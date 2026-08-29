# F2B — Authored Scene and World Definitions

**Status:** OWNER-APPROVED

**Revision date:** 2026-08-29

**Hardening revision:** 2

**Baseline commit:** `1a52e1311b82408f506958c507713f79adaf7c78`

**Authority:** `../architecture/shared_engine_scene_foundation_architecture_v1.md` Revision 2

**Gate:** F1 decisions L1 and L7–L13 plus the accepted F2A APIs

## Outcome

F2B adds the immutable authored side of the shared scene foundation. It defines
versioned prefab, level, world, entity-instance, camera, metadata, extension,
migration, canonical-serialization, and validation contracts under
`src/scene_core/`. The module depends only on `foundation` and the Zig standard
library. No production runtime path imports it yet.

F2B does not add `RuntimeScene`, `SceneSnapshot`, an entity registry, handle
reuse, mutable hierarchy commands, scene assembly, downstream compiled tables,
save-game state, or renderer/physics/editor integration. Those remain F2C or
separately authorized downstream work.

## Authored definitions

- `PrefabDefinition` is a reusable composition graph. Stable lowercase
  `PrefabNodeId` values identify nodes within one prefab asset. Nodes may
  reference exact nested prefab revisions; inheritance is absent.
- `EntityInstanceDefinition` is one authored placement with a persistent
  `EntityId`, local TRS, optional required parent reference, optional exact
  prefab reference, stable-path overrides, tags, enabled/visibility intent,
  placement classification, neutral links, and extension records. It contains
  no runtime handle, world matrix, dense index, or track-owned compiled state.
- `LevelDefinition` owns a streamable set of placements. Its authored origin is
  exact signed integer millimetres in the stable world frame, while entity
  transforms remain level-local `f32` metres. This makes the current boundary
  explicit without authorizing large-world or floating-origin runtime work. A
  future floating origin is derived runtime state: it must publish an explicit
  origin-shift generation and cannot rewrite this origin, local transforms, or
  persistent IDs.
- `WorldDefinition` references zero or more exact level revisions and owns
  world-persistent placements. It is not save-game or mutable world state.
- F camera data is restricted to perspective focal/sensor geometry or
  orthographic extent, lens shift, and geometric near/far clip ranges.
  Exposure, depth of field, shutter, post-processing, viewport, jitter,
  render-target, and GPU state are deliberately absent.

## Asset and reference envelope

Every authored document materializes:

- schema ID and strong schema version;
- logical `AssetId`, strong asset version, exact `AssetKind`, and optional slug;
- producer ID and strong producer version;
- exact classified direct dependencies;
- optional deterministic generator provenance;
- optional typed `PresentationRef`; and
- the schema-specific payload.

Prefab, level, and world schema IDs are fixed protocol data in
`src/scene_core/asset.zig`:

| Document family | Permanent schema UUID |
| --- | --- |
| Prefab | `01a04ad0-e800-7234-9678-9abcdef01122` |
| Level | `01a04ad0-e800-7345-a789-abcdef012233` |
| World | `01a04ad0-e800-7456-b89a-bcdef0123344` |

Each UUID identifies its document family, not one version of that family. The
same Level UUID therefore frames the `0.9.0` pre-acceptance draft, accepted
`1.0.0`, future compatible `1.x` revisions, and a future migrated major if the
document remains the Level family. A genuinely distinct incompatible document
family receives a different UUID. These constants are permanent once accepted
into persisted authored data: they must not be regenerated for a version bump,
and their UUID version/timestamp bits are opaque allocation details with no
schema, ordering, age, or compatibility meaning.

The constants were allocated through F2A's UUIDv7 API with the explicit
Unix-millisecond input `1787961600000` and three fixed ten-byte entropy inputs;
no ambient clock/random source or unregistered UUIDv5 namespace is involved.
The hardening pass preserved all three byte values while correcting only the
pre-acceptance version history. Exact `AssetRef` values reuse F2A identity,
version, kind, and SHA-256 types. Synthetic catalogs enforce one revision per
AssetId and reject missing identities, wrong kinds, and version/hash mismatch.
A presentation link is valid only when the same exact asset is declared as an
`optional_presentation` dependency, so UI/localization changes cannot enter
simulation-semantic identity silently.

## Canonical JSON and versions

