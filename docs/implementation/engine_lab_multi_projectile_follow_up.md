# Engine Lab sweep precision and eight-projectile follow-up

Status: implementation candidate, **PENDING OWNER VISUAL ACCEPTANCE** for this
new behavior. The owner accepted the original single-projectile visuals in chat.
EL1 remains closed; this is an unnumbered continuation of Engine Lab Integration.

## Original implementation authority and separate commits

Worktree: `C:/Users/Chad/Documents/2d Renderer-engine-lab-integration`.
Branch: `feature/engine-lab-integration`. Reviewed starting commit:
`37d11c8e3a7e2f67e210df0bb71000efdbbee793`, with base/master
`1f8d2f3e01102285e76d02a788b7adb5f992087f`. Local HEAD, clean status,
worktrees, ancestry and live remote refs matched before editing. One owner
performs hub composition, input, tick order, reset and reporting. Other worktrees
are preserved. This task authorizes two local commits, with no push or merge.

First commit: `3719ba225890f828df8d27d0badca521467d2d19`, the independently
validated static-sweep correction. The [integration record](engine_lab_projectile_impact.md#static-sweep-precision-follow-up-2026-09-08)
contains the actual pre-fix Zig failure and bounded numerical reasoning. Before
part two began, all 38 focused tests passed in Debug/ReleaseSafe/ReleaseFast,
and formatting, architecture, documentation and checkout-integrity gates passed.
The second local commit contains this eight-shot/color composition and evidence
record; its final identity is recorded in the review ZIP's validation manifest.

Zig reported exactly 0.16.0. The unchanged lock and all installed SDL 3.4.10
(105 files), DXC 1.9.2602.24 (37 files), identity files and cached archive hashes
were verified. Installed SDL GPU declarations were inspected. No dependency
update or checkout-policy override was used. Original evidence remains under
`.tmp/projectile-impact`; new logs/captures use `.tmp/projectile-impact-follow-up`.
Only the existing `.zig-cache` and `.tmp/projectile-impact/global-cache` cache
family is used, with the established `.tmp/projectile-impact/install` output.

## Exact shared contracts changed

- `collision_world.static_sweep.query`: signature, Sweep/Contact/Error types,
  finite-f32 domain and geometry conventions are unchanged. Exact dyadic
  comparisons correct rounded slab ordering; i288/i576 widths cover all finite
  binary32 inputs with no heap allocation, epsilon or iterative precision loop.
  Rational contact-coordinate numerators also prevent endpoint cancellation.
- `projectile_effects.Bridge.consume(events, effects)` retains its behavior and
  signature. Added `Rgb = [3]f32` and
  `consumeWithColors(events, effects, overrides: ?[]const ?Rgb)`. A null batch or
  null entry preserves authored appearance. `InvalidColorOverrides` reports a
  length mismatch or any nonfinite/out-of-range component, checked across the
  whole batch before bridge/effect mutation. Native event ordering is likewise
  checked before processing. Definition copies receive RGB at both endpoints;
  opacity and every other parameter remain intact. No caller buffer is retained.

The bridge still owns its identity recipe, native event order, exactly-once
consumption, trail tracking and drop semantics. Color overrides affect launch,
trail, impact and expiration definition copies, including zero-burst definitions.
They change no emission count, physical parameter, RNG draw, identity derivation
or projectile outcome. Palette/random/tag interpretation belongs to the hub.
No projectile/effects core state layout, event format or standalone client changes.

## Shot identity and color ownership

The launcher `(5.5,1.2)` and wall collider 3 at X=8 are unchanged. Each shot uses
velocity `(1.875,0)`, zero acceleration, half-extents `(0.0625,0.0625)`, lifetime
480 ticks and despawn-on-contact. Fresh E or gamepad-west presses can launch
with earlier shots in flight. Holding does not repeat. At most one pending edge
and one successful spawn occur per executed tick. Full/out-of-range presses
are consumed. Capacity is observed before stepping: a full-capacity press on
a contact tick remains rejected even when that tick subsequently retires a shot.

`Installation.color_context` and `next_shot_ordinal` are explicit authoritative
application values, separate from saturating diagnostic counters. Color derives
from the hub seed and the big-endian successful-shot ordinal via foundation
`deriveKey`, generator `f898e009-d4ae-51af-ad48-a862d2471277` v1.0.0,
algorithm `08c28ecd-7338-5c97-b7e0-37059add6f8e` v1.0.0, and stable key
`engine_lab.shot_palette.v1`. The low three bits of the first derived byte select
one of eight bright authored RGB colors without modulo bias. Repeats are valid.
The ordinal advances only after successful core spawn; rejected inputs consume
neither ordinal nor core identity. No wall time, global RNG, render RNG or private
effects state participates. Reset reproduces colors and identities.

The projectile's existing opaque u32 `Definition.tag` carries the hub palette
index unchanged through snapshots/events. The view only resolves that immutable
index. After retirement the copied native contact event supplies the same tag;
the hub passes corresponding RGB alongside the original ordered event batch.
Each particle owns copied start/end RGB, so later shots, contacts and slot reuse
cannot recolor older particles. The existing velocity/spread/gravity/drag, sizes,
opacity endpoints and 144-tick particle lifetime remain unchanged.

## Tick, input and ownership boundaries

At entry, hub/projectiles/effects all equal N:

1. Consume one pending edge, inspect completed actor position and capacity, and
   prepare an immutable spawn definition/color.
2. Execute the existing actor/controller/animation/station/camera block in its
   original relative order.
3. Step effects exactly once to N+1.
4. Spawn at most once while the projectile core is at N; only successful spawn
   commits the color ordinal.
5. Step projectiles once with the borrowed query against the same Hub.world.
6. Copy bounded observations and RGB values, consume the original ordered batch
   once through the bridge, then clear events after successful consumption.
7. Successful completion leaves all three counters at N+1. Impact particles
   have age zero and first advance on the next executed tick.

Both empty/offscreen cores keep ticking. Native timestamps are unchanged, with
no synthetic removal, extra clocks or render-driven simulation. Errors propagate;
there is no whole-hub rollback claim. Pause executes no ticks, single-step consumes
one edge once, navigation retains world/core/color state while clearing pending
input, and focus loss clears both mapper and hub activation. Reset dominates
same-frame controls, reconstructs before teardown, executes zero reset-frame
ticks, restores running tick zero and clears the complete installation/color
sequence. Every tested failed reconstruction preserves the prior live state.
Renderer/platform ownership and static RuntimeScene boundaries remain unchanged.

## Bounds and production presentation

| Storage | Capacity | Derivation |
| --- | ---: | --- |
| Projectiles and every copied projectile array | 8 | Supported simultaneous flights |
| Core events, observations and RGB override buffers | 17 | One spawn plus eight movement/contact-or-expiry pairs |
| Bridge trail tracking | 8 | One per active projectile |
| Particles and extraction/snapshot arrays | 192 | Eight overlapping impacts times 24 |
| Emitters | 9 | Eight impact emitters plus one empty launch emitter |
| Pending activation | 1 | Coalesced fresh input edge |
| Production queue | 1,792 sprites, 3 batches | Existing renderer contract |

The normal trajectory contacts after 312 executed ticks; particle lifetime 144
is shorter than a replacement flight. Thus at most eight impacts overlap. Empty
launch emitters retire in the next effects step before another launch event is
consumed. Headless/native fixtures reach 192 particles and nine emitters without
drops. A separate public-core boundary test actually emits all 17 permitted
spawn/movement/contact events, and repeats the bound for movement/expiry pairs.
The authored timeline's measured maximum batch is nine events.

The initial maximum tests exposed 1,799 sprites during ordinary overlap and
1,830 with saturated diagnostic counters. Local labels were shortened, retaining
readiness/capacity and existing diagnostics. Discarded-seconds display caps at
999.999 while the full clock value remains authoritative, matching the existing
bounded diagnostic-counter presentation principle. Tick values remain full u64.
Renderer limits, instance allocation, texture mapping and effect quality are
unchanged. A conservative glyph-cost test covers all 0..8 active counts, 192
particles, running/paused states, maximum decimal fields and the most expensive
possible 12-character hash. The corrected test measures 1,751 sprites and derives
an upper bound of 1,792/1,792, with no conservative spare capacity. The previous
1,747 observed / 1,788 conservative result used an incorrect maximum-glyph
assumption and is retained only as historical evidence. The correction below
supersedes that bound and the earlier four-sprite headroom claim. Prior nominal
maxima were 1,452 headless and 1,454 native, always in three batches; the corrected
focused tests again observe 1,452 headless. Readiness shows E/WEST n/8 or FULL 8/8.

## Diagnostic coverage and evidence boundaries

Local schema is now `engine_lab.projectile_impact.observations.v2`. It adds
color derivation context/seed/version, authored palette, successful-shot ordinal,
immutable projectile tags and particle RGB to authored configuration, core ticks,
copied live projectile/particle records, particle-reachable emitters, ordered
event history, pending command/capacity observations and bridge sequence/count/
metrics. Private RNG/storage, empty emitter records, camera, frame residue and
EL1 state remain excluded. Scratch RGB buffers are derived from the copied batch.
This is a selected diagnostic comparison, not comprehensive replay/save state;
RR1 is unchanged. Original EL1 selected-state v2 code and all 16 tests are retained.
Earlier integration-v1 logs/hashes/captures remain preserved as prior evidence.

The new fixture launches eight shots at completed ticks 0..112, spaced 16 ticks,
and replacements at 320..432. It observes two full-capacity rejections (including
one on first contact), one out-of-range rejection, 16 contacts, and final drain
at tick 888. Reset and equivalent mixed frame grouping reproduce all checkpoints
and colors. The existing 1,440-tick and 936-tick fixtures remain separately run.

New native readbacks show several colored flights, matching overlapping impacts,
old particles with new shots, paused contact and next-tick advancement, old-effect
drain and whole-hub reset. They are produced by SDL3/D3D12 captureUnified and
losslessly PNG-encoded by the existing review tool. The retained capture helper
temporarily pauses presentation to show completed state, then restores it; this
accounts for PAUSED overlays even on reset captures. The native reset assertion
separately verifies running tick zero. Captures are engineering inspection
evidence; new owner visual acceptance remains pending.

## Glyph-budget test correction (2026-09-08)

Starting HEAD: `fe742e703b15caa59886ff7a20a8ba724d7449ac`, on the clean
`feature/engine-lab-integration` worktree named above. The correction creates
one additional local commit, preserving both preceding commits without push,
merge or history rewriting. Its final identity is recorded in the separate
correction manifest. Only `tests/engine_lab_multi_impact_tests.zig` and this
record change; production source, font, labels, renderer capacity, APIs, palette,
particle quality and tick/lifecycle behavior remain unchanged.

The corrected test measures all 1,000 formatted integer values in 0..999 through
production `CommandBuffer.addLabel`. It separately formats and measures all
1,000 dot-plus-three-digit fractional suffixes. Since this font emits independent
commands per character, adding the two maxima bounds the full seconds field
without enumerating a million combinations. Formatting the combined candidate
confirms that the bound is attainable. Actual clamped formatting is checked at
999.999, 1000 and the largest finite f64; each renders `999.999` and stays within
the derived field cost. No result is substituted for the unchanged queue limits.

Fresh Debug, ReleaseSafe and ReleaseFast executions all report:

| Measured production label | Sprites |
| --- | ---: |
| Previous integer candidate `900` | 32 |
| Maximum integer candidate `400` | 33 |
| Previous seconds candidate `900.000` | 69 |
| Maximum seconds candidate `400.000` | 70 |
| Maximum fractional suffix `.000` (including dot) | 37 |
| Maximum decimal / hexadecimal single glyph | 12 / 12 |

The three bounded integer diagnostics and the seconds field each gain one
sprite in the conservative calculation. The directly observed frame maximum is
**1,751**, while replacing the observed hash with twelve maximally costly hex
glyphs gives **1,792**. These are separate measurements: the conservative bound
exactly meets capacity and does not demonstrate 41 sprites of guaranteed spare
capacity. All actual-frame and conservative `<= 1792` assertions and the exact
three-batch assertions remain intact.

Coverage retains active counts 0..8, 192 live particles, running/paused states,
diagnostics on/off, full-u64 tick values, saturated raw counters and the
12-character hash bound. Full station history is now explicitly asserted before
rendering. Every other test in the file is byte-preserved.

Fresh `test-engine-lab` runs pass 49/49 tests and 3/3 build steps in each of the
three optimization modes (exit 0 each). Fresh formatting, architecture,
documentation, checkout-integrity and mandatory `check` results are recorded
with exact commands, raw logs and file/source hashes in the correction manifest.
Preflight reverified Zig 0.16.0, all 105 SDL 3.4.10 files, all 37 DXC 1.9.2602.24
files, their archive hashes and the unchanged dependency lock. Delivery audits
compare all 1,014 protected tracked files, 44 original evidence files and 89 prior
follow-up evidence files against their preflight raw hashes.

New evidence is confined to
`.tmp/projectile-impact-follow-up/glyph-budget-correction`.
It contains `engine-lab-glyph-budget-correction.patch` (byte-preserving full-index
binary Git diff) and `engine-lab-glyph-budget-correction-review.zip`, with the
patch, this updated record, fresh logs, exact command ledger, validation manifest
and reproduction scripts. Original review ZIPs, logs, manifests and captures are
preserved. The earlier 699-test full suite, D3D12 smoke and native captures below
are **prior evidence for the starting revision**, not freshly executed correction
gates. Full-suite, content, historical reproduction and GPU routes are not rerun
for this test/documentation-only correction. New multi-projectile owner visual
acceptance remains **PENDING OWNER VISUAL ACCEPTANCE**.

## Original implementation validation and owner launch

The table below records executions for the original implementation ending at
`fe742e703b15caa59886ff7a20a8ba724d7449ac` on 2026-09-08. They remain prior
evidence, separate from the correction executions above. Exact commands/arguments,
exit codes, timings, log hashes, source identities and capture metadata remain
in `COMMANDS.md`, `commands.json` and `validation.json` inside the original review
ZIP. Its original delivery formatting, architecture/documentation and staged
checkout checks are preserved in that ledger as well.

| Executed gate | Exit | Observed result |
| --- | ---: | --- |
| Sweep correction before part two, Debug/ReleaseSafe/ReleaseFast | 0 each | 38 focused tests each, after the requested pre-fix false hit was reproduced |
| Final `test-engine-lab` + `test-effects-projectiles`, all three modes | 0 each | 49 + 58 = 107 tests, 6/6 steps each |
| `test` | 0 | 602 tests, 29/29 steps |
| `check` | 0 | 602 tests, formatting/static audits, 37/37 steps |
| `test-full` | 0 | 699 tests, 50/50 steps; includes both retained long-duration stress tests |
| Default application build, all three modes | 0 each | 24/24 steps each |
| Explicit independent `engine-lab` build, all three modes | 0 each | 11/11 steps each |
| Engine Lab `--verify` | 0 | 13/13 steps; original 1,440- and 936-tick fixtures plus new 888-tick/16-shot fixture |
| Physical `gpu-smoke` | 0 | 26/26 steps; actual D3D12/DXIL, production readback, two instances in one draw and initialization-failure cleanup |
| Engine Lab `--smoke` | 0 | 13/13 steps; original 180-frame/540-draw smoke, retained single-shot fixture and new multi-shot fixture |
| Lossless capture encoding | 0 each | Seven retained-fixture captures plus eight multi-shot captures, each with native PPM and PNG |
| Formatting, architecture, documentation and checkout-integrity audits | 0 | Individual gates plus aggregate checks; exact delivery results in the ledger |

Those original source-bearing gates agree on SHA-256
`2881ca1f46f7d4bd2231658130af096ea8d025742a3b8fb2ff93602dd6b4bbd9`
for the runner's sorted raw source/test/build/capture-tool identity. Documentation
has separate delivery audits. Native multi-shot smoke observes 16 launches and
16 contacts, two full rejections, one range rejection, 192 particles, nine emitters,
three batches and zero drops/steady allocations. Shutdown balances resources
26/26 and fences 1,387/1,387. The initial eight palette keys are
`2,5,7,4,4,2,2,5`; replacements are `6,5,7,2,2,4,2,2`, reproduced after reset.
Birth/next-step particle ages are exactly zero/one at ticks 312/313.

The preservation audit verifies all 44 prior task-evidence files, dependency
lock, accepted projectile/effects/foundation/graphics sources, closed EL1 and
standalone proof authorities, original EL1 v2 fingerprint/helpers and all 16 EL1
tests. Existing geometry/bridge tests and bridge effect identity recipe remain
byte-identical. There are no TODO/FIXME, unfinished stubs or disabled tests in
the changed code. Requested regression and corrected development failures remain
in the logs; no required final failure is unresolved.

Not executed: content qualification, historical exporter reproduction, the
`verify` aggregate that adds content qualification, or new manual owner visual
acceptance. Their documented content scopes are untouched. The two stress tests
were executed through `test-full`, not repeated as a separate command. No PSM01,
World Time, RR1, combat, dynamic scene publication, renderer/backend or dependency
work is included.

Review archive:
`.tmp/projectile-impact-follow-up/engine-lab-follow-up-review.zip`.
It includes the command ledger, gate/evidence scripts, relevant logs, implementation
record and 15 native captures with lossless PNG copies. The packaging script
verifies archive CRCs and every entry against its source SHA-256; the adjacent
`review-zip.sha256` records the final archive hash. Caches, dependencies,
executables and unrelated assets are excluded. The final commit identities and
changed-file inventory are in `validation.json`.

From the dedicated integration worktree:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 --global-cache-dir .tmp/projectile-impact/global-cache -p .tmp/projectile-impact/install
```

Use F2 or ordinary movement, tap E/gamepad west repeatedly, and inspect flight,
matching overlapping impacts, capacity rejection, pause/T stepping, navigation
and reset. The review ZIP excludes caches, dependencies, executables and unrelated
assets. Both commits remain local and unmerged at delivery.
