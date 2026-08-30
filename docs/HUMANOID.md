# Transform, Skeleton, and Humanoid Contract

## Singular math convention

The deterministic CPU world uses an arbitrary character-root origin, positive X right, positive Y up, counter-clockwise positive rotation, radians, and translation distances in metres. `Vec2` values are mathematical column vectors. `Mat3` stores nine `f32` coefficients column-major and applies `result = matrix * column_vector`.

`Transform2D` is authoritative component state: translation, rotation in radians, and nonuniform scale. Its affine value is `translation * rotation * scale`, so scale acts first. `composeParentChild(parent_to_world, child_local)` returns `parent_to_world * child_local.localToParent()`. Matrix elements are never interpolated; translation and scale use linear interpolation and rotation uses the signed shortest angular path.

Render-attachment pivot is expressed in unit-quad coordinates and is sent once to `SpriteBatch`. Bone transforms have no separate pivot, preventing double pivot application. Zero and negative scale remain finite supported math values. Authored bones use positive unit scales. Prompt 7 left facing applies one deliberate negative-X character-root scale and preserves this composition convention; it does not swap anatomical bones or mirror sockets a second time.

## Canonical rig definition and mutable pose

`SkeletonDefinition` owns three contiguous allocations: 16 stable bone records, a 16-entry topological evaluation order, and four socket records. Bone records contain an inline fixed-capacity debug name, parent index/root marker, rest-local `Transform2D`, and fixed `BoneSemantic`. They contain no current pose, world pose, character transform, allocator, pointer link, or GPU state.

Validation accepts authored bones in any order. It first validates indexes, root count, names, semantics, and finite transforms, then uses a bounded iterative resolved-state pass to produce parent-before-child evaluation order. Lack of progress identifies a cycle without recursion. Exactly one root and every required humanoid bone and socket semantic are mandatory. The supported bounds are 64 bones and 16 sockets.

Each `Pose` owns one contiguous local-transform array and one contiguous world-matrix array. A pose stores the stable allocation token and expected length of its compatible definition, but not pointers to individual bones. Evaluation requires the compatible definition as an argument. It validates every local value before writing world results, applies the character transform to the root exactly once, and follows the precomputed order allocation-free.

## Humanoid hierarchy and proportions

The canonical definition has 16 bones: root, pelvis, torso, head, bilateral upper arm/forearm/hand chains, and bilateral thigh/shin/foot chains. It has four semantic sockets attached to the terminal hand and foot bones. This topology, its lengths, its animation tracks, and its semantic lookup tables remain authoritative for locomotion, arm IK, foot planting, controller integration, interaction geometry, and handshake behavior.

The default legacy appearance still supplies 15 body-piece visuals and gives the root no visual. That is a default data set, not a cardinality rule and not a one-bone/one-visual invariant. A valid definition may contain zero through 128 visuals, several visuals may use the same canonical bone or attachment point, and arbitrary visuals do not add members to `AttachmentSemantic`.

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

Those immutable layer values are the right-facing authored defaults. Runtime order resolution uses the same centralized role values and maps anatomical right limbs to back roles and anatomical left limbs to front roles when facing left. Attachment definitions remain unchanged.

## Visual definitions, attachment points, and registries

`appearance.Definition` is immutable initialization data adjacent to, but distinct from, `SkeletonDefinition`. It owns contiguous arrays for attachment points, body regions, visual groups, optional rig modules, flattened module joints and sockets, visual attachments, and their bounded parent-before-child evaluation orders. Names are copied into inline `DebugName` storage and resolved only during initialization. Input order assigns compact typed `u16` IDs for attachment points, visuals, regions, groups, modules, and module-local members. Per-frame string or hash lookup is not part of evaluation or submission.

The conventional humanoid provides data-defined `head_scalp`, `face`, `neck`, `upper_back`, `chest`, `waist_pelvis`, left/right shoulder, left/right wrist, left/right hand, left/right ankle, and left/right foot attachment points. These names are conveniences in the default definition, not a closed enum. An attachment point has a stable ID, a canonical-bone or attachment-point parent, a finite local transform, and a validated hierarchy depth. Definitions reject empty or duplicate IDs, dangling parents, cycles, and depth beyond 16.

Body regions and visual groups are independent many-to-many classification concepts. A visual names one body region and one group, but multiple visuals may share either ID. The default regions group the pelvis, torso, head, anatomical arms/hands, and anatomical legs/feet; clothing coverage, deformation, wetness, material, damage, and armor consumers may use the IDs without assuming a region maps to one sprite. Prompt 17 equipment uses region IDs as metadata while leaving visibility and geometry authoritative.

