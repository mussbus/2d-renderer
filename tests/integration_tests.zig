const std = @import("std");
const math = @import("math");
const input = @import("input");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const sprite = @import("sprite_batch");
const diagnostics = @import("diagnostics");
const debug_draw = @import("debug_draw");
const integrated = @import("integrated_demo");

const RunResult = struct {
    state: integrated.AuthoritativeState,
    evidence: integrated.Evidence,
    history_overwrites: u64,
    debug_overflows: u64,
    batch_allocations_after_stabilization: u64,
};

fn runSchedule(configuration: integrated.Configuration, schedule: []const f64, validate: bool) !RunResult {
    var scene = try integrated.Scene.init(std.testing.allocator, configuration);
    defer scene.deinit();
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, sprite.initial_capacity, 1);
    defer batch.deinit();
    batch.markStabilized();
    for (0..integrated.required_frames) |frame| {
        try scene.updateFrame(schedule[frame % schedule.len]);
        batch.beginFrame();
        _ = try scene.submit(&batch);
        const prepared = batch.prepare();
        for (prepared.ranges) |_| batch.recordDraw();
        scene.recordRendering(.{
            .submitted_sprite_count = batch.frame_metrics.submitted_sprites,
            .ordinary_sprite_count = scene.evidence.ordinary_sprites,
            .debug_primitive_count = scene.evidence.debug_primitives,
            .texture_pages = 1,
            .sprite_draw_ranges = batch.frame_metrics.draw_ranges,
            .sprite_draw_calls = batch.frame_metrics.draw_calls,
            .total_actual_draw_calls = batch.frame_metrics.draw_calls,
        });
    }
    if (validate) try scene.validateComplete();
    return .{
        .state = try scene.authoritativeState(),
        .evidence = scene.evidence,
        .history_overwrites = scene.history.overwrite_count,
        .debug_overflows = scene.debug_commands.overflow_count,
        .batch_allocations_after_stabilization = batch.lifetime_metrics.cpu_allocations_after_stabilization,
    };
}

fn expectReset(scene: *const integrated.Scene) !void {
    const controller = scene.player.controller.?.state;
    try std.testing.expect(controller.position.approxEqAbs(.{ .x = -3.15, .y = 1.05 }, 0));
    try std.testing.expect(controller.velocity.approxEqAbs(math.Vec2.zero, 0));
    try std.testing.expect(controller.grounded);
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeCount());
    try std.testing.expect(!scene.player.isInteractionLocked());
    try std.testing.expect(!scene.partner.isInteractionLocked());
    try std.testing.expect(!scene.player.right_arm_ik.applied);
    try std.testing.expect(!scene.partner.right_arm_ik.applied);
    try std.testing.expect(!scene.player.foot_plants.left.hasLock());
    try std.testing.expect(!scene.player.foot_plants.right.hasLock());
    try std.testing.expectEqual(@as(usize, 0), scene.player.overrides.activeCount());
    try std.testing.expectEqual(@as(usize, 0), scene.partner.overrides.activeCount());
    try std.testing.expectEqual(@as(f32, 0), scene.player.procedural.landing_spring.offset);
    try std.testing.expectEqual(@as(f32, 0), scene.player.procedural.secondary_spring.offset);
    try std.testing.expectEqual(@as(usize, 0), scene.history.count);
}

test "diagnostic history is fixed capacity and overwrites oldest snapshots deterministically" {
    var history = diagnostics.History{};
    for (0..diagnostics.history_capacity + 9) |index| {
        var snapshot = diagnostics.Snapshot{};
        snapshot.simulation.fixed_tick = index;
        history.push(snapshot);
    }
    try std.testing.expectEqual(diagnostics.history_capacity, history.count);
    try std.testing.expectEqual(@as(u64, 9), history.overwrite_count);
    try std.testing.expectEqual(@as(u64, 9), history.oldest(0).?.simulation.fixed_tick);
    try std.testing.expectEqual(@as(u64, diagnostics.history_capacity + 8), history.oldest(diagnostics.history_capacity - 1).?.simulation.fixed_tick);
    try std.testing.expect(history.oldest(diagnostics.history_capacity) == null);
}

test "debug command storage is bounded reports overflow and allocates nothing" {
    var commands = debug_draw.CommandBuffer{};
    commands.beginFrame();
    for (0..debug_draw.command_capacity) |index| {
        try commands.addMarker(.{ .x = @floatFromInt(index), .y = 0 }, .{ 1, 1, 1, 1 });
    }
    try std.testing.expectError(error.DebugCommandCapacityExceeded, commands.addMarker(.{ .x = 0, .y = 0 }, .{ 1, 1, 1, 1 }));
    try std.testing.expectEqual(debug_draw.command_capacity, commands.count);
    try std.testing.expectEqual(@as(u64, 1), commands.overflow_count);
    try std.testing.expectEqual(@as(u64, 0), commands.submission_allocations);
}

