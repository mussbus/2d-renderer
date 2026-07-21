const std = @import("std");
const math = @import("math");
const input = @import("input");
const fault_injection = @import("fault_injection");
const fixed_step = @import("fixed_step");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const controller_demo = @import("controller_demo");
const humanoid = @import("humanoid");
const animation_system = @import("animation_system");
const state_machine = @import("state_machine");

const tolerance: f32 = 1e-4;

fn emptyIntent() input.CharacterIntent {
    return .{
        .move_axis = 0,
        .jump_pressed = false,
        .jump_held = false,
        .jump_released = false,
        .interact_pressed = false,
    };
}

fn moveIntent(axis: f32) input.CharacterIntent {
    var value = emptyIntent();
    value.move_axis = axis;
    return value;
}

fn oneFloor(allocator: std.mem.Allocator) !collision_world.CollisionWorld {
    const inputs = [_]collider.StaticColliderInput{.{
        .id = 1,
        .bounds = .{ .minimum = .{ .x = -20, .y = -1 }, .maximum = .{ .x = 20, .y = 0 } },
    }};
    return collision_world.CollisionWorld.init(allocator, &inputs, null);
}

fn onePlatform(allocator: std.mem.Allocator) !collision_world.CollisionWorld {
    const inputs = [_]collider.StaticColliderInput{.{
        .id = 7,
        .bounds = .{ .minimum = .{ .x = -1, .y = -0.25 }, .maximum = .{ .x = 1, .y = 0 } },
    }};
    return collision_world.CollisionWorld.init(allocator, &inputs, null);
}

test "fixed update rate is exactly 240 Hz" {
    try std.testing.expectEqual(@as(u32, 240), fixed_step.simulation_hz);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0 / 240.0), fixed_step.fixed_dt_seconds, 1e-15);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 240.0), (character_controller.Configuration{}).fixed_dt, 1e-8);
}

test "input snapshots merge keyboard and gamepad and expose deterministic edges" {
    var builder = input.SnapshotBuilder{};
    var snapshot = try builder.update(.{ .keyboard = .{ .a = true } });
    try std.testing.expectEqual(@as(f32, -1), snapshot.move_axis);
    snapshot = try builder.update(.{ .keyboard = .{ .a = true, .d = true }, .gamepad_move_axis = 0.60 });
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), snapshot.move_axis, tolerance);
    snapshot = try builder.update(.{ .keyboard = .{ .d = true }, .gamepad_move_axis = -1 });
    try std.testing.expectEqual(@as(f32, 1), snapshot.move_axis);
    snapshot = try builder.update(.{ .gamepad_move_axis = input.gamepad_dead_zone });
    try std.testing.expectEqual(@as(f32, 0), snapshot.move_axis);

    snapshot = try builder.update(.{ .keyboard = .{ .space = true, .e = true } });
    try std.testing.expect(snapshot.jump.pressed and snapshot.jump.held and !snapshot.jump.released);
    try std.testing.expect(snapshot.interact.pressed);
    snapshot = try builder.update(.{ .keyboard = .{ .space = true } });
    try std.testing.expect(!snapshot.jump.pressed and snapshot.jump.held and !snapshot.jump.released);
    try std.testing.expect(snapshot.interact.released);
    snapshot = try builder.update(.{});
    try std.testing.expect(!snapshot.jump.pressed and !snapshot.jump.held and snapshot.jump.released);
    try std.testing.expectError(error.NonFiniteGamepadAxis, builder.update(.{ .gamepad_move_axis = std.math.nan(f32) }));
}

test "pending input preserves zero-tick edges and consumes each edge once" {
    var builder = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .space = true, .e = true } }));
    try pending.acceptFrame(try builder.update(.{}));
    const first = pending.consumeTick();
    try std.testing.expect(first.jump_pressed and first.jump_released and first.interact_pressed);
    try std.testing.expect(!first.jump_held);
    const second = pending.consumeTick();
    try std.testing.expect(!second.jump_pressed and !second.jump_released and !second.interact_pressed);

    try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .space = true, .d = true } }));
    const rapid = pending.consumeTick();
    try std.testing.expect(rapid.jump_pressed and rapid.jump_held);
    try std.testing.expectEqual(@as(f32, 1), rapid.move_axis);
    const held = pending.consumeTick();
    try std.testing.expect(!held.jump_pressed and held.jump_held);
    pending.reset();
    try std.testing.expectEqual(emptyIntent(), pending.consumeTick());

    var independent_a = input.SnapshotBuilder{};
    var independent_b = input.SnapshotBuilder{};
    try std.testing.expect((try independent_a.update(.{ .keyboard = .{ .space = true } })).jump.pressed);
    try std.testing.expect((try independent_b.update(.{ .keyboard = .{ .space = true } })).jump.pressed);
    try std.testing.expect(!(try independent_a.update(.{ .keyboard = .{ .space = true } })).jump.pressed);
    try std.testing.expect((try independent_b.update(.{})).jump.released);

    var delayed_builder = input.SnapshotBuilder{};
    var delayed = input.PendingInput{};
    try delayed.acceptFrame(try delayed_builder.update(.{ .keyboard = .{ .space = true, .e = true } }));
    for (0..19) |_| try delayed.acceptFrame(try delayed_builder.update(.{ .keyboard = .{ .space = true, .e = true } }));
    const delayed_first = delayed.consumeTick();
    try std.testing.expect(delayed_first.jump_pressed and delayed_first.jump_held and delayed_first.interact_pressed);
    for (0..7) |_| {
        const substep = delayed.consumeTick();
        try std.testing.expect(!substep.jump_pressed and substep.jump_held and !substep.interact_pressed);
    }
    delayed.reset();
    delayed_builder.reset();
    try delayed.acceptFrame(try delayed_builder.update(.{ .keyboard = .{ .space = true, .e = true } }));
    try delayed.acceptFrame(try delayed_builder.update(.{}));
    delayed.reset();
    try std.testing.expectEqual(emptyIntent(), delayed.consumeTick());
}

