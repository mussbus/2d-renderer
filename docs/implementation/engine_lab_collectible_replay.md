# Bounded Engine Lab collectible replay

Status: implemented and validated on `feature/engine-lab-integration`, ready for independent review. Independent acceptance remains pending. Prior owner acceptance of traversal, zoom, collectibles, PSM01, World Time and projectile integration is unchanged.

## Baseline and authority

Starting commit `f2ff67a9832e9bdbabd3c2fa0bf089dd313f124c` was clean in `C:\Users\Chad\Documents\2d Renderer-engine-lab-integration`. Its reviewed source aggregate is `cc7aeb19037625cd219edc2e9daa9a6e2adec1bd8bb7f0438927115ea322b812`, over 376 inputs, using sorted UTF-8 Git paths plus NUL plus the raw 32-byte SHA-256 of each checkout file. No text normalization is used.

Immutable contract: `.tmp/engine-lab-replay-contract/engine-lab-replay-contract-review-v2.zip`, 726,531 bytes, SHA-256 `93b9ea5363cd0f5b70873e5c6cd712599179854caf8cecfc29981308a142b799`. All 165 members were verified. Its contract, field audit, storage calculation, source inventory and public one-tick probes are preserved. Those probes established course feasibility; they were not replay implementations or replay validation.

The implementation uses accepted [RR1](rr1_record_replay.md), [collectibles](engine_lab_collectibles.md), [traversal and zoom](engine_lab_traversal_expansion.md), [World Time](engine_lab_world_time.md), [PSM01](engine_lab_psm01_calibration_binding.md), [projectile integration](engine_lab_projectile_impact.md), [eight-projectile correction](engine_lab_multi_projectile_follow_up.md), [EL1](engine_lab_el1.md), and [checkout-byte policy](reproducible_windows_checkouts.md). Their source, test and GPU evidence retain their original identities. No earlier visual evidence is a fresh replay result.

Pins verified: Zig 0.16.0, SDL3 3.4.10, DXC 1.9.2602.24. Windows / SDL3 GPU / D3D12 / HLSL-DXIL remains the application baseline. The new proof initializes no SDL or GPU. Local master began at `1f8d2f3e01102285e76d02a788b7adb5f992087f`; recorded upstream was `37d11c8e3a7e2f67e210df0bb71000efdbbee793`. Morphology, Model Lab and capture refs had advanced since contract inspection; preflight records that movement without restoring or editing other tracks.

## Implemented boundary

A fresh heap-owned `Hub.initExpanded` uses seed `0123456789abcdef0123456789abcdef`, actor ID 1, spawn (-4.5, 1.05), facing right and layer 0. The accepted nine-collider expanded layout, controller properties and provisional production actor remain unchanged. World Time begins on day 0 at 86,340,000,000 microseconds (23:59), simulation 240 Hz, rate 60/1, day length 86,400,000,000 microseconds, fractional carry 0.

The recording contains exactly 1,469 dense records: one neutral StartChallenge/birth record, the existing 1,188-tick course, and 280 return/drain ticks. A route cursor generates recording commands only; it increments after a successful adapter step. Playback reads a decoded, immutable RR1 Session. The playback adapter imports no route generator and never injects outcomes, restores recorded state or applies checkpoint digests to the Hub.

Observed production results are four jumps, one dash, five landings, six collections, complete challenge, and drained effects. Collection completed-Hub ticks are 53, 277, 461, 653, 943 and 1137 (records 52, 276, 460, 652, 942 and 1136). These are assertions against execution, not inputs to it. Existing stations, calibration, World Time and the empty impact installation execute normally.

One running call executes `Hub.advanceFrame(fixed_dt_seconds, intent)`. One paused step requests the existing single step, then calls `Hub.advanceFrame(0, intent)`. Wait and paused run return without calling Hub or Player.next; they cannot latch edges or advance the recording route. A running single-step request is terminally invalid. Groups [1], [4] and repeating [1,3,2] contain separate adapter invocations, each executing at most one tick. This proves invocation-group independence, not arbitrary frame scheduling.

Before mutation the adapter checks supported clock configuration, zero accumulator/discard, no pending step/action edges, subsystem alignment, causal command shape, and known recording/checkpoint capacity. Candidate names include only possible transitions whose names have not already been emitted. After execution it verifies one substep, consumed edges, and tick relationships. At EOF it executes no additional tick; repeated calls preserve state and cursors.

