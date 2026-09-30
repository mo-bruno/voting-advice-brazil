# Quiz Persistence Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop public quiz submissions from creating or updating `devices` and `quiz_responses` whenever the app-scoped IoT flag is disabled, while preserving ranking and the dormant IoT behavior when explicitly enabled.

**Architecture:** Keep the HTTP schema backward compatible so old clients may still send `device_id`, but make the FastAPI route the definitive write barrier. The route reads `request.app.state.settings.iot_feature_enabled`, gates the existing repository write and push together, and leaves the pure ranking calculation untouched.

**Tech Stack:** Python 3.12+, FastAPI, SQLAlchemy 2, Pydantic Settings, pytest, Ruff, Mypy, uv

**Spec:** `docs/superpowers/specs/2026-09-29-analytics-privacy-and-data-minimization-design.md`

## Global Constraints

- Keep `POST /api/v1/quiz/submit` and its optional UUID v4 `device_id` field backward compatible.
- With `IOT_FEATURE_ENABLED=false`, return the same ranking and perform no insert or update in `devices` or `quiz_responses` and no hardware/news push.
- With `IOT_FEATURE_ENABLED=true`, preserve the existing persistence and push behavior.
- Read the flag from `request.app.state.settings`; a module-global `settings` value must not decide request behavior.
- Do not add, remove, or alter database tables, repositories, entities, or Alembic migrations.
- Do not delete historical data in this implementation; cleanup is a separately verified production operation.
- Preserve `politician_follow_interests`, follow, community, IoT links/events, posts, comments, votes, reports, locks, and moderation records.

## Review Focus

- A legacy client sends a valid UUID while IoT is disabled: it still receives a ranking, but creates no rows; Task 1 pins this.
- Rows already stored for a UUID are submitted again while IoT is disabled: timestamps, answers, and weights remain byte-for-byte unchanged; Task 1 pins this.
- The module-global flag disagrees with the settings of the concrete FastAPI app: the app-scoped value wins in both directions; Task 1 pins this.
- A request omits `device_id`: ranking remains unchanged and no persistence path is entered; Task 1 preserves the existing regression test.
- An invalid/non-v4 identifier is sent: schema validation still returns 422 without creating a device; Task 1 preserves the existing regression test.

---

### Task 1: Implement the app-scoped quiz write barrier

**Files:**
- Modify: `backend/app/api/routers/quiz.py:115-119`
- Modify: `backend/tests/test_quiz.py:153-538`

**Interfaces:**
- Consumes: `create_app(Settings(...))`, `get_db`, `DeviceModel`, `QuizResponseModel`, and `POST /api/v1/quiz/submit`.
- Produces: two disabled-IoT endpoint regressions plus one route conditional proving that the disabled app does not create or mutate quiz identity data while enabled-IoT behavior remains intact.

- [ ] **Step 1: Strengthen the existing disabled-IoT test before changing production code**

`backend/tests/conftest.py` sets `IOT_FEATURE_ENABLED=true` before importing the application, so the shared `client` intentionally remains the enabled-IoT regression client. Disabled-path tests must continue constructing their own app with `Settings(..., iot_feature_enabled=False)`; do not change the global fixture or environment for this fix.

Extend `test_submit_with_device_id_skips_news_push_when_iot_is_disabled` so its
signature also receives the shared IoT-enabled `client`, its UUID is assigned
to `device_id`, and the postconditions compare against a no-ID baseline request
through that independent shared app plus empty persistence:

```python
device_id = "550e8400-e29b-41d4-a716-446655440006"

# ... create the disabled configured_app ...
answers = _agree5(thesis_ids)
with TestClient(configured_app) as disabled_client:
    r = disabled_client.post(
        "/api/v1/quiz/submit",
        json={"device_id": device_id, "answers": answers},
    )
control = client.post(
    "/api/v1/quiz/submit",
    json={"answers": answers},
)

assert r.status_code == 200
assert control.status_code == 200
assert r.json()["results"] == control.json()["results"]
assert db_session.get(DeviceModel, device_id) is None
assert (
    db_session.query(QuizResponseModel)
    .filter_by(device_id=device_id)
    .count()
    == 0
)
```

- [ ] **Step 2: Run the focused test and verify the current defect**

Run:

```bash
cd backend
/tmp/codex-uv/bin/uv run pytest \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_device_id_skips_news_push_when_iot_is_disabled \
  -q --no-cov
```

Expected: FAIL because `db_session.get(DeviceModel, device_id)` returns a row even though the app-scoped flag is false.

