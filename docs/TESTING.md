# Testing Strategy

## Documentation contract audit

Prompt 25E introduced a bounded PowerShell audit for the consolidated project,
prompt-history, decision, and report trees. The audited live documentation now
records implementation through Prompt 27:

```powershell
& '.\tools\check_documentation.ps1'
```

It verifies required files, local Markdown targets, prompt navigation, report links, and practical orphan detection. Verbatim historical report files are excluded from link lint because their original local evidence paths are intentionally preserved rather than rewritten.

## Current aggregate status through Prompt 27C-R1

The Prompt 27C-R1 aggregate gate passes 389/389 tests in Debug. The focused
visual-geometry gate passes 158/158 checks and the focused
visual-foundation gate passes 31/31.
Prompt 27B's semantic report contains 9,714 metrics with zero failures; each
final D3D12 review package contains 55 independent pixel metrics with zero
failures. ReleaseSafe, ReleaseFast, repository audit, D3D12/DXIL GPU smoke,
the preserved Prompt 27A 16-case evidence route, the four Prompt 27B
supplemental captures, 47/47 byte-identical R1 D3D artifacts, and review-image
repeatability pass. Current
milestone-specific commands and their evidence boundaries are documented
below.

The aggregate commands remain:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test -j1
& '.\.deps\zig-0.16.0\zig.exe' build check -j1
& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1
& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1
```

Historical declaration counts in the Prompt 20–25 sections are
milestone-time evidence, not the current total.

## Prompt 25D focused visual geometry

`zig build test-visual-geometry -j1` is the fast character-art iteration gate.
It validates metadata, visible alpha bounds, the shared production transform,
semantic side identity, registration, directional axes, fit, coverage,
pixel-space joint continuity, profile proportions, front symmetry, the pose
matrix, and male/female morphology variation without creating a window or GPU
device. Controlled aligned/backwards, correctly sized/undersized, invalid
coverage, and over-limit distal/knee/root continuity fixtures prove that the
instrument neither accepts every input nor fails every input.

The final Prompt 25D gate retains 158 focused production checks (above the
required 129 baseline) and a separate 6,354-check pose/morphology sweep.
Locomotion, compression, rise, fall, and landing are evaluated in both side
facings; global-build and channel sweeps reset their authoritative state before
the motion matrix so the declared matrices cannot leak state into each other.

`zig build visual-geometry-report -j1` evaluates the current production
acceptance matrix and writes human-readable and JSON reports under
`zig-out/p25d_visual_geometry`. Exit code zero means every emitted production
metric passed and `failure_count = 0`. The frozen `pre_correction_report.*`
files retain the Prompt 25B-derived failure evidence.

The clean D3D12 capture uses:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
.\zig-out\bin\skeletal_gpu_demo.exe --frames 600 --demo visual-quality --scripted-input
```

The corresponding geometry overlay uses the identical character, production
submission, global queue, shaders, D3D12 backend, and readback:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
.\zig-out\bin\skeletal_gpu_demo.exe --frames 600 --demo visual-quality --scripted-input --debug-visualization
```

Golden hashing is a final change-detection layer only. After quantitative and
human acceptance, the approved D3D12/DXIL PPMs are verified with:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build check-p25d-goldens -j1
& '.\tools\check_p25d_goldens.ps1' -CompareLatest
```

The second command proves that the latest real-GPU readbacks equal the stored
approved captures. Prompt 25B captures remain unapproved.

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
- The Prompt 19 mixed route visibly interleaves a cape, body sprites, topology-expanded sleeves, fitted torso garment, and rigid clasp according to authored integer layers. The two-arm and four-arm characters must show two and four distinct sleeve instances, mirrored facing, build/breathing response, and deterministic cape removal/restoration.
- Drag the visible window through wide, tall, and square aspect ratios. Character size must remain constant while larger drawable dimensions reveal more world.
- Minimize and restore repeatedly, including on a high-DPI display when available. A zero drawable must skip safely, restoration must resume, and no unrelated persistent GPU resource count may change.
- Walk far left in the playground. The camera must follow without moving the physics root, and distant cave, midground pillars, and gameplay geometry must show clearly different horizontal response.

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

Prompt 11 originally added 11 deterministic integration tests. They cover a 32-entry diagnostic ring's overwrite order, fixed-capacity debug overflow (512 commands after Prompt 25C), debug-off/on authoritative equivalence, never-read/read-every-tick diagnostics equivalence, repeated non-destructive getters, landing-event single delivery, animation-contact physics invariance, pre-arm-IK target freezing, final hierarchy evaluation, reset during plant/airborne/pre-contact/contact, character-local isolation and interaction-peer release, three render grouping schedules, sequential complete handshakes, and a repeated integrated route. The final adversarial audit strengthens those same cases to 1,000 handshakes and 100,000 fixed ticks. The long route executes at least 30 complete walk/jump/platform/handshake/cleanup cycles, checks finite controller, spring, and foot state on every tick, rejects airborne locks, bounds slip to `0.0002 m`, and ends with zero allocation/resource growth and no stale interaction, override, or IK state.

Prompt 12 adds four focused regression tests, bringing the aggregate Zig count from 179 to 183. They cover deterministic lowest-ID support and sweep-face selection under collider-array permutation; an exact wall/floor diagonal corner at maximum run/fall speeds, including stable rest and epsilon-height support; exact requested/executed/discarded time under sustained 20 FPS overload plus an alternating zero/eight-substep schedule; and four-character state isolation with deliberately different animation, spring, facing, layer, foot-lock, and interaction-lock state. Existing tests were also strengthened for 20 zero-substep input frames, eight-substep one-shot edge consumption, pending-edge reset, coherent foot lifecycle chronology across repeated semantic contacts, comparator law checks at signed integer extremes, the 1,000-cycle interaction run, and the 100,000-tick integrated stress run.

