# CampusManagement

A cross-platform Campus Management System powered by:
- **Client:** Flutter (Web, Android, iOS, Windows, macOS, Linux) with local SQLite offline caching.
- **Backend:** Go (REST / WebSocket) with connection pooling (`pgxpool`).
- **Resilient Cache:** Cache-Aside with `singleflight` deduplication (Redis/In-Memory) to protect PostgreSQL from thundering herds / cache failures.
- **Primary Database:** PostgreSQL 16.

---

## Architecture Overview

```
                               ┌────────────────────────────────────────┐
                               │           Flutter Client               │
                               │  (Web, Desktop: 3 OS, Mobile: 2 OS)    │
                               │   Local SQLite (Drift) Offline Cache   │
                               └──────────────────┬─────────────────────┘
                                                  │ HTTPS / WSS
                                                  ▼
                               ┌────────────────────────────────────────┐
                               │               Go Backend               │
                               │   (Resilient Cache + Singleflight)     │
                               └─────────┬────────────────────┬─────────┘
                   Safe Fallback / Miss  │                    │ Non-blocking Set
                                         ▼                    ▼
                               ┌──────────────────┐  ┌──────────────────┐
                               │  PostgreSQL 16   │  │   Redis Cache    │
                               │ (pgx Connection  │  │ (Safe failure    │
                               │    Pool Cap)     │  │   tolerance)     │
                               └──────────────────┘  └──────────────────┘
```

---

## Directory Structure

```
CampusManagement/
├── backend/                   # Go backend service
│   ├── cmd/server/            # Main server entrypoint with seed data & HTTP mux
│   ├── internal/
│   │   ├── cache/             # Resilient cache manager + singleflight deduplication
│   │   ├── database/          # PostgreSQL pgxpool & schema migrations
│   │   ├── handler/           # Academic & User HTTP handlers
│   │   ├── idgen/             # Canonical campus handle generator
│   │   ├── model/             # Entities (Course, Timetable, Attendance, Notice, User)
│   │   └── service/           # Academic and Scoped RBAC services
│   └── go.mod
├── client/                    # Flutter multiplatform client (Web, Desktop, Mobile)
│   ├── lib/
│   │   ├── models/            # Dart academic and user models
│   │   ├── screens/           # Dashboard, Timetable, Attendance, Notices screens
│   │   ├── services/          # REST API & Offline Storage Outbox services
│   │   └── main.dart          # Adaptive Material 3 entrypoint
│   └── pubspec.yaml
└── docker-compose.yml         # Local PostgreSQL & Redis infrastructure
```

---

## Phase 1 API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` / `POST` | `/api/v1/academics/courses` | List course catalog / create new subject |
| `GET` / `POST` | `/api/v1/academics/timetable` | Query schedule by scope (e.g. `sec:cse-3a`) / add slot |
| `POST` | `/api/v1/attendance/sync` | Batch upsert offline-recorded class sessions |
| `GET` | `/api/v1/attendance/summary` | Get attendance percentage report per course for a student |
| `GET` / `POST` | `/api/v1/notices` | Fetch targeted notices by user scopes / publish announcement |
| `GET` | `/api/v1/sync` | Delta sync replication for offline SQLite clients |
| `POST` | `/api/v1/users/student` | Onboard student & mint canonical handle (`{name}_{year}_{entry}_{prog}_{seq}`) |
| `POST` | `/api/v1/users/employee` | Onboard employee & mint unified handle (`{name}_{year}_emp_{seq}`) |
| `GET` | `/api/v1/permissions/check` | Real-time scoped permission evaluation |
| `GET` | `/api/health` | Service health & cache readiness check |

---

## Running Automated Tests

Run backend Go test suite:
```bash
cd backend
go test -v ./...
```

Run Flutter client test suite & static analysis:
```bash
cd client
flutter test
flutter analyze
```

---

## Getting Started

### 1. Start Infrastructure (PostgreSQL & Redis)
```bash
docker compose up -d
```

### 2. Run Go Backend
```bash
cd backend
go run ./cmd/server
```
The server will start on `http://localhost:8080`.
- Health check: `http://localhost:8080/api/health`
- Delta Sync: `http://localhost:8080/api/v1/sync`

### 3. Run Flutter Client
```bash
cd client

# Run on Web (Chrome)
flutter run -d chrome

# Run on Linux Desktop
flutter run -d linux

# Run on Android Emulator or Device
flutter run -d <device_id>
```
