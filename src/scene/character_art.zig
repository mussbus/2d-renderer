const std = @import("std");
const math = @import("math");
const art_pack = @import("art_pack");
const humanoid = @import("humanoid");
const character = @import("character");
const appearance = @import("appearance");
const skeleton = @import("skeleton");
const presentation_pose = @import("presentation_pose");
const presentation_view = @import("presentation_view");
const render_queue = @import("render_queue");
const sprite = @import("sprite_batch");
const visual_geometry = @import("visual_geometry");
const visual_registration = @import("visual_registration");
const image_decode = @import("image_decode");
const anatomy = @import("anatomy");

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

pub const FootPixelPolicy = enum(u8) {
    render,
    suppress_covered_pixels,
};

pub const FootCoverage = struct {
    left: FootPixelPolicy = .render,
    right: FootPixelPolicy = .render,

    fn forSlot(coverage: FootCoverage, slot: Slot) FootPixelPolicy {
        return switch (slot) {
            .left_foot => coverage.left,
            .right_foot => coverage.right,
            else => .render,
        };
    }
};

pub const FrontFootGroundPolicy = struct {
    toe_out_degrees: f32,
    /// Ground-plane lateral component. Negative is anatomical left and
    /// positive is anatomical right.
    lateral: f32,
    /// Ground-plane depth component, retained as policy evidence. Front
    /// projection discards it rather than treating it as world Y.
    depth: f32,
    /// Exact projected world-XY target consumed by registration.
    projected_support_tangent: math.Vec2,
};

pub const RegisteredFoot = struct {
    placement: visual_registration.Placement,
    view: presentation_view.View,
    orientation_target: visual_registration.PointAxisTarget,
    front_ground_policy: ?FrontFootGroundPolicy = null,
    heel_world: math.Vec2,
    toe_world: math.Vec2,
    sole_back_world: math.Vec2,
    sole_front_world: math.Vec2,

    /// Heel/toe are transformed evidence for the point binding's authored
    /// orientation. They are not independent registration targets.
    pub fn orientationAxis(foot: RegisteredFoot) math.Vec2 {
        return foot.toe_world.sub(foot.heel_world);
    }

    /// Base anatomy and equipped footwear consume this exact target. It is
    /// created by the base-foot registration result and is not reconstructed
    /// from a second wardrobe placement formula.
    pub fn pointAxisTarget(foot: RegisteredFoot) visual_registration.PointAxisTarget {
        return foot.orientation_target;
    }
};

pub const RegisteredFeet = struct {
    left: ?RegisteredFoot = null,
    right: ?RegisteredFoot = null,

    pub fn begin(feet: *RegisteredFeet) void {
        feet.* = .{};
    }

    pub fn forSide(
        feet: RegisteredFeet,
        side: visual_geometry.Side,
    ) !RegisteredFoot {
        return switch (side) {
            .left => feet.left orelse error.MissingRegisteredAnatomyFoot,
            .right => feet.right orelse error.MissingRegisteredAnatomyFoot,
            .none => error.InvalidRegisteredAnatomyFootSide,
        };
    }

    fn record(
        feet: *RegisteredFeet,
        slot: Slot,
        foot: RegisteredFoot,
    ) !void {
        switch (slot) {
            .left_foot => {
                if (feet.left != null) return error.DuplicateRegisteredAnatomyFoot;
                feet.left = foot;
            },
            .right_foot => {
                if (feet.right != null) return error.DuplicateRegisteredAnatomyFoot;
                feet.right = foot;
            },
            else => return error.InvalidRegisteredAnatomyFootSlot,
        }
    }

    pub fn validateComplete(feet: RegisteredFeet) !void {
        if (feet.left == null or feet.right == null) {
            return error.IncompleteRegisteredAnatomyFeet;
        }
    }
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
    left_eyebrow,
    right_eyebrow,
    extra_upper_arm,
    extra_forearm,
    extra_hand,
    extra_second_upper_arm,
    extra_second_forearm,
    extra_second_hand,
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
    front_left_brow,
    front_right_brow,
};

const region_key_count = std.enums.values(RegionKey).len;
const anatomy_binding_count = slot_count * 4;
const garment_binding_count = std.enums.values(Style).len *
    std.enums.values(presentation_view.View).len *
    std.enums.values(Garment).len;

pub const page_inputs = [_]art_pack.TexturePageInput{
    .{
        .id = male_page_id,
        .stable_name = "p27c_male_base_anatomy_atlas",
        .asset_path = "art/p27c_male_base_anatomy_atlas.png",
        .sampling = .nearest,
        .expected_width = 1600,
        .expected_height = 983,
    },
    .{
        .id = female_page_id,
        .stable_name = "p27c_female_base_anatomy_atlas",
        .asset_path = "art/p27c_female_base_anatomy_atlas.png",
        .sampling = .nearest,
        .expected_width = 1599,
        .expected_height = 984,
    },
    .{
        .id = component_page_id,
        .stable_name = "p27c_anatomy_components_atlas",
        .asset_path = "art/p27c_anatomy_components_atlas.png",
        .sampling = .nearest,
        .expected_width = 1792,
        .expected_height = 1024,
    },
};

pub const region_inputs = makeRegionInputs();
pub const binding_inputs = makeBindingInputs();

const RegistrationAlphaEntry = struct {
    region_id: art_pack.AtlasRegionId,
    alpha: visual_geometry.AlphaGeometry,
};

