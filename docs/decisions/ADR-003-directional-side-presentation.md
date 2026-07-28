# ADR-003 — Directional Side Presentation Is Explicit

- Status: accepted contract; mirror-safe production subset implemented.
- Date: 2026-07-27.

## Decision

Every side fragment belongs to one of three authoring policies:

1. mirror-safe canonical side;
2. authored side-left and side-right variants;
3. mixed-fragment composition where each fragment chooses reflection or directional art.

Gameplay facing remains authoritative and anatomical left/right identity never swaps.

## Current evidence

All current wardrobe visuals use canonical-side art reflected through the body projection. The inspected `ivory_blouse` has no asymmetric side cue and is a valid mirror-safe control. Both semantic side views are exercised by visual-geometry acceptance.

No accepted production item requires authored directional variants. The runtime therefore has no unused directional-selection schema yet.

## Consequences

- Future asymmetric art must not be forced through reflection.
- Turning cannot recreate equipment state, decode images, create GPU resources, or reset secondary motion.
- Direction selection must be generalized by fragment/view metadata, never a blouse-name branch.
