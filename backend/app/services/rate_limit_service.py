import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

from app.config import settings


class InMemoryRateLimiter:
    """Process-local safety limit suitable for the single Render web service demo."""

    def __init__(self) -> None:
        self._requests: dict[str, deque[float]] = defaultdict(deque)

    def check(self, key: str) -> None:
        now = time.monotonic()
        window_start = now - settings.rate_limit_window_seconds
        timestamps = self._requests[key]
        while timestamps and timestamps[0] <= window_start:
            timestamps.popleft()
        if len(timestamps) >= settings.rate_limit_requests:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={"code": "RATE_LIMITED", "message": "Too many requests. Please try again shortly."},
            )
        timestamps.append(now)


limiter = InMemoryRateLimiter()


async def enforce_ai_rate_limit(request: Request) -> None:
    client = request.client.host if request.client else "unknown"
    limiter.check(client)


async def enforce_auth_rate_limit(request: Request) -> None:
    client = request.client.host if request.client else "unknown"
    limiter.check(f"auth:{client}")
