const std = @import("std");
const anatomy = @import("anatomy");
const equipment = @import("equipment");
const equipment_demo = @import("equipment_demo");
const modular_humanoid = @import("modular_humanoid");
const sprite = @import("sprite_batch");
const character = @import("character");

const tolerance: f32 = 0.000001;

const minimal_slots = [_]equipment.EquipmentSlotInput{
    .{ .stable_id = "tail_armor" },
};
const minimal_roles = [_]equipment.AnatomyRoleInput{
    .{ .stable_id = "arm_role", .compatible_part_type = "upper_arm" },
};
const minimal_layers = [_]equipment.VisualLayerInput{
    .{ .stable_id = "clothing", .render_layer = 70 },
};
const minimal_components = [_]equipment.VisualComponentInput{
    .{
        .stable_id = "sleeve",
        .sprite_size = .{ .x = 0.7, .y = 0.2 },
        .tint = .{ 0.4, 0.6, 0.8, 1 },
    },
};
const minimal_attributes = [_]equipment.AttributeDefinitionInput{
    .{ .stable_id = "fire_resistance", .base_value = 0, .minimum = 0, .maximum = 1 },
};
const minimal_capabilities = [_]equipment.CapabilityDefinitionInput{
    .{ .stable_id = "wall_climb" },
};
const minimal_recipes = [_]equipment.ItemVisualRecipeInput{
    .{
        .component = "sleeve",
        .binding = .{ .anatomy = .{
            .role = "arm_role",
            .selection = .every_compatible,
            .maximum_matches = 4,
        } },
        .body_region = "left_arm",
        .visual_layer = "clothing",
    },
};
const minimal_modifiers = [_]equipment.AttributeModifierInput{
    .{ .attribute = "fire_resistance", .operation = .add, .amount = 0.25 },
};
const minimal_items = [_]equipment.EquipmentItemInput{
    .{
        .stable_id = "adaptive_garment",
        .occupied_slots = &.{"tail_armor"},
        .visual_recipes = &minimal_recipes,
        .covered_body_regions = &.{"left_arm"},
        .attribute_modifiers = &minimal_modifiers,
        .capability_grants = &.{"wall_climb"},
    },
};

fn minimalInputs() equipment.DefinitionInputs {
    return .{
        .equipment_slots = &minimal_slots,
        .anatomy_roles = &minimal_roles,
        .visual_layers = &minimal_layers,
        .visual_components = &minimal_components,
        .attributes = &minimal_attributes,
        .capabilities = &minimal_capabilities,
        .items = &minimal_items,
        .default_loadout = &.{"adaptive_garment"},
    };
}

test "equipment definition registration validates duplicates missing references and future identifiers" {
    var humanoid_definition = try modular_humanoid.initDefinition(std.testing.allocator);
    defer humanoid_definition.deinit();
    const anatomy_definition = humanoid_definition.anatomy_definition.?.view();
    const appearance_definition = humanoid_definition.visual_definition.view();

    var valid = try equipment.Definition.init(
        std.testing.allocator,
        anatomy_definition,
        appearance_definition,
        minimalInputs(),
    );
    defer valid.deinit();
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(try valid.slotId("tail_armor")));
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(try valid.attributeId("fire_resistance")));
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(try valid.capabilityId("wall_climb")));

    const duplicate_slots = [_]equipment.EquipmentSlotInput{
        .{ .stable_id = "tail_armor" },
        .{ .stable_id = "tail_armor" },
    };
    var duplicate_inputs = minimalInputs();
    duplicate_inputs.equipment_slots = &duplicate_slots;
    try std.testing.expectError(
        error.DuplicateStableIdentifier,
        equipment.Definition.init(std.testing.allocator, anatomy_definition, appearance_definition, duplicate_inputs),
    );

    const missing_slot_items = [_]equipment.EquipmentItemInput{.{
        .stable_id = "invalid_item",
        .occupied_slots = &.{"missing_slot"},
        .visual_recipes = &minimal_recipes,
        .covered_body_regions = &.{"left_arm"},
        .attribute_modifiers = &minimal_modifiers,
        .capability_grants = &.{"wall_climb"},
    }};
    var missing_slot_inputs = minimalInputs();
    missing_slot_inputs.items = &missing_slot_items;
    missing_slot_inputs.default_loadout = &.{};
    try std.testing.expectError(
        error.MissingEquipmentSlotReference,
        equipment.Definition.init(std.testing.allocator, anatomy_definition, appearance_definition, missing_slot_inputs),
    );

    const missing_attribute_modifiers = [_]equipment.AttributeModifierInput{
        .{ .attribute = "missing_attribute", .operation = .add, .amount = 1 },
    };
    var missing_attribute_items = minimal_items;
    missing_attribute_items[0].attribute_modifiers = &missing_attribute_modifiers;
    var missing_attribute_inputs = minimalInputs();
    missing_attribute_inputs.items = &missing_attribute_items;
    try std.testing.expectError(
        error.MissingAttributeReference,
        equipment.Definition.init(std.testing.allocator, anatomy_definition, appearance_definition, missing_attribute_inputs),
    );
}

