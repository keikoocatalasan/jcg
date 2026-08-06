import hashlib
import logging
import secrets
import time
import hmac

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field

from app.config import settings
from app.services.email_service import EmailService
from app.services.rate_limit_service import enforce_auth_rate_limit

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger(__name__)

_otp_store: dict[str, dict] = {}


def _hash_otp(otp: str) -> str:
    return hashlib.sha256(otp.encode()).hexdigest()


def _normalise_email(email: str) -> str:
    return email.strip().lower()


def _generate_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _store_otp(email: str, action: str, otp: str) -> None:
    key = f"{_normalise_email(email)}:{action}"
    _otp_store[key] = {
        "hash": _hash_otp(otp),
        "expires": time.time() + 600,
        "attempts": 0,
    }


def _verify_otp(email: str, action: str, otp: str) -> bool:
    key = f"{_normalise_email(email)}:{action}"
    entry = _otp_store.get(key)
    if not entry:
        return False
    if time.time() > entry["expires"]:
        del _otp_store[key]
        return False
    entry["attempts"] += 1
    if entry["attempts"] > 5:
        del _otp_store[key]
        return False
    if not hmac.compare_digest(_hash_otp(otp), entry["hash"]):
        return False
    del _otp_store[key]
    return True


def _create_token(email: str, action: str, expires_in: int = 900) -> str:
    return jwt.encode(
        {
            "sub": email,
            "action": action,
            "iat": time.time(),
            "exp": time.time() + expires_in,
        },
        settings.supabase_jwt_secret,
        algorithm="HS256",
    )


def _decode_token(token: str, expected_action: str) -> str:
    try:
        payload = jwt.decode(
            token, settings.supabase_jwt_secret, algorithms=["HS256"]
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid token")

    if payload.get("action") != expected_action:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid token action")
    email = payload.get("sub")
    if not email:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid token")
    return email


# ── Request / Response models ────────────────────────────────────────

class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyOtpRequest(BaseModel):
    email: EmailStr
    otp: str


class ResetPasswordRequest(BaseModel):
    reset_token: str
    new_password: str = Field(min_length=8)


class SendConfirmationRequest(BaseModel):
    email: EmailStr


class ConfirmEmailRequest(BaseModel):
    email: EmailStr
    otp: str


# ── Forgot Password ──────────────────────────────────────────────────

@router.post("/forgot-password")
async def forgot_password(
    req: ForgotPasswordRequest,
    _: None = Depends(enforce_auth_rate_limit),
):
    otp = _generate_otp()
    _store_otp(req.email, "reset_password", otp)

    sent = await EmailService.send_password_reset(req.email, otp)
    if not sent:
        logger.warning("Could not send reset email to %s", req.email)

    if settings.is_production:
        return {"success": True, "message": "If the email exists, a reset code has been sent."}

    return {
        "success": True,
        "message": "Development mode — code returned in response. Email also sent (may be deferred).",
        "dev_code": otp,
        "email_sent": sent,
    }


@router.post("/verify-reset-otp")
async def verify_reset_otp(
    req: VerifyOtpRequest,
    _: None = Depends(enforce_auth_rate_limit),
):
    if not _verify_otp(req.email, "reset_password", req.otp):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or expired code")

    token = _create_token(req.email, "reset_password", expires_in=900)
    return {"success": True, "reset_token": token}


@router.post("/reset-password")
async def reset_password(
    req: ResetPasswordRequest,
    _: None = Depends(enforce_auth_rate_limit),
):
    email = _decode_token(req.reset_token, "reset_password")

    from supabase import create_client

    client = create_client(settings.supabase_url, settings.supabase_service_role_key)

    try:
        users = client.auth.admin.list_users()
        target = None
        for u in users:
            if u.email and u.email.lower() == email.lower():
                target = u
                break

        if target is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")

        client.auth.admin.update_user(target.id, {"password": req.new_password})
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to reset password for %s", email)
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to update password")

    return {"success": True, "message": "Password updated successfully"}


# ── Send Confirmation ────────────────────────────────────────────────

@router.post("/send-confirmation")
async def send_confirmation(
    req: SendConfirmationRequest,
    _: None = Depends(enforce_auth_rate_limit),
):
    otp = _generate_otp()
    _store_otp(req.email, "confirm_email", otp)

    sent = await EmailService.send_confirmation(req.email, otp)
    if not sent:
        logger.warning("Could not send confirmation email to %s", req.email)

    if settings.is_production:
        return {"success": True, "message": "If the email exists, a confirmation code has been sent."}

    return {
        "success": True,
        "message": "Development mode — code returned in response. Email also sent (may be deferred).",
        "dev_code": otp,
        "email_sent": sent,
    }


@router.post("/verify-email")
async def verify_email(
    req: ConfirmEmailRequest,
    _: None = Depends(enforce_auth_rate_limit),
):
    if not _verify_otp(req.email, "confirm_email", req.otp):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or expired code")

    from supabase import create_client

    client = create_client(settings.supabase_url, settings.supabase_service_role_key)

    try:
        users = client.auth.admin.list_users()
        target = None
        for u in users:
            if u.email and u.email.lower() == req.email.lower():
                target = u
                break

        if target is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")

        client.auth.admin.update_user(target.id, {"email_confirm": True})
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to confirm email for %s", req.email)
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to confirm email")

    return {"success": True, "message": "Email confirmed successfully"}
