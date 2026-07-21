# Build and Milestone Plan

## Inspected baseline

The repository began as an empty Git repository with no commits, source files, build files, dependency manifest, vendored dependencies, or SDL headers. The active compiler was verified as Zig 0.16.0 before the first modification. This plan therefore introduces files only when they gain executable or binding content.

## Build graph contract

The final `build.zig` will use Zig 0.16.0 APIs observed from the installed compiler. It will expose these real steps:

- Default `zig build`: compile shaders, compile the executable, copy `SDL3.dll` and shader artifacts into the install tree, and install the application.
- `zig build test`: build and run the platform-neutral aggregate in `tests/test_all.zig` without SDL video or a GPU.
- `zig build run`: depend on installation and run the installed application with its runtime DLL/assets available.
- `zig build gpu-smoke`: compile shaders and run the separate GPU smoke executable against explicit D3D12/DXIL.
- `zig build check`: run formatting verification, the test step, and static source/repository audits that require no GPU.
- `zig build -Doptimize=ReleaseSafe` and `-Doptimize=ReleaseFast`: build the same application and assets with the requested Zig optimization mode.

The build will not download from the network. It validates versioned local dependency paths created by `tools/bootstrap_dependencies.ps1` and fails with a direct recovery instruction if they are absent or malformed. Shader compilation is a normal dependency of graphical executable and GPU smoke builds, with explicit HLSL inputs and DXIL outputs.

## Milestone 0: binding design and dependency decision

Deliverables are `AGENTS.md`, architecture/dependency/testing documents, this build plan, and a concise repository README. Exit criteria are complete documented decisions, exact dependency hashes, an inspected SDL header record, and no renderer or feature implementation.

## Milestone 1: reproducible build foundation

Create `.gitignore`, `build.zig`, `build.zig.zon`, `tools/bootstrap_dependencies.ps1`, a minimal real `src/main.zig`, and the smallest SDL platform binding needed to initialize and shut down cleanly. Create a test aggregate only when the first real test exists.

The bootstrap script validates Zig, downloads exact SDL/DXC archives, checks SHA-256, extracts transactionally, and validates expected files. The build uses the actual Zig 0.16.0 standard build API and the inspected SDL headers/import library. The executable may print version/dependency diagnostics and exit; it must not pretend to render.

Exit criteria: dependency bootstrap succeeds from a clean `.deps`; incorrect hashes fail; `zig build`, both required release builds, formatting, and the first platform-neutral tests pass; initialization cleanup is tested where practical.

Prompt 1 explicitly required a narrower real GPU validation slice earlier than the full renderer planned in Milestone 7. That slice adds pinned HLSL/DXIL compilation, explicit D3D12/DXIL device creation, a procedural texture upload, one indexed instanced quad draw, swapchain presentation, render-target readback, and controlled initialization fault injection. It validates the build and ownership foundation without adding the future character renderer, sprite batching architecture, atlas, animation, physics, input, or scene systems. Milestone 7 remains responsible for the full sprite renderer and its architecture; this amendment does not move or weaken those decisions.

## Milestone 2: deterministic math and time

Add only the math and timing files needed for `Vec2`, `Mat3`, transforms, interpolation, and the 240 Hz fixed-step accumulator. Add exhaustive unit tests for conventions, composition order, interpolation, overload clamping, and float tolerances.

Exit criteria: deterministic tests pass without importing SDL; no steady-tick allocation exists.

## Milestone 3: skeleton and animation core

Add skeleton validation, owned pose storage, clip tracks/events, animator blending, and the locomotion state machine. Implement idle, walk, jump, fall, and land pose data sufficient for tests. Add world-transform/socket evaluation and visible walk vertical-offset data.

Exit criteria: sampling, wrap events, transitions, pose ownership, and socket transforms pass deterministic tests; physics root and visual offsets are structurally separate.

Prompt 3 advances only the foundational math and hierarchy portion of Milestones 2 and 3: `Vec2`, column-major affine `Mat3`, component `Transform2D`, shortest-angle interpolation, immutable validated humanoid definitions, independent local/world poses, sockets, render attachments, and one deterministic segmented humanoid. It deliberately does not add fixed-step timing, clips, state machines, IK, physics, or interactions. The humanoid submits exclusively through Prompt 2's production `SpriteBatch`.

Prompt 4 completes the animation-core portion of Milestone 3: transactional immutable clip definitions, packed component keys, typed events, bounded multi-loop traversal, local-pose sampling and blending, per-character animator state, one-shot fallback, eight real authored clips, and the deterministic idle/walk demonstration. It deliberately leaves physical root movement, IK, constraints, eligibility, and handshake coordination to later milestones. All animation output enters Prompt 3's existing `Pose` evaluator and Prompt 2's existing `SpriteBatch`.

Prompt 5 establishes the authoritative 240 Hz simulation clock, platform-neutral edge-preserving input, SDL keyboard/gamepad ownership, kinematic AABB controller, swept static collision, gravity, variable-height jump, coyote time, jump buffering, physical landing reporting, physics-selected locomotion animation, render interpolation, and the finite controller demonstration. Physics owns character-world position; animation remains local visual pose. IK, springs, dynamic bodies, and interaction coordination remain in their assigned milestones.

## Milestone 4: character physics and secondary motion

Add physics body/colliders, static collision world, character controller, gravity, jump, grounding, landing detection, and bounded springs. Integrate animation state inputs but keep simulation independent of rendering.

Exit criteria: deterministic platform scenarios pass; jump is physically simulated; landing impulse drives compression; walk bounce does not move the collision root; no external physics engine or per-tick allocation exists.

