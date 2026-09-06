const std = @import("std");
const foundation = @import("foundation");
const canonical = foundation.canonical_data;

pub const Digest = canonical.Sha256Digest;
pub const format_version: u16 = 1;
pub const protocol_version: u16 = 1;
pub const derivation_version: u16 = 1;
pub const tick_rate: u32 = 240;
pub const maximum_ticks: u32 = 65536;
pub const maximum_initial_bytes = 1024;
pub const maximum_payload_bytes = 64;
pub const maximum_contributors = 16;
pub const maximum_events: u32 = 65536;
pub const maximum_events_per_tick = 8;
pub const maximum_event_types = 8;
pub const maximum_checkpoints = 32;
pub const maximum_checkpoints_per_tick = 8;
pub const maximum_identifier_bytes = 32;
pub const named_checkpoint_version: u16 = 1;
pub const header_size = 212;
pub const record_header_size = 11;
pub const magic = "RR1TICK\x01";

pub const Error = canonical.Error || error{
    OutOfMemory,
    InvalidMetadata,
    UnsupportedVersion,
    UnsupportedChannel,
    IncompatibleTickRate,
    IncompatibleProtocol,
    SeedMismatch,
    DerivationMismatch,
    InitialStateMismatch,
    InvalidPayload,
    NonCanonicalFloat,
    PayloadTooLarge,
    CapacityExceeded,
    TickOverflow,
    InvalidTick,
    InvalidOrdering,
    UnknownRecordKind,
    TruncatedArtifact,
    CorruptArtifact,
    InvalidCounts,
    SessionFinished,
    SessionNotFinished,
    VerificationPending,
    NoPendingTick,
    StateDivergence,
    ContributorOrder,
    TooManyContributors,
    WriteFailed,
    CausalCapacityExceeded,
    ObservedCapacityExceeded,
    CheckpointCapacityExceeded,
    InvalidEventOrdinal,
    OrdinalOverflow,
    UnknownEventType,
    UnsupportedEventSchema,
    ObservedEventDivergence,
    NamedCheckpointDivergence,
    InvalidCheckpointIdentifier,
    DuplicateCheckpoint,
    CheckpointOrder,
    CheckpointDigestMismatch,
};

pub const Identity = struct {
    id: u32,
    version: u16,

    pub fn eql(a: Identity, b: Identity) bool {
        return a.id == b.id and a.version == b.version;
    }

    pub fn validate(self: Identity) Error!void {
        if (self.id == 0 or self.version == 0) return error.InvalidMetadata;
    }

    pub fn bytes(self: Identity) [6]u8 {
        var result: [6]u8 = undefined;
        std.mem.writeInt(u32, result[0..4], self.id, .little);
        std.mem.writeInt(u16, result[4..6], self.version, .little);
        return result;
    }
};

/// Callbacks validate explicit durable payload bytes, never native structs.
pub const Channel = struct {
    identity: Identity,
    maximum_size: u16,
    validate_fn: *const fn ([]const u8) Error!void,

    fn validate(self: Channel, payload: []const u8) Error!void {
        if (payload.len > self.maximum_size or payload.len > maximum_payload_bytes)
            return error.PayloadTooLarge;
        try self.validate_fn(payload);
    }
};

pub const EventChannel = struct {
    identity: Identity,
    types: []const Channel,

    fn validate(self: EventChannel) Error!void {
        try self.identity.validate();
        if (self.types.len == 0 or self.types.len > maximum_event_types) return error.InvalidMetadata;
        var previous: u32 = 0;
        for (self.types) |entry| {
            try entry.identity.validate();
            if (entry.identity.id <= previous or entry.maximum_size > maximum_payload_bytes) return error.InvalidMetadata;
            previous = entry.identity.id;
        }
    }

    fn validateEvent(self: EventChannel, event: Event) Error!void {
        for (self.types) |entry| {
            if (entry.identity.id == event.identity.id) {
                if (entry.identity.version != event.identity.version) return error.UnsupportedEventSchema;
                try entry.validate(try event.payloadBytes());
                return;
            }
        }
        return error.UnknownEventType;
    }
};

pub const Channels = struct {
    command: Channel,
    causal: EventChannel,
    observed: EventChannel,

    fn validate(self: Channels, metadata: Metadata) Error!void {
        if (!self.command.identity.eql(metadata.command) or !self.causal.identity.eql(metadata.causal) or
            !self.observed.identity.eql(metadata.observed)) return error.UnsupportedChannel;
        if (self.command.maximum_size == 0 or self.command.maximum_size > maximum_payload_bytes)
            return error.InvalidMetadata;
        try self.causal.validate();
        try self.observed.validate();
    }
};

