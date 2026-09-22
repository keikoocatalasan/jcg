import asyncio

from app.config import settings
from app.schemas.chatbot import ChatContext, ChatTurn
from app.services.chatbot_service import ChatbotService
from app.services.nvidia_chat_service import NvidiaChatService


def test_nvidia_payload_uses_openai_compatible_multimodal_shape(monkeypatch) -> None:
    captured: dict = {}

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            return {
                "model": "meta/llama-3.2-11b-vision-instruct",
                "choices": [{"message": {"content": "Adobo"}}],
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

    monkeypatch.setattr(
        "app.services.nvidia_chat_service.httpx.AsyncClient",
        FakeClient,
    )
    monkeypatch.setattr(settings, "ai_model_api_key", "test-nvidia-key")
    monkeypatch.setattr(
        settings,
        "ai_model_name",
        "meta/llama-3.2-11b-vision-instruct",
    )

    result = asyncio.run(
        NvidiaChatService().create_text(
            instructions="Identify the dish.",
            input_content=[
                {"type": "input_text", "text": "Meal type: lunch"},
                {
                    "type": "input_image",
                    "image_url": "data:image/jpeg;base64,abc",
                },
            ],
            max_output_tokens=100,
        )
    )

    assert result.text == "Adobo"
    assert captured["url"] == "https://integrate.api.nvidia.com/v1/chat/completions"
    payload = captured["json"]
    assert payload["model"] == "meta/llama-3.2-11b-vision-instruct"
    assert payload["stream"] is False
    assert payload["max_tokens"] == 100
    assert payload["messages"][0]["content"] == [
        {"type": "text", "text": "Identify the dish."},
        {"type": "text", "text": "Meal type: lunch"},
        {
            "type": "image_url",
            "image_url": {"url": "data:image/jpeg;base64,abc"},
        },
    ]


def test_nvidia_json_parser_accepts_markdown_fenced_output() -> None:
    parsed = NvidiaChatService.parse_json('```json\n{"candidates": []}\n```')

    assert parsed == {"candidates": []}


def test_nvidia_response_extractor_ignores_malformed_choice_shapes() -> None:
    assert NvidiaChatService._extract_text({"choices": [{"message": "bad"}]}) == ""
    assert NvidiaChatService._extract_text({"choices": "bad"}) == ""


def test_nvidia_chat_sends_distinct_system_and_conversation_roles(monkeypatch) -> None:
    captured: dict = {}

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            return {
                "model": "meta/llama-3.2-11b-vision-instruct",
                "choices": [{"message": {"content": "It is a useful protein source."}}],
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

    monkeypatch.setattr(
        "app.services.nvidia_chat_service.httpx.AsyncClient",
        FakeClient,
    )
    monkeypatch.setattr(settings, "chat_model_provider", "inherit")
    monkeypatch.setattr(settings, "ai_model_api_key", "test-nvidia-key")
    monkeypatch.setattr(
        settings,
        "ai_model_name",
        "meta/llama-3.2-11b-vision-instruct",
    )

    result = asyncio.run(
        NvidiaChatService().create_chat(
            messages=[
                {"role": "system", "content": "You are JCG's nutrition assistant."},
                {"role": "user", "content": "What does chicken provide?"},
                {"role": "assistant", "content": "It is a source of protein."},
                {"role": "user", "content": "How about grilled chicken?"},
            ],
            max_output_tokens=150,
        )
    )

    assert result.text == "It is a useful protein source."
    assert captured["url"] == "https://integrate.api.nvidia.com/v1/chat/completions"
    assert captured["headers"]["Authorization"] == "Bearer test-nvidia-key"
    assert captured["json"]["messages"][0]["role"] == "system"
    assert [message["role"] for message in captured["json"]["messages"]] == [
        "system", "user", "assistant", "user"
    ]
    assert captured["json"]["messages"][-1]["content"] == "How about grilled chicken?"
    assert captured["json"]["max_tokens"] == 150


def test_chatbot_does_not_flatten_nvidia_history_into_the_current_prompt(monkeypatch) -> None:
    monkeypatch.setattr(settings, "ai_model_provider", "nvidia")
    monkeypatch.setattr(settings, "chat_model_provider", "inherit")
    service = ChatbotService()
    captured: dict = {}

    async def fake_create_chat(**kwargs):
        captured.update(kwargs)
        return type("Result", (), {"text": "A tailored reply."})()

    monkeypatch.setattr(service._nvidia, "create_chat", fake_create_chat)

    result = asyncio.run(
        service.get_response(
            "What about 200 grams?",
            ChatContext(remaining_calories=500),
            [
                ChatTurn(role="user", content="How many calories are in chicken breast?"),
                ChatTurn(role="assistant", content="The JCG serving lists 165 kcal."),
            ],
        )
    )

    assert result.reply == "A tailored reply."
    messages = captured["messages"]
    assert [message["role"] for message in messages] == [
        "system", "user", "assistant", "user"
    ]
    assert "remaining calories: 500 kcal" in messages[0]["content"]
    assert messages[-1]["content"] == "What about 200 grams?"


def test_nvidia_chat_invalid_json_is_reported_as_provider_failure(monkeypatch) -> None:
    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            raise ValueError("not json")

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
        "app.services.nvidia_chat_service.httpx.AsyncClient",
        FakeClient,
    )
    monkeypatch.setattr(settings, "chat_model_provider", "inherit")
    monkeypatch.setattr(settings, "ai_model_api_key", "test-nvidia-key")

    try:
        asyncio.run(
            NvidiaChatService().create_chat(
                messages=[{"role": "user", "content": "How much protein?"}]
            )
        )
    except RuntimeError as exc:
        assert str(exc) == "NVIDIA provider returned invalid JSON"
    else:
        raise AssertionError("invalid provider JSON must raise a controlled error")
