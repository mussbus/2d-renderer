# Engine Lab traversal and layout expansion

Status: **PENDING INDEPENDENT REVIEW AND OWNER VISUAL/GAMEPAD ACCEPTANCE**.
This is one bounded checkpoint in the unnumbered Engine Lab Integration track.
EL1 remains closed. Automated route execution is not general reachability or owner acceptance.

## Authority and ordered commits

Worktree: `C:\Users\Chad\Documents\2d Renderer-engine-lab-integration`.
Branch: `feature/engine-lab-integration`. Preflight found the requested clean HEAD
`deacc4e2c6f24873df730a18fc83cc23dfa6b97b`. The first new local commit is
`d8642fe6d15973c31199fa06bd4e544faae8c2b4`: five documentation files record
World Time acceptance of that exact implementation. Independent source/evidence
review and owner visual acceptance passed. The reviewer inspected reconstructed
patches, source, tests, logs, hashes and native captures; the implementation owner
performed the Windows/Zig/D3D12 executions. The reviewer did not rerun them.
Pause, step, navigation, reset, snapshot continuation, overflow and the conservative
1,950/1,984 sprites, three batches and 34 spare are accepted. Historical manifests
retain their original pending statuses. The earlier `cf15b1b50191a94f4b1779c71f905b0694a47703`
actually records PSM01 acceptance, as its unchanged history states.

Formatting, architecture/checkout, documentation and `check` passed before the
acceptance commit and before traversal production edits. The second new local
commit contains traversal; its exact identity is in the review manifest. Neither
commit is pushed or merged. Feature acceptance does not imply incorporation into
master. Starting local master and read-only remote master both identified
`1f8d2f3e01102285e76d02a788b7adb5f992087f`; remote feature was
`37d11c8e3a7e2f67e210df0bb71000efdbbee793`. Other worktrees may advance independently.
No fetch, checkout, history rewrite or other-worktree mutation is part of this task.

Zig reports exactly 0.16.0. Preflight verified the lock, installed identities,
all 105 SDL3 3.4.10 files, all 37 DXC 1.9.2602.24 files and pinned archive hashes.
Root AGENTS.md is the only applicable instruction file. No reconciliation document
was found in this checkout. Raw historical bytes and checkout policy are preserved.

## Immutable content and retained construction

[`layout.zig`](../../src/app/engine_lab/layout.zig) is a small immutable app-owned
set of AABBs and named route locations, shared by collision and presentation.
The expanded playable X interval is -24..8 metres, exactly 32 metres. Nine static
boxes include a continuous floor, left/right walls to Y=14, a ceiling at Y=14,
the retained central obstacle, two intermediate ledges and two separated upper
walkways. There is no level format, streaming, editor, procedural placement or
reachability solver. Static RuntimeScene installations and the provisional
15-part production actor retain their original owners.

| Collider | X interval | Top Y / meaning |
| --- | --- | --- |
| 1 | -24.3..8.3 | 0, continuous safe lower floor |
| 2 | -24.3..-24 | 14, left boundary |
| 3 | 8..8.3 | 14, original firing target face at X=8 |
| 4 | -0.75..0.75 | 0.6, retained central obstacle |
| 5 | -24.3..8.3 | ceiling underside 14 |
| 10 | -8.8..-7.3 | 1.6, first ledge |
| 11 | -12.5..-10.8 | 3.2, second ledge |
| 12 | -16.2..-14 | 4.8, first upper walkway |
| 13 | -24..-21 | 4.8, far upper walkway |

The launcher remains (5.5,1.2); wall ID 3 remains at X=8. The original flight
corridor, speed, lifetime, colors, particles and activation semantics are unchanged.
Station anchors (-5.8 and 5.8) and F1/F2 destinations (-4.5 and 4.5) stay stable.
All routes return to floor ID 1 through gravity. The low first ledge and central
obstacle can be crossed with ordinary jumps while returning to both installations.
There are no one-way platforms, drop-through rules, hazards, damage or respawns.

`Hub.initLegacy` retains the accepted room and controller defaults; `Hub.init`
is its compatibility alias. `Hub.initExpanded` selects normal interactive content.
One shared initializer, reset, fixedUpdate, actions and view serve both. Reset
constructs the same selected content before tearing down the live hub. There is
no interactive legacy selector. Native verification constructs legacy and expanded
fixtures sequentially. Earlier tests receive only explicit legacy-capacity naming;
their scenarios, assertions and expected identities are retained.

