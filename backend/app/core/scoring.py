"""Lógica pura de cálculo de compatibilidade (Wahl-O-Mat City Block).

Zero dependências de infra/API/repos. Testável em unidade pura.
Ver docs/superpowers/specs/2026-04-21-algoritmo-match-score-design.md.
"""

from __future__ import annotations

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


MIN_ANSWERS: Final[int] = 5


class InsufficientAnswersError(ValueError):
    def __init__(self, provided: int, required: int = MIN_ANSWERS) -> None:
        self.provided = provided
        self.required = required
        super().__init__(
            f"Quiz exige ao menos {required} respostas não-puladas; "
            f"recebidas {provided}."
        )
