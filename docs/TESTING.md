# Testing Strategy

## Current verification workflow

This section is the current repository-wide command contract. Historical
milestone counts, aggregate membership statements, and commands later in this
document remain evidence for the state that existed when those milestones
were accepted; they do not override this workflow.

Routine CPU verification remains windowless and GPU-independent. Use the
pinned Zig 0.16.0 executable and `-j1` on the Windows reference workflow:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build check -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-full -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-content -j1
& '.\.deps\zig-0.16.0\zig.exe' build verify -j1
& '.\.deps\zig-0.16.0\zig.exe' build gpu-smoke -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-engine-composition -j1
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-smoke -j1
```

| Gate | Primary command | Contents | Explicit exclusions / required use |
| --- | --- | --- | --- |
| Fast engine contract/static | `zig build check -j1` | Sandbox and independent application compilation, formatting, current architecture and hygiene policy, documentation validation, and fast engine/F/scene/input/renderer-boundary CPU contracts including the independent composition test | No physical GPU, canonical/content qualification, manual review, or historical evidence generation. Run for ordinary engine work and every review request. |
| Full deterministic CPU integration | `zig build test-full -j1` | `check`, broader deterministic integration, production-route suites, environment/wardrobe/foundation composition, and the existing long-duration stress tests | No physical GPU, manual review, or canonical/historical evidence generation. Run for substantial engine or cross-system changes. |
| Current canonical/content qualification | `zig build test-content -j1` | Canonical model/human/geometry, current authored art/visual/anatomy qualification, current content audits, approved goldens, exporter compilation, and the retained full content-policy audit | Required for canonical/content-authority changes; not required for unrelated engine iteration. |
| Physical GPU validation | `zig build gpu-smoke -j1` | Real D3D12/DXIL device, shader, draw, readback, fault, and cleanup proof through the independent `engine_smoke` client | Requires suitable Windows GPU access and remains separate from CPU-only gates; it does not enter `DemoApplication`. |
| Manual/visual acceptance | `zig build visual-acceptance -j1` | Builds the application and current report executables used by the documented capture/review routes | Does not claim human approval and is never an automatic dependency of `check`. |
| Historical evidence reproduction | `zig build evidence-history -j1` | Explicit, potentially mutating historical exporters, Blender bridge checks, and Prompt-era review packages | On demand only. Use `zig build evidence-history-check -j1` for a non-mutating registration check. |
| CPU verification aggregate | `zig build verify -j1` | `check` + `test-full` + `test-content`, with shared nodes executed once | No physical GPU, manual acceptance, or historical reproduction. |

`zig build test -j1` remains a compatibility and focused-development alias for
the fast CPU contract suite used by `check`. `zig build test-stress -j1`
remains callable and is now also included by `test-full`; the stress tests were
not weakened or deleted.

All engine and content test roots use the simple runner bundled with the pinned
Zig 0.16.0 toolchain. This runs the same declarations and reports failure by
process exit code, while avoiding the server-listener timeouts observed on the
Windows reference machine during long aggregate gates. Gate membership,
assertions, filtering, and focused target names are unchanged.


### PSM01 generic secondary-motion proof

Run zig build test-psm01 -j1 for 40 headless tests: the original 23 solver,
driver timing, lifecycle, energy and replay proofs plus 17 authored rate-policy,
validation, calibration, explicit-duration and offline/runtime trace tests.
Repeat the focused gate with -Doptimize=ReleaseSafe and -Doptimize=ReleaseFast.
The root imports only secondary_motion, secondary_motion_rate, fixed_step and
spring. It is included in test, check, test-full and verify. Existing animation
and attachment regressions remain in test-deterministic.
The [PSM01 contract and measured evidence](implementation/psm01_secondary_motion.md)
documents 240 Hz outer ticks, two internal spring integration stages, identity
and authored rate policies, tolerances and unchanged legacy samples.
The owner accepted the generic solver/resolver, fixed-step and determinism
contracts, synthetic calibration and offline/runtime proof at
43ae062867d8bda79b1ba364ad6e934c0beee8c7. Final anatomical tuning and production
bindings remain outside acceptance. Offline proof uses ordered fixed arrays
and the same production solver; no renderer, animation object or batch exporter.

### Effects and Projectiles Foundation

`zig build test-effects-projectiles -j1` runs 54 headless projectile, deflection,
particle, composition and standalone-proof tests. It is included exactly once
in the fast engine aggregate, and therefore in `test`, `check`, `test-full`
and `verify`. Run the focused target in Debug, ReleaseSafe and ReleaseFast.
The combined focused invocation with `test-record-replay`, `test-psm01`,
`test-world` and `test-engine-lab` passed 15/15 steps and 181 tests per mode
for the accepted integration.

`zig build effects-projectiles -j1` builds the standalone application;
`zig build run-effects-projectiles -j1` runs it. The separate physical route
`zig build effects-projectiles-smoke -j1` exercises the existing SDL3 GPU
D3D12 renderer and four captures. Compare them with the accepted evidence using
`python tools/effects_projectiles_review.py --compare evidence/effects_projectiles`.
These routes do not integrate effects/projectiles into PHY, Engine Lab, RR1,
world/environment, 3D presentation or gameplay-specific clients. Both cores
and the standalone visual proof are currently 2D.

The [owner acceptance and measured aggregate counts](implementation/effects_projectiles_foundation.md)
record the integration commit and exact validation boundary. The integration-time
[Windows working-byte defect](project/KNOWN_GAPS.md#windows-working-byte-reproducibility)
required a local workaround at that time. The later unnumbered repository
correction resolves it with committed attributes, exact byte preservation and
fresh-worktree proof. Historical integration evidence and expectations are
unchanged; current validation needs no old-worktree copying.

### Checkout integrity and parallel-lane status

Root `.gitattributes` makes source/current canonical text LF, preserves immutable
captures with scoped `-text`, and keeps images/archive bytes binary.
`python tools/checks/checkout_bytes.py` checks both raw index and checkout bytes
and required attributes. It runs through `tools/check_repository.ps1`, so normal
`check`, `test-full` and `verify` include it. `--index-only` is a staged-review
option, not acceptance evidence and not used by any aggregate gate.

The check consumes existing document/capture hash authorities and the ten
prospective owner-established authorities in `assets/history/manifest.json`.
It never needs an old worktree or network access. Git and Python must be
available to repository gates. A pre-policy checkout is not rematerialized by
editing attributes; use a new worktree for reproducibility validation. Existing
pinned dependencies may be shared through an ignored `.deps` junction; use a
fresh task-local Zig cache. Do not apply local conversion-configuration overrides
or copy tracked files to make a proof checkout pass. See the
[correction report](implementation/reproducible_windows_checkouts.md).

PSM01, World Time, Engine Lab EL1, RR1 and Effects/Projectiles are all accepted
on master within their individual scopes. Their focused gates remain separate
and registered once in the fast aggregate. Run the five together in Debug,
ReleaseSafe and ReleaseFast for a repository-integrity acceptance boundary.
Sharing a gate or master does not integrate their state or ownership.

### Change-based gate guidance

| Change | Required aggregate gates | Add focused routes |
| --- | --- | --- |
| Foundation or `scene_core` | `check`, `test-full` | `test-foundation-primitives`, `test-scene-core-authored`, or `test-scene-core-runtime` as applicable; the internal registry root remains in the fast aggregate |
| Animation, physics, interaction, or character runtime | `check`, `test-full` | The relevant domain target; include `test-stress` when lifecycle or long-duration behavior changes |
| Canonical human/model/geometry or current art/content | `check`, `test-content` | The relevant canonical/content target; add `visual-acceptance` when owner visual review is required |
| Renderer/backend/shaders | `check`, `test-full`, `gpu-smoke` | `test-renderer-boundary` and other affected focused CPU targets |
| Documentation only | `check` | `tools/check_documentation.ps1` may be run directly for rapid feedback |
| Historical evidence tooling | `check`, `evidence-history-check` | Run only the affected mutating historical route when regeneration is intended |
| Application composition or public engine-client surface | `check`, `test-full` | `test-engine-composition`; add `run-engine-smoke` when renderer/platform composition changes |

### Build/test registration ownership

Production module creation belongs in `build/modules.zig`; application
executable/run registration belongs in `build/apps.zig`. Fast engine and
full-CPU test roots belong in `build/tests_engine.zig`; canonical/content
tests belong in `build/tests_content.zig`; report executables and historical
reproduction belong in `build/evidence.zig`; top-level aggregate semantics
belong in `build/gates.zig`. Root `build.zig` composes these domains and owns
target/platform, pinned dependencies, shaders, installed runtime assets, and
the major dependency DAG. `build/apps.zig` owns the four application artifacts
(`engine_sandbox`, `engine_smoke`, `engine_lab`, and `effects_projectiles`),
their run routes, and GPU smoke. Registration is
explicit; directory scanning is prohibited.

A future SEM or OBJ module/test normally changes its production/domain source
and the matching module/test helper. A new LVL tool belongs with the relevant
tool/content helper. A new editor executable should receive an explicit
application/tool helper registration. Root changes only when introducing a
new major domain or top-level aggregate, and ordinary additions do not require
new checks in `tools/check_repository.ps1` or new prose here unless policy or
gate semantics actually change.

### World-time foundation

`zig build test-world -j1` runs 21 headless declarations (20 behavioral tests
and their import root) from `tests/world/test_world.zig`. The test root imports
only the production `world` module, whose implementation uses `std` and local
leaves. There is no SDL linkage, wall-clock access, network, sleep, application,
physics, or animation dependency. The target is included in `test`, `check`,
`test-full`, and `verify` through the fast engine aggregate.

Coverage includes exact rational tick accumulation, fractional carry, partition
independence, zero progression and numeric zero rate, arbitrary day cycles,
rollover, exhaustion with atomic failure, copied continuation snapshots,
independent clocks, rate versus cycle semantics, and a complete headless
progression-to-day/time-snapshot vertical slice. Boundary arithmetic is also
exercised with `test-world -Doptimize=ReleaseSafe` and
`test-world -Doptimize=ReleaseFast`. Only approximate float convenience views
use a rounding tolerance; authoritative time comparisons are exact integers.

For world-time changes, run the focused target in all three modes, `check`,
`test-full`, and the normal `build` gate. The static architecture audit allows
only downward engine dependencies to foundation and excludes clock,
application, and backend access; no unused foundation edge is required.
Read the [world-time implementation report](implementation/world_time_foundation.md)
for units, continuation behavior, validation evidence, and owner-review decisions.

### Bounded Engine Lab collectible replay

`zig build test-engine-lab-replay -j1` runs the application replay contracts through
the focused runner and is included in `test`, `check` and `test-full`. Coverage
includes the real 1,469-tick record/encode/decode/fresh playback, twelve contributors,
ten names, exact 88,079-byte output, invocation groups, lifecycle, semantic tampering,
terminal failures, allocation cleanup and the 1,024-byte decoder-envelope bound.
`test-deterministic` includes the two generic copied animation snapshot tests.
Use Debug, ReleaseSafe and ReleaseFast for the affected acceptance matrix.

For file reproduction, run the same focused target with
`-Dengine-lab-replay-test-filter="write recording"` and
`-Dengine-lab-replay-output=<new-path.rr1>`, then with
`-Dengine-lab-replay-test-filter="play recording"` and
`-Dengine-lab-replay-input=<path.rr1>`. Playback with an input path consumes that file;
it never substitutes generated commands. See exact PowerShell examples and evidence
classification in the [implementation record](implementation/engine_lab_collectible_replay.md).
No new GPU capture or owner visual test is required by this headless scope.

### RR1 deterministic record/replay

`zig build test-record-replay -j1` exercises the CPU-only corrected V1 contract:
independent byte/hash/key goldens, dense intervals, ordered causal/observed
streams, named-marker grammar/order/uniqueness, corruption/compatibility
failures, combined divergence diagnostics, state coverage and bounded lifetime.

The real production proof records and verifies 480 ticks, every observed
event, every post-tick fingerprint, three named checkpoints and exact final
controller state. Direct tick batches 1/7/1 produce byte-identical artifacts;
playback invocation batches 1/7/23 produce identical state and marker counts.
These tests make no arbitrary frame-schedule claim. A separate test gives
unrelated live input and a clock which discards time to an outside caller,
while playback itself consumes only recorded tick data.

An allocator guard covers causal injection, multiple observations, fingerprints,
names and combined divergence without allocation/resize/remap attempts.
Focused tests remain in `test`, `check`, `test-full` and `verify` through the
unchanged modular build registration. Correction acceptance additionally runs
focused ReleaseSafe/ReleaseFast tests and default builds in both release modes.
No physical GPU gate is required. See the
[V1 contract](architecture/deterministic_record_replay_v1.md) and
[implementation evidence](implementation/rr1_record_replay.md).

### Independent engine composition proof

`zig build engine-smoke -j1` builds the permanent small second application.
`zig build run-engine-smoke -j1` runs its physical proof through the installed
SDL3/D3D12/DXIL layout. It creates and promotes one F entity, observes and
mutates it through supported RuntimeScene APIs, converts the read view to a
production sprite request, renders six frames, performs generic pixel
readback, checks steady-state resource/allocation behavior, and verifies
balanced renderer shutdown.

`zig build test-engine-composition -j1` is CPU-only and part of `check`. Its
three tests prove generic RuntimeScene/render-data composition, two-character
F binding and transform/enabled synchronization, and a complete production
handshake lifecycle without importing a demo scenario. The physical target is
deliberately separate from `check`.


## Historical M01.5 verification workflow

This section preserves the pre-F4C5 aggregate contract and milestone-time
counts. It is retained as implementation history and does not override the
F4C5 workflow above.

All routine CPU verification remains windowless and GPU-independent. Use the
pinned Zig 0.16.0 executable and `-j1` on the Windows reference workflow:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test -j1
& '.\.deps\zig-0.16.0\zig.exe' build check -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-full -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-stress -j1
& '.\.deps\zig-0.16.0\zig.exe' build verify -j1
```

