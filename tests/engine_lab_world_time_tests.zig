const std = @import("std");
const h = @import("engine_lab");
const time = h.world_time_module;
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const queue_module = @import("render_queue");
const debug = @import("debug_draw");
fn init(allocator: std.mem.Allocator) !h.Hub {
    return h.Hub.init(allocator, try h.Seed.parseLowerHex(h.default_seed));
}
fn close(hub: *h.Hub) void {
    hub.deinit() catch |err| h.cleanupFailure(err);
}
fn advance(hub: *h.Hub, ticks: usize) !void {
    for (0..ticks) |_| try hub.advanceFrame(1.0 / 240.0, h.neutral_intent);
}
fn exact(hub: *const h.Hub, ticks: u64, day: u64, us: u64) !void {
    try std.testing.expectEqualDeep(time.Snapshot{ .configuration = .{ .simulation_hz = 240, .rate = .{ .numerator = 60, .denominator = 1 }, .day_duration_us = 86_400_000_000 }, .simulation_ticks = ticks, .day_index = day, .time_of_day_us = us }, hub.world_time.snapshot());
    try std.testing.expectEqual(ticks, hub.tick);
    try std.testing.expectEqual(ticks, hub.impact.effects.tick());
    try std.testing.expectEqual(ticks, hub.impact.projectiles.tick());
}

test "World Time actual hub initial values exact executed ticks and zero-step frames" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try exact(&hub, 0, 0, 86_340_000_000);
    for ([_]f64{ 0, -1, 1.0 / 960.0 }) |delta| {
        try hub.advanceFrame(delta, h.neutral_intent);
        try exact(&hub, 0, 0, 86_340_000_000);
    }
    try advance(&hub, 1);
    try exact(&hub, 1, 0, 86_340_250_000);
    try advance(&hub, 7);
    try exact(&hub, 8, 0, 86_342_000_000);
}

test "World Time pause at 239 single step rolls to day one navigation retains entire snapshot" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var mapper = actions.Mapper{};
    try advance(&hub, 239);
    try exact(&hub, 239, 0, 86_399_750_000);
    try actions.advance(&hub, &mapper, .{}, .{ .pause = true }, 0.1);
    for (0..5) |_| try actions.advance(&hub, &mapper, .{}, .{}, 0.1);
    try exact(&hub, 239, 0, 86_399_750_000);
    for ([_]h.Destination{ .springs, .hierarchy }) |destination| {
        const frozen = hub.world_time.snapshot();
        try actions.advance(&hub, &mapper, .{}, .{ .destination = destination }, 0);
        try std.testing.expectEqualDeep(frozen, hub.world_time.snapshot());
        try std.testing.expectEqual(@as(u64, 0), hub.calibration.state.fixed_ticks);
        if (hub.tick == 239) {
            try actions.advance(&hub, &mapper, .{}, .{ .step = true }, 0.1);
            try exact(&hub, 240, 1, 0);
        }
    }
    hub.clock.setPaused(false);
    const frozen = hub.world_time.snapshot();
    try hub.navigate(.springs);
    try std.testing.expectEqualDeep(frozen, hub.world_time.snapshot());
    try advance(&hub, 1);
    try exact(&hub, 241, 1, 250_000);
    try std.testing.expectEqual(@as(u64, 1), hub.calibration.state.fixed_ticks);
}

test "World Time focus loss retains existing input policy and large deltas count only executed capped ticks" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var mapper = actions.Mapper{};
    const Raw = @import("physical_input").RawInputState;
    const held = Raw{ .keyboard = .{ .d = true, .e = true } };
    try actions.advance(&hub, &mapper, held, mapper.sample(held), 1.0 / 240.0);
    const lost = Raw{ .keyboard_focused = false, .focus_lost = true, .keyboard = held.keyboard };
    const before = hub.world_time.snapshot();
    try actions.advance(&hub, &mapper, lost, mapper.sample(lost), 0);
    try std.testing.expectEqualDeep(before, hub.world_time.snapshot());
    try actions.advance(&hub, &mapper, lost, mapper.sample(lost), 100);
    try exact(&hub, 9, 0, 86_342_250_000);
    try std.testing.expect(!hub.clock.paused and !hub.impact.pending_activation);
    try std.testing.expectEqual(@as(u8, 8), hub.clock.last_frame.substeps);
    try std.testing.expect(hub.clock.lifetime_discarded_time > 0);
    try std.testing.expectEqual(@as(f32, 0), mapper.sample(held).intent.move_axis);
}

