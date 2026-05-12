import json
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest

from app.infrastructure.database.models import (
    OfficialEvidenceModel,
    PoliticalActorModel,
    SentinelaSummaryModel,
)


def test_sentinela_summary_entity_fields():
    from app.core.entities.political_actor import SectionSummary, SentinelaSummary

    section = SectionSummary(
        summary="Votou Sim em 10 ocasiões.",
        citations=[{"label": "Votação 1", "source_url": "https://example.com"}],
    )
    summary = SentinelaSummary(
        id=1,
        political_actor_id=42,
        period="quarter",
        generated_at=datetime.now(timezone.utc),
        expires_at=datetime.now(timezone.utc),
        votes=section,
        propositions=SectionSummary(summary="Sem registros.", citations=[]),
        expenses=SectionSummary(summary="Sem registros.", citations=[]),
        synthesis="O deputado participou ativamente das votações.",
    )

    assert summary.period == "quarter"
    assert summary.votes.summary == "Votou Sim em 10 ocasiões."
    assert summary.votes.citations[0]["label"] == "Votação 1"


@pytest.fixture(autouse=True)
def clean_sentinela_tables(db_session):
    db_session.query(SentinelaSummaryModel).delete()
    db_session.query(OfficialEvidenceModel).delete()
    db_session.query(PoliticalActorModel).delete()
    db_session.commit()
    yield
    db_session.query(SentinelaSummaryModel).delete()
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
        source_url=f"https://dadosabertos.camara.leg.br/api/v2/deputados/{source_id}",
        last_indexed_at=datetime.now(timezone.utc),
    )
    db_session.add(actor)
    db_session.commit()
    db_session.refresh(actor)
    return actor


def _seed_evidence(db_session, actor_id, evidence_type, source_id, days_ago=10):
    now = datetime.now(timezone.utc)
    evidence = OfficialEvidenceModel(
        political_actor_id=actor_id,
        source="camara",
        source_id=source_id,
        evidence_type=evidence_type,
        title=f"Evidência {source_id}",
        summary="Resumo da evidência.",
        evidence_date=now - timedelta(days=days_ago),
        source_url=f"https://dadosabertos.camara.leg.br/api/v2/{source_id}",
        fetched_at=now,
        expires_at=now + timedelta(days=1),
    )
    db_session.add(evidence)
    db_session.commit()
    return evidence


def _sentinela_summary_data(
    actor_id, now, synthesis="O deputado participou ativamente."
):
    return {
        "political_actor_id": actor_id,
        "period": "quarter",
        "generated_at": now,
        "expires_at": now + timedelta(hours=24),
        "votes_summary": json.dumps(
            {"summary": "Votou Sim em 5 ocasiões.", "citations": []}
        ),
        "propositions_summary": json.dumps({"summary": "Sem dados.", "citations": []}),
        "expenses_summary": json.dumps({"summary": "Sem dados.", "citations": []}),
        "synthesis": synthesis,
    }


def test_sentinela_repo_returns_none_when_no_cache(db_session):
    from app.infrastructure.database.political_actor_repositories import (
        SqlSentinelaSummaryRepository,
    )

    repo = SqlSentinelaSummaryRepository(db_session)
    result = repo.get_valid(
        actor_id=999, period="quarter", now=datetime.now(timezone.utc)
    )
    assert result is None


def test_sentinela_repo_returns_none_when_cache_expired(db_session):
    from app.infrastructure.database.political_actor_repositories import (
        SqlSentinelaSummaryRepository,
    )

    actor = _seed_actor(db_session)
    now = datetime.now(timezone.utc)
    empty_section = json.dumps({"summary": "Sem dados.", "citations": []})
    db_session.add(
        SentinelaSummaryModel(
            political_actor_id=actor.id,
            period="quarter",
            generated_at=now - timedelta(hours=25),
            expires_at=now - timedelta(hours=1),
            votes_summary=empty_section,
            propositions_summary=empty_section,
            expenses_summary=empty_section,
            synthesis="Sem dados.",
        )
    )
    db_session.commit()

    repo = SqlSentinelaSummaryRepository(db_session)
    result = repo.get_valid(actor_id=actor.id, period="quarter", now=now)
    assert result is None


