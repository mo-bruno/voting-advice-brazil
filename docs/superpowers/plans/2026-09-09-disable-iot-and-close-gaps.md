# Disable IoT and Close Security Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide the physical IoT feature behind default-off flags and close the repository's anonymous-identity, community-integrity, scheduler, architecture, dependency, and documentation gaps.

**Architecture:** FastAPI and Flutter each own a default-off IoT flag so dormant code remains testable but absent from deployed routes and UI. Community responses project private owner UUIDs into public aliases and request-relative ownership flags, while moderation and rate limits move into core use cases. The API no longer owns a scheduler; the retained IoT notifier is a guarded one-shot job with safe pending semantics and database deduplication.

**Tech Stack:** Python 3.12, FastAPI, Pydantic Settings, SQLAlchemy, Alembic, pytest, Flutter/Dart, Firebase Hosting, Cloud Run, MQTT.

**Spec:** `docs/superpowers/specs/2026-09-09-disable-iot-and-close-gaps-design.md`

## Global Constraints

- `IOT_FEATURE_ENABLED` defaults to `false` in both backend and Flutter.
- The Farol Político brand remains; only the physical hardware feature becomes dormant.
- Existing IoT migrations, tables, rows, and firmware source are preserved.
- Raw anonymous UUIDs remain private bearer credentials and never appear in community responses.
- Missing posts remain HTTP 404; removed posts reject new votes/comments with HTTP 410.
- Comments allow 10 accepted submissions per anonymous UUID per rolling 10 minutes.
- Unmapped Câmara votes are `pending`; only real abstention values are `abstained`.
- No module under `backend/app/core` may import infrastructure or framework packages.
- Backend and Flutter API-contract changes ship together.
- Product-facing copy remains Brazilian Portuguese.

---

### Task 1: Restore the Core/Infrastructure Dependency Boundary

**Files:**

- Create: `backend/tests/test_architecture_boundaries.py`
- Modify: `backend/app/core/use_cases/interfaces.py`
- Modify: `backend/app/core/entities/news.py`
- Modify: `backend/app/core/use_cases/moderate_and_create_post.py`
- Modify: `backend/app/core/use_cases/report_post.py`
- Modify: `backend/app/core/use_cases/news_notifier.py`
- Modify: `backend/app/infrastructure/llm/moderation_client.py`
- Modify: `backend/app/infrastructure/sources/gnews.py`
- Modify: `backend/tests/test_community_use_cases.py`
- Modify: `backend/tests/test_report_post.py`
- Modify: `backend/tests/test_news_notifier.py`

**Interfaces:**

- Produces: `ModerationPort.moderate(content, report_reasons=None) -> ModerationResult` in core.
- Produces: `ModerationUnavailable` in core.
- Produces: `DeviceNewsArticle(title: str, source: str, date: str)` in core.
- Consumes: existing `ModerationResult` and `NewsArticle` core entities.

- [ ] **Step 1: Write the failing architecture test**

Create an AST-based test that names the production change that makes it pass:

```python
from __future__ import annotations

import ast
from pathlib import Path

FORBIDDEN_PREFIXES = (
    "app.infrastructure",
    "fastapi",
    "sqlalchemy",
    "httpx",
    "paho",
    "apscheduler",
)


def test_core_does_not_import_frameworks_or_infrastructure() -> None:
    core_dir = Path(__file__).parents[1] / "app" / "core"
    violations: list[str] = []
    for path in core_dir.rglob("*.py"):
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            names: list[str] = []
            if isinstance(node, ast.Import):
                names = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom) and node.module:
                names = [node.module]
            for name in names:
                if name.startswith(FORBIDDEN_PREFIXES):
                    violations.append(f"{path.relative_to(core_dir)} imports {name}")
    assert violations == []
```

- [ ] **Step 2: Run the architecture test and verify RED**

Run:

```bash
cd backend
uv run pytest tests/test_architecture_boundaries.py -q
```

Expected: FAIL listing imports from `moderate_and_create_post.py` and
`report_post.py`.

- [ ] **Step 3: Move moderation contracts and hardware-news data into core**

Add the moderation boundary to `interfaces.py` after importing
`ModerationResult`:

```python
class ModerationPort(ABC):
    @abstractmethod
    def moderate(
        self,
        content: str,
        report_reasons: list[str] | None = None,
    ) -> ModerationResult: ...


class ModerationUnavailable(Exception):
    """Raised when required content moderation cannot produce a decision."""
```

Add to `core/entities/news.py`:

```python
@dataclass(frozen=True, slots=True)
class DeviceNewsArticle:
    title: str
    source: str
    date: str
```

Update both community use cases and the LLM adapter to import the core
moderation types. Delete the adapter-local definitions. Update
`news_notifier.py` to type `ArticlesFetcher` with `DeviceNewsArticle`, and make
the GNews adapter construct that core entity instead of defining its own
dataclass.

- [ ] **Step 4: Run focused core and adapter tests and verify GREEN**

Run:

```bash
cd backend
uv run pytest tests/test_architecture_boundaries.py tests/test_community_use_cases.py tests/test_report_post.py tests/test_news_notifier.py tests/test_gnews_client.py -q
```

