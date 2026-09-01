# JCG Fitness / NutriSmart AI — Detailed Build Checklist Plan

**Document Version:** 1.3 — Polished Build-Ready Revision  
**Purpose:** Build-ready checklist for implementing the JCG Fitness / NutriSmart AI mobile application without drifting from the approved thesis scope, ERD, API contract, and feature contract.  
**Target App:** Android mobile application  
**Frontend:** Flutter + Dart  
**Local Database:** SQLite  
**Cloud Backend:** Supabase Auth, Supabase PostgreSQL, Supabase Storage  
**AI Backend:** Python FastAPI  
**Version Control:** Git + GitHub  

---

## 0. Non-Negotiable Build Rules

These rules must be followed before writing any code. They are designed to prevent feature drift and AI hallucination.

### 0.1 Scope Lock Rules

- [ ] Do **not** add barcode scanning.
- [ ] Do **not** add grocery purchasing or grocery transactions.
- [ ] Do **not** add wearable integration.
- [ ] Do **not** add workout planning.
- [ ] Do **not** add private messaging.
- [ ] Do **not** make the chatbot available offline.
- [ ] Do **not** make the AI scanner available offline.
- [ ] Do **not** allow AI scanner results to auto-save meal logs.
- [ ] Do **not** allow old meal logs to update when food prices or nutrition records change.
- [ ] Do **not** allow normal users to edit official food records.
- [ ] Do **not** expose Supabase service role keys in Flutter.
- [ ] Do **not** use `meal_plan` as a fitness goal. Meal planning is an app feature, not a body-composition goal.
- [ ] Do **not** create community image upload, profile/avatar upload, or persistent AI scan image storage unless approved through a written change request.
- [ ] Do **not** create denormalized domain tables unless they are explicitly listed as approved snapshot/history tables in this checklist.
- [ ] Do **not** store raw API keys, Supabase service role keys, JWT secrets, or AI provider keys in Flutter.
- [ ] Do **not** change endpoint names, request fields, response fields, table names, or sync rules without a written change request.

### 0.2 Required Core Rule

The defensible core must work first:

```text
User profile
→ nutrition targets
→ food database
→ manual meal logging
→ dashboard
→ budget-aware recommendation
```

If this core works correctly, the project remains defensible even if AI accuracy is limited.

### 0.3 Offline/Online Rule

| Area | Required behavior |
|---|---|
| Core tracking | Works offline using SQLite |
| Food search | Works offline using SQLite seed data |
| Manual meal logging | Saves locally first |
| Dashboard | Reads local SQLite data |
| Hydration | Saves locally first |
| Weight tracking | Saves locally first |
| Meal planner | Saves locally first |
| Recommendations | Runs locally using rule-based engine |
| Analytics | Reads SQLite logs |
| AI scanner | Requires internet and FastAPI |
| AI chatbot | Requires internet and FastAPI |
| Community | Online-first; cached viewing only; write actions are blocked offline and are not added to the offline sync queue |
| Admin tools | Online only |
| Sync | Runs only when internet is available |

### 0.4 AI Builder Anti-Hallucination Contract

When using an AI coding assistant, every prompt must include these constraints:

```text
Build only what is specified in the approved JCG Fitness contracts.
Do not invent tables, columns, screens, endpoints, roles, or features.
Use the approved 3NF data dictionary, API contract, sync operation matrix, and page/use-case catalog as the only implementation source of truth.
If a required detail is missing, output TODO_NEEDS_APPROVAL instead of inventing it.
Use Flutter + Dart, SQLite, Supabase, Supabase Storage, and Python FastAPI only.
All offline-capable features must save to SQLite first.
All synced records must use client-generated UUIDs.
Meal logs and meal plans must store snapshot nutrition and cost values.
Daily analytics must use daily target/budget snapshots or effective target history, never today's active target for old dates.
AI scanner must never create meal logs without user confirmation.
Recommendations must run offline using a local rule-based engine.
Chatbot and AI scanner require internet.
Community create/comment/like/report actions require internet and must not be queued for offline upload.
Private messaging, barcode scanning, grocery transactions, wearables, and workout planning are excluded.
```

### 0.5 Change Request Template

Use this before changing approved scope.

```text
Requested change:
Reason:
Affected feature(s):
Affected screen(s):
Affected table(s):
Affected API endpoint(s):
Affected offline behavior:
Risk level:
Approval:
```

---

## 1. Recommended Build Order

Build in this exact order to reduce redesign.

| Order | Build block | Reason |
|---:|---|---|
| 1 | Repository setup and project standards | Prevents inconsistent structure |
| 2 | Supabase project, PostgreSQL schema, RLS, Storage | Establishes backend contract |
| 3 | SQLite schema, migrations, seed foods, local DAOs | Enables offline-first development |
| 4 | Flutter app shell, routing, theme, state management | Creates stable UI foundation |
| 5 | Authentication and session flow | Controls protected access |
| 6 | Onboarding and profile setup | Provides source data for targets |
| 7 | Nutrition target engine | Calculates BMR, TDEE, macros, hydration |
| 8 | Food database and custom food | Required for logging and recommendations |
| 9 | Manual meal logging | Main nutrition tracking feature |
| 10 | Dashboard / home feed | Verifies daily totals |
| 11 | Hydration tracking | Core offline tracker |
| 12 | Weight tracking | Core offline tracker and analytics input |
| 13 | Budget-aware recommendation engine | Main thesis contribution after tracking |
| 14 | Weekly meal planner | Planning layer using food/log logic |
| 15 | Offline sync queue | Connects local and remote data safely |
| 16 | Admin food management | Allows official food maintenance |
| 17 | FastAPI foundation | AI service infrastructure |
| 18 | AI food scanner | Online AI feature |
| 19 | AI chatbot | Online AI guidance feature |
| 20 | Analytics | Historical visualization |
| 21 | Community feed | Required online feature for the final implementation |
| 22 | Account settings and lifecycle | Logout, cache, profile edits |
| 23 | Security hardening | RLS, validation, key safety, privacy |
| 24 | Full testing and defense evidence | Final verification |
| 25 | Deployment and APK build | Production-ready delivery |

---

## 2. Sprint-Based Build Plan

### Sprint 0 — Contract Freezing and Setup

**Goal:** Make sure developers and AI assistants have no freedom to invent architecture.

- [ ] Place these files in the repository `/docs` folder:
  - [ ] Final Feature Contract Table
  - [ ] Final API Contract
  - [ ] Complete 3NF ERD
  - [ ] Thesis PDF or thesis summary
  - [ ] This build checklist
- [ ] Create `/docs/change_requests/` folder.
- [ ] Create `/docs/test_evidence/` folder.
- [ ] Create `/docs/defense_screenshots/` folder.
- [ ] Create `/docs/api_examples/` folder.
- [ ] Add `README.md` explaining:
  - [ ] Tech stack
  - [ ] Setup steps
  - [ ] Environment variables
  - [ ] Build order
  - [ ] Excluded features
  - [ ] Offline/online rules
- [ ] Add `CONTRIBUTING.md` explaining branch naming and commit rules.
- [ ] Create GitHub repository.
- [ ] Create branches:
  - [ ] `main`
  - [ ] `develop`
  - [ ] `feature/*`
  - [ ] `fix/*`
- [ ] Add `.gitignore` for Flutter, Python, environment files, build outputs.
- [ ] Add issue templates:
  - [ ] Feature task
  - [ ] Bug report
  - [ ] Change request
  - [ ] Test evidence
- [ ] Add project board columns:
  - [ ] Backlog
  - [ ] Ready
  - [ ] In Progress
  - [ ] Code Review
  - [ ] Testing
  - [ ] Done

**Done when:** Repository is ready, contracts are committed, and no feature can start without mapping to a contract item.

---

## 3. Environment Setup Checklist

### 3.1 Developer Machine

- [ ] Install Flutter SDK.
- [ ] Verify `flutter doctor` has no critical errors.
- [ ] Install Dart SDK if not bundled.
- [ ] Install Android Studio or Android SDK tools.
- [ ] Configure Android emulator or physical test device.
- [ ] Install VS Code.
- [ ] Install VS Code extensions:
  - [ ] Dart
  - [ ] Flutter
  - [ ] Python
  - [ ] SQLite viewer
  - [ ] REST Client or Thunder Client
- [ ] Install Git.
- [ ] Install Python 3.11 or compatible version.
- [ ] Install Postman for API testing.
- [ ] Install Supabase CLI if local development is needed.
- [ ] Install SQLite command-line tools.

### 3.2 Flutter Project

- [ ] Create Flutter project.
- [ ] Confirm target platform is Android.
- [ ] Add packages only when needed:
  - [ ] `supabase_flutter`
  - [ ] SQLite package, such as `sqflite`
  - [ ] Path/provider package for database location
  - [ ] State management package: Riverpod or Bloc
  - [ ] HTTP client package
  - [ ] Image picker/camera package
  - [ ] Connectivity checker
  - [ ] UUID generator
  - [ ] Charting package
  - [ ] Secure storage package if needed
- [ ] Create app folder structure:

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
    constants.dart
  core/
    database/
    network/
    errors/
    utils/
    validators/
    sync/
  features/
    auth/
    onboarding/
    nutrition/
    food_database/
    meal_logging/
    dashboard/
    hydration/
    weight_tracking/
    recommendations/
    meal_planner/
    ai_scanner/
    chatbot/
    analytics/
    community/
    admin/
    profile_settings/
```

### 3.3 Supabase Project

- [ ] Create Supabase development project.
- [ ] Create Supabase production project later.
- [ ] Save these values in `.env` or Flutter environment config:
  - [ ] `SUPABASE_URL`
  - [ ] `SUPABASE_ANON_KEY`
  - [ ] `FASTAPI_BASE_URL`
  - [ ] `APP_ENV`
- [ ] Do **not** put service role key in Flutter.
- [ ] Enable email/password authentication.
- [ ] Configure Google OAuth only if it is part of the final implementation.
- [ ] Configure redirect URLs if OAuth is used.
- [ ] Configure email templates if needed.

### 3.4 FastAPI Project

- [ ] Create `/backend` folder.
- [ ] Create Python virtual environment.
- [ ] Add dependencies:
  - [ ] `fastapi`
  - [ ] `uvicorn`
  - [ ] `python-multipart`
  - [ ] JWT verification library
  - [ ] Supabase client or HTTP tools, if needed
  - [ ] Image processing library
  - [ ] AI provider client, if used
  - [ ] Testing tools: `pytest`, `httpx`
- [ ] Create FastAPI structure:

```text
backend/
  app/
    main.py
    config.py
    auth/
      jwt_verifier.py
    routes/
      health.py
      version.py
      scan_food.py
      scan_feedback.py
      chat.py
      explain_recommendation.py
    services/
      scanner_service.py
      chatbot_service.py
      safety_service.py
      image_validation_service.py
    schemas/
      common.py
      scanner.py
      chatbot.py
    tests/
```

### 3.5 Environment Variables

Mobile environment variables:

- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_ANON_KEY`
- [ ] `FASTAPI_BASE_URL`
- [ ] `APP_ENV`

Server environment variables:

- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_ANON_KEY`
- [ ] `SUPABASE_JWT_SECRET`
- [ ] `SUPABASE_SERVICE_ROLE_KEY`
- [ ] `AI_MODEL_PROVIDER`
- [ ] `AI_MODEL_API_KEY`
- [ ] `MAX_IMAGE_UPLOAD_MB`
- [ ] `ALLOWED_ORIGINS`

---

## 4. Database Build Checklist

## 4.1 PostgreSQL / Supabase Schema

### 4.1.1 General Requirements

- [ ] Use UUID primary keys for user-created records.
- [ ] Add `created_at` and `updated_at` where required.
- [ ] Add `is_deleted` for logs where soft delete is needed.
- [ ] Add indexes for date-based user queries.
- [ ] Add indexes for food search.
- [ ] Add foreign keys.
- [ ] Add unique constraints where required.
- [ ] Add check constraints for positive numeric fields where practical.
- [ ] Add lookup/reference tables before dependent tables.
- [ ] Enable RLS on every user-owned table.
- [ ] Add user-owned RLS policies.
- [ ] Add admin-only RLS policies.
- [ ] Add Storage policies.
- [ ] Prepare migration scripts.
- [ ] Test migration rollback or reset procedure.


### 4.1.1.1 Third Normal Form and Data Design Rules

These rules are mandatory for the Supabase/PostgreSQL domain schema.

- [ ] Keep every domain table in **Third Normal Form (3NF)** unless a table is explicitly marked as a snapshot, history, cache, or operational queue table.
- [ ] Each table must represent one entity or relationship only.
- [ ] Every non-key column must depend on the table key, the whole key, and nothing except the key.
- [ ] Do not store repeating groups in one column, such as comma-separated allergies, comma-separated food categories, or multiple meal types in one field.
- [ ] Use lookup tables for controlled values: role, account status, sex, activity level, fitness goal, meal type, log source, scan status, chat role, safety status, report reason, report status, moderation action type, sync entity type, sync operation type, and sync status.
- [ ] Use bridge tables for many-to-many relationships, such as `USER_ALLERGY` and `USER_DIETARY_RESTRICTION`.
- [ ] Do not duplicate user profile fields inside logs. Logs must reference `user_id` and store only log-specific snapshot facts needed for historical correctness.
- [ ] Snapshot columns are allowed only where historical correctness requires preserving values that may change later, such as food name, serving, nutrition, cost, target, and daily budget at the time of use.
- [ ] JSON columns are allowed only for operational metadata, API raw response evidence, sync payloads, or admin/audit details. JSON must not replace normalized domain tables.
- [ ] Soft delete is used for meal logs and custom foods where old records must remain auditable. Water logs, weight logs, and planned-status meal plans use hard delete plus sync tombstone as defined in this checklist.
- [ ] `created_at`, `updated_at`, and user ownership columns must not be used as substitutes for proper foreign keys.

### 4.1.1.2 Approved Remote 3NF Data Dictionary Summary

Use this as the implementation boundary. Detailed migrations may add indexes and constraints, but must not change entities or relationships without change approval.

| Table | Primary key | Required foreign keys | Required core columns | 3NF / implementation rule |
|---|---|---|---|---|
| `ROLE` | `role_id` | — | `role_code`, `role_name` | Lookup only: `user`, `admin`. |
| `ACCOUNT_STATUS` | `account_status_id` | — | `status_code`, `status_name` | Lookup only: `active`, `disabled`. |
| `SEX` | `sex_id` | — | `sex_code`, `sex_name` | Lookup only: `male`, `female`. |
| `ACTIVITY_LEVEL` | `activity_level_id` | — | `activity_code`, `activity_name`, `multiplier` | Stores TDEE multipliers only. |
| `FITNESS_GOAL` | `fitness_goal_id` | — | `goal_code`, `goal_name`, `description` | Body/composition goals only. Do not include `meal_plan`. |
| `MEAL_TYPE` | `meal_type_id` | — | `meal_type_code`, `meal_type_name` | Breakfast, lunch, dinner, snack. |
| `LOG_SOURCE` | `log_source_id` | — | `source_code`, `source_name` | Manual, AI scanner, recommendation, planner. |
| `APP_USER` | `user_id` | `role_id`, `account_status_id` | `auth_user_id`, `created_at`, `updated_at` | One app user per Supabase Auth user. `auth_user_id` must be unique. |
| `USER_PROFILE` | `profile_id` | `user_id`, `sex_id`, `activity_level_id`, `fitness_goal_id` | `nickname`, `age`, `height_cm`, `current_weight_kg`, `target_weight_kg`, `daily_budget_php`, `onboarding_completed` | `current_weight_kg` is onboarding/start weight or cached latest only; latest `WEIGHT_LOG` is source of truth after onboarding. |
| `MEDICAL_DISCLAIMER_ACCEPTANCE` | `acceptance_id` | `user_id` | `accepted_at`, `disclaimer_version` | One acceptance event per version. |
| `ALLERGY` | `allergy_id` | — | `allergy_name`, `is_active` | Lookup of selectable allergies. |
| `USER_ALLERGY` | `user_allergy_id` | `user_id`, `allergy_id` | `created_at` | Bridge table. Unique `user_id + allergy_id`. |
| `DIETARY_RESTRICTION` | `restriction_id` | — | `restriction_name`, `is_active` | Lookup of selectable restrictions. |
| `USER_DIETARY_RESTRICTION` | `user_restriction_id` | `user_id`, `restriction_id` | `created_at` | Bridge table. Unique `user_id + restriction_id`. |
| `NUTRITION_FORMULA_VERSION` | `formula_version_id` | — | `version_code`, `description`, `is_active` | Tracks formula version, e.g., `mifflin_v1`. |
| `GOAL_CALORIE_POLICY` | `policy_id` | `fitness_goal_id` | `calorie_adjustment`, `is_active` | One active calorie policy per goal. |
| `GOAL_MACRO_POLICY` | `policy_id` | `fitness_goal_id` | `protein_pct`, `carbs_pct`, `fat_pct`, `is_active` | One active macro policy per goal. Percentages must total 100. |
| `NUTRITION_TARGET` | `target_id` | `user_id`, `formula_version_id`, `fitness_goal_id`, `source_weight_log_id` optional | `bmr`, `tdee`, `calorie_target`, `protein_target_g`, `carbs_target_g`, `fat_target_g`, `water_target_ml`, `effective_from`, `effective_to`, `is_active` | Current target is active; old targets are retained for history. |
| `DAILY_TARGET_SNAPSHOT` | `snapshot_id` | `user_id`, `nutrition_target_id` | `target_date`, `calorie_target_snapshot`, `protein_target_g_snapshot`, `carbs_target_g_snapshot`, `fat_target_g_snapshot`, `water_target_ml_snapshot`, `daily_budget_php_snapshot` | Used by analytics so old dates are not recalculated using today's target/budget. Unique `user_id + target_date`. |
| `FOOD_CATEGORY` | `category_id` | — | `category_name`, `is_active` | Lookup. |
| `DATA_SOURCE` | `source_id` | — | `source_name`, `source_type`, `source_reference` | Nutrition/price source metadata. |
| `FOOD_ITEM` | `food_id` | `category_id`, `owner_user_id` optional | `food_name`, `normalized_name`, `is_local_food`, `is_official`, `is_active`, `created_at`, `updated_at` | Food identity only. User-owned custom food uses `owner_user_id`; official food has no normal user owner. |
| `FOOD_SERVING` | `serving_id` | `food_id` | `serving_label`, `serving_grams`, `is_default`, `is_active` | MVP has one active default serving per food for normal logging. |
| `FOOD_NUTRITION_PROFILE` | `nutrition_profile_id` | `food_id`, `serving_id`, `source_id` | `calories`, `protein_g`, `carbs_g`, `fat_g`, `is_active`, `effective_from`, `effective_to` | MVP reads one active nutrition profile per default serving. |
| `FOOD_PRICE` | `price_id` | `food_id`, `serving_id`, `source_id` | `estimated_price_php`, `is_active`, `effective_from`, `effective_to` | MVP reads one active price per default serving. Price changes never update old log snapshots. |
| `FOOD_CHANGE_LOG` | `change_log_id` | `food_id`, `changed_by_user_id` | `change_type`, `old_value_json`, `new_value_json`, `changed_at` | Audit/history table; JSON allowed for audit details only. |
| `MEAL_LOG` | `meal_log_id` | `user_id`, `food_id` optional, `meal_type_id`, `log_source_id` | `food_name_snapshot`, `serving_grams_snapshot`, `quantity`, `calories_snapshot`, `protein_g_snapshot`, `carbs_g_snapshot`, `fat_g_snapshot`, `cost_php_snapshot`, `logged_at`, `is_deleted` | Historical snapshot table; old logs never recalculate from updated food records. |
| `WATER_LOG` | `water_log_id` | `user_id` | `amount_ml`, `logged_at`, `created_at`, `updated_at` | Hard delete plus sync tombstone. |
| `WEIGHT_LOG` | `weight_log_id` | `user_id` | `weight_kg`, `logged_at`, `created_at`, `updated_at` | Latest log is current weight source. Hard delete plus sync tombstone. |
| `MEAL_PLAN_STATUS` | `status_id` | — | `status_code`, `status_name` | Planned, logged, skipped. |
| `MEAL_PLAN` | `meal_plan_id` | `user_id`, `food_id` optional, `meal_type_id`, `status_id`, `converted_meal_log_id` optional | snapshot fields, `planned_date`, `quantity`, `created_at`, `updated_at` | Snapshot table; planned-status rows may be deleted, logged/skipped rows preserved. |
| `RECOMMENDATION_SESSION` | `session_id` | `user_id` | `remaining_budget_php`, `remaining_calories`, `remaining_protein_g`, `remaining_carbs_g`, `remaining_fat_g`, `generated_at` | Stores session context for thesis evidence. |
| `RECOMMENDATION_ITEM` | `recommendation_item_id` | `session_id`, `food_id`, `linked_meal_log_id` optional, `linked_meal_plan_id` optional | `rank_number`, `final_score`, score component fields, `reason_text`, `was_accepted`, `accepted_at` | Acceptance is updated only after linked log/plan save succeeds. |
| `AI_SCAN_STATUS` | `scan_status_id` | — | `status_code`, `status_name` | Pending, completed, failed, low_confidence. |
| `AI_SCAN` | `scan_id` | `user_id`, `scan_status_id` | `client_scan_id`, `image_path` optional, `created_at`, `completed_at`, `raw_response_json` optional | `client_scan_id` must be unique per user. Raw image path is optional approval-based. |
| `AI_SCAN_PREDICTION` | `prediction_id` | `scan_id`, `food_id` optional | `predicted_food_name`, `confidence`, `rank_number`, estimated nutrition/cost fields | Stores candidates without creating meal logs. |
| `AI_SCAN_CONFIRMATION` | `confirmation_id` | `scan_id`, `selected_prediction_id` optional, `meal_log_id` optional | `confirmed_food_id`, `quantity`, `meal_type_id`, `confirmed_at`, `correction_reason` optional | One confirmation per scan after user action. |
| `CHAT_SESSION` | `chat_session_id` | `user_id` | `started_at`, `ended_at` optional | Groups chat messages. |
| `CHAT_ROLE` | `chat_role_id` | — | `role_code`, `role_name` | User, assistant, system. |
| `CHAT_SAFETY_STATUS` | `safety_status_id` | — | `status_code`, `status_name` | Safe, redirected, blocked. |
| `CHAT_DELIVERY_STATUS` | `delivery_status_id` | — | `status_code`, `status_name` | `local_saved`, `sent_to_api`, `assistant_received`, `failed`, `blocked`, `redirected`. |
| `CHAT_MESSAGE` | `chat_message_id` | `chat_session_id`, `chat_role_id`, `safety_status_id`, `delivery_status_id` | `message_text`, `created_at`, `sent_at` optional | User messages saved before sending; failed messages remain retryable. |
| `CHAT_MESSAGE_CONTEXT` | `context_id` | `chat_message_id` | `context_type`, `context_value_json` | JSON allowed for context snapshot only. |
| `COMMUNITY_POST` | `post_id` | `user_id` | `body_text`, `is_hidden`, `is_deleted`, `created_at`, `updated_at` | Authenticated users only. Text-only by default. |
| `COMMUNITY_COMMENT` | `comment_id` | `post_id`, `user_id` | `comment_text`, `is_hidden`, `is_deleted`, `created_at`, `updated_at` | Normal users cannot report comments unless approved. |
| `COMMUNITY_LIKE` | `like_id` | `post_id`, `user_id` | `created_at` | Unique `post_id + user_id`. |
| `REPORT_REASON` | `reason_id` | — | `reason_code`, `reason_name` | Lookup. |
| `REPORT_STATUS` | `status_id` | — | `status_code`, `status_name` | Pending, reviewed, dismissed, action_taken. |
| `COMMUNITY_REPORT` | `report_id` | `reporter_user_id`, `post_id`, `reason_id`, `status_id` | `details`, `created_at`, `reviewed_at` optional | Reports target posts only. |
| `MODERATION_ACTION_TYPE` | `action_type_id` | — | `action_code`, `action_name` | Hide post, unhide post, hide comment, warn user. |
| `MODERATION_ACTION` | `moderation_action_id` | `admin_user_id`, `action_type_id`, `post_id` optional, `comment_id` optional, `report_id` optional | `reason`, `created_at` | Admin-only actions. |
| `DEVICE` | `device_id` | `user_id` | `device_name`, `platform`, `last_seen_at` | Optional but recommended for sync evidence. |
| `SYNC_ENTITY_TYPE` | `sync_entity_type_id` | — | `entity_code`, `entity_name` | Lookup. |
| `SYNC_OPERATION_TYPE` | `sync_operation_type_id` | — | `operation_code`, `operation_name` | Create, update, delete. |
| `SYNC_STATUS` | `sync_status_id` | — | `status_code`, `status_name` | Pending, processing, synced, failed. |
| `SYNC_QUEUE` | `sync_queue_id` | `user_id`, `device_id` optional, lookup FKs | `operation_id`, `entity_id`, `payload_json`, `changed_fields_json`, `client_sequence`, `attempt_count`, `last_error`, `server_synced_at` | Operational queue; JSON allowed because it is not a normalized domain table. |

### 4.1.1.3 MVP Food Record Rule

The schema remains normalized, but the first implementation must expose a simple food model to users.

- [ ] Each food item must have exactly one active default serving for normal user search/logging.
- [ ] Each active default serving must have exactly one active nutrition profile.
- [ ] Each active default serving must have exactly one active estimated price.
- [ ] Admin changes create new effective nutrition/price rows and close old rows with `effective_to` where practical.
- [ ] Normal users search only active foods, active default servings, active nutrition profiles, and active prices.
- [ ] Multiple serving choices are excluded from MVP unless approved through a written change request.

### 4.1.2 Lookup Tables

- [ ] Create `ROLE`.
- [ ] Seed roles:
  - [ ] `user`
  - [ ] `admin`
- [ ] Create `ACCOUNT_STATUS`.
- [ ] Seed account statuses:
  - [ ] `active`
  - [ ] `disabled`
- [ ] Use `ACCOUNT_STATUS` in `APP_USER` to block disabled accounts from entering onboarding/dashboard after authentication.
- [ ] Create `SEX`.
- [ ] Seed:
  - [ ] `male`
  - [ ] `female`
- [ ] Create `ACTIVITY_LEVEL`.
- [ ] Seed:
  - [ ] `sedentary = 1.20`
  - [ ] `light = 1.375`
  - [ ] `moderate = 1.55`
  - [ ] `active = 1.725`
  - [ ] `very_active = 1.90`
- [ ] Create `FITNESS_GOAL`.
- [ ] Seed:
  - [ ] `cutting`
  - [ ] `maintenance`
  - [ ] `bulking`
  - [ ] `lean`
  - [ ] `gain_weight`
- [ ] Create `MEAL_TYPE`.
- [ ] Seed:
  - [ ] `breakfast`
  - [ ] `lunch`
  - [ ] `dinner`
  - [ ] `snack`
- [ ] Create `LOG_SOURCE`.
- [ ] Seed:
  - [ ] `manual`
  - [ ] `ai_scanner`
  - [ ] `recommendation`
  - [ ] `planner`
- [ ] Create AI/chat/community/sync lookup tables.

### 4.1.3 User and Profile Tables

- [ ] Represent Supabase Auth as external `AUTH_USERS` reference.
- [ ] Create `APP_USER`.
- [ ] Link `APP_USER.auth_user_id` to Supabase auth user ID.
- [ ] Enforce one `APP_USER` per Supabase Auth account using a unique `auth_user_id`.
- [ ] Create `APP_USER` immediately after successful Supabase Auth registration using a controlled post-register step or database trigger.
- [ ] Add `APP_USER.account_status` with default `active`.
- [ ] Create `USER_PROFILE`.
- [ ] Store profile fields:
  - [ ] nickname
  - [ ] sex
  - [ ] age
  - [ ] height_cm
  - [ ] current_weight_kg
  - [ ] target_weight_kg
  - [ ] activity_level
  - [ ] fitness_goal
  - [ ] daily_budget_php
  - [ ] onboarding_completed
- [ ] Create `MEDICAL_DISCLAIMER_ACCEPTANCE`.

### 4.1.3.1 Current Weight Source-of-Truth Rule

- [ ] During onboarding, `USER_PROFILE.current_weight_kg` stores the user's starting/current weight.
- [ ] On onboarding completion, create an initial `WEIGHT_LOG` from `USER_PROFILE.current_weight_kg` using the onboarding completion date/time.
- [ ] After onboarding, the latest `WEIGHT_LOG` is the source of truth for the user's current weight.
- [ ] `USER_PROFILE.current_weight_kg` may be used only as the onboarding/start weight or as a cached latest-weight value.
- [ ] Editing current weight from Profile must create a new `WEIGHT_LOG` entry and trigger nutrition target recalculation.
- [ ] Dashboard, analytics, and target recalculation must read the latest weight from `WEIGHT_LOG` when available.

- [ ] Create `ALLERGY`.
- [ ] Create `USER_ALLERGY`.
- [ ] Create `DIETARY_RESTRICTION`.
- [ ] Create `USER_DIETARY_RESTRICTION`.

### 4.1.4 Nutrition Target Tables

- [ ] Create `NUTRITION_FORMULA_VERSION`.
- [ ] Seed active formula version:
  - [ ] `mifflin_v1`
- [ ] Create `GOAL_CALORIE_POLICY`.
- [ ] Seed calorie adjustments:
  - [ ] cutting: `-400`
  - [ ] maintenance: `0`
  - [ ] bulking: `+400`
  - [ ] lean: `+200`
  - [ ] gain_weight: `+500`
- [ ] Create `GOAL_MACRO_POLICY`.
- [ ] Seed macro percentages per goal.
- [ ] Create `NUTRITION_TARGET`.
- [ ] Include `effective_from`, `effective_to`, and `is_active`.
- [ ] Enforce only one active target per user in app logic or database logic.
- [ ] Create `DAILY_TARGET_SNAPSHOT`.
- [ ] Store daily target and budget snapshots for analytics: calories, protein, carbs, fat, water target, and daily budget.
- [ ] Enforce unique `user_id + target_date` for `DAILY_TARGET_SNAPSHOT`.
- [ ] Analytics must use `DAILY_TARGET_SNAPSHOT` or target effective history, not the user's current target for old dates.

### 4.1.5 Food Database Tables

- [ ] Create `FOOD_CATEGORY`.
- [ ] Seed categories.
- [ ] Create `DATA_SOURCE`.
- [ ] Create `FOOD_ITEM`.
- [ ] Create `FOOD_SERVING`.
- [ ] Create `FOOD_NUTRITION_PROFILE`.
- [ ] Create `FOOD_PRICE`.
- [ ] Create `FOOD_CHANGE_LOG`.
- [ ] Add index on `normalized_name`.
- [ ] Add category index.
- [ ] Add owner user index for custom foods.
- [ ] Seed at least 50 common foods.
- [ ] Mark official foods as system/admin-owned.
- [ ] Allow user-created foods as custom records.
- [ ] Ensure official foods are editable only by admin.
- [ ] MVP normal logging must read only one active default serving, one active nutrition profile, and one active estimated price per food.
- [ ] Food updates must create change/history records; old meal log snapshots must not update.

### 4.1.6 Tracking Tables

- [ ] Create `MEAL_LOG`.
- [ ] Include snapshot fields:
  - [ ] `food_name_snapshot`
  - [ ] `serving_grams_snapshot`
  - [ ] `calories_snapshot`
  - [ ] `protein_g_snapshot`
  - [ ] `carbs_g_snapshot`
  - [ ] `fat_g_snapshot`
  - [ ] `cost_php_snapshot`
- [ ] Add `logged_at`.
- [ ] Add `is_deleted`.
- [ ] Create `WATER_LOG`.
- [ ] Create `WEIGHT_LOG`.
- [ ] Add user/date indexes:
  - [ ] meal logs by user and date
  - [ ] water logs by user and date
  - [ ] weight logs by user and date

### 4.1.7 Planner Tables

- [ ] Create `MEAL_PLAN_STATUS`.
- [ ] Seed statuses:
  - [ ] `planned`
  - [ ] `logged`
  - [ ] `skipped`
- [ ] Create `MEAL_PLAN`.
- [ ] Include snapshot fields same as meal logs.
- [ ] Include `planned_date`.
- [ ] Include `converted_meal_log_id`.
- [ ] Add user/date index.

### 4.1.8 Recommendation Tables

- [ ] Create `RECOMMENDATION_SESSION`.
- [ ] Store remaining budget/macros at generation time.
- [ ] Create `RECOMMENDATION_ITEM`.
- [ ] Store food, rank, score, reason text, acceptance status.
- [ ] Link accepted recommendation to meal log or meal plan if user accepts.

### 4.1.9 AI Scanner Tables

- [ ] Create `AI_SCAN_STATUS`.
- [ ] Seed statuses:
  - [ ] `pending`
  - [ ] `completed`
  - [ ] `failed`
  - [ ] `low_confidence`
- [ ] Create `AI_SCAN`.
- [ ] Create `AI_SCAN_PREDICTION`.
- [ ] Create `AI_SCAN_CONFIRMATION`.
- [ ] Ensure one confirmation per scan.
- [ ] Ensure scan confirmation may link to a meal log only after user action.

### 4.1.10 Chatbot Tables

- [ ] Create `CHAT_SESSION`.
- [ ] Create `CHAT_ROLE`.
- [ ] Seed roles:
  - [ ] `user`
  - [ ] `assistant`
  - [ ] `system`
- [ ] Create `CHAT_SAFETY_STATUS`.
- [ ] Seed safety statuses:
  - [ ] `safe`
  - [ ] `redirected`
  - [ ] `blocked`
- [ ] Create `CHAT_MESSAGE`.
- [ ] Create `CHAT_MESSAGE_CONTEXT`.

### 4.1.11 Community and Moderation Tables

- [ ] Create `COMMUNITY_POST`.
- [ ] Create `COMMUNITY_COMMENT`.
- [ ] Create `COMMUNITY_LIKE`.
- [ ] Enforce one like per user per post.
- [ ] Create `REPORT_REASON`.
- [ ] Create `REPORT_STATUS`.
- [ ] Create `COMMUNITY_REPORT`.
- [ ] Enforce report target rule:
  - [ ] normal user reports target posts only
  - [ ] comment reporting is not included unless approved through a written change request
- [ ] Create `MODERATION_ACTION_TYPE`.
- [ ] Create `MODERATION_ACTION`.
- [ ] Ensure admin-only moderation.

### 4.1.12 Sync Support Tables

- [ ] Create `DEVICE`.
- [ ] Create `SYNC_ENTITY_TYPE`.
- [ ] Create `SYNC_OPERATION_TYPE`.
- [ ] Create `SYNC_STATUS`.
- [ ] Create `SYNC_QUEUE` or remote sync audit table if needed.

---

## 5. SQLite Local Database Checklist

### 5.1 Local Schema Requirements

SQLite is the operational database for offline-first features.

- [ ] Create local schema matching offline-required tables.
- [ ] Use UUID strings generated by Flutter.
- [ ] Add local migration version table.
- [ ] Add `created_at` and `updated_at` fields.
- [ ] Add `is_deleted` where needed.
- [ ] Add `sync_status` or use separate `sync_queue`.
- [ ] Add indexes for dashboard and food search speed.
- [ ] Seed lookup values locally.
- [ ] Seed at least 50 foods locally.
- [ ] Store local food database for offline search.

### 5.2 Required Local Tables

- [ ] `app_settings`
- [ ] `profiles`
- [ ] `nutrition_targets`
- [ ] `foods`
- [ ] `custom_foods` or equivalent custom food structure
- [ ] `meal_logs`
- [ ] `water_logs`
- [ ] `weight_logs`
- [ ] `meal_plans`
- [ ] `recommendation_sessions`
- [ ] `recommendation_items`
- [ ] `ai_scans`
- [ ] `ai_scan_predictions`
- [ ] `ai_scan_feedback`
- [ ] `chat_sessions`
- [ ] `chat_messages`
- [ ] `chat_message_context`
- [ ] `daily_target_snapshots`
- [ ] `community_cache` for read-only cached community feed viewing; it must not store unsynced community write actions
- [ ] `sync_queue`

If a simplified local implementation combines `recommendation_sessions/items` or `ai_scans/predictions/feedback`, it must still preserve the same fields and relationships. Do not collapse normalized remote tables into one remote table.

### 5.3 SQLite DAO / Repository Checklist

For every local table:

- [ ] Implement create/insert.
- [ ] Implement read by ID.
- [ ] Implement update.
- [ ] Implement soft delete if applicable.
- [ ] Implement date-range query if applicable.
- [ ] Implement user-scoped query.
- [ ] Implement pending sync query if applicable.
- [ ] Write unit tests for DAO operations.

### 5.4 Local Transaction Rules

- [ ] Completing onboarding must create profile, initial weight log, nutrition target, and sync-queue rows in the same local transaction.
- [ ] Creating a meal log must also queue sync in the same local transaction.
- [ ] Updating a meal log must also queue sync in the same local transaction.
- [ ] Deleting a meal log must soft-delete and queue sync in the same local transaction.
- [ ] Converting a meal plan to a log must create meal log and update plan status in one transaction.
- [ ] Saving AI scan feedback locally must not create a meal log unless user confirms.
- [ ] Recommendation acceptance must create a log or plan only after user action.
- [ ] Deleting a water log must hard-delete locally and create a sync-queue delete tombstone in the same local transaction.
- [ ] Deleting a weight log must hard-delete locally and create a sync-queue delete tombstone in the same local transaction.
- [ ] Deleting a planned-status meal plan item must hard-delete locally and create a sync-queue delete tombstone in the same local transaction.
- [ ] Saving a latest weight log must create a new active nutrition target and daily target snapshot update in the same user action flow.
- [ ] Deleting the latest weight log must recalculate latest weight, nutrition target, hydration target, and affected dashboard values.

---

## 6. Supabase Security Checklist

### 6.1 RLS General

- [ ] Enable RLS on all user-owned tables.
- [ ] Test that User A cannot read User B profile.
- [ ] Test that User A cannot read User B logs.
- [ ] Test that User A cannot update User B records.
- [ ] Test that User A cannot delete User B records.
- [ ] Test that unauthenticated users cannot access protected tables.
- [ ] Test admin can manage official foods.
- [ ] Test normal users cannot manage official foods.
- [ ] Test admin can moderate community reports.
- [ ] Test normal users cannot access admin tables/actions.

### 6.2 Storage Buckets

Create buckets according to approved storage scope:

- [ ] `community-images` must not be created by default; create only if community image upload is approved through a written change request
- [ ] `profile-images` must **not** be created because profile image/avatar upload is not included unless approved through a written change request.
- [ ] `ai-scans`, only if persistent AI scan image storage is explicitly approved

### 6.3 Storage Path Rules

- [ ] AI scan image path, only if optional persistent scan-image storage is approved:

```text
ai-scans/{user_id}/{scan_id}.{extension}
```

- [ ] Community image path, only if community image upload is approved through a written change request:

```text
community-images/{user_id}/{post_id}.{extension}
```

### 6.4 Storage Validation

- [ ] Max image size: 5 MB.
- [ ] Allowed file types:
  - [ ] JPG
  - [ ] PNG
  - [ ] WEBP
- [ ] User can only upload to owned path.
- [ ] User can only read private AI images they own, if optional AI scan storage is enabled.
- [ ] Community image visibility follows the approved public/authenticated read policy only if community image upload is approved.

---

## 7. Flutter Architecture Checklist

Each feature must follow this structure:

```text
Screen / Widget
→ Controller / ViewModel
→ Use Case / Service
→ Repository
→ Data Source
   → SQLite Local Database
   → Supabase Remote Database
   → FastAPI AI Backend, if needed