All errors latch the first failing record and stage. A Hub error may leave real partial execution; no retry, rollback, reset or continuation is attempted. Playback ordering is actual observations, Player.observe, contributor capture, Player.verify, then application checkpoint placement checks. A capture failure after an observation mismatch retains the observation diagnostic and capture error, with verification_completed=false and no invented digest. RR1 event/state/named diagnostics remain owned by the Player; the application adds placement and capture diagnostics.

## Shared API and review corrections

The only shared production change is `CharacterInstance.animationPlaybackSnapshot(*const CharacterInstance) AnimationPlaybackSnapshot` in [character.zig](../../src/scene/character.zig). The copied value contains `current_state_index: u16`, the complete `animator.PlaybackState`, and optional complete `animator.TransitionState`, including both playback sides and both transition policies. It allocates nothing, returns no borrowed or mutable internal pointer and contains no Engine Lab or RR1 semantics. Native size is 128 bytes, alignment 8; compile-time budgeting checks enforce the reviewed reservation. Registered character tests exercise ordinary playback, looping/completion/fallback, real transitions with both policy settings, independent copies and no allocations.

The three explicit review corrections are implemented:

1. C5 encodes the actual `Transform2D`: translation Vec2, rotation_radians f32 and scale Vec2, exactly 20 canonical bytes. C5 is **4,419 bytes**, never a substituted matrix.
2. RR1 can allocate an initial payload up to 1,024 bytes before the application enforces exactly 88. Valid capacity Session payload is **967,632 bytes**; the permitted larger envelope raises it to **968,568**, or **968,944 including the 376-byte owner**. The extra **936 bytes** are included in the failure-path budget. The real decoder is unchanged.
3. Observations are supplied before state capture. The combined mismatch/capture-failure test proves the earlier mismatch survives and verification does not occur after capture fails.

Two additional source-derived accounting/alignment corrections were found while implementing the audited fields:

- Bridge Metrics has **seven** u64 fields, all listed in FIELD_COVERAGE.md, although the reviewed arithmetic said six. All seven are encoded and checked, including truncated_segments. C11 is **220 bytes**, eight more than 212. No metric was dropped to fit the estimate.
- Production `StepResult.simulation_tick` denotes starting controller tick N. Completed controller/actor/Hub/subsystem counters denote N+1. The adapter preserves that actual StepResult value and checks its one-tick offset. The initial StepResult is zero. Production behavior is unchanged.

## Canonical state and schemas

The implementation follows the reviewed field order, with the corrections above. Integers are explicit little-endian values; usize narrows with a check to u32. Stable ID enums retain their declared widths; other semantic enums use u8 and Bend uses signed i8 (-1/+1). Floats are finite, signed zero canonicalizes to +0, and no quantization/tolerance enters replay. Optional values have tags; dynamic sequences have u32 lengths; fixed arrays do not gain a length. Only initialized event/history prefixes are read.

| Contributor | Coverage | Canonical upper bound |
| --- | --- | ---: |
| C1 | Streaming content identity | 32 |
| C2 | Actor read, complete controller, pending intent, actual last physical result | 231 |
| C3 | Copied playback/transition state and valid emitted animation events | 1,382 |
| C4 | Procedural state, feet, persistent restoration locals and lifecycle history | 838 |
| C5 | Actual Transform2D, evaluated pose, appearance, presentation and inactive guards | 4,419 |
| C6 | Both station configurations/responses and initialized physical ring slots | 1,760 |
| C7 | Calibration driver, response and previous references | 48 |
| C8 | Complete World Time snapshot and exact fractional carry | 52 |
| C9 | Phase/run/progress/timing, observed prefix and retained effect IDs | 319 |
| C10 | Seed, copied emitters, every particle, definitions, IDs, ordinals and metrics | 14,786 |
| C11 | Empty projectile/impact installation, advancing ticks and all seven bridge metrics | 220 |
| C12 | Hub tick, visited flags and counters | 26 |

Nominal observed maxima are [32,230,122,712,4419,1760,48,52,319,2511,220,26]. Optional values and live-particle counts explain the difference from maximum capacity. The largest reserved contributor fits the reused 16,384-byte canonical buffer.

