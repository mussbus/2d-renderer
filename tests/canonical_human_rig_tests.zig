const std = @import("std");
const canonical = @import("canonical_model");
const human_test_support = @import("canonical_human_test_support.zig");

const diagnostics = canonical.diagnostics;
const human_measurements = canonical.human_measurements;
const human_validation = canonical.human_validation;
const identity = canonical.identity;
const math3d = canonical.math3d;
const normalization = canonical.normalization;
const parsing = canonical.parsing;
const serialization = canonical.serialization;

const tolerance: f32 = 1.0e-5;

test "Prompt 2B human rig validates and round-trips canonically" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    try human_validation.validatePrompt2A(source);
    try human_validation.validatePrompt2B(source);

    var diagnostic_storage: [512]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(source, .{}, &diagnostic_storage);
    try std.testing.expect(normalized.isValid());
    const canonical_bytes = try serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(canonical_bytes);

    var parsed = try parsing.parse(std.testing.allocator, canonical_bytes);
    defer parsed.deinit();
    try human_validation.validatePrompt2B(&parsed.value);
    var parsed_diagnostics: [512]diagnostics.Diagnostic = undefined;
    const round_trip = try normalization.normalize(&parsed.value, .{}, &parsed_diagnostics);
    try std.testing.expect(round_trip.isValid());
    const round_trip_bytes = try serialization.serializeAlloc(std.testing.allocator, round_trip.normalized.?);
    defer std.testing.allocator.free(round_trip_bytes);
    try std.testing.expectEqualStrings(canonical_bytes, round_trip_bytes);
}

test "Prompt 2B manifest has the approved skeleton counts" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    try std.testing.expectEqual(@as(usize, 149), source.bones.len);

    try expectCategoryCount(source, .root, 1);
    try expectCategoryCount(source, .torso, 13);
    try expectCategoryCount(source, .tongue, 6);
    try expectCategoryCount(source, .arm, 18);
    try expectCategoryCount(source, .hand, 38);
    try expectCategoryCount(source, .leg, 14);
    try expectCategoryCount(source, .foot, 34);
    try expectCategoryCount(source, .eye, 14);
    try expectCategoryCount(source, .ear, 2);
    try expectCategoryCount(source, .optional_anatomy, 9);

    var deformation_count: usize = 0;
    var structural_count: usize = 0;
    var root_count: usize = 0;
    for (source.bones) |bone| {
        if (bone.deforms_mesh) deformation_count += 1 else structural_count += 1;
        if (bone.parent_bone_id == null) root_count += 1;
        try std.testing.expect(bone.owner_component_id != null);
    }
    try std.testing.expectEqual(@as(usize, 142), deformation_count);
    try std.testing.expectEqual(@as(usize, 7), structural_count);
    try std.testing.expectEqual(@as(usize, 1), root_count);
}

test "Prompt 2B hierarchy preserves main chains and auxiliary twist branches" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    try expectParent(source, "pelvis", "skeleton_root");
    try expectParent(source, "spine_01", "pelvis");
    try expectParent(source, "spine_07", "spine_06");
    try expectParent(source, "neck_01", "spine_07");
    try expectParent(source, "head", "neck_03");
    try expectParent(source, "jaw", "head");
    try expectParent(source, "clavicle_left", "spine_07");
    try expectParent(source, "scapula_left", "clavicle_left");
    try expectParent(source, "upper_arm_left", "scapula_left");
    try expectParent(source, "forearm_left", "upper_arm_left");
    try expectParent(source, "upper_arm_twist_left_01", "upper_arm_left");
    try expectParent(source, "upper_arm_twist_left_02", "upper_arm_twist_left_01");
    try expectParent(source, "hand_left", "forearm_left");
    try expectParent(source, "ankle_left", "lower_leg_left");
    try std.testing.expect(!findBone(source, "ankle_left").?.deforms_mesh);
    try expectParent(source, "foot_left", "ankle_left");
    try expectParent(source, "midfoot_left", "foot_left");
    try expectParent(source, "forefoot_left", "midfoot_left");
    try expectParent(source, "tongue_01", "jaw");
    try expectParent(source, "tongue_branch_point", "tongue_04");
    try std.testing.expect(!findBone(source, "tongue_branch_point").?.deforms_mesh);
    try expectParent(source, "tongue_tip_01", "tongue_branch_point");
    try std.testing.expect(!findBone(source, "tongue_tip_01").?.deforms_mesh);
    try expectParent(source, "eyeball_left_01", "head");
    try expectParent(source, "eyelid_upper_left_center", "head");
    try expectParent(source, "ear_root_right_01", "head");
    try expectParent(source, "penis_root_01", "pelvis");
    try expectParent(source, "penis_shaft_07", "penis_shaft_06");
    try expectParent(source, "penis_tip_01", "penis_shaft_07");
}

