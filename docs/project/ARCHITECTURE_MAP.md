# Architecture Map

This map supplements, rather than replaces, the normative details in [../ARCHITECTURE.md](../ARCHITECTURE.md). It names the current production modules and their authority boundaries.

## Character production data flow

```text
Character Definition
+ Anatomy Definition
+ Morphology / Body Preset
+ Equipment / Outfit Definitions
+ Art Pack
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
Body-Relative Visual Ordering
        |
        v
Unified Sprite + Mesh Render Queue
        |
        v
Atlas-Backed GPU Rendering
```

### Actual module ownership

| Stage | Current authority |
|---|---|
| Character definition/runtime | [`src/scene/character.zig`](../../src/scene/character.zig), [`src/scene/humanoid.zig`](../../src/scene/humanoid.zig) |
| Skeleton, poses, clips, state machine | [`src/animation/skeleton.zig`](../../src/animation/skeleton.zig), [`src/animation/pose.zig`](../../src/animation/pose.zig), [`src/animation/clip.zig`](../../src/animation/clip.zig), [`src/animation/state_machine.zig`](../../src/animation/state_machine.zig) |
| Anatomy identity/runtime | [`src/scene/anatomy.zig`](../../src/scene/anatomy.zig), production definitions in [`src/scene/humanoid.zig`](../../src/scene/humanoid.zig) |
| Body presets/morphology | Anatomy/body-preset and morphology declarations in [`src/scene/anatomy.zig`](../../src/scene/anatomy.zig) and [`src/scene/humanoid.zig`](../../src/scene/humanoid.zig) |
| Appearance semantics and attachment points | [`src/scene/appearance.zig`](../../src/scene/appearance.zig) |
| Base character presentation | [`src/scene/character_art.zig`](../../src/scene/character_art.zig), [`src/scene/presentation_pose.zig`](../../src/scene/presentation_pose.zig), [`src/scene/presentation_view.zig`](../../src/scene/presentation_view.zig) |
| Equipment identity, slots, recipes, loadout | [`src/scene/equipment.zig`](../../src/scene/equipment.zig) |
| Wardrobe definitions and presets | [`src/scene/wardrobe_catalog.zig`](../../src/scene/wardrobe_catalog.zig) |
| Wardrobe view/art resolution and submission | [`src/scene/wardrobe_art.zig`](../../src/scene/wardrobe_art.zig), [`src/scene/wardrobe_presentation.zig`](../../src/scene/wardrobe_presentation.zig) |
| Art-pack pages/regions/semantic bindings | [`src/graphics/art_pack.zig`](../../src/graphics/art_pack.zig), character and wardrobe art definitions under [`src/scene`](../../src/scene) |
| Controller and fixed-step root physics | [`src/physics/character_controller.zig`](../../src/physics/character_controller.zig), [`src/physics/fixed_step.zig`](../../src/physics/fixed_step.zig) |
| Interaction coordination/handshake | [`src/interaction/interaction_system.zig`](../../src/interaction/interaction_system.zig), [`src/interaction/handshake.zig`](../../src/interaction/handshake.zig) |
| IK | [`src/animation/arm_ik.zig`](../../src/animation/arm_ik.zig), [`src/animation/leg_ik.zig`](../../src/animation/leg_ik.zig), [`src/animation/two_bone_ik.zig`](../../src/animation/two_bone_ik.zig) |
| Deformation and secondary motion | [`src/scene/deformation.zig`](../../src/scene/deformation.zig), [`src/animation/attachment_secondary_motion.zig`](../../src/animation/attachment_secondary_motion.zig), [`src/graphics/deformable_mesh.zig`](../../src/graphics/deformable_mesh.zig) |
| Visual-geometry metadata, traces, and audits | [`src/scene/visual_geometry.zig`](../../src/scene/visual_geometry.zig), [`src/scene/visual_geometry_audit.zig`](../../src/scene/visual_geometry_audit.zig) |
| Unified ordering | [`src/graphics/render_queue.zig`](../../src/graphics/render_queue.zig) and `sprite.OrderInput` in [`src/graphics/sprite_batch.zig`](../../src/graphics/sprite_batch.zig) |
| GPU device, resources, batching, renderer | [`src/platform/sdl.zig`](../../src/platform/sdl.zig), [`src/graphics/gpu_demo.zig`](../../src/graphics/gpu_demo.zig), [`src/graphics/sprite_batch.zig`](../../src/graphics/sprite_batch.zig), [`src/graphics/mesh_gpu_catalog.zig`](../../src/graphics/mesh_gpu_catalog.zig) |

## Authoritative boundaries

| Identity or behavior | Authority | Must not be inferred from |
|---|---|---|
| Gameplay facing | `humanoid.Facing` on the character instance | Sprite scale sign, shoe orientation, or atlas layout |
| Presentation view | `presentation_view.View` resolved from character state | Filename or texture-page choice |
| Anatomical left/right identity | Typed anatomy part instance | Final mirrored quad or screen position |
| Equipment item identity | Typed `EquipmentItemId` in the loadout | Visual component, atlas region, or garment color |
| Visual fragment identity | Currently typed `ItemVisualRecipeId` + component; future stable authored fragment ID is documented | Draw order or source rectangle |
| Atlas-region identity | Typed art-pack region ID selected through semantic/view binding | Logical item ID |
| Physics/collision | Physics body, collider, collision world, and support surfaces | Opaque sprite bounds or garment-fit contour |
| Visual fit geometry | Semantic landmarks, axes, alpha-visible bounds, fit/coverage contracts | Physics collider, raw quad, or atlas dimensions alone |
| Render ordering | Unified queue order tuple; wardrobe resolves its declared visual layer into that tuple | Submission timing or a second clothing renderer |
| Interaction ownership | Interaction system and handshake state | Animation clip coincidence or full-body teleport |

Changing facing or view changes resolved presentation transforms. It does not change equipment identity, anatomy identity, decode images, create GPU resources, reset the loadout, or create a new renderer.

## Gameplay geometry versus visual-authoring geometry

These geometries are related but not interchangeable.

### Gameplay geometry

- physics collider;
- collision bounds;
- static support and grounding surfaces;
- interaction eligibility, reach, and target geometry.

Gameplay geometry answers whether the character can move, stand, collide, or interact.

### Visual-authoring geometry

- visible torso and hip contours;
- neck base and collar region;
- clavicle line;
- left/right shoulder slope, seam, root, and armhole;
- garment waist and hem;
- limb visual extents;
- semantic attachment landmarks and directional axes;
- alpha-visible bounds and coverage zones.

Visual-authoring geometry answers whether visible art fits, layers, or articulates correctly. A rectangular torso collider, raw sprite rectangle, opaque bounds, or atlas dimensions may contribute evidence, but none is sufficient as a garment-fitting contour.

## Current ordering model

Every anatomy, equipment sprite, and deformable mesh is submitted to the same bounded [`UnifiedRenderQueue`](../../src/graphics/render_queue.zig). The queue sorts the resolved order tuple and preserves batching. Current wardrobe content declares named visual layers which resolve to numeric `body_part_layer` values. Those values are stable for the accepted content, but semantic depth relationships such as `behind_neck` remain a documented schema gap; see [AUTHORING_CONTRACTS.md](AUTHORING_CONTRACTS.md).

## Anticipated Prompt 26 world path

The following is a planned boundary, not an implemented Prompt 25E feature:

```text
World / Collision Definition
+ Environment Theme
        |
        v
Layered World Presentation
        |
        v
Unified Render Queue
```

Collision remains authoritative gameplay data. A future environment theme will resolve presentation from that data without becoming collision authority or creating a second renderer.
