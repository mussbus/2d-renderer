const std = @import("std");
const math = @import("math");
const fixed_step = @import("fixed_step");
const spring = @import("spring");
const procedural = @import("procedural_motion");
const humanoid = @import("humanoid");
const animation_system = @import("animation_system");
const controller_demo = @import("controller_demo");

const tolerance: f32 = 1e-5;

test "spring rejects invalid configuration and non-finite state" {
    const valid = procedural.landing_spring_configuration;
    var invalid = valid;
    invalid.stiffness = -1;
    try std.testing.expectError(error.InvalidSpringStiffness, invalid.validate(procedural.procedural_fixed_dt));
    invalid = valid;
    invalid.stiffness = std.math.inf(f32);
    try std.testing.expectError(error.InvalidSpringStiffness, invalid.validate(procedural.procedural_fixed_dt));
    invalid = valid;
    invalid.damping = -1;
    try std.testing.expectError(error.InvalidSpringDamping, invalid.validate(procedural.procedural_fixed_dt));
    invalid = valid;
    invalid.damping = std.math.nan(f32);
    try std.testing.expectError(error.InvalidSpringDamping, invalid.validate(procedural.procedural_fixed_dt));
    invalid = valid;
    invalid.maximum_displacement = -0.01;
    try std.testing.expectError(error.InvalidSpringDisplacementLimit, invalid.validate(procedural.procedural_fixed_dt));
    invalid = valid;
    invalid.maximum_velocity = -0.01;
    try std.testing.expectError(error.InvalidSpringVelocityLimit, invalid.validate(procedural.procedural_fixed_dt));
    try std.testing.expectError(error.InvalidSpringTimestep, valid.validate(0));
    try std.testing.expectError(error.InvalidSpringTimestep, valid.validate(std.math.inf(f32)));
    try std.testing.expectError(error.NonFiniteSpringState, spring.State.init(valid, procedural.procedural_fixed_dt, std.math.nan(f32), 0, 0));
    try std.testing.expectError(error.SpringStateOutsideLimits, spring.State.init(valid, procedural.procedural_fixed_dt, valid.maximum_displacement + 1, 0, 0));

    var state = spring.State{};
    state.velocity = std.math.inf(f32);
    try std.testing.expectError(error.NonFiniteSpringState, state.step(valid, procedural.procedural_fixed_dt));
}

test "neutral spring is exact and signed disturbances return toward zero" {
    const config = procedural.landing_spring_configuration;
    var neutral = try spring.State.init(config, procedural.procedural_fixed_dt, 0, 0, 0);
    for (0..2400) |_| try neutral.step(config, procedural.procedural_fixed_dt);
    try std.testing.expectEqual(@as(f32, 0), neutral.offset);
    try std.testing.expectEqual(@as(f32, 0), neutral.velocity);

    var positive = try spring.State.init(config, procedural.procedural_fixed_dt, 0.05, 1.0, 0);
    var negative = try spring.State.init(config, procedural.procedural_fixed_dt, -0.05, -1.0, 0);
    for (0..2400) |_| {
        try positive.step(config, procedural.procedural_fixed_dt);
        try negative.step(config, procedural.procedural_fixed_dt);
    }
    try std.testing.expect(@abs(positive.offset) < 1e-6 and @abs(positive.velocity) < 1e-5);
    try std.testing.expect(@abs(negative.offset) < 1e-6 and @abs(negative.velocity) < 1e-5);
}

test "spring impulse remains finite bounded and converges over long stress" {
    const config = procedural.landing_spring_configuration;
    var state = spring.State{};
    try state.applyVelocityImpulse(-1000, config);
    try std.testing.expectEqual(-config.maximum_velocity, state.velocity);
    var maximum_observed_offset: f32 = 0;
    for (0..24000) |_| {
        try state.step(config, procedural.procedural_fixed_dt);
        try std.testing.expect(std.math.isFinite(state.offset) and std.math.isFinite(state.velocity));
        try std.testing.expect(@abs(state.offset) <= config.maximum_displacement);
        try std.testing.expect(@abs(state.velocity) <= config.maximum_velocity);
        maximum_observed_offset = @max(maximum_observed_offset, @abs(state.offset));
    }
    try std.testing.expect(maximum_observed_offset > 0);
    try std.testing.expect(@abs(state.offset) < 1e-6 and @abs(state.velocity) < 1e-5);
}

