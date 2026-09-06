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
pub const header_size = 196;
pub const record_header_size = 11;
pub const magic = "RR1TICK\x00";

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

pub const Channels = struct {
    command: Channel,
    event: Channel,

    fn validate(self: Channels, metadata: Metadata) Error!void {
        if (!self.command.identity.eql(metadata.command) or !self.event.identity.eql(metadata.event))
            return error.UnsupportedChannel;
        if (self.command.maximum_size == 0 or self.event.maximum_size == 0 or
            self.command.maximum_size > maximum_payload_bytes or self.event.maximum_size > maximum_payload_bytes)
            return error.InvalidMetadata;
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
    event: Identity,

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
        try self.event.validate();
    }

    fn compatible(self: Metadata, expected: Metadata) Error!void {
        try self.validate();
        try expected.validate();
        if (self.start_tick != expected.start_tick) return error.InvalidTick;
        if (!self.initial_schema.eql(expected.initial_schema)) return error.InitialStateMismatch;
        if (!self.command.eql(expected.command) or !self.event.eql(expected.event))
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

pub const Tick = struct {
    tick: u64,
    command_size: u16,
    event_size: ?u16,
    command: [maximum_payload_bytes]u8,
    event: [maximum_payload_bytes]u8,
    checkpoint: Digest,

    pub fn commandBytes(self: *const Tick) []const u8 {
        return self.command[0..self.command_size];
    }

    pub fn eventBytes(self: *const Tick) ?[]const u8 {
        return if (self.event_size) |size| self.event[0..size] else null;
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
    count: u32 = 0,
    event_count: u32 = 0,
    finished: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        metadata: Metadata,
        channels: Channels,
        initial: []const u8,
        recreated_state: Digest,
        capacity: u32,
    ) Error!Session {
        try metadata.validate();
        try channels.validate(metadata);
        if (capacity > maximum_ticks) return error.CapacityExceeded;
        if (initial.len > maximum_initial_bytes) return error.PayloadTooLarge;
        const identity = try initialDigest(metadata.initial_schema, initial);
        const initial_copy = try allocator.dupe(u8, initial);
        errdefer allocator.free(initial_copy);
        const storage = try allocator.alloc(Tick, capacity);
        return .{
            .allocator = allocator,
            .metadata = metadata,
            .channels = channels,
            .initial = initial_copy,
            .initial_identity = identity,
            .initial_state = recreated_state,
            .storage = storage,
        };
    }

    pub fn deinit(self: *Session) void {
        self.allocator.free(self.storage);
        self.allocator.free(self.initial);
        self.* = undefined;
    }

    /// All validation precedes the commit to storage/counts.
    pub fn append(self: *Session, tick: u64, command: []const u8, event: ?[]const u8, checkpoint: Digest) Error!void {
        if (self.finished) return error.SessionFinished;
        const next_tick = std.math.add(u64, self.metadata.start_tick, self.count) catch return error.TickOverflow;
        if (tick != next_tick) return error.InvalidTick;
        _ = std.math.add(u64, tick, 1) catch return error.TickOverflow;
        try self.channels.command.validate(command);
        if (event) |payload| try self.channels.event.validate(payload);
        if (self.count == self.storage.len) return error.CapacityExceeded;
        var record = Tick{
            .tick = tick,
            .command_size = @intCast(command.len),
            .event_size = if (event) |payload| @intCast(payload.len) else null,
            .command = @splat(0),
            .event = @splat(0),
            .checkpoint = checkpoint,
        };
        @memcpy(record.command[0..command.len], command);
        if (event) |payload| @memcpy(record.event[0..payload.len], payload);
        self.storage[self.count] = record;
        self.count += 1;
        if (event != null) self.event_count += 1;
    }

    pub fn finish(self: *Session) Error!void {
        if (self.finished) return error.SessionFinished;
        self.finished = true;
    }

    pub fn ticks(self: *const Session) []const Tick {
        return self.storage[0..self.count];
    }

    pub fn encodedSize(self: *const Session) Error!usize {
        if (!self.finished) return error.SessionNotFinished;
        var size: usize = header_size + self.initial.len + 32;
        for (self.ticks()) |record| {
            size += 2 * record_header_size + record.command_size + 32;
            if (record.event_size) |length| size += record_header_size + length;
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
            try writeRecord(&writer, 1, record.tick, record.commandBytes());
            if (record.eventBytes()) |event| try writeRecord(&writer, 2, record.tick, event);
            try writeRecord(&writer, 3, record.tick, &record.checkpoint.bytes);
        }
        const digest = try artifactDigest(writer.slice());
        try writer.raw(&digest.bytes);
        return writer.slice();
    }

    pub fn write(self: *const Session, writer: *std.Io.Writer, scratch: []u8) Error!void {
        try writer.writeAll(try self.encode(scratch));
    }
};

pub const Divergence = struct { tick: u64, expected: Digest, actual: Digest };

/// Tick delivery cannot advance past an unverified or divergent checkpoint.
pub const Player = struct {
    session: *const Session,
    cursor: u32 = 0,
    pending: bool = false,
    divergence: ?Divergence = null,

    pub fn init(session: *const Session, expected: Metadata, recreated_envelope: []const u8, recreated_state: Digest) Error!Player {
        if (!session.finished) return error.SessionNotFinished;
        try session.metadata.compatible(expected);
        if (!session.initial_identity.eql(try initialDigest(expected.initial_schema, recreated_envelope)) or
            !session.initial_state.eql(recreated_state)) return error.InitialStateMismatch;
        return .{ .session = session };
    }

    pub fn next(self: *Player) Error!?*const Tick {
        if (self.divergence != null) return error.StateDivergence;
        if (self.pending) return error.VerificationPending;
        if (self.cursor == self.session.count) return null;
        self.pending = true;
        return &self.session.storage[self.cursor];
    }

    pub fn verify(self: *Player, actual: Digest) Error!void {
        if (self.divergence != null) return error.StateDivergence;
        if (!self.pending) return error.NoPendingTick;
        const record = &self.session.storage[self.cursor];
        if (!record.checkpoint.eql(actual)) {
            self.divergence = .{ .tick = record.tick, .expected = record.checkpoint, .actual = actual };
            return error.StateDivergence;
        }
        self.cursor += 1;
        self.pending = false;
    }

    pub fn deinit(self: *Player) void {
        self.* = undefined;
    }
};

pub fn decode(allocator: std.mem.Allocator, artifact: []const u8, channels: Channels, capacity: u32) Error!Session {
    if (artifact.len < header_size + 32) return error.TruncatedArtifact;
    // Header compatibility is diagnosed before checksum so unknown V1 revisions fail explicitly.
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
    metadata.event = try reader.identity();
    const count = try reader.int(u32);
    const event_count = try reader.int(u32);
    const checkpoint_count = try reader.int(u32);
    try metadata.validate();
    try channels.validate(metadata);
    if (count > capacity or count > maximum_ticks) return error.CapacityExceeded;
    if (event_count > count or checkpoint_count != count) return error.InvalidCounts;
    if (initial_size > maximum_initial_bytes) return error.PayloadTooLarge;
    _ = std.math.add(u64, metadata.start_tick, count) catch return error.TickOverflow;
    const minimum_size = header_size + @as(usize, initial_size) + @as(usize, count) * (record_header_size * 2 + 32) +
        @as(usize, event_count) * record_header_size + 32;
    if (artifact.len < minimum_size) return error.TruncatedArtifact;
    const maximum_size = header_size + @as(usize, initial_size) + @as(usize, count) * (record_header_size * 2 + maximum_payload_bytes + 32) +
        @as(usize, event_count) * (record_header_size + maximum_payload_bytes) + 32;
    if (artifact.len > maximum_size) return error.PayloadTooLarge;
    const integrity = try artifactDigest(artifact[0 .. artifact.len - 32]);
    if (!std.mem.eql(u8, &integrity.bytes, artifact[artifact.len - 32 ..])) return error.CorruptArtifact;
    const initial = try reader.raw(initial_size);
    if (!initial_identity.eql(try initialDigest(metadata.initial_schema, initial))) return error.InitialStateMismatch;
    var result = try Session.init(allocator, metadata, channels, initial, initial_state, count);
    errdefer result.deinit();
    for (0..count) |index| {
        const tick = metadata.start_tick + index;
        const command = try reader.record(1, tick);
        var event: ?[]const u8 = null;
        if (reader.position < reader.input.len and reader.input[reader.position] == 2)
            event = try reader.record(2, tick);
        const checkpoint = try reader.record(3, tick);
        if (checkpoint.len != 32) return error.InvalidPayload;
        try result.append(tick, command, event, .{ .bytes = checkpoint[0..32].* });
    }
    if (reader.position != reader.input.len) return error.InvalidOrdering;
    if (result.event_count != event_count) return error.InvalidCounts;
    try result.finish();
    return result;
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

    fn record(self: *Reader, expected_kind: u8, tick: u64) Error![]const u8 {
        const kind = try self.int(u8);
        if (kind < 1 or kind > 3) return error.UnknownRecordKind;
        if (kind != expected_kind) return error.InvalidOrdering;
        if (try self.int(u64) != tick) return error.InvalidTick;
        const length = try self.int(u16);
        if (length > maximum_payload_bytes) return error.PayloadTooLarge;
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
    try writer.raw(&metadata.event.bytes());
    try writer.int(u32, self.count);
    try writer.int(u32, self.event_count);
    try writer.int(u32, self.count);
}
