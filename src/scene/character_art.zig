const std = @import("std");
const math = @import("math");
const art_pack = @import("art_pack");
const humanoid = @import("humanoid");
const character = @import("character");
const appearance = @import("appearance");
const presentation_pose = @import("presentation_pose");
const presentation_view = @import("presentation_view");
const render_queue = @import("render_queue");
const sprite = @import("sprite_batch");
const visual_geometry = @import("visual_geometry");

pub const male_page_id: art_pack.TexturePageId = @enumFromInt(41);
pub const female_page_id: art_pack.TexturePageId = @enumFromInt(42);
pub const component_page_id: art_pack.TexturePageId = @enumFromInt(43);
pub const texture_page_count: usize = 3;

pub const Style = enum(u8) {
    male,
    female,
};

pub const HairSelection = enum(u8) {
    bald,
    buzz_cut,
    long,
};

pub const Garment = enum(u8) {
    training_vest,
};

const Slot = enum(u8) {
    pelvis,
    torso,
    head,
    left_upper_arm,
    left_forearm,
    left_hand,
    right_upper_arm,
    right_forearm,
    right_hand,
    left_thigh,
    left_shin,
    left_foot,
    right_thigh,
    right_shin,
    right_foot,
    left_eye,
    right_eye,
    eyebrows,
    nose,
    mouth,
    left_ear,
    right_ear,
    hair,
};

const slot_count = std.enums.values(Slot).len;

const RegionKey = enum(u8) {
    side_head,
    side_torso,
    side_pelvis,
    side_upper_arm,
    side_forearm,
    side_hand,
    side_thigh,
    side_shin,
    side_foot,
    side_eye,
    side_brow,
    side_nose,
    side_mouth,
    side_ear,
    side_hair,
    front_head,
    front_torso,
    front_pelvis,
    front_upper_arm,
    front_forearm,
    front_hand,
    front_thigh,
    front_shin,
    front_foot,
    front_left_eye,
    front_right_eye,
    front_brows,
    front_nose,
    front_mouth,
    front_left_ear,
    front_right_ear,
    front_hair,
    side_training_vest,
    front_training_vest,
};

const region_key_count = std.enums.values(RegionKey).len;
const anatomy_binding_count = slot_count * 4;
const garment_binding_count = std.enums.values(Style).len *
    std.enums.values(presentation_view.View).len *
    std.enums.values(Garment).len;

pub const page_inputs = [_]art_pack.TexturePageInput{
    .{
        .id = male_page_id,
        .stable_name = "p25a_male_base_anatomy_atlas",
        .asset_path = "art/p25a_male_base_anatomy_atlas.png",
        .sampling = .nearest,
        .expected_width = 1600,
        .expected_height = 983,
    },
    .{
        .id = female_page_id,
        .stable_name = "p25a_female_base_anatomy_atlas",
        .asset_path = "art/p25a_female_base_anatomy_atlas.png",
        .sampling = .nearest,
        .expected_width = 1599,
        .expected_height = 984,
    },
    .{
        .id = component_page_id,
        .stable_name = "p25b_anatomy_components_atlas",
        .asset_path = "art/p25b_anatomy_components_atlas.png",
        .sampling = .nearest,
        .expected_width = 1792,
        .expected_height = 1024,
    },
};

pub const region_inputs = makeRegionInputs();
pub const binding_inputs = makeBindingInputs();

pub fn definitionInput() art_pack.DefinitionInput {
    return .{
        .stable_name = "prompt24a_character_presentation",
        .pages = &page_inputs,
        .regions = &region_inputs,
        .bindings = &binding_inputs,
    };
}

pub const Definition = struct {
    art: art_pack.Definition,

    pub fn init(allocator: std.mem.Allocator) !Definition {
        var definition = Definition{
            .art = try art_pack.Definition.init(allocator, definitionInput()),
        };
        errdefer definition.deinit();
        try definition.validateAnatomyClothingBoundary();
        return definition;
    }

    pub fn deinit(definition: *Definition) void {
        definition.art.deinit();
        definition.* = undefined;
    }

    pub fn resolveBaseAnatomy(
        definition: *const Definition,
        style: Style,
        semantic: humanoid.AttachmentSemantic,
        view: presentation_view.View,
    ) !art_pack.ResolvedVisual {
        const slot: Slot = @enumFromInt(@intFromEnum(semantic));
        return definition.art.resolve(.character, semanticId(style, slot), artView(view));
    }

    pub fn resolveGarment(
        definition: *const Definition,
        style: Style,
        garment: Garment,
        view: presentation_view.View,
    ) !art_pack.ResolvedVisual {
        return definition.art.resolve(.equipment, garmentSemanticId(style, garment), artView(view));
    }

    pub fn validateAnatomyClothingBoundary(definition: *const Definition) !void {
        for (std.enums.values(Style)) |style| {
            for (std.enums.values(presentation_view.View)) |view| {
                const torso = try definition.resolveBaseAnatomy(style, .torso, view);
                const vest = try definition.resolveGarment(style, .training_vest, view);
                if (torso.semantic_id == vest.semantic_id or torso.region_id == vest.region_id) {
                    return error.AnatomyGarmentIdentityCollision;
                }
                if (torso.texture_page != vest.texture_page) {
                    return error.AnatomyGarmentCoPackingEvidenceMissing;
                }
                if (definition.art.resolve(
                    .equipment,
                    semanticId(style, .torso),
                    artView(view),
                )) |_| {
                    return error.AnatomyResolvedAsEquipment;
                } else |err| switch (err) {
                    error.MissingVisualBinding => {},
                }
                if (definition.art.resolve(
                    .character,
                    garmentSemanticId(style, .training_vest),
                    artView(view),
                )) |_| {
                    return error.GarmentResolvedAsAnatomy;
                } else |err| switch (err) {
                    error.MissingVisualBinding => {},
                }
            }
        }
    }
};

