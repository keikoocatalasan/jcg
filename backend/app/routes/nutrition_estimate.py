import json

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import ValidationError

from app.auth.admin_authorization import require_admin
from app.schemas.common import SuccessResponse
from app.schemas.nutrition_estimate import NutritionEstimateRequest
from app.services.nutrition_estimate_service import NutritionEstimateService
from app.services.rate_limit_service import enforce_ai_rate_limit


router = APIRouter()
nutrition_estimate_service = NutritionEstimateService()


@router.post("/ai/admin/estimate-nutrition", response_model=SuccessResponse)
async def estimate_nutrition(
    request: NutritionEstimateRequest,
    _admin_user_id: str = Depends(require_admin),
    _rate_limit: None = Depends(enforce_ai_rate_limit),
):
    try:
        result = await nutrition_estimate_service.estimate(request)
    except httpx.TimeoutException as exc:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail={"code": "AI_TIMEOUT", "message": "Nutrition estimation timed out."},
        ) from exc
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "AI_UNAVAILABLE", "message": "Nutrition estimation is unavailable."},
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
            detail={"code": code, "message": "Nutrition estimation is unavailable."},
        ) from exc
    except (json.JSONDecodeError, ValidationError, KeyError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "code": "AI_INVALID_OUTPUT",
                "message": "The nutrition estimate could not be validated.",
            },
        ) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "AI_UNAVAILABLE", "message": str(exc)},
        ) from exc

    return SuccessResponse(
        data=result.model_dump(mode="json"),
        message="Nutrition estimate ready for administrator review",
    )
