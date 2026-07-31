# Architecture

## Scope and invariants

This design separates a deterministic CPU simulation from an SDL3 GPU renderer. The simulation can run in tests without SDL initialization, a window, or a GPU device. The renderer consumes immutable render snapshots and never owns gameplay state.

The application is a character controller and animation system, not a ragdoll simulator. Each character has a controlled physics root, an authored skeletal pose, procedural inverse kinematics, and bounded secondary-motion springs. This keeps movement responsive and animation-directed while still providing gravity, platform collision, landing compression, step bounce, and spring-like follow-through. A full rigid-body ragdoll would add joint constraints, contact manifolds, solver instability, and a different ownership model without serving the required demonstration.

## Coordinate system and units

- Simulation and authored animation use a right-handed 2D world: positive X points right, positive Y points up, and positive rotation is counter-clockwise.
- Physics distances are metres, time is seconds, velocity is metres per second, acceleration is metres per second squared, and angles are radians.
- Sprite dimensions and bone offsets are authored in metres. Pixels are presentation units only; the camera supplies pixels-per-metre.
- SDL GPU viewport coordinates have their origin at the top-left with positive Y down. The camera projection performs the one required Y inversion when mapping world coordinates to clip space. Physics, animation, IK, and scene code never adopt screen-space Y.
- Texture coordinates follow SDL GPU convention: `(0, 0)` is the top-left and positive V points down.

## Vectors, matrices, and transforms

`Vec2` values are mathematical column vectors. `Mat3` represents an affine 2D transform in homogeneous coordinates and is stored column-major. Code applies transforms as `p_result = M * p_source`.

The stored columns are the transformed local X basis, transformed local Y basis, and affine translation. Points use homogeneous `w = 1`; directions use `w = 0`, so translation never affects a direction. The arbitrary character root is the authored world origin. Character, bone, collider, debug, and sprite submissions remain in metres; only the GPU camera boundary converts those values to clip space.

A local transform is composed as:

```text
local = translation * rotation * scale
```

This means scale is applied first, then rotation, then translation. A child-to-world transform is:

```text
child_world = parent_world * child_local
```

Function names bind operand direction: `Transform2D.localToParent`, `composeParentChild(parent_to_world, child_local)`, and `Pose.evaluateWorld`. Attachment pivot belongs only to the sprite attachment in unit-quad coordinates. Bones have no pivot field, and CPU hierarchy evaluation never applies the sprite pivot.

Angles wrap to `[-pi, pi)`. Interpolation is component-wise: translation and nonuniform scale are linear, while rotation follows the signed shortest arc. Matrix coefficients are never interpolated. Zero and negative finite scale are supported math values. The current humanoid uses positive bone scale; future facing mirroring must deliberately use negative X scale in the character/pose transform without changing multiplication order or independently relocating attachments.

The root transform combines only physics root position and facing. Animation and secondary visual offsets remain in the pose hierarchy; they never rewrite the physics root. CPU/GPU layout tests will validate any matrix or packed-instance representation passed to HLSL. HLSL uses `mul(matrix, column_vector)` for the same convention.

## Camera, viewport, and parallax ownership

`src/graphics/camera2d.zig` owns presentation state: a finite world-space center, nonzero drawable-pixel width and height, and a positive pixels-per-metre scale. It imports only the renderer-independent math module. `worldToPresentation`, `presentationToWorld`, `worldToClip`, visible half-extents, the 16-byte GPU uniform, and deterministic horizontal following are therefore testable without SDL, a window, or a GPU.

The immutable reference presentation is 640×480 at 82 pixels per metre with
center `(0, 135 / 82) m`. It maps world origin to the established `(320, 105)`
presentation point and fixes the vertical world span at `480 / 82`, or
approximately `5.85365854 m`. Every valid viewport update atomically derives
the effective scale from drawable height:

```text
pixels_per_metre = 82 * drawable_height / 480
```

This derivation always starts from the reference values; it never compounds
from the previous resize. X and Y share that one scale. Resolution changes at
one aspect ratio therefore preserve both world extents while increasing pixel
detail, and aspect-ratio changes alter only horizontal visibility. Manual zoom
remains deferred. This policy supersedes Prompt 14's fixed-pixel-density
resize behavior; its fixed 640×480 capture composition remains identical.
The Prompt 27B 16-pixel top/bottom safe-region margins are likewise reference
composition values: they are converted through 82 px/m to constant world
margins, then rendered at the effective scale. This prevents a resolution
change by itself from moving the camera center while leaving the 640×480 ruler
exactly unchanged.

Visible windows are created with `SDL_WINDOW_RESIZABLE`. SDL window-resize, drawable-pixel-size, minimize, and restore events refresh `SDL_GetWindowSizeInPixels`; the dimensions returned by `SDL_WaitAndAcquireGPUSwapchainTexture` are the final per-frame authority. A zero or absent swapchain texture skips drawing without changing the last valid camera. Restoration applies the new nonzero pixel extent. Resize handling updates scalar camera state only and does not recreate shaders, textures, buffers, samplers, or pipelines.

Horizontal camera following is a deterministic dead zone evaluated from the already-authoritative character position after simulation. It writes only `Camera2D.center.x`. Camera movement never writes controller position, velocity, collision, animation clocks, foot state, or interaction eligibility.

Each sprite instance carries one validated horizontal camera-response factor. Gameplay geometry and characters use `1.0`, the cave midground uses `0.45`, and the distant cave layer uses `0.125`. The vertex shader subtracts `camera_center.x * factor` while applying full vertical camera displacement. Parallax is presentation metadata in the global sprite batch; it is absent from character control and collision.

## Fixed simulation and render interpolation

Simulation advances at exactly 240 Hz (`dt = 1 / 240` seconds). One `f64` accumulator receives validated real elapsed time, performs whole fixed ticks, then renders an interpolation between the previous and current completed simulation snapshots. Controller integration uses the validated `f32` form of the same constant. Interpolation never feeds back into simulation and never advances the animator.

Real frame delta is rejected when non-finite, sanitized to zero when negative, and clamped to `0.10 s`. At most eight simulation ticks may be processed for one displayed frame. Whole ticks beyond that budget are discarded explicitly and reported as both per-frame and lifetime discarded seconds; only the fractional accumulator remainder is retained. The loop never performs unbounded catch-up or claims discarded time was simulated. Pause accumulates no real time; a pending single-step executes exactly one physics/animation tick. Tests drive explicit elapsed values and do not read wall-clock time.

Simulation order within one tick is fixed:

1. Convert the current platform snapshot through pending edges and produce `CharacterIntent`.
2. Resolve the character's bounded gameplay properties from current stable sources, then advance controller velocity, gravity, jump/double-jump/dash policy, horizontal/vertical static collision, and grounded/support classification; emit physical action and landing results.
3. When not interaction-locked, select animation from authoritative physics and advance the animator exactly once by `1 / 240` second.
4. Update walk weight transfer, consume a physical landing event once, advance procedural springs, compose local visual offsets, and evaluate the pre-leg hierarchy.
5. Freeze both feet's pre-IK sole/hip inputs, query the authoritative collision world, update plant state, apply both analytical leg constraints, and leave the hierarchy evaluated.
6. Process an interaction edge after the ordinary locomotion state is current.
7. For each active interaction, advance its one shared tick counter, sample both role poses, compose procedural motion, and evaluate both pre-arm hierarchies.
8. Freeze both pre-IK hands, compute one shared midpoint, apply both analytical arm constraints, then reapply only already-owned foot constraints. Arm and leg chains are disjoint; no new foot lock is acquired in this interaction branch.
9. Resolve final visual anchors, advance bounded per-visual attachment secondary state, and compose it after morphology/breathing without feeding any result back into authority.
10. Observe lifecycle milestones and copy optional diagnostics after authoritative updates.
11. Preserve previous/current physics transforms for render interpolation. On the render frame, globally submit all attachments and optional debug primitives, sort/build ranges, and issue the SDL GPU draw.

## Input and character intent

SDL keyboard and gamepad code owns device discovery, hot-plugging, dead zones, and raw button state. It produces one renderer-independent frame snapshot whose buttons distinguish pressed, held, and released state. A pending-edge layer retains jump press/release, dash press, and interaction press through zero-tick rendered frames, consumes each edge on the first following simulation tick, and preserves held state for every applicable tick. It then produces `CharacterIntent` containing normalized horizontal movement and jump/dash/interaction semantics; reset and debug/time controls remain frame controls. Character, animation, physics, and interaction systems never query SDL directly. Tests construct snapshots and intents without platform input. `docs/CONTROLS.md` binds the exact key, gamepad, merge, and dead-zone policies.

## Skeleton and pose ownership

A canonical humanoid `Skeleton` is immutable after initialization. It owns the bone hierarchy, bind-local transforms, four locomotion/interaction sockets, and semantic bone/socket indices. It does not own arbitrary rendered geometry or optional anatomy-module articulation. Animation clips refer to canonical bones by validated indices; names are used for loading and diagnostics, not per-tick lookup.

Prompt 3 implements this as `SkeletonDefinition`: one contiguous bone array, one contiguous socket array, one parent-before-child evaluation-order array, and fixed semantic-to-index tables. Bone and socket names use inline bounded storage, so no record owns an individual heap allocation. Authored input order is unrestricted. Validation uses a bounded iterative resolved-state pass; a pass with no progress identifies a cycle without recursion. Exactly one root, all 16 humanoid bone semantics, and all four hand/foot socket semantics are required.

Each `Character` owns its controller state, resolved gameplay-property set, animator state, current local pose, previous pose snapshot, secondary springs, arm IK workspace, immutable-index leg bindings, independent left/right plant state, and appearance/module runtime. The demo characters may share immutable skeleton, clip, property, attachment-point, visual, region, group, and rig-module definitions, but never share mutable resolved properties, pose arrays, foot locks, module-local pose, visibility, deformation, overrides, or derived visual matrices. All arrays are allocated or fixed-capacity during initialization. The steady-state loop performs no heap allocation.

The current canonical `Pose` owns separate contiguous local `Transform2D` and world `Mat3` arrays. It is compatible only with the definition allocation token and bone count captured at initialization; every evaluation receives the still-live definition explicitly. Definitions never cache current local or world pose. Visual attachments are immutable local metadata and never store authoritative world transforms. `docs/HUMANOID.md` records the concrete hierarchy, proportions, layer values, appearance model, and runtime allocation proof.

World bone transforms are rebuilt parent-before-child from the physics root plus the local visual pose. Socket positions are calculated from those world transforms. A handshake alignment claim is valid only when the measured distance between the two selected hand sockets is within the documented tolerance.

## Character visual definitions and optional rig modules

`appearance.Definition` separates rendered visuals from canonical skeleton semantics. It stores bounded contiguous registries for data-defined attachment points, body regions, visual groups, optional rig modules, module-local joints/sockets, and variable-count visual attachments. Initialization copies bounded names, rejects duplicate IDs and dangling references, resolves names to compact typed `u16` IDs, and precomputes attachment-point, module-joint, and visual evaluation orders. Runtime evaluation uses only IDs and arrays; it performs no string or hash lookup.

The conventional humanoid publishes scalp/head, face, neck, upper-back, chest, waist/pelvis, bilateral shoulder/wrist/hand, and bilateral ankle/foot attachment points. A definition may add other points without changing central enums. Attachment-point and visual-parent hierarchies have a maximum depth of 16 and reject cycles. A visual may source its transform from a canonical bone, attachment point, module joint, module socket, or another visual. Zero visuals and multiple visuals sharing one transform source are valid.

The fixed 15-member `AttachmentSemantic` table remains only the fast optional primary-visual lookup needed by existing interaction layering, diagnostics, and tests. It is not a registry for hair, faces, clothing, armor, equipment, or unusual anatomy. Arbitrary visuals receive stable definition-local IDs and an optional semantic is absent. Body-region and visual-group IDs are also data-defined; neither implies one visual per region or group.

Prompt 16 adds an immutable modular-anatomy catalog beside the appearance definition. Reusable part definitions use extensible inline tags; repeated part instances attach to canonical points, other part sockets, or module sockets. Body presets select bounded active-instance sets rather than a sex/gender topology boolean. Faces and hair are grouped per head, and presentation variants select existing visuals without changing the active topology. Full ownership, morphology math, validation, and limitations are documented in `docs/ANATOMY.md`.

Each character owns its anatomy runtime next to its canonical pose and appearance runtime. Morphology and presentation are applied before appearance evaluation; the anatomy part/socket world hierarchy is evaluated afterward as bounded derived state. These operations cannot write canonical bones, controller roots, colliders, animation clocks, interaction state, or standard IK lengths and cannot create GPU resources.

## Equipment definitions, loadouts, and consumers

Prompt 17 adds the next declarative layer without merging existing concepts. Equipment slots are exclusive logical loadout claims; attachment points and anatomy instances are transform sources; body regions are coverage metadata; visual layers are ordering metadata; attributes and capabilities are gameplay declarations. All have separate typed IDs. `docs/EQUIPMENT.md` binds the full validation, ownership, transaction, capacity, and demonstration contracts.

An immutable `equipment.Definition` is initialized against the immutable anatomy and appearance definition tokens. Initialization resolves all names to compact IDs and validates every reference and bound. A character-owned `equipment.Loadout` then expands equipped item recipes against that character's active anatomy into fixed-capacity visual bindings. Definitions may be shared; equipped items, slot occupancy, resolved visuals, coverage, modifiers, and grants may not.

