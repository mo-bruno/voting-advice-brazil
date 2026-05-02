from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # App
    app_name: str = "Farol Político API"
    app_version: str = "0.1.0"
    app_env: Literal["dev", "test", "staging", "prod"] = "dev"
    debug: bool = False

    # Database
    database_url: str = "sqlite:///./voting_advice.db"
    data_dir: str = "../data"

    # External services
    groq_api_key: str | None = None
    mqtt_broker_url: str = "mqtts://broker.hivemq.com:8883"


settings = Settings()
