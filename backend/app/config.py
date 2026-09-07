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
    nvidia_base_url: str = "https://integrate.api.nvidia.com/v1"
    chat_model_provider: str = "inherit"
    chat_model_api_key: str = ""
    chat_model_name: str = "openai/gpt-oss-20b"
    groq_base_url: str = "https://api.groq.com/openai/v1"
    ai_request_timeout_seconds: float = 45.0
    ai_web_search_enabled: bool = False
    ai_allowed_domains: str = ""
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
        return self.environment.strip().lower() == "production"

    @property
    def ai_allowed_domains_list(self) -> list[str]:
        return [
            domain.strip().removeprefix("https://").removeprefix("http://")
            for domain in self.ai_allowed_domains.split(",")
            if domain.strip()
        ]

    @property
    def effective_chat_provider(self) -> str:
        requested = self.chat_model_provider.strip().lower()
        return (
            self.ai_model_provider.strip().lower()
            if requested in {"", "inherit"}
            else requested
        )

    @property
    def effective_chat_api_key(self) -> str:
        requested = self.chat_model_provider.strip().lower()
        if requested not in {"", "inherit"}:
            return self.chat_model_api_key
        return self.ai_model_api_key

    @property
    def effective_chat_model(self) -> str:
        requested = self.chat_model_provider.strip().lower()
        if requested in {"", "inherit"}:
            return self.ai_model_name
        return self.chat_model_name.strip() or "openai/gpt-oss-20b"

    def validate_runtime(self) -> None:
        scanner_provider = self.ai_model_provider.strip().lower()
        if scanner_provider not in {"deterministic", "openai", "nvidia"}:
            raise ValueError("AI_MODEL_PROVIDER must be 'deterministic', 'openai', or 'nvidia'")
        if self.effective_chat_provider not in {"deterministic", "openai", "nvidia", "groq"}:
            raise ValueError(
                "CHAT_MODEL_PROVIDER must be 'inherit', 'deterministic', 'openai', 'nvidia', or 'groq'"
            )
        if self.max_image_upload_mb <= 0:
            raise ValueError("MAX_IMAGE_UPLOAD_MB must be greater than zero")
        if self.rate_limit_requests <= 0 or self.rate_limit_window_seconds <= 0:
            raise ValueError("Rate limit settings must be greater than zero")
        if self.ai_request_timeout_seconds <= 0:
            raise ValueError("AI_REQUEST_TIMEOUT_SECONDS must be greater than zero")
        if self.ai_web_search_enabled and not self.ai_allowed_domains_list:
            raise ValueError(
                "AI_ALLOWED_DOMAINS is required when AI_WEB_SEARCH_ENABLED=true"
            )
        if not self.is_production:
            return
        missing = [
            name for name, value in {
                "SUPABASE_URL": self.supabase_url,
                "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
                "SUPABASE_JWT_SECRET": self.supabase_jwt_secret,
                "ALLOWED_ORIGINS": self.allowed_origins,
            }.items() if not value
        ]
        if missing:
            raise ValueError(f"Missing required production configuration: {', '.join(missing)}")
        if scanner_provider in {"openai", "nvidia"} and not self.ai_model_api_key:
            raise ValueError(
                "AI_MODEL_API_KEY is required when AI_MODEL_PROVIDER is openai or nvidia"
            )
        if self.effective_chat_provider in {"openai", "nvidia", "groq"} and not self.effective_chat_api_key:
            raise ValueError(
                "CHAT_MODEL_API_KEY or AI_MODEL_API_KEY is required for the configured chat provider"
            )
        if self.effective_chat_provider == "groq" and not self.groq_base_url.startswith("https://"):
            raise ValueError("GROQ_BASE_URL must use HTTPS in production")
        if self.allowed_origins.strip() == "*":
            raise ValueError("ALLOWED_ORIGINS must not be '*' in production")


settings = Settings()
