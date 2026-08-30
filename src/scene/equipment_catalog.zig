const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const humanoid = @import("humanoid");
const equipment = @import("equipment");

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
        .{ .stable_id = "armor", .base_value = 0, .minimum = 0, .maximum = 10_000 },
        .{ .stable_id = "physical_damage_reduction", .base_value = 0, .minimum = 0, .maximum = 0.95 },
        .{ .stable_id = "movement_speed", .base_value = 4.5, .minimum = 0.1, .maximum = 20 },
        .{ .stable_id = "jump_strength", .base_value = 9, .minimum = 3.51, .maximum = 30 },
        .{ .stable_id = "carrying_capacity", .base_value = 50, .minimum = 0, .maximum = 10_000 },
    };
    const capabilities = [_]equipment.CapabilityDefinitionInput{
        .{ .stable_id = "double_jump" },
        .{ .stable_id = "dash" },
    };
    const components = [_]equipment.VisualComponentInput{
        component("pelvis_underwear_visual", .{ .x = 0.74, .y = 0.34 }, .{ 0.18, 0.20, 0.34, 1 }, .{ 0.5, 0.5 }, .{ .breathing = 0 }),
        component("chest_underwear_visual", .{ .x = 0.82, .y = 0.40 }, .{ 0.78, 0.32, 0.52, 1 }, .{ 0.5, 0.5 }, .{ .morphology = 0.95 }),
        component("shirt_torso", .{ .x = 0.92, .y = 1.18 }, .{ 0.12, 0.48, 0.82, 1 }, .{ 0.5, 0.5 }, .{}),
        component("short_sleeve", .{ .x = 0.34, .y = 0.23 }, .{ 0.12, 0.48, 0.82, 1 }, .{ 0, 0.5 }, .{ .breathing = 0.8 }),
        component("sweatshirt_torso", .{ .x = 1.00, .y = 1.24 }, .{ 0.72, 0.22, 0.18, 1 }, .{ 0.5, 0.5 }, .{ .morphology = 0.9, .breathing = 0.85 }),
        component("long_sleeve", .{ .x = 0.72, .y = 0.25 }, .{ 0.72, 0.22, 0.18, 1 }, .{ 0, 0.5 }, .{ .breathing = 0.75 }),
        component("sock", .{ .x = 0.34, .y = 0.20 }, .{ 0.92, 0.92, 0.92, 1 }, .{ 0, 0.5 }, .{ .morphology = 0.7, .breathing = 0 }),
        component("shoe", .{ .x = 0.42, .y = 0.24 }, .{ 0.12, 0.12, 0.16, 1 }, .{ 0, 0.5 }, .{ .morphology = 0.2, .breathing = 0 }),
        component("boot", .{ .x = 0.46, .y = 0.30 }, .{ 0.22, 0.42, 0.16, 1 }, .{ 0, 0.5 }, .{ .morphology = 0.25, .breathing = 0 }),
        component("shoulder_plate", .{ .x = 0.30, .y = 0.28 }, .{ 0.62, 0.66, 0.72, 1 }, .{ 0.2, 0.5 }, .{ .morphology = 0.15, .breathing = 0 }),
        component("gauntlet", .{ .x = 0.30, .y = 0.24 }, .{ 0.58, 0.62, 0.70, 1 }, .{ 0, 0.5 }, .{ .morphology = 0, .breathing = 0 }),
        component("armor_torso", .{ .x = 1.02, .y = 1.16 }, .{ 0.46, 0.50, 0.58, 1 }, .{ 0.5, 0.5 }, .{ .morphology = 0.1, .breathing = 0 }),
        component("amulet_visual", .{ .x = 0.18, .y = 0.24 }, .{ 0.92, 0.72, 0.16, 1 }, .{ 0.5, 0.9 }, .{ .morphology = 0, .breathing = 0 }),
        component("backpack_visual", .{ .x = 0.72, .y = 0.92 }, .{ 0.28, 0.20, 0.12, 1 }, .{ 0.5, 0.5 }, .{ .morphology = 0, .breathing = 0 }),
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
            .stable_id = "feather_amulet",
            .occupied_slots = &.{"neck_accessory"},
            .visual_recipes = &.{attachmentRecipe("amulet_visual", "neck", "torso", "accessory", math.Transform2D.init(.{ .x = 0, .y = -0.08 }, 0, math.Vec2.one))},
            .covered_body_regions = &.{},
            .attribute_modifiers = &.{},
            .capability_grants = &.{"double_jump"},
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
            .stable_id = "spring_boots",
            .occupied_slots = &.{"shoes"},
            .visual_recipes = &.{everyRecipe("boot", "foot_role", 2, "left_foot", "accessory", math.Transform2D.identity())},
            .covered_body_regions = &.{ "left_foot", "right_foot" },
            .attribute_modifiers = &.{.{ .attribute = "jump_strength", .operation = .multiply, .amount = 1.20 }},
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
    response: deformation.Response,
) equipment.VisualComponentInput {
    return .{
        .stable_id = stable_id,
        .sprite_size = size,
        .pivot = pivot,
        .tint = tint,
        .deformation_response = response,
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