Prompt 13 adds ten grouped deterministic tests, bringing the aggregate count from 183 to 193. They cover every keyboard alternative and neutral opposite-key combination; Space/E/R/F1/Escape/window-close transition edges, held-state repeat rejection, and keyboard/gamepad deduplication; focus loss, release reconciliation, held-key suppression, and phantom-free regain; 20 zero-substep frames plus press/release coalescing and eight-tick single consumption; real controller movement, deceleration, facing, and opposing-input rest; measured short/held jump apex ordering; identical raw-key controller outcomes under one-tick and four-tick render grouping; real interaction completion, held-E non-restart, release/new-press restart, and world-aware reset cleanup; authoritative F1 invariance; and the complete 1,800-frame raw-key playground route without a window or GPU.

Prompt 13's GPU-backed evidence run is:

```text
zig build run -- --frames 1800 --demo playground --scripted-input
```

It must demonstrate idle, left and right movement, release deceleration, opposing-key neutrality, measured short and held jumps, landing, debug on/off, controller-driven approach, exactly one E request and handshake completion while E stays held, one R reset, and a stable initial final state. It reports two characters, five environment colliders, 14 cave-layer sprites, 49 ordinary sprites, one texture page/range/actual draw, zero input-created GPU resources, and zero steady-state mapping/intent/playground allocation growth. Missing milestones or cleanup evidence returns nonzero.

Prompt 14 adds 12 grouped deterministic tests, bringing the aggregate count from 193 to 205. Pure camera cases cover the original 640×480 mapping, known offsets, positive-Y-up clip behavior, 640×480 plus 1280×720 and 800×800 viewports, nonzero finite validation, transactional zero-size rejection, exact 16-byte uniform values, hand-derived parallax displacement, and bit-deterministic repeated dead-zone updates. Integration cases prove resize changes presentation without changing controller state, camera following cannot change a 720-tick physics replay, the playground keeps both raised platforms while extending its floor to `[-32, 32] m`, cave submissions contain distinct distant/midground/gameplay factors in world metres, and the bounded raw-input route crosses more than 20 metres deterministically.

Prompt 14's bounded GPU-backed route is:

```text
zig build run -- --frames 1100 --demo side-scroller --scripted-input
```

It drives the real mapped `A` input through the 240 Hz controller into the extended-left world, traverses from `-3.15 m` past `-24 m`, and lets the character decelerate. The route must report at least 12 metres of deterministic camera-center travel, distant factor `0.125`, midground factor `0.45`, gameplay factor `1.0`, one texture page/range/actual draw, zero steady-state allocations, zero unrelated GPU-resource creation, and current drawable pixel dimensions. Failure to travel, follow, render, or cleanly settle returns nonzero. The fixed `zig build gpu-smoke` route remains 640×480 and verifies the same shader contract through deterministic readback independently of visible-window resizing.

Prompt 15 adds eight grouped deterministic tests, bringing the aggregate Zig count from 205 to 213. They prove the canonical 16-bone rig, rest transforms, semantics, and four sockets remain unchanged while a definition adds custom attachment-point, region, group, visual, module, joint, and socket IDs. They cover zero and extended visual counts; multiple visuals sharing one point; visual-parent hierarchy; duplicate, dangling, self/cycle, and transactional cleanup failures; character-local visibility, deformation, and module pose with exact reset; mirrored point/module/child visuals; stable equal-layer input ordering; and 128 repeated appearance mutations/evaluations/submissions with no allocator movement after initialization.

Prompt 15 does not add a new renderer or GPU acceptance route. The existing humanoid, animation, multi-character, handshake, foot-planting, integrated, playground, side-scroller, and GPU-smoke routes exercise the unchanged canonical semantics and global sprite batch. The extended test definition is intentionally headless and uses abstract harmless visuals plus a two-joint module to prove Prompt 16 can add real modular anatomy without changing locomotion topology.

Prompt 16 adds ten grouped deterministic tests, bringing the aggregate Zig count from 213 to 223. They cover exact morphology interpolation at 0/50/100; channel and per-instance override precedence; invalid values/ranges; preset isolation and reset; conventional and repeated adult-module configurations; dangling parent and cycle rejection; independently addressable face features and three hair styles; two validated face groups using the same generic feature definition while resolving materially different visual transforms, sizes, tints, visibility, and independent character state; presentation switching with an unchanged topology fingerprint; explicit module-local articulation; unchanged controller, animation, interaction-owner, canonical rest, and IK length state; independent runtimes; repeated-run equality; and fixed-buffer zero-allocation updates.

The dedicated non-sexual GPU evidence route is:

```powershell
zig build run -- --frames 240 --demo modular-body
```

It renders conventional male, conventional female, and extra-arms/tail/horn presets through one shared skeleton, animation library, global sprite batch, texture page, and indexed-instanced draw. The first two characters render the visibly distinct `conventional_face` and `angular_face` definitions side by side through the same bounded anatomy-to-appearance path. It switches profiles and hair deterministically and requires zero fixed-buffer movement or GPU-resource creation after initialization.

Prompt 17 adds five grouped deterministic tests, bringing the aggregate Zig count from 223 to 228. They cover duplicate identifiers, missing slot and attribute references, and creation of future slot/attribute/capability IDs; the same garment resolving exactly two and four upper-arm instances; required, optional, specific, and maximum-bounded matching; transactional conflict rejection; layering, coverage, multi-slot replacement, unequip, and default reset; grant removal; independent character loadouts; definition-sorted visuals and effects under different equip request orders; fixed-buffer zero-allocation equip/unequip/rebind; unchanged canonical hand sockets; and inherited facing reflection. The complete pre-existing handshake and analytical IK suites remain in `test_all.zig` and regression-protect interaction timing, socket measurement, target freezing, limb overrides, and visual-pose-only authority.