pub const Metadata = struct {
    format: u16 = format_version,
    protocol: u16 = protocol_version,
    hz: u32 = tick_rate,
    start_tick: u64 = 0,
    derivation_framing: u16 = derivation_version,
    derivation: foundation.determinism.DerivationContext,
    initial_schema: Identity,
    command: Identity,
    causal: Identity,
    observed: Identity,
    named_encoding: u16 = named_checkpoint_version,

    pub fn validate(self: Metadata) Error!void {
        if (self.format != format_version) return error.UnsupportedVersion;
        if (self.protocol != protocol_version) return error.IncompatibleProtocol;
        if (self.hz != tick_rate) return error.IncompatibleTickRate;
        if (self.derivation_framing != derivation_version) return error.DerivationMismatch;
        _ = foundation.identity.GeneratorId.fromCanonicalBytes(self.derivation.generator_id.bytes) catch
            return error.InvalidMetadata;
        _ = foundation.identity.AlgorithmId.fromCanonicalBytes(self.derivation.algorithm_id.bytes) catch
            return error.InvalidMetadata;
        try self.initial_schema.validate();
        try self.command.validate();
        try self.causal.validate();
        try self.observed.validate();
        if (self.named_encoding != named_checkpoint_version) return error.UnsupportedVersion;
    }

    fn compatible(self: Metadata, expected: Metadata) Error!void {
        try self.validate();
        try expected.validate();
        if (self.start_tick != expected.start_tick) return error.InvalidTick;
        if (!self.initial_schema.eql(expected.initial_schema)) return error.InitialStateMismatch;
        if (!self.command.eql(expected.command) or !self.causal.eql(expected.causal) or !self.observed.eql(expected.observed))
            return error.UnsupportedChannel;
        if (!self.derivation.root_seed.eql(expected.derivation.root_seed)) return error.SeedMismatch;
        if (!self.derivation.generator_id.eql(expected.derivation.generator_id) or
            !self.derivation.algorithm_id.eql(expected.derivation.algorithm_id) or
            !self.derivation.generator_version.eql(expected.derivation.generator_version) or
            !self.derivation.algorithm_version.eql(expected.derivation.algorithm_version))
            return error.DerivationMismatch;
    }
};

pub fn initialDigest(identity: Identity, payload: []const u8) Error!Digest {
    try identity.validate();
    if (payload.len > maximum_initial_bytes) return error.PayloadTooLarge;
    const key = identity.bytes();
    return canonical.hashDomainSeparated("replay.initial.v1", &.{ &key, payload });
}

pub fn contributorDigest(identity: Identity, fields: []const u8) Error!Digest {
    try identity.validate();
    const key = identity.bytes();
    return canonical.hashDomainSeparated("replay.contributor.v1", &.{ &key, fields });
}

pub const Contributor = struct { identity: Identity, digest: Digest };

pub fn stateDigest(contributors: []const Contributor) Error!Digest {
    if (contributors.len == 0) return error.InvalidMetadata;
    if (contributors.len > maximum_contributors) return error.TooManyContributors;
    var data: [maximum_contributors * 38]u8 = undefined;
    var writer = Bytes.init(&data);
    var previous: u32 = 0;
    for (contributors) |entry| {
        try entry.identity.validate();
        if (entry.identity.id <= previous) return error.ContributorOrder;
        previous = entry.identity.id;
        try writer.raw(&entry.identity.bytes());
        try writer.raw(&entry.digest.bytes);
    }
    return canonical.hashDomainSeparated("replay.state.v1", &.{writer.slice()});
}

pub fn artifactDigest(bytes: []const u8) Error!Digest {
    return canonical.hashDomainSeparated("replay.artifact.v1", &.{bytes});
}

pub const Event = struct {
    tick: u64,
    ordinal: u16,
    identity: Identity,
    payload_size: u16,
    payload: [maximum_payload_bytes]u8,

    pub fn init(tick: u64, ordinal: u16, identity: Identity, payload: []const u8) Error!Event {
        try identity.validate();
        if (payload.len > maximum_payload_bytes) return error.PayloadTooLarge;
        var result = Event{ .tick = tick, .ordinal = ordinal, .identity = identity, .payload_size = @intCast(payload.len), .payload = @splat(0) };
        @memcpy(result.payload[0..payload.len], payload);
        return result;
    }

    pub fn payloadBytes(self: *const Event) Error![]const u8 {
        if (self.payload_size > maximum_payload_bytes) return error.PayloadTooLarge;
        return self.payload[0..self.payload_size];
    }
};

