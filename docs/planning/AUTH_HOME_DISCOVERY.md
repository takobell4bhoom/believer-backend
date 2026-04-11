# Auth and Home Discovery Notes

Last updated: 2026-03-26

## Purpose

This file records the current discovery status for the highest-priority Figma areas:

- Auth
- Onboarding
- Setup / location selection
- Home / prayer
- Mosque listing / mosque page
- Notifications / prayer settings

It separates what is fully verified from what is still pending discovery so future chats do not over-claim screen mappings.

## What is verified right now

## Verified root area

- `657:1636` -> `Hi-Fi MockUps (Dev)`

This is the main entry point for product-screen discovery.

## Verified auth nodes

### `2511:11665` -> `Login Page - Empty`

Supporting auth states discovered in the same verified Figma auth section:

- `2508:10028` -> `Login Page - Filled`
- `2511:11759` -> `Login Page - Error`

Visible design characteristics from the verified login frame:

- compact top nav with back arrow + centered `Log In` title
- narrow auth content column with `38px` side padding inside a `390px` frame
- `Email address` and `Password` entry fields using shallow-radius filled inputs
- right-aligned `Forgot Password?` link
- `50px` high primary CTA with disabled/filled state variants
- footer divider:
  - `Or Log In with`
- stacked Google + Apple auth buttons
- centered account-switch prompt:
  - `Don’t have an account? Sign Up`

Current code comparison:

- Closest current file: `lib/screens/login_screen.dart`
- The Flutter login screen has now been rebuilt around the verified Figma auth shell while preserving the existing backend login call and route contracts.

Current mismatch summary:

- The base visual shell, field geometry, button sizing, footer structure, and back-nav affordance are now aligned much more closely with Figma.
- Forgot-password remains a placeholder action.
- Social auth remains visual-only.

### `2510:11494` -> `Signup Page - Empty`

Supporting auth states discovered in the same verified Figma auth section:

- `2511:11826` -> `Signup Page - Filled`
- `2511:11918` -> `Signup Page - Password error`
- `2511:12079` -> `Signup Page - Email error`

Verification notes:

- The exact Sign Up node was isolated directly from the verified `Log In & Sign Up` section.
- A detailed design-context fetch for this frame was blocked by the Figma starter-plan MCP rate limit after node isolation.
- The verified auth section still exposed the exact sibling state frames listed above, so the Flutter implementation followed the same auth-shell structure already confirmed on Login:
  - compact top nav
  - narrow input stack
  - `50px` CTA
  - social footer
  - centered account-switch prompt

Current code comparison:

- Closest current file: `lib/screens/signup_screen.dart`
- The Flutter sign-up screen has now been updated to the verified auth-shell direction while preserving the existing signup API contract.

Current mismatch summary:

- Prefilled demo values were removed.
- The base auth shell now matches the verified Login-family structure much more closely.
- Exact deeper auth continuation screens such as code-entry still need their own dedicated Figma comparison if we continue the auth journey later.

## Verified onboarding/setup nodes

### `2509:10100` -> `Onboarding-3`

Implementation status:

- Implemented in `lib/screens/onboarding_screen.dart`
- Exposed as a route-ready screen through `AppRoutes.onboarding`
- Not yet switched into the main startup flow

Visible design characteristics:

- light neutral background
- centered greeting:
  - `Salam`
  - `Welcome to`
  - `BelieversLens`
- large illustration block
- bottom CTA stack:
  - primary: `Log In or Sign Up`
  - secondary: `Explore as Guest`

Current code comparison:

- Closest current file: `lib/screens/onboarding_screen.dart`
- This screen has now been rebuilt around the verified Figma structure.

Current mismatch summary:

- The Flutter screen is now aligned to the direct decision-screen structure:
  - greeting
  - central celebratory illustration
  - `Log In or Sign Up`
  - `Explore as Guest`
- It still uses an in-code custom illustration and existing app typography rather than exact exported Figma assets/fonts.
- Startup wiring was intentionally left unchanged to preserve roadmap direction.

