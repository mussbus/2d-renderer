# Transform, Skeleton, and Humanoid Contract

## Singular math convention

The deterministic CPU world uses an arbitrary character-root origin, positive X right, positive Y up, counter-clockwise positive rotation, radians, and translation distances in metres. `Vec2` values are mathematical column vectors. `Mat3` stores nine `f32` coefficients column-major and applies `result = matrix * column_vector`.

`Transform2D` is authoritative component state: translation, rotation in radians, and nonuniform scale. Its affine value is `translation * rotation * scale`, so scale acts first. `composeParentChild(parent_to_world, child_local)` returns `parent_to_world * child_local.localToParent()`. Matrix elements are never interpolated; translation and scale use linear interpolation and rotation uses the signed shortest angular path.

Render-attachment pivot is expressed in unit-quad coordinates and is sent once to `SpriteBatch`. Bone transforms have no separate pivot, preventing double pivot application. Zero and negative scale remain finite supported math values. The current humanoid uses positive unit bone scales. Future facing mirroring must use one deliberate negative-X character or pose scale and preserve this same composition convention; it must not reorder attachment sprites independently.

## Immutable definition and mutable pose

`SkeletonDefinition` owns three contiguous allocations: 16 stable bone records, a 16-entry topological evaluation order, and four socket records. Bone records contain an inline fixed-capacity debug name, parent index/root marker, rest-local `Transform2D`, and fixed `BoneSemantic`. They contain no current pose, world pose, character transform, allocator, pointer link, or GPU state.

Validation accepts authored bones in any order. It first validates indexes, root count, names, semantics, and finite transforms, then uses a bounded iterative resolved-state pass to produce parent-before-child evaluation order. Lack of progress identifies a cycle without recursion. Exactly one root and every required humanoid bone and socket semantic are mandatory. The supported bounds are 64 bones and 16 sockets.

Each `Pose` owns one contiguous local-transform array and one contiguous world-matrix array. A pose stores the stable allocation token and expected length of its compatible definition, but not pointers to individual bones. Evaluation requires the compatible definition as an argument. It validates every local value before writing world results, applies the character transform to the root exactly once, and follows the precomputed order allocation-free.

## Humanoid hierarchy and proportions

The definition has 16 bones: root, pelvis, torso, head, bilateral upper arm/forearm/hand chains, and bilateral thigh/shin/foot chains. It has four sockets attached to the terminal hand and foot bones. The root has no sprite; the other 15 bones have one immutable render attachment.

Body sizes are authored in metres:

| Part | Length or height | Thickness or width | Pivot |
| --- | ---: | ---: | --- |
| Pelvis | 0.72 wide | 0.42 high | center |
| Torso | 1.16 high | 0.86 wide | center |
| Head | 0.66 | 0.66 | center |
| Upper arm | 0.65 | 0.18 | shoulder |
| Forearm | 0.55 | 0.15 | elbow |
| Hand | 0.25 | 0.20 | wrist |
| Thigh | 0.90 | 0.22 | hip |
| Shin | 0.85 | 0.18 | knee |
| Foot | 0.35 | 0.18 | ankle |

The left chain samples the procedural red region and uses back-limb layers. The right chain samples green and uses front-limb layers. Pelvis, torso, and head sample blue/yellow regions. Explicit body-part layers are left leg 10–12, left arm 20–22, pelvis/torso 30–31, head 40, right leg 50–52, and right arm 60–62. Hierarchy order never determines visual front/back order.

## Attachment submission

Each attachment stores only parent index, local transform, sprite size, pivot, UV rectangle, straight-alpha tint, texture page, body-part layer, stable semantic, and inline debug name. Per frame, CPU code computes `bone_world * attachment_local`, extracts presentation position/rotation/scale, and submits it through the existing `SpriteBatch`. All 15 attachments use texture page 0 and therefore form one range and one `SDL_DrawGPUIndexedPrimitives` command. Pose changes create no GPU resources and do not change the pinned shader or pipeline.

## Deterministic demonstration

Run:

```powershell
zig build run -- --frames 300 --demo humanoid
```

Frames 0–74 use rest pose. Frames 75–149 rotate the right upper arm and forearm. Frames 150–224 additionally rotate the left thigh and shin. Frames 225 onward additionally translate and rotate the character root. The program logs right shoulder, elbow, hand socket, left knee, and foot socket positions at frames 0, 100, 200, and 299.

The demo definition, attachments, and pose use a 64 KiB fixed allocator during initialization. Its exact used byte count is recorded before the frame loop. Pose evaluation, socket queries, and attachment submission each compare that allocator position before and after their operations, providing separate runtime zero-allocation evidence. Pure tests repeat the proof and exercise two independent poses sharing one immutable definition.
