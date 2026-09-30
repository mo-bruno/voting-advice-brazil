from dataclasses import replace

from app.core.entities.community import Post, PostVote
from app.core.use_cases.community_errors import PostRemovedError
from app.core.use_cases.interfaces import PostRepository, PostVoteRepository


def vote_post(
    post_repo: PostRepository,
    vote_repo: PostVoteRepository,
    post_id: str,
    anonymous_id: str,
    value: int,
) -> Post | None:
    post = post_repo.get_by_id(post_id)
    if post is None:
        return None
    if post.removed_at is not None:
        raise PostRemovedError()
    new_score = vote_repo.upsert(PostVote(post_id=post_id, anonymous_id=anonymous_id, value=value))
    if not getattr(vote_repo, "updates_post_score_atomically", False):
        post_repo.update_score(post_id, new_score)
    return replace(post, score=new_score)
