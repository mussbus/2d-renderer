# Engine Lab EL1: persistent hub corrective pass

Status: persistent-hub corrective implementation; validation results and the owner gate are recorded below.

## Authority and starting audit

The corrective owner request supersedes the first EL1 selectable-environment design.
Engine Lab is one persistent integrated application/world. The sandbox retains its
isolated demonstration modes; engine_smoke supplies bounded architecture/GPU proof;
3D Model Lab remains separate canonical authoring work; future games are sibling
production-engine clients. None is imported by Engine Lab.

All work is in C:/Users/Chad/Documents/2d Renderer-engine-lab-el1 on
feature/engine-lab-el1, initially clean at 93303802692459ac0449a17586e9b78085d4bf9e,
one commit above accepted F4 base cb60fc9a9b24ba7d69578ffc721948e9b00de8fd.
The owner checkout is clean on master at that base; master and recorded origin/master
match. Owner index SHA-256 before work:
AA2979907CB6C298268E02C01E706369D6C8ECACB65406E3F1F515F7234271D8.
Only the EL1 local branch contains its first commit; it has no upstream. This is
local evidence only; no fetch or network publication check was performed.

Root AGENTS.md is the only applicable repository instruction file. Zig reports
0.16.0. Installed SDL 3.4.10 headers and production renderer APIs were inspected.
The current F1-F4 architecture authority is accepted; historical candidate wording
in earlier implementation reports does not override the current normative record.

Registered worktrees: owner, EL1, media-library foundation/UI, secondary motion,
record/replay, world-time foundation, and effects/projectiles. The latter four
share central build/test/documentation files with EL1. Their additions belong to
other modules; none owns Engine Lab sources. No other branch is incorporated here.
Central edits are limited to EL1 wiring; future integration may require resolving
adjacent build-catalog hunks. No material unresolved implementation ownership
conflict was identified.

## Production ownership decision

CharacterInstance.initControlled, stepController, selectControllerAnimation,
advanceVisualTickWithFootPlanting and submitUnified provide the existing controlled
2D actor path. CharacterController and CollisionWorld own movement/contact;
authored clips, animator, procedural motion and foot planting own visual motion.
The application composes these APIs without importing or copying a demo root.

RuntimeScene owns generic scene membership, lifetime, hierarchy and publication.
Its mutation/snapshot transactions allocate. The accepted integrated compatibility
route publishes character transforms through CharacterEntityBindings, whereas the
retained side-scroller path uses the specialized current 2D runtime directly.
EL1 uses that provisional specialized actor path and a RuntimeScene for static
station anchors. It does not register a stale generic actor transform, claim the
actor is an F-backed canonical character, or introduce a dynamic RuntimeScene API.
Generic actor publication remains a future integration decision, with the accepted
allocation/authority contracts intact. LevelDefinition is the authored entity/asset
container; no authored asset resolver is needed for these fixed runtime anchors.

Engine Lab imports production modules; production modules never import Engine Lab. The hub receives an allocator,
explicit seed and CharacterIntent values, with no renderer, window or service locator.
The application owns persistent platform/GPU services and a single hub. Destination
shortcuts move the current actor through its supported staging command. Only whole-hub
reset reconstructs world state; both installations remain live during navigation.

## Review of all first-commit files