```

### 7.1 Common Core Layer

- [ ] Create `AppError` model.
- [ ] Create `Result<T>` or equivalent success/error wrapper.
- [ ] Create global validators.
- [ ] Create date/time helper.
- [ ] Create UUID helper.
- [ ] Create money formatter for PHP.
- [ ] Create macro/calorie formatter.
- [ ] Create network connectivity service.
- [ ] Create Supabase client provider.
- [ ] Create local database provider.
- [ ] Create sync service provider.
- [ ] Create global loading component.
- [ ] Create global empty state component.
- [ ] Create global error banner/dialog.
- [ ] Create internet-required component.
- [ ] Create offline-mode banner.

### 7.2 Routing Checklist

- [ ] Session loading route.
- [ ] Login route.
- [ ] Register route.
- [ ] Forgot password route.
- [ ] Onboarding route group.
- [ ] Dashboard route.
- [ ] Manual log route.
- [ ] Food search route.
- [ ] Custom food route.
- [ ] Hydration route.
- [ ] Weight route.
- [ ] Recommendation route.
- [ ] Planner route.
- [ ] AI scanner route.
  - [ ] AI Scanner must be reachable from the Log tab and/or Dashboard Quick Actions.
- [ ] Chatbot route.
  - [ ] Chatbot must be reachable from Dashboard Quick Actions and/or Profile help/settings.
- [ ] Analytics route.
- [ ] Community route.
- [ ] Profile/settings route.
- [ ] Admin route guarded by role.

### 7.3 Global UI States

Every screen must handle:

- [ ] Initial/loading state.
- [ ] Empty state.
- [ ] Error state.
- [ ] Offline state if relevant.
- [ ] Validation error state.
- [ ] Success confirmation if user action saves data.

---

## 8. Feature Build Checklist

# F01 — Authentication and Access Control

## Build Requirements

- [ ] Build Session Loading Screen.
- [ ] Build Login Screen.
- [ ] Build Register Screen.
- [ ] Build Forgot Password Screen.
- [ ] Build OAuth redirect handler only if Google OAuth is implemented.
- [ ] Build Logout Confirmation Dialog.
- [ ] Implement Supabase email/password registration.
- [ ] Implement Supabase email/password login.
- [ ] Implement session persistence.
- [ ] Implement session refresh/expired handling.
- [ ] Check `APP_USER.account_status` after authentication.
- [ ] Block disabled accounts from routing to onboarding/dashboard.
- [ ] Implement logout.
- [ ] If pending sync exists during logout, show warning.
- [ ] Route user based on:
  - [ ] no session → login
  - [ ] session + onboarding incomplete → onboarding
  - [ ] session + onboarding complete → dashboard

## Validation

- [ ] Email is required.
- [ ] Email must be valid format.
- [ ] Password is required.
- [ ] Password minimum length is enforced.
- [ ] Confirm password must match password during registration.
- [ ] Duplicate email shows user-readable error.
- [ ] Invalid credentials show user-readable error.
- [ ] Disabled account shows a user-readable account-disabled error.

## Offline Behavior

- [ ] New login/register blocked offline.
- [ ] Existing valid local session may open offline only when the last cached `APP_USER.account_status` is `active`.
- [ ] When the app reconnects, recheck `APP_USER.account_status`; if disabled, block protected routes, stop sync, and show account-disabled message.
- [ ] Password reset blocked offline.
- [ ] Logout offline clears local session but warns about pending sync.

## Tests

- [ ] Register valid user.
- [ ] Register duplicate email.
- [ ] Login valid user.
- [ ] Login wrong password.
- [ ] Login disabled account and verify access is blocked.
- [ ] Open app with valid session.
- [ ] Open app with expired session.
- [ ] Logout with no pending sync.
- [ ] Logout with pending sync.
- [ ] User A cannot access User B data.

---

# F02 — Onboarding and Profile Setup

## Screens

- [ ] Set Nickname Screen.
- [ ] Choose Goal Screen.
- [ ] Health and Safety Disclaimer Screen.
- [ ] Allergy and Restriction Screen.
- [ ] User Stats Screen.
- [ ] Budget Setup Screen.
- [ ] Onboarding Review Screen.

## Data Fields

- [ ] nickname
- [ ] sex
- [ ] age
- [ ] height_cm
- [ ] current_weight_kg
- [ ] target_weight_kg
- [ ] activity_level
- [ ] fitness_goal
- [ ] daily_budget_php
- [ ] allergies
- [ ] dietary_restrictions
- [ ] medical_disclaimer_accepted
- [ ] onboarding_completed

## Validation

- [ ] Nickname: 2–30 characters.
- [ ] Sex: male or female.
- [ ] Age: 13–80.
- [ ] Height: 100–250 cm inclusive.
- [ ] Current weight: 20–300 kg inclusive.
- [ ] Target weight: optional; if provided, must be 20–300 kg inclusive.
- [ ] Activity level must be valid enum.
- [ ] Fitness goal must be valid enum.
- [ ] Daily budget must be at least ₱20.
- [ ] Medical disclaimer must be accepted before completion.

## Data Flow

- [ ] Save profile locally first.
- [ ] Create initial `WEIGHT_LOG` from `current_weight_kg` during onboarding completion.
- [ ] Generate active nutrition target after profile completion using the initial weight log as the current-weight source.
- [ ] Save nutrition target locally.
- [ ] Queue profile sync.
- [ ] Queue initial weight log sync.
- [ ] Queue nutrition target sync.
- [ ] Mark onboarding completed.

## Tests

- [ ] Complete onboarding with valid data.
- [ ] Leave nickname empty.
- [ ] Enter invalid age.
- [ ] Reject disclaimer.
- [ ] Complete onboarding offline with existing session and existing local `APP_USER` identity.
- [ ] Block offline onboarding completion if local `APP_USER` identity is missing.
- [ ] Change goal later and verify targets recalculate.

---

# F03 — Nutrition Target Engine

## Formula Requirements

- [ ] Implement male BMR formula:

```text
BMR = 10 × weight_kg + 6.25 × height_cm - 5 × age + 5
```

- [ ] Implement female BMR formula:

```text
BMR = 10 × weight_kg + 6.25 × height_cm - 5 × age - 161
```

- [ ] Implement TDEE:

```text
TDEE = BMR × activity_multiplier
```

- [ ] Implement goal calorie adjustments:
  - [ ] cutting = TDEE - 400
  - [ ] maintenance = TDEE
  - [ ] bulking = TDEE + 400
  - [ ] lean = TDEE + 200
  - [ ] gain_weight = TDEE + 500

- [ ] Implement macro distributions:
  - [ ] cutting: 30% protein, 45% carbs, 25% fat
  - [ ] maintenance: 25% protein, 50% carbs, 25% fat
  - [ ] bulking: 30% protein, 50% carbs, 20% fat
  - [ ] lean: 30% protein, 45% carbs, 25% fat
  - [ ] gain_weight: 25% protein, 55% carbs, 20% fat

- [ ] Implement gram conversion:
  - [ ] protein grams = protein calories / 4
  - [ ] carbs grams = carbs calories / 4
  - [ ] fat grams = fat calories / 9

- [ ] Implement hydration target formula:

```text
water_target_ml = current_weight_kg × 35
```

- [ ] Round `water_target_ml` to the nearest 100 ml for display.
- [ ] Use the latest `WEIGHT_LOG` value when available; otherwise use `USER_PROFILE.current_weight_kg`.
- [ ] Treat this as a general non-medical estimate, not a clinical hydration prescription.

## Storage

- [ ] Save BMR.
- [ ] Save TDEE.
- [ ] Save calorie target.
- [ ] Save protein target grams.
- [ ] Save carbs target grams.
- [ ] Save fat target grams.
- [ ] Calculate raw water target as `current_weight_kg × 35`, then store and display `water_target_ml` rounded to the nearest 100 ml.
- [ ] Save formula version.
- [ ] Mark current target as active.
- [ ] Mark old targets inactive.
- [ ] Create or update `DAILY_TARGET_SNAPSHOT` for the active local date after onboarding, profile change, goal change, daily budget change, and latest weight change.
- [ ] Analytics must read dated target/budget snapshots for historical calculations.

## Tests

- [ ] Male BMR calculation.
- [ ] Female BMR calculation.
- [ ] TDEE calculation for every activity level.
- [ ] Goal calorie adjustment for every goal.
- [ ] Macro percentage conversion.
- [ ] Recalculation after profile update.
- [ ] Recalculation after new latest weight log is saved.
- [ ] Recalculation after latest weight log is deleted.
- [ ] Daily target snapshot uses the correct target and budget for the selected date.

---

# F04 — Local Filipino Food Database

## Screens

- [ ] Food Search Screen.
- [ ] Food Detail Screen.
- [ ] Custom Food Form.
- [ ] Admin Food Management Screen.

## Official Food Requirements

- [ ] Food name.
- [ ] Normalized food name.
- [ ] Category.
- [ ] Serving label.
- [ ] Serving grams.
- [ ] Calories.
- [ ] Protein grams.
- [ ] Carbs grams.
- [ ] Fat grams.
- [ ] Estimated price PHP.
- [ ] Local food flag.
- [ ] Active flag.
- [ ] Nutrition source.
- [ ] Price source.

## Seed Food Checklist

Seed at least these common foods or equivalent Filipino/local items:

- [ ] boiled egg
- [ ] fried egg
- [ ] rice
- [ ] sardines
- [ ] tuna
- [ ] tofu
- [ ] tokwa
- [ ] chicken breast
- [ ] adobong manok
- [ ] pork adobo
- [ ] tinolang manok
- [ ] sinigang na baboy
- [ ] sinigang na isda
- [ ] ginisang monggo
- [ ] tortang talong
- [ ] grilled bangus
- [ ] fried bangus
- [ ] oatmeal
- [ ] banana
- [ ] kamote
- [ ] peanut butter
- [ ] chicken curry
- [ ] menudo
- [ ] pinakbet
- [ ] laing
- [ ] pancit canton
- [ ] lumpiang gulay
- [ ] beef tapa
- [ ] longganisa
- [ ] tocino
- [ ] giniling
- [ ] nilagang baka
- [ ] chopsuey
- [ ] bicol express
- [ ] grilled tilapia
- [ ] fried tilapia
- [ ] ensaladang talong
- [ ] malunggay soup
- [ ] chicken afritada
- [ ] pork steak
- [ ] arroz caldo
- [ ] lugaw
- [ ] champorado
- [ ] pandesal
- [ ] whole wheat bread
- [ ] milk
- [ ] yogurt
- [ ] apple
- [ ] orange
- [ ] cucumber
- [ ] cabbage

## Search Requirements

- [ ] Search by normalized name.
- [ ] Filter by category.
- [ ] Filter by local food flag.
- [ ] Hide inactive foods from normal user search.
- [ ] Include custom foods in user search.

## Custom Food Requirements

- [ ] User can create custom food offline.
- [ ] User can update only their own custom foods.
- [ ] User can soft-delete only their own custom foods.
- [ ] Deleted custom foods are hidden from future search/logging but must not change old meal log snapshots.
- [ ] Custom food saves locally first.
- [ ] Custom food create/update/delete queues sync.
- [ ] Custom food can be logged immediately.

## Tests

- [ ] Search official food offline.
- [ ] Search inactive food as normal user.
- [ ] Create custom food.
- [ ] Reject negative calories.
- [ ] Reject negative macros.
- [ ] Reject negative price.
- [ ] Admin updates official food.
- [ ] Old meal logs remain unchanged after food update.

---

# F05 — Manual Meal Logging

## Screens

- [ ] Manual Log Screen.
- [ ] Food Search Modal.
- [ ] Quantity Input Screen / Component, only as an optional intermediate step before returning to Manual Log.
- [ ] Custom Food Form.
- [ ] Edit Meal Log Screen.
- [ ] Delete Confirmation Dialog.

## Navigation Rule

- [ ] Manual Log Screen is the only manual logging save screen.
- [ ] Quantity Input Screen / Component must not duplicate saving behavior.
- [ ] If the user is already on Manual Log Screen, use the inline quantity field.
- [ ] If the user selects food from Food Search, Food Detail, or a quick action, Quantity Input may confirm quantity before returning to Manual Log.

## Required Inputs

- [ ] Food item.
- [ ] Meal type.
- [ ] Quantity or serving multiplier.
- [ ] Logged date/time.
- [ ] Source defaults to `manual`; if opened from Recommendation Detail, save source as `recommendation`; if opened from planner conversion, use the planner conversion flow instead.

## Calculation Rules

- [ ] `logged_calories = food.calories × serving_multiplier`
- [ ] `logged_protein = food.protein_g × serving_multiplier`
- [ ] `logged_carbs = food.carbs_g × serving_multiplier`
- [ ] `logged_fat = food.fat_g × serving_multiplier`
- [ ] `logged_cost = food.estimated_price_php × serving_multiplier`

## Snapshot Rules

When saved, store:

- [ ] food_name_snapshot
- [ ] serving_grams_snapshot
- [ ] calories_snapshot
- [ ] protein_g_snapshot
- [ ] carbs_g_snapshot
- [ ] fat_g_snapshot
- [ ] cost_php_snapshot

Do not recalculate old logs from updated food records.

## Offline Rules

- [ ] Add meal log offline.
- [ ] Edit meal log offline.
- [ ] Delete meal log offline using soft delete.
- [ ] Queue create/update/delete sync.
- [ ] Dashboard updates immediately.

## Tests

- [ ] Add meal log offline.
- [ ] Add quantity 2 and verify values double.
- [ ] Edit meal quantity.
- [ ] Soft-delete meal.
- [ ] Dashboard excludes deleted log.
- [ ] Sync retry does not create duplicate meal log.
- [ ] Food price update does not change old meal log cost.

---

# F06 — Dashboard / Home Feed

## Widgets

- [ ] Calorie Remaining Card.
- [ ] Macro Progress Card.
- [ ] Budget Card.
- [ ] Hydration Card.
- [ ] Latest Weight Widget.
- [ ] Recent Logs Widget.
- [ ] Quick Action Floating Button.
- [ ] Warning Banner.

## Data Sources

- [ ] Active nutrition target.
- [ ] Today’s meal logs.
- [ ] Today’s water logs.
- [ ] Latest weight log.
- [ ] Profile daily budget.

## Calculations

- [ ] Total consumed calories.
- [ ] Remaining calories.
- [ ] Total protein consumed.
- [ ] Total carbs consumed.
- [ ] Total fat consumed.
- [ ] Total budget spent.
- [ ] Remaining budget.
- [ ] Total water intake.
- [ ] Weight latest value.

## Warning States

- [ ] Over budget warning.
- [ ] Over calorie warning.
- [ ] No target found prompt.
- [ ] No logs empty state.
- [ ] SQLite error retry.

## Tests

- [ ] Open dashboard with no logs.
- [ ] Add meal log and verify calories/macros update.
- [ ] Add water log and verify hydration update.
- [ ] Add weight log and verify latest weight update.
- [ ] Exceed budget and verify warning.
- [ ] Exceed calories and verify warning.

---

# F07 — Budget-Aware Recommendation Engine

## Inputs

- [ ] Remaining budget.
- [ ] Remaining calories.
- [ ] Remaining protein.
- [ ] Remaining carbs.
- [ ] Remaining fat.
- [ ] Allergies.
- [ ] Dietary restrictions.
- [ ] Fitness goal.
- [ ] Food list from SQLite.
- [ ] User-owned custom foods.
- [ ] Meal type or current time suggestion.

## Hard Rules

- [ ] Never recommend food matching listed allergies.
- [ ] Apply allergy filtering before scoring; do not use a separate allergy penalty for already-excluded foods.
- [ ] Do not auto-log recommendations.
- [ ] Always provide reason text.
- [ ] Work offline.
- [ ] Show closest low-cost options if no perfect match.
- [ ] Save recommendation log for analytics/thesis evidence.

## Scoring Components

- [ ] Protein fit score.
- [ ] Affordability score.
- [ ] Calorie fit score.
- [ ] Goal match score.
- [ ] Meal type score.
- [ ] Over-budget penalty.


## Locked Scoring Formula

The recommendation engine must be deterministic and reproducible for thesis defense.

```text
final_score =
  0.30 × affordability_score
