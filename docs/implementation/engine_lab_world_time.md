# Engine Lab World Time integration

Status: **OWNER ACCEPTED** at `deacc4e2c6f24873df730a18fc83cc23dfa6b97b`.
Independent source/evidence review and owner visual acceptance passed. The reviewer
inspected reconstructed patches, production code, tests, logs, hashes and native
captures; the implementation owner performed the Windows/Zig/D3D12 executions.
The reviewer did not independently repeat those executions. Acceptance includes
one hub-owned WorldTime advancing from executed ticks, pause, single-step,
navigation, whole-hub reset, snapshot continuation and overflow behavior.
The accepted conservative bound is 1,950/1,984 sprites, three batches and 34 spare.
Feature-branch acceptance does not imply incorporation into master. Historical
pending-status evidence and original raw bytes remain preserved.
This is one bounded slice of the unnumbered Engine Lab Integration track. EL1
remains closed. The accepted World Time Foundation and PSM01 solver are unchanged.

## Authority and preceding acceptance

Worktree: `C:\Users\Chad\Documents\2d Renderer-engine-lab-integration`.
Branch: `feature/engine-lab-integration`. The clean expected starting HEAD was
`cfb2876c29df78f0cfa034d3df45ebe19764b141`. The first new local commit is
`cf15b1b50191a94f4b1779c71f905b0694a47703`, a five-file documentation-only
record of owner acceptance of that exact PSM01 LAG checkpoint. Independent
source/evidence review passed: the reviewer inspected patches, source, logs and
captures; the implementation owner performed the Windows/Zig/D3D12 executions.
Those executions were not independently repeated by the reviewer. The accepted
boundary includes completed-controller sampling, lifecycle, horizontal production
presentation and `Renderer.initializeUnifiedQueueWithCapacities`, with unchanged
solver and renderer defaults. Its conservative bound remains 1,827/1,856 sprites,
three batches and 29 sprites of headroom. Formatting, architecture/checkout,
documentation and `check` passed before that acceptance commit and before any
World Time production edit. Historical evidence remains byte-preserved, including
its original pending status. Feature acceptance implies no incorporation into master.

The second new local commit contains this World Time integration; its full identity
is recorded in the review manifest to avoid a self-referential commit hash. Both
commits remain local and unmerged. Starting master was
`1f8d2f3e01102285e76d02a788b7adb5f992087f`. Other worktree revisions may advance
concurrently and are recorded as observations. This task writes only this worktree.
The installed Zig reports 0.16.0. Pins, all 105 installed SDL3 3.4.10 files, all 37
DXC 1.9.2602.24 files, identity files and archive hashes passed preflight unchanged.
Root AGENTS.md is the only applicable instruction file. No dated reconciliation
document was found in this checkout; current accepted contracts and the explicit
request define this slice.

## Ownership and tick composition

[`world_time.zig`](../../src/app/engine_lab/world_time.zig) contains application
content constants and bounded copied-value formatting. `Hub` owns one inline
accepted `WorldTime`, constructed with validated `fromSnapshot`. The accepted
[`src/world/time.zig`](../../src/world/time.zig) alone owns exact accumulation and
continuation. There is no new scheduler, accumulator, OS clock, independent day
counter, mutable display cache, rate control or partial live-hub restore operation.

| Authored Engine Lab policy | Value |
| --- | ---: |
| Fixed simulation frequency | existing `fixed_step.simulation_hz`, 240 Hz |
| World seconds per executed simulation second | 60/1 |
| Logical day duration | 86,400,000,000 microseconds |
| Initial day index | 0 |
| Initial time within day | 86,340,000,000 microseconds, 23:59:00 |
| Initial accepted ticks / fractional carry | 0 / 0 |

These are lab content values, not engine defaults or final game balance. Controller,
animation, stations, PSM01, projectiles and particles retain their existing speed.

At prior boundary N the hub consumes pending activation, executes the existing
controller/animation/station/camera block, and steps the accepted calibration once
from the completed controller. It then executes the existing effects step, optional
spawn at projectile-native N, projectile step to N+1, ordered event/color observation,
bridge consumption once and event clearing. Only after all of that succeeds does
`WorldTime.advanceSimulationTicks(1)` execute. A successfully returned tick leaves
hub, effects, projectiles and world accepted-tick counts equal. PSM01's steps since
reanchor remain independent of the hub tick count after navigation.

World Time counts actual executed hub ticks. Render frames, requested substeps,
raw/clamped/discarded frame duration and interpolation contribute no logical time.
One executed tick adds exactly 250,000 world microseconds. Tick 239 is day 0 at
86,399,750,000; tick 240 is day 1 at zero. Pause adds no ticks. Paused single-step
crosses that boundary exactly once. Navigation preserves the entire snapshot and
retains existing actor repositioning/PSM01 reanchoring. Focus loss follows the
existing input suppression policy without resetting or independently pausing time.

