import uuid
import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, status
from app.auth.jwt_verifier import verify_token
from app.schemas.chatbot import ChatRequest, ChatResponse
from app.services.chat_context_service import ChatContextService
from app.services.chatbot_service import ChatbotService
from app.services.safety_service import EMERGENCY_TOPICS, check_safety, contains_profanity
from app.services.rate_limit_service import enforce_chat_rate_limit

router = APIRouter()
chatbot_service = ChatbotService()
chat_context_service = ChatContextService()


@router.post("/ai/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    http_request: Request,
    payload: dict = Depends(verify_token),
    _rate_limit: None = Depends(enforce_chat_rate_limit),
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
        if 'profanity' in safety.matched_topics:
            return ChatResponse(
                assistant_message_id=str(uuid.uuid4()),
                reply="Let's keep it respectful. Rephrase your question and I'll help. / Pakisabi ulit nang walang mura para matulungan kita.",
                safety_status='redirected',
            )
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
        access_token = http_request.headers.get("authorization", "")
        if access_token.lower().startswith("bearer "):
            access_token = access_token[7:].strip()
        else:
            access_token = ""
        trusted_context = await chat_context_service.get_context(
            auth_user_id=str(payload.get("sub") or ""),
            access_token=access_token,
            message=request.message,
            history=request.history,
        )
        result = await chatbot_service.get_response(
            request.message,
            trusted_context,
            request.history,
        )
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
    if contains_profanity(result.reply):
        return ChatResponse(
            assistant_message_id=str(uuid.uuid4()),
            reply="I couldn't provide a suitable reply. Please rephrase your question and try again.",
            safety_status='redirected',
        )
    return ChatResponse(
        assistant_message_id=str(uuid.uuid4()),
        reply=result.reply,
        safety_status="safe",
    )