### `771:1974` -> `Select Location #1`

Visible design characteristics:

- `Set Up` title
- `Set Location` section
- search field for city/area/street
- `Use Current Location` row
- step/progress indicator

Current code comparison:

- No clearly wired Flutter screen currently matches this setup step.

### `1501:1980` -> `Select Location #2`

Visible design characteristics:

- top nav
- full map background
- draggable location instruction
- bottom location summary
- CTA for confirming precise location

Current code comparison:

- No clearly wired Flutter screen currently matches this setup step.

## Verified home/prayer component nodes

### `812:1551` -> `Home Page #1`

Verification notes:

- Verified directly from the user-provided Figma copy rooted at `657:1636`.
- This is the exact full Home screen container for the current implementation pass.
- `1677:7432` is also labeled `Home Page #1` in metadata, but its design context resolves to the prayer-settings flow and should not be used as the Home source of truth.

Visible design characteristics from the verified Home frame:

- fixed top nav with underlined location label and right-side menu icon
- fixed bottom nav with `Home`, `Mosques & Events`, `Notifications`, and `Services`
- prayer hero card with:
  - centered `TODAY`
  - date row with left/right arrows
  - `NOW`
  - `Duhr`
  - time range
  - `Ends in` badge
- prayer timeline row under the hero card
- nearby mosque section with chips, `Closest To You` badge, and outlined CTA
- events section with compact horizontal cards
- others section with two compact promo cards plus one wide support card

Current code comparison:

- Closest current file: `lib/screens/home_page_1.dart`
- The Flutter Home screen has now been rebuilt around this verified Figma shell while preserving existing backend/provider flows for nearby mosques, mosque-detail navigation, prayer-settings navigation, logout, and bottom-nav routing.

Current mismatch summary:

- Prayer data, date content, and top location are still static.
- Events and others content remain local/static rather than backend-backed.
- Visual direction is now materially closer to Figma, but exact fonts/assets and deeper live-data parity are still pending.

## Verified mosque discovery nodes

### `2064:13852` -> `Mosque Listing`

Verification notes:

- Verified directly from the `Mosque` section under the shared Figma root `657:1636`.
- This is the exact listing frame used for the current mosque-listing implementation pass.
- Related supporting frame in the same section:
  - `2355:10414` -> `Sort & Filter - Mosques`

Visible design characteristics from the verified listing frame:

- fixed top nav with underlined location label and right-side menu icon
- second row with back arrow and centered `Nearby Mosques` title
- horizontal filter rail with compact chips such as:
  - `Within 3 miles`
  - `Newly added`
  - `This weekend`
  - `Free`
- leading filter action with red badge
- count row showing total mosque count plus active filter count
- stacked mosque cards with:
  - hero image
  - rating badge
  - location/distance row
  - amenity chips
  - prayer timing row
  - dark `Starts in` pill
- first card carries a `Closest To You` badge

Current code comparison:

- Closest current file: `lib/screens/mosque_listing.dart`
- The Flutter listing screen has now been rebuilt around this verified shell while preserving:
  - `mosqueProvider` loading
  - current auth redirect behavior
  - mosque detail navigation
  - bottom-nav routing

Current mismatch summary:

- Listing content still uses the current mosque model rather than richer Figma-specific content assets.
- The top location still comes from the existing preferences/default-location path, not a Figma-specific source.
- Some chip labels remain representational rather than backed by deeper data modeling.

### `2355:10414` -> `Sort & Filter - Mosques`

Verification notes:

- Verified as the exact companion filter screen for the mosque-listing slice.
- This frame defines the visual direction for the listing filter modal, not a separate discovery track.

Visible design characteristics from the verified filter frame:

- centered top title:
  - `Sort & Filter`
- `Clear filters` action near the top
- bottom fixed actions:
  - `Close`
  - `Apply`
- uppercase grouped sections with divider lines:
  - `SORT BY`
  - `DISTANCE`
  - `SECT`
  - `ASAR TIME`
  - `REVIEWS`
  - `TIMINGS`
  - `FACILITIES`
  - `MOSQUE CLASSES & HALAQAS`
  - `MOSQUE EVENTS`
