const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const character = @import("character");
const sprite = @import("sprite_batch");

pub const command_capacity: usize = 2048;
pub const line_thickness_meters: f32 = 2.0 / 82.0;
pub const marker_size_meters: f32 = 7.0 / 82.0;

pub const Color = [4]f32;

pub const CommandBuffer = struct {
    commands: [command_capacity]sprite.SpriteRequest = undefined,
    count: usize = 0,
    overflow_count: u64 = 0,
    submission_allocations: u64 = 0,

    pub fn beginFrame(buffer: *CommandBuffer) void {
        buffer.count = 0;
    }

    pub fn addMarker(buffer: *CommandBuffer, world_position: math.Vec2, color: Color) !void {
        if (!world_position.isFinite()) return error.NonFiniteDebugPrimitive;
        try buffer.append(.{
            .world_position = world_position.toArray(),
            .rotation = 0,
            .scale = .{ marker_size_meters, marker_size_meters },
            .pivot = .{ 0.5, 0.5 },
            .uv_rect = .{ 0, 0, 0.5, 0.5 },
            .tint = color,
            .texture_page = 0,
            .order = debugOrder(buffer.count),
        });
    }

    pub fn addLine(buffer: *CommandBuffer, from_world: math.Vec2, to_world: math.Vec2, color: Color) !void {
        if (!from_world.isFinite() or !to_world.isFinite()) return error.NonFiniteDebugPrimitive;
        const delta = to_world.sub(from_world);
        const length = delta.length();
        if (!std.math.isFinite(length)) return error.NonFiniteDebugPrimitive;
        if (length <= std.math.floatEps(f32)) return buffer.addMarker(from_world, color);
        try buffer.append(.{
            .world_position = from_world.toArray(),
            .rotation = std.math.atan2(delta.y, delta.x),
            .scale = .{ length, line_thickness_meters },
            .pivot = .{ 0, 0.5 },
            .uv_rect = .{ 0, 0, 0.5, 0.5 },
            .tint = color,
            .texture_page = 0,
            .order = debugOrder(buffer.count),
        });
    }

    pub fn addAabb(buffer: *CommandBuffer, bounds: collider.Aabb, color: Color) !void {
        try bounds.validate();
        const minimum = bounds.minimum;
        const maximum = bounds.maximum;
        try buffer.addLine(minimum, .{ .x = maximum.x, .y = minimum.y }, color);
        try buffer.addLine(.{ .x = maximum.x, .y = minimum.y }, maximum, color);
        try buffer.addLine(maximum, .{ .x = minimum.x, .y = maximum.y }, color);
        try buffer.addLine(.{ .x = minimum.x, .y = maximum.y }, minimum, color);
    }

    /// Adds a tiny bounded 3x5 diagnostic label using the same debug sprite
    /// command buffer. This is intentionally allocation-free and returns the
    /// exact number of commands appended for capacity accounting.
    pub fn addLabel(
        buffer: *CommandBuffer,
        origin: math.Vec2,
        text: []const u8,
        color: Color,
    ) !u32 {
        const pixel_size: f32 = 1.25 / 82.0;
        const advance: f32 = 4.25 / 82.0;
        var appended: u32 = 0;
        for (text, 0..) |raw, character_index| {
            const glyph = labelGlyph(toUpper(raw));
            for (0..5) |row| {
                for (0..3) |column| {
                    const bit: u4 = @intCast(row * 3 + (2 - column));
                    if (glyph & (@as(u16, 1) << bit) == 0) continue;
                    try buffer.append(.{
                        .world_position = .{
                            origin.x +
                                @as(f32, @floatFromInt(character_index)) *
                                    advance +
                                @as(f32, @floatFromInt(column)) * pixel_size,
                            origin.y -
                                @as(f32, @floatFromInt(row)) * pixel_size,
                        },
                        .rotation = 0,
                        .scale = .{ pixel_size, pixel_size },
                        .pivot = .{ 0.5, 0.5 },
                        .uv_rect = .{ 0, 0, 0.5, 0.5 },
                        .tint = color,
                        .texture_page = 0,
                        .order = debugOrder(buffer.count),
                    });
                    appended += 1;
                }
            }
        }
        return appended;
    }

    pub fn submit(buffer: *const CommandBuffer, batch: *sprite.SpriteBatch) !u32 {
        for (buffer.commands[0..buffer.count]) |command| try batch.submit(command);
        return @intCast(buffer.count);
    }

    pub fn submitUnified(buffer: *const CommandBuffer, queue: anytype) !u32 {
        for (buffer.commands[0..buffer.count]) |command| _ = try queue.submitSprite(command);
        return @intCast(buffer.count);
    }

    fn append(buffer: *CommandBuffer, command: sprite.SpriteRequest) !void {
        if (buffer.count == buffer.commands.len) {
            buffer.overflow_count += 1;
            return error.DebugCommandCapacityExceeded;
        }
        buffer.commands[buffer.count] = command;
        buffer.count += 1;
    }
};

