from datetime import datetime, timedelta, timezone

import pytest

from app.infrastructure.database.models import (
    FollowedActorModel,
    OfficialEvidenceModel,
    PoliticalActorModel,
)


@pytest.fixture(autouse=True)
def clean_political_actor_tables(db_session):
    db_session.query(FollowedActorModel).delete()
    db_session.query(OfficialEvidenceModel).delete()
    db_session.query(PoliticalActorModel).delete()
    db_session.commit()
    yield
    db_session.query(FollowedActorModel).delete()
    db_session.query(OfficialEvidenceModel).delete()
    db_session.query(PoliticalActorModel).delete()
    db_session.commit()


def _seed_actor(db_session, source_id="101", name="Maria Silva"):
    actor = PoliticalActorModel(
        source="camara",
        source_id=source_id,
        normalized_name=name.lower(),
        display_name=name,
        party="PT",
        state="SP",
        role="federal_deputy",
        status="active",
        photo_url=None,
        source_url=(
            f"https://dadosabertos.camara.leg.br/api/v2/deputados/{source_id}"
        ),
        last_indexed_at=datetime.now(timezone.utc),
    )
    db_session.add(actor)
    db_session.commit()
    return actor


def test_lists_political_actors(client, db_session):
    _seed_actor(db_session)

    response = client.get("/api/v1/political-actors?search=maria")

    assert response.status_code == 200
    data = response.json()
    assert data["total_count"] == 1
    assert data["actors"][0]["display_name"] == "Maria Silva"
    assert data["actors"][0]["role"] == "federal_deputy"


def test_returns_trending_only_when_threshold_is_met(client, db_session):
    actor = _seed_actor(db_session)
    headers = {"X-Farol-Anonymous-Id": "anon-1"}
    client.put(
        "/api/v1/me/followed-actor",
        json={"political_actor_id": actor.id},
        headers=headers,
    )

    low = client.get("/api/v1/political-actors/trending")
    assert low.status_code == 200
    assert low.json()["actors"] == []

    client.put(
        "/api/v1/me/followed-actor",
        json={"political_actor_id": actor.id},
        headers={"X-Farol-Anonymous-Id": "anon-2"},
    )

    high = client.get("/api/v1/political-actors/trending")
    assert high.status_code == 200
    assert high.json()["actors"][0]["actor"]["id"] == actor.id
    assert "follow_count" not in high.json()["actors"][0]


def test_follow_get_and_delete_actor(client, db_session):
    actor = _seed_actor(db_session)
    headers = {"X-Farol-Anonymous-Id": "anon-follow"}

    put = client.put(
        "/api/v1/me/followed-actor",
        json={"political_actor_id": actor.id},
        headers=headers,
    )
    get = client.get("/api/v1/me/followed-actor", headers=headers)
    delete = client.delete("/api/v1/me/followed-actor", headers=headers)
    after = client.get("/api/v1/me/followed-actor", headers=headers)

    assert put.status_code == 200
    assert get.json()["political_actor"]["id"] == actor.id
    assert delete.status_code == 204
    assert after.status_code == 404


def test_follow_requires_anonymous_header(client, db_session):
    actor = _seed_actor(db_session)

    response = client.put(
        "/api/v1/me/followed-actor",
        json={"political_actor_id": actor.id},
    )

    assert response.status_code == 422


def test_returns_cached_evidence_with_freshness_flag(client, db_session):
    actor = _seed_actor(db_session)
    now = datetime.now(timezone.utc)
    db_session.add(
        OfficialEvidenceModel(
            political_actor_id=actor.id,
            source="camara",
            source_id="proposition:9001",
            evidence_type="proposition",
            title="Apresentou PL 123/2026",
            summary="Proposta oficial registrada na Camara.",
            evidence_date=now,
            source_url="https://dadosabertos.camara.leg.br/api/v2/proposicoes/9001",
            normalized_payload={"sigla_tipo": "PL"},
            fetched_at=now,
            expires_at=now + timedelta(hours=12),
        )
    )
    db_session.commit()

    response = client.get(f"/api/v1/political-actors/{actor.id}/evidence")

    assert response.status_code == 200
    data = response.json()
    assert data["cache_status"] == "fresh"
    assert data["evidence"][0]["title"] == "Apresentou PL 123/2026"
