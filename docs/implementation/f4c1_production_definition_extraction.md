# F4C1 — Production Definition Extraction

**Status:** F4C1 implementation candidate — awaiting owner review

**Date:** 2026-08-29

**Starting commit:** `4fcdf67b298323935fe99e18df95023c41a20740`

## Scope and authority

The owner authorized F4C1 after approving F4A, F4B1, and F4B2. This change
extracts reusable definitions, factories, and shared data from historical
scenario ownership while preserving their exact values, IDs, ordering,
geometry, collision inputs, and runtime behavior.

F4C1 does not delete a surviving scenario, split `GpuDemo`, restructure
`CharacterInstance`, adopt F runtime identity in legacy systems, redesign
input or interaction authority, modularize the build system, alter canonical
data, rename assets, or begin F4C2 through F4E or downstream feature work.

The starting gate observed:

| Check | Observed value |
|---|---|
| Worktree | clean |
| Branch | `master` |
| Upstream | `origin/master` at `4fcdf67b298323935fe99e18df95023c41a20740` |
| Ahead / behind | `0 / 0` |
| Zig | `0.16.0` |
| Required records | F4A, F4B1, F4B2, and repository-retention records present in HEAD |

## Complete pre-migration source dependency inventory

The audit classified 28 source-to-scenario module edges. Twelve were direct
cross-demo edges; nine of those twelve borrowed production authority and were
removed. The other source edges are application routing or acceptance-only
report roots.

| Consumer | Scenario dependency | Classification | F4C1 decision |
|---|---|---|---|
| `src/graphics/gpu_demo.zig` | `controller_demo`, `handshake_ik_demo`, `integrated_demo`, `playground_demo`, `modular_body_demo`, `equipment_demo`, `mesh_attachment_demo`, `foundation_playground`, `visual_foundation`, `art_asset_demo`, `wardrobe_demo`, `environment_demo` | Temporary F4C2 application routing | Retain all 12; `GpuDemo` still dispatches surviving modes |
| `src/main.zig` | `visual_foundation` | Temporary F4C2 application dependency | Retain CLI option parsing against the active integration scenario |
| `anatomy_quality_report.zig` | `wardrobe_demo` | Historical/acceptance-only | Retain report input scenario |
| `foundation_coherence_report.zig` | `visual_foundation` | Historical/acceptance-only | Retain report input scenario |
| `visual_geometry_report.zig` | `wardrobe_demo` | Historical/acceptance-only | Retain report input scenario |
| `environment_demo.zig` | `foundation_playground` | Reusable production definition/data | Replace with `foundation_world` |
| `environment_demo.zig` | `modular_body_demo` | Reusable production definition/factory | Replace with `modular_humanoid` |
| `environment_demo.zig` | `wardrobe_demo` | Pure scenario composition | Retain embedded wardrobe scene |
| `equipment_demo.zig` | `modular_body_demo` | Reusable production factory | Replace with `modular_humanoid` |
| `foundation_playground.zig` | `modular_body_demo` | Reusable production factory | Replace with `modular_humanoid` |
| `foundation_playground.zig` | `mesh_attachment_demo` | Reusable production factory/data | Replace with `attachment_meshes` |
| `mesh_attachment_demo.zig` | `modular_body_demo` | Reusable production factory | Replace with `modular_humanoid` |
| `visual_foundation.zig` | `foundation_playground` | Reusable production world data | Replace with `foundation_world` |
| `visual_foundation.zig` | `modular_body_demo` | Reusable production factory | Replace with `modular_humanoid` |
| `visual_foundation.zig` | `environment_demo` | Pure scenario composition | Retain embedded environment scene |
| `visual_foundation.zig` | `wardrobe_demo` | Pure scenario composition | Retain presentation composition |
| `wardrobe_demo.zig` | `modular_body_demo` | Reusable production factory | Replace with `modular_humanoid` |

No reusable production module imported a scenario as its authority outside
these application, report, or scenario roots. The remaining demo files
(`controller_demo`, `handshake_ik_demo`, `integrated_demo`, and
`playground_demo`) expose scenario state and integration fixtures, not a
straightforward externally borrowed production catalog or factory.

## Complete pre-migration test dependency inventory

