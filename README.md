# JCG Fitness / NutriSmart AI

Budget-aware nutrition tracking Android app with AI assistance. Built for thesis defense.

## Tech Stack

- **Frontend**: Flutter + Dart (Android)
- **Local Database**: SQLite (`sqflite`)
- **Cloud Backend**: Supabase (Auth, PostgreSQL, Storage, RLS)
- **AI Backend**: Python FastAPI
- **State Management**: Riverpod
- **Routing**: GoRouter

## Quick Start

### Prerequisites

- Flutter SDK 3.0+
- Python 3.11+
- Supabase CLI (for local development)
- Android Studio or VS Code with Flutter extensions

### 1. Database Setup

```bash
cd supabase
supabase start
supabase db reset
```

### 2. FastAPI Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate  # Windows
pip install -r requirements.txt
cp .env.example .env  # Configure your API keys
uvicorn app.main:app --reload
```

### 3. Flutter App

```bash
cd flutter_app
cp .env.example .env  # Configure Supabase credentials
flutter pub get
flutter run
```

### 4. Build APK

```bash
cd flutter_app
flutter build apk --release
```

## Project Structure

```
├── backend/              # Python FastAPI
│   └── app/
│       ├── auth/         # JWT verification
│       ├── routes/       # API endpoints
│       ├── schemas/      # Pydantic models
│       └── services/     # AI scanner, chatbot, safety
├── docs/                 # Documentation
│   ├── change_requests/
│   ├── test_evidence/
│   ├── defense_screenshots/
│   └── api_examples/
├── flutter_app/          # Flutter Android app
│   └── lib/
│       ├── app/          # Theme, router, constants
│       ├── core/         # Database, network, errors, utils
│       └── features/     # 16 feature modules
├── supabase/             # Database migrations
│   └── migrations/       # 24 SQL migration files
```

## Features

- **Offline-first**: Core tracking works without internet
- **Filipino Food Database**: 50+ local foods with nutrition and pricing
- **Budget-Aware Recommendations**: Thesis-core feature with deterministic scoring
- **AI Food Scanner**: Camera-based food recognition via FastAPI
- **AI Chatbot**: Budget-aware nutrition guidance with safety rules
- **Community Feed**: Text-only authenticated social feed
- **Sync Queue**: Offline changes sync when connection returns

## Excluded Features

- Barcode scanning
- Grocery purchasing
- Wearable integration
- Workout planning
- Private messaging
- Profile/avatar image upload
- Community image upload

## Build Order

See `docs/jcg_fitness_detailed_build_checklist_plan_POLISHED_FIXED.md` for complete build plan.

# EXAMPLE
