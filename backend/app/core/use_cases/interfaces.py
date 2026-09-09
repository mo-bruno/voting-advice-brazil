from abc import ABC, abstractmethod
from datetime import datetime

from app.core.entities.candidate import Candidate, CandidatePosition, Theme, Thesis
from app.core.entities.iot_device import (
    IotDeviceEvent,
    IotDeviceLink,
    IotPairingSession,
)
from app.core.entities.political_actor import (
    FollowedActor,
    OfficialEvidence,
    PoliticalActor,
    TrendingActor,
)


class ThesisRepository(ABC):
    @abstractmethod
    def list_approved(
        self,
        themes: list[str] | None = None,
        limit: int = 30,
    ) -> list[Thesis]: ...

    @abstractmethod
    def get_by_ids(self, ids: list[int]) -> list[Thesis]: ...


class CandidateRepository(ABC):
    @abstractmethod
    def get_by_id(self, candidate_id: int) -> Candidate | None: ...

    @abstractmethod
    def list(
        self,
        cargo: str | None = None,
        estado: str | None = None,
        partido: str | None = None,
        search: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[Candidate], int]: ...


class PositionRepository(ABC):
    @abstractmethod
    def get_by_candidate(self, candidate_id: int) -> list[CandidatePosition]: ...

    @abstractmethod
    def get_by_candidates_and_theses(
        self,
        candidate_ids: list[int],
        thesis_ids: list[int],
    ) -> dict[int, dict[int, CandidatePosition]]: ...


class ThemeRepository(ABC):
    @abstractmethod
    def list_with_min_theses(self, min_theses: int = 3) -> list[Theme]: ...


class PoliticalActorRepository(ABC):
    @abstractmethod
    def get_by_id(self, actor_id: int) -> PoliticalActor | None: ...

    @abstractmethod
    def get_by_source(self, source: str, source_id: str) -> PoliticalActor | None: ...

    @abstractmethod
    def list(
        self,
        search: str | None = None,
        state: str | None = None,
        party: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[PoliticalActor], int]: ...


class OfficialEvidenceRepository(ABC):
    @abstractmethod
    def list_by_actor(
        self,
        actor_id: int,
        now: datetime,
    ) -> tuple[list[OfficialEvidence], bool]: ...

    @abstractmethod
    def replace_for_actor_type(
        self,
        actor_id: int,
        evidence_type: str,
        rows: list[dict[str, object]],
    ) -> None: ...


class FollowedActorRepository(ABC):
    @abstractmethod
    def get_followed(self, anonymous_id: str) -> FollowedActor | None: ...

    @abstractmethod
    def set_followed(self, anonymous_id: str, actor_id: int) -> FollowedActor: ...

    @abstractmethod
    def delete_followed(self, anonymous_id: str) -> bool: ...

    @abstractmethod
    def list_trending(
        self,
        limit: int = 10,
        min_followers: int = 2,
    ) -> list[TrendingActor]: ...

    @abstractmethod
    def list_all_followed(self) -> list[tuple[int, str]]: ...


class IotDeviceLinkRepository(ABC):
    @abstractmethod
    def get_by_anonymous_id(self, anonymous_id: str) -> IotDeviceLink | None: ...

    @abstractmethod
    def get_by_token(self, device_token: str) -> IotDeviceLink | None: ...

    @abstractmethod
    def get_conflicting_link(
        self,
        anonymous_id: str,
        device_token: str,
    ) -> IotDeviceLink | None: ...

    @abstractmethod
    def set_link(
        self,
        anonymous_id: str,
        device_token: str,
        now: datetime,
    ) -> IotDeviceLink: ...

    @abstractmethod
    def delete_by_anonymous_id(self, anonymous_id: str) -> bool: ...


class IotPairingSessionRepository(ABC):
    @abstractmethod
    def create_session(
        self,
        device_token: str,
        pairing_code_hash: str,
        qr_payload: str,
        firmware_version: str | None,
        now: datetime,
        expires_at: datetime,
    ) -> IotPairingSession: ...

    @abstractmethod
    def get_active_session(
        self,
        device_token: str,
        pairing_code_hash: str,
        now: datetime,
    ) -> IotPairingSession | None: ...

    @abstractmethod
    def list_active_sessions_by_token_prefix(
        self,
        device_token_prefix: str,
        now: datetime,
    ) -> list[IotPairingSession]: ...

    @abstractmethod
    def consume_session(self, session_id: int, now: datetime) -> None: ...


class IotMqttPublisher(ABC):
    @abstractmethod
    def publish(self, topic: str, payload: dict[str, str]) -> None: ...


class IotDeviceEventRepository(ABC):
    @abstractmethod
    def record(
        self,
        device_token: str,
        event_type: str,
        payload: dict[str, object],
        now: datetime,
    ) -> IotDeviceEvent: ...

    @abstractmethod
    def get_latest(
        self,
        device_token: str,
        event_type: str,
    ) -> IotDeviceEvent | None: ...


# ── Community ──────────────────────────────────────────────────────────────

from app.core.entities.community import (  # noqa: E402
    Comment,
    ModerationResult,
    Post,
    PostReport,
    PostVote,
)


class ModerationPort(ABC):
    @abstractmethod
    def moderate(
        self,
        content: str,
        report_reasons: list[str] | None = None,
    ) -> ModerationResult: ...


class ModerationUnavailable(Exception):
    """Raised when required content moderation cannot produce a decision."""


class PostRepository(ABC):
    @abstractmethod
    def create(self, post: Post) -> Post: ...

    @abstractmethod
    def get_by_id(self, post_id: str) -> Post | None: ...

    @abstractmethod
    def list(
        self,
        page: int = 1,
        page_size: int = 20,
        political_actor_id: int | None = None,
        theme_slug: str | None = None,
        sort: str = "score",
    ) -> tuple[list[Post], int]: ...

    @abstractmethod
    def update_score(self, post_id: str, new_score: int) -> None: ...

    @abstractmethod
    def count_by_author_since(self, anonymous_id: str, since: datetime) -> int: ...

    @abstractmethod
    def mark_removed(self, post_id: str, removed_by: str, now: datetime) -> None: ...


class CommentRepository(ABC):
    @abstractmethod
    def create(self, comment: Comment) -> Comment: ...

    @abstractmethod
    def list_by_post(self, post_id: str) -> list[Comment]: ...


class PostVoteRepository(ABC):
    @abstractmethod
    def upsert(self, vote: PostVote) -> int: ...

    @abstractmethod
    def get(self, post_id: str, anonymous_id: str) -> PostVote | None: ...


class PostReportRepository(ABC):
    @abstractmethod
    def upsert(self, report: PostReport) -> None: ...

    @abstractmethod
    def count_distinct_reporters(self, post_id: str) -> int: ...

    @abstractmethod
    def reasons_for_post(self, post_id: str) -> list[str]: ...


class ModerationLogRepository(ABC):
    @abstractmethod
    def record(
        self,
        post_id: str | None,
        anonymous_id: str,
        content_hash: str,
        approved: bool,
        reason: str | None,
        model_used: str,
    ) -> None: ...


# ── News ───────────────────────────────────────────────────────────────────

from app.core.entities.news import NewsArticle  # noqa: E402


class WeeklyNewsSource(ABC):
    @abstractmethod
    def fetch_recent(self) -> list[NewsArticle]: ...
