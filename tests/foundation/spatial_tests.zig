const std = @import("std");
const foundation = @import("foundation");
const canonical_model = @import("canonical_model");
const transform2d = @import("current_transform2d");

const spatial = foundation.spatial;

test "finite validation and quaternion canonical tolerance boundaries are explicit" {
    try std.testing.expectError(error.NonFiniteValue, spatial.Vec3.init(std.math.inf(f32), 0.0, 0.0));
    try std.testing.expectError(error.NonFiniteValue, spatial.LocalTransform.init(
        .{ .x = 0.0, .y = std.math.nan(f32), .z = 0.0 },
        spatial.Quaternion.identity,
        spatial.Vec3.one,
    ));
    const within = try spatial.Quaternion.initCanonical(0.0, 0.0, 0.0, @sqrt(1.0 + spatial.quaternion_unit_tolerance * 0.5));
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), within.w, spatial.quaternion_unit_tolerance);
    try std.testing.expectError(
        error.InvalidQuaternion,
        spatial.Quaternion.initCanonical(0.0, 0.0, 0.0, @sqrt(1.0 + spatial.quaternion_unit_tolerance * 2.0)),
    );
    const hemisphere = try spatial.Quaternion.initCanonical(-0.0, -0.0, -0.0, -1.0);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @bitCast(hemisphere.x)));
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @bitCast(hemisphere.y)));
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @bitCast(hemisphere.z)));
    try std.testing.expectEqual(@as(f32, 1.0), hemisphere.w);
    const positive_x_half_turn = try spatial.Quaternion.initCanonical(1.0, 0.0, 0.0, 0.0);
    const negative_x_half_turn = try spatial.Quaternion.initCanonical(-1.0, 0.0, 0.0, 0.0);
    try std.testing.expectEqual(positive_x_half_turn, negative_x_half_turn);
}

test "shared spatial convention conforms to protected canonical math" {
    const right = spatial.Vec3{ .x = 1.0, .y = 0.0, .z = 0.0 };
    const up = spatial.Vec3{ .x = 0.0, .y = 1.0, .z = 0.0 };
    const forward = spatial.Vec3{ .x = 0.0, .y = 0.0, .z = 1.0 };
    try expectSharedVec(forward, right.cross(up));

    const angle: f32 = std.math.pi / 3.0;
    const shared_rotation = try spatial.Quaternion.fromAxisAngle(.{ .x = 0.0, .y = 0.0, .z = 1.0 }, angle);
    const canonical_rotation = try canonical_model.math3d.Quaternion.initCanonical(
        0.0,
        0.0,
        @sin(angle * 0.5),
        @cos(angle * 0.5),
    );
    const shared_local = try spatial.LocalTransform.init(
        .{ .x = 2.0, .y = -3.0, .z = 4.0 },
        shared_rotation,
        .{ .x = 2.0, .y = 0.5, .z = -1.0 },
    );
    const canonical_local = canonical_model.math3d.LocalTransform{
        .translation_m = .{ .x = 2.0, .y = -3.0, .z = 4.0 },
        .rotation = canonical_rotation,
        .scale = .{ .x = 2.0, .y = 0.5, .z = -1.0 },
    };
    const shared_affine = try spatial.AffineTransform.fromLocal(shared_local);
    const canonical_affine = canonical_model.math3d.AffineTransform.fromLocal(canonical_local);
    try expectVec3(canonical_affine.x_axis, shared_affine.x_axis);
    try expectVec3(canonical_affine.y_axis, shared_affine.y_axis);
    try expectVec3(canonical_affine.z_axis, shared_affine.z_axis);
    try expectVec3(canonical_affine.translation_m, shared_affine.translation);
}

test "scale rotate translate and parent times local semantics are explicit" {
    const quarter_turn = try spatial.Quaternion.fromAxisAngle(.{ .x = 0.0, .y = 0.0, .z = 1.0 }, std.math.pi / 2.0);
    const local = try spatial.LocalTransform.init(
        .{ .x = 10.0, .y = 20.0, .z = 0.0 },
        quarter_turn,
        .{ .x = 2.0, .y = 3.0, .z = 1.0 },
    );
    try expectSharedVec(.{ .x = 10.0, .y = 22.0, .z = 0.0 }, local.transformPoint(.{ .x = 1.0, .y = 0.0, .z = 0.0 }));

    const parent = try spatial.AffineTransform.fromLocal(try spatial.LocalTransform.init(
        .{ .x = 3.0, .y = 4.0, .z = 0.0 },
        spatial.Quaternion.identity,
        spatial.Vec3.one,
    ));
    const composed = try spatial.AffineTransform.compose(parent, try spatial.AffineTransform.fromLocal(local));
    const point = spatial.Vec3{ .x = 1.0, .y = 0.0, .z = 0.0 };
    try expectSharedVec(parent.transformPoint((try spatial.AffineTransform.fromLocal(local)).transformPoint(point)), composed.transformPoint(point));
}