test "Prompt 2B ownership and non-bone mouth following are explicit" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    try expectOwnedBoneCount(source, "body", 1);
    try expectOwnedBoneCount(source, "torso", 11);
    try expectOwnedBoneCount(source, "pelvis", 1);
    try expectOwnedBoneCount(source, "neck", 3);
    try expectOwnedBoneCount(source, "head", 1);
    try expectOwnedBoneCount(source, "mouth", 1);
    try expectOwnedBoneCount(source, "tongue", 6);
    try expectOwnedBoneCount(source, "arm_left_01", 6);
    try expectOwnedBoneCount(source, "arm_right_01", 6);
    try expectOwnedBoneCount(source, "hand_left_01", 20);
    try expectOwnedBoneCount(source, "hand_right_01", 20);
    try expectOwnedBoneCount(source, "leg_left_01", 7);
    try expectOwnedBoneCount(source, "leg_right_01", 7);
    try expectOwnedBoneCount(source, "foot_left_01", 17);
    try expectOwnedBoneCount(source, "foot_right_01", 17);
    try expectOwnedBoneCount(source, "eye_left_01", 7);
    try expectOwnedBoneCount(source, "eye_right_01", 7);
    try expectOwnedBoneCount(source, "ear_left_01", 1);
    try expectOwnedBoneCount(source, "ear_right_01", 1);
    try expectOwnedBoneCount(source, "penis_module_01", 9);

    inline for (.{ "mouth", "mouth_cavity", "teeth_upper", "gums_palate_upper", "teeth_lower", "gums_lower", "tongue" }) |component_id| {
        try std.testing.expect(findComponent(source, component_id) != null);
    }
    try expectParent(source, "jaw", "head");
    try expectParent(source, "tongue_01", "jaw");
}

test "Prompt 2B local A-pose composes into a nontrivial global pose" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    const pose = try human_measurements.deriveGlobalPose(source);
    const shoulder_left = (try pose.transformFor(source, "upper_arm_left")).translation_m;
    const shoulder_right = (try pose.transformFor(source, "upper_arm_right")).translation_m;
    const elbow_left = (try pose.transformFor(source, "forearm_left")).translation_m;
    const elbow_right = (try pose.transformFor(source, "forearm_right")).translation_m;
    const wrist_left = (try pose.transformFor(source, "hand_left")).translation_m;
    const wrist_right = (try pose.transformFor(source, "hand_right")).translation_m;

    try std.testing.expect(elbow_left.x < shoulder_left.x);
    try std.testing.expect(elbow_right.x > shoulder_right.x);
    try std.testing.expect(elbow_left.y < shoulder_left.y);
    try std.testing.expect(elbow_right.y < shoulder_right.y);
    try std.testing.expect(wrist_left.y < elbow_left.y);
    try std.testing.expect(wrist_right.y < elbow_right.y);

    const upper_arm_left = findBone(source, "upper_arm_left").?;
    const forearm_left = findBone(source, "forearm_left").?;
    const expected_forearm = math3d.AffineTransform.compose(
        try pose.transformFor(source, upper_arm_left.bone_id.value.bytes),
        math3d.AffineTransform.fromLocal(forearm_left.local_rest_transform),
    );
    try std.testing.expect(std.meta.eql(expected_forearm, try pose.transformFor(source, "forearm_left")));
    try std.testing.expect(!std.meta.eql(forearm_left.local_rest_transform.translation_m, elbow_left));
}

