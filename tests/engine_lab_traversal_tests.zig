const std = @import("std");
const h = @import("engine_lab");
const collision = @import("collider");
const actions = @import("engine_lab_actions");
const Raw = @import("physical_input").RawInputState;
const view_module = @import("engine_lab_view");
const queue_module = @import("render_queue");
fn init(allocator: std.mem.Allocator) !h.Hub {
    return h.Hub.initExpanded(allocator, try h.Seed.parseLowerHex(h.default_seed));
}
fn close(hub: *h.Hub) void {
    hub.deinit() catch |err| h.cleanupFailure(err);
}
fn tick(hub: *h.Hub, axis: f32, jump: bool, dash: bool) !void {
    var intent = h.neutral_intent;
    intent.move_axis = axis;
    intent.jump_pressed = jump;
    intent.jump_held = true;
    intent.dash_pressed = dash;
    try hub.advanceFrame(1.0 / 240.0, intent);
    const c = hub.actor.controllerSnapshot().?;
    try std.testing.expect(!try hub.world.containsPenetrationBeyond(try collision.characterBounds(c.state.position, c.configuration.collider_half_extents), c.configuration.ground_epsilon));
}
fn report(hub: *h.Hub, name: []const u8) void {
    const s = hub.actor.controllerSnapshot().?.state;
    std.debug.print("TRAVERSAL_ROUTE {s} tick={d} x={d:.6} y={d:.6} vx={d:.3} vy={d:.3} support={any} jump={any} dash={}\n", .{ name, hub.tick, s.position.x, s.position.y, s.velocity.x, s.velocity.y, s.supporting_collider, hub.last_physical.jump_source, hub.last_physical.dash_started });
}
fn moveTo(hub: *h.Hub, x: f32) !void {
    for (0..2000) |_| {
        const s = hub.actor.controllerSnapshot().?.state;
        if (@abs(s.position.x - x) < 0.015 and @abs(s.velocity.x) < 0.04) return;
        try tick(hub, std.math.clamp((x - s.position.x) * 3, -1, 1), false, false);
    }
    report(hub, "move_timeout");
    return error.RouteApproachTimeout;
}
fn runTo(hub: *h.Hub, x: f32, axis: f32) !void {
    for (0..2000) |_| {
        if ((hub.actor.worldPosition().x - x) * axis >= 0) return;
        try tick(hub, axis, false, false);
    }
    return error.RouteRunTimeout;
}
fn jumpLand(hub: *h.Hub, axis: f32, air_tick: ?usize, dash_tick: ?usize, surface: u32) !void {
    for (0..500) |i| {
        try tick(hub, axis, i == 0 or (air_tick != null and i == air_tick.?), dash_tick != null and i == dash_tick.?);
        if (hub.last_physical.jump_accepted or hub.last_physical.dash_started) report(hub, "event");
        if (i > 0 and hub.actor.controllerSnapshot().?.state.grounded) {
            report(hub, "land");
            try std.testing.expectEqual(surface, hub.actor.controllerSnapshot().?.state.supporting_collider.?);
            for (0..32) |_| try tick(hub, 0, false, false);
            report(hub, "braked");
            return;
        }
    }
    return error.RouteLandingTimeout;
}
test "traversal authored easy route reaches three named supports with production jumps" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try moveTo(&hub, -5.7);
    report(&hub, "easy_start");
    try jumpLand(&hub, -1, null, null, 10);
    try runTo(&hub, -8.55, -1);
    report(&hub, "second_start");
    try jumpLand(&hub, -1, null, null, 11);
    try runTo(&hub, -12.25, -1);
    report(&hub, "upper_start");
    try jumpLand(&hub, -1, null, null, 12);
    try runTo(&hub, -16.1, -1);
    report(&hub, "dash_start");
    try jumpLand(&hub, -1, null, 40, 13);
}

test "traversal air shortcut skips first ledge and lands on second support" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try runTo(&hub, -5.7, -1);
    report(&hub, "air_start");
    try jumpLand(&hub, -1, 85, null, 11);
}

test "traversal authored schedules preserve exact expanded checkpoints across frame groupings" {
    _ = try @import("engine_lab_verification").traversal.verify(std.testing.allocator, try h.Seed.parseLowerHex(h.default_seed));
}

