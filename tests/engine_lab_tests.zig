const std = @import("std");
const hub_module = @import("engine_lab");
const verification = @import("engine_lab_verification");
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const queue_module = @import("render_queue");
const collider = @import("collider");
comptime {
    _ = @import("engine_lab_zoom_tests.zig");
    _ = @import("engine_lab_traversal_tests.zig");
    _ = @import("engine_lab_traversal_budget_tests.zig");
    _ = @import("static_sweep_tests.zig");
    _ = @import("engine_lab_impact_tests.zig");
    _ = @import("engine_lab_multi_impact_tests.zig");
    _ = @import("engine_lab_calibration_tests.zig");
    _ = @import("engine_lab_world_time_tests.zig");
}

fn seed() !hub_module.Seed {
    return hub_module.Seed.parseLowerHex(hub_module.default_seed);
}
fn close(hub: *hub_module.Hub) void {
    hub.deinit() catch |err| hub_module.cleanupFailure(err);
}
fn movement(axis: f32) hub_module.Intent {
    var value = hub_module.neutral_intent;
    value.move_axis = axis;
    return value;
}

test "direct construction owns one running hub with actor and both spatial installations" {
    var hub = try hub_module.Hub.init(std.testing.allocator, try seed());
    defer close(&hub);
    try std.testing.expect(!hub.clock.paused);
    try std.testing.expectEqual(@as(u64, 0), hub.tick);
    try std.testing.expect(hub.actor.controllerSnapshot() != null);
    try std.testing.expect(hub.actor.worldPosition().approxEqAbs(hub_module.spawn, 1e-6)); // Below a display pixel and f32 metre arithmetic noise.
    try std.testing.expect(hub.installations.roots[0].world.x < hub.installations.roots[1].world.x);
    var snapshot = try hub.installations.scene.acquireSnapshot(.{ .tick = 0, .fixed_delta_seconds = 1.0 / 240.0, .interpolation_alpha = 0 });
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 8), snapshot.view().entityCount());
    for (hub.installations.anchors, 0..) |anchors, station| for (anchors, 0..) |anchor, mass| {
        try std.testing.expect(snapshot.view().resolve(anchor.id) != null);
        // 1e-6 m covers f32 parent-plus-child addition, far below a pixel.
        try std.testing.expectApproxEqAbs(hub_module.station_x[station] + (@as(f32, @floatFromInt(mass)) - 1) * 0.8, anchor.world.x, 1e-6);
        try std.testing.expectApproxEqAbs(@as(f32, 2.6), anchor.world.y, 1e-6);
    };
}

test "initial logical fingerprint repeats and the seed changes real station state" {
    var first = try hub_module.Hub.init(std.testing.allocator, try seed());
    defer close(&first);
    var second = try hub_module.Hub.init(std.testing.allocator, try seed());
    defer close(&second);
    try std.testing.expect((try first.fingerprint()).eql(try second.fingerprint()));
    var changed_seed = try seed();
    changed_seed.bytes[0] ^= 1;
    var changed = try hub_module.Hub.init(std.testing.allocator, changed_seed);
    defer close(&changed);
    try std.testing.expect(!(try first.fingerprint()).eql(try changed.fingerprint()));
}

test "actual hub schedule reaches both stations with jumps landings collision and equal checkpoints" {
    const result = try verification.verify(std.testing.allocator, try seed());
    try std.testing.expect(result.jumps >= 2 and result.landings >= 2 and result.wall_contacts > 0);
    for (result.checkpoints, verification.checkpoint_ticks, 0..) |checkpoint, tick, index| {
        try std.testing.expectEqual(tick, checkpoint.tick);
        if (index > 0) try std.testing.expect(!checkpoint.digest.eql(result.checkpoints[index - 1].digest));
    }
}