const RegistrationAlphaCatalog = struct {
    entries: [region_inputs.len]RegistrationAlphaEntry = undefined,
    count: usize = 0,

    fn init() !RegistrationAlphaCatalog {
        var catalog = RegistrationAlphaCatalog{};
        for (page_inputs) |page| {
            var path_buffer: [256]u8 = undefined;
            const path = try std.fmt.bufPrint(
                &path_buffer,
                "assets/{s}",
                .{page.asset_path},
            );
            var decoded = try image_decode.decodePngFile(
                std.heap.smp_allocator,
                path,
                null,
            );
            defer decoded.deinit();
            for (region_inputs) |region| {
                if (region.page_id != page.id) continue;
                if (catalog.count == catalog.entries.len) {
                    return error.RegistrationAlphaCatalogCapacityExceeded;
                }
                catalog.entries[catalog.count] = .{
                    .region_id = region.id,
                    .alpha = try visual_geometry.deriveAlphaGeometry(
                        decoded.pixels,
                        decoded.layout.width,
                        decoded.layout.height,
                        decoded.layout.row_bytes,
                        .{
                            .x = region.source.x,
                            .y = region.source.y,
                            .width = region.source.width,
                            .height = region.source.height,
                        },
                    ),
                };
                catalog.count += 1;
            }
        }
        if (catalog.count != catalog.entries.len) {
            return error.IncompleteRegistrationAlphaCatalog;
        }
        return catalog;
    }

    fn find(
        catalog: RegistrationAlphaCatalog,
        region_id: art_pack.AtlasRegionId,
    ) !visual_geometry.AlphaGeometry {
        for (catalog.entries[0..catalog.count]) |entry| {
            if (entry.region_id == region_id) return entry.alpha;
        }
        return error.MissingRegistrationAlphaGeometry;
    }
};

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
    registration_alpha: RegistrationAlphaCatalog,

    pub fn init(allocator: std.mem.Allocator) !Definition {
        const registration_alpha = try RegistrationAlphaCatalog.init();
        var definition = Definition{
            .art = try art_pack.Definition.init(allocator, definitionInput()),
            .registration_alpha = registration_alpha,
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

    pub fn registrationAlpha(
        definition: *const Definition,
        region_id: art_pack.AtlasRegionId,
    ) !visual_geometry.AlphaGeometry {
        return definition.registration_alpha.find(region_id);
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
    alpha: visual_geometry.AlphaGeometry,
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
            const side = try definition.art.resolve(
                .character,
                semantic_id,
                art_pack.side_view,
            );
            const front = try definition.art.resolve(
                .character,
                semantic_id,
                art_pack.front_view,
            );
            result.bindings[attachment.id.index()] = .{
                .active = true,
                .slot = slot,
                .side = .{
                    .visual = side,
                    .rest_rotation = restRotation(style, slot, .side),
                    .alpha = try definition.registration_alpha.find(side.region_id),
                },
                .front = .{
                    .visual = front,
                    .rest_rotation = restRotation(style, slot, .front),
                    .alpha = try definition.registration_alpha.find(front.region_id),
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
        var ignored_registered_feet = RegisteredFeet{};
        return presentation.submitTracedWithRegisteredFeet(
            instance,
            queue,
            trace,
            &ignored_registered_feet,
        );
    }

    pub fn submitTracedWithRegisteredFeet(
        presentation: Presentation,
        instance: *character.CharacterInstance,
        queue: *render_queue.UnifiedRenderQueue,
        trace: ?*visual_geometry.Trace,
        registered_feet: *RegisteredFeet,
    ) !u32 {
        return presentation.submitTracedWithRegisteredFeetAndCoverage(
            instance,
            queue,
            trace,
            registered_feet,
            .{},
        );
    }

    pub fn submitTracedWithRegisteredFeetAndCoverage(
        presentation: Presentation,
        instance: *character.CharacterInstance,
        queue: *render_queue.UnifiedRenderQueue,
        trace: ?*visual_geometry.Trace,
        registered_feet: *RegisteredFeet,
        foot_coverage: FootCoverage,
    ) !u32 {
        if (presentation.attachment_count != instance.definition.attachments.len) {
            return error.PresentationDefinitionMismatch;
        }
        registered_feet.begin();
        const view = instance.presentationView();
        const projection = try presentation.projectionFor(instance);
        var anatomy_projection: ?presentation_pose.FrontAnatomyProjection = if (instance.definition.anatomy_definition) |anatomy_definition| if (instance.character.anatomy_runtime) |anatomy_runtime|
            try presentation_pose.FrontAnatomyProjection.init(
                projection,
                anatomy_definition,
                anatomy_runtime,
            )
        else
            null else null;

        instance.last_submitted_keys =
            [_]?sprite.DrawOrderKey{null} ** humanoid.canonical_attachment_semantic_count;
        var submitted: u32 = 0;
        var optional_submissions: [6]OptionalArmSubmission = undefined;
        var optional_submission_count: usize = 0;
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
                if (anatomy_projection) |*value| value else null,
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
            const legacy_request = sprite.SpriteRequest{
                .world_position = sprite_transform.world_position.toArray(),
                .rotation = sprite_transform.rotation_radians + rest_rotation,
                .scale = world_size.toArray(),
                .pivot = selected.visual.pivot,
                .uv_rect = selected.visual.uv_rect,
                .tint = technicalTint(binding.slot),
                .texture_page = presentation.renderer_page_offset + selected.visual.texture_page,
                .order = order,
            };
            const geometry = geometryForSlot(
                presentation.style,
                binding.slot,
                geometryView(view, instance.facing),
            );
            const registered = try productionRegistration(
                instance,
                attachment,
                binding.slot,
                presentation.style,
                view,
                projection,
                selected,
                geometry,
                legacy_request,
            );
            const request = if (registered) |placement|
                placement.request
            else
                legacy_request;
            if (registered) |placement| {
                if (binding.slot == .left_foot or binding.slot == .right_foot) {
                    const heel = try visual_registration.sourcePoint(
                        selected.alpha,
                        geometry,
                        .heel,
                        .point,
                    );
                    const toe = try visual_registration.sourcePoint(
                        selected.alpha,
                        geometry,
                        .toe,
                        .point,
                    );
                    const sole_back = try visual_registration.sourcePoint(
                        selected.alpha,
                        geometry,
                        .sole_back,
                        .point,
                    );
                    const sole_front = try visual_registration.sourcePoint(
                        selected.alpha,
                        geometry,
                        .sole_front,
                        .point,
                    );
                    const heel_world = sprite.localPointToWorld(
                        placement.request,
                        heel.local.toArray(),
                    );
                    const toe_world = sprite.localPointToWorld(
                        placement.request,
                        toe.local.toArray(),
                    );
                    const sole_back_world = sprite.localPointToWorld(
                        placement.request,
                        sole_back.local.toArray(),
                    );
                    const sole_front_world = sprite.localPointToWorld(
                        placement.request,
                        sole_front.local.toArray(),
                    );
                    const orientation_target = if (placement.evidence.axis) |axis|
                        visual_registration.PointAxisTarget{
                            .anchor = .{
                                .role = .point,
                                .identity = placement.evidence.points[0].target_identity,
                                .world = placement.evidence.points[0].target_world,
                            },
                            .axis_identity = axis.reference_identity,
                            .direction_world = axis.reference_vector_world,
                        }
                    else
                        visual_registration.PointAxisTarget{
                            .anchor = .{
                                .role = .point,
                                .identity = placement.evidence.points[0].target_identity,
                                .world = placement.evidence.points[0].target_world,
                            },
                            .axis_identity = "registered_side_foot.sole_axis",
                            .direction_world = math.Vec2{
                                .x = sole_front_world[0] - sole_back_world[0],
                                .y = sole_front_world[1] - sole_back_world[1],
                            },
                        };
                    try registered_feet.record(binding.slot, .{
                        .placement = placement,
                        .view = view,
                        .orientation_target = orientation_target,
                        .front_ground_policy = if (view == .front)
                            try frontFootGroundPolicy(
                                presentation.style,
                                geometrySide(binding.slot),
                            )
                        else
                            null,
                        .heel_world = .{
                            .x = heel_world[0],
                            .y = heel_world[1],
                        },
                        .toe_world = .{
                            .x = toe_world[0],
                            .y = toe_world[1],
                        },
                        .sole_back_world = .{
                            .x = sole_back_world[0],
                            .y = sole_back_world[1],
                        },
                        .sole_front_world = .{
                            .x = sole_front_world[0],
                            .y = sole_front_world[1],
                        },
                    });
                }
            }
            const pixel_policy = foot_coverage.forSlot(binding.slot);
            const suppressed = pixel_policy == .suppress_covered_pixels;
            const graph_binding = try graphBindingEvidence(
                instance,
                attachment,
                binding.slot,
                projection,
            );
            const submission_index: u32 = if (suppressed)
                std.math.maxInt(u32)
            else
                @intCast(queue.sprite_count);
            const key: ?sprite.DrawOrderKey = if (suppressed)
                null
            else
                try queue.submitSprite(request);
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
                    .geometry = geometry,
                    .world_geometry = if (registered != null)
                        null
                    else
                        try anatomyRootWorldGeometry(
                            instance,
                            binding.slot,
                            projection,
                        ),
                    .morphology_length_scale = @abs(if (view == .front)
                        morphology_scale.y
                    else
                        morphology_scale.x),
                    .binding_rotation_radians = if (registered) |placement|
                        placement.request.rotation
                    else
                        sprite_transform.rotation_radians,
                    .submission_index = submission_index,
                    .registration = if (registered) |placement|
                        placement.evidence
                    else
                        null,
                    .placement_authority = if (registered != null)
                        .authoritative_registration
                    else
                        .transitional_legacy,
                    .submission_visibility = if (suppressed)
                        .suppressed_by_closed_footwear
                    else
                        .rendered,
                    .graph_binding = graph_binding,
                });
            }
            if (key) |submitted_key| {
                if (attachment.canonical_semantic) |raw_semantic| {
                    instance.last_submitted_keys[raw_semantic] = submitted_key;
                }
                if (graph_binding) |binding_evidence| {
                    if (optional_submission_count == optional_submissions.len) {
                        return error.OptionalArmSubmissionCapacityExceeded;
                    }
                    optional_submissions[optional_submission_count] = .{
                        .visual_id = attachment.id,
                        .component_id = @enumFromInt(binding_evidence.component_id),
                        .module_id = @enumFromInt(binding_evidence.module_id),
                        .start_kind = binding_evidence.start_kind,
                        .start_global_index = binding_evidence.start_global_index,
                        .end_kind = binding_evidence.end_kind,
                        .end_global_index = binding_evidence.end_global_index,
                        .view = view,
                        .submission_index = submission_index,
                    };
                    optional_submission_count += 1;
                }
                submitted += 1;
            }
        }
        _ = try validateOptionalArmSubmissions(
            instance,
            view,
            optional_submissions[0..optional_submission_count],
        );
        try registered_feet.validateComplete();
        return submitted;
    }

    /// Builds the exact view-specific projection consumed by production
    /// submission. Read-only diagnostics call this method so canonical versus
    /// presented transforms cannot drift through a second formula.
    pub fn projectionFor(
        presentation: Presentation,
        instance: *const character.CharacterInstance,
    ) !presentation_pose.FrontProjection {
        _ = presentation;
        var result = switch (instance.presentationView()) {
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
        const anatomy_definition = instance.definition.anatomy_definition orelse
            return error.CharacterHasNoAnatomy;
        const anatomy_runtime = instance.character.anatomy_runtime orelse
            return error.CharacterHasNoAnatomy;
        try result.bindActiveOptionalArmModules(
            instance.definition.visual_definition,
            instance.character.appearance_runtime,
            anatomy_definition,
            anatomy_runtime,
        );
        return result;
    }
};

