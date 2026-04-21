from sqlalchemy import Float, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class ThemeModel(Base):
    __tablename__ = "themes"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon_slug: Mapped[str | None] = mapped_column(String(64), nullable=True)

    theses: Mapped[list["ThesisModel"]] = relationship(back_populates="theme")


class ThesisModel(Base):
    __tablename__ = "theses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    theme_id: Mapped[str] = mapped_column(ForeignKey("themes.id"), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="approved")

    theme: Mapped["ThemeModel"] = relationship(back_populates="theses")
    positions: Mapped[list["CandidatePositionModel"]] = relationship(back_populates="thesis")

    __table_args__ = (Index("ix_theses_theme_status", "theme_id", "status"),)


class CandidateModel(Base):
    __tablename__ = "candidates"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(256), nullable=False, index=True)
    party: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    coalition: Mapped[str | None] = mapped_column(String(256), nullable=True)
    number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    running_mate: Mapped[str | None] = mapped_column(String(256), nullable=True)
    spectrum: Mapped[str | None] = mapped_column(String(64), nullable=True)
    party_logo: Mapped[str | None] = mapped_column(String(512), nullable=True)
    foto_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    cargo: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    estado: Mapped[str | None] = mapped_column(String(2), nullable=True, index=True)

    positions: Mapped[list["CandidatePositionModel"]] = relationship(back_populates="candidate")


class CandidatePositionModel(Base):
    __tablename__ = "candidate_positions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    candidate_id: Mapped[str] = mapped_column(ForeignKey("candidates.id"), nullable=False)
    thesis_id: Mapped[int] = mapped_column(ForeignKey("theses.id"), nullable=False)
    position: Mapped[str] = mapped_column(String(32), nullable=False)
    justification: Mapped[str | None] = mapped_column(Text, nullable=True)
    quote: Mapped[str | None] = mapped_column(Text, nullable=True)

    candidate: Mapped["CandidateModel"] = relationship(back_populates="positions")
    thesis: Mapped["ThesisModel"] = relationship(back_populates="positions")

    __table_args__ = (
        Index("ix_positions_candidate_thesis", "candidate_id", "thesis_id", unique=True),
        Index("ix_positions_thesis", "thesis_id"),
    )
