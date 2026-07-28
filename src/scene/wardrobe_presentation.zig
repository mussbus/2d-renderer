const std = @import("std");
const math = @import("math");
const mesh = @import("deformable_mesh");
const equipment = @import("equipment");
const humanoid = @import("humanoid");
const anatomy = @import("anatomy");
const character = @import("character");
const presentation_pose = @import("presentation_pose");
const presentation_view = @import("presentation_view");
const render_queue = @import("render_queue");
const sprite = @import("sprite_batch");
const wardrobe_art = @import("wardrobe_art");
const wardrobe_catalog = @import("wardrobe_catalog");
const visual_geometry = @import("visual_geometry");

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
        return presentation.submitTraced(instance, queue, null);
    }

    pub fn submitTraced(
        presentation: *Presentation,
        instance: *character.CharacterInstance,
        queue: *render_queue.UnifiedRenderQueue,
        trace: ?*visual_geometry.Trace,
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
            .front => projection: {
                var front = try presentation_pose.FrontProjection.init(
                    &instance.definition.skeleton_definition,
                    instance.character.local_and_world_pose,
                    instance.definition.visual_definition,
                    instance.character.appearance_runtime,
                    instance.world_position,
                );
                try front.applyFrontShoulderMorphology(
                    &instance.definition.skeleton_definition,
                    instance.definition.visual_definition,
                    instance.character.appearance_runtime,
                    anatomy_definition,
                    anatomy_runtime.*,
                    instance.world_position.x,
                );
                break :projection front;
            },
            .side => if (instance.isInteractionLocked())
                try presentation_pose.FrontProjection.initSideInteraction(
                    &instance.definition.skeleton_definition,
                    instance.character.local_and_world_pose,
                    instance.definition.visual_definition,
                    instance.character.appearance_runtime,
                    instance.world_position,
                    instance.facing == .left,
                )
            else
                try presentation_pose.FrontProjection.initSide(
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
            const spec = specForSemantic(component.presentation_semantic.?) orelse
                return error.UnknownWardrobeSemantic;
            const resolved = try projectedEquipmentTransform(
                instance,
                visual_index,
                projection,
                projected_anatomy,
            );
            const order = try presentation.resolvedVisualOrder(
                instance,
                visual_index,
            );

            if (component.presentation_semantic == semantic(25_032)) {
                const definition = if (view == .front)
                    presentation.front_skirt_mesh.view()
                else
                    presentation.side_skirt_mesh.view();
                var composed_deformation = try resolved.composedDeformation();
                const effective_pivot_y = effectivePivotY(
                    spec,
                    selected.pivot[1],
                    bodyStyle(instance),
                    view,
                );
                const pivot_offset_y = selected.authored_size[1] *
                    (selected.pivot[1] - effective_pivot_y);
                var mesh_binding_world = resolved.binding_world.mul(
                    math.Mat3.translation(.{ .x = 0, .y = pivot_offset_y }),
                );
                const mesh_fit_x = if (std.mem.eql(u8, bodyStyle(instance), "male"))
                    (if (view == .front)
                        spec.fit.male_front_scale_x
                    else
                        spec.fit.male_side_scale_x)
                else if (view == .front)
                    spec.fit.female_front_scale_x
                else
                    spec.fit.female_side_scale_x;
                mesh_binding_world = mesh_binding_world.mul(
                    math.Mat3.nonuniformScale(.{ .x = mesh_fit_x, .y = 1 }),
                );
                if (std.mem.eql(u8, bodyStyle(instance), "male")) {
                    if (view == .front) {
                        composed_deformation.scale.y *= spec.fit.male_front_scale_y;
                    } else {
                        composed_deformation.scale.y *= spec.fit.male_side_scale_y;
                    }
                }
                try loadout.resolved_visuals[visual_index].mesh_state.update(
                    instance.id.raw(),
                    resolved.bound_identity,
                    mesh_binding_world,
                    composed_deformation,
                );
                _ = try queue.submitMesh(.{
                    .definition = definition,
                    .binding_world = mesh_binding_world,
                    .resolved_deformation = composed_deformation,
                    .owning_character = instance.id.raw(),
                    .bound_identity = resolved.bound_identity,
                    .order = order,
                });
                if (trace) |sink| {
                    const source = sourceForWardrobeRegion(selected.region_id) orelse
                        return error.MissingWardrobeGeometrySource;
                    const role = visual_geometry.roleForAnchor(binding.anchor);
                    var traced_vertices: [visual_geometry.mesh_vertex_capacity]visual_geometry.MeshVertex = undefined;
                    if (definition.vertices.len > traced_vertices.len or
                        definition.indices.len > visual_geometry.mesh_index_capacity)
                    {
                        return error.VisualGeometryMeshCapacityExceeded;
                    }
                    for (definition.vertices, 0..) |vertex, index| {
                        const local = try mesh.deformedLocalPoint(vertex, composed_deformation);
                        traced_vertices[index] = .{
                            .world = mesh_binding_world.transformPoint(local),
                            .uv = vertex.uv,
                        };
                    }
                    const top_left = traced_vertices[0].world;
                    const top_right = traced_vertices[1].world;
                    const middle_left = traced_vertices[2].world;
                    const middle_right = traced_vertices[3].world;
                    const bottom_left = traced_vertices[4].world;
                    const bottom_right = traced_vertices[5].world;
                    const request = sprite.SpriteRequest{
                        .world_position = .{
                            mesh_binding_world.values[6],
                            mesh_binding_world.values[7],
                        },
                        .rotation = 0,
                        .scale = .{ 1, 1 },
                        .pivot = .{ 0, 0 },
                        .uv_rect = selected.uv_rect,
                        .tint = .{ 1, 1, 1, 1 },
                        .texture_page = presentation.renderer_page_offset + selected.texture_page,
                        .order = order,
                    };
                    try sink.append(.{
                        .character_id = instance.id.raw(),
                        .style = bodyStyle(instance),
                        .view = geometryView(view, instance.facing),
                        .owner = ownerForRole(role),
                        .role = role,
                        .side = semanticSide(visual, anatomy_definition),
                        .semantic_id = @intFromEnum(selected.semantic_id),
                        .component_id = @intCast(component.id.index()),
                        .bound_identity = boundIdentityRaw(visual),
                        .stable_id = spec.stable_id,
                        .region_id = @intFromEnum(selected.region_id),
                        .source = .{
                            .x = source.x,
                            .y = source.y,
                            .width = source.width,
                            .height = source.height,
                        },
                        .request = request,
                        .geometry = visual_geometry.attachmentGeometry(
                            spec.stable_id,
                            role,
                            geometryView(view, instance.facing),
                        ),
                        .fit = spec.fit,
                        .world_geometry = visual_geometry.WorldGeometry.init(&.{
                            .{ .kind = .waist_left, .world = top_left },
                            .{ .kind = .waist_right, .world = top_right },
                            .{ .kind = .hip, .world = middle_left },
                            .{ .kind = .proximal, .world = middle_right },
                            .{ .kind = .leg_opening_left, .world = bottom_left },
                            .{ .kind = .leg_opening_right, .world = bottom_right },
                            .{ .kind = .hem, .world = bottom_left.add(bottom_right).scale(0.5) },
                        }),
                        .mesh = visual_geometry.MeshTrace.init(
                            traced_vertices[0..definition.vertices.len],
                            definition.indices,
                        ),
                    });
                }
            } else {
                const sprite_transform = try humanoid.spriteTransform(try resolved.world());
                const rest_rotation = restRotation(binding.anchor, view, instance.facing);
                var world_size = presentation_view.spriteMorphologyScale(
                    sprite_transform.signed_scale,
                    rest_rotation,
                ).componentMul(.{
                    .x = selected.authored_size[0],
                    .y = selected.authored_size[1],
                });
                if (std.mem.eql(u8, bodyStyle(instance), "male")) {
                    if (view == .front) {
                        world_size.x *= spec.fit.male_front_scale_x;
                        world_size.y *= spec.fit.male_front_scale_y;
                    } else {
                        world_size.x *= spec.fit.male_side_scale_x;
                        world_size.y *= spec.fit.male_side_scale_y;
                    }
                } else if (view == .front) {
                    world_size.x *= spec.fit.female_front_scale_x;
                } else {
                    world_size.x *= spec.fit.female_side_scale_x;
                }
                var pivot = selected.pivot;
                pivot[1] = effectivePivotY(spec, pivot[1], bodyStyle(instance), view);
                if (view == .side and binding.anchor == .foot) {
                    // Both authored side shoes point texture-left while the
                    // authoritative side feet point along the presentation
                    // facing direction. Invert the equipment source axis; the
                    // projected anatomy transform already supplies facing.
                    world_size.x = -world_size.x;
                }
                if (view == .front) {
                    const bound_to_left_part = switch (visual.source) {
                        .anatomy_part => |part_id| std.mem.startsWith(
                            u8,
                            anatomy_definition.part_instances[part_id.index()].stable_id.slice(),
                            "left_",
                        ),
                        .attachment_point => false,
                    };
                    // The production shoe source points texture-left. Front
                    // anatomy feet point away from the body center, so its
                    // mirror polarity is intentionally the inverse of the
                    // vertically-authored limb garments.
                    const mirror = if (binding.anchor == .foot)
                        !bound_to_left_part
                    else
                        bound_to_left_part;
                    if (mirror) {
                        world_size.x = -world_size.x;
                        if (binding.anchor != .foot) {
                            pivot[0] = 1.0 - pivot[0];
                        }
                    }
                }
                var world_position = sprite_transform.world_position;
                const morphology_factor = @abs(world_size.y) /
                    @max(selected.authored_size[1], std.math.floatEps(f32));
                const morphology_fit_y = spec.fit.morphology_fit_y_per_scale *
                    (morphology_factor - 1.0) + spec.fit.morphology_fit_y_bias;
                if (@abs(morphology_fit_y) > std.math.floatEps(f32)) {
                    const fit_rotation = sprite_transform.rotation_radians + rest_rotation;
                    world_position.x -= @sin(fit_rotation) * morphology_fit_y;
                    world_position.y += @cos(fit_rotation) * morphology_fit_y;
                }
                const request = sprite.SpriteRequest{
                    .world_position = world_position.toArray(),
                    .rotation = sprite_transform.rotation_radians + rest_rotation,
                    .scale = world_size.toArray(),
                    .pivot = pivot,
                    .uv_rect = selected.uv_rect,
                    .tint = .{ 1, 1, 1, 1 },
                    .texture_page = presentation.renderer_page_offset + selected.texture_page,
                    .order = order,
                };
                _ = try queue.submitSprite(request);
                if (trace) |sink| {
                    const source = sourceForWardrobeRegion(selected.region_id) orelse
                        return error.MissingWardrobeGeometrySource;
                    const role = visual_geometry.roleForAnchor(binding.anchor);
                    try sink.append(.{
                        .character_id = instance.id.raw(),
                        .style = bodyStyle(instance),
                        .view = geometryView(view, instance.facing),
                        .owner = ownerForRole(role),
                        .role = role,
                        .side = semanticSide(visual, anatomy_definition),
                        .semantic_id = @intFromEnum(selected.semantic_id),
                        .component_id = @intCast(component.id.index()),
                        .bound_identity = boundIdentityRaw(visual),
                        .stable_id = spec.stable_id,
                        .region_id = @intFromEnum(selected.region_id),
                        .source = .{
                            .x = source.x,
                            .y = source.y,
                            .width = source.width,
                            .height = source.height,
                        },
                        .request = request,
                        .geometry = visual_geometry.attachmentGeometry(
                            spec.stable_id,
                            role,
                            geometryView(view, instance.facing),
                        ),
                        .fit = spec.fit,
                    });
                }
            }
            submitted += 1;
        }
        return submitted;
    }

    pub fn resolvedVisualOrder(
        presentation: *const Presentation,
        instance: *const character.CharacterInstance,
        visual_index: usize,
    ) !sprite.OrderInput {
        const loadout = if (instance.equipment_loadout) |*value|
            value
        else
            return error.CharacterEquipmentNotInitialized;
        if (visual_index >= loadout.visuals().len) return error.InvalidResolvedEquipmentVisualIndex;
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
        const anatomy_definition = instance.definition.anatomy_definition orelse
            return error.CharacterHasNoAnatomy;
        const layer = loadout.definition.visual_layers[recipe.visual_layer.index()];
        return .{
            .scene_layer = character.characters_scene_layer,
            .interaction_layer = try equipmentInteractionLayer(
                instance,
                visual,
                binding.anchor,
                anatomy_definition,
            ),
            .actor_layer = instance.actor_layer,
            .body_part_layer = layer.render_layer,
        };
    }
};

