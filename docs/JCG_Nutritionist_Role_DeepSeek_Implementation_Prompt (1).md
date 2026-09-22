# JCG Nutritionist Role — DeepSeek V4.1 Flash Implementation Prompt & Plan

> **Purpose:** Paste this entire document into DeepSeek V4.1 Flash while it has access to the JCG repository.  
> **Execution mode:** Audit the existing implementation first, then immediately implement/fix the Nutritionist role. Do not stop after analysis or provide only recommendations.

---

# MASTER IMPLEMENTATION PROMPT

You are working directly on the **JCG food-recognition and nutrition application**.

## 1. Application Context

JCG is a nutrition and fitness application with:

- **Flutter** mobile frontend.
- **FastAPI** backend hosted on **Render**.
- AI-based food-image recognition/scanning.
- NVIDIA is already used for food-image scanning.
- Users capture or upload an image of food.
- The scanner identifies the likely food.
- The **user manually enters the food weight in grams** after recognition.
- The application uses the selected food's stored nutrition values to calculate calories/macros for the entered weight.
- JCG has its own food catalog/database.
- JCG may already contain `USER`, `ADMIN`, `NUTRITIONIST`, or similar roles.
- A Nutritionist implementation may already exist, but its current behavior, permissions, pages, database structures, endpoints, or workflow may be incomplete or overly broad.

The goal is **NOT** to build a clinical telehealth system.

The Nutritionist's primary function in JCG must be:

> **Food and Nutrition Data Validator**

The Nutritionist verifies, corrects, documents, and maintains nutrition information used by the application's food-recognition and macro-calculation workflow.

The Nutritionist is **not another administrator** and must not receive unrestricted access to the application.

---

# 2. FIRST TASK — AUDIT THE EXISTING IMPLEMENTATION

Before changing anything, inspect the complete repository and understand how JCG currently works.

Do not assume file names, database technology, authentication provider, ORM, state-management library, or routing structure if the repository already defines them.

Inspect at minimum:

1. Authentication and registration flow.
2. Existing user model/schema.
3. Existing role enum / role storage.
4. Existing Nutritionist role and permissions.
5. Admin permissions.
6. Food database/catalog models.
7. Nutrition/macronutrient models.
8. Food scanner result flow.
9. How scanned foods are matched to food records.
10. How the user-entered grams are stored and validated.
11. How calories/macros are calculated from grams.
12. Existing reports/flagging features.
13. Existing audit/history mechanisms.
14. Existing backend route structure.
15. Existing Flutter screens/routes/navigation.
16. Existing middleware/dependencies for authentication and RBAC.
17. Existing database migrations.
18. Existing file/image upload mechanism.
19. Existing validation libraries.
20. Existing tests.

Search the repository for terms such as:

`nutritionist`, `dietitian`, `role`, `roles`, `permission`, `admin`, `food`, `nutrition`, `macro`, `calorie`, `protein`, `carbs`, `fat`, `grams`, `scan`, `scanner`, `recognition`, `report`, `verification`, `verified`, `review`, `auth`, `register`, `signup`, `profile`, `audit`, and relevant enum names.

## Audit requirement

Create a concise internal implementation map before editing:

- Current Nutritionist functionality.
- Current database entities involved.
- Current API endpoints involved.
- Current Nutritionist Flutter screens.
- What currently works correctly.
- What is missing.
- What violates the intended Nutritionist scope.
- What can be reused instead of rewritten.

Then **continue directly into implementation**.

Do not stop and ask the user to approve the plan unless a required secret, inaccessible third-party credential, or truly blocking external dependency prevents implementation.

---

# 3. CORE DESIGN DECISION

The Nutritionist role must be intentionally narrow.

## Nutritionist's main responsibility

The Nutritionist shall:

> Review the food catalog and validate whether the nutritional information used by JCG is reasonable, properly sourced, and suitable for the application's deterministic gram-based nutrient calculation.

The Nutritionist verifies the **underlying food record**, not every individual scan made by every user.

Example:

```text
Food:
Chicken Adobo

Canonical nutrition values:
Calories: xxx kcal / 100 g
Protein: xx g / 100 g
Carbohydrates: xx g / 100 g
Fat: xx g / 100 g

User enters:
150 g

System calculates:
value_per_100g × 150 / 100
```

The Nutritionist validates the canonical `per 100 g` values and their source.

The backend/application—not the Nutritionist manually—performs the mathematical scaling for a user's entered grams.

---

# 4. PROFESSIONAL ROLE AND ACCOUNT VALIDATION

A person must **not instantly receive active Nutritionist permissions merely by selecting "Nutritionist" during registration**.

Implement a credential-validation workflow.

Use existing account/user architecture wherever possible.

## Recommended Nutritionist account states

Use or adapt the following:

```text
PENDING
VERIFIED
REJECTED
SUSPENDED
```

If the application already has suitable status values, reuse them instead of creating redundant enums.

### Meaning

- `PENDING` — account submitted; professional credentials awaiting review.
- `VERIFIED` — professional verification completed and Nutritionist dashboard access granted.
- `REJECTED` — submitted credentials could not be verified; user may correct/resubmit where appropriate.
- `SUSPENDED` — Nutritionist access temporarily disabled without deleting historical review records.

Do not mix professional verification status with normal authentication status if the architecture already separates those concepts.

---

