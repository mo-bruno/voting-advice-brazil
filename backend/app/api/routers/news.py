from datetime import datetime, timezone
from typing import Final
from urllib.parse import urlparse

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Response

from app.api.cache import cache_get, cache_set
from app.api.deps import get_weekly_news_source
from app.api.schemas.news import NewsArticleOut, WeeklyNewsResponse
from app.core.use_cases.interfaces import WeeklyNewsSource
from app.core.use_cases.list_weekly_news import list_weekly_news

router = APIRouter(prefix="/news", tags=["Notícias"])

CACHE_TTL_SECONDS = 1800

# Allowlist EXATA, não sufixo: "camara.leg.br.evil.com" e "evil-camara.leg.br"
# passariam num teste de sufixo ingênuo e transformariam isto num proxy aberto.
ALLOWED_IMAGE_HOSTS: Final[frozenset[str]] = frozenset(
    {"camara.leg.br", "www.camara.leg.br"}
)
IMAGE_TIMEOUT_SECONDS: Final[float] = 8.0
MAX_IMAGE_BYTES: Final[int] = 5 * 1024 * 1024
IMAGE_CACHE_SECONDS: Final[int] = 86400


def is_allowed_image_url(raw: str) -> bool:
    try:
        parsed = urlparse(raw)
    except ValueError:
        return False
    if parsed.scheme not in ("http", "https"):
        return False
    return (parsed.hostname or "").lower() in ALLOWED_IMAGE_HOSTS


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


@router.get(
    "/image",
    summary="Reserve uma imagem da Câmara com CORS",
    response_class=Response,
)
def news_image(url: str = Query(description="URL da imagem no domínio da Câmara")) -> Response:
    """A Câmara serve as imagens sem `access-control-allow-origin`, e o
    CanvasKit do Flutter Web precisa desse header para desenhá-las. Aqui a
    imagem é buscada no servidor e reservida com o CORS da nossa API.

    `follow_redirects=False` é deliberado: seguir redirecionamento permitiria
    escapar da allowlist e transformar isto num vetor de SSRF.
    """
    if not is_allowed_image_url(url):
        raise HTTPException(status_code=400, detail="URL de imagem não permitida.")

    try:
        upstream = httpx.get(
            url,
            timeout=IMAGE_TIMEOUT_SECONDS,
            follow_redirects=False,
        )
        upstream.raise_for_status()
    except httpx.HTTPError:
        raise HTTPException(
            status_code=502, detail="Não foi possível obter a imagem."
        ) from None

    media_type = upstream.headers.get("content-type", "")
    if not media_type.startswith("image/"):
        raise HTTPException(status_code=415, detail="O recurso não é uma imagem.")

    content = upstream.content
    if len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Imagem grande demais.")

    return Response(
        content=content,
        media_type=media_type,
        headers={"Cache-Control": f"public, max-age={IMAGE_CACHE_SECONDS}"},
    )