| Tier | Primary command | Purpose | Required use |
| --- | --- | --- | --- |
| Fast development | `zig build test -j1` | Pure/deterministic CPU behavior, the 27 F2A primitive declarations, the 39 F2B authored-scene declarations, the 25 F2C runtime-scene declarations, cheap format-independent asset checks, visual registration, all 50 M01 canonical-model declarations, and all 53 M02 canonical-human declarations | During normal implementation and before handing a local change to another engineer |
| Fast repository gate | `zig build check -j1` | Fast development tier plus formatting and every static repository, art, golden, and policy audit | Before every review request; this remains the required non-GPU static gate |
| Full regression | `zig build test-full -j1` | Fast tier plus the bounded production-route integration, foundation, wardrobe, visual-geometry, environment, and visual-foundation suites | Before milestone acceptance, after cross-system changes, and when a focused suite affects an adjacent subsystem |
| Stress/exhaustive | `zig build test-stress -j1` | The unchanged 1,000-handshake lifecycle audit and 100,000-integrated-tick stability/resource audit | Before milestone acceptance and after interaction, IK, foot-planting, reset, allocation, or long-duration simulation changes |
| Complete CPU verification | `zig build verify -j1` | `check` + `test-full` + `test-stress`, with shared build nodes executed once | Final pre-owner-review gate for M02 through M08 and repository-wide verification changes |

### Current M02.5 canonical-human routes

The current canonical-model inventory is 50 M01 test declarations and 53 M02
test declarations. The M02 declarations are split across five file-backed
focused routes. Each later route depends on the earlier routes, so the final
route exercises the complete M02 chain:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-identity -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-rig -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-joint-controls -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-structural -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-base -j1
```

Tests of the accepted human asset load
`assets/canonical_model/human_base/human_base.authoring.json` through the
canonical file-backed loader. Small synthetic records remain appropriate for
generic schema/validator unit tests.

`test` schedules all M01 and M02 roots directly. `check` depends on `test` and
adds formatting plus static repository, art, and golden audits. `test-full`
depends on `test` and adds bounded integration/production-route suites.
`test-stress` contains the two long-duration audits and does not duplicate the
M01/M02 declarations. `verify` is the union of `check`, `test-full`, and
`test-stress`, with shared build nodes executed once.

`zig build update-human-base-evidence` is an explicit authoring/update command.
It reads the authoritative authoring JSON and may regenerate only the reviewed
derived canonical JSON and structural report. Ordinary `test`, `check`,
`test-full`, `test-stress`, and `verify` routes never invoke it to repair a
golden mismatch.

### F2A shared-foundation primitive route

The accepted F1 contract has one renderer-independent, CPU-only F2A route:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-foundation-primitives -j1
```

Its 27 declarations cover strong RFC 9562 UUID identity kinds, explicit
UUIDv5/v7 inputs and fixed identity vectors, semantic-version kinds, exact
asset references and fixed direct/transitive dependency hashes, the
non-persistent `EntityHandle` value, 3D TRS/affine composition, canonical
negative-X reflection and decomposition tolerances, canonical JSON/hash
primitives and a fixed domain-hash vector, protected canonical-model and
canonical-geometry byte/hash conformance, fixed seed/key derivation vectors,
normalized rational scene time including negative time, and stable
diagnostic ordering. Test-only imports compare the new faÃƒÂ§ade with the
protected H canonical pipelines and the current 2D transform route; production
foundation code does not import or replace those systems.

The focused route is a dependency of `test`, so it is also exercised by
`check` and `test-full`. F2A acceptance uses this bounded order:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-foundation-primitives -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build test-full -j1 --summary all
```

This route does not test slot reuse, generation increment, stale-handle
registries, scene compilation, world/level/prefab schemas, extension framing,
or runtime publication. Those remain F2C or F2B responsibilities under the
F1 Revision 2 gate table.

### F2B authored scene-definition route

The CPU-only F2B schema, migration, canonical-data, and validation gate is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-scene-core-authored -j1
```

Its 39 declarations cover authored prefab/entity/level/world separation,
stable prefab child identity, exact world origins and local transforms,
neutral camera geometry, typed presentation/volume/layer boundaries, tag and
activation rules, exact synthetic catalogs, deterministic hierarchy and
lifecycle order, reusable street-lamp composition, multiple level references,
strict cross-level parenting, extension namespace/registration/dependency
reporting/limits, unknown-required versus optional-preserve behavior, canonical
round trips under reordered collections, explicit and omitted defaults,
file-backed `0.9.0 -> 1.0.0` migration, explicit major/minor/patch rejection,
schema-family UUID permanence, unknown/duplicate/unsupported-field rejection,
and fixed minimal plus representative canonical bytes/domain hashes.

The route is a direct dependency of `test`, so `check` and `test-full` include
it. F2B acceptance uses this bounded order:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-scene-core-authored -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build test-foundation-primitives -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build test-full -j1 --summary all
```

The focused route does not construct a RuntimeScene, allocate or recycle
handles, mutate hierarchies, unload levels, publish snapshots, compile
downstream component tables, or exercise renderer/physics/editor integration.
Those remain F2C and separately authorized track responsibilities.

### F2C runtime scene route

The CPU-only registry, assembly, hierarchy, lifecycle, publication, snapshot,
and consumer-boundary gate is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-scene-core-runtime -j1
```

Its 25 declarations cover generation-checked slot reuse and retirement,
persistent-ID lookup, bounded capacity growth, deterministic runtime hierarchy,
explicit reparent/removal policies, affine transform caching and dirty
propagation, exact Level origins, multi-Level unload, world-persistent anchors,
host-scoped temporary authority, fail-closed gameplay promotion origin policy,
dedicated promotion diagnostics, successful world-affine preservation, nested prefab
expansion and overrides, exact
asset resolution, owned F2B slice lifetime, extension preservation, atomic
two-phase publication, immutable bounded snapshots, stable diagnostics, and
test-only R/P/gameplay/C consumers of one shared scene view.

The route is a direct dependency of `test`, so `check` and `test-full` include
it. F2C acceptance uses this bounded order:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-scene-core-runtime -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build test-scene-core-authored -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build test-foundation-primitives -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all
& '.\.deps\zig-0.16.0\zig.exe' build test-full -j1 --summary all
```

This route uses synthetic definitions, a neutral mock asset resolver, and
test-only downstream consumers. It does not initialize SDL, create a GPU
device, import production R/P/gameplay/C implementations, migrate existing
runtime routes, serialize a RuntimeScene, or exercise future W streaming,
procedural generation, save games, or floating-origin work.

### M03 Prompt 2A canonical-geometry route

The renderer-independent generic geometry foundation has one focused fast
route:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-geometry -j1
```

It covers strict file loading, M02 normalized-source compatibility, stable
mesh/vertex/face identities and allocation cursors, quad semantics, canonical
surface coordinates, independent UVs and declared overlaps, seam/binding and
module-interface records, collision proxies, deterministic canonical JSON and
hash boundaries, explicit triangulation, Catmull-Clark v1 level one, and the
file-backed generic invalid-case matrix. The fixture geometry is synthetic;
this route does not imply that production human geometry exists. The same test
root is scheduled by `test`, and therefore by `check`, `test-full`, and
`verify`.

### M03 Prompt 2B human scaffold routes

The first file-backed production human geometry has a focused fast route:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-geometry-scaffold -j1
```

It loads both authoritative M02 and M03 sources, then validates the continuous
main-body identity, stable topology, closed connectedness, height/ground,
bilateral symmetry, broad semantic coverage, all 11 M02 seam loops, all 35
landmark bindings, the anus receiver closure interface, deterministic hashes,
triangulation, Catmull-Clark level one, and committed evidence inventory. The
target depends on the Prompt 2A generic route and is scheduled by `test`. Its
evidence assertions remain pinned to the accepted Prompt 2B historical package
while its structural assertions ensure the current geometry still preserves
the approved scaffold contracts.

### M03 Prompt 2C/R1 historical-evidence route

The superseded Prompt 2C/R1 packages retain a focused historical-evidence route:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-geometry-refinement -j1
```

It validates the frozen topology-revision-3 report, explicit Prompt 2C-to-R1
face-ID delta, and committed high-resolution R1 report/visual inventory. It no
longer treats R1 as current authority. The route depends on Prompt 2B/2A and is
scheduled by `test`.

### M03 Prompt 2C-T3/R3/R4 HM08 topology and neutral-adaptation routes

The current topology-v2 authority retains its adoption/provenance route:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-geometry-adoption -j1
```

It validates topology compatibility 2.0.0/revision 4, fresh scoped IDs and
cursors, the current five identities, 13,380 vertices/13,378 quads, closed
connected symmetry and current R4 quality baseline, semantic classification of all 416
M02 region/surface records, all 11 seam bindings, all 35 landmark bindings,
43 deformation zones, provisional imported UV separation, minimal anus
receiver metadata, pinned provenance, five-run determinism, and Blender
round-trip evidence. It depends on the generic/scaffold/historical routes and
is scheduled by `test`.

R3 shape adaptation, landmark semantics, topology preservation, persistent
visual evidence, and explicit bridge edit authorization have a focused route:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-geometry-r3 -j1
```

It verifies that the neutral adaptation changes geometry without changing
control topology or triangulation, keeps topology-v2 IDs/cursors and all
integrity invariants, classifies all 35 bindings into surface or internal
semantics, enforces the surface-correspondence registration targets, checks
the six carried receiver-retopology dispositions, and inventories 43
high-resolution images, three mobile sheets, and nine T3-vs-R3 comparisons.
It is scheduled by `test`; ordinary tests never launch Blender or rewrite
canonical authority/evidence.

R4 final shared-human neutrality, unchanged topology identities, measurement
deltas, 18/17 landmark semantics, outlier lineage, and owner-review evidence
have a focused route:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-geometry-r4 -j1
```

It depends on the R3/T3/historical/generic chain and is scheduled by `test`.
It verifies the current five identities, exact topology preservation, locked
height/ground, bilateral symmetry, zero topology-integrity defects, zero new
above-8 aspect outliers, the persistent Blender self-intersection result, and
all three R4 mobile sheets plus R3-vs-R4 comparisons.

The non-adjacent derived-triangle self-intersection audit is isolated in:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-canonical-human-geometry-full -j1
```

It is scheduled by `test-full`, not duplicated in the fast tier. The audit
uses canonical f32 positions with f64 separating-axis calculations and a
documented validation-only epsilon. It depends on the current R4 route.

Prompt 2B and original Prompt 2C evidence are frozen historical evidence.
Derived Prompt 2C-R1 OBJ, report, high-resolution PPM, downsampled PNG, and
owner contact-sheet updates are explicit:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build update-human-geometry-r1-evidence -j1
```

Ordinary test/check/full/verify routes compare committed evidence; they never
invoke the update step or rewrite geometry or evidence.

### M03 Prompt 2C-T1 Blender bridge route

The pinned offline Blender bridge has a specialized authoring/tooling gate:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-blender-bridge -j1
```

This route verifies Blender 4.5.9 LTS and its locked portable-archive hash,
canonical/Blender coordinate conversion, handedness and f32 round trips,
source/sidecar/working-file binding, stable-ID preservation, fail-closed
missing/duplicate/unallocated/retired-ID behavior, explicit semantic metadata,
allocation cursors, seam/binding preservation, and the exact current
topology-v2 normalized, topology, triangulation, and neutral identities after a
no-op round trip. It
also runs a malformed candidate through the normal canonical geometry loader
and requires rejection.

