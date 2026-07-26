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

Prompt 11 originally added 11 deterministic integration tests. They cover a 32-entry diagnostic ring's overwrite order, 256-command debug overflow, debug-off/on authoritative equivalence, never-read/read-every-tick diagnostics equivalence, repeated non-destructive getters, landing-event single delivery, animation-contact physics invariance, pre-arm-IK target freezing, final hierarchy evaluation, reset during plant/airborne/pre-contact/contact, character-local isolation and interaction-peer release, three render grouping schedules, sequential complete handshakes, and a repeated integrated route. The final adversarial audit strengthens those same cases to 1,000 handshakes and 100,000 fixed ticks. The long route executes at least 30 complete walk/jump/platform/handshake/cleanup cycles, checks finite controller, spring, and foot state on every tick, rejects airborne locks, bounds slip to `0.0002 m`, and ends with zero allocation/resource growth and no stale interaction, override, or IK state.

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

The GPU-backed acceptance route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 1800 --demo foundation --scripted-input
```

It requires Direct3D 12/DXIL, three persistent mesh definitions, three modular characters, eight static colliders, conventional two-sleeve and nonstandard four-sleeve expansion, actual controller property consumption, canonical handshake IK/foot planting, exact reset, zero fixed-buffer update/submission growth, zero unified-queue allocation after stabilization, and zero GPU-resource creation after scene/topology initialization. It reports actual sprite/mesh instance, range, draw, and upload counts and rejects more than 32 total mixed draw commands. The interactive companion is `zig build run -- --demo foundation --interactive`.

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