test "spring repeated run and reset replay are deterministic" {
    const config = procedural.secondary_spring_configuration;
    var first = spring.State{};
    var second = spring.State{};
    for (0..4096) |tick| {
        const target: f32 = if (tick < 120) -0.08 else 0;
        try first.setTarget(target, config);
        try second.setTarget(target, config);
        try first.step(config, procedural.procedural_fixed_dt);
        try second.step(config, procedural.procedural_fixed_dt);
    }
    try std.testing.expectEqual(first, second);
    const recorded = first;
    first.reset();
    for (0..4096) |tick| {
        try first.setTarget(if (tick < 120) -0.08 else 0, config);
        try first.step(config, procedural.procedural_fixed_dt);
    }
    try std.testing.expectEqual(recorded, first);
}

test "landing impulse mapping is finite monotonic thresholded and clamped" {
    try std.testing.expectEqual(@as(f32, 0), try procedural.landingImpulseForImpact(0.166667));
    try std.testing.expectEqual(@as(f32, 0), try procedural.landingImpulseForImpact(procedural.landing_minimum_trigger_impact));
    const slight = try procedural.landingImpulseForImpact(procedural.landing_minimum_trigger_impact + 0.001);
    const nominal = try procedural.landingImpulseForImpact(procedural.landing_nominal_impact);
    const maximum = try procedural.landingImpulseForImpact(procedural.landing_maximum_mapped_impact);
    const above = try procedural.landingImpulseForImpact(1000);
    try std.testing.expect(slight < 0);
    try std.testing.expect(@abs(slight) < @abs(nominal));
    try std.testing.expect(@abs(nominal) < @abs(maximum));
    try std.testing.expectEqual(maximum, above);
    try std.testing.expectApproxEqAbs(procedural.landing_maximum_impulse, @abs(maximum), tolerance);
    try std.testing.expectError(error.InvalidLandingImpact, procedural.landingImpulseForImpact(-1));
    try std.testing.expectError(error.InvalidLandingImpact, procedural.landingImpulseForImpact(std.math.nan(f32)));
}

test "hard landing has greater bounded compression than moderate landing" {
    const moderate = try landingRun(procedural.landing_nominal_impact);
    const hard = try landingRun(procedural.landing_maximum_mapped_impact);
    const above = try landingRun(1000);
    try std.testing.expect(moderate.peak < 0 and hard.peak < moderate.peak);
    try std.testing.expect(@abs(hard.peak) <= procedural.landing_spring_configuration.maximum_displacement);
    try std.testing.expectApproxEqAbs(hard.peak, above.peak, tolerance);
    try std.testing.expect(@abs(moderate.final_offset) < 1e-5 and @abs(moderate.final_velocity) < 1e-4);
    try std.testing.expect(@abs(hard.final_offset) < 1e-5 and @abs(hard.final_velocity) < 1e-4);
}

test "one landing event is consumed once and reset clears every response" {
    var state = try procedural.State.init();
    const event = procedural.LandingEvent{ .simulation_tick = 17, .impact_speed = procedural.landing_nominal_impact };
    try state.update(tickInput(0, true, 0, 0, event));
    try std.testing.expectEqual(@as(u32, 1), state.metrics.landing_impulses);
    try state.update(tickInput(0, true, 0, 0, event));
    try std.testing.expectEqual(@as(u32, 1), state.metrics.landing_impulses);
    for (0..60) |_| try state.update(tickInput(0, true, 0, 0, null));
    try std.testing.expectEqual(@as(u32, 1), state.metrics.landing_impulses);
    try state.reset(0);
    try std.testing.expectEqual(@as(f32, 0), state.landing_spring.offset);
    try std.testing.expectEqual(@as(f32, 0), state.landing_spring.velocity);
    try std.testing.expect(state.last_consumed_landing_tick == null);
    try std.testing.expectEqual(@as(u32, 0), state.metrics.landing_impulses);
}

