# F4C4 Scene-Core Adoption and Input Boundaries

Date: 2026-08-31

Status: **IMPLEMENTED / AWAITING OWNER REVIEW**

F4A, F4B1, F4B2, F4C1, F4C2, and F4C3 are owner-approved. F4C4 is
authorized by the owner. F4 overall remains not accepted; F4C5, F4D, F4E,
and post-F4 feature work have not begun.

## Starting gate

| Gate | Observed result before any modification |
|---|---|
| HEAD | `f8ee7e7165c9a331e80aea95bab8db9cef858217` |
| Branch | `master` |
| Upstream | `origin/master` at the same commit |
| Ahead / behind | `0 / 0` |
| Worktree | Clean |
| Compiler | Zig `0.16.0` |
| Repository audit | Passed for 263 files |
| Required inherited boundaries | F4C1 production definitions, F4C2 renderer/application/evidence separation, and F4C3 opaque character/interaction authority were present |

## Pre-F4C4 identity, lifetime, and world audit

The accepted `scene_core.runtime_scene.RuntimeScene` existed only in F tests.
No production module outside `scene_core` imported the supported `scene_core`
root. Current character scenarios therefore owned creation, destruction,
lookup identity, root transforms, participation and render ordering without an
F runtime entity corresponding to a character.

| Concept | Pre-F4C4 owner and identifier | Persistence and consumers | Mutation/lifetime authority and invariant | F relationship and F4C4 disposition |
|---|---|---|---|---|
| Generic persistent entity identity | F `foundation.identity.EntityId`, used only by scene-core definitions/runtime tests | RFC 9562 128-bit persistent identity | `RuntimeScene` rejects duplicate active IDs and resolves ID to current handle | Adopt for the representative production route |
| Generic runtime identity | F `EntityHandle { slot, generation }`, used only by scene-core runtime tests | Process/runtime only; invalid after destruction/reuse | F registry generation and stale-handle checks | Adopt through the supported RuntimeScene view only |
| Legacy character identity | `character.EntityId`, a nonzero `u32` enum | Runtime-only in practice but named generically; characters, interactions, diagnostics, render sort/evidence and scenario lookup consume it | Character allocator/scenario assigns; reset preserves it; old `EntityRegistry` is a fixed compatibility lookup | Retain only as a character-subsystem lookup/order key beneath an F binding; never serialize as world identity |
| Legacy character registry | `character.EntityRegistry` fixed array of legacy IDs | Used by legacy multi-character behavior/tests, not authored persistence | Rejects invalid, duplicate and overflow IDs | Keep specialized and bounded; it is not scene membership or persistent identity |
| Character creation/destruction | Individual demo/scenario `init`/`deinit` functions | Scenario lifetime | Scenario constructs definition, world and character fields; error defers clean partial initialization | Representative integrated composition creates F entities and attaches existing specialized runtimes; F scene teardown precedes character teardown |
| Scene membership | Implicit presence in scenario struct/participant arrays | Runtime-only | Owning scenario decides whether an object exists | F binding becomes membership authority for the integrated route |
| Character world/root position | `CharacterInstance.world_position`; controlled characters additionally contain controller position | Runtime-only; simulation, IK, diagnostics and render extraction read it | Controller writes physics root, character coordinator synchronizes pose/presentation | F owns published generic transform; controller owns in-step physics result; adapter pulls before simulation and publishes after a simulation frame/batch |
| Default/reset transform | Character default position/facing | Character lifetime | Character reset restores it without changing legacy ID | Reset preserves F identity and republishes the reset root through the adapter |
| Pose/root offsets | Character pose, procedural, IK and anatomy runtime | Runtime-only specialized state | F4C3 character/animation/IK owners | Remains outside RuntimeEntity |
| Presentation offsets/views | Character presentation and attachment secondary motion | Derived runtime state | F4C3 presentation/appearance owners | Never synchronized into generic F transform |
| Enabled/active state | Implicit scenario participation; no generic enabled state | Runtime-only | Presence in update/submit arrays determines activity | F effective-enabled cache gates integrated simulation, interaction eligibility and render submission |
| Interaction participant identity | Legacy character ID plus character pointers in manager calls | Runtime-only; not serialized | F4C3 manager owns lifecycle and locks | Integrated route first resolves live enabled F bindings; manager retains subordinate character lookup IDs internally |
| Render identity/sort key | Legacy character raw ID appears in deterministic attachment keys and evidence | Runtime-only render ordering/evidence | Character extraction owns submitted keys | Retain as a character-local stable sort key; it is explicitly not world identity |
| Collision/controller identity | Collider IDs identify static fixtures; controller itself has no persistent entity ID | Runtime-only | Physics owns collision and root results | No identity replacement; adapter publishes the result to F |
| Spawn/despawn | Scenario init/deinit/reset; no general runtime spawn | Runtime-only | Scenario owns all | Adapter provides bounded F entity create/bind/destroy operations for the representative path |
| Hierarchy | Character pose hierarchy only; no generic entity parenting | Runtime-only skeleton semantics | Pose owner | Representative character F entities are root entities; F hierarchy semantics remain unchanged |
| Persistent references | F definitions support them; character scenarios do not | Authored F only | F schema/validation | No schema change; no character legacy ID becomes a persistent reference |
| Collision-world fixtures | Demo collision world arrays | Scenario lifetime | Collision-world owner | Remain specialized; F4C4 does not move fixtures into RuntimeEntity |

