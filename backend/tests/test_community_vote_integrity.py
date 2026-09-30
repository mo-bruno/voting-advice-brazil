import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from threading import Barrier
from types import SimpleNamespace

import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Session

from app.core.entities.community import Comment, CommentReport, Post, PostVote
from app.core.use_cases.community_errors import PostRemovedError
from app.core.use_cases.create_comment import moderate_and_create_comment
from app.core.use_cases.vote_post import vote_post
from app.infrastructure.database.community_repositories import (
    SqlCommentReportRepository,
    SqlCommentRepository,
    SqlModerationLogRepository,
    SqlPostRepository,
    SqlPostVoteRepository,
)
from app.infrastructure.database.models import (
    Base,
    CommentModel,
    ModerationLogModel,
    PostModel,
    PostVoteModel,
)
from app.infrastructure.llm.moderation_client import FakeModerationClient


def test_vote_sql_compiles_with_real_postgresql_dialect_without_a_server():
    dialect = postgresql.dialect()
    statements = []

    def compile_statement(statement):
        statements.append(str(statement.compile(dialect=dialect)))
        return SimpleNamespace(one_or_none=lambda: (None,))

    session = SimpleNamespace(
        get_bind=lambda: SimpleNamespace(dialect=dialect),
        execute=compile_statement,
        scalar=lambda statement: 1,
        commit=lambda: None,
        rollback=lambda: None,
    )
    assert SqlPostVoteRepository(session).upsert(PostVote("p1", "a", 1)) == 1
    assert any(
        "INSERT INTO post_votes" in sql
        and "ON CONFLICT (post_id, anonymous_id) DO UPDATE" in sql
        for sql in statements
    )
    assert any("FOR UPDATE" in sql for sql in statements)
    assert any("UPDATE posts" in sql for sql in statements)


@pytest.fixture(params=["sqlite", "postgresql"])
def vote_engine(request, tmp_path):
    if request.param == "postgresql":
        url = os.environ.get("COMMUNITY_TEST_POSTGRES_URL")
        if not url:
            pytest.skip("Set COMMUNITY_TEST_POSTGRES_URL for an isolated PostgreSQL DB")
        engine = create_engine(url)
    else:
        engine = create_engine(
            f"sqlite:///{tmp_path / 'votes.db'}", connect_args={"timeout": 10}
        )
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        SqlPostRepository(db).create(
            Post(
                id="vote-integrity-post",
                anonymous_id="author",
                content="Debate político",
                political_actor_id=None,
                theme_slug=None,
                score=0,
                created_at=datetime.now(timezone.utc),
            )
        )
    yield engine
    with Session(engine) as db:
        db.query(ModerationLogModel).filter_by(post_id="vote-integrity-post").delete()
        db.query(PostVoteModel).filter_by(post_id="vote-integrity-post").delete()
        db.query(PostModel).filter_by(id="vote-integrity-post").delete()
        db.commit()
    engine.dispose()


def test_vote_upsert_updates_cached_score_in_same_transaction(vote_engine):
    with Session(vote_engine) as db:
        repo = SqlPostVoteRepository(db)
        assert repo.upsert(PostVote("vote-integrity-post", "a", 1)) == 1
        assert repo.upsert(PostVote("vote-integrity-post", "b", 1)) == 2
        assert repo.upsert(PostVote("vote-integrity-post", "a", -1)) == 0
        assert db.get(PostModel, "vote-integrity-post").score == 0
        assert repo.upsert(PostVote("vote-integrity-post", "a", 0)) == 1
        assert db.get(PostModel, "vote-integrity-post").score == 1


@pytest.mark.parametrize("same_user", [False, True])
def test_overlapping_votes_keep_score_equal_to_persisted_vote_sum(
    vote_engine, same_user
):
    barrier = Barrier(2)

    def submit(index):
        with Session(vote_engine) as db:
            barrier.wait(timeout=10)
            return vote_post(
                SqlPostRepository(db),
                SqlPostVoteRepository(db),
                "vote-integrity-post",
                "same" if same_user else f"user-{index}",
                1 if index == 0 else -1,
            )

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(submit, index) for index in range(2)]
        assert all(future.result(timeout=15) is not None for future in futures)
    with Session(vote_engine) as db:
        votes = db.scalar(
            select(func.sum(PostVoteModel.value)).where(
                PostVoteModel.post_id == "vote-integrity-post"
            )
        )
        assert db.get(PostModel, "vote-integrity-post").score == votes
        assert db.scalar(
            select(func.count())
            .select_from(PostVoteModel)
            .where(PostVoteModel.post_id == "vote-integrity-post")
        ) == (1 if same_user else 2)


def test_comment_reports_and_tombstone_metadata_round_trip(vote_engine):
    now = datetime.now(timezone.utc)
    with Session(vote_engine) as db:
        comments = SqlCommentRepository(db)
        reports = SqlCommentReportRepository(db)
        comments.create(
            Comment(
                "reported-vote-comment",
                "vote-integrity-post",
                "author",
                "Concordo.",
                now,
            )
        )
        for reporter in ("a", "a", "b", "c"):
            reports.upsert(
                CommentReport("reported-vote-comment", reporter, "spam", None, now)
            )
        assert reports.count_distinct_reporters("reported-vote-comment") == 3
        assert reports.reasons_for_comment("reported-vote-comment") == [
            "spam",
            "spam",
            "spam",
        ]
        comments.mark_removed("reported-vote-comment", "moderation", now)
        comments.mark_removed("reported-vote-comment", "author", now)
        tombstone = comments.get_by_id("reported-vote-comment")
        assert tombstone.content == ""
        assert tombstone.removed_by == "moderation"
        assert tombstone.removed is True
        assert comments.count_by_author_since("author", now) == 1
        posts = SqlPostRepository(db)
        projected = posts.enrich([posts.get_by_id("vote-integrity-post")], None)[0]
        assert projected.comment_count == 1
        assert projected.my_vote == 0
        assert projected.theme_name is None


def test_comment_admission_rechecks_parent_removed_during_moderation(vote_engine):
    class RemoveParentDuringModeration(FakeModerationClient):
        def moderate_comment(self, content, parent_content, report_reasons=None):
            with Session(vote_engine) as remover:
                SqlPostRepository(remover).mark_removed(
                    "vote-integrity-post",
                    "author",
                    datetime.now(timezone.utc),
                )
            return super().moderate_comment(content, parent_content, report_reasons)

    with Session(vote_engine) as db:
        with pytest.raises(PostRemovedError):
            moderate_and_create_comment(
                SqlPostRepository(db),
                SqlCommentRepository(db),
                SqlModerationLogRepository(db),
                RemoveParentDuringModeration(),
                "vote-integrity-post",
                "late-commenter",
                "Concordo.",
            )
        assert (
            db.scalar(
                select(func.count())
                .select_from(CommentModel)
                .where(CommentModel.post_id == "vote-integrity-post")
            )
            == 0
        )
        assert (
            SqlCommentRepository(db).count_by_author_since(
                "late-commenter",
                datetime.now(timezone.utc).replace(hour=0),
            )
            == 0
        )
        assert (
            db.scalar(
                select(func.count())
                .select_from(ModerationLogModel)
                .where(ModerationLogModel.post_id == "vote-integrity-post")
            )
            == 0
        )
