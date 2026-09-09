import logging
from datetime import datetime, timezone

from app.core.use_cases.interfaces import (
    FollowedActorRepository,
    IotDeviceEventRepository,
    IotDeviceLinkRepository,
    IotMqttPublisher,
)

_log = logging.getLogger(__name__)

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
    source_event_id: str,
    deputy_name: str,
    party: str | None,
    state: str | None,
    vote: str,
    alignment: str,
    now: datetime,
) -> dict[str, object]:
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    now_utc = now.astimezone(timezone.utc)
    normalized = _normalize_alignment(alignment)
    meta = ALIGNMENT_METADATA[normalized]
    return {
        "type": "vote_alert",
        "source_event_id": source_event_id,
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
    source_event_id: str,
    deputy_name: str,
    party: str | None,
    state: str | None,
    vote: str,
    alignment: str,
    now: datetime,
) -> int:
    payload = _payload(
        source_event_id=source_event_id,
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
        # Reserve before publication: broker failures deliberately suppress retries.
        event = event_repo.record_once(
            device_token=link.device_token,
            event_type="vote_alert",
            deduplication_key=source_event_id,
            payload=payload,
            now=now,
        )
        if event is None:
            continue
        try:
            publisher.publish(
                topic=f"farol/{link.device_token}",
                payload={k: str(v) for k, v in payload.items()},
            )
        except Exception:
            # Broker exceptions can contain credentials or device tokens.
            _log.error("Falha ao publicar voto reservado; nova tentativa suprimida.")
            continue
        notified += 1
    return notified
