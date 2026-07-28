const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const skeleton = @import("skeleton");
const appearance = @import("appearance");
const fault_injection = @import("fault_injection");

pub const maximum_part_definitions: usize = 96;
pub const maximum_part_instances: usize = 128;
pub const maximum_tags: usize = 512;
pub const maximum_part_sockets: usize = 256;
pub const maximum_morphology_channels: usize = 32;
pub const maximum_morphology_presets: usize = 16;
pub const maximum_presentation_profiles: usize = 8;
pub const maximum_visual_variants: usize = maximum_part_instances * maximum_presentation_profiles;
pub const maximum_face_definitions: usize = 16;
pub const maximum_hair_definitions: usize = 16;
pub const maximum_body_presets: usize = 16;
pub const maximum_hierarchy_depth: u8 = 16;
pub const no_index: u16 = std.math.maxInt(u16);

pub const BodyPartDefinitionId = enum(u16) {
    _,

    pub fn index(id: BodyPartDefinitionId) usize {
        return @intFromEnum(id);
    }
};

pub const BodyPartInstanceId = enum(u16) {
    _,

    pub fn index(id: BodyPartInstanceId) usize {
        return @intFromEnum(id);
    }
};

pub const PartSocketId = enum(u16) {
    _,

    pub fn index(id: PartSocketId) usize {
        return @intFromEnum(id);
    }
};

pub const MorphologyChannelId = enum(u16) {
    _,

    pub fn index(id: MorphologyChannelId) usize {
        return @intFromEnum(id);
    }
};

pub const MorphologyPresetId = enum(u16) {
    _,

    pub fn index(id: MorphologyPresetId) usize {
        return @intFromEnum(id);
    }
};

pub const PresentationProfileId = enum(u16) {
    _,

    pub fn index(id: PresentationProfileId) usize {
        return @intFromEnum(id);
    }
};

pub const FaceDefinitionId = enum(u16) {
    _,

    pub fn index(id: FaceDefinitionId) usize {
        return @intFromEnum(id);
    }
};

pub const HairDefinitionId = enum(u16) {
    _,

    pub fn index(id: HairDefinitionId) usize {
        return @intFromEnum(id);
    }
};

pub const BodyPresetId = enum(u16) {
    _,

    pub fn index(id: BodyPresetId) usize {
        return @intFromEnum(id);
    }
};

pub const PartSocketReferenceInput = struct {
    part_instance: []const u8,
    socket: []const u8,
};

pub const BodyPartParentInput = union(enum) {
    attachment_point: []const u8,
    body_part_socket: PartSocketReferenceInput,
    module_socket: appearance.ModuleMemberInput,
};

pub const BodyPartParent = union(enum) {
    attachment_point: appearance.AttachmentPointId,
    body_part_socket: PartSocketId,
    module_socket: u16,
};

pub const ValidationMetadataInput = struct {
    maximum_instances: u16 = maximum_part_instances,
    allow_children: bool = true,
};

pub const ChildSocketInput = struct {
    stable_id: []const u8,
    local_to_part: math.Transform2D,
    accepted_child_tag: ?[]const u8 = null,
};

pub const MorphBindingInput = struct {
    channel: []const u8,
    neutral_value: f32 = 1,
    translation_per_unit: math.Vec2 = math.Vec2.zero,
    rotation_per_unit: f32 = 0,
    scale_per_unit: math.Vec2 = math.Vec2.zero,
};

pub const BodyPartDefinitionInput = struct {
    stable_id: []const u8,
    category_tag: []const u8,
    type_tag: []const u8,
    tags: []const []const u8,
    child_sockets: []const ChildSocketInput,
    morphology_bindings: []const MorphBindingInput,
    breathing_binding: deformation.BreathingBinding = .{},
    validation: ValidationMetadataInput = .{},
};

pub const VisualVariantInput = struct {
    presentation_profile: []const u8,
    visuals: []const []const u8,
};

pub const BodyPartInstanceInput = struct {
    stable_id: []const u8,
    definition: []const u8,
    parent: BodyPartParentInput,
    local_to_parent: math.Transform2D,
    pivot_anchor: [2]f32 = .{ 0.5, 0.5 },
    body_region: []const u8,
    visual_group: []const u8,
    base_render_layer: u16,
    articulation_module: ?[]const u8 = null,
    presentation_variants: []const VisualVariantInput,
};

pub const MorphologyChannelInput = struct {
    stable_id: []const u8,
};

pub const MorphologyRangeInput = struct {
    channel: []const u8,
    low: f32,
    high: f32,
};

pub const MorphologyPresetInput = struct {
    stable_id: []const u8,
    ranges: []const MorphologyRangeInput,
};

pub const PresentationProfileInput = struct {
    stable_id: []const u8,
    detail_tag: []const u8,
};

pub const FaceDefinitionInput = struct {
    stable_id: []const u8,
    head_part: []const u8,
    feature_parts: []const []const u8,
};

pub const HairDefinitionInput = struct {
    stable_id: []const u8,
    style_tag: []const u8,
    part_instances: []const []const u8,
};

pub const BodyPresetInput = struct {
    stable_id: []const u8,
    active_parts: []const []const u8,
    faces: []const []const u8,
    hair: ?[]const u8,
    morphology_preset: []const u8,
    global_build: f32,
    presentation_profile: []const u8,
    front_shoulder_half_span_metres: f32 = 0.45,
};

pub const DefinitionInputs = struct {
    morphology_channels: []const MorphologyChannelInput,
    morphology_presets: []const MorphologyPresetInput,
    presentation_profiles: []const PresentationProfileInput,
    part_definitions: []const BodyPartDefinitionInput,
    part_instances: []const BodyPartInstanceInput,
    faces: []const FaceDefinitionInput,
    hair_definitions: []const HairDefinitionInput,
    body_presets: []const BodyPresetInput,
    default_body_preset: []const u8,
};

pub const ValidationMetadata = struct {
    maximum_instances: u16,
    allow_children: bool,
};

pub const DefinitionSocket = struct {
    stable_id: skeleton.DebugName,
    local_to_part: math.Transform2D,
    accepted_child_tag: ?skeleton.DebugName,
};

pub const MorphBinding = struct {
    channel: MorphologyChannelId,
    neutral_value: f32,
    translation_per_unit: math.Vec2,
    rotation_per_unit: f32,
    scale_per_unit: math.Vec2,
};

pub const BodyPartDefinition = struct {
    id: BodyPartDefinitionId,
    stable_id: skeleton.DebugName,
    category_tag: skeleton.DebugName,
    type_tag: skeleton.DebugName,
    tag_start: u16,
    tag_count: u16,
    socket_start: u16,
    socket_count: u16,
    morph_binding_start: u16,
    morph_binding_count: u16,
    breathing_binding: deformation.BreathingBinding,
    validation: ValidationMetadata,
};

pub const InstanceSocket = struct {
    id: PartSocketId,
    stable_id: skeleton.DebugName,
    owner: BodyPartInstanceId,
    local_to_part: math.Transform2D,
    accepted_child_tag: ?skeleton.DebugName,
};

pub const VisualVariant = struct {
    presentation_profile: PresentationProfileId,
    visual_start: u16,
    visual_count: u16,
};

pub const BodyPartInstance = struct {
    id: BodyPartInstanceId,
    stable_id: skeleton.DebugName,
    definition: BodyPartDefinitionId,
    parent: BodyPartParent,
    local_to_parent: math.Transform2D,
    pivot_anchor: [2]f32,
    body_region: appearance.BodyRegionId,
    visual_group: appearance.VisualGroupId,
    base_render_layer: u16,
    articulation_module: ?appearance.RigModuleId,
    instance_socket_start: u16,
    instance_socket_count: u16,
    visual_variant_start: u16,
    visual_variant_count: u16,
    hierarchy_depth: u8,
};

pub const MorphologyChannel = struct {
    id: MorphologyChannelId,
    stable_id: skeleton.DebugName,
};

pub const MorphologyRange = struct {
    low: f32,
    high: f32,
};

pub const MorphologyPreset = struct {
    id: MorphologyPresetId,
    stable_id: skeleton.DebugName,
    range_start: u16,
};

pub const PresentationProfile = struct {
    id: PresentationProfileId,
    stable_id: skeleton.DebugName,
    detail_tag: skeleton.DebugName,
};

pub const FaceDefinition = struct {
    id: FaceDefinitionId,
    stable_id: skeleton.DebugName,
    head_part: BodyPartInstanceId,
    feature_start: u16,
    feature_count: u16,
};

pub const HairDefinition = struct {
    id: HairDefinitionId,
    stable_id: skeleton.DebugName,
    style_tag: skeleton.DebugName,
    part_start: u16,
    part_count: u16,
};

pub const BodyPreset = struct {
    id: BodyPresetId,
    stable_id: skeleton.DebugName,
    active_part_start: u16,
    face_start: u16,
    face_count: u16,
    hair: ?HairDefinitionId,
    morphology_preset: MorphologyPresetId,
    global_build_normalized: f32,
    presentation_profile: PresentationProfileId,
    front_shoulder_half_span_metres: f32,
};