- [ ] **Step 3: Add the existing-row non-mutation regression**

Create `test_submit_with_device_id_does_not_update_existing_data_when_iot_is_disabled`. Seed through the existing IoT-enabled shared `client`, snapshot every mapped column, then submit changed values through a disabled app using the same database session. Add a small test helper based on `sqlalchemy.inspect(type(row)).mapper.column_attrs` that returns a tuple of every mapped column value; sort those snapshot tuples with the shown deterministic `repr` key before comparison.

```python
device_id = "550e8400-e29b-41d4-a716-446655440016"
original = _agree5(thesis_ids)
changed = [
    {
        "thesis_id": original[0]["thesis_id"],
        "answer": "disagree",
        "weight": 2,
    },
    *original[1:],
]

created = client.post(
    "/api/v1/quiz/submit",
    json={"device_id": device_id, "answers": original},
)
assert created.status_code == 200
db_session.expire_all()
before_device = db_session.get(DeviceModel, device_id)
assert before_device is not None
before_device_snapshot = _mapped_column_snapshot(before_device)
before_rows = sorted(
    (
        _mapped_column_snapshot(row)
        for row in db_session.query(QuizResponseModel)
        .filter_by(device_id=device_id)
        .all()
    ),
    key=repr,
)

configured_app = create_app(
    Settings(_env_file=None, app_env="test", iot_feature_enabled=False)
)

def override_get_db():
    yield db_session

configured_app.dependency_overrides[get_db] = override_get_db
with TestClient(configured_app) as disabled_client:
    response = disabled_client.post(
        "/api/v1/quiz/submit",
        json={"device_id": device_id, "answers": changed},
    )
control = client.post(
    "/api/v1/quiz/submit",
    json={"answers": changed},
)

assert response.status_code == 200
assert control.status_code == 200
assert response.json()["results"] == control.json()["results"]
db_session.expire_all()
after_device = db_session.get(DeviceModel, device_id)
assert after_device is not None
assert _mapped_column_snapshot(after_device) == before_device_snapshot
after_rows = sorted(
    (
        _mapped_column_snapshot(row)
        for row in db_session.query(QuizResponseModel)
        .filter_by(device_id=device_id)
        .all()
    ),
    key=repr,
)
assert after_rows == before_rows
```

Patch `_push_news_for_quiz_submission` with `pushed_for.append` before the enabled seed, assert `pushed_for == [device_id]`, then clear the list. Submit through the disabled app and assert `pushed_for == []` together with the unchanged database snapshots. This lets the enabled seed exercise its valid side effect while proving the disabled request triggers none.

- [ ] **Step 4: Run both disabled-IoT tests and verify they fail for persistence only**

Run:

```bash
cd backend
/tmp/codex-uv/bin/uv run pytest \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_device_id_skips_news_push_when_iot_is_disabled \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_device_id_does_not_update_existing_data_when_iot_is_disabled \
  -q --no-cov
```

Expected: FAIL on the new persistence assertions; both disabled requests still
return 200 with the exact same ranking as the same-payload no-ID baseline from
the independent IoT-enabled shared app, and the push guard remains uncalled.

- [ ] **Step 5: Implement the minimal route gate**

Replace the current nested conditional with:

```python
if (
    body.device_id is not None
    and request.app.state.settings.iot_feature_enabled
):
    anonymous_id = str(body.device_id)
    quiz_response_repo.upsert_answers(anonymous_id, answers)
    _push_news_for_quiz_submission(anonymous_id)
```

Do not move the ranking calculation into this block.

- [ ] **Step 6: Strengthen the enabled-app/global-disabled regression**

In `test_factory_enabled_app_pushes_news_when_global_iot_is_disabled`, after asserting the push, also prove the app-scoped enabled setting persisted data:

```python
device = db_session.get(DeviceModel, device_id)
assert device is not None
assert (
    db_session.query(QuizResponseModel)
    .filter_by(device_id=device_id)
    .count()
    == len(_agree5(thesis_ids))
)
```

- [ ] **Step 7: Run the focused behavior matrix**

Run:

```bash
cd backend
/tmp/codex-uv/bin/uv run pytest \
  tests/test_quiz.py::TestEndpointSubmit::test_returns_ranked_results \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_without_device_id_does_not_persist_answers \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_device_id_persists_answers \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_device_id_pushes_news_inline \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_device_id_skips_news_push_when_iot_is_disabled \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_device_id_does_not_update_existing_data_when_iot_is_disabled \
  tests/test_quiz.py::TestEndpointSubmit::test_factory_enabled_app_pushes_news_when_global_iot_is_disabled \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_same_device_id_updates_existing_answers \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_persists_skip_answers_when_payload_is_valid \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_duplicate_thesis_ids_persists_latest_answer \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_duplicate_thesis_ids_scores_and_persists_latest_answers \
  tests/test_quiz.py::TestEndpointSubmit::test_submit_with_uuidv1_device_id_rejected_without_persisting_device \
  -q --no-cov
```

