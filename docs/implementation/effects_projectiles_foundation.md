# Generic Effects and Projectiles Foundation

Status: corrective follow-up implemented and all required automated gates passed.
Owner visual, manual-input and API review remain pending. Original validation
is preserved separately as historical evidence.


## Corrective architecture alignment

This is an owner-authorized corrective follow-up to the completed implementation,
not a rewrite or a new numbered roadmap milestone. The preliminary label **E1**
was invalid: the owner's `2d_game_engine_chat_reconciliation_2026-09-02` decisions
reserve **E1 for Character Editor**, and E2-E7 for other editor tracks. Those
reconciliation decisions are supplied explicitly in the correction request;
the named reconciliation document is not present at this checkout's baseline.
The accepted repository architecture/status/roadmap records were also inspected.
No authoritative roadmap/status file or legitimate Character Editor reference
is edited by this correction.

This **Generic Effects and Projectiles Foundation** is an owner-authorized
parallel foundation pulled forward from later effects/projectile work because
it can progress independently of the Base Human. It does not replace or renumber
the canonical M03/M04 sequence, is not Character Editor E1, and does not complete
Phase D or Phase L. It does not complete fireball, abilities, cooldowns, combat,
enemies, baseball, weather, liquids, Engine Lab or record/replay. It supplies
reusable mechanisms that compatible later systems may choose to consume.
F1-F4 remain the accepted shared foundation; game/content owns rules, values,
meaning and balance. Headless mechanisms remain upstream of clients.

### Corrective preflight and history

- Worktree: `C:/Users/Chad/Documents/effects-projectiles-e1`, retained under its
  historical directory name solely to avoid unnecessary worktree movement.
- Original branch: `feature/e1-effects-projectiles`.
- Corrected branch: `feature/effects-projectiles-foundation`.
- Accepted foundation: `cb60fc9a9b24ba7d69578ffc721948e9b00de8fd`.
- Existing domain: `b39931a1d36ffd8839f5c34ed436bc68a4016117`.
- Existing final/pre-correction HEAD: `2833d4e857b0023d64a298338f705a6a009178fa`.
- Verified clean feature worktree, expected HEAD and ancestry, no upstream,
  no replacement branch, and no feature-containing ref except the local feature.
- Live `git ls-remote --heads --tags origin` exposed only accepted master at the
  foundation commit. Neither feature name was present on the remote.
- Original master was clean at the foundation commit and had not absorbed this
  feature. Its 931 tracked file byte hashes were recorded before changes.
- Full original feature diff: 32 files, 4,429 insertions and one deletion; no
  shared-domain source changes beyond the four build registration files.
- Required pre-change `zig build verify -j1 --summary all` returned **0**, with
  **92/92 steps and 712 reported successful test executions**, in 628.911 seconds.
- Branch rename used `git branch -m`, without force. Report/evidence moves used
  `git mv`. The two original commits and messages remain unchanged and ancestors
  of the corrective commits. No second copy of the feature branch was created.

Historical initial evidence is retained byte-for-byte under
`evidence/effects_projectiles/history/initial/`. Preliminary E1 markers and the
old branch in those immutable records are historical output, not current names.
The old occurrences remain in Git history. Current capture/review markers are
`EFFECTS_PROJECTILES_PROOF_OK` and `EFFECTS_PROJECTILES_REVIEW_OK`; current test
artifact is `effects-projectiles-tests`. Build commands were already descriptive
and remain `test-effects-projectiles`, `effects-projectiles`,
`run-effects-projectiles`, and `effects-projectiles-smoke`.

### Verified 2D and module boundaries

Positions, velocities, accelerations, swept inputs, particles and extraction use
the existing `math.Vec2`: X right, Y up, metres, seconds and radians, at 240 Hz.
The SDL GPU proof is a 2D client. No dimension-generic vectors, 3D runtime,
Model Lab or canonical-human authoring changes are introduced. A later 3D system
may adapt compatible definitions/events; this branch implements and promises no
such adapter.

