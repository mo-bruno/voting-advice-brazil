from dataclasses import dataclass

from app.core.use_cases.interfaces import (
    FollowedActorRepository,
    IotDeviceLinkRepository,
    IotMqttPublisher,
)


@dataclass
class VoteEventInput:
    political_actor_id: int
    deputy_name: str
    vote_summary: str
    vote_type: str  # e.g. "Sim", "Não", "Abstenção"
    timestamp_utc: str  # ISO 8601


def notify_iot_for_vote(
    vote: VoteEventInput,
    followed_repo: FollowedActorRepository,
    iot_link_repo: IotDeviceLinkRepository,
    publisher: IotMqttPublisher,
) -> int:
    anonymous_ids = followed_repo.list_anonymous_ids_by_political_actor(
        vote.political_actor_id
    )
    notified = 0
    for anonymous_id in anonymous_ids:
        link = iot_link_repo.get_by_anonymous_id(anonymous_id)
        if link is None:
            continue
        publisher.publish(
            topic=f"farol/{link.device_token}",
            payload={
                "type": "vote_update",
                "color": _vote_color(vote.vote_type),
                "deputy_name": vote.deputy_name,
                "vote_summary": vote.vote_summary,
                "timestamp_utc": vote.timestamp_utc,
            },
        )
        notified += 1
    return notified


def _vote_color(vote_type: str) -> str:
    normalized = vote_type.strip().lower()
    if normalized in {"sim", "yes"}:
        return "green"
    if normalized in {"não", "nao", "no"}:
        return "red"
    return "yellow"
