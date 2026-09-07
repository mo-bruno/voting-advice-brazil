from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class NewsArticle:
    """Uma notícia já normalizada, pronta para a API.

    `image_url` é anulável: o feed da Câmara não garante imagem em todo item.
    """

    id: str
    title: str
    summary: str
    image_url: str | None
    theme_slug: str
    theme_label: str
    published_at: datetime
    reading_minutes: int
    url: str
