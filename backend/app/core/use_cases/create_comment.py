import uuid
from datetime import datetime, timezone

from app.core.entities.community import Comment
from app.core.use_cases.interfaces import CommentRepository, PostRepository


def create_comment(
    post_repo: PostRepository,
    comment_repo: CommentRepository,
    post_id: str,
    anonymous_id: str,
    content: str,
) -> Comment | None:
    if post_repo.get_by_id(post_id) is None:
        return None
    comment = Comment(
        id=str(uuid.uuid4()), post_id=post_id, anonymous_id=anonymous_id,
        content=content, created_at=datetime.now(timezone.utc),
    )
    return comment_repo.create(comment)
