import hashlib

from app.core.entities.political_actor import PoliticianFollowInterest
from app.core.use_cases.interfaces import PoliticianFollowInterestRepository

_HASH_CONTEXT = "politician-follow-interest:v1:"


def _subject_hash(anonymous_id: str) -> str:
    contextualized = f"{_HASH_CONTEXT}{anonymous_id}"
    return hashlib.sha256(contextualized.encode("utf-8")).hexdigest()


def register_politician_follow_interest(
    repo: PoliticianFollowInterestRepository,
    anonymous_id: str,
) -> tuple[PoliticianFollowInterest, bool]:
    return repo.register(_subject_hash(anonymous_id))


def has_politician_follow_interest(
    repo: PoliticianFollowInterestRepository,
    anonymous_id: str,
) -> bool:
    return repo.get(_subject_hash(anonymous_id)) is not None


def delete_politician_follow_interest(
    repo: PoliticianFollowInterestRepository,
    anonymous_id: str,
) -> bool:
    return repo.delete(_subject_hash(anonymous_id))