# 5. NUTRITIONIST REGISTRATION

Audit the current registration system first.

If the application already has Nutritionist registration, modify it rather than creating a duplicate registration flow.

A Nutritionist application should collect only information reasonably needed to establish professional identity.

## Required account fields

Use the existing user fields for:

- First name
- Last name
- Email
- Password / authentication credential
- Role request = `NUTRITIONIST`

## Nutritionist-specific fields

Add/reuse fields such as:

```text
profession
prc_license_number
prc_license_expiration_date
credential_document
verification_status
verification_submitted_at
verified_at
verified_by
rejection_reason
suspension_reason
```

Use names that match existing project conventions.

### `profession`

For the Philippine deployment, the expected regulated profession is:

```text
Nutritionist-Dietitian
```

Do not present arbitrary healthcare professions under the Nutritionist role.

---

# 6. PRC CREDENTIAL VERIFICATION WORKFLOW

The implementation must reflect that Nutritionist-Dietitian practice in the Philippines is regulated.

For the thesis implementation, use a **simple manual verification workflow**.

## Registration process

```text
Nutritionist registration
        ↓
Submit basic account information
        ↓
Submit PRC license number
        ↓
Submit PRC professional ID expiration date
        ↓
Upload credential proof if the existing upload architecture supports it
        ↓
Account becomes PENDING
        ↓
Admin reviews application
        ↓
Admin verifies professional identity using an appropriate official PRC verification source
        ↓
VERIFIED → Nutritionist dashboard enabled
or
REJECTED → applicant receives reason and may correct/resubmit
```

## Important implementation constraint

Do **not** invent an official PRC API.

Do not silently scrape PRC websites.

If the repository has no legitimate official API integration, make credential validation an **Admin-assisted manual verification process**.

The Admin review interface may contain a clear action such as:

```text
Verify credentials externally
```

and record:

- verification result
- verifier/admin
- verification date
- optional verification notes

Never claim the system performed an automated PRC verification if it did not.

---

# 7. REGISTRATION VALIDATIONS

Implement validation on both:

1. Flutter/client side for usability.
2. FastAPI/server side as the authoritative validation.

Never rely only on frontend validation.

Validate:

### Email

- Required.
- Valid email syntax.
- Normalize appropriately.
- Must be unique according to existing account rules.

### Password

Use the application's existing password/authentication policy.

Do not weaken existing authentication.

### Names

- Required.
- Trim whitespace.
- Reasonable maximum length.
- Prevent empty/whitespace-only values.

### PRC license number

- Required for Nutritionist registration.
- Trim whitespace.
- Store consistently.
- Prevent duplicate active Nutritionist profiles using the same license number.
- Do not guess a rigid numeric format if the current PRC data or existing app does not justify one.
- Use conservative length/character validation rather than inventing a false format.

### License expiration

- Required.
- Must parse as a legitimate date.
- A clearly expired credential must not become `VERIFIED`.
- If an already verified credential later expires, restrict professional actions until revalidated according to the implementation's status policy.

### Credential document

If supported:

- Accept only explicitly allowed file/image formats.
- Enforce file-size limits.
- Generate server-side filenames/keys.
- Do not trust the uploaded filename.
- Restrict access.
- Never expose credential documents as public URLs.
- Reuse the project's existing secure storage mechanism.

### Duplicate applications

Prevent accidental creation of multiple active verification applications for the same Nutritionist account.

### Verification status

Users must never be able to set:

```text
VERIFIED
SUSPENDED
verified_by
verified_at
```

through self-registration payloads.

Those are server-controlled/Admin-controlled fields.

---

# 8. MINIMIZE PERSONAL DATA

Do not collect unnecessary health, identity, or professional information simply because it could be collected.

For the current JCG Nutritionist role, the Nutritionist does **not need routine access to individual users'**:

- weight history
- BMI
- allergies
- dietary restrictions
- meal history
- private nutrition targets
- email addresses
- profile data
- health-related information

unless an existing feature has a clearly documented, necessary purpose and authorization.

The Nutritionist is validating the **food database**, not managing patients.

Use least-privilege access.

Professional credential files must not be visible to normal users or other Nutritionists.

---

# 9. ROLE-BASED ACCESS CONTROL

Enforce RBAC in the **backend**, not merely by hiding Flutter buttons.

Use the project's current authentication architecture.

A verified Nutritionist must pass both:

```text
authenticated == true
role == NUTRITIONIST
nutritionist_verification_status == VERIFIED
```

before protected professional endpoints/actions are allowed.

A pending/rejected/suspended Nutritionist must not bypass this restriction by calling APIs manually.

Return appropriate HTTP status codes and safe error responses.

Do not expose implementation details or sensitive data in authorization errors.

---

# 10. NUTRITIONIST DASHBOARD — REQUIRED MODULES

Keep the interface simple.

The main Nutritionist navigation should contain approximately:

```text
Dashboard
Food Reviews
Food Catalog
Reported Foods
Review History
Profile / Verification
```

If `Food Reviews` and `Food Catalog` are cleaner as one module in the current app architecture, they may be combined.

Do not add unrelated modules merely to make the dashboard appear larger.

---

# 11. DASHBOARD HOME

Create a concise professional dashboard.

## Summary cards

Useful cards include:

- Pending / unreviewed food records
- Foods currently in review
- Foods verified
- Foods needing revision
- Open reported-food issues

