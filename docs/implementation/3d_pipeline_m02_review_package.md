# M02 final engineering review package

Date: 2026-08-09  
Scope: Prompt 3 audit only  
Disposition: **OWNER-ACCEPTED**
M03 status: **NOT STARTED**

This package audits the complete M02 implementation against the M02 brief, the
canonical decision record, the start-here contract, every Prompt 1 through 2E
owner decision, the current testing policy, and the accepted M01 evidence. The
accepted M02 structural golden was preserved. One in-scope Prompt 3 defect was
found and corrected: the evidence exporter previously constructed and rewrote
the readable authoring file from Zig data. It now reads that file as the sole
authoritative M02 human source and can write only derived evidence.

The principal offline inspection artifact remains
[`human_base.structural_report.txt`](../../assets/canonical_model/human_base/human_base.structural_report.txt).
This package audits and indexes that report; it does not introduce a parallel
structural evidence format.

**M02.5 handoff note:** the accepted authoring JSON remains the sole source.
Downstream canonical work must load it through
`canonical_model.human_base.loadAuthoritative(allocator, io, diagnostics)`,
which owns the file bytes and parsed definition and performs generic validation,
human structural validation, and normalization. The canonical JSON, structural
report, hashes, and traces remain derived review evidence.

## A. Executive status

M02 is owner-accepted. There are no failing M02 requirements
and no M03 structural blocker. Two matters remain deliberately deferred by
owner decision: derived male/female configuration profiles and empirically
fitted structural collision proxies. The latter is a hard carry-forward gate:
proxies must be created and fitted after real human geometry exists and before
acceptance of the first resolved-human-geometry snapshot.

### Definition of Done

| # | Requirement | Classification | Evidence |
|---:|---|---|---|
| 1 | Real canonical `human_base` using M01 | PASS | File-backed authoring source, normalized golden, parser, M01 records, and 9/9 acceptance tests. |
| 2 | Coordinate/origin/height/A-pose contract | PASS | Report header, transform evidence, and rig tests; height is exactly `1.8288 m`. A-pose angles remain asset-level OPEN/TUNING. |
| 3 | Explicit single-parent component tree | PASS | 48-component report tree and structural validation. |
| 4 | Complete approved human skeleton | PASS | 149-bone report tree and rig validation. |
| 5 | Required constituent bone/control counts | PASS | Focused structural, rig, joint/control, and acceptance suites. Aggregate totals are accepted M02 manifest counts, not universal architecture locks. |
| 6 | Deterministic local-to-global derivation | PASS | Local-only source transforms and repeated derived-transform evidence. |
| 7 | Measurable neutral bilateral mirroring | PASS | Mirror records, coordinate samples, positive/negative fixtures, and tolerance-qualified validation. |
| 8 | Required joint/control records | PASS | 148 joints, 116 controls, 12/12 joint/control tests, and deterministic traces. |
| 9 | Anchors/sockets/mounts | PASS | 106 anchors, 22 sockets, and 20 mount anchors with distinct validated reference types. |
| 10 | Stable landmarks and deterministic measurements | PASS | 35 landmarks and deterministic measurement/report generation. |
| 11 | Shared seams without fake geometry data | PASS | 11 structural seam identities; no UV, ring, vertex, or atlas-coordinate claims. |
| 12 | Structural surfaces/regions without fake membership | PASS | 206 regions and 206 surfaces; structural semantics only. |
| 13 | Interaction sites/effectors | PASS | 25 sites and 6 effectors, including named adult-anatomy identities. |
| 14 | One base rig with owner-approved optional state | PASS | One `human_base`; anus enabled, vulva/vaginal-canal, penis, and scrotum/testicles disabled. This owner decision supersedes the brief's earlier blanket-disabled wording. |
| 15 | Collision-proxy implementation or approved deferral | DEFERRED BY APPROVED OWNER DECISION | `defer_from_m02`, count 0; no runtime 2D AABB substitution. |
| 16 | Deterministic readable input/normalization/serialization/hash | PASS | Authoring file is read through the real parser; round trip, equivalent input, five-repeat, and mutation tests pass. |
| 17 | Accepted M02 golden; immutable M01 goldens | PASS | All three accepted hashes reproduced. |
| 18 | Precise invalid diagnostics and no silent repair | PASS | 17 file-backed parser fixtures; exact diagnostics reproduced twice; zero-capacity large-source test fails explicitly. |
| 19 | Renderer/runtime independence | PASS | Forbidden-import audit and module dependency review pass. |
| 20 | M01.5 test tier structure intact | PASS | `test`, `check`, filtered deterministic, `test-full`, `test-stress`, `verify`, and specialized steps remain active. |
| 21 | Final `verify -j1` | PASS | 50/50 steps and 505/505 tests, including 2/2 stress. |
| 22 | Review package complete | PASS | This document, backed by the accepted structural report and final commands below. |
| 23 | No mesh/skinning/sculpting/garment/atlas/M03 work | PASS | Scope and source scans are clean; M03 was not begun. |

