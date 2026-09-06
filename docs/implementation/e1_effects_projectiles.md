# E1 Generic Effects and Projectiles Foundation

Status: implemented and automated validation passed; PENDING OWNER REVIEW.
The complete domain plus wiring tree is validated. Owner acceptance is not claimed.

## Scope and preflight

Production headless projectile and CPU effect systems, a one-way presentation
bridge, and a small independent 2D SDL GPU proof client. No character, canonical
human, combat, editor, world simulation, or renderer authority is changed.

Original repository: `C:/Users/Chad/Documents/2d Renderer`.
Original branch: `master`; tracked and untracked status was empty.
Original HEAD, local origin/master and live remote master:
`cb60fc9a9b24ba7d69578ffc721948e9b00de8fd`.
This commit records owner acceptance of F4, following the audited implementation
`48a7c677d781543e479b178c6e7b10b139eeb26e`.

Dedicated worktree: `C:/Users/Chad/Documents/effects-projectiles-e1`.
Branch: `feature/e1-effects-projectiles`, created from that exact baseline.
Existing media-library worktrees remain at `ae21349` (foundation) and `b636c7a`
(UI). No prior E1 branch or preferred sibling directory existed.
Zig reported exactly `0.16.0` before changes. Existing pinned Zig, SDL3 3.4.10
and DXC 1.9.2602.24 are copied locally; dependencies are not updated.

## Pre-implementation infrastructure audit

| Infrastructure | Existing authority and E1 disposition |
|---|---|
| Math | `src/math` Vec2 and interpolation; reuse metre, Y-up 2D values. F spatial remains the 3D scene transform authority. |
| Identity | F EntityId and UUIDv5 fields; reuse explicit namespaces and stable keys. Specialized IDs do not allocate or replace RuntimeScene entities. Optional source IDs refer to host-owned F entities. |
| Time | P fixed_step owns 240 Hz; F SceneTime labels explicit ticks. No wall-clock reads in either core. |
| Randomness/hashes | F Seed128, named/versioned derivation and canonical domain hashing exist. No production particle PRNG exists. Effects use pinned Zig Xoshiro256++ with an explicit version and stable stream keys. |
| Scene | F root exposes RuntimeScene/read-only snapshots; no entity registry or hierarchy is needed for transient presentation particles. |
| Physics | Static AABB/collider IDs, overlap, separate horizontal/vertical character sweeps and ground-down queries exist. No general 2D segment sweep, collision masks or material payload exists. Stop at a narrow query boundary; fake query in tests, bounded scenario-owned target query in the proof. |
| Events | Animation has a specialized bounded EventBuffer; follow bounded ordered value buffers without importing animation or adding a bus. |
| Storage | RuntimeScene and renderer have private state, explicit initialization/destruction and bounded storage. E1 reserves all arrays at initialization. |
| Rendering | SpriteRequest and UnifiedRenderQueue are reusable production values; Renderer owns SDL/D3D12 resources. Effect extraction owns no GPU resources. |
| Applications | engine_smoke is a supported independent renderer client. No Engine Lab exists. Add a separate effects_projectiles proof client. |
| Validation | Typed validation/error returns, std.testing.allocator and fixed golden vectors; build/modules, apps, tests_engine and gates own explicit registration. |
| Existing effects | No projectile, emitter or particle system exists. Cape trails are attachment-motion demo evidence; equipment effects are property modifiers, not particle runtime. |
| Serialization | F canonical definitions are reusable, but full effect assets, save state and reload schemas are deliberately deferred. |

## Final ownership and contracts

`foundation / math / fixed_step / collider -> projectiles` and
`foundation / math / fixed_step / art_pack data -> effects` are independent headless graphs.
`projectiles + effects -> projectile_effects` is optional composition.
The application converts extracted values to the existing sprite queue.
Shared foundation, scene_core, physics and graphics files need no changes.
The only shared merge surfaces are build/modules.zig, build/apps.zig,
build/tests_engine.zig and build/gates.zig; see the wiring inventory below.

