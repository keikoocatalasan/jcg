import asyncio

from app.config import settings
from app.schemas.chatbot import ChatTurn
from app.services.chat_context_service import ChatContextService


AUTH_USER_ID = "11111111-1111-4111-8111-111111111111"
APP_USER_ID = "22222222-2222-4222-8222-222222222222"


def test_chat_context_uses_user_jwt_and_returns_only_relevant_jcg_data(monkeypatch) -> None:
    captured = []

    class FakeResponse:
        def __init__(self, rows):
            self.rows = rows

        def raise_for_status(self) -> None:
            return None

        def json(self):
            return self.rows

    class FakeClient:
        def __init__(self, **_kwargs) -> None:
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args) -> None:
            return None

        async def get(self, url, params, headers):
            table = url.rsplit("/", 1)[-1]
            captured.append((table, params, headers))
            response_by_table = {
                "app_user": [{"user_id": APP_USER_ID}],
                "user_profile": [{"fitness_goal_id": 1, "daily_budget_php": 500}],
                "nutrition_target": [{
                    "fitness_goal_id": 1,
                    "calorie_target": 1800,
                    "protein_target_g": 110,
                    "carbs_target_g": 210,
                    "fat_target_g": 60,
                }],
                "daily_target_snapshot": [{
                    "calorie_target_snapshot": 1700,
                    "protein_target_g_snapshot": 100,
                    "carbs_target_g_snapshot": 200,
                    "fat_target_g_snapshot": 55,
                    "daily_budget_php_snapshot": 400,
                }],
                "meal_log": [{
                    "calories_snapshot": 600,
                    "protein_g_snapshot": 35,
                    "carbs_g_snapshot": 80,
                    "fat_g_snapshot": 20,
                    "cost_php_snapshot": 150,
                }],
                "user_allergy": [{"allergy_id": 2}],
                "user_dietary_restriction": [{"restriction_id": 3}],
                "fitness_goal": [{"goal_code": "weight_loss"}],
                "allergy": [{"allergy_name": "Peanuts"}],
                "dietary_restriction": [{"restriction_name": "Dairy-free"}],
                "food_catalog": [{
                    "food_name": "Chicken Breast",
                    "normalized_name": "chicken breast",
                    "serving_label": "1 piece",
                    "serving_grams": 100,
                    "calories": 165,
                    "protein_g": 31,
                    "carbs_g": 0,
                    "fat_g": 3.6,
                    "estimated_price_php": 45,
                }],
            }
            return FakeResponse(response_by_table.get(table, []))

    monkeypatch.setattr(
        "app.services.chat_context_service.httpx.AsyncClient",
        FakeClient,
    )
    monkeypatch.setattr(settings, "supabase_url", "https://example.supabase.co")
    monkeypatch.setattr(settings, "supabase_anon_key", "test-anon-key")

    context = asyncio.run(
        ChatContextService().get_context(
            auth_user_id=AUTH_USER_ID,
            access_token="user-access-token",
            message="How many calories does chicken breast have?",
        )
    )

    assert context is not None
    assert context.fitness_goal == "weight_loss"
    assert context.calorie_target == 1700
    assert context.remaining_calories == 1100
    assert context.remaining_protein_g == 65
    assert context.remaining_budget_php == 250
    assert context.allergies == ["Peanuts"]
    assert context.dietary_restrictions == ["Dairy-free"]
    assert context.food_records[0].food_name == "Chicken Breast"
    assert context.food_records[0].serving_grams == 100
    assert captured
    assert all(call[2]["apikey"] == "test-anon-key" for call in captured)
    assert all(call[2]["Authorization"] == "Bearer user-access-token" for call in captured)
    assert all("service_role" not in call[2]["Authorization"] for call in captured)


def test_food_lookup_uses_recent_user_turn_for_follow_up(monkeypatch) -> None:
    captured = {}

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self):
            return []

    class FakeClient:
        def __init__(self, **_kwargs) -> None:
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_args) -> None:
            return None

        async def get(self, url, params, headers):
            table = url.rsplit("/", 1)[-1]
            if table == "food_catalog":
                captured.update(params)
            return FakeResponse()

    monkeypatch.setattr(
        "app.services.chat_context_service.httpx.AsyncClient",
        FakeClient,
    )
    monkeypatch.setattr(settings, "supabase_url", "https://example.supabase.co")
    monkeypatch.setattr(settings, "supabase_anon_key", "test-anon-key")

    asyncio.run(
        ChatContextService().get_context(
            auth_user_id=AUTH_USER_ID,
            access_token="user-access-token",
            message="How about 200 grams?",
            history=[
                ChatTurn(role="user", content="How many calories in chicken breast?"),
                ChatTurn(role="assistant", content="One serving is listed."),
            ],
        )
    )

    assert "food_name.ilike.*chicken*" in captured["or"]
    assert "normalized_name.ilike.*breast*" in captured["or"]


def test_context_skips_unrecognized_non_uuid_subject(monkeypatch) -> None:
    def fail_if_client_created(**_kwargs):
        raise AssertionError("invalid auth subject must not trigger database access")

    monkeypatch.setattr(
        "app.services.chat_context_service.httpx.AsyncClient",
        fail_if_client_created,
    )
    monkeypatch.setattr(settings, "supabase_url", "https://example.supabase.co")
    monkeypatch.setattr(settings, "supabase_anon_key", "test-anon-key")

    result = asyncio.run(
        ChatContextService().get_context(
            auth_user_id="not-a-supabase-user-id",
            access_token="user-access-token",
            message="Suggest lunch",
        )
    )

    assert result is None
