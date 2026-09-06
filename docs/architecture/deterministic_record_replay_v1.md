# Deterministic record/replay V1

Status: normative RR1 implementation contract, written before production code.
Base: accepted post-F4 commit cb60fc9a9b24ba7d69578ffc721948e9b00de8fd.

## Observed authorities and design decisions

The inspected base has a 240 Hz `physics/fixed_step.Clock`, exact foundation
seed/key derivation, physical-only platform input, application action mapping
and pending-edge consumption, and the production `CharacterIntent` and
`CharacterController`. `RuntimeScene` owns generic entities. Its publication
mutations clone state; acquiring a snapshot also allocates. RR1 does not alter
these closed authorities. Build modules, engine tests, and aggregate gates
belong respectively to `build/modules.zig`, `tests_engine.zig`, and `gates.zig`.

The reusable `record_replay` module imports only foundation and the standard
library. An external `record_replay_proof` client imports that core, production
controller/collision/fixed-step/intent, and the supported scene-core root.
The core never imports the client, physical input, SDL, renderer, evidence, or
sandbox. There is no new simulation loop: recording and playback call the
same client `step` which calls the existing controller once per tick.

## Data flow and tick phases

A caller recreates initial state and verifies both its canonical envelope and
its full deterministic state digest before beginning a session. Recording
captures the semantic command actually consumed, after action mapping and
`PendingInput.consumeTick`. Exactly one command and zero or one accepted
exogenous event apply before controller step N. A checkpoint is mandatory
immediately after step N. The next command applies to N+1. Start tick is an
explicit u64; ticks are contiguous, and the exclusive end must fit u64.
An empty run is valid and still validates its initial state.

The recorder atomically appends a complete tick only after payload validation
and capacity checks. Callers must stop/discard a session on any simulation or
recording error. It must never be interpreted as a successfully finished run.
The player requires each delivered tick to be verified before delivering the
next, and latches the first mismatch with tick, expected, and actual digests.
An ended player returns no more commands. Live gameplay input and frame delta
are absent from its API. Out-of-band abort/pause may stop consumption.

Internal collisions, landing/jump results, procedural output and animation
contacts are derived outputs; they are never injected as recorded causes.
The proof's accepted external event is a movement-speed assignment approved
by an external caller at a known tick. The scheduler in tests is a fixture,
not a rule in the simulation which could regenerate the event.

## Persistent encoding and compatibility

V1 is a durable byte compatibility promise for this protocol, not a promise
that future engine builds can simulate V1 without the matching adapter.
All multibyte integers and IEEE-754 binary32 words are little endian. Native
struct memory is never encoded. There are no textual strings. IDs are u32
channel/contributor identifiers or existing foundation UUID bytes. UUIDs must
be valid non-nil canonical foundation identities. Versions are explicit.

Header fields in exact order:

| Field | Bytes |
| --- | --- |
| magic `RR1TICK` followed by NUL | 8 |
| format version 1, replay protocol 1 | u16, u16 |
| tick rate 240, start tick | u32, u64 |
| foundation derivation framing version 1, reserved zero | u16, u16 |
| root seed | 16 |
| generator UUID, generator semantic version | 16, three u32 |
| algorithm UUID, algorithm semantic version | 16, three u32 |
| initial-state schema ID, version, envelope length | u32, u16, u16 |
| envelope digest, recreated initial deterministic-state digest | 32, 32 |
| command channel ID/version, event channel ID/version | u32/u16, u32/u16 |
| tick count, event count, checkpoint count | u32, u32, u32 |

Then come the opaque initial envelope bytes and contiguous tick groups.
Each group contains a command record, an optional event record, and a
checkpoint record, in that order. Record framing is kind u8 (1 command,
2 exogenous event, 3 checkpoint), tick u64, payload length u16, then payload.
Checkpoint payload is exactly 32 bytes. Unknown kinds and versions fail
closed; V1 has no optional extensions. No trailing bytes are accepted.
The final 32 bytes are an artifact digest of every preceding byte.

Envelope bound is 1024 bytes; each command/event is at most 64 bytes;
at most 65536 ticks, one command, one checkpoint and one event per tick.
Caller-selected record capacity is at most that bound. Decode validates counts,
lengths, ordering, canonical payloads, checksums, and caller capacity before
returning a loaded session. Truncation and overflow return explicit errors.
Encoding checks total destination size before touching it. The writer API
propagates writer failure; callers own disk paths and atomic file publication.
RR1 introduces no filesystem writes to arbitrary user paths.

A typed channel descriptor (ID, version, maximum size, explicit validation
function) separates persistent byte contracts from domain types. V1's real
adapter command is channel 1/version 1: canonical move-axis f32 bits followed
by one byte whose bits 0..4 are jump pressed/held/released, dash pressed,
interact pressed; upper bits must be zero. Axis must be finite in [-1,1].
Encode changes either zero sign to positive zero; decode rejects negative zero.
Event channel 1/version 1 is a finite positive movement-speed f32 in [0.5,20].
All adapter state floats are finite with zero normalized identically.

