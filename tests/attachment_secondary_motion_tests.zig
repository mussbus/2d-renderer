const std = @import("std");
const math = @import("math");
const secondary = @import("attachment_secondary_motion");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const state_machine = @import("state_machine");
const queue_module = @import("render_queue");
const mesh_demo = @import("mesh_attachment_demo");
const attachment_meshes = @import("attachment_meshes");
const character = @import("character");

const test_definition = secondary.Definition{
    .dynamic_point_count = 3,
    .rest_offsets = .{
        .{ .x = 0, .y = -0.3 },
        .{ .x = 0, .y = -0.6 },
        .{ .x = 0, .y = -0.9 },
        math.Vec2.zero,
    },
    .spring_configuration = .{
        .stiffness = 96,
        .damping = 17,
        .maximum_displacement = 0.40,
        .maximum_velocity = 6.0,
    },
    .acceleration_response = .{ .x = 0.008, .y = 0.008 },
    .velocity_response = .{ .x = 0.030, .y = 0.020 },
    .chain_follow = 0.35,
    .landing_impulse_scale = 0.10,
    .output_translation_scale = 0.35,
    .maximum_rotation_radians = 0.55,
};

test "bounded attachment definition validates rest layout finite values and stable extremes" {
    try test_definition.validate();

    var invalid = test_definition;
    invalid.dynamic_point_count = 0;
    try std.testing.expectError(error.InvalidSecondaryPointCount, invalid.validate());
    invalid = test_definition;
    invalid.rest_offsets[1] = invalid.rest_offsets[0];
    try std.testing.expectError(error.InvalidSecondaryRestOffset, invalid.validate());
    invalid = test_definition;
    invalid.gravity_displacement.x = std.math.nan(f32);
    try std.testing.expectError(error.NonFiniteSecondaryDefinition, invalid.validate());
    invalid = test_definition;
    invalid.chain_follow = 1.01;
    try std.testing.expectError(error.InvalidSecondaryResponse, invalid.validate());
    invalid = test_definition;
    invalid.spring_configuration.stiffness = 60_000;
    try std.testing.expectError(error.UnstableSecondaryConfiguration, invalid.validate());

    const extreme = secondary.Definition{
        .dynamic_point_count = 4,
        .rest_offsets = .{
            .{ .x = 0.1, .y = -0.2 },
            .{ .x = 0.2, .y = -0.4 },
            .{ .x = 0.3, .y = -0.6 },
            .{ .x = 0.4, .y = -0.8 },
        },
        .spring_configuration = .{
            .stiffness = 50_000,
            .damping = 450,
            .maximum_displacement = 1.0,
            .maximum_velocity = 1_000,
        },
        .gravity_displacement = .{ .x = 0.9, .y = -0.4 },
        .acceleration_response = .{ .x = 0.02, .y = 0.02 },
        .velocity_response = .{ .x = 0.04, .y = 0.04 },
        .chain_follow = 1,
        .landing_impulse_scale = 2,
        .output_translation_scale = 1,
        .maximum_rotation_radians = std.math.pi,
    };
    try extreme.validate();
    var state = secondary.RuntimeState{};
    try state.step(extreme, .{
        .anchor_world = .{ .x = 1, .y = 2 },
        .linear_velocity_world = .{ .x = 500, .y = -500 },
    });
    for (0..4) |tick| {
        try state.step(extreme, .{
            .anchor_world = .{ .x = 1, .y = 2 },
            .linear_velocity_world = .{ .x = if (tick % 2 == 0) 500 else -500, .y = 500 },
            .linear_acceleration_world = .{ .x = 20_000, .y = -20_000 },
            .landing_velocity_impulse_world = .{ .x = 300, .y = -300 },
        });
        try std.testing.expect(state.isFiniteAndBounded(extreme));
        try std.testing.expect((try state.resolvedTransform(extreme)).isFinite());
    }
}

