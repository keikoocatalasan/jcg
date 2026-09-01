# JCG Fitness / NutriSmart AI — Security Audit Report

**Date:** 2026-07-11  
**Scope:** Full source-code audit of the Flutter Android app, Python FastAPI backend, Supabase migrations/configuration, and deployment manifests.  
**Auditor:** OpenCode (automated + manual review)  
**Methodology:** Line-by-line reading of all application source files, pattern-based searches for secrets / unsafe constructs / missing controls, and architectural review of authentication, authorization, data flow, and secret management.

---

## 1. Executive Summary

The codebase contains **multiple critical and high-severity security issues**. The most severe is the exposure of production Supabase credentials, database passwords, and JWT secrets in plain text inside files that are either committed to version control or stored in the project root. Several backend and mobile controls are missing or misconfigured, including permissive CORS, weak password policy, fail-open account-status checks, and lack of secure token storage.

### Risk Snapshot

| Severity | Count |
|----------|-------|
| Critical | 4 |
| High     | 7 |
| Medium   | 10 |
| Low      | 5 |

**Immediate actions required:**
1. Rotate all exposed Supabase / database credentials and API keys.
2. Remove `.env`, `render.yaml`, and hardcoded defaults from source control.
3. Restrict backend CORS to known origins.
4. Fix fail-open login / account-status logic.
5. Enforce password complexity on the client and in Supabase Auth.

---

## 2. Scope & Methodology

### 2.1 In Scope

- `backend/app/` — FastAPI routes, auth, services, schemas, config, tests
- `flutter_app/lib/` — all Dart source files (~150 files)
- `flutter_app/android/app/src/main/AndroidManifest.xml`
- `flutter_app/pubspec.yaml`
- `supabase/migrations/` — all 22 SQL migration files
- `supabase/config.toml`
- `.env` files and `render.yaml`

### 2.2 Out of Scope

- `flutter_sdk/` — this is the Flutter framework itself, not application code
- IDE metadata, build artifacts, `.dart_tool/`, `build/`, `__pycache__/`
- Third-party services beyond configuration (e.g., Supabase hosted platform internals)

### 2.3 Audit Methodology

1. **Inventory** — listed every source file in the application directories.
2. **Secret sweep** — searched for URLs, tokens, passwords, keys, and DB connection strings.
3. **Auth / AuthZ review** — examined JWT verification, RLS policies, admin guards, and session handling.
4. **Input validation review** — checked file uploads, SQL operations, JSON parsing, and multipart handling.
5. **Mobile security review** — examined manifest, network config, storage, OAuth deeplink registration, and local DB.
6. **Configuration review** — examined `.env` files, `render.yaml`, `config.toml`, and `.gitignore` coverage.
7. **Code pattern review** — searched for unsafe patterns (`eval`, raw SQL concatenation, `print`, weak crypto, wildcard CORS).

---

## 3. Critical Findings

### CRIT-1: Production secrets committed to source control

**Severity:** Critical  
**Files:**
- `backend/.env`
- `flutter_app/.env`
- `supabase/.env`
- `render.yaml`

**Description:**
The following production secrets are stored in plain text inside the repository:
- Supabase project URL
- Supabase anon/public key
- Supabase JWT secret
- Supabase service-role key placeholder
- PostgreSQL `DATABASE_URL` and `DIRECT_URL` containing the database password
- `DB_PASSWORD`
- OpenAI API key placeholder
- Render deployment manifest exposes the real Supabase URL and anon key

The root `.gitignore` only ignores `backend/.env` and top-level `.env`; it does **not** ignore `flutter_app/.env`, `supabase/.env`, `supabase/config.toml`, or `render.yaml`. `supabase/.gitignore` is malformed and unlikely to work as intended.

**Impact:**
Anyone with access to the repository or the deployed filesystem can authenticate to Supabase, access/modify user data, and potentially escalate privileges using the service role key or database password.

**Fix:**
1. Immediately rotate **all** Supabase credentials and the database password in the Supabase dashboard.
2. Revoke/reissue the OpenAI API key if it was ever real.
3. Delete the four `.env` files and `render.yaml` from repository history (e.g., `git filter-repo` or BFG Repo-Cleaner).
4. Add the following to the root `.gitignore`:
   ```gitignore
   flutter_app/.env
   supabase/.env
   supabase/config.toml
   render.yaml
   *.env
   *.env.*
   ```
