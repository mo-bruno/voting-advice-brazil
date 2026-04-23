from pydantic import BaseModel


class CandidateOut(BaseModel):
    id: int
    external_id: str
    name: str
    party_id: int
    party_acronym: str
    party_name: str
    party_logo_url: str | None
    coalition: str | None
    ballot_number: int | None
    running_mate: str | None
    spectrum: str | None
    photo_url: str | None
    office: str
    state: str | None
    city: str | None
    election_year: int
    election_round: int

    model_config = {"from_attributes": True}


class CandidateListResponse(BaseModel):
    candidates: list[CandidateOut]
    total_count: int
    page: int
    page_size: int
    has_next: bool


class PositionOut(BaseModel):
    thesis_id: int
    text: str
    theme_id: int
    theme_name: str
    position: str

    model_config = {"from_attributes": True}


class PositionsResponse(BaseModel):
    candidate_id: int
    positions: list[PositionOut]


class JustificationOut(BaseModel):
    thesis_id: int
    thesis_text: str
    theme: str
    theme_name: str
    position: str
    justification: str | None
    quote: str | None


class JustificationSummaryOut(BaseModel):
    agree_count: int
    disagree_count: int
    neutral_count: int
    no_position_count: int


class JustificationsResponse(BaseModel):
    candidate_id: int
    justifications: list[JustificationOut]
    summary: JustificationSummaryOut
    grouped: dict[str, list[JustificationOut]] | None = None
