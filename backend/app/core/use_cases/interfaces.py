from abc import ABC, abstractmethod
from datetime import datetime

from app.core.entities.candidate import Candidate, CandidatePosition, Theme, Thesis
from app.core.entities.iot_device import IotDeviceLink, IotPairingSession
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
        expires_at: datetime,
        now: datetime,
    ) -> IotPairingSession: ...

    @abstractmethod
    def get_active_session(
        self,
        device_token: str,
        pairing_code_hash: str,
        now: datetime,
    ) -> IotPairingSession | None: ...

    @abstractmethod
    def consume_session(self, session_id: int, now: datetime) -> None: ...


class IotMqttPublisher(ABC):
    @abstractmethod
    def publish(self, topic: str, payload: dict[str, str]) -> None: ...
