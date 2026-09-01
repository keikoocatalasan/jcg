# JCG Fitness (NutriSmart AI) UI/UX and Logic Audit

Audit window: 2026-07-30 to 2026-07-31 (Asia/Shanghai)

Target exercised: Flutter Android debug APK on Pixel API 36 emulator, backed by the configured live Supabase project and deployed FastAPI service.

## Executive result

The audit found and fixed high-impact problems in returning-user routing, remote-to-local hydration, local-day calculations, offline sync acknowledgements, planner conversion, admin gating, admin food categories, moderation wording, narrow-screen layout, and chatbot emergency classification. The final APK builds and the automated suites pass.

This is not a claim that every requested external integration is release-certified. The real-food AI camera pipeline, email delivery/reset-link completion, Flutter web behavior, physical-device behavior, and the repaired admin metrics RPCs remain external gates described below. The deployed chatbot also still returns HTTP 500 for ordinary AI-generated answers because the deployed AI service/configuration was not changed by this local patch.

## Test environment and evidence

- Android emulator: `emulator-5554`, API 36, 1080 x 2400 pixels (360 dp logical width).
- Flutter: repository-bundled SDK 3.44.2.
- Backend health/readiness/version: live endpoints responded successfully.
- Test identity: one QA-only normal account, temporarily promoted to admin through `app_user.role_id`.
- Cleanup: the QA auth identity, application user, moderation audit row, and cascaded test content were removed after testing. No QA-owned food reached the live catalog.
- Automated verification:
  - Flutter: 179 tests passed.
  - FastAPI: 10 tests passed.
  - Flutter analyzer: no errors or warnings; 83 informational style/deprecation notices.
  - Debug APK: built successfully with `.env` dart defines.
  - `git diff --check`: passed.
  - Supabase local lint: not run to completion because PostgreSQL was not listening on `127.0.0.1:54322`.

## Route and service inventory

The router exposes 50 route declarations covering auth/session, six onboarding steps, the five-tab shell, meal logging, food search/custom food, hydration, weight, recommendations, planner, scanner, analytics, community, profile/settings/sync, and seven admin destinations. Admin access is enforced at three layers:

1. `isAdminProvider` and the router's admin guard.
2. Conditional Admin Console entry on Profile.
3. Supabase RLS and admin RPC checks through `is_admin()`.

The FastAPI surface inspected includes health, version, auth support, food scan, scan feedback, recommendation explanation, and chat. Flutter sends the Supabase bearer token through the configured API client. The deployed service was tested directly for health and chat safety behavior.

## Interactive inventory and observed status

Legend: **Pass** = exercised live on Android; **Fixed/Pass** = failed initially and passed live after the fix; **Partial** = screen/logic inspected or partly exercised but an external or device gate remains; **Blocked** = the requested end-to-end result was not available.

| Feature | Elements and flows exercised | Initial | Final |
|---|---|---:|---:|
| Auth | Empty/invalid registration validation, login, session-loading, returning-user redirect, logout/profile entry visibility | Fail | Fixed/Pass |
| Auth external flows | Forgot-password screen and links; actual email delivery and reset-link completion | Partial | Blocked |
| Onboarding | Goal, allergy choice, stats, activity, budget, disclaimer, completion, persisted review values | Pass | Pass |
| Dashboard | Live calories/macros/budget, quick actions, recent logs, narrow layout, return after reinstall | Fail | Fixed/Pass |
| Meal logging | Food selection, quantity, save, live dashboard update, recent list, planner-created log, edit navigation | Fail | Fixed/Pass |
| Meal planner | Responsive week table, add plan, date selection, day summary, convert dialog, plan-to-log remote state | Fail | Fixed/Pass |
| Food database | Search, categories, popular foods, detail navigation, custom-food form validation/category source | Fail | Fixed/Pass |
| AI scanner | Camera entry and source-level pipeline/error handling | Partial | Partial |
| Chatbot | Send, persisted history, suggested prompts, retry, crash-diet redirect, diagnosis refusal, emergency prompt | Fail | Partial |
| Hydration | Live history, quick add, local-day time, offline add, reconnect, remote upload, final status badge | Fail | Fixed/Pass |
| Weight | Log and current-weight update, history ordering, excluded photo control removal | Fail | Fixed/Pass |
| Recommendations | List/detail navigation, real food data, explanation UI and dead-action audit | Fail | Fixed/Pass (UI); explanation service not load-tested |
| Analytics | User analytics with hydrated data; admin statistics failure state | Fail | Partial |
| Community | Text-only post, comment, like, report, admin report context and moderation action | Fail | Fixed/Pass |
| Profile/settings | Profile, edit route, settings, sync status, static rows, cache/storage controls audit | Fail | Fixed/Pass |
| Admin gating | Normal-user row visibility, direct admin RPC denial, admin entry/guard and tool access | Fail | Fixed/Pass |
| Admin food | Live list, active filters, empty-form validation, schema-valid categories, local queue behavior | Fail | Fixed/Pass for create contract; no QA food retained |
| Admin reports | Report list, detail, dismissal/keep/remove wording and moderation audit | Fail | Fixed/Pass |
| Admin dashboard/analytics | Tool access when KPI RPC fails, friendly statistics error | Fail | Partial; migration awaits deployment |
| Offline first | Disconnect banner, local water write, pending state, reconnect upload, no duplicate, synced badge | Fail | Fixed/Pass |
| Excluded features | Barcode, purchase, wearables, workout planning, private messaging, avatar/community uploads | Fail (stray controls) | Fixed/Pass boundary |

