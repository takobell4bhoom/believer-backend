# Screen Gap Audit

Last updated: 2026-04-10

## How to read this file

Status labels:

- `Real`: backed by working logic or backend data
- `Partial`: partly real, partly hardcoded/prototype
- `Prototype`: mostly visual or local-only behavior

Design fidelity labels:

- `Low`
- `Medium`
- `High`

Priority labels:

- `P0`: do next
- `P1`: do soon after core screens
- `P2`: do after primary journey is stable

## Core Journey

| Screen | Main file | Current status | Design fidelity | Major gaps | Priority |
|---|---|---:|---:|---|---:|
| Login | `lib/screens/login_screen.dart` | Real | Medium | Base Figma auth shell is now implemented, auth entry now starts with explicit `User Login` vs `Mosque Admin Login` mode selection, validation/auth errors stay user friendly, forgot-password now routes into a live email-reset request flow, and reset-password is direct-link safe for Flutter web hash routes, but social-auth and broader account-governance surfaces still remain out of scope | P1 |
| Sign Up | `lib/screens/signup_screen.dart` | Real | Medium | Base Figma auth shell is now implemented, auth entry now starts with explicit `User Sign Up` vs `Mosque Admin Sign Up` mode selection, admin signup still keeps the access-code requirement, password/access-code guidance remains intact, and signup now triggers a lightweight non-blocking welcome email when backend email is configured, but deeper auth continuation screens still need dedicated review | P1 |
| Home | `lib/screens/home_page_1.dart` | Partial | High | Verified Figma shell, PNG-led mobile fidelity refinement, extracted shared primitives, featured-mosque backend prayer-time hydration, uploaded-cover-image rendering on the featured mosque card, honest selected-day/back-forward prayer behavior, today-only live prayer-window progress, and one conservative `Others` live-data/auth-state pass are now implemented, but one business promo and broader Home live-data depth still remain | P0 |
| Mosque Listing | `lib/screens/mosque_listing.dart` | Real-Partial | Medium-High | Verified Figma shell is now implemented, card summaries now use persisted review/content/bookmark/verification data more honestly, and mosque thumbnails now use the mosque's uploaded cover image in a safer landscape treatment, but per-card live prayer-time depth still remains | P0 |
| Mosque Page | `lib/screens/mosque_page.dart` | Real-Partial | High | Verified Figma shell plus a PNG-led fidelity refinement are now implemented, page-level summary/meta copy now aligns with honest listing payload semantics, backend daily prayer reads now power both today IQAMAH and a conservative weekly in-app sheet, and uploaded mosque images now render in a shared landscape-first 16:9 hero/slider treatment, but deeper mosque engagement models still remain | P0 |
| Notifications | `lib/screens/notifications_screen.dart` | Real-Partial | Medium | Verified Figma shell is now implemented, `My Mosques` now hydrates from persisted backend data, and shared section-heading primitives are now reused, but feed/event/broadcast modeling and deeper routing are still pending | P1 |
| Prayer Settings | `lib/screens/prayer_notifications_settings_page.dart` | Real-Partial | High | Verified Figma shell plus a PNG-led refinement are now implemented, but prayer/date/location content is still local/static and exact assets/fonts remain approximate | P1 |
| Profile & Settings | `lib/screens/profile_settings_screen.dart` | Real | High | A compact PNG-led logged-in shell is now routed from Home’s menu icon and includes honest profile editing, real authenticated password change, a launch-safe account deactivation flow, lightweight About/Privacy/FAQ/Rate/Support/Suggest screens, logout, user/admin variants, owned-mosque admin entry points, a minimal super-admin business-moderation entry, and a real `Register as a Business` entry into the authenticated backend-backed registration flow, but saved-business/account surfaces beyond that entry still remain out of scope | P0 |

## Entry and Setup