test "traversal movement profile enables one air jump and original dash ordering timers and wall termination" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    const config = hub.actor.controllerSnapshot().?.configuration;
    try std.testing.expectEqual(@as(f32, 4.5), config.maximum_run_speed);
    try std.testing.expectEqual(@as(f32, 9), config.jump_speed);
    try std.testing.expectEqual(@as(f32, -28), config.gravity);
    try std.testing.expect(!hub.actor.hasEquipment() and hub.actor.definitionView().anatomy_definition == null);
    for (0..50) |_| try tick(&hub, -1, false, false);
    try std.testing.expectEqual(@as(f32, -5.5), hub.actor.controllerSnapshot().?.state.velocity.x);
    try hub.reset();
    try tick(&hub, 0, true, true);
    try std.testing.expect(hub.last_physical.jump_source == .grounded and hub.last_physical.dash_started);
    var state = hub.actor.controllerSnapshot().?.state;
    try std.testing.expectEqual(@as(f32, 12), state.velocity.x);
    // 1e-5 m/s covers one f32 multiply/add at the production fixed timestep.
    try std.testing.expectApproxEqAbs(@as(f32, 10.5) + config.gravity * config.fixed_dt, state.velocity.y, 1e-5);
    try std.testing.expectEqual(@as(u16, 28), state.dash_ticks_remaining);
    try std.testing.expectEqual(@as(u16, 76), state.dash_cooldown_ticks_remaining);
    try tick(&hub, -1, false, true);
    try std.testing.expect(hub.last_physical.dash_denied);
    try std.testing.expect(hub.actor.controllerSnapshot().?.state.dash_direction == .right);
    for (0..27) |_| try tick(&hub, 0, false, false);
    try std.testing.expect(hub.last_physical.dash_ended);
    try tick(&hub, -1, true, false);
    try std.testing.expect(hub.last_physical.jump_source == .air);
    try tick(&hub, 0, true, false);
    try std.testing.expect(!hub.last_physical.jump_accepted);
    try std.testing.expectEqual(@as(u8, 1), hub.actor.controllerSnapshot().?.state.air_jumps_used);
    for (0..500) |_| {
        try tick(&hub, 0, false, false);
        if (hub.actor.controllerSnapshot().?.state.grounded) break;
    }
    try std.testing.expect(hub.actor.controllerSnapshot().?.state.grounded);
    try std.testing.expectEqual(@as(u8, 0), hub.actor.controllerSnapshot().?.state.air_jumps_used);
    try tick(&hub, -1, true, true);
    try std.testing.expect(hub.last_physical.jump_source == .grounded and hub.last_physical.dash_started);
    try std.testing.expect(hub.actor.controllerSnapshot().?.state.dash_direction == .left);
    try tick(&hub, 0, true, false);
    try std.testing.expect(hub.last_physical.jump_source == .air);
    try hub.navigate(.springs);
    try runTo(&hub, 7.4, 1);
    try tick(&hub, 1, false, true);
    try std.testing.expect(hub.last_physical.dash_started);
    for (0..29) |_| {
        try tick(&hub, 1, false, false);
        if (hub.last_physical.wall_collision) break;
    }
    try std.testing.expect(hub.last_physical.wall_collision and hub.last_physical.dash_ended);
    state = hub.actor.controllerSnapshot().?.state;
    try std.testing.expectEqual(@as(u16, 0), state.dash_ticks_remaining);
    try std.testing.expectApproxEqAbs(@as(f32, 7.7), state.position.x, 0.0002); // Existing ground epsilon plus f32 sweep rounding.
    try tick(&hub, -1, false, true);
    try std.testing.expect(hub.last_physical.dash_denied);
}

