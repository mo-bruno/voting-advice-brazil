from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from threading import Event, local

import pytest
from sqlalchemy import create_engine, event, func, select
from sqlalchemy.orm import Session

from app.core.entities.community import Comment, Post
from app.core.use_cases.comment_rate_limit import CommentRateLimitExceeded
from app.core.use_cases.create_comment import moderate_and_create_comment
from app.infrastructure.database.community_repositories import (
    SqlCommentRepository,
    SqlModerationLogRepository,
    SqlPostRepository,
)
from app.infrastructure.database.models import Base, CommentModel
from app.infrastructure.llm.moderation_client import FakeModerationClient
from tests.conftest import ANONYMOUS_OWNER


@pytest.mark.parametrize("previous_admission", [False, True])
def test_overlapping_acceptances_compete_for_one_remaining_slot(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, previous_admission: bool
) -> None:
    """Both old counts see nine; atomic admission instead blocks the second writer."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'admission.db'}",
        connect_args={"check_same_thread": False, "timeout": 10},
    )
    Base.metadata.create_all(engine)
    now = datetime.now(timezone.utc)
    with Session(engine) as db:
        post_repo = SqlPostRepository(db)
        for post_id in ("p1", "p2"):
            post_repo.create(Post(
                id=post_id, anonymous_id=ANONYMOUS_OWNER, content="Política",
                political_actor_id=None, theme_slug=None, score=0, created_at=now,
            ))
        if previous_admission:
            assert moderate_and_create_comment(
                post_repo, SqlCommentRepository(db), SqlModerationLogRepository(db),
                FakeModerationClient(), "p1", ANONYMOUS_OWNER, "Primeiro",
            ) is not None
        for index in range(8 if previous_admission else 9):
            SqlCommentRepository(db).create(Comment(
                id=str(index), post_id="p1", anonymous_id=ANONYMOUS_OWNER,
                content="Anterior", created_at=now,
            ))

    first_counted = Event()
    second_attempted = Event()
    first_committed = Event()
    contender = local()
    real_count = SqlCommentRepository.count_by_author_since

    def controlled_count(repo: SqlCommentRepository, author: str, since: datetime) -> int:
        count = real_count(repo, author, since)
        if contender.index == 0:
            first_counted.set()
            assert second_attempted.wait(10), "second request never reached admission"
        else:
            # In the old path, keep its real count of nine until the first commit.
            second_attempted.set()
            assert first_committed.wait(10), "first admission did not commit"
        return count

    def observe_commit(session: Session) -> None:
        if getattr(contender, "index", None) == 0:
            first_committed.set()

    def observe_lock_attempt(connection, cursor, statement, parameters, context, executemany):
        if getattr(contender, "index", None) == 1 and "comment_admission_locks" in statement:
            # Fires before the DB call, so the first can commit while this blocks.
            second_attempted.set()

    monkeypatch.setattr(SqlCommentRepository, "count_by_author_since", controlled_count)
    event.listen(engine, "before_cursor_execute", observe_lock_attempt)
    event.listen(Session, "after_commit", observe_commit)

    def submit(index: int) -> str:
        contender.index = index
        with Session(engine) as db:
            try:
                result = moderate_and_create_comment(
                    SqlPostRepository(db), SqlCommentRepository(db),
                    SqlModerationLogRepository(db), FakeModerationClient(),
                    f"p{index + 1}", ANONYMOUS_OWNER, "Disputando a última vaga",
                )
            except CommentRateLimitExceeded as exc:
                assert exc.retry_after_seconds == 600
                return "CommentRateLimitExceeded"
            assert result is not None and result[0] is not None
            return "accepted"

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(submit, 0)
            assert first_counted.wait(10), "first request never counted"
            second = pool.submit(submit, 1)
            outcomes = [first.result(timeout=15), second.result(timeout=15)]
        with Session(engine) as db:
            assert db.scalar(select(func.count()).select_from(CommentModel)) == 10
        assert outcomes == ["accepted", "CommentRateLimitExceeded"]
    finally:
        event.remove(engine, "before_cursor_execute", observe_lock_attempt)
        event.remove(Session, "after_commit", observe_commit)
        engine.dispose()
