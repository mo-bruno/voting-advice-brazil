
from fastapi import Depends
from sqlalchemy.orm import Session

from app.infrastructure.database.political_actor_repositories import (
    SqlFollowedActorRepository,
    SqlOfficialEvidenceRepository,
    SqlPoliticalActorRepository,
)
from app.infrastructure.database.repositories import (
    SqlCandidateRepository,
    SqlPositionRepository,
    SqlThemeRepository,
    SqlThesisRepository,
)
from app.infrastructure.database.session import get_db
from app.infrastructure.sources.camara import (
    CamaraClient,
    CamaraDeputyIndexSource,
    CamaraEvidenceSource,
)


def get_thesis_repo(db: Session = Depends(get_db)) -> SqlThesisRepository:
    return SqlThesisRepository(db)


def get_candidate_repo(db: Session = Depends(get_db)) -> SqlCandidateRepository:
    return SqlCandidateRepository(db)


def get_position_repo(db: Session = Depends(get_db)) -> SqlPositionRepository:
    return SqlPositionRepository(db)


def get_theme_repo(db: Session = Depends(get_db)) -> SqlThemeRepository:
    return SqlThemeRepository(db)


def get_political_actor_repo(
    db: Session = Depends(get_db),
) -> SqlPoliticalActorRepository:
    return SqlPoliticalActorRepository(db)


def get_official_evidence_repo(
    db: Session = Depends(get_db),
) -> SqlOfficialEvidenceRepository:
    return SqlOfficialEvidenceRepository(db)


def get_followed_actor_repo(
    db: Session = Depends(get_db),
) -> SqlFollowedActorRepository:
    return SqlFollowedActorRepository(db)


def get_camara_deputy_index_source() -> CamaraDeputyIndexSource:
    return CamaraDeputyIndexSource(CamaraClient())


def get_camara_evidence_source() -> CamaraEvidenceSource:
    return CamaraEvidenceSource(CamaraClient())