test "fixed-step clock covers zero one multiple clamped discarded paused and reset frames" {
    var clock = try fixed_step.Clock.init(.{});
    var metrics = try clock.beginFrame(0);
    try std.testing.expectEqual(@as(u8, 0), metrics.substeps);
    metrics = try clock.beginFrame(fixed_step.fixed_dt_seconds);
    try std.testing.expectEqual(@as(u8, 1), metrics.substeps);
    metrics = try clock.beginFrame(4 * fixed_step.fixed_dt_seconds);
    try std.testing.expectEqual(@as(u8, 4), metrics.substeps);
    metrics = try clock.beginFrame(-1);
    try std.testing.expectEqual(@as(f64, 0), metrics.clamped_frame_delta);
    try std.testing.expectError(error.NonFiniteFrameDelta, clock.beginFrame(std.math.inf(f64)));

    metrics = try clock.beginFrame(1);
    try std.testing.expectEqual(fixed_step.default_maximum_frame_delta, metrics.clamped_frame_delta);
    try std.testing.expectEqual(fixed_step.default_maximum_substeps, metrics.substeps);
    try std.testing.expect(metrics.discarded_time > 0);
    try std.testing.expect(metrics.accumulator >= 0 and metrics.accumulator < fixed_step.fixed_dt_seconds);
    try std.testing.expect(metrics.interpolation_alpha >= 0 and metrics.interpolation_alpha < 1);

    clock.setPaused(true);
    metrics = try clock.beginFrame(0.05);
    try std.testing.expectEqual(@as(u8, 0), metrics.substeps);
    clock.requestSingleStep();
    metrics = try clock.beginFrame(0.05);
    try std.testing.expectEqual(@as(u8, 1), metrics.substeps);
    try std.testing.expectEqual(@as(f64, 0), metrics.clamped_frame_delta);
    metrics = try clock.beginFrame(0.05);
    try std.testing.expectEqual(@as(u8, 0), metrics.substeps);
    clock.reset();
    try std.testing.expect(!clock.paused);
    try std.testing.expectEqual(@as(f64, 0), clock.accumulator);
    try std.testing.expectEqual(@as(f64, 0), clock.lifetime_discarded_time);
}

test "fixed-step low frame rate and discarded-time schedules account real and simulated time" {
    var clock = try fixed_step.Clock.init(.{});
    var requested: f64 = 0;
    var executed_ticks: u64 = 0;
    var discarded: f64 = 0;
    for (0..120) |_| {
        const delta: f64 = 1.0 / 20.0;
        requested += delta;
        const metrics = try clock.beginFrame(delta);
        executed_ticks += metrics.substeps;
        discarded += metrics.discarded_time;
        try std.testing.expectEqual(@as(u8, 8), metrics.substeps);
        try std.testing.expectApproxEqAbs(@as(f64, 4.0 / 240.0), metrics.discarded_time, 1e-12);
    }
    const executed = @as(f64, @floatFromInt(executed_ticks)) * fixed_step.fixed_dt_seconds;
    try std.testing.expectApproxEqAbs(@as(f64, 6), requested, 1e-12);
    try std.testing.expectApproxEqAbs(@as(f64, 4), executed, 1e-12);
    try std.testing.expectApproxEqAbs(@as(f64, 2), discarded, 1e-10);
    try std.testing.expectApproxEqAbs(requested, executed + discarded + clock.accumulator, 1e-10);

    clock.reset();
    const schedule = [_]f64{ 0, 8 * fixed_step.fixed_dt_seconds, 0, 8 * fixed_step.fixed_dt_seconds };
    var schedule_ticks: u64 = 0;
    for (0..64) |index| schedule_ticks += (try clock.beginFrame(schedule[index % schedule.len])).substeps;
    try std.testing.expectEqual(@as(u64, 256), schedule_ticks);
    try std.testing.expectApproxEqAbs(@as(f64, 0), clock.lifetime_discarded_time, 1e-12);
}

test "collision world rejects invalid definitions and injection cleans allocations" {
    try std.testing.expectError(error.EmptyCollisionWorld, collision_world.CollisionWorld.init(std.testing.allocator, &.{}, null));
    const invalid = [_]collider.StaticColliderInput{.{
        .id = 0,
        .bounds = .{ .minimum = .{ .x = 0, .y = 0 }, .maximum = .{ .x = 1, .y = 1 } },
    }};
    try std.testing.expectError(error.InvalidColliderIdentifier, collision_world.CollisionWorld.init(std.testing.allocator, &invalid, null));
    const duplicate = [_]collider.StaticColliderInput{
        .{ .id = 1, .bounds = .{ .minimum = .{ .x = 0, .y = 0 }, .maximum = .{ .x = 1, .y = 1 } } },
        .{ .id = 1, .bounds = .{ .minimum = .{ .x = 2, .y = 0 }, .maximum = .{ .x = 3, .y = 1 } } },
    };
    try std.testing.expectError(error.DuplicateColliderIdentifier, collision_world.CollisionWorld.init(std.testing.allocator, &duplicate, null));
    try std.testing.expectError(error.InjectedInitializationFailure, collision_world.CollisionWorld.init(
        std.testing.allocator,
        &duplicate,
        .{ .fail_after = .collision_world_collider_allocation },
    ));
}