fn geometryForSlot(
    style: Style,
    slot: Slot,
    view: visual_geometry.View,
) visual_geometry.Geometry {
    return switch (slot) {
        .left_eye,
        .right_eye,
        .left_eyebrow,
        .right_eyebrow,
        .eyebrows,
        .nose,
        .mouth,
        .left_ear,
        .right_ear,
        => visual_geometry.Geometry.init(.face_feature, &.{
            .{ .kind = .center, .visible_uv = .{ 0.5, 0.5 } },
        }),
        else => visual_geometry.anatomyGeometry(
            @tagName(style),
            geometryRole(slot),
            view,
        ),
    };
}

fn technicalTint(slot: Slot) [4]f32 {
    return switch (slot) {
        .extra_upper_arm,
        .extra_forearm,
        .extra_hand,
        => .{ 0.32, 1.0, 0.92, 1.0 },
        .extra_second_upper_arm,
        .extra_second_forearm,
        .extra_second_hand,
        => .{ 1.0, 0.36, 0.88, 1.0 },
        else => .{ 1, 1, 1, 1 },
    };
}

fn productionRegistration(
    instance: *const character.CharacterInstance,
    attachment: appearance.VisualAttachment,
    slot: Slot,
    style: Style,
    view: presentation_view.View,
    projection: presentation_pose.FrontProjection,
    selected: ViewBinding,
    geometry: visual_geometry.Geometry,
    legacy_request: sprite.SpriteRequest,
) !?visual_registration.Placement {
    return switch (slot) {
        .left_upper_arm,
        .right_upper_arm,
        .left_forearm,
        .right_forearm,
        .left_thigh,
        .right_thigh,
        .left_shin,
        .right_shin,
        => try segmentRegistration(
            instance,
            slot,
            style,
            view,
            projection,
            selected,
            geometry,
            legacy_request,
        ),
        .extra_upper_arm,
        .extra_forearm,
        .extra_hand,
        .extra_second_upper_arm,
        .extra_second_forearm,
        .extra_second_hand,
        => try optionalArmSegmentRegistration(
            instance,
            slot,
            view,
            projection,
            selected,
            geometry,
            legacy_request,
        ),
        .left_foot, .right_foot => try footRegistration(
            instance,
            slot,
            style,
            view,
            projection,
            selected,
            geometry,
            legacy_request,
        ),
        .left_eye,
        .right_eye,
        .left_eyebrow,
        .right_eyebrow,
        .nose,
        => try componentPointRegistration(
            instance,
            attachment,
            slot,
            view,
            projection,
            selected,
            geometry,
            legacy_request,
            .center,
        ),
        .hair => try componentPointRegistration(
            instance,
            attachment,
            slot,
            view,
            projection,
            selected,
            geometry,
            legacy_request,
            .proximal,
        ),
        .torso, .pelvis => try frameRegistration(
            instance,
            slot,
            view,
            projection,
            selected,
            geometry,
            legacy_request,
        ),
        else => null,
    };
}

const ModuleEndpointKind = enum(u8) {
    joint,
    socket,
};

const OptionalArmContract = struct {
    component_name: []const u8,
    module_name: []const u8,
    start_kind: ModuleEndpointKind,
    start_name: []const u8,
    end_kind: ModuleEndpointKind,
    end_name: []const u8,
    source_start: visual_geometry.LandmarkKind,
    source_end: visual_geometry.LandmarkKind,
};

fn optionalArmContract(slot: Slot) ?OptionalArmContract {
    return switch (slot) {
        .extra_upper_arm => .{
            .component_name = "extra_arm",
            .module_name = "extra_arm_module",
            .start_kind = .joint,
            .start_name = "shoulder",
            .end_kind = .joint,
            .end_name = "elbow",
            .source_start = .shoulder,
            .source_end = .elbow,
        },
        .extra_forearm => .{
            .component_name = "extra_arm",
            .module_name = "extra_arm_module",
            .start_kind = .joint,
            .start_name = "elbow",
            .end_kind = .joint,
            .end_name = "wrist",
            .source_start = .elbow,
            .source_end = .wrist,
        },
        .extra_hand => .{
            .component_name = "extra_arm",
            .module_name = "extra_arm_module",
            .start_kind = .joint,
            .start_name = "wrist",
            .end_kind = .socket,
            .end_name = "hand_tip",
            .source_start = .wrist,
            .source_end = .fingertip,
        },
        .extra_second_upper_arm => .{
            .component_name = "extra_arm_second",
            .module_name = "extra_arm_module_second",
            .start_kind = .joint,
            .start_name = "shoulder",
            .end_kind = .joint,
            .end_name = "elbow",
            .source_start = .shoulder,
            .source_end = .elbow,
        },
        .extra_second_forearm => .{
            .component_name = "extra_arm_second",
            .module_name = "extra_arm_module_second",
            .start_kind = .joint,
            .start_name = "elbow",
            .end_kind = .joint,
            .end_name = "wrist",
            .source_start = .elbow,
            .source_end = .wrist,
        },
        .extra_second_hand => .{
            .component_name = "extra_arm_second",
            .module_name = "extra_arm_module_second",
            .start_kind = .joint,
            .start_name = "wrist",
            .end_kind = .socket,
            .end_name = "hand_tip",
            .source_start = .wrist,
            .source_end = .fingertip,
        },
        else => null,
    };
}

pub const OptionalArmSubmission = struct {
    visual_id: appearance.VisualAttachmentId,
    component_id: anatomy.BodyPartInstanceId,
    module_id: appearance.RigModuleId,
    start_kind: visual_geometry.GraphEndpointKind,
    start_global_index: u16,
    end_kind: visual_geometry.GraphEndpointKind,
    end_global_index: u16,
    view: presentation_view.View,
    submission_index: u32,
};

pub const OptionalArmSubmissionCounts = struct {
    active_modules: u8 = 0,
    expected_submissions: u8 = 0,
    actual_submissions: u8 = 0,
    missing_submissions: u8 = 0,
    orphan_submissions: u8 = 0,
};

fn optionalArmSegmentRegistration(
    instance: *const character.CharacterInstance,
    slot: Slot,
    view: presentation_view.View,
    projection: presentation_pose.FrontProjection,
    selected: ViewBinding,
    geometry: visual_geometry.Geometry,
    legacy_request: sprite.SpriteRequest,
) !visual_registration.Placement {
    const contract = optionalArmContract(slot) orelse
        return error.MissingOptionalArmRegistrationContract;
    const source_proximal = try visual_registration.sourcePoint(
        selected.alpha,
        geometry,
        contract.source_start,
        .proximal,
    );
    const source_distal = try visual_registration.sourcePoint(
        selected.alpha,
        geometry,
        contract.source_end,
        .distal,
    );
    const module = try findModuleByName(
        instance.definition.visual_definition,
        contract.module_name,
    );
    const start = try moduleEndpoint(
        instance.definition.visual_definition,
        projection,
        module,
        contract.start_kind,
        contract.start_name,
        .proximal,
    );
    const end = try moduleEndpoint(
        instance.definition.visual_definition,
        projection,
        module,
        contract.end_kind,
        contract.end_name,
        .distal,
    );
    const source_axis = source_distal.local.sub(source_proximal.local);
    const transverse_scale = if (@abs(source_axis.x) >= @abs(source_axis.y))
        @abs(legacy_request.scale[1])
    else
        @abs(legacy_request.scale[0]);
    const reflect_transverse = view == .side and instance.facing == .left;
    return visual_registration.solveSegment(
        .{
            .identity = instance.definition.visual_definition.visuals[
                try optionalVisualIdForSlot(
                    instance.definition.visual_definition,
                    slot,
                )
            ].debug_name.slice(),
            .binding_mode = .segment,
            .scale_policy = .segment_longitudinal_transverse,
            .mirroring_policy = if (reflect_transverse)
                .transverse_reflection
            else
                .none,
            .allows_reflection = true,
        },
        legacy_request,
        source_proximal,
        source_distal,
        start.target,
        end.target,
        transverse_scale,
        reflect_transverse,
    );
}

