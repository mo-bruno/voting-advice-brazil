from fastapi import APIRouter, Depends

from app.api.deps import get_theme_repo
from app.api.schemas.themes import ThemeOut
from app.core.use_cases.list_themes import list_themes
from app.infrastructure.database.repositories import SqlThemeRepository

router = APIRouter(prefix="/themes", tags=["Temas"])

@router.get("", response_model=list[ThemeOut], summary="Lista temas disponíveis no quiz")
def list_all(
    repo: SqlThemeRepository = Depends(get_theme_repo),
) -> list[ThemeOut]:
    themes = list_themes(repo, min_theses=1)
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
    return response
