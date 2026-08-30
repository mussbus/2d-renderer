# F4B2 — Superseded Demo and Regression Retirement

**Status:** F4B2 implementation candidate — awaiting owner review

**Date:** 2026-08-29

**Starting commit:** `b7790698290d83edd367b54222020898d49803c5`

## 1. Authority and boundary

This record applies the owner-authorized F4B2 retention review to the thirteen
F4A candidates. It preserves production capability and permanent regression
coverage while removing only historical scenario shells whose useful behavior
is already covered through production-facing tests. F4B2 does not extract
production definitions, split `GpuDemo` or `CharacterInstance`, redesign the
renderer or build, change canonical authority, archive evidence, rename assets,
or begin F4C, F4D, F4E, or downstream feature work.

The starting gate was satisfied on synchronized `master`: HEAD and upstream
were both `b7790698290d83edd367b54222020898d49803c5`, ahead/behind was `0 0`,
the worktree was clean, Zig reported exactly `0.16.0`, F4B1 was committed and
published, and `docs/project/REPOSITORY_RETENTION.md` existed.

## 2. Pre-retirement candidate matrix

This matrix was completed before executable/build/test retirement edits.

| Candidate | F4A recommendation | Production-logic finding | Regression finding | Final F4B2 disposition |
|---|---|---|---|---|
| `humanoid` | Replace with focused test | No scenario module; a `GpuDemo` branch composes production humanoid, pose, socket, attachment, and batch APIs | Permanent skeleton/pose tests cover every useful invariant | **RETIRED** |
| `animation` | Replace with focused test | No scenario module; a `GpuDemo` branch composes production clip/animator/state-machine APIs | Permanent animation tests cover sampling, transitions, events, determinism, and allocation | **RETIRED** |
| `secondary_motion` | Replace with integration test | No scenario module; a second mode over the protected controller route enables production procedural motion | Permanent secondary-motion tests cover springs, controller equivalence, replay, reset, and allocation | **RETIRED** |
| `multi_character` | Replace with integration test | `multi_character_demo.Scene` is a historical script shell; no production consumer uses it | Seventeen production-facing tests retain identity, isolation, ordering, reflection, reset, physics, and batching; one redundant shell test is removed | **RETIRED** |
| `handshake` | Replace with integration test | `handshake_demo.Scene` is a historical script shell; production coordination is in `interaction_system` | Permanent interaction tests retain transactionality, ownership, clocking, cleanup, events, ordering, and physics independence | **RETIRED** |
| `handshake_ik` | Replace with integration test | `handshake_ik_demo.Scene` remains an active fixture consumed by a permanent presentation regression | IK coverage is extensive, but presentation ownership/cancellation still imports this fixture and replacing it cleanly would recreate orchestration or require later extraction | **RETAINED — COVERAGE GAP** |
| `foot_planting` | Replace with integration test | `foot_planting_demo.Scene` is a historical script shell; production ground query, foot state, and leg IK are separate | Twenty-three production-facing tests retain all useful contact, IK, determinism, reset, coexistence, and physics invariants; one redundant shell test is removed | **RETIRED** |
| `integrated` | Replace with integration test | `integrated_demo.Scene` is the current end-to-end composition and reset/diagnostic fixture | All nine integration tests, the stress test, and shared integration support consume it | **RETAINED — UNIQUE DEBUGGING/ACCEPTANCE VALUE** |
| `properties` | Replace with integration test | `character_properties_demo.Scene` is a historical script/evidence shell; property production APIs are separate | Seven production-facing tests retain validation, resolution, capability, equipment, controller, collision, and allocation behavior | **RETIRED** |
| `breathing` | Replace with integration test | `breathing_demo.Scene` is a historical script/evidence shell; production deformation APIs are separate | Eight production-facing tests retain breathing/deformation composition, isolation, authority, determinism, and allocation | **RETIRED** |
| `attachment_secondary` | Replace with integration test | No separate source; a second mode over protected `mesh_attachment_demo.Scene` | Permanent attachment-secondary tests and the protected `mesh_attachments` route retain integration and visual debugging | **RETIRED** |
| `art_assets` | Replace with integration test | `art_asset_demo` owns the concrete page/region/binding definition and scene used throughout art pipeline tests | Removing it would require extracting or recreating active definitions, prohibited in F4B2 | **RETAINED — PRODUCTION EXTRACTION REQUIRED IN F4C** |
| `character_presentation` | Replace with integration test | `character_presentation_demo.Scene` is a historical script/evidence shell; presentation and art production APIs are separate | Fifteen permanent tests retain policy, views, layers, interaction cleanup, spring reset, input, and bounded submission | **RETIRED** |

