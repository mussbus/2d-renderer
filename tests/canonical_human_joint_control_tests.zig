const std = @import("std");
const canonical = @import("canonical_model");

const diagnostics = canonical.diagnostics;
const human_base = canonical.human_base;
const human_controls = canonical.human_controls;
const human_joint_control_validation = canonical.human_joint_control_validation;
const human_joints = canonical.human_joints;
const identity = canonical.identity;
const normalization = canonical.normalization;
const parsing = canonical.parsing;
const serialization = canonical.serialization;
const validation = canonical.validation;

test "Prompt 2C human joints and controls validate and round-trip canonically" {
    try human_joint_control_validation.validatePrompt2C(&human_base.source);
    var diagnostic_storage: [512]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(&human_base.source, .{}, &diagnostic_storage);
    try std.testing.expect(normalized.isValid());
    const canonical_bytes = try serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(canonical_bytes);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "\"mirror_joint_id\":\"upper_arm_right_joint\"") != null);

    var parsed = try parsing.parse(std.testing.allocator, canonical_bytes);
    defer parsed.deinit();
    try human_joint_control_validation.validatePrompt2C(&parsed.value);
    var round_trip_diagnostics: [512]diagnostics.Diagnostic = undefined;
    const round_trip = try normalization.normalize(&parsed.value, .{}, &round_trip_diagnostics);
    try std.testing.expect(round_trip.isValid());
    const round_trip_bytes = try serialization.serializeAlloc(std.testing.allocator, round_trip.normalized.?);
    defer std.testing.allocator.free(round_trip_bytes);
    try std.testing.expectEqualStrings(canonical_bytes, round_trip_bytes);
}

test "Prompt 2C joint inventory covers every non-root bone with typed mirrors" {
    try std.testing.expectEqual(@as(usize, 148), human_joints.joint_count);
    try std.testing.expectEqual(human_joints.joint_count, human_base.source.joints.len);
    try std.testing.expectEqual(@as(usize, 21), human_joints.mobility_profiles.len);
    for (human_base.source.bones) |bone| {
        if (bone.parent_bone_id == null) continue;
        const joint_id = try std.fmt.allocPrint(std.testing.allocator, "{s}_joint", .{bone.bone_id.value.bytes});
        defer std.testing.allocator.free(joint_id);
        const joint = findJoint(joint_id) orelse return error.MissingJoint;
        try std.testing.expect(joint.child_bone_id.eql(bone.bone_id));
        try std.testing.expect(joint.parent_bone_id.eql(bone.parent_bone_id.?));
        try std.testing.expect(joint.mobility_profile_override != null);
        if (bone.mirror_bone_id) |mirror_bone_id| {
            try std.testing.expect(joint.mirror_joint_id != null);
            const expected_mirror = try std.fmt.allocPrint(std.testing.allocator, "{s}_joint", .{mirror_bone_id.value.bytes});
            defer std.testing.allocator.free(expected_mirror);
            try std.testing.expectEqualStrings(expected_mirror, joint.mirror_joint_id.?.value.bytes);
        }
    }
    try std.testing.expectEqual(canonical.rig.JointType.twist, findJoint("upper_arm_twist_left_01_joint").?.joint_type);
    try std.testing.expectEqualStrings("upper_arm_left", findJoint("forearm_left_joint").?.parent_bone_id.value.bytes);
}

test "Prompt 2C provisional ROM profiles are finite ordered and bounded" {
    for (human_joints.mobility_profiles) |profile| {
        try std.testing.expect(profile.profile_id.len != 0);
        try std.testing.expect(std.math.isFinite(profile.stiffness));
        try std.testing.expect(profile.stiffness >= 0 and profile.stiffness <= 1);
        try expectAxisFiniteAndOrdered(profile.preferred_range);
        try expectAxisFiniteAndOrdered(profile.hard_range);
        try expectPreferredInsideHard(profile.preferred_range, profile.hard_range);
        if (profile.swing_twist) |limits| {
            try expectRangeFiniteAndOrdered(limits.swing_y_radians);
            try expectRangeFiniteAndOrdered(limits.swing_z_radians);
            try expectRangeFiniteAndOrdered(limits.twist_radians);
        }
    }
}