Tests had 27 scenario-module edges before F4C1. Each edge was inspected as a
production-definition provider, a retained integration scenario, or both.

| Test source | Scenario imports before F4C1 | Classification and decision |
|---|---|---|
| `anatomy_tests.zig` | `modular_body_demo` | Move definition calls to production; retain scene integration |
| `art_pipeline_tests.zig` | `art_asset_demo` | Move definition input to production; retain focused scene integration |
| `attachment_secondary_motion_tests.zig` | `mesh_attachment_demo` | Move motion definitions to production; retain scene/count evidence |
| `character_presentation_tests.zig` | `modular_body_demo`, `handshake_ik_demo` | Move humanoid definition to production; retain both scenario tests |
| `character_properties_tests.zig` | `equipment_demo`, `modular_body_demo` | Move both definition providers to production; retain equipment scene only |
| `component_graph_tests.zig` | `modular_body_demo` | Retain integration against the compiled scenario scene |
| `controller_tests.zig` | `controller_demo` | Retain integration fixture |
| `deformation_tests.zig` | `equipment_demo`, `modular_body_demo` | Move definition providers to production; retain equipment scene |
| `environment_tests.zig` | `foundation_playground`, `environment_demo` | Move collider/world data to production; retain environment scene |
| `equipment_tests.zig` | `equipment_demo`, `modular_body_demo` | Move humanoid definition to production; retain equipment scene |
| `foundation_playground_tests.zig` | `foundation_playground` | Move shared spawn data to production; retain scenario behavior |
| `integration_test_support.zig` | `integrated_demo` | Retain integration-specific fixture |
| `integration_tests.zig` | `integrated_demo` | Retain integration scenario |
| `mesh_attachment_tests.zig` | `mesh_attachment_demo` | Move mesh factories to production; retain scene/count evidence |
| `multi_character_tests.zig` | `controller_demo` | Retain integration fixture |
| `playground_tests.zig` | `playground_demo` | Retain scenario behavior |
| `secondary_motion_tests.zig` | `controller_demo` | Retain scenario fixture |
| `stress_tests.zig` | `integrated_demo` | Retain integration/stress scenario |
| `visual_foundation_tests.zig` | `visual_foundation` | Retain active acceptance scenario |
| `visual_geometry_tests.zig` | `wardrobe_demo` | Retain acceptance scenario |
| `wardrobe_tests.zig` | `modular_body_demo`, `wardrobe_demo` | Move humanoid definition to production; retain wardrobe scenario |

Five test-to-scenario edges disappeared completely. Other migrated test files
still import a demo only for deliberate scene-level integration, while their
definition/factory calls now use production modules.

## Candidate classification matrix

| Candidate | Consumed reusable surface | Consumers | Classification | Extraction decision |
|---|---|---|---|---|
| `modular_body_demo` | Humanoid factory, optional-arm root contract, hair motion definitions | Six scenarios and anatomy/presentation/property/deformation/equipment/wardrobe tests | Reusable production definition and factory | Extract to `modular_humanoid` |
| `equipment_demo` | Representative equipment catalog and recipe construction | Equipment scene plus property/deformation tests | Reusable production definition and factory | Extract to `equipment_catalog` |
| `mesh_attachment_demo` | Fitted garment, sleeve, cape meshes and motion definitions | Mesh/foundation scenarios and mesh/motion tests | Reusable production factory and data | Extract to `attachment_meshes` |
| `art_asset_demo` | Prompt 23 page, region, binding, and definition inputs | Art scene and art-pipeline tests | Reusable production definition | Extract to `art_asset_catalog` |
| `foundation_playground` | Spawn points, parallax factors, static collider inputs | Foundation/environment/visual scenarios and world tests | Reusable production data | Extract to `foundation_world` |
| `wardrobe_demo` | Uses modular humanoid factory; otherwise owns a complete wardrobe scenario | Environment/visual composition and acceptance tests/reports | Borrowed factory plus pure scenario composition | Redirect factory; retain scenario edges |
| `environment_demo` | Uses shared world/humanoid data and embeds wardrobe scene | Visual composition and environment tests | Borrowed data plus pure scenario composition | Redirect data/factory; retain wardrobe composition |
| `visual_foundation` | Uses shared world/humanoid data and embeds environment/wardrobe scenes | Application, report, and acceptance tests | Borrowed data plus pure scenario composition | Redirect data/factory; retain composition |
| `handshake_ik_demo` | Complete IK interaction scene | Presentation tests and application router | Integration fixture | Retain |
| `integrated_demo` | Complete multi-system scene | Integration/stress tests and application router | Integration fixture | Retain |
| Other surviving demo roots | Scenario setup, timing, controls, evidence, or CLI routing | Their focused tests and application router | Scenario or historical acceptance only | Retain |

