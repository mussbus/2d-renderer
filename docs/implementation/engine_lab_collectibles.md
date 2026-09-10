# Bounded Engine Lab collectible challenge

Status: **OWNER ACCEPTED** on `feature/engine-lab-integration`; the nonblocking generic debug-capacity guard is corrected with bounded regression evidence.

This is one unnumbered application integration on `feature/engine-lab-integration`.
The accepted traversal/zoom parent is `fd8378974305b9e9b2b27451caf028f2b1ccd5db`.
Traversal/zoom and closed EL1 acceptance remain intact. Neither local commit implies
incorporation into master. Collectibles have their own review boundary.

## Acceptance checkpoint (2026-09-09)

The owner accepts the experience: pickups work, reset works, indicators are
present, and the experience looks good. No physical gamepad model or detailed
manual test transcript was supplied. A ring of indicators nearer screen center
is deferred presentation polish, not an acceptance blocker.

Accepted implementation: `14dc4e42923d0e50d80a637c6113456c87b41488`, with source
SHA-256 `d1616e7b0a878a253474734be92d7b2c822e0cf96343acefe64b1233eca27be3`.
The reviewed `.tmp/engine-lab-collectibles/engine-lab-collectibles-review.zip`
is 7,648,452 bytes, SHA-256
`8ac9ae8c236a17c630d3ba205db9c884e9256bacf18fcc81142a861f2ee74b80`.

Acceptance covers one active authored pickup at a time, all six physical-contact
pickups, reaction and separate collection effects, indicators, start/restart and
the lifecycle behavior documented below. The conservative combined presentation
bound remains 2,453/2,560 sprites, 107 spare, three batches. Shared additions are
default-false gamepad north polling and caller-selected debug command capacity;
the shared default is 2,048 and Engine Lab selects 2,304.

Independent review found no blocking six-pickup installation issue and verified
both ordered patches, snapshots, archive/member identities and all 120 native
capture conversions. It confirmed the 47 legacy, 12 calibration, eight World Time
and 26 traversal records unchanged. It reviewed the implementation session's
Windows evidence (751 full-suite tests, 395 focused tests per optimization mode,
required builds and native/GPU checks); the reviewer did not execute Windows,
Zig or D3D12 gates itself. Those results retain the source identity above.

Review also identified a nonblocking shared-helper issue: the existing guard
checks the default constant rather than the supplied generic capacity. Its narrow
correction and fresh regression evidence are a separate follow-up. This acceptance
documentation does not rerun or relabel the earlier product matrix. Historical
pending wording in the original evidence records describes their creation time.
EL1 remains closed, no new milestone is created, and acceptance on the integration
branch does not imply incorporation into master.

## Ownership and controls

The expanded persistent hub starts idle. C or gamepad north starts a run or restarts
completion. Short native key/button events and held-state edges share one semantic
action. Active/reaction presses are consumed immediately. Start preserves actor
position, World Time, projectiles and zoom. Legacy construction has no challenge.
Focus loss, navigation and reset clear pending start and suppress held controls.
Pause/zero-step can latch start; T executes one normal tick. R dominates and uses
candidate-first reconstruction, preserving the entire live hub on allocation failure.
Navigation retains progress, reaction, run identity and live particles; no teleport
path is queried. Only subsequent resolved controller movement/overlap can collect.

`collectible_content.zig` owns six IDs, positions, supports, dimensions, color and
reaction profile. `collectibles.zig` owns bounded state and translates application
observations into accepted effects requests. Generic physics/effects acquire no
Engine Lab semantics. The only shared additions are default-false raw gamepad north
polling and `CommandBufferWithCapacity`, whose shared default remains 2,048. North
was missing from the physical vocabulary; the additional HUD needs a provable
caller budget beyond the old shared command limit. The application selects 2,304.
No movement, layout, camera, impact, PSM01, World Time or renderer algorithm changes.

## Authored course and collection contract

World-space metres, Y up; every pickup has half-extents (0.12, 0.12).

| Ordinal | Stable ID | Position | Supporting collider |
|---|---|---|---|
| 1 | 101 approach | (-5.7, 1.05) | 1 lower floor |
| 2 | 102 first | (-8.2, 2.65) | 10 first ascent |
| 3 | 103 second | (-11.6, 4.25) | 11 second ascent |
| 4 | 104 upper | (-15.2, 5.85) | 12 before gap |
| 5 | 105 far | (-21.7, 5.85) | 13 across gap |
| 6 | 106 returning | (-17.2, 1.05) | 1 lower return |

Validation rejects invalid length/IDs/order, nonfinite/nonpositive bounds, room
escape, solid overlap, incorrect/missing support, insufficient horizontal landing
margin, incorrect standing height, insufficient standing clearance and coincident
consecutive positions. These are non-solid application triggers, absent from the
movement world. Six is this content slice, not an engine vocabulary limit.

