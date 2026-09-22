import asyncio

import pytest

from app.config import settings
from app.services.chatbot_service import ChatbotService
from app.services.openai_responses_service import OpenAIResponsesService


def test_openai_chat_uses_chat_credentials_without_changing_scanner_config(monkeypatch) -> None:
    captured: dict = {}

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            return {
                "id": "resp-chat-test",
                "model": "chat-model-test",
                "output": [
                    {"content": [{"type": "output_text", "text": "A tailored reply."}]}
                ],
            }

    class FakeClient:
        def __init__(self, **_kwargs) -> None:
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args) -> None:
            return None

        async def post(self, url, headers, json):
            captured.update(url=url, headers=headers, body=json)
            return FakeResponse()

    monkeypatch.setattr(
        "app.services.openai_responses_service.httpx.AsyncClient", FakeClient
    )
    monkeypatch.setattr(settings, "ai_model_provider", "nvidia")
    monkeypatch.setattr(settings, "ai_model_api_key", "scanner-secret")
    monkeypatch.setattr(settings, "ai_model_name", "scanner-vision-model")
    monkeypatch.setattr(settings, "chat_model_provider", "openai")
    monkeypatch.setattr(settings, "chat_model_api_key", "chat-secret")
    monkeypatch.setattr(settings, "chat_model_name", "chat-model-test")
    monkeypatch.setattr(settings, "openai_base_url", "https://openai.example/v1")

    result = asyncio.run(ChatbotService().get_response("Suggest lunch"))

    assert result.reply == "A tailored reply."
    assert captured["url"] == "https://openai.example/v1/responses"
    assert captured["headers"]["Authorization"] == "Bearer chat-secret"
    assert captured["body"]["model"] == "chat-model-test"
    assert settings.ai_model_provider == "nvidia"
    assert settings.ai_model_api_key == "scanner-secret"
    assert settings.ai_model_name == "scanner-vision-model"


def test_openai_provider_invalid_json_raises_controlled_error(monkeypatch) -> None:
    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            raise ValueError("invalid json body")

    class FakeClient:
        def __init__(self, **_kwargs) -> None:
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args) -> None:
            return None

        async def post(self, *_args, **_kwargs):
            return FakeResponse()

    monkeypatch.setattr(
        "app.services.openai_responses_service.httpx.AsyncClient", FakeClient
    )
    monkeypatch.setattr(settings, "ai_model_api_key", "test-key")

    with pytest.raises(RuntimeError, match="OpenAI provider returned invalid JSON"):
        asyncio.run(
            OpenAIResponsesService().create_text(
                instructions="Be helpful.",
                input_content="Suggest lunch.",
            )
        )