test "swept collision catches walls floor ceiling and ignores platform undersides while moving down" {
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    const half = math.Vec2{ .x = 0.30, .y = 1.05 };
    const wall = try world.sweepHorizontal(.{ .x = 0, .y = 4.0 }, half, 10, tolerance);
    try std.testing.expect(wall.hit_wall);
    try std.testing.expectApproxEqAbs(@as(f32, 3.20), wall.resolved_position_x, tolerance);
    const floor = try world.sweepVertical(.{ .x = -4, .y = 5 }, half, -20, tolerance);
    try std.testing.expect(floor.hit_ground);
    try std.testing.expectApproxEqAbs(@as(f32, 1.05), floor.resolved_position_y, tolerance);
    const ceiling = try world.sweepVertical(.{ .x = -2.3, .y = 1.05 }, half, 10, tolerance);
    try std.testing.expect(ceiling.hit_ceiling);
    try std.testing.expectApproxEqAbs(@as(f32, 1.55), ceiling.resolved_position_y, tolerance);
    const below_platform = try world.sweepVertical(.{ .x = -0.2, .y = 0.2 }, half, -0.1, tolerance);
    try std.testing.expect(!below_platform.hit_ground);
}

test "equal collision faces and initial support use stable collider IDs independent of input order" {
    const low_first = [_]collider.StaticColliderInput{
        .{ .id = 3, .bounds = .{ .minimum = .{ .x = -2, .y = -1 }, .maximum = .{ .x = 2, .y = 0 } } },
        .{ .id = 9, .bounds = .{ .minimum = .{ .x = -1, .y = -2 }, .maximum = .{ .x = 1, .y = 0 } } },
        .{ .id = 4, .bounds = .{ .minimum = .{ .x = 2, .y = 0 }, .maximum = .{ .x = 2.5, .y = 4 } }, .ground_query_eligible = false },
        .{ .id = 7, .bounds = .{ .minimum = .{ .x = 2, .y = 1 }, .maximum = .{ .x = 3, .y = 3 } }, .ground_query_eligible = false },
    };
    const high_first = [_]collider.StaticColliderInput{ low_first[1], low_first[0], low_first[3], low_first[2] };
    var world_a = try collision_world.CollisionWorld.init(std.testing.allocator, &low_first, null);
    defer world_a.deinit();
    var world_b = try collision_world.CollisionWorld.init(std.testing.allocator, &high_first, null);
    defer world_b.deinit();
    const half = math.Vec2{ .x = 0.30, .y = 1.05 };

    const support_a = try world_a.supportingCollider(try collider.characterBounds(.{ .x = 0, .y = 1.05 }, half), tolerance);
    const support_b = try world_b.supportingCollider(try collider.characterBounds(.{ .x = 0, .y = 1.05 }, half), tolerance);
    try std.testing.expectEqual(@as(collider.ColliderId, 3), support_a.?);
    try std.testing.expectEqual(support_a, support_b);

    const floor_a = try world_a.sweepVertical(.{ .x = 0, .y = 4 }, half, -10, tolerance);
    const floor_b = try world_b.sweepVertical(.{ .x = 0, .y = 4 }, half, -10, tolerance);
    try std.testing.expectEqual(@as(collider.ColliderId, 3), floor_a.collider_id);
    try std.testing.expectEqual(floor_a.collider_id, floor_b.collider_id);
    try std.testing.expectEqual(floor_a.resolved_position_y, floor_b.resolved_position_y);

    const wall_a = try world_a.sweepHorizontal(.{ .x = 0, .y = 2 }, half, 10, tolerance);
    const wall_b = try world_b.sweepHorizontal(.{ .x = 0, .y = 2 }, half, 10, tolerance);
    try std.testing.expectEqual(@as(collider.ColliderId, 4), wall_a.collider_id);
    try std.testing.expectEqual(wall_a.collider_id, wall_b.collider_id);
    try std.testing.expectEqual(wall_a.resolved_position_x, wall_b.resolved_position_x);
}