test "Prompt 2C canonical joint angles are radians and survive serialization" {
    const shoulder = findJoint("upper_arm_left_joint").?;
    try expectRangeRadians(shoulder.preferred_range.x.?, -std.math.pi / 4.0, std.math.pi / 2.0);
    try expectRangeRadians(shoulder.hard_range.x.?, -std.math.pi / 2.0, 5.0 * std.math.pi / 6.0);
    try expectRangeRadians(shoulder.swing_twist.?.twist_radians, -11.0 * std.math.pi / 36.0, 11.0 * std.math.pi / 36.0);

    const elbow = findJoint("forearm_left_joint").?;
    try expectRangeRadians(elbow.preferred_range.z.?, 0, 2.0 * std.math.pi / 3.0);
    try expectRangeRadians(elbow.hard_range.z.?, -std.math.pi / 36.0, 5.0 * std.math.pi / 6.0);

    const hip = findJoint("thigh_left_joint").?;
    try expectRangeRadians(hip.preferred_range.x.?, -std.math.pi / 6.0, std.math.pi / 3.0);
    try expectRangeRadians(hip.hard_range.x.?, -std.math.pi / 3.0, 2.0 * std.math.pi / 3.0);

    const knee = findJoint("lower_leg_left_joint").?;
    try expectRangeRadians(knee.preferred_range.x.?, 0, 2.0 * std.math.pi / 3.0);
    try expectRangeRadians(knee.hard_range.x.?, -std.math.pi / 36.0, 5.0 * std.math.pi / 6.0);

    const eye = findJoint("eyeball_left_01_joint").?;
    try expectRangeRadians(eye.preferred_range.x.?, -5.0 * std.math.pi / 36.0, 5.0 * std.math.pi / 36.0);
    try expectRangeRadians(eye.hard_range.x.?, -std.math.pi / 4.0, std.math.pi / 4.0);
    try expectRangeRadians(eye.swing_twist.?.twist_radians, -std.math.pi / 12.0, std.math.pi / 12.0);

    const twist = findJoint("upper_arm_twist_left_01_joint").?;
    try std.testing.expect(twist.preferred_range.x == null and twist.preferred_range.y == null and twist.preferred_range.z == null);
    try std.testing.expect(twist.hard_range.x == null and twist.hard_range.y == null and twist.hard_range.z == null);
    try expectRangeRadians(twist.swing_twist.?.swing_y_radians, -std.math.pi / 60.0, std.math.pi / 60.0);
    try expectRangeRadians(twist.swing_twist.?.twist_radians, -7.0 * std.math.pi / 36.0, 7.0 * std.math.pi / 36.0);

    // Review output is derived from canonical radians; no degree-valued joint
    // record or second authoritative degree table is retained.
    try expectReviewDegrees(shoulder.hard_range.x.?.maximum_radians, 150);
    try expectReviewDegrees(elbow.preferred_range.z.?.maximum_radians, 120);
    try expectReviewDegrees(hip.hard_range.x.?.maximum_radians, 120);
    try expectReviewDegrees(knee.hard_range.x.?.maximum_radians, 150);
    try expectReviewDegrees(eye.preferred_range.x.?.maximum_radians, 25);
    try expectReviewDegrees(twist.swing_twist.?.swing_y_radians.maximum_radians, 3);

    var diagnostic_storage: [512]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(&human_base.source, .{}, &diagnostic_storage);
    try std.testing.expect(normalized.isValid());
    const bytes = try serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(bytes);
    var parsed = try parsing.parse(std.testing.allocator, bytes);
    defer parsed.deinit();

    const parsed_shoulder = findJointIn(parsed.value.joints, "upper_arm_left_joint").?;
    const parsed_elbow = findJointIn(parsed.value.joints, "forearm_left_joint").?;
    const parsed_hip = findJointIn(parsed.value.joints, "thigh_left_joint").?;
    const parsed_knee = findJointIn(parsed.value.joints, "lower_leg_left_joint").?;
    const parsed_eye = findJointIn(parsed.value.joints, "eyeball_left_01_joint").?;
    const parsed_twist = findJointIn(parsed.value.joints, "upper_arm_twist_left_01_joint").?;
    try expectRangeEqualAfterRoundTrip(shoulder.hard_range.x.?, parsed_shoulder.hard_range.x.?);
    try expectRangeEqualAfterRoundTrip(elbow.preferred_range.z.?, parsed_elbow.preferred_range.z.?);
    try expectRangeEqualAfterRoundTrip(hip.hard_range.x.?, parsed_hip.hard_range.x.?);
    try expectRangeEqualAfterRoundTrip(knee.hard_range.x.?, parsed_knee.hard_range.x.?);
    try expectRangeEqualAfterRoundTrip(eye.swing_twist.?.twist_radians, parsed_eye.swing_twist.?.twist_radians);
    try expectRangeEqualAfterRoundTrip(twist.swing_twist.?.swing_y_radians, parsed_twist.swing_twist.?.swing_y_radians);

    std.debug.print(
        "PROMPT2C_RADIAN shoulder_hard_x_max={d:.8} elbow_preferred_z_max={d:.8} hip_hard_x_max={d:.8} knee_hard_x_max={d:.8} eye_twist_max={d:.8} twist_swing_y_max={d:.8}\n",
        .{
            shoulder.hard_range.x.?.maximum_radians,
            elbow.preferred_range.z.?.maximum_radians,
            hip.hard_range.x.?.maximum_radians,
            knee.hard_range.x.?.maximum_radians,
            eye.swing_twist.?.twist_radians.maximum_radians,
            twist.swing_twist.?.swing_y_radians.maximum_radians,
        },
    );
}

