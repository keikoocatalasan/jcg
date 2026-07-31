import logging
import uuid

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.routes import health, version, scan_food, scan_feedback, chat, explain_recommendation, auth

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

settings.validate_runtime()
app = FastAPI(title="JCG Fitness API", version="1.0.0")


@app.middleware("http")
async def request_context(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    try:
        response = await call_next(request)
    except Exception:
        logger.exception("Unhandled API error request_id=%s path=%s", request_id, request.url.path)
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": {"code": "INTERNAL_ERROR", "message": "An unexpected error occurred."}, "request_id": request_id},
        )
    response.headers["X-Request-ID"] = request_id
    logger.info("request_id=%s method=%s path=%s status=%s", request_id, request.method, request.url.path, response.status_code)
    return response


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={"success": False, "error": {"code": "VALIDATION_ERROR", "message": "Invalid request.", "details": {"errors": exc.errors()}}},
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException):
    detail = exc.detail if isinstance(exc.detail, dict) else {}
    error = detail.get("error", detail)
    if not isinstance(error, dict):
        error = {"code": "HTTP_ERROR", "message": str(exc.detail)}
    error.setdefault("code", "HTTP_ERROR")
    error.setdefault("message", "Request failed.")
    return JSONResponse(status_code=exc.status_code, content={"success": False, "error": error})

_origins = settings.allowed_origins_list
if _origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_origins,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type", "Authorization"],
    )

app.include_router(health.router)
app.include_router(version.router)
app.include_router(scan_food.router)
app.include_router(scan_feedback.router)
app.include_router(chat.router)
app.include_router(explain_recommendation.router)
app.include_router(auth.router)
