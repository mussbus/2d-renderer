const collider = @import("collider");
const math = @import("math");
const controller = @import("character_controller");

pub const Construction = enum { legacy, expanded };
pub const RouteId = enum { easy_ascent, air_shortcut, dash_gap };
pub const Route = struct {
    id: RouteId,
    label: []const u8,
    label_origin: math.Vec2,
    start: math.Vec2,
    landing_surfaces: []const collider.ColliderId,
    return_surface: collider.ColliderId = 1,
};
pub const movement = controller.GameplayProperties{ .maximum_run_speed = 5.5, .jump_speed = 10.5, .double_jump = true, .dash = true };
pub const legacy_colliders = [_]collider.StaticColliderInput{
    .{ .id = 1, .bounds = .{ .minimum = .{ .x = -8.3, .y = -0.45 }, .maximum = .{ .x = 8.3, .y = 0 } } },
    .{ .id = 2, .bounds = .{ .minimum = .{ .x = -8.3, .y = 0 }, .maximum = .{ .x = -8, .y = 5 } } },
    .{ .id = 3, .bounds = .{ .minimum = .{ .x = 8, .y = 0 }, .maximum = .{ .x = 8.3, .y = 5 } } },
    .{ .id = 4, .bounds = .{ .minimum = .{ .x = -0.75, .y = 0 }, .maximum = .{ .x = 0.75, .y = 0.6 } } },
};

// Stable firing wall 3 remains at X=8; expansion is entirely to its left.
pub const expanded_colliders = [_]collider.StaticColliderInput{
    .{ .id = 1, .bounds = .{ .minimum = .{ .x = -24.3, .y = -0.45 }, .maximum = .{ .x = 8.3, .y = 0 } } },
    .{ .id = 2, .bounds = .{ .minimum = .{ .x = -24.3, .y = 0 }, .maximum = .{ .x = -24, .y = 14 } } },
    .{ .id = 3, .bounds = .{ .minimum = .{ .x = 8, .y = 0 }, .maximum = .{ .x = 8.3, .y = 14 } } },
    .{ .id = 4, .bounds = .{ .minimum = .{ .x = -0.75, .y = 0 }, .maximum = .{ .x = 0.75, .y = 0.6 } } },
    .{ .id = 5, .bounds = .{ .minimum = .{ .x = -24.3, .y = 14 }, .maximum = .{ .x = 8.3, .y = 14.3 } } },
    .{ .id = 10, .bounds = .{ .minimum = .{ .x = -8.8, .y = 1.35 }, .maximum = .{ .x = -7.3, .y = 1.6 } } },
    .{ .id = 11, .bounds = .{ .minimum = .{ .x = -12.5, .y = 2.95 }, .maximum = .{ .x = -10.8, .y = 3.2 } } },
    .{ .id = 12, .bounds = .{ .minimum = .{ .x = -16.2, .y = 4.55 }, .maximum = .{ .x = -14, .y = 4.8 } } },
    .{ .id = 13, .bounds = .{ .minimum = .{ .x = -24, .y = 4.55 }, .maximum = .{ .x = -21, .y = 4.8 } } },
};
pub const routes = [_]Route{
    .{ .id = .easy_ascent, .label = "JUMP", .label_origin = .{ .x = -8.7, .y = 1.15 }, .start = .{ .x = -5.7, .y = 1.05 }, .landing_surfaces = &.{ 10, 11, 12 } },
    .{ .id = .air_shortcut, .label = "AIR", .label_origin = .{ .x = -12.4, .y = 2.75 }, .start = .{ .x = -5.7, .y = 1.05 }, .landing_surfaces = &.{ 11, 12 } },
    .{ .id = .dash_gap, .label = "DASH", .label_origin = .{ .x = -17, .y = 4.5 }, .start = .{ .x = -16.1, .y = 5.85 }, .landing_surfaces = &.{13} },
};

pub fn colliders(construction: Construction) []const collider.StaticColliderInput {
    return if (construction == .expanded) &expanded_colliders else &legacy_colliders;
}
pub fn identity(construction: Construction) []const u8 {
    return if (construction == .expanded) "engine_lab.traversal.layout.v1" else "engine_lab.legacy.room.v2";
}
pub fn profileIdentity(construction: Construction) []const u8 {
    return if (construction == .expanded) "engine_lab.traversal.movement.v1" else "controller.defaults";
}
