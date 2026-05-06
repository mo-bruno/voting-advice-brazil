from app.core.entities.political_actor import TrendingActor
from app.core.use_cases.interfaces import FollowedActorRepository


def list_trending_political_actors(
    repo: FollowedActorRepository,
    limit: int = 10,
    min_followers: int = 2,
) -> list[TrendingActor]:
    return repo.list_trending(limit=limit, min_followers=min_followers)