The dedicated Prompt 17 GPU evidence route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo equipment
```

It must report the same sweatshirt definition, exactly two conventional sleeves and four nonstandard sleeves, transactional conflict rejection, multi-slot replacement, unequip/restoration, independent loadouts, deterministic modifier/capability listings, two characters, one texture page/range/actual indexed-instanced draw, unchanged fixed-buffer usage, zero post-stabilization batch allocation, and zero equipment-created GPU resources. Missing evidence returns nonzero.

Prompt 18 adds eight grouped deterministic tests, bringing the aggregate Zig count from 228 to 236. Coverage lives in `tests/deformation_tests.zig` and separately checks breathing neutral/extreme samples, repeated bounded cycles, reset, independent character rate/phase, body/clothing agreement, exact topology-expanded sleeve drivers, per-part isolation, rigid response, global morph composition, equip/unequip at non-neutral phase, physics/controller/canonical-IK/effect invariance, handshake timing, render-frame grouping, and fixed-buffer allocation stability.

The bounded Prompt 18 GPU-backed breathing/clothing evidence route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo breathing
```

It represents 960 authoritative ticks per character, requires observable restrained torso motion and clothing agreement, validates one sweatshirt across four independent arms, and fails on allocation growth, GPU-resource creation, alternate draw ranges, or gameplay-state drift.

Prompt 19 adds seven grouped deterministic tests, bringing the aggregate Zig count from 236 to 243. Coverage lives in `tests/mesh_attachment_tests.zig` and checks finite/UV/topology/index/degenerate/capacity validation; immutable definition and persistent topology-catalog ownership; partial allocation cleanup; exact CPU/HLSL record sizes; bounded weighted deformation; one semantic sprite/mesh ordering stream; compatible mesh instancing; topology-expanded two/four-sleeve binding; distinct repeated and cross-character mutable state; mirrored facing; equip/unequip; deterministic queue capacity failures; and zero fixed-buffer movement after stabilization.

The bounded Prompt 19 GPU-backed mixed-primitive evidence route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo mesh-attachments
```

It requires two segmented characters, body sprites, fitted garments, six topology-expanded sleeve meshes, two cape meshes, rigid clasps, separately measured build and breathing deformation, mirrored facing, cape unequip/re-equip, real mesh shader/indexed-instanced execution, separate honest sprite/mesh range/draw/upload metrics, persistent topology resources, three bounded dynamic frame slots, and zero CPU/GPU resource growth after stabilization. A linked-build or GPU failure remains a failure; pure tests and shader compilation do not substitute for that evidence.

Prompt 20 adds six grouped deterministic tests in `tests/attachment_secondary_motion_tests.zig`; the repository contains 249 top-level Zig test declarations after this change. Coverage includes definition/finite/stability validation; exact rest; acceleration, sustained motion, reversal, sudden stop, jump, fall, and landing direction; facing reset and reset replay; extreme valid parameters; 24,000-tick convergence; deterministic repeated runs; independent states sharing one immutable definition; long-hair/ponytail and cape ownership across two characters; flexible topology-expanded repeated instances; equip/unequip/re-equip cleanup; grouped unified rendering; controller/physics and interaction invariance; the complete 240-frame headless evidence script; and fixed-buffer/resource stability.

The bounded Prompt 20 GPU-backed route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo attachment-secondary
```

It reuses the Prompt 19 topology catalog, unified queue, mesh shader, and persistent buffers. Success additionally requires cape acceleration/sustained/reversal/stop/jump/fall/landing evidence, moved long hair and ponytail, independent repeated flexible-sleeve state, cleared unequip state, exact re-equip rest, exact facing-change rest, zero steady-state fixed-buffer or queue allocation growth, and zero spring-caused GPU-resource creation.

Prompt 21 adds seven grouped deterministic tests in `tests/character_properties_tests.zig` and extends the existing input tests; the repository contains 257 top-level Zig test declarations after this change. Coverage includes attribute definition/range/base validation; additive and multiplicative modifier validation and combinations; deterministic source-key sorting; clamping; base overrides; capability defaults and independent source counts; duplicate-source rejection; removing one of two grants; character isolation; equipment gain/loss/replace/reset; two-item attribute stacking; carrying capacity, armor, and damage-reduction queries; appearance independence; movement-speed and jump-strength controller consumption; denied/allowed/exhausted double jump; airborne removal; denied/allowed dash; facing and active-removal behavior; wall collision; exact default-controller regression; and zero property-resolution allocation.

The bounded Prompt 21 GPU-backed route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo properties
```

It executes real controller behavior for default and modified movement, default and stronger jump, double-jump denial/grant, dash denial/grant, and dash wall collision. It directly verifies carry, armor, damage reduction, duplicate-grant removal, restoration, and independent characters, then renders both characters through one range and one indexed-instanced draw. Missing evidence, allocation growth, or GPU-resource growth returns nonzero.

Prompt 22 adds four grouped deterministic tests in `tests/foundation_playground_tests.zig`, bringing the repository to 261 top-level Zig test declarations. The focused command is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-foundation
```

Coverage includes the complete 1,800-frame raw-input route; left/right traversal, camera follow, three-layer parallax, short and stronger held jumps, body/build/hair changes, topology rebind, speed/jump loadouts, double jump, dash, landing, breathing, cape/sleeve response, approach, one handshake contact/release/completion, two synthetic viewport changes, exact loadout restoration, reset, and stable final state. Separate cases compare gameplay/loadout/pending edges across viewport changes, mutate then verify the complete reset baseline, and exercise deterministic bounded unified sprite/mesh ordering with debug primitives.

