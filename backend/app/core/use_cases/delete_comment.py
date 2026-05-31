from app.core.use_cases.interfaces import CommentRepository


def delete_comment(
    comment_repo: CommentRepository,
    comment_id: str,
    anonymous_id: str,
) -> bool | None:
    """Returns True on success, False if not owner, None if not found."""
    comment = comment_repo.get_by_id(comment_id)
    if comment is None:
        return None
    if comment.anonymous_id != anonymous_id:
        return False
    comment_repo.delete(comment_id)
    return True