5. Store secrets only in environment variables / CI secrets / Render dashboard secret fields. Provide `.env.example` templates with placeholder values.

---

### CRIT-2: Hardcoded Supabase credentials as compile-time defaults

**Severity:** Critical  
**Files:**
- `flutter_app/lib/app/config.dart` lines 4–12
- `flutter_app/lib/features/auth/screens/session_loading_screen.dart` lines 120–128

**Description:**
The Flutter app uses `String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://<project>.supabase.co')` and `String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '<real-anon-key>')` with production values as defaults. `--dart-define` values can be extracted from compiled APKs/AABs using standard reverse-engineering tools; defaults are always present in the binary.

**Impact:**
Even after removing `.env` files, the production Supabase anon key and project URL are embedded in every released APK. Attackers can extract them and abuse the Supabase API (within RLS limits, but still enabling enumeration, sign-ups, password attacks, etc.).

**Fix:**
1. Remove the `defaultValue` parameters entirely; require `--dart-define` at build time and fail the build if missing.
   ```dart
   static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
   static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
   ```
2. In `main.dart`, assert that these are non-empty and throw a clear error if not.
3. Rotate the exposed anon key after the fix because the previous key is already in binaries.

---

### CRIT-3: Backend CORS allows all origins

**Severity:** Critical  
**Files:**
- `backend/app/main.py` line 7
- `backend/app/config.py` line 15
- `backend/.env` line 11
- `render.yaml` line 25–26

**Description:**
`CORSMiddleware` is configured with `allow_origins=["*"]` and `allow_methods=["*"]` and `allow_headers=["*"]`. The Render manifest sets `ALLOWED_ORIGINS: "*"`.

**Impact:**
Any malicious website can make authenticated cross-origin requests to the FastAPI backend using a stolen or leaked token, enabling CSRF-like attacks against AI endpoints and feedback endpoints.

**Fix:**
1. Replace `"*"` with an explicit list of origins, e.g.:
   ```python
   allow_origins=["https://your-android-app", "http://localhost:8000"]
   ```
   (For a mobile app, CORS is less relevant, but still set it to the production FastAPI domain.)
2. In `render.yaml`, set `ALLOWED_ORIGINS` via the Render dashboard secret, not in the committed manifest.
3. Default `allowed_origins` in `config.py` should be an empty list, not `"*"`.

---

### CRIT-4: Database connection strings exposed in plain text

**Severity:** Critical  
**File:** `backend/.env` lines 5–6

**Description:**
`DATABASE_URL` and `DIRECT_URL` contain the full PostgreSQL connection URI including password for the Supabase hosted database.

**Impact:**
Direct database access bypasses RLS and application logic, giving an attacker full read/write access to all tables.

**Fix:**
1. Rotate the database password immediately.
2. Remove these variables from the backend unless truly required. If required, fetch them from Render secrets, not `.env`.
3. Consider using Supabase connection pooling with IAM / SCRAM and restrict IP allow-lists in Supabase.

---

## 4. High Findings

### HIGH-1: Account-status check fails open

**Severity:** High  
**Files:**
- `flutter_app/lib/features/auth/auth_provider.dart` lines 92–116
- `flutter_app/lib/features/auth/screens/session_loading_screen.dart` lines 80–93

**Description:**
`checkAccountStatus` catches all exceptions and returns `Success(true)`. If the network is unavailable, RLS rejects the query, or the user row is missing, the app treats the check as passed and allows login.

**Impact:**
A disabled/banned user may still log in when the status check fails. An attacker can also force a failure condition (e.g., by blocking DNS) to bypass account suspension.

**Fix:**
1. Change the catch block to return a `Failure` with a generic error.
2. Distinguish “account disabled” (statusId == 2) from “unable to verify.”
3. In `session_loading_screen.dart`, treat any `Failure` as a login denial and sign the user out.

---

### HIGH-2: Weak password policy

**Severity:** High  
**Files:**
- `flutter_app/lib/core/validators/validators.dart` line 10
- `flutter_app/lib/features/auth/screens/register_screen.dart` lines 425–433
- `supabase/config.toml` lines 182, 185

