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

## Accepted post-F4 parallel foundations on master

PSM01 Secondary Motion, World Time Foundation, Engine Lab EL1, RR1 deterministic
Record/Replay, and Effects and Projectiles Foundation are accepted within their
bounded scopes and present on master. The
[current five-lane record](CURRENT_STATE.md#accepted-post-f4-foundations-on-master-2026-09-06)
identifies their implementation commits and independent ownership boundaries.
Effects/Projectiles merge `493549cfc31b3d768b680f7284b6bd7fae517c7a` and
acceptance-document commit `d71c4ae439d0b04019734cd3f45b7a6366a6a00f` are on master.

The unnumbered checkout/status correction is owner-accepted repository-integrity
work on master at `dca3b331a86abee43a271cc00292021334ab8612`, following a direct
fast-forward with no separate merge commit. It advances no product milestone,
does not integrate these systems with one another or authorize EL2, PSM02,
gameplay, representation bindings, or any new milestone. All explicit deferred work and
M03/M04, phase and editor numbering remain unchanged.

## Accepted post-F4 PSM01 milestone

**PSM01 — Deterministic Secondary-Motion Foundation is ACCEPTED at
43ae062867d8bda79b1ba364ad6e934c0beee8c7.** The owner accepts the generic
scalar solver, authored rate-response resolver, fixed-step and determinism
contracts, synthetic calibration, and offline/runtime proof. The
[PSM01 record](../implementation/psm01_secondary_motion.md) supplies the scope,
validation evidence and retained implementation provenance.

Acceptance excludes final anatomical tuning and production bindings. It does
not accept the whole PHY track, begin PSM02 or baking, migrate current 2D
consumers, or change M03/M04 status or ordering.

## Accepted parallel Effects and Projectiles Foundation

The owner accepted `c0421e5182b9adb5fece7fb38520c9181bf8b038`, integrated through
merge `493549cfc31b3d768b680f7284b6bd7fae517c7a`. This owner-authorized parallel
foundation was pulled forward from later effects/projectile work; it does not
renumber or complete M03, M04, Phase D, Phase L or any editor milestone.

The projectile and effects cores are currently 2D and the visual proof is
standalone. PHY, Engine Lab, RR1, world/environment, 3D presentation and
gameplay-specific integration require future dedicated work. Acceptance does
not start those tasks or change their prerequisite gates. See the
[implementation record](../implementation/effects_projectiles_foundation.md).

The separately requested [Engine Lab PSM01 calibration binding](../implementation/engine_lab_psm01_calibration_binding.md)
adds one application-owned horizontal response above the provisional actor using
the accepted solver and ordinary movement controls. It is **OWNER ACCEPTED** at
`cfb2876c29df78f0cfa034d3df45ebe19764b141`. Independent source/evidence review
passed: the reviewer inspected patches, source, logs and captures; the
implementation owner performed the Windows/Zig/D3D12 executions. The accepted
conservative presentation is 1,827/1,856 sprites, three batches and 29 sprites
of headroom. Acceptance includes the generic
`Renderer.initializeUnifiedQueueWithCapacities` API; solver and renderer
defaults remain unchanged. The projectile-impact checkpoint remains
accepted at `6e4f7c2aadf24c2336ab3cba2d60ff127e750e0e`. This unnumbered
integration branch has no implied merge into master. The preexisting 1,792-sprite
bound is retained separately; the calibration has a 64-sprite allowance within
an explicitly configured 1,856-sprite CPU queue and three existing batches.

The subsequent [bounded Engine Lab World Time integration](../implementation/engine_lab_world_time.md)
is **OWNER ACCEPTED** at `deacc4e2c6f24873df730a18fc83cc23dfa6b97b`.
Independent source/evidence review and owner visual acceptance passed. The reviewer
inspected reconstructed patches, production code, tests, logs, hashes and native
captures; the implementation owner performed the Windows/Zig/D3D12 executions.
The reviewer did not independently repeat those executions. Acceptance includes
one hub-owned WorldTime advancing from executed ticks, pause, single-step,
navigation, whole-hub reset, snapshot continuation and overflow behavior.
The accepted conservative bound is 1,950/1,984 sprites, three batches and 34 spare.
Feature-branch acceptance does not imply incorporation into master. Historical
pending-status evidence and original raw bytes remain preserved.
One inline accepted
WorldTime advances after each successfully executed hub tick, using authored 60/1
logical time and a day-0 23:59 start. The completed snapshot supplies a bounded
upper-right day/HH:MM label. The original and accepted calibration bounds remain
separate; the additional time allowance is 128 within a 1,984-sprite CPU queue.
Measured complete conservative use is 1,950, with 34 sprites of headroom and three
batches. Shared cores/renderer defaults and static RuntimeScene ownership remain
unchanged. This unnumbered feature work is local and implies no master incorporation.


The [Engine Lab traversal expansion](../implementation/engine_lab_traversal_expansion.md)
opens a 32-metre two-level persistent hub through an explicit expanded construction.
It retains the accepted room as a regression construction and adds authored
5.5 m/s run, 10.5 m/s jump, one air jump, existing horizontal dash and bounded
vertical camera following. The one shared addition is a validated explicit
CharacterInstance movement-property step using the existing synchronization path.
Controller defaults/algorithm and accepted integration cores remain unchanged.
Nine static boxes retain the launcher and target; no collectibles are implemented.
Traversal is **pending independent review and owner visual/gamepad acceptance**.
World Time remains accepted at the exact revision recorded above; neither status
implies incorporation into master. See the implementation record for routes,
separate legacy evidence and the 2,200/2,232 conservative presentation bound.

## Product target

The separately approved [Engine Lab projectile-impact slice](../implementation/engine_lab_projectile_impact.md)
and its [eight-shot color, sweep and glyph-budget follow-up](../implementation/engine_lab_multi_projectile_follow_up.md)
are owner accepted at `6e4f7c2aadf24c2336ab3cba2d60ff127e750e0e`, with
independent source/evidence review reported as passing. Acceptance is on the
integration branch; incorporation into master remains separate and no push or
merge is claimed. Engine Lab Integration is an unnumbered track name. Only static swept geometry and this
fixed projectile-to-impact installation are adopted; all later integrations
and closed EL1 acceptance retain their existing boundaries.

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
PSM01 has the bounded generic acceptance recorded above; this status record
authorizes no additional downstream work. Current non-blocking visual
limitations, pending visual owner review, and future schema triggers remain
recorded in [KNOWN_GAPS.md](KNOWN_GAPS.md).
