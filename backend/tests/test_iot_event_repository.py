from datetime import datetime, timezone

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.infrastructure.database.iot_device_repositories import SqlIotDeviceEventRepository
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
