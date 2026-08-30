const std = @import("std");
const properties = @import("character_properties");
const skeleton = @import("skeleton");
const equipment_demo = @import("equipment_demo");
const equipment_catalog = @import("equipment_catalog");
const modular_humanoid = @import("modular_humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const character_controller = @import("character_controller");
const input = @import("input");
const collider = @import("collider");
const collision_world = @import("collision_world");

const tolerance: f32 = 0.0001;

fn attribute(
    raw_id: u16,
    name: []const u8,
    base_value: f32,
    minimum: f32,
    maximum: f32,
) !properties.AttributeDefinition {
    return .{
        .id = @enumFromInt(raw_id),
        .stable_id = try skeleton.DebugName.init(name),
        .base_value = base_value,
        .minimum = minimum,
        .maximum = maximum,
    };
}

fn capability(raw_id: u16, name: []const u8, granted_by_default: bool) !properties.CapabilityDefinition {
    return .{
        .id = @enumFromInt(raw_id),
        .stable_id = try skeleton.DebugName.init(name),
        .granted_by_default = granted_by_default,
    };
}

fn intent(move_axis: f32, jump_pressed: bool, dash_pressed: bool) input.CharacterIntent {
    return .{
        .move_axis = move_axis,
        .jump_pressed = jump_pressed,
        .jump_held = jump_pressed,
        .jump_released = false,
        .dash_pressed = dash_pressed,
        .interact_pressed = false,
    };
}

fn emptyIntent() input.CharacterIntent {
    return intent(0, false, false);
}

fn floorWorld(allocator: std.mem.Allocator) !collision_world.CollisionWorld {
    const inputs = [_]collider.StaticColliderInput{.{
        .id = 1,
        .bounds = .{ .minimum = .{ .x = -100, .y = -1 }, .maximum = .{ .x = 100, .y = 0 } },
    }};
    return collision_world.CollisionWorld.init(allocator, &inputs, null);
}

test "attribute definitions modifiers and base overrides reject invalid data" {
    try std.testing.expectError(
        error.NonFiniteAttributeDefinition,
        (properties.AttributeDefinitionInput{
            .stable_id = "speed",
            .base_value = std.math.nan(f32),
            .minimum = 0,
            .maximum = 10,
        }).validate(),
    );
    try std.testing.expectError(
        error.InvalidAttributeRange,
        (properties.AttributeDefinitionInput{
            .stable_id = "speed",
            .base_value = 11,
            .minimum = 0,
            .maximum = 10,
        }).validate(),
    );
    try std.testing.expectError(error.NonFiniteAttributeModifier, properties.validateModifierAmount(.add, std.math.inf(f32)));
    try std.testing.expectError(error.InvalidMultiplicativeModifier, properties.validateModifierAmount(.multiply, -0.1));
    try std.testing.expectError(error.InvalidMultiplicativeModifier, properties.validateModifierAmount(.multiply, 17));

    const attributes = [_]properties.AttributeDefinition{
        try attribute(0, "speed", 10, 0, 100),
    };
    const capabilities = [_]properties.CapabilityDefinition{};
    try std.testing.expectError(
        error.BaseAttributeOverrideOutOfRange,
        properties.Builder.init(&attributes, &capabilities, &.{.{
            .attribute = @enumFromInt(0),
            .value = 101,
        }}),
    );
    try std.testing.expectError(
        error.DuplicateBaseAttributeOverride,
        properties.Builder.init(&attributes, &capabilities, &.{
            .{ .attribute = @enumFromInt(0), .value = 20 },
            .{ .attribute = @enumFromInt(0), .value = 30 },
        }),
    );
}

test "resolution uses deterministic additive then multiplicative stacking and clamps bounds" {
    const attributes = [_]properties.AttributeDefinition{
        try attribute(0, "speed", 10, 0, 100),
        try attribute(1, "armor", 90, 0, 100),
    };
    const capabilities = [_]properties.CapabilityDefinition{};
    const modifiers = [_]properties.Modifier{
        .{
            .source = properties.SourceId.init(2, 8),
            .source_ordinal = 0,
            .attribute = @enumFromInt(0),
            .operation = .multiply,
            .amount = 0.5,
        },
        .{
            .source = properties.SourceId.init(1, 3),
            .source_ordinal = 0,
            .attribute = @enumFromInt(0),
            .operation = .add,
            .amount = 3,
        },
        .{
            .source = properties.SourceId.init(2, 7),
            .source_ordinal = 0,
            .attribute = @enumFromInt(0),
            .operation = .multiply,
            .amount = 2,
        },
        .{
            .source = properties.SourceId.init(1, 4),
            .source_ordinal = 0,
            .attribute = @enumFromInt(0),
            .operation = .add,
            .amount = 5,
        },
        .{
            .source = properties.SourceId.init(1, 5),
            .source_ordinal = 0,
            .attribute = @enumFromInt(1),
            .operation = .add,
            .amount = 20,
        },
        .{
            .source = properties.SourceId.init(2, 6),
            .source_ordinal = 0,
            .attribute = @enumFromInt(1),
            .operation = .multiply,
            .amount = 2,
        },
    };

    var forward = try properties.Builder.init(&attributes, &capabilities, &.{});
    for (modifiers) |modifier_value| try forward.addModifier(modifier_value);
    const forward_resolved = try forward.finish();

    var reverse = try properties.Builder.init(&attributes, &capabilities, &.{});
    var index = modifiers.len;
    while (index > 0) {
        index -= 1;
        try reverse.addModifier(modifiers[index]);
    }
    const reverse_resolved = try reverse.finish();

    try std.testing.expectEqual(@as(f32, 18), try forward_resolved.value(@enumFromInt(0)));
    try std.testing.expectEqual(@as(f32, 100), try forward_resolved.value(@enumFromInt(1)));
    try std.testing.expectEqual(forward_resolved, reverse_resolved);
    try std.testing.expectEqual(@as(u16, modifiers.len), forward_resolved.applied_modifier_count);
}

test "capabilities count independent sources and removal preserves remaining grants" {
    const attributes = [_]properties.AttributeDefinition{};
    const capabilities = [_]properties.CapabilityDefinition{
        try capability(0, "double_jump", false),
        try capability(1, "dash", true),
    };
    const source_a = properties.SourceId.init(1, 10);
    const source_b = properties.SourceId.init(2, 4);
    var both = try properties.Builder.init(&attributes, &capabilities, &.{});
    try both.addCapabilityGrant(.{ .source = source_a, .capability = @enumFromInt(0) });
    try both.addCapabilityGrant(.{ .source = source_b, .capability = @enumFromInt(0) });
    try std.testing.expectError(
        error.DuplicateCapabilitySource,
        both.addCapabilityGrant(.{ .source = source_a, .capability = @enumFromInt(0) }),
    );
    const both_resolved = try both.finish();
    try std.testing.expectEqual(@as(u16, 2), try both_resolved.grantCount(@enumFromInt(0)));
    try std.testing.expect(both_resolved.hasCapability(@enumFromInt(0)));
    try std.testing.expectEqual(@as(u16, 1), try both_resolved.grantCount(@enumFromInt(1)));

    var one = try properties.Builder.init(&attributes, &capabilities, &.{});
    try one.addCapabilityGrant(.{ .source = source_b, .capability = @enumFromInt(0) });
    const one_resolved = try one.finish();
    try std.testing.expectEqual(@as(u16, 1), try one_resolved.grantCount(@enumFromInt(0)));

    var none = try properties.Builder.init(&attributes, &capabilities, &.{});
    const none_resolved = try none.finish();
    try std.testing.expect(!none_resolved.hasCapability(@enumFromInt(0)));
}

test "equipment lifecycle resolves modifiers grants replacement reset and appearance-independent state" {
    var scene = try equipment_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const definition = scene.equipment_definition.view();
    const movement_speed = try definition.attributeId("movement_speed");
    const jump_strength = try definition.attributeId("jump_strength");
    const carrying_capacity = try definition.attributeId("carrying_capacity");
    const armor = try definition.attributeId("armor");
    const damage_reduction = try definition.attributeId("physical_damage_reduction");
    const double_jump = try definition.capabilityId("double_jump");
    const dash = try definition.capabilityId("dash");

    try std.testing.expectApproxEqAbs(@as(f32, 5.175), try scene.two_arm.attributeValue(movement_speed), tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 9.45), try scene.two_arm.attributeValue(jump_strength), tolerance);
    try std.testing.expectEqual(@as(f32, 70), try scene.two_arm.attributeValue(carrying_capacity));
    try std.testing.expectEqual(@as(f32, 4), try scene.two_arm.attributeValue(armor));
    try std.testing.expect(try scene.two_arm.hasCapability(dash));
    try std.testing.expect(!try scene.two_arm.hasCapability(double_jump));

    try std.testing.expectEqual(@as(f32, 4.5), try scene.four_arm.attributeValue(movement_speed));
    try std.testing.expect(try scene.four_arm.hasCapability(double_jump));
    try std.testing.expect(!try scene.four_arm.hasCapability(dash));

    try scene.two_arm.replaceItem(try definition.itemId("spring_boots"));
    try std.testing.expectEqual(@as(f32, 4.5), try scene.two_arm.attributeValue(movement_speed));
    try std.testing.expectApproxEqAbs(@as(f32, 11.34), try scene.two_arm.attributeValue(jump_strength), tolerance);

    try scene.two_arm.replaceItem(try definition.itemId("winged_boots"));
    try scene.two_arm.replaceItem(try definition.itemId("feather_amulet"));
    try std.testing.expectEqual(@as(u16, 2), try scene.two_arm.capabilityGrantCount(double_jump));
    try std.testing.expect(!try scene.two_arm.hasCapability(dash));
    try scene.two_arm.unequipItem(try definition.itemId("winged_boots"));
    try std.testing.expectEqual(@as(u16, 1), try scene.two_arm.capabilityGrantCount(double_jump));
    try scene.two_arm.unequipItem(try definition.itemId("feather_amulet"));
    try std.testing.expect(!try scene.two_arm.hasCapability(double_jump));

    try scene.four_arm.equipItem(try definition.itemId("left_shoulder_armor"));
    try std.testing.expectEqual(@as(f32, 8), try scene.four_arm.attributeValue(armor));
    try scene.four_arm.replaceItem(try definition.itemId("full_plate_armor"));
    try std.testing.expectEqual(@as(f32, 25), try scene.four_arm.attributeValue(armor));
    try std.testing.expectApproxEqAbs(@as(f32, 0.20), try scene.four_arm.attributeValue(damage_reduction), tolerance);
    try scene.four_arm.unequipItem(try definition.itemId("full_plate_armor"));
    try std.testing.expectEqual(@as(f32, 0), try scene.four_arm.attributeValue(damage_reduction));

    try scene.two_arm.reset();
    try std.testing.expectEqual(@as(f32, 4.5), try scene.two_arm.attributeValue(movement_speed));
    try std.testing.expectEqual(@as(f32, 9), try scene.two_arm.attributeValue(jump_strength));
    try std.testing.expectEqual(@as(f32, 50), try scene.two_arm.attributeValue(carrying_capacity));
    try std.testing.expectEqual(@as(f32, 0), try scene.two_arm.attributeValue(armor));
    try std.testing.expect(!try scene.two_arm.hasCapability(double_jump));
    try std.testing.expect(!try scene.two_arm.hasCapability(dash));

    const attributes_before_appearance_change = scene.two_arm.resolved_properties.?;
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    try scene.two_arm.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_female"));
    try std.testing.expectEqual(attributes_before_appearance_change, scene.two_arm.resolved_properties.?);
    try std.testing.expectEqual(@as(f32, 4.5), try scene.four_arm.attributeValue(movement_speed));
}

