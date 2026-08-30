const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const anatomy = @import("anatomy");
const equipment = @import("equipment");
const equipment_demo = @import("equipment_demo");
const equipment_catalog = @import("equipment_catalog");
const modular_humanoid = @import("modular_humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const handshake = @import("handshake");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");

const tolerance: f32 = 1e-5;

test "breathing validates configuration and samples neutral extrema reset and repeated cycles" {
    try std.testing.expectError(error.InvalidBreathingPeriod, deformation.BreathingConfiguration.init(3, 0.5));
    try std.testing.expectError(error.InvalidBreathingAmplitude, deformation.BreathingConfiguration.init(240, 1.01));
    try std.testing.expectError(error.InvalidBreathingRate, deformation.BreathingConfiguration.fromRateHz(0, 0.5));
    try std.testing.expectError(error.BreathingRateNotTickRepresentable, deformation.BreathingConfiguration.fromRateHz(0.7, 0.5));
    try std.testing.expectError(error.InvalidDeformationResponse, (deformation.Response{ .morphology = 1.1 }).validate());
    try std.testing.expectError(error.InvalidBreathingScaleRange, (deformation.BreathingBinding{
        .scale_delta_at_unit = .{ .x = 1, .y = 0 },
    }).validate());

    const configuration = try deformation.BreathingConfiguration.init(240, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 1), configuration.rateHz(), tolerance);
    var state = try deformation.BreathingState.init(configuration);
    try std.testing.expectApproxEqAbs(@as(f32, 0), try state.sample(), tolerance);

    for (0..60) |_| try state.advance();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), try state.sample(), tolerance);
    for (0..60) |_| try state.advance();
    try std.testing.expectApproxEqAbs(@as(f32, 0), try state.sample(), tolerance);
    for (0..60) |_| try state.advance();
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), try state.sample(), tolerance);
    for (0..60) |_| try state.advance();
    try std.testing.expectEqual(@as(u32, 0), state.cycle_tick);
    try std.testing.expectApproxEqAbs(@as(f32, 0), try state.sample(), tolerance);

    for (0..10_000 * 240) |_| try state.advance();
    try std.testing.expectEqual(@as(u32, 0), state.cycle_tick);
    state.setPhaseTick(61) catch return error.UnexpectedBreathingPhaseFailure;
    state.reset();
    try std.testing.expectEqual(@as(u32, 0), state.cycle_tick);
}

test "independent breathing states keep phase rate and amplitude character local" {
    var slow = try deformation.BreathingState.init(try deformation.BreathingConfiguration.init(960, 0.8));
    var fast = try deformation.BreathingState.init(try deformation.BreathingConfiguration.init(480, 0.35));
    try fast.setPhaseTick(120);
    for (0..120) |_| {
        try slow.advance();
        try fast.advance();
    }
    try std.testing.expectEqual(@as(u32, 120), slow.cycle_tick);
    try std.testing.expectEqual(@as(u32, 240), fast.cycle_tick);
    const quarter_pi: f32 = std.math.pi / 4.0;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8) * @sin(quarter_pi), try slow.sample(), tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0), try fast.sample(), tolerance);
    try slow.setPhaseTick(17);
    try std.testing.expectEqual(@as(u32, 240), fast.cycle_tick);
}

test "resolved deformation composes global morphology breathing and per visual response once" {
    const base = math.Transform2D.init(
        .{ .x = 0.2, .y = -0.1 },
        0.3,
        .{ .x = 1.2, .y = 0.8 },
    );
    const binding = deformation.BreathingBinding{
        .translation_at_unit = .{ .x = 0.04, .y = 0.02 },
        .rotation_at_unit = 0.1,
        .scale_delta_at_unit = .{ .x = 0.05, .y = 0.02 },
    };
    const resolved = try deformation.resolve(.{
        .base_morphology = base,
        .breathing_binding = binding,
        .breathing_sample = 0.5,
        .response = .{ .morphology = 0.5, .breathing = 0.8 },
    });
    try std.testing.expect(resolved.translation.approxEqAbs(.{ .x = 0.116, .y = -0.042 }, tolerance));
    try std.testing.expectApproxEqAbs(@as(f32, 0.19), resolved.rotation_radians, tolerance);
    try std.testing.expect(resolved.scale.approxEqAbs(.{ .x = 1.122, .y = 0.9072 }, tolerance));

    const rigid = try deformation.resolve(.{
        .base_morphology = base,
        .breathing_binding = binding,
        .breathing_sample = -0.75,
        .response = .{ .morphology = 0, .breathing = 0 },
    });
    try std.testing.expect(rigid.approxEqAbs(math.Transform2D.identity(), 0));
}