+ 0.25 × protein_fit_score
+ 0.20 × calorie_fit_score
+ 0.15 × macro_balance_score
+ 0.05 × goal_match_score
+ 0.05 × meal_type_score
- over_budget_penalty
```

Component rules:

```text
affordability_score = 1 - min(food_cost / max(remaining_budget, 1), 1)
protein_fit_score = 1 - min(abs(food_protein - remaining_protein) / max(remaining_protein, 1), 1)
calorie_fit_score = 1 - min(abs(food_calories - remaining_calories) / max(remaining_calories, 1), 1)
carbs_fit_score = 1 - min(abs(food_carbs - remaining_carbs) / max(remaining_carbs, 1), 1)
fat_fit_score = 1 - min(abs(food_fat - remaining_fat) / max(remaining_fat, 1), 1)
macro_balance_score = average(protein_fit_score, carbs_fit_score, fat_fit_score)
meal_type_score = 1.00 if food is suitable for selected/current meal type, otherwise 0.50
goal_match_score = 1.00 if food supports the selected goal rule, otherwise 0.50
over_budget_penalty = 0.25 if food_cost > remaining_budget, otherwise 0.00
```

Goal match rules:

| Goal | Rule |
|---|---|
| `cutting` | Prefer high protein, moderate calories, low cost. |
| `maintenance` | Prefer balanced calories/macros and budget fit. |
| `bulking` | Prefer higher calories and protein while remaining budget-aware. |
| `lean` | Prefer high protein and controlled calorie surplus. |
| `gain_weight` | Prefer affordable calorie-dense foods with acceptable protein. |

If no food fits the remaining budget, show safe closest options with a clear over-budget warning. Allergy conflicts are excluded before scoring and must never appear as suggestions.

## Screens

- [ ] Recommendation List Screen.
- [ ] Recommendation Detail Screen.
- [ ] Add to Log action.
  - [ ] Opens Manual Log Screen with the recommended food preselected.
  - [ ] User must still confirm meal type, quantity, and logged date/time before saving.
  - [ ] Saved meal log source must be `recommendation`.
  - [ ] Mark recommendation accepted only after the meal log is successfully saved and linked.
- [ ] Add to Planner action.
  - [ ] Opens Add Planned Meal Screen with the recommended food preselected.
  - [ ] User must still confirm planned date, meal type, and quantity before saving.
  - [ ] Mark recommendation accepted only after the meal plan is successfully saved and linked.

## Tests

- [ ] Generate recommendations with enough budget.
- [ ] Low budget prioritizes cheap foods.
- [ ] Allergy conflict excludes food.
- [ ] No exact match shows closest safe options.
- [ ] User accepts recommendation to log.
- [ ] User accepts recommendation to planner.
- [ ] Recommendation works offline.

---

# F08 — Hydration Tracking

## Screens

- [ ] Water Log Screen.
- [ ] Custom Amount Dialog.
- [ ] Hydration History Screen.

## Requirements

- [ ] Preset amounts: 250 ml, 500 ml, 1000 ml.
- [ ] Custom amount.
- [ ] Logged date/time, automatically set to current device date/time when adding from preset/custom amount.
- [ ] Save locally first.
- [ ] Queue sync.
- [ ] Dashboard updates immediately.
- [ ] Deleting a water log uses hard delete from the local `water_logs` table.
- [ ] A water-log hard delete must create a sync-queue delete operation in the same local transaction, preserving the deleted record UUID/entity type for remote deletion.
- [ ] No `is_deleted` flag is required for water logs unless a later change request replaces this hard-delete rule.

## Validation

- [ ] Amount must be greater than 0.
- [ ] Amount must be less than or equal to 5000 ml per entry.

## Tests

- [ ] Add 250 ml.
- [ ] Add custom 750 ml.
- [ ] Reject negative amount.
- [ ] Reject extremely large amount.
- [ ] Delete water log and verify total decreases.
- [ ] Delete water log offline and verify a sync-queue delete tombstone remains until remote deletion succeeds.

---

# F09 — Weight Tracking

## Screens

- [ ] Log Weight Screen.
- [ ] Weight History Screen.
- [ ] Weight Trend Chart.

## Requirements

- [ ] Save weight in kg.
- [ ] Store logged date/time.
- [ ] Save locally first.
- [ ] Queue sync.
- [ ] Update latest weight display.
- [ ] If the saved log is the latest by `logged_at`, recalculate BMR, TDEE, calories, macros, and hydration target.
- [ ] Mark previous nutrition target inactive and create a new active `NUTRITION_TARGET`.
- [ ] Create or update the current `DAILY_TARGET_SNAPSHOT`.
- [ ] Queue nutrition target sync when recalculation occurs.
- [ ] Use historical logs for trend chart.
- [ ] Onboarding creates the first `WEIGHT_LOG` so latest-weight behavior is available immediately after onboarding.
- [ ] Latest `WEIGHT_LOG` is the source of truth for current weight after onboarding.
- [ ] Deleting a weight log uses hard delete from the local `weight_logs` table.
- [ ] A weight-log hard delete must create a sync-queue delete operation in the same local transaction, preserving the deleted record UUID/entity type for remote deletion.
- [ ] No `is_deleted` flag is required for weight logs unless a later change request replaces this hard-delete rule.
- [ ] If the deleted weight log was the latest, find the next latest remaining `WEIGHT_LOG`, recalculate targets, update dashboard/profile display, and queue affected sync operations.

## Validation

- [ ] Weight must be 20–300 kg inclusive.
- [ ] Values below 20 kg are rejected.
- [ ] Values above 300 kg are rejected.

## Tests

- [ ] Add valid weight.
- [ ] Reject impossible weight.
- [ ] Accept boundary weights 20 kg and 300 kg.
- [ ] Add multiple weights and verify trend.
- [ ] Delete latest weight and recalculate latest display from the remaining latest `WEIGHT_LOG`.
- [ ] Delete weight log offline and verify a sync-queue delete tombstone remains until remote deletion succeeds.

---

# F10 — Weekly Meal Planner

## Screens

- [ ] Weekly Planner Screen.
- [ ] Add Planned Meal Screen.
- [ ] Planned Day Summary Screen.
- [ ] Convert to Log Dialog.
- [ ] Mark Skipped Dialog.

## Requirements

- [ ] Support full 7-day week.
- [ ] Planned date is required.
- [ ] Meal type is required.
- [ ] Food is required.
- [ ] Quantity is required.
- [ ] Save snapshot nutrition and cost values.
- [ ] Show planned daily calories.
- [ ] Show planned daily macros.
- [ ] Show planned daily cost.
- [ ] Warn if planned cost exceeds budget.
- [ ] Convert planned meal to actual meal log.
- [ ] Mark converted meal as `logged`.
- [ ] Mark meal as `skipped` when skipped.
- [ ] Planned meal delete is allowed only for `planned` status; hard delete locally and create a sync-queue delete tombstone using the meal plan UUID.
- [ ] Preserve `logged` and `skipped` meal plans for history/analytics unless a later written change request approves archived deletion.

## Convert-to-Log Transaction

- [ ] Create meal log from meal plan snapshot.
- [ ] Set meal log source = `planner`.
- [ ] Update meal plan status = `logged`.
- [ ] Set `converted_meal_log_id`.
- [ ] Queue both sync operations.

## Tests

- [ ] Add planned meal.
- [ ] Plan exceeds budget and warning appears.
- [ ] Convert plan to log.
- [ ] Mark plan skipped.
- [ ] Delete planned meal.
- [ ] Planner works offline.

---

# F11 — Offline Sync Queue

## Required Entity Types

- [ ] profiles
- [ ] nutrition_targets
- [ ] custom_foods
- [ ] meal_logs
- [ ] water_logs
- [ ] weight_logs
- [ ] meal_plans
- [ ] recommendation_sessions
- [ ] recommendation_items
- [ ] ai_scans
- [ ] ai_scan_predictions
- [ ] ai_scan_feedback
- [ ] chat_sessions
- [ ] chat_messages
- [ ] daily_target_snapshots

## Excluded From Offline Sync Queue

- [ ] `community_posts`
- [ ] `community_comments`
- [ ] `community_likes`
- [ ] `community_reports`

Community write actions are online-only. If offline, the app must block the action and must not create a local unsynced community record. Cached community feed data may exist only for offline viewing.


## Processing Order

- [ ] profiles
- [ ] nutrition_targets
- [ ] daily_target_snapshots
- [ ] custom_foods
- [ ] meal_logs
- [ ] water_logs
- [ ] weight_logs
- [ ] meal_plans
- [ ] recommendation_sessions
- [ ] recommendation_items
- [ ] ai_scans
- [ ] ai_scan_predictions
- [ ] ai_scan_feedback
- [ ] chat_sessions
- [ ] chat_messages

Community write actions are excluded from this order because they are online-only and must not enter the offline sync queue.

## Sync Queue Required Fields

- [ ] `sync_queue_id`
- [ ] `operation_id`, generated once per local user action for idempotency
- [ ] `user_id`
- [ ] `device_id`, if device tracking is implemented
- [ ] `entity_type`
- [ ] `entity_id`
- [ ] `operation_type`: create, update, or delete
- [ ] `payload_json`, containing the exact remote payload or tombstone payload
- [ ] `changed_fields_json`, used to avoid overwriting fields the user did not edit
- [ ] `client_created_at`
- [ ] `client_updated_at`
- [ ] `client_sequence`, monotonically increasing per device
- [ ] `attempt_count`
- [ ] `last_error`
- [ ] `sync_status`
- [ ] `depends_on_entity_type`, optional
- [ ] `depends_on_entity_id`, optional
- [ ] `server_synced_at`, set only after successful remote confirmation

## Entity Operation Matrix

| Entity | Create | Update | Delete | Delete style / notes |
|---|---:|---:|---:|---|
| `profiles` | Yes | Yes | No | Field-level merge; never overwrite required fields with null. |
| `nutrition_targets` | Yes | Yes | No | Old rows marked inactive or closed with `effective_to`. |
| `daily_target_snapshots` | Yes | Yes | No | One per user/date; used for analytics. |
| `custom_foods` | Yes | Yes | Yes | Soft delete/hide from future search. |
| `meal_logs` | Yes | Yes | Yes | Soft delete with `is_deleted = true`. |
| `water_logs` | Yes | No/limited | Yes | Hard delete locally plus tombstone payload. |
| `weight_logs` | Yes | No/limited | Yes | Hard delete locally plus tombstone payload; latest deletion recalculates target. |
| `meal_plans` | Yes | Yes | Yes | Hard delete only if status is `planned`; `logged`/`skipped` preserved. |
| `recommendation_sessions` | Yes | No | No | Append-only thesis evidence. |
| `recommendation_items` | Yes | Acceptance update only | No | Update only after linked log/plan save succeeds. |
| `ai_scans` | Yes | Status update only | No | Linked by `client_scan_id`. |
| `ai_scan_predictions` | Yes | No | No | Append-only candidates. |
| `ai_scan_feedback` | Yes | Yes | No | Idempotent upsert by `client_scan_id`. |
| `chat_sessions` | Yes | End-time update only | No | Preserved for history. |
| `chat_messages` | Yes | Delivery-status update only | No | Append-only message content. |
| `community_*` | No offline queue | No offline queue | No offline queue | Online-only writes. |

## Improved Conflict Rules

- [ ] UUID identifies the record; `operation_id` identifies the local action.
- [ ] `server_synced_at` is the confirmation timestamp from the backend and must not be generated by the client.
- [ ] Do not rely only on client `updated_at` because device clocks may be wrong.
- [ ] For profile updates, merge by `changed_fields_json`; do not replace the whole profile when only one field changed.
- [ ] For custom foods and meal logs, same UUID prevents duplicates; changed fields decide safe updates.
- [ ] For delete tombstones, delete wins unless the remote record is already absent.
- [ ] For water/weight/meal plan delete tombstones, preserve `entity_id`, `entity_type`, and `operation_id` until remote delete succeeds.
- [ ] For chat messages, message text is append-only; only delivery/sync status may update.
- [ ] For AI scan feedback, upsert by `client_scan_id` so correction and confirmation update one feedback record.

## Retry Rules

- [ ] Attempt 1: immediate.
- [ ] Attempt 2: after 5 seconds.
- [ ] Attempt 3: after 30 seconds.
- [ ] Attempt 4: after 2 minutes.
- [ ] Attempt 5+: mark failed and allow manual retry.

## Tests

- [ ] Create log offline and sync later.
- [ ] Update log offline and sync later.
- [ ] Delete log offline and sync later.
- [ ] Failed sync remains pending or failed.
- [ ] Retry does not duplicate records.
- [ ] Community create/comment/like/report offline is blocked and does not create a sync queue row.
- [ ] Sync respects processing order.
- [ ] Conflict resolution works using `updated_at`.

---

# F12 — Admin Food and Moderation Tools

## Screens

- [ ] Admin Dashboard Screen.
- [ ] Food Management Screen.
- [ ] Add/Edit Food Screen.
- [ ] Price History Screen.
- [ ] Reports Screen.
- [ ] Moderation Detail Screen.

## Food Admin Requirements

- [ ] Admin can create official food.
- [ ] Admin can update official food.
- [ ] Admin can deactivate official food.
- [ ] Admin can update price.
- [ ] Admin update creates food change/history log.
- [ ] Normal user cannot create official food.
- [ ] Normal user cannot edit official food.

## Moderation Requirements

- [ ] Admin can view reports.
- [ ] Admin can hide post.
- [ ] Admin can unhide post.
- [ ] Admin can view comments under a reported post from Moderation Detail.
- [ ] Admin can hide comment from that admin-only content review path.
- [ ] Admin can unhide comment from that admin-only content review path.
- [ ] Normal users cannot report comments unless approved through a written change request.
- [ ] Admin can dismiss report.
- [ ] Hidden content does not appear in normal feed.

## Tests

- [ ] Admin opens dashboard.
- [ ] Normal user is blocked from admin dashboard.
- [ ] Admin creates food.
- [ ] Admin updates food price.
- [ ] Old logs remain unchanged.
- [ ] Admin hides reported post.
- [ ] Hidden post disappears from feed.

---

# F13 — FastAPI Foundation

## Endpoints

- [ ] `GET /health`
- [ ] `GET /version`
- [ ] `POST /ai/scan-food`
- [ ] `POST /ai/scan-feedback`
  - [ ] Flutter saves scan feedback locally first.
  - [ ] Sync sends feedback to this endpoint using the same `client_scan_id` to prevent duplicates.
- [ ] `POST /ai/chat`
- [ ] `POST /ai/explain-recommendation`, optional but defined

## Global Response Format

Success:

```json
{
  "success": true,
  "data": {},
  "message": "OK"
}
```

Error:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message.",
    "details": {}
  }
}
```

