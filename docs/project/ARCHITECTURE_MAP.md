# Architecture Map

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
| Character definition/runtime | [`src/scene/character.zig`](../../src/scene/character.zig), [`src/scene/humanoid.zig`](../../src/scene/humanoid.zig) |
| Skeleton, poses, clips, state machine | [`src/animation/skeleton.zig`](../../src/animation/skeleton.zig), [`src/animation/pose.zig`](../../src/animation/pose.zig), [`src/animation/clip.zig`](../../src/animation/clip.zig), [`src/animation/state_machine.zig`](../../src/animation/state_machine.zig) |
| Anatomy identity/runtime | [`src/scene/anatomy.zig`](../../src/scene/anatomy.zig), production definitions in [`src/scene/humanoid.zig`](../../src/scene/humanoid.zig) |
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
| GPU device, resources, batching, renderer | [`src/platform/sdl.zig`](../../src/platform/sdl.zig), [`src/graphics/gpu_demo.zig`](../../src/graphics/gpu_demo.zig), [`src/graphics/sprite_batch.zig`](../../src/graphics/sprite_batch.zig), [`src/graphics/mesh_gpu_catalog.zig`](../../src/graphics/mesh_gpu_catalog.zig) |

## Authoritative boundaries

| Identity or behavior | Authority | Must not be inferred from |
|---|---|---|
| Gameplay facing | `humanoid.Facing` on the character instance | Sprite scale sign, shoe orientation, or atlas layout |
| Presentation view | `presentation_view.View` resolved from character state and optional interaction role claim | Filename or texture-page choice |
| Anatomical left/right identity | Typed anatomy part instance | Final mirrored quad or screen position |
| Equipment item identity | Typed `EquipmentItemId` in the loadout | Visual component, atlas region, or garment color |
| Visual fragment identity | Currently typed `ItemVisualRecipeId` + component; future stable authored fragment ID is documented | Draw order or source rectangle |
| Atlas-region identity | Typed art-pack region ID selected through semantic/view binding | Logical item or theme ID |
| Physics/collision | Physics body, collider, collision world, and support surfaces | Opaque sprite bounds, garment-fit contours, or painted terrain |
| Standable white environment edge | Deterministic projection of `solid && ground_query_eligible` collider tops | Theme artwork, decorative ledges, or debug geometry |
| Environment theme identity | Typed preloaded theme definition | File path, collision identity, or active GPU page |
| Visual fit geometry | Semantic landmarks, axes, alpha-visible bounds, fit/coverage contracts | Physics collider, raw quad, or atlas dimensions alone |
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
