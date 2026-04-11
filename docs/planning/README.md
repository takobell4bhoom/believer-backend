# Believers Lens Planning Pack

This folder is the continuity pack for building the app toward the intended Figma design without losing context across chats.

Use these files in this order:

1. `FIGMA_IMPLEMENTATION_MASTER_PLAN.md`
   Main roadmap, build order, safety guardrails, and phase-by-phase done criteria.

2. `SCREEN_GAP_AUDIT.md`
   Screen-by-screen status audit comparing the current project state with the intended UI direction.

3. `FIGMA_VISIBILITY_NOTES.md`
   Confirmation of what is currently visible in Figma, what is still ambiguous, and which node is the best current entry point.

4. `FIGMA_NODE_MAP.md`
   Verified node-to-file mapping for screens and reusable design components.

5. `CHAT_CONTINUITY_GUIDE.md`
   Practical handoff guide for resuming work in a new chat with minimal setup loss.

Working assumptions used in these docs:

- The shared Figma link currently opens on a `Competitive Analysis` canvas rather than a product screen node.
- For UI design and implementation, use verified Figma nodes only.
- Ignore `Ui-scan/*.md` as a design/build reference for UI screens.
- The app is already functionally underway, so the goal is not a rewrite. The goal is a controlled migration from prototype-grade UI to a design-faithful product.

Suggested use in future chats:

- Start by sharing `docs/planning/FIGMA_IMPLEMENTATION_MASTER_PLAN.md`.
- If the chat is focused on one screen, also share the relevant part of `docs/planning/SCREEN_GAP_AUDIT.md`.
- If the chat is for implementation, ask to complete exactly one phase or one screen slice at a time.