test "Prompt 2C control inventory covers every approved body area" {
    try std.testing.expectEqual(@as(usize, 116), human_controls.control_count);
    try std.testing.expectEqual(human_controls.control_count, human_base.source.controls.len);
    try expectAreaCount(.spine, 5);
    try expectAreaCount(.pelvis_root, 8);
    try expectAreaCount(.head_jaw, 3);
    try expectAreaCount(.arm, 14);
    try expectAreaCount(.hand, 52);
    try expectAreaCount(.leg_foot, 24);
    try expectAreaCount(.eyes_eyelids, 7);
    try expectAreaCount(.tongue, 2);
    try expectAreaCount(.optional_anatomy, 1);

    inline for (.{
        "spine_lower_control",
        "spine_mid_control",
        "spine_chest_control",
        "spine_upper_chest_control",
        "spine_curve_control",
        "pelvis_figure_eight_control",
        "hand_left_ik_target",
        "elbow_right_pole_control",
        "hand_left_pinch_control",
        "foot_right_ik_target",
        "eyes_shared_look_target",
        "eyelids_blink_control",
        "tongue_curve_control",
        "penis_curve_control",
    }) |control_id| try std.testing.expect(human_controls.findControl(&human_base.source, control_id) != null);
    for (human_base.source.controls) |control| try std.testing.expect(control.control_type != .procedural_grasp);
    try std.testing.expectEqual(@as(f32, 0), human_controls.findControl(&human_base.source, "eyelids_blink_control").?.default_value.?.scalar);
    try std.testing.expectEqual(@as(f32, 0), human_controls.findControl(&human_base.source, "hand_left_pinch_control").?.default_value.?.scalar);
    try std.testing.expectEqual(@as(f32, 0.5), human_controls.findControl(&human_base.source, "finger_left_spread_control").?.default_value.?.scalar);
}

test "Prompt 2C neutral structural controls default to local or character space" {
    try expectControlSpaceCount(.local, 102);
    try expectControlSpaceCount(.character, 14);
    try expectControlSpaceCount(.world, 0);
    try expectControlSpaceCount(.target_relative, 0);

    try expectControlSpace("upper_arm_left_fk_control", .local);
    try expectControlSpace("finger_left_spread_control", .local);
    try expectControlSpace("hand_left_ik_target", .character);
    try expectControlSpace("foot_right_ik_target", .character);
    try expectControlSpace("elbow_left_pole_control", .character);
    try expectControlSpace("knee_right_pole_control", .character);
    try expectControlSpace("eyes_shared_look_target", .character);
    try expectControlSpace("eye_left_look_override", .character);
    try expectControlSpace("pelvis_translation_control", .character);

    std.debug.print("PROMPT2C_CONTROL_SPACES local=102 character=14 world=0 target_relative=0\n", .{});
}

