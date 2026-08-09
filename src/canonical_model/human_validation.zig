const std = @import("std");
const component = @import("component.zig");
const coordinate = @import("coordinate.zig");
const definition = @import("definition.zig");
const human_base = @import("human_base.zig");
const human_measurements = @import("human_measurements.zig");
const human_rig = @import("human_rig.zig");
const identity = @import("identity.zig");
const material = @import("material.zig");
const semantics = @import("semantics.zig");
const visibility = @import("visibility.zig");

pub const Error = error{
    InvalidSchemaIdentity,
    InvalidAssetIdentity,
    InvalidCompilerIdentity,
    InvalidCoordinateContract,
    InvalidComponentCount,
    MissingApprovedComponent,
    ComponentContractMismatch,
    InvalidOptionalModuleMultiplicity,
    InvalidRootBoneContract,
    MissingBoneOwner,
    InvalidRegionCount,
    InvalidSurfaceCount,
    MissingApprovedRegion,
    MissingApprovedSurface,
    RegionSurfaceContractMismatch,
    InvalidMaterialDefinitionCount,
    InvalidMaterialInstanceCount,
    MissingApprovedMaterialDefinition,
    MissingApprovedMaterialInstance,
    MaterialContractMismatch,
    InvalidVisibilityCount,
    MissingComponentVisibility,
    VisibilityContractMismatch,
    MissingSkeletonRoot,
    MultipleSkeletonRoots,
    WrongPelvisParent,
    WrongSpineCount,
    WrongNeckCount,
    WrongUpperArmTwistCount,
    WrongForearmTwistCount,
    WrongThighTwistCount,
    WrongLowerLegTwistCount,
    MalformedFingerChain,
    MalformedToeChain,
    WrongDefaultEyeCount,
    WrongEyelidCount,
    WrongDefaultEarCount,
    WrongTongueCount,
    BoneCountMismatch,
    MissingApprovedBone,
    BoneContractMismatch,
    BoneOwnedByDisabledComponent,
    ActiveChildDependsOnInactiveParent,
    OptionalRigCreatesSecondSkeleton,
    OptionalActivationChangesSharedIds,
    CrossComponentHierarchyMismatch,
    CanonicalHeightMismatch,
    GroundReferenceMismatch,
    BilateralMirrorMismatch,
    MeasurementDerivationFailed,
};

pub fn validatePrompt2A(source: *const definition.CanonicalCreatureDefinition) Error!void {
    try validateIdentityAndCoordinates(source);
    try validateComponents(source.components);
    try validateRootBone(source);
    try validateRegionsAndSurfaces(source.regions, source.surfaces);
    try validateMaterials(source.material_definitions, source.material_instances);
    try validateVisibility(source.visibility_metadata);
}

pub fn validatePrompt2B(source: *const definition.CanonicalCreatureDefinition) Error!void {
    @setEvalBranchQuota(500_000);
    try validateIdentityAndCoordinates(source);
    try validateComponents(source.components);
    try validateRegionsAndSurfaces(source.regions, source.surfaces);
    try validateMaterials(source.material_definitions, source.material_instances);
    try validateVisibility(source.visibility_metadata);
    try validateSkeletonRoots(source);
    try validatePelvisParent(source);
    try validateLockedCounts(source);
    try validateFingerChains(source);
    try validateToeChains(source);
    try validatePrompt2BActivation(source);
    try validateBoneManifest(source);

    const report = human_measurements.generate(source) catch return error.MeasurementDerivationFailed;
    if (!near(report.total_height_m, coordinate.canonical.canonical_height_m, human_rig.measurement_tolerance_m)) {
        return error.CanonicalHeightMismatch;
    }
    inline for (.{
        report.key_joints.heel_contacts.left.y,
        report.key_joints.heel_contacts.right.y,
        report.key_joints.big_toe_tips.left.y,
        report.key_joints.big_toe_tips.right.y,
    }) |ground_y| {
        if (!near(ground_y, coordinate.canonical.ground_y_m, human_rig.measurement_tolerance_m)) {
            return error.GroundReferenceMismatch;
        }
    }
    human_measurements.validateSymmetry(source, human_rig.test_only_symmetry_tolerance) catch {
        return error.BilateralMirrorMismatch;
    };
    try validateRestData(source);
}

