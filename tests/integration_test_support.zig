const std = @import("std");
const math = @import("math");
const integrated = @import("integrated_demo");

pub fn expectReset(scene: *const integrated.Scene) !void {
    const controller = scene.player.controller.?.state;
    try std.testing.expect(controller.position.approxEqAbs(.{ .x = -3.15, .y = 1.05 }, 0));
    try std.testing.expect(controller.velocity.approxEqAbs(math.Vec2.zero, 0));
    try std.testing.expect(controller.grounded);
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeCount());
    try std.testing.expect(!scene.player.isInteractionLocked());
    try std.testing.expect(!scene.partner.isInteractionLocked());
    try std.testing.expect(!scene.player.right_arm_ik.applied);
    try std.testing.expect(!scene.partner.right_arm_ik.applied);
    try std.testing.expect(!scene.player.foot_plants.left.hasLock());
    try std.testing.expect(!scene.player.foot_plants.right.hasLock());
    try std.testing.expectEqual(@as(usize, 0), scene.player.overrides.activeCount());
    try std.testing.expectEqual(@as(usize, 0), scene.partner.overrides.activeCount());
    try std.testing.expectEqual(@as(f32, 0), scene.player.procedural.landing_spring.offset);
    try std.testing.expectEqual(@as(f32, 0), scene.player.procedural.secondary_spring.offset);
    try std.testing.expectEqual(@as(usize, 0), scene.history.count);
}
