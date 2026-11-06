# CampusManagement

A resilient, multiplatform Campus Operating System powered by:

- **Client:** Flutter (Web, Linux Desktop, macOS, Windows, Android, iOS) with local SQLite offline caching and reactive Material 3 design.
- **Backend:** Go (REST / WebSocket) with connection pooling (`pgxpool`).
- **Resilient Cache:** Cache-Aside with `singleflight` deduplication (Redis/In-Memory) to protect PostgreSQL from thundering herds.
- **Primary Database:** PostgreSQL 16.
- **Attendance Protocol:** Anti-proxy Optical Data Transfer with rapidly changing rolling QR codes and HMAC-SHA256 signatures.

---

## 📚 Documentation Index

Comprehensive technical documentation is maintained in the [`docs/`](file:///home/yogesh/Projects/CampusManagement/docs/README.md) directory:

- [**System Architecture & Caching**](file:///home/yogesh/Projects/CampusManagement/docs/ARCHITECTURE.md): Dual-tier caching, singleflight deduplication, database connection pooling, and offline outbox sync.
- [**Optical Data Transfer Attendance**](file:///home/yogesh/Projects/CampusManagement/docs/OPTICAL_ATTENDANCE.md): Rapidly rolling QR protocol (1.5s refresh), HMAC-SHA256 frame packets, 6-second anti-proxy freshness window, and live podium feed.
- [**Identity Minting & Scoped RBAC**](file:///home/yogesh/Projects/CampusManagement/docs/IDENTITY_AND_RBAC.md): Canonical handle generator (`idgen`), scoped roles (`sec:cse-3a`, `dept:cse`, `inst:*`), dual-role staff, and lifecycle states.
- [**REST API Reference**](file:///home/yogesh/Projects/CampusManagement/docs/API_REFERENCE.md): Complete endpoint specification with JSON schemas, query parameters, error codes, and cURL commands.
- [**UI & Design System**](file:///home/yogesh/Projects/CampusManagement/docs/UI_AND_DESIGN_SYSTEM.md): Material 3 Wine Red (`#7A1C30`) and GitHub Green (`#238636`) palette, smooth theme transitions, SVG icons, and non-scrollable viewports.
- [**Operations & CLI Orchestrator**](file:///home/yogesh/Projects/CampusManagement/docs/OPERATIONS_AND_SCRIPTS.md): Turnkey development lifecycle runner (`./script.sh`), Docker Compose topology, and automated build pipelines.

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

## Unified Project Lifecycle Commands

Conforming to engineering standards (`./script.sh <command>` or `.\script.ps1 <command>`):

```bash
# 1. Install dependencies (Go modules + Flutter packages)
./script.sh deps

# 2. Start PostgreSQL 16 & Redis infrastructure
./script.sh envi

# 3. Start local development server (with deterministic port cleanup)
./script.sh dev

# 4. Run Flutter client
./script.sh app run          # Native Linux Desktop
./script.sh app web          # Google Chrome

# 5. Run static analysis & typecheckers (zero warnings policy)
./script.sh check

# 6. Run all automated tests
./script.sh test

# 7. Compile production release bundles
./script.sh build

# 8. Flush databases and caches
./script.sh flush

# 9. Tear down docker containers
./script.sh uenvi
```

---

## Core API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/auth/login` | Institutional sign in with canonical handle or email (zero public signup) |
| `GET` / `POST` | `/api/v1/academics/courses` | List course catalog / create new subject |
| `GET` / `POST` | `/api/v1/academics/timetable` | Query schedule by scope (e.g. `sec:cse-3a`) / add slot |
| `POST` | `/api/v1/attendance/optical/start` | Start faculty podium optical broadcast with rotating 1.5s secret |
| `POST` | `/api/v1/attendance/optical/verify` | Verify scanned rolling optical frame with 6-second freshness drift check |
| `GET` | `/api/v1/attendance/optical/roster` | Live roster stream feed of verified students during active lecture |
| `POST` | `/api/v1/attendance/optical/end` | Conclude optical session and persist finalized attendance |
| `POST` | `/api/v1/attendance/sync` | Batch upsert offline-recorded class sessions |
| `GET` | `/api/v1/attendance/summary` | Get attendance percentage report per course for a student |
| `GET` / `POST` | `/api/v1/notices` | Fetch targeted notices by user scopes / publish announcement |
| `GET` | `/api/v1/sync` | Delta sync replication for offline SQLite clients |
| `GET` | `/api/v1/users` | List campus directory with search and archetype filtering |
| `POST` | `/api/v1/users/student` | Onboard student & mint canonical handle (`{name}_{year}_{entry}_{prog}_{seq}`) |
| `POST` | `/api/v1/users/employee` | Onboard employee & mint unified handle (`{name}_{year}_emp_{seq}`) |
| `POST` | `/api/v1/users/discontinue` | Discontinue / offboard campus identity |
| `POST` | `/api/v1/users/reactivate` | Reactivate suspended identity |
| `GET` | `/api/v1/permissions/check` | Real-time scoped permission evaluation |
| `GET` / `POST` | `/api/v1/departments` | List academic departments / create department with HOD |
| `GET` | `/api/v1/academics/programs` | List interdisciplinary degree programs |
| `GET` / `POST` | `/api/v1/academics/subjects` | Manage subjects with decoupled odd/even semester cycle codes |
| `POST` / `GET` | `/api/v1/academics/subjects/syllabus` | Ratify BoS syllabus revisions / query immutable audit trail |
| `GET` / `POST` | `/api/v1/academics/sections` | Cross-program shared cohorts and capacity tracking |
| `POST` | `/api/v1/academics/sections/transfer-student` | Transfer student between section cohorts |
| `POST` | `/api/v1/academics/sections/merge` | Atomically consolidate student cohorts from source to target |
| `GET` / `POST` | `/api/v1/academics/sections/batches` | Query / provision practical lab batches ($B_1, B_2, \dots$) |
| `POST` | `/api/v1/academics/sections/batches/auto-partition` | Deterministic $O(N)$ round-robin student batch auto-partitioning |
| `GET` / `POST` / `DELETE` | `/api/v1/academics/allocations` | Assign faculty to theory, practical, or tutorial components |
| `GET` | `/api/v1/academics/faculty/workload` | Faculty teaching hours summary with 16h overload ceiling |
| `GET` | `/api/health` | Service health & cache readiness check |

---

## Directory Structure

```
CampusManagement/
├── backend/                   # Go backend service
│   ├── cmd/server/            # Main server entrypoint with seed data & HTTP mux
│   ├── internal/
│   │   ├── cache/             # Resilient cache manager + singleflight deduplication
│   │   ├── database/          # PostgreSQL pgxpool & schema migrations
│   │   ├── handler/           # Academic, Optical Attendance, User & Auth HTTP handlers
│   │   ├── idgen/             # Canonical campus handle generator
│   │   ├── model/             # Entities (Course, Timetable, Optical Attendance, User)
│   │   └── service/           # Academic and Scoped RBAC services
│   └── go.mod
├── client/                    # Flutter multiplatform client (Web, Desktop, Mobile)
│   ├── lib/
│   │   ├── models/            # Dart academic, user, and optical frame models
│   │   ├── screens/           # Attendance (Optical & Manual), Timetable, Notices, Users
│   │   ├── services/          # REST API & Offline Storage Outbox services
│   │   ├── theme/             # Wine Red & GitHub Green palette, SVG vector icons
│   │   ├── widgets/           # High-definition SVG logo and common UI components
│   │   └── main.dart          # Adaptive Material 3 entrypoint with animated theme switcher
│   └── pubspec.yaml
├── docs/                      # Technical Documentation Portal
│   ├── README.md              # Documentation index and overview
│   ├── ARCHITECTURE.md        # System architecture, caching, and offline outbox
│   ├── OPTICAL_ATTENDANCE.md  # Optical data transfer protocol & anti-proxy design
│   ├── IDENTITY_AND_RBAC.md   # Canonical handle minting & scoped RBAC
│   ├── API_REFERENCE.md       # Comprehensive REST API reference
│   ├── UI_AND_DESIGN_SYSTEM.md# Material 3 theme, logo, SVG icons, and layout rules
│   └── OPERATIONS_AND_SCRIPTS.md # Script orchestrator and infrastructure guide
├── scripts/                   # Individual lifecycle task scripts
├── script.sh                  # POSIX Universal Lifecycle Orchestrator
├── script.ps1                 # Windows PowerShell Lifecycle Orchestrator
└── docker-compose.yml         # Local PostgreSQL & Redis infrastructure
```
