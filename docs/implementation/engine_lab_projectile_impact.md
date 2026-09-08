# Engine Lab projectile-impact integration

Status: the owner accepted the original single-projectile visuals in chat.
The [eight-projectile/color follow-up](engine_lab_multi_projectile_follow_up.md)
is **OWNER ACCEPTED** at `6e4f7c2aadf24c2336ab3cba2d60ff127e750e0e`,
including its sweep and glyph-budget corrections. The owner also reports passing
independent source/evidence review. This is acceptance on the integration branch,
not incorporation into master or a push/merge claim. Original measurements below
remain historical; the follow-up record owns current bounds, color contracts,
commands and review evidence.
Engine Lab Integration is a track name. This slice does not reopen closed EL1,
assign a milestone number, or adopt later roadmap systems.

## Original single-projectile authority and ownership

Base: `1f8d2f3e01102285e76d02a788b7adb5f992087f`, verified against live GitHub
master before editing. All five requested accepted foundation commits are
ancestors. Work is isolated on `feature/engine-lab-integration` in the dedicated
`2d Renderer-engine-lab-integration` worktree. The original master was clean.
Zig reports exactly 0.16.0. SDL 3.4.10 (105 installed payload files) and DXC
1.9.2602.24 (37 files), their manifests and cached archives passed SHA-256
verification against the unchanged dependency lock. Installed SDL GPU, keyboard,
scancode, gamepad and focus-event headers were inspected. No dependency update
or checkout-byte override was used. The optional reconciliation document was
not present in the checkout; the supplied approved scope is the task authority.

API decision, made before implementation: retain the character-oriented axis
sweeps unchanged and add a nonallocating per-collider helper in
`src/physics/static_sweep.zig`, exported through `collision_world.static_sweep`.
It reuses native AABBs and Vec2 rather than extending controller response APIs.
Its minimal input is two center endpoints and nonnegative body half-extents;
its output is optional fraction, unit normal and surface position. This avoids
a world-level nearest-hit decision that could discard a valid farther hit.

Physics imports no projectiles, effects, bridge or application. The hub-owned
adapter enumerates every solid collider of the same `Hub.world` used by the
actor, in immutable world order. It appends all contacts or returns HitCapacity;
the accepted projectile port retains validation, native-ID exclusion, bilateral
mask filtering and time-bucket/native-ID tie authority. Static geometry has no
F identity/affiliation mapping: entity metadata is null, material is zero,
layer is one and mask is all bits. Tests explicitly filter/exclude the nearer
platform and observe the farther real wall. No second world or target is made.

`Hub.impact` uniquely owns both core systems, the accepted bridge, pending edge,
authored placement and bounded copied observations. The launcher source is the
existing right installation's validated F root identity. The specialized actor
continues using its supported controller observations/staging/submission; no
actor F identity or dynamic RuntimeScene publication is fabricated. Query
context is borrowed for the call and event batches end before core mutation.

## Static contact contract

Metres, X-right/Y-up; a complete segment sweeps a point or axis-aligned body
against a solid static AABB. Finite endpoints/extents and ordered finite bounds
are required. Exact bounded dyadic comparisons preserve slab ordering for all finite f32
inputs, including opposite maximum endpoints and subnormal geometry. Fraction is normalized center travel. Normal is an exact axial
unit vector. Position is on the original obstacle face, with the other
coordinate clamped to its face span, including penetrating initial states.

Strict initial overlap reports zero fraction with the closest expanded face;
ties choose min-X, max-X, min-Y, max-Y, including zero movement. Otherwise
inward boundary and endpoint entry count. Stationary boundary, tangent or
separating entry, travel along a face and isolated corner grazing do not hit.
Exact corner entry ties choose X. The projectile port additionally applies its
accepted separating/tangent zero-time filter. There is no epsilon inflation,
dynamic collider publication, broadphase, controller-response change or body
solver. A per-collider helper has no output buffer to truncate; bounded adapter
failure is explicitly tested.

## Static-sweep precision follow-up (2026-09-08)

