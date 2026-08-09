const std = @import("std");
const canonical = @import("canonical_model");

const diagnostics = canonical.diagnostics;
const human_base = canonical.human_base;
const human_validation = canonical.human_validation;
const identity = canonical.identity;
const normalization = canonical.normalization;
const parsing = canonical.parsing;
const serialization = canonical.serialization;
const validation = canonical.validation;

const m01_canonical_json = @embedFile("fixtures/canonical_model/valid/minimal_valid_canonical.json");
const m01_phase_f_sha256 = "b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d";

test "Prompt 2A human_base is a valid canonical source" {
    var diagnostic_storage: [256]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(&human_base.source, .{}, &diagnostic_storage);
    try std.testing.expect(normalized.isValid());
    try std.testing.expectEqual(@as(usize, 0), normalized.report.error_count);
    try human_validation.validatePrompt2A(&human_base.source);

    const canonical_bytes = try serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(canonical_bytes);
    try std.testing.expect(canonical_bytes.len > 64 * 1024);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "\"asset_id\":\"human_base\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "\"owner_component_id\":\"body\"") != null);
    try std.testing.expect(canonical_bytes[canonical_bytes.len - 1] == '}');
    try std.testing.expect(std.mem.indexOfAny(u8, canonical_bytes, "\t\r\n") == null);

    var parsed = try parsing.parse(std.testing.allocator, canonical_bytes);
    defer parsed.deinit();
    var round_trip_diagnostics: [256]diagnostics.Diagnostic = undefined;
    const round_trip = try normalization.normalize(&parsed.value, .{}, &round_trip_diagnostics);
    try std.testing.expect(round_trip.isValid());
    try human_validation.validatePrompt2A(&parsed.value);
    const round_trip_bytes = try serialization.serializeAlloc(std.testing.allocator, round_trip.normalized.?);
    defer std.testing.allocator.free(round_trip_bytes);
    try std.testing.expectEqualStrings(canonical_bytes, round_trip_bytes);
}

test "Prompt 2A identity and coordinate defaults are locked" {
    const source = human_base.source;
    try std.testing.expectEqualStrings("canonical_creature_schema", source.schema_identity.schema_id.value.bytes);
    try std.testing.expectEqual(@as(u32, 1), source.schema_identity.version.major);
    try std.testing.expectEqual(@as(u32, 1), source.schema_identity.version.minor);
    try std.testing.expectEqual(@as(u32, 0), source.schema_identity.version.patch);
    try std.testing.expectEqualStrings("human_base", source.asset_identity.asset_id.value.bytes);
    try std.testing.expectEqualStrings("Human Base", source.asset_identity.display_name.bytes);
    try std.testing.expectEqual(canonical.coordinate.canonical, source.coordinate_contract.?);
    try std.testing.expectEqual(@as(f32, 1.8288), source.coordinate_contract.?.canonical_height_m);
    try std.testing.expectEqual(canonical.coordinate.AxisDirection.positive_z, source.coordinate_contract.?.canonical_forward);
    try std.testing.expectEqual(canonical.coordinate.AssetOrigin.centered_between_feet_on_ground_in_a_pose, source.coordinate_contract.?.asset_origin);
    try std.testing.expectEqual(canonical.coordinate.BindPose.a_pose, source.coordinate_contract.?.bind_pose);
}

test "Prompt 2A component tree has the approved 48 stable identities" {
    try std.testing.expectEqual(human_base.component_count, human_base.source.components.len);
    var root_count: usize = 0;
    for (human_base.source.components) |record| {
        if (record.parent_component_id == null) root_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), root_count);
    try expectComponent("body", null, .required, .enabled);
    try expectComponent("torso", "body", .required, .enabled);
    try expectComponent("arm_left_01", "body", .required, .enabled);
    try expectComponent("hand_right_01", "arm_right_01", .required, .enabled);
    try expectComponent("leg_left_01", "pelvis", .required, .enabled);
    try expectComponent("foot_right_01", "leg_right_01", .required, .enabled);
    try expectComponent("mouth_cavity", "mouth", .required, .enabled);
    try expectComponent("fingernail_thumb_left", "hand_left_01", .required, .enabled);
    try expectComponent("toenail_little_right", "foot_right_01", .required, .enabled);
}

test "Prompt 2A optional anatomy remains present with approved neutral defaults" {
    try expectComponent("anus_module_01", "pelvis", .optional, .enabled);
    try expectComponent("vulva_vaginal_canal_module_01", "pelvis", .optional, .disabled);
    try expectComponent("penis_module_01", "pelvis", .optional, .disabled);
    try expectComponent("scrotum_testicles_module_01", "pelvis", .optional, .disabled);

    try expectVisibility("anus_module_01", .present, .enabled, .visible);
    try expectVisibility("vulva_vaginal_canal_module_01", .present, .disabled, .hidden_by_policy);
    try expectVisibility("penis_module_01", .present, .disabled, .hidden_by_policy);
    try expectVisibility("scrotum_testicles_module_01", .present, .disabled, .hidden_by_policy);
}