fn sourceForWardrobeRegion(id: @import("art_pack").AtlasRegionId) ?@import("art_pack").PixelRect {
    for (wardrobe_art.region_inputs) |region| {
        if (region.id == id) return region.source;
    }
    return null;
}

fn equipmentInteractionLayer(
    instance: *const character.CharacterInstance,
    visual: equipment.ResolvedVisualInstance,
    anchor: wardrobe_catalog.AnchorKind,
    anatomy_definition: anatomy.DefinitionView,
) !i32 {
    const part_id = switch (visual.source) {
        .anatomy_part => |value| value,
        .attachment_point => return character.neutral_interaction_layer,
    };
    const part_name = anatomy_definition.part_instances[part_id.index()].stable_id.slice();
    const left = std.mem.startsWith(u8, part_name, "left_");
    const anatomy_semantic: humanoid.AttachmentSemantic = switch (anchor) {
        .torso => .torso,
        .pelvis, .waist => .pelvis,
        .head => .head,
        .upper_arm => if (left) .left_upper_arm else .right_upper_arm,
        .hand => if (left) .left_hand else .right_hand,
        .lower_leg => if (left) .left_shin else .right_shin,
        .foot => if (left) .left_foot else .right_foot,
    };
    return (try instance.resolvedOrder(anatomy_semantic)).interaction_layer;
}

