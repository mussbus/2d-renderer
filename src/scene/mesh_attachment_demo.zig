const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const attachment_secondary_motion = @import("attachment_secondary_motion");
const mesh = @import("deformable_mesh");
const queue_module = @import("render_queue");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const equipment = @import("equipment");
const modular_humanoid = @import("modular_humanoid");
const attachment_meshes = @import("attachment_meshes");

pub const required_frames: u32 = 240;
pub const character_count: usize = 2;
pub const mesh_definition_count: usize = 3;
pub const expected_conventional_sleeves: u16 = 2;
pub const expected_nonstandard_sleeves: u16 = 4;

pub const Evidence = struct {
    conventional_sleeves: u16 = 0,
    nonstandard_sleeves: u16 = 0,
    cape_unequipped: bool = false,
    cape_reequipped: bool = false,
    independent_repeated_state: bool = false,
    independent_character_state: bool = false,
    deformation_changed: bool = false,
    breathing_deformation_changed: bool = false,
    build_deformation_changed: bool = false,
    mirrored_facing: bool = false,
    cape_acceleration_trails: bool = false,
    cape_sustained_motion_trails: bool = false,
    cape_reversal_changes_target: bool = false,
    cape_sudden_stop_changes_target: bool = false,
    cape_jump_trails_down: bool = false,
    cape_fall_trails_up: bool = false,
    cape_landing_impulse_consumed: bool = false,
    cape_runtime_removed: bool = false,
    cape_reequip_reset: bool = false,
    facing_change_reset: bool = false,
    long_hair_moved: bool = false,
    ponytail_moved: bool = false,
    repeated_secondary_state_independent: bool = false,
};

