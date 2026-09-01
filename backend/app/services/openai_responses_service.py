import base64
import json
from dataclasses import dataclass, field

import httpx

from app.config import settings


@dataclass(frozen=True)
class OpenAISource:
    url: str
    title: str


@dataclass
class OpenAIResponseResult:
    text: str
    response_id: str | None = None
    model: str | None = None
    sources: list[OpenAISource] = field(default_factory=list)


class OpenAIResponsesService:
    async def create(
        self,
        *,
        instructions: str,
        input_content: str | list[dict],
        json_schema: dict | None = None,
        tools: list[dict] | None = None,
        include: list[str] | None = None,
        tool_choice: str | dict | None = None,
        max_output_tokens: int | None = None,
    ) -> OpenAIResponseResult:
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
            "store": False,
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
        if tools:
            body["tools"] = tools
        if include:
            body["include"] = include
        if tool_choice is not None:
            body["tool_choice"] = tool_choice
        if max_output_tokens is not None:
            body["max_output_tokens"] = max_output_tokens

        async with httpx.AsyncClient(
            timeout=settings.ai_request_timeout_seconds,
        ) as client:
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

        text = self._extract_text(payload)
        if not text:
            raise RuntimeError("AI provider returned no output text")
        return OpenAIResponseResult(
            text=text,
            response_id=payload.get("id"),
            model=payload.get("model"),
            sources=self._extract_sources(payload),
        )

    async def create_text(
        self,
        *,
        instructions: str,
        input_content: str | list[dict],
        json_schema: dict | None = None,
    ) -> str:
        result = await self.create(
            instructions=instructions,
            input_content=input_content,
            json_schema=json_schema,
        )
        return result.text

    @staticmethod
    def _extract_text(payload: dict) -> str:
        for output in payload.get("output", []):
            for item in output.get("content", []):
                if item.get("type") == "output_text" and item.get("text"):
                    return item["text"]
        return ""

    @staticmethod
    def _extract_sources(payload: dict) -> list[OpenAISource]:
        found: dict[str, OpenAISource] = {}
        for output in payload.get("output", []):
            action = output.get("action") or {}
            for source in action.get("sources", []) or []:
                url = source.get("url")
                if url:
                    found[url] = OpenAISource(
                        url=url,
                        title=source.get("title") or url,
                    )
            for item in output.get("content", []) or []:
                for annotation in item.get("annotations", []) or []:
                    if annotation.get("type") != "url_citation":
                        continue
                    citation = annotation.get("url_citation") or annotation
                    url = citation.get("url")
                    if url:
                        found[url] = OpenAISource(
                            url=url,
                            title=citation.get("title") or url,
                        )
        return list(found.values())

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
