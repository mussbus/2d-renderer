# Bounded Engine Lab collectible challenge

Status: **IMPLEMENTED WITH FINAL AUTOMATED EVIDENCE; INDEPENDENT REVIEW AND OWNER ACCEPTANCE PENDING**.

This is one unnumbered application integration on `feature/engine-lab-integration`.
The accepted traversal/zoom parent is `fd8378974305b9e9b2b27451caf028f2b1ccd5db`.
Traversal/zoom and closed EL1 acceptance remain intact. Neither local commit implies
incorporation into master. Collectibles have their own review boundary.

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
