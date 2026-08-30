# Shared Engine / Scene Foundation Architecture and Dependency Contract

**Status:** F1 owner-approved; F2A separately authorized only by a dedicated implementation request

**Revision:** 2

**Date:** 2026-08-25

**Scope:** Shared contracts required before parallel F/W/R/P/E/U/C/A/H work

**Milestone gates:** F2A requires L2-L6; F2B requires L1 and L7-L13 plus accepted F2A APIs; F2C requires the runtime portions of L7 and L9, L14-L15, plus accepted F2B schemas

This record establishes the owner-approved shared engine/scene contract after inspection of the
current repository. It does not supersede accepted character, renderer,
canonical-model, canonical-geometry, or visual-evidence authority. In
particular, it introduces no production types, changes no current runtime
path, and does not itself authorize implementation. Every F2 milestone, world
generation, rendering, physics, effects, UI, cinematics, editor, or
Human/Character implementation still requires its own dedicated request.

## A. Current-State Audit

### A.1 Repository shape and dependency facts

The repository is a bounded 2D character/runtime prototype with one SDL3 GPU
renderer, one fixed-step simulation model, several composition-root `Scene`
types, and a separate offline canonical 3D model/geometry pipeline. It is not
currently a general world/entity/prefab engine. `build.zig` explicitly wires
the Zig module graph; there is no package registry, reflection-based component
loader, editor runtime, or general scene serializer.

The current dependency direction is sound in important places:

- simulation math, physics, animation, interactions, and character state are
  testable without SDL or a GPU;
- `UnifiedRenderQueue` consumes resolved render requests and does not own
  gameplay state;
- environment presentation consumes, but does not redefine, collision
  geometry;
- definitions are generally immutable and mutable state is instance-owned;
- current editors are deferred and ADR-005 requires future editors to write
  the same validated production definitions used by runtime consumers;
- canonical model and geometry source data already use strict parsing,
  normalized deterministic JSON, typed IDs, explicit versions, strong hashes,
  and fail-closed validation.

The missing layer is a renderer-, physics-, editor-, and character-independent
contract for assets, placed objects, levels, persistent entities, scene
assembly, and runtime entity handles.

### A.2 Existing equivalents and disposition

| Existing module/type | Current responsibility, owner, and consumers | F disposition | Compatibility risk |
|---|---|---|---|
| `src/scene/visual_foundation.zig` `Scene` | Current visible Prompt 27 composition root. It owns an `environment_demo.Scene`, interaction manager, evidence state, debug state, and submission orchestration. Consumed by `gpu_demo` and visual-foundation tests. | **Remain.** Treat as an integration/demo root, not the general meaning of `Scene`. A later adapter may consume F runtime views. | Renaming or converting it during F2 would disturb accepted evidence and cross-system tests. |
| `src/scene/environment_demo.zig`, `wardrobe_demo.zig`, `foundation_playground.zig`, and other `*_demo.zig` `Scene` types | Milestone-specific compositions embedding definitions, collision, characters, clocks, cameras, evidence, and input. | **Remain.** Do not infer a canonical scene schema from these concrete aggregates. | Their shared name hides materially different ownership and lifecycle semantics. |
| `character.EntityId`, `EntityIdAllocator`, `EntityRegistry` | Nonzero sequential `u32` identity for at most eight current character instances. Interactions and deterministic character sorting consume it. | **Wrap, then migrate later.** Classify it as a current runtime identity, not serialized persistent identity. Keep its API until an H/P adapter is accepted. | Persisting it would make identity depend on load order and would collide across levels/worktrees. Replacing it in F2 would create broad H/P churn. |
| `CharacterInstance` and `HumanoidDefinition` | Strong current example of definition/instance separation: immutable skeleton/appearance/anatomy definitions are shared; pose, controller, procedural, loadout, presentation, and IK state are instance-owned. | **Evolve by analogy, not inheritance.** F runtime entities may host a later H-owned character runtime keyed by an F runtime handle. | A general entity must not absorb the character's mutable state or force all entities into the humanoid schema. |
| `math.Transform2D`, `Mat3`, `composeParentChild` | Runtime 2D local TRS and derived affine composition using `parent_world * child_local`; finite validation and deterministic interpolation. | **Remain.** Provide an explicit F 3D-to-current-2D adapter later; do not change current rendering/physics math in F2. | Negative X scale is current facing/reflection policy. A new transform validator must not accidentally outlaw it. |
| `animation.SkeletonDefinition`, `Pose`, appearance/anatomy/module hierarchies | Parent graphs with validated references, cycle rejection, deterministic evaluation order, local authoritative transforms, and derived world matrices. | **Reuse the invariants.** Entity hierarchy is separate from skeleton and component hierarchies but should share affine semantics and validation philosophy. | Treating bones or anatomy parts as world entities would conflate lifetimes, identity scopes, and hot-path storage. |
| `canonical_model.math3d.LocalTransform`, `AffineTransform`, `Quaternion` | Renderer-independent 3D local TRS, canonical quaternion rules, and affine composition including possible shear from nonuniform parent scale. | **Compatibility target.** F should adopt the same coordinate and transform semantics. Whether code is extracted or bridged is an owner decision in L. | Directly importing `canonical_model` from F would invert F -> H dependency. Duplicating behavior without conformance tests could drift. |
| `canonical_model.identity` | Lowercase `snake_case` typed IDs; separate schema/asset/compiler semantic versions; display names distinct from IDs. IDs are primarily definition-local semantic identifiers. | **Preserve and bridge.** Keep canonical asset-internal IDs unchanged. Add globally stable F asset/entity IDs rather than repurposing these strings. | Renaming existing IDs changes canonical bytes and protected SHA-256 identities. String IDs alone do not safely support decentralized world/entity creation. |
| `canonical_model.definition.CanonicalCreatureDefinition` | Canonical creature asset containing components, rig, attachments, semantics, morphology, materials, and visibility metadata. | **Remain H-owned and independent.** Register/wrap a canonical creature as an asset consumable from F; do not turn it into a world object schema. | It has exactly one component root (`body`) and human/creature validation assumptions unsuitable for general scene entities. |
| `canonical_model.material.MaterialDefinition` / `MaterialInstance` | Renderer-independent semantic material capability/property schema inside the canonical creature definition. | **Remain.** R may evolve a general material asset and provide a lossless mapping for canonical material instances. F owns only typed asset-reference semantics. | Moving these records or changing serialization could invalidate canonical source hashes and geometry compatibility. |
| `canonical_model.parsing`, `normalization`, `serialization`, `hashing`, `validation`, `diagnostics` | Strict unknown-field parsing; deterministic field/record order; shortest round-tripping `f32`; no nonfinite values; canonical quaternion/zero handling; newline-free bytes; SHA-256; sorted diagnostics. | **Evolve into a shared canonical-data utility only with byte-for-byte regression protection.** Scene schemas should use the same rules, not a competing format. | The serializer is currently schema-specific, and canonical geometry already has a separate implementation. A careless extraction can drift protected bytes. |
| `src/canonical_geometry/` | Separate offline, renderer-independent geometry schema bound to the canonical structural source by exact identity/version/hash. Owns stable mesh/vertex/face IDs, UV/surface channels, seams, module interfaces, collision proxies, deterministic serialization, and validation. | **Remain H-owned and independent.** F AssetRef may point to a geometry asset; R/P adapters may consume compiled derivatives later. | It is not the runtime mesh format and must not be rewritten to satisfy scene serialization. |
| `graphics.art_pack` | Immutable renderer/presentation catalog with typed texture-page, atlas-region, semantic, and view IDs; canonical relative PNG paths; derived runtime page indices/UVs. | **Remain R-owned.** Expose art packs as assets behind F references. Do not use atlas IDs as general asset/entity IDs. | Runtime indices are load-order accelerators and are not stable serialized identity. |
| `graphics.deformable_mesh` | Current bounded 2D runtime/render mesh definition and per-instance binding/deformation state. Its `MaterialReference` is a stable string plus texture page and tint. | **Remain R/H compatibility code.** Later R adapters should replace the fixed material tuple with a resolved material handle sourced from an F MaterialRef. | The current material tuple is renderer-specific and too narrow for emission, transmission, layering, or offline rendering. |
| `graphics.camera2d.Camera2D` / `HorizontalFollower` | Current presentation camera state, viewport projection, height-relative pixels-per-metre policy, and gameplay follower. | **Remain.** Adapt from a future shared camera definition and track-owned controller; do not make this GPU-uniform-oriented type the authored camera schema. | It mixes resolved viewport state with current 2D projection policy and has no stable asset identity or authored camera definition. |
| `physics.CollisionWorld`, `StaticCollider`, `ColliderId` | P-owned immutable array of bounded static AABBs and deterministic queries/sweeps. Current world data is constructed directly in Zig from `foundation_world.colliderInputs`. | **Remain P-owned.** A later P compiler consumes F/W definitions and produces this hot runtime representation. | Calling it the shared `World` would couple authored data to AABBs and current character-controller needs. Collider IDs are definition-local `u16`, not persistent entity IDs. |
| `scene.environment_theme` / `environment_art` | R-facing environment presentation layered over the one current collision world. Derives standable white surfaces from collision and submits far/mid/gameplay/foreground art. | **Remain.** Split only in downstream W/R migration: W owns spatial content; R owns presentation/theme implementation. | Current terrain visuals iterate colliders directly and numeric scene layers live in character code, creating a future W/R/H seam. |
| `graphics.render_queue`, `sprite_batch`, `mesh_gpu_catalog`, `gpu_demo` | R-owned hot-path render requests, sort keys, batching, GPU resources, and current application composition. | **Remain R-owned.** Consume resolved scene views through an adapter; never store authored entity strings/UUIDs in per-draw hot paths. | `gpu_demo.zig`, `build.zig`, and `src/main.zig` are high-conflict integration files. |
| `interaction.Definition`, `interaction_system.Instance` / `Manager` | P-owned immutable definition versus bounded runtime instances, using character runtime IDs and shared fixed ticks. Includes a narrow interaction presentation boundary. | **Remain.** Later use F EntityRef for authored participants/anchors and EntityHandle at runtime through a P adapter. | Current IDs are character-only and no world-object anchor entity exists. |
| `presentation_view.Runtime` and `interaction.PresentationDefinition` | Current H/P presentation selection and interaction view/occlusion policy. | **Remain domain-owned.** They are not replacements for asset display name/description/icon metadata or general camera definitions. | Reusing the term `PresentationDefinition` for UI asset metadata would be ambiguous. |
| `character.SceneLayers` and render order tuples | Current R/H numeric background/world/character/foreground ordering plus interaction/actor/body-part layers. | **Remain R-owned compatibility policy.** Do not create one F `layer` integer shared by render, collision, lighting, and navigation. | Numeric scene layers currently live in `character.zig`; migrating them needs an R/H-owned adapter and tests. |
| `animation.procedural_motion` | Deterministic analytic fixed-tick motion. It contains no PRNG or procedural-generation seed model. | **Remain.** Do not treat the word “procedural” as evidence of world-generation infrastructure. | F currently has no stable seed, generator identity/version, or random-stream contract. |
| Documentation/authoring tools | ADR-005 and scope documents require editors to emit production schemas. Blender tooling is specialized to canonical geometry. There is no general editor module. | **Preserve.** A must depend on F and track-owned validators; F must not depend on A. | An editor-only entity/identity/collider/material model would fork authority. |

