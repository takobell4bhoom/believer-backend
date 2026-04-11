# Public Launch Hardening Prompts

Use these prompts one at a time in a fresh Codex chat. Do not start the next prompt until the current one is implemented, tested, and documented.

## Shared rules for every prompt

```text
Work like a seasoned senior software engineer and launch-focused CTO.

Rules:
- Use the code-review graph first for context. If graph is unavailable or insufficient, fall back to direct repo inspection with rg/sed/git.
- Do not hallucinate. Read the exact files before deciding on a fix.
- Edit only the minimum files required for the task.
- Before editing, list the exact files you plan to touch and why.
- After editing, update the relevant markdown docs so launch status stays current.
- Prefer updating existing docs first:
  - docs/deployment/PUBLIC_QA_CHECKLIST.md
  - docs/deployment/PUBLIC_LAUNCH_RUNBOOK.md
  - docs/planning/PUBLIC_LAUNCH_HARDENING_PROMPTS.md
- Run the smallest meaningful impacted tests first, then broader impacted tests.
- If tests fail, fix them or clearly prove they are unrelated before finishing.
- Final response must include:
  1. what changed
  2. exact files changed
  3. tests run and results
  4. remaining risks or follow-ups
- Never make unrelated cleanup changes.
```

## Prompt 1

```text
Use the shared rules above.

Task:
Make the public location experience honest and launch-safe.

Inspect first:
- lib/screens/location_setup_screen.dart
- lib/services/current_location_service.dart
- lib/services/current_location_service_stub.dart
- lib/services/current_location_service_web.dart
- lib/screens/map_screen.dart
- lib/screens/home_page_1.dart
- lib/navigation/app_router.dart
- test/location_setup_flow_test.dart
- test/home_page_1_test.dart

Goals:
- Remove or gate public-facing native map/current-location promises that are not truly implemented.
- Keep manual location setup working smoothly.
- Keep any supported in-flow location confirmation behavior that is already real.
- Make user-facing copy honest.
- Update the launch docs and QA checklist to match the real scope.

Verification:
- Run the impacted Flutter tests, including location and home-page coverage.
```

Launch status note:
- Public location scope is manual Google-backed place search plus saved-coordinate confirmation, with current-location access on supported browsers and Android/iOS devices.
- Live in-app map browsing is out of scope for this launch and should stay explicitly framed that way in public UI and QA.
- Backend setup for that flow is a single `GOOGLE_MAPS_API_KEY` with Geocoding API and Places API enabled; no Flutter/browser map SDK key is required while map rendering remains out of scope.

Event launch status note:
- Public Events now only renders mosque-submitted published event/class records returned from the nearby-mosque backend path.
- Nearby mosques with no published program content no longer generate synthetic event cards; the event listing shows an explicit empty state instead.
- Event search and filters now evaluate real published program fields such as title, schedule, location, and description before falling back to mosque context, and missing schedule metadata stays labeled as unpublished instead of being replaced with `This week` or `EVENT`.

## Prompt 2

```text
Use the shared rules above.

Task:
Make the public services marketplace trustworthy for launch.

Inspect first:
- backend/src/services/servicesService.js
- backend/src/routes/services.js
- backend/src/services/businessListingsService.js
- lib/screens/services_search.dart
- lib/screens/business_listing.dart
- lib/services/services_search_service.dart
- lib/models/service.dart
- test/business_listing_test.dart
- test/business_registration_flow_test.dart

Goals:
- Remove or fully gate synthetic catalog data from public marketplace results.
- If marketplace remains public, guest users must be able to browse public listing discovery and detail flows without forced login.
- Keep business registration and moderation flows intact.
- Make UI copy honest if public scope is reduced.
- Update launch docs and QA checklist.

Verification:
- Run targeted backend tests for services behavior.
- Run impacted Flutter marketplace tests.
```