pub const DefinitionView = struct {
    morphology_channels: []const MorphologyChannel,
    morphology_presets: []const MorphologyPreset,
    morphology_ranges: []const MorphologyRange,
    presentation_profiles: []const PresentationProfile,
    part_definitions: []const BodyPartDefinition,
    tags: []const skeleton.DebugName,
    definition_sockets: []const DefinitionSocket,
    morph_bindings: []const MorphBinding,
    part_instances: []const BodyPartInstance,
    instance_sockets: []const InstanceSocket,
    instance_evaluation_order: []const u16,
    visual_variants: []const VisualVariant,
    variant_visuals: []const appearance.VisualAttachmentId,
    managed_visuals: []const appearance.VisualAttachmentId,
    faces: []const FaceDefinition,
    face_features: []const BodyPartInstanceId,
    hair_definitions: []const HairDefinition,
    hair_parts: []const BodyPartInstanceId,
    body_presets: []const BodyPreset,
    body_preset_active_parts: []const bool,
    body_preset_faces: []const FaceDefinitionId,
    default_body_preset: BodyPresetId,
    owner_token: usize,

    pub fn partInstanceId(definition: DefinitionView, name: []const u8) !BodyPartInstanceId {
        return findPartInstance(definition.part_instances, name);
    }

    pub fn morphologyChannelId(definition: DefinitionView, name: []const u8) !MorphologyChannelId {
        return findMorphologyChannel(definition.morphology_channels, name);
    }

    pub fn morphologyPresetId(definition: DefinitionView, name: []const u8) !MorphologyPresetId {
        return findMorphologyPreset(definition.morphology_presets, name);
    }

    pub fn presentationProfileId(definition: DefinitionView, name: []const u8) !PresentationProfileId {
        return findPresentationProfile(definition.presentation_profiles, name);
    }

    pub fn bodyPresetId(definition: DefinitionView, name: []const u8) !BodyPresetId {
        return findBodyPreset(definition.body_presets, name);
    }

    pub fn hairDefinitionId(definition: DefinitionView, name: []const u8) !HairDefinitionId {
        return findHairDefinition(definition.hair_definitions, name);
    }
};