## Identity authority decisions

| Identity | Purpose | Persistence | Authority | Allowed consumers |
|---|---|---|---|---|
| F `EntityId` | Generic authored/world identity | Persistent | F / RuntimeScene | Authored/runtime scene, adapter and F read views |
| F `EntityHandle` | Live runtime entity lookup | Runtime only | F registry through RuntimeScene | Adapter and generic snapshots/read views |
| Legacy `character.EntityId` | Character-local lookup, interaction addressing and deterministic render ordering | Runtime only; never serialized | Character subsystem | Character, interaction, specialized scenarios, diagnostics and the binding adapter |
| Interaction ID | One interaction lifecycle instance | Runtime only | F4C3 interaction manager | Interaction commands/observations |
| Collider ID | Static collision fixture identity | Runtime only | Physics collision world | Controller/ground queries/debugging |
| Draw-order key | Deterministic render ordering | Per submission/runtime | Character/render extraction | Queue, renderer and evidence observations |

The term `EntityId` on the legacy character type is retained for compatibility,
but its authority is explicitly subordinate. No mapping derives an F ID by
zero-extension, formatting or serialization of the `u32` value. The adapter
stores an explicit association established by the application composition.

## Bounded F-character adapter design

The production adapter is a specialized, fixed-capacity owner beneath F. Its
private state contains one supported `RuntimeScene` and a deterministic compact
binding table. It does not expose the scene's mutable storage or its binding
array.

Supported operations are intentionally narrow:

- initialize/deinitialize the F-backed character composition;
- create a persistent F root entity and bind one legacy character runtime ID;
- attach/detach and resolve a live binding;
- resolve F handle or F persistent ID for a character runtime ID;
- pull a published F root transform into a character through F4C3 commands;
- publish the controller/character root into F through `setLocalTransform`;
- set F enabled state and query the committed effective state;
- destroy the authoritative F entity and transactionally remove its binding;
- acquire a standard F snapshot for generic observations.

Invariants:

1. A live F handle occurs at most once.
2. A persistent F entity ID occurs at most once.
3. A legacy character runtime ID occurs at most once.
4. Bind validates the handle and exact persistent ID through an F read view.
5. A RuntimeScene publication participant stages binding/cache changes and
   commits only after F publication succeeds.
6. Destroyed or stale handles cannot resolve a character runtime.
7. Character reset never replaces either F identity value.
8. Binding storage is fixed-capacity and deterministically ordered by F
   persistent EntityId, then handle.
9. Fixed-table binding lookup/insertion/removal allocates nothing; F
   RuntimeScene mutation and explicit snapshot acquisition retain their
   accepted transactional allocation points.

