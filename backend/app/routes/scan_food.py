from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException, status
from app.auth.jwt_verifier import verify_token
from app.services.image_validation_service import validate_image
from app.services.scanner_service import ScannerService
from app.schemas.scan_food import ScanFoodResponse, ScanCandidate
from app.config import settings
from app.services.rate_limit_service import enforce_ai_rate_limit

router = APIRouter()
scanner_service = ScannerService()


@router.post("/ai/scan-food", response_model=ScanFoodResponse)
async def scan_food(
    file: UploadFile = File(...),
    meal_type: str | None = Form(default=None),
    client_scan_id: UUID | None = Form(default=None),
    payload: dict = Depends(verify_token),
    _rate_limit: None = Depends(enforce_ai_rate_limit),
):
    errors = validate_image(file, settings.max_image_upload_mb)
    if errors:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"success": False, "error": {"code": "INVALID_IMAGE", "message": errors[0]}},
        )

    image_bytes = await file.read()
    scan_result = await scanner_service.scan_image(
        image_bytes,
        meal_type,
        str(client_scan_id) if client_scan_id else None,
        file.content_type or "image/jpeg",
    )

    high_conf = [c for c in scan_result.candidates if c.confidence > 0.60]
    if high_conf:
        status_str = "completed"
        manual = False
        candidates = high_conf
    else:
        status_str = "low_confidence"
        manual = True
        candidates = scan_result.candidates

    return ScanFoodResponse(
        client_scan_id=scan_result.client_scan_id,
        status=status_str,
        manual_search_recommended=manual,
        candidates=candidates,
    )
