const std = @import("std");

pub const Error = error{
    DuplicateKey,
    InvalidHashDomain,
    InvalidHex,
    InvalidUuid,
    InvalidUtf8,
    NonFiniteFloat,
    OutputTooSmall,
    ScratchTooSmall,
    TooManyFields,
};

pub const Sha256Digest = struct {
    bytes: [32]u8,

    pub fn eql(a: Sha256Digest, b: Sha256Digest) bool {
        return std.mem.eql(u8, &a.bytes, &b.bytes);
    }

    pub fn order(a: Sha256Digest, b: Sha256Digest) std.math.Order {
        return std.mem.order(u8, &a.bytes, &b.bytes);
    }

    pub fn parseLowerHex(text: []const u8) Error!Sha256Digest {
        if (text.len != 64) return error.InvalidHex;
        var result: Sha256Digest = undefined;
        for (0..result.bytes.len) |index| {
            const high = try lowerHexValue(text[index * 2]);
            const low = try lowerHexValue(text[index * 2 + 1]);
            result.bytes[index] = (high << 4) | low;
        }
        return result;
    }

    pub fn formatLowerHex(self: Sha256Digest) [64]u8 {
        const alphabet = "0123456789abcdef";
        var result: [64]u8 = undefined;
        for (self.bytes, 0..) |byte, index| {
            result[index * 2] = alphabet[byte >> 4];
            result[index * 2 + 1] = alphabet[byte & 0x0f];
        }
        return result;
    }
};

pub const Field = struct {
    name: []const u8,
    /// Trusted already-canonical JSON fragment. External/authored input must be
    /// parsed, validated, and canonicalized before reaching this field.
    canonical_value: []const u8,
};

pub const Record = struct {
    key: []const u8,
    /// Trusted already-canonical JSON fragment, not arbitrary source JSON.
    canonical_value: []const u8,
};

// Persistent framing protocol. Incompatible framing requires a new reviewed
// versioned domain and must not silently change the v1 golden outputs.
const domain_hash_protocol = "foundation.domain_hash.v1";

pub const Writer = struct {
    output: []u8,
    length: usize = 0,

    pub fn init(output: []u8) Writer {
        return .{ .output = output };
    }

    pub fn bytes(self: *const Writer) []const u8 {
        return self.output[0..self.length];
    }

    /// Appends a trusted already-canonical fragment. This is a low-level
    /// composition primitive, not a parser or validator for external JSON.
    pub fn raw(self: *Writer, value: []const u8) Error!void {
        if (value.len > self.output.len - self.length) return error.OutputTooSmall;
        @memcpy(self.output[self.length..][0..value.len], value);
        self.length += value.len;
    }

    pub fn byte(self: *Writer, value: u8) Error!void {
        if (self.length == self.output.len) return error.OutputTooSmall;
        self.output[self.length] = value;
        self.length += 1;
    }

    pub fn jsonString(self: *Writer, value: []const u8) Error!void {
        if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidUtf8;
        try self.byte('"');
        for (value) |character| switch (character) {
            '"' => try self.raw("\\\""),
            '\\' => try self.raw("\\\\"),
            0x08 => try self.raw("\\b"),
            0x0c => try self.raw("\\f"),
            '\n' => try self.raw("\\n"),
            '\r' => try self.raw("\\r"),
            '\t' => try self.raw("\\t"),
            0x00...0x07, 0x0b, 0x0e...0x1f => {
                const alphabet = "0123456789abcdef";
                try self.raw("\\u00");
                try self.byte(alphabet[character >> 4]);
                try self.byte(alphabet[character & 0x0f]);
            },
            else => try self.byte(character),
        };
        try self.byte('"');
    }

    pub fn f32Value(self: *Writer, value: f32) Error!void {
        if (!std.math.isFinite(value)) return error.NonFiniteFloat;
        const normalized: f32 = if (value == 0.0) 0.0 else value;
        var buffer: [64]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, "{d}", .{normalized}) catch
            return error.OutputTooSmall;
        try self.raw(text);
    }

    pub fn u64Value(self: *Writer, value: u64) Error!void {
        var buffer: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch
            return error.OutputTooSmall;
        try self.raw(text);
    }

    pub fn i64Value(self: *Writer, value: i64) Error!void {
        var buffer: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch
            return error.OutputTooSmall;
        try self.raw(text);
    }

    pub fn boolean(self: *Writer, value: bool) Error!void {
        try self.raw(if (value) "true" else "false");
    }

    pub fn uuidValue(self: *Writer, value: [16]u8) Error!void {
        var any_nonzero = false;
        for (value) |byte_value| any_nonzero = any_nonzero or byte_value != 0;
        const uuid_version = value[6] >> 4;
        if (!any_nonzero or value[8] & 0xc0 != 0x80 or uuid_version < 1 or uuid_version > 8) {
            return error.InvalidUuid;
        }
        const alphabet = "0123456789abcdef";
        try self.byte('"');
        for (value, 0..) |byte_value, index| {
            if (index == 4 or index == 6 or index == 8 or index == 10) try self.byte('-');
            try self.byte(alphabet[byte_value >> 4]);
            try self.byte(alphabet[byte_value & 0x0f]);
        }
        try self.byte('"');
    }

    pub fn sha256Value(self: *Writer, value: Sha256Digest) Error!void {
        const formatted = value.formatLowerHex();
        try self.byte('"');
        try self.raw(&formatted);
        try self.byte('"');
    }

    pub fn versionValue(self: *Writer, major: u32, minor: u32, patch: u32) Error!void {
        var buffer: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, "{d}.{d}.{d}", .{ major, minor, patch }) catch
            return error.OutputTooSmall;
        try self.jsonString(text);
    }

    pub fn object(self: *Writer, fields: []const Field, index_scratch: []usize) Error!void {
        if (index_scratch.len < fields.len) return error.ScratchTooSmall;
        const order = index_scratch[0..fields.len];
        for (order, 0..) |*slot, index| slot.* = index;
        insertionSortFields(fields, order);
        var duplicate_index: usize = 1;
        while (duplicate_index < order.len) : (duplicate_index += 1) {
            if (std.mem.eql(u8, fields[order[duplicate_index]].name, fields[order[duplicate_index - 1]].name)) {
                return error.DuplicateKey;
            }
        }
        try self.byte('{');
        for (order, 0..) |field_index, output_index| {
            if (output_index != 0) try self.byte(',');
            try self.jsonString(fields[field_index].name);
            try self.byte(':');
            try self.raw(fields[field_index].canonical_value);
        }
        try self.byte('}');
    }

    /// Preserves semantic order. Every value must already be canonical JSON.
    pub fn semanticArray(self: *Writer, values: []const []const u8) Error!void {
        try self.byte('[');
        for (values, 0..) |value, index| {
            if (index != 0) try self.byte(',');
            try self.raw(value);
        }
        try self.byte(']');
    }

    pub fn sortedRecordArray(self: *Writer, records: []const Record, index_scratch: []usize) Error!void {
        if (index_scratch.len < records.len) return error.ScratchTooSmall;
        const order = index_scratch[0..records.len];
        for (order, 0..) |*slot, index| slot.* = index;
        insertionSortRecords(records, order);
        var duplicate_index: usize = 1;
        while (duplicate_index < order.len) : (duplicate_index += 1) {
            if (std.mem.eql(u8, records[order[duplicate_index]].key, records[order[duplicate_index - 1]].key)) {
                return error.DuplicateKey;
            }
        }
        try self.byte('[');
        for (order, 0..) |record_index, output_index| {
            if (output_index != 0) try self.byte(',');
            try self.raw(records[record_index].canonical_value);
        }
        try self.byte(']');
    }
};

