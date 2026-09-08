# JCG Fitness

JCG Fitness is an offline-first, budget-aware nutrition tracking application built for Android. It pairs a Flutter mobile client with a FastAPI service and Supabase for authenticated cloud synchronization, governed data access, and administrative operations.

## Highlights

- Track meals, hydration, weight, and nutrition goals.
- Browse Filipino food data and receive budget-aware recommendations.
- Use an offline sync queue so core tracking remains usable with unreliable connectivity.
- Use AI-assisted food scanning and nutrition guidance through the FastAPI service.
- Moderate community content and manage food data, users, analytics, and audit records through a protected admin area.

## Public download

The current Android release is available from the [JCG Fitness landing page](https://nutrismart-ai-sce8.onrender.com/). The universal download follows GitHub's `latest` release redirect. The page also offers a same-origin resumable ARM64 route for large-download failures; update that mirrored APK whenever the fallback release changes.

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

For a local defense walkthrough, use the isolated demo identity and keep the
backend on a dedicated port if another local service already uses 8000:

```powershell
$env:JCG_DEVICE_ID = "emulator-5554" # or the physical device ID
$env:JCG_BACKEND_PORT = "8001"
$env:JCG_FASTAPI_BASE_URL = "http://10.0.2.2:8001"
$env:JCG_APP_ENV = "development"
$env:JCG_DEV_BYPASS_AUTH = "true"
$env:JCG_LIVE_PREVIEW = "false" # enable only for bounded live hints
# From the repository root, run the backend in one terminal:
.\run_backend.ps1
# In a second terminal, keep the same environment values and run:
.\run_flutter.ps1
```

`JCG_DEV_BYPASS_AUTH` is compile-time, visible as `LOCAL QA`, and rejected in
release/production builds. It must never be used for a production APK.

The chatbot can inherit the existing server-side provider or use Groq
independently with `CHAT_MODEL_PROVIDER=groq`, `CHAT_MODEL_API_KEY`,
`CHAT_MODEL_NAME`, and `GROQ_BASE_URL`. Keep those values on the backend; do
not put a Groq key in Flutter or source control.

For a production Android build, use the ignored `flutter_app/.env` file with
the Render HTTPS API and `APP_ENV=production`, or start from
`flutter_app/.env.production.example`:

```powershell
flutter build apk --release --dart-define-from-file=.env
flutter build appbundle --release --dart-define-from-file=.env
```

### Updating the downloadable APK

The landing page uses GitHub's `releases/latest` redirect, so it does not need
to be edited for every app update. Increase the version and Android build
number in `flutter_app/pubspec.yaml`, run the test suite, then push a matching
version tag such as `v1.0.2`. The `.github/workflows/android-release.yml`
workflow is explicitly dispatched on that tag with
`gh workflow run android-release.yml --ref v1.0.2`; it builds a draft release
with branded APKs, checksums and release metadata. Verify the candidate before
publishing the draft. Tag pushes alone do not publish. Configure the
documented Android signing and production API secrets in GitHub Actions once;
never commit the keystore or passwords. Until those secrets are configured,
run `tools/publish_android_release.ps1` locally after committing the update;
it also creates a draft. Choose only one publisher for a version. Include
`GOOGLE_WEB_CLIENT_ID` in both local production configuration and CI secrets.
The existing public download stays unchanged until the draft is published. The
published asset name is `JCG-Fitness.apk`; the older `app-release.apk` link is
kept as a compatibility alias during the transition.

For the one-time Google OAuth setup required before publishing v1.0.2, follow
[Google Sign-In production setup](docs/google_signin_production_setup.md).

Before tagging a release, build the ARM64 APK and refresh the same-origin
fallback used by the resumable phone download. Commit that binary alongside the
version change; the local publisher and CI both reject a mismatched fallback.

```powershell
.\tools\sync_android_fallback.ps1 -Arm64ApkPath .\flutter_app\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
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
