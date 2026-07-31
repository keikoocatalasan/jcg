# NutriSmart AI — Test Plan

> Version: 1.0  
> Last updated: June 13, 2026  
> App: JCG Fitness / NutriSmart AI  
> Platform: Flutter (Android/iOS) + FastAPI backend

---

## 1. Unit Tests

### 1.1 Nutrition Engine (`test/unit/nutrition_engine_test.dart`)

| Test Case | Input | Expected | Status |
|-----------|-------|----------|--------|
| Male BMR | 70kg, 175cm, 25yr, male | 1668.75 | ✅ |
| Female BMR | 55kg, 160cm, 30yr, female | 1219.00 | ✅ |
| BMR edge: max height, min weight | 20kg, 250cm, 80yr, male | 1267.50 | ✅ |
| BMR edge: min age, female | 20kg, 100cm, 13yr, female | 873.00 | ✅ |
| TDEE sedentary | BMR 1668.75 × 1.20 | 2002.50 | ✅ |
| TDEE moderate | BMR 1668.75 × 1.55 | 2586.56 | ✅ |
| TDEE very active | BMR 1668.75 × 1.90 | 3170.63 | ✅ |
| Goal adj: cutting | — | -400 | ✅ |
| Goal adj: bulking | — | 400 | ✅ |
| Goal adj: unknown | — | 0 | ✅ |
| Macro grams: 2000kcal cutting | 30/45/25 split | P150g C225g F55.56g | ✅ |
| Macro grams: 1500kcal maintenance | 25/50/25 split | P93.75g C187.5g F41.67g | ✅ |
| Water target: 70kg | 70 × 35 → 2450 → 2400 | 2400ml | ✅ |
| Water target: 55kg | 55 × 35 → 1925 → 1900 | 1900ml | ✅ |
| Full pipeline: male cutting, sedentary | All inputs | BMR=1668.75, TDEE=2002.5, Calories=1603 | ✅ |
| Full pipeline: female bulking, moderate | All inputs | BMR=1219.0, TDEE=1889.45, Calories=2289 | ✅ |

### 1.2 Recommendation Engine (`test/unit/recommendation_engine_test.dart`)

| Test Case | Expected |
|-----------|----------|
| Affordability: budget = cost → 0.0 | ✅ |
| Affordability: free food → 1.0 | ✅ |
| Affordability: cost exceeds budget → capped at 0.0 | ✅ |
| Affordability: half-price → 0.5 | ✅ |
| Affordability: zero budget divisor defaults to 1 | ✅ |
| Protein fit: exact match → 1.0 | ✅ |
| Protein fit: zero remaining defaults divisor to 1 | ✅ |
| Final score: perfect food = 0.85 | ✅ |
| Over-budget penalty: 0.25 applied | ✅ |
| Results sorted descending by score | ✅ |
| Max 10 results returned | ✅ |
| Dairy allergy excludes Dairy category | ✅ |
| Peanut allergy excludes name match | ✅ |
| Gluten allergy excludes Bread and Pastry | ✅ |
| Shellfish allergy excludes shrimp name | ✅ |
| No allergies → all foods returned | ✅ |
| Vegetarian excludes Meat and Seafood | ✅ |
| Halal excludes pork-related names | ✅ |
| Vegan excludes Meat, Seafood, Dairy, Egg | ✅ |
| Breakfast meal type scores 1.0 for cereals | ✅ |
| Non-breakfast food scores 0.5 | ✅ |
| Over-budget reason text | ✅ |
| Best value reason text | ✅ |

### 1.3 Validators (`test/unit/validators_test.dart`)

