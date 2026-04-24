import random

import pytest
from hypothesis import given, strategies as st

from app.core.scoring import (
    CandidateStance,
    InsufficientAnswersError,
    MIN_ANSWERS,
    RankedCandidate,
    ScoreBreakdown,
    Stance,
    UserAnswer,
    Weight,
    rank,
    score,
    validate_minimum,
)


class TestStanceEnum:
    def test_values(self):
        assert Stance.AGREE.value == "agree"
        assert Stance.NEUTRAL.value == "neutral"
        assert Stance.DISAGREE.value == "disagree"
        assert Stance.NO_OPINION.value == "no_opinion"
        assert Stance.SKIP.value == "skip"

    def test_is_string_enum(self):
        assert Stance.AGREE == "agree"


class TestWeightEnum:
    def test_values(self):
        assert Weight.NORMAL == 1
        assert Weight.DOUBLE == 2

    def test_rejects_out_of_range(self):
        with pytest.raises(ValueError):
            Weight(3)


class TestUserAnswerDataclass:
    def test_default_weight_is_normal(self):
        a = UserAnswer(thesis_id=1, stance=Stance.AGREE)
        assert a.weight is Weight.NORMAL

    def test_frozen(self):
        a = UserAnswer(thesis_id=1, stance=Stance.AGREE)
        with pytest.raises(Exception):
            a.thesis_id = 2  # type: ignore[misc]


class TestCandidateStanceDataclass:
    def test_frozen(self):
        cs = CandidateStance(thesis_id=1, stance=Stance.AGREE)
        with pytest.raises(Exception):
            cs.thesis_id = 2  # type: ignore[misc]


class TestMinAnswers:
    def test_value_is_five(self):
        assert MIN_ANSWERS == 5


class TestInsufficientAnswersError:
    def test_is_value_error(self):
        err = InsufficientAnswersError(provided=2)
        assert isinstance(err, ValueError)
        assert err.provided == 2
        assert err.required == MIN_ANSWERS

    def test_message_in_ptbr(self):
        err = InsufficientAnswersError(provided=3)
        assert "3" in str(err) and "5" in str(err)


class TestScoreBreakdownDataclass:
    def test_frozen(self):
        sb = ScoreBreakdown(
            total_distance=0,
            max_distance=2,
            score_percent=100.0,
            exact_matches=1,
            total_mismatches=0,
            counted_theses=1,
        )
        with pytest.raises(Exception):
            sb.score_percent = 0.0  # type: ignore[misc]


def _u(tid: int, s: Stance, w: Weight = Weight.NORMAL) -> UserAnswer:
    return UserAnswer(thesis_id=tid, stance=s, weight=w)


def _c(tid: int, s: Stance) -> CandidateStance:
    return CandidateStance(thesis_id=tid, stance=s)


class TestScoreCanonicalMatrix:
    """Matriz 3x3 do Wahl-O-Mat - dist nao-ponderada."""

    @pytest.mark.parametrize(
        "user_stance,cand_stance,expected_dist",
        [
            (Stance.AGREE,    Stance.AGREE,    0),
            (Stance.AGREE,    Stance.NEUTRAL,  1),
            (Stance.AGREE,    Stance.DISAGREE, 2),
            (Stance.NEUTRAL,  Stance.AGREE,    1),
            (Stance.NEUTRAL,  Stance.NEUTRAL,  0),
            (Stance.NEUTRAL,  Stance.DISAGREE, 1),
            (Stance.DISAGREE, Stance.AGREE,    2),
            (Stance.DISAGREE, Stance.NEUTRAL,  1),
            (Stance.DISAGREE, Stance.DISAGREE, 0),
        ],
    )
    def test_distance_matrix(self, user_stance, cand_stance, expected_dist):
        sb = score([_u(1, user_stance)], [_c(1, cand_stance)])
        assert sb.total_distance == expected_dist
        assert sb.max_distance == 2
        assert sb.counted_theses == 1


class TestScoreReferenceExample:
    """Exemplo reprodutivel do design spec 7.2."""

    def test_reference_example(self):
        answers = [_u(1, Stance.AGREE), _u(2, Stance.AGREE), _u(3, Stance.DISAGREE)]
        stances = [_c(1, Stance.AGREE), _c(2, Stance.NEUTRAL), _c(3, Stance.AGREE)]
        sb = score(answers, stances)
        assert sb.total_distance == 3
        assert sb.max_distance == 6
        assert sb.score_percent == 50.0
        assert sb.exact_matches == 1
        assert sb.total_mismatches == 1
        assert sb.counted_theses == 3


