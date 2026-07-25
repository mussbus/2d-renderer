const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const mesh = @import("deformable_mesh");
const queue_module = @import("render_queue");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const equipment = @import("equipment");
const modular_body = @import("modular_body_demo");

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
        var definition = try modular_body.initDefinition(allocator);
        errdefer definition.deinit();
        var fitted_garment_mesh = try initFittedGarmentMesh(allocator);
        errdefer fitted_garment_mesh.deinit();
        var sleeve_mesh = try initSleeveMesh(allocator);
        errdefer sleeve_mesh.deinit();
        var cape_mesh = try initCapeMesh(allocator);
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
        const conventional_sleeves = countComponentVisuals(&conventional.equipment_loadout.?, sleeve_component);
        const nonstandard_sleeves = countComponentVisuals(&nonstandard.equipment_loadout.?, sleeve_component);
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
            try scene.conventional.unequipItem(cape_item);
            scene.evidence.cape_unequipped = true;
        } else if (frame == 80) {
            try scene.conventional.equipItem(cape_item);
            scene.evidence.cape_reequipped = true;
        } else if (frame == 120) {
            scene.pre_build_fitted_scale_x = try scene.currentFittedScaleX();
            try scene.conventional.setGlobalBuild(100);
        }
        try scene.conventional.advanceVisualTick(.{});
        try scene.nonstandard.advanceVisualTick(.{});
        scene.visual_ticks += character_count;
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
            !scene.evidence.mirrored_facing)
        {
            return error.MeshAttachmentDemonstrationIncomplete;
        }
    }

    fn observeRuntimeState(scene: *Scene) !void {
        const fitted_component = try scene.equipment_definition.visualComponentId("fitted_torso_mesh");
        const sleeve_component = try scene.equipment_definition.visualComponentId("topology_sleeve_mesh");
        const conventional_loadout = &scene.conventional.equipment_loadout.?;
        const nonstandard_loadout = &scene.nonstandard.equipment_loadout.?;

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
            first.mesh_state.owning_character == scene.conventional.id.raw() and
            second.mesh_state.owning_character == scene.conventional.id.raw() and
            first.mesh_state.bound_identity.encoded() != second.mesh_state.bound_identity.encoded() and
            first.mesh_state.update_serial > 0 and second.mesh_state.update_serial > 0;
        scene.evidence.independent_character_state =
            other_character.mesh_state.owning_character == scene.nonstandard.id.raw() and
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
    }

    fn currentFittedScaleX(scene: *const Scene) !f32 {
        const fitted_component = try scene.equipment_definition.visualComponentId("fitted_torso_mesh");
        const loadout = &scene.conventional.equipment_loadout.?;
        for (loadout.visuals()) |visual| {
            const recipe = try loadout.definition.recipe(visual.recipe);
            if (recipe.component == fitted_component) return visual.mesh_state.resolved_deformation.scale.x;
        }
        return error.MissingFittedMeshState;
    }
};

pub fn initFittedGarmentMesh(allocator: std.mem.Allocator) !mesh.Definition {
    const vertices = [_]mesh.VertexInput{
        vertex(-0.46, -0.58, 0.00, 1.00, 0.85),
        vertex(0.46, -0.58, 1.00, 1.00, 0.85),
        vertex(-0.52, 0.00, 0.00, 0.50, 1.00),
        vertex(0.52, 0.00, 1.00, 0.50, 1.00),
        vertex(-0.40, 0.58, 0.08, 0.00, 1.00),
        vertex(0.40, 0.58, 0.92, 0.00, 1.00),
    };
    const indices = [_]u16{ 0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4 };
    return mesh.Definition.init(allocator, .{
        .stable_id = "fitted_garment_mesh_v1",
        .vertices = &vertices,
        .indices = &indices,
        .material = .{
            .stable_id = "tailored_fabric",
            .texture_page = 0,
            .tint = .{ 0.12, 0.48, 0.82, 1 },
        },
    });
}

pub fn initSleeveMesh(allocator: std.mem.Allocator) !mesh.Definition {
    const vertices = [_]mesh.VertexInput{
        vertex(0.00, -0.15, 0.00, 1.00, 1.00),
        vertex(0.00, 0.15, 0.00, 0.00, 1.00),
        vertex(0.36, -0.13, 0.50, 0.92, 0.90),
        vertex(0.36, 0.13, 0.50, 0.08, 0.90),
        vertex(0.72, -0.10, 1.00, 0.84, 0.75),
        vertex(0.72, 0.10, 1.00, 0.16, 0.75),
    };
    const indices = [_]u16{ 0, 2, 1, 1, 2, 3, 2, 4, 3, 3, 4, 5 };
    return mesh.Definition.init(allocator, .{
        .stable_id = "reusable_sleeve_mesh_v1",
        .vertices = &vertices,
        .indices = &indices,
        .material = .{
            .stable_id = "tailored_fabric",
            .texture_page = 0,
            .tint = .{ 0.12, 0.48, 0.82, 1 },
        },
    });
}

pub fn initCapeMesh(allocator: std.mem.Allocator) !mesh.Definition {
    const vertices = [_]mesh.VertexInput{
        vertex(-0.40, 0.48, 0.00, 0.00, 1.00),
        vertex(0.40, 0.48, 1.00, 0.00, 1.00),
        vertex(-0.50, -0.18, 0.00, 0.45, 0.95),
        vertex(0.48, -0.18, 1.00, 0.45, 0.95),
        vertex(-0.62, -1.08, 0.00, 1.00, 0.80),
        vertex(0.00, -0.94, 0.50, 0.88, 0.85),
        vertex(0.58, -1.08, 1.00, 1.00, 0.80),
    };
    const indices = [_]u16{ 0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4, 3, 6, 5 };
    return mesh.Definition.init(allocator, .{
        .stable_id = "upper_back_cape_mesh_v1",
        .vertices = &vertices,
        .indices = &indices,
        .material = .{
            .stable_id = "cape_fabric",
            .texture_page = 0,
            .tint = .{ 0.44, 0.12, 0.52, 0.92 },
        },
    });
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
        meshComponent("fitted_torso_mesh", fitted, .{ .morphology = 1, .breathing = 1 }),
        meshComponent("topology_sleeve_mesh", sleeve, .{ .morphology = 0.9, .breathing = 0.8 }),
        meshComponent("cape_mesh", cape, .{ .morphology = 0.65, .breathing = 0.6 }),
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
) equipment.VisualComponentInput {
    return .{
        .stable_id = stable_id,
        .sprite_size = .{ .x = 1, .y = 1 },
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 1, 1 },
        .tint = definition.material.tint,
        .texture_page = definition.material.texture_page,
        .deformation_response = response,
        .primitive = .{ .deformable_mesh = definition },
    };
}

fn vertex(x: f32, y: f32, u: f32, v: f32, weight: f32) mesh.VertexInput {
    return .{
        .local_position = .{ .x = x, .y = y },
        .uv = .{ u, v },
        .deformation_weight = weight,
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