Starting revision: `37d11c8e3a7e2f67e210df0bb71000efdbbee793`. Local and
remote integration/master refs matched the reviewed revisions; the integration
worktree was clean. Zig 0.16.0 and every installed SDL 3.4.10/DXC 1.9.2602.24
manifest file and archive hash were verified without dependency changes.

The requested Zig regression reproduced the reviewed defect before the fix:
point travel from `(-2^60,-2^60)` to `(2^60,2^60)` against minimum `(1,3)`,
maximum `(2,4)` returned fraction 0.5, normal `(-1,0)`, position `(1,3)`.
The analytic line `y=x` misses that box. The focused gate returned 1, with
34 passing tests, one failure and zero skips. Its original log is preserved
in `.tmp/projectile-impact-follow-up/sweep-reproduction.txt`.

The helper now converts each finite binary32 value exactly into units of
`2^-149`. Scaled magnitude is below `2^277`; expanded slab numerators use at
most three terms and deltas at most two. Signed i288 stores these values;
signed i576 stores ratio cross products and contact-coordinate numerators,
whose magnitude is below `2^558`. Only two axes are processed, using fixed
compiler integer storage with no allocation or precision-dependent loop.
The intersection decision uses exact ordering, with strict positive interior
intervals. A true entry/exit equality rejects grazing; genuine entry corner
ties still choose X. Contact coordinates use the exact rational numerator
before final float conversion, avoiding endpoint cancellation. No epsilon,
geometry enlargement, wider-float correctness assumption or domain reduction
is used. The public Sweep/Contact/Error API and existing contact conventions
are unchanged; physics acquires no application dependencies.

Analytic regressions cover the reported separation, reversed and axis-swapped
travel, valid extreme diagonal crossings and normals, true corner entry versus
grazing, body expansion, subnormal geometry and the retained maximum-f32 hit.
The original geometry and integration assertions remain intact. Follow-up logs
use the distinct directory above while reusing `.zig-cache` and
`.tmp/projectile-impact/global-cache`; previous evidence remains unchanged.

The corrected focused `test-engine-lab` gate returned 0 in Debug, ReleaseSafe
and ReleaseFast: 3/3 steps and 38 tests per mode (16 EL1, nine geometry and
13 integration). Formatting, repository architecture/hygiene, documentation
and full raw index/working-checkout integrity checks returned 0. These are new
follow-up executions, recorded in `commands.json`, not reused historical passes.

## Authored installation and tick order

Seed is the supplied hub seed (default `0123456789abcdef0123456789abcdef`).
Projectile namespace: `05a3a5bf-dab2-51fd-b625-cbb14f5fd6dd`.
Bridge namespace: `aaaf3d93-c358-535f-ae26-96d6dca205c4`.
The launcher is right-root position plus `(-0.3, -1.8)`, giving `(5.5, 1.2)`.
The marker resolves native collider 3 and uses its actual left face at X=8.
Activation uses completed actor center inside launcher half-range `(1.35, 1.2)`.
E or gamepad west launches at `(1.875, 0)` m/s, zero acceleration, half-extents
`(0.0625, 0.0625)`, lifetime 480 ticks, despawn-on-contact. The 1/128 m tick
increment gives contact on executed tick 312: center `(7.9375, 1.2)`, surface
`(8, 1.2)`, normal `(-1, 0)`. Flight takes 1.3 seconds at 240 Hz.

At successful tick entry all three counters equal N:

1. Consume at most one pending edge; observe completed actor position and core
   availability at N; capture an immutable spawn command or consume rejection.
2. Execute the existing controller, animation, station and camera block in its
   original relative order.
3. Step effects once, N to N+1.
4. Spawn once if accepted, while the projectile core is still at N.
5. Step projectiles once with the borrowed hub query, N to N+1.
6. Copy bounded observations; consume the ordered batch through Bridge once;
   clear core events only after successful consumption.
7. All counters equal N+1. Impact particles are age zero; they first advance on
   the following executed tick. No post-bridge effects step or extra removal.