test "non-landing collision ticks cannot create landing compression" {
    var state = try procedural.State.init();
    for (0..600) |tick| {
        const velocity: f32 = if (tick % 2 == 0) 4.5 else -4.5;
        try state.update(tickInput(velocity, false, 0.25, 1, null));
    }
    try std.testing.expectEqual(@as(u32, 0), state.metrics.landing_impulses);
    try std.testing.expectEqual(@as(f32, 0), state.landing_spring.offset);
    try std.testing.expectEqual(@as(f32, 0), state.landing_spring.velocity);
}

test "walk amplitude uses speed magnitude and clamps at full speed" {
    try std.testing.expectEqual(@as(f32, 0), procedural.walkAmplitudeForSpeed(0));
    try std.testing.expectEqual(@as(f32, 0), procedural.walkAmplitudeForSpeed(procedural.walk_minimum_active_speed));
    const partial = procedural.walkAmplitudeForSpeed(2.25);
    try std.testing.expect(partial > 0 and partial < procedural.walk_maximum_amplitude);
    try std.testing.expectApproxEqAbs(procedural.walk_maximum_amplitude, procedural.walkAmplitudeForSpeed(4.5), tolerance);
    try std.testing.expectApproxEqAbs(procedural.walk_maximum_amplitude, procedural.walkAmplitudeForSpeed(100), tolerance);
    try std.testing.expectApproxEqAbs(partial, procedural.walkAmplitudeForSpeed(-2.25), tolerance);
}

test "authored contact phases alternate and each loop returns exactly neutral" {
    const left = try procedural.contactPhase(0.10);
    const right = try procedural.contactPhase(0.60);
    try std.testing.expectEqual(procedural.ContactFoot.left, left.foot);
    try std.testing.expectEqual(procedural.ContactFoot.right, right.foot);
    try std.testing.expect((try procedural.walkOffsetAtPhase(0.09, procedural.walk_maximum_amplitude)) < 0);
    try std.testing.expect((try procedural.walkOffsetAtPhase(0.38, procedural.walk_maximum_amplitude)) > 0);
    try std.testing.expectEqual(@as(f32, 0), try procedural.walkOffsetAtPhase(0, procedural.walk_maximum_amplitude));
    try std.testing.expectEqual(@as(f32, 0), try procedural.walkOffsetAtPhase(0.5, procedural.walk_maximum_amplitude));
    try std.testing.expectEqual(@as(f32, 0), try procedural.walkOffsetAtPhase(1, procedural.walk_maximum_amplitude));
}

test "walk bounce has no accumulated drift over one ten and one thousand loops" {
    for ([_]usize{ 1, 10, 1000 }) |loop_count| {
        var state = try procedural.State.init();
        const ticks = loop_count * 240;
        for (0..ticks) |tick| {
            const phase: f32 = @as(f32, @floatFromInt((tick + 1) % 240)) / 240.0;
            try state.update(tickInput(4.5, true, phase, 1, null));
        }
        try std.testing.expectEqual(@as(f32, 0), state.walk_cycle_phase);
        try std.testing.expectEqual(@as(f32, 0), state.walk_bounce_offset);
        try std.testing.expect(@abs(state.visual_root_offset_y) < tolerance);
    }
}

