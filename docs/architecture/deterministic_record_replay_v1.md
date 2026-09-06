# Deterministic record/replay V1

Status: normative RR1 V1 contract from corrected commit
fb0526ddbd268be0befef9694b1b1dc03ad7fb68. Integration preserves its protocol,
versions, bytes and goldens. The original candidate and corrective pass remain
separate commits; their implementation and validation records are retained in
the [implementation evidence](../implementation/rr1_record_replay.md).

Corrective design provenance: this contract was revised before corrective
production code, from base cb60fc9a9b24ba7d69578ffc721948e9b00de8fd.
At that preflight, candidate e779f96004573921417165d2f3b25e731ca0913f had not
been owner-accepted, merged or published; the read-only remote check found no
RR1 branch and remote master remained at base. The owner explicitly authorized
revising those candidate bytes and goldens. The subsequent publication and
integration do not permit another silent V1 rewrite. Incompatible published
bytes/domains require a new identity. No migration is provided.

## Existing authorities and ownership

The reusable core imports only standard library and foundation. The external
proof uses the real CharacterIntent, CharacterController, CollisionWorld,
240 Hz fixed-step contract, foundation derivation, and supported RuntimeScene.
It keeps one static scene snapshot acquired at initialization; per-tick
snapshot acquisition/publication allocates and is outside RR1. The controller
remains the sole moving simulation authority. Core and adapter have no SDL,
GPU, renderer, sandbox, wall-clock, filesystem or evidence ownership.
Modular build registration remains in the existing build helpers.

The reconciliation source was not found in the repository or the searched
Documents tree. This correction follows the authoritative record/replay and
deterministic-tooling excerpts supplied in the corrective request: initial
state + RNG seed + input stream + scene events, event logs, named checkpoints,
and deterministic fingerprints. Screenshots and JSON remain future clients.

## Exact timeline and phases

The durable interval is [start_tick, start_tick + tick_count). Both are explicit
u64/u32 values, and their sum must fit u64. A valid empty interval has no
commands, events, fingerprints or named checkpoints and still verifies initial
state. Each nonempty tick has exactly one complete command and one fingerprint.
Missing, duplicate, decreasing and out-of-interval command ticks fail; no
implicit neutral/default command exists. Recorder capacity is an upper bound,
not a promise that every capacity slot was recorded.

For authoritative tick N:

1. Obtain its complete semantic command after application mapping and pending
   edge consumption.
2. Apply zero or more accepted external causal events in recorded ordinal order.
3. Advance existing deterministic simulation exactly once.
4. Collect derived semantic observed events from the completed production step.
5. Compare the actual observed-event list against the recorded list.
6. Compute and compare the mandatory post-tick state fingerprint.
7. Evaluate named checkpoints attached to that completed state.
8. Permit tick N+1 only if all required verification succeeded.

The player requires observe(actual_events) before verify(actual_fingerprint).
observe stores the first event mismatch without terminating that completed-tick
verification, so the caller can then compute the fingerprint and obtain
combined diagnostics from verify. next never advances through that mismatch.
Calling verify before observe fails with VerificationPending.

A post-tick mismatch leaves simulation after the executed tick N and blocks
N+1; RR1 does not roll back N. Observations and names never drive simulation.
Automatic fingerprints occur after EVERY tick in both core and proof; there
is no sparse mode. First divergence means the earliest mismatching completed
tick among these event/fingerprint observations, not a claim about unobserved
systems or earlier causes which have not changed observed deterministic state.

## Three separate streams

Command channel 1/schema 1 retains five-byte CharacterIntent: finite IEEE f32
axis in [-1,1], then bits 0..4 for jump pressed/held/released, dash pressed,
interact pressed. Upper flag bits are zero. No physical input, render delta,
interpolation alpha or device identity is durable causal data.

Causal channel 1/schema 1 registers event type 1/schema 1, SetMaximumRunSpeed:
one finite f32 in [0.5,20] metres/second. Multiple accepted assignments execute
sequentially before the step. Stable encoded ordinals start at zero and must
be contiguous within EACH stream and tick. Repeated event types are legal;
duplicate/skipped/decreasing ordinals and ordinal overflow are errors.

Observed channel 1/schema 1 registers these production StepResult observations:

| Type/schema | Meaning | Canonical payload |
| --- | --- | --- |
| 1/1 | JumpAccepted | u8 source: grounded=0, coyote=1, buffered=2, air=3 |
| 2/1 | DashStarted | empty |
| 3/1 | Landed | finite nonnegative f32 landing impact speed |