Canonical output uses snake-case fields, sorted object keys and unordered
record collections, semantic array order where order is meaningful, finite
shortest round-tripping numbers, normalized zero, explicit defaults, no
insignificant whitespace, and no trailing newline. External extension and
override JSON values are parsed and re-emitted through the same canonical
value boundary before storage. Already-normalized definitions may be emitted
only when every embedded payload is canonical.

The canonical asset domain is
`foundation.scene_core.authored_asset.v1`. Its framing is persistent; an
incompatible future algorithm requires a new reviewed versioned domain. The
accepted `1.0.0` protocol goldens fix these outputs:

| Contract | Fixed output |
| --- | --- |
| Minimal canonical empty Level | 432 bytes, newline-free |
| Minimal Level versioned domain SHA-256 | `30580590a1b397494d8054bf552cf4841dd73a5339e7a5d7ece8b938ac162bac` |
| Representative populated canonical Level | 2,331 bytes, newline-free |
| Representative Level versioned domain SHA-256 | `8a5c30cbf717208ae60ea30a4363489d4b822569e2902d95d856ba119596c736` |

The minimal golden protects the envelope and explicit empty/default
representation. The representative golden protects an exact signed `i64`
millimetre origin, two persistent entities, deterministic hierarchy and
collection order, repeated use of one exact prefab reference, local transforms,
a bounded override, tags, neutral perspective camera geometry, and one
synthetic optional-preserve `r.light` extension. Property and behavioral tests
remain authoritative in addition to these fixed snapshots.

The prior pre-acceptance empty-Level candidate was also 432 bytes and hashed to
`d1184ca93b2fa73c7cc8dafa2ae17d05d9d8cc189cd48927caafa6e4acadf043`.
The only canonical-byte change in that candidate is schema version text
`2.0.0` becoming accepted `1.0.0`; the byte count is unchanged, while the
versioned domain hash changes as intended. Both accepted goldens were written
from an independent field-order inspection and reproduced outside the Zig
serializer with UTF-8 canonical text plus the documented big-endian
length-framed `foundation.domain_hash.v1` protocol before being frozen in tests.

Current authored schemas begin at accepted `1.0.0`. Compatibility is defined
as follows:

- a **major** change is structurally or semantically incompatible and requires
  explicit migration or new reader support; it retains the schema-family UUID
  when it remains the same document family;
- a **minor** change is intentionally additive and compatible through defined
  optional fields, defaults, or capabilities, but readers accept a future
  minor only after explicit feature/version support is registered; and
- a **patch** preserves the same wire-level authored structure and identity
  semantics. It may clarify or correct parser, validation, implementation, or
  documentation behavior, but cannot add required fields, redefine meanings,
  or require structural migration.

The registered current reader accepts `1.0.x` and preserves the parsed patch.
It explicitly rejects future `1.1.x`, future majors, and malformed versions.
`SchemaVersion` remains strongly distinct from `AssetVersion`. Authoring JSON
may omit documented defaults; canonical save materializes them. Unknown F-owned
fields and duplicate JSON members fail.

The implemented migration is Level `0.9.0 -> 1.0.0`. `0.9.0` is the immediately
preceding synthetic, pre-acceptance F2B draft; it was never an accepted or
shipped production schema. The original `1.x -> 2.x` labels were introduced
inside F2B to demonstrate migration and did not represent repository history.

The migration remains a real representation change. Draft `0.9.0` stores the
Level origin in exact integer metres as `origin_m` and requires a smaller
entity record containing identity, local transform, parent, prefab reference,
and extensions. Migration multiplies every origin component by 1,000 with
checked `i64` arithmetic, emits current `origin_mm`, and materializes current
activation, visibility, classification, overrides, tags, layers,
presentation, camera, and volume-boundary defaults. It preserves the schema-
family UUID, AssetId, EntityIds, transforms, parents, prefab references, and
extensions, and sets only the schema version to `1.0.0`. The acceptance path
passes that candidate through current F2B validation and canonical reparse,
proving deterministic current output. Migration emits two stable notes, never
rewrites the source, and fails atomically on overflow, unsupported source
version, or insufficient report capacity.

## Extension and metadata governance

- `ComponentTypeId` is a lowercase dot-separated identifier whose first
  segment is one of `f/w/r/p/e/u/c/a/h`; maximum length is 127 bytes.
- Descriptor registration uses caller-owned bounded storage, freezes before
  validation, sorts by type ID/version independent of registration order, and
  rejects duplicates, ambiguous routes, or post-freeze changes.
