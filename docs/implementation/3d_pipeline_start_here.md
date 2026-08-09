# 3D Model Pipeline — Codex Start Here

**Status:** M02.5 authority/handoff cleanup complete; awaiting owner review
**Current milestone:** M02.5 — File-backed `human_base` authority and M03 handoff cleanup
**Accepted foundation:** M01, M01.5, and M02
**Testing foundation:** M01.5 — Tiered verification / test-streamlining pass  
**Next milestone:** M03 — Canonical Human Mesh & Surface Foundation; not started and requires explicit authorization
**Owner-review gate:** Required for this M02.5 cleanup before any M03 work
**Primary runtime boundary:** The current production runtime remains 2D-only. Canonical 3D authoring, validation, and representation generation are offline/build-time concerns unless a later milestone explicitly changes that boundary.

---

## 1. Purpose

This file is the stable entry point for Codex work on the canonical 3D model pipeline.

It is intentionally **not** a milestone specification. Its job is to define:

- authority and document precedence;
- the current pipeline status;
- what Codex must read before milestone work;
- implementation rules that apply across milestones;
- test/verification policy;
- review evidence requirements;
- stop/escalation behavior;
- the boundary between the current milestone and the next one.

Detailed scope belongs in the active milestone engineering brief.

Work milestone-by-milestone. Do not infer permission to implement later phases merely because the broader architecture describes them.

---

## 2. Pipeline status

### Accepted foundation

**M01 — Canonical Model Data Foundation** is owner-accepted.

M01 established the renderer-independent canonical-model subsystem, including typed identities/references, 3D local transforms, canonical normalization/serialization, SHA-256 source identity, structured validation, deterministic tracing, and proof fixtures.

Its accepted golden identities remain regression contracts unless an explicitly reviewed M01 change authorizes otherwise.

### Testing foundation

**M01.5 — test-tier streamlining** is complete.

It reorganized execution speed and test scheduling without weakening M01 contracts, changing accepted tolerances, shortening stress iteration counts, or deleting meaningful coverage.

The repository testing authority is:

- `docs/TESTING.md`

### Accepted structural milestone

**M02 — `human_base` Structural Definition** is owner-accepted.

M02 instantiates the first real canonical human structural asset on top of the M01 data foundation. It defines stable human structure—component ownership, skeleton, rest pose, joints, controls, anchors, landmarks, seams, semantic identities, interaction hooks, and deterministic asset evidence—without yet creating the production human mesh.

Read:

- `docs/implementation/3d_pipeline_milestone_02.md`

### Current cleanup and next milestone

**M02.5** enforces the accepted authority boundary: the sole authoritative
human source is `assets/canonical_model/human_base/human_base.authoring.json`.
The supported repository API is
`canonical_model.human_base.loadAuthoritative(allocator, io, diagnostics)`.
It reads that file, parses it, runs generic and human structural validation,
normalizes it, and returns an ownership wrapper for the canonical in-memory
definition. Evidence files and the current 2D runtime are never source authority.

**M03 — Canonical Human Mesh & Surface Foundation** begins only after explicit
owner authorization with its engineering brief.

M03 will attach actual continuous canonical human geometry to the structural identities established in M02. It must consume M02 IDs, skeleton, landmarks, seams, anchors, and semantic ownership rather than redefining them.

M03 has not started.

---

## 3. Required reading order

Before beginning or resuming milestone implementation, read the following in order.

1. **Pipeline entry point**
   - `docs/implementation/3d_pipeline_start_here.md`

2. **Canonical source of truth**
   - `docs/architecture/3d_model_pipeline_canonical_decision_record_v1.md`

3. **Current cleanup/review package**
   - `docs/implementation/3d_pipeline_m02_5_review_package.md`

4. **Accepted prior-milestone evidence relevant to the current work**
   - `docs/implementation/3d_pipeline_m02_review_package.md`
   - `docs/implementation/3d_pipeline_m01_review_package.md`

5. **Repository testing authority**
   - `docs/TESTING.md`