test "walk bounce blends in and out while airborne state suppresses output" {
    var state = try procedural.State.init();
    try state.update(tickInput(4.5, true, 0.38, 1, null));
    const first_amplitude = state.walk_bounce_amplitude;
    try std.testing.expect(first_amplitude > 0 and first_amplitude < procedural.walk_maximum_amplitude);
    for (0..120) |_| try state.update(tickInput(4.5, true, 0.38, 1, null));
    try std.testing.expect(state.walk_bounce_amplitude > first_amplitude);
    try state.update(tickInput(4.5, false, 0.38, 1, null));
    try std.testing.expectEqual(@as(f32, 0), state.walk_bounce_offset);
    for (0..120) |_| try state.update(tickInput(0, true, 0, 0, null));
    try std.testing.expectEqual(@as(f32, 0), state.walk_bounce_amplitude);
    try std.testing.expectEqual(@as(f32, 0), state.walk_bounce_offset);
}

test "secondary head lag follows acceleration direction and remains bounded" {
    var state = try procedural.State.init();
    try state.update(tickInput(0, true, 0, 0, null));
    try state.update(tickInput(4.5, true, 0, 0, null));
    try std.testing.expect(state.secondary_spring.offset < 0);
    var maximum_offset = @abs(state.secondary_spring.offset);
    for (0..2400) |_| {
        try state.update(tickInput(4.5, true, 0, 0, null));
        maximum_offset = @max(maximum_offset, @abs(state.secondary_spring.offset));
        try std.testing.expect(@abs(state.secondary_spring.offset) <= procedural.secondary_spring_configuration.maximum_displacement);
        try std.testing.expect(@abs(state.secondary_spring.velocity) <= procedural.secondary_spring_configuration.maximum_velocity);
    }
    try std.testing.expect(maximum_offset > 0);
    try std.testing.expect(@abs(state.secondary_spring.offset) < 1e-5);
    try std.testing.expect(@abs(state.secondary_spring.velocity) < 1e-4);
}

test "secondary reset teleport synchronization and disable avoid stale spikes" {
    var state = try procedural.State.init();
    try state.update(tickInput(4.5, true, 0, 0, null));
    try std.testing.expect(state.secondary_spring.offset != 0);
    try state.reset(-3.0);
    try state.update(tickInput(-3.0, true, 0, 0, null));
    try std.testing.expectEqual(@as(f32, 0), state.secondary_spring.offset);
    try std.testing.expectEqual(@as(f32, 0), state.secondary_spring.velocity);
    try state.setEnabled(false, -3.0);
    try state.update(tickInput(4.5, true, 0.38, 1, .{ .simulation_tick = 99, .impact_speed = 10 }));
    try std.testing.expectEqual(@as(f32, 0), state.visual_root_offset_y);
    try std.testing.expectEqual(@as(f32, 0), state.secondary_spring.offset);
    try std.testing.expectEqual(@as(u32, 0), state.metrics.landing_impulses);
}

test "procedural states remain independent per character" {
    var first = try procedural.State.init();
    var second = try procedural.State.init();
    try first.update(tickInput(4.5, true, 0.38, 1, .{ .simulation_tick = 1, .impact_speed = 10 }));
    try second.update(tickInput(0, true, 0, 0, null));
    try std.testing.expect(first.landing_spring.offset != second.landing_spring.offset);
    try std.testing.expect(first.secondary_spring.offset != second.secondary_spring.offset);
    try std.testing.expectEqual(@as(f32, 0), second.visual_root_offset_y);
}

test "pose composition applies visual root and head once and disabled pose stays authored" {
    var demo = try humanoid.DemoCharacter.init(std.testing.allocator, null);
    defer demo.deinit();
    const definition = &demo.definition.skeleton_definition;
    const root_index = try definition.boneIndex(.root);
    const head_index = try definition.boneIndex(.head);
    const authored_root = demo.character.local_and_world_pose.local_transforms[root_index];
    const authored_head = demo.character.local_and_world_pose.local_transforms[head_index];

    var state = try procedural.State.init();
    state.visual_root_offset_y = -0.04;
    state.secondary_spring.offset = 0.08;
    try state.composePose(definition, &demo.character.local_and_world_pose, 1);
    try std.testing.expectApproxEqAbs(authored_root.translation.y - 0.04, demo.character.local_and_world_pose.local_transforms[root_index].translation.y, tolerance);
    try std.testing.expectApproxEqAbs(authored_head.rotation_radians + 0.08, demo.character.local_and_world_pose.local_transforms[head_index].rotation_radians, tolerance);
    try std.testing.expectError(error.ProceduralPoseAlreadyComposed, state.composePose(definition, &demo.character.local_and_world_pose, 1));

    try demo.character.local_and_world_pose.restoreAllToRest(definition);
    try state.setEnabled(false, 0);
    try state.composePose(definition, &demo.character.local_and_world_pose, 2);
    try std.testing.expectEqual(authored_root, demo.character.local_and_world_pose.local_transforms[root_index]);
    try std.testing.expectEqual(authored_head, demo.character.local_and_world_pose.local_transforms[head_index]);
}

