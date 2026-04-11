# Figma Node Map

Last updated: 2026-04-09

## Purpose

This file is the bridge between the Figma canvas and the Flutter codebase.

Use it to answer:

- which Figma node is the current source of truth for a screen or component
- which Flutter file is the likely implementation target
- whether the mapping is verified or still pending

## Status labels

- `Verified`: exact Figma node has been opened and inspected
- `Candidate`: likely code target exists, but full implementation comparison has not yet been completed
- `Missing`: Figma exists but no clear code target is wired yet
- `Pending Discovery`: expected to exist in Figma, but exact node not yet isolated

## Root Entry Point

| Figma node | Name | Role | Status |
|---|---|---|---|
| `657:1636` | `Hi-Fi MockUps (Dev)` | Main hi-fi product canvas | Verified |

## Verified Screen Nodes

| Figma node | Figma name | Likely Flutter file | Status | Notes |
|---|---|---|---|---|
| `2509:10100` | `Onboarding-3` | `lib/screens/onboarding_screen.dart` | Verified | Implemented as the active first-launch onboarding/auth-entry route, with setup handoff into either login or guest home |
| `2511:11665` | `Login Page - Empty` | `lib/screens/login_screen.dart` | Verified | Implemented as the base Login redesign slice; supporting sibling states discovered in the same auth section: `2508:10028` filled, `2511:11759` error |
| `2510:11494` | `Signup Page - Empty` | `lib/screens/signup_screen.dart` | Verified | Implemented as the base Sign Up redesign slice; supporting sibling states discovered in the same auth section: `2511:11826` filled, `2511:11918` password error, `2511:12079` email error |
| `812:1551` | `Home Page #1` | `lib/screens/home_page_1.dart` | Verified | Implemented as the current verified Home redesign slice from the user-provided Figma copy; keep this as the Home source of truth |
| `2064:13852` | `Mosque Listing` | `lib/screens/mosque_listing.dart` | Verified | Implemented as the current verified mosque-listing redesign slice while preserving `mosqueProvider`, auth redirect behavior, detail navigation, and bottom-nav routing |
| `2355:10414` | `Sort & Filter - Mosques` | `lib/screens/sort_filter_mosque.dart` | Verified | Implemented as the Figma-backed companion filter modal for Mosque Listing; route now preserves current filter selections when reopened |
| `1864:4926` | `Mosque Page` | `lib/screens/mosque_page.dart` and `lib/screens/mosque_detail_screen.dart` | Verified | Implemented as the current verified mosque-page redesign slice in `lib/screens/mosque_page.dart`; preserves routed mosque-detail loading, reviews route, and mosque-notification-settings route |
| `1696:11273` | `Notifications Page - Notifications` | `lib/screens/notifications_screen.dart` | Verified | Implemented as the current logged-in Notifications source of truth; paired with `1746:19476` for the `My Mosques` tab and documented sibling states `2064:12250` and `2064:12596` |
| `1677:7432` | `Home Page #1` | `lib/screens/prayer_notifications_settings_page.dart` | Verified | Exact full-screen source of truth for Prayer Notifications & Settings despite the misleading Figma name; implemented conservatively while preserving local prayer-settings persistence |
| `1793:2921` | `Mosque Page - Notification Settings` | `lib/screens/mosque_notification_settings.dart` | Verified | Implemented as the current mosque-notification-settings redesign slice while preserving auth-backed update behavior and adding compact-viewport overflow protection |
| `771:1974` | `Select Location #1` | `lib/screens/location_setup_screen.dart` | Verified | Implemented as setup step 1 with search + location selection; onboarding now routes here conservatively before login or guest home |
| `1501:1980` | `Select Location #2` | `lib/screens/location_setup_screen.dart` | Verified | Implemented as setup step 2 map-style confirmation; saves through the existing location preferences path and continues to the requested next route |
| Unknown (PNG-led reference) | `Business Listing - Contact & Location` | `lib/screens/business_registration_contact/business_registration_contact_screen.dart` | Candidate | Local isolated Contact & Location step is now implemented from supplied PNG references, but the exact Figma node still needs to be isolated before broader business-registration wiring continues |