pub const Scene = struct {
    definition: humanoid.HumanoidDefinition,
    fitted_garment_mesh: mesh.Definition,
    sleeve_mesh: mesh.Definition,
    cape_mesh: mesh.Definition,
    equipment_definition: equipment.Definition,
    shared_animations: authored.Definitions,
    id_allocator: character.EntityIdAllocator,
    conventional: character.CharacterInstance,
    nonstandard: character.CharacterInstance,
    evidence: Evidence = .{},
    visual_ticks: u64 = 0,
    initial_fitted_scale_x: ?f32 = null,
    pre_build_fitted_scale_x: ?f32 = null,

    pub fn init(allocator: std.mem.Allocator) !Scene {
        var definition = try modular_humanoid.initDefinition(allocator);
        errdefer definition.deinit();
        var fitted_garment_mesh = try attachment_meshes.initFittedGarmentMesh(allocator);
        errdefer fitted_garment_mesh.deinit();
        var sleeve_mesh = try attachment_meshes.initSleeveMesh(allocator);
        errdefer sleeve_mesh.deinit();
        var cape_mesh = try attachment_meshes.initCapeMesh(allocator);
        errdefer cape_mesh.deinit();
        var equipment_definition = try initEquipmentDefinition(
            allocator,
            &definition,
            fitted_garment_mesh.view(),
            sleeve_mesh.view(),
            cape_mesh.view(),
        );
        errdefer equipment_definition.deinit();
        var shared_animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer shared_animations.deinit();
        var id_allocator = character.EntityIdAllocator{};

        var conventional = try character.CharacterInstance.init(
            allocator,
            try id_allocator.allocate(),
            &definition,
            &shared_animations,
            .{ .x = -1.55, .y = 0 },
            .right,
            0,
            null,
        );
        errdefer conventional.deinit();
        var nonstandard = try character.CharacterInstance.init(
            allocator,
            try id_allocator.allocate(),
            &definition,
            &shared_animations,
            .{ .x = 1.55, .y = 0 },
            .left,
            1,
            null,
        );
        errdefer nonstandard.deinit();

        const anatomy_definition = definition.anatomy_definition.?.view();
        try conventional.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_female"));
        try nonstandard.selectBodyPreset(try anatomy_definition.bodyPresetId("nonstandard_humanoid"));
        try conventional.configureBreathing(try deformation.BreathingConfiguration.init(960, 0.8));
        try nonstandard.configureBreathing(try deformation.BreathingConfiguration.init(720, 0.65));
        try nonstandard.setBreathingPhaseTick(180);
        try conventional.initializeEquipment(equipment_definition.view());
        try nonstandard.initializeEquipment(equipment_definition.view());

        const tailored_set = try equipment_definition.itemId("tailored_mesh_set");
        const cape_item = try equipment_definition.itemId("upper_back_cape");
        try conventional.equipItem(tailored_set);
        try conventional.equipItem(cape_item);
        try nonstandard.equipItem(tailored_set);
        try nonstandard.equipItem(cape_item);

        const sleeve_component = try equipment_definition.visualComponentId("topology_sleeve_mesh");
        const conventional_sleeves = countComponentVisuals(conventional.equipmentView().?, sleeve_component);
        const nonstandard_sleeves = countComponentVisuals(nonstandard.equipmentView().?, sleeve_component);
        if (conventional_sleeves != expected_conventional_sleeves or nonstandard_sleeves != expected_nonstandard_sleeves) {
            return error.TopologyAwareMeshExpansionEvidenceMissing;
        }

        return .{
            .definition = definition,
            .fitted_garment_mesh = fitted_garment_mesh,
            .sleeve_mesh = sleeve_mesh,
            .cape_mesh = cape_mesh,
            .equipment_definition = equipment_definition,
            .shared_animations = shared_animations,
            .id_allocator = id_allocator,
            .conventional = conventional,
            .nonstandard = nonstandard,
            .evidence = .{
                .conventional_sleeves = conventional_sleeves,
                .nonstandard_sleeves = nonstandard_sleeves,
            },
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.nonstandard.deinit();
        scene.conventional.deinit();
        scene.shared_animations.deinit();
        scene.equipment_definition.deinit();
        scene.cape_mesh.deinit();
        scene.sleeve_mesh.deinit();
        scene.fitted_garment_mesh.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn meshDefinitions(scene: *const Scene) [mesh_definition_count]mesh.DefinitionView {
        return .{
            scene.fitted_garment_mesh.view(),
            scene.sleeve_mesh.view(),
            scene.cape_mesh.view(),
        };
    }

    pub fn updateFrame(scene: *Scene, frame: u32) !void {
        const cape_item = try scene.equipment_definition.itemId("upper_back_cape");
        if (frame == 40) {
            const cape_index = try scene.findEquipmentVisualIndex(&scene.conventional, "cape_mesh");
            if (!scene.conventional.equipmentView().?.resolved_visuals[cape_index].secondary.initialized) {
                return error.CapeMotionWasNotInitializedBeforeUnequip;
            }
            try scene.conventional.unequipItem(cape_item);
            scene.evidence.cape_unequipped = true;
            const cape_missing = missing: {
                _ = scene.findEquipmentVisualIndex(&scene.conventional, "cape_mesh") catch |err| {
                    if (err == error.MissingEquipmentVisual) break :missing true;
                    return err;
                };
                break :missing false;
            };
            scene.evidence.cape_runtime_removed =
                !scene.conventional.equipmentView().?.resolved_visuals[cape_index].secondary.initialized and
                cape_missing;
        } else if (frame == 80) {
            try scene.conventional.equipItem(cape_item);
            scene.evidence.cape_reequipped = true;
        } else if (frame == 120) {
            scene.pre_build_fitted_scale_x = try scene.currentFittedScaleX();
            try scene.conventional.setGlobalBuild(100);
        } else if (frame == 206) {
            try scene.conventional.setFacing(.left);
            try scene.nonstandard.setFacing(.right);
        }
        const conventional_input = scriptedMotionInput(frame);
        var nonstandard_input = conventional_input;
        nonstandard_input.horizontal_velocity *= -0.45;
        nonstandard_input.vertical_velocity *= 0.65;
        try scene.conventional.advanceVisualTick(conventional_input);
        try scene.nonstandard.advanceVisualTick(nonstandard_input);
        scene.visual_ticks += character_count;
        if (frame == 80) {
            const state = try scene.equipmentSecondaryState(&scene.conventional, "cape_mesh");
            const displacement_value = try state.displacement(attachment_meshes.cape_secondary_motion, 2);
            scene.evidence.cape_reequip_reset =
                state.initialized and state.reset_count == 1 and displacement_value.approxEqAbs(math.Vec2.zero, 0);
        }
    }

    pub fn submit(scene: *Scene, queue: *queue_module.UnifiedRenderQueue) !u32 {
        const count = try character.submitUnifiedGlobally(&.{ &scene.conventional, &scene.nonstandard }, queue);
        try scene.observeRuntimeState();
        return count;
    }

    pub fn validateComplete(scene: *const Scene) !void {
        if (scene.visual_ticks != @as(u64, required_frames) * character_count or
            scene.evidence.conventional_sleeves != expected_conventional_sleeves or
            scene.evidence.nonstandard_sleeves != expected_nonstandard_sleeves or
            !scene.evidence.cape_unequipped or
            !scene.evidence.cape_reequipped or
            !scene.evidence.independent_repeated_state or
            !scene.evidence.independent_character_state or
            !scene.evidence.deformation_changed or
            !scene.evidence.breathing_deformation_changed or
            !scene.evidence.build_deformation_changed or
            !scene.evidence.mirrored_facing or
            !scene.evidence.cape_acceleration_trails or
            !scene.evidence.cape_sustained_motion_trails or
            !scene.evidence.cape_reversal_changes_target or
            !scene.evidence.cape_sudden_stop_changes_target or
            !scene.evidence.cape_jump_trails_down or
            !scene.evidence.cape_fall_trails_up or
            !scene.evidence.cape_landing_impulse_consumed or
            !scene.evidence.cape_runtime_removed or
            !scene.evidence.cape_reequip_reset or
            !scene.evidence.facing_change_reset or
            !scene.evidence.long_hair_moved or
            !scene.evidence.ponytail_moved or
            !scene.evidence.repeated_secondary_state_independent)
        {
            return error.MeshAttachmentDemonstrationIncomplete;
        }
    }

    fn observeRuntimeState(scene: *Scene) !void {
        const fitted_component = try scene.equipment_definition.visualComponentId("fitted_torso_mesh");
        const sleeve_component = try scene.equipment_definition.visualComponentId("topology_sleeve_mesh");
        const conventional_loadout = scene.conventional.equipmentView().?;
        const nonstandard_loadout = scene.nonstandard.equipmentView().?;

        var first_conventional_sleeve: ?*const equipment.ResolvedVisualInstance = null;
        var second_conventional_sleeve: ?*const equipment.ResolvedVisualInstance = null;
        var first_nonstandard_sleeve: ?*const equipment.ResolvedVisualInstance = null;
        var conventional_fitted: ?*const equipment.ResolvedVisualInstance = null;
        for (conventional_loadout.visuals()) |*visual| {
            const recipe = try conventional_loadout.definition.recipe(visual.recipe);
            if (recipe.component == fitted_component) conventional_fitted = visual;
            if (recipe.component == sleeve_component) {
                if (first_conventional_sleeve == null) {
                    first_conventional_sleeve = visual;
                } else if (second_conventional_sleeve == null) {
                    second_conventional_sleeve = visual;
                }
            }
        }
        for (nonstandard_loadout.visuals()) |*visual| {
            const recipe = try nonstandard_loadout.definition.recipe(visual.recipe);
            if (recipe.component == sleeve_component and first_nonstandard_sleeve == null) first_nonstandard_sleeve = visual;
        }

        const first = first_conventional_sleeve orelse return error.MissingConventionalSleeveState;
        const second = second_conventional_sleeve orelse return error.MissingConventionalSleeveState;
        const other_character = first_nonstandard_sleeve orelse return error.MissingNonstandardSleeveState;
        const fitted = conventional_fitted orelse return error.MissingFittedMeshState;
        scene.evidence.independent_repeated_state =
            first.mesh_state.owning_character == scene.conventional.id().raw() and
            second.mesh_state.owning_character == scene.conventional.id().raw() and
            first.mesh_state.bound_identity.encoded() != second.mesh_state.bound_identity.encoded() and
            first.mesh_state.update_serial > 0 and second.mesh_state.update_serial > 0;
        scene.evidence.repeated_secondary_state_independent =
            first.secondary.initialized and second.secondary.initialized and
            &first.secondary != &second.secondary and
            first.mesh_state.bound_identity.encoded() != second.mesh_state.bound_identity.encoded();
        scene.evidence.independent_character_state =
            other_character.mesh_state.owning_character == scene.nonstandard.id().raw() and
            other_character.mesh_state.owning_character != first.mesh_state.owning_character;
        scene.evidence.mirrored_facing =
            first.mesh_state.binding_world.values[0] * other_character.mesh_state.binding_world.values[0] < 0;
        if (scene.initial_fitted_scale_x) |initial| {
            if (@abs(fitted.mesh_state.resolved_deformation.scale.x - initial) > 1e-4) {
                scene.evidence.breathing_deformation_changed = true;
            }
        } else {
            scene.initial_fitted_scale_x = fitted.mesh_state.resolved_deformation.scale.x;
        }
        if (scene.pre_build_fitted_scale_x) |pre_build| {
            if (@abs(fitted.mesh_state.resolved_deformation.scale.x - pre_build) > 1e-4) {
                scene.evidence.build_deformation_changed = true;
            }
        }
        scene.evidence.deformation_changed =
            scene.evidence.breathing_deformation_changed and scene.evidence.build_deformation_changed;

        const conventional_tick = scene.conventional.simulationTick();
        if (scene.findEquipmentSecondaryState(&scene.conventional, "cape_mesh")) |cape_state| {
            const displacement_value = try cape_state.displacement(attachment_meshes.cape_secondary_motion, 2);
            const target_x = cape_state.points[2].horizontal.target_offset;
            if (conventional_tick >= 25 and conventional_tick < 40 and displacement_value.x < 0) {
                scene.evidence.cape_acceleration_trails = true;
            }
            if (conventional_tick >= 100 and conventional_tick < 111 and displacement_value.x < 0) {
                scene.evidence.cape_sustained_motion_trails = true;
            }
            if (conventional_tick >= 112 and conventional_tick < 146 and target_x > 0) {
                scene.evidence.cape_reversal_changes_target = true;
            }
            if (conventional_tick >= 147 and conventional_tick < 154 and target_x < 0) {
                scene.evidence.cape_sudden_stop_changes_target = true;
            }
            if (conventional_tick >= 155 and conventional_tick < 166 and cape_state.points[2].vertical.target_offset < 0) {
                scene.evidence.cape_jump_trails_down = true;
            }
            if (conventional_tick >= 167 and conventional_tick < 186 and cape_state.points[2].vertical.target_offset > 0) {
                scene.evidence.cape_fall_trails_up = true;
            }
            if (conventional_tick == 187 and cape_state.points[2].vertical.velocity < 0) {
                scene.evidence.cape_landing_impulse_consumed = true;
            }
            if (conventional_tick == 207) {
                scene.evidence.facing_change_reset =
                    cape_state.reset_count == 1 and displacement_value.approxEqAbs(math.Vec2.zero, 0);
            }
        } else |_| {}

        const appearance_definition = scene.definition.visual_definition.view();
        const long_hair_id = try scene.definition.visual_definition.visualId("long_hair");
        const ponytail_id = try scene.definition.visual_definition.visualId("ponytail_hair");
        const long_hair_state = try scene.conventional.humanoidView().appearance_runtime.visualSecondaryState(
            appearance_definition,
            long_hair_id,
        );
        const ponytail_state = try scene.nonstandard.humanoidView().appearance_runtime.visualSecondaryState(
            appearance_definition,
            ponytail_id,
        );
        scene.evidence.long_hair_moved = scene.evidence.long_hair_moved or
            (long_hair_state.initialized and
                !(try long_hair_state.displacement(modular_humanoid.long_hair_secondary_motion, 2)).approxEqAbs(math.Vec2.zero, 0.00001));
        scene.evidence.ponytail_moved = scene.evidence.ponytail_moved or
            (ponytail_state.initialized and
                !(try ponytail_state.displacement(modular_humanoid.ponytail_secondary_motion, 2)).approxEqAbs(math.Vec2.zero, 0.00001));
    }

    fn currentFittedScaleX(scene: *const Scene) !f32 {
        const fitted_component = try scene.equipment_definition.visualComponentId("fitted_torso_mesh");
        const loadout = scene.conventional.equipmentView().?;
        for (loadout.visuals()) |visual| {
            const recipe = try loadout.definition.recipe(visual.recipe);
            if (recipe.component == fitted_component) return visual.mesh_state.resolved_deformation.scale.x;
        }
        return error.MissingFittedMeshState;
    }

    fn findEquipmentVisualIndex(
        scene: *const Scene,
        instance: *const character.CharacterInstance,
        component_name: []const u8,
    ) !usize {
        const component_id = try scene.equipment_definition.visualComponentId(component_name);
        const loadout = instance.equipmentView().?;
        for (loadout.visuals(), 0..) |visual, index| {
            const recipe = try loadout.definition.recipe(visual.recipe);
            if (recipe.component == component_id) return index;
        }
        return error.MissingEquipmentVisual;
    }

    fn findEquipmentSecondaryState(
        scene: *const Scene,
        instance: *const character.CharacterInstance,
        component_name: []const u8,
    ) !*const attachment_secondary_motion.RuntimeState {
        const index = try scene.findEquipmentVisualIndex(instance, component_name);
        return &instance.equipmentView().?.resolved_visuals[index].secondary;
    }

    pub fn equipmentSecondaryState(
        scene: *const Scene,
        instance: *const character.CharacterInstance,
        component_name: []const u8,
    ) !*const attachment_secondary_motion.RuntimeState {
        return scene.findEquipmentSecondaryState(instance, component_name);
    }
};

fn scriptedMotionInput(frame: u32) character.VisualTickInput {
    if (frame < 20) return .{};
    if (frame < 111) return .{ .horizontal_velocity = 4.0 };
    if (frame < 146) return .{ .horizontal_velocity = -4.0 };
    if (frame < 154) return .{};
    if (frame < 166) return .{
        .vertical_velocity = 4.0,
        .physically_grounded = false,
    };
    if (frame < 186) return .{
        .vertical_velocity = -5.0,
        .physically_grounded = false,
    };
    if (frame == 186) return .{
        .landing_event = .{ .simulation_tick = frame + 1, .impact_speed = 6.0 },
    };
    if (frame >= 206 and frame < 224) return .{ .horizontal_velocity = -3.0 };
    return .{};
}

fn initEquipmentDefinition(
    allocator: std.mem.Allocator,
    humanoid_definition: *const humanoid.HumanoidDefinition,
    fitted: mesh.DefinitionView,
    sleeve: mesh.DefinitionView,
    cape: mesh.DefinitionView,
) !equipment.Definition {
    const anatomy_definition = humanoid_definition.anatomy_definition.?.view();
    const appearance_definition = humanoid_definition.visual_definition.view();
    const slots = [_]equipment.EquipmentSlotInput{
        .{ .stable_id = "tailored_outfit" },
        .{ .stable_id = "back" },
    };
    const roles = [_]equipment.AnatomyRoleInput{
        .{ .stable_id = "torso_role", .compatible_part_type = "torso" },
        .{ .stable_id = "upper_arm_role", .compatible_part_type = "upper_arm" },
    };
    const layers = [_]equipment.VisualLayerInput{
        .{ .stable_id = "cape_behind_body", .render_layer = 5 },
        .{ .stable_id = "sleeve_between_limbs", .render_layer = 23 },
        .{ .stable_id = "fitted_over_torso", .render_layer = 33 },
        .{ .stable_id = "accessory_over_clothing", .render_layer = 70 },
    };
    const components = [_]equipment.VisualComponentInput{
        meshComponent("fitted_torso_mesh", fitted, .{ .morphology = 1, .breathing = 1 }, null),
        meshComponent("topology_sleeve_mesh", sleeve, .{ .morphology = 0.9, .breathing = 0.8 }, attachment_meshes.loose_sleeve_secondary_motion),
        meshComponent("cape_mesh", cape, .{ .morphology = 0.65, .breathing = 0.6 }, attachment_meshes.cape_secondary_motion),
        .{
            .stable_id = "rigid_collar_clasp",
            .sprite_size = .{ .x = 0.18, .y = 0.14 },
            .pivot = .{ 0.5, 0.5 },
            .uv_rect = .{ 0, 0, 0.5, 0.5 },
            .tint = .{ 0.94, 0.72, 0.18, 1 },
            .texture_page = 0,
            .deformation_response = .{ .morphology = 0.2, .breathing = 0.2 },
        },
    };
    const items = [_]equipment.EquipmentItemInput{
        .{
            .stable_id = "tailored_mesh_set",
            .occupied_slots = &.{"tailored_outfit"},
            .visual_recipes = &.{
                firstRecipe("fitted_torso_mesh", "torso_role", "torso", "fitted_over_torso", torsoLocal()),
                everyRecipe("topology_sleeve_mesh", "upper_arm_role", 4, "left_arm", "sleeve_between_limbs", math.Transform2D.identity()),
                firstRecipe("rigid_collar_clasp", "torso_role", "torso", "accessory_over_clothing", math.Transform2D.init(.{ .x = 0, .y = 1.02 }, 0, math.Vec2.one)),
            },
            .covered_body_regions = &.{ "torso", "left_arm", "right_arm" },
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "upper_back_cape",
            .occupied_slots = &.{"back"},
            .visual_recipes = &.{
                firstRecipe("cape_mesh", "torso_role", "torso", "cape_behind_body", math.Transform2D.init(.{ .x = -0.08, .y = 0.58 }, 0, math.Vec2.one)),
            },
            .covered_body_regions = &.{"torso"},
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
    };
    return equipment.Definition.init(allocator, anatomy_definition, appearance_definition, .{
        .equipment_slots = &slots,
        .anatomy_roles = &roles,
        .visual_layers = &layers,
        .visual_components = &components,
        .attributes = &.{},
        .capabilities = &.{},
        .items = &items,
    });
}

fn meshComponent(
    stable_id: []const u8,
    definition: mesh.DefinitionView,
    response: deformation.Response,
    motion_definition: ?attachment_secondary_motion.Definition,
) equipment.VisualComponentInput {
    return .{
        .stable_id = stable_id,
        .sprite_size = .{ .x = 1, .y = 1 },
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 1, 1 },
        .tint = definition.material.tint,
        .texture_page = definition.material.texture_page,
        .deformation_response = response,
        .secondary_motion = motion_definition,
        .primitive = .{ .deformable_mesh = definition },
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

fn countComponentVisuals(loadout: *const equipment.Loadout, component_id: equipment.VisualComponentId) u16 {
    var count: u16 = 0;
    for (loadout.visuals()) |visual| {
        const recipe = loadout.definition.recipe(visual.recipe) catch return 0;
        if (recipe.component == component_id) count += 1;
    }
    return count;
}
