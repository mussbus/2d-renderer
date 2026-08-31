# F4D Independent Engine Composition and Decoupling Proof

Status: **F4D implementation/acceptance candidate — awaiting owner review**

Date: 2026-08-31

Starting baseline: clean, synchronized `master` at
`c648697aeaf75d03823aa7e9f874898464a79679`, with upstream at the same commit
and ahead/behind `0/0`.

## Scope and proof objective

F4D asks whether a second application can use accepted production engine
infrastructure without inheriting the historical demo application's scenario,
mode-routing, or evidence architecture. The retained proof is the permanent,
small `engine_smoke` application. It is a client of existing subsystem roots,
not a new engine facade or a replacement for the historical application.

The proof adds no authored/canonical content, changes no simulation behavior,
and creates no new renderer. Its one production API change is the narrow
shutdown-observation companion `Renderer.deinitWithMetrics`; existing
`Renderer.deinit` delegates to it and preserves behavior.

## Supported entry surfaces for a new client

A new application imports the subsystems it actually needs:

- `foundation` for stable identity and spatial values;
- `scene_core` for supported RuntimeScene commands and read views;
- `sdl_gpu_renderer` for the production SDL3 GPU backend;
- `sprite_batch` or `render_queue` for render-facing work;
- `character` plus `character_entity_binding` only for a character client;
- `interaction`, `interaction_system`, and a production interaction definition
  such as `handshake` only for interaction behavior.

No giant `engine.zig` re-export root was added. Platform SDL ownership remains
inside the renderer boundary for this client.

## Independent application architecture

```text
engine_smoke.zig
  |
  +--> engine_smoke_client.zig
  |      +--> foundation
  |      +--> scene_core.RuntimeScene
  |      `--> sprite_batch request contract
  |
  `--> sdl_gpu_renderer.Renderer
         +--> UnifiedRenderQueue
         +--> SDL3 direct3d12 + DXIL
         `--> CapturedFrame readback
```

`engine_smoke_client.Client` initializes a fixed-capacity RuntimeScene, creates
a physics/gameplay temporary, promotes it to a persistent F `EntityId`, and
retains its valid `EntityHandle`. It observes only `SceneSnapshot` /
`SceneReadView` values. A supported world-authority transform mutation is
observed at a later publication generation before rendering begins.

The copied observation is converted to one production `SpriteRequest` from
the resolved world affine. The physical app initializes the existing renderer,
unified queue, and generic capture transfer; submits the same bounded request
for six frames; performs a direct copied-frame readback; and shuts down the
RuntimeScene and renderer explicitly.

## Forbidden and transitive dependency proof

The independent app source and its build-injected module edges contain none of:

- `gpu_demo` or `GpuDemo`;
- `demo_application` or `DemoApplication`;
- any `*_demo` scenario module;
- `foundation_playground` or `visual_foundation`;
- evidence writers, prompt trackers, review packages, or historical reports.

Its actual first-party module tree is:

```text
engine_smoke entry
  +--> engine_smoke_client
  |      +--> foundation root and its relative contract files
  |      +--> scene_core root and its relative contract files
  |      |      `--> foundation
  |      `--> sprite_batch
  `--> sdl_gpu_renderer
         +--> sdl + fault_injection
         +--> sprite_batch
         +--> render_queue --> sprite_batch + deformable_mesh
         +--> deformable_mesh --> math + deformation + skeleton
         +--> mesh_gpu_catalog --> deformable_mesh
         +--> camera2d --> math
         +--> art_pack + image_decode
         +--> diagnostics
         `--> frame_capture
