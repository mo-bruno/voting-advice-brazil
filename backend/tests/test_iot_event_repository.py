from datetime import datetime, timezone

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.infrastructure.database.iot_device_repositories import (
    SqlIotDeviceEventRepository,
)
from app.infrastructure.database.models import Base


def _db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return engine


def test_record_and_get_latest():
    engine = _db()
    with Session(engine) as session:
        repo = SqlIotDeviceEventRepository(session)
        now = datetime.now(timezone.utc)

        event = repo.record("tok1", "vote_alert", {"foo": "bar"}, now)

        assert event.device_token == "tok1"
        assert event.event_type == "vote_alert"
        assert event.payload == {"foo": "bar"}

        latest = repo.get_latest("tok1", "vote_alert")
        assert latest is not None
        assert latest.id == event.id


def test_get_latest_returns_none_when_empty():
    engine = _db()
    with Session(engine) as session:
        repo = SqlIotDeviceEventRepository(session)
        assert repo.get_latest("tok1", "vote_alert") is None


def test_record_once_is_persistent_and_scoped_to_device_and_type():
    engine = _db()
    now = datetime.now(timezone.utc)
    with Session(engine) as session:
        repo = SqlIotDeviceEventRepository(session)
        first = repo.record_once("tok1", "vote_alert", "vote:123:456", {"v": "1"}, now)
        assert first is not None
        assert first.deduplication_key == "vote:123:456"
    with Session(engine) as session:
        repo = SqlIotDeviceEventRepository(session)
        assert repo.record_once("tok1", "vote_alert", "vote:123:456", {}, now) is None
        latest = repo.get_latest("tok1", "vote_alert")
        assert latest is not None
        assert latest.id == first.id
        assert latest.payload == {"v": "1"}
        assert latest.deduplication_key == "vote:123:456"
        assert repo.record_once("tok2", "vote_alert", "vote:123:456", {}, now) is not None
        assert repo.record_once("tok1", "news", "vote:123:456", {}, now) is not None
        assert repo.record_once("tok1", "vote_alert", "vote:124:456", {}, now) is not None


def test_legacy_events_without_deduplication_keys_can_still_repeat():
    engine = _db()
    with Session(engine) as session:
        repo = SqlIotDeviceEventRepository(session)
        now = datetime.now(timezone.utc)
        first = repo.record("tok1", "news", {}, now)
        second = repo.record("tok1", "news", {}, now)
        assert first.id != second.id
        assert first.deduplication_key is None
        assert second.deduplication_key is None


def test_get_latest_returns_most_recent():
    from datetime import timedelta

    engine = _db()
    with Session(engine) as session:
        repo = SqlIotDeviceEventRepository(session)
        now = datetime.now(timezone.utc)

        repo.record("tok1", "vote_alert", {"v": "1"}, now - timedelta(minutes=10))
        newer = repo.record("tok1", "vote_alert", {"v": "2"}, now)

        latest = repo.get_latest("tok1", "vote_alert")
        assert latest is not None
        assert latest.id == newer.id
