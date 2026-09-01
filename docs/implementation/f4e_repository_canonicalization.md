# F4E repository canonicalization

Status: **F4E implementation candidate — awaiting owner review**
Date: 2026-08-31
Starting baseline: `ff65ac7219deca6402da7b4c06fec80c81268781`

F4E changes repository naming, current/history presentation, compatibility
residue, active asset authority, and scenario hygiene only. It does not change
renderer, `RuntimeScene`, character, interaction, input, canonical schema,
topology, or content semantics. F4 remains not yet accepted.

## Starting state

The baseline was clean `master`, synchronized with `origin/master` at the exact
commit above (`0` ahead, `0` behind). Zig reported exactly `0.16.0`. The current
repository and documentation checkers passed before changes. The independent
`engine_smoke` client, F4C5 modular gate architecture, and F4D acceptance record
were present.

## Pre-F4E provenance inventory

The complete tracked checkout contained 928 files and 801,254,217 bytes. A
path-level prompt/milestone scan found 515 historically named paths:

| Area | Historically named tracked paths | Primary classification |
|---|---:|---|
| `assets` | 418 | Protected canonical geometry lineage, active atlas names, and rejected art |
| `docs` | 69 | Prompt sources, decisions, reports, and recent implementation provenance |
| `tests` | 15 | Protected golden/geometry lineage plus one F4C4-named current test root |
| `tools` | 12 | Current content audits and explicit historical evidence tools |
| top-level prompt source | 1 | Historical source record |

The repository contained 300 PNG files (409,205,156 bytes), 84 PPM files
(322,772,534 bytes), and 402 files under `assets/canonical_model`
(758,566,790 bytes). Canonical human geometry evidence alone contained 396
files and 720,106,824 bytes. Size therefore primarily reflects protected
current qualification/lineage rather than abandoned runtime assets.

Meaningful occurrences were classified as follows:

| Category | Included families | Disposition |
|---|---|---|
| Current production — canonicalize | ten runtime atlas filenames/install paths; primary executable; GPU-smoke ownership; art scenario route; current build descriptions | Domain names, production smoke client, or retirement with permanent tests |
| Current validation — canonicalize | environment/anatomy audit tools, visual-geometry golden checker, F4C4-named boundary test, current report steps | Domain tool/test/step names |
| Protected authority/compatibility | canonical human schema IDs, accepted geometry evidence/goldens, predecessor comparison images, stable runtime IDs | Preserve bytes/IDs; record mappings in manifests |
| History | prompt sources, prompt-era decisions, old reports, rejected images, predecessor images | Move beneath explicit history roots; retain historical terminology |
| Obsolete | four-line `GpuDemo` alias and runtime `art_assets` scenario shell | Remove after consumers/policy and permanent coverage were migrated |

Generic uses of words such as `candidate` in selection algorithms and
`MilestoneId` in bounded runtime diagnostics were not historical-development
names and were not renamed.

## Protected-file watch

The protected set for this phase is:

- all canonical model, schema, geometry, topology, golden, and hash authority;
- `src/foundation`, `src/scene_core`, and accepted F architecture contracts;
- active runtime atlas bytes and current content-qualification fixtures;
- accepted predecessor images used by pixel-delta audits;
- historical geometry evidence consumed by current tests/tools.

No protected canonical file is removed or content-modified. Runtime PNG moves
are byte-preserving and their accepted pre-move SHA-256 values are recorded in
`assets/manifest.json`.

## Production naming migrations

| Former current name | Canonical current name |
|---|---|
| `p23_mechanical_atlas.png` | `mechanical_atlas.png` |
| `p23_energy_atlas.png` | `energy_atlas.png` |
| `p25_wardrobe_upper_atlas.png` | `wardrobe_upper_atlas.png` |
| `p25_wardrobe_layers_atlas.png` | `wardrobe_layers_atlas.png` |
| `p25_wardrobe_lower_atlas.png` | `wardrobe_lower_atlas.png` |
| `p26_violet_crystal_ruin_atlas.png` | `environment_violet_crystal_ruin_atlas.png` |
| `p26_neutral_debug_atlas.png` | `environment_neutral_debug_atlas.png` |
| `p27c_male_base_anatomy_atlas.png` | `male_base_anatomy_atlas.png` |
| `p27c_female_base_anatomy_atlas.png` | `female_base_anatomy_atlas.png` |
| `p27c_anatomy_components_atlas.png` | `anatomy_components_atlas.png` |
| `skeletal_gpu_demo.exe` | `engine_sandbox.exe` |
| `audit_p26_environment_art.ps1` | `audit_environment_art.ps1` |
| `audit_p27c_art.ps1` | `audit_anatomy_art.ps1` |
| `audit_p27c_r1_torso.ps1` | `audit_anatomy_torso.ps1` |
| `check_p25d_goldens.ps1` | `check_visual_geometry_goldens.ps1` |
| `reauthor_p27c_anatomy.ps1` | `author_anatomy_art.ps1` |
| `tests/f4c4_adoption_tests.zig` | `tests/scene_binding_boundary_tests.zig` |
| `test-f4c4-adoption` | `test-scene-binding-boundaries` |
| `p27c-anatomy-report` | `anatomy-quality-report` |

