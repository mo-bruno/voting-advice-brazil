from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta

from app.core.entities.political_actor import OfficialEvidence, SentinelaSummary
from app.core.use_cases.interfaces import (
    OfficialEvidenceRepository,
    PoliticalActorRepository,
    SentinelaSummaryRepository,
)
from app.infrastructure.llm.sentinela import (
    generate_section_summary,
    generate_synthesis,
)

_QUARTER_DAYS = 90
_TTL = {
    "quarter": timedelta(hours=24),
    "full": timedelta(days=7),
}
_PERIOD_LABELS = {
    "quarter": "últimos 90 dias",
    "full": "mandato completo",
}


class ActorNotFoundError(Exception):
    pass


def generate_sentinela_summary(
    actor_id: int,
    period: str,
    actor_repo: PoliticalActorRepository,
    evidence_repo: OfficialEvidenceRepository,
    summary_repo: SentinelaSummaryRepository,
    api_key: str,
    now: datetime,
) -> SentinelaSummary:
    cached = summary_repo.get_valid(actor_id=actor_id, period=period, now=now)
    if cached:
        return cached

    actor = actor_repo.get_by_id(actor_id)
    if not actor:
        raise ActorNotFoundError(f"Actor {actor_id} not found")

    since = now - timedelta(days=_QUARTER_DAYS) if period == "quarter" else None
    all_evidence = evidence_repo.list_by_actor_since(actor_id, since=since)

    votes = [e for e in all_evidence if e.evidence_type == "vote"]
    propositions = [e for e in all_evidence if e.evidence_type == "proposition"]
    expenses = [e for e in all_evidence if e.evidence_type == "expense"]

    period_label = _PERIOD_LABELS.get(period, period)
    actor_name = f"{actor.display_name} ({actor.party}-{actor.state})"

    sections: dict[str, list[OfficialEvidence]] = {
        "vote": votes,
        "proposition": propositions,
        "expense": expenses,
    }

    results = {}
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = {
            executor.submit(
                generate_section_summary,
                api_key,
                actor_name,
                evidence_type,
                evidence_list,
                period_label,
            ): evidence_type
            for evidence_type, evidence_list in sections.items()
        }
        for future in as_completed(futures):
            evidence_type = futures[future]
            results[evidence_type] = future.result()

    synthesis = generate_synthesis(
        api_key=api_key,
        actor_name=actor_name,
        votes_summary=results["vote"].summary,
        propositions_summary=results["proposition"].summary,
        expenses_summary=results["expense"].summary,
        period_label=period_label,
    )

    ttl = _TTL.get(period, timedelta(hours=24))
    return summary_repo.upsert(
        {
            "political_actor_id": actor_id,
            "period": period,
            "generated_at": now,
            "expires_at": now + ttl,
            "votes_summary": json.dumps(
                {
                    "summary": results["vote"].summary,
                    "citations": results["vote"].citations,
                }
            ),
            "propositions_summary": json.dumps(
                {
                    "summary": results["proposition"].summary,
                    "citations": results["proposition"].citations,
                }
            ),
            "expenses_summary": json.dumps(
                {
                    "summary": results["expense"].summary,
                    "citations": results["expense"].citations,
                }
            ),
            "synthesis": synthesis,
        }
    )
