from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.entities.community import Comment, Post, PostVote
from app.infrastructure.database.community_repositories import (
    SqlCommentRepository,
    SqlModerationLogRepository,
    SqlPostRepository,
    SqlPostVoteRepository,
)
from app.infrastructure.database.models import Base


@pytest.fixture()
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    with Session() as session:
        yield session


def _make_post(**kwargs) -> Post:
    defaults = dict(
        id="post-1",
        anonymous_id="anon-1",
        content="Texto político válido",
        political_actor_id=None,
        theme_slug=None,
        score=0,
        created_at=datetime.now(timezone.utc),
    )
    defaults.update(kwargs)
    return Post(**defaults)


def test_post_create_and_get(db):
    repo = SqlPostRepository(db)
    post = _make_post()
    saved = repo.create(post)
    assert saved.id == "post-1"
    fetched = repo.get_by_id("post-1")
    assert fetched is not None
    assert fetched.content == "Texto político válido"


def test_post_get_returns_none_for_unknown(db):
    repo = SqlPostRepository(db)
    assert repo.get_by_id("nope") is None


def test_post_list_pagination(db):
    repo = SqlPostRepository(db)
    for i in range(3):
        repo.create(_make_post(id=f"post-{i}", anonymous_id="anon-1"))
    posts, total = repo.list(page=1, page_size=2)
    assert total == 3
    assert len(posts) == 2


def test_post_update_score(db):
    repo = SqlPostRepository(db)
    repo.create(_make_post())
    repo.update_score("post-1", 5)
    fetched = repo.get_by_id("post-1")
    assert fetched.score == 5


def test_comment_create_and_list(db):
    post_repo = SqlPostRepository(db)
    post_repo.create(_make_post())
    comment_repo = SqlCommentRepository(db)
    comment = Comment(
        id="c-1",
        post_id="post-1",
        anonymous_id="anon-1",
        content="Comentário",
        created_at=datetime.now(timezone.utc),
    )
    saved = comment_repo.create(comment)
    assert saved.id == "c-1"
    comments = comment_repo.list_by_post("post-1")
    assert len(comments) == 1


def test_vote_upsert_returns_score(db):
    post_repo = SqlPostRepository(db)
    post_repo.create(_make_post())
    vote_repo = SqlPostVoteRepository(db)
    score = vote_repo.upsert(PostVote(post_id="post-1", anonymous_id="anon-1", value=1))
    assert score == 1


def test_vote_upsert_replaces_previous(db):
    post_repo = SqlPostRepository(db)
    post_repo.create(_make_post())
    vote_repo = SqlPostVoteRepository(db)
    vote_repo.upsert(PostVote(post_id="post-1", anonymous_id="anon-1", value=1))
    score = vote_repo.upsert(
        PostVote(post_id="post-1", anonymous_id="anon-1", value=-1)
    )
    assert score == -1


def test_vote_two_users(db):
    post_repo = SqlPostRepository(db)
    post_repo.create(_make_post())
    vote_repo = SqlPostVoteRepository(db)
    vote_repo.upsert(PostVote(post_id="post-1", anonymous_id="anon-1", value=1))
    score = vote_repo.upsert(PostVote(post_id="post-1", anonymous_id="anon-2", value=1))
    assert score == 2


def test_moderation_log_record(db):
    log_repo = SqlModerationLogRepository(db)
    log_repo.record(
        post_id="post-1",
        anonymous_id="anon-1",
        content_hash="abc123",
        approved=True,
        reason=None,
        model_used="fake",
    )