const ResolvedModuleEndpoint = struct {
    kind: visual_geometry.GraphEndpointKind,
    global_index: u16,
    identity: []const u8,
    target: visual_registration.TargetPoint,
};

fn moduleEndpoint(
    definition: appearance.DefinitionView,
    projection: presentation_pose.FrontProjection,
    module: appearance.RigModule,
    kind: ModuleEndpointKind,
    name: []const u8,
    role: visual_registration.EndpointRole,
) !ResolvedModuleEndpoint {
    return switch (kind) {
        .joint => {
            for (0..module.joint_count) |local_index| {
                const global_index: u16 = @intCast(
                    module.joint_start + local_index,
                );
                const joint = &definition.module_joints[global_index];
                if (!std.mem.eql(u8, joint.debug_name.slice(), name)) continue;
                const world = projection.module_joint_world[global_index]
                    .translationPart();
                return .{
                    .kind = .module_joint,
                    .global_index = global_index,
                    .identity = joint.debug_name.slice(),
                    .target = try visual_registration.targetPoint(
                        joint.debug_name.slice(),
                        world,
                        role,
                    ),
                };
            }
            return error.RigModuleJointMissing;
        },
        .socket => {
            for (0..module.socket_count) |local_index| {
                const global_index: u16 = @intCast(
                    module.socket_start + local_index,
                );
                const socket_value = &definition.module_sockets[global_index];
                if (!std.mem.eql(u8, socket_value.debug_name.slice(), name)) continue;
                const world = projection.module_socket_world[global_index]
                    .translationPart();
                return .{
                    .kind = .module_socket,
                    .global_index = global_index,
                    .identity = socket_value.debug_name.slice(),
                    .target = try visual_registration.targetPoint(
                        socket_value.debug_name.slice(),
                        world,
                        role,
                    ),
                };
            }
            return error.RigModuleEndSocketMissing;
        },
    };
}

fn findModuleByName(
    definition: appearance.DefinitionView,
    name: []const u8,
) !appearance.RigModule {
    for (definition.rig_modules) |module| {
        if (std.mem.eql(u8, module.debug_name.slice(), name)) return module;
    }
    return error.InvalidRigModuleId;
}

fn optionalVisualIdForSlot(
    definition: appearance.DefinitionView,
    slot: Slot,
) !usize {
    for (definition.visuals) |visual| {
        if (std.mem.eql(u8, visual.debug_name.slice(), @tagName(slot))) {
            return visual.id.index();
        }
    }
    return error.MissingOptionalArmVisualIdentity;
}

fn graphBindingEvidence(
    instance: *const character.CharacterInstance,
    attachment: appearance.VisualAttachment,
    slot: Slot,
    projection: presentation_pose.FrontProjection,
) !?visual_geometry.GraphBindingEvidence {
    const contract = optionalArmContract(slot) orelse return null;
    const anatomy_definition = instance.definition.anatomy_definition orelse
        return error.CharacterHasNoAnatomy;
    const graph_definition = instance.definition.component_graph_definition orelse
        return error.CharacterHasNoComponentGraph;
    const graph = try graph_definition.view(
        instance.definition.visual_definition,
        anatomy_definition,
    );
    const anatomy_runtime = instance.character.anatomy_runtime orelse
        return error.CharacterHasNoAnatomy;
    const component_id = try anatomy_definition.partInstanceId(
        contract.component_name,
    );
    const component = try graph.component(component_id);
    const module_id = component.instance.articulation_module orelse
        return error.RequiredRigModuleMissing;
    const module = instance.definition.visual_definition.rig_modules[
        module_id.index()
    ];
    if (!std.mem.eql(u8, module.debug_name.slice(), contract.module_name)) {
        return error.OptionalArmModuleOwnershipMismatch;
    }
    const parent_component = component.parent_component orelse
        return error.OptionalArmParentComponentMissing;
    const visuals = try graph.boundVisuals(
        component_id,
        anatomy_runtime.selected_presentation_profile,
    );
    var graph_visual_index: ?u8 = null;
    for (visuals, 0..) |visual_id, index| {
        if (visual_id != attachment.id) continue;
        if (graph_visual_index != null) return error.DuplicateOptionalArmGraphVisual;
        graph_visual_index = @intCast(index);
    }
    const resolved_index = graph_visual_index orelse
        return error.OptionalArmVisualNotDeclaredByGraph;
    const start = try moduleEndpoint(
        instance.definition.visual_definition,
        projection,
        module,
        contract.start_kind,
        contract.start_name,
        .proximal,
    );
    const end = try moduleEndpoint(
        instance.definition.visual_definition,
        projection,
        module,
        contract.end_kind,
        contract.end_name,
        .distal,
    );
    return .{
        .component_id = @intCast(component_id.index()),
        .component_identity = anatomy_definition.part_instances[
            component_id.index()
        ].stable_id.slice(),
        .parent_component_id = @intCast(parent_component.index()),
        .parent_component_identity = anatomy_definition.part_instances[
            parent_component.index()
        ].stable_id.slice(),
        .module_id = @intCast(module_id.index()),
        .module_identity = instance.definition.visual_definition.rig_modules[
            module_id.index()
        ].debug_name.slice(),
        .graph_visual_index = resolved_index,
        .source_identity = instance.definition.visual_definition.visuals[
            attachment.id.index()
        ].debug_name.slice(),
        .start_kind = start.kind,
        .start_global_index = start.global_index,
        .start_identity = start.identity,
        .end_kind = end.kind,
        .end_global_index = end.global_index,
        .end_identity = end.identity,
    };
}

