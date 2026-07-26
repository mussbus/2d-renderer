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

`src/graphics/camera2d.zig` owns presentation state: a finite world-space center, nonzero drawable-pixel width and height, and a positive pixels-per-metre zoom. It imports only the renderer-independent math module. `worldToPresentation`, `presentationToWorld`, `worldToClip`, visible half-extents, the 16-byte GPU uniform, and deterministic horizontal following are therefore testable without SDL, a window, or a GPU.

The default camera uses 82 pixels per metre and center `(0, 135 / 82) m`. At 640×480 this maps world origin to the previous `(320, 105)` presentation point, so existing scenes remain visually comparable. Resizing changes only the half-width and half-height visible in world metres. Zoom and character size do not change, so a larger window reveals more world instead of stretching it.

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

Viewport changes update only the camera viewport scalars. The scene compares controller, interaction, appearance selection, loadout fingerprint, capability state, and pending-edge count before and after every synthetic resize. A real SDL resize reaches the same camera method after drawable-pixel refresh. Neither route reinitializes characters or GPU resources.

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