test "topology generated clothing follows exact bound instances with isolated overrides and rigid opt out" {
    var scene = try equipment_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    const configuration = try deformation.BreathingConfiguration.init(240, 1);
    try scene.four_arm.configureBreathing(configuration);
    try scene.four_arm.setBreathingPhaseTick(60);

    const torso_id = try anatomy_definition.partInstanceId("torso");
    const torso_visual_id = try scene.definition.visual_definition.visualId("torso");
    const anatomy_runtime = &scene.four_arm.character.anatomy_runtime.?;
    const appearance_definition = scene.definition.visual_definition.view();
    const full_torso = try anatomy_runtime.resolvedDeformationForPart(anatomy_definition, torso_id, .{});
    const skin_torso = scene.four_arm.character.appearance_runtime.visual_states[torso_visual_id.index()].local_deformation;
    try std.testing.expect(full_torso.approxEqAbs(skin_torso, tolerance));

    const long_sleeve = try scene.equipment_definition.visualComponentId("long_sleeve");
    var sleeve_indices: [4]usize = undefined;
    var sleeve_parts: [4]anatomy.BodyPartInstanceId = undefined;
    var sleeve_world_before: [4]math.Mat3 = undefined;
    var sleeve_count: usize = 0;
    for (scene.four_arm.equipment_loadout.?.visuals(), 0..) |visual, index| {
        const recipe = try scene.four_arm.equipment_loadout.?.definition.recipe(visual.recipe);
        if (recipe.component != long_sleeve) continue;
        if (sleeve_count >= sleeve_indices.len) return error.UnexpectedSleeveCount;
        const part_id = switch (visual.source) {
            .anatomy_part => |value| value,
            .attachment_point => return error.SleeveLostAnatomyBinding,
        };
        for (sleeve_parts[0..sleeve_count]) |existing| {
            try std.testing.expect(existing != part_id);
        }
        sleeve_indices[sleeve_count] = index;
        sleeve_parts[sleeve_count] = part_id;
        sleeve_world_before[sleeve_count] = try scene.four_arm.equipmentVisualWorld(index);
        const component = scene.four_arm.equipment_loadout.?.definition.visual_components[recipe.component.index()];
        const expected = (try anatomy_runtime.partBindingWorld(anatomy_definition, part_id))
            .mul(try recipe.local_to_binding.localToParent())
            .mul(try (try anatomy_runtime.resolvedDeformationForPart(
            anatomy_definition,
            part_id,
            component.deformation_response,
        )).localToParent());
        try std.testing.expect(expected.approxEqAbs(sleeve_world_before[sleeve_count], tolerance));
        sleeve_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 4), sleeve_count);

    const changed_part = try anatomy_definition.partInstanceId("extra_arm");
    const thickness = try anatomy_definition.morphologyChannelId("upper_arm_thickness");
    try scene.four_arm.setPartMorphologyOverride(changed_part, thickness, 100);
    var changed_count: usize = 0;
    for (sleeve_indices, sleeve_parts, sleeve_world_before) |index, part_id, before| {
        const after = try scene.four_arm.equipmentVisualWorld(index);
        if (part_id == changed_part) {
            try std.testing.expect(!before.approxEqAbs(after, tolerance));
            changed_count += 1;
        } else {
            try std.testing.expect(before.approxEqAbs(after, tolerance));
        }
    }
    try std.testing.expectEqual(@as(usize, 1), changed_count);

    const tail_id = try anatomy_definition.partInstanceId("tail");
    const tail_at_inhale = try anatomy_runtime.resolvedDeformationForPart(anatomy_definition, tail_id, .{});
    try scene.four_arm.setBreathingPhaseTick(180);
    const tail_at_exhale = try anatomy_runtime.resolvedDeformationForPart(anatomy_definition, tail_id, .{});
    try std.testing.expect(tail_at_inhale.approxEqAbs(tail_at_exhale, tolerance));

    const gauntlet = try scene.equipment_definition.itemId("left_gauntlet");
    try scene.four_arm.equipItem(gauntlet);
    const gauntlet_component = try scene.equipment_definition.visualComponentId("gauntlet");
    const left_hand = try anatomy_definition.partInstanceId("left_hand");
    const gauntlet_index = try findEquipmentVisual(&scene.four_arm, gauntlet_component, left_hand);
    const gauntlet_before = try scene.four_arm.equipmentVisualWorld(gauntlet_index);
    const hand_scale = try anatomy_definition.morphologyChannelId("hand_scale");
    try scene.four_arm.setPartMorphologyOverride(left_hand, hand_scale, 100);
    const gauntlet_after = try scene.four_arm.equipmentVisualWorld(gauntlet_index);
    try std.testing.expect(gauntlet_before.approxEqAbs(gauntlet_after, tolerance));

    const sweatshirt = try scene.equipment_definition.itemId("long_sleeve_sweatshirt");
    const sweatshirt_torso = try scene.equipment_definition.visualComponentId("sweatshirt_torso");
    const torso_index_before = try findEquipmentVisual(&scene.four_arm, sweatshirt_torso, torso_id);
    const sweatshirt_world_before = try scene.four_arm.equipmentVisualWorld(torso_index_before);
    const phase_before = try scene.four_arm.breathingSample();
    try scene.four_arm.unequipItem(sweatshirt);
    try scene.four_arm.equipItem(sweatshirt);
    const torso_index_after = try findEquipmentVisual(&scene.four_arm, sweatshirt_torso, torso_id);
    const sweatshirt_world_after = try scene.four_arm.equipmentVisualWorld(torso_index_after);
    try std.testing.expect(sweatshirt_world_before.approxEqAbs(sweatshirt_world_after, tolerance));
    try std.testing.expectApproxEqAbs(phase_before, try scene.four_arm.breathingSample(), 0);
    _ = appearance_definition;
}