## 3. Candidate retirement manifests

### 3.1 `humanoid`

1. **What it is:** a `DemoMode`/CLI branch inside `GpuDemo`; there is no
   `humanoid_demo.zig`.
2. **References:** `main.zig` parsing/help and `GpuDemo` initialization,
   update/submission, and terminal evidence reporting.
3. **Production behavior:** none owned by the branch. It consumes
   `humanoid.DemoCharacter`, production pose/socket evaluation, and the shared
   sprite batch; those modules remain because the protected controller route
   uses them.
4. **Unique regression coverage:** none after the permanent skeleton suite.
5. **Authoritative source:** no; immutable skeleton/attachment definitions are
   owned by production modules.
6. **Hash/version sensitivity:** none specific to the scenario.
7. **Reproducibility:** its meaningful construction and hierarchy results are
   deterministically reproduced headlessly.
8. **Replacement:** `skeleton_tests`: `valid humanoid definition has stable
   semantics sockets order and no per-bone allocation`, `rest pose hierarchy
   and sockets match independent world positions`, `attachments follow
   hierarchy preserve pivots layers page and pose immutability`, and `pose
   socket and attachment submission allocate zero bytes after initialization`.
9. **Provenance:** Prompt-era documentation and reports remain tracked; this
   F4B2 record maps the retired route to its surviving tests.
10. **Authorization:** owner-authorized F4B2 request plus the F4A `REPLACE WITH
    FOCUSED TEST` decision.

### 3.2 `animation`

1. **What it is:** a `DemoMode`/CLI branch inside `GpuDemo`; no standalone
   scenario file exists.
2. **References:** `main.zig` and `GpuDemo`; production animation modules are
   also used by protected routes.
3. **Production behavior:** none owned by the branch.
4. **Unique regression coverage:** none beyond permanent clip, animator, and
   state-machine tests.
5. **Authoritative source:** no; authored clips and animation APIs remain.
6. **Hash/version sensitivity:** none specific to the scenario.
7. **Reproducibility:** exact fixed-tick sampling and transitions are headless.
8. **Replacement:** `animation_tests`: `component sampling has explicit
   boundaries modes shortest rotation and source preservation`, `loop advance
   and event traversal cover exact boundaries multiple wraps capacity and speed
   policy`, `animator transitions events interruption policy one-shot fallback
   replay and independent players`, and `animation initialization fault stages
   clean transactionally and steady updates allocate zero`.
9. **Provenance:** historical prompt documentation/reports remain.
10. **Authorization:** owner-authorized F4B2 request and F4A focused-test
    disposition.

### 3.3 `secondary_motion`

1. **What it is:** a mode-specific scripted branch over the protected
   controller/humanoid/animation composition; no separate scenario source.
2. **References:** `main.zig` and `GpuDemo`; production spring/procedural modules
   and protected controller fixtures survive.
3. **Production behavior:** none owned by this mode branch.
4. **Unique regression coverage:** none; the focused suite includes controller
   comparison and render-grouping integration.
