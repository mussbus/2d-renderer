# F4C5 Build, Test, and Repository-Policy Modularization

Status: **F4C5 implementation candidate — awaiting owner review**

Date: 2026-08-31

Starting baseline:
`a7785c11cca0e23eda8074a79c25be13e3a25114`

## Scope and non-scope

F4C5 changes build registration, aggregate-gate ownership, test taxonomy,
repository-policy routing, and developer documentation. It does not change
production engine behavior, rendering, character/interaction authority,
F identity or RuntimeScene semantics, input behavior, canonical data, art,
topology, hashes, demos, or prompt-era artifact names.

F4D independent-engine composition proof, F4E naming/provenance cleanup, and
all downstream feature tracks remain unstarted.

## Starting-state evidence

Before modification:

| Check | Observed result |
| --- | --- |
| Worktree | clean |
| Branch | `master` |
| HEAD | `a7785c11cca0e23eda8074a79c25be13e3a25114` |
| Upstream | `origin/master` at the same commit |
| Ahead / behind | `0 / 0` |
| Zig | `0.16.0` |
| Repository policy | PASS; F2C and F4C1–F4C4 ownership checks passed |

No pull, merge, rebase, reset, stash, branch switch, commit, or push occurred.

## Pre-F4C5 build ownership audit

The pre-migration root `build.zig` was the owner of the following
responsibilities.

| Responsibility | Pre-F4C5 owner | Correct owner | Taxonomy | Registration-only move? |
| --- | --- | --- | --- | --- |
| Pinned Zig/SDL/DXC/DXIL validation | root | root composition | normal build | unchanged |
| Windows/target constraints | root | root composition | normal build | unchanged |
| Shader compilation/validation | root | root composition | normal build and GPU | unchanged |
| Application executable | root | root composition | normal build | unchanged |
| Runtime DLL/art/shader installation | root | root composition | normal build | unchanged |
| Production module creation and imports | root | `build/modules.zig` | all gates | yes |
| Deterministic engine root | root | `build/tests_engine.zig` | fast engine | yes |
| Renderer-boundary root | root | `build/tests_engine.zig` | fast engine | yes |
| Foundation/F4C4/scene-core roots | root | `build/tests_engine.zig` | fast engine | yes |
| Integration and stress roots | root | `build/tests_engine.zig` | full CPU | yes |
| Art/presentation/component roots | root | `build/tests_content.zig` | content | yes |
| Foundation/wardrobe/environment/visual-foundation roots | root | `build/tests_content.zig` | full CPU, with content audits separate | yes |
| Canonical model/human/geometry roots | root | `build/tests_content.zig` | content | yes |
| Current art, anatomy, golden, environment audits | root | content/evidence helpers | content | yes |
| Canonical/human exporters and validators | root | `build/evidence.zig` | content or on demand | yes |
| Blender bridge | root | `build/evidence.zig` | historical/on demand | yes |
| Acceptance report executables | root | `build/evidence.zig` | manual/visual | yes |
| Historical review packages | root | `build/evidence.zig` | historical/on demand | yes |
| GPU smoke executable/command | root | root composition | GPU smoke | unchanged |
| `test`, `check`, `test-full`, `verify` | root | `build/gates.zig` | aggregates | semantics changed as documented |
| Documentation validation | standalone only | `check` via `build/gates.zig` | fast static | new dependency |
| Historical prompt/evidence routes | root, mixed with normal registrations | `build/evidence.zig` | on demand | yes |

The old root registered all concrete module/test/tool/evidence objects even
when their only relationship was a top-level aggregate. F4C5 moves
registration without changing the implementation source or test assertions.

## Pre-F4C5 test taxonomy

Each coherent pre-existing family has one primary category. A family may be
reused by an aggregate, but its owner is singular.

### FAST_ENGINE_CONTRACT

- `tests/test_all.zig`: math, camera, skeleton/pose/clip/animation, input
  layering, physics/controller, character authority, interaction/IK,
  render-queue and application-neutral deterministic contracts.
- `tests/renderer_boundary_tests.zig`.
- `tests/image_decode_tests.zig` because decode validity is required by the
  production application boundary.
- `tests/foundation_primitives.zig`.
- `tests/f4c4_adoption_tests.zig`.
- `tests/scene_core/authored_scene_tests.zig`.
- `tests/scene_core/runtime_scene_tests.zig`.
- `tests/scene_core/registry_tests.zig`, retaining internal white-box access.

### FULL_CPU_INTEGRATION

