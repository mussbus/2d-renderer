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
- Analytical two-bone reachability, segment invariants, degenerate distances, bend direction, mirroring, continuity, and repeated-solve determinism.
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
- A fixed-position handshake request creates one paired session without moving roots, synchronizes both role samples and shared events, measures the authored socket baseline, releases, and removes the session.
- Cancellation before and after contact restores only interaction-owned handles and leaves both characters independent and responsive.
- Replaying the same initial state and intent sequence produces the same state/event trace on the Windows x64 target.

Prompt 5 adds synthetic frame-snapshot tests for keyboard left/right/opposition, analog dead zone and merge, jump press/hold/release, interaction press, zero-tick preservation, multi-tick single consumption, rapid press/release, independent builders, and reset. Clock tests cover zero/one/multiple ticks, negative and non-finite deltas, `0.10 s` clamping, the eight-tick limit, explicit discarded-time accounting, pause/single-step, bounded interpolation alpha, and reset synchronization. Schedule equivalence groups an identical 240-tick intent trace into one-tick, two-tick, and mixed zero/one/multiple-tick rendered frames and compares authoritative position, velocity, grounded state, facing, tick count, and animation state within the tabled tolerance.

Controller/collision tests cover configuration and AABB validation; allocation fault cleanup; gravity, ground/air acceleration, deceleration, speed clamp, facing stability; floor/ceiling/wall/platform sweeps at and beyond configured speed; floor contact and 600-tick resting stability; platform landing, underside collision, walk-off, and support clearing; grounded, coyote, and buffered jump acceptance/consumption; exact timer boundary success/failure; held-input non-repetition; tap/hold apex separation; release after apex; impact capture and landing-event uniqueness; reset while grounded, rising, falling, buffered, and transitioning; interpolation independence; one animator update per fixed physics tick; and full 600-frame scripted-route completion. Tests use `1e-4 m`/`1e-4 m/s` for controller comparisons because this is the documented contact tolerance and remains far below one presentation pixel at 82 pixels per metre.

Prompt 6 adds 20 behavioral tests. Spring cases cover invalid and non-finite configuration/state, exact rest, signed displacement and velocity recovery, impulse/clamp behavior, 2,400-tick convergence, 24,000-tick stress, repeated-run determinism, and reset replay. Landing cases cover the resting-contact threshold, exact threshold, monotonic nominal/maximum response, above-maximum clamping, harder-impact peak ordering, one-event consumption, no-event wall/ceiling equivalents, reset, and the combined `[-0.060, +0.045] m` visual-root guard. Walk cases cover zero/partial/full/negative/above-full speed, alternating contact phases, blend in/out, airborne suppression, and exact neutral output after 1, 10, and 1,000 cycles. Secondary cases cover acceleration direction, bounds, settling, reset/teleport synchronization, disable, independent character state, one-time pose composition, and zero allocation metrics.

The mandatory anti-cheating test executes the same 600-frame raw scripted input twice through `CharacterIntent`, controller, animation, procedural motion, and pose: once enabled and once disabled. It compares final physics position and velocity within `1e-5`, then requires exact grounded state, supporting collider ID, and landing-event count. A separate fixed-tick trace is grouped as one-tick frames, four-tick frames, and mixed zero/one/multi-tick frames; landing, walk, and secondary states agree within `1e-5`.

Prompt 7 adds 17 behavioral tests. Entity tests cover deterministic monotonic `u32` generation, zero rejection, duplicate rejection, registry capacity, maximum-value issuance, and overflow. Ownership tests cover distinct poses, animator scratch/event storage, procedural state, optional controller state, facing, overrides, isolated reset, whole-scene reset, safe instance teardown, and five genuine second-character fault stages with successful retry. Ordering tests cover both actor directions, equal-layer entity-ID stability, cross-character interleaving, both hand directions, forearm-over-torso partial interleaving, per-component override precedence, exact restoration, invalid targets and values, eight-slot overflow, and handle overflow. Facing tests cover right/left hand and foot sockets through rotated ancestors, anatomical preservation, default-layer role reversal, negative-scale decomposition, collision invariance, and a double mirror. Batching tests require exactly 30 page-zero sprites and one range, including empty global input.