fn validateSkeletonRoots(source: *const definition.CanonicalCreatureDefinition) Error!void {
    var root_count: usize = 0;
    var has_skeleton_root = false;
    for (source.bones) |bone| {
        if (bone.parent_bone_id == null) root_count += 1;
        if (std.mem.eql(u8, bone.bone_id.value.bytes, "skeleton_root")) has_skeleton_root = true;
    }
    if (!has_skeleton_root) return error.MissingSkeletonRoot;
    if (root_count > 1) return error.MultipleSkeletonRoots;
    if (root_count == 0) return error.MissingSkeletonRoot;
}

fn validatePelvisParent(source: *const definition.CanonicalCreatureDefinition) Error!void {
    const pelvis = findBone(source, "pelvis") orelse return error.WrongPelvisParent;
    const parent = pelvis.parent_bone_id orelse return error.WrongPelvisParent;
    if (!std.mem.eql(u8, parent.value.bytes, "skeleton_root")) return error.WrongPelvisParent;
}

fn validateLockedCounts(source: *const definition.CanonicalCreatureDefinition) Error!void {
    @setEvalBranchQuota(500_000);
    if (countBonePrefix(source, "spine_") != 7) return error.WrongSpineCount;
    if (countBonePrefix(source, "neck_") != 3) return error.WrongNeckCount;
    inline for (.{ "left", "right" }) |side| {
        if (countBonePrefix(source, std.fmt.comptimePrint("upper_arm_twist_{s}_", .{side})) != 2) return error.WrongUpperArmTwistCount;
        if (countBonePrefix(source, std.fmt.comptimePrint("forearm_twist_{s}_", .{side})) != 2) return error.WrongForearmTwistCount;
        if (countBonePrefix(source, std.fmt.comptimePrint("thigh_twist_{s}_", .{side})) != 2) return error.WrongThighTwistCount;
        if (countBonePrefix(source, std.fmt.comptimePrint("lower_leg_twist_{s}_", .{side})) != 2) return error.WrongLowerLegTwistCount;
    }
    if (countBonePrefix(source, "eyeball_") != 2) return error.WrongDefaultEyeCount;
    if (countBonePrefix(source, "eyelid_") != 12) return error.WrongEyelidCount;
    if (countBonePrefix(source, "ear_root_") != 2) return error.WrongDefaultEarCount;
    if (countTongueDeformationBones(source) != 4 or
        findBone(source, "tongue_branch_point") == null or
        findBone(source, "tongue_tip_01") == null)
    {
        return error.WrongTongueCount;
    }
}

fn validateFingerChains(source: *const definition.CanonicalCreatureDefinition) Error!void {
    @setEvalBranchQuota(500_000);
    inline for (.{ "left", "right" }) |side| {
        if (!hasParent(source, std.fmt.comptimePrint("thumb_metacarpal_{s}", .{side}), std.fmt.comptimePrint("hand_{s}", .{side})) or
            !hasParent(source, std.fmt.comptimePrint("thumb_proximal_{s}", .{side}), std.fmt.comptimePrint("thumb_metacarpal_{s}", .{side})) or
            !hasParent(source, std.fmt.comptimePrint("thumb_distal_{s}", .{side}), std.fmt.comptimePrint("thumb_proximal_{s}", .{side})))
        {
            return error.MalformedFingerChain;
        }
        inline for (.{ "index", "middle", "ring", "little" }) |finger| {
            if (!hasParent(source, std.fmt.comptimePrint("{s}_metacarpal_{s}", .{ finger, side }), std.fmt.comptimePrint("hand_{s}", .{side})) or
                !hasParent(source, std.fmt.comptimePrint("{s}_proximal_{s}", .{ finger, side }), std.fmt.comptimePrint("{s}_metacarpal_{s}", .{ finger, side })) or
                !hasParent(source, std.fmt.comptimePrint("{s}_middle_{s}", .{ finger, side }), std.fmt.comptimePrint("{s}_proximal_{s}", .{ finger, side })) or
                !hasParent(source, std.fmt.comptimePrint("{s}_distal_{s}", .{ finger, side }), std.fmt.comptimePrint("{s}_middle_{s}", .{ finger, side })))
            {
                return error.MalformedFingerChain;
            }
        }
    }
}