Optionally show:

- Reviews completed this week
- Credential expiration warning

Do not add vanity metrics with no operational value.

## Main dashboard content

Show:

### Priority review queue

Fields can include:

```text
Food
Current verification status
Source status
Reason queued
Last updated
Action
```

### Recent activity

Examples:

```text
Verified Chicken Adobo
Requested revision for Beef Tapa
Resolved nutrition-data report for ...
```

### Credential warning

If the professional credential is approaching expiration, show a warning.

If expired according to the app's verification policy, professional write/review actions must be restricted until revalidation.

---

# 12. FOOD REVIEW MODULE

This is the Nutritionist's most important module.

Provide:

- Search
- Filtering
- Sorting
- Pagination if necessary
- Review detail screen
- Source/evidence fields
- Current nutrition values
- proposed/corrected values
- decision
- reviewer note
- audit history

## Filters

At minimum:

```text
All
Unreviewed
In Review
Verified
Needs Revision
Rejected
Reported / Flagged
```

Adapt names if existing statuses already cover these concepts.

---

# 13. FOOD REVIEW DETAIL PAGE

The Nutritionist should see the information required to validate the food without being distracted by user-management data.

Recommended sections:

## Food identity

- Food name
- Alternate/common name if available
- Food category
- Food image if available
- Scanner/recognition label if relevant
- Existing aliases if used by the scanner-to-catalog mapping

## Canonical nutrition values

Prefer normalized nutrition values stored as:

```text
per 100 g edible portion
```

At minimum:

- Energy / calories
- Protein
- Carbohydrates
- Fat

If JCG already supports additional nutrients, preserve and expose them where appropriate, such as:

- Fiber
- Sugar
- Sodium
- Cholesterol
- saturated fat
- micronutrients

Do not invent additional required nutrients that would break existing data.

## Source/evidence

Display:

- source type
- source name
- source reference
- date checked
- optional source notes

Example source types:

```text
DOST-FNRI PhilFCT
Manufacturer nutrition label
Other recognized food-composition source
Recipe-based estimate
Internal legacy record
Unknown / source missing
```

Use the project's real data and avoid falsely claiming that a source is authoritative.

## Current status

Display a clear status badge.

---

# 14. FOOD VERIFICATION STATUSES

Prefer a controlled state machine.

Example:

```text
UNREVIEWED
IN_REVIEW
VERIFIED
NEEDS_REVISION
REJECTED
ARCHIVED
```

If the application already has compatible statuses, reuse them.

Avoid duplicated status systems.

## State behavior

### UNREVIEWED
Food exists but has not been reviewed.

### IN_REVIEW
A Nutritionist has begun reviewing it.

### VERIFIED
The nutrition record was checked and accepted for use.

Store:

```text
verified_by
verified_at
source information
review note if applicable
```

### NEEDS_REVISION
Data is incomplete, inconsistent, unsupported, or requires correction.

Require a reason.

### REJECTED
Use when the record should not be treated as a valid canonical food entry.

Require a reason.

### ARCHIVED
Use instead of destructive deletion for canonical historical data.

---

# 15. CRUD — EXACT NUTRITIONIST CAPABILITIES

The application needs CRUD behavior, but Nutritionist CRUD must apply only to the Nutritionist's professional scope.

## CREATE

A verified Nutritionist may:

- Create a new food/nutrition record or draft if the current catalog architecture allows professional food creation.
- Add an alternate food/source proposal.
- Create a food review.
- Create a correction proposal.
- Create a source/evidence record.
- Create review notes.

New foods should normally begin as:

```text
UNREVIEWED
```

or an equivalent draft/review status rather than silently becoming trusted production data.

If the creator is a verified Nutritionist and the existing business rules permit self-review, the app may allow them to complete a proper verification workflow afterward, but the action must still be audited.

## READ

A verified Nutritionist may read:

- Food catalog.
- Nutrition facts necessary for verification.
- Food source/evidence information.
- Food reports related to incorrect recognition/nutrition values.
- Review queue.
- Their own and authorized review history.
- Aggregate dashboard counts.

They must not receive broad user account/profile access.

## UPDATE

A verified Nutritionist may update nutrition-domain data such as:

- canonical nutrition values
- food display name where appropriate
- nutrition source/evidence
- source notes
- verification status
- review decision
- professional review note
- selected food metadata relevant to correct identification

Every meaningful change to a verified/canonical nutrition record must be auditable.

Do not silently overwrite verified values without preserving who changed them and when.

## DELETE

Use conservative deletion rules.

A Nutritionist must **not hard-delete production food history**.

Preferred behavior:

- Nutritionist may delete/cancel their own unfinished review draft if appropriate.
- Nutritionist may archive an invalid/duplicate food entry if authorized by the business rules.
- Canonical records with existing scan/log references should be soft-deleted/archived.
- Review/audit history must remain intact.

If existing foreign keys or application logic make deletion unsafe, implement archive/soft-delete instead of destructive deletion.

---

# 16. NUTRITION VALIDATION RULES

Nutritionist review is professional judgment, but the application should provide deterministic validation assistance.

Validation checks should produce warnings/errors without pretending they replace a professional review.

## Required numerical validation

For nutrition fields:

- Numeric where required.
- Not `NaN`.
- Not infinite.
- Not negative unless the project's schema explicitly uses a special sentinel value.
- Use nullable values for unknown nutrients rather than fake zero values when the distinction matters.

