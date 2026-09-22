# NutriSmart AI — Deployment Checklist

> Use this checklist to track every step before and during production deployment.

## Pre-Deployment

- [ ] Code freeze confirmed on `main` branch
- [ ] All pull requests merged and reviewed
- [ ] Version bumped to 1.0.0
- [ ] Changelog updated

## Supabase (Production)

- [ ] Create production Supabase project
- [ ] Retrieve `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- [ ] Run every migration in `supabase/migrations/` in filename order, including timestamped migrations
- [ ] Verify every table and relationship exists
- [ ] Enable Row-Level Security (RLS) on all tables
- [ ] Write and apply RLS policies for authenticated users
- [ ] Create admin account with elevated privileges
- [ ] Create service role API key for backend

## FastAPI Backend (Render)

- [ ] Create new Web Service on Render (Docker or Python environment)
- [ ] Point service to `backend/` directory
- [ ] Set build command: `pip install -r requirements.txt`
- [ ] Set start command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

### Environment Variables (Render)

- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_ANON_KEY`
- [ ] `SUPABASE_SERVICE_ROLE_KEY`
- [ ] `SUPABASE_JWT_SECRET` — required by production startup and used as the legacy HS256 verification fallback
- [ ] `AI_MODEL_PROVIDER` — `deterministic`, `openai`, or `nvidia`
- [ ] `AI_MODEL_API_KEY` — required when `AI_MODEL_PROVIDER` is `openai` or `nvidia`
- [ ] `AI_MODEL_NAME` — use `meta/llama-3.2-11b-vision-instruct` for NVIDIA text + image inference
- [ ] `NVIDIA_BASE_URL` — `https://integrate.api.nvidia.com/v1` when using NVIDIA NIM
- [ ] `CHAT_MODEL_PROVIDER` — `inherit`, `openai`, `nvidia`, or `groq`; keep `inherit` to use the scanner provider
- [ ] `CHAT_MODEL_API_KEY` — required when chat uses a separate provider; store the secret on the backend only
- [ ] `CHAT_MODEL_NAME` — choose a model identifier supported by the selected chat provider
- [ ] `OPENAI_BASE_URL`, `NVIDIA_BASE_URL`, and `GROQ_BASE_URL` — use HTTPS URLs for every configured provider
- [ ] `AI_WEB_SEARCH_ENABLED` — enable only after the configured model passes a web-search smoke test
- [ ] `AI_ALLOWED_DOMAINS` — comma-separated approved nutrition-source domains
- [ ] `ALLOWED_ORIGINS` — comma-separated list of allowed origins
- [ ] `MAX_IMAGE_UPLOAD_MB`
- [ ] `RATE_LIMIT_REQUESTS` and `RATE_LIMIT_WINDOW_SECONDS`
- [ ] `ENVIRONMENT` — set to `production`

### Security

- [ ] Enable HTTPS (Render enforces this by default)
- [ ] Configure CORS middleware to restrict origins
- [ ] Rate limiting enabled on `/ai/` endpoints
- [ ] Validate JWT on every authenticated route
- [ ] Verify `/ai/admin/estimate-nutrition` rejects non-admin users
- [ ] Keep AI nutrition output in review state until the audited admin RPC succeeds
- [ ] Request size limits configured (especially for image uploads)

## Flutter App

- [ ] Set `FASTAPI_BASE_URL`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY` in `flutter_app/.env`
- [ ] For production builds, set `FASTAPI_BASE_URL=https://nutrismart-ai-backend.onrender.com` and `APP_ENV=production`
- [ ] Build release APK: `flutter build apk --release --split-per-abi`
- [ ] Build release App Bundle: `flutter build appbundle --release`
- [ ] Sign APK with release keystore
- [ ] Verify APK installs and runs on physical device

## Smoke Test (on Physical Device)

- [ ] App launches without crash
- [ ] Registration and login succeed
- [ ] Onboarding completes (all 7 screens)
- [ ] Dashboard loads with real data
- [ ] Food search returns results
- [ ] Manual meal log saves correctly
- [ ] Hydration tracking works
- [ ] Weight logging updates targets
- [ ] Weight Trend shows BMI from the newest saved weight and profile height; ages below 20 do not show adult categories
- [ ] Weekly weight check-in appears when due and opens the existing weight form
- [ ] Meal add-ons such as cheese and tomato can be logged as separate items and included in meal totals
- [ ] AI food scan captures and processes image
- [ ] AI food recognition clearly requires an internet connection and does not run offline
- [ ] Chatbot responds to queries
- [ ] Chatbot answers the current question and, when context is available, uses only the signed-in user's targets, meal totals, preferences, and relevant food records
- [ ] Nutritionist credential submission uploads privately; only an administrator can approve reviewer access
- [ ] Approved nutritionists can submit serving/macro feedback without directly changing official food values
- [ ] If Groq is enabled, verify `/version` reports the intended chat provider/model and run a real chat request within the account's free limits
- [ ] Analytics displays charts
- [ ] Admin food management functions
- [ ] Community feed loads
- [ ] Offline mode works (airplane mode test)
- [ ] Sync reconnects when internet restored

## Post-Deployment

- [ ] Monitor Render logs for errors
- [ ] Verify Supabase dashboard shows active connections
- [ ] Run full UAT survey with 20–30 respondents
- [ ] Document any issues found during UAT
- [ ] Tag release in Git (`v1.0.0`)