fn validateToeChains(source: *const definition.CanonicalCreatureDefinition) Error!void {
    @setEvalBranchQuota(500_000);
    inline for (.{ "left", "right" }) |side| {
        if (!hasParent(source, std.fmt.comptimePrint("toe_big_{s}_01", .{side}), std.fmt.comptimePrint("forefoot_{s}", .{side})) or
            !hasParent(source, std.fmt.comptimePrint("toe_big_{s}_02", .{side}), std.fmt.comptimePrint("toe_big_{s}_01", .{side})))
        {
            return error.MalformedToeChain;
        }
        inline for (.{ "index", "middle", "ring", "little" }) |toe| {
            if (!hasParent(source, std.fmt.comptimePrint("toe_{s}_{s}_01", .{ toe, side }), std.fmt.comptimePrint("forefoot_{s}", .{side})) or
                !hasParent(source, std.fmt.comptimePrint("toe_{s}_{s}_02", .{ toe, side }), std.fmt.comptimePrint("toe_{s}_{s}_01", .{ toe, side })) or
                !hasParent(source, std.fmt.comptimePrint("toe_{s}_{s}_03", .{ toe, side }), std.fmt.comptimePrint("toe_{s}_{s}_02", .{ toe, side })))
            {
                return error.MalformedToeChain;
            }
        }
    }
}

fn validateBoneManifest(source: *const definition.CanonicalCreatureDefinition) Error!void {
    @setEvalBranchQuota(500_000);
    if (source.bones.len != human_rig.bone_count) return error.BoneCountMismatch;
    inline for (human_rig.bone_specs) |spec| {
        const bone = findBone(source, spec.bone_id) orelse return error.MissingApprovedBone;
        const owner = bone.owner_component_id orelse return error.MissingBoneOwner;
        if (!std.mem.eql(u8, owner.value.bytes, spec.owner_component_id) or
            !optionalBoneIdMatches(bone.parent_bone_id, spec.parent_bone_id) or
            !optionalBoneIdMatches(bone.mirror_bone_id, spec.mirror_bone_id))
        {
            return error.CrossComponentHierarchyMismatch;
        }
        if (bone.deforms_mesh != spec.deforms_mesh) return error.BoneContractMismatch;
    }
}

fn validateRestData(source: *const definition.CanonicalCreatureDefinition) Error!void {
    @setEvalBranchQuota(500_000);
    inline for (human_rig.bone_specs) |spec| {
        const bone = findBone(source, spec.bone_id) orelse return error.MissingApprovedBone;
        if (!localTransformNear(bone.local_rest_transform, spec.local_rest_transform, human_rig.measurement_tolerance_m) or
            !optionalF32Near(bone.display_length_m, spec.display_length_m, human_rig.measurement_tolerance_m))
        {
            return error.BoneContractMismatch;
        }
    }
}

pub fn validatePrompt2BActivation(source: *const definition.CanonicalCreatureDefinition) Error!void {
    if (source.bones.len < human_rig.shared_bone_count) return error.OptionalActivationChangesSharedIds;
    inline for (human_rig.bone_specs[0..human_rig.shared_bone_count]) |spec| {
        if (findBone(source, spec.bone_id) == null) return error.OptionalActivationChangesSharedIds;
    }

    var active_root_count: usize = 0;
    for (source.bones) |bone| {
        const owner_id = bone.owner_component_id orelse return error.MissingBoneOwner;
        const active = componentIsEnabled(source, owner_id.value.bytes) orelse return error.MissingBoneOwner;
        if (active and bone.parent_bone_id == null) active_root_count += 1;
        if (active) if (bone.parent_bone_id) |parent_id| {
            const parent = findBone(source, parent_id.value.bytes) orelse return error.ActiveChildDependsOnInactiveParent;
            const parent_owner = parent.owner_component_id orelse return error.MissingBoneOwner;
            const parent_active = componentIsEnabled(source, parent_owner.value.bytes) orelse return error.MissingBoneOwner;
            if (!parent_active) return error.ActiveChildDependsOnInactiveParent;
        };
    }
    for (source.bones) |bone| {
        const owner_id = bone.owner_component_id orelse return error.MissingBoneOwner;
        const active = componentIsEnabled(source, owner_id.value.bytes) orelse return error.MissingBoneOwner;
        const spec = findBoneSpec(bone.bone_id.value.bytes) orelse return error.MissingApprovedBone;
        const optional_bone = spec.category == .optional_anatomy;
        if (!optional_bone and !active) return error.BoneOwnedByDisabledComponent;
    }
    if (active_root_count != 1) return error.OptionalRigCreatesSecondSkeleton;
}

