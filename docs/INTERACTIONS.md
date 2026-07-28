# Deterministic Paired Interactions

## Definition and roles

`interaction.Definition` is an immutable value. The fixed-position handshake
has type ID `1`, debug name `fixed_position_handshake`, and exactly two stable
roles: initiator and receiver. The initiator is the entity whose real
`interact_pressed` edge created the request; array order never assigns a role.
Both roles use their dedicated 1.60-second one-shot state and their anatomical
right-hand socket. An entity cannot fill both roles, zero and missing IDs are
rejected, and an active instance never stores participant pointers.

Prompt 27 adds an immutable validated `PresentationDefinition` to the
interaction definition. It contains:

- one optional presentation view for each semantic participant role;
- a flag controlling whether ordinary automatic view selection is suppressed
  while the interaction owns a claim;
- one typed `OcclusionProfileId`.

The production handshake declares side/side views, suppresses automatic view
selection, and selects `handshake_right_hand_contact`. A separate definition
test proves that front/front with no occlusion profile is valid; view policy is
therefore definition data rather than a manager constant.

Construction resolves each role state to the requested clip, requires equal clip duration within `0.000001 s`, and validates exactly one contact, release, and complete event in both clips. Role times must agree within `0.000001 s` and satisfy contact < release < complete <= duration. The definition then owns one shared event stream:

| Semantic | Authored time | Elapsed fixed tick |
| --- | ---: | ---: |
| Contact | 0.60 s | 144 |
| Release | 1.20 s | 288 |
| Complete | 1.50 s | 360 |

The conversion subtracts at most `0.0001` of one tick solely to remove `f32` authored representation noise before applying the open-closed interval ceiling. A semantic just after that shield advances to the next tick. Clip-local body-layer events remain immutable validation data; coordinated participant animators suppress their clip event buffers, so each shared semantic emits once.

## Storage, identity, and lifecycle

`interaction_system.Manager` contains four inline slots and performs no heap allocation. A nonzero monotonic `u32` interaction ID is reserved at commit and never wraps. Each instance records type, role-to-entity mapping, lifecycle, authoritative start tick, elapsed ticks, phase, three consumed bits and event counts/ticks, up to four participant-qualified override handles, contact socket measurement, and cancellation reason. The shared definition can be reused by simultaneous AB and CD instances.

Legal lifecycle edges are:

```text
inactive -> requested -> active -> completing -> completed
                     \-> cancelled
             active --------------------------> cancelled
             completing ----------------------> cancelled
```

All other edges return `IllegalInteractionLifecycleTransition`. Terminal data remains inspectable until its slot is reused, but the slot is immediately available and repeated updates do nothing.

Each `CharacterInstance` contains a zero-or-interaction-ID lock. Startup validates both entities and states, reserves A then B, enters role A then role B, prepares the instance, and commits only after every stage succeeds. Injected failures after either reservation and either animator transition restore copied animator state and release both locks. Pool overflow is detected before either participant is reserved. A locked character is ineligible as either initiator or receiver; AB therefore deterministically blocks C-to-B.

## Eligibility and selection

The authored right-hand contact reach is approximately 1.86 m per participant. Fixed-position eligibility uses this inclusive envelope:

- Authored horizontal separation: `3.72 m`.
- Minimum horizontal separation: `3.70 m`.
- Maximum horizontal separation: `3.74 m`.
- Maximum absolute vertical root difference: `0.02 m`.
- Facing: exact face-to-face semantics in the left/right model.
- State: idle or walk before entry.
- Grounding: controller `state.grounded` for controlled characters; explicit `passive_grounded` for controller-less actors.

The left entity must face right and the right entity must face left. Same direction, facing away, equal-X, airborne, jump/rise/fall/landing/handshake state, missing entity, duplicate ID, and existing ownership are rejected. No animation foot event is grounding evidence. No facing or position is changed to manufacture eligibility.

Candidate ranking is lexicographic: smallest absolute error from `3.72 m`, then smallest Euclidean world distance, then lowest stable entity ID. Iteration, pointer, allocation, submission, and hash order have no effect.

## Shared clock and animation sampling

Strategy A is authoritative shared-time sampling. Start leaves both role animators at time zero on the request's simulation tick. For each later fixed tick:

```text
elapsed_ticks += 1
shared_time = min(1.60, elapsed_ticks / 240)
sample initiator clip at shared_time
sample receiver clip at shared_time
consume shared definition events for newly reached elapsed ticks
```

There is no raw render delta parameter. A zero-substep frame calls no interaction update; every one- or multi-substep frame calls once per fixed tick. Pause therefore freezes the pair, single-step advances exactly one tick, render interpolation cannot advance it, and reset cancels all occupied slots. Tests group identical ticks into regular one-step, eight-step, and mixed zero/one/multi-step render schedules and require identical event ticks, counts, terminal state, locks, and contact measurement.