**Description:**
- Client validator only checks length ≥ 8.
- UI shows requirements for number + uppercase but does not enforce them on submit.
- Supabase Auth config sets `minimum_password_length = 6` and `password_requirements = ""`.

**Impact:**
Users can create weak passwords (e.g., `password`), increasing risk of credential-stuffing and brute-force attacks.

**Fix:**
1. Enforce the same complexity on client and server:
   - minimum 8 characters
   - at least one uppercase, one lowercase, one digit
   - optionally one symbol
2. Update `validators.dart` and the register-screen validator.
3. Update `supabase/config.toml`:
   ```toml
   minimum_password_length = 8
   password_requirements = "lower_upper_letters_digits"
   ```

---

### HIGH-3: JWT verification accepts HS256 with a configurable secret

**Severity:** High  
**File:** `backend/app/auth/jwt_verifier.py` lines 11–33

**Description:**
The verifier accepts both symmetric `HS256` (using `SUPABASE_JWT_SECRET`) and asymmetric `RS256`/`ES256`. If `SUPABASE_JWT_SECRET` is weak or leaked, an attacker can forge HS256 tokens. The current `.env` value is a sentence-based string, not a cryptographically random key.

**Impact:**
Token forgery and authentication bypass if the JWT secret is compromised.

**Fix:**
1. For production, use only RS256/ES256 (Supabase default). Remove HS256 support or restrict it to `APP_ENV=test`.
2. Validate that `supabase_jwt_secret` is a high-entropy value when HS256 is enabled.
3. At startup, raise an error if JWT secret is empty and HS256 mode is active.
4. Validate that `payload.get("sub")` is non-null in `get_current_user_id`.

---

### HIGH-4: Supabase Auth security settings are weak

**Severity:** High  
**File:** `supabase/config.toml` lines 175–185, 225–228

**Description:**
- `enable_confirmations = false` — emails are not confirmed before login.
- `secure_password_change = false` — users do not need recent re-auth to change password.
- `minimum_password_length = 6`
- `additional_redirect_urls = ["https://127.0.0.1:3000"]` — local-only redirect.

**Impact:**
Account takeover is easier: stolen passwords can be changed without re-auth, and anyone can sign up with any email.

**Fix:**
1. Set `enable_confirmations = true` for production (or keep false only for local dev).
2. Set `secure_password_change = true`.
3. Set `minimum_password_length = 8` and `password_requirements = "lower_upper_letters_digits"`.
4. Replace `additional_redirect_urls` with production OAuth redirect URLs and add them to the Android/iOS manifest.

---

### HIGH-5: Missing rate limiting on backend endpoints

**Severity:** High  
**Files:**
- `backend/app/routes/chat.py`
- `backend/app/routes/scan_food.py`
- `backend/app/routes/scan_feedback.py`
- `backend/app/routes/explain_recommendation.py`

**Description:**
No rate limiting or maximum request size enforcement beyond the image upload limit. The FastAPI `UploadFile` is read entirely into memory.

**Impact:**
Attackers can abuse AI endpoints, causing cost inflation (OpenAI API calls once implemented) or denial of service.

**Fix:**
1. Add `slowapi` or in-memory rate limiting per user/IP.
2. Limit `/ai/chat` to e.g. 30 requests/minute per user.
3. Limit `/ai/scan-food` to e.g. 10 scans/minute per user.
4. Add request timeouts in `main.py` and streaming limits.

---

### HIGH-6: Insecure local token storage (Supabase defaults)

**Severity:** High  
**File:** `flutter_app/lib/main.dart` lines 9–12

**Description:**
`Supabase.initialize` is called without a custom `localStorage`. On Android, the default Supabase storage may fall back to `SharedPreferences`, where tokens are stored in plain XML accessible to root or backup-enabled attackers. The app declares `flutter_secure_storage` in `pubspec.yaml` but does not use it.

**Impact:**
Session tokens can be extracted from device storage, leading to account takeover on rooted/compromised devices.

**Fix:**
1. Configure Supabase to use `FlutterSecureStorage`:
   ```dart
   await Supabase.initialize(
     url: AppConfig.supabaseUrl,
     publishableKey: AppConfig.supabaseAnonKey,
     authOptions: const FlutterAuthClientOptions(
       authFlowType: AuthFlowType.pkce,
     ),
     // Use flutter_secure_storage adapter
   );
   ```
