# Admin Sync Strategy

## Offline-First (Local SQLite + Sync Queue)

**Food CRUD** uses the offline-first pattern:
- `admin_food_form_screen.dart` writes to local SQLite via `FoodRepository`
- A `SyncQueueEntry` is enqueued with the full JSON payload
- The `SyncQueueService` worker routes official-food writes through
  `admin_upsert_food()` so nutrition/price history and `food_change_log` remain
  immutable; non-official custom-food sync keeps the normal upsert path
- This ensures food management works during connectivity gaps

**Why offline-first for food CRUD:**
- Food creation/editing may involve large batches (bulk imports, price updates)
- Admin workflows are often sequential — create food, set price, update serving — and should survive temporary network loss
- Local SQLite provides instant feedback without network round-trips

## Direct-to-Supabase (Atomic RPCs)

**Price History** and **Community Moderation** write directly to Supabase:

| Operation | RPC | Reason |
|---|---|---|
| Set food price | `admin_set_food_price()` | Multi-row atomic: deactivate old price + insert new one. Must be transactional. |
| Hide reported post | `admin_hide_reported_post()` | Cross-table atomic: update report status + hide post + write moderation audit. Must be transactional. |
| Dismiss/resolve report | Direct `UPDATE` + `admin_log_moderation_action()` | Report status update + audit log. |
| Dashboard KPIs | `admin_dashboard_kpis()` | Read-only aggregate queries — no local state needed. |
| Analytics snapshot | `admin_analytics_snapshot()` | Read-only time-series data across all tables. |

**Why direct-to-Supabase for these:**
- Administrators are assumed to be online (admin panel is a web-connected management tool)
- Price changes and moderation actions have immediate visibility implications for all users
- Atomicity requirements (deactivate + insert, hide + audit) can only be guaranteed server-side
- No value in queuing these — an admin expects instant feedback on price changes and report actions

## Audit Logging

All audit trails write directly to Supabase with retry:
- `food_change_log` — tracks food creates/updates (retry-once, non-blocking warning on failure)
- `moderation_audit_log` — tracks dismiss, hide, resolve actions via `admin_log_moderation_action()` RPC
- `admin_role_audit` — tracks role changes via `admin_set_user_role()` RPC
- `moderation_action` — structural record of hide operations (written atomically within `admin_hide_reported_post()`)

**Why direct for audit:**
- Audit logs must survive client-side data loss (e.g., app uninstall)
- Delayed audit writes defeat the purpose of an audit trail
- Retry-once pattern with user-visible warning ensures no silent data loss