## Identity and hashing

Use `foundation.canonical_data.hashDomainSeparated`, including its existing
framing, for all persistent digests. Domains are `replay.initial.v1` (schema
ID/version bytes, envelope), `replay.contributor.v1` (ID/version bytes,
canonical fields), `replay.state.v1` (ordered contributor ID/version/digest
records), and `replay.artifact.v1` (all bytes before final digest).
Stable nonzero contributor IDs must be strictly increasing; duplicate or
out-of-order contributors fail. At most 16 contributors are accepted.
Golden vectors freeze every domain and the proof's derived key.

Root seed, generator/algorithm IDs and semantic versions reuse foundation
`DerivationContext`; derivation framing 1 means the existing
`foundation.seed_child.v1` / `foundation.key_child.v1` contract. Playback
compares the complete expected context and protocol before any simulation.
The proof derives a key with stable keys `rr1.controller` and `speed`; its
first byte selects initial movement speed. No global RNG or call-order stream.

## Proof and initial-state boundary

Initial schema 1/version 1 contains a four-byte spawn X value. Spawn Y is 1.05 metres
and the production collider root is its centre above a floor at Y zero. Other bootstrap values belong
to the versioned adapter: one floor, default controller configuration, right
facing, one immutable persistent scene anchor, and fixed 240 Hz stepping.
Changing bootstrap semantics requires a new adapter/protocol identity.

The client constructs one real RuntimeScene world-persistent anchor, acquires
one immutable snapshot at initialization, and holds it for the session. It
never publishes dynamic controller roots into that static anchor. That would
require an allocation-capable scene publication policy outside RR1. There is
no second character model: the existing CharacterController owns all moving
state, including jump/landing and timer transitions.

Contributors are: 1 bootstrap (envelope, derivation context/key, configuration,
spawn/reset values, collision world and immutable scene semantic identity,
lifecycle, enabled state and transforms); 2 complete production controller
State in explicit field order; 3 current gameplay properties. Previous fields
are included conservatively even when only presentation currently uses them.
Allocation metadata, handles/addresses, capacity slack, scene cache revisions,
publication generation and frame accumulator/alpha are excluded. The anchor
has no parent, children, tags, assets, extensions, overrides, camera or levels;
these absent facts are verified at initialization. Collision and scene state
are immutable for this proof. Derived events do not affect a separate system.
No arbitrary specialized character, animation, IK, equipment, interaction,
world-time, sandbox or full-engine replay coverage is claimed.

## Ownership, errors, and verification

Recorder initialization owns an envelope copy and a fixed tick array; failed
initialization releases earlier allocations. Loading validates and owns its
storage. A player borrows a finished session, which must outlive it; it owns
no heap memory. The proof owns its scene, retained snapshot and collision
world, releasing the snapshot before the scene. Encoding uses caller storage.
Per-tick append/read/inject/hash/verify do not allocate. Tests stop allocator
success after initialization and compare allocation counts across the run.

Errors distinguish invalid metadata, unsupported versions/channels,
incompatible rate/protocol/seed/derivation, initial mismatch, invalid payload,
capacity/size exhaustion, malformed ordering, overflow, truncation, checksum,
writer failure, pending verification, and first state divergence. Failed
checkpoint verification never advances to another tick or replaces diagnostics.
Tests cover repeated byte identity and different recording frame groupings;
playback is driven by recorded ticks, with no wall clock or physical devices.
Exact digest equality is contractual for this supported Windows x86_64 pinned
implementation. No broad float tolerance masks divergence.

## Extensions and explicit non-goals

A future client must supply canonical channels, bootstrap recreation, all
causal deterministic state contributors, accepted external event policy, and
protocol identities matching its algorithms. Engine Lab and gameplay routes
must integrate these at their existing tick boundary and define how generic
scene publication is handled. Additional channels need explicit versioned
registration; unknown required channels fail. RR1 does not implement video,
audio, save-game UX, memory snapshots, rewind, scrubbing, rollback, networking,
editing, compression, encryption, migration, scheduling, bug minimization,
physics changes, secondary motion, morphology, world time, editors, projectiles,
or a general event bus. No GPU pixels participate in simulation authority.

## Public callback and buffer obligations

Registered channel validators must be deterministic, headless and allocation
free, and must not consult live input, ambient RNG or wall time. They validate
their complete channel payload; the real V1 adapter enforces exact lengths.
Session storage has one owner and must not be copied as additional ownership.
Treat its implementation fields as read-only outside its methods. A finished
session remains immutable until every borrowing player has been disposed.
Encoder scratch must not alias session storage or a writer's own buffer.
The caller owns writer flushing and atomic disk publication; `write`
propagates errors from `writeAll`, and the caller must also check flush errors.