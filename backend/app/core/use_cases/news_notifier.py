from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime
from typing import TYPE_CHECKING

from app.core.use_cases.interfaces import (
    IotDeviceEventRepository,
    IotDeviceLinkRepository,
    IotMqttPublisher,
)

if TYPE_CHECKING:
    from app.infrastructure.sources.gnews import NewsArticle

_log = logging.getLogger(__name__)

ThemesFetcher = Callable[[str], list[str]]
ArticlesFetcher = Callable[[list[str]], list["NewsArticle"]]


def push_news_for_user(
    anonymous_id: str,
    now: datetime,
    link_repo: IotDeviceLinkRepository,
    event_repo: IotDeviceEventRepository,
    publisher: IotMqttPublisher,
    fetch_themes: ThemesFetcher,
    fetch_articles: ArticlesFetcher,
) -> None:
    link = link_repo.get_by_anonymous_id(anonymous_id)
    if link is None:
        return

    themes = fetch_themes(anonymous_id)
    if not themes:
        return

    articles = fetch_articles(themes)
    if not articles:
        return

    payload: dict[str, object] = {
        "type": "news_batch",
        "articles": [
            {"title": a.title, "source": a.source, "date": a.date}
            for a in articles
        ],
    }

    try:
        event_repo.record(link.device_token, "news_batch", payload, now)
        mqtt_payload = {
            "type": "news_batch",
            "articles": "|".join(
                f"{a.title[:60]}#{a.source}#{a.date}" for a in articles
            ),
        }
        publisher.publish(f"farol/{link.device_token}", mqtt_payload)
    except Exception:
        _log.exception("Falha ao publicar news_batch para device %s", link.device_token)
