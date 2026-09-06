from datetime import datetime, timezone
from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    Query,
    Response,
    status,
)

from app.api.deps import (
    get_comment_repo,
    get_moderation_client,
    get_moderation_log_repo,
    get_post_repo,
    get_post_report_repo,
    get_vote_repo,
)
from app.api.schemas.community import (
    CommentIn,
    CommentOut,
    PostDetailOut,
    PostIn,
    PostListResponse,
    PostOut,
    ReportIn,
    VoteIn,
)
from app.core.entities.community import Comment, Post
from app.core.use_cases.create_comment import create_comment
from app.core.use_cases.get_post import get_post
from app.core.use_cases.list_posts import list_posts
from app.core.use_cases.moderate_and_create_post import moderate_and_create_post
from app.core.use_cases.post_rate_limit import (
    WINDOW,
    PostRateLimitExceeded,
    check_post_rate_limit,
)
from app.core.use_cases.remove_post import NotThePostAuthorError, remove_own_post
from app.core.use_cases.report_post import report_post
from app.core.use_cases.vote_post import vote_post
from app.infrastructure.database.community_repositories import (
    SqlCommentRepository,
    SqlModerationLogRepository,
    SqlPostReportRepository,
    SqlPostRepository,
    SqlPostVoteRepository,
)
from app.infrastructure.llm.moderation_client import (
    ModerationPort,
    ModerationUnavailable,
)

router = APIRouter(prefix="/community", tags=["Comunidade"])
AnonymousHeader = Annotated[str, Header(min_length=1, max_length=64)]


def _post_out(post: Post) -> PostOut:
    return PostOut(
        id=post.id,
        anonymous_id=post.anonymous_id,
        content=post.content,
        political_actor_id=post.political_actor_id,
        theme_slug=post.theme_slug,
        score=post.score,
        created_at=post.created_at,
        removed=post.removed_at is not None,
        removed_by=post.removed_by,
    )


def _comment_out(comment: Comment) -> CommentOut:
    return CommentOut(
        id=comment.id,
        post_id=comment.post_id,
        anonymous_id=comment.anonymous_id,
        content=comment.content,
        created_at=comment.created_at,
    )


@router.post("/posts", response_model=PostOut, status_code=status.HTTP_201_CREATED)
def create_post_endpoint(
    body: PostIn,
    x_farol_anonymous_id: AnonymousHeader,
    post_repo: SqlPostRepository = Depends(get_post_repo),
    log_repo: SqlModerationLogRepository = Depends(get_moderation_log_repo),
    moderation_client: ModerationPort = Depends(get_moderation_client),
) -> PostOut:
    since = datetime.now(timezone.utc) - WINDOW
    try:
        check_post_rate_limit(
            post_repo.count_by_author_since(x_farol_anonymous_id, since)
        )
    except PostRateLimitExceeded as exc:
        raise HTTPException(
            status_code=429,
            detail=(
                "Você publicou demais nos últimos minutos. "
                "Tente novamente em breve."
            ),
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from None

    try:
        post, result = moderate_and_create_post(
            post_repo, log_repo, moderation_client,
            x_farol_anonymous_id, body.content,
            body.political_actor_id, body.theme_slug,
        )
    except ModerationUnavailable:
        raise HTTPException(
            status_code=503,
            detail="Serviço de moderação temporariamente indisponível.",
        )
    if post is None:
        raise HTTPException(status_code=422, detail=result.reason)
    return _post_out(post)


@router.get("/posts", response_model=PostListResponse)
def list_posts_endpoint(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    political_actor_id: int | None = Query(default=None),
    theme_slug: str | None = Query(default=None),
    post_repo: SqlPostRepository = Depends(get_post_repo),
) -> PostListResponse:
    posts, total = list_posts(
        post_repo, page=page, page_size=page_size,
        political_actor_id=political_actor_id, theme_slug=theme_slug,
    )
    return PostListResponse(
        posts=[_post_out(p) for p in posts],
        total_count=total, page=page, page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.get("/posts/{post_id}", response_model=PostDetailOut)
def get_post_endpoint(
    post_id: str,
    post_repo: SqlPostRepository = Depends(get_post_repo),
    comment_repo: SqlCommentRepository = Depends(get_comment_repo),
) -> PostDetailOut:
    result = get_post(post_repo, comment_repo, post_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    post, comments = result
    return PostDetailOut(post=_post_out(post), comments=[_comment_out(c) for c in comments])


@router.post("/posts/{post_id}/votes", response_model=PostOut)
def vote_post_endpoint(
    post_id: str,
    body: VoteIn,
    x_farol_anonymous_id: AnonymousHeader,
    post_repo: SqlPostRepository = Depends(get_post_repo),
    vote_repo: SqlPostVoteRepository = Depends(get_vote_repo),
) -> PostOut:
    updated = vote_post(post_repo, vote_repo, post_id, x_farol_anonymous_id, body.value)
    if updated is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    return _post_out(updated)


@router.post(
    "/posts/{post_id}/comments",
    response_model=CommentOut,
    status_code=status.HTTP_201_CREATED,
)
def create_comment_endpoint(
    post_id: str,
    body: CommentIn,
    x_farol_anonymous_id: AnonymousHeader,
    post_repo: SqlPostRepository = Depends(get_post_repo),
    comment_repo: SqlCommentRepository = Depends(get_comment_repo),
) -> CommentOut:
    comment = create_comment(post_repo, comment_repo, post_id, x_farol_anonymous_id, body.content)
    if comment is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    return _comment_out(comment)


@router.post(
    "/posts/{post_id}/reports",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Denuncia um post",
)
def report_post_endpoint(
    post_id: str,
    body: ReportIn,
    x_farol_anonymous_id: AnonymousHeader,
    post_repo: SqlPostRepository = Depends(get_post_repo),
    report_repo: SqlPostReportRepository = Depends(get_post_report_repo),
    log_repo: SqlModerationLogRepository = Depends(get_moderation_log_repo),
    moderation_client: ModerationPort = Depends(get_moderation_client),
) -> Response:
    if post_repo.get_by_id(post_id) is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")

    report_post(
        report_repo=report_repo,
        post_repo=post_repo,
        log_repo=log_repo,
        moderation_client=moderation_client,
        post_id=post_id,
        anonymous_id=x_farol_anonymous_id,
        reason=body.reason,
        detail=body.detail,
        now=datetime.now(timezone.utc),
    )
    # 204 sempre, inclusive na denuncia repetida: revelar contagem ou limiar
    # permitiria sondar o estado da moderacao.
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/posts/{post_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove o próprio post",
)
def delete_post_endpoint(
    post_id: str,
    x_farol_anonymous_id: AnonymousHeader,
    post_repo: SqlPostRepository = Depends(get_post_repo),
) -> Response:
    try:
        existe = remove_own_post(
            post_repo,
            post_id=post_id,
            anonymous_id=x_farol_anonymous_id,
            now=datetime.now(timezone.utc),
        )
    except NotThePostAuthorError:
        raise HTTPException(
            status_code=403, detail="Só o autor pode remover este post."
        ) from None
    if not existe:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
