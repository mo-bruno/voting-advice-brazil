from __future__ import annotations

import json
from collections.abc import Mapping, Sequence
from datetime import datetime, timezone
from typing import Any, cast

from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.entities.political_actor import (
    FollowedActor,
    OfficialEvidence,
    PoliticalActor,
    SectionSummary,
    SentinelaSummary,
    TrendingActor,
)
from app.core.use_cases.interfaces import (
    FollowedActorRepository,
    OfficialEvidenceRepository,
    PoliticalActorRepository,
    SentinelaSummaryRepository,
)
from app.infrastructure.database.models import (
    FollowedActorModel,
    OfficialEvidenceModel,
    PoliticalActorModel,
    SentinelaSummaryModel,
)


def _to_actor(model: PoliticalActorModel) -> PoliticalActor:
    return PoliticalActor(
        id=model.id,
        source=model.source,
        source_id=model.source_id,
        normalized_name=model.normalized_name,
        display_name=model.display_name,
        party=model.party,
        state=model.state,
        role=model.role,
        status=model.status,
        photo_url=model.photo_url,
        source_url=model.source_url,
        last_indexed_at=model.last_indexed_at,
    )


def _to_evidence(model: OfficialEvidenceModel) -> OfficialEvidence:
    return OfficialEvidence(
        id=model.id,
        political_actor_id=model.political_actor_id,
        source=model.source,
        source_id=model.source_id,
        evidence_type=model.evidence_type,
        title=model.title,
        summary=model.summary,
        evidence_date=model.evidence_date,
        source_url=model.source_url,
        fetched_at=model.fetched_at,
        expires_at=model.expires_at,
    )


def _comparable_datetime(value: datetime, reference: datetime) -> datetime:
    if value.tzinfo is None and reference.tzinfo is not None:
        return value.replace(tzinfo=reference.tzinfo)
    return value