Projectiles copy validated definitions into runtime records, derive stable IDs
through F, accept explicit spawn/remove/enable/deflect commands, and publish
ordered value events. Failed commands and failed query/tick updates must not
publish partial state. Fast movement uses a full swept segment with half-extents.
Hit ordering uses a normalized-time bucket followed by collider ID so nearly
equal ties are transitive and independent of candidate enumeration order.
Bounce processing is bounded; continue-hit excludes already reported colliders
for the rest of that tick. Unconsumed travel at the collision bound is reported.

Effects copy scalar definitions and own independent named streams. One effect
owns one emitter in E1. Spawn identity/stream keys are supplied explicitly,
allowing independent streams regardless of request ordering. Emission is world
space; lifetimes use integer ticks; continuous rate uses fixed-point tick
accumulation. Particle overflow drops new particles deterministically and
reports counts; emitter overflow rejects the spawn. Stop drains living particles,
clear removes them, and reset explicitly invalidates old scenario observations.
Render extraction writes caller-owned values without changing simulation.

## Projectile API and lifecycle

The public entry point is [projectiles/root.zig](../../src/projectiles/root.zig).
`System.init(allocator, Config)` reserves records, transaction scratch records,
events and transaction scratch events. `deinit` releases every allocation.
The owner must not copy/destroy the same System twice. A namespace is explicitly
required; different independent systems must receive distinct namespaces.

| API | Behavior |
|---|---|
| `spawn(Spawn)` | Validates and copies Definition, position, velocity, optional F source EntityId and enabled flag. Returns F UUIDv5 identity derived from namespace, `p.projectile.v1`, and a big-endian monotonic counter. Failed requests consume neither identity nor event sequence. |
| `step(?collision.Query)` | One 240 Hz semi-implicit tick: acceleration updates velocity, swept travel resolves, age increments, lifetime expires. Null query means explicit collision-free simulation. |
| `remove(id)` | Emits removed and frees the record; unknown/stale IDs fail. |
| `setEnabled(id, bool)` | Disabled records retain identity and freeze motion and lifetime. |
| `deflect(id, Deflect)` | Replaces velocity, optionally changes or clears source, relocates, and/or restarts lifetime. Relocation synchronizes previous position to avoid a visual teleport streak. |
| `snapshot(id)`, `copySnapshots(buffer)` | Copied records in successful spawn order. No mutable runtime storage is returned. |
| `events()`, `clearEvents()` | Ordered const batch, borrowed until the next mutation. Consume/copy before clearing. Buffer exhaustion rejects a command or rolls back the entire tick. |
| `reset()` | Explicit replay reset: clears records/events and restarts IDs, event sequence and tick. Host discards all old observations/IDs at this boundary. |

Both cores expose only a const opaque ownership context, following the accepted
RuntimeScene boundary; callers cannot reach typed mutable arrays through the
public facade. An explicit boundary test protects this property.

Definition contains acceleration, lifetime ticks, swept half-extents (zero means
point), layer/mask, response, restitution, collision-iteration bound and generic
tag. No damage, health, weapon, character or team policy exists.

Events contain sequence, tick, kind, copied projectile state, segment origin,
incoming velocity, whole-step contact fraction, and optional hit metadata.
For each projectile, moved segments precede collided, then optional deflected;
expiration follows the last live tick. Collision-despawn is represented by the
collided event's despawn response, while explicit removal uses removed. Numeric
or query failures publish no partial projectile state or events, including when
a later projectile fails after earlier ones advanced in the transaction.

## Collision contract and PHY synchronization

[collision_query.zig](../../src/projectiles/collision_query.zig) accepts immutable
host context plus `collect(context, Sweep, Hits)`. Sweep supplies the full segment,
AABB half-extents, layer/mask, optional source and excluded collider IDs. The
callback enumerates candidates into bounded caller storage or returns an error;
it must be read-only and must not truncate silently. It may report at most one
candidate per native collider ID per query. E1 accepts at most 64 candidates.

A hit includes native ColliderId, optional F EntityId, surface contact position,
unit normal, normalized center-travel fraction, layer/mask and material token.
Invalid results fail the tick. Normal squared length tolerance is 1e-4; bounce
normalizes the accepted normal before reflection. Both masks must intersect.
Near ties are transitive: `floor(fraction * 1,000,000)`, then lower ColliderId.
A higher-time candidate in the same bucket can win by less than 1e-6 of the step.
This policy avoids enumeration-order-dependent chains of pairwise epsilon ties.