| Validator | Valid Cases | Invalid Cases |
|-----------|-------------|---------------|
| `isValidEmail` | user@example.com, user+tag@sub.example.com | missing @, no TLD, empty |
| `isValidPassword` | ≥6 chars | 5 chars, empty |
| `passwordsMatch` | identical | different, case mismatch |
| `isValidNickname` | 2–30 chars trimmed | 1 char, 31 chars, whitespace only |
| `isValidAge` | 13–80 | 12, 81, 0 |
| `isValidHeight` | 100.0–250.0 | 99.0, 251.0 |
| `isValidWeight` | 20.0–300.0 | 19.0, 301.0 |
| `isValidBudget` | ≥20 | 19, 0 |
| `isValidWaterAmount` | 1–5000 | 0, 5001 |
| `isValidQuantity` | >0 | 0, negative |
| `isPositiveNumber` | >0 | 0, negative |

### 1.4 Date Helper (`test/unit/date_helper_test.dart`)

| Test | Expected |
|------|----------|
| `nowUtc` format | ISO 8601 ending with Z |
| `todayDate` format | yyyy-MM-dd |
| `parseDate` valid | Non-null DateTime |
| `parseDate` invalid | Null |
| `formatDateTime` | "Jun 13, 2026 2:30 PM" |
| `formatDate` | "Jun 13, 2026" |
| `formatTime` | "8:05 AM" |
| `daysBetween` same day | 0 |
| `daysBetween` 7 days | 7 |
| `daysBetween` reversed | 7 (absolute) |
| `weekStart` Saturday → Monday | Previous Monday |
| `weekEnd` Saturday → Sunday | Following Sunday |

### 1.5 Macro Bar / Scaling (`test/unit/macro_bar_scaling_test.dart`)

| Formula | Input | Expected |
|---------|-------|----------|
| `scaleNutrient(53, 2)` | 53g × 2 servings | 106g |
| `scaleNutrient(53, 0.5)` | 53g × 0.5 servings | 26.5g |
| `scaleCalories(284, 3)` | 284 × 3 | 852 |
| `scaleCost(55, 1.5)` | ₱55 × 1.5 | ₱82.50 |
| `progressRatio(50, 100)` | 50/100 clamped | 0.5 |
| `progressRatio(150, 100)` | 150/100 clamped | 1.0 |
| `progressRatio(50, 0)` | Target = 0 | 0.0 |
| `reverseScaleServing(106, 53)` | 106/53 | 2.0 |

---

## 2. SQLite Tests (`test/sqlite/migration_test.dart`)

### 2.1 Schema Creation
- Verify all 19 tables created
- Verify all 13 indexes created
- Verify idempotent re-run does not error

### 2.2 CRUD Operations
| Entity | Operations |
|--------|------------|
| `profiles` | Insert, read, update nickname/weight, delete |
| `meal_logs` | Insert multiple, query by date, soft delete |
| `foods` | Search by name, partial search, category filter, active official query |
| `water_logs` | Insert, query by date, sum total for day |
| `weight_logs` | Insert, query by date range |
| `sync_queue` | Insert, query pending items |

### 2.3 Constraint Enforcement
- Foreign key violation when referencing non-existent `user_id` → `DatabaseException`

---

## 3. RLS Tests (Manual — Supabase Console)

### 3.1 Two-User Isolation Test

| Step | Action | Expected |
|------|--------|----------|
| 1 | User A logs in and creates 3 meal logs | 3 rows visible |
| 2 | User B logs in and queries meal_logs table | 0 rows from User A |
| 3 | User B creates 2 meal logs | 2 rows visible to B |
| 4 | User A queries again | Still only 3 rows |

### 3.2 Admin Access Test

| Step | Action | Expected |
|------|--------|----------|
| 1 | Admin user (role_code = 'admin') queries all profiles | Can see all |
| 2 | Regular user queries all profiles | Can only see own row |
| 3 | Admin hides a community post | Post hidden globally |
| 4 | Non-admin tries to hide a post | Permission denied |

---

## 4. Integration Tests (Flutter)

### 4.1 Onboarding → Profile Creation

