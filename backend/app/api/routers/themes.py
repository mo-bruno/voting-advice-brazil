from fastapi import APIRouter, Depends

from app.api.cache import cache_get, cache_set
from app.api.deps import get_theme_repo
from app.api.schemas.themes import ThemeOut
from app.core.use_cases.list_themes import list_themes
from app.infrastructure.database.repositories import SqlThemeRepository

router = APIRouter(prefix="/themes", tags=["Temas"])

_THEMES_TTL = 6 * 3600  # 6 hours


@router.get("", response_model=list[ThemeOut], summary="Lista temas disponíveis no quiz")
def list_all(
    repo: SqlThemeRepository = Depends(get_theme_repo),
) -> list[ThemeOut]:
    cached = cache_get("themes:all")
    if cached is not None:
        return cached

    themes = list_themes(repo, min_theses=3)
    response = [
        ThemeOut(
            id=t.id,
            slug=t.slug,
            nome=t.name,
            area=t.area,
            descricao=t.description,
            icone_slug=t.icon_slug,
            total_teses_aprovadas=t.total_approved_theses,
        )
        for t in themes
    ]
    cache_set("themes:all", response, _THEMES_TTL)
    return response
