# AGENTS.md — GovConnect

Multi-tenant SaaS for commune/ward public services. .NET 10 Clean Architecture CQRS backend + two React frontends (Admin/Portal web + Zalo Mini App).

## Prerequisites

- .NET 10 SDK
- Docker Desktop (required for dev services AND integration tests)

## Dev commands

```powershell
# Start all services (Postgres+PostGIS :5432, MinIO :9000/:9001, Redis :6379)
docker compose up -d

# Create MinIO bucket "govconnect" at http://localhost:9001 (minioadmin/minioadmin)
# Or: start-dev.bat does everything automatically

# Run API (auto-deploys DB schema via DbUp on first dev start)
dotnet run --project src/GovConnect.Api

# Run web frontend
cd web && npm run dev    # port 8311

# Run Zalo Mini App (Zalo web simulator — enables native APIs: camera, location, QR, Zalo auth)
cd miniapp && npx zmp start -D  # port 8312

# Run all tests (integration tests use Testcontainers — Docker must be running)
dotnet test

# Run a single test class
dotnet test --filter "FullyQualifiedName~RlsIsolationTests"

# Stop dev services (keeps data)
stop-dev.bat
```

Default dev ports: API `:8310`, Web `:8311`, MiniApp `:8312`.

### Demo accounts (tenant `demo-tandinh`)

| Email | Password | Role |
|-------|----------|------|
| `admin@demo-tandinh.gov.vn` | `Admin@123` | TenantAdmin |
| `officer@demo-tandinh.gov.vn` | `Officer@123` | Officer |
| `super@govconnect.vn` | `Super@123` | SuperAdmin |

Citizen login uses Zalo mock: `POST /api/auth/zalo` with `X-Tenant-Code: demo-tandinh` header.

## Architecture

```
src/
  GovConnect.Domain        — entities, enums, domain events (no dependencies)
  GovConnect.Application   — CQRS handlers (MediatR + FluentValidation), ports/interfaces
  GovConnect.Infrastructure — EF Core, RLS interceptor, MinIO, JWT, Zalo mock, Hangfire
  GovConnect.Database      — DbUp SQL scripts (versioned schema migration)
  GovConnect.Api           — ASP.NET Core controllers, middleware, DI wiring
tests/
  GovConnect.IntegrationTests — xunit + Testcontainers (Postgres, MinIO)
  GovConnect.UnitTests
web/    — Admin/Portal (React 19, Vite 8, Tailwind 4, react-router-dom v7)
miniapp/ — Zalo Mini App (React 18, zmp-sdk, zmp-ui, react-router-dom v6)
```

Entry points: `src/GovConnect.Api/Program.cs`, `web/src/main.tsx`, `miniapp/src/main.tsx`.

## Critical patterns

### DB schema: DbUp, NOT EF migrations

Schema is managed by **versioned SQL scripts** in `src/GovConnect.Database/Scripts/`, not EF Core migrations. To add a schema change:
1. Create `ScriptNNNN_Description.sql` in the Scripts folder (sequential numbering matters).
2. Run `dotnet run --project src/GovConnect.Database` to apply manually, or just restart the API (auto-deploys in Development).

The `Migrator` connection string uses the superuser `govconnect`; the `Default` connection uses `govconnect_app` (RLS-enforced).

### Multi-tenancy: two-layer isolation

1. **PostgreSQL RLS** (primary) — `govconnect_app` role enforces `tenant_id = app.current_tenant` at DB level via `set_config()` in `RlsConnectionInterceptor`.
2. **EF Core global query filter** (defense-in-depth) — applied to every `ITenantScoped` entity in `AppDbContext.OnModelCreating`.

New entities that hold tenant data must implement `ITenantScoped` and have a `Guid TenantId` property.

### Tenant resolution

`TenantResolutionMiddleware` runs AFTER auth. It reads `TenantId` from JWT claims first, then falls back to `X-Tenant-Code` header (used by citizen Zalo login and onboarding).

### CQRS with MediatR

Every feature follows: `Command/Query` → `Handler` → `Validator` (FluentValidation). Validation runs via `ValidationBehavior` pipeline. Controllers are thin — they just `mediator.Send()`.

### Permission system

