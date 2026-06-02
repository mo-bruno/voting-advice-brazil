from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    SmallInteger,
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
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

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
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    party: Mapped["PartyModel"] = relationship(back_populates="candidates")
    positions: Mapped[list["CandidatePositionModel"]] = relationship(
        back_populates="candidate"
    )
    government_plan: Mapped["GovernmentPlanModel | None"] = relationship(
        back_populates="candidate", uselist=False
    )

    __table_args__ = (
        UniqueConstraint(
            "external_id",
            "office",
            "election_year",
            "election_round",
            name="uq_candidates_external_office_year_round",
        ),
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
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    theme: Mapped["ThemeModel"] = relationship(back_populates="theses")
    positions: Mapped[list["CandidatePositionModel"]] = relationship(
        back_populates="thesis"
    )

    __table_args__ = (
        Index("ix_theses_theme_status_year", "theme_id", "status", "election_year"),
    )


class CandidatePositionModel(Base):
    __tablename__ = "candidate_positions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    candidate_id: Mapped[int] = mapped_column(
        ForeignKey("candidates.id"), nullable=False
    )
    thesis_id: Mapped[int] = mapped_column(ForeignKey("theses.id"), nullable=False)
    position: Mapped[str] = mapped_column(String(32), nullable=False)
    justification: Mapped[str | None] = mapped_column(Text, nullable=True)
    quote: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_ref: Mapped[str | None] = mapped_column(String(256), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    candidate: Mapped["CandidateModel"] = relationship(back_populates="positions")
    thesis: Mapped["ThesisModel"] = relationship(back_populates="positions")

    __table_args__ = (
        UniqueConstraint(
            "candidate_id", "thesis_id", name="uq_positions_candidate_thesis"
        ),
        Index("ix_positions_thesis", "thesis_id"),
    )


class GovernmentPlanModel(Base):
    __tablename__ = "government_plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    candidate_id: Mapped[int] = mapped_column(
        ForeignKey("candidates.id"), nullable=False, unique=True
    )
    source_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    raw_text: Mapped[str] = mapped_column(Text, nullable=False)
    extracted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    extractor_version: Mapped[str | None] = mapped_column(String(64), nullable=True)

    candidate: Mapped["CandidateModel"] = relationship(back_populates="government_plan")


class DeviceModel(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
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
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

    device: Mapped["DeviceModel"] = relationship(back_populates="responses")

    __table_args__ = (
        UniqueConstraint(
            "device_id",
            "thesis_id",
            "election_year",
            name="uq_responses_device_thesis_year",
        ),
        Index("ix_responses_device_year", "device_id", "election_year"),
    )


class PoliticalActorModel(Base):
    __tablename__ = "political_actors"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    source_id: Mapped[str] = mapped_column(String(64), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(256), nullable=False)
    display_name: Mapped[str] = mapped_column(String(256), nullable=False)
    party: Mapped[str | None] = mapped_column(String(32), nullable=True)
    state: Mapped[str | None] = mapped_column(String(2), nullable=True)
    role: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="active")
    photo_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    source_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    last_indexed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

    evidence: Mapped[list["OfficialEvidenceModel"]] = relationship(
        back_populates="actor"
    )
    followers: Mapped[list["FollowedActorModel"]] = relationship(back_populates="actor")

    __table_args__ = (
        UniqueConstraint("source", "source_id", name="uq_political_actors_source_id"),
        Index("ix_political_actors_role_state_party", "role", "state", "party"),
        Index("ix_political_actors_normalized_name", "normalized_name"),
    )


