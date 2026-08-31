# Architecture Map

> **Current authority note (2026-08-30):** F1, F2A, F2B, F2C and F3 are
> owner-approved. F4A is owner-approved, and F4 production-architecture
> hardening is the current track. The composition map below describes the
> existing demo-driven runtime audited by F4A; it is not the accepted post-F4
> target architecture. F4B1, F4B2, and F4C1 are owner-approved. F4C2 has
> extracted renderer/application/evidence ownership and awaits owner review.
> See the [F4C2 record](../implementation/f4c2_renderer_application_evidence_boundaries.md).

This map supplements, rather than replaces, the normative details in
[../ARCHITECTURE.md](../ARCHITECTURE.md). It names the current production
modules and their authority boundaries through Prompt 27.

## Integrated production flow

```text
Character / Anatomy Definition
+ Morphology / Body Preset
+ Equipment / Outfit Definitions
+ Character and Wardrobe Art Packs
        |
        v
Character Runtime
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
| Prompt 27C deterministic art reauthoring and audit | [`tools/reauthor_p27c_anatomy.ps1`](../../tools/reauthor_p27c_anatomy.ps1), [`tools/audit_p27c_art.ps1`](../../tools/audit_p27c_art.ps1) |
| VF-01 truth snapshot, overlay categories, schema, bundle finalization, and PNG writer | [`src/debug/visual_truth.zig`](../../src/debug/visual_truth.zig) |
| VF-01 F1/F4 scene orchestration | [`src/scene/visual_foundation.zig`](../../src/scene/visual_foundation.zig) |
| Application mode routing, scenario lifetime, and capture scheduling | [`src/app/demo_application.zig`](../../src/app/demo_application.zig) |
| SDL window/device/resource lifetime, queue execution, upload, and generic D3D12 readback | [`src/graphics/sdl_gpu_renderer.zig`](../../src/graphics/sdl_gpu_renderer.zig) |
| Copied frame result contract | [`src/graphics/frame_capture.zig`](../../src/graphics/frame_capture.zig) |
| Historical PPM/PNG evidence output | [`src/evidence/capture_writer.zig`](../../src/evidence/capture_writer.zig) |
| Legacy `GpuDemo` source compatibility | [`src/graphics/gpu_demo.zig`](../../src/graphics/gpu_demo.zig), alias only |
| VF-01 frame-level platform input | [`src/platform/input.zig`](../../src/platform/input.zig), [`src/platform/sdl_input.zig`](../../src/platform/sdl_input.zig) |
| Character definition/runtime | [`src/scene/character.zig`](../../src/scene/character.zig), [`src/scene/humanoid.zig`](../../src/scene/humanoid.zig) |
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
| Interaction definition and coordination | [`src/interaction/interaction.zig`](../../src/interaction/interaction.zig), [`src/interaction/interaction_system.zig`](../../src/interaction/interaction_system.zig), [`src/interaction/handshake.zig`](../../src/interaction/handshake.zig) |
| IK | [`src/animation/arm_ik.zig`](../../src/animation/arm_ik.zig), [`src/animation/leg_ik.zig`](../../src/animation/leg_ik.zig), [`src/animation/two_bone_ik.zig`](../../src/animation/two_bone_ik.zig) |
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
