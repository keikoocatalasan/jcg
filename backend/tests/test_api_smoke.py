from io import BytesIO

import jwt
from fastapi.testclient import TestClient
from PIL import Image

from app.config import settings
from app.main import app
from app.routes.auth import _otp_store, _store_otp, _verify_otp
from app.routes.chat import chatbot_service
from app.routes.scan_food import scanner_service


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

    readiness_response = client.get("/readiness")
    assert readiness_response.status_code == 200
    assert readiness_response.json()["data"]["status"] == "ready"


def test_validation_errors_use_standard_envelope() -> None:
    response = client.post("/ai/chat", headers=auth_headers(), json={"message": "missing fields"})
    assert response.status_code == 422
    assert response.json()["success"] is False
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


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
    assert len(body["candidates"]) == 2


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
