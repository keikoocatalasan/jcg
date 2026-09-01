# NutriSmart AI — Security Hardening Checklist

> Status as of: June 2026  
> Project: JCG Fitness / NutriSmart AI  
> Scope: Flutter mobile app + FastAPI backend + Supabase

---

## Checklist

| # | Requirement | Status | Notes |
|---|------------|--------|-------|
| 1 | **No service role keys in Flutter** | ✅ Done | Service role key never embedded in Flutter source. Only anon key is configured in `supabase_client_provider.dart`. |
| 2 | **Flutter uses anon key only** | ✅ Done | Flutter client initializes with `supabaseKey` (anon key). All client-side operations use Row Level Security (RLS). |
| 3 | **RLS enabled on all user-owned tables** | ✅ Done | Every Supabase table that holds user data has RLS policies applied. Policy restricts `SELECT`/`INSERT`/`UPDATE`/`DELETE` to rows where `auth.uid()` = `user_id`. |
| 4 | **Admin-only moderation** | ✅ Done | Community post reporting and moderation endpoints are restricted to users with `role_code = 'admin'` on the FastAPI middleware layer. Admin-only Supabase RLS policy also applies. |
| 5 | **SQLite in app internal storage** | ✅ Done | Offline database stored via `sqflite` using `getDatabasesPath()` which resolves to app-internal storage. Not accessible to other apps or external storage. |
| 6 | **No secrets in logs** | ✅ Done | All log statements (debug, info, error) are audited. Supabase API keys, JWT tokens, and user passwords are never written to logs. `flutter_secure_storage` used for token persistence. |
| 7 | **JWT verification on FastAPI** | ✅ Done | All protected FastAPI endpoints verify the Supabase JWT via `supabase-py` `auth.get_user()` or manual JWT decode. Invalid/expired tokens return 401. |
| 8 | **CORS configured** | ✅ Done | FastAPI CORS middleware allows only the production app origin(s). No wildcard `Access-Control-Allow-Origin` in production. |
| 9 | **Medical disclaimer shown** | ✅ Done | Onboarding flow includes `onboarding_disclaimer_screen.dart` that requires explicit acceptance (`disclaimer_accepted = true`) before proceeding. Stored in `profiles.disclaimer_version`. |
| 10 | **Chatbot has safety disclaimer** | ✅ Done | Chatbot welcome message includes notice: "I am an AI assistant and not a medical professional. Consult a healthcare provider for medical advice." Stored as first system message in each session. |

---

## Verification Steps

### Anon Key Configuration
```
File: lib/core/network/supabase_client_provider.dart
- Confirm only `supabaseKey` (anon) is present
- Confirm `serviceRoleKey` is NOT imported or referenced anywhere in Flutter
```

### RLS Policy Sample (Supabase SQL)
```sql
-- Example RLS policy for meal_logs
CREATE POLICY "Users can only access their own meal logs"
  ON meal_logs
  FOR ALL
  USING (auth.uid() = user_id);
```

### SQLite Storage Location
```
Platform: Android   → /data/data/com.jcg.fitness/databases/jcg_fitness.db
Platform: iOS       → NSLibraryDirectory / Database / jcg_fitness.db
```

### JWT Verification (FastAPI)
```python
# In middleware or dependency
user = supabase.auth.get_user(token)
if not user:
    raise HTTPException(status_code=401, detail="Invalid token")
```

### CORS Configuration (FastAPI)
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://nutrismart.ai"],
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

---

## Incident Response

| Scenario | Action |
|----------|--------|
| Key exposed in commit | Immediately rotate Supabase anon/service keys via Supabase dashboard. Revoke old keys. |
| RLS bypass suspected | Audit Supabase query logs. Verify all policies using `auth.uid()` checks. |
| JWT token leak | Tokens are short-lived (1hr default). No action needed unless service role key is compromised. |
| Unauthorized admin access | Check admin role in `profiles.role_code`. Verify FastAPI admin middleware. |