Prompt 27 supersedes the old procedural GPU composition while preserving the
Prompt 22 route as the focused `test-foundation` regression. The current
GPU-backed acceptance route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 2400 --demo foundation --scripted-input
```

The current route requires Direct3D 12/DXIL, two persistent garment mesh
definitions, two production-art characters, eight static colliders, actual
controller property consumption, canonical handshake IK/foot planting, exact
reset, zero fixed-buffer update/submission growth, zero unified-queue
allocation after stabilization, and zero GPU-resource creation after
scene/topology initialization. It reports actual sprite/mesh instance, range,
draw, and upload peaks. The interactive companion is
`zig build run -- --demo foundation --interactive`.

Resize verification is split deliberately: pure tests use synthetic nonzero viewports and compare authoritative state plus pending edge counts exactly; the SDL route feeds real resize/pixel-size/restore events through drawable-size refresh and the same camera setter. Neither form claims physical manual resizing unless it was actually performed.

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
## Prompt 23 art-pipeline verification

`zig build test-art` runs ten focused tests split between platform-independent definition/render routing and Windows WIC decode behavior. Coverage includes page definitions and per-page nearest/linear policy; duplicate page and region IDs/names; exact normalized UV derivation; atlas bounds and arithmetic overflow; invalid pivots; missing page and region references; duplicate or conflicting semantic bindings; fixed-buffer allocation failure; synthetic view 37; declaration reorder stability; two-page unified ranges; deformable-mesh material compatibility; alpha-bearing RGBA decode; missing/corrupt/unsupported image errors; image metadata bounds; and zero post-stabilization queue allocation.

The GPU-backed command is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo art-assets --frames 240
```

It requires D3D12/DXIL and the installed asset layout. Startup runs GPU fault-cleanup cases, then uploads both real pages and renders six PNG-backed sprites plus one mesh. Runtime assertions require both nearest-sampled pages, six sprite ranges/draws plus one mesh range/draw, exact decode counts, no retained CPU images, no steady-state fixed-buffer or queue allocation, and no steady-state GPU-resource creation. A successful bounded run is GPU execution evidence; it is not a claim of subjective manual art review.

## Prompt 24 character-presentation verification

Run the focused platform-independent suite:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation
```

It covers the complete automatic view policy; override/interaction precedence and cleanup; facing and root invariance; reset; single-root side reflection; non-reflected front projection; both-view region completeness; bald, buzz-cut, and long-hair resolution; explicit front semantic layers; interaction cancellation; deterministic spring reset; allocation-free view changes; two-character isolation; `Q` input; and bounded submission on both views. Prompt 24A additionally resolves every canonical male/female side/front base region with no garment, proves torso and vest semantic/region IDs differ while their real production page is shared, removes and re-resolves the optional garment without changing the base result, and asserts zero fixed-buffer growth across repeated resolution. Aggregate `zig build test` retains the existing deformation, IK, foot-planting, interaction, controller, and reset regression suites.

The GPU-backed acceptance route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo character-presentation --scripted-input --frames 360
```

The route executes exactly 1,440 fixed ticks. Its runtime evidence must include front idle, left and right side movement, preserved left facing while front, jump/rise/fall/land, bald/buzz switching, female front/side states, breathing, long-hair displacement, both debug overrides, side-view handshake ownership, completion cleanup, and return to front. Prompt 24A startup also validates the anatomy/clothing boundary over the actual page bindings and logs the distinct male/female front torso and vest region IDs. The final two-character frame must retain three real art pages, 68 regions, 96 bindings, bounded texture-page ranges/draws, no update/submission/queue allocation after stabilization, and no steady-state GPU-resource delta.

Manual visual acceptance is separate from the automated verdict. Inspect both source atlases at native resolution and run the interactive route to check coherent silhouettes, face readability, hair shape, consistent lighting/scale, shoulder/elbow/wrist/hip/knee/ankle/neck overlaps, front semantic ordering, movement articulation, breathing, hair response, view transitions, and handshake contact. For Prompt 24A, inspect male/female front and side captures from the live D3D12 window and confirm bare neutral limbs/feet, featureless torso/pelvis base-presentation surfaces, and preserved joints/overlaps. Automated success proves routing and invariants but cannot by itself prove subjective joint/art quality.

## Prompt 25 wardrobe verification

Run:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo wardrobe --scripted-input --frames 600
```

The focused suite validates all item/preset/component IDs, complete and distinct paired side/front art, deterministic lookup, duplicate/conflicting slots, independent occupancy/layer/coverage, blouse-plus-cardigan composition, reuse across presets, custom recombination, zero cosmetic effects, two/four-arm sleeve expansion, bilateral semantic-foot binding, invariant foot matrices, hair/headwear coexistence, transaction state preservation and rollback, two-character isolation, long-mesh and secondary-state cleanup, reset, focus-safe O/P edges, both-view queue submission, and fixed-buffer stability after initialization. The `0.000001` matrix/controller tolerances isolate unintended state mutation while allowing normal `f32` representation; selection performs no arithmetic expected to exceed this bound.

The D3D12 route must report:

- `direct3d12` selected and DXIL agreement;
- six decoded production art pages and two persistent skirt mesh definitions;
- 15 presets, 30 items, 36 components, 72 wardrobe regions, and 72 bindings;
- every preset observed in front and side, including both mandatory outfits;
- custom recombination, headwear/hair, long mesh/secondary motion, legwear, footwear, breathing, locomotion, jump, land, and unchanged male evidence;
- zero update, submission, queue, and hot-swap GPU-resource growth after initialization.

Manual visual acceptance inspects every preset in both views through the real D3D12 window. Confirm torso pieces are centered on anatomy rather than the head, sleeves bind each visible arm, lower pieces remain independently composed, the split skirt deforms below the pelvis, headwear and long hair coexist, shoes remain on planted feet, the base-only preset reveals intact neutral anatomy, and the custom outfit visibly layers blouse below cardigan. Sequential window captures are acceptable evidence of the real route; they do not count as physical input testing.

## Prompt 25A visual-quality gate

Run the non-interactive hard gate only through its exact route:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\skeletal_gpu_demo.exe' --frames 600 --demo visual-quality --scripted-input
```

The route writes eleven P6 images from the same prepared 640 by 480 global queue
used by D3D12, using one persistent pre-checkpoint transfer buffer. It requires
base male/female front and side; representative male/female wardrobe front and
side; `wide_brim_crimson`; `ivory_blouse_red_shorts`; the recombined ivory
blouse plus crimson cardigan in both views; stride; jump rise; and jump fall.
It rejects an incorrect frame count or non-scripted invocation.