Prompt 19 generalizes `VisualComponent` without adding another character or item architecture. A component is either the established rigid sprite or a validated immutable deformable mesh. Both retain owning character, resolved anatomy/attachment binding, semantic visual layer, material/texture reference, and deterministic definition identity. Repeated mesh recipes share immutable topology but each resolved record owns its mutable binding/deformation state. `docs/MESH_ATTACHMENTS.md` binds the mesh validation, queue, GPU ownership, capacity, and evidence contracts.

Prompt 20 lets an immutable appearance visual or equipment component opt into one bounded attachment-secondary definition. Mutable point springs are embedded in each character-owned `VisualRuntimeState` or `ResolvedVisualInstance`; neither a visual/component ID nor any hair, equipment, anatomy, or mesh definition owns mutable nodes. The fixed resolved anchor follows final animation/procedural/IK/anatomy motion, while the output is local visual deformation only. Unequip clears removed state, re-equip starts at rest, and a facing change clears the affected state before the existing single root reflection is applied. `docs/ATTACHMENT_SECONDARY_MOTION.md` binds the equations, capacity, lifecycle, composition, and evidence contracts.

The mutation flow is copy candidate, validate all occupied slots and required anatomy, expand every recipe within authored and global bounds, rebuild deterministic coverage/effect views, then commit the entire bounded value. Failure changes nothing. No loadout mutation or query allocates or performs string lookup.

Equipment rendering is a consumer in generalized character visual submission. A resolved record selects the current character-owned anatomy-part or attachment-point matrix and applies immutable recipe-local data. Sprite-only scenes enter the existing `SpriteBatch`; mixed scenes enter `UnifiedRenderQueue`, which uses the same scene/interaction/actor/visual key for both primitive kinds. The equipment system imports no renderer, SDL, controller, physics, animation, IK, or interaction module. The renderer receives primitive, material, transform/deformation, and order data only and never sees armor values or capabilities.

Prompt 21 resolves equipment gameplay declarations through the generic bounded `character_properties` layer. Typed definitions provide explicit finite base/range metadata. Stable source-keyed additive and multiplicative records resolve as `clamp((base + additions) * multiplier_product)` after a deterministic sort. Capabilities are source counts, not equip-time Boolean toggles. Each character owns its resolved set and recomputes it transactionally with loadout changes. The controller receives only resolved movement speed, jump strength, double-jump availability, and dash availability; it never sees item names or visual definitions. Carrying capacity, armor, and physical damage reduction remain resolved/queryable for future consumers. Appearance, morphology, camera, renderer, and GPU state are absent from resolution. `docs/CHARACTER_PROPERTIES.md` binds the full stacking, source, controller, reset, and evidence contracts.

## Prompt 22 integrated foundation boundary

`foundation_playground.Scene` is an acceptance composition root, not a new engine subsystem. It instantiates the existing modular humanoid definition, authored animation library, static collision world, controlled `CharacterInstance`, passive characters, interaction manager, camera/follower, equipment resolver, deformable-mesh definitions, and unified render queue. Fixed ticks still execute the established order: consume `CharacterIntent`, resolve equipment-backed gameplay properties, advance the controller/collision state, select canonical animation, apply procedural motion and foot planting, advance breathing and resolved-instance secondary motion, update interaction/arm IK, and finally derive visual submissions. Camera and rendering remain downstream observers.

The final definition flow is:

```text
Character/Anatomy Definitions + Equipment Definitions
                         |
              Loadout + Topology Resolution
                         |
          +--------------+----------------+
          |                               |
Resolved Visual Instances       Resolved Gameplay Effects
          |                               |
Appearance Deformation          Attributes / Capabilities
          |                               |
Sprite + Mesh Rendering         Gameplay Consumers
```

The branches share stable item definitions and loadout identity only. The visual branch owns anatomy bindings, coverage, layers, mesh instance state, and bounded secondary nodes. The gameplay branch owns numeric values and capability source counts. The renderer cannot grant a capability, and controller consumers cannot select a sprite, mesh, layer, topology match, or deformation response.

The integrated route uses canonical roots and the existing right-arm/hand socket for handshake IK. Morphology, clothing, equipment properties, and secondary motion do not rewrite participant roots or the authored `3.72 m` eligibility geometry. The nonstandard showcase retains the canonical skeleton but is not inserted into the two-participant interaction candidate set; arbitrary noncanonical interaction binding remains outside this milestone rather than being approximated.

Viewport changes update only the camera's presentation dimensions and the
height-derived pixels-per-metre scale. The scene compares controller,
interaction, animation, appearance selection, loadout fingerprint, capability
state, character transform, and pending-edge count before and after synthetic
resizes. The SDL event path re-queries `SDL_GetWindowSizeInPixels`; the render
path also consumes the width and height returned with the acquired swapchain
texture. Those drawable dimensions update `GpuDemo`'s single stored viewport
authority. Production foundation/environment scenes synchronize from that
authority before later per-frame camera publication, and acquired dimensions
are reapplied before GPU encoding. A zero or minimized drawable marks
presentation unavailable and preserves the last valid camera; no scale or
projection is calculated until a later positive drawable size arrives.
Neither route reinitializes characters or GPU resources.

Reset has one owner, `Scene.resetWorld`. It clears the manager, controller velocity/jump/dash state, animation and procedural state, foot locks, IK/overrides, breathing phase, appearance selection and overrides, resolved-instance secondary/mesh state, pending edges, fixed-step clock, and camera center. It then reapplies the authored initial body/build/hair configuration and atomically restores the equipment definition's default loadout and resolved properties. Viewport dimensions remain the current window dimensions; camera tracking restarts from the authored center.

Future tools may author current validated definition inputs without changing runtime ownership:

- A character/body editor could author anatomy modules, attachments, faces, hair, equipment, visual recipes, layers, and property grants.
- A level editor could author static world geometry and object definitions.
- A mission editor could author trigger regions and objective/event relationships.

No editor runtime, serialization dependency, mission/objective system, trigger scripting, combat, inventory economy, or level mutation is introduced by Prompt 22.

Prompt 18 inserts a shared resolved deformation stage between instance binding and visual submission. Each anatomy runtime retains both an undeformed binding matrix and a fully deformed descendant matrix. Skin and anatomy-bound equipment call the same resolver with immutable morphology/breathing bindings, character-local base morph and tick-derived breathing state, exact anatomy-instance identity, and per-visual response strengths. Rigid visuals can attenuate or opt out. `docs/DEFORMATION.md` binds the clock, composition order, invariants, and evidence.

An optional rig module attaches to a validated attachment point and contributes at most 16 local joints plus 16 local sockets. Module joint parents and sockets are resolved and cycle-checked during initialization, then flattened into bounded contiguous arrays. Module joints are not automatically sampled by canonical clips or consumed by locomotion, standard arm IK, foot planting, controllers, or interactions. Integration with any future anatomy-specific driver must be explicit.

