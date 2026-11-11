# CampusManagement Documentation Portal

Welcome to the **CampusManagement** engineering documentation. This repository houses the cross-platform campus operating system built with a **Flutter** multiplatform client, a high-throughput **Go** backend, **PostgreSQL 16**, **Redis** cache-aside with `singleflight` deduplication, and an **anti-proxy optical data transfer attendance engine**.

---

## Documentation Index

| Guide | Description |
| :--- | :--- |
| [Architecture & System Design](ARCHITECTURE.md) | High-level system topology, caching strategy, offline-first Drift/SQLite outbox, and delta sync replication. |
| [Optical Attendance Protocol](OPTICAL_ATTENDANCE.md) | Deep dive into rolling QR codes, 1.5s ephemeral frame turnovers, HMAC-SHA256 signatures, and anti-proxy mitigations. |
| [Identity & Scoped RBAC](IDENTITY_AND_RBAC.md) | Canonical handle generation (`idgen`), scoped roles, dual-role employees, and user lifecycle states. |
| [API Reference](API_REFERENCE.md) | Comprehensive REST API specification with request/response schemas, error handling, and cURL examples including Fee, Fine, Library, Dispute, AKTU Sessional Hub, and DigiLocker subsystems. |
| [UI & Design System](UI_AND_DESIGN_SYSTEM.md) | Wine Red & GitHub Green palette, smooth theme transitions, SVG icons, desktop dropdowns, lighter placeholder standards, and non-scrollable viewports. |
| [Error Catalog & Troubleshooting](ERROR_CATALOG.md) | Institutional error catalog mapping mild user-facing error messages and reference codes (`CPOS-...`) to IT resolution steps. |
| [Operations & CLI Orchestrator](OPERATIONS_AND_SCRIPTS.md) | Universal lifecycle commands (`./script.sh`), Docker local environment, testing, and deployment. |

---

## System Overview

```mermaid
flowchart TD
    subgraph Client["Flutter Multiplatform Client (Web / Desktop / Mobile)"]
        UI["Material 3 Adaptive UI\n(Wine Red & GitHub Green)"]
        Scanner["Optical Receiver Scanner\n(Viewfinder Reticle)"]
        Broadcaster["Optical Broadcast Podium\n(1.5s Rolling QR)"]
        LocalDB["Local Storage & Outbox\n(Offline Drift/SQLite)"]
    end

    subgraph Backend["Go Backend Engine (Port 8080)"]
        Router["HTTP Router / Mux"]
        AuthHandler["Auth Handler\n(Zero Sign-up, Pre-provisioned)"]
        UserHandler["User & ID Handler\n(idgen Canonical Handles)"]
        AcademicHandler["Academic & Optical Handler\n(HMAC Verification & Rosters)"]
        DeptHandler["Department & Allocation Handler\n(M:N Academics, Batches, Workload)"]
        CacheMgr["Resilient Cache Manager\n(Cache-Aside + Singleflight)"]
    end

    subgraph Storage["Persistent & Cache Layer"]
        PG[("PostgreSQL 16\n(pgxpool Cap: 30)")]
        RedisStore[("Redis 7 Cache\n(Resilient Fallback)")]
    end

    UI --> LocalDB
    Scanner --> LocalDB
    Broadcaster --> LocalDB
    LocalDB <-->|REST & Delta Sync| Router

    Router --> AuthHandler
    Router --> UserHandler
    Router --> AcademicHandler
    Router --> DeptHandler

    UserHandler --> CacheMgr
    AcademicHandler --> CacheMgr
    DeptHandler --> CacheMgr
    CacheMgr <--> RedisStore
    CacheMgr <--> PG
```

---

## Quick Start

```bash
# 1. Install all dependencies (Go modules & Flutter packages)
./script.sh deps

# 2. Boot PostgreSQL 16 & Redis infrastructure
./script.sh envi

# 3. Start Go backend development server
./script.sh dev

# 4. Launch Flutter client
./script.sh app run    # Native Linux Desktop
./script.sh app web    # Google Chrome

# 5. Run static analysis & test suites
./script.sh check
./script.sh test
```