Focused Prompt 25A coverage extends `test-presentation` and `test-wardrobe` with
exact production page dimensions/paths, nonzero in-bounds regions, audited
alpha-tight shoe/sleeve extraction, side and front joint geometry, semantic
shoe pivot/offset, and a 600-frame fixed-buffer acceptance schedule. These tests
remain necessary but do not replace pixel judgment.

`VISUAL_ACCEPTANCE_25A.md` contains the nineteen-item checklist for every final
capture, concrete observations, normal and nearest-neighbor 2x review, and the
before/after evidence. `PROMPT25A_DECISION_RECORD.md` records the root causes,
rejected iterations, image-generation provenance, architecture decisions, and
minor remaining visual limitations. This scripted/GPU evidence does not claim
physical keyboard input or manual window resizing.

## Prompt 25B character-art gate

Run the two focused suites and the real-art alpha audit before the aggregate
regression:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation
& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe
& '.\tools\audit_p25b_art.ps1'
```

The art audit opens the production component PNG and both production base
pages. It checks all 28 corrected pelvis/arm/hand/leg/foot regions plus the two
re-authored front torso regions for exact atlas bounds, visible alpha, packing
margin, unique source rectangles where applicable, compact shoulder
silhouettes, and authored-to-alpha aspect ratio in the 0.82..1.20 band. Focused
tests additionally prove distinct forearm/shin UVs, rig-length and pivot
bounds, one authoritative-to-side root compression, deterministic front
anatomy mirroring, forearm-over-upper-arm elbow overlap, pelvis-behind-thigh
overlap, corrected female hand size, allocation-free submission, and the
existing anatomy/equipment ownership boundary.

The legacy bilateral-equipment regression proves only mirrored submission
metadata: two quads, opposite signed X scales, reflected pivots `0.05/0.95`,
equal absolute widths, and at least `0.35 m` center separation. It does not
prove heel/toe registration, forward direction, sole angle, fit, or visible
coverage. Prompt 25C preserves that test under the precise name "bilateral
footwear receives mirrored submission metadata" and adds the stronger semantic
and alpha-visible checks separately.

Visual acceptance uses the same Prompt 25A D3D12 route after rebuilding. The
accepted Prompt 25B hard-gate captures are retained under
`zig-out/p25b_followup_final`; the earlier comparison remains under
`zig-out/p25b_visual`. The
same-scale before/after review is
`zig-out/p25b_visual/prompt25a_vs_prompt25b_same_scale.png`. Inspect neutral
front/side first, then clothed front/side, stride, jump rise, and jump fall.
`PROMPT25B_DECISION_RECORD.md` records source identities, actual region
rectangles, causes, corrections, and remaining visual limits.

## Prompt 26 environment validation

Fast deterministic gate:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-environment -j1
```

The focused tests prove:

- exact two-page/two-theme art-pack completeness and missing-reference errors;
- absence of collision/spawn/interaction ownership in theme input;
- exact eligible-collider surface count, IDs, and endpoint coordinates;
- exclusion of walls, ceilings, and decorative non-collision ledges;
- terrain/surface/character/debug ordering in `UnifiedRenderQueue`;
- distinct preloaded page identity with no GPU/file owner in presentation;
- allocation-free repeated switching;
- preservation of controller, root, facing, view, outfit, interaction owner,
  fixed clock, pending input, camera, collision, and surface state;
- deterministic `T` edge and focus-loss filtering;
- scripted front/side, parallax, stationary in-place switching, jump and
  non-floor raised-platform landing, resize, reset, debug, allocation, and
  fixed-tick evidence.

Real D3D12 acceptance route:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo environment --scripted-input --frames 720
```

The route must preload eight art pages, retain nine configured renderer pages,
produce seven 640 by 480 captures in `zig-out/p26_environment_gpu`, report two
theme switches, six white standable segments, a recorded raised-platform
landing frame, unchanged collision/surface
fingerprints, zero post-initialization allocation/resource growth, and real
D3D12/DXIL rendering. Inspect neutral front, side/parallax, in-place debug
theme, switch-back, jump, raised-platform landing, and detailed collider
frames. White tops
must match floor/platform collision exactly and remain visually distinct from
cyan/orange detailed debug.

## Prompt 27 integrated visual foundation

Fast deterministic gate:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
```

The focused tests run a bounded 2,400-frame composition through production
character, wardrobe, environment, interaction, and mixed-queue paths. They
assert automatic front/side behavior, body/build/hair controls, idle and
moving outfit changes, short/full/double jumps, dash, raised-platform landing,
camera/parallax, both themes, six collision-derived white surfaces, three
fixed-root handshakes, exact presentation cleanup, viewport invariance, full
reset, bounded sprites/meshes/ranges, and zero queue allocation after
stabilization.

Each handshake record includes typed ID, participant entities, preset, theme,
requested role views, start/contact/release/complete ticks, pre/post-IK socket
separation, projected production-presentation hand separation, contact views,
body/equipment ordering proof, root invariance, and finite secondary state. The
required presets are `wide_brim_crimson`,
`garnet_formal`, and `ivory_blouse_red_shorts`. A separate validated synthetic
definition selects front/front, proving that side view is handshake data
rather than a manager constant.

## Prompt 27A evidence integrity

The same focused command now discovers 18 tests. In addition to the Prompt 27
composition checks, controlled fixtures prove that every major capture
predicate accepts its valid boundary and rejects minimally and clearly invalid
state. Coverage includes view/facing/velocity, rise/apex/fall, bilateral raised
landing contact, theme invariance, interaction approach/reach/contact/release
and cleanup, complete debug categories, interrupted holds, timeout, metadata,
commit order, duplicate render observations, and bounded allocation-free HUD
submission.