No candidate required an ambiguous ownership policy, and no straightforward
in-scope extraction was blocked.

## Production ownership migrations

| Old owner | New owner | Extracted public surface | Ownership rationale |
|---|---|---|---|
| `modular_body_demo` | `modular_humanoid` | `OptionalArmRootContract`, long-hair and ponytail motion definitions, `initDefinition`, `initDefinitionWithOptionalArmRootContract` | Cohesive immutable/default humanoid construction shared by several consumers |
| `equipment_demo` | `equipment_catalog` | `initDefinition` and its private recipe helpers | Concrete reusable catalog sits above generic equipment semantics and below scenarios |
| `mesh_attachment_demo` | `attachment_meshes` | Cape/sleeve motion definitions; fitted-garment, sleeve, and cape factories | Narrow production owner for existing reusable attachment topology and motion data |
| `art_asset_demo` | `art_asset_catalog` | Page IDs, semantic IDs, view ID, page/region/binding arrays, `definitionInput` | Concrete runtime art content is separate from generic `art_pack` validation and scenario evidence |
| `foundation_playground` | `foundation_world` | Three spawn points, two parallax factors, `colliderInputs` | Narrow owner for the already-shared world fixture without introducing a general world or level system |

Twenty-nine reusable public declarations left affected demo modules. The five
new production modules expose 28 declarations: `world_min_x` and
`world_max_x` became private implementation data, while the formerly private
injectable humanoid constructor became a narrowly required public function so
the retained demo can preserve its allocation-failure checks. All helper
recipes, vertex tables, and construction helpers remain private. There is no
mutable global state.

## Test fixture migration

The following test sources now call production owners for shipped/default
content while retaining demo imports only where they exercise whole scenarios:

- `anatomy_tests.zig` and `character_presentation_tests.zig` use
  `modular_humanoid`.
- `character_properties_tests.zig`, `deformation_tests.zig`, and
  `equipment_tests.zig` use `modular_humanoid`; the first two also use
  `equipment_catalog`.
- `wardrobe_tests.zig` uses `modular_humanoid` and no longer imports
  `modular_body_demo`.
- `mesh_attachment_tests.zig` and `attachment_secondary_motion_tests.zig`
  use `attachment_meshes`.
- `art_pipeline_tests.zig` uses `art_asset_catalog`.
- `environment_tests.zig` and `foundation_playground_tests.zig` use
  `foundation_world` for shared world data.

Real production content remains production-owned; no shipped fixture moved
under `tests/`.

## Surviving scenario dependencies

Every surviving source-side scenario import is allowlisted and classified:

- **PURE SCENARIO COMPOSITION:** `environment_demo -> wardrobe_demo`;
  `visual_foundation -> environment_demo`; `visual_foundation -> wardrobe_demo`.
- **TEMPORARY F4C2 APPLICATION DEPENDENCY:** `GpuDemo` routes all twelve
  surviving scenarios; `main.zig` reads three `visual_foundation` CLI values.
- **HISTORICAL/ACCEPTANCE-ONLY:** the anatomy-quality and visual-geometry
  reports consume `wardrobe_demo`; the coherence report consumes
  `visual_foundation`.
- **INTEGRATION FIXTURE:** the 22 remaining test-to-scenario edges exercise
  complete scenarios, counts/evidence produced by those scenarios, or
  integration/stress behavior. They are not definition-provider calls.

No production definition, factory, domain algorithm, animation, physics,
character, or rendering module imports a scenario for reusable authority.

## Before and after dependency graph

