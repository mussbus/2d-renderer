const std = @import("std");
const math = @import("math");
const mesh = @import("deformable_mesh");
const equipment = @import("equipment");
const humanoid = @import("humanoid");
const character = @import("character");
const presentation_pose = @import("presentation_pose");
const presentation_view = @import("presentation_view");
const render_queue = @import("render_queue");
const sprite = @import("sprite_batch");
const wardrobe_art = @import("wardrobe_art");
const wardrobe_catalog = @import("wardrobe_catalog");

pub const mesh_definition_count: usize = 2;

const ViewBinding = struct {
    side: wardrobe_art_resolved = undefined,
    front: wardrobe_art_resolved = undefined,
};

const wardrobe_art_resolved = @import("art_pack").ResolvedVisual;

const ComponentBinding = struct {
    active: bool = false,
    anchor: wardrobe_catalog.AnchorKind = .torso,
    views: ViewBinding = .{},
};

pub const Presentation = struct {
    renderer_page_offset: u32,
    component_count: usize,
    bindings: [equipment.maximum_visual_components]ComponentBinding =
        [_]ComponentBinding{.{}} ** equipment.maximum_visual_components,
    side_skirt_mesh: mesh.Definition,
    front_skirt_mesh: mesh.Definition,

    pub fn init(
        allocator: std.mem.Allocator,
        art_definition: *const wardrobe_art.Definition,
        catalog: *const wardrobe_catalog.Catalog,
        renderer_page_offset: u32,
    ) !Presentation {
        try art_definition.validateCatalog(catalog);
        var bindings = [_]ComponentBinding{.{}} ** equipment.maximum_visual_components;
        for (catalog.equipment_definition.visual_components) |component| {
            const presentation_semantic = component.presentation_semantic orelse
                return error.MissingPresentationSemantic;
            const spec = specForSemantic(presentation_semantic) orelse
                return error.UnknownWardrobeSemantic;
            bindings[component.id.index()] = .{
                .active = true,
                .anchor = spec.anchor,
                .views = .{
                    .side = try art_definition.resolve(presentation_semantic, false),
                    .front = try art_definition.resolve(presentation_semantic, true),
                },
            };
        }

        const skirt_component = try catalog.equipment_definition.visualComponentId(
            "garnet_split_skirt",
        );
        const skirt_binding = bindings[skirt_component.index()];
        var side_skirt_mesh = try initSkirtMesh(
            allocator,
            "p25_skirt_side_mesh",
            "p25_skirt_side_material",
            skirt_binding.views.side,
            renderer_page_offset,
        );
        errdefer side_skirt_mesh.deinit();
        var front_skirt_mesh = try initSkirtMesh(
            allocator,
            "p25_skirt_front_mesh",
            "p25_skirt_front_material",
            skirt_binding.views.front,
            renderer_page_offset,
        );
        errdefer front_skirt_mesh.deinit();

        return .{
            .renderer_page_offset = renderer_page_offset,
            .component_count = catalog.equipment_definition.visual_components.len,
            .bindings = bindings,
            .side_skirt_mesh = side_skirt_mesh,
            .front_skirt_mesh = front_skirt_mesh,
        };
    }

    pub fn deinit(presentation: *Presentation) void {
        presentation.front_skirt_mesh.deinit();
        presentation.side_skirt_mesh.deinit();
        presentation.* = undefined;
    }

    pub fn meshDefinitions(
        presentation: *const Presentation,
    ) [mesh_definition_count]mesh.DefinitionView {
        return .{
            presentation.side_skirt_mesh.view(),
            presentation.front_skirt_mesh.view(),
        };
    }

    pub fn validateCompleteness(
        presentation: Presentation,
        catalog: *const wardrobe_catalog.Catalog,
    ) !void {
        if (presentation.component_count != catalog.equipment_definition.visual_components.len) {
            return error.WardrobePresentationDefinitionMismatch;
        }
        for (catalog.equipment_definition.visual_components) |component| {
            const binding = presentation.bindings[component.id.index()];
            if (!binding.active or
                binding.views.side.semantic_id != binding.views.front.semantic_id or
                binding.views.side.region_id == binding.views.front.region_id)
            {
                return error.IncompleteWardrobePresentation;
            }
        }
    }

    pub fn submit(
        presentation: *Presentation,
        instance: *character.CharacterInstance,
        queue: *render_queue.UnifiedRenderQueue,
    ) !u32 {
        const loadout = if (instance.equipment_loadout) |*value| value else return error.CharacterEquipmentNotInitialized;
        const anatomy_definition = instance.definition.anatomy_definition orelse
            return error.CharacterHasNoAnatomy;
        const anatomy_runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try loadout.validateCompatibility(.{
            .definition = anatomy_definition,
            .runtime = anatomy_runtime,
            .owning_character = instance.id.raw(),
        });
        if (loadout.definition.appearance_token != instance.definition.visual_definition.owner_token) {
            return error.EquipmentAppearanceDefinitionMismatch;
        }

        const view = instance.presentationView();
        const projection = switch (view) {
            .front => try presentation_pose.FrontProjection.init(
                &instance.definition.skeleton_definition,
                instance.character.local_and_world_pose,
                instance.definition.visual_definition,
                instance.character.appearance_runtime,
                instance.world_position,
            ),
            .side => try presentation_pose.FrontProjection.initSide(
                &instance.definition.skeleton_definition,
                instance.character.local_and_world_pose,
                instance.definition.visual_definition,
                instance.character.appearance_runtime,
                instance.world_position,
                instance.facing == .left,
            ),
        };
        const projected_anatomy = try presentation_pose.FrontAnatomyProjection.init(
            projection,
            anatomy_definition,
            anatomy_runtime.*,
        );

        var submitted: u32 = 0;
        var visual_index: usize = 0;
        while (visual_index < loadout.visuals().len) : (visual_index += 1) {
            const visual = loadout.visuals()[visual_index];
            const recipe = try loadout.definition.recipe(visual.recipe);
            if (recipe.component.index() >= presentation.component_count or
                recipe.visual_layer.index() >= loadout.definition.visual_layers.len)
            {
                return error.InvalidEquipmentVisualReference;
            }
            const component = loadout.definition.visual_components[recipe.component.index()];
            const binding = presentation.bindings[component.id.index()];
            if (!binding.active) return error.MissingWardrobePresentationBinding;
            const selected = if (view == .front) binding.views.front else binding.views.side;
            const resolved = try projectedEquipmentTransform(
                instance,
                visual_index,
                projection,
                projected_anatomy,
            );
            const layer = loadout.definition.visual_layers[recipe.visual_layer.index()];
            const order = sprite.OrderInput{
                .scene_layer = character.characters_scene_layer,
                .interaction_layer = character.neutral_interaction_layer,
                .actor_layer = instance.actor_layer,
                .body_part_layer = layer.render_layer,
            };

            if (component.presentation_semantic == semantic(25_032)) {
                const definition = if (view == .front)
                    presentation.front_skirt_mesh.view()
                else
                    presentation.side_skirt_mesh.view();
                const composed_deformation = try resolved.composedDeformation();
                try loadout.resolved_visuals[visual_index].mesh_state.update(
                    instance.id.raw(),
                    resolved.bound_identity,
                    resolved.binding_world,
                    composed_deformation,
                );
                _ = try queue.submitMesh(.{
                    .definition = definition,
                    .binding_world = resolved.binding_world,
                    .resolved_deformation = composed_deformation,
                    .owning_character = instance.id.raw(),
                    .bound_identity = resolved.bound_identity,
                    .order = order,
                });
            } else {
                const sprite_transform = try humanoid.spriteTransform(try resolved.world());
                var world_size = sprite_transform.signed_scale.componentMul(.{
                    .x = selected.authored_size[0],
                    .y = selected.authored_size[1],
                });
                var pivot = selected.pivot;
                if (view == .front) {
                    const bound_to_left_part = switch (visual.source) {
                        .anatomy_part => |part_id| std.mem.startsWith(
                            u8,
                            anatomy_definition.part_instances[part_id.index()].stable_id.slice(),
                            "left_",
                        ),
                        .attachment_point => false,
                    };
                    if (bound_to_left_part) {
                        world_size.x = -world_size.x;
                        pivot[0] = 1.0 - pivot[0];
                    }
                }
                _ = try queue.submitSprite(.{
                    .world_position = sprite_transform.world_position.toArray(),
                    .rotation = sprite_transform.rotation_radians +
                        restRotation(binding.anchor, view, instance.facing),
                    .scale = world_size.toArray(),
                    .pivot = pivot,
                    .uv_rect = selected.uv_rect,
                    .tint = .{ 1, 1, 1, 1 },
                    .texture_page = presentation.renderer_page_offset + selected.texture_page,
                    .order = order,
                });
            }
            submitted += 1;
        }
        return submitted;
    }
};

