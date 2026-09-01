import json

import jwt
from fastapi.testclient import TestClient

from app.auth.admin_authorization import admin_authorization_service
from app.config import settings
from app.main import app
from app.routes.nutrition_estimate import nutrition_estimate_service
from app.services.openai_responses_service import (
    OpenAIResponseResult,
    OpenAIResponsesService,
    OpenAISource,
)


client = TestClient(app)


def auth_headers(user_id: str = "admin-test-1") -> dict[str, str]:
    settings.supabase_jwt_secret = "test-secret"
    token = jwt.encode(
        {"sub": user_id, "aud": "authenticated"},
        settings.supabase_jwt_secret,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}"}


def estimate_body() -> dict:
    return {
        "food_name": "Chicken Adobo",
        "category_name": "Meat and Poultry",
        "serving_label": "1 cup",
        "serving_grams": 200,
        "description": "Filipino chicken adobo",
    }


def test_admin_can_generate_deterministic_review_draft(monkeypatch) -> None:
    async def is_admin(_user_id: str) -> bool:
        return True

    monkeypatch.setattr(admin_authorization_service, "is_admin", is_admin)
    monkeypatch.setattr(settings, "ai_model_provider", "deterministic")

    response = client.post(
        "/ai/admin/estimate-nutrition",
        headers=auth_headers(),
        json=estimate_body(),
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["status"] == "needs_review"
    assert data["provider"] == "deterministic"
    assert data["calories"] > 0
    assert data["suggested_meal_types"] == ["lunch", "dinner"]
    assert "verify nutrition" in data["warnings"][0].lower()


def test_non_admin_cannot_use_nutrition_estimator(monkeypatch) -> None:
    async def is_admin(_user_id: str) -> bool:
        return False

    monkeypatch.setattr(admin_authorization_service, "is_admin", is_admin)
    response = client.post(
        "/ai/admin/estimate-nutrition",
        headers=auth_headers("normal-user"),
        json=estimate_body(),
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "ADMIN_REQUIRED"


def test_openai_estimate_returns_structured_sources(monkeypatch) -> None:
    async def is_admin(_user_id: str) -> bool:
        return True

    async def create(**_kwargs) -> OpenAIResponseResult:
        return OpenAIResponseResult(
            text=json.dumps(
                {
                    "food_name": "Chicken Adobo",
                    "serving_label": "1 cup",
                    "serving_grams": 200,
                    "calories": 430,
                    "protein_g": 35,
                    "carbs_g": 8,
                    "fat_g": 28,
                    "suggested_meal_types": ["lunch", "dinner"],
                    "confidence": 0.82,
                    "warnings": [],
                }
            ),
            response_id="resp-test",
            model="test-model",
            sources=[
                OpenAISource(
                    title="Nutrition reference",
                    url="https://example.com/nutrition",
                )
            ],
        )

    monkeypatch.setattr(admin_authorization_service, "is_admin", is_admin)
    monkeypatch.setattr(settings, "ai_model_provider", "openai")
    monkeypatch.setattr(settings, "ai_web_search_enabled", True)
    monkeypatch.setattr(nutrition_estimate_service._openai, "create", create)

    response = client.post(
        "/ai/admin/estimate-nutrition",
        headers=auth_headers(),
        json=estimate_body(),
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["model"] == "test-model"
    assert data["sources"][0]["url"] == "https://example.com/nutrition"


def test_openai_source_extraction_deduplicates_urls() -> None:
    payload = {
        "output": [
            {
                "type": "web_search_call",
                "action": {
                    "sources": [
                        {"url": "https://example.com/a", "title": "A"},
                    ]
                },
            },
            {
                "type": "message",
                "content": [
                    {
                        "type": "output_text",
                        "text": "Result",
                        "annotations": [
                            {
                                "type": "url_citation",
                                "url": "https://example.com/a",
                                "title": "A updated",
                            }
                        ],
                    }
                ],
            },
        ]
    }

    sources = OpenAIResponsesService._extract_sources(payload)
    assert len(sources) == 1
    assert sources[0].title == "A updated"