test "rest acceleration sustained reversal stop jump fall landing facing and reset are deterministic" {
    var state = secondary.RuntimeState{};
    const rest_input = secondary.TickInput{ .anchor_world = .{ .x = 2, .y = 3 } };
    try state.step(test_definition, rest_input);
    try std.testing.expect((try state.displacement(test_definition, 2)).approxEqAbs(math.Vec2.zero, 0));
    try std.testing.expect((try state.resolvedPointWorld(test_definition, 2)).approxEqAbs(.{ .x = 2, .y = 2.1 }, 0.000001));

    for (0..30) |_| {
        try state.step(test_definition, .{
            .anchor_world = rest_input.anchor_world,
            .linear_velocity_world = .{ .x = 3, .y = 0 },
            .linear_acceleration_world = .{ .x = 40, .y = 0 },
        });
    }
    try std.testing.expect((try state.displacement(test_definition, 2)).x < 0);

    for (0..90) |_| {
        try state.step(test_definition, .{
            .anchor_world = rest_input.anchor_world,
            .linear_velocity_world = .{ .x = 3, .y = 0 },
            .linear_acceleration_world = math.Vec2.zero,
        });
    }
    try std.testing.expect((try state.displacement(test_definition, 2)).x < 0);

    for (0..120) |_| {
        try state.step(test_definition, .{
            .anchor_world = rest_input.anchor_world,
            .linear_velocity_world = .{ .x = -3, .y = 0 },
            .linear_acceleration_world = .{ .x = -40, .y = 0 },
        });
    }
    try std.testing.expect(state.points[2].horizontal.target_offset > 0);
    try std.testing.expect((try state.displacement(test_definition, 2)).x > 0);

    try state.step(test_definition, .{
        .anchor_world = rest_input.anchor_world,
        .linear_acceleration_world = .{ .x = 40, .y = 0 },
    });
    try std.testing.expect(state.points[2].horizontal.target_offset < 0);

    try state.reset(test_definition, rest_input);
    for (0..20) |_| {
        try state.step(test_definition, .{
            .anchor_world = rest_input.anchor_world,
            .linear_velocity_world = .{ .x = 0, .y = 4 },
            .linear_acceleration_world = .{ .x = 0, .y = 40 },
        });
    }
    try std.testing.expect(state.points[2].vertical.target_offset < 0);

    for (0..20) |_| {
        try state.step(test_definition, .{
            .anchor_world = rest_input.anchor_world,
            .linear_velocity_world = .{ .x = 0, .y = -5 },
            .linear_acceleration_world = .{ .x = 0, .y = -40 },
        });
    }
    try std.testing.expect(state.points[2].vertical.target_offset > 0);

    try state.reset(test_definition, rest_input);
    try state.step(test_definition, .{
        .anchor_world = rest_input.anchor_world,
        .landing_velocity_impulse_world = .{ .x = 0, .y = -5 },
    });
    try std.testing.expect(state.points[2].vertical.velocity < 0);

    const resets_before_facing = state.reset_count;
    try state.step(test_definition, .{
        .anchor_world = rest_input.anchor_world,
        .linear_velocity_world = .{ .x = -2, .y = 0 },
        .facing = .left,
    });
    try std.testing.expectEqual(resets_before_facing + 1, state.reset_count);
    try std.testing.expect((try state.displacement(test_definition, 2)).approxEqAbs(math.Vec2.zero, 0));
    try std.testing.expect((try state.resolvedPointWorld(test_definition, 2)).isFinite());

    try state.reset(test_definition, rest_input);
    const first_reset = state;
    try state.step(test_definition, .{
        .anchor_world = rest_input.anchor_world,
        .linear_velocity_world = .{ .x = 4, .y = 0 },
        .linear_acceleration_world = .{ .x = 20, .y = 0 },
    });
    try state.reset(test_definition, rest_input);
    var expected_reset = first_reset;
    expected_reset.reset_count = state.reset_count;
    try expectRuntimeEqual(expected_reset, state, test_definition);
}

test "shared immutable definition gives independent states deterministic replay and long-run convergence" {
    var first = secondary.RuntimeState{};
    var second = secondary.RuntimeState{};
    const initial = secondary.TickInput{ .anchor_world = math.Vec2.zero };
    try first.step(test_definition, initial);
    try second.step(test_definition, initial);
    for (0..600) |tick| {
        const velocity = math.Vec2{
            .x = if ((tick / 75) % 2 == 0) 3 else -2,
            .y = if (tick > 250 and tick < 330) -4 else 0,
        };
        const input_value = secondary.TickInput{
            .anchor_world = .{ .x = 1, .y = 2 },
            .linear_velocity_world = velocity,
            .landing_velocity_impulse_world = if (tick == 340) .{ .x = 0, .y = -5 } else math.Vec2.zero,
        };
        try first.step(test_definition, input_value);
        try second.step(test_definition, input_value);
        try expectRuntimeEqual(first, second, test_definition);
    }

    var independent = secondary.RuntimeState{};
    try independent.step(test_definition, initial);
    for (0..60) |_| {
        try independent.step(test_definition, .{
            .anchor_world = math.Vec2.zero,
            .linear_velocity_world = .{ .x = -3, .y = 0 },
            .linear_acceleration_world = .{ .x = -30, .y = 0 },
        });
    }
    try std.testing.expect((try first.displacement(test_definition, 2)).x !=
        (try independent.displacement(test_definition, 2)).x);

    for (0..24_000) |_| {
        try first.step(test_definition, .{
            .anchor_world = math.Vec2.zero,
            .linear_acceleration_world = math.Vec2.zero,
        });
    }
    const final_displacement = try first.displacement(test_definition, 2);
    try std.testing.expect(@abs(final_displacement.x) < 0.00001);
    try std.testing.expect(@abs(final_displacement.y) < 0.00001);
    try std.testing.expect(first.isFiniteAndBounded(test_definition));
}

