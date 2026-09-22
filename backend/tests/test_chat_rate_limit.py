import pytest
from fastapi import HTTPException

from app.config import settings
from app.services.rate_limit_service import InMemoryRateLimiter


def _set_production_settings(monkeypatch) -> None:
    values = {
        "environment": "production",
        "ai_model_provider": "nvidia",
        "chat_model_provider": "inherit",
        "supabase_url": "https://example.supabase.co",
        "supabase_anon_key": "test-anon-key",
        "supabase_service_role_key": "test-service-key",
        "supabase_jwt_secret": "test-jwt-secret",
        "allowed_origins": "https://jcgfit.vercel.app",
        "ai_model_api_key": "test-ai-key",
    }
    for field, value in values.items():
        monkeypatch.setattr(settings, field, value)


def test_chat_rate_limit_is_per_user_and_independent() -> None:
    limiter = InMemoryRateLimiter()
    limiter.check("user-a", limit=1, window_seconds=60)
    limiter.check("user-b", limit=1, window_seconds=60)

    with pytest.raises(HTTPException) as error:
        limiter.check("user-a", limit=1, window_seconds=60)

    assert error.value.status_code == 429


def test_rate_limiter_discards_expired_user_buckets(monkeypatch) -> None:
    now = [100.0]
    monkeypatch.setattr("app.services.rate_limit_service.time.monotonic", lambda: now[0])
    limiter = InMemoryRateLimiter(cleanup_interval=3)
    limiter.check("expired-user", limit=1, window_seconds=60)

    now[0] = 161.0
    limiter.check("active-user", limit=1, window_seconds=60)
    assert "expired-user" in limiter._requests
    limiter.check("next-user", limit=1, window_seconds=60)

    assert "expired-user" not in limiter._requests
    assert "expired-user" not in limiter._window_by_key


def test_production_rejects_deterministic_chat_provider(monkeypatch) -> None:
    _set_production_settings(monkeypatch)
    monkeypatch.setattr(settings, "chat_model_provider", "deterministic")

    with pytest.raises(ValueError, match="CHAT_MODEL_PROVIDER=deterministic"):
        settings.validate_runtime()


def test_production_requires_anon_key_for_authenticated_chat_context(monkeypatch) -> None:
    _set_production_settings(monkeypatch)
    monkeypatch.setattr(settings, "supabase_anon_key", "")

    with pytest.raises(ValueError, match="SUPABASE_ANON_KEY"):
        settings.validate_runtime()


@pytest.mark.parametrize(
    ("field", "value", "expected_error"),
    [
        ("supabase_url", "http://example.supabase.co", "SUPABASE_URL"),
        ("allowed_origins", "http://jcgfit.example", "ALLOWED_ORIGINS"),
        ("allowed_origins", "https://jcgfit.example/path", "ALLOWED_ORIGINS"),
    ],
)
def test_production_requires_secure_supabase_and_cors_urls(
    monkeypatch, field, value, expected_error
) -> None:
    _set_production_settings(monkeypatch)
    monkeypatch.setattr(settings, field, value)

    with pytest.raises(ValueError, match=expected_error):
        settings.validate_runtime()


@pytest.mark.parametrize(
    ("provider", "url_field", "error_name"),
    [
        ("openai", "openai_base_url", "OPENAI_BASE_URL"),
        ("nvidia", "nvidia_base_url", "NVIDIA_BASE_URL"),
        ("groq", "groq_base_url", "GROQ_BASE_URL"),
    ],
)
def test_production_requires_https_for_each_configured_ai_provider(
    monkeypatch, provider, url_field, error_name
) -> None:
    _set_production_settings(monkeypatch)
    monkeypatch.setattr(settings, "ai_model_provider", "nvidia")
    monkeypatch.setattr(settings, "chat_model_provider", provider)
    monkeypatch.setattr(settings, "chat_model_api_key", "test-chat-key")
    monkeypatch.setattr(settings, url_field, "http://provider.example/v1")

    with pytest.raises(ValueError, match=error_name):
        settings.validate_runtime()