- controls are primarily larger selection cards rather than the old small-chip layout

Current code comparison:

- Closest current file: `lib/screens/sort_filter_mosque.dart`
- The Flutter filter screen has now been redesigned to follow this verified card-based grouping while preserving the existing result payload contract used by `MosqueListing`.

Current mismatch summary:

- Current option labels are aligned conservatively to the existing mosque-listing filter logic rather than fully expanded into every possible Figma variant.
- No backend/data contract changes were made for this slice.

### `1864:4926` -> `Mosque Page`

Verification notes:

- Verified in the same mosque section during this continuation pass.
- This frame is now the next correct target after Mosque Listing and Sort/Filter.

Current code comparison:

- Closest current files:
  - `lib/screens/mosque_page.dart`
  - `lib/screens/mosque_detail_screen.dart`

Current mismatch summary:

- The routed Flutter mosque page now follows the verified Figma shell more closely with:
  - fixed top nav
  - stronger mosque identity header
  - hero + thumbnail gallery
  - Figma-style iqamah/today section
  - card-based events/classes sections
  - fixed bottom contact/directions/notifications rail
- Real route behavior was preserved for:
  - mosque resolution/loading
  - reviews route
  - mosque notification settings route
- The older `lib/screens/mosque_detail_screen.dart` remains in the codebase for the legacy detail widget/test path and bookmark-specific coverage, so the broader mosque-detail architecture is still split across two files.

### `759:16067` -> `SalahTime`

Visible design characteristics:

- six prayer-card variants:
  - Fajar
  - Sunrise
  - Duhr
  - Asar
  - Maghrib
  - Isha
- high-fidelity gradient/illustration-backed hero cards
- strong tokenized typography hierarchy
- arrow/date row
- current prayer block
- "Ends in" badge

Current code comparison:

- Closest current file: `lib/screens/home_page_1.dart`
- Current home prayer card is structurally similar in purpose, but visually and compositionally below the Figma fidelity level.

### `1685:9216` -> `Prayer time notifications`

Verification notes:

- Verified as a nested prayer-time-notification section inside the full-screen prayer-settings frame `1677:7432`.
- This node should be used as a supporting component reference, not as the full route source of truth.

Visible design characteristics:

- segmented prayer selection rows
- variants for Fajar, Duhr, Asar, Maghrib, Isha
- tightly matched to prayer settings interaction design
- three prayer-notification mode cards:
  - `Silent`
  - `On`
  - `Adhan`

Current code comparison:

- Closest current file: `lib/screens/prayer_notifications_settings_page.dart`
- The Flutter screen now uses this node as the nested interaction reference while the full route is implemented from the verified parent frame `1677:7432`.

## Verified notifications and prayer-settings nodes

### `1696:11273` -> `Notifications Page - Notifications`

Verification notes:

- Verified directly from the `Notifications` section under root `657:1636`.
- This is the exact logged-in Notifications frame used as the current route source of truth.
- Verified supporting frames in the same section:
  - `1746:19476` -> companion `My Mosques` tab state
  - `2064:12250` -> unlogged state
  - `2064:12596` -> logged but empty state
  - `2518:12397` -> parent `Notifications` section

Current code comparison:

- Closest current file: `lib/screens/notifications_screen.dart`
- The Flutter notifications route has now been rebuilt around the verified logged-in shell and companion `My Mosques` state while preserving current route contracts.

Current mismatch summary:

- Event and broadcast taps remain conservative placeholder affordances because deeper event/broadcast routing was not introduced in that slice.
- Feed content still uses locally shaped mock content rather than a dedicated notifications model.

### `1677:7432` -> `Home Page #1`

Verification notes:

- Despite the misleading metadata label, this is the exact full-screen `Prayer Notifications & Settings` frame.
- It should be treated as the source of truth for `lib/screens/prayer_notifications_settings_page.dart`, not for Home.
- Supporting nested section:
  - `1685:9216` -> `Prayer time notifications`