test "Prompt 2C deterministic traces are stable-ID ordered and complete" {
    var first_storage: [human_controls.trace_count]human_controls.TraceEntry = undefined;
    var second_storage: [human_controls.trace_count]human_controls.TraceEntry = undefined;
    const first = try human_controls.generateTraces(&first_storage);
    const second = try human_controls.generateTraces(&second_storage);
    try std.testing.expectEqual(@as(usize, 313), first.len);
    try std.testing.expectEqual(first.len, second.len);
    for (first, second, 0..) |a, b, index| {
        try expectTraceEqual(a, b);
        if (index != 0) {
            const order = std.mem.order(u8, first[index - 1].control_id, a.control_id);
            try std.testing.expect(order == .lt or order == .eq);
        }
    }
    const hand_ik = findTrace(first, "hand_left_ik_target", "hand_left") orelse return error.MissingTrace;
    try std.testing.expectEqual(human_controls.TargetKind.bone, hand_ik.target_kind);
    try std.testing.expectEqualStrings("hand_left_joint", hand_ik.relevant_joint_id.?);
    try std.testing.expectEqualStrings("hand_right_ik_target", hand_ik.mirror_control_id.?);
    try std.testing.expectEqual(canonical.rig.ControlSpace.character, hand_ik.space);
    const spine = findTrace(first, "spine_curve_control", "spine_07_joint") orelse return error.MissingTrace;
    try std.testing.expectEqual(human_controls.TargetKind.joint, spine.target_kind);
    try std.testing.expectEqualStrings("owner_approved_m02_prompt_2c_manifest", spine.provenance);
    std.debug.print(
        "PROMPT2C_TRACE control={s} target={s}:{s} mirror={s} space={s} relevant_joint={s} provenance={s}\n",
        .{
            hand_ik.control_id,
            @tagName(hand_ik.target_kind),
            hand_ik.target_id,
            hand_ik.mirror_control_id.?,
            @tagName(hand_ik.space),
            hand_ik.relevant_joint_id.?,
            hand_ik.provenance,
        },
    );
}

test "Prompt 2C optional structural control follows component activation" {
    try std.testing.expectEqual(@as(usize, 115), human_controls.activeControlCount(&human_base.source));
    try std.testing.expect(!human_controls.controlIsActive(&human_base.source, "penis_curve_control"));
    var components = human_base.components;
    components[componentIndex("penis_module_01").?].default_state = .enabled;
    var source = human_base.source;
    source.components = &components;
    try std.testing.expectEqual(@as(usize, 116), human_controls.activeControlCount(&source));
    try std.testing.expect(human_controls.controlIsActive(&source, "penis_curve_control"));
}

test "Prompt 2C validator distinguishes joint range and hierarchy defects" {
    var joints = human_base.joints;
    const spine_index = jointIndex("spine_01_joint").?;
    var preferred = joints[spine_index].preferred_range.x.?;
    preferred.maximum_radians = joints[spine_index].hard_range.x.?.maximum_radians + 0.1;
    joints[spine_index].preferred_range.x = preferred;
    try expectJointError(error.PreferredRangeOutsideHardRange, &joints);

    joints = human_base.joints;
    joints[jointIndex("upper_arm_left_joint").?].swing_twist = null;
    try expectJointError(error.MalformedSwingTwist, &joints);

    joints = human_base.joints;
    const jaw_index = jointIndex("jaw_joint").?;
    preferred = joints[jaw_index].preferred_range.x.?;
    preferred.minimum_radians = std.math.nan(f32);
    joints[jaw_index].preferred_range.x = preferred;
    try expectJointError(error.NonFiniteJointRange, &joints);

    joints = human_base.joints;
    const knee_index = jointIndex("lower_leg_left_joint").?;
    var hard = joints[knee_index].hard_range.x.?;
    hard.minimum_radians = hard.maximum_radians + 0.1;
    joints[knee_index].hard_range.x = hard;
    try expectJointError(error.ReversedJointRange, &joints);

    joints = human_base.joints;
    joints[jaw_index].parent_bone_id = try identity.BoneId.init("pelvis");
    try expectJointError(error.IncompatibleJointBones, &joints);

    joints = human_base.joints;
    joints[jointIndex("upper_arm_left_joint").?].mirror_joint_id = null;
    try expectJointError(error.MissingJointMirrorPartner, &joints);
}

