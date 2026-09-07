import asyncio
from dataclasses import dataclass

import httpx

from app.config import settings


@dataclass(frozen=True)
class GroqChatResult:
    text: str
    model: str | None = None


class GroqChatService:
    """Small, dependency-light client for Groq's OpenAI-compatible chat API."""

    async def create_text(
        self,
        *,
        instructions: str,
        input_content: str,
        max_output_tokens: int | None = None,
    ) -> GroqChatResult:
        api_key = settings.effective_chat_api_key
        if not api_key:
            raise RuntimeError(
                "CHAT_MODEL_API_KEY or AI_MODEL_API_KEY is required for the Groq provider"
            )

        body: dict = {
            "model": settings.effective_chat_model,
            "messages": [
                {"role": "system", "content": instructions},
                {"role": "user", "content": input_content},
            ],
            "temperature": 0.2,
            "stream": False,
        }
        if max_output_tokens is not None:
            body["max_tokens"] = max_output_tokens

        async with httpx.AsyncClient(timeout=settings.ai_request_timeout_seconds) as client:
            for attempt in range(2):
                try:
                    response = await client.post(
                        f"{settings.groq_base_url.rstrip('/')}/chat/completions",
                        headers={
                            "Authorization": f"Bearer {api_key}",
                            "Accept": "application/json",
                            "Content-Type": "application/json",
                        },
                        json=body,
                    )
                    response.raise_for_status()
                    try:
                        payload = response.json()
                    except ValueError as exc:
                        raise RuntimeError("Groq returned invalid JSON") from exc
                    break
                except httpx.HTTPStatusError as exc:
                    retryable = exc.response.status_code in {429, 500, 502, 503, 504}
                    if attempt == 0 and retryable:
                        await asyncio.sleep(0.75)
                        continue
                    raise

        text = self._extract_text(payload)
        if not text:
            raise RuntimeError("Groq returned no output text")
        return GroqChatResult(text=text, model=payload.get("model"))

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