Real D3D12 route:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --scripted-input --frames 2400
& '.\.deps\zig-0.16.0\zig.exe' build p27a-review
```

It must preload eight art pages into nine configured renderer pages, decode
eight files during initialization only, upload two persistent garment meshes,
write exactly 16 state-conditioned 640 by 480 captures and JSON records under
`zig-out/p27a_evidence/candidate`, and report zero post-stabilization update,
submission, queue, and GPU-resource growth. The ordered matrix covers initial
idle, left walk, stopped/front/left, right walk, rise, apex, fall, raised
landing, theme switch, approach, reach, first contact, release, cleanup,
detailed debug, and reset.

`p27a-review` independently parses each PPM payload, verifies SHA-256 against
both metadata and manifest, rejects duplicate payloads and missing/mismatched
cases, checks semantic and resource metrics, converts to deterministic PNG,
and writes:

- `review_manifest.json`;
- `raw_metrics.json`;
- a complete matrix sheet;
- clean/static, locomotion/jump, interaction, and detailed-debug sheets.

The current required result is 16/16 captures and at least 263 raw metrics
with zero automated failures. Run the route and review package twice, then use
`tools/compare_p27a_repeats.ps1`; all PPM, metadata, PNG, state, and metric
results must match. These checks prove evidence integrity, not aesthetic
quality. Manual visual acceptance remains `[PENDING OWNER REVIEW]`.

## Prompt 27B contact, framing, parallax, and presence

Focused semantic tests:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --global-cache-dir '.zig-cache\p27b-global'
& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --global-cache-dir '.zig-cache\p27b-global'
```

The 28 focused tests retain all Prompt 27/27A integration and evidence tests,
then add controlled valid-boundary, minimally invalid, and clearly invalid
fixtures for:

- independent left/right socket and alpha-derived sole contact;
- wrong landmark and wrong footwear pivot;
- terrain/surface/character/debug semantic ordering;
- exact and clipped camera safe bounds plus resized determinism;
- direct 960×540-to-640×480 first-frame reprojection versus subsequent
  15.999 px valid and 16.001 px invalid world-camera steps;
- measured, zero-travel, and reversed parallax;
- ordinary and interaction participant overlap;
- stopped-root invariance, bounded controller steps, and teleport rejection;
- one complete 2,400-frame production route;
- simulation-equivalent outcomes under alternate render grouping.

`p27b-coherence-report` executes the same state-conditioned production route
headlessly and writes raw TXT/JSON measurements. The preserved historical
final Prompt 27B report recorded 9,714 metrics and zero failures at its
historical source-art hashes. It is not evidence that fresh current art
passes. The VF-01 pre-change fresh-current-art run records 9,714 metrics and
24 failures: the front-foot heel/toe endpoint-height observations differ by
`-13.645128 px` and `+13.645128 px` across the affected cases. Required
thresholds and rationales remain frozen in
[`PROMPT27B_DECISION_RECORD.md`](PROMPT27B_DECISION_RECORD.md). Important
historical final-Prompt-27B ranges were:

- canonical sole error: 14 required rows, all `0 px`;
- visual sole midpoint: all `0 px`;
- heel/toe endpoint error: `0..0.03 px` and `-0.03..0 px`;
- top/bottom clearance: `16..115.30 px` and `16..80.24 px`;
- camera vertical step: `0..15.57 px/render`, required at most `16`;
- abrupt first-post resize: `960×540 -> 640×480`, headroom `37.50 px`,
  footroom `36.77 px`, instantaneous reprojection world delta `0 px`;
- ordinary participant overlap: `0`;
- semantic camera travel: `10.93 m`;
- semantic adjacent parallax separation: `304.69 px` and `483.92 px`.

The VF-02 owner-review correction preserves both historical reports and reruns
the same fresh-current-art command without rebaselining. The corrected report
contains 9,752 metrics and zero failures. The former 24 endpoint failures were
caused by an independent exact `+/-78` degree wardrobe shoe rotation after
the anatomy foot had already registered. The front anatomy foot now uses one
`point_axis` contract: the ankle is its positional target and the authored
sole axis maps to a horizontal view-space support tangent. The shoe consumes
that exact target and the registered foot's full authored transverse scale.
Closed-footwear metadata suppresses covered base-foot pixels but preserves
their trace evidence. Front sole-back and sole-front are horizontal and all
24 formerly failing endpoint-height rows measure `0.0 px`. No endpoint
threshold, ruler, source art, camera, support surface, or baseline changed.

Real D3D12 route and independent readback review:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --scripted-input --frames 2400
& '.\.deps\zig-0.16.0\zig.exe' build p27b-review
```

The route retains the 16 Prompt 27A state-conditioned captures and adds:

- `07_camera_resize.ppm`;
- `08_abrupt_resize_first_post_debug.ppm`;
- `10_parallax_start_debug.ppm`;
- `11_parallax_finish_debug.ppm`.

`p27b-review` independently parses the real PPM pixels and produces 12 PNG
review frames, a labeled contact sheet, and raw JSON/TXT pixel metrics. The
preserved historical report contains 55 metrics and zero failures; it is
historical integrity evidence, not a current-art pass. The abrupt-resize
readback contains complete 49-pixel top/bottom markers, projection errors of
`0.50/0.23 px`, the unchanged 16 px semantic margins, and a maximum
subsequent world-camera step of `15.566496 px`. Measured
far/mid/gameplay displacement is `30/113/246 px`; camera-factor prediction
error is `0.48/0.16/0 px`; adjacent layer separation is `83/133 px`; safe
frame, projected surface, and heel/toe evidence are within `0.5 px`.

Run the semantic report twice and the D3D12 route/review in isolated output
roots twice. The accepted repeat comparison has zero mismatches across 38
production D3D artifacts and 15 review artifacts. The pre-change SHA-256
inventory covers 314 Prompt 27/27A evidence files; the final integrity audit
reports zero missing and zero changed files. Failed Prompt 27B development
candidates remain preserved.

These automated checks and the Codex visual inspection establish the declared
geometry/evidence contract. They do not approve aesthetics or promote
goldens. Owner/manual acceptance remains `[PENDING OWNER REVIEW]`.

## Prompt 27C production anatomy

Fast source and semantic gates:

```powershell
& '.\tools\audit_p27c_art.ps1'
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-geometry -j1
& '.\.deps\zig-0.16.0\zig.exe' build p27c-anatomy-report -j1 -- --output 'zig-out\p27c_evidence\final_semantic_report' --expect-pass
```

The source audit validates three exact-size RGBA pages, 28 nonempty component
regions, and preserved predecessor hashes. The focused gate contains 15 Zig
test declarations and 158 Prompt 27C controlled/production checks while
retaining the 6,354-check Prompt 25D pose/morphology sweep. Controlled
fixtures prove square/gapped/blob shoulders, oversized hands, overlong arms,
wrist pinches, floating/excessive pelvis transitions, knee beads, ankle gaps,
reversed feet, invalid toe-out, dark joint strips, incomplete matrices, and
nonfinite values fail.

The anatomy report runs 102 style/view/pose/morphology cases, records 2,450
production traces and 3,788 metrics, and requires zero failures. The frozen
pre-correction report under
`zig-out/p27c_evidence/pre_correction_head_3259f79` contains the same counts
and 817 failures. Two final semantic runs are byte-identical.

Real D3D12/DXIL evidence:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo anatomy-quality --scripted-input --frames 600
& '.\tools\build_p27c_review_package.ps1'
```

