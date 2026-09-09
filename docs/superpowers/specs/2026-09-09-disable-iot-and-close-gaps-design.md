# Disable IoT and Close Security Gaps — Design

**Date:** 2026-09-09

**Status:** Approved for implementation

**Project:** Farol Político

## Objective

Make the physical IoT feature dormant and invisible by default while retaining
its implementation for a possible future revival. At the same time, close the
known anonymous-identity, community-integrity, architecture, scheduling, and
documentation gaps discovered during the repository review.

The Farol Político product name remains unchanged. The web/mobile voting-advice
application, political-actor tracking, official evidence, community, and news
feed remain active.

## Scope

This change covers:

- a default-off IoT feature flag in FastAPI and Flutter;
- removal of the in-process APScheduler lifecycle from the API;
- safe, deduplicated semantics for dormant vote notifications;
- removal of raw anonymous credentials from public API responses;
- moderation and database-backed rate limiting for comments;
- rejection of votes and comments on removed posts;
- restoration of the dependency direction promised by Clean Architecture;
- removal of unused Gemini configuration and dependency declarations;
- correction of current and historical documentation;
- regression tests for disabled and enabled paths.

Existing IoT tables and Alembic migrations remain in place. No migration drops
hardware data. Firmware source remains in the repository as dormant code.

## Feature Flag

### Backend

Add `IOT_FEATURE_ENABLED: bool = false` to `Settings` and document it in
`backend/.env.example`.

FastAPI application construction becomes explicit through `create_app()`. It
registers `/api/v1/iot-devices/*` and `/api/v1/me/iot-device*` only when the
flag is true. With the default value, those routes do not exist and are absent
from OpenAPI.

Quiz responses continue to be persisted when a device UUID is supplied. The
optional hardware-news push after quiz submission runs only when the flag is
true. No MQTT client is created while the flag is false.

The API lifespan continues to seed static application data, but never starts a
process-local scheduler. The former scheduled notifier becomes a one-shot job
entry point that checks `IOT_FEATURE_ENABLED` before doing any work. A future
deployment may invoke that job from an external scheduler; the disabled
production deployment does not schedule it.

### Flutter

Add a compile-time flag using:

```dart
const bool kIotFeatureEnabled = bool.fromEnvironment(
  'IOT_FEATURE_ENABLED',
  defaultValue: false,
);
```

When false:

- IoT device and pairing routes are not added to `MaterialApp.routes`;
- the drawer does not instantiate the IoT session or render hardware state;
- quiz answers do not send IoT pulse requests;
- no visible copy suggests that a physical device is available.

The flag can be injected into route/drawer construction in tests so both states
are verifiable without maintaining separate test suites. Existing direct tests
of dormant IoT widgets and models may remain.

### Deployment and Firmware

Cloud Build sets `IOT_FEATURE_ENABLED=false` explicitly for Cloud Run. The
Firebase web build supplies
`--dart-define=IOT_FEATURE_ENABLED=false` explicitly.

Firmware source stays under `firmware/`. Its workflow remains path-filtered and
therefore runs only when dormant firmware files or the firmware workflow are
changed. There is no firmware deployment step.

## Anonymous Identity Boundary

`X-Farol-Anonymous-Id` remains a locally generated UUID v4 bearer credential.
The backend validates the UUID format consistently wherever the header is
required. The raw value remains stored in private database columns because it
is needed for ownership, following, rate limiting, and optional IoT linkage.

The raw credential must never appear in post or comment responses. Replace it
with:

- `author_alias`: a deterministic, non-reversible public pseudonym derived from
  the SHA-256 digest of the UUID and displayed as `u/<digest-prefix>`;
- `is_mine`: a boolean computed by comparing the authenticated request header
  with the stored owner ID.

Community list and detail requests accept the anonymous header so `is_mine` is
accurate for the current client. If the header is absent, `is_mine` is false.
Create, vote, comment, report, delete, follow, and optional IoT operations still
require the header.

Flutter community models and widgets consume `author_alias` and `is_mine`.
They never receive or compare another user's bearer credential.

This design prevents credential copying and author impersonation. It does not
claim to prevent a person from generating many independent anonymous UUIDs; IP
rate limiting remains the secondary anti-abuse layer for that threat.

## Community Integrity

### Comment moderation

Comments pass through the same moderation port used by posts before they are
persisted. An unavailable required moderation service returns HTTP 503. A
rejected comment returns HTTP 422 with the moderator's short reason. Moderation
logs store the parent post ID, author credential, content hash, decision,
reason, and model without storing a second copy of comment content.

### Comment rate limit

Comments use a database-backed limit of 10 accepted comments per anonymous
credential in a rolling 10-minute window. This is separate from the existing
post limit of 5 posts per 10 minutes. Exceeding it returns HTTP 429 with a
`Retry-After: 600` header. Rejected comments do not consume the accepted-comment
quota because they are not persisted.

### Removed posts