Responses: despawn on hit; continue and exclude each reported collider for the
rest of that tick; reflect using restitution in [0,1]. Continue can report the
same collider again on a later tick if a query reports initial overlap. Zero-time
separating/tangent contacts are ignored. Each definition permits 1-8 query
iterations, default 4. Reaching the bound holds the last contact position, emits
collision_limit with consumed step fraction, and discards remaining travel;
there is no unbounded retry, hidden catch-up or nudge. Lifetime still advances.

Production Physics currently has axis-specific character sweeps, not this
arbitrary segment contract. The required synchronization request is a PHY-owned
read-only point/AABB sweep adapter returning the candidate/contact contract,
with layer/material mapping and tests for thin walls, corners, overlap, masks,
source exclusion policy and deterministic ties. Dynamic colliders and broadphase
belong there. No shared physics file was changed.

The proof-only adapter in
[effects_projectiles_scene.zig](../../src/app/effects_projectiles_scene.zig)
reads the accepted CollisionWorld's immutable static collider data and performs
slab intersection against three scenario targets. It proves the narrow contract
with real spatial inputs; it is not a promoted general physics query API. The
pass-through target is 4 mm thick, less than one proof tick's travel. Shape
expansion, diagonal travel, initial overlap, and X-first exact corner normal
selection are explicit. Test fakes cover query errors, overflow and ordering.

## Effect API, determinism and lifetime

The public entry point is [effects/root.zig](../../src/effects/root.zig).
One effect owns one emitter in E1; each particle references both stable F UUIDs
and an emitter-local ordinal. Hosts supply a unique effect ID per replay session.
An active duplicate is rejected; an unbounded history of retired IDs is not kept.
Emitter ID is UUIDv5 derived from the effect ID in the fixed E-owned namespace.

| API | Behavior |
|---|---|
| `init(allocator, Config)` / `deinit()` | Reserve/release emitter and particle storage; seed is mandatory. |
| `spawn(Spawn)` | Copies the validated definition, stable effect ID and world position; emits burst immediately and returns emitter identity. |
| `step()` | One 240 Hz tick. Existing particles age/move first, then continuous particles spawn at age zero. |
| `setPosition(id, position)` | Moves future emission origin only; existing particles stay in world space. |
| `stop(id)` | Stops new emission and lets existing particles drain. |
| `clear(id)` | Removes that effect, emitter and its particles immediately. |
| `reset(seed)` | Clears all runtime state, counters and metrics; same seed/IDs/commands reproduce the same results. |
| `emitter(id)`, `copyParticles(buffer)` | Copied observations; definitions remain owned by runtime copies. |
| `extract(buffer, alpha)` | Caller-owned render values; no state mutation, allocation, RNG draw or GPU work. |

Definition supports burst, integer milli-particles/sec, duration/lifetime ticks,
position/velocity spread, initial velocity, acceleration, nonnegative drag,
rotation/angular velocity, start/end size, opacity and RGB color, accepted
AtlasRegionId and numeric render layer. It contains no authoritative gameplay
state. Emission scalar/vector magnitudes are bounded to 1,000,000 and lifetimes
to 1,000,000 ticks to retain finite arithmetic. Burst is at most 4096; continuous
emission at most 1024 particles per emitter per tick. Invalid definitions fail.

Continuous accumulation adds rate_milli each tick and divides by 240,000;
there is no floating-point rate drift. Emitter duration includes exactly that
many emission ticks. A particle spawned at tick T retires at T+lifetime_ticks.
Stopped/exhausted emitters retain identity until their particles drain.
Velocity uses semi-implicit acceleration followed by stable simple drag
`v = (v + acceleration*dt) / (1 + drag*dt)`. Linear size/color/opacity and render
position/rotation use the existing math.interpolation helpers. Extraction orders
by effect UUID and ordinal and interpolates completed states only.

