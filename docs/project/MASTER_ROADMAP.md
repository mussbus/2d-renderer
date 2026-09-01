# Master Roadmap

## Accepted production-architecture foundation

The Foundation milestones F1, F2A, F2B, F2C and F3 are owner-approved. The
F2C authority-encapsulation amendment at
`685383a9012f10769c89b363d2eeff820410e0ae` is accepted.

F4A, F4B1, F4B2, F4C1, F4C2, F4C3, F4C4, F4C5, F4D, and F4E are
owner-approved. The Final F4 Independent Production Architecture Acceptance
Audit inspected commit `48a7c677d781543e479b178c6e7b10b139eeb26e`, found
no CRITICAL or MAJOR blocker, verified every original F4A CRITICAL/MAJOR
finding as resolved, and passed every required final gate. The owner accepts
that audit and **F4 — Production Architecture Hardening is ACCEPTED**.

The completed sequence is:

```text
F4A whole-repository audit
  -> F4-ADMIN (current state-recording step)
  -> F4B1 safe hygiene and retention groundwork
  -> F4B2 superseded demo/test retirement with replacement coverage
  -> F4C1-F4C5 production architecture migration
  -> F4D independent-engine and decoupling proof
  -> F4E repository canonicalization and provenance cleanup
  -> Final F4 Independent Acceptance Audit
  -> owner acceptance
  -> post-F4 parallel development available through dedicated requests
```

Milestone-time implementation records retain their original candidate wording.
Current disposition and post-F4 readiness are recorded in
[CURRENT_STATE.md](CURRENT_STATE.md).

The renderer/character phases below remain useful implementation history and
capability inventory. They do not supersede the accepted F4 contracts.

## Product target

The present project target is:

> A modular 2D character and world runtime capable of supporting one polished
> side-scrolling gameplay vertical slice, with stable validated data contracts
> suitable for future authoring tools.

This is not a finished general-purpose game engine. Each phase below is bounded
by the production contracts already implemented and by the explicit scope in
[SCOPE_BOUNDARIES.md](SCOPE_BOUNDARIES.md).

## Phase 1 — Renderer and deterministic runtime foundation

Status: **automated integration complete; manual visual acceptance reopened**

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

Status: **automated implementation complete; current anatomy owner review pending**

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
- Prompt 27C versioned and reauthored the production base anatomy, hardened
  style/view silhouette and joint-continuity contracts, and added repeatable
  body-only D3D12 evidence. Owner visual review remains pending.

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
- Prompt 27A: a 16-case state-conditioned capture matrix, validated semantic
  metadata, bounded same-queue HUD, deterministic contact sheets/raw metrics,
  and byte-exact two-run repeatability. Owner visual review remains pending.
- Prompt 27B: measured collider/socket/alpha/pixel ground contact, bounded
  existing-camera safe framing, actual-factor semantic and D3D12 parallax,
  and non-teleport scripted character presence. Owner visual review remains
  pending.

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

Prompts 0–27C remain the historical implementation sequence. F4 is accepted,
and its architecture gate no longer blocks post-F4 development. SEM, SAF, MAT,
CHR, CL, OBJ, LVL, AN, INT, PHY, WRD, ENV, and IMG are architecture-ready for
dedicated implementation requests. PFB, SCN, PG, AI, GAME, and ED retain the
specific dependency gates recorded in [CURRENT_STATE.md](CURRENT_STATE.md).
This status record begins none of those tracks. Current non-blocking visual
limitations, pending visual owner review, and future schema triggers remain
recorded in [KNOWN_GAPS.md](KNOWN_GAPS.md).