The bridge gate is intentionally specialized: normal runtime builds and the
ordinary canonical parser/validation routes do not require Blender. Prompt
2C-T1 runs this gate explicitly in addition to `test`, `check`, and
`test-full`. Candidate validation without Blender is available through:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build validate-human-geometry-candidate -j1 -- .authoring-work/human_base_geometry.candidate.json .authoring-work/human_base_geometry.candidate.validation.txt
```

Full command and promotion policy is documented in
`docs/implementation/3d_pipeline_m03_blender_bridge.md`.

### M03 Prompt 2C-T2 hm08 qualification route

The read-only external topology-seed qualification is reproduced with:

```powershell
& '.\tools\hm08_qualification.ps1'
```

The route verifies the pinned MPFB2 revision, exact `hm08` OBJ and CC0 license
hashes, visible-body/helper range separation, topology/manifold/symmetry and
self-intersection evidence, provisional M02 seams and all 35 landmark
relationships, then rebuilds the ignored Blender comparison scene and the
persistent high-resolution evidence package. `-SkipRender` retains all
text/scene qualification checks without regenerating PNGs. The route never
writes the canonical geometry authority or assigns canonical stable IDs to the
external mesh. It is an explicit authoring/qualification gate and is not part
of ordinary runtime, `test`, or `check` execution.

The qualification method and owner-facing result are documented in
`docs/implementation/3d_pipeline_m03_hm08_qualification.md`. T3 subsequently
adopted only the visible-body topology; this T2 command remains a provenance
and qualification reproducer and never rewrites current authority.

T3's derived visual package is frozen historical evidence and its renderer is
hash-bound to the historical T3 authority. It must not be regenerated from the
current R3 authority. R3 review evidence is explicitly regenerated from the
current source with:

```powershell
& '.\tools\render_human_geometry_r3_evidence.ps1'
& '.\tools\compose_human_geometry_r3_review.ps1'
```

These source-driven evidence commands are not scheduled by ordinary
test/check/full/verify and refuse an unexpected authority hash.

The 2026-08-08 M01.5 measurements use isolated task-local caches and report
wall time, so compiler cache state and the known Windows test-runner IPC
variability can move the outer time without changing test work. The measured
fast tier passed 340/340 in 63.4 seconds, `check` passed 22/22 steps and
340/340 tests in 68.9 seconds, full regression passed 450/450 in 172.2
seconds, stress passed 2/2 in 237.6 seconds, and complete `verify` passed
39/39 steps and 452/452 unique tests in 274.4 seconds. These are planning
ranges, not pass/fail timeouts. A slow run is investigated; tests are never
weakened or skipped to meet a time target.

### M01.5 before-state findings

Before this split, both `test` and `check` executed the same 11 test binaries:
the 323-test deterministic aggregate, image decode, wardrobe, visual
registration, visual geometry, environment, visual foundation, and all four
canonical-model suites. `check` additionally ran formatting plus five static
art/golden/repository audits. The shared dependency nodes were not executed
twice within one `check` invocation, but the ordinary `test` command still
carried the same expensive workload as `check` minus static audits.

The fresh before-state `check` passed 29/29 steps and 484/484 scheduled test
executions in 459.3 seconds. The deterministic aggregate reported about five
minutes, including an isolated 174.0-second 1,000-handshake audit and a
67.0-second 100,000-tick audit. The visual-foundation suite reported about one
minute; its two production-route proofs took approximately 37 and 25 seconds.
Wardrobe, visual geometry, and environment took approximately 9, 6, and 10
seconds. Static audits accounted for approximately 40 seconds of constituent
execution. Constituent times can overlap and therefore do not sum to wall
time.

Before-state standalone `test` attempts reached 440.1 to 454.8 seconds and
completed 470 to 477 reported tests before the known Windows test-runner IPC
non-response occurred. The identical test graph completed through `check`;
there was no assertion failure. M01.5 therefore uses the successful `check`
wall time as the clean aggregate baseline and retains the standalone behavior
as an infrastructure observation.

### Focused and specialized commands

Use the smallest relevant focused step while iterating, then run the required
primary tier before review. Existing milestone steps such as `test-camera`,
`test-art`, `test-presentation`, `test-component-graph`, `test-wardrobe`,
`test-visual-registration`, `test-visual-geometry`, `test-foundation`,
`test-environment`, `test-visual-foundation`, and the four
`test-canonical-model-*` steps remain supported specialized routes.

`zig build test-deterministic -Dtest-filter=<text> -j1` compiles and runs only
matching tests from the fast deterministic aggregate. Use the following for a
focused test in the visual-foundation suite:

```powershell
zig build test-visual-foundation -Dvisual-foundation-test-filter=<text> -j1
```

Filters are iteration aids only and never satisfy a primary tier by themselves.

The GPU-backed `gpu-smoke`, bounded executable evidence routes, real-D3D12
review packages, and manual visual acceptance remain specialized verification.
They are intentionally not hidden inside a CPU command that could report
success on a machine without the required graphical environment.

### Test placement rules

- Put short isolated behavior, validation, ownership, deterministic ordering,
  and regression cases in the fast aggregate.
- Put bounded end-to-end production routes, large asset/geometry matrices, and
  multi-subsystem acceptance simulations in full regression.
- Put repeated lifecycle, long-duration, high-load, permutation/exhaustive, and
  soak tests in stress when their cost would materially slow normal iteration.
- Keep GPU, review-package, report-generation, and narrowly scoped subsystem
  checks as specialized commands with explicit environment requirements.
- A test moves tiers because of its purpose and measured cost, never solely to
  make a failing or slow gate appear green. Its assertions and accepted bounds
  remain unchanged during a tier move.
- A new meaningful test must be reachable from `test`, `test-full`, or
  `test-stress`; `verify` must therefore reach it. A specialized-only test is
  allowed only when it requires hardware, external evidence, or an explicitly
  documented environment that the CPU verification graph cannot provide.

M01.5 removed no test behavior. The previous graph executed the 19 wardrobe
and 13 environment tests twice: once through `tests/test_all.zig` and once
through their focused roots. The current graph executes each once in
`test-full`. The two long stress tests moved intact from
`tests/integration_tests.zig` to `tests/stress_tests.zig`; the remaining nine
integration tests use their own full-regression root.

### M02-M08 retirement rule

Every M02 through M08 milestone that introduces a replacement production path,
test harness, fixture helper, compatibility adapter, or temporary scaffold must
perform a retirement review before its owner-review gate:

1. Inventory the old and replacement paths and every production, test, tool,
   build, and documentation call site.
2. Delete the old item in the same milestone when it has zero required call
   sites, the replacement carries equivalent or stronger coverage, and no
   accepted contract still requires it.
3. If deletion is unsafe, record why it remains, its current owner, the exact
   exit evidence required, and the latest milestone (no later than M08) that
   must decide its fate. Terms such as `transitional_legacy` are an explicit
   migration classification, not permanent authorization.
4. Do not keep an old path merely for hypothetical compatibility, and do not
   delete it merely because its name says legacy. Uncertain reachability or
   behavior stays in place and is reported for owner review.
5. Update build steps and documentation in the same change so retired tests or
   helpers cannot remain silently scheduled, orphaned, or described as current.
6. At the M08 closeout, every remaining transitional item must either be
   deleted or receive explicit owner approval as a supported long-term path.

The M01 canonical-model source, file-backed goldens, 12,022-byte Phase F
payload, and accepted SHA-256 identities are protected regression authority.
Ordinary verification never regenerates them. An intentional canonical change
still requires explicit review.

## Documentation contract audit

Prompt 25E introduced a bounded PowerShell audit for the consolidated project,
prompt-history, decision, and report trees. The audited live documentation now
records implementation through Prompt 27:

```powershell
& '.\tools\check_documentation.ps1'
```

It verifies required files, local Markdown targets, prompt navigation, report links, and practical orphan detection. Verbatim historical report files are excluded from link lint because their original local evidence paths are intentionally preserved rather than rewritten.

## Historical aggregate status through Prompt 27C-R1

The Prompt 27C-R1 aggregate gate passes 389/389 tests in Debug. The focused
visual-geometry gate passes 158/158 checks and the focused
visual-foundation gate passes 31/31.
Prompt 27B's semantic report contains 9,714 metrics with zero failures; each
final D3D12 review package contains 55 independent pixel metrics with zero
failures. ReleaseSafe, ReleaseFast, repository audit, D3D12/DXIL GPU smoke,
the preserved Prompt 27A 16-case evidence route, the four Prompt 27B
supplemental captures, 47/47 byte-identical R1 D3D artifacts, and review-image
repeatability pass. Current
milestone-specific commands and their evidence boundaries are documented
below.

The aggregate commands remain:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test -j1
& '.\.deps\zig-0.16.0\zig.exe' build check -j1
& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1
& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1
```

Historical declaration counts in the Prompt 20Ã¢â‚¬â€œ25 sections are
milestone-time evidence, not the current total.

## Prompt 25D focused visual geometry

`zig build test-visual-geometry -j1` is the fast character-art iteration gate.
It validates metadata, visible alpha bounds, the shared production transform,
semantic side identity, registration, directional axes, fit, coverage,
pixel-space joint continuity, profile proportions, front symmetry, the pose
matrix, and male/female morphology variation without creating a window or GPU
device. Controlled aligned/backwards, correctly sized/undersized, invalid
coverage, and over-limit distal/knee/root continuity fixtures prove that the
instrument neither accepts every input nor fails every input.

The final Prompt 25D gate retains 158 focused production checks (above the
required 129 baseline) and a separate 6,354-check pose/morphology sweep.
Locomotion, compression, rise, fall, and landing are evaluated in both side
facings; global-build and channel sweeps reset their authoritative state before
the motion matrix so the declared matrices cannot leak state into each other.

`zig build visual-geometry-report -j1` evaluates the current production
acceptance matrix and writes human-readable and JSON reports under
`zig-out/p25d_visual_geometry`. Exit code zero means every emitted production
metric passed and `failure_count = 0`. The frozen `pre_correction_report.*`
files retain the Prompt 25B-derived failure evidence.

The clean D3D12 capture uses:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
.\zig-out\bin\engine_sandbox.exe --frames 600 --demo visual-quality --scripted-input
```

The corresponding geometry overlay uses the identical character, production
submission, global queue, shaders, D3D12 backend, and readback:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
.\zig-out\bin\engine_sandbox.exe --frames 600 --demo visual-quality --scripted-input --debug-visualization
```