- `tests/integration_tests.zig`.
- `tests/stress_tests.zig`.
- `tests/foundation_playground_tests.zig`.
- `tests/wardrobe_tests.zig`.
- `tests/environment_tests.zig`; the associated atlas audit is content-owned.
- `tests/visual_foundation_tests.zig`.

These exercise deterministic production composition and cross-system behavior.
They are not canonical-human qualification merely because they consume current
production definitions.

### CONTENT_QUALIFICATION

- `tests/art_pipeline_tests.zig`.
- `tests/character_presentation_tests.zig`.
- `tests/component_graph_tests.zig`.
- `tests/visual_registration_tests.zig`.
- `tests/visual_geometry_tests.zig`.
- Canonical model core/phase-C/phase-DE/phase-F roots.
- Canonical human identity/rig/joint-control/structural/base roots.
- Canonical geometry and human-geometry scaffold/refinement/adoption/R3/R4/full
  roots.
- Prompt 25D approved-golden verification.
- Prompt 26 environment-art audit.
- Prompt 27C art and R1 torso audits.
- Current human-base exporter compilation and retained content-policy audit.

### GPU_SMOKE

- `tests/gpu_smoke.zig` through the existing real D3D12/DXIL `gpu-smoke`
  route.

### MANUAL_VISUAL_ACCEPTANCE

- The installed application routes and current visual-geometry,
  anatomy-quality, and foundation-coherence reports.
- Existing documented D3D12 capture/review workflows. Building these routes
  does not imply human acceptance.

### HISTORICAL_EVIDENCE_REPRODUCTION

- Human-geometry refinement/R1 evidence exporters.
- Pinned Blender bridge reproduction.
- Prompt 27A and 27B historical review-package routes.
- Other existing focused prompt-era update/review steps remain individually
  registered under the evidence helper even where they are not members of the
  compact historical aggregate.

No test/evidence route was removed.

## Pre-F4C5 repository-checker taxonomy

The former 2,900-line `tools/check_repository.ps1` combined all categories.

| Category | Pre-F4C5 contents | F4C5 owner |
| --- | --- | --- |
| Current architecture invariant | F2C supported/internal surface; F4C1 production-definition direction; F4C2 renderer/application/evidence boundary; F4C3 opaque authority; F4C4 F identity/input boundary | `tools/checks/architecture.ps1`, run by routine checker |
| Current content invariant | Canonical model/human/geometry, art/atlas, anatomy, current golden and current Prompt 23–27 qualification/source-shape assertions | `tools/checks/content_policy.ps1`, run by `test-content` |
| Historical prompt/evidence acceptance | Prompt-specific review-package, report, lineage, and reproduction registration | retained content policy plus explicit `tools/checks/history.ps1`; reproduction is on demand |
| Brittle implementation-shape check | Exact phrase/source-shape assertions accumulated from earlier milestones | retained in content qualification pending F4E provenance cleanup; current architecture uses narrower dependency/API checks |
| Repository hygiene | Forbidden renderer paths, unfinished markers, skipped tests, forbidden `unreachable`, editor/generated debris | `tools/checks/hygiene.ps1`, run by routine checker |

Nothing was silently deleted. The full retained checker moved mechanically to
`tools/checks/content_policy.ps1`; its repository-root calculation and
build-source input were updated for the helper layout.

## Build architecture after F4C5

```text
build.zig
├── target/platform + pinned dependencies
├── shaders + installed runtime assets
├── production application
├── physical GPU smoke
├── build/modules.zig
│   └── explicit production/test module catalog
├── build/tests_engine.zig
│   ├── fast engine/F/scene roots
│   └── integration + stress roots
├── build/tests_content.zig
│   ├── authored art/presentation roots
│   ├── production composition roots
│   └── canonical model/human/geometry roots
├── build/evidence.zig
│   ├── exporters/validators/reports
│   ├── manual visual build route
│   └── historical evidence routes
└── build/gates.zig
    └── test/check/test-full/test-content/verify
```

The root remains the visible composition DAG. Registration is explicit; no
directory discovery or global mutable build state was introduced. A small
typed options/registration record is passed to each helper. Production module
creation has one owner in `build/modules.zig`; test-only root modules remain
separate where white-box access, filtering, or failure isolation requires it.

## Gate dependency DAG

### Before

```text
test
├── engine contracts
└── canonical/content qualification

check
├── test
├── formatting
├── monolithic repository/content/history policy
├── art audits
└── approved goldens

test-full
├── test
└── broader integration/content routes

verify
├── check
├── test-full
└── test-stress

gpu-smoke (separate)
manual/evidence routes (individually registered, not taxonomically aggregated)
```

### After