| Screen | Main file | Current status | Design fidelity | Major gaps | Priority |
|---|---|---:|---:|---|---:|
| Onboarding / Auth Entry | `lib/screens/onboarding_screen.dart` | Real-Partial | High | Splash plus onboarding 1/2/3 PNG sequence is now implemented, first-launch startup now lands here, page 3 now opens login/sign-up as child auth routes, and guest-return preference is now persisted, but deeper auth continuation states are still pending | P1 |
| Location Setup / Select Location | `lib/screens/location_setup_screen.dart` | Real-Partial | High | The supplied 2-step setup shell is now real: onboarding routes into `Set Location`, current-location uses live browser geolocation plus loading/error states, successful saves continue into `Set Asar Time`, and manual entry still reuses the safer search/map-confirm fallback, but the manual map remains illustrative/local and setup-completion startup gating is still deferred | P0 |

## Secondary Discovery and Engagement

| Screen | Main file | Current status | Design fidelity | Major gaps | Priority |
|---|---|---:|---:|---|---:|
| Services Search | `lib/screens/services_search.dart` | Real-Partial | Medium | Live services fetch, location header hydration, typed business-route handoff, compact-safe layout, approved-business visibility in the default feed, and explicit supported-category alias handling are now implemented, but broader taxonomy expansion and any future keyword-search contract still depend on a deliberate Services API expansion | P1 |
| Business Listing | `lib/screens/business_listing.dart` | Real-Partial | Medium | Service-backed detail rendering plus real call/WhatsApp/directions/share/connect launches are now in place, but older entry points still fall back to nearby-mosque shaping and save/review flows remain local/read-only | P1 |
| Business Registration - Basic Details | `lib/screens/business_registration_basic/business_registration_basic_screen.dart` | Real-Partial | High | A mobile-first PNG-led shell is now routed inside an authenticated flow, persists backend-owned draft data, and hands off sanely into Contact & Location, but live-listing revision support still remains intentionally read-only until a safe publish/update model lands | P1 |
| Business Registration - Contact & Location | `lib/screens/business_registration_contact/business_registration_contact_screen.dart` | Real-Partial | High | A mobile-first PNG-led shell is now routed inside an authenticated flow, restores persisted draft state, supports sane back/save/submit transitions, and submits into the backend under-review state, but richer validation coverage plus post-publish revision semantics still remain | P1 |
| Business Registration - Status Utilities | `lib/screens/business_registration_status/*.dart` | Real-Partial | High | Intro, under-review, rejected, and live confirmation shells are now wired into the authenticated backend-backed flow with real status reads, but the live state intentionally stays read-only until a safe revision workflow is added | P1 |
| Event Search Listing | `lib/screens/event_search_listing.dart` | Real-Partial | Medium | Discovery shell, filtering, route handoff, and a shared event adapter are now implemented, but the source data is still mosque/tag-derived rather than a dedicated events contract | P1 |
| Event Detail | `lib/screens/event_detail_screen.dart` | Real-Partial | Medium | Shared event adapter, compact-safe layout, real share behavior, real directions entry, and organizer-site/contact-or-open-page actions are now in place, but there is still no dedicated event registration contract or event-specific organizer payload | P1 |
| Leave Review | `lib/screens/leave_review.dart` | Real | Medium | Authenticated review submission, validation, and error states are now implemented, but richer post-submit context is still missing | P1 |
| Review Confirmation | `lib/screens/review_confirmation.dart` | Real | Medium | Confirmation routing and return-home behavior now work, but the screen remains intentionally lightweight and mosque-specific follow-up cues are still absent | P2 |
| Mosque Broadcast | `lib/screens/mosque_broadcast.dart` | Real-Partial | Medium | Persisted broadcast reads, compact-safe layout, shared section-heading reuse, and new mosque-admin publishing/removal continuity are now implemented, but broader mosque-content modeling and secondary actions remain pending | P1 |
| Mosque Notification Settings | `lib/screens/mosque_notification_settings.dart` | Real-Partial | Medium | Verified Figma shell is now implemented, but richer backend notification taxonomy and final typography/icon fidelity are still pending | P1 |
| Sort/Filter Mosque | `lib/screens/sort_filter_mosque.dart` | Real-Partial | Medium-High | Verified Figma card-based filter shell is now implemented, and the current labels now better match supported mosque summary semantics, but it still depends on the current nearby/list payload rather than a broader search backend | P1 |

