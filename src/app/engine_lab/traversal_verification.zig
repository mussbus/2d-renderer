const std = @import("std");
const h = @import("engine_lab");

pub const Scenario = enum { easy, shortcut };
pub const Checkpoint = struct { tick: u64, digest: h.Digest };
pub const Segment = struct {
    name: []const u8,
    ticks: u16,
    axis: f32 = -1,
    jump: bool = false,
    dash: bool = false,
    approach: bool = false,
    support: ?u16 = null,
    capture: bool = false,
};
// Authored semantic inputs; edges are isolated first ticks, never smeared across
// frame groupings. Starts are reached from normal spawn without position writes.
pub const easy = [_]Segment{
    .{ .name = "lower-floor", .ticks = 148, .approach = true, .support = 1, .capture = true },
    .{ .name = "easy-ascent", .ticks = 90, .jump = true, .capture = true },
    .{ .name = "first-landing", .ticks = 38, .support = 10, .capture = true },
    .{ .name = "first-brake", .ticks = 32, .axis = 0, .support = 10 },
    .{ .name = "second-approach", .ticks = 37, .support = 10 },
    .{ .name = "second-landing", .ticks = 128, .jump = true, .support = 11 },
    .{ .name = "second-brake", .ticks = 32, .axis = 0, .support = 11 },
    .{ .name = "upper-approach", .ticks = 37, .support = 11 },
    .{ .name = "upper-landing", .ticks = 128, .jump = true, .support = 12, .capture = true },
    .{ .name = "upper-hud", .ticks = 32, .axis = 0, .support = 12, .capture = true },
    .{ .name = "dash-approach", .ticks = 43, .support = 12 },
    .{ .name = "gap-jump", .ticks = 40, .jump = true },
    .{ .name = "dash-crossing", .ticks = 29, .dash = true, .capture = true },
    .{ .name = "dash-contact", .ticks = 110, .support = 13 },
    .{ .name = "dash-landing", .ticks = 32, .axis = 0, .support = 13, .capture = true },
    .{ .name = "descent", .ticks = 200, .axis = 1 },
    .{ .name = "safe-descent", .ticks = 32, .axis = 0, .support = 1, .capture = true },
};
pub const shortcut = [_]Segment{
    .{ .name = "air-approach", .ticks = 71, .support = 1 },
    .{ .name = "air-ground-jump", .ticks = 85, .jump = true },
    .{ .name = "air-shortcut", .ticks = 90, .jump = true, .capture = true },
    .{ .name = "air-contact", .ticks = 53, .support = 11 },
    .{ .name = "air-landing", .ticks = 32, .axis = 0, .support = 11, .capture = true },
    .{ .name = "air-upper-approach", .ticks = 61, .support = 11 },
    .{ .name = "air-upper-landing", .ticks = 128, .jump = true, .support = 12, .capture = true },
};
pub fn segments(scenario: Scenario) []const Segment {
    return if (scenario == .easy) &easy else &shortcut;
}
pub fn input(hub: *const h.Hub, segment: Segment, elapsed: u64) h.Intent {
    var intent = h.neutral_intent;
    intent.move_axis = if (segment.approach) std.math.clamp((-5.7 - hub.actor.worldPosition().x) * 3, -1, 1) else segment.axis;
    intent.jump_pressed = segment.jump and elapsed == 0;
    intent.jump_held = true;
    intent.dash_pressed = segment.dash and elapsed == 0;
    return intent;
}
pub fn steps(segment: Segment, elapsed: u64, mixed: bool, frame: usize) u64 {
    if (segment.approach or (elapsed == 0 and (segment.jump or segment.dash))) return 1;
    const grouping = [_]u64{ 1, 3, 2 };
    return @min(segment.ticks - elapsed, if (mixed) grouping[frame % grouping.len] else 4);
}
pub fn validateBoundary(hub: *const h.Hub, segment: Segment) !void {
    if (segment.support) |id| {
        const state = hub.actor.controllerSnapshot().?.state;
        if (!state.grounded or state.supporting_collider != id) {
            std.log.err("traversal {s}: expected support {d}; actual {any}, root={any}", .{ segment.name, id, state.supporting_collider, state.position });
            return error.TraversalLandingMismatch;
        }
    }
    if (hub.tick != hub.world_time.snapshot().simulation_ticks or hub.tick != hub.impact.effects.tick() or hub.tick != hub.impact.projectiles.tick()) return error.TraversalTickMismatch;
    for (hub.stations) |station| if (station.updates != hub.tick) return error.TraversalStationMismatch;
}
pub const Result = struct { checkpoints: [easy.len + shortcut.len + 2]Checkpoint };
pub fn verify(allocator: std.mem.Allocator, seed: h.Seed) !Result {
    var result: Result = undefined;
    var next: usize = 0;
    for ([_]Scenario{ .easy, .shortcut }) |scenario| {
        var hub = try h.Hub.initExpanded(allocator, seed);
        defer hub.deinit() catch |err| h.cleanupFailure(err);
        const offset = next;
        result.checkpoints[next] = .{ .tick = 0, .digest = try hub.traversalFingerprint() };
        next += 1;
        for ([_]bool{ false, true }) |mixed| {
            if (mixed) try hub.reset();
            var checkpoint = offset + 1;
            var frame: usize = 0;
            for (segments(scenario)) |segment| {
                var elapsed: u64 = 0;
                while (elapsed < segment.ticks) : (frame += 1) {
                    const count = steps(segment, elapsed, mixed, frame);
                    try hub.advanceFrame(@as(f64, @floatFromInt(count)) / 240.0, input(&hub, segment, elapsed));
                    elapsed += count;
                }
                try validateBoundary(&hub, segment);
                const digest = try hub.traversalFingerprint();
                if (mixed) {
                    if (hub.tick != result.checkpoints[checkpoint].tick or !digest.eql(result.checkpoints[checkpoint].digest)) return error.TraversalGroupingMismatch;
                } else {
                    result.checkpoints[checkpoint] = .{ .tick = hub.tick, .digest = digest };
                    next += 1;
                }
                checkpoint += 1;
            }
        }
    }
    if (next != result.checkpoints.len) return error.TraversalCheckpointCount;
    return result;
}
