from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # App
    app_name: str = "Farol Político API"
    app_version: str = "0.1.0"
    app_env: Literal["dev", "test", "staging", "prod"] = "dev"
    debug: bool = False
    iot_feature_enabled: bool = False
    active_election_year: int = 2026
    active_election_office: str = "presidente"

    # Database
    database_url: str = "sqlite:///./voting_advice.db"
    data_dir: str = "../data"
    allowed_origins: str = "https://farol-politico-495210.web.app"

    # External services
    moderation_mode: Literal["enforce", "disabled"] = "enforce"
    nvidia_api_key: str | None = None
    nvidia_moderation_model: str = "nvidia/nemotron-3-super-120b-a12b"
    mqtt_broker_url: str = "mqtts://broker.hivemq.com:8883"
    gnews_api_key: str | None = None

    @property
    def allowed_origins_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.allowed_origins.split(",")
            if origin.strip()
        ]


settings = Settings()