pub const Definition = struct {
    allocator: std.mem.Allocator,
    morphology_channels: []const MorphologyChannel,
    morphology_presets: []const MorphologyPreset,
    morphology_ranges: []const MorphologyRange,
    presentation_profiles: []const PresentationProfile,
    part_definitions: []const BodyPartDefinition,
    tags: []const skeleton.DebugName,
    definition_sockets: []const DefinitionSocket,
    morph_bindings: []const MorphBinding,
    part_instances: []const BodyPartInstance,
    instance_sockets: []const InstanceSocket,
    instance_evaluation_order: []const u16,
    visual_variants: []const VisualVariant,
    variant_visuals: []const appearance.VisualAttachmentId,
    managed_visuals: []const appearance.VisualAttachmentId,
    faces: []const FaceDefinition,
    face_features: []const BodyPartInstanceId,
    hair_definitions: []const HairDefinition,
    hair_parts: []const BodyPartInstanceId,
    body_presets: []const BodyPreset,
    body_preset_active_parts: []const bool,
    body_preset_faces: []const FaceDefinitionId,
    default_body_preset: BodyPresetId,

    pub fn init(
        allocator: std.mem.Allocator,
        appearance_definition: appearance.DefinitionView,
        inputs: DefinitionInputs,
        injector: ?fault_injection.Injector,
    ) !Definition {
        try validateInputCounts(inputs);

        const morphology_channels = allocator.alloc(MorphologyChannel, inputs.morphology_channels.len) catch return error.AllocationFailure;
        errdefer allocator.free(morphology_channels);
        for (inputs.morphology_channels, 0..) |input, index| {
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(MorphologyChannel, morphology_channels[0..index], stable_id, "stable_id");
            morphology_channels[index] = .{ .id = @enumFromInt(index), .stable_id = stable_id };
        }

        const range_count = std.math.mul(usize, inputs.morphology_presets.len, inputs.morphology_channels.len) catch return error.SupportedCountOverflow;
        const morphology_presets = allocator.alloc(MorphologyPreset, inputs.morphology_presets.len) catch return error.AllocationFailure;
        errdefer allocator.free(morphology_presets);
        const morphology_ranges = allocator.alloc(MorphologyRange, range_count) catch return error.AllocationFailure;
        errdefer allocator.free(morphology_ranges);
        for (inputs.morphology_presets, 0..) |input, preset_index| {
            if (input.ranges.len != morphology_channels.len) return error.IncompleteMorphologyPreset;
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(MorphologyPreset, morphology_presets[0..preset_index], stable_id, "stable_id");
            const range_start = preset_index * morphology_channels.len;
            var seen = [_]bool{false} ** maximum_morphology_channels;
            for (input.ranges) |range_input| {
                const channel_id = try findMorphologyChannel(morphology_channels, range_input.channel);
                if (seen[channel_id.index()]) return error.DuplicateMorphologyRange;
                if (!std.math.isFinite(range_input.low) or !std.math.isFinite(range_input.high) or range_input.low > range_input.high) {
                    return error.InvalidMorphologyRange;
                }
                morphology_ranges[range_start + channel_id.index()] = .{ .low = range_input.low, .high = range_input.high };
                seen[channel_id.index()] = true;
            }
            for (seen[0..morphology_channels.len]) |present| {
                if (!present) return error.IncompleteMorphologyPreset;
            }
            morphology_presets[preset_index] = .{
                .id = @enumFromInt(preset_index),
                .stable_id = stable_id,
                .range_start = @intCast(range_start),
            };
        }

        const presentation_profiles = allocator.alloc(PresentationProfile, inputs.presentation_profiles.len) catch return error.AllocationFailure;
        errdefer allocator.free(presentation_profiles);
        for (inputs.presentation_profiles, 0..) |input, index| {
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(PresentationProfile, presentation_profiles[0..index], stable_id, "stable_id");
            presentation_profiles[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .detail_tag = try skeleton.DebugName.init(input.detail_tag),
            };
        }

        var total_tags: usize = 0;
        var total_definition_sockets: usize = 0;
        var total_morph_bindings: usize = 0;
        for (inputs.part_definitions) |input| {
            total_tags = try checkedAdd(total_tags, input.tags.len);
            total_definition_sockets = try checkedAdd(total_definition_sockets, input.child_sockets.len);
            total_morph_bindings = try checkedAdd(total_morph_bindings, input.morphology_bindings.len);
        }
        if (total_tags > maximum_tags or total_definition_sockets > maximum_part_sockets) return error.SupportedCountOverflow;

        const part_definitions = allocator.alloc(BodyPartDefinition, inputs.part_definitions.len) catch return error.AllocationFailure;
        errdefer allocator.free(part_definitions);
        const tags = allocator.alloc(skeleton.DebugName, total_tags) catch return error.AllocationFailure;
        errdefer allocator.free(tags);
        const definition_sockets = allocator.alloc(DefinitionSocket, total_definition_sockets) catch return error.AllocationFailure;
        errdefer allocator.free(definition_sockets);
        const morph_bindings = allocator.alloc(MorphBinding, total_morph_bindings) catch return error.AllocationFailure;
        errdefer allocator.free(morph_bindings);

        var tag_cursor: usize = 0;
        var definition_socket_cursor: usize = 0;
        var morph_binding_cursor: usize = 0;
        for (inputs.part_definitions, 0..) |input, index| {
            if (input.validation.maximum_instances == 0 or input.validation.maximum_instances > maximum_part_instances) {
                return error.InvalidValidationMetadata;
            }
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(BodyPartDefinition, part_definitions[0..index], stable_id, "stable_id");
            const tag_start = tag_cursor;
            for (input.tags) |tag_text| {
                const tag = try skeleton.DebugName.init(tag_text);
                for (tags[tag_start..tag_cursor]) |*existing| {
                    if (tag.eql(existing)) return error.DuplicatePartTag;
                }
                tags[tag_cursor] = tag;
                tag_cursor += 1;
            }

            const socket_start = definition_socket_cursor;
            for (input.child_sockets) |socket_input| {
                if (!socket_input.local_to_part.isFinite()) return error.NonFiniteTransform;
                const socket_id = try skeleton.DebugName.init(socket_input.stable_id);
                for (definition_sockets[socket_start..definition_socket_cursor]) |*existing| {
                    if (socket_id.eql(&existing.stable_id)) return error.DuplicatePartSocketId;
                }
                definition_sockets[definition_socket_cursor] = .{
                    .stable_id = socket_id,
                    .local_to_part = socket_input.local_to_part,
                    .accepted_child_tag = if (socket_input.accepted_child_tag) |value| try skeleton.DebugName.init(value) else null,
                };
                definition_socket_cursor += 1;
            }

            const morph_start = morph_binding_cursor;
            for (input.morphology_bindings) |binding_input| {
                if (!std.math.isFinite(binding_input.neutral_value) or
                    !binding_input.translation_per_unit.isFinite() or
                    !std.math.isFinite(binding_input.rotation_per_unit) or
                    !binding_input.scale_per_unit.isFinite())
                {
                    return error.InvalidMorphBinding;
                }
                const channel_id = try findMorphologyChannel(morphology_channels, binding_input.channel);
                for (morph_bindings[morph_start..morph_binding_cursor]) |existing| {
                    if (existing.channel == channel_id) return error.DuplicateMorphBinding;
                }
                morph_bindings[morph_binding_cursor] = .{
                    .channel = channel_id,
                    .neutral_value = binding_input.neutral_value,
                    .translation_per_unit = binding_input.translation_per_unit,
                    .rotation_per_unit = binding_input.rotation_per_unit,
                    .scale_per_unit = binding_input.scale_per_unit,
                };
                morph_binding_cursor += 1;
            }
            try input.breathing_binding.validate();
            part_definitions[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .category_tag = try skeleton.DebugName.init(input.category_tag),
                .type_tag = try skeleton.DebugName.init(input.type_tag),
                .tag_start = @intCast(tag_start),
                .tag_count = @intCast(input.tags.len),
                .socket_start = @intCast(socket_start),
                .socket_count = @intCast(input.child_sockets.len),
                .morph_binding_start = @intCast(morph_start),
                .morph_binding_count = @intCast(input.morphology_bindings.len),
                .breathing_binding = input.breathing_binding,
                .validation = .{
                    .maximum_instances = input.validation.maximum_instances,
                    .allow_children = input.validation.allow_children,
                },
            };
        }

        var total_instance_sockets: usize = 0;
        var total_variants: usize = 0;
        var total_variant_visuals: usize = 0;
        for (inputs.part_instances) |input| {
            const definition_id = try findPartDefinition(part_definitions, input.definition);
            total_instance_sockets = try checkedAdd(total_instance_sockets, part_definitions[definition_id.index()].socket_count);
            total_variants = try checkedAdd(total_variants, input.presentation_variants.len);
            for (input.presentation_variants) |variant| total_variant_visuals = try checkedAdd(total_variant_visuals, variant.visuals.len);
        }
        if (total_instance_sockets > maximum_part_sockets or total_variants > maximum_visual_variants) return error.SupportedCountOverflow;

        const part_instances = allocator.alloc(BodyPartInstance, inputs.part_instances.len) catch return error.AllocationFailure;
        errdefer allocator.free(part_instances);
        const instance_sockets = allocator.alloc(InstanceSocket, total_instance_sockets) catch return error.AllocationFailure;
        errdefer allocator.free(instance_sockets);
        const instance_evaluation_order = allocator.alloc(u16, inputs.part_instances.len) catch return error.AllocationFailure;
        errdefer allocator.free(instance_evaluation_order);
        const visual_variants = allocator.alloc(VisualVariant, total_variants) catch return error.AllocationFailure;
        errdefer allocator.free(visual_variants);
        const variant_visuals = allocator.alloc(appearance.VisualAttachmentId, total_variant_visuals) catch return error.AllocationFailure;
        errdefer allocator.free(variant_visuals);

        const visual_owner = allocator.alloc(u16, appearance_definition.visuals.len) catch return error.AllocationFailure;
        defer allocator.free(visual_owner);
        @memset(visual_owner, no_index);
        var unique_managed_visual_count: usize = 0;

        var instance_socket_cursor: usize = 0;
        var variant_cursor: usize = 0;
        var variant_visual_cursor: usize = 0;
        for (inputs.part_instances, 0..) |input, index| {
            if (!input.local_to_parent.isFinite() or
                !std.math.isFinite(input.pivot_anchor[0]) or
                !std.math.isFinite(input.pivot_anchor[1]) or
                input.pivot_anchor[0] < 0 or input.pivot_anchor[0] > 1 or
                input.pivot_anchor[1] < 0 or input.pivot_anchor[1] > 1)
            {
                return error.InvalidPartInstanceTransform;
            }
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(BodyPartInstance, part_instances[0..index], stable_id, "stable_id");
            const definition_id = try findPartDefinition(part_definitions, input.definition);
            const definition = part_definitions[definition_id.index()];
            var same_definition_count: usize = 1;
            for (part_instances[0..index]) |existing| {
                if (existing.definition == definition_id) same_definition_count += 1;
            }
            if (same_definition_count > definition.validation.maximum_instances) return error.PartMultiplicityExceeded;

            const socket_start = instance_socket_cursor;
            for (definition_sockets[definition.socket_start .. definition.socket_start + definition.socket_count]) |socket| {
                instance_sockets[instance_socket_cursor] = .{
                    .id = @enumFromInt(instance_socket_cursor),
                    .stable_id = socket.stable_id,
                    .owner = @enumFromInt(index),
                    .local_to_part = socket.local_to_part,
                    .accepted_child_tag = socket.accepted_child_tag,
                };
                instance_socket_cursor += 1;
            }

            if (input.presentation_variants.len != presentation_profiles.len) return error.IncompletePresentationVariants;
            const visual_variant_start = variant_cursor;
            var profile_seen = [_]bool{false} ** maximum_presentation_profiles;
            for (input.presentation_variants) |variant_input| {
                const profile_id = try findPresentationProfile(presentation_profiles, variant_input.presentation_profile);
                if (profile_seen[profile_id.index()]) return error.DuplicatePresentationVariant;
                profile_seen[profile_id.index()] = true;
                const visual_start = variant_visual_cursor;
                for (variant_input.visuals) |visual_name| {
                    const visual_id = try findVisual(appearance_definition.visuals, visual_name);
                    for (variant_visuals[visual_start..variant_visual_cursor]) |existing| {
                        if (existing == visual_id) return error.DuplicateVariantVisual;
                    }
                    const previous_owner = visual_owner[visual_id.index()];
                    if (previous_owner == no_index) {
                        visual_owner[visual_id.index()] = @intCast(index);
                        unique_managed_visual_count += 1;
                    } else if (previous_owner != index) {
                        return error.DuplicateVisualOwnership;
                    }
                    variant_visuals[variant_visual_cursor] = visual_id;
                    variant_visual_cursor += 1;
                }
                visual_variants[variant_cursor] = .{
                    .presentation_profile = profile_id,
                    .visual_start = @intCast(visual_start),
                    .visual_count = @intCast(variant_input.visuals.len),
                };
                variant_cursor += 1;
            }
            for (profile_seen[0..presentation_profiles.len]) |present| {
                if (!present) return error.IncompletePresentationVariants;
            }

            part_instances[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .definition = definition_id,
                .parent = .{ .attachment_point = @enumFromInt(0) },
                .local_to_parent = input.local_to_parent,
                .pivot_anchor = input.pivot_anchor,
                .body_region = try findBodyRegion(appearance_definition.body_regions, input.body_region),
                .visual_group = try findVisualGroup(appearance_definition.visual_groups, input.visual_group),
                .base_render_layer = input.base_render_layer,
                .articulation_module = if (input.articulation_module) |name| try findRigModule(appearance_definition.rig_modules, name) else null,
                .instance_socket_start = @intCast(socket_start),
                .instance_socket_count = definition.socket_count,
                .visual_variant_start = @intCast(visual_variant_start),
                .visual_variant_count = @intCast(input.presentation_variants.len),
                .hierarchy_depth = 0,
            };
        }

        for (inputs.part_instances, 0..) |input, index| {
            part_instances[index].parent = switch (input.parent) {
                .attachment_point => |name| .{ .attachment_point = try findAttachmentPoint(appearance_definition.attachment_points, name) },
                .body_part_socket => |reference| parent: {
                    const parent_instance_id = try findPartInstance(part_instances, reference.part_instance);
                    if (parent_instance_id.index() == index) return error.BodyPartSelfParent;
                    const parent_instance = part_instances[parent_instance_id.index()];
                    if (!part_definitions[parent_instance.definition.index()].validation.allow_children) return error.BodyPartChildrenForbidden;
                    const socket_id = try findInstanceSocket(
                        instance_sockets[parent_instance.instance_socket_start .. parent_instance.instance_socket_start + parent_instance.instance_socket_count],
                        reference.socket,
                    );
                    const global_socket_id: PartSocketId = @enumFromInt(parent_instance.instance_socket_start + socket_id.index());
                    if (instance_sockets[global_socket_id.index()].accepted_child_tag) |accepted| {
                        if (!definitionHasTag(
                            part_definitions[part_instances[index].definition.index()],
                            tags,
                            accepted,
                        )) return error.ChildTagRejected;
                    }
                    break :parent .{ .body_part_socket = global_socket_id };
                },
                .module_socket => |member| .{ .module_socket = try findModuleSocketGlobal(
                    appearance_definition.rig_modules,
                    appearance_definition.module_joints,
                    appearance_definition.module_sockets,
                    member,
                ) },
            };
        }
        try resolvePartHierarchy(part_instances, instance_sockets, instance_evaluation_order);

        const managed_visuals = allocator.alloc(appearance.VisualAttachmentId, unique_managed_visual_count) catch return error.AllocationFailure;
        errdefer allocator.free(managed_visuals);
        var managed_cursor: usize = 0;
        for (visual_owner, 0..) |owner, visual_index| {
            if (owner != no_index) {
                managed_visuals[managed_cursor] = @enumFromInt(visual_index);
                managed_cursor += 1;
            }
        }

        var total_face_features: usize = 0;
        for (inputs.faces) |input| total_face_features = try checkedAdd(total_face_features, input.feature_parts.len);
        const faces = allocator.alloc(FaceDefinition, inputs.faces.len) catch return error.AllocationFailure;
        errdefer allocator.free(faces);
        const face_features = allocator.alloc(BodyPartInstanceId, total_face_features) catch return error.AllocationFailure;
        errdefer allocator.free(face_features);
        var face_feature_cursor: usize = 0;
        for (inputs.faces, 0..) |input, index| {
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(FaceDefinition, faces[0..index], stable_id, "stable_id");
            const feature_start = face_feature_cursor;
            for (input.feature_parts) |feature_name| {
                const feature_id = try findPartInstance(part_instances, feature_name);
                for (face_features[feature_start..face_feature_cursor]) |existing| {
                    if (existing == feature_id) return error.DuplicateFaceFeature;
                }
                face_features[face_feature_cursor] = feature_id;
                face_feature_cursor += 1;
            }
            faces[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .head_part = try findPartInstance(part_instances, input.head_part),
                .feature_start = @intCast(feature_start),
                .feature_count = @intCast(input.feature_parts.len),
            };
        }

        var total_hair_parts: usize = 0;
        for (inputs.hair_definitions) |input| total_hair_parts = try checkedAdd(total_hair_parts, input.part_instances.len);
        const hair_definitions = allocator.alloc(HairDefinition, inputs.hair_definitions.len) catch return error.AllocationFailure;
        errdefer allocator.free(hair_definitions);
        const hair_parts = allocator.alloc(BodyPartInstanceId, total_hair_parts) catch return error.AllocationFailure;
        errdefer allocator.free(hair_parts);
        var hair_part_cursor: usize = 0;
        for (inputs.hair_definitions, 0..) |input, index| {
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(HairDefinition, hair_definitions[0..index], stable_id, "stable_id");
            const part_start = hair_part_cursor;
            for (input.part_instances) |part_name| {
                const part_id = try findPartInstance(part_instances, part_name);
                for (hair_parts[part_start..hair_part_cursor]) |existing| {
                    if (existing == part_id) return error.DuplicateHairPart;
                }
                hair_parts[hair_part_cursor] = part_id;
                hair_part_cursor += 1;
            }
            hair_definitions[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .style_tag = try skeleton.DebugName.init(input.style_tag),
                .part_start = @intCast(part_start),
                .part_count = @intCast(input.part_instances.len),
            };
        }

        var total_body_preset_faces: usize = 0;
        for (inputs.body_presets) |input| total_body_preset_faces = try checkedAdd(total_body_preset_faces, input.faces.len);
        const body_presets = allocator.alloc(BodyPreset, inputs.body_presets.len) catch return error.AllocationFailure;
        errdefer allocator.free(body_presets);
        const active_count = std.math.mul(usize, inputs.body_presets.len, inputs.part_instances.len) catch return error.SupportedCountOverflow;
        const body_preset_active_parts = allocator.alloc(bool, active_count) catch return error.AllocationFailure;
        errdefer allocator.free(body_preset_active_parts);
        @memset(body_preset_active_parts, false);
        const body_preset_faces = allocator.alloc(FaceDefinitionId, total_body_preset_faces) catch return error.AllocationFailure;
        errdefer allocator.free(body_preset_faces);

        var body_preset_face_cursor: usize = 0;
        for (inputs.body_presets, 0..) |input, index| {
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(BodyPreset, body_presets[0..index], stable_id, "stable_id");
            const active_start = index * part_instances.len;
            for (input.active_parts) |part_name| {
                const part_id = try findPartInstance(part_instances, part_name);
                if (body_preset_active_parts[active_start + part_id.index()]) return error.DuplicatePresetPart;
                body_preset_active_parts[active_start + part_id.index()] = true;
            }
            const face_start = body_preset_face_cursor;
            for (input.faces) |face_name| {
                const face_id = try findFaceDefinition(faces, face_name);
                for (body_preset_faces[face_start..body_preset_face_cursor]) |existing| {
                    if (existing == face_id) return error.DuplicatePresetFace;
                }
                body_preset_faces[body_preset_face_cursor] = face_id;
                body_preset_face_cursor += 1;
            }
            const global_build_normalized = try normalizeUserValue(input.global_build);
            if (!std.math.isFinite(input.front_shoulder_half_span_metres) or
                input.front_shoulder_half_span_metres <= 0)
            {
                return error.InvalidFrontShoulderHalfSpan;
            }
            body_presets[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .active_part_start = @intCast(active_start),
                .face_start = @intCast(face_start),
                .face_count = @intCast(input.faces.len),
                .hair = if (input.hair) |name| try findHairDefinition(hair_definitions, name) else null,
                .morphology_preset = try findMorphologyPreset(morphology_presets, input.morphology_preset),
                .global_build_normalized = global_build_normalized,
                .presentation_profile = try findPresentationProfile(presentation_profiles, input.presentation_profile),
                .front_shoulder_half_span_metres = input.front_shoulder_half_span_metres,
            };
            try validatePresetTopology(
                part_instances,
                instance_sockets,
                faces,
                face_features,
                hair_definitions,
                hair_parts,
                body_presets[index],
                body_preset_active_parts,
                body_preset_faces,
            );
        }

        const default_body_preset = try findBodyPreset(body_presets, inputs.default_body_preset);
        try validateMorphScales(part_definitions, morph_bindings, morphology_presets, morphology_ranges, morphology_channels.len);
        try after(injector, .anatomy_definition_allocation);

        return .{
            .allocator = allocator,
            .morphology_channels = morphology_channels,
            .morphology_presets = morphology_presets,
            .morphology_ranges = morphology_ranges,
            .presentation_profiles = presentation_profiles,
            .part_definitions = part_definitions,
            .tags = tags,
            .definition_sockets = definition_sockets,
            .morph_bindings = morph_bindings,
            .part_instances = part_instances,
            .instance_sockets = instance_sockets,
            .instance_evaluation_order = instance_evaluation_order,
            .visual_variants = visual_variants,
            .variant_visuals = variant_visuals,
            .managed_visuals = managed_visuals,
            .faces = faces,
            .face_features = face_features,
            .hair_definitions = hair_definitions,
            .hair_parts = hair_parts,
            .body_presets = body_presets,
            .body_preset_active_parts = body_preset_active_parts,
            .body_preset_faces = body_preset_faces,
            .default_body_preset = default_body_preset,
        };
    }

    pub fn deinit(definition: *Definition) void {
        definition.allocator.free(definition.body_preset_faces);
        definition.allocator.free(definition.body_preset_active_parts);
        definition.allocator.free(definition.body_presets);
        definition.allocator.free(definition.hair_parts);
        definition.allocator.free(definition.hair_definitions);
        definition.allocator.free(definition.face_features);
        definition.allocator.free(definition.faces);
        definition.allocator.free(definition.managed_visuals);
        definition.allocator.free(definition.variant_visuals);
        definition.allocator.free(definition.visual_variants);
        definition.allocator.free(definition.instance_evaluation_order);
        definition.allocator.free(definition.instance_sockets);
        definition.allocator.free(definition.part_instances);
        definition.allocator.free(definition.morph_bindings);
        definition.allocator.free(definition.definition_sockets);
        definition.allocator.free(definition.tags);
        definition.allocator.free(definition.part_definitions);
        definition.allocator.free(definition.presentation_profiles);
        definition.allocator.free(definition.morphology_ranges);
        definition.allocator.free(definition.morphology_presets);
        definition.allocator.free(definition.morphology_channels);
        definition.* = undefined;
    }

    pub fn view(definition: *const Definition) DefinitionView {
        return .{
            .morphology_channels = definition.morphology_channels,
            .morphology_presets = definition.morphology_presets,
            .morphology_ranges = definition.morphology_ranges,
            .presentation_profiles = definition.presentation_profiles,
            .part_definitions = definition.part_definitions,
            .tags = definition.tags,
            .definition_sockets = definition.definition_sockets,
            .morph_bindings = definition.morph_bindings,
            .part_instances = definition.part_instances,
            .instance_sockets = definition.instance_sockets,
            .instance_evaluation_order = definition.instance_evaluation_order,
            .visual_variants = definition.visual_variants,
            .variant_visuals = definition.variant_visuals,
            .managed_visuals = definition.managed_visuals,
            .faces = definition.faces,
            .face_features = definition.face_features,
            .hair_definitions = definition.hair_definitions,
            .hair_parts = definition.hair_parts,
            .body_presets = definition.body_presets,
            .body_preset_active_parts = definition.body_preset_active_parts,
            .body_preset_faces = definition.body_preset_faces,
            .default_body_preset = definition.default_body_preset,
            .owner_token = definition.compatibilityToken(),
        };
    }

    pub fn compatibilityToken(definition: *const Definition) usize {
        return @intFromPtr(definition.part_instances.ptr);
    }

    pub fn partInstanceId(definition: *const Definition, name: []const u8) !BodyPartInstanceId {
        return findPartInstance(definition.part_instances, name);
    }

    pub fn morphologyChannelId(definition: *const Definition, name: []const u8) !MorphologyChannelId {
        return findMorphologyChannel(definition.morphology_channels, name);
    }

    pub fn morphologyPresetId(definition: *const Definition, name: []const u8) !MorphologyPresetId {
        return findMorphologyPreset(definition.morphology_presets, name);
    }

    pub fn presentationProfileId(definition: *const Definition, name: []const u8) !PresentationProfileId {
        return findPresentationProfile(definition.presentation_profiles, name);
    }

    pub fn bodyPresetId(definition: *const Definition, name: []const u8) !BodyPresetId {
        return findBodyPreset(definition.body_presets, name);
    }

    pub fn hairDefinitionId(definition: *const Definition, name: []const u8) !HairDefinitionId {
        return findHairDefinition(definition.hair_definitions, name);
    }
};

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    definition_token: usize,
    selected_body_preset: BodyPresetId,
    selected_morphology_preset: MorphologyPresetId,
    selected_presentation_profile: PresentationProfileId,
    selected_hair: ?HairDefinitionId,
    global_build_normalized: f32,
    active_parts: []bool,
    channel_override_set: []bool,
    channel_override_normalized: []f32,
    instance_override_set: []bool,
    instance_override_normalized: []f32,
    resolved_channels: []f32,
    breathing: deformation.BreathingState = .{},
    part_morph_local: []math.Transform2D,
    part_deformation_local: []math.Transform2D,
    part_binding_world: []math.Mat3,
    part_world: []math.Mat3,
    socket_world: []math.Mat3,

    pub fn init(
        allocator: std.mem.Allocator,
        definition: DefinitionView,
        injector: ?fault_injection.Injector,
    ) !Runtime {
        const active_parts = allocator.alloc(bool, definition.part_instances.len) catch return error.AllocationFailure;
        errdefer allocator.free(active_parts);
        const channel_override_set = allocator.alloc(bool, definition.morphology_channels.len) catch return error.AllocationFailure;
        errdefer allocator.free(channel_override_set);
        const channel_override_normalized = allocator.alloc(f32, definition.morphology_channels.len) catch return error.AllocationFailure;
        errdefer allocator.free(channel_override_normalized);
        const override_count = std.math.mul(usize, definition.part_instances.len, definition.morphology_channels.len) catch return error.SupportedCountOverflow;
        const instance_override_set = allocator.alloc(bool, override_count) catch return error.AllocationFailure;
        errdefer allocator.free(instance_override_set);
        const instance_override_normalized = allocator.alloc(f32, override_count) catch return error.AllocationFailure;
        errdefer allocator.free(instance_override_normalized);
        const resolved_channels = allocator.alloc(f32, definition.morphology_channels.len) catch return error.AllocationFailure;
        errdefer allocator.free(resolved_channels);
        const part_morph_local = allocator.alloc(math.Transform2D, definition.part_instances.len) catch return error.AllocationFailure;
        errdefer allocator.free(part_morph_local);
        const part_deformation_local = allocator.alloc(math.Transform2D, definition.part_instances.len) catch return error.AllocationFailure;
        errdefer allocator.free(part_deformation_local);
        const part_binding_world = allocator.alloc(math.Mat3, definition.part_instances.len) catch return error.AllocationFailure;
        errdefer allocator.free(part_binding_world);
        const part_world = allocator.alloc(math.Mat3, definition.part_instances.len) catch return error.AllocationFailure;
        errdefer allocator.free(part_world);
        const socket_world = allocator.alloc(math.Mat3, definition.instance_sockets.len) catch return error.AllocationFailure;
        errdefer allocator.free(socket_world);
        try after(injector, .anatomy_runtime_allocation);

        var runtime = Runtime{
            .allocator = allocator,
            .definition_token = definition.owner_token,
            .selected_body_preset = definition.default_body_preset,
            .selected_morphology_preset = @enumFromInt(0),
            .selected_presentation_profile = @enumFromInt(0),
            .selected_hair = null,
            .global_build_normalized = 0.5,
            .active_parts = active_parts,
            .channel_override_set = channel_override_set,
            .channel_override_normalized = channel_override_normalized,
            .instance_override_set = instance_override_set,
            .instance_override_normalized = instance_override_normalized,
            .resolved_channels = resolved_channels,
            .part_morph_local = part_morph_local,
            .part_deformation_local = part_deformation_local,
            .part_binding_world = part_binding_world,
            .part_world = part_world,
            .socket_world = socket_world,
        };
        try runtime.reset(definition);
        return runtime;
    }

    pub fn deinit(runtime: *Runtime) void {
        runtime.allocator.free(runtime.socket_world);
        runtime.allocator.free(runtime.part_world);
        runtime.allocator.free(runtime.part_binding_world);
        runtime.allocator.free(runtime.part_deformation_local);
        runtime.allocator.free(runtime.part_morph_local);
        runtime.allocator.free(runtime.resolved_channels);
        runtime.allocator.free(runtime.instance_override_normalized);
        runtime.allocator.free(runtime.instance_override_set);
        runtime.allocator.free(runtime.channel_override_normalized);
        runtime.allocator.free(runtime.channel_override_set);
        runtime.allocator.free(runtime.active_parts);
        runtime.* = undefined;
    }

    pub fn validateCompatibility(runtime: Runtime, definition: DefinitionView) !void {
        const override_count = std.math.mul(usize, definition.part_instances.len, definition.morphology_channels.len) catch return error.AnatomyDefinitionMismatch;
        if (runtime.definition_token != definition.owner_token or
            runtime.active_parts.len != definition.part_instances.len or
            runtime.channel_override_set.len != definition.morphology_channels.len or
            runtime.channel_override_normalized.len != definition.morphology_channels.len or
            runtime.instance_override_set.len != override_count or
            runtime.instance_override_normalized.len != override_count or
            runtime.resolved_channels.len != definition.morphology_channels.len or
            runtime.part_morph_local.len != definition.part_instances.len or
            runtime.part_deformation_local.len != definition.part_instances.len or
            runtime.part_binding_world.len != definition.part_instances.len or
            runtime.part_world.len != definition.part_instances.len or
            runtime.socket_world.len != definition.instance_sockets.len)
        {
            return error.AnatomyDefinitionMismatch;
        }
    }

    pub fn reset(runtime: *Runtime, definition: DefinitionView) !void {
        try runtime.validateCompatibility(definition);
        @memset(runtime.channel_override_set, false);
        @memset(runtime.channel_override_normalized, 0);
        @memset(runtime.instance_override_set, false);
        @memset(runtime.instance_override_normalized, 0);
        runtime.breathing.reset();
        for (runtime.part_morph_local) |*value| value.* = math.Transform2D.identity();
        for (runtime.part_deformation_local) |*value| value.* = math.Transform2D.identity();
        for (runtime.part_binding_world) |*value| value.* = math.Mat3.identity();
        for (runtime.part_world) |*value| value.* = math.Mat3.identity();
        for (runtime.socket_world) |*value| value.* = math.Mat3.identity();
        try runtime.selectBodyPreset(definition, definition.default_body_preset);
    }

    pub fn selectBodyPreset(runtime: *Runtime, definition: DefinitionView, preset_id: BodyPresetId) !void {
        try runtime.validateCompatibility(definition);
        if (preset_id.index() >= definition.body_presets.len) return error.InvalidBodyPresetId;
        const preset = definition.body_presets[preset_id.index()];
        runtime.selected_body_preset = preset_id;
        runtime.selected_morphology_preset = preset.morphology_preset;
        runtime.selected_presentation_profile = preset.presentation_profile;
        runtime.selected_hair = preset.hair;
        runtime.global_build_normalized = preset.global_build_normalized;
        @memset(runtime.channel_override_set, false);
        @memset(runtime.instance_override_set, false);
        try runtime.rebuildActiveParts(definition, runtime.selected_hair);
        try runtime.resolveMorphology(definition);
    }

    pub fn selectMorphologyPreset(runtime: *Runtime, definition: DefinitionView, preset_id: MorphologyPresetId) !void {
        try runtime.validateCompatibility(definition);
        if (preset_id.index() >= definition.morphology_presets.len) return error.InvalidMorphologyPresetId;
        runtime.selected_morphology_preset = preset_id;
        try runtime.resolveMorphology(definition);
    }

    pub fn setGlobalBuild(runtime: *Runtime, definition: DefinitionView, user_value: f32) !void {
        try runtime.validateCompatibility(definition);
        runtime.global_build_normalized = try normalizeUserValue(user_value);
        try runtime.resolveMorphology(definition);
    }

    pub fn setChannelOverride(
        runtime: *Runtime,
        definition: DefinitionView,
        channel_id: MorphologyChannelId,
        user_value: ?f32,
    ) !void {
        try runtime.validateCompatibility(definition);
        if (channel_id.index() >= definition.morphology_channels.len) return error.InvalidMorphologyChannelId;
        if (user_value) |value| {
            runtime.channel_override_normalized[channel_id.index()] = try normalizeUserValue(value);
            runtime.channel_override_set[channel_id.index()] = true;
        } else {
            runtime.channel_override_set[channel_id.index()] = false;
            runtime.channel_override_normalized[channel_id.index()] = 0;
        }
        try runtime.resolveMorphology(definition);
    }

    pub fn setInstanceOverride(
        runtime: *Runtime,
        definition: DefinitionView,
        part_id: BodyPartInstanceId,
        channel_id: MorphologyChannelId,
        user_value: ?f32,
    ) !void {
        try runtime.validateCompatibility(definition);
        if (part_id.index() >= definition.part_instances.len) return error.InvalidBodyPartInstanceId;
        if (channel_id.index() >= definition.morphology_channels.len) return error.InvalidMorphologyChannelId;
        const index = runtime.instanceOverrideIndex(definition, part_id, channel_id);
        if (user_value) |value| {
            runtime.instance_override_normalized[index] = try normalizeUserValue(value);
            runtime.instance_override_set[index] = true;
        } else {
            runtime.instance_override_set[index] = false;
            runtime.instance_override_normalized[index] = 0;
        }
        try runtime.resolveMorphology(definition);
    }

    pub fn selectPresentationProfile(runtime: *Runtime, definition: DefinitionView, profile_id: PresentationProfileId) !void {
        try runtime.validateCompatibility(definition);
        if (profile_id.index() >= definition.presentation_profiles.len) return error.InvalidPresentationProfileId;
        runtime.selected_presentation_profile = profile_id;
    }

    pub fn selectHair(runtime: *Runtime, definition: DefinitionView, hair_id: ?HairDefinitionId) !void {
        try runtime.validateCompatibility(definition);
        if (hair_id) |value| {
            if (value.index() >= definition.hair_definitions.len) return error.InvalidHairDefinitionId;
        }
        try runtime.rebuildActiveParts(definition, hair_id);
        runtime.selected_hair = hair_id;
    }

    pub fn configureBreathing(
        runtime: *Runtime,
        definition: DefinitionView,
        configuration: deformation.BreathingConfiguration,
    ) !void {
        try runtime.validateCompatibility(definition);
        try runtime.breathing.configure(configuration);
        try runtime.refreshResolvedDeformation(definition);
    }

    pub fn setBreathingPhaseTick(runtime: *Runtime, definition: DefinitionView, phase_tick: u32) !void {
        try runtime.validateCompatibility(definition);
        try runtime.breathing.setPhaseTick(phase_tick);
        try runtime.refreshResolvedDeformation(definition);
    }

    pub fn advanceBreathing(runtime: *Runtime, definition: DefinitionView) !void {
        try runtime.validateCompatibility(definition);
        try runtime.breathing.advance();
        try runtime.refreshResolvedDeformation(definition);
    }

    pub fn breathingSample(runtime: Runtime, definition: DefinitionView) !f32 {
        try runtime.validateCompatibility(definition);
        return runtime.breathing.sample();
    }

    pub fn resolvedChannel(runtime: Runtime, definition: DefinitionView, channel_id: MorphologyChannelId) !f32 {
        try runtime.validateCompatibility(definition);
        if (channel_id.index() >= runtime.resolved_channels.len) return error.InvalidMorphologyChannelId;
        return runtime.resolved_channels[channel_id.index()];
    }

    pub fn resolvedChannelForPart(
        runtime: Runtime,
        definition: DefinitionView,
        part_id: BodyPartInstanceId,
        channel_id: MorphologyChannelId,
    ) !f32 {
        try runtime.validateCompatibility(definition);
        if (part_id.index() >= definition.part_instances.len) return error.InvalidBodyPartInstanceId;
        if (channel_id.index() >= definition.morphology_channels.len) return error.InvalidMorphologyChannelId;
        const override_index = runtime.instanceOverrideIndex(definition, part_id, channel_id);
        const amount = if (runtime.instance_override_set[override_index])
            runtime.instance_override_normalized[override_index]
        else if (runtime.channel_override_set[channel_id.index()])
            runtime.channel_override_normalized[channel_id.index()]
        else
            runtime.global_build_normalized;
        return runtime.interpolateChannel(definition, channel_id, amount);
    }

    pub fn isPartActive(runtime: Runtime, definition: DefinitionView, part_id: BodyPartInstanceId) !bool {
        try runtime.validateCompatibility(definition);
        if (part_id.index() >= runtime.active_parts.len) return error.InvalidBodyPartInstanceId;
        return runtime.active_parts[part_id.index()];
    }

    pub fn activePartCount(runtime: Runtime, definition: DefinitionView) !usize {
        try runtime.validateCompatibility(definition);
        var count: usize = 0;
        for (runtime.active_parts) |active| count += @intFromBool(active);
        return count;
    }

    pub fn topologyFingerprint(runtime: Runtime, definition: DefinitionView) !u64 {
        try runtime.validateCompatibility(definition);
        var hash: u64 = 14695981039346656037;
        for (definition.part_instances, runtime.active_parts) |part, active| {
            hash = (hash ^ @as(u64, @intFromEnum(part.id))) *% 1099511628211;
            hash = (hash ^ @as(u64, @intFromBool(active))) *% 1099511628211;
            const parent_value: u64 = switch (part.parent) {
                .attachment_point => |id| @as(u64, @intFromEnum(id)),
                .body_part_socket => |id| 0x10000 + @as(u64, @intFromEnum(id)),
                .module_socket => |id| 0x20000 + @as(u64, id),
            };
            hash = (hash ^ parent_value) *% 1099511628211;
        }
        return hash;
    }

    pub fn applyAppearanceState(
        runtime: *Runtime,
        definition: DefinitionView,
        appearance_definition: appearance.DefinitionView,
        appearance_runtime: *appearance.Runtime,
    ) !void {
        try runtime.validateCompatibility(definition);
        try appearance_runtime.validateCompatibility(appearance_definition);

        for (definition.managed_visuals) |visual_id| {
            try appearance_runtime.setVisible(appearance_definition, visual_id, false);
            try appearance_runtime.setVisualDeformation(appearance_definition, visual_id, math.Transform2D.identity());
        }

        for (definition.part_instances) |part| {
            const full_deformation = if (runtime.active_parts[part.id.index()])
                try runtime.resolvedDeformationForPart(definition, part.id, .{})
            else
                math.Transform2D.identity();
            runtime.part_deformation_local[part.id.index()] = full_deformation;
            const variants = definition.visual_variants[part.visual_variant_start .. part.visual_variant_start + part.visual_variant_count];
            for (variants) |variant| {
                for (definition.variant_visuals[variant.visual_start .. variant.visual_start + variant.visual_count]) |visual_id| {
                    const response = appearance_definition.visuals[visual_id.index()].deformation_response;
                    const resolved = if (runtime.active_parts[part.id.index()])
                        try runtime.resolvedDeformationForPart(definition, part.id, response)
                    else
                        math.Transform2D.identity();
                    try appearance_runtime.setVisualDeformation(appearance_definition, visual_id, resolved);
                }
            }
            if (!runtime.active_parts[part.id.index()]) continue;
            const variant = findVariantForProfile(variants, runtime.selected_presentation_profile) orelse return error.MissingPresentationVariant;
            for (definition.variant_visuals[variant.visual_start .. variant.visual_start + variant.visual_count]) |visual_id| {
                try appearance_runtime.setVisible(appearance_definition, visual_id, true);
            }
        }
    }

    pub fn evaluateHierarchy(
        runtime: *Runtime,
        definition: DefinitionView,
        appearance_definition: appearance.DefinitionView,
        appearance_runtime: *const appearance.Runtime,
    ) !void {
        try runtime.validateCompatibility(definition);
        try appearance_runtime.validateCompatibility(appearance_definition);
        for (definition.instance_evaluation_order) |raw_index| {
            const part = definition.part_instances[raw_index];
            if (!runtime.active_parts[part.id.index()]) {
                runtime.part_binding_world[part.id.index()] = math.Mat3.identity();
                runtime.part_world[part.id.index()] = math.Mat3.identity();
                for (definition.instance_sockets[part.instance_socket_start .. part.instance_socket_start + part.instance_socket_count]) |socket| {
                    runtime.socket_world[socket.id.index()] = math.Mat3.identity();
                }
                continue;
            }
            const parent_world = switch (part.parent) {
                .attachment_point => |id| try appearance_runtime.attachmentPointWorld(appearance_definition, id),
                .body_part_socket => |id| runtime.socket_world[id.index()],
                .module_socket => |global_index| try appearance_runtime.moduleSocketWorldGlobal(appearance_definition, global_index),
            };
            const binding_world = parent_world.mul(try part.local_to_parent.localToParent());
            const world = binding_world.mul(try runtime.part_deformation_local[part.id.index()].localToParent());
            runtime.part_binding_world[part.id.index()] = binding_world;
            runtime.part_world[part.id.index()] = world;
            for (definition.instance_sockets[part.instance_socket_start .. part.instance_socket_start + part.instance_socket_count]) |socket| {
                runtime.socket_world[socket.id.index()] = world.mul(try socket.local_to_part.localToParent());
            }
        }
    }

    pub fn setPartModuleJointLocal(
        runtime: *Runtime,
        definition: DefinitionView,
        appearance_definition: appearance.DefinitionView,
        appearance_runtime: *appearance.Runtime,
        part_id: BodyPartInstanceId,
        joint_id: appearance.ModuleJointId,
        local: math.Transform2D,
    ) !void {
        try runtime.validateCompatibility(definition);
        if (part_id.index() >= definition.part_instances.len) return error.InvalidBodyPartInstanceId;
        const module_id = definition.part_instances[part_id.index()].articulation_module orelse return error.BodyPartIsNotArticulated;
        try appearance_runtime.setModuleJointLocal(appearance_definition, module_id, joint_id, local);
    }

    pub fn partWorld(runtime: Runtime, definition: DefinitionView, part_id: BodyPartInstanceId) !math.Mat3 {
        try runtime.validateCompatibility(definition);
        if (part_id.index() >= runtime.part_world.len) return error.InvalidBodyPartInstanceId;
        return runtime.part_world[part_id.index()];
    }

    pub fn partBindingWorld(runtime: Runtime, definition: DefinitionView, part_id: BodyPartInstanceId) !math.Mat3 {
        try runtime.validateCompatibility(definition);
        if (part_id.index() >= runtime.part_binding_world.len) return error.InvalidBodyPartInstanceId;
        return runtime.part_binding_world[part_id.index()];
    }

    pub fn resolvedDeformationForPart(
        runtime: Runtime,
        definition: DefinitionView,
        part_id: BodyPartInstanceId,
        response: deformation.Response,
    ) !math.Transform2D {
        try runtime.validateCompatibility(definition);
        if (part_id.index() >= definition.part_instances.len) return error.InvalidBodyPartInstanceId;
        const part = definition.part_instances[part_id.index()];
        const part_definition = definition.part_definitions[part.definition.index()];
        return deformation.resolve(.{
            .base_morphology = runtime.part_morph_local[part_id.index()],
            .breathing_binding = part_definition.breathing_binding,
            .breathing_sample = try runtime.breathing.sample(),
            .response = response,
        });
    }

    /// Returns the selected preset's authored-art baseline for one morphology
    /// channel: the midpoint of its declared range.
    pub fn nominalChannel(
        runtime: Runtime,
        definition: DefinitionView,
        channel_id: MorphologyChannelId,
    ) !f32 {
        try runtime.validateCompatibility(definition);
        if (channel_id.index() >= definition.morphology_channels.len) {
            return error.InvalidMorphologyChannelId;
        }
        const preset = definition.morphology_presets[
            runtime.selected_morphology_preset.index()
        ];
        const range = definition.morphology_ranges[
            preset.range_start + channel_id.index()
        ];
        return (range.low + range.high) * 0.5;
    }

    fn resolveMorphology(runtime: *Runtime, definition: DefinitionView) !void {
        for (definition.morphology_channels) |channel| {
            const amount = if (runtime.channel_override_set[channel.id.index()])
                runtime.channel_override_normalized[channel.id.index()]
            else
                runtime.global_build_normalized;
            runtime.resolved_channels[channel.id.index()] = runtime.interpolateChannel(definition, channel.id, amount);
        }
        for (definition.part_instances) |part| {
            runtime.part_morph_local[part.id.index()] = try runtime.morphForPart(definition, part.id);
        }
        try runtime.refreshResolvedDeformation(definition);
    }

    fn refreshResolvedDeformation(runtime: *Runtime, definition: DefinitionView) !void {
        for (definition.part_instances) |part| {
            runtime.part_deformation_local[part.id.index()] = if (runtime.active_parts[part.id.index()])
                try runtime.resolvedDeformationForPart(definition, part.id, .{})
            else
                math.Transform2D.identity();
        }
    }

    fn interpolateChannel(
        runtime: Runtime,
        definition: DefinitionView,
        channel_id: MorphologyChannelId,
        amount: f32,
    ) f32 {
        const preset = definition.morphology_presets[runtime.selected_morphology_preset.index()];
        const range = definition.morphology_ranges[preset.range_start + channel_id.index()];
        return range.low + (range.high - range.low) * amount;
    }

    fn morphForPart(runtime: Runtime, definition: DefinitionView, part_id: BodyPartInstanceId) !math.Transform2D {
        const part = definition.part_instances[part_id.index()];
        const part_definition = definition.part_definitions[part.definition.index()];
        var result = math.Transform2D.identity();
        for (definition.morph_bindings[part_definition.morph_binding_start .. part_definition.morph_binding_start + part_definition.morph_binding_count]) |binding| {
            const value = try runtime.resolvedChannelForPart(definition, part_id, binding.channel);
            const delta = value - binding.neutral_value;
            result.translation = result.translation.add(binding.translation_per_unit.scale(delta));
            result.rotation_radians += binding.rotation_per_unit * delta;
            const factor = math.Vec2{
                .x = 1 + binding.scale_per_unit.x * delta,
                .y = 1 + binding.scale_per_unit.y * delta,
            };
            if (!factor.isFinite() or factor.x <= 0 or factor.y <= 0) return error.InvalidResolvedMorphScale;
            result.scale = result.scale.componentMul(factor);
        }
        if (!result.isFinite()) return error.InvalidResolvedMorphTransform;
        return result;
    }

    fn rebuildActiveParts(runtime: *Runtime, definition: DefinitionView, hair_id: ?HairDefinitionId) !void {
        var scratch = [_]bool{false} ** maximum_part_instances;
        const preset = definition.body_presets[runtime.selected_body_preset.index()];
        const base = definition.body_preset_active_parts[preset.active_part_start .. preset.active_part_start + definition.part_instances.len];
        @memcpy(scratch[0..definition.part_instances.len], base);
        for (definition.body_preset_faces[preset.face_start .. preset.face_start + preset.face_count]) |face_id| {
            activateFace(definition, scratch[0..definition.part_instances.len], face_id);
        }
        if (hair_id) |value| activateHair(definition, scratch[0..definition.part_instances.len], value);
        try validateActiveTopology(definition.part_instances, definition.instance_sockets, scratch[0..definition.part_instances.len]);
        @memcpy(runtime.active_parts, scratch[0..definition.part_instances.len]);
    }

    fn instanceOverrideIndex(
        runtime: Runtime,
        definition: DefinitionView,
        part_id: BodyPartInstanceId,
        channel_id: MorphologyChannelId,
    ) usize {
        _ = runtime;
        return part_id.index() * definition.morphology_channels.len + channel_id.index();
    }
};

