from pydantic import BaseModel


class CandidateOut(BaseModel):
    id: str
    name: str
    party: str
    coalition: str | None
    number: int | None
    running_mate: str | None
    spectrum: str | None
    party_logo: str | None
    foto_url: str | None
    cargo: str | None
    estado: str | None

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
    theme_id: str
    theme_name: str
    position: str

    model_config = {"from_attributes": True}


class PositionsResponse(BaseModel):
    candidate_id: str
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
    candidate_id: str
    justifications: list[JustificationOut]
    summary: JustificationSummaryOut
    grouped: dict[str, list[JustificationOut]] | None = None