Stable art page names and mesh/material identifiers that may participate in
accepted runtime identity are not silently rewritten. Their prompt-era spellings
are compatibility-protected and mapped to domain-named files by the manifest.
The P25A/P25B predecessor filenames also remain because their generation labels
are the identity used by accepted comparison tooling.

## Active asset authority

`assets/manifest.json` is the single active source/runtime asset manifest. Each
entry records the logical name, tracked path, install path when applicable,
authority class, format, dimensions, size, SHA-256, consumer, predecessor name,
and regeneration tool when one exists. All ten active runtime pages are
truthfully classified as `active_binary_source`: the tracked PNG is the
authoritative starting material unless/until a layered editable source is
provided. The manifest does not invent an authoring source.

Build installation, production references, current tests, audits, and reports
use the canonical paths. Atlas pixel bytes, UVs, coordinates, dimensions, and
content are unchanged.

## Historical art and evidence retention

`assets/history/manifest.json` records the recovery baseline, classification,
authority relationship, paths, counts/sizes, hashes where practical,
reproduction notes, and disposition.
The content-policy gate resolves every listed path and verifies each declared
family file count and byte total, so the manifest cannot silently drift from
the retained checkout.

| Family | Current role | Authority | References | Reproducible | Final disposition |
|---|---|---|---|---|---|
| P24A base atlases | Predecessor provenance | None current | Historical records | Git-recoverable | MOVE TO HISTORY |
| rejected anatomy candidates | Rejection provenance | Explicitly not runtime | Review notes/audits | Bytes retained; no editable source claimed | MOVE TO HISTORY |
| P25A/P25B atlas predecessors | Current pixel-delta qualification | Protected validation lineage | Anatomy audits | Yes, via current audits | KEEP CURRENT VALIDATION |
| `prompt_2b` geometry evidence | Scaffold tests/conversion | Protected | Current tests/tools | Registered tools | KEEP HISTORICAL IN PLACE |
| `prompt_2c` and `prompt_2c_r1` | Refinement tests/export | Protected | Current tests/tools | Registered tools | KEEP HISTORICAL IN PLACE |
| `prompt_2c_t2_hm08` | Accepted qualification chain | Accepted lineage | Implementation/qualification records | Git/tool lineage | KEEP HISTORICAL IN PLACE |
| `prompt_2c_t3_hm08_adoption` | Current adoption tests | Protected | Current tests/tools | Registered tools | KEEP HISTORICAL IN PLACE |
| `prompt_2c_r3` | Current neutral-adaptation tests | Protected | Current tests/tools | Registered tools | KEEP HISTORICAL IN PLACE |
| `prompt_2c_r4` | Final neutral authority | Protected current authority | Current final qualification | Registered tools | KEEP ACTIVE |
| P25D goldens | Current visual qualification | Protected validation | `test-content` | Golden checker | KEEP CURRENT VALIDATION |
| prompt/review documents | Non-normative provenance | None over current docs | History index | Git | MOVE TO HISTORY |

No historical binary family was deleted from HEAD. The audit could not prove
that the large canonical geometry families were disposable without weakening
accepted lineage or current tests, so they remain deliberately retained.

## Compatibility and scenario cleanup

The four-line `src/graphics/gpu_demo.zig` alias had no current consumer and is
removed. Repository policy now enforces direct `engine_smoke` use of the
production `Renderer` and rejects demo imports on that path.