## Error Codes

- [ ] `UNAUTHORIZED`
- [ ] `FORBIDDEN`
- [ ] `VALIDATION_ERROR`
- [ ] `IMAGE_TOO_LARGE`
- [ ] `UNSUPPORTED_IMAGE_TYPE`
- [ ] `AI_MODEL_FAILED`
- [ ] Do not use `LOW_CONFIDENCE` as an error for normal low-confidence predictions. Return successful low-confidence scan response with manual-search guidance.
- [ ] `CHAT_UNSAFE_REQUEST`
- [ ] `UPSTREAM_TIMEOUT`
- [ ] `RATE_LIMITED` for throttled requests
- [ ] `SERVER_ERROR`


## Locked API Contract

All FastAPI endpoints must return the global response format above. Protected endpoints derive the authenticated user from `Authorization: Bearer <Supabase JWT>` and must reject mismatched user IDs.

### `GET /health`

Success response:

```json
{
  "success": true,
  "data": {
    "status": "ok"
  },
  "message": "OK"
}
```

### `GET /version`

Success response:

```json
{
  "success": true,
  "data": {
    "api_version": "1.0.0",
    "enabled_modules": ["scan_food", "scan_feedback", "chat"]
  },
  "message": "OK"
}
```

### `POST /ai/scan-food`