| File | Classification | Corrective decision |
| --- | --- | --- |
| README.md | KEEP AND ADAPT | Describe direct hub startup and navigation |
| assets/engine_lab/white.png | KEEP UNCHANGED | Actual neutral sampling texture for hub geometry/HUD |
| assets/manifest.json | KEEP UNCHANGED | White asset remains used and byte-identical |
| build.zig | KEEP UNCHANGED | Independent runtime installation wiring remains necessary |
| build/apps.zig | KEEP AND ADAPT | Retain targets; remove obsolete CLI help |
| build/gates.zig | KEEP UNCHANGED | Headless tests and independent compilation still belong in gates |
| build/modules.zig | KEEP AND ADAPT | Replace old composition source and inject production actor dependencies |
| build/tests_engine.zig | KEEP AND ADAPT | Describe hub behavior coverage |
| docs/TESTING.md | KEEP AND ADAPT | Correct controls and hub verification |
| docs/implementation/engine_lab_el1.md | REPLACE | Current report supersedes old design; first-commit evidence remains in Git history |
| src/app/engine_lab/labs.zig | REMOVE AS OBSOLETE | Replace with hub.zig; retain useful scene/spring/canonical mechanisms |
| src/app/engine_lab/main.zig | KEEP AND ADAPT | Direct startup; navigation; persistent GPU services; hub smoke |
| src/app/engine_lab/actions.zig | KEEP AND ADAPT | Movement intents, destination shortcuts, reset-safe input |
| src/app/engine_lab/view.zig | KEEP AND ADAPT | Persistent world, actor, camera-relative help and both stations |
| src/debug/debug_draw.zig | GENERAL PRODUCTION FIX REQUIRING EXPLICIT JUSTIFICATION | Keep existing glyph correction unchanged: required for readable controls, with public-output tests |
| tests/engine_lab_tests.zig | REPLACE | Real hub/controller/collision/lifetime tests replace selection/registry tests |
| tools/checks/architecture.ps1 | KEEP AND ADAPT | Preserve real source/build dependency closure; describe hub boundary |

No central roadmap/status document, dependency version, production API or legacy
application is changed. The glyph fix is retained from the first commit; it changes
neither buffer capacity nor ownership and is exercised by the final hub.

## Final hub and lifetime

The executable directly constructs one Hub and starts its fixed clock running.
There is no selector, registry, descriptor, stable lab ID, per-lab session or
switch lifecycle. The old labs.zig file is explicitly deleted. hub.zig owns the
concrete world; verification.zig contains only the bounded verification fixture.
CLI --list and --lab are removed, with unknown arguments rejected. The only
options are --help, --seed, --verify and --smoke. Verification and smoke cannot
be requested together.

The foundation spans x=-8 to +8 metres, with ground, enclosing side walls and a
0.6-metre raised central platform. The actor begins at (-4.5, 1.05). Production
CharacterController uses its current 240 Hz defaults: gravity -28 m/s^2,
maximum horizontal speed 4.5 m/s, jump velocity 9 m/s and a swept AABB with
half extents (0.3, 1.05). This gameplay collider is not a silhouette collider or
a full ragdoll. Collision and root movement are entirely CPU-owned. Input is
converted to CharacterIntent before reaching the hub. CharacterInstance selects
idle/walk/jump/rise/fall/landing clips and advances procedural motion, foot planting
and landing response. Its current fifteen-part HumanoidDefinition and the existing
renderer color atlas are provisional production assets, not canonical-generated
character content. Facing uses the supported mirrored representation and layer order.

The camera follows horizontally using HorizontalFollower's 0.9-metre dead zone,
clamps its center to [-5,5], and retains y=2.1. The established renderer owns
drawable-derived scale. Ground marks, platform/walls and station labels provide
spatial reference. Installations stand beside their destination positions so their
mass/line diagnostics are visible next to the actor at the default scale.

| Part | Production system exercised | Persistent state |
| --- | --- | --- |
| Controlled actor | CharacterInstance, CharacterController, CollisionWorld, authored clips, animator, procedural motion and foot planting | Controller root/contact state, facing, pose, animation and procedural state |
| F1 hierarchy station, x=-5.8 | RuntimeScene spawn/promotion, stable identity resolution, parent/child world transforms and snapshot lease, plus production springs | One persistent root and three child anchors, spring positions/velocities and history |
| F2 damping station, x=+5.8 | Same real scene identity/hierarchy path; production scalar springs with damping 0.5, 4 and 12 | Independent continuously updated springs and a bounded recent-history graph |
| Presentation | CharacterInstance.submitUnified, UnifiedRenderQueue, debug CommandBuffer, Camera2D and SDL GPU D3D12 renderer | Application-owned render queues, window/device, texture pages and GPU buffers |
| Verification | Fixed-step clock, canonical Writer, domain-separated SHA-256 and explicit seed | Actual hub logical checkpoint state |

The eight generic scene entities are static installations, not actor authority.
Their world positions are copied from a validated RuntimeScene snapshot during
construction and the lease is released immediately. Both sets of production
springs step every fixed tick, even off-screen. The first station's damping values
are 1.2, 3 and 7; the second exposes contrasting damping and recent motion. Seeded
initial offsets and periodic velocity impulses keep the real spring behavior visible.
The histories are bounded presentation data, excluded from the logical hash.

