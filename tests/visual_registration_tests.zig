const std = @import("std");
const math = @import("math");
const sprite = @import("sprite_batch");
const visual = @import("visual_geometry");
const registration = @import("visual_registration");

const tolerance: f32 = registration.structural_epsilon_m;

fn request() sprite.SpriteRequest {
    return .{
        .world_position = .{ 0, 0 },
        .rotation = 0,
        .scale = .{ 1, 1 },
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 1, 1 },
        .tint = .{ 1, 1, 1, 1 },
        .texture_page = 0,
        .order = .{
            .scene_layer = 0,
            .interaction_layer = 0,
            .actor_layer = 0,
            .body_part_layer = 0,
        },
    };
}

fn definition(
    mode: visual.RegistrationBindingMode,
    policy: visual.RegistrationScalePolicy,
    reflection: bool,
) registration.Definition {
    return .{
        .identity = "controlled_fixture",
        .binding_mode = mode,
        .scale_policy = policy,
        .mirroring_policy = if (reflection) .transverse_reflection else .none,
        .allows_reflection = reflection,
    };
}

test "point binding maps one atlas landmark to one projected target" {
    const placement = try registration.solvePoint(
        definition(.point, .point_authored, false),
        request(),
        .{
            .role = .point,
            .landmark = .center,
            .local = .{ .x = 0.23, .y = 0.74 },
        },
        .{
            .role = .point,
            .identity = "projected_face_anchor",
            .world = .{ .x = 4.25, .y = -2.5 },
        },
        0.42,
        .{ .x = 0.8, .y = 0.6 },
    );
    const transformed = sprite.localPointToWorld(
        placement.request,
        .{ 0.23, 0.74 },
    );
    try std.testing.expectApproxEqAbs(@as(f32, 4.25), transformed[0], tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, -2.5), transformed[1], tolerance);
    try registration.requireAuthoritative(placement.evidence);
}

test "point-axis binding owns anchor orientation signed scale and axis evidence" {
    const placement = try registration.solvePointAxis(
        definition(.point_axis, .point_axis_authored, true),
        request(),
        .{
            .role = .point,
            .landmark = .ankle,
            .local = .{ .x = 0.3, .y = 0.8 },
        },
        .{
            .role = .axis_start,
            .landmark = .sole_back,
            .local = .{ .x = 0.1, .y = 0.1 },
        },
        .{
            .role = .axis_end,
            .landmark = .sole_front,
            .local = .{ .x = 0.9, .y = 0.1 },
        },
        .{
            .anchor = .{
                .role = .point,
                .identity = "projected_ankle",
                .world = .{ .x = -0.4, .y = 1.2 },
            },
            .axis_identity = "support_tangent",
            .direction_world = .{ .x = -0.25, .y = 0 },
        },
        .{ .x = -0.6, .y = 0.2 },
    );
    try std.testing.expectApproxEqAbs(
        @as(f32, -0.4),
        placement.request.world_position[0],
        tolerance,
    );
    try std.testing.expectApproxEqAbs(
        @as(f32, 1.2),
        placement.request.world_position[1],
        tolerance,
    );
    try std.testing.expect(placement.request.scale[0] < 0);
    const axis = placement.evidence.axis orelse
        return error.MissingPointAxisEvidence;
    try std.testing.expectApproxEqAbs(
        axis.transformed_start_world.y,
        axis.transformed_end_world.y,
        tolerance,
    );
    try std.testing.expect(axis.transformed_end_world.x < axis.transformed_start_world.x);
    try std.testing.expect(axis.endpoint_residual_m <= registration.structural_epsilon_m);
    try std.testing.expect(
        axis.angular_residual_radians <= registration.angular_epsilon_radians,
    );
}

test "point-axis binding rejects missing degenerate and nonfinite axis data" {
    const source_anchor = registration.SourcePoint{
        .role = .point,
        .landmark = .ankle,
        .local = .{ .x = 0.3, .y = 0.8 },
    };
    const source_start = registration.SourcePoint{
        .role = .axis_start,
        .landmark = .sole_back,
        .local = .{ .x = 0.1, .y = 0.1 },
    };
    const source_end = registration.SourcePoint{
        .role = .axis_end,
        .landmark = .sole_front,
        .local = .{ .x = 0.9, .y = 0.1 },
    };
    const target = registration.PointAxisTarget{
        .anchor = .{
            .role = .point,
            .identity = "projected_ankle",
            .world = .{ .x = 0, .y = 0 },
        },
        .axis_identity = "support_tangent",
        .direction_world = .{ .x = 1, .y = 0 },
    };
    try std.testing.expectError(
        error.CoincidentSourceAxis,
        registration.solvePointAxis(
            definition(.point_axis, .point_axis_authored, false),
            request(),
            source_anchor,
            source_start,
            .{
                .role = .axis_end,
                .landmark = .sole_front,
                .local = source_start.local,
            },
            target,
            .{ .x = 1, .y = 1 },
        ),
    );
    var coincident_target = target;
    coincident_target.direction_world = .{ .x = 0, .y = 0 };
    try std.testing.expectError(
        error.CoincidentTargetAxis,
        registration.solvePointAxis(
            definition(.point_axis, .point_axis_authored, false),
            request(),
            source_anchor,
            source_start,
            source_end,
            coincident_target,
            .{ .x = 1, .y = 1 },
        ),
    );
    var nonfinite_target = target;
    nonfinite_target.direction_world.x = std.math.nan(f32);
    try std.testing.expectError(
        error.NonFiniteTargetAxis,
        registration.solvePointAxis(
            definition(.point_axis, .point_axis_authored, false),
            request(),
            source_anchor,
            source_start,
            source_end,
            nonfinite_target,
            .{ .x = 1, .y = 1 },
        ),
    );
}

