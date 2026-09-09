from typing import Final

MAX_COMMENTS_PER_WINDOW: Final[int] = 10
WINDOW_MINUTES: Final[int] = 10


class CommentRateLimitExceeded(Exception):
    def __init__(self) -> None:
        self.retry_after_seconds = WINDOW_MINUTES * 60
        super().__init__("Limite de comentários excedido.")


def check_comment_rate_limit(recent_count: int) -> None:
    if recent_count >= MAX_COMMENTS_PER_WINDOW:
        raise CommentRateLimitExceeded()
