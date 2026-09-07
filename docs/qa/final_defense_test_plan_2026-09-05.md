# JCG Final Defense Test and Release Plan

This plan covers the local defense build, the production release gates, and the remaining Groq activation step. It separates deterministic local QA from real-provider validation so a successful demo is not mistaken for proof of production AI availability.

## 1. Test environments

| Environment | Purpose | Required configuration |
|---|---|---|
| Local Android emulator | Repeatable UI, camera lifecycle, CRUD, admin, and offline-first walkthrough | `APP_ENV=development`, `JCG_DEV_BYPASS_AUTH=true`, backend on dedicated port `8001`, `JCG_LIVE_PREVIEW=false` |
| Local backend | API contract and safety tests without spending provider quota | `AI_MODEL_PROVIDER=deterministic` |
| Render staging/production | Real authentication, Supabase RLS, real scanner provider, and chatbot provider smoke tests | `APP_ENV=production`, real Supabase values, restricted CORS, server-side AI keys only |
| Physical Android device | Final camera/performance and release APK check | USB debugging, camera permission, production API URL, signed release build |

The local bypass is compile-time, visibly marked `LOCAL QA`, rejected for release/production builds, and must never be used in a defense or public APK built with production settings.

## 2. Automated gates

- [x] Flutter unit/widget tests pass (`flutter test --no-pub`).
- [x] Backend tests pass (`python -m pytest -q`).
- [x] Backend modules compile (`python -m compileall -q app tests`).
- [x] Flutter analyzer reports zero errors; informational lints remain for later cleanup.
- [x] `git diff --check` passes.
- [x] Debug APK builds and installs on `emulator-5554` with the local QA flags.
- [ ] Run the release build with production `.env` and a release signing configuration.
- [ ] Install the signed artifact on a physical Android device.
- [ ] Run authenticated Render smoke tests after confirming deployed environment variables.

### Recorded local evidence

- Backend: 38 tests passed; live `health`, `readiness`, and `version` endpoints returned successfully on port `8001`.
- Chat: authenticated local safe-question request returned a context-aware response; an extreme-fasting request was blocked before provider execution.
- Flutter: 205 tests passed (one expected Windows-only TFLite host-DLL skip); analyzer completed with zero fatal issues and 79 informational lints.
- Emulator: the local demo dashboard, Recent Logs, meal edit, water edit, community, admin, scanner, camera preview/live mode, capture preview, local scan result, and chatbot response flows were opened after the latest APK install. The cards fit the phone viewport, and steady-state logs contained no Flutter exceptions, defunct-element errors, or image-buffer drops. Android's emulator camera2 layer reports a short one-time contention when switching between live stream and still capture; preview inference remains bounded and the transition is surfaced by the capture progress state.

## 3. Module test matrix

### Authentication and session

1. Launch with local QA flags: the dashboard opens, the banner says `LOCAL QA`, and no login screen is exposed.
2. Build without the bypass: the normal session-loading, login, registration, logout, and expired-session paths remain reachable.
3. Confirm a production build with bypass flags fails configuration validation rather than silently disabling authentication.
4. Confirm admin access is role-gated in production; the local demo admin is namespaced and never synced.

### Dashboard, nutrition, and recommendations

1. Verify target calories and macros render without overflow on a narrow phone and a larger emulator.
2. Add a meal, water entry, and weight entry; confirm the dashboard totals update.
3. Change the latest weight; confirm the recalculated target is reflected consistently in dashboard and profile data.
4. Check allergy and dietary filters against at least one included and one excluded food.
5. Verify no empty image area produces a broken-image icon; text/icon fallback is shown instead.

### Meal logs

1. Log a meal containing an ulam and rice; verify each component retains its own quantity, calories, and nutrition values.
2. Open Recent Logs, filter to Meals, edit the date, meal type, quantity, and component list, then save.
3. Reopen the same date and confirm the edit changed the existing rows instead of creating duplicates.
4. Remove one component and add another catalog item; confirm only the intended rows are deleted/created.
5. Repeat while offline in local QA; verify local persistence and a queued sync operation in production-mode tests.

### Water and weight logs

1. Edit a water entry from Recent Logs and from the hydration history menu; verify amount/date validation and saved totals.
2. Verify singular/plural presentation (`1 glass`, `2 glasses`) and no clipped controls.
3. Edit a non-latest weight and confirm historical data changes without recalculating the current target unnecessarily.
4. Edit the latest weight and confirm profile/target/snapshot recalculation is atomic.
5. Attempt to edit another user’s row through repository/API tests; confirm ownership rejection.