`appearance.Runtime` is character-owned mutable state: attachment-point world matrices, module local pose and derived joint/socket matrices, visual visibility, local deformation, optional per-visual attachment-secondary state, resolved secondary anchors, and derived visual matrices. Reset copies immutable module rest transforms and clears character-local appearance changes and motion nodes. Evaluation order is canonical pose, attachment points, module joints/sockets, base visuals, then bounded secondary composition. Facing remains one canonical character-root reflection inherited by every downstream transform.

## Animation sampling

Clips are CPU-side data made of per-bone translation, rotation, and scale tracks plus timestamped events. Sampling uses binary search or a monotonic cursor chosen during implementation, linear interpolation for translation and scale, and shortest-arc interpolation for angles. Missing tracks use the skeleton bind value.

Prompt 4 implements bounded binary-search sampling over immutable contiguous clip arrays. Step, linear, and smoothstep segments are explicit; smooth uses `t^2 * (3 - 2t)`. Values hold before the first and after the final key. The event interval is `(previous, current]`; time-zero records fire on state entry and loop wrap, while exact-duration records fire in the ending cycle. One update may traverse at most eight loop boundaries and writes to a per-animator preallocated event buffer.

The state machine owns idle, walk, jump, fall, land, and handshake transitions. Cross-fades sample both source and destination poses and blend into a separate output pose; they do not mutate clip data. Looping event scans use half-open time intervals so an event at a loop boundary fires exactly once. Locomotion clips provide visual motion only. Physics decides whether the root rises, falls, lands, and collides.

The current bounded machine has eight required states. Idle-to-walk and walk-to-idle advance both source and destination during a 0.30-second local-component blend. Requests during an active transition are rejected; a same-state request is a no-op. A one-shot exposes its final pose and events before fallback starts on the next update. `docs/ANIMATION.md` binds exact sampling boundaries, event ownership, fallback durations, and authored timelines.

Walk includes an authored vertical pelvis/body component. Prompt 6 layers a contact-relative, speed-scaled visual-root curve without integrating an offset, so complete cycles cannot accumulate drift. Landing adds a bounded compression spring driven by the pre-resolution physical impact speed. Head rotational lag derives from horizontal acceleration and runs through the same reusable fixed-step spring primitive. The complete constants, equations, floor guard, reset policy, and composition order are bound in `docs/SECONDARY_MOTION.md`.

## Physics

The physics body is one stable axis-aligned character-controller box anchored at the root, not one rigid body per bone. The collision world owns one contiguous immutable array containing floor, wall, ceiling/overhang, and two raised platforms with stable IDs. Movement uses axis-separated continuous sweeps, horizontal before vertical, followed by ground classification. Only a downward vertical support hit produces normal `(0, +1)`, grounded state, and a supporting ID; wall and ceiling hits cannot. Initial penetration is rejected, while runtime contact validation tolerates only the documented `0.0001 m` floating-point contact epsilon. `docs/PHYSICS.md` binds all configuration values, timers, collision consequences, and ownership details.

Root position and velocity are authoritative physics state. Pelvis bounce, landing compression, hand IK, and spring offsets are visual pose state. Animation cannot move the collider through a platform, and collision correction cannot erase visual secondary motion.

Prompt 10 adds visual foot placement without a second collision representation. Authored contact events create only pending anatomical intent; `CollisionWorld.queryGroundDown` validates an eligible top surface from the controller's collider array. The exact pose pipeline is authored sampling, Prompt 6 procedural composition, pre-leg hierarchy evaluation, frozen left/right query and target inputs, analytical leg solves, optional disjoint arm solve, and attachment submission. Locks are world-space character/foot-local state. No foot path writes the physics root, collider, grounding, support, velocity, landing state, animator clock, interaction clock, GPU state, or draw topology. `docs/FOOT_PLANTING.md` binds the detailed query and stance policy.

## Interaction ownership and handshake coordination

Prompt 8's `interaction.Definition` is an immutable value separate from requests and runtime instances. The fixed-position handshake definition names two explicit roles, validates their clips and matching paired events, owns the authoritative duration/event timeline, and records an inclusive spatial envelope. `interaction_system.Manager` embeds four preallocated slots. Every active slot owns one stable nonzero `u32` instance ID, both participant entity IDs, stable role assignment, start/elapsed ticks, lifecycle, phase, deduplicated event state, cancellation reason, contact measurement, and exact layer-override handles. No persistent participant pointer, singleton handshake state, or runtime allocation is used.

The manager implements shared-time sampling: both animators enter their role states transactionally on the same fixed tick, then the one instance elapsed-tick counter determines both clip sample times. Participant clip events are validation inputs only; the definition collapses matching role events into one contact/release/complete stream. Legal lifecycle transitions are `inactive -> requested -> active -> completing -> completed` and `requested|active|completing -> cancelled`; terminal instances cannot reactivate. Completion and cancellation synchronously restore owned overrides, release both locks, and choose grounded idle/walk fallback states.

Prompt 8's original manager construction remains the non-IK baseline. Prompt 9's opt-in construction adds one interaction-owned midpoint target and fixed-tick weight without approach movement, root alignment, motion warping, or collision. Both role poses are sampled and evaluated first; the manager freezes the midpoint of both pre-IK right-hand sockets before independently solving either arm. Only mutable shoulder and elbow rotations change, followed by final hierarchy evaluation. Eligibility remains grounded, allowed-state, `3.70..3.74 m`, vertically aligned within `0.02 m`, and face-to-face. Neither path writes controller position, velocity, grounding, support, or collision data. `docs/INTERACTIONS.md` and `docs/IK.md` bind the coordination and solve contracts.

## CPU/GPU responsibility boundary

CPU responsibilities:

- Platform input to `CharacterIntent` conversion.
- Fixed-step animation, physics, collision, ground queries, springs, interaction coordination, analytical arm/leg IK, foot-plant state, socket measurement, and target/slip/penetration metrics.
- Canonical skeleton traversal, attachment/module/visual traversal, and socket measurement.
- Stable transparent draw ordering and explicit limb-front overrides.
- Building a bounded array of sprite instances and debug primitives.
- Building the bounded mixed render queue and per-mesh instance records.

GPU responsibilities through the SDL3 GPU API:

- Transforming unit-quad vertices from world metres through current camera center/zoom/viewport state into clip space.
- Sampling the body-part texture atlas.
- Applying vertex colour and texture alpha.
- Alpha blending into the swapchain target.
- Drawing many sprite instances from a single indexed quad and instance buffer.
- Applying weighted local mesh deformation and world/camera transforms in the mesh vertex shader.
- Drawing repeated compatible mesh topology with indexed instancing.

No SDL high-level 2D renderer participates in this boundary.

## Transparent draw order and instancing