## Lifetime and failure policy

The integrated compatibility path may construct the specialized character
runtime before binding because rewriting character initialization is outside
F4C4. It then creates/promotes the F entity and attaches that existing runtime.
Once attached, F membership and lifetime are authoritative:

- destroying an F entity publishes removal before the binding disappears;
- disabled/unbound characters cannot simulate, interact or submit through the
  F-backed integrated path;
- adapter teardown destroys the RuntimeScene before specialized character
  teardown;
- a failed bind destroys the just-created F entity before returning;
- partial integrated initialization deinitializes the adapter and all F state
  before deinitializing specialized characters;
- fixed binding capacity and duplicate mappings fail atomically.

## Transform synchronization policy

| Stage | Source authority | Direction and behavior |
|---|---|---|
| Entity creation/bind | F spawn transform supplied by composition | F publishes the generic root; adapter verifies the character root matches |
| Before simulation frame or explicit fixed-tick batch | Last committed F transform | Adapter applies changed X/Y root translation through `stageControlledTransform` or `setWorldPosition`; Z, scale and rotation must remain the supported 2D root form |
| During controller step | Physics/controller state | Controller exclusively owns the in-step root result; pose and presentation derive from it |
| After simulation frame or explicit batch | Character/controller root | Adapter publishes one changed root transform through RuntimeScene with its publication participant |
| Snapshot/publication | F committed state | Generic identity, transform, lifetime and enabled state are read from an F snapshot |
| Render extraction | Character const/read façade | Pose, facing, appearance and presentation remain specialized; only F enabled membership gates extraction |

The adapter caches only the last committed F root translation and effective
enabled value. RuntimeScene is the source; publication prepare/commit is the
only cache invalidation path. This avoids per-tick snapshots and unnecessary
unchanged transform publications. Root F entities use world origin zero and
identity rotation/unit scale; parented, rotated, scaled or nonzero-Z character
roots are rejected rather than approximated.

## Representative route and transitional routes

The existing `integrated` route is the F-backed production proof. Its two
characters have persistent F IDs and handles, are attached to the bounded
adapter, synchronize the controlled root at frame/batch publication boundaries,
gate interaction through live enabled bindings, submit only enabled bound
characters, and expose F snapshots for validation. Its interaction manager
continues to use legacy IDs as character-local lookup keys beneath those live
bindings.

| Route classification | Routes |
|---|---|
| F-BACKED | `integrated` |
| TRANSITIONAL LEGACY SCENARIO | `sprites`, `controller`, `handshake-ik`, `playground`, `side-scroller`, `modular-body`, `equipment`, `mesh-attachments`, `art-assets` |
| SPECIALIZED ACCEPTANCE/CONTENT ROUTE | `foundation`, `wardrobe`, `visual-quality`, `anatomy-quality`, `environment` |

F4C4 does not rewrite those retained routes into authored scene JSON. F4D owns
the later independent composition proof.

The implemented route constructs specialized character state first only as a
documented compatibility step, then creates and promotes two persistent F
entities and attaches the runtimes. From attachment until scene teardown,
RuntimeScene membership, enabled state, handle validity and published root
transform are authoritative. The application route performs no direct access
to F registry/runtime-entity implementation storage.

## Pre-F4C4 input audit

Before F4C4, `src/platform/input.zig` combined raw physical/device state,
focus filtering, edge calculation, application actions, character intent and
pending fixed-tick delivery.

