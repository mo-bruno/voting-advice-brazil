from datetime import datetime, timezone

from app.core.use_cases.interfaces import (
    FollowedActorRepository,
    IotDeviceEventRepository,
    IotDeviceLinkRepository,
    IotMqttPublisher,
)

ALIGNMENT_METADATA = {
    "aligned": {"color": "green", "description": "Voto alinhado ao usuario."},
    "divergent": {
        "color": "red",
        "description": "Voto divergente do usuario.",
    },
    "abstained": {"color": "yellow", "description": "Abstencao registrada."},
    "pending": {"color": "blue", "description": "Voto pendente."},
}


def _normalize_alignment(alignment: str) -> str:
    return alignment if alignment in ALIGNMENT_METADATA else "pending"


def _payload(
    deputy_name: str,
    party: str | None,
    state: str | None,
    vote: str,
    alignment: str,
    now: datetime,
) -> dict[str, str]:
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    now_utc = now.astimezone(timezone.utc)
    normalized = _normalize_alignment(alignment)
    meta = ALIGNMENT_METADATA[normalized]
    return {
        "type": "vote_alert",
        "deputy_name": deputy_name,
        "party": party or "",
        "state": state or "",
        "vote": vote,
        "alignment": normalized,
        "color": meta["color"],
        "description": meta["description"],
        "timestamp_utc": now_utc.isoformat().replace("+00:00", "Z"),
    }


def run_vote_notifier(
    *,
    followed_repo: FollowedActorRepository,
    link_repo: IotDeviceLinkRepository,
    event_repo: IotDeviceEventRepository,
    publisher: IotMqttPublisher,
    political_actor_id: int,
    deputy_name: str,
    party: str | None,
    state: str | None,
    vote: str,
    alignment: str,
    now: datetime,
) -> int:
    payload = _payload(
        deputy_name=deputy_name,
        party=party,
        state=state,
        vote=vote,
        alignment=alignment,
        now=now,
    )
    notified = 0
    for actor_id, anonymous_id in followed_repo.list_all_followed():
        if actor_id != political_actor_id:
            continue
        link = link_repo.get_by_anonymous_id(anonymous_id)
        if link is None:
            continue
        publisher.publish(topic=f"farol/{link.device_token}", payload=payload)
        event_repo.record(
            device_token=link.device_token,
            event_type="vote_alert",
            payload=payload,
            now=now,
        )
        notified += 1
    return notified