| Step | Description |
|------|-------------|
| 1 | Launch app for first time |
| 2 | Walk through all onboarding screens |
| 3 | Accept medical disclaimer |
| 4 | Complete profile setup |
| 5 | Verify profile saved in SQLite `profiles` table |
| 6 | Verify `onboarding_completed = 1` |

### 4.2 Meal Logging Flow

| Step | Description |
|------|-------------|
| 1 | Navigate to meal log screen |
| 2 | Search for food "Chicken Breast" |
| 3 | Select food, set quantity=1.5 |
| 4 | Save meal log |
| 5 | Verify row in SQLite `meal_logs` with scaled values |

### 4.3 Recommendation Flow

| Step | Description |
|------|-------------|
| 1 | Complete profile with budget=300 and goal=cutting |
| 2 | Navigate to recommendations |
| 3 | Verify scored food list returned |
| 4 | Verify items sorted by `finalScore` descending |
| 5 | Verify over-budget items penalized |

---

## 5. Offline Tests

| Test | Procedure | Expected |
|------|-----------|----------|
| Offline meal log | Airplane mode → log meal → reconnect | Log synced to Supabase via sync queue |
| Offline water log | Airplane mode → log water → reconnect | Synced after reconnect |
| Offline profile edit | Airplane mode → edit profile → reconnect | Profile updated on server |
| Conflict resolution | Edit same field offline & online → sync | Conflict resolver picks latest `updated_at` |
| Sync queue retry | Force sync failure → verify retry count | `attempt_count` incremented |

---

## 6. AI Feature Tests

### 6.1 AI Food Scanner

| Test | Expected |
|------|----------|
| Camera opens and captures image | Photo taken |
| Image sent to /api/scan | 200 OK |
| Prediction returned with confidence scores | Top-5 predictions |
| User confirms correct prediction | Meal log created |
| User rejects and enters correction | Correction saved to `ai_scan_feedback` |

### 6.2 AI Chatbot

| Test | Expected |
|------|----------|
| Send message | Response received |
| Safety disclaimer shown on first message | "I am an AI assistant and not a medical professional" |
| Suggested prompts displayed | 3–5 context-relevant prompts |
| Chat history persisted | Messages saved to `chat_messages` |

---

## 7. Performance Tests

| Scenario | Target |
|----------|--------|
| App cold start | < 3 seconds |
| Meal log screen with 50 logs | Scroll at 60fps |
| Food search across 500 foods | Results in < 500ms |
| Sync queue with 100 pending items | Processed in < 10s |
| Recommendation engine with 200 foods | Returns top 10 in < 200ms |

---

## 8. User Acceptance Testing (UAT) Checklist

| # | Test Scenario | P/F |
|---|---------------|-----|
| 1 | User can register with email/password | ☐ |
| 2 | User can complete onboarding with profile, budget, allergies | ☐ |
| 3 | Medical disclaimer must be accepted before proceeding | ☐ |
| 4 | BMR, TDEE, calorie target, macros, water calculated correctly | ☐ |
| 5 | User can log a meal with search and quantity | ☐ |
| 6 | User can log water intake | ☐ |
| 7 | User can log weight | ☐ |
| 8 | Food recommendations respect budget and allergies | ☐ |
| 9 | Offline data syncs when connectivity returns | ☐ |
| 10 | User can view analytics dashboard | ☐ |
| 11 | User can edit profile settings | ☐ |
| 12 | AI scanner can identify food from photo | ☐ |
| 13 | Chatbot responds to nutrition questions | ☐ |
| 14 | Admin can manage food database | ☐ |
| 15 | Admin can moderate community posts | ☐ |

---

## Tools

| Tool | Purpose |
|------|---------|
| `flutter test` | Run all Dart unit/SQLite tests |
| `flutter test --coverage` | Generate coverage report |
| Supabase SQL Editor | Run manual RLS verification queries |
| FastAPI `/docs` | Test API endpoints |
| Postman / Insomnia | API integration tests |
