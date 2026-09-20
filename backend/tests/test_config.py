
import pytest
from pydantic import ValidationError

from app.config import Settings


def test_iot_is_disabled_and_unused_gemini_setting_is_absent(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("IOT_FEATURE_ENABLED", raising=False)
    configured = Settings(_env_file=None)
    assert configured.iot_feature_enabled is False
    assert not hasattr(configured, "gemini_api_key")


def test_settings_defaults(monkeypatch):
    # conftest sets APP_ENV=test for the app lifespan; clear it to verify defaults
    monkeypatch.delenv("APP_ENV", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.delenv("NVIDIA_API_KEY", raising=False)
    monkeypatch.delenv("NVIDIA_MODERATION_MODEL", raising=False)
    monkeypatch.delenv("MQTT_BROKER_URL", raising=False)
    monkeypatch.delenv("ALLOWED_ORIGINS", raising=False)
    monkeypatch.delenv("IOT_FEATURE_ENABLED", raising=False)
    s = Settings(_env_file=None)
    assert s.app_env == "dev"
    assert s.database_url.startswith("sqlite:///")
    assert s.allowed_origins_list == ["https://farol-politico-495210.web.app"]
    assert s.mqtt_broker_url == "mqtts://broker.hivemq.com:8883"
    assert s.nvidia_api_key is None
    assert s.nvidia_moderation_model == "nvidia/nemotron-3-super-120b-a12b"
    assert s.iot_feature_enabled is False


def test_settings_reads_env(monkeypatch):
    monkeypatch.setenv("APP_ENV", "prod")
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://x:y@z/d")
    monkeypatch.setenv("NVIDIA_API_KEY", "nvapi-test")
    monkeypatch.setenv("NVIDIA_MODERATION_MODEL", "nvidia/test-model")
    monkeypatch.setenv("IOT_FEATURE_ENABLED", "true")
    monkeypatch.setenv(
        "ALLOWED_ORIGINS",
        "https://farol-politico-495210.web.app, http://localhost:3000",
    )
    s = Settings()
    assert s.app_env == "prod"
    assert s.database_url == "postgresql+psycopg://x:y@z/d"
    assert s.nvidia_api_key == "nvapi-test"
    assert s.nvidia_moderation_model == "nvidia/test-model"
    assert s.iot_feature_enabled is True
    assert s.allowed_origins_list == [
        "https://farol-politico-495210.web.app",
        "http://localhost:3000",
    ]


def test_settings_rejects_invalid_env(monkeypatch):
    monkeypatch.setenv("APP_ENV", "bogus")
    with pytest.raises(ValidationError):
        Settings()