pub const CheckpointName = struct {
    length: u8,
    bytes: [maximum_identifier_bytes]u8,

    pub fn init(text: []const u8) Error!CheckpointName {
        if (text.len == 0 or text.len > maximum_identifier_bytes) return error.InvalidCheckpointIdentifier;
        var result = CheckpointName{ .length = @intCast(text.len), .bytes = @splat(0) };
        @memcpy(result.bytes[0..text.len], text);
        try result.validate();
        return result;
    }

    pub fn validate(self: CheckpointName) Error!void {
        if (self.length == 0 or self.length > maximum_identifier_bytes) return error.InvalidCheckpointIdentifier;
        for (self.bytes[0..self.length], 0..) |ch, index| {
            if (ch >= 'a' and ch <= 'z') continue;
            if (index > 0 and ((ch >= '0' and ch <= '9') or ch == '_')) continue;
            return error.InvalidCheckpointIdentifier;
        }
    }

    pub fn slice(self: *const CheckpointName) []const u8 {
        return self.bytes[0..self.length];
    }
};

pub const NamedCheckpoint = struct { name: CheckpointName, tick: u64, digest: Digest };

pub const Capacities = struct {
    ticks: u32,
    causal_events: u32 = 0,
    observed_events: u32 = 0,
    named_checkpoints: u8 = 0,

    fn validate(self: Capacities) Error!void {
        if (self.ticks > maximum_ticks) return error.CapacityExceeded;
        if (self.causal_events > maximum_events) return error.CausalCapacityExceeded;
        if (self.observed_events > maximum_events) return error.ObservedCapacityExceeded;
        if (self.named_checkpoints > maximum_checkpoints) return error.CheckpointCapacityExceeded;
    }
};

pub const Tick = struct {
    tick: u64,
    command_size: u16,
    command: [maximum_payload_bytes]u8,
    causal_start: u32,
    causal_count: u8,
    observed_start: u32,
    observed_count: u8,
    named_start: u8,
    named_count: u8,
    fingerprint: Digest,

    pub fn commandBytes(self: *const Tick) []const u8 {
        return self.command[0..self.command_size];
    }
};

pub const TickView = struct {
    tick: u64,
    command: []const u8,
    causal: []const Event,
    observed: []const Event,
    fingerprint: Digest,
    checkpoints: []const NamedCheckpoint,

    pub fn commandBytes(self: TickView) []const u8 {
        return self.command;
    }
};