## Current Stabilization Risks

- Services, business, and event secondary flows now use real outbound launches where current data allows, but business/event depth still leans on frontend adapters over current service/mosque payloads rather than dedicated backend contracts.
- Business registration now has a real authenticated backend-backed path with named routes, persisted draft continuity, and real under-review/rejected/live status reads, but post-publish live-editing still remains intentionally read-only until a revision workflow lands.
- Event detail still has no true event registration URL or event-specific organizer/contact contract, so the screen can only launch the parent mosque’s site/contact surface or fall back to the organizer page.
- Shared Figma primitives now cover more section-heading cases, but future cleanup should stay tightly scoped to avoid accidental visual drift across existing verified screens.

## Next Objective

- Keep the completed public-readiness slices stable and shift the next work toward the remaining launch blockers:
- do not reopen account/settings, current-location/manual-location continuity, notifications shell fidelity, or backend integration-db isolation unless a regression is found
- prioritize deployment/runtime docs, production validation, and clearly documented contract gaps before any new visual redesign
- keep broader moderation and richer notification/event ecosystems isolated from this consolidation pass; only the minimal super-admin business-listing review queue is now in scope on the admin side, and remaining business-onboarding work should stay focused on safe contract-driven follow-through rather than rebuilding the current frontend assembly

## Admin and Content Operations

| Screen | Main file | Current status | Design fidelity | Major gaps | Priority |
|---|---|---:|---:|---|---:|
| Admin Add Mosque | `lib/screens/mosque_admin_add_screen.dart` | Real | Medium | Persisted admin-only create flow now stays intentionally create-first with prayer-time config and real image upload, while event publishing/broadcast composition has been removed from this screen and pushed behind owned-mosque management | P0 |
| Admin Edit Mosque | `lib/screens/mosque_admin_edit_screen.dart` | Real | Medium | Persisted admin-only edit flow now updates existing mosque basics, prayer-time config, live mosque-page content, ordered mosque images up to 10 with cover/reorder/remove controls, a practical published-events editor, and a real mosque broadcast composer, and backend ownership enforcement now makes it safe for owner-only management, but it is intentionally limited to one conservative editor and does not expand into moderation or a broader dashboard | P0 |
| My Mosques / Owned Mosque Management | `lib/screens/owned_mosques_screen.dart` | Real-Partial | Medium | Owned-mosque selection is now the compact admin path into manage/events/broadcast workflows, but it is intentionally a small routing surface rather than a richer analytics/dashboard tool | P0 |

## Business Registration

### Basic Details

Strengths:

- A new isolated mobile-first Flutter implementation now exists for the `Basic Details` step
- The shell follows the supplied PNG layout closely, including the centered title, 2-step progress rail, stacked pill inputs, logo upload card, and bottom CTA area
- The business/service selector now supports the expected collapsed, expanded, and selected taxonomy states instead of a dead placeholder dropdown
- `Next` and `Save as draft & close` are callback-driven rather than dead UI
- Local validation now drives disabled/enabled `Next` states for business name, logo, business type, tagline, and description
- All new code is isolated under `lib/screens/business_registration_basic/`, which keeps it merge-safe relative to the separate Contact & Location work
- The step now participates in a real named-route flow under authenticated-user gating
- Temporary draft continuity now exists through a business-registration-specific frontend storage/controller layer
- The journey now hands off into Contact & Location and the under-review/live architecture without dead transitions

Gaps:

- There is still no backend wiring for business-registration draft persistence or final submission
- Exact Figma node mapping for this step still has not been documented in the planning pack; the implementation currently follows the supplied PNG references

Relevant files:

- `lib/screens/business_registration_basic/business_registration_basic_screen.dart`
- `lib/screens/business_registration_basic/business_registration_basic_models.dart`
- `lib/screens/business_registration_basic/business_registration_basic_taxonomy.dart`
- `lib/screens/business_registration_basic/business_registration_basic_widgets.dart`
- `lib/features/business_registration/business_registration_models.dart`
- `lib/features/business_registration/business_registration_flow_controller.dart`
- `lib/features/business_registration/business_registration_draft_storage.dart`
- `lib/features/business_registration/business_registration_flow_screen.dart`
- `lib/navigation/app_routes.dart`
- `lib/navigation/app_router.dart`

### Contact & Location

Strengths:

- A new isolated mobile-first Flutter implementation now exists for the `Contact & Location` step
- The shell follows the supplied PNG layout closely, including the centered title, 2-step progress rail, stacked pill inputs, and bottom CTA area
- Submit and `Save as draft & close` are callback-driven rather than dead UI
- Local validation now drives disabled/enabled submit states for required email, phone, operating hours, and either location details or the online-only path
- Operating hours use real time pickers instead of static text placeholders
- All new code is isolated under `lib/screens/business_registration_contact/`, which keeps it merge-safe relative to the separate Basic Details work
- The step now participates in a real named-route flow under authenticated-user gating
- Temporary draft continuity now exists through a business-registration-specific frontend storage/controller layer
- Back/submit/save transitions now return to the previous step, save and close cleanly, and hand off into the under-review state without dead taps

Gaps:

- There is still no backend wiring for business-registration draft persistence or final submission
- Exact Figma node mapping for this step still has not been documented in the planning pack; the implementation currently follows the supplied PNG references

Relevant files:

- `lib/screens/business_registration_contact/business_registration_contact_screen.dart`
- `lib/screens/business_registration_contact/business_registration_contact_model.dart`
- `lib/screens/business_registration_contact/business_registration_contact_widgets.dart`
- `lib/features/business_registration/business_registration_models.dart`
- `lib/features/business_registration/business_registration_flow_controller.dart`
- `lib/features/business_registration/business_registration_draft_storage.dart`
- `lib/features/business_registration/business_registration_flow_screen.dart`
- `lib/navigation/app_routes.dart`
- `lib/navigation/app_router.dart`

### Status Utilities

Strengths:

- New intro, under-review, rejected, and live business-registration states now participate in the routed frontend flow rather than remaining isolated presentational shells
- The shells follow the supplied PNG compositions closely on mobile, including the centered top bar, progress rail, confirmation layout, and CTA treatment
- Primary actions are now wired through a dedicated business-registration flow coordinator instead of staying unwired callbacks
- Authenticated users can now enter or resume the flow from Profile & Settings, and intro/basic/contact/review routing stays in one feature-local path
- The status shells still stay visually isolated under `lib/screens/business_registration_status/`, while the coordinating state/routing logic lives under a business-registration-specific feature folder
- Repo theme tokens and typography are reused instead of introducing a parallel local theme

Gaps:

- Rejected status is now backend-backed with stored moderation feedback, but post-publish editing should still be treated as intentionally read-only until revision support lands
- The flow currently enters from Profile & Settings rather than broader discovery/business entry points
- The flow now also enters from Home and Services, but it still intentionally does not rewrite the published `BusinessListing` detail experience or add live revision support
- Exact Figma node mapping for these utility screens still has not been documented in the planning pack; the implementation currently follows the supplied PNG references

Relevant files:

- `lib/screens/business_registration_status/business_registration_intro_screen.dart`
- `lib/screens/business_registration_status/business_registration_rejected_screen.dart`
- `lib/screens/business_registration_status/business_registration_under_review_screen.dart`
- `lib/screens/business_registration_status/business_registration_live_screen.dart`
- `lib/screens/business_registration_status/business_registration_status_widgets.dart`
- `lib/features/business_moderation/business_moderation_screen.dart`
- `lib/features/business_moderation/business_moderation_service.dart`
- `lib/features/business_registration/business_registration_models.dart`
- `lib/features/business_registration/business_registration_flow_controller.dart`
- `lib/features/business_registration/business_registration_draft_storage.dart`
- `lib/features/business_registration/business_registration_flow_screen.dart`
- `lib/screens/profile_settings_screen.dart`
- `lib/navigation/app_routes.dart`
- `lib/navigation/app_router.dart`

