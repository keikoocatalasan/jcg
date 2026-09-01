# NutriSmart AI — FastAPI examples

These are the routes implemented by `backend/app/main.py`. Application data such as foods, logs, profiles, plans, recommendations, and community posts is accessed through Supabase, not duplicate FastAPI CRUD routes.

Set the base URL and use a Supabase access token for authenticated AI routes.

## Service status

```bash
curl http://localhost:8000/health
curl http://localhost:8000/readiness
curl http://localhost:8000/version
```

## Scan food

The multipart field is named `file`. `client_scan_id` is preserved in the response, making retries idempotently identifiable.

```bash
curl -X POST http://localhost:8000/ai/scan-food \
  -H "Authorization: Bearer <token>" \
  -F "file=@food.jpg" \
  -F "meal_type=lunch" \
  -F "client_scan_id=550e8400-e29b-41d4-a716-446655440000"
```

```json
{
  "client_scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "manual_search_recommended": false,
  "candidates": [
    {
      "food_id": null,
      "food_name": "Chicken Adobo",
      "confidence": 0.87,
      "rank_number": 1,
      "calories": 480,
      "protein_g": 35,
      "carbs_g": 12,
      "fat_g": 30,
      "estimated_cost_php": 85
    }
  ]
}
```

## Submit scan feedback

```bash
curl -X POST http://localhost:8000/ai/scan-feedback \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "feedback_id": "660e8400-e29b-41d4-a716-446655440000",
    "client_scan_id": "550e8400-e29b-41d4-a716-446655440000",
    "selected_food_id": null,
    "was_helpful": true,
    "feedback_text": null
  }'
```

## Chat

```bash
curl -X POST http://localhost:8000/ai/chat \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "chat_session_id": "770e8400-e29b-41d4-a716-446655440000",
    "client_message_id": "880e8400-e29b-41d4-a716-446655440000",
    "message": "Suggest a Filipino lunch within my remaining budget.",
    "context": {
      "fitness_goal": "maintenance",
      "remaining_budget_php": 150,
      "remaining_calories": 600,
      "remaining_protein_g": 30,
      "allergies": ["Peanut"],
      "dietary_restrictions": []
    }
  }'
```

## Explain a recommendation

```bash
curl -X POST http://localhost:8000/ai/explain-recommendation \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "food_name": "Chicken Adobo with Rice",
    "calories": 520,
    "protein_g": 30,
    "carbs_g": 60,
    "fat_g": 15,
    "estimated_cost_php": 85,
    "fitness_goal": "maintenance"
  }'
```

## Account email flows

The backend implements these unauthenticated JSON routes:

- `POST /auth/forgot-password` with `{"email":"user@example.com"}`
- `POST /auth/verify-reset-otp` with `{"email":"user@example.com","otp":"123456"}`
- `POST /auth/reset-password` with `{"reset_token":"<token>","new_password":"<password>"}`
- `POST /auth/send-confirmation` with `{"email":"user@example.com"}`
- `POST /auth/verify-email` with `{"email":"user@example.com","otp":"123456"}`

Supabase Auth handles registration, login, and access-token issuance directly.
