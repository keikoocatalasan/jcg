from fastapi import APIRouter

router = APIRouter()


@router.get("/version")
async def get_version():
    return {
        "success": True,
        "data": {
            "api_version": "1.0.0",
            "enabled_modules": ["scan_food", "scan_feedback", "chat"],
        },
        "message": "OK",
    }