fn validateInputCounts(inputs: DefinitionInputs) !void {
    if (inputs.morphology_channels.len == 0 or
        inputs.morphology_channels.len > maximum_morphology_channels or
        inputs.morphology_presets.len == 0 or
        inputs.morphology_presets.len > maximum_morphology_presets or
        inputs.presentation_profiles.len == 0 or
        inputs.presentation_profiles.len > maximum_presentation_profiles or
        inputs.part_definitions.len == 0 or
        inputs.part_definitions.len > maximum_part_definitions or
        inputs.part_instances.len == 0 or
        inputs.part_instances.len > maximum_part_instances or
        inputs.faces.len > maximum_face_definitions or
        inputs.hair_definitions.len > maximum_hair_definitions or
        inputs.body_presets.len == 0 or
        inputs.body_presets.len > maximum_body_presets)
    {
        return error.SupportedCountOverflow;
    }
}

fn checkedAdd(left: usize, right: usize) !usize {
    return std.math.add(usize, left, right) catch error.SupportedCountOverflow;
}

fn ensureUniqueName(
    comptime T: type,
    values: []const T,
    candidate: skeleton.DebugName,
    comptime field_name: []const u8,
) !void {
    for (values) |*value| {
        const existing: *const skeleton.DebugName = &@field(value, field_name);
        if (candidate.eql(existing)) return error.DuplicateStableId;
    }
}

