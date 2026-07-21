const std = @import("std");
const input = @import("input");
const math = @import("math");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const playground = @import("playground_demo");

test "production keyboard horizontal alternatives map once and opposing controls are neutral" {
    const cases = [_]struct { keyboard: input.KeyboardState, expected: f32 }{
        .{ .keyboard = .{ .a = true }, .expected = -1 },
        .{ .keyboard = .{ .left_arrow = true }, .expected = -1 },
        .{ .keyboard = .{ .d = true }, .expected = 1 },
        .{ .keyboard = .{ .right_arrow = true }, .expected = 1 },
        .{ .keyboard = .{ .a = true, .left_arrow = true }, .expected = -1 },
        .{ .keyboard = .{ .d = true, .right_arrow = true }, .expected = 1 },
        .{ .keyboard = .{ .a = true, .d = true }, .expected = 0 },
        .{ .keyboard = .{ .left_arrow = true, .right_arrow = true }, .expected = 0 },
        .{ .keyboard = .{ .a = true, .right_arrow = true }, .expected = 0 },
        .{ .keyboard = .{}, .expected = 0 },
    };
    for (cases) |case| {
        var builder = input.SnapshotBuilder{};
        const snapshot = try builder.update(.{ .keyboard = case.keyboard });
        try std.testing.expectEqual(case.expected, snapshot.move_axis);
    }

    var merge_builder = input.SnapshotBuilder{};
    try std.testing.expectEqual(@as(f32, -1), (try merge_builder.update(.{
        .keyboard = .{ .a = true },
        .gamepad_move_axis = 1,
    })).move_axis);
    merge_builder.reset();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), (try merge_builder.update(.{
        .gamepad_move_axis = 0.6,
    })).move_axis, 0.000001);
}

test "production action mappings emit physical transition edges without repeat or source duplication" {
    var builder = input.SnapshotBuilder{};
    var snapshot = try builder.update(.{ .keyboard = .{
        .space = true,
        .e = true,
        .r = true,
        .f1 = true,
        .escape = true,
    } });
    try std.testing.expect(snapshot.jump.pressed and snapshot.jump.held and !snapshot.jump.released);
    try std.testing.expect(snapshot.interact.pressed and snapshot.reset.pressed and snapshot.debug_toggle.pressed and snapshot.exit.pressed);

    snapshot = try builder.update(.{ .keyboard = .{
        .space = true,
        .e = true,
        .r = true,
        .f1 = true,
        .escape = true,
    } });
    try std.testing.expect(!snapshot.jump.pressed and !snapshot.interact.pressed and !snapshot.reset.pressed and
        !snapshot.debug_toggle.pressed and !snapshot.exit.pressed);

    snapshot = try builder.update(.{});
    try std.testing.expect(snapshot.jump.released and snapshot.interact.released and snapshot.exit.released);
    try std.testing.expect(!snapshot.jump.pressed and !snapshot.reset.pressed and !snapshot.debug_toggle.pressed);

    builder.reset();
    snapshot = try builder.update(.{ .keyboard = .{ .space = true, .e = true }, .gamepad_jump = true, .gamepad_interact = true });
    try std.testing.expect(snapshot.jump.pressed and snapshot.interact.pressed);
    snapshot = try builder.update(.{ .gamepad_jump = true, .gamepad_interact = true });
    try std.testing.expect(!snapshot.jump.pressed and !snapshot.jump.released and !snapshot.interact.pressed and !snapshot.interact.released);
    snapshot = try builder.update(.{});
    try std.testing.expect(snapshot.jump.released and snapshot.interact.released);

    builder.reset();
    try std.testing.expect((try builder.update(.{ .window_close_requested = true })).exit.pressed);
    try std.testing.expect(!(try builder.update(.{})).exit.pressed);
}

test "focus loss clears keyboard holds pending presses and suppresses phantom regain edges" {
    var builder = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    const held = input.KeyboardState{ .a = true, .space = true, .e = true, .r = true, .f1 = true };
    try pending.acceptFrame(try builder.update(.{ .keyboard = held }));
    try std.testing.expectEqual(@as(u8, 2), pending.pendingEdgeCount());

    var snapshot = try builder.update(.{ .keyboard = held, .keyboard_focused = false, .focus_lost = true });
    try std.testing.expect(snapshot.focus_lost and !snapshot.keyboard_left_held and snapshot.move_axis == 0);
    try std.testing.expect(snapshot.jump.released and !snapshot.jump.held and !snapshot.interact.pressed);
    try std.testing.expect(!snapshot.reset.pressed and !snapshot.debug_toggle.pressed);
    try pending.acceptFrame(snapshot);
    try std.testing.expectEqual(@as(u8, 1), pending.pendingEdgeCount());
    const release = pending.consumeTick();
    try std.testing.expect(!release.jump_pressed and release.jump_released and !release.jump_held and !release.interact_pressed);

    snapshot = try builder.update(.{ .keyboard = held, .keyboard_focused = true });
    try std.testing.expect(!snapshot.keyboard_left_held and !snapshot.jump.pressed and !snapshot.jump.held and
        !snapshot.interact.pressed and !snapshot.reset.pressed and !snapshot.debug_toggle.pressed);
    _ = try builder.update(.{});
    snapshot = try builder.update(.{ .keyboard = held });
    try std.testing.expect(snapshot.keyboard_left_held and snapshot.jump.pressed and snapshot.interact.pressed and
        snapshot.reset.pressed and snapshot.debug_toggle.pressed);
}

