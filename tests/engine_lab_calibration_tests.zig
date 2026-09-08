const std = @import("std");
const h = @import("engine_lab");
const calibration = h.calibration_module;
const verification = @import("engine_lab_verification").calibration;
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const queue_module = @import("render_queue");
fn init(allocator: std.mem.Allocator) !h.Hub {
    return h.Hub.init(allocator, try h.Seed.parseLowerHex(h.default_seed));
}
fn close(hub: *h.Hub) void {
    hub.deinit() catch |err| h.cleanupFailure(err);
}
fn movement(axis: f32) h.Intent {
    var intent = h.neutral_intent;
    intent.move_axis = axis;
    return intent;
}
fn advance(hub: *h.Hub, ticks: usize, axis: f32) !void {
    for (0..ticks) |_| try hub.advanceFrame(1.0 / 240.0, movement(axis));
}
fn rest(hub: *const h.Hub) !void {
    try std.testing.expectEqual(@as(u64, 0), hub.calibration.state.fixed_ticks);
    try std.testing.expectEqual(@as(f32, 0), hub.calibration.state.driver_velocity);
    try std.testing.expectEqualDeep(calibration.motion.Response{}, hub.calibration.state.response);
    try std.testing.expectEqualDeep(hub.calibration.reference, hub.calibration.previous_reference);
    try std.testing.expectEqualDeep(hub.calibration.state.response, hub.calibration.previous_response);
    const position = hub.actor.controllerSnapshot().?.state.position.add(calibration.mount);
    try std.testing.expectEqualDeep(position, hub.calibration.reference);
    for ([_]f64{ 0, 0.25, 0.75, 0.999 }) |alpha| {
        const sample = try hub.calibration.presentation(alpha, hub.clock.paused);
        try std.testing.expectEqualDeep(position, sample.reference);
        try std.testing.expectEqualDeep(position, sample.response);
    }
}

test "calibration actual controller acceleration braking and reversal lag visibly and settle" {
    const result = try verification.verify(std.testing.allocator, try h.Seed.parseLowerHex(h.default_seed));
    for (result.checkpoints) |point| std.debug.print("CALIBRATION_SAMPLE tick={d} offset={d:.6} velocity={d:.6} sha256={s}\n", .{ point.tick, point.offset, point.velocity, point.digest.formatLowerHex() });
    // One centimetre exceeds a subpixel response at the native 82 px/m scale.
    try std.testing.expect(result.checkpoints[1].offset < -0.01);
    try std.testing.expect(result.checkpoints[3].offset > 0.01);
    try std.testing.expect(result.checkpoints[7].offset > 0.01);
    try std.testing.expectEqual(@as(f32, 0), result.checkpoints[result.checkpoints.len - 1].offset);
}

test "calibration steps public solver once per completed controller tick without double forcing" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try rest(&hub);
    var oracle = try calibration.motion.State.init(calibration.profile, hub.calibration.reference.x);
    for (0..480) |index| {
        const previous = hub.calibration;
        var intent = verification.inputAt(hub.tick);
        intent.jump_pressed = index == 30;
        intent.jump_held = index >= 30 and index < 65;
        intent.jump_released = index == 65;
        try hub.advanceFrame(1.0 / 240.0, intent);
        const completed = hub.actor.controllerSnapshot().?.state.position;
        _ = try oracle.step(calibration.profile, .{ .driver = .{ .position = completed.x + calibration.mount.x }, .external_acceleration = 0, .fixed_dt_seconds = 1.0 / 240.0 });
        try std.testing.expectEqualDeep(oracle, hub.calibration.state);
        try std.testing.expectEqual(hub.tick, oracle.fixed_ticks);
        try std.testing.expectEqualDeep(previous.reference, hub.calibration.previous_reference);
        try std.testing.expectEqualDeep(previous.state.response, hub.calibration.previous_response);
        try std.testing.expectEqualDeep(completed.add(calibration.mount), hub.calibration.reference);
    }
}

test "calibration render interpolation follows actor once and cannot change any simulation state" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    var view = try view_module.View.init(tracking.allocator());
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(tracking.allocator(), view_module.legacy_entry_capacity, view_module.legacy_sprite_capacity, view_module.mesh_capacity, 2);
    defer queue.deinit();
    queue.markStabilized();
    try advance(&hub, 30, 1);
    const before = hub.calibration;
    const hub_digest = try hub.fingerprint();
    const impact_digest = try hub.impact.fingerprint();
    tracking.fail_index = tracking.alloc_index;
    tracking.resize_fail_index = tracking.resize_index;
    // Running presentation uses the accepted half-open [0, 1) clock range.
    // Paused presentation below always uses completed state, regardless of alpha.
    for ([_]bool{ false, true }) |paused| for ([_]f64{ 0, 0.25, 0.75, 0.999 }) |alpha| {
        hub.clock.paused = paused;
        hub.clock.last_frame.interpolation_alpha = alpha;
        const sample = try hub.calibration.presentation(alpha, paused);
        // Same f32 metre arithmetic, with a tolerance far below one pixel.
        try std.testing.expect(sample.reference.approxEqAbs((try hub.renderedActorPosition()).add(calibration.mount), 1e-6));
        const expected = if (paused) before.state.response.offset else @as(f32, @floatCast(@as(f64, before.previous_response.offset) + (@as(f64, before.state.response.offset) - before.previous_response.offset) * alpha));
        try std.testing.expectApproxEqAbs(expected, sample.response.x - sample.reference.x, 1e-6);
        try std.testing.expectEqual(sample.reference.y, sample.response.y);
        try view.render(&hub, &queue);
        try std.testing.expectEqual(@as(usize, 3), queue.prepare().ranges.len);
        try std.testing.expectEqualDeep(before, hub.calibration);
        try std.testing.expect(hub_digest.eql(try hub.fingerprint()));
        try std.testing.expect(impact_digest.eql(try hub.impact.fingerprint()));
    };
    try std.testing.expect(!tracking.has_induced_failure);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}

