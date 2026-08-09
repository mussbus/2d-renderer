# M01 Canonical Model Data Foundation — Owner Review Package

**Milestone:** M01  
**Audit date:** 2026-08-08  
**Status:** Implementation and Prompt 3 contract audit complete; stopped for owner acceptance  
**Authority:** `../architecture/3d_model_pipeline_canonical_decision_record_v1.md`  
**Downstream reference only:** `../architecture/creature_interaction_architecture_decision_record_v3.md`

M02 and the canonical `human_base` asset have not begun.

## Implemented

### Repository layout

- `src/canonical_model/root.zig` exposes one renderer-independent canonical-model subsystem.
- `identity.zig`, `coordinate.zig`, and `math3d.zig` implement typed IDs and versions, the locked coordinate contract, vectors, canonical quaternions, local TRS, and transient affine composition.
- `component.zig`, `rig.zig`, `attachment.zig`, and `semantics.zig` implement component ownership, bones, joints, controls, anchors, sockets, mount anchors, attachments, regions, surfaces, landmarks, shared seams, interaction sites, and effectors.
- `morphology.zig`, `material.zig`, and `visibility.zig` implement explicit morphology parameters/bindings/dependencies/provenance, material definitions/instances, and distinct existence/enabled/visibility/coverage/representation metadata.
- `definition.zig` defines the complete M01 `CanonicalCreatureDefinition` aggregate.
- `parsing.zig`, `normalization.zig`, `serialization.zig`, and `hashing.zig` provide allocator-owned strict JSON parsing, fail-closed normalization, deterministic canonical JSON, and typed SHA-256 source-definition identity.
- `diagnostics.zig`, `validation.zig`, and `trace.zig` provide structured deterministic diagnostics, M01 validation, and deterministic morphology inspection.
- `build.zig` exposes four focused M01 test steps and includes them in repository `test` and `check`.
- `tests/fixtures/canonical_model/` contains the accepted readable, equivalent, golden, and targeted-invalid file-backed fixture matrix.

The subsystem imports only the Zig standard library and sibling `src/canonical_model/` modules. It imports no scene, graphics, animation, physics, interaction, platform, SDL, atlas, sprite, or GPU module.

### Locked data contracts

- Coordinate authority is explicit: meters, `f32`, right-handed, `+x` viewer-right, `+y` up, `+z` toward camera/canonical forward, ground at `y = 0`, origin centered between the feet on the ground in A-pose, and radians for canonical angles.
- Canonical source transforms are local parent-relative TRS only. Local point evaluation is scale, rotate, translate. Transient global affine composition is `M_parent * M_local`; no global/world transform is serialized.
- Quaternions use `[x, y, z, w]`, finite components, the accepted unit-length tolerance, exact normalization, canonical hemisphere selection, and `-0.0` normalization. Equivalent signs serialize identically.
- Machine IDs and display names are separate. Schema, asset, and compiler versions are distinct strong types with independent unsigned `{ major, minor, patch }` values.
- Morphology uses typed values, units, default/recommended/hard domains, symmetry, topology policy, explicit typed target-property addresses, all six operations, writer roles, ordered stages, explicit dependencies, and provenance.
- Base material color is `f32` linear-sRGB straight-alpha RGBA in `0.0–1.0`. Temporary surface state is not part of `MaterialInstance`.
- Component existence, enabled state, visibility, normalized coverage, coverage sources, and representation selection remain separate values.

### Validation and no-silent-repair behavior

The validator covers:

- duplicate IDs, UTF-8 display names, missing references, wrong reference types, roots, parents, and cycles;
- finite coordinate/transform/value checks, canonical quaternions, normalized values, parameter domains/defaults, and joint-range ordering;
- typed target-property rules, allowed operations, explicit binding ownership, one authoritative writer, derived inputs, DAG dependencies, and provenance references;
- anchors, sockets, mount anchors, attachment capacity/type/ownership relationships, and component multiplicity contradictions;
- regions, surfaces, materials, seams, semantic owners, interaction sites/effectors, visibility references, and coverage;
- material definition/instance properties, required properties, value kinds, and base-color channels.

Invalid input produces a deterministic structured report and no normalized value. Validation and normalization do not mutate or repair the source.

### Canonical normalization and hash behavior

