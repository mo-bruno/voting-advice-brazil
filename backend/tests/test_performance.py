import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.infrastructure.database.models import Base
from app.infrastructure.database.seed import seed


@pytest.fixture(scope="module")
def db() -> Session:
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session_ = sessionmaker(bind=engine)
    s = Session_()
    seed(s)
    yield s
    s.close()


def _explain(db: Session, sql: str, **params) -> str:
    rows = db.execute(text(f"EXPLAIN QUERY PLAN {sql}"), params).all()
    return "\n".join(str(r) for r in rows).upper()


def test_theses_query_uses_theme_status_year_index(db: Session) -> None:
    plan = _explain(
        db,
        "SELECT * FROM theses WHERE theme_id = :tid AND status = 'approved' AND election_year = 2022",
        tid=1,
    )
    assert "IX_THESES_THEME_STATUS_YEAR" in plan or "USING INDEX" in plan


def test_positions_by_candidate_uses_index(db: Session) -> None:
    plan = _explain(
        db,
        "SELECT * FROM candidate_positions WHERE candidate_id = :cid AND thesis_id = :tid",
        cid=1,
        tid=1,
    )
    assert "UQ_POSITIONS_CANDIDATE_THESIS" in plan or "USING INDEX" in plan


def test_candidates_by_party_uses_index(db: Session) -> None:
    plan = _explain(db, "SELECT * FROM candidates WHERE party_id = :pid", pid=1)
    assert "IX_CANDIDATES_PARTY_ID" in plan or "USING INDEX" in plan


def test_quiz_responses_lookup_uses_index(db: Session) -> None:
    plan = _explain(
        db,
        "SELECT * FROM quiz_responses WHERE device_id = :d AND election_year = 2022",
        d="abc",
    )
    assert "IX_RESPONSES_DEVICE_YEAR" in plan or "USING INDEX" in plan