test "production horizontal controller collides with both enclosing walls and owns facing" {
    var hub = try hub_module.Hub.init(std.testing.allocator, try seed());
    defer close(&hub);
    for (0..120) |_| try hub.advanceFrame(1.0 / 60.0, movement(-1));
    var controller = hub.actor.controllerSnapshot().?;
    // 1e-4 m matches the production contact epsilon, well below a rendered pixel.
    try std.testing.expectApproxEqAbs(@as(f32, -7.7), controller.state.position.x, 1e-4);
    try std.testing.expect(controller.state.grounded and controller.state.facing == .left);
    try std.testing.expect(hub.wall_contacts > 0);
    try std.testing.expect(!(try hub.world.containsPenetrationBeyond(try collider.characterBounds(controller.state.position, controller.configuration.collider_half_extents), 1e-4)));
    try hub.navigate(.springs);
    for (0..120) |_| try hub.advanceFrame(1.0 / 60.0, movement(1));
    controller = hub.actor.controllerSnapshot().?;
    try std.testing.expectApproxEqAbs(@as(f32, 7.7), controller.state.position.x, 1e-4);
    try std.testing.expect(controller.state.facing == .right);
    try std.testing.expectApproxEqAbs(@as(f32, 5), hub.camera.center.x, 1e-6); // Exact configured camera boundary.
}

test "gravity lands the production actor on the raised platform" {
    var hub = try hub_module.Hub.init(std.testing.allocator, try seed());
    defer close(&hub);
    // Use the supported destination staging command to set up a drop, then only
    // production fixed-step gravity/contact determines the landing and animation.
    try hub.actor.stageControlledTransform(.{ .x = 0, .y = 3.6 }, .right);
    var airborne = false;
    for (0..120) |_| {
        try hub.advanceFrame(1.0 / 60.0, hub_module.neutral_intent);
        airborne = airborne or !hub.actor.controllerSnapshot().?.state.grounded;
    }
    const state = hub.actor.controllerSnapshot().?.state;
    try std.testing.expect(airborne and hub.landings > 0);
    try std.testing.expectEqual(@as(?u16, 4), state.supporting_collider);
    try std.testing.expectApproxEqAbs(@as(f32, 1.65), state.position.y, 1e-4); // Platform 0.6 m + collider half-height 1.05 m, production contact epsilon.
    try std.testing.expect(hub.actor.animationState() == .idle);
}

test "both stations keep evolving when the actor moves away" {
    var hub = try hub_module.Hub.init(std.testing.allocator, try seed());
    defer close(&hub);
    const initial = hub.stations;
    for (0..120) |_| try hub.advanceFrame(1.0 / 60.0, movement(-1));
    for (hub.stations, initial) |station, before| {
        try std.testing.expectEqual(hub.tick, station.updates);
        try std.testing.expect(station.history_count > 0);
        try std.testing.expect(station.springs[0].offset != before.springs[0].offset);
    }
}

test "developer navigation preserves station state resources and the fixed clock" {
    var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try hub_module.Hub.init(allocator.allocator(), try seed());
    defer close(&hub);
    for (0..30) |_| try hub.advanceFrame(1.0 / 60.0, movement(1));
    const stations = hub.stations;
    const tick = hub.tick;
    const clock = hub.clock;
    const actor_id = hub.actor.id();
    const collision_storage = hub.world.colliders.ptr;
    const attachments = hub.definition.attachments.ptr;
    allocator.fail_index = allocator.alloc_index;
    allocator.resize_fail_index = allocator.resize_index;
    try hub.navigate(.springs);
    try std.testing.expect(std.meta.eql(stations, hub.stations));
    try std.testing.expect(std.meta.eql(clock, hub.clock));
    try std.testing.expectEqual(tick, hub.tick);
    try std.testing.expectEqual(actor_id, hub.actor.id());
    try std.testing.expect(collision_storage == hub.world.colliders.ptr and attachments == hub.definition.attachments.ptr);
    try std.testing.expect(!allocator.has_induced_failure);
    try std.testing.expectApproxEqAbs(hub_module.destination_x[1], hub.actor.worldPosition().x, 1e-6); // Exact destination constant.
    try std.testing.expect(hub.visited[0] and hub.visited[1]);
    try hub.navigate(.hierarchy);
    try std.testing.expect(std.meta.eql(stations, hub.stations));
}

