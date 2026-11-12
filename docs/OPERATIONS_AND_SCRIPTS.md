# Operations, Scripts & Lifecycle Orchestrator

This document explains the lifecycle management scripts, local container infrastructure, automated test pipelines, and build targets in CampusManagement.

---

## 1. Universal Lifecycle Orchestrator (`script.sh` & `script.ps1`)

All tasks are executed through the single-entrypoint lifecycle runner:
- **POSIX (Linux / macOS)**: `./script.sh <command>`
- **Windows (PowerShell)**: `.\script.ps1 <command>`

### 1.1 Command Reference

```bash
# ----------------------------------------------------
# 1. SETUP & DEPENDENCIES
# ----------------------------------------------------
./script.sh deps
# - Fetches Go modules via 'go mod download'
# - Fetches Flutter dependencies via 'flutter pub get'

# ----------------------------------------------------
# 2. LOCAL DOCKER INFRASTRUCTURE
# ----------------------------------------------------
./script.sh envi
# - Generates .env from .env.example if missing
# - Starts PostgreSQL 16 (port 5432) and Redis 7 (port 6379) via docker-compose
# - Verifies health checks before releasing control

./script.sh uenvi
# - Shuts down Docker containers and unbinds network ports

./script.sh flush
# - Flushes PostgreSQL database schema and clears Redis cache keys
# - Re-applies backend/internal/database/schema.sql automatically for clean-slate testing

# ----------------------------------------------------
# 3. DEVELOPMENT SERVER
# ----------------------------------------------------
./script.sh dev
# - Kills any orphan processes bound to port 8080 (deterministic cleanup)
# - Runs Go backend server locally with hot compilation
# - Seeds default roles, sample academic schedules, and pre-provisioned users

# ----------------------------------------------------
# 4. FLUTTER CLIENT LAUNCHER
# ----------------------------------------------------
./script.sh app run          # Native Linux Desktop application
./script.sh app web          # Google Chrome web client
./script.sh app build        # Native release binary

# ----------------------------------------------------
# 5. QUALITY ASSURANCE & TESTING
# ----------------------------------------------------
./script.sh check
# - Runs Go static analysis ('go vet ./...')
# - Runs Flutter static analysis ('flutter analyze')
# - Enforces 0 warnings / 0 errors policy

./script.sh test
# - Executes backend Go test suite ('go test -v ./...')
# - Executes Flutter client test suite ('flutter test')
# - Supports argument forwarding (e.g. './script.sh test --plain-name "Department"')
# - Tests widget hierarchy, optical packet math, academic models, and anti-proxy freshness logic

# ----------------------------------------------------
# 6. PRODUCTION RELEASE BUILD
# ----------------------------------------------------
./script.sh build
# - Compiles optimized Go backend binary to 'backend/bin/server'
# - Compiles Flutter web production bundle to 'client/build/web'
```

---

## 2. Local Infrastructure Topology (`docker-compose.yml`)

The repository includes a turnkey local environment defined in `docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: campus_postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: campus_user
      POSTGRES_PASSWORD: campus_password
      POSTGRES_DB: campus_db
    ports:
      - "${POSTGRES_PORT:-5435}:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./backend/internal/database/schema.sql:/docker-entrypoint-initdb.d/schema.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U campus_user -d campus_db"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: campus_redis
    restart: unless-stopped
    ports:
      - "${REDIS_PORT:-6380}:6379"
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
  redisdata:
```

---

## 3. Environment Configuration (`.env`)

Default environment variables are declared in `.env` (derived from `.env.example`):

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `PORT` | `8080` | Port for the Go HTTP REST API server |
| `ENV` | `development` | Runtime environment (`development`, `production`, `test`) |
| `POSTGRES_HOST` | `localhost` | PostgreSQL host |
| `POSTGRES_PORT` | `5435` | PostgreSQL host port (mapped to container port 5432) |
| `POSTGRES_USER` | `campus_user` | PostgreSQL username |
| `POSTGRES_PASSWORD` | `campus_password` | PostgreSQL password |
| `POSTGRES_DB` | `campus_db` | Primary PostgreSQL database name |
| `DATABASE_URL` | `postgres://campus_user:campus_password@localhost:5435/campus_db?sslmode=disable` | Full PostgreSQL connection string |
| `REDIS_PORT` | `6380` | Redis host port (mapped to container port 6379) |
| `REDIS_ADDR` | `localhost:6380` | Redis address |
| `STORAGE_DRIVER` | `local` | Document/PDF storage driver (`local`, `s3`) |
| `PAYMENT_GATEWAY_PROVIDER` | `sandbox` | Payment gateway provider (`sandbox`, `razorpay`) |
| `API_BASE_URL` | `http://localhost:8080` | Client API endpoint target |

---

## 4. Continuous Integration & Pre-Commit Verification

Before committing code or submitting pull requests, developers must run the two verification gates:

```bash
# Gate 1: Static analysis
./script.sh check

# Gate 2: Test suites
./script.sh test
```

Both gates run in under 5 seconds and exit with non-zero status if any static analysis warning or test regression occurs.