The adapter emits flagged results in this stable semantic order: jump,
dash, landing. This is the adapter's canonical order of a completed StepResult,
not an invented sub-tick chronology (buffered jump can occur after collision).
It calls no second event simulation. Other StepResult diagnostic/transition
flags are outside the supported observed channel. State fingerprints remain
complete for the supported proof regardless of this event selection.

Channels and event type registries have explicit nonzero IDs/versions and
bounded payload validators. Registry type IDs are strictly increasing and
unique; unknown required types/versions fail during recording/load.
Playback actual events are compared rather than reinjected. A mismatch reports
completed tick, ordinal, category, and optional expected/actual bounded event
(type/schema, tick, ordinal, canonical payload). Missing and extra events have
one absent side. Categories distinguish missing, extra, wrong type, schema,
payload, order and tick. An event matching another expected position is an
order mismatch. The first event mismatch and same-tick state/named digest
mismatches are retained together when present. Further calls cannot replace
them or execute another tick.

## Named checkpoints

Names use 1..32 ASCII bytes: [a-z][a-z0-9_]*, lowercase only. There is no
normalization, Unicode or allocation. The fixed identifier owns its length
and initialized byte buffer. Maximum 32 names per recording and 8 per tick.
Names are globally unique and ordered by (completed tick, bytewise name);
multiple distinct names at one tick are valid. Malformed identifiers, capacity
exhaustion, duplicates and incorrect ordering return explicit errors.

A durable marker stores its name, completed tick and expected state digest.
Recorder markers obtain that tick's mandatory fingerprint; decoder requires
the encoded marker digest to equal that fingerprint. Playback compares it
against the actual completed state after event/fingerprint comparison.
Names are non-causal and cannot replace per-tick fingerprints. Initial-state
identity is a separate pre-simulation authority.

The proof fixture marks the first accepted jump as jump_accepted, the accepted
speed assignment as speed_changed, and the completed run as final_state.
Names are chosen from real proof conditions. Additional names on a shared tick
must follow canonical lexical order.

## Canonical container

All integers and IEEE binary32 words are little endian. Struct memory, padding,
pointers and handles are never serialized. Every float must be finite; encoding
normalizes either zero to positive zero and decoding rejects negative zero.
IDs use u32/u16 pairs, UUIDs use validated non-nil foundation canonical bytes,
semantic versions use three u32 components. V1 has no optional record kinds.

Header fields in exact order (212 bytes):

| Field | Encoding |
| --- | --- |
| corrected candidate magic | eight bytes: RR1TICK followed by 0x01 |
| container format / replay protocol | u16 1 / u16 1 |
| tick rate / start tick | u32 240 / u64 |
| derivation framing / reserved | u16 1 / u16 zero |
| root seed | 16 bytes |
| generator UUID / semantic version | 16 bytes / three u32 |
| algorithm UUID / semantic version | 16 bytes / three u32 |
| initial schema / envelope length | u32 ID, u16 version, u16 length |
| initial envelope digest / recreated state digest | 32 bytes each |
| command / causal / observed channel identities | three u32/u16 pairs |
| named-checkpoint encoding version | u16 1 |
| tick / causal / observed / fingerprint / named counts | five u32 |

Header is followed by the initial envelope, contiguous tick groups and a
32-byte artifact digest covering every preceding byte. Record prefix is
kind u8, tick u64, payload length u16 (11 bytes). Within a tick:

| Kind | Record | Payload |
| --- | --- | --- |
| 1 | exactly one command | channel-defined bytes, <=64 |
| 2 | zero or more causal events | ordinal u16, type u32/schema u16, <=64 value bytes |
| 4 | zero or more observed events | ordinal u16, type u32/schema u16, <=64 value bytes |
| 3 | exactly one fingerprint | 32-byte deterministic digest |
| 5 | zero or more named checkpoints | name length u8, name bytes, 32-byte digest |

Record sequence and dense ordinals make empty stream boundaries unambiguous.
All record ticks must equal their containing tick. Header counts must equal
parsed counts. No trailing bytes, unknown kind, unsupported version, invalid
type, malformed payload, missing command/fingerprint, or excess record is
accepted. Footer integrity is mandatory and never bypassed to reach playback.
Structurally valid alternate recordings must be encoded/resealed and loaded
normally before semantic divergence is tested.

## Hashes and initial-state proof

Existing foundation hash framing and domains remain: replay.initial.v1 over
schema identity and envelope; replay.contributor.v1 over contributor identity
and canonical fields; replay.state.v1 over strictly increasing versioned
contributor records; replay.artifact.v1 over container bytes before its footer.
Golden vectors cover each domain, revised container including observations
and markers, and foundation-derived key. No new hashing authority is added.
These domain meanings remain unchanged; only the unaccepted container changes.

