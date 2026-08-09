# 3D Model Pipeline — Codex Start Here

**Status:** Active implementation handoff  
**Current milestone:** M01 — Canonical Model Data Foundation  
**Owner-review gate:** Required before M02  
**Primary runtime boundary:** The current production runtime remains 2D-only. Canonical 3D authoring, validation, and representation generation are offline/build-time concerns unless a later milestone explicitly changes that boundary.

---

## 1. Purpose

This file is the short entry point for Codex work on the new canonical 3D model pipeline.

Do not treat this file as the full specification. Its job is to define:

- which documents are authoritative;
- what Codex should read first;
- which milestone is currently active;
- what Codex may and may not change;
- how implementation assumptions, validation, evidence, and owner review must be handled.

The current task is **not** to implement the entire 3D pipeline. Work milestone-by-milestone.

---

## 2. Required reading order

Read these documents in this order before implementation:

1. **This file**
   - `docs/implementation/3d_pipeline_start_here.md`

2. **Canonical source of truth**
   - `docs/architecture/3d_model_pipeline_canonical_decision_record_v1.md`

3. **Current implementation milestone**
   - `docs/implementation/3d_pipeline_milestone_01.md`

4. **Downstream requirements/reference**
   - `docs/architecture/creature_interaction_architecture_decision_record_v3.md`

Do not substitute an older renderer implementation, historical prompt, test fixture, or downstream architecture note for the canonical decision record.

---

## 3. Authority and precedence

The canonical decision record owns:

- units and coordinate conventions;
- canonical origin and bind pose;
- naming and stable IDs;
- component topology;
- rig/skeleton structure;
- morphology parameters and bindings;
- deformation rules;
- anchors, sockets, semantic surfaces, seams, and landmarks;
- material and visibility contracts;
- animation data contracts;
- registration/export requirements;
- deterministic serialization, hashing, and validation;
- the canonical `human_base` definition.

The creature/interaction architecture record is a **downstream integration and acceptance-requirements record**. It informs clothing, interaction, representation, caching, simulation, and future integration, but it does not silently redefine canonical anatomy or rig behavior.

If documents conflict, the canonical decision record wins for canonical model-pipeline behavior unless a newer explicit, versioned owner decision says otherwise.

Known examples already resolved in favor of the canonical record include:

- canonical asset origin is centered between the feet on the ground in the A-pose;
- the tongue uses four shared deformation bones plus an explicit branching point.

---

## 4. Status language is binding

The canonical decision record uses these statuses:

- **LOCKED** — requirement; implement as specified.
- **DEFERRED** — preserve architectural compatibility, but do not pull implementation forward unless the milestone requires it.
- **EXCLUDED** — do not implement in the current scope.
- **OPEN/TUNING** — may require later empirical tuning; do not present a provisional implementation value as a newly locked design decision.

If a milestone requires a provisional `OPEN/TUNING` value, record it explicitly in the review package.

---

## 5. Current milestone

The active milestone is:

> **M01 — Canonical Model Data Foundation**

M01 implements the deterministic, versioned data model and validation infrastructure needed to represent a canonical creature definition.

M01 is **schema/data-contract work**, not character modeling.

The milestone must make it possible for M02 to begin `human_base` without requiring a schema rewrite.

Read the full scope and acceptance criteria in:

- `docs/implementation/3d_pipeline_milestone_01.md`

---

## 6. M01 hard boundary

### M01 should implement

At minimum, the repository must be able to represent, normalize, validate, serialize, hash, and inspect:

- schema / asset / compiler identity;
- coordinate contract;
- stable IDs and references;
- component graph;
- bones / skeleton;
- joints;
- animator-facing controls;
- anchors, sockets, mount anchors, and attachments;
- semantic surfaces / regions;
- landmarks and shared seams;
- interaction sites / effectors;
- morphology parameters and explicit bindings;
- dependency relationships;
- material definitions and instances;
- visibility / representation / normalized coverage metadata;
- deterministic canonical JSON normalization and serialization;
- source-definition hashing;
- structured validation diagnostics;
- valid and invalid proof fixtures.

### M01 must not implement

Do not pull these into M01:

- the actual `human_base` mesh;
- production skinning or weight painting;
- morphology sculpting;
- corrective-shape authoring;
- soft-tissue solving;
- contact deformation solving;
- garment fitting;
- clothing authoring;
- animation solving;
- multi-actor choreography solving;
- atlas generation;
- a replacement 2D renderer;
- live runtime 3D.

Representing future-facing records or metadata hooks is allowed when M01 requires them. Implementing the downstream solver/system is not.

---

## 7. Repository reconnaissance comes before code changes