test "whole hub reset restores actor camera stations clock seed and transients" {
    var hub = try hub_module.Hub.init(std.testing.allocator, try seed());
    defer close(&hub);
    const initial = try hub.fingerprint();
    const camera = hub.camera;
    for (0..30) |_| try hub.advanceFrame(1.0 / 60.0, movement(1));
    try hub.navigate(.springs);
    hub.clock.setPaused(true);
    hub.clock.requestSingleStep();
    hub.pending.jump_pressed = true;
    hub.diagnostics_enabled = true;
    try hub.reset();
    try std.testing.expect((try hub.fingerprint()).eql(initial));
    try std.testing.expect(std.meta.eql(camera, hub.camera));
    try std.testing.expect(std.meta.eql(hub_module.neutral_intent, hub.pending));
    try std.testing.expect(!hub.clock.paused and !hub.clock.single_step_pending);
    try std.testing.expectEqual(@as(f64, 0), hub.clock.accumulator);
    try std.testing.expectEqual(@as(u32, 0), hub.navigation_count);
    try std.testing.expect(!hub.diagnostics_enabled);
    for (hub.stations) |station| try std.testing.expectEqual(@as(usize, 0), station.history_count);
}

test "pause and single step consume one pending jump edge without replay" {
    var hub = try hub_module.Hub.init(std.testing.allocator, try seed());
    defer close(&hub);
    hub.clock.setPaused(true);
    var jump = hub_module.neutral_intent;
    jump.jump_pressed = true;
    jump.jump_held = true;
    try hub.advanceFrame(0.05, jump);
    try std.testing.expectEqual(@as(u64, 0), hub.tick);
    hub.clock.requestSingleStep();
    try hub.advanceFrame(0.05, hub_module.neutral_intent);
    try std.testing.expectEqual(@as(u64, 1), hub.tick);
    try std.testing.expectEqual(@as(u32, 1), hub.jumps);
    hub.clock.requestSingleStep();
    try hub.advanceFrame(0.05, hub_module.neutral_intent);
    try std.testing.expectEqual(@as(u64, 2), hub.tick);
    try std.testing.expectEqual(@as(u32, 1), hub.jumps);
    try std.testing.expect(!hub.pending.jump_pressed);
}

test "render extraction camera diagnostics and interpolation do not change logical state" {
    var hub = try hub_module.Hub.init(std.testing.allocator, try seed());
    defer close(&hub);
    var view = try view_module.View.init(std.testing.allocator);
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(std.testing.allocator, 2048, 1792, 256, 2);
    defer queue.deinit();
    try hub.advanceFrame(1.0 / 60.0, movement(1));
    const before = try hub.fingerprint();
    _ = try hub.renderedActorPosition();
    try view.render(&hub, &queue);
    const prepared = queue.prepare();
    try std.testing.expectEqual(@as(usize, 3), prepared.ranges.len);
    try std.testing.expectEqual(@as(usize, 15), view.actor_queue.prepare().sprites.len);
    hub.diagnostics_enabled = true;
    try hub.camera.setCenter(.{ .x = 0, .y = 2.1 });
    try view.render(&hub, &queue);
    try std.testing.expect((try hub.fingerprint()).eql(before));
}

test "steady hub simulation render and navigation allocate nothing after warmup" {
    var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try hub_module.Hub.init(allocator.allocator(), try seed());
    defer close(&hub);
    var view = try view_module.View.init(allocator.allocator());
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(allocator.allocator(), 2048, 1792, 256, 2);
    defer queue.deinit();
    queue.markStabilized();
    allocator.fail_index = allocator.alloc_index;
    allocator.resize_fail_index = allocator.resize_index;
    hub.diagnostics_enabled = true;
    for (0..360) |frame| {
        try hub.advanceFrame(1.0 / 60.0, verification.inputAt(hub.tick));
        try view.render(&hub, &queue);
        try std.testing.expect(queue.prepare().sprites.len <= 1792);
        if (frame == 180) try hub.navigate(.springs);
    }
    try std.testing.expect(!allocator.has_induced_failure);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}

