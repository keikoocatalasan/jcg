from uuid import UUID

from pydantic import BaseModel


class ScanCandidate(BaseModel):
    food_id: str | None
    food_name: str
    confidence: float
    rank_number: int
    calories: float | None
    protein_g: float | None
    carbs_g: float | None
    fat_g: float | None
    estimated_cost_php: float | None


class ScanFoodResponse(BaseModel):
    client_scan_id: str
    status: str
    manual_search_recommended: bool = False
    candidates: list[ScanCandidate] = []


class ScanFeedbackRequest(BaseModel):
    feedback_id: UUID | None = None
    client_scan_id: UUID
    selected_food_id: str | None = None
    was_helpful: bool
    feedback_text: str | None = None