Each visible visual attachment produces a CPU `SpriteSubmission` with world position, rotation, nonuniform scale/size in metres, pivot, atlas UV bounds, straight-alpha tint, texture page, horizontal camera-response factor, and a lexicographic integer draw key. The key contains signed scene and interaction layers, unsigned actor and body-part layers, and a bounded `u64` submission index. Stable definition/input order preserves original submission order for equal layers without using float depth, addresses, or packed arithmetic.

The handshake session explicitly raises or lowers the participating hand and forearm keys so the selected limb is in front. This is data-driven ordering, not a shader accident. Consecutive compatible texture pages form draw ranges without reordering across page changes. Sprite-only scenes retain the current one-page, one-range straight-alpha path. The renderer uploads 64-byte sprite GPU records and calls `SDL_DrawGPUIndexedPrimitives` with six shared quad indices and `num_instances > 1`. Slot 1 is declared `SDL_GPU_VERTEXINPUTRATE_INSTANCE`.

Mixed scenes sort sprites and meshes in one semantic stream. Compatible adjacent sprites form sprite ranges; adjacent mesh records form mesh ranges and repeated equal mesh definitions become indexed-instanced draws. Persistent mesh topology is not expanded on the CPU or recreated per frame. Mesh instances also use an explicit 64-byte slot-1 record, while slot 0 reads the definition's persistent weighted vertex data. The renderer reports sprite and mesh ranges/draws separately and does not claim one draw for a mixed scene. `docs/SPRITE_BATCH.md` and `docs/MESH_ATTACHMENTS.md` bind the layouts and transform contracts.

Prompt 7 formalizes `CharacterInstance` as the mutable entity boundary. It borrows immutable skeleton, appearance, clip, event, and state-machine views while independently owning pose, animator, procedural, facing, optional controller, appearance/module runtime, and override state. Stable monotonic `u32` entity IDs establish deterministic global submission order without pointer identity. All visible attachments from both characters enter the same batch before the global semantic sort. Bounded interaction overrides can raise one canonical hand or forearm above another character without changing either actor layer or any immutable attachment. `docs/MULTI_CHARACTER.md` binds the multi-character model.

Visual left facing is one character-root reflection, `T(position) * S(-1,+1)`, applied during hierarchy evaluation. Socket semantics remain anatomical and the physics AABB is unchanged. Reflected attachments retain a negative presentation scale; the inspected SDL pipeline uses no face culling. Front/back body roles are recomputed from anatomical semantic and facing rather than by swapping bones or sockets.

Debug bones, colliders, sockets, and targets use a bounded primitive buffer and the existing compatible sprite pipeline. They do not alter simulation state. Prompt 11's exact observer, update-order, reset, resource, and debug-submission contracts are recorded in `docs/DIAGNOSTICS.md`.

## Resource lifetime and allocation model

Initialization proceeds from platform to resizable window, GPU device, claimed window, swapchain format, shaders, fixed-readback and swapchain-compatible pipelines, sampler, textures, static geometry buffers, transfer buffers, and per-frame instance resources. A mixed scene additionally creates one validated CPU topology catalog, one persistent mesh vertex/index buffer pair, a mesh vertex shader and target-compatible pipelines, and bounded mesh instance/upload buffers in each existing frame slot. Every owner has an explicit `deinit` path. Partial initialization uses `errdefer`, scoped owners, or the enclosing `GpuDemo` cleanup to destroy already-acquired resources in reverse order.

SDL GPU resource destruction maps to the matching API: buffers, transfer buffers, textures, samplers, shaders, pipelines, fences, the claimed window, and the GPU device are each released by their documented function. Command buffers are either submitted or cancelled on every path. Destruction waits for GPU idle when in-flight access makes that necessary.

All simulation arrays, canonical poses, appearance/module runtimes, instance buffers, debug geometry, event queues, and interaction slots have capacities established at initialization. Appearance definitions allow at most 64 attachment points, 128 visuals, 64 regions, 32 groups, eight modules, 16 joints and sockets per module, and hierarchy depth 16. The sprite batch starts at 1,024 records, doubles transactionally to a maximum of 16,384, and reports CPU and GPU growth independently. The mixed queue preallocates 2,048 entries, 1,792 sprite records, and 256 mesh records. Each mesh definition permits 256 vertices and 768 indices; the persistent catalog permits 32 definitions, 4,096 vertices, and 12,288 indices. Three per-frame upload/instance-buffer slots retain fences; a slot is overwritten only after its own fence completes. The ordinary frame loop performs no heap allocation, topology upload, persistent GPU creation, or global device-idle wait.

Each Prompt 7 character embeds eight temporary layer slots and one optional controller value. Global character submission copies at most eight pointers into stack storage and sorts them by numeric entity ID. Runtime character removal is out of scope; scene teardown destroys character-owned animator and pose buffers before the shared clip and skeleton owners.

## Error handling and logging

Subsystems expose meaningful Zig error sets such as dependency, platform, GPU-device, shader, resource, and scene-initialization failures. Errors propagate to the application boundary; code does not convert failure into unconditional success.

Every failed SDL call is logged with the operation name and the current `SDL_GetError()` text before cleanup. GPU driver and shader-format selection are logged at startup. Device, shader, pipeline, texture, buffer, swapchain, and window-claim failures are fatal for the graphical application and GPU smoke test. There is no silent graphics fallback.

## Determinism and test boundary

Given identical configuration, initial state, and per-tick intents on the Windows x64 target, these systems are deterministic and testable without SDL or a GPU:

- Vector, matrix, transform, and interpolation math.
- Fixed-step accumulation policy when driven with explicit elapsed values.
- Clip sampling, pose blending, state transitions, and event emission.
- Character gravity, jumping, static-platform collision, and grounded state.
- Pose-level and per-visual bounded secondary springs/control points.
- Two-bone IK and socket error measurement.
- Handshake phase coordination and draw-key overrides.

Floating-point results are not promised to be bit-identical across unrelated CPU architectures or compiler modes; tests use documented tolerances.

The following require a real SDL GPU device and therefore are excluded from ordinary deterministic tests:

- D3D12 backend/device and swapchain creation.
- DXIL shader creation and graphics-pipeline creation.
- GPU buffers, transfers, texture upload/sampling, blending, instanced draws, fences, and presentation.
- Visual correctness, draw order, and GPU performance measurements.
## Prompt 23 presentation-resource boundary

Real art remains presentation data. The immutable art pack maps stable typed semantic/view IDs to stable atlas-region IDs, then derives page indices and normalized UVs during initialization. Gameplay, character, anatomy, equipment, controller, collision, interaction, and animation definitions do not store atlas coordinates. See `docs/ART_PIPELINE.md` for the complete ownership and validation contract.

Windows Imaging Component decodes required installed PNG files to owned RGBA8 CPU slices during initialization only. `GpuDemo` transactionally creates bounded texture/sampler pages, uploads each once, waits its upload fence, releases decoded pixels, and retains GPU resources until renderer destruction. The common texture-page table is consumed by both rigid-sprite and deformable-mesh ranges. The GPU responsibility remains vertex transformation, RGBA sampling, alpha blending, and indexed-instanced drawing; the CPU remains responsible for semantic resolution, ordering, and every gameplay system.