```text
test (fast compatibility alias)
└── fast engine/F/scene/renderer-boundary CPU tests

check
├── application compile
├── test
├── formatting
├── current architecture + hygiene policy
└── documentation validation

test-full
├── check
├── deterministic integration
├── deterministic production composition
└── stress

test-content
├── canonical/content tests
├── current art/environment/anatomy/golden audits
├── retained content policy
└── current exporter compilation

verify
├── check
├── test-full
└── test-content

gpu-smoke (orthogonal physical D3D12/DXIL)
visual-acceptance (orthogonal manual-review build route)
evidence-history-check (orthogonal, non-mutating)
evidence-history (orthogonal, explicit and potentially mutating)
```

There is no cycle. `test-content` does not depend on `test-full`.
`verify` does not require a GPU or manual acceptance.

## Gate definitions

### `check`

Primary routine developer gate:

- production application compilation;
- formatting;
- fast deterministic engine/F/scene/input/renderer-boundary contracts;
- current architecture and hygiene policy;
- documentation structure/link validation.

It intentionally excludes physical GPU work, full canonical-human/content
qualification, current art/golden qualification, manual review, and historical
evidence reproduction.

### `test-full`

Full deterministic CPU gate. It includes `check`, broader integration,
foundation/wardrobe/environment/visual-foundation production composition, and
the existing 1,000-interaction/100,000-tick stress suite. It excludes physical
GPU, manual review, current canonical/content qualification, and historical
generation.

### `test-content`

Current content-authority gate. It includes all canonical model/human/geometry
roots, current art/presentation/component/visual qualification, current
environment/anatomy/golden audits, current exporter compilation, and the
retained full content-policy checker. Canonical or current content-authority
changes require this gate even though unrelated engine work does not.

### `gpu-smoke`

Unchanged physical D3D12/DXIL proof. It remains orthogonal and retains real
device/shader/draw/readback/fault/cleanup behavior.

### `visual-acceptance`

Build-only aggregate for the application and current report executables used
by documented owner-review routes. Human review remains human review.

### `evidence-history-check` and `evidence-history`

The check proves retained historical route registration and source presence
without mutating evidence. The reproduction aggregate intentionally exposes
potentially mutating historical exporters and review packages on demand.

### `verify`

CPU-capable pre-review aggregate: `check` + `test-full` +
`test-content`. Shared nodes execute once. GPU smoke, manual acceptance, and
historical reproduction remain explicit separate decisions.

## Test-root consolidation decision

F4C5 retains the existing concrete test-root count and focused target names.
The audit rejected a single giant test executable because:

- scene-core registry and character/interaction white-box roots must remain
  isolated from supported production APIs;
- canonical phase roots preserve useful file-backed failure isolation;
- visual-foundation filtering must remain available;
- combining all roots would increase listener payload and reduce targeted
  diagnosis;
- the present catalog already shares production module definitions safely.

F4C5 centralizes module ownership and aggregate registration but does not
over-share mutable `std.Build.Module` configuration or weaken root
boundaries. No claim is made that Windows cache or Zig listener instability is
solved; repeated cache `AccessDenied` remains an environmental observation.

## Compatibility

Preserved commands include:

- `zig build`;
- `zig build test`;
- `zig build check`;
- `zig build test-full`;
- `zig build test-stress`;
- `zig build verify`;
- `zig build gpu-smoke`;
- all existing focused domain, canonical, report, exporter, and review steps.

New stable aggregates are `test-content`, `visual-acceptance`,
`evidence-history-check`, and `evidence-history`.

All 54 pre-F4C5 named build steps remain registered. F4C5 adds exactly five:
the four stable aggregates above plus the internal `test-content-tests`
composition step. No existing command was removed or renamed.

## Future domain registration workflow

- A SEM or OBJ production module is added to its source domain and explicitly
  registered once in `build/modules.zig`; its fast/full test root is added to
  `build/tests_engine.zig`.
- A content-authority validator belongs in `build/tests_content.zig` and
  `test-content`, not `check`, unless it protects a universal engine
  invariant and the reason is recorded.
- An LVL authoring/content tool belongs in the content or evidence helper
  according to whether it validates current authority or generates review
  output.
- A new editor executable should receive an explicit application/tool helper
  registration; root changes only if it creates a new major domain or gate.
- Historical reproduction belongs in `build/evidence.zig` and may not become
  a routine-gate dependency.

Ordinary additions therefore do not require simultaneous edits to root
`build.zig`, `tests/test_all.zig`, the repository checker, and this document.

## Before/after coupling metrics

Final measured values are recorded after validation.

