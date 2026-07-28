# ADR-002 — Logical Garments Use Bounded Visual Recipes

- Status: accepted contract; partially represented in the current runtime.
- Date: 2026-07-27.

## Decision

One garment is one logical equipment item. It may resolve to zero or more bounded visual fragments per presentation view. A fragment owns its component/view policy, binding, pivot, landmarks, coverage contribution, deformation/motion response, and depth relation.

No invariant equates one garment with one sprite, atlas region, or render layer.

## Current representation

`EquipmentItemInput.visual_recipes` and topology-aware `every_compatible` expansion already provide bounded multi-component garments. For example, `ivory_blouse` resolves one torso and two conventional sleeve visuals while remaining one item.

Current recipe IDs are typed and deterministic, but stable authored fragment names and semantic depth relations are not yet fields. They remain explicit future schema gaps.

## Rationale

Reusable clothing must combine with arbitrary compatible items and anatomy without requiring monolithic full-body textures. Fixed-capacity recipes preserve deterministic memory and ordering.

## Consequences

- Routine garments may remain one fragment.
- Skirts, collars, jackets, and hair/headwear may use several fragments.
- The unified sprite/mesh queue remains the only renderer.
- A future runtime extension must be driven by production content or an authorized editor-export milestone, not added speculatively.