| Module | Direct production imports | Ownership conclusion |
|---|---|---|
| projectiles | std, foundation, math, fixed_step, collider, local collision_query | Transient identity/lifecycle/state/commands and consumer-owned 2D query port; no effects or presentation |
| effects | std, foundation, math, fixed_step, art_pack | Independent deterministic CPU particles; no projectiles, production body/collision system, renderer, SDL or GPU ownership |
| projectile_effects | std, projectiles, effects, math, foundation | Optional one-way event-to-particle composition |
| effects_projectiles_scene | both cores, bridge, foundation/math, collider/CollisionWorld | Scenario-owned test/proof composition; accepted static world plus bounded scenario query |
| effects_projectiles_view | scene, both copied core views, math, sprite_batch/render_queue | Translates values into existing graphics requests |
| effects_projectiles application | scene/view, fixed_step, SDL, production renderer | Window, input mapping, ticks and resource-owning renderer composition |

`fixed_step` resides in `src/physics` but imports only std and supplies the
accepted deterministic clock/constants. Consuming that time contract introduces
no production physics-system dependency. `art_pack` resides in `src/graphics`
but imports only std; the effect core consumes only its accepted `AtlasRegionId`
asset-reference type. It owns no texture, material implementation or rendering
operation. These narrow accepted contracts are retained rather than duplicated.
Foundation and math keep their accepted inward-only dependencies. Test wiring
uses the same core modules with CPU-only query/queue adapters; only the application
links SDL. Existing renderer diagnostic compile coupling remains inherited
POST-F4-DEBT-001, outside both core module graphs.

### Projectile versus physics ownership

The actual accepted Physics implementation provides a character controller with
character-specific gravity/movement policy and horizontal/vertical AABB sweeps.
There is no general body integrator or arbitrary-segment production sweep port
at this baseline. This audit found no reusable accepted facility materially
duplicated by the bounded transient-projectile mechanism. Its existing
semi-implicit kinematics, finite swept query and bounded response loop stay.
It introduces no second collision world, broadphase or general rigid-body solver.
The proof reads the existing CollisionWorld; test fakes remain deterministic.

Generic reusable force integration and collision mechanisms belong to Physics.
Projectile infrastructure owns identity, configuration, lifetime, commands,
lifecycle events, source, affiliation, filter state, response policy and snapshots.
A PHY-owned production point/AABB sweep/body adapter with layer/material mapping
remains an explicit synchronization point; no shared Physics file was changed to
conceal the missing integration. Future dynamic/rigid-body work needs its own
contract and acceptance. Baseball code may compute its own drag, spin, Magnus
force and outcomes; this transient mechanism is not complete baseball physics.

### Corrected source, affiliation, filters and deflection

`source` retains the existing optional F EntityId and means current host-assigned
owner/source. It is not an origin-history list or a gameplay authority grant.
No accepted generic affiliation/faction/team type exists in the inspected source.
`projectiles.Affiliation` therefore aliases a projectile-local opaque `enum(u64)`
from its query port. All token values are valid; null means absent. The host owns
meaning and lifetime. This adds no faction registry, relations or combat policy.
The query receives copied source and affiliation metadata; affiliation alone
never infers a filter or relationship.

Definition layer/mask fields remain immutable spawn defaults. Each Snapshot now
carries current `layer` and `mask` independently. `Deflect` can replace velocity,
source, affiliation, layer and/or mask together, with its existing optional
position and lifetime restart. Omitted source/affiliation commands preserve them;
a populated optional may clear them. Omitted filters preserve current values;
zero is a valid mask selecting no candidates. Source IDs retain F validation.

A successful command validates and constructs one candidate, reserves its ordered
event, then publishes all fields synchronously at the current completed tick.
A failed command publishes neither partial state nor an event. The owner issues
commands between ticks on one thread; queries cannot reenter/mutate the system,
and concurrent access is unsupported. A following step observes the complete
new state. Commands after tick T carry tick T; step advances to T+1. Sequence
numbers preserve command/lifecycle ordering at that boundary.

Every `deflected` event, including automatic bounce, contains a copied
`before_deflection` Snapshot and copied after-state in `projectile`. Incoming
velocity is retained. Automatic bounce changes velocity while retaining source,
affiliation and filters. Events remain borrowed const batches until mutation;
copy an Event value when its before/after history must survive later mutations.

Both mask intersections still apply: `(projectile.layer & hit.mask) != 0` and
`(projectile.mask & hit.layer) != 0`. The host explicitly supplies filters that
permit the former source and exclude the new one; source identity and affiliation
do not hardcode automatic friendly/hostile rules. Six new focused tests cover
coherent transfer, failed-command rollback, both filter directions, immutable
before/after records, exact tick/sequence ordering, reset/repeat identity, bounce
preservation, absent fields and explicit clears. Two new proof tests cover a
sweep beginning inside the new source, and repeated redirected simulation with
presentation disabled. Existing assertions and golden ID/RNG values are retained.

