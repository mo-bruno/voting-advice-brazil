"""Read checked-in explanations, bound to an exact editorial question version.

This optional reading aid never changes a thesis, a position or its score. The
catalogue is immutable for a deployment; publishing edited copy reloads it.
"""

import logging
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, HttpUrl, StringConstraints

from app.config import settings
from app.core.entities.thesis_explanation import ExplanationSource, ThesisExplanation

_logger = logging.getLogger(__name__)
_Text = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]


class _Source(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: _Text
    url: HttpUrl


class _Entry(BaseModel):
    model_config = ConfigDict(extra="forbid")

    thesis_id: _Text
    thesis_version: int = Field(ge=1)
    thesis_text: _Text
    paragraphs: list[_Text] = Field(min_length=2, max_length=4)
    sources: list[_Source] = Field(min_length=1, max_length=4)


class _Catalogue(BaseModel):
    model_config = ConfigDict(extra="forbid")

    election_year: int
    updated_at: date
    explanations: list[_Entry]


@lru_cache(maxsize=8)
def _load_catalogue(path: Path, election_year: int) -> dict[str, _Entry]:
    try:
        catalogue = _Catalogue.model_validate_json(path.read_text(encoding="utf-8"))
        entries = {entry.thesis_id: entry for entry in catalogue.explanations}
        if catalogue.election_year != election_year or len(entries) != len(catalogue.explanations):
            raise ValueError("Ano ou identidades do catálogo de explicações inválidos")
        return entries
    except FileNotFoundError:
        return {}
    except (OSError, ValueError):
        # Optional help must not prevent someone from answering the quiz.
        _logger.warning("Catálogo de explicações indisponível para a edição %s", election_year)
        return {}


def get_thesis_explanation(
    *, election_year: int, editorial_id: str | None,
    editorial_version: int | None, text: str,
) -> ThesisExplanation | None:
    if editorial_id is None or editorial_version is None:
        return None
    data_dir = Path(settings.data_dir)
    if not data_dir.is_absolute():
        data_dir = Path(__file__).resolve().parents[2] / data_dir
    path = (data_dir / "theses" / str(election_year) / "explanations.json").resolve()
    entry = _load_catalogue(path, election_year).get(editorial_id)
    if entry is None or entry.thesis_version != editorial_version or entry.thesis_text != text:
        return None
    return ThesisExplanation(
        paragraphs=tuple(entry.paragraphs),
        sources=tuple(ExplanationSource(title=source.title, url=str(source.url)) for source in entry.sources),
    )
