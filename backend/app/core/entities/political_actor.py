from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class PoliticalActor:
    id: int
    source: str
    source_id: str
    normalized_name: str
    display_name: str
    party: str | None
    state: str | None
    role: str
    status: str
    photo_url: str | None
    source_url: str | None
    last_indexed_at: datetime


@dataclass(frozen=True)
class OfficialEvidence:
    id: int
    political_actor_id: int
    source: str
    source_id: str
    evidence_type: str
    title: str
    summary: str
    evidence_date: datetime | None
    source_url: str | None
    fetched_at: datetime
    expires_at: datetime


@dataclass(frozen=True)
class FollowedActor:
    anonymous_id: str
    political_actor_id: int
    updated_at: datetime


@dataclass(frozen=True)
class TrendingActor:
    actor: PoliticalActor
    rank: int
    follow_count: int


@dataclass(frozen=True)
class SectionSummary:
    summary: str
    citations: list[dict[str, str]]


@dataclass(frozen=True)
class SentinelaSummary:
    id: int
    political_actor_id: int
    period: str
    generated_at: datetime
    expires_at: datetime
    votes: SectionSummary
    propositions: SectionSummary
    expenses: SectionSummary
    synthesis: str