test "pending edges survive zero substeps coalesce press release and consume once across eight ticks" {
    var builder = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .d = true, .space = true, .e = true } }));
    for (0..19) |_| try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .d = true, .space = true, .e = true } }));
    try std.testing.expectEqual(@as(u8, 2), pending.pendingEdgeCount());

    try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .d = true } }));
    try std.testing.expectEqual(@as(u8, 3), pending.pendingEdgeCount());
    const first = pending.consumeTick();
    try std.testing.expectEqual(@as(f32, 1), first.move_axis);
    try std.testing.expect(first.jump_pressed and first.jump_released and !first.jump_held and first.interact_pressed);
    for (0..7) |_| {
        const later = pending.consumeTick();
        try std.testing.expectEqual(@as(f32, 1), later.move_axis);
        try std.testing.expect(!later.jump_pressed and !later.jump_released and !later.interact_pressed);
    }

    var action_builder = input.SnapshotBuilder{};
    const actions = try action_builder.update(.{ .keyboard = .{ .r = true, .f1 = true } });
    try std.testing.expect(actions.reset.pressed and actions.debug_toggle.pressed);
    const held_actions = try action_builder.update(.{ .keyboard = .{ .r = true, .f1 = true } });
    try std.testing.expect(!held_actions.reset.pressed and !held_actions.debug_toggle.pressed);
}

test "mapped keyboard input drives real controller movement deceleration opposition and facing" {
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();

    var controller = try character_controller.CharacterController.init(.{}, &world, playground.player_spawn, .right);
    var builder = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .a = true } }));
    for (0..60) |_| _ = try controller.step(&world, pending.consumeTick());
    try std.testing.expect(controller.state.position.x < playground.player_spawn.x - 0.1);
    try std.testing.expect(controller.state.velocity.x < 0 and controller.state.facing == .left);

    const speed_before_release = @abs(controller.state.velocity.x);
    try pending.acceptFrame(try builder.update(.{}));
    for (0..12) |_| _ = try controller.step(&world, pending.consumeTick());
    try std.testing.expect(@abs(controller.state.velocity.x) < speed_before_release);

    try controller.reset(&world);
    builder.reset();
    pending.reset();
    try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .right_arrow = true } }));
    for (0..60) |_| _ = try controller.step(&world, pending.consumeTick());
    try std.testing.expect(controller.state.position.x > playground.player_spawn.x + 0.1);
    try std.testing.expect(controller.state.facing == .right);

    try controller.reset(&world);
    builder.reset();
    pending.reset();
    try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .left_arrow = true, .d = true } }));
    for (0..60) |_| _ = try controller.step(&world, pending.consumeTick());
    try std.testing.expectApproxEqAbs(playground.player_spawn.x, controller.state.position.x, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), controller.state.velocity.x, 0.000001);
}

test "Space early release produces lower real-controller apex than held Space" {
    const short = try jumpApex(3);
    const held = try jumpApex(80);
    try std.testing.expect(short > playground.player_spawn.y + 0.1);
    try std.testing.expect(held > short + 0.5);
}

test "raw keyboard mapping produces identical controller state under render grouping schedules" {
    const one = try mappedGroupingState(1);
    const four = try mappedGroupingState(4);
    try std.testing.expect(one.position.approxEqAbs(four.position, 0.000001));
    try std.testing.expect(one.velocity.approxEqAbs(four.velocity, 0.000001));
    try std.testing.expectEqual(one.grounded, four.grounded);
    try std.testing.expectEqual(one.facing, four.facing);
    try std.testing.expectEqual(one.simulation_tick, four.simulation_tick);
}

