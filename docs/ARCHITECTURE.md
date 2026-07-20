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

The stored columns are the transformed local X basis, transformed local Y basis, and affine translation. Points use homogeneous `w = 1`; directions use `w = 0`, so translation never affects a direction. The arbitrary character root is the authored world origin. Character and bone translations use metres; only render-attachment submission converts metres to pixels.

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

## Fixed simulation and render interpolation

Simulation advances at exactly 240 Hz (`dt = 1 / 240` seconds). One `f64` accumulator receives validated real elapsed time, performs whole fixed ticks, then renders an interpolation between the previous and current completed simulation snapshots. Controller integration uses the validated `f32` form of the same constant. Interpolation never feeds back into simulation and never advances the animator.

Real frame delta is rejected when non-finite, sanitized to zero when negative, and clamped to `0.10 s`. At most eight simulation ticks may be processed for one displayed frame. Whole ticks beyond that budget are discarded explicitly and reported as both per-frame and lifetime discarded seconds; only the fractional accumulator remainder is retained. The loop never performs unbounded catch-up or claims discarded time was simulated. Pause accumulates no real time; a pending single-step executes exactly one physics/animation tick. Tests drive explicit elapsed values and do not read wall-clock time.

Simulation order within one tick is fixed:

1. Consume pending frame edges once and produce `CharacterIntent`.
2. Advance controller velocity, gravity, jump policy, and static collision.
3. Classify grounded state and produce physical jump/landing results.
4. Select animation from authoritative physics and advance the animator once by `1 / 240` second.
5. Evaluate the local pose and then the world pose from the authoritative physics root.
6. In later milestones, apply bounded visual springs and solve interaction IK without changing the physics root.
7. Emit animation/interaction data and preserve previous/current simulation transforms for render interpolation.

## Input and character intent

SDL keyboard and gamepad code owns device discovery, hot-plugging, dead zones, and raw button state. It produces one renderer-independent frame snapshot whose buttons distinguish pressed, held, and released state. A pending-edge layer retains jump press/release and interaction press through zero-tick rendered frames, consumes each edge on the first following simulation tick, and preserves held state for every applicable tick. It then produces `CharacterIntent` containing normalized horizontal movement and jump/interaction semantics; reset and debug/time controls remain frame controls. Character, animation, physics, and interaction systems never query SDL directly. Tests construct snapshots and intents without platform input. `docs/CONTROLS.md` binds the exact key, gamepad, merge, and dead-zone policies.

## Skeleton and pose ownership

A `Skeleton` is immutable after initialization. It owns the bone hierarchy, bind-local transforms, sprite attachment metadata, hand sockets, and semantic bone indices. Animation clips refer to bones by validated indices; names are used for loading and diagnostics, not per-tick lookup.

Prompt 3 implements this as `SkeletonDefinition`: one contiguous bone array, one contiguous socket array, one parent-before-child evaluation-order array, and fixed semantic-to-index tables. Bone and socket names use inline bounded storage, so no record owns an individual heap allocation. Authored input order is unrestricted. Validation uses a bounded iterative resolved-state pass; a pass with no progress identifies a cycle without recursion. Exactly one root, all 16 humanoid bone semantics, and all four hand/foot socket semantics are required.

Each `Character` owns its controller state, animator state, current local pose, previous pose snapshot, secondary springs, and IK workspace. The demo characters may share immutable skeleton and clip data, but never share mutable pose arrays. All arrays are allocated or fixed-capacity during initialization. The steady-state loop performs no heap allocation.

The current `Pose` owns separate contiguous local `Transform2D` and world `Mat3` arrays. It is compatible only with the definition allocation token and bone count captured at initialization; every evaluation receives the still-live definition explicitly. Definitions never cache current local or world pose. Render attachments are immutable local metadata and never store authoritative world transforms. `docs/HUMANOID.md` records the concrete hierarchy, proportions, layer values, and runtime allocation proof.