pub fn validateOptionalArmSubmissions(
    instance: *const character.CharacterInstance,
    view: presentation_view.View,
    submissions: []const OptionalArmSubmission,
) !OptionalArmSubmissionCounts {
    if (submissions.len > 6) return error.OptionalArmSubmissionCapacityExceeded;
    const anatomy_definition = instance.definition.anatomy_definition orelse
        return error.CharacterHasNoAnatomy;
    const anatomy_runtime = instance.character.anatomy_runtime orelse
        return error.CharacterHasNoAnatomy;
    const graph_definition = instance.definition.component_graph_definition orelse
        return error.CharacterHasNoComponentGraph;
    const graph = try graph_definition.view(
        instance.definition.visual_definition,
        anatomy_definition,
    );
    var result = OptionalArmSubmissionCounts{
        .actual_submissions = @intCast(submissions.len),
    };
    for ([_][]const u8{ "extra_arm", "extra_arm_second" }) |component_name| {
        const component_id = try anatomy_definition.partInstanceId(component_name);
        const component = try graph.component(component_id);
        const active = try anatomy_runtime.isPartActive(
            anatomy_definition,
            component_id,
        );
        const required_view = switch (view) {
            .front => anatomy.ViewSupport{ .front = true, .side_left = false, .side_right = false },
            .side => if (instance.facing == .left)
                anatomy.ViewSupport{ .front = false, .side_left = true, .side_right = false }
            else
                anatomy.ViewSupport{ .front = false, .side_left = false, .side_right = true },
        };
        if (active and !component.definition.projected_views.contains(required_view)) {
            return error.UnsupportedOptionalArmRequiredView;
        }
        const declared = try graph.boundVisuals(
            component_id,
            anatomy_runtime.selected_presentation_profile,
        );
        if (declared.len != 3) return error.OptionalArmDeclaredVisualCountMismatch;
        if (active) {
            result.active_modules += 1;
            result.expected_submissions += @intCast(declared.len);
        }
        var component_actual: usize = 0;
        for (submissions) |submission| {
            if (submission.component_id != component_id) continue;
            component_actual += 1;
            if (!active) return error.InactiveOptionalArmProducedSubmission;
            if (submission.view != view) return error.OptionalArmSubmissionViewMismatch;
            const module_id = component.instance.articulation_module orelse
                return error.RequiredRigModuleMissing;
            if (submission.module_id != module_id) {
                return error.OptionalArmModuleOwnershipMismatch;
            }
            var declared_match_count: usize = 0;
            for (declared) |visual_id| {
                declared_match_count += @intFromBool(visual_id == submission.visual_id);
            }
            if (declared_match_count != 1) {
                return error.OptionalArmVisualNotDeclaredByGraph;
            }
            const visual = instance.definition.visual_definition.visuals[
                submission.visual_id.index()
            ];
            const slot = optionalSlotForName(visual.debug_name.slice()) orelse
                return error.MissingOptionalArmVisualIdentity;
            const contract = optionalArmContract(slot).?;
            if (!std.mem.eql(u8, contract.component_name, component_name)) {
                return error.OptionalArmComponentOwnershipMismatch;
            }
            const module = instance.definition.visual_definition.rig_modules[
                module_id.index()
            ];
            const expected_start = try moduleEndpointIndex(
                instance.definition.visual_definition,
                module,
                contract.start_kind,
                contract.start_name,
            );
            const expected_end = try moduleEndpointIndex(
                instance.definition.visual_definition,
                module,
                contract.end_kind,
                contract.end_name,
            );
            if (submission.start_kind != expected_start.kind or
                submission.start_global_index != expected_start.global_index or
                submission.end_kind != expected_end.kind or
                submission.end_global_index != expected_end.global_index)
            {
                return error.OptionalArmJointBindingMismatch;
            }
            if (submission.submission_index == std.math.maxInt(u32)) {
                return error.OptionalArmFinalSubmissionMissing;
            }
        }
        for (declared) |visual_id| {
            var matches: usize = 0;
            for (submissions) |submission| {
                if (submission.component_id == component_id and
                    submission.visual_id == visual_id)
                {
                    matches += 1;
                }
            }
            if (active and matches == 0) {
                return error.OptionalArmFinalSubmissionMissing;
            }
            if (matches > 1) return error.DuplicateOptionalArmVisualSubmission;
        }
        if (active and component_actual != declared.len) {
            return error.OptionalArmFinalSubmissionMissing;
        }
        if (!active and component_actual != 0) {
            return error.InactiveOptionalArmProducedSubmission;
        }
    }
    for (submissions) |submission| {
        const component_name = anatomy_definition.part_instances[
            submission.component_id.index()
        ].stable_id.slice();
        if (!std.mem.eql(u8, component_name, "extra_arm") and
            !std.mem.eql(u8, component_name, "extra_arm_second"))
        {
            return error.OrphanOptionalArmSubmission;
        }
    }
    return result;
}

const ModuleEndpointIndex = struct {
    kind: visual_geometry.GraphEndpointKind,
    global_index: u16,
};

fn moduleEndpointIndex(
    definition: appearance.DefinitionView,
    module: appearance.RigModule,
    kind: ModuleEndpointKind,
    name: []const u8,
) !ModuleEndpointIndex {
    return switch (kind) {
        .joint => {
            for (definition.module_joints[module.joint_start .. module.joint_start + module.joint_count], 0..) |joint, local_index| {
                if (std.mem.eql(u8, joint.debug_name.slice(), name)) {
                    return .{
                        .kind = .module_joint,
                        .global_index = @intCast(module.joint_start + local_index),
                    };
                }
            }
            return error.RigModuleJointMissing;
        },
        .socket => {
            for (definition.module_sockets[module.socket_start .. module.socket_start + module.socket_count], 0..) |socket_value, local_index| {
                if (std.mem.eql(u8, socket_value.debug_name.slice(), name)) {
                    return .{
                        .kind = .module_socket,
                        .global_index = @intCast(module.socket_start + local_index),
                    };
                }
            }
            return error.RigModuleEndSocketMissing;
        },
    };
}

fn optionalSlotForName(name: []const u8) ?Slot {
    inline for ([_]Slot{
        .extra_upper_arm,
        .extra_forearm,
        .extra_hand,
        .extra_second_upper_arm,
        .extra_second_forearm,
        .extra_second_hand,
    }) |slot| {
        if (std.mem.eql(u8, name, @tagName(slot))) return slot;
    }
    return null;
}

const SegmentContract = struct {
    proximal_landmark: visual_geometry.LandmarkKind,
    distal_landmark: visual_geometry.LandmarkKind,
    proximal_bone: skeleton.BoneSemantic,
    distal_bone: skeleton.BoneSemantic,
};

fn segmentContract(slot: Slot) ?SegmentContract {
    return switch (slot) {
        .left_upper_arm => .{
            .proximal_landmark = .shoulder,
            .distal_landmark = .elbow,
            .proximal_bone = .left_upper_arm,
            .distal_bone = .left_forearm,
        },
        .right_upper_arm => .{
            .proximal_landmark = .shoulder,
            .distal_landmark = .elbow,
            .proximal_bone = .right_upper_arm,
            .distal_bone = .right_forearm,
        },
        .left_forearm => .{
            .proximal_landmark = .elbow,
            .distal_landmark = .wrist,
            .proximal_bone = .left_forearm,
            .distal_bone = .left_hand,
        },
        .right_forearm => .{
            .proximal_landmark = .elbow,
            .distal_landmark = .wrist,
            .proximal_bone = .right_forearm,
            .distal_bone = .right_hand,
        },
        .left_thigh => .{
            .proximal_landmark = .hip,
            .distal_landmark = .knee,
            .proximal_bone = .left_thigh,
            .distal_bone = .left_shin,
        },
        .right_thigh => .{
            .proximal_landmark = .hip,
            .distal_landmark = .knee,
            .proximal_bone = .right_thigh,
            .distal_bone = .right_shin,
        },
        .left_shin => .{
            .proximal_landmark = .knee,
            .distal_landmark = .ankle,
            .proximal_bone = .left_shin,
            .distal_bone = .left_foot,
        },
        .right_shin => .{
            .proximal_landmark = .knee,
            .distal_landmark = .ankle,
            .proximal_bone = .right_shin,
            .distal_bone = .right_foot,
        },
        else => null,
    };
}

fn segmentRegistration(
    instance: *const character.CharacterInstance,
    slot: Slot,
    style: Style,
    view: presentation_view.View,
    projection: presentation_pose.FrontProjection,
    selected: ViewBinding,
    geometry: visual_geometry.Geometry,
    legacy_request: sprite.SpriteRequest,
) !visual_registration.Placement {
    const contract = segmentContract(slot) orelse
        return error.MissingSegmentRegistrationContract;
    const source_proximal = try visual_registration.sourcePoint(
        selected.alpha,
        geometry,
        contract.proximal_landmark,
        .proximal,
    );
    const source_distal = try visual_registration.sourcePoint(
        selected.alpha,
        geometry,
        contract.distal_landmark,
        .distal,
    );
    const target_proximal = try projectedBoneTarget(
        instance,
        projection,
        contract.proximal_bone,
        .proximal,
    );
    const target_distal = try projectedBoneTarget(
        instance,
        projection,
        contract.distal_bone,
        .distal,
    );
    const source_axis = source_distal.local.sub(source_proximal.local);
    const transverse_scale = (if (@abs(source_axis.x) >= @abs(source_axis.y))
        @abs(legacy_request.scale[1])
    else
        @abs(legacy_request.scale[0])) * registrationTransverseMultiplier(
        style,
        slot,
        view,
    );
    const reflect_transverse =
        (view == .front and mirrorsFrontRegion(slot)) or
        (view == .side and instance.facing == .left);
    return visual_registration.solveSegment(
        .{
            .identity = @tagName(slot),
            .binding_mode = .segment,
            .scale_policy = .segment_longitudinal_transverse,
            .mirroring_policy = if (reflect_transverse)
                .transverse_reflection
            else
                .none,
            .allows_reflection = true,
        },
        legacy_request,
        source_proximal,
        source_distal,
        target_proximal,
        target_distal,
        transverse_scale,
        reflect_transverse,
    );
}