test "Prompt 2C validator distinguishes control drive and mirror defects" {
    var controls = human_base.controls;
    controls[0].driven_targets = controls[0].driven_targets[0..1];
    try expectControlError(error.MissingDrivenTarget, &controls);

    controls = human_base.controls;
    var targets = human_controls.target_storage[0];
    targets[0] = .{ .bone = try identity.BoneId.init("spine_01_joint") };
    controls[0].driven_targets = targets[0..2];
    try expectControlError(error.WrongDrivenTargetType, &controls);

    controls = human_base.controls;
    targets = human_controls.target_storage[0];
    targets[0] = .{ .constraint = try identity.ConstraintId.init("disallowed_control_constraint") };
    controls[0].driven_targets = targets[0..2];
    try expectControlError(error.DisallowedDrivenTarget, &controls);

    controls = human_base.controls;
    controls[1].control_id = controls[0].control_id;
    try expectControlError(error.DuplicateStructuralControlOwnership, &controls);

    controls = human_base.controls;
    controls[controlIndex("hand_left_ik_target").?].mirror_control_id = null;
    try expectControlError(error.MissingControlMirrorPartner, &controls);

    controls = human_base.controls;
    controls[controlIndex("spine_lower_control").?].control_id = try identity.ControlId.init("renamed_spine_control");
    try expectControlError(error.WrongSpineControlCount, &controls);

    controls = human_base.controls;
    controls[controlIndex("hand_left_pinch_control").?].control_type = .procedural_grasp;
    try expectControlError(error.DisallowedDrivenTarget, &controls);
}

test "Prompt 2C parser-backed preferred-range drift retains its diagnostic" {
    var joints = human_base.joints;
    const index = jointIndex("spine_01_joint").?;
    var preferred = joints[index].preferred_range.x.?;
    preferred.maximum_radians = joints[index].hard_range.x.?.maximum_radians + 0.1;
    joints[index].preferred_range.x = preferred;
    var source = human_base.source;
    source.joints = &joints;
    var diagnostic_storage: [512]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(&source, .{}, &diagnostic_storage);
    try std.testing.expect(normalized.isValid());
    const bytes = try serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(bytes);
    var parsed = try parsing.parse(std.testing.allocator, bytes);
    defer parsed.deinit();
    try std.testing.expectError(error.PreferredRangeOutsideHardRange, human_joint_control_validation.validatePrompt2C(&parsed.value));
}

test "typed joint mirrors require schema 1.1 while M01 remains schema 1.0" {
    var source = human_base.source;
    source.schema_identity.version = .{ .major = 1, .minor = 0, .patch = 0 };
    var diagnostic_storage: [512]diagnostics.Diagnostic = undefined;
    const report = try validation.validate(&source, .{}, &diagnostic_storage);
    try std.testing.expect(!report.isValid());
    var found_joint_mirror_version_error = false;
    for (report.diagnostics) |diagnostic| {
        if (diagnostic.code == .schema_feature_version_mismatch and
            std.mem.eql(u8, diagnostic.object_type, "joint") and
            diagnostic.property != null and
            std.mem.eql(u8, diagnostic.property.?, "mirror_joint_id"))
        {
            found_joint_mirror_version_error = true;
        }
    }
    try std.testing.expect(found_joint_mirror_version_error);
}

fn expectJointError(expected: human_joint_control_validation.Error, joints: []const canonical.rig.Joint) !void {
    var source = human_base.source;
    source.joints = joints;
    try std.testing.expectError(expected, human_joint_control_validation.validatePrompt2C(&source));
}

fn expectControlError(expected: human_joint_control_validation.Error, controls: []const canonical.rig.Control) !void {
    var source = human_base.source;
    source.controls = controls;
    try std.testing.expectError(expected, human_joint_control_validation.validatePrompt2C(&source));
}

fn expectAreaCount(area: human_controls.Area, expected: usize) !void {
    var count: usize = 0;
    for (human_controls.control_specs) |spec| if (spec.area == area) {
        count += 1;
    };
    try std.testing.expectEqual(expected, count);
}

fn expectControlSpaceCount(space: canonical.rig.ControlSpace, expected: usize) !void {
    var count: usize = 0;
    for (human_base.source.controls) |control| if (control.space == space) {
        count += 1;
    };
    try std.testing.expectEqual(expected, count);
}

fn expectControlSpace(control_id: []const u8, expected: canonical.rig.ControlSpace) !void {
    const control = human_controls.findControl(&human_base.source, control_id) orelse return error.MissingControl;
    try std.testing.expectEqual(expected, control.space);
}

const angle_tolerance_radians: f32 = 0.000001;

fn expectRangeRadians(range: canonical.rig.AngularRange, minimum: f32, maximum: f32) !void {
    try std.testing.expectApproxEqAbs(minimum, range.minimum_radians, angle_tolerance_radians);
    try std.testing.expectApproxEqAbs(maximum, range.maximum_radians, angle_tolerance_radians);
}