- Strict input parsing rejects unknown fields, malformed tagged values, invalid IDs/enums/types, and numeric values that cannot be represented as finite canonical values.
- Omitted aggregate defaults and the coordinate contract resolve explicitly in canonical output.
- Schema-declared unordered records and ID sets serialize in stable-ID order; semantic sequences retain authored order.
- `f32` output is the shortest decimal that round-trips to the same `f32`; `-0.0` becomes `0`.
- Canonical JSON is UTF-8, whitespace-free, and has no trailing newline.
- `source_definition_hash` is SHA-256 over normalized canonical bytes and includes display names. It excludes file names, timestamps, input formatting, and unordered input order.
- Hash domains remain strongly separated for future resolved-geometry, resolved-pose, and representation identities.

## Prompt 3 hardening

- Added a nontrivial quaternion canonical JSON round-trip regression proving that canonical renormalization is byte-idempotent beyond identity/axis-aligned fixtures.
- Changed derived-input inspection to copy into caller-owned storage and stable-ID sort the result. Reordered authoring input now produces identical dependency trace output, matching canonical unordered-input serialization.
- Added exact file-backed diagnostic-location assertions for missing references, normalized coverage, and authoritative-writer conflicts.
- No schema, architecture decision, canonical fixture source, canonical serialization rule, or locked golden hash changed.

## Automated tests

### M01 suite

The focused M01 suite passes **50/50** tests:

- core identity/coordinate/record contracts: 7/7;
- morphology/material/visibility records: 7/7;
- normalization/serialization/hash/validation/trace regressions: 14/14;
- Phase F file-backed proof and determinism acceptance: 22/22.

Coverage includes canonical round-trip, equivalent-input identity, repeated generation, mutation sensitivity, shortest `f32`, `-0.0`, quaternion sign identity, nontrivial quaternion idempotence, local/global transform authority, affine composition, stable diagnostics, stable dependency/driver/input tracing, every required invalid fixture, and strict parser rejection.

### Repository regression and build results

- `zig build check`: **29/29 steps and 484/484 tests passed**. This includes Zig formatting, all repository deterministic test suites, every M01 suite, and repository static policy.
- Host Debug build: **20/20 steps passed**.
- Managed Debug build: reached the accepted `manifest_create AccessDenied` environment limitation; the equivalent host build passed.
- Standalone `zig build test` attempts exhibited the previously accepted outer/test-runner IPC timing variability. One completed 477 tests before a Phase C runner failed to respond; another completed 470 tests before a Phase D/E runner failed to respond. No test assertion failed. The identical aggregate test graph completed all **484/484** tests with exit code zero under `zig build check`.

No test was disabled, skipped, weakened, deleted, or given a relaxed timeout.

## Formal fixture matrix

Valid/equivalent/golden:

- `tests/fixtures/canonical_model/minimal_valid_authoring.json`
- `tests/fixtures/canonical_model/valid/minimal_valid_equivalent_authoring.json`
- `tests/fixtures/canonical_model/valid/minimal_valid_canonical.json`

Targeted invalid:

- `duplicate_id.json`
- `missing_parent_reference.json`
- `component_cycle.json`
- `skeleton_cycle.json`
- `invalid_joint_range.json`
- `non_finite_numeric.json`
- `coverage_out_of_range.json`
- `morphology_dependency_cycle.json`
- `authoritative_writer_conflict.json`
- `invalid_socket_anchor_mount.json`
- `missing_semantic_owner.json`
- `wrong_reference_type.json`

## Empirical evidence

### Canonical valid fixture

The committed normalized payload begins with:

```text
{"schema_identity":{"schema_id":"canonical_creature_schema","version":{"major":1,"minor":0,"patch":0}},"asset_identity":...
```

Observed identity:

```text
canonical_bytes=12022
final_byte=}
trailing_newline=false
source_definition_sha256=b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d
```

The Prompt 2C focused fixture remains:

```text
source_definition_sha256=2855fc11c0f8a1e5698af253c1a89eeb07483e5879556094ea4b6f29149b784b
```

### Representative diagnostics

Observed exact diagnostic identities:

```text
code=missing_reference object=component id=torso property=parent_component_id reference_type=component reference_id=missing_parent
code=coverage_out_of_range object=visibility_metadata id=invalid_coverage property=coverage reference_type=null reference_id=null
code=multiple_authoritative_writers object=morphology_binding id=root_height_b property=target reference_type=rest_bone_transform reference_id=skeleton_root
```

### Morphology trace

```text
dependency_order=group_drives_height -> derive_surface_roughness
derived_inputs(surface_roughness)=[body_height,head_width]
authoritative_writer(head.translation_y)=body_height_bone_binding
```

Reversing the authored derived-input order produces the same stable-ID-sorted trace.

### Local-transform authority

Only `local_rest_transform` appears in canonical bytes; `global_transform` and `world_transform` do not. Derived fixture translations are reproducible:

```text
skeleton_root.global_y=0
pelvis.global_y=0.8
spine_01.global_y=1.2
head.global_y=1.5
```

The nontrivial affine proof observes:

```text
composed_point=(5.8561540,23.5909920,54.0000000)
sequential_point == composed_point within 2e-5
parent +90deg Z maps +X to +Y
shear_dot=2.5000012
repeat_composition=bit-identical
```

The `2e-5` value is an accepted test-only comparison tolerance, not a canonical authoring or morphology tolerance.

## Contract-audit checklist

| Area | Result | Evidence |
|---|---|---|
| Authority and M01 boundary | PASS | Canonical ADR controls; no M02 implementation or `human_base`; downstream ADR is not imported into code authority. |
| Coordinate, naming, identity, and versions | PASS | Explicit locked coordinate record, typed local transforms/IDs/display names, and three distinct version types. |
| Core record families | PASS | Every M01 component, rig, attachment, semantic, interaction-site, and effector family is represented and exercised. |
| Morphology | PASS | Categories, domains, curves, symmetry, topology policy, typed bindings, operations, writer rules, DAGs, stages, and deterministic provenance/trace hooks. |
| Materials and visibility | PASS | Definition/instance separation, canonical base color, no temporary material state, and distinct existence/enabled/visibility/coverage/representation fields. |
| Serialization and hashing | PASS | Explicit defaults, stable ordering, semantic-order preservation, shortest `f32`, canonical quaternion/zero handling, locked bytes, and SHA-256 identity. |
| Validation and no silent repair | PASS | All brief validator classes are covered; invalid parsed fixtures fail closed with precise stable diagnostics. |
| Fixtures and determinism | PASS | Fifteen committed files cover valid/equivalent/golden plus twelve targeted invalid cases; all Phase F acceptance paths pass. |
| Renderer/runtime independence | PASS | Forbidden canonical import scan: 0 matches. |
| Placeholder/skipped-test policy | PASS | TODO/FIXME/stub/placeholder/unreachable/skipped/disabled-test scan: 0 findings. |

## Decisions assumed

None.

## OPEN/TUNING values

None introduced by M01 or Prompt 3.

The accepted `2e-5` affine-test comparison tolerance remains test-only and is not an architecture value.

## Known limitations

M01 intentionally does not implement the actual `human_base` asset, meshes, mesh editing/generation, skinning, morph execution, corrective-shape execution, soft-tissue/contact solvers, collision generation, garment fitting/authoring, animation/IK/choreography execution, shading, atlas generation, 3D-to-2D rasterization, live runtime 3D, or a new editor UI.

Schema hooks for those future systems are identities/references only where M01 requires them.

The repository's Zig test-runner can exhibit long or non-responsive standalone `zig build test` wrappers. This is an infrastructure observation, not a suppressed failure: the full graph passed 484/484 through `zig build check`, and every focused M01 suite passed independently.

## M01 definition of done

1. **PASS** — One coherent canonical model-data subsystem exists under `src/canonical_model/`.
2. **PASS** — The minimal synthetic fixture represents every required M01 concept.
3. **PASS** — Canonical input normalizes and serializes deterministically.
4. **PASS** — Equivalent logical inputs produce identical bytes and hash.
5. **PASS** — Invalid inputs fail with precise, stable diagnostics.
6. **PASS** — Dependency cycles and conflicting authoritative writers are rejected.
7. **PASS** — No silent correction or hidden dependency behavior remains.
8. **PASS** — The subsystem is independent of current 2D renderer visual placement and runtime modules.
9. **PASS** — Relevant pre-existing tests pass: 484/484 under `zig build check`.
10. **PASS** — This owner-review package is complete.
11. **PASS** — No `human_base` mesh/modeling or other M02 work entered M01.

## Owner-review items

- Accept or reject the final M01 implementation and audit evidence.
- No new architecture decision, assumed decision, golden-hash change, or OPEN/TUNING value requires resolution.

## M02 readiness

**Ready, subject to owner acceptance of M01.** The foundation can represent the planned M02 `human_base` structural asset—typed identity/version metadata, the locked coordinate/local-transform contract, component and skeleton structures, semantic landmarks/surfaces, attachments, materials, visibility, morphology bindings, validation, canonical bytes, and source identity—without a schema rewrite.

M02 must instantiate those contracts with the real reviewed structural asset and must not reinterpret the locked M01 authority.

M01 implementation and audit are complete to the extent shown above. I have stopped for owner acceptance and have not begun M02.