### A.3 Concepts that are absent or only reserved

The audit found no production general `WorldDefinition`, `LevelDefinition`,
`PrefabDefinition`, persistent entity ID, runtime entity handle with generation
checking, entity transform hierarchy, save-game schema, scene-time evaluation
request, procedural seed metadata, general asset registry, authored light,
authored camera asset, general presentation metadata asset, general tags,
separate collision/render/lighting/navigation layer references, or spatial
volume/zone contract. Light behavior is absent; the only source-level emission
example is a canonical material property test. These are genuine foundation
gaps, not alternate names hidden elsewhere.

## B. Proposed Architecture

### B.1 Dependency rule

The shared direction is:

```text
authored/generated definitions
            |
            v
F canonical assets + world/level/prefab/entity contracts
            |
            v
F validated assembly + resolved core runtime scene
            |
      +-----+------+------+------+------+
      v            v      v      v      v
      R            P      E      C      U/A read views
  rendering     physics effects cinema  tools
```

F owns stable data and resolution rules. Specialized tracks own behavior and
compiled hot-path storage. F does not import R/P/E/U/C/A/H modules. W depends
on F to author or generate definitions. Editors depend on F and the relevant
track validators. Runtime consumers may publish typed read views or compiled
tables keyed by an F runtime handle; they may not push implementation-specific
objects back into authored F definitions.

### B.2 Proposed repository modules

F2 should add real files only as their sub-milestone needs them:

```text
src/foundation/
  root.zig                 public F surface
  identity.zig             AssetId, EntityId, typed local IDs
  version.zig              schema/asset/generator versions
  reference.zig            AssetRef, EntityRef, resolved refs
  spatial.zig              shared Vec3/quaternion/local TRS/affine contract
  canonical_data.zig       shared canonical JSON primitives and hashing rules
  determinism.zig          seed, generator identity, scene time, dependency set
  extension.zig            namespaced downstream component/section descriptors
  diagnostics.zig          deterministic cross-schema diagnostics

src/scene_core/
  root.zig
  asset.zig                AssetHeader and AssetDependency
  prefab.zig               reusable definition graph
  level.zig                streamable authored placements
  world.zig                world definition and persistent placements
  entity.zig               authored instance core and runtime core record
  hierarchy.zig            validation, evaluation order, reparent/removal policy
  serialization.zig        world/level/prefab canonical adapters
  validation.zig           cross-reference and schema validation
  assembly.zig             definition-to-runtime resolution
  runtime_scene.zig        handles, generations, dense core records, read views
```

`foundation` contains no scene ownership and can be consumed by canonical
assets, world data, or future non-scene tools. `scene_core` depends only on
`foundation`. The existing `src/scene/` remains the current H/integration area
until downstream migrations deliberately move or adapt its contents.

### B.3 World, level, and scene

Accepted terminology:

- **WorldDefinition** is an authored asset that names the world, references
  zero or more levels, declares world-persistent entity instances, and records
  deterministic/global definition metadata. It is not mutable save data and
  does not embed renderer or physics runtime objects.
- **LevelDefinition** is a streamable authored/generated spatial content asset.
  It owns placed entity instance definitions and level-local references. An
  interior, exterior region, editor preview area, or generated dungeon chunk
  can each be a level; loading multiple levels is ordinary.
- **RuntimeScene** is the resolved mutable set of active runtime entity core
  records assembled from one world, any loaded level set, persistent entities,
  temporary runtime entities, cutscene overlays, and editor-preview overlays.
  It is not authored and is not serialized as a level.
- **SceneSnapshot** is an immutable, tick-stamped read view of a RuntimeScene
  for downstream consumers. R, P, E, and C may compile their own snapshots or
  tables from it.

F2B must give every level an explicit origin in a stable world coordinate
frame; entity source transforms remain level-local `f32` metres, while
world-persistent entities use the world frame. Large-world precision beyond
that contract is reserved: any future floating-origin system must publish an
explicit derived origin-shift generation to R/P/E/C consumers and must never
rewrite canonical EntityIds, level origins, or authored local transforms.
Large-world work cannot begin until the world-origin representation, precision,
and cross-origin reference rules receive their own accepted W/F amendment.

Mutable long-lived gameplay state and save games are deliberately separate:
W owns the top-level `WorldState`/`SaveGame` envelope, level/persistent-entity
partitioning, dependency manifest, and load/save orchestration. P owns
versioned gameplay/simulation state payloads placed inside that envelope.
Other tracks own only their namespaced payloads. The future schema will refer
to stable EntityIds and asset revisions; it will not serialize runtime handles
or cached matrices. Neither W nor P may redefine F identity or canonical-data
rules while implementing it.

This model supports multiple loaded areas, interiors/exteriors, future
streaming, world-persistent entities, transient effects/gameplay entities,
cutscene-only entities, generated levels, and editor previews without making
those use cases synonyms.

### B.4 Definition, instance, and runtime state

The core separation is:

```text
PrefabDefinition asset
  reusable node graph + defaults + typed extension records

EntityInstanceDefinition
  stable EntityId + prefab AssetRef + local placement + parent ref
  + bounded explicit overrides + activation/tags

RuntimeEntityRecord
  EntityHandle + optional persistent EntityId + resolved source identity
  + local transform + derived world affine + activation + extension table keys
```

Definitions are immutable validated assets. Instances are authored/generated
placements and do not duplicate an entire prefab. Runtime records are resolved
and optimized; they may cache matrices, dense indexes, and subsystem keys, but
they never become canonical source authority.

An entity without a prefab is valid when it has explicit extension records.
A temporary runtime entity may have only an EntityHandle; it receives a
persistent EntityId only when a track explicitly promotes it to persistent or
serializable state. An accepted procedural result is source data and therefore
must receive deterministic persistent IDs before canonical serialization.

F2C owns command validation, atomic application, and lifecycle publication,
not gameplay policy. W is authoritative for create/destroy commands caused by
level load/unload or accepted world generation; P is authoritative for
gameplay spawn/despawn and persistent-state promotion requests. A and C may
submit preview/overlay requests only through their scoped hosts. Every command
declares persistent or transient intent and lifecycle owner. Conflicting
commands are rejected deterministically; no subsystem mutates RuntimeScene or
another track's compiled tables directly.

### B.5 Asset, object, prefab, and entity relationships

- An **asset** is reusable, versioned content in an asset registry. Meshes,
  materials, material instances, lights, camera definitions, prefabs, levels,
  worlds, canonical creatures, art packs, animation libraries, and
  presentation metadata are different asset kinds.
- **Object** is a non-normative editor/UI word for a selected asset, prefab
  node, authored entity instance, or runtime entity. It is not a fourth
  identity-bearing schema type, and no track may introduce an `ObjectId` as a
  competing general identity.
- A **prefab** is an asset whose content is a reusable entity-node graph.
- An **entity instance definition** is one occurrence placed in a world/level,
  optionally sourced from a prefab.
- A **runtime entity** is one active resolved occurrence addressed by a
  generation-checked handle.

Prefab reuse is composition-first. Each prefab node has a stable
definition-local `PrefabNodeId`; nested prefabs are allowed after validation.
General definition inheritance is not part of F2. Instance overrides target a
stable node/component/property path, never an array position. Nested-prefab
cycles, missing targets, duplicate overrides, type mismatches, and unsupported
override properties are errors.

For a StreetLamp, one prefab can declare a geometry-render extension, material
references, P-owned collider extension, R-owned light extension, U-owned
presentation link, and child nodes. A LevelDefinition stores only the root
instance identity, placement, prefab reference, and intentional overrides.

### B.6 Shared core and extension boundaries

F-owned entity core data is intentionally small:

- persistent identity and optional source/prefab reference;
- local transform and optional parent EntityRef;
- enabled/disabled activation;
- a sorted set of namespaced semantic TagIds;
- explicit extension records keyed by namespaced ComponentTypeId and schema
  version;
- optional F-owned links to presentation metadata and other neutral assets;
- deterministic provenance for generated content.

F owns `ExtensionRecord` framing, canonical payload boundaries, duplicate
rules, version routing, critical/optional classification, and descriptor
interfaces. Each downstream track owns its payload type, parser, validator,
normalizer, resolver, and runtime table. The host composition root supplies
descriptors to F; F never imports downstream modules. Unknown critical
extensions fail runtime loading. A may preserve unknown optional canonical
payloads losslessly, but normal runtime assembly emits a diagnostic when it
skips one. No hot subsystem parses JSON or searches UUID strings per tick.

Extension type IDs use an owner-governed lowercase namespace whose first
segment is the owning track (`w`, `r`, `p`, `e`, `u`, `c`, `a`, or `h`);
`f` is reserved for F contracts. The accepted grammar is dot-separated ASCII
segments matching `[a-z][a-z0-9_]*`, with a maximum canonical UTF-8 length of
127 bytes. The integration registry freezes before asset validation, sorts
descriptors by type ID and version, and rejects duplicate IDs, ambiguous
version routes, or registration changes after freeze, independent of caller
registration order.