A future 3D authoring tool is strictly offline. It may render or stylize views and emit PNG pages plus stable region/view/pivot metadata, but the runtime boundary does not change and atlas layout never becomes authoritative identity.

## Prompt 24 character-presentation boundary

`Facing` remains authoritative left/right gameplay state. `presentation_view.Runtime` separately resolves side/front from fixed-tick grounding and activity, a bounded debug override, and optional interaction ownership in that precedence order. The handshake definition requires side and releases its claim on every completion, cancellation, or rollback path. View transitions cannot write physics, controller, interaction, property, equipment, animation-clock, or topology state.

Side rendering consumes the existing appearance transforms and one character-root reflection. Front rendering uses a fixed-capacity projection of the same local pose without facing reflection or a second animator. Both consume existing deformation and attachment-secondary transforms, then enter one global semantic render queue with explicit front body-part layers. The complete view/art ownership and evidence route are documented in `docs/CHARACTER_PRESENTATION.md`.

Base anatomy, removable clothing, and equipment/accessories are separate semantic layers:

```text
base anatomy -> clothing layer(s) -> equipment/accessory layer(s)
```

Prompt 24A's actual production pages bind canonical body, face, and hair regions as `.character`; the garment-only training-vest regions are `.equipment`. Torso and vest regions intentionally share a physical texture page while retaining distinct semantic IDs and region IDs. A character presentation resolves every canonical body region without a garment. Removing or replacing an equipment binding cannot address, hide, or replace the `.character` definition. The neutral opaque torso/pelvis modesty surface is permanent `base_presentation`, not an equipped item. Texture packing remains a renderer optimization and never confers anatomy, clothing, or equipment ownership.

## Prompt 25 wardrobe boundary

The wardrobe catalog is immutable definition data layered onto the existing equipment core. Typed item, component, semantic, slot, anatomy-role, coverage, visual-layer, and preset IDs remain separate. A preset is only a bounded item-ID list. Complete selection uses copy-validate-commit loadout replacement and character-owned property recomputation; it cannot mutate body/hair, root, facing, controller, physics, canonical pose, animation clock, camera, interaction, or renderer ownership.

`wardrobe_presentation.Presentation` resolves the 36 side/front semantic pairs at initialization into fixed arrays. Each frame consumes the character's existing presentation view and existing resolved equipment instances. Front uses the shared Prompt 24 pose/anatomy projection; side uses existing appearance/anatomy matrices. Both submit ordinary sprite or mesh requests into the one global mixed queue. No per-character renderer, per-item draw submission path, name lookup, allocation, decode, or GPU-resource creation occurs in steady state.

Long garments reuse Prompt 19 deformable meshes and Prompt 20 bounded secondary state. Two tiny immutable skirt topologies represent the paired atlas views and are uploaded at startup. Equipment lifecycle rebuild owns mesh/spring cleanup. This is not a general cloth simulation.

The full content/authoring contract is in `WARDROBE.md`; engineering decisions are in `WARDROBE_DECISION_RECORD.md`.

## Prompt 26 environment-presentation boundary

Environment themes are presentation definitions layered over one authoritative
world. They do not own colliders, ground eligibility, player spawns,
interaction coordinates, controller state, fixed time, camera state, character
customization, or GPU resources. Both theme packs resolve and upload at
initialization; `T` changes only the active resolved theme ID.

The global queue orders far backdrop, parallax midground, collision-aligned
terrain, collision-derived white standable tops, existing characters and
wardrobe, foreground framing, and optional detailed collider debug. White tops
are exact projections of solid `ground_query_eligible` AABB tops, not painted
terrain metadata or a debug view. Walls and decorative ledges cannot receive
them.

`docs/ENVIRONMENT_THEMES.md` binds the data model, layer factors, hot-swap
invariants, edge derivation, debug distinction, bounds, and future
level-editor/theme boundary.

## Prompt 25C semantic visual geometry

Semantic visual geometry is bounded authoring metadata evaluated against the
existing authoritative character and the exact submitted production
`SpriteRequest`. It does not add a skeleton, character representation,
renderer, pose correction, or per-character draw path. Typed local landmarks
resolve through alpha-visible atlas bounds, the production pivot/signed
scale/rotation transform, and the acceptance camera. Wardrobe fit contracts
then measure registration, orientation, relative size, alpha coverage, joint
continuity, and optional profile symmetry.

Test/audit-time alpha processing may allocate. Trace collection and debug
submission are fixed-capacity and leave ordinary steady-state behavior
unchanged. `docs/VISUAL_GEOMETRY.md` records the detailed contracts, coordinate
spaces, bounds, diagnostics, and engineering decisions.

## Prompt 27 integrated visual-foundation boundary

`visual_foundation.Scene` is the production composition used by the existing
`--demo foundation` route. It directly composes the Prompt 26 environment
scene and its two Prompt 25 character instances. Those same instances own
controller, animation, anatomy, morphology, breathing, equipment, properties,
deformable garments, secondary motion, view, interaction locks, IK, and final
submissions. The route adds one existing `interaction_system.Manager`; it does
not add another skeleton, character model, animation clock, renderer, or
simulation root.

```text
Character / Anatomy Definition
  + Equipment / Outfit Definitions
  + Art Pack
        |
        v
Character Runtime
        |
        v
Animation / Controller / Interaction
        |
        v
Presentation View Resolution
        |
        v
Semantic Body + Equipment Visual Resolution
        |
        v
Deformation + Secondary Motion + Interaction IK
        |
        v
Unified Sprite/Mesh Render Ordering
        |
        v
Atlas-backed SDL GPU Rendering

World / Collision + Environment Theme
        |
        v
Layered World Presentation
```

### Interaction presentation data

`interaction.PresentationDefinition` contains a view per semantic participant
role, an automatic-view suppression flag, and a typed `OcclusionProfileId`.
The handshake declares side/side and
`handshake_right_hand_contact`. The manager interprets that profile through
its existing four owned override handles. Definitions contain no renderer
callback and no outfit name. Wardrobe visuals inherit the interaction layer
of their bound canonical anatomy part while retaining their authored clothing
layer, so a right-hand glove follows the same participant-qualified ordering
as the right hand.

Ordinary side presentation remaps both arm rests into a readable profile.
During an interaction-owned side view, the participating right-arm chain
preserves the authored animation/IK plane, while the nonparticipating arm and
legs retain profile treatment. This downstream projection does not change
socket positions, IK targets, physics roots, or interaction timing.

Completion, cancellation, startup rollback, character reset, and scene reset
release view claims, override handles, IK ownership, and interaction locks.
Grounded-idle front presentation then resumes.

### Prompt 27A evidence integrity

