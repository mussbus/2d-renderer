# Scope Boundaries

## Current production scope

- Modular 2D segmented characters.
- Front and side presentation with stable gameplay-facing authority.
- Male/female body presets and bounded morphology.
- Independent anatomy, hair, permanent base-presentation modesty surfaces, removable clothing, and equipment.
- Image-backed art packs and atlas resources.
- Modular equipment items, bounded visual recipes, outfit presets, and custom recombination.
- Deterministic animation, character physics, interaction coordination, IK, deformation, and secondary motion.
- Semantic visual-geometry validation and real D3D12/DXIL evidence.

## Immediate future scope

- Prompt 26 environment themes and layered world presentation.
- Prompt 27 integrated visual/gameplay foundation.
- One narrow gameplay vertical slice with a beginning, traversal, an objective or meaningful interaction, a completion condition, and replay/reset.

Prompt 25E does not implement any of these.

## Later tools

- Character/body editor.
- Wardrobe/garment/outfit editor.
- Level editor.
- Mission/objective editor.

These tools must export the same production definitions consumed by the runtime and validator. They must not introduce an editor-only skeleton, collider, garment-fit model, layer model, or atlas identity system.

## Deferred general-engine features

- Runtime 3D or 3D-to-2D generation.
- Arbitrary 360-degree character rotation.
- General cloth simulation or clothing collision.
- Arbitrary full-body paired-pose solving.
- Universal game-editor suite.
- Unrestricted scripting ecosystem.
- Broad combat/enemy framework.
- Inventory economy.
- Dialogue framework.
- Save-game platform.
- Networking.
- Weather, liquids, or unrelated world simulation.

## Binding rule

Future extensibility is a documentation and schema-design constraint, not permission to implement speculative systems. A runtime extension belongs in a milestone only when accepted production content or the immediately following authorized milestone needs it and the existing authority cannot represent it.
