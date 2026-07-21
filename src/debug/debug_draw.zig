const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const humanoid = @import("humanoid");
const character = @import("character");
const sprite = @import("sprite_batch");

pub const command_capacity: usize = 256;
pub const line_thickness_pixels: f32 = 2;
pub const marker_size_pixels: f32 = 7;

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
        const presentation = toPresentation(world_position);
        try buffer.append(.{
            .world_position = presentation.toArray(),
            .rotation = 0,
            .scale = .{ marker_size_pixels, marker_size_pixels },
            .pivot = .{ 0.5, 0.5 },
            .uv_rect = .{ 0, 0, 0.5, 0.5 },
            .tint = color,
            .texture_page = 0,
            .order = debugOrder(buffer.count),
        });
    }

    pub fn addLine(buffer: *CommandBuffer, from_world: math.Vec2, to_world: math.Vec2, color: Color) !void {
        if (!from_world.isFinite() or !to_world.isFinite()) return error.NonFiniteDebugPrimitive;
        const from = toPresentation(from_world);
        const to = toPresentation(to_world);
        const delta = to.sub(from);
        const length = delta.length();
        if (!std.math.isFinite(length)) return error.NonFiniteDebugPrimitive;
        if (length <= std.math.floatEps(f32)) return buffer.addMarker(from_world, color);
        try buffer.append(.{
            .world_position = from.toArray(),
            .rotation = std.math.atan2(delta.y, delta.x),
            .scale = .{ length, line_thickness_pixels },
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

    fn append(buffer: *CommandBuffer, command: sprite.SpriteRequest) !void {
        if (buffer.count == buffer.commands.len) {
            buffer.overflow_count += 1;
            return error.DebugCommandCapacityExceeded;
        }
        buffer.commands[buffer.count] = command;
        buffer.count += 1;
    }
};

fn toPresentation(world_position: math.Vec2) math.Vec2 {
    return humanoid.presentation_origin.add(world_position.scale(humanoid.pixels_per_meter));
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
