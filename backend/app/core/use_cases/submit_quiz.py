from dataclasses import dataclass, field

from app.core.entities.candidate import CandidatePosition
from app.core.use_cases.interfaces import CandidateRepository, PositionRepository, ThesisRepository

_POSITION_SCORE = {"concordo": 2, "neutro": 1, "discordo": 0}
_ANSWER_SCORE = {"concordo": 2, "neutro": 1, "discordo": 0}


@dataclass
class QuizAnswer:
    thesis_id: int
    answer: str  # "concordo" | "discordo" | "neutro" | "pulou"
    weight: int = 1  # 1 or 2


@dataclass
class ThesisMatch:
    thesis_id: int
    thesis_text: str
    theme_id: int
    user_answer: str
    candidate_position: str
    match_type: str  # "match" | "mismatch" | "partial" | "skipped"


@dataclass
class CandidateResult:
    candidate_id: int
    name: str
    party_acronym: str
    party_logo_url: str | None
    score_percent: float
    score_by_theme: dict[str, float]
    matches: list[ThesisMatch] = field(default_factory=list)


def _match_type(user_answer: str, candidate_position: str) -> str:
    if user_answer == "pulou" or candidate_position == "sem_posicao":
        return "skipped"
    if user_answer == candidate_position:
        return "match"
    if {user_answer, candidate_position} == {"concordo", "discordo"}:
        return "mismatch"
    return "partial"


def _score_candidate(
    answers: list[QuizAnswer],
    positions: dict[int, CandidatePosition],
) -> tuple[float, dict[str, float]]:
    total_dist = 0.0
    max_dist = 0.0
    theme_data: dict[str, list[float]] = {}

    for ans in answers:
        if ans.answer == "pulou":
            continue
        pos = positions.get(ans.thesis_id)
        if pos is None or pos.position == "sem_posicao":
            continue

        u = _ANSWER_SCORE[ans.answer]
        c = _POSITION_SCORE[pos.position]
        w = ans.weight
        dist = w * abs(u - c)
        mx = w * 2

        total_dist += dist
        max_dist += mx

        theme = pos.theme_slug
        if theme not in theme_data:
            theme_data[theme] = [0.0, 0.0]
        theme_data[theme][0] += dist
        theme_data[theme][1] += mx

    if max_dist == 0:
        return 0.0, {}

    overall = (1 - total_dist / max_dist) * 100
    by_theme = {
        t: (1 - d / m) * 100 if m > 0 else 0.0
        for t, (d, m) in theme_data.items()
    }
    return round(overall, 2), {k: round(v, 2) for k, v in by_theme.items()}


def submit_quiz(
    answers: list[QuizAnswer],
    candidate_repo: CandidateRepository,
    position_repo: PositionRepository,
    thesis_repo: ThesisRepository,
) -> list[CandidateResult]:
    answered_ids = [a.thesis_id for a in answers if a.answer != "pulou"]
    if not answered_ids:
        return []

    candidates, _ = candidate_repo.list(page_size=100)
    candidate_ids = [c.id for c in candidates]
    positions_map = position_repo.get_by_candidates_and_theses(candidate_ids, answered_ids)
    theses = {t.id: t for t in thesis_repo.get_by_ids(answered_ids)}

    results: list[CandidateResult] = []
    for candidate in candidates:
        cand_positions = positions_map.get(candidate.id, {})
        score, by_theme = _score_candidate(answers, cand_positions)

        matches = []
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

        results.append(
            CandidateResult(
                candidate_id=candidate.id,
                name=candidate.name,
                party_acronym=candidate.party_acronym,
                party_logo_url=candidate.party_logo_url,
                score_percent=score,
                score_by_theme=by_theme,
                matches=matches,
            )
        )

    return sorted(results, key=lambda r: r.score_percent, reverse=True)