test "debug visualization on and off preserve the exact authoritative integrated result" {
    const schedule = [_]f64{1.0 / 60.0};
    const disabled = try runSchedule(.{ .debug_visualization = false }, &schedule, true);
    const enabled = try runSchedule(.{ .debug_visualization = true }, &schedule, true);
    try std.testing.expect(integrated.authoritativeStatesEqual(disabled.state, enabled.state, 0));
    try std.testing.expectEqual(@as(u32, 0), disabled.evidence.maximum_debug_primitives);
    try std.testing.expect(enabled.evidence.maximum_debug_primitives > 0);
    try std.testing.expectEqual(@as(u64, 0), enabled.debug_overflows);
    try std.testing.expectEqual(@as(u64, 0), enabled.batch_allocations_after_stabilization);
}

test "diagnostics read every tick and never read during ticks are simulation invariant" {
    const schedule = [_]f64{1.0 / 60.0};
    const unread = try runSchedule(.{
        .diagnostics_each_tick = false,
        .capture_milestones = false,
    }, &schedule, true);
    const read_every_tick = try runSchedule(.{
        .diagnostics_each_tick = true,
        .capture_milestones = true,
    }, &schedule, true);
    try std.testing.expect(integrated.authoritativeStatesEqual(unread.state, read_every_tick.state, 0));
    try std.testing.expectEqual(@as(u64, 0), unread.history_overwrites);
    try std.testing.expectEqual(@as(u64, integrated.required_frames * integrated.fixed_ticks_per_nominal_frame - diagnostics.history_capacity), read_every_tick.history_overwrites);
}

test "diagnostic getters are non destructive and do not consume interaction or animator events" {
    var scene = try integrated.Scene.init(std.testing.allocator, .{ .diagnostics_each_tick = false, .capture_milestones = false });
    defer scene.deinit();
    try scene.updateFixedTicks(2300);
    const before = try scene.authoritativeState();
    const animator_event_count = scene.player.animator.emittedEvents().len;
    const interaction_before = scene.manager.firstActiveInstance().?.*;
    const first = try scene.captureDiagnostics();
    var second = first;
    for (0..1000) |_| second = try scene.captureDiagnostics();
    const after = try scene.authoritativeState();
    try std.testing.expect(integrated.authoritativeStatesEqual(before, after, 0));
    try std.testing.expectEqual(animator_event_count, scene.player.animator.emittedEvents().len);
    try std.testing.expectEqualDeep(interaction_before.event_counts, scene.manager.firstActiveInstance().?.event_counts);
    try std.testing.expectEqualDeep(first.interaction_state.event_counts, second.interaction_state.event_counts);
    try std.testing.expectEqual(first.interaction_state.elapsed_ticks, second.interaction_state.elapsed_ticks);
}

test "integrated update order delivers landing once preserves physics and evaluates IK in production order" {
    const schedule = [_]f64{1.0 / 60.0};
    const run = try runSchedule(.{}, &schedule, true);
    try std.testing.expectEqual(run.evidence.landing_count, run.evidence.landing_event_delivery_count);
    try std.testing.expect(!run.evidence.foot_contact_changed_physics);
    try std.testing.expect(run.evidence.shared_target_from_pre_ik);
    try std.testing.expect(run.evidence.final_pose_after_ik);
    try std.testing.expect(run.evidence.maximum_post_ik_contact_error <= 0.0002);
    try std.testing.expect(run.evidence.partial_interleaving_observed);
    try std.testing.expect(run.evidence.foot_placement_during_handshake);
    try std.testing.expect(run.state.milestone_ticks[@intFromEnum(integrated.Milestone.left_foot_planted)].? <
        run.state.milestone_ticks[@intFromEnum(integrated.Milestone.walk_started)].?);
    const left_lifecycle = run.state;
    try std.testing.expect(left_lifecycle.left_candidate_tick.? <= left_lifecycle.left_plant_tick.?);
    try std.testing.expect(left_lifecycle.left_plant_tick.? <= left_lifecycle.left_release_tick.?);
    try std.testing.expect(left_lifecycle.right_candidate_tick.? <= left_lifecycle.right_plant_tick.?);
    try std.testing.expect(left_lifecycle.right_plant_tick.? <= left_lifecycle.right_release_tick.?);
}

test "integrated scene reset clears planted airborne pre contact and contact state" {
    const reset_ticks = [_]u32{ 1, 200, 400, 842, 900, 1000, 2124, 2200, 2300, 2420 };
    for (reset_ticks) |tick_count| {
        var scene = try integrated.Scene.init(std.testing.allocator, .{});
        defer scene.deinit();
        try scene.updateFixedTicks(tick_count);
        try scene.resetAll();
        try expectReset(&scene);
    }
}