test "breathing and morph changes preserve physics controller canonical IK and declared effects" {
    const floor_input = [_]collider.StaticColliderInput{.{
        .id = 1,
        .bounds = .{ .minimum = .{ .x = -10, .y = -1 }, .maximum = .{ .x = 10, .y = 0 } },
    }};
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &floor_input, null);
    defer world.deinit();
    var definition = try modular_humanoid.initDefinition(std.testing.allocator);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var instance = try character.CharacterInstance.initControlled(
        std.testing.allocator,
        try character.entityIdFromRaw(1),
        &definition,
        &animations,
        &world,
        character_controller.Configuration{},
        .{ .x = 0, .y = 1.05 },
        .right,
        0,
        null,
    );
    defer instance.deinit();

    const controller_before = instance.controller.?.state;
    const root_before = instance.world_position;
    const collider_extents_before = instance.controller.?.configuration.collider_half_extents;
    const upper_length_before = instance.right_arm_binding.upper_length;
    const lower_length_before = instance.right_arm_binding.lower_length;
    const hand_socket_before = try instance.socketPosition(.right_hand);
    const anatomy_definition = definition.anatomy_definition.?.view();
    try instance.configureBreathing(try deformation.BreathingConfiguration.init(240, 1));
    try instance.setBreathingPhaseTick(60);
    try instance.setGlobalBuild(100);
    try instance.setPartMorphologyOverride(
        try anatomy_definition.partInstanceId("right_upper_arm"),
        try anatomy_definition.morphologyChannelId("upper_arm_thickness"),
        0,
    );

    const controller_after = instance.controller.?.state;
    try std.testing.expect(controller_before.position.approxEqAbs(controller_after.position, 0));
    try std.testing.expect(controller_before.velocity.approxEqAbs(controller_after.velocity, 0));
    try std.testing.expectEqual(controller_before.grounded, controller_after.grounded);
    try std.testing.expectEqual(controller_before.supporting_collider, controller_after.supporting_collider);
    try std.testing.expectEqual(controller_before.simulation_tick, controller_after.simulation_tick);
    try std.testing.expect(root_before.approxEqAbs(instance.world_position, 0));
    try std.testing.expect(collider_extents_before.approxEqAbs(instance.controller.?.configuration.collider_half_extents, 0));
    try std.testing.expectApproxEqAbs(upper_length_before, instance.right_arm_binding.upper_length, 0);
    try std.testing.expectApproxEqAbs(lower_length_before, instance.right_arm_binding.lower_length, 0);
    try std.testing.expect(hand_socket_before.approxEqAbs(try instance.socketPosition(.right_hand), 0));

    var equipment_definition = try equipment_catalog.initDefinition(std.testing.allocator, &definition);
    defer equipment_definition.deinit();
    try instance.initializeEquipment(equipment_definition.view());
    const modifier_before = modifierFingerprint(&instance.equipment_loadout.?);
    const capability_before = capabilityFingerprint(&instance.equipment_loadout.?);
    try instance.setBreathingPhaseTick(180);
    try instance.setGlobalBuild(20);
    try std.testing.expectEqual(modifier_before, modifierFingerprint(&instance.equipment_loadout.?));
    try std.testing.expectEqual(capability_before, capabilityFingerprint(&instance.equipment_loadout.?));
}