Expected: all selected tests pass.

- [ ] **Step 5: Run static checks for the changed boundary**

Run:

```bash
cd backend
uv run ruff check app/core app/infrastructure/llm app/infrastructure/sources/gnews.py tests/test_architecture_boundaries.py
uv run mypy app/core app/infrastructure/llm app/infrastructure/sources/gnews.py
```

Expected: both commands exit 0.

- [ ] **Step 6: Commit the boundary restoration**

```bash
git add backend/app/core backend/app/infrastructure/llm backend/app/infrastructure/sources/gnews.py backend/tests/test_architecture_boundaries.py backend/tests/test_community_use_cases.py backend/tests/test_report_post.py backend/tests/test_news_notifier.py
git commit -m "refactor: restore core dependency boundaries"
```

---

### Task 2: Make Anonymous UUIDs Private Credentials

**Files:**

- Create: `backend/app/api/identity.py`
- Create: `backend/tests/test_anonymous_identity.py`
- Modify: `backend/app/api/schemas/community.py`
- Modify: `backend/app/api/routers/community.py`
- Modify: `backend/app/api/routers/political_actors.py`
- Modify: `backend/app/api/routers/iot_devices.py`
- Modify: `backend/tests/conftest.py`
- Modify: all backend API tests that send `X-Farol-Anonymous-Id`

**Interfaces:**

- Produces: `require_anonymous_id(...) -> str` FastAPI dependency.
- Produces: `optional_anonymous_id(...) -> str | None` FastAPI dependency.
- Produces: `public_author_alias(anonymous_id: str) -> str`.
- Changes: `PostOut` and `CommentOut` replace `anonymous_id` with
  `author_alias` and `is_mine`.

- [ ] **Step 1: Add failing identity and response-contract tests**

Create tests with UUID v4 constants:

```python
from app.api.identity import public_author_alias

OWNER = "550e8400-e29b-41d4-a716-446655440000"
OTHER = "550e8400-e29b-41d4-a716-446655440001"


def test_public_alias_is_stable_and_does_not_expose_uuid() -> None:
    first = public_author_alias(OWNER)
    assert first == public_author_alias(OWNER)
    assert first.startswith("u/")
    assert OWNER not in first
    assert first != public_author_alias(OTHER)


def test_invalid_anonymous_header_is_rejected(client) -> None:
    response = client.post(
        "/api/v1/community/posts",
        headers={"X-Farol-Anonymous-Id": "not-a-uuid"},
        json={"content": "Debate político brasileiro."},
    )
    assert response.status_code == 422


def test_post_response_hides_owner_credential(client) -> None:
    response = client.post(
        "/api/v1/community/posts",
        headers={"X-Farol-Anonymous-Id": OWNER},
        json={"content": "Debate político brasileiro."},
    )
    body = response.json()
    assert "anonymous_id" not in body
    assert body["author_alias"].startswith("u/")
    assert body["is_mine"] is True
    assert OWNER not in response.text
```

Also add list/detail tests proving `is_mine=false` without a header and for a
different UUID, plus a comment-response test proving the raw UUID is absent.

- [ ] **Step 2: Run the new tests and verify RED**

```bash
cd backend
uv run pytest tests/test_anonymous_identity.py -q
```

Expected: collection fails because `app.api.identity` does not exist, or
assertions fail because responses still contain `anonymous_id`.

- [ ] **Step 3: Implement shared header validation and public projection**

Create `app/api/identity.py`:

```python
from __future__ import annotations

import hashlib
from typing import Annotated
from uuid import UUID

from fastapi import Header, HTTPException

_AnonymousHeader = Annotated[str | None, Header(alias="X-Farol-Anonymous-Id")]


def _validated_uuid4(raw: str) -> str:
    try:
        parsed = UUID(raw)
    except ValueError:
        raise HTTPException(status_code=422, detail="Anonymous ID must be a UUID v4.") from None
    if parsed.version != 4:
        raise HTTPException(status_code=422, detail="Anonymous ID must be a UUID v4.")
    return str(parsed)


def require_anonymous_id(value: _AnonymousHeader = None) -> str:
    if value is None:
        raise HTTPException(status_code=422, detail="X-Farol-Anonymous-Id is required.")
    return _validated_uuid4(value)


def optional_anonymous_id(value: _AnonymousHeader = None) -> str | None:
    return None if value is None else _validated_uuid4(value)


def public_author_alias(anonymous_id: str) -> str:
    digest = hashlib.sha256(anonymous_id.encode("utf-8")).hexdigest()
    return f"u/{digest[:10]}"
```

Use `Depends(require_anonymous_id)` on protected community, followed-actor,
and optional IoT routes. Use `Depends(optional_anonymous_id)` on community list
and detail routes.

Change schema fields to:

```python
author_alias: str
is_mine: bool
```

Change `_post_out` and `_comment_out` to accept `viewer_id: str | None`, derive
the alias, and set `is_mine=viewer_id == entity.anonymous_id`.

- [ ] **Step 4: Normalize existing API test identities**