test "equipment and hair instances own lifecycle state independently and preserve grouped rendering" {
    const storage = try std.testing.allocator.alloc(u8, 4 * 1024 * 1024);
    defer std.testing.allocator.free(storage);
    var fixed = std.heap.FixedBufferAllocator.init(storage);
    var scene = try mesh_demo.Scene.init(fixed.allocator());
    defer scene.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(fixed.allocator(), 256, 224, 32, 1);
    defer queue.deinit();
    const stabilized_bytes = fixed.end_index;
    queue.markStabilized();

    try scene.conventional.advanceVisualTick(.{
        .horizontal_velocity = 4,
        .vertical_velocity = 2,
        .physically_grounded = false,
    });
    try scene.nonstandard.advanceVisualTick(.{
        .horizontal_velocity = -1,
        .vertical_velocity = -3,
        .physically_grounded = false,
    });
    for (0..40) |_| {
        try scene.conventional.advanceVisualTick(.{ .horizontal_velocity = 4 });
        try scene.nonstandard.advanceVisualTick(.{ .horizontal_velocity = -1 });
    }

    const conventional_cape = try scene.equipmentSecondaryState(&scene.conventional, "cape_mesh");
    const nonstandard_cape = try scene.equipmentSecondaryState(&scene.nonstandard, "cape_mesh");
    try std.testing.expect(conventional_cape != nonstandard_cape);
    try std.testing.expect(!(try conventional_cape.displacement(attachment_meshes.cape_secondary_motion, 2)).approxEqAbs(
        try nonstandard_cape.displacement(attachment_meshes.cape_secondary_motion, 2),
        0.000001,
    ));

    const cape_item = try scene.equipment_definition.itemId("upper_back_cape");
    try scene.conventional.unequipItem(cape_item);
    try std.testing.expectError(
        error.MissingEquipmentVisual,
        scene.equipmentSecondaryState(&scene.conventional, "cape_mesh"),
    );
    try scene.conventional.equipItem(cape_item);
    const reequipped = try scene.equipmentSecondaryState(&scene.conventional, "cape_mesh");
    try std.testing.expect(!reequipped.initialized);
    try scene.conventional.advanceVisualTick(.{ .horizontal_velocity = 4 });
    const initialized = try scene.equipmentSecondaryState(&scene.conventional, "cape_mesh");
    try std.testing.expect(initialized.initialized);
    try std.testing.expect((try initialized.displacement(attachment_meshes.cape_secondary_motion, 2)).approxEqAbs(math.Vec2.zero, 0));

    const sleeve_component = try scene.equipment_definition.visualComponentId("topology_sleeve_mesh");
    var sleeve_indices: [mesh_demo.expected_conventional_sleeves]usize = undefined;
    var sleeve_count: usize = 0;
    const internal = character.testing.state(&scene.conventional);
    const loadout = &internal.equipment_loadout.?;
    for (loadout.visuals(), 0..) |visual, index| {
        const recipe = try loadout.definition.recipe(visual.recipe);
        if (recipe.component == sleeve_component) {
            sleeve_indices[sleeve_count] = index;
            sleeve_count += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, mesh_demo.expected_conventional_sleeves), sleeve_count);
    const first_sleeve = &internal.equipment_loadout.?.resolved_visuals[sleeve_indices[0]].secondary;
    const second_sleeve = &internal.equipment_loadout.?.resolved_visuals[sleeve_indices[1]].secondary;
    try std.testing.expect(first_sleeve != second_sleeve);
    try first_sleeve.step(attachment_meshes.loose_sleeve_secondary_motion, .{
        .anchor_world = math.Vec2.zero,
        .linear_acceleration_world = .{ .x = 40, .y = 0 },
    });
    try std.testing.expect(!(try first_sleeve.displacement(attachment_meshes.loose_sleeve_secondary_motion, 1)).approxEqAbs(
        try second_sleeve.displacement(attachment_meshes.loose_sleeve_secondary_motion, 1),
        0.000001,
    ));

    queue.beginFrame();
    _ = try scene.submit(&queue);
    const prepared = queue.prepare();
    try std.testing.expect(prepared.meshes.len > 0);
    try std.testing.expect(prepared.mesh_draws.len < prepared.meshes.len);
    for (prepared.meshes) |submission| {
        try std.testing.expect(gpuInstanceFinite(submission.gpu_instance));
    }

    for (0..120) |_| {
        try scene.conventional.advanceVisualTick(.{});
        try scene.nonstandard.advanceVisualTick(.{});
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
    }
    try std.testing.expectEqual(stabilized_bytes, fixed.end_index);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}

