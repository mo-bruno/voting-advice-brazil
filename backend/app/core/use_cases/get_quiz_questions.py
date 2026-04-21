import random

from app.core.entities.candidate import Thesis
from app.core.use_cases.interfaces import ThesisRepository


def get_quiz_questions(
    repo: ThesisRepository,
    themes: list[str] | None = None,
    limit: int = 30,
) -> list[Thesis]:
    theses = repo.list_approved(themes=themes, limit=limit)
    random.shuffle(theses)
    return theses[:limit]
