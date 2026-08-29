# F2A — Shared Foundation Primitives and Canonical-Data Substrate

**Status:** OWNER-APPROVED

**Revision date:** 2026-08-28

**Hardening revision:** 3

**Baseline commit:** `9c9833c2ffc21fc5acf4174960200b4b68c9e0f1`

**Authority:** `../architecture/shared_engine_scene_foundation_architecture_v1.md` Revision 2

**Gate:** F1 decisions L2–L6 only

## Outcome

F2A adds the renderer-independent substrate that later foundation milestones
may consume without creating scene, world, registry, or track-owned runtime
systems. The implementation is additive under `src/foundation/`; protected H
canonical source, geometry, assets, hashes, topology, evidence, and runtime
routes remain unchanged.

## Implemented contract

### Identity and versioning

- Strong 128-bit `AssetId`, `EntityId`, namespace, producer, generator, and
  algorithm identity kinds use RFC 9562 network byte order without host-endian
  reinterpretation and use lowercase canonical text. These UUIDs are opaque
  identity values: generation method, version bits, and byte layout are not
  object semantics. Ordinary consumers must not branch on those details or
  infer creation time, age, procedural origin, authoring origin, or meaning.
  Version inspection is restricted to parsing/validation, diagnostics, tests,
  migration, and explicit identity-generation tooling.
- The UUID `byteOrder` operation is unsigned lexicographic ordering of the 16
  canonical bytes solely for deterministic output. It has no semantic or
  chronological meaning, including for UUIDv7 values.
- UUIDv5 supports the RFC algorithm and a domain-tagged, length-framed field
  form. Its RFC-required SHA-1 algorithm is retained; it is not being used as a
  general cryptographic-security primitive. UUIDv5 is for identities that must
  be reproducible from a registered namespace and canonical semantic inputs.
  UUIDv7 is for genuinely new unique persistent identities. It accepts the
  48-bit Unix-millisecond clock and a ten-byte entropy input explicitly; the
  version and variant overwrite six reserved input bits, leaving the
  RFC-defined 74 effective entropy bits. It does not read ambient time or
  randomness, and higher-level clock/entropy sourcing is outside F2A.
- Namespace registrations are bounded, duplicate-rejecting, and stored in
  canonical UUID byte order. Once a NamespaceId derives any persisted UUIDv5
  identity, it is a permanent protocol identity: it cannot be regenerated,
  reassigned, or repurposed. Metadata may describe it but cannot redefine it;
  an incompatible semantic domain receives a new namespace. The current F2A
  tree defines no production repository-wide namespace constant or permanent
  registration. Before any production persisted UUIDv5 identity is issued,
  its permanent registration must be added to `src/foundation/identity.zig`
  alongside the identity contract and reviewed as protocol data. Existing test
  namespaces remain fixtures only.
- Although the strong types expose `[16]u8` for canonical storage and hashing,
  raw struct construction is unsupported for authored, serialized, saved, or
  public subsystem boundaries. Supported construction is validated canonical
  parsing, `fromCanonicalBytes`, UUIDv5 derivation, or UUIDv7 generation. Every
  later F load/parse/serialization/public-data boundary must validate bytes;
  the Zig type alone is not proof of a valid UUID.
- The existing H-owned semantic string identity remains a separate type. Its
  boundary mapping is an explicit UUIDv5 derivation in a registered namespace;
  no H type or protected serializer is changed.
- Schema, asset, producer/compiler, generator, and algorithm versions are
  non-interchangeable `u32.u32.u32` semantic triples.
- `EntityHandle` is only an eight-byte `{slot: u32, generation: u32}` runtime
  acceleration/reference value with equality and validity checks. It is not
  persistent identity, must not be serialized as authored identity, and is not
  stable across scene unload/reload or process restart. `slot` identifies a
  future runtime storage location; `generation` is reserved for stale-handle
  detection after recycling. `slot == maxInt(u32)` and generation zero remain
  invalid. F2C owns registry/storage, allocation/recycling, generation
  increments and wrap behavior, stale rejection, free lists, component lookup,
  and persistent-ID-to-handle resolution.

### Exact asset references and dependencies

- `AssetRef` pins expected kind, persistent asset identity, asset version, and
  SHA-256 content hash.
- Within one resolved graph/context, one AssetId resolves to exactly one exact
  AssetRevision. Duplicate-by-AssetId rejection is intentional even when two
  records name different versions or hashes. Editors and migration tools may
  compare revisions only in separate explicit comparison contexts; canonical
  authored/runtime graphs never contain a floating `latest` reference.
- Direct dependencies are classified as semantic/runtime-required,
  optional-presentation, or tooling-only.