fn countBonePrefix(source: *const definition.CanonicalCreatureDefinition, prefix: []const u8) usize {
    var count: usize = 0;
    for (source.bones) |bone| if (std.mem.startsWith(u8, bone.bone_id.value.bytes, prefix)) {
        count += 1;
    };
    return count;
}

fn countTongueDeformationBones(source: *const definition.CanonicalCreatureDefinition) usize {
    var count: usize = 0;
    inline for (1..5) |number| {
        const id = std.fmt.comptimePrint("tongue_{d:0>2}", .{number});
        if (findBone(source, id)) |bone| if (bone.deforms_mesh) {
            count += 1;
        };
    }
    return count;
}

fn findBone(source: *const definition.CanonicalCreatureDefinition, bone_id: []const u8) ?@import("rig.zig").Bone {
    for (source.bones) |bone| if (std.mem.eql(u8, bone.bone_id.value.bytes, bone_id)) return bone;
    return null;
}

fn findBoneSpec(bone_id: []const u8) ?human_rig.BoneSpec {
    for (human_rig.bone_specs) |spec| if (std.mem.eql(u8, spec.bone_id, bone_id)) return spec;
    return null;
}

fn hasParent(source: *const definition.CanonicalCreatureDefinition, bone_id: []const u8, parent_id: []const u8) bool {
    const bone = findBone(source, bone_id) orelse return false;
    const parent = bone.parent_bone_id orelse return false;
    return std.mem.eql(u8, parent.value.bytes, parent_id);
}

fn componentIsEnabled(source: *const definition.CanonicalCreatureDefinition, component_id: []const u8) ?bool {
    for (source.components) |record| {
        if (std.mem.eql(u8, record.component_id.value.bytes, component_id)) return record.default_state == .enabled;
    }
    return null;
}

fn optionalBoneIdMatches(actual: ?identity.BoneId, expected: ?[]const u8) bool {
    if (actual == null or expected == null) return actual == null and expected == null;
    return std.mem.eql(u8, actual.?.value.bytes, expected.?);
}

fn localTransformNear(a: @import("math3d.zig").LocalTransform, b: @import("math3d.zig").LocalTransform, tolerance: f32) bool {
    return vecNear(a.translation_m, b.translation_m, tolerance) and
        near(a.rotation.x, b.rotation.x, tolerance) and
        near(a.rotation.y, b.rotation.y, tolerance) and
        near(a.rotation.z, b.rotation.z, tolerance) and
        near(a.rotation.w, b.rotation.w, tolerance) and
        vecNear(a.scale, b.scale, tolerance);
}

fn vecNear(a: @import("math3d.zig").Vec3, b: @import("math3d.zig").Vec3, tolerance: f32) bool {
    return near(a.x, b.x, tolerance) and near(a.y, b.y, tolerance) and near(a.z, b.z, tolerance);
}

fn optionalF32Near(a: ?f32, b: ?f32, tolerance: f32) bool {
    if (a == null or b == null) return a == null and b == null;
    return near(a.?, b.?, tolerance);
}

fn near(a: f32, b: f32, tolerance: f32) bool {
    return @abs(a - b) <= tolerance;
}