## Core macros

At minimum ensure:

```text
calories >= 0
protein_g >= 0
carbohydrates_g >= 0
fat_g >= 0
```

## Per-100-g normalization

Prefer canonical values normalized to:

```text
per 100 g
```

If the application stores per-serving values, preserve compatibility but make the base/unit explicit.

Never mix `per serving` and `per 100 g` without unit metadata.

## Macro sanity flag

For a 100 g food record, if:

```text
protein + carbohydrates + fat
```

is implausibly greater than 100 g beyond a small rounding tolerance, flag the record for review.

Do not automatically reject solely from this heuristic because nutrition databases may use different definitions and rounding rules.

## Energy consistency flag

Optionally calculate an approximation:

```text
estimated_kcal = (protein_g * 4) + (carbohydrates_g * 4) + (fat_g * 9)
```

If stored calories differ substantially, show a **review warning**, not an automatic declaration that the source is wrong.

There can be legitimate differences because of:

- fiber
- alcohol
- organic acids
- database methodology
- rounding
- food-specific energy factors

Use this as a consistency check only.

---

# 17. GRAM-BASED CALCULATION RULE

The Nutritionist role must not change the core calculation into AI guessing.

The user manually enters food mass in grams.

Use deterministic scaling from canonical nutrition data.

For each nutrient:

```text
calculated_value =
    nutrient_per_100g * entered_grams / 100
```

Example:

```text
protein_per_100g = 20 g
entered_grams = 150 g

protein =
20 * 150 / 100
= 30 g
```

Server-side validation must verify the entered grams.

At minimum:

```text
grams > 0
```

Use a reasonable configurable maximum if the application already has one or add a conservative abuse-prevention limit that does not interfere with realistic food entries.

Do not allow:

- zero grams
- negative grams
- `NaN`
- infinity
- malformed numeric strings

Use appropriate decimal/rounding behavior consistent with the existing nutrition engine.

---

# 18. FOOD SOURCE VALIDATION

Every Nutritionist verification should encourage traceable data.

Recommended priority for Filipino foods:

1. DOST-FNRI Philippine Food Composition Tables (PhilFCT), when the food has an appropriate matching record.
2. Manufacturer nutrition label for a specific packaged/branded food.
3. Other recognized food-composition source where appropriate.
4. Recipe-based calculation/estimate for composite dishes when no direct authoritative entry applies.

Do not pretend a generic database value exactly represents every recipe.

For foods such as:

```text
adobo
sinigang
pancit
caldereta
homemade dishes
restaurant dishes
```

composition can vary by recipe.

If the value is recipe-based or approximate, represent that honestly in metadata, e.g.:

```text
source_type = RECIPE_ESTIMATE
```

rather than falsely marking the numerical source as an exact measured composition.

---

# 19. VERIFIED DOES NOT MEAN "HEALTHY"

Do not implement a simplistic binary:

```text
HEALTHY
UNHEALTHY
```

as the Nutritionist's main decision.

The Nutritionist is verifying the **accuracy and provenance of nutritional data**, not declaring foods universally healthy or unhealthy.

A food's suitability depends on:

- amount consumed
- overall dietary pattern
- individual goals
- medical context
- allergies
- dietary restrictions
- preparation
- frequency

The core review states should describe data quality:

```text
VERIFIED
NEEDS_REVISION
REJECTED
```

not moral/health labels.

If JCG already has a "healthy" indicator, do not silently remove it if other features depend on it. Instead inspect how it is calculated and separate that feature from the Nutritionist's factual nutrition-data verification.

---

# 20. REPORTED FOODS MODULE

Users should be able to flag obvious problems if such a feature exists or can be added without overengineering.

Examples:

```text
Wrong food identified
Incorrect calories/macros
Wrong serving/food data
Duplicate food
Missing food
Other food-data issue
```

The Nutritionist should see only the information needed to investigate the food-data issue.

Recommended report states:

```text
OPEN
IN_REVIEW
RESOLVED
DISMISSED
```

For each report show:

- reported food
- issue category
- user description if provided
- relevant scan/food reference
- created date
- current status

Avoid exposing unnecessary personal profile information about the reporter.

## Nutritionist actions

A Nutritionist may:

- open a report
- review the associated food
- mark it in review
- correct/verify the food data
- resolve the report
- dismiss clearly invalid reports with a reason

Do not allow Nutritionists to delete arbitrary user reports merely to remove them from the queue.

---

# 21. REVIEW HISTORY / AUDIT TRAIL

Implement or reuse an immutable-enough audit trail.

For each important Nutritionist action, record:

```text
actor_user_id
actor_role
action
entity_type
entity_id
previous_value / change summary
new_value / change summary
reason or note where applicable
timestamp
```

At minimum audit:

- nutrition value change
- verification decision
- source change
- status change
- archive action
- report resolution
- credential verification status change by Admin

Avoid logging:

- passwords
- authentication tokens
- raw secrets
- unnecessary credential-document contents

The Nutritionist should have a Review History page showing professional review actions.

Admin may have broader audit access according to existing permissions.

Normal users must not access these audit records.

---

# 22. NUTRITIONIST PROFILE MODULE

A verified Nutritionist may view:

- own name
- own email
- role
- PRC license number in an appropriately masked or controlled display
- professional verification status
- license expiration date
- verification date

