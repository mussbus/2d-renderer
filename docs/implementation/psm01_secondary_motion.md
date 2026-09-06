# PSM01 - Deterministic Secondary-Motion Foundation

## Executive summary and status

PSM01 is the dedicated, requested first secondary-motion milestone within the
existing architecture-ready PHY lane. It does not rename PHY or advance AN,
M03, M04, Model Lab, or a later PSM milestone. Implementation and the required automated gates pass; owner acceptance remains pending.

The implementation extends the existing production scalar spring and adds a
physics-owned driver-following channel. It requires no renderer, skeleton,
human geometry, application, editor, allocator, wall clock, or global state.
The mathematical channel can later be used independently along two or three
axes; no anatomical or presentation binding is implemented.

## Isolation record

| Item | Observed value before implementation |
| --- | --- |
| Original worktree | `C:\Users\Chad\Documents\2d Renderer` |
| Original branch | `master` |
| Original HEAD / local master / known origin/master | `cb60fc9a9b24ba7d69578ffc721948e9b00de8fd` |
| Original tracked and untracked status | Clean |
| Local master matches known origin/master | Yes; no network refresh performed |
| PSM01 worktree | `C:\Users\Chad\Documents\2d Renderer-psm01-secondary-motion` |
| PSM01 branch | `psm01-secondary-motion` |
| PSM01 base | `cb60fc9a9b24ba7d69578ffc721948e9b00de8fd` |
| Prior PSM01 branch or worktree | None; proposed path unoccupied |
| Original index SHA-256 | `AA2979907CB6C298268E02C01E706369D6C8ECACB65406E3F1F515F7234271D8` |
| Original file metadata snapshot | 405811 files; `BA76DDAA883DA0CB7810FCC85796E33621AC6646E361580359E8FA85548628DF` |

The metadata snapshot includes tracked, untracked, and ignored files, sorted
by ordinal relative path, length, and UTC last-write ticks. It excludes shared
Git administration and does not follow reparse points. It is a metadata check,
not a claim to hash every file's contents. Git diff/status and the index hash
provide separate tracked/index checks. Worktree creation necessarily adds
shared Git administrative records and the new branch.

Other pre-existing worktrees were the original checkout and:
- `2d Renderer-media-library`, `feature/media-library-foundation`,
  `ae21349486db5dc55cc09171bd9f52c7692f7231`;
- `2d Renderer-media-library-ui`, `feature/media-library-ui`,
  `b636c7a0d452d31087ade9f875c1d2f9d2d4f966`.

The root AGENTS.md is the only applicable AGENTS.md found. No different
integration branch or extra worktree instruction was found. Zig 0.16.0 was
verified before edits. Existing pinned Zig, SDL, and DXC inputs are copied
into the isolated checkout, without dependency updates or links back to
writable original caches. All implementation, formatting, tests and commit
operations take place here.

## Pre-implementation audit: verified facts

### Fixed simulation authority

- [fixed_step.zig](../../src/physics/fixed_step.zig) owns 240 Hz and
  `fixed_dt_seconds = 1/240` (f64 clock; f32 solver conversion).
  Clock clamps real delta to 0.10 seconds, executes at most eight ticks,
  reports discarded excess whole ticks, and preserves a fractional remainder.
  Pause adds no elapsed time; single-step executes one tick. Negative elapsed
  values become zero; non-finite elapsed values fail.
- Several application/scenario compositions own Clock instances:
  integrated_demo, foundation_playground, visual_foundation, playground_demo,
  wardrobe_demo and controller_demo. There is one reusable timing algorithm,
  not one global scene loop. The F-backed integrated route is the representative
  authority; the maintained foundation presentation uses its production scene.
  The independent engine_smoke client proves renderer composition and is not
  an alternative character simulation.
- [character.zig](../../src/scene/character.zig), especially
  advanceVisualTickInternal, advances authored animation, procedural pose,
  breathing, hierarchy, foot IK, appearance and then attachment motion.
  integrated_demo advances controller/collision before visual motion, then
  interaction management and reapplication of owned foot constraints.
