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

pub const male_page_id: art_pack.TexturePageId = @enumFromInt(41);
pub const female_page_id: art_pack.TexturePageId = @enumFromInt(42);
pub const texture_page_count: usize = 2;

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
        if (presentation.attachment_count != instance.definition.attachments.len) {
            return error.PresentationDefinitionMismatch;
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
            const world_size = sprite_transform.signed_scale.componentMul(.{
                .x = selected.visual.authored_size[0],
                .y = selected.visual.authored_size[1],
            });
            const order = presentationOrder(instance, attachment, binding.slot, presentation.style, view);
            const key = try queue.submitSprite(.{
                .world_position = sprite_transform.world_position.toArray(),
                .rotation = sprite_transform.rotation_radians +
                    presentationRestRotation(
                        selected.rest_rotation,
                        binding.slot,
                        view,
                        instance.facing,
                    ),
                .scale = world_size.toArray(),
                .pivot = selected.visual.pivot,
                .uv_rect = selected.visual.uv_rect,
                .tint = .{ 1, 1, 1, 1 },
                .texture_page = presentation.renderer_page_offset + selected.visual.texture_page,
                .order = order,
            });
            if (attachment.canonical_semantic) |raw_semantic| {
                instance.last_submitted_keys[raw_semantic] = key;
            }
            submitted += 1;
        }
        return submitted;
    }
};

fn presentationOrder(
    instance: *const character.CharacterInstance,
    attachment: appearance.VisualAttachment,
    slot: Slot,
    style: Style,
    view: presentation_view.View,
) sprite.OrderInput {
    const default_layer = if (attachment.canonical_semantic) |raw_semantic| layer: {
        const semantic: humanoid.AttachmentSemantic = @enumFromInt(raw_semantic);
        const authored_layer = switch (view) {
            .side => sideBodyPartLayer(semantic, instance.facing),
            .front => frontBodyPartLayer(semantic),
        };
        break :layer if (style == .male)
            maleConnectorLayer(semantic, authored_layer)
        else
            authored_layer;
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

fn maleConnectorLayer(
    semantic: humanoid.AttachmentSemantic,
    authored_layer: u16,
) u16 {
    return switch (semantic) {
        .pelvis => 9,
        .left_thigh, .right_thigh => authored_layer - 1,
        .left_shin, .right_shin => authored_layer + 1,
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
        .left_hand, .right_hand => if (front) 24 else 20,
        .left_forearm, .right_forearm => if (front) 25 else 21,
        .left_upper_arm, .right_upper_arm => if (front) 26 else 22,
    };
}

fn sideFeatureVisible(slot: Slot) bool {
    return slot != .left_eye and slot != .left_ear;
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
                .page_id = if (style == .male) male_page_id else female_page_id,
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
        .side_head, .front_head => .{ 0.78, 0.86 },
        .side_torso => if (style == .male) .{ 0.84, 1.30 } else .{ 0.82, 1.30 },
        .front_torso => .{ 1.14, 1.30 },
        .side_pelvis, .front_pelvis => if (style == .male) .{ 0.90, 0.70 } else .{ 1.08, 0.72 },
        .side_upper_arm => if (style == .male) .{ 0.71, 0.28 } else .{ 0.71, 0.27 },
        .side_forearm => .{ 0.68, 0.24 },
        .side_hand => .{ 0.38, 0.22 },
        .side_thigh, .front_thigh => .{ 0.36, 1.05 },
        .side_shin, .front_shin => .{ 0.30, 0.99 },
        .side_foot, .front_foot => .{ 0.48, 0.26 },
        .front_upper_arm => if (style == .male) .{ 0.28, 0.78 } else .{ 0.27, 0.78 },
        .front_forearm => .{ 0.24, 0.68 },
        .front_hand => .{ 0.24, 0.38 },
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
        .side_upper_arm => .{ 0, 0.5 },
        .side_forearm, .side_hand => .{ 0.09, 0.5 },
        .side_thigh, .side_shin, .front_thigh, .front_shin => .{ 0.5, 0.93 },
        .front_upper_arm => .{ 0.5, 1 },
        .front_forearm, .front_hand => .{ 0.5, 0.93 },
        .side_foot, .front_foot => .{ 0.12, 0.55 },
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
    return switch (style) {
        .male => switch (key) {
            .side_head => rect(65, 27, 185, 210),
            .side_torso => rect(284, 17, 379, 233),
            .side_pelvis => rect(460, 24, 573, 239),
            .side_upper_arm => rect(650, 104, 794, 163),
            // The generated forearm candidate included hand detail at its distal
            // end. Reusing the clean straight segment keeps the semantic
            // forearm independent while preserving the intended taper at its
            // smaller authored size.
            .side_forearm => rect(650, 104, 794, 163),
            .side_hand => rect(1048, 115, 1164, 187),
            .side_thigh => rect(1284, 23, 1339, 229),
            .side_shin => rect(1444, 23, 1498, 229),
            .side_foot => rect(60, 301, 173, 377),
            .side_eye => rect(275, 312, 346, 360),
            .side_brow => rect(451, 316, 533, 342),
            .side_nose => rect(647, 283, 702, 370),
            .side_mouth => rect(825, 321, 907, 357),
            .side_ear => rect(1048, 284, 1099, 377),
            .side_hair => rect(1202, 284, 1328, 380),
            .front_head => rect(59, 432, 165, 595),
            .front_torso => rect(252, 431, 398, 611),
            .front_pelvis => rect(453, 442, 571, 614),
            .front_upper_arm => rect(662, 437, 713, 613),
            .front_forearm => rect(870, 436, 919, 613),
            .front_hand => rect(1045, 436, 1109, 572),
            .front_thigh => rect(1237, 419, 1296, 610),
            .front_shin => rect(1426, 420, 1479, 610),
            .front_foot => rect(62, 663, 176, 741),
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
            .side_pelvis => rect(408, 54, 523, 237),
            .side_upper_arm => rect(605, 108, 726, 164),
            .side_forearm => rect(783, 108, 910, 164),
            .side_hand => rect(962, 101, 1124, 167),
            .side_thigh => rect(1234, 36, 1294, 210),
            // The dedicated generated cell incorrectly included a foot.
            // A separate region identity intentionally reuses the clean
            // straight lower-limb source; authored geometry remains distinct.
            .side_shin => rect(1234, 36, 1294, 210),
            .side_foot => rect(57, 299, 181, 400),
            .side_eye => rect(263, 307, 335, 371),
            .side_brow => rect(413, 322, 526, 355),
            .side_nose => rect(628, 298, 686, 384),
            .side_mouth => rect(774, 319, 866, 373),
            .side_ear => rect(956, 293, 1020, 382),
            .side_hair => rect(1107, 223, 1297, 470),
            .front_head => rect(45, 455, 150, 617),
            .front_torso => rect(214, 447, 357, 627),
            .front_pelvis => rect(404, 461, 556, 635),
            .front_upper_arm => rect(630, 471, 685, 621),
            .front_forearm => rect(812, 474, 865, 626),
            .front_hand => rect(958, 512, 1120, 580),
            .front_thigh => rect(1234, 464, 1300, 635),
            .front_shin => rect(1234, 464, 1300, 635),
            .front_foot => rect(63, 653, 180, 750),
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

fn rect(left: u32, top: u32, right: u32, bottom: u32) art_pack.PixelRect {
    return .{ .x = left, .y = top, .width = right - left, .height = bottom - top };
}