## Movement authority and shared contract

The provisional definition has no anatomy. Equipment initialization requires
anatomy, so no equipment, anatomy or alternative actor is introduced.
The one authorized shared API is
`CharacterInstance.stepControllerWithProperties(world, intent, GameplayProperties)`.
The complete explicit value replaces resolved properties for that call alone.
It neither merges with equipment nor persists an override. The ordinary entry
retains its supported property/capability resolution. Both delegate to one private
controller step and the same root, facing, attachment, pose and presentation
synchronization block. Values are validated before any controller mutation.
Focused tests compare default results, controller snapshots, world poses and
presentation, reject invalid values without mutation, and demonstrate that normal
equipment authority resumes immediately after an explicit call.

| Lab property | Value |
| --- | --- |
| Maximum running speed | 5.5 m/s |
| Jump launch speed | 10.5 m/s |
| Additional air jumps | one, enabled through existing double-jump property |
| Horizontal dash | enabled through existing dash property |
| Gravity | unchanged -28 m/s squared |
| Dash speed/duration/reuse | unchanged 12 m/s, 0.12 s, 0.20 s |

Shared defaults stay 4.5 m/s and 9 m/s with abilities disabled. Acceleration,
braking, fall limit, jump release, buffering, coyote time, jump-before-dash ordering,
gravity during dash, facing selection, wall termination and landing replenishment
remain in the unchanged controller. At 240 Hz dash has 29 active ticks and 77
start-to-reuse ticks; the start tick consumes one of each. No new physics algorithm,
mutable controller access, cooldown subsystem, invulnerability or air-dash limit exists.

## Measured routes and observation boundaries

The production route inputs in
[`traversal_verification.zig`](../../src/app/engine_lab/traversal_verification.zig)
start at normal spawn. They contain no position writes. Pulse edges and phase
boundaries split frame schedules; per-tick approach steering is sampled identically.
The 60 Hz and mixed 1/3/2 tick groups compare 26 exact traversal checkpoints.
Separate tests execute every route tick, observe events and check penetration,
visibility and named supported surfaces. A negative control removes the gap dash
and fails to reach collider 13. These are specific route proofs, not reachability claims.

| Route observation | Executed hub tick | Root X, Y (m) | Evidence |
| --- | ---: | --- | --- |
| Easy start | 148 | -5.702217, 1.05 | ordinary walk from spawn |
| First landing | 276 | -7.794755, 2.65 | support 10, ground jump |
| Second landing | 473 | -11.499564, 4.25 | support 11, ground jump |
| Upper landing | 670 | -15.204374, 5.85 | support 12; no air jump or dash used |
| Air-jump event | 157 | -7.689182, 3.035276 | one accepted additional jump |
| Shortcut landing | 299 | -10.943366, 4.25 | support 11, skips support 10 |
| Shortcut upper landing | 520 | -15.198179, 5.85 | support 12, 150 ticks earlier than easy route |
| Gap departure | 745 | -16.113335, 5.85 | supported approach on 12 |
| Gap dash event | 786 | -17.080006, 7.225208 | existing dash starts 40 ticks after ground jump |
| Gap contact / braked landing | 924 / 956 | -21.000832 / -21.333110, 5.85 | support 13 across 4.8 m gap |
| Safe return | 1188 | -16.826230, 1.05 | support 1, ordinary descent |

Measured held ground-jump rise is 1.946874 m. The timed additional air jump reaches
3.888886 m above the lower-floor starting root. Each 1.6 m stair rise has about
0.346874 m of vertical apex clearance. First/second/upper landing full-collider
horizontal margins are approximately 0.195/0.400/0.696 m. The shortcut first touches
with partial support overlap, then brakes to a full-collider margin of 0.176 m.
The dash first touches with about 0.301 m of overlap, then brakes to a full-collider
margin of 0.033 m; continued movement left has ample walkway behind it. The dash
travels about 4.8875 m between departure and first contact. The without-dash control
falls short. The named route metadata records starts, support IDs and floor return
for later placement work, but adds no collectible entities or progression.

`engine_lab.traversal.observations.v1` includes layout/profile IDs, selected EL1 v2,
impact and calibration digests, exact time diagnostics, previous controller samples,
air-jump usage, dash direction/active/reuse ticks, pending intent (including dash)
and pause/activation flags. It writes explicit values, never padding. Frame-group
residue and render-only camera are excluded. It is not RR1, a save format or a
complete replay protocol. The old v2 schema and its selected-state meaning remain;
its geometry enumeration now reads the selected immutable construction. All 47
legacy and 12 calibration identities plus the exact World Time checkpoints remain
separate regression authorities.

