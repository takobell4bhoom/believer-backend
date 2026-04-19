# Believer

BelieversLens monorepo with a Flutter frontend at the repo root and a Fastify/PostgreSQL backend in `backend/`.

## Repo Layout
- Frontend entrypoint: `lib/main.dart`
- Frontend routing: `lib/navigation/app_router.dart`
- Backend entrypoint: `backend/src/index.js`
- Backend API spec: `backend/docs/openapi.yaml`
- Backend contract doc: `API_CONTRACT.md`

## Useful Local Commands
- Install Node workspace dependencies: `npm install`
- Flutter dependencies: `flutter pub get`
- Run Flutter web locally: `flutter run -d chrome --web-port 3000`
- Run Flutter on Android emulator locally: `flutter run -d emulator-5554`
- Flutter analyzer: `flutter analyze`
- Flutter tests: `flutter test`
- Flutter web release build: `flutter build web --release --dart-define=API_BASE_URL=https://api.example.com`
- Backend dev server: `npm run backend:dev`
- Backend migration runner: `npm run backend:migrate`
- Backend seed data: `npm run backend:seed`
- Backend smoke tests: `npm run backend:test`
- Backend integration tests: `npm run backend:test:integration`

## Local Setup
1. Install Node dependencies from the repo root with `npm install`.
2. Install Flutter dependencies with `flutter pub get`.
3. Copy `backend/.env.example` to `backend/.env` and set a real `JWT_SECRET`.
4. Start PostgreSQL with `cd backend && docker compose up -d postgres`.
5. Run backend migrations with `npm run backend:migrate`.
6. Start the backend with `npm run backend:dev`.
7. Start the frontend:
   - Flutter web: `flutter run -d chrome --web-port 3000`
   - Android emulator: `flutter run -d emulator-5554`

## Frontend API Base URL Defaults
- Flutter web, iOS simulator, and desktop builds default to `http://localhost:4000`.
- Android local builds default to `http://10.0.2.2:4000`, which reaches the host machine from the Android emulator.
- Physical devices still need an explicit override such as `--dart-define=API_BASE_URL=http://192.168.x.x:4000`.
- If auth shows a connection-style error while the backend is already running, verify `API_BASE_URL` for the current target before assuming the server is down.

## CI
- Frontend GitHub Actions workflow: `.github/workflows/frontend-ci.yml`
- Backend GitHub Actions workflow: `.github/workflows/backend-ci.yml`
- Production deploy workflow: `.github/workflows/production-deploy.yml`
- Frontend CI runs `flutter pub get`, `flutter analyze`, `flutter test`, and a release web build with `API_BASE_URL`.
- Backend CI keeps running syntax checks, smoke tests, and integration tests.
- Production deploy runs the frontend and backend checks again on `main`, packages the Flutter web build as a GitHub artifact, uploads it to the Ubuntu host over SSH, and then runs `deploy/scripts/deploy_release.sh` on the server.

## Backend Integration Tests
- Normal local development uses PostgreSQL at `postgresql://postgres:postgres@localhost:5432/believer`.
- The integration suite uses a dedicated local test database, defaulting to `postgresql://postgres:postgres@localhost:5432/believer_test`.
- `npm --workspace backend run test:integration` now bootstraps the repo's `backend/docker-compose.yml` Postgres service when the database is not already reachable, creates or reuses `believer_test`, waits for readiness, runs migrations against that dedicated test database, and then runs the real API integration assertions there.
- Docker must be installed and running locally for that auto-start path.
- Backend-specific setup notes live in `backend/README.md`.

## Docs
- Repo overview and onboarding: `README.md`
- Backend setup, run/test workflow, and ops notes: `backend/README.md`
- API contract: `API_CONTRACT.md`
- Deployment and launch docs: `docs/deployment/*.md`
- Planning and implementation status: `docs/planning/*.md`

## Deployment
- Azure Ubuntu VM deployment notes: `docs/deployment/AZURE_UBUNTU_VM.md`
- GitHub Actions CI/CD setup: `docs/deployment/GITHUB_ACTIONS_CICD.md`
- Public launch runbook: `docs/deployment/PUBLIC_LAUNCH_RUNBOOK.md`
- Backup and restore guide: `docs/deployment/BACKUP_RESTORE.md`
- Public QA checklist: `docs/deployment/PUBLIC_QA_CHECKLIST.md`
- Production backend env template: `backend/.env.production.example`
- Nginx template: `deploy/nginx/believer.conf`
- systemd template: `deploy/systemd/believer-backend.service`
