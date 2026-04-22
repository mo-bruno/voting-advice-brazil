"""Lógica pura de cálculo de compatibilidade (Wahl-O-Mat City Block).

Zero dependências de infra/API/repos. Testável em unidade pura.
Ver docs/superpowers/specs/2026-04-21-algoritmo-match-score-design.md.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from enum import Enum
from typing import Final


class Stance(str, Enum):
    """Posição numa tese. `SKIP` só válido para usuário;
    `NO_OPINION` só válido para candidato."""

    AGREE = "agree"
    NEUTRAL = "neutral"
    DISAGREE = "disagree"
    NO_OPINION = "no_opinion"
    SKIP = "skip"


class Weight(int, Enum):
    NORMAL = 1
    DOUBLE = 2


@dataclass(frozen=True, slots=True)
class UserAnswer:
    thesis_id: int
    stance: Stance
    weight: Weight = Weight.NORMAL


@dataclass(frozen=True, slots=True)
class CandidateStance:
    thesis_id: int
    stance: Stance


@dataclass(frozen=True, slots=True)
class ScoreBreakdown:
    total_distance: int
    max_distance: int
    score_percent: float
    exact_matches: int
    total_mismatches: int
    counted_theses: int


@dataclass(frozen=True, slots=True)
class RankedCandidate:
    candidate_id: str
    name: str
    score: ScoreBreakdown
    rank: int


_STANCE_VALUE: Final[dict[Stance, int]] = {
    Stance.AGREE: 2,
    Stance.NEUTRAL: 1,
    Stance.DISAGREE: 0,
}


def score(
    answers: Iterable[UserAnswer],
    candidate_stances: Iterable[CandidateStance],
) -> ScoreBreakdown:
    """Calcula ScoreBreakdown para um candidato (funcao pura, deterministica).

    Teses com `UserAnswer.stance == SKIP` ou `CandidateStance.stance == NO_OPINION`
    sao excluidas do numerador, denominador e contadores. Se nenhuma tese e
    contavel, retorna `score_percent = 0.0` como sentinela (caller deve ter
    validado o minimo antes).
    """
    by_thesis: dict[int, CandidateStance] = {
        cs.thesis_id: cs for cs in candidate_stances
    }
    total_d = max_d = exact = mismatches = counted = 0

    for ans in answers:
        if ans.stance is Stance.SKIP:
            continue
        cs = by_thesis.get(ans.thesis_id)
        if cs is None or cs.stance is Stance.NO_OPINION:
            continue

        u = _STANCE_VALUE[ans.stance]
        c = _STANCE_VALUE[cs.stance]
        raw = abs(u - c)
        w = ans.weight.value

        total_d += w * raw
        max_d += w * 2
        counted += 1
        if raw == 0:
            exact += 1
        elif raw == 2:
            mismatches += 1

    score_pct = 0.0 if max_d == 0 else round((1 - total_d / max_d) * 100, 2)
    return ScoreBreakdown(
        total_distance=total_d,
        max_distance=max_d,
        score_percent=score_pct,
        exact_matches=exact,
        total_mismatches=mismatches,
        counted_theses=counted,
    )


MIN_ANSWERS: Final[int] = 5


class InsufficientAnswersError(ValueError):
    def __init__(self, provided: int, required: int = MIN_ANSWERS) -> None:
        self.provided = provided
        self.required = required
        super().__init__(
            f"Quiz exige ao menos {required} respostas não-puladas; "
            f"recebidas {provided}."
        )
