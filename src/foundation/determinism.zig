const std = @import("std");
const canonical_data = @import("canonical_data.zig");
const identity = @import("identity.zig");
const version = @import("version.zig");

// Persistent deterministic protocol identifiers. Changing either existing v1
// string or its framing changes derived values and requires explicit review and
// a new versioned domain instead of rewriting the existing golden outputs.
const seed_child_domain = "foundation.seed_child.v1";
const key_child_domain = "foundation.key_child.v1";

pub const Seed128 = struct {
    bytes: [16]u8,

    pub fn eql(a: Seed128, b: Seed128) bool {
        return std.mem.eql(u8, &a.bytes, &b.bytes);
    }

    pub fn parseLowerHex(text: []const u8) error{InvalidSeed}!Seed128 {
        if (text.len != 32) return error.InvalidSeed;
        var result: Seed128 = undefined;
        for (0..result.bytes.len) |index| {
            const high = lowerHex(text[index * 2]) orelse return error.InvalidSeed;
            const low = lowerHex(text[index * 2 + 1]) orelse return error.InvalidSeed;
            result.bytes[index] = (high << 4) | low;
        }
        return result;
    }

    pub fn formatLowerHex(self: Seed128) [32]u8 {
        const alphabet = "0123456789abcdef";
        var result: [32]u8 = undefined;
        for (self.bytes, 0..) |byte, index| {
            result[index * 2] = alphabet[byte >> 4];
            result[index * 2 + 1] = alphabet[byte & 0x0f];
        }
        return result;
    }
};

pub const DerivationContext = struct {
    /// Every field participates in derivation. Callers supply all state;
    /// ambient clocks, process/pointer state, host byte order, and global RNGs
    /// are outside this contract.
    root_seed: Seed128,
    generator_id: identity.GeneratorId,
    generator_version: version.GeneratorVersion,
    algorithm_id: identity.AlgorithmId,
    algorithm_version: version.AlgorithmVersion,
};

pub fn deriveSeed(context: DerivationContext, stable_keys: []const []const u8) canonical_data.Error!Seed128 {
    const digest = try deriveDigest(seed_child_domain, context, stable_keys);
    return .{ .bytes = digest.bytes[0..16].* };
}

pub fn deriveKey(context: DerivationContext, stable_keys: []const []const u8) canonical_data.Error![32]u8 {
    const digest = try deriveDigest(key_child_domain, context, stable_keys);
    return digest.bytes;
}

pub const RationalSubTick = struct {
    numerator: u32,
    denominator: u32,

    pub fn init(numerator: u32, denominator: u32) error{InvalidSubTick}!RationalSubTick {
        if (denominator == 0 or numerator == 0 or numerator >= denominator) return error.InvalidSubTick;
        const divisor = gcd(numerator, denominator);
        return .{ .numerator = numerator / divisor, .denominator = denominator / divisor };
    }
};

/// Exact position in an externally defined tick domain:
/// `tick + numerator / denominator`. The optional fraction is canonical,
/// nonnegative, and less than one; therefore `{-1, 1/2}` means -0.5 ticks.
/// SceneTime deliberately does not define seconds per tick.
pub const SceneTime = struct {
    tick: i64,
    sub_tick: ?RationalSubTick = null,

    pub fn init(tick: i64, numerator: u32, denominator: u32) error{InvalidSubTick}!SceneTime {
        if (numerator == 0) {
            if (denominator == 0) return error.InvalidSubTick;
            return .{ .tick = tick, .sub_tick = null };
        }
        return .{ .tick = tick, .sub_tick = try RationalSubTick.init(numerator, denominator) };
    }
};

fn deriveDigest(
    domain: []const u8,
    context: DerivationContext,
    stable_keys: []const []const u8,
) canonical_data.Error!canonical_data.Sha256Digest {
    var generator_version_bytes: [12]u8 = undefined;
    writeVersion(&generator_version_bytes, context.generator_version.major, context.generator_version.minor, context.generator_version.patch);
    var algorithm_version_bytes: [12]u8 = undefined;
    writeVersion(&algorithm_version_bytes, context.algorithm_version.major, context.algorithm_version.minor, context.algorithm_version.patch);
    if (stable_keys.len > 64) return error.TooManyFields;
    var fields: [69][]const u8 = undefined;
    fields[0] = &context.root_seed.bytes;
    fields[1] = &context.generator_id.bytes;
    fields[2] = &generator_version_bytes;
    fields[3] = &context.algorithm_id.bytes;
    fields[4] = &algorithm_version_bytes;
    for (stable_keys, 0..) |key, index| fields[5 + index] = key;
    return canonical_data.hashDomainSeparated(domain, fields[0 .. 5 + stable_keys.len]);
}

fn writeVersion(output: *[12]u8, major: u32, minor: u32, patch: u32) void {
    std.mem.writeInt(u32, output[0..4], major, .big);
    std.mem.writeInt(u32, output[4..8], minor, .big);
    std.mem.writeInt(u32, output[8..12], patch, .big);
}

fn gcd(a_initial: u32, b_initial: u32) u32 {
    var a = a_initial;
    var b = b_initial;
    while (b != 0) {
        const remainder = a % b;
        a = b;
        b = remainder;
    }
    return a;
}

fn lowerHex(byte: u8) ?u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        else => null,
    };
}
