from datetime import datetime, timezone

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class PartyModel(Base):
    __tablename__ = "parties"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    acronym: Mapped[str] = mapped_column(String(32), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(256), nullable=False)
    number: Mapped[int | None] = mapped_column(Integer, nullable=True, unique=True)
    logo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    spectrum: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_utcnow)

    candidates: Mapped[list["CandidateModel"]] = relationship(back_populates="party")


class CandidateModel(Base):
    __tablename__ = "candidates"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    external_id: Mapped[str] = mapped_column(String(64), nullable=False)
    name: Mapped[str] = mapped_column(String(256), nullable=False)
    legal_name: Mapped[str | None] = mapped_column(String(256), nullable=True)
    party_id: Mapped[int] = mapped_column(ForeignKey("parties.id"), nullable=False)
    coalition: Mapped[str | None] = mapped_column(String(512), nullable=True)
    ballot_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    running_mate: Mapped[str | None] = mapped_column(String(256), nullable=True)
    photo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    office: Mapped[str] = mapped_column(String(32), nullable=False)
    state: Mapped[str | None] = mapped_column(String(2), nullable=True)
    city: Mapped[str | None] = mapped_column(String(128), nullable=True)
    election_year: Mapped[int] = mapped_column(Integer, nullable=False)
    election_round: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_utcnow)

    party: Mapped["PartyModel"] = relationship(back_populates="candidates")
    positions: Mapped[list["CandidatePositionModel"]] = relationship(back_populates="candidate")
    government_plan: Mapped["GovernmentPlanModel | None"] = relationship(back_populates="candidate", uselist=False)

    __table_args__ = (
        UniqueConstraint("external_id", "office", "election_year", "election_round",
                         name="uq_candidates_external_office_year_round"),
        Index("ix_candidates_party_id", "party_id"),
        Index("ix_candidates_office_year_state", "office", "election_year", "state"),
    )


class ThemeModel(Base):
    __tablename__ = "themes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    slug: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    area: Mapped[str] = mapped_column(String(32), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon_slug: Mapped[str | None] = mapped_column(String(64), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    theses: Mapped[list["ThesisModel"]] = relationship(back_populates="theme")

    __table_args__ = (Index("ix_themes_area", "area"),)


class ThesisModel(Base):
    __tablename__ = "theses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    theme_id: Mapped[int] = mapped_column(ForeignKey("themes.id"), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="approved")
    election_year: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_utcnow)

    theme: Mapped["ThemeModel"] = relationship(back_populates="theses")
    positions: Mapped[list["CandidatePositionModel"]] = relationship(back_populates="thesis")

    __table_args__ = (Index("ix_theses_theme_status_year", "theme_id", "status", "election_year"),)


class CandidatePositionModel(Base):
    __tablename__ = "candidate_positions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    candidate_id: Mapped[int] = mapped_column(ForeignKey("candidates.id"), nullable=False)
    thesis_id: Mapped[int] = mapped_column(ForeignKey("theses.id"), nullable=False)
    position: Mapped[str] = mapped_column(String(32), nullable=False)
    justification: Mapped[str | None] = mapped_column(Text, nullable=True)
    quote: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_ref: Mapped[str | None] = mapped_column(String(256), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_utcnow)

    candidate: Mapped["CandidateModel"] = relationship(back_populates="positions")
    thesis: Mapped["ThesisModel"] = relationship(back_populates="positions")

    __table_args__ = (
        UniqueConstraint("candidate_id", "thesis_id", name="uq_positions_candidate_thesis"),
        Index("ix_positions_thesis", "thesis_id"),
    )


class GovernmentPlanModel(Base):
    __tablename__ = "government_plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    candidate_id: Mapped[int] = mapped_column(ForeignKey("candidates.id"), nullable=False, unique=True)
    source_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    raw_text: Mapped[str] = mapped_column(Text, nullable=False)
    extracted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    extractor_version: Mapped[str | None] = mapped_column(String(64), nullable=True)

    candidate: Mapped["CandidateModel"] = relationship(back_populates="government_plan")


class DeviceModel(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_utcnow)
    app_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    platform: Mapped[str | None] = mapped_column(String(16), nullable=True)

    responses: Mapped[list["QuizResponseModel"]] = relationship(back_populates="device")

    __table_args__ = (Index("ix_devices_last_seen", "last_seen_at"),)


class QuizResponseModel(Base):
    __tablename__ = "quiz_responses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    device_id: Mapped[str] = mapped_column(ForeignKey("devices.id"), nullable=False)
    thesis_id: Mapped[int] = mapped_column(ForeignKey("theses.id"), nullable=False)
    answer: Mapped[str] = mapped_column(String(32), nullable=False)
    weight: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    election_year: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

    device: Mapped["DeviceModel"] = relationship(back_populates="responses")

    __table_args__ = (
        UniqueConstraint("device_id", "thesis_id", "election_year",
                         name="uq_responses_device_thesis_year"),
        Index("ix_responses_device_year", "device_id", "election_year"),
    )
