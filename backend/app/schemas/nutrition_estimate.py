from pydantic import BaseModel, Field, field_validator


MEAL_TYPES = {"breakfast", "lunch", "dinner", "snack"}


class NutritionEstimateRequest(BaseModel):
    food_name: str = Field(min_length=2, max_length=150)
    category_name: str = Field(min_length=2, max_length=100)
    serving_label: str = Field(min_length=1, max_length=100)
    serving_grams: float = Field(gt=0, le=5000)
    description: str | None = Field(default=None, max_length=500)


class NutritionSource(BaseModel):
    title: str
    url: str


class NutritionEstimatePayload(BaseModel):
    food_name: str
    serving_label: str
    serving_grams: float = Field(gt=0, le=5000)
    calories: float = Field(ge=0, le=10000)
    protein_g: float = Field(ge=0, le=2000)
    carbs_g: float = Field(ge=0, le=2000)
    fat_g: float = Field(ge=0, le=2000)
    suggested_meal_types: list[str] = Field(min_length=1, max_length=4)
    confidence: float = Field(ge=0, le=1)
    warnings: list[str] = Field(default_factory=list)

    @field_validator("suggested_meal_types")
    @classmethod
    def validate_meal_types(cls, values: list[str]) -> list[str]:
        normalized = list(dict.fromkeys(value.lower() for value in values))
        if any(value not in MEAL_TYPES for value in normalized):
            raise ValueError("Unsupported meal type")
        return normalized


class NutritionEstimateResult(NutritionEstimatePayload):
    estimate_id: str
    status: str = "needs_review"
    sources: list[NutritionSource] = Field(default_factory=list)
    provider: str
    model: str
