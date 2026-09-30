"""Orquestrador do endpoint /quiz/submit. Converte entidades dos repos em
tipos do módulo `scoring`, delega o cálculo e monta o DTO de resposta.

Toda a regra matemática vive em `app.core.scoring` — este módulo é I/O glue.
"""

from dataclasses import dataclass, field
from typing import Any

from app.core.entities.candidate import CandidatePosition
from app.core.scoring import (
    CandidateStance,
    InsufficientAnswersError,  # re-exportado para o router
    RankingStatus,
    ScoreBreakdown,
    Stance,
    UserAnswer,
    Weight,
    rank,
    ranking_status,
    score,
    validate_minimum,
)
from app.core.use_cases.interfaces import (
    CandidateRepository,
    PositionRepository,
    ThesisRepository,
)

__all__ = [
    "CandidateResult",
    "InsufficientAnswersError",
    "InvalidThesisIdsError",
    "QuizAnswer",
    "ThesisMatch",
    "submit_quiz",
]

_ANSWER_TO_STANCE = {
    "agree": Stance.AGREE,
    "neutral": Stance.NEUTRAL,
    "disagree": Stance.DISAGREE,
    "skip": Stance.SKIP,
}

_POSITION_TO_STANCE = {
    "concordo": Stance.AGREE,
    "neutro": Stance.NEUTRAL,
    "discordo": Stance.DISAGREE,
    "sem_posicao": Stance.NO_OPINION,
}


class InvalidThesisIdsError(ValueError):
    """Raised when a submission references theses unavailable in the active quiz."""

    def __init__(self, thesis_ids: list[int]) -> None:
        self.thesis_ids = sorted(set(thesis_ids))
        joined_ids = ", ".join(str(thesis_id) for thesis_id in self.thesis_ids)
        super().__init__(f"Teses indisponíveis para o quiz ativo: {joined_ids}.")


@dataclass
class QuizAnswer:
    """DTO do router — strings por compat. com o schema atual."""

    thesis_id: int
    answer: str  # "agree" | "disagree" | "neutral" | "skip"
    weight: int = 1


@dataclass
class ThesisMatch:
    thesis_id: int
    thesis_text: str
    theme_id: int
    user_answer: str
    candidate_position: str
    candidate_analysis: str | None
    match_type: str  # "match" | "mismatch" | "partial" | "skipped"


@dataclass
class CandidateResult:
    candidate_id: int
    name: str
    party_acronym: str
    party_logo_url: str | None
    photo_url: str | None
    score_percent: float
    score_by_theme: dict[str, float]
    rank: int
    counted_theses: int
    answered_theses: int
    comparable_categories: int
    documented_theses: int
    documented_categories: int
    ranking_status: str
    ranking_eligible: bool
    matches: list[ThesisMatch] = field(default_factory=list)


def _to_user_answer(a: QuizAnswer) -> UserAnswer:
    return UserAnswer(
        thesis_id=a.thesis_id,
        stance=_ANSWER_TO_STANCE[a.answer],
        weight=Weight(a.weight),
    )


def _to_candidate_stance(p: CandidatePosition) -> CandidateStance:
    return CandidateStance(
        thesis_id=p.thesis_id,
        stance=_POSITION_TO_STANCE[p.position],
    )


def _match_type(user_answer: str, candidate_position: str) -> str:
    if user_answer == "skip" or candidate_position == "sem_posicao":
        return "skipped"
    c_norm = {"concordo": "agree", "discordo": "disagree", "neutro": "neutral"}.get(
        candidate_position, "neutral"
    )
    if user_answer == c_norm:
        return "match"
    if {user_answer, c_norm} == {"agree", "disagree"}:
        return "mismatch"
    return "partial"


def _score_by_theme(
    answers: list[QuizAnswer],
    positions: dict[int, CandidatePosition],
) -> dict[str, float]:
    buckets: dict[str, tuple[int, int]] = {}
    for ans in answers:
        if ans.answer == "skip":
            continue
        pos = positions.get(ans.thesis_id)
        if pos is None or pos.position == "sem_posicao":
            continue
        sb = score([_to_user_answer(ans)], [_to_candidate_stance(pos)])
        d, m = buckets.get(pos.theme_slug, (0, 0))
        buckets[pos.theme_slug] = (d + sb.total_distance, m + sb.max_distance)

    return {
        theme: round((1 - d / m) * 100, 2) if m > 0 else 0.0
        for theme, (d, m) in buckets.items()
    }