test "one garment expands deterministically to two and four arms with bounded required matching" {
    var humanoid_definition = try modular_humanoid.initDefinition(std.testing.allocator);
    defer humanoid_definition.deinit();
    const anatomy_definition = humanoid_definition.anatomy_definition.?.view();
    var equipment_definition = try equipment.Definition.init(
        std.testing.allocator,
        anatomy_definition,
        humanoid_definition.visual_definition.view(),
        minimalInputs(),
    );
    defer equipment_definition.deinit();

    var two_arm_runtime = try anatomy.Runtime.init(std.testing.allocator, anatomy_definition, null);
    defer two_arm_runtime.deinit();
    try two_arm_runtime.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("conventional_male"));
    const two_arm = try equipment.Loadout.init(equipment_definition.view(), .{
        .definition = anatomy_definition,
        .runtime = &two_arm_runtime,
    });
    try std.testing.expectEqual(@as(usize, 2), two_arm.visuals().len);

    var four_arm_runtime = try anatomy.Runtime.init(std.testing.allocator, anatomy_definition, null);
    defer four_arm_runtime.deinit();
    try four_arm_runtime.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("nonstandard_humanoid"));
    const four_arm = try equipment.Loadout.init(equipment_definition.view(), .{
        .definition = anatomy_definition,
        .runtime = &four_arm_runtime,
    });
    try std.testing.expectEqual(@as(usize, 4), four_arm.visuals().len);
    try std.testing.expectEqualSlices(equipment.EquipmentItemId, two_arm.equippedItems(), four_arm.equippedItems());

    var bounded_recipes = minimal_recipes;
    bounded_recipes[0].binding.anatomy.maximum_matches = 2;
    var bounded_items = minimal_items;
    bounded_items[0].visual_recipes = &bounded_recipes;
    var bounded_inputs = minimalInputs();
    bounded_inputs.items = &bounded_items;
    var bounded_definition = try equipment.Definition.init(
        std.testing.allocator,
        anatomy_definition,
        humanoid_definition.visual_definition.view(),
        bounded_inputs,
    );
    defer bounded_definition.deinit();
    try std.testing.expectError(
        error.CompatiblePartExpansionExceeded,
        equipment.Loadout.init(bounded_definition.view(), .{
            .definition = anatomy_definition,
            .runtime = &four_arm_runtime,
        }),
    );

    var specific_recipes = minimal_recipes;
    specific_recipes[0].binding = .{ .anatomy = .{
        .role = "arm_role",
        .selection = .specific_instance,
        .specific_instance = "extra_arm",
        .maximum_matches = 1,
    } };
    var specific_items = minimal_items;
    specific_items[0].visual_recipes = &specific_recipes;
    var specific_inputs = minimalInputs();
    specific_inputs.items = &specific_items;
    var specific_definition = try equipment.Definition.init(
        std.testing.allocator,
        anatomy_definition,
        humanoid_definition.visual_definition.view(),
        specific_inputs,
    );
    defer specific_definition.deinit();
    try std.testing.expectError(
        error.MissingRequiredAnatomy,
        equipment.Loadout.init(specific_definition.view(), .{
            .definition = anatomy_definition,
            .runtime = &two_arm_runtime,
        }),
    );

    specific_recipes[0].binding.anatomy.required = false;
    specific_items[0].visual_recipes = &specific_recipes;
    specific_inputs.items = &specific_items;
    var optional_definition = try equipment.Definition.init(
        std.testing.allocator,
        anatomy_definition,
        humanoid_definition.visual_definition.view(),
        specific_inputs,
    );
    defer optional_definition.deinit();
    const optional_loadout = try equipment.Loadout.init(optional_definition.view(), .{
        .definition = anatomy_definition,
        .runtime = &two_arm_runtime,
    });
    try std.testing.expectEqual(@as(usize, 0), optional_loadout.visuals().len);
}