## B. Implemented architecture

### Files and modules

M02 extends the M01 canonical subsystem without introducing renderer ownership.
The implemented human-specific modules are:

- `src/canonical_model/human_base.zig`
- `src/canonical_model/human_acceptance.zig`
- `src/canonical_model/human_rig.zig`
- `src/canonical_model/human_joints.zig`
- `src/canonical_model/human_controls.zig`
- `src/canonical_model/human_measurements.zig`
- `src/canonical_model/human_attachments.zig`
- `src/canonical_model/human_structural_semantics.zig`
- `src/canonical_model/human_validation.zig`
- `src/canonical_model/human_joint_control_validation.zig`
- `src/canonical_model/human_structural_validation.zig`
- `src/canonical_model/human_evidence.zig`

The existing M01 records were extended in `attachment.zig`, `diagnostics.zig`,
`rig.zig`, `root.zig`, `semantics.zig`, `serialization.zig`, and
`validation.zig`; `root.zig` wires the human modules into the canonical model.
`build.zig` supplies focused test steps and the explicit updater.
`tools/export_human_base_evidence.zig` is the file-driven derived-evidence
exporter.

The five focused test roots are:

- `tests/canonical_human_identity_tests.zig`
- `tests/canonical_human_rig_tests.zig`
- `tests/canonical_human_joint_control_tests.zig`
- `tests/canonical_human_structural_tests.zig`
- `tests/canonical_human_base_acceptance_tests.zig`

The asset set comprises the authoring JSON, normalized canonical JSON,
structural report, asset README, and 17 parser-backed invalid JSON fixtures
under `tests/fixtures/canonical_model/human_base/invalid/`.

### Accepted M02 manifest counts

These are the accepted current M02 manifest totals. They are not all universal
LOCKED architecture counts.

| Record | Count |
|---|---:|
| Components | 48 |
| Bones | 149 |
| Active shared bones | 140 |
| Optional penis sub-rig bones | 9 |
| Joints | 148 |
| Controls | 116 |
| Animator-facing spine controls | 5 |
| Regions | 206 |
| Surfaces | 206 |
| Material definitions / matching instances | 11 / 11 |
| Anchors | 106 |
| Sockets | 22 |
| Mount anchors | 20 |
| Attachments | 20 |
| Landmarks | 35 |
| Shared seams | 11 |
| Interaction sites | 25 |
| Effectors | 6 |
| Collision proxies | 0, approved deferral |

The report's historical `LOCKED_COUNTS` heading is retained to preserve the
accepted 204,166-byte artifact. For owner-review terminology, its aggregate
values are interpreted as **accepted M02 manifest counts**. Specifically locked
constituents include one root and pelvis relation, seven spine deformation
bones, three neck deformation bones, five animator-facing spine controls, two
twist deformation bones per required limb segment, the approved 3-bone thumb
and 4-bone non-thumb finger chains, 2-bone big-toe and 3-bone other-toe chains,
four shared tongue deformation bones, six eyelid deformation bones per default
eye, and seven penis shaft deformation bones when that module is enabled.

The material inventory is cornea, gums, iris, lips, nails, oral mucosa, pupil,
sclera, skin, tongue, and tooth enamel. Each has a stable definition/instance
identity. Their current colors are OPEN/TUNING.

### Ownership and optional state

- There is one asset ID, `human_base`, with one logical `body` component root.
- There is one `skeleton_root`; pelvis is its child.
- Torso remains a semantic/geometry owner driven structurally by pelvis, spine,
  clavicles, and scapulae. No monolithic torso deformation bone was introduced.
