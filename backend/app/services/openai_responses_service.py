import base64
import json

import httpx

from app.config import settings


class OpenAIResponsesService:
    async def create_text(
        self,
        *,
        instructions: str,
        input_content: str | list[dict],
        json_schema: dict | None = None,
    ) -> str:
        if not settings.ai_model_api_key:
            raise RuntimeError("AI_MODEL_API_KEY is required for the OpenAI provider")

        content = (
            [{"type": "input_text", "text": input_content}]
            if isinstance(input_content, str)
            else input_content
        )
        body: dict = {
            "model": settings.ai_model_name,
            "instructions": instructions,
            "input": [{"role": "user", "content": content}],
        }
        if json_schema is not None:
            body["text"] = {
                "format": {
                    "type": "json_schema",
                    "name": "nutrismart_response",
                    "strict": True,
                    "schema": json_schema,
                }
            }

        async with httpx.AsyncClient(timeout=settings.ai_request_timeout_seconds) as client:
            response = await client.post(
                f"{settings.openai_base_url.rstrip('/')}/responses",
                headers={
                    "Authorization": f"Bearer {settings.ai_model_api_key}",
                    "Content-Type": "application/json",
                },
                json=body,
            )
            response.raise_for_status()
            payload = response.json()

        for output in payload.get("output", []):
            for item in output.get("content", []):
                if item.get("type") == "output_text" and item.get("text"):
                    return item["text"]
        raise RuntimeError("AI provider returned no output text")

    @staticmethod
    def image_content(image_bytes: bytes, media_type: str) -> dict:
        encoded = base64.b64encode(image_bytes).decode("ascii")
        return {
            "type": "input_image",
            "image_url": f"data:{media_type};base64,{encoded}",
        }

    @staticmethod
    def parse_json(text: str) -> dict:
        return json.loads(text)
