const std = @import("std");
const foundation = @import("foundation");

pub fn isCanonical(source: []const u8, scratch: []u8) bool {
    var parsed = std.json.parseFromSlice(
        std.json.Value,
        std.heap.page_allocator,
        source,
        .{ .parse_numbers = false },
    ) catch return false;
    defer parsed.deinit();
    var writer = foundation.canonical_data.Writer.init(scratch);
    writeValue(&writer, parsed.value) catch return false;
    return std.mem.eql(u8, source, writer.bytes());
}

pub fn writeValue(writer: *foundation.canonical_data.Writer, value: std.json.Value) foundation.canonical_data.Error!void {
    switch (value) {
        .null => try writer.raw("null"),
        .bool => |boolean| try writer.boolean(boolean),
        .integer => |integer| try writer.i64Value(integer),
        .float => |float| try writeF64(writer, float),
        .number_string => |number| try writeNumberString(writer, number),
        .string => |string| try writer.jsonString(string),
        .array => |array| {
            try writer.raw("[");
            for (array.items, 0..) |item, index| {
                if (index != 0) try writer.raw(",");
                try writeValue(writer, item);
            }
            try writer.raw("]");
        },
        .object => |object| try writeObject(writer, object),
    }
}

fn writeObject(writer: *foundation.canonical_data.Writer, object: std.json.ObjectMap) foundation.canonical_data.Error!void {
    try writer.raw("{");
    var previous: ?[]const u8 = null;
    for (0..object.count()) |emitted| {
        var selected_key: ?[]const u8 = null;
        var selected_value: std.json.Value = undefined;
        var iterator = object.iterator();
        while (iterator.next()) |entry| {
            const key = entry.key_ptr.*;
            if (previous) |previous_key| if (std.mem.order(u8, key, previous_key) != .gt) continue;
            if (selected_key == null or std.mem.order(u8, key, selected_key.?) == .lt) {
                selected_key = key;
                selected_value = entry.value_ptr.*;
            }
        }
        if (emitted != 0) try writer.raw(",");
        try writer.jsonString(selected_key orelse return error.DuplicateKey);
        try writer.raw(":");
        try writeValue(writer, selected_value);
        previous = selected_key;
    }
    try writer.raw("}");
}

fn writeNumberString(writer: *foundation.canonical_data.Writer, number: []const u8) foundation.canonical_data.Error!void {
    if (std.mem.indexOfAny(u8, number, ".eE") == null) {
        const integer = std.fmt.parseInt(i64, number, 10) catch return error.NonFiniteFloat;
        return writer.i64Value(integer);
    }
    const float = std.fmt.parseFloat(f64, number) catch return error.NonFiniteFloat;
    return writeF64(writer, float);
}

fn writeF64(writer: *foundation.canonical_data.Writer, raw_value: f64) foundation.canonical_data.Error!void {
    if (!std.math.isFinite(raw_value)) return error.NonFiniteFloat;
    const value: f64 = if (raw_value == 0.0) 0.0 else raw_value;
    var buffer: [64]u8 = undefined;
    const rendered = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch return error.OutputTooSmall;
    try writer.raw(rendered);
}
