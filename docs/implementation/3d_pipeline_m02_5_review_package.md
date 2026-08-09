# M02.5 file-backed authority and M03 handoff review package

Date: 2026-08-09
Scope: M02.5 cleanup only
Disposition: **READY FOR OWNER REVIEW**
M03 status: **NOT STARTED**

## A. Original audit blockers

The approved audit found three blockers: a complete current-human definition
could be reconstructed through public Zig data, evidence still read some
current-human relationships and OPEN/TUNING numbers from those Zig tables, and
the M02-to-M03/testing documentation still described a pre-acceptance state.

## B. Authority after cleanup

There is now one supported asset-consumption path:

```text
assets/canonical_model/human_base/human_base.authoring.json
  -> canonical JSON parser
  -> generic canonical validation
  -> human structural validation
  -> canonical normalization
  -> LoadedHumanBase / CanonicalCreatureDefinition
       -> authorized future M03 consumer
       -> derived evidence consumer
```

`canonical_model.human_base.loadAuthoritative(allocator, io, diagnostics)`
implements that route. `LoadedHumanBase` explicitly owns the file bytes and
parsed allocations and must outlive borrowed definition/normalization views.
The byte-based lower-level entry point uses the same path and copies its input.
There is no static fallback and no renderer/runtime import.

The canonical JSON, structural report, hashes, and traces are derived evidence,
not source authority.

## C. Removed, privatized, and retained reconstruction code

Removed complete reconstruction API/data:

- `human_base.source` and its complete `components`, `bones`, `joints`,
  `controls`, `anchors`, `sockets`, `mount_anchors`, `attachments`, `landmarks`,
  `shared_seams`, `interaction_sites`, `effectors`, `regions`, `surfaces`,
  `material_definitions`, `material_instances`, and `visibility_metadata` arrays;
- `human_rig.bones`, `buildBones`, and source-only active/category helpers;
- `human_joints.joints` and `buildJoints`;
- `human_controls.controls`, `target_storage`, static `trace_count`, and their
  complete canonical-record builders;
- `human_attachments.anchors`, `sockets`, `mount_anchors`, `attachments`, and
  their canonical-record builders;
- `human_structural_semantics.landmarks`, `seam_members`, `shared_seams`,
  `interaction_sites`, `effectors`, and their canonical-record builders.

The public root no longer exports `human_rig` or `human_joints`. Narrow facades
expose only source-driven control traces and structural report helpers. The
human validation modules retain access to their internal expectations, but M03
is not offered those tables as asset constructors.

Intentionally retained human-specific hardcoded structures and exact reasons:

- `human_manifest` component/region/surface/material specs: required stable IDs,
  ownership, multiplicity, and material-contract validation;
- `human_rig.bone_specs` and component-follow specs: accepted hierarchy,
  deformation, mirror, ownership, and locked constituent-count validation;
- `human_joints.joint_specs` and mobility profiles: accepted typed mirror/range
  validation and stable invalid-fixture diagnostic contracts;
- `human_controls.control_specs`: required control IDs/categories/limits and
  target-shape validation; source-derived traces do not consume this table;
- `human_attachments` specs: required anchor/socket/mount/attachment identity,
  relationship, ground, mirror, and registration validation;
- `human_structural_semantics` specs: required landmark/seam/site/effector IDs,
  ownership, kinds, sides, and collision-proxy deferral;
- three numerical validator/test tolerances: explicitly test-only, never asset
  values.

Post-migration caller analysis found every retained table referenced by a human
validator or source-driven report classifier. No additional `PROVABLY_DEAD`
module or symbol was established, so no speculative deletion was made.

## D. Source-derived evidence proof

- Counts, inventories, parent chains, transforms, mirrors, registration records,
  materials, and measurements are read from the parsed definition.
- `traceCount(source)` and `generateTraces(source, output)` traverse actual
  canonical controls and driven targets with deterministic stable-ID ordering.
- The 142-line OPEN/TUNING inventory selects current material, rest, control,
  attachment, and joint values from canonical IDs/properties in the parsed
  source. Only the three validation-only tolerances originate in Zig.
- Five independent parse/validate/normalize/report iterations each produced the
  accepted 379,458-byte canonical payload and an exact string match to the
  accepted 204,166-byte report.