class OfficialEvidenceModel(Base):
    __tablename__ = "official_evidence"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    political_actor_id: Mapped[int] = mapped_column(
        ForeignKey("political_actors.id"), nullable=False
    )
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    source_id: Mapped[str] = mapped_column(String(128), nullable=False)
    evidence_type: Mapped[str] = mapped_column(String(32), nullable=False)
    title: Mapped[str] = mapped_column(String(512), nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    evidence_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    source_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    normalized_payload: Mapped[dict[str, object] | None] = mapped_column(
        JSON, nullable=True
    )
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    actor: Mapped["PoliticalActorModel"] = relationship(back_populates="evidence")

    __table_args__ = (
        UniqueConstraint(
            "political_actor_id",
            "source",
            "source_id",
            "evidence_type",
            name="uq_evidence_actor_source_type",
        ),
        Index(
            "ix_evidence_actor_type_date",
            "political_actor_id",
            "evidence_type",
            "evidence_date",
        ),
        Index("ix_evidence_expires_at", "expires_at"),
    )


class FollowedActorModel(Base):
    __tablename__ = "followed_actors"

    anonymous_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    political_actor_id: Mapped[int] = mapped_column(
        ForeignKey("political_actors.id"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

    actor: Mapped["PoliticalActorModel"] = relationship(back_populates="followers")

    __table_args__ = (Index("ix_followed_actors_actor", "political_actor_id"),)


class IotDeviceLinkModel(Base):
    __tablename__ = "iot_device_links"

    device_token: Mapped[str] = mapped_column(String(64), primary_key=True)
    anonymous_id: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="linked")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        UniqueConstraint("anonymous_id", name="uq_iot_device_links_anonymous_id"),
        Index("ix_iot_device_links_anonymous_id", "anonymous_id"),
        Index("ix_iot_device_links_updated_at", "updated_at"),
    )


class IotPairingSessionModel(Base):
    __tablename__ = "iot_pairing_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    device_token: Mapped[str] = mapped_column(String(64), nullable=False)
    pairing_code_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    qr_payload: Mapped[str] = mapped_column(String(512), nullable=False)
    firmware_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    consumed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        Index("ix_iot_pairing_sessions_device_expires", "device_token", "expires_at"),
    )


class SourceSyncRunModel(Base):
    __tablename__ = "source_sync_runs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    operation: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False)
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    finished_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        Index("ix_source_sync_runs_source_operation", "source", "operation"),
    )


class SourceSyncCursorModel(Base):
    __tablename__ = "source_sync_cursors"

    source: Mapped[str] = mapped_column(String(32), primary_key=True)
    cursor_name: Mapped[str] = mapped_column(String(64), primary_key=True)
    cursor_value: Mapped[str | None] = mapped_column(String(512), nullable=True)
    refreshed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class IotDeviceEventModel(Base):
    __tablename__ = "iot_device_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    device_token: Mapped[str] = mapped_column(String(64), nullable=False)
    event_type: Mapped[str] = mapped_column(String(32), nullable=False)
    payload: Mapped[dict[str, object]] = mapped_column(JSON, nullable=False)
    published_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    __table_args__ = (
        Index(
            "ix_iot_device_events_token_type_at",
            "device_token",
            "event_type",
            "published_at",
        ),
    )


class PostModel(Base):
    __tablename__ = "posts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    anonymous_id: Mapped[str] = mapped_column(String(64), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    political_actor_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("political_actors.id", ondelete="SET NULL"), nullable=True
    )
    theme_slug: Mapped[str | None] = mapped_column(String(64), nullable=True)
    score: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    comments: Mapped[list["CommentModel"]] = relationship(
        back_populates="post", cascade="all, delete-orphan"
    )
    votes: Mapped[list["PostVoteModel"]] = relationship(
        back_populates="post", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_posts_anonymous_id", "anonymous_id"),
        Index("ix_posts_score_created", "score", "created_at"),
        Index("ix_posts_actor_id", "political_actor_id"),
    )


class CommentModel(Base):
    __tablename__ = "comments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    post_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False
    )
    anonymous_id: Mapped[str] = mapped_column(String(64), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    post: Mapped["PostModel"] = relationship(back_populates="comments")

    __table_args__ = (Index("ix_comments_post_id", "post_id"),)


class PostVoteModel(Base):
    __tablename__ = "post_votes"

    post_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("posts.id", ondelete="CASCADE"), primary_key=True
    )
    anonymous_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[int] = mapped_column(SmallInteger, nullable=False)

    post: Mapped["PostModel"] = relationship(back_populates="votes")


class ModerationLogModel(Base):
    __tablename__ = "moderation_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    post_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    anonymous_id: Mapped[str] = mapped_column(String(64), nullable=False)
    content_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    approved: Mapped[bool] = mapped_column(Boolean, nullable=False)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    model_used: Mapped[str] = mapped_column(String(128), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    __table_args__ = (Index("ix_moderation_log_post_id", "post_id"),)