def test_sentinela_repo_upsert_and_get(db_session):
    from app.infrastructure.database.political_actor_repositories import (
        SqlSentinelaSummaryRepository,
    )

    actor = _seed_actor(db_session)
    now = datetime.now(timezone.utc)
    repo = SqlSentinelaSummaryRepository(db_session)

    section = {
        "summary": "Votou Sim em 5 ocasiões.",
        "citations": [
            {
                "label": "Votação 1",
                "source_url": "https://dadosabertos.camara.leg.br/api/v2/votacoes/1",
            }
        ],
    }
    repo.upsert(
        {
            "political_actor_id": actor.id,
            "period": "quarter",
            "generated_at": now,
            "expires_at": now + timedelta(hours=24),
            "votes_summary": json.dumps(section),
            "propositions_summary": json.dumps(
                {"summary": "Sem dados.", "citations": []}
            ),
            "expenses_summary": json.dumps({"summary": "Sem dados.", "citations": []}),
            "synthesis": "O deputado participou ativamente.",
        }
    )

    result = repo.get_valid(actor_id=actor.id, period="quarter", now=now)
    assert result is not None
    assert result.period == "quarter"
    assert result.votes.summary == "Votou Sim em 5 ocasiões."
    assert result.votes.citations[0]["label"] == "Votação 1"
    assert result.synthesis == "O deputado participou ativamente."


def test_sentinela_repo_upsert_updates_existing_actor_period(db_session):
    from app.infrastructure.database.political_actor_repositories import (
        SqlSentinelaSummaryRepository,
    )

    actor = _seed_actor(db_session)
    now = datetime.now(timezone.utc)
    repo = SqlSentinelaSummaryRepository(db_session)

    first = repo.upsert(
        _sentinela_summary_data(actor.id, now, synthesis="Primeira síntese.")
    )
    second = repo.upsert(
        _sentinela_summary_data(actor.id, now, synthesis="Síntese atualizada.")
    )

    row_count = (
        db_session.query(SentinelaSummaryModel)
        .filter_by(
            political_actor_id=actor.id,
            period="quarter",
        )
        .count()
    )
    assert row_count == 1
    assert second.id == first.id
    assert second.synthesis == "Síntese atualizada."


def test_evidence_repo_list_by_actor_since_filters_by_date(db_session):
    from app.infrastructure.database.political_actor_repositories import (
        SqlOfficialEvidenceRepository,
    )

    actor = _seed_actor(db_session)
    _seed_evidence(db_session, actor.id, "vote", "vote:1", days_ago=10)
    _seed_evidence(db_session, actor.id, "vote", "vote:2", days_ago=100)

    repo = SqlOfficialEvidenceRepository(db_session)
    since = datetime.now(timezone.utc) - timedelta(days=90)

    result = repo.list_by_actor_since(actor.id, since=since)
    assert len(result) == 1
    assert result[0].source_id == "vote:1"


def test_evidence_repo_list_by_actor_since_returns_all_when_no_filter(db_session):
    from app.infrastructure.database.political_actor_repositories import (
        SqlOfficialEvidenceRepository,
    )

    actor = _seed_actor(db_session)
    _seed_evidence(db_session, actor.id, "vote", "vote:1", days_ago=10)
    _seed_evidence(db_session, actor.id, "proposition", "prop:1", days_ago=500)

    repo = SqlOfficialEvidenceRepository(db_session)
    result = repo.list_by_actor_since(actor.id, since=None)
    assert len(result) == 2


def test_generate_section_summary_returns_section_with_valid_citations():
    from app.core.entities.political_actor import OfficialEvidence
    from app.infrastructure.llm.sentinela import generate_section_summary

    now = datetime.now(timezone.utc)
    evidence = [
        OfficialEvidence(
            id=1,
            political_actor_id=1,
            source="camara",
            source_id="vote:123:456",
            evidence_type="vote",
            title="Votou Sim",
            summary="PL 1234/2026 - Reforma tributária.",
            evidence_date=now,
            source_url="https://dadosabertos.camara.leg.br/api/v2/votacoes/123",
            fetched_at=now,
            expires_at=now + timedelta(days=1),
        )
    ]

    fake_response = MagicMock()
    fake_response.text = json.dumps({
        "summary": "Votou Sim na reforma tributária.",
        "citations": [
            {"label": "Votação 123", "source_url": "https://dadosabertos.camara.leg.br/api/v2/votacoes/123"}
        ],
    })

    with patch("app.infrastructure.llm.sentinela.genai.Client") as MockClient:
        instance = MockClient.return_value
        instance.models.generate_content.return_value = fake_response

        result = generate_section_summary(
            api_key="fake-key",
            actor_name="Maria Silva",
            evidence_type="vote",
            evidence_list=evidence,
            period_label="último trimestre",
        )

    assert result.summary == "Votou Sim na reforma tributária."
    assert len(result.citations) == 1
    assert result.citations[0]["source_url"] == "https://dadosabertos.camara.leg.br/api/v2/votacoes/123"


