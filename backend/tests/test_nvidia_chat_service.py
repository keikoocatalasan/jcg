import asyncio

from app.config import settings
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