test "segment binding maps proximal and distal while thickness preserves proximal" {
    const source_proximal = registration.SourcePoint{
        .role = .proximal,
        .landmark = .shoulder,
        .local = .{ .x = 0.5, .y = 0.9 },
    };
    const source_distal = registration.SourcePoint{
        .role = .distal,
        .landmark = .elbow,
        .local = .{ .x = 0.5, .y = 0.1 },
    };
    const target_proximal = registration.TargetPoint{
        .role = .proximal,
        .identity = "left_upper_arm",
        .world = .{ .x = -1.2, .y = 3.4 },
    };
    const target_distal = registration.TargetPoint{
        .role = .distal,
        .identity = "left_forearm",
        .world = .{ .x = -0.8, .y = 2.3 },
    };
    const thin = try registration.solveSegment(
        definition(.segment, .segment_longitudinal_transverse, true),
        request(),
        source_proximal,
        source_distal,
        target_proximal,
        target_distal,
        0.25,
        false,
    );
    const thick = try registration.solveSegment(
        definition(.segment, .segment_longitudinal_transverse, true),
        request(),
        source_proximal,
        source_distal,
        target_proximal,
        target_distal,
        0.75,
        true,
    );
    for ([_]registration.Placement{ thin, thick }) |placement| {
        try std.testing.expectApproxEqAbs(
            @as(f32, 0),
            placement.evidence.maximum_residual_m,
            tolerance,
        );
        const proximal = sprite.localPointToWorld(
            placement.request,
            source_proximal.local.toArray(),
        );
        try std.testing.expectApproxEqAbs(target_proximal.world.x, proximal[0], tolerance);
        try std.testing.expectApproxEqAbs(target_proximal.world.y, proximal[1], tolerance);
    }
}

test "frame binding maps a nondegenerate orthogonal source and target frame" {
    const placement = try registration.solveFrame(
        definition(.frame, .frame_axes, false),
        request(),
        .{ .role = .origin, .landmark = .center, .local = .{ .x = 0.5, .y = 0.5 } },
        .{ .role = .axis_x, .landmark = .shoulder_right, .local = .{ .x = 0.9, .y = 0.5 } },
        .{ .role = .axis_y, .landmark = .neck, .local = .{ .x = 0.5, .y = 0.9 } },
        .{ .role = .origin, .identity = "torso_frame_origin", .world = .{ .x = 2, .y = 3 } },
        .{ .role = .axis_x, .identity = "right_shoulder", .world = .{ .x = 2, .y = 4 } },
        .{ .role = .axis_y, .identity = "torso_lower_axis", .world = .{ .x = 0, .y = 3 } },
    );
    try std.testing.expectApproxEqAbs(
        @as(f32, 0),
        placement.evidence.maximum_residual_m,
        tolerance,
    );
}

test "source and target lookup fail closed" {
    const alpha = visual.AlphaGeometry{
        .source = .{ .x = 0, .y = 0, .width = 8, .height = 8 },
        .opaque_bounds = .{ .x = 0, .y = 0, .width = 8, .height = 8 },
        .opaque_count = 64,
        .centroid_source_px = .{ 3.5, 3.5 },
    };
    const geometry = visual.Geometry.init(.custom, &.{
        .{ .kind = .proximal, .visible_uv = .{ 0.5, 0 } },
    });
    try std.testing.expectError(
        error.MissingSourceLandmark,
        registration.sourcePoint(alpha, geometry, .distal, .distal),
    );
    try std.testing.expectError(
        error.MissingRegistrationTarget,
        registration.targetPoint("missing", null, .point),
    );
}

