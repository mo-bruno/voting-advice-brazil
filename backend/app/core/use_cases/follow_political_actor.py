from app.core.entities.political_actor import FollowedActor
from app.core.use_cases.interfaces import (
    FollowedActorRepository,
    PoliticalActorRepository,
)


def follow_political_actor(
    follow_repo: FollowedActorRepository,
    actor_repo: PoliticalActorRepository,
    anonymous_id: str,
    actor_id: int,
) -> FollowedActor | None:
    if actor_repo.get_by_id(actor_id) is None:
        return None
    return follow_repo.set_followed(anonymous_id, actor_id)


def get_followed_political_actor(
    follow_repo: FollowedActorRepository,
    anonymous_id: str,
) -> FollowedActor | None:
    return follow_repo.get_followed(anonymous_id)


def delete_followed_political_actor(
    follow_repo: FollowedActorRepository,
    anonymous_id: str,
) -> bool:
    return follow_repo.delete_followed(anonymous_id)