Native spawn is tick 0/sequence 0; first movement is tick 1/sequence 1.
Contact is preceded by movement at tick 312/sequence 312, then collision at
tick 312/sequence 313. Despawn response retires the core record without a
synthetic removed event. The bridge emits 24 particles at age zero. Tick 313
gives age one; tick 456 has no particles or emitters. Empty/offscreen systems
step every executed hub tick. Errors propagate with the executing hub tick;
the application stops. Core transactional guarantees remain unchanged, and
whole-hub rollback is neither implemented nor claimed.

## Controls and lifetime

`actions.advance` is the single application composition point used by native
input and tests. Activation is separate from CharacterIntent. Keyboard event
latching preserves short E taps; edges coalesce to one pending bit. Holding E
or west does not repeat. Busy/out-of-range edges are consumed without later
automatic shots. Ready state reads the projectile core's active count.

Pause executes no ticks; one pending edge may wait. T consumes it during one
complete paused tick. F1/F2 retain the world, clock, station/core/bridge state
and world-space particles/projectiles, clear pending activation, and suppress
held actions until release. Offscreen ticks continue. Focus loss clears both
mapper and hub activation and suppresses held input until release.

R dominates all same-frame commands, reconstructs before teardown, restores
seeded tick-zero running state and empty cores/events/observations/bridge,
suppresses held input and executes zero reset-frame ticks. Failed construction
preserves the prior live hub at every tested allocation boundary, both during
flight and while particles remain. Renderer/platform lifetime is retained.

## Presentation and bounds

View copies one projectile snapshot and calls effects.extract into 64 fixed
slots, then submits ordinary SpriteRequests through UnifiedRenderQueue. Effect
sprite 1 explicitly maps to the existing neutral texture page 1. Unknown
sprites fail. Paused extraction uses completed state. No view simulation,
randomness, lifecycle, effects emission or resource creation is introduced.

Bounds: one projectile, four core events per batch (nominal maximum two for
this trajectory), eight emitters, 64 particles, one bridge trail record, one
pending activation and four copied diagnostic events. Impact bursts contain 24
particles with 144-tick lifetime; the earliest next contact is 312 ticks later.
Nominal operation therefore needs at most 24 particles and two emitters: a fresh
shot can briefly overlap its empty launch emitter with the preceding impact.
The measured spaced-shot smoke peaks at one emitter. Launch,
trail and expiration definitions intentionally emit zero particles; bridge
delivery still processes all native events. Saturation remains observable and
does not change projectile outcomes. No nominal impact particles are dropped.

Neutral texture/layer choices preserve exactly three batches and the existing
1,792-sprite queue limit. Shorter labels reserve capacity for the new prompt
and bounded L(launch), C(contact), D(drop) diagnostics (display capped at 999;
full counts remain in observations). GPU instance allocation remains 2,048
slots after initialization. Simulation/extraction/queue/report storage is
preallocated. Reset and explicit offline capture boundaries may allocate;
ordinary executed frames are guarded against allocation. SDL/driver internals
are outside the Zig allocation counter.

## Verification record and owner review

EL1's selected-state v2 algorithm and meaning are unchanged. The separate
`engine_lab.projectile_impact.observations.v1` hash covers authored configuration,
core ticks, copied projectile/particle records, live emitters reachable from
particles, ordered event history, pending command/capacity observations and
bridge sequence/count/metrics. It excludes private RNG/storage, empty emitter
records, camera, frame residue and EL1 state. This is diagnostic evidence,
not comprehensive core state, a save format or RR1 state. Repeated future
emissions after reset and read-only extraction exercise determinism beyond the
selected observations. Comparisons require equivalent executed semantic tick
streams; clock clamping/discard and differing raw input streams are excluded.

Task output is `.tmp/projectile-impact/`; caches are only `.zig-cache` and
`.tmp/projectile-impact/global-cache`, with install output under that task
directory. Raw command logs, validation identity and native PPM/PNG captures
are local review evidence. At explicit capture boundaries the fixture pauses
presentation temporarily to inspect completed state. The seven captures are ready, launch, flight,
contact, fade, drain and reset. `tools/engine_lab_impact_review.py` losslessly
encodes native readback RGB; it does not generate pixels. Accepted EL1,
Effects/Projectiles, canonical and historical evidence remain untouched.

