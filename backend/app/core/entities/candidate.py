from dataclasses import dataclass, field


@dataclass
class Theme:
    id: str
    name: str
    description: str | None
    icon_slug: str | None
    total_approved_theses: int = 0


@dataclass
class Thesis:
    id: int
    text: str
    theme_id: str
    theme_name: str
    status: str
    coverage: float = 0.0


@dataclass
class CandidatePosition:
    thesis_id: int
    thesis_text: str
    theme_id: str
    theme_name: str
    position: str
    justification: str | None
    quote: str | None


@dataclass
class Candidate:
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
    positions: list[CandidatePosition] = field(default_factory=list)
