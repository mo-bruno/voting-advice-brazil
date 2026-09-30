import json
import shutil
from pathlib import Path

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.use_cases.submit_quiz import QuizAnswer
from app.infrastructure.database.models import (
    Base,
    CandidateModel,
    CandidatePositionModel,
    PartyModel,
    QuizResponseModel,
    ThemeModel,
    ThesisModel,
)
from app.infrastructure.database.repositories import (
    SqlCandidateRepository,
    SqlPositionRepository,
    SqlQuizResponseRepository,
    SqlThesisRepository,
)
from app.infrastructure.database.seed import seed

FIXTURE_DATA_DIR = (
    Path(__file__).parent / "fixtures" / "election_2026" / "data"
)


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session_ = sessionmaker(bind=engine)
    with Session_() as s:
        yield s


def test_seed_minimum_counts(db):
    seed(db)
    assert db.query(ThemeModel).count() == 22
    assert db.query(PartyModel).count() >= 5
    assert db.query(CandidateModel).count() >= 10
    assert db.query(ThesisModel).count() > 0


def test_seed_is_idempotent(db):
    seed(db)
    c1 = db.query(CandidateModel).count()
    seed(db)
    c2 = db.query(CandidateModel).count()
    assert c1 == c2


def test_every_candidate_has_position_for_every_thesis(db):
    seed(db)
    n_cands = db.query(CandidateModel).count()
    n_theses = db.query(ThesisModel).count()
    n_positions = db.query(CandidatePositionModel).count()
    assert n_positions == n_cands * n_theses


def test_themes_have_valid_areas(db):
    seed(db)
    valid_areas = {"economica", "social", "ambiental_infra", "institucional"}
    themes = db.query(ThemeModel).all()
    assert themes
    for theme in themes:
        assert theme.area in valid_areas, f"Theme {theme.slug} has invalid area {theme.area}"


def _configure_2026_fixture(monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "data_dir", str(FIXTURE_DATA_DIR))
    monkeypatch.setattr(settings, "active_election_year", 2026)
    monkeypatch.setattr(settings, "active_election_office", "presidente")


def _insert_legacy_2022_rows(db):
    party = PartyModel(acronym="PT", name="Partido legado", number=13)
    former_number_owner = PartyModel(
        acronym="PTB",
        name="Partido Trabalhista Brasileiro",
        number=14,
    )
    theme = ThemeModel(
        slug="economia",
        name="Economia",
        area="economica",
        icon_slug="chart-bar",
    )
    db.add_all([party, former_number_owner, theme])
    db.flush()
    candidate = CandidateModel(
        external_id="legacy-2022",
        name="Candidato legado",
        party_id=party.id,
        office="presidente",
        election_year=2022,
        election_round=1,
    )
    thesis = ThesisModel(
        text="Tese legada",
        theme_id=theme.id,
        status="approved",
        election_year=2022,
    )
    db.add_all([candidate, thesis])
    db.flush()
    db.add(CandidatePositionModel(
        candidate_id=candidate.id,
        thesis_id=thesis.id,
        position="concordo",
    ))
    db.commit()


def _active_counts(db):
    return (
        db.query(CandidateModel).filter_by(election_year=2026).count(),
        db.query(ThesisModel).filter_by(election_year=2026).count(),
        db.query(CandidatePositionModel)
        .join(ThesisModel)
        .filter(ThesisModel.election_year == 2026)
        .count(),
    )


def test_seed_2026_can_run_after_2022_data(db, monkeypatch):
    _insert_legacy_2022_rows(db)
    _configure_2026_fixture(monkeypatch)

    seed(db)

    assert {row.election_year for row in db.query(CandidateModel)} == {2022, 2026}
    assert {row.election_year for row in db.query(ThesisModel)} == {2022, 2026}
    assert _active_counts(db) == (3, 1, 3)
    assert db.query(PartyModel).filter_by(acronym="MISSÃO").one().number == 14
    assert db.query(PartyModel).filter_by(acronym="PTB").one().number is None


def test_seed_2026_is_idempotent(db, monkeypatch):
    _configure_2026_fixture(monkeypatch)
    seed(db)
    first_counts = _active_counts(db)

    seed(db)

    assert _active_counts(db) == first_counts == (3, 1, 3)


def test_seed_2026_preserves_candidate_photo_and_position_evidence(db, monkeypatch):
    _configure_2026_fixture(monkeypatch)

    seed(db)

    candidate = db.query(CandidateModel).filter_by(external_id="2026-a").one()
    assert candidate.legal_name == "Candidata A da Silva"
    assert candidate.photo_url == "/data/fotos/2026/BR/2026-a.jpg"
    position = (
        db.query(CandidatePositionModel)
        .filter_by(candidate_id=candidate.id)
        .one()
    )
    assert position.quote == "regulamentar o imposto sobre grandes fortunas"
    assert position.source_ref == "plano-a.pdf#page=10"