### Particle scope and future consumers

The current effects subsystem is the deterministic 2D CPU particle/emitter portion
of the broader future effects vocabulary. Its independent APIs and random streams
are preserved. It adds no decals, lights, screen shake, audio, shader-effect graphs,
editors, GPU compute, particle collision, liquid deposition or general asset graphs.

Compatible later consumers may include fireball presentation/motion, ranged
attacks, collectible bursts, impact particles, weather-particle presentation and
visual droplets. None is required to use this exact implementation. This branch
does not implement or guarantee abilities, cooldowns, damage/combat, enemy AI,
baseball-ball physics/drag/spin/Magnus rules, hitscan weapons, rigid-body
projectiles, liquid collision/deposition/transfer/drying, weather simulation,
gameplay-authoritative particles, full replay serialization, runtime 3D, the
production PHY adapter or Engine Lab integration.

## Original implementation scope and preflight (historical)

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
Initial branch: `feature/e1-effects-projectiles`, created from that exact baseline.
The corrective follow-up renamed it without changing either prior commit.
Existing media-library worktrees remain at `ae21349` (foundation) and `b636c7a`
(UI). No prior preliminary feature branch or preferred sibling directory existed.
Zig reported exactly `0.16.0` before changes. Existing pinned Zig, SDL3 3.4.10
and DXC 1.9.2602.24 are copied locally; dependencies are not updated.

## Pre-implementation infrastructure audit (accepted baseline)

| Infrastructure | Existing authority and effects/projectiles disposition |
|---|---|
| Math | `src/math` Vec2 and interpolation; reuse metre, Y-up 2D values. F spatial remains the 3D scene transform authority. |
| Identity | F EntityId and UUIDv5 fields; reuse explicit namespaces and stable keys. Specialized IDs do not allocate or replace RuntimeScene entities. Optional source IDs refer to host-owned F entities. |
| Time | P fixed_step owns 240 Hz; F SceneTime labels explicit ticks. No wall-clock reads in either core. |
| Randomness/hashes | F Seed128, named/versioned derivation and canonical domain hashing exist. No production particle PRNG exists. Effects use pinned Zig Xoshiro256++ with an explicit version and stable stream keys. |
| Scene | F root exposes RuntimeScene/read-only snapshots; no entity registry or hierarchy is needed for transient presentation particles. |
| Physics | Static AABB/collider IDs, overlap, separate horizontal/vertical character sweeps and ground-down queries exist. No general 2D segment sweep, collision masks or material payload exists. Stop at a narrow query boundary; fake query in tests, bounded scenario-owned target query in the proof. |
| Events | Animation has a specialized bounded EventBuffer; follow bounded ordered value buffers without importing animation or adding a bus. |
| Storage | RuntimeScene and renderer have private state, explicit initialization/destruction and bounded storage. Each core reserves all arrays at initialization. |
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
owns one emitter in this foundation. Spawn identity/stream keys are supplied explicitly,
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
| `spawn(Spawn)` | Validates and copies Definition, position, velocity, optional F source EntityId, optional affiliation token and enabled flag; initializes runtime layer/mask from Definition. Returns F UUIDv5 identity derived from namespace, `p.projectile.v1`, and a big-endian monotonic counter. Failed requests consume neither identity nor event sequence. |
| `step(?collision.Query)` | One 240 Hz semi-implicit tick: acceleration updates velocity, swept travel resolves, age increments, lifetime expires. Null query means explicit collision-free simulation. |
| `remove(id)` | Emits removed and frees the record; unknown/stale IDs fail. |
| `setEnabled(id, bool)` | Disabled records retain identity and freeze motion and lifetime. |
| `deflect(id, Deflect)` | Atomically replaces velocity and optionally source, affiliation, runtime layer/mask, position, and lifetime age. Null source/affiliation commands preserve the field; a populated optional may explicitly clear it. Relocation synchronizes previous position to avoid a visual teleport streak. |
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
incoming velocity, whole-step contact fraction, and optional hit metadata. Every
deflected event additionally carries a complete copied before_deflection Snapshot;
projectile is its complete after-state, for both commands and automatic bounce.
For each projectile, moved segments precede collided, then optional deflected;
expiration follows the last live tick. Collision-despawn is represented by the
collided event's despawn response, while explicit removal uses removed. Numeric
or query failures publish no partial projectile state or events, including when
a later projectile fails after earlier ones advanced in the transaction.

