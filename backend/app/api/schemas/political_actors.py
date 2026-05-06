from datetime import datetime

from pydantic import BaseModel, Field


class PoliticalActorOut(BaseModel):
    id: int
    source: str
    source_id: str
    display_name: str
    party: str | None
    state: str | None
    role: str
    status: str
    photo_url: str | None
    source_url: str | None
    last_indexed_at: datetime


class PoliticalActorListResponse(BaseModel):
    actors: list[PoliticalActorOut]
    total_count: int
    page: int
    page_size: int
    has_next: bool


class TrendingActorOut(BaseModel):
    actor: PoliticalActorOut
    rank: int


class TrendingActorResponse(BaseModel):
    actors: list[TrendingActorOut]


class OfficialEvidenceOut(BaseModel):
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


class EvidenceResponse(BaseModel):
    political_actor_id: int
    cache_status: str
    evidence: list[OfficialEvidenceOut]


class FollowActorRequest(BaseModel):
    political_actor_id: int = Field(gt=0)


class FollowedActorResponse(BaseModel):
    political_actor: PoliticalActorOut
    updated_at: datetime