pub fn hashDomainSeparated(domain: []const u8, fields: []const []const u8) Error!Sha256Digest {
    if (!validHashDomain(domain)) return error.InvalidHashDomain;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateLengthFramed(&hasher, domain_hash_protocol);
    updateLengthFramed(&hasher, domain);
    var count_buffer: [8]u8 = undefined;
    std.mem.writeInt(u64, &count_buffer, fields.len, .big);
    hasher.update(&count_buffer);
    for (fields) |field| updateLengthFramed(&hasher, field);
    var digest: Sha256Digest = undefined;
    hasher.final(&digest.bytes);
    return digest;
}

pub fn validHashDomain(domain: []const u8) bool {
    if (domain.len == 0 or domain.len > 127) return false;
    if (domain[0] == '.' or domain[domain.len - 1] == '.') return false;
    var previous_was_dot = false;
    for (domain) |byte| {
        const valid = (byte >= 'a' and byte <= 'z') or
            (byte >= '0' and byte <= '9') or byte == '_' or byte == '.';
        if (!valid) return false;
        if (byte == '.' and previous_was_dot) return false;
        previous_was_dot = byte == '.';
    }
    return true;
}

fn updateLengthFramed(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    var length_buffer: [8]u8 = undefined;
    std.mem.writeInt(u64, &length_buffer, value.len, .big);
    hasher.update(&length_buffer);
    hasher.update(value);
}

fn insertionSortFields(fields: []const Field, order: []usize) void {
    var index: usize = 1;
    while (index < order.len) : (index += 1) {
        const value = order[index];
        var position = index;
        while (position > 0 and std.mem.order(u8, fields[value].name, fields[order[position - 1]].name) == .lt) : (position -= 1) {
            order[position] = order[position - 1];
        }
        order[position] = value;
    }
}

fn insertionSortRecords(records: []const Record, order: []usize) void {
    var index: usize = 1;
    while (index < order.len) : (index += 1) {
        const value = order[index];
        var position = index;
        while (position > 0 and std.mem.order(u8, records[value].key, records[order[position - 1]].key) == .lt) : (position -= 1) {
            order[position] = order[position - 1];
        }
        order[position] = value;
    }
}

fn lowerHexValue(byte: u8) Error!u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        else => error.InvalidHex,
    };
}
