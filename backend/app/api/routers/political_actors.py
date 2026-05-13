from datetime import datetime, timedelta, timezone
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response

from app.api.deps import (
    get_camara_deputy_index_source,
    get_camara_evidence_source,
    get_followed_actor_repo,
    get_official_evidence_repo,
    get_political_actor_repo,
    get_sentinela_summary_repo,
)
from app.api.schemas.political_actors import (
    CitationOut,
    EvidenceResponse,
    FollowActorRequest,
    FollowedActorResponse,
    OfficialEvidenceOut,
    PoliticalActorListResponse,
    PoliticalActorOut,
    SectionSummaryOut,
    SentinelaSectionsOut,
    SentinelaSummaryOut,
    TrendingActorOut,
    TrendingActorResponse,
)
from app.core.config import settings
from app.core.entities.political_actor import (
    OfficialEvidence,
    PoliticalActor,
    SectionSummary,
)
from app.core.use_cases.ensure_political_actor_index import (
    ensure_political_actor_index,
)
from app.core.use_cases.follow_political_actor import (
    delete_followed_political_actor,
    follow_political_actor,
    get_followed_political_actor,
)
from app.core.use_cases.generate_sentinela_summary import (
    ActorNotFoundError,
    GenerationFailedError,
    generate_sentinela_summary,
)
from app.core.use_cases.get_official_evidence import (
    get_official_evidence,
    get_or_refresh_official_evidence,
)
from app.core.use_cases.get_political_actor import get_political_actor
from app.core.use_cases.list_political_actors import list_political_actors
from app.core.use_cases.list_trending_political_actors import (
    list_trending_political_actors,
)
from app.infrastructure.database.political_actor_repositories import (
    SqlFollowedActorRepository,
    SqlOfficialEvidenceRepository,
    SqlPoliticalActorRepository,
    SqlSentinelaSummaryRepository,
)
from app.infrastructure.sources.camara import (
    CamaraDeputyIndexSource,
    CamaraEvidenceSource,
    CamaraSourceError,
)

router = APIRouter(prefix="/political-actors", tags=["Politicos"])
me_router = APIRouter(prefix="/me", tags=["Politicos"])
AnonymousHeader = Annotated[str, Header(min_length=1, max_length=64)]


def _actor_out(actor: PoliticalActor) -> PoliticalActorOut:
    return PoliticalActorOut(**actor.__dict__)


def _evidence_out(evidence: OfficialEvidence) -> OfficialEvidenceOut:
    return OfficialEvidenceOut(**evidence.__dict__)