fn nameEquals(name: *const skeleton.DebugName, text: []const u8) bool {
    return std.mem.eql(u8, name.slice(), text);
}

fn findMorphologyChannel(values: []const MorphologyChannel, name: []const u8) !MorphologyChannelId {
    for (values) |*value| if (nameEquals(&value.stable_id, name)) return value.id;
    return error.UnknownMorphologyChannel;
}

fn findMorphologyPreset(values: []const MorphologyPreset, name: []const u8) !MorphologyPresetId {
    for (values) |*value| if (nameEquals(&value.stable_id, name)) return value.id;
    return error.UnknownMorphologyPreset;
}

fn findPresentationProfile(values: []const PresentationProfile, name: []const u8) !PresentationProfileId {
    for (values) |*value| if (nameEquals(&value.stable_id, name)) return value.id;
    return error.UnknownPresentationProfile;
}

fn findPartDefinition(values: []const BodyPartDefinition, name: []const u8) !BodyPartDefinitionId {
    for (values) |*value| if (nameEquals(&value.stable_id, name)) return value.id;
    return error.UnknownBodyPartDefinition;
}

fn findPartInstance(values: []const BodyPartInstance, name: []const u8) !BodyPartInstanceId {
    for (values) |*value| if (nameEquals(&value.stable_id, name)) return value.id;
    return error.UnknownBodyPartInstance;
}