- There are no separate male/female body definitions or skeletons.
- Anus is present/enabled. Vulva/vaginal-canal, penis, and scrotum/testicles are
  present/disabled. Each current optional module is zero-or-one.
- Formal male/female derived configuration profiles remain owner-approved
  deferred work; their absence does not weaken the shared-base rule.
- Collision proxies are absent by `defer_from_m02`; the canonical solution must
  be fitted against real geometry and must not reuse runtime 2D AABBs.

## C. Deterministic source evidence

| Evidence | Observed value |
|---|---|
| Sole authoritative source | `assets/canonical_model/human_base/human_base.authoring.json` |
| Authoring source | 604,786 bytes; SHA-256 `c883274ae097dd373c152fdd70e474cffd5f2dfb9d9812cdb0a2f6d67ee3ff1e` |
| Normalized golden | `assets/canonical_model/human_base/human_base.canonical.json` |
| Golden bytes | 379,458 |
| Final byte | `0x7d` / `}` |
| Trailing newline | None |
| M02 SHA-256 | `7b579784f239d90ae9757a0aec1967fc37cf752733a4ac13409977f6f3212381` |
| Controlled mutation SHA-256 | `a2d3f693da22166a1bad2f711741bf56417283795d52614485c89a2d9272752a` (sensitivity evidence only) |
| Structural report | 204,166 bytes; SHA-256 `56f63684b09d1e38c445ca4c22eff61701f632f96545dbf3cea9845ef696ab25` |
| M01 Prompt 2C fixture | `2855fc11c0f8a1e5698af253c1a89eeb07483e5879556094ea4b6f29149b784b` |
| M01 Phase F fixture | `b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d` |

The acceptance route proves canonical parse/normalize/serialize byte identity,
equivalent-input identity, five identical repeat outputs and reports, and a
changed hash for the controlled mutation. The executable Zig manifest mirror
is acceptance-tested byte-for-byte against the normalized file-backed source;
it is test/construction support, not an independent authority.

### Golden-update policy audit

- `update-human-base-evidence` is the only authoring/update command.
- It reads the authoritative authoring JSON and writes only the normalized
  golden, the invalid fixtures, and the structural report.
- It never writes or repairs the authoritative authoring JSON.
- `test`, `check`, `test-full`, and `verify` do not depend on the updater run
  artifact. `check` compiles the exporter to keep it buildable but does not run
  it.
- A focused static regression inspects these build/export boundaries.
- A content manifest over all 20 evidence files (authoring, golden, report, and
  17 invalid fixtures) was identical before and after ordinary gates:
  SHA-256 `85abc781d40594ad45388e248b1f4fa9346e9e0d9130452066d604246c5787a8`.

Therefore an ordinary-gate mismatch remains a failure until an explicit,
reviewed source/contract change invokes the updater intentionally.

## D. Structural evidence

The accepted report contains the authoritative review views at these headings:

- `COMPONENT_TREE`: all 48 records and parentage.
- `SKELETON_TREE`: all 149 bones, local rest transforms, mirrors, and derived
  parent chains.
- `MEASUREMENTS_METERS` and `KEY_COORDINATES`: measurements plus bilateral
  shoulder, elbow, wrist, hip, knee, ankle, eye, ear, heel, and toe evidence.
- `ANCHOR_INVENTORY`, `SOCKET_INVENTORY`, `MOUNT_INVENTORY`, and
  `ATTACHMENT_INVENTORY`: distinct reference kinds and transforms.
- `LANDMARK_INVENTORY`: 35 named structural references and coordinates.
- `SEAM_INVENTORY`: 11 shared structural identities without fake rings.
- `INTERACTION_SITE_INVENTORY` and `EFFECTOR_INVENTORY`: 25 sites and 6
  effectors.
- `OPTIONAL_MODULE_STATE` and `ADULT_ANATOMY_REQUIRED_IDENTITIES`: explicit
  neutral states and inspectable adult-anatomy structural identities.
- `INVALID_FIXTURE_DIAGNOSTICS`: the exact negative matrix.
- `OPEN_TUNING_CLASSIFICATION` and `OPEN_TUNING_VALUES`: the complete current
  provisional inventory.