@pytest.fixture
def snapshot(tmp_path, monkeypatch):
    from app.config import settings

    _configure_2026_fixture(monkeypatch)
    shutil.copytree(FIXTURE_DATA_DIR, tmp_path / "data")
    monkeypatch.setattr(settings, "data_dir", str(tmp_path / "data"))
    candidates_path = tmp_path / "data/propostas/2026/candidates.json"
    theses_path = tmp_path / "data/theses/2026/theses.json"
    return candidates_path, theses_path


def _change_json(path, change):
    payload = json.loads(path.read_text())
    change(payload)
    path.write_text(json.dumps(payload), encoding="utf-8")


def test_refresh_replaces_candidate_and_keeps_historical_positions(db, snapshot):
    candidates_path, theses_path = snapshot
    seed(db)
    old = db.query(CandidateModel).filter_by(external_id="2026-b").one()
    old_id = old.id

    def replace_candidate(rows):
        rows[1]["id"] = "2026-new"
        rows[1]["name"] = "Substituto"

    def replace_positions(payload):
        positions = payload["theses"][0]["positions"]
        positions["2026-new"] = positions.pop("2026-b")

    _change_json(candidates_path, replace_candidate)
    _change_json(theses_path, replace_positions)
    seed(db)

    candidates, count = SqlCandidateRepository(db).list()
    assert count == 3
    assert {c.external_id for c in candidates} == {"2026-a", "2026-new", "2026-c"}
    assert SqlCandidateRepository(db).get_by_id(old_id) is None
    assert SqlPositionRepository(db).get_by_candidate(old_id) == []
    assert db.get(CandidateModel, old_id) is not None
    assert db.query(CandidatePositionModel).filter_by(candidate_id=old_id).count() == 1
    new = db.query(CandidateModel).filter_by(external_id="2026-new").one()
    assert SqlPositionRepository(db).get_by_candidate(new.id)[0].position == "discordo"
    assert SqlThesisRepository(db).list_approved()[0].coverage == 66.7


def test_refresh_updates_status_and_evidence_without_changing_response_ids(db, snapshot):
    _, theses_path = snapshot
    seed(db)
    thesis = db.query(ThesisModel).one()
    thesis_id = thesis.id
    SqlQuizResponseRepository(db).upsert_answers("device-history", [QuizAnswer(thesis_id, "agree", 1)])

    def update(payload):
        item = payload["theses"][0]
        item["status"] = "draft"
        item["positions"]["2026-a"] = {
            "position": "sem_posicao", "quote": None, "source_ref": None,
            "source_url": None, "justification": "Evidência reavaliada",
        }

    _change_json(theses_path, update)
    seed(db)
    assert SqlThesisRepository(db).list_approved() == []
    assert db.query(ThesisModel).one().id == thesis_id
    response = db.query(QuizResponseModel).one()
    assert (response.thesis_id, response.answer) == (thesis_id, "agree")
    candidate = db.query(CandidateModel).filter_by(external_id="2026-a").one()
    position = db.query(CandidatePositionModel).filter_by(candidate_id=candidate.id).one()
    assert (position.position, position.quote, position.source_ref) == ("sem_posicao", None, None)


def test_new_editorial_version_keeps_old_answers_on_old_text(db, snapshot):
    _, theses_path = snapshot
    seed(db)
    old = db.query(ThesisModel).one()
    old_id, old_text = old.id, old.text
    SqlQuizResponseRepository(db).upsert_answers("device-history", [QuizAnswer(old_id, "agree", 1)])

    def update(payload):
        payload["theses"][0].update(version=2, text="O imposto deve ter uma alíquota de 2%.")

    _change_json(theses_path, update)
    seed(db)
    assert db.query(ThesisModel).count() == 2
    approved = SqlThesisRepository(db).list_approved()
    assert len(approved) == 1 and approved[0].id != old_id
    assert db.get(ThesisModel, old_id).text == old_text
    assert db.query(QuizResponseModel).one().thesis_id == old_id
    seed(db)
    assert db.query(ThesisModel).count() == 2


def test_text_change_without_version_is_rejected_before_roster_mutation(db, snapshot):
    candidates_path, theses_path = snapshot
    seed(db)
    _change_json(candidates_path, lambda rows: rows[0].update(name="Alteração não aplicada"))
    _change_json(theses_path, lambda payload: payload["theses"][0].update(text="Outra decisão."))
    with pytest.raises(ValueError, match="versão"):
        seed(db)
    assert db.query(CandidateModel).filter_by(external_id="2026-a").one().name == "CANDIDATA A"


