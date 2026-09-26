from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.config import settings
from app.core.entities.candidate import Candidate, CandidatePosition, Theme, Thesis
from app.core.use_cases.interfaces import (
    CandidateRepository,
    PositionRepository,
    ThemeRepository,
    ThesisRepository,
)
from app.core.use_cases.submit_quiz import QuizAnswer
from app.infrastructure.database.models import (
    CandidateModel,
    CandidatePositionModel,
    DeviceModel,
    PartyModel,
    QuizResponseModel,
    ThemeModel,
    ThesisModel,
)
from app.infrastructure.thesis_explanations import get_thesis_explanation


def _to_thesis(m: ThesisModel, active_candidate_ids: set[int]) -> Thesis:
    with_position = sum(
        1 for p in m.positions
        if p.candidate_id in active_candidate_ids and p.position != "sem_posicao"
    )
    coverage = (with_position / len(active_candidate_ids) * 100) if active_candidate_ids else 0.0
    return Thesis(
        id=m.id,
        text=m.text,
        theme_id=m.theme_id,
        theme_slug=m.theme.slug if m.theme else "",
        theme_name=m.theme.name if m.theme else "",
        status=m.status,
        election_year=m.election_year,
        coverage=round(coverage, 1),
        explanation=get_thesis_explanation(
            election_year=m.election_year,
            editorial_id=m.editorial_id,
            editorial_version=m.editorial_version,
            text=m.text,
        ),
    )


def _to_candidate(m: CandidateModel) -> Candidate:
    return Candidate(
        id=m.id,
        external_id=m.external_id,
        name=m.name,
        party_id=m.party_id,
        party_acronym=m.party.acronym if m.party else "",
        party_name=m.party.name if m.party else "",
        party_logo_url=m.party.logo_url if m.party else None,
        coalition=m.coalition,
        ballot_number=m.ballot_number,
        running_mate=m.running_mate,
        photo_url=m.photo_url,
        official_status=m.official_status,
        source_snapshot=m.source_snapshot,
        office=m.office,
        state=m.state,
        city=m.city,
        election_year=m.election_year,
        election_round=m.election_round,
        spectrum=m.party.spectrum if m.party else None,
    )


def _to_position(m: CandidatePositionModel) -> CandidatePosition:
    return CandidatePosition(
        thesis_id=m.thesis_id,
        thesis_text=m.thesis.text if m.thesis else "",
        theme_id=m.thesis.theme_id if m.thesis else 0,
        theme_slug=m.thesis.theme.slug if (m.thesis and m.thesis.theme) else "",
        theme_name=m.thesis.theme.name if (m.thesis and m.thesis.theme) else "",
        position=m.position,
        justification=m.justification,
        quote=m.quote,
        source_ref=m.source_ref,
        source_url=m.source_url,
    )