test "traversal dash input edges short taps holding focus pause navigation and reset remain separate" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var mapper = actions.Mapper{};
    for ([_]bool{ false, true }) |gamepad| {
        try hub.reset();
        mapper = .{};
        if (gamepad) mapper.captureGamepadDashPress() else mapper.capturePress(.{ .left_shift = true });
        var command = mapper.sample(.{});
        try std.testing.expect(command.intent.dash_pressed and !command.intent.jump_pressed and !command.activate);
        try actions.advance(&hub, &mapper, .{}, command, 0);
        try std.testing.expect(hub.pending.dash_pressed and hub.tick == 0);
        command = mapper.sample(.{});
        try actions.advance(&hub, &mapper, .{}, command, 4.0 / 240.0);
        try std.testing.expect(!hub.pending.dash_pressed and hub.tick == 4);
        try std.testing.expectEqual(@as(u16, 25), hub.actor.controllerSnapshot().?.state.dash_ticks_remaining);
        const held = if (gamepad) Raw{ .gamepad_button_right_shoulder = true } else Raw{ .keyboard = .{ .left_shift = true } };
        _ = mapper.sample(held);
        for (0..100) |_| try actions.advance(&hub, &mapper, held, mapper.sample(held), 1.0 / 240.0);
        try std.testing.expectEqual(@as(u16, 0), hub.actor.controllerSnapshot().?.state.dash_ticks_remaining);
        _ = mapper.sample(.{});
        try actions.advance(&hub, &mapper, held, mapper.sample(held), 0);
        try std.testing.expect(hub.pending.dash_pressed);
        const lost = Raw{ .focus_lost = true, .keyboard_focused = false, .keyboard = held.keyboard, .gamepad_button_right_shoulder = held.gamepad_button_right_shoulder };
        try actions.advance(&hub, &mapper, lost, mapper.sample(lost), 0);
        try std.testing.expect(!hub.pending.dash_pressed and !mapper.sample(held).intent.dash_pressed);
        _ = mapper.sample(.{});
        try actions.advance(&hub, &mapper, held, mapper.sample(held), 0);
        try actions.advance(&hub, &mapper, held, .{ .destination = .springs }, 0);
        try std.testing.expect(hub.construction == .expanded and !hub.pending.dash_pressed and !mapper.sample(held).intent.dash_pressed);
        _ = mapper.sample(.{});
        hub.clock.setPaused(true);
        var both = mapper.sample(held);
        both.intent.jump_pressed = true;
        both.intent.jump_held = true;
        try actions.advance(&hub, &mapper, held, both, 1);
        const before = try hub.traversalFingerprint();
        const count = hub.tick;
        var still_held = mapper.sample(held);
        still_held.intent.jump_held = true;
        try actions.advance(&hub, &mapper, held, still_held, 1);
        try std.testing.expect(before.eql(try hub.traversalFingerprint()) and hub.tick == count);
        try actions.advance(&hub, &mapper, held, .{ .step = true, .intent = .{ .move_axis = 0, .jump_pressed = false, .jump_held = true, .jump_released = false, .interact_pressed = false } }, 1);
        try std.testing.expect(hub.tick == count + 1 and hub.last_physical.jump_accepted and hub.last_physical.dash_started);
        try actions.advance(&hub, &mapper, held, .{ .reset = true, .step = true, .pause = true, .activate = true, .destination = .hierarchy }, 1);
        try std.testing.expect(hub.tick == 0 and hub.construction == .expanded and !hub.pending.dash_pressed and !mapper.sample(held).intent.dash_pressed);
    }
    mapper = .{};
    const jump = mapper.sample(.{ .gamepad_button_south = true });
    try std.testing.expect(jump.intent.jump_pressed and !jump.intent.dash_pressed and !jump.activate);
    mapper = .{};
    const shot = mapper.sample(.{ .gamepad_button_west = true });
    try std.testing.expect(shot.activate and !shot.intent.jump_pressed and !shot.intent.dash_pressed);
}

