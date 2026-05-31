from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.entities.community import ModerationResult
from app.infrastructure.database.community_repositories import (
    SqlCommentRepository,
    SqlModerationLogRepository,
    SqlPostRepository,
    SqlPostVoteRepository,
)
from app.infrastructure.database.iot_device_repositories import (
    SqlIotDeviceEventRepository,
    SqlIotDeviceLinkRepository,
    SqlIotPairingSessionRepository,
)
from app.infrastructure.database.political_actor_repositories import (
    SqlFollowedActorRepository,
    SqlOfficialEvidenceRepository,
    SqlPoliticalActorRepository,
)
from app.infrastructure.database.repositories import (
    SqlCandidateRepository,
    SqlPositionRepository,
    SqlQuizResponseRepository,
    SqlThemeRepository,
    SqlThesisRepository,
)
from app.infrastructure.database.session import get_db
from app.infrastructure.llm.moderation_client import (
    GroqModerationClient,
    ModerationPort,
    ModerationUnavailable,
)
from app.infrastructure.mqtt.publisher import PahoIotMqttPublisher
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


def get_quiz_response_repo(db: Session = Depends(get_db)) -> SqlQuizResponseRepository:
    return SqlQuizResponseRepository(db)


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


def get_iot_device_link_repo(
    db: Session = Depends(get_db),
) -> SqlIotDeviceLinkRepository:
    return SqlIotDeviceLinkRepository(db)


def get_iot_pairing_session_repo(
    db: Session = Depends(get_db),
) -> SqlIotPairingSessionRepository:
    return SqlIotPairingSessionRepository(db)


def get_iot_mqtt_publisher() -> PahoIotMqttPublisher:
    return PahoIotMqttPublisher()


def get_iot_device_event_repo(
    db: Session = Depends(get_db),
) -> SqlIotDeviceEventRepository:
    return SqlIotDeviceEventRepository(db)


def get_camara_deputy_index_source() -> CamaraDeputyIndexSource:
    return CamaraDeputyIndexSource(CamaraClient())


def get_camara_evidence_source() -> CamaraEvidenceSource:
    return CamaraEvidenceSource(CamaraClient())


def get_post_repo(db: Session = Depends(get_db)) -> SqlPostRepository:
    return SqlPostRepository(db)


def get_comment_repo(db: Session = Depends(get_db)) -> SqlCommentRepository:
    return SqlCommentRepository(db)


def get_vote_repo(db: Session = Depends(get_db)) -> SqlPostVoteRepository:
    return SqlPostVoteRepository(db)


def get_moderation_log_repo(db: Session = Depends(get_db)) -> SqlModerationLogRepository:
    return SqlModerationLogRepository(db)


class _UnconfiguredModerationClient(ModerationPort):
    """Usado quando GROQ_API_KEY não está configurada — retorna 503 em vez de aprovar tudo."""

    def moderate(self, content: str) -> ModerationResult:
        raise ModerationUnavailable("GROQ_API_KEY não configurada")


def get_moderation_client() -> ModerationPort:
    if settings.groq_api_key:
        return GroqModerationClient(settings.groq_api_key)
    return _UnconfiguredModerationClient()
