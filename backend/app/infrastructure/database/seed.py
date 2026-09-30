"""Popula o banco com os dados estáticos da edição eleitoral ativa."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, TypedDict

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.infrastructure.database.models import (
    CandidateModel,
    CandidatePositionModel,
    PartyModel,
    ThemeModel,
    ThesisModel,
)


class _ThemeMeta(TypedDict):
    name: str
    area: str
    icon_slug: str
    sort_order: int


_THEME_META: dict[str, _ThemeMeta] = {
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
    "economia_desenvolvimento": {
        "name": "Economia e Desenvolvimento",
        "area": "economica",
        "icon_slug": "chart-bar",
        "sort_order": 101,
    },
    "estado_gestao": {
        "name": "Estado e Gestão Pública",
        "area": "institucional",
        "icon_slug": "landmark",
        "sort_order": 102,
    },
    "infraestrutura_territorio": {
        "name": "Infraestrutura e Território",
        "area": "ambiental_infra",
        "icon_slug": "road",
        "sort_order": 103,
    },
    "meio_ambiente_clima": {
        "name": "Meio Ambiente e Clima",
        "area": "ambiental_infra",
        "icon_slug": "leaf",
        "sort_order": 104,
    },
    "ciencia_tecnologia_inovacao": {
        "name": "Ciência, Tecnologia e Inovação",
        "area": "economica",
        "icon_slug": "cpu",
        "sort_order": 105,
    },
    "bem_estar_social": {
        "name": "Bem-Estar Social",
        "area": "social",
        "icon_slug": "heart",
        "sort_order": 106,
    },
    "educacao_cultura_sociedade": {
        "name": "Educação, Cultura e Sociedade",
        "area": "social",
        "icon_slug": "book",
        "sort_order": 107,
    },
    "cidadania_direitos": {
        "name": "Cidadania e Direitos",
        "area": "social",
        "icon_slug": "users",
        "sort_order": 108,
    },
    "seguranca_publica": {
        "name": "Segurança Pública",
        "area": "institucional",
        "icon_slug": "shield",
        "sort_order": 109,
    },
    "soberania_relacoes_internacionais": {
        "name": "Soberania e Relações Internacionais",
        "area": "institucional",
        "icon_slug": "globe",
        "sort_order": 110,
    },
}


def _data_dir() -> Path:
    configured = Path(settings.data_dir)
    backend_dir = Path(__file__).resolve().parents[3]
    base = configured if configured.is_absolute() else (backend_dir / configured)
    resolved = base.resolve()
    if not resolved.is_dir():
        raise FileNotFoundError(
            f"Diretorio de dados nao encontrado: {resolved} "
            f"(settings.data_dir={settings.data_dir}). "
            f"Configure DATA_DIR no .env ou ajuste o layout do repo."
        )
    return resolved


def seed(db: Session) -> None:
    data_dir = _data_dir()
    try:
        candidates, theses = _load_snapshot(data_dir)
        # One transaction owns reconciliation, including shared party numbers.
        if db.get_bind().dialect.name == "postgresql":
            db.execute(select(func.pg_advisory_xact_lock(20260920)))
        existing_theses = _resolve_theses(db, theses)
        _seed_themes(db)
        party_map = _seed_parties(db, candidates)
        candidate_map = _seed_candidates(db, candidates, party_map)
        _seed_theses_and_positions(db, theses, candidate_map, existing_theses)
        db.commit()
    except Exception:
        db.rollback()
        raise


def _load_snapshot(data_dir: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    candidates = _load_candidates_json(data_dir)
    theses_file = data_dir / "theses" / str(settings.active_election_year) / "theses.json"
    with theses_file.open(encoding="utf-8") as source:
        payload = json.load(source)
    theses = payload.get("theses") if isinstance(payload, dict) else payload
    metadata = payload.get("metadata", {}) if isinstance(payload, dict) else {}
    if int(metadata.get("election", settings.active_election_year)) != settings.active_election_year:
        raise ValueError("Ano das teses difere da edição ativa")
    if metadata.get("office", settings.active_election_office) != settings.active_election_office:
        raise ValueError("Cargo das teses difere da edição ativa")
    if not isinstance(candidates, list) or not candidates or not isinstance(theses, list) or not theses:
        raise ValueError("Snapshot deve conter candidatos e teses")
    candidate_ids: set[str] = set()
    party_numbers: dict[int, str] = {}
    for candidate in candidates:
        candidate["id"] = str(candidate["id"])
        if not candidate["id"] or candidate["id"] in candidate_ids:
            raise ValueError("Identificador de candidato ausente ou duplicado")
        candidate_ids.add(candidate["id"])
        if not candidate["name"].strip() or not candidate["party"].strip():
            raise ValueError("Nome e partido são obrigatórios")
        if (int(candidate.get("election_year", settings.active_election_year)) != settings.active_election_year
                or candidate.get("office", settings.active_election_office) != settings.active_election_office
                or int(candidate.get("election_round", 1)) != 1):
            raise ValueError("Candidato fora da edição ativa e do primeiro turno")
        number = candidate.get("party_number", candidate.get("number"))
        if number is not None:
            if number in party_numbers and party_numbers[number] != candidate["party"]:
                raise ValueError("Número partidário duplicado")
            party_numbers[number] = candidate["party"]
    editorial_ids: set[str] = set()
    for thesis in theses:
        thesis["id"] = str(thesis["id"])
        thesis["version"] = int(thesis.get("version", 1))
        if not thesis["id"] or thesis["id"] in editorial_ids or thesis["version"] < 1:
            raise ValueError("Identidade ou versão editorial inválida")
        editorial_ids.add(thesis["id"])
        if not thesis["text"].strip() or thesis["topic"] not in _THEME_META:
            raise ValueError("Texto ou tema da tese inválido")
        if thesis.get("status", "approved") not in {"approved", "draft"}:
            raise ValueError("Status editorial inválido")
        positions = thesis.get("positions", {})
        if not isinstance(positions, dict) or set(positions) - candidate_ids:
            raise ValueError("Posições referenciam candidatos fora do snapshot")
        if any(p.get("position") not in {"concordo", "discordo", "neutro", "sem_posicao"} for p in positions.values()):
            raise ValueError("Posição inválida")
    return candidates, theses


def _resolve_theses(db: Session, theses: list[dict[str, Any]]) -> dict[str, ThesisModel]:
    """Validate identities before writes; never adopt a legacy row by its order."""
    rows = db.query(ThesisModel).filter_by(election_year=settings.active_election_year).all()
    resolved: dict[str, ThesisModel] = {}
    used_ids: set[int] = set()
    for item in theses:
        versions = [row for row in rows if row.editorial_id == item["id"]]
        if any((row.editorial_version or 0) > item["version"] for row in versions):
            raise ValueError(f"Não é permitido retroceder a versão de {item['id']}")
        exact = next((row for row in versions if row.editorial_version == item["version"]), None)
        if exact is not None and (exact.text != item["text"] or exact.theme.slug != item["topic"]):
            raise ValueError(f"Mudança no texto/tema de {item['id']} exige nova versão editorial")
        if exact is None:
            legacy = [row for row in rows if row.editorial_id is None and row.text == item["text"] and row.theme.slug == item["topic"]]
            if len(legacy) > 1:
                raise ValueError(f"Adoção ambígua da tese legada {item['id']}; requer migração explícita")
            exact = legacy[0] if legacy else None
        if exact is not None:
            if exact.id in used_ids:
                raise ValueError("Duas identidades editoriais correspondem à mesma tese legada")
            used_ids.add(exact.id)
            resolved[item["id"]] = exact
    return resolved


def _seed_themes(db: Session) -> None:
    for slug, meta in _THEME_META.items():
        theme = db.query(ThemeModel).filter_by(slug=slug).one_or_none()
        if theme is None:
            theme = ThemeModel(slug=slug, name=meta["name"], area=meta["area"])
            db.add(theme)
        theme.name = meta["name"]
        theme.area = meta["area"]
        theme.icon_slug = meta["icon_slug"]
        theme.sort_order = meta["sort_order"]
    db.flush()


def _load_candidates_json(data_dir: Path) -> list[dict[str, Any]]:
    candidates_file = (
        data_dir
        / "propostas"
        / str(settings.active_election_year)
        / "candidates.json"
    )
    with candidates_file.open(encoding="utf-8") as f:
        raw: Any = json.load(f)
    return raw if isinstance(raw, list) else raw.get("candidates", [])


def _seed_parties(db: Session, candidates: list[dict[str, Any]]) -> dict[str, int]:
    party_map: dict[str, int] = {}
    for c in candidates:
        acronym = c["party"]
        if acronym in party_map:
            continue
        party_number = c.get("party_number", c.get("number"))
        p = db.query(PartyModel).filter_by(acronym=acronym).one_or_none()
        if party_number is not None:
            former_number_owner = (
                db.query(PartyModel)
                .filter(
                    PartyModel.number == party_number,
                    PartyModel.acronym != acronym,
                )
                .one_or_none()
            )
            if former_number_owner is not None:
                former_number_owner.number = None
                db.flush()
        if p is None:
            p = PartyModel(acronym=acronym, name=c.get("party_name", acronym))
            db.add(p)
        p.name = c.get("party_name", acronym)
        p.number = party_number
        p.logo_url = c.get("party_logo_url", c.get("party_logo"))
        p.spectrum = c.get("spectrum")
        db.flush()
        party_map[acronym] = p.id
    return party_map


def _seed_candidates(
    db: Session, candidates: list[dict[str, Any]], party_map: dict[str, int]
) -> dict[str, int]:
    candidate_map: dict[str, int] = {}
    for c in candidates:
        office = c.get("office", settings.active_election_office)
        election_year = int(c.get("election_year", settings.active_election_year))
        election_round = int(c.get("election_round", 1))
        if (
            office != settings.active_election_office
            or election_year != settings.active_election_year
        ):
            continue
        cand = (
            db.query(CandidateModel)
            .filter_by(
                external_id=str(c["id"]),
                office=office,
                election_year=election_year,
                election_round=election_round,
            )
            .one_or_none()
        )
        if cand is None:
            cand = CandidateModel(
                external_id=str(c["id"]),
                name=c["name"],
                party_id=party_map[c["party"]],
                office=office,
                election_year=election_year,
                election_round=election_round,
            )
            db.add(cand)
        cand.name = c["name"]
        cand.legal_name = c.get("legal_name")
        cand.party_id = party_map[c["party"]]
        cand.coalition = c.get("coalition")
        cand.ballot_number = c.get("number")
        cand.running_mate = c.get("running_mate")
        cand.photo_url = c.get("photo_url", c.get("foto_url"))
        cand.official_status = c.get("official_status")
        cand.source_snapshot = c.get("source_snapshot")
        cand.state = c.get("state")
        cand.city = c.get("city")
        cand.is_active = True
        db.flush()
        candidate_map[str(c["id"])] = cand.id
    for previous in db.query(CandidateModel).filter_by(
        election_year=settings.active_election_year,
        office=settings.active_election_office,
    ):
        if previous.id not in candidate_map.values():
            previous.is_active = False
    return candidate_map


def _seed_theses_and_positions(
    db: Session, theses_data: list[dict[str, Any]], candidate_map: dict[str, int],
    existing_theses: dict[str, ThesisModel],
) -> None:
    slug_to_id = {t.slug: t.id for t in db.query(ThemeModel).all()}
    current_ids = set()
    for t in theses_data:
        thesis = existing_theses.get(t["id"])
        if thesis is None:
            thesis = ThesisModel(
                text=t["text"], theme_id=slug_to_id[t["topic"]],
                election_year=settings.active_election_year,
            )
            db.add(thesis)
        thesis.editorial_id = t["id"]
        thesis.editorial_version = t["version"]
        thesis.status = t.get("status", "approved")
        db.flush()
        current_ids.add(thesis.id)
        declared_positions = t.get("positions", {})
        positions = {p.candidate_id: p for p in db.query(CandidatePositionModel).filter_by(thesis_id=thesis.id)}
        for external_id, candidate_id in candidate_map.items():
            data = declared_positions.get(external_id, {"position": "sem_posicao"})
            position = positions.get(candidate_id)
            if position is None:
                position = CandidatePositionModel(candidate_id=candidate_id, thesis_id=thesis.id)
                db.add(position)
            position.position = data["position"]
            position.analytical_position = data.get("analytical_position")
            position.justification = data.get("justification")
            position.quote = data.get("quote")
            position.source_ref = data.get("source_ref")
            position.source_url = data.get("source_url")
    for previous in db.query(ThesisModel).filter_by(election_year=settings.active_election_year):
        if previous.id not in current_ids:
            previous.status = "archived"


def main() -> None:
    from app.infrastructure.database.session import SessionLocal

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