Golden hashing is a final change-detection layer only. After quantitative and
human acceptance, the approved D3D12/DXIL PPMs are verified with:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build check-visual-geometry-goldens -j1
& '.\tools\check_visual_geometry_goldens.ps1' -CompareLatest
```

The second command proves that the latest real-GPU readbacks equal the stored
approved captures. Prompt 25B captures remain unapproved.

## Test layers

Tests are divided by the external state they require. Ordinary `zig build test` and `zig build check` must not initialize SDL video or create a GPU device. GPU and manual visual tests are explicit separate steps.

## Pure unit tests

Pure tests cover small data transformations and invariants:

- Vector arithmetic, normalization edge cases, matrices, affine composition, and inverse transforms.
- Angle wrapping, shortest-arc interpolation, and render interpolation.
- Skeleton hierarchy validation, local-to-world traversal, and socket transforms.
- Clip boundary sampling, looping, pose blending, and half-open event intervals.
- Physical-input dead-zone, application-action mapping, and `CharacterIntent`
  conversion using renderer-independent inputs.
- Collider overlap/sweep primitives and spring integration.
- Analytical two-bone reachability, segment invariants, degenerate distances, bend direction, mirroring, continuity, and repeated-solve determinism.
- Stable draw-key ordering and handshake limb-front overrides.

Tests assert behavior and invariants rather than restating implementation expressions.

Prompt 2 additionally tests the compile-time-bound CPU/GPU strides, independently hand-computed transform points, zero and ninety-degree rotation, nonuniform and negative scale, center/top-left/arbitrary pivots, translation order, zero scale, non-finite rejection, UV/tint/page validation, integer layer boundaries, negative unsigned layers, stable equal-key ordering, reverse order, repeated deterministic sorts, near-limit submission indices, empty batches, exactly-full and growing capacity, allocation failure, byte-size overflow, 1,000 one-page instances, two page ranges, and page-return boundaries. These remain SDL- and GPU-free.

Prompt 3 adds independently hand-computed vector, matrix, transform-order, four-level hierarchy, direction, zero-scale, small-value, angle-wrap, shortest-interpolation, and tolerance-boundary cases. Skeleton tests cover valid semantics, invalid parents, self-parenting, two- and three-bone cycles, missing/multiple roots, missing/duplicate/invalid semantics, non-finite rest transforms, invalid/duplicate sockets, and transactional allocation faults. Pose/socket/attachment tests cover rest restoration, repeated evaluation, independent poses and character transforms, compatibility mismatch, rotated/scaled ancestors, immutable definition data, exact 15-part submission, preserved pivots/layers/page, one range, and fixed-buffer zero-allocation behavior.

Prompt 4 adds malformed clip, track, key, event, state, transition, fallback, and allocation-fault cases. Sampling tests cover before/at/between/after-key behavior, one-key and missing components, step/linear/smooth interpolation, shortest-angle wrap, source immutability, alias rejection, and compatibility. Playback and event tests cover time-zero entry, exact open/closed interval boundaries, same-time authored order, exact duration, one/two/five/eight wraps, ninth-wrap rejection, speed zero, negative-speed rejection, capacity overflow, and one-shot final events. Blending and state tests cover endpoints, hand-derived midpoint, invalid weight, input independence, transition interruption policy, immediate transitions, reverse transitions, one-shot completion/fallback/re-entry, independent animators, authored timelines, and fixed-buffer zero allocation.

## Deterministic simulation tests

Simulation tests create no window and use explicit fixed ticks. Scenarios include:

- Idle remains grounded without root drift over thousands of ticks.
- Walk changes root position, cycles animation, and produces visible vertical pose movement without moving the collider vertically through the ground.
- Jump applies physical upward velocity, transitions through jump and fall, collides with a platform, enters land, and returns to locomotion.
- Landing impulse drives bounded visual compression and a stable decay.
- Static-platform edge, ceiling, side, and high-speed approach cases do not tunnel beyond the algorithm's documented limits.
- A fixed-position handshake request creates one paired session without moving roots, synchronizes both role samples and shared events, measures the authored socket baseline, releases, and removes the session.
- Cancellation before and after contact restores only interaction-owned handles and leaves both characters independent and responsive.
- Replaying the same initial state and intent sequence produces the same state/event trace on the Windows x64 target.

Prompt 5 adds synthetic frame-snapshot tests for keyboard left/right/opposition, analog dead zone and merge, jump press/hold/release, interaction press, zero-tick preservation, multi-tick single consumption, rapid press/release, independent builders, and reset. Clock tests cover zero/one/multiple ticks, negative and non-finite deltas, `0.10 s` clamping, the eight-tick limit, explicit discarded-time accounting, pause/single-step, bounded interpolation alpha, and reset synchronization. Schedule equivalence groups an identical 240-tick intent trace into one-tick, two-tick, and mixed zero/one/multiple-tick rendered frames and compares authoritative position, velocity, grounded state, facing, tick count, and animation state within the tabled tolerance.

Controller/collision tests cover configuration and AABB validation; allocation fault cleanup; gravity, ground/air acceleration, deceleration, speed clamp, facing stability; floor/ceiling/wall/platform sweeps at and beyond configured speed; floor contact and 600-tick resting stability; platform landing, underside collision, walk-off, and support clearing; grounded, coyote, and buffered jump acceptance/consumption; exact timer boundary success/failure; held-input non-repetition; tap/hold apex separation; release after apex; impact capture and landing-event uniqueness; reset while grounded, rising, falling, buffered, and transitioning; interpolation independence; one animator update per fixed physics tick; and full 600-frame scripted-route completion. Tests use `1e-4 m`/`1e-4 m/s` for controller comparisons because this is the documented contact tolerance and remains far below one presentation pixel at 82 pixels per metre.

Prompt 6 adds 20 behavioral tests. Spring cases cover invalid and non-finite configuration/state, exact rest, signed displacement and velocity recovery, impulse/clamp behavior, 2,400-tick convergence, 24,000-tick stress, repeated-run determinism, and reset replay. Landing cases cover the resting-contact threshold, exact threshold, monotonic nominal/maximum response, above-maximum clamping, harder-impact peak ordering, one-event consumption, no-event wall/ceiling equivalents, reset, and the combined `[-0.060, +0.045] m` visual-root guard. Walk cases cover zero/partial/full/negative/above-full speed, alternating contact phases, blend in/out, airborne suppression, and exact neutral output after 1, 10, and 1,000 cycles. Secondary cases cover acceleration direction, bounds, settling, reset/teleport synchronization, disable, independent character state, one-time pose composition, and zero allocation metrics.

The mandatory anti-cheating test executes the same 600-frame raw scripted input twice through `CharacterIntent`, controller, animation, procedural motion, and pose: once enabled and once disabled. It compares final physics position and velocity within `1e-5`, then requires exact grounded state, supporting collider ID, and landing-event count. A separate fixed-tick trace is grouped as one-tick frames, four-tick frames, and mixed zero/one/multi-tick frames; landing, walk, and secondary states agree within `1e-5`.

Prompt 7 adds 17 behavioral tests. Entity tests cover deterministic monotonic `u32` generation, zero rejection, duplicate rejection, registry capacity, maximum-value issuance, and overflow. Ownership tests cover distinct poses, animator scratch/event storage, procedural state, optional controller state, facing, overrides, isolated reset, whole-scene reset, safe instance teardown, and five genuine second-character fault stages with successful retry. Ordering tests cover both actor directions, equal-layer entity-ID stability, cross-character interleaving, both hand directions, forearm-over-torso partial interleaving, per-component override precedence, exact restoration, invalid targets and values, eight-slot overflow, and handle overflow. Facing tests cover right/left hand and foot sockets through rotated ancestors, anatomical preservation, default-layer role reversal, negative-scale decomposition, collision invariance, and a double mirror. Batching tests require exactly 30 page-zero sprites and one range, including empty global input.

Prompt 8 adds 18 behavioral tests (bringing the aggregate Zig count from 104 to 122). Definition cases cover participant count, role clip/state validation, paired duration, paired event presence/order/time, finite envelopes, legal lifecycle edges, exact authored tick conversion, and checked interaction-ID overflow. Eligibility cases cover invalid/duplicate IDs, both lock directions, passive/controller grounding, disallowed airborne states, inclusive minimum/maximum/vertical boundaries and just-outside values, all facing failures, candidate alignment/distance/ID ranking, and container-order independence. Input cases cover zero-substep preservation, one-time multi-step consumption, held-button non-restart, and release/new-press restart. Startup cases inject failure after A/B reservation and A/B transition, fill all four slots, and exhaust contact override capacity. Runtime cases require exact shared start/contact/release/complete ticks, one semantic event each despite paired clip copies, synchronized normalized time, owned-only layering cleanup, unrelated override survival, before/after-contact cancellation, reset/single-step behavior, mirrored equivalence, AB/CD isolation, and regular/large/mixed render-group agreement. The controller-invariance test compares position, velocity, grounding, and support with interaction disabled/enabled.

Prompt 9 adds 22 behavioral tests, bringing the aggregate count from 122 to 144. Synthetic solver cases cover valid and rejected inputs, zero-distance fallback, straight/interior/diagonal geometry, exact safe boundaries, near/far clamping, opposite bends, mirrored targets, near-extension continuity, moving targets, and repeated bit determinism. Binding and application cases cover stable valid indices, invalid bones/sockets/parents, immutable `0.65/0.80 m` lengths, weights zero/half/one, shortest-angle wrap, unreachable world targets, and fixed roots. Paired cases cover symmetric target order, A-then-B versus B-then-A, fixed-tick weight samples, nominal and perturbed convergence, mirrored anatomy, zero/one/multi-substep grouping, IK-disabled/enabled timing and controlled physics agreement, cancellation in four phases, completion, scene and participant reset, unrelated reset isolation, and simultaneous pair cancellation/completion isolation.

Prompt 10 adds 24 behavioral tests, bringing the aggregate count from 144 to 168. Ground-query cases cover floor/platform/no-hit, exact range/surface inclusion, just-beyond rejection, slight height, origin below/inside, overlapping tops and stable ID ties, platform edges, ineligible walls/ceilings, and invalid numeric input. Binding/application cases cover both anatomical chains, invalid hip/knee/ankle/socket, immutable `0.900000/0.919239 m` lengths, zero/full weight, mirrored forward knee bend, no stretch, near/far conflict release, and left/right solve-order equivalence. Plant cases cover valid/no-ground/airborne/out-of-range contact, transition-start blending, pending reach-safe acquisition, fixed locks, repeated contacts, left/right jump release and fresh acquisition, reset, foot/character isolation, floor/platform fresh height, edge rejection, slip reduction, penetration/hover bounds, enabled/disabled controller and animator invariance, regular/large/mixed render schedules, arm-chain coexistence, handshake timeline/lock coexistence, and the complete scripted floor-to-platform route.

The mandatory Prompt 7 physics test replays the unchanged 600-frame scripted controller sequence twice: once with the controlled character alone and once with a passive independently updated second character sharing the immutable definitions. Final position and velocity agree within `1e-5`; grounded state, supporting collider, and five landing events agree exactly. A separate order-only trace changes actor, interaction, and body layers while comparing animation time, local pose, walk bounce, landing spring, secondary spring, and an untouched controller state.

## Floating-point tolerances

Exact floating-point equality is used only for values defined by exact assignment or discrete state. Numerical assertions use the smallest tolerance appropriate to the subsystem:

| Measurement | Tolerance | Rationale |
| --- | --- | --- |
| Basic vector/matrix identities near unit scale | absolute `1e-5` | Covers normal f32 rounding across several operations without hiding a visible transform error |
| Angle interpolation | absolute `1e-5` radians | Covers wrap/interpolation rounding and is far below a visible angular difference |
| Collision contact position | absolute `1e-4` m | One tenth of a millimetre is above accumulated f32 contact arithmetic noise and below gameplay-visible penetration |
| IK endpoint in an analytically reachable case | absolute `1e-4` m | Allows transform-chain rounding while still detecting an incorrect solve |
| Handshake full-weight target error | absolute `2e-4` m per hand | Bounds transform-chain rounding while requiring both sockets to converge on the same frozen target |
| Spring settled value | absolute `1e-4` m and velocity `1e-4` m/s | Tests convergence without requiring an asymptotic value to become bitwise zero |

A test that needs a larger tolerance must explain the numerical source locally. Tolerances may not be widened merely to make a failure pass.

## GPU smoke tests

`zig build gpu-smoke` is an opt-in Windows test that requires a physical or supported hardware GPU. It must:

1. Initialize SDL video and create a small test window.
2. Prove DXIL support for `direct3d12`, create that backend explicitly, log the driver returned by SDL, and verify the created driver and reported shader format.
3. Claim the window and acquire a swapchain texture.
4. Load the build-produced vertex and pixel DXIL, create both shaders and the sprite graphics pipeline.
5. Upload a four-color procedural RGBA texture and shared quad vertex/index data, then submit two distinct records through the production three-slot sprite-batch transfer path.
6. Execute both shader stages and render the two instances in one indexed instanced draw, submit, and present three frames.
7. Render again to an `R8G8B8A8_UNORM` color target and download that render target through an SDL GPU download transfer buffer.
8. Use an explicit D3D12-compatible row pitch: `align(width * 4, 256)` bytes, pass `pixels_per_row = row_pitch / 4`, and address each mapped row with that pitch. The implementation checks SDL's texel block size instead of assuming a four-byte format contract silently.
9. Submit with `SDL_SubmitGPUCommandBufferAndAcquireFence`, wait successfully with `SDL_WaitForGPUFences`, and only then map the download transfer buffer.
10. Compare an exterior clear pixel and two non-overlapping interior sprites expected to match red and yellow regions selected by distinct UV rectangles from the same texture. Channel tolerance is one integer code value.
11. Inject controlled failures after sprite-batch CPU allocation, SDL initialization, window creation, device creation, window claim, shader creation, sampler creation, textures, shared quad vertex/index buffers, static transfer creation, upload, instance frame-slot creation, pipeline creation, transactional GPU growth replacement, and frame-fence acquisition.
12. Release every resource and report any SDL operation plus `SDL_GetError()` on failure.

The smoke test fails with a nonzero exit when a graphical session, swapchain texture, required hardware/backend, DXIL agreement, rendering operation, fence, mapped readback, or expected pixel is unavailable. It is never reported as skipped success and never falls back to another API.

## Manual visual acceptance tests

The final visual pass records the GPU driver, resolution, and build mode, then verifies:

- Two visibly segmented humanoids render through the GPU sprite batch.
- Keyboard and gamepad independently control the intended character with sensible dead zones and hot-plug behavior.
- Idle, walk, jump, fall, land, and handshake states are visually distinct and transition coherently.
- Walking shows vertical body movement while the physics root remains collision-correct.
- Gravity, jump arcs, and collision work on every static demo platform.
- Landing produces visible compression followed by stable spring-like recovery and secondary follow-through.
- The Prompt 8 handshake remains available as the synchronized authored baseline; the Prompt 9 route separately proves nominal, mirrored, and meaningfully perturbed shared-target convergence without root correction.
- A control or scenario switches which handshake hand/forearm is in front, with the requested order visible.
- Debug display identifies bones, colliders, hand sockets, and the shared interaction target.
- Alpha edges blend correctly and no body part is rendered through a per-sprite command submission path.
- The Prompt 19 mixed route visibly interleaves a cape, body sprites, topology-expanded sleeves, fitted torso garment, and rigid clasp according to authored integer layers. The two-arm and four-arm characters must show two and four distinct sleeve instances, mirrored facing, build/breathing response, and deterministic cape removal/restoration.
- Drag the visible window through wide, tall, and square aspect ratios. The vertical world boundaries must remain fixed as drawable height changes; character pixel height must scale linearly with drawable height. Equal-height wider windows may reveal more horizontal world, but no aspect ratio may stretch X versus Y.
- Minimize and restore repeatedly, including on a high-DPI display when available. A zero drawable must skip safely, restoration must resume, and no unrelated persistent GPU resource count may change.
- Walk far left in the playground. The camera must follow without moving the physics root, and distant cave, midground pillars, and gameplay geometry must show clearly different horizontal response.

## Performance and allocation checks

Performance checks run a ReleaseFast build after correctness passes. Debug metrics report fixed ticks, frame time, instance count, draw count, transfer bytes, fixed-step overruns, and any bounded collection growth.

Acceptance targets for the two-character demo are:

- Zero heap allocations during a steady 10,000-tick simulation after initialization.
- Zero unreported capacity growth during steady rendering.
- One sprite instance upload and one indexed instanced sprite draw for a frame when all body parts share the atlas/pipeline; debug rendering is counted separately.
- No command submission per body part.
- Stable 60 displayed frames per second on the documented reference machine, with 240 Hz simulation and no sustained fixed-step overruns.

The reference GPU/CPU and measured percentile frame times will be added when performance testing begins; no unmeasured target is reported as passed.

Prompt 2's executable evidence run is `zig build run -- --frames 300`. Its final metrics must show 1,000 submitted/visible/sorted sprites, zero culled sprites, one range, one actual `SDL_DrawGPUIndexedPrimitives` call with 1,000 instances, 60,000 uploaded instance bytes, no post-stabilization CPU allocation, no GPU slot growth, and identical persistent-resource creation counts before the run, after warm-up, and after frame 300. Frame-slot waits are acceptable only when a reused slot's fence was observed unsignaled.

F4B2 retired Prompt 3's standalone humanoid shell. Its useful hierarchy, socket, attachment, pose-independence, allocation, and submission invariants remain in `tests/skeleton_tests.zig` and run through `zig build test`.

F4B2 retired Prompt 4's standalone animation shell. Clip sampling, transition, event, state-machine, replay, independence, and zero-allocation invariants remain in `tests/animation_tests.zig` and run through `zig build test`.

Prompt 5's executable evidence run is `zig build run -- --frames 600 --demo controller --scripted-input`. It must complete 2,400 physics ticks and exactly 2,400 animator ticks; exercise ceiling, both raised platforms, coyote jump, buffered jump, wall, and stable final ground; submit 15 humanoid sprites plus five collider sprites as one page-zero range and one indexed-instanced draw; report bounded clock/discard metrics; and report zero clock/input/intent/controller/collision/animation-selection/animator/interpolation allocations plus zero GPU resources created by movement. Incomplete scripted milestones cause a nonzero exit.

F4B2 retired Prompt 6's standalone secondary-motion shell. The permanent `secondary_motion_tests.zig` suite retains speed-scaled walk response, contact semantics, head lag, landing compression, recovery, reset replay, render-group determinism, controller equivalence, and zero hot-path allocation.

F4B2 retired Prompt 7's standalone multi-character shell. The permanent `multi_character_tests.zig` suite retains immutable-definition sharing, mutable-state isolation, deterministic entity ordering, reflection, override/reset behavior, passive-character physics equivalence, and one-batch submission.

F4B2 retired Prompt 10's standalone foot-planting shell. The permanent `foot_planting_tests.zig` suite retains contact acquisition/release, immutable targets, slip/penetration/hover tolerances, floor/platform IK, jump/reset clearing, schedule determinism, physics/animator invariance, interaction coexistence, and allocation behavior.

Prompt 11 originally added 11 deterministic integration tests. They cover a 32-entry diagnostic ring's overwrite order, fixed-capacity debug overflow (512 commands after Prompt 25C), debug-off/on authoritative equivalence, never-read/read-every-tick diagnostics equivalence, repeated non-destructive getters, landing-event single delivery, animation-contact physics invariance, pre-arm-IK target freezing, final hierarchy evaluation, reset during plant/airborne/pre-contact/contact, character-local isolation and interaction-peer release, three render grouping schedules, sequential complete handshakes, and a repeated integrated route. The final adversarial audit strengthens those same cases to 1,000 handshakes and 100,000 fixed ticks. The long route executes at least 30 complete walk/jump/platform/handshake/cleanup cycles, checks finite controller, spring, and foot state on every tick, rejects airborne locks, bounds slip to `0.0002 m`, and ends with zero allocation/resource growth and no stale interaction, override, or IK state.

Prompt 12 adds four focused regression tests, bringing the aggregate Zig count from 179 to 183. They cover deterministic lowest-ID support and sweep-face selection under collider-array permutation; an exact wall/floor diagonal corner at maximum run/fall speeds, including stable rest and epsilon-height support; exact requested/executed/discarded time under sustained 20 FPS overload plus an alternating zero/eight-substep schedule; and four-character state isolation with deliberately different animation, spring, facing, layer, foot-lock, and interaction-lock state. Existing tests were also strengthened for 20 zero-substep input frames, eight-substep one-shot edge consumption, pending-edge reset, coherent foot lifecycle chronology across repeated semantic contacts, comparator law checks at signed integer extremes, the 1,000-cycle interaction run, and the 100,000-tick integrated stress run.

Prompt 13 adds ten grouped deterministic tests, bringing the aggregate count from 183 to 193. They cover every keyboard alternative and neutral opposite-key combination; Space/E/R/F1/Escape/window-close transition edges, held-state repeat rejection, and keyboard/gamepad deduplication; focus loss, release reconciliation, held-key suppression, and phantom-free regain; 20 zero-substep frames plus press/release coalescing and eight-tick single consumption; real controller movement, deceleration, facing, and opposing-input rest; measured short/held jump apex ordering; identical raw-key controller outcomes under one-tick and four-tick render grouping; real interaction completion, held-E non-restart, release/new-press restart, and world-aware reset cleanup; authoritative F1 invariance; and the complete 1,800-frame raw-key playground route without a window or GPU.

Prompt 13's GPU-backed evidence run is:

```text
zig build run -- --frames 1800 --demo playground --scripted-input
```

It must demonstrate idle, left and right movement, release deceleration, opposing-key neutrality, measured short and held jumps, landing, debug on/off, controller-driven approach, exactly one E request and handshake completion while E stays held, one R reset, and a stable initial final state. It reports two characters, five environment colliders, 14 cave-layer sprites, 49 ordinary sprites, one texture page/range/actual draw, zero input-created GPU resources, and zero steady-state mapping/intent/playground allocation growth. Missing milestones or cleanup evidence returns nonzero.

Prompt 14 originally added 12 grouped deterministic tests around a fixed
82-pixel-per-metre resize policy. The current height-relative presentation
decision deliberately supersedes that one assertion while preserving its
640Ãƒâ€”480 mapping, positive-Y-up transforms, zero-size rejection, GPU uniform,
parallax, follow, physics-invariance, extended-world, and traversal coverage.
The focused `zig build test-camera` route now also covers the 720/1080/1440/
2160 linear scales, fixed vertical span, equal-aspect world extents,
width-only aspect behavior, uniform X/Y mapping, inverse transforms, a
multi-size round trip, and zero-height recovery.

Camera scalar/world comparisons use `1e-5`. The 4K uniform-axis pixel-delta
comparison uses `0.0001 px`: subtracting nearby `f32` presentation coordinates
whose magnitudes are in the thousands produced `0.00002 px` cancellation in
the focused run, and the selected bound remains four orders of magnitude below
one physical pixel.

Prompt 14's bounded GPU-backed route is:

```text
zig build run -- --frames 1100 --demo side-scroller --scripted-input
```

It drives the real mapped `A` input through the 240 Hz controller into the extended-left world, traverses from `-3.15 m` past `-24 m`, and lets the character decelerate. The route must report at least 12 metres of deterministic camera-center travel, distant factor `0.125`, midground factor `0.45`, gameplay factor `1.0`, one texture page/range/actual draw, zero steady-state allocations, zero unrelated GPU-resource creation, and current drawable pixel dimensions. Failure to travel, follow, render, or cleanly settle returns nonzero. The fixed `zig build gpu-smoke` route remains 640Ãƒâ€”480 and verifies the same shader contract through deterministic readback independently of visible-window resizing.

Prompt 15 adds eight grouped deterministic tests, bringing the aggregate Zig count from 205 to 213. They prove the canonical 16-bone rig, rest transforms, semantics, and four sockets remain unchanged while a definition adds custom attachment-point, region, group, visual, module, joint, and socket IDs. They cover zero and extended visual counts; multiple visuals sharing one point; visual-parent hierarchy; duplicate, dangling, self/cycle, and transactional cleanup failures; character-local visibility, deformation, and module pose with exact reset; mirrored point/module/child visuals; stable equal-layer input ordering; and 128 repeated appearance mutations/evaluations/submissions with no allocator movement after initialization.

Prompt 15 does not add a new renderer or GPU acceptance route. The permanent humanoid, animation, multi-character, interaction, IK, and foot-planting suites exercise the unchanged canonical semantics; retained `integrated`, `playground`, `side-scroller`, and `gpu-smoke` routes continue to exercise the shared GPU batch. The extended test definition is intentionally headless and uses abstract harmless visuals plus a two-joint module to prove Prompt 16 can add real modular anatomy without changing locomotion topology.

Prompt 16 adds ten grouped deterministic tests, bringing the aggregate Zig count from 213 to 223. They cover exact morphology interpolation at 0/50/100; channel and per-instance override precedence; invalid values/ranges; preset isolation and reset; conventional and repeated adult-module configurations; dangling parent and cycle rejection; independently addressable face features and three hair styles; two validated face groups using the same generic feature definition while resolving materially different visual transforms, sizes, tints, visibility, and independent character state; presentation switching with an unchanged topology fingerprint; explicit module-local articulation; unchanged controller, animation, interaction-owner, canonical rest, and IK length state; independent runtimes; repeated-run equality; and fixed-buffer zero-allocation updates.

The dedicated non-sexual GPU evidence route is:

```powershell
zig build run -- --frames 240 --demo modular-body
```

It renders conventional male, conventional female, and extra-arms/tail/horn presets through one shared skeleton, animation library, global sprite batch, texture page, and indexed-instanced draw. The first two characters render the visibly distinct `conventional_face` and `angular_face` definitions side by side through the same bounded anatomy-to-appearance path. It switches profiles and hair deterministically and requires zero fixed-buffer movement or GPU-resource creation after initialization.

Prompt 17 adds five grouped deterministic tests, bringing the aggregate Zig count from 223 to 228. They cover duplicate identifiers, missing slot and attribute references, and creation of future slot/attribute/capability IDs; the same garment resolving exactly two and four upper-arm instances; required, optional, specific, and maximum-bounded matching; transactional conflict rejection; layering, coverage, multi-slot replacement, unequip, and default reset; grant removal; independent character loadouts; definition-sorted visuals and effects under different equip request orders; fixed-buffer zero-allocation equip/unequip/rebind; unchanged canonical hand sockets; and inherited facing reflection. The complete pre-existing handshake and analytical IK suites remain in `test_all.zig` and regression-protect interaction timing, socket measurement, target freezing, limb overrides, and visual-pose-only authority.

The dedicated Prompt 17 GPU evidence route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo equipment
```