fn findFaceDefinition(values: []const FaceDefinition, name: []const u8) !FaceDefinitionId {
    for (values) |*value| if (nameEquals(&value.stable_id, name)) return value.id;
    return error.UnknownFaceDefinition;
}

fn findHairDefinition(values: []const HairDefinition, name: []const u8) !HairDefinitionId {
    for (values) |*value| if (nameEquals(&value.stable_id, name)) return value.id;
    return error.UnknownHairDefinition;
}

fn findBodyPreset(values: []const BodyPreset, name: []const u8) !BodyPresetId {
    for (values) |*value| if (nameEquals(&value.stable_id, name)) return value.id;
    return error.UnknownBodyPreset;
}

fn findAttachmentPoint(values: []const appearance.AttachmentPoint, name: []const u8) !appearance.AttachmentPointId {
    for (values) |*value| if (nameEquals(&value.debug_name, name)) return value.id;
    return error.UnknownAttachmentPoint;
}

fn findBodyRegion(values: []const appearance.BodyRegion, name: []const u8) !appearance.BodyRegionId {
    for (values) |*value| if (nameEquals(&value.debug_name, name)) return value.id;
    return error.UnknownBodyRegion;
}

fn findVisualGroup(values: []const appearance.VisualGroup, name: []const u8) !appearance.VisualGroupId {
    for (values) |*value| if (nameEquals(&value.debug_name, name)) return value.id;
    return error.UnknownVisualGroup;
}

