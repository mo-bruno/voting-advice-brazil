import hashlib
from collections.abc import Iterator
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.api.deps import get_db, get_moderation_client
from app.core.entities.community import Comment, ModerationResult, Post
from app.core.use_cases.interfaces import ModerationPort, ModerationUnavailable
from app.core.use_cases.vote_post import vote_post
from app.infrastructure.database.community_repositories import (
    SqlCommentRepository,
    SqlModerationLogRepository,
    SqlPostRepository,
    SqlPostVoteRepository,
)
from app.infrastructure.database.models import (
    Base,
    CommentModel,
    ModerationLogModel,
    PostVoteModel,
)
from app.infrastructure.llm.moderation_client import FakeModerationClient
from app.main import app
from tests.conftest import ANONYMOUS_OTHER, ANONYMOUS_OWNER

NOW = datetime(2026, 9, 9, 12, tzinfo=timezone.utc)
HEADERS = {"X-Farol-Anonymous-Id": ANONYMOUS_OWNER}


class DownModeration(ModerationPort):
    def moderate(
        self, content: str, report_reasons: list[str] | None = None
    ) -> ModerationResult:
        raise ModerationUnavailable("offline")


@pytest.fixture
def db() -> Iterator[Session]:
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        repo = SqlPostRepository(session)
        for post_id in ("p1", "p2"):
            repo.create(Post(
                id=post_id, anonymous_id=ANONYMOUS_OWNER, content="Política",
                political_actor_id=None, theme_slug=None, score=0, created_at=NOW,
            ))
        yield session
    engine.dispose()


@pytest.fixture
def api(db: Session) -> Iterator[TestClient]:
    def database() -> Iterator[Session]:
        with Session(db.get_bind()) as session:
            yield session

    app.dependency_overrides[get_db] = database
    app.dependency_overrides[get_moderation_client] = FakeModerationClient
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


def _seed_comment(
    db: Session, comment_id: str, author: str, created_at: datetime, post_id: str = "p1"
) -> None:
    SqlCommentRepository(db).create(Comment(
        id=comment_id, post_id=post_id, anonymous_id=author,
        content="Comentário anterior", created_at=created_at,
    ))


@pytest.mark.parametrize("approved", [True, False])
def test_comment_moderation_logs_hash_and_only_persists_approval(
    db: Session, approved: bool
) -> None:
    from app.core.use_cases.create_comment import moderate_and_create_comment

    result = moderate_and_create_comment(
        post_repo=SqlPostRepository(db), comment_repo=SqlCommentRepository(db),
        log_repo=SqlModerationLogRepository(db),
        moderation_client=FakeModerationClient(approved=approved, reason="Falso"),
        post_id="p1", anonymous_id=ANONYMOUS_OWNER, content="Conteúdo político",
    )
    assert result is not None
    comment, decision = result
    assert decision.approved is approved
    comments = SqlCommentRepository(db).list_by_post("p1")
    assert len(comments) == int(approved)
    assert (comment is not None) is approved
    entries = list(db.scalars(select(ModerationLogModel)))
    assert len(entries) == 1
    assert entries[0].post_id == "p1"
    assert entries[0].anonymous_id == ANONYMOUS_OWNER
    assert entries[0].content_hash == hashlib.sha256("Conteúdo político".encode()).hexdigest()
    assert entries[0].approved is approved
    assert entries[0].reason == (None if approved else "Falso")
    assert entries[0].model_used == decision.model_used


def test_comment_limit_is_ten_per_ten_minutes() -> None:
    from app.core.use_cases.comment_rate_limit import (
        CommentRateLimitExceeded,
        check_comment_rate_limit,
    )

    check_comment_rate_limit(9)
    with pytest.raises(CommentRateLimitExceeded) as exc:
        check_comment_rate_limit(10)
    assert exc.value.retry_after_seconds == 600


def test_comment_count_filters_author_and_includes_window_boundary(db: Session) -> None:
    since = NOW - timedelta(minutes=10)
    _seed_comment(db, "old", ANONYMOUS_OWNER, since - timedelta(microseconds=1))
    _seed_comment(db, "boundary", ANONYMOUS_OWNER, since)
    _seed_comment(db, "recent", ANONYMOUS_OWNER, NOW, post_id="p2")
    _seed_comment(db, "other", ANONYMOUS_OTHER, NOW)
    assert SqlCommentRepository(db).count_by_author_since(ANONYMOUS_OWNER, since) == 2


def test_use_case_blocks_eleventh_accepted_comment(db: Session) -> None:
    from app.core.use_cases.comment_rate_limit import CommentRateLimitExceeded
    from app.core.use_cases.create_comment import moderate_and_create_comment

    for index in range(10):
        _seed_comment(db, str(index), ANONYMOUS_OWNER, datetime.now(timezone.utc) - timedelta(minutes=9))
    with pytest.raises(CommentRateLimitExceeded):
        moderate_and_create_comment(
            SqlPostRepository(db), SqlCommentRepository(db), SqlModerationLogRepository(db),
            FakeModerationClient(), "p2", ANONYMOUS_OWNER, "Décimo primeiro",
        )
    assert SqlCommentRepository(db).list_by_post("p2") == []