- The documented ideal final-anchor order is not universal in code:
  sampleInteractionAnimation advances attachment state while sampling the role
  pose, before the interaction manager's later arm solve. This is an existing
  integration finding, not authority for changing the interaction pipeline.
- Quarter-speed debug modes scale elapsed time BEFORE Clock, reducing the
  number of simulated ticks. This slows the whole simulation. It is distinct
  from playing only a driver trajectory faster at the same simulation rate.
- Existing fixed-step/controller, secondary-motion, attachment, interaction,
  integration and stress tests protect the clock and simulation contracts.

### Physics and ownership

[character_controller.zig](../../src/physics/character_controller.zig) owns
position, velocity, grounded state, gravity, movement acceleration, jumps,
dash and impact events. There is no standalone body.zig in this checkout.
[collider.zig](../../src/physics/collider.zig) owns AABBs;
[collision_world.zig](../../src/physics/collision_world.zig) owns immutable
static collider storage, axis-separated sweeps and ground queries.
IK/foot constraints live in animation; interaction constraints in interaction.
There is no general rigid-body force/constraint engine to extend here.

[spring.zig](../../src/physics/spring.zig) already owns the reusable unit-mass
scalar damped spring, target offsets, explicit velocity impulses and bounds.
Its semi-implicit Euler update checks finite values, caps velocity, projects
displacement, and removes outward velocity on an overshooting projection.
Physics is the correct production owner. No reusable spring extraction from
a demo is needed.

### Existing secondary motion disposition

- [procedural_motion.zig](../../src/animation/procedural_motion.zig) owns the
  existing 2D pose binding: speed/contact-derived walk bounce, impact-driven
  landing compression and controller-acceleration head rotation. It imports
  spring and fixed_step. Character instances own mutable state.
- [attachment_secondary_motion.zig](../../src/animation/attachment_secondary_motion.zig)
  owns one to four scalar-spring pairs plus 2D rest offsets, facing conversion,
  chain targets and Transform2D output. Appearance/equipment resolved instances
  own mutable nodes, not shared definitions. Hair, cape, sleeves and garments
  consume it in production. It runs fixed ticks, not render delta.
- Attachments use controller velocity/acceleration and authored sag/velocity
  targets, rather than differentiating their resolved anchor trajectory.
  Definitions and mutable state are separate; first use/facing changes reset.
  There is no general position discontinuity/seek notification contract.
- The existing attachment validation separately bounds stiffness and damping
  steps; the combined mathematical stability condition is not enforced there.
  PSM01 uses a stricter envelope without changing accepted legacy profiles.
- Disposition: REUSE and EXTEND the scalar integrator; PRESERVE the two
  established representation-specific bindings and their regression tests.
  PSM01 adds the missing generic driver/history/lifecycle policy, not another
  spring implementation. Existing targets, chains, facing and composition
  must not be silently migrated to a different physical model.

### Animation, math and dependencies

- clip.advanceTime applies playback_speed once to the authored timeline.
  Animator updates cross-fade source/destination local components; angles use
  shortest-arc interpolation. Procedural composition follows sampling and
  precedes ordinary foot IK. Interaction sampling accepts shared explicit
  time, with state/time validation, rather than a general seek event bus.
- Character reset explicitly resets visual state, animator, springs and
  controller history. setWorldPosition updates hierarchy; it is not a
  representation-neutral teleport notification.
- An adapter can evaluate a final authored/IK attachment coordinate each
  fixed tick and pass that scalar to PSM01. No animation import is necessary.
  PSM01 never samples a clip, composes a pose, or competes for animation time.
- Existing specialized math uses f32 Vec2/Mat3/Transform2D, radians, column
  vectors, parent-times-local transforms, +X right and +Y up, and metres.
  Foundation spatial also has f32 Vec3 and shared right-handed +Z forward.
  A scalar f32 channel needs neither package and duplicates no vector type.
- Foundation determinism provides explicit seeds/keys and SceneTime; it does
  not promise cross-platform bitwise floating-point integration. Existing
  runtime determinism is same inputs/configuration/ticks on the Windows x64
  toolchain, with tolerances for broader comparisons.