test "invalid segment fixtures reject coincident nonfinite swapped and reflection data" {
    const valid_source_a = registration.SourcePoint{
        .role = .proximal,
        .landmark = .proximal,
        .local = .{ .x = 0, .y = 0.5 },
    };
    const valid_source_b = registration.SourcePoint{
        .role = .distal,
        .landmark = .distal,
        .local = .{ .x = 1, .y = 0.5 },
    };
    const valid_target_a = registration.TargetPoint{
        .role = .proximal,
        .identity = "proximal",
        .world = .{ .x = 0, .y = 0 },
    };
    const valid_target_b = registration.TargetPoint{
        .role = .distal,
        .identity = "distal",
        .world = .{ .x = 1, .y = 0 },
    };
    try std.testing.expectError(
        error.CoincidentSourceSegment,
        registration.solveSegment(
            definition(.segment, .segment_longitudinal_transverse, false),
            request(),
            valid_source_a,
            .{ .role = .distal, .landmark = .distal, .local = valid_source_a.local },
            valid_target_a,
            valid_target_b,
            1,
            false,
        ),
    );
    try std.testing.expectError(
        error.CoincidentTargetSegment,
        registration.solveSegment(
            definition(.segment, .segment_longitudinal_transverse, false),
            request(),
            valid_source_a,
            valid_source_b,
            valid_target_a,
            .{ .role = .distal, .identity = "distal", .world = valid_target_a.world },
            1,
            false,
        ),
    );
    try std.testing.expectError(
        error.NonFiniteSourcePoint,
        registration.solveSegment(
            definition(.segment, .segment_longitudinal_transverse, false),
            request(),
            .{
                .role = .proximal,
                .landmark = .proximal,
                .local = .{ .x = std.math.nan(f32), .y = 0 },
            },
            valid_source_b,
            valid_target_a,
            valid_target_b,
            1,
            false,
        ),
    );
    try std.testing.expectError(
        error.NonFiniteTargetPoint,
        registration.solveSegment(
            definition(.segment, .segment_longitudinal_transverse, false),
            request(),
            valid_source_a,
            valid_source_b,
            .{
                .role = .proximal,
                .identity = "proximal",
                .world = .{ .x = std.math.inf(f32), .y = 0 },
            },
            valid_target_b,
            1,
            false,
        ),
    );
    try std.testing.expectError(
        error.InvalidSourceEndpointOrder,
        registration.solveSegment(
            definition(.segment, .segment_longitudinal_transverse, false),
            request(),
            .{ .role = .distal, .landmark = .proximal, .local = valid_source_a.local },
            .{ .role = .proximal, .landmark = .distal, .local = valid_source_b.local },
            valid_target_a,
            valid_target_b,
            1,
            false,
        ),
    );
    try std.testing.expectError(
        error.InvalidRegistrationReflection,
        registration.solveSegment(
            definition(.segment, .segment_longitudinal_transverse, false),
            request(),
            valid_source_a,
            valid_source_b,
            valid_target_a,
            valid_target_b,
            1,
            true,
        ),
    );
}

test "invalid frames and excessive residual fail closed" {
    const source_origin = registration.SourcePoint{
        .role = .origin,
        .landmark = .center,
        .local = .{ .x = 0, .y = 0 },
    };
    const target_origin = registration.TargetPoint{
        .role = .origin,
        .identity = "origin",
        .world = .{ .x = 0, .y = 0 },
    };
    try std.testing.expectError(
        error.DegenerateSourceFrame,
        registration.solveFrame(
            definition(.frame, .frame_axes, false),
            request(),
            source_origin,
            .{ .role = .axis_x, .landmark = .proximal, .local = .{ .x = 1, .y = 0 } },
            .{ .role = .axis_y, .landmark = .distal, .local = .{ .x = 2, .y = 0 } },
            target_origin,
            .{ .role = .axis_x, .identity = "x", .world = .{ .x = 1, .y = 0 } },
            .{ .role = .axis_y, .identity = "y", .world = .{ .x = 0, .y = 1 } },
        ),
    );
    try std.testing.expectError(
        error.DegenerateTargetFrame,
        registration.solveFrame(
            definition(.frame, .frame_axes, false),
            request(),
            source_origin,
            .{ .role = .axis_x, .landmark = .proximal, .local = .{ .x = 1, .y = 0 } },
            .{ .role = .axis_y, .landmark = .distal, .local = .{ .x = 0, .y = 1 } },
            target_origin,
            .{ .role = .axis_x, .identity = "x", .world = .{ .x = 1, .y = 0 } },
            .{ .role = .axis_y, .identity = "y", .world = .{ .x = 2, .y = 0 } },
        ),
    );
    try std.testing.expectError(
        error.ExcessiveRegistrationResidual,
        registration.validateResidual(.{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }),
    );
}

test "front authority bypass and side semantic swaps are rejected" {
    try std.testing.expectError(
        error.RegistrationAuthorityBypassed,
        registration.requireAuthoritative(null),
    );
    try std.testing.expectError(
        error.RegistrationSemanticIdentitySwap,
        registration.validateSemanticIdentity(.left, .right),
    );
    try registration.validateSemanticIdentity(.left, .left);
}

test "a thickness policy that moves the proximal anchor fails closed" {
    try std.testing.expectError(
        error.ExcessiveRegistrationResidual,
        registration.validateResidual(
            .{ .x = -1.25, .y = 3.5 },
            .{ .x = -1.20, .y = 3.5 },
        ),
    );
}

test "mesh bridge registration schema is explicit" {
    try registration.validateMeshBridgeDefinition(
        definition(.mesh_bridge, .mesh_bridge, false),
    );
    try std.testing.expectError(
        error.RegistrationScalePolicyMismatch,
        registration.validateMeshBridgeDefinition(
            definition(.mesh_bridge, .frame_axes, false),
        ),
    );
}