## Verified Component/Section Nodes

These are useful for Phase 2 design-system work and for rebuilding Home/Prayer Settings accurately.

| Figma node | Figma name | Likely Flutter target | Status | Notes |
|---|---|---|---|---|
| `2518:12397` | `Notifications` | `lib/screens/notifications_screen.dart` | Verified | Parent notifications section containing the verified logged-in, unlogged, and empty-state frames |
| `1746:19476` | `Notifications Page - Notifications` | `lib/screens/notifications_screen.dart` | Verified | Companion `My Mosques` state used for the second notifications tab |
| `2064:12250` | `Notifications Page - (Unlogged state)` | `lib/screens/notifications_screen.dart` | Verified | Reference-only sibling state in the same notifications area; not active in the current route |
| `2064:12596` | `Notifications Page - (Logged but empty state)` | `lib/screens/notifications_screen.dart` | Verified | Reference-only sibling state in the same notifications area; not active in the current route |
| `1685:9216` | `Prayer time notifications` | `lib/screens/prayer_notifications_settings_page.dart` | Verified | Nested prayer-time-notification section inside the full-screen prayer settings frame `1677:7432` |
| `759:16067` | `SalahTime` | `lib/screens/home_page_1.dart` | Candidate | Strong match for the home prayer hero cards / prayer-time variants |
| `2518:12401` | `Mosque` | mosque discovery section container | Verified | Parent section containing the verified mosque-listing, filter, and mosque-page frames in the user-provided Figma copy |

Important Home note:

- `1677:7432` is also named `Home Page #1` in metadata, but its design context maps to the prayer-settings flow rather than the main Home screen.
- Do not use `1677:7432` as the Home source of truth; use it only for `lib/screens/prayer_notifications_settings_page.dart`.

## High-Priority Pending Discovery

These are the next post-core targets most aligned with the roadmap.

| Product area | Expected Flutter file(s) | Status | Reason |
|---|---|---|---|
| Broadcast / mosque content follow-up | `lib/screens/mosque_broadcast.dart` and adjacent mosque engagement routes | Pending comparison | Notifications and mosque notification settings are now aligned enough to move into the next secondary engagement slice |

## Codebase Notes Related To Mapping

Current route map observations:

- The active route map is centered on auth, onboarding/setup, home, mosque, notifications, prayer settings, services, events, and reviews.
- Login and Sign Up now have verified Figma nodes and implemented auth redesign slices, while forgot-password and social auth are explicitly deferred in-product.
- Onboarding now owns the first-launch unauthenticated startup route.
- Mosque Listing and its Sort/Filter modal now have verified Figma nodes and implemented redesign slices while preserving the current listing/filter payload contract.
- Notifications, Prayer Settings, and Mosque Notification Settings now all have verified nodes and implemented redesign slices.
- Setup/location flows are now wired through `AppRoutes.locationSetup` and `AppRoutes.locationSetupMap`, with onboarding handing off into the flow and startup now distinguishing guest return from signed-out account return.
- Business registration now has one isolated local screen target under `lib/screens/business_registration_contact/`, but the exact Figma node and route entry are still pending.

Practical implication:

- Some Figma screens may map to existing files that are currently dormant.
- Some Figma screens may require new route wiring in addition to visual implementation.

## Recommended Next Discovery Order

1. compare one next secondary-flow node against its matching Flutter file
2. take that redesign slice conservatively without changing backend notification contracts

## Suggested Future Chat Instruction

When continuing discovery, ask the next chat to:

- open `657:1636`
- use the already-verified node for one screen only
- compare that node to the matching Flutter file
- update this map with `Verified` status and implementation notes
