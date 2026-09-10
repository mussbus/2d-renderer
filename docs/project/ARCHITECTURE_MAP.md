# Architecture Map

> **Current authority note (2026-08-31):** F1-F4 are accepted. F4A, F4B1,
> F4B2, F4C1, F4C2, F4C3, F4C4, F4C5, F4D, and F4E are owner-approved. The
> Final F4 Independent Acceptance Audit inspected commit
> `48a7c677d781543e479b178c6e7b10b139eeb26e`, found no CRITICAL or MAJOR
> blocker, and passed every required final gate. The map below describes the
> accepted post-F4 production architecture. Historical prompt/milestone
> records under `docs/history` are non-normative.

This map supplements, rather than replaces, the normative details in
[../ARCHITECTURE.md](../ARCHITECTURE.md). It names the current production
modules and their current authority boundaries.

## Accepted post-F4 ownership on master

All five parallel foundations are accepted and present on master at
`d71c4ae439d0b04019734cd3f45b7a6366a6a00f`. The
[current status record](CURRENT_STATE.md#accepted-post-f4-foundations-on-master-2026-09-06)
provides commit provenance and scope. Coexistence on master does not create
cross-system adoption or override any existing authority boundary.

| Lane | Independent authority |
| --- | --- |
| PSM01 | Scalar secondary motion and authored rate response under physics; no anatomical or representation binding |
| World Time | [world/root.zig](../../src/world/root.zig) and [time.zig](../../src/world/time.zig): caller-owned logical time; no wall clock, weather or environment ownership |
| Engine Lab EL1 | [app/engine_lab](../../src/app/engine_lab): independent persistent hub/application composition; lower engine modules do not import it |
| RR1 | Bounded record/replay protocol and external controller-proof adapter, described below; no general Engine Lab or scene replay |
| Effects/Projectiles | Separate 2D cores and optional composition, described below; standalone visual proof |

Future adoption among these lanes, PHY adapters, world/environment integration,
canonical-generated actor presentation and gameplay remain separately scoped.
This record does not authorize EL2 or PSM02.

## Accepted parallel Effects and Projectiles ownership

Owner-accepted feature `c0421e5182b9adb5fece7fb38520c9181bf8b038` was integrated
through merge `493549cfc31b3d768b680f7284b6bd7fae517c7a`, followed by acceptance
documentation `d71c4ae439d0b04019734cd3f45b7a6366a6a00f`, both on master. This is a parallel
foundation pulled forward from later roadmap work; it does not renumber or
complete M03, M04, Phase D, Phase L or any editor milestone.

| Module | Authority and boundary |
| --- | --- |
| [`projectiles`](../../src/projectiles/root.zig) | Deterministic 2D transient identity, lifecycle, commands, deflection and state; consumes a client-supplied [collision query](../../src/projectiles/collision_query.zig), with no effects or presentation ownership |
| [`effects`](../../src/effects/root.zig) | Independent deterministic 2D CPU emitters and particles; no projectile, physics-body, SDL or GPU ownership |
| [`projectile_effects`](../../src/effect_composition/projectile_effects.zig) | Optional one-way projectile-event to effects composition |
| [Standalone scene](../../src/app/effects_projectiles_scene.zig), [view](../../src/app/effects_projectiles_view.zig) and [application](../../src/app/effects_projectiles.zig) | Scenario/query composition, translation of copied values into existing graphics requests, and SDL3 GPU renderer lifetime respectively |

The visual proof remains standalone. PHY, Engine Lab, RR1, world/environment,
3D presentation and gameplay-specific integration are deferred; existing
registrations do not imply adoption. See the
[accepted implementation and validation record](../implementation/effects_projectiles_foundation.md).

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
Nine static boxes retain the launcher and target. The accepted traversal checkpoint
excluded collectibles; the separate bounded follow-up is described below.
Traversal and corrected F4 zoom are **OWNER ACCEPTED** on
`feature/engine-lab-integration`. Independent source/evidence review and owner
acceptance are complete for reviewed source
`69330e7111d19fe784fa99ce59abd4df19595b1c1a2d5693dc0052900ed540d6`.
The reviewer inspected the source and evidence; Windows/Zig/D3D12 executions
belong to the implementation session. The accepted final bound is 2,254/2,286
sprites, 32 spare and three batches. World Time and closed EL1 acceptance remain
unchanged. This feature-branch acceptance does not imply incorporation into
master. Earlier traversal bounds, failed attempts and evidence limitations remain
in the implementation record.

The [bounded collectible challenge](../implementation/engine_lab_collectibles.md) adds
six ordered physical-contact pickups to the expanded hub, C/gamepad north start or
restart, separate collection effects and a fixed HUD/offscreen arrow. Implementation
and final automated validation are complete; independent review and owner acceptance
remain pending. The final Debug suite passed 751 tests; 395 affected tests passed in
each optimization mode. Combined presentation is bounded at 2,453/2,560 sprites,
107 spare and three batches.
It preserves the accepted traversal/zoom boundary and does not imply a master merge.

## Integrated production flow

The [accepted Engine Lab projectile-impact checkpoint](../implementation/engine_lab_projectile_impact.md)
adds a physics-owned per-AABB `collision_world.static_sweep` helper. The hub
enumerates its existing world into the accepted projectile query port, then
consumes native events through the accepted bridge and extracts ordinary
production SpriteRequests. Physics has no application/projectile/effects
dependency. The [follow-up](../implementation/engine_lab_multi_projectile_follow_up.md)
uses exact bounded dyadic slab comparisons, eight concurrent projectiles and
hub-owned seeded palette tags. An optional value-only, per-event bridge RGB
override copies colors into emitted definitions; both cores and native event
formats remain unchanged. The projectile-impact checkpoint is owner accepted
at `6e4f7c2aadf24c2336ab3cba2d60ff127e750e0e`, including eight-shot visuals
and passing independent source/evidence review reported by the owner. This
feature-branch acceptance does not claim incorporation into master. The standalone
foundation proof and other deferred integrations retain their own authority.

```text
Character / Anatomy Definition
+ Morphology / Body Preset
+ Equipment / Outfit Definitions
+ Character and Wardrobe Art Packs
        |
        v
F RuntimeScene identity / lifecycle / transform
        |
        v
Bounded Character Entity Binding
        |
        v
Specialized Character Runtime
        |
        v
Controller / Animation / Interaction
        |
        v
Presentation View Resolution
        |
        v
Semantic Body + Equipment Visual Resolution
        |
        v
View / Facing / Reflection Policy
        |
        v
Deformation + Secondary Motion + IK
        |
        v
Body-Relative and Interaction-Qualified Ordering
        |
        +------------------------------+
                                       |
World / Collision Definition           |
+ Environment Theme                    |
        |                              |
        v                              |
Layered World Presentation             |
        |                              |
        +------------------------------+
                       |
                       v
           Unified Sprite + Mesh Queue
                       |
                       +--> VF-01 read-only truth snapshot
                       |      |
                       |      +--> F1 bounded overlay through the same queue
                       |      +--> F4 JSON/summary/manifest
                       |      +--> clean/debug D3D12 readback
                       |
                       v
          Atlas-Backed SDL3 GPU Rendering
```

`visual_foundation.Scene` is the current visible `--demo foundation`
composition root. It owns the Prompt 26 environment scene and its two Prompt
25 production character instances. The earlier
`foundation_playground.Scene` remains a focused Prompt 22 regression and
collider-data authority.

## Actual module ownership

| Stage | Current authority |
|---|---|
| Prompt 27 integration root | [`src/scene/visual_foundation.zig`](../../src/scene/visual_foundation.zig) |
| Prompt 27A capture predicates and fixed-tick tracker | [`src/scene/foundation_evidence.zig`](../../src/scene/foundation_evidence.zig) |
| Prompt 27A read-only acceptance HUD | [`src/debug/acceptance_hud.zig`](../../src/debug/acceptance_hud.zig) |
| Prompt 27A deterministic review/repeatability tools | [`tools/build_p27a_review_package.ps1`](../../tools/build_p27a_review_package.ps1), [`tools/compare_p27a_repeats.ps1`](../../tools/compare_p27a_repeats.ps1) |
| Prompt 27B semantic contact/framing/parallax/presence authority | [`src/scene/foundation_coherence.zig`](../../src/scene/foundation_coherence.zig) |
| Prompt 27B semantic report route | [`src/scene/foundation_coherence_report.zig`](../../src/scene/foundation_coherence_report.zig) |
| Prompt 27B D3D12 readback review | [`tools/build_p27b_review_package.ps1`](../../tools/build_p27b_review_package.ps1) |
| Prompt 27C anatomy-quality contracts and report | [`src/scene/anatomy_quality.zig`](../../src/scene/anatomy_quality.zig), [`src/scene/anatomy_quality_report.zig`](../../src/scene/anatomy_quality_report.zig) |
| Prompt 27C state-conditioned D3D12 evidence | [`src/scene/anatomy_evidence.zig`](../../src/scene/anatomy_evidence.zig), [`tools/build_p27c_review_package.ps1`](../../tools/build_p27c_review_package.ps1) |
| Prompt 27C deterministic art reauthoring and audit | [`tools/author_anatomy_art.ps1`](../../tools/author_anatomy_art.ps1), [`tools/audit_anatomy_art.ps1`](../../tools/audit_anatomy_art.ps1) |
| VF-01 truth snapshot, overlay categories, schema, bundle finalization, and PNG writer | [`src/debug/visual_truth.zig`](../../src/debug/visual_truth.zig) |
| VF-01 F1/F4 scene orchestration | [`src/scene/visual_foundation.zig`](../../src/scene/visual_foundation.zig) |
| Application mode routing, scenario lifetime, and capture scheduling | [`src/app/demo_application.zig`](../../src/app/demo_application.zig) |
| Independent engine composition proof | [`src/app/engine_smoke.zig`](../../src/app/engine_smoke.zig) with client-owned RuntimeScene composition in [`src/app/engine_smoke_client.zig`](../../src/app/engine_smoke_client.zig); no demo/evidence dependency |
| Generic persistent/runtime scene identity, lifetime, enabled state and transform | Supported [`src/scene_core/root.zig`](../../src/scene_core/root.zig) surface; `RuntimeScene` implementation remains private behind that root |
| F-to-character specialized binding | [`src/scene/character_entity_binding.zig`](../../src/scene/character_entity_binding.zig), private fixed-capacity mapping; consumed by the representative [`src/scene/integrated_demo.zig`](../../src/scene/integrated_demo.zig) route and independent CPU composition tests |
| SDL window/device/resource lifetime, queue execution, upload, and generic D3D12 readback | [`src/graphics/sdl_gpu_renderer.zig`](../../src/graphics/sdl_gpu_renderer.zig) |
| Copied frame result contract | [`src/graphics/frame_capture.zig`](../../src/graphics/frame_capture.zig) |
| Historical PPM/PNG evidence output | [`src/evidence/capture_writer.zig`](../../src/evidence/capture_writer.zig) |
| GPU smoke ownership | [`src/app/engine_smoke.zig`](../../src/app/engine_smoke.zig), direct production-renderer client |
| Physical platform input | [`src/platform/input.zig`](../../src/platform/input.zig), [`src/platform/sdl_input.zig`](../../src/platform/sdl_input.zig) |
| Application/demo action mapping | [`src/app/demo_actions.zig`](../../src/app/demo_actions.zig) |
| Character movement/interaction intent value | [`src/physics/character_intent.zig`](../../src/physics/character_intent.zig) |
| Character definition/runtime | [`src/scene/character.zig`](../../src/scene/character.zig) exposes commands/read-only views over private inline `CharacterState`; [`src/scene/humanoid.zig`](../../src/scene/humanoid.zig) owns humanoid pose/appearance runtime |
| Skeleton, poses, clips, state machine | [`src/animation/skeleton.zig`](../../src/animation/skeleton.zig), [`src/animation/pose.zig`](../../src/animation/pose.zig), [`src/animation/clip.zig`](../../src/animation/clip.zig), [`src/animation/state_machine.zig`](../../src/animation/state_machine.zig) |
| Anatomy identity/runtime | [`src/scene/anatomy.zig`](../../src/scene/anatomy.zig), production definitions in [`src/scene/humanoid.zig`](../../src/scene/humanoid.zig) |
| VF-03 compiled component-topology authority | [`src/scene/component_graph.zig`](../../src/scene/component_graph.zig), compiled from immutable appearance/anatomy definitions |
| Body presets/morphology | Anatomy/body-preset and morphology declarations in [`src/scene/anatomy.zig`](../../src/scene/anatomy.zig) and [`src/scene/humanoid.zig`](../../src/scene/humanoid.zig) |
| Appearance semantics and attachment points | [`src/scene/appearance.zig`](../../src/scene/appearance.zig) |
| Base character presentation | [`src/scene/character_art.zig`](../../src/scene/character_art.zig), [`src/scene/presentation_pose.zig`](../../src/scene/presentation_pose.zig), [`src/scene/presentation_view.zig`](../../src/scene/presentation_view.zig) |
| Equipment identity, slots, recipes, loadout | [`src/scene/equipment.zig`](../../src/scene/equipment.zig) |
| Wardrobe definitions and presets | [`src/scene/wardrobe_catalog.zig`](../../src/scene/wardrobe_catalog.zig) |
| Wardrobe view/art resolution and submission | [`src/scene/wardrobe_art.zig`](../../src/scene/wardrobe_art.zig), [`src/scene/wardrobe_presentation.zig`](../../src/scene/wardrobe_presentation.zig) |
| Art-pack pages/regions/semantic bindings | [`src/graphics/art_pack.zig`](../../src/graphics/art_pack.zig), character, wardrobe, and environment definitions under [`src/scene`](../../src/scene) |
| Environment theme definitions/art | [`src/scene/environment_theme.zig`](../../src/scene/environment_theme.zig), [`src/scene/environment_art.zig`](../../src/scene/environment_art.zig) |
| Environment scene and collision-derived surfaces | [`src/scene/environment_demo.zig`](../../src/scene/environment_demo.zig), with retained collider data from [`src/scene/foundation_playground.zig`](../../src/scene/foundation_playground.zig) |
| Controller and fixed-step root physics | [`src/physics/character_controller.zig`](../../src/physics/character_controller.zig), [`src/physics/fixed_step.zig`](../../src/physics/fixed_step.zig) |
| Interaction definition and coordination | [`src/interaction/interaction.zig`](../../src/interaction/interaction.zig), private lifecycle authority behind `Manager` in [`src/interaction/interaction_system.zig`](../../src/interaction/interaction_system.zig), [`src/interaction/handshake.zig`](../../src/interaction/handshake.zig) |
| IK | [`src/animation/arm_ik.zig`](../../src/animation/arm_ik.zig), [`src/animation/leg_ik.zig`](../../src/animation/leg_ik.zig), [`src/animation/two_bone_ik.zig`](../../src/animation/two_bone_ik.zig) |
| Generic scalar secondary motion (PSM01, ACCEPTED at 43ae062) | [`src/physics/secondary_motion.zig`](../../src/physics/secondary_motion.zig) reuses [`src/physics/spring.zig`](../../src/physics/spring.zig); [authored rate resolution](../../src/physics/secondary_motion_rate.zig) produces validated profiles for the same fixed-tick solver; [accepted generic contract and offline trace evidence](../implementation/psm01_secondary_motion.md). Final anatomical tuning and production bindings are outside generic foundation acceptance. The bounded Engine Lab calibration consumer is owner accepted as described above. |
| Deformation and secondary motion | [`src/scene/deformation.zig`](../../src/scene/deformation.zig), [`src/animation/attachment_secondary_motion.zig`](../../src/animation/attachment_secondary_motion.zig), [`src/graphics/deformable_mesh.zig`](../../src/graphics/deformable_mesh.zig) |
| Visual-geometry metadata, traces, and audits | [`src/scene/visual_geometry.zig`](../../src/scene/visual_geometry.zig), [`src/scene/visual_geometry_audit.zig`](../../src/scene/visual_geometry_audit.zig) |
| Unified ordering | [`src/graphics/render_queue.zig`](../../src/graphics/render_queue.zig) and `sprite.OrderInput` in [`src/graphics/sprite_batch.zig`](../../src/graphics/sprite_batch.zig) |
| GPU device, resources, batching, renderer | [`src/platform/sdl.zig`](../../src/platform/sdl.zig), [`src/graphics/sdl_gpu_renderer.zig`](../../src/graphics/sdl_gpu_renderer.zig), [`src/graphics/sprite_batch.zig`](../../src/graphics/sprite_batch.zig), [`src/graphics/mesh_gpu_catalog.zig`](../../src/graphics/mesh_gpu_catalog.zig) |

## Authoritative boundaries

| Identity or behavior | Authority | Must not be inferred from |
|---|---|---|
| Gameplay facing | `humanoid.Facing` on the character instance | Sprite scale sign, shoe orientation, or atlas layout |
| Presentation view | `presentation_view.View` resolved from character state and optional interaction role claim | Filename or texture-page choice |
| Anatomical left/right identity | Typed anatomy part instance | Final mirrored quad or screen position |
| Runtime component topology | Compiled immutable `component_graph.Definition` over appearance/anatomy owners | Alpha overlap, draw order, or runtime-created joints |
| Component connection semantics | Explicit `continuous`, `intentional_gap`, `hidden`, or `soft_bridge` data on the instance/socket contract | Whether adjacent sprite alpha happens to overlap |
| Equipment item identity | Typed `EquipmentItemId` in the loadout | Visual component, atlas region, or garment color |
| Visual fragment identity | Currently typed `ItemVisualRecipeId` + component; future stable authored fragment ID is documented | Draw order or source rectangle |
| Atlas-region identity | Typed art-pack region ID selected through semantic/view binding | Logical item or theme ID |
| Physics/collision | Physics body, collider, collision world, and support surfaces | Opaque sprite bounds, garment-fit contours, or painted terrain |
| Standable white environment edge | Deterministic projection of `solid && ground_query_eligible` collider tops | Theme artwork, decorative ledges, or debug geometry |
| Environment theme identity | Typed preloaded theme definition | File path, collision identity, or active GPU page |
| Visual fit geometry | Semantic landmarks, axes, alpha-visible bounds, fit/coverage contracts | Physics collider, raw quad, or atlas dimensions alone |
| Migrated character visual placement | `visual_registration` over active projected targets and alpha-visible atlas landmarks | Authored pivot/size alone or a validator-only expectation |
| Render ordering | Unified queue order tuple; wardrobe preserves its visual layer and may inherit a bound anatomy interaction layer | Submission timing or a second clothing renderer |
| Interaction ownership | Interaction manager and handshake state | Animation clip coincidence, view appearance, or full-body teleport |
| Interaction view/occlusion policy | Validated `interaction.PresentationDefinition` on the interaction definition | Manager constants, outfit IDs, or renderer callbacks |

Changing facing, view, outfit, or environment theme changes resolved
presentation data. It does not change anatomical identity, collider ownership,
interaction roots, decode images, create GPU resources, or create a new
renderer.

## Gameplay geometry versus visual-authoring geometry

These geometries are related but not interchangeable.

### Gameplay geometry

- physics collider;
- collision bounds;
- static support and grounding surfaces;
- interaction eligibility, reach, and target geometry.

Gameplay geometry answers whether the character can move, stand, collide, or
interact.

### Visual-authoring geometry

- visible torso and hip contours;
- neck base and collar region;
- clavicle line;
- left/right shoulder slope, seam, root, and armhole;
- garment waist and hem;
- limb visual extents;
- semantic attachment landmarks and directional axes;
- alpha-visible bounds and coverage zones;
- environment parallax placement and decorative presentation.

Visual-authoring geometry answers whether visible art fits, layers,
articulates, or communicates gameplay surfaces correctly. A rectangular torso
collider, raw sprite rectangle, opaque bounds, or atlas dimensions may
contribute evidence, but none is sufficient as a garment-fitting contour.
Conversely, painted terrain never becomes collision.

## Current ordering model

Every anatomy sprite, equipment sprite, deformable mesh, environment visual,
standable-edge visual, and debug primitive enters the same bounded
[`UnifiedRenderQueue`](../../src/graphics/render_queue.zig). The queue sorts
the resolved order tuple and preserves batching. Current wardrobe content
declares named visual layers which resolve to numeric `body_part_layer` values.
During an interaction, a bound equipment visual inherits the interaction layer
of its actual anatomy semantic while retaining that clothing layer. Numeric
depth values remain stable for accepted content, but general relations such as
`behind_neck` remain a documented schema gap; see
[AUTHORING_CONTRACTS.md](AUTHORING_CONTRACTS.md).

## Environment and integration boundary

Environment themes resolve presentation over the one immutable world:

```text
World / Collision Definition
+ Preloaded Environment Theme
        |
        v
Layered Environment Presentation
        |
        v
Unified Render Queue
```

Collision remains authoritative gameplay data. Theme switching changes only a
resolved presentation ID and performs no file I/O, image decode, allocation,
or GPU-resource creation in steady state.

Prompt 27 composes that environment path with the existing character,
wardrobe, interaction, IK, camera, diagnostics, and GPU paths. It adds no
parallel implementation of any subsystem.

VF-01 observes that composition after production submission. It explicitly
distinguishes authoritative controller/collider state, canonical pose,
view-specific presentation projection, appearance/anatomy/module topology,
atlas/source metadata, final queue submissions, automated acceptance
evidence, and owner visual approval. Only the first six become snapshot data;
automated evidence remains diagnostic, and owner approval remains external
and `[PENDING OWNER REVIEW]`.

VF-02 makes the bounded core character path a producer, rather than merely a
consumer, of visual-geometry truth. Both arms, forearms, thighs, shins, feet,
torso, pelvis, and the nose are submitted from one point/segment/frame
registration solver in front and side presentation. The solver's final
request and residual evidence enter the existing trace and queue. Equipped
shoes also use the point-axis solver: the registered anatomy-foot
`PointAxisTarget` owns their ankle/orientation target, while their source
ankle/sole landmarks supply the atlas frame. Closed-footwear metadata gives
the shoe visible-envelope ownership, suppresses only covered base-foot
pixels, and retains the hidden base-foot trace. Other wardrobe and unmigrated
character visuals remain explicitly classified compatibility or transitional
paths; they are not silently described as authoritative.

VF-03 compiles one inspectable topology facade from the existing appearance
and anatomy records. It exports component parents, typed sockets, connection
modes, selected visuals, and explicit module ownership through VF-01 schema
4. Front and side projection resolve component/module/visual-parent sources
without creating runtime joints. Direct eye, eyebrow, and hair visuals use
their projected component targets through the shared point-registration
solver. Existing standard character, equipment, controller, interaction,
queue, and GPU authorities remain unchanged.

VF-03-R1 closes the facade-to-render boundary: an active optional arm's three
declared graph visuals must resolve to three production `character_art`
submissions, each bound to the exported projected module chain. Final trace,
F1, JSON, summary, and validation consume those same request records. The
technical arm uses the existing atlas, global queue, D3D12 renderer, and
resource ownership; no graph-only or overlay-only renderer exists.

## RR1 record/replay ownership

| Boundary | Authority |
| --- | --- |
| Bounded V1 sessions, three streams, canonical encoding/loading, fingerprints, named markers and divergence | [record_replay/root.zig](../../src/record_replay/root.zig), importing foundation/std only |
| CharacterIntent, causal speed changes and observed controller StepResult adapters | [record_replay_proof.zig](../../src/app/record_replay_proof.zig), a normal external client |
| Headless proof and protocol/error/allocation tests | [record_replay_tests.zig](../../tests/record_replay_tests.zig), existing engine-test and fast-gate registration |

The [V1 contract](../architecture/deterministic_record_replay_v1.md) preserves
physical input -> actions -> semantic tick commands. Causal events apply before
the existing controller step; observed events, fingerprints and names verify
after it. The static RuntimeScene snapshot is acquired only at initialization.
Dynamic publication and arbitrary specialized scenes remain outside RR1.
Screenshot and JSON capture belong to future non-authoritative sidecars.
