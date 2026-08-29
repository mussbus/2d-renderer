# F2C — Runtime Scene Assembly, Registry, Lifecycle, and Snapshots

**Status:** F2C owner-approved; authority-encapsulation amendment at
`685383a9012f10769c89b363d2eeff820410e0ae` owner-approved; subsequent F3
follow-up owner-approved

**Revision date:** 2026-08-29

**Baseline commit:** `ae6b76e82be11d2532f8cc668e4398946e47e4ba`

**Authority-amendment base:** `29b01df8c2e39e0447b5270faa23708afcd6b99d`

**Accepted authority-amendment commit:**
`685383a9012f10769c89b363d2eeff820410e0ae`

**Authority:** `../architecture/shared_engine_scene_foundation_architecture_v1.md` Revision 2

**Gate:** Runtime portions of L7 and L9, L14–L15, plus the accepted F2B schemas

## Current owner disposition

The authority-encapsulation amendment described below is accepted. The
independent F3 follow-up was subsequently reviewed and owner-approved, and the
Foundation is accepted as the substrate for F4 production-architecture
hardening. The earlier candidate wording and the original F3 finding remain
historical evidence; they are not the current F2C or Foundation disposition.

F4 does not reopen F identity, canonical-data, scene-core ownership, runtime
mutation authority, snapshots, publication, hierarchy, lifecycle, or another
accepted F contract unless a future owner-approved amendment explicitly does
so.

## Outcome and boundary

F2C adds a renderer-independent, CPU-only runtime scene foundation under
`src/scene_core/`. It consumes normalized, validated current F2B definitions;
builds candidate runtime state; resolves exact asset references through a
neutral callback; evaluates hierarchy and transforms; prepares downstream
participants; and publishes one coherent generation. No production renderer,
physics, gameplay, editor, cinematic, Human, foundation-playground, or current
scene route imports these modules yet.

Runtime state is not an authored format and is not canonically serialized.
F2B remains the authority for prefab, entity-instance, Level, World, camera,
metadata, and extension meaning. F2C owns only the active resolved registry,
mutable hierarchy, cached transforms, Level activation state, runtime tokens,
publication generation, and bounded immutable snapshots.

## Runtime module layout

```text
src/scene_core/
├── runtime_asset.zig    neutral exact AssetRef -> opaque token boundary
├── runtime_entity.zig   owned shared runtime record and lifetime classes
├── registry.zig         slot/generation storage and EntityId lookup
└── runtime_scene.zig    assembly, hierarchy, transforms, lifecycle,
                         publication, snapshots, and read-only views
```

The existing authored modules are unchanged. The runtime root imports only
the Zig standard library, F2A `foundation`, and F2B/F2C F-owned modules. The
existing character-specific registry in `src/scene/character.zig` remains an
H/current-route implementation and was neither imported nor modified.

## Authority-encapsulation amendment

F3-MAJ-001 found that the implementation contradicted the documented
authority boundary. Before this amendment, the supported `scene_core` root
re-exported both `registry.zig` and `runtime_entity.zig`; a consumer could
therefore construct `EntityRegistry`, call `insert`, `destroy`, `getMutable`,
or `assignPersistentId`, and directly edit `RuntimeEntity`. `RuntimeScene`
also exposed its registry-bearing state, publication generation, snapshot
lease counters, and growth sink as ordinary struct fields. `SceneSnapshot`
carried mutable opaque context pointers. The registry tests demonstrated the
root-level route by importing `scene_core.registry` as a normal consumer.

The amendment narrows accessibility without changing runtime semantics:

| Surface | Classification |
| --- | --- |
| `runtime_scene.RuntimeScene` | Public authority façade; implementation held behind a const opaque context |
| `runtime_scene.SceneSnapshot` | Public deep-owned immutable read contract with const opaque contexts |
| `runtime_scene.SceneReadView` / `EntityView` / subordinate views | Public read-only borrowed views |
| `foundation.identity.EntityHandle` | Public runtime value; never serialized |
| `runtime_scene.MutationContext` and operation-specific APIs | Public authority-checked mutation surface |
| `runtime_asset.Resolver` / `ResolvedAssetToken` | Public neutral exact-resolution boundary |
| `registry.EntityRegistry` | F2C internal implementation |
| `runtime_entity.RuntimeEntity` | F2C internal mutable storage |
| Registry slots, mappings, generations, and hierarchy adjacency | F2C internal implementation |
| Candidate state, dirty/cache state, publication and lease bookkeeping | F2C internal implementation |

Zig declarations used across sibling source files remain `pub` where the
compiler requires cross-file visibility, but neither internal module is
re-exported by `scene_core/root.zig`. A separate
`src/scene_core/internal_test_root.zig` is wired only into the registry
white-box test artifact. Production modules outside `src/scene_core/` may
import the supported `scene_core` module but may not directly import
`registry.zig`, `runtime_entity.zig`, or the named internal test module. The
repository source-policy audit enforces that rule.

`RuntimeScene` retains the existing activation, lifecycle, transform,
hierarchy, promotion, publication, and snapshot operations. Public contract
aliases for lifetime, authority, world-transform, asset-role, registry
configuration, and growth diagnostics are provided by `runtime_scene`; no
consumer needs the mutable storage module. Mock R/P/gameplay/C consumers use
only the supported root, snapshots, and const views. Const opaque contexts do
not grant supported writable access; internal methods alone cast them back to
F-owned storage while applying the existing validation and publication path.

## Registry and handle lifecycle

`EntityHandle` retains the accepted two-`u32` F2A value layout. The registry
allocates the lowest reusable slot within its current logical capacity. A new
slot starts at generation 1. Destroying an entity immediately increments its
generation before placing the slot back on the free set; the next occupant
therefore cannot resolve through an old handle. Generation zero and slot
`maxInt(u32)` remain invalid.

If a slot is destroyed at generation `maxInt(u32)`, it is permanently retired.
The generation never wraps. Retirement reduces usable capacity, increments the
reported retired-slot count, and produces a capacity event when reached. The
pure `nextGenerationAfterDestroy` policy returns `null` for this terminal
transition so the overflow rule is independently testable without billions of
allocations.

Persistent active entities are indexed by a sorted `EntityId -> EntityHandle`
table. Lookup compares canonical UUID bytes and never reparses strings. An
active duplicate is rejected. Destruction and Level unload remove the mapping.
Temporary entities may have only a handle; a handle is never persistent or
serialized.

Handles are valid only within one registry lifetime. Definition and prefab
ordering is deterministic, but consumers must not depend on a particular slot
or generation across reloads, different activation sequences, or processes.
Persistent determinism uses `EntityId`.

## Ownership, capacity, and mutation authority

The registry allocates bounded hard storage at scene initialization and grows
logical entity, persistent-mapping, and active-Level capacities only during
authorized load/create/editor mutation points. Growth is geometric, preserves
slot indices and handles, and emits category, old/new capacity, hard capacity,
and cause only after successful publication. Candidate capacity failure is
atomic and emits no published growth event.

F2C owns registry slots, generation counters, identity mappings, hierarchy
adjacency, cached transforms, Level records, runtime-owned strings/payloads,
and snapshots. Downstream code receives opaque read views and cannot obtain a
writable registry or generation counter.

Mutation authority is explicit:

- W authority activates/deactivates Levels and the World, owns Level-scoped
  create/destroy, and may mutate shared Level/world records;
- P/gameplay authority may create, destroy, or mutate gameplay-scoped
  temporaries, may promote only an eligible gameplay temporary by assigning a
  fresh persistent EntityId, and may request mutations of persistent shared
  records;
- A authority is limited to editor-preview temporaries;
- C authority is limited to cutscene-preview temporaries; and
- F validates, applies, and publishes every accepted operation.

