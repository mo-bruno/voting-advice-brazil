from app.core.entities.community import Comment
from app.core.use_cases.interfaces import CommentRepository


def edit_comment(
    comment_repo: CommentRepository,
    comment_id: str,
    anonymous_id: str,
    new_content: str,
) -> Comment | bool | None:
    """Returns updated Comment on success, False if not owner, None if not found."""
    comment = comment_repo.get_by_id(comment_id)
    if comment is None:
        return None
    if comment.anonymous_id != anonymous_id:
        return False
    return comment_repo.update_content(comment_id, new_content)