- A descriptor validates the canonical payload and the complete declared
  direct-dependency report before future compilation. Every reported record
  must also appear exactly, with the same class, in the owning asset header.
  Scene core imports no downstream descriptor implementation.
- Unknown required extensions fail. Unknown `optional_preserve` records retain
  canonical payload bytes, exact version, criticality, and dependencies.
- One entity or prefab node is limited to 32 records, one payload to 64 KiB,
  and aggregate extension payloads in one F asset to 1 MiB.
- `TagId` uses lowercase `namespace:name`, is limited to 63 bytes, and is
  bounded to 64 sorted unique values per entity or node.
- Enabled intent is `inherit/enabled/disabled`; a disabled ancestor cannot be
  re-enabled by a child. Enable order is parent-before-child, disable order is
  child-before-parent, with EntityId sibling ties.
- Visibility intent remains separate from enabled state. Render, lighting,
  collision, and navigation layer assignments remain distinct typed systems
  whose reference kind must use the owning track namespace; there is no shared
  bit mask.
- `VolumeShapeRef` reserves only exact `f.volume_shape` asset identity. Shape
  coordinates are entity-local metres; no shape payload, collider, trigger, or
  volume behavior is implemented.

## Validation and determinism

Validation covers exact headers and references, dependency duplication,
provenance keys, transforms, persistent-ID uniqueness, required parents,
self-parenting, missing parents, cycles, maximum hierarchy depth, deterministic
parent/sibling order, prefab node graphs, nested prefab cycles/depth, stable
override targets, tag/layer limits, extension descriptors and aggregate size,
neutral cameras, presentation classification, typed volume references, and
world/level placement rules.

Level parents resolve only within that level or to an explicitly supplied
world-persistent anchor. An arbitrary cross-level parent fails. World
persistent placements must use authored classification; editor-preview and
cutscene-overlay placements stay scoped to levels/hosts and do not silently
become persistent world state.

Diagnostics reuse the F2A stable codes, schema context, object/property paths,
and deterministic collector ordering. Validation APIs return typed failures;
callers attach the appropriate stable diagnostic at their schema boundary.

## File and dependency boundary

```text
src/scene_core/root.zig
├── asset.zig
├── canonical_json.zig
├── camera.zig
├── entity.zig
├── extension.zig
├── hierarchy.zig
├── level.zig
├── metadata.zig
├── migration.zig
├── prefab.zig
├── serialization.zig
├── validation.zig
└── world.zig
    └── imports only foundation + Zig standard library

tests/scene_core/*
└── imports only scene_core + foundation + synthetic fixtures
```

Protected canonical-model, canonical-geometry, topology, assets, evidence, and
current runtime routes are not imported or modified.

## Verification and F2C handoff

The focused target is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-scene-core-authored -j1
```

It is part of `test`, and therefore of `check` and `test-full`. Its 39
declarations cover both canonical byte/hash goldens, reordered-input
determinism, schema-family permanence, the explicit major/minor/patch policy,
the file-backed `0.9.0 -> 1.0.0` migration, migration validation and canonical
reparse stability, explicit and omitted defaults, schema rejection, exact
catalogs, hierarchies, reusable street-lamp composition, multi-level worlds,
extension isolation/limits, metadata ownership, and strict camera/volume
boundaries.

After owner acceptance, neither golden may be updated merely because a
refactor changes output. A mismatch triggers investigation. An intentional
schema/protocol change requires an approved reason, compatible version policy
or explicit migration, and independent regeneration of exact bytes, length,
and domain hash.

F2C may consume only normalized validated current-schema definitions. It must
still implement transactional scene assembly, generation-checked registry
storage, handle lifecycle and retirement, loaded-level ownership, exact unload
behavior, reparent/removal modes, immutable snapshots, command authority,
capacity/growth reporting, and two-phase publication across RuntimeScene and
track-owned compiled tables. F2B does not begin or partially implement any of
those responsibilities.

The accepted authority split also remains future work: W owns the top-level
save-game/world-state envelope and level/persistent partitioning, while P owns
versioned gameplay/simulation payloads inside it. W may request entity
create/destroy for level load/unload and accepted generation; P may request
gameplay spawn/despawn and persistent-state promotion; A/C may request only
host-scoped previews or overlays. F2C must validate those owners and publish
core plus track-owned compiled tables atomically or roll everything back.
