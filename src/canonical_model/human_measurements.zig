const std = @import("std");
const definition = @import("definition.zig");
const human_rig = @import("human_rig.zig");
const math3d = @import("math3d.zig");

pub const Error = error{
    InvalidBoneCount,
    MissingBone,
    MissingAnchor,
    MissingParentBone,
    HierarchyCycle,
    MissingDisplayLength,
    BilateralMirrorMismatch,
    NoSpaceLeft,
    UnsupportedAnchorDriver,
};

pub const GlobalPose = struct {
    transforms: [human_rig.bone_count]math3d.AffineTransform,

    pub fn transformFor(
        self: *const GlobalPose,
        source: *const definition.CanonicalCreatureDefinition,
        bone_id: []const u8,
    ) Error!math3d.AffineTransform {
        const index = findBoneIndex(source, bone_id) orelse return error.MissingBone;
        return self.transforms[index];
    }
};

pub const BilateralCoordinates = struct {
    left: math3d.Vec3,
    right: math3d.Vec3,
};

pub const KeyJointCoordinates = struct {
    shoulders: BilateralCoordinates,
    elbows: BilateralCoordinates,
    wrists: BilateralCoordinates,
    hips: BilateralCoordinates,
    knees: BilateralCoordinates,
    ankles: BilateralCoordinates,
    eyes: BilateralCoordinates,
    ears: BilateralCoordinates,
    heel_contacts: BilateralCoordinates,
    big_toe_tips: BilateralCoordinates,
    jaw: math3d.Vec3,
    head_top: math3d.Vec3,
};

pub const MeasurementReport = struct {
    total_height_m: f32,
    shoulder_breadth_m: f32,
    hip_breadth_m: f32,
    arm_span_m: f32,
    torso_length_m: f32,
    leg_length_m: f32,
    upper_arm_length_m: f32,
    forearm_length_m: f32,
    thigh_length_m: f32,
    lower_leg_length_m: f32,
    hand_length_m: f32,
    foot_length_m: f32,
    head_height_m: f32,
    key_joints: KeyJointCoordinates,
};

pub fn deriveGlobalPose(source: *const definition.CanonicalCreatureDefinition) Error!GlobalPose {
    if (source.bones.len != human_rig.bone_count) return error.InvalidBoneCount;
    var pose: GlobalPose = undefined;
    var states = [_]u2{0} ** human_rig.bone_count;
    for (source.bones, 0..) |_, index| try deriveOne(source, index, &pose, &states);
    return pose;
}

pub fn generate(source: *const definition.CanonicalCreatureDefinition) Error!MeasurementReport {
    const pose = try deriveGlobalPose(source);
    const head = try pose.transformFor(source, "head");
    const jaw = try pose.transformFor(source, "jaw");
    const pelvis = try positionFor(&pose, source, "pelvis");
    const neck_01 = try positionFor(&pose, source, "neck_01");

    const head_length = source.bones[findBoneIndex(source, "head") orelse return error.MissingBone].display_length_m orelse return error.MissingDisplayLength;
    const jaw_length = source.bones[findBoneIndex(source, "jaw") orelse return error.MissingBone].display_length_m orelse return error.MissingDisplayLength;
    const head_top = head.transformPoint(.{ .x = 0, .y = head_length, .z = 0 });
    const jaw_bottom = jaw.transformPoint(.{ .x = 0, .y = -jaw_length, .z = 0 });
    const shoulders = try pairedPositions(&pose, source, "upper_arm");
    const elbows = try pairedPositions(&pose, source, "forearm");
    const wrists = try pairedPositions(&pose, source, "hand");
    const hips = try pairedPositions(&pose, source, "thigh");
    const knees = try pairedPositions(&pose, source, "lower_leg");
    const ankles = try pairedPositions(&pose, source, "ankle");
    const eyes = try pairedPositionsWithSuffix(&pose, source, "eyeball", "_01");
    const ears = try pairedPositionsWithSuffix(&pose, source, "ear_root", "_01");
    const heel_contacts: BilateralCoordinates = .{
        .left = try heelContact(&pose, source, "left"),
        .right = try heelContact(&pose, source, "right"),
    };
    const big_toe_tips: BilateralCoordinates = .{
        .left = try bigToeTip(&pose, source, "left"),
        .right = try bigToeTip(&pose, source, "right"),
    };
    const middle_fingertips: BilateralCoordinates = .{
        .left = try fingerTip(&pose, source, "middle", "left"),
        .right = try fingerTip(&pose, source, "middle", "right"),
    };

    return .{
        .total_height_m = head_top.y,
        .shoulder_breadth_m = distance(shoulders.left, shoulders.right),
        .hip_breadth_m = distance(hips.left, hips.right),
        .arm_span_m = distance(middle_fingertips.left, middle_fingertips.right),
        .torso_length_m = distance(pelvis, neck_01),
        .leg_length_m = (hips.left.y + hips.right.y) * 0.5,
        .upper_arm_length_m = distance(shoulders.left, elbows.left),
        .forearm_length_m = distance(elbows.left, wrists.left),
        .thigh_length_m = distance(hips.left, knees.left),
        .lower_leg_length_m = distance(knees.left, ankles.left),
        .hand_length_m = distance(wrists.left, middle_fingertips.left),
        .foot_length_m = distance(heel_contacts.left, big_toe_tips.left),
        .head_height_m = head_top.y - jaw_bottom.y,
        .key_joints = .{
            .shoulders = shoulders,
            .elbows = elbows,
            .wrists = wrists,
            .hips = hips,
            .knees = knees,
            .ankles = ankles,
            .eyes = eyes,
            .ears = ears,
            .heel_contacts = heel_contacts,
            .big_toe_tips = big_toe_tips,
            .jaw = jaw.translation_m,
            .head_top = head_top,
        },
    };
}