6. **Additional accepted transition/testing report if retained in the repository**
   - M01.5 report/documentation, when present

7. **Downstream integration / acceptance reference**
   - `docs/architecture/creature_interaction_architecture_decision_record_v3.md`

Read additional repository architecture or implementation documents when the active milestone references them.

Do not substitute:

- an older prompt;
- historical renderer behavior;
- a test fixture;
- a downstream integration note;
- the current runtime humanoid;
- or a previous milestone's temporary implementation detail

for the canonical decision record or active milestone brief.

---

## 4. Authority and precedence

The canonical decision record is authoritative for canonical model-pipeline architecture, including:

- units and coordinate conventions;
- canonical origin and bind/reference pose;
- naming and stable IDs;
- component ownership;
- rig/skeleton concepts;
- morphology and dependency rules;
- deformation architecture;
- anchors, sockets, surfaces, regions, seams, and landmarks;
- material and visibility contracts;
- animation-data architecture;
- representation/registration requirements;
- deterministic serialization, hashing, and validation;
- canonical `human_base` requirements.

The **active milestone engineering brief** determines which portion of that architecture may be implemented now.

The creature/interaction architecture record is a **downstream integration and acceptance-requirements reference**. It can expose requirements the canonical pipeline must eventually satisfy, but it does not silently redefine canonical anatomy, rig structure, identity, coordinate behavior, or source authority.

If documents conflict:

1. a newer explicit owner decision wins over older text for the decision it replaces;
2. otherwise the canonical decision record wins for canonical model-pipeline architecture;
3. the active milestone brief controls current implementation scope;
4. downstream documents do not silently override canonical authority.

Known previously resolved examples include:

- canonical asset origin centered between the feet on the ground in A-pose rather than at the pelvis;
- tongue structure using four shared deformation bones plus an explicit branch point.

---

## 5. Status language is binding

The canonical decision record and milestone briefs use these statuses:

- **LOCKED** — architectural requirement; implement as specified.
- **DEFERRED** — preserve compatibility, but do not pull the implementation forward unless the active milestone explicitly requires it.
- **EXCLUDED** — do not implement in the current scope.
- **OPEN/TUNING** — provisional empirical values may be needed, but they are not newly locked architecture.

When an active milestone requires an `OPEN/TUNING` value:

- keep it centralized and inspectable;
- identify it explicitly in the implementation report/review package;
- do not describe it as a universal law or permanent architecture;
- do not turn a hierarchy/topology/ownership decision into “tuning” to avoid owner review.

---

## 6. Milestone boundary rule

The active milestone is the implementation boundary.

Codex may:

- use already accepted infrastructure from prior milestones;
- add the records/assets/tests/tools explicitly required by the active milestone;
- add narrow regression fixes discovered while implementing the active milestone;
- preserve forward-compatible hooks already authorized by the canonical architecture.

Codex must not:

- begin the next milestone early;
- opportunistically implement later solvers/systems;
- redesign accepted prior milestones without a demonstrated defect;
- make renderer/game state authoritative for canonical data;
- broaden scope merely because a future system is described in the architecture record.

At every owner-review gate, stop and wait for explicit approval before advancing.

---

## 7. Non-negotiable implementation rules

### 7.1 One source of truth

Do not create two independently authoritative representations of the same canonical value.

Examples:

- canonical bone transforms are authored as local parent-relative transforms;
- derived global/affine transforms are computed/cached, not independently authored;
- one low-level target property has one authoritative writer/resolver;
- a semantic seam has one stable identity rather than separate unrelated definitions for each side.

### 7.2 No silent repair

Invalid canonical source must fail explicitly.

Do not silently:

- repair broken references;
- clamp invalid canonical values;
- choose between conflicting authoritative writers;
- upgrade dependency versions;
- substitute missing/unsupported components;
- change topology;
- reinterpret malformed hierarchy;
- regenerate accepted goldens merely because a test fails.

An editor may eventually offer explicit repair actions, but repair is a source-changing author operation.