Randomness uses F Seed128 and deriveKey with fixed generator/algorithm UUIDs,
version 1.0.0, effect ID and emitter ID. The first big-endian u64 of that key
seeds the pinned Zig 0.16 Xoshiro256++ implementation (its SplitMix64 seeding is
part of this recorded algorithm). Each particle consumes four top-24-bit signed
samples, even when dropped. The algorithm name is
`zig-0.16.xoshiro256plusplus.top24.v1`. No default PRNG, wall clock, address,
render call or other emitter's random consumption affects this stream. Changes
to the algorithm/framing require a new version and explicit golden review.

Independent Python UUID/SHA/integer-PRNG calculations established the fixed
projectile UUID, emitter UUID and four exact dyadic particle samples in the
contract tests. Repeated-run tests also compare complete copied records and
render instances. Determinism is scoped to the pinned toolchain/target and
identical definitions, IDs, seed and command order; cross-platform floating-point
or driver pixel identity is not promised.

## Capacity and complexity

| Storage | Default / hard maximum | Overflow behavior |
|---|---|---|
| Projectiles | 128 / 65,536 | Reject newest spawn with CapacityExceeded; preserve ID sequence. |
| Projectile events | 4096 / 1,048,576 | Command rejection or transactional whole-tick rollback; caller drains explicitly. |
| Query candidates | 64 | HitCapacity error and tick rollback. |
| Collision iterations | 4 / 8 per projectile/tick | Emit collision_limit and discard remaining travel. |
| Emitters | 128 / 4096 | Reject newest effect, increment rejected_emitters. |
| Particles | 2048 / 65,536 | Drop newest particles, consume RNG draws, increment dropped_particles. |
| Bridge trail records | 128 / 65,536 | Drop new tracking record and count dropped_trails. |
| Trail samples | 64 / 4096 per segment | Emit bounded prefix, retain distance remainder, count truncated_segments. |

The bridge counts emitter-capacity and out-of-effect-coordinate-domain emissions
as dropped_effects, leaving projectile authority untouched. Particle and emitter
metrics include peaks; counters saturate for reporting. Burst overflow priority
is request order; continuous priority is effect UUID order. Independent streams
remain stable under reordered requests, but which particles survive saturation
is deliberately part of the recorded command order.

Arrays are reserved once, records are compacted in stable order, and every
partial initialization frees acquired allocations. No general pool, registry,
ECS or container framework was introduced. Tick work is bounded by configured
capacity. Particle extraction and exhausted-emitter retirement currently scan
emitter/particle pairs; E1 makes no high-capacity throughput claim. A future
profile-driven index can reduce that cost without changing ownership or order.

## Composition and rendering boundary

[projectile_effects.zig](../../src/effect_composition/projectile_effects.zig)
accepts only ordered projectile event values and an effect system. It maps
spawned to launch, moved segment distance to trail, collided to contact burst,
and expired to expiration burst. Explicit removal/collision-despawn retires
trail tracking. Duplicate/out-of-order event batches fail before emitting.
Clients consume once before clearing the projectile batch. IDs derive from
projectile identity, event sequence and sample index; the adapter resets with
both systems. Distance remainder survives subspacing steps and bounce segments.

The renderer receives compact position, rotation, size, RGBA, AtlasRegionId and
layer values through
[effects_projectiles_view.zig](../../src/app/effects_projectiles_view.zig).
That application adapter resolves four proof atlas regions and submits ordinary
SpriteRequests to one UnifiedRenderQueue. Effect/projectile cores import no SDL,
renderer, shader, character, canonical model or gameplay code. Effects import
only art_pack's CPU AtlasRegionId data contract. The renderer owns all GPU
allocation, HLSL/DXIL pipelines, buffers, textures, swapchain and destruction.
No shared rendering or shader file changed.

The existing renderer's diagnostics graph still reaches character/interaction
types (accepted POST-F4-DEBT-001). This inherited compile coupling is present in
the proof executable; neither headless core depends on it, and E1 does not widen
or refactor that accepted debt.

## Visual proof and controls

From this dedicated worktree with its copied pinned dependencies:

```powershell
.\.deps\zig-0.16.0\zig.exe build run-effects-projectiles -j1
.\.deps\zig-0.16.0\zig.exe build effects-projectiles-smoke -j1 --summary all
```

