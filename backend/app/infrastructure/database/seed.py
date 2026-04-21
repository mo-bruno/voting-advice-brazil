"""Populates the database from data/theses/2022/theses.json and data/propostas/2022/candidates.json."""
import json
from pathlib import Path

from sqlalchemy.orm import Session

from app.infrastructure.database.models import (
    CandidateModel,
    CandidatePositionModel,
    ThemeModel,
    ThesisModel,
)

_THEME_META: dict[str, dict[str, str]] = {
    "economia": {"name": "Economia", "icon_slug": "chart-bar"},
    "trabalho": {"name": "Trabalho", "icon_slug": "briefcase"},
    "seguranca": {"name": "Segurança", "icon_slug": "shield"},
    "direitos_sociais": {"name": "Direitos Sociais", "icon_slug": "users"},
    "meio_ambiente": {"name": "Meio Ambiente", "icon_slug": "leaf"},
    "saude": {"name": "Saúde", "icon_slug": "heart"},
    "educacao": {"name": "Educação", "icon_slug": "book"},
    "politica": {"name": "Política", "icon_slug": "landmark"},
    "previdencia": {"name": "Previdência", "icon_slug": "clock"},
    "tecnologia": {"name": "Tecnologia", "icon_slug": "cpu"},
    "habitacao": {"name": "Habitação", "icon_slug": "home"},
    "agricultura": {"name": "Agricultura", "icon_slug": "wheat"},
}


def _data_dir() -> Path:
    here = Path(__file__).parent
    return (here / "../../../../data").resolve()


def seed(db: Session) -> None:
    if db.query(CandidateModel).count() > 0:
        return

    data_dir = _data_dir()
    _seed_candidates(db, data_dir)
    _seed_theses(db, data_dir)
    db.commit()


def _seed_candidates(db: Session, data_dir: Path) -> None:
    candidates_file = data_dir / "propostas/2022/candidates.json"
    with candidates_file.open(encoding="utf-8") as f:
        raw = json.load(f)

    candidates = raw if isinstance(raw, list) else raw.get("candidates", [])
    for c in candidates:
        db.merge(
            CandidateModel(
                id=c["id"],
                name=c["name"],
                party=c["party"],
                coalition=c.get("coalition"),
                number=c.get("number"),
                running_mate=c.get("running_mate"),
                spectrum=c.get("spectrum"),
                party_logo=c.get("party_logo"),
                foto_url=c.get("foto_url"),
                cargo="presidente",
                estado=None,
            )
        )


def _seed_theses(db: Session, data_dir: Path) -> None:
    theses_file = data_dir / "theses/2022/theses.json"
    with theses_file.open(encoding="utf-8") as f:
        raw = json.load(f)

    theses = raw.get("theses", raw) if isinstance(raw, dict) else raw

    topics: set[str] = {t["topic"] for t in theses}
    for topic in topics:
        meta = _THEME_META.get(topic, {"name": topic.replace("_", " ").title(), "icon_slug": None})
        db.merge(
            ThemeModel(
                id=topic,
                name=meta["name"],
                description=None,
                icon_slug=meta.get("icon_slug"),
            )
        )

    for thesis in theses:
        db.merge(
            ThesisModel(
                id=thesis["id"],
                text=thesis["text"],
                theme_id=thesis["topic"],
                status="approved",
            )
        )
        for candidate_id, pos_data in thesis.get("positions", {}).items():
            db.merge(
                CandidatePositionModel(
                    candidate_id=candidate_id,
                    thesis_id=thesis["id"],
                    position=pos_data["position"],
                    justification=pos_data.get("justification"),
                    quote=pos_data.get("quote"),
                )
            )
