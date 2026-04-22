import pytest

from app.core.scoring import (
    CandidateStance,
    InsufficientAnswersError,
    MIN_ANSWERS,
    ScoreBreakdown,
    Stance,
    UserAnswer,
    Weight,
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