test "calibration pause single step and moving or paused navigation use reset without teleport history" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var mapper = actions.Mapper{};
    try advance(&hub, 30, 1);
    hub.clock.setPaused(true);
    const frozen = hub.calibration;
    try actions.advance(&hub, &mapper, .{}, .{}, 0.1);
    try std.testing.expectEqualDeep(frozen, hub.calibration);
    try actions.advance(&hub, &mapper, .{}, .{ .step = true, .intent = movement(-1) }, 0.1);
    try std.testing.expectEqual(frozen.state.fixed_ticks + 1, hub.calibration.state.fixed_ticks);
    for ([_]bool{ true, false }) |paused| {
        hub.clock.setPaused(paused);
        const tick = hub.tick;
        try actions.advance(&hub, &mapper, .{}, .{ .destination = .springs }, 0);
        try std.testing.expectEqual(tick, hub.tick);
        try rest(&hub);
        hub.clock.setPaused(false);
        try advance(&hub, 1, 0);
        try std.testing.expectEqual(@as(u64, 1), hub.calibration.state.fixed_ticks);
        try std.testing.expectEqualDeep(calibration.motion.Response{}, hub.calibration.state.response);
        try advance(&hub, 30, -1);
    }
}

test "focus loss suppresses held movement without resetting binding or pending derivative history" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var mapper = actions.Mapper{};
    const Raw = @import("physical_input").RawInputState;
    const held = Raw{ .keyboard = .{ .d = true } };
    for (0..30) |_| try actions.advance(&hub, &mapper, held, mapper.sample(held), 1.0 / 240.0);
    const before = hub.calibration;
    const lost = Raw{ .keyboard_focused = false, .focus_lost = true, .keyboard = .{ .d = true } };
    try actions.advance(&hub, &mapper, lost, mapper.sample(lost), 0);
    try std.testing.expectEqualDeep(before, hub.calibration);
    try actions.advance(&hub, &mapper, held, mapper.sample(held), 1.0 / 240.0);
    try std.testing.expectEqual(before.state.fixed_ticks + 1, hub.calibration.state.fixed_ticks);
    try std.testing.expectEqual(before.state.response.offset, hub.calibration.previous_response.offset);
    try std.testing.expectEqual(@as(f32, 0), mapper.sample(held).intent.move_axis);
}

fn live(hub: *h.Hub) !void {
    try hub.navigate(.springs);
    hub.impact.pending_activation = true;
    try advance(hub, 312, 0);
    hub.impact.pending_activation = true;
    try advance(hub, 30, -1);
    try std.testing.expect(hub.impact.projectiles.count() > 0 and hub.impact.effects.particleCount() > 0);
    try std.testing.expect(hub.calibration.state.response.offset > 0.01);
}

test "reset dominates live effects motion and same frame controls and restores full hub at rest" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var fresh = try init(std.testing.allocator);
    defer close(&fresh);
    var mapper = actions.Mapper{};
    try live(&hub);
    try actions.advance(&hub, &mapper, .{}, .{ .reset = true, .pause = true, .step = true, .activate = true, .destination = .springs, .intent = movement(1) }, 0.1);
    try rest(&hub);
    try std.testing.expectEqual(@as(u64, 0), hub.tick);
    try std.testing.expect((try fresh.fingerprint()).eql(try hub.fingerprint()));
    try std.testing.expect((try fresh.impact.fingerprint()).eql(try hub.impact.fingerprint()));
    try std.testing.expectEqualDeep(fresh.calibration, hub.calibration);
}

test "every allocation-failed reconstruction preserves live binding projectiles particles and hub" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    const construction_allocations = tracking.alloc_index;
    try live(&hub);
    const before = hub.calibration;
    const hub_digest = try hub.fingerprint();
    const impact_digest = try hub.impact.fingerprint();
    const clock_before = hub.clock;
    const camera_before = hub.camera;
    const pending_before = hub.pending;
    for (0..construction_allocations) |failure| {
        const live_bytes = tracking.allocated_bytes - tracking.freed_bytes;
        tracking.fail_index = tracking.alloc_index + failure;
        tracking.has_induced_failure = false;
        if (hub.reset()) |_| return error.ExpectedReconstructionFailure else |_| try std.testing.expect(tracking.has_induced_failure);
        try std.testing.expectEqual(live_bytes, tracking.allocated_bytes - tracking.freed_bytes);
        try std.testing.expectEqualDeep(clock_before, hub.clock);
        try std.testing.expectEqualDeep(camera_before, hub.camera);
        try std.testing.expectEqualDeep(pending_before, hub.pending);
        try std.testing.expectEqualDeep(before, hub.calibration);
        try std.testing.expect(hub_digest.eql(try hub.fingerprint()));
        try std.testing.expect(impact_digest.eql(try hub.impact.fingerprint()));
    }
    tracking.fail_index = std.math.maxInt(usize);
    try advance(&hub, 1, 0);
    try std.testing.expectEqual(before.state.fixed_ticks + 1, hub.calibration.state.fixed_ticks);
}