fn validateIdentityAndCoordinates(source: *const definition.CanonicalCreatureDefinition) Error!void {
    if (!std.mem.eql(u8, source.schema_identity.schema_id.value.bytes, "canonical_creature_schema") or
        !std.meta.eql(source.schema_identity.version, human_base.schema_version))
    {
        return error.InvalidSchemaIdentity;
    }
    if (!std.mem.eql(u8, source.asset_identity.asset_id.value.bytes, "human_base") or
        !std.mem.eql(u8, source.asset_identity.display_name.bytes, "Human Base") or
        !std.meta.eql(source.asset_identity.version, human_base.asset_version))
    {
        return error.InvalidAssetIdentity;
    }
    if (!std.mem.eql(u8, source.compiler_identity.compiler_id.value.bytes, "m01_canonical_compiler") or
        !std.meta.eql(source.compiler_identity.version, human_base.compiler_version))
    {
        return error.InvalidCompilerIdentity;
    }
    const contract = source.coordinate_contract orelse return error.InvalidCoordinateContract;
    if (!std.meta.eql(contract, coordinate.canonical)) return error.InvalidCoordinateContract;
}

fn validateComponents(components: []const component.Component) Error!void {
    if (components.len != human_base.component_count) return error.InvalidComponentCount;
    for (human_base.component_specs) |spec| {
        const record = findComponent(components, spec.component_id) orelse return error.MissingApprovedComponent;
        if (spec.requirement == .optional and
            (record.multiplicity.minimum != 0 or record.multiplicity.maximum == null or record.multiplicity.maximum.? != 1))
        {
            return error.InvalidOptionalModuleMultiplicity;
        }
        if (!std.mem.eql(u8, record.component_type.value.bytes, spec.component_type) or
            !optionalIdMatches(record.parent_component_id, spec.parent_component_id) or
            record.requirement != spec.requirement or
            record.default_state != spec.default_state or
            record.multiplicity.minimum != (if (spec.requirement == .required) @as(u32, 1) else @as(u32, 0)) or
            record.multiplicity.maximum == null or
            record.multiplicity.maximum.? != 1)
        {
            return error.ComponentContractMismatch;
        }
    }
}

fn validateRootBone(source: *const definition.CanonicalCreatureDefinition) Error!void {
    const root = findRootBone(source) orelse return error.InvalidRootBoneContract;
    if (!std.mem.eql(u8, root.bone_id.value.bytes, "skeleton_root") or
        root.parent_bone_id != null or
        root.deforms_mesh or
        !std.meta.eql(root.local_rest_transform.translation_m, .{ .x = 0, .y = 0, .z = 0 }) or
        !std.meta.eql(root.local_rest_transform.rotation, .{ .x = 0, .y = 0, .z = 0, .w = 1 }) or
        !std.meta.eql(root.local_rest_transform.scale, .{ .x = 1, .y = 1, .z = 1 }))
    {
        return error.InvalidRootBoneContract;
    }
    const owner = root.owner_component_id orelse return error.MissingBoneOwner;
    if (!std.mem.eql(u8, owner.value.bytes, "body")) return error.InvalidRootBoneContract;
    for (source.bones) |bone| {
        if (bone.owner_component_id == null) return error.MissingBoneOwner;
    }
}

fn validateRegionsAndSurfaces(
    regions: []const semantics.Region,
    surfaces: []const semantics.Surface,
) Error!void {
    @setEvalBranchQuota(500_000);
    if (regions.len != human_base.region_surface_count) return error.InvalidRegionCount;
    if (surfaces.len != human_base.region_surface_count) return error.InvalidSurfaceCount;
    inline for (human_base.region_surface_specs) |spec| {
        const region = findRegion(regions, spec.region_id) orelse return error.MissingApprovedRegion;
        const surface_id = std.fmt.comptimePrint("{s}_surface", .{spec.region_id});
        const surface = findSurface(surfaces, surface_id) orelse return error.MissingApprovedSurface;
        if (!std.mem.eql(u8, region.owner_component_id.value.bytes, spec.owner_component_id) or
            !std.mem.eql(u8, surface.owner_component_id.value.bytes, spec.owner_component_id) or
            !surface.region_id.eql(region.region_id) or
            !std.mem.eql(u8, surface.material_instance_id.value.bytes, spec.material_instance_id) or
            surface.coordinate_metadata_id != null or
            surface.visibility_metadata_id != null)
        {
            return error.RegionSurfaceContractMismatch;
        }
    }
}

fn findRootBone(source: *const definition.CanonicalCreatureDefinition) ?@import("rig.zig").Bone {
    for (source.bones) |bone| if (std.mem.eql(u8, bone.bone_id.value.bytes, "skeleton_root")) return bone;
    return null;
}

