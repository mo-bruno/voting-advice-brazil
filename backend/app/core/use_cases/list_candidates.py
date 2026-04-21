from app.core.entities.candidate import Candidate
from app.core.use_cases.interfaces import CandidateRepository


def list_candidates(
    repo: CandidateRepository,
    cargo: str | None = None,
    estado: str | None = None,
    partido: str | None = None,
    search: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Candidate], int]:
    page_size = min(page_size, 50)
    return repo.list(
        cargo=cargo,
        estado=estado,
        partido=partido,
        search=search,
        page=page,
        page_size=page_size,
    )