test "resolved equipment properties drive movement jump double jump and dash through the controller" {
    var definition = try modular_humanoid.initDefinition(std.testing.allocator);
    defer definition.deinit();
    var equipment_definition = try equipment_catalog.initDefinition(std.testing.allocator, &definition);
    defer equipment_definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var world = try floorWorld(std.testing.allocator);
    defer world.deinit();
    var controlled = try character.CharacterInstance.initControlled(
        std.testing.allocator,
        try character.entityIdFromRaw(1),
        &definition,
        &animations,
        &world,
        .{},
        .{ .x = 0, .y = 1.05 },
        .right,
        0,
        null,
    );
    defer controlled.deinit();
    const anatomy_definition = definition.anatomy_definition.?.view();
    try controlled.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_male"));
    try controlled.initializeEquipment(equipment_definition.view());

    for (0..120) |_| _ = try controlled.stepController(&world, intent(1, false, false));
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), controlled.controller.?.state.velocity.x, tolerance);
    try controlled.resetControlled(&world);
    try controlled.replaceItem(try equipment_definition.itemId("speed_boots"));
    for (0..120) |_| _ = try controlled.stepController(&world, intent(1, false, false));
    try std.testing.expectApproxEqAbs(@as(f32, 5.175), controlled.controller.?.state.velocity.x, tolerance);

    try controlled.resetControlled(&world);
    const default_jump = try controlled.stepController(&world, intent(0, true, false));
    try std.testing.expect(default_jump.jump_accepted and default_jump.jump_source == .grounded);
    const default_jump_velocity = controlled.controller.?.state.velocity.y;
    try controlled.resetControlled(&world);
    try controlled.replaceItem(try equipment_definition.itemId("spring_boots"));
    _ = try controlled.stepController(&world, intent(0, true, false));
    try std.testing.expect(controlled.controller.?.state.velocity.y > default_jump_velocity + 1.7);

    try controlled.resetControlled(&world);
    _ = try controlled.stepController(&world, intent(0, true, false));
    const denied_air_jump = try controlled.stepController(&world, intent(0, true, false));
    try std.testing.expect(!denied_air_jump.jump_accepted);

    try controlled.resetControlled(&world);
    const winged_boots = try equipment_definition.itemId("winged_boots");
    try controlled.replaceItem(winged_boots);
    _ = try controlled.stepController(&world, intent(0, true, false));
    const allowed_air_jump = try controlled.stepController(&world, intent(0, true, false));
    try std.testing.expect(allowed_air_jump.jump_accepted and allowed_air_jump.jump_source == .air);
    try std.testing.expectEqual(@as(u8, 1), controlled.controller.?.state.air_jumps_used);
    const third_jump = try controlled.stepController(&world, intent(0, true, false));
    try std.testing.expect(!third_jump.jump_accepted);
    for (0..600) |_| {
        _ = try controlled.stepController(&world, emptyIntent());
        if (controlled.controller.?.state.grounded) break;
    }
    try std.testing.expect(controlled.controller.?.state.grounded);
    try std.testing.expectEqual(@as(u8, 0), controlled.controller.?.state.air_jumps_used);
    _ = try controlled.stepController(&world, intent(0, true, false));
    try std.testing.expect((try controlled.stepController(&world, intent(0, true, false))).jump_source == .air);

    try controlled.resetControlled(&world);
    try controlled.replaceItem(winged_boots);
    _ = try controlled.stepController(&world, intent(0, true, false));
    try controlled.unequipItem(winged_boots);
    const removed_while_airborne = try controlled.stepController(&world, intent(0, true, false));
    try std.testing.expect(!removed_while_airborne.jump_accepted);

    try controlled.resetControlled(&world);
    const denied_dash = try controlled.stepController(&world, intent(0, false, true));
    try std.testing.expect(denied_dash.dash_denied and !denied_dash.dash_started);
    try controlled.resetControlled(&world);
    const amulet = try equipment_definition.itemId("amulet");
    try controlled.equipItem(amulet);
    const allowed_dash = try controlled.stepController(&world, intent(-1, false, true));
    try std.testing.expect(allowed_dash.dash_started and !allowed_dash.dash_denied);
    try std.testing.expectEqual(character_controller.Facing.left, controlled.controller.?.state.facing);
    try std.testing.expect(controlled.controller.?.state.velocity.x < -11.9);
    const active_ticks_before_removal = controlled.controller.?.state.dash_ticks_remaining;
    try controlled.unequipItem(amulet);
    _ = try controlled.stepController(&world, emptyIntent());
    try std.testing.expect(controlled.controller.?.state.dash_ticks_remaining < active_ticks_before_removal);
    try std.testing.expect(controlled.controller.?.state.dash_ticks_remaining > 0);
}

