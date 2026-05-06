from datetime import datetime, timedelta, timezone

import pytest

from app.core.use_cases.ensure_political_actor_index import (
    ensure_political_actor_index,
)
from app.infrastructure.database.models import (
    FollowedActorModel,
    OfficialEvidenceModel,
    PoliticalActorModel,
)
from app.infrastructure.database.political_actor_repositories import (
    SqlPoliticalActorRepository,
)


class FakeDeputyIndexSource:
    def __init__(self) -> None:
        self.calls = 0

    def list_current_deputies_for_index(
        self,
        now: datetime,
    ) -> list[dict[str, object]]:
        self.calls += 1
        return [
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
        ]


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


def test_refreshes_index_when_local_index_is_empty(db_session):
    repo = SqlPoliticalActorRepository(db_session)
    source = FakeDeputyIndexSource()

    refreshed = ensure_political_actor_index(
        repo=repo,
        source=source,
        now=datetime(2026, 5, 6, tzinfo=timezone.utc),
        max_age=timedelta(hours=24),
    )

    actors, total = repo.list(search="maria")
    assert refreshed is True
    assert source.calls == 1
    assert total == 1
    assert actors[0].display_name == "Maria Silva"


def test_skips_refresh_when_index_is_fresh(db_session):
    repo = SqlPoliticalActorRepository(db_session)
    source = FakeDeputyIndexSource()
    now = datetime(2026, 5, 6, tzinfo=timezone.utc)
    repo.upsert_index(source.list_current_deputies_for_index(now))
    source.calls = 0

    refreshed = ensure_political_actor_index(
        repo=repo,
        source=source,
        now=now + timedelta(hours=1),
        max_age=timedelta(hours=24),
    )

    assert refreshed is False
    assert source.calls == 0
