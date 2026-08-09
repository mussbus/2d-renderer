# Engineering Brief — 3D Model Pipeline M01: Canonical Model Data Foundation

**Status:** Ready for Codex implementation planning and execution  
**Milestone:** M01  
**Source of truth:** `../architecture/3d_model_pipeline_canonical_decision_record_v1.md`  
**Downstream reference only:** `../architecture/creature_interaction_architecture_decision_record_v3.md`  
**Owner-review gate:** Required before M02

---

## 1. Purpose

Implement the first executable foundation of the new canonical 3D model pipeline: the deterministic, versioned data model and validation infrastructure required to represent a canonical creature definition and, in the next milestone, `human_base`.

This milestone is **schema/data-contract work**, not character modeling.

The central outcome is that the repository can load, normalize, validate, serialize, hash, and inspect a small canonical creature definition without relying on renderer-specific assumptions or hidden state.

---

## 2. Authority and precedence

Codex must treat `../architecture/3d_model_pipeline_canonical_decision_record_v1.md` as authoritative for canonical model-pipeline behavior.

The creature/interaction architecture record at `../architecture/creature_interaction_architecture_decision_record_v3.md` is downstream guidance only. It must not silently override canonical anatomy, coordinate, rig, morphology, material, or schema decisions.

If implementation exposes a conflict or a missing canonical decision:

1. stop at the affected boundary;
2. identify the exact missing/conflicting decision;
3. report it for owner review;
4. do **not** silently invent a replacement architecture.

Locked decisions are requirements. `DEFERRED`, `EXCLUDED`, and `OPEN/TUNING` items must retain those statuses.

---

## 3. Primary objective

Create a canonical model-data subsystem capable of representing these concepts with stable IDs and deterministic references:

```text
CanonicalCreatureDefinition
├── identity/version metadata
├── coordinate contract
├── component ownership graph
├── skeleton/bones
├── joints
├── animator-facing controls
├── anchors
├── sockets
├── child mount anchors / attachments
├── semantic surfaces and regions
├── landmarks and shared seams
├── interaction sites/effectors
├── morphology parameters
├── morphology bindings/dependencies
├── material definitions/instances
├── visibility/coverage metadata
└── normalized deterministic identity/hash
```

M01 must prove that these records can coexist, cross-reference each other, validate deterministically, and produce reproducible canonical output.

---

## 4. Explicit non-goals

Do **not** implement the following in M01:

- the actual `human_base` mesh;
- 3D mesh generation or editing;
- skinning execution;
- morph-target deformation execution;
- corrective-shape execution;
- soft-tissue solving;
- contact deformation solving;
- collision-proxy generation;
- garment fitting or garment authoring;
- animation playback/IK solving/choreography execution;
- atlas generation;
- 3D-to-2D rasterization;
- replacement of the current 2D renderer;
- live runtime 3D;
- editor UI beyond minimal diagnostics required to prove the data layer, unless an existing debug surface makes a tiny integration clearly cheaper than a standalone fixture.

M01 may define schema fields/references needed by later systems, but it must not pull their implementation into this milestone.

---

## 5. Locked canonical coordinate contract

The data model must encode the coordinate contract explicitly rather than relying on engine convention.

```text
unit                = meter
numeric_precision   = f32
authoring_step_m    = 0.001
handedness          = right_handed
+x                  = world/viewer right
+y                  = up
+z                  = toward camera
-z                  = away from camera
canonical_forward   = +z
ground              = y = 0
asset_origin         = centered between feet on ground in A-pose
canonical_height_m  = 1.8288
bind_pose            = a_pose
```

Imperial units are display/input conversions only and do not belong in canonical calculations.

Canonical transforms are **local, parent-relative only**. Global transforms are derived.

- translation: meters / `f32`
- rotation: quaternion
- scale: XYZ
- canonical joint-angle values: radians
- editor-facing angle display may use degrees

---

## 6. Naming and identity contract

Machine-facing IDs use lowercase `snake_case`.

Rules:

- `left` / `right` always mean character anatomical side;
- repeated structures use `_01`, `_02`, ...;
- use `center`, not `middle`, for midline structures;
- IDs are stable and immutable once published;
- display names are separate human-readable strings;
- references use stable IDs, never array indices;
- parent relationships are not encoded into IDs;
- use semantic names, not generic names such as `bone_17`.

Required version identities:

```text
schema_version
asset_version
compiler_version
```

These are independent concepts.

---

## 7. Core record contracts

The exact code organization is repository-dependent, but the semantic contract below is required.

### 7.1 Component

A component participates in a single-parent ownership tree rooted at one logical `body` component.

Minimum semantic fields:

- immutable `component_id`;
- `component_type`;
- optional `parent_component_id` except root;
- semantic tags;
- required/optional status;
- enabled/disabled default/state representation;
- multiplicity/capacity policy where applicable;
- compatibility/profile requirements;
- references to attachment/rig/surface/material/visibility data as appropriate.

Adding/removing a true component is an explicit topology/module change, never a side effect of a continuous morphology parameter.

### 7.2 Bone / skeleton

Minimum semantic fields:

- immutable `bone_id`;
- optional `parent_bone_id` except `skeleton_root`;
- `deforms_mesh` flag;
- local rest transform;
- semantic tags;
- optional mirrored bone reference;
- optional editor/display length metadata.

Only `skeleton_root` has no skeletal parent.

Display length does not define deformation.

### 7.3 Joint

Minimum semantic fields:

- stable `joint_id`;
- parent/child bone references;
- joint type;
- preferred/soft range;
- hard/absolute range;
- preferred bend direction where applicable;
- swing/twist constraints where applicable;
- stiffness/limit behavior metadata;
- mobility-profile override hook.

Exact numeric human ranges are `OPEN/TUNING` and must not be invented as frozen architecture in M01.

Joint-range validity and body collision are separate constraints.

### 7.4 Animator-facing control

Minimum semantic fields:

- stable `control_id`;
- control type;
- driven target IDs;
- control space;
- optional mirror control;
- limits/defaults;
- semantic tags/region.

Supported control categories must be representable:

- FK rotation;
- IK target;
- pole/direction;
- curve/spline;
- whole-region;
- normalized slider;
- look target;
- procedural grasp control.

M01 represents these records; it does not implement the solvers.

### 7.5 Anchor

An anchor is a stable semantic coordinate frame.

Minimum semantic fields:

- `anchor_id`;
- owner component;
- driver/reference ID;
- local position;
- local quaternion rotation;
- semantic tags.

### 7.6 Socket

A socket is an anchor with attachment acceptance rules.

Represent at least:

- socket ID / referenced anchor;
- accepted component types/tags;
- capacity;
- required/optional attachment policy;
- compatibility/profile requirements.

Every socket is an anchor; not every anchor is a socket.

### 7.7 Mount anchor and attachment

Child components may define their own mount anchors.

An attachment explicitly aligns:

```text
parent socket
↔ child mount anchor
```

Do not assume the child component origin is the mount point.

### 7.8 Semantic surfaces / regions

Support stable:

- fine-grained `surface_id`;
- coarser `region_id`;
- material-instance reference;
- canonical-surface-coordinate metadata hook;
- visibility/coverage metadata hook.

Actual mesh membership is M02+ because the real mesh does not exist yet, but the IDs and reference model must be representable now.

### 7.9 Landmarks and shared seams

Represent stable semantic landmarks and shared seam/boundary identities.

Shared seams must be designed so later modular 2D exports can derive both sides from the same canonical seam/ring identity rather than maintaining independent edges.

M01 only defines/validates the records and references.

### 7.10 Interaction sites / effectors

Represent semantic contact regions and actors without implementing contact solving.

Interaction-site schema must be able to express:

- stable site ID;
- owning component/region;
- optional preferred anchor;
- semantic tags;
- allowed approach/orientation metadata hooks;
- capacity/occupancy policy hooks.

Effectors are semantic actors such as hands, feet, mouth, weapon edge, etc.

---

## 8. Morphology parameter schema

M01 must implement the canonical parameter model.

### 8.1 Parameter categories

Support:

- `structural`;
- `morphological`;
- `appearance`;
- `group`.