test "combined authored and procedural compression respects visual floor guard" {
    var state = try procedural.State.init();
    for (0..240) |tick| {
        const event: ?procedural.LandingEvent = if (tick == 0) .{ .simulation_tick = 1, .impact_speed = 1000 } else null;
        try state.update(tickInput(4.5, true, 0.09, 1, event));
        try std.testing.expect(state.visual_root_offset_y >= procedural.minimum_visual_root_offset_y);
        try std.testing.expect(state.visual_root_offset_y <= procedural.maximum_visual_root_offset_y);
    }
}

test "fixed ticks are deterministic across small large and mixed render groupings" {
    const schedule_a = [_]u8{1};
    const schedule_b = [_]u8{4};
    const schedule_c = [_]u8{ 0, 3, 1, 0, 5, 2 };
    const a = try runGroupedSchedule(&schedule_a, 2400);
    const b = try runGroupedSchedule(&schedule_b, 2400);
    const c = try runGroupedSchedule(&schedule_c, 2400);
    try expectProceduralStateEquivalent(a, b);
    try expectProceduralStateEquivalent(a, c);
}

test "procedural enabled and disabled controller replays preserve authoritative physics" {
    const enabled = try runControllerReplay(true);
    const disabled = try runControllerReplay(false);
    try std.testing.expect(enabled.position.approxEqAbs(disabled.position, tolerance));
    try std.testing.expect(enabled.velocity.approxEqAbs(disabled.velocity, tolerance));
    try std.testing.expectEqual(enabled.grounded, disabled.grounded);
    try std.testing.expectEqual(enabled.supporting_collider, disabled.supporting_collider);
    try std.testing.expectEqual(enabled.landing_events, disabled.landing_events);
    try std.testing.expect(enabled.landing_events >= 2);
    try std.testing.expect(enabled.procedural_ticks > 0 and disabled.procedural_ticks > 0);
}

test "procedural hot paths report zero allocations" {
    var state = try procedural.State.init();
    for (0..2400) |tick| {
        try state.update(tickInput(
            if (tick < 600) 4.5 else 0,
            tick < 1200,
            @as(f32, @floatFromInt(tick % 240)) / 240.0,
            if (tick < 600) 1 else 0,
            if (tick == 900) .{ .simulation_tick = tick, .impact_speed = 8 } else null,
        ));
    }
    try std.testing.expectEqual(@as(u64, 0), state.metrics.walk_update_allocations);
    try std.testing.expectEqual(@as(u64, 0), state.metrics.landing_event_allocations);
    try std.testing.expectEqual(@as(u64, 0), state.metrics.spring_update_allocations);
    try std.testing.expectEqual(@as(u64, 0), state.metrics.secondary_update_allocations);
    try std.testing.expectEqual(@as(u64, 0), state.metrics.pose_composition_allocations);
}

const LandingRun = struct {
    peak: f32,
    final_offset: f32,
    final_velocity: f32,
};

fn landingRun(impact: f32) !LandingRun {
    var state = try procedural.State.init();
    try state.update(tickInput(0, true, 0, 0, .{ .simulation_tick = 1, .impact_speed = impact }));
    for (0..2400) |_| try state.update(tickInput(0, true, 0, 0, null));
    return .{
        .peak = state.landing_peak_displacement,
        .final_offset = state.landing_spring.offset,
        .final_velocity = state.landing_spring.velocity,
    };
}

