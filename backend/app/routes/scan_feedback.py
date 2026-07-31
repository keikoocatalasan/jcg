import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from app.auth.jwt_verifier import verify_token, get_current_user_id
from app.schemas.common import SuccessResponse
from app.schemas.scan_food import ScanFeedbackRequest
from app.services.rate_limit_service import enforce_ai_rate_limit
from app.services.supabase_service import SupabaseService

router = APIRouter()
supabase_service = SupabaseService()


@router.post("/ai/scan-feedback", response_model=SuccessResponse)
async def submit_scan_feedback(
    feedback: ScanFeedbackRequest,
    user_id: str = Depends(get_current_user_id),
    _payload: dict = Depends(verify_token),
    _rate_limit: None = Depends(enforce_ai_rate_limit),
):
    feedback_id = str(feedback.feedback_id or uuid.uuid4())
    client_scan_id = str(feedback.client_scan_id)
    try:
        result = await supabase_service.insert_scan_feedback({
            "feedback_id": feedback_id,
            "user_id": user_id,
            "client_scan_id": client_scan_id,
            "selected_food_id": feedback.selected_food_id,
            "was_helpful": feedback.was_helpful,
            "feedback_text": feedback.feedback_text,
        })
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "FEEDBACK_PERSIST_FAILED", "message": "Unable to record scan feedback. Please retry."},
        ) from exc
    return SuccessResponse(
        data={
            "feedback_id": feedback_id,
            "client_scan_id": client_scan_id,
            "user_id": user_id,
            "persisted": result["persisted"],
        },
        message="Feedback recorded" if result["persisted"] else "Feedback accepted for local demo",
    )