Temporary state such as breathing, arousal, flex activation, temperature, injury, etc. is **not** permanent morphology.

### 8.2 Value types

Support:

- `f32`;
- integer;
- enum;
- bool only for genuinely binary properties.

Physical values may use real units such as meters. Other values may use normalized `0.0–1.0` ranges.

### 8.3 Ranges

Each parameter can represent:

- default value;
- recommended/profile range;
- hard supported range.

### 8.4 Response curves

Represent at least:

- linear;
- smooth;
- custom-authored curve reference/data.

### 8.5 Symmetry

Represent:

- centered;
- mirrored;
- independent pair.

The schema must support linked left/right editing by default without destroying independent underlying values.

### 8.6 Topology rule

A continuous morphology parameter must never silently alter topology or component count.

Topology/module changes are explicit component-graph changes.

### 8.7 Bindings

Parameters explicitly declare what they affect.

Binding target categories must be representable for:

- rest bone transforms;
- anchors/sockets;
- mesh morph targets;
- corrective-shape inputs;
- material parameters;
- collision geometry;
- interaction sites;
- garment-fitting envelopes/surfaces;
- semantic landmarks;
- soft-tissue properties.

Standard binding operations:

- `set`;
- `offset`;
- `scale`;
- `weight`;
- `remap`;
- `derive`.

No hidden side effects.

### 8.8 Dependency rules

- one authoritative writer/resolver per low-level target property;
- group parameters drive parameters, not final geometry directly;
- derived values explicitly list all inputs;
- dependencies form a directed acyclic graph;
- evaluation order is deterministic;
- conflicting bindings are errors;
- source/provenance must remain inspectable.

Canonical morphology resolution order to preserve:

```text
structural parameters
→ rest skeleton + anchors
→ mesh morphology
→ soft tissue
→ collisions / interaction sites
→ garment-fitting data
→ corrective validation
```

M01 implements the dependency/binding model and validation, not the actual mesh-resolution stages.

---

## 9. Material definition and instance schema

Represent the distinction between:

### Material definition

Reusable behavior/capabilities, e.g. `human_skin`, `tooth_enamel`, `eye_sclera`.

### Material instance

Asset/character-specific values using a definition.

Material properties must be extensible enough to represent later:

- base color;
- roughness;
- gloss/specular;
- opacity;
- translucency;
- subsurface response;
- normal/detail strength;
- emission;
- wetness response;
- temperature/color response;
- optional displacement/detail.

Temporary surface state is separate from the material instance.

M01 does not implement shading.

---

## 10. Visibility, representation, and normalized coverage metadata

The data model must preserve separate state dimensions for:

- component existence/enabled state;
- visibility state;
- normalized coverage `0.0–1.0`;
- representation variant/substitution.

Visibility states must be able to represent concepts such as:

- visible;
- partially visible;
- fully occluded;
- hidden by policy;
- hidden for representation;
- replaced by variant.

Do not collapse these into one Boolean.

Coverage may later be driven by clothing, armor, hair, accessories, body overlap, or props.

M01 only defines the canonical metadata/validation model.

---

## 11. Canonical JSON and normalization

Canonical serialization is a required deliverable.

Rules:

- UTF-8;
- `snake_case` fields;
- deterministic generated field ordering;
- deterministic collection ordering;
- semantic arrays preserve semantic order;
- unordered collections canonicalize by stable ID;
- no duplicate IDs;
- no `NaN` or infinity;
- no meaningless floating-point precision noise.

For `f32`:

> Parse/store as `f32`, then serialize the shortest decimal representation that round-trips to the identical `f32` value.

Readable authoring input may omit defaults. Before hashing, produce a normalized canonical form with defaults explicitly resolved.

Equivalent logical authoring inputs must normalize to the same canonical identity.

---

## 12. Hashing and dependency identity

Use SHA-256 or an equivalent strong stable hash.

M01 must provide at least a **canonical source-definition hash** over the normalized form.

The design must leave room for later distinct hashes such as:

- resolved-geometry hash;
- resolved-pose hash;
- representation-package hash.

Generated/compiled artifacts later record hashes of all dependencies that materially affect them.