The existing headless verification passes its 1,440-tick fixture. The separate
936-tick integration fixture repeats two launches/contacts across reset and
equivalent 4-tick/mixed frame groupings, including navigation and arbitrary
extraction/camera reads. Native D3D12 smoke passes the original 180-frame proof
and the added integration lifecycle, with zero measured steady allocations,
24 peak particles, one peak emitter, zero drops, and balanced resources/fences.
All required automated gates passed in this task. There are 34 Engine Lab
tests (16 retained, five geometry and 13 integration), plus 54 unchanged
Effects/Projectiles tests. Every command and exit is recorded in local
`gates.json`; `validation.json` supplies base/final identity, dependency lock
identity, explicit observation coverage, file inventory and log/capture hashes.

For the table, Zig means `.\.deps\zig-0.16.0\zig.exe`. Every build invocation
uses `-j1 --summary all --global-cache-dir .tmp/projectile-impact/global-cache
-p .tmp/projectile-impact/install`, before the application's `--` arguments.

| Executed command / arguments | Exit | Newly executed result |
| --- | ---: | --- |
| `zig fmt --check build.zig build.zig.zon build src tests` | 0 | No formatting differences |
| `pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/check_repository.ps1` | 0 | Architecture/hygiene and raw checkout integrity passed |
| `pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/check_documentation.ps1` | 0 | 46 required files, 42 Markdown files, 102 local targets |
| `zig build test-engine-lab test-effects-projectiles` | 0 | Debug: 6/6 steps, 88 tests |
| Same with `-Doptimize=ReleaseSafe` | 0 | 6/6 steps, 88 tests |
| Same with `-Doptimize=ReleaseFast` | 0 | 6/6 steps, 88 tests |
| `zig build check` | 0 | 37/37 steps, 583 tests |
| `zig build test-full` | 0 | 50/50 steps, 680 tests, including production composition and retained stress |
| `zig build` | 0 | Debug: 24/24 steps |
| `zig build -Doptimize=ReleaseSafe` | 0 | 24/24 steps |
| `zig build -Doptimize=ReleaseFast` | 0 | 24/24 steps |
| `zig build gpu-smoke` | 0 | Physical D3D12: 26/26 steps |
| `zig build run-engine-lab -- --verify` | 0 | 13/13 steps; original and integration fixtures passed |
| `zig build run-engine-lab -- --smoke` | 0 | 13/13 steps; original and integration native smokes passed |
| `python tools/engine_lab_impact_review.py` | 0 | Seven lossless RGB captures encoded |

Final native measurements: 26 resources created/released, 386 fences
acquired/released, zero measured steady allocations or queue growth, 24 peak
particles, one peak emitter in the scripted fixture, zero drops, and exactly
three texture batches. Captured frames contain 1,363-1,519 sprites. The
separate maximum-diagnostic/64-particle test also preserves the 1,792 bound.
Final flight/contact/fade captures were inspected. Their pixel identity is
reference-machine scoped and is not an owner acceptance claim.

Initial development runs exposed small-enum byte encoding, extreme-distance
slab precision, and label-capacity failures. These were corrected in source;
the original failing logs remain under `focused-debug-01` through `-05`.
No assertion was weakened, no test disabled and no accepted evidence changed.
The source audit found zero TODO/FIXME/unfinished-body or skipped-test findings.
No automated failure or environmental blocker remains.

Interactive command from the dedicated worktree:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 --global-cache-dir .tmp/projectile-impact/global-cache -p .tmp/projectile-impact/install
```

Use ordinary movement or F2, then E/gamepad west. Inspect flight and wall
contact, hold activation to confirm no repeat, pause and step through particle
birth/fade, travel while the shot is in flight, and reset during flight and
particles. Review the unchanged provisional segmented actor and spring stations.
Automated native captures are not owner visual acceptance; physical gamepad
feel and owner visual acceptance remain required. No PSM01 migration, World
Time, RR1, dynamic scene/body infrastructure or gameplay system is adopted.