@router.get("", response_model=PoliticalActorListResponse)
def list_all(
    search: str | None = Query(default=None),
    state: str | None = Query(default=None, min_length=2, max_length=2),
    party: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    repo: SqlPoliticalActorRepository = Depends(get_political_actor_repo),
    index_source: CamaraDeputyIndexSource = Depends(get_camara_deputy_index_source),
) -> PoliticalActorListResponse:
    try:
        ensure_political_actor_index(
            repo,
            index_source,
            datetime.now(timezone.utc),
            timedelta(hours=24),
        )
    except CamaraSourceError as exc:
        if repo.count() == 0:
            raise HTTPException(
                status_code=503,
                detail="Fonte oficial temporariamente indisponivel.",
            ) from exc

    actors, total = list_political_actors(
        repo,
        search=search,
        state=state,
        party=party,
        page=page,
        page_size=page_size,
    )
    return PoliticalActorListResponse(
        actors=[_actor_out(actor) for actor in actors],
        total_count=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.get("/trending", response_model=TrendingActorResponse)
def trending(
    limit: int = Query(default=10, ge=1, le=20),
    repo: SqlFollowedActorRepository = Depends(get_followed_actor_repo),
) -> TrendingActorResponse:
    items = list_trending_political_actors(repo, limit=limit, min_followers=2)
    return TrendingActorResponse(
        actors=[
            TrendingActorOut(actor=_actor_out(item.actor), rank=item.rank)
            for item in items
        ]
    )


@router.get("/{actor_id}", response_model=PoliticalActorOut)
def get_one(
    actor_id: int,
    repo: SqlPoliticalActorRepository = Depends(get_political_actor_repo),
) -> PoliticalActorOut:
    actor = get_political_actor(repo, actor_id)
    if actor is None:
        raise HTTPException(status_code=404, detail="Politico nao encontrado.")
    return _actor_out(actor)


@router.get("/{actor_id}/evidence", response_model=EvidenceResponse)
def evidence(
    actor_id: int,
    actor_repo: SqlPoliticalActorRepository = Depends(get_political_actor_repo),
    evidence_repo: SqlOfficialEvidenceRepository = Depends(get_official_evidence_repo),
    source: CamaraEvidenceSource = Depends(get_camara_evidence_source),
) -> EvidenceResponse:
    actor = get_political_actor(actor_repo, actor_id)
    if actor is None:
        raise HTTPException(status_code=404, detail="Politico nao encontrado.")
    now = datetime.now(timezone.utc)
    try:
        rows, cache_status = get_or_refresh_official_evidence(
            evidence_repo,
            actor,
            source,
            now,
        )
    except CamaraSourceError as exc:
        rows, cache_status = get_official_evidence(evidence_repo, actor_id, now)
        if not rows:
            raise HTTPException(
                status_code=503,
                detail="Fonte oficial temporariamente indisponivel.",
            ) from exc
    return EvidenceResponse(
        political_actor_id=actor_id,
        cache_status=cache_status,
        evidence=[_evidence_out(row) for row in rows],
    )


@me_router.put("/followed-actor", response_model=FollowedActorResponse)
def set_followed(
    body: FollowActorRequest,
    x_farol_anonymous_id: AnonymousHeader,
    actor_repo: SqlPoliticalActorRepository = Depends(get_political_actor_repo),
    follow_repo: SqlFollowedActorRepository = Depends(get_followed_actor_repo),
) -> FollowedActorResponse:
    followed = follow_political_actor(
        follow_repo,
        actor_repo,
        x_farol_anonymous_id,
        body.political_actor_id,
    )
    if followed is None:
        raise HTTPException(status_code=404, detail="Politico nao encontrado.")
    actor = get_political_actor(actor_repo, followed.political_actor_id)
    if actor is None:
        raise HTTPException(status_code=404, detail="Politico nao encontrado.")
    return FollowedActorResponse(
        political_actor=_actor_out(actor),
        updated_at=followed.updated_at,
    )


@me_router.get("/followed-actor", response_model=FollowedActorResponse)
def get_followed(
    x_farol_anonymous_id: AnonymousHeader,
    actor_repo: SqlPoliticalActorRepository = Depends(get_political_actor_repo),
    follow_repo: SqlFollowedActorRepository = Depends(get_followed_actor_repo),
) -> FollowedActorResponse:
    followed = get_followed_political_actor(follow_repo, x_farol_anonymous_id)
    if followed is None:
        raise HTTPException(status_code=404, detail="Nenhum politico acompanhado.")
    actor = get_political_actor(actor_repo, followed.political_actor_id)
    if actor is None:
        raise HTTPException(status_code=404, detail="Politico nao encontrado.")
    return FollowedActorResponse(
        political_actor=_actor_out(actor),
        updated_at=followed.updated_at,
    )


@me_router.delete("/followed-actor", status_code=204)
def delete_followed(
    response: Response,
    x_farol_anonymous_id: AnonymousHeader,
    follow_repo: SqlFollowedActorRepository = Depends(get_followed_actor_repo),
) -> Response:
    delete_followed_political_actor(follow_repo, x_farol_anonymous_id)
    response.status_code = 204
    return response


@router.get("/{actor_id}/summary", response_model=SentinelaSummaryOut)
def get_sentinela_summary(
    actor_id: int,
    response: Response,
    actor_repo: SqlPoliticalActorRepository = Depends(get_political_actor_repo),
    evidence_repo: SqlOfficialEvidenceRepository = Depends(get_official_evidence_repo),
    summary_repo: SqlSentinelaSummaryRepository = Depends(get_sentinela_summary_repo),
    period: Literal["quarter", "full"] = Query(default="quarter"),
) -> SentinelaSummaryOut:
    now = datetime.now(timezone.utc)

    try:
        summary, cached = generate_sentinela_summary(
            actor_id=actor_id,
            period=period,
            actor_repo=actor_repo,
            evidence_repo=evidence_repo,
            summary_repo=summary_repo,
            api_key=settings.gemini_api_key or "",
            now=now,
        )
    except ActorNotFoundError:
        raise HTTPException(status_code=404, detail="Político não encontrado.")
    except GenerationFailedError:
        raise HTTPException(
            status_code=503,
            detail="Não foi possível gerar o resumo no momento. Tente novamente em instantes.",
        )

    response.headers["X-Sentinela-Cached"] = "true" if cached else "false"
    response.headers["X-Sentinela-Generated-At"] = summary.generated_at.isoformat()

    def _section_out(section: SectionSummary) -> SectionSummaryOut:
        return SectionSummaryOut(
            summary=section.summary,
            citations=[
                CitationOut(label=c["label"], source_url=c["source_url"])
                for c in section.citations
                if "label" in c and "source_url" in c
            ],
        )

    return SentinelaSummaryOut(
        period=summary.period,
        generated_at=summary.generated_at,
        cached=cached,
        synthesis=summary.synthesis,
        sections=SentinelaSectionsOut(
            votes=_section_out(summary.votes),
            propositions=_section_out(summary.propositions),
            expenses=_section_out(summary.expenses),
        ),
    )
