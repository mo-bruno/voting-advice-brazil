from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Farol Político API"
    app_version: str = "0.1.0"
    database_url: str = "sqlite:///./voting_advice.db"
    data_dir: str = "../data"
    debug: bool = False


settings = Settings()