The first command opens the interactive scenario. The second runs 180 hidden
D3D12 frames, 720 fixed ticks, resource/allocation assertions, and four explicit
GPU readbacks under `.zig-cache/e1-captures`. The installed executable also
accepts `--smoke` without `--capture` for a non-writing physical proof.

| Control | Action |
|---|---|
| Space | Pause/resume |
| Period | One fixed tick while paused |
| R | Reset same seed |
| N | Reset next seed |
| P | Spawn another projectile; capacity rejection is logged |
| D | Deflect/relaunch the first live projectile |
| F1 | Toggle velocity debug vectors |
| Escape | Quit |

Title counts show tick/projectiles/emitters/particles. Blue demonstrates lifetime
expiration, green bounce, red impact, yellow pass-through; a small separate
continuous emitter demonstrates autonomous effects. Lane bars and target blocks
are proof geometry, not new UI or art authority. After the scenario drains,
press R to repeat. World units and camera framing match the accepted renderer.

The ordinary loop reserves GPU capacity before stabilization and reports zero
subsequent allocation/resource growth. Explicit acceptance readback is outside
that loop and owns temporary CapturedFrame/PPM CPU allocations. PNGs below are
lossless encodings of the actual RGB readback; raw PPMs remain in local cache.
Owner visual acceptance is pending.
`python tools/effects_projectiles_review.py --compare evidence/e1` losslessly
encodes fresh PPMs into the local cache and checks reference-machine repetition.

| Fixed tick | Review frame |
|---|---|
| 120 | [Travel and trails](../../evidence/e1/tick_120.png) |
| 176 | [Bounce and pass-through bursts](../../evidence/e1/tick_176.png) |
| 212 | [Target impact](../../evidence/e1/tick_212.png) |
| 256 | [Expiration and draining effects](../../evidence/e1/tick_256.png) |

## Tests and measured results

The focused test-effects-projectiles target is part of test/check/test-full/verify.
Its 41 tests (17 projectile, 13 effect, 5 composition and 6 proof/ownership)
cover the requested projectile, effect, composition and proof
behaviors, query failure/overflow transactionality, stale commands, independent
fixed vectors, owned definitions, all allocation-failure sites, zero steady-state
allocation, and complete 480-tick presentation-on/off replay with real queue
submissions. No existing tests or assertions were changed or disabled.

The first physical Debug proof reported 180 frames, 720 ticks, 3 collisions,
1 deflection, 3 expirations, peaks of 4 projectiles / 171 emitters / 291 particles,
445 trail samples, 300 submitted sprites and one instanced sprite draw per frame.
It reported zero dropped particles/effects and zero steady-state allocations.
Tracking covers Zig allocations through the client allocator and renderer
resource counters; SDL/driver internal allocations are not measured.
Simulation time was 205,864,500 ns over 720 ticks (about 0.286 ms/tick), with
1,475,546,800 ns wall time. These are one local Debug observation, not a benchmark
promise. Renderer cleanup balanced 23 creations/releases and 185 fences.

## Shared wiring and integration review

Only these pre-existing files change:

| File | Wiring and conflict risk |
|---|---|
| build/modules.zig | Explicit E1 core, bridge, proof and test modules; highest shared edit contention. |
| build/apps.zig | Third independent executable, build/run/smoke routes; localized registration conflict. |
| build/tests_engine.zig | E1 test executable using the accepted simple test runner; localized registration conflict. |
| build/gates.zig | Add E1 headless tests to test and executable compilation to check; two additive edges. |

No changes to root build.zig, main.zig, tests/test_all.zig, shared physics,
foundation, scene_core, graphics, shaders, canonical human/HM08/MPFB assets or
animation sources. The integration wiring is kept separately reviewable from
domain source/tests/evidence. Apply the complete lane before acceptance testing.
No merge or push is part of E1.

## Deferred integrations and owner decisions

- Physics: production arbitrary-segment query/layer/material adapter, dynamic
  collision and broadphase; the exact proposed boundary is documented above.
- Engine Lab: mount this isolated client only when an accepted extension point
  exists; no Engine Lab was created.
