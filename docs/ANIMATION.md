# Animation System Contract

## Authoritative data flow

Animation is deterministic CPU work and follows one path:

```text
per-character animator state
-> immutable clip sampling into local Transform2D values
-> component-space transition blending
-> existing Pose.evaluateWorld hierarchy traversal
-> existing socket and attachment evaluation
-> existing SpriteBatch
-> existing SDL GPU indexed-instanced draw
```

Clips never evaluate world matrices, mutate skeleton rest transforms, write sprite instances, or own renderer state. Character-world position remains independent physics-root state. Every authored visual-height change targets the pelvis rather than the root semantic, so idle and walk cannot accumulate world displacement.

## Immutable clip layout

The authored library owns eight contiguous `ClipDefinition` records. Each clip owns contiguous arrays for its fixed bone-track mapping, bone tracks, translation keys, rotation keys, scale keys, and typed events. Individual keys, tracks, and events have no allocation. A clip records a stable `ClipId`, inline identifier and debug name, duration, playback mode, the compatible skeleton token and bone count, and immutable slices.

Mutable time, loop counts, completion flags, transition progress, state-entry markers, and event traversal state exist only in each `Animator`. Two animators may share the same definitions without sharing mutable playback data.

Prompt 7 character instances borrow the same immutable clip and state-machine slices through non-owning views. Each instance still allocates its own source/destination pose scratch and event storage. Moving a scene wrapper cannot invalidate these views because their identity and compatibility derive from the stable underlying definition allocations, not the wrapper address.

Authored input is accepted only when keys are strictly increasing within each component track. Duplicate timestamps and unsorted keys are errors; the loader does not reorder authored input. Events are nondecreasing so multiple typed events may deliberately share a timestamp while retaining authored order. Event identifiers are unique within a clip.

## Component sampling

Track sampling uses bounded binary search. A missing component track preserves that component from the supplied source pose. A missing bone track preserves the complete source transform. The animator uses skeleton rest locals as its source/default pose.

Boundary behavior is explicit:

- Before the first key, hold the first value.
- At an exact key, use that key's value.
- After the final key, hold the final value.
- A one-key component track holds its value for the whole clip.
- Direct one-shot sampling beyond duration holds the final pose.
- Direct looping sampling beyond duration wraps; direct sampling at exactly duration uses the authored endpoint.
- Negative or non-finite sample time is rejected.
- Source and output overlap is rejected for the public source-pose sampler.

Translation and scale use component-wise interpolation. Rotation is stored in radians, follows the shortest signed arc, and wraps to `[-pi, pi)`. Segment interpolation comes from the left key: step holds the left value, linear uses `t`, and smooth uses `t^2 * (3 - 2t)`. Matrices are never interpolated. Finite zero and negative scale remain supported consistently with `Transform2D`.

## Playback and events

The caller supplies deterministic delta seconds. The animator never reads a wall clock. Both the preserved animation demonstration and controller gameplay now advance from the authoritative 240 Hz fixed clock: a deterministic `1/60`-second displayed frame executes four animator updates of exactly `1/240` second. A zero-tick rendered frame advances animation zero times, a multi-tick frame advances it once per physics tick, pause advances it zero times, and single-step advances it exactly once. Render interpolation never calls animator update.

Looping time uses checked direct quotient/remainder arithmetic rather than simulation microsteps. Exact arrival at duration increments the loop count and produces local time zero. At most eight loop boundaries may be crossed by one update. A ninth returns `error.EventTraversalLimitExceeded` before playback state changes or events are emitted.

Event traversal uses `(previous_time, current_time]`. Time-zero events fire on state entry and at each loop boundary. An exact-duration event belongs to the ending cycle and fires before the next cycle's time-zero events. Multiple-loop output preserves cycle order, timestamp order, and authored same-time order.

Events are written to the animator's preallocated fixed-capacity storage and exposed as a borrowed immutable slice. No global event list exists. An exact-capacity write succeeds. Overflow returns `error.EventOutputOverflow`, preserves already written events for diagnosis, and leaves playback uncommitted; the caller resets the buffer before retrying. The production capacity is 64 records.

The fixed event types are left/right foot contact, hand contact, hand release, interaction complete, and body-part layer change. A layer event stores a fixed attachment semantic, `u16` layer value, and restoration policy. Prompt 4 emits this data but does not mutate immutable attachment definitions or coordinate cross-character ordering.

Walk foot-contact records remain semantic animation events. Prompt 6 samples a deliberate contact-relative visual curve only while physical controller state makes walking relevant; a contact cannot ground the character, snap a root, create a landing event, or modify collision. During idle, jump, rise, and fall, walk amplitude fades or its output is immediately suppressed as documented in `docs/SECONDARY_MOTION.md`.