An extension payload is a bounded canonical JSON value governed by the F
canonical-data rules. Its descriptor reports every direct AssetRef and
dependency class before compilation. F2B limits each entity or prefab node to
32 extension records, each canonical payload to 64 KiB, and aggregate extension
payload bytes in one F asset to 1 MiB; exceeding a limit is an explicit schema
or capacity error, and changing a limit requires a versioned contract amendment.
Authoring tools preserve an unknown optional record's canonical bytes,
version, criticality, and declared dependencies losslessly. They never
normalize it with an unavailable descriptor.

F2C uses prepare/commit/rollback descriptor operations. RuntimeScene core and
all track-owned compiled extension tables are built or mutated in private
scratch state, then published under one scene generation only after every
participant prepares successfully. A failure rolls back/deinitializes all
prepared state and leaves the previously published scene and track tables
unchanged; a track may not publish early or retain a partial side effect.

### B.7 Materials, lights, cameras, and presentation

- **Materials:** R owns general `MaterialDefinition`, `MaterialInstance`,
  parameter schema, dynamic parameters, shader compilation, and real-time or
  offline evaluation. F owns only typed `MaterialRef`/asset-kind semantics.
  This leaves room for color, metallic/roughness, normal, opacity, emission,
  transmission, subsurface, clearcoat, sheen, anisotropy, displacement,
  layering, procedures, and overrides without putting a fixed color in world
  data. Current canonical-model materials remain valid H-owned source and gain
  an R mapping rather than being replaced.
- **Lights:** an authored light is a normal entity with an F transform and an
  R-owned versioned light extension/reference. R owns directional, point,
  spot, area, environment, emissive-material behavior, lighting layers, and
  renderer-specific compiled state. F owns no lighting algorithm.
- **Cameras:** F owns the neutral camera-definition boundary because gameplay,
  A previews, U icon rendering, C shots, and both real-time/offline renderers
  consume it. Its source data is restricted to neutral projection geometry:
  projection kind, perspective focal-length/sensor or equivalent field-of-view
  representation, lens shift, orthographic extent, and geometric clip ranges
  in world units. Exposure, aperture/depth-of-field evaluation, shutter,
  motion blur, post-processing, viewport/scissor state, jitter, GPU uniforms,
  and render-target policy remain R/C-owned. P/A/C own camera selection,
  control, and animation; R compiles a selected camera plus entity transform
  and viewport into a render view. Current `Camera2D` remains the 2D runtime
  adapter.
- **Presentation metadata:** U owns `PresentationDefinition` content such as
  display name, description, icon/thumbnail references, and UI category. F
  owns only an optional typed `PresentationRef` link in asset metadata. That
  link is an optional-presentation dependency, excluded from simulation-semantic
  dependency identity. Localization, icon, thumbnail, or UI-category changes
  therefore cannot silently change semantic/runtime hashes. A workflow that
  requires exact presentation records a separate presentation-closure hash.
  R, P, and entity simulation do not import U or branch on display metadata.

### B.8 Tags, layers, activation, visibility, and volumes

- Semantic tags are F-owned namespaced IDs used for discovery and authoring.
  `TagId` uses lowercase `namespace:name` syntax; each side matches
  `[a-z][a-z0-9_]*`, total canonical length is at most 63 bytes, and one entity
  has at most 64 sorted unique tags. A tag is not a substitute for a typed
  capability or component contract; overflow, invalid syntax, and duplicates
  are validation errors.
- F owns authored enabled intent (`inherit`, `enabled`, or `disabled`) and a
  derived effective-enabled value. A root `inherit` resolves to enabled; a
  child cannot re-enable itself beneath an effectively disabled ancestor.
  Level loaded state and scoped runtime suppression are additional runtime
  inputs, not source rewrites. Enable publication is parent-before-child;
  disable publication is child-before-parent; sibling ties are EntityId order.
  All affected lifecycle transitions share the scene's atomic publication.
- Presentation visibility is distinct from enabled. F reserves a simple
  inherited/visible/hidden authored intent; R owns render visibility masks,
  culling, and lighting visibility. A and C may apply non-authoritative view
  overrides without rewriting the source entity.
- Render layers and lighting layers are R-owned typed IDs; collision layers
  are P-owned; navigation layers are W/P-owned. They may use F typed-reference
  primitives, but are not one shared integer or mask.
- Volumes/zones are normal entities with transforms. F owns only the typed
  `VolumeShapeRef` asset-kind boundary in F2B; the neutral shape payload and its
  implementation owner are explicitly deferred to a later F/W/P/R design gate.
  A referenced shape's coordinates are entity-local metres and reach world
  space through the entity's full affine; consumers must reject unsupported
  nonuniform scale or shear rather than approximate it. Trigger, water, fog,
  audio, post-process, damage, gravity, environment, and no-fly semantics are
  separate downstream extensions. A shape does not become a physics collider
  merely because P can compile one from it.

### B.9 Validation and failure policy

Validation is staged and deterministic:

1. parse the F-owned envelope strictly;
2. validate schema/version support;
3. normalize IDs, quaternions, defaults, and unordered collections;
4. validate local uniqueness and value invariants;
5. resolve asset, prefab, entity, and parent references;
6. validate graphs and extension descriptors;
7. prepare runtime core records and every downstream typed table in scratch
   state;
8. commit one scene generation only after every participant succeeds, or roll
   back all prepared core/extension state.

Duplicate persistent IDs, missing asset references, wrong asset kinds,
dangling entity references, self-parenting, cycles, nonfinite transforms,
zero scale, malformed quaternions, unsupported schema versions, invalid prefab
nesting, unresolved override paths, malformed generator metadata, duplicate
extensions, and unknown critical extension types are errors. Silent ID
regeneration, parent dropping, reference nulling, transform normalization
outside documented tolerances, or unsupported-field deletion is prohibited.
Diagnostics include schema, asset, object/property path, reference kind/ID,
and stable error code, then sort deterministically.

Runtime mutations follow the same two-phase publication boundary. A command
batch, hierarchy subtree, level unload, or extension recompile either becomes
visible everywhere under one generation or changes nothing. This is required
even when track-owned tables use different internal storage.

### B.10 Authored versus runtime performance representation

| Canonical/authored concept | Resolved runtime concept |
|---|---|
| 128-bit AssetId / EntityId serialized as canonical text | `AssetHandle` / `EntityHandle { slot, generation }` |
| AssetRef with expected kind and revision policy | resolved asset index/pointer owned by registry |
| local TRS and parent EntityRef | dense local TRS, parent handle/index, cached world affine, dirty generation |
| prefab/node/component IDs and canonical extension payload | typed track-owned dense arrays keyed by EntityHandle |
| sorted semantic TagIds | optional interned/tag-bitset query index |
| exact asset revision/content hash | resolved immutable asset object and dependency-set hash |

String/UUID lookup is restricted to loading, mutation, diagnostics, and
editor operations. Fixed-tick rendering/physics/gameplay use compact handles,
indexes, and prevalidated tables. Handle reuse increments a generation so a
stale handle cannot address a new entity.

F2C configuration records and reports initial/hard capacities for entities,
handles, loaded levels, command batches, extension-table rows, and in-flight
snapshots. Allocation or transactional bounded growth is allowed only during
initialization, explicit level load, editor transaction, or authorized spawn/
mutation command application; each growth reports category, old/new capacity,
hard limit, and cause. Capacity failure leaves the published generation
unchanged. The steady fixed-tick simulation/render extraction path allocates
nothing.

RuntimeScene has one composition-root-designated writer thread. Track workers
may prepare private tables, but only the writer validates command ownership and
commits a scene generation. A SceneSnapshot is immutable and remains valid
until its explicit bounded lease is released; newer generations may publish,
but storage referenced by an outstanding lease cannot be mutated or reused.
Exhausting configured snapshot leases is an explicit capacity error, never an
overwrite or unbounded allocation. Handle generation zero is invalid. If a
live slot at maximum generation would otherwise wrap, F2C retires that slot
permanently and reports the capacity loss; it never aliases a stale handle.

## C. Data-Flow Diagram

```text
                          AUTHORING / GENERATION

  A editors --------------------+       W procedural generators
    | production schemas        |         | seed + generator version
    v                           v         v
  asset sources ------> validate/normalize/canonicalize/hash
    | mesh/material/light/camera/presentation/canonical-H assets
    | prefab definitions
    | level definitions (placed EntityInstanceDefinitions)
    | world definition (level refs + persistent instances)
    v
  F asset registry + exact dependency/revision set
    |
    +--> PrefabDefinition --nested composition/overrides--+
    |                                                     |
    +--> WorldDefinition --> selected LevelDefinitions ---+
                                                          v
                                                F scene assembly
                                                          |
                    +-------------------------------------+------------------+
                    | persistent authored instances      | temporary runtime
                    | level instances / cutscene overlay | editor preview
                    +--------------------+----------------+------------------+
                                         v
                                 RuntimeScene core
                      EntityHandle + local/world transform + source refs
                                         |
                                         v
                                  SceneSnapshot at T
                                         |
          +----------------+-------------+-------------+----------------+
          v                v             v             v                v
     R render tables   P physics/     E effect     C deterministic   U/A read
     material/light/   gameplay       tables       evaluation +      views and
     camera views      tables                       offline render     previews
          |                |             |             |
          +----------------+-------------+-------------+
                           resolved outputs/events only
```

R/P/E/C/U/H extension definitions point inward to F identity, transform,
reference, version, serialization, and runtime-handle contracts. F contains no
back-edge to those implementations.

## D. Identity Model

### D.1 Alternatives evaluated

| Representation | Strength | Rejection/limitation for persistent world identity |
|---|---|---|
| Sequential `u32`/`u64` | Compact and fast | Requires central allocation, collides across worktrees/generated levels, and exposes load order. Keep only for runtime handles/local indexes. |
| Lowercase namespaced strings | Human-readable and close to canonical-model IDs | Renames become identity changes, collision policy is social, strings are expensive in hot paths, and decentralized authoring still needs namespace governance. Keep for definition-local semantic IDs and slugs. |
| Content hashes | Deterministic and integrity-friendly | Identity changes whenever content changes, which breaks stable entity/save/editor references. Use as revision/dependency identity, not object identity. |
| Opaque 128-bit stable IDs | Decentralized, compact, fixed-size, editor/worktree safe, binary-sortable | Needs a canonical text format and explicit random/deterministic generation policies. **Accepted.** |