5. **Authoritative source:** no.
6. **Hash/version sensitivity:** none specific to the route.
7. **Reproducibility:** fixed-tick responses and reset replay are deterministic.
8. **Replacement:** `secondary_motion_tests`: `hard landing has greater bounded
   compression than moderate landing`, `secondary head lag follows acceleration
   direction and remains bounded`, `fixed ticks are deterministic across small
   large and mixed render groupings`, `procedural enabled and disabled controller
   replays preserve authoritative physics`, and `procedural hot paths report zero
   allocations`.
9. **Provenance:** historical Prompt 6 records remain.
10. **Authorization:** owner-authorized F4B2 request and F4A integration-test
    disposition.

### 3.4 `multi_character`

1. **What it is:** `src/scene/multi_character_demo.zig`, its mode, and scripted
   global-submission evidence shell.
2. **References:** `GpuDemo`, `build.zig`, repository shape checks, and one final
   test in `tests/multi_character_tests.zig`; no other demo imports it.
3. **Production behavior:** none. Stable entity identity, character-local state,
   reflection, overrides, and global submission live in production modules.
4. **Unique regression coverage:** the final full-script test duplicates the
   preceding seventeen production-facing tests and adds only historical phase
   completion.
5. **Authoritative source:** no.
6. **Hash/version sensitivity:** none.
7. **Reproducibility:** all continuing invariants are reproduced directly from
   production APIs.
8. **Replacement:** `multi_character_tests`: `characters share immutable
   definitions while pose animator and procedural state stay independent`,
   `four adversarial character states remain isolated when one character
   resets`, `global actor ordering is reversible stable and interleaves
   equal-layer characters`, `two page-zero characters produce one range exact
   count and no character-specific batch`, and `passive second character
   preserves the controlled scripted physics result`.
9. **Provenance:** historical docs remain; this record captures file, consumer,
   and replacement mappings.
10. **Authorization:** owner-authorized F4B2 request and F4A integration-test
    disposition.

### 3.5 `handshake`

1. **What it is:** `src/scene/handshake_demo.zig` and a scripted non-IK mode.
2. **References:** `GpuDemo`, `build.zig`, and repository shape checks; no
   permanent test imports the demo.
3. **Production behavior:** none; definitions and coordination remain in
   `interaction.zig`, `handshake.zig`, and `interaction_system.zig`.
4. **Unique regression coverage:** none. Non-IK behavior protects distinct
   lifecycle/transaction invariants already covered by interaction tests.
5. **Authoritative source:** no.
6. **Hash/version sensitivity:** none.
7. **Reproducibility:** direct fixed-tick manager tests are deterministic.
8. **Replacement:** `interaction_tests`: `paired runtime starts samples and
   completes from one shared tick clock`, `transactional start rolls back every
   reservation and animator fault stage`, `cancellation before and after contact
   restores only owned state and is idempotent`, `zero one and multi-substep
   render schedules produce identical paired results`, and `interaction sampling
   and socket measurement leave authoritative controller physics unchanged`.
9. **Provenance:** historical Prompt 8 records remain.
10. **Authorization:** owner-authorized F4B2 request and F4A integration-test
    disposition.

### 3.6 `handshake_ik`

1. **What it is:** `src/scene/handshake_ik_demo.zig` and the scripted paired-IK
   route.
2. **References:** `GpuDemo`, `build.zig`, repository checks, and
   `character_presentation_tests.zig` through `handshake_ik_demo.Scene`.
3. **Production behavior:** the solver and manager are production-owned, but the
   demo still owns active two-character orchestration used as a test fixture.
4. **Unique regression coverage:** the IK suite covers solver and interaction
   behavior, while the presentation suite still depends on this exact fixture
   for side-view ownership and cancellation cleanup.
5. **Authoritative source:** not canonical, but it is an active regression
   fixture.
6. **Hash/version sensitivity:** none.
7. **Reproducibility:** possible only by duplicating fixture orchestration in a
   test or extracting it; neither is warranted in F4B2.
