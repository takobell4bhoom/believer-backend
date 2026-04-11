# Figma Implementation Master Plan

Last updated: 2026-04-10

Status note:

- This file remains the original phased plan.
- For the current implemented-vs-partial state, read `docs/planning/SCREEN_GAP_AUDIT.md` first.
- Several items originally marked as future work here have since landed in code.

## Progress Snapshot

Completed since this plan was created:

- Phase 1 baseline stabilization has been completed.
- `flutter test` is green again.
- `flutter analyze` is green.
- backend `npm test` is green.
- Verified Figma-backed onboarding/auth-entry screen slice has been implemented as a route-ready screen without changing the app's startup flow.
- Exact Figma auth nodes have now been isolated for:
  - `Login` -> `2511:11665` (`Login Page - Empty`)
  - `Sign Up` -> `2510:11494` (`Signup Page - Empty`)
- The auth redesign slice is now implemented in Flutter for:
  - `lib/screens/login_screen.dart`
  - `lib/screens/signup_screen.dart`
  - supporting auth widgets and tests
- Exact Figma Home node has now been isolated in the user-provided Figma copy:
  - `Home Page #1` -> `812:1551`
- A conservative Home redesign slice is now implemented in Flutter for:
  - `lib/screens/home_page_1.dart`
  - supporting widget coverage in `test/home_page_1_test.dart`
- Exact Figma mosque nodes have now been isolated for:
  - `Mosque Listing` -> `2064:13852`
  - `Sort & Filter - Mosques` -> `2355:10414`
  - `Mosque Page` -> `1864:4926`
- A conservative Mosque Listing + Sort/Filter redesign slice is now implemented in Flutter for:
  - `lib/screens/mosque_listing.dart`
  - `lib/screens/sort_filter_mosque.dart`
  - supporting widget coverage in `test/sort_filter_mosque_test.dart`
- A conservative Mosque Page redesign slice is now implemented in Flutter for:
  - `lib/screens/mosque_page.dart`
  - supporting widget coverage in `test/mosque_page_test.dart`
- Exact Figma notification/prayer nodes have now been isolated for:
  - `Notifications Page - Notifications` -> `1696:11273`
  - `Notifications Page - My Mosques` companion -> `1746:19476`
  - `Prayer Notifications & Settings` full screen -> `1677:7432`
  - nested `Prayer time notifications` section -> `1685:9216`
- A conservative Notifications redesign slice is now implemented in Flutter for:
  - `lib/screens/notifications_screen.dart`
  - supporting widget coverage in `test/notifications_screen_test.dart`
- A conservative Prayer Settings redesign slice is now implemented in Flutter for:
  - `lib/screens/prayer_notifications_settings_page.dart`
  - supporting widget coverage in `test/prayer_notifications_settings_page_test.dart`
- A conservative Mosque Notification Settings redesign slice is now implemented in Flutter for:
  - `lib/screens/mosque_notification_settings.dart`
  - supporting widget coverage in `test/mosque_notification_settings_test.dart`
- A conservative business-registration status utility slice is now implemented in Flutter for:
  - `lib/screens/business_registration_status/business_registration_intro_screen.dart`
  - `lib/screens/business_registration_status/business_registration_rejected_screen.dart`
  - `lib/screens/business_registration_status/business_registration_under_review_screen.dart`
  - `lib/screens/business_registration_status/business_registration_live_screen.dart`
  - local helper composition in `lib/screens/business_registration_status/business_registration_status_widgets.dart`
  - this slice has since been assembled into a feature-local frontend flow with named routes, authenticated entry, backend draft/review/live continuity, and explicit rejected-state feedback
- Home screen test brittleness was reduced by:
  - fixing the event card overflow
  - replacing the home mosque card network-image decoration path with an error-tolerant image widget
  - updating the stale boot test to match current mock-data app behavior
- Compact-viewport overflow hardening has been expanded by:
  - fixing the prayer-settings Suhoor/Iftar row overflow under constrained widths
  - adding compact-viewport widget regression coverage for prayer settings
  - adding compact-viewport widget regression coverage for mosque notification settings

Remaining follow-up under the broader Phase 1/Phase 2 boundary:

- continue reducing prototype/test-only brittleness where it appears in future screen slices
- keep removing hidden assumptions from mock-data-driven UI
- continue replacing static Home content where real data paths do not yet exist:
  - broader events/business depth
  - remaining promo/content modeling
- continue auth-journey follow-up beyond the now-live login/signup/password-recovery slices:
  - any deeper verification-code/auth continuation screens that still need dedicated comparison
- continue exact node isolation and comparison for the next Phase 4 target:
  - secondary engagement/content screens adjacent to the mosque-notifications path
- keep the business-registration frontend assembly scoped to its feature-local flow/controller layer and the minimal super-admin moderation queue; broader admin dashboards and post-publish revision tooling remain out of scope

## Objective

Build the Believers Lens app so the shipped product matches the intended Figma experience as closely as possible while preserving the working architecture that already exists in this repository.

This plan is intentionally conservative:

- No broad rewrite unless a specific module becomes unsalvageable.
- No destructive API or schema changes unless explicitly planned and documented.
- No "finish every screen at once" approach.
- One vertical slice at a time, with verification after each slice.

## Current Reality

The project is already beyond the wireframe stage:

- Auth is real and backed by Fastify + PostgreSQL.
- Nearby mosque discovery is real.
- Mosque detail and bookmarks are real.
- Prayer settings persistence exists.
- Shared navigation and shared widgets exist.

The project is not yet design-faithful:

- Several screens still use hardcoded content and prototype placeholders.
- Design tokens are too shallow for high-fidelity implementation.
- Test coverage is not stable enough to protect UI regressions.
- Some flows appear visually complete but are not backed by complete data models or backend endpoints.

## Main Constraints

### Constraint 1: Figma source ambiguity

The currently shared Figma link opens on `Competitive Analysis`, not directly on product screens.

Implication:

- Do not use `Ui-scan/*.md` as a design source for UI implementation.
- Use verified Figma nodes as the only source of truth for screen design and UI building.
- Before implementation, obtain or confirm the exact Figma screen node for the target slice.

### Constraint 2: Existing architecture should be preserved

The current stack is good enough to continue:

- Flutter frontend
- Riverpod state
- Shared widget primitives
- Fastify backend
- PostgreSQL persistence

Implication:

- Refactor incrementally.
- Reuse the route map and provider structure.
- Avoid replacing the app shell unless necessary.

### Constraint 3: Prototype artifacts still exist

Examples:

- Hardcoded prayer/event content
- Static location labels
- Placeholder snackbars
- Local-only admin add flow
- Network images inside mock data and tests

Implication:

- Every screen migration must include both design fidelity work and data-hardening work.

## Safety Guardrails

These rules should be followed in future implementation chats:

1. Change one slice at a time.
2. Do not rewrite the entire theme and all screens in one pass.
3. Preserve existing named routes unless intentionally refactoring route contracts.
4. Do not break backend contracts already documented in `PROJECT_CONTEXT.md` and `API_CONTRACT.md`.
5. Replace placeholder UI with real flows only when the underlying data path exists or is added in the same slice.
6. Do not rely on live network images in tests.
7. After each slice, run:
   - `flutter analyze`
   - `flutter test`
   - `npm test` in `backend/`
8. Keep docs updated after each meaningful slice so another chat can resume cleanly.

## Recommended Build Sequence

## Phase 0: Figma Alignment Preparation

Status: `IN_PROGRESS`

### Goal

Remove ambiguity between intended design and local implementation targets.

### Tasks

- Gather direct Figma node links for:
  - Auth
  - Home
  - Mosque listing
  - Mosque detail
  - Notifications
  - Prayer settings
  - Services
  - Admin add mosque
- Treat verified Figma nodes as the only design/build reference for each target screen.
- Create a source-of-truth mapping from Figma screen to Flutter file.

### Done criteria

- Every core screen has a known verified Figma node.
- No future chat has to guess which Figma frame to match.

Current status notes:

- Verified root product canvas: `657:1636`
- Verified onboarding/setup nodes exist and are documented
- Verified auth base screen nodes exist and are documented
- Verified home/prayer component nodes exist and are documented
- Exact full `Home` screen node is now verified as `812:1551`
- Exact full `Prayer Notifications & Settings` screen node is now verified as `1677:7432`

## Phase 1: Stabilize the Base Before More UI Work

Status: `COMPLETED (baseline)`

### Goal

Make the existing app safe to iterate on.

### Tasks

- Fix current Flutter test failures.
- Remove network-dependent images from widget-test paths.
- Fix the home event card overflow.
- Update stale boot/auth tests.
- Ensure test runs reflect the current auth hydration behavior.

### Target areas

- `lib/screens/home_page_1.dart`
- `lib/data/mock_data.dart`
- `test/widget_test.dart`
- any test files affected by auth bootstrap

### Done criteria

- `flutter analyze` passes.
- `flutter test` passes.
- `npm test` passes.
- No known layout overflow remains on the home screen test path.

Outcome:

- Completed on 2026-03-26.
- This establishes a safer baseline for the design-system and screen-fidelity passes that follow.

## Phase 2: Expand the Design System

### Goal

Create enough reusable design primitives to support Figma-faithful builds without repeating screen-specific styling logic.

### Tasks

- Expand typography tokens:
  - display
  - heading
  - title
  - label
  - caption
  - badge
- Expand spacing and radius tokens where the design demands it.
- Add reusable style patterns for:
  - section headers
  - cards
  - chips
  - badges
  - tab bars
  - filter pills
  - screen top bars
  - empty/error/loading states
- Normalize icon sizing and interactive hit areas.
- Document token usage rules.

### Target areas

- `lib/theme/app_theme.dart`
- `lib/theme/app_colors.dart`
- `lib/theme/app_tokens.dart`
- `lib/widgets/common/*`
- new shared widgets if needed

### Done criteria

- Core screens can be rebuilt from reusable tokens/components rather than ad hoc local styling.
- Visual hierarchy is consistent across screens.

## Phase 3: Rebuild Core Screens to Match Design