Add stable UUID fixtures/constants in `tests/conftest.py` and replace short
values such as `anon-1`, `device-a`, and `user-1` anywhere they pass through an
HTTP header. Fake repository unit tests that never exercise header validation
may keep descriptive non-UUID identifiers.

- [ ] **Step 5: Run identity, community, followed-actor, and IoT API tests**

```bash
cd backend
uv run pytest tests/test_anonymous_identity.py tests/test_community_api.py tests/test_community_integrity_api.py tests/test_political_actors_api.py tests/test_iot_devices_api.py tests/test_last_event_endpoint.py -q
```

Expected: all selected tests pass and response text contains no raw owner UUID.

- [ ] **Step 6: Commit the private identity contract**

```bash
git add backend/app/api backend/tests
git commit -m "fix: keep anonymous credentials out of public responses"
```

---

### Task 3: Moderate and Rate-Limit Comments; Close Removed Posts

**Files:**

- Create: `backend/app/core/use_cases/comment_rate_limit.py`
- Create: `backend/app/core/use_cases/community_errors.py`
- Create: `backend/tests/test_comment_integrity.py`
- Modify: `backend/app/core/use_cases/create_comment.py`
- Modify: `backend/app/core/use_cases/vote_post.py`
- Modify: `backend/app/core/use_cases/interfaces.py`
- Modify: `backend/app/infrastructure/database/community_repositories.py`
- Modify: `backend/app/api/routers/community.py`
- Modify: `backend/tests/test_community_use_cases.py`
- Modify: `backend/tests/test_community_integrity_api.py`

**Interfaces:**

- Produces: `CommentRateLimitExceeded(retry_after_seconds: int)`.
- Produces: `check_comment_rate_limit(recent_count: int) -> None`.
- Produces: `PostRemovedError`.
- Changes: `CommentRepository.count_by_author_since(anonymous_id, since) -> int`.
- Changes: comment creation accepts `ModerationLogRepository` and
  `ModerationPort`, returning `(Comment | None, ModerationResult)`.

- [ ] **Step 1: Write failing comment-integrity tests**

Cover the real use-case and API behavior:

```python
def test_rejected_comment_is_logged_but_not_persisted():
    comment, decision = moderate_and_create_comment(
        post_repo=active_post_repo,
        comment_repo=comment_repo,
        log_repo=log_repo,
        moderation_client=FakeModerationClient(approved=False, reason="Falso"),
        post_id=POST_ID,
        anonymous_id=OWNER,
        content="Conteúdo rejeitado",
    )
    assert comment is None
    assert decision.approved is False
    assert comment_repo.created == []
    assert len(log_repo.entries) == 1


def test_comment_limit_is_ten_per_ten_minutes():
    check_comment_rate_limit(9)
    with pytest.raises(CommentRateLimitExceeded) as exc:
        check_comment_rate_limit(10)
    assert exc.value.retry_after_seconds == 600


def test_removed_post_rejects_vote_and_comment(client, removed_post_id):
    vote = client.post(
        f"/api/v1/community/posts/{removed_post_id}/votes",
        headers=HEADERS,
        json={"value": 1},
    )
    comment = client.post(
        f"/api/v1/community/posts/{removed_post_id}/comments",
        headers=HEADERS,
        json={"content": "Novo comentário"},
    )
    assert vote.status_code == 410
    assert comment.status_code == 410
```

Add endpoint tests for moderator 503, rejection 422, eleventh accepted comment
429, and `Retry-After: 600`.

- [ ] **Step 2: Run the new tests and verify RED**

```bash
cd backend
uv run pytest tests/test_comment_integrity.py -q
```

Expected: FAIL because comments bypass moderation/rate limiting and removed
posts still accept activity.

- [ ] **Step 3: Implement comment limits and removed-post errors**

Create `comment_rate_limit.py`:

```python
from typing import Final

MAX_COMMENTS_PER_WINDOW: Final[int] = 10
WINDOW_MINUTES: Final[int] = 10


class CommentRateLimitExceeded(Exception):
    def __init__(self) -> None:
        self.retry_after_seconds = WINDOW_MINUTES * 60
        super().__init__("Limite de comentários excedido.")


def check_comment_rate_limit(recent_count: int) -> None:
    if recent_count >= MAX_COMMENTS_PER_WINDOW:
        raise CommentRateLimitExceeded()
```

Create `community_errors.py` with `PostRemovedError`. Update vote and comment
use cases to load the post once, return `None` for missing, and raise
`PostRemovedError` when `removed_at` is set.

Add `CommentRepository.count_by_author_since` and implement it with a SQL count
on `anonymous_id` and `created_at >= since`.

- [ ] **Step 4: Add moderation to comment creation and router error mapping**

Apply the post moderation sequence to comments: moderate, SHA-256 hash, log
rejections without persistence, create approved comments, then log approval.
Map errors in the router exactly:

```python
except CommentRateLimitExceeded as exc:
    raise HTTPException(
        status_code=429,
        detail="Você comentou demais nos últimos minutos. Tente novamente em breve.",
        headers={"Retry-After": str(exc.retry_after_seconds)},
    ) from None
except PostRemovedError:
    raise HTTPException(status_code=410, detail="Este post foi removido.") from None
except ModerationUnavailable:
    raise HTTPException(
        status_code=503,
        detail="Serviço de moderação temporariamente indisponível.",
    ) from None
```