Request type: `multipart/form-data`.

Required form fields:

| Field | Type | Required | Rule |
|---|---|---:|---|
| `image` | file | Yes | JPG/JPEG/PNG/WEBP, max 5 MB, minimum 224 × 224. |
| `client_scan_id` | string UUID | Yes | Generated by Flutter before upload. |
| `meal_type` | string/null | No | One of `breakfast`, `lunch`, `dinner`, `snack`; optional context only. |
| `image_storage_path` | string/null | No | Sent only if persistent scan-image storage is approved. |

Success response for completed/high-medium confidence:

```json
{
  "success": true,
  "data": {
    "client_scan_id": "uuid",
    "status": "completed",
    "manual_search_recommended": false,
    "candidates": [
      {
        "food_id": "uuid_or_null",
        "food_name": "Chicken adobo",
        "confidence": 0.86,
        "rank_number": 1,
        "calories": 280,
        "protein_g": 24,
        "carbs_g": 6,
        "fat_g": 16,
        "estimated_cost_php": 55
      }
    ]
  },
  "message": "OK"
}
```

Success response for low confidence:

```json
{
  "success": true,
  "data": {
    "client_scan_id": "uuid",
    "status": "low_confidence",
    "manual_search_recommended": true,
    "candidates": []
  },
  "message": "Low confidence. Please search manually."
}
```

### `POST /ai/scan-feedback`

Request body:

```json
{
  "client_scan_id": "uuid",
  "selected_food_id": "uuid_or_null",
  "corrected_food_id": "uuid_or_null",
  "confirmed_meal_log_id": "uuid_or_null",
  "meal_type": "breakfast | lunch | dinner | snack | null",
  "quantity": 1.0,
  "correction_reason": "optional text",
  "feedback_type": "candidate_selected | corrected | confirmed | cancelled"
}
```