Allow editing of normal safe profile fields according to existing account rules.

Changes to important professional fields such as license number should trigger re-verification rather than silently changing trusted credentials.

Example:

```text
Change PRC license number
        ↓
Verification status returns to PENDING
        ↓
Professional review actions disabled
        ↓
Admin verifies new credential
```

Apply equivalent logic to changed/replaced credential proof where appropriate.

---

# 23. ADMIN RESPONSIBILITIES FOR NUTRITIONIST ACCOUNTS

Nutritionist verification should belong to an existing Admin/Super Admin workflow.

Do not create a separate "Nutritionist Admin."

Admin should be able to:

- list Nutritionist applications
- view application details
- view professional verification fields
- verify
- reject with reason
- suspend with reason
- restore/reactivate if valid
- see credential expiration
- view relevant verification history

Admin should **not** need to manually manage every food review.

That is the Nutritionist's domain.

---

# 24. NUTRITIONIST HARD LIMITATIONS

A Nutritionist must **NOT** automatically receive permission to:

- Create Admin accounts.
- Create arbitrary system roles.
- Change another user's role.
- Delete normal users.
- Suspend normal users.
- Reset other users' passwords.
- View authentication secrets.
- View tokens.
- Change global system settings.
- Change environment variables.
- Change backend configuration.
- Modify API keys.
- Modify NVIDIA scanner credentials.
- Change AI provider configuration.
- Train/deploy/replace the food-recognition model.
- Modify application source code from the dashboard.
- Modify system security settings.
- Modify database infrastructure.
- Manage subscriptions/payments unless an unrelated existing role explicitly authorizes it.
- Access all users' private meal logs.
- Access all users' weight history.
- Access all users' health profiles.
- Change a user's targets without an explicitly designed clinical workflow.
- Alter a user's historical meal records.
- Diagnose medical conditions.
- Prescribe medication.
- Prescribe treatment.
- Represent automated outputs as medical diagnosis.
- Perform clinical medical-nutrition treatment through this simple validation role.
- Override Admin security controls.
- Hard-delete audit history.
- Mark their own unverified professional account as verified.

If existing Nutritionist code currently grants any of these privileges only because it shares Admin permissions, fix the RBAC.

---

# 25. NO CLINICAL MODULE IN THIS IMPLEMENTATION

Keep this implementation intentionally limited.

Do not introduce:

- patient consultation scheduling
- medical diagnosis
- disease treatment
- clinical charting
- prescriptions
- medical nutrition therapy plans
- doctor referrals
- private patient consultation records

unless those features already exist as explicit approved JCG requirements.

The thesis feature being implemented here is:

> professional validation of the food/nutrition database used by the food-recognition application.

---

# 26. DATABASE / MODEL PLAN

First inspect the existing schema and extend it minimally.

Do not create duplicate tables if equivalent models already exist.

A likely logical model is shown below, but adapt it to the real codebase.

## NutritionistProfile

Potential fields:

```text
id
user_id
prc_license_number
prc_license_expiration_date
verification_status
credential_document_key
submitted_at
verified_at
verified_by
rejection_reason
suspension_reason
created_at
updated_at
```

## Food / FoodNutrition

Reuse the existing food model.

Potential additional verification metadata:

```text
verification_status
nutrition_source_type
nutrition_source_name
nutrition_source_reference
source_checked_at
verified_by
verified_at
archived_at
```

Only add fields genuinely needed.

## FoodNutritionReview

Potential fields:

```text
id
food_id
nutritionist_user_id
status
decision
review_note
source_type
source_name
source_reference
previous_values
proposed_values
created_at
updated_at
completed_at
```

If the existing audit system already preserves changes, avoid duplicating large before/after JSON blobs unnecessarily.

## FoodReport

Reuse an existing user-report model where possible.

Potential fields:

```text
id
food_id
reporter_user_id
issue_type
description
status
reviewed_by
resolution_note
created_at
resolved_at
```

Protect reporter identity in Nutritionist-facing serialization unless needed.

## AuditLog

Reuse existing auditing if present.

Do not invent an entirely separate audit framework if the application already has one.

---

# 27. DATABASE CONSTRAINTS

Where appropriate, enforce constraints at the database/model layer in addition to API validation.

Examples:

- one Nutritionist profile per user
- unique professional license number where appropriate
- valid controlled verification statuses
- required foreign keys
- timestamps
- safe cascade behavior
- preserve historical reviews if user/account status changes

Avoid destructive cascade deletion of professional review history when a Nutritionist account is disabled.

Use migrations compatible with the project's current migration system.

Do not reset the database.

Do not drop existing production data.

Do not rewrite migration history that has already been applied.

---

# 28. BACKEND API PLAN

Follow existing FastAPI conventions.

Do not create duplicated route styles if the project already has established routers/services/repositories.

The following is a logical API design only.

## Nutritionist dashboard

```http
GET /nutritionist/dashboard
```

Return aggregate counts and recent relevant activity only.

## Food review queue

```http
GET /nutritionist/reviews
GET /nutritionist/reviews/{review_id}
POST /nutritionist/reviews
PATCH /nutritionist/reviews/{review_id}
```

Use existing REST conventions.

## Nutritionist food catalog