Return 422 with the moderator reason when the result is rejected. Apply the
same `PostRemovedError` to voting.

- [ ] **Step 5: Run focused community tests and verify GREEN**

```bash
cd backend
uv run pytest tests/test_comment_integrity.py tests/test_community_use_cases.py tests/test_community_api.py tests/test_community_integrity_api.py tests/test_post_rate_limit.py tests/test_remove_post.py tests/test_report_post.py -q
```

Expected: all selected tests pass.

- [ ] **Step 6: Commit community integrity changes**

```bash
git add backend/app/core/use_cases backend/app/infrastructure/database/community_repositories.py backend/app/api/routers/community.py backend/tests
git commit -m "fix: enforce integrity rules for community comments"
```

---

### Task 4: Add the Default-Off Backend IoT Flag

**Files:**

- Create: `backend/tests/test_iot_feature_flag.py`
- Modify: `backend/app/core/config.py`
- Modify: `backend/app/main.py`
- Modify: `backend/app/api/routers/quiz.py`
- Modify: `backend/.env.example`
- Modify: `backend/tests/test_config.py`
- Modify: `backend/tests/conftest.py`

**Interfaces:**

- Produces: `Settings.iot_feature_enabled: bool` defaulting to false.
- Produces: `create_app(app_settings: Settings = settings) -> FastAPI`.
- Keeps: global `app = create_app()` for Uvicorn and existing tests.

- [ ] **Step 1: Write failing backend feature-flag tests**

```python
from app.core.config import Settings
from app.main import create_app


def _paths(enabled: bool) -> set[str]:
    configured = Settings(_env_file=None, iot_feature_enabled=enabled)
    return {route.path for route in create_app(configured).routes}


def test_iot_routes_are_absent_by_default() -> None:
    assert Settings(_env_file=None).iot_feature_enabled is False
    assert "/api/v1/me/iot-device" not in _paths(False)
    assert "/api/v1/iot-devices/{device_token}/pairing-session" not in _paths(False)


def test_iot_routes_can_be_explicitly_enabled() -> None:
    assert "/api/v1/me/iot-device" in _paths(True)
```

Add a quiz endpoint test that monkeypatches
`settings.iot_feature_enabled=False`, replaces
`_push_news_for_quiz_submission` with a function that fails if called, submits
a valid quiz with `device_id`, and asserts HTTP 200.

- [ ] **Step 2: Run feature-flag tests and verify RED**

```bash
cd backend
uv run pytest tests/test_iot_feature_flag.py -q
```

Expected: FAIL because the setting and `create_app` do not exist.

- [ ] **Step 3: Refactor app construction and gate routes**

Add to `Settings`:

```python
iot_feature_enabled: bool = False
```

Refactor `main.py` so `create_app` owns middleware, exception handlers, static
mounts, and route registration. Always register active routers; conditionally
register both IoT routers:

```python
if app_settings.iot_feature_enabled:
    application.include_router(iot_devices.router, prefix=PREFIX)
    application.include_router(iot_devices.me_router, prefix=PREFIX)
```

Keep `app = create_app()` at module scope. Remove all scheduler start/stop calls
from the lifespan; retain only seed startup outside tests and startup logging.

- [ ] **Step 4: Gate quiz-triggered hardware news**

Keep anonymous quiz-response persistence, then change the optional notification
condition to:

```python
if body.device_id is not None:
    anonymous_id = str(body.device_id)
    quiz_response_repo.upsert_answers(anonymous_id, answers)
    if settings.iot_feature_enabled:
        _push_news_for_quiz_submission(anonymous_id)
```

Document `IOT_FEATURE_ENABLED=false` in `.env.example`. Set it to true at the
top of `tests/conftest.py` before importing the app so legacy IoT endpoint tests
continue exercising the enabled route set; isolated factory tests cover false.

- [ ] **Step 5: Run app/config/quiz/IoT tests and verify GREEN**

```bash
cd backend
uv run pytest tests/test_iot_feature_flag.py tests/test_config.py tests/test_quiz.py tests/test_quiz_response_repository.py tests/test_iot_devices_api.py tests/test_health.py -q
```

Expected: all selected tests pass.

- [ ] **Step 6: Commit the backend flag**

```bash
git add backend/app/core/config.py backend/app/main.py backend/app/api/routers/quiz.py backend/.env.example backend/tests
git commit -m "feat: disable IoT API by default"
```

---

### Task 5: Convert the IoT Scheduler to a Safe One-Shot Job

**Files:**

- Create: `backend/alembic/versions/0007_iot_event_deduplication.py`
- Create: `backend/tests/test_iot_notifier_job.py`
- Modify: `backend/app/core/entities/iot_device.py`
- Modify: `backend/app/core/use_cases/interfaces.py`
- Modify: `backend/app/core/use_cases/vote_notifier.py`
- Modify: `backend/app/infrastructure/database/models.py`
- Modify: `backend/app/infrastructure/database/iot_device_repositories.py`
- Modify: `backend/app/infrastructure/scheduler.py`
- Modify: `backend/tests/test_vote_notifier.py`
- Modify: `backend/tests/test_iot_event_repository.py`
- Modify: `backend/tests/test_migrations.py`