## Notes By Screen

## Auth

### Login

Strengths:

- Real auth call
- Error handling exists
- Route wiring is stable
- Exact Figma `Login` node is now verified
- Base Figma auth shell has been implemented with tighter spacing, CTA sizing, and footer structure
- Forgot-password now opens a live email-reset request flow instead of a dead tap
- Reset-password now completes against the live backend token flow and keeps direct-link handling safe for web hash routes
- Social-auth placeholders are removed in favor of honest availability copy
- Mosque-admin users now have a direct entry point from Login into the access-code-gated sign-up path
- Login now starts with explicit user vs mosque-admin mode buttons instead of a heavier shared-auth explainer
- Wrong-credential, invalid-email, and short-password messaging now reads as plain-language guidance instead of raw backend phrasing

Gaps:

- Social auth is still not implemented
- Account deletion now exists through Profile & Settings, but login itself still does not cover broader account-governance or admin-recovery flows
- Deeper auth continuation screens still need their own exact Figma comparison if we continue the full auth journey
- There is still no self-serve admin approval or invite flow beyond the current access-code gate

Relevant files:

- `lib/screens/login_screen.dart`
- `lib/screens/forgot_password_screen.dart`
- `lib/screens/reset_password_screen.dart`
- `lib/widgets/auth_scaffold.dart`
- `lib/widgets/auth_text_field.dart`
- `lib/widgets/auth_primary_button.dart`

### Sign Up

Strengths:

- Real signup call
- Basic client validation exists
- Exact Figma `Sign Up` node is now verified
- Prefilled demo values have been removed
- Base auth shell now matches the verified auth family much more closely
- Social-auth placeholders are removed in favor of honest availability copy
- User vs mosque-admin account creation is now explicit in the active UI, with an access-code field only when mosque-admin mode is selected
- Sign-up copy now switches more clearly into a mosque-admin-specific state while keeping the overall shell lighter
- Password expectations, duplicate-email handling, and missing/invalid admin-code feedback are now more user friendly
- Successful signup now has a real backend-triggered welcome email path without adding a new marketing or onboarding UI surface

Gaps:

- Social auth is still not implemented
- Mosque-admin signup still depends on a backend-configured access code rather than a richer invite/approval workflow
- Code-entry / continuation states still need dedicated Figma comparison if brought into the active flow
- There is still no self-serve admin approval, invite, or recovery flow beyond the current access-code gate

Relevant files:

- `lib/screens/signup_screen.dart`
- `backend/src/routes/auth.js`

## Entry and Setup

### Onboarding / Auth Entry

Strengths:

- Verified Figma-backed entry shell exists
- Supplied splash + onboarding 1/2/3 PNG sequence now drives the active route visuals
- First-launch unauthenticated startup now correctly lands on this route
- The primary CTA now opens login directly while the guest CTA still hands off into the setup flow
- Guest selection now persists a return-to-home preference used by startup and auth-required redirects
- Direct login/signup/home behavior outside onboarding remains unchanged

Gaps:

- Deeper auth continuation states remain outside this slice
- The onboarding sequence is image-backed right now, so any follow-up interactive polish between pages should stay tightly scoped

Relevant files:

- `lib/screens/onboarding_screen.dart`
- `lib/navigation/app_routes.dart`
- `lib/navigation/app_router.dart`

### Location Setup / Select Location

Strengths:

- Verified Figma-mapped location nodes now have real Flutter targets
- Onboarding now hands directly into the supplied `Set Location` setup shell instead of the old search-first screen
- `Use my current location` now performs a real browser geolocation request, shows a live loading state, persists coordinates immediately, and advances directly into `Set Asar Time`
- Chosen locations persist through the existing `LocationPreferencesService` and `user.location` preference key, and Asar preference now persists through `PrayerSettingsService`
- Widget coverage now verifies compact safety, current-location loading/error/success states, manual fallback continuity, and Asar persistence/navigation

