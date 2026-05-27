"""Tests for GET /me/iot-device/last-event endpoint."""

from datetime import datetime, timezone
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from app.main import app
from app.api.deps import get_iot_device_link_repo, get_iot_device_event_repo
from app.core.entities.iot_device import IotDeviceEvent, IotDeviceLink


def _fake_link():
    return IotDeviceLink(
        device_token="tok-abc",
        anonymous_id="user-1",
        status="linked",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        last_seen_at=None,
    )


def _fake_event():
    payload = {
        "type": "vote_alert",
        "deputy_name": "Fulano",
        "party": "PT",
        "state": "SP",
        "vote": "Sim",
        "alignment": "aligned",
        "color": "green",
        "description": "Reforma tributaria",
        "timestamp_utc": "2026-05-27T12:00:00+00:00",
    }
    return IotDeviceEvent(
        id=1, device_token="tok-abc", event_type="vote_alert",
        payload=payload, published_at=datetime.now(timezone.utc),
    )


def test_get_last_event_returns_event():
    link_repo = MagicMock()
    link_repo.get_by_anonymous_id.return_value = _fake_link()
    event_repo = MagicMock()
    event_repo.get_latest.return_value = _fake_event()

    app.dependency_overrides[get_iot_device_link_repo] = lambda: link_repo
    app.dependency_overrides[get_iot_device_event_repo] = lambda: event_repo

    client = TestClient(app)
    resp = client.get("/api/v1/me/iot-device/last-event", headers={"X-Farol-Anonymous-Id": "user-1"})

    assert resp.status_code == 200
    data = resp.json()
    assert data["deputy_name"] == "Fulano"
    assert data["alignment"] == "aligned"

    app.dependency_overrides.clear()


def test_get_last_event_404_when_no_device():
    link_repo = MagicMock()
    link_repo.get_by_anonymous_id.return_value = None
    event_repo = MagicMock()

    app.dependency_overrides[get_iot_device_link_repo] = lambda: link_repo
    app.dependency_overrides[get_iot_device_event_repo] = lambda: event_repo

    client = TestClient(app)
    resp = client.get("/api/v1/me/iot-device/last-event", headers={"X-Farol-Anonymous-Id": "user-1"})

    assert resp.status_code == 404

    app.dependency_overrides.clear()
