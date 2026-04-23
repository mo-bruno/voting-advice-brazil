"""Popula o banco com dados de desenvolvimento (candidatos 2022 + teses)."""
from __future__ import annotations

import json
from pathlib import Path

from sqlalchemy.orm import Session

from app.infrastructure.database.models import (
    CandidateModel,
    CandidatePositionModel,
    PartyModel,
    ThemeModel,
    ThesisModel,
)
from app.infrastructure.database.session import SessionLocal

_THEME_META: dict[str, dict[str, object]] = {
    "economia":         {"name": "Economia",          "area": "economica",       "icon_slug": "chart-bar", "sort_order": 1},
    "trabalho":         {"name": "Trabalho",          "area": "economica",       "icon_slug": "briefcase", "sort_order": 2},
    "saude":            {"name": "Saúde",             "area": "social",          "icon_slug": "heart",     "sort_order": 3},
    "educacao":         {"name": "Educação",          "area": "social",          "icon_slug": "book",      "sort_order": 4},
    "direitos_sociais": {"name": "Direitos Sociais",  "area": "social",          "icon_slug": "users",     "sort_order": 5},
    "politica_social":  {"name": "Política Social",   "area": "social",          "icon_slug": "hands",     "sort_order": 6},
    "meio_ambiente":    {"name": "Meio Ambiente",     "area": "ambiental_infra", "icon_slug": "leaf",      "sort_order": 7},
    "agricultura":      {"name": "Agricultura",       "area": "ambiental_infra", "icon_slug": "wheat",     "sort_order": 8},
    "infraestrutura":   {"name": "Infraestrutura",    "area": "ambiental_infra", "icon_slug": "road",      "sort_order": 9},
    "governanca":       {"name": "Governança",        "area": "institucional",   "icon_slug": "landmark",  "sort_order": 10},
    "politica_externa": {"name": "Política Externa",  "area": "institucional",   "icon_slug": "globe",     "sort_order": 11},
    "seguranca":        {"name": "Segurança",         "area": "institucional",   "icon_slug": "shield",    "sort_order": 12},
}


def _data_dir() -> Path:
    here = Path(__file__).parent
    return (here / "../../../../data").resolve()


def seed(db: Session) -> None:
    if db.query(PartyModel).count() > 0:
        return

    data_dir = _data_dir()
    _seed_themes(db)
    party_map = _seed_parties(db, data_dir)
    candidate_map = _seed_candidates(db, data_dir, party_map)
    _seed_theses_and_positions(db, data_dir, candidate_map)
    db.commit()


def _seed_themes(db: Session) -> None:
    for slug, meta in _THEME_META.items():
        db.add(ThemeModel(
            slug=slug,
            name=meta["name"],
            area=meta["area"],
            icon_slug=meta["icon_slug"],
            sort_order=meta["sort_order"],
        ))
    db.flush()


def _load_candidates_json(data_dir: Path) -> list[dict]:
    candidates_file = data_dir / "propostas/2022/candidates.json"
    with candidates_file.open(encoding="utf-8") as f:
        raw = json.load(f)
    return raw if isinstance(raw, list) else raw.get("candidates", [])


def _seed_parties(db: Session, data_dir: Path) -> dict[str, int]:
    candidates = _load_candidates_json(data_dir)
    party_map: dict[str, int] = {}
    for c in candidates:
        acronym = c["party"]
        if acronym in party_map:
            continue
        p = PartyModel(
            acronym=acronym,
            name=c.get("party_name", acronym),
            number=c.get("number"),
            logo_url=c.get("party_logo"),
            spectrum=c.get("spectrum"),
        )
        db.add(p)
        db.flush()
        party_map[acronym] = p.id
    return party_map


def _seed_candidates(
    db: Session, data_dir: Path, party_map: dict[str, int]
) -> dict[str, int]:
    candidates = _load_candidates_json(data_dir)
    candidate_map: dict[str, int] = {}
    for c in candidates:
        cand = CandidateModel(
            external_id=c["id"],
            name=c["name"],
            party_id=party_map[c["party"]],
            coalition=c.get("coalition"),
            ballot_number=c.get("number"),
            running_mate=c.get("running_mate"),
            photo_url=c.get("foto_url"),
            office="presidente",
            election_year=2022,
            election_round=1,
        )
        db.add(cand)
        db.flush()
        candidate_map[c["id"]] = cand.id
    return candidate_map


def _seed_theses_and_positions(
    db: Session, data_dir: Path, candidate_map: dict[str, int]
) -> None:
    theses_file = data_dir / "theses/2022/theses.json"
    with theses_file.open(encoding="utf-8") as f:
        raw = json.load(f)
    theses_data = raw.get("theses", raw) if isinstance(raw, dict) else raw

    slug_to_id = {t.slug: t.id for t in db.query(ThemeModel).all()}
    all_candidate_db_ids = list(candidate_map.values())

    for t in theses_data:
        thesis = ThesisModel(
            text=t["text"],
            theme_id=slug_to_id[t["topic"]],
            status="approved",
            election_year=2022,
        )
        db.add(thesis)
        db.flush()

        declared_positions = t.get("positions", {})
        seen_candidates: set[int] = set()
        for external_id, pos_data in declared_positions.items():
            if external_id not in candidate_map:
                continue
            cand_db_id = candidate_map[external_id]
            seen_candidates.add(cand_db_id)
            db.add(CandidatePositionModel(
                candidate_id=cand_db_id,
                thesis_id=thesis.id,
                position=pos_data["position"],
                justification=pos_data.get("justification"),
                quote=pos_data.get("quote"),
            ))
        for cand_db_id in all_candidate_db_ids:
            if cand_db_id not in seen_candidates:
                db.add(CandidatePositionModel(
                    candidate_id=cand_db_id,
                    thesis_id=thesis.id,
                    position="sem_posicao",
                ))


def main() -> None:
    with SessionLocal() as db:
        seed(db)
        print(
            f"Seed concluido. Parties: {db.query(PartyModel).count()}, "
            f"Candidates: {db.query(CandidateModel).count()}, "
            f"Themes: {db.query(ThemeModel).count()}, "
            f"Theses: {db.query(ThesisModel).count()}."
        )


if __name__ == "__main__":
    main()
