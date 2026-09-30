import hashlib
import uuid
from datetime import datetime, timezone

from app.core.entities.community import ModerationResult, Post
from app.core.use_cases.interfaces import (
    ModerationLogRepository,
    ModerationPort,
    PostRepository,
)
from app.core.use_cases.post_rate_limit import (
    MAX_POSTS_PER_WINDOW,
    WINDOW,
    PostRateLimitExceeded,
    check_post_rate_limit,
)


def moderate_and_create_post(
    post_repo: PostRepository,
    log_repo: ModerationLogRepository,
    moderation_client: ModerationPort,
    anonymous_id: str,
    content: str,
    political_actor_id: int | None = None,
    theme_slug: str | None = None,
) -> tuple[Post | None, ModerationResult]:
    # Avoid a provider call for an already full quota. The SQL admission repeats
    # the count under its lock after moderation, closing concurrent-publication races.
    counter = getattr(post_repo, "count_by_author_since", None)
    if counter is not None:
        check_post_rate_limit(counter(anonymous_id, datetime.now(timezone.utc) - WINDOW))
    result = moderation_client.moderate(content)
    content_hash = hashlib.sha256(content.encode()).hexdigest()

    if not result.approved:
        log_repo.record(
            post_id=None, anonymous_id=anonymous_id, content_hash=content_hash,
            approved=False, reason=result.reason, model_used=result.model_used,
        )
        return None, result

    post = Post(
        id=str(uuid.uuid4()), anonymous_id=anonymous_id, content=content,
        political_actor_id=political_actor_id, theme_slug=theme_slug,
        score=0, created_at=datetime.now(timezone.utc),
    )
    admit = getattr(post_repo, "create_with_rate_limit", None)
    saved = (admit(post, post.created_at - WINDOW, MAX_POSTS_PER_WINDOW)
             if admit is not None else post_repo.create(post))
    if saved is None:
        raise PostRateLimitExceeded(int(WINDOW.total_seconds()))
    log_repo.record(
        post_id=saved.id, anonymous_id=anonymous_id, content_hash=content_hash,
        approved=True, reason=None, model_used=result.model_used,
    )
    return saved, result
