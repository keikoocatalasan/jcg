import uuid
from dataclasses import dataclass, field

from app.config import settings
from app.schemas.scan_food import ScanCandidate, ScanComponent
from app.services.nvidia_chat_service import NvidiaChatService
from app.services.openai_responses_service import OpenAIResponsesService


@dataclass
class ScanResult:
    client_scan_id: str
    candidates: list[ScanCandidate] = field(default_factory=list)
    components: list[ScanComponent] = field(default_factory=list)
    composition_confidence: float | None = None
    quality_flags: list[str] = field(default_factory=list)


class ScannerService:
    def __init__(self) -> None:
        self._openai = OpenAIResponsesService()
        self._nvidia = NvidiaChatService()

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
        if settings.ai_model_provider.lower() == "nvidia":
            return await self._scan_with_nvidia(
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

        return ScanResult(
            client_scan_id=scan_id,
            candidates=mock_candidates,
            components=[self._component_from_candidate(mock_candidates[0], scan_id)],
            composition_confidence=0.70,
            quality_flags=["portion_required"],
        )

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
                "confidence": {"type": "number", "minimum": 0, "maximum": 1},
                "rank_number": {"type": "integer", "minimum": 1, "maximum": 3},
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
        return ScanResult(
            client_scan_id=scan_id,
            candidates=candidates,
            components=[
                self._component_from_candidate(candidates[0], scan_id)
            ] if candidates else [],
            composition_confidence=0.55 if candidates else None,
            quality_flags=["portion_required"] if candidates else ["no_candidate"],
        )

    async def _scan_with_nvidia(
        self,
        scan_id: str,
        image_bytes: bytes,
        media_type: str,
        meal_type: str | None,
    ) -> ScanResult:
        text = await self._nvidia.create_text(
            instructions=(
                "Analyze this Filipino meal photo. Return exactly one line in this format: "
                "dish=<one short canonical dish name>; rice=<yes|no|unknown>; "
                "extras=<none or comma-separated visible side names>. Do not add markdown "
                "or explanations. If the image is not food or you are unsure, set dish=unknown. "
                "Do not estimate grams or nutrition."
            ),
            input_content=[
                {"type": "text", "text": f"Meal type: {meal_type or 'unknown'}"},
                self._nvidia.image_content(image_bytes, media_type),
            ],
            max_output_tokens=900,
        )
        food_name, rice_present, extras = self._parse_nvidia_scan_text(text.text)
        if not food_name or food_name.lower() == "unknown":
            return ScanResult(
                client_scan_id=scan_id,
                candidates=[],
                components=[],
                quality_flags=["unknown_or_unsupported", "manual_confirmation_required"],
            )
        candidate = ScanCandidate(
            food_id=None,
            food_name=food_name,
            confidence=0.59,
            rank_number=1,
            calories=None,
            protein_g=None,
            carbs_g=None,
            fat_g=None,
            estimated_cost_php=None,
        )
        components = [
            ScanComponent(
                component_id=self._component_id(scan_id, "ulam"),
                role="ulam",
                food_name=food_name,
                confidence=0.59,
            )
        ]
        if rice_present is True:
            components.append(
                ScanComponent(
                    component_id=self._component_id(scan_id, "rice"),
                    role="rice",
                    food_name="Cooked White Rice",
                    confidence=0.59,
                )
            )
        for index, extra in enumerate(extras, start=1):
            components.append(
                ScanComponent(
                    component_id=self._component_id(scan_id, f"extra-{index}"),
                    role="side",
                    food_name=extra,
                    confidence=0.50,
                )
            )
        quality_flags = ["portion_required", "manual_confirmation_required"]
        if rice_present is None:
            quality_flags.append("rice_presence_uncertain")
        return ScanResult(
            client_scan_id=scan_id,
            candidates=[candidate],
            components=components,
            composition_confidence=0.59,
            quality_flags=quality_flags,
        )

    @classmethod
    def _parse_nvidia_scan_text(cls, text: str) -> tuple[str, bool | None, list[str]]:
        """Parse the compact non-JSON contract used by the NVIDIA VLM.

        Structured output is not assumed for this provider. Plain dish-name output
        remains valid for older deployments and mocked tests.
        """

        line = text.strip().splitlines()[0] if text.strip() else ""
        fields: dict[str, str] = {}
        if "dish=" in line.lower():
            for part in line.split(";"):
                if "=" not in part:
                    continue
                key, value = part.split("=", 1)
                fields[key.strip().lower()] = value.strip()
        food_name = cls._clean_nvidia_food_name(fields.get("dish", line))
        rice_value = fields.get("rice", "").lower()
        rice_present: bool | None
        if rice_value in {"yes", "true", "present"}:
            rice_present = True
        elif rice_value in {"no", "false", "absent"}:
            rice_present = False
        else:
            rice_present = None
        extras_value = fields.get("extras", "")
        extras = [
            value.strip()
            for value in extras_value.split(",")
            if value.strip() and value.strip().lower() not in {"none", "unknown"}
        ][:3]
        return food_name, rice_present, extras

    @staticmethod
    def _component_from_candidate(
        candidate: ScanCandidate,
        scan_id: str,
    ) -> ScanComponent:
        lowered = candidate.food_name.lower()
        role = "rice" if "rice" in lowered else "ulam"
        return ScanComponent(
            component_id=ScannerService._component_id(scan_id, "component-1"),
            role=role,
            food_id=candidate.food_id,
            food_name=candidate.food_name,
            confidence=candidate.confidence,
            reference_grams=candidate.serving_grams,
            calories=candidate.calories,
            protein_g=candidate.protein_g,
            carbs_g=candidate.carbs_g,
            fat_g=candidate.fat_g,
            estimated_cost_php=candidate.estimated_cost_php,
        )

    @staticmethod
    def _component_id(scan_id: str, suffix: str) -> str:
        return str(uuid.uuid5(uuid.NAMESPACE_URL, f"jcg-scan:{scan_id}:{suffix}"))

    @staticmethod
    def _clean_nvidia_food_name(text: str) -> str:
        value = text.strip().splitlines()[0] if text.strip() else ""
        if value.startswith("```"):
            value = value.strip("`").strip()
        for prefix in (
            "the dish shown is ",
            "the dish is ",
            "this is ",
            "likely dish: ",
            "food: ",
            "answer: ",
        ):
            if value.lower().startswith(prefix):
                value = value[len(prefix):].strip()
                break
        return value.rstrip(".!?;:").strip().strip('"\'')