class SqlThesisRepository(ThesisRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def _active_candidate_ids(self) -> set[int]:
        return set(self._db.scalars(
            select(CandidateModel.id).where(
                CandidateModel.election_year == settings.active_election_year,
                CandidateModel.office == settings.active_election_office,
                CandidateModel.is_active.is_(True),
            )
        ))

    def list_approved(self, themes: list[str] | None = None, limit: int = 30) -> list[Thesis]:
        active_candidate_ids = self._active_candidate_ids()
        stmt = (
            select(ThesisModel)
            .options(
                selectinload(ThesisModel.theme),
                selectinload(ThesisModel.positions),
            )
            .where(
                ThesisModel.status == "approved",
                ThesisModel.election_year == settings.active_election_year,
            )
        )
        if themes:
            stmt = stmt.join(ThemeModel).where(ThemeModel.slug.in_(themes))
        stmt = stmt.limit(limit)
        rows = self._db.execute(stmt).scalars().all()
        return [_to_thesis(r, active_candidate_ids) for r in rows]

    def get_by_ids(self, ids: list[int]) -> list[Thesis]:
        active_candidate_ids = self._active_candidate_ids()
        stmt = (
            select(ThesisModel)
            .options(
                selectinload(ThesisModel.theme),
                selectinload(ThesisModel.positions),
            )
            .where(
                ThesisModel.id.in_(ids),
                ThesisModel.status == "approved",
                ThesisModel.election_year == settings.active_election_year,
            )
        )
        rows = self._db.execute(stmt).scalars().all()
        return [_to_thesis(r, active_candidate_ids) for r in rows]


class SqlCandidateRepository(CandidateRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_id(self, candidate_id: int) -> Candidate | None:
        stmt = (
            select(CandidateModel)
            .options(selectinload(CandidateModel.party))
            .where(
                CandidateModel.id == candidate_id,
                CandidateModel.election_year == settings.active_election_year,
                CandidateModel.office == settings.active_election_office,
                CandidateModel.is_active.is_(True),
            )
        )
        m = self._db.execute(stmt).scalar_one_or_none()
        return _to_candidate(m) if m else None

    def list(
        self,
        cargo: str | None = None,
        estado: str | None = None,
        partido: str | None = None,
        search: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[Candidate], int]:
        stmt = (
            select(CandidateModel)
            .options(selectinload(CandidateModel.party))
            .where(
                CandidateModel.election_year == settings.active_election_year,
                CandidateModel.office == settings.active_election_office,
                CandidateModel.is_active.is_(True),
            )
        )
        if cargo:
            stmt = stmt.where(CandidateModel.office == cargo)
        if estado:
            stmt = stmt.where(CandidateModel.state == estado)
        if partido:
            stmt = stmt.join(PartyModel).where(PartyModel.acronym == partido)
        if search:
            stmt = stmt.where(CandidateModel.name.ilike(f"%{search}%"))
        stmt = stmt.order_by(CandidateModel.name)
        total = self._db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        offset = (page - 1) * page_size
        rows = self._db.execute(stmt.offset(offset).limit(page_size)).scalars().all()
        return [_to_candidate(r) for r in rows], total


class SqlPositionRepository(PositionRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_candidate(self, candidate_id: int) -> list[CandidatePosition]:
        stmt = (
            select(CandidatePositionModel)
            .options(selectinload(CandidatePositionModel.thesis).selectinload(ThesisModel.theme))
            .join(ThesisModel)
            .join(CandidateModel, CandidatePositionModel.candidate_id == CandidateModel.id)
            .where(
                CandidatePositionModel.candidate_id == candidate_id,
                CandidateModel.is_active.is_(True),
                CandidateModel.election_year == settings.active_election_year,
                CandidateModel.office == settings.active_election_office,
                ThesisModel.status == "approved",
                ThesisModel.election_year == settings.active_election_year,
            )
        )
        rows = self._db.execute(stmt).scalars().all()
        return [_to_position(r) for r in rows]

    def get_by_candidates_and_theses(
        self,
        candidate_ids: list[int],
        thesis_ids: list[int],
    ) -> dict[int, dict[int, CandidatePosition]]:
        stmt = (
            select(CandidatePositionModel)
            .options(selectinload(CandidatePositionModel.thesis).selectinload(ThesisModel.theme))
            .join(ThesisModel)
            .join(CandidateModel, CandidatePositionModel.candidate_id == CandidateModel.id)
            .where(
                CandidatePositionModel.candidate_id.in_(candidate_ids),
                CandidateModel.is_active.is_(True),
                CandidateModel.election_year == settings.active_election_year,
                CandidateModel.office == settings.active_election_office,
                CandidatePositionModel.thesis_id.in_(thesis_ids),
                ThesisModel.status == "approved",
                ThesisModel.election_year == settings.active_election_year,
            )
        )
        rows = self._db.execute(stmt).scalars().all()
        result: dict[int, dict[int, CandidatePosition]] = {}
        for row in rows:
            result.setdefault(row.candidate_id, {})[row.thesis_id] = _to_position(row)
        return result


class SqlThemeRepository(ThemeRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_with_min_theses(self, min_theses: int = 3) -> list[Theme]:
        count_subq = (
            select(ThesisModel.theme_id, func.count(ThesisModel.id).label("total"))
            .where(
                ThesisModel.status == "approved",
                ThesisModel.election_year == settings.active_election_year,
            )
            .group_by(ThesisModel.theme_id)
            .subquery()
        )
        stmt = (
            select(ThemeModel, count_subq.c.total)
            .join(count_subq, ThemeModel.id == count_subq.c.theme_id)
            .where(count_subq.c.total >= min_theses)
            .order_by(ThemeModel.sort_order, ThemeModel.name)
        )
        rows = self._db.execute(stmt).all()
        return [
            Theme(
                id=row[0].id,
                slug=row[0].slug,
                name=row[0].name,
                area=row[0].area,
                description=row[0].description,
                icon_slug=row[0].icon_slug,
                sort_order=row[0].sort_order,
                total_approved_theses=row[1],
            )
            for row in rows
        ]


class SqlQuizResponseRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def upsert_answers(self, device_id: str, answers: list[QuizAnswer]) -> None:
        deduplicated_answers = self._deduplicate_answers(answers)
        try:
            self._upsert_answers_once(device_id, deduplicated_answers)
            self._db.commit()
        except IntegrityError:
            self._db.rollback()
            self._upsert_answers_once(device_id, deduplicated_answers)
            self._db.commit()

    def _deduplicate_answers(self, answers: list[QuizAnswer]) -> list[QuizAnswer]:
        latest_by_thesis_id: dict[int, QuizAnswer] = {}
        for answer in answers:
            latest_by_thesis_id.pop(answer.thesis_id, None)
            latest_by_thesis_id[answer.thesis_id] = answer
        return list(latest_by_thesis_id.values())

    def _upsert_answers_once(self, device_id: str, answers: list[QuizAnswer]) -> None:
        now = datetime.now(timezone.utc)
        device = self._db.get(DeviceModel, device_id)
        if device is None:
            device = DeviceModel(
                id=device_id,
                created_at=now,
                last_seen_at=now,
            )
            self._db.add(device)
        else:
            device.last_seen_at = now

        thesis_ids = [answer.thesis_id for answer in answers]
        year_rows = self._db.execute(
            select(ThesisModel.id, ThesisModel.election_year).where(
                ThesisModel.id.in_(thesis_ids)
            )
        ).all()
        election_year_by_thesis_id = {
            thesis_id: election_year for thesis_id, election_year in year_rows
        }

        for answer in answers:
            election_year = election_year_by_thesis_id.get(answer.thesis_id)
            if election_year is None:
                continue

            existing = self._db.execute(
                select(QuizResponseModel).where(
                    QuizResponseModel.device_id == device_id,
                    QuizResponseModel.thesis_id == answer.thesis_id,
                    QuizResponseModel.election_year == election_year,
                )
            ).scalar_one_or_none()

            if existing is None:
                self._db.add(
                    QuizResponseModel(
                        device_id=device_id,
                        thesis_id=answer.thesis_id,
                        answer=answer.answer,
                        weight=answer.weight,
                        election_year=election_year,
                        created_at=now,
                        updated_at=now,
                    )
                )
            else:
                existing.answer = answer.answer
                existing.weight = answer.weight
                existing.updated_at = now
