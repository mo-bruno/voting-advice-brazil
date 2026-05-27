from typing import cast

from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.cache import cache_get, cache_set
from app.api.deps import (
    get_candidate_repo,
    get_position_repo,
    get_quiz_response_repo,
    get_thesis_repo,
)
from app.api.schemas.quiz import (
    CandidateResultOut,
    QuestionsResponse,
    SubmitQuizIn,
    SubmitQuizResponse,
    ThesisMatchOut,
    ThesisOut,
)
from app.core.use_cases.get_quiz_questions import get_quiz_questions
from app.core.use_cases.submit_quiz import (
    InsufficientAnswersError,
    QuizAnswer,
    submit_quiz,
)
from app.infrastructure.database.repositories import (
    SqlCandidateRepository,
    SqlPositionRepository,
    SqlQuizResponseRepository,
    SqlThesisRepository,
)

router = APIRouter(prefix="/quiz", tags=["Quiz"])

_QUESTIONS_TTL = 3600  # 1 hour


def _deduplicate_answers(answers: list[QuizAnswer]) -> list[QuizAnswer]:
    latest_by_thesis_id: dict[int, QuizAnswer] = {}
    for answer in answers:
        latest_by_thesis_id.pop(answer.thesis_id, None)
        latest_by_thesis_id[answer.thesis_id] = answer
    return list(latest_by_thesis_id.values())


@router.get("/questions", response_model=QuestionsResponse, summary="Retorna teses para o quiz")
def questions(
    themes: list[str] | None = Query(default=None, description="Filtrar por tema(s)"),
    limit: int = Query(default=30, ge=1, le=60),
    thesis_repo: SqlThesisRepository = Depends(get_thesis_repo),
) -> QuestionsResponse:
    cache_key = f"quiz:questions:{','.join(sorted(themes or []))}:{limit}"
    cached = cache_get(cache_key)
    if cached is not None:
        return cast(QuestionsResponse, cached)

    theses = get_quiz_questions(thesis_repo, themes=themes, limit=limit)
    response = QuestionsResponse(
        theses=[
            ThesisOut(
                id=t.id,
                text=t.text,
                theme_id=t.theme_id,
                theme_name=t.theme_name,
                coverage=t.coverage,
            )
            for t in theses
        ],
        total=len(theses),
    )
    cache_set(cache_key, response, _QUESTIONS_TTL)
    return response


@router.post(
    "/submit",
    response_model=SubmitQuizResponse,
    summary="Calcula ranking de candidatos",
)
def submit(
    body: SubmitQuizIn,
    thesis_repo: SqlThesisRepository = Depends(get_thesis_repo),
    candidate_repo: SqlCandidateRepository = Depends(get_candidate_repo),
    position_repo: SqlPositionRepository = Depends(get_position_repo),
    quiz_response_repo: SqlQuizResponseRepository = Depends(get_quiz_response_repo),
) -> SubmitQuizResponse:
    answers = [
        QuizAnswer(thesis_id=a.thesis_id, answer=a.answer, weight=a.weight)
        for a in body.answers
    ]
    answers = _deduplicate_answers(answers)
    try:
        results = submit_quiz(answers, candidate_repo, position_repo, thesis_repo)
    except InsufficientAnswersError as err:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "insufficient_answers",
                "message": str(err),
                "provided": err.provided,
                "required": err.required,
            },
        ) from err

    if body.device_id is not None:
        quiz_response_repo.upsert_answers(str(body.device_id), answers)
        _push_news_async(str(body.device_id))

    return SubmitQuizResponse(
        results=[
            CandidateResultOut(
                candidate_id=r.candidate_id,
                name=r.name,
                party_acronym=r.party_acronym,
                party_logo_url=r.party_logo_url,
                score_percent=r.score_percent,
                score_by_theme=r.score_by_theme,
                rank=r.rank,
                matches=[
                    ThesisMatchOut(
                        thesis_id=m.thesis_id,
                        thesis_text=m.thesis_text,
                        theme_id=m.theme_id,
                        user_answer=m.user_answer,
                        candidate_position=m.candidate_position,
                        match_type=m.match_type,
                    )
                    for m in r.matches
                ],
            )
            for r in results
        ]
    )


import logging
from threading import Thread


_log_quiz = logging.getLogger(__name__)


def _push_news_async(anonymous_id: str) -> None:
    from app.core.use_cases.news_notifier import push_news_for_user
    from app.infrastructure.database.session import SessionLocal
    from app.infrastructure.sources.gnews import fetch_news_for_themes
    from app.core.config import settings
    from datetime import datetime, timezone
    from sqlalchemy import select
    from app.infrastructure.database.models import (
        QuizResponseModel, ThesisModel, ThemeModel
    )

    def _run():
        try:
            with SessionLocal() as session:
                rows = session.execute(
                    select(ThemeModel.slug)
                    .join(ThesisModel, ThesisModel.theme_id == ThemeModel.id)
                    .join(QuizResponseModel, QuizResponseModel.thesis_id == ThesisModel.id)
                    .where(
                        QuizResponseModel.device_id == anonymous_id,
                        QuizResponseModel.answer.in_(["agree", "disagree"]),
                    )
                    .distinct()
                ).scalars().all()
                themes = list(rows)

                from app.infrastructure.database.iot_device_repositories import (
                    SqlIotDeviceEventRepository,
                    SqlIotDeviceLinkRepository,
                )
                from app.infrastructure.mqtt.publisher import PahoIotMqttPublisher

                push_news_for_user(
                    anonymous_id=anonymous_id,
                    now=datetime.now(timezone.utc),
                    link_repo=SqlIotDeviceLinkRepository(session),
                    event_repo=SqlIotDeviceEventRepository(session),
                    publisher=PahoIotMqttPublisher(),
                    fetch_themes=lambda _: themes,
                    fetch_articles=lambda t: fetch_news_for_themes(
                        t, api_key=settings.gnews_api_key or ""
                    ),
                )
        except Exception:
            _log_quiz.exception("Falha ao pushear news para %s", anonymous_id)

    Thread(target=_run, daemon=True).start()