Window/device/renderer, PlatformInput, View and its preallocated extraction queue
live outside the Hub. The hub owns its actor, immutable definition/clip allocations,
CollisionWorld, RuntimeScene, stations, camera/follower, fixed clock, seed and local
counters. Destruction releases scene state, actor, colliders, clips and definition;
application shutdown then uses the production renderer's measured destruction path.
Each partial initialization uses explicit rollback. A failed reset leaves the
original world live because a complete replacement is constructed before teardown.

No production API was added or changed by the corrective pass. The existing general
glyph correction is the only shared production-source change across the full two
EL1 commits. It corrects bitmap orientation and distinguishes numeric glyphs, is
used by every HUD label, and is checked through submitted public glyph geometry.
The 121-byte white.png remains the actual neutral texture for geometry and HUD;
its existing manifest record and content are retained without change.

## Navigation, input and deterministic reset

A/D or left/right arrows move; Space jumps. Gamepad left stick and south button
feed the same intent path. Ordinary movement and a jump across the central platform
reach both regions. F1 and F2 are optional destination shortcuts to x=-4.5 and +4.5.
They respawn the same actor through resetControlled/stageControlledTransform, reset
its controller/foot/animation state and velocity, and snap the camera beside the
chosen installation. They do not reconstruct the hub, scene, collider storage,
station springs/history, fixed clock or GPU services. Actor identity and shared
representation resources are retained. Navigation logs the current hub tick and
checks that both station update counters are unchanged by the operation.

P toggles pause; T requests one fixed tick while paused. F3 toggles collision/hash
diagnostics. Escape exits. R reconstructs the complete hub using the same explicit
seed: actor, camera, stations, tick/accumulator, pause/single-step, pending intent,
visit/jump/landing/contact counters and diagnostic/history state return to their
initial values. Reset starts running. It does not recreate the platform or GPU.
Renderer/window lifetime counters intentionally continue through hub resets.

The input mapper latches short action/jump key presses, consumes jump edges once,
and suppresses held keyboard, gamepad jump and analog movement after reset,
destination travel or focus loss until the relevant input is released/neutral.
The reset frame advances zero simulation time. The window's current drawable
viewport is reapplied for presentation after deterministic camera reset.

## Headless verification and allocation proof

--verify constructs the actual hub with seed
0123456789abcdef0123456789abcdef unless --seed supplies another canonical 128-bit
seed. A bounded movement/jump schedule runs 1440 ticks. Movement is rightward for
720 ticks then leftward; jumps occur at ticks 240 and 960. The same fixture runs at
60 Hz and repeating frame durations of 1/240, 3/240 and 1/120 seconds, with edges
aligned to common fixed-tick boundaries. Checkpoints at ticks 0, 480, 960 and 1440
must match after whole-hub reconstruction. Both station regions must be reached,
both installations must update at every tick, and jumps, landings and wall contacts
must occur. No destination shortcuts are used by this movement proof.

Fingerprint schema 2 selects controller position/velocity/contact/tick state,
facing, animation state/time, jump/landing counters, static collision bounds,
scene anchor identities/world positions, seed, spring configuration/offset/target/
velocity, station update counters, region visits and the fixed hub tick. It uses
explicit canonical field and array order. It excludes addresses, allocator behavior,
GPU state, pixels, wall time, transient OS input, camera/UI and presentation history.
It is selected logical evidence, not a complete checkpoint/restoration format or
a claim of cross-platform floating-point identity. There are no recording/replay
files, rollback, networking or general snapshot framework.

Sixteen headless tests replace the old registry/switching suite. They cover direct
construction; deterministic seed sensitivity; real scheduled movement and frame
schedules; both enclosing walls/facing; gravity and landing on the raised platform;
concurrent station updates; allocation-free navigation preserving resources and
clock; whole-hub reset; pause/single-step edge consumption; render/hash independence;
steady-state simulation/extraction/navigation; failed reset preservation; every
partial construction allocation boundary; keyboard/gamepad/focus suppression;
short action/jump taps; and retained glyph output. Float tolerances explain their
relation to f32 arithmetic or the production contact epsilon. No tests are disabled
or weakened. Obsolete registry ordering and disposable-session switching tests are
removed because their architecture no longer exists.