8. **Replacement:** no clean demo-independent replacement exists yet. Existing
   `ik_tests` provide broad coverage but do not remove the presentation import.
9. **Provenance:** source and route remain live.
10. **Authorization:** F4B2 expressly requires retaining a candidate when
    migration would cross into extraction or a hidden demo.

### 3.7 `foot_planting`

1. **What it is:** `src/scene/foot_planting_demo.zig` and its scripted route.
2. **References:** `GpuDemo`, `build.zig`, repository checks, and one final
   scripted-shell test.
3. **Production behavior:** none; collision queries, state, bindings, and leg IK
   remain in production modules.
4. **Unique regression coverage:** the shell test adds timeline completion but
   no invariant absent from the twenty-three direct tests.
5. **Authoritative source:** no.
6. **Hash/version sensitivity:** none.
7. **Reproducibility:** direct tests cover floor/platform acquisition, release,
   IK quality, render schedules, reset, and coexistence.
8. **Replacement:** `foot_planting_tests`: `contact event and valid ground
   acquires gradually while transition start cannot snap`, `planted target stays
   world fixed repeated contact does not drift and slip is reduced`, `foot
   planting preserves controller root velocity collision timing and animator
   clocks through jump and landing`, `plant acquisition release targets slip
   states and weights are invariant across render schedules`, and `handshake
   lifecycle arm IK and character local foot locks coexist without timeline or
   ownership coupling`.
9. **Provenance:** historical Prompt 10 material remains.
10. **Authorization:** owner-authorized F4B2 request and F4A integration-test
    disposition.

### 3.8 `integrated`

1. **What it is:** the current `integrated_demo.Scene` end-to-end character,
   physics, interaction, IK, foot-planting, diagnostics, reset, and debug fixture.
2. **References:** `GpuDemo`, `build.zig`, `integration_tests.zig`,
   `integration_test_support.zig`, and `stress_tests.zig`.
3. **Production behavior:** it owns current application composition used by
   active acceptance and test orchestration.
4. **Unique regression coverage:** yes; production-order coexistence, whole-scene
   reset, render-group determinism, diagnostics invariance, and 100,000-tick
   stability.
5. **Authoritative source:** current integration fixture, though not canonical
   content authority.
6. **Hash/version sensitivity:** no canonical hash; behavior is regression
   sensitive.
7. **Reproducibility:** not without moving/recreating composition, which is F4C.
8. **Replacement:** none inside F4B2; active integration/stress tests retain it.
9. **Provenance:** live source, route, tests, and historical records remain.
10. **Authorization:** F4B2 production-logic and unique-value gates require
    retention.

### 3.9 `properties`

1. **What it is:** `src/scene/character_properties_demo.zig` and a finite
   scripted evidence route.
2. **References:** `GpuDemo`, `build.zig`, and repository checks; no test imports
   the demo.
3. **Production behavior:** none; definitions/resolution and controller
   integration are production-owned.
4. **Unique regression coverage:** none after the seven direct tests.
5. **Authoritative source:** no; it consumes protected equipment definitions.
6. **Hash/version sensitivity:** none.
7. **Reproducibility:** direct property/controller tests are deterministic.
8. **Replacement:** `character_properties_tests`: `resolution uses deterministic
   additive then multiplicative stacking and clamps bounds`, `equipment lifecycle
   resolves modifiers grants replacement reset and appearance-independent state`,
   `resolved equipment properties drive movement jump double jump and dash
   through the controller`, `dash collides with walls and default resolved
   controller path is regression-equivalent`, and `property resolution performs
   no allocation growth`.
9. **Provenance:** historical Prompt 21 docs/reports remain.
10. **Authorization:** owner-authorized F4B2 request and F4A integration-test
    disposition.

### 3.10 `breathing`

1. **What it is:** `src/scene/breathing_demo.zig` and a bounded visual/evidence
   route.
2. **References:** `GpuDemo`, `build.zig`, and repository checks; permanent tests
   use production deformation APIs and protected definition fixtures instead.