fn tickInput(
    horizontal_velocity: f32,
    grounded: bool,
    walk_phase: f32,
    walk_weight: f32,
    landing_event: ?procedural.LandingEvent,
) procedural.TickInput {
    return .{
        .horizontal_velocity = horizontal_velocity,
        .physically_grounded = grounded,
        .walk_cycle_phase = walk_phase,
        .walk_layer_weight = walk_weight,
        .landing_event = landing_event,
    };
}

fn runGroupedSchedule(schedule: []const u8, total_ticks: u64) !procedural.State {
    var state = try procedural.State.init();
    var tick: u64 = 0;
    var frame: usize = 0;
    while (tick < total_ticks) : (frame += 1) {
        const available = @as(u64, schedule[frame % schedule.len]);
        const count = @min(available, total_ticks - tick);
        for (0..count) |_| {
            const phase: f32 = @as(f32, @floatFromInt(tick % 240)) / 240.0;
            const velocity: f32 = if (tick < 720) 4.5 else if (tick < 960) -2.25 else 0;
            const event: ?procedural.LandingEvent = if (tick == 777)
                .{ .simulation_tick = tick, .impact_speed = 8.25 }
            else
                null;
            try state.update(tickInput(velocity, tick < 1200, phase, if (tick < 1000) 1 else 0, event));
            tick += 1;
        }
    }
    return state;
}

fn expectProceduralStateEquivalent(expected: procedural.State, actual: procedural.State) !void {
    try std.testing.expectApproxEqAbs(expected.landing_spring.offset, actual.landing_spring.offset, tolerance);
    try std.testing.expectApproxEqAbs(expected.landing_spring.velocity, actual.landing_spring.velocity, tolerance);
    try std.testing.expectApproxEqAbs(expected.walk_cycle_phase, actual.walk_cycle_phase, tolerance);
    try std.testing.expectApproxEqAbs(expected.walk_bounce_offset, actual.walk_bounce_offset, tolerance);
    try std.testing.expectApproxEqAbs(expected.secondary_spring.offset, actual.secondary_spring.offset, tolerance);
    try std.testing.expectApproxEqAbs(expected.secondary_spring.velocity, actual.secondary_spring.velocity, tolerance);
}

const ReplayResult = struct {
    position: math.Vec2,
    velocity: math.Vec2,
    grounded: bool,
    supporting_collider: ?u16,
    landing_events: u32,
    procedural_ticks: u64,
};

fn runControllerReplay(enabled: bool) !ReplayResult {
    var demo = try humanoid.DemoCharacter.init(std.testing.allocator, null);
    defer demo.deinit();
    var animation = try animation_system.Runtime.init(std.testing.allocator, &demo.definition, null);
    defer animation.deinit();
    var runtime = try controller_demo.Runtime.init(std.testing.allocator, null);
    defer runtime.deinit();
    try runtime.setProceduralEnabled(enabled);
    var script = controller_demo.ScriptedInput{};

    for (0..600) |_| {
        try runtime.acceptFrameInput(try script.nextFrame(&runtime.controller));
        const frame = try runtime.beginFrame(1.0 / 60.0);
        for (0..frame.substeps) |_| {
            const result = try runtime.simulateTick(&animation, &demo.character, &demo.definition);
            script.observe(result, &runtime.controller);
        }
    }
    const state = runtime.controller.state;
    return .{
        .position = state.position,
        .velocity = state.velocity,
        .grounded = state.grounded,
        .supporting_collider = state.supporting_collider,
        .landing_events = runtime.metrics.landing_events,
        .procedural_ticks = runtime.procedural.metrics.fixed_ticks,
    };
}

comptime {
    if (fixed_step.simulation_hz != 240) @compileError("secondary-motion tests require the authoritative 240 Hz clock");
}