| Input state/action | Before owner | Classification | F4C4 owner |
|---|---|---|---|
| Physical keys A, D, arrows, Space, Shift, E, R, F1-F4, C, V, H, L, O, P, Q, T, Escape | Platform input | PHYSICAL / DEVICE INPUT | Platform physical state |
| Keyboard focus/loss and window-close request | Platform input/SDL input | PHYSICAL / DEVICE INPUT | Platform physical state |
| Gamepad left-X axis and South/West/right-shoulder buttons | Platform input/SDL input, previously named by actions | PHYSICAL / DEVICE INPUT | Platform physical state with physical names |
| Move axis, jump and dash | Platform snapshot/intent | GENERIC MOVEMENT INTENT | Application mapping to physics-owned `CharacterIntent` |
| Interact | Platform snapshot/intent | APPLICATION ACTION feeding an interaction domain command | Application mapper; manager remains domain owner |
| Reset | Platform snapshot | APPLICATION / DEMO ACTION | Application mapper/scenario coordinator |
| Debug toggle | Platform snapshot | APPLICATION / DEMO ACTION | Application mapper/scenario coordinator |
| Time-mode cycle, pause and single step | Platform snapshot | APPLICATION / DEMO ACTION | Application mapper/clock coordinator |
| Manual debug/evidence capture | Platform snapshot | APPLICATION / EVIDENCE ACTION | Application mapper and evidence scheduler |
| Body preset, build and hair cycle | Platform snapshot | DOMAIN COMMAND trigger | Application mapper to character/anatomy commands |
| Loadout and outfit cycle | Platform snapshot | DOMAIN COMMAND trigger | Application mapper to equipment/wardrobe commands |
| Presentation-view cycle | Platform snapshot | DOMAIN COMMAND trigger | Application mapper to presentation command |
| Environment-theme cycle | Platform snapshot | DOMAIN COMMAND trigger | Application mapper to environment command |
| Exit | Platform snapshot | APPLICATION ACTION | Application mapper/application loop |
| Focus-safe blocked-until-release and edge history | Platform input | APPLICATION ACTION MAPPING STATE over physical inputs | Application mapper |
| Pending fixed-tick character edges | Platform input | GENERIC MOVEMENT/INTERACTION DELIVERY | Application mapper producing physics-owned intent |

## Target input ownership

`src/platform/input.zig` retains only physical keyboard/gamepad/focus/window
state and generic physical-state set/numeric helpers. `sdl_input` polls and
returns that raw state. A focused application `demo_actions` mapper owns the
unchanged key bindings, edge/repeat behavior, focus blocking, demo/content
action names and scripted-input parity. Physics owns the narrow
`CharacterIntent` value accepted by the controller. Scenario/application code
maps actions to the F4C3 character, interaction, wardrobe, environment and
evidence command surfaces.

The mapping remains:

```text
SDL physical state
    -> demo action mapper
    -> application/scenario action snapshot
    -> domain command or CharacterIntent
```

Scripted routes construct the same physical state and call the same mapper;
evidence staging may invoke the same semantic application operation directly
without pretending to be a keyboard.

## Before/after identity matrix

| Concept | Before authority | After authority | Compatibility state |
|---|---|---|---|
| Persistent entity identity | F contract unused by production characters | F `EntityId` / RuntimeScene | Adopted by integrated route |
| Runtime entity identity | F handle used only in F tests | F `EntityHandle` | Adopted by integrated route/adapter |
| Character internal ID | Character subsystem, generically named | Character-local lookup/order key beneath binding | Retained, contained |
| Interaction participant identity | Legacy ID/pointer | Live F binding gates participation; legacy ID remains internal manager lookup | Bounded compatibility |
| Render identity/key | Legacy raw ID in deterministic sort/evidence | Same character-local render key, explicitly not world identity | Intentionally distinct |
| Collision/controller token | Controller and collider IDs | Unchanged; physics result publishes to F transform | Intentionally distinct |
| Scene membership | Scenario struct presence | RuntimeScene entity plus live adapter binding | Adopted for integrated route |
| Lifetime/destruction | Scenario `init`/`deinit` | F scene lifetime precedes attached character lifetime | Adopted for integrated route |
| World transform | Controller/character root only | F committed generic root; controller owns in-step result and publishes through adapter | Explicit staged authority |

## Before/after input matrix

