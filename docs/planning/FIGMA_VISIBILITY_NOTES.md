# Figma Visibility Notes

Last updated: 2026-03-26

## Current answer

Yes, the Figma file does contain the real hi-fi product work.

The earlier shared link opened on a `Competitive Analysis` canvas, which made it look like the product screens might be missing. After opening the file from node `657:1636`, it is now clear that the file also contains the main product mockups and component/system work.

## Best current entry point

Use this Figma node as the main starting point for further product inspection:

- `657:1636` -> `Hi-Fi MockUps (Dev)`

This node exposes the broader product canvas structure much better than the earlier node.

## What is visible now

From the metadata currently visible, the file includes grouped areas for:

- Log in & Sign up
- Profile & settings
- Onboarding
- Set up
- Home & prayer timings
- Notifications
- Mosque
- Events
- Services
- Business registration

The same area also exposes design-system and component-level work such as:

- button variants
- notification icons
- prayer-time components
- toggles
- timeline states
- location-selection screens
- onboarding screens

## Product scope summary currently visible in Figma

The summary block visible in the file reports:

- Total screens: `60`
- Unique screens: `27`
- Error screens: `04`
- Pop-up screens: `08`
- Sub-screens: `21`

Category counts visible in the summary:

- Log in & Sign up: `10`
- Profile & settings: `02`
- Onboarding: `04`
- Set up: `06`
- Home & prayer timings: `05`
- Notifications: `06`
- Mosque: `10`
- Events: `03`
- Services: `03`
- Business registration: `11`

## Important limitation

Even though the broader file is now visible, I still do **not** yet have every screen individually mapped to its exact Flutter file and exact Figma node.

So the correct answer is:

- I can now see that the full screen system exists in Figma.
- I can see the high-level screen groups and counts.
- I cannot yet claim that every single screen has already been individually inspected and mapped.

## What should happen next for exact design implementation

For pixel-accurate implementation, future chats should inspect one product area at a time from `Hi-Fi MockUps (Dev)` and create a node-to-file mapping for the target slice, for example:

1. Auth
2. Home
3. Mosque listing
4. Mosque page
5. Notifications
6. Prayer settings

That will eliminate ambiguity before deeper visual implementation work.

## Practical instruction for future chats

If a future chat is focused on one screen, ask it to:

- open node `657:1636`
- locate the exact screen inside `Hi-Fi MockUps (Dev)`
- compare that exact screen to the matching Flutter file
- implement only that slice

