from fastapi import APIRouter, Depends, Query

from app.api.cache import cache_get, cache_set
from app.api.deps import get_candidate_repo, get_position_repo, get_thesis_repo
from app.api.schemas.quiz import (
    CandidateResultOut,
    QuestionsResponse,
    SubmitQuizIn,
    SubmitQuizResponse,
    ThesisMatchOut,
    ThesisOut,
)
from app.core.use_cases.get_quiz_questions import get_quiz_questions
from app.core.use_cases.submit_quiz import QuizAnswer, submit_quiz
from app.infrastructure.database.repositories import (
    SqlCandidateRepository,
    SqlPositionRepository,
    SqlThesisRepository,
)

router = APIRouter(prefix="/quiz", tags=["Quiz"])

_QUESTIONS_TTL = 3600  # 1 hour


@router.get("/questions", response_model=QuestionsResponse, summary="Retorna teses para o quiz")
def questions(
    themes: list[str] | None = Query(default=None, description="Filtrar por tema(s)"),
    limit: int = Query(default=30, ge=1, le=60),
    thesis_repo: SqlThesisRepository = Depends(get_thesis_repo),
) -> QuestionsResponse:
    cache_key = f"quiz:questions:{','.join(sorted(themes or []))}:{limit}"
    cached = cache_get(cache_key)
    if cached is not None:
        return cached

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


@router.post("/submit", response_model=SubmitQuizResponse, summary="Calcula ranking de candidatos")
def submit(
    body: SubmitQuizIn,
    thesis_repo: SqlThesisRepository = Depends(get_thesis_repo),
    candidate_repo: SqlCandidateRepository = Depends(get_candidate_repo),
    position_repo: SqlPositionRepository = Depends(get_position_repo),
) -> SubmitQuizResponse:
    answers = [
        QuizAnswer(thesis_id=a.thesis_id, answer=a.answer, weight=a.weight)
        for a in body.answers
    ]
    results = submit_quiz(answers, candidate_repo, position_repo, thesis_repo)
    return SubmitQuizResponse(
        results=[
            CandidateResultOut(
                candidate_id=r.candidate_id,
                name=r.name,
                party_acronym=r.party_acronym,
                party_logo_url=r.party_logo_url,
                score_percent=r.score_percent,
                score_by_theme=r.score_by_theme,
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