It must report the same sweatshirt definition, exactly two conventional sleeves and four nonstandard sleeves, transactional conflict rejection, multi-slot replacement, unequip/restoration, independent loadouts, deterministic modifier/capability listings, two characters, one texture page/range/actual indexed-instanced draw, unchanged fixed-buffer usage, zero post-stabilization batch allocation, and zero equipment-created GPU resources. Missing evidence returns nonzero.

Prompt 18 adds eight grouped deterministic tests, bringing the aggregate Zig count from 228 to 236. Coverage lives in `tests/deformation_tests.zig` and separately checks breathing neutral/extreme samples, repeated bounded cycles, reset, independent character rate/phase, body/clothing agreement, exact topology-expanded sleeve drivers, per-part isolation, rigid response, global morph composition, equip/unequip at non-neutral phase, physics/controller/canonical-IK/effect invariance, handshake timing, render-frame grouping, and fixed-buffer allocation stability.

F4B2 retired the standalone Prompt 18 breathing shell. The eight grouped
production-facing deformation tests above remain the acceptance path; retained
`mesh-attachments` and `foundation` routes continue to exercise breathing
through the real unified GPU composition.

Prompt 19 adds seven grouped deterministic tests, bringing the aggregate Zig count from 236 to 243. Coverage lives in `tests/mesh_attachment_tests.zig` and checks finite/UV/topology/index/degenerate/capacity validation; immutable definition and persistent topology-catalog ownership; partial allocation cleanup; exact CPU/HLSL record sizes; bounded weighted deformation; one semantic sprite/mesh ordering stream; compatible mesh instancing; topology-expanded two/four-sleeve binding; distinct repeated and cross-character mutable state; mirrored facing; equip/unequip; deterministic queue capacity failures; and zero fixed-buffer movement after stabilization.

The bounded Prompt 19 GPU-backed mixed-primitive evidence route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo mesh-attachments
```

It requires two segmented characters, body sprites, fitted garments, six topology-expanded sleeve meshes, two cape meshes, rigid clasps, separately measured build and breathing deformation, mirrored facing, cape unequip/re-equip, real mesh shader/indexed-instanced execution, separate honest sprite/mesh range/draw/upload metrics, persistent topology resources, three bounded dynamic frame slots, and zero CPU/GPU resource growth after stabilization. A linked-build or GPU failure remains a failure; pure tests and shader compilation do not substitute for that evidence.

Prompt 20 adds six grouped deterministic tests in `tests/attachment_secondary_motion_tests.zig`; the repository contains 249 top-level Zig test declarations after this change. Coverage includes definition/finite/stability validation; exact rest; acceleration, sustained motion, reversal, sudden stop, jump, fall, and landing direction; facing reset and reset replay; extreme valid parameters; 24,000-tick convergence; deterministic repeated runs; independent states sharing one immutable definition; long-hair/ponytail and cape ownership across two characters; flexible topology-expanded repeated instances; equip/unequip/re-equip cleanup; grouped unified rendering; controller/physics and interaction invariance; the complete 240-frame headless evidence script; and fixed-buffer/resource stability.

F4B2 retired the duplicate Prompt 20 attachment-secondary route. The six
permanent production-facing tests above retain the motion/lifecycle/authority
contract, while the retained `mesh-attachments` route continues to exercise
the shared sprite/mesh GPU path.

Prompt 21 adds seven grouped deterministic tests in `tests/character_properties_tests.zig` and extends the existing input tests; the repository contains 257 top-level Zig test declarations after this change. Coverage includes attribute definition/range/base validation; additive and multiplicative modifier validation and combinations; deterministic source-key sorting; clamping; base overrides; capability defaults and independent source counts; duplicate-source rejection; removing one of two grants; character isolation; equipment gain/loss/replace/reset; two-item attribute stacking; carrying capacity, armor, and damage-reduction queries; appearance independence; movement-speed and jump-strength controller consumption; denied/allowed/exhausted double jump; airborne removal; denied/allowed dash; facing and active-removal behavior; wall collision; exact default-controller regression; and zero property-resolution allocation.

F4B2 retired the standalone Prompt 21 properties shell. The seven permanent
property/controller tests above retain movement, jump, capability, dash,
collision, isolation, restoration, and allocation coverage.

Prompt 22 adds four grouped deterministic tests in `tests/foundation_playground_tests.zig`, bringing the repository to 261 top-level Zig test declarations. The focused command is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-foundation
```

Coverage includes the complete 1,800-frame raw-input route; left/right traversal, camera follow, three-layer parallax, short and stronger held jumps, body/build/hair changes, topology rebind, speed/jump loadouts, double jump, dash, landing, breathing, cape/sleeve response, approach, one handshake contact/release/completion, two synthetic viewport changes, exact loadout restoration, reset, and stable final state. Separate cases compare gameplay/loadout/pending edges across viewport changes, mutate then verify the complete reset baseline, and exercise deterministic bounded unified sprite/mesh ordering with debug primitives.

Prompt 27 supersedes the old procedural GPU composition while preserving the
Prompt 22 route as the focused `test-foundation` regression. The current
GPU-backed acceptance route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 2400 --demo foundation --scripted-input
```

The current route requires Direct3D 12/DXIL, two persistent garment mesh
definitions, two production-art characters, eight static colliders, actual
controller property consumption, canonical handshake IK/foot planting, exact
reset, zero fixed-buffer update/submission growth, zero unified-queue
allocation after stabilization, and zero GPU-resource creation after
scene/topology initialization. It reports actual sprite/mesh instance, range,
draw, and upload peaks. The interactive companion is
`zig build run -- --demo foundation --interactive`.

Resize verification is split deliberately: pure tests use synthetic viewports
and compare controller, animation, world transform, appearance/loadout state,
camera center, and pending edges across the atomic camera update. The
production-scene test continues update/submission work after a 1920Ãƒâ€”1080
resize to prove later camera publication retains 184.5 px/m. The SDL route
feeds real resize/pixel-size/restore events through `SDL_GetWindowSizeInPixels`
and confirms acquired swapchain dimensions again before GPU encoding. A zero
drawable skips without deriving scale. Neither form claims physical manual
resizing or a visible 4K window unless it was actually performed.

The active Prompt 27B scripted fixture retains its 960Ãƒâ€”540, 800Ãƒâ€”510, 640Ãƒâ€”480
incremental sequence and the separately classified direct 960Ãƒâ€”540-to-640Ãƒâ€”480
transition in their original route phases. Every viewport-change frame is
classified as instantaneous viewport reprojection instead of ordinary
same-viewport world-camera motion. On the first submitted frame at a
non-reference height, a submitted-bounds correction that is independently
required uses the available safe-region interval symmetrically so later bound
changes have head and foot slack. If identical bounds are already safe, resize
leaves the camera center exactly unchanged. Later frames at that viewport
return to nearest-edge correction and retain the unchanged 16 px/render limit.
Returning to 640Ãƒâ€”480 does not invoke the non-reference recenter. Registration,
ground alignment, secondary motion, physics, animation, and interaction
behavior remain unchanged.

Prompt 11's GPU-backed evidence run is:

```text
zig build run -- --frames 2400 --demo integrated --scripted-input
```

It must execute exactly 9,600 fixed ticks, complete all 16 asserted milestones, use two humanoids and the real controller/interaction/IK/foot systems, preserve 35 ordinary sprites in one texture range and one actual draw, report zero steady-state allocation and GPU-resource delta, and end grounded with no active interaction, participant lock, interaction-owned override, arm constraint, or airborne foot lock. `--debug-visualization` runs the same route with the bounded debug overlay; authoritative milestone and final-state tests prove equivalence, and the compatible overlay remains inside the one actual draw.

## Build command contract

The finished build graph must support:

```text
zig build
zig build test
zig build run
zig build gpu-smoke
zig build check
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=ReleaseFast
```

`zig build check` runs `zig fmt --check` on Zig sources and build files, pure and deterministic tests, and repository audits that need no GPU. Source audits check for prohibited high-level render APIs, forbidden graphics/engine dependencies, unfinished markers, disabled tests, and missing resource-release ownership. Documentation examples are not treated as executable source.

Prompt 1 introduced each listed command with a real target. Later milestones extend the same build interface rather than replacing it.
## Prompt 23 art-pipeline verification

`zig build test-art` runs ten focused tests split between platform-independent definition/render routing and Windows WIC decode behavior. Coverage includes page definitions and per-page nearest/linear policy; duplicate page and region IDs/names; exact normalized UV derivation; atlas bounds and arithmetic overflow; invalid pivots; missing page and region references; duplicate or conflicting semantic bindings; fixed-buffer allocation failure; synthetic view 37; declaration reorder stability; two-page unified ranges; deformable-mesh material compatibility; alpha-bearing RGBA decode; missing/corrupt/unsupported image errors; image metadata bounds; and zero post-stabilization queue allocation.

The permanent focused command is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-art -j1
```