2. Implement a `LocalStorage` adapter backed by `flutter_secure_storage`.
3. Disable Android backups for the app or exclude shared_prefs from backups.

---

### HIGH-7: Local SQLite database is unencrypted

**Severity:** High  
**Files:**
- `flutter_app/lib/core/database/database_provider.dart`
- `flutter_app/lib/core/database/migration_v1.dart`

**Description:**
The app stores user health data, meal logs, weight, chat messages, and profile in a plain SQLite database at `jcg_fitness.db`.

**Impact:**
On a rooted device or via backup extraction, an attacker can read all local health and personal data.

**Fix:**
1. Encrypt the SQLite database using `sqlcipher_flutter_libs` or `sqflite_sqlcipher`.
2. Derive the encryption key from the user’s password or from secure hardware (Android Keystore / iOS Keychain), not a hardcoded key.
3. Exclude the database file from Android backups.

---

## 5. Medium Findings

### MED-1: `get_current_user_id` may return null

**Severity:** Medium  
**File:** `backend/app/auth/jwt_verifier.py` lines 57–59

**Description:**
`get_current_user_id` returns `payload.get("sub")`, which can be `None` if the token is malformed or missing the `sub` claim.

**Impact:**
Routes that use `user_id` for authorization could operate with a null user ID, potentially causing logic errors or data leakage.

**Fix:**
```python
user_id = payload.get("sub")
if not user_id:
    raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
return user_id
```

---

### MED-2: File upload validation relies on client-provided MIME type

**Severity:** Medium  
**File:** `backend/app/services/image_validation_service.py` lines 21–22

**Description:**
`file.content_type` is supplied by the client and can be spoofed. The extension check is also weak.

**Impact:**
An attacker can upload non-image files by setting `Content-Type: image/png`.

**Fix:**
1. Validate the actual file magic bytes using `python-magic` or Pillow’s format detection.
2. Reject files whose true format is not in the allow-list.
3. Limit image dimensions and pixel count to prevent decompression bombs.

---

### MED-3: Pillow image parsing is vulnerable to decompression bombs

**Severity:** Medium  
**File:** `backend/app/services/image_validation_service.py` lines 32–39

**Description:**
`Image.open(BytesIO(contents))` is called on untrusted input without `ImageFile.LOAD_TRUNCATED_IMAGES` control or pixel-count limits.

**Impact:**
A crafted image can cause excessive CPU/memory consumption, leading to DoS.

**Fix:**
```python
from PIL import ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = False
# enforce max pixels
if img.width * img.height > MAX_PIXELS:
    errors.append("Image too large")
```

---

### MED-4: Safety filter is trivially bypassed

**Severity:** Medium  
**Files:**
- `backend/app/services/safety_service.py`
- `backend/app/services/chatbot_service.py` lines 36–39

**Description:**
Blocked topics are detected with simple substring matching (`if topic in message.lower()`). Misspellings, translations, or obfuscation bypass it.

**Impact:**
Users can receive medical / harmful advice the system intends to block.

**Fix:**
1. Use a small classifier model or an LLM-based moderation layer.
2. Maintain an allow-list approach: reject unless the message is clearly nutrition-related.
3. Log and review blocked/redirected messages.

---

### MED-5: Chatbot context is concatenated unsafely for future LLM integration

**Severity:** Medium  
**File:** `backend/app/services/chatbot_service.py` lines 22–34

**Description:**
User context is concatenated directly into a string with no escaping, parameterization, or system-prompt separation. When real LLM integration is added, this invites prompt injection.

**Impact:**
Prompt injection can manipulate the AI to ignore safety rules or leak context.

**Fix:**
1. Use OpenAI/Anthropic message arrays with a fixed system prompt.
2. Treat user input as a user message only; never interpolate it into instructions.
3. Apply output filtering and avoid exposing raw context in replies.

---

### MED-6: Supabase GRANTs are overly broad for authenticated role

**Severity:** Medium  
**Files:**
- `supabase/migrations/000019_grant_authenticated_app_privileges.sql`
- `supabase/migrations/000021_grant_admin_report_privileges.sql`
- `supabase/migrations/000022_grant_admin_price_privileges.sql`

