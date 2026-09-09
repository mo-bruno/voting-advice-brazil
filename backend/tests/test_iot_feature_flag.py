from app.core.config import Settings
from app.main import create_app


def _paths(enabled: bool) -> set[str]:
    configured = Settings(_env_file=None, iot_feature_enabled=enabled)
    return {route.path for route in create_app(configured).routes}


def test_iot_routes_are_absent_by_default(monkeypatch) -> None:
    monkeypatch.delenv("IOT_FEATURE_ENABLED", raising=False)

    assert Settings(_env_file=None).iot_feature_enabled is False
    assert "/api/v1/me/iot-device" not in _paths(False)
    assert "/api/v1/iot-devices/{device_token}/pairing-session" not in _paths(False)


def test_iot_routes_can_be_explicitly_enabled() -> None:
    assert "/api/v1/me/iot-device" in _paths(True)
