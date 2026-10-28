# GovConnect Backend

Multi-tenant SaaS backend (.NET 10, Clean Architecture, CQRS) for commune/ward public services.
Modules in this build: Field Reports (full lifecycle). Auth: staff (email/password) + citizens
(Zalo mock). Storage: MinIO. Tenant isolation: PostgreSQL Row-Level Security (RLS).

## Prerequisites

- .NET 10 SDK
- Docker Desktop

## Run locally

```powershell
docker compose up -d
# Postgres+PostGIS listens on port 5432, MinIO on 9000/9001, Redis on 6379.
# Create the MinIO bucket "govconnect" at http://localhost:9001 (minioadmin/minioadmin)
#   Console -> Buckets -> Create Bucket -> name: govconnect
dotnet run --project src/GovConnect.Api
```

On first Development startup the app auto-deploys schema via DbUp and seeds the demo tenant `demo-tandinh`.

### Database schema management (DbUp)

Schema is managed by **DbUp** (versioned SQL scripts in `src/GovConnect.Database/Scripts/`), not EF Core migrations.

- **Development auto-deploy:** `dotnet run --project src/GovConnect.Api` deploys automatically (uses the `Migrator` connection string = superuser `govconnect`).
- **Manual deploy:** `dotnet run --project src/GovConnect.Database`
- **Connection strings in `appsettings.json`:**
  - `Default` — app role `govconnect_app` (non-superuser; RLS is enforced against this role)
  - `Migrator` — superuser `govconnect` (runs DbUp scripts; bypasses RLS for schema setup)

### Two-role architecture

PostgreSQL RLS requires a non-superuser role. The superuser (`govconnect`) creates schema and RLS policies; the API connects as `govconnect_app` so all row-level policies are enforced.

## Demo accounts

After first startup, the following accounts are seeded for tenant `demo-tandinh`:

| Account | Email | Password | Role |
|---------|-------|----------|------|
| Officer | `officer@demo-tandinh.gov.vn` | `Officer@123` | Officer |
| Tenant admin | `admin@demo-tandinh.gov.vn` | `Admin@123` | TenantAdmin |
| Super admin | `super@govconnect.vn` | `Super@123` | SuperAdmin |

Citizen login (Zalo mock):
```http
POST /api/auth/zalo
X-Tenant-Code: demo-tandinh
Content-Type: application/json

{
  "tenantCode": "demo-tandinh",
  "zaloAccessToken": "mock:mock-app:z1:0901234567:Tên Người Dùng"
}
```

## API

Swagger UI available at `/swagger` when running in Development mode.
Authenticate with the Bearer token returned from a login endpoint.

Key endpoints:

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/login` | Staff login (email + password) |
| POST | `/api/auth/zalo` | Citizen login (Zalo mock token) |
| POST | `/api/reports` | Create report (citizen) |
| GET | `/api/reports/mine` | List my reports (citizen) |
| GET | `/api/reports/{id}` | Report detail + timeline |
| GET | `/api/reports` | List all reports (officer, paged) |
| POST | `/api/reports/{id}/stage` | Update stage (officer) |
| POST | `/api/reports/{id}/assign` | Assign officer |
| POST | `/api/reports/{id}/rate` | Rate a completed report (citizen) |
| GET | `/api/reports/heatmap` | PostGIS heatmap (officer) |
| GET | `/api/reports/{id}/duplicates` | Nearby duplicate detection (officer) |
| POST | `/api/files/upload-url` | Get presigned MinIO upload URL |
| GET | `/health` | Health check (Postgres) |

## Tests

```powershell
dotnet test
```

Integration tests spin up isolated Postgres+PostGIS (port mapped dynamically) and MinIO containers via Testcontainers (Docker required). Tests run against a fresh database seeded for each test run.

Tests included:

- `RlsIsolationTests` — mandatory cross-tenant RLS leak test (DB-level, bypasses EF filter)
- `AuthTests` — citizen Zalo mock login end-to-end
- `CreateReportTests` — citizen creates report, verifies routing to department
- `ReportLifecycleTests` — full Received→Todo→InProgress→Done lifecycle + invalid transition rejected 400

## Architecture

```
GovConnect.Domain        entities, enums, domain events (no dependencies)
GovConnect.Application   CQRS handlers, ports, validation pipeline (MediatR + FluentValidation)
GovConnect.Infrastructure EF Core + RLS interceptor, MinIO, JWT, Zalo mock, DbUp runner
GovConnect.Database      DbUp SQL scripts (versioned schema migration)
GovConnect.Api           ASP.NET Core controllers, middleware, DI wiring
```

Tenant isolation uses two mechanisms:
1. **PostgreSQL RLS** (primary) — `govconnect_app` role enforces `tenant_id = app.current_tenant` at DB level
2. **EF Core global query filter** (defense-in-depth) — applied to every `ITenantScoped` entity

## Notify + Neighborhood QR (Plan 2)

- Neighborhoods have an opaque `QrToken`; citizens `POST /api/neighborhoods/join {qrToken}` → membership `pending` → officer/kp approve.
- Two-layer notification moderation: kp `POST /api/notifications` (draft) → `/submit` → officer `/approve` or `/reject`.
- Approval enqueues a **Hangfire** job (Redis storage) that fans out to approved members: in-app always, ZNS (mock) when priority is High. Dashboard at `/hangfire` (super-admin only).
- Citizen unified feed: `GET /api/notifications/mine` merges neighborhood notices + report-status updates; `POST /api/notifications/mine/read {kind,id}`.
- Demo neighborhood QR token (seed): `KP-DEMO0001`.

## Platform / Admin (Plan 3) — super-admin only (`/api/platform/...`)

- Tenants: `GET/POST /api/platform/tenants`, `PUT /{id}`, `POST /{id}/suspend`, `POST /{id}/zalo` (map Zalo App ID). Create auto-generates a `code` slug and provisions default SLA rules.
- Staff: `GET/POST /api/platform/users` (cross-tenant), `POST /{id}/disable`. Invited staff can log in immediately.
- Catalog: `GET/POST /api/platform/zns-templates`, `GET /api/platform/plans`.
- Observability: `GET /api/platform/audit` (paged), `GET /api/platform/kpis` (system-wide counts).
- KPIs read cross-tenant aggregates via the **Migrator (superuser) connection** (the only RLS-bypassing path); everything else uses the app role. Non-super-admins get 403.
- All admin/moderation actions are recorded in `audit_logs`.
