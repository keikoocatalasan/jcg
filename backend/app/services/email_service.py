import httpx
import logging

from app.config import settings

logger = logging.getLogger(__name__)

BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"


class EmailService:
    @staticmethod
    async def send(
        to_email: str,
        subject: str,
        html_content: str,
        sender_name: str = "JCG Fitness",
    ) -> bool:
        if not settings.brevo_api_key:
            logger.warning("BREVO_API_KEY not configured — skipping email to %s", to_email)
            return False

        payload = {
            "sender": {"name": sender_name, "email": settings.brevo_sender_email},
            "to": [{"email": to_email}],
            "subject": subject,
            "htmlContent": html_content,
        }
        headers = {
            "accept": "application/json",
            "content-type": "application/json",
            "api-key": settings.brevo_api_key,
        }

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(BREVO_API_URL, json=payload, headers=headers)
                if response.status_code in (200, 201):
                    logger.info("Email sent to %s — subject=%s", to_email, subject)
                    return True
                logger.error("Brevo API error %s: %s", response.status_code, response.text)
                return False
        except Exception:
            logger.exception("Failed to send email to %s", to_email)
            return False

    @staticmethod
    async def send_password_reset(to_email: str, otp_code: str) -> bool:
        html = f"""
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"></head>
        <body style="margin:0;padding:0;font-family:'Segoe UI',Roboto,sans-serif;background:#f4f6f8;">
        <div style="max-width:480px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.08);">
            <div style="background:#16a34a;padding:24px 32px;">
                <h1 style="margin:0;color:#fff;font-size:20px;font-weight:700;">JCG Fitness</h1>
                <p style="margin:4px 0 0;color:rgba(255,255,255,.85);font-size:13px;">NutriSmart AI</p>
            </div>
            <div style="padding:32px;">
                <h2 style="margin:0 0 12px;color:#1a1a1a;font-size:18px;">Password Reset Request</h2>
                <p style="margin:0 0 24px;color:#555;font-size:14px;line-height:1.6;">
                    We received a request to reset your password. Use the code below within <strong>10 minutes</strong>.
                </p>
                <div style="background:#f0fdf4;border:2px dashed #16a34a;border-radius:8px;padding:20px;text-align:center;margin:0 0 24px;">
                    <p style="margin:0 0 8px;color:#555;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Your Reset Code</p>
                    <p style="margin:0;color:#16a34a;font-size:32px;font-weight:700;letter-spacing:6px;font-family:monospace;">{otp_code}</p>
                </div>
                <p style="margin:0 0 16px;color:#888;font-size:12px;line-height:1.5;">
                    If you did not request a password reset, you can safely ignore this email. Your password will remain unchanged.
                </p>
            </div>
            <div style="background:#f9fafb;padding:16px 32px;text-align:center;">
                <p style="margin:0;color:#999;font-size:11px;">JCG Fitness &mdash; Budget-Aware Nutrition Tracking</p>
            </div>
        </div>
        </body>
        </html>
        """
        return await EmailService.send(to_email, "JCG Fitness — Password Reset Code", html)

    @staticmethod
    async def send_confirmation(to_email: str, otp_code: str) -> bool:
        html = f"""
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"></head>
        <body style="margin:0;padding:0;font-family:'Segoe UI',Roboto,sans-serif;background:#f4f6f8;">
        <div style="max-width:480px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.08);">
            <div style="background:#16a34a;padding:24px 32px;">
                <h1 style="margin:0;color:#fff;font-size:20px;font-weight:700;">JCG Fitness</h1>
                <p style="margin:4px 0 0;color:rgba(255,255,255,.85);font-size:13px;">NutriSmart AI</p>
            </div>
            <div style="padding:32px;">
                <h2 style="margin:0 0 12px;color:#1a1a1a;font-size:18px;">Verify Your Email</h2>
                <p style="margin:0 0 24px;color:#555;font-size:14px;line-height:1.6;">
                    Welcome to JCG Fitness! Use the code below to verify your email address. This code expires in <strong>10 minutes</strong>.
                </p>
                <div style="background:#f0fdf4;border:2px dashed #16a34a;border-radius:8px;padding:20px;text-align:center;margin:0 0 24px;">
                    <p style="margin:0 0 8px;color:#555;font-size:12px;text-transform:uppercase;letter-spacing:1px;">Your Verification Code</p>
                    <p style="margin:0;color:#16a34a;font-size:32px;font-weight:700;letter-spacing:6px;font-family:monospace;">{otp_code}</p>
                </div>
                <p style="margin:0 0 16px;color:#888;font-size:12px;line-height:1.5;">
                    If you did not create an account, you can safely ignore this email.
                </p>
            </div>
            <div style="background:#f9fafb;padding:16px 32px;text-align:center;">
                <p style="margin:0;color:#999;font-size:11px;">JCG Fitness &mdash; Budget-Aware Nutrition Tracking</p>
            </div>
        </div>
        </body>
        </html>
        """
        return await EmailService.send(to_email, "JCG Fitness — Verify Your Email", html)
