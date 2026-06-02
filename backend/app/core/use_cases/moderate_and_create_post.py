import hashlib
import uuid
from datetime import datetime, timezone

from app.core.entities.community import ModerationResult, Post
from app.core.use_cases.interfaces import ModerationLogRepository, PostRepository
from app.infrastructure.llm.moderation_client import ModerationPort


def moderate_and_create_post(
    post_repo: PostRepository,
    log_repo: ModerationLogRepository,
    moderation_client: ModerationPort,
    anonymous_id: str,
    content: str,
    political_actor_id: int | None = None,
    theme_slug: str | None = None,
) -> tuple[Post | None, ModerationResult]:
    result = moderation_client.moderate(content)
    content_hash = hashlib.sha256(content.encode()).hexdigest()

    if not result.approved:
        log_repo.record(
            post_id=None,
            anonymous_id=anonymous_id,
            content_hash=content_hash,
            approved=False,
            reason=result.reason,
            model_used=result.model_used,
        )
        return None, result

    post = Post(
        id=str(uuid.uuid4()),
        anonymous_id=anonymous_id,
        content=content,
        political_actor_id=political_actor_id,
        theme_slug=theme_slug,
        score=0,
        created_at=datetime.now(timezone.utc),
    )
    saved = post_repo.create(post)
    log_repo.record(
        post_id=saved.id,
        anonymous_id=anonymous_id,
        content_hash=content_hash,
        approved=True,
        reason=None,
        model_used=result.model_used,
    )
    return saved, result
