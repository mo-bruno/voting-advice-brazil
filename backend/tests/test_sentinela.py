from datetime import datetime, timezone


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