### Camera and image recognition

1. Grant camera permission and open the scanner; preview must start without a crash.
2. Keep live analysis off: preview remains smooth and the status explicitly says analysis is off.
3. Capture a still image; preview, retry, manual search, and confirmation routes must all work.
4. Toggle live analysis on and off repeatedly; confirm stale requests cannot overwrite a newer frame and leaving the screen disposes the camera without `setState`/defunct-element errors.
5. Test bright, dim, close, far, angled, partially occluded, rice-plus-ulam, and non-food images.
6. Treat confidence as a gate, not a guarantee: high-confidence results can be confirmed, while ambiguous results require manual confirmation/search.
7. Record latency and dropped-frame observations on emulator and physical device; target no sustained preview jank during live inference.
8. Confirm upload-size, invalid-image, network timeout, and unavailable-provider errors are shown as actionable text.

### Chatbot

1. Send a normal nutrition question; verify the user message and assistant reply appear in the same session and the newest reply scrolls into view automatically.
2. Confirm history survives screen navigation and app restart after local persistence.
3. Send a budget question with profile context; the server must receive budget, calories, protein, allergies, and dietary restrictions.
4. Send a medical/emergency or eating-disorder request; the safety pre-filter must respond without calling the provider.
5. Simulate offline mode; the composer is disabled with a clear message and no infinite spinner.
6. Simulate timeout, network error, provider error, empty output, and rate limit; the user sees a failed state with retry rather than a silent hang.
7. In deterministic local QA, verify the local responder completes immediately and never leaves `Sending...`.
8. With Groq enabled, verify `/version` reports the configured chat provider/model, the key is absent from all responses/logs, and an authenticated `/ai/chat` request returns a safe answer.

### Community

1. Load the feed from cache, refresh it, like/unlike a post, open a detail view, and add a comment.
2. Create a post with text and with an image; verify image upload failure falls back to a text-only post or an actionable error.
3. Report a post and delete the user’s own post; confirm unauthorized actions are rejected.
4. Test long text, empty text, keyboard overlap, and narrow-screen wrapping.

### Admin console and analytics

1. Open dashboard KPIs, users, food management, reports, content rules, and audit log.
2. Verify non-admin users cannot enter admin routes or call admin APIs.
3. Check charts and range selectors at narrow and wide widths; titles and controls must not truncate.
4. Test moderation actions, blocked-word updates, food approval, and audit entries with real RLS in staging.
5. Confirm local demo values are clearly demo-only and never presented as production statistics.

### Sync, offline behavior, and persistence

1. Create/edit each log type while online; confirm local write happens before remote sync.
2. Repeat offline; inspect the sync queue, reconnect, and confirm idempotent replay without duplicates.
3. Force a conflict using an older client sequence; verify conflict resolution follows the repository policy.
4. Confirm local QA mode skips cloud sync and does not make network calls for seeded demo data.

## 4. Groq activation runbook

1. Complete trusted-device verification for the Groq account and create a key in the Groq console.
2. In Render, set `CHAT_MODEL_PROVIDER=groq`, `CHAT_MODEL_API_KEY` to the secret, `CHAT_MODEL_NAME=openai/gpt-oss-20b`, and `GROQ_BASE_URL=https://api.groq.com/openai/v1`.
3. Redeploy the backend only after the secret is saved; do not add the key to Flutter, Git, or screenshots.
4. Check `/health`, `/readiness`, and `/version`; `/version` must show provider/model metadata but no secret.
5. Run the authenticated chatbot smoke tests above, then inspect logs for timeouts, 429s, and accidental secret output.
6. If verification or quota is unavailable, leave `CHAT_MODEL_PROVIDER=inherit` and keep the current NVIDIA path; do not set Groq without a key.

Groq's official API is OpenAI-compatible at `/openai/v1/chat/completions`, and the model identifier must remain an active model from Groq's supported-model list. Free-tier limits are quotas, not an accuracy or uptime guarantee.

## 5. Release exit criteria

- [ ] All automated gates are green on the release commit.
- [ ] Physical-device camera and signed APK checks are complete.
- [ ] Render deployment is healthy and the actual deployed commit is identified.
- [ ] Supabase RLS, admin role, CORS, and rate-limit checks pass in staging.
- [ ] Chatbot provider is verified, or the release notes explicitly state that it remains on the inherited provider.
- [ ] No secrets, local QA flags, demo seed IDs, or ignored `.env` files are committed.
- [ ] Final defense screenshots and known limitations are documented.