## Collision contract and PHY synchronization

[collision_query.zig](../../src/projectiles/collision_query.zig) accepts immutable
host context plus `collect(context, Sweep, Hits)`. Sweep supplies the full segment,
AABB half-extents, current runtime layer/mask, optional source and affiliation,
and excluded collider IDs. The
callback enumerates candidates into bounded caller storage or returns an error;
it must be read-only and must not truncate silently. It may report at most one
candidate per native collider ID per query. The query port accepts at most 64 candidates.

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
slab intersection against the original three targets and two optional source targets. It proves the narrow contract
with real spatial inputs; it is not a promoted general physics query API. The
pass-through target is 4 mm thick, less than one proof tick's travel. Shape
expansion, diagonal travel, initial overlap, and X-first exact corner normal
selection are explicit. Test fakes cover query errors, overflow and ordering.

## Effect API, determinism and lifetime

The public entry point is [effects/root.zig](../../src/effects/root.zig).
One effect owns one emitter in this foundation; each particle references both stable F UUIDs
and an emitter-local ordinal. Hosts supply a unique effect ID per replay session.
An active duplicate is rejected; an unbounded history of retired IDs is not kept.
Emitter ID is UUIDv5 derived from the effect ID in the fixed effect-owned namespace.

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
emitter/particle pairs; this foundation makes no high-capacity throughput claim. A future
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
the proof executable; neither headless core depends on it, and this foundation does not widen
or refactor that accepted debt.

## Visual proof and controls

From this dedicated worktree with its copied pinned dependencies:

```powershell
.\.deps\zig-0.16.0\zig.exe build run-effects-projectiles -j1
.\.deps\zig-0.16.0\zig.exe build effects-projectiles-smoke -j1 --summary all
```

The first command opens the interactive scenario. The second runs 180 hidden
D3D12 frames, 720 fixed ticks, resource/allocation assertions, and four explicit
GPU readbacks under `.zig-cache/effects-projectiles-captures`. The installed executable also
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

The corrected application uses resetWithOwnershipProof to add a fifth bottom
lane. Its projectile starts with source A/affiliation A, then a client command
between ticks 120 and 121 transfers source to B, changes affiliation and both
filter directions, and redirects velocity toward A. A later swept collision
hits former source A; source B is excluded by the new filter. Blue/red bottom
blocks identify A/B. The real-overlap test separately starts inside B to prove
that exclusion is caused by filtering. The original four-case reset remains
covered with its original exact collision/expiration/bounce assertions.

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
`python tools/effects_projectiles_review.py --compare evidence/effects_projectiles` losslessly
encodes fresh PPMs into the local cache and checks reference-machine repetition.

| Fixed tick | Review frame |
|---|---|
| 120 | [Travel and trails](../../evidence/effects_projectiles/tick_120.png) |
| 176 | [Bounce and pass-through bursts](../../evidence/effects_projectiles/tick_176.png) |
| 212 | [Target impact](../../evidence/effects_projectiles/tick_212.png) |
| 256 | [Expiration and draining effects](../../evidence/effects_projectiles/tick_256.png) |

## Original tests and measurements (historical)

The focused test-effects-projectiles target is part of test/check/test-full/verify.
The original 41 tests (17 projectile, 13 effect, 5 composition and 6 proof/ownership)
cover the requested projectile, effect, composition and proof
behaviors, query failure/overflow transactionality, stale commands, independent
fixed vectors, owned definitions, all allocation-failure sites, zero steady-state
allocation, and complete 480-tick presentation-on/off replay with real queue
submissions. The corrective pass retains these assertions and adds eight contracts (49 total).

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
| build/modules.zig | Explicit effects/projectiles core, bridge, proof and test modules; highest shared edit contention. |
| build/apps.zig | Third independent executable, build/run/smoke routes; localized registration conflict. |
| build/tests_engine.zig | Effects/projectiles test executable using the accepted simple test runner; localized registration conflict. |
| build/gates.zig | Add effects/projectiles headless tests to test and executable compilation to check; two additive edges. |

