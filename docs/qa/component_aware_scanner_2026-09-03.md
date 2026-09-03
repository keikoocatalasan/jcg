# Component-aware scanner implementation QA — 2026-09-03

## Scope

This release adds the production foundation for portion-aware, mixed-plate
food scanning. It does not claim that the current two-dish model is a
100-dish model or that the dataset is complete.

## Implemented

- FastAPI scan responses now include component roles, composition confidence,
  portion metadata, quality flags, and backward-compatible candidates.
- NVIDIA vision requests use a compact dish/rice/extras contract because the
  current provider integration cannot assume structured JSON output.
- Nutrition scaling is deterministic and uses catalog reference grams; vision
  output is never treated as the nutrition source of truth.
- Flutter scan results preserve separate ulam/rice components and catalog
  reference serving grams.
- Confirmation asks for grams when the matched catalog item has a measured
  serving weight, with 100 g, 150 g, 200 g, and one-serving presets.
- Camera preview runs throttled on-device inference and requires repeated
  stable frames; cloud analysis is limited to the final captured image.
- Local scan, prediction, component, and confirmation updates are queued for
  offline synchronization.
- Supabase production schema contains `ai_scan_component`, RLS policies,
  owner-scoped write policies, serving/reference gram columns, and a registered
  sync entity.

## Verification evidence

- Backend: `25 passed`.
- Flutter widget/database/unit tests: `200 passed`.
- Dart analyzer: no errors; existing informational lint/deprecation notices
  remain in the repository.
- Android release packaging: APK `89.7 MB`; AAB `83.2 MB`.
- Supabase SQL migration: succeeded in the authenticated JCG production
  project.
- Supabase verification: component table exists, RLS is enabled, and the
  `ai_scan_component` sync entity is present.
- Supabase REST exposure check for the component table: HTTP 200.
- Dataset audit: 101 classes checked; 101 incomplete and below the required
  real-image target; zero duplicate, provenance, or corruption errors.

## Release gate still outstanding

The 100-dish TFLite model must not be shipped until all registered classes and
the unknown class have approved, leakage-safe train/validation/test data and
the locked evaluation passes the configured accuracy gate. The current
two-dish model remains the safe fallback until then.