test "maximum-speed diagonal exact corner remains finite stable and lands once" {
    const inputs = [_]collider.StaticColliderInput{
        .{ .id = 2, .bounds = .{ .minimum = .{ .x = -10, .y = -2 }, .maximum = .{ .x = 10, .y = 0 } } },
        .{ .id = 5, .bounds = .{ .minimum = .{ .x = 1.30, .y = 0 }, .maximum = .{ .x = 1.60, .y = 6 } }, .ground_query_eligible = false },
    };
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &inputs, null);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0.25, .y = 4.05 }, .right);
    controller.state.velocity = .{
        .x = controller.configuration.maximum_run_speed,
        .y = -controller.configuration.maximum_fall_speed,
    };
    var landings: u32 = 0;
    for (0..80) |_| {
        const result = try controller.step(&world, moveIntent(1));
        if (result.landed) landings += 1;
        try std.testing.expect(controller.state.position.isFinite());
        try std.testing.expect(controller.state.velocity.isFinite());
    }
    try std.testing.expectEqual(@as(u32, 1), landings);
    try std.testing.expect(controller.state.grounded);
    try std.testing.expectEqual(@as(?collider.ColliderId, 2), controller.state.supporting_collider);
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), controller.state.position.x, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 1.05), controller.state.position.y, tolerance);
    for (0..600) |_| {
        const result = try controller.step(&world, emptyIntent());
        try std.testing.expect(!result.landed);
        try std.testing.expect(controller.state.position.isFinite());
        try std.testing.expect(controller.state.velocity.isFinite());
        try std.testing.expectEqual(@as(?collider.ColliderId, 2), controller.state.supporting_collider);
    }

    const epsilon_contact = try character_controller.CharacterController.init(
        .{},
        &world,
        .{ .x = -2, .y = 1.05 + tolerance * 0.5 },
        .right,
    );
    try std.testing.expect(epsilon_contact.state.grounded);
    try std.testing.expectEqual(@as(?collider.ColliderId, 2), epsilon_contact.state.supporting_collider);
}

test "controller accelerates decelerates clamps speed and updates facing" {
    var world = try oneFloor(std.testing.allocator);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 1.05 }, .right);
    _ = try controller.step(&world, moveIntent(1));
    try std.testing.expectApproxEqAbs(@as(f32, 36.0 / 240.0), controller.state.velocity.x, tolerance);
    for (0..240) |_| _ = try controller.step(&world, moveIntent(1));
    try std.testing.expectApproxEqAbs(controller.configuration.maximum_run_speed, controller.state.velocity.x, tolerance);
    for (0..240) |_| _ = try controller.step(&world, emptyIntent());
    try std.testing.expectApproxEqAbs(@as(f32, 0), controller.state.velocity.x, tolerance);
    _ = try controller.step(&world, moveIntent(-1));
    try std.testing.expectEqual(character_controller.Facing.left, controller.state.facing);
}

test "falling lands exactly once and remains stable without penetration" {
    var world = try oneFloor(std.testing.allocator);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 4 }, .right);
    var landings: u32 = 0;
    var impact: f32 = 0;
    for (0..600) |_| {
        const result = try controller.step(&world, emptyIntent());
        if (result.landed) {
            landings += 1;
            impact = result.landing_impact_speed;
        }
    }
    try std.testing.expectEqual(@as(u32, 1), landings);
    try std.testing.expect(impact > 0.25);
    try std.testing.expect(controller.state.grounded);
    try std.testing.expectApproxEqAbs(@as(f32, 1.05), controller.state.position.y, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0), controller.state.velocity.y, tolerance);
    const bounds = try collider.characterBounds(controller.state.position, controller.configuration.collider_half_extents);
    try std.testing.expect(!world.containsPenetration(bounds));

    var jump = emptyIntent();
    jump.jump_pressed = true;
    try std.testing.expect((try controller.step(&world, jump)).jump_accepted);
    var second_landing_count: u32 = 0;
    for (0..600) |_| if ((try controller.step(&world, emptyIntent())).landed) {
        second_landing_count += 1;
    };
    try std.testing.expectEqual(@as(u32, 1), second_landing_count);

    var soft = try character_controller.CharacterController.init(.{}, &world, .{ .x = 2, .y = 1.0505 }, .right);
    soft.state.velocity.y = -0.05;
    const soft_contact = try soft.step(&world, emptyIntent());
    try std.testing.expect(soft.state.grounded);
    try std.testing.expect(!soft_contact.landed);
    try std.testing.expect(soft.state.last_landing_tick == null);
}

test "held jump does not repeat and early release produces a lower apex" {
    var world = try oneFloor(std.testing.allocator);
    defer world.deinit();
    var held = try character_controller.CharacterController.init(.{}, &world, .{ .x = -1, .y = 1.05 }, .right);
    var tapped = try character_controller.CharacterController.init(.{}, &world, .{ .x = 1, .y = 1.05 }, .right);
    var press = emptyIntent();
    press.jump_pressed = true;
    press.jump_held = true;
    try std.testing.expect((try held.step(&world, press)).jump_accepted);
    try std.testing.expect((try tapped.step(&world, press)).jump_accepted);
    var held_apex = held.state.position.y;
    var tapped_apex = tapped.state.position.y;
    var repeated: u32 = 0;
    for (0..180) |tick| {
        var held_intent = emptyIntent();
        held_intent.jump_held = true;
        if ((try held.step(&world, held_intent)).jump_accepted) repeated += 1;
        var tap_intent = emptyIntent();
        if (tick == 0) tap_intent.jump_released = true;
        _ = try tapped.step(&world, tap_intent);
        held_apex = @max(held_apex, held.state.position.y);
        tapped_apex = @max(tapped_apex, tapped.state.position.y);
    }
    try std.testing.expectEqual(@as(u32, 0), repeated);
    try std.testing.expect(held_apex > tapped_apex + 0.5);
}