The former `art-assets` sandbox route was retired after its multi-page
sprite/mesh submission, semantic resolution, exact decode, and steady-state
allocation coverage moved to a test-only fixture. Physical D3D12/DXIL proof is
owned by `gpu-smoke` and `run-engine-smoke`; neither command claims subjective
manual art approval.

## Prompt 24 character-presentation verification

Run the focused platform-independent suite:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation
```

It covers the complete automatic view policy; override/interaction precedence and cleanup; facing and root invariance; reset; single-root side reflection; non-reflected front projection; both-view region completeness; bald, buzz-cut, and long-hair resolution; explicit front semantic layers; interaction cancellation; deterministic spring reset; allocation-free view changes; two-character isolation; `Q` input; and bounded submission on both views. Prompt 24A additionally resolves every canonical male/female side/front base region with no garment, proves torso and vest semantic/region IDs differ while their real production page is shared, removes and re-resolves the optional garment without changing the base result, and asserts zero fixed-buffer growth across repeated resolution. Aggregate `zig build test` retains the existing deformation, IK, foot-planting, interaction, controller, and reset regression suites.

F4B2 retired the standalone Prompt 24 scripted and interactive shells. The
focused suite above remains authoritative for presentation policy, mapping,
interaction cleanup, secondary reset, input, and bounded submission. Current
GPU inspection uses the retained production `foundation` and
`anatomy-quality` routes; historical Prompt 24 evidence remains preserved.

Manual visual acceptance remains separate from automated regression coverage.
Use the retained production visual routes to inspect coherent silhouettes,
face readability, hair shape, consistent lighting/scale, joint overlaps,
front semantic ordering, movement articulation, breathing, hair response,
view transitions, and handshake contact. Automated success proves routing and
invariants but cannot by itself prove subjective joint/art quality.

## Prompt 25 wardrobe verification

Run:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo wardrobe --scripted-input --frames 600
```

The focused suite validates all item/preset/component IDs, complete and distinct paired side/front art, deterministic lookup, duplicate/conflicting slots, independent occupancy/layer/coverage, blouse-plus-cardigan composition, reuse across presets, custom recombination, zero cosmetic effects, two/four-arm sleeve expansion, bilateral semantic-foot binding, invariant foot matrices, hair/headwear coexistence, transaction state preservation and rollback, two-character isolation, long-mesh and secondary-state cleanup, reset, focus-safe O/P edges, both-view queue submission, and fixed-buffer stability after initialization. The `0.000001` matrix/controller tolerances isolate unintended state mutation while allowing normal `f32` representation; selection performs no arithmetic expected to exceed this bound.

The D3D12 route must report:

- `direct3d12` selected and DXIL agreement;
- six decoded production art pages and two persistent skirt mesh definitions;
- 15 presets, 30 items, 36 components, 72 wardrobe regions, and 72 bindings;
- every preset observed in front and side, including both mandatory outfits;
- custom recombination, headwear/hair, long mesh/secondary motion, legwear, footwear, breathing, locomotion, jump, land, and unchanged male evidence;
- zero update, submission, queue, and hot-swap GPU-resource growth after initialization.

Manual visual acceptance inspects every preset in both views through the real D3D12 window. Confirm torso pieces are centered on anatomy rather than the head, sleeves bind each visible arm, lower pieces remain independently composed, the split skirt deforms below the pelvis, headwear and long hair coexist, shoes remain on planted feet, the base-only preset reveals intact neutral anatomy, and the custom outfit visibly layers blouse below cardigan. Sequential window captures are acceptable evidence of the real route; they do not count as physical input testing.

## Prompt 25A visual-quality gate

Run the non-interactive hard gate only through its exact route:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\engine_sandbox.exe' --frames 600 --demo visual-quality --scripted-input
```

The route writes eleven P6 images from the same prepared 640 by 480 global queue
used by D3D12, using one persistent pre-checkpoint transfer buffer. It requires
base male/female front and side; representative male/female wardrobe front and
side; `wide_brim_crimson`; `ivory_blouse_red_shorts`; the recombined ivory
blouse plus crimson cardigan in both views; stride; jump rise; and jump fall.
It rejects an incorrect frame count or non-scripted invocation.

Focused Prompt 25A coverage extends `test-presentation` and `test-wardrobe` with
exact production page dimensions/paths, nonzero in-bounds regions, audited
alpha-tight shoe/sleeve extraction, side and front joint geometry, semantic
shoe pivot/offset, and a 600-frame fixed-buffer acceptance schedule. These tests
remain necessary but do not replace pixel judgment.

`VISUAL_ACCEPTANCE_25A.md` contains the nineteen-item checklist for every final
capture, concrete observations, normal and nearest-neighbor 2x review, and the
before/after evidence. `PROMPT25A_DECISION_RECORD.md` records the root causes,
rejected iterations, image-generation provenance, architecture decisions, and
minor remaining visual limitations. This scripted/GPU evidence does not claim
physical keyboard input or manual window resizing.

## Prompt 25B character-art gate

Run the two focused suites and the real-art alpha audit before the aggregate
regression:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation
& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe
& '.\tools\audit_p25b_art.ps1'
```

The art audit opens the production component PNG and both production base
pages. It checks all 28 corrected pelvis/arm/hand/leg/foot regions plus the two
re-authored front torso regions for exact atlas bounds, visible alpha, packing
margin, unique source rectangles where applicable, compact shoulder
silhouettes, and authored-to-alpha aspect ratio in the 0.82..1.20 band. Focused
tests additionally prove distinct forearm/shin UVs, rig-length and pivot
bounds, one authoritative-to-side root compression, deterministic front
anatomy mirroring, forearm-over-upper-arm elbow overlap, pelvis-behind-thigh
overlap, corrected female hand size, allocation-free submission, and the
existing anatomy/equipment ownership boundary.

The legacy bilateral-equipment regression proves only mirrored submission
metadata: two quads, opposite signed X scales, reflected pivots `0.05/0.95`,
equal absolute widths, and at least `0.35 m` center separation. It does not
prove heel/toe registration, forward direction, sole angle, fit, or visible
coverage. Prompt 25C preserves that test under the precise name "bilateral
footwear receives mirrored submission metadata" and adds the stronger semantic
and alpha-visible checks separately.

Visual acceptance uses the same Prompt 25A D3D12 route after rebuilding. The
accepted Prompt 25B hard-gate captures are retained under
`zig-out/p25b_followup_final`; the earlier comparison remains under
`zig-out/p25b_visual`. The
same-scale before/after review is
`zig-out/p25b_visual/prompt25a_vs_prompt25b_same_scale.png`. Inspect neutral
front/side first, then clothed front/side, stride, jump rise, and jump fall.
`PROMPT25B_DECISION_RECORD.md` records source identities, actual region
rectangles, causes, corrections, and remaining visual limits.

## Prompt 26 environment validation

Fast deterministic gate:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-environment -j1
```

The focused tests prove:

- exact two-page/two-theme art-pack completeness and missing-reference errors;
- absence of collision/spawn/interaction ownership in theme input;
- exact eligible-collider surface count, IDs, and endpoint coordinates;
- exclusion of walls, ceilings, and decorative non-collision ledges;
- terrain/surface/character/debug ordering in `UnifiedRenderQueue`;
- distinct preloaded page identity with no GPU/file owner in presentation;
- allocation-free repeated switching;
- preservation of controller, root, facing, view, outfit, interaction owner,
  fixed clock, pending input, camera, collision, and surface state;
- deterministic `T` edge and focus-loss filtering;
- scripted front/side, parallax, stationary in-place switching, jump and
  non-floor raised-platform landing, resize, reset, debug, allocation, and
  fixed-tick evidence.

Real D3D12 acceptance route:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo environment --scripted-input --frames 720
```

The route must preload eight art pages, retain nine configured renderer pages,
produce seven 640 by 480 captures in `zig-out/p26_environment_gpu`, report two
theme switches, six white standable segments, a recorded raised-platform
landing frame, unchanged collision/surface
fingerprints, zero post-initialization allocation/resource growth, and real
D3D12/DXIL rendering. Inspect neutral front, side/parallax, in-place debug
theme, switch-back, jump, raised-platform landing, and detailed collider
frames. White tops
must match floor/platform collision exactly and remain visually distinct from
cyan/orange detailed debug.

## Prompt 27 integrated visual foundation

Fast deterministic gate:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
```

The focused tests run a bounded 2,400-frame composition through production
character, wardrobe, environment, interaction, and mixed-queue paths. They
assert automatic front/side behavior, body/build/hair controls, idle and
moving outfit changes, short/full/double jumps, dash, raised-platform landing,
camera/parallax, both themes, six collision-derived white surfaces, three
fixed-root handshakes, exact presentation cleanup, viewport invariance, full
reset, bounded sprites/meshes/ranges, and zero queue allocation after
stabilization.

Each handshake record includes typed ID, participant entities, preset, theme,
requested role views, start/contact/release/complete ticks, pre/post-IK socket
separation, projected production-presentation hand separation, contact views,
body/equipment ordering proof, root invariance, and finite secondary state. The
required presets are `wide_brim_crimson`,
`garnet_formal`, and `ivory_blouse_red_shorts`. A separate validated synthetic
definition selects front/front, proving that side view is handshake data
rather than a manager constant.

## Prompt 27A evidence integrity

The same focused command now discovers 18 tests. In addition to the Prompt 27
composition checks, controlled fixtures prove that every major capture
predicate accepts its valid boundary and rejects minimally and clearly invalid
state. Coverage includes view/facing/velocity, rise/apex/fall, bilateral raised
landing contact, theme invariance, interaction approach/reach/contact/release
and cleanup, complete debug categories, interrupted holds, timeout, metadata,
commit order, duplicate render observations, and bounded allocation-free HUD
submission.

Real D3D12 route:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\engine_sandbox.exe' --demo foundation --scripted-input --frames 2400
& '.\.deps\zig-0.16.0\zig.exe' build p27a-review
```

It must preload eight art pages into nine configured renderer pages, decode
eight files during initialization only, upload two persistent garment meshes,
write exactly 16 state-conditioned 640 by 480 captures and JSON records under
`zig-out/p27a_evidence/candidate`, and report zero post-stabilization update,
submission, queue, and GPU-resource growth. The ordered matrix covers initial
idle, left walk, stopped/front/left, right walk, rise, apex, fall, raised
landing, theme switch, approach, reach, first contact, release, cleanup,
detailed debug, and reset.

`p27a-review` independently parses each PPM payload, verifies SHA-256 against
both metadata and manifest, rejects duplicate payloads and missing/mismatched
cases, checks semantic and resource metrics, converts to deterministic PNG,
and writes:

- `review_manifest.json`;
- `raw_metrics.json`;
- a complete matrix sheet;
- clean/static, locomotion/jump, interaction, and detailed-debug sheets.

The current required result is 16/16 captures and at least 263 raw metrics
with zero automated failures. Run the route and review package twice, then use
`tools/compare_p27a_repeats.ps1`; all PPM, metadata, PNG, state, and metric
results must match. These checks prove evidence integrity, not aesthetic
quality. Manual visual acceptance remains `[PENDING OWNER REVIEW]`.

## Prompt 27B contact, framing, parallax, and presence

Focused semantic tests:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --global-cache-dir '.zig-cache\p27b-global'
& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --global-cache-dir '.zig-cache\p27b-global'
```

The 28 focused tests retain all Prompt 27/27A integration and evidence tests,
then add controlled valid-boundary, minimally invalid, and clearly invalid
fixtures for:

- independent left/right socket and alpha-derived sole contact;
- wrong landmark and wrong footwear pivot;
- terrain/surface/character/debug semantic ordering;
- exact and clipped camera safe bounds plus resized determinism;
- direct 960Ãƒâ€”540-to-640Ãƒâ€”480 first-frame reprojection versus subsequent
  15.999 px valid and 16.001 px invalid world-camera steps;
- measured, zero-travel, and reversed parallax;
- ordinary and interaction participant overlap;
- stopped-root invariance, bounded controller steps, and teleport rejection;
- one complete 2,400-frame production route;
- simulation-equivalent outcomes under alternate render grouping.

`p27b-coherence-report` executes the same state-conditioned production route
headlessly and writes raw TXT/JSON measurements. The preserved historical
final Prompt 27B report recorded 9,714 metrics and zero failures at its
historical source-art hashes. It is not evidence that fresh current art
passes. The VF-01 pre-change fresh-current-art run records 9,714 metrics and
24 failures: the front-foot heel/toe endpoint-height observations differ by
`-13.645128 px` and `+13.645128 px` across the affected cases. Required
thresholds and rationales remain frozen in
[`PROMPT27B_DECISION_RECORD.md`](PROMPT27B_DECISION_RECORD.md). Important
historical final-Prompt-27B ranges were:

- canonical sole error: 14 required rows, all `0 px`;
- visual sole midpoint: all `0 px`;
- heel/toe endpoint error: `0..0.03 px` and `-0.03..0 px`;
- top/bottom clearance: `16..115.30 px` and `16..80.24 px`;
- camera vertical step: `0..15.57 px/render`, required at most `16`;
- abrupt first-post resize: `960Ãƒâ€”540 -> 640Ãƒâ€”480`, headroom `37.50 px`,
  footroom `36.77 px`, instantaneous reprojection world delta `0 px`;
- ordinary participant overlap: `0`;
- semantic camera travel: `10.93 m`;
- semantic adjacent parallax separation: `304.69 px` and `483.92 px`.

The VF-02 owner-review correction preserves both historical reports and reruns
the same fresh-current-art command without rebaselining. The corrected report
contains 9,752 metrics and zero failures. The former 24 endpoint failures were
caused by an independent exact `+/-78` degree wardrobe shoe rotation after
the anatomy foot had already registered. The front anatomy foot now uses one
`point_axis` contract: the ankle is its positional target and the authored
sole axis maps to a horizontal view-space support tangent. The shoe consumes
that exact target and the registered foot's full authored transverse scale.
Closed-footwear metadata suppresses covered base-foot pixels but preserves
their trace evidence. Front sole-back and sole-front are horizontal and all
24 formerly failing endpoint-height rows measure `0.0 px`. No endpoint
threshold, ruler, source art, camera, support surface, or baseline changed.

Real D3D12 route and independent readback review:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\engine_sandbox.exe' --demo foundation --scripted-input --frames 2400
& '.\.deps\zig-0.16.0\zig.exe' build p27b-review
```

