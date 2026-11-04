# Architecture & System Design

This document details the architectural blueprints of **CampusManagement**, focusing on resilient caching, database concurrency controls, offline-first client synchronization, and multiplatform delivery.

---

## 1. System Topology

```mermaid
flowchart LR
    subgraph ClientLayer["Multiplatform Flutter Client"]
        ClientApp["Flutter Engine"]
        SQLiteCache[("Drift / SQLite Cache")]
        SyncOutbox[("Sync Outbox")]
    end

    subgraph APILayer["Go REST & Sync Service"]
        Server["Go HTTP Mux"]
        Singleflight["Singleflight Group\n(Request Deduplication)"]
        CacheAside["Resilient Cache-Aside Layer"]
    end

    subgraph DataLayer["Persistence & In-Memory"]
        RedisNode[("Redis 7 In-Memory")]
        PostgresNode[("PostgreSQL 16 Engine\n(pgxpool connection pool)")]
    end

    ClientApp <--> SQLiteCache
    ClientApp --> SyncOutbox
    SyncOutbox -->|Delta Sync / Replay| Server

    Server --> Singleflight
    Singleflight --> CacheAside
    CacheAside <-->|Fast Path / Read Cache| RedisNode
    CacheAside <-->|Cache Miss / Slow Path| PostgresNode
```

---

## 2. Resilient Dual-Tier Caching & Singleflight

### 2.1 The Thundering Herd Problem
In a university environment, thousands of students check grades, schedules, or notices simultaneously (e.g. 09:00 AM term timetable release). A cache miss across 5,000 concurrent requests could easily saturate the database connection pool, inducing connection timeouts or cascade failures.

### 2.2 Singleflight Deduplication
The Go backend implements `golang.org/x/sync/singleflight`. When multiple concurrent goroutines request the identical cache key (e.g. `timetable:sec:cse-3a`), only **one** goroutine executes the database query. All other concurrent goroutines wait on the channel and share the result once resolved.

```mermaid
sequenceDiagram
    autonumber
    actor ClientA as Student 1
    actor ClientB as Student 2
    actor ClientC as Student 3
    participant SF as Singleflight Group
    participant Cache as Redis Cache
    participant DB as PostgreSQL 16

    ClientA->>SF: GET /academics/timetable?scope=sec:cse-3a
    ClientB->>SF: GET /academics/timetable?scope=sec:cse-3a
    ClientC->>SF: GET /academics/timetable?scope=sec:cse-3a

    Note over SF: Leader elected (ClientA).<br/>ClientB & ClientC join waiting channel.
    SF->>Cache: Check Key "timetable:sec:cse-3a"
    Cache-->>SF: Cache Miss
    SF->>DB: Query timetable slots for scope
    DB-->>SF: Return rows (10ms)
    SF->>Cache: Asynchronously populate cache (TTL: 15m)
    SF-->>ClientA: HTTP 200 JSON Response
    SF-->>ClientB: HTTP 200 JSON Response (Deduplicated)
    SF-->>ClientC: HTTP 200 JSON Response (Deduplicated)
```

### 2.3 Resilient Redis Fallback
If the Redis server is unavailable, network partitioned, or restarting:
- The backend does **not** crash or fail the incoming HTTP request.
- The cache manager transparently catches Redis connection errors, logs an alert, falls back to direct PostgreSQL reads, and degrades gracefully.
- Health checks at `/api/health` expose `"cache_ready": false` without interrupting service availability.

---

## 3. Database Layer & PostgreSQL Connection Pooling

The database layer utilizes `pgxpool` with strict connection caps:
- **`MaxConns: 30`**: Protects the PostgreSQL database from unbounded connection thread spawns.
- **`MinConns: 5`**: Maintains hot connections to avoid TCP and TLS handshake overhead.
- **Prepared Statements**: Parameterized queries prevent SQL injection and allow query plan reuse.
- **Transactions (`pgx.Tx`)**: Atomic operations ensure user admission, handle creation, role assignment, and enrollment are either committed entirely or rolled back.

---

## 4. Offline-First Client Architecture

Campus networks often experience poor indoor cellular coverage and Wi-Fi dead zones in lecture halls. To provide uninterrupted operational reliability, the Flutter client employs an **offline-first outbox model**:

```mermaid
flowchart TD
    UserAction["User Action\n(e.g. Mark Offline Attendance)"] --> SaveLocal["Save Record to Local SQLite"]
    SaveLocal --> QueueOutbox["Enqueue into Sync Outbox\n(Status: PENDING)"]
    QueueOutbox --> NetCheck{"Network\nConnected?"}

    NetCheck -- Yes --> PushSync["POST /api/v1/attendance/sync"]
    PushSync --> AckSuccess{"Server\nAcknowledged?"}
    AckSuccess -- Yes --> MarkClean["Mark Outbox Item COMPLETED\nUpdate Local State"]
    AckSuccess -- No --> RetryWithBackoff["Exponential Backoff Retry"]

    NetCheck -- No --> HoldQueue["Retain in Outbox\nBadge UI with 'Pending Sync'"]
    HoldQueue --> ListenConnectivity["Listen for Connectivity Restoration"]
    ListenConnectivity --> NetCheck
```

### 4.1 Delta Sync Protocol
When the client transitions from offline to online:
1. **Pull Step**: The client issues `GET /api/v1/sync?since=<last_synced_timestamp>`.
2. The server responds with all courses, timetable slots, attendance sessions, and notices modified since that timestamp.
3. **Reconciliation**: The client applies updates locally using idempotent upserts.
4. **Push Step**: Any locally recorded events (such as student optical verifications or manual checklist entries) in the outbox are drained via `POST /api/v1/attendance/sync`.

---

## 5. Security & Isolation Model

- **No Self-Registration**: Accounts are provisioned exclusively via institutional onboarding (`/api/v1/users/student` and `/api/v1/users/employee`).
- **Cryptographic Ephemeral Tokens**: Rapidly rolling optical attendance frames include HMAC-SHA256 signatures with 6-second lifetimes to eliminate remote screenshot proxy fraud.
- **Scope-Delimited RBAC**: Permissions are evaluated dynamically against scope hierarchies (`inst:*` > `campus:main` > `dept:cse` > `sec:cse-3a`), preventing horizontal privilege escalation across departments.
