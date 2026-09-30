import hashlib
import uuid
from datetime import datetime, timedelta, timezone

from app.core.entities.community import Comment, ModerationResult
from app.core.use_cases.comment_rate_limit import (
    MAX_COMMENTS_PER_WINDOW,
    WINDOW_MINUTES,
    CommentRateLimitExceeded,
)
from app.core.use_cases.community_errors import PostRemovedError
from app.core.use_cases.interfaces import (
    CommentRepository,
    ModerationLogRepository,
    ModerationPort,
    PostRepository,
)


def moderate_and_create_comment(
    post_repo: PostRepository,
    comment_repo: CommentRepository,
    log_repo: ModerationLogRepository,
    moderation_client: ModerationPort,
    post_id: str,
    anonymous_id: str,
    content: str,
) -> tuple[Comment | None, ModerationResult] | None:
    post = post_repo.get_by_id(post_id)
    if post is None:
        return None
    if post.removed_at is not None:
        raise PostRemovedError()

    result = moderation_client.moderate_comment(content, post.content)
    content_hash = hashlib.sha256(content.encode()).hexdigest()
    if not result.approved:
        log_repo.record(
            post_id=post_id, anonymous_id=anonymous_id, content_hash=content_hash,
            approved=False, reason=result.reason, model_used=result.model_used,
        )
        return None, result

    now = datetime.now(timezone.utc)
    comment = Comment(
        id=str(uuid.uuid4()), post_id=post_id, anonymous_id=anonymous_id,
        content=content, created_at=now,
    )
    saved = comment_repo.create_with_rate_limit(
        comment,
        since=comment.created_at - timedelta(minutes=WINDOW_MINUTES),
        max_comments=MAX_COMMENTS_PER_WINDOW,
    )
    if saved is None:
        raise CommentRateLimitExceeded()
    log_repo.record(
        post_id=post_id, anonymous_id=anonymous_id, content_hash=content_hash,
        approved=True, reason=None, model_used=result.model_used,
    )
    return saved, result