test "interaction event timing is invariant across breathing configurations" {
    const disabled = try runHandshakeWithBreathing(0);
    const enabled = try runHandshakeWithBreathing(1);
    try std.testing.expectEqualDeep(disabled.event_ticks, enabled.event_ticks);
    try std.testing.expectEqualDeep(disabled.event_counts, enabled.event_counts);
    try std.testing.expectEqual(disabled.lifecycle, enabled.lifecycle);
}

test "fixed tick breathing is deterministic across render frame grouping" {
    const configuration = try deformation.BreathingConfiguration.init(960, 0.7);
    var one_per_frame = try deformation.BreathingState.init(configuration);
    var grouped = try deformation.BreathingState.init(configuration);
    var zero_and_many = try deformation.BreathingState.init(configuration);
    for (0..12_345) |_| try one_per_frame.advance();
    for (0..2_469) |_| {
        for (0..5) |_| try grouped.advance();
    }
    const grouping = [_]u8{ 0, 8, 1, 0, 3, 4, 0, 7, 2 };
    var total: usize = 0;
    while (total < 12_345) {
        for (grouping) |count| {
            const remaining = 12_345 - total;
            const applied = @min(@as(usize, count), remaining);
            for (0..applied) |_| try zero_and_many.advance();
            total += applied;
            if (total == 12_345) break;
        }
    }
    try std.testing.expectEqual(one_per_frame.cycle_tick, grouped.cycle_tick);
    try std.testing.expectEqual(one_per_frame.cycle_tick, zero_and_many.cycle_tick);
    try std.testing.expectApproxEqAbs(try one_per_frame.sample(), try grouped.sample(), 0);
    try std.testing.expectApproxEqAbs(try one_per_frame.sample(), try zero_and_many.sample(), 0);
}

