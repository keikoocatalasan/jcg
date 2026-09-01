# JCG Fitness Release Action Inventory

This is the execution checklist for verifying every reachable, released dynamic action. Each item requires an authenticated success result, a visible error result where applicable, and a local/remote persistence assertion.

| Area | Actions | Required connection |
| --- | --- | --- |
| Authentication | Register, login, reset password, logout, OAuth callback | Supabase Auth; account status check; protected route redirect |
| Onboarding/profile | Save identity, goals, disclaimer, allergies, stats, budget, profile edits | SQLite transaction + sync queue + `app_user`/`user_profile`/target records |
| Food and meal log | Search, custom food, add/edit/delete meal log | SQLite repository + queue + `food_catalog`/food tables and `meal_log` |
| Tracking | Add/history hydration and weight; target recalculation | SQLite transaction + queue + `water_log`, `weight_log`, target/snapshot tables |
| Planner/recommendations | Add, skip, convert plan; generate and inspect recommendations | Local engine/repositories + queue + planner/recommendation tables |
| AI scanner | Camera, preview, upload, candidates, correction, confirmation, feedback | Camera permission + FastAPI + local scan repositories + feedback endpoint |
| AI chat | Send, safe/redirected/blocked reply, history | FastAPI + local chat repositories + sync queue |
| Community | Refresh, create/delete post, comment, like, report | RLS-protected community Supabase tables and visible error state |
| Administration | Catalog edits, price write/history, reports, hide/dismiss actions | Admin role + RLS/grants; audit log where supported |
| Synchronization | Retry, pending/failed inspection, reconnect, duplicate replay | Sync queue state transitions and idempotent Supabase writes |

## Release evidence

- Flutter unit/widget suite passes, including the password complexity policy.
- FastAPI route tests pass against Python 3.11 with a clean local environment.
- Fresh Supabase migration run and RLS role matrix are recorded.
- Emulator completes all inventory actions; physical Android proof covers camera capture/upload and offline-to-online sync.
- Render `/health` and `/readiness` return successful responses after deployment.