fn runSegments(hub: *h.Hub, scenario: @import("engine_lab_verification").traversal.Scenario) !void {
    const routes = @import("engine_lab_verification").traversal;
    var air: usize = 0;
    var dash: usize = 0;
    for (routes.segments(scenario)) |segment| {
        var apex = hub.actor.worldPosition().y;
        for (0..segment.ticks) |elapsed| {
            try hub.advanceFrame(1.0 / 240.0, routes.input(hub, segment, elapsed));
            const state = hub.actor.controllerSnapshot().?.state;
            air += @intFromBool(hub.last_physical.jump_source == .air);
            dash += @intFromBool(hub.last_physical.dash_started);
            apex = @max(apex, state.position.y);
            const c = hub.actor.controllerSnapshot().?;
            try std.testing.expect(!try hub.world.containsPenetrationBeyond(try collision.characterBounds(state.position, c.configuration.collider_half_extents), c.configuration.ground_epsilon));
            const half = try hub.camera.worldHalfExtents();
            // The full collider and LAG label stay inside drawable bounds. These
            // margins are in metres; 1e-4 covers collision/camera f32 rounding.
            try std.testing.expect(state.position.y - 1.05 >= hub.camera.center.y - half.y - 1e-4);
            try std.testing.expect(state.position.y + 3.65 <= hub.camera.center.y + half.y + 1e-4);
            try std.testing.expect(@abs(state.position.x - hub.camera.center.x) + 0.5 <= half.x + 1e-4);
            // Additional vertical proof for every supported arrival, including
            // the dash contact segment. The earlier horizontal check is retained.
            if (segment.support != null and segment.ticks - elapsed <= 16) {
                for (h.layout.expanded_colliders) |box| if (box.id == segment.support.?) {
                    try std.testing.expect(box.bounds.maximum.y >= hub.camera.center.y - half.y and box.bounds.maximum.y <= hub.camera.center.y + half.y);
                };
            }
            if (segment.support != null and segment.jump and segment.ticks - elapsed <= 40) {
                for (h.layout.expanded_colliders) |box| if (box.id == segment.support.?) {
                    try std.testing.expect(box.bounds.maximum.x >= hub.camera.center.x - half.x and box.bounds.minimum.x <= hub.camera.center.x + half.x);
                };
            }
        }
        try routes.validateBoundary(hub, segment);
        const state = hub.actor.controllerSnapshot().?.state;
        if (segment.capture) std.debug.print("TRAVERSAL_MEASURE scenario={s} point={s} tick={d} x={d:.6} y={d:.6} segment_apex={d:.6} support={any} camera={any}\n", .{ @tagName(scenario), segment.name, hub.tick, state.position.x, state.position.y, apex, state.supporting_collider, hub.camera.center });
        if (scenario == .easy and std.mem.eql(u8, segment.name, "upper-hud")) try std.testing.expect(air == 0 and dash == 0);
    }
    try std.testing.expectEqual(@as(usize, if (scenario == .shortcut) 1 else 0), air);
    try std.testing.expectEqual(@as(usize, if (scenario == .easy) 1 else 0), dash);
}

test "traversal routes show full actor LAG and approaching supports at both drawable aspect ratios" {
    for ([_][2]u32{ .{ 640, 480 }, .{ 1280, 720 }, .{ 960, 720 } }) |viewport| {
        for ([_]@import("engine_lab_verification").traversal.Scenario{ .easy, .shortcut }) |scenario| {
            var hub = try init(std.testing.allocator);
            defer close(&hub);
            try hub.setViewport(viewport[0], viewport[1]);
            try runSegments(&hub, scenario);
        }
    }
}

test "traversal gap fails without dash and gravity return reaches both original installations" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    const routes = @import("engine_lab_verification").traversal;
    for (routes.easy[0..11]) |segment| {
        for (0..segment.ticks) |i| try hub.advanceFrame(1.0 / 240.0, routes.input(&hub, segment, i));
        try routes.validateBoundary(&hub, segment);
    }
    for (0..179) |i| try tick(&hub, -1, i == 0, false);
    try std.testing.expect(hub.actor.controllerSnapshot().?.state.supporting_collider != 13);
    try std.testing.expect(hub.actor.worldPosition().y < 5.85);
    // Ordinary descent, then walk beneath the high ledges and jump over the
    // first low ledge and the preserved central obstacle. No navigation/warps.
    for (0..250) |_| try tick(&hub, 0, false, false);
    try std.testing.expectEqual(@as(u16, 1), hub.actor.controllerSnapshot().?.state.supporting_collider.?);
    try runTo(&hub, -10.1, 1);
    for (0..260) |i| try tick(&hub, 1, i == 0, false);
    try moveTo(&hub, -4.5);
    try std.testing.expect(hub.visited[0]);
    try runTo(&hub, -2.6, 1);
    for (0..200) |i| try tick(&hub, 1, i == 0, false);
    try moveTo(&hub, 5.0);
    try std.testing.expect(hub.visited[1] and hub.actor.controllerSnapshot().?.state.grounded);
    hub.impact.pending_activation = true;
    try tick(&hub, 0, false, false);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.launches);
}