3. **Production behavior:** none owned by the scenario.
4. **Unique regression coverage:** none after the deformation suite.
5. **Authoritative source:** no.
6. **Hash/version sensitivity:** none.
7. **Reproducibility:** fixed-tick breathing and deformation layering are
   deterministic and headless.
8. **Replacement:** all eight `deformation_tests`, especially `resolved
   deformation composes global morphology breathing and per visual response
   once`, `breathing and morph changes preserve physics controller canonical IK
   and declared effects`, `fixed tick breathing is deterministic across render
   frame grouping`, and `steady state breathing morphing and loadout changes do
   not grow character storage`.
9. **Provenance:** historical Prompt 18 docs/reports remain.
10. **Authorization:** owner-authorized F4B2 request and F4A integration-test
    disposition.

### 3.11 `attachment_secondary`

1. **What it is:** a second `DemoMode` and reporting branch over the protected
   `mesh_attachment_demo.Scene`; it has no standalone source.
2. **References:** `main.zig`, `GpuDemo`, docs, and no unique build module.
3. **Production behavior:** none owned by the alias; attachment-secondary state
   and protected mesh composition survive.
4. **Unique regression coverage:** none beyond direct tests and the retained
   `mesh_attachments` route.
5. **Authoritative source:** no.
6. **Hash/version sensitivity:** none specific to the alias.
7. **Reproducibility:** permanent tests cover deterministic lifecycle,
   cross-character isolation, rendering integration, and authority invariance.
8. **Replacement:** `attachment_secondary_motion_tests`: `rest acceleration
   sustained reversal stop jump fall landing facing and reset are deterministic`,
   `equipment and hair instances own lifecycle state independently and preserve
   grouped rendering`, `visual secondary motion leaves controller physics and
   interaction authority invariant`, plus the surviving protected
   `mesh_attachments` visual route.
9. **Provenance:** historical Prompt 20 docs/reports remain.
10. **Authorization:** owner-authorized F4B2 request and F4A integration-test
    disposition.

### 3.12 `art_assets`

1. **What it is:** `src/scene/art_asset_demo.zig`, a concrete art definition and
   focused scene that exercises sprite/mesh pages.
2. **References:** `GpuDemo`, `build.zig`, repository checks,
   `art_pipeline_tests.zig`, `ART_PIPELINE.md`, and historical records.
3. **Production behavior:** it owns `page_inputs`, `region_inputs`,
   `binding_inputs`, `definitionInput`, semantic IDs, and `Scene` used by active
   tests.
4. **Unique regression coverage:** yes; the art suite consumes the concrete
   definitions for lookup, reordering, rejection, fault, and bounded submission.
5. **Authoritative source:** active definition/test-fixture source, though not a
   canonical human authority.
6. **Hash/version sensitivity:** semantic mapping and declaration-order behavior
   are exact regression inputs; assets and historical evidence remain retained.
7. **Reproducibility:** removing the module requires extracting or duplicating
   its definitions, prohibited by F4B2.
8. **Replacement:** none within F4B2; `art_pipeline_tests` and image decode tests
   continue to consume it, with GPU behavior covered by surviving routes.
9. **Provenance:** live source, assets, tests, docs, and reports remain.
10. **Authorization:** the F4B2 production-logic gate requires `BLOCKED FOR F4C
    EXTRACTION` rather than forced deletion.

### 3.13 `character_presentation`

1. **What it is:** `src/scene/character_presentation_demo.zig` and
   scripted/interactive evidence routes.
2. **References:** `GpuDemo`, `main.zig`, `build.zig`, repository checks, current
   user docs, and historical records; no permanent test imports the demo.
3. **Production behavior:** none owned by the scene. Presentation policy,
   projection, art mapping, character state, and unified queue remain.
4. **Unique regression coverage:** none after the fifteen direct tests.
5. **Authoritative source:** no.
6. **Hash/version sensitivity:** production asset bindings remain untouched; the
   scenario itself has no canonical hash authority.