Current status: `IN_PROGRESS`

Phase 3 status notes:

- Auth sub-slice for base `Login` and `Sign Up` screens completed on `2026-03-26` against verified Figma nodes.
- Home sub-slice for verified `Home Page #1` completed on `2026-03-26` against exact node `812:1551`.
- Mosque Listing sub-slice completed on `2026-03-26` against exact node `2064:13852`.
- Sort/Filter companion sub-slice completed on `2026-03-26` against exact node `2355:10414`.
- Mosque Page sub-slice completed on `2026-03-26` against exact node `1864:4926`.
- Notifications sub-slice completed on `2026-03-26` against exact node `1696:11273` with companion node `1746:19476`.
- Prayer Settings sub-slice completed on `2026-03-26` against exact full-screen node `1677:7432` with nested section reference `1685:9216`.
- Mosque Notification Settings sub-slice completed on `2026-03-26` against exact node `1793:2921`.
- Startup flow remains intentionally unchanged.
- Phase 3 core-screen order is now complete.
- Next correct target is the next Phase 4 secondary engagement/content screen that can be advanced without route-contract or backend-contract churn.

### Goal

Bring the highest-traffic user journey close to the Figma first.

### Order

1. Auth
2. Home
3. Mosque listing
4. Mosque page
5. Notifications
6. Prayer settings

### Why this order

- This is the main first-run and daily-use journey.
- It provides the biggest visual payoff quickly.
- It also touches the screens with the highest user trust impact.

### Slice expectations for each screen

Each screen slice should include:

- visual fidelity work
- data correctness review
- interaction cleanup
- regression tests
- doc update

### Done criteria

- Screen structure matches intended design direction.
- Hardcoded placeholder content is removed where it should be real.
- Navigation and state transitions are stable.
- Tests cover the screen's critical states.

## Phase 4: Complete Secondary User Flows

### Goal

Bring the supporting discovery and engagement flows up to the same standard.

Current status notes:

- Services Search and Business Listing are already in the active secondary-discovery stack.
- Business registration now has a real authenticated frontend path with named routes, a feature-local typed draft/controller layer, temporary draft persistence, and under-review/live route wiring, but backend submit/review/live contracts are still pending.

### Screens

- Event search
- Event listing
- Event detail
- Leave review
- Review confirmation
- Mosque notification settings
- Broadcast screen
- Services search
- Business listing
- Business registration
- Sort/filter modal

### Done criteria

- Each screen is reachable through a real app path.
- No major placeholder interactions remain.
- Screen layouts follow the shared design system.

## Phase 5: Finish Content Operations and Admin Flows

### Goal

Replace local-preview behavior with real content operations.

### Highest priority

- `MosqueAdminAddScreen`

### Required changes

- Validate form inputs robustly.
- Submit through backend instead of local-only store mutation.
- Add server-side route/service support if missing.
- Return stable error states.
- Reflect successful submissions in discovery flows.

### Target areas

- `lib/screens/mosque_admin_add_screen.dart`
- `lib/data/mosque_provider.dart`
- `backend/src/routes/mosques.js`
- supporting backend services and tests

### Done criteria

- Admin add mosque is real, not preview-only.
- Submitted content can be discovered through normal user flows.

## Phase 6: Production Polish

### Goal

Harden the app for confidence, continuity, and future scaling.

### Tasks

- Improve empty/error messaging consistency.
- Improve loading and retry states.
- Review accessibility basics:
  - text scaling
  - contrast
  - tap targets
  - semantic labels where needed
- Add more widget tests and golden-style regression checks where practical.
- Remove leftover prototype copy and stale TODO migrations.

### Done criteria

- No obvious prototype artifacts remain in primary flows.
- The app is stable enough for continued iteration without regressions.

## Immediate Next Plan

If resuming work in a fresh chat, this is the best next execution order:

1. Phase 1: stabilize tests and remove UI brittleness.
2. Phase 2: expand the design system.
3. Phase 3A: auth redesign pass for `Login` + `Sign Up` is completed.
4. Phase 3B: verified `Home` redesign pass is completed for the current shell/data-preserving slice.
5. Phase 3C: verified `Mosque Listing` + `Sort & Filter - Mosques` redesign slice is completed.
6. Phase 3D: verified `Mosque Page` redesign slice is completed.
7. Phase 3E: verified `Notifications` redesign slice is completed.
8. Phase 3F: verified `Prayer Settings` redesign slice is completed.
9. Phase 4A: `Mosque Page - Notification Settings` against verified node `1793:2921` is completed.
10. Phase 4B: advance the next secondary engagement/content screen in a similarly conservative verified slice.

This is the highest-leverage path because:

- It improves confidence first.
- It avoids building more screens on a weak visual foundation.
- It focuses effort on the screens users see most often.

## Definition of Success

This project should be considered "aligned with Figma direction" when:

- core screens visually match the approved Figma frames
- the app no longer depends on obvious placeholder behavior
- data-backed screens are truly data-backed
- design tokens and shared components are strong enough to carry the rest of the app
- test runs are green and useful
- future chats can continue from docs without rediscovering the project state
