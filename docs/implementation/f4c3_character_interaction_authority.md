# F4C3 Character and Interaction Runtime Authority Hardening

Date: 2026-08-31

Status: **IMPLEMENTED / AWAITING OWNER REVIEW**

F4A, F4B1, F4B2, F4C1, and F4C2 are owner-approved. F4 overall is not
accepted. F4C4, F4C5, F4D, and F4E have not begun.

## Scope and starting gate

F4C3 began only after the required gate established:

| Gate | Observed result |
|---|---|
| HEAD | `efa584b3b55017eae78e82df27f88d4164acfb2f` |
| Branch | `master` |
| Upstream | `origin/master` at the same commit |
| Ahead / behind | `0 / 0` |
| Worktree | Clean |
| Compiler | Zig `0.16.0` |
| F4C2 boundaries | Renderer, application, copied-frame, evidence-writer, and four-line `GpuDemo` alias present |
| Baseline repository audit | Passed for 262 files |

This work changes runtime mutation authority only. It does not migrate legacy
character identity, adopt `RuntimeScene`, introduce an ECS, redesign physics,
animation, interaction semantics, SDL/GPU rendering, platform actions, build
taxonomy, assets, canonical data, or evidence routes.

## Pre-F4C3 character authority inventory

Before F4C3, all 28 semantic fields of public `CharacterInstance` were public.
Any importer could write those fields without invoking the methods that
restore solver locals, recompute pose/appearance, synchronize presentation,
rebind equipment, update derived properties, preserve interaction ownership,
or validate time and rendering keys.

| State family and fields | Before owner and lifetime | Before writers/readers | Invariant and bypass risk | F4C3 decision |
|---|---|---|---|---|
| Allocation/lifetime: allocator implicit in child owners | Aggregate lifetime from `init` to `deinit` | Initializers and teardown | Every acquired pose/animator/anatomy/loadout allocation must have one cleanup path | Private `CharacterState`; façade owns inline storage and delegates lifetime |
| Legacy identity: `id` | Character lifetime | Initializer; render sorting, interaction, equipment, diagnostics read it; tests wrote it | Nonzero, stable, unique within submitted set; direct writes bypass uniqueness | Private; `id()`/`read()` only. Test-only duplicate injection remains explicit. F4C4 owns migration. |
| Immutable definition views: `definition`, `shared_animations` | Borrowed for character lifetime | Initializer; all character domains read | Tokens, skeleton, visuals, clips and machine must remain compatible | Private borrowed views; copied `definitionView()` and `animationDefinitionsView()` |
| Pose/appearance/anatomy: `character` | Character lifetime | Animation, procedural, morphology, IK, equipment binding and tests wrote/read nested runtime | Local/world pose, appearance and anatomy must be reevaluated in order | Private; const `humanoidView()` plus domain commands and value snapshots |
| Animation: `animator` | Character lifetime | Character methods and tests directly read/mutated | Machine state, playback, blend poses, event cursor and compatibility token move together | Private; state-change/advance/sample commands and scalar/event/metric reads |
| Procedural pose: `procedural` | Character lifetime | Character tick; tests and diagnostics read | One fixed-tick update and one composition after animation sampling | Private; `proceduralSnapshot()` |
| Arm IK: `right_arm_binding`, `right_arm_ik` | Definition-derived binding for lifetime; application state per tick | Interaction and tests | Restore saved locals before a new solve; one application per tick; no root mutation | Private; target/clear commands, binding value, optional metrics |
| Leg/foot placement: `left_leg_binding`, `right_leg_binding`, `foot_plants` | Lifetime with per-tick locks and saved locals | Character/foot system; tests directly wrote locks | Authoritative ground query, frozen pre-IK target, stable anatomical side, reset/restore ordering | Private; foot-placement command paths and copied snapshot |
| Controller/physics: `controller` | Optional character lifetime | Character step/reset; demos/tests directly read or installed it | Controller owns root physics; world result must synchronize world position, facing, pose, presentation | Private; initialization/step/reset/staging commands and copied controller snapshot |
| Transform/facing/layer defaults and current values: `facing`, `default_facing`, `world_position`, `default_world_position`, `actor_layer`, `default_actor_layer` | Character lifetime | Controller, reset, staging, demos, presentation, rendering | Finite root, facing reflection, reset baseline, valid ordering layer and derived pose/view sync | Private; validated setters and scalar/read view |
| Draw overrides: `overrides` | Character lifetime; bounded handles | Character and interaction; tests wrote handle internals | Bounded unique handles, valid layers, owned-only cleanup | Private; apply/clear/resolve/count commands and queries |
| Equipment: `equipment_loadout` | Optional character lifetime | Equipment commands, demo staging and render extraction directly reached internals | Transactional candidate validation, anatomy compatibility, owning ID and resolved visuals stay coherent | Private; equipment commands, const loadout view, resolved transform/update commands |
| Properties: `property_bindings`, `resolved_properties` | Optional equipment lifetime | Equipment commands recompute; controller reads | Derived properties must correspond exactly to committed loadout | Private; transactional recomputation and copied resolved snapshot |
| Interaction participation: `interaction_owner_id` | Zero while idle; manager-owned during pair | Manager commands; diagnostics/tests read | One owner, matching animation/presentation claim, owned cleanup | Private; participant commands and scalar status queries |
| Interaction rollback checkpoint: none before | Start-call duration | No owner | Partial participant mutations required manual compensating cleanup | New private animator checkpoint within `CharacterState`; manager owns begin/commit/rollback protocol |
| Presentation: `presentation` | Character lifetime | Character automatic sync, interaction claim and debug input; render code read nested state | Presentation derives from character/controller/interaction truth and cannot become gameplay authority | Private; presentation commands, view query and copied runtime snapshot |
| Passive grounding: `passive_grounded` | Character lifetime | Passive scenario commands, interaction reads | Controller grounding wins for controlled characters; passive value must be explicit | Private; validated command and read view |
| Deterministic time: `simulation_tick` | Character lifetime | Visual tick and reset; demos/tests read or could write | Checked monotonic fixed-tick increment, reset only through lifecycle | Private; `simulationTick()`/`read()` |
| Render bookkeeping: `last_submitted_keys` | Per character, cleared each submission/reset | Character extraction; tests/debug read | Keys describe the latest authoritative submission only | Private; extraction-owned begin/record and optional key query |
| Diagnostics: `metrics` | Character lifetime/reset | Owning paths increment; diagnostics/tests read | Metrics observe but never control behavior | Private; copied `hotPathMetrics()` |