test "Prompt 2B measurement report is deterministic and ground-referenced" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    const first = try human_measurements.generate(source);
    const second = try human_measurements.generate(source);
    try std.testing.expect(std.meta.eql(first, second));
    try expectNear(1.8288, first.total_height_m);
    try expectNear(0, first.key_joints.heel_contacts.left.y);
    try expectNear(0, first.key_joints.heel_contacts.right.y);
    try expectNear(0, first.key_joints.big_toe_tips.left.y);
    try expectNear(0, first.key_joints.big_toe_tips.right.y);
    try expectNear(distance(first.key_joints.shoulders.left, first.key_joints.elbows.left), first.upper_arm_length_m);
    try expectNear(distance(first.key_joints.elbows.left, first.key_joints.wrists.left), first.forearm_length_m);
    try expectNear(distance(first.key_joints.hips.left, first.key_joints.knees.left), first.thigh_length_m);
    try expectNear(distance(first.key_joints.knees.left, first.key_joints.ankles.left), first.lower_leg_length_m);
    try std.testing.expect(first.shoulder_breadth_m > first.hip_breadth_m);
    try std.testing.expect(first.arm_span_m > 1.0);
    try std.testing.expect(first.hand_length_m > 0.10);
    try std.testing.expect(first.foot_length_m > 0.20);
    try std.testing.expect(first.head_height_m > 0.20);

    std.debug.print(
        "PROMPT2B_MEASUREMENTS height={d:.6} shoulder={d:.6} hip={d:.6} arm_span={d:.6} torso={d:.6} leg={d:.6} upper_arm={d:.6} forearm={d:.6} thigh={d:.6} lower_leg={d:.6} hand={d:.6} foot={d:.6} head={d:.6}\n",
        .{
            first.total_height_m,
            first.shoulder_breadth_m,
            first.hip_breadth_m,
            first.arm_span_m,
            first.torso_length_m,
            first.leg_length_m,
            first.upper_arm_length_m,
            first.forearm_length_m,
            first.thigh_length_m,
            first.lower_leg_length_m,
            first.hand_length_m,
            first.foot_length_m,
            first.head_height_m,
        },
    );
}

test "Prompt 2B bilateral rest and derived transforms mirror across sagittal zero" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    try human_measurements.validateSymmetry(source, tolerance);
    const report = try human_measurements.generate(source);
    try expectMirrored(report.key_joints.shoulders);
    try expectMirrored(report.key_joints.elbows);
    try expectMirrored(report.key_joints.wrists);
    try expectMirrored(report.key_joints.hips);
    try expectMirrored(report.key_joints.knees);
    try expectMirrored(report.key_joints.ankles);
    try expectMirrored(report.key_joints.eyes);
    try expectMirrored(report.key_joints.ears);
    try expectMirrored(report.key_joints.heel_contacts);
    try expectMirrored(report.key_joints.big_toe_tips);
    try expectNear(
        distance(report.key_joints.shoulders.left, report.key_joints.elbows.left),
        distance(report.key_joints.shoulders.right, report.key_joints.elbows.right),
    );
    try expectNear(
        distance(report.key_joints.elbows.left, report.key_joints.wrists.left),
        distance(report.key_joints.elbows.right, report.key_joints.wrists.right),
    );
    try expectNear(
        distance(report.key_joints.hips.left, report.key_joints.knees.left),
        distance(report.key_joints.hips.right, report.key_joints.knees.right),
    );
    try expectNear(
        distance(report.key_joints.knees.left, report.key_joints.ankles.left),
        distance(report.key_joints.knees.right, report.key_joints.ankles.right),
    );
    try expectNear(
        distance(report.key_joints.heel_contacts.left, report.key_joints.big_toe_tips.left),
        distance(report.key_joints.heel_contacts.right, report.key_joints.big_toe_tips.right),
    );
}

