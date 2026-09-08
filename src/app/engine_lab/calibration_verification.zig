const std = @import("std");
const h = @import("engine_lab");
pub const checkpoint_ticks = [_]u64{ 0, 30, 120, 150, 180, 210, 300, 330, 420, 480, 960, 1440 };
pub const Checkpoint = struct { tick: u64, digest: h.Digest, offset: f32, velocity: f32 };
pub const Result = struct { checkpoints: [checkpoint_ticks.len]Checkpoint };

pub fn inputAt(tick: u64) h.Intent {
    var input = h.neutral_intent;
    input.move_axis = if (tick < 120 or (tick >= 180 and tick < 300)) 1 else if (tick >= 300 and tick < 420) -1 else 0;
    return input;
}
fn observe(hub: *const h.Hub) !Checkpoint {
    return .{ .tick = hub.tick, .digest = try hub.calibration.fingerprint(), .offset = hub.calibration.state.response.offset, .velocity = hub.calibration.state.response.velocity };
}
fn run(hub: *h.Hub, mixed: bool) !Result {
    var result: Result = .{ .checkpoints = undefined };
    result.checkpoints[0] = try observe(hub);
    const schedule = [_]u64{ 1, 3, 2 };
    var frame: usize = 0;
    for (checkpoint_ticks[1..], 1..) |target, index| {
        while (hub.tick < target) : (frame += 1) {
            const steps = @min(target - hub.tick, if (mixed) schedule[frame % schedule.len] else 4);
            try hub.advanceFrame(@as(f64, @floatFromInt(steps)) / 240.0, inputAt(hub.tick));
            if (hub.calibration.state.fixed_ticks != hub.tick or hub.impact.effects.tick() != hub.tick or hub.impact.projectiles.tick() != hub.tick) return error.CalibrationFixtureTickMismatch;
            const root = hub.actor.controllerSnapshot() orelse return error.HubActorHasNoController;
            if (hub.calibration.state.driver_position != root.state.position.x + h.calibration_module.mount.x) return error.CalibrationDriverMismatch;
            if (@abs(hub.calibration.state.response.offset) > h.calibration_module.profile.maximum_displacement or @abs(hub.calibration.state.response.velocity) > h.calibration_module.profile.maximum_velocity.?) return error.CalibrationLimitExceeded;
        }
        result.checkpoints[index] = try observe(hub);
    }
    if (hub.calibration.state.response.offset != 0 or hub.calibration.state.response.velocity != 0) return error.CalibrationDidNotSettle;
    return result;
}
pub fn verify(allocator: std.mem.Allocator, seed: h.Seed) !Result {
    var hub = try h.Hub.init(allocator, seed);
    defer hub.deinit() catch |err| h.cleanupFailure(err);
    const first = try run(&hub, false);
    try hub.reset();
    const second = try run(&hub, true);
    for (first.checkpoints, second.checkpoints) |left, right| if (left.tick != right.tick or !left.digest.eql(right.digest)) return error.CalibrationGroupingMismatch;
    return second;
}