test "traversal camera snaps dead zones clamps resize and ceiling contact use supported paths" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    const initial = hub.camera;
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), initial.center.y, 1e-5);
    try hub.actor.stageControlledTransform(.{ .x = -4.2, .y = 1.1 }, .right);
    try hub.updateCamera();
    try std.testing.expectEqualDeep(initial.center, hub.camera.center);
    try hub.actor.stageControlledTransform(.{ .x = -23.7, .y = 12.8 }, .left);
    try hub.updateCamera();
    const half = try hub.camera.worldHalfExtents();
    try std.testing.expectApproxEqAbs(-24 + half.x, hub.camera.center.x, 1e-5);
    try std.testing.expectApproxEqAbs(14 - half.y, hub.camera.center.y, 1e-5);
    // Explicit boundary fixture, independent of the route proofs. Tests the
    // real expanded world's roof at high speed without claiming a route here.
    try tick(&hub, 0, true, false);
    for (0..40) |_| {
        try tick(&hub, 0, false, false);
        if (hub.last_physical.ceiling_collision) break;
    }
    try std.testing.expect(hub.last_physical.ceiling_collision);
    const snapshot = hub.world_time.snapshot();
    try hub.navigate(.springs);
    try std.testing.expectEqualDeep(snapshot, hub.world_time.snapshot());
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), hub.camera.center.x, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), hub.camera.center.y, 1e-5);
    try hub.setViewport(3840, 480);
    try std.testing.expectEqual(@as(f32, -8), hub.camera.center.x);
    try std.testing.expectEqual(@as(f32, 82), hub.camera.pixels_per_meter);
    const wide = hub.camera;
    try std.testing.expectError(error.ZeroViewport, hub.setViewport(0, 0));
    try std.testing.expectEqualDeep(wide, hub.camera);
    try hub.reset();
    try std.testing.expectEqualDeep(initial, hub.camera);
}

test "traversal initialization and every failed reset preserve ownership and complete live observations" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    const count = tracking.alloc_index;
    // This constructor intentionally maps allocator errors into meaningful
    // subsystem errors; verify induced failures and cleanup rather than assume
    // the std helper's OutOfMemory-only error contract.
    for (0..count) |failure| {
        var initial = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        if (init(initial.allocator())) |value| {
            var unexpected = value;
            close(&unexpected);
            return error.ExpectedInitializationFailure;
        } else |_| try std.testing.expect(initial.has_induced_failure);
        try std.testing.expectEqual(initial.allocated_bytes, initial.freed_bytes);
    }
    try hub.navigate(.springs);
    hub.impact.pending_activation = true;
    for (0..312) |_| try tick(&hub, 0, false, false);
    hub.impact.pending_activation = true;
    try tick(&hub, -1, true, true);
    try hub.advanceFrame(0, .{ .move_axis = -1, .jump_pressed = true, .jump_held = true, .jump_released = false, .interact_pressed = false, .dash_pressed = true });
    const before = try hub.traversalFingerprint();
    const controlled = hub.actor.controllerSnapshot();
    const camera = hub.camera;
    const clock = hub.clock;
    const stations = hub.stations;
    const calibration = hub.calibration;
    const physical = hub.last_physical;
    var mapper = actions.Mapper{};
    for (0..count) |failure| {
        const live = tracking.allocated_bytes - tracking.freed_bytes;
        tracking.fail_index = tracking.alloc_index + failure;
        tracking.has_induced_failure = false;
        if (actions.advance(&hub, &mapper, .{}, .{ .reset = true, .step = true, .pause = true, .activate = true }, 1)) |_| return error.ExpectedResetFailure else |_| try std.testing.expect(tracking.has_induced_failure);
        try std.testing.expectEqual(live, tracking.allocated_bytes - tracking.freed_bytes);
        try std.testing.expect(before.eql(try hub.traversalFingerprint()));
        try std.testing.expectEqualDeep(controlled, hub.actor.controllerSnapshot());
        try std.testing.expectEqualDeep(camera, hub.camera);
        try std.testing.expectEqualDeep(clock, hub.clock);
        try std.testing.expectEqualDeep(stations, hub.stations);
        try std.testing.expectEqualDeep(calibration, hub.calibration);
        try std.testing.expectEqualDeep(physical, hub.last_physical);
        try std.testing.expect(hub.construction == .expanded);
    }
    tracking.fail_index = std.math.maxInt(usize);
    try actions.advance(&hub, &mapper, .{}, .{ .reset = true, .step = true, .pause = true, .activate = true }, 1);
    try std.testing.expect(hub.tick == 0 and hub.construction == .expanded and !hub.clock.paused);
    std.debug.print("TRAVERSAL_ALLOCATION_FAILURES_OK reset_prefixes={d} initialization=all live_state_preserved=true\n", .{count});
}

