# Testing Strategy

## Test layers

Tests are divided by the external state they require. Ordinary `zig build test` and `zig build check` must not initialize SDL video or create a GPU device. GPU and manual visual tests are explicit separate steps.

## Pure unit tests

Pure tests cover small data transformations and invariants:

- Vector arithmetic, normalization edge cases, matrices, affine composition, and inverse transforms.
- Angle wrapping, shortest-arc interpolation, and render interpolation.
- Skeleton hierarchy validation, local-to-world traversal, and socket transforms.
- Clip boundary sampling, looping, pose blending, and half-open event intervals.
- Input dead-zone and raw-state to `CharacterIntent` conversion using platform-neutral inputs.
- Collider overlap/sweep primitives and spring integration.
- Two-bone IK reachability, bend direction, and finite output at degenerate distances.
- Stable draw-key ordering and handshake limb-front overrides.

Tests assert behavior and invariants rather than restating implementation expressions.

Prompt 2 additionally tests the compile-time-bound CPU/GPU strides, independently hand-computed transform points, zero and ninety-degree rotation, nonuniform and negative scale, center/top-left/arbitrary pivots, translation order, zero scale, non-finite rejection, UV/tint/page validation, integer layer boundaries, negative unsigned layers, stable equal-key ordering, reverse order, repeated deterministic sorts, near-limit submission indices, empty batches, exactly-full and growing capacity, allocation failure, byte-size overflow, 1,000 one-page instances, two page ranges, and page-return boundaries. These remain SDL- and GPU-free.

Prompt 3 adds independently hand-computed vector, matrix, transform-order, four-level hierarchy, direction, zero-scale, small-value, angle-wrap, shortest-interpolation, and tolerance-boundary cases. Skeleton tests cover valid semantics, invalid parents, self-parenting, two- and three-bone cycles, missing/multiple roots, missing/duplicate/invalid semantics, non-finite rest transforms, invalid/duplicate sockets, and transactional allocation faults. Pose/socket/attachment tests cover rest restoration, repeated evaluation, independent poses and character transforms, compatibility mismatch, rotated/scaled ancestors, immutable definition data, exact 15-part submission, preserved pivots/layers/page, one range, and fixed-buffer zero-allocation behavior.

Prompt 4 adds malformed clip, track, key, event, state, transition, fallback, and allocation-fault cases. Sampling tests cover before/at/between/after-key behavior, one-key and missing components, step/linear/smooth interpolation, shortest-angle wrap, source immutability, alias rejection, and compatibility. Playback and event tests cover time-zero entry, exact open/closed interval boundaries, same-time authored order, exact duration, one/two/five/eight wraps, ninth-wrap rejection, speed zero, negative-speed rejection, capacity overflow, and one-shot final events. Blending and state tests cover endpoints, hand-derived midpoint, invalid weight, input independence, transition interruption policy, immediate transitions, reverse transitions, one-shot completion/fallback/re-entry, independent animators, authored timelines, and fixed-buffer zero allocation.

## Deterministic simulation tests

Simulation tests create no window and use explicit fixed ticks. Scenarios include:

- Idle remains grounded without root drift over thousands of ticks.
- Walk changes root position, cycles animation, and produces visible vertical pose movement without moving the collider vertically through the ground.
- Jump applies physical upward velocity, transitions through jump and fall, collides with a platform, enters land, and returns to locomotion.
- Landing impulse drives bounded visual compression and a stable decay.
- Static-platform edge, ceiling, side, and high-speed approach cases do not tunnel beyond the algorithm's documented limits.
- A handshake request creates one paired session, approaches without teleporting, synchronizes phases, solves both arms, holds measured hand separation within 0.015 m, releases, and removes the session.
- Cancellation caused by range, participant removal, or obstruction leaves both characters independent and responsive.
- Replaying the same initial state and intent sequence produces the same state/event trace on the Windows x64 target.

## Floating-point tolerances

Exact floating-point equality is used only for values defined by exact assignment or discrete state. Numerical assertions use the smallest tolerance appropriate to the subsystem:

| Measurement | Tolerance | Rationale |
| --- | --- | --- |
| Basic vector/matrix identities near unit scale | absolute `1e-5` | Covers normal f32 rounding across several operations without hiding a visible transform error |
| Angle interpolation | absolute `1e-5` radians | Covers wrap/interpolation rounding and is far below a visible angular difference |
| Collision contact position | absolute `1e-4` m | One tenth of a millimetre is above accumulated f32 contact arithmetic noise and below gameplay-visible penetration |
| IK endpoint in an analytically reachable case | absolute `1e-4` m | Allows transform-chain rounding while still detecting an incorrect solve |
| Handshake hold socket separation | maximum `0.015` m | A 1.5 cm production acceptance bound accounts for two animated shoulders while requiring visually convincing contact |
| Spring settled value | absolute `1e-4` m and velocity `1e-4` m/s | Tests convergence without requiring an asymptotic value to become bitwise zero |

A test that needs a larger tolerance must explain the numerical source locally. Tolerances may not be widened merely to make a failure pass.

## GPU smoke tests

`zig build gpu-smoke` is an opt-in Windows test that requires a physical or supported hardware GPU. It must:

1. Initialize SDL video and create a small test window.
2. Prove DXIL support for `direct3d12`, create that backend explicitly, log the driver returned by SDL, and verify the created driver and reported shader format.
3. Claim the window and acquire a swapchain texture.
4. Load the build-produced vertex and pixel DXIL, create both shaders and the sprite graphics pipeline.
5. Upload a four-color procedural RGBA texture and shared quad vertex/index data, then submit two distinct records through the production three-slot sprite-batch transfer path.
6. Execute both shader stages and render the two instances in one indexed instanced draw, submit, and present three frames.
7. Render again to an `R8G8B8A8_UNORM` color target and download that render target through an SDL GPU download transfer buffer.
8. Use an explicit D3D12-compatible row pitch: `align(width * 4, 256)` bytes, pass `pixels_per_row = row_pitch / 4`, and address each mapped row with that pitch. The implementation checks SDL's texel block size instead of assuming a four-byte format contract silently.
9. Submit with `SDL_SubmitGPUCommandBufferAndAcquireFence`, wait successfully with `SDL_WaitForGPUFences`, and only then map the download transfer buffer.
10. Compare an exterior clear pixel and two non-overlapping interior sprites expected to match red and yellow regions selected by distinct UV rectangles from the same texture. Channel tolerance is one integer code value.
11. Inject controlled failures after sprite-batch CPU allocation, SDL initialization, window creation, device creation, window claim, shader creation, sampler creation, textures, shared quad vertex/index buffers, static transfer creation, upload, instance frame-slot creation, pipeline creation, transactional GPU growth replacement, and frame-fence acquisition.
12. Release every resource and report any SDL operation plus `SDL_GetError()` on failure.

The smoke test fails with a nonzero exit when a graphical session, swapchain texture, required hardware/backend, DXIL agreement, rendering operation, fence, mapped readback, or expected pixel is unavailable. It is never reported as skipped success and never falls back to another API.

## Manual visual acceptance tests

The final visual pass records the GPU driver, resolution, and build mode, then verifies:

- Two visibly segmented humanoids render through the GPU sprite batch.
- Keyboard and gamepad independently control the intended character with sensible dead zones and hot-plug behavior.
- Idle, walk, jump, fall, land, and handshake states are visually distinct and transition coherently.
- Walking shows vertical body movement while the physics root remains collision-correct.
- Gravity, jump arcs, and collision work on every static demo platform.
- Landing produces visible compression followed by stable spring-like recovery and secondary follow-through.
- The handshake is synchronized, both hands target the shared point, and the debug overlay reports socket separation at or below 0.015 m during grip.
- A control or scenario switches which handshake hand/forearm is in front, with the requested order visible.
- Debug display identifies bones, colliders, hand sockets, and the shared interaction target.
- Alpha edges blend correctly and no body part is rendered through a per-sprite command submission path.

## Performance and allocation checks

Performance checks run a ReleaseFast build after correctness passes. Debug metrics report fixed ticks, frame time, instance count, draw count, transfer bytes, fixed-step overruns, and any bounded collection growth.

Acceptance targets for the two-character demo are:

- Zero heap allocations during a steady 10,000-tick simulation after initialization.
- Zero unreported capacity growth during steady rendering.
- One sprite instance upload and one indexed instanced sprite draw for a frame when all body parts share the atlas/pipeline; debug rendering is counted separately.
- No command submission per body part.
- Stable 60 displayed frames per second on the documented reference machine, with 120 Hz simulation and no sustained fixed-step overruns.

The reference GPU/CPU and measured percentile frame times will be added when performance testing begins; no unmeasured target is reported as passed.

Prompt 2's executable evidence run is `zig build run -- --frames 300`. Its final metrics must show 1,000 submitted/visible/sorted sprites, zero culled sprites, one range, one actual `SDL_DrawGPUIndexedPrimitives` call with 1,000 instances, 60,000 uploaded instance bytes, no post-stabilization CPU allocation, no GPU slot growth, and identical persistent-resource creation counts before the run, after warm-up, and after frame 300. Frame-slot waits are acceptable only when a reused slot's fence was observed unsignaled.

Prompt 3's executable evidence run is `zig build run -- --frames 300 --demo humanoid`. It must report 16 bones, four sockets, 15 attachments and humanoid sprite instances, one texture-page range, one actual draw, zero pose/socket/submission allocation after initialization, and zero GPU-resource creation from pose changes. Frame 0 and modified-pose logs must show different right-hand and left-foot socket positions resulting from actual ancestor rotations.

Prompt 4's executable evidence run is `zig build run -- --frames 360 --demo animation`. It must report eight clips/states, the two idle/walk transitions, bounded foot-contact logs, 15 humanoid instances, one texture-page range, one actual draw, unchanged character-world root, and zero measured sampling/blending/event/update/pose/submission allocation or animation-created GPU resources. Logged idle and walk socket positions must differ through actual ancestor tracks.

## Build command contract

The finished build graph must support:

```text
zig build
zig build test
zig build run
zig build gpu-smoke
zig build check
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=ReleaseFast
```

`zig build check` runs `zig fmt --check` on Zig sources and build files, pure and deterministic tests, and repository audits that need no GPU. Source audits check for prohibited high-level render APIs, forbidden graphics/engine dependencies, unfinished markers, disabled tests, and missing resource-release ownership. Documentation examples are not treated as executable source.

Prompt 1 introduced each listed command with a real target. Later milestones extend the same build interface rather than replacing it.