Content uses the reviewed domain-separated H0/record/end fold. Each record includes previous digest, little-endian record/section/element indices, length-prefixed field path and canonical value. Sections cover bootstrap, actual world colliders/layout, installation IDs/anchors, skeleton, appearance/attachments, clips/state machine, named visual constants and bindings, stations, calibration/World Time, collection/effect derivation inputs and inactive impact configuration. Immutable lookup/evaluation-order arrays are included; allocator and compatibility/owner tokens are excluded. Source SHA-256 is evidence only and is never mutable-state authority. Content is computed at construction and rechecked at successful completion.

Application version 1: envelope/command/causal/observed IDs 0x454C0101..0104, StartChallenge 0x454C0201, Jump/Dash/Land/Collect 0x454C0301..0304, contributors 0x454C1001..100C. Scenario UUID `1326918e-056e-5844-8045-3001cf7b07cf`; generator `588a012e-bac2-526e-b0b6-d5a9a58be794` and algorithm `ba014e85-8d7b-5879-89df-7ef3d860f13b`, both 1.0.0. No registered source identity collision was found.

The exact 88-byte envelope follows scenario/content/seed/count/actor/spawn/facing/construction/reserved/hz order. Commands contain f32 axis plus four flags in five bytes. StartChallenge has an empty payload at record 0 only. Observations encode jump source (1 byte), dash (empty), landing speed (4 bytes), and collection run/ID/ordinal/completed tick/position/segment (28 bytes). Causal actions remain separate from observed outcomes.

Named checkpoints are exactly run_started, collected_1..6, challenge_complete, effects_drained and final_state. Actual placement is separately verified in addition to RR1's digest checks. Their production record indices are 0,52,276,460,652,942,1136,1160,1256,1468. Simultaneous names use lexical ordering.

No pointer, padding, allocator internals, undefined tail, source-only state hash or stale generic RuntimeScene actor transform enters the fingerprint. Borrowed actor views end before the next mutation or destruction. Animator scratch poses remain excluded under sample-from-rest overwrite-before-use; foot restoration locals are included. Absence of anatomy/component graphs/equipment/properties/overrides/interaction/arm IK and secondary profiles is checked under the fresh exclusive lifecycle. Static RuntimeScene installation ownership is not dynamic actor publication.

Collection effects use burst12, rate0, duration1, lifetime120, six emitters/72 particles. Four RNG draws per particle produce the synchronous burst (48 draws per emitter); this lifecycle admits no later RNG draw. Seed/derivation inputs, emitter/particle IDs, ordinals and resulting complete state are retained. The known ID inventory must equal actual emitter count; particle identity ordering requires every ordinal exactly once per live emitter. Orphans, moved/missing emitters and inconsistent definitions/ages are rejected. Normal retirement is supported. No private RNG accessor or shadow simulation is used. Private inactive projectile next_id=1/next_event=0 are reconstructed only while enforcing no spawn/event/action lineage and recording actual advancing ticks.

## Storage and allocation

Owners/scratch are allocated during initialization. Capacities remain 2,048 ticks, one cause, 8,192 observed events (at most four per tick), ten names and twelve contributors. Native measurements:

| Item | Bytes |
| --- | ---: |
| Heap Hub value / its initialized owned heap | 39,168 / 91,890 |
| Adapter value | 208 |
| Scratch aggregate (including copied animation) | 34,112 |
| Session owner / Player owner | 376 / 440 |
| Valid recording Session payload | 967,632 |
| Nominal decoded Session payload | 178,664 |
| Artifact buffer capacity / written nominal artifact | 344,976 / 88,079 |
| Nominal recording live owned payload | 1,478,362 |
| Nominal playback live owned payload, excluding caller's input artifact | 344,858 |
| Maximum decoded-envelope Session payload plus owner | 968,944 |

The implementation allocates one naturally aligned scratch aggregate instead of the proposal's separately rounded slots. Its measured 34,112 bytes includes canonical storage, particles, emitters, twelve contributors, observations, cause, candidate names, envelope, actor copies and two twelve-element length arrays. The 208-byte adapter separately owns its failure/control fields; a Player is allocated only for playback. These measured figures replace the provisional 34,172-byte scratch/control reservation, not the contributor or capacity contract. No unbounded tick trace is added. Recording tests may retain another adapter/artifact for comparison; these separate test allocations are outside tick loops.

