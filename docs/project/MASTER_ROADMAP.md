# Master Roadmap

## Product target

The present project target is:

> A modular 2D character and world runtime capable of supporting one polished
> side-scrolling gameplay vertical slice, with stable validated data contracts
> suitable for future authoring tools.

This is not a finished general-purpose game engine. Each phase below is bounded
by the production contracts already implemented and by the explicit scope in
[SCOPE_BOUNDARIES.md](SCOPE_BOUNDARIES.md).

## Phase 1 — Renderer and deterministic runtime foundation

Status: **complete**

- SDL3 platform initialization and Windows 11 D3D12-backed SDL GPU route.
- HLSL-to-DXIL shader pipeline.
- One bounded, atlas-backed indexed/instanced sprite batch.
- Unified sprite and deformable-mesh render queue.
- Fixed 240 Hz simulation with render interpolation.
- Camera, animation, character controller, static collision, interactions, IK,
  and debug diagnostics.
- Keyboard/gamepad input converted to character intent.

Historical scope: Prompts 0–13. Later prompts extended the same ownership model
rather than replacing it.

## Phase 2 — Modular character foundation

Status: **complete**

- Semantic anatomy and optional/repeated body modules.
- Multiple independent character instances.
- Body presets and morphology channels.
- Topology-aware equipment and transactional loadouts.
- Shared anatomy/equipment deformation.
- Deformable mesh visuals.
- Bounded secondary motion.
- Generic character properties and capabilities.
- Focused Character + World Foundation Playground.

Historical scope: Prompts 14–22. Prompt 27 later promoted the visible
`foundation` CLI to the production-art integration root while retaining the
Prompt 22 scene as a focused regression module.

## Phase 3 — Production presentation

Status: **complete for the current production content**

- Real image assets, typed texture pages, atlas regions, and semantic view
  bindings.
- Front and canonical-side male/female character presentation.
- Independent base anatomy, hair, permanent base-presentation modesty
  surfaces, and removable equipment.
- Modular wardrobe items and outfit presets.
- Semantic visual-geometry validation, deterministic D3D12 captures, and
  approved goldens.
- Prompt 25D production-art and presentation corrections.
- Prompt 25E consolidated history, authority, authoring, and known-gap
  contracts.

Historical scope: Prompts 23–25E.

## Phase 4 — Environment and integrated presentation

Status: **complete**

- Prompt 26: two layered image-backed environment themes, bounded hot
  swapping, and collision-derived white standable surfaces over the unchanged
  world.
- Prompt 27: the production `foundation` route composes two accepted
  characters, all current wardrobe, both themes, movement, traversal,
  view-aware interactions, IK, equipment-aware occlusion, cleanup, reset,
  resource bounds, and real D3D12 captures.

Both milestones reuse the existing collision authority, camera, character
instances, interaction system, unified render queue, and SDL3 GPU renderer.
They introduce no alternative world, animation, or rendering path.

## Phase 5 — Narrow gameplay vertical slice

Status: **not started; not currently authorized**

A future bounded playable loop may contain:

- a beginning;
- movement and traversal;
- at least one meaningful interaction or objective;
- a completion condition;
- reset and replay.

This phase is deliberately narrower than a broad combat, mission, economy, or
content framework. Prompt 27 is a systems-integration acceptance route, not
that beginning-to-completion game loop.

## Phase 6 — Authoring tools

Status: **deferred**

Only after runtime schemas and validation contracts are stable:

1. character/body authoring;
2. garment/outfit authoring;
3. level authoring;
4. later mission/objective authoring.

Editors will be user interfaces over ordinary validated production
definitions. They will not own parallel anatomy, equipment, fit, layer,
collision, theme, or atlas-identity models.

## Milestone gate

Prompts 0–27 are implemented. No later milestone is authorized by this
roadmap. Current non-blocking limitations and future schema triggers are
recorded in [KNOWN_GAPS.md](KNOWN_GAPS.md).
