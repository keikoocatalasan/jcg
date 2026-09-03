import uuid
import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from app.auth.jwt_verifier import verify_token
from app.schemas.chatbot import ChatRequest, ChatResponse
from app.services.chatbot_service import ChatbotService
from app.services.safety_service import EMERGENCY_TOPICS, check_safety
from app.services.rate_limit_service import enforce_ai_rate_limit

router = APIRouter()
chatbot_service = ChatbotService()


@router.post("/ai/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    _payload: dict = Depends(verify_token),
    _rate_limit: None = Depends(enforce_ai_rate_limit),
):
    safety = check_safety(request.message)

    if safety.status == "blocked":
        is_emergency = any(topic in EMERGENCY_TOPICS for topic in safety.matched_topics)
        return ChatResponse(
            assistant_message_id=str(uuid.uuid4()),
            reply=(
                "This may be an emergency. Contact local emergency services now or go to the nearest emergency department. "
                "Do not rely on this chat for urgent medical help."
                if is_emergency
                else "I'm sorry, I can't provide information on that topic. Please consult a qualified professional."
            ),
            safety_status="blocked",
        )

    if safety.status == "redirected":
        reply = (
            "It sounds like you're asking about something I can't help with directly. "
            "I can assist with healthy eating habits, nutrition facts, and meal planning instead. "
            "Would you like help with any of those?"
        )
        return ChatResponse(
            assistant_message_id=str(uuid.uuid4()),
            reply=reply,
            safety_status="redirected",
        )

    try:
        result = await chatbot_service.get_response(request.message, request.context)
    except httpx.TimeoutException as exc:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail={"code": "AI_TIMEOUT", "message": "Chat response timed out."},
        ) from exc
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "AI_UNAVAILABLE", "message": "Chat service is unavailable."},
        ) from exc
    except httpx.HTTPStatusError as exc:
        provider_status = exc.response.status_code
        code = "AI_RATE_LIMITED" if provider_status == 429 else "AI_PROVIDER_ERROR"
        raise HTTPException(
            status_code=(
                status.HTTP_503_SERVICE_UNAVAILABLE
                if provider_status == 429
                else status.HTTP_502_BAD_GATEWAY
            ),
            detail={"code": code, "message": "Chat service is unavailable."},
        ) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "AI_UNAVAILABLE", "message": str(exc)},
        ) from exc
    return ChatResponse(
        assistant_message_id=str(uuid.uuid4()),
        reply=result.reply,
        safety_status="safe",
    )
