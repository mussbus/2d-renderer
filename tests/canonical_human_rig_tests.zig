const std = @import("std");
const canonical = @import("canonical_model");

const diagnostics = canonical.diagnostics;
const human_base = canonical.human_base;
const human_measurements = canonical.human_measurements;
const human_rig = canonical.human_rig;
const human_validation = canonical.human_validation;
const identity = canonical.identity;
const math3d = canonical.math3d;
const normalization = canonical.normalization;
const parsing = canonical.parsing;
const serialization = canonical.serialization;

const tolerance = human_rig.measurement_tolerance_m;

test "Prompt 2B human rig validates and round-trips canonically" {
    try human_validation.validatePrompt2A(&human_base.source);
    try human_validation.validatePrompt2B(&human_base.source);

    var diagnostic_storage: [512]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(&human_base.source, .{}, &diagnostic_storage);
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
    try std.testing.expectEqual(human_rig.bone_count, human_base.source.bones.len);
    try std.testing.expectEqual(@as(usize, 149), human_rig.bone_count);
    try std.testing.expectEqual(@as(usize, 140), human_rig.shared_bone_count);
    try std.testing.expectEqual(@as(usize, 9), human_rig.optional_penis_bone_count);
    try std.testing.expectEqual(@as(usize, 142), human_rig.deformation_bone_count);
    try std.testing.expectEqual(@as(usize, 7), human_rig.structural_reference_bone_count);

    try expectCategoryCount(.root, 1);
    try expectCategoryCount(.torso, 13);
    try expectCategoryCount(.tongue, 6);
    try expectCategoryCount(.arm, 18);
    try expectCategoryCount(.hand, 38);
    try expectCategoryCount(.leg, 14);
    try expectCategoryCount(.foot, 34);
    try expectCategoryCount(.eye, 14);
    try expectCategoryCount(.ear, 2);
    try expectCategoryCount(.optional_anatomy, 9);

    var deformation_count: usize = 0;
    var structural_count: usize = 0;
    var root_count: usize = 0;
    for (human_base.source.bones) |bone| {
        if (bone.deforms_mesh) deformation_count += 1 else structural_count += 1;
        if (bone.parent_bone_id == null) root_count += 1;
        try std.testing.expect(bone.owner_component_id != null);
    }
    try std.testing.expectEqual(human_rig.deformation_bone_count, deformation_count);
    try std.testing.expectEqual(human_rig.structural_reference_bone_count, structural_count);
    try std.testing.expectEqual(@as(usize, 1), root_count);
}

test "Prompt 2B hierarchy preserves main chains and auxiliary twist branches" {
    try expectParent("pelvis", "skeleton_root");
    try expectParent("spine_01", "pelvis");
    try expectParent("spine_07", "spine_06");
    try expectParent("neck_01", "spine_07");
    try expectParent("head", "neck_03");
    try expectParent("jaw", "head");
    try expectParent("clavicle_left", "spine_07");
    try expectParent("scapula_left", "clavicle_left");
    try expectParent("upper_arm_left", "scapula_left");
    try expectParent("forearm_left", "upper_arm_left");
    try expectParent("upper_arm_twist_left_01", "upper_arm_left");
    try expectParent("upper_arm_twist_left_02", "upper_arm_twist_left_01");
    try expectParent("hand_left", "forearm_left");
    try expectParent("ankle_left", "lower_leg_left");
    try std.testing.expect(!findBone("ankle_left").?.deforms_mesh);
    try expectParent("foot_left", "ankle_left");
    try expectParent("midfoot_left", "foot_left");
    try expectParent("forefoot_left", "midfoot_left");
    try expectParent("tongue_01", "jaw");
    try expectParent("tongue_branch_point", "tongue_04");
    try std.testing.expect(!findBone("tongue_branch_point").?.deforms_mesh);
    try expectParent("tongue_tip_01", "tongue_branch_point");
    try std.testing.expect(!findBone("tongue_tip_01").?.deforms_mesh);
    try expectParent("eyeball_left_01", "head");
    try expectParent("eyelid_upper_left_center", "head");
    try expectParent("ear_root_right_01", "head");
    try expectParent("penis_root_01", "pelvis");
    try expectParent("penis_shaft_07", "penis_shaft_06");
    try expectParent("penis_tip_01", "penis_shaft_07");
}

