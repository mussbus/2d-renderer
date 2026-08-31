const std = @import("std");
const input = @import("input");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const integrated = @import("integrated_demo");
const support = @import("integration_test_support.zig");

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
        const id = (try manager.requestFromIntent(role_a.id(), interact_intent, &participants, current_tick)).?;
        try std.testing.expectEqual(@as(u32, @intCast(cycle + 1)), id.raw());
        for (0..manager.definitionView().authoritative_duration_ticks) |_| {
            current_tick += 1;
            try manager.updateTick(current_tick, &participants);
        }
        try std.testing.expectEqual(@as(usize, 0), manager.activeCount());
        try std.testing.expect(!role_a.isInteractionLocked());
        try std.testing.expect(!role_b.isInteractionLocked());
        try std.testing.expectEqual(@as(usize, 0), role_a.activeOverrideCount());
        try std.testing.expectEqual(@as(usize, 0), role_b.activeOverrideCount());
        try std.testing.expect(role_a.rightHandIkMetrics() == null);
        try std.testing.expect(role_b.rightHandIkMetrics() == null);
        try std.testing.expect(!manager.lastTerminal().?.ik.enabled);
        for (manager.lastTerminal().?.event_counts) |count| try std.testing.expectEqual(@as(u8, 1), count);
    }
    try std.testing.expectEqual(@as(u64, 1000), manager.metricsSnapshot().starts);
    try std.testing.expectEqual(@as(u64, 1000), manager.metricsSnapshot().completions);
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
        const controller = scene.player.controllerSnapshot().?.state;
        try std.testing.expect(controller.position.isFinite());
        try std.testing.expect(controller.velocity.isFinite());
        const procedural = scene.player.proceduralSnapshot();
        const planting = scene.player.footPlantingSnapshot();
        try std.testing.expect(std.math.isFinite(procedural.landing_spring.offset));
        try std.testing.expect(std.math.isFinite(procedural.secondary_spring.offset));
        try std.testing.expect(planting.left.pre_ik_sole.isFinite());
        try std.testing.expect(planting.left.post_ik_sole.isFinite());
        try std.testing.expect(planting.right.pre_ik_sole.isFinite());
        try std.testing.expect(planting.right.post_ik_sole.isFinite());
        if (!controller.grounded) {
            try std.testing.expect(!planting.left.hasLock());
            try std.testing.expect(!planting.right.hasLock());
        }
        if (scene.hasMilestone(.final_stable_state) and scene.phase_tick > integrated.final_stability_ticks) {
            completed_cycles += 1;
            total_acquisitions += planting.left.metrics.plant_acquisitions + planting.right.metrics.plant_acquisitions;
            total_releases += planting.left.metrics.full_releases + planting.right.metrics.full_releases;
            maximum_slip = @max(maximum_slip, @max(
                planting.left.metrics.maximum_world_space_slip,
                planting.right.metrics.maximum_world_space_slip,
            ));
            maximum_penetration = @max(maximum_penetration, @max(
                planting.left.metrics.maximum_penetration,
                planting.right.metrics.maximum_penetration,
            ));
            maximum_hover = @max(maximum_hover, @max(
                planting.left.metrics.maximum_hover,
                planting.right.metrics.maximum_hover,
            ));
            try std.testing.expectEqual(@as(usize, 0), scene.manager.activeCount());
            try std.testing.expectEqual(@as(usize, 0), scene.manager.activeOwnedOverrideCount());
            try scene.restartCyclePreservingCounters();
        }
    }
    const final_planting = scene.player.footPlantingSnapshot();
    total_acquisitions += final_planting.left.metrics.plant_acquisitions + final_planting.right.metrics.plant_acquisitions;
    total_releases += final_planting.left.metrics.full_releases + final_planting.right.metrics.full_releases;
    try std.testing.expect(completed_cycles >= 30);
    try std.testing.expect(scene.manager.metricsSnapshot().starts >= 30);
    try std.testing.expect(scene.manager.metricsSnapshot().completions >= 30);
    try std.testing.expect(total_acquisitions >= 200);
    try std.testing.expect(total_releases >= 160);
    try std.testing.expect(maximum_slip <= 0.0002);
    try std.testing.expect(maximum_penetration <= 0.0002);
    try std.testing.expect(maximum_hover <= 0.0002);
    try scene.resetAll();
    try support.expectReset(&scene);
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeOwnedOverrideCount());
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeIkConstraintCount());
    const snapshot = try scene.captureDiagnostics();
    try std.testing.expectEqual(@as(u64, 0), snapshot.allocations.total());
    try std.testing.expectEqual(@as(u64, 0), snapshot.resources.gpu_resources_created_lifetime);
}
