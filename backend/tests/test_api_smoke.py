from io import BytesIO

import httpx
import jwt
from fastapi.testclient import TestClient
from PIL import Image

from app.config import settings
from app.main import app
from app.routes.auth import _otp_store, _store_otp, _verify_otp
from app.routes.chat import chatbot_service
from app.routes.scan_food import scanner_service
from app.schemas.scan_food import ScanCandidate
from app.services.nvidia_chat_service import NvidiaChatResult
from app.services.scanner_service import ScanResult


client = TestClient(app)


def auth_headers(user_id: str = "user-test-1") -> dict[str, str]:
    settings.supabase_jwt_secret = "test-secret"
    token = jwt.encode(
        {"sub": user_id, "aud": "authenticated"},
        settings.supabase_jwt_secret,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}"}


def test_health_and_version_routes() -> None:
    health_response = client.get("/health")
    assert health_response.status_code == 200
    assert health_response.json()["data"]["status"] == "ok"

    version_response = client.get("/version")
    assert version_response.status_code == 200
    assert version_response.json()["data"]["api_version"] == "1.0.0"
    assert version_response.json()["data"]["ai_provider"] == settings.ai_model_provider
    assert version_response.json()["data"]["ai_model"] == settings.ai_model_name

    readiness_response = client.get("/readiness")
    assert readiness_response.status_code == 200
    assert readiness_response.json()["data"]["status"] == "ready"


def test_validation_errors_use_standard_envelope() -> None:
    response = client.post("/ai/chat", headers=auth_headers(), json={"message": "missing fields"})
    assert response.status_code == 422
    assert response.json()["success"] is False
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


def test_protected_route_without_authorization_returns_401() -> None:
    response = client.post(
        "/ai/chat",
        json={
            "chat_session_id": "chat-auth",
            "client_message_id": "message-auth",
            "message": "Suggest breakfast",
        },
    )

    assert response.status_code == 401
    assert response.json()["error"]["message"] == "Invalid authorization header format"


def test_production_rejects_development_hs256_tokens(monkeypatch) -> None:
    monkeypatch.setattr(settings, "environment", "production")
    response = client.post(
        "/ai/chat",
        headers=auth_headers("production-user"),
        json={
            "chat_session_id": "chat-auth-production",
            "client_message_id": "message-auth-production",
            "message": "Suggest breakfast",
        },
    )

    assert response.status_code == 401
    assert response.json()["error"]["message"] == "Invalid token"