Allocation instrumentation counts attempted alloc, resize, remap and free calls, including failed attempts. Full recording and playback loops (including state capture and final content recheck) show zero added operations. Encoding uses the preallocated buffer and written prefix; decoding and all acquisition/teardown operations are accounted separately. Both initialization modes reach success after 173 tested allocation boundaries, with balanced cleanup at every injected failure. A correctly checksummed 2,048-record/8,192-observation/1,024-envelope artifact is 278,328 bytes, allocates the maximum 968,944-byte owner-inclusive decoded Session, then is rejected by application envelope validation with complete cleanup. All five decoder allocations are failure-tested.

These are owned-payload counts, not process working set, allocator metadata/page rounding or compiler stack-frame measurements. No new large automatic pose/particle/canonical array is introduced; the existing large challenge diagnostic fingerprint is not called. The allocator audit casts only its own allocator-vtable context, never private simulation storage.

## Tests and reproduction

The focused runner `test-engine-lab-replay` is registered in the fast engine aggregate and has 17 tests. It covers full production round trip and exact bytes, repeated recording, all invocation groupings, pause/wait/step/resume/EOF, initial validation, resealed tampering, actual event/state/name divergence, combined observation-plus-capture failure, capacities, all twelve contributors, inactive features/orphans, initialization/decoder failure cleanup and a real partial Hub overflow. A test-local application helper invalidates a Session after successful preflight and a real completed Hub tick, proving unexpected append failure is terminal; it exposes no shared production accessor. Existing RR1 tests and golden bytes remain unchanged. Two snapshot tests run through the registered deterministic root (283 tests total).

Run from this worktree using a new output filename. These commands use the existing focused test-runner pattern, without a live replay UI or new GPU application:

```powershell
New-Item -ItemType Directory -Force -Path '.tmp/engine-lab-collectible-replay' | Out-Null
$replayBuildOptions = @('-j1', '--summary', 'all', '--global-cache-dir', '.tmp/projectile-impact/global-cache', '--cache-dir', '.tmp/engine-lab-collectible-replay/cache', '-p', '.tmp/engine-lab-collectible-replay/install')
& '.\.deps\zig-0.16.0\zig.exe' build test-engine-lab-replay @replayBuildOptions '-Dengine-lab-replay-test-filter=write recording' '-Dengine-lab-replay-output=.tmp/engine-lab-collectible-replay/reproduction.Debug.rr1'
& '.\.deps\zig-0.16.0\zig.exe' build test-engine-lab-replay @replayBuildOptions '-Dengine-lab-replay-test-filter=play recording' '-Dengine-lab-replay-input=.tmp/engine-lab-collectible-replay/reproduction.Debug.rr1'
```

The playback command reads the serialized file before initialization. It does not generate a fallback route when an input path is supplied. Without an input path, the ordinary test constructs its own recording fixture. Output writing occurs only after completed recording/encoding, outside simulation execution. Add `-Doptimize=ReleaseSafe` or `-Doptimize=ReleaseFast` for that profile; determinism claims are limited to profiles actually verified.

Task evidence is under `.tmp/engine-lab-collectible-replay/`: exact command/exit/source ledgers and raw logs, immutable prior-package references, source and runner identities, serialized recordings, corrected accounting, full-index patch, changed snapshots, manifest, ZIP and external receipt. Source aggregation covers src/tests/build/build.zig/build.zig.zon/tools/engine_lab_impact_review.py. Documentation, architecture scripts and task-local runners/probes are identified separately, never implied to be in that aggregate.

Development failures are preserved: initial new-code syntax/name/API errors, the incorrect StepResult alignment assertion, and its test-fixture cleanup omission. Later fixes have their own logs and source associations. The initial allocation leaks were from a test returning before its missing defer, corrected before cleanup acceptance. A private-module test was not initially scheduled; the registered root now invokes its bounded failure helper explicitly. Packaging validation is not a new behavioral gate. No historical failure or GPU result is relabeled.

## Final automated validation

Final implementation source: `a428f4447f70aa43320d518a7b3fa3ecbd5feba5839e16294550e59e2cd8d335`, **381 inputs**, frozen before the required matrix. All commands below exited zero against that source. Exact commands, raw output, optimization mode, runner identities and compile/run cache status are retained in the task-local command ledger.