### D.2 Accepted persistent and runtime identities

- `AssetId` and `EntityId` are distinct strong types over 128 bits. Sharing a
  binary shape does not permit cross-type comparison.
- Canonical JSON uses lowercase RFC 9562 UUID text (`8-4-4-4-12`, 36 bytes).
  The 16-byte representation is RFC canonical/network order: the first two
  hex digits encode byte zero, and ordering never passes through host-endian
  integer fields. Parsing rejects noncanonical case, missing hyphens, malformed
  variants/versions where a version is required, and the all-zero value.
  Display slugs/names are separate.
- Interactive/imported authoring uses RFC 9562 UUIDv7 with explicit caller-
  supplied Unix-millisecond clock and 74 bits of entropy. The API validates the
  timestamp range and never reads an ambient clock or entropy source.
  Deterministically generated authored entities use RFC 9562 UUIDv5 from a
  registered namespace plus canonical length-delimited name fields; ambiguous
  concatenation is forbidden.
- Namespace registration records stable namespace UUID, owner track, purpose,
  and derivation-domain version. Registration is normalized and sorted before
  use; duplicate UUIDs, duplicate owner/purpose keys, or an output ID already
  present in the target definition/assembly are hard errors.
- Equality is exact 16-byte equality. Canonical ordering is unsigned
  lexicographic byte order. Hashing uses the bytes, not source spelling.
- Null is represented by an optional field/JSON `null`; no valid ID doubles as
  null. Runtime invalid-handle sentinels remain nonserialized implementation
  details.

An AssetId lives for the logical asset across compatible revisions. An
AssetRevision records semantic version and canonical content hash. Exact
accepted builds resolve every AssetRef to `{AssetId, AssetRevision,
content_hash}`. A floating authoring preference such as “latest compatible”
may exist in A tooling, but canonical world/level/prefab inputs used for
deterministic builds must resolve and record an exact dependency set.

An EntityId lives for a serialized placed/persistent entity across save/load,
editor edits, and compatible level revisions. Deleting and recreating an
entity does not reuse its ID. Duplicates within an assembled world are fatal.
EntityRef is a typed persistent reference plus explicit required/optional
semantics; required dangling references fail assembly.

Existing H-owned semantic string IDs remain byte-for-byte and name-for-name
unchanged. A future H registration adapter owns an explicit typed mapping
`{H asset kind, H semantic string ID} -> AssetId` plus exact source hash. There
is no implicit string parsing, UUID hashing, renaming, or fallback conversion
inside F; missing or duplicate mappings fail at the adapter boundary.

`EntityHandle { slot: u32, generation: u32 }` identifies a live RuntimeScene
slot. It is never serialized, compared with EntityId, or retained across scene
teardown. The runtime registry maps persistent EntityId to handle at load/mutation
boundaries. A generation increments before slot reuse; stale handles fail.

### D.3 Prefab and procedural identities

PrefabNodeId remains a stable lowercase definition-local semantic ID because
it is scoped by the prefab AssetId and used for readable override paths.
Instantiated child EntityIds derive deterministically from the root EntityId
and the canonical nested prefab-node path. Reordering arrays does not change
the path; renaming a published node is an identity migration and must provide
an explicit alias/migration.

Procedural provenance records the root Seed, generator AssetId/version,
algorithm ID/version, stable generation key, and exact dependency set. A
generated entity's UUIDv5 name input is the canonical generator namespace plus
stable key, not its array index or traversal timing.

### D.4 Exact asset references and dependency identity

`AssetRevision` is the logical AssetId plus strong asset semantic version and
canonical SHA-256 content hash. `AssetRef` adds the expected AssetKind and the
exact revision. A kind, version, hash, or logical ID mismatch is an error; a
canonical runtime/build input never resolves “latest” implicitly.

Every direct dependency record has exactly one class:

- `semantic_runtime_required`: required to validate or execute semantic
  behavior and included in simulation-semantic identity;
- `optional_presentation`: optional U/R-facing content excluded from semantic
  identity but included in a separately requestable presentation closure;
- `tooling_only`: required only by import/build/editor tooling and excluded
  from runtime and presentation identity.

Direct dependencies are records declared by one asset. A transitive closure is
resolved by following only the requested class domain through exact revisions.
Records sort by class, AssetKind, AssetId bytes, semantic version, and content
hash. Duplicate direct AssetIds are rejected even when textually identical;
conflicting revisions are not “last writer wins.” Cycles in any requested
closure are rejected with the complete deterministic cycle path rather than
cut, ignored, or hashed recursively.

Hash framing is length-delimited and versioned with distinct domains:
`foundation.dependency.direct.v1`,
`foundation.dependency.semantic_runtime_closure.v1`,
`foundation.dependency.presentation_closure.v1`, and
`foundation.dependency.tooling_closure.v1`. Only the semantic/runtime closure
participates in simulation-semantic identity. Domain or framing changes require
a new domain version and cannot reinterpret an existing hash.

## E. Transform/Hierarchy Model

### E.1 Coordinate and transform semantics

The accepted scene transform is renderer-independent 3D and matches the
accepted canonical-model contract:

- right-handed; `+X` right, `+Y` up, `+Z` forward (`+X × +Y = +Z`; the
  canonical human reference view historically describes this same axis as
  toward the camera);
- metres, `f32`, radians;
- local parent-relative translation, quaternion `[x,y,z,w]`, and XYZ scale;
- local point order is scale, rotate, translate;
- `world_affine = parent_world_affine * local_affine`;
- global affine is derived and may contain shear; decomposed global TRS is not
  canonical authority.

Vectors are columns. Local application is `T * R * S * point`, and hierarchy
composition means `world_point = parent(local(point))`; multiplication is not
interpreted in reverse. `AffineTransform.x_axis`, `y_axis`, and `z_axis` are
the three linear-matrix basis columns, with translation as the affine fourth
column. Quaternion storage is `[x,y,z,w]`. Canonicalization chooses positive
`w`; when `w == 0`, it chooses the sign whose first nonzero `x`, then `y`, then
`z` component is positive, and normalizes signed zero.

Quaternion finite/unit/hemisphere and `-0.0` normalization rules match
`canonical_model.math3d`. Scene scale must be finite and nonzero on every axis;
negative scale is valid because current facing reflection requires it. Current
2D systems adapt by using `z = 0`, Z-axis rotation, and an appropriate Z scale;
F2 does not replace `Transform2D` or `Camera2D`.

F2A begins with independent F spatial types plus test-only conformance bridges
to both `canonical_model.math3d` and current `Transform2D`; production F never
imports H or current scene/runtime modules. Moving or re-exporting canonical
spatial code requires a separate behavior-preserving extraction proposal, H
compatibility approval, and passing protected API, byte, hash, and behavior
regressions. Passing conformance tests alone does not authorize extraction.

The accepted F spatial tolerances are public named constants and boundary-
tested fixtures:

| Rule | Accepted tolerance |
|---|---|
| Quaternion unit validation | `abs(length_squared - 1) <= 1e-5` before canonical normalization |
| Minimum scale for inversion/decomposition | `abs(scale_axis) >= 1e-6`; authored nonzero values below this may exist but `keep_world` must fail |
| Normalized-basis orthogonality/shear test | absolute dot product `<= 1e-5` |
| Affine recompose comparison | per element `abs(a - b) <= 1e-5 + 1e-5 * max(abs(a), abs(b))` |
| Inverse singularity test | `abs(det) > 1e-8 * (length(x_axis) * length(y_axis) * length(z_axis))` |

All values must first be finite. Equality/hashing of canonical values is not
defined by these tolerances; tolerances govern validation and representability
only. Values on an accepted boundary pass, values beyond it fail, and no caller
may silently widen a tolerance.

Affine inversion operates on the complete affine linear part and translation,
preserves shear/reflection, and returns a typed singular/nonfinite error rather
than an identity or partial inverse. Affine-to-local-TRS conversion succeeds
only when extracted signed scales and an orthonormal quaternion recompose every
matrix element within the published tolerance. Shear beyond the orthogonality
or recompose limits returns `not_representable`; negative determinant uses one
documented canonical signed-scale assignment compatible with the current
negative-X 2D reflection. The decomposed representation preserves the affine
transformation but does not promise to restore the exact authored signs of all
three scale components; a reflected transform always receives the canonical
negative X scale plus an adjusted rotation. It never returns a closest or
approximate TRS.

### E.2 Serialized hierarchy

Each EntityInstanceDefinition serializes one local transform and an optional
parent EntityRef. Root entities have `parent = null`. Child lists and world
transforms are derived, never duplicated in source. Parent references normally
remain within a level or target a declared world-persistent entity/anchor.
Arbitrary level-to-level parenting is rejected because unloading either level
would make hierarchy semantics order-dependent.

Validation requires:

- unique EntityIds before graph traversal;
- every required parent to resolve and no self-parent;
- no cycles;
- finite canonical local TRS and nonzero scale;
- one deterministic parent-before-child evaluation order, with sibling ties
  sorted by EntityId rather than input/load order;
- bounded nesting (accepted default 64 for entity hierarchy and 32 for
  nested prefabs), reported as an explicit capacity error.

### E.3 Runtime propagation and mutation

RuntimeScene stores local TRS, parent handle/index, derived child adjacency,
world affine, local revision, and evaluated ancestor revision. A local or
parent change marks that node/subtree dirty. Evaluation follows the validated
parent-before-child order and rebuilds only dirty affines. Downstream snapshots
observe one committed hierarchy generation; no consumer sees half a reparent.

Parent assignment is transactional and takes an explicit mode:

- `keep_local`: local TRS is unchanged and world placement changes;
- `keep_world`: compute the new local affine from the prior world affine and
  new parent inverse, failing if inversion or canonical local representation is
  impossible under the E.1 public tolerances. It never silently drops shear
  into an approximate TRS.

Removal requires an explicit policy. The accepted default is
`reject_if_children`. Authorized alternatives are `cascade` or
`orphan_keep_world`; the latter must succeed transactionally for every child or
change nothing. Level unload uses predeclared ownership and cannot invoke an
implicit orphan policy.