def test_invalid_snapshot_is_rejected_without_mutating_existing_data(db, snapshot):
    candidates_path, theses_path = snapshot
    seed(db)
    _change_json(candidates_path, lambda rows: rows[0].update(name="Alteração não aplicada"))
    _change_json(theses_path, lambda payload: payload["theses"][0].update(status="invalid"))
    with pytest.raises(ValueError):
        seed(db)
    assert db.query(CandidateModel).filter_by(external_id="2026-a").one().name == "CANDIDATA A"


def test_refresh_persists_source_url(db, snapshot):
    _, theses_path = snapshot
    seed(db)
    _change_json(theses_path, lambda payload: payload["theses"][0]["positions"]["2026-a"].update(source_url="https://example.test/plan.pdf"))
    seed(db)
    candidate = db.query(CandidateModel).filter_by(external_id="2026-a").one()
    position = SqlPositionRepository(db).get_by_candidate(candidate.id)[0]
    assert getattr(position, "source_url", None) == "https://example.test/plan.pdf"


def test_refresh_persists_analytical_position_separately_from_scoring(db, snapshot):
    _, theses_path = snapshot
    _change_json(
        theses_path,
        lambda payload: payload["theses"][0]["positions"]["2026-a"].update(
            position="sem_posicao",
            analytical_position="CONDICIONAL_OU_MISTA",
        ),
    )

    seed(db)

    candidate = db.query(CandidateModel).filter_by(external_id="2026-a").one()
    position = SqlPositionRepository(db).get_by_candidate(candidate.id)[0]
    assert position.position == "sem_posicao"
    assert position.analytical_position == "CONDICIONAL_OU_MISTA"


def test_seed_adopts_unique_legacy_text_without_moving_answers(db, snapshot):
    seed(db)
    thesis = db.query(ThesisModel).one()
    thesis_id = thesis.id
    SqlQuizResponseRepository(db).upsert_answers("legacy-device", [QuizAnswer(thesis_id, "disagree", 1)])
    thesis.editorial_id = None
    thesis.editorial_version = None
    db.commit()

    seed(db)

    assert db.query(ThesisModel).count() == 1
    assert db.query(ThesisModel).one().editorial_id == "T2026-001"
    assert db.query(QuizResponseModel).one().thesis_id == thesis_id


def test_seed_rejects_ambiguous_legacy_identity(db, snapshot):
    seed(db)
    thesis = db.query(ThesisModel).one()
    thesis.editorial_id = None
    thesis.editorial_version = None
    db.add(ThesisModel(text=thesis.text, theme_id=thesis.theme_id, status="approved", election_year=2026))
    db.commit()

    with pytest.raises(ValueError, match="ambígua"):
        seed(db)

    assert all(row.editorial_id is None for row in db.query(ThesisModel))


def test_removed_thesis_is_archived_and_new_thesis_is_added(db, snapshot):
    _, theses_path = snapshot
    seed(db)
    thesis_id = db.query(ThesisModel).one().id
    SqlQuizResponseRepository(db).upsert_answers("legacy-device", [QuizAnswer(thesis_id, "agree", 1)])
    _change_json(theses_path, lambda payload: payload["theses"][0].update(id="T2026-002", text="Uma nova decisão."))

    seed(db)

    assert db.get(ThesisModel, thesis_id).status == "archived"
    assert db.query(QuizResponseModel).one().thesis_id == thesis_id
    assert len(SqlThesisRepository(db).list_approved()) == 1
    assert db.query(CandidatePositionModel).count() == 6


def test_restore_candidate_keeps_identity_and_updates_official_status(db, snapshot):
    candidates_path, theses_path = snapshot
    original_candidates = json.loads(candidates_path.read_text())
    original_theses = json.loads(theses_path.read_text())
    seed(db)
    candidate_id = db.query(CandidateModel).filter_by(external_id="2026-b").one().id
    _change_json(candidates_path, lambda rows: rows.pop(1))
    _change_json(theses_path, lambda payload: payload["theses"][0]["positions"].pop("2026-b"))
    seed(db)
    original_candidates[1].update(official_status="PENDENTE DE JULGAMENTO", source_snapshot="20/09/2026 12:00:00")
    candidates_path.write_text(json.dumps(original_candidates), encoding="utf-8")
    theses_path.write_text(json.dumps(original_theses), encoding="utf-8")

    seed(db)

    restored = SqlCandidateRepository(db).get_by_id(candidate_id)
    assert restored is not None
    assert restored.official_status == "PENDENTE DE JULGAMENTO"
    assert restored.source_snapshot == "20/09/2026 12:00:00"
    assert db.query(CandidateModel).count() == 3
    assert db.query(CandidatePositionModel).count() == 3
