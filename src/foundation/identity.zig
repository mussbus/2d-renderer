const std = @import("std");

/// Strong persistent identity kinds share an RFC 9562 byte representation but
/// remain non-interchangeable Zig types. The UUID is opaque identity: its
/// version and byte layout do not encode engine semantics.
pub const AssetId = UuidId("asset");
pub const EntityId = UuidId("entity");
pub const NamespaceId = UuidId("namespace");
pub const ProducerId = UuidId("producer");
pub const GeneratorId = UuidId("generator");
pub const AlgorithmId = UuidId("algorithm");

pub const UuidVersion = enum(u4) {
    v1 = 1,
    v2 = 2,
    v3 = 3,
    v4 = 4,
    v5 = 5,
    v6 = 6,
    v7 = 7,
    v8 = 8,
};

pub const ParseError = error{
    InvalidCharacter,
    InvalidLength,
    InvalidVariant,
    InvalidVersion,
    NilUuid,
};

pub const GenerationError = error{
    FieldTooLarge,
    TimestampOutOfRange,
};

// These versioned strings are persistent deterministic protocol domains.
// An incompatible framing or mapping must receive a newly reviewed domain.
const uuid_v5_fields_domain = "foundation.uuid_v5_fields.v1";
const semantic_asset_mapping_domain = "h.semantic_asset_id.v1";

fn UuidId(comptime kind_name: []const u8) type {
    return extern struct {
        const Self = @This();

        /// Exposed for canonical storage and hashing. Raw struct construction
        /// is unsupported at authored, serialized, saved, or subsystem
        /// boundaries; those boundaries must validate with parseCanonical or
        /// fromCanonicalBytes, or use an approved generator.
        bytes: [16]u8,

        pub const kind = kind_name;

        pub fn parseCanonical(text: []const u8) ParseError!Self {
            const bytes = try parseUuid(text);
            return .{ .bytes = bytes };
        }

        pub fn parseCanonicalVersion(text: []const u8, expected: UuidVersion) ParseError!Self {
            const result = try parseCanonical(text);
            if (result.version() != expected) return error.InvalidVersion;
            return result;
        }

        pub fn fromCanonicalBytes(bytes: [16]u8) ParseError!Self {
            try validateUuidBytes(bytes);
            return .{ .bytes = bytes };
        }

        /// Version inspection is for validation, diagnostics, tests,
        /// migration, and identity-generation tooling. Ordinary consumers
        /// must not derive object behavior or meaning from this value.
        pub fn version(self: Self) UuidVersion {
            return @enumFromInt(self.bytes[6] >> 4);
        }

        pub fn formatCanonical(self: Self) [36]u8 {
            return formatUuid(self.bytes);
        }

        pub fn eql(a: Self, b: Self) bool {
            return std.mem.eql(u8, &a.bytes, &b.bytes);
        }

        /// Unsigned lexicographic byte order for deterministic output only.
        /// This has no semantic or chronological meaning.
        pub fn byteOrder(a: Self, b: Self) std.math.Order {
            return std.mem.order(u8, &a.bytes, &b.bytes);
        }
    };
}

comptime {
    if (@sizeOf(AssetId) != 16 or @sizeOf(EntityId) != 16 or @sizeOf(NamespaceId) != 16) {
        @compileError("persistent UUID identity types must remain exactly 128 bits");
    }
}

pub fn uuidV5(comptime Id: type, namespace: NamespaceId, name: []const u8) Id {
    // SHA-1 is the algorithm required by RFC 9562 UUIDv5, not a general
    // cryptographic-security choice.
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update(&namespace.bytes);
    hasher.update(name);
    var digest: [20]u8 = undefined;
    hasher.final(&digest);
    var bytes: [16]u8 = digest[0..16].*;
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return .{ .bytes = bytes };
}

