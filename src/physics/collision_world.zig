const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const fault_injection = @import("fault_injection");

pub const maximum_static_colliders: usize = 64;

pub const DemoColliderId = enum(collider.ColliderId) {
    floor = 1,
    right_wall = 2,
    ceiling = 3,
    raised_platform_1 = 4,
    raised_platform_2 = 5,
};

pub const HorizontalSweep = struct {
    resolved_position_x: f32,
    hit_wall: bool = false,
    collider_id: collider.ColliderId = collider.invalid_collider_id,
};

pub const VerticalSweep = struct {
    resolved_position_y: f32,
    hit_ground: bool = false,
    hit_ceiling: bool = false,
    collider_id: collider.ColliderId = collider.invalid_collider_id,
};

pub const CollisionWorld = struct {
    allocator: std.mem.Allocator,
    colliders: []const collider.StaticCollider,

    pub fn init(
        allocator: std.mem.Allocator,
        inputs: []const collider.StaticColliderInput,
        injector: ?fault_injection.Injector,
    ) !CollisionWorld {
        if (inputs.len == 0) return error.EmptyCollisionWorld;
        if (inputs.len > maximum_static_colliders) return error.SupportedCountOverflow;
        _ = std.math.mul(usize, inputs.len, @sizeOf(collider.StaticCollider)) catch return error.ByteSizeOverflow;

        const storage = allocator.alloc(collider.StaticCollider, inputs.len) catch return error.AllocationFailure;
        errdefer allocator.free(storage);
        try after(injector, .collision_world_collider_allocation);
        for (inputs, 0..) |input, index| {
            if (input.id == collider.invalid_collider_id) return error.InvalidColliderIdentifier;
            try input.bounds.validate();
            if (!input.solid) return error.UnsupportedNonSolidCollider;
            for (inputs[0..index]) |existing| {
                if (existing.id == input.id) return error.DuplicateColliderIdentifier;
            }
            storage[index] = .{
                .id = input.id,
                .bounds = input.bounds,
                .solid = input.solid,
                .ground_query_eligible = input.ground_query_eligible,
            };
        }
        return .{ .allocator = allocator, .colliders = storage };
    }

    pub fn initDemo(allocator: std.mem.Allocator, injector: ?fault_injection.Injector) !CollisionWorld {
        const inputs = demoColliderInputs();
        return init(allocator, &inputs, injector);
    }

    pub fn deinit(world: *CollisionWorld) void {
        world.allocator.free(world.colliders);
        world.* = undefined;
    }

    pub fn containsPenetration(world: CollisionWorld, bounds: collider.Aabb) bool {
        for (world.colliders) |static_collider| {
            if (static_collider.solid and collider.overlapsStrict(bounds, static_collider.bounds)) return true;
        }
        return false;
    }

    pub fn containsPenetrationBeyond(
        world: CollisionWorld,
        bounds: collider.Aabb,
        epsilon: f32,
    ) !bool {
        try collider.validateEpsilon(epsilon);
        for (world.colliders) |static_collider| {
            if (!static_collider.solid) continue;
            const overlap_x = @min(bounds.maximum.x, static_collider.bounds.maximum.x) -
                @max(bounds.minimum.x, static_collider.bounds.minimum.x);
            const overlap_y = @min(bounds.maximum.y, static_collider.bounds.maximum.y) -
                @max(bounds.minimum.y, static_collider.bounds.minimum.y);
            if (overlap_x > epsilon and overlap_y > epsilon) return true;
        }
        return false;
    }

    pub fn supportingCollider(
        world: CollisionWorld,
        bounds: collider.Aabb,
        epsilon: f32,
    ) !?collider.ColliderId {
        try collider.validateEpsilon(epsilon);
        for (world.colliders) |static_collider| {
            if (!static_collider.solid or !static_collider.ground_query_eligible) continue;
            if (!collider.overlapsX(bounds, static_collider.bounds, epsilon)) continue;
            if (@abs(bounds.minimum.y - static_collider.bounds.maximum.y) <= epsilon) return static_collider.id;
        }
        return null;
    }

    pub fn sweepHorizontal(
        world: CollisionWorld,
        position: math.Vec2,
        half_extents: math.Vec2,
        delta_x: f32,
        epsilon: f32,
    ) !HorizontalSweep {
        if (!std.math.isFinite(delta_x)) return error.NonFiniteMovement;
        try collider.validateEpsilon(epsilon);
        const current = try collider.characterBounds(position, half_extents);
        var result = HorizontalSweep{ .resolved_position_x = position.x + delta_x };
        if (delta_x == 0) return result;

        for (world.colliders) |static_collider| {
            if (!static_collider.solid or !collider.overlapsY(current, static_collider.bounds, epsilon)) continue;
            if (delta_x > 0) {
                const start_edge = current.maximum.x;
                const end_edge = start_edge + delta_x;
                const obstacle = static_collider.bounds.minimum.x;
                if (start_edge <= obstacle + epsilon and end_edge >= obstacle) {
                    const candidate = obstacle - half_extents.x;
                    if (!result.hit_wall or candidate < result.resolved_position_x) {
                        result = .{ .resolved_position_x = candidate, .hit_wall = true, .collider_id = static_collider.id };
                    }
                }
            } else {
                const start_edge = current.minimum.x;
                const end_edge = start_edge + delta_x;
                const obstacle = static_collider.bounds.maximum.x;
                if (start_edge >= obstacle - epsilon and end_edge <= obstacle) {
                    const candidate = obstacle + half_extents.x;
                    if (!result.hit_wall or candidate > result.resolved_position_x) {
                        result = .{ .resolved_position_x = candidate, .hit_wall = true, .collider_id = static_collider.id };
                    }
                }
            }
        }
        return result;
    }

    pub fn sweepVertical(
        world: CollisionWorld,
        position: math.Vec2,
        half_extents: math.Vec2,
        delta_y: f32,
        epsilon: f32,
    ) !VerticalSweep {
        if (!std.math.isFinite(delta_y)) return error.NonFiniteMovement;
        try collider.validateEpsilon(epsilon);
        const current = try collider.characterBounds(position, half_extents);
        var result = VerticalSweep{ .resolved_position_y = position.y + delta_y };
        if (delta_y == 0) return result;

        for (world.colliders) |static_collider| {
            if (!static_collider.solid or !collider.overlapsX(current, static_collider.bounds, epsilon)) continue;
            if (delta_y > 0) {
                const start_edge = current.maximum.y;
                const end_edge = start_edge + delta_y;
                const obstacle = static_collider.bounds.minimum.y;
                if (start_edge <= obstacle + epsilon and end_edge >= obstacle) {
                    const candidate = obstacle - half_extents.y;
                    if (!result.hit_ceiling or candidate < result.resolved_position_y) {
                        result = .{ .resolved_position_y = candidate, .hit_ceiling = true, .collider_id = static_collider.id };
                    }
                }
            } else {
                const start_edge = current.minimum.y;
                const end_edge = start_edge + delta_y;
                const obstacle = static_collider.bounds.maximum.y;
                if (start_edge >= obstacle - epsilon and end_edge <= obstacle) {
                    const candidate = obstacle + half_extents.y;
                    if (!result.hit_ground or candidate > result.resolved_position_y) {
                        result = .{ .resolved_position_y = candidate, .hit_ground = true, .collider_id = static_collider.id };
                    }
                }
            }
        }
        return result;
    }
};

pub fn demoColliderInputs() [5]collider.StaticColliderInput {
    return .{
        make(.floor, -5.0, -1.0, 5.0, 0.0),
        make(.right_wall, 3.50, 0.0, 3.80, 6.0),
        make(.ceiling, -2.80, 2.60, -1.80, 2.90),
        make(.raised_platform_1, -0.70, 0.90, 0.40, 1.15),
        make(.raised_platform_2, 1.80, 1.50, 2.70, 1.75),
    };
}

fn make(id: DemoColliderId, min_x: f32, min_y: f32, max_x: f32, max_y: f32) collider.StaticColliderInput {
    return .{
        .id = @intFromEnum(id),
        .bounds = .{ .minimum = .{ .x = min_x, .y = min_y }, .maximum = .{ .x = max_x, .y = max_y } },
    };
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