test "visual secondary motion leaves controller physics and interaction authority invariant" {
    var scene = try mesh_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    character.testing.state(&scene.conventional).controller = try character_controller.CharacterController.init(
        .{},
        &world,
        .{ .x = -4, .y = 1.05 },
        .right,
    );
    const controller_before = scene.conventional.controllerSnapshot().?.state;
    const world_position_before = scene.conventional.worldPosition();
    try scene.conventional.advanceVisualTick(.{
        .horizontal_velocity = 4,
        .vertical_velocity = -3,
        .physically_grounded = false,
        .landing_event = .{ .simulation_tick = 1, .impact_speed = 6 },
    });
    try std.testing.expect(std.meta.eql(controller_before, scene.conventional.controllerSnapshot().?.state));
    try std.testing.expect(world_position_before.approxEqAbs(scene.conventional.worldPosition(), 0));

    try scene.conventional.reserveInteraction(77);
    const interaction_owner_before = scene.conventional.interactionOwnerId();
    const controller_before_interaction = scene.conventional.controllerSnapshot().?.state;
    try scene.conventional.enterAnimationState(state_machine.StateId.handshake_role_a);
    try scene.conventional.sampleInteractionAnimation(state_machine.StateId.handshake_role_a, 0.2);
    try std.testing.expectEqual(interaction_owner_before, scene.conventional.interactionOwnerId());
    try std.testing.expect(scene.conventional.isInteractionLocked());
    try std.testing.expect(std.meta.eql(controller_before_interaction, scene.conventional.controllerSnapshot().?.state));
    try std.testing.expect(world_position_before.approxEqAbs(scene.conventional.worldPosition(), 0));
}

test "scripted modular attachment demonstration completes with stable resources" {
    const storage = try std.testing.allocator.alloc(u8, 4 * 1024 * 1024);
    defer std.testing.allocator.free(storage);
    var fixed = std.heap.FixedBufferAllocator.init(storage);
    var scene = try mesh_demo.Scene.init(fixed.allocator());
    defer scene.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(fixed.allocator(), 256, 224, 32, 1);
    defer queue.deinit();
    const stabilized_bytes = fixed.end_index;
    queue.markStabilized();

    for (0..mesh_demo.required_frames) |frame| {
        try scene.updateFrame(@intCast(frame));
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
    }
    try scene.validateComplete();
    try std.testing.expectEqual(stabilized_bytes, fixed.end_index);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}

fn expectRuntimeEqual(
    expected: secondary.RuntimeState,
    actual: secondary.RuntimeState,
    definition: secondary.Definition,
) !void {
    try std.testing.expectEqual(expected.initialized, actual.initialized);
    try std.testing.expectEqual(expected.facing, actual.facing);
    try std.testing.expect(expected.anchor_world.approxEqAbs(actual.anchor_world, 0));
    try std.testing.expect(expected.previous_linear_velocity_world.approxEqAbs(actual.previous_linear_velocity_world, 0));
    try std.testing.expectEqual(expected.fixed_ticks, actual.fixed_ticks);
    try std.testing.expectEqual(expected.reset_count, actual.reset_count);
    for (0..definition.dynamic_point_count) |index| {
        try std.testing.expectEqual(expected.points[index].horizontal.offset, actual.points[index].horizontal.offset);
        try std.testing.expectEqual(expected.points[index].horizontal.velocity, actual.points[index].horizontal.velocity);
        try std.testing.expectEqual(expected.points[index].horizontal.target_offset, actual.points[index].horizontal.target_offset);
        try std.testing.expectEqual(expected.points[index].vertical.offset, actual.points[index].vertical.offset);
        try std.testing.expectEqual(expected.points[index].vertical.velocity, actual.points[index].vertical.velocity);
        try std.testing.expectEqual(expected.points[index].vertical.target_offset, actual.points[index].vertical.target_offset);
    }
}

fn gpuInstanceFinite(instance: @import("deformable_mesh").GpuInstance) bool {
    const values = [_]f32{
        instance.world_column_0[0],
        instance.world_column_0[1],
        instance.world_column_1[0],
        instance.world_column_1[1],
        instance.world_translation[0],
        instance.world_translation[1],
        instance.deformation_translation[0],
        instance.deformation_translation[1],
        instance.deformation_rotation,
        instance.deformation_scale[0],
        instance.deformation_scale[1],
        instance.tint[0],
        instance.tint[1],
        instance.tint[2],
        instance.tint[3],
        instance.camera_x_factor,
    };
    for (values) |value| if (!std.math.isFinite(value)) return false;
    return true;
}
