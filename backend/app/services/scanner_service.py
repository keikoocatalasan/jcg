import uuid
from dataclasses import dataclass, field

from app.config import settings
from app.schemas.scan_food import ScanCandidate
from app.services.openai_responses_service import OpenAIResponsesService


@dataclass
class ScanResult:
    client_scan_id: str
    candidates: list[ScanCandidate] = field(default_factory=list)


class ScannerService:
    def __init__(self) -> None:
        self._openai = OpenAIResponsesService()

    async def scan_image(
        self,
        image_bytes: bytes,
        meal_type: str | None = None,
        client_scan_id: str | None = None,
        media_type: str = "image/jpeg",
    ) -> ScanResult:
        scan_id = client_scan_id or str(uuid.uuid4())

        if settings.ai_model_provider.lower() == "openai":
            return await self._scan_with_openai(
                scan_id, image_bytes, media_type, meal_type
            )

        # Stable local mode for offline demos and automated tests.
        mock_candidates = [
            ScanCandidate(
                food_id=None,
                food_name="White Rice (cooked)",
                confidence=0.87,
                rank_number=1,
                calories=206.0,
                protein_g=4.2,
                carbs_g=45.0,
                fat_g=0.4,
                estimated_cost_php=15.0,
            ),
            ScanCandidate(
                food_id=None,
                food_name="Fried Rice",
                confidence=0.65,
                rank_number=2,
                calories=333.0,
                protein_g=7.0,
                carbs_g=55.0,
                fat_g=9.0,
                estimated_cost_php=35.0,
            ),
            ScanCandidate(
                food_id=None,
                food_name="Steamed Rice",
                confidence=0.45,
                rank_number=3,
                calories=170.0,
                protein_g=3.5,
                carbs_g=37.0,
                fat_g=0.3,
                estimated_cost_php=12.0,
            ),
        ]

        return ScanResult(client_scan_id=scan_id, candidates=mock_candidates)

    async def _scan_with_openai(
        self,
        scan_id: str,
        image_bytes: bytes,
        media_type: str,
        meal_type: str | None,
    ) -> ScanResult:
        candidate_schema = {
            "type": "object",
            "properties": {
                "food_id": {"type": ["string", "null"]},
                "food_name": {"type": "string"},
                "confidence": {"type": "number"},
                "rank_number": {"type": "integer"},
                "calories": {"type": ["number", "null"]},
                "protein_g": {"type": ["number", "null"]},
                "carbs_g": {"type": ["number", "null"]},
                "fat_g": {"type": ["number", "null"]},
                "estimated_cost_php": {"type": ["number", "null"]},
            },
            "required": [
                "food_id", "food_name", "confidence", "rank_number",
                "calories", "protein_g", "carbs_g", "fat_g",
                "estimated_cost_php",
            ],
            "additionalProperties": False,
        }
        schema = {
            "type": "object",
            "properties": {
                "candidates": {
                    "type": "array",
                    "minItems": 1,
                    "maxItems": 3,
                    "items": candidate_schema,
                }
            },
            "required": ["candidates"],
            "additionalProperties": False,
        }
        text = await self._openai.create_text(
            instructions=(
                "Identify likely Filipino foods in the image. Return up to three ranked "
                "candidates with nutrition per visible serving and estimated Philippine-peso "
                "cost. Use null food_id because catalog IDs are unavailable. Keep confidence "
                "between 0 and 1 and do not invent certainty when the image is unclear."
            ),
            input_content=[
                {"type": "input_text", "text": f"Meal type: {meal_type or 'unknown'}"},
                self._openai.image_content(image_bytes, media_type),
            ],
            json_schema=schema,
        )
        data = self._openai.parse_json(text)
        candidates = [
            ScanCandidate.model_validate(candidate)
            for candidate in data["candidates"]
        ]
        return ScanResult(client_scan_id=scan_id, candidates=candidates)
