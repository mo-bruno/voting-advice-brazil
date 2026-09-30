# CLAUDE.md

Repository guidance for coding agents. Farol Político is a Brazilian voting-advice academic project at Mackenzie University.

## Current product

The active quiz compares weighted answers against the 2026 presidential plans using City Block Distance. The current edition has 30 active theses and thirteen candidacies, with documentary citations. Only explicit categorical positions affect scores; silence, conditional positions and insufficient evidence do not imply agreement or disagreement. The calculation uses only questions answered by the user for which the candidacy has a documented categorical position, retaining the user's weights. Agreement on all nine comparable answers yields 100%, even if the user answered 30 questions.

The main results screen displays each candidate's photo, name, party and percentage, ordered from highest to lowest percentage. Candidates without comparable answers display `—` and appear last. Cards omit coverage counts and lengthy explanations; evidence coverage, missing positions, sources and excerpts remain available in the answer comparison screen. The results do not recommend a vote. The public political-following entry points currently show a demand-validation page without name or contact details; its locally retained identifier is pseudonymous. Search, profiles, evidence and one-actor follow code are retained behind `POLITICIAN_FOLLOW_ENABLED=false`; existing data is preserved. The app also provides a community under stable pseudonymous aliases and official weekly news. Legislative evidence does not feed the quiz score.

The API's optional quiz field is still named `device_id` and may carry the app's local UUID v4. With `IOT_FEATURE_ENABLED=false`, the backend calculates results without persisting answers or creating or updating `devices`, even if a legacy client supplies `device_id`. With IoT enabled, a supplied ID retains the historical persistence and push behavior. The UUID remains in use for community and follow actions.

## Architecture and integrations

- `backend/app/core/`: framework-free entities, scoring, use cases and ports. Do not introduce FastAPI, SQLAlchemy, Pydantic Settings or vendor clients here.
- `backend/app/config.py`: application settings, outside core.
- `backend/app/api/`: HTTP validation, private identity headers, public response projection and dependency wiring.
- `backend/app/infrastructure/`: database, NVIDIA NIM moderation and official-source adapters, plus retained dormant integrations.
- `mobile/lib/`: Flutter features and shared API/models. Treat response shapes strictly; do not restore fallback parsing of public private-identity fields.
- `data/`: checked-in presidential 2026 proposals, versioned theses, documentary review and official photos; historical 2022 data is preserved.

NVIDIA NIM is a synchronous moderation gate on post/comment creation, with audited decisions. It rejects off-topic content, clearly fabricated or manipulative claims, and attacks against people or groups such as directed insults, sexual humiliation, threats, incitement to violence, harassment and hate speech. Harsh criticism of policies and public acts remains allowed when it does not attack people. The default model is `nvidia/nemotron-3-super-120b-a12b`; `MODERATION_MODE=enforce` is the default, missing credentials or provider failures fail publication with 503, and rejected content returns 422. `disabled` explicitly bypasses the model for local development. No batch generative analysis pipeline is implemented.

Câmara's official APIs provide deputies/evidence, and its official news source provides `/news/weekly`. These are separate from the retained GNews integration for historical physical-device news. Do not describe GNews as the current weekly feed or LLM output as verified legislative alignment.

## Identity and community contract

`anonymous_id` is a locally generated UUID v4, not a hardware identifier. It is a private bearer credential in `X-Farol-Anonymous-Id` for `/me/...` and community writes. Community reads accept the header optionally. Public post/comment payloads expose `author_alias` and `is_mine`; never publish the UUID or use the alias as a write credential. This is possession-based access without accounts, recovery or one-person-one-identity enforcement.

The demand-validation interest uses a separate local UUID; the contextual database hash is one-way, while the browser holding the UUID can reproduce it to consult or delete its row. Deduplicated active database rows are the demand source of truth. GA funnel events cover only opt-in visitors. Withdrawal deletes the interest and operational retention is capped at 180 days. Posts and comments may reveal political opinion, are stored and publicly displayed under a stable alias, and are sent to NVIDIA NIM for moderation. Removing a post replaces its content with a tombstone and preserves comments; comment-removal and other applicable rights requests go to `privacidade@fpolitico.com.br`. Functional community retention follows necessity for the feature, security, legal duties and rights, not a fixed global period.

Posts allow 500 characters and five publications per ten minutes; comments allow 300 characters and ten publications per ten minutes. Counts are persisted per identity; 429 includes `Retry-After: 600`. Removed posts still count toward publication quota. New votes and comments on removed posts return 410; unknown posts return 404. The author can soft-delete a post, other identities receive 403. Reports are deduplicated and may trigger remoderation. General IP throttling is in-process, not distributed.

## Dormant historical IoT

Physical IoT is disabled and hidden by default. Backend `IOT_FEATURE_ENABLED=false` prevents registration of pairing/device routes and guards external side effects. Flutter's compile-time `IOT_FEATURE_ENABLED=false` hides hardware entry points and prevents background device-status access. Cloud Build and Firebase builds explicitly pass false.

MQTT, ESP32/Arduino firmware and GNews source code are retained for historical development only. Enabling both flags is unsupported for current deployments and does not provide a completed alignment engine or production scheduler. `backend/app/infrastructure/scheduler.py` is now a guarded one-shot module run externally via `uv run python -m app.infrastructure.scheduler`; the API lifespan starts no scheduler. The job emits `abstained` for abstentions and `pending` for other votes. Event reservation deduplicates before MQTT publication and suppresses retries after broker failure; it does not guarantee delivery.

Hardware `device_token` belongs only to this dormant pairing/MQTT boundary (`farol/{device_token}`), and must not be confused with `anonymous_id`. Read [firmware/README.md](firmware/README.md) before touching retained firmware. Historical plans describe previous intentions; the [2026-09-09 design](docs/superpowers/specs/2026-09-09-disable-iot-and-close-gaps-design.md) and current code define the present behavior.

## API coverage and verification

Active families are `/health`, `/api/v1/quiz`, `/api/v1/candidates`, `/api/v1/themes`, `/api/v1/political-actors`, `/api/v1/me/politician-follow-interest`, `/api/v1/community/posts` (including votes, comments, reports and author deletion), and `/api/v1/news` (weekly feed and image proxy). `/api/v1/me/followed-actor` is retained but guarded by `POLITICIAN_FOLLOW_ENABLED`. `/docs`, `/redoc`, `/openapi.json` expose the contract; `/data/...` serves public assets when configured.

```bash
cd backend
uv sync --extra dev
uv lock --check
uv run alembic upgrade head
uv run pytest
uv run ruff check .
uv run mypy app/
```

Use `uv run pytest tests/test_config.py -q --no-cov` for focused configuration checks without the full-suite coverage threshold.

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=IOT_FEATURE_ENABLED=false --dart-define=POLITICIAN_FOLLOW_ENABLED=false
```

Keep migrations authoritative for schema changes; startup only performs idempotent seed in development. Production seed is an explicit deployment step; see PUBLICACAO_2026.md for migration, traffic and rollback order. Never claim a deploy or full-suite pass from a source review or a focused test run.