An authority mismatch fails before candidate publication. This is not a full
ECS command system. The future save-game boundary also remains unchanged: W
owns the top-level save/world-state envelope and persistent/Level partition;
P owns versioned gameplay/simulation payloads inside that envelope.

Promotion remains an F-owned mutation and is accepted only for a
`.transient.physics_gameplay` entity under `.physics_gameplay` mutation
authority. An unparented gameplay transient is eligible only when its optional
Level host is absent, so both the transient and the resulting
world-persistent entity use the world-zero origin basis. A gameplay transient
parented beneath a world-persistent entity is also eligible, including when it
has a Level lifecycle host, because both before and after promotion its world
origin and affine are inherited from that same persistent parent. A Level host
must never be treated as world-basis merely because its numeric origin happens
to be zero.

An unparented Level-hosted gameplay transient fails closed with
`PromotionRequiresWorldRebase`; F2C does not collapse the exact `i64` Level
origin into `f32`, rebase, approximate, or teleport it. Parent compatibility is
validated first, so a request that is both beneath a non-world-persistent
parent and Level-hosted deterministically reports `PersistentBelowLevelOwned`
before the rebase-required condition. `EntityAlreadyPersistent`,
`PersistentBelowLevelOwned`, and `PromotionRequiresWorldRebase` classify as
the dedicated stable runtime codes `entity_already_persistent`,
`persistent_below_level_owned`, and `promotion_requires_world_rebase`.

Every otherwise eligible promotion captures the published world transform,
changes identity/lifetime only in a candidate, reevaluates the dirty subtree,
and requires the exact origin to match plus the affine to compare equal under
the accepted F2A affine tolerances. Only then may two-phase publication begin.
Any policy, identity, capacity, evaluation, invariant, or participant failure
leaves the live mapping, lifetime, handle, hierarchy, local/world transforms,
and publication generation unchanged. A future owner-reviewed W/persistence
operation may define spatial-domain transfer; it is not part of F2C promotion.

The current contract is single-writer. No locks, atomics, jobs, or lock-free
storage are introduced. Scene mutation, Level activation, and snapshot
acquisition are allowed allocation points. Read-only entity queries,
handle/EntityId resolution, extension lookup, transform reads, and lifecycle
ordering allocate nothing.

## Hierarchy and removal

Runtime hierarchy uses handles and owned, deterministically sorted child
adjacency. Persistent EntityId byte order is the sibling tie-breaker;
runtime-only entities fall back to handle value order. Parent assignment checks
handle validity, cycles, world-persistent ownership, and cross-Level scope.
World-persistent entities cannot be parented beneath Level-owned state, and
arbitrary cross-Level parenting is rejected. A Level entity may use a declared
world-persistent anchor.

Reparenting is transactional and explicit:

- `keep_local` retains local TRS and allows world placement to change;
- `keep_world` retains the exact prior affine world placement only when the
  old and new exact origins match and F2A inverse/decomposition succeeds. It
  fails on singular transforms, nonrepresentable shear, or a cross-origin
  request instead of approximating.

Removal defaults to `reject_if_children`. `cascade` removes children before
parents in reverse deterministic adjacency order. `orphan_keep_world`
precomputes every direct child's root-local TRS and exact-origin compatibility
before changing any link; one failure rejects the whole candidate.

The published lifecycle-order query is parent-before-child for enabling and
the exact reverse for disabling. It uses caller-owned scratch and the same
deterministic root/sibling ordering.

## Transforms and large-coordinate boundary

Local transforms remain F2A `LocalTransform`. World transforms remain general
F2A `AffineTransform` and use:

```text
world_affine = parent_world_affine × local_affine
```

World affines are never forced back to TRS during evaluation, so negative
scale and hierarchy-generated shear survive. Dirtying a local transform or
parent marks only that subtree. Evaluation recursively guarantees
parent-before-child order, detects defensive runtime cycles, tracks parent
world revision, and does not recompute clean unrelated branches.

