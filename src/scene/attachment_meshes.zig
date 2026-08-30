const std = @import("std");
const math = @import("math");
const attachment_secondary_motion = @import("attachment_secondary_motion");
const mesh = @import("deformable_mesh");

pub const cape_secondary_motion = attachment_secondary_motion.Definition{
    .dynamic_point_count = 3,
    .rest_offsets = .{
        .{ .x = 0, .y = -0.36 },
        .{ .x = 0, .y = -0.74 },
        .{ .x = 0, .y = -1.10 },
        math.Vec2.zero,
    },
    .spring_configuration = .{
        .stiffness = 72,
        .damping = 15,
        .maximum_displacement = 0.42,
        .maximum_velocity = 5.5,
    },
    .gravity_displacement = .{ .x = 0, .y = -0.10 },
    .acceleration_response = .{ .x = 0.010, .y = 0.008 },
    .velocity_response = .{ .x = 0.035, .y = 0.018 },
    .chain_follow = 0.40,
    .landing_impulse_scale = 0.08,
    .output_translation_scale = 0.38,
    .maximum_rotation_radians = 0.62,
};

pub const loose_sleeve_secondary_motion = attachment_secondary_motion.Definition{
    .dynamic_point_count = 2,
    .rest_offsets = .{
        .{ .x = 0.34, .y = 0 },
        .{ .x = 0.70, .y = 0 },
        math.Vec2.zero,
        math.Vec2.zero,
    },
    .spring_configuration = .{
        .stiffness = 128,
        .damping = 21,
        .maximum_displacement = 0.12,
        .maximum_velocity = 2.8,
    },
    .gravity_displacement = .{ .x = 0, .y = -0.018 },
    .acceleration_response = .{ .x = 0.0025, .y = 0.002 },
    .velocity_response = .{ .x = 0.006, .y = 0.004 },
    .chain_follow = 0.28,
    .landing_impulse_scale = 0.012,
    .output_translation_scale = 0.18,
    .maximum_rotation_radians = 0.18,
};

pub fn initFittedGarmentMesh(allocator: std.mem.Allocator) !mesh.Definition {
    const vertices = [_]mesh.VertexInput{
        vertex(-0.46, -0.58, 0.00, 1.00, 0.85),
        vertex(0.46, -0.58, 1.00, 1.00, 0.85),
        vertex(-0.52, 0.00, 0.00, 0.50, 1.00),
        vertex(0.52, 0.00, 1.00, 0.50, 1.00),
        vertex(-0.40, 0.58, 0.08, 0.00, 1.00),
        vertex(0.40, 0.58, 0.92, 0.00, 1.00),
    };
    const indices = [_]u16{ 0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4 };
    return mesh.Definition.init(allocator, .{
        .stable_id = "fitted_garment_mesh_v1",
        .vertices = &vertices,
        .indices = &indices,
        .material = .{
            .stable_id = "tailored_fabric",
            .texture_page = 0,
            .tint = .{ 0.12, 0.48, 0.82, 1 },
        },
    });
}

pub fn initSleeveMesh(allocator: std.mem.Allocator) !mesh.Definition {
    const vertices = [_]mesh.VertexInput{
        vertex(0.00, -0.15, 0.00, 1.00, 1.00),
        vertex(0.00, 0.15, 0.00, 0.00, 1.00),
        vertex(0.36, -0.13, 0.50, 0.92, 0.90),
        vertex(0.36, 0.13, 0.50, 0.08, 0.90),
        vertex(0.72, -0.10, 1.00, 0.84, 0.75),
        vertex(0.72, 0.10, 1.00, 0.16, 0.75),
    };
    const indices = [_]u16{ 0, 2, 1, 1, 2, 3, 2, 4, 3, 3, 4, 5 };
    return mesh.Definition.init(allocator, .{
        .stable_id = "reusable_sleeve_mesh_v1",
        .vertices = &vertices,
        .indices = &indices,
        .material = .{
            .stable_id = "tailored_fabric",
            .texture_page = 0,
            .tint = .{ 0.12, 0.48, 0.82, 1 },
        },
    });
}

pub fn initCapeMesh(allocator: std.mem.Allocator) !mesh.Definition {
    const vertices = [_]mesh.VertexInput{
        vertex(-0.40, 0.48, 0.00, 0.00, 0.00),
        vertex(0.40, 0.48, 1.00, 0.00, 0.00),
        vertex(-0.50, -0.18, 0.00, 0.45, 0.45),
        vertex(0.48, -0.18, 1.00, 0.45, 0.45),
        vertex(-0.62, -1.08, 0.00, 1.00, 1.00),
        vertex(0.00, -0.94, 0.50, 0.88, 0.90),
        vertex(0.58, -1.08, 1.00, 1.00, 1.00),
    };
    const indices = [_]u16{ 0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4, 3, 6, 5 };
    return mesh.Definition.init(allocator, .{
        .stable_id = "upper_back_cape_mesh_v1",
        .vertices = &vertices,
        .indices = &indices,
        .material = .{
            .stable_id = "cape_fabric",
            .texture_page = 0,
            .tint = .{ 0.44, 0.12, 0.52, 0.92 },
        },
    });
}

fn vertex(x: f32, y: f32, u: f32, v: f32, weight: f32) mesh.VertexInput {
    return .{
        .local_position = .{ .x = x, .y = y },
        .uv = .{ u, v },
        .deformation_weight = weight,
    };
}