- F4 is accepted. [CURRENT_STATE](../project/CURRENT_STATE.md),
  [MASTER_ROADMAP](../project/MASTER_ROADMAP.md) and
  [ARCHITECTURE_MAP](../project/ARCHITECTURE_MAP.md) govern current ownership.
  Build registration belongs in build/modules.zig and build/tests_engine.zig;
  fast/full aggregation belongs in build/gates.zig.
  tools/checks/architecture.ps1 enforces lower-layer dependency direction.
- Shared overlap is limited to the spring, explicit build catalog, test
  registration and architecture policy. No human, Model Lab, Engine Lab,
  character, pose, interaction or renderer source is edited.

## Architecture decisions and solver contract

These are PSM01 implementation choices, distinct from the audit facts above.

The immutable authored Profile is passed by value to validated operations.
Each State owns response offset/velocity, two driver-history values, and a
tick count. DriverSample owns one position and a discontinuity flag.
TickInput supplies the driver and external acceleration. Explicit impulse is
a velocity change applied with applyVelocityImpulse, not force or momentum.
Response contains only offset and velocity. Future bindings own coordinate
conversion and deformation; the solver has no semantic IDs.

For one channel, let U be its selected unit (metres or an unwrapped angular
coordinate in radians). All inputs and response share one fixed, orthonormal
axis/frame. Moving/rotating frames require a future adapter to transform all
samples consistently or reset. Do not pass wrapped angles or projected pixels.

At each fixed tick h:
```text
driver_velocity = (driver_position - previous_driver_position) / h
driver_acceleration = (driver_velocity - previous_driver_velocity) / h
forcing = external_acceleration * external_gain
        - driver_acceleration * inertial_gain
response_acceleration = -stiffness * offset - damping * velocity + forcing
velocity_next = velocity + response_acceleration * (h/2)
offset_next = offset + bounded_velocity_next * (h/2)
```

Driver derivatives and forcing are evaluated once per owner tick. Spring acceleration and both
integration equations are evaluated twice with the same forcing, at h/2 per stage.
There is no additional clock, accumulator, adaptive timestep or rate factor.
The second fixed stage improves first-order integration accuracy: at 0.5 s
the critical analytic proof initially exceeded its 0.00015 U tolerance with
one stage (0.00420451 U vs 0.00404277 U). Two stages yield 0.00412415 U and
satisfy the unchanged assertion. Existing bindings still use one legacy stage.

This is the existing semi-implicit Euler integrator, extended with an explicit
acceleration argument. Its unit-mass stiffness/damping parameterization
preserves one existing physical authority. Derived natural angular frequency
is sqrt(stiffness), and damping ratio is damping/(2*sqrt(stiffness)); neither
is an independently authored field. The legacy step delegates with zero
external acceleration, retaining its original arithmetic order.

| Profile field | Default | Unit | Supported range |
| --- | --- | --- | --- |
| stiffness | 144 | 1/s² | >= 1, stiffness*h² <= 1 |
| damping | 12 | 1/s | >= 0.01, damping*h <= 1 |
| inertial_gain | 1 | dimensionless | 0..100 |
| external_gain | 1 | dimensionless | 0..100 |
| maximum_displacement | 0.25 | U | 1e-6..1e6 |
| maximum_velocity | null | U/s | null or >0..1e6 |
| settle_displacement | 1e-5 | U | >0, strictly below maximum displacement |
| settle_velocity | 1e-4 | U/s | >0..1e6, strictly below a supplied velocity cap |

All authored numbers must be finite. Ranges fail with meaningful errors;
invalid data is never sanitized. The documented numeric budgets bound profile
products within f32 range. The lower stiffness/damping bounds exclude
non-restoring and effectively undamped configurations. The independent
upper bounds imply stiffness*h² + 2*damping*h <= 3 < 4, inside the
semi-implicit Euler stability region. This is a stability envelope, not a
claim that high-frequency motion is accurately resolved near its edge.

Normal inputs may have any finite coordinate, but derivative/force overflow
is rejected. f64 intermediate differencing avoids overflowing a finite
position subtraction before validation; solver response remains f32.
Large absolute f32 positions can lose small motion. Bind in a local coordinate
frame. Use explicit discontinuity for teleports and seeks.

## Lifecycle, limits and energy

