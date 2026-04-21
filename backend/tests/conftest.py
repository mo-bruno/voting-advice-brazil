import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.infrastructure.database.models import (
    Base,
    CandidateModel,
    CandidatePositionModel,
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
    db.add(ThemeModel(id="economia", name="Economia", description=None, icon_slug="chart-bar"))
    db.add(ThemeModel(id="seguranca", name="Segurança", description=None, icon_slug="shield"))
    db.add(ThemeModel(id="saude", name="Saúde", description=None, icon_slug="heart"))
    db.flush()

    for i in range(1, 6):
        db.add(ThesisModel(id=i, text=f"Tese {i}", theme_id="economia", status="approved"))
    db.add(ThesisModel(id=6, text="Tese 6", theme_id="seguranca", status="approved"))
    db.add(ThesisModel(id=7, text="Tese 7 rascunho", theme_id="saude", status="draft"))
    db.flush()

    for cid, name, party in [
        ("cand_a", "Candidato A", "PT"),
        ("cand_b", "Candidato B", "PL"),
        ("cand_c", "Candidato C", "MDB"),
    ]:
        db.add(
            CandidateModel(
                id=cid,
                name=name,
                party=party,
                coalition=None,
                number=None,
                running_mate=None,
                spectrum="centro",
                party_logo=None,
                foto_url=None,
                cargo="presidente",
                estado=None,
            )
        )
    db.flush()

    positions = [
        ("cand_a", 1, "concordo"), ("cand_a", 2, "concordo"), ("cand_a", 3, "neutro"),
        ("cand_a", 4, "discordo"), ("cand_a", 5, "concordo"), ("cand_a", 6, "concordo"),
        ("cand_b", 1, "discordo"), ("cand_b", 2, "discordo"), ("cand_b", 3, "concordo"),
        ("cand_b", 4, "concordo"), ("cand_b", 5, "neutro"), ("cand_b", 6, "sem_posicao"),
        ("cand_c", 1, "neutro"), ("cand_c", 2, "neutro"), ("cand_c", 3, "neutro"),
        ("cand_c", 4, "neutro"), ("cand_c", 5, "sem_posicao"), ("cand_c", 6, "discordo"),
    ]
    for cid, tid, pos in positions:
        db.add(
            CandidatePositionModel(
                candidate_id=cid,
                thesis_id=tid,
                position=pos,
                justification=f"Justificativa {cid} tese {tid}",
                quote=None,
            )
        )
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
