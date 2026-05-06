from app.core.entities.political_actor import PoliticalActor
from app.core.use_cases.interfaces import PoliticalActorRepository


def list_political_actors(
    repo: PoliticalActorRepository,
    search: str | None = None,
    state: str | None = None,
    party: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[PoliticalActor], int]:
    return repo.list(
        search=search,
        state=state,
        party=party,
        page=page,
        page_size=page_size,
    )