fn geometryView(view: presentation_view.View, facing: humanoid.Facing) visual_geometry.View {
    return switch (view) {
        .front => .front,
        .side => if (facing == .left) .side_left else .side_right,
    };
}

fn effectivePivotY(
    spec: wardrobe_catalog.VisualSpec,
    fallback: f32,
    style: []const u8,
    view: presentation_view.View,
) f32 {
    const male = std.mem.eql(u8, style, "male");
    return if (view == .front)
        (if (male) spec.male_front_pivot_y else spec.female_front_pivot_y) orelse fallback
    else
        (if (male) spec.male_side_pivot_y else spec.female_side_pivot_y) orelse fallback;
}

fn ownerForRole(role: visual_geometry.Role) visual_geometry.Owner {
    return switch (role) {
        .torso_garment, .lower_garment, .sleeve, .glove, .legwear => .clothing,
        .shoe => .equipment,
        else => .accessory,
    };
}

fn bodyStyle(instance: *const character.CharacterInstance) []const u8 {
    const anatomy_definition = instance.definition.anatomy_definition orelse return "unknown";
    const anatomy_runtime = instance.character.anatomy_runtime orelse return "unknown";
    const preset = anatomy_definition.body_presets[anatomy_runtime.selected_body_preset.index()];
    if (std.mem.indexOf(u8, preset.stable_id.slice(), "female") != null) return "female";
    if (std.mem.indexOf(u8, preset.stable_id.slice(), "male") != null) return "male";
    return preset.stable_id.slice();
}