The only public storage field after F4C3 is `opaque_storage`, an aligned byte
array exactly sized for private `CharacterState`. This preserves inline
ownership and the pre-F4C3 allocation model while preventing external code
from naming mutable implementation fields. Zig does not provide field-level
visibility for a public value struct, so this member is ABI storage, not a
supported mutation surface. Repository policy rejects any production access
to `.opaque_storage` outside the two owning authority modules; semantic access
must use the command/read APIs. Unsafe byte rewriting or reflection remains
outside the supported contract, like arbitrary pointer corruption.

## Pre-F4C3 interaction authority inventory

The public `Manager` previously exposed all seven mutable state fields.
Production consumers read terminal state and metrics directly, while a test
directly wrote `next_id`; any importer could also have changed slots,
exhaustion state, the definition, or IK policy.

| State family | Before owner/readers/writers/lifetime | Invariant and bypass risk | F4C3 decision |
|---|---|---|---|
| `definition` | Manager lifetime; manager and scenarios read | Roles/events/presentation/timing must stay fixed for all active slots | Private; copied `definitionView()` |
| `slots` and each `Instance` lifecycle | Fixed manager storage; manager writes, queries/tests read | Capacity, unique pair participation, legal transitions, owned overrides and terminal cleanup | Private; lifecycle commands and const instance observations |
| `next_id`, `ids_exhausted` | Manager lifetime; start writes; overflow test wrote | Nonzero monotonic IDs, terminal max value issued once, no wrap | Private; `maximumIssuedId()`; test-only setter for overflow injection |
| `metrics` | Manager lifetime; request/start/update/terminal paths write | Read-only observation; no control flow may depend on external mutation | Private; copied `metricsSnapshot()` |
| `last_terminal` | Until next terminal result/reset | Completion/cancellation writes; demos/tests read | Must be the fully cleaned and transitioned terminal copy | Private; const `lastTerminal()` |
| `ik_enabled` | Manager lifetime from constructor | Manager reads; public writes could change active semantics | Private constructor-selected policy |
| Participant locks/animation/view/IK/overrides | Character-owned state coordinated by manager | Manager invoked public character mutators independently | Start must be all-or-nothing; cleanup must affect only owned state | Explicit participant transaction plus narrow character commands |

