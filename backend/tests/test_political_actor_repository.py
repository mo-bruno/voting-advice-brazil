from datetime import datetime, timedelta, timezone

import pytest

from app.infrastructure.database.models import (
    FollowedActorModel,
    OfficialEvidenceModel,
    PoliticalActorModel,
)
from app.infrastructure.database.political_actor_repositories import (
    SqlFollowedActorRepository,
    SqlPoliticalActorRepository,
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


def _actor(
    source_id: str,
    name: str,
    party: str,
    state: str,
) -> PoliticalActorModel:
    return PoliticalActorModel(
        source="camara",
        source_id=source_id,
        normalized_name=name.lower(),
        display_name=name,
        party=party,
        state=state,
        role="federal_deputy",
        status="active",
        photo_url=f"https://example.com/{source_id}.jpg",
        source_url=(
            f"https://dadosabertos.camara.leg.br/api/v2/deputados/{source_id}"
        ),
        last_indexed_at=datetime.now(timezone.utc),
    )


def test_searches_actors_by_name_party_and_state(db_session):
    db_session.add_all([
        _actor("101", "Maria Silva", "PT", "SP"),
        _actor("102", "Joao Pereira", "PSD", "MG"),
    ])
    db_session.commit()

    repo = SqlPoliticalActorRepository(db_session)

    by_name, total_name = repo.list(search="maria", page=1, page_size=10)
    by_party, total_party = repo.list(party="PSD", page=1, page_size=10)
    by_state, total_state = repo.list(state="SP", page=1, page_size=10)

    assert total_name == 1
    assert by_name[0].display_name == "Maria Silva"
    assert total_party == 1
    assert by_party[0].display_name == "Joao Pereira"
    assert total_state == 1
    assert by_state[0].state == "SP"


def test_upsert_by_source_identity_updates_existing_actor(db_session):
    repo = SqlPoliticalActorRepository(db_session)
    now = datetime.now(timezone.utc)

    created = repo.upsert_index([
        {
            "source": "camara",
            "source_id": "101",
            "normalized_name": "maria silva",
            "display_name": "Maria Silva",
            "party": "PT",
            "state": "SP",
            "role": "federal_deputy",
            "status": "active",
            "photo_url": None,
            "source_url": (
                "https://dadosabertos.camara.leg.br/api/v2/deputados/101"
            ),
            "last_indexed_at": now,
        }
    ])
    updated = repo.upsert_index([
        {
            "source": "camara",
            "source_id": "101",
            "normalized_name": "maria silva",
            "display_name": "Maria Silva",
            "party": "PSB",
            "state": "SP",
            "role": "federal_deputy",
            "status": "active",
            "photo_url": None,
            "source_url": (
                "https://dadosabertos.camara.leg.br/api/v2/deputados/101"
            ),
            "last_indexed_at": now + timedelta(minutes=1),
        }
    ])

    assert created == 1
    assert updated == 1
    actor = repo.get_by_source("camara", "101")
    assert actor is not None
    assert actor.party == "PSB"


def test_follow_replaces_existing_actor_for_anonymous_context(db_session):
    a = _actor("101", "Maria Silva", "PT", "SP")
    b = _actor("102", "Joao Pereira", "PSD", "MG")
    db_session.add_all([a, b])
    db_session.commit()

    follow_repo = SqlFollowedActorRepository(db_session)
    first = follow_repo.set_followed("anon-1", a.id)
    second = follow_repo.set_followed("anon-1", b.id)

    assert first.political_actor_id == a.id
    assert second.political_actor_id == b.id
    assert follow_repo.get_followed("anon-1").political_actor_id == b.id


def test_trending_requires_minimum_threshold(db_session):
    a = _actor("101", "Maria Silva", "PT", "SP")
    b = _actor("102", "Joao Pereira", "PSD", "MG")
    db_session.add_all([a, b])
    db_session.commit()
    follow_repo = SqlFollowedActorRepository(db_session)
    follow_repo.set_followed("anon-1", a.id)
    follow_repo.set_followed("anon-2", a.id)
    follow_repo.set_followed("anon-3", b.id)

    trending = follow_repo.list_trending(limit=10, min_followers=2)

    assert [item.actor.display_name for item in trending] == ["Maria Silva"]