class TestScoreInvariants:
    def test_bounds_score_percent(self):
        sb = score(
            [_u(1, Stance.AGREE), _u(2, Stance.DISAGREE)],
            [_c(1, Stance.NEUTRAL), _c(2, Stance.NEUTRAL)],
        )
        assert 0.0 <= sb.score_percent <= 100.0

    def test_all_agree_is_perfect_match(self):
        answers = [_u(i, Stance.AGREE) for i in range(1, 4)]
        stances = [_c(i, Stance.AGREE) for i in range(1, 4)]
        sb = score(answers, stances)
        assert sb.score_percent == 100.0
        assert sb.exact_matches == sb.counted_theses == 3
        assert sb.total_mismatches == 0

    def test_total_opposition_is_zero(self):
        answers = [_u(i, Stance.AGREE) for i in range(1, 4)]
        stances = [_c(i, Stance.DISAGREE) for i in range(1, 4)]
        sb = score(answers, stances)
        assert sb.score_percent == 0.0
        assert sb.total_mismatches == sb.counted_theses == 3
        assert sb.exact_matches == 0

    def test_order_independent(self):
        a = [_u(1, Stance.AGREE), _u(2, Stance.DISAGREE), _u(3, Stance.NEUTRAL)]
        b = [a[2], a[0], a[1]]
        s = [_c(1, Stance.NEUTRAL), _c(2, Stance.NEUTRAL), _c(3, Stance.AGREE)]
        assert score(a, s) == score(b, s)


class TestScoreExclusion:
    def test_skip_excluded(self):
        sb = score(
            [_u(1, Stance.SKIP), _u(2, Stance.AGREE)],
            [_c(1, Stance.DISAGREE), _c(2, Stance.AGREE)],
        )
        assert sb.counted_theses == 1
        assert sb.score_percent == 100.0

    def test_no_opinion_excluded(self):
        sb = score(
            [_u(1, Stance.AGREE), _u(2, Stance.AGREE)],
            [_c(1, Stance.AGREE), _c(2, Stance.NO_OPINION)],
        )
        assert sb.counted_theses == 1
        assert sb.score_percent == 100.0

    def test_candidate_missing_thesis_excluded(self):
        sb = score([_u(1, Stance.AGREE), _u(2, Stance.AGREE)], [_c(1, Stance.AGREE)])
        assert sb.counted_theses == 1

    def test_all_excluded_returns_zero_sentinel(self):
        sb = score([_u(1, Stance.SKIP)], [_c(1, Stance.AGREE)])
        assert sb.counted_theses == 0
        assert sb.score_percent == 0.0
        assert sb.total_distance == 0
        assert sb.max_distance == 0


class TestScoreWeighting:
    def test_double_weight_amplifies_distance(self):
        sb = score([_u(1, Stance.AGREE, Weight.DOUBLE)], [_c(1, Stance.DISAGREE)])
        assert sb.total_distance == 4
        assert sb.max_distance == 4
        assert sb.score_percent == 0.0

    def test_double_weight_equals_duplicated_thesis(self):
        sb_double = score(
            [_u(1, Stance.AGREE, Weight.DOUBLE), _u(2, Stance.DISAGREE)],
            [_c(1, Stance.NEUTRAL), _c(2, Stance.DISAGREE)],
        )
        sb_dup = score(
            [
                _u(1, Stance.AGREE),
                _u(2, Stance.AGREE),
                _u(3, Stance.DISAGREE),
            ],
            [_c(1, Stance.NEUTRAL), _c(2, Stance.NEUTRAL), _c(3, Stance.DISAGREE)],
        )
        assert sb_double.score_percent == sb_dup.score_percent

    def test_weight_ignored_in_exact_matches_counter(self):
        sb = score(
            [_u(1, Stance.AGREE, Weight.DOUBLE), _u(2, Stance.AGREE)],
            [_c(1, Stance.AGREE), _c(2, Stance.AGREE)],
        )
        assert sb.exact_matches == 2

    def test_weight_ignored_in_mismatches_counter(self):
        sb = score(
            [_u(1, Stance.AGREE, Weight.DOUBLE)], [_c(1, Stance.DISAGREE)]
        )
        assert sb.total_mismatches == 1


class TestValidateMinimum:
    def test_accepts_exactly_five(self):
        answers = [_u(i, Stance.AGREE) for i in range(1, 6)]
        validate_minimum(answers)

    def test_accepts_more_than_five(self):
        answers = [_u(i, Stance.AGREE) for i in range(1, 11)]
        validate_minimum(answers)

    def test_rejects_four(self):
        answers = [_u(i, Stance.AGREE) for i in range(1, 5)]
        with pytest.raises(InsufficientAnswersError) as exc:
            validate_minimum(answers)
        assert exc.value.provided == 4
        assert exc.value.required == 5

    def test_rejects_zero(self):
        with pytest.raises(InsufficientAnswersError) as exc:
            validate_minimum([])
        assert exc.value.provided == 0

    def test_skip_does_not_count(self):
        answers = [_u(i, Stance.AGREE) for i in range(1, 6)]
        answers[0] = _u(1, Stance.SKIP)
        answers[1] = _u(2, Stance.SKIP)
        with pytest.raises(InsufficientAnswersError) as exc:
            validate_minimum(answers)
        assert exc.value.provided == 3


def _sb(
    score_pct: float, exact: int = 0, mismatches: int = 0, counted: int = 10
) -> ScoreBreakdown:
    return ScoreBreakdown(
        total_distance=0,
        max_distance=20,
        score_percent=score_pct,
        exact_matches=exact,
        total_mismatches=mismatches,
        counted_theses=counted,
    )