Whole-hub reset restores the authored snapshot, dominates other same-frame commands
and executes zero reset-frame ticks. Candidate construction still precedes teardown;
all 160 failed allocation prefixes preserve the old live time, calibration, effects,
projectiles, selected hub state, pending intent, clock, camera and live allocation size.

A late time overflow reports the operation and executing hub tick and propagates.
It is a fatal partial tick, not whole-hub rollback. World Time's own atomic failure
leaves its old snapshot while prior hub systems have completed one tick. Subsequent
frame entry rejects this divergence before changing input or fixed-clock state;
only a successful whole-hub reset reconstructs a usable hub. The bounded
`--verify-world-time-overflow` fixture uses a supported constructor for an unusual
initial clock, deliberately exits nonzero with `WorldDayOverflow`, verifies that
only one of eight requested ticks reached the late failure, and proves that zero-
and nonzero-delta continuation attempts are rejected without further state changes.
The offline wrapper checks that expected failure, context and rejection together.

## Observation and bounded presentation

Snapshots copy the complete configuration, accepted simulation ticks, day index,
whole microseconds within day and fractional remainder. Observation cannot mutate
live state. Tests reconstruct an independent clock with `fromSnapshot`, including a
valid nonzero carry under an unusual 1/7 rate, then compare exact continuation with
the actual hub. Unusual and extreme formatting fixtures are explicitly test or
presentation inputs, not claims of ordinarily reached simulation history.

`WORLD_TIME_STATE_V1` is a separate bounded exact-integer diagnostic record, including
all configuration/state fields. It is not authoritative serialization, JSON replay
or a padding dump. The accepted typed snapshot remains the continuation contract.
All 47 legacy checkpoint records and 12 calibration observation identities remain
separate. Their schemas and fixture implementations are preserved.

The existing production debug font renders one persistent upper-right HUD label.
It reads the completed copied snapshot using integer minute flooring, with no
interpolation or rounding into a future minute. Days 0..999 display exactly;
all larger days show `D1000UP`. The full u64 day remains intact in snapshots and
diagnostics. HH:MM intentionally omits seconds, so a single step often leaves text
unchanged. `D0 23:59` becomes `D1 00:00` on rollover.

The view measures the actual emitted glyph outer edge and aligns it to the existing
HUD inset. No font metrics are duplicated and no renderer/font redesign is needed.
Production-font tests enumerate all 1,001 bounded day prefixes and 1,440 minute
suffixes, then test the combined maximum and placement. Per-character emission
makes the independently derived maxima additive. The maximum is `D1000UP 00:00`:
123 sprites and 87.6 native pixels wide. Placement is checked at both navigation
camera positions, including exact and overflow days, with f32 tolerance 1e-5 metre
(far below one pixel). Native 640x480 captures retain controls, status and LAG.

| Presentation accounting | Observed / conservative bound | Allowance or capacity |
| --- | ---: | ---: |
| Original content | 1,751 / 1,792 | 1,792 |
| Accepted calibration addition | 35 / 35 | 64 |
| Prior combined frame, removing only time | 1,786 / 1,827 | 1,856 |
| Time label maximum | 123 / 123 | 128 |
| Complete frame | 1,909 / 1,950 | 1,984 |
| Conservative complete-frame headroom | 34 | unchanged three batches |

The full saturation matrix retains 0..8 projectiles, 192 particles, full station
histories, diagnostics on/off, run/pause, full-u64 tick labels, production-font
counter/hash maxima and calibration at rest/both displacement limits. Removing
time preserves <=1,856; removing time and calibration preserves <=1,792. Both
actual and conservative complete totals fit <=1,984. Existing lower nominal
1,792 tests remain intact. Queue entries remain 2,048, meshes 256, debug commands
2,048 and texture pages unchanged. Existing renderer APIs request capacity before
stabilization; GPU storage still rounds to 2,048. Shared renderer defaults are
unchanged. No steady-state allocation is introduced.

## Evidence and validation boundaries

Fresh evidence is under `.tmp/engine-lab-world-time`. Only the existing `.zig-cache`,
`.tmp/projectile-impact/global-cache` and `.tmp/projectile-impact/install` are reused.
No previous evidence is overwritten or normalized. Preflight/final hashes protect
all prior projectile and PSM01 evidence. Exact command arrays, exits, raw logs,
source identities, cache-hit details and expected overflow failure are retained.

