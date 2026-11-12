"""환경 설정. 값은 환경변수 또는 server/.env 에서 읽는다."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "myprettyboard"
    database_url: str = "postgresql+psycopg://board:board@localhost:5442/board"
    cors_origins: list[str] = ["http://localhost:3100"]


settings = Settings()