**Interfaces:**

- Changes: `run_vote_notifier(..., source_event_id: str, ...) -> int`.
- Produces: `IotDeviceEventRepository.record_once(..., deduplication_key: str, ...) -> IotDeviceEvent | None`.
- Produces: `_alignment_for_vote(vote: str) -> str` returning only `abstained`
  or `pending` for raw Câmara values.
- Produces: `run_once() -> int` in the former scheduler module; no background
  thread or API lifecycle integration.

- [ ] **Step 1: Write failing safe-alignment and deduplication tests**

```python
@pytest.mark.parametrize("vote", ["Abstenção", "ABSTENCAO", "Abstention"])
def test_camara_abstentions_are_yellow(vote: str) -> None:
    assert _alignment_for_vote(vote) == "abstained"


@pytest.mark.parametrize("vote", ["Sim", "Não", "Obstrução"])
def test_unmapped_votes_are_pending(vote: str) -> None:
    assert _alignment_for_vote(vote) == "pending"


def test_same_source_vote_is_published_once():
    first = run_vote_notifier(source_event_id="vote:123:456", **dependencies)
    second = run_vote_notifier(source_event_id="vote:123:456", **dependencies)
    assert first == 1
    assert second == 0
    assert len(publisher.published) == 1
```

Add repository tests proving `record_once` returns an event once and `None` for
the same `(device_token, event_type, deduplication_key)`. Add a migration test
that upgrades from `0006_community_integrity` to head while preserving a
pre-existing IoT event row.

- [ ] **Step 2: Run notifier/repository tests and verify RED**

```bash
cd backend
uv run pytest tests/test_iot_notifier_job.py tests/test_vote_notifier.py tests/test_iot_event_repository.py tests/test_migrations.py -q
```

Expected: FAIL because safe mapping, deduplication key, and `record_once` do not
exist.

- [ ] **Step 3: Add the additive deduplication migration and model field**

Migration `0007_iot_event_deduplication` revises
`0006_community_integrity`, adds nullable `deduplication_key VARCHAR(192)`, and
creates a unique constraint named `uq_iot_events_delivery` over:

```text
device_token, event_type, deduplication_key
```

Use Alembic batch operations for SQLite compatibility. Add the matching nullable
mapped column and `UniqueConstraint` to `IotDeviceEventModel`; expose the field
on `IotDeviceEvent`.

- [ ] **Step 4: Implement atomic reservation and safe publication**

Implement `record_once` by attempting the insert and commit. On
`IntegrityError`, roll back and return `None`. `run_vote_notifier` calls
`record_once` before MQTT publish and skips publication when it returns `None`.
The at-most-once choice is deliberate: it prevents repeats even though a broker
failure after reservation can leave an undelivered historical event.

Include `source_event_id` in the event payload. Update fakes to track reserved
keys.

- [ ] **Step 5: Remove APScheduler and expose the guarded one-shot job**

Remove `BackgroundScheduler`, `_scheduler`, `start`, and `stop`. Keep the Câmara
fetch/orchestration logic, but expose:

```python
def _alignment_for_vote(vote: str) -> str:
    normalized = "".join(
        char for char in unicodedata.normalize("NFKD", vote.casefold())
        if not unicodedata.combining(char)
    )
    return "abstained" if normalized in {"abstencao", "abstention"} else "pending"


def run_once() -> int:
    if not settings.iot_feature_enabled:
        return 0
    return _run_vote_notifier_job()


def main() -> None:
    run_once()


if __name__ == "__main__":
    main()
```

Each fetched vote supplies `source_event_id=f"vote:{voting_id}:{source_id}"`
and `alignment=_alignment_for_vote(vote)`.

- [ ] **Step 6: Run migration and notifier tests and verify GREEN**

```bash
cd backend
uv run pytest tests/test_iot_notifier_job.py tests/test_vote_notifier.py tests/test_iot_event_repository.py tests/test_migrations.py tests/test_last_event_endpoint.py -q
uv run alembic upgrade head
```

Expected: tests pass and Alembic reaches `0007_iot_event_deduplication` without
dropping existing tables.

- [ ] **Step 7: Commit the one-shot notifier**

```bash
git add backend/alembic backend/app/core backend/app/infrastructure/database backend/app/infrastructure/scheduler.py backend/tests
git commit -m "fix: make dormant IoT notifications safe and deduplicated"
```

---

### Task 6: Hide IoT Throughout Flutter

**Files:**

- Create: `mobile/lib/core/features/feature_flags.dart`
- Create: `mobile/test/iot_feature_flag_test.dart`
- Modify: `mobile/lib/app.dart`
- Modify: `mobile/lib/core/shell/main_shell.dart`
- Modify: `mobile/lib/shared/widgets/app_drawer.dart`
- Modify: `mobile/lib/features/quiz/quiz_page.dart`
- Modify: `mobile/test/widget_test.dart`
- Modify: `mobile/test/app_drawer_test.dart`
- Modify: `mobile/test/navigation_shell_wiring_test.dart`
- Modify: `mobile/test/quiz_controller_analytics_test.dart` only if its fixture constructs `QuizPage`