test "Prompt 2B ownership and non-bone mouth following are explicit" {
    try expectOwnedBoneCount("body", 1);
    try expectOwnedBoneCount("torso", 11);
    try expectOwnedBoneCount("pelvis", 1);
    try expectOwnedBoneCount("neck", 3);
    try expectOwnedBoneCount("head", 1);
    try expectOwnedBoneCount("mouth", 1);
    try expectOwnedBoneCount("tongue", 6);
    try expectOwnedBoneCount("arm_left_01", 6);
    try expectOwnedBoneCount("arm_right_01", 6);
    try expectOwnedBoneCount("hand_left_01", 20);
    try expectOwnedBoneCount("hand_right_01", 20);
    try expectOwnedBoneCount("leg_left_01", 7);
    try expectOwnedBoneCount("leg_right_01", 7);
    try expectOwnedBoneCount("foot_left_01", 17);
    try expectOwnedBoneCount("foot_right_01", 17);
    try expectOwnedBoneCount("eye_left_01", 7);
    try expectOwnedBoneCount("eye_right_01", 7);
    try expectOwnedBoneCount("ear_left_01", 1);
    try expectOwnedBoneCount("ear_right_01", 1);
    try expectOwnedBoneCount("penis_module_01", 9);

    try expectFollow("mouth", "head");
    try expectFollow("mouth_cavity", "head");
    try expectFollow("teeth_upper", "head");
    try expectFollow("gums_palate_upper", "head");
    try expectFollow("teeth_lower", "jaw");
    try expectFollow("gums_lower", "jaw");
    try expectFollow("tongue", "tongue_01");
}

test "Prompt 2B local A-pose composes into a nontrivial global pose" {
    const pose = try human_measurements.deriveGlobalPose(&human_base.source);
    const shoulder_left = (try pose.transformFor(&human_base.source, "upper_arm_left")).translation_m;
    const shoulder_right = (try pose.transformFor(&human_base.source, "upper_arm_right")).translation_m;
    const elbow_left = (try pose.transformFor(&human_base.source, "forearm_left")).translation_m;
    const elbow_right = (try pose.transformFor(&human_base.source, "forearm_right")).translation_m;
    const wrist_left = (try pose.transformFor(&human_base.source, "hand_left")).translation_m;
    const wrist_right = (try pose.transformFor(&human_base.source, "hand_right")).translation_m;

    try std.testing.expect(elbow_left.x < shoulder_left.x);
    try std.testing.expect(elbow_right.x > shoulder_right.x);
    try std.testing.expect(elbow_left.y < shoulder_left.y);
    try std.testing.expect(elbow_right.y < shoulder_right.y);
    try std.testing.expect(wrist_left.y < elbow_left.y);
    try std.testing.expect(wrist_right.y < elbow_right.y);

    const upper_arm_left = findBone("upper_arm_left").?;
    const forearm_left = findBone("forearm_left").?;
    const expected_forearm = math3d.AffineTransform.compose(
        try pose.transformFor(&human_base.source, upper_arm_left.bone_id.value.bytes),
        math3d.AffineTransform.fromLocal(forearm_left.local_rest_transform),
    );
    try std.testing.expect(std.meta.eql(expected_forearm, try pose.transformFor(&human_base.source, "forearm_left")));
    try std.testing.expect(!std.meta.eql(forearm_left.local_rest_transform.translation_m, elbow_left));
}