Gaps:

- The manual map confirmation surface is still illustrative rather than backed by a full interactive maps integration
- Startup gating on setup completion is still intentionally deferred
- Final visual polish still depends on the supplied onboarding/location PNG reference

Relevant files:

- `lib/screens/location_setup_screen.dart`
- `lib/services/current_location_service.dart`
- `lib/services/location_preferences_service.dart`
- `lib/services/prayer_settings_service.dart`
- `test/location_setup_flow_test.dart`
- `test/location_preferences_service_test.dart`

## Home

Strengths:

- Nearby mosques are fetched
- Async states exist
- Exact full Home node is now verified as `812:1551`
- Figma-backed top nav, prayer hero/timeline, nearby mosque card, events row, and others promos are now implemented
- A Phase 2 PNG-led fidelity pass tightened the mobile spacing, section typography, prayer card proportions, nearby-mosque card composition, and promotional card density
- The strongest repeated Home treatments are now extracted into shared Figma-faithful primitives for section headings, filter chips, outline actions, and compact status chips
- Nearby mosque detail navigation and prayer settings navigation were preserved through the redesign
- The home events rail can now reuse persisted mosque-page event content for the featured mosque when that backend read succeeds
- The Home prayer card now requests `GET /api/v1/mosques/:id/prayer-times` for the featured mosque and selected date, and renders honest loading/config-unavailable/schedule/up-next states from the backend payload
- Home prayer day navigation now stays tied to the current selected date, and delayed responses no longer override a newer day selection
- The Home timeline now uses device time against the current day’s backend prayer payload to highlight the active prayer window and partial progress only when the displayed day is actually today
- The Home top location label now comes from the persisted `user.location` preference, and the prayer hero explicitly labels which featured mosque/location the timings belong to
- The right-side `Others` card now reads persisted notification-enabled mosques for authenticated users and falls back to honest guest/empty/error messaging instead of a fake business spotlight promo
- The bottom utility strip now reflects admin/logged-in/guest state with real routes (`Add Mosque`, notifications, or login) instead of static support copy

Gaps:

- The left business promo in `Others` still uses static copy and routes into the existing business flow rather than a more fully typed/live Home-owned card
- Nearby discovery still uses the current fixed-coordinate load path because this slice intentionally avoided geocoding/maps work
- Non-today prayer dates intentionally stay schedule-only right now, so there is still no richer historical/future-day explanation beyond the conservative static timeline state
- Exact assets and deeper live-data parity are still pending even though the mobile shell is now materially closer to the PNG/Figma target

Relevant files:

- `lib/screens/home_page_1.dart`
- `lib/data/mosque_provider.dart`
- `lib/widgets/common/async_states.dart`
- `lib/widgets/common/figma_section_heading.dart`
- `lib/widgets/common/figma_filter_chip.dart`
- `lib/widgets/common/figma_outline_action_button.dart`
- `lib/widgets/common/figma_status_chip.dart`

## Mosque Listing

Strengths:

- Filtering logic is substantial
- Nearby loading path is real
- Detail navigation exists
- Exact Mosque Listing node is now verified as `2064:13852`
- Exact companion Sort/Filter node is now verified as `2355:10414`
- Listing shell and filter modal now follow the verified Figma direction much more closely
- Uploaded mosque images now render in a shared landscape thumbnail frame instead of a portrait-leaning card crop

Gaps:

- Listing prayer summaries are now intentionally conservative and explicitly listing-level, so the remaining gap is per-card live prayer-time depth rather than honesty
- Filtering is now more honest, but it still runs locally against the loaded nearby payload instead of a broader typed search backend
- Detail-path prayer-summary drift has been reduced, but the screen still does not batch or prefetch live prayer summaries for cards

Relevant files:

- `lib/screens/mosque_listing.dart`
- `lib/screens/sort_filter_mosque.dart`
- `test/mosque_listing_test.dart`
- `test/sort_filter_mosque_test.dart`

## Mosque Page

Strengths:

- Good information structure already exists
- Bookmark and review paths are integrated
- Uses shared primitives more than some other screens
- Exact Mosque Page node is now verified as `1864:4926`
- Routed mosque page now follows the verified shell much more closely with the PNG-led header/gallery rebuild, denser iqamah/facilities/imams cards, refined connect/reviews sections, more editorial event/class posters, and a more faithful bottom action rail
- Widget coverage now exists for the routed `MosquePage` shell and mosque-notification-settings route
- Compact-viewport widget coverage now also guards the routed `MosquePage` shell
- Review summaries/details now hydrate from persisted backend data
- Broadcast preview content now hydrates from persisted backend broadcast messages and routes into the broadcast screen
- Events, classes, and connect content now prefer persisted backend mosque-page content with conservative screen-local fallback content
- The same persisted mosque-page event content can now feed the Home events rail for the featured mosque
- Call/share/directions actions plus persisted connect links now launch real outbound behavior where source data exists, with honest no-data messages instead of dead placeholder taps
- Header/meta summary language now aligns more closely with the honest listing payload instead of implying fake open-hours, sect, or review richness
- Routed page bookmark state now has its own real toggle, reducing drift between listing cards and the active detail route
- Empty broadcasts/events/classes/contact/facilities/review states now stay explicit and conservative instead of rendering invented detail-rich fallback content
- Listing-level prayer fallback labels now reuse the same conservative wording as Mosque Listing, so the routed page distinguishes listed summaries from backend live timing reads more clearly
- Legacy `MosqueDetailScreen` is now only a thin compatibility wrapper around `MosquePage`, and older detail-only tests were narrowed to that role
- `View this week's iqamah timings` now opens a conservative 7-day in-app sheet backed by the existing daily prayer-time route, so the CTA is no longer a dead tap
- Single uploaded mosque images now render as one full-width 16:9 hero instead of being forced into a pseudo-gallery layout
- Ordered uploaded mosque image galleries now render in the same 16:9 frame with slider arrows and a simple page indicator, keeping portrait uploads acceptably cropped instead of stretched or letterboxed

Gaps:

- `MosqueDetailScreen` still exists as a compatibility wrapper for older direct callers, even though the active routed detail experience now lives entirely in `MosquePage`
- The weekly iqamah view currently fans out the existing daily route rather than using a batch/week contract, so any future optimization should stay additive instead of replacing the current backend-owned source of truth
- The broader mosque engagement graph is still partial because notifications feed cards and broadcast follow-on actions do not yet resolve into richer linked content models
- The current gallery interaction is intentionally lightweight: there is no fullscreen/lightbox view, thumbnail strip, or deeper gallery affordance yet

Relevant files:

- `lib/screens/mosque_page.dart`
- `lib/screens/mosque_broadcast.dart`
- `lib/screens/mosque_detail_screen.dart`
- `test/mosque_page_test.dart`

## Notifications

Strengths:

- Navigation shell exists
- Tab switching exists
- Exact logged-in Notifications node is now verified as `1696:11273`
- Companion `My Mosques` state is now verified as `1746:19476`
- Verified Figma-backed notifications shell is now implemented with sectioned feed cards and `My Mosques` tab behavior
- `My Mosques` now hydrates from persisted notification-enabled mosque data when the authenticated backend read is available
- Notifications section headers now reuse the shared Figma heading primitive extracted during the Home follow-up pass

Gaps:

- Feed/event/broadcast cards still use local placeholder content
- Event and broadcast actions still use placeholder affordances
- Needs a richer notifications content model and deeper routing for secondary content

Relevant files:

- `lib/screens/notifications_screen.dart`
- `backend/src/routes/notifications.js`
- `lib/widgets/common/figma_section_heading.dart`

## Prayer Settings

Strengths:

- Settings persistence exists
- State changes are real
- Exact full-screen Prayer Settings node is now verified as `1677:7432`
- Nested prayer-notification section is now verified as `1685:9216`
- Verified Figma-backed top nav, prayer overview card, Asar setting row, Suhoor/Iftar card, and voluntary-prayers section are now implemented
- A follow-up PNG-led fidelity pass tightened the top-nav divider treatment, status chip treatment, and shared section/toggle styling to better match the supplied prayer-settings reference
- Prayer Settings now shares the extracted Figma heading, status-chip, and switch primitives instead of keeping separate near-duplicate local widgets

Gaps:

- Prayer/date/location values remain static/local instead of modeled from live app data
- Exact Figma fonts/assets are still approximated with current Flutter icons and typography

Recent hardening:

- Compact-viewport widget coverage now guards against overflow regressions in the prayer-settings route.

Relevant files:

- `lib/screens/prayer_notifications_settings_page.dart`
- `lib/widgets/common/figma_section_heading.dart`
- `lib/widgets/common/figma_status_chip.dart`
- `lib/widgets/common/figma_switch.dart`

## Mosque Notification Settings

Strengths:

- Real auth-backed update behavior exists
- Exact mosque notification settings node is now verified as `1793:2921`
- Verified Figma-backed shell is now implemented with card-based toggles and explanatory footer copy
- Compact-viewport widget coverage now guards against bottom-overflow regressions on this route
- Persisted backend reads now hydrate the screen before falling back to the local cache
- The route now also reuses the extracted shared Figma switch primitive instead of carrying a separate local compact toggle implementation

Gaps:

- Notification labels/descriptions still map conservatively from the current settings payload shape
- Exact Figma assets/fonts are still approximated with current Flutter iconography and typography

Relevant files:

- `lib/screens/mosque_notification_settings.dart`
- `lib/services/mosque_notification_settings_service.dart`
- `test/mosque_notification_settings_test.dart`

## Admin Add Mosque

Strengths:

- Persisted admin-only create route now exists end to end
- Form now submits only fields that the current backend and discovery/detail flows can really store/use
- Auth role is now persisted locally and used for honest admin gating
- Successful creates now flow back into active discovery/detail paths without needing a fake local ID
- Mosque-owned events can now be created during the initial add flow through the same persisted mosque-content path already consumed by Mosque Page and Home
- Mosque image selection, preview, upload, and saved-image reuse now run through a real backend-owned browser upload path instead of a pasted URL field
- The shared admin image preview now uses the same landscape framing the product expects in live mosque surfaces, the form shows a short recommendation to upload a landscape image around `1600 x 900` or larger, and admins can upload/manage up to 10 ordered mosque images

Gaps:

- Still only one create workflow, not a full admin platform
- No edit/delete/review moderation lifecycle yet
- Some richer prototype-only fields were intentionally trimmed rather than faked
- Visual fidelity remains conservative until a verified PNG/node pass is provided
- Event publishing is intentionally lightweight: saved events are treated as published content, with no draft/approval window yet
- Gallery interaction remains intentionally practical: admins can upload/reorder/remove images, but there is still no drag-and-drop sorter, batch uploader, or richer media management

Relevant files:

- `lib/screens/mosque_admin_add_screen.dart`
- `lib/data/auth_provider.dart`
- `lib/services/mosque_service.dart`
- `lib/widgets/mosque_image_upload_field.dart`
- `backend/src/routes/mosques.js`
- `backend/src/db/migrations/003_admin_mosque_create.sql`
- `backend/src/db/migrations/004_admin_mosque_fields.sql`

## Cross-Cutting Gaps

These affect many screens at once:

1. Theme and tokens are not yet rich enough for high-fidelity design work.
2. Placeholder snackbars still exist in user-facing paths.
3. Hardcoded demo content remains in key screens.
4. Widget tests were recently stabilized to a green baseline, but coverage is still too shallow to confidently guard all future design refactors.
5. Figma source mapping is incomplete because the shared link does not point directly at the real product frames.