test "transactional loadout layering replacement coverage reset effects and character isolation" {
    var scene = try equipment_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const definition = scene.equipment_definition.view();
    const loadout = scene.two_arm.equipmentView().?;
    const outerwear_slot = try definition.slotId("outerwear");
    const shirt_slot = try definition.slotId("shirt");
    const underwear_slot = try definition.slotId("pelvis_underwear");
    const chest_underwear_slot = try definition.slotId("chest_underwear");
    const shoes_slot = try definition.slotId("shoes");
    try std.testing.expect(try loadout.itemInSlot(outerwear_slot) != null);
    try std.testing.expect(try loadout.itemInSlot(shirt_slot) != null);
    try std.testing.expect(try loadout.itemInSlot(underwear_slot) != null);

    try scene.two_arm.equipItem(try definition.itemId("bra"));
    try std.testing.expect(try loadout.itemInSlot(chest_underwear_slot) != null);
    try std.testing.expect(try loadout.itemInSlot(shirt_slot) != null);
    const torso_region = try scene.definition.visual_definition.bodyRegionId("torso");
    try std.testing.expect(loadout.coversRegion(torso_region));

    const before_conflict = fingerprint(loadout);
    try std.testing.expectError(
        error.EquipmentSlotOccupied,
        scene.two_arm.equipItem(try definition.itemId("winged_boots")),
    );
    try std.testing.expectEqual(before_conflict, fingerprint(loadout));

    const winged_boots = try definition.itemId("winged_boots");
    const double_jump = try definition.capabilityId("double_jump");
    try scene.two_arm.replaceItem(winged_boots);
    try std.testing.expectEqual(winged_boots, (try loadout.itemInSlot(shoes_slot)).?);
    try std.testing.expect(loadout.hasCapability(double_jump));
    try scene.two_arm.unequipItem(winged_boots);
    try std.testing.expect(!loadout.hasCapability(double_jump));
    try std.testing.expect((try loadout.itemInSlot(shoes_slot)) == null);

    const other_before = fingerprint(scene.four_arm.equipmentView().?);
    try scene.two_arm.equipItem(try definition.itemId("shoes"));
    try std.testing.expectEqual(other_before, fingerprint(scene.four_arm.equipmentView().?));
    try scene.two_arm.reset();
    try std.testing.expect(!loadout.hasCapability(double_jump));
    try std.testing.expectEqual(
        try definition.itemId("shoes"),
        (try loadout.itemInSlot(shoes_slot)).?,
    );
    try std.testing.expect((try loadout.itemInSlot(outerwear_slot)) == null);
}

