from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from threading import Barrier
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_moderation_client
from app.core.entities.community import Post, PostReport
from app.infrastructure.database.community_repositories import (
    SqlPostReportRepository,
    SqlPostRepository,
)
from app.infrastructure.database.models import (
    ModerationLogModel,
    PostModel,
    PostReportModel,
)
from app.infrastructure.llm.moderation_client import FakeModerationClient
from app.main import app
from tests.test_community_vote_integrity import vote_engine as vote_engine


def test_overlapping_post_publications_compete_for_last_author_slot(vote_engine):
    author = str(uuid4())
    now = datetime.now(timezone.utc)
    barrier = Barrier(2)

    class SimultaneousApproval(FakeModerationClient):
        def moderate(self, content, report_reasons=None):
            barrier.wait(timeout=10)
            return super().moderate(content, report_reasons)

    with Session(vote_engine) as db:
        repo = SqlPostRepository(db)
        for index in range(4):
            post_id = str(uuid4())
            repo.create(Post(post_id, author, "Anterior", None, None, 0, now))
            if index == 0:
                repo.mark_removed(post_id, "author", now)

    def database():
        with Session(vote_engine) as db:
            yield db

    app.dependency_overrides[get_db] = database
    app.dependency_overrides[get_moderation_client] = SimultaneousApproval
    try:
        with TestClient(app) as client:

            def publish(index):
                return client.post(
                    "/api/v1/community/posts",
                    headers={"X-Farol-Anonymous-Id": author},
                    json={"content": f"Debate político {index}"},
                )

            with ThreadPoolExecutor(max_workers=2) as pool:
                responses = list(pool.map(publish, range(2)))
        assert sorted(response.status_code for response in responses) == [201, 429]
        limited = next(
            response for response in responses if response.status_code == 429
        )
        assert limited.headers["Retry-After"] == "600"
        with Session(vote_engine) as db:
            assert (
                SqlPostRepository(db).count_by_author_since(
                    author, now - timedelta(minutes=10)
                )
                == 5
            )
            assert (
                db.scalar(
                    select(func.count())
                    .select_from(ModerationLogModel)
                    .where(
                        ModerationLogModel.anonymous_id == author,
                    )
                )
                == 1
            )
    finally:
        app.dependency_overrides.clear()
        with Session(vote_engine) as db:
            db.query(ModerationLogModel).filter_by(anonymous_id=author).delete()
            db.query(PostModel).filter_by(anonymous_id=author).delete()
            db.commit()


def test_post_tombstone_keeps_first_removal_reason(vote_engine):
    with Session(vote_engine) as db:
        repo = SqlPostRepository(db)
        now = datetime.now(timezone.utc)
        repo.mark_removed("vote-integrity-post", "author", now)
        repo.mark_removed(
            "vote-integrity-post", "moderation", now + timedelta(seconds=1)
        )
        post = repo.get_by_id("vote-integrity-post")
        assert post.removed_by == "author"
        assert post.removed_at.replace(tzinfo=timezone.utc) == now
        assert post.content == ""


def test_same_reporter_concurrent_post_reports_are_deduplicated(
    vote_engine, monkeypatch
):
    start = Barrier(2)
    absence = Barrier(2)
    original_get = Session.get

    def overlap_missing_report(self, entity, ident, *args, **kwargs):
        result = original_get(self, entity, ident, *args, **kwargs)
        if entity is PostReportModel and result is None:
            absence.wait(timeout=10)
        return result

    monkeypatch.setattr(Session, "get", overlap_missing_report)

    def report(index):
        with Session(vote_engine) as db:
            start.wait(timeout=10)
            SqlPostReportRepository(db).upsert(
                PostReport(
                    "vote-integrity-post",
                    "same-reporter",
                    "spam",
                    None,
                    datetime.now(timezone.utc),
                )
            )

    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(report, range(2)))
    with Session(vote_engine) as db:
        assert (
            SqlPostReportRepository(db).count_distinct_reporters("vote-integrity-post")
            == 1
        )