`Manager` now exposes only aligned opaque inline storage for private
`ManagerState`. No heap indirection or hot-path allocation was added.

## Consumer classification and migration

The audit covered every repository reference to `CharacterInstance`, its 28
former fields, and the seven former manager fields.

| Class | Consumers and result |
|---|---|
| Application/scenario coordination | `demo_application`, playground, integrated, environment, foundation, visual-foundation, modular-body, equipment, mesh-attachment, wardrobe and report routes now invoke commands and copied/const queries |
| Animation system | Mutable animator state remains private to character coordination and `animator`; callers request transition, advance or interaction sampling |
| Physics/controller | Controller mutation remains in `character_controller` through character step/reset/staging commands; demos read copied snapshots |
| Interaction | `interaction_system` uses participant commands and read queries; it no longer reaches character fields and its own state is private |
| Presentation/render extraction | `character_art`, wardrobe presentation, diagnostics, visual truth and submitters use const humanoid/equipment views, copied presentation/runtime values, and existing queue submission commands |
| Tests | Supported behavior uses production APIs; eight files with genuine failure injection or ownership-isolation checks use the conditional `character.testing` or `interaction_system.testing` route |
| Invalid cross-domain mutation | Production direct writes to protected character/manager fields were removed. No production module references either test-only route. |

Nineteen production files changed: the two authority owners and seventeen
consumers. Fourteen existing aggregate-test files changed, one focused public
surface test file was added, and eight tests retain explicit white-box access.

## Character responsibility classification

| Responsibility | Before | After | Disposition |
|---|---|---|---|
| Definition and legacy ID lifetime | Public fields on aggregate | Private borrowed views/ID with read queries | TEMPORARY — F4C4 |
| Initialization, teardown, reset and cross-domain order | Aggregate methods and fields | Façade coordinates private state and domain owners | CHARACTER COORDINATION |
| State-machine transition, sampling, blending and events | Embedded animator publicly reachable | `animator` owns mutable implementation; character delegates | ANIMATION OWNED |
| Procedural spring update/composition | Embedded procedural state publicly reachable | `procedural_motion.State` private and invoked in preserved order | ANIMATION OWNED |
| Pose hierarchy evaluation | Public nested humanoid runtime | Humanoid/pose owner private; const view for extraction | POSE/IK OWNED |
| Arm/leg IK and foot locks | Public bindings/runtime | Solver and foot runtime private; target/result commands only | POSE/IK OWNED |
| Root movement/collision | Public optional controller | Controller owns physics state; character applies result and synchronization | PHYSICS/CONTROLLER OWNED |
| Equipment/loadout and resolved properties | Public optional runtime fields | Equipment candidate transaction and property recomputation behind commands | EQUIPMENT/APPEARANCE OWNED |
| Anatomy, morphology, appearance and breathing | Public nested runtime | Domain commands plus const/copy reads | EQUIPMENT/APPEARANCE OWNED |
| Interaction participation | Public owner field and individual methods | Explicit participant transaction and ownership commands | INTERACTION OWNED |
| Automatic/debug/interaction view selection | Public presentation runtime | Private derived runtime; commands and copied/view reads | PRESENTATION OWNED |
| Sprite/mesh request generation and submitted keys | Aggregate methods/public bookkeeping | Existing queue extraction retained; bookkeeping private | RENDER EXTRACTION |
| Entity registry/RuntimeScene participation | Legacy helper types only | Unchanged | TEMPORARY — F4C4 |

No focused runtime file was extracted. The existing domain types already own
their algorithms; the defect was public reachability. Keeping the coordinator
in one file preserves the established evaluation transaction and avoids
creating pass-through files solely to reduce line count.

## Supported production surfaces

Character commands are grouped by domain rather than a universal command
enum: lifetime/reset; transform/facing/layer; visual tick/controller; animation
state/sample; IK/foot placement; interaction ownership transaction;
presentation; anatomy/morphology/breathing; equipment/properties; override;
and render submission.

Character observations include `CharacterReadView`, identity/transform/time
scalars, copied definition/animation/controller/procedural/foot/property/
presentation/anatomy snapshots, const humanoid/equipment views, IK and hot-path
metrics, interaction status, and resolved render keys/transforms. Const views
borrow character-owned storage and expire when the character mutates or is
destroyed. Value snapshots are detached copies and cannot mutate the owner.

