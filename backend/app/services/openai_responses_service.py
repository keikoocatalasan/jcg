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
        api_key: str | None = None,
        model: str | None = None,
        base_url: str | None = None,
        json_schema: dict | None = None,
        tools: list[dict] | None = None,
        include: list[str] | None = None,
        tool_choice: str | dict | None = None,
        max_output_tokens: int | None = None,
    ) -> OpenAIResponseResult:
        selected_api_key = api_key if api_key is not None else settings.ai_model_api_key
        selected_model = model if model is not None else settings.ai_model_name
        selected_base_url = base_url if base_url is not None else settings.openai_base_url
        if not selected_api_key:
            raise RuntimeError("An API key is required for the OpenAI provider")

        content = (
            [{"type": "input_text", "text": input_content}]
            if isinstance(input_content, str)
            else input_content
        )
        body: dict = {
            "model": selected_model,
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
                f"{selected_base_url.rstrip('/')}/responses",
                headers={
                    "Authorization": f"Bearer {selected_api_key}",
                    "Content-Type": "application/json",
                },
                json=body,
            )
            response.raise_for_status()
            try:
                payload = response.json()
            except ValueError as exc:
                raise RuntimeError("OpenAI provider returned invalid JSON") from exc

        if not isinstance(payload, dict):
            raise RuntimeError("OpenAI provider returned an invalid response")

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
        api_key: str | None = None,
        model: str | None = None,
        base_url: str | None = None,
        json_schema: dict | None = None,
    ) -> str:
        result = await self.create(
            instructions=instructions,
            input_content=input_content,
            api_key=api_key,
            model=model,
            base_url=base_url,
            json_schema=json_schema,
        )
        return result.text

    @staticmethod
    def _extract_text(payload: dict) -> str:
        outputs = payload.get("output")
        if not isinstance(outputs, list):
            return ""
        for output in outputs:
            if not isinstance(output, dict):
                continue
            content = output.get("content")
            if not isinstance(content, list):
                continue
            for item in content:
                if not isinstance(item, dict):
                    continue
                text = item.get("text")
                if item.get("type") == "output_text" and isinstance(text, str) and text.strip():
                    return text
        return ""

    @staticmethod
    def _extract_sources(payload: dict) -> list[OpenAISource]:
        found: dict[str, OpenAISource] = {}
        outputs = payload.get("output")
        if not isinstance(outputs, list):
            return []
        for output in outputs:
            if not isinstance(output, dict):
                continue
            action = output.get("action") or {}
            if not isinstance(action, dict):
                action = {}
            sources = action.get("sources")
            if not isinstance(sources, list):
                sources = []
            for source in sources:
                if not isinstance(source, dict):
                    continue
                url = source.get("url")
                if url:
                    found[url] = OpenAISource(
                        url=url,
                        title=source.get("title") or url,
                    )
            content = output.get("content")
            if not isinstance(content, list):
                continue
            for item in content:
                if not isinstance(item, dict):
                    continue
                annotations = item.get("annotations")
                if not isinstance(annotations, list):
                    continue
                for annotation in annotations:
                    if not isinstance(annotation, dict):
                        continue
                    if annotation.get("type") != "url_citation":
                        continue
                    citation = annotation.get("url_citation") or annotation
                    if not isinstance(citation, dict):
                        continue
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