**Interfaces:**

- Produces: immutable `FeatureFlags(iotEnabled: bool)` and
  `FeatureFlags.environment`.
- Changes: `MyApp`, `MainShell`, `AppDrawer`, and `QuizPage` accept an injectable
  feature configuration or boolean while defaulting to the environment flag.

- [ ] **Step 1: Write failing Flutter flag tests**

```dart
testWidgets('IoT routes are absent when the feature is disabled', (tester) async {
  await tester.pumpWidget(
    const MyApp(featureFlags: FeatureFlags(iotEnabled: false)),
  );
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  expect(app.routes!.containsKey('/iot-device'), isFalse);
  expect(app.routes!.containsKey('/iot-pairing'), isFalse);
});

testWidgets('drawer hides all physical-device controls by default', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: AppDrawer(iotEnabled: false)));
  expect(find.textContaining('CONECTAR FAROL'), findsNothing);
  expect(find.textContaining('Farol conectado'), findsNothing);
});

testWidgets('IoT routes remain available when explicitly enabled', (tester) async {
  await tester.pumpWidget(
    const MyApp(featureFlags: FeatureFlags(iotEnabled: true)),
  );
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  expect(app.routes!.containsKey('/iot-device'), isTrue);
  expect(app.routes!.containsKey('/iot-pairing'), isTrue);
});
```

Add a quiz-page test with a fake IoT session proving an answer does not call
`sendQuizPulse` when disabled and does call it when enabled.

- [ ] **Step 2: Run the new Flutter test and verify RED**

```bash
cd mobile
flutter test test/iot_feature_flag_test.dart
```

Expected: compilation fails because `FeatureFlags` and injectable flags do not
exist.

- [ ] **Step 3: Implement the compile-time feature configuration**

Create:

```dart
class FeatureFlags {
  const FeatureFlags({required this.iotEnabled});

  final bool iotEnabled;

  static const environment = FeatureFlags(
    iotEnabled: bool.fromEnvironment(
      'IOT_FEATURE_ENABLED',
      defaultValue: false,
    ),
  );
}
```

Make `MyApp` default to `FeatureFlags.environment`. Conditionally spread the
two IoT routes into `routes`. Pass the boolean through the root `MainShell` to
`AppDrawer`.

When false, `AppDrawer` must not add `IotDeviceSession.instance` to its merged
listenables, call `loadStatus`/`loadLastEvent`, render `FarolDrawerHeader`, or
render `FarolStatusTile`. Use the ordinary branded drawer header and keep
followed-politician, quiz, community, about, and privacy items.

Add `iotEnabled` to `QuizPage`; wrap `IotDeviceSession.instance.sendQuizPulse`
so it executes only when true.

- [ ] **Step 4: Update existing navigation/drawer fixtures**

Tests for the default deployed UI assert no physical-device entry. Tests that
exercise dormant IoT drawer widgets instantiate `AppDrawer(iotEnabled: true)`.
Direct IoT page/session/model tests remain unchanged.

- [ ] **Step 5: Run focused Flutter tests and verify GREEN**

```bash
cd mobile
flutter test test/iot_feature_flag_test.dart test/widget_test.dart test/app_drawer_test.dart test/navigation_shell_wiring_test.dart test/shell_drawer_test.dart test/iot_device_page_test.dart test/iot_device_session_test.dart
```

Expected: all selected tests pass.

- [ ] **Step 6: Commit Flutter feature gating**

```bash
git add mobile/lib/core/features mobile/lib/app.dart mobile/lib/core/shell/main_shell.dart mobile/lib/shared/widgets/app_drawer.dart mobile/lib/features/quiz/quiz_page.dart mobile/test
git commit -m "feat: hide physical Farol behind a disabled flag"
```

---

### Task 7: Update Flutter for the Private Community Identity Contract

**Files:**

- Modify: `mobile/lib/features/community/models/community_models.dart`
- Modify: `mobile/lib/features/community/utils/community_utils.dart`
- Modify: `mobile/lib/features/community/widgets/post_card.dart`
- Modify: `mobile/lib/features/community/post_detail_page.dart`
- Modify: `mobile/lib/features/community/community_feed_page.dart`
- Modify: `mobile/lib/core/api/api_client.dart`
- Modify: `mobile/test/community_models_test.dart`
- Modify: `mobile/test/api_model_parsing_test.dart`
- Modify: `mobile/test/community_card_anatomy_test.dart`
- Modify: `mobile/test/community_integrity_ui_test.dart`
- Modify: `mobile/test/community_vote_test.dart`

**Interfaces:**

- Changes: `PostSummary.authorAlias: String` and `PostSummary.isMine: bool`
  replace `anonymousId`.
- Changes: `PostComment.authorAlias: String` and `PostComment.isMine: bool`
  replace `anonymousId`.
- Keeps: the local UUID is sent only as `X-Farol-Anonymous-Id`.

- [ ] **Step 1: Write failing model and ownership tests**

