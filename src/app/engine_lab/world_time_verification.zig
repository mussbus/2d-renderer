const std = @import("std");
const h = @import("engine_lab");
const time = h.world_time_module;
pub const checkpoint_ticks = [_]u64{ 0, 1, 8, 120, 239, 240, 241, 480 };
pub const Result = struct { checkpoints: [checkpoint_ticks.len]time.Snapshot };

pub fn verify(allocator: std.mem.Allocator, seed: h.Seed) !Result {
    var hub = try h.Hub.init(allocator, seed);
    defer hub.deinit() catch |err| h.cleanupFailure(err);
    var result: Result = undefined;
    for ([_]bool{ false, true }) |mixed| {
        if (mixed) try hub.reset();
        const schedule = [_]u64{ 1, 3, 2 };
        var frame: usize = 0;
        for (checkpoint_ticks, 0..) |target, index| {
            while (hub.tick < target) : (frame += 1) {
                const steps = @min(target - hub.tick, if (mixed) schedule[frame % schedule.len] else 4);
                try hub.advanceFrame(@as(f64, @floatFromInt(steps)) / 240.0, h.neutral_intent);
            }
            const snapshot = hub.world_time.snapshot();
            // Independent authored-policy oracle: one tick is exactly 250,000 us.
            const total = 86_340_000_000 + target * 250_000;
            if (snapshot.simulation_ticks != target or hub.impact.effects.tick() != target or hub.impact.projectiles.tick() != target or
                snapshot.day_index != total / 86_400_000_000 or snapshot.time_of_day_us != total % 86_400_000_000 or snapshot.submicrosecond_remainder != 0 or
                !std.meta.eql(snapshot.configuration, time.configuration)) return error.WorldTimeFixtureMismatch;
            if (mixed) {
                if (!std.meta.eql(result.checkpoints[index], snapshot)) return error.WorldTimeGroupingMismatch;
            } else result.checkpoints[index] = snapshot;
        }
    }
    return result;
}

/// Deliberately failing headless CLI fixture. Supported constructor supplies an
/// unusual initial clock for overflow testing; no live partial-restore API exists.
pub fn verifyOverflow(allocator: std.mem.Allocator, seed: h.Seed) !void {
    var hub = try h.Hub.init(allocator, seed);
    defer hub.deinit() catch |err| h.cleanupFailure(err);
    var snapshot = time.initial_snapshot;
    snapshot.day_index = std.math.maxInt(u64);
    snapshot.time_of_day_us = snapshot.configuration.day_duration_us - 1;
    hub.world_time = try time.WorldTime.fromSnapshot(snapshot);
    if (hub.advanceFrame(8.0 / 240.0, h.neutral_intent)) |_| return error.ExpectedWorldTimeOverflow else |err| {
        if (err != error.WorldDayOverflow) return err;
    }
    if (hub.tick != 1 or hub.impact.effects.tick() != 1 or hub.impact.projectiles.tick() != 1 or hub.calibration.state.fixed_ticks != 1 or
        !std.meta.eql(snapshot, hub.world_time.snapshot())) return error.WorldTimeOverflowPartialTickMismatch;
    const selected = try hub.fingerprint();
    const impact = try hub.impact.fingerprint();
    const calibration = try hub.calibration.fingerprint();
    const clock = hub.clock;
    for ([_]f64{ 0, 8.0 / 240.0 }) |delta| {
        if (hub.advanceFrame(delta, h.neutral_intent)) |_| return error.ExpectedWorldTimeContinuationRejection else |err| {
            if (err != error.WorldTimeTickMismatch) return err;
        }
        if (!(try hub.fingerprint()).eql(selected) or !(try hub.impact.fingerprint()).eql(impact) or !(try hub.calibration.fingerprint()).eql(calibration) or
            !std.meta.eql(clock, hub.clock) or !std.meta.eql(snapshot, hub.world_time.snapshot())) return error.WorldTimeContinuedAfterFailure;
    }
    std.log.info("WORLD_TIME_OVERFLOW_PROPAGATION_OK fixture=validated_unusual_initial_clock hub_tick=1 time_tick=0 requested_steps=8 executed_partial_ticks=1 continuation_rejected=true rollback=false", .{});
    // Preserve a failing process exit: this is evidence of propagation, not a
    // successful simulation. The offline runner checks error and context together.
    return error.WorldDayOverflow;
}