| Gate | Observed result |
| --- | --- |
| final-focused-Debug | 444 tests; 4 executed test roots, 0 cached test roots; Build Summary: 13/13 steps succeeded |
| final-focused-ReleaseSafe | 444 tests; 4 executed test roots, 0 cached test roots; Build Summary: 13/13 steps succeeded |
| final-focused-ReleaseFast | 444 tests; 4 executed test roots, 0 cached test roots; Build Summary: 13/13 steps succeeded |
| final-format | exit 0 |
| final-architecture | exit 0 |
| final-documentation-01 | exit 0 |
| final-checkout-01 | exit 0 |
| final-check-Debug | 673 tests; 16 executed test roots, 0 cached test roots; Build Summary: 42/42 steps succeeded |
| final-test-full-Debug | 771 tests; 22 executed test roots, 0 cached test roots; Build Summary: 55/55 steps succeeded |
| final-default-build-Debug | Build Summary: 24/24 steps succeeded |
| final-engine-lab-build-Debug | Build Summary: 11/11 steps succeeded |
| final-default-build-ReleaseSafe | Build Summary: 24/24 steps succeeded |
| final-engine-lab-build-ReleaseSafe | Build Summary: 11/11 steps succeeded |
| final-default-build-ReleaseFast | Build Summary: 24/24 steps succeeded |
| final-engine-lab-build-ReleaseFast | Build Summary: 11/11 steps succeeded |
| final-engine-lab-headless-verify | Build Summary: 13/13 steps succeeded |
| serialized-record-Debug | 1 tests; 1 executed test roots, 0 cached test roots; Build Summary: 4/4 steps succeeded |
| serialized-play-Debug | 1 tests; 1 executed test roots, 0 cached test roots; Build Summary: 4/4 steps succeeded |
| serialized-record-ReleaseSafe | 1 tests; 1 executed test roots, 0 cached test roots; Build Summary: 4/4 steps succeeded |
| serialized-play-ReleaseSafe | 1 tests; 1 executed test roots, 0 cached test roots; Build Summary: 4/4 steps succeeded |
| serialized-record-ReleaseFast | 1 tests; 1 executed test roots, 0 cached test roots; Build Summary: 4/4 steps succeeded |
| serialized-play-ReleaseFast | 1 tests; 1 executed test roots, 0 cached test roots; Build Summary: 4/4 steps succeeded |

The four focused roots contain 17 replay, 94 existing Engine Lab, 50 RR1 and 283 deterministic character tests: **444 per profile** in Debug, ReleaseSafe and ReleaseFast. Repeated identical recording and all three adapter invocation groupings were verified within each profile. Build cache reuse is compiler reuse, not a substitute for executed tests.

- Debug: `.tmp/engine-lab-collectible-replay/recording-Debug.rr1`, 88,079 bytes, SHA-256 `253a7b637b3cd45efbc81a6a12aafadec20aa3cf1464be197dadfcbc36fd8856`; independently written and read by the serialized playback command.
- ReleaseFast: `.tmp/engine-lab-collectible-replay/recording-ReleaseFast.rr1`, 88,079 bytes, SHA-256 `253a7b637b3cd45efbc81a6a12aafadec20aa3cf1464be197dadfcbc36fd8856`; independently written and read by the serialized playback command.
- ReleaseSafe: `.tmp/engine-lab-collectible-replay/recording-ReleaseSafe.rr1`, 88,079 bytes, SHA-256 `253a7b637b3cd45efbc81a6a12aafadec20aa3cf1464be197dadfcbc36fd8856`; independently written and read by the serialized playback command.

The three measured profiles produced identical artifact bytes on this pinned Windows toolchain. This observation does not claim determinism on untested compilers, architectures or profiles.

The final documentation closeout is outside the source aggregate and receives documentation and checkout-byte audits. It does not invalidate the unchanged source matrix. One local implementation commit is authorized after the gates and diff review; its exact parent/commit/status are in the review receipt to avoid a self-referential commit hash in this record. The review package reconstructs its full binary patch in an isolated index and compares every changed file byte-for-byte. Packaging checks are not new simulation tests.

## Limits and review boundary

No live input, navigation, reset/restart, teleport, equipment/content changes, zoom/camera input, projectile firing, rewind, restore, seek, multi-tick render-frame scheduling or arbitrary initial state is admitted. Pause and stepping are execution controls outside serialized commands. No whole-engine replay or dynamic generic actor publication is claimed. No dependency, gameplay, PSM01, World Time, renderer or RR1 protocol change is included. Independent review remains pending; prior owner visual acceptance is preserved and this headless task requires no new visual/gamepad acceptance. Nothing is pushed or merged.