Fetching a removed post still returns its tombstone and existing discussion.
Creating a new vote or comment on a removed post returns HTTP 410 Gone. Voting
and commenting use cases distinguish missing posts from removed posts so the
API can retain the existing HTTP 404 behavior for unknown IDs.

## Clean Architecture

Move `ModerationPort` and `ModerationUnavailable` into the core boundary. The
NVIDIA NIM, fake, and unavailable implementations in `infrastructure/llm`
implement and import that core contract. Community use cases import only core
entities and core ports.

The hardware-news use case must likewise avoid type references to the GNews
adapter. A small core entity or protocol represents the title/source/date data
needed by the dormant notifier, and the GNews adapter produces that type.

Add an architecture test that fails if a Python module under `app/core`
imports `app.infrastructure`, FastAPI, SQLAlchemy, HTTPX, Paho MQTT, or
APScheduler.

## Dormant Vote Notification Semantics

There is no trustworthy mapping between a Câmara roll-call vote and a user's
quiz thesis. The code must not label ordinary `Sim` or `Não` votes as aligned,
divergent, or abstentions without that mapping.

When the dormant one-shot notifier is explicitly enabled and invoked:

- Câmara abstention variants map to `abstained` and yellow;
- every other unmapped vote maps to `pending` and blue;
- an explicitly supplied, trusted alignment can still produce green or red;
- each Câmara vote carries a stable source event ID based on voting ID and
  deputy source ID;
- the same source event is published at most once per linked device.

Add a nullable deduplication key to IoT device events with a uniqueness rule
covering device token, event type, and deduplication key. Existing event rows
remain valid. The notifier checks/reserves this key so rescanning a Câmara time
window cannot create repeated alerts.

Because the API no longer embeds APScheduler, Cloud Run scaling cannot create
duplicate per-instance scheduler loops and scale-to-zero cannot silently pause
an advertised in-process schedule.

## Dependency Cleanup

Remove `google-genai` and `GEMINI_API_KEY`; neither has an implemented runtime
consumer. Remove APScheduler after converting the notifier to a one-shot job.
Regenerate `backend/uv.lock`. Keep Paho MQTT and GNews configuration because
they remain part of the optional flag-enabled implementation.

## Documentation

Update:

- the root README with the active product capabilities, accurate setup,
  complete verification commands, and an explicit dormant-IoT section;
- `backend/README.md` with all active API families, identity behavior, feature
  flags, moderation, and deployment-relevant environment variables;
- `CLAUDE.md` with current phase status, persisted anonymous quiz responses,
  actual LLM usage, and the absence of a completed consistency index;
- `backend/.env.example` with the default-off IoT flag and without Gemini;
- the community design document so it uses `anonymous_id` rather than calling
  that mobile identity a hardware `device_token`;
- historical IoT design and implementation-plan documents with a prominent
  retired/dormant status banner instead of rewriting their historical content;
- a firmware README stating that hardware is dormant, unsupported in current
  deployments, and gated by the application feature flag.

The public API summary in the root README must describe quiz, candidates,
themes, political actors, community, news, and health. IoT endpoints belong
only in the dormant feature section.

## Compatibility and Migration

The feature flag defaults to false, so deployment is fail-closed even if an
environment omits the new variable. Existing production IoT tables and rows are
preserved. The new nullable deduplication column does not invalidate historical
rows.

Removing `anonymous_id` from community responses is an intentional API contract
change. Backend and Flutter changes ship together. Database ownership columns,
the header name, and locally stored UUIDs do not change.

## Error Behavior

- Disabled IoT paths: HTTP 404 because routes are not registered.
- Missing anonymous credential on protected operations: HTTP 422 under FastAPI
  header validation.
- Invalid/non-v4 anonymous credential: HTTP 422.
- Moderation unavailable: HTTP 503.
- Moderation rejection: HTTP 422.
- Community publication limit exceeded: HTTP 429 with `Retry-After`.
- Missing post: HTTP 404.
- Vote or comment on removed post: HTTP 410.

## Verification

Backend verification:

```bash
cd backend
uv sync --extra dev
uv run pytest
uv run ruff check .
uv run mypy app/
uv run alembic upgrade head
```

Mobile verification:

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=IOT_FEATURE_ENABLED=false
```

Firmware verification remains the existing conditional PlatformIO build when
firmware files change.

Acceptance requires tests proving:

- IoT routes and UI are absent by default and available when explicitly
  enabled;
- disabled quiz flows create no MQTT or hardware-news work;
- raw anonymous credentials never appear in community responses;
- public aliases are stable and ownership flags are correct;
- comment moderation and comment rate limiting reject the intended cases;
- removed posts reject new votes and comments;
- core modules have no infrastructure imports;
- unmapped votes are pending, abstentions are abstained, and repeated source
  events are not republished;
- migration from the previous Alembic head preserves existing tables and data;
- current documentation contains no claim that the physical feature is active
  or that the consistency index is implemented.