```http
GET /nutritionist/foods
GET /nutritionist/foods/{food_id}
POST /nutritionist/foods
PATCH /nutritionist/foods/{food_id}
DELETE /nutritionist/foods/{food_id}
```

For `DELETE`, implement archive/soft-delete where required.

Do not necessarily duplicate public `/foods` endpoints if existing endpoints can be protected and extended cleanly.

## Reports

```http
GET /nutritionist/reports
GET /nutritionist/reports/{report_id}
PATCH /nutritionist/reports/{report_id}
```

## Profile

```http
GET /nutritionist/profile
PATCH /nutritionist/profile
```

## Admin Nutritionist verification

Conceptually:

```http
GET /admin/nutritionist-applications
GET /admin/nutritionist-applications/{id}
PATCH /admin/nutritionist-applications/{id}/verify
PATCH /admin/nutritionist-applications/{id}/reject
PATCH /admin/nutritionist-applications/{id}/suspend
```

Adapt this to existing Admin routes.

Do not introduce endpoint proliferation if a clean generic Admin verification endpoint already exists.

---

# 29. API SECURITY REQUIREMENTS

For every endpoint:

- Authenticate on backend.
- Authorize by role/status on backend.
- Validate input using the project's schema system.
- Return only fields the caller needs.
- Never trust a role submitted by the client.
- Never trust `verified_by`, `verified_at`, status, or ownership fields submitted by the client.
- Prevent mass-assignment vulnerabilities.
- Do not expose stack traces to clients.
- Use safe error messages.
- Preserve the existing authentication design.
- Do not break normal USER or ADMIN endpoints.

Use shared FastAPI dependencies/middleware for authorization where possible instead of repeating fragile role checks.

Example conceptual guard:

```python
require_verified_nutritionist()
```

but use the project's naming and dependency style.

---

# 30. FLUTTER UI PLAN

First inspect existing UI patterns and design system.

Do not create a completely different visual language for Nutritionist screens.

Reuse:

- typography
- cards
- buttons
- form controls
- colors/theme
- loading components
- error handling
- empty states
- routing/navigation
- state management

## Required Nutritionist screens

At minimum:

```text
Nutritionist Registration / Application
Nutritionist Verification Status
Nutritionist Dashboard
Food Reviews / Food Catalog
Food Review Detail/Edit
Reported Foods
Report Detail
Review History
Nutritionist Profile
```

Admin should also receive/update:

```text
Nutritionist Applications
Nutritionist Application Detail
```

if those screens do not already exist.

---

# 31. NUTRITIONIST REGISTRATION UI

The role-specific application form should clearly explain:

```text
Nutritionist accounts require professional verification before professional features become available.
```

Do not state that verification is automated unless it actually is.

After registration:

```text
Application submitted
Status: Pending Verification
```

Do not redirect an unverified Nutritionist into an active professional dashboard.

Create a status screen with:

- status
- submitted date
- basic credential summary
- rejection reason if rejected
- resubmission action where appropriate

Do not expose Admin-only notes unnecessarily.

---

# 32. FOOD CATALOG UI

Create a useful table/list.

Suggested columns:

```text
Food
Category
Calories / 100 g
Protein
Carbs
Fat
Source
Verification Status
Last Reviewed
Action
```

On small mobile screens, use the project's responsive/mobile patterns rather than forcing a desktop table.

Provide:

- search
- filters
- status filter
- source filter if useful
- pagination/infinite loading according to existing architecture

---

# 33. FOOD EDIT / REVIEW UI

Clearly separate:

1. current data
2. proposed/new data
3. validation warnings
4. source information
5. decision

Use confirmation for impactful actions such as:

```text
Verify food
Reject food
Archive food
```

Require a reason for:

```text
Needs Revision
Rejected
Archive
```

Do not make routine verification excessively cumbersome.

---

# 34. SOURCE RECORDING UI

At verification time, make the Nutritionist provide or confirm:

```text
Source type
Source name/reference
Date checked
```

Where a source URL/reference is supported, validate length and safe text handling.

Do not fetch arbitrary URLs server-side merely because a Nutritionist pasted one; this can create SSRF/security risks.

Treat a reference as metadata unless a safe integration is deliberately implemented.

---

# 35. SCANNER INTEGRATION BOUNDARY

Do not rewrite the NVIDIA scanner.

The Nutritionist role is not an AI engineering role.

The scanner's job:

```text
Image → likely food identity
```

The food catalog's job:

```text
Food identity → canonical nutrient values
```

The user supplies:

```text
grams
```

The nutrition calculator produces:

```text
scaled calories/macros
```

The Nutritionist validates:

```text
canonical food/nutrition values + source
```

These responsibilities must remain separated.

If a report indicates that recognition frequently maps to the wrong food, the Nutritionist may flag the food/mapping for technical review, but should not receive model-training/deployment controls.

---

# 36. BACKWARD COMPATIBILITY

Do not break:

- existing users
- existing Admin accounts
- existing food records
- existing scanner
- existing meal logging
- existing nutrition calculations
- existing API clients
- existing authentication
- existing deployed Render configuration

If existing Nutritionist records already exist:

- migrate them safely.
- do not blindly mark every old Nutritionist as verified.
- preserve current data.
- choose a safe migration/default status and document it.

If existing accounts already have professional verification metadata, reuse it.

---

# 37. PERFORMANCE

Keep this simple.

Avoid:

