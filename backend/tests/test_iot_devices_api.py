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
AMBIGUOUS_TOKEN_A = "12345678-1234-4abc-8abc-123456789abc"
AMBIGUOUS_TOKEN_B = "12345678-abcd-4def-9def-abcdef123456"


class FakePublisher:
    def __init__(self) -> None:
        self.messages: list[tuple[str, dict[str, str]]] = []

    def publish(self, topic: str, payload: dict[str, str]) -> None:
        self.messages.append((topic, payload))


class FailingPublisher:
    def publish(self, topic: str, payload: dict[str, str]) -> None:
        raise RuntimeError("mqtt offline")


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


def test_manual_pair_flow_links_device_and_publishes_confirmation(client) -> None:
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
            json={
                "device_token_prefix": TOKEN[:8],
                "pairing_code": PAIRING_CODE,
            },
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


def test_manual_pair_flow_rejects_unknown_device_token_prefix(client) -> None:
    client.post(
        f"/api/v1/iot-devices/{TOKEN}/pairing-session",
        json={"pairing_code": PAIRING_CODE, "firmware_version": "0.1.0"},
    )

    response = client.put(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
        json={"device_token_prefix": "deadbeef", "pairing_code": PAIRING_CODE},
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Codigo de pareamento invalido ou expirado."


def test_manual_pair_flow_rejects_ambiguous_device_token_prefix(client) -> None:
    client.post(
        f"/api/v1/iot-devices/{AMBIGUOUS_TOKEN_A}/pairing-session",
        json={"pairing_code": PAIRING_CODE, "firmware_version": "0.1.0"},
    )
    client.post(
        f"/api/v1/iot-devices/{AMBIGUOUS_TOKEN_B}/pairing-session",
        json={"pairing_code": PAIRING_CODE, "firmware_version": "0.1.0"},
    )

    response = client.put(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
        json={
            "device_token_prefix": AMBIGUOUS_TOKEN_A[:8],
            "pairing_code": PAIRING_CODE,
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"] == (
        "Prefixo do dispositivo corresponde a mais de uma sessao ativa."
    )


def test_pairing_status_reports_unlinked_then_linked(client) -> None:
    publisher = FakePublisher()
    app.dependency_overrides[get_iot_mqtt_publisher] = lambda: publisher
    try:
        before_response = client.get(
            f"/api/v1/iot-devices/{TOKEN}/pairing-status",
        )
        client.post(
            f"/api/v1/iot-devices/{TOKEN}/pairing-session",
            json={"pairing_code": PAIRING_CODE, "firmware_version": "0.1.0"},
        )
        pair_response = client.put(
            "/api/v1/me/iot-device",
            headers={"X-Farol-Anonymous-Id": "anon-1"},
            json={"device_token": TOKEN, "pairing_code": PAIRING_CODE},
        )
        after_response = client.get(
            f"/api/v1/iot-devices/{TOKEN}/pairing-status",
        )
    finally:
        app.dependency_overrides.pop(get_iot_mqtt_publisher, None)

    assert before_response.status_code == 200
    assert before_response.json() == {"paired": False, "status": "unlinked"}
    assert pair_response.status_code == 200
    assert after_response.status_code == 200
    assert after_response.json() == {"paired": True, "status": "linked"}


def test_pair_flow_still_succeeds_when_mqtt_publish_fails(client) -> None:
    app.dependency_overrides[get_iot_mqtt_publisher] = FailingPublisher
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