World bone transforms are rebuilt parent-before-child from the physics root plus the local visual pose. Socket positions are calculated from those world transforms. A handshake alignment claim is valid only when the measured distance between the two selected hand sockets is within the documented tolerance.

## Animation sampling

Clips are CPU-side data made of per-bone translation, rotation, and scale tracks plus timestamped events. Sampling uses binary search or a monotonic cursor chosen during implementation, linear interpolation for translation and scale, and shortest-arc interpolation for angles. Missing tracks use the skeleton bind value.

Prompt 4 implements bounded binary-search sampling over immutable contiguous clip arrays. Step, linear, and smoothstep segments are explicit; smooth uses `t^2 * (3 - 2t)`. Values hold before the first and after the final key. The event interval is `(previous, current]`; time-zero records fire on state entry and loop wrap, while exact-duration records fire in the ending cycle. One update may traverse at most eight loop boundaries and writes to a per-animator preallocated event buffer.

The state machine owns idle, walk, jump, fall, land, and handshake transitions. Cross-fades sample both source and destination poses and blend into a separate output pose; they do not mutate clip data. Looping event scans use half-open time intervals so an event at a loop boundary fires exactly once. Locomotion clips provide visual motion only. Physics decides whether the root rises, falls, lands, and collides.

The current bounded machine has eight required states. Idle-to-walk and walk-to-idle advance both source and destination during a 0.30-second local-component blend. Requests during an active transition are rejected; a same-state request is a no-op. A one-shot exposes its final pose and events before fallback starts on the next update. `docs/ANIMATION.md` binds exact sampling boundaries, event ownership, fallback durations, and authored timelines.

Walk includes an authored vertical pelvis/body component. Landing adds a bounded compression spring driven by the physical landing impulse. Other secondary offsets use stable, fixed-step spring integration and are clamped to authored limits.

## Physics

The physics body is one stable axis-aligned character-controller box anchored at the root, not one rigid body per bone. The collision world owns one contiguous immutable array containing floor, wall, ceiling/overhang, and two raised platforms with stable IDs. Movement uses axis-separated continuous sweeps, horizontal before vertical, followed by ground classification. Only a downward vertical support hit produces normal `(0, +1)`, grounded state, and a supporting ID; wall and ceiling hits cannot. Initial penetration is rejected, while runtime contact validation tolerates only the documented `0.0001 m` floating-point contact epsilon. `docs/PHYSICS.md` binds all configuration values, timers, collision consequences, and ownership details.

Root position and velocity are authoritative physics state. Pelvis bounce, landing compression, hand IK, and spring offsets are visual pose state. Animation cannot move the collider through a platform, and collision correction cannot erase visual secondary motion.

## Interaction ownership and handshake coordination

`InteractionSystem` owns transient pair sessions. A handshake session records both participant IDs, selected hands, phase, shared target, approach timing, socket-error history, and release state. Characters receive constraints from the session but do not own or permanently reference each other.

Handshake phases are request, approach, grip, release, and complete/cancelled. The shared target is derived from both characters' reachable regions. Small root alignment is achieved through ordinary bounded controller velocity during approach; full-body teleportation is not the normal alignment mechanism. Excess separation, obstruction, invalid participants, or failure to converge cancels the session cleanly.

During grip, each arm uses a two-bone analytic IK solve with a configured elbow bend preference. The solve targets the same world-space grip point while preserving shoulder ownership. After world transforms are rebuilt, the system calculates both hand socket positions and records their separation. Visual acceptance requires the measured grip error to remain at or below 0.015 m during the hold phase.

## CPU/GPU responsibility boundary

CPU responsibilities:

- Platform input to `CharacterIntent` conversion.
- Fixed-step animation, physics, collision, springs, IK, and interaction coordination.
- Skeleton traversal and socket measurement.
- Stable transparent draw ordering and explicit limb-front overrides.
- Building a bounded array of sprite instances and debug primitives.

GPU responsibilities through the SDL3 GPU API:

- Transforming unit-quad vertices from packed instance data.
- Sampling the body-part texture atlas.
- Applying vertex colour and texture alpha.
- Alpha blending into the swapchain target.
- Drawing many sprite instances from a single indexed quad and instance buffer.

No SDL high-level 2D renderer participates in this boundary.

## Transparent draw order and instancing

Each visible body part produces a CPU `SpriteSubmission` with world position, rotation, nonuniform scale/size, pivot, atlas UV bounds, straight-alpha tint, texture page, and a lexicographic integer draw key. The key contains signed scene and interaction layers, unsigned actor and body-part layers, and a bounded `u64` submission index. A stable semantic order preserves original submission order for equal layers without using float depth, addresses, or packed arithmetic.

The handshake session explicitly raises or lowers the participating hand and forearm keys so the selected limb is in front. This is data-driven ordering, not a shader accident. Consecutive compatible texture pages form draw ranges without reordering across page changes. The current one-page atlas and straight-alpha sprite pipeline produce one range. The renderer uploads 60-byte GPU records and calls `SDL_DrawGPUIndexedPrimitives` with six shared quad indices and `num_instances > 1`. Slot 1 is declared `SDL_GPU_VERTEXINPUTRATE_INSTANCE`; a draw per body part or CPU-expanded mesh does not qualify as instancing. `docs/SPRITE_BATCH.md` binds the complete layout and transform contract.

Debug bones, colliders, sockets, and targets use their own debug pipeline and bounded primitive buffer. They do not alter simulation state.

## Resource lifetime and allocation model

Initialization proceeds from platform to window, GPU device, claimed window, swapchain configuration, shaders, pipeline, sampler, textures, static geometry buffers, transfer buffers, and per-frame instance resources. Every owner has an explicit `deinit` path. Partial initialization uses `errdefer` or an equivalent scope guard to destroy already-acquired resources in reverse order.

SDL GPU resource destruction maps to the matching API: buffers, transfer buffers, textures, samplers, shaders, pipelines, fences, the claimed window, and the GPU device are each released by their documented function. Command buffers are either submitted or cancelled on every path. Destruction waits for GPU idle when in-flight access makes that necessary.

All simulation arrays, poses, instance buffers, debug geometry, event queues, and interaction slots have capacities established at initialization. The sprite batch starts at 1,024 records, doubles transactionally to a maximum of 16,384, and reports CPU and GPU growth independently. Three per-frame upload/instance-buffer slots retain fences; a slot is overwritten only after its own fence completes. The ordinary frame loop performs no heap allocation, persistent GPU creation, or global device-idle wait.

## Error handling and logging

Subsystems expose meaningful Zig error sets such as dependency, platform, GPU-device, shader, resource, and scene-initialization failures. Errors propagate to the application boundary; code does not convert failure into unconditional success.

Every failed SDL call is logged with the operation name and the current `SDL_GetError()` text before cleanup. GPU driver and shader-format selection are logged at startup. Device, shader, pipeline, texture, buffer, swapchain, and window-claim failures are fatal for the graphical application and GPU smoke test. There is no silent graphics fallback.

## Determinism and test boundary

Given identical configuration, initial state, and per-tick intents on the Windows x64 target, these systems are deterministic and testable without SDL or a GPU:

- Vector, matrix, transform, and interpolation math.
- Fixed-step accumulation policy when driven with explicit elapsed values.
- Clip sampling, pose blending, state transitions, and event emission.
- Character gravity, jumping, static-platform collision, and grounded state.
- Secondary springs.
- Two-bone IK and socket error measurement.
- Handshake phase coordination and draw-key overrides.

Floating-point results are not promised to be bit-identical across unrelated CPU architectures or compiler modes; tests use documented tolerances.

The following require a real SDL GPU device and therefore are excluded from ordinary deterministic tests:

- D3D12 backend/device and swapchain creation.
- DXIL shader creation and graphics-pipeline creation.
- GPU buffers, transfers, texture upload/sampling, blending, instanced draws, fences, and presentation.
- Visual correctness, draw order, and GPU performance measurements.
