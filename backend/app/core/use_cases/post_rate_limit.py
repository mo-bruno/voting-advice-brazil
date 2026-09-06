"""Limite de publicação por dispositivo.

A contagem vem do banco, não de memória de processo: o `slowapi` que o projeto
usa guarda contadores no processo, e com `max-instances=3` no Cloud Run o limite
efetivo seria o triplo do declarado, silenciosamente.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Final

MAX_POSTS_PER_WINDOW: Final[int] = 5
WINDOW_MINUTES: Final[int] = 10
WINDOW: Final[timedelta] = timedelta(minutes=WINDOW_MINUTES)


class PostRateLimitExceeded(Exception):
    def __init__(self, retry_after_seconds: int) -> None:
        self.retry_after_seconds = retry_after_seconds
        super().__init__(
            f"Limite de {MAX_POSTS_PER_WINDOW} publicações a cada "
            f"{WINDOW_MINUTES} minutos excedido."
        )


def check_post_rate_limit(recent_count: int) -> None:
    """Levanta `PostRateLimitExceeded` se o dispositivo já atingiu o limite.

    `recent_count` inclui posts removidos de propósito: apagar não deve liberar
    cota, senão o limite é contornável com publicar-e-apagar.
    """
    if recent_count >= MAX_POSTS_PER_WINDOW:
        raise PostRateLimitExceeded(retry_after_seconds=WINDOW_MINUTES * 60)