fn registrationTransverseMultiplier(
    style: Style,
    slot: Slot,
    view: presentation_view.View,
) f32 {
    return switch (view) {
        .front => switch (style) {
            // The source atlas keeps Prompt 27C's accepted authored dimensions.
            // Registration owns the independent transverse policy and narrows
            // the front male thigh around its exact hip-to-knee axis.
            .male => switch (slot) {
                .left_thigh, .right_thigh => 0.724,
                else => 1,
            },
            .female => 1,
        },
        .side => 1,
    };
}

fn footRegistration(
    instance: *const character.CharacterInstance,
    slot: Slot,
    style: Style,
    view: presentation_view.View,
    projection: presentation_pose.FrontProjection,
    selected: ViewBinding,
    geometry: visual_geometry.Geometry,
    legacy_request: sprite.SpriteRequest,
) !visual_registration.Placement {
    const semantic: skeleton.BoneSemantic = switch (slot) {
        .left_foot => .left_foot,
        .right_foot => .right_foot,
        else => return error.MissingFootRegistrationContract,
    };
    const source = try visual_registration.sourcePoint(
        selected.alpha,
        geometry,
        .ankle,
        .point,
    );
    const target = try projectedBoneTarget(instance, projection, semantic, .point);
    const bone_index = try instance.definition.skeleton_definition.boneIndex(semantic);
    const target_transform = try humanoid.spriteTransform(
        projection.bone_world[bone_index],
    );
    var scale = math.Vec2{
        .x = @abs(legacy_request.scale[0]),
        .y = @abs(legacy_request.scale[1]),
    };
    if ((view == .front and mirrorsFrontRegion(slot)) or
        (view == .side and instance.facing == .left))
    {
        scale.x = -scale.x;
    }
    if (view == .front) {
        const sole_back = try visual_registration.sourcePoint(
            selected.alpha,
            geometry,
            .sole_back,
            .axis_start,
        );
        const sole_front = try visual_registration.sourcePoint(
            selected.alpha,
            geometry,
            .sole_front,
            .axis_end,
        );
        const policy = try frontFootGroundPolicy(style, geometrySide(slot));
        return visual_registration.solvePointAxis(
            .{
                .identity = @tagName(slot),
                .binding_mode = .point_axis,
                .scale_policy = .point_axis_authored,
                .mirroring_policy = if (scale.x < 0)
                    .view_reflection
                else
                    .none,
                .allows_reflection = true,
            },
            legacy_request,
            source,
            sole_back,
            sole_front,
            .{
                .anchor = target,
                .axis_identity = switch (slot) {
                    .left_foot => "left_foot.support_tangent",
                    .right_foot => "right_foot.support_tangent",
                    else => return error.MissingFootRegistrationContract,
                },
                .direction_world = policy.projected_support_tangent,
            },
            scale,
        );
    }
    return visual_registration.solvePoint(
        .{
            .identity = @tagName(slot),
            .binding_mode = .point,
            .scale_policy = .point_authored,
            .mirroring_policy = if (scale.x < 0)
                .view_reflection
            else
                .none,
            .allows_reflection = true,
        },
        legacy_request,
        source,
        target,
        target_transform.rotation_radians,
        scale,
    );
}

pub fn frontFootToeOutDegrees(style: Style) f32 {
    return switch (style) {
        .male => 16.0,
        .female => 13.0,
    };
}

pub fn frontFootGroundPolicy(
    style: Style,
    side: visual_geometry.Side,
) !FrontFootGroundPolicy {
    const toe_out_degrees = frontFootToeOutDegrees(style);
    const toe_out_radians = std.math.degreesToRadians(toe_out_degrees);
    const outward_sign: f32 = switch (side) {
        .left => -1,
        .right => 1,
        else => return error.MissingFootRegistrationContract,
    };
    const lateral = outward_sign * @sin(toe_out_radians);
    const depth = @cos(toe_out_radians);
    return .{
        .toe_out_degrees = toe_out_degrees,
        .lateral = lateral,
        .depth = depth,
        // Front projection maps ground-plane lateral to world X and discards
        // depth. World Y remains the support-normal axis and is exactly zero.
        .projected_support_tangent = .{ .x = lateral, .y = 0 },
    };
}

fn componentPointRegistration(
    instance: *const character.CharacterInstance,
    attachment: appearance.VisualAttachment,
    slot: Slot,
    view: presentation_view.View,
    projection: presentation_pose.FrontProjection,
    selected: ViewBinding,
    geometry: visual_geometry.Geometry,
    legacy_request: sprite.SpriteRequest,
    source_landmark: visual_geometry.LandmarkKind,
) !visual_registration.Placement {
    const anatomy_definition = instance.definition.anatomy_definition orelse
        return error.CharacterHasNoAnatomy;
    const anatomy_runtime = instance.character.anatomy_runtime orelse
        return error.CharacterHasNoAnatomy;
    const part_id = try anatomy_definition.partInstanceId(
        attachment.debug_name.slice(),
    );
    if (!try anatomy_runtime.isPartActive(anatomy_definition, part_id)) {
        return error.InactiveRegistrationTarget;
    }
    const anatomy_projection = try presentation_pose.FrontAnatomyProjection.init(
        projection,
        anatomy_definition,
        anatomy_runtime,
    );
    const target_world = anatomy_projection.part_world[part_id.index()];
    const target_transform = try humanoid.spriteTransform(target_world);
    const source = try visual_registration.sourcePoint(
        selected.alpha,
        geometry,
        source_landmark,
        .point,
    );
    const target = try visual_registration.targetPoint(
        anatomy_definition.part_instances[part_id.index()].stable_id.slice(),
        target_transform.world_position,
        .point,
    );
    var scale = target_transform.signed_scale.componentMul(.{
        .x = selected.visual.authored_size[0],
        .y = selected.visual.authored_size[1],
    });
    if (view == .side and instance.facing == .left and scale.x > 0) {
        scale.x = -scale.x;
    }
    return visual_registration.solvePoint(
        .{
            .identity = @tagName(slot),
            .binding_mode = .point,
            .scale_policy = .point_authored,
            .mirroring_policy = if (scale.x < 0) .view_reflection else .none,
            .allows_reflection = true,
        },
        legacy_request,
        source,
        target,
        target_transform.rotation_radians,
        scale,
    );
}

fn frameRegistration(
    instance: *const character.CharacterInstance,
    slot: Slot,
    view: presentation_view.View,
    projection: presentation_pose.FrontProjection,
    selected: ViewBinding,
    geometry: visual_geometry.Geometry,
    legacy_request: sprite.SpriteRequest,
) !visual_registration.Placement {
    const source_frame = try sourceFrame(selected.alpha, geometry, slot, view);
    const target_frame = try targetFrame(
        instance,
        projection,
        slot,
        view,
        legacy_request,
        source_frame,
    );
    return visual_registration.solveFrame(
        .{
            .identity = @tagName(slot),
            .binding_mode = .frame,
            .scale_policy = .frame_axes,
            .mirroring_policy = if (view == .side and instance.facing == .left)
                .view_reflection
            else
                .transverse_reflection,
            .allows_reflection = true,
        },
        legacy_request,
        source_frame.origin,
        source_frame.axis_x,
        source_frame.axis_y,
        target_frame.origin,
        target_frame.axis_x,
        target_frame.axis_y,
    );
}

const RegistrationFrame = struct {
    origin: visual_registration.SourcePoint,
    axis_x: visual_registration.SourcePoint,
    axis_y: visual_registration.SourcePoint,
};