pub fn uuidV5Fields(comptime Id: type, namespace: NamespaceId, fields: []const []const u8) GenerationError!Id {
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update(&namespace.bytes);
    hasher.update(uuid_v5_fields_domain);
    var count_buffer: [4]u8 = undefined;
    if (fields.len > std.math.maxInt(u32)) return error.FieldTooLarge;
    std.mem.writeInt(u32, &count_buffer, @intCast(fields.len), .big);
    hasher.update(&count_buffer);
    for (fields) |field| {
        if (field.len > std.math.maxInt(u32)) return error.FieldTooLarge;
        var length_buffer: [4]u8 = undefined;
        std.mem.writeInt(u32, &length_buffer, @intCast(field.len), .big);
        hasher.update(&length_buffer);
        hasher.update(field);
    }
    var digest: [20]u8 = undefined;
    hasher.final(&digest);
    var bytes: [16]u8 = digest[0..16].*;
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return .{ .bytes = bytes };
}

pub fn uuidV7(comptime Id: type, unix_milliseconds: u64, entropy: [10]u8) GenerationError!Id {
    if (unix_milliseconds > 0x0000_ffff_ffff_ffff) return error.TimestampOutOfRange;
    var bytes: [16]u8 = undefined;
    bytes[0] = @truncate(unix_milliseconds >> 40);
    bytes[1] = @truncate(unix_milliseconds >> 32);
    bytes[2] = @truncate(unix_milliseconds >> 24);
    bytes[3] = @truncate(unix_milliseconds >> 16);
    bytes[4] = @truncate(unix_milliseconds >> 8);
    bytes[5] = @truncate(unix_milliseconds);
    @memcpy(bytes[6..16], &entropy);
    bytes[6] = (bytes[6] & 0x0f) | 0x70;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return .{ .bytes = bytes };
}

pub const SemanticStringId = struct {
    bytes: []const u8,

    pub fn init(bytes: []const u8) error{InvalidSemanticId}!SemanticStringId {
        if (!validSemanticId(bytes)) return error.InvalidSemanticId;
        return .{ .bytes = bytes };
    }
};

pub const SemanticAssetMapping = struct {
    semantic_id: SemanticStringId,
    asset_id: AssetId,
};

pub fn mapSemanticAssetId(namespace: NamespaceId, semantic_id: SemanticStringId) GenerationError!AssetId {
    return uuidV5Fields(AssetId, namespace, &.{ semantic_asset_mapping_domain, semantic_id.bytes });
}

pub const NamespaceRegistration = struct {
    /// Once this namespace derives a persisted identity, `id` is a permanent
    /// protocol identity. Metadata must not redefine or repurpose it.
    id: NamespaceId,
    owner: []const u8,
    purpose: []const u8,
};

pub const NamespaceRegistry = struct {
    storage: []NamespaceRegistration,
    length: usize = 0,

    pub fn init(storage: []NamespaceRegistration) NamespaceRegistry {
        return .{ .storage = storage };
    }

    pub fn register(self: *NamespaceRegistry, registration: NamespaceRegistration) error{
        CapacityExceeded,
        DuplicateNamespace,
        DuplicateOwnerPurpose,
        InvalidRegistration,
    }!void {
        if (!validRegistryLabel(registration.owner) or !validRegistryLabel(registration.purpose)) {
            return error.InvalidRegistration;
        }
        for (self.storage[0..self.length]) |existing| {
            if (existing.id.eql(registration.id)) return error.DuplicateNamespace;
            if (std.mem.eql(u8, existing.owner, registration.owner) and
                std.mem.eql(u8, existing.purpose, registration.purpose))
            {
                return error.DuplicateOwnerPurpose;
            }
        }
        if (self.length == self.storage.len) return error.CapacityExceeded;
        var insertion_index = self.length;
        while (insertion_index > 0 and registration.id.byteOrder(self.storage[insertion_index - 1].id) == .lt) : (insertion_index -= 1) {
            self.storage[insertion_index] = self.storage[insertion_index - 1];
        }
        self.storage[insertion_index] = registration;
        self.length += 1;
    }

    pub fn registrations(self: *const NamespaceRegistry) []const NamespaceRegistration {
        return self.storage[0..self.length];
    }
};