Do not use file names or timestamps as canonical identity.

---

## 13. Validation framework

Validation is a first-class output, not an incidental assertion.

Severity levels:

- `error`;
- `warning`;
- `info`.

Every diagnostic must identify the exact source object/property/reference whenever possible.

M01 validators must cover at least:

### Identity/reference validation

- duplicate IDs;
- missing references;
- wrong reference type;
- invalid root counts;
- invalid parent relationships.

### Graph validation

- component-tree cycles;
- skeleton cycles;
- preset/dependency cycles if preset primitives are introduced in M01;
- morphology dependency cycles.

### Transform/value validation

- non-finite floats;
- invalid normalized ranges;
- defaults outside hard ranges;
- malformed quaternion/transform data;
- invalid joint-range ordering.

### Binding validation

- unsupported target/operation pair;
- multiple authoritative writers for one low-level property;
- unresolved dependency;
- conflicting binding ownership;
- invalid derived-input references.

### Attachment validation

- socket references missing anchor;
- child attachment missing mount anchor;
- capacity/multiplicity contradictions;
- incompatible parent/child type references.

### Semantic validation

- surface references missing region/material where required;
- seam references missing required pair/shared identity;
- landmark/interaction-site owner missing;
- visibility/coverage value outside contract.

---

## 14. No silent repair

This is a hard requirement.

Invalid canonical source data must **not** be silently fixed during loading, normalization, validation, or hashing.

Examples:

- a broken reference remains an error;
- a conflicting binding remains an error;
- an out-of-range normalized value remains an error;
- future skin weights totaling `1.03` must not be silently normalized.

A future editor may provide explicit repair commands, but those commands must modify source data visibly and intentionally.

---

## 15. Minimal proof fixture

M01 must include a small synthetic canonical-creature fixture. It is **not** `human_base`.

The fixture should be just large enough to prove the contracts, e.g.:

```text
body
├── head
├── torso
└── pelvis
```

with a minimal skeleton such as:

```text
skeleton_root
└── pelvis
    └── spine_01
        └── head
```

The fixture should exercise at least:

- component ownership;
- skeletal parenting;
- one joint;
- one animator control;
- one anchor;
- one socket;
- one child mount/attachment;
- one surface + region;
- one landmark;
- one shared seam identity;
- one interaction site;
- one material definition + instance;
- one structural morphology parameter;
- one morphological/appearance parameter;
- one group parameter;
- multiple explicit parameter bindings;
- one derived dependency;
- visibility/coverage metadata;
- deterministic normalization/hash.

Use simple synthetic values. Do not attempt to encode the full human anatomy in this fixture.

---

## 16. Required invalid fixtures/tests

Create targeted invalid fixtures to prove diagnostics, including at least:

1. duplicate ID;
2. missing parent/reference;
3. component cycle;
4. skeleton cycle;
5. invalid joint range;
6. non-finite numeric input rejection;
7. normalized coverage outside `0.0–1.0`;
8. morphology dependency cycle;
9. two authoritative bindings writing the same low-level property;
10. invalid socket/anchor/mount relationship;
11. missing semantic owner/reference;
12. logically equivalent input with reordered unordered collections and omitted defaults.

For #12, both inputs must normalize and hash identically.

---

## 17. Determinism acceptance tests

M01 is not complete until these are automated.

### A. Canonical round-trip

```text
authoring input
→ parse
→ normalize
→ serialize
→ parse
→ normalize
```

The second normalized form must equal the first.

### B. Equivalent-input identity

Different source formatting/order/default omission representing the same logical object must produce identical normalized canonical output and identical hash.

### C. Repeat-build identity

Run canonical generation multiple times from identical inputs. Output bytes and hash must match exactly.

### D. Mutation sensitivity

A material change to canonical data must change the source-definition hash.

### E. Stable local-transform behavior

Global transforms derived from local parent-relative transforms must be reproducible, but only local transforms are serialized as canonical source.

### F. Validation determinism

The same invalid fixture must produce the same diagnostic identities/order/content where deterministic ordering is applicable.

---

## 18. Repository integration rules

