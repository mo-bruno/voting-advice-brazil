from dataclasses import dataclass


@dataclass(frozen=True)
class ExplanationSource:
    title: str
    url: str


@dataclass(frozen=True)
class ThesisExplanation:
    paragraphs: tuple[str, ...]
    sources: tuple[ExplanationSource, ...]