fn expectRangeEqualAfterRoundTrip(expected: canonical.rig.AngularRange, actual: canonical.rig.AngularRange) !void {
    try std.testing.expectApproxEqAbs(expected.minimum_radians, actual.minimum_radians, angle_tolerance_radians);
    try std.testing.expectApproxEqAbs(expected.maximum_radians, actual.maximum_radians, angle_tolerance_radians);
}

fn expectReviewDegrees(canonical_radians: f32, expected_degrees: f32) !void {
    const displayed_degrees = canonical_radians * 180.0 / std.math.pi;
    try std.testing.expectApproxEqAbs(expected_degrees, displayed_degrees, @as(f32, 0.0001));
}

fn expectAxisFiniteAndOrdered(limits: canonical.rig.AxisAngularLimits) !void {
    const ranges = [_]?canonical.rig.AngularRange{ limits.x, limits.y, limits.z };
    for (ranges) |maybe_range| if (maybe_range) |range| try expectRangeFiniteAndOrdered(range);
}

fn expectRangeFiniteAndOrdered(range: canonical.rig.AngularRange) !void {
    try std.testing.expect(std.math.isFinite(range.minimum_radians));
    try std.testing.expect(std.math.isFinite(range.maximum_radians));
    try std.testing.expect(range.minimum_radians <= range.maximum_radians);
}

fn expectPreferredInsideHard(preferred: canonical.rig.AxisAngularLimits, hard: canonical.rig.AxisAngularLimits) !void {
    try expectPreferredAxisInsideHard(preferred.x, hard.x);
    try expectPreferredAxisInsideHard(preferred.y, hard.y);
    try expectPreferredAxisInsideHard(preferred.z, hard.z);
}

fn expectPreferredAxisInsideHard(preferred: ?canonical.rig.AngularRange, hard: ?canonical.rig.AngularRange) !void {
    const preferred_range = preferred orelse return;
    const hard_range = hard orelse return error.MissingHardRange;
    try std.testing.expect(preferred_range.minimum_radians >= hard_range.minimum_radians);
    try std.testing.expect(preferred_range.maximum_radians <= hard_range.maximum_radians);
}

fn expectTraceEqual(a: human_controls.TraceEntry, b: human_controls.TraceEntry) !void {
    try std.testing.expectEqualStrings(a.control_id, b.control_id);
    try std.testing.expectEqualStrings(a.owner_component_id, b.owner_component_id);
    try std.testing.expectEqual(a.area, b.area);
    try std.testing.expectEqual(a.target_kind, b.target_kind);
    try std.testing.expectEqualStrings(a.target_id, b.target_id);
    try expectOptionalStringsEqual(a.mirror_control_id, b.mirror_control_id);
    try std.testing.expectEqual(a.space, b.space);
    try expectOptionalStringsEqual(a.relevant_joint_id, b.relevant_joint_id);
    try std.testing.expectEqualStrings(a.provenance, b.provenance);
}

fn expectOptionalStringsEqual(a: ?[]const u8, b: ?[]const u8) !void {
    try std.testing.expect((a == null) == (b == null));
    if (a) |value| try std.testing.expectEqualStrings(value, b.?);
}

fn findTrace(traces: []const human_controls.TraceEntry, control_id: []const u8, target_id: []const u8) ?human_controls.TraceEntry {
    for (traces) |trace| {
        if (std.mem.eql(u8, trace.control_id, control_id) and std.mem.eql(u8, trace.target_id, target_id)) return trace;
    }
    return null;
}

fn findJoint(id: []const u8) ?canonical.rig.Joint {
    return findJointIn(human_base.source.joints, id);
}

fn findJointIn(joints: []const canonical.rig.Joint, id: []const u8) ?canonical.rig.Joint {
    for (joints) |joint| if (std.mem.eql(u8, joint.joint_id.value.bytes, id)) return joint;
    return null;
}

fn jointIndex(id: []const u8) ?usize {
    for (human_base.source.joints, 0..) |joint, index| {
        if (std.mem.eql(u8, joint.joint_id.value.bytes, id)) return index;
    }
    return null;
}

fn controlIndex(id: []const u8) ?usize {
    for (human_base.source.controls, 0..) |control, index| {
        if (std.mem.eql(u8, control.control_id.value.bytes, id)) return index;
    }
    return null;
}

fn componentIndex(id: []const u8) ?usize {
    for (human_base.source.components, 0..) |component, index| {
        if (std.mem.eql(u8, component.component_id.value.bytes, id)) return index;
    }
    return null;
}
