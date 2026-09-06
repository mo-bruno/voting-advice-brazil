from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query

from app.api.cache import cache_get, cache_set
from app.api.deps import get_weekly_news_source
from app.api.schemas.news import NewsArticleOut, WeeklyNewsResponse
from app.core.use_cases.interfaces import WeeklyNewsSource
from app.core.use_cases.list_weekly_news import list_weekly_news

router = APIRouter(prefix="/news", tags=["Notícias"])

CACHE_TTL_SECONDS = 1800


@router.get(
    "/weekly",
    response_model=WeeklyNewsResponse,
    summary="Notícias oficiais dos últimos 7 dias",
)
def weekly_news(
    limit: int = Query(default=10, ge=1, le=20),
    source: WeeklyNewsSource = Depends(get_weekly_news_source),
) -> WeeklyNewsResponse:
    cache_key = f"news:weekly:{limit}"
    cached = cache_get(cache_key)
    if cached is not None:
        return cached  # type: ignore[no-any-return]

    result = list_weekly_news(source, now=datetime.now(timezone.utc), limit=limit)

    response = WeeklyNewsResponse(
        period_start=result.period_start.date(),
        period_end=result.period_end.date(),
        period_label=result.period_label,
        total=len(result.articles),
        articles=[
            NewsArticleOut(
                id=a.id,
                title=a.title,
                summary=a.summary,
                image_url=a.image_url,
                theme_slug=a.theme_slug,
                theme_label=a.theme_label,
                published_at=a.published_at,
                reading_minutes=a.reading_minutes,
                url=a.url,
            )
            for a in result.articles
        ],
    )
    cache_set(cache_key, response, CACHE_TTL_SECONDS)
    return response
