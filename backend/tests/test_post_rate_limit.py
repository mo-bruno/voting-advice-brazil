import pytest

from app.core.use_cases.post_rate_limit import (
    MAX_POSTS_PER_WINDOW,
    WINDOW_MINUTES,
    PostRateLimitExceeded,
    check_post_rate_limit,
)


def test_permite_ate_o_limite() -> None:
    for count in range(MAX_POSTS_PER_WINDOW):
        check_post_rate_limit(count)


def test_recusa_a_partir_do_limite() -> None:
    with pytest.raises(PostRateLimitExceeded) as exc:
        check_post_rate_limit(MAX_POSTS_PER_WINDOW)

    assert exc.value.retry_after_seconds == WINDOW_MINUTES * 60


def test_recusa_acima_do_limite() -> None:
    with pytest.raises(PostRateLimitExceeded):
        check_post_rate_limit(MAX_POSTS_PER_WINDOW + 10)


def test_constantes_batem_com_o_spec() -> None:
    assert MAX_POSTS_PER_WINDOW == 5
    assert WINDOW_MINUTES == 10
