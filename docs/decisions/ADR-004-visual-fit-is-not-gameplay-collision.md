# ADR-004 — Visual Fit Geometry Is Not Gameplay Collision

- Status: accepted.
- Date: 2026-07-27.

## Decision

Garment fit uses semantic visual landmarks, axes, visible-alpha geometry, intended coverage zones, and design-specific contracts transformed through the production presentation path.

Physics colliders, raw quads, atlas rectangles, and opaque bounds are not sufficient clothing contours.

## Rationale

A collider answers movement/grounding questions. It deliberately ignores shoulder slope, neck/collar intent, armholes, garment hem, and visible articulation. Prompt 25C/25D demonstrated that valid bindings/quads can still look visibly wrong.

## Consequences

- Collision and fit overlays must be visually distinct.
- Future shoulder/collar contracts extend semantic geometry, not physics.
- Tests retain controlled bad fixtures for wrong axes, registration, coverage, and continuity.
