const std = @import("std");
const math = @import("math");

const Vec2 = math.Vec2;
const Mat3 = math.Mat3;
const Transform2D = math.Transform2D;
const tolerance: f32 = 1e-5;

fn expectVec(expected: Vec2, actual: Vec2) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
}

test "Vec2 arithmetic normalization and finite validation are explicit" {
    const left = Vec2.init(3, 4);
    try expectVec(.{ .x = 4, .y = 2 }, left.add(.{ .x = 1, .y = -2 }));
    try expectVec(.{ .x = 2, .y = 6 }, left.sub(.{ .x = 1, .y = -2 }));
    try expectVec(.{ .x = 6, .y = 8 }, left.scale(2));
    try expectVec(.{ .x = 6, .y = -4 }, left.componentMul(.{ .x = 2, .y = -1 }));
    try std.testing.expectEqual(@as(f32, 25), left.lengthSquared());
    try std.testing.expectEqual(@as(f32, 5), left.length());
    try std.testing.expectEqual(@as(f32, -5), left.dot(.{ .x = 1, .y = -2 }));
    try expectVec(.{ .x = 0.6, .y = 0.8 }, try left.normalizeSafe(1e-6));
    try expectVec(Vec2.zero, try Vec2.zero.normalizeSafe(1e-6));
    try expectVec(Vec2.zero, try Vec2.init(1e-8, -1e-8).normalizeSafe(1e-6));
    try std.testing.expectError(error.InvalidNonFiniteVector, Vec2.init(std.math.inf(f32), 0).normalizeSafe(1e-6));
    try std.testing.expectError(error.InvalidNormalizationEpsilon, left.normalizeSafe(0));
}

test "identity translation scale and point versus direction use hand-computed values" {
    const point = Vec2.init(2, -3);
    try expectVec(point, Mat3.identity().transformPoint(point));
    try expectVec(.{ .x = 7, .y = 4 }, Mat3.translation(.{ .x = 5, .y = 7 }).transformPoint(point));
    try expectVec(.{ .x = 6, .y = -9 }, Mat3.nonuniformScale(.{ .x = 3, .y = 3 }).transformPoint(point));
    try expectVec(.{ .x = 4, .y = 12 }, Mat3.nonuniformScale(.{ .x = 2, .y = -4 }).transformPoint(point));

    const translated = Mat3.translation(.{ .x = 100, .y = -50 });
    try expectVec(.{ .x = 102, .y = -53 }, translated.transformPoint(point));
    try expectVec(point, translated.transformDirection(point));
}

test "positive and negative ninety-degree rotations match the CCW convention" {
    try expectVec(.{ .x = 0, .y = 1 }, Mat3.rotation(std.math.pi / 2.0).transformPoint(.{ .x = 1, .y = 0 }));
    try expectVec(.{ .x = 0, .y = -1 }, Mat3.rotation(-std.math.pi / 2.0).transformPoint(.{ .x = 1, .y = 0 }));
}

test "component order and parent-child order are independently hand computed" {
    const local = Transform2D.init(.{ .x = 5, .y = 7 }, std.math.pi / 2.0, .{ .x = 2, .y = 3 });
    try expectVec(.{ .x = 5, .y = 9 }, (try local.localToParent()).transformPoint(.{ .x = 1, .y = 0 }));

    const parent_to_world = Mat3.rotation(std.math.pi / 2.0);
    const child_local = Transform2D.init(.{ .x = 2, .y = 0 }, 0, Vec2.one);
    try expectVec(.{ .x = 0, .y = 2 }, (try math.composeParentChild(parent_to_world, child_local)).transformPoint(Vec2.zero));

    const translated_parent = Mat3.translation(.{ .x = 10, .y = 1 });
    const rotated_child = Transform2D.init(.{ .x = 2, .y = 0 }, std.math.pi / 2.0, Vec2.one);
    const two_level = try math.composeParentChild(translated_parent, rotated_child);
    try expectVec(.{ .x = 12, .y = 2 }, two_level.transformPoint(.{ .x = 1, .y = 0 }));
}

test "four-level hierarchy includes every ancestor exactly once" {
    var world = Mat3.translation(.{ .x = 10, .y = 0 });
    world = try math.composeParentChild(world, Transform2D.init(.{ .x = 2, .y = 0 }, std.math.pi / 2.0, Vec2.one));
    world = try math.composeParentChild(world, Transform2D.init(.{ .x = 3, .y = 0 }, 0, Vec2.one));
    world = try math.composeParentChild(world, Transform2D.init(.{ .x = 4, .y = 0 }, 0, Vec2.one));
    try expectVec(.{ .x = 12, .y = 7 }, world.transformPoint(Vec2.zero));
}

test "zero scale and very small finite transforms stay finite" {
    const collapsed = Transform2D.init(.{ .x = 4, .y = -2 }, 0.3, Vec2.zero);
    try expectVec(.{ .x = 4, .y = -2 }, (try collapsed.localToParent()).transformPoint(.{ .x = 100, .y = -100 }));
    const tiny = Transform2D.init(.{ .x = 1e-7, .y = -1e-7 }, 1e-7, .{ .x = 1e-7, .y = 2e-7 });
    try std.testing.expect((try tiny.localToParent()).isFinite());
}

test "angle wrapping and shortest interpolation cross zero in both directions" {
    const degrees = std.math.pi / 180.0;
    try std.testing.expectApproxEqAbs(@as(f32, 0), try math.interpolation.wrapAngle(4.0 * std.math.pi), tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0), try math.interpolation.wrapAngle(-6.0 * std.math.pi), tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 20 * degrees), try math.interpolation.signedShortestAngleDifference(350 * degrees, 10 * degrees), tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, -20 * degrees), try math.interpolation.signedShortestAngleDifference(10 * degrees, 350 * degrees), tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0), try math.interpolation.lerpAngleShortest(350 * degrees, 10 * degrees, 0.5), tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0), try math.interpolation.lerpAngleShortest(10 * degrees, 350 * degrees, 0.5), tolerance);
}

test "component interpolation does not interpolate matrix elements" {
    const from = Transform2D.init(.{ .x = 0, .y = 2 }, 350.0 * std.math.pi / 180.0, .{ .x = 1, .y = 2 });
    const to = Transform2D.init(.{ .x = 10, .y = 6 }, 10.0 * std.math.pi / 180.0, .{ .x = 3, .y = 6 });
    const halfway = try Transform2D.interpolateComponents(from, to, 0.5);
    try expectVec(.{ .x = 5, .y = 4 }, halfway.translation);
    try expectVec(.{ .x = 2, .y = 4 }, halfway.scale);
    try std.testing.expectApproxEqAbs(@as(f32, 0), halfway.rotation_radians, tolerance);
}

test "non-finite rejection and approximate equality distinguish tolerance boundaries" {
    var invalid = Transform2D.identity();
    invalid.rotation_radians = std.math.nan(f32);
    try std.testing.expectError(error.InvalidNonFiniteTransform, invalid.validate());
    try std.testing.expectError(error.InvalidNonFiniteInterpolation, math.interpolation.wrapAngle(std.math.inf(f32)));

    const base = Transform2D.identity();
    const near = Transform2D.init(.{ .x = 0.5e-5, .y = -0.5e-5 }, 0.5e-5, .{ .x = 1.0 + 0.5e-5, .y = 1 });
    const outside = Transform2D.init(.{ .x = 2e-5, .y = 0 }, 0, Vec2.one);
    try std.testing.expect(base.approxEqAbs(near, tolerance));
    try std.testing.expect(!base.approxEqAbs(outside, tolerance));
}