pub fn validateSymmetry(
    source: *const definition.CanonicalCreatureDefinition,
    tolerance: f32,
) Error!void {
    const pose = try deriveGlobalPose(source);
    for (source.bones, 0..) |bone, bone_index| {
        const mirror_id = bone.mirror_bone_id orelse continue;
        const mirror_index = findBoneIndex(source, mirror_id.value.bytes) orelse return error.MissingBone;
        const mirror = source.bones[mirror_index];
        const reciprocal_id = mirror.mirror_bone_id orelse return error.BilateralMirrorMismatch;
        if (!reciprocal_id.eql(bone.bone_id) or
            !localTransformsMirror(bone.local_rest_transform, mirror.local_rest_transform, tolerance) or
            !affineTransformsMirror(pose.transforms[bone_index], pose.transforms[mirror_index], tolerance))
        {
            return error.BilateralMirrorMismatch;
        }
    }
}

fn deriveOne(
    source: *const definition.CanonicalCreatureDefinition,
    index: usize,
    pose: *GlobalPose,
    states: *[human_rig.bone_count]u2,
) Error!void {
    if (states[index] == 2) return;
    if (states[index] == 1) return error.HierarchyCycle;
    states[index] = 1;
    const bone = source.bones[index];
    const local = math3d.AffineTransform.fromLocal(bone.local_rest_transform);
    if (bone.parent_bone_id) |parent_id| {
        const parent_index = findBoneIndex(source, parent_id.value.bytes) orelse return error.MissingParentBone;
        try deriveOne(source, parent_index, pose, states);
        pose.transforms[index] = math3d.AffineTransform.compose(pose.transforms[parent_index], local);
    } else {
        pose.transforms[index] = local;
    }
    states[index] = 2;
}

fn pairedPositions(
    pose: *const GlobalPose,
    source: *const definition.CanonicalCreatureDefinition,
    prefix: []const u8,
) Error!BilateralCoordinates {
    var left_buffer: [64]u8 = undefined;
    var right_buffer: [64]u8 = undefined;
    return .{
        .left = try positionFor(pose, source, try std.fmt.bufPrint(&left_buffer, "{s}_left", .{prefix})),
        .right = try positionFor(pose, source, try std.fmt.bufPrint(&right_buffer, "{s}_right", .{prefix})),
    };
}

fn pairedPositionsWithSuffix(
    pose: *const GlobalPose,
    source: *const definition.CanonicalCreatureDefinition,
    prefix: []const u8,
    suffix: []const u8,
) Error!BilateralCoordinates {
    var left_buffer: [64]u8 = undefined;
    var right_buffer: [64]u8 = undefined;
    return .{
        .left = try positionFor(pose, source, try std.fmt.bufPrint(&left_buffer, "{s}_left{s}", .{ prefix, suffix })),
        .right = try positionFor(pose, source, try std.fmt.bufPrint(&right_buffer, "{s}_right{s}", .{ prefix, suffix })),
    };
}

fn positionFor(
    pose: *const GlobalPose,
    source: *const definition.CanonicalCreatureDefinition,
    bone_id: []const u8,
) Error!math3d.Vec3 {
    return (try pose.transformFor(source, bone_id)).translation_m;
}

