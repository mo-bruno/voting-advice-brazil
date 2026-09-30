from datetime import datetime

from app.core.use_cases.interfaces import CommentRepository


class NotTheCommentAuthorError(PermissionError):
    """Only the comment's author may request its removal."""


def remove_own_comment(
    comment_repo: CommentRepository,
    *,
    post_id: str,
    comment_id: str,
    anonymous_id: str,
    now: datetime,
) -> bool:
    comment = comment_repo.get_by_id(comment_id)
    if comment is None or comment.post_id != post_id:
        return False
    if comment.anonymous_id != anonymous_id:
        raise NotTheCommentAuthorError(comment_id)
    if not comment.removed:
        comment_repo.mark_removed(comment_id, removed_by="author", now=now)
    return True