/// Owns bounded storage. Do not copy or mutate a session while borrowed by a player.
pub const Session = struct {
    allocator: std.mem.Allocator,
    metadata: Metadata,
    channels: Channels,
    initial: []const u8,
    initial_identity: Digest,
    initial_state: Digest,
    storage: []Tick,
    causal_storage: []Event,
    observed_storage: []Event,
    named_storage: []NamedCheckpoint,
    count: u32 = 0,
    causal_count: u32 = 0,
    observed_count: u32 = 0,
    named_count: u8 = 0,
    finished: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        metadata: Metadata,
        channels: Channels,
        initial: []const u8,
        recreated_state: Digest,
        capacities: Capacities,
    ) Error!Session {
        try metadata.validate();
        try channels.validate(metadata);
        try capacities.validate();
        if (initial.len > maximum_initial_bytes) return error.PayloadTooLarge;
        const identity = try initialDigest(metadata.initial_schema, initial);
        const initial_copy = try allocator.dupe(u8, initial);
        errdefer allocator.free(initial_copy);
        const storage = try allocator.alloc(Tick, capacities.ticks);
        errdefer allocator.free(storage);
        const causal = try allocator.alloc(Event, capacities.causal_events);
        errdefer allocator.free(causal);
        const observed = try allocator.alloc(Event, capacities.observed_events);
        errdefer allocator.free(observed);
        const named = try allocator.alloc(NamedCheckpoint, capacities.named_checkpoints);
        return .{
            .allocator = allocator,
            .metadata = metadata,
            .channels = channels,
            .initial = initial_copy,
            .initial_identity = identity,
            .initial_state = recreated_state,
            .storage = storage,
            .causal_storage = causal,
            .observed_storage = observed,
            .named_storage = named,
        };
    }

    pub fn deinit(self: *Session) void {
        self.allocator.free(self.named_storage);
        self.allocator.free(self.observed_storage);
        self.allocator.free(self.causal_storage);
        self.allocator.free(self.storage);
        self.allocator.free(self.initial);
        self.* = undefined;
    }

    pub fn endTickExclusive(self: *const Session) Error!u64 {
        return std.math.add(u64, self.metadata.start_tick, self.count) catch error.TickOverflow;
    }

    /// Used before stepping; observed_reserve is a proven upper bound for that adapter.
    pub fn preflight(self: *const Session, tick: u64, command: []const u8, causal: []const Event, observed_reserve: usize, names: []const CheckpointName) Error!void {
        if (self.finished) return error.SessionFinished;
        if (tick != try self.endTickExclusive()) return error.InvalidTick;
        _ = std.math.add(u64, tick, 1) catch return error.TickOverflow;
        try self.channels.command.validate(command);
        try validateEvents(self.channels.causal, tick, causal);
        if (self.count == self.storage.len) return error.CapacityExceeded;
        if (causal.len > self.causal_storage.len - self.causal_count) return error.CausalCapacityExceeded;
        if (observed_reserve > maximum_events_per_tick or observed_reserve > self.observed_storage.len - self.observed_count)
            return error.ObservedCapacityExceeded;
        try self.validateNames(names);
    }

    fn validateNames(self: *const Session, names: []const CheckpointName) Error!void {
        if (names.len > maximum_checkpoints_per_tick or names.len > self.named_storage.len - self.named_count)
            return error.CheckpointCapacityExceeded;
        for (names, 0..) |name, index| {
            try name.validate();
            if (index > 0) {
                switch (std.mem.order(u8, names[index - 1].slice(), name.slice())) {
                    .eq => return error.DuplicateCheckpoint,
                    .gt => return error.CheckpointOrder,
                    .lt => {},
                }
            }
            for (self.named_storage[0..self.named_count]) |existing| {
                if (std.mem.eql(u8, existing.name.slice(), name.slice())) return error.DuplicateCheckpoint;
            }
        }
    }

    /// All validation precedes the atomic commit of this complete tick.
    pub fn append(self: *Session, tick: u64, command: []const u8, causal: []const Event, observed: []const Event, fingerprint: Digest, names: []const CheckpointName) Error!void {
        try self.preflight(tick, command, causal, observed.len, names);
        try validateEvents(self.channels.observed, tick, observed);
        var record = Tick{
            .tick = tick,
            .command_size = @intCast(command.len),
            .command = @splat(0),
            .causal_start = self.causal_count,
            .causal_count = @intCast(causal.len),
            .observed_start = self.observed_count,
            .observed_count = @intCast(observed.len),
            .named_start = self.named_count,
            .named_count = @intCast(names.len),
            .fingerprint = fingerprint,
        };
        @memcpy(record.command[0..command.len], command);
        @memcpy(self.causal_storage[self.causal_count..][0..causal.len], causal);
        @memcpy(self.observed_storage[self.observed_count..][0..observed.len], observed);
        for (names, 0..) |name, index|
            self.named_storage[self.named_count + index] = .{ .name = name, .tick = tick, .digest = fingerprint };
        self.storage[self.count] = record;
        self.causal_count += @intCast(causal.len);
        self.observed_count += @intCast(observed.len);
        self.named_count += @intCast(names.len);
        self.count += 1;
    }

    pub fn finish(self: *Session) Error!void {
        if (self.finished) return error.SessionFinished;
        self.finished = true;
    }

    pub fn ticks(self: *const Session) []const Tick {
        return self.storage[0..self.count];
    }

    pub fn view(self: *const Session, record: *const Tick) TickView {
        return .{
            .tick = record.tick,
            .command = record.commandBytes(),
            .fingerprint = record.fingerprint,
            .causal = self.causal_storage[record.causal_start..][0..record.causal_count],
            .observed = self.observed_storage[record.observed_start..][0..record.observed_count],
            .checkpoints = self.named_storage[record.named_start..][0..record.named_count],
        };
    }

    pub fn encodedSize(self: *const Session) Error!usize {
        if (!self.finished) return error.SessionNotFinished;
        var size: usize = header_size + self.initial.len + 32;
        for (self.ticks()) |*record| {
            size += 2 * record_header_size + record.command_size + 32;
            const tick = self.view(record);
            for (tick.causal) |event| size += record_header_size + 8 + event.payload_size;
            for (tick.observed) |event| size += record_header_size + 8 + event.payload_size;
            for (tick.checkpoints) |checkpoint| size += record_header_size + 1 + checkpoint.name.length + 32;
        }
        return size;
    }

    pub fn encode(self: *const Session, output: []u8) Error![]const u8 {
        const size = try self.encodedSize();
        if (output.len < size) return error.OutputTooSmall;
        var writer = Bytes.init(output[0..size]);
        try writeHeader(&writer, self);
        try writer.raw(self.initial);
        for (self.ticks()) |*record| {
            const tick = self.view(record);
            try writeRecord(&writer, 1, tick.tick, tick.command);
            for (tick.causal) |event| try writeEvent(&writer, 2, event);
            for (tick.observed) |event| try writeEvent(&writer, 4, event);
            try writeRecord(&writer, 3, tick.tick, &tick.fingerprint.bytes);
            for (tick.checkpoints) |checkpoint| {
                var payload: [1 + maximum_identifier_bytes + 32]u8 = undefined;
                var fields = Bytes.init(&payload);
                try fields.int(u8, checkpoint.name.length);
                try fields.raw(checkpoint.name.slice());
                try fields.raw(&checkpoint.digest.bytes);
                try writeRecord(&writer, 5, tick.tick, fields.slice());
            }
        }
        const digest = try artifactDigest(writer.slice());
        try writer.raw(&digest.bytes);
        return writer.slice();
    }

    pub fn write(self: *const Session, writer: *std.Io.Writer, scratch: []u8) Error!void {
        try writer.writeAll(try self.encode(scratch));
    }
};