No changes to root build.zig, main.zig, tests/test_all.zig, shared physics,
foundation, scene_core, graphics, shaders, canonical human/HM08/MPFB assets or
animation sources. The integration wiring is kept separately reviewable from
domain source/tests/evidence. Apply the complete lane before acceptance testing.
No merge or push is part of this feature.

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
  approved 3D spatial/extraction adapter. The current Vec2 simulation is explicit;
  the accepted 2D renderer received no 3D feature.
- Owner review: API names, ordering/overflow policies, one-emitter effect scope,
  visual proof and the future PHY adapter should be reviewed before integration.
  Automated validation does not confer owner acceptance.

## Original validation environment and resolved findings (historical)

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

## Original preservation verification (historical)

A final read-only comparison found all 927 pre-existing files outside the four
feature wiring edits byte-identical to the original checkout. This includes 456
protected canonical-human, geometry, Blender and HM08 qualification files.
Original master remains clean at cb60fc9a9b24ba7d69578ffc721948e9b00de8fd.
No original working-tree file was written, no user changes were absorbed, and no
push, merge, reset, clean, rebase, branch deletion or worktree deletion occurred.
The four locally generated raw proof PPMs were retained in the dedicated cache;
only their lossless PNG review copies are versioned.


## Initial feature file inventory (historical, paths corrected)

| Area | Files created |
|---|---|
| Projectile core | `src/projectiles/root.zig`, `src/projectiles/collision_query.zig` |
| Effect core | `src/effects/root.zig` |
| Composition | `src/effect_composition/projectile_effects.zig` |
| Proof client | `src/app/effects_projectiles.zig`, `src/app/effects_projectiles_scene.zig`, `src/app/effects_projectiles_view.zig` |
| Tests | `tests/effects/root.zig`, `support.zig`, `projectile_tests.zig`, `effect_tests.zig`, `composition_tests.zig`, `proof_tests.zig` |
| Review utility | `tools/effects_projectiles_review.py` |
| Documentation | `docs/implementation/effects_projectiles_foundation.md` |
| Historical initial evidence | Four `evidence/effects_projectiles/history/initial/tick_*.png` readbacks; `validation.json`, `verify.txt`, `focused-debug.txt`, `focused-release-safe.txt`, `focused-release-fast.txt`, `gpu-smoke.txt`, `proof.txt`, `review.txt`, `check.txt` |

The four existing-file edits are enumerated separately under Shared wiring.
Commit packaging separates domain implementation/tests/report/evidence from
shared build registration so another lane can review the integration surfaces
independently. The original two commits form the initial feature; neither
changes the accepted master branch. Corrective commits are appended to those two commits. The final correction
identity is reported in the delivery response and by `git rev-parse HEAD`.

The checkout conversion also left stale Git stat entries. A metadata refresh of
927 already-tracked, byte-verified baseline entries produced zero staged content
changes; final tracked status then contained only the four intended wiring files.
No index refresh or file write was performed in the original checkout.

The following original measurements and command labels are retained as historical facts at `2833d4e857b0023d64a298338f705a6a009178fa`. Preliminary E1 labels here identify that old run only. Current corrective results appear separately below.

## Original implementation validation (historical)

At the original final commit, the complete `verify` gate passed **92/92 build steps**, including
fast, full, stress and content acceptance. Its 37 completed test executables
reported **712 successful test executions**; this is an execution count, not a
claim that cross-suite contracts are deduplicated. All existing applications and
the E1 proof compile in Debug, ReleaseSafe and ReleaseFast. E1's 41 focused tests
pass in each of those modes with allocator leak checks enabled by the tests.

Exact final command records, durations, source hashes, preservation checks and
readback hashes are in [validation.json](../../evidence/effects_projectiles/history/initial/validation.json).
The complete aggregate output is [verify.txt](../../evidence/effects_projectiles/history/initial/verify.txt).
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

The final post-documentation command `.\.deps\zig-0.16.0\zig.exe build test check -j1 --summary all` returned **0**: 28/28 steps succeeded, with 425 reported successful test executions. Its [complete log](../../evidence/effects_projectiles/history/initial/check.txt) records the final formatting, repository and documentation checks.

The complete formatter command
`.\.deps\zig-0.16.0\zig.exe fmt build.zig build.zig.zon build src tests`
returned zero, and `verify` then passed its independent formatting check.
`git -c safe.directory='C:/Users/Chad/Documents/effects-projectiles-e1' -c core.safecrlf=false diff --check`
returned zero with no output. The E1 source audit scanned 14 Zig/Python files:
zero TODO/FIXME markers, unfinished bodies, prohibited API references or skipped
tests were found. No existing test file changed.

