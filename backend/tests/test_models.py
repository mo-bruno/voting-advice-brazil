from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.infrastructure.database.models import (
    Base,
    CandidateModel,
    CandidatePositionModel,
    DeviceModel,
    GovernmentPlanModel,
    PartyModel,
    QuizResponseModel,
    ThemeModel,
    ThesisModel,
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
        # enable FK enforcement in sqlite
        s.execute(__import__("sqlalchemy").text("PRAGMA foreign_keys=ON"))
        yield s


def test_create_party(db: Session):
    p = PartyModel(acronym="PT", name="Partido dos Trabalhadores", number=13)
    db.add(p)
    db.commit()
    assert p.id is not None


def test_party_acronym_unique(db: Session):
    db.add(PartyModel(acronym="PT", name="X"))
    db.add(PartyModel(acronym="PT", name="Y"))
    with pytest.raises(IntegrityError):
        db.commit()


def test_candidate_requires_party_fk(db: Session):
    c = CandidateModel(
        external_id="13",
        name="Lula",
        office="presidente",
        election_year=2022,
        party_id=9999,
    )
    db.add(c)
    with pytest.raises(IntegrityError):
        db.commit()


def test_candidate_unique_external_id_office_year_round(db: Session):
    party = PartyModel(acronym="PT", name="X")
    db.add(party)
    db.flush()
    db.add(CandidateModel(
        external_id="13", name="Lula", office="presidente",
        election_year=2022, election_round=1, party_id=party.id,
    ))
    db.add(CandidateModel(
        external_id="13", name="Lula", office="presidente",
        election_year=2022, election_round=1, party_id=party.id,
    ))
    with pytest.raises(IntegrityError):
        db.commit()


def test_position_unique_candidate_thesis(db: Session):
    party = PartyModel(acronym="PT", name="X")
    db.add(party)
    db.flush()
    cand = CandidateModel(
        external_id="13", name="L", office="presidente",
        election_year=2022, party_id=party.id,
    )
    theme = ThemeModel(slug="economia", name="Economia", area="economica")
    db.add_all([cand, theme])
    db.flush()
    thesis = ThesisModel(text="X", theme_id=theme.id, election_year=2022)
    db.add(thesis)
    db.flush()

    db.add(CandidatePositionModel(candidate_id=cand.id, thesis_id=thesis.id, position="concordo"))
    db.add(CandidatePositionModel(candidate_id=cand.id, thesis_id=thesis.id, position="discordo"))
    with pytest.raises(IntegrityError):
        db.commit()


def test_quiz_response_unique_device_thesis_year(db: Session):
    theme = ThemeModel(slug="economia", name="Economia", area="economica")
    device = DeviceModel(id="550e8400-e29b-41d4-a716-446655440000")
    db.add_all([theme, device])
    db.flush()
    thesis = ThesisModel(text="X", theme_id=theme.id, election_year=2022)
    db.add(thesis)
    db.flush()
    db.add(QuizResponseModel(device_id=device.id, thesis_id=thesis.id, answer="concordo", election_year=2022))
    db.add(QuizResponseModel(device_id=device.id, thesis_id=thesis.id, answer="discordo", election_year=2022))
    with pytest.raises(IntegrityError):
        db.commit()


def test_government_plan_one_per_candidate(db: Session):
    party = PartyModel(acronym="PT", name="X")
    db.add(party)
    db.flush()
    cand = CandidateModel(
        external_id="13", name="L", office="presidente",
        election_year=2022, party_id=party.id,
    )
    db.add(cand)
    db.flush()
    db.add(GovernmentPlanModel(
        candidate_id=cand.id, raw_text="A", extracted_at=datetime.now(timezone.utc),
    ))
    db.add(GovernmentPlanModel(
        candidate_id=cand.id, raw_text="B", extracted_at=datetime.now(timezone.utc),
    ))
    with pytest.raises(IntegrityError):
        db.commit()