fn semantic(raw: u32) equipment.PresentationSemanticId {
    return @enumFromInt(raw);
}

fn specForSemantic(
    semantic_id: equipment.PresentationSemanticId,
) ?wardrobe_catalog.VisualSpec {
    for (wardrobe_catalog.visual_specs) |spec| {
        if (spec.semantic == semantic_id) return spec;
    }
    return null;
}

fn restRotation(
    anchor: wardrobe_catalog.AnchorKind,
    view: presentation_view.View,
    facing: humanoid.Facing,
) f32 {
    return switch (anchor) {
        .upper_arm, .hand, .lower_leg => if (view == .side and facing == .left)
            -std.math.pi / 2.0
        else
            std.math.pi / 2.0,
        else => 0,
    };
}

fn projectedEquipmentTransform(
    instance: *character.CharacterInstance,
    visual_index: usize,
    front: presentation_pose.FrontProjection,
    front_anatomy: presentation_pose.FrontAnatomyProjection,
) !character.ResolvedEquipmentTransform {
    const loadout = &instance.equipment_loadout.?;
    const anatomy_definition = instance.definition.anatomy_definition.?;
    const anatomy_runtime = &instance.character.anatomy_runtime.?;
    if (visual_index >= loadout.visuals().len) return error.InvalidResolvedEquipmentVisualIndex;
    const visual = loadout.visuals()[visual_index];
    const recipe = try loadout.definition.recipe(visual.recipe);
    if (recipe.component.index() >= loadout.definition.visual_components.len) {
        return error.InvalidEquipmentVisualReference;
    }
    const component = loadout.definition.visual_components[recipe.component.index()];
    const secondary_deformation = if (component.secondary_motion) |motion_definition|
        try visual.secondary.resolvedTransform(motion_definition)
    else
        math.Transform2D.identity();
    return switch (visual.source) {
        .anatomy_part => |part_id| .{
            .binding_world = (try front_anatomy.partBindingWorld(part_id))
                .mul(try recipe.local_to_binding.localToParent()),
            .resolved_deformation = try anatomy_runtime.resolvedDeformationForPart(
                anatomy_definition,
                part_id,
                component.deformation_response,
            ),
            .secondary_deformation = secondary_deformation,
            .bound_identity = .{ .anatomy_part = @intFromEnum(part_id) },
        },
        .attachment_point => |point_id| .{
            .binding_world = (try front.attachmentPointWorld(point_id))
                .mul(try recipe.local_to_binding.localToParent()),
            .resolved_deformation = math.Transform2D.identity(),
            .secondary_deformation = secondary_deformation,
            .bound_identity = .{ .attachment_point = @intFromEnum(point_id) },
        },
    };
}

