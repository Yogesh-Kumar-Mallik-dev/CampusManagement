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
│   ├── cmd/server/            # Main server entrypoint
│   ├── internal/
│   │   ├── cache/             # Resilient cache manager + singleflight
│   │   ├── database/          # PostgreSQL pgxpool connection manager
│   │   └── model/             # Entities with delta-sync support
│   └── go.mod
├── client/                    # Flutter multiplatform client
│   ├── android/
│   ├── ios/
│   ├── linux/
│   ├── macos/
│   ├── web/
│   ├── windows/
│   ├── lib/
│   └── pubspec.yaml
└── docker-compose.yml         # Local PostgreSQL & Redis infrastructure
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