- World/environment: caller supplies world-space emission origins and handles
  host entity/level removal. Weather, liquid and streaming behavior are deferred.
- Record/replay: replay seed, IDs, definitions and ordered commands at 240 Hz.
  Snapshot observation is implemented; full runtime restore/save, effect asset
  serialization and cross-version migration are deferred.
- Future 3D presentation: reuse lifecycle/event principles through a separately
  approved 3D spatial/extraction adapter. E1's current Vec2 simulation is explicit;
  the accepted 2D renderer received no 3D feature.
- Owner review: API names, ordering/overflow policies, one-emitter effect scope,
  visual proof and the future PHY adapter should be reviewed before integration.
  Automated validation does not confer owner acceptance.

## Validation environment and resolved findings

The first aggregate verify run exposed default Windows checkout conversions:
core.autocrlf=true created CRLF Zig sources and changed twelve exact archival
prompt/report hashes. Git-normalized content matched the accepted baseline.
The archival originals include mixed line endings in some reports, so their
verified pinned bytes were recovered read-only from the original checkout only
after checking both the existing SHA256 expectations and normalized Git blobs.
The same checkout conversion also affected source formatting and canonical text
fixtures/manifest byte totals. In total, twelve archival files and 574 other
checkout-converted files were restored after normalized Git-content checks.
Only the isolated worktree's bytes were repaired; checkers/hashes were unchanged.
Zig formatting removes checkout-only CRLF differences from code. These repairs
introduce no Git content diff and do not change historical or canonical authority.

During implementation, focused gates caught and resolved Zig shadowed names,
an incorrect math export reference, a compile-time numeric division, proof UV
min/max bounds, and normalization of native physics AllocationFailure into the
composed allocator contract's OutOfMemory. The initial pass-through target was
thicker than one tick of travel and correctly yielded another overlap hit on the
next tick; the proof now uses a 4 mm target to demonstrate a complete swept
crossing in one tick while retaining exact collision-count assertions. Existing
and new assertions were not weakened to mask failures.

## Preservation verification

A final read-only comparison found all 927 pre-existing files outside the four
E1 wiring edits byte-identical to the original checkout. This includes 456
protected canonical-human, geometry, Blender and HM08 qualification files.
Original master remains clean at cb60fc9a9b24ba7d69578ffc721948e9b00de8fd.
No original working-tree file was written, no user changes were absorbed, and no
push, merge, reset, clean, rebase, branch deletion or worktree deletion occurred.
The four locally generated raw proof PPMs were retained in the dedicated cache;
only their lossless PNG review copies are versioned.


## Final automated validation

The corrected complete `verify` gate passed **92/92 build steps**, including
fast, full, stress and content acceptance. Its 37 completed test executables
reported **712 successful test executions**; this is an execution count, not a
claim that cross-suite contracts are deduplicated. All existing applications and
the E1 proof compile in Debug, ReleaseSafe and ReleaseFast. E1's 41 focused tests
pass in each of those modes with allocator leak checks enabled by the tests.

Exact final command records, durations, source hashes, preservation checks and
readback hashes are in [validation.json](../../evidence/e1/validation.json).
The complete aggregate output is [verify.txt](../../evidence/e1/verify.txt).
Versioned text logs normalize line endings and remove trailing blank lines;
raw command output remains in the dedicated validation cache.

| Command from this worktree | Exit | Observed result |
|---|---|---|
| `.\.deps\zig-0.16.0\zig.exe build verify -j1 --summary all` | 0 | 92/92 steps succeeded; 712 reported test executions |
| `.\.deps\zig-0.16.0\zig.exe build -j1 --summary all` | 0 | 24/24 steps succeeded |
| `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseSafe -j1 --summary all` | 0 | 24/24 steps succeeded |
| `.\.deps\zig-0.16.0\zig.exe build test-effects-projectiles -Doptimize=ReleaseSafe -j1 --summary all` | 0 | 3/3 steps succeeded; 41 reported test executions |
| `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseFast -j1 --summary all` | 0 | 24/24 steps succeeded |
| `.\.deps\zig-0.16.0\zig.exe build test-effects-projectiles -Doptimize=ReleaseFast -j1 --summary all` | 0 | 3/3 steps succeeded; 41 reported test executions |
| `.\.deps\zig-0.16.0\zig.exe build gpu-smoke -j1 --summary all` | 0 | 26/26 steps succeeded |
| `.\.deps\zig-0.16.0\zig.exe build effects-projectiles-smoke -j1 --summary all` | 0 | 26/26 steps succeeded |
| `python tools/effects_projectiles_review.py --compare evidence/e1` | 0 | E1_REVIEW_OK frames=4 lossless_rgb=true |

