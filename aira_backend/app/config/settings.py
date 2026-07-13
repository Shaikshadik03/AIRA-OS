"""Application settings loaded from environment variables."""

from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """AIRA OS application settings."""

    # Supabase
    supabase_url: str = "https://your-project.supabase.co"
    supabase_key: str = "your-supabase-anon-key"
    supabase_service_role_key: str = "your-supabase-service-role-key"

    # AI
    groq_api_key: str = "your-groq-api-key"

    # Security
    jwt_secret: str = "your-supabase-jwt-secret"
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    # App
    environment: str = "development"
    app_name: str = "AIRA OS"
    api_v1_prefix: str = "/api/v1"

    @property
    def debug(self) -> bool:
        return self.environment == "development"

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "extra": "ignore",
    }


@lru_cache()
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()