The explicit `update-human-base-evidence` tool now loads the authoritative JSON
and can write only derived evidence. Regression checks prove `test`, `check`,
`test-full`, and `verify` do not depend on that updater.

## E. Identity evidence

| Artifact | Bytes | SHA-256 | Result |
|---|---:|---|---|
| Authoritative authoring JSON | 604,786 | `c883274ae097dd373c152fdd70e474cffd5f2dfb9d9812cdb0a2f6d67ee3ff1e` | Unchanged |
| M02 canonical JSON | 379,458 | `7b579784f239d90ae9757a0aec1967fc37cf752733a4ac13409977f6f3212381` | Unchanged |
| M02 structural report | 204,166 | `56f63684b09d1e38c445ca4c22eff61701f632f96545dbf3cea9845ef696ab25` | Unchanged |
| M01 focused fixture | — | `2855fc11c0f8a1e5698af253c1a89eeb07483e5879556094ea4b6f29149b784b` | Unchanged |
| M01 Phase F fixture | 12,022 | `b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d` | Unchanged |

No evidence updater was run and none of the three committed M02 asset/evidence
files was modified.

## F. Test evidence

All successful commands used repository-local Zig 0.16.0 and `-j1`.

| Gate | Observed result |
|---|---|
| `test-canonical-human-identity` | 7/7 steps, 46/46 tests |
| `test-canonical-human-rig` | 10/10 steps, 58/58 tests |
| `test-canonical-human-joint-controls` | 13/13 steps, 70/70 tests |
| `test-canonical-human-structural` | 16/16 steps, 80/80 tests |
| `test-canonical-human-base` | 19/19 steps, 89/89 tests |
| Four M01 focused suites | 50/50 tests |
| `zig build test -j1` | 25/25 steps, 393/393 tests |
| `zig build check -j1` | 33/33 steps, 393/393 tests; formatting/static audits pass |
| `zig build verify -j1` | 50/50 steps, 505/505 tests |
| Stress within `verify` | 2/2 tests |

The first complete-gate attempt reached its 120-second outer command allowance
without an assertion failure and was not counted as a pass. The unchanged rerun
completed in 370.6 seconds with exit code zero and the totals above. The managed
cache did not produce `manifest_create AccessDenied`, so no host Debug fallback
was required.

## G. Documentation corrections

- `3d_pipeline_start_here.md`: M02 owner-accepted, M02.5 handoff current, M03
  unstarted, and the exact loader API documented.
- `3d_pipeline_milestone_02.md`: historical specification marked completed and
  owner-accepted.
- `3d_pipeline_m02_review_package.md`: owner-accepted disposition and M02.5
  file-backed handoff note.
- `TESTING.md`: 50 M01 and 53 M02 declarations, all five M02 targets, tier
  relationships, and updater isolation.
- downstream creature-interaction ADR: inherited origin and tongue wording now
  defers to the canonical model ADR and matches the accepted M02 structure.

## H. M03 handoff

The only documented supported M03 path is:

```zig
var human = try canonical_model.human_base.loadAuthoritative(
    allocator,
    io,
    diagnostic_storage,
);
defer human.deinit();
const definition = human.definition();
```

M03 must not use the canonical JSON, report, hashes, traces, internal validation
tables, current 2D anatomy/skeleton/component graph, or renderer registration
data as source authority. M03 remains unauthorized until its explicit brief.

## I. Deferred requirements

M03 still owns continuous quad-oriented human geometry, deterministic
triangulation, real semantic membership and seam rings, surface coordinates,
UVs, material-to-geometry assignment, and geometry-informed collision-proxy
creation/fitting before the first resolved-human-geometry acceptance boundary.
Skinning, morphology/correctives, derived sex-typical profiles, soft tissue,
contact/state response, garments, and 3D-to-2D export remain later work.

## J. Remaining uncertainty and dead code

No blocking M03 handoff issue remains. Internal validator expectation tables
deliberately repeat required stable IDs and some accepted diagnostic contracts;
they are not public asset constructors and no evidence generator reads their
current numeric values as source authority. Future reviewed OPEN/TUNING source
changes may require corresponding validator-contract review, but no values were
changed or reclassified in M02.5.

The active 2D runtime and schema 1.0 compatibility paths remain intact. No M03
implementation was started.