- init(profile, position) starts exactly at rest with zero previous velocity.
  The first ordinary moving sample is a real start from rest.
- step advances exactly one established fixed tick. It accepts no delta,
  playback rate, elapsed time or allocator. The owner executes it once for
  every Clock substep in stable instance/channel order.
- applyVelocityImpulse adds delta velocity and applies the optional velocity
  limit. A momentum impulse must be divided by binding-owned mass upstream.
- reset(profile, position) clears response and derivative history, and resets
  the diagnostic tick counter. It can recover a corrupted old state.
- A flagged discontinuity sample resets at the new position within the current
  tick, clears inherited response, and skips that tick's external forcing.
  Valid input is still required. Following samples resume from rest.
- Failed operations leave State unchanged. Profile changes require a deliberate
  reset/reinitialization; silently animating stiffness is not supported.
- Bounds act on response relative to the driver. Velocity capping removes
  kinetic energy. Displacement projection removes restoring potential;
  outward velocity is zeroed, while inward velocity is retained. No rebound
  or restitution is introduced. Continued external forcing can do work but
  outward contact does not accumulate hidden velocity.
- When net forcing is exactly zero and BOTH response magnitudes are below
  authored settling thresholds, response snaps to exact zero, removing residual
  energy. Nonzero forcing is never discarded by the settling rule.
- Euler's ordinary discrete physical energy can fluctuate slightly even for
  a stable unforced trajectory. The claim is finite, bounded, decaying response
  and non-injecting constraint projection, not per-tick conservation.

## Fixed-step and playback semantics

Tests use the existing Clock, including zero/multiple-substep frames, pause,
single-step and equal-tick frame partitions. Discarded ticks are not simulated;
different frame partitions that DROP different ticks are outside equivalence.

Only the trajectory sampler changes rate. The same normalized path sampled
at rate 0.5, 1 and 2 supplies different position histories at unchanged h.
Finite differences naturally produce faster velocity and acceleration.
There is no playback-rate field in the solver, so an already retimed path is
not scaled again. Whole-world quarter-speed debug mode has different meaning.
A paused solver does not step. Pausing only the driver allows response to
settle; resuming or changing rate creates the physical sampled acceleration.
A seek, hard cut, coordinate-frame change or teleport must mark discontinuity.

Replay requires profile, complete State, ordered samples, external
accelerations, impulses, discontinuities and fixed-tick schedule. Same binary,
target, optimization mode and input sequence repeat exactly in tests.
Cross-platform or cross-optimization bitwise equivalence is not promised.
The driver wrapper uses strict float mode and the spring retains its existing default float policy. The core uses no transcendental operations, randomness,
wall clocks, iteration over unordered containers or allocation.

## Future integration recommendations (not implemented)

| Consumer | Future binding responsibility |
| --- | --- |
| Existing 2D pose and attachment motion | Choose migration explicitly; map final driver coordinates, preserve visual ownership, compare accepted traces; convert scalar responses to existing transforms |
| Model Lab / canonical 3D animation | Sample pose/driver frames outside physics, evaluate independent axes, transform response after agreed IK ordering |
| Morphology and deformation controls | Define permitted channels, amplitude units, axes and range policy without changing topology here |
| Breast, glute, abdomen/body fat and thigh-fat bindings | Semantic binding selects frame, permitted deformation channels and profile; subsequent morph/bone/control mapping owns vertex movement |
| Hair, clothing, tails, ears and accessories | Select attachment frames and channel profiles; chains, collisions and coupled constraints need separately scoped designs |
| Authored profile assets / character editor | Serialize validated Profile later and expose its single parameter authority; no new assets or UI here |
| Record/replay | Record full fixed-tick state/input/impulse/discontinuity history with toolchain/profile identity |
| Collision response | Convert a later collision observation into explicit acceleration or delta velocity outside this core |
| Later soft-body approximations | Justify coupling, volume/contact constraints and solver choice in a separate milestone |

No anatomical binding, skeleton/skin deformation, morph authoring, cloth,
volumetric/FEM/fluid simulation, collision system, editor, new demo or PSM02
is part of this change.

## Owner-review decisions and limitations

