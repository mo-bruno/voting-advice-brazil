from dataclasses import replace
from datetime import datetime, timezone
from typing import Literal

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Response,
    status,
)

from app.api.deps import (
    get_comment_repo,
    get_comment_report_repo,
    get_moderation_client,
    get_moderation_log_repo,
    get_post_repo,
    get_post_report_repo,
    get_vote_repo,
)
from app.api.identity import (
    optional_anonymous_id,
    public_author_alias,
    require_anonymous_id,
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
from app.core.use_cases.comment_rate_limit import CommentRateLimitExceeded
from app.core.use_cases.community_errors import PostRemovedError
from app.core.use_cases.create_comment import moderate_and_create_comment
from app.core.use_cases.get_post import get_post
from app.core.use_cases.interfaces import ModerationPort, ModerationUnavailable
from app.core.use_cases.list_posts import list_posts
from app.core.use_cases.moderate_and_create_post import moderate_and_create_post
from app.core.use_cases.post_rate_limit import (
    PostRateLimitExceeded,
)
from app.core.use_cases.remove_comment import (
    NotTheCommentAuthorError,
    remove_own_comment,
)
from app.core.use_cases.remove_post import NotThePostAuthorError, remove_own_post
from app.core.use_cases.report_comment import report_comment
from app.core.use_cases.report_post import report_post
from app.core.use_cases.vote_post import vote_post
from app.infrastructure.database.community_repositories import (
    SqlCommentReportRepository,
    SqlCommentRepository,
    SqlModerationLogRepository,
    SqlPostReportRepository,
    SqlPostRepository,
    SqlPostVoteRepository,
)

router = APIRouter(prefix="/community", tags=["Comunidade"])


def _post_out(post: Post, viewer_id: str | None) -> PostOut:
    return PostOut(
        id=post.id,
        author_alias=public_author_alias(post.anonymous_id),
        is_mine=viewer_id == post.anonymous_id,
        content=post.content,
        political_actor_id=post.political_actor_id,
        theme_slug=post.theme_slug,
        score=post.score,
        created_at=post.created_at,
        removed=post.removed_at is not None,
        removed_by=post.removed_by,
        my_vote=post.my_vote,
        comment_count=post.comment_count,
        theme_name=post.theme_name,
    )


def _comment_out(comment: Comment, viewer_id: str | None) -> CommentOut:
    return CommentOut(
        id=comment.id,
        post_id=comment.post_id,
        author_alias=public_author_alias(comment.anonymous_id),
        is_mine=viewer_id == comment.anonymous_id,
        content=comment.content,
        created_at=comment.created_at,
        removed=comment.removed,
        removed_by=comment.removed_by,
    )


def _enrich_posts(post_repo: SqlPostRepository, posts: list[Post], viewer_id: str | None) -> list[Post]:
    # Existing injected repositories can continue returning entities with defaults.
    enrich = getattr(post_repo, "enrich", None)
    if enrich is None:
        return posts
    return list(enrich(posts, viewer_id))


@router.post("/posts", response_model=PostOut, status_code=status.HTTP_201_CREATED)
def create_post_endpoint(
    body: PostIn,
    x_farol_anonymous_id: str = Depends(require_anonymous_id),
    post_repo: SqlPostRepository = Depends(get_post_repo),
    log_repo: SqlModerationLogRepository = Depends(get_moderation_log_repo),
    moderation_client: ModerationPort = Depends(get_moderation_client),
) -> PostOut:
    try:
        post, result = moderate_and_create_post(
            post_repo, log_repo, moderation_client,
            x_farol_anonymous_id, body.content,
            body.political_actor_id, body.theme_slug,
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

    except ModerationUnavailable:
        raise HTTPException(
            status_code=503,
            detail="Serviço de moderação temporariamente indisponível.",
        )
    if post is None:
        raise HTTPException(status_code=422, detail=result.reason)
    return _post_out(_enrich_posts(post_repo, [post], x_farol_anonymous_id)[0], x_farol_anonymous_id)


@router.get("/posts", response_model=PostListResponse)
def list_posts_endpoint(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    political_actor_id: int | None = Query(default=None),
    theme_slug: str | None = Query(default=None),
    sort: Literal["score", "recent"] = Query(default="score"),
    viewer_id: str | None = Depends(optional_anonymous_id),
    post_repo: SqlPostRepository = Depends(get_post_repo),
) -> PostListResponse:
    posts, total = list_posts(
        post_repo, page=page, page_size=page_size,
        political_actor_id=political_actor_id, theme_slug=theme_slug,
        sort=sort,
    )
    return PostListResponse(
        posts=[_post_out(p, viewer_id) for p in _enrich_posts(post_repo, posts, viewer_id)],
        total_count=total, page=page, page_size=page_size,
        has_next=(page * page_size) < total,
    )


@router.get("/posts/{post_id}", response_model=PostDetailOut)
def get_post_endpoint(
    post_id: str,
    viewer_id: str | None = Depends(optional_anonymous_id),
    post_repo: SqlPostRepository = Depends(get_post_repo),
    comment_repo: SqlCommentRepository = Depends(get_comment_repo),
) -> PostDetailOut:
    result = get_post(post_repo, comment_repo, post_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    post, comments = result
    return PostDetailOut(
        post=_post_out(replace(_enrich_posts(post_repo, [post], viewer_id)[0], comment_count=len(comments)), viewer_id),
        comments=[_comment_out(c, viewer_id) for c in comments],
    )


@router.post("/posts/{post_id}/votes", response_model=PostOut)
def vote_post_endpoint(
    post_id: str,
    body: VoteIn,
    x_farol_anonymous_id: str = Depends(require_anonymous_id),
    post_repo: SqlPostRepository = Depends(get_post_repo),
    vote_repo: SqlPostVoteRepository = Depends(get_vote_repo),
) -> PostOut:
    try:
        updated = vote_post(post_repo, vote_repo, post_id, x_farol_anonymous_id, body.value)
    except PostRemovedError:
        raise HTTPException(status_code=410, detail="Este post foi removido.") from None
    if updated is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    return _post_out(_enrich_posts(post_repo, [updated], x_farol_anonymous_id)[0], x_farol_anonymous_id)


@router.post(
    "/posts/{post_id}/comments",
    response_model=CommentOut,
    status_code=status.HTTP_201_CREATED,
)
def create_comment_endpoint(
    post_id: str,
    body: CommentIn,
    x_farol_anonymous_id: str = Depends(require_anonymous_id),
    post_repo: SqlPostRepository = Depends(get_post_repo),
    comment_repo: SqlCommentRepository = Depends(get_comment_repo),
    log_repo: SqlModerationLogRepository = Depends(get_moderation_log_repo),
    moderation_client: ModerationPort = Depends(get_moderation_client),
) -> CommentOut:
    try:
        result = moderate_and_create_comment(
            post_repo, comment_repo, log_repo, moderation_client,
            post_id, x_farol_anonymous_id, body.content,
        )
    except CommentRateLimitExceeded as exc:
        raise HTTPException(
            status_code=429,
            detail="Você comentou demais nos últimos minutos. Tente novamente em breve.",
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from None
    except PostRemovedError:
        raise HTTPException(status_code=410, detail="Este post foi removido.") from None
    except ModerationUnavailable:
        raise HTTPException(
            status_code=503,
            detail="Serviço de moderação temporariamente indisponível.",
        ) from None
    if result is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    comment, decision = result
    if comment is None:
        raise HTTPException(status_code=422, detail=decision.reason)
    return _comment_out(comment, x_farol_anonymous_id)


@router.post(
    "/posts/{post_id}/reports",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Denuncia um post",
)
def report_post_endpoint(
    post_id: str,
    body: ReportIn,
    x_farol_anonymous_id: str = Depends(require_anonymous_id),
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
    x_farol_anonymous_id: str = Depends(require_anonymous_id),
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


@router.delete("/posts/{post_id}/comments/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_comment_endpoint(
    post_id: str,
    comment_id: str,
    x_farol_anonymous_id: str = Depends(require_anonymous_id),
    comment_repo: SqlCommentRepository = Depends(get_comment_repo),
) -> Response:
    try:
        exists = remove_own_comment(
            comment_repo, post_id=post_id, comment_id=comment_id,
            anonymous_id=x_farol_anonymous_id, now=datetime.now(timezone.utc),
        )
    except NotTheCommentAuthorError:
        raise HTTPException(status_code=403, detail="Só o autor pode remover este comentário.") from None
    if not exists:
        raise HTTPException(status_code=404, detail="Comentário não encontrado.")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/posts/{post_id}/comments/{comment_id}/reports", status_code=status.HTTP_204_NO_CONTENT)
def report_comment_endpoint(
    post_id: str,
    comment_id: str,
    body: ReportIn,
    x_farol_anonymous_id: str = Depends(require_anonymous_id),
    post_repo: SqlPostRepository = Depends(get_post_repo),
    comment_repo: SqlCommentRepository = Depends(get_comment_repo),
    report_repo: SqlCommentReportRepository = Depends(get_comment_report_repo),
    log_repo: SqlModerationLogRepository = Depends(get_moderation_log_repo),
    moderation_client: ModerationPort = Depends(get_moderation_client),
) -> Response:
    exists = report_comment(
        report_repo=report_repo, comment_repo=comment_repo, post_repo=post_repo,
        log_repo=log_repo, moderation_client=moderation_client,
        post_id=post_id, comment_id=comment_id, anonymous_id=x_farol_anonymous_id,
        reason=body.reason, detail=body.detail, now=datetime.now(timezone.utc),
    )
    if not exists:
        raise HTTPException(status_code=404, detail="Comentário não encontrado.")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
