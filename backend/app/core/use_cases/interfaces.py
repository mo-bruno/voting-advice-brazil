from abc import ABC, abstractmethod

from app.core.entities.candidate import Candidate, CandidatePosition, Theme, Thesis


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