test "traversal projectile bridge ages remain ordered while movement lag and logical time coexist" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try hub.navigate(.springs);
    hub.impact.pending_activation = true;
    try tick(&hub, -1, true, true);
    const impact = h.impact_module;
    try std.testing.expect(hub.last_physical.jump_accepted and hub.last_physical.dash_started);
    try std.testing.expectEqual(impact.p.EventKind.spawned, hub.impact.observations.last_batch[0].kind);
    try std.testing.expectEqual(@as(u64, 0), hub.impact.observations.last_batch[0].tick);
    try std.testing.expectEqual(impact.p.EventKind.moved, hub.impact.observations.last_batch[1].kind);
    for (1..312) |_| try tick(&hub, 0, false, false);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.contacts);
    try std.testing.expectEqual(impact.p.EventKind.moved, hub.impact.observations.last_batch[0].kind);
    try std.testing.expectEqual(impact.p.EventKind.collided, hub.impact.observations.last_batch[1].kind);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.events().len);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.bridge.metrics.impacts);
    var particles: [impact.particle_capacity]impact.e.ParticleSnapshot = undefined;
    const born = try hub.impact.effects.copyParticles(&particles);
    try std.testing.expectEqual(@as(usize, 24), born.len);
    for (born) |particle| try std.testing.expectEqual(@as(u32, 0), particle.age_ticks);
    try tick(&hub, 0, false, false);
    for (try hub.impact.effects.copyParticles(&particles)) |particle| try std.testing.expectEqual(@as(u32, 1), particle.age_ticks);
    const time = hub.world_time.snapshot();
    try std.testing.expect(time.simulation_ticks == hub.tick and time.day_index == 1 and time.time_of_day_us == 18_250_000);
    const retained = try hub.impact.fingerprint();
    try hub.navigate(.springs);
    try std.testing.expectEqualDeep(time, hub.world_time.snapshot());
    try std.testing.expect(retained.eql(try hub.impact.fingerprint()));
    try std.testing.expectEqual(@as(u64, 0), hub.calibration.state.fixed_ticks);
    // A copied-position range fixture above the bay cannot activate it.
    try hub.actor.stageControlledTransform(.{ .x = hub.impact.launcher.x, .y = 5.85 }, .right);
    hub.impact.pending_activation = true;
    try tick(&hub, 0, false, false);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.out_of_range);
    const elapsed = hub.tick;
    try hub.advanceFrame(0, h.neutral_intent);
    try std.testing.expectEqual(elapsed, hub.tick);
    try hub.advanceFrame(100, h.neutral_intent);
    try std.testing.expectEqual(elapsed + 8, hub.tick);
    try std.testing.expectEqual(hub.tick, hub.world_time.snapshot().simulation_ticks);
}

test "traversal render interpolation observes simulation without warmed allocation or resize" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    var view = try view_module.View.init(tracking.allocator());
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(tracking.allocator(), view_module.entry_capacity, view_module.sprite_capacity, view_module.mesh_capacity, 2);
    defer queue.deinit();
    queue.markStabilized();
    const allocations = tracking.alloc_index;
    const resizes = tracking.resize_index;
    tracking.fail_index = allocations;
    tracking.resize_fail_index = resizes;
    const routes = @import("engine_lab_verification").traversal;
    for (routes.easy) |segment| {
        for (0..segment.ticks) |elapsed| {
            try hub.advanceFrame(1.0 / 240.0, routes.input(&hub, segment, elapsed));
            const before = try hub.traversalFingerprint();
            for ([_]f64{ 0, 0.25, 0.75, 0.999 }) |alpha| {
                hub.clock.last_frame.interpolation_alpha = alpha;
                try view.render(&hub, &queue);
                try std.testing.expect(before.eql(try hub.traversalFingerprint()));
                try std.testing.expectEqual(@as(usize, 3), queue.prepare().ranges.len);
            }
        }
    }
    try std.testing.expectEqual(allocations, tracking.alloc_index);
    try std.testing.expectEqual(resizes, tracking.resize_index);
    try std.testing.expect(!tracking.has_induced_failure);
}