test "World Time complete snapshots match under equivalent command schedules and frame groupings" {
    _ = try @import("engine_lab_verification").world_time.verify(std.testing.allocator, try h.Seed.parseLowerHex(h.default_seed));
    var left = try init(std.testing.allocator);
    defer close(&left);
    var right = try init(std.testing.allocator);
    defer close(&right);
    for (0..3) |segment| {
        var intent = h.neutral_intent;
        intent.move_axis = if (segment == 0) 1 else if (segment == 1) -1 else 0;
        if (segment == 1) {
            try left.navigate(.springs);
            try right.navigate(.springs);
            left.impact.pending_activation = true;
            right.impact.pending_activation = true;
        }
        for (0..20) |_| {
            try left.advanceFrame(4.0 / 240.0, intent);
            try right.advanceFrame(1.0 / 240.0, intent);
            try right.advanceFrame(3.0 / 240.0, intent);
        }
        try std.testing.expectEqualDeep(left.world_time.snapshot(), right.world_time.snapshot());
        try std.testing.expect((try left.fingerprint()).eql(try right.fingerprint()));
        try std.testing.expect((try left.impact.fingerprint()).eql(try right.impact.fingerprint()));
        try std.testing.expect((try left.calibration.fingerprint()).eql(try right.calibration.fingerprint()));
    }
}

test "World Time copied observation is independent and supported reconstruction preserves nonzero carry continuation" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try advance(&hub, 239);
    const observed = hub.world_time.snapshot();
    var copy = observed;
    copy.day_index = 999;
    copy.time_of_day_us = 0;
    copy.configuration.rate.numerator = 1;
    try std.testing.expectEqual(@as(u64, 999), copy.day_index);
    try std.testing.expectEqualDeep(observed, hub.world_time.snapshot());
    var restored = try time.WorldTime.fromSnapshot(observed);
    try restored.advanceSimulationTicks(1);
    try advance(&hub, 1);
    try std.testing.expectEqualDeep(restored.snapshot(), hub.world_time.snapshot());
    // Valid unusual test clock; no public live-hub restore operation is added.
    // A nonzero carry under 1/7 rate proves that continuation uses more than HH:MM.
    var unusual = time.initial_snapshot;
    unusual.configuration.rate = .{ .numerator = 1, .denominator = 7 };
    unusual.submicrosecond_remainder = 160;
    try hub.reset();
    hub.world_time = try time.WorldTime.fromSnapshot(unusual);
    restored = try time.WorldTime.fromSnapshot(hub.world_time.snapshot());
    try hub.navigate(.springs);
    try std.testing.expectEqualDeep(unusual, hub.world_time.snapshot());
    try restored.advanceSimulationTicks(17);
    try advance(&hub, 17);
    try std.testing.expectEqualDeep(restored.snapshot(), hub.world_time.snapshot());
    try std.testing.expectEqual(@as(u64, 86_340_010_119), restored.snapshot().time_of_day_us);
    try std.testing.expectEqual(@as(u64, 240), restored.snapshot().submicrosecond_remainder);
}

test "World Time rendering all supported alphas preserves exact time and prior simulation without allocations" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    var view = try view_module.View.init(tracking.allocator());
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(tracking.allocator(), view_module.entry_capacity, view_module.sprite_capacity, view_module.mesh_capacity, 2);
    defer queue.deinit();
    queue.markStabilized();
    try hub.navigate(.springs);
    hub.impact.pending_activation = true;
    try advance(&hub, 312);
    hub.impact.pending_activation = true;
    var move = h.neutral_intent;
    move.move_axis = -1;
    for (0..30) |_| try hub.advanceFrame(1.0 / 240.0, move);
    const snapshot = hub.world_time.snapshot();
    const selected = try hub.fingerprint();
    const impact = try hub.impact.fingerprint();
    const calibration = hub.calibration;
    const allocations = tracking.alloc_index;
    const resizes = tracking.resize_index;
    tracking.fail_index = allocations;
    tracking.resize_fail_index = resizes;
    for ([_]bool{ false, true }) |paused| for ([_]f64{ 0, 0.25, 0.75, 0.999 }) |alpha| {
        hub.clock.paused = paused;
        hub.clock.last_frame.interpolation_alpha = alpha;
        try view.render(&hub, &queue);
        try std.testing.expectEqualDeep(snapshot, hub.world_time.snapshot());
        try std.testing.expectEqualDeep(calibration, hub.calibration);
        try std.testing.expect(selected.eql(try hub.fingerprint()));
        try std.testing.expect(impact.eql(try hub.impact.fingerprint()));
        try std.testing.expectEqual(@as(usize, 3), queue.prepare().ranges.len);
        try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
    };
    try std.testing.expectEqual(allocations, tracking.alloc_index);
    try std.testing.expectEqual(resizes, tracking.resize_index);
    try std.testing.expect(!tracking.has_induced_failure);
}

