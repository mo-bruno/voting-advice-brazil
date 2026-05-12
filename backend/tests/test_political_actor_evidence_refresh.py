from datetime import datetime, timezone

import pytest

from app.core.use_cases.get_official_evidence import (
    get_or_refresh_official_evidence,
)
from app.infrastructure.database.models import (
    FollowedActorModel,
    OfficialEvidenceModel,
    PoliticalActorModel,
)
from app.infrastructure.database.political_actor_repositories import (
    SqlOfficialEvidenceRepository,
)


class FakeCamaraEvidenceSource:
    def fetch_evidence_for_actor(
        self,
        actor: PoliticalActorModel,
    ) -> dict[str, list[dict[str, object]]]:
        fetched_at = datetime(2026, 5, 6, tzinfo=timezone.utc)
        return {
            "proposition": [
                {
                    "political_actor_id": actor.id,
                    "source": "camara",
                    "source_id": "proposition:9001",
                    "evidence_type": "proposition",
                    "title": "Apresentou PL 123/2026",
                    "summary": "Proposta oficial registrada na Camara.",
                    "evidence_date": fetched_at,
                    "source_url": (
                        "https://dadosabertos.camara.leg.br/api/v2/proposicoes/9001"
                    ),
                    "normalized_payload": {"sigla_tipo": "PL"},
                    "fetched_at": fetched_at,
                    "expires_at": datetime(2026, 5, 7, tzinfo=timezone.utc),
                }
            ],
            "vote": [],
            "expense": [],
        }


class FakeCompleteCamaraEvidenceSource:
    def fetch_evidence_for_actor(
        self,
        actor: PoliticalActorModel,
    ) -> dict[str, list[dict[str, object]]]:
        fetched_at = datetime(2026, 5, 6, tzinfo=timezone.utc)
        return {
            "proposition": [
                {
                    "political_actor_id": actor.id,
                    "source": "camara",
                    "source_id": "proposition:9002",
                    "evidence_type": "proposition",
                    "title": "Apresentou PL 456/2026",
                    "summary": "Proposta oficial registrada na Camara.",
                    "evidence_date": fetched_at,
                    "source_url": (
                        "https://dadosabertos.camara.leg.br/api/v2/proposicoes/9002"
                    ),
                    "normalized_payload": {"sigla_tipo": "PL"},
                    "fetched_at": fetched_at,
                    "expires_at": datetime(2026, 5, 7, tzinfo=timezone.utc),
                }
            ],
            "expense": [
                {
                    "political_actor_id": actor.id,
                    "source": "camara",
                    "source_id": "expense:2026:1:COMBUSTIVEIS",
                    "evidence_type": "expense",
                    "title": "Registrou R$ 119,72 em despesa parlamentar",
                    "summary": "Despesa oficial declarada na Camara.",
                    "evidence_date": fetched_at,
                    "source_url": "https://example.test/despesa",
                    "normalized_payload": {"tipoDespesa": "COMBUSTIVEIS"},
                    "fetched_at": fetched_at,
                    "expires_at": datetime(2026, 5, 20, tzinfo=timezone.utc),
                }
            ],
            "vote": [],
        }


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


def test_refreshes_evidence_when_cache_is_empty(db_session):
    actor = PoliticalActorModel(
        source="camara",
        source_id="101",
        normalized_name="maria silva",
        display_name="Maria Silva",
        party="PT",
        state="SP",
        role="federal_deputy",
        status="active",
        photo_url=None,
        source_url=None,
        last_indexed_at=datetime.now(timezone.utc),
    )
    db_session.add(actor)
    db_session.commit()

    repo = SqlOfficialEvidenceRepository(db_session)

    evidence, status = get_or_refresh_official_evidence(
        evidence_repo=repo,
        actor=actor,
        source=FakeCamaraEvidenceSource(),
        now=datetime(2026, 5, 6, tzinfo=timezone.utc),
    )

    assert status == "refreshed"
    assert evidence[0].title == "Apresentou PL 123/2026"


def test_refreshes_fresh_proposition_only_cache_for_federal_deputy(db_session):
    actor = PoliticalActorModel(
        source="camara",
        source_id="101",
        normalized_name="maria silva",
        display_name="Maria Silva",
        party="PT",
        state="SP",
        role="federal_deputy",
        status="active",
        photo_url=None,
        source_url=None,
        last_indexed_at=datetime.now(timezone.utc),
    )
    db_session.add(actor)
    db_session.flush()
    db_session.add(
        OfficialEvidenceModel(
            political_actor_id=actor.id,
            source="camara",
            source_id="proposition:9001",
            evidence_type="proposition",
            title="Apresentou PL 123/2026",
            summary="Proposta oficial registrada na Camara.",
            evidence_date=datetime(2026, 5, 5, tzinfo=timezone.utc),
            source_url="https://dadosabertos.camara.leg.br/api/v2/proposicoes/9001",
            normalized_payload={"sigla_tipo": "PL"},
            fetched_at=datetime(2026, 5, 5, tzinfo=timezone.utc),
            expires_at=datetime(2026, 5, 7, tzinfo=timezone.utc),
        )
    )
    db_session.commit()

    repo = SqlOfficialEvidenceRepository(db_session)

    evidence, status = get_or_refresh_official_evidence(
        evidence_repo=repo,
        actor=actor,
        source=FakeCompleteCamaraEvidenceSource(),
        now=datetime(2026, 5, 6, tzinfo=timezone.utc),
    )

    assert status == "refreshed"
    assert {row.evidence_type for row in evidence} == {"proposition", "expense"}
