from dataclasses import dataclass

from app.core.entities.candidate import CandidatePosition
from app.core.use_cases.interfaces import PositionRepository


@dataclass
class JustificationSummary:
    agree_count: int
    disagree_count: int
    neutral_count: int
    no_position_count: int


@dataclass
class JustificationResult:
    positions: list[CandidatePosition]
    summary: JustificationSummary
    grouped: dict[str, list[CandidatePosition]] | None


def get_candidate_justifications(
    repo: PositionRepository,
    candidate_id: str,
    group_by_theme: bool = False,
) -> JustificationResult:
    positions = repo.get_by_candidate(candidate_id)

    counts = {"concordo": 0, "discordo": 0, "neutro": 0, "sem_posicao": 0}
    for p in positions:
        counts[p.position] = counts.get(p.position, 0) + 1

    summary = JustificationSummary(
        agree_count=counts["concordo"],
        disagree_count=counts["discordo"],
        neutral_count=counts["neutro"],
        no_position_count=counts["sem_posicao"],
    )

    grouped = None
    if group_by_theme:
        grouped = {}
        for p in sorted(positions, key=lambda x: (x.theme_id, x.thesis_id)):
            grouped.setdefault(p.theme_id, []).append(p)

    return JustificationResult(
        positions=sorted(positions, key=lambda x: x.thesis_id),
        summary=summary,
        grouped=grouped,
    )