class TestRank:
    def test_sorts_by_score_desc(self):
        result = rank([
            ("c1", "Alice", _sb(50.0)),
            ("c2", "Bob", _sb(80.0)),
            ("c3", "Carol", _sb(30.0)),
        ])
        assert [r.candidate_id for r in result] == ["c2", "c1", "c3"]
        assert [r.rank for r in result] == [1, 2, 3]

    def test_tiebreak_by_exact_matches_desc(self):
        result = rank([
            ("c1", "Alice", _sb(70.0, exact=3)),
            ("c2", "Bob", _sb(70.0, exact=5)),
        ])
        assert [r.candidate_id for r in result] == ["c2", "c1"]
        assert [r.rank for r in result] == [1, 2]

    def test_tiebreak_by_total_mismatches_asc(self):
        result = rank([
            ("c1", "Alice", _sb(70.0, exact=5, mismatches=2)),
            ("c2", "Bob", _sb(70.0, exact=5, mismatches=1)),
        ])
        assert [r.candidate_id for r in result] == ["c2", "c1"]

    def test_tiebreak_by_name_asc(self):
        result = rank([
            ("c1", "Bob", _sb(70.0, exact=5, mismatches=1)),
            ("c2", "Alice", _sb(70.0, exact=5, mismatches=1)),
        ])
        assert [r.candidate_id for r in result] == ["c2", "c1"]

    def test_name_normalization_accent_insensitive(self):
        result = rank([
            ("c1", "Bruno", _sb(70.0, exact=5, mismatches=1)),
            ("c2", "Álvaro", _sb(70.0, exact=5, mismatches=1)),
        ])
        assert [r.candidate_id for r in result] == ["c2", "c1"]

    def test_true_tie_shares_rank_olympic(self):
        result = rank([
            ("c1", "Alice", _sb(70.0, exact=5, mismatches=1)),
            ("c2", "Alice", _sb(70.0, exact=5, mismatches=1)),
            ("c3", "Alice", _sb(70.0, exact=5, mismatches=1)),
            ("c4", "Zoe",   _sb(60.0)),
        ])
        ranks = {r.candidate_id: r.rank for r in result}
        assert ranks["c1"] == ranks["c2"] == ranks["c3"] == 1
        assert ranks["c4"] == 4

    def test_empty_input(self):
        assert rank([]) == []

    def test_idempotent(self):
        inputs = [
            ("c1", "Alice", _sb(50.0, exact=2)),
            ("c2", "Bob", _sb(50.0, exact=3)),
            ("c3", "Carol", _sb(80.0)),
        ]
        once = rank(inputs)
        twice = rank([(r.candidate_id, r.name, r.score) for r in once])
        assert [r.candidate_id for r in once] == [r.candidate_id for r in twice]

    def test_permutation_invariant(self):
        a = rank([
            ("c1", "Alice", _sb(50.0)),
            ("c2", "Bob", _sb(80.0)),
        ])
        b = rank([
            ("c2", "Bob", _sb(80.0)),
            ("c1", "Alice", _sb(50.0)),
        ])
        assert [r.candidate_id for r in a] == [r.candidate_id for r in b]

    def test_returns_ranked_candidate_instances(self):
        result = rank([("c1", "Alice", _sb(50.0))])
        assert isinstance(result[0], RankedCandidate)


_user_stances = st.sampled_from([Stance.AGREE, Stance.NEUTRAL, Stance.DISAGREE])
_cand_stances = st.sampled_from([Stance.AGREE, Stance.NEUTRAL, Stance.DISAGREE])


@st.composite
def _answer_pairs(draw, n: int = 10):
    ids = list(range(1, n + 1))
    answers = [
        UserAnswer(
            thesis_id=i,
            stance=draw(_user_stances),
            weight=draw(st.sampled_from([Weight.NORMAL, Weight.DOUBLE])),
        )
        for i in ids
    ]
    stances = [
        CandidateStance(thesis_id=i, stance=draw(_cand_stances)) for i in ids
    ]
    return answers, stances


class TestScoreProperties:
    @given(_answer_pairs(n=10))
    def test_score_always_in_bounds(self, pair):
        answers, stances = pair
        sb = score(answers, stances)
        assert 0.0 <= sb.score_percent <= 100.0
        assert 0 <= sb.total_distance <= sb.max_distance

    @given(_answer_pairs(n=10))
    def test_score_order_independent(self, pair):
        answers, stances = pair
        shuffled_a = answers[:]
        shuffled_s = stances[:]
        random.seed(42)
        random.shuffle(shuffled_a)
        random.shuffle(shuffled_s)
        assert score(answers, stances) == score(shuffled_a, shuffled_s)

    @given(_answer_pairs(n=5))
    def test_adding_exact_match_never_lowers_score(self, pair):
        answers, stances = pair
        base = score(answers, stances)
        extra_a = UserAnswer(thesis_id=999, stance=Stance.AGREE)
        extra_c = CandidateStance(thesis_id=999, stance=Stance.AGREE)
        new = score([*answers, extra_a], [*stances, extra_c])
        assert new.score_percent >= base.score_percent