Prompt 8 adds 18 behavioral tests (bringing the aggregate Zig count from 104 to 122). Definition cases cover participant count, role clip/state validation, paired duration, paired event presence/order/time, finite envelopes, legal lifecycle edges, exact authored tick conversion, and checked interaction-ID overflow. Eligibility cases cover invalid/duplicate IDs, both lock directions, passive/controller grounding, disallowed airborne states, inclusive minimum/maximum/vertical boundaries and just-outside values, all facing failures, candidate alignment/distance/ID ranking, and container-order independence. Input cases cover zero-substep preservation, one-time multi-step consumption, held-button non-restart, and release/new-press restart. Startup cases inject failure after A/B reservation and A/B transition, fill all four slots, and exhaust contact override capacity. Runtime cases require exact shared start/contact/release/complete ticks, one semantic event each despite paired clip copies, synchronized normalized time, owned-only layering cleanup, unrelated override survival, before/after-contact cancellation, reset/single-step behavior, mirrored equivalence, AB/CD isolation, and regular/large/mixed render-group agreement. The controller-invariance test compares position, velocity, grounding, and support with interaction disabled/enabled.

Prompt 9 adds 22 behavioral tests, bringing the aggregate count from 122 to 144. Synthetic solver cases cover valid and rejected inputs, zero-distance fallback, straight/interior/diagonal geometry, exact safe boundaries, near/far clamping, opposite bends, mirrored targets, near-extension continuity, moving targets, and repeated bit determinism. Binding and application cases cover stable valid indices, invalid bones/sockets/parents, immutable `0.65/0.80 m` lengths, weights zero/half/one, shortest-angle wrap, unreachable world targets, and fixed roots. Paired cases cover symmetric target order, A-then-B versus B-then-A, fixed-tick weight samples, nominal and perturbed convergence, mirrored anatomy, zero/one/multi-substep grouping, IK-disabled/enabled timing and controlled physics agreement, cancellation in four phases, completion, scene and participant reset, unrelated reset isolation, and simultaneous pair cancellation/completion isolation.

Prompt 10 adds 24 behavioral tests, bringing the aggregate count from 144 to 168. Ground-query cases cover floor/platform/no-hit, exact range/surface inclusion, just-beyond rejection, slight height, origin below/inside, overlapping tops and stable ID ties, platform edges, ineligible walls/ceilings, and invalid numeric input. Binding/application cases cover both anatomical chains, invalid hip/knee/ankle/socket, immutable `0.900000/0.919239 m` lengths, zero/full weight, mirrored forward knee bend, no stretch, near/far conflict release, and left/right solve-order equivalence. Plant cases cover valid/no-ground/airborne/out-of-range contact, transition-start blending, pending reach-safe acquisition, fixed locks, repeated contacts, left/right jump release and fresh acquisition, reset, foot/character isolation, floor/platform fresh height, edge rejection, slip reduction, penetration/hover bounds, enabled/disabled controller and animator invariance, regular/large/mixed render schedules, arm-chain coexistence, handshake timeline/lock coexistence, and the complete scripted floor-to-platform route.

The mandatory Prompt 7 physics test replays the unchanged 600-frame scripted controller sequence twice: once with the controlled character alone and once with a passive independently updated second character sharing the immutable definitions. Final position and velocity agree within `1e-5`; grounded state, supporting collider, and five landing events agree exactly. A separate order-only trace changes actor, interaction, and body layers while comparing animation time, local pose, walk bounce, landing spring, secondary spring, and an untouched controller state.

## Floating-point tolerances

Exact floating-point equality is used only for values defined by exact assignment or discrete state. Numerical assertions use the smallest tolerance appropriate to the subsystem:

| Measurement | Tolerance | Rationale |
| --- | --- | --- |
| Basic vector/matrix identities near unit scale | absolute `1e-5` | Covers normal f32 rounding across several operations without hiding a visible transform error |
| Angle interpolation | absolute `1e-5` radians | Covers wrap/interpolation rounding and is far below a visible angular difference |
| Collision contact position | absolute `1e-4` m | One tenth of a millimetre is above accumulated f32 contact arithmetic noise and below gameplay-visible penetration |
| IK endpoint in an analytically reachable case | absolute `1e-4` m | Allows transform-chain rounding while still detecting an incorrect solve |
| Handshake full-weight target error | absolute `2e-4` m per hand | Bounds transform-chain rounding while requiring both sockets to converge on the same frozen target |
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
- The Prompt 8 handshake remains available as the synchronized authored baseline; the Prompt 9 route separately proves nominal, mirrored, and meaningfully perturbed shared-target convergence without root correction.
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
- Stable 60 displayed frames per second on the documented reference machine, with 240 Hz simulation and no sustained fixed-step overruns.

The reference GPU/CPU and measured percentile frame times will be added when performance testing begins; no unmeasured target is reported as passed.

Prompt 2's executable evidence run is `zig build run -- --frames 300`. Its final metrics must show 1,000 submitted/visible/sorted sprites, zero culled sprites, one range, one actual `SDL_DrawGPUIndexedPrimitives` call with 1,000 instances, 60,000 uploaded instance bytes, no post-stabilization CPU allocation, no GPU slot growth, and identical persistent-resource creation counts before the run, after warm-up, and after frame 300. Frame-slot waits are acceptable only when a reused slot's fence was observed unsignaled.

Prompt 3's executable evidence run is `zig build run -- --frames 300 --demo humanoid`. It must report 16 bones, four sockets, 15 attachments and humanoid sprite instances, one texture-page range, one actual draw, zero pose/socket/submission allocation after initialization, and zero GPU-resource creation from pose changes. Frame 0 and modified-pose logs must show different right-hand and left-foot socket positions resulting from actual ancestor rotations.

Prompt 4's executable evidence run is `zig build run -- --frames 360 --demo animation`. It must report eight clips/states, the two idle/walk transitions, bounded foot-contact logs, 15 humanoid instances, one texture-page range, one actual draw, unchanged character-world root, and zero measured sampling/blending/event/update/pose/submission allocation or animation-created GPU resources. Logged idle and walk socket positions must differ through actual ancestor tracks.

Prompt 5's executable evidence run is `zig build run -- --frames 600 --demo controller --scripted-input`. It must complete 2,400 physics ticks and exactly 2,400 animator ticks; exercise ceiling, both raised platforms, coyote jump, buffered jump, wall, and stable final ground; submit 15 humanoid sprites plus five collider sprites as one page-zero range and one indexed-instanced draw; report bounded clock/discard metrics; and report zero clock/input/intent/controller/collision/animation-selection/animator/interpolation allocations plus zero GPU resources created by movement. Incomplete scripted milestones cause a nonzero exit.

Prompt 6's executable evidence run is `zig build run -- --frames 900 --demo secondary-motion --scripted-input`. Its raw-input prelude demonstrates idle, partial-speed and full-speed walk, alternating contact semantics, acceleration-driven head lag, settling, and a reset edge. It then delegates to the unchanged Prompt 5 route for jump, platform fall, five measured landings, coyote/buffered behavior, and stable idle. The run exits nonzero unless at least two impact speeds differ, the harder impact has greater measured compression, partial/full amplitudes differ, spring residuals settle, the route completes, steady-state allocations remain zero, and procedural motion creates no GPU resources.

Prompt 7's executable evidence run is `zig build run -- --frames 720 --demo multi-character`. It must log all nine resolved-order phases, shared immutable definition tokens, distinct pose/animator/procedural storage, independent animation/procedural samples, reflected socket positions, exact default restoration, 30 humanoid sprites, one texture page, one range, one actual draw, unchanged fixed-buffer usage, zero hot-path counters, and zero GPU-resource creation from facing or ordering.

