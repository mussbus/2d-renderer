const math = @import("math");
const collider = @import("collider");

pub const player_spawn = math.Vec2{ .x = -3.15, .y = 1.05 };
pub const partner_spawn = math.Vec2{ .x = -1.40, .y = 1.05 };
pub const showcase_spawn = math.Vec2{ .x = 14.0, .y = 1.05 };
pub const distant_camera_x_factor: f32 = 0.12;
pub const midground_camera_x_factor: f32 = 0.46;

const world_min_x: f32 = -36;
const world_max_x: f32 = 36;

pub fn colliderInputs() [8]collider.StaticColliderInput {
    return .{
        staticCollider(1, world_min_x, -1, world_max_x, 0, true),
        staticCollider(2, world_max_x - 0.3, 0, world_max_x, 7, false),
        staticCollider(3, world_min_x, 0, world_min_x + 0.3, 7, false),
        staticCollider(4, 4.5, 0.75, 7.0, 1.0, true),
        staticCollider(5, 9.0, 1.45, 11.5, 1.70, true),
        staticCollider(6, 15.0, 0.85, 18.0, 1.10, true),
        staticCollider(7, 23.0, 1.75, 26.0, 2.0, true),
        staticCollider(8, -27.0, 1.15, -23.0, 1.40, true),
    };
}

fn staticCollider(
    id: collider.ColliderId,
    minimum_x: f32,
    minimum_y: f32,
    maximum_x: f32,
    maximum_y: f32,
    ground_query_eligible: bool,
) collider.StaticColliderInput {
    return .{
        .id = id,
        .bounds = .{
            .minimum = .{ .x = minimum_x, .y = minimum_y },
            .maximum = .{ .x = maximum_x, .y = maximum_y },
        },
        .ground_query_eligible = ground_query_eligible,
    };
}