The adapter borrows the completed production controller and calls physics-owned
`static_sweep.query` on previous position -> (resolved end X, previous Y) -> resolved
end position, in that order, with the physical collider dimensions. It retains the
query's strict overlap, entering, separating and grazing conventions. It does not
query a diagonal chord, velocity reconstruction, rendered root or attachment.

Start creates a target in an executed tick; collection begins on subsequent ticks.
One collection emits an observation (run, spawn ID, ordinal, executing hub tick,
position, resolved segment), immediately removes collectability, increments progress
once and starts 24 subsequent executed reaction ticks. Their last tick creates the
next target or 6/6 completion; a new target cannot collect during its birth tick.

The existing projectile pre-movement activation and impact sequence stay unchanged.
After actor/animation/stations/camera/PSM01 and the complete impact sequence, collection
effects step once, then one challenge transition/query runs and emits its observation.
World Time advances last. Both burst types finish their birth tick at age zero and
advance to one on the next tick. Late errors remain fatal partial ticks; continuation
is rejected and whole-hub reset repairs them.

The separate collection effects instance allocates at expanded initialization: six
emitters, 72 particles, 12-particle bursts, 120-tick lifetime, no continuous emission.
Its clock advances once on every hub tick, even idle. UUIDv5 IDs use a dedicated
namespace plus run and pickup ordinal. Restart clears only its live IDs with `clear`,
preserving tick alignment; it never resets or commandeers impact effects.

## Presentation and bounded evidence

Existing neutral texture page, debug glyphs and production queues render a green
diamond, matching particles, compact C/north hint, progress and completion. A single
read-only arrow points toward a target outside the usable central camera rectangle,
clear of controls/status. Text and arrow keep drawable-relative size at all zooms.
Render, interpolation, resize and extraction do not mutate challenge state.

The original traversal contribution remains protected at 2,254/2,286 sprites with
32 spare, across its original 17,496 saturation frames. New contributions are counted
separately. The current combined conservative bound is 2,453/2,560 (107 spare), mesh
capacity 256, debug capacity 2,304, exactly three batches. New saturation covers all
phases/ordinals, nine indicator configurations, three viewports and all zooms with
eight flights, 192 impact particles and 72 collection particles. Synthetic saturation
and isolated lifecycle staging are not route evidence.

`collectible_verification.zig` supplies authored semantic movement/jump/dash inputs
from normal spawn through all pickups and a second run without reset or navigation.
Returning for the second run physically jumps over the existing low first ledge.
Equivalent 60 Hz/mixed groupings compare twelve ordered events and two diagnostics.
The native proof uses single-tick production window submissions, comparing the same
endpoints and retaining birth/age-one/reaction/next-target/completion captures.
Real window resize/zoom checks inspect the camera after submission. Readbacks use
that camera without republishing it. Capture storage is transient; frame simulation
and extraction report zero allocator/resize attempts. Screenshots are engineering
evidence, not owner visual/gamepad acceptance.

New diagnostic schema `engine_lab.collection.observations.v1` covers phase, run,
progress, birth/reaction timing, effects tick, pending start, ordered event identities,
ticks and segment, plus live particle IDs, ordinals, ages, positions and velocities.
It excludes frame residue, presentation, complete controller state and some effects
configuration/rotation. It is not whole-hub replay authority. The old 47 legacy,
12 calibration, eight World Time and 26 traversal identities remain protected with
the challenge idle. New evidence does not relabel older source results.

## Reproduction and review boundary

Use pinned Zig 0.16.0, `-j1`, default `.zig-cache`, global cache
`.tmp/projectile-impact/global-cache` and prefix `.tmp/projectile-impact/install`.
Run `test-engine-lab` without its optional development filter for acceptance; affected
roots also include `test-deterministic`, `test-camera` and `test-renderer-boundary`.
The final matrix requires all three optimization modes, `check`, `test-full`, both
application builds, physical `gpu-smoke`, Engine Lab `--verify` and `--smoke`.
`--verify-world-time-overflow` and `--verify-collection-overflow` deliberately fail;
expected errors, propagation markers and context must all match.

The task ledger, raw logs, source identities, preserved failures, native PPM/PNG
captures and review package live under `.tmp/engine-lab-collectibles/`. Native smoke
capture directories must be supplied there so previous accepted evidence is preserved.
The package contains both ordered patches and exact snapshots with isolated index/
object reconstruction. Final validation and commit identities are recorded with the
package; independent review and owner visual/gamepad acceptance remain pending.

## Final automated validation