const ViewBinding = struct {
    visual: art_pack.ResolvedVisual,
    rest_rotation: f32,
};

const AttachmentBinding = struct {
    active: bool = false,
    slot: Slot = .pelvis,
    side: ?ViewBinding = null,
    front: ?ViewBinding = null,
};

pub const Presentation = struct {
    style: Style,
    renderer_page_offset: u32,
    bindings: [appearance.maximum_visual_attachments]AttachmentBinding =
        [_]AttachmentBinding{.{}} ** appearance.maximum_visual_attachments,
    attachment_count: usize,

    pub fn init(
        definition: *const Definition,
        humanoid_definition: *const humanoid.HumanoidDefinition,
        style: Style,
        renderer_page_offset: u32,
    ) !Presentation {
        if (humanoid_definition.attachments.len > appearance.maximum_visual_attachments) {
            return error.PresentationAttachmentCapacityExceeded;
        }
        var result = Presentation{
            .style = style,
            .renderer_page_offset = renderer_page_offset,
            .attachment_count = humanoid_definition.attachments.len,
        };
        for (humanoid_definition.attachments) |attachment| {
            const slot = slotForAttachment(style, attachment) orelse continue;
            const semantic_id = semanticId(style, slot);
            result.bindings[attachment.id.index()] = .{
                .active = true,
                .slot = slot,
                .side = .{
                    .visual = try definition.art.resolve(
                        .character,
                        semantic_id,
                        art_pack.side_view,
                    ),
                    .rest_rotation = restRotation(style, slot, .side),
                },
                .front = .{
                    .visual = try definition.art.resolve(
                        .character,
                        semantic_id,
                        art_pack.front_view,
                    ),
                    .rest_rotation = restRotation(style, slot, .front),
                },
            };
        }
        try result.validateCompleteness(humanoid_definition);
        return result;
    }

    pub fn validateCompleteness(
        presentation: Presentation,
        humanoid_definition: *const humanoid.HumanoidDefinition,
    ) !void {
        if (presentation.attachment_count != humanoid_definition.attachments.len) {
            return error.PresentationDefinitionMismatch;
        }
        for (std.enums.values(humanoid.AttachmentSemantic)) |semantic| {
            const attachment = try humanoid_definition.attachment(semantic);
            const binding = presentation.bindings[attachment.id.index()];
            if (!binding.active or binding.side == null or binding.front == null) {
                return error.MissingRequiredCharacterRegion;
            }
        }
        const expected_hair: HairSelection = switch (presentation.style) {
            .male => .buzz_cut,
            .female => .long,
        };
        if (!presentation.hasHair(expected_hair)) return error.MissingRequiredHairRegion;
    }

    pub fn hasHair(presentation: Presentation, selection: HairSelection) bool {
        if (selection == .bald) return true;
        const expected_name = switch (selection) {
            .bald => return true,
            .buzz_cut => "short_hair",
            .long => "long_hair",
        };
        for (presentation.bindings[0..presentation.attachment_count], 0..) |binding, index| {
            if (!binding.active or binding.slot != .hair) continue;
            _ = index;
            return switch (presentation.style) {
                .male => std.mem.eql(u8, expected_name, "short_hair"),
                .female => std.mem.eql(u8, expected_name, "long_hair"),
            };
        }
        return false;
    }

    pub fn submit(
        presentation: Presentation,
        instance: *character.CharacterInstance,
        queue: *render_queue.UnifiedRenderQueue,
    ) !u32 {
        return presentation.submitTraced(instance, queue, null);
    }

    pub fn submitTraced(
        presentation: Presentation,
        instance: *character.CharacterInstance,
        queue: *render_queue.UnifiedRenderQueue,
        trace: ?*visual_geometry.Trace,
    ) !u32 {
        if (presentation.attachment_count != instance.definition.attachments.len) {
            return error.PresentationDefinitionMismatch;
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
                const anatomy_definition = instance.definition.anatomy_definition orelse
                    return error.CharacterHasNoAnatomy;
                const anatomy_runtime = instance.character.anatomy_runtime orelse
                    return error.CharacterHasNoAnatomy;
                try front.applyFrontShoulderMorphology(
                    &instance.definition.skeleton_definition,
                    instance.definition.visual_definition,
                    instance.character.appearance_runtime,
                    anatomy_definition,
                    anatomy_runtime,
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

        instance.last_submitted_keys =
            [_]?sprite.DrawOrderKey{null} ** humanoid.canonical_attachment_semantic_count;
        var submitted: u32 = 0;
        for (instance.definition.attachments) |attachment| {
            const binding = presentation.bindings[attachment.id.index()];
            if (!binding.active) continue;
            if (!try instance.character.appearance_runtime.isVisible(
                instance.definition.visual_definition,
                attachment.id,
            )) continue;
            if (view == .side and !sideFeatureVisible(binding.slot)) continue;

            const selected = switch (view) {
                .side => binding.side orelse return error.MissingSideCharacterRegion,
                .front => binding.front orelse return error.MissingFrontCharacterRegion,
            };
            const world = try presentationVisualWorld(
                instance,
                attachment,
                binding.slot,
                view,
                projection,
            );
            const sprite_transform = try humanoid.spriteTransform(world);
            const rest_rotation = presentationRestRotation(
                selected.rest_rotation,
                binding.slot,
                view,
                instance.facing,
            );
            const morphology_scale = presentation_view.spriteMorphologyScale(
                sprite_transform.signed_scale,
                rest_rotation,
            );
            var world_size = morphology_scale.componentMul(.{
                .x = selected.visual.authored_size[0],
                .y = selected.visual.authored_size[1],
            });
            if (view == .front and mirrorsFrontRegion(binding.slot)) {
                world_size.x = -world_size.x;
            }
            const order = presentationOrder(instance, attachment, binding.slot, presentation.style, view);
            const request = sprite.SpriteRequest{
                .world_position = sprite_transform.world_position.toArray(),
                .rotation = sprite_transform.rotation_radians + rest_rotation,
                .scale = world_size.toArray(),
                .pivot = selected.visual.pivot,
                .uv_rect = selected.visual.uv_rect,
                .tint = .{ 1, 1, 1, 1 },
                .texture_page = presentation.renderer_page_offset + selected.visual.texture_page,
                .order = order,
            };
            const key = try queue.submitSprite(request);
            if (trace) |sink| {
                const region_source = sourceForRegion(selected.visual.region_id) orelse
                    return error.MissingCharacterGeometrySource;
                try sink.append(.{
                    .character_id = instance.id.raw(),
                    .style = @tagName(presentation.style),
                    .view = geometryView(view, instance.facing),
                    .owner = ownerForSlot(binding.slot),
                    .role = geometryRole(binding.slot),
                    .side = geometrySide(binding.slot),
                    .semantic_id = @intFromEnum(selected.visual.semantic_id),
                    .component_id = @intCast(attachment.id.index()),
                    .bound_identity = boundIdentityForSlot(instance, binding.slot, attachment),
                    .stable_id = @tagName(binding.slot),
                    .region_id = @intFromEnum(selected.visual.region_id),
                    .source = .{
                        .x = region_source.x,
                        .y = region_source.y,
                        .width = region_source.width,
                        .height = region_source.height,
                    },
                    .request = request,
                    .geometry = visual_geometry.anatomyGeometry(
                        @tagName(presentation.style),
                        geometryRole(binding.slot),
                        geometryView(view, instance.facing),
                    ),
                    .world_geometry = try anatomyRootWorldGeometry(
                        instance,
                        binding.slot,
                        projection,
                    ),
                    .morphology_length_scale = @abs(if (view == .front)
                        morphology_scale.y
                    else
                        morphology_scale.x),
                });
            }
            if (attachment.canonical_semantic) |raw_semantic| {
                instance.last_submitted_keys[raw_semantic] = key;
            }
            submitted += 1;
        }
        return submitted;
    }
};

fn anatomyRootWorldGeometry(
    instance: *const character.CharacterInstance,
    slot: Slot,
    projection: presentation_pose.FrontProjection,
) !?visual_geometry.WorldGeometry {
    const definition = &instance.definition.skeleton_definition;
    return switch (slot) {
        .torso => visual_geometry.WorldGeometry.init(&.{
            .{
                .kind = .shoulder_left,
                .world = projection.bone_world[try definition.boneIndex(.left_upper_arm)].translationPart(),
            },
            .{
                .kind = .shoulder_right,
                .world = projection.bone_world[try definition.boneIndex(.right_upper_arm)].translationPart(),
            },
        }),
        .pelvis => visual_geometry.WorldGeometry.init(&.{
            .{
                .kind = .hip_left,
                .world = projection.bone_world[try definition.boneIndex(.left_thigh)].translationPart(),
            },
            .{
                .kind = .hip_right,
                .world = projection.bone_world[try definition.boneIndex(.right_thigh)].translationPart(),
            },
        }),
        else => null,
    };
}

fn sourceForRegion(id: art_pack.AtlasRegionId) ?art_pack.PixelRect {
    for (region_inputs) |region| {
        if (region.id == id) return region.source;
    }
    return null;
}

fn geometryView(view: presentation_view.View, facing: humanoid.Facing) visual_geometry.View {
    return switch (view) {
        .front => .front,
        .side => if (facing == .left) .side_left else .side_right,
    };
}

fn geometrySide(slot: Slot) visual_geometry.Side {
    return switch (slot) {
        .left_upper_arm,
        .left_forearm,
        .left_hand,
        .left_thigh,
        .left_shin,
        .left_foot,
        .left_eye,
        .left_ear,
        => .left,
        .right_upper_arm,
        .right_forearm,
        .right_hand,
        .right_thigh,
        .right_shin,
        .right_foot,
        .right_eye,
        .right_ear,
        => .right,
        else => .none,
    };
}

fn geometryRole(slot: Slot) visual_geometry.Role {
    return switch (slot) {
        .head => .head,
        .torso => .torso,
        .pelvis => .pelvis,
        .left_upper_arm, .right_upper_arm => .upper_arm,
        .left_forearm, .right_forearm => .forearm,
        .left_hand, .right_hand => .hand,
        .left_thigh, .right_thigh => .thigh,
        .left_shin, .right_shin => .shin,
        .left_foot, .right_foot => .foot,
        .hair => .hair,
        else => .face_feature,
    };
}

fn ownerForSlot(slot: Slot) visual_geometry.Owner {
    return switch (slot) {
        .pelvis, .hair, .left_eye, .right_eye, .eyebrows, .nose, .mouth, .left_ear, .right_ear => .base_presentation,
        else => .anatomy,
    };
}

fn boundIdentityForSlot(
    instance: *const character.CharacterInstance,
    slot: Slot,
    attachment: appearance.VisualAttachment,
) u32 {
    if (instance.definition.anatomy_definition) |definition| {
        for (definition.part_instances) |part| {
            if (std.mem.eql(u8, part.stable_id.slice(), @tagName(slot))) {
                return @intCast(@intFromEnum(part.id));
            }
        }
    }
    return if (attachment.canonical_semantic) |semantic_value|
        semantic_value
    else
        @intCast(attachment.id.index());
}

fn presentationOrder(
    instance: *const character.CharacterInstance,
    attachment: appearance.VisualAttachment,
    slot: Slot,
    style: Style,
    view: presentation_view.View,
) sprite.OrderInput {
    const default_layer = if (attachment.canonical_semantic) |raw_semantic| layer: {
        const semantic: humanoid.AttachmentSemantic = @enumFromInt(raw_semantic);
        break :layer switch (view) {
            .side => connectorLayer(
                semantic,
                sideBodyPartLayer(semantic, instance.facing),
                .side,
            ),
            .front => frontPresentationLayer(semantic),
        };
    } else if (slot == .hair and style == .female)
        29
    else
        attachment.body_part_layer;
    const resolved = instance.overrides.resolve(@intFromEnum(attachment.id), default_layer);
    return .{
        .scene_layer = character.characters_scene_layer,
        .interaction_layer = resolved.interaction_layer,
        .actor_layer = instance.actor_layer,
        .body_part_layer = resolved.body_part_layer,
    };
}

fn connectorLayer(
    semantic: humanoid.AttachmentSemantic,
    authored_layer: u16,
    view: presentation_view.View,
) u16 {
    _ = view;
    return switch (semantic) {
        .pelvis => 9,
        else => authored_layer,
    };
}

fn presentationVisualWorld(
    instance: *const character.CharacterInstance,
    attachment: appearance.VisualAttachment,
    slot: Slot,
    view: presentation_view.View,
    projection: presentation_pose.FrontProjection,
) !math.Mat3 {
    if (attachment.canonical_semantic != null) {
        return projection.visualWorld(
            instance.character.appearance_runtime,
            attachment,
        );
    }

    const head = try instance.definition.attachment(.head);
    const head_world = try projection.visualWorld(
        instance.character.appearance_runtime,
        head.*,
    );
    if (attachment.id.index() >= instance.character.appearance_runtime.visual_states.len) {
        return error.InvalidVisualAttachmentId;
    }
    const state = instance.character.appearance_runtime.visual_states[attachment.id.index()];
    var world = head_world
        .mul(math.Mat3.translation(featureOffset(slot, view)))
        .mul(try state.local_deformation.localToParent());
    if (attachment.secondary_motion) |motion_definition| {
        world = world.mul(try (try state.secondary.resolvedTransform(motion_definition)).localToParent());
    }
    return world;
}

fn presentationRestRotation(
    authored: f32,
    slot: Slot,
    view: presentation_view.View,
    facing: humanoid.Facing,
) f32 {
    if (view == .side and facing == .left) {
        return switch (slot) {
            .left_thigh, .right_thigh, .left_shin, .right_shin => -std.math.pi / 2.0,
            else => authored,
        };
    }
    return authored;
}

fn featureOffset(slot: Slot, view: presentation_view.View) math.Vec2 {
    return switch (view) {
        .side => switch (slot) {
            .left_eye, .right_eye => .{ .x = 0.20, .y = 0.10 },
            .eyebrows => .{ .x = 0.19, .y = 0.19 },
            .nose => .{ .x = 0.34, .y = 0.02 },
            .mouth => .{ .x = 0.25, .y = -0.14 },
            .left_ear, .right_ear => .{ .x = -0.29, .y = 0.03 },
            .hair => .{ .x = 0, .y = 0.29 },
            else => math.Vec2.zero,
        },
        .front => switch (slot) {
            .left_eye => .{ .x = -0.14, .y = 0.09 },
            .right_eye => .{ .x = 0.14, .y = 0.09 },
            .eyebrows => .{ .x = 0, .y = 0.19 },
            .nose => .{ .x = 0, .y = -0.01 },
            .mouth => .{ .x = 0, .y = -0.15 },
            .left_ear, .right_ear => .{ .x = 0, .y = 0.02 },
            .hair => .{ .x = 0, .y = 0.29 },
            else => math.Vec2.zero,
        },
    };
}

pub fn frontBodyPartLayer(semantic: humanoid.AttachmentSemantic) u16 {
    return switch (semantic) {
        .left_foot => 10,
        .left_shin => 11,
        .left_thigh => 12,
        .right_foot => 14,
        .right_shin => 15,
        .right_thigh => 16,
        .left_hand => 20,
        .left_forearm => 21,
        .left_upper_arm => 22,
        .right_hand => 24,
        .right_forearm => 25,
        .right_upper_arm => 26,
        .pelvis => 30,
        .torso => 31,
        .head => 40,
    };
}

pub fn frontPresentationLayer(semantic: humanoid.AttachmentSemantic) u16 {
    return connectorLayer(semantic, frontBodyPartLayer(semantic), .front);
}

fn sideBodyPartLayer(
    semantic: humanoid.AttachmentSemantic,
    facing: humanoid.Facing,
) u16 {
    const left_is_front = facing == .left;
    const front = switch (semantic) {
        .left_upper_arm,
        .left_forearm,
        .left_hand,
        .left_thigh,
        .left_shin,
        .left_foot,
        => left_is_front,
        .right_upper_arm,
        .right_forearm,
        .right_hand,
        .right_thigh,
        .right_shin,
        .right_foot,
        => !left_is_front,
        else => false,
    };
    return switch (semantic) {
        .pelvis => 30,
        .torso => 31,
        .head => 40,
        .left_foot, .right_foot => if (front) 14 else 10,
        .left_shin, .right_shin => if (front) 15 else 11,
        .left_thigh, .right_thigh => if (front) 16 else 12,
        .left_hand, .right_hand => if (front) 34 else 20,
        .left_forearm, .right_forearm => if (front) 33 else 21,
        // The torso owns the visible profile deltoid. Both upper-arm roots
        // therefore pass behind it; the near forearm and hand retain their
        // front layers so the hanging arm still reads in profile.
        .left_upper_arm, .right_upper_arm => 22,
    };
}

fn sideFeatureVisible(slot: Slot) bool {
    return slot != .left_eye and slot != .left_ear;
}

fn mirrorsFrontRegion(slot: Slot) bool {
    return switch (slot) {
        .left_upper_arm,
        .left_forearm,
        .left_hand,
        .left_thigh,
        .left_shin,
        .left_foot,
        => true,
        else => false,
    };
}

fn slotForAttachment(style: Style, attachment: appearance.VisualAttachment) ?Slot {
    if (attachment.canonical_semantic) |raw_semantic| return @enumFromInt(raw_semantic);
    const name = attachment.debug_name.slice();
    return switch (style) {
        .male => if (std.mem.eql(u8, name, "left_eye"))
            .left_eye
        else if (std.mem.eql(u8, name, "right_eye"))
            .right_eye
        else if (std.mem.eql(u8, name, "eyebrows"))
            .eyebrows
        else if (std.mem.eql(u8, name, "nose"))
            .nose
        else if (std.mem.eql(u8, name, "mouth"))
            .mouth
        else if (std.mem.eql(u8, name, "left_ear"))
            .left_ear
        else if (std.mem.eql(u8, name, "right_ear"))
            .right_ear
        else if (std.mem.eql(u8, name, "short_hair"))
            .hair
        else
            null,
        .female => if (std.mem.eql(u8, name, "angular_left_eye"))
            .left_eye
        else if (std.mem.eql(u8, name, "angular_right_eye"))
            .right_eye
        else if (std.mem.eql(u8, name, "angular_eyebrows"))
            .eyebrows
        else if (std.mem.eql(u8, name, "angular_nose"))
            .nose
        else if (std.mem.eql(u8, name, "angular_mouth"))
            .mouth
        else if (std.mem.eql(u8, name, "angular_left_ear"))
            .left_ear
        else if (std.mem.eql(u8, name, "angular_right_ear"))
            .right_ear
        else if (std.mem.eql(u8, name, "long_hair"))
            .hair
        else
            null,
    };
}

fn semanticId(style: Style, slot: Slot) art_pack.VisualSemanticId {
    return @enumFromInt(1000 + @as(u32, @intFromEnum(style)) * 100 + @intFromEnum(slot));
}

fn garmentSemanticId(style: Style, garment: Garment) art_pack.VisualSemanticId {
    return @enumFromInt(2000 + @as(u32, @intFromEnum(style)) * 100 + @intFromEnum(garment));
}

fn regionId(style: Style, key: RegionKey) art_pack.AtlasRegionId {
    return @enumFromInt(5000 + @as(u32, @intFromEnum(style)) * 100 + @intFromEnum(key));
}

fn artView(view: presentation_view.View) art_pack.ViewId {
    return if (view == .side) art_pack.side_view else art_pack.front_view;
}

fn keyForGarment(garment: Garment, view: presentation_view.View) RegionKey {
    return switch (garment) {
        .training_vest => if (view == .side) .side_training_vest else .front_training_vest,
    };
}

fn keyForSlot(slot: Slot, view: presentation_view.View) RegionKey {
    return switch (view) {
        .side => switch (slot) {
            .pelvis => .side_pelvis,
            .torso => .side_torso,
            .head => .side_head,
            .left_upper_arm, .right_upper_arm => .side_upper_arm,
            .left_forearm, .right_forearm => .side_forearm,
            .left_hand, .right_hand => .side_hand,
            .left_thigh, .right_thigh => .side_thigh,
            .left_shin, .right_shin => .side_shin,
            .left_foot, .right_foot => .side_foot,
            .left_eye, .right_eye => .side_eye,
            .eyebrows => .side_brow,
            .nose => .side_nose,
            .mouth => .side_mouth,
            .left_ear, .right_ear => .side_ear,
            .hair => .side_hair,
        },
        .front => switch (slot) {
            .pelvis => .front_pelvis,
            .torso => .front_torso,
            .head => .front_head,
            .left_upper_arm, .right_upper_arm => .front_upper_arm,
            .left_forearm, .right_forearm => .front_forearm,
            .left_hand, .right_hand => .front_hand,
            .left_thigh, .right_thigh => .front_thigh,
            .left_shin, .right_shin => .front_shin,
            .left_foot, .right_foot => .front_foot,
            .left_eye => .front_left_eye,
            .right_eye => .front_right_eye,
            .eyebrows => .front_brows,
            .nose => .front_nose,
            .mouth => .front_mouth,
            .left_ear => .front_left_ear,
            .right_ear => .front_right_ear,
            .hair => .front_hair,
        },
    };
}

fn makeRegionInputs() [region_key_count * 2]art_pack.AtlasRegionInput {
    @setEvalBranchQuota(20_000);
    var result: [region_key_count * 2]art_pack.AtlasRegionInput = undefined;
    for (std.enums.values(Style)) |style| {
        for (std.enums.values(RegionKey)) |key| {
            const index = @as(usize, @intFromEnum(style)) * region_key_count + @intFromEnum(key);
            result[index] = .{
                .id = regionId(style, key),
                .stable_name = std.fmt.comptimePrint("{s}_{s}", .{ @tagName(style), @tagName(key) }),
                .page_id = pageForRegion(style, key),
                .source = sourceRect(style, key),
                .authored_size = authoredSize(style, key),
                .pivot = pivotFor(style, key),
            };
        }
    }
    return result;
}

fn makeBindingInputs() [anatomy_binding_count + garment_binding_count]art_pack.VisualBindingInput {
    @setEvalBranchQuota(20_000);
    var result: [anatomy_binding_count + garment_binding_count]art_pack.VisualBindingInput = undefined;
    for (std.enums.values(Style)) |style| {
        for (std.enums.values(presentation_view.View)) |view| {
            for (std.enums.values(Slot)) |slot| {
                const index = (@as(usize, @intFromEnum(style)) * 2 +
                    @as(usize, @intFromEnum(view))) * slot_count + @intFromEnum(slot);
                result[index] = .{
                    .kind = .character,
                    .semantic_id = semanticId(style, slot),
                    .semantic_name = @tagName(slot),
                    .view_id = if (view == .side) art_pack.side_view else art_pack.front_view,
                    .region_id = regionId(style, keyForSlot(slot, view)),
                };
            }
            for (std.enums.values(Garment)) |garment| {
                const index = anatomy_binding_count +
                    (@as(usize, @intFromEnum(style)) * 2 +
                        @as(usize, @intFromEnum(view))) *
                        std.enums.values(Garment).len +
                    @intFromEnum(garment);
                result[index] = .{
                    .kind = .equipment,
                    .semantic_id = garmentSemanticId(style, garment),
                    .semantic_name = @tagName(garment),
                    .view_id = artView(view),
                    .region_id = regionId(style, keyForGarment(garment, view)),
                };
            }
        }
    }
    return result;
}

fn authoredSize(style: Style, key: RegionKey) [2]f32 {
    return switch (key) {
        .side_head, .front_head => .{ 0.68, 0.96 },
        .side_torso => if (style == .male) .{ 0.66, 1.30 } else .{ 0.72, 1.30 },
        .front_torso => if (style == .male) .{ 0.94, 1.30 } else .{ 0.85, 1.30 },
        .side_pelvis => if (style == .male) .{ 0.72, 1.13 } else .{ 0.72, 1.15 },
        .front_pelvis => if (style == .male) .{ 0.96, 0.62 } else .{ 1.08, 0.63 },
        .side_upper_arm => if (style == .male) .{ 0.68, 0.30 } else .{ 0.68, 0.29 },
        .side_forearm => if (style == .male) .{ 0.582, 0.20 } else .{ 0.58, 0.18 },
        .side_hand => if (style == .male) .{ 0.34, 0.20 } else .{ 0.34, 0.18 },
        .side_thigh => if (style == .male) .{ 0.415, 0.93 } else .{ 0.38, 0.919 },
        .side_shin => if (style == .male) .{ 0.28, 0.88 } else .{ 0.28, 0.875 },
        .side_foot => .{ 0.44, 0.167 },
        .front_upper_arm => if (style == .male) .{ 0.255, 0.801 } else .{ 0.25, 0.783 },
        // Both visible forearm spans now resolve to the authoritative
        // elbow-to-wrist distance independently of thickness morphology.
        .front_forearm => if (style == .male) .{ 0.20, 0.568 } else .{ 0.19, 0.568 },
        .front_hand => if (style == .male) .{ 0.20, 0.36 } else .{ 0.15, 0.31 },
        .front_thigh => if (style == .male) .{ 0.36, 0.980 } else .{ 0.46, 1.026 },
        .front_shin => if (style == .male) .{ 0.34, 0.883 } else .{ 0.31, 0.882 },
        .front_foot => if (style == .male) .{ 0.42, 0.172 } else .{ 0.36, 0.190 },
        .side_eye => .{ 0.14, 0.09 },
        .front_left_eye, .front_right_eye => .{ 0.13, 0.085 },
        .side_brow => .{ 0.16, 0.045 },
        .front_brows => .{ 0.35, 0.055 },
        .side_nose => .{ 0.08, 0.15 },
        .front_nose => .{ 0.08, 0.14 },
        .side_mouth => .{ 0.13, 0.055 },
        .front_mouth => .{ 0.20, 0.06 },
        .side_ear, .front_left_ear, .front_right_ear => .{ 0.08, 0.17 },
        .side_hair => if (style == .male) .{ 0.76, 0.42 } else .{ 0.88, 1.16 },
        .front_hair => if (style == .male) .{ 0.76, 0.36 } else .{ 0.96, 1.20 },
        .side_training_vest => if (style == .male) .{ 0.84, 1.30 } else .{ 0.82, 1.30 },
        .front_training_vest => .{ 1.14, 1.30 },
    };
}

fn pivotFor(style: Style, key: RegionKey) [2]f32 {
    return switch (key) {
        // The authored profile bridge overlaps the lower torso above its
        // semantic waist while leaving its tapered lower column behind the
        // independently articulated thigh.
        .side_pelvis => .{ 0.5, 0.403 },
        // Extend the base-presentation bridge behind the upper thighs while
        // preserving its torso-side edge at the authored waist.
        .front_pelvis => if (style == .male) .{ 0.5, 0.305 } else .{ 0.5, 0.362 },
        .side_upper_arm => .{ 0.022, 0.5 },
        .side_forearm => .{ 0.026, 0.5 },
        .side_hand => .{ 0.045, 0.5 },
        .side_thigh => .{ 0.5, 0.984 },
        .side_shin => .{ 0.5, 0.983 },
        // Pivots are the alpha-derived proximal semantic landmarks, so
        // morphology scales about the authoritative joint instead of pulling
        // the visible limb away from it.
        .front_upper_arm => if (style == .male) .{ 0.5, 0.856 } else .{ 0.5, 0.865 },
        .front_forearm => .{ 0.5, 0.981 },
        .front_hand => .{ 0.5, 0.960016 },
        .front_thigh => if (style == .male) .{ 0.5, 0.951154 } else .{ 0.5, 0.945065 },
        .front_shin => .{ 0.5, 0.985 },
        .side_foot => if (style == .male) .{ 0.261357, 0.948980 } else .{ 0.248357, 0.947917 },
        .front_foot => if (style == .male) .{ 0.258478, 0.950980 } else .{ 0.287086, 0.955357 },
        .side_hair, .front_hair => if (style == .male) .{ 0.5, 0.15 } else .{ 0.5, 0.76 },
        else => .{ 0.5, 0.5 },
    };
}

fn restRotation(style: Style, slot: Slot, view: presentation_view.View) f32 {
    _ = style;
    return switch (view) {
        .side => switch (slot) {
            .left_thigh, .right_thigh, .left_shin, .right_shin => std.math.pi / 2.0,
            else => 0,
        },
        .front => switch (slot) {
            .left_upper_arm,
            .right_upper_arm,
            .left_forearm,
            .right_forearm,
            .left_hand,
            .right_hand,
            .left_thigh,
            .right_thigh,
            .left_shin,
            .right_shin,
            => std.math.pi / 2.0,
            else => 0,
        },
    };
}

fn sourceRect(style: Style, key: RegionKey) art_pack.PixelRect {
    if (componentSourceRect(style, key)) |component| return component;
    const base = baseSourceRect(style, key);
    // RegionKey is partitioned between componentSourceRect and baseSourceRect.
    std.debug.assert(base != null);
    return base.?;
}

fn baseSourceRect(style: Style, key: RegionKey) ?art_pack.PixelRect {
    return switch (style) {
        .male => switch (key) {
            .side_head => rect(65, 27, 185, 210),
            .side_torso => rect(284, 17, 379, 233),
            .side_pelvis,
            .side_upper_arm,
            .side_forearm,
            .side_hand,
            .side_thigh,
            .side_shin,
            .side_foot,
            => null,
            .side_eye => rect(275, 312, 346, 360),
            .side_brow => rect(451, 316, 533, 342),
            .side_nose => rect(647, 283, 702, 370),
            .side_mouth => rect(825, 321, 907, 357),
            .side_ear => rect(1048, 284, 1099, 377),
            .side_hair => rect(1202, 284, 1328, 380),
            .front_head => rect(59, 432, 165, 595),
            .front_torso => rect(248, 430, 398, 612),
            .front_pelvis,
            .front_upper_arm,
            .front_forearm,
            .front_hand,
            .front_thigh,
            .front_shin,
            .front_foot,
            => null,
            .front_left_eye => rect(291, 680, 356, 731),
            .front_right_eye => rect(445, 680, 509, 731),
            .front_brows => rect(608, 701, 768, 720),
            .front_nose => rect(871, 665, 933, 743),
            .front_mouth => rect(1047, 697, 1126, 731),
            .front_left_ear => rect(1237, 664, 1288, 754),
            .front_right_ear => rect(1410, 664, 1461, 754),
            .front_hair => rect(59, 796, 183, 945),
            .side_training_vest => rect(433, 772, 531, 962),
            .front_training_vest => rect(990, 771, 1111, 964),
        },
        .female => switch (key) {
            .side_head => rect(46, 40, 157, 203),
            .side_torso => rect(245, 39, 344, 229),
            .side_pelvis,
            .side_upper_arm,
            .side_forearm,
            .side_hand,
            .side_thigh,
            .side_shin,
            .side_foot,
            => null,
            .side_eye => rect(263, 307, 335, 371),
            .side_brow => rect(413, 322, 526, 355),
            .side_nose => rect(628, 298, 686, 384),
            .side_mouth => rect(774, 319, 866, 373),
            .side_ear => rect(956, 293, 1020, 382),
            .side_hair => rect(1107, 223, 1297, 470),
            .front_head => rect(45, 455, 150, 617),
            .front_torso => rect(224, 446, 348, 628),
            .front_pelvis,
            .front_upper_arm,
            .front_forearm,
            .front_hand,
            .front_thigh,
            .front_shin,
            .front_foot,
            => null,
            .front_left_eye => rect(256, 675, 337, 739),
            .front_right_eye => rect(443, 675, 524, 739),
            .front_brows => rect(578, 697, 766, 724),
            .front_nose => rect(822, 665, 886, 750),
            .front_mouth => rect(981, 680, 1077, 735),
            .front_left_ear => rect(1199, 655, 1258, 743),
            .front_right_ear => rect(1413, 655, 1472, 743),
            .front_hair => rect(44, 754, 237, 960),
            .side_training_vest => rect(340, 784, 450, 947),
            .front_training_vest => rect(500, 790, 621, 949),
        },
    };
}

fn pageForRegion(style: Style, key: RegionKey) art_pack.TexturePageId {
    if (isComponentRegion(key)) return component_page_id;
    return if (style == .male) male_page_id else female_page_id;
}

fn isComponentRegion(key: RegionKey) bool {
    return switch (key) {
        .side_pelvis,
        .side_upper_arm,
        .side_forearm,
        .side_hand,
        .side_thigh,
        .side_shin,
        .side_foot,
        .front_pelvis,
        .front_upper_arm,
        .front_forearm,
        .front_hand,
        .front_thigh,
        .front_shin,
        .front_foot,
        => true,
        else => false,
    };
}

fn componentSourceRect(style: Style, key: RegionKey) ?art_pack.PixelRect {
    return switch (style) {
        .male => switch (key) {
            .side_upper_arm => rect(72, 103, 174, 156),
            .side_forearm => rect(335, 111, 422, 137),
            .side_hand => rect(612, 111, 667, 145),
            .side_thigh => rect(857, 51, 917, 206),
            .side_shin => rect(1124, 55, 1161, 173),
            .side_foot => rect(1373, 103, 1443, 152),
            .side_pelvis => rect(1608, 65, 1671, 163),
            .front_upper_arm => rect(209, 317, 247, 427),
            .front_forearm => rect(364, 334, 392, 415),
            .front_hand => rect(623, 352, 656, 416),
            .front_thigh => rect(869, 306, 923, 428),
            .front_shin => rect(1123, 313, 1162, 417),
            .front_foot => rect(1374, 358, 1441, 409),
            .front_pelvis => rect(1607, 292, 1729, 362),
            else => null,
        },
        .female => switch (key) {
            .side_upper_arm => rect(72, 617, 174, 669),
            .side_forearm => rect(335, 624, 422, 651),
            .side_hand => rect(612, 624, 667, 655),
            .side_thigh => rect(854, 563, 916, 718),
            .side_shin => rect(1125, 567, 1163, 685),
            .side_foot => rect(1373, 616, 1443, 664),
            .side_pelvis => rect(1606, 580, 1668, 678),
            .front_upper_arm => rect(209, 827, 246, 937),
            .front_forearm => rect(364, 845, 392, 926),
            .front_hand => rect(624, 864, 655, 928),
            .front_thigh => rect(855, 819, 915, 941),
            .front_shin => rect(1126, 817, 1166, 921),
            .front_foot => rect(1379, 868, 1437, 924),
            .front_pelvis => rect(1580, 833, 1708, 899),
            else => null,
        },
    };
}

fn rect(left: u32, top: u32, right: u32, bottom: u32) art_pack.PixelRect {
    return .{ .x = left, .y = top, .width = right - left, .height = bottom - top };
}
