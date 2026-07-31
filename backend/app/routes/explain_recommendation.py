import uuid
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from app.auth.jwt_verifier import verify_token
from app.schemas.common import SuccessResponse
from app.services.rate_limit_service import enforce_ai_rate_limit

router = APIRouter()


class ExplainRequest(BaseModel):
    food_name: str
    calories: float | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None
    estimated_cost_php: float | None = None
    fitness_goal: str | None = None


@router.post("/ai/explain-recommendation", response_model=SuccessResponse)
async def explain_recommendation(
    request: ExplainRequest,
    _payload: dict = Depends(verify_token),
    _rate_limit: None = Depends(enforce_ai_rate_limit),
):
    explanation_parts = [f"**{request.food_name}**"]

    if request.fitness_goal:
        explanation_parts.append(f"- aligns with goal: **{request.fitness_goal}**")

    if request.calories is not None:
        explanation_parts.append(f"- provides **{request.calories:.0f} kcal**")

    nutrition = []
    if request.protein_g is not None:
        nutrition.append(f"protein: {request.protein_g:.1f}g")
    if request.carbs_g is not None:
        nutrition.append(f"carbs: {request.carbs_g:.1f}g")
    if request.fat_g is not None:
        nutrition.append(f"fat: {request.fat_g:.1f}g")
    if nutrition:
        explanation_parts.append(f"- macros: {', '.join(nutrition)}")

    if request.estimated_cost_php is not None:
        explanation_parts.append(f"- estimated cost: **₱{request.estimated_cost_php:.2f}**")

    explanation = "\n".join(explanation_parts)

    return SuccessResponse(
        data={
            "explanation_id": str(uuid.uuid4()),
            "explanation": explanation,
        },
        message="Recommendation explained",
    )