fn findVisual(values: []const appearance.VisualAttachment, name: []const u8) !appearance.VisualAttachmentId {
    for (values) |*value| if (nameEquals(&value.debug_name, name)) return value.id;
    return error.UnknownVisualAttachment;
}

fn findRigModule(values: []const appearance.RigModule, name: []const u8) !appearance.RigModuleId {
    for (values) |*value| if (nameEquals(&value.debug_name, name)) return value.id;
    return error.UnknownRigModule;
}

fn findInstanceSocket(values: []const InstanceSocket, name: []const u8) !PartSocketId {
    for (values, 0..) |*value, index| if (nameEquals(&value.stable_id, name)) return @enumFromInt(index);
    return error.UnknownPartSocket;
}

fn findModuleJointLocal(values: []const appearance.ModuleJoint, name: []const u8) !appearance.ModuleJointId {
    for (values) |*value| if (nameEquals(&value.debug_name, name)) return value.id;
    return error.UnknownModuleJoint;
}

fn findModuleSocketLocal(values: []const appearance.ModuleSocket, name: []const u8) !appearance.ModuleSocketId {
    for (values) |*value| if (nameEquals(&value.debug_name, name)) return value.id;
    return error.UnknownModuleSocket;
}

fn findModuleSocketGlobal(
    modules: []const appearance.RigModule,
    joints: []const appearance.ModuleJoint,
    sockets: []const appearance.ModuleSocket,
    member: appearance.ModuleMemberInput,
) !u16 {
    _ = joints;
    const module_id = try findRigModule(modules, member.module_name);
    const module = modules[module_id.index()];
    const local_id = try findModuleSocketLocal(sockets[module.socket_start .. module.socket_start + module.socket_count], member.member_name);
    return @intCast(module.socket_start + local_id.index());
}