test "character local reset isolates an unrelated character and releases its interaction peer" {
    var scene = try integrated.Scene.init(std.testing.allocator, .{ .diagnostics_each_tick = false });
    defer scene.deinit();
    try scene.updateFixedTicks(400);
    while (!scene.partner.foot_plants.left.hasLock() and !scene.partner.foot_plants.right.hasLock() and scene.simulation_tick < 700) {
        try scene.updateFixedTicks(1);
    }
    const partner_state = scene.partner.animationState();
    const partner_time = scene.partner.animationTime();
    const partner_left_target = scene.partner.foot_plants.left.locked_target;
    const partner_right_target = scene.partner.foot_plants.right.locked_target;
    const partner_secondary = scene.partner.procedural.secondary_spring;
    try std.testing.expect(partner_left_target != null or partner_right_target != null);
    try scene.resetCharacter(scene.player.id);
    try std.testing.expectEqual(partner_state, scene.partner.animationState());
    try std.testing.expectEqual(partner_time, scene.partner.animationTime());
    try std.testing.expectEqualDeep(partner_left_target, scene.partner.foot_plants.left.locked_target);
    try std.testing.expectEqualDeep(partner_right_target, scene.partner.foot_plants.right.locked_target);
    try std.testing.expectEqualDeep(partner_secondary, scene.partner.procedural.secondary_spring);

    try scene.resetAll();
    try scene.updateFixedTicks(2300);
    try std.testing.expectEqual(@as(usize, 1), scene.manager.activeCount());
    try scene.resetCharacter(scene.player.id);
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeCount());
    try std.testing.expect(!scene.player.isInteractionLocked());
    try std.testing.expect(!scene.partner.isInteractionLocked());
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeOwnedOverrideCount());
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeIkConstraintCount());
}

test "integrated scenario is deterministic under three render frame grouping schedules" {
    const schedule_a = [_]f64{1.0 / 60.0};
    const schedule_b = [_]f64{ 1.0 / 120.0, 1.0 / 40.0 };
    const schedule_c = [_]f64{ 1.0 / 240.0, 7.0 / 240.0 };
    const a = try runSchedule(.{}, &schedule_a, true);
    const b = try runSchedule(.{}, &schedule_b, true);
    const c = try runSchedule(.{}, &schedule_c, true);
    try std.testing.expect(integrated.authoritativeStatesEqual(a.state, b.state, 0));
    try std.testing.expect(integrated.authoritativeStatesEqual(a.state, c.state, 0));
    try std.testing.expectEqualDeep(a.state.milestone_ticks, b.state.milestone_ticks);
    try std.testing.expectEqualDeep(a.state.milestone_ticks, c.state.milestone_ticks);
}

test "one thousand complete handshakes clean every lock override and IK constraint" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var role_a = try character.CharacterInstance.init(
        std.testing.allocator,
        try character.entityIdFromRaw(1),
        &definition,
        &animations,
        .{ .x = -1.86, .y = 1.05 },
        .right,
        0,
        null,
    );
    defer role_a.deinit();
    var role_b = try character.CharacterInstance.init(
        std.testing.allocator,
        try character.entityIdFromRaw(2),
        &definition,
        &animations,
        .{ .x = 1.86, .y = 1.05 },
        .left,
        1,
        null,
    );
    defer role_b.deinit();
    var manager = interaction_system.Manager.initWithIk(try handshake.definition(&animations));
    const participants = [_]*character.CharacterInstance{ &role_a, &role_b };
    var current_tick: u64 = 0;
    const interact_intent = input.CharacterIntent{
        .move_axis = 0,
        .jump_pressed = false,
        .jump_held = false,
        .jump_released = false,
        .interact_pressed = true,
    };
    for (0..1000) |cycle| {
        const id = (try manager.requestFromIntent(role_a.id, interact_intent, &participants, current_tick)).?;
        try std.testing.expectEqual(@as(u32, @intCast(cycle + 1)), id.raw());
        for (0..manager.definition.authoritative_duration_ticks) |_| {
            current_tick += 1;
            try manager.updateTick(current_tick, &participants);
        }
        try std.testing.expectEqual(@as(usize, 0), manager.activeCount());
        try std.testing.expect(!role_a.isInteractionLocked());
        try std.testing.expect(!role_b.isInteractionLocked());
        try std.testing.expectEqual(@as(usize, 0), role_a.overrides.activeCount());
        try std.testing.expectEqual(@as(usize, 0), role_b.overrides.activeCount());
        try std.testing.expect(!role_a.right_arm_ik.applied);
        try std.testing.expect(!role_b.right_arm_ik.applied);
        try std.testing.expect(!manager.last_terminal.?.ik.enabled);
        for (manager.last_terminal.?.event_counts) |count| try std.testing.expectEqual(@as(u8, 1), count);
    }
    try std.testing.expectEqual(@as(u64, 1000), manager.metrics.starts);
    try std.testing.expectEqual(@as(u64, 1000), manager.metrics.completions);
    try std.testing.expectEqual(@as(u32, 1000), manager.maximumIssuedId());
    try std.testing.expectEqual(@as(usize, 0), manager.activeOwnedOverrideCount());
    try std.testing.expectEqual(@as(usize, 0), manager.activeIkConstraintCount());
}

