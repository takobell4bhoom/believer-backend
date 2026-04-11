# Chat Continuity Guide

Last updated: 2026-04-02

## Purpose

Use this file to resume work in another chat without re-discovering the repo, current implementation state, and doc ownership.

## What a new chat should know immediately

- This is a Flutter frontend + Fastify/PostgreSQL backend monorepo.
- The current codebase already has real auth, mosque discovery, admin mosque management, notifications settings, password recovery, and account-governance flows.
- `docs/planning/SCREEN_GAP_AUDIT.md` is the best current status doc for implemented-vs-partial UI work.
- `README.md`, `backend/README.md`, and `API_CONTRACT.md` own onboarding, backend workflow, and contract details.
- `Ui-scan/*.md` are historical CSIF artifacts, not current implementation truth.

## Best files to share first in a new chat

Share these in this order:

1. `docs/planning/SCREEN_GAP_AUDIT.md`
2. `docs/planning/FIGMA_IMPLEMENTATION_MASTER_PLAN.md`
3. `MASTER_CONTEXT.md`
4. `API_CONTRACT.md`
5. any direct Figma node link for the exact screen being worked on

## Suggested prompt for resuming in a new chat

Use a prompt close to this:

`Continue Believers Lens from docs/planning/SCREEN_GAP_AUDIT.md. Work only on the named screen or doc owner area I specify, verify against the current code first, make only scoped changes, run the relevant checks, and update the owning docs if the status changes.`

## Safe execution model

1. Read the owner docs for the area being changed.
2. Inspect the exact frontend/backend files involved.
3. Compare against the exact verified Figma node if this is a UI-fidelity task.
4. Make only scoped changes.
5. Run the relevant verification.
6. Update the owning docs, not every overlapping doc.

## What not to do in a future chat

- Do not redesign every screen in one pass.
- Do not rewrite routing unless necessary.
- Do not change backend contracts casually.
- Do not treat historical CSIF files as current implementation docs.
- Do not replace owner docs with duplicated summaries in unrelated files.
- Do not implement a screen without first confirming the exact verified Figma node.

## Known facts worth reusing

### Frontend

- Named routes in `lib/navigation/app_routes.dart` are active and broad enough for the current app.
- Shared bottom-nav, screen-header, async-state, and Figma-derived primitives already exist.
- Home, mosque listing/page, notifications, prayer settings, profile/settings, and admin mosque management are the highest-value runtime surfaces.

### Backend

- Auth is real, including forgot/reset password, change password, and account deactivation.
- Mosque discovery, content reads, prayer times, broadcasts, reviews, location lookup helpers, bookmarks, notifications, and services routes are implemented.
- Admin add/edit/upload/owned-mosque workflows are real.

### Tests

- `flutter analyze`, `flutter test`, `npm run backend:test`, and `npm run backend:test:integration` are the active verification commands.
- Integration tests use the dedicated `believer_test` database flow.

## Recommended next chat types

- Deployment/runtime doc maintenance or launch-readiness checks
- API contract cleanup when backend routes move
- One scoped UI fidelity slice tied to an exact Figma node
- One scoped backend/runtime fix tied to existing tests

## Suggested doc maintenance rule

At the end of any meaningful implementation chat, update the owner doc for that area:

- `README.md`
- `backend/README.md`
- `API_CONTRACT.md`
- `docs/planning/SCREEN_GAP_AUDIT.md`
- deployment docs under `docs/deployment/`

## Quick reference commands

Frontend analyze:

`flutter analyze`

Frontend tests:

`flutter test`

Backend smoke tests:

`npm run backend:test`

Backend integration tests:

`npm run backend:test:integration`

Run backend locally:

`npm run backend:dev`

Run Flutter web locally:

`flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:4000`