The final [E1 GPU proof](../../evidence/effects_projectiles/history/initial/proof.txt) reproduced every first-run
behavior/count and all four GPU RGBA hashes. It measured 298,206,800 ns simulation
time over 720 ticks (about 0.414 ms/tick) and 1,469,253,600 ns wall time.
These two Debug observations vary under local workload; no high-capacity or
cross-machine performance guarantee is inferred. The final proof balanced
23 GPU creations/releases and 185 fence acquisitions/releases, submitted at most
300 sprites with one instanced draw per frame, and measured zero steady-state
Zig allocations and zero dropped particles/effects.
The existing [GPU smoke](../../evidence/effects_projectiles/history/initial/gpu-smoke.txt) also returned zero,
including its resource-initialization failure cleanup checks.
The [repeat comparison](../../evidence/effects_projectiles/history/initial/review.txt) reproduced all four PNGs.

Focused raw results: [Debug](../../evidence/effects_projectiles/history/initial/focused-debug.txt),
[ReleaseSafe](../../evidence/effects_projectiles/history/initial/focused-release-safe.txt), and
[ReleaseFast](../../evidence/effects_projectiles/history/initial/focused-release-fast.txt).
No unresolved automated validation failure remains. Keyboard interactions are
implemented and their scene operations have headless tests; manual input and
owner visual/API acceptance remain review work, not an automated acceptance claim.

## Corrective validation and evidence

All required correction gates returned exit code zero. The 49 focused tests
include the original 41 tests plus six deflection tests and two
ownership-proof tests. Allocator failure-site cleanup, leak checks, bounded
storage, zero steady-state allocation, presentation independence and original
ID/RNG goldens remain enabled. Counts below are reported test executions, not
a deduplicated count across suites.

| Exact command from this worktree | Exit | Observed result |
|---|---|---|
| `.\.deps\zig-0.16.0\zig.exe build verify -j1 --summary all` | 0 | 92/92 steps succeeded; 712 reported tests (before edits) |
| `.\.deps\zig-0.16.0\zig.exe build test-effects-projectiles -j1 --summary all` | 0 | 3/3 steps succeeded; 49 reported tests |
| `.\.deps\zig-0.16.0\zig.exe fmt build/apps.zig build/gates.zig build/modules.zig build/tests_engine.zig src/projectiles src/effects src/app/effects_projectiles.zig src/app/effects_projectiles_scene.zig src/app/effects_projectiles_view.zig tests/effects` | 0 | no output |
| `.\.deps\zig-0.16.0\zig.exe build -j1 --summary all` | 0 | 24/24 steps succeeded |
| `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseSafe -j1 --summary all` | 0 | 24/24 steps succeeded |
| `.\.deps\zig-0.16.0\zig.exe build test-effects-projectiles -Doptimize=ReleaseSafe -j1 --summary all` | 0 | 3/3 steps succeeded; 49 reported tests |
| `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseFast -j1 --summary all` | 0 | 24/24 steps succeeded |
| `.\.deps\zig-0.16.0\zig.exe build test-effects-projectiles -Doptimize=ReleaseFast -j1 --summary all` | 0 | 3/3 steps succeeded; 49 reported tests |
| `.\.deps\zig-0.16.0\zig.exe build verify -j1 --summary all` | 0 | 92/92 steps succeeded; 720 reported tests |
| `.\.deps\zig-0.16.0\zig.exe build test check -j1 --summary all` | 0 | 28/28 steps succeeded; 433 reported tests |
| `.\.deps\zig-0.16.0\zig.exe build gpu-smoke -j1 --summary all` | 0 | 26/26 steps succeeded |
| `.\.deps\zig-0.16.0\zig.exe build effects-projectiles-smoke -j1 --summary all` | 0 | 26/26 steps succeeded |
| `python tools/effects_projectiles_review.py --compare evidence/effects_projectiles` | 0 | EFFECTS_PROJECTILES_REVIEW_OK frames=4 lossless_rgb=true |
| `python tools/effects_projectiles_review.py --output evidence/effects_projectiles` | 0 | EFFECTS_PROJECTILES_REVIEW_OK frames=4 lossless_rgb=true |