Manager commands are `requestFromIntent`, `startPair`, `updateTick`,
`cancelForCharacter`, `reset`, and `resetPassiveCharacter`. Its read surface
is copied definition/metrics plus const active/terminal/identified instance
observations and scalar counts. The supported root does not return mutable
slots or lifecycle instances.

The conditional `testing` declarations exist only when `builtin.is_test` is
true. They permit named failure/overflow/ownership injection without making
production fields public. Repository policy rejects production references to
`character.testing` or `interaction_system.testing`.

## Transactional interaction lifecycle

Start now has an explicit two-phase protocol:

1. validate eligibility, slot capacity, ID capacity, participants and animation availability;
2. acquire private checkpoints for both participants;
3. reserve ownership, claim role presentation and enter both role animations;
4. construct and validate the active `Instance` locally;
5. discard participant checkpoints through non-fallible commit;
6. publish the manager slot, advance/exhaust the ID and increment start metrics.

Every fallible step precedes publication. `errdefer` rollback restores both
participants from their checkpoints, including animator state, owner,
presentation, overrides and IK state. Once checkpoints are committed, slot and
metric publication is non-fallible. Completion and cancellation retain the
existing order: clear only manager-owned overrides; clear pair IK; restore
fallback animation; release matching ownership; transition lifecycle; copy
terminal observation; vacate slot; increment the relevant metric.

## Evaluation order before and after

The effective order is behaviorally unchanged. The façade adds one delegation
call; it does not reorder operations.

For a normal visual tick, before and after are:

1. checked computation of the next fixed simulation tick;
2. restore prior arm-IK locals;
3. restore prior foot-IK locals;
4. advance/sample animator and publish animation events into the pose;
5. update procedural state and compose procedural pose;
6. advance anatomy breathing when present;
7. publish the next simulation tick;
8. evaluate world pose and appearance;
9. when an authoritative world is supplied, query/apply foot planting, then reevaluate appearance;
10. synchronize derived presentation view;
11. advance appearance and equipment secondary motion;
12. later extract resolved sprite/mesh requests into the existing queue.

Controller stepping remains controller simulation, root/facing copy, world-pose
evaluation, then presentation synchronization. Interaction update remains
participant validation, sequential tick check, shared-time sampling for both
roles, optional shared-target IK, ordered event processing, and terminal
cleanup. These paths retain their existing fixed 240 Hz clock and numerical
behavior.

## Before/after authority matrix

| State family | Before owner | Before external writers | After owner | Supported mutation path | Read surface |
|---|---|---|---|---|---|
| Animation | Public character field / animator | Any importer | Private animator under coordinator | transition, sample, advance/reset | state/time/events/metrics |
| Procedural pose | Public character field | Any importer | Private `procedural_motion.State` | visual tick/reset | copied snapshot |
| Arm IK | Public character fields | Any importer | Private pose/IK runtime | apply/clear target | binding and metrics |
| Leg IK | Public bindings and pose | Any importer | Private pose/IK runtime | foot/interaction coordination | const pose/foot snapshot |
| Foot planting | Public field | Any importer | Private `foot_planting.State` | authoritative-world tick/maintenance/reset | copied snapshot |
| Controller | Public optional field | Any importer | Private controller owner | init/step/reset/stage | copied snapshot |
| Position/facing | Public fields | Any importer | Private coordinator truth | validated setters/controller result | scalar/read view |
| Equipment | Public optional loadout | Any importer | Private loadout/domain owner | init/equip/replace/unequip/rebind/mesh update | const loadout and transforms |
| Properties | Public bindings/resolved set | Any importer | Private derived equipment state | transactional loadout recomputation | copied resolved set |
| Presentation | Public runtime | Any importer | Private derived presentation owner | automatic/input/debug/interaction commands | view and copied runtime |
| Interaction ownership | Public owner ID | Any importer | Private character participation state | manager-facing reserve/claim/release transaction | status/owner ID |
| Simulation time | Public tick | Any importer | Private coordinator clock | checked visual advance/reset | scalar/read view |
| Rendering bookkeeping | Public key array | Any importer | Private extraction state | submission functions only | optional submitted key |
| Interaction slots | Public manager array | Any importer | Private `ManagerState` | manager lifecycle commands | const instance observations/counts |
| Interaction lifecycle | Public slot instances | Any importer | Private `ManagerState` | start/update/cancel/reset | const active/terminal instance |