def test_scan_route_rejects_spoofed_image_content() -> None:
    response = client.post(
        "/ai/scan-food",
        headers=auth_headers(),
        files={"file": ("meal.png", BytesIO(b"not an image"), "image/png")},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "INVALID_IMAGE"


def test_chat_route_returns_safe_response(monkeypatch) -> None:
    monkeypatch.setattr(settings, "ai_model_provider", "deterministic")
    response = client.post(
        "/ai/chat",
        headers=auth_headers(),
        json={
            "chat_session_id": "chat-1",
            "client_message_id": "message-1",
            "message": "Suggest a balanced breakfast",
            "context": {"fitness_goal": "maintenance", "remaining_calories": 500},
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["safety_status"] == "safe"
    assert body["assistant_message_id"]
    assert "balanced options" in body["reply"]


def test_chat_route_blocks_unsafe_topics() -> None:
    response = client.post(
        "/ai/chat",
        headers=auth_headers(),
        json={
            "chat_session_id": "chat-1",
            "client_message_id": "message-2",
            "message": "Give me an eating disorder meal plan",
        },
    )

    assert response.status_code == 200
    assert response.json()["safety_status"] == "blocked"


def test_chat_route_escalates_emergency_symptoms_without_calling_ai(monkeypatch) -> None:
    async def fail_if_called(**_kwargs) -> str:
        raise AssertionError("AI provider must not be called for emergency symptoms")

    monkeypatch.setattr(chatbot_service._openai, "create_text", fail_if_called)
    response = client.post(
        "/ai/chat",
        headers=auth_headers(),
        json={
            "chat_session_id": "chat-1",
            "client_message_id": "message-emergency",
            "message": "I have chest pain and feel faint",
        },
    )

    assert response.status_code == 200
    assert response.json()["safety_status"] == "blocked"
    assert "emergency services" in response.json()["reply"]


def test_chat_provider_timeout_uses_gateway_error(monkeypatch) -> None:
    async def fail_with_timeout(*_args, **_kwargs):
        raise httpx.TimeoutException("provider timeout")

    monkeypatch.setattr(chatbot_service, "get_response", fail_with_timeout)
    response = client.post(
        "/ai/chat",
        headers=auth_headers("chat-timeout-user"),
        json={
            "chat_session_id": "chat-timeout",
            "client_message_id": "message-timeout",
            "message": "Suggest lunch",
        },
    )

    assert response.status_code == 504
    assert response.json()["error"]["code"] == "AI_TIMEOUT"


def test_chat_provider_network_error_uses_unavailable_error(monkeypatch) -> None:
    async def fail_with_network_error(*_args, **_kwargs):
        raise httpx.RequestError("provider unavailable")

    monkeypatch.setattr(chatbot_service, "get_response", fail_with_network_error)
    response = client.post(
        "/ai/chat",
        headers=auth_headers("chat-network-error-user"),
        json={
            "chat_session_id": "chat-network-error",
            "client_message_id": "message-network-error",
            "message": "Suggest lunch",
        },
    )

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "AI_UNAVAILABLE"


def test_scan_food_route_accepts_valid_image(monkeypatch) -> None:
    monkeypatch.setattr(settings, "ai_model_provider", "deterministic")
    image = Image.new("RGB", (224, 224), color="white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)

    response = client.post(
        "/ai/scan-food",
        headers=auth_headers(),
        data={"client_scan_id": "11111111-1111-4111-8111-111111111111"},
        files={"file": ("meal.png", buffer, "image/png")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "completed"
    assert body["client_scan_id"] == "11111111-1111-4111-8111-111111111111"
    assert body["manual_search_recommended"] is False
    assert len(body["candidates"]) == 3
    assert body["components"][0]["role"] == "rice"
    assert body["needs_portion_input"] is True


def test_scan_route_requires_the_highest_ranked_candidate_to_pass_gate(monkeypatch) -> None:
    async def fake_scan_image(*_args, **_kwargs) -> ScanResult:
        return ScanResult(
            client_scan_id="ranked-scan",
            candidates=[
                ScanCandidate(
                    food_id=None,
                    food_name="Ambiguous Adobo",
                    confidence=0.61,
                    rank_number=1,
                    calories=None,
                    protein_g=None,
                    carbs_g=None,
                    fat_g=None,
                    estimated_cost_php=None,
                ),
                ScanCandidate(
                    food_id=None,
                    food_name="Other Dish",
                    confidence=0.94,
                    rank_number=2,
                    calories=None,
                    protein_g=None,
                    carbs_g=None,
                    fat_g=None,
                    estimated_cost_php=None,
                ),
            ],
        )

    monkeypatch.setattr(scanner_service, "scan_image", fake_scan_image)
    image = Image.new("RGB", (224, 224), color="white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)

    response = client.post(
        "/ai/scan-food",
        headers=auth_headers("ranked-scan-user"),
        files={"file": ("meal.png", buffer, "image/png")},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "low_confidence"
    assert response.json()["manual_search_recommended"] is True


def test_scan_provider_timeout_uses_gateway_error(monkeypatch) -> None:
    async def fail_with_timeout(*_args, **_kwargs):
        raise httpx.TimeoutException("provider timeout")

    monkeypatch.setattr(scanner_service, "scan_image", fail_with_timeout)
    image = Image.new("RGB", (224, 224), color="white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)

    response = client.post(
        "/ai/scan-food",
        headers=auth_headers("scan-timeout-user"),
        files={"file": ("meal.png", buffer, "image/png")},
    )

    assert response.status_code == 504
    assert response.json()["error"]["code"] == "AI_TIMEOUT"


def test_scan_provider_network_error_uses_unavailable_error(monkeypatch) -> None:
    async def fail_with_network_error(*_args, **_kwargs):
        raise httpx.RequestError("provider unavailable")

    monkeypatch.setattr(scanner_service, "scan_image", fail_with_network_error)
    image = Image.new("RGB", (224, 224), color="white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)

    response = client.post(
        "/ai/scan-food",
        headers=auth_headers("scan-network-error-user"),
        files={"file": ("meal.png", buffer, "image/png")},
    )

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "AI_UNAVAILABLE"


def test_openai_provider_paths_are_connected_without_network(monkeypatch) -> None:
    async def fake_create_text(**kwargs) -> str:
        if kwargs.get("json_schema"):
            return (
                '{"candidates":[{"food_id":null,"food_name":"Tinola",'
                '"confidence":0.91,"rank_number":1,"calories":250,'
                '"protein_g":28,"carbs_g":8,"fat_g":11,'
                '"estimated_cost_php":75}]}'
            )
        return "Try tinola with rice within your remaining budget."

    monkeypatch.setattr(settings, "ai_model_provider", "openai")
    monkeypatch.setattr(scanner_service._openai, "create_text", fake_create_text)
    monkeypatch.setattr(chatbot_service._openai, "create_text", fake_create_text)

    image = Image.new("RGB", (224, 224), color="white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)
    scan_response = client.post(
        "/ai/scan-food",
        headers=auth_headers(),
        data={"client_scan_id": "44444444-4444-4444-8444-444444444444"},
        files={"file": ("meal.png", buffer, "image/png")},
    )
    chat_response = client.post(
        "/ai/chat",
        headers=auth_headers(),
        json={
            "chat_session_id": "chat-openai",
            "client_message_id": "message-openai",
            "message": "Suggest lunch",
            "context": {"remaining_budget_php": 100},
        },
    )

    assert scan_response.status_code == 200
    assert scan_response.json()["candidates"][0]["food_name"] == "Tinola"
    assert chat_response.status_code == 200
    assert "tinola" in chat_response.json()["reply"].lower()


def test_scan_rejects_provider_confidence_outside_contract(monkeypatch) -> None:
    async def fake_create_text(**_kwargs) -> str:
        return (
            '{"candidates":[{"food_id":null,"food_name":"Dish",'
            '"confidence":1.2,"rank_number":1,"calories":100,'
            '"protein_g":5,"carbs_g":10,"fat_g":2,'
            '"estimated_cost_php":20}]}'
        )

    monkeypatch.setattr(settings, "ai_model_provider", "openai")
    monkeypatch.setattr(settings, "ai_model_api_key", "test-openai-key")
    monkeypatch.setattr(scanner_service._openai, "create_text", fake_create_text)

    image = Image.new("RGB", (224, 224), color="white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)
    response = client.post(
        "/ai/scan-food",
        headers=auth_headers("invalid-confidence-user"),
        files={"file": ("meal.png", buffer, "image/png")},
    )

    assert response.status_code == 502
    assert response.json()["error"]["code"] == "AI_INVALID_OUTPUT"


def test_nvidia_provider_paths_are_connected_without_network(monkeypatch) -> None:
    async def fake_nvidia_create_text(**kwargs) -> NvidiaChatResult:
        input_content = kwargs["input_content"]
        is_image_request = isinstance(input_content, list) and any(
            item.get("type") == "image_url" for item in input_content
        )
        if is_image_request:
            return NvidiaChatResult(
                text="dish=Chicken Adobo; rice=yes; extras=atchara",
                model="meta/llama-3.2-11b-vision-instruct",
            )
        return NvidiaChatResult(
            text="Try chicken adobo with vegetables within your remaining budget.",
            model="meta/llama-3.2-11b-vision-instruct",
        )

    monkeypatch.setattr(settings, "ai_model_provider", "nvidia")
    monkeypatch.setattr(settings, "ai_model_api_key", "test-nvidia-key")
    monkeypatch.setattr(scanner_service._nvidia, "create_text", fake_nvidia_create_text)
    monkeypatch.setattr(chatbot_service._nvidia, "create_text", fake_nvidia_create_text)

    image = Image.new("RGB", (224, 224), color="white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)
    scan_response = client.post(
        "/ai/scan-food",
        headers=auth_headers(),
        data={"client_scan_id": "55555555-5555-4555-8555-555555555555"},
        files={"file": ("meal.png", buffer, "image/png")},
    )
    chat_response = client.post(
        "/ai/chat",
        headers=auth_headers(),
        json={
            "chat_session_id": "chat-nvidia",
            "client_message_id": "message-nvidia",
            "message": "Suggest lunch",
        },
    )

    assert scan_response.status_code == 200
    assert scan_response.json()["candidates"][0]["food_name"] == "Chicken Adobo"
    assert scan_response.json()["components"][0]["role"] == "ulam"
    assert scan_response.json()["components"][1]["role"] == "rice"
    assert scan_response.json()["components"][2]["food_name"] == "atchara"
    assert scan_response.json()["needs_portion_input"] is True
    assert chat_response.status_code == 200
    assert "adobo" in chat_response.json()["reply"].lower()


def test_nvidia_unknown_result_is_explicitly_manual(monkeypatch) -> None:
    async def fake_nvidia_create_text(**kwargs) -> NvidiaChatResult:
        input_content = kwargs["input_content"]
        if isinstance(input_content, list) and any(
            item.get("type") == "image_url" for item in input_content
        ):
            return NvidiaChatResult(
                text="dish=unknown; rice=unknown; extras=none",
                model="meta/llama-3.2-11b-vision-instruct",
            )
        return NvidiaChatResult(text="unused", model="test-model")

    monkeypatch.setattr(settings, "ai_model_provider", "nvidia")
    monkeypatch.setattr(settings, "ai_model_api_key", "test-nvidia-key")
    monkeypatch.setattr(scanner_service._nvidia, "create_text", fake_nvidia_create_text)

    image = Image.new("RGB", (224, 224), color="white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)
    response = client.post(
        "/ai/scan-food",
        headers=auth_headers("unknown-scan-user"),
        files={"file": ("meal.png", buffer, "image/png")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "low_confidence"
    assert body["manual_search_recommended"] is True
    assert body["candidates"] == []
    assert "unknown_or_unsupported" in body["quality_flags"]


def test_scan_feedback_route_returns_user_id(monkeypatch) -> None:
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_service_role_key", "")
    response = client.post(
        "/ai/scan-feedback",
        headers=auth_headers("user-feedback-1"),
        json={
            "feedback_id": "22222222-2222-4222-8222-222222222222",
            "client_scan_id": "33333333-3333-4333-8333-333333333333",
            "selected_food_id": "food-001",
            "was_helpful": True,
        },
    )

    assert response.status_code == 200
    assert response.json()["data"]["feedback_id"] == "22222222-2222-4222-8222-222222222222"
    assert response.json()["data"]["user_id"] == "user-feedback-1"
    assert response.json()["data"]["persisted"] is False


def test_explain_recommendation_route_returns_explanation() -> None:
    response = client.post(
        "/ai/explain-recommendation",
        headers=auth_headers(),
        json={
            "food_name": "White Rice",
            "calories": 206,
            "protein_g": 4.2,
            "estimated_cost_php": 15,
            "fitness_goal": "maintenance",
        },
    )

    assert response.status_code == 200
    assert "White Rice" in response.json()["data"]["explanation"]


def test_otp_verification_is_case_insensitive_and_limited() -> None:
    _otp_store.clear()
    _store_otp("User@Example.com", "reset_password", "123456")

    assert _verify_otp("user@example.com", "reset_password", "000000") is False
    assert _verify_otp("user@example.com", "reset_password", "123456") is True

    _store_otp("locked@example.com", "reset_password", "654321")
    for _ in range(5):
        assert _verify_otp("locked@example.com", "reset_password", "000000") is False
    assert _verify_otp("locked@example.com", "reset_password", "654321") is False


def test_reset_password_rejects_short_password() -> None:
    response = client.post(
        "/auth/reset-password",
        json={"reset_token": "not-used", "new_password": "short"},
    )
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
