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
    allowed_origins: str = "https://farol-politico-495210.web.app"

    # External services
    groq_api_key: str | None = None
    gemini_api_key: str | None = None
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