## Bugs and fixes

### Navigation, session, and hydration

1. **Returning users could be sent back to onboarding after reinstall.** The router trusted a transient/stale onboarding flag during auth restoration. Authenticated public routes now enter the session loader, which checks remote account state before routing.
2. **A returning user's dashboard could show zero targets and no history.** Initial pull only hydrated the profile. It now pulls active nutrition targets, daily snapshots, weight, water, meal logs, and meal plans with their lookup codes.
3. **Admin status could fail with HTTP 400.** The provider used an invalid embedded role relationship query. It now reads `role_id` directly and compares it with the documented admin role.

### Local dates, logging, and offline sync

4. **A 1:08 AM local meal was grouped under the prior UTC date and displayed as 5:08 PM.** SQLite date filters now use local time; presentation converts zoned timestamps with `toLocal()`.
5. **Recent Logs could show an empty page even when non-meal history existed.** Empty-state selection now checks meal entries specifically and the app bar provides a working Add Meal action.
6. **Meal/water changes did not consistently refresh dashboard and recent totals.** The relevant Riverpod providers are invalidated after mutations and successful syncs.
7. **Connectivity started as false until the first change event.** The connectivity stream now performs an initial `checkConnectivity()` before listening for changes.
8. **Offline writes uploaded but remained visually `PENDING`.** The queue previously marked only its own row as synced. It now acknowledges the corresponding local entity, then refreshes affected providers. A final live disconnect/add/reconnect cycle showed four water rows as `SYNCED`, with the new row present once in Supabase.
9. **Weight history could choose either of two same-minute entries.** Latest-weight ordering now uses `logged_at` and `created_at` deterministically.

### Planner

10. **The weekly planner overflowed narrow devices.** The planning grid and stat content now use constrained horizontal scrolling.
11. **Add Planned Meal defaulted to Monday instead of today.** The current week defaults to the current date; other weeks use the selected week's first day.
12. **Day Summary hardcoded “High Protein” and fixed percentages.** It now displays the profile's real goal and calculates calories/macros against the hydrated nutrition target.
13. **Convert to Log could update SQLite without uploading.** The transaction now queues complete meal/plan payloads and explicitly starts sync after conversion. Live verification showed the Rice plan in logged status with its `converted_meal_log_id` and one planner-source meal log.

### Admin and moderation

14. **A failed KPI RPC made every admin tool unreachable.** The dashboard now shows a non-blocking metrics error card while Food Management, Reports, and Statistics remain accessible.
15. **Live admin RPCs drifted from the schema.** The deployed `admin_dashboard_kpis` function is missing and `admin_analytics_metrics` references a nonexistent `is_deleted` column. Migration `000031_repair_admin_metrics_rpcs.sql` repairs both contracts, but it has not been applied to the live project.
16. **Admin food categories did not match Supabase.** Labels such as `Others`, `Meat`, and `Dairy` caused lookup failures. The shared list now matches all 12 live lookup rows exactly. Custom Food now asks for a food category instead of incorrectly saving a meal type.
17. **Synced food rows and audit records could be stale or sequenced incorrectly.** Food flags are normalized from SQLite integers to booleans, serving/nutrition/price records are written before the change log, list providers refresh, and sync is started after save.
18. **Moderation actions were mislabeled.** “Approve/Reject” semantics were replaced with Keep Post, Remove Post, Mark Reviewed, Reviewed, Post Removed, and Dismissed, matching the actual database transitions.
19. **Admin statistics exposed raw PostgREST exceptions.** It now presents a stable user-facing failure state while retaining retry.