test "steady state breathing morphing and loadout changes do not grow character storage" {
    const backing = try std.testing.allocator.alloc(u8, 4 * 1024 * 1024);
    defer std.testing.allocator.free(backing);
    var fixed = std.heap.FixedBufferAllocator.init(backing);
    var scene = try equipment_demo.Scene.init(fixed.allocator());
    defer scene.deinit();
    try scene.two_arm.configureBreathing(try deformation.BreathingConfiguration.init(480, 0.7));
    try scene.four_arm.configureBreathing(try deformation.BreathingConfiguration.init(960, 0.9));
    const initialized_bytes = fixed.end_index;
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    const channel = try anatomy_definition.morphologyChannelId("upper_arm_thickness");
    const part = try anatomy_definition.partInstanceId("extra_arm");
    const sweatshirt = try scene.equipment_definition.itemId("long_sleeve_sweatshirt");
    for (0..1_920) |tick| {
        try scene.two_arm.advanceVisualTick(.{});
        try scene.four_arm.advanceVisualTick(.{});
        if (tick == 300) try scene.four_arm.setPartMorphologyOverride(part, channel, 90);
        if (tick == 600) try scene.four_arm.unequipItem(sweatshirt);
        if (tick == 900) try scene.four_arm.equipItem(sweatshirt);
        if (tick == 1_200) try scene.four_arm.setPartMorphologyOverride(part, channel, null);
    }
    try std.testing.expectEqual(initialized_bytes, fixed.end_index);
}

const InteractionEvidence = struct {
    event_ticks: [interaction.event_count]?u64,
    event_counts: [interaction.event_count]u8,
    lifecycle: interaction.Lifecycle,
};

fn runHandshakeWithBreathing(amplitude: f32) !InteractionEvidence {
    var scene = try equipment_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    try scene.two_arm.setWorldPosition(.{ .x = -1.86, .y = 1.05 });
    try scene.four_arm.setWorldPosition(.{ .x = 1.86, .y = 1.05 });
    try scene.two_arm.configureBreathing(try deformation.BreathingConfiguration.init(480, amplitude));
    try scene.four_arm.configureBreathing(try deformation.BreathingConfiguration.init(960, amplitude));
    try scene.four_arm.setBreathingPhaseTick(137);
    var manager = interaction_system.Manager.init(try handshake.definition(&scene.shared_animations));
    const participants = [_]*character.CharacterInstance{ &scene.two_arm, &scene.four_arm };
    const id = try manager.startPair(scene.two_arm.id, scene.four_arm.id, &participants, 0, .none);
    const duration = manager.definition.authoritative_duration_ticks;
    for (1..@as(u64, duration) + 1) |tick| try manager.updateTick(tick, &participants);
    const terminal = manager.instance(id) orelse return error.MissingTerminalInteraction;
    return .{
        .event_ticks = terminal.event_ticks,
        .event_counts = terminal.event_counts,
        .lifecycle = terminal.lifecycle,
    };
}

fn findEquipmentVisual(
    instance: *character.CharacterInstance,
    component_id: equipment.VisualComponentId,
    part_id: anatomy.BodyPartInstanceId,
) !usize {
    const loadout = if (instance.equipment_loadout) |*value| value else return error.CharacterEquipmentNotInitialized;
    for (loadout.visuals(), 0..) |visual, index| {
        const recipe = try loadout.definition.recipe(visual.recipe);
        if (recipe.component != component_id) continue;
        switch (visual.source) {
            .anatomy_part => |source_part| if (source_part == part_id) return index,
            .attachment_point => {},
        }
    }
    return error.ResolvedEquipmentVisualNotFound;
}

fn modifierFingerprint(loadout: *const equipment.Loadout) u64 {
    var hash: u64 = 14695981039346656037;
    for (loadout.modifiers()) |modifier| {
        hash = (hash ^ @as(u64, @intFromEnum(modifier.item))) *% 1099511628211;
        hash = (hash ^ @as(u64, @intFromEnum(modifier.attribute))) *% 1099511628211;
        const amount_bits: u32 = @bitCast(modifier.amount);
        hash = (hash ^ @as(u64, amount_bits)) *% 1099511628211;
    }
    return hash;
}

fn capabilityFingerprint(loadout: *const equipment.Loadout) u64 {
    var hash: u64 = 14695981039346656037;
    for (loadout.capabilities()) |capability| {
        hash = (hash ^ @as(u64, @intFromEnum(capability.item))) *% 1099511628211;
        hash = (hash ^ @as(u64, @intFromEnum(capability.capability))) *% 1099511628211;
    }
    return hash;
}