fn walkOff(controller: *character_controller.CharacterController, world: *const collision_world.CollisionWorld) !character_controller.StepResult {
    while (true) {
        const result = try controller.step(world, moveIntent(1));
        if (result.ground_left) return result;
    }
}

test "coyote jump succeeds on its final tick expires afterward and cannot repeat" {
    var world = try onePlatform(std.testing.allocator);
    defer world.deinit();
    var final_tick = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0.65, .y = 1.05 }, .right);
    _ = try walkOff(&final_tick, &world);
    while (final_tick.state.coyote_ticks_remaining > 1) _ = try final_tick.step(&world, moveIntent(1));
    var press = moveIntent(1);
    press.jump_pressed = true;
    const accepted = try final_tick.step(&world, press);
    try std.testing.expect(accepted.jump_accepted and accepted.jump_source.? == .coyote and accepted.coyote_consumed);
    const held_again = try final_tick.step(&world, press);
    try std.testing.expect(!held_again.jump_accepted);

    var expired = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0.65, .y = 1.05 }, .right);
    _ = try walkOff(&expired, &world);
    while (expired.state.coyote_ticks_remaining > 0) _ = try expired.step(&world, moveIntent(1));
    try std.testing.expect(!(try expired.step(&world, press)).jump_accepted);
}

test "buffered jump is consumed once on landing and reset clears timers" {
    var world = try oneFloor(std.testing.allocator);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 1.20 }, .right);
    controller.state.velocity.y = -2;
    var press = emptyIntent();
    press.jump_pressed = true;
    var result = try controller.step(&world, press);
    try std.testing.expect(!result.jump_accepted and result.jump_buffer_started);
    var buffered_count: u32 = 0;
    for (0..40) |_| {
        result = try controller.step(&world, emptyIntent());
        if (result.jump_source == .buffered) buffered_count += 1;
    }
    try std.testing.expectEqual(@as(u32, 1), buffered_count);
    try std.testing.expect(controller.state.velocity.y > 0);
    try controller.reset(&world);
    try std.testing.expectEqual(@as(u16, 0), controller.state.jump_buffer_ticks_remaining);
    try std.testing.expectEqual(@as(u16, 0), controller.state.coyote_ticks_remaining);
    try std.testing.expect(controller.state.last_jump_tick == null);
}

const Schedule = enum { one_tick, two_ticks, mixed };

fn scheduleTickCount(schedule: Schedule, frame: usize) u32 {
    return switch (schedule) {
        .one_tick => 1,
        .two_ticks => 2,
        .mixed => switch (frame % 4) {
            0 => 0,
            1 => 1,
            2 => 3,
            else => 4,
        },
    };
}

fn runSchedule(schedule: Schedule) !character_controller.State {
    var world = try oneFloor(std.testing.allocator);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 1.05 }, .right);
    var clock = try fixed_step.Clock.init(.{});
    const frame_count: usize = switch (schedule) {
        .one_tick => 240,
        .two_ticks, .mixed => 120,
    };
    var simulated: u32 = 0;
    for (0..frame_count) |frame| {
        const tick_count = scheduleTickCount(schedule, frame);
        const metrics = try clock.beginFrame(@as(f64, @floatFromInt(tick_count)) * fixed_step.fixed_dt_seconds);
        for (0..metrics.substeps) |_| {
            var intent = if (simulated < 120) moveIntent(1) else moveIntent(-0.35);
            if (simulated == 30) intent.jump_pressed = true;
            if (simulated == 55) intent.jump_released = true;
            _ = try controller.step(&world, intent);
            simulated += 1;
        }
    }
    try std.testing.expectEqual(@as(u32, 240), simulated);
    return controller.state;
}

const FullScheduleResult = struct {
    state: character_controller.State,
    animation_state: state_machine.StateId,
};

fn runFullSchedule(schedule: Schedule) !FullScheduleResult {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var character = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer character.deinit();
    var animation = try animation_system.Runtime.init(std.testing.allocator, &definition, null);
    defer animation.deinit();
    var runtime = try controller_demo.Runtime.init(std.testing.allocator, null);
    defer runtime.deinit();
    const frame_count: usize = switch (schedule) {
        .one_tick => 240,
        .two_ticks, .mixed => 120,
    };
    var simulated: u32 = 0;
    for (0..frame_count) |frame| {
        const count = scheduleTickCount(schedule, frame);
        const metrics = try runtime.beginFrame(@as(f64, @floatFromInt(count)) * fixed_step.fixed_dt_seconds);
        for (0..metrics.substeps) |_| {
            runtime.pending_input.move_axis = if (simulated < 120) 1 else -0.35;
            runtime.pending_input.jump_held = simulated >= 30 and simulated < 55;
            runtime.pending_input.jump_pressed_pending = simulated == 30;
            runtime.pending_input.jump_released_pending = simulated == 55;
            _ = try runtime.simulateTick(&animation, &character, &definition);
            simulated += 1;
        }
    }
    try std.testing.expectEqual(@as(u32, 240), simulated);
    return .{
        .state = runtime.controller.state,
        .animation_state = animation.animator.currentState(&animation.definitions.machine),
    };
}

