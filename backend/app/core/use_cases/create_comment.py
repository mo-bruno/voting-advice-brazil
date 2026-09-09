import hashlib
import uuid
from datetime import datetime, timedelta, timezone

from app.core.entities.community import Comment, ModerationResult
from app.core.use_cases.comment_rate_limit import (
    WINDOW_MINUTES,
    check_comment_rate_limit,
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

    result = moderation_client.moderate(content)
    content_hash = hashlib.sha256(content.encode()).hexdigest()
    if not result.approved:
        log_repo.record(
            post_id=post_id, anonymous_id=anonymous_id, content_hash=content_hash,
            approved=False, reason=result.reason, model_used=result.model_used,
        )
        return None, result

    now = datetime.now(timezone.utc)
    check_comment_rate_limit(comment_repo.count_by_author_since(
        anonymous_id, now - timedelta(minutes=WINDOW_MINUTES),
    ))
    comment = Comment(
        id=str(uuid.uuid4()), post_id=post_id, anonymous_id=anonymous_id,
        content=content, created_at=now,
    )
    saved = comment_repo.create(comment)
    log_repo.record(
        post_id=post_id, anonymous_id=anonymous_id, content_hash=content_hash,
        approved=True, reason=None, model_used=result.model_used,
    )
    return saved, result
