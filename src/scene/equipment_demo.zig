const std = @import("std");
const math = @import("math");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const equipment = @import("equipment");
const modular_body = @import("modular_body_demo");
const sprite = @import("sprite_batch");

pub const required_frames: u32 = 240;
pub const character_count: usize = 2;

pub const Evidence = struct {
    conflict_rejected_transactionally: bool = false,
    multi_slot_replacement_proved: bool = false,
    unequip_restoration_proved: bool = false,
    two_arm_sleeves: u16 = 0,
    four_arm_sleeves: u16 = 0,
};

pub const Scene = struct {
    definition: humanoid.HumanoidDefinition,
    equipment_definition: equipment.Definition,
    shared_animations: authored.Definitions,
    id_allocator: character.EntityIdAllocator,
    two_arm: character.CharacterInstance,
    four_arm: character.CharacterInstance,
    evidence: Evidence = .{},
    visual_ticks: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) !Scene {
        var definition = try modular_body.initDefinition(allocator);
        errdefer definition.deinit();
        var equipment_definition = try initDefinition(allocator, &definition);
        errdefer equipment_definition.deinit();
        var shared_animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer shared_animations.deinit();
        var id_allocator = character.EntityIdAllocator{};

        var two_arm = try character.CharacterInstance.init(
            allocator,
            try id_allocator.allocate(),
            &definition,
            &shared_animations,
            .{ .x = -1.75, .y = 0 },
            .right,
            0,
            null,
        );
        errdefer two_arm.deinit();
        var four_arm = try character.CharacterInstance.init(
            allocator,
            try id_allocator.allocate(),
            &definition,
            &shared_animations,
            .{ .x = 1.75, .y = 0 },
            .left,
            1,
            null,
        );
        errdefer four_arm.deinit();

        const anatomy_definition = definition.anatomy_definition.?.view();
        try two_arm.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_male"));
        try four_arm.selectBodyPreset(try anatomy_definition.bodyPresetId("nonstandard_humanoid"));
        try two_arm.initializeEquipment(equipment_definition.view());
        try four_arm.initializeEquipment(equipment_definition.view());

        const sweatshirt = try equipment_definition.itemId("long_sleeve_sweatshirt");
        const left_shoulder = try equipment_definition.itemId("left_shoulder_armor");
        const right_shoulder = try equipment_definition.itemId("right_shoulder_armor");
        const amulet = try equipment_definition.itemId("amulet");
        const backpack = try equipment_definition.itemId("backpack");
        const speed_boots = try equipment_definition.itemId("speed_boots");
        const winged_boots = try equipment_definition.itemId("winged_boots");
        const full_armor = try equipment_definition.itemId("full_plate_armor");

        try two_arm.equipItem(sweatshirt);
        try two_arm.equipItem(left_shoulder);
        try two_arm.equipItem(amulet);
        try two_arm.equipItem(backpack);

        const before_conflict = loadoutFingerprint(&two_arm);
        var rejected = false;
        two_arm.equipItem(winged_boots) catch |err| {
            if (err != error.EquipmentSlotOccupied) return err;
            rejected = true;
        };
        if (!rejected or before_conflict != loadoutFingerprint(&two_arm)) return error.TransactionalConflictEvidenceMissing;
        try two_arm.replaceItem(speed_boots);

        try four_arm.equipItem(sweatshirt);
        try four_arm.equipItem(right_shoulder);
        try four_arm.replaceItem(winged_boots);
        const before_multi_slot_conflict = loadoutFingerprint(&four_arm);
        rejected = false;
        four_arm.equipItem(full_armor) catch |err| {
            if (err != error.EquipmentSlotOccupied) return err;
            rejected = true;
        };
        if (!rejected or before_multi_slot_conflict != loadoutFingerprint(&four_arm)) {
            return error.MultiSlotConflictEvidenceMissing;
        }
        try four_arm.replaceItem(full_armor);
        const torso_armor_slot = try equipment_definition.slotId("torso_armor");
        const left_shoulder_slot = try equipment_definition.slotId("left_shoulder_armor");
        const right_shoulder_slot = try equipment_definition.slotId("right_shoulder_armor");
        const loadout = &four_arm.equipment_loadout.?;
        if (try loadout.itemInSlot(torso_armor_slot) != full_armor or
            try loadout.itemInSlot(left_shoulder_slot) != full_armor or
            try loadout.itemInSlot(right_shoulder_slot) != full_armor)
        {
            return error.MultiSlotReplacementEvidenceMissing;
        }
        try four_arm.unequipItem(full_armor);
        try four_arm.equipItem(right_shoulder);

        const sleeve_component = try equipment_definition.visualComponentId("long_sleeve");
        const two_arm_sleeves = countComponentVisuals(&two_arm.equipment_loadout.?, sleeve_component);
        const four_arm_sleeves = countComponentVisuals(&four_arm.equipment_loadout.?, sleeve_component);
        if (two_arm_sleeves != 2 or four_arm_sleeves != 4) return error.TopologyAwareSleeveEvidenceMissing;

        return .{
            .definition = definition,
            .equipment_definition = equipment_definition,
            .shared_animations = shared_animations,
            .id_allocator = id_allocator,
            .two_arm = two_arm,
            .four_arm = four_arm,
            .evidence = .{
                .conflict_rejected_transactionally = true,
                .multi_slot_replacement_proved = true,
                .two_arm_sleeves = two_arm_sleeves,
                .four_arm_sleeves = four_arm_sleeves,
            },
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.four_arm.deinit();
        scene.two_arm.deinit();
        scene.shared_animations.deinit();
        scene.equipment_definition.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn updateFrame(scene: *Scene, frame: u32) !void {
        if (frame == 30) {
            try scene.four_arm.replaceItem(try scene.equipment_definition.itemId("full_plate_armor"));
        } else if (frame == 60) {
            try scene.two_arm.unequipItem(try scene.equipment_definition.itemId("left_shoulder_armor"));
        } else if (frame == 90) {
            try scene.four_arm.unequipItem(try scene.equipment_definition.itemId("full_plate_armor"));
            try scene.four_arm.equipItem(try scene.equipment_definition.itemId("right_shoulder_armor"));
        } else if (frame == 120) {
            try scene.two_arm.equipItem(try scene.equipment_definition.itemId("left_shoulder_armor"));
            scene.evidence.unequip_restoration_proved = true;
        }
        try scene.two_arm.advanceVisualTick(.{});
        try scene.four_arm.advanceVisualTick(.{});
        scene.visual_ticks += 2;
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        return character.submitGlobally(&.{ &scene.two_arm, &scene.four_arm }, batch);
    }

    pub fn validateComplete(scene: *const Scene) !void {
        if (!scene.evidence.conflict_rejected_transactionally or
            !scene.evidence.multi_slot_replacement_proved or
            !scene.evidence.unequip_restoration_proved or
            scene.evidence.two_arm_sleeves != 2 or
            scene.evidence.four_arm_sleeves != 4 or
            scene.visual_ticks != @as(u64, required_frames) * @as(u64, character_count))
        {
            return error.EquipmentDemonstrationIncomplete;
        }
        const double_jump = try scene.equipment_definition.capabilityId("double_jump");
        const speed = try scene.equipment_definition.attributeId("movement_speed");
        if (!scene.four_arm.equipment_loadout.?.hasCapability(double_jump)) return error.CapabilityEvidenceMissing;
        var speed_modifier_found = false;
        for (scene.two_arm.equipment_loadout.?.modifiers()) |modifier| {
            if (modifier.attribute == speed) speed_modifier_found = true;
        }
        if (!speed_modifier_found) return error.AttributeModifierEvidenceMissing;
        if (loadoutFingerprint(&scene.two_arm) == loadoutFingerprint(&scene.four_arm)) {
            return error.CharacterLoadoutIsolationEvidenceMissing;
        }
    }
};

pub fn initDefinition(
    allocator: std.mem.Allocator,
    humanoid_definition: *const humanoid.HumanoidDefinition,
) !equipment.Definition {
    const anatomy_definition = humanoid_definition.anatomy_definition.?.view();
    const appearance_definition = humanoid_definition.visual_definition.view();

    const slots = [_]equipment.EquipmentSlotInput{
        .{ .stable_id = "pelvis_underwear" },
        .{ .stable_id = "chest_underwear" },
        .{ .stable_id = "shirt" },
        .{ .stable_id = "outerwear" },
        .{ .stable_id = "socks" },
        .{ .stable_id = "shoes" },
        .{ .stable_id = "torso_armor" },
        .{ .stable_id = "left_shoulder_armor" },
        .{ .stable_id = "right_shoulder_armor" },
        .{ .stable_id = "left_gauntlet" },
        .{ .stable_id = "right_gauntlet" },
        .{ .stable_id = "neck_accessory" },
        .{ .stable_id = "back" },
    };
    const roles = [_]equipment.AnatomyRoleInput{
        .{ .stable_id = "pelvis_role", .compatible_part_type = "pelvis" },
        .{ .stable_id = "torso_role", .compatible_part_type = "torso" },
        .{ .stable_id = "upper_arm_role", .compatible_part_type = "upper_arm" },
        .{ .stable_id = "hand_role", .compatible_part_type = "hand" },
        .{ .stable_id = "foot_role", .compatible_part_type = "foot" },
    };
    const layers = [_]equipment.VisualLayerInput{
        .{ .stable_id = "undergarment", .render_layer = 65 },
        .{ .stable_id = "shirt", .render_layer = 66 },
        .{ .stable_id = "outerwear", .render_layer = 67 },
        .{ .stable_id = "armor", .render_layer = 72 },
        .{ .stable_id = "accessory", .render_layer = 78 },
    };
    const attributes = [_]equipment.AttributeDefinitionInput{
        .{ .stable_id = "armor" },
        .{ .stable_id = "physical_damage_reduction" },
        .{ .stable_id = "movement_speed" },
        .{ .stable_id = "jump_strength" },
        .{ .stable_id = "carrying_capacity" },
    };
    const capabilities = [_]equipment.CapabilityDefinitionInput{
        .{ .stable_id = "double_jump" },
        .{ .stable_id = "dash" },
    };
    const components = [_]equipment.VisualComponentInput{
        component("pelvis_underwear_visual", .{ .x = 0.74, .y = 0.34 }, .{ 0.18, 0.20, 0.34, 1 }, .{ 0.5, 0.5 }),
        component("chest_underwear_visual", .{ .x = 0.82, .y = 0.40 }, .{ 0.78, 0.32, 0.52, 1 }, .{ 0.5, 0.5 }),
        component("shirt_torso", .{ .x = 0.92, .y = 1.18 }, .{ 0.12, 0.48, 0.82, 1 }, .{ 0.5, 0.5 }),
        component("short_sleeve", .{ .x = 0.34, .y = 0.23 }, .{ 0.12, 0.48, 0.82, 1 }, .{ 0, 0.5 }),
        component("sweatshirt_torso", .{ .x = 1.00, .y = 1.24 }, .{ 0.72, 0.22, 0.18, 1 }, .{ 0.5, 0.5 }),
        component("long_sleeve", .{ .x = 0.72, .y = 0.25 }, .{ 0.72, 0.22, 0.18, 1 }, .{ 0, 0.5 }),
        component("sock", .{ .x = 0.34, .y = 0.20 }, .{ 0.92, 0.92, 0.92, 1 }, .{ 0, 0.5 }),
        component("shoe", .{ .x = 0.42, .y = 0.24 }, .{ 0.12, 0.12, 0.16, 1 }, .{ 0, 0.5 }),
        component("boot", .{ .x = 0.46, .y = 0.30 }, .{ 0.22, 0.42, 0.16, 1 }, .{ 0, 0.5 }),
        component("shoulder_plate", .{ .x = 0.30, .y = 0.28 }, .{ 0.62, 0.66, 0.72, 1 }, .{ 0.2, 0.5 }),
        component("gauntlet", .{ .x = 0.30, .y = 0.24 }, .{ 0.58, 0.62, 0.70, 1 }, .{ 0, 0.5 }),
        component("armor_torso", .{ .x = 1.02, .y = 1.16 }, .{ 0.46, 0.50, 0.58, 1 }, .{ 0.5, 0.5 }),
        component("amulet_visual", .{ .x = 0.18, .y = 0.24 }, .{ 0.92, 0.72, 0.16, 1 }, .{ 0.5, 0.9 }),
        component("backpack_visual", .{ .x = 0.72, .y = 0.92 }, .{ 0.28, 0.20, 0.12, 1 }, .{ 0.5, 0.5 }),
    };

    const items = [_]equipment.EquipmentItemInput{
        .{
            .stable_id = "underwear",
            .occupied_slots = &.{"pelvis_underwear"},
            .visual_recipes = &.{firstRecipe("pelvis_underwear_visual", "pelvis_role", "pelvis", "undergarment", math.Transform2D.identity())},
            .covered_body_regions = &.{"pelvis"},
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "bra",
            .occupied_slots = &.{"chest_underwear"},
            .visual_recipes = &.{firstRecipe("chest_underwear_visual", "torso_role", "torso", "undergarment", torsoLocal())},
            .covered_body_regions = &.{"torso"},
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "short_sleeve_shirt",
            .occupied_slots = &.{"shirt"},
            .visual_recipes = &.{
                firstRecipe("shirt_torso", "torso_role", "torso", "shirt", torsoLocal()),
                everyRecipe("short_sleeve", "upper_arm_role", 4, "left_arm", "shirt", math.Transform2D.identity()),
            },
            .covered_body_regions = &.{ "torso", "left_arm", "right_arm" },
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "long_sleeve_sweatshirt",
            .occupied_slots = &.{"outerwear"},
            .visual_recipes = &.{
                firstRecipe("sweatshirt_torso", "torso_role", "torso", "outerwear", torsoLocal()),
                everyRecipe("long_sleeve", "upper_arm_role", 4, "left_arm", "outerwear", math.Transform2D.identity()),
            },
            .covered_body_regions = &.{ "torso", "left_arm", "right_arm" },
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "socks",
            .occupied_slots = &.{"socks"},
            .visual_recipes = &.{everyRecipe("sock", "foot_role", 2, "left_foot", "undergarment", math.Transform2D.identity())},
            .covered_body_regions = &.{ "left_foot", "right_foot" },
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "shoes",
            .occupied_slots = &.{"shoes"},
            .visual_recipes = &.{everyRecipe("shoe", "foot_role", 2, "left_foot", "outerwear", math.Transform2D.identity())},
            .covered_body_regions = &.{ "left_foot", "right_foot" },
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "left_shoulder_armor",
            .occupied_slots = &.{"left_shoulder_armor"},
            .visual_recipes = &.{specificRecipe("shoulder_plate", "upper_arm_role", "left_upper_arm", "left_arm", "armor")},
            .covered_body_regions = &.{"left_arm"},
            .attribute_modifiers = &.{.{ .attribute = "armor", .operation = .add, .amount = 4 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "right_shoulder_armor",
            .occupied_slots = &.{"right_shoulder_armor"},
            .visual_recipes = &.{specificRecipe("shoulder_plate", "upper_arm_role", "right_upper_arm", "right_arm", "armor")},
            .covered_body_regions = &.{"right_arm"},
            .attribute_modifiers = &.{.{ .attribute = "armor", .operation = .add, .amount = 4 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "left_gauntlet",
            .occupied_slots = &.{"left_gauntlet"},
            .visual_recipes = &.{specificRecipe("gauntlet", "hand_role", "left_hand", "left_hand", "armor")},
            .covered_body_regions = &.{"left_hand"},
            .attribute_modifiers = &.{.{ .attribute = "armor", .operation = .add, .amount = 2 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "right_gauntlet",
            .occupied_slots = &.{"right_gauntlet"},
            .visual_recipes = &.{specificRecipe("gauntlet", "hand_role", "right_hand", "right_hand", "armor")},
            .covered_body_regions = &.{"right_hand"},
            .attribute_modifiers = &.{.{ .attribute = "armor", .operation = .add, .amount = 2 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "full_plate_armor",
            .occupied_slots = &.{ "torso_armor", "left_shoulder_armor", "right_shoulder_armor" },
            .visual_recipes = &.{
                firstRecipe("armor_torso", "torso_role", "torso", "armor", torsoLocal()),
                specificRecipe("shoulder_plate", "upper_arm_role", "left_upper_arm", "left_arm", "armor"),
                specificRecipe("shoulder_plate", "upper_arm_role", "right_upper_arm", "right_arm", "armor"),
            },
            .covered_body_regions = &.{ "torso", "left_arm", "right_arm" },
            .attribute_modifiers = &.{
                .{ .attribute = "armor", .operation = .add, .amount = 25 },
                .{ .attribute = "physical_damage_reduction", .operation = .add, .amount = 0.20 },
                .{ .attribute = "movement_speed", .operation = .multiply, .amount = 0.90 },
            },
            .capability_grants = &.{},
        },
        .{
            .stable_id = "amulet",
            .occupied_slots = &.{"neck_accessory"},
            .visual_recipes = &.{attachmentRecipe("amulet_visual", "neck", "torso", "accessory", math.Transform2D.init(.{ .x = 0, .y = -0.08 }, 0, math.Vec2.one))},
            .covered_body_regions = &.{},
            .attribute_modifiers = &.{.{ .attribute = "jump_strength", .operation = .multiply, .amount = 1.05 }},
            .capability_grants = &.{"dash"},
        },
        .{
            .stable_id = "backpack",
            .occupied_slots = &.{"back"},
            .visual_recipes = &.{attachmentRecipe("backpack_visual", "upper_back", "torso", "accessory", math.Transform2D.init(.{ .x = -0.12, .y = -0.20 }, 0, math.Vec2.one))},
            .covered_body_regions = &.{"torso"},
            .attribute_modifiers = &.{.{ .attribute = "carrying_capacity", .operation = .add, .amount = 20 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "speed_boots",
            .occupied_slots = &.{"shoes"},
            .visual_recipes = &.{everyRecipe("boot", "foot_role", 2, "left_foot", "accessory", math.Transform2D.identity())},
            .covered_body_regions = &.{ "left_foot", "right_foot" },
            .attribute_modifiers = &.{.{ .attribute = "movement_speed", .operation = .multiply, .amount = 1.15 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "winged_boots",
            .occupied_slots = &.{"shoes"},
            .visual_recipes = &.{everyRecipe("boot", "foot_role", 2, "left_foot", "accessory", math.Transform2D.identity())},
            .covered_body_regions = &.{ "left_foot", "right_foot" },
            .attribute_modifiers = &.{},
            .capability_grants = &.{"double_jump"},
        },
    };

    return equipment.Definition.init(allocator, anatomy_definition, appearance_definition, .{
        .equipment_slots = &slots,
        .anatomy_roles = &roles,
        .visual_layers = &layers,
        .visual_components = &components,
        .attributes = &attributes,
        .capabilities = &capabilities,
        .items = &items,
        .default_loadout = &.{ "underwear", "short_sleeve_shirt", "socks", "shoes" },
    });
}

fn component(
    stable_id: []const u8,
    size: math.Vec2,
    tint: [4]f32,
    pivot: [2]f32,
) equipment.VisualComponentInput {
    return .{
        .stable_id = stable_id,
        .sprite_size = size,
        .pivot = pivot,
        .tint = tint,
    };
}

fn torsoLocal() math.Transform2D {
    return math.Transform2D.init(.{ .x = 0, .y = 0.56 }, 0, math.Vec2.one);
}

fn firstRecipe(
    component_name: []const u8,
    role: []const u8,
    region: []const u8,
    layer: []const u8,
    local: math.Transform2D,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component_name,
        .binding = .{ .anatomy = .{
            .role = role,
            .selection = .first_compatible,
            .maximum_matches = 1,
        } },
        .local_to_binding = local,
        .body_region = region,
        .visual_layer = layer,
    };
}

fn everyRecipe(
    component_name: []const u8,
    role: []const u8,
    maximum_matches: u16,
    region: []const u8,
    layer: []const u8,
    local: math.Transform2D,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component_name,
        .binding = .{ .anatomy = .{
            .role = role,
            .selection = .every_compatible,
            .maximum_matches = maximum_matches,
        } },
        .local_to_binding = local,
        .body_region = region,
        .visual_layer = layer,
    };
}

fn specificRecipe(
    component_name: []const u8,
    role: []const u8,
    part: []const u8,
    region: []const u8,
    layer: []const u8,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component_name,
        .binding = .{ .anatomy = .{
            .role = role,
            .selection = .specific_instance,
            .specific_instance = part,
            .maximum_matches = 1,
        } },
        .body_region = region,
        .visual_layer = layer,
    };
}

fn attachmentRecipe(
    component_name: []const u8,
    attachment_point: []const u8,
    region: []const u8,
    layer: []const u8,
    local: math.Transform2D,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component_name,
        .binding = .{ .attachment_point = attachment_point },
        .local_to_binding = local,
        .body_region = region,
        .visual_layer = layer,
    };
}

fn countComponentVisuals(loadout: *const equipment.Loadout, component_id: equipment.VisualComponentId) u16 {
    var count: u16 = 0;
    for (loadout.visuals()) |visual| {
        const recipe = loadout.definition.recipe(visual.recipe) catch return 0;
        if (recipe.component == component_id) count += 1;
    }
    return count;
}

fn loadoutFingerprint(instance: *const character.CharacterInstance) u64 {
    const loadout = &instance.equipment_loadout.?;
    var hash: u64 = 14695981039346656037;
    for (loadout.equippedItems()) |item_id| {
        hash = (hash ^ @as(u64, @intFromEnum(item_id))) *% 1099511628211;
    }
    for (loadout.visuals()) |visual| {
        hash = (hash ^ @as(u64, @intFromEnum(visual.recipe))) *% 1099511628211;
        const source: u64 = switch (visual.source) {
            .anatomy_part => |part_id| @intFromEnum(part_id),
            .attachment_point => |point_id| 0x10000 + @as(u64, @intFromEnum(point_id)),
        };
        hash = (hash ^ source) *% 1099511628211;
    }
    return hash;
}
