import os

import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_settings_defaults(monkeypatch):
    # conftest sets APP_ENV=test for the app lifespan; clear it to verify defaults
    monkeypatch.delenv("APP_ENV", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.delenv("GROQ_API_KEY", raising=False)
    monkeypatch.delenv("MQTT_BROKER_URL", raising=False)
    s = Settings(_env_file=None)
    assert s.app_env == "dev"
    assert s.database_url.startswith("sqlite:///")
    assert s.mqtt_broker_url == "mqtts://broker.hivemq.com:8883"
    assert s.groq_api_key is None


def test_settings_reads_env(monkeypatch):
    monkeypatch.setenv("APP_ENV", "prod")
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://x:y@z/d")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    s = Settings()
    assert s.app_env == "prod"
    assert s.database_url == "postgresql+psycopg://x:y@z/d"
    assert s.groq_api_key == "gsk_test"


def test_settings_rejects_invalid_env(monkeypatch):
    monkeypatch.setenv("APP_ENV", "bogus")
    with pytest.raises(ValidationError):
        Settings()
