import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_db, get_moderation_client
from app.infrastructure.database.models import Base
from app.infrastructure.llm.moderation_client import FakeModerationClient
from app.main import app

ANON = "test-device-001"
HEADERS = {"x-farol-anonymous-id": ANON}


def _make_client(approved: bool, reason: str = "") -> tuple:
    """Return (engine, TestClient) sharing a single SQLite in-memory connection."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def override_db():
        with TestSession() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_moderation_client] = lambda: FakeModerationClient(
        approved=approved, reason=reason
    )
    return engine, TestClient(app)


@pytest.fixture()
def client():
    engine, c = _make_client(approved=True)
    with c as tc:
        yield tc
    app.dependency_overrides.clear()


@pytest.fixture()
def client_rejecting():
    engine, c = _make_client(approved=False, reason="Conteúdo fora do tema político")
    with c as tc:
        yield tc
    app.dependency_overrides.clear()


def test_create_post_approved(client):
    resp = client.post(
        "/api/v1/community/posts",
        json={"content": "PT votou contra a reforma administrativa"},
        headers=HEADERS,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["content"] == "PT votou contra a reforma administrativa"
    assert data["score"] == 0


def test_create_post_rejected(client_rejecting):
    resp = client_rejecting.post(
        "/api/v1/community/posts",
        json={"content": "Receita de bolo"},
        headers=HEADERS,
    )
    assert resp.status_code == 422
    assert "Conteúdo fora do tema político" in resp.json()["detail"]


def test_list_posts_empty(client):
    resp = client.get("/api/v1/community/posts")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_count"] == 0
    assert data["posts"] == []


def test_list_posts_after_create(client):
    client.post(
        "/api/v1/community/posts",
        json={"content": "Lula assinou decreto X"},
        headers=HEADERS,
    )
    resp = client.get("/api/v1/community/posts")
    assert resp.json()["total_count"] == 1


def test_get_post_with_comment(client):
    create_resp = client.post(
        "/api/v1/community/posts",
        json={"content": "Bolsonaro votou sim na PEC"},
        headers=HEADERS,
    )
    post_id = create_resp.json()["id"]

    client.post(
        f"/api/v1/community/posts/{post_id}/comments",
        json={"content": "Interessante!"},
        headers=HEADERS,
    )

    resp = client.get(f"/api/v1/community/posts/{post_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["post"]["id"] == post_id
    assert len(data["comments"]) == 1
    assert data["comments"][0]["content"] == "Interessante!"


def test_get_post_not_found(client):
    resp = client.get("/api/v1/community/posts/nope")
    assert resp.status_code == 404


def test_vote_increases_score(client):
    post_id = client.post(
        "/api/v1/community/posts",
        json={"content": "Câmara aprovou PL de armas"},
        headers=HEADERS,
    ).json()["id"]

    resp = client.post(
        f"/api/v1/community/posts/{post_id}/votes",
        json={"value": 1},
        headers=HEADERS,
    )
    assert resp.status_code == 200
    assert resp.json()["score"] == 1


def test_vote_replaces_previous(client):
    post_id = client.post(
        "/api/v1/community/posts",
        json={"content": "Senado aprovou reforma tributária"},
        headers=HEADERS,
    ).json()["id"]

    client.post(
        f"/api/v1/community/posts/{post_id}/votes", json={"value": 1}, headers=HEADERS
    )
    resp = client.post(
        f"/api/v1/community/posts/{post_id}/votes", json={"value": -1}, headers=HEADERS
    )
    assert resp.json()["score"] == -1


def test_comment_on_missing_post(client):
    resp = client.post(
        "/api/v1/community/posts/nope/comments",
        json={"content": "comentário"},
        headers=HEADERS,
    )
    assert resp.status_code == 404
