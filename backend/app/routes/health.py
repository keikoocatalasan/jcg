from fastapi import APIRouter, HTTPException, status
from app.config import settings

router = APIRouter()


@router.get("/health")
async def health_check():
    return {"success": True, "data": {"status": "ok"}, "message": "OK"}


@router.get("/readiness")
async def readiness_check():
    try:
        settings.validate_runtime()
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail={"code": "NOT_READY", "message": str(exc)}) from exc
    return {"success": True, "data": {"status": "ready", "environment": settings.environment}, "message": "Ready"}