Launch status note:
- Prompt 2 is complete.
- Public Services now stays launch-safe by showing only approved live business listings; synthetic seed cards are out of the public feed.
- The public services query path now follows the same taxonomy labels stored by business registration and moderation, instead of relying on a smaller hardcoded alias set.
- The public Services screen now exposes broader in-app discovery across the real launch taxonomy, while keeping `Halal Food & Restaurants` as the default landing category behind the shared header's filter toggle.
- The public Services screen now defaults to the inclusive `New` sort, keeps a live owner listing visible in the same default public results, and uses filter-specific empty copy when chips like `Top Rated` hide otherwise live listings.
- The owner card on the public Services screen now reads category messaging from the backend owner-status payload's approved/public category fields instead of draft `selectedType`, and it falls back to a generic live-state message whenever that public category cannot be proven.
- Categories with no live approved listings now stay visible but render an explicit empty state instead of implying hidden or seeded inventory.
- Signed-out users can browse public services discovery and business detail pages without abrupt login redirects.
- Uploaded business registration logos now flow end to end into the public Services cards and business detail hero whenever stored logo bytes exist, with the placeholder brand mark only used as a fallback.
- Business listings now support real public review browsing plus authenticated review submission through `/api/v1/business-listings/:id/reviews`, and the public Services feed rolls up those review counts/ratings.
- Business registration and super-admin moderation remain the path for getting a listing into the marketplace.
- Migration `013_backfill_business_listing_category_fields.sql` now backfills only missing approved/public category fields and preserves non-empty stored values when legacy draft taxonomy diverges.

## Prompt 3

```text
Use the shared rules above.

Task:
Implement or honestly classify unfinished public settings and business surfaces.

Inspect first:
- lib/screens/profile_settings_screen.dart
- lib/screens/settings_detail_screens.dart
- lib/screens/business_registration_status/business_registration_live_screen.dart
- lib/navigation/app_router.dart
- test/profile_settings_screen_test.dart
- test/settings_detail_screens_test.dart
- test/business_registration_flow_test.dart

Goals:
- Fully implement feasible public settings/business surfaces like in-app feedback handoff and live-listing update plus resubmission behavior.
- Classify each remaining gap as implemented now, blocked by missing dependency, or requiring product decision.
- Keep only user-facing options that are real and trustworthy for public launch.
- Update docs to reflect the completed scope and any proven blockers.

Verification:
- Run impacted Flutter settings and business-registration tests.
```

Launch status note:
- Prompt 3 is complete.
- `Rate Us` now routes to a real in-app feedback submission flow backed by the existing account support-request endpoint.
- Live business listings now present an honest `Update Listing` path that lets owners edit details and resubmit them for moderation instead of suggesting an unsupported read-only placeholder.
- Saved businesses remain blocked for public launch because this repo only implements mosque bookmarks; business-save persistence, API routes, and UI state do not exist yet.

## Prompt 4

```text
Use the shared rules above.

Task:
Move auth session secrets out of SharedPreferences and into secure storage suitable for public launch.

Inspect first:
- lib/data/auth_provider.dart
- lib/services/auth_service.dart
- lib/services/api_client.dart
- pubspec.yaml
- test/auth_screens_test.dart
- test/widget_test.dart
- any tests touching authProvider hydration/persistence

Goals:
- Replace SharedPreferences storage for access and refresh tokens with secure storage.
- Preserve existing auth flows, hydration, logout, refresh, and profile update behavior.
- Keep non-secret preference storage separate from secret storage.
- Update docs with the new security expectation and any platform setup notes.

Verification:
- Run impacted Flutter auth tests.
- Run any broader Flutter tests needed for confidence around startup/auth state.
```

Launch status note:
- Prompt 4 is complete.
- Access and refresh tokens now hydrate from the app's secure token store, while non-secret onboarding and cached profile fields remain in `SharedPreferences`.
- Existing sessions migrate legacy `SharedPreferences` tokens into secure storage on first successful hydration so users do not get logged out by the launch hardening patch.
- For the current Flutter web launch path, secure token persistence assumes the deployed app is served over HTTPS.

## Prompt 5

```text
Use the shared rules above.

Task:
Make notification language honest for public launch and remove any implication that device push delivery already exists if it does not.

Inspect first:
- backend/src/routes/notifications.js
- lib/screens/profile_settings_screen.dart
- lib/screens/notifications_screen.dart
- lib/screens/mosque_notification_settings.dart
- lib/services/mosque_notification_settings_service.dart
- test/notifications_screen_test.dart
- test/mosque_notification_settings_test.dart

Goals:
- Align backend, UI copy, and settings labels with the actual feature: followed-mosque preferences and in-app notification/feed behavior.
- Remove misleading app-wide push language unless real delivery exists.
- Keep the actual usable notification settings experience intact.
- Update launch docs and QA checklist.

Verification:
- Run impacted backend and Flutter notification tests.
```