Review the conservative profile envelope and defaults, sampled-position driver
contract, explicit discontinuity policy, and unit/frame responsibilities.
Review future integration ordering separately, especially the pre-existing
interaction attachment timing discrepancy. Automated completion never implies
owner acceptance or visual/anatomical validation.

The following sections record executed synthetic proofs and validation.
Owner acceptance and later binding decisions remain separate.


## Synthetic proof results

Measured with Zig 0.16.0, Windows x64, Debug, after the two-stage accuracy
correction. ReleaseSafe and ReleaseFast also pass all focused assertions.

| Scenario | Observed result |
| --- | --- |
| Stationary driver / zero impulse / zero forcing | Exact zero offset, velocity and energy for 10,000 ticks |
| Underdamped k=100, c=4, initial offset=0.1 U | Minimum -0.05258262 U; peak energy 0.50000001; exact rest at the 6,000-tick observation |
| Critical k=100, c=20, initial offset=0.1 U | At 0.5 s: 0.00412415 U; continuous reference 0.00404277 U; absolute tolerance 0.00015 U |
| Critical and high damping c=20/60 | No negative-offset oscillation; monotonic displacement decay and exact rest by 6,000 ticks |
| Unit velocity impulse with default profile | Peak 0.04453819 U; exact zero final energy; repeated traces agree in every scalar bit |
| Displacement projection with outward force | Projected energy 0.00500000 vs unprojected 12.92160293 at the same tick |
| Sustained positive limit contact | 2,400 ticks at 0.01 U with exact zero outward velocity, then release and exact settling |
| Forced gravity equilibrium, external gain=0.5 | -0.03402785 U vs -4.9/144 U; tolerance 1e-6 U |
| Profile envelope | 36 combinations, 24,000 ticks each: 864,000 finite bounded ticks |
| Driver path at 0.5x / 1x / 2x | Peak magnitudes 0.00009838 / 0.00038218 / 0.00141552 U |
| Render grouping | 240 one-tick, 60 four-tick and mixed zero/one/multi-tick frames produce identical 240-tick states |
| Teleport from negative to positive f32 maximum | Reset response/derivative history; no false impulse; ordinary unflagged overflow fails without mutation |
| Legacy spring preservation | Six base-commit samples protect target, impulse, reversal and long settling behavior |

The playback fixture is a shared normalized cosine path:
position(t)=0.02*(1-cos(2*pi*0.25*t)) U, ten normalized cycles at each rate.
All three driver frequencies lie below the profile resonance. These measured
results do not imply that response grows monotonically at every possible
frequency, especially across resonance or when limits engage.

The 36 envelope cases combine stiffness {1,144,57599}, damping
{0.01,12,239.99}, displacement {1e-6,1e6}, and velocity cap {null,1e6}.
The high stiffness/damping values sit just inside the public envelope to avoid
f32 equality ambiguity at the exact edge. Inputs force/alternate for 2,000
ticks and then release for 22,000. Very low damping is not claimed to settle
within this observation window; every case must remain finite and bounded.

Legacy samples were generated by executing the actual spring.zig from base
cb60fc9a9b24ba7d69578ffc721948e9b00de8fd in an ignored headless fixture, rather
than reconstructing its integrator in the assertion. The committed test
records six measured samples and explains its 1e-7 U / 1e-6 U/s tolerances.

## Test inventory

The standalone tests/psm01_secondary_motion_tests.zig contains 23 tests:

1. Stationary and zero input preserve exact rest without energy.
2. Displacement converges; underdamping overshoots.
3. Critical and high damping settle without sign oscillation.
4. Critical response agrees with an independent continuous solution.
5. Impulse reproducibility and independent instances.
6. Projection removes energy; sustained contact stores no outward velocity.
7. Exact boundary contact removes outward and preserves inward motion.
8. Optional velocity cap limits impulses and forced stepping.
9. Reset clears response/history/ticks and recovers corrupt old state.
10. Teleport/seek avoids differentiating the position discontinuity.
11. A step and sudden reversal create signed inertial response.
12. External acceleration reaches the correct forced equilibrium.
13. Settling retains turning points and tiny nonzero forcing; explicit zero gains disable response.
14. Every profile field rejects NaN and both infinities.
15. Invalid zero/negative/contradictory/unstable profiles fail closed.
16. Rejected inputs, numerical overflow and invalid state are transactional.
17. Supported profile extremes remain finite and bounded in long runs.
18. Identical ticks agree across render partitions, including zero-tick frames.
19. Clock pause, single-step and resume retain established behavior.
20. Faster traversal strengthens the natural response at fixed timestep.
21. Retimed and precomputed input agree without a second playback-rate factor.
22. Independent channel update order leaves per-channel traces unchanged.
23. Both spring entry points match independently captured base-commit samples.