A visual attachment contains a stable ID, optional canonical semantic, transform source, finite local transform, region/group IDs, hierarchy depth, draw layer, and sprite metadata. Its transform source may be a canonical bone, data-defined attachment point, module joint, module socket, or another visual. Visual-parent edges are resolved to IDs and topologically ordered at initialization. The optional canonical semantic is only the fast primary lookup used by existing diagnostics and hand/forearm interaction overrides; extra visuals leave it null.

## Optional rig modules

A rig module attaches to one validated attachment-point ID and has its own finite module-local transform. It may contain zero through 16 local joints and zero through 16 named local sockets; a complete definition supports at most eight modules, 128 flattened module joints, and 128 flattened module sockets. Joint parents are module-local stable IDs, roots use the module origin, and sockets may use the module origin or a local joint. Duplicate names, dangling members, self-parenting, and joint cycles fail initialization transactionally.

Module joints do not enter `BoneSemantic`, canonical clips, locomotion sampling, ordinary arm/leg IK, controller state, or interaction geometry. Their rest transforms are immutable definition data. A future anatomy system may explicitly drive the character-owned local module pose without replacing the canonical humanoid skeleton.

## Mutable appearance runtime

Every `HumanoidCharacter` owns an `appearance.Runtime` compatible with its borrowed immutable definition. It contains contiguous attachment-point world matrices, module-local joint transforms, module joint/socket world matrices, per-visual visibility and local deformation state, and final visual world matrices. Two characters sharing one definition never share these arrays. Reset restores module joints to immutable rest transforms, makes every visual visible, clears local deformation, and rebuilds derived matrices from the current canonical pose.

Initialization allocates every runtime array. Evaluation, visibility changes, local deformation, module-pose changes, reset, and submission perform no steady-state allocation. The single character-root `S(-1,+1)` facing reflection reaches attachment points, module chains, module sockets, visual parents, and final sprites through normal matrix composition; no anatomical semantic is swapped.

## Attachment submission

After canonical pose evaluation, the CPU evaluates attachment points, module-local joints and sockets, then visuals in their precomputed orders. Submission skips character-local hidden visuals, extracts world position/rotation/signed scale in metres from the already-owned runtime matrix, and submits each visible visual through the existing `SpriteBatch`. Camera and viewport conversion occur later at the GPU vertex boundary. The default 15 visuals still use texture page 0 and therefore form one range and one `SDL_DrawGPUIndexedPrimitives` command. Additional compatible visuals join that same global batch; appearance changes create no GPU resources and do not change the pinned shader or pipelines.

Prompt 17 optionally embeds a fixed-capacity equipment loadout in `CharacterInstance`. Reset restores anatomy before atomically restoring the default loadout. Equipment visuals are appended by the generic `submitAttachments` consumer after base appearance evaluation; both base and equipment records enter the same globally sorted sprite batch, so call order is not draw-order authority. Equipment sources current anatomy-part or attachment-point matrices and therefore inherits canonical animation, procedural motion, IK, foot planting, world translation, actor ordering, and facing reflection without owning any of them.

The canonical semantic key table remains limited to the original 15 primary body visuals. Equipment visuals use item/recipe IDs and do not enter handshake override ownership. This preserves existing explicit hand/forearm layer control and keeps equipment from masquerading as canonical anatomy. Complete equipment contracts are in `docs/EQUIPMENT.md`.

## Deterministic demonstration

F4B2 retired the standalone humanoid route after its continuing invariants
were mapped to `tests/skeleton_tests.zig`, which runs through `zig build test`.

The retired route historically staged rest pose, arm/leg edits, and root
movement. Those hierarchy and socket relationships are now asserted directly
without retaining the visual timeline shell.

The demo definition, appearance runtime, and pose use a fixed allocator during initialization. Its exact used byte count is recorded before the frame loop. Pose evaluation, attachment-point/module/visual evaluation, socket queries, and attachment submission compare allocator position before and after their operations, providing separate runtime zero-allocation evidence. Pure tests repeat the proof, including zero and extended visual counts, two independent runtimes sharing one immutable definition, module-local pose/reset, hierarchy rejection, mirroring, and deterministic ordering.

Prompt 16 retains this canonical rig and adds optional character-owned modular anatomy above Prompt 15's attachment/module layer. Adult anatomy, repeated parts, faces, hair, morphology, presentation profiles, conventional presets, and the alternative-rig boundary are specified in `docs/ANATOMY.md`. None of those systems adds a canonical bone semantic or changes ordinary arm/leg IK geometry.