```dart
test('post parses public author metadata without a credential', () {
  final post = PostSummary.fromJson({
    'id': 'post-1',
    'author_alias': 'u/abc123def0',
    'is_mine': true,
    'content': 'Texto',
    'political_actor_id': null,
    'theme_slug': null,
    'score': 0,
    'created_at': '2026-09-09T12:00:00Z',
    'removed': false,
    'removed_by': null,
  });
  expect(post.authorAlias, 'u/abc123def0');
  expect(post.isMine, isTrue);
});

testWidgets('delete control is based on isMine', (tester) async {
  await pumpPostCard(tester, post: postWith(isMine: false));
  expect(find.byIcon(Icons.delete_outline), findsNothing);
  await pumpPostCard(tester, post: postWith(isMine: true));
  expect(find.byIcon(Icons.delete_outline), findsOneWidget);
});
```

Add a fake HTTP test proving list/detail requests send the local credential in
the header but parsed response objects expose only aliases.

- [ ] **Step 2: Run the focused Flutter tests and verify RED**

```bash
cd mobile
flutter test test/community_models_test.dart test/community_integrity_ui_test.dart
```

Expected: compile/assertion failures because models still require
`anonymousId`.

- [ ] **Step 3: Replace credential fields with projection fields**

Update JSON parsing to read `author_alias` and `is_mine`. Change avatar color
and initials helpers to consume the public alias. Display `authorAlias`
directly; do not derive `u/<prefix>` client-side.

Remove ownership comparisons against `DeviceIdentityStore` from widgets and
pages. Use `post.isMine` for delete actions. Continue sending the locally held
UUID to all protected and viewer-aware API requests.

- [ ] **Step 4: Run all community Flutter tests and verify GREEN**

```bash
cd mobile
flutter test test/community_models_test.dart test/api_model_parsing_test.dart test/api_client_community_sort_test.dart test/community_card_anatomy_test.dart test/community_error_handling_test.dart test/community_feed_chrome_test.dart test/community_feed_states_test.dart test/community_integrity_ui_test.dart test/community_session_test.dart test/community_vote_test.dart test/create_post_page_test.dart
```

Expected: all selected tests pass.

- [ ] **Step 5: Commit the Flutter API-contract update**

```bash
git add mobile/lib/features/community mobile/lib/core/api/api_client.dart mobile/test
git commit -m "fix: consume public community author aliases"
```

---

### Task 8: Remove Unused Dependencies and Update Deployment/Documentation

**Files:**

- Create: `firmware/README.md`
- Modify: `backend/pyproject.toml`
- Modify: `backend/uv.lock`
- Modify: `backend/app/core/config.py`
- Modify: `backend/.env.example`
- Modify: `cloudbuild.yaml`
- Modify: `.github/workflows/deploy-web.yml`
- Modify: `README.md`
- Modify: `backend/README.md`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-05-22-iot-gadget-pairing-design.md`
- Modify: `docs/superpowers/plans/2026-05-22-iot-gadget-pairing.md`
- Modify: `docs/superpowers/specs/2026-05-30-community-forum-design.md`

**Interfaces:**

- Removes: `Settings.gemini_api_key`.
- Removes: runtime dependencies `google-genai` and `apscheduler`.
- Documents: `IOT_FEATURE_ENABLED=false` as the deployed default.

- [ ] **Step 1: Add failing dependency/config assertions**

Extend `backend/tests/test_config.py`:

```python
def test_iot_is_disabled_and_unused_gemini_setting_is_absent() -> None:
    configured = Settings(_env_file=None)
    assert configured.iot_feature_enabled is False
    assert not hasattr(configured, "gemini_api_key")