The existing test-deterministic root still executes all 277 declarations,
including the untouched animation, procedural motion, attachment-secondary,
controller and lifecycle regressions. The PSM01 proof is a separately compiled
headless root with only three named production dependencies; no test-only
solver exists. The new production facility and its two transitive local
dependencies have enforced import allowlists in the architecture check.

There is no allocator argument, allocation call, mutable global, wall-clock
read, resource initialization, window, GPU or destruction obligation in the
channel. Its state and both integration-stage spring values are inline.
This is established by the source/dependency audit, not an invented allocator
counter. No physical GPU/visual proof is needed for this headless scope.

## Validation commands and observed outcomes

All build/test/format commands below execute in the isolated PSM01 worktree.
The executable is the copied .deps/zig-0.16.0/zig.exe (SHA-256
086CE9D47BA42F33A514E1A6E04EB1D4A8FA1D75E0868E0213CAAD447C91E864),
matching the original toolchain. All 142 copied SDL/DXC manifest entries were
rehash-verified against the existing manifests and pinned archive identities.

For readability, commands here omit only output redirection to ignored
.tmp/*.log; arguments and cache locations are reproduced exactly.

| Command | Exit code | Observed output |
| --- | --- | --- |
| `& '.\.deps\zig-0.16.0\zig.exe' version` | 0 | 0.16.0 |
| `git -c safe.directory='C:/Users/Chad/Documents/2d Renderer' worktree add -b psm01-secondary-motion 'C:\Users\Chad\Documents\2d Renderer-psm01-secondary-motion' cb60fc9a9b24ba7d69578ffc721948e9b00de8fd` | 0 | New branch; HEAD at cb60fc9 |
| `& '.\.deps\zig-0.16.0\zig.exe' build test-deterministic -Dtest-filter=spring -j1 --summary all --cache-dir '.zig-cache\baseline' --global-cache-dir '.zig-cache\global'` | 0 | Pre-change baseline: 6 tests, 3/3 steps |
| `& '.\.deps\zig-0.16.0\zig.exe' test .tmp/capture_spring_baseline.zig --cache-dir '.zig-cache\baseline' --global-cache-dir '.zig-cache\global'` | 0 | Six base-commit samples; 1 test passed |
| `& '.\.deps\zig-0.16.0\zig.exe' fmt src/physics/secondary_motion.zig src/physics/spring.zig tests/psm01_secondary_motion_tests.zig build/modules.zig build/tests_engine.zig build/gates.zig` | 0 | Modified Zig files formatted |
| `& '.\.deps\zig-0.16.0\zig.exe' build test-psm01 -j1 --summary all --cache-dir '.zig-cache\psm01' --global-cache-dir '.zig-cache\global'` | 0 | 23 tests; 3/3 steps |
| `& '.\.deps\zig-0.16.0\zig.exe' build test-psm01 -Doptimize=ReleaseSafe -j1 --summary all --cache-dir '.zig-cache\psm01-release' --global-cache-dir '.zig-cache\global'` | 0 | 23 tests; 3/3 steps |
| `& '.\.deps\zig-0.16.0\zig.exe' build test-psm01 -Doptimize=ReleaseFast -j1 --summary all --cache-dir '.zig-cache\psm01-release' --global-cache-dir '.zig-cache\global'` | 0 | 23 tests; 3/3 steps |
| `& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all --cache-dir '.zig-cache\psm01' --global-cache-dir '.zig-cache\global'` | 0 | 407 tests in 10 roots; 21/21 steps |
| `& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all --cache-dir '.zig-cache\psm01' --global-cache-dir '.zig-cache\global'` | 0 | 27/27 steps, application compilation, formatting, static checks and fast tests |
| `& '.\.deps\zig-0.16.0\zig.exe' build test-full -j1 --summary all --cache-dir '.zig-cache\psm01' --global-cache-dir '.zig-cache\global'` | 0 | 504 tests, 16 roots; 40/40 steps |
| `& '.\.deps\zig-0.16.0\zig.exe' fmt --check build.zig build.zig.zon build src tests` | 0 | No formatting findings |
| `pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/check_repository.ps1` | 0 | Hygiene and architecture policy passed |
| `pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/check_documentation.ps1` | 0 | 46 required files, 42 Markdown files, 95 local targets |
| `git -c safe.directory='C:/Users/Chad/Documents/2d Renderer-psm01-secondary-motion' diff --exit-code -- docs/history` | 0 | No historical content changes |

The full deterministic CPU gate passed 504 tests in 16 roots, 40/40 build
steps, including the existing long-duration stress and production integration
suites. test-content, the larger verify aggregate and physical GPU smoke are
not required for this non-content, non-rendering physics change under the
current docs/TESTING.md gate matrix. Full application release builds are not
claimed; the new headless root is tested in both release modes.

### Resolved development and environment findings

- Initial Git status without safe.directory reported dubious ownership.
  Subsequent Git commands use a per-command exception; global config is
  unchanged.
- Exploratory reads of body.zig, math/root.zig, build/engine_tests.zig,
  build/validation.zig and tools/check_architecture.ps1 found those paths absent.
  Actual source/build ownership was located and used; no assumed API or module
  was invented.
- The first focused compile failed with two helper-name shadowing errors.
  The helper was renamed to springState; subsequent compilation passed.
- The first executed numerical suite passed 22/23 tests: critical response
  exceeded the analytic accuracy tolerance. The new channel's two fixed
  integration stages corrected the numerical error without relaxing that
  assertion. The maintained-contact fixture holds outward force across both
  stages, so it measures sustained contact rather than immediate inward release.
- The first documentation audit found 12 historical hash mismatches; the first
  check gate also found 249 baseline Zig files with CRLF formatting differences.
  System Git core.autocrlf=true had changed their checkout bytes. No policy,
  hash, accepted assertion or historical content was changed to conceal this.
- Twelve archive files were copied byte-for-byte from the original ONLY after
  verifying their recorded SHA-256 and their normalized equality with the base
  Git blobs. Some historical hashes preserve mixed line endings, so a first
  attempted raw-base equality check stopped before writing any file.
  The 249 untouched Zig files were materialized with LF bytes only after their
  reconstructed Git blob IDs matched the base/index objects. The resulting
  tracked diff contains none of those files. Formatting and hash audits then
  passed. No Git configuration was changed.

## Files and review scope

Created:
- src/physics/secondary_motion.zig
- tests/psm01_secondary_motion_tests.zig
- docs/implementation/psm01_secondary_motion.md

Modified:
- src/physics/spring.zig
- build/modules.zig
- build/tests_engine.zig
- build/gates.zig
- tools/checks/architecture.ps1
- docs/TESTING.md
- docs/project/ARCHITECTURE_MAP.md

The ten-file implementation diff is limited to PSM01. Local dependencies,
caches, log files and the base-source sampling fixture remain ignored in the
PSM01 worktree. No dependency versions or production profile assets changed.

## Commit and final worktree receipt

One focused commit is created on psm01-secondary-motion after validation and
complete diff review. A commit cannot contain its own resolved hash.
The owner-review completion receipt at .tmp/psm01-completion.md records the
actual hash and final worktree status after commit; the same hash is reported
in the final owner response. This committed document supplies the durable
contract, test data and validation record.

Before the commit, the original snapshot was rechecked: all 405811 records,
the metadata digest and original index hash matched the preflight values.
The original remains clean on master at the base hash; local master and known
origin/master still match. No fetch, pull, merge, rebase, reset, clean, stash,
branch switch, commit on master or push was performed. The original worktree's
tracked/index/untracked/ignored state was preserved. Only the required shared
Git worktree records and PSM01 branch are added.
