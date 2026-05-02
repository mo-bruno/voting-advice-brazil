from app.core.entities.candidate import Candidate
from app.core.use_cases.interfaces import CandidateRepository


def get_candidate(repo: CandidateRepository, candidate_id: int) -> Candidate | None:
    return repo.get_by_id(candidate_id)