Nine new Engine Lab tests cover lifecycle, exact rollover, capped and zero-step
frames, grouping, snapshot independence/continuation, render purity, all failed
reset allocations, integer formatting and production-font bounds. Accepted
`test-world`, `test-psm01` and `test-effects-projectiles` remain separate targets.
The native smoke retains both impact fixtures and calibration, adds eight World
Time captures, and routes all 32 fresh readbacks to the new task directory.
Native capture allocations occur outside warm frames. Each native RGBA SHA-256
is checked against the retained PPM, and each PNG is verified lossless. Capture
presentation temporarily pauses to show completed state; logs separately report
whether simulation was actually paused. Initial/reset snapshots are running at tick
zero even though completed-state captures carry the PAUSED overlay.

The overflow fixture passed its expected-failure wrapper. Native D3D12 smoke passed
with three batches, zero warm allocations/drops, 26/26 resources and 2,016/2,016 fences.
Engineering inspection of native initial, rollover, coexistence and calibration
reversal captures found the time label readable with existing controls and LAG.
This inspection is separate from independent review and owner visual acceptance.
The final gate table and source identity are recorded below.

The compact review ZIP contains two ordered full-index binary-capable patches,
changed-file inventory, acceptance/implementation records, command ledger, raw
logs, reproduction scripts, native PPM/lossless PNG captures, preservation receipts
and a validation manifest. A separate temporary Git index applies both patches
in order and checks the complete committed tree without touching the working
index. Caches, dependencies, executables and redundant capture copies are excluded.

## Exclusions and owner launch

This slice preserves provisional controller authority and static RuntimeScene
installations; it does not implement dynamic scene publication. No calendar,
weekday/month/season, timezone, weather, lighting, schedule, fast-forward, separate
pause domain, RR1, combat, abilities, Fireball, collectibles, liquids, anatomical
or garment binding, canonical authoring or sibling application work is included.
No next integration slice is started. World Time and the preceding PSM01 checkpoint are accepted at their exact
revisions recorded above; their original evidence retains its historical status.

From the established integration worktree:

```powershell
Set-Location -LiteralPath 'C:\Users\Chad\Documents\2d Renderer-engine-lab-integration'
& '.\.tmp\projectile-impact\install\bin\engine_lab.exe'
```

The label starts at D0 23:59 and rolls after one executed simulation second.
P pauses, T advances one simulation tick, F1/F2 navigate without resetting time,
and R resets the whole hub. Existing movement and E/gamepad-west activation remain.

## Final source validation

| Fresh invocation | Exit | Observed result |
| --- | ---: | --- |
| `focused-debug-accepted` | 0 | 184 tests in 4 roots; 12/12 steps succeeded |
| `focused-release-safe` | 0 | 184 tests in 4 roots; 12/12 steps succeeded |
| `focused-release-fast` | 0 | 184 tests in 4 roots; 12/12 steps succeeded |
| `test` | 0 | 621 tests in 15 roots; 31/31 steps succeeded |
| `check` | 0 | 621 tests in 15 roots; 39/39 steps succeeded |
| `test-full` | 0 | 718 tests in 21 roots; 52/52 steps succeeded |
| `build-debug` | 0 | 24/24 steps succeeded |
| `build-release-safe` | 0 | 24/24 steps succeeded |
| `build-release-fast` | 0 | 24/24 steps succeeded |
| `engine-lab-build-debug` | 0 | 11/11 steps succeeded |
| `engine-lab-build-release-safe` | 0 | 11/11 steps succeeded |
| `engine-lab-build-release-fast` | 0 | 11/11 steps succeeded |
| `gpu-smoke` | 0 | 26/26 steps succeeded |
| `headless-final` | 0 | 13/13 steps succeeded |
| `engine-lab-smoke` | 0 | 13/13 steps succeeded |
| `overflow-propagation` | 0 | Expected process exit 1; operation/tick context and no continuation verified |
| `encode-single` | 0 | Lossless RGB capture conversion verified |
| `encode-multi` | 0 | Lossless RGB capture conversion verified |
| `encode-calibration` | 0 | Lossless RGB capture conversion verified |
| `encode-world-time` | 0 | Lossless RGB capture conversion verified |

All required source-bearing invocations identify SHA-256 `44f985c0e648f4f554cdb2e0a331d51c8ab69c3cc715bc23c59d5e29dd1d8c0d`.
Exact commands, raw logs, per-command source hashes, durations and cached child
steps are retained in the command ledger. These are fresh gate invocations;
cached compiles are identified in raw output and are not claimed as fresh compiles.
No source test was disabled or skipped. The deliberately failing overflow process
is preserved with its actual nonzero exit; its checking wrapper returns zero.
No unexpected development compile/test failure or unresolved required gate remains.
