# JCG Fitness

JCG Fitness is an offline-first, budget-aware nutrition tracking application built for Android. It pairs a Flutter mobile client with a FastAPI service and Supabase for authenticated cloud synchronization, governed data access, and administrative operations.

## Highlights

- Track meals, hydration, weight, and nutrition goals.
- Browse Filipino food data and receive budget-aware recommendations.
- Use an offline sync queue so core tracking remains usable with unreliable connectivity.
- Use AI-assisted food scanning and nutrition guidance through the FastAPI service.
- Moderate community content and manage food data, users, analytics, and audit records through a protected admin area.

## Architecture

| Area | Technology |
| --- | --- |
| Mobile app | Flutter, Dart, Riverpod, GoRouter |
| Local storage | SQLite / `sqflite` |
| API service | Python 3.11+, FastAPI |
| Cloud platform | Supabase Auth, Postgres, Storage, and Row Level Security |
| Database changes | Versioned SQL migrations in `supabase/migrations/` |

## Repository layout

```text
backend/       FastAPI application and API tests
flutter_app/   Flutter Android application and widget/database tests
supabase/      SQL migrations and Supabase configuration templates
docs/          Project, QA, and implementation documentation
```

## Prerequisites

- Flutter SDK compatible with `flutter_app/pubspec.yaml`
- Android Studio and an Android emulator or physical device
- Python 3.11 or later
- A Supabase project and CLI for cloud-backed feature development

## Local setup

Never commit real credentials. Copy the example environment files and fill them with values for your own local Supabase and API configuration.

### 1. Backend

```powershell
Set-Location backend
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn app.main:app --reload
```

### 2. Flutter app

```powershell
Set-Location flutter_app
Copy-Item .env.example .env
flutter pub get
flutter run
```

To target a specific emulator, use `flutter devices` to find its ID, then run:

```powershell
flutter run -d <device-id> --dart-define-from-file=.env
```

### 3. Database migrations

For local Supabase development, start the local stack and apply the migrations in `supabase/migrations/`. For a shared or production project, review migrations and Row Level Security policies before applying them through your approved deployment process.

```powershell
Set-Location supabase
supabase start
supabase db reset
```

## Admin access

Administrative routes are guarded in the app and enforced by Supabase Row Level Security and administrator RPCs. Assign roles through the approved Supabase administration workflow; do not expose service-role credentials in the Flutter app or commit them to this repository.

## Verification

Run checks from the appropriate project directory:

```powershell
# Flutter
Set-Location flutter_app
flutter analyze
flutter test

# Backend
Set-Location ..\backend
py -3.11 -m pytest -q
```

## Security

- Keep all `.env` files, signing keys, Firebase provider files, service-account files, certificates, and database dumps local.
- Commit sanitized `.env.example` templates only.
- Use least-privilege Supabase policies and verify RLS whenever a new admin capability is introduced.
- Report potential security issues privately to the maintainers; do not publish secrets or exploit details in public issues.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development, testing, and pull request expectations.

## License

Distributed under the [MIT License](LICENSE).