**Description:**
The migrations grant `DELETE` on many user tables and grant admin-only operations (`UPDATE/DELETE` on `community_report`, `INSERT/UPDATE/DELETE` on `food_price`) to the `authenticated` role. RLS policies mitigate this, but the defense-in-depth principle is violated.

**Impact:**
If RLS is accidentally disabled or bypassed, all authenticated users can modify prices, reports, and delete other users’ data.

**Fix:**
1. Remove admin-only grants from `authenticated`; rely on `service_role` or a dedicated admin role.
2. Grant only the minimum statements each role needs.
3. Add a migration audit test that verifies no dangerous grants exist.

---

### MED-7: Admin actions use wrong Supabase table names

**Severity:** Medium  
**File:** `flutter_app/lib/features/admin/screens/moderation_detail_screen.dart` lines 80–104

**Description:**
The code updates `post_reports` and `posts`, but the real tables are `community_report` and `community_post`. This will currently fail, but if table aliases are added later it could affect the wrong data.

**Impact:**
Functional failure now; potential data integrity issue later.

**Fix:**
1. Replace `post_reports` → `community_report` and `posts` → `community_post`.
2. Add unit/integration tests for admin moderation flows.

---

### MED-8: Custom food sync payload is not valid JSON

**Severity:** Medium  
**File:** `flutter_app/lib/features/food_database/food_provider.dart` line 138

**Description:**
`payloadJson: food.toMap().toString()` stores the Dart `toString()` representation instead of JSON. The sync service will fail to parse it.

**Impact:**
Custom foods created by users never sync to Supabase; data loss on device migration.

**Fix:**
```dart
payloadJson: jsonEncode(food.toMap()),
```

---

### MED-9: Sync entity type mismatch for custom/admin foods

**Severity:** Medium  
**Files:**
- `flutter_app/lib/features/food_database/food_provider.dart` line 135
- `flutter_app/lib/features/admin/screens/admin_food_form_screen.dart` line 167

**Description:**
Both use `entityTypeCode: 'food'`, but `sync_queue_service.dart` only maps `'custom_food'` to `food_item`. There is no case for `'food'`.

**Impact:**
Food create/update sync operations throw `Unknown entity type code: food`.

**Fix:**
Standardize on `'custom_food'` everywhere, or add `'food'` to `_entityTypeToTable` mapping.

---

### MED-10: `sync_initial_pull` queries non-existent Supabase table

**Severity:** Medium  
**File:** `flutter_app/lib/core/sync/sync_initial_pull.dart` lines 71–72

**Description:**
`pullUserData` queries `profiles` from Supabase, but the server table is `user_profile`.

**Impact:**
User data bridge after offline registration fails silently.

**Fix:**
Change `from('profiles')` to `from('user_profile')`.

---

## 6. Low Findings

### LOW-1: `explain_recommendation` accepts arbitrary markdown injection

**Severity:** Low  
**File:** `backend/app/routes/explain_recommendation.py` lines 25–44

**Description:**
`food_name` and `fitness_goal` are inserted into a Markdown explanation without sanitization. The UI may render this as text, but if rendered as Markdown/HTML, it enables injection.

**Fix:**
1. Sanitize or escape user-controlled fields before concatenation.
2. Return structured data and let the client render it safely.

---

### LOW-2: Client-side admin check can be bypassed on rooted devices

**Severity:** Low  
**File:** `flutter_app/lib/app/router.dart` lines 340–369

**Description:**
`_AdminGuard` checks `isAdminProvider` on the client. The actual protection comes from Supabase RLS, but the client-side guard gives a false sense of security.

**Impact:**
On a compromised client, the UI guard can be skipped; however, RLS still blocks unauthorized Supabase writes.

**Fix:**
Document that RLS is the authoritative enforcement. Consider adding server-side admin checks before sensitive FastAPI operations.

---

### LOW-3: OAuth redirect URL is not registered in Android manifest

**Severity:** Low  
**File:** `flutter_app/lib/features/auth/auth_provider.dart` line 122

**Description:**
Google sign-in uses redirect `io.jcgfitness://login-callback`, but `AndroidManifest.xml` has no intent-filter for that scheme.

