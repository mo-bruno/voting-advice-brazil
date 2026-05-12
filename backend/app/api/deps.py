
from fastapi import Depends
from sqlalchemy.orm import Session

from app.infrastructure.database.repositories import (
    SqlCandidateRepository,
    SqlPositionRepository,
    SqlQuizResponseRepository,
    SqlThemeRepository,
    SqlThesisRepository,
)
from app.infrastructure.database.session import get_db


def get_thesis_repo(db: Session = Depends(get_db)) -> SqlThesisRepository:
    return SqlThesisRepository(db)


def get_candidate_repo(db: Session = Depends(get_db)) -> SqlCandidateRepository:
    return SqlCandidateRepository(db)


def get_position_repo(db: Session = Depends(get_db)) -> SqlPositionRepository:
    return SqlPositionRepository(db)


def get_quiz_response_repo(db: Session = Depends(get_db)) -> SqlQuizResponseRepository:
    return SqlQuizResponseRepository(db)


def get_theme_repo(db: Session = Depends(get_db)) -> SqlThemeRepository:
    return SqlThemeRepository(db)
