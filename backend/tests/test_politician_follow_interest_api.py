import pytest
from sqlalchemy import text

from tests.conftest import ANONYMOUS_OWNER


def _headers(anonymous_id: str = ANONYMOUS_OWNER) -> dict[str, str]:
    return {"X-Farol-Anonymous-Id": anonymous_id}


def test_registers_interest_idempotently(client) -> None:
    client.delete(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )
    first = client.put(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )
    second = client.put(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )

    assert first.status_code == 200
    assert first.json() == {"registered": True, "newly_registered": True}
    assert second.status_code == 200
    assert second.json() == {"registered": True, "newly_registered": False}
    client.delete(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )


def test_reads_and_removes_interest(client) -> None:
    client.delete(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )
    before = client.get(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )
    registered = client.put(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )
    after = client.get(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )
    removed = client.delete(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )
    final = client.get(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )

    assert before.status_code == 200
    assert before.json() == {"registered": False}
    assert registered.status_code == 200
    assert after.json() == {"registered": True}
    assert removed.status_code == 204
    assert final.json() == {"registered": False}


def test_stores_only_a_one_way_subject_hash(client, db_session) -> None:
    client.delete(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )

    response = client.put(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )
    stored_hash = db_session.execute(
        text("SELECT subject_hash FROM politician_follow_interests"),
    ).scalar_one()

    assert response.status_code == 200
    assert stored_hash == (
        "a9b6fca98823a47b206e72aca10c4a6bd8153f99f5cca06b2e006bcc5fa51ac5"
    )
    assert ANONYMOUS_OWNER not in stored_hash
    client.delete(
        "/api/v1/me/politician-follow-interest",
        headers=_headers(),
    )


@pytest.mark.parametrize("method", ["get", "put", "delete"])
def test_interest_requires_a_valid_anonymous_identity(client, method: str) -> None:
    response = getattr(client, method)(
        "/api/v1/me/politician-follow-interest",
    )

    assert response.status_code == 422


def test_interest_registration_obeys_the_api_ip_rate_limit(client) -> None:
    client.app.state.limiter.reset()
    try:
        for _ in range(60):
            response = client.put(
                "/api/v1/me/politician-follow-interest",
                headers=_headers(),
            )
            assert response.status_code == 200

        limited = client.put(
            "/api/v1/me/politician-follow-interest",
            headers=_headers(),
        )

        assert limited.status_code == 429
    finally:
        client.app.state.limiter.reset()


@pytest.mark.parametrize(
    ("method", "kwargs"),
    [
        ("get", {}),
        ("put", {"json": {"political_actor_id": 1}}),
        ("delete", {}),
    ],
)
def test_disabled_feature_rejects_all_legacy_follow_operations(
    client,
    monkeypatch: pytest.MonkeyPatch,
    method: str,
    kwargs: dict[str, object],
) -> None:
    monkeypatch.setattr(
        client.app.state.settings,
        "politician_follow_enabled",
        False,
    )

    response = getattr(client, method)(
        "/api/v1/me/followed-actor",
        headers=_headers(),
        **kwargs,
    )

    assert response.status_code == 404
    assert response.json() == {"detail": "Funcionalidade ainda nao disponivel."}