Steady-state tests freeze allocator growth after construction/warmup, then execute
360 frames of actual actor/station simulation, extraction, diagnostics and navigation.
All allocations/resizes would fail; none occur. The production queue's allocation
counter stays zero. The actor's fifteen submissions are copied with only the
interpolated root translation delta, leaving controller and pose authority untouched.
The final queue has three texture ranges (world page 1, actor page 0, diagnostics
page 1), not one draw per body part. CPU bone pose remains the current fixed pose;
only root and station scalar motion are interpolated for presentation.

## Commands and owner review

Use PowerShell from C:/Users/Chad/Documents/2d Renderer-engine-lab-el1 and the pinned
.deps/zig-0.16.0/zig.exe. All reported builds use -j1 and the existing worktree-local
global cache argument --global-cache-dir .zig-cache/el1-global. Dependencies remain
Zig 0.16.0, SDL 3.4.10 and DXC 1.9.2602.24; no dependency or canonical-byte policy
change is included. Runtime assets and DLLs install next to zig-out/bin/engine_lab.exe.

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 --global-cache-dir '.zig-cache\el1-global'
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 --global-cache-dir '.zig-cache\el1-global' -- --verify
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 --global-cache-dir '.zig-cache\el1-global' -- --smoke
```

Owner review: confirm direct startup and readable controls, walk right into the
central platform to see blocking, then jump across it and continue to the second
station and right wall. Walk/jump back. Inspect facing, animation, gravity, camera
follow, collider outlines (F3), and both station histories continuing over time.
Use P and confirm the tick/hash stays fixed; T must advance exactly one tick; P
resumes. F1/F2 must reposition the same actor without clearing station state or
hub time. R must return the starting actor/camera/seed/station state and running
clock, without recreating the renderer. Escape must produce the balanced shutdown
marker. A physical gamepad review remains owner work.

Owner visual AND architectural acceptance is PENDING. In particular, review the
provisional specialized actor composition alongside static F-backed stations. This
corrective pass does not claim the future canonical-generated runtime actor, the
full future hub, a gameplay vertical slice, or generalized recording/replay.

## Scope boundary

Existing sandbox demonstrations and engine_smoke retain their original clients and
builds. Engine Lab imports mature production APIs only. Source/build dependency
closure checks reject production-to-EL1 dependencies and EL1-to-demo, engine_smoke,
evidence and canonical-human paths; both tests and CLI verification have a headless
module closure. The checks validate dependencies rather than old type-name spelling.
No central roadmap/status document is changed.

EL2, later hub facilities, baseball, interactions/choreography, secondary-motion
expansion, effects/projectiles, world time/weather/water, traversal, inventory,
canonical-human/HM08/morphology/skinning and all 3D/editor work remain deferred.
The current actor uses the existing colored segmented representation, including its
current idle arm pose and gameplay collider; art/silhouette acceptance is not implied.
No new production API, broad redesign or additional roadmap lane was needed.

## Interactive evidence and review limits

The final native window was inspected through the computer-use window API. Direct
startup showed the actor, the left installation, ground/platform reference and
accurate controls. F2 showed the right installation and its history graph; the
travel log retained hub tick 37500. P froze the tick; T visibly advanced one tick;
F1 while paused retained tick 42035 and existing station motion state. P resumed.
R returned to the initial actor/camera/left-region state and reproduced the exact
initial SHA-256 aeec6a019b227aa02f6500735b0f12d2e8ac2e2a87142fb08687bfabb30d86da.
F3 exposed actual collider outlines and the selected-state hash. Escape returned
exit 0 after 33259 rendered frames with resources 25/25, fences 33261/33261 and
zero queue allocations after warmup. Evidence log: .tmp/el1-correction/manual-final.log.
The native window retains the shared renderer's existing window caption; the HUD
identifies Engine Lab.

The desktop input API exposes brief key taps without a held-key operation. Taps
exercised action controls and a jump/landing visual during an earlier inspection,
but did not establish sustained manual keyboard traversal. Physical walking,
platform crossing, facing, gravity/collision and continuous camera tracking are
therefore automated controller/native-smoke evidence, with sustained interactive
keyboard travel and physical gamepad review still due from the owner using the
procedure above. No screenshot or automated test is called owner acceptance. This
is the validation limitation permitted by the corrective prompt; it is not hidden
as a manual pass.

## Corrective validation history

The first combined focused build exited 1 due to three test-only Zig compile errors:
a missing try on an error-union boolean, an illegal discarded captured error value,
and an inferred anonymous struct that did not coerce to RawInputState. These were
corrected without disabling tests or relaxing assertions. The independent executable
already compiled in that invocation. Subsequent focused runs passed 16/16.

A presentation inspection found that changing Camera2D scale alone is overwritten
by the renderer's authoritative drawable-derived scale. The final layout uses the
existing renderer contract and places installations beside their destination
positions. The attempted zoom is absent from the final source; no renderer API or
shared scale policy was changed. Final focused and aggregate runs cover that source.

The first EL1 commit's prior validation remains historical evidence in commit
93303802692459ac0449a17586e9b78085d4bf9e; its selectable-environment behavior is
superseded. This pass uses the existing worktree's validated canonical-byte inputs
and task-local cache. It does not change line-ending policy, canonical fixtures or
protected hashes, rerun destructive checkout recovery, or treat normalization as
permission to weaken canonical validation.

## Final native and deterministic results

Final direct commands (exit 0):

```powershell
& '.\zig-out\bin\engine_lab.exe' --verify
& '.\zig-out\bin\engine_lab.exe' --smoke
& '.\zig-out\bin\engine_lab.exe'
```

The final CLI verification reports ENGINE_LAB_HUB_VERIFY_OK with 1440 ticks,
two reached/coexisting stations, two jumps, three landings and 403 wall-contact
ticks. Its four matching checkpoints are:

| Tick | SHA-256 |
| --- | --- |
| 0 | aeec6a019b227aa02f6500735b0f12d2e8ac2e2a87142fb08687bfabb30d86da |
| 480 | c205e01d59dd6625bc62efc5a719d26e93204630b24b03ff4a6a3c880c1d09aa |
| 960 | c048898023e2a07f6d6dce9928688287a6c368712e27167616e2647ec56ff8dc |
| 1440 | f676e07914eb108d49e85cc182fba14256c2328c3856cd82922f30ada834886c |

Final native smoke reports ENGINE_LAB_HUB_SMOKE_OK on direct3d12/DXIL:
180 frames, 540 draws, 55620 changed readback pixels; movement, jump and collision
observed; destination travel at hub ticks 420 and 533 retained station state;
whole-hub reset reproduced the tick-0 hash. Resources balance 26/26 and fences
183/183, with zero queue allocations after warmup and no steady GPU growth.
Smoke final tick 116 and visits {true,false} are post-reset state, not the total
coverage counters. Logs are .tmp/el1-correction/cli-final.log and smoke-final.log;
these generated logs stay ignored and outside the commit.

## Aggregate validation and Git review

The exact final focused/normal/complete commands below returned exit 0:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' version
& '.\.deps\zig-0.16.0\zig.exe' fmt build/apps.zig build/modules.zig build/tests_engine.zig src/app/engine_lab tests/engine_lab_tests.zig
& '.\.deps\zig-0.16.0\zig.exe' build test-engine-lab engine-lab -j1 --summary all --global-cache-dir '.zig-cache\el1-global'
& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all --global-cache-dir '.zig-cache\el1-global'
& '.\.deps\zig-0.16.0\zig.exe' build verify -j1 --summary all --global-cache-dir '.zig-cache\el1-global'
```