## Input, lifecycle and tick order

A/D/arrows and stick move; Space/gamepad south jump; Left Shift/right shoulder
dash; E/gamepad west activate the nearby launcher. F1/F2, P, T, R, F3 and Escape
retain their functions. Existing physical fields suffice. App-owned keyboard and
gamepad press capture preserves short dash taps. Pending dash survives zero-step
and paused frames, is consumed once on an executed tick, and does not repeat when
held. Focus loss, navigation and reset clear pending edges and suppress held input
until release. No physical input or controller module changes are needed.

Navigation resets/repositions the same actor and reanchors LAG, clears pending
movement/activation, and preserves stations, projectiles, effects and World Time.
Navigation itself executes no tick. R dominates same-frame actions and executes
zero reset-frame ticks. All 160 initialization and reset failure prefixes are
checked for cleanup; failed reset retains the live controller, content selection,
clock, camera, pending input, station histories, calibration and integration state.
Full two-dimensional launch proximity rejects a root above the bay.

At boundary N: consume activation; step actor with selected properties; animate,
advance visual/foot planting, hub/stations/camera; step PSM01 from completed root;
advance effects; optionally spawn at native N; advance projectiles to N+1;
observe ordered colored events; consume bridge once to create age-zero particles;
clear events; advance World Time once, last. Tests observe age zero and next-tick
age one, exact 60/1 rollover, zero/capped frames and successful tick alignment.
Controller and PSM01 counters since navigation remain independent of total hub time.
The contextual fatal World Time overflow and rejection of continuation are retained.

## Camera, presentation and capacity

Horizontal following retains the 0.9 m dead zone. Expanded vertical following uses
completed root Y plus 0.95 m and a 0.15 m dead zone. X clamps to viewport-derived
bounds inside -24..8; viewports wider than the room center at -8. Y clamps between
2.0 and 14 minus the viewport half-height. Initial/reset camera is (-4.5,2.0).
Navigation snaps to destination X and Y=2.0; subsequent composition applies bounds.
Viewport updates recompose only the camera; invalid zero sizes preserve it.
The original height-relative scale remains 82 * drawable_height / 480 pixels/m.
No zoom, actor shrink, new scheduler or physics dependency is introduced.

Tests retain the earlier 40-tick horizontal approach check and additionally verify
vertical support visibility for the final 16 ticks of every supported arrival.
The full collider and LAG label remain within 640x480, 1280x720 and 960x720 views
through the recorded routes. At jump apex a lower landing can lie below the viewport;
the fixed scale is retained. Rendering at supported interpolation alphas does not
advance simulation, time or solver state. Warm rendering/simulation attempts neither
allocation nor resize growth. Controls use shorter spacing beside the LAG guide.

| Complete production presentation | Bound/capacity |
| --- | ---: |
| Legacy observed / conservative sprites | 1,909 / 1,950, capacity 1,984 |
| Expanded observed / conservative sprites | 2,160 / 2,200 |
| Expanded CPU sprites / entries | 2,232 / 2,232 |
| Conservative spare sprites | 32 |
| Maximum debug commands | 1,903 / 2,048 |
| Mesh capacity / batches | 256 / exactly three |
| Existing GPU rounded backing capacity | 4,096 |

The 5,832-frame saturation matrix includes all geometry/labels, full histories,
diagnostics on/off, run/pause, full-u64 counters, production-font decimal/hash
maxima, 0..8 projectiles, 192 particles, LAG at rest/both limits, maximum time text,
three positions on both levels and three viewports. Actual and conservative totals
are distinct; the latter substitutes the font's maximum hash glyph cost. No shared
renderer defaults change. All storage is reserved before stabilization.

## Evidence, reproduction and acceptance limits

Fresh records live under `.tmp/engine-lab-traversal`. The existing `.zig-cache`,
`.tmp/projectile-impact/global-cache` and `.tmp/projectile-impact/install` are reused
with `-j1`. Prior evidence inventory is 44 original-projectile, 117 follow-up,
148 PSM01 and 138 World Time files (447 total), hashed before and after work.
Protected source, dependencies, historical records and original test scenarios
are checked separately. Development failures and corrected inputs remain in the ledger.