Hierarchy edits preflight the entire affected subtree, order parents before
children with EntityId sibling ties for evaluation, and publish one generation
only after every transform and downstream participant prepares successfully.
Cascade destruction commits children before parents in reverse deterministic
order. `orphan_keep_world` computes and validates every child local transform
before changing any parent link; one inversion/representability failure rolls
back the whole subtree.

Level unload destroys all level-owned entities and transient descendants whose
lifecycle owner is that level, children before parents and with EntityId ties.
World-persistent entities survive and therefore may not be parented beneath a
level-owned entity; level entities may be parented to declared world-persistent
anchors. Required external references, compiled extension teardown, and handle
invalidation are preflight together. Any failure leaves the level, handles,
RuntimeScene, and track-owned tables published exactly as before the request.

Entity hierarchy is not skeleton/rigging. Skeleton, anatomy, appearance, and
prefab definition graphs retain their own typed node identities and
lifecycles. They may share affine math and validation utilities, but a bone or
prefab node does not become a runtime world entity unless an explicit adapter
creates one.

## F. Serialization/Versioning Model

### F.1 One canonical-data contract

F uses the repository's existing canonical JSON rules:

- UTF-8 JSON with `snake_case` field names;
- strict F-owned fields and explicit extension payload boundaries;
- finite numbers only and shortest decimal that round-trips to identical
  `f32` where a field is `f32`;
- normalized `-0.0`, canonical quaternion identity, resolved defaults;
- deterministic field order;
- unordered record collections sorted by stable typed ID;
- semantic arrays preserve declared order;
- no insignificant whitespace and no trailing newline in canonical bytes;
- SHA-256 stage/domain hashes that exclude file path, timestamp, and source
  formatting.

F2A is facade/conformance-first. It introduces governed neutral leaf
primitives and test-only conformance adapters while the existing canonical
model and canonical geometry parsers/normalizers/serializers remain unchanged
production consumers. The new facade must prove byte-for-byte output and
protected hash equality for their fixtures, plus public API/behavior
conformance where responsibilities overlap. A shared-leaf extraction is a
separate change requiring a written behavior-preservation case, H compatibility
approval, and passing byte/hash/API/behavior regressions before either protected
pipeline adopts it. Failure to prove safe extraction retains the facade and
conformance bridge; it never permits a risky migration. F does not embed world
data inside `CanonicalCreatureDefinition`, and it does not invent YAML, a
second JSON dialect, or a generic unvalidated property bag.

### F.2 Schema envelope and versions

Every authored asset has:

```text
schema_identity  = schema ID + schema semantic version
asset_identity   = AssetId + asset semantic version + optional slug/display data
producer_identity = compiler/generator/tool ID + semantic version
dependencies     = exact AssetId/revision/content-hash records
provenance       = optional deterministic-generation record
payload          = schema-specific validated definition
```

Schema, asset, producer/generator, and runtime engine versions are distinct
strong types. Major schema mismatch is unsupported. A newer minor version is
accepted only when the registered parser explicitly declares compatibility;
unknown fields are not assumed safe. Patch versions may change validation or
producer behavior only when canonical semantic meaning remains compatible.

### F.3 Load, migration, and save boundaries

The runtime consumes only normalized validated current-schema definitions.
Migration is a deterministic explicit chain (`v1 -> v2 -> v3`) registered per
schema. A migration preserves stable IDs where possible, reports every
non-exact translation, never discards unsupported data silently, and produces a
new candidate while preserving the old source. Ordinary runtime/test commands
do not rewrite source or repair goldens.

Authoring JSON may contain whitespace and omit defined defaults. Canonical
bytes materialize defaults and stable order for hashing. Round trip means
`authoring -> normalized -> canonical -> parse -> normalized` preserves
canonical bytes, identity, and references; it does not promise to preserve
source whitespace.

Save-game/runtime state is a future separate schema. It may contain stable
EntityIds and track-owned state payloads but never EntityHandles, raw pointers,
GPU indexes, cached world matrices, or mutable editor selections.

### F.4 Interaction with canonical model and geometry

The canonical human/model and geometry pipelines remain independent assets
with their existing schema IDs, versions, typed internal IDs, byte identities,
hashes, validation, and Blender bridge. F may register their outputs by AssetId
and exact hash through the explicit H mapping boundary in D.2. F2A does not
rewire either pipeline. Any future shared utility extraction must be behavior-
preserving, H-approved, and separately authorized after protected byte, hash,
API, and behavior regressions pass. F1/F2 do not rename human IDs, rewrite JSON,
move topology, regenerate evidence, or make runtime scene state part of
canonical human authority.

## G. Determinism Model

### G.1 F guarantees

For identical canonical definitions and registered descriptors, F guarantees:

- byte-identical normalized canonical JSON and domain hashes;
- deterministic diagnostic ordering;
- stable AssetId/EntityId equality and ordering;
- deterministic prefab expansion and derived child IDs;
- deterministic reference-resolution and hierarchy traversal order independent
  of input array, hash-map, load, or worktree merge order;
- deterministic local-to-world affine evaluation for a fixed target/toolchain;
- explicit scene time and seed inputs with no ambient clock/random source;
- a recorded exact asset dependency set and producer/generator identity;
- transactionality: invalid assembly/mutation does not expose partial state,
  and RuntimeScene plus every track-owned compiled table publish under one
  generation or all roll back.

`SceneTime` is represented as an integer simulation tick plus an optional
rational sub-tick numerator/denominator for sampling. Its exact value is
`tick + numerator / denominator`; the fraction is reduced, nonnegative, and
less than one, so `tick = -1` plus `1/2` represents `-0.5` ticks. Whole ticks
use no sub-tick rather than an arbitrary `0/N`. `SceneTime` defines no seconds-
per-tick rate, and canonical evaluation does not use wall-clock time. The
current 240 Hz simulation remains P-owned. A
cinematic may declare another rational evaluation rate, but must convert
explicitly and record it.

`Seed128` is canonical data. Child streams/keys derive from a domain-separated
SHA-256 of the root seed, generator identity/version, algorithm ID/version, and
stable semantic key. F specifies derivation and metadata; W/E/P own the exact
versioned generator/PRNG algorithms and results. Using Zig's unspecified
default PRNG without a recorded algorithm/version is prohibited for accepted
generated content.

### G.2 Downstream obligations and limits

| Track | Required deterministic claim |
|---|---|
| W | Same generator version, seed, stable keys, F schema, and exact dependencies reproduce identical canonical generated definitions or emit an explicit incompatibility. |
| R | Stable extraction/order from a SceneSnapshot. Pixel/driver bit identity is a separately scoped GPU claim, not implied by F. |
| P | Fixed-tick ordering and replay inputs are explicit. Cross-platform bit-identical physics is not required unless P separately promises it. |
| E | Random streams are named/versioned and independent of submission order; visual GPU particles may declare weaker guarantees than canonical authored effects. |
| U/A | Editing and presentation metadata do not mutate stable IDs implicitly; canonical output does not depend on UI order. |
| C | `evaluate scene at T` records SceneTime, exact assets, camera, generator/effect versions, and any simulation snapshot dependency. Offline pixels have a separately stated reproducibility tier. |
| H | Existing canonical hashes and deterministic geometry/evidence contracts remain authoritative in their documented scope. |

F does not promise cross-architecture floating-point bit identity for live
simulation, third-party GPU driver identity, bit-identical unrestricted
physics, or reproducibility from a changed generator/asset dependency set.
Those limits are explicit metadata, never silent fallback.

## H. Ownership Matrix

| Track | Owns | F contracts consumed | May depend on / depended on by | May extend | May NOT silently redefine |
|---|---|---|---|---|---|
| **F — Shared Foundation** | `src/foundation/`, `src/scene_core/`; identity, versions, refs, core transform/hierarchy, asset envelope, world/level/prefab/entity core schemas, canonical-data rules, deterministic metadata, extension framing, assembly, RuntimeScene core | N/A | Depends only on std and explicitly approved low-level utilities. All W/R/P/E/U/C/A/H depend inward on F. | New F contracts only through F prompts or owner-approved amendments | Any specialized rendering, material behavior, lighting, physics, gameplay, effects, UI, cinematics, editor workflow, or human schema |
| **W — World / Levels / Procedural Generation** | World content conventions, level streaming policy, terrain/spatial generation, generator implementations, navigation-world authoring, top-level SaveGame/WorldState envelope and world persistence orchestration | AssetId/Ref, EntityId/Ref, Transform, World/Level/Prefab schemas, seed/provenance, extension descriptors | May depend on F and P/R data contracts through adapters, never implementations. R/P/E/C consume W definitions/views. | W-owned level/world extension payloads, generator schemas, and save partition records | F identity, `RuntimeScene`, canonical JSON rules, P gameplay-state payloads/collision layers, R render/light/material definitions |
| **R — Rendering / Materials / Lighting** | Existing `src/graphics/`, shaders/art packs/render queue/GPU resources; general material/light definitions and instances; render extraction, render/lighting layers, culling; real-time renderer | AssetRef, EntityHandle, Transform/Affine, SceneSnapshot, CameraDefinition, extension framing | Depends on F; may consume W/H/E outputs. U/C may consume R services; no F back-edge. | R-owned mesh-render, material, light, environment-render extension schemas | F entities/transforms/asset refs; P collision; U presentation metadata; H canonical semantic identity |
| **P — Physics / Gameplay Foundation** | Existing `src/physics/`, `src/interaction/`, controller/gameplay state; collider/trigger definitions and compiled worlds; collision layers; versioned gameplay-state save payloads; gameplay spawn/despawn authority | EntityId/Handle, Transform, SceneSnapshot, level/prefab extension framing, time/seed metadata | Depends on F and selected W/H definitions. W/E/C/gameplay depend on P views/events. | P-owned rigid/static collider, trigger, gameplay, property, interaction-anchor and save-state extensions | F hierarchy/identity; R render visibility/layers; W top-level save/level identity and load/unload authority; H skeleton/anatomy authority |
| **E — Effects / Environment / Particles** | Effect definitions/runtime, particle systems, fog/weather/environment effect payloads, versioned random-stream use | Entity handles/transforms, asset refs, scene time/seed, volume boundary, extension framing | Depends on F and may consume W/R/P views. R/C/U consume E outputs. | E-owned effect/emitter/fog/water-environment extensions | F seed derivation/time, R material/light ownership, P collision/damage authority, W level ownership |
| **U — UI / Presentation / Icons** | `PresentationDefinition`, display/description/category schemas, icon/thumbnail recipes and UI runtime | AssetId/Ref, PresentationRef link, camera asset, scene read views where authorized | Depends on F and R services; reads W/P/H metadata via public views. No runtime system depends on U for gameplay truth. | U-owned presentation/icon extensions and assets | F AssetHeader/IDs, R material/render state, P gameplay identity, H anatomy/equipment identity |
| **C — Cinematics / Offline Rendering** | Shot/timeline definitions, camera selection/animation, deterministic scene-evaluation requests, offline render orchestration | Entity/Asset refs, Transform, CameraDefinition, SceneTime, SceneSnapshot, exact dependency set | Depends on F plus public R/P/E/W/H views. Nothing in F depends on C. | C-owned shot, timeline, binding, offline-render settings extensions | F time/identity/scene assembly, R material/light definitions, P simulation state, H canonical assets |
| **A — Editors / Authoring** | Editor UI, commands, undo/redo, preview orchestration, import/export tools | All F production schemas/validators/migrators plus track-owned descriptors | Depends on F and whichever track it edits. Runtime tracks never depend on editor models. | Editor-only view state and commands; never exported as production truth | A parallel asset/entity/transform/collider/material/light/identity schema; silent source repair |
| **H — Human / Character Pipeline** | Existing `src/canonical_model/`, `src/canonical_geometry/`, canonical human assets/evidence; current character/anatomy/appearance/equipment/animation/presentation modules until explicit migration | F asset registration/ref, transform conformance, EntityHandle adapter, extension framing | Depends on F only through approved adapters; R/P/U/C consume public H definitions/views. | H-owned character/canonical asset extensions and compiled runtime tables | F entity/world identity, R material implementation, P world physics, U general presentation metadata |