fn semanticSide(
    visual: equipment.ResolvedVisualInstance,
    anatomy_definition: @import("anatomy").DefinitionView,
) visual_geometry.Side {
    return switch (visual.source) {
        .anatomy_part => |part_id| blk: {
            const name = anatomy_definition.part_instances[part_id.index()].stable_id.slice();
            if (std.mem.startsWith(u8, name, "left_")) break :blk .left;
            if (std.mem.startsWith(u8, name, "right_")) break :blk .right;
            break :blk .none;
        },
        .attachment_point => .none,
    };
}

fn boundIdentityRaw(visual: equipment.ResolvedVisualInstance) u32 {
    return switch (visual.source) {
        .anatomy_part => |part_id| @intCast(@intFromEnum(part_id)),
        .attachment_point => |point_id| @intCast(@intFromEnum(point_id)),
    };
}

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
    // Mesh vertices use the same authored-pivot convention as SpriteRequest:
    // the resolved binding is at the visual pivot, not at its top edge.
    const top_y = visual.authored_size[1] * (1.0 - visual.pivot[1]);
    const vertices = [_]mesh.VertexInput{
        .{ .local_position = .{ .x = -0.396, .y = top_y }, .uv = .{ uv[0], uv[1] }, .deformation_weight = 0.15 },
        .{ .local_position = .{ .x = 0.396, .y = top_y }, .uv = .{ uv[2], uv[1] }, .deformation_weight = 0.15 },
        .{ .local_position = .{ .x = -0.362, .y = top_y - 0.84 }, .uv = .{ uv[0], middle_v }, .deformation_weight = 0.62 },
        .{ .local_position = .{ .x = 0.362, .y = top_y - 0.84 }, .uv = .{ uv[2], middle_v }, .deformation_weight = 0.62 },
        .{ .local_position = .{ .x = -0.55, .y = top_y - 1.68 }, .uv = .{ uv[0], uv[3] }, .deformation_weight = 1.0 },
        .{ .local_position = .{ .x = 0.55, .y = top_y - 1.68 }, .uv = .{ uv[2], uv[3] }, .deformation_weight = 1.0 },
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