test "playground interaction hold requires a release and new E press and reset clears world ownership" {
    var scene = try playground.Scene.init(std.testing.allocator, false);
    defer scene.deinit();
    var builder = input.SnapshotBuilder{};

    var frame: u32 = 0;
    while (!scene.interactionEligibility().isEligible() and frame < 600) : (frame += 1) {
        const state = scene.player.controller.?.state;
        const target = playground.handshake_player_x - 0.01;
        const command = std.math.clamp((target - state.position.x) * 0.5 - state.velocity.x * 0.8, 0, 0.15);
        try scene.updateFrame(1.0 / 60.0, try builder.update(.{ .gamepad_move_axis = encodeGamepadAxis(command) }));
    }
    try std.testing.expect(scene.interactionEligibility().isEligible());

    try scene.updateFrame(1.0 / 60.0, try builder.update(.{ .keyboard = .{ .e = true } }));
    while (scene.evidence.completion_events == 0 and frame < 1000) : (frame += 1) {
        try scene.updateFrame(1.0 / 60.0, try builder.update(.{ .keyboard = .{ .e = true } }));
    }
    try std.testing.expectEqual(@as(u32, 1), scene.evidence.successful_interactions);
    for (0..60) |_| try scene.updateFrame(1.0 / 60.0, try builder.update(.{ .keyboard = .{ .e = true } }));
    try std.testing.expectEqual(@as(u32, 1), scene.evidence.interaction_requests);
    try std.testing.expectEqual(@as(u32, 0), scene.evidence.held_interaction_restarts);

    try scene.updateFrame(1.0 / 60.0, try builder.update(.{}));
    try scene.updateFrame(1.0 / 60.0, try builder.update(.{ .keyboard = .{ .e = true } }));
    try std.testing.expectEqual(@as(u32, 2), scene.evidence.successful_interactions);
    try std.testing.expectEqual(@as(usize, 1), scene.manager.activeCount());

    try scene.updateFrame(1.0 / 60.0, try builder.update(.{ .keyboard = .{ .r = true } }));
    const reset = scene.authoritativeState();
    try std.testing.expect(reset.player_position.approxEqAbs(playground.player_spawn, 0.000001));
    try std.testing.expect(reset.player_velocity.approxEqAbs(math.Vec2.zero, 0.000001));
    try std.testing.expect(reset.player_grounded and reset.player_facing == .right);
    try std.testing.expectEqual(@as(usize, 0), reset.active_interactions);
    try std.testing.expectEqual(@as(usize, 0), reset.participant_locks);
    try std.testing.expectEqual(@as(usize, 0), reset.active_overrides);
    try std.testing.expectEqual(@as(usize, 0), reset.active_arm_constraints);
    try std.testing.expect(reset.left_locked_target == null and reset.right_locked_target == null);
    try std.testing.expectEqual(@as(u8, 0), scene.pending_input.pendingEdgeCount());
}

test "F1 toggles leave authoritative playground simulation identical" {
    var plain = try playground.Scene.init(std.testing.allocator, false);
    defer plain.deinit();
    var toggled = try playground.Scene.init(std.testing.allocator, false);
    defer toggled.deinit();
    var plain_builder = input.SnapshotBuilder{};
    var toggled_builder = input.SnapshotBuilder{};

    for (0..360) |frame| {
        var raw = input.RawInputState{};
        if (frame >= 20 and frame < 100) raw.keyboard.d = true;
        if (frame >= 120 and frame < 124) raw.keyboard.space = true;
        var debug_raw = raw;
        if (frame == 40 or frame == 80 or frame == 160 or frame == 200) debug_raw.keyboard.f1 = true;
        try plain.updateFrame(1.0 / 60.0, try plain_builder.update(raw));
        try toggled.updateFrame(1.0 / 60.0, try toggled_builder.update(debug_raw));
    }
    try std.testing.expect(playground.authoritativeStatesEqual(plain.authoritativeState(), toggled.authoritativeState(), 0.000001));
    try std.testing.expectEqual(@as(u32, 4), toggled.evidence.debug_toggle_count);
}

test "bounded playground script uses raw mapping and completes every production milestone" {
    var scene = try playground.Scene.init(std.testing.allocator, false);
    defer scene.deinit();
    var builder = input.SnapshotBuilder{};
    var script = playground.ScriptedInput{};
    for (0..playground.required_frames) |_| {
        const raw = script.nextRaw(&scene);
        const snapshot = try builder.update(raw);
        try scene.updateFrame(1.0 / 60.0, snapshot);
        try script.observe(&scene);
    }
    try script.validate(&scene);
    try std.testing.expectEqual(@as(u8, 4), scene.evidence.maximum_substeps);
}

fn jumpApex(hold_ticks: u32) !f32 {
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, playground.player_spawn, .right);
    var builder = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    var apex = controller.state.position.y;
    var tick: u32 = 0;
    var was_airborne = false;
    while (tick < 600) : (tick += 1) {
        try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .space = tick < hold_ticks } }));
        _ = try controller.step(&world, pending.consumeTick());
        apex = @max(apex, controller.state.position.y);
        was_airborne = was_airborne or !controller.state.grounded;
        if (was_airborne and controller.state.grounded) break;
    }
    return apex;
}

fn mappedGroupingState(ticks_per_frame: u8) !character_controller.State {
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, playground.player_spawn, .right);
    var builder = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    var simulated: u32 = 0;
    while (simulated < 240) {
        var raw = input.RawInputState{};
        if (simulated < 80) raw.keyboard.d = true;
        if (simulated >= 40 and simulated < 60) raw.keyboard.space = true;
        if (simulated >= 120 and simulated < 180) raw.keyboard.a = true;
        try pending.acceptFrame(try builder.update(raw));
        for (0..ticks_per_frame) |_| {
            _ = try controller.step(&world, pending.consumeTick());
            simulated += 1;
        }
    }
    return controller.state;
}

fn encodeGamepadAxis(desired_axis: f32) f32 {
    if (@abs(desired_axis) <= std.math.floatEps(f32)) return 0;
    return std.math.sign(desired_axis) * (input.gamepad_dead_zone + @abs(desired_axis) * (1 - input.gamepad_dead_zone));
}
