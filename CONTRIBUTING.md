# Contributing to JCG Fitness

Thanks for contributing. This project combines a Flutter client, a FastAPI service, and Supabase migrations, so changes should be small, reviewable, and safe to run in another developer's environment.

## Before you start

1. Check existing issues and documentation to avoid duplicate work.
2. Create a focused branch using the `user/<short-description>` convention.
3. Copy `.env.example` files to local `.env` files as needed. Never commit real credentials, tokens, keys, production data exports, or signing files.
4. Keep database changes in new, ordered files under `supabase/migrations/`; do not edit a migration that has already been applied to a shared environment.

## Development expectations

- Follow the existing architecture and naming conventions.
- Keep authorization checks in both the UI and the backend/database layer. Flutter route guards improve the experience; Supabase RLS remains authoritative.
- Prefer deterministic, testable behavior for nutrition calculations and sync workflows.
- Add or update tests whenever a behavior changes, especially for migrations, authentication, synchronization, and admin actions.
- Update documentation when setup, configuration, or user-facing behavior changes.

## Checks

Run the checks that apply to your changes before opening a pull request:

```powershell
# Flutter checks
Set-Location flutter_app
flutter analyze
flutter test

# Backend checks
Set-Location ..\backend
py -3.11 -m pytest -q
```

If you change database migrations, test them against a disposable local Supabase environment. Do not use `db reset` against a shared or production project.

## Pull requests

Use a clear title and include:

- What changed and why.
- Any schema, RLS, or environment changes.
- The commands you ran and their results.
- Screenshots or short recordings for user-interface changes when useful.
- Migration rollout or rollback notes for changes that affect shared data.

Keep pull requests focused. Do not mix unrelated refactors, generated artifacts, or local configuration with functional changes.

## Reporting security issues

Do not open a public issue for exposed credentials, authorization bypasses, or sensitive user-data concerns. Contact the maintainers privately with a concise description, affected area, reproduction steps, and suggested mitigation.