The route retains the 16 Prompt 27A state-conditioned captures and adds:

- `07_camera_resize.ppm`;
- `08_abrupt_resize_first_post_debug.ppm`;
- `10_parallax_start_debug.ppm`;
- `11_parallax_finish_debug.ppm`.

`p27b-review` independently parses the real PPM pixels and produces 12 PNG
review frames, a labeled contact sheet, and raw JSON/TXT pixel metrics. The
preserved historical report contains 55 metrics and zero failures; it is
historical integrity evidence, not a current-art pass. The abrupt-resize
readback contains complete 49-pixel top/bottom markers, projection errors of
`0.50/0.23 px`, the unchanged 16 px semantic margins, and a maximum
subsequent world-camera step of `15.566496 px`. Measured
far/mid/gameplay displacement is `30/113/246 px`; camera-factor prediction
error is `0.48/0.16/0 px`; adjacent layer separation is `83/133 px`; safe
frame, projected surface, and heel/toe evidence are within `0.5 px`.

Run the semantic report twice and the D3D12 route/review in isolated output
roots twice. The accepted repeat comparison has zero mismatches across 38
production D3D artifacts and 15 review artifacts. The pre-change SHA-256
inventory covers 314 Prompt 27/27A evidence files; the final integrity audit
reports zero missing and zero changed files. Failed Prompt 27B development
candidates remain preserved.

These automated checks and the Codex visual inspection establish the declared
geometry/evidence contract. They do not approve aesthetics or promote
goldens. Owner/manual acceptance remains `[PENDING OWNER REVIEW]`.

## Prompt 27C production anatomy

Fast source and semantic gates:

```powershell
& '.\tools\audit_anatomy_art.ps1'
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-geometry -j1
& '.\.deps\zig-0.16.0\zig.exe' build p27c-anatomy-report -j1 -- --output 'zig-out\p27c_evidence\final_semantic_report' --expect-pass
```

The source audit validates three exact-size RGBA pages, 28 nonempty component
regions, and preserved predecessor hashes. The focused gate contains 15 Zig
test declarations and 158 Prompt 27C controlled/production checks while
retaining the 6,354-check Prompt 25D pose/morphology sweep. Controlled
fixtures prove square/gapped/blob shoulders, oversized hands, overlong arms,
wrist pinches, floating/excessive pelvis transitions, knee beads, ankle gaps,
reversed feet, invalid toe-out, dark joint strips, incomplete matrices, and
nonfinite values fail.

The anatomy report runs 102 style/view/pose/morphology cases, records 2,450
production traces and 3,788 metrics, and requires zero failures. The frozen
pre-correction report under
`zig-out/p27c_evidence/pre_correction_head_3259f79` contains the same counts
and 817 failures. Two final semantic runs are byte-identical.

Real D3D12/DXIL evidence:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\engine_sandbox.exe' --demo anatomy-quality --scripted-input --frames 600
& '.\tools\build_p27c_review_package.ps1'
```

The state predicates produce eight 640Ãƒâ€”480 body-only captures covering
neutral front, side-right, side-left, low/high build, extended arm, bent
elbow, and deep knee bend. The ordinary `UnifiedRenderQueue` and SDL3 GPU
readback are used; post-initialization update, submission, queue, and GPU
resource growth are zero. The review tool validates the manifest and report,
converts deterministic PNGs, and produces before/after plus shoulder,
elbow/wrist, pelvis/hip, knee/ankle, and foot sheets. Two isolated nine-file
capture trees and two 18-file review trees are byte-identical.

Regression requirements retain:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
& '.\.deps\zig-0.16.0\zig.exe' build test -j1
& '.\.deps\zig-0.16.0\zig.exe' build check -j1
& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1
& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1
& '.\.deps\zig-0.16.0\zig.exe' build gpu-smoke -j1
```

The 28-test foundation gate keeps both incremental and direct resize
fixtures. The direct first frame remains instantaneous viewport reprojection;
subsequent world-camera movement retains the unchanged 16 px bound. All 314
historical Prompt 27/27A evidence files remain present and SHA-256 identical.
Prompt 27A, Prompt 27B, and Prompt 27C owner/manual visual acceptance remains
`[PENDING OWNER REVIEW]`; no Prompt 27C capture is an approved golden.

## Prompt 27C-R1 corrective torso and presence policy

Focused deterministic gates:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build audit-anatomy-torso -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-geometry -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
& '.\.deps\zig-0.16.0\zig.exe' build p27c-anatomy-report -j1 -- --output 'zig-out\p27c_r1_evidence\final_semantic_report' --expect-pass
```

The torso audit compares both complete production pages with the last
accepted Prompt 25A pages. It requires all 1,509 male and 1,234 female changed
pixels to remain inside four fixed shoulder rectangles and reports zero
unapproved page changes. Each torso must contain one alpha-connected
component and no transparent nonzero-RGB texel. Four controlled fixtures must
be rejected: transparent-white bilinear matte, mismatched directional mask,
detached geometry, and one outside-region pixel.

The foundation gate covers explicit `measure_only` and
`enforce_acceptance` policies. Its interactive-equivalent case approaches the
passive character, crosses the former failure point, continues through, moves
away, and submits every frame without termination. The exact `0.021407`
measurement is nonfatal but remains failed/reportable in `measure_only`; the
same measurement produces `CharacterPresenceOverlapExceeded` under
`enforce_acceptance`. Scripted production evidence and controlled invalid
fixtures remain fail-closed. Interaction context is active only while the
authoritative interaction manager has an active interaction; cancellation
and completion restore the ordinary `0.02` threshold.

Real D3D12/DXIL and review-package gates:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\engine_sandbox.exe' --demo anatomy-quality --scripted-input --frames 600
& '.\zig-out\bin\engine_sandbox.exe' --demo foundation --scripted-input --frames 2400
& '.\tools\build_p27c_r1_review_package.ps1'
& '.\zig-out\bin\engine_sandbox.exe' --demo foundation --interactive --frames 300
```

Run the anatomy and foundation routes from an isolated R1 working directory
so their relative `zig-out` paths cannot overwrite Prompt 27, Prompt 27A, or
final Prompt 27B evidence. The review package requires 8/8 body-only and
16/16 foundation captures, labels source provenance for every displayed PNG,
and includes native/enlarged torsos, both side directions, dark/light and
bilinear composites, diffs, assembled/clothed captures, and an explicit
`[PENDING OWNER REVIEW]` sheet.

The bounded real interactive executable proves startup, D3D12/DXIL
submission, and non-crashing frame completion. It is not represented as
physical keyboard/gamepad testing. Automated geometry and pixel checks do not
claim aesthetic approval.

## VF-01 visual truth debugger and capture bundles

Focused deterministic gate:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --summary all --global-cache-dir '.zig-cache\vf01-global'
```

VF-01 expands this gate to 40 tests. New coverage proves:

- F1 order and wraparound;
- F1 authoritative-state invariance and reset preservation;
- nonzero production truth categories;
- fail-closed debug-command overflow;
- one-shot F4 edges and held-key suppression;
- one frozen state across clean/debug queue generation;
- unchanged simulation tick and all state fingerprints;
- incomplete-directory hiding and timestamp/counter collision handling;
- globally monotonic indices across finalized bundles;
- valid versioned JSON and required top-level schema;
- severity-sorted summary output;
- PNG validation, manifest SHA-256 revalidation, and common fingerprint;
- no embedded NUL or dangling target identities;
- no post-stabilization queue allocations when capture is inactive; and
- deterministic, untimestamped automated evidence names.

The real D3D12/DXIL proof uses `--demo foundation --interactive` and the real
F1/F4 platform path. Synthetic Windows key messages were directed at the
isolated SDL window to make the run repeatable; this is not claimed as
physical-keyboard testing. The final evidence set is the ten globally
monotonic directories ending in `_0020` through `_0029` under
`zig-out/manual_debug_captures`. It covers five front-idle truth snapshots
(male, female, face, shoulder, and pelvis/leg inspection), female side idle,
side walk, airborne/falling, grounded after landing, and All Diagnostics.
Each directory contains exactly five required files. Independent re-read
parses every JSON file, recomputes every manifest-listed SHA-256, rejects NUL
target identities, verifies clean/debug hashes differ, and confirms
`clean_debug_state_equal=true`.

F4 evidence is diagnostic and is never promoted to a golden by this route.
At the VF-01 checkpoint, its fresh current-art Prompt 27B result was 9,714
metrics with 24 front-foot endpoint-height failures. That report is preserved
as pre-correction evidence; the later VF-02 shoe-authority result is described
below. Manual visual acceptance remains `[PENDING OWNER REVIEW]`.

## VF-02 authoritative registration

Focused structural coverage:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-registration -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
```

The registration gate covers point, segment, frame, mesh-bridge schema,
missing sources/targets, coincident endpoints, nonfinite points, reversed
endpoint roles, invalid reflection, degenerate frames, excessive residual,
proximal movement under thickness, front authority bypass, and side semantic
swaps.

The production VF-01 gate submits both styles in front, side-right, and
side-left and requires migrated records to be authoritative, have the correct
binding mode/point count, and remain at or below `0.00001 m`. It also verifies
schema version 3 authority, orientation-axis, submission-visibility, coverage
owner, and exposed-anchor fields.

`test-visual-geometry` remains the independent current-pixel ruler. A
structural registration pass does not imply that silhouette, continuity,
foot, or compatibility metrics pass. Fresh failures are retained as
current-art evidence. The initial VF-02 run passed 13/15 tests: the current
baseline reports eight failure categories, while the pose/morphology sweep
reported 116 silhouette/continuity/legacy-wardrobe findings. The later
owner-review correction does not relabel those findings and does not weaken
either ruler. Its fresh Prompt 27B report independently emits 9,752 metrics
with zero failures after removal of the second wardrobe shoe orientation
authority.

Historical real-D3D12/DXIL bundles `_0040` through `_0049` under
`zig-out/manual_debug_captures` cover male/female front, female side-right,
female side-left walk/idle, and All Diagnostics. Each contains 26
authoritative base registrations with zero structural residual failures, but
its four shoes remain `compatibility_adapter`; this set is not proof of the
owner-review shoe correction.

The final corrective proof uses `_0068` / `_0069` / `_0070` for male and
female body-only front / side-left / side-right, and `_0071` / `_0072` /
`_0073` for the corresponding equipped-foot cases. Body-only frames contain
four rendered anatomy feet and no shoes. Equipped frames contain four
authoritative rendered shoes plus four explicitly suppressed registered
base-foot evidence records. Independent validation recomputes every
manifest-listed SHA-256 and byte size, confirms clean/debug frame, tick,
state, and common-fingerprint equality, and measures zero front shoe
sole-endpoint height delta. These bundles are manual candidates and never
approved goldens.

## VF-03 typed component graph

`zig build test-component-graph` covers the compiled immutable graph, typed
socket roles/tags/capacities, selected bound visuals, eye Ã¢â€ â€™ eyebrow
child-follow, scalp Ã¢â€ â€™ hair, explicit shoulder/elbow/wrist/hand-tip arm
modules, front/side-left/side-right projection, the `0.08 m`
intentional-gap contract, and runtime topology-fingerprint compatibility.

The fail-closed fixture matrix covers unknown parent socket, invalid child
tag, socket capacity, component multiplicity, forbidden children,
self-parenting, cycles, inactive parents, duplicate component/socket IDs,
unsupported connection, invalid intentional-gap bounds, missing soft bridge,
missing module joint/end socket, unsupported front projection, child-follow
drift, and post-initialization topology mutation. Fixtures use local
definitions rather than production stable IDs.

The production visual-foundation gate verifies schema-4 graph export,
component/socket/module debug categories, one bound visual per eyebrow child,
authoritative point registration for eye/brow/hair, unchanged frozen-state
identity, and zero post-stabilization queue allocation.

VF-03-R1 adds the cross-layer invariant that an active optional module's three
declared graph visuals resolve to exactly three final production
submissions. Observable tests assert component/module ownership,
shoulderÃ¢â€ â€™elbow, elbowÃ¢â€ â€™wrist, and wristÃ¢â€ â€™hand-tip bindings, final submission
indices, nonempty visible alpha bounds, view/reflection persistence, inactive
zero-submission behavior, and fail-closed duplicate/wrong-owner/wrong-joint
fixtures. The focused totals are now `6/6` component-graph tests and `47/47`
visual-foundation tests.

Connection tests independently verify epsilon/zero continuous success,
`0.08 m` continuous rejection, `0.08 m` intentional-gap success, below
`0.07 m` and above `0.09 m` rejection, morphology-scale invariance in world
metres, and reflected direction with invariant magnitude. Capture pixels use
the exported camera:

```text
gap_px = measured_gap_m Ãƒâ€” pixels_per_meter
```

Historical `_0074Ã¢â‚¬â€œ_0082` remain unchanged. The accepted corrective
real-D3D12/DXIL bundles are:

- `_0083`: disabled front, `0` active modules and `0` submissions;
- `_0091`: continuous front, `1` module and `3` submissions;
- `_0092`: intentional-gap front, `0.08000003 m` / `6.560002 px`;
- `_0093`: continuous side-left, `3` submissions;
- `_0094`: continuous side-right, `3` submissions;
- `_0095`: intentional-gap side-left, `0.08000008 m` / `6.560007 px`;
- `_0096`: intentional-gap side-right, `0.08000003 m` / `6.560002 px`;
- `_0097`: two modules, `6` submissions with continuous and
  intentional-gap roots.