Response body:

```json
{
  "success": true,
  "data": {
    "client_scan_id": "uuid",
    "feedback_saved": true
  },
  "message": "OK"
}
```

### `POST /ai/chat`

Request body:

```json
{
  "chat_session_id": "uuid",
  "client_message_id": "uuid",
  "message": "User question",
  "context": {
    "fitness_goal": "cutting | maintenance | bulking | lean | gain_weight",
    "remaining_budget_php": 120,
    "remaining_calories": 800,
    "remaining_protein_g": 40,
    "allergies": ["peanut"],
    "dietary_restrictions": []
  }
}
```

Response body:

```json
{
  "success": true,
  "data": {
    "assistant_message_id": "uuid",
    "reply": "Safe non-medical nutrition guidance.",
    "safety_status": "safe | redirected | blocked"
  },
  "message": "OK"
}
```

### `POST /ai/explain-recommendation` — Optional

Request body:

```json
{
  "recommendation_item_id": "uuid",
  "food_name": "string",
  "score_components": {
    "affordability_score": 0.9,
    "protein_fit_score": 0.7,
    "calorie_fit_score": 0.8,
    "macro_balance_score": 0.6,
    "goal_match_score": 1.0,
    "meal_type_score": 1.0,
    "over_budget_penalty": 0.0
  }
}
```

Response body:

```json
{
  "success": true,
  "data": {
    "explanation": "This food fits your budget and supports your protein target."
  },
  "message": "OK"
}
```

## Security

- [ ] Verify Supabase JWT for protected endpoints.
- [ ] Reject missing token.
- [ ] Reject expired token.
- [ ] Reject mismatched `user_id`.
- [ ] Do not log sensitive tokens.
- [ ] Configure CORS.
- [ ] Use HTTPS in production.

## Tests

- [ ] Health endpoint returns OK.
- [ ] Version endpoint returns API version and enabled modules.
- [ ] Protected endpoint rejects missing token.
- [ ] Protected endpoint rejects invalid token.
- [ ] Protected endpoint rejects mismatched user ID.
- [ ] Response format is consistent.
- [ ] Low-confidence scan response is represented as successful response with `status = low_confidence` and manual-search guidance.
- [ ] Rate-limited request returns `RATE_LIMITED` with readable retry message.

---

# F14 — AI Food Scanner

## Screens

- [ ] Camera Screen.
- [ ] Image Preview Screen.
- [ ] Scanning Loading Screen.
- [ ] Prediction Result Screen.
- [ ] Candidate Selection Screen.
- [ ] Manual Correction Screen.
- [ ] Confirm AI Log Screen.

## API Request Requirements

- [ ] Uses `POST /ai/scan-food`.
- [ ] Uses multipart form data.
- [ ] Sends image file.
- [ ] Sends user ID or token-derived authenticated user identity.
- [ ] Generates and sends `client_scan_id` before upload so prediction, correction, confirmation, and feedback remain linked.
- [ ] Sends meal type if provided.
- [ ] Sends image storage path only if optional persistent scan-image storage is approved and the image was uploaded first.

## Image Storage Rule

- [ ] Default behavior: send the image directly to FastAPI and do not persist the raw scan image in Supabase Storage.
- [ ] Store scan metadata, predictions, confirmation, and feedback.
- [ ] Store raw scan image path only if optional persistent scan-image storage is explicitly approved.

## Image Validation

- [ ] Allowed extensions: `.jpg`, `.jpeg`, `.png`, `.webp`.
- [ ] Allowed MIME types: `image/jpeg`, `image/png`, `image/webp`.
- [ ] Max file size: 5 MB.
- [ ] Minimum image size: 224 × 224.
- [ ] Reject empty file.

## Confidence Behavior

- [ ] `>= 0.80`: show top prediction, still require confirmation.
- [ ] `>= 0.60 and < 0.80`: show top 3 candidates, require confirmation.
- [ ] `< 0.60`: recommend manual search.

## Critical Save Rule

- [ ] Scanner endpoint must never create a meal log.
- [ ] Flutter must create meal log only after user confirms/corrects.
- [ ] Scan feedback must be saved locally.
- [ ] Correction and confirmation must upsert one feedback record by `client_scan_id`.
- [ ] Scan feedback must sync when online using idempotent upsert by `client_scan_id`.
- [ ] Raw scan image storage is optional and approval-based, not a default requirement.

## Error Handling

- [ ] No internet → show manual log option.
- [ ] Camera permission denied → show permission message and manual log option.
- [ ] Image too large → reject by default. Compression is excluded unless approved by written change request.
- [ ] Unsupported image type → reject.
- [ ] Backend timeout → retry/manual log option.
- [ ] Low confidence → manual search suggestion.

## Tests

- [ ] Upload valid image.
- [ ] High confidence requires confirmation.
- [ ] Medium confidence shows candidates.
- [ ] Low confidence recommends manual search.
- [ ] User corrects prediction and feedback is saved.
- [ ] Offline scanner attempt shows internet-required message.
- [ ] Scanner never auto-logs meal.

---

# F15 — AI Chatbot

## Screens

- [ ] Chatbot Screen.
- [ ] Suggested Prompts Section.
- [ ] Chat History.
- [ ] Safety Disclaimer Banner.

## Allowed Topics

- [ ] Meal suggestions.
- [ ] Budget-friendly alternatives.
- [ ] Macro explanations.
- [ ] Hydration reminders.
- [ ] General healthy eating guidance.
- [ ] App usage help.

## Blocked Topics

- [ ] Medical diagnosis.
- [ ] Disease treatment.
- [ ] Eating disorder advice.
- [ ] Extreme fasting.
- [ ] Supplement/drug prescription.
- [ ] Dangerous calorie restriction.
- [ ] Guaranteed health outcome claims.

## Context Requirements

- [ ] User ID.
- [ ] User message.
- [ ] Fitness goal.
- [ ] Remaining budget.
- [ ] Remaining calories.
- [ ] Remaining protein.
- [ ] Allergies.
- [ ] Dietary restrictions.
- [ ] Recent logs, if available.

## Behavior

- [ ] Save user message locally first with `delivery_status = local_saved`.
- [ ] Build context from SQLite.
- [ ] Send to `POST /ai/chat`.
- [ ] Apply backend safety rules.
- [ ] Save assistant response locally with `delivery_status = assistant_received`.
- [ ] If send fails, keep the user message visible with `delivery_status = failed` and show retry.
- [ ] If blocked/redirected by safety rules, store the final safety status and do not treat it as a failed network send.
- [ ] Queue chat messages for Supabase sync.
- [ ] View previous messages offline.
- [ ] Sending new message offline is blocked.

## Tests

- [ ] Budget meal question returns budget-aware answer.
- [ ] Allergy is respected.
- [ ] Medical diagnosis question is redirected/refused.
- [ ] Extreme diet question is refused.
- [ ] Offline send is blocked.
- [ ] Old messages can be viewed offline.
- [ ] Chatbot does not modify nutrition targets.

---

# F16 — Analytics

## Screens and Widgets

- [ ] Analytics Screen.
- [ ] Keep Analytics as one screen with sections/widgets; do not create separate top-level Analytics routes unless approved.
- [ ] Date Range Selector.
- [ ] Spending Chart.
- [ ] Weight Trend Chart.
  - [ ] Reuse the same Weight Trend Chart widget used in Weight Tracking; do not build a separate duplicate chart implementation.
- [ ] Macro Consistency Chart.
- [ ] Calorie Adherence Card.
- [ ] Hydration Consistency Card.
- [ ] Previous Logs List.

## Calculations

- [ ] Weekly spending total.
- [ ] Monthly spending total.
- [ ] Average daily calories.
- [ ] Macro adherence percentage.
- [ ] Weight change.
- [ ] Hydration adherence.
- [ ] Budget adherence.
- [ ] Historical calorie/macro/hydration/budget adherence must use `DAILY_TARGET_SNAPSHOT` for each date.
- [ ] Do not calculate old adherence using only the current active target.

## Empty States

- [ ] No meal logs.
- [ ] No weight logs.
- [ ] No water logs.
- [ ] No target.

## Tests

- [ ] Analytics with no data shows empty states.
- [ ] Add 7 days logs and verify weekly chart.
- [ ] Add weight logs and verify trend.
- [ ] Exceed weekly budget and verify warning.
- [ ] Analytics works offline.

---

# F17 — Community Feed

## Screens

- [ ] Community Feed Screen.
- [ ] Create Post Screen.
- [ ] Post Detail Screen.
- [ ] Report Post Dialog.

## Included Features

- [ ] Create text-only post by default.
- [ ] Community feed is public only inside the authenticated app; unauthenticated guests cannot read, create, like, comment, report, or delete community content.
- [ ] View authenticated public feed.
- [ ] Comment on post.
- [ ] Like/unlike post.
- [ ] Report post.
- [ ] Delete own post.
- [ ] Admin hide/unhide post.

## Excluded Features

- [ ] No private messaging.
- [ ] No friend requests.
- [ ] No group chats.
- [ ] No live direct chat.
- [ ] No real-time notification requirement.
- [ ] No community image upload unless approved through a written change request.

## Offline Behavior

- [ ] Cached authenticated feed posts may be viewed offline using read-only `community_cache`.
- [ ] Create post requires internet.
- [ ] Like/comment/report requires internet.
- [ ] Offline community create/comment/like/report must not create local unsynced records or sync queue tasks.

## Tests

- [ ] Create post online.
- [ ] Create post offline shows error.
- [ ] Like post.
- [ ] Unlike post.
- [ ] Comment on post.
- [ ] Report post.
- [ ] Delete own post.
- [ ] User cannot delete another user’s post.
- [ ] Admin hides post.
- [ ] Hidden post disappears.

---

# F18 — Account Lifecycle and Settings

## Screens

- [ ] Profile Screen.
- [ ] Edit Profile Screen.
- [ ] Settings Screen.
- [ ] Clear Cache Confirmation Dialog.
- [ ] Logout Confirmation Dialog.

## Requirements

- [ ] View profile data.
- [ ] Edit profile fields.
- [ ] If profile current weight changes, create a new `WEIGHT_LOG` instead of directly treating profile weight as the source of truth.
- [ ] Recalculate nutrition targets after relevant profile changes.
- [ ] Save edits locally first.
- [ ] Queue profile sync.
- [ ] Queue weight log sync when current weight changes.
- [ ] Queue nutrition target sync when target recalculates.
- [ ] Show pending sync status.
- [ ] Clear local cache only after confirmation.
- [ ] Clear cache may remove cached community feed, temporary AI scanner image files, expired API response cache, and non-critical UI cache.
- [ ] Clear cache must not remove profiles, nutrition targets, daily target snapshots, meal logs, water logs, weight logs, meal plans, custom foods, sync queue rows, delete tombstones, unsynced AI scan feedback, or unsynced chat messages.
- [ ] Logout warns if unsynced data exists.

## Tests

- [ ] Edit budget and verify dashboard/recommendations update.
- [ ] Edit weight and verify target recalculation if required.
- [ ] Clear cache confirmation works.
- [ ] Logout with pending sync warns user.

---

## 9. API Integration Checklist

### 9.1 Supabase Direct Operations

- [ ] Auth register.
- [ ] Auth login.
- [ ] Auth logout.
- [ ] Profile upsert.
- [ ] Nutrition target insert.
- [ ] Food read and sync.
- [ ] Custom food create/update/delete.
- [ ] Meal log create/update/delete.
- [ ] Water log create/update/delete.
- [ ] Weight log create/update/delete.
- [ ] Meal plan create/update/delete.
- [ ] Recommendation log save.
- [ ] AI scan log save.
- [ ] Chat message save.
- [ ] Community post create/delete, comment create, like/unlike, and post report operations, online-only and not queued offline. Post delete is owner-only and must be enforced by RLS.
- [ ] Admin food operations.
- [ ] Admin moderation operations.

### 9.2 FastAPI Operations

- [ ] `GET /health`.
- [ ] `GET /version`.
- [ ] `POST /ai/scan-food`.
- [ ] `POST /ai/scan-feedback`
  - [ ] Flutter saves scan feedback locally first.
  - [ ] Sync sends feedback to this endpoint using the same `client_scan_id` to prevent duplicates.