## Milestone 5: interaction, handshake, and IK

Add interaction sessions, handshake phase coordination, shared-target selection, bounded approach control, analytic two-bone IK, socket measurement, cancellation, and explicit handshake draw-order overrides.

Exit criteria: two independent character simulations coordinate one session, converge without normal full-body teleportation, measure hand separation no greater than 0.015 m during grip, release without welding, and pass both front-limb ordering cases.

Prompt 8 completes the coordination-only portion: immutable paired definitions, deterministic eligibility/candidate ranking, a four-slot shared interaction pool, atomic role entry and locks, one 240 Hz paired clock, deduplicated semantic events, interaction-owned partial layer overrides, cancellation/completion cleanup, fixed-position contact measurement, mirroring, isolation, and one-draw GPU evidence. It deliberately adds no approach movement, root correction, collision, target constraint, or IK. Prompt 9 owns analytic arm IK and must improve the recorded authored-contact baseline without changing interaction-root alignment.

Prompt 9 completes the analytical arm-constraint portion: a stateless triangle solver with near/far classification, immutable-length right-arm binding, explicit mirrored bend preference, shortest-angle pose blending, a per-instance pre-IK midpoint target, deterministic `0 -> 1 -> 0` shared-timeline weight, cancellation/reset cleanup, order-independence proof, and a perturbed legal-spacing demonstration. It adds no root alignment, leg or foot constraint, character collision, rigid-body constraint, or additional GPU path.

Prompt 10 completes deterministic visual foot placement: the controller's static AABB world supplies allocation-free downward top queries, anatomical contact events create gated per-foot intent, immutable rest-derived leg bindings reuse the analytical two-bone solver, and fixed-tick world locks blend in/out without root or collision mutation. The milestone adds floor/raised-platform, jump/replant, mirroring, isolation, order, schedule, slip, penetration, hover, physics/timing invariance, one-draw, and zero-allocation evidence. It adds no physical feet, moving platform model, ragdoll, motion warping, dynamic body, pelvis solver, or GPU path.

## Milestone 6: SDL input platform

Add the SDL lifecycle wrapper and raw keyboard/gamepad acquisition needed for the demo. Convert raw state and edge events into `CharacterIntent`; handle gamepad add/remove and explicit close paths. Document final controls in `docs/CONTROLS.md`.

Exit criteria: intent conversion remains platform-neutral and tested; manual keyboard/gamepad checks pass; device ownership has explicit cleanup.

## Milestone 7: SDL GPU sprite renderer

After re-inspecting the vendored 3.4.10 headers at every used API, add HLSL, the pinned shader compilation script, GPU context/resource owners, render types, sprite batching, and renderer. Force `direct3d12` with DXIL only. Build a shared quad plus ordered instance data, a texture atlas, alpha blending, and one indexed instanced draw for the sprite batch.

Every initialization failure cleans acquired resources in reverse order. Every GPU object has a release path. Swapchain/device/shader/pipeline/texture/buffer failures are fatal with operation and SDL error text.

Exit criteria: shader compilation and validation pass; `zig build gpu-smoke` creates and destroys the full resource chain and draws at least two instances in one call; no high-level SDL renderer, API fallback, CPU rasterizer, or per-body-part submission exists.

Prompt 2 establishes the authoritative sprite submission core early: explicit CPU/GPU layouts, deterministic integer ordering, texture-page range generation, a three-slot fenced upload ring, straight-alpha blending, actual-operation metrics, a deterministic 1,000-sprite demonstration, and the shared production smoke path. Later Milestone 7 work extends this same batch for character atlas content and render snapshots; it must not introduce a second sprite path.

## Milestone 8: demo scene and debug visualization

Add the two-character scene, static platforms, sprite assets, full state integration, debug bones/colliders/sockets/targets, metrics, and the final controls document. Connect interpolation-only render snapshots to the renderer.

Exit criteria: every manual visual acceptance item in `docs/TESTING.md` passes, including both limb-front modes and live socket-error display.

Prompt 7 established the multi-character and occlusion foundation. Prompt 8 now reuses it for the fixed-position paired handshake while leaving IK, motion warping, root alignment movement, and character-to-character collision unimplemented.

Prompt 11 completes the integration/observability portion without replacing those systems. It adds a deterministic ten-phase two-character route, bounded scalar snapshots, named milestone captures, fixed-capacity debug sprite commands, exact update-order assertions, debug/read invariance, adversarial resets, repeated interaction/plant cleanup, long-duration stability, and owned resource/allocation accounting. Debug mode shares the existing sprite batch and creates no GPU resources during ordinary frames. Prompt 12 hardens that implementation adversarially: it makes collision tie-breaking independent of collider storage order, reports coherent foot lifecycles and named milestone ticks, validates milestone dependencies, fixes the repository audit's pattern-array construction, and extends the retained stress coverage to 1,000 interactions and 100,000 fixed ticks.

## Milestone 9: hardening and performance

Audit all partial initialization, destruction, errors, allocation behavior, test independence, fixed-step overload behavior, batching, and release builds. Measure the documented performance counters and run the no-placeholder/source-policy audit.

Exit criteria: every required build command exits zero in its proper environment; GPU/manual requirements have recorded evidence; the 10,000-tick allocation test passes; no disabled test or unfinished implementation remains.

## File creation discipline

The intended repository tree in `AGENTS.md` is a destination, not a request for empty scaffolding. For example, `sprite_batch.zig` appears with the renderer milestone, `handshake.zig` with interaction, and `metrics.zig` when metrics are recorded. A milestone may split a file earlier only when the new file contains real behavior used by that or the immediately following milestone.
