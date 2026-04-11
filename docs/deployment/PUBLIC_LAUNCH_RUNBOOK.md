# Public Launch Runbook

This runbook is for the current production path only:

- One Azure Ubuntu VM
- Nginx serving the Flutter web build
- Backend running under `systemd`
- PostgreSQL on the same VM or an Azure PostgreSQL instance
- Uploaded files stored on the VM at `backend/uploads/`

Use this document with:

- `docs/deployment/AZURE_UBUNTU_VM.md`
- `docs/deployment/BACKUP_RESTORE.md`
- `docs/deployment/PUBLIC_QA_CHECKLIST.md`

## Launch blockers to clear before go-live

- Production DNS records exist for `app.example.com` and `api.example.com`.
- HTTPS certificates are issued and active for both hostnames.
- The backend returns `200 OK` from `https://api.example.com/health`.
- The frontend is built with `--dart-define=API_BASE_URL=https://api.example.com`.
- The deployed frontend origin is HTTPS so browser secure storage can hydrate auth sessions reliably.
- `CORS_ORIGIN` matches the final frontend origin, including scheme.
- `PUBLIC_API_ORIGIN` matches the final API origin, including scheme.
- A fresh PostgreSQL backup has been taken before any migration.
- The `backend/uploads/` directory is included in backup coverage.
- A named rollback target is identified before deploy begins.

## Canonical pre-launch verification commands

Run the repo-level verification suite before a public deploy:

```bash
node --test backend/test/app.test.js
flutter test test/home_page_1_test.dart
flutter test test/widget_test.dart test/auth_screens_test.dart test/profile_settings_screen_test.dart test/services_search_test.dart test/business_listing_test.dart test/business_review_screen_test.dart test/business_leave_review_test.dart test/notifications_screen_test.dart test/mosque_notification_settings_test.dart
npm --workspace backend run test:integration
```

Verification note:

- Use `npm --workspace backend run test:integration` for backend integration coverage, not a raw `node --test backend/test/integration.api.test.js` invocation.
- The integration script prepares the dedicated `believer_test` database, runs migrations, and then executes the real API assertions against that migrated schema.
- A raw `node --test` run can fail before the suite starts if the local integration database has not been migrated to include the latest tables such as `business_listing_reviews`.

## Production env checklist

Minimum backend env values, based on `backend/.env.production.example`:

- `NODE_ENV=production`
- `HOST=127.0.0.1`
- `PORT=4000`
- `TRUST_PROXY=true`
- `DATABASE_URL=postgresql://...`
- `JWT_SECRET=<32+ char random secret>`
- `JWT_EXPIRES_IN=15m`
- `REFRESH_TOKEN_TTL_DAYS=30`
- `RESEND_API_KEY=...`
- `EMAIL_FROM=...`
- `EMAIL_REPLY_TO=...`
- `APP_WEB_ORIGIN=https://app.example.com`
- `PASSWORD_RESET_URL_BASE=https://app.example.com/#/reset-password`
- `PASSWORD_RESET_TOKEN_TTL_MINUTES=60`
- `CORS_ORIGIN=https://app.example.com`
- `PUBLIC_API_ORIGIN=https://api.example.com`
- `GOOGLE_MAPS_API_KEY=...` if manual location search, place resolution, or reverse lookup is used in production
- `ALADHAN_BASE_URL=https://api.aladhan.com/v1`
- `ALADHAN_TIMEOUT_MS=5000`

Frontend auth storage expectation:

- Access and refresh tokens should persist through the app's secure token store, not plain `SharedPreferences`.
- Non-secret onboarding and cached profile fields may still live in `SharedPreferences`.
- For the current Flutter web launch path, secure token persistence depends on serving the app over HTTPS with the production origin locked down.

Location/event launch scope note:

- Typed location search, place resolution, and reverse lookup are backend-backed Google APIs only; the Flutter client does not need a browser JavaScript Maps key for this launch.
- The current backend implementation calls Google Geocoding plus the legacy Places web-service endpoints at `/maps/api/place/autocomplete/json` and `/maps/api/place/details/json`.
- The Google Cloud project used by `GOOGLE_MAPS_API_KEY` must have billing enabled, `Geocoding API` enabled, and the current `Places API` enabled for those legacy server-side endpoints. If only `Places API (New)` is enabled, the current code path will return `REQUEST_DENIED`.
- API key restrictions must allow backend/server-side web-service requests. Do not use an HTTP referrer-only browser key for this backend flow.
- Before a deploy or smoke test, verify the backend key itself against Google directly. `Geocoding API` and legacy `Places API` are separate enablement checks for the current implementation, so one can still fail even when the other works.
- Direct key validation commands:

```bash
node --input-type=module -e "import dotenv from 'dotenv'; dotenv.config({ path: './backend/.env' }); const key = process.env.GOOGLE_MAPS_API_KEY; for (const url of [ `https://maps.googleapis.com/maps/api/geocode/json?address=Bengaluru&key=${encodeURIComponent(key)}`, `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Bengaluru&types=geocode&key=${encodeURIComponent(key)}` ]) { const response = await fetch(url); console.log(await response.text()); }"
```

- Expected direct Google result:
  `status: OK` or `ZERO_RESULTS` is healthy for the specific endpoint being checked.
  `Geocoding API` not enabled returns `REQUEST_DENIED` with `This API is not activated on your API project`.
  Legacy Places autocomplete/details not enabled returns `REQUEST_DENIED` with `LegacyApiNotActivatedMapError`.
  Billing and key-restriction failures return different Google `REQUEST_DENIED` messages, so capture the exact upstream `error_message` before changing app code.
- Current-location lookup is supported only on secure web contexts such as HTTPS or localhost plus Android/iOS via device geolocation permissions.
- Android release builds must keep `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION`, and iOS builds must keep `NSLocationWhenInUseUsageDescription`, for native current-location lookup to work.
- In-app map browsing/rendering is still out of scope, so no Flutter Google Maps SDK key is required unless that scope changes later.
- The public map/location hub should only show real location flows for the current platform: current location where supported, otherwise Google-backed typed search only.
- The Home and Events location affordances should both route into that same location hub.
- The public Events surface only shows mosque-submitted published event/class records. Nearby mosques without published program content must render the honest empty state instead of synthetic listing cards, and unpublished schedules must stay labeled as unpublished instead of falling back to filler values.

## Release order

1. Confirm the last known good commit, backup file names, and rollback owner.
2. Take a PostgreSQL backup and verify the backup file exists.
3. Snapshot or archive `backend/uploads/`.
4. Pull the target release onto the VM.
5. Install Node dependencies with `npm ci`.
6. Install Flutter dependencies with `flutter pub get`.
7. Build the frontend:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

8. Run backend migrations before restarting traffic-serving services:

```bash
npm run backend:migrate
```

9. Restart the backend:

```bash
sudo systemctl restart believer-backend
sudo systemctl status believer-backend
```

10. Validate Nginx config if it changed, then reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

11. Run the smoke test flow below before announcing launch complete.

## Migration order and safety notes

- Always take the PostgreSQL backup before `npm run backend:migrate`.
- Do not deploy schema-changing code without a matching pre-deploy database backup.
- If a migration fails, stop and resolve it before restarting the backend service.
- If a migration succeeds but creates a production issue, restore the pre-deploy backup only after confirming the rollback plan for any data written after the deploy started.

## Smoke test flow

Run these checks in order after the release is live:

1. `curl https://api.example.com/health`
2. Load `https://app.example.com` and confirm the app shell loads without console 404s for core assets.
3. Use browser devtools to confirm frontend API calls point at `https://api.example.com`.
4. Confirm CORS allows requests from `https://app.example.com` only as intended.
5. Sign up or log in with both a community and a mosque-admin test account.
6. Confirm mosque-admin sign up uses the same full-name, email, and password flow and does not prompt for an extra access code.
7. If transactional email is enabled for launch, confirm that signup sends the welcome email successfully.
8. Refresh the app and confirm the session rehydrates while browser `SharedPreferences` no longer contains `auth.access_token` or `auth.refresh_token`.
9. In location setup, verify typed place search returns real Google-backed suggestions and coordinate confirmation completes successfully.
   If this step fails with backend `503 LOCATION_LOOKUP_UNAVAILABLE`, inspect backend logs for Google `REQUEST_DENIED` and confirm billing, `Geocoding API`, legacy `Places API`, and server-side key restrictions for `GOOGLE_MAPS_API_KEY`.
   If direct geocoding returns `This API is not activated on your API project`, enable `Geocoding API`.
   If direct Places autocomplete/details returns `LegacyApiNotActivatedMapError`, enable the legacy `Places API` for the current backend key/project.