test "Prompt 2B measurement report is deterministic and ground-referenced" {
    const first = try human_measurements.generate(&human_base.source);
    const second = try human_measurements.generate(&human_base.source);
    try std.testing.expect(std.meta.eql(first, second));
    try expectNear(1.8288, first.total_height_m);
    try expectNear(0, first.key_joints.heel_contacts.left.y);
    try expectNear(0, first.key_joints.heel_contacts.right.y);
    try expectNear(0, first.key_joints.big_toe_tips.left.y);
    try expectNear(0, first.key_joints.big_toe_tips.right.y);
    try expectNear(human_rig.open_tuning.upper_arm_length_m, first.upper_arm_length_m);
    try expectNear(human_rig.open_tuning.forearm_length_m, first.forearm_length_m);
    try expectNear(human_rig.open_tuning.thigh_length_m, first.thigh_length_m);
    try expectNear(human_rig.open_tuning.lower_leg_length_m, first.lower_leg_length_m);
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
    try human_measurements.validateSymmetry(&human_base.source, human_rig.test_only_symmetry_tolerance);
    const report = try human_measurements.generate(&human_base.source);
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
    var bones = human_base.bones;
    bones[boneIndex("head").?].local_rest_transform.translation_m.y += 0.01;
    var source = human_base.source;
    source.bones = &bones;
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
    try std.testing.expectEqual(human_rig.shared_bone_count, human_rig.activeBoneCount(&human_base.source));
    try human_validation.validatePrompt2BActivation(&human_base.source);

    var enabled_components = human_base.components;
    enabled_components[componentIndex("penis_module_01").?].default_state = .enabled;
    var enabled_source = human_base.source;
    enabled_source.components = &enabled_components;
    try std.testing.expectEqual(human_rig.bone_count, human_rig.activeBoneCount(&enabled_source));
    try human_validation.validatePrompt2BActivation(&enabled_source);
    for (human_base.source.bones[0..human_rig.shared_bone_count], 0..) |bone, index| {
        try std.testing.expectEqualStrings(human_rig.bone_specs[index].bone_id, bone.bone_id.value.bytes);
    }
}

test "Prompt 2B validator reports root pelvis and count defects precisely" {
    var bones = human_base.bones;
    bones[boneIndex("skeleton_root").?].bone_id = try identity.BoneId.init("renamed_root");
    try expectValidationError(error.MissingSkeletonRoot, &bones);

    bones = human_base.bones;
    bones[boneIndex("penis_root_01").?].parent_bone_id = null;
    try expectValidationError(error.MultipleSkeletonRoots, &bones);

    bones = human_base.bones;
    bones[boneIndex("pelvis").?].parent_bone_id = try identity.BoneId.init("head");
    try expectValidationError(error.WrongPelvisParent, &bones);

    try expectRenamedBoneError("spine_07", "renamed_spine", error.WrongSpineCount);
    try expectRenamedBoneError("neck_03", "renamed_neck", error.WrongNeckCount);
    try expectRenamedBoneError("upper_arm_twist_left_02", "renamed_upper_twist", error.WrongUpperArmTwistCount);
    try expectRenamedBoneError("forearm_twist_right_02", "renamed_forearm_twist", error.WrongForearmTwistCount);
    try expectRenamedBoneError("thigh_twist_left_02", "renamed_thigh_twist", error.WrongThighTwistCount);
    try expectRenamedBoneError("lower_leg_twist_right_02", "renamed_lower_leg_twist", error.WrongLowerLegTwistCount);
    try expectRenamedBoneError("eyeball_left_01", "renamed_eye", error.WrongDefaultEyeCount);
    try expectRenamedBoneError("eyelid_upper_left_center", "renamed_lid", error.WrongEyelidCount);
    try expectRenamedBoneError("ear_root_right_01", "renamed_ear", error.WrongDefaultEarCount);
    try expectRenamedBoneError("tongue_04", "renamed_tongue", error.WrongTongueCount);
}

test "Prompt 2B validator rejects malformed chains and ownership activation defects" {
    var bones = human_base.bones;
    bones[boneIndex("index_middle_left").?].parent_bone_id = try identity.BoneId.init("hand_left");
    try expectValidationError(error.MalformedFingerChain, &bones);

    bones = human_base.bones;
    bones[boneIndex("toe_index_right_03").?].parent_bone_id = try identity.BoneId.init("forefoot_right");
    try expectValidationError(error.MalformedToeChain, &bones);

    bones = human_base.bones;
    bones[boneIndex("ear_root_left_01").?].owner_component_id = null;
    try expectValidationError(error.MissingBoneOwner, &bones);

    bones = human_base.bones;
    bones[boneIndex("head").?].owner_component_id = try identity.ComponentId.init("penis_module_01");
    var source = human_base.source;
    source.bones = &bones;
    try std.testing.expectError(error.ActiveChildDependsOnInactiveParent, human_validation.validatePrompt2BActivation(&source));

    bones = human_base.bones;
    bones[boneIndex("ear_root_left_01").?].owner_component_id = try identity.ComponentId.init("penis_module_01");
    source.bones = &bones;
    try std.testing.expectError(error.BoneOwnedByDisabledComponent, human_validation.validatePrompt2BActivation(&source));

    bones = human_base.bones;
    bones[boneIndex("ear_root_left_01").?].bone_id = try identity.BoneId.init("changed_shared_bone_id");
    source.bones = &bones;
    try std.testing.expectError(error.OptionalActivationChangesSharedIds, human_validation.validatePrompt2BActivation(&source));

    var enabled_components = human_base.components;
    enabled_components[componentIndex("penis_module_01").?].default_state = .enabled;
    bones = human_base.bones;
    bones[boneIndex("penis_root_01").?].parent_bone_id = null;
    source = human_base.source;
    source.components = &enabled_components;
    source.bones = &bones;
    try std.testing.expectError(error.OptionalRigCreatesSecondSkeleton, human_validation.validatePrompt2BActivation(&source));
}