Native D3D12 verification reruns all 32 accepted captures and adds 18 traversal
captures, with separate paths for development and final evidence. Traversal captures
cover lower floor, ascent, supported upper landings, air jump, dash, upper HUD,
descent, particles, LAG/time coexistence, pause/step, navigation and reset.
Each copied native RGBA hash is checked against PPM bytes and lossless PNG pixels.
Still captures temporarily pause presentation to show completed state; logs retain
the actual simulation pause flag. Alias tables identify deduplicated images.
Balanced GPU resource/fence totals are reported from final execution below.

The compact `engine-lab-traversal-review.zip` includes two ordered full-index binary
patches, committed changed sources, command arrays/exits/source identities/raw logs,
records, reproduction and verification scripts, hashes and native evidence. A
separate temporary Git index applies the patches to the starting commit and verifies
the exact final tree without modifying the working index. Prior evidence payloads,
caches, dependencies, executables and unrelated assets are excluded. The manifest
and package receipt carry final commit, tree, source and archive identities.

Final input inspection also restricted SDL dash press events to the selected
gamepad, matching the existing platform polling authority. Other connected
controllers cannot inject that edge. Physical gamepad acceptance remains pending.

Development findings: the first layout hit an upper walkway underside, so the
stairs were rearranged to approach from an open side. Initial compilation caught
an existing `properties` name collision, the pose API's `world_transforms` spelling,
and optional collider ID typing. Legacy fixtures now name their original capacities
explicitly. Test corrections retained paused held-input semantics and used the
required float tolerance for camera arithmetic. Initialization failure testing
handles subsystem-specific allocation errors directly. No failing assertion or
historical scenario was removed or weakened. Automatic approval review rejected a
combined framing/test-window edit; it was not executed. The implemented alternative
preserves the original horizontal assertion and adds an independent vertical check.

No collectibles, score, progression, RR1 adoption, extra PSM01 binding, World Time
policy, combat, anatomy, equipment workaround, dynamic actor publication, sibling
application, dependency or shared controller-algorithm change is included.
Independent source/evidence review and owner visual/gamepad acceptance remain pending.

Owner launch from the existing worktree:

```powershell
Set-Location -LiteralPath 'C:\Users\Chad\Documents\2d Renderer-engine-lab-integration'
& '.\.tmp\projectile-impact\install\bin\engine_lab.exe'
```

## Final implementation execution

Final code/test/build/capture-encoder source SHA-256:
`a81cfeb81e0f6ae27d0e37d3a00024053800bbed456547d7f3fda8b6cc9e2366`. The hash definition and exact per-command arrays, exits,
source identities, durations and raw logs are in `run.py` and `commands.json`.
Documentation is inventoried separately by committed file hashes.

| Fresh gate invocation | Observed result |
| --- | --- |
| Formatting; architecture/checkout; documentation | passed, exit 0 |
| Focused five roots, Debug / ReleaseSafe / ReleaseFast | 208 / 208 / 208 tests; all passed |
| Explicit CharacterInstance properties | 10 tests passed |
| check | 635 tests; 39/39 steps succeeded |
| test-full | 732 tests; 52/52 steps succeeded |
| Default + Engine Lab builds, all three modes | six gates passed |
| Physical GPU smoke | passed; 26/26 steps succeeded |
| Headless verification | legacy, calibration, time and 26 traversal records passed |
| Native Engine Lab verification | 32 legacy + 18 traversal captures; 551 traversal frames |
| Expected fatal World Time overflow | process exit 1; verification wrapper exit 0 |
| Lossless native capture encoders | 7 + 8 + 9 + 8 + 18 captures passed |

The focused roots executed 77 Engine Lab, 21 World Time, 40 PSM01, 58 effects/
projectile and 12 camera tests in each mode. Counts above come from actual raw
`All N tests passed` summaries, not earlier checkpoints. Child compiles may be
cached; fresh invocations and executed tests are distinct. All gates listed above were executed. Final delivery formatting, architecture/checkout, documentation and raw-preservation audit are required before the local commit and are
listed in `required-gates.json`; their exact receipts are included in the package.

Final native shutdown reports 26/26 GPU resources and 2940/2940 fences.
Traversal reports zero warm allocation growth, zero drops, and exactly three
batches. The installed Debug Engine Lab executable defaults to the expanded hub.
Source/evidence review and owner visual/gamepad acceptance remain pending.
