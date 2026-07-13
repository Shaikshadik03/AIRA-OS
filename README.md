# 🧠 AIRA OS — Your Personal AI Operating System

> An intelligent, responsive personal AI assistant that remembers, plans, learns, automates, creates, and helps you in every part of life.

## Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter 3.x (Dart) |
| **Backend** | Python FastAPI |
| **Database** | Supabase PostgreSQL + pgvector |
| **AI** | Groq (Llama 3.3 70B) |
| **Local Storage** | Hive + Encrypted Storage |

## Project Structure

```
aira/
├── aira_app/              # Flutter mobile app
│   ├── lib/
│   │   ├── core/          # Theme, widgets, services
│   │   ├── features/      # Feature-first modules
│   │   ├── routing/       # go_router config
│   │   ├── app.dart       # MaterialApp
│   │   └── main.dart      # Entry point
│   └── pubspec.yaml
├── aira_backend/           # FastAPI server
│   ├── app/
│   │   ├── api/v1/        # REST endpoints
│   │   ├── config/        # Settings, DB, security
│   │   ├── core/          # AI engine, middleware
│   │   ├── models/        # Pydantic schemas
│   │   ├── services/      # Business logic
│   │   └── main.py        # FastAPI app
│   └── requirements.txt
├── supabase/migrations/    # SQL migration scripts
└── docs/                   # Documentation
```

## Getting Started

### Prerequisites
- Flutter SDK 3.x
- Python 3.11+
- Supabase account
- Groq API key

### Flutter App
```bash
cd aira_app
flutter pub get
flutter run
```

### Backend
```bash
cd aira_backend
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your API keys
uvicorn app.main:app --reload
```

### Database
Run migration scripts (001–006) in order in your Supabase SQL Editor.

## Features (Phase 1)
- ✅ Secure authentication (Email + Google)
- ✅ Premium dark-mode UI with glassmorphism
- ✅ Personal dashboard with progress tracking
- ✅ AI chat powered by Groq/Llama
- ✅ Long-term semantic memory system
- ✅ 6 SQL migration scripts with full schema

## License
MIT