fn validateEvents(channel: EventChannel, tick: u64, events: []const Event) Error!void {
    if (events.len > maximum_events_per_tick) return error.OrdinalOverflow;
    for (events, 0..) |event, index| {
        if (event.tick != tick) return error.InvalidTick;
        if (event.ordinal >= maximum_events_per_tick) return error.OrdinalOverflow;
        if (event.ordinal != index) return error.InvalidEventOrdinal;
        try channel.validateEvent(event);
    }
}

pub const Divergence = struct { tick: u64, expected: Digest, actual: Digest };
pub const ObservedMismatch = enum { missing, extra, wrong_type, wrong_schema, wrong_payload, wrong_order, wrong_tick };
pub const ObservedDivergence = struct {
    tick: u64,
    ordinal: u16,
    category: ObservedMismatch,
    expected: ?Event,
    actual: ?Event,
};
pub const CheckpointDivergence = struct { name: CheckpointName, state: Divergence };

fn sameEventValue(a: Event, b: Event) bool {
    if (!a.identity.eql(b.identity)) return false;
    const left = a.payloadBytes() catch return false;
    const right = b.payloadBytes() catch return false;
    return std.mem.eql(u8, left, right);
}

fn compareObserved(tick: TickView, actual: []const Event) ?ObservedDivergence {
    const count = @max(tick.observed.len, actual.len);
    for (0..count) |index| {
        const expected: ?Event = if (index < tick.observed.len) tick.observed[index] else null;
        const found: ?Event = if (index < actual.len) actual[index] else null;
        const category: ObservedMismatch = mismatch: {
            if (expected == null) break :mismatch .extra;
            if (found == null) break :mismatch .missing;
            const a = found.?;
            const e = expected.?;
            if (a.tick != tick.tick) break :mismatch .wrong_tick;
            if (a.ordinal != e.ordinal) break :mismatch .wrong_order;
            if (sameEventValue(e, a)) continue;
            for (tick.observed, 0..) |other, other_index| {
                if (other_index != index and sameEventValue(other, a)) break :mismatch .wrong_order;
            }
            if (a.identity.id != e.identity.id) break :mismatch .wrong_type;
            if (a.identity.version != e.identity.version) break :mismatch .wrong_schema;
            break :mismatch .wrong_payload;
        };
        // Expected streams contain at most eight events; the first extra ordinal fits u16.
        return .{ .tick = tick.tick, .ordinal = @intCast(index), .category = category, .expected = expected, .actual = found };
    }
    return null;
}