**Impact:**
OAuth flow currently cannot complete; when fixed, it must be registered with `android:exported="true"` and protected to prevent hijacking.

**Fix:**
1. Add the intent filter when enabling OAuth.
2. Use App Links / verified domain for production instead of a custom scheme.

---

### LOW-4: `MAX_IMAGE_UPLOAD_MB` is a string in render manifest

**Severity:** Low  
**File:** `render.yaml` line 23–24

**Description:**
`MAX_IMAGE_UPLOAD_MB` is declared as a string `"5"` instead of an integer.

**Impact:**
Pydantic may coerce it, but this is inconsistent and could break validation.

**Fix:**
Remove `MAX_IMAGE_UPLOAD_MB` from the committed manifest; set it as a Render secret or environment variable, and parse it robustly in `config.py`.

---

### LOW-5: `SUPABASE_SERVICE_ROLE_KEY` placeholder in Render manifest

**Severity:** Low  
**File:** `render.yaml` line 17–18

**Description:**
The service role key is a literal `placeholder_service_role_key`.

**Impact:**
If someone accidentally replaces it with the real key in the committed file, the service role key is exposed.

**Fix:**
Set `sync: false` for `SUPABASE_SERVICE_ROLE_KEY` (like `SUPABASE_JWT_SECRET` and `AI_MODEL_API_KEY`) and remove the placeholder value.

---

## 7. Remediation Plan

### Phase 1 — Immediate (within 24 hours)

| # | Action | Owner | Verification |
|---|--------|-------|--------------|
| 1.1 | Rotate Supabase anon key, JWT secret, service role key, and database password. | Backend lead | Old credentials return 401. |
| 1.2 | Delete `backend/.env`, `flutter_app/.env`, `supabase/.env`, and `render.yaml` from repo history using BFG/filter-repo. | DevOps | `git log --all --full-history -- <file>` returns nothing. |
| 1.3 | Update root `.gitignore` to ignore all `.env` files, `render.yaml`, and `supabase/config.toml`. | DevOps | New secret files are untracked. |
| 1.4 | Restrict FastAPI CORS to known origins only. | Backend | `curl -H Origin:evil.com` is rejected. |
| 1.5 | Change fail-open account-status check to fail-closed. | Mobile | Unit test: exception returns Failure, user is signed out. |

### Phase 2 — Short term (within 1 week)

| # | Action | Owner | Verification |
|---|--------|-------|--------------|
| 2.1 | Remove hardcoded Supabase defaults from `config.dart` and `session_loading_screen.dart`; add build-time assertions. | Mobile | APK strings dump does not contain real key. |
| 2.2 | Enforce password complexity client-side and in Supabase Auth config. | Mobile + Backend/DB | Registration rejects `password`. |
| 2.3 | Restrict JWT verification to RS256/ES256 in production; remove HS256 fallback or gate it to tests. | Backend | Unit test with HS256 token fails in prod mode. |
| 2.4 | Harden Supabase Auth config (`enable_confirmations`, `secure_password_change`, stronger passwords). | Backend/DB | Config diff shows hardened values. |
| 2.5 | Add rate limiting to `/ai/*` endpoints. | Backend | Load test shows 429 responses. |
| 2.6 | Configure Supabase to use `flutter_secure_storage`. | Mobile | Tokens not in plain shared_prefs. |
| 2.7 | Encrypt local SQLite or exclude it from backups. | Mobile | Database file is not readable as plain text. |

### Phase 3 — Medium term (within 1 month)

| # | Action | Owner | Verification |
|---|--------|-------|--------------|
| 3.1 | Replace MIME-type based upload validation with magic-byte validation and decompression-bomb limits. | Backend | Upload spoofed PNG fails. |
| 3.2 | Implement real safety filter (classifier/LLM moderation). | Backend | Penetration test of blocked topics passes. |
| 3.3 | Refactor chatbot service to use structured system/user messages. | Backend | Prompt injection test fails. |
| 3.4 | Tighten Supabase GRANTs; remove admin operations from `authenticated` role. | Backend/DB | Migration test verifies grants. |
| 3.5 | Fix admin moderation table names and add tests. | Mobile | Admin can hide/dismiss reports. |
| 3.6 | Fix custom-food JSON payload and entity-type mapping. | Mobile | Custom foods sync successfully. |
| 3.7 | Fix `sync_initial_pull` table name (`profiles` → `user_profile`). | Mobile | Offline registration bridge works. |

