"""Recorte semanal das notícias. Função pura: sem HTTP, sem XML, sem relógio.

O chamador injeta a fonte e o instante de referência, o que torna o teste
determinístico sem congelar o tempo.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Final

from app.core.entities.news import NewsArticle
from app.core.use_cases.interfaces import WeeklyNewsSource

WINDOW_DAYS: Final[int] = 7
DEFAULT_LIMIT: Final[int] = 10

_MONTHS_ABBR: Final[tuple[str, ...]] = (
    "JAN",
    "FEV",
    "MAR",
    "ABR",
    "MAI",
    "JUN",
    "JUL",
    "AGO",
    "SET",
    "OUT",
    "NOV",
    "DEZ",
)


@dataclass(frozen=True, slots=True)
class WeeklyNews:
    period_start: datetime
    period_end: datetime
    period_label: str
    articles: list[NewsArticle]


def format_period_label(start: datetime, end: datetime) -> str:
    """Ex.: "30 DE AGO A 6 DE SET DE 2026"."""
    return (
        f"{start.day} DE {_MONTHS_ABBR[start.month - 1]} "
        f"A {end.day} DE {_MONTHS_ABBR[end.month - 1]} DE {end.year}"
    )


def list_weekly_news(
    source: WeeklyNewsSource,
    now: datetime,
    limit: int = DEFAULT_LIMIT,
) -> WeeklyNews:
    start = now - timedelta(days=WINDOW_DAYS)

    seen: set[str] = set()
    kept: list[NewsArticle] = []
    for article in source.fetch_recent():
        if article.published_at < start or article.published_at > now:
            continue
        if article.id in seen:
            continue
        seen.add(article.id)
        kept.append(article)

    kept.sort(key=lambda a: a.published_at, reverse=True)

    return WeeklyNews(
        period_start=start,
        period_end=now,
        period_label=format_period_label(start, now),
        articles=kept[:limit],
    )
