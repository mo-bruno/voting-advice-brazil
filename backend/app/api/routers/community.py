from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.api.deps import (
    get_comment_repo,
    get_moderation_client,
    get_moderation_log_repo,
    get_post_repo,
    get_vote_repo,
)
from app.api.schemas.community import (
    CommentIn,
    CommentOut,
    PostDetailOut,
    PostIn,
    PostListResponse,
    PostOut,
    VoteIn,
)
from app.core.use_cases.create_comment import create_comment
from app.core.use_cases.get_post import get_post
from app.core.use_cases.list_posts import list_posts
from app.core.use_cases.moderate_and_create_post import moderate_and_create_post
from app.core.use_cases.vote_post import vote_post
from app.infrastructure.llm.moderation_client import ModerationUnavailable

router = APIRouter(prefix="/community", tags=["Comunidade"])
AnonymousHeader = Annotated[str, Header(min_length=1, max_length=64)]


def _post_out(post) -> PostOut:
    return PostOut(
        id=post.id,
        anonymous_id=post.anonymous_id,
        content=post.content,
        political_actor_id=post.political_actor_id,
        theme_slug=post.theme_slug,
        score=post.score,
        created_at=post.created_at,
    )


def _comment_out(comment) -> CommentOut:
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
    post_repo=Depends(get_post_repo),
    log_repo=Depends(get_moderation_log_repo),
    moderation_client=Depends(get_moderation_client),
) -> PostOut:
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
    post_repo=Depends(get_post_repo),
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
    post_repo=Depends(get_post_repo),
    comment_repo=Depends(get_comment_repo),
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
    post_repo=Depends(get_post_repo),
    vote_repo=Depends(get_vote_repo),
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
    post_repo=Depends(get_post_repo),
    comment_repo=Depends(get_comment_repo),
) -> CommentOut:
    comment = create_comment(post_repo, comment_repo, post_id, x_farol_anonymous_id, body.content)
    if comment is None:
        raise HTTPException(status_code=404, detail="Post não encontrado.")
    return _comment_out(comment)
