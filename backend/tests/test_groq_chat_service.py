import asyncio

import pytest

from app.config import settings
from app.services.chatbot_service import ChatbotService
from app.services.groq_chat_service import GroqChatService
from app.services.groq_chat_service import GroqChatResult
from app.schemas.chatbot import ChatContext


def test_groq_requires_a_server_side_key(monkeypatch) -> None:
    monkeypatch.setattr(settings, "chat_model_provider", "groq")
    monkeypatch.setattr(settings, "chat_model_api_key", "")

    with pytest.raises(RuntimeError, match="CHAT_MODEL_API_KEY"):
        asyncio.run(
            GroqChatService().create_text(
                instructions="Be concise.",
                input_content="Suggest lunch.",
            )
        )


def test_groq_payload_uses_current_openai_compatible_chat_shape(monkeypatch) -> None:
    captured: dict = {}

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            return {
                "model": "openai/gpt-oss-20b",
                "choices": [{"message": {"content": "Try chicken adobo with vegetables."}}],
            }

    class FakeClient:
        def __init__(self, **_kwargs) -> None:
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args) -> None:
            return None

        async def post(self, url, headers, json):
            captured["url"] = url
            captured["headers"] = headers
            captured["json"] = json
            return FakeResponse()

    monkeypatch.setattr("app.services.groq_chat_service.httpx.AsyncClient", FakeClient)
    monkeypatch.setattr(settings, "chat_model_provider", "groq")
    monkeypatch.setattr(settings, "chat_model_api_key", "test-groq-key")
    monkeypatch.setattr(settings, "chat_model_name", "openai/gpt-oss-20b")

    result = asyncio.run(
        GroqChatService().create_text(
            instructions="Be concise and budget-aware.",
            input_content="Suggest a lunch.",
            max_output_tokens=120,
        )
    )

    assert result.text == "Try chicken adobo with vegetables."
    assert result.model == "openai/gpt-oss-20b"
    assert captured["url"] == "https://api.groq.com/openai/v1/chat/completions"
    assert captured["headers"]["Authorization"] == "Bearer test-groq-key"
    payload = captured["json"]
    assert payload["model"] == "openai/gpt-oss-20b"
    assert payload["stream"] is False
    assert payload["max_tokens"] == 120
    assert payload["messages"] == [
        {"role": "system", "content": "Be concise and budget-aware."},
        {"role": "user", "content": "Suggest a lunch."},
    ]


def test_chatbot_uses_groq_without_changing_scanner_provider(monkeypatch) -> None:
    monkeypatch.setattr(settings, "ai_model_provider", "nvidia")
    monkeypatch.setattr(settings, "chat_model_provider", "groq")
    monkeypatch.setattr(settings, "chat_model_api_key", "test-groq-key")
    monkeypatch.setattr(settings, "chat_model_name", "openai/gpt-oss-20b")
    service = ChatbotService()
    captured: dict = {}

    async def fake_create_text(**kwargs) -> GroqChatResult:
        captured.update(kwargs)
        return GroqChatResult(
            text="Use a balanced Filipino meal within your budget.",
            model="openai/gpt-oss-20b",
        )

    monkeypatch.setattr(service._groq, "create_text", fake_create_text)

    result = asyncio.run(
        service.get_response(
            "Suggest lunch",
            ChatContext(
                fitness_goal="weight_loss",
                remaining_budget_php=120,
                remaining_calories=600,
                remaining_protein_g=35.5,
                allergies=["peanuts"],
                dietary_restrictions=["low sodium"],
            ),
        )
    )

    assert "balanced Filipino meal" in result.reply
    assert settings.ai_model_provider == "nvidia"
    assert "remaining daily food budget: PHP 120.00" in captured["input_content"]
    assert "remaining protein: 35.5 g" in captured["input_content"]
    assert "allergies: peanuts" in captured["input_content"]
    assert "dietary restrictions: low sodium" in captured["input_content"]