Frozen source SHA-256:
`d1616e7b0a878a253474734be92d7b2c822e0cf96343acefe64b1233eca27be3`
across 373 source/test/build inputs. Documentation is inventoried separately.

The Windows implementation session executed 395 affected tests in each of Debug,
ReleaseSafe and ReleaseFast, 654 tests through `check`, and all 751 `test-full` tests,
including the 100,000-tick stress fixture. Both default and Engine Lab applications
built in all three modes; Engine Lab Debug was restored. Physical D3D12 `gpu-smoke`,
complete Engine Lab headless/native proofs and both expected overflow error fixtures
passed their contracts. Cached compilation is identified separately from executed
tests in the command ledger. Both deliberate overflow processes returned exit 1,
with the required propagation/error context; neither is a successful simulation.

Native collection proof submitted 4,670 frames and retained 66 challenge captures
(two complete physical runs, twelve pickups, no navigation in either route). The
complete final run retained 120 native captures across all installations, with raw
PPM bytes, lossless PNG encodings and native RGBA hash matches. Resources balanced
26/26 and fences 7,770/7,770. There were zero steady-state allocation/resize attempts,
particle drops or queue growth. Readbacks are fixed 640x480 images using the actual
post-window-submission camera; the resized-window checks validate native camera and
HUD/arrow bounds, not desktop screenshot pixels at each window resolution.

The final evidence audit matched all 47 legacy, 12 calibration, eight World Time and
26 traversal records against retained authority. It verified 1,173 preexisting
evidence files unchanged and retained the accepted archive bytes. Earlier compile
corrections, the second-run route fixture missing a return jump, and the native
verification helper's calibration reanchor counter assumption are preserved as
failed development attempts. The corrected final run is separately identified.
No earlier result is relabeled as testing this source.

These are automated engineering results. Independent collectible review and owner
visual/gamepad acceptance remain pending. The two-commit review package records
commit IDs, ordered patches, exact snapshots, preservation receipts and isolated
index/object reconstruction; packaging checks do not count as product test execution.

## Generic debug command capacity correction (2026-09-09)

This follow-up resolves the nonblocking issue recorded at acceptance. The old
module-level guard checked only `command_capacity` (2,048). The generic now checks
its actual comptime `capacity` before returning the storage type, accepting
1..65,535 inclusive and rejecting zero/65,536 with the existing diagnostic.
`OrderInput.body_part_layer` is an i32 input validated into the u16
`DrawOrderKey.body_part_layer`; this preserves the existing conservative domain.
The default 2,048, Engine Lab 2,304, command layout, order and bounded append
error remain unchanged. There is no runtime branch or allocation added.

Production-type fixtures force analysis with `@sizeOf`; valid 1, 3, 2,048, 2,304
and 65,535 compile without creating a maximum-size stack value. The zero and
65,536 probes each return compiler exit 1 with exactly the intended diagnostic;
the runner separately returns 0 after checking it. The integration root also
checks actual three-command storage, validated order, exact fill, failed append,
no last-command overwrite, overflow count and beginFrame reuse. Existing default
and Engine Lab saturation tests remain intact. No compile-failure infrastructure
existed, so three small fixtures and `tools/checks/debug_capacity.py` provide the
bounded reproduction; there is no new general framework or build registration.

Frozen corrected source SHA-256:
`cc7aeb19037625cd219edc2e9daa9a6e2adec1bd8bb7f0438927115ea322b812`.
The existing inventory algorithm covers source/tests/build and the retained
impact-review tool; the new probe runner and fixtures are additionally frozen
in `frozen-probes.json`. Every final gate checks those identities unchanged.

Fresh Windows/Zig 0.16.0 evidence under
`.tmp/engine-lab-collectibles-closeout/`: positive/negative probes in all three
optimization modes; unfiltered `test-engine-lab` (94) and `test-integration` (10)
in Debug, ReleaseSafe and ReleaseFast (104 per mode); `check` (39/39 steps,
654 executed tests); Engine Lab Debug build (11/11 steps), leaving the normal
owner executable ready. Compilation cache reuse is identified in the raw build
summaries; executed test counts come from actual test output. The new generic
regression belongs to `test-integration`, not `test-deterministic`.

All commands use the existing local cache, `.tmp/projectile-impact/global-cache`,
`.tmp/projectile-impact/install` and `-j1` for build gates. Direct object probes
emit no binary and use the same cache locations. No new full suite, application
matrix, GPU/native capture or manual review was performed for this correction.
Earlier 751/395, native/GPU and visual evidence retain reviewed source
`d1616e7b0a878a253474734be92d7b2c822e0cf96343acefe64b1233eca27be3`.
The accepted archive and prior failures are preserved. Central indicator-ring
polish remains deferred; the correction changes no collectible experience.