Primary circular-dependency hazards are F importing a track payload; R reading P
objects instead of SceneSnapshot/adapter data; W making collision or render
types its source schema; P importing H presentation or R draw data; U becoming
required for asset/gameplay identity; C mutating the live scene through an
offline renderer; and A exporting an editor-only schema. Extension descriptors,
typed read views, and composition-root wiring are the required breaks.

## I. Parallel Worktree Integration Policy

### I.1 Repository-specific ownership

| Owner | Primary paths |
|---|---|
| F | `src/foundation/**`, `src/scene_core/**`, `tests/foundation/**`, this record, F-specific implementation records |
| W | `src/world/**`, `src/levels/**`, `src/procedural/**`, `tests/world/**` |
| R | `src/graphics/**`, `assets/shaders/**`, future `src/rendering/**`, `tests/rendering/**` |
| P | `src/physics/**`, `src/interaction/**`, future `src/gameplay/**`, `tests/physics/**`, `tests/gameplay/**` |
| E | future `src/effects/**`, `src/environment_effects/**`, `tests/effects/**` |
| U | future `src/ui/**`, `src/presentation/**`, `assets/ui/**`, `tests/ui/**` |
| C | future `src/cinematics/**`, `src/offline_render/**`, `tests/cinematics/**` |
| A | future `src/editor/**`, `tools/authoring/**`, editor tests/fixtures |
| H | `src/canonical_model/**`, `src/canonical_geometry/**`, `assets/canonical_model/**`, H-owned files under `src/scene/**` and `src/animation/**`, canonical/human tests and evidence |

The following are integration-controlled high-contention files and are not a
track's casual edit surface: `build.zig`, `src/main.zig`,
`src/graphics/gpu_demo.zig`, `src/scene/visual_foundation.zig`,
`tests/test_all.zig`, `docs/ARCHITECTURE.md`, `docs/TESTING.md`, and
`docs/project/**`. A track branch supplies a small documented wiring patch;
the integration gate applies/merges those patches serially after track tests.

Existing mixed-boundary files keep their current owner until an explicit
migration prompt. In particular, W does not seize `environment_theme.zig`, R
does not seize canonical materials, P does not seize `CharacterInstance`, and
F does not seize the current demo `Scene` roots merely because the future
architecture names adjacent concepts.

### I.2 Contract-change and merge procedure

1. The owner approves this F1 record and a known integration commit.
2. Every parallel worktree begins from that exact commit and records it in its
   implementation report.
3. F-owned contracts change only in an F prompt or an explicit owner-approved
   amendment. A downstream branch that needs a missing contract stops at an
   adapter boundary and files a concrete request: use case, smallest new F
   surface, invariants, tests, and migration impact.
4. Tracks consume public `root.zig` APIs or documented adapter/read-view APIs;
   they do not import F private files or another track's internal file.
5. Each branch confines implementation and focused tests to its owned paths.
   Cross-track file edits are isolated as separate commits/patches for the
   integration gate.
6. The integration gate reviews API/ownership changes, applies central build
   wiring, runs focused tests, then `test` and `check`; acceptance waves run
   `test-full`, `test-stress`, or `verify` according to `docs/TESTING.md`.
7. Merge order is F contracts first, downstream producers second, consumers
   third, composition/integration last. Branches rebase/merge from the approved
   integration result before the next wave.
8. No branch weakens tests, changes canonical hashes, regenerates protected
   evidence, or resolves conflicts by deleting another track's behavior.
9. Adapters are classified as permanent or transitional. Transitional
   adapters record owner, call sites, exit evidence, and retirement milestone
   under the repository's M02-M08 retirement rule.

### I.3 Build-graph concurrency

The current monolithic `build.zig` is a merge hotspot. F2 should add one
`foundation` module and namespaced test roots without reorganizing unrelated
existing build logic. Subsequent parallel tracks should own a track-local
module/test registration helper once they have real content; the integration
coordinator alone adds the stable top-level call. Until that helper boundary
exists, build wiring remains a separate integration patch, never a reason for
two worktrees to edit `build.zig` concurrently.

## J. Migration Assessment

| Existing area | Required adaptation | Owner / phase | Migration classification and concern |
|---|---|---|---|
| Canonical JSON utilities | Add facade/conformance leaf primitives while preserving exact current bytes and leaving protected pipelines unchanged | F2A; any later extraction requires H approval | Compatibility-sensitive. No source/evidence rewrite; adoption by existing schemas remains deferred unless a separately authorized extraction passes byte/hash/API/behavior regressions. |
| `canonical_model.math3d` and F spatial math | Add the required test-only conformance bridge; consider shared-leaf extraction only later | F2A bridge; H approves any extraction | Protected behavior. Never make F import the H root module, and never use conformance as implicit extraction authorization. |
| Current `character.EntityId` | Add bidirectional runtime adapter between current nonzero `u32` identity and F EntityHandle/EntityId mapping | F2C adapter; eventual H/P migration | Transitional. Do not mass-change interaction/character tests in F2. |
| Demo `Scene` composition roots | Optionally expose a read-only SceneSnapshot adapter for mock/current integration proof | F2C only if bounded; later integration owns production adoption | Current names remain. No production route switch in F2 unless separately authorized. |
| `CollisionWorld` and Zig-authored collider arrays | P compiler later resolves P collider extensions from F/W definitions into current immutable array | Later P/W | Current collision remains authority until adapter parity tests pass. No collider-as-world shortcut. |
| Environment definitions | Separate W spatial placement/level concerns from R art/theme submission through extension adapters | Later W/R | Mixed current module; preserve surface derivation and current collision fingerprints. |
| `art_pack` IDs/runtime indices | Register art-pack asset by F AssetId; keep page/region IDs local and runtime page index nonserialized | Later R | Low-risk wrapper if hashes/lookup behavior remain unchanged. |
| `deformable_mesh.MaterialReference` | Map F MaterialRef -> R material instance -> current texture/tint compatibility record | Later R/H | Transitional and potentially lossy for advanced materials; must be labeled compatibility. |
| Canonical model materials | R provides compiled general-material mapping while H schema remains source authority | Later R/H | Do not rename IDs or move records in F2. |
| `Camera2D` | Compile F CameraDefinition + entity transform + viewport into current `Camera2D`; P/A/C own controllers/selections | Later R/P/A/C | Preserve accepted height-relative viewport behavior and camera tests. |
| Numeric render layers in `character.zig` | Move ownership to R or add R aliases after current queue/evidence parity | Later R/H | High evidence risk; not F2. |
| Interactions/world anchors | P authored interaction extensions use F EntityRefs/anchor assets, then map live participants to EntityHandles | Later P/H/W | Current handshake definition remains unchanged. |
| Presentation metadata | Add U asset schema targeted by F PresentationRef | Later U | Current `presentation_view` and interaction presentation keep their names/roles. |
| Volumes/zones | Add only the F-owned typed VolumeShapeRef boundary; defer neutral shape payload ownership to a later F/W/P/R gate | F2B reserves; downstream implements | Shape coordinates are entity-local metres; no general shape or volume behavior in F2. |
| Save games | W owns the top-level stable-ID envelope/partitioning and P owns versioned gameplay-state payloads | Later W/P | Runtime handles/caches forbidden; neither track redefines F identity/canonical rules. |
| Build and test structure | Add F modules/focused roots and central wiring; leave unrelated module graph intact | F2A-C/integration | `build.zig` conflicts must be serialized. |

No existing production type requires replacement in F2A. F2B introduces new
authored schemas beside current code. F2C proves resolution and adapters with
mock consumers; broad current-runtime conversion belongs to later track work
after owner approval.

## K. F2 Implementation Plan

### K.0 Corrected milestone gates

F1 approval establishes architectural authority only. Each milestone still
requires its own dedicated implementation request and stops for owner review.

| Milestone | Accepted decision/API prerequisites | Does not wait for |
|---|---|---|
| **F2A** | L2-L6 | L1 or L7-L15; no scene schema/runtime decision is needed for primitives |
| **F2B** | L1 and L7-L13, plus owner-accepted F2A APIs | Runtime portions of L7/L9 or L14-L15 |
| **F2C** | Runtime portions of L7 and L9, L14-L15, plus owner-accepted F2B schemas | Production adoption by W/R/P/E/U/C/A/H |