test "World Time reset dominates live effects and every failed reconstruction preserves full prior state" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    const construction_allocations = tracking.alloc_index;
    try hub.navigate(.springs);
    hub.impact.pending_activation = true;
    try advance(&hub, 312);
    hub.impact.pending_activation = true;
    var move = h.neutral_intent;
    move.move_axis = -1;
    for (0..30) |_| try hub.advanceFrame(1.0 / 240.0, move);
    try std.testing.expect(hub.impact.projectiles.count() > 0 and hub.impact.effects.particleCount() > 0 and hub.calibration.state.response.offset > 0.01);
    const snapshot = hub.world_time.snapshot();
    const calibration = hub.calibration;
    const selected = try hub.fingerprint();
    const impact = try hub.impact.fingerprint();
    const clock = hub.clock;
    const camera = hub.camera;
    const pending = hub.pending;
    var mapper = actions.Mapper{};
    const command = actions.Actions{ .reset = true, .pause = true, .step = true, .activate = true, .destination = .hierarchy, .intent = move };
    for (0..construction_allocations) |failure| {
        const live_bytes = tracking.allocated_bytes - tracking.freed_bytes;
        tracking.fail_index = tracking.alloc_index + failure;
        tracking.has_induced_failure = false;
        if (actions.advance(&hub, &mapper, .{}, command, 0.1)) |_| return error.ExpectedResetFailure else |_| try std.testing.expect(tracking.has_induced_failure);
        try std.testing.expectEqual(live_bytes, tracking.allocated_bytes - tracking.freed_bytes);
        try std.testing.expectEqualDeep(snapshot, hub.world_time.snapshot());
        try std.testing.expectEqualDeep(calibration, hub.calibration);
        try std.testing.expectEqualDeep(clock, hub.clock);
        try std.testing.expectEqualDeep(camera, hub.camera);
        try std.testing.expectEqualDeep(pending, hub.pending);
        try std.testing.expect(selected.eql(try hub.fingerprint()));
        try std.testing.expect(impact.eql(try hub.impact.fingerprint()));
    }
    tracking.fail_index = std.math.maxInt(usize);
    try actions.advance(&hub, &mapper, .{}, command, 0.1);
    try exact(&hub, 0, 0, 86_340_000_000);
    try std.testing.expect(!hub.clock.paused);
    try std.testing.expectEqual(@as(u64, 0), hub.calibration.state.fixed_ticks);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.count());
    try std.testing.expectEqual(@as(usize, 0), hub.impact.effects.particleCount());
    std.debug.print("WORLD_TIME_RESET_FAILURES_OK allocation_prefixes={d} full_live_state_preserved=true dominant_reset_ticks=0\n", .{construction_allocations});
}

test "World Time minute flooring day overflow label and full integer diagnostics are bounded" {
    var buffer: [time.label_capacity]u8 = undefined;
    const cases = [_]struct { day: u64, us: u64, expected: []const u8 }{
        .{ .day = 0, .us = 0, .expected = "D0 00:00" },
        .{ .day = 0, .us = 59_999_999, .expected = "D0 00:00" },
        .{ .day = 0, .us = 60_000_000, .expected = "D0 00:01" },
        .{ .day = 9, .us = 3_599_999_999, .expected = "D9 00:59" },
        .{ .day = 10, .us = 3_600_000_000, .expected = "D10 01:00" },
        .{ .day = 999, .us = 86_399_999_999, .expected = "D999 23:59" },
        .{ .day = 1000, .us = 0, .expected = "D1000UP 00:00" },
        .{ .day = std.math.maxInt(u64), .us = 86_399_999_999, .expected = "D1000UP 23:59" },
    };
    for (cases) |case| {
        var snapshot = time.initial_snapshot;
        snapshot.day_index = case.day;
        snapshot.time_of_day_us = case.us;
        snapshot.submicrosecond_remainder = 239;
        const clock = try time.WorldTime.fromSnapshot(snapshot);
        try std.testing.expectEqualStrings(case.expected, try time.formatLabel(clock.snapshot(), &buffer));
        try std.testing.expectEqual(case.day, clock.snapshot().day_index);
    }
    var diagnostic_buffer: [time.diagnostic_capacity]u8 = undefined;
    const extreme = try time.WorldTime.fromSnapshot(.{ .configuration = .{ .simulation_hz = std.math.maxInt(u32), .rate = .{ .numerator = std.math.maxInt(u32), .denominator = std.math.maxInt(u32) }, .day_duration_us = std.math.maxInt(u64) }, .simulation_ticks = std.math.maxInt(u64), .day_index = std.math.maxInt(u64), .time_of_day_us = std.math.maxInt(u64) - 1, .submicrosecond_remainder = @as(u64, std.math.maxInt(u32)) * std.math.maxInt(u32) - 1 });
    const diagnostic = try time.diagnostic(extreme.snapshot(), &diagnostic_buffer);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "day_index=18446744073709551615") != null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "submicrosecond_remainder=18446744065119617024") != null);
}