The final post-documentation command `.\.deps\zig-0.16.0\zig.exe build test check -j1 --summary all` returned **0**: 28/28 steps succeeded, with 425 reported successful test executions. Its [complete log](../../evidence/e1/check.txt) records the final formatting, repository and documentation checks.

The complete formatter command
`.\.deps\zig-0.16.0\zig.exe fmt build.zig build.zig.zon build src tests`
returned zero, and `verify` then passed its independent formatting check.
`git -c safe.directory='C:/Users/Chad/Documents/effects-projectiles-e1' -c core.safecrlf=false diff --check`
returned zero with no output. The E1 source audit scanned 14 Zig/Python files:
zero TODO/FIXME markers, unfinished bodies, prohibited API references or skipped
tests were found. No existing test file changed.

The final [E1 GPU proof](../../evidence/e1/proof.txt) reproduced every first-run
behavior/count and all four GPU RGBA hashes. It measured 298,206,800 ns simulation
time over 720 ticks (about 0.414 ms/tick) and 1,469,253,600 ns wall time.
These two Debug observations vary under local workload; no high-capacity or
cross-machine performance guarantee is inferred. The final proof balanced
23 GPU creations/releases and 185 fence acquisitions/releases, submitted at most
300 sprites with one instanced draw per frame, and measured zero steady-state
Zig allocations and zero dropped particles/effects.
The existing [GPU smoke](../../evidence/e1/gpu-smoke.txt) also returned zero,
including its resource-initialization failure cleanup checks.
The [repeat comparison](../../evidence/e1/review.txt) reproduced all four PNGs.

Focused raw results: [Debug](../../evidence/e1/focused-debug.txt),
[ReleaseSafe](../../evidence/e1/focused-release-safe.txt), and
[ReleaseFast](../../evidence/e1/focused-release-fast.txt).
No unresolved automated validation failure remains. Keyboard interactions are
implemented and their scene operations have headless tests; manual input and
owner visual/API acceptance remain review work, not an automated acceptance claim.

## New-file inventory

| Area | Files created |
|---|---|
| Projectile core | `src/projectiles/root.zig`, `src/projectiles/collision_query.zig` |
| Effect core | `src/effects/root.zig` |
| Composition | `src/effect_composition/projectile_effects.zig` |
| Proof client | `src/app/effects_projectiles.zig`, `src/app/effects_projectiles_scene.zig`, `src/app/effects_projectiles_view.zig` |
| Tests | `tests/effects/root.zig`, `support.zig`, `projectile_tests.zig`, `effect_tests.zig`, `composition_tests.zig`, `proof_tests.zig` |
| Review utility | `tools/effects_projectiles_review.py` |
| Documentation | `docs/implementation/e1_effects_projectiles.md` |
| Evidence | Four `evidence/e1/tick_*.png` readbacks; `validation.json`, `verify.txt`, `focused-debug.txt`, `focused-release-safe.txt`, `focused-release-fast.txt`, `gpu-smoke.txt`, `proof.txt`, `review.txt`, `check.txt` |

The four existing-file edits are enumerated separately under Shared wiring.
Commit packaging separates domain implementation/tests/report/evidence from
shared build registration so another lane can review the integration surfaces
independently. Both commits together form the validated E1 feature; neither
changes the accepted master branch. The final commit identity is reported in
the delivery response and can be read with `git rev-parse HEAD` in this worktree.

The checkout conversion also left stale Git stat entries. A metadata refresh of
927 already-tracked, byte-verified baseline entries produced zero staged content
changes; final tracked status then contained only the four intended wiring files.
No index refresh or file write was performed in the original checkout.