10. In a supported secure browser context or Android/iOS build, verify current-location permission success and denial both show honest outcomes without blocking manual entry.
11. Open the location hub from both Home and Events and verify it shows current-location lookup only where supported, always keeps typed search available, and still makes it clear that live in-app map browsing is not part of launch.
12. Open Events and verify the listing only shows mosque-submitted published events/classes from nearby mosques.
13. If the nearby mosques have no published program content, verify the Events empty state says so explicitly instead of showing filler.
14. Open an event without a published schedule and verify the UI says `Schedule not published` instead of inventing timing text such as `This week`.
15. Open the public Services marketplace while signed out and confirm only approved live business listings are visible, with the default feed using the same taxonomy label the listing stored at registration time (`Halal Food & Restaurants` for the launch entry point).
16. Confirm the shared Services header uses the standard back/title/filter pattern, and that tapping the filter button reveals the category plus sort/filter controls instead of leaving those chips permanently visible.
17. Confirm the default Services feed keeps the `New` chip active, still shows all live listings in the category, and orders them newest-first by `published_at`.
18. If the signed-in account owns a live listing in the currently browsed Services category, confirm the owner card can say `Your listing is live` while the unfiltered public results still include that listing in the same category.
19. If the signed-in account owns a live listing in a different Services category, confirm the owner card explicitly names that other category only when the owner-status payload includes the same approved public category fields the feed uses.
20. If those approved public category fields are absent on owner status, confirm the owner card falls back to a generic live-state message instead of naming a category from draft taxonomy.
21. Apply `Top Rated` or another restrictive chip and confirm the empty state says no listings match the active chip instead of claiming no live listings exist.
22. Use the in-screen category picker to browse at least one non-default live taxonomy category and confirm the results still come from the same real registration taxonomy.
23. Switch to one category with no live listings and confirm the empty state stays explicit instead of implying hidden inventory.
24. Open one live business listing while signed out and confirm the detail page stays browsable without redirecting to login, while any uploaded business logo renders instead of the placeholder brand mark.
25. Open `Read all reviews` for that business and confirm review browsing works publicly.
26. Sign in with a community account, submit one business review, and confirm the listing review count/rating update on the detail page and public Services summary after refresh.
27. Sign in, open Profile & Settings, and verify `Rate Us` submits in-app product feedback successfully.
28. From the same screen, verify `Support` still submits a normal support request successfully.
29. From the same screen, confirm the app shows `Mosque Updates` and does not expose an app-wide push-notification toggle.
30. If the account has a live business listing, open the listing status flow and confirm the CTA is `Update Listing`, with copy that makes resubmission for moderation explicit.
31. Confirm the app does not expose a saved-businesses settings surface that implies unsupported persistence.
32. Load the mosque list.
33. Open one mosque detail page.
34. Follow that mosque and confirm the available update categories are limited to `Broadcast Messages` and `Events & Class Updates`.
35. Confirm no mosque settings screen claims device push, iqamah reminders, or background reminder delivery.
36. Open Notifications and confirm the same mosque appears under `My Mosques`.
37. Confirm the Notifications feed shows only in-app broadcast, event, and class updates from followed mosques.
38. Disable one category such as `Events & Class Updates` for a followed mosque and confirm that category no longer appears in the in-app feed for that mosque.
39. Confirm a backend-backed write path that does not require production data cleanup policy changes.
40. Upload one image and confirm the returned URL is served from `https://api.example.com/uploads/...`.
41. Verify one password-reset email flow if email sending is part of launch scope.
42. Confirm backend logs show healthy traffic without repeated 5xx responses.

Migration safety note:

- Migration `013_backfill_business_listing_category_fields.sql` must only fill blank approved/public category columns from `basic_details.selectedType`.
- Existing non-empty approved/public category values must remain unchanged, even if the draft taxonomy stored in `basic_details.selectedType` differs.

## DNS, HTTPS, CORS, and API base URL checks

- `app.example.com` should resolve to the public VM IP.
- `api.example.com` should resolve to the public VM IP.
- Nginx should serve the Flutter build for `app.example.com`.
- Nginx should reverse proxy `api.example.com` to `127.0.0.1:4000`.
- HTTPS should terminate at Nginx for both domains before public launch.
- `CORS_ORIGIN` should be the final browser origin, not the API origin.
- `PUBLIC_API_ORIGIN` should be the final public API URL used in upload links.
- The Flutter build command must use the same API base URL as `PUBLIC_API_ORIGIN`.
- `GOOGLE_MAPS_API_KEY` should enable Google Geocoding API plus the currently used legacy Places web-service endpoints for backend location search/resolve calls.
- If Google returns `REQUEST_DENIED` with a message about a legacy API not being enabled, enable the legacy `Places API` for the current backend implementation or migrate the backend to the new Places API before launch.
- Key restrictions must be compatible with server-to-server requests from the backend host; browser referrer-only restrictions will break localhost and production backend lookups.
- Native current-location lookup does not need a Google Maps SDK key; it depends on browser/device permission plus the existing Android/iOS location entitlements already checked into the app.
- Do not provision a Flutter Google Maps SDK key for this release unless in-app map rendering is intentionally added.

## Backup expectations

- Take a new PostgreSQL backup immediately before production migration.
- Keep at least one tested restore path for the most recent pre-launch backup.
- Include `backend/uploads/` in the same release checkpoint as the database backup.
- Store backup files outside the live deploy directory when possible.

## Rollback notes

- The fastest rollback path is to redeploy the last known good release onto the VM and restart `believer-backend`.
- If the release included schema changes, pair the code rollback with the matching pre-deploy PostgreSQL backup when necessary.
- Restoring the database without restoring `backend/uploads/` can leave broken file references.
- Restoring `backend/uploads/` without restoring the matching database can leave orphaned files.
- After rollback, rerun the same smoke checks as a normal deploy.

## Launch sign-off checklist

- Frontend CI is green.
- Backend CI is green.
- Production env file is present and reviewed.
- Backup files are created and named.
- Migration completed successfully.
- Backend service is healthy under `systemd`.
- Nginx config is valid and reloaded.
- Smoke tests passed.
- Rollback owner knows the backup file name and target release commit.