`foundation_evidence.zig` defines an ordered 16-case capture matrix. Each case
combines an optional script-stage discriminator with authoritative controller,
collision, animation, presentation, interaction, and debug predicates. Stage
or filename identity is never sufficient. `Tracker` advances inspection holds
in fixed simulation ticks, ignores duplicate zero-substep render
observations, resets stability when a predicate becomes false, enforces a
bounded timeout, and validates commit order and final completeness.

`visual_foundation.Scene.captureObservation` is a read-only projection of the
same production state submitted that frame. It records semantic entity,
controller, foot-to-surface, presentation, body/morphology/hair/outfit, theme,
interaction, debug, camera, render, resource, and allocation data. The
production D3D12 readback and its SHA-256 payload evidence are bound to that
observation in per-capture JSON and an ordered manifest.

`acceptance_hud.zig` draws a fixed 3-by-5 glyph HUD through the existing
`UnifiedRenderQueue`. It owns no input, mutable control, renderer, texture, or
steady-state allocation. Clean readbacks occur from the prepared production
queue; the HUD is then appended to that same queue for the visible evidence
window. Detailed-debug capture uses the actual production diagnostic
submissions.

The deterministic review tool validates and converts the 16 PPMs, emits five
contact sheets and raw per-case metrics, and leaves the result
`[PENDING OWNER REVIEW]`. Historical Prompt 27 evidence is never overwritten,
and no Prompt 27A artifact is an approved golden.

### Prompt 27B contact, framing, parallax, and presence

`foundation_coherence.zig` measures one production contact chain: immutable
supporting-collider top, independently identified post-IK sole socket,
alpha-derived sole landmarks from the actual submitted anatomy/equipment
record, camera projection, and real D3D12 surface-edge pixels. Character and
wardrobe traces carry their actual `UnifiedRenderQueue` submission indices,
so alignment modifies only the corresponding submitted visual transform.
Physics roots, colliders, animation poses, IK state, anatomy/equipment
identity, and source art remain unchanged.

The same `Camera2D` that owns ordinary presentation consumes actual submitted
bounds from anatomy, hair, headwear, equipment, and deformable garments. It
applies one bounded vertical safe-region correction while retaining the
existing horizontal policy, then publishes that camera for the same submitted
frame. It cannot write simulation, collision, interaction, or foot-planting
state.

The route retains its incremental 960×540 to 800×510 to 640×480 resize and
also performs one separately identified direct 960×540 to 640×480 event.
Every changed-viewport frame is classified as instantaneous viewport
reprojection: its finite head/foot projection must satisfy the unchanged
safe-region contract immediately. The first submitted frame at a
non-reference height uses the available vertical interval symmetrically only
when its submitted bounds independently require a safe-region correction,
giving later bound changes head and foot slack. Already-safe identical bounds
leave camera center unchanged; subsequent frames return to nearest-edge
correction. A resize is not misreported as ordinary world-camera motion, while
every same-viewport camera-center step still must satisfy the unchanged
16 px/render bound.

Environment submission exposes typed far, midground, and gameplay trace
records containing the actual anchors and camera factors used by production.
Semantic validation predicts ordered displacement from those factors.
Debug-only color markers are appended through the existing global queue after
the clean production capture; the independent D3D12 parser measures their
actual displacement, safe bounds, collider top, and sole endpoints. There is
no second renderer or validation-only transform path.

The runtime still has no general dynamic character collision. The
deterministic foundation script uses ordinary controller input for a bounded
partner walk-clear and return, and an allocation-free visible-presence
measurement rejects uncontrolled overlap when its explicit policy is
`enforce_acceptance`. The unrestricted interactive route uses `measure_only`:
it exposes the same frame/tick, roots, overlap, interaction context, and
pass/fail result without turning the visual acceptance measurement into
collision authority. Stopped roots must remain exactly stable and every
moving root is constrained by the normal per-tick controller speed bound.
Interactive character pass-through remains a documented limitation rather
than an implied collision feature.

### Prompt 27C anatomy silhouette authority

Prompt 27C does not add a skeleton, pose, animation, renderer, or
character-specific draw path. `character_art.submitTraced` remains the one
production presentation path and optionally records the same submitted
`SpriteRequest` in a bounded semantic trace. `anatomy_quality.zig` evaluates
that trace together with decoded alpha-visible pixels and the production
camera.

The ruler is style-, view-, role-, and side-aware. It measures shoulder slope
and curvature, parent/child widths at articulated joints, body-relative
length ratios, transverse crop-edge darkness, foot axes, and neutral-front
symmetry. Production contracts belong to the conventional male/female
presentation profiles; they are not a universal human-proportion table.
Missing matrix cases, alpha, landmarks, or finite transforms fail closed.

The three Prompt 27C pages are immutable runtime inputs installed and uploaded
through the existing art-pack catalog. They version their Prompt 25
predecessors, retain the same anatomy/equipment ownership, and preserve the
permanent `base_presentation` modesty classification. Reauthoring changes
silhouette pixels, authored body-part dimensions, pivots, and front-foot rest
presentation only; physics roots, sockets, foot planting, IK, garments, and
the Prompt 27B camera remain authoritative and unchanged.

Prompt 27C-R1 replaces only the owner-rejected torso pixels. The source pass
starts from the last accepted Prompt 25A pages, edits four explicit shoulder
rectangles, and preserves every pixel outside them byte-for-byte. A canonical
side torso region is reflected by the existing root transform for the other
direction. The component page and all non-torso anatomy remain the accepted
Prompt 27C output. Straight-alpha ownership and nearest sampling remain in the
renderer; the authoring audit rejects transparent-white fringe inputs and
unapproved page changes.

### Future interaction and authoring boundaries

A future paired definition may add a bounded array of semantic contacts such
as hand-to-hand, hand-to-shoulder, or hand-to-torso. Authored paired animation
remains primary; IK corrects measured endpoints rather than inventing a
full-body pose. Richer interactions may need a larger data-defined occlusion
profile later, but the current handshake deliberately retains its sufficient
four manager-owned slots.

Carrying or lifting requires a separately owned bounded
participant-relative root constraint; the fixed-root handshake neither
parents roots nor provides that behavior. Chairs, doors, beds, ledges, and
other props would expose typed world interaction anchors owned by world data.
Front, back, three-quarter, or cinematic interactions remain presentation
definition choices backed by authored views. A focused synthetic definition
test proves front/front selection without adding a second visible interaction.

Future 3D authoring remains offline:

```text
3D source character
  -> generate multiple 2D presentation views
  -> atlas + semantic metadata
  -> existing Art Pack and runtime
```

The runtime has no dependency on that future editor.

### VF-01 visual truth snapshot and capture boundary

VF-01 adds one read-only inspection branch after the production character and
wardrobe presenters have emitted their actual traced submissions:

```text
authoritative controller/collider
  -> canonical skeleton pose
  -> exact production presentation projection
  -> appearance/anatomy/module topology
  -> atlas region and alpha landmarks
  -> final sprite/mesh submission
  -> read-only visual_truth.Snapshot
```