test "Prompt 2A region and surface inventory preserves adult anatomy identities" {
    try std.testing.expectEqual(human_base.region_surface_count, human_base.source.regions.len);
    try std.testing.expectEqual(human_base.region_surface_count, human_base.source.surfaces.len);
    inline for (.{
        "breast_left",
        "nipple_right",
        "areola_left",
        "anus_external",
        "perianal",
        "anal_canal",
        "labia_majora_left",
        "labia_minora_right",
        "clitoral_region",
        "urethral_opening",
        "vaginal_opening",
        "vestibule",
        "vaginal_canal",
        "penis_shaft",
        "scrotum",
        "testicle_left",
        "testicle_right",
    }) |region_id| {
        try std.testing.expect(findRegion(region_id) != null);
        try std.testing.expect(findSurface(region_id ++ "_surface") != null);
    }
    const breast = findRegion("breast_left").?;
    try std.testing.expectEqualStrings("torso", breast.owner_component_id.value.bytes);
    const anal_canal = findRegion("anal_canal").?;
    try std.testing.expectEqualStrings("anus_module_01", anal_canal.owner_component_id.value.bytes);
}

test "Prompt 2A neutral materials keep definitions and instances separate" {
    try std.testing.expectEqual(human_base.neutral_material_count, human_base.source.material_definitions.len);
    try std.testing.expectEqual(human_base.neutral_material_count, human_base.source.material_instances.len);
    for (human_base.material_specs) |spec| {
        try std.testing.expect(!std.mem.eql(u8, spec.definition_id, spec.instance_id));
        const instance = findMaterialInstance(spec.instance_id).?;
        try std.testing.expectEqualStrings(spec.definition_id, instance.definition_id.value.bytes);
        const color = switch (instance.properties[0].value) {
            .linear_srgb_rgba => |value| value,
            else => return error.UnexpectedMaterialValue,
        };
        for (color.channels) |channel| {
            try std.testing.expect(std.math.isFinite(channel));
            try std.testing.expect(channel >= 0 and channel <= 1);
        }
    }
}

test "Prompt 2A human validation rejects structural drift" {
    var source = human_base.source;
    source.components = source.components[0 .. source.components.len - 1];
    try std.testing.expectError(error.InvalidComponentCount, human_validation.validatePrompt2A(&source));

    var changed_components = human_base.components;
    const anus_index = componentIndex("anus_module_01").?;
    changed_components[anus_index].default_state = .disabled;
    source = human_base.source;
    source.components = &changed_components;
    try std.testing.expectError(error.ComponentContractMismatch, human_validation.validatePrompt2A(&source));

    var changed_bones = human_base.bones;
    changed_bones[0].owner_component_id = null;
    source = human_base.source;
    source.bones = &changed_bones;
    try std.testing.expectError(error.MissingBoneOwner, human_validation.validatePrompt2A(&source));

    var changed_surfaces = human_base.surfaces;
    changed_surfaces[0].owner_component_id = try identity.ComponentId.init("pelvis");
    source = human_base.source;
    source.surfaces = &changed_surfaces;
    try std.testing.expectError(error.RegionSurfaceContractMismatch, human_validation.validatePrompt2A(&source));
}

test "component-owned bone reference is typed and generically validated" {
    var bones = human_base.bones;
    bones[0].owner_component_id = try identity.ComponentId.init("human_base_skin");
    var source = human_base.source;
    source.bones = &bones;
    var diagnostic_storage: [16]diagnostics.Diagnostic = undefined;
    const report = try validation.validate(&source, .{}, &diagnostic_storage);
    try std.testing.expect(!report.isValid());
    try std.testing.expectEqual(@as(usize, 1), report.error_count);
    try std.testing.expectEqual(diagnostics.Code.wrong_reference_type, report.diagnostics[0].code);
    try std.testing.expectEqualStrings("owner_component_id", report.diagnostics[0].property.?);
}

test "component-owned bone field requires schema 1.1 or newer" {
    var source = human_base.source;
    source.schema_identity.version = .{ .major = 1, .minor = 0, .patch = 0 };
    source.bones = human_base.source.bones[0..1];
    source.joints = &.{};
    source.controls = &.{};
    source.anchors = &.{};
    source.sockets = &.{};
    source.mount_anchors = &.{};
    source.attachments = &.{};
    source.landmarks = &.{};
    source.shared_seams = &.{};
    source.interaction_sites = &.{};
    source.effectors = &.{};
    var diagnostic_storage: [16]diagnostics.Diagnostic = undefined;
    const report = try validation.validate(&source, .{}, &diagnostic_storage);
    try std.testing.expect(!report.isValid());
    try std.testing.expectEqual(@as(usize, 1), report.error_count);
    try std.testing.expectEqual(diagnostics.Code.schema_feature_version_mismatch, report.diagnostics[0].code);
}

