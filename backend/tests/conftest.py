import os

# Isolate test execution before importing Settings/app
os.environ.setdefault("APP_ENV", "test")

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.infrastructure.database.models import (
    Base,
    CandidateModel,
    CandidatePositionModel,
    PartyModel,
    ThemeModel,
    ThesisModel,
)
from app.infrastructure.database.session import get_db
from app.main import app

engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def _populate(db: Session) -> None:
    pt = PartyModel(acronym="PT", name="Partido dos Trabalhadores", number=13, spectrum="esquerda", logo_url=None)
    pl = PartyModel(acronym="PL", name="Partido Liberal", number=22, spectrum="direita", logo_url=None)
    mdb = PartyModel(acronym="MDB", name="Movimento Democratico Brasileiro", number=15, spectrum="centro", logo_url=None)
    db.add_all([pt, pl, mdb])
    db.flush()

    economia = ThemeModel(slug="economia", name="Economia", area="economica", icon_slug="chart-bar")
    seguranca = ThemeModel(slug="seguranca", name="Seguranca", area="institucional", icon_slug="shield")
    saude = ThemeModel(slug="saude", name="Saude", area="social", icon_slug="heart")
    db.add_all([economia, seguranca, saude])
    db.flush()

    theses = []
    for i in range(1, 6):
        t = ThesisModel(text=f"Tese {i}", theme_id=economia.id, status="approved", election_year=2022)
        theses.append(t)
    t6 = ThesisModel(text="Tese 6", theme_id=seguranca.id, status="approved", election_year=2022)
    t7 = ThesisModel(text="Tese 7 rascunho", theme_id=saude.id, status="draft", election_year=2022)
    theses.extend([t6, t7])
    db.add_all(theses)
    db.flush()

    cand_a = CandidateModel(
        external_id="cand_a", name="Candidato A", party_id=pt.id,
        office="presidente", election_year=2022,
    )
    cand_b = CandidateModel(
        external_id="cand_b", name="Candidato B", party_id=pl.id,
        office="presidente", election_year=2022,
    )
    cand_c = CandidateModel(
        external_id="cand_c", name="Candidato C", party_id=mdb.id,
        office="presidente", election_year=2022,
    )
    db.add_all([cand_a, cand_b, cand_c])
    db.flush()

    positions = [
        (cand_a.id, theses[0].id, "concordo"), (cand_a.id, theses[1].id, "concordo"),
        (cand_a.id, theses[2].id, "neutro"), (cand_a.id, theses[3].id, "discordo"),
        (cand_a.id, theses[4].id, "concordo"), (cand_a.id, t6.id, "concordo"),
        (cand_b.id, theses[0].id, "discordo"), (cand_b.id, theses[1].id, "discordo"),
        (cand_b.id, theses[2].id, "concordo"), (cand_b.id, theses[3].id, "concordo"),
        (cand_b.id, theses[4].id, "neutro"), (cand_b.id, t6.id, "sem_posicao"),
        (cand_c.id, theses[0].id, "neutro"), (cand_c.id, theses[1].id, "neutro"),
        (cand_c.id, theses[2].id, "neutro"), (cand_c.id, theses[3].id, "neutro"),
        (cand_c.id, theses[4].id, "sem_posicao"), (cand_c.id, t6.id, "discordo"),
    ]
    for cid, tid, pos in positions:
        db.add(CandidatePositionModel(
            candidate_id=cid, thesis_id=tid, position=pos,
            justification=f"Justificativa cand {cid} tese {tid}",
        ))
    db.commit()


@pytest.fixture(scope="session")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSession()
    _populate(db)
    yield db
    db.close()
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(db_session):
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def candidate_ids(db_session) -> dict[str, int]:
    """Map external_id -> internal int id for candidates seeded in _populate."""
    rows = db_session.query(CandidateModel).all()
    return {c.external_id: c.id for c in rows}


@pytest.fixture
def thesis_ids(db_session) -> dict[str, int]:
    """Map thesis text -> thesis id for theses seeded in _populate."""
    rows = db_session.query(ThesisModel).all()
    return {t.text: t.id for t in rows}
