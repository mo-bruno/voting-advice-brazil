from app.core.entities.community import Post, PostVote
from app.core.use_cases.interfaces import PostRepository, PostVoteRepository


def vote_post(
    post_repo: PostRepository,
    vote_repo: PostVoteRepository,
    post_id: str,
    anonymous_id: str,
    value: int,
) -> Post | None:
    if post_repo.get_by_id(post_id) is None:
        return None
    new_score = vote_repo.upsert(PostVote(post_id=post_id, anonymous_id=anonymous_id, value=value))
    post_repo.update_score(post_id, new_score)
    return post_repo.get_by_id(post_id)