test "M01 canonical golden remains byte-identical without owner field" {
    var parsed = try parsing.parse(std.testing.allocator, m01_canonical_json);
    defer parsed.deinit();
    const offset_operations = [_]canonical.morphology.BindingOperation{.offset};
    const scale_operations = [_]canonical.morphology.BindingOperation{.scale};
    const set_operations = [_]canonical.morphology.BindingOperation{.set};
    const property_rules = [_]canonical.morphology.BindingPropertyRule{
        .{ .target_type = .anchor_transform, .property_id = try identity.PropertyId.init("position_y"), .allowed_operations = &offset_operations },
        .{ .target_type = .rest_bone_transform, .property_id = try identity.PropertyId.init("translation_y"), .allowed_operations = &offset_operations },
        .{ .target_type = .rest_bone_transform, .property_id = try identity.PropertyId.init("scale_x"), .allowed_operations = &scale_operations },
        .{ .target_type = .material_parameter, .property_id = try identity.PropertyId.init("roughness"), .allowed_operations = &set_operations },
    };
    var diagnostic_storage: [64]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(
        &parsed.value,
        .{ .binding_schema = .{ .property_rules = &property_rules } },
        &diagnostic_storage,
    );
    try std.testing.expect(normalized.isValid());
    const canonical_bytes = try serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(canonical_bytes);
    try std.testing.expectEqualStrings(m01_canonical_json, canonical_bytes);
    for (parsed.value.bones) |bone| try std.testing.expect(bone.owner_component_id == null);
    for (parsed.value.joints) |joint| try std.testing.expect(joint.mirror_joint_id == null);
    for (parsed.value.anchors) |anchor| try std.testing.expect(anchor.mirror_anchor_id == null);
    for (parsed.value.landmarks) |landmark| try std.testing.expect(landmark.mirror_landmark_id == null);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "mirror_joint_id") == null);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "mirror_anchor_id") == null);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "mirror_landmark_id") == null);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "\"bone_id\":\"skeleton_root\",\"display_name\":\"Skeleton Root\",\"parent_bone_id\"") != null);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canonical_bytes, &digest, .{});
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    try std.testing.expectEqualStrings(m01_phase_f_sha256, &digest_hex);
}

fn expectComponent(
    id: []const u8,
    parent_id: ?[]const u8,
    requirement: canonical.component.Requirement,
    default_state: canonical.component.DefaultState,
) !void {
    const record = human_base.source.components[componentIndex(id) orelse return error.MissingComponent];
    try std.testing.expectEqual(requirement, record.requirement);
    try std.testing.expectEqual(default_state, record.default_state);
    if (parent_id) |expected_parent| {
        try std.testing.expect(record.parent_component_id != null);
        try std.testing.expectEqualStrings(expected_parent, record.parent_component_id.?.value.bytes);
    } else {
        try std.testing.expect(record.parent_component_id == null);
    }
}

fn expectVisibility(
    component_id: []const u8,
    existence: canonical.visibility.ComponentExistence,
    enabled_state: canonical.visibility.ComponentEnabledState,
    visibility_state: canonical.visibility.VisibilityState,
) !void {
    for (human_base.source.visibility_metadata) |record| switch (record.subject) {
        .component => |id| if (std.mem.eql(u8, id.value.bytes, component_id)) {
            try std.testing.expectEqual(existence, record.component_existence);
            try std.testing.expectEqual(enabled_state, record.component_enabled_state);
            try std.testing.expectEqual(visibility_state, record.visibility_state);
            try std.testing.expectEqual(@as(f32, 0), record.coverage.value);
            try std.testing.expectEqual(std.meta.Tag(canonical.visibility.RepresentationSelection).canonical, std.meta.activeTag(record.representation));
            return;
        },
        else => {},
    };
    return error.MissingVisibility;
}

fn componentIndex(id: []const u8) ?usize {
    for (human_base.source.components, 0..) |record, index| {
        if (std.mem.eql(u8, record.component_id.value.bytes, id)) return index;
    }
    return null;
}

fn findRegion(id: []const u8) ?canonical.semantics.Region {
    for (human_base.source.regions) |record| if (std.mem.eql(u8, record.region_id.value.bytes, id)) return record;
    return null;
}

fn findSurface(id: []const u8) ?canonical.semantics.Surface {
    for (human_base.source.surfaces) |record| if (std.mem.eql(u8, record.surface_id.value.bytes, id)) return record;
    return null;
}

fn findMaterialInstance(id: []const u8) ?canonical.material.MaterialInstance {
    for (human_base.source.material_instances) |record| if (std.mem.eql(u8, record.material_instance_id.value.bytes, id)) return record;
    return null;
}
