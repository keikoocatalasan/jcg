import httpx
from fastapi import Depends, HTTPException, status

from app.auth.jwt_verifier import get_current_user_id
from app.services.supabase_service import SupabaseService


admin_authorization_service = SupabaseService()


async def require_admin(
    auth_user_id: str = Depends(get_current_user_id),
) -> str:
    try:
        is_admin = await admin_authorization_service.is_admin(auth_user_id)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "ADMIN_LOOKUP_UNAVAILABLE",
                "message": "Administrator access could not be verified.",
            },
        ) from exc
    if not is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "ADMIN_REQUIRED",
                "message": "Administrator access is required.",
            },
        )
    return auth_user_id