```

Run:

```bash
cd backend
uv run pytest tests/test_config.py -q
```

Expected: FAIL because `gemini_api_key` still exists.

- [ ] **Step 2: Remove unused settings and dependencies**

Delete `gemini_api_key` from settings and any example environment entry. Remove
`google-genai` and `apscheduler` from `project.dependencies`. Remove the
duplicate `psycopg[binary]` declaration while preserving the stricter
`>=3.2.0` constraint.

Regenerate the lockfile:

```bash
cd backend
uv lock
uv sync --extra dev
```

Expected: lock succeeds and neither removed package is present as a direct or
transitive dependency required only by this project.

- [ ] **Step 3: Make disabled deployment explicit**

In Cloud Run deployment environment variables, include:

```yaml
--set-env-vars=DATA_DIR=/data,APP_ENV=prod,IOT_FEATURE_ENABLED=false
```

Change the Firebase web build command to:

```yaml
run: flutter build web --release --dart-define=IOT_FEATURE_ENABLED=false
```

- [ ] **Step 4: Rewrite current documentation to match the code**

The root README must state:

- active product: 2022 proposal-based quiz, current-deputy official evidence,
  anonymous community, and official weekly news;
- quiz responses are stored by anonymous UUID when submitted by the app;
- physical IoT is dormant and invisible by default;
- enabling both flags is for historical development only and does not provide
  a completed alignment engine or production scheduler;
- complete active endpoint families and verification commands.

`backend/README.md` must document all active API families, the private bearer
UUID/public alias split, post and comment moderation/rate limits, the default
flag, and current environment variables.

`CLAUDE.md` must remove claims that the present quiz scores voting records,
that a consistency index exists, that quiz responses are not persisted, and
that a batch Gemini pipeline is implemented. Describe Groq moderation as a
synchronous post/comment gate and Câmara/GNews as separate integrations.

- [ ] **Step 5: Mark historical documents and firmware accurately**

Prepend both 2026-05-22 IoT documents with:

```markdown
> **Status: dormant historical design.** The physical IoT feature is disabled
> by default as of 2026-09-09. Current behavior is defined by
> `2026-09-09-disable-iot-and-close-gaps-design.md`; this file is retained as a
> record of the original implementation.
```

Correct the community design's identity wording from hardware `device_token`
to local `anonymous_id` UUID. Create `firmware/README.md` stating that firmware
is retained but unsupported in current deployments, requires both backend and
Flutter flags plus an external one-shot job invocation, and has no automatic
deployment.

- [ ] **Step 6: Audit documentation and dependency references**

Run:

```bash
rg -n "GEMINI_API_KEY|google-genai|APScheduler|quiz responses not persisted|não.*persist" README.md backend/README.md CLAUDE.md backend/.env.example backend/pyproject.toml
rg -n "IoT|MQTT|ESP32|Arduino|gadget|hardware|Farol físico" README.md backend/README.md CLAUDE.md firmware/README.md docs/superpowers
rg -n "anonymous_id|author_alias|IOT_FEATURE_ENABLED" README.md backend/README.md CLAUDE.md backend/.env.example firmware/README.md
```

Expected: the first command has no stale matches; IoT matches are confined to
explicit dormant/historical explanations; identity and flag terms appear in
current documentation.

- [ ] **Step 7: Run config tests and commit docs/dependency/deployment work**

```bash
cd backend
uv run pytest tests/test_config.py -q
cd ..
git add backend/pyproject.toml backend/uv.lock backend/app/core/config.py backend/.env.example cloudbuild.yaml .github/workflows/deploy-web.yml README.md backend/README.md CLAUDE.md firmware/README.md
git add -f docs/superpowers/specs/2026-05-22-iot-gadget-pairing-design.md docs/superpowers/plans/2026-05-22-iot-gadget-pairing.md docs/superpowers/specs/2026-05-30-community-forum-design.md
git commit -m "docs: align product guidance with dormant hardware"
```

---

### Task 9: Full Verification and Final Review

**Files:**

- Modify only files required to fix failures exposed by the commands below.

**Interfaces:**

- Consumes: all behavior and contracts from Tasks 1–8.
- Produces: a verified repository with no unintended raw identity exposure and
  a default-off hardware surface.

- [ ] **Step 1: Run the complete backend suite**

```bash
cd backend
uv run pytest
```

Expected: all tests pass with coverage at or above 80%.

- [ ] **Step 2: Run complete backend static analysis**

```bash
cd backend
uv run ruff check .
uv run mypy app/
```

Expected: both commands exit 0 without warnings/errors.

- [ ] **Step 3: Verify migrations from an empty database**

Use a temporary SQLite path, never the developer database:

```bash
cd backend
verification_db="$(mktemp -u /tmp/farol-migration-XXXXXX.db)"
DATABASE_URL="sqlite:///$verification_db" uv run alembic upgrade head
DATABASE_URL="sqlite:///$verification_db" uv run alembic current
rm -f "$verification_db"
```

Expected: upgrade exits 0 and current reports
`0007_iot_event_deduplication (head)`.

- [ ] **Step 4: Run the complete Flutter suite and analysis**

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

Expected: dependency resolution, analysis, and all tests pass.

- [ ] **Step 5: Build the deployed default-off web application**

```bash
cd mobile
flutter build web --release --dart-define=IOT_FEATURE_ENABLED=false
```

Expected: release build exits 0.

- [ ] **Step 6: Smoke-build the recoverable enabled web path**

```bash
cd mobile
flutter build web --release --dart-define=IOT_FEATURE_ENABLED=true
```

Expected: release build exits 0, proving dormant imports/routes still compile.

- [ ] **Step 7: Run repository-wide audits**

```bash
git diff --check
rg -n '"anonymous_id"\s*:' backend/app/api/schemas mobile/lib/features/community
rg -n '^from app\.infrastructure|^import app\.infrastructure' backend/app/core
git status --short
```

Expected: no whitespace errors; no community response/model credential field;
no core-to-infrastructure imports; status contains only intentional changes.

- [ ] **Step 8: Review the final diff against the specification**

Read:

```bash
git diff --stat HEAD~8..HEAD
git diff HEAD~8..HEAD -- README.md backend/README.md CLAUDE.md backend/app mobile/lib cloudbuild.yaml .github/workflows/deploy-web.yml
```

Check every acceptance item in the specification against a passing test or a
specific diff hunk. Fix and re-run the relevant full verification command for
any discrepancy.

- [ ] **Step 9: Commit only verification-driven fixes, if any**

```bash
git add backend mobile README.md CLAUDE.md cloudbuild.yaml .github/workflows/deploy-web.yml firmware/README.md
git commit -m "fix: address final verification findings"
```

Skip this commit when verification required no additional edits.