fn toUpper(value: u8) u8 {
    return if (value >= 'a' and value <= 'z') value - ('a' - 'A') else value;
}

fn glyphRows(a: u3, b: u3, c: u3, d: u3, e: u3) u16 {
    return @as(u16, a) |
        (@as(u16, b) << 3) |
        (@as(u16, c) << 6) |
        (@as(u16, d) << 9) |
        (@as(u16, e) << 12);
}

fn labelGlyph(value: u8) u16 {
    return switch (value) {
        'A' => glyphRows(0b010, 0b101, 0b111, 0b101, 0b101),
        'B' => glyphRows(0b110, 0b101, 0b110, 0b101, 0b110),
        'C' => glyphRows(0b011, 0b100, 0b100, 0b100, 0b011),
        'D' => glyphRows(0b110, 0b101, 0b101, 0b101, 0b110),
        'E' => glyphRows(0b111, 0b100, 0b110, 0b100, 0b111),
        'F' => glyphRows(0b111, 0b100, 0b110, 0b100, 0b100),
        'G' => glyphRows(0b011, 0b100, 0b101, 0b101, 0b011),
        'H' => glyphRows(0b101, 0b101, 0b111, 0b101, 0b101),
        'I' => glyphRows(0b111, 0b010, 0b010, 0b010, 0b111),
        'J' => glyphRows(0b001, 0b001, 0b001, 0b101, 0b010),
        'K' => glyphRows(0b101, 0b101, 0b110, 0b101, 0b101),
        'L' => glyphRows(0b100, 0b100, 0b100, 0b100, 0b111),
        'M' => glyphRows(0b101, 0b111, 0b111, 0b101, 0b101),
        'N' => glyphRows(0b101, 0b111, 0b111, 0b111, 0b101),
        'O' => glyphRows(0b010, 0b101, 0b101, 0b101, 0b010),
        'P' => glyphRows(0b110, 0b101, 0b110, 0b100, 0b100),
        'Q' => glyphRows(0b010, 0b101, 0b101, 0b111, 0b011),
        'R' => glyphRows(0b110, 0b101, 0b110, 0b101, 0b101),
        'S' => glyphRows(0b011, 0b100, 0b010, 0b001, 0b110),
        'T' => glyphRows(0b111, 0b010, 0b010, 0b010, 0b010),
        'U' => glyphRows(0b101, 0b101, 0b101, 0b101, 0b111),
        'V' => glyphRows(0b101, 0b101, 0b101, 0b101, 0b010),
        'W' => glyphRows(0b101, 0b101, 0b111, 0b111, 0b101),
        'X' => glyphRows(0b101, 0b101, 0b010, 0b101, 0b101),
        'Y' => glyphRows(0b101, 0b101, 0b010, 0b010, 0b010),
        'Z' => glyphRows(0b111, 0b001, 0b010, 0b100, 0b111),
        '0' => glyphRows(0b111, 0b101, 0b101, 0b101, 0b111),
        '1' => glyphRows(0b010, 0b110, 0b010, 0b010, 0b111),
        '2' => glyphRows(0b110, 0b001, 0b010, 0b100, 0b111),
        '3' => glyphRows(0b110, 0b001, 0b010, 0b001, 0b110),
        '4' => glyphRows(0b101, 0b101, 0b111, 0b001, 0b001),
        '5' => glyphRows(0b111, 0b100, 0b110, 0b001, 0b110),
        '6' => glyphRows(0b011, 0b100, 0b110, 0b101, 0b010),
        '7' => glyphRows(0b111, 0b001, 0b010, 0b010, 0b010),
        '8' => glyphRows(0b010, 0b101, 0b010, 0b101, 0b010),
        '9' => glyphRows(0b010, 0b101, 0b011, 0b001, 0b110),
        '/' => glyphRows(0b001, 0b001, 0b010, 0b100, 0b100),
        '-' => glyphRows(0, 0, 0b111, 0, 0),
        '.' => glyphRows(0, 0, 0, 0, 0b010),
        ':' => glyphRows(0, 0b010, 0, 0b010, 0),
        ' ', '_' => 0,
        else => glyphRows(0b111, 0b001, 0b010, 0, 0b010),
    };
}

fn debugOrder(index: usize) sprite.OrderInput {
    return .{
        .scene_layer = character.SceneLayers.debug_overlay,
        .interaction_layer = 0,
        .actor_layer = 0,
        .body_part_layer = @intCast(index),
    };
}

comptime {
    if (command_capacity == 0 or command_capacity > std.math.maxInt(u16)) {
        @compileError("debug command capacity must fit the sprite ordering key");
    }
}
