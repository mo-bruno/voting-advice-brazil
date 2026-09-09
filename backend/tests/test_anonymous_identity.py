from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.api.deps import get_moderation_client
from app.infrastructure.database.models import Base
from app.infrastructure.database.session import get_db
from app.infrastructure.llm.moderation_client import FakeModerationClient
from app.main import app
from tests.conftest import ANONYMOUS_OTHER as OTHER
from tests.conftest import ANONYMOUS_OWNER as OWNER

POSTS = "/api/v1/community/posts"
HEADER = "X-Farol-Anonymous-Id"


@pytest.fixture
def client() -> Iterator[TestClient]:
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)

    def database() -> Iterator[Session]:
        with Session(engine) as session:
            yield session

    app.dependency_overrides[get_db] = database
    app.dependency_overrides[get_moderation_client] = FakeModerationClient
    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.clear()
        engine.dispose()


def test_public_alias_is_stable_and_does_not_expose_uuid() -> None:
    from app.api.identity import public_author_alias

    first = public_author_alias(OWNER)
    assert first == public_author_alias(OWNER)
    assert first.startswith("u/")
    assert OWNER not in first
    assert first != public_author_alias(OTHER)


@pytest.mark.parametrize("identity", [None, "", "not-a-uuid", "550e8400-e29b-11d4-a716-446655440000", "u/0123456789"])
@pytest.mark.parametrize(
    ("method", "path", "body"),
    [
        ("POST", POSTS, {"content": "Debate político brasileiro."}),
        ("POST", f"{POSTS}/missing/votes", {"value": 1}),
        ("POST", f"{POSTS}/missing/comments", {"content": "Comentário."}),
        ("POST", f"{POSTS}/missing/reports", {"reason": "spam"}),
        ("DELETE", f"{POSTS}/missing", None),
        ("GET", "/api/v1/me/followed-actor", None),
        ("PUT", "/api/v1/me/followed-actor", {"political_actor_id": 1}),
        ("DELETE", "/api/v1/me/followed-actor", None),
        ("GET", "/api/v1/me/iot-device", None),
        ("PUT", "/api/v1/me/iot-device", {"device_token": OWNER, "pairing_code": "123456"}),
        ("DELETE", "/api/v1/me/iot-device", None),
        ("POST", "/api/v1/me/iot-device/quiz-pulse", {"answer": "agree", "current": 1, "total": 10}),
        ("GET", "/api/v1/me/iot-device/last-event", None),
    ],
)
def test_required_anonymous_header_rejects_invalid_credentials(
    client: TestClient, identity: str | None, method: str, path: str,
    body: dict[str, object] | None,
) -> None:
    headers = {} if identity is None else {HEADER: identity}
    response = client.request(method, path, headers=headers, json=body)
    assert response.status_code == 422
    # Verify the header error, so body/domain validation cannot mask a missing validator.
    if identity is None:
        errors = response.json()["detail"]
        assert isinstance(errors, list)
        assert len(errors) == 1
        assert errors[0]["loc"] == ["header", HEADER]
        assert errors[0]["type"] == "missing"
        assert errors[0]["input"] is None
    else:
        assert response.json()["detail"] == "Anonymous ID must be a UUID v4."
        if identity:
            assert identity not in response.text


@pytest.mark.parametrize("path", [POSTS, f"{POSTS}/missing"])
@pytest.mark.parametrize("identity", ["", "not-a-uuid", "550e8400-e29b-11d4-a716-446655440000"])
def test_optional_viewer_header_rejects_invalid_credentials(
    client: TestClient, path: str, identity: str,
) -> None:
    response = client.get(path, headers={HEADER: identity})
    assert response.status_code == 422
    assert response.json()["detail"] == "Anonymous ID must be a UUID v4."
    if identity:
        assert identity not in response.text


def _create_post(client: TestClient, identity: str = OWNER) -> dict[str, object]:
    response = client.post(
        POSTS, headers={HEADER: identity},
        json={"content": "Debate político brasileiro."},
    )
    assert response.status_code == 201
    body: dict[str, object] = response.json()
    return body


def test_post_response_hides_owner_credential(client: TestClient) -> None:
    response = client.post(
        POSTS, headers={HEADER: OWNER},
        json={"content": "Debate político brasileiro."},
    )
    assert response.status_code == 201
    body = response.json()
    assert "anonymous_id" not in body
    assert body["author_alias"].startswith("u/")
    assert body["is_mine"] is True
    assert OWNER not in response.text