Before editing, Codex must inspect the current repository and identify:

- existing JSON/schema/config infrastructure;
- existing ID/reference types;
- math/vector/quaternion types;
- hashing utilities;
- test conventions;
- build targets;
- modules that can be reused without importing renderer-specific assumptions into the canonical pipeline.

Prefer reuse when the existing abstraction is genuinely compatible.

Do **not** force the canonical model contract into an existing renderer type merely because that type already exists.

The new pipeline must remain an offline/canonical authoring subsystem that can later feed the existing 2D renderer through explicit compiled representation data.

Do not rename/reorganize unrelated existing code merely to make M01 aesthetically cleaner.

---

## 19. Implementation sequence

Recommended execution order:

### Phase A — repository reconnaissance

- inspect relevant source/tests/build files;
- identify reusable infrastructure;
- document proposed module/file placement;
- identify architectural conflicts before coding.

### Phase B — core value/ID/schema types

Implement identity/versioning, coordinate contract, stable references, components, transforms, bones, joints, controls, anchors/sockets, semantic records.

### Phase C — morphology/material/visibility records

Implement parameter definitions, bindings, dependency graph representation, material definition/instance records, coverage/visibility records.

### Phase D — normalization/serialization/hash

Implement canonical normalization, deterministic ordering, `f32` serialization behavior, canonical output, SHA-256 source-definition identity.

### Phase E — validation

Implement structured diagnostics and all M01 validators.

### Phase F — proof fixtures and regression tests

Implement valid minimal fixture, invalid fixtures, determinism tests, and repeat-build evidence.

### Phase G — documentation/review package

Document the actual code layout and provide evidence for owner review.

---

## 20. Required review package

At completion, provide a concise engineering report containing:

### Implemented

- modules/files added or changed;
- data contracts implemented;
- validators implemented;
- normalization/hash behavior.

### Automated tests

- test count/categories;
- deterministic round-trip results;
- equivalent-input hash result;
- invalid-fixture results;
- repeat-build result.

### Empirical evidence

Include concrete example output for:

- normalized valid fixture;
- source-definition SHA-256;
- at least several representative diagnostics;
- dependency/binding trace for one morphology parameter.

### Decisions assumed

List any decision that was necessary but not explicitly present in the canonical record.

**Preferred result: none.**

### OPEN/TUNING values

List any provisional values introduced. Do not present them as newly locked architecture.

### Known limitations

State what M01 intentionally does not implement.

### Owner-review items

Explicitly call out anything needing approval before M02.

---

## 21. Stop / escalation conditions

Stop and request owner review instead of continuing if:

- a required concept cannot be represented without changing a locked decision;
- existing repository architecture forces canonical data to depend on renderer/game-specific state;
- stable IDs cannot be preserved under the proposed design;
- deterministic normalization/hashing cannot be guaranteed;
- a schema choice would silently constrain later human/dog/horse rig families;
- a supposedly continuous morphology design would require implicit topology changes;
- two canonical sources of truth would be created for the same transform/value;
- implementation requires choosing an `OPEN/TUNING` anatomical/artistic value that is not necessary for the schema proof.

---

## 22. Definition of done

M01 is complete when:

1. the repository has one coherent canonical model-data subsystem;
2. the minimal valid fixture represents all required M01 concepts;
3. canonical input normalizes and serializes deterministically;
4. equivalent logical inputs produce the same canonical hash;
5. invalid inputs fail with precise, stable diagnostics;
6. dependency cycles and conflicting morphology writers are rejected;
7. no silent correction or silent dependency behavior exists;
8. the system remains independent of the existing 2D renderer's visual-placement assumptions;
9. all pre-existing relevant tests still pass;
10. the M01 review package is complete;
11. no actual `human_base` mesh/modeling work has been pulled into this milestone.

**Owner review is required before M02 begins.**

---

## 23. M02 handoff boundary

M02 begins only after M01 approval.

M02 will use this data foundation to begin the actual canonical `human_base` structural asset: rest skeleton, landmarks, semantic instantiation, and the first path toward a resolved neutral geometry snapshot.

M01 must therefore make M02 possible without requiring a schema rewrite.