/// Tick delivery cannot advance past pending verification or any latched mismatch.
pub const Player = struct {
    session: *const Session,
    cursor: u32 = 0,
    phase: enum { idle, delivered, observed, failed } = .idle,
    divergence: ?Divergence = null,
    observed_divergence: ?ObservedDivergence = null,
    checkpoint_divergence: ?CheckpointDivergence = null,
    verified_named_checkpoints: u32 = 0,

    pub fn init(session: *const Session, expected: Metadata, recreated_envelope: []const u8, recreated_state: Digest) Error!Player {
        if (!session.finished) return error.SessionNotFinished;
        try session.metadata.compatible(expected);
        if (!session.initial_identity.eql(try initialDigest(expected.initial_schema, recreated_envelope)) or
            !session.initial_state.eql(recreated_state)) return error.InitialStateMismatch;
        return .{ .session = session };
    }

    fn requireHealthy(self: *const Player) Error!void {
        if (self.observed_divergence != null) return error.ObservedEventDivergence;
        if (self.divergence != null) return error.StateDivergence;
        if (self.checkpoint_divergence != null) return error.NamedCheckpointDivergence;
    }

    pub fn next(self: *Player) Error!?TickView {
        try self.requireHealthy();
        if (self.phase != .idle) return error.VerificationPending;
        if (self.cursor == self.session.count) return null;
        self.phase = .delivered;
        return self.session.view(&self.session.storage[self.cursor]);
    }

    /// Compare events before the caller computes the completed-state fingerprint.
    /// A newly detected mismatch is retained; finish verify to collect same-tick state diagnostics.
    pub fn observe(self: *Player, actual_observed: []const Event) Error!void {
        try self.requireHealthy();
        if (self.phase == .idle) return error.NoPendingTick;
        if (self.phase != .delivered) return error.VerificationPending;
        const tick = self.session.view(&self.session.storage[self.cursor]);
        self.observed_divergence = compareObserved(tick, actual_observed);
        self.phase = .observed;
    }

    pub fn verify(self: *Player, actual: Digest) Error!void {
        if (self.phase == .failed) try self.requireHealthy();
        if (self.phase == .idle) return error.NoPendingTick;
        if (self.phase != .observed) return error.VerificationPending;
        const tick = self.session.view(&self.session.storage[self.cursor]);
        if (!tick.fingerprint.eql(actual))
            self.divergence = .{ .tick = tick.tick, .expected = tick.fingerprint, .actual = actual };
        for (tick.checkpoints) |checkpoint| {
            if (!checkpoint.digest.eql(actual) and self.checkpoint_divergence == null)
                self.checkpoint_divergence = .{ .name = checkpoint.name, .state = .{ .tick = tick.tick, .expected = checkpoint.digest, .actual = actual } };
        }
        self.phase = .failed;
        try self.requireHealthy();
        self.verified_named_checkpoints += @intCast(tick.checkpoints.len);
        self.cursor += 1;
        self.phase = .idle;
    }

    pub fn deinit(self: *Player) void {
        self.* = undefined;
    }
};