class SqlPoliticalActorRepository(PoliticalActorRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def count(self) -> int:
        return self._db.scalar(select(func.count(PoliticalActorModel.id))) or 0

    def newest_indexed_at(self) -> datetime | None:
        return self._db.scalar(select(func.max(PoliticalActorModel.last_indexed_at)))

    def get_by_id(self, actor_id: int) -> PoliticalActor | None:
        model = self._db.get(PoliticalActorModel, actor_id)
        return _to_actor(model) if model else None

    def get_by_source(self, source: str, source_id: str) -> PoliticalActor | None:
        stmt = select(PoliticalActorModel).where(
            PoliticalActorModel.source == source,
            PoliticalActorModel.source_id == source_id,
        )
        model = self._db.execute(stmt).scalar_one_or_none()
        return _to_actor(model) if model else None

    def list(
        self,
        search: str | None = None,
        state: str | None = None,
        party: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[PoliticalActor], int]:
        stmt = select(PoliticalActorModel)
        if search:
            term = search.lower().strip()
            display_term = search.strip()
            stmt = stmt.where(
                or_(
                    PoliticalActorModel.normalized_name.ilike(f"%{term}%"),
                    PoliticalActorModel.display_name.ilike(f"%{display_term}%"),
                )
            )
        if state:
            stmt = stmt.where(PoliticalActorModel.state == state.upper())
        if party:
            stmt = stmt.where(PoliticalActorModel.party == party.upper())
        stmt = stmt.order_by(PoliticalActorModel.display_name)
        total = self._db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        offset = (page - 1) * page_size
        rows = self._db.execute(stmt.offset(offset).limit(page_size)).scalars().all()
        return [_to_actor(row) for row in rows], total

    def upsert_index(self, rows: Sequence[Mapping[str, object]]) -> int:
        count = 0
        for row in rows:
            row_data = cast("dict[str, Any]", dict(row))
            existing = self._db.execute(
                select(PoliticalActorModel).where(
                    PoliticalActorModel.source == row_data["source"],
                    PoliticalActorModel.source_id == row_data["source_id"],
                )
            ).scalar_one_or_none()
            if existing is None:
                self._db.add(PoliticalActorModel(**row_data))
            else:
                for key, value in row_data.items():
                    setattr(existing, key, value)
            count += 1
        self._db.commit()
        return count


class SqlOfficialEvidenceRepository(OfficialEvidenceRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_by_actor(
        self,
        actor_id: int,
        now: datetime,
    ) -> tuple[list[OfficialEvidence], bool]:
        stmt = (
            select(OfficialEvidenceModel)
            .where(OfficialEvidenceModel.political_actor_id == actor_id)
            .order_by(
                OfficialEvidenceModel.evidence_date.desc(),
                OfficialEvidenceModel.id.desc(),
            )
        )
        rows = self._db.execute(stmt).scalars().all()
        is_fresh = bool(rows) and all(
            _comparable_datetime(row.expires_at, now) > now for row in rows
        )
        return [_to_evidence(row) for row in rows], is_fresh

    def replace_for_actor_type(
        self,
        actor_id: int,
        evidence_type: str,
        rows: Sequence[Mapping[str, object]],
    ) -> None:
        existing = (
            self._db.execute(
                select(OfficialEvidenceModel).where(
                    OfficialEvidenceModel.political_actor_id == actor_id,
                    OfficialEvidenceModel.evidence_type == evidence_type,
                )
            )
            .scalars()
            .all()
        )
        for existing_model in existing:
            self._db.delete(existing_model)
        if existing:
            self._db.flush()
        for row in rows:
            row_data = cast("dict[str, Any]", dict(row))
            self._db.add(OfficialEvidenceModel(**row_data))
        self._db.commit()

    def list_by_actor_since(
        self,
        actor_id: int,
        since: datetime | None = None,
    ) -> list[OfficialEvidence]:
        stmt = select(OfficialEvidenceModel).where(
            OfficialEvidenceModel.political_actor_id == actor_id
        )
        if since is not None:
            stmt = stmt.where(OfficialEvidenceModel.evidence_date >= since)
        stmt = stmt.order_by(
            OfficialEvidenceModel.evidence_date.desc(),
            OfficialEvidenceModel.id.desc(),
        )
        rows = self._db.execute(stmt).scalars().all()
        return [_to_evidence(row) for row in rows]


class SqlFollowedActorRepository(FollowedActorRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_followed(self, anonymous_id: str) -> FollowedActor | None:
        model = self._db.get(FollowedActorModel, anonymous_id)
        if model is None:
            return None
        return FollowedActor(
            anonymous_id=model.anonymous_id,
            political_actor_id=model.political_actor_id,
            updated_at=model.updated_at,
        )

    def set_followed(self, anonymous_id: str, actor_id: int) -> FollowedActor:
        model = self._db.get(FollowedActorModel, anonymous_id)
        if model is None:
            model = FollowedActorModel(
                anonymous_id=anonymous_id,
                political_actor_id=actor_id,
            )
            self._db.add(model)
        else:
            model.political_actor_id = actor_id
        self._db.commit()
        self._db.refresh(model)
        return FollowedActor(
            anonymous_id=model.anonymous_id,
            political_actor_id=model.political_actor_id,
            updated_at=model.updated_at,
        )

    def delete_followed(self, anonymous_id: str) -> bool:
        model = self._db.get(FollowedActorModel, anonymous_id)
        if model is None:
            return False
        self._db.delete(model)
        self._db.commit()
        return True

    def list_trending(
        self,
        limit: int = 10,
        min_followers: int = 2,
    ) -> list[TrendingActor]:
        count_label = func.count(FollowedActorModel.anonymous_id).label("follow_count")
        stmt = (
            select(PoliticalActorModel, count_label)
            .join(
                FollowedActorModel,
                FollowedActorModel.political_actor_id == PoliticalActorModel.id,
            )
            .group_by(PoliticalActorModel.id)
            .having(count_label >= min_followers)
            .order_by(count_label.desc(), PoliticalActorModel.display_name)
            .limit(limit)
        )
        rows = self._db.execute(stmt).all()
        return [
            TrendingActor(
                actor=_to_actor(row[0]),
                rank=index + 1,
                follow_count=int(row[1]),
            )
            for index, row in enumerate(rows)
        ]


def _to_section(raw: str) -> SectionSummary:
    data = json.loads(raw)
    return SectionSummary(
        summary=data["summary"],
        citations=data.get("citations", []),
    )


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _to_sentinela_summary(model: SentinelaSummaryModel) -> SentinelaSummary:
    return SentinelaSummary(
        id=model.id,
        political_actor_id=model.political_actor_id,
        period=model.period,
        generated_at=_ensure_utc(model.generated_at),
        expires_at=_ensure_utc(model.expires_at),
        votes=_to_section(model.votes_summary),
        propositions=_to_section(model.propositions_summary),
        expenses=_to_section(model.expenses_summary),
        synthesis=model.synthesis,
    )


def _apply_sentinela_summary_data(
    model: SentinelaSummaryModel,
    data: dict[str, object],
) -> None:
    for key, value in data.items():
        setattr(model, key, value)


class SqlSentinelaSummaryRepository(SentinelaSummaryRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_valid(
        self,
        actor_id: int,
        period: str,
        now: datetime,
    ) -> SentinelaSummary | None:
        stmt = select(SentinelaSummaryModel).where(
            SentinelaSummaryModel.political_actor_id == actor_id,
            SentinelaSummaryModel.period == period,
            SentinelaSummaryModel.expires_at > now,
        )
        model = self._db.execute(stmt).scalar_one_or_none()
        return _to_sentinela_summary(model) if model else None

    def upsert(self, data: dict[str, object]) -> SentinelaSummary:
        stmt = select(SentinelaSummaryModel).where(
            SentinelaSummaryModel.political_actor_id == data["political_actor_id"],
            SentinelaSummaryModel.period == data["period"],
        )
        model = self._db.execute(stmt).scalar_one_or_none()
        if model:
            _apply_sentinela_summary_data(model, data)
        else:
            model = SentinelaSummaryModel(**data)
            self._db.add(model)
        try:
            self._db.commit()
        except IntegrityError:
            self._db.rollback()
            model = self._db.execute(stmt).scalar_one_or_none()
            if model is None:
                raise
            _apply_sentinela_summary_data(model, data)
            self._db.commit()
        self._db.refresh(model)
        return _to_sentinela_summary(model)