```text
Before
  reusable consumer/test
       -> historical demo
            -> embedded reusable definitions/factories/data

After
  modular_humanoid / equipment_catalog / attachment_meshes
  art_asset_catalog / foundation_world
       -> consuming scenarios and tests

  GpuDemo -> surviving scenarios             (application routing retained)
  visual_foundation -> environment/wardrobe  (scenario composition retained)
  environment_demo -> wardrobe_demo          (scenario composition retained)
```

## Dependency metrics

| Measure | Before F4C1 | F4C1 candidate | Delta |
|---|---:|---:|---:|
| Production modules importing demos for reusable authority | 0 direct domain modules, but 9 borrowing edges inside reusable scenarios | 0 | 9 borrowing edges removed |
| All source-to-scenario module edges | 28 | 19 | -9 |
| Direct demo-to-demo edges | 12 | 3 | -9 |
| Tests importing scenario modules | 27 | 22 | -5 |
| Public reusable declarations owned by affected demos | 29 | 0 | -29 |
| `GpuDemo` scenario fan-out | 12 | 12 | unchanged |
| New production modules | 0 | 5 | +5 |

`build.zig` removes the same nine demo-borrowing dependency edges and adds 41
explicit edges around the five production modules: 17 production-module
dependencies, 14 scenario-consumer imports, and 10 aggregate/focused test-root
imports. This is mechanical module wiring, not build-system modularization.

## Static policy

`tools/check_repository.ps1` now:

1. recognizes the five production owners when checking the established
   Prompt-era contracts;
2. requires the migrated factories/data to exist in those owners and rejects
   their former public demo-owned entry points;
3. rejects tests that call the former demo-qualified provider APIs; and
4. scans every `src/**/*.zig` scenario import against an explicit allowlist.

The allowlist contains only `main.zig`, `gpu_demo.zig`, three acceptance report
roots, and the two scenario-composition roots. It is intentionally expected to
shrink during F4C2.

## Files created

- `src/scene/modular_humanoid.zig`
- `src/scene/equipment_catalog.zig`
- `src/scene/attachment_meshes.zig`
- `src/scene/art_asset_catalog.zig`
- `src/scene/foundation_world.zig`
- `docs/implementation/f4c1_production_definition_extraction.md`

## Files modified

- `build.zig`
- Eight consuming scenario files: `modular_body_demo.zig`,
  `equipment_demo.zig`, `mesh_attachment_demo.zig`, `art_asset_demo.zig`,
  `foundation_playground.zig`, `wardrobe_demo.zig`, `environment_demo.zig`,
  and `visual_foundation.zig`.
- Eleven affected test files listed in the test fixture migration section.
- `tools/check_repository.ps1`.
- Current architecture/status documentation: `docs/ARCHITECTURE.md`,
  `docs/ART_PIPELINE.md`, the accepted shared-foundation architecture record,
  and four live documents under `docs/project/`.

## Files deleted

None. Every surviving scenario remains present.

## Scenario results and retirement eligibility

| Scenario | Result | Disposition after F4C1 |
|---|---|---|
| `modular_body_demo` | Consumes `modular_humanoid`; retains scene, topology, and failure-path evidence | **RETAIN — UNIQUE SCENARIO VALUE** |
| `equipment_demo` | Consumes `modular_humanoid` and `equipment_catalog`; retains loadout evidence | **RETAIN — UNIQUE SCENARIO VALUE** |
| `mesh_attachment_demo` | Consumes production humanoid and attachment factories; retains mixed-render/secondary-motion scene | **RETAIN — UNIQUE SCENARIO VALUE** |
| `art_asset_demo` / `art_assets` | Consumes `art_asset_catalog`; no longer owns production content | **RETIREMENT ELIGIBLE** after a separately authorized route/test retirement maps its one focused scene integration test |
| `foundation_playground` | Consumes production humanoid, attachment, and world data; retains its broad focused regression scene | **RETAIN — UNIQUE SCENARIO VALUE** |
| `wardrobe_demo` | Consumes production humanoid factory; remains environment/visual composition input | **RETAIN — UNIQUE SCENARIO VALUE** |
| `environment_demo` | Consumes production world/humanoid data; embeds wardrobe scene deliberately | **RETAIN — UNIQUE SCENARIO VALUE** |
| `visual_foundation` | Consumes production world/humanoid data; remains active integration/evidence scenario | **RETAIN — UNIQUE SCENARIO VALUE** |

