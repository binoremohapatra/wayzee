from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "Wayze Backend"
    app_version: str = "0.1.0"
    database_url: str = "sqlite:///wayze.db"
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]
    rate_limit_per_minute: int = 60
    max_map_size_bytes: int = 10 * 1024 * 1024  # 10MB
    max_qr_size_bytes: int = 2 * 1024  # 2KB

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