test "different render schedules produce equivalent fixed-step state" {
    const one = try runSchedule(.one_tick);
    const two = try runSchedule(.two_ticks);
    const mixed = try runSchedule(.mixed);
    inline for (.{ two, mixed }) |actual| {
        try std.testing.expectApproxEqAbs(one.position.x, actual.position.x, tolerance);
        try std.testing.expectApproxEqAbs(one.position.y, actual.position.y, tolerance);
        try std.testing.expectApproxEqAbs(one.velocity.x, actual.velocity.x, tolerance);
        try std.testing.expectApproxEqAbs(one.velocity.y, actual.velocity.y, tolerance);
        try std.testing.expectEqual(one.facing, actual.facing);
        try std.testing.expectEqual(one.grounded, actual.grounded);
        try std.testing.expectEqual(one.simulation_tick, actual.simulation_tick);
    }
    const full_one = try runFullSchedule(.one_tick);
    const full_two = try runFullSchedule(.two_ticks);
    const full_mixed = try runFullSchedule(.mixed);
    inline for (.{ full_two, full_mixed }) |actual| {
        try std.testing.expectApproxEqAbs(full_one.state.position.x, actual.state.position.x, tolerance);
        try std.testing.expectApproxEqAbs(full_one.state.position.y, actual.state.position.y, tolerance);
        try std.testing.expectApproxEqAbs(full_one.state.velocity.x, actual.state.velocity.x, tolerance);
        try std.testing.expectApproxEqAbs(full_one.state.velocity.y, actual.state.velocity.y, tolerance);
        try std.testing.expectEqual(full_one.state.grounded, actual.state.grounded);
        try std.testing.expectEqual(full_one.state.facing, actual.state.facing);
        try std.testing.expectEqual(full_one.animation_state, actual.animation_state);
    }
}

test "controller runtime advances animator once per 240 Hz tick without hot-path allocation" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var character = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer character.deinit();
    var animation = try animation_system.Runtime.init(std.testing.allocator, &definition, null);
    defer animation.deinit();
    var runtime = try controller_demo.Runtime.init(std.testing.allocator, null);
    defer runtime.deinit();
    var builder = input.SnapshotBuilder{};
    for (0..60) |_| {
        try runtime.acceptFrameInput(try builder.update(.{ .keyboard = .{ .d = true } }));
        const frame = try runtime.beginFrame(1.0 / 60.0);
        try std.testing.expectEqual(@as(u8, 4), frame.substeps);
        for (0..frame.substeps) |_| _ = try runtime.simulateTick(&animation, &character, &definition);
        try runtime.evaluateRenderPose(&character, &definition);
    }
    try std.testing.expectEqual(@as(u64, 240), runtime.metrics.simulation_ticks);
    try std.testing.expectEqual(runtime.metrics.simulation_ticks, runtime.metrics.animator_ticks);
    try std.testing.expectEqual(@as(u64, 0), runtime.metrics.clock_allocations);
    try std.testing.expectEqual(@as(u64, 0), runtime.metrics.input_allocations);
    try std.testing.expectEqual(@as(u64, 0), runtime.metrics.controller_allocations);
    try std.testing.expectEqual(@as(u64, 0), runtime.metrics.collision_allocations);
    try std.testing.expectEqual(@as(u64, 0), runtime.metrics.animator_allocations);
    try runtime.reset(&animation, &character, &definition);
    try std.testing.expectEqual(@as(u64, 0), runtime.controller.state.simulation_tick);
    try std.testing.expectEqual(@as(u64, 0), runtime.metrics.simulation_ticks);
}

test "controller initialization fault stages are recoverable" {
    try controller_demo.runFaultInjectionChecks(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), fault_injection.controller_initialization_stages.len);
}

test "scripted input reaches every controller milestone through the real fixed-step pipeline" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var character = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer character.deinit();
    var animation = try animation_system.Runtime.init(std.testing.allocator, &definition, null);
    defer animation.deinit();
    var runtime = try controller_demo.Runtime.init(std.testing.allocator, null);
    defer runtime.deinit();
    var script = controller_demo.ScriptedInput{};
    for (0..600) |frame_index| {
        try runtime.acceptFrameInput(try script.nextFrame(&runtime.controller));
        const frame = try runtime.beginFrame(1.0 / 60.0);
        for (0..frame.substeps) |_| {
            const tick = runtime.simulateTick(&animation, &character, &definition) catch |err| {
                std.debug.print("script failure frame={d} phase={s} position=({d},{d}) velocity=({d},{d}) grounded={} error={s}\n", .{
                    frame_index,
                    @tagName(script.phase),
                    runtime.controller.state.position.x,
                    runtime.controller.state.position.y,
                    runtime.controller.state.velocity.x,
                    runtime.controller.state.velocity.y,
                    runtime.controller.state.grounded,
                    @errorName(err),
                });
                return err;
            };
            script.observe(tick, &runtime.controller);
        }
        try runtime.evaluateRenderPose(&character, &definition);
    }
    if (!script.completed()) {
        std.debug.print("script incomplete phase={s} phase_frames={d} flags ceiling={} first={} second={} coyote={} buffered={} wall={} position=({d},{d}) velocity=({d},{d}) grounded={}\n", .{
            @tagName(script.phase),              script.phase_frames,                 script.ceiling_seen,                 script.first_platform_landed,
            script.second_platform_landed,       script.coyote_jump_seen,             script.buffered_jump_seen,           script.wall_seen,
            runtime.controller.state.position.x, runtime.controller.state.position.y, runtime.controller.state.velocity.x, runtime.controller.state.velocity.y,
            runtime.controller.state.grounded,
        });
        return error.ScriptDidNotComplete;
    }
    try std.testing.expect(script.ceiling_seen);
    try std.testing.expect(script.first_platform_landed);
    try std.testing.expect(script.second_platform_landed);
    try std.testing.expect(script.coyote_jump_seen);
    try std.testing.expect(script.buffered_jump_seen);
    try std.testing.expect(script.wall_seen);
    try std.testing.expect(runtime.controller.state.grounded);
    try std.testing.expectEqual(@as(u64, 2400), runtime.metrics.simulation_ticks);
}

