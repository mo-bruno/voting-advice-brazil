from app.core.entities.political_actor import PoliticalActor
from app.core.use_cases.interfaces import PoliticalActorRepository


def get_political_actor(
    repo: PoliticalActorRepository,
    actor_id: int,
) -> PoliticalActor | None:
    return repo.get_by_id(actor_id)
