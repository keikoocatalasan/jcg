from uuid import UUID

from typing import Literal

from pydantic import BaseModel, Field


ComponentRole = Literal[
    "ulam",
    "rice",
    "vegetable",
    "soup",
    "side",
    "drink",
    "sauce",
    "dessert",
    "unknown",
]

PortionMethod = Literal[
    "not_provided",
    "user_input",
    "serving_preset",
    "visual_estimate",
]


class ScanCandidate(BaseModel):
    food_id: str | None
    food_name: str
    confidence: float = Field(ge=0, le=1)
    rank_number: int = Field(ge=1, le=3)
    calories: float | None
    protein_g: float | None
    carbs_g: float | None
    fat_g: float | None
    estimated_cost_php: float | None
    serving_grams: float | None = Field(default=None, gt=0, le=5000)


class ScanComponent(BaseModel):
    """One visually separate item on a plate or in a meal photo.

    Nutrition remains nullable until a catalog food and a portion are confirmed.
    The vision model is never treated as the nutrition source of truth.
    """

    component_id: str = Field(min_length=1, max_length=80)
    role: ComponentRole = "unknown"
    food_id: str | None = None
    food_name: str = Field(min_length=1, max_length=150)
    confidence: float = Field(ge=0, le=1)
    alternatives: list[str] = Field(default_factory=list, max_length=3)
    reference_grams: float | None = Field(default=None, gt=0, le=5000)
    grams: float | None = Field(default=None, gt=0, le=5000)
    portion_method: PortionMethod = "not_provided"
    portion_confidence: float | None = Field(default=None, ge=0, le=1)
    calories: float | None = Field(default=None, ge=0)
    protein_g: float | None = Field(default=None, ge=0)
    carbs_g: float | None = Field(default=None, ge=0)
    fat_g: float | None = Field(default=None, ge=0)
    estimated_cost_php: float | None = Field(default=None, ge=0)


class ScanFoodResponse(BaseModel):
    client_scan_id: str
    status: str
    manual_search_recommended: bool = False
    candidates: list[ScanCandidate] = Field(default_factory=list)
    pipeline_version: str = "scanner-v2"
    composition_confidence: float | None = Field(default=None, ge=0, le=1)
    components: list[ScanComponent] = Field(default_factory=list)
    needs_portion_input: bool = False
    quality_flags: list[str] = Field(default_factory=list)
    messages: list[str] = Field(default_factory=list)


class ScanFeedbackRequest(BaseModel):
    feedback_id: UUID | None = None
    client_scan_id: UUID
    selected_food_id: str | None = None
    was_helpful: bool
    feedback_text: str | None = None