The coordinate record is right-handed, +X right, +Y up, +Z forward, meter
units, with the origin centered between the feet on ground Y=0 in A-pose.
Source authority is local transforms only; global values are deterministically
derived. Representative global evidence includes shoulders at
`(-0.17500001, 1.4500003, 0)` and `(0.17500001, 1.4500003, 0)`, hips at
`(-0.1, 0.95, 0)` and `(0.1, 0.95, 0)`, and heel contacts at Y approximately
`-5.59e-9`, within the documented `0.00001 m` validation tolerance.

Only total height, `1.8288 m`, is LOCKED. Current structural/reference
measurements are shoulder breadth `0.350000`, hip breadth `0.200000`, A-pose
arm span `1.630712`, torso length `0.560000`, leg length `0.950000`, upper-arm
length `0.310000`, forearm length `0.270000`, thigh length `0.450000`, lower-leg
length `0.430000`, hand length `0.145000`, foot length `0.260000`, and head
reference height `0.308800` meters. These are OPEN/TUNING rig measurements,
not final visible-body anthropometric or mesh-surface claims.

Collision-proxy inventory: zero. Status:
`DEFERRED BY APPROVED OWNER DECISION`.

## E. Joint/control evidence

The report's `JOINT_INVENTORY` records all 148 joints, drive bones, mirror
references, preferred mobility, hard limits, stiffness, and swing/twist data.
All angles are normalized to radians. Representative reproduced values are:
shoulder hard X max `2.61799400`, elbow preferred Z max `2.09439520`, hip hard
X max `2.09439520`, knee hard X max `2.61799400`, eye twist max `0.26179940`,
and twist-bone swing Y max `0.05235988`.

The 116 controls comprise 102 local-space and 14 character-space controls;
there are zero current world-space and target-relative controls. The inventory
includes five spine controls, limb FK controls, hand/foot IK targets and pole
controls, finger/toe structural controls, and eye/lid/tongue structural
controls. Every control has an explicit target and drive reference. The report
contains deterministic target/parent/relevant-joint traces; for example,
`hand_left_ik_target` targets `bone:hand_left`, mirrors
`hand_right_ik_target`, uses character space, and traces to
`hand_left_joint`.

No IK, gaze, blink, grasp, tongue, grounding, or other solver was implemented
in M02.

## F. Validation evidence

All invalid fixtures are readable JSON parsed through the real authoring parser
and fail closed without repair:

1. missing skeleton root;
2. multiple skeleton roots;
3. wrong pelvis parent;
4. wrong spine count;
5. wrong neck count;
6. wrong arm twist count;
7. wrong leg twist count;
8. malformed finger chain;
9. malformed toe chain;
10. bilateral mirror mismatch;
11. foot contact off ground;
12. canonical height mismatch;
13. missing required landmark;
14. missing required seam;
15. socket/anchor mismatch;
16. interaction site missing owner;
17. invalid optional-module multiplicity.

Representative exact diagnostics include:

- `missing_skeleton_root`, object `bone`, ID `skeleton_root`, property
  `bone_id`, message `required skeleton_root is absent`;
- `socket_anchor_mismatch`, object `socket`, ID `hair_socket`, property
  `anchor_id`, message `socket references the wrong or a missing structural anchor`;
- `missing_interaction_site_owner`, object `interaction_site`, ID
  `palm_left_site`, property `owner_component_id`, message
  `interaction site owner is missing or does not match the accepted manifest`.

Each fixture is run twice and compared for exact code, object type, ID,
property, message, and deterministic ordering. Validation stops at the intended
structural diagnostic rather than emitting cascading noise. The diagnostic
collector sorts deterministically by code, object type, object ID, property,
reference type, reference ID, and message. Capacity is explicit: a zero-slot
collector applied to the real 604,786-byte source returns
`DiagnosticCapacityExceeded`; diagnostics are not silently truncated.

## G. Test/build evidence

All commands used repository-local Zig 0.16.0 and `-j1` where required.