def test_generate_section_summary_removes_invalid_citations():
    from app.core.entities.political_actor import OfficialEvidence
    from app.infrastructure.llm.sentinela import generate_section_summary

    now = datetime.now(timezone.utc)
    evidence = [
        OfficialEvidence(
            id=1,
            political_actor_id=1,
            source="camara",
            source_id="vote:123:456",
            evidence_type="vote",
            title="Votou Sim",
            summary="PL real.",
            evidence_date=now,
            source_url="https://dadosabertos.camara.leg.br/api/v2/votacoes/123",
            fetched_at=now,
            expires_at=now + timedelta(days=1),
        )
    ]

    fake_response = MagicMock()
    fake_response.text = json.dumps({
        "summary": "Votou em algo inventado.",
        "citations": [
            {"label": "Real", "source_url": "https://dadosabertos.camara.leg.br/api/v2/votacoes/123"},
            {"label": "Inventado", "source_url": "https://dadosabertos.camara.leg.br/api/v2/votacoes/INVENTADO"},
        ],
    })

    with patch("app.infrastructure.llm.sentinela.genai.Client") as MockClient:
        instance = MockClient.return_value
        instance.models.generate_content.return_value = fake_response

        result = generate_section_summary(
            api_key="fake-key",
            actor_name="Maria Silva",
            evidence_type="vote",
            evidence_list=evidence,
            period_label="último trimestre",
        )

    assert len(result.citations) == 1
    assert result.citations[0]["label"] == "Real"


def test_generate_section_summary_handles_empty_evidence():
    from app.infrastructure.llm.sentinela import generate_section_summary

    result = generate_section_summary(
        api_key="fake-key",
        actor_name="Maria Silva",
        evidence_type="vote",
        evidence_list=[],
        period_label="último trimestre",
    )

    assert result.summary == "Sem registros neste período."
    assert result.citations == []


def test_generate_section_summary_handles_client_construction_error():
    from app.core.entities.political_actor import OfficialEvidence
    from app.infrastructure.llm.sentinela import generate_section_summary

    now = datetime.now(timezone.utc)
    evidence = [
        OfficialEvidence(
            id=1,
            political_actor_id=1,
            source="camara",
            source_id="vote:123:456",
            evidence_type="vote",
            title="Votou Sim",
            summary="PL real.",
            evidence_date=now,
            source_url="https://dadosabertos.camara.leg.br/api/v2/votacoes/123",
            fetched_at=now,
            expires_at=now + timedelta(days=1),
        )
    ]

    with patch(
        "app.infrastructure.llm.sentinela.genai.Client",
        side_effect=RuntimeError("client error"),
    ):
        result = generate_section_summary(
            api_key="fake-key",
            actor_name="Maria Silva",
            evidence_type="vote",
            evidence_list=evidence,
            period_label="último trimestre",
        )

    assert result.summary == "Não foi possível gerar o resumo neste momento."
    assert result.citations == []


def test_generate_synthesis_handles_client_construction_error():
    from app.infrastructure.llm.sentinela import generate_synthesis

    with patch(
        "app.infrastructure.llm.sentinela.genai.Client",
        side_effect=RuntimeError("client error"),
    ):
        result = generate_synthesis(
            api_key="fake-key",
            actor_name="Maria Silva",
            votes_summary="Votou Sim.",
            propositions_summary="Apresentou proposição.",
            expenses_summary="Declarou despesas.",
            period_label="último trimestre",
        )

    assert result == "Não foi possível gerar a síntese neste momento."
