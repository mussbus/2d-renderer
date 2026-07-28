# Master Roadmap

## Product target

The present project target is:

> A modular 2D character and world runtime capable of supporting one polished side-scrolling gameplay vertical slice, with stable validated data contracts suitable for future authoring tools.

This is not a finished general-purpose game engine. Each phase below is bounded by the production contracts already implemented and by the explicit scope in [SCOPE_BOUNDARIES.md](SCOPE_BOUNDARIES.md).

## Phase 1 — Renderer and deterministic runtime foundation

Status: **complete**

- SDL3 platform initialization and Windows 11 D3D12-backed SDL GPU route.
- HLSL-to-DXIL shader pipeline.
- One bounded, atlas-backed indexed/instanced sprite batch.
- Unified sprite and deformable-mesh render queue.
- Fixed 240 Hz simulation with render interpolation.
- Camera, animation, character controller, static collision, interactions, IK, and debug diagnostics.
- Keyboard/gamepad input converted to character intent.

Historical scope: Prompts 0–13. Later prompts extended the same ownership model rather than replacing it.

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
- Integrated Character + World Foundation Playground.

Historical scope: Prompts 14–22.

## Phase 3 — Production presentation

Status: **complete for the current production content**

- Real image assets, typed texture pages, atlas regions, and semantic view bindings.
- Front and canonical-side male/female character presentation.
- Independent base anatomy, hair, permanent base-presentation modesty surfaces, and removable equipment.
- Modular wardrobe items and outfit presets.
- Semantic visual-geometry validation, deterministic D3D12 captures, and approved goldens.
- Prompt 25D production-art and presentation corrections.

Historical scope: Prompts 23–25D. Prompt 25E consolidates the contracts, history, and known gaps without changing accepted art.

## Phase 4 — Environment and integrated presentation

Status: **planned; not started**

- Prompt 26: layered environment art, hot-swappable themes, and collision-derived gameplay readability.
- Prompt 27: integrated visual foundation and view-aware interaction presentation.

These milestones must reuse the existing world/collision and unified-render-queue authorities. They are not implemented by Prompt 25E.

## Phase 5 — Narrow gameplay vertical slice

Status: **not started**

A bounded playable loop will contain:

- a beginning;
- movement and traversal;
- at least one meaningful interaction or objective;
- a completion condition;
- reset and replay.

This phase is deliberately narrower than a broad combat, mission, economy, or content framework.

## Phase 6 — Authoring tools

Status: **deferred**

Only after runtime schemas and validation contracts are stable:

1. character/body authoring;
2. garment/outfit authoring;
3. level authoring;
4. later mission/objective authoring.

Editors will be user interfaces over ordinary validated production definitions. They will not own parallel anatomy, equipment, fit, layer, or collision models.

## Milestone gate

Prompt 26 is the next planned milestone after Prompt 25E, but it may begin only with explicit authorization. Current blockers and non-blocking gaps are recorded in [KNOWN_GAPS.md](KNOWN_GAPS.md).
