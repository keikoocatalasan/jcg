import httpx

from app.config import settings


class SupabaseService:
    async def is_admin(self, auth_user_id: str) -> bool:
        if not settings.supabase_url or not settings.supabase_service_role_key:
            return False
        headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
        }
        url = f"{settings.supabase_url.rstrip('/')}/rest/v1/app_user"
        params = {
            "auth_user_id": f"eq.{auth_user_id}",
            "select": "user_id,role(role_code)",
            "limit": "1",
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, headers=headers, params=params)
            response.raise_for_status()
        rows = response.json()
        if not rows:
            return False
        role = rows[0].get("role") or {}
        return role.get("role_code") == "admin"

    async def insert_scan_feedback(self, payload: dict) -> dict:
        if not settings.supabase_url or not settings.supabase_service_role_key:
            # Local deterministic demos may run without Supabase. The route still
            # reports an explicit non-persisted outcome rather than pretending.
            return {"persisted": False}
        headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=representation",
        }
        url = (
            f"{settings.supabase_url.rstrip('/')}/rest/v1/ai_scan_feedback"
            "?on_conflict=feedback_id"
        )
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
        rows = response.json()
        return {"persisted": True, "row": rows[0] if rows else payload}
