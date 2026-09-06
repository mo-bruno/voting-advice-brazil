"""Feeds RSS temáticos da Agência Câmara.

O feed entrega title, link, guid, pubDate, description e content:encoded — e
mais nada. Imagem, tempo de leitura e categoria são derivados aqui, porque são
detalhe do formato da fonte, não regra de negócio.

Limite conhecido da fonte: 10 itens por feed, sem paginação.
"""

from __future__ import annotations

import hashlib
import logging
import re
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Final
from xml.etree import ElementTree

import httpx

from app.core.entities.news import NewsArticle
from app.core.use_cases.interfaces import WeeklyNewsSource

BASE_URL: Final[str] = "https://www.camara.leg.br/noticias/rss/dinamico"
TIMEOUT_SECONDS: Final[float] = 8.0
WORDS_PER_MINUTE: Final[int] = 200

# (segmento no feed, slug interno, rótulo exibido)
FEEDS: Final[tuple[tuple[str, str, str], ...]] = (
    ("POLITICA", "politica", "POLÍTICA"),
    ("ELEICOES", "eleicoes", "ELEIÇÕES"),
    ("ECONOMIA", "economia", "ECONOMIA"),
)

_CONTENT_TAG: Final[str] = "{http://purl.org/rss/1.0/modules/content/}encoded"
_IMG_RE: Final[re.Pattern[str]] = re.compile(r"<img[^>]+src=\"([^\"]+)\"", re.IGNORECASE)
_TAG_RE: Final[re.Pattern[str]] = re.compile(r"<[^>]+>")

_log = logging.getLogger(__name__)


def extract_image_url(content_html: str) -> str | None:
    match = _IMG_RE.search(content_html)
    return match.group(1) if match else None


def reading_minutes(content_html: str) -> int:
    words = len(_TAG_RE.sub(" ", content_html).split())
    return max(1, round(words / WORDS_PER_MINUTE))


def parse_pub_date(raw: str) -> datetime | None:
    try:
        parsed = parsedate_to_datetime(raw)
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def parse_feed(
    xml_bytes: bytes,
    theme_slug: str,
    theme_label: str,
) -> list[NewsArticle]:
    """Recebe bytes de propósito: o XML declara encoding, e `fromstring` sobre
    str com declaração de encoding é caso de borda que não vale a pena carregar.
    """
    try:
        root = ElementTree.fromstring(xml_bytes)
    except ElementTree.ParseError:
        _log.warning("camara_news: XML invalido no tema %s", theme_slug)
        return []

    articles: list[NewsArticle] = []
    for item in root.iter("item"):
        title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        if not title or not link:
            continue

        published_at = parse_pub_date((item.findtext("pubDate") or "").strip())
        if published_at is None:
            continue

        guid = (item.findtext("guid") or link).strip()
        content = item.findtext(_CONTENT_TAG) or ""

        articles.append(
            NewsArticle(
                id=hashlib.sha1(guid.encode("utf-8")).hexdigest(),
                title=title,
                summary=(item.findtext("description") or "").strip(),
                image_url=extract_image_url(content),
                theme_slug=theme_slug,
                theme_label=theme_label,
                published_at=published_at,
                reading_minutes=reading_minutes(content),
                url=link,
            )
        )
    return articles


class CamaraNewsSource(WeeklyNewsSource):
    def __init__(self, base_url: str = BASE_URL) -> None:
        self._base_url = base_url

    def fetch_recent(self) -> list[NewsArticle]:
        articles: list[NewsArticle] = []
        for segment, slug, label in FEEDS:
            try:
                response = httpx.get(
                    f"{self._base_url}/{segment}",
                    timeout=TIMEOUT_SECONDS,
                    follow_redirects=True,
                )
                response.raise_for_status()
            except httpx.HTTPError:
                # Um tema fora do ar não derruba a tela: seguimos com os outros.
                _log.warning("camara_news: falha ao buscar o tema %s", segment)
                continue
            articles.extend(parse_feed(response.content, slug, label))
        return articles
