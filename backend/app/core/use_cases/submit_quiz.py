"""Orquestrador do endpoint /quiz/submit. Converte entidades dos repos em
tipos do módulo `scoring`, delega o cálculo e monta o DTO de resposta.

Toda a regra matemática vive em `app.core.scoring` — este módulo é I/O glue.
"""

from dataclasses import dataclass, field

from app.core.entities.candidate import CandidatePosition
from app.core.scoring import (
    CandidateStance,
    InsufficientAnswersError,  # re-exportado para o router
    Stance,
    UserAnswer,
    Weight,
    rank,
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
    theme_id: str
    user_answer: str
    candidate_position: str
    match_type: str  # "match" | "mismatch" | "partial" | "skipped"


@dataclass
class CandidateResult:
    candidate_id: str
    name: str
    party: str
    party_logo: str | None
    score_percent: float
    score_by_theme: dict[str, float]
    rank: int
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
        theme_answers = [ans]
        theme_stances = [_to_candidate_stance(pos)]
        sb = score(
            (_to_user_answer(a) for a in theme_answers),
            theme_stances,
        )
        d, m = buckets.get(pos.theme_id, (0, 0))
        buckets[pos.theme_id] = (d + sb.total_distance, m + sb.max_distance)

    return {
        theme: round((1 - d / m) * 100, 2) if m > 0 else 0.0
        for theme, (d, m) in buckets.items()
    }


def submit_quiz(
    answers: list[QuizAnswer],
    candidate_repo: CandidateRepository,
    position_repo: PositionRepository,
    thesis_repo: ThesisRepository,
) -> list[CandidateResult]:
    """Pipeline: valida mínimo → busca dados → score por candidato → rank."""
    user_answers = [_to_user_answer(a) for a in answers]
    validate_minimum(user_answers)  # lança InsufficientAnswersError se < 5

    answered_ids = [a.thesis_id for a in answers if a.answer != "skip"]
    candidates, _ = candidate_repo.list(page_size=100)
    candidate_ids = [c.id for c in candidates]
    positions_map = position_repo.get_by_candidates_and_theses(
        candidate_ids, answered_ids
    )
    theses = {t.id: t for t in thesis_repo.get_by_ids(answered_ids)}

    scored: list[tuple[str, str, object]] = []
    intermediate: dict[str, dict] = {}
    for candidate in candidates:
        cand_positions = positions_map.get(candidate.id, {})
        stances = [_to_candidate_stance(p) for p in cand_positions.values()]
        breakdown = score(user_answers, stances)
        by_theme = _score_by_theme(answers, cand_positions)

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
                    match_type=_match_type(ans.answer, cand_pos_str),
                )
            )

        intermediate[candidate.id] = {
            "candidate": candidate,
            "breakdown": breakdown,
            "by_theme": by_theme,
            "matches": matches,
        }
        scored.append((candidate.id, candidate.name, breakdown))

    ranked = rank(scored)

    results: list[CandidateResult] = []
    for rc in ranked:
        data = intermediate[rc.candidate_id]
        candidate = data["candidate"]
        results.append(
            CandidateResult(
                candidate_id=candidate.id,
                name=candidate.name,
                party=candidate.party,
                party_logo=candidate.party_logo,
                score_percent=rc.score.score_percent,
                score_by_theme=data["by_theme"],
                rank=rc.rank,
                matches=data["matches"],
            )
        )
    return results