test "Prompt 2B validator distinguishes height ground mirror and rest drift" {
    var bones = human_base.bones;
    bones[boneIndex("head").?].local_rest_transform.translation_m.y += 0.01;
    try expectValidationError(error.CanonicalHeightMismatch, &bones);

    bones = human_base.bones;
    bones[boneIndex("foot_left").?].local_rest_transform.translation_m.y += 0.01;
    try expectValidationError(error.GroundReferenceMismatch, &bones);

    bones = human_base.bones;
    bones[boneIndex("upper_arm_left").?].local_rest_transform.rotation = math3d.Quaternion.identity;
    try expectValidationError(error.BilateralMirrorMismatch, &bones);

    bones = human_base.bones;
    bones[boneIndex("jaw").?].local_rest_transform.translation_m.z += 0.001;
    try expectValidationError(error.BoneContractMismatch, &bones);
}

fn expectCategoryCount(category: human_rig.Category, expected: usize) !void {
    try std.testing.expectEqual(expected, human_rig.categoryCount(category));
}

fn expectOwnedBoneCount(component_id: []const u8, expected: usize) !void {
    try std.testing.expectEqual(expected, human_rig.componentOwnedBoneCount(component_id));
}

fn expectFollow(component_id: []const u8, bone_id: []const u8) !void {
    for (human_rig.component_follow_specs) |spec| {
        if (std.mem.eql(u8, spec.component_id, component_id)) {
            try std.testing.expectEqualStrings(bone_id, spec.bone_id);
            try std.testing.expect(findBone(spec.bone_id) != null);
            return;
        }
    }
    return error.MissingFollowSpec;
}

fn expectParent(child_id: []const u8, expected_parent_id: []const u8) !void {
    const child = findBone(child_id) orelse return error.MissingBone;
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

fn expectValidationError(expected: human_validation.Error, bones: []const canonical.rig.Bone) !void {
    var source = human_base.source;
    source.bones = bones;
    try std.testing.expectError(expected, human_validation.validatePrompt2B(&source));
}

fn expectRenamedBoneError(old_id: []const u8, replacement_id: []const u8, expected: human_validation.Error) !void {
    var bones = human_base.bones;
    bones[boneIndex(old_id).?].bone_id = try identity.BoneId.init(replacement_id);
    try expectValidationError(expected, &bones);
}

fn findBone(id: []const u8) ?canonical.rig.Bone {
    for (human_base.source.bones) |bone| if (std.mem.eql(u8, bone.bone_id.value.bytes, id)) return bone;
    return null;
}

fn boneIndex(id: []const u8) ?usize {
    for (human_base.source.bones, 0..) |bone, index| {
        if (std.mem.eql(u8, bone.bone_id.value.bytes, id)) return index;
    }
    return null;
}

fn componentIndex(id: []const u8) ?usize {
    for (human_base.source.components, 0..) |record, index| {
        if (std.mem.eql(u8, record.component_id.value.bytes, id)) return index;
    }
    return null;
}

fn distance(a: math3d.Vec3, b: math3d.Vec3) f32 {
    const x = a.x - b.x;
    const y = a.y - b.y;
    const z = a.z - b.z;
    return @sqrt(x * x + y * y + z * z);
}
