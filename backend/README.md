# Believer Backend (Local)

Production-minded backend for the existing Flutter app.

## Stack
- Fastify (Node.js)
- PostgreSQL
- JWT auth (access + refresh)
- Haversine distance for nearby search (no PostGIS)

## Features
- Auth and account governance: signup, login, refresh, profile update, logout, change password, password recovery, account deactivation, support requests, and mosque suggestions
- Mosque discovery: list, nearby lookup, detail, reviews, bookmarks, broadcasts, location resolve/suggest/reverse, and backend-owned prayer times
- Admin mosque operations: create, edit, image upload, owned-mosque management, prayer-time configuration, and persisted mosque-page content
- Notifications, services, and business listings: mosque notification settings, the approved-live-only public services discovery feed, backend-persisted business registration drafts/review state, and super-admin business-listing moderation

## Local Setup (Mac)
1. Start database:
   - `cd backend`
   - `docker compose up -d postgres`
2. Install dependencies:
   - `npm install`
3. Configure env:
   - `cp .env.example .env`
   - Set `JWT_SECRET` (32+ chars)
4. Run migration:
   - `npm run migrate`
5. Seed sample mosques:
   - `npm run seed`
6. Start API:
   - `npm run dev`
7. Run smoke tests:
   - `npm test`
8. Run integration tests:
   - `npm run test:integration`
   - This command starts or reuses the repo-local `postgres` Compose service when needed, waits for PostgreSQL readiness, ensures the dedicated integration database exists, runs backend migrations against that test database, and then executes the real integration assertions there.
   - If Docker is unavailable or PostgreSQL cannot be reached, the command exits non-zero with an actionable error instead of skipping the suite.
   - Docker still needs to be installed and running locally for the auto-start path.

API default: `http://localhost:4000`

## Run and Test Commands
- Dev server: `npm run dev`
- Production-style start: `npm run start`
- Migrations: `npm run migrate`
- Seed data: `npm run seed`
- Syntax check: `npm run check`
- Smoke tests: `npm test`
- Integration tests: `npm run test:integration`
- Integration prepare only: `npm run test:integration:prepare`
- Integration run only: `npm run test:integration:run`

## Integration Test Database
- Normal local development database: `DATABASE_URL=postgresql://postgres:postgres@localhost:5432/believer`
- Dedicated local integration database: `DATABASE_TEST_URL=postgresql://postgres:postgres@localhost:5432/believer_test`
- If `DATABASE_TEST_URL` is omitted, the integration bootstrap derives it automatically from `DATABASE_URL` by swapping only the database name to `believer_test`.
- The integration bootstrap refuses to run if `DATABASE_TEST_URL` resolves to the same database name as `DATABASE_URL`.
- Source of truth for local Postgres: `backend/docker-compose.yml`
- Preferred command: `npm run test:integration`
- Optional prep-only command: `npm run test:integration:prepare`
- Run-only command once PostgreSQL is already prepared: `npm run test:integration:run`
- `npm run test:integration` auto-starts or reuses the repo-local Docker Postgres service, creates `believer_test` if needed, runs migrations against `believer_test`, and then runs the real assertions with `DATABASE_URL` pointed at `believer_test`.
- `npm run test:integration:prepare` performs the same Docker/readiness/database-create/migration bootstrap without running the assertions.
- `npm run test:integration:run` keeps the run-only path for already prepared environments, but still points the test process at the dedicated integration database automatically.
- If you want to start the database yourself first, `docker compose up -d postgres` still works and the integration commands will reuse the running instance.
- The integration test file no longer self-skips when PostgreSQL is missing; database orchestration now lives in the script layer so failures stay loud and actionable while normal local dev data stays on `believer`.

## Route Families
- Health: `GET /`, `GET /health`
- Auth: `/api/v1/auth/*`
- Account governance: `/api/v1/account/*`
- Business listings: `/api/v1/business-listings*`, `/api/v1/admin/business-listings*`
- Mosques, location lookup, content, prayer times, reviews, and broadcasts: `/api/v1/mosques*`
- Bookmarks: `/api/v1/bookmarks*`
- Notifications: `/api/v1/notifications*`
- Services: `GET /api/v1/services`
  - Returns the public services feed for a supported category or alias.
  - Only approved business listings whose moderation status is `live` appear in the public feed.
  - `draft`, `under_review`, and `rejected` business listings are intentionally excluded from the public feed.
  - Supported public categories are currently explicit and narrow: `Halal Food` plus supported food aliases, and `Islamic Books` plus the supported `Books & Stationery` alias.
  - Approved business listings outside those explicit Services mappings can still become `live`, but they do not appear in public Services until a deliberate category mapping is added.

## API Docs
- Narrative contract: `../API_CONTRACT.md`
- OpenAPI spec: `docs/openapi.yaml`
- Postman collection: `docs/postman_collection.json`

## Logging
- Supports incoming `x-request-id` header and echoes it back in responses.
- If `x-request-id` is missing, Fastify generates one automatically.

## Production notes
- Reverse-proxy deployments should set `TRUST_PROXY=true`.
- Set `PUBLIC_API_ORIGIN=https://api.example.com` so uploaded mosque image URLs stay correct behind Nginx/HTTPS.
- Start from `backend/.env.production.example` for production env setup.
- Azure Ubuntu VM deployment notes live at `../docs/deployment/AZURE_UBUNTU_VM.md`.
- Public launch runbook: `../docs/deployment/PUBLIC_LAUNCH_RUNBOOK.md`
- Backup and restore guide: `../docs/deployment/BACKUP_RESTORE.md`
- Public QA checklist: `../docs/deployment/PUBLIC_QA_CHECKLIST.md`

## CI
- Frontend GitHub Actions workflow: `../.github/workflows/frontend-ci.yml`
- Backend GitHub Actions workflow: `../.github/workflows/backend-ci.yml`
- Backend CI runs: syntax check, smoke tests, integration tests.

## Nearby Search Design (Future-proof)
- Nearby queries currently use SQL bounding-box prefilter + Haversine distance in code.
- Geo logic is isolated in:
  - `src/utils/geo-distance.js`
  - `src/services/mosque-nearby.js`
- Future PostGIS migration can replace only service internals while keeping API contract unchanged.
