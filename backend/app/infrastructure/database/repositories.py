from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.entities.candidate import Candidate, CandidatePosition, Theme, Thesis
from app.core.use_cases.interfaces import (
    CandidateRepository,
    PositionRepository,
    ThemeRepository,
    ThesisRepository,
)
from app.infrastructure.database.models import (
    CandidateModel,
    CandidatePositionModel,
    ThemeModel,
    ThesisModel,
)


def _to_thesis(m: ThesisModel, total_candidates: int) -> Thesis:
    with_position = sum(
        1 for p in m.positions if p.position != "sem_posicao"
    )
    coverage = (with_position / total_candidates * 100) if total_candidates else 0.0
    return Thesis(
        id=m.id,
        text=m.text,
        theme_id=m.theme_id,
        theme_name=m.theme.name if m.theme else "",
        status=m.status,
        coverage=round(coverage, 1),
    )


def _to_candidate(m: CandidateModel) -> Candidate:
    return Candidate(
        id=m.id,
        name=m.name,
        party=m.party,
        coalition=m.coalition,
        number=m.number,
        running_mate=m.running_mate,
        spectrum=m.spectrum,
        party_logo=m.party_logo,
        foto_url=m.foto_url,
        cargo=m.cargo,
        estado=m.estado,
    )


def _to_position(m: CandidatePositionModel) -> CandidatePosition:
    return CandidatePosition(
        thesis_id=m.thesis_id,
        thesis_text=m.thesis.text if m.thesis else "",
        theme_id=m.thesis.theme_id if m.thesis else "",
        theme_name=m.thesis.theme.name if (m.thesis and m.thesis.theme) else "",
        position=m.position,
        justification=m.justification,
        quote=m.quote,
    )


class SqlThesisRepository(ThesisRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_approved(
        self,
        themes: list[str] | None = None,
        limit: int = 30,
    ) -> list[Thesis]:
        total_candidates = self._db.scalar(select(func.count(CandidateModel.id))) or 0

        stmt = (
            select(ThesisModel)
            .options(
                selectinload(ThesisModel.theme),
                selectinload(ThesisModel.positions),
            )
            .where(ThesisModel.status == "approved")
        )
        if themes:
            stmt = stmt.where(ThesisModel.theme_id.in_(themes))

        rows = self._db.execute(stmt).scalars().all()
        return [_to_thesis(r, total_candidates) for r in rows]

    def get_by_ids(self, ids: list[int]) -> list[Thesis]:
        total_candidates = self._db.scalar(select(func.count(CandidateModel.id))) or 0
        stmt = (
            select(ThesisModel)
            .options(
                selectinload(ThesisModel.theme),
                selectinload(ThesisModel.positions),
            )
            .where(ThesisModel.id.in_(ids))
        )
        rows = self._db.execute(stmt).scalars().all()
        return [_to_thesis(r, total_candidates) for r in rows]


class SqlCandidateRepository(CandidateRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_id(self, candidate_id: str) -> Candidate | None:
        m = self._db.get(CandidateModel, candidate_id)
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
        stmt = select(CandidateModel)
        if cargo:
            stmt = stmt.where(CandidateModel.cargo == cargo)
        if estado:
            stmt = stmt.where(CandidateModel.estado == estado)
        if partido:
            stmt = stmt.where(CandidateModel.party == partido)
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

    def get_by_candidate(self, candidate_id: str) -> list[CandidatePosition]:
        stmt = (
            select(CandidatePositionModel)
            .options(
                selectinload(CandidatePositionModel.thesis).selectinload(ThesisModel.theme)
            )
            .join(ThesisModel)
            .where(
                CandidatePositionModel.candidate_id == candidate_id,
                ThesisModel.status == "approved",
            )
        )
        rows = self._db.execute(stmt).scalars().all()
        return [_to_position(r) for r in rows]

    def get_by_candidates_and_theses(
        self,
        candidate_ids: list[str],
        thesis_ids: list[int],
    ) -> dict[str, dict[int, CandidatePosition]]:
        stmt = (
            select(CandidatePositionModel)
            .options(
                selectinload(CandidatePositionModel.thesis).selectinload(ThesisModel.theme)
            )
            .where(
                CandidatePositionModel.candidate_id.in_(candidate_ids),
                CandidatePositionModel.thesis_id.in_(thesis_ids),
            )
        )
        rows = self._db.execute(stmt).scalars().all()
        result: dict[str, dict[int, CandidatePosition]] = {}
        for row in rows:
            result.setdefault(row.candidate_id, {})[row.thesis_id] = _to_position(row)
        return result


class SqlThemeRepository(ThemeRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_with_min_theses(self, min_theses: int = 3) -> list[Theme]:
        count_subq = (
            select(ThesisModel.theme_id, func.count(ThesisModel.id).label("total"))
            .where(ThesisModel.status == "approved")
            .group_by(ThesisModel.theme_id)
            .subquery()
        )
        stmt = (
            select(ThemeModel, count_subq.c.total)
            .join(count_subq, ThemeModel.id == count_subq.c.theme_id)
            .where(count_subq.c.total >= min_theses)
        )
        rows = self._db.execute(stmt).all()
        return [
            Theme(
                id=row[0].id,
                name=row[0].name,
                description=row[0].description,
                icon_slug=row[0].icon_slug,
                total_approved_theses=row[1],
            )
            for row in rows
        ]
