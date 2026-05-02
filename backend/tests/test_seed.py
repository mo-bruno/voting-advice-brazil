import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.infrastructure.database.models import (
    Base,
    CandidateModel,
    CandidatePositionModel,
    PartyModel,
    ThemeModel,
    ThesisModel,
)
from app.infrastructure.database.seed import seed


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
    assert db.query(ThemeModel).count() == 12
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