Expected: all twelve tests PASS. The six persistence-positive tests use the existing shared IoT-enabled `client`; both disabled regressions use an explicitly false app, compare their ranking with a same-payload no-ID request through the independent enabled app, and prove the concrete app-scoped setting wins. The existing no-ID regression independently remains in the matrix.

- [ ] **Step 8: Run static checks for the touched backend files**

Run:

```bash
cd backend
/tmp/codex-uv/bin/uv run ruff check app/api/routers/quiz.py tests/test_quiz.py
/tmp/codex-uv/bin/uv run mypy app/api/routers/quiz.py
```

Expected: both commands exit 0.

- [ ] **Step 9: Commit the tested implementation**

```bash
git add backend/app/api/routers/quiz.py backend/tests/test_quiz.py
git commit -m "fix: gate quiz persistence behind iot"
```

### Task 2: Align backend and operator documentation

**Files:**
- Modify: `backend/README.md:102-143`
- Modify: `README.md:1-18`
- Modify: `PUBLICACAO_2026.md`
- Modify: `CLAUDE.md:5-12`

**Interfaces:**
- Consumes: the route behavior proven in Task 1.
- Produces: documentation that no longer says the public quiz persists answers when IoT is off.

- [ ] **Step 1: Update the backend contract text**

State all of the following explicitly in `backend/README.md`:

```text
POST /quiz/submit keeps device_id optional for backward compatibility. With
IOT_FEATURE_ENABLED=false, the API uses the submitted answers only to calculate
the response and does not create or update devices or quiz_responses, even when
a legacy client sends device_id. With the flag true, persistence and the
historical IoT side effect remain enabled together.
```

Change the endpoint table description from unconditional persistence to “persistence only when IoT is enabled.”

- [ ] **Step 2: Update repository-facing identity documentation**

In `README.md`, `PUBLICACAO_2026.md`, and `CLAUDE.md`, replace the claim that every quiz submit stores the UUID and answers with the verified public behavior. Preserve the separate uses of the main UUID for community/follow and the separate UUID for `politician_follow_interests`.

- [ ] **Step 3: Check stale claims**

Run:

```bash
rg -n -i "respostas?.*(persist|gravad|salv)|(persist|gravad|salv).*respostas?|persistência funcional.*respostas|quiz answers.*persisted" \
  README.md PUBLICACAO_2026.md CLAUDE.md backend/README.md
```

Expected: no statement claims unconditional quiz persistence; any remaining match explicitly scopes persistence to IoT enabled.

- [ ] **Step 4: Commit the documentation**

```bash
git add README.md PUBLICACAO_2026.md CLAUDE.md backend/README.md
git commit -m "docs: describe transient public quiz processing"
```

### Task 3: Verify the backend deliverable

**Files:**
- Verify only: `backend/`

**Interfaces:**
- Consumes: Tasks 1-2.
- Produces: release evidence for the isolated backend change; it does not authorize production deletion.

- [ ] **Step 1: Verify dependency and lock consistency**

```bash
cd backend
/tmp/codex-uv/bin/uv lock --check
/tmp/codex-uv/bin/uv sync --locked --extra dev
```

Expected: both commands exit 0 without modifying `uv.lock`.

- [ ] **Step 2: Run the complete backend quality gate**

```bash
cd backend
/tmp/codex-uv/bin/uv run pytest
/tmp/codex-uv/bin/uv run ruff check . ../scripts/build_presidential_2026_data.py ../scripts/deploy_presidential_backend.py
/tmp/codex-uv/bin/uv run mypy app/
```

Expected: all tests pass with the configured coverage threshold; Ruff and Mypy exit 0.

- [ ] **Step 3: Inspect the final diff and confirm schema stability**

```bash
git diff origin/main...HEAD -- backend
git status --short
```

Expected: no migration, model, repository, lockfile, or unrelated backend file changed; the worktree is clean after commits.

- [ ] **Step 4: Record the production follow-up boundary**

The handoff must state that production verification and historical deletion remain in `docs/superpowers/plans/2026-09-29-analytics-cutover-and-cleanup.md`. Do not run SQL deletion as part of this plan.