---

## 8. Verification Checklist

Before the next release, confirm:

- [ ] No real secrets exist in any committed file.
- [ ] `flutter strings app-release.apk | grep -i eyJ` returns no JWT/key fragments.
- [ ] CORS preflight from unauthorized origins is rejected.
- [ ] Disabled users cannot log in even when offline/network fails.
- [ ] Passwords < 8 chars or without complexity are rejected.
- [ ] JWT signed with HS256 is rejected in production.
- [ ] Rate limiting returns 429 on excessive AI calls.
- [ ] Tokens are stored in secure storage, not `SharedPreferences`.
- [ ] SQLite database is encrypted or excluded from backups.
- [ ] RLS policies pass integration tests for each table.
- [ ] Custom foods and admin foods sync end-to-end.

---

## 9. Appendix A — Files Audited

### Backend (Python)
- `backend/app/main.py`
- `backend/app/config.py`
- `backend/app/auth/jwt_verifier.py`
- `backend/app/routes/chat.py`
- `backend/app/routes/explain_recommendation.py`
- `backend/app/routes/health.py`
- `backend/app/routes/scan_feedback.py`
- `backend/app/routes/scan_food.py`
- `backend/app/routes/version.py`
- `backend/app/schemas/chatbot.py`
- `backend/app/schemas/common.py`
- `backend/app/schemas/scan_food.py`
- `backend/app/services/chatbot_service.py`
- `backend/app/services/image_validation_service.py`
- `backend/app/services/safety_service.py`
- `backend/app/services/scanner_service.py`
- `backend/tests/test_api_smoke.py`
- `backend/requirements.txt`

### Flutter (Dart)
All files under `flutter_app/lib/` were reviewed, with special attention to:
- `flutter_app/lib/app/config.dart`
- `flutter_app/lib/app/router.dart`
- `flutter_app/lib/main.dart`
- `flutter_app/lib/core/network/api_client.dart`
- `flutter_app/lib/core/network/supabase_client_provider.dart`
- `flutter_app/lib/core/database/database_provider.dart`
- `flutter_app/lib/core/database/migration_v1.dart`
- `flutter_app/lib/core/sync/sync_queue_service.dart`
- `flutter_app/lib/core/sync/sync_initial_pull.dart`
- `flutter_app/lib/core/sync/local_transaction_helper.dart`
- `flutter_app/lib/core/validators/validators.dart`
- `flutter_app/lib/features/auth/auth_provider.dart`
- `flutter_app/lib/features/auth/screens/session_loading_screen.dart`
- `flutter_app/lib/features/auth/screens/register_screen.dart`
- `flutter_app/lib/features/admin/admin_provider.dart`
- `flutter_app/lib/features/admin/screens/admin_food_form_screen.dart`
- `flutter_app/lib/features/admin/screens/moderation_detail_screen.dart`
- `flutter_app/lib/features/admin/screens/price_history_screen.dart`
- `flutter_app/lib/features/admin/screens/reports_screen.dart`
- `flutter_app/lib/features/community/community_provider.dart`
- `flutter_app/lib/features/chatbot/chatbot_provider.dart`
- `flutter_app/lib/features/food_database/food_provider.dart`
- `flutter_app/lib/features/profile_settings/profile_provider.dart`
- `flutter_app/lib/features/onboarding/onboarding_controller.dart`

### Database / Config
- `supabase/migrations/000001_create_lookup_tables.sql` through `000022_grant_admin_price_privileges.sql`
- `supabase/config.toml`
- `supabase/seed.sql`
- `flutter_app/android/app/src/main/AndroidManifest.xml`
- `flutter_app/android/app/src/debug/AndroidManifest.xml`
- `flutter_app/android/app/src/profile/AndroidManifest.xml`
- `flutter_app/pubspec.yaml`
- `.gitignore`
- `render.yaml`
- `backend/.env`, `backend/.env.example`
- `flutter_app/.env`, `flutter_app/.env.example`
- `supabase/.env`, `supabase/.env.example`