fn sourceFrame(
    alpha: visual_geometry.AlphaGeometry,
    geometry: visual_geometry.Geometry,
    slot: Slot,
    view: presentation_view.View,
) !RegistrationFrame {
    const lateral_left_kind: visual_geometry.LandmarkKind = switch (slot) {
        .torso => .shoulder_left,
        .pelvis => .hip_left,
        else => return error.MissingFrameRegistrationContract,
    };
    const lateral_right_kind: visual_geometry.LandmarkKind = switch (slot) {
        .torso => .shoulder_right,
        .pelvis => .hip_right,
        else => return error.MissingFrameRegistrationContract,
    };
    const depth_kind: visual_geometry.LandmarkKind = switch (slot) {
        .torso => .waist_left,
        .pelvis => .waist_left,
        else => return error.MissingFrameRegistrationContract,
    };
    const left = try visual_registration.sourcePoint(
        alpha,
        geometry,
        lateral_left_kind,
        .origin,
    );
    const right = try visual_registration.sourcePoint(
        alpha,
        geometry,
        if (view == .front) lateral_right_kind else switch (slot) {
            .torso => .proximal,
            .pelvis => .proximal,
            else => return error.MissingFrameRegistrationContract,
        },
        .axis_x,
    );
    const origin_local = if (view == .front)
        midpoint(left.local, (try visual_registration.sourcePoint(
            alpha,
            geometry,
            lateral_right_kind,
            .axis_x,
        )).local)
    else
        left.local;
    const depth_local = if (view == .front) d: {
        const depth_left = try visual_registration.sourcePoint(
            alpha,
            geometry,
            .waist_left,
            .axis_y,
        );
        const depth_right = try visual_registration.sourcePoint(
            alpha,
            geometry,
            .waist_right,
            .axis_y,
        );
        break :d midpoint(depth_left.local, depth_right.local);
    } else (try visual_registration.sourcePoint(
        alpha,
        geometry,
        depth_kind,
        .axis_y,
    )).local;
    return .{
        .origin = .{
            .role = .origin,
            .landmark = lateral_left_kind,
            .local = origin_local,
        },
        .axis_x = .{
            .role = .axis_x,
            .landmark = right.landmark,
            .local = .{ .x = right.local.x, .y = origin_local.y },
        },
        .axis_y = .{
            .role = .axis_y,
            .landmark = depth_kind,
            .local = .{ .x = origin_local.x, .y = depth_local.y },
        },
    };
}

const TargetFrame = struct {
    origin: visual_registration.TargetPoint,
    axis_x: visual_registration.TargetPoint,
    axis_y: visual_registration.TargetPoint,
};

fn targetFrame(
    instance: *const character.CharacterInstance,
    projection: presentation_pose.FrontProjection,
    slot: Slot,
    view: presentation_view.View,
    legacy_request: sprite.SpriteRequest,
    source: RegistrationFrame,
) !TargetFrame {
    const definition = &instance.definition.skeleton_definition;
    const left_semantic: skeleton.BoneSemantic = switch (slot) {
        .torso => .left_upper_arm,
        .pelvis => .left_thigh,
        else => return error.MissingFrameRegistrationContract,
    };
    const right_semantic: skeleton.BoneSemantic = switch (slot) {
        .torso => .right_upper_arm,
        .pelvis => .right_thigh,
        else => return error.MissingFrameRegistrationContract,
    };
    const depth_semantic: skeleton.BoneSemantic = switch (slot) {
        .torso => .torso,
        .pelvis => .pelvis,
        else => return error.MissingFrameRegistrationContract,
    };
    const origin_identity: []const u8 = switch (slot) {
        .torso => "projected_torso_frame.shoulder_origin",
        .pelvis => "projected_pelvis_frame.hip_origin",
        else => return error.MissingFrameRegistrationContract,
    };
    const axis_x_identity: []const u8 = switch (slot) {
        .torso => "projected_torso_frame.shoulder_axis",
        .pelvis => "projected_pelvis_frame.hip_axis",
        else => return error.MissingFrameRegistrationContract,
    };
    const axis_y_identity: []const u8 = switch (slot) {
        .torso => "projected_torso_frame.waist_axis",
        .pelvis => "projected_pelvis_frame.waist_axis",
        else => return error.MissingFrameRegistrationContract,
    };
    const left_world =
        projection.bone_world[try definition.boneIndex(left_semantic)].translationPart();
    const right_world =
        projection.bone_world[try definition.boneIndex(right_semantic)].translationPart();
    const origin_world = if (view == .front)
        midpoint(left_world, right_world)
    else
        right_world;
    const axis_x_world = if (view == .front)
        math.Vec2{ .x = right_world.x, .y = origin_world.y }
    else a: {
        const source_delta = source.axis_x.local.sub(source.origin.local);
        var signed_span = source_delta.x * legacy_request.scale[0];
        if (@abs(signed_span) <= visual_registration.axis_epsilon) {
            signed_span = if (instance.facing == .left) -0.01 else 0.01;
        }
        break :a math.Vec2{
            .x = origin_world.x + signed_span,
            .y = origin_world.y,
        };
    };
    const depth_world =
        projection.bone_world[try definition.boneIndex(depth_semantic)].translationPart();
    const axis_y_world = math.Vec2{
        .x = origin_world.x,
        .y = depth_world.y,
    };
    return .{
        .origin = try visual_registration.targetPoint(
            origin_identity,
            origin_world,
            .origin,
        ),
        .axis_x = try visual_registration.targetPoint(
            axis_x_identity,
            axis_x_world,
            .axis_x,
        ),
        .axis_y = try visual_registration.targetPoint(
            axis_y_identity,
            axis_y_world,
            .axis_y,
        ),
    };
}

fn projectedBoneTarget(
    instance: *const character.CharacterInstance,
    projection: presentation_pose.FrontProjection,
    semantic: skeleton.BoneSemantic,
    role: visual_registration.EndpointRole,
) !visual_registration.TargetPoint {
    const index = try instance.definition.skeleton_definition.boneIndex(semantic);
    return visual_registration.targetPoint(
        @tagName(semantic),
        projection.bone_world[index].translationPart(),
        role,
    );
}

fn midpoint(a: math.Vec2, b: math.Vec2) math.Vec2 {
    return a.add(b).scale(0.5);
}

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
        .left_eyebrow,
        .left_ear,
        .extra_second_upper_arm,
        .extra_second_forearm,
        .extra_second_hand,
        => .left,
        .right_upper_arm,
        .right_forearm,
        .right_hand,
        .right_thigh,
        .right_shin,
        .right_foot,
        .right_eye,
        .right_eyebrow,
        .right_ear,
        .extra_upper_arm,
        .extra_forearm,
        .extra_hand,
        => .right,
        else => .none,
    };
}

fn geometryRole(slot: Slot) visual_geometry.Role {
    return switch (slot) {
        .head => .head,
        .torso => .torso,
        .pelvis => .pelvis,
        .left_upper_arm,
        .right_upper_arm,
        .extra_upper_arm,
        .extra_second_upper_arm,
        => .upper_arm,
        .left_forearm,
        .right_forearm,
        .extra_forearm,
        .extra_second_forearm,
        => .forearm,
        .left_hand,
        .right_hand,
        .extra_hand,
        .extra_second_hand,
        => .hand,
        .left_thigh, .right_thigh => .thigh,
        .left_shin, .right_shin => .shin,
        .left_foot, .right_foot => .foot,
        .hair => .hair,
        else => .face_feature,
    };
}

fn ownerForSlot(slot: Slot) visual_geometry.Owner {
    return switch (slot) {
        .pelvis,
        .hair,
        .left_eye,
        .right_eye,
        .left_eyebrow,
        .right_eyebrow,
        .eyebrows,
        .nose,
        .mouth,
        .left_ear,
        .right_ear,
        => .base_presentation,
        else => .anatomy,
    };
}