### K.1 F2A — Foundation primitives and canonical-data substrate

**Scope**

- Implement the approved low-level F module surface: strong 128-bit identities,
  versions, typed AssetRef/EntityRef, runtime handle shapes, namespaced local
  IDs, deterministic diagnostics, spatial TRS/affine semantics, seed/time
  primitives, and canonical-data utilities/facade.
- Implement facade/conformance bridges for `canonical_model.math3d`, current
  `Transform2D`, and protected canonical serializers without changing their
  production APIs or protected canonical bytes. Shared-code extraction is not
  part of F2A unless separately proposed and H-approved.
- Add only the `foundation` build module and focused tests.

**Dependencies**

- Owner approval of L2-L6.
- Existing Zig 0.16.0 math/canonical tests and frozen canonical fixture hashes.
- No dependency on W/R/P/E/U/C/A/H runtime implementations.

**Expected code/document changes**

- `src/foundation/root.zig` and the F2A files listed in B.2 that contain real
  behavior.
- `tests/foundation/identity_tests.zig`, `spatial_tests.zig`,
  `canonical_data_tests.zig`, `determinism_tests.zig`, and
  `test_foundation_primitives.zig` as the focused test root.
- Minimal `build.zig` wiring, `docs/TESTING.md` focused command, and an F2A
  implementation record.
- Test-only conformance adapters; no production canonical re-export, rewiring,
  source, asset, or evidence change.

**Required tests**

- canonical RFC 9562 ID parse/format/null/equality/byte order, namespace
  registration/duplicate failure, UUIDv5 vectors, and injected-input UUIDv7;
- AssetId/EntityId/H semantic-string separation, distinct version types,
  AssetKind/revision/hash mismatch, direct/transitive dependency classes,
  duplicate/cycle rejection, and versioned closure hashes;
- EntityHandle value equality, invalid representation, type separation, and
  proof that it is not serializable; no slot registry/reuse lifecycle test;
- quaternion sign/zero/finite/unit rules, local TRS order, affine hierarchy,
  nonuniform-scale shear, negative-scale compatibility, inverse failure,
  affine-to-TRS representability/tolerance boundaries, and 2D conformance;
- seed derivation and SceneTime validation;
- canonical number/string/order/hash/diagnostic determinism;
- byte-for-byte existing canonical-model and canonical-geometry regression,
  including newline-free canonical output.

**Completion criteria**

- F primitives import no downstream track.
- Focused tests, `zig build test -j1`, `zig build check -j1`, and final-boundary
  `zig build test-full -j1` pass.
- Protected canonical bytes/hashes are unchanged and no authoring/evidence file
  is rewritten.
- Public APIs, tolerances, dependency classes/hash domains, capacity choices,
  and facade/conformance bridges are owner-reviewable.
- Stop; do not begin F2B automatically.

### K.2 F2B — Authored asset, prefab, level, and world schemas

**Scope**

- Implement `AssetHeader`, dependencies/provenance, `PrefabDefinition`,
  `LevelDefinition`, `WorldDefinition`, `EntityInstanceDefinition`, core camera
  definition, tags/activation/visibility intent, extension records, and the
  transform/hierarchy/reference validation contract.
- Implement strict authoring parse, normalization, deterministic canonical
  serialization/hash, version rejection, and explicit migration interfaces for
  these F schemas.
- Provide synthetic fixtures only; do not convert production characters,
  environments, physics, materials, lights, or cameras.

**Dependencies**

- Owner-accepted F2A APIs and owner approval of L1 and L7-L13.
- No renderer, physics, editor, or canonical-human implementation dependency.

**Expected code/document changes**

- `src/scene_core/asset.zig`, `prefab.zig`, `level.zig`, `world.zig`,
  `entity.zig`, `hierarchy.zig`, `serialization.zig`, `validation.zig`.
- `tests/foundation/schema_tests.zig` plus valid/invalid synthetic JSON fixtures.
- Focused build target and F2B implementation record.

**Required tests**

- authoring/canonical round trip and canonical byte determinism under reordered
  fields/record collections and explicit/omitted defaults;
- schema major/minor/patch support and unsupported-version failure;
- ID stability across load/save/migration; duplicate and wrong-kind IDs;
- required/optional asset and entity reference resolution;
- local transform validation, parent/child correctness, cycle/self/missing
  parent rejection, deterministic sibling/evaluation order;
- definition/instance separation and no prefab data duplication;
- nested prefab expansion metadata, cycle/depth rejection, valid/invalid
  override paths, and stable derived child ID fixtures;
- multiple levels, world-persistent references, forbidden arbitrary cross-level
  parents, explicit level origins/floating-origin reservation, and
  editor-preview/cutscene classification;
- deterministic seed/generator/dependency metadata and malformed provenance;
- extension namespace/descriptor-registration determinism, canonical payload
  limits/dependencies, and unknown critical versus preserved optional behavior;
- restricted neutral camera fields, presentation dependency classification,
  TagId syntax/capacity, authored/effective activation and lifecycle ordering,
  visibility, and typed-only VolumeShapeRef boundary.

**Completion criteria**

- Every F-authored definition validates before consumption and emits stable
  diagnostics.
- No production runtime path consumes the new schemas yet.
- The format has an owner-reviewed version/migration statement and canonical
  goldens.
- Focused tests, `test`, and `check` pass; `test-full` runs because serialization
  touches shared canonical infrastructure if F2A adopted it.
- Stop; do not begin F2C automatically.

### K.3 F2C — Runtime scene assembly, handles, hierarchy, and mock consumers

**Scope**

- Implement transactional assembly from validated world/level/prefab/entity
  definitions into `RuntimeScene` core records.
- Implement dense generation-checked handles, persistent-ID lookup at mutation
  boundaries, prefab instantiation, loaded-level ownership, persistent and
  transient entities, derived world-affine caching, explicit reparent/removal
  modes, snapshots, and extension descriptor routing.
- Implement single-writer validated create/destroy command application and
  two-phase prepare/commit/rollback across RuntimeScene core plus every
  track-owned compiled extension table.
- Prove downstream compatibility through mock R/P/C consumers and at most a
  read-only adapter to current demo state. Do not switch production rendering,
  physics, character, or environment ownership.

**Dependencies**

- Owner-accepted F2B schemas, the runtime portions of L7 and L9, and owner
  approval of L14-L15.
- Current fixed-step and allocation rules inform tests but are not imported as
  ownership dependencies.

**Expected code/document changes**

- `src/scene_core/assembly.zig`, `runtime_scene.zig`, runtime portions of
  `hierarchy.zig`, and focused runtime fixtures/tests.
- Track-neutral mock descriptor modules under tests, not production R/P/C
  implementations.
- Optional bounded compatibility adapter in a new F-owned adapter file; no
  edits to current H topology or canonical assets.
- Focused build target, architecture map update, and F2C implementation record.

**Required tests**

- stable resolution from definitions to instances to runtime records;
- persistent ID -> handle lookup, slot reuse, generation increment,
  stale/dangling handle rejection, zero-generation invalidity, generation-wrap
  slot retirement, transient entity semantics, and teardown invalidation;
- load/unload of multiple levels while world-persistent entities survive,
  including exact child-before-parent ordering and atomic unload rollback;
- prefab/nested child identity and reference resolution;
- parent/child affine correctness, dirty propagation, deterministic traversal,
  cycle rejection on mutation, `keep_local`/`keep_world` behavior, and all
  removal policies including transactional failure;
- invalid asset/entity/extension refs and any downstream prepare failure leave
  the prior RuntimeScene and every track table unchanged;
- SceneSnapshot is immutable/tick-stamped, stable under insertion-order
  permutations, and valid for its documented bounded reader lease;
- deterministic seed/time/dependency context reaches mock consumers unchanged;
- mock renderer, physics, and cinematic consumers compile against public F
  views without F importing them;
- hot iteration uses handles/indexes rather than string/UUID lookup and reports
  capacity and every allowed load/mutation-boundary growth; steady fixed-tick
  iteration is allocation-free and failed growth is atomic;
- single-writer mutation/thread enforcement, deterministic command conflicts,
  persistent/transient create/destroy authority, and two-phase publication;
- reset/unload/reload and downstream mock-consumer compatibility.

**Completion criteria**

- Runtime assembly has explicit ownership/deinit and no partially visible
  failure state.
- F imports no downstream implementation and mock consumers require no private
  F imports.
- Focused, `test`, `check`, and `test-full` pass; `test-stress` is required if
  lifecycle/handle/load-unload tests are classified long-duration.
- All transitional adapters have retirement records.
- Stop for owner review. W/R/P/E/U/C/A/H work remains separately authorized.

## L. Owner Decisions and Dispositions

F1-R2 records owner approval of every decision. The accepted text in each
subsection is authoritative; alternatives remain documented to preserve the
review rationale. Milestone implementation authorization remains separate and
follows K.0 rather than one global L1-L15 gate.

| Decision | Disposition | Milestone gate |
|---|---|---|
| L1 | Approved as written | F2B |
| L2 | Approved as written | F2A |
| L3 | Approved with F1-R2 amendment | F2A |
| L4 | Approved with F1-R2 amendment | F2A |
| L5 | Approved with F1-R2 amendment | F2A |
| L6 | Approved with F1-R2 amendment | F2A |
| L7 | Approved with F1-R2 amendment | F2B; runtime portion also F2C |
| L8 | Approved as written | F2B |
| L9 | Approved with F1-R2 amendment | F2B; runtime portion also F2C |
| L10 | Approved with F1-R2 amendment | F2B |
| L11 | Approved with F1-R2 amendment | F2B |
| L12 | Approved with F1-R2 amendment | F2B |
| L13 | Approved with F1-R2 amendment | F2B |
| L14 | Approved with F1-R2 amendment | F2C |
| L15 | Approved as written | F2C |

### L1. Are World, Level, and Scene distinct terms?

- **Accepted:** Use the definitions in B.3: WorldDefinition is authored
  global composition, LevelDefinition is streamable spatial content, and
  RuntimeScene/SceneSnapshot is resolved active state.
