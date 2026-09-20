from datetime import datetime, timezone

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


@pytest.mark.parametrize("date_field", ["dataHoraRegistro", "data"])
@pytest.mark.parametrize("timestamp,included", [
    ("2026-09-09", True),
    ("2026-09-08", False),
    ("2026-09-09T00:00:00", True),
    ("2026-09-08T23:59:59", False),
    ("2026-09-09T02:59:59", True),
    ("2026-09-09T03:00:00Z", True),
    ("2026-09-09T02:59:59Z", False),
    ("2026-09-09T05:00:00+02:00", True),
    ("2026-09-09T04:59:59+02:00", False),
    ("2026-09-08T23:00:00-04:00", True),
])
def test_camara_dates_use_sao_paulo_unless_offset_explicit(
    monkeypatch, date_field, timestamp, included,
):
    from app.infrastructure import scheduler

    class Camara:
        def list_recent_votings(self, scan_limit):
            return [{
                "id": "123", "uri": "https://dadosabertos.camara.leg.br/api/v2/votacoes/123",
                "descricao": "Aprovação da proposta", date_field: timestamp,
            }]

        def list_votes_for_voting(self, voting_id):
            return [{
                "tipoVoto": "Sim", "dataRegistroVoto": "2026-09-09T00:00:00",
                "deputado_": {
                    "id": 456, "nome": "Deputy", "siglaPartido": "ABC", "siglaUf": "SP",
                    "uri": "https://dadosabertos.camara.leg.br/api/v2/deputados/456",
                },
            }]

    monkeypatch.setattr(scheduler, "CamaraClient", Camara)
    votes = scheduler._fetch_recent_votes_for_actor(
        "456", datetime(2026, 9, 9, 3, tzinfo=timezone.utc),
    )
    assert [vote["voting_id"] for vote in votes] == (["123"] if included else [])


def test_job_preserves_partial_count_and_continues_later_actors(monkeypatch):
    from app.infrastructure import scheduler

    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine)
    with sessions() as db:
        for actor_id, source_id in ((10, "456"), (20, "789")):
            db.add(PoliticalActorModel(
                id=actor_id, source="camara", source_id=source_id, normalized_name="deputy",
                display_name="Deputy", role="deputado_federal",
            ))
        for index in (1, 2, 3, 4):
            db.add(FollowedActorModel(
                anonymous_id=f"anon-{index}", political_actor_id=10 if index < 4 else 20,
            ))
            db.add(IotDeviceLinkModel(
                device_token=f"tok-{index}", anonymous_id=f"anon-{index}", status="linked",
            ))
        db.commit()

    published = []
    attempts = []

    class Publisher:
        def publish(self, topic, payload):
            with sessions() as db:
                reservation = db.scalar(select(IotDeviceEventModel).where(
                    IotDeviceEventModel.device_token == topic.removeprefix("farol/"),
                    IotDeviceEventModel.deduplication_key == payload["source_event_id"],
                ))
                assert reservation is not None
            attempts.append(topic)
            if topic == "farol/tok-2":
                raise RuntimeError("broker failure")
            published.append((topic, payload["source_event_id"]))

    class Camara:
        def list_recent_votings(self, scan_limit):
            return [{"id": "123", "descricao": "Proposal", "dataHoraRegistro": "2099-01-01"}]

        def list_votes_for_voting(self, voting_id):
            return [
                {"deputado_": {"id": 456, "nome": "Deputy A"}, "tipoVoto": "Sim"},
                {"deputado_": {"id": 789, "nome": "Deputy B"}, "tipoVoto": "Não"},
            ]

    monkeypatch.setattr(scheduler.settings, "iot_feature_enabled", True)
    monkeypatch.setattr(scheduler, "SessionLocal", sessions)
    monkeypatch.setattr(scheduler, "CamaraClient", Camara)
    monkeypatch.setattr(scheduler, "PahoIotMqttPublisher", Publisher)
    assert scheduler.run_once() == 3
    assert attempts == ["farol/tok-1", "farol/tok-2", "farol/tok-3", "farol/tok-4"]
    assert published == [
        ("farol/tok-1", "vote:123:456"),
        ("farol/tok-3", "vote:123:456"),
        ("farol/tok-4", "vote:123:789"),
    ]
    assert scheduler.run_once() == 0
    assert len(attempts) == 4
    with sessions() as db:
        assert len(list(db.scalars(select(IotDeviceEventModel)))) == 4
    engine.dispose()


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
