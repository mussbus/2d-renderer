const std = @import("std");
const math = @import("math");
const integrated = @import("integrated_demo");

pub fn expectReset(scene: *const integrated.Scene) !void {
    const controller = scene.player.controllerSnapshot().?.state;
    try std.testing.expect(controller.position.approxEqAbs(.{ .x = -3.15, .y = 1.05 }, 0));
    try std.testing.expect(controller.velocity.approxEqAbs(math.Vec2.zero, 0));
    try std.testing.expect(controller.grounded);
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeCount());
    try std.testing.expect(!scene.player.isInteractionLocked());
    try std.testing.expect(!scene.partner.isInteractionLocked());
    try std.testing.expect(scene.player.rightHandIkMetrics() == null);
    try std.testing.expect(scene.partner.rightHandIkMetrics() == null);
    try std.testing.expect(!scene.player.footPlantingSnapshot().left.hasLock());
    try std.testing.expect(!scene.player.footPlantingSnapshot().right.hasLock());
    try std.testing.expectEqual(@as(usize, 0), scene.player.activeOverrideCount());
    try std.testing.expectEqual(@as(usize, 0), scene.partner.activeOverrideCount());
    try std.testing.expectEqual(@as(f32, 0), scene.player.proceduralSnapshot().landing_spring.offset);
    try std.testing.expectEqual(@as(f32, 0), scene.player.proceduralSnapshot().secondary_spring.offset);
    try std.testing.expectEqual(@as(usize, 0), scene.history.count);
}
