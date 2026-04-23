from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.cache import cache_get, cache_set
from app.api.deps import get_candidate_repo, get_position_repo
from app.api.schemas.candidates import (
    CandidateListResponse,
    CandidateOut,
    JustificationOut,
    JustificationSummaryOut,
    JustificationsResponse,
    PositionOut,
    PositionsResponse,
)
from app.core.use_cases.get_candidate import get_candidate
from app.core.use_cases.get_candidate_justifications import get_candidate_justifications
from app.core.use_cases.get_candidate_positions import get_candidate_positions
from app.core.use_cases.list_candidates import list_candidates
from app.infrastructure.database.repositories import (
    SqlCandidateRepository,
    SqlPositionRepository,
)

router = APIRouter(prefix="/candidates", tags=["Candidatos"])

_CANDIDATE_TTL = 3600  # 1 hour


def _make_candidate_out(c: object) -> CandidateOut:
    return CandidateOut(
        id=c.id,  # type: ignore[attr-defined]
        external_id=c.external_id,  # type: ignore[attr-defined]
        name=c.name,  # type: ignore[attr-defined]
        party_id=c.party_id,  # type: ignore[attr-defined]
        party_acronym=c.party_acronym,  # type: ignore[attr-defined]
        party_name=c.party_name,  # type: ignore[attr-defined]
        party_logo_url=c.party_logo_url,  # type: ignore[attr-defined]
        coalition=c.coalition,  # type: ignore[attr-defined]
        ballot_number=c.ballot_number,  # type: ignore[attr-defined]
        running_mate=c.running_mate,  # type: ignore[attr-defined]
        spectrum=c.spectrum,  # type: ignore[attr-defined]
        photo_url=c.photo_url,  # type: ignore[attr-defined]
        office=c.office,  # type: ignore[attr-defined]
        state=c.state,  # type: ignore[attr-defined]
        city=c.city,  # type: ignore[attr-defined]
        election_year=c.election_year,  # type: ignore[attr-defined]
        election_round=c.election_round,  # type: ignore[attr-defined]
    )


@router.get("", response_model=CandidateListResponse, summary="Lista candidatos com filtros")
def list_all(
    cargo: str | None = Query(default=None),
    estado: str | None = Query(default=None),
    partido: str | None = Query(default=None),
    search: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    repo: SqlCandidateRepository = Depends(get_candidate_repo),
) -> CandidateListResponse:
    cache_key = f"candidates:list:{cargo}:{estado}:{partido}:{search}:{page}:{page_size}"
    cached = cache_get(cache_key)
    if cached is not None:
        return cached

    candidates, total = list_candidates(
        repo, cargo=cargo, estado=estado, partido=partido,
        search=search, page=page, page_size=page_size,
    )
    response = CandidateListResponse(
        candidates=[_make_candidate_out(c) for c in candidates],
        total_count=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total,
    )
    cache_set(cache_key, response, _CANDIDATE_TTL)
    return response


@router.get("/{candidate_id}", response_model=CandidateOut, summary="Perfil completo do candidato")
def get_one(
    candidate_id: int,
    repo: SqlCandidateRepository = Depends(get_candidate_repo),
) -> CandidateOut:
    cache_key = f"candidates:one:{candidate_id}"
    cached = cache_get(cache_key)
    if cached is not None:
        return cached

    candidate = get_candidate(repo, candidate_id)
    if candidate is None:
        raise HTTPException(status_code=404, detail=f"Candidato '{candidate_id}' não encontrado.")

    response = _make_candidate_out(candidate)
    cache_set(cache_key, response, _CANDIDATE_TTL)
    return response


@router.get("/{candidate_id}/positions", response_model=PositionsResponse, summary="Posições do candidato nas teses")
def get_positions(
    candidate_id: int,
    candidate_repo: SqlCandidateRepository = Depends(get_candidate_repo),
    position_repo: SqlPositionRepository = Depends(get_position_repo),
) -> PositionsResponse:
    candidate = get_candidate(candidate_repo, candidate_id)
    if candidate is None:
        raise HTTPException(status_code=404, detail=f"Candidato '{candidate_id}' não encontrado.")

    cache_key = f"candidates:positions:{candidate_id}"
    cached = cache_get(cache_key)
    if cached is not None:
        return cached

    positions = get_candidate_positions(position_repo, candidate_id)
    response = PositionsResponse(
        candidate_id=candidate_id,
        positions=[
            PositionOut(
                thesis_id=p.thesis_id,
                text=p.thesis_text,
                theme_id=p.theme_id,
                theme_name=p.theme_name,
                position=p.position,
            )
            for p in positions
        ],
    )
    cache_set(cache_key, response, _CANDIDATE_TTL)
    return response


@router.get("/{candidate_id}/justifications", response_model=JustificationsResponse, summary="Posições e justificativas do candidato")
def get_justifications(
    candidate_id: int,
    group_by: str | None = Query(default=None, description="Use 'theme' para agrupar por tema"),
    candidate_repo: SqlCandidateRepository = Depends(get_candidate_repo),
    position_repo: SqlPositionRepository = Depends(get_position_repo),
) -> JustificationsResponse:
    candidate = get_candidate(candidate_repo, candidate_id)
    if candidate is None:
        raise HTTPException(status_code=404, detail=f"Candidato '{candidate_id}' não encontrado.")

    group_by_theme = group_by == "theme"
    cache_key = f"candidates:justifications:{candidate_id}:{group_by_theme}"
    cached = cache_get(cache_key)
    if cached is not None:
        return cached

    result = get_candidate_justifications(position_repo, candidate_id, group_by_theme=group_by_theme)

    def _to_out(p: object) -> JustificationOut:
        return JustificationOut(
            thesis_id=p.thesis_id,  # type: ignore[attr-defined]
            thesis_text=p.thesis_text,  # type: ignore[attr-defined]
            theme=p.theme_slug,  # type: ignore[attr-defined]
            theme_name=p.theme_name,  # type: ignore[attr-defined]
            position=p.position,  # type: ignore[attr-defined]
            justification=p.justification,  # type: ignore[attr-defined]
            quote=p.quote,  # type: ignore[attr-defined]
        )

    grouped_out = None
    if result.grouped is not None:
        grouped_out = {theme: [_to_out(p) for p in positions] for theme, positions in result.grouped.items()}

    response = JustificationsResponse(
        candidate_id=candidate_id,
        justifications=[_to_out(p) for p in result.positions],
        summary=JustificationSummaryOut(
            agree_count=result.summary.agree_count,
            disagree_count=result.summary.disagree_count,
            neutral_count=result.summary.neutral_count,
            no_position_count=result.summary.no_position_count,
        ),
        grouped=grouped_out,
    )
    cache_set(cache_key, response, _CANDIDATE_TTL)
    return response