Exact durations, command records, tested source SHA256 values, preservation
results and generated capture hashes are recorded in
[current validation.json](../../evidence/effects_projectiles/validation.json).
Complete current outputs: [verify](../../evidence/effects_projectiles/verify.txt),
[test/check](../../evidence/effects_projectiles/check.txt),
[GPU smoke](../../evidence/effects_projectiles/gpu-smoke.txt),
[proof](../../evidence/effects_projectiles/proof.txt),
[repeat comparison](../../evidence/effects_projectiles/review.txt),
[Debug tests](../../evidence/effects_projectiles/focused-debug.txt),
[ReleaseSafe tests](../../evidence/effects_projectiles/focused-release-safe.txt),
[ReleaseFast tests](../../evidence/effects_projectiles/focused-release-fast.txt).
The [pre-correction preflight](../../evidence/effects_projectiles/history/precorrection/preflight.json)
and [pre-change verify output](../../evidence/effects_projectiles/history/precorrection/verify.txt)
record the clean old HEAD before any rename or code edit.

The corrected physical proof reported:

```text
info: EFFECTS_PROJECTILES_DEFLECTION transfers=1 former_source_hits=1 new_source_hits=0
info: EFFECTS_PROJECTILES_PROOF frames=180 ticks=720 collisions=4 deflections=2 expirations=3 peak_projectiles=5 peak_emitters=213 peak_particles=352 trail_samples=544 peak_sprites=363 peak_draws=1 dropped_particles=0 dropped_effects=0 steady_allocations=0 simulation_ns=296474600 wall_ns=1468805200
info: EFFECTS_PROJECTILES_PROOF_OK backend=direct3d12 created=23 released=23 fences_acquired=185 fences_released=185
```

The fifth ownership lane adds one projectile, a source-to-source transfer,
one former-source collision and its composed trail/bursts. That is the semantic
reason for changed pixels and higher peak counts. The old four-lane assertions
and core identity/random-stream golden vectors are unchanged. Marker and cache
path changes affect labels only. No expected result or generated hash was edited.
The supported proof/review tool regenerated every current PNG, and a second
physical proof reproduced all four RGBA hashes and all four PNG byte streams.

| Tick | Changed pixels | GPU RGBA SHA256 | PNG SHA256 |
|---|---|---|---|
| 120 | 5267 | `ada3e299a3da0e955fa16bacda33c2fa7d127e2302a61a18a3b4fcd3a1218972` | `b9af80be26d949992d190f7c478a98a2cf46a87bc5bdcce49e336abbbf4c9204` |
| 176 | 5082 | `6ad9f0a7dacabdaa47aee4c87716e2121dcbc274fe157ced25f1e1db533057bf` | `966d73e194fb561fe5303c36101dd38ef673e42eff6f9d24d6c628d8a9d0ae25` |
| 212 | 4998 | `e72a45be951d569424a0ba2beda90f71d0b1df5eead0d0f9ae298158117a4596` | `cae09a628fa343f9a12da48144c4f372d1aea4d3339454138a388f37269a35ed` |
| 256 | 4731 | `8f46b9a6ce9c75f0c0e6a72b5be6073e6700dc5fc985d4054b1af69dfa6fc797` | `b73325500eca2e97ff784cb1b259ce4e7b84e36140c5b2332b117cac95d0f090` |

Current simulation/wall timing is a local Debug observation, not a benchmark
guarantee. The proof has one instanced sprite draw, zero measured steady-state
Zig allocations, no particle/effect drops and balanced GPU resources/fences.
SDL/driver internal allocation is outside the counters. Repeat pixel evidence
is scoped to this reference machine and driver. The actual tick-176 and tick-256
PNGs were inspected: the bottom lane returns toward blue A and then impacts it.
This inspection does not grant owner visual acceptance.

The first new focused compile exceeded the default Zig compile-time branch
quota for two fixed proof UUIDv5 inputs. A local finite SHA-1 evaluation quota
resolved both diagnostics; no runtime path, test assertion or golden was weakened.
All subsequent focused/configuration/aggregate runs passed. A duplicated phrase
in the build-step description was corrected during review; later test/check
and GPU build routes parsed the corrected registration. No unrelated baseline
regression was repaired during this pass.

### Corrective preservation and scope audit