test "render interpolation is midpoint-only and reset synchronizes snapshots" {
    var world = try oneFloor(std.testing.allocator);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 1.05 }, .right);
    _ = try controller.step(&world, moveIntent(1));
    const before = controller.state;
    const midpoint = try controller.interpolatedPosition(0.5);
    try std.testing.expectApproxEqAbs((before.previous_position.x + before.position.x) * 0.5, midpoint.x, tolerance);
    try std.testing.expectApproxEqAbs((before.previous_position.y + before.position.y) * 0.5, midpoint.y, tolerance);
    try std.testing.expectEqual(before.position, controller.state.position);
    try std.testing.expectError(error.InterpolationAlphaOutOfRange, controller.interpolatedPosition(1));
    try controller.reset(&world);
    try std.testing.expectEqual(controller.state.position, controller.state.previous_position);
}

test "ground rest is stable for 600 complete simulation ticks" {
    var world = try oneFloor(std.testing.allocator);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 1.05 }, .right);
    var landing_count: u32 = 0;
    for (0..600) |_| {
        const result = try controller.step(&world, emptyIntent());
        if (result.landed) landing_count += 1;
        try std.testing.expect(controller.state.grounded);
        try std.testing.expectApproxEqAbs(@as(f32, 1.05), controller.state.position.y, tolerance);
        try std.testing.expectApproxEqAbs(@as(f32, 0), controller.state.velocity.y, tolerance);
        try std.testing.expectEqual(@as(u16, 24), controller.state.coyote_ticks_remaining);
    }
    try std.testing.expectEqual(@as(u32, 0), landing_count);
    try std.testing.expect(controller.state.last_landing_tick == null);
}

test "air control ceiling wall and platform contacts retain correct classification" {
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();

    var airborne = try character_controller.CharacterController.init(.{}, &world, .{ .x = -4, .y = 4 }, .right);
    _ = try airborne.step(&world, moveIntent(1));
    try std.testing.expectApproxEqAbs(@as(f32, 18.0 / 240.0), airborne.state.velocity.x, tolerance);

    var ceiling = try character_controller.CharacterController.init(.{}, &world, .{ .x = -2.3, .y = 1.05 }, .right);
    var jump = emptyIntent();
    jump.jump_pressed = true;
    _ = try ceiling.step(&world, jump);
    var ceiling_seen = false;
    for (0..120) |_| {
        const result = try ceiling.step(&world, emptyIntent());
        if (result.ceiling_collision) {
            ceiling_seen = true;
            try std.testing.expect(!result.landed);
            try std.testing.expect(!ceiling.state.grounded);
            try std.testing.expectApproxEqAbs(@as(f32, 0), ceiling.state.velocity.y, tolerance);
            try std.testing.expect(ceiling.state.position.y <= 1.55 + tolerance);
            break;
        }
    }
    try std.testing.expect(ceiling_seen);

    var wall = try character_controller.CharacterController.init(.{}, &world, .{ .x = 3.0, .y = 4.0 }, .right);
    wall.state.velocity.x = wall.configuration.maximum_run_speed;
    var wall_seen = false;
    for (0..30) |_| {
        const result = try wall.step(&world, moveIntent(1));
        if (result.wall_collision) {
            wall_seen = true;
            try std.testing.expect(!result.landed);
            try std.testing.expect(!wall.state.grounded);
            try std.testing.expectApproxEqAbs(@as(f32, 0), wall.state.velocity.x, tolerance);
            try std.testing.expectApproxEqAbs(@as(f32, 3.2), wall.state.position.x, tolerance);
            break;
        }
    }
    try std.testing.expect(wall_seen);

    var platform = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 4.5 }, .right);
    var landed_on_platform = false;
    for (0..300) |_| {
        const result = try platform.step(&world, emptyIntent());
        if (result.landed) {
            landed_on_platform = platform.state.supporting_collider == @intFromEnum(collision_world.DemoColliderId.raised_platform_1);
            break;
        }
    }
    try std.testing.expect(landed_on_platform);
    try std.testing.expectApproxEqAbs(@as(f32, 2.20), platform.state.position.y, tolerance);
    var left_platform = false;
    for (0..240) |_| {
        const result = try platform.step(&world, moveIntent(1));
        if (result.ground_left) {
            left_platform = true;
            try std.testing.expect(!platform.state.grounded);
            try std.testing.expect(platform.state.supporting_collider == null);
            break;
        }
    }
    try std.testing.expect(left_platform);
}

