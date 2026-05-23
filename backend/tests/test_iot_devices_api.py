from datetime import datetime, timezone

import pytest

from app.api.deps import get_iot_mqtt_publisher
from app.infrastructure.database.models import (
    IotDeviceLinkModel,
    IotPairingSessionModel,
)
from app.main import app

TOKEN = "550e8400-e29b-41d4-a716-446655440000"
PAIRING_CODE = "482913"


class FakePublisher:
    def __init__(self) -> None:
        self.messages: list[tuple[str, dict[str, str]]] = []

    def publish(self, topic: str, payload: dict[str, str]) -> None:
        self.messages.append((topic, payload))


@pytest.fixture(autouse=True)
def clean_iot_tables(db_session):
    db_session.query(IotPairingSessionModel).delete()
    db_session.query(IotDeviceLinkModel).delete()
    db_session.commit()
    yield
    db_session.query(IotPairingSessionModel).delete()
    db_session.query(IotDeviceLinkModel).delete()
    db_session.commit()


def test_create_pairing_session_returns_qr_payload(client) -> None:
    response = client.post(
        f"/api/v1/iot-devices/{TOKEN}/pairing-session",
        json={"pairing_code": PAIRING_CODE, "firmware_version": "0.1.0"},
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["device_token"] == TOKEN
    assert payload["pairing_code"] == PAIRING_CODE
    assert (
        payload["qr_payload"]
        == f"farol://pair?device_token={TOKEN}&pairing_code={PAIRING_CODE}"
    )
    assert payload["expires_at"] is not None


def test_get_iot_device_returns_404_when_unlinked(client) -> None:
    response = client.get(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
    )

    assert response.status_code == 404


def test_pair_flow_links_device_and_publishes_confirmation(client) -> None:
    publisher = FakePublisher()
    app.dependency_overrides[get_iot_mqtt_publisher] = lambda: publisher
    try:
        client.post(
            f"/api/v1/iot-devices/{TOKEN}/pairing-session",
            json={"pairing_code": PAIRING_CODE, "firmware_version": "0.1.0"},
        )

        pair_response = client.put(
            "/api/v1/me/iot-device",
            headers={"X-Farol-Anonymous-Id": "anon-1"},
            json={"device_token": TOKEN, "pairing_code": PAIRING_CODE},
        )
        get_response = client.get(
            "/api/v1/me/iot-device",
            headers={"X-Farol-Anonymous-Id": "anon-1"},
        )
    finally:
        app.dependency_overrides.pop(get_iot_mqtt_publisher, None)

    assert pair_response.status_code == 200
    assert pair_response.json()["status"] == "linked"
    assert get_response.status_code == 200
    assert get_response.json()["device_token"] == TOKEN
    assert publisher.messages[0][0] == f"farol/{TOKEN}"
    assert publisher.messages[0][1]["type"] == "pairing_confirmed"


def test_consumed_session_is_rejected(client) -> None:
    publisher = FakePublisher()
    app.dependency_overrides[get_iot_mqtt_publisher] = lambda: publisher
    try:
        client.post(
            f"/api/v1/iot-devices/{TOKEN}/pairing-session",
            json={"pairing_code": PAIRING_CODE, "firmware_version": "0.1.0"},
        )
        first_response = client.put(
            "/api/v1/me/iot-device",
            headers={"X-Farol-Anonymous-Id": "anon-1"},
            json={"device_token": TOKEN, "pairing_code": PAIRING_CODE},
        )
        second_response = client.put(
            "/api/v1/me/iot-device",
            headers={"X-Farol-Anonymous-Id": "anon-1"},
            json={"device_token": TOKEN, "pairing_code": PAIRING_CODE},
        )
    finally:
        app.dependency_overrides.pop(get_iot_mqtt_publisher, None)

    assert first_response.status_code == 200
    assert second_response.status_code == 422


def test_delete_unlinks_current_app(client, db_session) -> None:
    db_session.add(
        IotDeviceLinkModel(
            device_token=TOKEN,
            anonymous_id="anon-1",
            status="linked",
            created_at=datetime(2026, 5, 22, tzinfo=timezone.utc),
            updated_at=datetime(2026, 5, 22, tzinfo=timezone.utc),
        )
    )
    db_session.commit()

    delete_response = client.delete(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
    )
    get_response = client.get(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
    )

    assert delete_response.status_code == 204
    assert get_response.status_code == 404
