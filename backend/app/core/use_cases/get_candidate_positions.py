from app.core.entities.candidate import CandidatePosition
from app.core.use_cases.interfaces import PositionRepository


def get_candidate_positions(
    repo: PositionRepository,
    candidate_id: str,
) -> list[CandidatePosition]:
    positions = repo.get_by_candidate(candidate_id)
    return sorted(positions, key=lambda p: (p.theme_id, p.thesis_id))