pub const PresentationMaximum = struct { day: u64, minute: u64, sprites: usize, width: f32 };
fn measure(text: []const u8) !struct { count: usize, width: f32 } {
    var glyphs = debug.CommandBuffer{};
    _ = try glyphs.addLabel(.zero, text, .{ 1, 1, 1, 1 });
    var left: f32 = std.math.inf(f32);
    var right: f32 = -std.math.inf(f32);
    for (glyphs.commands[0..glyphs.count]) |command| {
        left = @min(left, command.world_position[0] - command.scale[0] * 0.5);
        right = @max(right, command.world_position[0] + command.scale[0] * 0.5);
    }
    return .{ .count = glyphs.count, .width = (right - left) * 1.6 };
}
/// Exhaustive legal day prefixes and all 1,440 minute suffixes; production font
/// emits independent per-character sprites, so the separate maxima are additive.
pub fn presentationMaximum() !PresentationMaximum {
    var snapshot = time.initial_snapshot;
    snapshot.time_of_day_us = 0;
    var buffer: [time.label_capacity]u8 = undefined;
    var max_day: u64 = 0;
    var day_cost: usize = 0;
    var width: f32 = 0;
    for (0..1001) |day| {
        snapshot.day_index = day;
        const measured = try measure(try time.formatLabel(snapshot, &buffer));
        width = @max(width, measured.width);
        if (measured.count > day_cost) {
            max_day = day;
            day_cost = measured.count;
        }
    }
    snapshot.day_index = max_day;
    var maximum: PresentationMaximum = .{ .day = max_day, .minute = 0, .sprites = 0, .width = width };
    for (0..1440) |minute| {
        snapshot.time_of_day_us = minute * 60_000_000;
        const measured = try measure(try time.formatLabel(snapshot, &buffer));
        maximum.width = @max(maximum.width, measured.width);
        if (measured.count > maximum.sprites) {
            maximum.minute = minute;
            maximum.sprites = measured.count;
        }
    }
    return maximum;
}

test "World Time worst legal production glyph count and widest label fit the native camera anchored HUD" {
    const maximum = try presentationMaximum();
    try std.testing.expect(maximum.sprites <= view_module.time_sprite_allowance);
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var view = try view_module.View.init(std.testing.allocator);
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(std.testing.allocator, view_module.entry_capacity, view_module.sprite_capacity, view_module.mesh_capacity, 2);
    defer queue.deinit();
    // Presentation-only validated snapshots, never claimed as simulated history.
    for ([_]u64{ 0, 999, 1000, maximum.day, std.math.maxInt(u64) }) |day| for ([_]u64{ 0, maximum.minute, 1439 }) |minute| for ([_]h.Destination{ .hierarchy, .springs }) |destination| {
        try hub.navigate(destination);
        var snapshot = time.initial_snapshot;
        snapshot.day_index = day;
        snapshot.time_of_day_us = minute * 60_000_000;
        hub.world_time = try time.WorldTime.fromSnapshot(snapshot);
        try view.render(&hub, &queue);
        try std.testing.expect(view.time_sprite_count <= maximum.sprites);
        const half = try hub.camera.worldHalfExtents();
        var left: f32 = std.math.inf(f32);
        var right: f32 = -std.math.inf(f32);
        for (view.commands.commands[view.commands.count - view.time_sprite_count .. view.commands.count]) |command| {
            left = @min(left, command.world_position[0] - command.scale[0] * 0.5);
            right = @max(right, command.world_position[0] + command.scale[0] * 0.5);
            try std.testing.expect(command.world_position[1] + command.scale[1] * 0.5 < hub.camera.center.y + half.y);
        }
        // Metre arithmetic in f32; 1e-5 m is much less than one native pixel.
        try std.testing.expectApproxEqAbs(hub.camera.center.x + half.x - 0.2, right, 1e-5);
        try std.testing.expect(right - left <= maximum.width + 1e-5);
        try std.testing.expect(left > hub.camera.center.x + half.x - 1.4);
        try std.testing.expectEqualDeep(snapshot, hub.world_time.snapshot());
    };
    std.debug.print("WORLD_TIME_GLYPH_BOUND day={d} minute={d} max_sprites={d}/128 max_width_pixels={d:.3} native=640x480 camera_anchored=true exhaustive_days=1001 exhaustive_minutes=1440\n", .{ maximum.day, maximum.minute, maximum.sprites, maximum.width * 82 });
}
