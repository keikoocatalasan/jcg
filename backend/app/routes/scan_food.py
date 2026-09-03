import json
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException, status
from pydantic import ValidationError
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
    try:
        scan_result = await scanner_service.scan_image(
            image_bytes,
            meal_type,
            str(client_scan_id) if client_scan_id else None,
            file.content_type or "image/jpeg",
        )
    except httpx.TimeoutException as exc:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail={"code": "AI_TIMEOUT", "message": "Food recognition timed out."},
        ) from exc
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "AI_UNAVAILABLE", "message": "Food recognition is unavailable."},
        ) from exc
    except httpx.HTTPStatusError as exc:
        provider_status = exc.response.status_code
        code = "AI_RATE_LIMITED" if provider_status == 429 else "AI_PROVIDER_ERROR"
        raise HTTPException(
            status_code=(
                status.HTTP_503_SERVICE_UNAVAILABLE
                if provider_status == 429
                else status.HTTP_502_BAD_GATEWAY
            ),
            detail={"code": code, "message": "Food recognition is unavailable."},
        ) from exc
    except (json.JSONDecodeError, ValidationError, KeyError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "AI_INVALID_OUTPUT",
                "message": "Food recognition returned an invalid result.",
            },
        ) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "AI_UNAVAILABLE", "message": str(exc)},
        ) from exc

    # A candidate is only considered complete at the release target. Lower
    # scores remain visible, but require confirmation/manual correction.
    top_candidate = (
        min(scan_result.candidates, key=lambda candidate: candidate.rank_number)
        if scan_result.candidates
        else None
    )
    if top_candidate is not None and top_candidate.confidence >= 0.80:
        status_str = "completed"
        manual = False
        # Keep ranked alternatives in the response so the user can inspect a
        # close runner-up even when the top candidate passes the release gate.
        candidates = scan_result.candidates
    else:
        status_str = "low_confidence"
        manual = True
        candidates = scan_result.candidates

    return ScanFoodResponse(
        client_scan_id=scan_result.client_scan_id,
        status=status_str,
        manual_search_recommended=manual,
        candidates=candidates,
        components=scan_result.components,
        composition_confidence=scan_result.composition_confidence,
        needs_portion_input=bool(scan_result.components),
        quality_flags=scan_result.quality_flags,
        messages=(
            ["Confirm each detected component and enter its portion weight."]
            if scan_result.components
            else ["No reliable food component was detected."]
        ),
    )