Read-only SHA256 checks found all 931 original-master tracked files unchanged
from the preflight inventory. All 927 accepted baseline files outside the four
feature wiring surfaces also remain byte-identical in this isolated checkout.
All 13 original evidence files match the old committed blobs byte-for-byte at
their archival destinations. The composition implementation and original
projectile/effect/composition test files are unchanged. The effect implementation
is byte-identical after removing its three new documentation lines.

All 15 feature Zig/Python files, plus the four build registration files, were
audited: zero TODO, FIXME, unreachable, stub/placeholder, skipped-test or active
preliminary E1-name matches. Full source review found no unfinished bodies,
unconditional-success substitutes or disabled tests. The old names survive only
as explicit history and legitimate editor-roadmap context, including the retained
physical worktree path. No canonical-human, HM08, Model Lab, animation, wardrobe,
environment, foundation, scene-core, graphics, shaders or shared physics file
was modified. The original master remains clean at the accepted baseline.

### Corrective file inventory and commit packaging

Renamed with git mv (no evidence content removed):

- `docs/implementation/e1_effects_projectiles.md` to `docs/implementation/effects_projectiles_foundation.md`.
- Each `evidence/e1/` file to the same basename under `evidence/effects_projectiles/history/initial/`:
  - `check.txt`.
  - `focused-debug.txt`.
  - `focused-release-fast.txt`.
  - `focused-release-safe.txt`.
  - `gpu-smoke.txt`.
  - `proof.txt`.
  - `review.txt`.
  - `tick_120.png`.
  - `tick_176.png`.
  - `tick_212.png`.
  - `tick_256.png`.
  - `validation.json`.
  - `verify.txt`.

Created by this corrective pass:

- `tests/effects/deflection_tests.zig`.
- `evidence/effects_projectiles/build-debug.txt`.
- `evidence/effects_projectiles/build-release-fast.txt`.
- `evidence/effects_projectiles/build-release-safe.txt`.
- `evidence/effects_projectiles/check.txt`.
- `evidence/effects_projectiles/focused-debug.txt`.
- `evidence/effects_projectiles/focused-release-fast.txt`.
- `evidence/effects_projectiles/focused-release-safe.txt`.
- `evidence/effects_projectiles/format.txt`.
- `evidence/effects_projectiles/gpu-smoke.txt`.
- `evidence/effects_projectiles/history/precorrection/preflight.json`.
- `evidence/effects_projectiles/history/precorrection/verification.json`.
- `evidence/effects_projectiles/history/precorrection/verify.txt`.
- `evidence/effects_projectiles/proof-first.txt`.
- `evidence/effects_projectiles/proof.txt`.
- `evidence/effects_projectiles/review-generation.txt`.
- `evidence/effects_projectiles/review.txt`.
- `evidence/effects_projectiles/tick_120.png`.
- `evidence/effects_projectiles/tick_176.png`.
- `evidence/effects_projectiles/tick_212.png`.
- `evidence/effects_projectiles/tick_256.png`.
- `evidence/effects_projectiles/validation.json`.
- `evidence/effects_projectiles/verify.txt`.

Modified (in addition to the renamed implementation report):

- `src/projectiles/root.zig`.
- `src/projectiles/collision_query.zig`.
- `src/effects/root.zig`.
- `src/app/effects_projectiles.zig`.
- `src/app/effects_projectiles_scene.zig`.
- `src/app/effects_projectiles_view.zig`.
- `tests/effects/root.zig`.
- `tests/effects/proof_tests.zig`.
- `tests/effects/support.zig`.
- `tools/effects_projectiles_review.py`.
- `build/apps.zig`.
- `build/gates.zig`.
- `build/modules.zig`.
- `build/tests_engine.zig`.

Removed content: none. Old paths retire through the traceable renames above;
the original commits, messages and evidence remain intact.

The four shared build files change only descriptive names/registration references.
They remain potential merge-conflict surfaces, especially build/modules.zig;
their corrective changes are packaged as a separate wiring commit after the
domain/report/evidence correction. Apply both corrective commits together on top
of the unchanged original two commits. No merge, push, reset, clean, rebase,
amend, squash, branch/worktree deletion or destructive operation was performed.

Owner review remains for source/affiliation/filter API semantics and timing,
visual/manual controls, bounded response/overflow policies, and the deferred PHY
adapter synchronization. No future roadmap phase or deferred gameplay system
is marked complete. The final commit identifiers and clean branch status are
reported in the delivery response; the branch stops at owner review.
