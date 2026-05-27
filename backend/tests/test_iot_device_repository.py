from datetime import datetime, timedelta, timezone

from app.infrastructure.database.iot_device_repositories import (
    SqlIotDeviceLinkRepository,
    SqlIotPairingSessionRepository,
)
from app.infrastructure.database.models import (
    IotDeviceLinkModel,
    IotPairingSessionModel,
)

TOKEN_000 = "550e8400-e29b-41d4-a716-446655440000"
TOKEN_001 = "550e8400-e29b-41d4-a716-446655440001"
NOW = datetime(2026, 5, 22, tzinfo=timezone.utc)
QR_PAYLOAD_000 = "farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=111111"
QR_PAYLOAD_001 = "farol://pair?device_token=550e8400-e29b-41d4-a716-446655440001&pairing_code=222222"


def _clean(db_session) -> None:
    db_session.query(IotPairingSessionModel).delete()
    db_session.query(IotDeviceLinkModel).delete()
    db_session.commit()


def test_upserts_one_iot_link_per_anonymous_id(db_session) -> None:
    _clean(db_session)
    repo = SqlIotDeviceLinkRepository(db_session)

    first = repo.set_link("anon-1", TOKEN_000, now=NOW)
    second = repo.set_link("anon-1", TOKEN_001, now=NOW + timedelta(seconds=1))

    assert first.device_token == TOKEN_000
    assert second.device_token == TOKEN_001
    assert repo.get_by_anonymous_id("anon-1").device_token == TOKEN_001
    assert repo.get_by_token(TOKEN_000) is None


def test_refuses_token_linked_to_other_anonymous_id(db_session) -> None:
    _clean(db_session)
    repo = SqlIotDeviceLinkRepository(db_session)
    repo.set_link("anon-1", TOKEN_000, now=NOW)

    conflict = repo.get_conflicting_link("anon-2", TOKEN_000)

    assert conflict is not None
    assert conflict.anonymous_id == "anon-1"


def test_set_link_allows_repair_by_different_anonymous_id(db_session) -> None:
    _clean(db_session)
    repo = SqlIotDeviceLinkRepository(db_session)
    repo.set_link("anon-1", TOKEN_000, now=NOW)

    result = repo.set_link("anon-2", TOKEN_000, now=NOW + timedelta(seconds=1))

    assert result.anonymous_id == "anon-2"
    assert result.device_token == TOKEN_000
    assert repo.get_by_token(TOKEN_000).anonymous_id == "anon-2"
    assert repo.get_by_anonymous_id("anon-1") is None


def test_pairing_session_lifecycle(db_session) -> None:
    _clean(db_session)
    repo = SqlIotPairingSessionRepository(db_session)
    session = repo.create_session(
        TOKEN_000,
        "hash-000",
        QR_PAYLOAD_000,
        "1.0.0",
        NOW,
        NOW + timedelta(minutes=10),
    )

    active = repo.get_active_session(TOKEN_000, "hash-000", now=NOW)
    repo.consume_session(session.id, now=NOW + timedelta(seconds=1))

    assert active is not None
    assert active.device_token == TOKEN_000
    assert active.pairing_code_hash == "hash-000"
    assert repo.get_active_session(TOKEN_000, "hash-000", now=NOW) is None


def test_new_pairing_session_invalidates_previous_active_sessions(db_session) -> None:
    _clean(db_session)
    repo = SqlIotPairingSessionRepository(db_session)
    repo.create_session(
        device_token=TOKEN_000,
        pairing_code_hash="old-hash-000",
        qr_payload=QR_PAYLOAD_000,
        firmware_version=None,
        now=NOW,
        expires_at=NOW + timedelta(minutes=10),
    )
    repo.create_session(
        device_token=TOKEN_000,
        pairing_code_hash="new-hash-000",
        qr_payload=QR_PAYLOAD_001,
        firmware_version="1.0.1",
        now=NOW + timedelta(seconds=1),
        expires_at=NOW + timedelta(minutes=10),
    )

    assert repo.get_active_session(TOKEN_000, "old-hash-000", now=NOW) is None
    assert repo.get_active_session(TOKEN_000, "new-hash-000", now=NOW) is not None