@pytest.mark.parametrize(("viewer", "is_mine"), [(None, False), (OTHER, False), (OWNER, True)])
def test_list_and_detail_derive_ownership_from_viewer(
    client: TestClient, viewer: str | None, is_mine: bool,
) -> None:
    post = _create_post(client)
    comment = client.post(
        f"{POSTS}/{post['id']}/comments", headers={HEADER: OTHER},
        json={"content": "Comentário político."},
    )
    assert comment.status_code == 201
    headers = {} if viewer is None else {HEADER: viewer}
    listing = client.get(POSTS, headers=headers)
    detail = client.get(f"{POSTS}/{post['id']}", headers=headers)
    assert listing.status_code == detail.status_code == 200
    for projection in [listing.json()["posts"][0], detail.json()["post"]]:
        assert projection["is_mine"] is is_mine
        assert projection["author_alias"] == post["author_alias"]
        assert "anonymous_id" not in projection
    projected_comment = detail.json()["comments"][0]
    assert projected_comment["is_mine"] is (viewer == OTHER)
    assert projected_comment["author_alias"] == comment.json()["author_alias"]
    assert projected_comment["author_alias"] != post["author_alias"]
    for response in [listing, detail]:
        assert OWNER not in response.text
        assert OTHER not in response.text
        assert "anonymous_id" not in response.text


def test_comment_response_hides_owner_credential(client: TestClient) -> None:
    post = _create_post(client)
    response = client.post(
        f"{POSTS}/{post['id']}/comments", headers={HEADER: OWNER},
        json={"content": "Comentário político."},
    )
    assert response.status_code == 201
    assert "anonymous_id" not in response.json()
    assert response.json()["author_alias"] == post["author_alias"]
    assert response.json()["is_mine"] is True
    assert OWNER not in response.text


@pytest.mark.parametrize(("viewer", "is_mine"), [(OWNER, True), (OTHER, False)])
def test_vote_response_uses_post_ownership(client: TestClient, viewer: str, is_mine: bool) -> None:
    post = _create_post(client)
    response = client.post(
        f"{POSTS}/{post['id']}/votes", headers={HEADER: viewer}, json={"value": 1},
    )
    assert response.status_code == 200
    assert response.json()["is_mine"] is is_mine
    assert response.json()["author_alias"] == post["author_alias"]
    assert "anonymous_id" not in response.json()
    assert OWNER not in response.text
    assert OTHER not in response.text


def test_uuid_header_is_canonicalized_for_ownership(client: TestClient) -> None:
    post = _create_post(client, OWNER.upper())
    response = client.get(f"{POSTS}/{post['id']}", headers={HEADER: OWNER})
    assert response.status_code == 200
    assert response.json()["post"]["is_mine"] is True
    deleted = client.delete(f"{POSTS}/{post['id']}", headers={HEADER: OWNER})
    assert deleted.status_code == 204


def test_public_alias_cannot_authorize_post_deletion(client: TestClient) -> None:
    post = _create_post(client)
    response = client.delete(f"{POSTS}/{post['id']}", headers={HEADER: str(post["author_alias"])})
    assert response.status_code == 422
    assert client.get(f"{POSTS}/{post['id']}").json()["post"]["removed"] is False


def test_public_response_schemas_do_not_publish_anonymous_id(client: TestClient) -> None:
    schemas = client.get("/openapi.json").json()["components"]["schemas"]
    for name in ["PostOut", "CommentOut"]:
        properties = schemas[name]["properties"]
        assert "anonymous_id" not in properties
        assert {"author_alias", "is_mine"} <= properties.keys()


@pytest.mark.parametrize(
    ("method", "path", "required"),
    [
        ("post", POSTS, True),
        ("post", f"{POSTS}/{{post_id}}/votes", True),
        ("post", f"{POSTS}/{{post_id}}/comments", True),
        ("post", f"{POSTS}/{{post_id}}/reports", True),
        ("delete", f"{POSTS}/{{post_id}}", True),
        ("get", "/api/v1/me/followed-actor", True),
        ("put", "/api/v1/me/followed-actor", True),
        ("delete", "/api/v1/me/followed-actor", True),
        ("get", "/api/v1/me/iot-device", True),
        ("put", "/api/v1/me/iot-device", True),
        ("delete", "/api/v1/me/iot-device", True),
        ("post", "/api/v1/me/iot-device/quiz-pulse", True),
        ("get", "/api/v1/me/iot-device/last-event", True),
        ("get", POSTS, False),
        ("get", f"{POSTS}/{{post_id}}", False),
    ],
)
def test_openapi_documents_anonymous_header_requirement(
    client: TestClient, method: str, path: str, required: bool,
) -> None:
    operation = client.get("/openapi.json").json()["paths"][path][method]
    headers = [
        parameter for parameter in operation["parameters"]
        if parameter["in"] == "header" and parameter["name"] == HEADER
    ]
    assert len(headers) == 1
    assert headers[0]["required"] is required
    if required:
        assert headers[0]["schema"]["type"] == "string"