Derivation framing 1 is the current foundation.seed_child.v1 /
foundation.key_child.v1 contract. Root seed, generator/algorithm UUIDs and
versions are persisted and checked. The proof retains seed
00112233445566778899aabbccddeeff, generator 0195d5b8-4100-7000-8000-000000000001 and algorithm
0195d5b8-4100-7000-8000-000000000002, both version 1.0.0.
Stable derivation keys rr1.controller and speed choose initial movement speed.

Initial schema 1/1 remains a four-byte finite spawn X in [-50,50]. Adapter
bootstrap recreates Y=1.05, right facing, default controller configuration,
one static floor and persistent scene anchor, then verifies envelope and full
state digests before simulation. Contributors 1/1 bootstrap, 2/1 controller,
3/1 properties retain their existing bytes and explicit fields:
configuration/spawn/reset, collision world, root seed/context/key, static
scene identity/lifecycle/enabled/visibility/local/world transforms/origin,
all 20 controller State fields and all four gameplay properties.
No renderer state, pointers, padding, handles, unused capacity, scene
publication/cache bookkeeping, frame clock or diagnostics enter fingerprints.
Absent scene hierarchy/assets/extensions/camera/levels are checked at init.
Scene state and collision world remain immutable; no allocating per-tick read
or snapshot is introduced.

## Capacity, lifetime and errors

Caller-approved capacities are explicit for ticks, causal events, observed
events and names. Limits: 65536 ticks, 65536 events per stream, 8 events per
stream per tick, 32 names total, 8 names per tick, 32 name bytes, 64 command or
event value bytes, 1024 initial bytes and 16 fingerprint contributors.
Types are limited to 8 per event channel. Storage uses one fixed tick array,
separate fixed event arrays and one marker array, not maximal event arrays in
every tick. Exact memory cost is capacity times the supported target's
sizeOf(Tick/Event/NamedCheckpoint), plus copied envelope and session metadata;
the implementation evidence records measured sizes and proof allocations.

Initialization/load may allocate, with complete failure cleanup. All per-tick
command access, causal injection, observation collection/comparison,
fingerprints, marker evaluation, divergence construction and cursor advancement
must make zero allocation/resize/remap attempts. Encoder uses caller scratch;
writer failures and caller flush failures must propagate. No disk-path owner
is added. Capacity checks and all record validation precede recorder storage
mutation. The proof preflights bounded output capacity before stepping.
Callers must stop on any simulation/recording error.

Before simulation: load rejects corruption/framing/count/interval/type/schema
errors; Player.init rejects protocol/seed/initial mismatch. Before a tick:
recorder preflight rejects closed/full sessions, wrong tick, invalid commands,
causes or markers; Player.next rejects pending or latched failures. After a
tick: actual observed-event/fingerprint/marker mismatches are latched and block
the next tick. A failed tick is not rolled back or silently dropped.

Session storage has one owner; its fields are read-only outside methods and a
finished session is immutable while borrowed. Channel registries and their
validators must remain immutable and outlive every session using them. Player holds a bounded tick view
and borrows session lifetime. The proof releases its retained snapshot before
scene destruction. Validators must be deterministic, headless and allocation
free. Scratch must not alias session or writer storage.

## Exact claim and future clients

Given identical initial state and complete tick-indexed command/causal streams,
recorder tick-batch grouping and playback invocation batching cannot change
artifact or supported simulation state. Tests directly group an already
specified dense tick stream. This is NOT arbitrary physical-input or
render-frame invariance: the existing clock clamps substeps and can discard
time. Playback independently ignores live input, frame delta and interpolation.
Exact proof equality is validated with the pinned Windows x86_64 Zig 0.16.0
build in Debug, ReleaseSafe and ReleaseFast, not across CPUs/platforms/compilers.

Arbitrary sandbox, animation, interaction, specialized scene, equipment,
world-time and whole-engine replay are not integrated. Future Engine Lab or
gameplay clients need their own complete bootstrap, channels and contributors.
Screenshots and JSON are optional future evidence sidecars correlated by
artifact digest, protocol identity, named checkpoint, completed tick and
state digest. They never control playback or replace state mismatches.
The core knows nothing of image/JSON formats, render frames, directories or
evidence manifests. No screenshot, JSON capture, UI, save-game, rewind,
rollback, networking, compression, editor, physics, secondary-motion,
projectile, AI, morphology or general event bus work belongs to this correction.