test "one hundred thousand integrated ticks remain finite bounded and repeatedly clean systems" {
    var scene = try integrated.Scene.init(std.testing.allocator, .{
        .diagnostics_each_tick = false,
        .capture_milestones = false,
    });
    defer scene.deinit();
    var fixed_ticks: u32 = 0;
    var completed_cycles: u32 = 0;
    var total_acquisitions: u64 = 0;
    var total_releases: u64 = 0;
    var maximum_slip: f32 = 0;
    var maximum_penetration: f32 = 0;
    var maximum_hover: f32 = 0;
    while (fixed_ticks < 100_000) {
        try scene.updateFixedTicks(1);
        fixed_ticks += 1;
        const controller = scene.player.controller.?.state;
        try std.testing.expect(controller.position.isFinite());
        try std.testing.expect(controller.velocity.isFinite());
        try std.testing.expect(std.math.isFinite(scene.player.procedural.landing_spring.offset));
        try std.testing.expect(std.math.isFinite(scene.player.procedural.secondary_spring.offset));
        try std.testing.expect(scene.player.foot_plants.left.pre_ik_sole.isFinite());
        try std.testing.expect(scene.player.foot_plants.left.post_ik_sole.isFinite());
        try std.testing.expect(scene.player.foot_plants.right.pre_ik_sole.isFinite());
        try std.testing.expect(scene.player.foot_plants.right.post_ik_sole.isFinite());
        if (!controller.grounded) {
            try std.testing.expect(!scene.player.foot_plants.left.hasLock());
            try std.testing.expect(!scene.player.foot_plants.right.hasLock());
        }
        if (scene.hasMilestone(.final_stable_state) and scene.phase_tick > integrated.final_stability_ticks) {
            completed_cycles += 1;
            total_acquisitions += scene.player.foot_plants.left.metrics.plant_acquisitions + scene.player.foot_plants.right.metrics.plant_acquisitions;
            total_releases += scene.player.foot_plants.left.metrics.full_releases + scene.player.foot_plants.right.metrics.full_releases;
            maximum_slip = @max(maximum_slip, @max(
                scene.player.foot_plants.left.metrics.maximum_world_space_slip,
                scene.player.foot_plants.right.metrics.maximum_world_space_slip,
            ));
            maximum_penetration = @max(maximum_penetration, @max(
                scene.player.foot_plants.left.metrics.maximum_penetration,
                scene.player.foot_plants.right.metrics.maximum_penetration,
            ));
            maximum_hover = @max(maximum_hover, @max(
                scene.player.foot_plants.left.metrics.maximum_hover,
                scene.player.foot_plants.right.metrics.maximum_hover,
            ));
            try std.testing.expectEqual(@as(usize, 0), scene.manager.activeCount());
            try std.testing.expectEqual(@as(usize, 0), scene.manager.activeOwnedOverrideCount());
            try scene.restartCyclePreservingCounters();
        }
    }
    total_acquisitions += scene.player.foot_plants.left.metrics.plant_acquisitions + scene.player.foot_plants.right.metrics.plant_acquisitions;
    total_releases += scene.player.foot_plants.left.metrics.full_releases + scene.player.foot_plants.right.metrics.full_releases;
    try std.testing.expect(completed_cycles >= 30);
    try std.testing.expect(scene.manager.metrics.starts >= 30);
    try std.testing.expect(scene.manager.metrics.completions >= 30);
    try std.testing.expect(total_acquisitions >= 200);
    try std.testing.expect(total_releases >= 160);
    try std.testing.expect(maximum_slip <= 0.0002);
    try std.testing.expect(maximum_penetration <= 0.0002);
    try std.testing.expect(maximum_hover <= 0.0002);
    try scene.resetAll();
    try expectReset(&scene);
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeOwnedOverrideCount());
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeIkConstraintCount());
    const snapshot = try scene.captureDiagnostics();
    try std.testing.expectEqual(@as(u64, 0), snapshot.allocations.total());
    try std.testing.expectEqual(@as(u64, 0), snapshot.resources.gpu_resources_created_lifetime);
}