Launch status note:
- Prompt 5 is complete.
- Public notifications are now explicitly scoped to followed mosques plus an in-app updates feed.
- The repo still does not implement device-token registration, FCM/APNs delivery, or a real push pipeline, so all misleading push-toggle and reminder language has been removed from the public UI and launch docs.
- Mosque update settings are now limited to the supported launch categories: `Broadcast Messages` and `Events & Class Updates`.
- The Notifications feed now respects those per-mosque category settings instead of showing all followed-mosque content unconditionally.

## Prompt 6

```text
Use the shared rules above.

Task:
Get the Flutter suite green for the public-launch surface, starting with the home page regressions and then broadening only as needed.

Inspect first:
- test/home_page_1_test.dart
- lib/screens/home_page_1.dart
- any files changed by Prompts 1 to 5 that affect home navigation, copy, or auth state

Goals:
- Fix the currently failing home-page widget tests without adding brittle hacks.
- Reconcile test expectations with the final public-launch scope and copy.
- Run a broader affected Flutter test pass after targeted fixes succeed.
- Update launch docs with current test status and any remaining known risk.

Verification:
- Run targeted home-page tests first.
- Then run the broader impacted Flutter test set.
```

Launch status note:
- Prompt 6 is complete.
- `test/home_page_1_test.dart` is green on the final launch-safe home surface, including honest nearby-location messaging, supported guest CTAs, and the non-launch map framing.
- The broader representative Flutter launch-surface suite is also green:
  - `test/widget_test.dart`
  - `test/auth_screens_test.dart`
  - `test/profile_settings_screen_test.dart`
  - `test/services_search_test.dart`
  - `test/business_listing_test.dart`
  - `test/business_review_screen_test.dart`
  - `test/business_leave_review_test.dart`
  - `test/notifications_screen_test.dart`
  - `test/mosque_notification_settings_test.dart`
- No additional Flutter launch-surface regressions were found in the final pass.

## Prompt 7

```text
Use the shared rules above.

Task:
Do a final public-launch hardening pass and documentation sign-off.

Inspect first:
- docs/deployment/PUBLIC_LAUNCH_RUNBOOK.md
- docs/deployment/PUBLIC_QA_CHECKLIST.md
- docs/planning/PUBLIC_LAUNCH_HARDENING_PROMPTS.md
- git diff for all launch-hardening changes

Goals:
- Ensure launch docs match the shipped product scope exactly.
- Remove stale statements that still imply unsupported features.
- Confirm the final public-launch checklist reflects the actual smoke-test path.
- Run the final agreed backend and Flutter verification suite.

Verification:
- Run the final backend and Flutter test commands that best represent launch readiness.
- Summarize residual risks only if they are real and still unresolved.
```

Launch status note:
- Prompt 7 is complete.
- The final representative launch-readiness suite is green when run through the repo's supported commands:
  - `node --test backend/test/app.test.js`
  - `flutter test test/home_page_1_test.dart`
  - `flutter test test/widget_test.dart test/auth_screens_test.dart test/profile_settings_screen_test.dart test/services_search_test.dart test/business_listing_test.dart test/business_review_screen_test.dart test/business_leave_review_test.dart test/notifications_screen_test.dart test/mosque_notification_settings_test.dart`
  - `npm --workspace backend run test:integration`
- The backend integration suite must be run through `npm --workspace backend run test:integration` because that command prepares the dedicated migrated `believer_test` database before executing `backend/test/integration.api.test.js`.
- Signup welcome-email delivery now stays covered through the real backend email-service path, and the Resend request contract is regression-tested so launch smoke can validate welcome-email delivery separately from password reset.
- Community and mosque-admin signup now share the same full-name, email, and password flow, with account-type selection preserved and no separate mosque-admin access code gate in the backend or UI.
- This final pass found no remaining launch blocker in the verified Flutter/backend public-launch surface.
- Saved businesses remains a separate backend/data-model track and is still correctly treated as out of scope rather than a newly discovered blocker.
