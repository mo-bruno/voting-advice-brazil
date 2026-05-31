from app.core.entities.community import Comment, Post
from app.core.use_cases.interfaces import CommentRepository, PostRepository


def get_post(
    post_repo: PostRepository,
    comment_repo: CommentRepository,
    post_id: str,
) -> tuple[Post, list[Comment]] | None:
    post = post_repo.get_by_id(post_id)
    if post is None:
        return None
    return post, comment_repo.list_by_post(post_id)