7. **Reproducibility:** direct tests cover both views, policy, layering, cleanup,
   state isolation, input, and bounded queue submission.
8. **Replacement:** `character_presentation_tests`: `automatic presentation
   policy is authoritative and complete`, `facing is preserved across view
   changes and reset restores automatic front`, `interaction owns side view and
   cancellation releases both participants to front`, `view transition clears
   long-hair spring state without allocation or cross-character mutation`, and
   `Q input cycles presentation only and art submission remains bounded in both
   views`.
9. **Provenance:** Prompt 24 documentation/reports and assets remain; this record
   captures the retirement.
10. **Authorization:** owner-authorized F4B2 request and F4A integration-test
    disposition.

## 4. Planned retirement delta

Ten runnable modes are selected for retirement: `humanoid`, `animation`,
`secondary_motion`, `multi_character`, `handshake`, `foot_planting`,
`properties`, `breathing`, `attachment_secondary`, and
`character_presentation`. Six scenario source files are selected for deletion:

- `src/scene/multi_character_demo.zig`
- `src/scene/handshake_demo.zig`
- `src/scene/foot_planting_demo.zig`
- `src/scene/character_properties_demo.zig`
- `src/scene/breathing_demo.zig`
- `src/scene/character_presentation_demo.zig`

The redundant final scripted-shell tests in `multi_character_tests.zig` and
`foot_planting_tests.zig` are selected for deletion. No test root, asset,
historical evidence file, canonical content, or production definition is
selected for removal. `handshake_ik`, `integrated`, `art_assets`, every
explicitly protected route, and all three report executables remain.

## 5. Implementation and validation results

### 5.1 Exact retirement

Retired runnable modes:

- `humanoid`
- `animation`
- `secondary_motion` (`secondary-motion` on the CLI)
- `multi_character` (`multi-character`)
- `handshake`
- `foot_planting` (`foot-planting`)
- `properties`
- `breathing`
- `attachment_secondary` (`attachment-secondary`)
- `character_presentation` (`character-presentation`)

Deleted source files:

- `src/scene/multi_character_demo.zig`
- `src/scene/handshake_demo.zig`
- `src/scene/foot_planting_demo.zig`
- `src/scene/character_properties_demo.zig`
- `src/scene/breathing_demo.zig`
- `src/scene/character_presentation_demo.zig`

Retained candidates:

- `handshake_ik`: retained because
  `character_presentation_tests.zig` still consumes `handshake_ik_demo.Scene`.
- `integrated`: retained because integration tests, stress tests, and shared
  integration support consume its current application composition.
- `art_assets`: retained because `art_asset_demo` owns concrete page, region,
  binding, definition, and scene fixtures consumed throughout the art tests;
  production/test-fixture extraction belongs to F4C.

### 5.2 Tests

No test was added. Two test files were narrowed:

- `tests/multi_character_tests.zig` no longer imports the deleted demo and no
  longer contains `multi-character scene runs all deterministic phases with
  steady fixed storage`.
- `tests/foot_planting_tests.zig` no longer imports the deleted demo and no
  longer contains `scripted foot planting demonstration deterministically
  crosses floor jump landing and raised platform`.

Both deleted tests exercised the historical script shell after the same useful
identity/isolation/ordering/batching or contact/IK/physics/determinism
invariants had already been asserted through direct production APIs. The
required permanent-test mapping is recorded in Sections 2 and 3. No test root
was removed, and no meaningful production regression was weakened.

### 5.3 Application, build, and checker changes

`GpuDemo` changes are limited to removing imports, enum entries, initialization,
state, update/submission branches, reporting, and scenario-only metrics for the
ten retired modes. The protected controller route still initializes the same
humanoid and animation runtimes. The protected `mesh_attachments` route still
owns the shared mesh scene and GPU path after the duplicate alias was removed.
No lifecycle, renderer, resource, backend, or evidence framework was
restructured.