The controller and collider remain gameplay authority. The canonical pose
remains animation/IK/foot-planting authority. `character_art.Presentation`
owns view-specific projection, and its public `projectionFor` function is
shared by the production submitter and truth snapshot. Appearance and anatomy
retain their existing topology domains. Atlas metadata never becomes
physics. The final `UnifiedRenderQueue` request and trace remain rendering
truth. Automated measurements and bundle hashes are acceptance evidence only;
owner aesthetic approval remains external and pending.

F1 uses a deterministic four-state cycle. Rig compares physics and canonical
topology. Rig + Visual Registration adds projected transforms, final pivots,
alpha bounds, atlas landmarks, and residual lines. All Diagnostics composes
the retained ground, foot-lock, IK, interaction, camera, Prompt 27B, and
presence diagnostics. Reset preserves the selected inspection mode. No mode
can change simulation, view selection, interaction eligibility, collision, or
camera.

The snapshot and 2,048-entry debug buffer are explicitly allocated once
during scene initialization. The larger buffer was justified by an observed
fail-closed overflow at command 513 on the complete production overlay.
Alpha geometry is decoded into a CPU catalog only during initialization.
Persistent D3D12 readback resources are also created before stabilization.
Normal frames perform no diagnostic allocation or GPU-resource creation.

F4 is outside `PendingInput` and `CharacterIntent`. The already-prepared clean
production queue is read back first. All Diagnostics is then appended from
the same immutable snapshot and read back second. The path rejects any
render-frame, simulation-tick, authoritative, presentation, or capture
fingerprint change. File creation is fail-closed: a hidden incomplete
directory is validated and hashed before an atomic preserve-rename exposes
the timestamped, globally monotonic final directory. F4 may perform bounded
file/process/hash allocation outside the fixed-tick loop. Automated Prompt
27 evidence retains its deterministic untimestamped naming policy.

### VF-02 authoritative atlas-to-rig registration

VF-02 inserts one structural placement authority between the active
presentation projection and final character sprite submission:

```text
canonical pose
  -> front/side production projection
  -> named projected targets
  + alpha-visible atlas landmarks
  -> visual_registration solver
  -> final SpriteRequest
  -> UnifiedRenderQueue + RegistrationEvidence
```

Point bindings map one landmark to one target under explicit orientation and
scale policies. Segment bindings derive translation, rotation, and
longitudinal scale from proximal/distal pairs while keeping transverse
morphology independent. Frame bindings map bounded torso/pelvis axes.
Mesh-bridge metadata is validated but has no migrated production garment.
Missing, coincident, nonfinite, reversed, degenerate, or excessive-residual
data fails before queue submission.

The trace stores evidence generated from the exact submitted request. VF-01
mismatch lines and JSON consume those points directly. Registered records are
`authoritative_registration`; non-shoe wardrobe records remain
`compatibility_adapter`; unmigrated character records are
`transitional_legacy`.

Registered anatomy-foot placement is handed directly to wardrobe submission
as a fixed two-entry left/right value. In front view, the base foot owns one
`point_axis` contract: its alpha-derived ankle maps to the projected ankle and
its authored `sole_back -> sole_front` axis maps to the view's support tangent.
The male 16-degree and female 13-degree toe-out data remain explicit physical
ground-plane policy. Front projection retains the signed lateral component
and discards depth instead of mapping depth into world Y, so the projected
support tangent is horizontal. Heel, toe, sole-back, and sole-front remain
transformed evidence rather than independent target endpoints.

Closed footwear receives the exact stored ankle/support-axis target from the
registered anatomy foot and solves its own alpha-derived ankle and sole axis
through the same registration solver. The registered foot's transverse
authored scale also supplies the front shoe thickness. The closed-footwear
metadata suppresses covered base-foot pixels while retaining their full
trace, landmarks, and registration evidence; `ankle` is the declared exposed
anatomy anchor. This removes the former independent wardrobe `+/-78` degree
rotation without adding mutable simulation state, a second presenter,
per-frame allocation, or a parallel transform formula.

The fixed trace is initialization-owned and heap-backed to keep the enlarged
bounded diagnostic structure off the Windows Debug stack. Atlas-alpha scan
scratch is initialization-only and freed immediately. Neither choice adds a
steady-state allocation or GPU resource.

### VF-03 immutable component topology

VF-03 compiles the existing appearance and anatomy definitions into
`component_graph.Definition`. The graph is a bounded facade, not a third
editable hierarchy: appearance still owns visual attachments and rig-module
members, anatomy still owns part evaluation and active presets, and the graph
is the one inspection/validation authority that joins their identities,
parents, typed sockets, connection modes, bound visuals, and optional module
ownership. Owner tokens and a topology fingerprint reject mutation after
initialization.

Sockets declare accepted child tags and roles, capacity, supported
connections, and local frames. Components declare point/segment/frame/mesh
binding, maximum multiplicity, child policy, required/projected views,
optional module template, and typed material/morphology extension names.
`continuous`, `intentional_gap`, `hidden`, and `soft_bridge` are explicit
data; alpha overlap never selects a connection mode.

`FrontAnatomyProjection` evaluates component/socket transforms in immutable
definition order after the ordinary front/side appearance projection has
resolved canonical bones, attachment points, module joints/sockets, and
visual-parent sources. Direct point-bound eye, eyebrow, and hair visuals use
the projected component transform and the existing point-registration
solver. The standard controller, pose, animation, IK, collision, interaction,
camera, unified queue, and GPU resource authorities are unchanged.

VF-01 schema 4 exports this compiled topology. The expanded bounded snapshot
is filled in place to avoid Windows Debug stack copies and performs no
steady-state heap allocation. Optional module joints are all explicit at
initialization; no runtime joint creation exists.

### VF-03-R1 graph-to-production invariant

The original VF-03 graph could declare an optional component's bound visuals
without proving that `character_art` resolved and submitted them. R1 makes the
production trace a required cross-layer result. For every active optional arm:

```text
declared graph visuals
  == resolved active visuals
  == expected submissions
  == actual final submissions
```

The bounded value is three. `character_art` builds upper-arm, forearm, and
hand requests from the already-projected module endpoints and submits them to
the existing `UnifiedRenderQueue`. The same trace record owns component,
module, parent, and joint identities; placement authority; world transform;
visible bounds; graph-bound visual index; and final submission index.
`visual_truth` validates and exports that record; it does not reconstruct
placement.

Continuous and intentional-gap roots share one projection/submission path.
Continuous reanchors the module root to the projected torso socket.
Intentional-gap applies the declared vector in world metres, then projects it
with the current front/side/reflected transform. Gap pixels are observation
data derived from the captured camera, never placement authority. Inactive
modules retain immutable definition data but produce no active projected
members and no queue submissions.
