from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    model_config = ConfigDict(env_file=".env", extra="ignore")

    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_jwt_secret: str = ""
    supabase_service_role_key: str = ""
    ai_model_provider: str = "openai"
    ai_model_api_key: str = ""
    ai_model_name: str = "gpt-5-mini"
    openai_base_url: str = "https://api.openai.com/v1"
    ai_request_timeout_seconds: float = 45.0
    max_image_upload_mb: int = 5
    allowed_origins: str = ""
    environment: str = "development"
    rate_limit_requests: int = 30
    rate_limit_window_seconds: int = 60
    brevo_api_key: str = ""
    brevo_sender_email: str = "keikoocatalasan@gmail.com"

    @property
    def allowed_origins_list(self) -> list[str]:
        raw = self.allowed_origins.strip()
        if not raw:
            return []
        if raw == "*":
            return []
        return [o.strip() for o in raw.split(",") if o.strip()]

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "production"

    def validate_runtime(self) -> None:
        if self.ai_model_provider.lower() not in {"deterministic", "openai"}:
            raise ValueError("AI_MODEL_PROVIDER must be 'deterministic' or 'openai'")
        if self.max_image_upload_mb <= 0:
            raise ValueError("MAX_IMAGE_UPLOAD_MB must be greater than zero")
        if self.rate_limit_requests <= 0 or self.rate_limit_window_seconds <= 0:
            raise ValueError("Rate limit settings must be greater than zero")
        if self.ai_request_timeout_seconds <= 0:
            raise ValueError("AI_REQUEST_TIMEOUT_SECONDS must be greater than zero")
        if not self.is_production:
            return
        missing = [
            name for name, value in {
                "SUPABASE_URL": self.supabase_url,
                "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
                "ALLOWED_ORIGINS": self.allowed_origins,
            }.items() if not value
        ]
        if missing:
            raise ValueError(f"Missing required production configuration: {', '.join(missing)}")
        if self.ai_model_provider.lower() == "openai" and not self.ai_model_api_key:
            raise ValueError("AI_MODEL_API_KEY is required when AI_MODEL_PROVIDER=openai")
        if self.allowed_origins.strip() == "*":
            raise ValueError("ALLOWED_ORIGINS must not be '*' in production")


settings = Settings()