| Metric | Before | After |
| --- | ---: | ---: |
| Root `build.zig` lines | 2,381 | 245 |
| Build helper files / lines | 0 / 0 | 5 / 2,557 |
| Concrete test roots registered directly in root | 36 | 0 |
| Tool/report executables registered directly in root | 7 | 0; the application executable remains root-owned |
| Content/evidence steps registered directly in root | 42 | 0; 26 content and 16 evidence steps are helper-owned |
| Concrete test executable/root count | 36 | 36 |
| Routine checker root/helper split | 2,896 / 0 | 13 / 269; full retained content policy is a separate 2,903-line helper |
| Future ordinary domain additions expected to touch root | most | only new major domains/gates |

The unchanged 36-root decision preserves useful isolation. Registration
coupling, not minimum line count, is the success measure.

## Test counts and timing

Baseline measurements used one isolated cache pair in the sequence
`build` → `check` → `test-full` on the same Windows machine.

| Command | Before F4C5 | After F4C5 |
| --- | --- | --- |
| normal build | 20/20 steps; tool-observed wall approximately 64 s and application compile 28 s | 20/20 steps, 44.484 s isolated-cache; exact warm command 7.824 s |
| `check` | 57/57 steps, 527/527 tests, 313.420 s | 22/22 steps, 381/381 tests, 49.732 s |
| `test-full` | 64/64 steps, 638/638 tests, 335.649 s; stress was separate | 35/35 steps, 478/478 tests, 407.300 s including stress |
| `test-content` | no distinct aggregate | 60/60 steps, 279/279 tests, 364.595 s |
| `verify` | check + old full + separate stress | 86/86 steps, 668/668 unique tests, 631.165 s |
| repository checker | PASS, approximately 13.695 s | PASS, 3.774 s |
| documentation checker | PASS, 0.288 s | PASS, 0.227 s |

These are machine-specific observations, not performance budgets. The routine
`check` wall time fell by approximately 84 percent while retaining its stated
engine/static contracts. The new `test-full` is slower than the old aggregate
because it now correctly includes the two long-duration stress tests. Shared
roots make `verify` report 668 unique tests rather than the sum of overlapping
gate counts.

## Validation record

| Validation | Result |
| --- | --- |
| Exact normal build | PASS, 20/20 steps |
| Isolated-cache normal build | PASS, 20/20 steps, 44.484 s |
| `check` | PASS, 22/22 steps, 381/381 tests, 49.732 s |
| `test-full` | PASS, 35/35 steps, 478/478 tests, 407.300 s |
| `test-content` | PASS, 60/60 steps, 279/279 tests, 364.595 s |
| `verify` | PASS on unchanged retry, 86/86 steps, 668/668 tests, 631.165 s |
| `gpu-smoke` | PASS, physical Direct3D12/DXIL, two instances, one indexed-instanced draw, readback and fault cleanup |
| Focused component graph + canonical human base chain | PASS, 95/95 tests |
| Focused canonical geometry | PASS, 12/12 tests |
| Historical evidence registration | PASS through `evidence-history-check`; five aggregate reproduction jobs plus retained focused routes are present without regeneration |
| Manual visual build route | PASS; application plus three current report executables compiled |
| Current repository checker | PASS, current F2C/F4C1–F4C5 architecture and hygiene |
| Retained content checker | PASS, all prior prompt/content checks retained |
| Documentation checker | PASS, 46 required files, 42 Markdown files, 109 local targets |
| Representative D3D12 routes | PASS: `sprites`, `integrated`, `handshake-ik`, `environment`, exits `0,0,0,0` |

Two environmental conditions were observed without changing coverage. Initial
sandboxed isolated-cache builds failed with Windows `manifest_create
AccessDenied`; the same builds passed outside the restricted sandbox. One
`test-content` attempt timed out in the Zig listener on the unchanged
environment test, which immediately passed 13/13 focused; the aggregate then
passed 279/279 unchanged. The first `verify` attempt reported 659/659 completed
tests but exited nonzero after a canonical-human-base listener timeout; the
unchanged retry passed 668/668. No assertion was weakened or skipped.

## Current state

| Milestone | State |
| --- | --- |
| F4A | OWNER-APPROVED |
| F4B1 | OWNER-APPROVED |
| F4B2 | OWNER-APPROVED |
| F4C1 | OWNER-APPROVED |
| F4C2 | OWNER-APPROVED |
| F4C3 | OWNER-APPROVED |
| F4C4 | OWNER-APPROVED |
| F4C5 | IMPLEMENTED / AWAITING OWNER REVIEW |
| F4D | NOT BEGUN |
| F4E | NOT BEGUN |
| F4 overall | NOT ACCEPTED |

Post-F4 fan-out remains blocked.
