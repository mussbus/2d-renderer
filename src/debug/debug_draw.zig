const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const character = @import("character");
const sprite = @import("sprite_batch");

pub const command_capacity: usize = 512;
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