pub fn rejectDuplicateIds(comptime Id: type, ids: []const Id) error{DuplicateId}!void {
    for (ids, 0..) |id, index| {
        for (ids[0..index]) |previous| {
            if (id.eql(previous)) return error.DuplicateId;
        }
    }
}

/// Runtime-only acceleration/reference value. It is never authored or
/// serialized as persistent identity and is not stable across scene reload or
/// process restart. `slot` names a future runtime registry/storage location;
/// `generation` is reserved for detecting stale references after slot reuse.
/// F2A freezes only this value shape and its validity rules. Allocation,
/// recycling, generation changes/wrap, stale rejection, free lists, component
/// lookup, and persistent-ID resolution remain F2C responsibilities.
pub const EntityHandle = extern struct {
    slot: u32,
    generation: u32,

    pub const invalid = EntityHandle{
        .slot = std.math.maxInt(u32),
        .generation = 0,
    };

    pub fn init(slot: u32, generation: u32) error{InvalidHandle}!EntityHandle {
        if (slot == std.math.maxInt(u32) or generation == 0) return error.InvalidHandle;
        return .{ .slot = slot, .generation = generation };
    }

    pub fn isValid(self: EntityHandle) bool {
        return self.slot != std.math.maxInt(u32) and self.generation != 0;
    }

    pub fn eql(a: EntityHandle, b: EntityHandle) bool {
        return a.slot == b.slot and a.generation == b.generation;
    }
};

comptime {
    if (@sizeOf(EntityHandle) != 8) @compileError("EntityHandle must remain a two-u32 runtime value type");
}

fn parseUuid(text: []const u8) ParseError![16]u8 {
    if (text.len != 36) return error.InvalidLength;
    if (text[8] != '-' or text[13] != '-' or text[18] != '-' or text[23] != '-') {
        return error.InvalidCharacter;
    }
    var bytes: [16]u8 = undefined;
    var input_index: usize = 0;
    var output_index: usize = 0;
    while (input_index < text.len) {
        if (text[input_index] == '-') {
            input_index += 1;
            continue;
        }
        const high = try lowerHexValue(text[input_index]);
        const low = try lowerHexValue(text[input_index + 1]);
        bytes[output_index] = (high << 4) | low;
        output_index += 1;
        input_index += 2;
    }
    try validateUuidBytes(bytes);
    return bytes;
}

fn validateUuidBytes(bytes: [16]u8) ParseError!void {
    var any_nonzero = false;
    for (bytes) |byte| any_nonzero = any_nonzero or byte != 0;
    if (!any_nonzero) return error.NilUuid;
    if (bytes[8] & 0xc0 != 0x80) return error.InvalidVariant;
    const version = bytes[6] >> 4;
    if (version < 1 or version > 8) return error.InvalidVersion;
}

fn formatUuid(bytes: [16]u8) [36]u8 {
    const alphabet = "0123456789abcdef";
    var result: [36]u8 = undefined;
    var input_index: usize = 0;
    var output_index: usize = 0;
    while (input_index < bytes.len) : (input_index += 1) {
        if (output_index == 8 or output_index == 13 or output_index == 18 or output_index == 23) {
            result[output_index] = '-';
            output_index += 1;
        }
        result[output_index] = alphabet[bytes[input_index] >> 4];
        result[output_index + 1] = alphabet[bytes[input_index] & 0x0f];
        output_index += 2;
    }
    return result;
}

fn lowerHexValue(byte: u8) ParseError!u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        else => error.InvalidCharacter,
    };
}

fn validSemanticId(value: []const u8) bool {
    if (value.len == 0 or value.len > 255) return false;
    for (value) |byte| {
        if (!((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '_' or byte == '.' or byte == '-')) {
            return false;
        }
    }
    return true;
}

fn validRegistryLabel(value: []const u8) bool {
    if (value.len == 0 or value.len > 127) return false;
    for (value) |byte| {
        if (!((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '_' or byte == '-')) {
            return false;
        }
    }
    return true;
}
