const std = @import("std");
const h = @import("engine_lab");
const v = @import("engine_lab_view");
const q = @import("render_queue");
const debug = @import("debug_draw");
fn step(hub: *h.Hub) !void {
    try hub.advanceFrame(1.0 / 240.0, h.neutral_intent);
}
fn fill(hub: *h.Hub) !void {
    for (0..8) |_| {
        hub.impact.pending_activation = true;
        try step(hub);
    }
}
test "traversal complete production glyph geometry and effects saturation fits bounded capacities" {
    var hub = try h.Hub.initExpanded(std.testing.allocator, try h.Seed.parseLowerHex(h.default_seed));
    defer hub.deinit() catch |err| h.cleanupFailure(err);
    var view = try v.View.init(std.testing.allocator);
    defer view.deinit();
    var queue = try q.UnifiedRenderQueue.init(std.testing.allocator, v.entry_capacity, v.sprite_capacity, v.mesh_capacity, 2);
    defer queue.deinit();
    queue.markStabilized();
    try hub.navigate(.springs);
    try fill(&hub);
    while (hub.tick < 320) try step(&hub);
    try fill(&hub);
    try std.testing.expectEqual(@as(usize, 192), hub.impact.effects.particleCount());
    for (hub.stations) |station| try std.testing.expectEqual(station.history.len, station.history_count);
    const time_max = try @import("engine_lab_world_time_tests.zig").presentationMaximum();
    var glyphs = debug.CommandBuffer{};
    var hex_max: usize = 0;
    for ("0123456789abcdef") |letter| {
        glyphs.beginFrame();
        hex_max = @max(hex_max, try glyphs.addLabel(.zero, &.{letter}, .{ 1, 1, 1, 1 }));
    }
    var integer_max: usize = 0;
    var integer_value: u64 = 0;
    var decimal_max: usize = 0;
    var text: [32]u8 = undefined;
    for ("0123456789") |letter| {
        glyphs.beginFrame();
        decimal_max = @max(decimal_max, try glyphs.addLabel(.zero, &.{letter}, .{ 1, 1, 1, 1 }));
    }
    for (0..1000) |value| {
        glyphs.beginFrame();
        const cost = try glyphs.addLabel(.zero, try std.fmt.bufPrint(&text, "{d}", .{value}), .{ 1, 1, 1, 1 });
        if (cost > integer_max) {
            integer_max = cost;
            integer_value = value;
        }
    }
    glyphs.beginFrame();
    try std.testing.expectEqual(decimal_max, try glyphs.addLabel(.zero, "0", .{ 1, 1, 1, 1 }));
    var observed: usize = 0;
    var conservative: usize = 0;
    var command_max: usize = 0;
    var frames: usize = 0;
    for (0..9) |removed| {
        for ([_]bool{ false, true }) |paused| for ([_]bool{ false, true }) |diagnostics| for ([_]u64{ 10000000000000000000, std.math.maxInt(u64) }) |counter| {
            hub.tick = counter;
            hub.clock.paused = paused;
            hub.diagnostics_enabled = diagnostics;
            hub.impact.observations.launches = if (counter == std.math.maxInt(u64)) counter else integer_value;
            hub.impact.observations.contacts = hub.impact.observations.launches;
            hub.impact.bridge.metrics.dropped_effects = hub.impact.observations.launches;
            hub.clock.lifetime_discarded_time = if (counter == std.math.maxInt(u64)) std.math.floatMax(f64) else @floatFromInt(integer_value);
            for ([_][2]u32{ .{ 640, 480 }, .{ 1280, 720 }, .{ 960, 720 } }) |viewport| for ([_][2]f32{ .{ 4.5, 1.05 }, .{ -15, 5.85 }, .{ -22, 5.85 } }) |position| {
                // Presentation-only saturation values, explicitly not route evidence.
                try hub.actor.stageControlledTransform(.{ .x = position[0], .y = position[1] }, .right);
                try hub.calibration.reanchor(hub.actor.worldPosition());
                try hub.setViewport(viewport[0], viewport[1]);
                for ([_]f32{ 0, -0.4, 0.4 }) |offset| for ([_]u64{ time_max.day, 999, std.math.maxInt(u64) }) |day| {
                    hub.calibration.state.response = .{ .offset = offset, .velocity = 0 };
                    hub.calibration.previous_response = hub.calibration.state.response;
                    var snapshot = h.world_time_module.initial_snapshot;
                    snapshot.day_index = day;
                    snapshot.time_of_day_us = time_max.minute * 60_000_000;
                    hub.world_time = try h.world_time_module.WorldTime.fromSnapshot(snapshot);
                    try view.render(&hub, &queue);
                    const frame = queue.prepare();
                    try std.testing.expectEqual(@as(usize, 3), frame.ranges.len);
                    observed = @max(observed, frame.sprites.len);
                    command_max = @max(command_max, view.commands.count);
                    frames += 1;
                    var bound = frame.sprites.len;
                    if (diagnostics) {
                        const digest = (try hub.fingerprint()).formatLowerHex();
                        glyphs.beginFrame();
                        const actual = try glyphs.addLabel(.zero, digest[0..12], .{ 1, 1, 1, 1 });
                        bound = bound - actual + 12 * hex_max;
                    }
                    conservative = @max(conservative, bound);
                };
            };
        };
        if (removed < 8) {
            var storage: [8]h.impact_module.p.Snapshot = undefined;
            const values = try hub.impact.projectiles.copySnapshots(&storage);
            try hub.impact.projectiles.remove(values[0].id);
            hub.impact.projectiles.clearEvents();
        }
    }
    std.debug.print("TRAVERSAL_PRESENTATION_BOUND observed={d} conservative={d} sprites={d} entries={d} spare={d} commands={d}/2048 meshes={d} frames={d} batches=3 projectiles=0..8 particles=192 viewports=3 positions=3\n", .{ observed, conservative, v.sprite_capacity, v.entry_capacity, v.sprite_capacity - conservative, command_max, v.mesh_capacity, frames });
    try std.testing.expect(v.sprite_capacity <= 2304 and v.entry_capacity <= 2560 and v.mesh_capacity == 256);
    try std.testing.expect(conservative + 32 <= v.sprite_capacity);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}