pub fn decode(allocator: std.mem.Allocator, artifact: []const u8, channels: Channels, capacities: Capacities) Error!Session {
    try capacities.validate();
    if (artifact.len < header_size + 32) return error.TruncatedArtifact;
    var reader = Reader{ .input = artifact[0 .. artifact.len - 32] };
    if (!std.mem.eql(u8, try reader.raw(8), magic)) return error.CorruptArtifact;
    var metadata: Metadata = undefined;
    metadata.format = try reader.int(u16);
    metadata.protocol = try reader.int(u16);
    metadata.hz = try reader.int(u32);
    metadata.start_tick = try reader.int(u64);
    metadata.derivation_framing = try reader.int(u16);
    if (try reader.int(u16) != 0) return error.InvalidMetadata;
    metadata.derivation.root_seed.bytes = (try reader.raw(16))[0..16].*;
    metadata.derivation.generator_id = .{ .bytes = (try reader.raw(16))[0..16].* };
    metadata.derivation.generator_version = .{
        .major = try reader.int(u32),
        .minor = try reader.int(u32),
        .patch = try reader.int(u32),
    };
    metadata.derivation.algorithm_id = .{ .bytes = (try reader.raw(16))[0..16].* };
    metadata.derivation.algorithm_version = .{
        .major = try reader.int(u32),
        .minor = try reader.int(u32),
        .patch = try reader.int(u32),
    };
    metadata.initial_schema = try reader.identity();
    const initial_size = try reader.int(u16);
    const initial_identity = Digest{ .bytes = (try reader.raw(32))[0..32].* };
    const initial_state = Digest{ .bytes = (try reader.raw(32))[0..32].* };
    metadata.command = try reader.identity();
    metadata.causal = try reader.identity();
    metadata.observed = try reader.identity();
    metadata.named_encoding = try reader.int(u16);
    const count = try reader.int(u32);
    const causal_count = try reader.int(u32);
    const observed_count = try reader.int(u32);
    const fingerprint_count = try reader.int(u32);
    const named_count = try reader.int(u32);
    try metadata.validate();
    try channels.validate(metadata);
    if (count > capacities.ticks or count > maximum_ticks) return error.CapacityExceeded;
    if (causal_count > capacities.causal_events or causal_count > maximum_events) return error.CausalCapacityExceeded;
    if (observed_count > capacities.observed_events or observed_count > maximum_events) return error.ObservedCapacityExceeded;
    if (named_count > capacities.named_checkpoints or named_count > maximum_checkpoints) return error.CheckpointCapacityExceeded;
    if (causal_count > count * maximum_events_per_tick or observed_count > count * maximum_events_per_tick or
        named_count > count * maximum_checkpoints_per_tick or fingerprint_count != count) return error.InvalidCounts;
    if (initial_size > maximum_initial_bytes) return error.PayloadTooLarge;
    _ = std.math.add(u64, metadata.start_tick, count) catch return error.TickOverflow;
    const event_count: usize = @as(usize, causal_count) + observed_count;
    const minimum_size = header_size + @as(usize, initial_size) + @as(usize, count) * (record_header_size * 2 + 32) +
        event_count * (record_header_size + 8) + @as(usize, named_count) * (record_header_size + 34) + 32;
    if (artifact.len < minimum_size) return error.TruncatedArtifact;
    const maximum_size = minimum_size + @as(usize, count) * maximum_payload_bytes +
        event_count * maximum_payload_bytes + @as(usize, named_count) * (maximum_identifier_bytes - 1);
    if (artifact.len > maximum_size) return error.PayloadTooLarge;
    const integrity = try artifactDigest(artifact[0 .. artifact.len - 32]);
    if (!std.mem.eql(u8, &integrity.bytes, artifact[artifact.len - 32 ..])) return error.CorruptArtifact;
    const initial = try reader.raw(initial_size);
    if (!initial_identity.eql(try initialDigest(metadata.initial_schema, initial))) return error.InitialStateMismatch;
    var result = try Session.init(allocator, metadata, channels, initial, initial_state, .{
        .ticks = count,
        .causal_events = causal_count,
        .observed_events = observed_count,
        .named_checkpoints = @intCast(named_count),
    });
    errdefer result.deinit();
    for (0..count) |index| {
        const tick = metadata.start_tick + index;
        const command = try reader.record(1, tick);
        var causal: [maximum_events_per_tick]Event = undefined;
        var causal_length: usize = 0;
        while (reader.peekKind() == 2) {
            if (causal_length == causal.len) return error.OrdinalOverflow;
            causal[causal_length] = try readEvent(&reader, 2, tick);
            causal_length += 1;
        }
        var observed: [maximum_events_per_tick]Event = undefined;
        var observed_length: usize = 0;
        while (reader.peekKind() == 4) {
            if (observed_length == observed.len) return error.OrdinalOverflow;
            observed[observed_length] = try readEvent(&reader, 4, tick);
            observed_length += 1;
        }
        const fingerprint = try reader.record(3, tick);
        if (fingerprint.len != 32) return error.InvalidPayload;
        const digest = Digest{ .bytes = fingerprint[0..32].* };
        var names: [maximum_checkpoints_per_tick]CheckpointName = undefined;
        var names_length: usize = 0;
        while (reader.peekKind() == 5) {
            if (names_length == names.len) return error.CheckpointCapacityExceeded;
            var fields = Reader{ .input = try reader.record(5, tick) };
            const length = try fields.int(u8);
            const name = try CheckpointName.init(try fields.raw(length));
            const named_digest = try fields.raw(32);
            if (fields.position != fields.input.len) return error.InvalidPayload;
            if (!std.mem.eql(u8, named_digest, &digest.bytes)) return error.CheckpointDigestMismatch;
            names[names_length] = name;
            names_length += 1;
        }
        if (causal_length > causal_count - result.causal_count or observed_length > observed_count - result.observed_count or
            names_length > named_count - result.named_count) return error.InvalidCounts;
        try result.append(tick, command, causal[0..causal_length], observed[0..observed_length], digest, names[0..names_length]);
    }
    if (reader.position != reader.input.len) return error.InvalidOrdering;
    if (result.causal_count != causal_count or result.observed_count != observed_count or result.named_count != named_count)
        return error.InvalidCounts;
    try result.finish();
    return result;
}

fn writeEvent(writer: *Bytes, kind: u8, event: Event) Error!void {
    var payload: [8 + maximum_payload_bytes]u8 = undefined;
    var fields = Bytes.init(&payload);
    try fields.int(u16, event.ordinal);
    try fields.raw(&event.identity.bytes());
    try fields.raw(try event.payloadBytes());
    try writeRecord(writer, kind, event.tick, fields.slice());
}

fn readEvent(reader: *Reader, kind: u8, tick: u64) Error!Event {
    var fields = Reader{ .input = try reader.record(kind, tick) };
    const ordinal = try fields.int(u16);
    const identity = try fields.identity();
    return Event.init(tick, ordinal, identity, fields.input[fields.position..]);
}