### 7.3 No silent architectural invention

If implementation requires a decision that is not already supported:

1. stop at the affected boundary;
2. identify the exact missing decision;
3. explain why it is necessary;
4. show the smallest viable alternatives/tradeoffs;
5. request owner review;
6. do not bury the choice in code, fixture data, generated output, or a magic constant.

### 7.4 Determinism

Given identical canonical source, accepted dependencies, compiler version, settings, and deterministic seed, canonical/generated metadata must be reproducible where the milestone requires it.

Normalize before hashing.

Ordering must be deterministic where ordering is non-semantic.

Semantic ordering must not be destroyed merely to make serialization easier.

Accepted golden files/hashes are reviewed regression evidence, not auto-update targets.

### 7.5 Validation-first design

Prefer explicit measurable validation over visual guessing.

Diagnostics should identify, where applicable:

- stable diagnostic code/category;
- object/record ID;
- property/reference;
- referenced ID;
- actionable reason;
- deterministic ordering/location information.

Later mesh, deformation, representation, seam, landmark, and registration milestones should continue the same evidence-first philosophy.

### 7.6 Renderer independence

The canonical 3D model pipeline is not an extension of the current sprite-placement implementation.

Canonical model data must not depend on:

- current sprite layout;
- atlas placement;
- render layers as structural authority;
- game-specific controller state;
- current runtime humanoid indexes;
- GPU/D3D12 state;
- hidden presentation offsets.

The current 2D renderer may later consume compiled representation packages. Dependency direction must remain toward the canonical/compiled data, not from canonical data into runtime presentation code.

---

## 8. Implementation style

Prefer:

- explicit typed records;
- stable semantic string IDs;
- local transforms;
- small deterministic transformations;
- explicit ownership and references;
- traceable dependencies;
- structured diagnostics;
- file-backed proof fixtures where appropriate;
- focused regression tests;
- reviewable canonical goldens/evidence.

Avoid:

- implicit global state;
- magic numeric indexes as identity;
- order-dependent behavior where order is not semantic;
- giant catch-all records;
- duplicate sources of truth;
- human-only hacks in generic canonical-model infrastructure when a general rig-family abstraction is required;
- renderer-specific naming in canonical model types;
- speculative systems that belong to later milestones.

---

## 9. Testing and verification policy

`docs/TESTING.md` is the testing authority.

M01.5 established separate fast, full, stress, specialized, and complete verification tiers. Preserve that structure.

### Normal edit-time verification

```text
zig build test -j1
```

Use focused milestone-specific test targets while iterating when available.

### Fast repository / pre-review gate

```text
zig build check -j1
```

This is the normal fast tests plus formatting/static repository audits.

### Targeted deterministic iteration

```text
zig build test-deterministic -Dtest-filter='<text>' -j1
```

Use when the relevant test lives in the deterministic suite.

### Full non-stress regression

```text
zig build test-full -j1
```

Run at major owner-review gates or when changes have broad integration reach.

### Stress / endurance verification

```text
zig build test-stress -j1
```

Do not shorten or duplicate existing endurance coverage merely for convenience.

### Complete acceptance verification

```text
zig build verify -j1
```

Use for final milestone acceptance unless the milestone brief explicitly requires more specialized evidence.

### Specialized workflows

Keep specialized GPU-smoke, D3D12 evidence, visual/manual review, and focused subsystem commands explicit.

Do not claim GPU/manual visual acceptance for an offline structural milestone that has no production geometry to inspect.

### Test retirement

Do not delete, weaken, or classify active compatibility/runtime coverage as obsolete merely because a newer canonical milestone exists.

A production test/path may be retired only when an authorized later milestone has actually replaced its responsibility and the retirement policy in `docs/TESTING.md` is satisfied.

---

## 10. Accepted infrastructure limitations

The following previously observed behaviors are infrastructure/tooling observations unless new evidence ties them to an implementation defect:

- managed-environment Zig cache/manifest `AccessDenied` behavior where the equivalent host Debug build succeeds;
- standalone Zig test-runner IPC/outer-timeout variability where unchanged tests pass through the accepted verification graph.

Continue reporting them accurately.

Do not:

- hide real assertion failures behind these classifications;
- skip tests because of them;
- weaken acceptance criteria;
- redesign canonical architecture around a managed-sandbox artifact.

---

## 11. Required milestone review evidence

Every milestone should end with an engineering/review package containing, as applicable:

### Implemented

- files/modules/assets changed;
- contracts/features implemented;
- validators or schema extensions added;
- tools/reports added.

### Automated tests

- focused milestone tests;
- prior-milestone regression/golden status;
- fast `test`;
- `check`;
- `test-full` where required;
- `verify` for final acceptance;
- specialized/stress tests when relevant.

### Empirical evidence

Show concrete outputs relevant to the milestone, such as:

- canonical normalized output;
- hashes/signatures;
- hierarchy reports;
- transform derivations;
- measurement reports;
- semantic inventories;
- representative diagnostics;
- dependency/binding traces;
- seam/registration evidence;
- later, visual/GPU evidence where the milestone actually requires it.

### Decisions assumed

List every necessary assumption not explicitly supported by accepted architecture.

Preferred result: **None**.

### OPEN/TUNING values

List provisional values separately.

They are not newly locked architecture unless explicitly owner-approved.

### Known limitations

State what the milestone intentionally does not implement.

### Owner-review items

Identify anything that must be accepted before the next milestone.

### Next-milestone readiness

State whether the next milestone can consume the current work without replacing accepted core IDs, hierarchy, authority, or evidence contracts.

---

## 12. Stop / escalation rules

Stop instead of silently continuing if:

- a `LOCKED` decision cannot be represented;
- the active milestone would require material redesign of an accepted prior milestone;
- canonical data would need renderer/game-specific authority;
- stable IDs or ownership cannot be preserved;
- deterministic normalization/hashing cannot be maintained;
- two authoritative representations would exist;
- an `OPEN/TUNING` choice actually changes architecture;
- a continuous morphology operation would implicitly require a topology change;
- an accepted golden changes unexpectedly;
- a required dependency must be silently upgraded;
- implementation would constrain future rig families without an accepted decision;
- tests must be skipped/weakened to pass;
- the work would cross into the next milestone.

If the problem is a genuine defect in accepted prior work, report it as a regression/blocker and propose the narrowest correction.

---

## 13. Current M02.5 → M03 gate

M02 is owner-accepted. M02.5 is limited to enforcing its source-authority and
handoff boundary. M03 remains unauthorized until its explicit engineering
brief/prompt is provided.

The sole supported M03 consumption path is:

1. call `canonical_model.human_base.loadAuthoritative(allocator, io, diagnostics)`;
2. consume the returned normalized, validated in-memory definition while the
   ownership wrapper remains alive.

M03 must not treat the canonical JSON, report, hashes, traces, old Zig
validation tables, current 2D runtime anatomy, or renderer registration data as
source authority.

Until explicit M03 authorization:

- do not begin production canonical human mesh topology;
- do not attach real skin weights;
- do not implement morphology sculpting/correctives;
- do not create real-geometry UVs;
- do not implement garment fitting;
- do not begin 3D-to-2D representation generation.

When authorized, M03 may create the continuous canonical human mesh and surface foundation **using the structural identities produced by M02**.

The handoff is successful only if M03 can proceed without casually renaming core IDs, replacing the accepted skeleton, inventing a parallel landmark/seam system, or making renderer-specific data authoritative.

---

## 14. Maintenance rule for this file

Keep this file stable and short relative to milestone briefs.

When the pipeline advances:

1. update the status block;
2. update the active milestone section/path;
3. update the next-milestone summary/gate;
4. preserve the cross-milestone engineering/testing rules unless an explicit owner decision changes them.

Do **not** copy an entire milestone specification into this file again.

Historical milestone details belong in milestone briefs and review packages.