`main.zig` removes only retired CLI names, supported-mode help text, and
scenario-specific input/frame checks. It does not add a registry, application
layer, or second executable.

`build.zig` removes only the six deleted modules, their imports, and now-unused
test-root imports. No build target was renamed, no root build modularization
occurred, and no retained test or report registration was removed.

`tools/check_repository.ps1` removes six deleted-source reads and exact
demo-shell/evidence/build-wiring assertions. Production-facing Prompt 3/4/6/7/
8/10/18/21/24 invariants and permanent-test assertions remain. The checker was
not split or redesigned; its post-change audit passes for 252 first-party
source files.

Scenario-only runtime evidence/reporting branches embedded in the deleted
scenes and `GpuDemo` were removed. No historical evidence artifact, accepted
golden, capture image, report, or canonical evidence was deleted or modified.

### 5.4 Files

Created:

- `docs/implementation/f4b2_superseded_demo_retirement.md`

Modified:

- `README.md`
- `build.zig`
- `docs/ANIMATION.md`
- `docs/ART_PIPELINE.md`
- `docs/ATTACHMENT_SECONDARY_MOTION.md`
- `docs/CHARACTER_PRESENTATION.md`
- `docs/CHARACTER_PROPERTIES.md`
- `docs/CONTROLS.md`
- `docs/DEFORMATION.md`
- `docs/FOOT_PLANTING.md`
- `docs/HUMANOID.md`
- `docs/INTERACTIONS.md`
- `docs/MESH_ATTACHMENTS.md`
- `docs/MULTI_CHARACTER.md`
- `docs/SECONDARY_MOTION.md`
- `docs/TESTING.md`
- `docs/project/CURRENT_STATE.md`
- `docs/project/MASTER_ROADMAP.md`
- `src/graphics/gpu_demo.zig`
- `src/main.zig`
- `tests/foot_planting_tests.zig`
- `tests/multi_character_tests.zig`
- `tools/check_repository.ps1`

Deleted: the six source files listed in Section 5.1.

### 5.5 Assets and provenance

No asset was deleted, renamed, or modified. No canonical data, topology, hash,
version, golden, evidence file, capture bundle, or report executable changed.
Historical Prompt-era documentation remains. Current user-facing docs now mark
the ten removed routes as retired, name their permanent tests, and retain only
commands that still resolve.

### 5.6 Before/after maintenance metrics

| Measure | Before F4B2 | F4B2 candidate | Delta |
|---|---:|---:|---:|
| Runnable `DemoMode` entries | 25 | 15 | -10 |
| `src/scene/*_demo.zig` files | 16 | 10 | -6 |
| Repository source-audit files | 258 | 252 | -6 |
| `GpuDemo` lines | 5,848 | 4,709 | -1,139 |
| `GpuDemo` bytes | 328,516 | 255,076 | -73,440 |
| `main.zig` lines | 225 | 203 | -22 |
| `main.zig` bytes | 13,045 | 10,982 | -2,063 |
| `build.zig` lines | 2,368 | 2,271 | -97 |
| `build.zig` bytes | 128,417 | 122,048 | -6,369 |
| Test roots | 62 | 62 | 0 |
| Top-level Zig test declarations | 631 | 629 | -2 redundant shells |
| `check` aggregate tests | 518 | 516 | -2 redundant shells |
| `test-full` aggregate tests | 629 | 627 | -2 redundant shells |
| Candidate tracked files after commit | 897 | 892 | -5 net (six deletions, one record) |

The isolated host-cache normal build reported a 29-second executable compile.
Observed aggregate wall time was approximately five minutes for `check` and
approximately five to six minutes for `test-full`, dominated by the unchanged
canonical geometry suites. GPU smoke reported a 28-second executable compile
and 10-second D3D12 run. Approval/sandbox orchestration wait is excluded from
these informational timings.