```

All nodes are production engine/backend modules. `art_pack` and
`image_decode` are renderer capabilities, not `art_asset_demo` or content
qualification. The app uses the renderer's built-in procedural texture and
installed production shaders; it does not load historical atlases or evidence.

`tools/checks/architecture.ps1` enforces the source imports, build-injected
edges, lower-layer direction, renderer direction, CPU-proof direction, and
application-helper registration on every routine `check`.

## Build registration

F4D introduces `build/apps.zig` as the explicit application helper anticipated
by the F4C5 workflow. It owns both `skeletal_gpu_demo` and `engine_smoke`, the
existing `run` / `gpu-smoke` routes, and the new `engine-smoke` /
`run-engine-smoke` routes. `build/modules.zig` owns both root modules and their
explicit dependency injection. `build/tests_engine.zig` owns
`test-engine-composition`; `build/gates.zig` attaches it and both application
compiles to `check`.

The root changed once to compose the new application helper and no longer
contains concrete application registration. A later application should touch
its source, `build/modules.zig`, and `build/apps.zig`; it need not copy
`DemoApplication` or edit root/gate/policy files unless it creates a new major
gate or protected architectural boundary.

## CPU structural proof

`tests/engine_composition_tests.zig` contains three independent tests:

1. create/promote/observe/mutate a generic RuntimeScene entity and construct a
   production sprite request from the supported read view;
2. bind two real specialized `CharacterInstance` runtimes to two F entities,
   apply a scene transform, publish a character transform, change enabled
   state, and observe both results through a normal snapshot;
3. create the same two F bindings, build the production handshake definition,
   start/update/complete the production interaction manager, and verify
   completion, cleanup, bindings, and unchanged roots.

The test module has no SDL dependency and imports no application/demo/evidence
module. It is part of the fast engine contract through `check`.

## Physical renderer and lifetime proof

The independent app uses the actual `sdl_gpu_renderer.Renderer` and its
hard-required `direct3d12` driver/DXIL format. The observed run produced:

| Measurement | Result |
| --- | ---: |
| Frames | 6 |
| Sprite draw calls | 6 |
| Instances per frame | 1 |
| Readback pixels different from the first/background pixel | 15,129 |
| Initial tracked GPU creations/releases | 17 / 1 |
| Tracked GPU creations after steady frames | 17 |
| Queue allocations after stabilization | 0 |
| Final tracked GPU creations/releases | 17 / 17 |
| Final fence acquisitions/releases | 8 / 8 |

The owned copied readback is inspected directly; no file writer or evidence
manifest participates. The one readback allocation is an explicit on-demand
copied-frame result outside the steady six-frame loop. RuntimeScene snapshots
and the transform mutation occur outside that stabilized render loop.

## Client dependency matrix

| Client | Foundation | Scene Core | Renderer | Character | DemoApplication | `*_demo` | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Existing demo application | YES | YES, through F-backed clients | YES | YES | YES | YES | YES, optional routes |
| Independent `engine_smoke` | YES | YES | YES | NO | NO | NO | NO |
| Existing `gpu-smoke` command | YES, transitive app graph | YES, transitive app graph | YES | YES, transitive app graph | YES | YES, transitive app graph | YES, transitive app graph |
| F4D CPU composition tests | YES | YES | NO | YES | NO | NO | NO |

The legacy GPU-smoke command still enters through the historical application,
but the reusable renderer's `runSmoke` capability is renderer-owned. Rewiring
that command is compatibility cleanup, not missing engine infrastructure.

## Blast-radius reassessment

### A. Add a second renderer backend

F4A expected backend implementation, construction/configuration, and focused
tests. Post-F4D, those remain the primary changes. Application composition
would choose the backend in `build/apps.zig`/the client root; scene_core,
character, interaction, and evidence writers do not change. The current
clients name the concrete SDL backend rather than a backend interface, which is
an explicit construction dependency, not demo ownership.

### B. Add another application

F4A identified the root build and demo application as change magnets. F4D's
second app required its two source files, explicit module wiring, application
helper registration, one fast test root, and policy/docs because it established
a new protected boundary. It did not copy or edit `DemoApplication`. Future
ordinary apps do not need root build edits after the one-time `build/apps.zig`
introduction.

### C. Add a character-domain feature

The primary impact is the character/domain module, its explicit module edge,
and focused tests. Renderer/backend code changes only if the render contract
changes. Demo scenarios are optional clients, not definition owners.

### D. Add a non-character physics entity

F identity, lifetime, enabled state, hierarchy, transforms, snapshots, and
generic rendering are usable without character/demo ownership, as this proof
demonstrates. Current physics contains collision primitives and a specialized
character controller but no generic rigid-body component/runtime. Adding that
is future P-track domain work, not an F4D extraction blocker.

### E. Delete the historical demo application

No core reusable engine capability would disappear. The deletion would remove
scenario CLI routing, application actions, unique scenario integration and
visual/evidence fixtures, and the current command route that invokes renderer
GPU smoke through `DemoApplication`. The renderer, RuntimeScene, character,
interaction, queue, capture, definitions, and independent app remain
buildable. The GPU-smoke command would need a narrow new client route before
deletion.

## Static hypothetical demo-deletion probe

| Surviving dependency | Classification | Result if demo files disappeared |
| --- | --- | --- |
| Foundation, scene_core, renderer, queue, capture | NO BLOCKER | Remain independently reachable through `engine_smoke` and focused roots |
| Character, binding, interaction, animation, physics | NO BLOCKER | Remain production modules with independent CPU coverage |
| Existing `gpu-smoke` command routing | MINOR COMPATIBILITY DEPENDENCY | Renderer capability remains; command must be pointed at a non-demo client |
| `GpuDemo` four-line alias | F4E CLEANUP | No current code consumer; historical docs still name it |
| Scenario-specific CLI behavior and visual/evidence fixtures | NO BLOCKER | Expected application/acceptance capability, not core engine infrastructure |
| Transitional demo scenarios | F4E CLEANUP | Isolated clients; no lower production layer imports them |

There is no F4D blocker. `art_asset_demo` remains **RETIREMENT ELIGIBLE**:
production definitions live in `art_asset_catalog`, and neither F4D client nor
the independent proof depends on the scenario. Its focused integration value
must be mapped before any F4E retirement.

## Narrow proof-enablement fix

`Renderer.deinitWithMetrics` satisfies the F4D narrow-fix policy:

- renderer ownership and destruction were already established by F4C2;
- it delegates to the unchanged shutdown sequence;
- it returns a copied `ResourceMetrics` value only after cleanup;
- it exposes no mutable `State` or raw GPU handle;
- existing `deinit` behavior is retained;
- the physical second client verifies balanced resource and fence counts.

## Before/after structural metrics

| Metric | Before F4D | F4D candidate |
| --- | ---: | ---: |
| Independent production-rendering applications | 0 | 1 |
| Application build helpers | 0 | 1 (`build/apps.zig`, 67 lines) |
| Root `build.zig` lines | 245 | 235 |
| Concrete applications registered in root | 1 | 0 |
| New CPU proof tests | 0 | 3 |
| Independent app direct application/demo/evidence imports | not applicable | 0 |
| Independent steady queue allocations | not applicable | 0 |
| Independent steady GPU-resource creation delta | not applicable | 0 |

## Validation results

All commands below were run locally on Windows 11 with Zig 0.16.0 and `-j1`.
The reported elapsed values are machine-specific command/process observations,
not performance targets.

| Validation | Result |
| --- | --- |
| Baseline repository checker | PASS; 355 files, F2C/F4C1–F4C5 policy intact |
| Focused CPU proof + app build | PASS; 5/5 steps, 3/3 tests, `engine_smoke` compiled |
| Normal build | PASS; 22/22 steps |
| `check` | PASS; 25/25 steps, 384/384 tests; about 30 seconds |
| `test-full` | PASS; 38/38 steps, 481/481 tests; constituent stress route about 4 minutes |
| `test-content` | PASS; 60/60 steps, 279/279 tests |
| `verify` | PASS on unchanged retry; 89/89 steps, 671/671 tests |
| Existing GPU smoke | PASS; 24/24 steps, actual D3D12/DXIL, two instances, one indexed-instanced draw, pixel readback and cleanup; about 11 seconds |
| Independent physical app | PASS; 24/24 steps and metrics above; process about 1.3 seconds |
| Sprites route | PASS; 300 frames, 1,000 instances, one draw, zero steady allocation/resource growth |
| Integrated route | PASS; 2,400 frames/9,600 fixed ticks, all 16 milestones, one draw, zero steady growth; about 21 seconds |
| Handshake-IK route | PASS; 720 frames, three interactions, measured convergence, one draw, zero IK allocation/resources; about 7 seconds |
| Environment route | PASS; 720 frames, D3D12/DXIL, eight art pages, rollback checks; about 12 seconds |
| Historical evidence registration | PASS; 2/2 steps, retained routes reachable only on demand |
| F4D repository policy | PASS; 359 files, F2C/F4C1–F4D policy intact |
| Documentation validation | PASS; 46 required files, 42 Markdown files, 110 local targets before final record refresh |

The first `test-content` attempt exposed a retained F4C2 content-policy phrase
that still named the pre-F4C5 `app_module` variable. The implementation was
already wired correctly through `build/modules.zig`; the policy now checks the
actual `demo_entry_module` edge. The unchanged content gate then passed. No
content assertion, asset, hash, or threshold changed.

The first `verify` attempt had 658/658 completed tests pass but returned failure
because Zig's Windows listener did not receive an `environment-tests` response
within 1 minute 13 seconds. The unchanged retry passed 671/671. Other successful
aggregates also printed Zig's known listener `failed command` warning while
returning exit zero and reporting all tests passed; no test was weakened or
disabled.

The first physical engine-smoke execution completed all six frames and resource
teardown, then faulted while logging through a queue pointer whose renderer had
already been destroyed. The app now copies that already-observed allocation
count before teardown. The corrected supported build route passed twice with
balanced resources; no renderer behavior changed.

## F4D completion checklist

- [x] Exact post-F4C5 baseline, clean worktree, branch, upstream, and 0/0 synchronization verified.
- [x] Independent second composition root exists.
- [x] Independent app imports no `GpuDemo`.
- [x] Independent app imports no `DemoApplication`.
- [x] Independent app imports no `*_demo.zig`.
- [x] Independent app imports no historical evidence/report orchestration.
- [x] Source and build-injected transitive dependency proof confirms those boundaries.
- [x] Independent app uses the supported production renderer/backend.
- [x] Independent app creates and owns a real `RuntimeScene`.
- [x] A temporary F entity is created and promoted to world-persistent identity.
- [x] Entity identity, handle, lifecycle, enabled state, and transform are observed through supported read APIs.
- [x] Independent app renders through physical D3D12/DXIL.
- [x] Independent app executes six frames and six real draw submissions.
- [x] Resource, fence, queue-allocation, frame-capture, and shutdown checks pass.
- [x] No unexpected steady-state allocation or resource growth occurs.
- [x] CPU-only structural independence test exists and is in `check`.
- [x] Character/F binding operates without the demo application.
- [x] Production interaction starts, advances, completes, and cleans up without demo scenario authority.
- [x] Renderer/backend imports no demo module.
- [x] Existing demo application and four representative routes remain functional.
- [x] Static policy prevents forbidden independent-app and lower-layer dependencies.
- [x] F4C1 production ownership policy remains intact.
- [x] F4C2 renderer/application/evidence boundary remains intact.
- [x] F4C3 character/interaction authority remains intact.
- [x] F4C4 identity/input authority remains intact.
- [x] F4C5 build/test/policy architecture remains intact.
- [x] New app uses the F4C5 module catalog, application helper, engine-test helper, and gate composition.
- [x] No substantial new architecture refactor was performed.
- [x] All five requested blast-radius probes were reassessed.
- [x] Static demo-deletion capability probe was completed.
- [x] No core reusable engine capability remains demo-owned; only command/fixture compatibility remains.
- [x] Normal build passes.
- [x] `check` passes.
- [x] `test-full` passes.
- [x] `test-content` passes.
- [x] `verify` passes.
- [x] Existing physical GPU smoke passes.
- [x] Independent physical app passes.
- [x] Existing sprites, integrated, handshake-IK, and environment routes pass.
- [x] Historical evidence registration check passes.
- [x] Repository policy and documentation validation pass.
- [x] Diff and changed-file hygiene validation pass after the final record refresh.
- [x] F4E and downstream feature work did not begin.

## F4E inputs, not performed

- retire the four-line `GpuDemo` alias if its historical compatibility value is
  no longer needed;
- decide whether the legacy GPU-smoke command should use `engine_smoke`;
- map and potentially retire `art_assets` after preserving its focused test;
- normalize transitional demo route and prompt-era active-production names;
- separate stale historical documentation from normative current ownership;
- archive prompt evidence and compatibility aliases under explicit provenance.

## Scope attestation

- No broad production architecture redesign occurred.
- No renderer/backend design or rendering semantics changed.
- No character or interaction authority changed.
- No F identity/runtime or input behavior changed.
- No build gate taxonomy changed.
- No canonical model, geometry, art, asset, hash, or content changed.
- No demo or test was retired.
- No prompt-era naming migration or evidence archival occurred.
- F4E and downstream feature work did not begin.