The state predicates produce eight 640×480 body-only captures covering
neutral front, side-right, side-left, low/high build, extended arm, bent
elbow, and deep knee bend. The ordinary `UnifiedRenderQueue` and SDL3 GPU
readback are used; post-initialization update, submission, queue, and GPU
resource growth are zero. The review tool validates the manifest and report,
converts deterministic PNGs, and produces before/after plus shoulder,
elbow/wrist, pelvis/hip, knee/ankle, and foot sheets. Two isolated nine-file
capture trees and two 18-file review trees are byte-identical.

Regression requirements retain:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
& '.\.deps\zig-0.16.0\zig.exe' build test -j1
& '.\.deps\zig-0.16.0\zig.exe' build check -j1
& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1
& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1
& '.\.deps\zig-0.16.0\zig.exe' build gpu-smoke -j1
```

The 28-test foundation gate keeps both incremental and direct resize
fixtures. The direct first frame remains instantaneous viewport reprojection;
subsequent world-camera movement retains the unchanged 16 px bound. All 314
historical Prompt 27/27A evidence files remain present and SHA-256 identical.
Prompt 27A, Prompt 27B, and Prompt 27C owner/manual visual acceptance remains
`[PENDING OWNER REVIEW]`; no Prompt 27C capture is an approved golden.

## Prompt 27C-R1 corrective torso and presence policy

Focused deterministic gates:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build audit-p27c-r1-torso -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-geometry -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
& '.\.deps\zig-0.16.0\zig.exe' build p27c-anatomy-report -j1 -- --output 'zig-out\p27c_r1_evidence\final_semantic_report' --expect-pass
```

The torso audit compares both complete production pages with the last
accepted Prompt 25A pages. It requires all 1,509 male and 1,234 female changed
pixels to remain inside four fixed shoulder rectangles and reports zero
unapproved page changes. Each torso must contain one alpha-connected
component and no transparent nonzero-RGB texel. Four controlled fixtures must
be rejected: transparent-white bilinear matte, mismatched directional mask,
detached geometry, and one outside-region pixel.

The foundation gate covers explicit `measure_only` and
`enforce_acceptance` policies. Its interactive-equivalent case approaches the
passive character, crosses the former failure point, continues through, moves
away, and submits every frame without termination. The exact `0.021407`
measurement is nonfatal but remains failed/reportable in `measure_only`; the
same measurement produces `CharacterPresenceOverlapExceeded` under
`enforce_acceptance`. Scripted production evidence and controlled invalid
fixtures remain fail-closed. Interaction context is active only while the
authoritative interaction manager has an active interaction; cancellation
and completion restore the ordinary `0.02` threshold.

Real D3D12/DXIL and review-package gates:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo anatomy-quality --scripted-input --frames 600
& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --scripted-input --frames 2400
& '.\tools\build_p27c_r1_review_package.ps1'
& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --interactive --frames 300
```

Run the anatomy and foundation routes from an isolated R1 working directory
so their relative `zig-out` paths cannot overwrite Prompt 27, Prompt 27A, or
final Prompt 27B evidence. The review package requires 8/8 body-only and
16/16 foundation captures, labels source provenance for every displayed PNG,
and includes native/enlarged torsos, both side directions, dark/light and
bilinear composites, diffs, assembled/clothed captures, and an explicit
`[PENDING OWNER REVIEW]` sheet.

The bounded real interactive executable proves startup, D3D12/DXIL
submission, and non-crashing frame completion. It is not represented as
physical keyboard/gamepad testing. Automated geometry and pixel checks do not
claim aesthetic approval.

## VF-01 visual truth debugger and capture bundles

Focused deterministic gate:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --summary all --global-cache-dir '.zig-cache\vf01-global'
```

VF-01 expands this gate to 40 tests. New coverage proves:

- F1 order and wraparound;
- F1 authoritative-state invariance and reset preservation;
- nonzero production truth categories;
- fail-closed debug-command overflow;
- one-shot F4 edges and held-key suppression;
- one frozen state across clean/debug queue generation;
- unchanged simulation tick and all state fingerprints;
- incomplete-directory hiding and timestamp/counter collision handling;
- globally monotonic indices across finalized bundles;
- valid versioned JSON and required top-level schema;
- severity-sorted summary output;
- PNG validation, manifest SHA-256 revalidation, and common fingerprint;
- no embedded NUL or dangling target identities;
- no post-stabilization queue allocations when capture is inactive; and
- deterministic, untimestamped automated evidence names.

The real D3D12/DXIL proof uses `--demo foundation --interactive` and the real
F1/F4 platform path. Synthetic Windows key messages were directed at the
isolated SDL window to make the run repeatable; this is not claimed as
physical-keyboard testing. The final evidence set is the ten globally
monotonic directories ending in `_0020` through `_0029` under
`zig-out/manual_debug_captures`. It covers five front-idle truth snapshots
(male, female, face, shoulder, and pelvis/leg inspection), female side idle,
side walk, airborne/falling, grounded after landing, and All Diagnostics.
Each directory contains exactly five required files. Independent re-read
parses every JSON file, recomputes every manifest-listed SHA-256, rejects NUL
target identities, verifies clean/debug hashes differ, and confirms
`clean_debug_state_equal=true`.

