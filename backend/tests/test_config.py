import os

import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_settings_defaults():
    s = Settings()
    assert s.app_env == "dev"
    assert s.database_url.startswith("sqlite:///")
    assert s.mqtt_broker_url == "mqtts://broker.hivemq.com:8883"
    assert s.groq_api_key is None


def test_settings_reads_env(monkeypatch):
    monkeypatch.setenv("APP_ENV", "prod")
    monkeypatch.setenv("DATABASE_URL", "postgresql://x:y@z/d")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    s = Settings()
    assert s.app_env == "prod"
    assert s.database_url == "postgresql://x:y@z/d"
    assert s.groq_api_key == "gsk_test"


def test_settings_rejects_invalid_env(monkeypatch):
    monkeypatch.setenv("APP_ENV", "bogus")
    with pytest.raises(ValidationError):
        Settings()