- loading the entire food catalog at once
- N+1 review queries
- fetching full audit histories for dashboard cards
- fetching credential documents in normal lists
- loading private user records into Nutritionist endpoints

Use:

- paginated queries
- indexed status/food lookup fields where justified
- aggregate queries for dashboard counts
- lightweight list serializers
- detail serializers only when needed

---

# 38. ERROR, LOADING, AND EMPTY STATES

Every Nutritionist page must handle:

- loading
- API error
- empty result
- unauthorized
- suspended account
- pending verification
- expired/revalidation-required credential
- network failure

Do not leave blank pages.

Do not expose raw backend exception text.

---

# 39. TESTING REQUIREMENTS

Add/update tests according to the project's testing architecture.

## Authentication / RBAC

Test:

- normal USER cannot access Nutritionist endpoints.
- pending Nutritionist cannot perform verified Nutritionist actions.
- rejected Nutritionist cannot perform them.
- suspended Nutritionist cannot perform them.
- verified Nutritionist can access permitted endpoints.
- Nutritionist cannot access Admin-only user/role management.
- Nutritionist cannot verify their own professional application.

## Registration

Test:

- missing required professional fields.
- duplicate email.
- duplicate license where applicable.
- malformed/invalid expiration date.
- expired credential cannot be approved as current.
- client cannot submit `verification_status=VERIFIED` to self-approve.
- resubmission workflow works.

## Food validation

Test:

- negative nutrient values rejected.
- malformed values rejected.
- unknown optional nutrients handled properly.
- verification stores reviewer and timestamp.
- reason required for rejection/revision where specified.
- archived records remain historically traceable.

## Gram calculation

Test deterministic scaling.

Example:

```text
100 g → 20 g protein
150 g → 30 g protein
```

Test:

- zero grams
- negative grams
- decimals
- realistic valid values
- maximum boundary
- rounding

## Reports

Test:

- Nutritionist can resolve a food-data report.
- Nutritionist cannot obtain unnecessary reporter/private profile data.
- resolved report is auditable.

## Audit

Test that:

- nutrition changes produce history.
- verification decisions produce history.
- credential status changes produce history.
- secrets are not recorded.

---

# 40. ACCEPTANCE CRITERIA

Do not consider the work complete until the following behavior exists.

## Registration

```text
Nutritionist registers
→ professional information required
→ status PENDING
→ cannot access active professional tools
→ Admin reviews
→ Admin verifies or rejects
→ VERIFIED account receives Nutritionist functionality
```

## Nutrition verification

```text
Verified Nutritionist opens Food Reviews
→ selects food
→ reviews nutrition per 100 g
→ reviews source
→ corrects values if necessary
→ records source
→ chooses VERIFIED / NEEDS_REVISION / REJECTED
→ action stored with reviewer and timestamp
→ audit/history updated
```

## Normal user scan

```text
User captures food image
→ scanner identifies food
→ app matches catalog food
→ user enters grams
→ app calculates nutrient values deterministically
→ nutrition data originates from catalog record
→ verification metadata may be displayed if the UX supports it
```

## Reported data

```text
User flags inaccurate food/nutrition data
→ report enters queue
→ verified Nutritionist reviews
→ corrects/verifies/dismisses with reason
→ report resolved
→ audit trail preserved
```

## Security

```text
Nutritionist cannot become Admin
Nutritionist cannot manage roles
Nutritionist cannot change AI configuration
Nutritionist cannot access arbitrary users' private nutrition/health data
Nutritionist cannot self-verify
Nutritionist cannot bypass suspended/pending state through API calls
```

---

# 41. IMPLEMENTATION ORDER

Execute in this order unless repository dependencies justify a slight change:

## Phase 1 — Inspect

- Map auth/RBAC.
- Map current Nutritionist behavior.
- Map food/nutrition schemas.
- Map scanner → food → grams → macro flow.
- Map Admin capabilities.
- Identify reusable components.

## Phase 2 — Data model

- Add/normalize Nutritionist verification profile/status.
- Add minimal food verification metadata.
- Add/reuse review/history/report models.
- Create safe migrations.

## Phase 3 — Backend security

- Add verified-Nutritionist authorization dependency.
- Fix excessive existing Nutritionist privileges.
- Protect endpoints server-side.

## Phase 4 — Registration verification

- Nutritionist application.
- Pending status.
- Admin verify/reject/suspend.
- Revalidation behavior.

## Phase 5 — Food CRUD/review

- Catalog list/detail.
- Create.
- Update.
- Archive instead of unsafe hard deletion.
- Source tracking.
- Verification state machine.

## Phase 6 — Reports

- Food-report queue.
- Review.
- Resolve/dismiss.
- Audit.

## Phase 7 — Dashboard

- Relevant counts.
- priority queue.
- recent professional activity.
- credential status warning.

## Phase 8 — Flutter UI

- Registration/status.
- Nutritionist navigation.
- Dashboard.
- Food review/catalog.
- Reports.
- History.
- Profile.
- Admin credential review.

## Phase 9 — Tests

- RBAC.
- Registration.
- CRUD.
- status transitions.
- validation.
- gram calculations.
- privacy restrictions.
- audit.

## Phase 10 — Final verification

Run:

- formatter
- linter
- type/static checks
- backend tests
- Flutter tests where present
- build checks practical for the repository

Fix introduced errors.

---

# 42. CODE QUALITY RULES

While implementing:

