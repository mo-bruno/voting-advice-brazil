from app.core.entities.candidate import Theme
from app.core.use_cases.interfaces import ThemeRepository


def list_themes(repo: ThemeRepository, min_theses: int = 3) -> list[Theme]:
    themes = repo.list_with_min_theses(min_theses)
    return sorted(themes, key=lambda t: t.total_approved_theses, reverse=True)
