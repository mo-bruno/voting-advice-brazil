from typing import Any

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Farol Político API"
    app_version: str = "0.1.0"
    database_url: str = "sqlite:///./voting_advice.db"
    data_dir: str = "../data"
    debug: bool = False

    @field_validator("debug", mode="before")
    @classmethod
    def parse_debug(cls, value: Any) -> Any:
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"release", "profile", "prod", "production"}:
                return False
            if normalized in {"debug", "dev", "development"}:
                return True

        return value


settings = Settings()
