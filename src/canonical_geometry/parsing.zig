const std = @import("std");
const canonical = @import("canonical_model");
const identity = @import("identity.zig");
const schema = @import("schema.zig");

pub const ParseError = error{
    OutOfMemory,
    InvalidJson,
    ExpectedObject,
    ExpectedArray,
    ExpectedString,
    ExpectedBoolean,
    ExpectedNumber,
    InvalidNumber,
    IntegerOutOfRange,
    InvalidEnumValue,
    InvalidCanonicalId,
    MissingField,
    UnknownField,
    InvalidArrayLength,
    InvalidSha256,
};

pub const ParsedGeometry = struct {
    parsed_json: std.json.Parsed(std.json.Value),
    value: schema.GeometryDefinition,

    pub fn deinit(self: *ParsedGeometry) void {
        self.parsed_json.deinit();
        self.* = undefined;
    }
};

pub fn parse(allocator: std.mem.Allocator, source_bytes: []const u8) ParseError!ParsedGeometry {
    var parsed_json = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        source_bytes,
        .{ .parse_numbers = false },
    ) catch |parse_error| switch (parse_error) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidJson,
    };
    errdefer parsed_json.deinit();

    return .{
        .value = try parseValue(schema.GeometryDefinition, parsed_json.arena.allocator(), parsed_json.value),
        .parsed_json = parsed_json,
    };
}

fn parseValue(comptime T: type, allocator: std.mem.Allocator, json_value: std.json.Value) ParseError!T {
    if (comptime isTypedStringId(T)) return parseTypedStringId(T, json_value);
    if (comptime T == identity.VertexId or T == identity.FaceId) {
        return .{ .value = try parseInteger(u32, json_value) };
    }
    if (comptime T == identity.Sha256Digest) return parseSha256(json_value);
    if (comptime T == schema.Vec2) return parseVec2(json_value);
    if (comptime T == canonical.math3d.Vec3) return parseVec3(json_value);
    if (comptime T == canonical.math3d.Quaternion) return parseQuaternion(json_value);

    return switch (@typeInfo(T)) {
        .bool => switch (json_value) {
            .bool => |value| value,
            else => error.ExpectedBoolean,
        },
        .float => parseFloat(T, json_value),
        .int => parseInteger(T, json_value),
        .@"enum" => parseEnum(T, json_value),
        .optional => |optional_info| switch (json_value) {
            .null => null,
            else => try parseValue(optional_info.child, allocator, json_value),
        },
        .pointer => |pointer_info| switch (pointer_info.size) {
            .slice => try parseSlice(T, pointer_info.child, allocator, json_value),
            else => @compileError("canonical geometry JSON parser only supports slice pointers"),
        },
        .array => |array_info| try parseArray(T, array_info.child, allocator, json_value),
        .@"struct" => try parseStruct(T, allocator, json_value),
        else => @compileError("unsupported canonical geometry JSON type: " ++ @typeName(T)),
    };
}

fn isTypedStringId(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "kind_name"),
        else => false,
    };
}

fn parseTypedStringId(comptime T: type, json_value: std.json.Value) ParseError!T {
    return T.init(try expectString(json_value)) catch error.InvalidCanonicalId;
}

fn parseSha256(json_value: std.json.Value) ParseError!identity.Sha256Digest {
    const encoded = try expectString(json_value);
    if (encoded.len != 64) return error.InvalidSha256;
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, encoded) catch return error.InvalidSha256;
    return .{ .bytes = bytes };
}

fn parseVec2(json_value: std.json.Value) ParseError!schema.Vec2 {
    const items = try expectArray(json_value);
    if (items.len != 2) return error.InvalidArrayLength;
    return .{ .x = try parseFloat(f32, items[0]), .y = try parseFloat(f32, items[1]) };
}

fn parseVec3(json_value: std.json.Value) ParseError!canonical.math3d.Vec3 {
    const items = try expectArray(json_value);
    if (items.len != 3) return error.InvalidArrayLength;
    return .{
        .x = try parseFloat(f32, items[0]),
        .y = try parseFloat(f32, items[1]),
        .z = try parseFloat(f32, items[2]),
    };
}

fn parseQuaternion(json_value: std.json.Value) ParseError!canonical.math3d.Quaternion {
    const items = try expectArray(json_value);
    if (items.len != 4) return error.InvalidArrayLength;
    return .{
        .x = try parseFloat(f32, items[0]),
        .y = try parseFloat(f32, items[1]),
        .z = try parseFloat(f32, items[2]),
        .w = try parseFloat(f32, items[3]),
    };
}

fn parseStruct(comptime T: type, allocator: std.mem.Allocator, json_value: std.json.Value) ParseError!T {
    const object = try expectObject(json_value);
    const fields = @typeInfo(T).@"struct".fields;

    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        var known = false;
        inline for (fields) |field| {
            if (std.mem.eql(u8, entry.key_ptr.*, field.name)) known = true;
        }
        if (!known) return error.UnknownField;
    }

    var result: T = undefined;
    inline for (fields) |field| {
        if (object.get(field.name)) |field_value| {
            @field(result, field.name) = try parseValue(field.type, allocator, field_value);
        } else if (field.defaultValue()) |default_value| {
            @field(result, field.name) = default_value;
        } else {
            return error.MissingField;
        }
    }
    return result;
}

fn parseSlice(
    comptime T: type,
    comptime Child: type,
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!T {
    const items = try expectArray(json_value);
    const result = try allocator.alloc(Child, items.len);
    for (items, 0..) |item, index| result[index] = try parseValue(Child, allocator, item);
    return result;
}

fn parseArray(
    comptime T: type,
    comptime Child: type,
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!T {
    const items = try expectArray(json_value);
    if (items.len != @typeInfo(T).array.len) return error.InvalidArrayLength;
    var result: T = undefined;
    for (items, 0..) |item, index| result[index] = try parseValue(Child, allocator, item);
    return result;
}

fn parseFloat(comptime T: type, json_value: std.json.Value) ParseError!T {
    const value = switch (json_value) {
        .number_string => |bytes| std.fmt.parseFloat(T, bytes) catch return error.InvalidNumber,
        .integer => |integer| @as(T, @floatFromInt(integer)),
        .float => |float| @as(T, @floatCast(float)),
        else => return error.ExpectedNumber,
    };
    if (!std.math.isFinite(value)) return error.InvalidNumber;
    return value;
}

fn parseInteger(comptime T: type, json_value: std.json.Value) ParseError!T {
    return switch (json_value) {
        .number_string => |bytes| std.fmt.parseInt(T, bytes, 10) catch |parse_error| switch (parse_error) {
            error.Overflow => error.IntegerOutOfRange,
            error.InvalidCharacter => error.InvalidNumber,
        },
        .integer => |integer| std.math.cast(T, integer) orelse error.IntegerOutOfRange,
        else => error.ExpectedNumber,
    };
}

fn parseEnum(comptime T: type, json_value: std.json.Value) ParseError!T {
    return std.meta.stringToEnum(T, try expectString(json_value)) orelse error.InvalidEnumValue;
}

fn expectString(json_value: std.json.Value) ParseError![]const u8 {
    return switch (json_value) {
        .string => |bytes| bytes,
        else => error.ExpectedString,
    };
}

fn expectArray(json_value: std.json.Value) ParseError![]const std.json.Value {
    return switch (json_value) {
        .array => |array| array.items,
        else => error.ExpectedArray,
    };
}

fn expectObject(json_value: std.json.Value) ParseError!std.json.ObjectMap {
    return switch (json_value) {
        .object => |object| object,
        else => error.ExpectedObject,
    };
}