### 5.7 Validation

| Gate | Result |
|---|---|
| Zig version | PASS: exactly `0.16.0` |
| Baseline Git gate | PASS: clean synchronized `master`, HEAD/upstream `b7790698290d83edd367b54222020898d49803c5`, ahead/behind `0 0` |
| Retired filename/basename/mode/CLI executable scans | PASS: zero live source, test, build, or checker import/registration for the retired artifacts |
| `tools/check_repository.ps1` | PASS: 252 files, no unfinished/skipped markers, production audits retained |
| `zig build` | PASS: 20/20 steps |
| `zig build check` | PASS: 53/53 steps, 516/516 tests |
| `zig build test-full` | PASS: 60/60 steps, 627/627 tests |
| `zig build gpu-smoke` | PASS: 22/22 steps; physical `direct3d12`, DXIL, one two-instance indexed-instanced draw, readback matched within tolerance 1 |
| `tools/check_documentation.ps1` | PASS: 46 required files, 42 Markdown files, 104 local targets |
| Zig formatting | PASS |
| Diff/hygiene checks | PASS: no whitespace error, new TODO/FIXME/placeholder, or disabled/skipped test |

Two initial sandboxed normal-build attempts failed before compilation because
Zig could not create a Windows cache manifest (`manifest_create AccessDenied`).
The required build/check/test-full/GPU gates were rerun with repository-local
isolated host caches and returned exit code zero; no failed cache attempt is
reported as a product pass.

### 5.8 Acceptance criteria

- [PASS] Exact committed F4B1 baseline verified.
- [PASS] All thirteen F4B2 candidates received independent ten-question
  retirement analyses.
- [PASS] Every deletion satisfies the repository-retention policy.
- [PASS] No candidate owning reusable production behavior was deleted.
- [PASS] Every retired useful invariant maps to named permanent coverage.
- [PASS] Only two redundant historical shell tests were deleted.
- [PASS] All surviving useful invariants remain tested.
- [PASS] No protected demo or report executable was deleted.
- [PASS] No production definition moved out of a demo.
- [PASS] No F4C extraction work began.
- [PASS] `GpuDemo` changes are scenario-removal-only.
- [PASS] `main.zig` changes are scenario-removal-only.
- [PASS] `build.zig` changes are mechanically tied to retired modules/imports.
- [PASS] The static checker received only narrow deleted-shell adjustments.
- [PASS] No canonical authority, asset name, or historical evidence changed.
- [PASS] Normal build, `check`, `test-full`, GPU smoke, documentation, format,
  reference, and diff/hygiene gates pass.
- [PASS] Current state records F4B2 awaiting owner review and F4C/F4D/F4E not
  begun.
- [PASS] No downstream feature track began.

### 5.9 Unexpected findings and future scope

- `art_asset_demo` is not currently disposable: its concrete definition inputs
  and scene are active test fixtures. Extracting them is a future F4C decision.
- `integrated_demo.Scene` remains the current end-to-end composition fixture for
  integration and stress coverage. Replacing it belongs with later production
  composition work, not selective retirement.
- `handshake_ik_demo.Scene` remains a direct dependency of one presentation
  regression. The solver itself is thoroughly covered, but removing the scene
  now would duplicate orchestration in tests or require a cleaner fixture
  boundary.

### 5.10 No-scope-expansion attestation

- No production-definition extraction occurred.
- No renderer, GPU backend, resource, or application architecture refactor
  occurred.
- No `CharacterInstance` or character architecture refactor occurred.
- No F adoption adapter was implemented.
- No build modularization occurred.
- No broad evidence archival occurred.
- No canonical authority, topology, asset, hash, version, or golden changed.
- No prompt-era production naming cleanup occurred.
- F4C, F4D, F4E, and all downstream feature tracks remain unbegun.

F4B2 stops at this implementation candidate and awaits owner review. It does
not accept itself, authorize a commit/push, or begin F4C.
