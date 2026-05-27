from __future__ import annotations

import logging
from datetime import datetime, timezone

_log = logging.getLogger(__name__)

from app.core.use_cases.interfaces import (
    FollowedActorRepository,
    IotDeviceLinkRepository,
    IotMqttPublisher,
    OfficialEvidenceRepository,
    PoliticalActorRepository,
)
from app.core.use_cases.notify_iot_for_vote import VoteEventInput, notify_iot_for_vote
from app.infrastructure.sources.camara import CamaraEvidenceSource


def run_once(
    followed_repo: FollowedActorRepository,
    actor_repo: PoliticalActorRepository,
    link_repo: IotDeviceLinkRepository,
    evidence_repo: OfficialEvidenceRepository,
    camara: CamaraEvidenceSource,
    publisher: IotMqttPublisher,
) -> int:
    now = datetime.now(timezone.utc)
    actor_ids = followed_repo.list_followed_political_actor_ids()
    total_notified = 0

    for actor_id in actor_ids:
        actor = actor_repo.get_by_id(actor_id)
        if actor is None:
            continue

        existing, _ = evidence_repo.list_by_actor(actor_id, now)
        known_ids = {e.source_id for e in existing if e.evidence_type == "vote"}

        try:
            new_votes = camara.fetch_votes_for_actor(actor)
        except Exception:
            _log.exception("Camara fetch failed for actor_id=%s", actor_id)
            continue

        evidence_repo.replace_for_actor_type(actor_id, "vote", new_votes)

        for row in new_votes:
            if row["source_id"] in known_ids:
                continue
            normalized = row.get("normalized_payload") or {}
            vote_input = VoteEventInput(
                political_actor_id=actor_id,
                deputy_name=actor.display_name,
                vote_summary=str(row.get("summary") or ""),
                vote_type=str(normalized.get("vote") or ""),
                timestamp_utc=_iso(row.get("evidence_date"), now),
            )
            total_notified += notify_iot_for_vote(
                vote_input, followed_repo, link_repo, publisher
            )

    return total_notified


def _iso(value: object, fallback: datetime) -> str:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.isoformat()
    return fallback.isoformat()


if __name__ == "__main__":
    from app.infrastructure.database.iot_device_repositories import SqlIotDeviceLinkRepository
    from app.infrastructure.database.political_actor_repositories import (
        SqlFollowedActorRepository,
        SqlOfficialEvidenceRepository,
        SqlPoliticalActorRepository,
    )
    from app.infrastructure.database.session import SessionLocal
    from app.infrastructure.mqtt.publisher import PahoIotMqttPublisher
    from app.infrastructure.sources.camara import CamaraClient

    db = SessionLocal()
    try:
        notified = run_once(
            followed_repo=SqlFollowedActorRepository(db),
            actor_repo=SqlPoliticalActorRepository(db),
            link_repo=SqlIotDeviceLinkRepository(db),
            evidence_repo=SqlOfficialEvidenceRepository(db),
            camara=CamaraEvidenceSource(CamaraClient()),
            publisher=PahoIotMqttPublisher(),
        )
        print(f"[vote_notifier] Dispositivos notificados: {notified}")
    finally:
        db.close()