test "timer expiration held-input and post-apex release boundaries are exact" {
    var world = try oneFloor(std.testing.allocator);
    defer world.deinit();
    var expired = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 10 }, .right);
    var press = emptyIntent();
    press.jump_pressed = true;
    press.jump_held = true;
    _ = try expired.step(&world, press);
    for (0..40) |_| {
        var held = emptyIntent();
        held.jump_held = true;
        try std.testing.expect(!(try expired.step(&world, held)).jump_accepted);
    }
    try std.testing.expectEqual(@as(u16, 0), expired.state.jump_buffer_ticks_remaining);
    var late_jump_count: u32 = 0;
    for (0..600) |_| {
        var held = emptyIntent();
        held.jump_held = true;
        if ((try expired.step(&world, held)).jump_accepted) late_jump_count += 1;
    }
    try std.testing.expectEqual(@as(u32, 0), late_jump_count);

    var boundary = try character_controller.CharacterController.init(.{}, &world, .{ .x = 2, .y = 1.051 }, .right);
    boundary.state.velocity.y = -1;
    boundary.state.jump_buffer_ticks_remaining = 1;
    const boundary_result = try boundary.step(&world, emptyIntent());
    try std.testing.expect(boundary_result.jump_source == .buffered);
    var first_expired = try character_controller.CharacterController.init(.{}, &world, .{ .x = -2, .y = 1.051 }, .right);
    first_expired.state.velocity.y = -1;
    const rejected = try first_expired.step(&world, emptyIntent());
    try std.testing.expect(!rejected.jump_accepted and rejected.landed);

    var jumper = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 1.05 }, .right);
    try std.testing.expect((try jumper.step(&world, press)).jump_accepted);
    while (jumper.state.velocity.y >= 0) _ = try jumper.step(&world, emptyIntent());
    var comparison = jumper;
    var release = emptyIntent();
    release.jump_released = true;
    _ = try jumper.step(&world, release);
    _ = try comparison.step(&world, emptyIntent());
    try std.testing.expectApproxEqAbs(comparison.state.velocity.y, jumper.state.velocity.y, tolerance);
}

test "malformed physics configuration and state are rejected" {
    var invalid = character_controller.Configuration{};
    invalid.gravity = 1;
    try std.testing.expectError(error.InvalidGravity, invalid.validate());
    invalid = .{};
    invalid.fixed_dt = 0.005;
    try std.testing.expectError(error.InvalidFixedTimestep, invalid.validate());
    invalid = .{};
    invalid.collider_half_extents.x = 0;
    try std.testing.expectError(error.InvalidColliderDimensions, invalid.validate());
    invalid = .{};
    invalid.jump_release_speed = invalid.jump_speed;
    try std.testing.expectError(error.InvalidJumpConfiguration, invalid.validate());
    try std.testing.expectError(error.InvalidMaximumSubsteps, fixed_step.Clock.init(.{ .maximum_substeps = 0 }));
    try std.testing.expectError(error.InvalidFixedTimestep, fixed_step.Clock.init(.{ .fixed_dt = 0 }));

    var world = try oneFloor(std.testing.allocator);
    defer world.deinit();
    try std.testing.expectError(error.UnsupportedInitialPenetration, character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 0 }, .right));
    var controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 1.05 }, .right);
    controller.state.velocity.x = std.math.nan(f32);
    try std.testing.expectError(error.NonFiniteVelocity, controller.step(&world, emptyIntent()));
}

test "runtime reset clears rising falling buffered and transition state without reallocation" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var character = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer character.deinit();
    var animation = try animation_system.Runtime.init(std.testing.allocator, &definition, null);
    defer animation.deinit();
    var runtime = try controller_demo.Runtime.init(std.testing.allocator, null);
    defer runtime.deinit();

    try animation.animator.requestState(&animation.definitions.machine, .walk);
    try std.testing.expect(animation.animator.active_transition != null);
    try runtime.reset(&animation, &character, &definition);
    try std.testing.expect(animation.animator.active_transition == null);

    var builder = input.SnapshotBuilder{};
    try runtime.acceptFrameInput(try builder.update(.{ .keyboard = .{ .space = true } }));
    _ = try runtime.simulateTick(&animation, &character, &definition);
    try std.testing.expect(runtime.controller.state.velocity.y > 0);
    try runtime.reset(&animation, &character, &definition);
    try std.testing.expectApproxEqAbs(@as(f32, 0), runtime.controller.state.velocity.y, tolerance);

    runtime.controller.state.position.y = 3;
    runtime.controller.state.previous_position = runtime.controller.state.position;
    runtime.controller.state.grounded = false;
    runtime.controller.state.previous_grounded = false;
    runtime.controller.state.velocity.y = -2;
    runtime.controller.state.jump_buffer_ticks_remaining = 5;
    runtime.pending_input.jump_pressed_pending = true;
    try animation.animator.enterState(&animation.definitions.machine, .falling);
    try runtime.reset(&animation, &character, &definition);
    try std.testing.expectEqual(controller_demo.spawn_position, runtime.controller.state.position);
    try std.testing.expectEqual(runtime.controller.state.position, runtime.controller.state.previous_position);
    try std.testing.expectApproxEqAbs(@as(f32, 0), runtime.controller.state.velocity.length(), tolerance);
    try std.testing.expectEqual(@as(u16, 0), runtime.controller.state.jump_buffer_ticks_remaining);
    try std.testing.expect(!runtime.pending_input.jump_pressed_pending);
    try std.testing.expect(animation.animator.active_transition == null);
    try std.testing.expectEqual(@as(f32, 0), animation.animator.currentClipTime());
}
