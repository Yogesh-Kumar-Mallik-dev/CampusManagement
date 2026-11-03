# ==============================================================================
# Universal Project Lifecycle Orchestrator (Windows PowerShell Entrypoint)
# Conforming to engineering-standards / SCRIPT_ORCHESTRATION_GUIDE.md
# Usage: .\script.ps1 [dev|build|check|test|deps|envi|uenvi|flush|app|help]
# ==============================================================================
[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$Command = "dev",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Help {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  🏛️  CampusManagement Platform Lifecycle Orchestrator" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Usage: .\script.ps1 <command> [args...]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available commands:"
    Write-Host "  dev      Start infrastructure (Postgres/Redis) and launch Go backend"
    Write-Host "  build    Build Go backend binary and Flutter production bundles"
    Write-Host "  check    Run typecheckers, linters, and static analysis"
    Write-Host "  test     Run backend Go tests and Flutter client test suites"
    Write-Host "  deps     Install Go and Flutter dependencies"
    Write-Host "  envi     Initialize environment (.env) and start Docker containers"
    Write-Host "  uenvi    Tear down local Docker containers"
    Write-Host "  app      Run or build the native Flutter client (run|web|desktop|apk)"
    Write-Host "  flush    Flush database (PostgreSQL) and Redis caches"
    Write-Host "  help     Display this help message"
    Write-Host "==================================================================" -ForegroundColor Cyan
}

switch ($Command.ToLower()) {
    "dev" {
        $target = Join-Path $ScriptDir "scripts\dev.ps1"
        if (Test-Path $target) { & $target @RemainingArgs } else {
            Write-Host "==> Starting backend server..."
            Set-Location (Join-Path $ScriptDir "backend")
            go run ./cmd/server
        }
    }
    "build" {
        $target = Join-Path $ScriptDir "scripts\build.ps1"
        if (Test-Path $target) { & $target @RemainingArgs } else {
            Set-Location (Join-Path $ScriptDir "backend")
            go build -o bin/server.exe ./cmd/server/main.go
            Set-Location (Join-Path $ScriptDir "client")
            flutter build windows --release
        }
    }
    "check" {
        Set-Location (Join-Path $ScriptDir "backend")
        go vet ./...
        Set-Location (Join-Path $ScriptDir "client")
        flutter analyze
    }
    "test" {
        Set-Location (Join-Path $ScriptDir "backend")
        go test -v ./...
        Set-Location (Join-Path $ScriptDir "client")
        flutter test
    }
    "deps" {
        Set-Location (Join-Path $ScriptDir "backend")
        go mod download; go mod tidy
        Set-Location (Join-Path $ScriptDir "client")
        flutter pub get
    }
    "envi" {
        Set-Location $ScriptDir
        docker compose up -d postgres redis
    }
    "uenvi" {
        Set-Location $ScriptDir
        docker compose down
    }
    "flush" {
        docker compose exec redis redis-cli flushall
    }
    "app" {
        Set-Location (Join-Path $ScriptDir "client")
        flutter run @RemainingArgs
    }
    "help" {
        Show-Help
    }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Show-Help
    }
}
