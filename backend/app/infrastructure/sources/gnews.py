from __future__ import annotations

import hashlib
import time

import httpx

from app.core.entities.news import DeviceNewsArticle

GNEWS_BASE = "https://gnews.io/api/v4/search"
_CACHE: dict[str, tuple[list[DeviceNewsArticle], float]] = {}
_CACHE_TTL_SECONDS = 3600


def _cache_key(themes: list[str]) -> str:
    joined = ",".join(sorted(themes))
    return hashlib.sha1(joined.encode()).hexdigest()


def fetch_news_for_themes(
    themes: list[str],
    api_key: str,
    max_articles: int = 5,
) -> list[DeviceNewsArticle]:
    if not themes or not api_key:
        return []

    key = _cache_key(themes)
    cached, expires_at = _CACHE.get(key, ([], 0.0))
    if expires_at > time.monotonic():
        return cached

    query = " OR ".join(f'"{t}"' for t in themes[:4]) + " Brasil"
    try:
        resp = httpx.get(
            GNEWS_BASE,
            params={
                "q": query,
                "lang": "pt",
                "country": "br",
                "max": max_articles,
                "token": api_key,
            },
            timeout=8.0,
        )
        if resp.status_code != 200:
            return []
        data = resp.json()
        articles = []
        for item in data.get("articles", [])[:max_articles]:
            pub = item.get("publishedAt", "")[:10]
            try:
                from datetime import datetime

                dt = datetime.fromisoformat(pub)
                date_str = dt.strftime("%d/%m")
            except Exception:
                date_str = pub

            source = item.get("source", {}).get("name", "")
            title = item.get("title", "")[:100]
            articles.append(
                DeviceNewsArticle(title=title, source=source, date=date_str)
            )
    except Exception:
        return []

    _CACHE[key] = (articles, time.monotonic() + _CACHE_TTL_SECONDS)
    return articles
