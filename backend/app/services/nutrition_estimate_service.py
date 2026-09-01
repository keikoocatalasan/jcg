import uuid

from app.config import settings
from app.schemas.nutrition_estimate import (
    NutritionEstimatePayload,
    NutritionEstimateRequest,
    NutritionEstimateResult,
    NutritionSource,
)
from app.services.openai_responses_service import OpenAIResponsesService


class NutritionEstimateService:
    def __init__(self) -> None:
        self._openai = OpenAIResponsesService()

    async def estimate(
        self,
        request: NutritionEstimateRequest,
    ) -> NutritionEstimateResult:
        if settings.ai_model_provider.lower() != "openai":
            return self._deterministic_estimate(request)

        schema = {
            "type": "object",
            "properties": {
                "food_name": {"type": "string"},
                "serving_label": {"type": "string"},
                "serving_grams": {"type": "number"},
                "calories": {"type": "number"},
                "protein_g": {"type": "number"},
                "carbs_g": {"type": "number"},
                "fat_g": {"type": "number"},
                "suggested_meal_types": {
                    "type": "array",
                    "minItems": 1,
                    "maxItems": 4,
                    "items": {
                        "type": "string",
                        "enum": ["breakfast", "lunch", "dinner", "snack"],
                    },
                },
                "confidence": {"type": "number", "minimum": 0, "maximum": 1},
                "warnings": {"type": "array", "items": {"type": "string"}},
            },
            "required": [
                "food_name",
                "serving_label",
                "serving_grams",
                "calories",
                "protein_g",
                "carbs_g",
                "fat_g",
                "suggested_meal_types",
                "confidence",
                "warnings",
            ],
            "additionalProperties": False,
        }
        tools: list[dict] = []
        include: list[str] = []
        if settings.ai_web_search_enabled:
            web_search: dict = {"type": "web_search", "search_context_size": "low"}
            if settings.ai_allowed_domains_list:
                web_search["filters"] = {
                    "allowed_domains": settings.ai_allowed_domains_list,
                }
            tools.append(web_search)
            include.append("web_search_call.action.sources")

        result = await self._openai.create(
            instructions=(
                "Estimate nutrition for the exact serving supplied by an administrator. "
                "Prefer authoritative nutrition sources, distinguish prepared dishes from "
                "raw ingredients, avoid false precision, and return review warnings when "
                "ingredients or preparation are ambiguous. Suggest only breakfast, lunch, "
                "dinner, or snack meal types."
            ),
            input_content=(
                f"Food: {request.food_name}\n"
                f"Category: {request.category_name}\n"
                f"Serving: {request.serving_label} ({request.serving_grams:g} g)\n"
                f"Description: {request.description or 'not provided'}"
            ),
            json_schema=schema,
            tools=tools or None,
            include=include or None,
            tool_choice="auto" if tools else None,
            max_output_tokens=1200,
        )
        payload = NutritionEstimatePayload.model_validate(
            self._openai.parse_json(result.text)
        )
        warnings = list(payload.warnings)
        self._append_consistency_warning(payload, warnings)
        sources = [
            NutritionSource(title=source.title, url=source.url)
            for source in result.sources
        ]
        if settings.ai_web_search_enabled and not sources:
            warnings.append("No web source citation was returned; verify manually.")
        return NutritionEstimateResult(
            **payload.model_dump(exclude={"warnings"}),
            estimate_id=str(uuid.uuid4()),
            warnings=warnings,
            sources=sources,
            provider="openai",
            model=result.model or settings.ai_model_name,
        )

    @staticmethod
    def _append_consistency_warning(
        payload: NutritionEstimatePayload,
        warnings: list[str],
    ) -> None:
        macro_calories = (
            payload.protein_g * 4 + payload.carbs_g * 4 + payload.fat_g * 9
        )
        difference = abs(payload.calories - macro_calories) / max(payload.calories, 1)
        if difference > 0.35:
            warnings.append(
                "Calories differ substantially from the supplied macronutrients."
            )

    @staticmethod
    def _deterministic_estimate(
        request: NutritionEstimateRequest,
    ) -> NutritionEstimateResult:
        grams = request.serving_grams
        protein = round(grams * 0.12, 1)
        carbs = round(grams * 0.15, 1)
        fat = round(grams * 0.05, 1)
        calories = round(protein * 4 + carbs * 4 + fat * 9, 1)
        category_meals = {
            "Dairy and Eggs": ["breakfast", "snack"],
            "Bread and Pastry": ["breakfast", "snack"],
            "Fruits": ["breakfast", "snack"],
            "Snacks and Desserts": ["snack"],
            "Beverages": ["breakfast", "snack"],
        }
        return NutritionEstimateResult(
            estimate_id=str(uuid.uuid4()),
            food_name=request.food_name,
            serving_label=request.serving_label,
            serving_grams=request.serving_grams,
            calories=calories,
            protein_g=protein,
            carbs_g=carbs,
            fat_g=fat,
            suggested_meal_types=category_meals.get(
                request.category_name,
                ["lunch", "dinner"],
            ),
            confidence=0.35,
            warnings=[
                "Deterministic demo estimate only; verify nutrition before saving."
            ],
            sources=[],
            provider="deterministic",
            model="deterministic-demo",
        )
