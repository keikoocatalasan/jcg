from dataclasses import dataclass

from app.config import settings
from app.schemas.chatbot import ChatContext
from app.services.nvidia_chat_service import NvidiaChatService
from app.services.openai_responses_service import OpenAIResponsesService


@dataclass
class ChatResult:
    reply: str


class ChatbotService:
    def __init__(self):
        self._openai = OpenAIResponsesService()
        self._nvidia = NvidiaChatService()
        self.blocked_topics = [
            "medical diagnosis",
            "disease treatment",
            "eating disorder",
            "extreme fasting",
            "supplement prescription",
            "dangerous calorie restriction",
        ]

    async def get_response(self, message: str, context: ChatContext | None = None) -> ChatResult:
        context_hint = ""
        if context:
            parts = []
            if context.fitness_goal:
                parts.append(f"fitness goal: {context.fitness_goal}")
            if context.remaining_calories is not None:
                parts.append(f"remaining calories: {context.remaining_calories} kcal")
            if context.dietary_restrictions:
                parts.append(f"dietary restrictions: {', '.join(context.dietary_restrictions)}")
            if parts:
                context_hint = f"\n[Context: {' | '.join(parts)}]"

        if any(topic in message.lower() for topic in self.blocked_topics):
            return ChatResult(
                reply="I can't provide guidance on that. For health concerns, please see a professional."
            )

        provider = settings.ai_model_provider.lower()
        instructions = (
            "You are NutriSmart AI, a concise budget-aware nutrition assistant for "
            "the Filipino market. Use Philippine pesos and familiar Filipino foods. "
            "Respect allergies and dietary restrictions in the supplied context. "
            "Do not diagnose, prescribe treatment, encourage eating disorders, extreme "
            "fasting, or dangerous calorie restriction. Recommend professional care "
            "when health concerns exceed general nutrition education."
        )
        if provider == "openai":
            reply = await self._openai.create_text(
                instructions=instructions,
                input_content=f"{message}{context_hint}",
            )
            return ChatResult(reply=reply)
        if provider == "nvidia":
            result = await self._nvidia.create_text(
                instructions=instructions,
                input_content=f"{message}{context_hint}",
                max_output_tokens=700,
            )
            return ChatResult(reply=result.text)

        return ChatResult(
            reply=f"Here's what I found about your meal:{context_hint}\n\n"
            f"Based on your query, I recommend balanced options. "
            f"Would you like more specific nutritional advice?"
        )
