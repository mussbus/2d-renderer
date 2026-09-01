# Prompt 27A Engineering Decision Record

## Status and scope

Prompt 27's automated integration acceptance remains regression-protected, but
its manual visual acceptance is reopened. The historical nine captures and
their timing/resource evidence remain under
`zig-out/p27_visual_foundation/`; Prompt 27A does not overwrite or promote
them. Candidate evidence is written separately under
`zig-out/p27a_evidence/`. Owner aesthetic acceptance remains
`[PENDING OWNER REVIEW]`.

Prompt 27A changes only capture/evidence selection, diagnostics, and review
packaging. Character and garment art, animation clips, physics, collision,
camera behavior, the handshake definition, and production render ownership are
out of scope.

## Pre-change empirical declaration

This declaration was frozen at baseline HEAD
`7c4721a5fedbac93eb507b429dfecf4b9e211cde` before changing production
capture behavior.

### Measurement method

The evidence route evaluates a fixed ordered capture specification against a
read-only observation of the authoritative scene after fixed-tick update and
before submission. A capture candidate must satisfy all declared
authoritative, presentation, interaction, and diagnostic predicates for the
declared number of consecutive fixed ticks. Duplicate render observations at
the same simulation tick add no stability. A false predicate resets the
stable count. Reaching the bounded render-frame timeout is an error.

Every accepted capture is measured from two sources:

1. scene semantics: fixed simulation tick, controller state, resolved
   presentation, interaction ownership/lifecycle, equipment/theme identity,
   debug submissions, camera, render-resource counters, and queue metrics;
2. the production D3D12 readback: a 640 by 480 RGB frame with validated PPM
   structure, pixel-data hash, visible-color bounds/statistics, and
   deterministic PNG conversion.

The manifest binds both sources by capture ID, filename, render frame,
simulation tick, and pixel hash. Missing, duplicate, nonfinite, out-of-order,
or mismatched evidence fails closed. No filename or script phase proves a
state.

### Units and frozen thresholds

| Measurement | Unit | Accepted range | Rationale |
| --- | --- | --- | --- |
| Idle horizontal velocity | m/s | absolute value at most 0.02 | Existing controller's settled-front observation boundary. |
| Idle vertical velocity | m/s | absolute value at most 0.02 | Rejects airborne/residual vertical motion while allowing float noise. |
| Locomotion horizontal speed | m/s | absolute value at least 0.20 | Existing production locomotion/view transition boundary. |
| Jump-rise vertical velocity | m/s | greater than 0.20 | Separates a rising body from the apex band. |
| Apex vertical velocity | m/s | absolute value at most 0.35 | A 60 Hz render observation spans four 240 Hz gravity steps, or about 0.467 m/s; 0.35 brackets the nearest honest apex sample without admitting clear rise/fall. |
| Jump-fall vertical velocity | m/s | less than -0.20 | Separates falling from the apex band. |
| Airborne root clearance | m | at least 0.10 above the last supporting surface | Rejects a takeoff-edge frame that is not visibly airborne. |
| Raised-landing semantic sole error | m | each foot at most 0.08 from its raised-surface sample | Bounded landing-pose contact evidence; stricter planted-foot quality remains under Prompt 27B. |
| Initial/front/final stable hold | fixed ticks / rendered pacing | at least 240 ticks and 60 rendered frames | Required inspection pacing at 240 Hz / 60 Hz. |
| Forced outfit/view hold | fixed ticks / rendered pacing | at least 240 ticks and 60 rendered frames | Required inspection pacing. |
| Debug hold | fixed ticks / rendered pacing | at least 240 ticks and 60 rendered frames | Required inspection pacing. |
| Ordinary state stability | fixed ticks | at least 8 unless a longer hold is declared | Rejects single-frame transitions while keeping motion captures phase-local. |
| Interaction phase stability | fixed ticks | at least 12 | Provides a legible bounded phase sample. |
| Capture timeout | rendered observations | spec-specific, never above the 2,400-frame route bound | Missing required states fail rather than silently disappearing. |
| D3D12 dimensions | pixels | exactly 640 by 480 | Fixed production acceptance camera target. |
| D3D12 RGB payload | bytes | exactly 921,600 after the PPM header | Detects truncated or malformed readback. |
| Debug submissions | primitives/frame | greater than zero and all required category counts greater than zero | A flag alone is not visible diagnostic evidence. |

These thresholds are declared before the Prompt 27 baseline run. Any later
change must record the old/new values, rationale, affected cases, before/after
results, and boundary-negative fixture evidence.