@pytest.mark.parametrize("operation", ["comment", "vote"])
def test_removed_post_use_cases_reject_without_writes(db: Session, operation: str) -> None:
    from app.core.use_cases.community_errors import PostRemovedError
    from app.core.use_cases.create_comment import moderate_and_create_comment

    post_repo = SqlPostRepository(db)
    post_repo.mark_removed("p1", "author", NOW)
    with pytest.raises(PostRemovedError):
        if operation == "vote":
            vote_post(post_repo, SqlPostVoteRepository(db), "p1", ANONYMOUS_OWNER, 1)
        else:
            moderate_and_create_comment(
                post_repo, SqlCommentRepository(db), SqlModerationLogRepository(db),
                DownModeration(), "p1", ANONYMOUS_OWNER, "Comentário",
            )
    assert list(db.scalars(select(PostVoteModel))) == []
    assert list(db.scalars(select(CommentModel))) == []
    assert list(db.scalars(select(ModerationLogModel))) == []


@pytest.mark.parametrize("operation,payload", [
    ("comments", {"content": "Novo comentário"}), ("votes", {"value": 1}),
])
@pytest.mark.parametrize("removed", [True, False])
def test_inactive_post_api_status(
    api: TestClient, db: Session, operation: str, payload: dict[str, object], removed: bool
) -> None:
    if removed:
        SqlPostRepository(db).mark_removed("p1", "author", NOW)
    post_id = "p1" if removed else "missing"
    app.dependency_overrides[get_moderation_client] = DownModeration
    response = api.post(
        f"/api/v1/community/posts/{post_id}/{operation}", json=payload, headers=HEADERS,
    )
    assert response.status_code == (410 if removed else 404)
    assert list(db.scalars(select(PostVoteModel))) == []
    assert list(db.scalars(select(CommentModel))) == []


def test_unavailable_moderation_returns_503_without_comment(api: TestClient, db: Session) -> None:
    app.dependency_overrides[get_moderation_client] = DownModeration
    response = api.post(
        "/api/v1/community/posts/p1/comments", headers=HEADERS, json={"content": "Política"},
    )
    assert response.status_code == 503
    assert list(db.scalars(select(CommentModel))) == []
    assert list(db.scalars(select(ModerationLogModel))) == []


def test_rejection_returns_reason_logs_and_does_not_use_quota(api: TestClient, db: Session) -> None:
    app.dependency_overrides[get_moderation_client] = lambda: FakeModerationClient(False, "Falso")
    for _ in range(11):
        response = api.post(
            "/api/v1/community/posts/p1/comments", headers=HEADERS, json={"content": "Rejeitado"},
        )
        assert response.status_code == 422
        assert response.json()["detail"] == "Falso"
    assert list(db.scalars(select(CommentModel))) == []
    assert len(list(db.scalars(select(ModerationLogModel)))) == 11
    app.dependency_overrides[get_moderation_client] = FakeModerationClient
    assert api.post(
        "/api/v1/community/posts/p1/comments", headers=HEADERS, json={"content": "Aprovado"},
    ).status_code == 201


def test_comment_quota_is_persisted_across_posts_and_canonical_uuid(
    api: TestClient, db: Session
) -> None:
    for index in range(10):
        identity = ANONYMOUS_OWNER if index % 2 else ANONYMOUS_OWNER.upper().replace("-", "")
        response = api.post(
            f"/api/v1/community/posts/p{index % 2 + 1}/comments",
            headers={"X-Farol-Anonymous-Id": identity}, json={"content": "Aprovado"},
        )
        assert response.status_code == 201
        assert response.json()["is_mine"] is True
        assert response.json()["author_alias"]
        assert "anonymous_id" not in response.json()
    response = api.post(
        "/api/v1/community/posts/p2/comments", headers=HEADERS, json={"content": "Décimo primeiro"},
    )
    assert response.status_code == 429
    assert response.headers["Retry-After"] == "600"
    assert len(list(db.scalars(select(CommentModel)))) == 10
    other = api.post(
        "/api/v1/community/posts/p1/comments", json={"content": "Outro autor"},
        headers={"X-Farol-Anonymous-Id": ANONYMOUS_OTHER},
    )
    assert other.status_code == 201
    app.dependency_overrides[get_moderation_client] = lambda: FakeModerationClient(False, "Falso")
    rejected = api.post(
        "/api/v1/community/posts/p1/comments", headers=HEADERS, json={"content": "Rejeitado"},
    )
    assert rejected.status_code == 422
    assert len(list(db.scalars(select(ModerationLogModel).where(ModerationLogModel.approved.is_(False))))) == 1


def test_comment_quota_expires_after_ten_minutes(api: TestClient, db: Session) -> None:
    old = datetime.now(timezone.utc) - timedelta(minutes=10, seconds=1)
    for index in range(10):
        _seed_comment(db, str(index), ANONYMOUS_OWNER, old)
    response = api.post(
        "/api/v1/community/posts/p1/comments", headers=HEADERS, json={"content": "Nova janela"},
    )
    assert response.status_code == 201
