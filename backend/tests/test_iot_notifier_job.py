import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.infrastructure.database.models import (
    Base,
    FollowedActorModel,
    IotDeviceEventModel,
    IotDeviceLinkModel,
    PoliticalActorModel,
)


@pytest.mark.parametrize("vote", ["Abstenção", "ABSTENCAO", "Abstention"])
def test_camara_abstentions_are_yellow(vote: str) -> None:
    from app.infrastructure import scheduler

    assert scheduler._alignment_for_vote(vote) == "abstained"


@pytest.mark.parametrize("vote", ["Sim", "Não", "Obstrução", "", "unknown", "aligned"])
def test_unmapped_votes_are_pending(vote: str) -> None:
    from app.infrastructure import scheduler

    assert scheduler._alignment_for_vote(vote) == "pending"


def test_disabled_job_does_not_open_database_or_publish(monkeypatch):
    from app.infrastructure import scheduler

    def unexpected_work():
        pytest.fail("disabled job must not start work")

    monkeypatch.setattr(scheduler.settings, "iot_feature_enabled", False)
    monkeypatch.setattr(scheduler, "SessionLocal", unexpected_work)
    monkeypatch.setattr(scheduler, "PahoIotMqttPublisher", unexpected_work)
    assert scheduler.run_once() == 0


def test_enabled_job_returns_published_vote_count(monkeypatch):
    from app.infrastructure import scheduler

    monkeypatch.setattr(scheduler.settings, "iot_feature_enabled", True)
    monkeypatch.setattr(scheduler, "_run_vote_notifier_job", lambda: 3)
    assert scheduler.run_once() == 3


def test_job_publishes_each_source_vote_once_per_device(monkeypatch):
    from app.infrastructure import scheduler

    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine)
    with sessions() as db:
        db.add(PoliticalActorModel(
            id=10, source="camara", source_id="456", normalized_name="deputy",
            display_name="Deputy", role="deputado_federal",
        ))
        for index in (1, 2):
            db.add(FollowedActorModel(anonymous_id=f"anon-{index}", political_actor_id=10))
            db.add(IotDeviceLinkModel(
                device_token=f"tok-{index}", anonymous_id=f"anon-{index}", status="linked",
            ))
        db.commit()

    published = []

    class Publisher:
        def publish(self, topic, payload):
            published.append((topic, payload))

    class Camara:
        def list_recent_votings(self, scan_limit):
            return [
                {"id": "123", "descricao": "Proposal"},
                {"id": "124", "descricao": "Other proposal"},
            ]

        def list_votes_for_voting(self, voting_id):
            return [{
                "deputado_": {"id": 456, "nome": "Deputy"},
                "tipoVoto": "Sim" if voting_id == "123" else "Abstenção",
            }]

    monkeypatch.setattr(scheduler.settings, "iot_feature_enabled", True)
    monkeypatch.setattr(scheduler, "SessionLocal", sessions)
    monkeypatch.setattr(scheduler, "CamaraClient", Camara)
    monkeypatch.setattr(scheduler, "PahoIotMqttPublisher", Publisher)
    assert scheduler.run_once() == 4
    assert scheduler.run_once() == 0
    assert len(published) == 4
    assert {(topic, payload["source_event_id"], payload["alignment"], payload["color"])
            for topic, payload in published} == {
        ("farol/tok-1", "vote:123:456", "pending", "blue"),
        ("farol/tok-2", "vote:123:456", "pending", "blue"),
        ("farol/tok-1", "vote:124:456", "abstained", "yellow"),
        ("farol/tok-2", "vote:124:456", "abstained", "yellow"),
    }
    with sessions() as db:
        events = list(db.scalars(select(IotDeviceEventModel)))
        assert len(events) == 4
        assert {event.deduplication_key for event in events} == {"vote:123:456", "vote:124:456"}
    engine.dispose()
