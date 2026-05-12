from datetime import datetime
from typing import Protocol

from app.core.entities.political_actor import OfficialEvidence, PoliticalActor
from app.core.use_cases.interfaces import OfficialEvidenceRepository


class EvidenceSource(Protocol):
    def fetch_evidence_for_actor(
        self,
        actor: PoliticalActor,
    ) -> dict[str, list[dict[str, object]]]: ...


def _has_complete_visible_cache(
    actor: PoliticalActor,
    evidence: list[OfficialEvidence],
) -> bool:
    if actor.role != "federal_deputy":
        return True
    types = {row.evidence_type for row in evidence}
    return {"proposition", "expense"}.issubset(types)


def get_official_evidence(
    repo: OfficialEvidenceRepository,
    actor_id: int,
    now: datetime,
) -> tuple[list[OfficialEvidence], str]:
    evidence, is_fresh = repo.list_by_actor(actor_id, now=now)
    if not evidence:
        return [], "empty"
    return evidence, "fresh" if is_fresh else "stale"


def get_or_refresh_official_evidence(
    evidence_repo: OfficialEvidenceRepository,
    actor: PoliticalActor,
    source: EvidenceSource,
    now: datetime,
) -> tuple[list[OfficialEvidence], str]:
    existing, is_fresh = evidence_repo.list_by_actor(actor.id, now=now)
    if is_fresh and _has_complete_visible_cache(actor, existing):
        return existing, "fresh"

    grouped = source.fetch_evidence_for_actor(actor)
    for evidence_type, rows in grouped.items():
        evidence_repo.replace_for_actor_type(actor.id, evidence_type, rows)

    refreshed, _ = evidence_repo.list_by_actor(actor.id, now=now)
    return refreshed, "refreshed" if refreshed else "empty"