Before implementing M01, inspect the repository and identify:

- current module/project layout;
- JSON/config/schema infrastructure;
- stable ID/reference types;
- vector/quaternion/transform math;
- hashing utilities;
- validation/diagnostic conventions;
- test framework and fixture conventions;
- build targets;
- renderer-specific types that must **not** become canonical model dependencies.

Prefer reuse only when the existing abstraction is genuinely compatible with the canonical contract.

Do not force canonical model data into an existing renderer-specific type merely because it already exists.

Do not reorganize unrelated repository code for aesthetic reasons.

If the repository architecture creates a real conflict with a locked canonical decision, stop at that boundary and report it before proceeding.

---

## 8. Non-negotiable implementation rules

### 8.1 One source of truth

Do not create two authoritative representations of the same canonical value.

Examples:

- canonical bone transforms store local parent-relative transforms only;
- global transforms are derived/cached, not independently authored;
- one low-level target property has one authoritative morphology resolver/writer.

### 8.2 No silent repair

Invalid source data must fail validation.

Do not silently:

- normalize invalid skin/morph weights;
- repair broken references;
- choose between conflicting writers;
- upgrade dependency versions;
- change topology;
- substitute unsupported components;
- clamp invalid canonical values without reporting it.

The editor/tooling may later offer an explicit repair operation, but repair is a source-changing author action.

### 8.3 No silent architectural invention

If implementation needs a canonical decision that is not present:

1. stop at the affected boundary;
2. identify the exact missing decision;
3. explain why it is required;
4. report possible options/tradeoffs;
5. wait for owner review when the choice changes architecture.

Do not bury an architectural decision in implementation code.

### 8.4 Determinism

Given identical canonical inputs, dependencies, compiler version, settings, and deterministic seed, canonical metadata and generated metadata must be reproducible.

Normalize before hashing.

Generated artifacts must record their relevant source/version/hash dependencies.

### 8.5 Validation-first design

Prefer explicit measurable validation over visual guessing.

Diagnostics should identify:

- exact object/record ID;
- exact property/reference;
- stable diagnostic code/category;
- actionable reason.

The broader pipeline will later use the same philosophy for seams, landmarks, registration, morphology, collisions, and 3D-to-2D traceability.

### 8.6 Renderer independence

The canonical 3D model pipeline is not an extension of the current sprite placement implementation.

The current 2D renderer may eventually consume compiled representation packages, but canonical model data must not depend on hidden renderer placement rules, sprite-specific assumptions, or game-specific state.

---

## 9. Implementation style

Prefer:

- explicit typed records;
- stable semantic IDs;
- small deterministic transformations;
- traceable dependency graphs;
- structured diagnostics;
- proof fixtures;
- unit/regression tests around every canonical rule.

Avoid:

- implicit global state;
- magic numeric indexes as identity;
- order-dependent behavior where order is not semantic;
- giant catch-all schema records;
- one-off special cases for `human_base` that prevent later dog/horse/other rig families;
- renderer-specific naming in canonical model types.

---

## 10. Required review evidence

Every milestone should finish with a concise engineering report containing:

### Implemented

- files/modules changed;
- contracts implemented;
- validators implemented;
- normalization/hash behavior.

### Automated tests

- test categories and counts;
- valid fixture coverage;
- invalid fixture coverage;
- deterministic round-trip/repeat-build results.

### Empirical evidence

Show concrete examples where applicable:

- normalized canonical output;
- hashes/signatures;
- representative validation diagnostics;
- dependency/binding traces;
- exact failure evidence.

### Decisions assumed

List every necessary assumption not explicitly supported by the canonical record.

Preferred result: **none**.

### OPEN/TUNING values

List provisional values separately. They are not newly locked architecture.

### Known limitations

State what the milestone intentionally does not implement.

### Owner-review items

Call out anything that must be accepted before the next milestone.

---

## 11. Stop / escalation rules

Stop instead of silently continuing if:

- a locked decision cannot be represented;
- canonical model types would need to depend on renderer/game-specific state;
- stable IDs cannot be maintained;
- deterministic normalization/hashing cannot be guaranteed;
- implementation would constrain later rig families without an explicit decision;
- a continuous morphology control would require an implicit topology change;
- two authoritative writers/sources of truth would exist;
- a required dependency must be silently upgraded;
- a schema or solver choice falls outside the current milestone.

---

## 12. M01 completion and M02 gate

M01 is not complete merely because types compile.

It is complete only when the milestone definition of done and review evidence in `3d_pipeline_milestone_01.md` are satisfied.

**Do not begin M02 until owner review accepts M01.**

M02 will begin the actual canonical `human_base` structural asset using the M01 data foundation.