After every fixed animator update, procedural composition modifies only that tick's mutable local pose: the combined walk/landing translation is added once to the root bone, and acceleration-driven follow-through is added once to head rotation. The immutable skeleton rest transforms and clip keys are never changed. A repeated composition for the same simulation tick is rejected, and the next animator update always recreates the authored pose before the next procedural composition.

## Blending and states

Pose blending is local-component blending: translation linear, rotation shortest-arc, and scale component-wise. Weight must be finite and inside `[0, 1]`; it is not clamped. Output may not overlap either input. Weight zero and one reproduce the respective endpoints.

The immutable state-machine definition has eight states and two ordinary transitions. Idle is initial. Idle-to-walk and walk-to-idle each blend for 0.30 seconds. Destination playback begins immediately, source playback continues while it contributes, and source events are emitted before destination events for each update. A request for the current state is a no-op. A request during an active transition is rejected with `error.ActiveTransitionRequestRejected`; explicit `enterState` deliberately replaces playback and resets entry/completion state. Zero-duration transitions enter the destination immediately.

One-shots sample and expose their final pose, emit final crossed events, and mark completion once. Fallback begins on the following update, so the final pose cannot be skipped. Jump start falls back to rising over 0.12 seconds. Landing and independently played handshake roles fall back to idle over 0.20 seconds. Re-entry resets completion and time zero.

## Authored library

| Clip | Duration | Mode | Authored content |
| --- | ---: | --- | --- |
| Idle | 2.00 s | Looping | Pelvis breathing, torso scale/rotation, small bilateral arm motion |
| Walk | 1.00 s | Looping | Alternating thighs/shins, opposing arms/forearms, pelvis-height curve |
| Jump start | 0.40 s | One-shot | Pelvis compression and bilateral knee/hip preparation |
| Rising | 0.60 s | Looping held motion | Extended legs and raised arms |
| Falling | 0.60 s | Looping held motion | Bent legs and arm pose measurably distinct from rising |
| Landing | 0.50 s | One-shot | Compression and visual recovery |
| Handshake role A | 1.60 s | One-shot | Right-arm extension on the shared handshake timeline |
| Handshake role B | 1.60 s | One-shot | Receiver right-arm extension on the shared handshake timeline |

Walk emits anatomical left-foot contact at `0.00` seconds and anatomical right-foot contact at `0.50` seconds. Prompt 10 consumes these only as visual stance intent: they cannot set physical grounding, support, velocity, position, or collision. A current authoritative-world ground query and controller-grounded gate are separately required, acquisition blends over `0.10 s`, and facing never swaps anatomy. Both handshake roles contain matching hand contact and layer records at `0.60`, hand release and restoration data at `1.20`, and interaction complete at `1.50` seconds. Prompt 8 validates those paired semantic times at definition construction and collapses them into one shared runtime event stream; participant animators do not emit duplicate paired events while coordinated. Role B uses its anatomical right arm because character-local left facing reflects that arm toward the initiator. The clips remain authored inputs rather than constraint authority: Prompt 9 samples them first, then optionally blends mutable shoulder/elbow rotations toward the interaction-owned shared target. Clip data, root alignment, and motion warping remain unchanged.

## Demonstration and allocation contract

Run:

```powershell
zig build run -- --frames 360 --demo animation
```

Frames 0-59 show idle. Frame 60 requests the 0.30-second idle-to-walk transition. Walk continues through frame 299, spanning multiple cycles. Frame 300 requests the 0.30-second walk-to-idle transition, which completes at frame 317; the remainder is idle.

The animation definition, animator buffers, pose, skeleton, sockets, and attachments are initialized from one fixed buffer. The loop records the allocator position around animator update, hierarchy evaluation, socket reads, and attachment submission. All remain unchanged after initialization. Clip sampling, blending, event traversal, state transitions, and animator update contain no allocator call. Animation state changes create no GPU resource and all 15 page-zero attachments remain one sprite range and one indexed-instanced draw.

## Side and front pose interpretation

Prompt 24 does not add front/side gameplay state machines. Each character still owns one animator and one authoritative animation state. The presentation policy reads that fixed-tick state together with controller grounding/velocity: grounded idle chooses front, while locomotion, dash, airborne states, landing, and the interaction-owned handshake choose side.

Side art consumes the ordinary reflected appearance transforms. Front art builds a bounded projection from the same local pose, retaining root position, vertical animation, breathing/deformation, and attachment secondary transforms while applying view-authored arm rest offsets. It never advances playback, changes a clip, or writes physics. The 360-frame character-presentation route exercises idle/walk blending, jump/rise/fall/land, both handshake roles and IK, and ordinary idle restoration with one shared animation timeline per character.