test "definition-sorted visual and effect views do not depend on equip request order" {
    var scene = try equipment_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const definition = scene.equipment_definition.view();
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    const internal = character.testing.state(&scene.two_arm);
    const context = equipment.AnatomyContext{
        .definition = anatomy_definition,
        .runtime = &internal.character.anatomy_runtime.?,
    };
    var first = try equipment.Loadout.init(definition, context);
    var second = try equipment.Loadout.init(definition, context);
    const amulet = try definition.itemId("amulet");
    const backpack = try definition.itemId("backpack");
    const sweatshirt = try definition.itemId("long_sleeve_sweatshirt");
    try first.equip(context, amulet);
    try first.equip(context, backpack);
    try first.equip(context, sweatshirt);
    try second.equip(context, sweatshirt);
    try second.equip(context, backpack);
    try second.equip(context, amulet);

    try std.testing.expectEqualSlices(equipment.EquipmentItemId, first.equippedItems(), second.equippedItems());
    try std.testing.expectEqual(first.visuals().len, second.visuals().len);
    for (first.visuals(), second.visuals()) |left, right| {
        try std.testing.expectEqual(left.item, right.item);
        try std.testing.expectEqual(left.recipe, right.recipe);
        try std.testing.expectEqual(sourceValue(left.source), sourceValue(right.source));
        try std.testing.expectEqual(left.body_region, right.body_region);
    }
    try std.testing.expectEqualSlices(equipment.ActiveModifier, first.modifiers(), second.modifiers());
    try std.testing.expectEqualSlices(equipment.ActiveCapability, first.capabilities(), second.capabilities());
}

test "equipment is allocation-free after initialization and preserves canonical sockets and facing reflection" {
    var storage: [4 * 1024 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var scene = try equipment_demo.Scene.init(fixed.allocator());
    defer scene.deinit();
    const initialized_bytes = fixed.end_index;
    const definition = scene.equipment_definition.view();
    const right_hand_before = try scene.two_arm.socketPosition(.right_hand);
    const backpack = try definition.itemId("backpack");
    try scene.two_arm.unequipItem(backpack);
    try scene.two_arm.equipItem(backpack);
    try scene.two_arm.rebindEquipment();
    try std.testing.expectEqual(initialized_bytes, fixed.end_index);
    const right_hand_after = try scene.two_arm.socketPosition(.right_hand);
    try std.testing.expectApproxEqAbs(right_hand_before.x, right_hand_after.x, tolerance);
    try std.testing.expectApproxEqAbs(right_hand_before.y, right_hand_after.y, tolerance);

    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 256, 1);
    defer batch.deinit();
    batch.beginFrame();
    _ = try scene.two_arm.submitAttachments(&batch);
    const right_facing_scale = try layerScaleX(batch.prepare().sprites, 67);
    try scene.two_arm.setFacing(.left);
    batch.beginFrame();
    _ = try scene.two_arm.submitAttachments(&batch);
    const left_facing_scale = try layerScaleX(batch.prepare().sprites, 67);
    try std.testing.expect(right_facing_scale * left_facing_scale < 0);
    try std.testing.expectApproxEqAbs(@abs(right_facing_scale), @abs(left_facing_scale), tolerance);
}

fn sourceValue(source: equipment.VisualSource) u32 {
    return switch (source) {
        .anatomy_part => |id| @intFromEnum(id),
        .attachment_point => |id| 0x10000 + @as(u32, @intFromEnum(id)),
    };
}

fn fingerprint(loadout: *const equipment.Loadout) u64 {
    var hash: u64 = 14695981039346656037;
    for (loadout.equippedItems()) |item_id| hash = (hash ^ @as(u64, @intFromEnum(item_id))) *% 1099511628211;
    for (loadout.visuals()) |visual| {
        hash = (hash ^ @as(u64, @intFromEnum(visual.recipe))) *% 1099511628211;
        hash = (hash ^ @as(u64, sourceValue(visual.source))) *% 1099511628211;
    }
    return hash;
}

fn layerScaleX(submissions: []const sprite.SpriteSubmission, body_part_layer: u16) !f32 {
    for (submissions) |submission| {
        if (submission.order.body_part_layer == body_part_layer) return submission.scale[0];
    }
    return error.EquipmentLayerSubmissionMissing;
}
