# World-time foundation correction

## Current disposition (2026-09-06)

The bounded World Time Foundation at
`89faed3b416e8d9aa4665e39ff72f5cb7ee93bb9` is accepted and present on master at
`d71c4ae439d0b04019734cd3f45b7a6366a6a00f`. See the
[current five-lane record](../project/CURRENT_STATE.md#accepted-post-f4-foundations-on-master-2026-09-06).
Acceptance covers deterministic caller-owned logical time and snapshots only.
Climate, weather, environment/application adoption and additional milestones
remain outside this scope. The candidate wording below records implementation
time and does not supersede this current disposition.

## Historical executive summary and review status

This is a **non-numbered feature slice pending owner review**. It retains only
deterministic, caller-owned, headless world-time accumulation. The corrected
vertical slice is explicit simulation progression -> advance world time ->
copy a complete snapshot -> inspect logical day index and time within the cycle.
No roadmap acceptance or Phase F completion is asserted.

The preceding prompt assigned an unapproved numbered identity and promoted
future climate/environment concepts into production contracts. This correction
removes that production experiment instead of treating its tests as architectural
approval. The authoritative roadmap and accepted base functionality are unchanged.

## Provenance and isolation

- Original base: `cb60fc9a9b24ba7d69578ffc721948e9b00de8fd`.
- Superseded local feature commit: `474ae300607b352962cb753f31e44c0b6327b03d`.
  Its source and original report preserve the removed experiment's provenance.
- Corrected branch: `world-time-foundation`.
- Existing physical worktree:
  `C:\Users\Chad\Documents\2d-Renderer-wt01-world-time-foundation`.
  This historical operational directory name is retained; it is not a milestone.
- Commit subject: `world: add deterministic world-time foundation`.
- Final amended commit is the containing commit of this corrected report.
  Its literal hash and post-amend verification are recorded in the local,
  untracked `.tmp/world-time-correction/final-state.txt` receipt and owner-facing
  completion report. A committed report cannot embed its own commit hash.
- Expected final history: exactly one commit above the original base, with that
  base as its only parent. The amendment replaces the previous feature commit;
  it does not add a second feature commit.

Before any tracked correction, the existing branch was clean at the exact
superseded commit, with exactly one parent at the original base and a one-commit
range. It had no upstream; no locally known remote ref contained it. The corrected
branch name did not exist and no worktree used it. These local checks do not claim
a fresh remote-server inventory; no fetch or other network Git action was used.

Primary-worktree observation before correction:

- Path: `C:\Users\Chad\Documents\2d Renderer`.
- Branch: `master`.
- HEAD: `cb60fc9a9b24ba7d69578ffc721948e9b00de8fd`.
- Index and working-tree status: clean.
- Index SHA-256:
  `AA2979907CB6C298268E02C01E706369D6C8ECACB65406E3F1F515F7234271D8`.

All eight worktrees were inspected read-only. The secondary-motion worktree
already contained owner changes in five tracked files plus one untracked file;
those changes were left alone. No implementation, formatting, staging, branch
switch, stash, or commit operation targets the primary or another feature worktree.
The current worktree alone receives correction writes. Post-correction
observations and final Git status are recorded after the validation gates below.

Existing pinned dependency installations are reused through the feature
worktree's existing junctions; there is no dependency update. The existing
task-local cache junction is also retained. Correction logs use
`.tmp/world-time-correction/`, separate from the original experiment's evidence.

## Pre-correction audit and classification

The complete base-to-feature diff, every world source/test, module registration,
engine test registration, aggregate gates, architecture policy, testing guide,
original implementation report, and applicable root instructions were inspected.
No nested instructions were found. Existing application frame measurement,
physics fixed-step scheduling, animation sampling, runtime snapshots, F primitive
identity/validation/error conventions, and deterministic rational timing were
reviewed. Tracked searches covered the old identifiers, world-time and removed
climate/environment type names, authored defaults, and environment resolution.

| Classification | Existing addition or decision | Corrective disposition |
| --- | --- | --- |
| KEEP | `WorldTime`, exact integral/rational accumulation, carry, validation, checked failure atomicity | Retain the narrow production world module and existing type name. |
| KEEP | Complete copied continuation state, derived day/time views | Preserve validated restoration without introducing serialization. |
| KEEP | `test-world`, module registration, fast/full CPU aggregate integration | Retain real headless build/test wiring. |
| RENAME | Local branch and implementation report | Normal local branch rename and Git-aware report rename; no directory move or new milestone. |
| REFACTOR | Module-owned paused state and setter | Remove both; caller supplies or withholds progression. Zero rate remains a numeric case. |
| REFACTOR | Pause-related time tests and documentation | Test zero progression, full-state failure atomicity, and carry-preserving continuation without pause ownership. |
| REFACTOR | Root exports, build descriptions, architecture policy, testing guide | Narrow to time; remove unused foundation imports left by the removed contracts. |
| REMOVE | `src/world/environment.zig` and `tests/world/environment_tests.zig` | Delete only files introduced by the superseded commit, including 15 behavioral tests. |
| REMOVE | `ClimateRegionDefinition`, `EnvironmentState`, `EnvironmentQuery`, environment export, authored-default resolution | No equivalent replacement API or hidden weather defaults. |
| DEFER TO OWNER REVIEW | Climate/weather authority, composition, selection, probability/seed semantics | Record open requirements below without production interfaces. |
| DEFER TO OWNER REVIEW | Pause/time domains, rate transitions, calendar interpretation, persistence, consumers | No runtime policy or integration added. |

The removed climate API had selected authored defaults as current conditions and
attached a query/state contract before authority, composition, and query semantics
were accepted. Temperature, wind, and precipitation validation alone could not
establish those semantics. Removal is authorized scope correction, not an attempt
to conceal failing tests: the entire pre-correction feature passed its own gates.

The old label is absent as an authoritative feature identifier. An unrelated
base64 asset contains a coincidental case-insensitive byte-string match; that
base-commit asset remains unchanged. Existing scene migration uses of authored
defaults and presentation/theme code also remain unchanged.

## Final public contracts, ownership, and dependencies

`src/world/root.zig` exports `time` and `WorldTime`. The `time` namespace exposes:

- `microseconds_per_second = 1_000_000`.
- `Rate { numerator: u32, denominator: u32 }`.
- `Configuration { simulation_hz: u32, rate: Rate, day_duration_us: u64 }`
  and configuration validation.
- `Snapshot` with configuration, accepted simulation tick count, day index,
  whole microseconds within the cycle, and submicrosecond remainder.
- `WorldTime.init`, `WorldTime.fromSnapshot`, `WorldTime.snapshot`, and
  `WorldTime.advanceSimulationTicks`.
- Snapshot validation, `totalWholeMicroseconds`, and `dayFraction`.
- Meaningful errors for invalid simulation frequency, rate denominator, day
  duration, within-day position, fractional remainder, simulation tick overflow,
  and world-day overflow.

Each instance owns one value state. Construction, advancement, observation, and
restoration allocate nothing. There are no resources to destroy, borrowed region
objects, global mutable state, ambient entropy, clock reads, callbacks, or
scheduler ownership. Snapshot reads return independent value copies through a
const receiver; changing a copy cannot mutate its source clock. Raw state mutation
is outside the supported API; constructors and every advance validate state.

The allowed engine dependency direction remains `world -> foundation`.
The corrected implementation needs only `std` and local `time.zig`; unused
foundation registration edges have therefore been removed. Architecture policy
permits only that downward engine direction and prohibits application, backend,
clock, and other upward dependencies. F remains unchanged and no parallel
identifier or time abstraction is invented inside it.

## Authoritative units, rate, cycle, and continuation

A supplied tick represents `1 / simulation_hz` simulation seconds. Rate
`numerator / denominator` maps accepted simulation seconds into world seconds.
One world second has exactly 1,000,000 world microseconds. These are numeric units;
there is no OS epoch, timezone, locale, or real-world calendar.

The independently configured `day_duration_us` is the number of world
microseconds in one logical day cycle. It projects accumulated world duration
into `day_index` and `time_of_day_us`; it does not set the progression rate.
There is no engine day-length default, 24-hour assumption, named phase boundary,
calendar, or authored game pacing. The fixture uses an arbitrary 1,234,567,890
microsecond cycle, and other tests use several smaller and extreme cycle sizes.

For frequency H, rate N/D, tick batch T, and existing remainder R:

- Divisor Q = H * D.
- Scaled duration A = T * N * 1,000,000 + R.
- Whole microseconds added = floor(A / Q); next remainder = A mod Q.
- Divide the resulting within-cycle whole duration by the configured cycle size
  to carry complete logical days and retain the canonical within-cycle position.

A zero numerator contributes no duration and preserves any valid existing carry.
Accepted simulation ticks still count. Supplying zero ticks preserves the entire
state. Withholding calls likewise introduces no progression. This numeric
behavior does not establish a global pause architecture.

The complete `Snapshot` is also the continuation state: configuration, tick
count, day/time, and carry all travel together. `fromSnapshot` validates and
copies it. There is no separate lossy observation struct or serialized schema.
The whole-microseconds scalar omits fractional carry, and the normalized `f64`
day fraction is approximate; neither scalar alone supports exact restoration.
The latter clamps rounding at the upper endpoint to remain in [0, 1), with no
feedback into authoritative arithmetic.

For equivalent initial state/configuration and successful total progression,
one batch and any partition produce exactly equal authoritative snapshots.
Tests compare complete state, including carry and configuration.

## Bounds and atomic failure

Frequency, denominator, and cycle size must be nonzero. The numerator may span
the full u32 range, including zero. Within-cycle time must be smaller than the
cycle; remainder must be smaller than H * D. All construction and restoration
paths enforce those bounds.

Two u32 divisor factors fit u64. A u64 tick batch times a u32 numerator times
1,000,000 plus carry fits u128, as does the added within-cycle duration. The total
whole-time view (u64 day index times u64 cycle size plus a smaller within-cycle
value) is strictly below 2^128. These arithmetic bounds avoid intermediate traps
in Debug, ReleaseSafe, and ReleaseFast.

The accepted-tick counter uses checked addition. The day increment is compared
against remaining u64 day capacity before conversion/addition. Work is performed
on a local copy and assigned only after validation and all overflow checks pass.
Either overflow error leaves the complete instance unchanged. Time does not wrap
silently, clamp accumulated duration, or silently discard overflow.

## Relationship to existing timing systems

- Application frame timing uses SDL nanosecond measurements and converts them to
  frame deltas. The new module does not read or consume render-frame time.
- `src/physics/fixed_step.zig` owns the existing 240 Hz scheduler, accumulator,
  frame clamp, bounded substeps, and scheduler pause/single-step behavior.
  World time takes caller-executed ticks and does not modify that scheduler.
- Animation clip/animator code samples f32 playback time using supplied deltas
  and playback speed. World accumulation does not alter animation sampling.
- F `SceneTime` is an exact signed tick-domain coordinate with a rational
  sub-tick and deliberately no seconds-per-tick meaning. Runtime-scene snapshots
  carry their existing tick/fixed-delta/interpolation contract. Neither is
  reinterpreted or replaced by world-time state.
- Rendering interpolation and presentation remain owned by existing systems;
  the convenience day fraction introduces no renderer coupling.

Pause ownership, time domains, cross-domain interaction, runtime rate transitions,
offline progression, direct set-time commands, scheduled events, and serialized
persistence remain unresolved. Day/night and calendar interpretation belong to
future configuration/content decisions. In-memory validated restoration is not a
save-game format or persistence implementation.

## Deferred requirements and owner decisions

Future climate work must preserve the roadmap's temperature ranges, rain
availability/probability, snow availability/probability, storms, wind, seasonal
hooks, and broader-region/local-zone override composition. Before production APIs,
owner review must determine:

- Whether climate definitions contain constraints, defaults, probabilities, or
  a combination, and the time basis for rain, snow, and storm probabilities.
- Who owns current weather state and how current conditions are produced.
- How broad regional defaults and local overrides compose; where spatial
  selection belongs within level/world data or another authority.
- How seasonal hooks connect to future calendar semantics.
- How wind is represented and consumed.
- What an eventual `EnvironmentQuery` queries.
- Deterministic seed and replay rules for dynamic weather.

**environment themes ≠ weather/world simulation**. Existing environment themes
remain presentation. This correction does not change LevelDefinition, colliders,
scene serialization, canonical/human content, runtime demos, animation, physics,
rendering, audio, or editor behavior.

Schedules, weather, drying, recovery, animal care, opening/closing locations,
persistence, presentation, and other games are possible future consumers only.
There are no consumer integrations, temporary interfaces, seeds, provider layers,
registries, weather defaults, or climate state in the corrected production API.
The full Level/World Editor still awaits proven world vocabulary.

## Tests retained, refactored, removed, and added

The superseded focused suite had 33 declarations: one root, 17 time behavioral
tests, and 15 environment behavioral tests. All 17 time tests remain, with
pause-related cases refactored to the authorized no-progression/continuation
contract. Fifteen environment behavioral tests and their root import are removed.
No failing test is disabled or skipped.

Three behavioral tests are added for independently configured clocks and repeated
snapshot observation, rate-versus-cycle projection, and a complete headless
progression-to-snapshot vertical slice. Final focused count is **21 declarations:
20 behavioral tests and one import root**.

Coverage includes initialization, zero progression, ordinary ticks, rational
rates, fractional carry across calls, partition equivalence across several rates,
single/multiple day boundaries, arbitrary cycles, invalid configuration and
snapshot bounds, maximum arithmetic operands, both overflow paths with full-state
atomicity, zero numeric rate, copied snapshots, and exact restored continuation.
Only approximate f64 convenience views use a documented 1e-15 rounding tolerance.

Pre-correction full CPU count: **514 declarations**.
The corrected observed count is 514 - 15 + 3 = **502 declarations**, summed from
the sixteen passing executable summaries in after-cpu.log.

## Commands and observed results

All feature commands run in the unchanged physical feature worktree. Zig reports
exactly `0.16.0`. The compiler path in every build below is
`.\.deps\zig-0.16.0\zig.exe`; `-j1` bounds Windows build concurrency.
Full logs are under `.tmp/world-time-correction/`.

Pre-correction commands, each exit 0:

~~~powershell
.\.deps\zig-0.16.0\zig.exe version
.\.deps\zig-0.16.0\zig.exe build test-world -j1 --summary all --global-cache-dir .zig-cache\world-time-global
.\.deps\zig-0.16.0\zig.exe build test check test-full -j1 --summary all --global-cache-dir .zig-cache\world-time-global
.\.deps\zig-0.16.0\zig.exe build -j1 --summary all --global-cache-dir .zig-cache\world-time-global
~~~

Observed: version 0.16.0; focused 33/33 declarations and 3/3 steps; aggregate
514 declarations and 40/40 steps; normal build 22/22 steps. Aggregate execution
included formatting, architecture, hygiene (366 files), documentation, and all
accepted deterministic CPU integration/stress gates. Shared graph nodes run once
when test/check/test-full are requested together. See before-focused.log,
before-cpu.log, and before-build.log.

The normal local branch rename and Git-aware report rename succeeded (exit 0).
Only the two experiment-owned environment files were removed with `git rm`
after resolving their paths within this worktree. No other branch or directory
was deleted or recreated.

Correction commands already observed, each exit 0:

~~~powershell
.\.deps\zig-0.16.0\zig.exe fmt src/world/root.zig src/world/time.zig tests/world/test_world.zig tests/world/time_tests.zig build/modules.zig build/tests_engine.zig build/gates.zig
.\.deps\zig-0.16.0\zig.exe build test-world -Doptimize=Debug -j1 --summary all --global-cache-dir .zig-cache\world-time-global
.\.deps\zig-0.16.0\zig.exe build test-world -Doptimize=ReleaseSafe -j1 --summary all --global-cache-dir .zig-cache\world-time-global
.\.deps\zig-0.16.0\zig.exe build test-world -Doptimize=ReleaseFast -j1 --summary all --global-cache-dir .zig-cache\world-time-global
~~~

Observed: **21/21 declarations and 3/3 steps in each mode**. Logs:
after-focused-Debug.log, after-focused-ReleaseSafe.log, and
after-focused-ReleaseFast.log.

Corrected aggregate and normal-build commands, each exit 0:

~~~powershell
.\.deps\zig-0.16.0\zig.exe build test check test-full -j1 --summary all --global-cache-dir .zig-cache\world-time-global
.\.deps\zig-0.16.0\zig.exe build -j1 --summary all --global-cache-dir .zig-cache\world-time-global
~~~

Observed: **502 declarations; 40/40 aggregate steps; 22/22 normal-build steps**.
Per-executable declaration counts were 3, 22, 39, 3, 277, 5, 21, 27, 5, 3, 4, 9,
19, 2, 13, and 50. The aggregate passed formatting, architecture, hygiene
(**364 implementation/policy files**), and documentation (**46 required files,
42 Markdown files, 94 local Markdown targets**). See after-cpu.log and
after-build.log. No tests were disabled or skipped. These are CPU/build results;
GPU/manual visual acceptance and the separate content-qualification `verify`
tier were not rerun for this headless-only correction.

Completed Git-aware correction operations (exit 0; old report name here is
historical command provenance only):

~~~powershell
git branch -m world-time-foundation
git mv docs/implementation/wt01_world_time_foundation.md docs/implementation/world_time_foundation.md
git rm -- src/world/environment.zig
git rm -- tests/world/environment_tests.zig
~~~

The exact ten-file net-scope comparison and
`git --no-optional-locks -c safe.directory='C:/Users/Chad/Documents/2d-Renderer-wt01-world-time-foundation' diff --check cb60fc9a9b24ba7d69578ffc721948e9b00de8fd`
passed with exit 0. Source/test searches found zero removed climate contracts,
pause state/setter, unfinished markers, or skipped-test markers. The world-time
report link in the testing guide resolves to this file.

After final prose is written, the following final review commands are archived
in final-audits.log and the staging/amendment result is recorded in amend.log:

~~~powershell
.\.deps\zig-0.16.0\zig.exe fmt --check src/world/root.zig src/world/time.zig tests/world/test_world.zig tests/world/time_tests.zig build/modules.zig build/tests_engine.zig build/gates.zig
pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/check_repository.ps1
pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/check_documentation.ps1
git diff --check
git diff --cached --check
git diff --cached --stat cb60fc9a9b24ba7d69578ffc721948e9b00de8fd
git commit --amend -m "world: add deterministic world-time foundation"
pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .tmp/world-time-correction/verify-final.ps1
~~~

Read-only Git commands use `--no-optional-locks` and an explicit task-local
`-c safe.directory` where needed. No global Git configuration is changed.
The complete final-verification script is retained beside its receipt; it checks
branch, subject, both feature hashes against locally known remote refs, no
upstream, old-branch absence, exact parent/count, ten-file scope, whitespace,
feature cleanliness, and the primary branch/HEAD/status/index hash.

A read-only inspection attempted the nonexistent `tools/checks.ps1`; it returned
a file-not-found error. Inspection was corrected to the actual
`tools/check_repository.ps1` and its architecture/hygiene helpers. A first
orchestration edit expression failed JavaScript parsing before any tool ran; the
corrected expression applied successfully. A sandboxed plain Git diff probe could
not resolve the worktree repository; subsequent read-only Git commands use an
explicit per-command safe.directory. These inspection/orchestration issues are
distinct from the passing compiler/test gates; no failure was hidden by changing
accepted production code.

## Complete file inventory

Net corrected feature against the original base (ten files):

| Status against base | Path | Purpose |
| --- | --- | --- |
| Added | `src/world/root.zig` | Time-only public module exports. |
| Added | `src/world/time.zig` | Deterministic accumulation and complete copied continuation. |
| Added | `tests/world/test_world.zig` | Headless focused test import root. |
| Added | `tests/world/time_tests.zig` | Twenty behavioral time contracts. |
| Added | `docs/implementation/world_time_foundation.md` | Corrected scope, provenance, evidence, and review decisions. |
| Modified | `build/modules.zig` | Register the narrow world module. |
| Modified | `build/tests_engine.zig` | Register the headless focused test artifact. |
| Modified | `build/gates.zig` | Include world tests in the fast aggregate (retained unchanged by this correction). |
| Modified | `tools/checks/architecture.ps1` | Enforce the narrow world dependency boundary. |
| Modified | `docs/TESTING.md` | Correct test scope, counts, gates, and report link. |

Relative to the superseded experiment, the report was renamed and rewritten,
the two world environment files were deleted, and the other listed source/test/
registration/policy/documentation files were narrowed. The original report path
can be retrieved from the superseded commit. No base-commit file is removed.
No roadmap, dependency manifest, scheduler, existing environment-theme test, or
application/runtime file appears in the feature diff.

## Final verification and review boundary

After correction and all CPU/build gates, the primary is still on `master` at
`cb60fc9a9b24ba7d69578ffc721948e9b00de8fd`, with clean index/worktree status and
the exact initial index SHA-256 recorded above. Every primary/other-worktree
inspection used read-only Git operations. This task made no writes to them.

Concurrent owner tasks changed Engine Lab, secondary-motion, record/replay, and
effects/projectiles worktrees during validation. Their observed status is therefore
not claimed to be identical to the starting inventory. Those unrelated changes
were neither staged, reverted, nor incorporated here. Final read-only observations
are preserved in the receipt.

The final amended commit and clean `world-time-foundation` status are certified by
`.tmp/world-time-correction/final-state.txt` after amendment. That verification
requires exactly one commit above the base, one parent at the base, the old branch
absent, no upstream, and no locally known remote ref containing either feature
commit. It also rechecks primary preservation. The completion response reports
the literal final commit hash; this tracked report identifies its containing
commit to avoid an impossible self-referential hash.

Nothing was fetched, pulled, merged, pushed, rebased, reset, cherry-picked, or
cleaned. No dependency or other worktree was modified by this task. Owner
acceptance remains pending. Climate, weather, environment-query contracts,
pause/time-domain policy, calendar/rate-transition semantics, and persistence
remain deferred. No subsequent feature is started.