test "Prompt 2B parser-backed invalid source retains the height diagnostic" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const base = loaded.definition();
    var bones = try human_test_support.dupe(canonical.rig.Bone, base.bones);
    defer std.testing.allocator.free(bones);
    bones[boneIndex(base, "head").?].local_rest_transform.translation_m.y += 0.01;
    var source = base.*;
    source.bones = bones;
    var diagnostic_storage: [512]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(&source, .{}, &diagnostic_storage);
    try std.testing.expect(normalized.isValid());
    const bytes = try serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(bytes);
    var parsed = try parsing.parse(std.testing.allocator, bytes);
    defer parsed.deinit();
    try std.testing.expectError(error.CanonicalHeightMismatch, human_validation.validatePrompt2B(&parsed.value));
}

test "Prompt 2B optional activation preserves shared IDs and one skeleton" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const base = loaded.definition();
    try std.testing.expectEqual(@as(usize, 140), activeBoneCount(base));
    try human_validation.validatePrompt2BActivation(base);

    var enabled_components = try human_test_support.dupe(canonical.component.Component, base.components);
    defer std.testing.allocator.free(enabled_components);
    enabled_components[componentIndex(base, "penis_module_01").?].default_state = .enabled;
    var enabled_source = base.*;
    enabled_source.components = enabled_components;
    try std.testing.expectEqual(@as(usize, 149), activeBoneCount(&enabled_source));
    try human_validation.validatePrompt2BActivation(&enabled_source);
    for (base.bones) |bone| if (!std.mem.eql(u8, bone.owner_component_id.?.value.bytes, "penis_module_01")) {
        try std.testing.expect(findBone(&enabled_source, bone.bone_id.value.bytes) != null);
    };
}

test "Prompt 2B validator reports root pelvis and count defects precisely" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const base = loaded.definition();
    var bones = try human_test_support.dupe(canonical.rig.Bone, base.bones);
    defer std.testing.allocator.free(bones);
    bones[boneIndex(base, "skeleton_root").?].bone_id = try identity.BoneId.init("renamed_root");
    try expectValidationError(base, error.MissingSkeletonRoot, bones);

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "penis_root_01").?].parent_bone_id = null;
    try expectValidationError(base, error.MultipleSkeletonRoots, bones);

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "pelvis").?].parent_bone_id = try identity.BoneId.init("head");
    try expectValidationError(base, error.WrongPelvisParent, bones);

    try expectRenamedBoneError(base, "spine_07", "renamed_spine", error.WrongSpineCount);
    try expectRenamedBoneError(base, "neck_03", "renamed_neck", error.WrongNeckCount);
    try expectRenamedBoneError(base, "upper_arm_twist_left_02", "renamed_upper_twist", error.WrongUpperArmTwistCount);
    try expectRenamedBoneError(base, "forearm_twist_right_02", "renamed_forearm_twist", error.WrongForearmTwistCount);
    try expectRenamedBoneError(base, "thigh_twist_left_02", "renamed_thigh_twist", error.WrongThighTwistCount);
    try expectRenamedBoneError(base, "lower_leg_twist_right_02", "renamed_lower_leg_twist", error.WrongLowerLegTwistCount);
    try expectRenamedBoneError(base, "eyeball_left_01", "renamed_eye", error.WrongDefaultEyeCount);
    try expectRenamedBoneError(base, "eyelid_upper_left_center", "renamed_lid", error.WrongEyelidCount);
    try expectRenamedBoneError(base, "ear_root_right_01", "renamed_ear", error.WrongDefaultEarCount);
    try expectRenamedBoneError(base, "tongue_04", "renamed_tongue", error.WrongTongueCount);
}