`gpu-smoke` now invokes `engine_smoke --gpu-smoke`. That path performs the same
renderer initialization fault matrix, runtime replacement/fence fault checks,
physical D3D12/DXIL draw/readback smoke, and balanced resource/fence shutdown
without entering `DemoApplication`.

The `art_assets` runtime route is retired. Its `Scene` is moved to
`tests/support/art_pipeline_fixture.zig`, where `test-art` retains semantic
resolution, two-page sprite/mesh submission, decode, and allocation coverage.
Production art definitions remain in `src/scene/art_asset_catalog.zig`.

Surviving scenarios are classified as follows:

- current engine sandbox: `sprites`, `controller`, `playground`,
  `side-scroller`, and `foundation`;
- current integration/interaction fixtures: `handshake-ik`, `integrated`,
  `modular-body`, `equipment`, and `mesh-attachments`;
- current content/acceptance scenarios: `wardrobe`, `visual-quality`,
  `anatomy-quality`, and `environment`.

`DemoApplication` remains an accurate name for the scenario-oriented client.
The executable changes to `engine_sandbox` because it is the general interactive
client, not the engine library or a skeletal-renderer-only prototype.

The specialized `character.EntityId` name remains for now. It is a private,
runtime-only ordering/lookup key with broad internal consumers, while F
`EntityId` is the sole persistent scene authority and repository policy prevents
the legacy type from escaping that boundary. Renaming the internal key would
create widespread compatibility churn without changing or clarifying a public
contract, so it is classified **STILL NEEDED** rather than silently migrated.

## Documentation architecture

Normative current documents are `AGENTS.md`, the root `README.md`,
`docs/ARCHITECTURE.md`, `docs/DEPENDENCIES.md`, `docs/TESTING.md`,
`docs/CONTROLS.md`, `docs/project/CURRENT_STATE.md`, and accepted subsystem
contracts under `docs/architecture`.

Prompt sources, prompt-era owner decisions, and old implementation reports now
live under `docs/history/{prompts,source-prompts,decisions,reports}`.
`docs/history/README.md` explicitly marks them non-normative and explains Git
recovery. Recent F1-F4 implementation records remain under
`docs/implementation` because they are still the readily accessible acceptance
provenance for current architecture; current normative documents summarize the
rules needed for ordinary work.

## Build/check policy

F4C5 modular ownership is preserved. Application registration remains in
`build/apps.zig`; test-only art integration is registered by the test helpers;
current content audits use domain names; historical Prompt 27 review packages
remain reachable only from the history evidence domain. Root `build.zig` does
not acquire new concrete app/test/tool registrations.

The repository checker now protects the absence of `GpuDemo`, the independent
production GPU-smoke route, the retired production art scenario, domain test
registration, active asset paths, and existing F4C/F4D dependency boundaries.

Engine and content test roots now select the simple runner bundled with the
pinned Zig 0.16.0 toolchain. Three separate aggregate attempts had failed in
the server listener after tests had completed or before an assertion result;
the same declarations then passed under the simple runner. This is a protocol-
only reliability correction: gate membership, assertions, focused targets,
and the F4C5 taxonomy are unchanged.

## Readability and independence probes

A new developer can determine the ten required facts without history:

1. The root README identifies the Windows SDL3 GPU 2D engine.
2. README and `DEPENDENCIES.md` give exact build/bootstrap requirements.
3. `zig build run` and `engine_sandbox` identify the sandbox.
4. `run-engine-smoke` identifies the independent engine client.
5. `ARCHITECTURE.md` and the shared foundation contract explain entities/scenes.
6. `ARCHITECTURE.md` and `SPRITE_BATCH.md` explain renderer ownership.
7. `ARCHITECTURE_MAP.md` identifies character runtime ownership.
8. `TESTING.md` defines gates and change-based guidance.
9. `assets/manifest.json` identifies current assets and source authority.
10. `docs/history/README.md` identifies non-normative provenance.

Removing `docs/history` from a conceptual clean checkout would not prevent a
developer from building, testing, understanding, or extending the engine.
Removing historical scenario files after preserving their unique tests and
acceptance fixtures would remove no core reusable engine capability.

## Repository metrics after cleanup

The intended working-tree result contains 931 files and 801,270,782 bytes,
compared with 928 files and 801,254,217 bytes at baseline: a net increase of
three files and 16,565 bytes. F4E establishes manifests and indexes rather than
chasing size reduction.

