# Public QA Checklist

Use this after staging sign-off or immediately after a production deploy on the current single-VM stack.

## Browser and routing

- `https://app.example.com` loads successfully.
- Refreshing a deep link still serves the Flutter app.
- No obvious missing asset errors appear in the browser console.

## API connectivity

- The frontend sends requests to `https://api.example.com`.
- `https://api.example.com/health` returns healthy.
- No CORS errors appear during normal navigation.

## Core public smoke flow

- Create or log in with both a community and a mosque-admin test account.
- Confirm both account types use the same full-name, email, and password sign-up flow, and mosque-admin sign up does not request an extra access code.
- If transactional email is enabled for the environment, confirm signup triggers the welcome email.
- In location setup, confirm typed place search returns real Google-backed suggestions and coordinate confirmation works end to end.
- On supported browsers running in a secure context plus Android/iOS devices, confirm current-location permission flow is honest: success saves coordinates, denial still leaves manual entry available, and unsupported platforms fall back cleanly to manual entry.
- Confirm the Home and Events location affordances both open the location hub.
- Confirm the location hub shows current-location lookup only when the platform actually supports it, while keeping Google-backed typed search available everywhere and still stating that live in-app map browsing is out of scope for this launch.
- Open Events and confirm the listing only shows mosque-submitted published events/classes, not one synthetic card per nearby mosque.
- If nearby mosques have no published events/classes, confirm the Events screen shows the explicit empty state instead of filler content.
- Apply at least one event filter or search term and confirm results narrow against real published program titles/details, not synthetic defaults like `This week` or `EVENT`.
- On Home, confirm `EVENTS AROUND YOU` shows real published mosque events only; if none exist nearby, it must show the empty state instead of static demo cards.
- Open the public Services marketplace while signed out.
- Confirm only approved live business listings appear; no placeholder or synthetic catalog cards should be visible.
- Confirm the public Services screen offers multiple real taxonomy categories, starting with `Halal Food & Restaurants`.
- Confirm the shared Services header uses the standard back/title/filter pattern, and tapping the filter button reveals the category plus sort/filter controls instead of leaving those chips permanently visible.
- Confirm the default Services feed keeps the `New` chip active and still includes all live listings in the browsed category, ordered newest-first by publish time.
- Switch to at least one non-default category such as `Health & Wellness` or `Professional & Business Services` and confirm the query still uses the same moderation-approved business-registration taxonomy labels.
- If the signed-in test account has a live listing in the currently browsed Services category, confirm the owner card still says the listing is live and the same business appears in the unfiltered public results for that category.
- If the signed-in test account has a live listing in a different Services category, confirm the owner card explicitly names that other category only when the backend owner-status payload exposes the approved public category fields that also drive feed membership.
- If the signed-in test account has a live listing but the backend owner-status payload does not expose approved public category fields, confirm the owner card falls back to a generic live-state message instead of guessing a category from draft taxonomy.
- Apply `Top Rated` or another restrictive chip and confirm an empty result set says no listings match the active chip, not that no live listings exist in the category.
- Open a business listing while signed out and confirm the detail page loads without a forced login redirect.
- If a live business has an uploaded registration logo, confirm the Services card and business detail hero render that uploaded logo instead of the placeholder brand mark.
- Open `Read all reviews` for a live business and confirm published business reviews load successfully for signed-out browsing.
- While signed in with a community account, submit one business review and confirm the detail page and Services summary reflect the updated review count/rating after refresh.
- Confirm marketplace empty states and owner CTA copy stay honest when a browsed category has no live approved listings.
- Sign in and open Profile & Settings.
- After sign-in, refresh the app and confirm the session still hydrates without any `auth.access_token` or `auth.refresh_token` entries remaining in browser `SharedPreferences` storage.
- Confirm the deployed app is served over HTTPS before relying on browser secure-storage session persistence.
- Confirm Rate Us opens the in-app feedback form and a submission succeeds.
- Confirm Support still submits a standard support request successfully.
- Confirm Profile & Settings shows `Mosque Updates` and does not expose an app-wide push-notification toggle.
- Start or resume a business listing from Profile & Settings and confirm the owner flow is available.
- If the test account already has a live listing, confirm the live status screen offers `Update Listing` plus a resubmission path instead of implying instant live edits.
- Confirm Profile & Settings does not claim saved businesses are available yet.
- Load the mosque listing.
- Open a mosque detail page.
- Follow that mosque and confirm the available update categories are limited to `Broadcast Messages` and `Events & Class Updates`.
- Confirm no mosque settings screen claims device push, iqamah reminders, or background reminder delivery.
- Confirm followed mosques appear under Notifications > `My Mosques`.
- Confirm the Notifications feed shows in-app broadcast, event, and class updates from followed mosques only.
- Disable one category such as `Events & Class Updates` for a followed mosque and confirm that category stops appearing in the in-app feed for that mosque.
- Confirm at least one backend-backed action succeeds.
- Upload a test image and verify it renders from `/uploads/`.

## Operational checks

- Backend service is active in `systemd`.
- Nginx config test passes.
- Backend logs include enough detail to diagnose any failed welcome-email delivery without blocking signup.
- Logs do not show repeated 5xx responses.
- Latest database backup and uploads backup are present.

## Launch-only final checks

- DNS points at the intended VM.
- HTTPS certificates are active for app and API domains.
- `CORS_ORIGIN` matches the app domain.
- `PUBLIC_API_ORIGIN` matches the API domain.
- `GOOGLE_MAPS_API_KEY` is present on the backend and loaded at runtime.
- The Google Cloud project for that key has billing enabled, `Geocoding API` enabled, and the current legacy `Places API` enabled for the backend autocomplete/details endpoints.
- If typed location search still fails, validate the backend key directly before changing code:
  `geocode/json` must not return `REQUEST_DENIED` with `This API is not activated on your API project`.
  `place/autocomplete/json` and `place/details/json` must not return `REQUEST_DENIED` with `LegacyApiNotActivatedMapError`.
  Treat those exact messages as API-enablement issues first; billing and key restrictions return different Google `error_message` values.
- API key restrictions allow server-side requests from the backend host. Do not use an HTTP referrer-only browser key for typed search or place resolve.
- Android release builds include coarse/fine location permissions, and iOS builds include the when-in-use location usage string.
- No Google Maps SDK key is configured for Flutter web/mobile unless in-app map rendering is intentionally added later.
- The release notes include the exact rollback target.