- Preserve the project's architecture.
- Prefer small reusable services/components.
- Do not duplicate authorization logic.
- Do not duplicate models.
- Do not rewrite unrelated features.
- Do not refactor the entire application without necessity.
- Do not introduce a new framework.
- Do not replace the current database.
- Do not replace the scanner.
- Do not change the chatbot provider while doing this task.
- Do not hardcode secrets.
- Do not commit API keys.
- Do not introduce mock production verification that claims to be real.
- Keep functions focused.
- Use typed request/response schemas.
- Reuse constants/enums.
- Use transactional updates for multi-step state changes where supported.
- Preserve auditability.
- Use server timestamps for trusted actions.
- Avoid trusting client-provided ownership or reviewer IDs.

---

# 43. IMPORTANT PRODUCT LANGUAGE

Use wording such as:

```text
Nutrition Data Verified
Nutrition Review
Needs Revision
Source
Reviewed By
Reviewed On
Professional Verification
Pending Verification
```

Avoid misleading wording such as:

```text
100% Healthy
Doctor Approved
Medically Safe
AI Certified
PRC Automatically Verified
Guaranteed Accurate
```

unless the exact statement is factually supported—which it normally will not be.

---

# 44. REGULATORY / PROFESSIONAL BASIS

Use these principles when designing the role:

## Philippine Nutrition and Dietetics Law

Republic Act No. 10862 regulates the practice of nutrition and dietetics in the Philippines and defines a Nutritionist-Dietitian as a registered and licensed person holding a valid certificate of registration and professional identification card issued through the relevant professional regulatory framework.

The law's scope includes food/nutrition services, standards, research, education, nutrition systems, and medical nutrition therapy.

For **JCG**, deliberately implement only the narrow food/nutrition-data validation component needed by the application rather than trying to reproduce the entire professional scope.

Reference:

- Republic Act No. 10862 — Nutrition and Dietetics Law of 2016  
  https://lawphil.net/statutes/repacts/ra2016/ra_10862_2016.html

## PRC license verification

PRC provides an online professional license verification service, including verification by name and by license number.

For JCG, treat this as a basis for a **manual Admin verification workflow** unless a legitimate supported API is actually available.

Reference:

- PRC Online Verification  
  https://verification.prc.gov.ph/

Do not build an undocumented scraper and call it an API integration.

## Philippine Food Composition Tables

DOST-FNRI's Philippine Food Composition Tables (PhilFCT) provides nutrition composition information for commonly consumed Philippine foods.

Use it as a preferred reference where an appropriate food record exists, but do not automatically assume that a generic PhilFCT food record exactly matches every restaurant/home recipe.

References:

- DOST-FNRI PhilFCT  
  https://i.fnri.dost.gov.ph/login/fct
- DOST-FNRI PhilFCT Library  
  https://i.fnri.dost.gov.ph/fct/library

## Data Privacy

Apply data minimization and access control to professional credentials and user information.

Reference:

- Republic Act No. 10173 — Data Privacy Act of 2012  
  https://privacy.gov.ph/data-privacy-act/

This implementation is software design guidance for the thesis/application and should not falsely claim legal certification or regulatory approval.

---

# 45. FINAL OUTPUT REQUIRED FROM YOU AFTER IMPLEMENTATION

After modifying the repository, provide a concise implementation report with:

## A. Existing Nutritionist role found

State:

- what existed
- what was reused
- what was unsafe/incomplete
- what was changed

## B. Files changed

List actual file paths grouped by:

- backend
- database/migrations
- Flutter
- tests

## C. Database changes

Describe the exact tables/columns/enums/migrations created or changed.

## D. Nutritionist registration workflow

Explain the final state transition:

```text
REGISTERED → PENDING → VERIFIED / REJECTED / SUSPENDED
```

using the actual implemented enum/status names.

## E. Final Nutritionist permissions

State exact CRUD permissions and restricted capabilities.

## F. Dashboard/modules completed

State which screens/routes are now available.

## G. API endpoints

List actual implemented endpoints.

## H. Validation implemented

List:

- credential validation
- nutrition numeric validation
- grams validation
- source validation
- status-transition validation
- backend RBAC

## I. Tests/checks

Report which tests/build/lint checks were run and their results.

Do not say something was tested if it was not run.

## J. Remaining limitations

Clearly identify anything that could not be completed because of an external dependency.

---

# 46. FINAL PRODUCT DEFINITION

When finished, the intended JCG Nutritionist role should be summarized as:

> **The JCG Nutritionist is a verified professional role responsible for reviewing and maintaining the accuracy, source traceability, and verification status of food nutrition data used by the application's image-recognition and gram-based macro calculation workflow. The role has nutrition-specific CRUD and review capabilities but does not receive general system administration, AI configuration, user-management, or unrestricted access to users' private health and meal information.**

This is the scope to implement.

---

# 47. START NOW

Proceed now.

1. Inspect the existing repository.
2. Identify the current Nutritionist implementation.
3. Reuse all correct existing work.
4. Fix excessive or missing permissions.
5. Implement credential verification.
6. Implement Nutritionist-specific CRUD.
7. Implement the dashboard/modules.
8. Implement validation and auditability.
9. Implement Admin verification controls.
10. Implement tests.
11. Run available checks.
12. Return the final implementation report.

Do not stop after writing another plan. Make the code changes.
