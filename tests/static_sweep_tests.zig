const std = @import("std");
const q = @import("collision_world").static_sweep;
const collider = @import("collider");
const math = @import("math");
const box = collider.Aabb{ .minimum = .{ .x = 1, .y = 1 }, .maximum = .{ .x = 2, .y = 2 } };
fn v(x: f32, y: f32) math.Vec2 {
    return .{ .x = x, .y = y };
}
fn check(hit: q.Contact, fraction: f32, position: math.Vec2, normal: math.Vec2) !void {
    // 1e-6 covers one f32 conversion of analytical slab fractions, not geometry inflation.
    try std.testing.expectApproxEqAbs(fraction, hit.fraction, 1e-6);
    try std.testing.expect(hit.position.approxEqAbs(position, 1e-6));
    try std.testing.expectEqual(normal, hit.normal);
    try std.testing.expectEqual(@as(f32, 1), hit.normal.lengthSquared());
}
test "static complete sweep detects thin obstacle at high travel distance" {
    const thin = collider.Aabb{ .minimum = v(1, -1), .maximum = v(1.0001, 1) };
    const hit = (try q.query(.{ .from = v(-10000, 0), .to = v(10000, 0) }, thin)).?;
    try check(hit, 10001.0 / 20000.0, v(1, 0), v(-1, 0));
    try std.testing.expect((try q.query(.{ .from = v(-10000, 2), .to = v(10000, 2) }, thin)) == null);
}
test "static diagonal body sweep reports original surface and deterministic corner" {
    try check((try q.query(.{ .from = v(0, 0), .to = v(3, 3) }, box)).?, 1.0 / 3.0, v(1, 1), v(-1, 0));
    try check((try q.query(.{ .from = v(0, 1.5), .to = v(2, 1.5), .half_extents = v(0.25, 0.1) }, box)).?, 0.375, v(1, 1.5), v(-1, 0));
    try check((try q.query(.{ .from = v(0, 0), .to = v(3, 3), .half_extents = v(0.25, 0.25) }, box)).?, 0.25, v(1, 1), v(-1, 0));
    try check((try q.query(.{ .from = v(1.5, 3), .to = v(1.5, 1) }, box)).?, 0.5, v(1.5, 2), v(0, 1));
    try std.testing.expect((try q.query(.{ .from = v(0, 2), .to = v(2, 0) }, box)) == null);
}
test "static initial overlap stationary motion and face ties have explicit contact" {
    try check((try q.query(.{ .from = v(1.5, 1.5), .to = v(1.5, 1.5) }, box)).?, 0, v(1, 1.5), v(-1, 0));
    try check((try q.query(.{ .from = v(1.9, 1.5), .to = v(3, 1.5) }, box)).?, 0, v(2, 1.5), v(1, 0));
    try std.testing.expect((try q.query(.{ .from = v(0, 0), .to = v(0, 0) }, box)) == null);
}
test "static boundary contact counts inward and endpoint entry but rejects tangent separating" {
    try check((try q.query(.{ .from = v(1, 1.5), .to = v(1.5, 1.5) }, box)).?, 0, v(1, 1.5), v(-1, 0));
    try check((try q.query(.{ .from = v(0, 1.5), .to = v(1, 1.5) }, box)).?, 1, v(1, 1.5), v(-1, 0));
    for ([_]math.Vec2{ v(0, 1.5), v(1, 2), v(1, 1.5) }) |to| try std.testing.expect((try q.query(.{ .from = v(1, 1.5), .to = to }, box)) == null);
    try std.testing.expect((try q.query(.{ .from = v(0, 1), .to = v(3, 1) }, box)) == null);
}
test "static sweep validates finite input and computes finite extreme output without allocation" {
    try std.testing.expectError(error.InvalidSweep, q.query(.{ .from = v(std.math.nan(f32), 0), .to = v(0, 0) }, box));
    try std.testing.expectError(error.InvalidSweep, q.query(.{ .from = v(0, 0), .to = v(std.math.inf(f32), 0) }, box));
    try std.testing.expectError(error.InvalidSweep, q.query(.{ .from = v(0, 0), .to = v(2, 2), .half_extents = v(-1, 0) }, box));
    try std.testing.expectError(error.InvalidSweep, q.query(.{ .from = v(0, 0), .to = v(2, 2), .half_extents = v(0, std.math.inf(f32)) }, box));
    try std.testing.expectError(error.InvalidBounds, q.query(.{ .from = v(0, 0), .to = v(2, 2) }, .{ .minimum = v(2, 1), .maximum = v(1, 2) }));
    try check((try q.query(.{ .from = v(-std.math.floatMax(f32), 1.5), .to = v(std.math.floatMax(f32), 1.5) }, box)).?, 0.5, v(1, 1.5), v(-1, 0));
}