- Duplicate dependency identities, catalog duplicates, missing exact
  revisions, revision/kind mismatches, and cycles fail explicitly.
- Direct and transitive dependency-set hashes use separate versioned domains,
  canonical exact-reference ordering, and caller-provided bounded scratch.
  Optional-presentation changes cannot alter the semantic/runtime closure hash.

### Persistent protocol golden vectors

The custom strings `foundation.uuid_v5_fields.v1`,
`foundation.asset_direct_dependencies.v1`, and
`foundation.asset_transitive_dependency_set.v1` are part of persistent
deterministic protocols, including their exact framing. They must not be edited
in place. An intentionally incompatible future algorithm requires a new,
explicitly reviewed domain/version string. Fixed tests pin these v1 results:

| Contract | Fixed output |
| --- | --- |
| UUIDv5 fields, DNS namespace, fields `["ab", "c"]` | `d2da82ec-d870-5a00-a872-bb67f274fe9f` |
| H semantic asset mapping, DNS namespace, `human_base.body` | `a444d435-d36f-59e1-b131-05906851406e` |
| UUIDv7, timestamp `1700000000123`, entropy `12 34 56 78 9a bc de f0 55 aa` | `018bcfe5-687b-7234-9678-9abcdef055aa` |
| Direct semantic/runtime dependency fixture | `a4c94bd2dbf344fbd2da9c5a7cc363bd79e6975e2d56b3ed998e7a73088c88d6` |
| Transitive semantic/runtime dependency-set fixture | `1f5078214df900758d5fa1702d7a9c3660176d8e9304324cb1bcd203cc6f0ee4` |

The UUIDv5 field vector was independently checked against namespace bytes,
the literal v1 domain, a big-endian `u32` field count, and a big-endian `u32`
length followed by bytes for every field. Dependency vectors were independently
checked against the domain frame, class byte, big-endian selected count,
canonical exact-reference order, framed kind, UUID bytes, three big-endian
version components, and content hash. Property tests for ambiguity, ordering,
class isolation, optional-presentation isolation, cycles, duplicates, and exact
revision mismatches remain in addition to these vectors.

### Spatial façade and conformance

- Shared 3D primitives use metres, `f32`, right-handed `+X` right, `+Y` up,
  `+Z` forward, and `+X × +Y = +Z`. This is the common engine/world contract;
  renderer screen/clip space, texture coordinates, and specialized physics
  representations convert at subsystem boundaries rather than redefining it.
- Vectors are columns. Local application is `T × R × S × point`: scale, then
  rotation, then translation. Hierarchy composition is `world = parent × local`
  and therefore `world_point = parent(local(point))`. Affine `x_axis`, `y_axis`,
  and `z_axis` are the linear-matrix basis columns; translation is the affine
  fourth column.
- Quaternions store `x, y, z, w` and must be unit length within the published
  tolerance before canonical normalization. Since `q` and `-q` are equivalent,
  F chooses positive `w`; at `w == 0`, the first nonzero component in `x, y, z`
  is positive. Signed zero is normalized.
- Local authored transforms are TRS. Derived transforms are full affine bases
  so non-uniform-scale/rotation composition retains shear instead of silently
  discarding it.
- Unit-quaternion, basis-orthogonality, affine absolute/relative,
  minimum-scale, and relative-determinant tolerances are named constants.
- The published values are `1e-5` for quaternion-unit acceptance, `1e-5` for
  basis orthogonality, and `abs(a-b) <= 1e-5 + 1e-5 * max(abs(a),abs(b))`
  per affine component; minimum invertible axis scale is `1e-6`, and the
  determinant threshold is `1e-8` times the product of basis-axis lengths.
- Affine inverse is explicit. Decomposition assigns a negative determinant to
  the X scale canonically, rejects zero/near-singular axes, rejects shear as
  non-representable TRS, recomposes, and verifies the accepted tolerance. The
  result preserves the spatial transformation but need not restore the exact
  originally authored scale signs: for example, authored negative Y may become
  canonical negative X plus an adjusted rotation. A focused test pins negative
  X as the reflection component.
- These numerical values are reviewed contract data. Future changes may alter
  inverse/decomposition success and require explicit review rather than local
  retuning.
- Tests compare results with the protected canonical 3D math and the current
  2D transform route. No production adapter or protected-pipeline extraction
  is included.

### Canonical data, determinism, and diagnostics

- A bounded canonical writer defines UTF-8 string escaping, lowercase control
  escapes, shortest round-tripping finite `f32`, normalized negative zero,
  and no trailing whitespace or newline. NaN and both infinities fail.
  Object fields and record collections sort deterministically and reject
  duplicate keys; semantic arrays preserve caller-declared order.