Each runtime world transform is a pair:

```text
exact signed-i64 Level/world origin in millimetres
+ small f32 affine in metres
```

A Level root uses its exact authored origin. Descendants inherit their runtime
parent's origin; a Level entity explicitly parented to a world-persistent
anchor therefore uses the anchor's world-frame origin. Arbitrarily large
origins are never converted to one giant `f32` translation or added into every
entity. Cross-origin `keep_world` remains fail-closed pending the separately
approved W/F large-world and rebasing amendment.

## Assembly, prefabs, and exact assets

Level and World assembly starts from a deep clone of the currently published
state. World activation resolves every declared exact Level reference but does
not activate it implicitly; W remains responsible for issuing the explicit
Level activation operations. Authored roots are ordered parent-before-child
with EntityId ties.
Prefab definitions are located by complete `AssetRef`; nodes are likewise
ordered independently of source array order. Nested prefabs are bounded to 32
levels, cycles reject, and instantiated persistent child IDs use the accepted
F2B root-EntityId/canonical-node-path UUIDv5 derivation. Instance overrides are
copied onto the exact expanded node path without interpreting downstream
properties or rewriting the authored prefab.

The neutral resolver accepts a complete exact `AssetRef` and returns a
nonzero opaque `ResolvedAssetToken`. F2C neither constructs nor owns a GPU,
physics, UI, cinematic, material, mesh, or Human object. Runtime records retain
owned exact reference kind bytes plus tokens for prefab sources,
presentations, volume shapes, layer references, and extension dependencies.

Extensions retain owned type ID, exact schema version, criticality, canonical
payload bytes, dependency class, complete exact references, and resolved
tokens. Unknown `optional_preserve` records therefore survive the F2B parse
buffer lifetime and remain queryable without interpretation. Runtime assembly
deep-copies every durable tag, type ID, payload, dependency-kind string,
override path/value, and prefab node path; it keeps no pointer into a temporary
F2B source buffer.

## Level lifecycle and publication

Multiple Levels may be active. Duplicate activation and unloading an inactive
Level fail explicitly. A successful unload removes all Level-owned entities
and all host-scoped transient entities, children before parents; invalidates
their handles; removes their persistent mappings; detaches their links from
surviving world anchors; and leaves unrelated Levels and world-persistent
entities intact. A surviving external dependent causes the complete unload to
fail before mutation.

Every operation uses two phases:

1. Clone/build the candidate, resolve exact assets, establish hierarchy,
   evaluate transforms, and call every registered participant's `prepare` on
   an opaque read-only candidate view.
2. If every prepare succeeds, swap the core state, advance one independent
   `u64` publication generation, call infallible participant commits, destroy
   the prior state, and emit capacity events.

If one prepare fails, that participant and every earlier prepared participant
receive rollback in deterministic reverse order. The candidate is destroyed;
the core scene, Level set, handles, EntityId mappings, publication generation,
and track-owned tables remain exactly as published before the request.

## Snapshots and consumer view

`SceneSnapshot` is a deep immutable clone stamped with the scene publication
generation and caller-supplied validated `SceneTime`. A configured hard lease
count bounds outstanding snapshots. Snapshot acquisition is an allowed
allocation point; release is explicit through `deinit`. RuntimeScene refuses
destruction while leases exist. A snapshot remains coherent and unchanged
across later scene mutations because its storage is neither mutated nor reused
until release.

The opaque view exposes entity iteration, handle and optional EntityId,
handle lookup, EntityId resolution, local and exact-origin/world transforms,
parent/children, authored and effective enabled state, shared visibility
intent, lifetime/Level ownership, tags, neutral camera geometry, resolved
asset references/tokens, extensions/dependencies, overrides, active Levels,
and deterministic lifecycle order. It exposes no writable slot, mapping,
generation, adjacency, or publication storage.