### Chat safety and interaction

20. **Retry did not actually resend and suggested prompts were truncated behind a dead action.** Retry now resubmits the failed text; See More opens the remaining prompts.
21. **Emergency messages such as chest pain plus fainting could reach the AI provider and fail with HTTP 500.** Emergency topic classification now includes chest pain, breathing difficulty, fainting, anaphylaxis, and self-harm; the route returns an immediate emergency-services response without calling the model. Backend tests cover this behavior.
22. **Deployment caveat:** the local safety fix is not present on the deployed FastAPI service. The live service correctly redirected a crash-diet request and refused a diagnosis request, but ordinary questions and the chest-pain test returned HTTP 500 through the deployed AI path.

### UI scope and dead controls

23. **A global floating action button obscured content and conflicted with screen actions.** It was removed; explicit dashboard quick actions remain.
24. **Multiple chevrons/buttons implied actions that did nothing.** Dead controls were removed or wired on profile/settings, food search/detail, recommendations, hydration/weight history, community detail, custom food, and session loading.
25. **Community and weight screens exposed image-related controls outside the approved scope.** Community Add Photos and weight progress-photo controls were removed. No excluded feature was implemented.
26. **Narrow hydration controls crowded each other.** Quick-add controls now wrap cleanly on the 360 dp test width.

## Business-logic checks

- Nutrition formulas: unit tests cover BMR, TDEE multipliers, all goal calorie adjustments, macro splits, gram conversion, water target, and safe calorie clamping.
- Recommendation scoring: unit tests cover budget/affordability, protein fit, penalties, allergy filtering, dietary restrictions, meal-type score, sorting, result cap, and reason text.
- Role enforcement: as role 1, the QA user saw only its own profile/application rows and the admin metrics RPC returned an authorization error. After role 2 promotion, the Admin Console appeared. The invalid client join was fixed independently of RLS.
- Moderation: a real text-only post was reported, appeared in Admin Reports, opened with correct context, and was dismissed through moderation. The admin audit record was created and later removed during QA cleanup.
- Planner: the real remote plan transitioned from planned to logged and referenced the generated meal log.
- Offline: a new water record persisted locally without connectivity, uploaded once after reconnect, and changed from pending to synced in the UI.

## Unresolved gates and limitations

1. **AI camera pipeline:** no physical food/camera scene was available in the emulator, so prediction accuracy, “AI correct,” manual correction, feedback persistence, timeout, and duplicate behavior were not certified end to end.
2. **Deployed chatbot:** the live AI-backed answer path returns HTTP 500. The emergency guard fix and test are local until the backend is deployed; provider credentials/quota/configuration must also be repaired.
3. **Admin metrics migration:** `000031_repair_admin_metrics_rpcs.sql` must be reviewed and applied to the target Supabase project, then dashboard/statistics must be rerun live.
4. **Forgot password:** the `.example.test` QA identity cannot receive mail. Delivery, deep link, and password replacement remain unverified.
5. **AI rate limits:** live excessive scanner/chat traffic was not generated against the shared service. Registration did surface a live Supabase rate limit, but that is not evidence for the custom AI limiter.
6. **Flutter web:** the Android target was preferred and fully rendered; the attempted local web session did not reach a usable rendered state. Web-specific hover behavior remains unverified.
7. **Physical device/release:** camera permissions, hardware behavior, release signing, performance, accessibility tooling, and store packaging were not tested.
8. **Database lint:** local Supabase was not running, so the new migration could not be linted against `127.0.0.1:54322`.

## Regression conclusion

All automated Flutter and backend tests pass, the final debug APK builds, and the highest-risk corrected flows were rerun live: returning-user routing and hydration, local-day dashboard/recent logs, planner conversion, normal/admin gating, community moderation, schema-valid admin categories, and offline reconnect synchronization with truthful status badges.

The unresolved items above prevent an honest “everything is production-ready” claim. They are deployment, external-service, web, email, or physical-device gates—not hidden pass assertions.

## Follow-up polish (non-blocking)

- Replace deprecated Radio APIs before Flutter removes them.
- Add automated integration tests for queue-to-entity status acknowledgement and UTC-boundary grouping.
- Add a seeded local Supabase QA profile so role and moderation regression can run without manual promotion.
- Add semantic labels to icon-only floating actions; the admin Add Food button was visually present but unnamed in accessibility output.
- Add a backend deployment smoke test that asserts ordinary chat, unsafe restriction, medical refusal, and emergency responses together.
