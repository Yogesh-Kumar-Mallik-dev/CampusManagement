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
./script.sh deps                 # Installs both Go modules and Flutter packages
./script.sh deps backend         # Installs Go modules ('go mod download && go mod tidy')
./script.sh deps client          # Installs Flutter dependencies ('flutter pub get')

# ----------------------------------------------------
# 2. LOCAL DOCKER INFRASTRUCTURE
# ----------------------------------------------------
./script.sh envi
# - Generates .env from .env.example if missing
# - Starts PostgreSQL 16 (port 5435) and Redis 7 (port 6380) via docker-compose
# - Verifies health checks before releasing control

./script.sh uenvi
# - Shuts down Docker containers and unbinds network ports

./script.sh flush
# - Flushes PostgreSQL database schema and clears Redis cache keys
# - Re-applies backend/internal/database/schema.sql automatically for clean-slate testing

# ----------------------------------------------------
# 3. DEVELOPMENT SERVER
# ----------------------------------------------------
./script.sh dev                  # Starts infra, Go backend, and Flutter Linux client
./script.sh dev --backend-only   # Starts infra and Go backend server only
./script.sh dev --web            # Starts infra, Go backend, and Chrome web client

# ----------------------------------------------------
# 4. FLUTTER CLIENT LAUNCHER
# ----------------------------------------------------
./script.sh app run              # Native Linux Desktop application
./script.sh app web              # Google Chrome web client
./script.sh app build            # Native release binary
./script.sh app apk              # Android APK build

# ----------------------------------------------------
# 5. QUALITY ASSURANCE & TESTING
# ----------------------------------------------------
./script.sh check                # Runs both Go vet and Flutter analyze
./script.sh check backend        # Runs Go static analysis ('go vet ./...')
./script.sh check client         # Runs Flutter static analysis ('flutter analyze')

./script.sh test                 # Executes all backend and client test suites
./script.sh test backend [args]  # Executes Go test suite (e.g. ./script.sh test backend -run TestDigiLocker)
./script.sh test client [args]   # Executes Flutter client test suite (e.g. ./script.sh test client test/facade_test.dart)

# ----------------------------------------------------
# 6. PRODUCTION RELEASE BUILD
# ----------------------------------------------------
./script.sh build                # Compiles Go backend binary and Flutter web bundle
./script.sh build backend        # Compiles Go backend binary to 'backend/bin/server'
./script.sh build web            # Compiles Flutter web production bundle to 'client/build/web'
./script.sh build linux          # Compiles Flutter Linux desktop bundle
./script.sh build apk            # Compiles Flutter Android release APK
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
| `DIGILOCKER_ENV` | `sandbox` | DigiLocker integration mode (`sandbox`, `production`) |
| `DIGILOCKER_CLIENT_ID` | `campus_erp_demo_client` | DigiLocker / MeriPehchan OAuth client ID |
| `DIGILOCKER_CLIENT_SECRET` | `campus_demo_secret` | DigiLocker / MeriPehchan OAuth client secret |
| `DIGILOCKER_REDIRECT_URI` | `https://erp.campus.edu/api/v1/digilocker/callback` | OAuth 2.0 PKCE redirect callback URI |
| `DIGILOCKER_AUTH_URL` | `https://digilocker.meripehchan.gov.in/public/oauth2/1/authorize` | MeriPehchan OAuth 2.0 authorization endpoint |
| `DIGILOCKER_TOKEN_URL` | `https://digilocker.meripehchan.gov.in/public/oauth2/1/token` | MeriPehchan OAuth 2.0 token endpoint |
| `DIGILOCKER_API_BASE_URL` | `https://api.digitallocker.gov.in/public/oauth2/2` | DigiLocker document pull REST API base URL |
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