Prompt 10's executable evidence run is `zig build run -- --frames 1200 --demo foot-planting --scripted-input`. It must record both contact/plant ticks, collider IDs and immutable targets, stable-plant slip/penetration/hover below `0.0002 m`, floor and `1.15 m` raised-platform pre/post error reduction, jump lock clearing, zero false airborne plants, fresh post-landing acquisition, exact enabled/disabled physics and animator timing, 15 humanoid plus five collider sprites, one page/range/draw, zero hot-path allocation, and zero foot-created GPU resources. Missing evidence is a nonzero exit.

Prompt 11 originally added 11 deterministic integration tests. They cover a 32-entry diagnostic ring's overwrite order, 256-command debug overflow, debug-off/on authoritative equivalence, never-read/read-every-tick diagnostics equivalence, repeated non-destructive getters, landing-event single delivery, animation-contact physics invariance, pre-arm-IK target freezing, final hierarchy evaluation, reset during plant/airborne/pre-contact/contact, character-local isolation and interaction-peer release, three render grouping schedules, sequential complete handshakes, and a repeated integrated route. The final adversarial audit strengthens those same cases to 1,000 handshakes and 100,000 fixed ticks. The long route executes at least 30 complete walk/jump/platform/handshake/cleanup cycles, checks finite controller, spring, and foot state on every tick, rejects airborne locks, bounds slip to `0.0002 m`, and ends with zero allocation/resource growth and no stale interaction, override, or IK state.

Prompt 12 adds four focused regression tests, bringing the aggregate Zig count from 179 to 183. They cover deterministic lowest-ID support and sweep-face selection under collider-array permutation; an exact wall/floor diagonal corner at maximum run/fall speeds, including stable rest and epsilon-height support; exact requested/executed/discarded time under sustained 20 FPS overload plus an alternating zero/eight-substep schedule; and four-character state isolation with deliberately different animation, spring, facing, layer, foot-lock, and interaction-lock state. Existing tests were also strengthened for 20 zero-substep input frames, eight-substep one-shot edge consumption, pending-edge reset, coherent foot lifecycle chronology across repeated semantic contacts, comparator law checks at signed integer extremes, the 1,000-cycle interaction run, and the 100,000-tick integrated stress run.

Prompt 13 adds ten grouped deterministic tests, bringing the aggregate count from 183 to 193. They cover every keyboard alternative and neutral opposite-key combination; Space/E/R/F1/Escape/window-close transition edges, held-state repeat rejection, and keyboard/gamepad deduplication; focus loss, release reconciliation, held-key suppression, and phantom-free regain; 20 zero-substep frames plus press/release coalescing and eight-tick single consumption; real controller movement, deceleration, facing, and opposing-input rest; measured short/held jump apex ordering; identical raw-key controller outcomes under one-tick and four-tick render grouping; real interaction completion, held-E non-restart, release/new-press restart, and world-aware reset cleanup; authoritative F1 invariance; and the complete 1,800-frame raw-key playground route without a window or GPU.

Prompt 13's GPU-backed evidence run is:

```text
zig build run -- --frames 1800 --demo playground --scripted-input
```

It must demonstrate idle, left and right movement, release deceleration, opposing-key neutrality, measured short and held jumps, landing, debug on/off, controller-driven approach, exactly one E request and handshake completion while E stays held, one R reset, and a stable initial final state. It reports two characters, five environment colliders, 35 ordinary sprites, one texture page/range/actual draw, zero input-created GPU resources, and zero steady-state mapping/intent/playground allocation growth. Missing milestones or cleanup evidence returns nonzero.

Prompt 11's GPU-backed evidence run is:

```text
zig build run -- --frames 2400 --demo integrated --scripted-input
```

It must execute exactly 9,600 fixed ticks, complete all 16 asserted milestones, use two humanoids and the real controller/interaction/IK/foot systems, preserve 35 ordinary sprites in one texture range and one actual draw, report zero steady-state allocation and GPU-resource delta, and end grounded with no active interaction, participant lock, interaction-owned override, arm constraint, or airborne foot lock. `--debug-visualization` runs the same route with the bounded debug overlay; authoritative milestone and final-state tests prove equivalence, and the compatible overlay remains inside the one actual draw.

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
