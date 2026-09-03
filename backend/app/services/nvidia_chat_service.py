import base64
import asyncio
import json
from dataclasses import dataclass

import httpx

from app.config import settings


@dataclass(frozen=True)
class NvidiaChatResult:
    text: str
    model: str | None = None


class NvidiaChatService:
    """Small client for NVIDIA's OpenAI-compatible serverless endpoint."""

    async def create_text(
        self,
        *,
        instructions: str,
        input_content: str | list[dict],
        max_output_tokens: int | None = None,
    ) -> NvidiaChatResult:
        if not settings.ai_model_api_key:
            raise RuntimeError("AI_MODEL_API_KEY is required for the NVIDIA provider")

        body: dict = {
            "model": settings.ai_model_name,
            "messages": [
                {
                    "role": "user",
                    "content": self._to_chat_content(
                        instructions,
                        input_content,
                    ),
                },
            ],
            "temperature": 0.2,
            "stream": False,
        }
        if max_output_tokens is not None:
            body["max_tokens"] = max_output_tokens

        async with httpx.AsyncClient(
            timeout=settings.ai_request_timeout_seconds,
        ) as client:
            for attempt in range(2):
                try:
                    response = await client.post(
                        f"{settings.nvidia_base_url.rstrip('/')}/chat/completions",
                        headers={
                            "Authorization": f"Bearer {settings.ai_model_api_key}",
                            "Accept": "application/json",
                            "Content-Type": "application/json",
                        },
                        json=body,
                    )
                    response.raise_for_status()
                    payload = response.json()
                    break
                except httpx.HTTPStatusError as exc:
                    retryable = exc.response.status_code in {429, 500, 502, 503, 504}
                    if attempt == 0 and retryable:
                        await asyncio.sleep(0.75)
                        continue
                    raise

        text = self._extract_text(payload)
        if not text:
            raise RuntimeError("NVIDIA provider returned no output text")
        return NvidiaChatResult(text=text, model=payload.get("model"))

    @staticmethod
    def image_content(image_bytes: bytes, media_type: str) -> dict:
        encoded = base64.b64encode(image_bytes).decode("ascii")
        return {
            "type": "image_url",
            "image_url": {
                "url": f"data:{media_type};base64,{encoded}",
            },
        }

    @staticmethod
    def _to_chat_content(
        instructions: str,
        input_content: str | list[dict],
    ) -> list[dict]:
        content: list[dict] = [{"type": "text", "text": instructions}]
        if isinstance(input_content, str):
            content.append({"type": "text", "text": input_content})
            return content

        for item in input_content:
            item_type = item.get("type")
            if item_type in {"input_text", "text"}:
                text = item.get("text")
                if text:
                    content.append({"type": "text", "text": text})
                continue

            if item_type in {"input_image", "image_url"}:
                image_url = item.get("image_url")
                if isinstance(image_url, dict):
                    image_url = image_url.get("url")
                if image_url:
                    content.append(
                        {
                            "type": "image_url",
                            "image_url": {"url": image_url},
                        }
                    )

        return content

    @staticmethod
    def _extract_text(payload: dict) -> str:
        choices = payload.get("choices") or []
        if not choices:
            return ""
        message = choices[0].get("message") or {}
        content = message.get("content")
        if isinstance(content, str):
            return content.strip()
        if isinstance(content, list):
            parts = [
                item.get("text", "")
                for item in content
                if isinstance(item, dict) and item.get("text")
            ]
            return "".join(parts).strip()
        return ""

    @staticmethod
    def parse_json(text: str) -> dict:
        """Parse strict JSON and tolerate a model's accidental markdown fence."""
        cleaned = text.strip()
        if cleaned.startswith("```"):
            lines = cleaned.splitlines()
            cleaned = "\n".join(lines[1:-1]).strip()
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            start = cleaned.find("{")
            end = cleaned.rfind("}")
            if start < 0 or end <= start:
                raise
            return json.loads(cleaned[start : end + 1])