- **Why:** It supports loaded-area sets, persistence, previews, cutscenes, and
  generated content without serializing runtime caches.
- **Alternatives:** Treat world/level/scene as synonyms; or omit WorldDefinition
  and let an application own only levels.
- **Consequences:** Synonyms make streaming/save/cinematic semantics ambiguous.
  Omitting WorldDefinition is simpler but leaves persistent cross-level entity
  and global dependency ownership to each game.

### L2. Is the shared scene transform 3D or current-runtime 2D?

- **Accepted:** Use the canonical-compatible right-handed 3D local TRS and
  derived affine contract, with explicit adapters to current `Transform2D`.
- **Why:** Materials/lights/cameras/offline rendering and the accepted canonical
  3D pipeline need 3D, while the current 2D runtime embeds cleanly.
- **Alternatives:** F owns only 2D; or supports separate unrelated 2D and 3D
  entity hierarchies.
- **Consequences:** 2D-only F forces later identity/hierarchy migration for C/R.
  Dual hierarchies create reference and parenting ambiguity.

### L3. What is the persistent ID representation?

- **Accepted:** Strong 128-bit AssetId/EntityId with RFC 9562 lowercase UUID
  text and canonical/network byte order; injected-clock/entropy UUIDv7 for
  interactive creation and registered-namespace, length-delimited UUIDv5 for
  deterministic generation. Namespace/output duplicates fail. Scoped semantic
  strings remain H-owned and map explicitly through a future H registration
  adapter; `u32` slot/generation pairs remain runtime-only handles.
- **Why:** This is decentralized/worktree-safe, stable across rename/load, and
  still compact at runtime boundaries.
- **Alternatives:** Namespaced strings; central `u64`; content hashes.
- **Consequences:** Strings need namespace/rename governance and hot-path
  interning. Central integers impede parallel generation. Content hashes break
  stable references whenever content changes.

### L4. Are exact asset revisions mandatory in canonical scene inputs?

- **Accepted:** Yes. Authoring tools may offer compatibility preferences, but
  canonical build inputs record exact AssetKind, version, and content hash.
  Direct records are distinct from resolved transitive closures. The accepted
  classes are semantic/runtime-required, optional-presentation, and
  tooling-only; duplicates and cycles fail. Each class uses its own versioned
  domain hash, and only semantic/runtime closure changes simulation identity.
- **Why:** Procedural recreation and cinematic evaluation require a closed
  dependency set.
- **Alternatives:** Resolve “latest compatible” at every load; pin only major
  version.
- **Consequences:** Floating resolution makes identical scene bytes produce
  different results over time. Exact pins require an explicit dependency-update
  workflow.

### L5. How is existing canonical JSON reused?

- **Accepted:** Use a facade/conformance-first F2A strategy. Protected canonical
  model/geometry production pipelines remain unchanged. Any shared-leaf
  extraction requires separate justification, H compatibility approval, and
  passing protected byte, hash, API, and behavior regressions.
- **Why:** It establishes one repository contract without embedding scene data
  in the human schema.
- **Alternatives:** Copy a third serializer; make scene use
  `CanonicalCreatureDefinition`; postpone all scene serialization.
- **Consequences:** Copying guarantees drift. Reusing the creature document
  corrupts domain boundaries. Postponing serialization blocks F2B identity,
  determinism, and editor contracts.

### L6. Should F own shared spatial math code used by canonical model?

- **Accepted:** F2A ships an independent F spatial surface and required
  test-only conformance bridge first. Shared-code extraction is separately
  authorized only after H compatibility approval. Full affine inversion and
  affine-to-TRS representability use the published E.1 tolerances, preserve
  shear/reflection, fail on singular/nonrepresentable inputs, and never return
  approximate `keep_world` transforms.
- **Why:** F cannot depend on H, and duplicated quaternion/affine rules can
  drift.
- **Alternatives:** Permanent duplicate implementations; F imports
  `canonical_model.math3d`.
- **Consequences:** Duplication requires permanent conformance tests. F -> H is
  a forbidden dependency inversion.

### L7. How do downstream tracks attach heterogeneous authored data?

- **Accepted:** F-owned versioned ExtensionRecord framing plus host-supplied
  descriptors that compile canonical payloads into track-owned typed tables.
  B.6 governs track namespaces, deterministic frozen descriptor registration,
  canonical payloads, declared dependency classes, record/payload/asset limits,
  lossless unknown-optional preservation, and transactional prepare/commit/
  rollback across RuntimeScene and all compiled tables.
- **Why:** It keeps F closed to downstream imports without a fixed union that
  every track must edit.
- **Alternatives:** One F tagged union of every component; raw unvalidated JSON
  maps; separate sidecar files with no common framing.
- **Consequences:** A fixed union makes all additions F changes. Raw maps lose
  validation. Unframed sidecars make dependency/version/ownership behavior
  inconsistent.

### L8. Does F2 support prefab inheritance?

- **Accepted:** No general inheritance. Support composition, nested prefabs,
  and strict stable-path overrides only.
- **Why:** Inheritance ordering/conflict semantics are complex and no current
  content proves the need.
- **Alternatives:** Single inheritance; multiple/mixin inheritance; no prefabs,
  only duplicated instances.
- **Consequences:** Inheritance expands F2 and migration surface. No prefab
  reuse duplicates data and weakens editor/procedural workflows.

### L9. What are reparent and parent-removal defaults?

- **Accepted:** Explicit `keep_local`/`keep_world` under E.1 representability
  tolerances; default removal `reject_if_children`; optional subtree-atomic
  cascade/orphan policies. Deterministic child order is EntityId-based. Reject
  arbitrary cross-level parenting and use E.3's exact atomic level-unload rules.
- **Why:** Silent orphaning or transform approximation corrupts authored
  content and undermines streaming.
- **Alternatives:** Always keep world; always keep local; automatic cascade;
  permit arbitrary cross-level parents.
- **Consequences:** Automatic policies are convenient but destructive or
  surprising. Cross-level parents force coupled load/unload groups.

### L10. Who owns camera definitions?

- **Accepted:** F owns only neutral projection and lens/orthographic geometry.
  P/A/C own selection and motion. Exposure, depth of field, shutter,
  post-processing, viewport, jitter, render-target, and GPU state remain R/C-
  owned.
- **Why:** Cameras are consumed across gameplay, editor preview, icons,
  cinematics, and offline rendering.
- **Alternatives:** R owns all camera data; C or P owns cameras.
- **Consequences:** A specialized owner forces editor/cinematic/gameplay data to
  depend on an implementation track or duplicate camera schemas.

### L11. Where does general presentation metadata live?

- **Accepted:** U owns PresentationDefinition; F AssetHeader contains only an
  optional PresentationRef classified as optional-presentation. Localization
  or presentation changes never silently change simulation-semantic dependency
  identity; exact presentation workflows use a separate closure hash.
- **Why:** UI/display fields stay out of rendering/physics/gameplay while every
  asset can link to them without F -> U dependency.
- **Alternatives:** Put display fields directly in every F asset; make R own
  presentation metadata; leave the relationship untyped.
- **Consequences:** Direct fields broaden F changes and localization concerns.
  R ownership contaminates material/render code. Untyped links fail late.

### L12. What common layer/tag/visibility policy is approved?

- **Accepted:** F owns bounded lowercase `namespace:name` TagIds, authored
  enabled intent, derived inherited effective-enabled state, and simple
  visibility intent; R/P/W own distinct typed layer systems. Activation is
  parent-before-child, deactivation child-before-parent, with EntityId ties and
  atomic lifecycle publication.
- **Why:** “Layer” does not imply shared semantics, while activation and basic
  authored visibility are cross-cutting.
- **Alternatives:** One global `u32` layer mask; all visibility R-owned; all
  tags subsystem-specific.
- **Consequences:** One mask couples unrelated capacity and policy. R-only
  visibility complicates editor/cinematic source intent. Fully separate tags
  prevent common discovery/authoring.

### L13. Are volumes normal entities?

- **Accepted:** Yes: entity transform + F-owned typed VolumeShapeRef boundary +
  subsystem-owned semantic extensions. The shape payload/implementation owner
  is explicitly deferred to a later F/W/P/R gate. Shape coordinates are entity-
  local metres; unsupported affine scale/shear must fail rather than approximate.
- **Why:** Parenting, identity, streaming, editor selection, and references then
  use ordinary scene rules without making all volumes physics objects.
- **Alternatives:** One F union of every volume behavior; special non-entity
  zone collections in each track.
- **Consequences:** A behavior union violates ownership. Separate collections
  duplicate transforms/identity/streaming and complicate cross-system zones.

### L14. How dynamic is RuntimeScene storage?

- **Accepted:** Initialization, explicit level load, editor transaction, and
  authorized spawn/mutation boundaries may allocate or grow transactionally and
  must report old/new capacity and cause. Fixed-tick iteration is allocation-
  free after stabilization. RuntimeScene is single-writer; consumers hold
  bounded immutable snapshot leases. Failed growth/mutation publishes nothing.
  Generation zero is invalid; a slot whose generation would wrap is retired
  permanently rather than reused.
- **Why:** This matches current repository rules while allowing future
  streaming outside the steady simulation loop.
- **Alternatives:** Fully fixed compile-time capacity; unrestricted per-frame
  dynamic ECS allocation.
- **Consequences:** Fixed global limits impede content/streaming. Unrestricted
  allocation violates current performance/ownership contracts.

### L15. Does F2C adapt the current production foundation route?

- **Accepted:** Only mock consumers and, if needed, one read-only
  compatibility projection. Do not switch production rendering/physics/H
  ownership in F2C.
- **Why:** F2 must prove contracts without reopening accepted visual/runtime
  evidence or turning migration into a broad refactor.
- **Alternatives:** Convert `visual_foundation.Scene` immediately; provide no
  compatibility proof at all.
- **Consequences:** Immediate conversion greatly expands risk and blocks
  parallel work on evidence parity. No adapter proof leaves downstream
  integration assumptions untested.

Owner approval makes Revision 2 the accepted F1 contract. It authorizes no
implementation by itself. F2A, F2B, and F2C each require a dedicated request,
their K.0 prerequisites, and a stop at their own owner-review boundary.
