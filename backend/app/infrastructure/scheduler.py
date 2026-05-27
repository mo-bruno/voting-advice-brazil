from __future__ import annotations

import logging
from datetime import datetime, timezone

from apscheduler.schedulers.background import BackgroundScheduler

from app.infrastructure.database.session import SessionLocal
from app.infrastructure.mqtt.publisher import PahoIotMqttPublisher
from app.infrastructure.sources.camara import CamaraClient

_log = logging.getLogger(__name__)
_scheduler = BackgroundScheduler(timezone="UTC")


def _fetch_recent_votes_for_actor(source_id: str, since: datetime) -> list[dict]:
    client = CamaraClient()
    votes = []
    try:
        votings = client.list_recent_votings(scan_limit=30)
    except Exception:
        return []
    for voting in votings:
        voting_date_str = voting.get("dataHoraRegistro") or voting.get("data") or ""
        if voting_date_str:
            try:
                voting_date = datetime.fromisoformat(
                    voting_date_str.replace("Z", "+00:00")
                )
                if voting_date < since:
                    continue
            except ValueError:
                pass

        voting_id = str(voting.get("id", ""))
        try:
            vote_payloads = client.list_votes_for_voting(voting_id)
        except Exception:
            continue

        for vp in vote_payloads:
            deputy = vp.get("deputado_") or {}
            if str(deputy.get("id", "")) != source_id:
                continue
            votes.append({
                "voting_id": voting_id,
                "vote": str(vp.get("tipoVoto", "")),
                "description": str(voting.get("descricao", "")),
                "deputy_name": str(deputy.get("nome", "")),
                "evidence_date": voting.get("dataHoraRegistro"),
            })
            break

    return votes


def _run_vote_notifier_job() -> None:
    from app.infrastructure.database.iot_device_repositories import (
        SqlIotDeviceEventRepository,
        SqlIotDeviceLinkRepository,
    )
    from app.infrastructure.database.political_actor_repositories import (
        SqlFollowedActorRepository,
        SqlPoliticalActorRepository,
    )
    from app.core.use_cases.vote_notifier import run_vote_notifier

    _log.info("vote_notifier: iniciando")
    now = datetime.now(timezone.utc)
    try:
        with SessionLocal() as db:
            run_vote_notifier(
                now=now,
                followed_repo=SqlFollowedActorRepository(db),
                link_repo=SqlIotDeviceLinkRepository(db),
                event_repo=SqlIotDeviceEventRepository(db),
                publisher=PahoIotMqttPublisher(),
                actor_repo=SqlPoliticalActorRepository(db),
                fetch_recent_votes=_fetch_recent_votes_for_actor,
            )
            _push_news_for_all_followers(db, now)
    except Exception:
        _log.exception("vote_notifier: erro inesperado")
    _log.info("vote_notifier: concluido")


def _push_news_for_all_followers(db: object, now: datetime) -> None:
    from sqlalchemy import select
    from sqlalchemy.orm import Session

    from app.core.config import settings
    from app.core.use_cases.news_notifier import push_news_for_user
    from app.infrastructure.database.iot_device_repositories import (
        SqlIotDeviceEventRepository,
        SqlIotDeviceLinkRepository,
    )
    from app.infrastructure.database.models import QuizResponseModel, ThemeModel, ThesisModel
    from app.infrastructure.database.political_actor_repositories import SqlFollowedActorRepository
    from app.infrastructure.sources.gnews import fetch_news_for_themes

    session = db  # type: ignore[assignment]
    assert isinstance(session, Session)

    followed_repo = SqlFollowedActorRepository(session)
    all_followed = followed_repo.list_all_followed()
    seen_anon_ids: set[str] = set()

    for _, anon_id in all_followed:
        if anon_id in seen_anon_ids:
            continue
        seen_anon_ids.add(anon_id)

        rows = session.execute(
            select(ThemeModel.slug)
            .join(ThesisModel, ThesisModel.theme_id == ThemeModel.id)
            .join(QuizResponseModel, QuizResponseModel.thesis_id == ThesisModel.id)
            .where(
                QuizResponseModel.device_id == anon_id,
                QuizResponseModel.answer.in_(["agree", "disagree"]),
            )
            .distinct()
        ).scalars().all()
        themes = list(rows)

        push_news_for_user(
            anonymous_id=anon_id,
            now=now,
            link_repo=SqlIotDeviceLinkRepository(session),
            event_repo=SqlIotDeviceEventRepository(session),
            publisher=PahoIotMqttPublisher(),
            fetch_themes=lambda _, t=themes: t,
            fetch_articles=lambda t: fetch_news_for_themes(
                t, api_key=settings.gnews_api_key or ""
            ),
        )


def start() -> None:
    _scheduler.add_job(
        _run_vote_notifier_job,
        trigger="interval",
        minutes=30,
        id="vote_notifier",
        replace_existing=True,
    )
    _scheduler.start()
    _log.info("scheduler: iniciado (vote_notifier a cada 30 min)")


def stop() -> None:
    if _scheduler.running:
        _scheduler.shutdown(wait=False)