test "shared XY transforms conform to the current Transform2D route" {
    const translation = transform2d.Vec2.init(2.0, -4.0);
    const scale = transform2d.Vec2.init(1.5, 0.75);
    const legacy = transform2d.Transform2D.init(translation, 0.4, scale);
    const legacy_matrix = try legacy.localToParent();
    const shared = try spatial.LocalTransform.init(
        .{ .x = 2.0, .y = -4.0, .z = 0.0 },
        try spatial.Quaternion.fromAxisAngle(.{ .x = 0.0, .y = 0.0, .z = 1.0 }, 0.4),
        .{ .x = 1.5, .y = 0.75, .z = 1.0 },
    );
    const shared_affine = try spatial.AffineTransform.fromLocal(shared);
    const legacy_point = legacy_matrix.transformPoint(transform2d.Vec2.init(3.0, 5.0));
    const shared_point = shared_affine.transformPoint(.{ .x = 3.0, .y = 5.0, .z = 0.0 });
    try std.testing.expectApproxEqAbs(legacy_point.x, shared_point.x, spatial.affine_absolute_tolerance);
    try std.testing.expectApproxEqAbs(legacy_point.y, shared_point.y, spatial.affine_absolute_tolerance);
}

test "affine inverse round trips and rejects singular values" {
    const transform = try spatial.AffineTransform.fromLocal(try spatial.LocalTransform.init(
        .{ .x = 4.0, .y = -2.0, .z = 7.0 },
        try spatial.Quaternion.fromAxisAngle(.{ .x = 0.0, .y = 1.0, .z = 0.0 }, 0.7),
        .{ .x = -2.0, .y = 3.0, .z = 0.5 },
    ));
    const inverse = try transform.inverse();
    const point = spatial.Vec3{ .x = 1.25, .y = -9.0, .z = 2.5 };
    try expectSharedVec(point, inverse.transformPoint(transform.transformPoint(point)));

    const small = try spatial.AffineTransform.fromLocal(try spatial.LocalTransform.init(
        spatial.Vec3.zero,
        spatial.Quaternion.identity,
        .{ .x = 0.001, .y = 0.001, .z = 0.001 },
    ));
    try expectSharedVec(point, (try small.inverse()).transformPoint(small.transformPoint(point)));

    const singular = spatial.AffineTransform{
        .x_axis = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .y_axis = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .z_axis = .{ .x = 0.0, .y = 0.0, .z = 1.0 },
        .translation = spatial.Vec3.zero,
    };
    try std.testing.expectError(error.SingularTransform, singular.inverse());
}

test "decomposition has canonical negative scale behavior and rejects shear" {
    const original = try spatial.LocalTransform.init(
        .{ .x = -1.0, .y = 3.0, .z = 5.0 },
        try spatial.Quaternion.fromAxisAngle(.{ .x = 1.0, .y = 0.0, .z = 0.0 }, 0.25),
        .{ .x = 2.0, .y = -3.0, .z = 4.0 },
    );
    const affine = try spatial.AffineTransform.fromLocal(original);
    const decomposed = try affine.toLocal();
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), decomposed.scale.x, spatial.affine_absolute_tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), decomposed.scale.y, spatial.affine_absolute_tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), decomposed.scale.z, spatial.affine_absolute_tolerance);
    try std.testing.expect(spatial.approximatelyEqual(affine, try spatial.AffineTransform.fromLocal(decomposed)));

    var sheared = spatial.AffineTransform.identity;
    sheared.y_axis.x = 0.2;
    try std.testing.expectError(error.NonRepresentableAffine, sheared.toLocal());
    var within_tolerance = spatial.AffineTransform.identity;
    within_tolerance.y_axis.x = spatial.basis_orthogonality_tolerance * 0.5;
    _ = try within_tolerance.toLocal();
    var outside_tolerance = spatial.AffineTransform.identity;
    outside_tolerance.y_axis.x = spatial.basis_orthogonality_tolerance * 2.0;
    try std.testing.expectError(error.NonRepresentableAffine, outside_tolerance.toLocal());
    try std.testing.expectError(error.ZeroScale, spatial.LocalTransform.init(spatial.Vec3.zero, spatial.Quaternion.identity, .{ .x = 1.0, .y = 0.0, .z = 1.0 }));
}

test "affine composition preserves shear without pretending it is local TRS" {
    const parent = try spatial.AffineTransform.fromLocal(try spatial.LocalTransform.init(
        spatial.Vec3.zero,
        try spatial.Quaternion.fromAxisAngle(.{ .x = 0.0, .y = 0.0, .z = 1.0 }, 0.7),
        .{ .x = 2.0, .y = 1.0, .z = 1.0 },
    ));
    const child = try spatial.AffineTransform.fromLocal(try spatial.LocalTransform.init(
        spatial.Vec3.zero,
        try spatial.Quaternion.fromAxisAngle(.{ .x = 0.0, .y = 0.0, .z = 1.0 }, -0.4),
        .{ .x = 1.0, .y = 3.0, .z = 1.0 },
    ));
    const composed = try spatial.AffineTransform.compose(parent, child);
    try std.testing.expectError(error.NonRepresentableAffine, composed.toLocal());
}

fn expectSharedVec(expected: spatial.Vec3, actual: spatial.Vec3) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, spatial.affine_absolute_tolerance);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, spatial.affine_absolute_tolerance);
    try std.testing.expectApproxEqAbs(expected.z, actual.z, spatial.affine_absolute_tolerance);
}

fn expectVec3(expected: canonical_model.math3d.Vec3, actual: spatial.Vec3) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, spatial.affine_absolute_tolerance);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, spatial.affine_absolute_tolerance);
    try std.testing.expectApproxEqAbs(expected.z, actual.z, spatial.affine_absolute_tolerance);
}