fn definitionHasTag(
    definition: BodyPartDefinition,
    tags: []const skeleton.DebugName,
    accepted: skeleton.DebugName,
) bool {
    if (accepted.eql(&definition.category_tag) or accepted.eql(&definition.type_tag)) return true;
    for (tags[definition.tag_start .. definition.tag_start + definition.tag_count]) |*tag| {
        if (accepted.eql(tag)) return true;
    }
    return false;
}

fn resolvePartHierarchy(
    parts: []BodyPartInstance,
    instance_sockets: []const InstanceSocket,
    evaluation_order: []u16,
) !void {
    var resolved = [_]bool{false} ** maximum_part_instances;
    var resolved_count: usize = 0;
    while (resolved_count < parts.len) {
        var progress = false;
        for (parts, 0..) |*part, index| {
            if (resolved[index]) continue;
            const parent_index: ?usize = switch (part.parent) {
                .attachment_point, .module_socket => null,
                .body_part_socket => |socket_id| instance_sockets[socket_id.index()].owner.index(),
            };
            if (parent_index) |value| {
                if (!resolved[value]) continue;
                part.hierarchy_depth = parts[value].hierarchy_depth + 1;
            } else {
                part.hierarchy_depth = 1;
            }
            if (part.hierarchy_depth > maximum_hierarchy_depth) return error.BodyPartHierarchyTooDeep;
            resolved[index] = true;
            evaluation_order[resolved_count] = @intCast(index);
            resolved_count += 1;
            progress = true;
        }
        if (!progress) return error.BodyPartHierarchyCycle;
    }
}

fn findVariantForProfile(variants: []const VisualVariant, profile: PresentationProfileId) ?VisualVariant {
    for (variants) |variant| if (variant.presentation_profile == profile) return variant;
    return null;
}

fn normalizeUserValue(value: f32) !f32 {
    if (!std.math.isFinite(value) or value < 0 or value > 100) return error.InvalidUserMorphologyValue;
    return value / 100;
}

fn activateFace(definition: DefinitionView, active: []bool, face_id: FaceDefinitionId) void {
    const face = definition.faces[face_id.index()];
    active[face.head_part.index()] = true;
    for (definition.face_features[face.feature_start .. face.feature_start + face.feature_count]) |part_id| active[part_id.index()] = true;
}

fn activateHair(definition: DefinitionView, active: []bool, hair_id: HairDefinitionId) void {
    const hair = definition.hair_definitions[hair_id.index()];
    for (definition.hair_parts[hair.part_start .. hair.part_start + hair.part_count]) |part_id| active[part_id.index()] = true;
}

fn validatePresetTopology(
    part_instances: []const BodyPartInstance,
    instance_sockets: []const InstanceSocket,
    faces: []const FaceDefinition,
    face_features: []const BodyPartInstanceId,
    hair_definitions: []const HairDefinition,
    hair_parts: []const BodyPartInstanceId,
    preset: BodyPreset,
    preset_active_parts: []const bool,
    preset_faces: []const FaceDefinitionId,
) !void {
    var active = [_]bool{false} ** maximum_part_instances;
    const base = preset_active_parts[preset.active_part_start .. preset.active_part_start + part_instances.len];
    @memcpy(active[0..part_instances.len], base);
    const definition = DefinitionView{
        .morphology_channels = &.{},
        .morphology_presets = &.{},
        .morphology_ranges = &.{},
        .presentation_profiles = &.{},
        .part_definitions = &.{},
        .tags = &.{},
        .definition_sockets = &.{},
        .morph_bindings = &.{},
        .part_instances = part_instances,
        .instance_sockets = instance_sockets,
        .instance_evaluation_order = &.{},
        .visual_variants = &.{},
        .variant_visuals = &.{},
        .managed_visuals = &.{},
        .faces = faces,
        .face_features = face_features,
        .hair_definitions = hair_definitions,
        .hair_parts = hair_parts,
        .body_presets = &.{},
        .body_preset_active_parts = &.{},
        .body_preset_faces = &.{},
        .default_body_preset = @enumFromInt(0),
        .owner_token = 0,
    };
    for (preset_faces[preset.face_start .. preset.face_start + preset.face_count]) |face_id| activateFace(definition, active[0..part_instances.len], face_id);
    if (preset.hair) |hair_id| activateHair(definition, active[0..part_instances.len], hair_id);
    try validateActiveTopology(part_instances, instance_sockets, active[0..part_instances.len]);
}

fn validateActiveTopology(
    part_instances: []const BodyPartInstance,
    instance_sockets: []const InstanceSocket,
    active: []const bool,
) !void {
    for (part_instances, active) |part, is_active| {
        if (!is_active) continue;
        switch (part.parent) {
            .body_part_socket => |socket_id| {
                const parent = instance_sockets[socket_id.index()].owner;
                if (!active[parent.index()]) return error.ActiveBodyPartParentInactive;
            },
            .attachment_point, .module_socket => {},
        }
    }
}

fn validateMorphScales(
    definitions: []const BodyPartDefinition,
    bindings: []const MorphBinding,
    presets: []const MorphologyPreset,
    ranges: []const MorphologyRange,
    channel_count: usize,
) !void {
    for (definitions) |definition| {
        for (bindings[definition.morph_binding_start .. definition.morph_binding_start + definition.morph_binding_count]) |binding| {
            for (presets) |preset| {
                const range = ranges[preset.range_start + binding.channel.index()];
                for ([_]f32{ range.low, range.high }) |value| {
                    const delta = value - binding.neutral_value;
                    const x = 1 + binding.scale_per_unit.x * delta;
                    const y = 1 + binding.scale_per_unit.y * delta;
                    if (!std.math.isFinite(x) or !std.math.isFinite(y) or x <= 0 or y <= 0) {
                        return error.InvalidMorphScaleRange;
                    }
                }
                if (preset.range_start + channel_count > ranges.len) return error.IncompleteMorphologyPreset;
            }
        }
    }
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