- [ ] `POST /ai/chat`.
- [ ] `POST /ai/explain-recommendation`.

### 9.3 API Validation Checklist

- [ ] All request bodies match the final API contract.
- [ ] All response bodies match the final API contract.
- [ ] All errors use standard error format.
- [ ] All protected requests include `Authorization: Bearer <token>`.
- [ ] Invalid tokens return `UNAUTHORIZED`.
- [ ] Forbidden actions return `FORBIDDEN`.
- [ ] Validation errors return `VALIDATION_ERROR`.

---

## 10. Testing Checklist

### 10.1 Unit Tests

- [ ] BMR formula.
- [ ] TDEE formula.
- [ ] Goal calorie adjustments.
- [ ] Macro gram conversion.
- [ ] Food quantity scaling.
- [ ] Meal log totals.
- [ ] Dashboard summary calculation.
- [ ] Budget remaining calculation.
- [ ] Recommendation score calculation.
- [ ] Allergy filter.
- [ ] Planner daily summary.
- [ ] Hydration total.
- [ ] Weight trend calculation.
- [ ] Analytics aggregation.
- [ ] Validators.

### 10.2 SQLite Tests

- [ ] Create schema.
- [ ] Run migration.
- [ ] Seed foods.
- [ ] Insert profile.
- [ ] Insert nutrition target.
- [ ] Insert meal log.
- [ ] Update meal log.
- [ ] Soft delete meal log.
- [ ] Query today’s logs.
- [ ] Query food search.
- [ ] Create sync queue task.
- [ ] Process sync queue state changes.

### 10.3 Supabase / RLS Tests

- [ ] User can read own profile.
- [ ] User cannot read another profile.
- [ ] User can read own logs.
- [ ] User cannot read another user’s logs.
- [ ] User can create own custom foods.
- [ ] User cannot edit official food.
- [ ] Admin can edit official food.
- [ ] User cannot access admin features.
- [ ] Admin can moderate posts.
- [ ] Storage user-owned path is enforced only for approved storage buckets.

### 10.4 Integration Tests

- [ ] Flutter → Supabase Auth.
- [ ] Flutter → SQLite.
- [ ] Flutter → Supabase table sync.
- [ ] Flutter → Supabase Storage only if an approved storage bucket exists for the tested feature.
- [ ] Flutter → FastAPI scan endpoint.
- [ ] Flutter → FastAPI chatbot endpoint.
- [ ] FastAPI → JWT verifier.
- [ ] Offline log → online sync.
- [ ] Planner convert → meal log sync.
- [ ] Recommendation accept → meal log or planner sync.

### 10.5 Offline Tests

- [ ] Open app offline with valid session.
- [ ] Food search works offline.
- [ ] Manual meal logging works offline.
- [ ] Dashboard works offline.
- [ ] Hydration works offline.
- [ ] Weight tracking works offline.
- [ ] Planner works offline.
- [ ] Recommendations work offline.
- [ ] Analytics works offline.
- [ ] AI scanner blocked offline.
- [ ] Chatbot send blocked offline.
- [ ] Community create blocked offline.
- [ ] Sync runs when connection returns.

### 10.6 AI Tests

- [ ] Valid image returns prediction.
- [ ] Invalid file type is rejected.
- [ ] Large image is rejected by default.
- [ ] Low confidence returns manual search suggestion.
- [ ] Prediction requires user confirmation.
- [ ] Feedback saves correction.
- [ ] Chatbot gives budget-aware meal suggestion.
- [ ] Chatbot respects allergies.
- [ ] Chatbot refuses medical diagnosis.
- [ ] Chatbot refuses extreme diet instruction.
- [ ] Chatbot latency is measured.
- [ ] Scanner latency is measured.

### 10.7 UAT Checklist

Prepare 20–30 respondents if following thesis methodology.

- [ ] Student/budget-conscious user can register.
- [ ] Student can complete profile.
- [ ] Student can set daily budget.
- [ ] Gym-goer can select bulking/cutting/maintenance.
- [ ] User can log Filipino food.
- [ ] User can see dashboard changes.
- [ ] User can get budget recommendation.
- [ ] User can use water tracker.
- [ ] User can use weight tracker.
- [ ] User can use planner.
- [ ] User can attempt scanner.
- [ ] User can ask chatbot safe question.
- [ ] Nutritionist/dietitian can evaluate food data reasonableness.
- [ ] Admin can update food data.

### 10.8 Performance Tests

- [ ] Dashboard opens under acceptable time with local data.
- [ ] Food search returns quickly with seed foods.
- [ ] Manual log saves quickly offline.
- [ ] Sync does not freeze UI.
- [ ] Scanner target processing is within expected range.
- [ ] Chatbot response time is measured.
- [ ] Supabase query response time is measured.
- [ ] App works on Android 8.0+ target device.
- [ ] App works on device with 3GB RAM target minimum.

---

## 11. Security and Privacy Checklist

- [ ] Supabase service role key is backend-only.
- [ ] Flutter uses anon key only.
- [ ] Protected FastAPI endpoints verify JWT.
- [ ] RLS enabled on all user-owned tables.
- [ ] Admin policies are separate from user policies.
- [ ] SQLite database is stored in app internal storage.
- [ ] Sensitive values are not printed in logs.
- [ ] Error messages do not reveal secrets.
- [ ] HTTPS used for production API calls.
- [ ] Medical disclaimer shown before nutrition guidance.
- [ ] Chatbot states non-clinical scope when needed.
- [ ] User data is scoped by user ID.
- [ ] Image uploads are user-owned.
- [ ] Report/moderation data is admin-only.

---

## 12. Defense Evidence Checklist

Collect proof while building, not after.

### 12.1 Screenshots

- [ ] Login screen.
- [ ] Register screen.
- [ ] Onboarding nickname screen.
- [ ] Goal selection screen.
- [ ] Health disclaimer screen.
- [ ] User stats screen.
- [ ] Budget setup screen.
- [ ] Dashboard screen.
- [ ] Food search screen.
- [ ] Manual log screen.
- [ ] Hydration screen.
- [ ] Weight screen.
- [ ] Recommendation screen.
- [ ] Planner screen.
- [ ] AI scanner screen.
- [ ] Chatbot screen.
- [ ] Analytics screen.
- [ ] Profile/settings screen.
- [ ] Admin food management screen.
- [ ] Community feed screen.

### 12.2 Test Evidence

- [ ] Unit test results.
- [ ] Integration test results.
- [ ] Offline test screenshots.
- [ ] RLS test screenshots.
- [ ] API Postman screenshots.
- [ ] Supabase table screenshots.
- [ ] SQLite seed data screenshot.
- [ ] Sync queue before/after screenshots.
- [ ] AI scanner prediction sample.
- [ ] AI chatbot safe response sample.
- [ ] UAT survey result summary.

### 12.3 Demo Script

Prepare a demo flow:

- [ ] Register/login.
- [ ] Complete onboarding.
- [ ] Show calculated nutrition target.
- [ ] Search Filipino food offline.
- [ ] Log meal offline.
- [ ] Show dashboard update.
- [ ] Add water intake.
- [ ] Add weight log.
- [ ] Generate budget recommendation.
- [ ] Add recommendation to planner.
- [ ] Convert planner item to meal log.
- [ ] Turn internet on and sync.
- [ ] Use AI scanner and confirm result.
- [ ] Ask chatbot budget-aware question.
- [ ] Show analytics.
- [ ] Show admin updating food price.
- [ ] Show old logs remain unchanged.

---

## 13. Deployment Checklist

### 13.1 Supabase Deployment

- [ ] Create production Supabase project.
- [ ] Run database migrations.
- [ ] Seed lookup tables.
- [ ] Seed official foods.
- [ ] Enable RLS.
- [ ] Apply RLS policies.
- [ ] Create only approved Storage buckets.
- [ ] Default MVP creates no image buckets unless persistent AI scan storage or community image upload is approved.
- [ ] Do not create `profile-images` unless profile/avatar upload is approved through written change request.
- [ ] Apply Storage policies only to approved buckets.
- [ ] Create admin account.
- [ ] Verify production anon key.
- [ ] Do not expose service role key.

### 13.2 FastAPI Deployment

- [ ] Choose hosting platform, such as Render.
- [ ] Configure environment variables.
- [ ] Enable HTTPS.
- [ ] Configure CORS.
- [ ] Deploy API.
- [ ] Test `/health`.
- [ ] Test `/version`.
- [ ] Test protected endpoints with token.
- [ ] Test logs do not expose secrets.

### 13.3 Flutter APK Build

- [ ] Configure production Supabase URL.
- [ ] Configure production anon key.
- [ ] Configure production FastAPI URL.
- [ ] Set app name.
- [ ] Set app icon.
- [ ] Set Android permissions:
  - [ ] Internet
  - [ ] Camera
  - [ ] Storage/media if needed
- [ ] Build debug APK for testing.
- [ ] Build release APK.
- [ ] Install on test device.
- [ ] Run smoke test.
- [ ] Save APK copy for defense.

---

## 14. Final Acceptance Checklist

The application is complete only when all items below are checked.

### Core

- [ ] User can register and login.
- [ ] User can complete onboarding.
- [ ] Nutrition targets calculate correctly.
- [ ] Food database works offline.
- [ ] User can create custom food.
- [ ] User can manually log meals offline.
- [ ] Dashboard updates immediately.
- [ ] Hydration tracking works offline.
- [ ] Weight tracking works offline.
- [ ] Recommendations work offline.
- [ ] Recommendation acceptance is saved only after linked meal log or meal plan creation succeeds.
- [ ] Planner works offline.
- [ ] Analytics works offline.

### Online/Cloud

- [ ] Supabase sync works.
- [ ] RLS protects user data.
- [ ] Admin can manage foods.
- [ ] Admin can moderate community.
- [ ] AI scanner works online.
- [ ] AI scanner requires confirmation.
- [ ] AI chatbot works online.
- [ ] Chatbot safety rules work.
- [ ] Minimum community works online: authenticated text-only feed, create post, comment, like, report post, and admin hide/unhide. No images, no notifications, no real-time requirement.

### Quality

- [ ] All validation rules work.
- [ ] All required error states work.
- [ ] Loading states exist.
- [ ] Empty states exist.
- [ ] Unit tests pass.
- [ ] Integration tests pass.
- [ ] Offline tests pass.
- [ ] Security tests pass.
- [ ] UAT evidence exists.
- [ ] APK builds successfully.
- [ ] Defense screenshots and demo script are ready.

---

## 15. AI Prompt Template for Coding Tasks

Use this prompt format whenever asking an AI model to generate code.

```text
You are helping build the JCG Fitness / NutriSmart AI Android app.
Use only the approved stack: Flutter + Dart, SQLite, Supabase, Supabase Storage, Python FastAPI.
Do not invent features, screens, tables, columns, endpoints, or behavior.
If something is missing from the contract, write TODO_NEEDS_APPROVAL.

Current task:
[describe exact task]

Contract constraints:
- Core tracking works offline using SQLite.
- Supabase is used for Auth, cloud database, Storage, RLS, and sync.
- FastAPI is used only for AI scanner, scanner feedback, chatbot, and optional recommendation explanation.
- Meal logs and meal plans must store snapshot values.
- AI scanner must never auto-create meal logs.
- Recommendations must run offline using a local rule-based engine.
- Chatbot requires internet and must follow safety rules.
- Excluded: private messaging, barcode scanning, grocery transactions, wearables, workout planning.

Required output:
- Files to create/update.
- Code.
- Explanation of how it maps to the approved contract.
- Tests to run.
```

---

## 16. Final Build Priority if Time Is Limited

If time becomes limited, complete in this order:

1. SQLite schema and seed foods.
2. Authentication.
3. Onboarding/profile setup.
4. Nutrition target engine.
5. Manual meal logging.
6. Dashboard.
7. Budget-aware recommendations.
8. Hydration tracking.
9. Weight tracking.
10. Meal planner.
11. Sync queue.
12. Basic admin food management.
13. Basic AI scanner with confirmation.
14. Basic chatbot with safety rules.
15. Analytics.
16. Community feed.

Minimum defensible prototype:

```text
Login/Register
→ Onboarding
→ Nutrition target calculation
→ Offline food search
→ Manual meal logging
→ Dashboard totals
→ Budget-aware recommendations
→ Community feed online evidence
→ Sync evidence
```

