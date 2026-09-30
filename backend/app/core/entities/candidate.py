from dataclasses import dataclass, field

from app.core.entities.thesis_explanation import ThesisExplanation


@dataclass
class Theme:
    id: int
    slug: str
    name: str
    area: str
    description: str | None = None
    icon_slug: str | None = None
    sort_order: int = 0
    total_approved_theses: int = 0


@dataclass
class Thesis:
    id: int
    text: str
    theme_id: int
    theme_slug: str
    theme_name: str
    status: str
    election_year: int
    coverage: float = 0.0
    explanation: ThesisExplanation | None = None


@dataclass
class CandidatePosition:
    thesis_id: int
    thesis_text: str
    theme_id: int
    theme_slug: str
    theme_name: str
    position: str
    analytical_position: str | None
    justification: str | None
    quote: str | None
    source_ref: str | None = None
    source_url: str | None = None


@dataclass
class Candidate:
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
    photo_url: str | None
    office: str
    state: str | None
    city: str | None
    election_year: int
    election_round: int
    spectrum: str | None = None
    official_status: str | None = None
    source_snapshot: str | None = None
    positions: list[CandidatePosition] = field(default_factory=list)