Observed results: compiler 0.16.0; formatting completed; focused 14/14 build steps
and 16/16 tests; normal 21/21 steps and 400 tests across ten roots; complete verify
92/92 steps. The full gate includes canonical/content, sandbox compilation, the
1000-handshake and 100000-integrated-tick stress tests, production integration,
formatting, architecture, repository hygiene and documentation. All returned zero;
no failure was disabled or normalized away. Logs: focused-final.log, test-final.log
and verify-final.log under .tmp/el1-correction.

The static gate inspected 366 implementation/policy files. Dependency closures have
54 modules for the executable, 44 for tests, and 39 for CLI verification. Production
import direction and the windowless test/verification boundary passed. Documentation
reported 46 required files, 42 Markdown files and 95 local Markdown targets.

The corrective and full-base review covers every original EL1 file and both new
sources. The five retained files have an empty corrective diff. The white texture's
SHA-256 remains 05c218270c2b2011372507266fa5d4f8d234a911165be8d33396073242b7c2a6.
The final source/build/current-user-guide scan finds zero obsolete lab-registry,
disposable-session or selection references. Historical explanation in this report
identifies what was removed; it does not document an available compatibility mode.
Engine Lab sources/tests have zero TODO, FIXME, unreachable and skipped-test markers.
No empty implementation, stub or unconditional success substitute was found. Empty
switch branches represent frames with no scripted control action, not missing code.
The diff has no whitespace errors, generated logs, dependency changes, canonical
fixture edits or unrelated line-ending conversions.