def submit_quiz(
    answers: list[QuizAnswer],
    candidate_repo: CandidateRepository,
    position_repo: PositionRepository,
    thesis_repo: ThesisRepository,
    selected_candidate_ids: list[int] | None = None,
) -> list[CandidateResult]:
    """Pipeline: valida teses e mínimo → calcula scores → monta o ranking."""
    requested_ids = list(dict.fromkeys(answer.thesis_id for answer in answers))
    available_theses = thesis_repo.get_by_ids(requested_ids)
    available_ids = {thesis.id for thesis in available_theses}
    invalid_ids = [thesis_id for thesis_id in requested_ids if thesis_id not in available_ids]
    if invalid_ids:
        raise InvalidThesisIdsError(invalid_ids)

    user_answers = [_to_user_answer(a) for a in answers]
    validate_minimum(user_answers)  # lança InsufficientAnswersError se < 5

    answered_ids = [a.thesis_id for a in answers if a.answer != "skip"]
    candidates, _ = candidate_repo.list(page_size=100)
    if selected_candidate_ids is not None:
        selected_ids = set(selected_candidate_ids)
        candidates = [candidate for candidate in candidates if candidate.id in selected_ids]
    candidate_ids = [c.id for c in candidates]
    edition_theses = thesis_repo.list_approved(limit=60)
    edition_ids = [thesis.id for thesis in edition_theses]
    positions_map = position_repo.get_by_candidates_and_theses(candidate_ids, edition_ids)
    theses = {t.id: t for t in available_theses if t.id in answered_ids}

    scored: list[tuple[int, str, ScoreBreakdown]] = []
    intermediate: dict[int, Any] = {}
    for candidate in candidates:
        cand_positions = positions_map.get(candidate.id, {})
        stances = [_to_candidate_stance(p) for p in cand_positions.values()]
        breakdown = score(user_answers, stances)
        by_theme = _score_by_theme(answers, cand_positions)
        documented_positions = [
            position
            for position in cand_positions.values()
            if position.position != "sem_posicao"
        ]
        comparable_positions = [
            position
            for thesis_id, position in cand_positions.items()
            if thesis_id in answered_ids and position.position != "sem_posicao"
        ]
        documented_categories = len(
            {position.theme_id for position in documented_positions}
        )
        comparable_categories = len(
            {position.theme_id for position in comparable_positions}
        )
        status = ranking_status(
            documented_theses=len(documented_positions),
            documented_categories=documented_categories,
            compared_theses=breakdown.counted_theses,
            compared_categories=comparable_categories,
        )

        matches: list[ThesisMatch] = []
        for ans in answers:
            thesis = theses.get(ans.thesis_id)
            if thesis is None:
                continue
            pos = cand_positions.get(ans.thesis_id)
            cand_pos_str = pos.position if pos else "sem_posicao"
            matches.append(
                ThesisMatch(
                    thesis_id=ans.thesis_id,
                    thesis_text=thesis.text,
                    theme_id=thesis.theme_id,
                    user_answer=ans.answer,
                    candidate_position=cand_pos_str,
                    candidate_analysis=pos.analytical_position if pos else None,
                    match_type=_match_type(ans.answer, cand_pos_str),
                )
            )

        intermediate[candidate.id] = {
            "candidate": candidate,
            "breakdown": breakdown,
            "by_theme": by_theme,
            "matches": matches,
            "comparable_categories": comparable_categories,
            "documented_theses": len(documented_positions),
            "documented_categories": documented_categories,
            "ranking_status": status,
        }
        scored.append((candidate.id, candidate.name, breakdown))

    ranked = rank(
        item
        for item in scored
        if intermediate[item[0]]["ranking_status"] is RankingStatus.ELIGIBLE
    )
    unranked = sorted(
        (
            item
            for item in scored
            if intermediate[item[0]]["ranking_status"] is not RankingStatus.ELIGIBLE
        ),
        key=lambda item: item[1].casefold(),
    )

    results: list[CandidateResult] = []
    ordered = [
        (rc.candidate_id, rc.score, rc.rank)
        for rc in ranked
    ] + [
        (candidate_id, breakdown, 0)
        for candidate_id, _name, breakdown in unranked
    ]
    for candidate_id, result_score, result_rank in ordered:
        data = intermediate[candidate_id]
        candidate = data["candidate"]
        status = data["ranking_status"]
        results.append(
            CandidateResult(
                candidate_id=candidate.id,
                name=candidate.name,
                party_acronym=candidate.party_acronym,
                party_logo_url=candidate.party_logo_url,
                photo_url=candidate.photo_url,
                score_percent=result_score.score_percent,
                score_by_theme=data["by_theme"],
                rank=result_rank,
                counted_theses=result_score.counted_theses,
                answered_theses=len(answered_ids),
                comparable_categories=data["comparable_categories"],
                documented_theses=data["documented_theses"],
                documented_categories=data["documented_categories"],
                ranking_status=status.value,
                ranking_eligible=status is RankingStatus.ELIGIBLE,
                matches=data["matches"],
            )
        )
    return results
