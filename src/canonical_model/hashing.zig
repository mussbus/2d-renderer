const std = @import("std");
const normalization = @import("normalization.zig");
const serialization = @import("serialization.zig");

pub const HashDomain = enum {
    source_definition,
    resolved_geometry,
    resolved_pose,
    representation_package,
};

pub fn StableHash(comptime domain_value: HashDomain) type {
    return struct {
        bytes: [32]u8,

        pub const domain = domain_value;
        const Self = @This();

        pub fn eql(a: Self, b: Self) bool {
            return std.mem.eql(u8, &a.bytes, &b.bytes);
        }

        pub fn toHex(self: Self) [64]u8 {
            return std.fmt.bytesToHex(self.bytes, .lower);
        }
    };
}

pub const SourceDefinitionHash = StableHash(.source_definition);

pub const HashResult = struct {
    canonical_bytes: []const u8,
    source_definition_hash: SourceDefinitionHash,
};

pub fn hashNormalized(
    normalized: normalization.NormalizedDefinition,
    serialization_buffer: []u8,
) serialization.SerializationError!HashResult {
    const canonical_bytes = try serialization.serialize(normalized, serialization_buffer);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canonical_bytes, &digest, .{});
    return .{
        .canonical_bytes = canonical_bytes,
        .source_definition_hash = .{ .bytes = digest },
    };
}