| Classification | Files | Bytes | Notes |
|---|---:|---:|---|
| Active runtime atlas pages | 10 | 7,404,266 | Every installed runtime page in `assets/manifest.json` |
| Protected atlas comparison lineage | 3 | 1,565,537 | P25A/P25B predecessors retained for current audits |
| Canonical/current qualification | 402 | 758,566,790 | `assets/canonical_model`; includes protected accepted lineage used by current tests |
| Explicit historical art | 10 | 4,908,469 | Nine moved predecessor/rejected records plus the history manifest |
| Explicit historical documents | 64 | 720,233 | 63 moved records plus the history index |

Seventy-two files moved into explicit history roots. No historical binary bytes
were deleted from HEAD because the large geometry families remain referenced by
current qualification or accepted lineage. The active scenario surface is 14
routes after retiring `art_assets`.

## Prompt/milestone scan after cleanup

The final literal scan uses `Prompt|prompt|P23..P27|F4C|F4D|owner_review` and
distinguishes raw occurrences from unjustified active identity:

| Area | Raw occurrences | Files | Classification |
|---|---:|---:|---|
| Production source | 171 | 31 | Historical evidence fields/routes, accepted canonical provenance IDs, and scenario acceptance diagnostics; no generic engine API or runtime asset path depends on them |
| Active build helpers | 56 | 2 | `build/evidence.zig` historical reproduction and protected content-test descriptions only |
| Normative/current docs | 343 | 8 | Explicit history mappings, accepted-decision status, and protected command/ID references; current architecture and workflow are stated independently at the start of each document |
| Current validation | 859 | 46 | Accepted golden, canonical lineage, and historical acceptance identifiers retained by tests/tools |
| Explicit history docs | 1,753 | 64 | Intentionally historical and non-normative |

Active installed runtime atlas paths contain zero prompt/milestone names. Three
prompt-named art paths remain only as protected P25A/P25B comparison lineage.
The scan found zero unexplained obsolete compatibility paths and zero
unjustified prompt names in generic production APIs.

## Validation results

Baseline repository and documentation checks passed before modification. Final
validation produced these observed results:

- normal build: 22/22 steps;
- `check`: 25/25 steps and 384/384 tests;
- `test-full`: 38/38 steps and 481/481 tests;
- `test-content`: 60/60 steps and 279/279 test declarations, including
  196/196 focused and 6,954/6,954 pose/morphology geometry checks;
- `verify`: 89/89 steps, composing all three CPU gates;
- `gpu-smoke`: 24/24 steps through `engine_smoke --gpu-smoke`, physical
  Direct3D 12/DXIL, two instances in one indexed draw, readback, fault matrix,
  and balanced cleanup;
- independent engine smoke: 24/24 steps, six frames, six draw calls, 15,129
  changed readback pixels, 17/17 resources released, and 8/8 fences released;
- sandbox sprites: eight frames, 1,000 instances, one draw, zero steady-state
  allocation or resource growth;
- integrated F runtime: 2,400 frames/9,600 fixed ticks, one completed handshake,
  zero runtime allocation/resource delta, and clean final ownership;
- handshake IK: 720 frames covering nominal, mirrored, and perturbed runs with
  sub-micrometre post-solve separation and zero solver allocation;
- environment: exact 720-frame scripted route, eight decoded production art
  pages, rollback fault checks, and exit code zero;
- historical registration: 2/2 steps;
- repository checker: 360 implementation/policy files, current F2C/F4C1-F4E
  boundaries passed;
- content policy: 271 source files plus art, canonical, golden, manifest, and
  lineage audits passed;
- documentation: 46 required files, 42 Markdown files, and 94 local targets;
- all ten renamed runtime PNGs matched their baseline SHA-256 byte for byte;
  canonical/content identity gates retained their accepted hashes.

The first sandbox environment attempt used 600 frames and was correctly
rejected by the source-enforced 720-frame contract; the exact route then
passed. Earlier sandboxed build attempts also reproduced the known Windows Zig
cache `AccessDenied` condition. Three server-listener attempts failed on
different test processes; after the protocol-only runner correction, every
required aggregate passed. One transient read of Zig's own standard library
failed during recompilation and the focused clean-cache retry passed all six
component-graph tests.

## Scope attestation

No renderer/backend architecture, character/interaction authority, F
identity/runtime, input architecture, build taxonomy, canonical schema,
serialization version, or topology is redesigned. No downstream feature work
began. F4 is not self-approved.