test "Prompt 2B validator rejects malformed chains and ownership activation defects" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const base = loaded.definition();
    var bones = try human_test_support.dupe(canonical.rig.Bone, base.bones);
    defer std.testing.allocator.free(bones);
    bones[boneIndex(base, "index_middle_left").?].parent_bone_id = try identity.BoneId.init("hand_left");
    try expectValidationError(base, error.MalformedFingerChain, bones);

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "toe_index_right_03").?].parent_bone_id = try identity.BoneId.init("forefoot_right");
    try expectValidationError(base, error.MalformedToeChain, bones);

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "ear_root_left_01").?].owner_component_id = null;
    try expectValidationError(base, error.MissingBoneOwner, bones);

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "head").?].owner_component_id = try identity.ComponentId.init("penis_module_01");
    var source = base.*;
    source.bones = bones;
    try std.testing.expectError(error.ActiveChildDependsOnInactiveParent, human_validation.validatePrompt2BActivation(&source));

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "ear_root_left_01").?].owner_component_id = try identity.ComponentId.init("penis_module_01");
    source.bones = bones;
    try std.testing.expectError(error.BoneOwnedByDisabledComponent, human_validation.validatePrompt2BActivation(&source));

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "ear_root_left_01").?].bone_id = try identity.BoneId.init("changed_shared_bone_id");
    source.bones = bones;
    try std.testing.expectError(error.OptionalActivationChangesSharedIds, human_validation.validatePrompt2BActivation(&source));

    var enabled_components = try human_test_support.dupe(canonical.component.Component, base.components);
    defer std.testing.allocator.free(enabled_components);
    enabled_components[componentIndex(base, "penis_module_01").?].default_state = .enabled;
    @memcpy(bones, base.bones);
    bones[boneIndex(base, "penis_root_01").?].parent_bone_id = null;
    source = base.*;
    source.components = enabled_components;
    source.bones = bones;
    try std.testing.expectError(error.OptionalRigCreatesSecondSkeleton, human_validation.validatePrompt2BActivation(&source));
}

test "Prompt 2B validator distinguishes locked geometry failures from OPEN TUNING rest edits" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const base = loaded.definition();
    var bones = try human_test_support.dupe(canonical.rig.Bone, base.bones);
    defer std.testing.allocator.free(bones);
    bones[boneIndex(base, "head").?].local_rest_transform.translation_m.y += 0.01;
    try expectValidationError(base, error.CanonicalHeightMismatch, bones);

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "foot_left").?].local_rest_transform.translation_m.y += 0.01;
    try expectValidationError(base, error.GroundReferenceMismatch, bones);

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "upper_arm_left").?].local_rest_transform.rotation = math3d.Quaternion.identity;
    try expectValidationError(base, error.BilateralMirrorMismatch, bones);

    @memcpy(bones, base.bones);
    bones[boneIndex(base, "jaw").?].local_rest_transform.translation_m.z += 0.001;
    var tuned = base.*;
    tuned.bones = bones;
    try human_validation.validatePrompt2B(&tuned);
    var diagnostics_storage: [512]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(&tuned, .{}, &diagnostics_storage);
    try std.testing.expect(normalized.isValid());
}

const Category = enum { root, torso, tongue, arm, hand, leg, foot, eye, ear, optional_anatomy };

fn expectCategoryCount(source: *const canonical.definition.CanonicalCreatureDefinition, category: Category, expected: usize) !void {
    var count: usize = 0;
    for (source.bones) |bone| if (boneCategory(bone) == category) {
        count += 1;
    };
    try std.testing.expectEqual(expected, count);
}

fn expectOwnedBoneCount(source: *const canonical.definition.CanonicalCreatureDefinition, component_id: []const u8, expected: usize) !void {
    var count: usize = 0;
    for (source.bones) |bone| if (bone.owner_component_id) |owner| {
        if (std.mem.eql(u8, owner.value.bytes, component_id)) count += 1;
    };
    try std.testing.expectEqual(expected, count);
}

fn expectParent(source: *const canonical.definition.CanonicalCreatureDefinition, child_id: []const u8, expected_parent_id: []const u8) !void {
    const child = findBone(source, child_id) orelse return error.MissingBone;
    const parent = child.parent_bone_id orelse return error.MissingParent;
    try std.testing.expectEqualStrings(expected_parent_id, parent.value.bytes);
}