Pre-commit owner recheck: C:/Users/Chad/Documents/2d Renderer remains clean on master
at cb60fc9a9b24ba7d69578ffc721948e9b00de8fd. The index SHA-256 still exactly equals
AA2979907CB6C298268E02C01E706369D6C8ECACB65406E3F1F515F7234271D8. The delivery is one
additional focused commit on feature/engine-lab-el1, preserving original commit
93303802692459ac0449a17586e9b78085d4bf9e as its parent. Final commit identity and
post-commit clean/owner checks are returned in the completion response; no
self-referential commit hash is embedded in this file.

The separately required recovery/default/native-client commands also returned exit 0:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-base test-canonical-human-geometry-scaffold test-canonical-human-geometry-refinement test-canonical-human-geometry-adoption test-canonical-human-geometry-r4 -j1 --summary all --global-cache-dir '.zig-cache\el1-global'
& '.\.deps\zig-0.16.0\zig.exe' build -j1 --summary all --global-cache-dir '.zig-cache\el1-global'
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-smoke -j1 --summary all --global-cache-dir '.zig-cache\el1-global'
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 --summary all --global-cache-dir '.zig-cache\el1-global' -- --verify
```

Recovery passed 37/37 steps and 121 tests across thirteen roots, including R3 through
R4's dependency chain; default installation passed 22/22 steps. engine_smoke passed
24/24 steps with six D3D12 frames/draws, 15129 changed readback pixels, a valid
world-persistent F entity, publication generation 3, resources 17/17, fences 8/8 and
zero steady queue allocations. Engine Lab's run/verify target passed 13/13 steps
with the same final hub checkpoints. Logs: recovery-final.log, default-final.log,
engine-smoke-final.log and run-verify-final.log under .tmp/el1-correction.

Final formatting/static and diff-review commands are:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' fmt --check build/apps.zig build/modules.zig build/tests_engine.zig src/app/engine_lab tests/engine_lab_tests.zig
& './tools/check_repository.ps1'
& './tools/check_documentation.ps1'
git --no-optional-locks -c safe.directory='C:/Users/Chad/Documents/2d Renderer-engine-lab-el1' -c core.safecrlf=false diff --cached --check
git --no-optional-locks -c safe.directory='C:/Users/Chad/Documents/2d Renderer-engine-lab-el1' -c core.safecrlf=false diff --cached 93303802692459ac0449a17586e9b78085d4bf9e
git --no-optional-locks -c safe.directory='C:/Users/Chad/Documents/2d Renderer-engine-lab-el1' -c core.safecrlf=false diff --cached cb60fc9a9b24ba7d69578ffc721948e9b00de8fd
```

There is no unresolved source/test/build failure. The only validation deviation is
the explicitly reported limitation on sustained manual keyboard input; owner
visual/architectural acceptance and physical gamepad review remain outstanding.
EL2 was not started. Nothing was fetched, pulled, merged, pushed, rebased, amended,
reset, cleaned or stashed in this corrective pass. No owner file, index, branch or
HEAD was modified. Only the requested feature-worktree correction is committed;
no worktree or branch is removed and no other roadmap lane is begun.