The inherited route bound was 2,100 rendered frames. After the baseline was
frozen, the bounded evidence route was changed to 2,400 frames because the
required 60-frame inspection holds plus distinct first-contact/release/cleanup
captures cannot complete all three regression-protected handshakes and the
final reset inside 2,100 frames. This changes pacing only: fixed tick, capture
predicate thresholds, physics, clips, and interaction event ticks are
unchanged. The affected case is the scripted Prompt 27A evidence route; focused
timeout fixtures still reject a target one observation beyond its declared
per-spec bound.

The original initial-idle timeout was 90 render observations and the cleanup
timeout was 100. Alternate-schedule testing exposed that these bounds could
reject an otherwise identical 240 Hz state observed at 120 render Hz. Both
bounds are now 180 render observations. Required fixed-tick stability, state
predicates, and the overall 2,400-frame route bound are unchanged. Controlled
timeout fixtures still fail on the first observation beyond the declared
bound.

A completion audit found that the raised-landing predicate recorded the real
landing/support but did not yet gate the two visible foot semantics. The
bilateral 0.08 m landing-pose bound was added before any art or simulation
change. The frozen production measurement is 0.009689 m for each foot. The
valid-bound fixture passes at 0.08 m; minimally invalid 0.0801 m and clearly
invalid 2 m fixtures both fail. This is capture-integrity evidence, not the
stricter pixel/sole correction assigned to Prompt 27B.

### Required ordered matrix

The route must produce exactly these predeclared cases:

| Order | Capture ID | Semantic state |
| ---: | --- | --- |
| 1 | `initial_front_idle` | grounded automatic front idle with no interaction |
| 2 | `side_left_walk` | left-facing side locomotion |
| 3 | `stopped_front_facing_left` | settled front while gameplay facing remains left |
| 4 | `side_right_walk` | right-facing side locomotion |
| 5 | `short_jump_rise` | airborne positive-velocity short-jump rise |
| 6 | `jump_apex` | airborne side-view apex band |
| 7 | `jump_fall` | airborne negative-velocity fall |
| 8 | `raised_platform_landing` | real grounded landing on the declared raised collider |
| 9 | `theme_switch_in_place` | changed theme with unchanged authoritative fingerprint |
| 10 | `interaction_approach` | eligible pre-request approach |
| 11 | `interaction_reach` | active pre-contact reach |
| 12 | `interaction_first_contact` | first contact semantic with active IK/order evidence |
| 13 | `interaction_release` | release semantic after contact |
| 14 | `interaction_cleanup_front` | no interaction/view/IK/override ownership remains |
| 15 | `detailed_debug` | detailed diagnostics submitted in all required categories |
| 16 | `reset_stable_front` | reset world held in stable automatic front idle |

Both production characters, current selected body/morphology/hair/build,
current outfit, front/side views, left/right facing, locomotion/jump, theme
transition, interaction lifecycle, cleanup, debug, and reset are recorded per
case. A missing matrix row is a failure, never a skip.

### Controlled fixtures

Focused tests use data-only observations, not production IDs. For each major
predicate they include a valid case, a minimally invalid boundary case, and a
clearly invalid case. The negative matrix covers excessive idle velocity,
wrong resolved view/facing, grounded rise, positive-velocity fall,
pre-semantic interaction contact, incomplete cleanup ownership, absent debug
submissions/categories, bilateral raised-landing error, theme/root/camera
invariance, locomotion/apex boundaries, interaction approach/reach/release,
interrupted stable holds, nonfinite fields, missing metadata, duplicate
filenames/IDs, out-of-order cases, and timeout.

The same tracker is also run with two render schedules over identical fixed
ticks. Capture identities and authoritative capture ticks must match. The
critical D3D12 route is run twice; semantic manifests and byte-stable capture
hashes must match except for fields explicitly documented as nondeterministic.

## Historical baseline preservation

The original `zig-out/p27_visual_foundation/` directory is retained
unchanged. A uniquely named Prompt 27A baseline directory contains hashes,
command output, and a separately executed copy of the inherited D3D12 route.
The inherited route is expected to demonstrate the known defect: nine
phase/frame-selected captures with no per-capture semantic manifest.

## Architecture boundary

Capture observations are read-only projections of the existing authoritative
scene. They cannot mutate roots, controller state, skeleton poses, animation,
IK, interaction ownership, presentation, camera, theme, or equipment. The HUD
submits bounded sprites through the existing `UnifiedRenderQueue`; it owns no
SDL input path, GPU resources, second renderer, or per-frame allocation.
Readback continues through the existing SDL3 GPU/D3D12 transfer-buffer path.

## Golden boundary

Prompt 27A produces review candidates, not approved goldens. Promotion is
prohibited until the user explicitly approves the generated package.
