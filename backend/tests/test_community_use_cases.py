from datetime import datetime, timezone

from app.core.entities.community import Comment, Post, PostVote
from app.infrastructure.llm.moderation_client import FakeModerationClient


class FakePostRepository:
    def __init__(self):
        self._store: dict[str, Post] = {}

    def create(self, post: Post) -> Post:
        self._store[post.id] = post
        return post

    def get_by_id(self, post_id: str) -> Post | None:
        return self._store.get(post_id)

    def list(self, page=1, page_size=20, political_actor_id=None, theme_slug=None):
        posts = list(self._store.values())
        return posts, len(posts)

    def update_score(self, post_id: str, new_score: int) -> None:
        p = self._store[post_id]
        self._store[post_id] = Post(
            id=p.id, anonymous_id=p.anonymous_id, content=p.content,
            political_actor_id=p.political_actor_id, theme_slug=p.theme_slug,
            score=new_score, created_at=p.created_at,
        )


class FakeCommentRepository:
    def __init__(self):
        self._store: list[Comment] = []

    def create(self, comment: Comment) -> Comment:
        self._store.append(comment)
        return comment

    def list_by_post(self, post_id: str) -> list[Comment]:
        return [c for c in self._store if c.post_id == post_id]


class FakeVoteRepository:
    def __init__(self):
        self._store: dict[tuple, PostVote] = {}

    def upsert(self, vote: PostVote) -> int:
        self._store[(vote.post_id, vote.anonymous_id)] = vote
        return sum(v.value for v in self._store.values() if v.post_id == vote.post_id)

    def get(self, post_id: str, anonymous_id: str) -> PostVote | None:
        return self._store.get((post_id, anonymous_id))


class FakeModerationLogRepository:
    def __init__(self):
        self.records: list[dict] = []

    def record(self, post_id, anonymous_id, content_hash, approved, reason, model_used):
        self.records.append(dict(
            post_id=post_id, anonymous_id=anonymous_id,
            approved=approved, reason=reason,
        ))


def _now():
    return datetime.now(timezone.utc)

def _post(post_id="p1"):
    return Post(id=post_id, anonymous_id="a", content="x",
                political_actor_id=None, theme_slug=None, score=0, created_at=_now())


# ── moderate_and_create_post ──

def test_approved_post_is_saved():
    from app.core.use_cases.moderate_and_create_post import moderate_and_create_post
    post_repo = FakePostRepository()
    log_repo = FakeModerationLogRepository()
    post, result = moderate_and_create_post(
        post_repo, log_repo, FakeModerationClient(approved=True),
        anonymous_id="anon-1", content="PT votou contra a PEC",
    )
    assert post is not None
    assert result.approved is True
    assert log_repo.records[0]["approved"] is True
    assert log_repo.records[0]["post_id"] == post.id


def test_rejected_post_not_saved():
    from app.core.use_cases.moderate_and_create_post import moderate_and_create_post
    post_repo = FakePostRepository()
    log_repo = FakeModerationLogRepository()
    post, result = moderate_and_create_post(
        post_repo, log_repo, FakeModerationClient(approved=False, reason="Fora do tema"),
        anonymous_id="anon-1", content="Receita de bolo",
    )
    assert post is None
    assert result.reason == "Fora do tema"
    assert log_repo.records[0]["post_id"] is None


# ── list_posts ──

def test_list_posts_returns_all():
    from app.core.use_cases.list_posts import list_posts
    repo = FakePostRepository()
    repo.create(_post())
    posts, total = list_posts(repo)
    assert total == 1 and posts[0].id == "p1"


# ── get_post ──

def test_get_post_with_comments():
    from app.core.use_cases.get_post import get_post
    post_repo = FakePostRepository()
    comment_repo = FakeCommentRepository()
    post_repo.create(_post())
    comment_repo.create(Comment(id="c1", post_id="p1", anonymous_id="a",
                                content="ótimo", created_at=_now()))
    result = get_post(post_repo, comment_repo, "p1")
    assert result is not None
    post, comments = result
    assert post.id == "p1" and len(comments) == 1


def test_get_post_returns_none_if_missing():
    from app.core.use_cases.get_post import get_post
    assert get_post(FakePostRepository(), FakeCommentRepository(), "nope") is None


# ── create_comment ──

def test_create_comment_saved():
    from app.core.use_cases.create_comment import create_comment
    post_repo = FakePostRepository()
    comment_repo = FakeCommentRepository()
    post_repo.create(_post())
    comment = create_comment(post_repo, comment_repo, "p1", "anon-2", "boa observação")
    assert comment is not None and comment.content == "boa observação"


def test_create_comment_returns_none_if_post_missing():
    from app.core.use_cases.create_comment import create_comment
    assert create_comment(FakePostRepository(), FakeCommentRepository(), "nope", "anon", "x") is None


# ── vote_post ──

def test_upvote_increases_score():
    from app.core.use_cases.vote_post import vote_post
    post_repo = FakePostRepository()
    post_repo.create(_post())
    updated = vote_post(post_repo, FakeVoteRepository(), "p1", "anon-1", 1)
    assert updated is not None and updated.score == 1


def test_vote_replaces_previous():
    from app.core.use_cases.vote_post import vote_post
    post_repo = FakePostRepository()
    vote_repo = FakeVoteRepository()
    post_repo.create(_post())
    vote_post(post_repo, vote_repo, "p1", "anon-1", 1)
    updated = vote_post(post_repo, vote_repo, "p1", "anon-1", -1)
    assert updated.score == -1


def test_vote_returns_none_if_post_missing():
    from app.core.use_cases.vote_post import vote_post
    assert vote_post(FakePostRepository(), FakeVoteRepository(), "nope", "anon", 1) is None