/// Explicit binary scalar writer shared by the adapter, with no object-memory API.
pub const Bytes = struct {
    output: []u8,
    length: usize = 0,

    pub fn init(output: []u8) Bytes {
        return .{ .output = output };
    }

    pub fn slice(self: *const Bytes) []const u8 {
        return self.output[0..self.length];
    }

    pub fn raw(self: *Bytes, value: []const u8) Error!void {
        if (value.len > self.output.len - self.length) return error.OutputTooSmall;
        @memcpy(self.output[self.length..][0..value.len], value);
        self.length += value.len;
    }

    pub fn int(self: *Bytes, comptime T: type, value: T) Error!void {
        var bytes: [@sizeOf(T)]u8 = undefined;
        std.mem.writeInt(T, &bytes, value, .little);
        try self.raw(&bytes);
    }

    pub fn boolean(self: *Bytes, value: bool) Error!void {
        try self.int(u8, @intFromBool(value));
    }

    pub fn float(self: *Bytes, value: f32) Error!void {
        if (!std.math.isFinite(value)) return error.NonFiniteFloat;
        const normalized: f32 = if (value == 0) 0 else value;
        try self.int(u32, @bitCast(normalized));
    }
};

pub const Reader = struct {
    input: []const u8,
    position: usize = 0,

    pub fn raw(self: *Reader, length: usize) Error![]const u8 {
        if (length > self.input.len - self.position) return error.TruncatedArtifact;
        const result = self.input[self.position..][0..length];
        self.position += length;
        return result;
    }

    pub fn int(self: *Reader, comptime T: type) Error!T {
        return std.mem.readInt(T, (try self.raw(@sizeOf(T)))[0..@sizeOf(T)], .little);
    }

    pub fn float(self: *Reader) Error!f32 {
        const bits = try self.int(u32);
        if (bits == 0x80000000) return error.NonCanonicalFloat;
        const value: f32 = @bitCast(bits);
        if (!std.math.isFinite(value)) return error.NonFiniteFloat;
        return value;
    }

    fn identity(self: *Reader) Error!Identity {
        return .{ .id = try self.int(u32), .version = try self.int(u16) };
    }

    fn peekKind(self: *const Reader) ?u8 {
        return if (self.position < self.input.len) self.input[self.position] else null;
    }

    fn record(self: *Reader, expected_kind: u8, tick: u64) Error![]const u8 {
        const kind = try self.int(u8);
        if (kind < 1 or kind > 5) return error.UnknownRecordKind;
        if (kind != expected_kind) return error.InvalidOrdering;
        if (try self.int(u64) != tick) return error.InvalidTick;
        const length = try self.int(u16);
        if (length > (if (kind == 2 or kind == 4) @as(u16, 72) else if (kind == 5) @as(u16, 65) else @as(u16, maximum_payload_bytes))) return error.PayloadTooLarge;
        return self.raw(length);
    }
};

fn writeRecord(writer: *Bytes, kind: u8, tick: u64, payload: []const u8) Error!void {
    try writer.int(u8, kind);
    try writer.int(u64, tick);
    try writer.int(u16, @intCast(payload.len));
    try writer.raw(payload);
}

fn writeHeader(writer: *Bytes, self: *const Session) Error!void {
    const metadata = self.metadata;
    const context = metadata.derivation;
    try writer.raw(magic);
    try writer.int(u16, metadata.format);
    try writer.int(u16, metadata.protocol);
    try writer.int(u32, metadata.hz);
    try writer.int(u64, metadata.start_tick);
    try writer.int(u16, metadata.derivation_framing);
    try writer.int(u16, 0);
    try writer.raw(&context.root_seed.bytes);
    try writer.raw(&context.generator_id.bytes);
    try writer.int(u32, context.generator_version.major);
    try writer.int(u32, context.generator_version.minor);
    try writer.int(u32, context.generator_version.patch);
    try writer.raw(&context.algorithm_id.bytes);
    try writer.int(u32, context.algorithm_version.major);
    try writer.int(u32, context.algorithm_version.minor);
    try writer.int(u32, context.algorithm_version.patch);
    try writer.raw(&metadata.initial_schema.bytes());
    try writer.int(u16, @intCast(self.initial.len));
    try writer.raw(&self.initial_identity.bytes);
    try writer.raw(&self.initial_state.bytes);
    try writer.raw(&metadata.command.bytes());
    try writer.raw(&metadata.causal.bytes());
    try writer.raw(&metadata.observed.bytes());
    try writer.int(u16, metadata.named_encoding);
    try writer.int(u32, self.count);
    try writer.int(u32, self.causal_count);
    try writer.int(u32, self.observed_count);
    try writer.int(u32, self.count);
    try writer.int(u32, self.named_count);
}
