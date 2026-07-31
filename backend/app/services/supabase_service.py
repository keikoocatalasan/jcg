import httpx

from app.config import settings


class SupabaseService:
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