fn initSkirtMesh(
    allocator: std.mem.Allocator,
    stable_id: []const u8,
    material_id: []const u8,
    visual: wardrobe_art_resolved,
    renderer_page_offset: u32,
) !mesh.Definition {
    const uv = visual.uv_rect;
    const middle_v = (uv[1] + uv[3]) * 0.5;
    const vertices = [_]mesh.VertexInput{
        .{ .local_position = .{ .x = -0.62, .y = 0.0 }, .uv = .{ uv[0], uv[1] }, .deformation_weight = 0.15 },
        .{ .local_position = .{ .x = 0.62, .y = 0.0 }, .uv = .{ uv[2], uv[1] }, .deformation_weight = 0.15 },
        .{ .local_position = .{ .x = -0.70, .y = -0.84 }, .uv = .{ uv[0], middle_v }, .deformation_weight = 0.62 },
        .{ .local_position = .{ .x = 0.70, .y = -0.84 }, .uv = .{ uv[2], middle_v }, .deformation_weight = 0.62 },
        .{ .local_position = .{ .x = -0.76, .y = -1.68 }, .uv = .{ uv[0], uv[3] }, .deformation_weight = 1.0 },
        .{ .local_position = .{ .x = 0.76, .y = -1.68 }, .uv = .{ uv[2], uv[3] }, .deformation_weight = 1.0 },
    };
    const indices = [_]u16{ 0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4 };
    return mesh.Definition.init(allocator, .{
        .stable_id = stable_id,
        .vertices = &vertices,
        .indices = &indices,
        .material = .{
            .stable_id = material_id,
            .texture_page = renderer_page_offset + visual.texture_page,
            .tint = .{ 1, 1, 1, 1 },
        },
    });
}
