from datetime import datetime

from app.core.entities.political_actor import OfficialEvidence
from app.core.use_cases.interfaces import OfficialEvidenceRepository


def get_official_evidence(
    repo: OfficialEvidenceRepository,
    actor_id: int,
    now: datetime,
) -> tuple[list[OfficialEvidence], str]:
    evidence, is_fresh = repo.list_by_actor(actor_id, now=now)
    if not evidence:
        return [], "empty"
    return evidence, "fresh" if is_fresh else "stale"