- SHA-256 helpers use validated, versioned, length-framed domains and lowercase
  hex digests.
- Protected canonical-model and canonical-geometry fixtures are regenerated
  in tests and required to retain their exact accepted bytes and hashes.
- `Seed128` and deterministic child seed/key derivation consume explicit root
  seed, generator identity/version, algorithm identity/version, and stable
  keys in caller-supplied semantic order. Versions use big-endian components;
  every hash field is length-framed. No ambient time, process/thread/pointer
  state, host byte order, iteration order, or global RNG input exists.
  `foundation.seed_child.v1` and `foundation.key_child.v1` are distinct
  persistent protocol domains; generator/algorithm identity or version changes
  intentionally change derived output.
- `SceneTime` means exactly `tick + numerator / denominator`, with a reduced
  nonnegative fraction below one. Whole ticks use `sub_tick = null`, and
  `tick = -1, sub_tick = 1/2` means `-0.5` ticks. It represents a coordinate in
  a scene-defined tick domain and deliberately does not define seconds per tick;
  runtime, cinematic, or offline contexts own that external mapping.
- `Writer.raw`, `Field.canonical_value`, `Record.canonical_value`, and
  `semanticArray` accept trusted already-canonical fragments. They are not
  external JSON parsers or validators. The supported flow is external input →
  parse → validate → canonicalize → trusted fragment → low-level composition.
- Diagnostics carry stable severity/code, optional schema context, object and
  property paths, and typed reference identity. A caller-bounded collector
  produces deterministic ordering independent of insertion order.

### Final deterministic protocol golden vectors

The `.v1` domain strings and their length/count framing are persistent protocol
identifiers, not labels. An incompatible future algorithm requires a new
reviewed domain/version; existing expected values must not merely be rewritten
to silence a regression. Independent SHA-256 reproduction of the current
big-endian, length-framed algorithms established these fixed outputs:

| Contract | Fixed output |
| --- | --- |
| `deriveSeed`, existing generator/algorithm/key fixture | `6b00742bb4af43281b71229730f8f709` |
| `deriveKey`, existing generator/algorithm/key fixture | `2823de51114f8ce37afeeaa40cbe1455bce52eb356888b4a7604ba6612cd8c7c` |
| `hashDomainSeparated("foundation.test.v1", ["ab", "c"])` | `bb8e5938e4750fb1bb120a2f01bee778569fcfc6b382baa0ee4409ee4ce39f01` |

These assertions supplement the existing same-input stability, ordered-key,
unambiguous-framing, version-change, domain-separation, and protected-output
tests; they do not replace them.

### Capacity choices

- Canonical output is written into caller-owned byte storage. Object and
  sorted-record operations require one caller-owned `usize` scratch entry per
  field or record and fail before emission when scratch is insufficient.
- Namespace and diagnostic collectors use caller-owned fixed storage and
  return `CapacityExceeded` without partial insertion when full.
- Dependency closure requires caller-owned state and selected-index arrays of
  at least the catalog length. Direct-dependency hashing requires one index per
  matching-class entry. Insufficient scratch is an explicit error.
- Seed/key derivation accepts at most 64 stable key fields; exceeding that
  declared bound is an explicit `TooManyFields` error.
- Asset-kind and hash-domain names are limited to 127 bytes, namespace owner
  and purpose labels to 127 bytes, and H semantic-ID boundary strings to 255
  bytes. All are validated before storage or hashing.

## File and dependency boundary

```text
src/foundation/root.zig
├── canonical_data.zig
├── identity.zig
├── version.zig
├── reference.zig       -> identity, version, canonical_data
├── spatial.zig
├── determinism.zig     -> identity, version, canonical_data
└── diagnostics.zig     -> identity, version

tests/foundation/*
├── foundation production module
├── canonical_model test-only conformance oracle
├── canonical_geometry test-only conformance oracle
└── current_transform2d test-only conformance oracle
```

No `src/scene_core/` path was created. Existing `src/scene/` production code
does not consume F2A yet, and F2A does not import it.

## Verification and acceptance boundary

The focused target is `zig build test-foundation-primitives -j1`. It is also
part of `test`, and consequently of `check` and `test-full`. The final command
outcomes belong in the implementation handoff rather than being predeclared in
this record.

F2A does not authorize F2B or F2C. In particular, this implementation does not
add authored world/level/prefab/entity schemas, extension descriptors or
payload framing, a runtime scene, entity registry lifecycle behavior,
hierarchy mutation, `keep_world`, snapshot publication, or track-owned
compiled tables.