test "dash collides with walls and default resolved controller path is regression-equivalent" {
    const colliders = [_]collider.StaticColliderInput{
        .{
            .id = 1,
            .bounds = .{ .minimum = .{ .x = -20, .y = -1 }, .maximum = .{ .x = 20, .y = 0 } },
        },
        .{
            .id = 2,
            .bounds = .{ .minimum = .{ .x = 1, .y = 0 }, .maximum = .{ .x = 1.2, .y = 4 } },
            .ground_query_eligible = false,
        },
    };
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &colliders, null);
    defer world.deinit();
    var dash_controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = 0, .y = 1.05 }, .right);
    var dash_properties = character_controller.GameplayProperties.fromConfiguration(dash_controller.configuration);
    dash_properties.dash = true;
    try std.testing.expect((try dash_controller.stepWithProperties(&world, intent(1, false, true), dash_properties)).dash_started);
    var wall_seen = false;
    for (0..40) |_| {
        const result = try dash_controller.stepWithProperties(&world, emptyIntent(), dash_properties);
        if (result.wall_collision) {
            wall_seen = true;
            try std.testing.expect(result.dash_ended);
            break;
        }
    }
    try std.testing.expect(wall_seen);
    try std.testing.expectEqual(@as(u16, 0), dash_controller.state.dash_ticks_remaining);
    try std.testing.expectApproxEqAbs(@as(f32, 0), dash_controller.state.velocity.x, tolerance);
    try std.testing.expect((try dash_controller.stepWithProperties(&world, intent(-1, false, true), dash_properties)).dash_denied);
    while (dash_controller.state.dash_cooldown_ticks_remaining > 0) {
        _ = try dash_controller.stepWithProperties(&world, emptyIntent(), dash_properties);
    }
    try std.testing.expect((try dash_controller.stepWithProperties(&world, intent(-1, false, true), dash_properties)).dash_started);

    var floor = try floorWorld(std.testing.allocator);
    defer floor.deinit();
    var legacy = try character_controller.CharacterController.init(.{}, &floor, .{ .x = -2, .y = 1.05 }, .right);
    var resolved = legacy;
    const defaults = character_controller.GameplayProperties.fromConfiguration(resolved.configuration);
    for (0..240) |tick| {
        var tick_intent = intent(if (tick < 160) 1 else -0.5, tick == 30, false);
        tick_intent.jump_held = tick >= 30 and tick < 60;
        tick_intent.jump_released = tick == 60;
        const legacy_result = try legacy.step(&floor, tick_intent);
        const resolved_result = try resolved.stepWithProperties(&floor, tick_intent, defaults);
        try std.testing.expectEqual(legacy_result, resolved_result);
        try std.testing.expectEqual(legacy.state, resolved.state);
    }
}

test "property resolution performs no allocation growth" {
    var storage: [64]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const before = fixed.end_index;
    const attributes = [_]properties.AttributeDefinition{
        try attribute(0, "capacity", 50, 0, 1000),
    };
    const capabilities = [_]properties.CapabilityDefinition{};
    var builder = try properties.Builder.init(&attributes, &capabilities, &.{});
    try builder.addModifier(.{
        .source = properties.SourceId.init(1, 1),
        .source_ordinal = 0,
        .attribute = @enumFromInt(0),
        .operation = .add,
        .amount = 20,
    });
    const resolved = try builder.finish();
    try std.testing.expectEqual(@as(f32, 70), try resolved.value(@enumFromInt(0)));
    try std.testing.expectEqual(before, fixed.end_index);
    _ = fixed.allocator();
}