F4 evidence is diagnostic and is never promoted to a golden by this route.
At the VF-01 checkpoint, its fresh current-art Prompt 27B result was 9,714
metrics with 24 front-foot endpoint-height failures. That report is preserved
as pre-correction evidence; the later VF-02 shoe-authority result is described
below. Manual visual acceptance remains `[PENDING OWNER REVIEW]`.

## VF-02 authoritative registration

Focused structural coverage:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-registration -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
```

The registration gate covers point, segment, frame, mesh-bridge schema,
missing sources/targets, coincident endpoints, nonfinite points, reversed
endpoint roles, invalid reflection, degenerate frames, excessive residual,
proximal movement under thickness, front authority bypass, and side semantic
swaps.

The production VF-01 gate submits both styles in front, side-right, and
side-left and requires migrated records to be authoritative, have the correct
binding mode/point count, and remain at or below `0.00001 m`. It also verifies
schema version 3 authority, orientation-axis, submission-visibility, coverage
owner, and exposed-anchor fields.

`test-visual-geometry` remains the independent current-pixel ruler. A
structural registration pass does not imply that silhouette, continuity,
foot, or compatibility metrics pass. Fresh failures are retained as
current-art evidence. The initial VF-02 run passed 13/15 tests: the current
baseline reports eight failure categories, while the pose/morphology sweep
reported 116 silhouette/continuity/legacy-wardrobe findings. The later
owner-review correction does not relabel those findings and does not weaken
either ruler. Its fresh Prompt 27B report independently emits 9,752 metrics
with zero failures after removal of the second wardrobe shoe orientation
authority.

Historical real-D3D12/DXIL bundles `_0040` through `_0049` under
`zig-out/manual_debug_captures` cover male/female front, female side-right,
female side-left walk/idle, and All Diagnostics. Each contains 26
authoritative base registrations with zero structural residual failures, but
its four shoes remain `compatibility_adapter`; this set is not proof of the
owner-review shoe correction.

The final corrective proof uses `_0068` / `_0069` / `_0070` for male and
female body-only front / side-left / side-right, and `_0071` / `_0072` /
`_0073` for the corresponding equipped-foot cases. Body-only frames contain
four rendered anatomy feet and no shoes. Equipped frames contain four
authoritative rendered shoes plus four explicitly suppressed registered
base-foot evidence records. Independent validation recomputes every
manifest-listed SHA-256 and byte size, confirms clean/debug frame, tick,
state, and common-fingerprint equality, and measures zero front shoe
sole-endpoint height delta. These bundles are manual candidates and never
approved goldens.

## VF-03 typed component graph

`zig build test-component-graph` covers the compiled immutable graph, typed
socket roles/tags/capacities, selected bound visuals, eye → eyebrow
child-follow, scalp → hair, explicit shoulder/elbow/wrist/hand-tip arm
modules, front/side-left/side-right projection, the `0.08 m`
intentional-gap contract, and runtime topology-fingerprint compatibility.

The fail-closed fixture matrix covers unknown parent socket, invalid child
tag, socket capacity, component multiplicity, forbidden children,
self-parenting, cycles, inactive parents, duplicate component/socket IDs,
unsupported connection, invalid intentional-gap bounds, missing soft bridge,
missing module joint/end socket, unsupported front projection, child-follow
drift, and post-initialization topology mutation. Fixtures use local
definitions rather than production stable IDs.

The production visual-foundation gate verifies schema-4 graph export,
component/socket/module debug categories, one bound visual per eyebrow child,
authoritative point registration for eye/brow/hair, unchanged frozen-state
identity, and zero post-stabilization queue allocation.

VF-03-R1 adds the cross-layer invariant that an active optional module's three
declared graph visuals resolve to exactly three final production
submissions. Observable tests assert component/module ownership,
shoulder→elbow, elbow→wrist, and wrist→hand-tip bindings, final submission
indices, nonempty visible alpha bounds, view/reflection persistence, inactive
zero-submission behavior, and fail-closed duplicate/wrong-owner/wrong-joint
fixtures. The focused totals are now `6/6` component-graph tests and `47/47`
visual-foundation tests.

Connection tests independently verify epsilon/zero continuous success,
`0.08 m` continuous rejection, `0.08 m` intentional-gap success, below
`0.07 m` and above `0.09 m` rejection, morphology-scale invariance in world
metres, and reflected direction with invariant magnitude. Capture pixels use
the exported camera:

```text
gap_px = measured_gap_m × pixels_per_meter
```

Historical `_0074–_0082` remain unchanged. The accepted corrective
real-D3D12/DXIL bundles are:

- `_0083`: disabled front, `0` active modules and `0` submissions;
- `_0091`: continuous front, `1` module and `3` submissions;
- `_0092`: intentional-gap front, `0.08000003 m` / `6.560002 px`;
- `_0093`: continuous side-left, `3` submissions;
- `_0094`: continuous side-right, `3` submissions;
- `_0095`: intentional-gap side-left, `0.08000008 m` / `6.560007 px`;
- `_0096`: intentional-gap side-right, `0.08000003 m` / `6.560002 px`;
- `_0097`: two modules, `6` submissions with continuous and
  intentional-gap roots.

All eight accepted bundles are schema 4, JSON-parseable, manifest-complete,
SHA-256/size valid, actual `direct3d12`/DXIL, and clean/debug frame, tick,
state, and common fingerprint identical. Missing and orphan submission counts
are zero. `_0084–_0090` are preserved invalid-JSON diagnostic candidates;
they are not completion evidence. Bundle finalization now parses generated
state and manifest JSON before rename. Manual visual acceptance is
`[PENDING OWNER REVIEW]`.