Ordinary animator advancement is skipped while locked. Completion enters both documented grounded motion fallback states and releases both locks on the same fixed tick. Cancellation before or after contact does the same without emitting complete.

## Presentation ownership, contact ordering, and cleanup

Startup claims each role's requested view only after participant validation
and lock reservation succeed. Completion, cancellation, reset, and every
startup rollback path release the claims. Interaction view authority has
precedence over debug and automatic presentation policy.

At contact, the typed `handshake_right_hand_contact` profile creates exactly
three participant-qualified handles:

- Initiator right hand: interaction layer `+3`.
- Receiver right hand: interaction layer `+2`.
- Initiator right forearm: interaction layer `+1`.

Both torsos remain at neutral interaction layer zero, so actor ordering remains
independent while the initiator hand is above the receiver hand and its
forearm is above the receiver torso. Equipment bound to a canonical anatomy
semantic inherits that semantic's interaction layer while retaining its own
garment/body layer. A glove therefore follows its actual hand without an item
ID, preset name, or outfit-specific branch.

Release clears exactly the profile-owned handles in reverse order. Completion
and cancellation repeat the owned-handle cleanup safely. Handles that predate
the interaction, including another override on the same character, survive. A
contact-time capacity failure clears any partially added interaction handles,
cancels both roles, and preserves the seven pre-existing handles used by the
adversarial test.

Ordinary side presentation remaps both arm rests for a readable profile.
During an interaction-owned side view, Prompt 27 preserves the participating
right-arm animation/IK plane while retaining the ordinary profile treatment
for the other arm and the legs. This is a downstream visual projection; it
does not change the authoritative socket, IK target, animation clock, or root.

## Fixed-position and physics isolation

The manager never writes `world_position`, controller position/velocity, facing, collision AABB, grounded state, or support ID. It applies no impulse and creates no character collision. Socket measurement reads evaluated world poses only. A separate controlled-character test executes identical zero-input controller sequences with and without an active handshake and requires position/velocity agreement within `0.000001`, plus exact grounding and support agreement.

The default `Manager.init` route preserves Prompt 8 with no arm constraint. `Manager.initWithIk` enables Prompt 9's interaction-owned shared midpoint and timeline weight. It consumes evaluated pre-IK sockets, delegates mathematical solving to the independent analytical module, and writes only mutable visual-pose rotations. Root correction and motion warping remain absent. Full details and evidence are in `docs/IK.md`.

## Demonstration evidence

Run:

```powershell
zig build run -- --frames 720 --demo handshake --scripted-input
```

The route waits visibly in an eligible idle arrangement, holds one real interaction press across five render frames, completes, stages the same IDs in the mirrored idle arrangement outside any interaction, then issues a release/new press. Starts occur at ticks 121 and 841. Their contact/release/complete ticks are 265/409/481 and 985/1129/1201. At contact both normalized role times are 0.375. The first socket positions are approximately `(0.000232, 3.452835)` and `(-0.000232, 3.452835)`, separated by `0.000464 m`; mirrored positions negate X and retain the same separation within `0.00001 m`.

Both characters keep 15 page-zero attachments in one global submission set: 30 sprites, one compatible range, one 1,800-byte upload, and one actual `SDL_DrawGPUIndexedPrimitives` call. Interaction initialization and both runtime sessions create zero GPU resources, and request, eligibility, selection, sampling, events, overrides, and completion report zero steady-state allocations.

The separate Prompt 9 route is `zig build run -- --frames 720 --demo handshake-ik --scripted-input`. It preserves the `0.000464 m` nominal pre-IK baseline, reduces nominal post-IK separation to approximately `0.00000018 m`, and reduces the mandatory `3.74 m` perturbed case from `0.019536 m` to approximately `0.00000057 m`. The mirrored result is equivalent, roots remain fixed during every interaction, one draw remains authoritative, and IK creates zero GPU resources.

## Prompt 27 integrated evidence

The focused route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
```

The 2,100-frame production D3D12 route completes three interactions with the
female initiator (entity 2) and male receiver (entity 1), using
`wide_brim_crimson`, `garnet_formal`, and
`ivory_blouse_red_shorts`. Each record includes role views, preset, theme,
start/contact/release/complete ticks, pre/post-IK separation, projected
presentation separation, root invariance, and body/equipment ordering. All
three use side/side only because the production definition requests it, and
all return to front after cleanup.

The route proves the fixed-root eligibility envelope, existing shared clock,
existing arm IK, definition-owned presentation policy, and equipment-aware
occlusion together. It does not add multi-contact solving, a relative-root
constraint, world interaction anchors, or a second renderer.
