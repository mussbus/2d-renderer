# ADR-001 — Preserve Production Authority Boundaries

- Status: accepted.
- Date: 2026-07-27.

## Decision

The runtime keeps one authoritative skeleton, anatomy identity, gameplay-facing value, equipment identity/loadout, physics/collision state, interaction owner, and unified render queue. Presentation and validation consume those authorities; they do not replace them.

Atlas regions are image identity, not anatomy or equipment identity. Visual fit geometry is authoring metadata, not collision. Draw submission order is not semantic depth authority.

## Rationale

Prompts 7–25D already prove deterministic composition, stable identities, and resource bounds. A parallel garment, editor, renderer, or validation model would permit drift and make current evidence non-authoritative.

## Consequences

- Facing/view changes resolve presentation only.
- Equipment effects are declared by items but consumed by gameplay systems.
- Future world themes derive from world/collision data without owning collision.
- Future editors manipulate and export the same definitions consumed by runtime/tests.