No scenario is retired by this change.

## Boundary-specific results

- **`GpuDemo`:** no source change. Its twelve-mode scenario fan-out remains
  application routing. No renderer, application, backend, resource, frame,
  capture, or evidence split occurred.
- **`CharacterInstance`:** no change. No character lifecycle, animator, IK,
  controller, identity, command, read facade, or mutable-authority refactor
  occurred.
- **`build.zig`:** five modules and their exact dependency imports were added;
  consumers and test roots were redirected. No target was renamed and no
  build architecture was modularized.
- **F authority:** identity, canonical serialization, `scene_core`,
  `RuntimeScene`, mutation contexts, rollback, publication, snapshots,
  hierarchy, and lifecycle are untouched.

## Validation results

| Validation | Result |
|---|---|
| Zig version | PASS — `0.16.0` |
| Normal build | PASS — 20/20 steps |
| Repository source audit | PASS — 257 files; F4C1 ownership allowlist passed |
| Focused anatomy | PASS — 16/16 |
| Focused equipment | PASS — 10/10 |
| Focused mesh | PASS — 9/9 |
| Focused deformation | PASS — 11/11 |
| Focused art/image | PASS — 10/10 |
| Focused presentation | PASS — 15/15 |
| Focused component graph | PASS — 6/6 |
| Focused wardrobe | PASS — 19/19 |
| Focused foundation | PASS — 4/4 |
| Focused environment | PASS — 13/13 |
| `check` | PASS — 53/53 steps, 516/516 tests |
| `test-full` | PASS on rerun — 60/60 steps, 627/627 tests. The first attempt completed 615 tests but hit a runner-response timeout in the unchanged canonical-human rig executable; that exact test passed in `check` and the full rerun passed 12/12. |
| Physical GPU smoke | PASS — 22/22 steps; D3D12/DXIL, 2 instances in 1 indexed draw call |
| Documentation audit | PASS — 46 required files, 42 Markdown files, 105 local Markdown targets |

The first `check` attempt correctly exposed missing `art_asset_catalog` and
`foundation_world` imports in the aggregate test root. The build wiring was
corrected before the passing recorded gate. No assertion, test, threshold, or
canonical content changed to obtain these results.

## Acceptance review

- [x] Clean synchronized post-F4B2 baseline verified.
- [x] Entire surviving repository inspected for demo-owned production content.
- [x] Every relevant source and test dependency into a scenario classified.
- [x] All straightforward reusable definitions, factories, and shared data
  discovered in scope have production owners.
- [x] Modular humanoid, equipment, attachment mesh, art asset, and shared
  foundation-world authorities no longer live in demos.
- [x] Definition-borrowing cross-demo imports were eliminated.
- [x] Tests use production owners for extracted content.
- [x] No surviving demo was deleted and no behavior was intentionally changed.
- [x] Canonical and F authority are unchanged.
- [x] No renderer/backend, `CharacterInstance`, F-adoption, platform-input,
  build-modularization, evidence-cleanup, or downstream feature work occurred.
- [x] Narrow ownership regression policy passes.
- [x] Focused tests, normal build, source audit, `check`, `test-full`, and
  physical D3D12 GPU smoke pass.

## Unexpected findings and owner-review notes

- The aggregate test root required explicit imports for two newly referenced
  production modules even though both focused roots were already correct.
- The first `test-full` attempt experienced one transient Windows test-runner
  response timeout in an unchanged canonical-human test. The same test passed
  in `check` and the complete rerun passed 627/627.
- `art_asset_demo` is now structurally retirement-eligible, but its CLI route
  and one focused scene integration test remain until a separate retirement
  request.
- No new ownership question requires an owner policy decision for F4C1.

## No-scope-expansion attestation

No surviving demo was deleted. No renderer/backend architecture was created.
`GpuDemo` and `CharacterInstance` were not structurally decomposed. No
interaction-authority redesign, F-adoption adapter, platform/domain action
redesign, build-system modularization, canonical authority change, asset-name
migration, or broad evidence archival occurred. F4C2, F4C3, F4C4, F4C5, F4D,
F4E, and every downstream feature track remain unbegun.