test "failed whole hub reconstruction leaves the current world live" {
    var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try hub_module.Hub.init(allocator.allocator(), try seed());
    defer close(&hub);
    try hub.advanceFrame(1.0 / 60.0, movement(1));
    const before = try hub.fingerprint();
    allocator.fail_index = allocator.alloc_index;
    if (hub.reset()) |_| {
        return error.ExpectedAllocationFailure;
    } else |_| {
        try std.testing.expect(allocator.has_induced_failure);
    }
    try std.testing.expect(allocator.has_induced_failure);
    try std.testing.expect((try hub.fingerprint()).eql(before));
}

test "every partial hub construction allocation failure releases acquired resources" {
    var index: usize = 0;
    while (index < 2000) : (index += 1) {
        var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = index });
        var hub = hub_module.Hub.init(allocator.allocator(), try seed()) catch {
            try std.testing.expect(allocator.has_induced_failure);
            try std.testing.expectEqual(allocator.allocated_bytes, allocator.freed_bytes);
            continue;
        };
        try hub.deinit();
        try std.testing.expectEqual(allocator.allocated_bytes, allocator.freed_bytes);
        return;
    }
    return error.AllocationBoundaryProofDidNotComplete;
}

test "reset suppression and focus loss clear keyboard gamepad and action history" {
    var mapper = actions.Mapper{};
    const held: @import("physical_input").RawInputState = .{ .keyboard = .{ .d = true, .space = true, .p = true }, .gamepad_left_x = @as(f32, 1), .gamepad_button_south = true };
    const first = mapper.sample(held);
    try std.testing.expect(first.intent.move_axis == 1 and first.intent.jump_pressed and first.pause);
    mapper.suppressHeld(held);
    const blocked = mapper.sample(held);
    try std.testing.expect(blocked.intent.move_axis == 0 and !blocked.intent.jump_pressed and !blocked.pause);
    _ = mapper.sample(.{});
    try std.testing.expect(mapper.sample(held).intent.jump_pressed);
    _ = mapper.sample(.{ .keyboard = .{ .r = true }, .focus_lost = true });
    try std.testing.expect(!mapper.sample(.{ .keyboard = .{ .r = true } }).reset);
    try std.testing.expect(mapper.sample(.{ .keyboard_focused = false, .window_close_requested = true }).exit);
}

test "short physical taps survive a frame and navigation maps destinations" {
    var mapper = actions.Mapper{};
    mapper.capturePress(.{ .space = true });
    const jump = mapper.sample(.{}).intent;
    try std.testing.expect(jump.jump_pressed and jump.jump_released and !jump.jump_held);
    try std.testing.expect(!mapper.sample(.{}).intent.jump_pressed);
    mapper.capturePress(.{ .f2 = true });
    try std.testing.expectEqual(@as(?hub_module.Destination, .springs), mapper.sample(.{}).destination);
    mapper.capturePress(.{ .escape = true });
    try std.testing.expect(mapper.sample(.{}).exit);
}
test "production diagnostic glyphs have readable orientation and distinct digits" {
    const debug = @import("debug_draw");
    var commands = debug.CommandBuffer{};
    _ = try commands.addLabel(.{ .x = 0, .y = 0 }, "L", .{ 1, 1, 1, 1 });
    // A readable L occupies the left edge on its upper rows; a mirrored L does not.
    for (commands.commands[0..4]) |command| try std.testing.expectEqual(@as(f32, 0), command.world_position[0]);
    try std.testing.expect(commands.commands[commands.count - 1].world_position[0] > 0);
    commands.beginFrame();
    _ = try commands.addLabel(.{ .x = 0, .y = 0 }, "0", .{ 1, 1, 1, 1 });
    const zero_count = commands.count;
    commands.beginFrame();
    _ = try commands.addLabel(.{ .x = 0, .y = 0 }, "1", .{ 1, 1, 1, 1 });
    try std.testing.expect(zero_count != commands.count);
}