fn validateMaterials(
    definitions: []const material.MaterialDefinition,
    instances: []const material.MaterialInstance,
) Error!void {
    if (definitions.len != human_base.neutral_material_count) return error.InvalidMaterialDefinitionCount;
    if (instances.len != human_base.neutral_material_count) return error.InvalidMaterialInstanceCount;
    for (human_base.material_specs) |spec| {
        const definition_record = findMaterialDefinition(definitions, spec.definition_id) orelse return error.MissingApprovedMaterialDefinition;
        const instance = findMaterialInstance(instances, spec.instance_id) orelse return error.MissingApprovedMaterialInstance;
        if (!std.mem.eql(u8, definition_record.display_name.bytes, spec.definition_display_name) or
            definition_record.property_specs.len != 1 or
            !std.mem.eql(u8, definition_record.property_specs[0].property_id.value.bytes, "base_color") or
            definition_record.property_specs[0].value_kind != .linear_srgb_rgba or
            !definition_record.property_specs[0].required or
            !std.mem.eql(u8, instance.display_name.bytes, spec.instance_display_name) or
            !std.mem.eql(u8, instance.definition_id.value.bytes, spec.definition_id) or
            instance.properties.len != 1 or
            !std.mem.eql(u8, instance.properties[0].property_id.value.bytes, "base_color"))
        {
            return error.MaterialContractMismatch;
        }
        switch (instance.properties[0].value) {
            .linear_srgb_rgba => |color| if (!std.meta.eql(color.channels, spec.color)) return error.MaterialContractMismatch,
            else => return error.MaterialContractMismatch,
        }
    }
}

fn validateVisibility(records: []const visibility.VisibilityCoverageMetadata) Error!void {
    if (records.len != human_base.component_count) return error.InvalidVisibilityCount;
    for (human_base.component_specs) |spec| {
        const record = findComponentVisibility(records, spec.component_id) orelse return error.MissingComponentVisibility;
        const enabled = spec.default_state == .enabled;
        const expected_enabled_state: visibility.ComponentEnabledState = if (enabled) .enabled else .disabled;
        const expected_visibility_state: visibility.VisibilityState = if (enabled) .visible else .hidden_by_policy;
        if (record.component_existence != .present or
            record.component_enabled_state != expected_enabled_state or
            record.visibility_state != expected_visibility_state or
            record.coverage.value != 0 or
            record.coverage_region_id != null or
            record.coverage_sources.len != 0 or
            std.meta.activeTag(record.representation) != .canonical)
        {
            return error.VisibilityContractMismatch;
        }
    }
}

fn findComponent(records: []const component.Component, id: []const u8) ?component.Component {
    for (records) |record| if (std.mem.eql(u8, record.component_id.value.bytes, id)) return record;
    return null;
}

fn findRegion(records: []const semantics.Region, id: []const u8) ?semantics.Region {
    for (records) |record| if (std.mem.eql(u8, record.region_id.value.bytes, id)) return record;
    return null;
}

fn findSurface(records: []const semantics.Surface, id: []const u8) ?semantics.Surface {
    for (records) |record| if (std.mem.eql(u8, record.surface_id.value.bytes, id)) return record;
    return null;
}

fn findMaterialDefinition(records: []const material.MaterialDefinition, id: []const u8) ?material.MaterialDefinition {
    for (records) |record| if (std.mem.eql(u8, record.material_definition_id.value.bytes, id)) return record;
    return null;
}

fn findMaterialInstance(records: []const material.MaterialInstance, id: []const u8) ?material.MaterialInstance {
    for (records) |record| if (std.mem.eql(u8, record.material_instance_id.value.bytes, id)) return record;
    return null;
}

fn findComponentVisibility(
    records: []const visibility.VisibilityCoverageMetadata,
    component_id: []const u8,
) ?visibility.VisibilityCoverageMetadata {
    for (records) |record| switch (record.subject) {
        .component => |id| if (std.mem.eql(u8, id.value.bytes, component_id)) return record,
        else => {},
    };
    return null;
}

fn optionalIdMatches(actual: ?identity.ComponentId, expected: ?[]const u8) bool {
    if (actual == null or expected == null) return actual == null and expected == null;
    return std.mem.eql(u8, actual.?.value.bytes, expected.?);
}