| Action/state | Before owner | After owner | Classification |
|---|---|---|---|
| Keys, physical gamepad controls, focus, window close | Platform | Platform | Physical/device |
| Button edges and focus resynchronization | Platform | Application mapper | Application mapping |
| Move/jump/dash/interaction action | Platform | Application mapper; CharacterIntent in physics boundary | Generic/domain intent |
| Reset/debug/time/step/pause/exit | Platform | Application mapper/coordinator | Application action |
| Body/build/hair/loadout/outfit | Platform | Application mapper to domain commands | Domain action |
| Presentation/environment cycles | Platform | Application mapper to domain commands | Domain action |
| Manual evidence capture | Platform | Application mapper/evidence coordinator | Evidence action |

## Validation

### Dependency metrics

| Metric | Before F4C4 | After F4C4 |
|---|---:|---:|
| Production legacy-character-ID uses outside specialized scene/interaction/debug/application scope | 0 | 0, statically enforced |
| Persistent/world scene references using legacy character identity | 0 | 0, statically enforced at the scene-core boundary |
| F-backed character/application routes | 0 | 1 (`integrated`) |
| Production F-character adapter consumers | 0 | 1 (`integrated_demo`) |
| Direct supported RuntimeScene consumers outside `scene_core` | 0 | 1 (the binding adapter) |
| Domain/content action identifiers in physical platform input | 18 mappings co-located with physical state | 0 |
| Platform imports of application/domain modules | 0 | 0, now statically enforced |
| Application action mappings in a dedicated owner | 0 | 18 (move plus 17 button actions) |
| Focused tests covering adapter/action boundaries | 0 | 5 |

The adapter's compact table has a hard capacity of eight, matching the current
character subsystem. Table lookup and unchanged synchronization allocate
nothing. Creating, destroying, enabling or publishing a changed F root uses an
explicit authorized RuntimeScene mutation boundary and therefore retains the
accepted F2C candidate-clone allocation model. One changed publication occurs
after a rendered frame or an explicit fixed-tick batch, never inside an
individual fixed tick; unchanged roots do not publish. Snapshot acquisition is
an explicit bounded allocation/lease point and is not used in the hot loop.

The production `DemoApplication` supplies a reclaiming runtime allocator to the
adapter's `RuntimeScene`; character and adapter storage remains in the existing
scenario arena. `RuntimeScene` owns and frees each publication candidate. This
separation is required because using the scenario arena for candidate cloning
made valid scene mutations look like permanent legacy-arena growth even though
the scene released each candidate. The integrated route now finishes with
`initialized_bytes=26192`, `final_bytes=26192`, and
`runtime_allocation_delta=0`. F-authorized mutation allocations remain bounded
mutation points rather than steady-state simulation-loop allocations.

### Observed acceptance results

| Gate | Result |
|---|---|
| Focused F primitives + scene-core authored/runtime/registry + F4C4 adoption | PASS, 98/98 tests (27 + 39 + 22 + 5 + 5) |
| Deterministic aggregate | PASS, 277/277 tests |
| Integration aggregate | PASS, 9/9 tests |
| Normal build | PASS, 20/20 steps |
| Repository policy audit | PASS, 267 files including F4C4 identity/input policy |
| `zig build check` | PASS, 57/57 steps and 527/527 tests |
| `zig build test-full` | PASS, 64/64 steps and 638/638 tests |
| Physical GPU smoke | PASS, D3D12/DXIL, 22/22 steps, one indexed-instanced draw |
| F-backed `integrated` scripted route | PASS, 2,400 frames, F identity/lifecycle/transform plus handshake/IK |
| `handshake-ik` scripted route | PASS, 720 frames, nominal/mirrored/perturbed cycles |
| `environment` scripted route | PASS, 720 frames, 22/22 steps |
| Documentation audit | PASS, 46 required files, 42 Markdown files, 108 local targets |

## Remaining boundaries

- **F4C5:** build/test/check modularization and development-gate topology.
- **F4D:** independent composition proof.
- **F4E:** prompt-era naming, normative/history separation and provenance/archive cleanup.

F4C4 does not introduce an ECS, change F schema/versioning, move character
internals into RuntimeEntity, redesign physics/renderer/backend/application,
create a generalized world/level system, implement gameplay, retire demos,
rename assets, archive evidence or begin downstream features.