fn expectNear(expected: f32, actual: f32) !void {
    try std.testing.expectApproxEqAbs(expected, actual, tolerance);
}

fn expectMirrored(pair: human_measurements.BilateralCoordinates) !void {
    try expectNear(pair.left.x, -pair.right.x);
    try expectNear(pair.left.y, pair.right.y);
    try expectNear(pair.left.z, pair.right.z);
}

fn expectValidationError(base: *const canonical.definition.CanonicalCreatureDefinition, expected: human_validation.Error, bones: []const canonical.rig.Bone) !void {
    var source = base.*;
    source.bones = bones;
    try std.testing.expectError(expected, human_validation.validatePrompt2B(&source));
}

fn expectRenamedBoneError(base: *const canonical.definition.CanonicalCreatureDefinition, old_id: []const u8, replacement_id: []const u8, expected: human_validation.Error) !void {
    var bones = try human_test_support.dupe(canonical.rig.Bone, base.bones);
    defer std.testing.allocator.free(bones);
    bones[boneIndex(base, old_id).?].bone_id = try identity.BoneId.init(replacement_id);
    try expectValidationError(base, expected, bones);
}

fn findBone(source: *const canonical.definition.CanonicalCreatureDefinition, id: []const u8) ?canonical.rig.Bone {
    for (source.bones) |bone| if (std.mem.eql(u8, bone.bone_id.value.bytes, id)) return bone;
    return null;
}

fn boneIndex(source: *const canonical.definition.CanonicalCreatureDefinition, id: []const u8) ?usize {
    for (source.bones, 0..) |bone, index| {
        if (std.mem.eql(u8, bone.bone_id.value.bytes, id)) return index;
    }
    return null;
}

fn componentIndex(source: *const canonical.definition.CanonicalCreatureDefinition, id: []const u8) ?usize {
    for (source.components, 0..) |record, index| {
        if (std.mem.eql(u8, record.component_id.value.bytes, id)) return index;
    }
    return null;
}

fn findComponent(source: *const canonical.definition.CanonicalCreatureDefinition, id: []const u8) ?canonical.component.Component {
    for (source.components) |record| if (std.mem.eql(u8, record.component_id.value.bytes, id)) return record;
    return null;
}

fn activeBoneCount(source: *const canonical.definition.CanonicalCreatureDefinition) usize {
    var count: usize = 0;
    for (source.bones) |bone| {
        const owner = bone.owner_component_id orelse continue;
        const component = findComponent(source, owner.value.bytes) orelse continue;
        if (component.default_state == .enabled) count += 1;
    }
    return count;
}

fn boneCategory(bone: canonical.rig.Bone) Category {
    if (std.mem.eql(u8, bone.bone_id.value.bytes, "skeleton_root")) return .root;
    if (std.mem.startsWith(u8, bone.bone_id.value.bytes, "clavicle_") or
        std.mem.startsWith(u8, bone.bone_id.value.bytes, "scapula_") or
        std.mem.eql(u8, bone.bone_id.value.bytes, "hand_left") or
        std.mem.eql(u8, bone.bone_id.value.bytes, "hand_right")) return .arm;
    const owner = bone.owner_component_id.?.value.bytes;
    if (std.mem.eql(u8, owner, "penis_module_01")) return .optional_anatomy;
    if (std.mem.eql(u8, owner, "tongue")) return .tongue;
    if (std.mem.startsWith(u8, owner, "arm_")) return .arm;
    if (std.mem.startsWith(u8, owner, "hand_")) return .hand;
    if (std.mem.startsWith(u8, owner, "leg_")) return .leg;
    if (std.mem.startsWith(u8, owner, "foot_")) return .foot;
    if (std.mem.startsWith(u8, owner, "eye_")) return .eye;
    if (std.mem.startsWith(u8, owner, "ear_")) return .ear;
    return .torso;
}

fn distance(a: math3d.Vec3, b: math3d.Vec3) f32 {
    const x = a.x - b.x;
    const y = a.y - b.y;
    const z = a.z - b.z;
    return @sqrt(x * x + y * y + z * z);
}