fn fingerTip(
    pose: *const GlobalPose,
    source: *const definition.CanonicalCreatureDefinition,
    finger: []const u8,
    side: []const u8,
) Error!math3d.Vec3 {
    var id_buffer: [64]u8 = undefined;
    const bone_id = try std.fmt.bufPrint(&id_buffer, "{s}_distal_{s}", .{ finger, side });
    const transform = try pose.transformFor(source, bone_id);
    const bone = source.bones[findBoneIndex(source, bone_id).?];
    const length = bone.display_length_m orelse return error.MissingDisplayLength;
    const sign: f32 = if (std.mem.eql(u8, side, "left")) -1 else 1;
    return transform.transformPoint(.{ .x = sign * length, .y = 0, .z = 0 });
}

fn bigToeTip(
    pose: *const GlobalPose,
    source: *const definition.CanonicalCreatureDefinition,
    side: []const u8,
) Error!math3d.Vec3 {
    var id_buffer: [64]u8 = undefined;
    const bone_id = try std.fmt.bufPrint(&id_buffer, "toe_big_{s}_02", .{side});
    const transform = try pose.transformFor(source, bone_id);
    const bone = source.bones[findBoneIndex(source, bone_id).?];
    const length = bone.display_length_m orelse return error.MissingDisplayLength;
    return transform.transformPoint(.{ .x = 0, .y = 0, .z = length });
}

fn heelContact(
    pose: *const GlobalPose,
    source: *const definition.CanonicalCreatureDefinition,
    side: []const u8,
) Error!math3d.Vec3 {
    var id_buffer: [64]u8 = undefined;
    return anchorPosition(pose, source, try std.fmt.bufPrint(&id_buffer, "heel_contact_{s}_anchor", .{side}));
}

fn anchorPosition(
    pose: *const GlobalPose,
    source: *const definition.CanonicalCreatureDefinition,
    anchor_id: []const u8,
) Error!math3d.Vec3 {
    for (source.anchors) |anchor| {
        if (!std.mem.eql(u8, anchor.anchor_id.value.bytes, anchor_id)) continue;
        const driver = switch (anchor.driver) {
            .bone => |bone_id| try pose.transformFor(source, bone_id.value.bytes),
            else => return error.UnsupportedAnchorDriver,
        };
        return math3d.AffineTransform.compose(driver, math3d.AffineTransform.fromLocal(anchor.local_transform)).translation_m;
    }
    return error.MissingAnchor;
}

fn localTransformsMirror(
    left: math3d.LocalTransform,
    right: math3d.LocalTransform,
    tolerance: f32,
) bool {
    return near(left.translation_m.x, -right.translation_m.x, tolerance) and
        near(left.translation_m.y, right.translation_m.y, tolerance) and
        near(left.translation_m.z, right.translation_m.z, tolerance) and
        near(left.rotation.x, right.rotation.x, tolerance) and
        near(left.rotation.y, -right.rotation.y, tolerance) and
        near(left.rotation.z, -right.rotation.z, tolerance) and
        near(left.rotation.w, right.rotation.w, tolerance) and
        vecNear(left.scale, right.scale, tolerance);
}

fn affineTransformsMirror(
    left: math3d.AffineTransform,
    right: math3d.AffineTransform,
    tolerance: f32,
) bool {
    return near(left.translation_m.x, -right.translation_m.x, tolerance) and
        near(left.translation_m.y, right.translation_m.y, tolerance) and
        near(left.translation_m.z, right.translation_m.z, tolerance) and
        near(left.x_axis.x, right.x_axis.x, tolerance) and
        near(left.x_axis.y, -right.x_axis.y, tolerance) and
        near(left.x_axis.z, -right.x_axis.z, tolerance) and
        near(left.y_axis.x, -right.y_axis.x, tolerance) and
        near(left.y_axis.y, right.y_axis.y, tolerance) and
        near(left.y_axis.z, right.y_axis.z, tolerance) and
        near(left.z_axis.x, -right.z_axis.x, tolerance) and
        near(left.z_axis.y, right.z_axis.y, tolerance) and
        near(left.z_axis.z, right.z_axis.z, tolerance);
}

fn vecNear(a: math3d.Vec3, b: math3d.Vec3, tolerance: f32) bool {
    return near(a.x, b.x, tolerance) and near(a.y, b.y, tolerance) and near(a.z, b.z, tolerance);
}

fn near(a: f32, b: f32, tolerance: f32) bool {
    return @abs(a - b) <= tolerance;
}

fn distance(a: math3d.Vec3, b: math3d.Vec3) f32 {
    const x = a.x - b.x;
    const y = a.y - b.y;
    const z = a.z - b.z;
    return @sqrt(x * x + y * y + z * z);
}

fn findBoneIndex(source: *const definition.CanonicalCreatureDefinition, bone_id: []const u8) ?usize {
    for (source.bones, 0..) |bone, index| {
        if (std.mem.eql(u8, bone.bone_id.value.bytes, bone_id)) return index;
    }
    return null;
}