Two authorization mechanisms:
- **Module permissions**: `[Authorize(Policy = "Permission")] + [Permission("reports", "edit")]` — checks module:action against role permissions.
- **Stage permissions**: `[Authorize(Policy = "StagePermission")] + [StagePermission("todo", "edit")]` — checks stage:action for report lifecycle gates.

### Domain events outbox

Domain events are captured in `DomainEventOutbox` table within the same transaction as entity changes (in `AppDbContext.SaveChangesAsync`). An `OutboxDispatcher` background service processes them.

### Enum handling

Enums are stored as integers in PostgreSQL. The frontend API clients receive/send them as numbers. When adding new enums, append values at the end to avoid shifting existing numeric values.

### IDs

All entities use `Guid.CreateVersion7()` (time-ordered). IDs are generated client-side in the domain model, not by the DB.

## Frontend notes

### Web (Admin/Portal)

- API base: `VITE_API_BASE` env var (default `http://localhost:8310`)
- Auth stored in `localStorage` key `gc_auth` (JSON with `accessToken`)
- Path alias: `@` → `./src`
- Pages: `pages/admin/*` (super-admin), `pages/portal/*` (officer/tenant-admin)

### Zalo Mini App

- API base: `VITE_API_BASE` env var (default `http://localhost:8310` in `.env.local`)
- Hardcoded `TENANT_CODE = 'demo-tandinh'` in `api/client.ts`
- Auth stored in `localStorage` key `gc_token`
- Uses `zmp-sdk` for native APIs (camera, location, QR, auth, payment)
- Build: `npm run build` includes `scripts/sync-app-config.mjs` to update `app-config.json` asset hashes
- Deploy: `zmp deploy` (requires Zalo developer account)

### Zalo Mini App: shared UI

`miniapp/src/ui/` is the only place a component is defined — screens import it, never re-implement it inline:

- **Header** — `ui/AppHeader.tsx` (markup `.mx-hd`, styles in `ui/man-hinh.css`) is the single header for every screen. Props: `title`, `subtitle`, `onBack`, `logo`, `right`, `extra`, `tall`, `variant: 'navy' | 'sang'`. To add something to a header, extend this component or pass an existing shared piece via `right`/`extra`.
- **Header pieces** — `ui/HeaderSearch.tsx` (`HeaderSearch` input / `HeaderSearchButton`), `ui/HeaderActions.tsx` (`HeaderIconButton`, `HeaderFilterButton`), `ui/BellButton.tsx`. The badge count convention (`data-dem` + `.mx-hd__nut--dem/--badge`) lives in these; screens must not rebuild it.
- Zalo's ⋯/✕ capsule is handled inside the header (`--gx-zalo-capsule` = 0px outside Zalo, set by `lib/zalo-env.ts`); never bake a fixed right inset into a screen.

### Frontend API clients

Both frontends have `api/client.ts` that wraps fetch with auth header injection and 401 handling. Web redirects to `/login`; miniapp redirects to `/onboarding`.

## Project testing skills

Reusable project skills live in `.claude/skills/`:

- `frontend-testing` — Web/Mini App build, lint, Playwright, visual and frontend contract checks.
- `miniapp-testing` — Mini App builds, browser tests, real backend flows, Zalo web simulator/device verification, and navigation/icon checks.
- `backend-testing` — .NET unit/integration tests, Testcontainers, DbUp and tenant/RLS coverage.
- `qa-verification` — cross-stack QA, FE↔BE boundary verification and release-readiness reporting.

For changes spanning frontend and backend, use the focused frontend (or `miniapp-testing` for Mini App) and backend testing skills for execution and `qa-verification` for the final cross-boundary review. These skills do not authorize deployment, production mutation, or external ticket changes.

## Conventions

- **No AI attribution in commits** — write commit messages like a normal developer.
- **Verification screenshots** go in `.screenshots/` (gitignored), never committed.
- **Deploy credentials** are in `.secrets/govconnect-ssh.md` (gitignored) — never write real IPs/passwords to tracked files.
- **Central package management** — all NuGet versions in `Directory.Packages.props`; individual `.csproj` files don't specify versions.
- **EF naming** — snake_case via `EFCore.NamingConventions`.
- **Swagger** available at `/swagger` in Development; Scalar at `/scalar/v1`.
- **Hangfire dashboard** at `/hangfire` (super-admin only); requires Redis.