All eight accepted bundles are schema 4, JSON-parseable, manifest-complete,
SHA-256/size valid, actual `direct3d12`/DXIL, and clean/debug frame, tick,
state, and common fingerprint identical. Missing and orphan submission counts
are zero. `_0084Ã¢â‚¬â€œ_0090` are preserved invalid-JSON diagnostic candidates;
they are not completion evidence. Bundle finalization now parses generated
state and manifest JSON before rename. Manual visual acceptance is
`[PENDING OWNER REVIEW]`.

## Engine Lab World Time integration

**OWNER ACCEPTED** at `deacc4e2c6f24873df730a18fc83cc23dfa6b97b`.
Independent source/evidence review and owner visual acceptance passed. The reviewer
inspected reconstructed patches, production code, tests, logs, hashes and native
captures; the implementation owner performed the Windows/Zig/D3D12 executions.
The reviewer did not independently repeat those executions. Acceptance includes
one hub-owned WorldTime advancing from executed ticks, pause, single-step,
navigation, whole-hub reset, snapshot continuation and overflow behavior.
The accepted conservative bound is 1,950/1,984 sprites, three batches and 34 spare.
Feature-branch acceptance does not imply incorporation into master. Historical
pending-status evidence and original raw bytes remain preserved.

The [bounded integration record](implementation/engine_lab_world_time.md) documents
actual-tick composition, exact snapshots, rollover at tick 240, lifecycle and
presentation limits. Run `test-engine-lab`, `test-world`, `test-psm01` and
`test-effects-projectiles` in Debug, ReleaseSafe and ReleaseFast. New tests cover
zero/capped frame steps, pause/step/navigation/focus/reset, grouping, snapshot-copy
independence, validated fractional-carry continuation, render purity, all 160 failed
reset allocation prefixes, integer label boundaries and exhaustive production-font
bounds. Keep prior <=1,792 and <=1,856 assertions alongside the combined <=1,984
bound. Measured conservative use is 1,950 with exactly three batches.

`--verify` preserves 47 legacy and 12 calibration identities and adds eight separate
exact World Time records. `--verify-world-time-overflow` is an explicitly failing
headless fixture; it must propagate WorldDayOverflow with operation/hub-tick context
and reject continuation. The task-local `verify-overflow.py` checks that expected
nonzero exit without treating it as a passing simulation.

Route the complete native rerun to fresh evidence destinations:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 --global-cache-dir .tmp/projectile-impact/global-cache -p .tmp/projectile-impact/install -- --smoke --impact-capture-dir .tmp/engine-lab-world-time/captures/impact --calibration-capture-dir .tmp/engine-lab-world-time/captures/calibration --world-time-capture-dir .tmp/engine-lab-world-time/captures/world-time
```

Choose fresh destinations on a further rerun. The eight additional production
D3D12 readbacks cover initial/advancing time, paused tick 239, one step to tick 240,
navigation on both sides, moving LAG with live projectiles/particles and dominant
reset. Capture allocation is outside warm frames; preserve raw PPM and lossless
PNG/pixel hashes. Automated evidence and engineering inspection do not confer
independent review or owner visual acceptance of World Time. PSM01 is accepted
at the checkpoint recorded below. This feature is not incorporated into master.

## Engine Lab PSM01 calibration binding

The [bounded calibration record](implementation/engine_lab_psm01_calibration_binding.md)
defines the application-owned fixed-world-X driver, authored profile, lifecycle,
separate observation schema and presentation allowance. New integration tests
run through `test-engine-lab`; the accepted `test-psm01` and
`test-effects-projectiles` targets remain separate. Execute all three in Debug,
ReleaseSafe and ReleaseFast. `test-renderer-boundary` additionally runs CPU-only
renderer queue default/custom validation and allocation-failure cleanup tests.

The combined budget test retains the accepted 1,792 preexisting bound and measures
the calibration separately across all original saturation states and rest/both
displacement limits. Current measurements are 1,751 old + 35 new = 1,786 observed,
1,792 + 35 = 1,827 conservative, within the explicit 1,856 CPU limit. Native GPU
storage uses the existing rounded 2,048 allocation for that 1,856 request; three
batches, 2,048 queue entries and 256 mesh entries remain.

`--verify` adds a separate calibration fixture after the unchanged old fixtures.
`--smoke` compares its native checkpoints and writes nine additional readbacks.
Use `--impact-capture-dir .tmp/engine-lab-psm01-binding/captures/impact` and
`--calibration-capture-dir .tmp/engine-lab-psm01-binding/captures/calibration`
to keep earlier impact evidence intact. The existing lossless capture encoder
accepts the calibration names via `--names`; the task-local reproduction script
records their exact list. The owner has now accepted this binding at
`cfb2876c29df78f0cfa034d3df45ebe19764b141`, and independent source/evidence
review passed. The reviewer inspected patches, source, logs and captures;
Windows/Zig/D3D12 tests were executed by the implementation owner, not independently
reexecuted by the reviewer. Original manifests retain historical pending status.
The accepted conservative bound is 1,827/1,856, three batches and 29 sprites of
headroom. Acceptance is on the feature branch and implies no incorporation into
master. The earlier projectile checkpoint stays accepted; EL1 remains closed.

## Engine Lab EL1

The [projectile-impact integration](implementation/engine_lab_projectile_impact.md)
and its [eight-shot follow-up](implementation/engine_lab_multi_projectile_follow_up.md)
add geometry, composition and lifecycle tests to `test-engine-lab`, preserving
all 16 EL1 tests. Run `test-engine-lab` and `test-effects-projectiles` in Debug,
ReleaseSafe and ReleaseFast. The optional bridge RGB path has independent
validation/default-appearance tests; it changes no projectile/effect core format.

`run-engine-lab -- --verify` retains the 1,440-tick EL1 and 936-tick single-shot
fixtures and adds a separate 888-tick, 16-shot fixture. Local integration hashes
are `engine_lab.projectile_impact.observations.v2`, covering color derivation
context, authored palette, successful-shot ordinal, copied tags and particle RGB
in addition to prior public observations. Original EL1 v2 fingerprints and
historical integration-v1 evidence remain unchanged; this is not replay/save state.

`run-engine-lab -- --smoke --impact-capture-dir .tmp/projectile-impact-follow-up/captures`
retains the original smoke and adds multiple flights, overlapping matching
impacts, capacity reuse, paused contact/next-tick birth ages, and multi-flight
plus live-particle reset coverage. The optional destination only controls
explicit offline capture writes. The follow-up directory is the new default;
original captures under `.tmp/projectile-impact/captures` are preserved.

Encode the eight new readbacks with:

```powershell
python tools/engine_lab_impact_review.py --capture-dir .tmp/projectile-impact-follow-up/captures --names multi-flight overlapping replacement paused single-step-contact single-step-next old-particles-drained multi-reset
python tools/engine_lab_impact_review.py --capture-dir .tmp/projectile-impact-follow-up/captures/single
```

The projectile-impact checkpoint, including eight-shot/color visuals and the
corrected 1,792/1,792 conservative glyph bound, is owner accepted at
`6e4f7c2aadf24c2336ab3cba2d60ff127e750e0e`; independent source/evidence
review was also reported as passing. Acceptance applies to the integration
branch and does not claim incorporation into master. E/gamepad west
fires on fresh presses while capacity is available; holds never repeat. The
follow-up record gives exact bounds, tick order, command ledger and review ZIP.

`zig build engine-lab -j1` builds/installs the independent persistent hub without
building the sandbox. The retained 16 EL1 headless tests cover
actual controller movement/collision, concurrent station state, destination travel,
reset, frame-schedule checkpoints, input suppression, rendering extraction and
allocation/lifetime safety. These also run in `test`, `check` and `verify`;
`check` compiles the independent executable.

`zig build run-engine-lab -j1 -- --verify` runs the actual hub for 1440 fixed ticks
under 60 Hz and mixed frame schedules, using the same bounded movement/jump fixture.
Both stations must be reached, continue updating, and match logical checkpoints.
This is test input, with no general recording, replay or restore format.
`zig build run-engine-lab -j1 -- --smoke` checks 180 native D3D12 frames, production
actor movement/jump/collision, two destination shortcuts, pause/step/reset, pixel
readback, allocation counters and balanced resources/fences.

For interactive review, run `zig build run-engine-lab -j1`. A/D or arrows move;
Space jumps (gamepad stick/south are also mapped). Walk to the central raised
platform, jump across it, and reach the second installation. Confirm camera
tracking, facing and animation. F1/F2 move the same actor to station destinations;
P pauses/resumes, T advances one paused tick, R reconstructs the complete seeded
hub, F3 toggles diagnostics, and Escape exits. Both station states remain live
through ordinary movement and destination travel. Review the exact evidence and
owner-confirmed visual/architectural acceptance and retained milestone-time
limitations in the [EL1 report](implementation/engine_lab_el1.md). EL1 is accepted;
this does not authorize later EL2 work.


## Engine Lab traversal expansion

The [bounded traversal record](implementation/engine_lab_traversal_expansion.md)
separates the explicit legacy room from normal expanded construction. Retain all
legacy expected identities and budgets. The expanded tests execute production
movement, all three named routes, input/lifecycle, initialization/reset failure
prefixes, camera/viewport bounds, render purity and full presentation saturation.
Run `test-engine-lab`, `test-world`, `test-psm01`, `test-effects-projectiles` and
`test-camera` in Debug, ReleaseSafe and ReleaseFast. Focus the additive shared API
and retained equipment consumers with `test-deterministic -Dtest-filter=character_properties_tests`.
Then run `check`, `test-full`, default/Engine Lab builds in all modes, physical
`gpu-smoke`, Engine Lab `--verify` and `--smoke`, and the expected-failure
`--verify-world-time-overflow` wrapper. Use `-j1` and the established caches/install.
Supply all four fresh capture directories: `--impact-capture-dir`,
`--calibration-capture-dir`, `--world-time-capture-dir`, `--traversal-capture-dir`.
The traversal reproduction script chooses a fresh directory and verifies PNGs.
Automated route and native evidence do not grant owner acceptance. The owner has
now explicitly accepted traversal and corrected zoom, following independent
source/evidence review and the final-source Windows validation recorded in the
implementation record. World Time acceptance is unchanged.

### Engine Lab F4 zoom follow-up

Run `test-engine-lab test-camera` for zoom input/reset, resize, unchanged route
checkpoints, fixed-size HUD and presentation budgets across all three scales.
Build `engine-lab` and run its native `--smoke` with all four capture directories
pointing into a fresh `.tmp/engine-lab-zoom-window` subdirectory. The four added zoom
captures show current, 2x-out, 4x-out and R-reset views. Manually press F4 repeatedly,
resize while zoomed out, navigate, and press R; the original zoom must return.

The window-framing regression first reproduces the renderer's acquired-drawable
refresh and verifies that the published zoom survives it. Every control/time glyph
and the status anchor are checked across three scales, five actor positions, both
diagnostic modes and four viewport sizes, including 1920x1080. All HUD glyph bounds
must stay inside the frame. Native traversal cycles zoom while following real
routes and checks the camera uniform, all three HUD sections and all four corners
of each of the 15 player sprites after actual window submission. Captures then use
that submitted camera without replacing it. A direct offscreen capture alone does
not verify the window refresh path. Because the fix adds an opt-in shared camera
scale, also run `test-renderer-boundary`, `check` and the default `gpu-smoke`.

## Engine Lab collectible validation

The [bounded collectible record](implementation/engine_lab_collectibles.md) separates
physical two-run reachability from staged lifecycle/saturation fixtures. New tests
cover exact birth/reaction/effect ages, resolved axis queries, C/north edges, pause,
focus, navigation, candidate reset, ownership, purity and the combined sprite bound.
`test-engine-lab` includes them automatically; `-Dengine-lab-test-filter=collectible`
is a development aid and must be omitted for final complete acceptance.

The required final roots are `test-engine-lab`, `test-deterministic`, `test-camera`
and `test-renderer-boundary` in Debug/ReleaseSafe/ReleaseFast, then `check` and
`test-full`, both applications in all modes, `gpu-smoke`, `--verify` and `--smoke`.
Use `--collectible-capture-dir` along with all four preexisting capture directory
options to preserve old evidence. The new `--verify-collection-overflow` deliberately
returns `Overflow` after proving fatal partial-tick rejection and reset repair;
`--verify-world-time-overflow` retains its expected failure contract.

Native collection captures test the actual submitted window camera and new HUD/arrow
geometry, including real window sizes at 640x480, 960x720 and 1280x720 across all
zooms. PNG encoding must match raw PPM RGB and reported native RGBA hashes. Capture
allocation is distinct from zero steady-state simulation/extraction allocation.
The owner has accepted pickups, reset, indicators and the overall experience;
no physical gamepad model or detailed manual transcript was supplied. Independent
package review and the implementation session's automated results are distinct
facts, recorded in the collectible implementation record. Original task evidence
remains under `.tmp/engine-lab-collectibles/`; the shared capacity guard correction
is a separate bounded follow-up.

### Shared debug-capacity guard follow-up

For the compile-time guard correction, run `test-engine-lab` and
`test-integration` without filters in Debug, ReleaseSafe and ReleaseFast, then
`check` and one `engine-lab -Doptimize=Debug` build. This bounded follow-up does
not require rerunning the collectible product matrix above. The integration
root owns the small-buffer order/overflow regression; maximum supported capacity
is checked as a type, not a large Windows stack value.

Run `python -B tools/checks/debug_capacity.py --output <new-evidence-directory>
--optimize Debug` (also ReleaseSafe and ReleaseFast). The runner requires pinned
Zig 0.16.0, compiles the production generic with valid 1/3/2048/2304/65535 and
rejects 0/65536 only when the intended capacity diagnostic is the sole compiler
error. `results.json` separates compiler exit 1 for expected negatives from
runner success; raw compiler logs are retained. Use a fresh output directory
per invocation, while retaining the existing shared build caches.