## Dependency and API metrics

| Metric | Before | After |
|---|---:|---:|
| `character.zig` direct imports | 29 | 30; direct `events` type supports the read-only emitted-event view |
| Public `CharacterInstance` semantic mutable fields | 28 | 0 |
| Public `CharacterInstance` storage fields | 28 | 1 opaque inline storage field |
| Public character methods | 69 | 106; added domain commands/read surfaces and delegates, not a monolithic switch |
| Production consumer files migrated | 0 | 17 plus the two authority owners |
| Production references to test-only routes | 0 | 0, statically enforced |
| Test files using explicit white-box routes | Implicit public access throughout | 8 |
| Public manager mutable state fields | 7 | 0 |
| Public manager storage fields | 7 | 1 opaque inline storage field |
| Public manager methods | 16 | 19; copied definition/metrics/terminal observations added |
| External manager state writes | At least one direct ID-counter write; all seven fields writable | 0 supported; overflow injection is test-only |
| New focused runtime modules | 0 | 0; existing domain owners were sufficient |
| New per-instance or steady-state allocation | 0 | 0 |

The increased façade method count is intentional and bounded: callers no
longer acquire an entire mutable aggregate merely to perform one operation or
read one result. Import fan-out increased by one only because the emitted
animation-event read surface names the existing `events.EmittedEvent` type.

## Build and static-policy changes

`build.zig` adds only the existing `events` module as a dependency of the
character module. No module graph, gate taxonomy, or test taxonomy was
modularized. `tests/runtime_authority_tests.zig` is imported by the existing
deterministic aggregate.

The repository checker now fails when production source references either
white-box test route, when private `CharacterState`/`ManagerState` becomes
public, when raw state accessors become public, or when the opaque façade
contracts disappear. It also rejects direct `.opaque_storage` access outside
the character and interaction authority owners, closing Zig's otherwise
public field-level escape hatch for repository production consumers. Existing
stable-ID submission policy was updated only to recognize the new `id()`
query spelling.

## Validation

Observed during implementation:

- Zig version gate: `0.16.0`.
- Focused deterministic, presentation, wardrobe, visual-geometry,
  environment, visual-foundation, integration and stress graph: 400/400 passed.
- Aggregate `zig build test`: passed, including deterministic and canonical-human groups.
- Repository audit: passed for 263 files, including the F4C3 authority rules.
- Normal application build: 20/20 steps passed after production consumer
  migration.
- Static acceptance (`zig build check`): 55/55 steps and 522/522 tests passed.
- Full acceptance (`zig build test-full`): 62/62 steps and 633/633 tests passed.
- Physical GPU smoke: 22/22 steps passed on Direct3D 12/DXIL; the readback
  observed two instances in one indexed draw with the expected pixels.
- Documented executable routes passed for the 600-frame controller sequence,
  720-frame handshake-IK sequence, 2,400-frame integrated sequence, and
  720-frame environment sequence.
- The final documentation-link and diff-hygiene checks are recorded in the
  owner-review report.

## Identity and deferred boundaries

Legacy `character.EntityId`, `EntityIdAllocator`, and `EntityRegistry` remain.
No F `EntityId`, `EntityHandle`, `RuntimeScene`, scene-core command, hierarchy,
snapshot or publication adoption occurred. The opaque façade deliberately
prevents new public field authority while leaving identity replacement and
scene-core lifetime integration to F4C4.

Remaining debt is separated as follows:

- **F4C4:** adopt accepted F/scene-core identity and lifetime boundaries and resolve broader platform/domain action ownership.
- **F4C5:** modularize the large build/test/check graph.
- **F4D:** prove the hardened production components in an independent composition.
- **F4E:** clean historical naming, provenance and retained evidence only after the architectural work is accepted.

## Current state

```text
F4A   OWNER-APPROVED
F4B1  OWNER-APPROVED
F4B2  OWNER-APPROVED
F4C1  OWNER-APPROVED
F4C2  OWNER-APPROVED

F4C3  IMPLEMENTED / AWAITING OWNER REVIEW

F4C4  NOT BEGUN
F4C5  NOT BEGUN
F4D   NOT BEGUN
F4E   NOT BEGUN

F4     NOT ACCEPTED
```

Post-F4 feature fan-out remains blocked pending owner acceptance of the full
F4 track.
