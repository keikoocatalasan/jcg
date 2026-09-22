import time
from collections import deque

from fastapi import Depends, HTTPException, Request, status

from app.auth.jwt_verifier import verify_token
from app.config import settings


class InMemoryRateLimiter:
    """Process-local safety limit suitable for the single Render web service demo."""

    def __init__(self, *, cleanup_interval: int = 128) -> None:
        self._requests: dict[str, deque[float]] = {}
        self._window_by_key: dict[str, int] = {}
        self._checks = 0
        self._cleanup_interval = max(1, cleanup_interval)

    def check(
        self,
        key: str,
        *,
        limit: int | None = None,
        window_seconds: int | None = None,
    ) -> None:
        now = time.monotonic()
        effective_window = window_seconds or settings.rate_limit_window_seconds
        effective_limit = limit or settings.rate_limit_requests
        window_start = now - effective_window
        self._checks += 1
        if self._checks % self._cleanup_interval == 0:
            for tracked_key, tracked_timestamps in list(self._requests.items()):
                tracked_window = self._window_by_key[tracked_key]
                if not tracked_timestamps or tracked_timestamps[-1] <= now - tracked_window:
                    self._requests.pop(tracked_key, None)
                    self._window_by_key.pop(tracked_key, None)

        timestamps = self._requests.setdefault(key, deque())
        self._window_by_key[key] = max(
            effective_window, self._window_by_key.get(key, 0)
        )
        while timestamps and timestamps[0] <= window_start:
            timestamps.popleft()
        if len(timestamps) >= effective_limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={"code": "RATE_LIMITED", "message": "Too many requests. Please try again shortly."},
            )
        timestamps.append(now)


limiter = InMemoryRateLimiter()
chat_limiter = InMemoryRateLimiter()


async def enforce_ai_rate_limit(request: Request) -> None:
    client = request.client.host if request.client else "unknown"
    limiter.check(client)


async def enforce_chat_rate_limit(payload: dict = Depends(verify_token)) -> None:
    """A chatbot-only per-user limit; does not throttle scanner endpoints."""
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_TOKEN", "message": "Invalid token."},
        )
    chat_limiter.check(str(user_id), limit=20, window_seconds=60)


async def enforce_auth_rate_limit(request: Request) -> None:
    client = request.client.host if request.client else "unknown"
    limiter.check(f"auth:{client}")