fn boundIdentityForSlot(
    instance: *const character.CharacterInstance,
    slot: Slot,
    attachment: appearance.VisualAttachment,
) u32 {
    if (instance.definition.anatomy_definition) |definition| {
        if (optionalArmContract(slot)) |contract| {
            const part_id = definition.partInstanceId(contract.component_name) catch
                return @intCast(attachment.id.index());
            return @intCast(part_id.index());
        }
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
    anatomy_projection: ?*const presentation_pose.FrontAnatomyProjection,
) !math.Mat3 {
    if (attachment.canonical_semantic != null) {
        return projection.visualWorld(
            instance.character.appearance_runtime,
            attachment,
        );
    }
    if (optionalArmContract(slot) != null) {
        return projection.visualWorld(
            instance.character.appearance_runtime,
            attachment,
        );
    }

    if (anatomy_projection) |projected| {
        if (try directPointComponentIndexForVisual(instance, attachment.id)) |part_index| {
            if (attachment.id.index() >= instance.character.appearance_runtime.visual_states.len) {
                return error.InvalidVisualAttachmentId;
            }
            const state = instance.character.appearance_runtime.visual_states[attachment.id.index()];
            var world = projected.part_world[part_index]
                .mul(try state.local_deformation.localToParent());
            if (attachment.secondary_motion) |motion_definition| {
                world = world.mul(
                    try (try state.secondary.resolvedTransform(motion_definition)).localToParent(),
                );
            }
            return world;
        }
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

fn directPointComponentIndexForVisual(
    instance: *const character.CharacterInstance,
    visual_id: appearance.VisualAttachmentId,
) !?usize {
    const appearance_definition = instance.definition.visual_definition;
    const anatomy_definition = instance.definition.anatomy_definition orelse return null;
    const graph_definition = instance.definition.component_graph_definition orelse return null;
    const anatomy_runtime = instance.character.anatomy_runtime orelse return null;
    const graph = try graph_definition.view(appearance_definition, anatomy_definition);
    for (anatomy_definition.part_instances) |part| {
        const component = try graph.component(part.id);
        if (component.definition.binding_mode != .point or
            part.topology_status != .direct or
            !try anatomy_runtime.isPartActive(anatomy_definition, part.id))
        {
            continue;
        }
        const visuals = try graph.boundVisuals(
            part.id,
            anatomy_runtime.selected_presentation_profile,
        );
        for (visuals) |candidate| {
            if (candidate == visual_id) return part.id.index();
        }
    }
    return null;
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
    return slot != .left_eye and slot != .left_eyebrow and slot != .left_ear;
}

fn mirrorsFrontRegion(slot: Slot) bool {
    return switch (slot) {
        .left_upper_arm,
        .left_forearm,
        .left_hand,
        .left_thigh,
        .left_shin,
        .left_foot,
        .extra_second_upper_arm,
        .extra_second_forearm,
        .extra_second_hand,
        => true,
        else => false,
    };
}

fn slotForAttachment(style: Style, attachment: appearance.VisualAttachment) ?Slot {
    if (attachment.canonical_semantic) |raw_semantic| return @enumFromInt(raw_semantic);
    const name = attachment.debug_name.slice();
    if (optionalSlotForName(name)) |slot| return slot;
    return switch (style) {
        .male => if (std.mem.eql(u8, name, "left_eye"))
            .left_eye
        else if (std.mem.eql(u8, name, "right_eye"))
            .right_eye
        else if (std.mem.eql(u8, name, "left_eyebrow"))
            .left_eyebrow
        else if (std.mem.eql(u8, name, "right_eyebrow"))
            .right_eyebrow
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
        else if (std.mem.eql(u8, name, "angular_left_eyebrow"))
            .left_eyebrow
        else if (std.mem.eql(u8, name, "angular_right_eyebrow"))
            .right_eyebrow
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
            .left_upper_arm,
            .right_upper_arm,
            .extra_upper_arm,
            .extra_second_upper_arm,
            => .side_upper_arm,
            .left_forearm,
            .right_forearm,
            .extra_forearm,
            .extra_second_forearm,
            => .side_forearm,
            .left_hand,
            .right_hand,
            .extra_hand,
            .extra_second_hand,
            => .side_hand,
            .left_thigh, .right_thigh => .side_thigh,
            .left_shin, .right_shin => .side_shin,
            .left_foot, .right_foot => .side_foot,
            .left_eye, .right_eye => .side_eye,
            .eyebrows, .left_eyebrow, .right_eyebrow => .side_brow,
            .nose => .side_nose,
            .mouth => .side_mouth,
            .left_ear, .right_ear => .side_ear,
            .hair => .side_hair,
        },
        .front => switch (slot) {
            .pelvis => .front_pelvis,
            .torso => .front_torso,
            .head => .front_head,
            .left_upper_arm,
            .right_upper_arm,
            .extra_upper_arm,
            .extra_second_upper_arm,
            => .front_upper_arm,
            .left_forearm,
            .right_forearm,
            .extra_forearm,
            .extra_second_forearm,
            => .front_forearm,
            .left_hand,
            .right_hand,
            .extra_hand,
            .extra_second_hand,
            => .front_hand,
            .left_thigh, .right_thigh => .front_thigh,
            .left_shin, .right_shin => .front_shin,
            .left_foot, .right_foot => .front_foot,
            .left_eye => .front_left_eye,
            .right_eye => .front_right_eye,
            .left_eyebrow => .front_left_brow,
            .right_eyebrow => .front_right_brow,
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
        .side_head, .front_head => if (style == .male) .{ 0.68, 0.96 } else .{ 0.68, 0.94 },
        .side_torso => if (style == .male) .{ 0.66, 1.30 } else .{ 0.72, 1.30 },
        .front_torso => if (style == .male) .{ 0.94, 1.30 } else .{ 0.85, 1.30 },
        .side_pelvis => if (style == .male) .{ 0.72, 1.13 } else .{ 0.72, 1.15 },
        .front_pelvis => if (style == .male) .{ 0.96, 0.62 } else .{ 1.08, 0.63 },
        .side_upper_arm => if (style == .male) .{ 0.687, 0.41 } else .{ 0.68, 0.44 },
        .side_forearm => if (style == .male) .{ 0.588, 0.235 } else .{ 0.58, 0.255 },
        .side_hand => if (style == .male) .{ 0.32, 0.153 } else .{ 0.29, 0.18 },
        .side_thigh => if (style == .male) .{ 0.415, 0.93 } else .{ 0.38, 0.919 },
        .side_shin => if (style == .male) .{ 0.28, 0.88 } else .{ 0.28, 0.875 },
        .side_foot => .{ 0.44, 0.167 },
        .front_upper_arm => if (style == .male) .{ 0.320, 0.813 } else .{ 0.330, 0.783 },
        // Both visible forearm spans now resolve to the authoritative
        // elbow-to-wrist distance independently of thickness morphology.
        .front_forearm => if (style == .male) .{ 0.210, 0.577 } else .{ 0.225, 0.568 },
        .front_hand => if (style == .male) .{ 0.135, 0.32 } else .{ 0.15, 0.282 },
        .front_thigh => if (style == .male) .{ 0.380, 0.980 } else .{ 0.46, 1.026 },
        .front_shin => if (style == .male) .{ 0.34, 0.883 } else .{ 0.355, 0.882 },
        .front_foot => if (style == .male) .{ 0.42, 0.172 } else .{ 0.36, 0.190 },
        .side_eye => .{ 0.14, 0.09 },
        .front_left_eye, .front_right_eye => .{ 0.13, 0.085 },
        .side_brow => .{ 0.16, 0.045 },
        .front_brows => .{ 0.35, 0.055 },
        .front_left_brow, .front_right_brow => .{ 0.175, 0.055 },
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
        // Prompt 27C's top/three-quarter alpha envelope begins one source
        // pixel farther inward than its preserved predecessor. Compensate
        // that alpha-derived X shift at the pivot so the semantic ankle stays
        // registered to footwear and the authoritative socket.
        .front_foot => if (style == .male) .{ 0.305500, 0.961000 } else .{ 0.337086, 0.966000 },
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
            .extra_upper_arm,
            .extra_second_upper_arm,
            .left_forearm,
            .right_forearm,
            .extra_forearm,
            .extra_second_forearm,
            .left_hand,
            .right_hand,
            .extra_hand,
            .extra_second_hand,
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
            .front_left_brow => rect(608, 701, 688, 720),
            .front_right_brow => rect(688, 701, 768, 720),
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
            .front_left_brow => rect(578, 697, 672, 724),
            .front_right_brow => rect(672, 697, 766, 724),
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