| Gate | Result |
|---|---|
| Zig version | PASS: `0.16.0` |
| Focused `test-canonical-human-base` | PASS: 89/89 |
| Explicit M01 canonical suites | PASS: 50/50 |
| `zig build test` | PASS: 393/393 |
| `zig build check` | PASS: 33/33 steps, 393/393 tests, formatting and repository audits |
| `zig build test-full` | PASS: 38/38 steps, 503/503 tests |
| Filtered deterministic `skeleton` route | PASS: 15/15 |
| Managed Debug build | INFRASTRUCTURE OBSERVATION: `manifest_create AccessDenied` during Zig cache check; no assertion failure |
| Identical host Debug build | PASS: 20/20 steps, linked executable plus three HLSL/DXIL shader compilations |
| `zig build verify` | PASS: 50/50 steps, 505/505 tests |
| Stress within `verify` | PASS: 2/2, approximately 3 minutes |

The test runner prints `failed command` for successful tests that write
diagnostic/evidence output while using Zig's listen protocol; the authoritative
terminal summaries and process exits were zero. No failing assertion was
hidden. The managed Debug cache denial was reproduced only in the sandboxed
cache context and was resolved by the required unchanged host build.

Specialized M02 results inside the focused acceptance route include exact
golden bytes/hash, five-repeat identity, mutation sensitivity, all 17 exact
invalid diagnostics, both M01 hashes, source-authority/update-policy checks,
and explicit diagnostic-capacity behavior.

M01.5 tiers remain intact. No active production/runtime test was retired or
weakened; expected M02 production/runtime retirement is zero and observed
retirement is zero.

## H. Decisions assumed

None.

All material choices in this package come from the brief or Prompt 1 through
Prompt 2E owner decisions. No additional owner decision was inferred.

## I. OPEN/TUNING

Classification is three-way and explicit:

1. **LOCKED architecture**: identity/hierarchy/coordinate rules and the
   specifically locked constituent counts described above; exact total height
   is `1.8288 m`.
2. **Asset-level OPEN/TUNING**: current human source numbers that are
   authoritative for this accepted asset but may change through explicit owner
   review and golden update.
3. **Validation-only tolerances**: numbers used to test finite-precision
   invariants; they are not body or architecture values.

The principal report's `OPEN_TUNING_VALUES` section is the exhaustive
line-by-line inventory and is incorporated here by reference rather than
copied into a competing evidence format. It contains all 142 accepted current
values:

| Category | Count | Scope |
|---|---:|---|
| Material colors | 11 | Linear-sRGB RGBA values for the 11 material instances |
| Rig/rest profile | 69 | Lengths, offsets, key local transforms, and A-pose angles |
| Control defaults | 4 | Normalized neutral control defaults/domains |
| Attachment offsets | 34 | Structural registration offsets |
| Mobility profiles | 21 | Preferred/hard ROM, stiffness, and swing/twist values |
| Validation-only tolerances | 3 | Two `0.00001 m` numerical tolerances and one `0.00001` symmetry tolerance |
| **Total** | **142** | Deterministically sorted in the accepted report |

The A-pose values include current upper-arm `25 degrees` and elbow `5 degrees`.
All measurements listed in section D other than total height are OPEN/TUNING.
There are no proxy dimensions because proxies are deferred. There are no mesh,
weight, morph-delta, UV, atlas, raster, soft-tissue, contact, or garment tuning
values in M02.

An intentional future tuning edit changes the authoritative JSON and therefore
may change the canonical hash. Such a change must use the explicit update path
and obtain owner review; tests cannot absorb it silently.

## J. Known limitations

M02 intentionally does not provide:

- production continuous human mesh or resolved body-surface geometry;
- skin weights, dual-quaternion skinning, or linear-blend-skinning execution;
- morph or corrective vertex deltas;
- soft-tissue, physiological, fluid, or contact-deformation solving;
- garment fitting or clothing geometry;
- real-geometry UVs, surface membership, vertex rings, or atlas generation;
- rasterization or live runtime 3D;
- procedural IK, gaze, blink, grasp, tongue, or grounding solvers;
- formal male/female derived configuration profile records;
- empirically fitted structural collision proxies;
- final mesh/body-surface anthropometric measurements.

The structural identities for breast/nipple/areola, anus/perianal/anal canal,
vulvar/vaginal, penis, scrotum/testicles, genital/perineal/anal/groin/pubic/glute
anchors, and corresponding interaction sites are present by name. Presence is
not a claim of final geometry, tissue deformation, state response, or contact
behavior.