Visible design characteristics:

- fixed top nav with underlined location label and right-side menu icon
- second row with back arrow and centered `Prayer Notifications & Settings` title
- top prayer overview card with:
  - `TODAY`
  - date row with arrows
  - `NOW`
  - current prayer/time range
  - `Ends in` chip
- iqamah-style prayer rows with one active state
- underlined `Asar Time` setting row
- Suhoor/Iftar card with `Show on homepage` toggle
- `VOLUNTARY PRAYERS` section with divider and stacked cards

Current code comparison:

- Closest current file: `lib/screens/prayer_notifications_settings_page.dart`
- The Flutter prayer-settings route has now been rebuilt around this verified full-screen shell while preserving existing `PrayerSettingsService` persistence and bottom-sheet interaction behavior.

Current mismatch summary:

- Prayer/date/location values are still static/local and not derived from live prayer/location models.
- Exact Figma fonts/assets are still approximated with current Flutter icons and typography.

### `1793:2921` -> `Mosque Page - Notification Settings`

Verification notes:

- Verified directly from the same prayer/notification area under root `657:1636`.
- This is the exact mosque-specific notification-settings frame for the next secondary-flow implementation pass.

Current code comparison:

- Closest current file: `lib/screens/mosque_notification_settings.dart`
- The route now follows the verified mosque-notification-settings shell more closely while preserving auth-backed update behavior and local fallback persistence.

Current mismatch summary:

- Toggle content still maps conservatively from the current notification-settings payload structure rather than a richer backend notification taxonomy.
- Exact Figma assets/fonts are still approximated with current Flutter iconography and typography.

## What is still not fully isolated

These are still pending exact node discovery or comparison:

- location/setup flow beyond the already verified `Select Location #1` and `Select Location #2` nodes
- later secondary flows such as Services, Broadcast, and admin content operations

Important:

- We know these product areas exist in Figma from the category summary.
- The highest-priority core prayer/notification nodes are now all verified in this file.

## Honest current conclusion

We now know enough to say:

1. The Figma file definitely contains the real product system.
2. Exact base-screen nodes are now verified for both `Login` and `Sign Up`.
3. The onboarding/setup flow exists in Figma and is more mature than the current active Flutter route flow.
4. Exact full `Home` screen node is now verified as `812:1551`, and the Home shell redesign slice has been implemented against it.
5. Exact `Mosque Listing`, `Sort & Filter - Mosques`, and `Mosque Page` nodes are now verified as `2064:13852`, `2355:10414`, and `1864:4926`.
6. The mosque-listing, filter, and mosque-page redesign slices have now been implemented conservatively without changing startup flow or backend contracts.
7. Exact logged-in `Notifications` and full-screen `Prayer Notifications & Settings` nodes are now verified and implemented conservatively.
8. The mosque-notification-settings slice is now implemented conservatively against the verified node `1793:2921`.
9. The next targeted implementation pass inside `Hi-Fi MockUps (Dev)` should move to the next secondary engagement/content screen that still lacks a comparable Figma-backed pass.

## Best next Figma discovery task

The next discovery-focused chat should do exactly this only if a new screen still lacks an exact node:

1. open `657:1636`
2. isolate or confirm one exact node
3. compare it to the matching Flutter file
4. update `FIGMA_NODE_MAP.md`
5. then start the next verified redesign slice if still needed

## Best next implementation task

If the goal is implementation rather than more discovery, the safest next Figma-backed slice is now a secondary engagement/content screen adjacent to the mosque/notifications path, such as:

- `lib/screens/mosque_broadcast.dart`
- `lib/screens/services_search.dart`
- another verified pending screen that does not require startup-flow or backend-contract changes

Why:

- the onboarding/auth-entry slice is already in place
- the base auth redesign slice is now in place
- the first verified Home redesign slice is now in place
- the mosque-listing, filter, and mosque-page slices are now in place
- it continues forward from the now-completed notifications + prayer-settings + mosque-notification-settings slices
- it stays adjacent to already active mosque/notifications route paths without changing the agreed direction
