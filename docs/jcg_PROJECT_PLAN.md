# JCG Fitness — Project Plan

> **Budget-aware nutrition tracking for Filipino students**
> Last updated: 2026-07-20

---

## 1. Project Overview

**JCG Fitness** is a mobile-first nutrition tracking application designed for budget-conscious Filipino students. It combines meal logging, AI-powered food scanning, personalized recommendations, and community features — all while respecting a daily budget constraint in Philippine Pesos (PHP).

### Core Value Proposition

| Problem | Solution |
|---------|----------|
| Nutrition apps ignore budget reality | Budget-first recommendation engine scores foods by affordability + nutrition |
| Filipino food databases are sparse | Curated catalog of local foods with PHP pricing |
| Offline access needed (commute, campus) | SQLite offline-first architecture with background sync |
| AI features feel disconnected | Integrated chatbot + food scanner with safety guardrails |

### Target Users

- Filipino college students tracking calories/macros on a budget
- Budget-conscious individuals wanting affordable meal recommendations
- Users who need offline access (limited campus WiFi)

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Dart)                    │
│  Material Design 3 · Impeller · Riverpod · GoRouter     │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  16 Feature  │  │  21 SQLite   │  │  Background  │  │
│  │   Modules    │  │   Repos      │  │    Sync      │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                 │                 │           │
│         └─────────┬───────┴─────────────────┘           │
│                   │                                     │
│         ┌─────────▼─────────┐                           │
│         │   API Client      │                           │
│         │ (http + supabase) │                           │
│         └─────────┬─────────┘                           │
└───────────────────┼─────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
┌───────▼───────┐     ┌─────────▼─────────┐
│  FASTAPI      │     │    SUPABASE        │
│  (Python)     │     │  (PostgreSQL 17)   │
│               │     │                    │
│  /ai/scan-food│     │  Auth (JWT+OTP)    │
│  /ai/chat     │     │  RLS Policies      │
│  /auth/*      │     │  Realtime          │
│  /health      │     │  Storage           │
└───────┬───────┘     └─────────┬──────────┘
        │                       │
        └───────────┬───────────┘
                    │
            ┌───────▼───────┐
            │  Render.com   │
            │  (Deployment) │
            └───────────────┘
```

### Data Flow

1. **Online path**: Flutter app → FastAPI API → Supabase REST API → PostgreSQL
2. **Offline path**: Flutter app → SQLite repos → sync_queue → WorkManager background sync → Supabase
3. **Auth path**: Supabase Auth (email OTP / Google Sign-In) → JWT → FastAPI jwt_verifier

---

## 3. Tech Stack Reference

### Mobile Frontend

| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Dart | SDK >=3.0.0 <4.0.0 |
| Framework | Flutter | 3.x |
| Rendering | Impeller | Enabled |
| State Management | Riverpod | 2.4.9 |
| Code Generation | riverpod_generator | 2.3.9 |
| Routing | GoRouter | 13.0.0 |
| Local Database | sqflite (SQLite) | 2.3.0 |
| HTTP | http | 1.1.2 |
| Cloud Client | supabase_flutter | 2.0.0 |
| Camera | camera | 0.10.5 |
| Charts | fl_chart | 0.66.0 |
| Background Sync | workmanager | 0.9.0 |
| Secure Storage | flutter_secure_storage | 9.0.0 |
| Google Auth | google_sign_in | 6.2.1 |
| Connectivity | connectivity_plus | 6.0.0 |
| Permissions | permission_handler | 11.3.1 |
| Fonts | JetBrains Mono via google_fonts | 6.1.0 |

### Backend

| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Python | 3.11.9 |
| Framework | FastAPI | 0.109.0 |
| ASGI Server | Uvicorn | 0.27.0 |
| Validation | Pydantic | 2.5.3 |
| Settings | pydantic-settings | 2.1.0 |
| Auth | PyJWT | 2.8.0 |
| HTTP Client | httpx | >=0.24.0,<0.26.0 |
| Database Client | supabase (Python) | 2.0.0 |
| Image Processing | Pillow | 11.3.0 |
| Email | Brevo SMTP relay | smtp-relay.brevo.com:587 |
| Testing | pytest | 8.0.0 |

### Database

| Component | Technology | Details |
|-----------|-----------|---------|
| Cloud Database | Supabase (PostgreSQL 17) | Hosted, 24 migrations |
| Local Dev DB | Supabase CLI | Port 54322 |
| Local API | Supabase REST | Port 54321 |
| Studio | Supabase Studio | Port 54323 |
| Shadow DB | PostgreSQL | Port 54320 |
| Email Testing | Inbucket | Port 54324 |
| Row Level Security | Enabled | All user tables |
| Realtime | Enabled | Community features |
| Edge Runtime | Deno 2 | per_worker policy |

### Deployment

| Component | Target | Config |
|-----------|--------|--------|
| Backend | Render.com | `render.yaml` blueprint |
| APK Distribution | GitHub Releases | Manual upload |
| Landing Page | Static HTML | `landing_page/` |

---

## 4. Feature Inventory

### Flutter Feature Modules (`flutter_app/lib/features/`)

| # | Module | Status | Description |
|---|--------|--------|-------------|
| 1 | **auth** | ✅ Built | Login, register, forgot password, OTP email verification, Google Sign-In, terms/privacy screens |
| 2 | **onboarding** | ✅ Built | 7-step flow: nickname → stats → goal → allergies → budget → review → disclaimer |
| 3 | **dashboard** | ✅ Built | Home screen with daily summary, quick actions |
| 4 | **meal_logging** | ✅ Built | Log meals, search food, quantity picker, edit/delete logs, recent logs |
| 5 | **meal_planner** | ✅ Built | Plan meals per day, mark skipped, convert planned→logged, day summary |
| 6 | **food_database** | ✅ Built | Food search, custom food creation, food detail view |
| 7 | **nutrition** | ✅ Built | Nutrition targets, macro calculation engine |
| 8 | **hydration** | ✅ Built | Water tracking, hydration history, quick log |
| 9 | **weight_tracking** | ✅ Built | Weight logging, weight history chart |
| 10 | **recommendations** | ✅ Built | Multi-factor scoring engine (affordability, protein, calories, macros, goal match, allergen filtering) |
| 11 | **analytics** | ✅ Built | Calorie adherence, macro consistency chart, spending chart |
| 12 | **community** | ✅ Built | Posts, create post, post detail, report dialog, community cache |
| 13 | **chatbot** | 🟡 UI Built, Backend Stubbed | Chat UI + history screen, but backend returns hardcoded reply |
| 14 | **ai_scanner** | 🟢 Connected | Camera → scan → prediction → manual correction; OpenAI vision is configurable with deterministic demo fallback |
| 15 | **profile_settings** | ✅ Built | Edit profile, settings, sync status, clear cache |
| 16 | **admin** | ✅ Built | Admin dashboard, food management, moderation, price history, reports |

### Backend API Endpoints

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| `/health` | GET | ✅ Built | Health check |
| `/readiness` | GET | ✅ Built | Readiness probe |
| `/version` | GET | ✅ Built | API version |
| `/auth/verify-otp` | POST | ✅ Built | Email OTP verification |
| `/auth/send-otp` | POST | ✅ Built | Send OTP email |
| `/auth/register` | POST | ✅ Built | User registration |
| `/ai/scan-food` | POST | 🟢 Connected | Image upload → configured OpenAI vision or deterministic demo recognition |
| `/ai/scan-feedback` | POST | ✅ Built | Submit scan correction feedback |
| `/ai/chat` | POST | 🟢 Connected | Safety-gated configured OpenAI response or deterministic demo response |
| `/ai/explain-recommendation` | POST | 🟡 Stubbed | Explain why a food was recommended |

---

## 5. Current State Assessment

### What's Working

- **Authentication**: Full auth flow with Supabase Auth, email OTP, Google Sign-In, JWT verification on backend
- **Offline-First Architecture**: 21 SQLite repository classes, `DatabaseProvider` with WAL mode, foreign keys enabled
- **Background Sync**: WorkManager integration, `SyncQueueService`, `ConflictResolver`, `SyncInitialPull`
- **Recommendation Engine**: Multi-factor scoring algorithm (`recommendation_engine.dart`, 357 lines) — affordability (30%), protein fit (25%), calorie fit (20%), macro balance (15%), goal match (5%), meal type (5%)
- **Allergen/Dietary Filtering**: Comprehensive allergen category map, name keyword matching, restriction exclusion
- **Meal Planning**: Full CRUD with day summaries, skip marking, planned→logged conversion
- **Community**: Posts, reports, offline cache
- **Safety Guardrails**: Chatbot topic blocking (medical, eating disorders, extreme fasting), rate limiting (30 req/60s)
- **Admin Panel**: Food management, moderation, price history, reports

### What's Stubbed / Not Connected

| Component | Status | Details |
|-----------|--------|---------|
| **AI Food Scanner** | Mock data | `ScannerService.scan_image()` returns hardcoded rice candidates (`scanner_service.py:17`) |
| **AI Chatbot** | Configurable | OpenAI Responses API in `openai_responses_service.py`; deterministic mode remains available for tests and offline demos |
| **Recommendation Explainer** | Deterministic | Route returns a nutrition, goal, and budget explanation from submitted recommendation data |
| **AI Model Integration** | Configurable | OpenAI Responses API is wired; `deterministic` remains the default deployment mode until provider credentials are configured |
| **Real-time Sync** | Partial | Supabase realtime enabled but Flutter side uses polling-based WorkManager |

### What Doesn't Exist

- **No 3D features**: No Three.js, Babylon.js, React Three Fiber, or `.gltf`/`.glb` files
- **No SISP Portal**: No Node.js, no Spring Boot, no separate portal application
- **No Kotlin/Jetpack Compose**: The Android app is pure Flutter, not native Android
- **No on-device TensorFlow Lite**: AI inference is server-side, with OpenAI and deterministic provider modes
- **No vector database / RAG**: Chatbot has no retrieval-augmented generation
- **No Docker**: No containerization setup
- **No CI/CD pipeline**: No GitHub Actions workflows

---

## 6. AI Integration Roadmap

### Phase 1: Food Scanner — Real Vision Model

**Current**: Mock candidates in `ScannerService`
**Target**: Real food recognition from uploaded images

| Option | Pros | Cons |
|--------|------|------|
| **OpenAI Vision API** | High accuracy, easy integration, supports food recognition | Cost per image, requires internet |
| **Google Cloud Vision** | Good food detection, PHP-friendly pricing | Setup complexity |
| **Hugging Face Inference** | Free tier available, open models | Lower accuracy for food |
| **Custom TFLite model** | Offline capable, no per-call cost | Training data needed, large model size |

**Recommended**: OpenAI Vision API via FastAPI backend (already has `ai_model_api_key` config)

**Implementation plan**:
1. Configure and validate the selected scanner provider in the target environment
2. Parse response into `ScanCandidate` objects with confidence scores
3. Add food name → Supabase food catalog lookup for nutrition data
4. Keep existing confidence threshold (>0.60 = auto, else manual search)

### Phase 2: Chatbot — LLM Integration

**Current**: Hardcoded reply in `ChatbotService`
**Target**: Context-aware nutrition assistant

| Option | Pros | Cons |
|--------|------|------|
| **OpenAI GPT-4o-mini** | Cheap, fast, good nutrition knowledge | API dependency |
| **OpenAI GPT-4o** | Best reasoning | Higher cost |
| **Ollama (local)** | Free, offline | Needs server resources |
| **Supabase Edge Function + AI** | Integrated with existing infra | Limited runtime |

**Recommended**: OpenAI GPT-4o-mini with system prompt + user context injection

**Implementation plan**:
1. Build system prompt with nutrition guidelines, Filipino food knowledge, safety rules
2. Inject `ChatContext` (fitness goal, remaining calories, dietary restrictions) into user message
3. Call OpenAI API via httpx in `ChatbotService.get_response()`
4. Keep existing safety guardrails (`safety_service.py`) as pre-filter
5. Store conversations in Supabase `chat_messages` table

### Phase 3: Recommendation Explainer

**Current**: Route registered but no service implementation
**Target**: "Why was this food recommended?" natural language explanation

**Implementation plan**:
1. Accept food ID + user context
2. Re-run scoring algorithm to get factor breakdown
3. Use LLM to generate human-readable explanation from scores
4. Cache explanations in `recommendation_items` table

---

## 7. Infrastructure & Deployment

### Local Development Ports

| Service | Port | Command |
|---------|------|---------|
| Supabase API | 54321 | `supabase start` |
| PostgreSQL DB | 54322 | (via Supabase CLI) |
| Shadow DB | 54320 | (via Supabase CLI) |
| Supabase Studio | 54323 | http://127.0.0.1:54323 |
| Inbucket (email) | 54324 | http://127.0.0.1:54324 |
| FastAPI Backend | 8000 | `uvicorn app.main:app --host 0.0.0.0 --port 8000` |
| Android Emulator | 5554 | `emulator -avd <name>` |
| Analytics | 54327 | (via Supabase CLI) |

### Environment Variables

**Backend (`backend/.env`)**:
```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=<local-anon-key>
SUPABASE_JWT_SECRET=<local-jwt-secret>
SUPABASE_SERVICE_ROLE_KEY=<local-service-role-key>
AI_MODEL_PROVIDER=deterministic
AI_MODEL_API_KEY=
MAX_IMAGE_UPLOAD_MB=5
ALLOWED_ORIGINS=http://127.0.0.1:3000
ENVIRONMENT=development
RATE_LIMIT_REQUESTS=30
RATE_LIMIT_WINDOW_SECONDS=60
BREVO_API_KEY=<brevo-key>
BREVO_SENDER_EMAIL=keikoocatalasan@gmail.com
```

**Flutter (`flutter_app/.env`)**:
```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=<local-anon-key>
FASTAPI_BASE_URL=http://10.0.2.2:8000
APP_ENV=development
GOOGLE_WEB_CLIENT_ID=<google-client-id>
```

### Launch Commands

```powershell
# Start Supabase local
cd C:\Users\john\projects\jcg\supabase
supabase start

# Start backend
cd C:\Users\john\projects\jcg\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Launch Flutter app on emulator
cd C:\Users\john\projects\jcg\flutter_app
flutter run -d emulator-5554 --dart-define-from-file=.env
```

### Production Deployment

- **Backend**: Render.com via `render.yaml` — `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
- **Database**: Supabase Cloud (managed PostgreSQL 17)
- **APK**: GitHub Releases (manual build + upload)
- **Landing Page**: Static hosting (GitHub Pages or similar)

---

## 8. Database Schema Overview

### Migration Files (23 total)

| Migration | Purpose |
|-----------|---------|
| `000001` | Lookup tables: ROLE, ACCOUNT_STATUS, SEX, ACTIVITY_LEVEL, FITNESS_GOAL, MEAL_TYPE, ALLERGY, FOOD_CATEGORY |
| `000002` | Users, profiles tables |
| `000003` | nutrition_targets, daily_target_snapshots |
| `000004` | Food catalog with Filipino foods + PHP pricing |
| `000005` | Tracking: meal_logs, water_logs, weight_logs |
| `000006` | Planner: meal_plans; Recommendations: sessions + items |
| `000007` | AI scanner: scan_results, scan_predictions |
| `000008` | Chatbot: chat_sessions, chat_messages |
| `000009` | Community: posts, post_reports |
| `000010` | Sync: sync_queue for offline changes |
| `000011` | Row Level Security policies |
| `000012` | Seed lookup tables |
| `000013` | Seed goal policies |
| `000014` | Seed allergies and foods |
| `000015` | Auto-create profile on auth signup (trigger) |
| `000016-000019` | GRANTs for community, app_user, authenticated roles |
| `000020` | Food catalog view |
| `000021-00022` | Admin report/price privileges |
| `000023` | AI scan feedback table |

### Key Tables

```
auth.users (Supabase managed)
    └── profiles (user profile, linked via FK)
        ├── nutrition_targets (macro/calorie goals)
        ├── daily_target_snapshots (daily rollup)
        ├── meal_logs (what user ate)
        ├── water_logs (hydration tracking)
        ├── weight_logs (weight over time)
        ├── meal_plans (planned meals)
        ├── recommendation_sessions + items
        ├── chat_sessions + messages
        ├── ai_scan_results + predictions + feedback
        ├── community_posts + reports
        └── sync_queue (offline change tracking)

food_catalog (Filipino foods with pricing)
food_categories (lookup)
allergies (lookup)
```

### SQLite Schema (Offline)

21 repository classes mirror key tables:
- `food_repository`, `meal_log_repository`, `meal_plan_repository`
- `profile_repository`, `nutrition_target_repository`
- `chat_message_repository`, `chat_session_repository`
- `community_cache_repository`, `sync_queue_repository`
- `water_log_repository`, `weight_log_repository`
- `recommendation_item_repository`, `recommendation_session_repository`
- `daily_target_snapshot_repository`
- `ai_scan_repository`, `ai_scan_prediction_repository`, `ai_scan_feedback_repository`
- `app_settings_repository`

---

## 9. Known Gaps & Technical Debt

### Critical

| Gap | Impact | Effort |
|-----|--------|--------|
| Deterministic AI mode is used in production | Results remain demo-only | Configure and validate the OpenAI provider before release |
| Chatbot returns hardcoded reply | Core feature non-functional | Medium (LLM integration) |
| No real AI model configured | `AI_MODEL_PROVIDER=deterministic` | Low (config change) |

### High

| Gap | Impact | Effort |
|-----|--------|--------|
| No CI/CD pipeline | Manual testing, no automated checks | Low |
| No integration tests | E2E flows untested | Medium |
| Backend tests only cover smoke | Most endpoints untested | Medium |
| `explain-recommendation` endpoint unimplemented | Dead route | Low |

### Medium

| Gap | Impact | Effort |
|-----|--------|--------|
| No Docker setup | Dev environment inconsistency | Low |
| No API documentation (OpenAPI/Swagger) | Hard for consumers | Low (FastAPI auto-generates) |
| Flutter unit tests cover only 5 files | Limited regression safety | Medium |
| No error tracking (Sentry, etc.) | Silent production errors | Low |

### Low

| Gap | Impact | Effort |
|-----|--------|--------|
| Landing page is minimal | Marketing limitation | Low |
| No analytics/telemetry | No usage insights | Low |
| `flutter_sdk/` clone in repo | Disk bloat (gitignored) | None |
| ProGuard rules may need tuning | Potential release crashes | Low |

---

## 10. Milestones & Timeline

### Phase 1: AI Integration (Weeks 1-3)

**Goal**: Make food scanner and chatbot functional

| Task | Priority | Est. |
|------|----------|------|
| Integrate OpenAI Vision API in `ScannerService` | P0 | 3 days |
| Wire food name → Supabase catalog lookup | P0 | 1 day |
| Implement LLM chatbot in `ChatbotService` | P0 | 3 days |
| Build system prompt with nutrition context | P0 | 1 day |
| Implement `explain-recommendation` endpoint | P1 | 1 day |
| Add API key rotation / error handling | P1 | 1 day |
| Test AI endpoints end-to-end | P1 | 1 day |

**Exit criteria**: Food scanner identifies real foods, chatbot responds to nutrition questions

### Phase 2: Polish & Testing (Weeks 4-5)

**Goal**: Production-ready quality

| Task | Priority | Est. |
|------|----------|------|
| Add integration tests for auth flow | P0 | 2 days |
| Add backend tests for all AI routes | P0 | 2 days |
| Add flutter_test for key flows | P1 | 2 days |
| Set up GitHub Actions CI (lint + test) | P1 | 1 day |
| Add Sentry or similar error tracking | P2 | 1 day |
| OpenAPI docs verification | P2 | 0.5 day |
| Fix any ProGuard issues for release build | P1 | 1 day |

**Exit criteria**: CI passes, 80%+ backend test coverage on AI routes, release APK builds clean

### Phase 3: Deployment & Launch (Weeks 6-7)

**Goal**: Public availability

| Task | Priority | Est. |
|------|----------|------|
| Deploy backend to Render.com | P0 | 0.5 day |
| Set up Supabase cloud project | P0 | 0.5 day |
| Configure production env vars | P0 | 0.5 day |
| Build signed release APK | P0 | 0.5 day |
| Upload APK to GitHub Releases | P0 | 0.5 day |
| Update landing page with download link | P1 | 0.5 day |
| Smoke test production deployment | P0 | 1 day |
| Write deployment runbook | P2 | 0.5 day |

**Exit criteria**: Users can download APK, register, and use all features against production

### Phase 4: Post-Launch (Weeks 8+)

**Goal**: Iterate based on feedback

| Task | Priority | Est. |
|------|----------|------|
| Monitor AI API costs | P0 | Ongoing |
| Collect user feedback | P0 | Ongoing |
| Expand Filipino food catalog | P1 | Ongoing |
| Add push notifications | P1 | 3 days |
| Web app version (Flutter web) | P2 | 1 week |
| Community moderation improvements | P2 | 2 days |

---

## Appendix: File Reference

| Path | Purpose |
|------|---------|
| `backend/app/main.py` | FastAPI app entry point |
| `backend/app/config.py` | Pydantic settings from `.env` |
| `backend/app/auth/jwt_verifier.py` | JWT verification (HS256 dev, ES256/RS256 prod) |
| `backend/app/services/scanner_service.py` | Food scanner with OpenAI and deterministic providers |
| `backend/app/services/chatbot_service.py` | Safety-aware chatbot with OpenAI and deterministic providers |
| `backend/app/services/safety_service.py` | Content safety guardrails |
| `backend/app/routes/chat.py` | `/ai/chat` endpoint |
| `backend/app/routes/scan_food.py` | `/ai/scan-food` endpoint |
| `flutter_app/lib/app/config.dart` | Compile-time env var access |
| `flutter_app/lib/app/router.dart` | GoRouter config (30+ routes) |
| `flutter_app/lib/core/database/database_provider.dart` | SQLite initialization |
| `flutter_app/lib/features/recommendations/recommendation_engine.dart` | Multi-factor scoring algorithm |
| `supabase/config.toml` | Full Supabase local dev config |
| `supabase/migrations/` | 24 SQL migration files |
| `render.yaml` | Render.com deployment blueprint |
| `launch_app.ps1` | Quick emulator launch script |