## K. M03 readiness

**Assessment: M02 OWNER-ACCEPTED; M02.5 FILE-BACKED HANDOFF READY.**

M03 can attach one continuous canonical human mesh to the existing M02 source
without renaming core IDs, replacing the skeleton, changing its hierarchy,
inventing a parallel landmark/seam system, or making renderer data
authoritative. The stable component, bone, joint, control, region, surface,
anchor, socket, mount, landmark, seam, interaction-site, effector, and material
identities are sufficient attachment points.

There is no current structural blocker. M03 must consume these identities and
add actual topology/surface membership as derived data. It must also create and
empirically fit canonical structural collision proxies after real geometry is
available and before the first resolved-human-geometry snapshot is accepted.
Runtime 2D AABBs are not an acceptable substitute.

No M03 implementation was created during this audit. M03 remains unstarted and
requires its explicit engineering brief/prompt.

## Major-section audit matrix

| M02 section | Classification | Audit result |
|---|---|---|
| 1 Purpose | PASS | Final structural foundation exists without geometry work. |
| 2 Authority and precedence | PASS | Owner decisions and the canonical decision record were applied in precedence order. |
| 3 M01/M01.5 baseline | PASS | Both M01 hashes and all test tiers are preserved. |
| 4 Primary objective | PASS | One stable, renderer-independent structural human definition exists. |
| 5 Explicit non-goals | PASS | Scope audit found none implemented. |
| 6 Identity and neutral state | PASS | One `human_base`; owner-approved optional states applied. |
| 7 OPEN/TUNING policy | PASS | Architecture, source tuning, and validation tolerances remain distinct. |
| 8 Pre-implementation manifest | PASS | Accepted Prompt 2A manifest is represented and validated. |
| 9 Component ownership tree | PASS | 48 records, one body root, single parents. |
| 10 Skeleton | PASS | Complete accepted hierarchy and constituent counts. |
| 11 Rest transforms/measurements | PASS | Local authority, deterministic globals, exact height, structural measurement labeling. |
| 12 Joints/mobility | PASS | 148 records, valid provisional relationships, no solver. |
| 13 Structural controls | PASS | 116 records, including five spine controls and explicit drives. |
| 14 Landmarks | PASS | 35 stable identities and deterministic coordinates. |
| 15 Shared seams | PASS | 11 identities without fake geometry data. |
| 16 Regions/surfaces | PASS | 206/206 structural semantic identities. |
| 17 Anchors/sockets/mounts/attachments | PASS | 106/22/20/20, distinct and validated. |
| 18 Sites/effectors | PASS | 25/6, including adult-anatomy identities. |
| 19 Optional profiles | DEFERRED BY APPROVED OWNER DECISION | Shared optional modules exist; formal male/female derived profiles remain deferred. |
| 20 Neutral materials | PASS | 11 definitions and 11 instances; numerical colors remain OPEN/TUNING. |
| 21 Collision proxies | DEFERRED BY APPROVED OWNER DECISION | Count zero until real-geometry fitting; requirement retained. |
| 22 Human validation | PASS | Identity, counts, symmetry, coordinates, references, and shared-source rule enforced. |
| 23 Invalid fixtures | PASS | 17 file-backed, exact, fail-closed cases. Conditional derived-profile case 18 is not applicable because profiles are deferred. |
| 24 Deterministic fixture/golden | PASS | Accepted bytes, hash, round trip, repeats, mutation, and M01 identity. |
| 25 Evidence tooling | PASS | Accepted deterministic structural report; exporter now file-driven. |
| 26 Testing policy | PASS | Current TESTING tiers followed through final verify. |
| 27 Test retirement | PASS | Zero active production/runtime tests retired. |
| 28 Implementation sequence | NOT APPLICABLE | Historical sequencing is complete; Prompt 3 audited the resulting state. |
| 29 Review package | PASS | Sections A-K and evidence are present here. |
| 30 Stop/escalation | PASS | No unresolved owner decision, golden change, or M03 expansion occurred. |
| 31 Definition of Done | PASS, with item 15 approved deferred | Detailed table in section A. |
| 32 M03 handoff | PASS | Stable structural attachment contract is ready after owner acceptance. |
