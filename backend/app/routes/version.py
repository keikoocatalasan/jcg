from fastapi import APIRouter

from app.config import settings

router = APIRouter()


@router.get("/version")
async def get_version():
    return {
        "success": True,
        "data": {
            "api_version": "1.0.0",
            "enabled_modules": [
                "scan_food",
                "scan_composition",
                "portion_nutrition",
                "scan_feedback",
                "chat",
            ],
            "scanner_pipeline": "scanner-v2",
            "ai_provider": settings.ai_model_provider,
            "ai_model": settings.ai_model_name,
        },
        "message": "OK",
    }