Runtime errors remain typed Zig errors and are classifiable through stable
`RuntimeErrorCode`; `foundationDiagnosticCode` maps them onto the accepted F2A
diagnostic families. Promotion policy failures have dedicated runtime codes;
the rebase-required code maps to `invalid_spatial_value`, while already-
persistent and incompatible-parent failures map to `invalid_reference`.
English messages are not the machine contract.

## Downstream handoff

- R may consume iteration, handles, exact-origin/world affines, renderer-owned
  extension envelopes/tokens, neutral mesh/material/presentation references,
  and shared visibility intent. R may not redefine identity, transforms, or
  hierarchy.
- P may consume handles, exact-origin/world affines, P-owned extension data,
  enabled state, and shared lifecycle identity. P may not create a parallel
  authoritative registry.
- Gameplay may resolve `EntityId <-> EntityHandle`, query shared metadata and
  extensions, and request authorized lifecycle operations. It may not persist
  handles.
- C may consume the same scene identities, transforms, neutral camera
  geometry, and `SceneTime` without depending on the real-time renderer. It
  may not create a separate world/entity identity system.
- A may edit F2B definitions and use bounded F2C preview snapshots. Editor-only
  records may not become authoritative over F2B.

Test-only mock R, P, gameplay, and C consumers prove these boundaries against
one snapshot. Runtime modules import none of their implementation modules.

## Deferrals

F2C deliberately does not implement production integration, save games,
streaming or async I/O, procedural generation, floating-origin rebasing, ECS
archetypes, transform jobs, render extraction, materials, lights, physics
bodies, gameplay mechanics, UI, cinematics, editor tools, or Human adapters.
It does not change F2A/F2B schemas, canonical serializers, hashes, protected
Human assets/topology/evidence, or existing runtime routes.

## Verification

The focused CPU-only gate is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-scene-core-runtime -j1 --summary all --seed 0x6f084e2a
```

Its 27 declarations run as 22 public/runtime-scene tests plus 5 F-owned
registry white-box tests. They cover public-surface encapsulation, allocation
and persistent lookup, duplicate IDs,
destroy/reuse/stale rejection, invalid handles, logical growth and handle
preservation, terminal generation retirement policy, deterministic hierarchy,
effective enabled/lifecycle ordering, exact large origins, dirty subtrees,
negative scale and shear, both reparent modes and cycles, all removal policies,
multi-Level activation/unload, host-scoped temporaries, explicit gameplay
promotion authority, fail-closed origin-basis eligibility, dedicated promotion
diagnostics, atomic policy rejection, successful world-affine preservation, world
anchors, nested prefab identity/reuse/overrides, exact-resolution rollback,
owned authored-buffer lifetime, immutable/bounded snapshots, stable diagnostic
classification, capacity failure atomicity/reporting, prepare/commit/rollback,
and common mock-consumer identity/transform/camera/extension observations.

The target is a direct dependency of `test`, and therefore of `check` and
`test-full`. It requires no SDL initialization, window, GPU, or downstream
implementation.

The authority-encapsulation amendment was validated on 2026-08-29 with:

- runtime focused: 27/27, split into 22 public/runtime-scene tests and 5
  internal registry white-box tests;
- authored focused: 39/39;
- foundation focused: 27/27;
- aggregate `test`: 518/518;
- static `check`: 53/53 build steps and 518/518 tests, including the new F2C
  authority import/export policy;
- `test-full`: 60/60 build steps and 629/629 tests;
- explicit requested `zig fmt --check` and `git diff --check`: pass; and
- targeted root-export, production/test import, authored-runtime
  serialization, and protected-path scans: zero findings.

At amendment completion, these results made F3-MAJ-001 ready for independent
re-audit but did not themselves approve the Foundation freeze. The required
follow-up was subsequently reviewed and owner-approved, as recorded in the
current disposition at the top of this document.
