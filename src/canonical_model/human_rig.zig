const std = @import("std");
const definition = @import("definition.zig");
const identity = @import("identity.zig");
const math3d = @import("math3d.zig");
const rig = @import("rig.zig");

pub const bone_count: usize = 149;
pub const shared_bone_count: usize = 140;
pub const optional_penis_bone_count: usize = 9;
pub const deformation_bone_count: usize = 142;
pub const structural_reference_bone_count: usize = 7;

/// Prompt 2B-only f32 mirror comparison tolerance. This is not a universal
/// anatomy tolerance and must not be reused as one by downstream systems.
pub const test_only_symmetry_tolerance: f32 = 1.0e-5;
/// Prompt 2B structural-report tolerance in canonical meters.
pub const measurement_tolerance_m: f32 = 1.0e-5;

pub const Category = enum {
    root,
    torso,
    tongue,
    arm,
    hand,
    leg,
    foot,
    eye,
    ear,
    optional_anatomy,
};

pub const open_tuning = struct {
    pub const pelvis_height_m: f32 = 0.95;
    pub const hip_half_breadth_m: f32 = 0.10;

    pub const spine_01_rise_m: f32 = 0.08;
    pub const spine_segment_rise_m: f32 = 0.07;
    pub const neck_01_rise_m: f32 = 0.06;
    pub const neck_segment_rise_m: f32 = 0.05;
    pub const head_rise_m: f32 = 0.05;
    pub const head_top_offset_m: f32 = 0.1688;
    pub const jaw_drop_m: f32 = 0.10;
    pub const jaw_forward_m: f32 = 0.04;
    pub const jaw_bottom_offset_m: f32 = 0.04;

    pub const clavicle_outset_m: f32 = 0.045;
    pub const clavicle_rise_m: f32 = 0.015;
    pub const scapula_outset_m: f32 = 0.055;
    pub const scapula_drop_m: f32 = 0.015;
    pub const scapula_back_m: f32 = 0.025;
    pub const shoulder_outset_m: f32 = 0.075;
    pub const upper_arm_length_m: f32 = 0.31;
    pub const forearm_length_m: f32 = 0.27;
    pub const upper_arm_a_pose_degrees: f32 = 25.0;
    pub const elbow_a_pose_degrees: f32 = 5.0;

    pub const hand_root_length_m: f32 = 0.03;
    pub const finger_metacarpal_length_m: f32 = 0.04;
    pub const finger_proximal_length_m: f32 = 0.03;
    pub const finger_middle_length_m: f32 = 0.025;
    pub const finger_distal_length_m: f32 = 0.02;
    pub const thumb_metacarpal_length_m: f32 = 0.035;
    pub const thumb_proximal_length_m: f32 = 0.03;
    pub const thumb_distal_length_m: f32 = 0.025;
    pub const thumb_base_outset_m: f32 = 0.015;
    pub const thumb_base_drop_m: f32 = 0.025;
    pub const thumb_base_forward_m: f32 = 0.03;
    pub const finger_spacing_m: f32 = 0.022;

    pub const thigh_length_m: f32 = 0.45;
    pub const lower_leg_length_m: f32 = 0.43;
    pub const ankle_to_foot_drop_m: f32 = 0.04;
    pub const foot_to_midfoot_forward_m: f32 = 0.055;
    pub const foot_to_midfoot_drop_m: f32 = 0.015;
    pub const midfoot_to_forefoot_forward_m: f32 = 0.065;
    pub const midfoot_to_forefoot_drop_m: f32 = 0.015;
    pub const heel_back_offset_m: f32 = 0.055;
    pub const heel_ground_drop_m: f32 = 0.03;
    pub const big_toe_01_length_m: f32 = 0.025;
    pub const big_toe_02_length_m: f32 = 0.035;
    pub const big_toe_tip_length_m: f32 = 0.025;
    pub const lesser_toe_01_length_m: f32 = 0.022;
    pub const lesser_toe_02_length_m: f32 = 0.025;
    pub const lesser_toe_03_length_m: f32 = 0.020;
    pub const lesser_toe_tip_length_m: f32 = 0.015;
    pub const toe_spacing_m: f32 = 0.014;

    pub const eye_half_spacing_m: f32 = 0.032;
    pub const eye_rise_m: f32 = 0.065;
    pub const eye_forward_m: f32 = 0.085;
    pub const eyelid_horizontal_offset_m: f32 = 0.012;
    pub const eyelid_vertical_offset_m: f32 = 0.012;
    pub const eyelid_forward_offset_m: f32 = 0.005;
    pub const eyeball_display_length_m: f32 = 0.024;
    pub const eyelid_display_length_m: f32 = 0.008;
    pub const ear_half_spacing_m: f32 = 0.085;
    pub const ear_rise_m: f32 = 0.04;
    pub const ear_display_length_m: f32 = 0.06;

    pub const tongue_root_drop_m: f32 = 0.015;
    pub const tongue_root_forward_m: f32 = 0.035;
    pub const tongue_segment_length_m: f32 = 0.03;
    pub const tongue_tip_length_m: f32 = 0.02;

    pub const penis_root_drop_m: f32 = 0.03;
    pub const penis_root_forward_m: f32 = 0.10;
    pub const penis_shaft_segment_m: f32 = 0.025;
    pub const penis_tip_reference_m: f32 = 0.02;
};

pub const BoneSpec = struct {
    bone_id: []const u8,
    parent_bone_id: ?[]const u8,
    owner_component_id: []const u8,
    deforms_mesh: bool,
    mirror_bone_id: ?[]const u8,
    local_rest_transform: math3d.LocalTransform,
    display_length_m: ?f32,
    category: Category,
};

pub const ComponentFollowSpec = struct {
    component_id: []const u8,
    bone_id: []const u8,
};

/// Non-bone mouth structures follow these authoritative bones when geometry is
/// attached later. This records following semantics without inventing bones.
pub const component_follow_specs = [_]ComponentFollowSpec{
    .{ .component_id = "mouth", .bone_id = "head" },
    .{ .component_id = "mouth_cavity", .bone_id = "head" },
    .{ .component_id = "teeth_upper", .bone_id = "head" },
    .{ .component_id = "gums_palate_upper", .bone_id = "head" },
    .{ .component_id = "teeth_lower", .bone_id = "jaw" },
    .{ .component_id = "gums_lower", .bone_id = "jaw" },
    .{ .component_id = "tongue", .bone_id = "tongue_01" },
};

const root_tags = makeIds(identity.SemanticTagId, &.{ "human", "root" });
const torso_tags = makeIds(identity.SemanticTagId, &.{ "human", "torso_rig" });
const tongue_tags = makeIds(identity.SemanticTagId, &.{ "human", "tongue_rig" });
const left_tags = makeIds(identity.SemanticTagId, &.{ "human", "left" });
const right_tags = makeIds(identity.SemanticTagId, &.{ "human", "right" });
const optional_tags = makeIds(identity.SemanticTagId, &.{ "human", "optional_anatomy" });

pub const bone_specs = buildBoneSpecs();
pub const bones = buildBones();

pub fn categoryCount(category: Category) usize {
    var count: usize = 0;
    for (bone_specs) |spec| if (spec.category == category) {
        count += 1;
    };
    return count;
}

pub fn boneIsActive(
    source: *const definition.CanonicalCreatureDefinition,
    bone: rig.Bone,
) bool {
    const owner = bone.owner_component_id orelse return false;
    for (source.components) |record| {
        if (record.component_id.eql(owner)) return record.default_state == .enabled;
    }
    return false;
}

pub fn activeBoneCount(source: *const definition.CanonicalCreatureDefinition) usize {
    var count: usize = 0;
    for (source.bones) |bone| if (boneIsActive(source, bone)) {
        count += 1;
    };
    return count;
}

pub fn componentOwnedBoneCount(component_id: []const u8) usize {
    var count: usize = 0;
    for (bones) |bone| {
        const owner = bone.owner_component_id orelse continue;
        if (std.mem.eql(u8, owner.value.bytes, component_id)) count += 1;
    }
    return count;
}

fn buildBoneSpecs() [bone_count]BoneSpec {
    @setEvalBranchQuota(500_000);
    var result: [bone_count]BoneSpec = undefined;
    var index: usize = 0;

    appendBone(&result, &index, "skeleton_root", null, "body", false, null, transform(0, 0, 0, math3d.Quaternion.identity), null, .root);
    appendBone(&result, &index, "pelvis", "skeleton_root", "pelvis", true, null, transform(0, open_tuning.pelvis_height_m, 0, math3d.Quaternion.identity), open_tuning.spine_01_rise_m, .torso);
    appendBone(&result, &index, "spine_01", "pelvis", "torso", true, null, transform(0, open_tuning.spine_01_rise_m, 0, math3d.Quaternion.identity), open_tuning.spine_segment_rise_m, .torso);
    inline for (2..8) |spine_number| {
        appendBone(
            &result,
            &index,
            std.fmt.comptimePrint("spine_{d:0>2}", .{spine_number}),
            std.fmt.comptimePrint("spine_{d:0>2}", .{spine_number - 1}),
            "torso",
            true,
            null,
            transform(0, open_tuning.spine_segment_rise_m, 0, math3d.Quaternion.identity),
            open_tuning.spine_segment_rise_m,
            .torso,
        );
    }
    appendBone(&result, &index, "neck_01", "spine_07", "neck", true, null, transform(0, open_tuning.neck_01_rise_m, 0, math3d.Quaternion.identity), open_tuning.neck_segment_rise_m, .torso);
    appendBone(&result, &index, "neck_02", "neck_01", "neck", true, null, transform(0, open_tuning.neck_segment_rise_m, 0, math3d.Quaternion.identity), open_tuning.neck_segment_rise_m, .torso);
    appendBone(&result, &index, "neck_03", "neck_02", "neck", true, null, transform(0, open_tuning.neck_segment_rise_m, 0, math3d.Quaternion.identity), open_tuning.head_rise_m, .torso);
    appendBone(&result, &index, "head", "neck_03", "head", true, null, transform(0, open_tuning.head_rise_m, 0, math3d.Quaternion.identity), open_tuning.head_top_offset_m, .torso);
    appendBone(&result, &index, "jaw", "head", "mouth", true, null, transform(0, -open_tuning.jaw_drop_m, open_tuning.jaw_forward_m, math3d.Quaternion.identity), open_tuning.jaw_bottom_offset_m, .torso);
    appendBone(&result, &index, "tongue_01", "jaw", "tongue", true, null, transform(0, -open_tuning.tongue_root_drop_m, open_tuning.tongue_root_forward_m, math3d.Quaternion.identity), open_tuning.tongue_segment_length_m, .tongue);
    inline for (2..5) |tongue_number| {
        appendBone(
            &result,
            &index,
            std.fmt.comptimePrint("tongue_{d:0>2}", .{tongue_number}),
            std.fmt.comptimePrint("tongue_{d:0>2}", .{tongue_number - 1}),
            "tongue",
            true,
            null,
            transform(0, 0, open_tuning.tongue_segment_length_m, math3d.Quaternion.identity),
            open_tuning.tongue_segment_length_m,
            .tongue,
        );
    }
    appendBone(&result, &index, "tongue_branch_point", "tongue_04", "tongue", false, null, transform(0, 0, open_tuning.tongue_segment_length_m, math3d.Quaternion.identity), open_tuning.tongue_tip_length_m, .tongue);
    appendBone(&result, &index, "tongue_tip_01", "tongue_branch_point", "tongue", false, null, transform(0, 0, open_tuning.tongue_tip_length_m, math3d.Quaternion.identity), null, .tongue);

    inline for (.{ "left", "right" }) |side| {
        const sign: f32 = if (std.mem.eql(u8, side, "left")) -1 else 1;
        const arm_owner = std.fmt.comptimePrint("arm_{s}_01", .{side});
        const hand_owner = std.fmt.comptimePrint("hand_{s}_01", .{side});
        const leg_owner = std.fmt.comptimePrint("leg_{s}_01", .{side});
        const foot_owner = std.fmt.comptimePrint("foot_{s}_01", .{side});
        const eye_owner = std.fmt.comptimePrint("eye_{s}_01", .{side});
        const ear_owner = std.fmt.comptimePrint("ear_{s}_01", .{side});

        appendPairedBone(&result, &index, "clavicle", side, "spine_07", "torso", true, transform(sign * open_tuning.clavicle_outset_m, open_tuning.clavicle_rise_m, 0, math3d.Quaternion.identity), open_tuning.scapula_outset_m, .arm);
        appendPairedBone(&result, &index, "scapula", side, std.fmt.comptimePrint("clavicle_{s}", .{side}), "torso", true, transform(sign * open_tuning.scapula_outset_m, -open_tuning.scapula_drop_m, -open_tuning.scapula_back_m, math3d.Quaternion.identity), open_tuning.shoulder_outset_m, .arm);
        appendPairedBone(&result, &index, "upper_arm", side, std.fmt.comptimePrint("scapula_{s}", .{side}), arm_owner, true, transform(sign * open_tuning.shoulder_outset_m, 0, open_tuning.scapula_back_m, rotationZDegrees(-sign * open_tuning.upper_arm_a_pose_degrees)), open_tuning.upper_arm_length_m, .arm);
        appendPairedBoneWithSuffix(&result, &index, "upper_arm_twist", side, std.fmt.comptimePrint("upper_arm_{s}", .{side}), arm_owner, true, transform(sign * open_tuning.upper_arm_length_m / 3.0, 0, 0, math3d.Quaternion.identity), open_tuning.upper_arm_length_m / 3.0, .arm, "_01");
        appendPairedBoneWithSuffix(&result, &index, "upper_arm_twist", side, std.fmt.comptimePrint("upper_arm_twist_{s}_01", .{side}), arm_owner, true, transform(sign * open_tuning.upper_arm_length_m / 3.0, 0, 0, math3d.Quaternion.identity), open_tuning.upper_arm_length_m / 3.0, .arm, "_02");
        appendPairedBone(&result, &index, "forearm", side, std.fmt.comptimePrint("upper_arm_{s}", .{side}), arm_owner, true, transform(sign * open_tuning.upper_arm_length_m, 0, 0, rotationZDegrees(-sign * open_tuning.elbow_a_pose_degrees)), open_tuning.forearm_length_m, .arm);
        appendPairedBoneWithSuffix(&result, &index, "forearm_twist", side, std.fmt.comptimePrint("forearm_{s}", .{side}), arm_owner, true, transform(sign * open_tuning.forearm_length_m / 3.0, 0, 0, math3d.Quaternion.identity), open_tuning.forearm_length_m / 3.0, .arm, "_01");
        appendPairedBoneWithSuffix(&result, &index, "forearm_twist", side, std.fmt.comptimePrint("forearm_twist_{s}_01", .{side}), arm_owner, true, transform(sign * open_tuning.forearm_length_m / 3.0, 0, 0, math3d.Quaternion.identity), open_tuning.forearm_length_m / 3.0, .arm, "_02");
        appendPairedBone(&result, &index, "hand", side, std.fmt.comptimePrint("forearm_{s}", .{side}), hand_owner, true, transform(sign * open_tuning.forearm_length_m, 0, 0, math3d.Quaternion.identity), open_tuning.hand_root_length_m, .arm);

        appendPairedBone(&result, &index, "thumb_metacarpal", side, std.fmt.comptimePrint("hand_{s}", .{side}), hand_owner, true, transform(sign * open_tuning.thumb_base_outset_m, -open_tuning.thumb_base_drop_m, open_tuning.thumb_base_forward_m, math3d.Quaternion.identity), open_tuning.thumb_metacarpal_length_m, .hand);
        appendPairedBone(&result, &index, "thumb_proximal", side, std.fmt.comptimePrint("thumb_metacarpal_{s}", .{side}), hand_owner, true, transform(sign * open_tuning.thumb_metacarpal_length_m, 0, 0, math3d.Quaternion.identity), open_tuning.thumb_proximal_length_m, .hand);
        appendPairedBone(&result, &index, "thumb_distal", side, std.fmt.comptimePrint("thumb_proximal_{s}", .{side}), hand_owner, true, transform(sign * open_tuning.thumb_proximal_length_m, 0, 0, math3d.Quaternion.identity), open_tuning.thumb_distal_length_m, .hand);

        inline for (.{ "index", "middle", "ring", "little" }, 0..) |finger, finger_index| {
            const z_offset = (@as(f32, @floatFromInt(finger_index)) - 1.0) * open_tuning.finger_spacing_m;
            appendPairedBone(&result, &index, std.fmt.comptimePrint("{s}_metacarpal", .{finger}), side, std.fmt.comptimePrint("hand_{s}", .{side}), hand_owner, true, transform(sign * open_tuning.hand_root_length_m, 0, z_offset, math3d.Quaternion.identity), open_tuning.finger_metacarpal_length_m, .hand);
            appendPairedBone(&result, &index, std.fmt.comptimePrint("{s}_proximal", .{finger}), side, std.fmt.comptimePrint("{s}_metacarpal_{s}", .{ finger, side }), hand_owner, true, transform(sign * open_tuning.finger_metacarpal_length_m, 0, 0, math3d.Quaternion.identity), open_tuning.finger_proximal_length_m, .hand);
            appendPairedBone(&result, &index, std.fmt.comptimePrint("{s}_middle", .{finger}), side, std.fmt.comptimePrint("{s}_proximal_{s}", .{ finger, side }), hand_owner, true, transform(sign * open_tuning.finger_proximal_length_m, 0, 0, math3d.Quaternion.identity), open_tuning.finger_middle_length_m, .hand);
            appendPairedBone(&result, &index, std.fmt.comptimePrint("{s}_distal", .{finger}), side, std.fmt.comptimePrint("{s}_middle_{s}", .{ finger, side }), hand_owner, true, transform(sign * open_tuning.finger_middle_length_m, 0, 0, math3d.Quaternion.identity), open_tuning.finger_distal_length_m, .hand);
        }

        appendPairedBone(&result, &index, "thigh", side, "pelvis", leg_owner, true, transform(sign * open_tuning.hip_half_breadth_m, 0, 0, math3d.Quaternion.identity), open_tuning.thigh_length_m, .leg);
        appendPairedBoneWithSuffix(&result, &index, "thigh_twist", side, std.fmt.comptimePrint("thigh_{s}", .{side}), leg_owner, true, transform(0, -open_tuning.thigh_length_m / 3.0, 0, math3d.Quaternion.identity), open_tuning.thigh_length_m / 3.0, .leg, "_01");
        appendPairedBoneWithSuffix(&result, &index, "thigh_twist", side, std.fmt.comptimePrint("thigh_twist_{s}_01", .{side}), leg_owner, true, transform(0, -open_tuning.thigh_length_m / 3.0, 0, math3d.Quaternion.identity), open_tuning.thigh_length_m / 3.0, .leg, "_02");
        appendPairedBone(&result, &index, "lower_leg", side, std.fmt.comptimePrint("thigh_{s}", .{side}), leg_owner, true, transform(0, -open_tuning.thigh_length_m, 0, math3d.Quaternion.identity), open_tuning.lower_leg_length_m, .leg);
        appendPairedBoneWithSuffix(&result, &index, "lower_leg_twist", side, std.fmt.comptimePrint("lower_leg_{s}", .{side}), leg_owner, true, transform(0, -open_tuning.lower_leg_length_m / 3.0, 0, math3d.Quaternion.identity), open_tuning.lower_leg_length_m / 3.0, .leg, "_01");
        appendPairedBoneWithSuffix(&result, &index, "lower_leg_twist", side, std.fmt.comptimePrint("lower_leg_twist_{s}_01", .{side}), leg_owner, true, transform(0, -open_tuning.lower_leg_length_m / 3.0, 0, math3d.Quaternion.identity), open_tuning.lower_leg_length_m / 3.0, .leg, "_02");
        appendPairedBone(&result, &index, "ankle", side, std.fmt.comptimePrint("lower_leg_{s}", .{side}), leg_owner, false, transform(0, -open_tuning.lower_leg_length_m, 0, math3d.Quaternion.identity), open_tuning.ankle_to_foot_drop_m, .leg);
        appendPairedBone(&result, &index, "foot", side, std.fmt.comptimePrint("ankle_{s}", .{side}), foot_owner, true, transform(0, -open_tuning.ankle_to_foot_drop_m, 0, math3d.Quaternion.identity), open_tuning.foot_to_midfoot_forward_m, .foot);
        appendPairedBone(&result, &index, "midfoot", side, std.fmt.comptimePrint("foot_{s}", .{side}), foot_owner, true, transform(0, -open_tuning.foot_to_midfoot_drop_m, open_tuning.foot_to_midfoot_forward_m, math3d.Quaternion.identity), open_tuning.midfoot_to_forefoot_forward_m, .foot);
        appendPairedBone(&result, &index, "forefoot", side, std.fmt.comptimePrint("midfoot_{s}", .{side}), foot_owner, true, transform(0, -open_tuning.midfoot_to_forefoot_drop_m, open_tuning.midfoot_to_forefoot_forward_m, math3d.Quaternion.identity), open_tuning.big_toe_01_length_m, .foot);
        appendPairedBoneWithSuffix(&result, &index, "toe_big", side, std.fmt.comptimePrint("forefoot_{s}", .{side}), foot_owner, true, transform(0, 0, open_tuning.big_toe_01_length_m, math3d.Quaternion.identity), open_tuning.big_toe_02_length_m, .foot, "_01");
        appendPairedBoneWithSuffix(&result, &index, "toe_big", side, std.fmt.comptimePrint("toe_big_{s}_01", .{side}), foot_owner, true, transform(0, 0, open_tuning.big_toe_02_length_m, math3d.Quaternion.identity), open_tuning.big_toe_tip_length_m, .foot, "_02");
        inline for (.{ "index", "middle", "ring", "little" }, 0..) |toe, toe_index| {
            const x_offset = sign * (@as(f32, @floatFromInt(toe_index + 1)) * open_tuning.toe_spacing_m);
            appendPairedBoneWithSuffix(&result, &index, std.fmt.comptimePrint("toe_{s}", .{toe}), side, std.fmt.comptimePrint("forefoot_{s}", .{side}), foot_owner, true, transform(x_offset, 0, open_tuning.lesser_toe_01_length_m, math3d.Quaternion.identity), open_tuning.lesser_toe_02_length_m, .foot, "_01");
            appendPairedBoneWithSuffix(&result, &index, std.fmt.comptimePrint("toe_{s}", .{toe}), side, std.fmt.comptimePrint("toe_{s}_{s}_01", .{ toe, side }), foot_owner, true, transform(0, 0, open_tuning.lesser_toe_02_length_m, math3d.Quaternion.identity), open_tuning.lesser_toe_03_length_m, .foot, "_02");
            appendPairedBoneWithSuffix(&result, &index, std.fmt.comptimePrint("toe_{s}", .{toe}), side, std.fmt.comptimePrint("toe_{s}_{s}_02", .{ toe, side }), foot_owner, true, transform(0, 0, open_tuning.lesser_toe_03_length_m, math3d.Quaternion.identity), open_tuning.lesser_toe_tip_length_m, .foot, "_03");
        }

        appendPairedBoneWithSuffix(&result, &index, "eyeball", side, "head", eye_owner, true, transform(sign * open_tuning.eye_half_spacing_m, open_tuning.eye_rise_m, open_tuning.eye_forward_m, math3d.Quaternion.identity), open_tuning.eyeball_display_length_m, .eye, "_01");
        inline for (.{ "upper", "lower" }) |lid| {
            const y_offset: f32 = if (std.mem.eql(u8, lid, "upper")) open_tuning.eyelid_vertical_offset_m else -open_tuning.eyelid_vertical_offset_m;
            inline for (.{ "inner", "center", "outer" }) |section| {
                const section_offset: f32 = if (std.mem.eql(u8, section, "inner")) -sign * open_tuning.eyelid_horizontal_offset_m else if (std.mem.eql(u8, section, "outer")) sign * open_tuning.eyelid_horizontal_offset_m else 0;
                appendPairedBoneWithSuffix(
                    &result,
                    &index,
                    std.fmt.comptimePrint("eyelid_{s}", .{lid}),
                    side,
                    "head",
                    eye_owner,
                    true,
                    transform(sign * open_tuning.eye_half_spacing_m + section_offset, open_tuning.eye_rise_m + y_offset, open_tuning.eye_forward_m + open_tuning.eyelid_forward_offset_m, math3d.Quaternion.identity),
                    open_tuning.eyelid_display_length_m,
                    .eye,
                    std.fmt.comptimePrint("_{s}", .{section}),
                );
            }
        }
        appendPairedBoneWithSuffix(&result, &index, "ear_root", side, "head", ear_owner, true, transform(sign * open_tuning.ear_half_spacing_m, open_tuning.ear_rise_m, 0, math3d.Quaternion.identity), open_tuning.ear_display_length_m, .ear, "_01");
    }

    appendBone(&result, &index, "penis_root_01", "pelvis", "penis_module_01", false, null, transform(0, -open_tuning.penis_root_drop_m, open_tuning.penis_root_forward_m, math3d.Quaternion.identity), open_tuning.penis_shaft_segment_m, .optional_anatomy);
    inline for (1..8) |shaft_number| {
        appendBone(
            &result,
            &index,
            std.fmt.comptimePrint("penis_shaft_{d:0>2}", .{shaft_number}),
            if (shaft_number == 1) "penis_root_01" else std.fmt.comptimePrint("penis_shaft_{d:0>2}", .{shaft_number - 1}),
            "penis_module_01",
            true,
            null,
            transform(0, 0, open_tuning.penis_shaft_segment_m, math3d.Quaternion.identity),
            open_tuning.penis_shaft_segment_m,
            .optional_anatomy,
        );
    }
    appendBone(&result, &index, "penis_tip_01", "penis_shaft_07", "penis_module_01", false, null, transform(0, 0, open_tuning.penis_tip_reference_m, math3d.Quaternion.identity), null, .optional_anatomy);

    if (index != bone_count) @compileError(std.fmt.comptimePrint("human rig bone count is {d}, expected {d}", .{ index, bone_count }));
    return result;
}

fn appendPairedBone(
    result: *[bone_count]BoneSpec,
    index: *usize,
    prefix: []const u8,
    side: []const u8,
    parent_bone_id: []const u8,
    owner_component_id: []const u8,
    deforms_mesh: bool,
    local_rest_transform: math3d.LocalTransform,
    display_length_m: ?f32,
    category: Category,
) void {
    appendPairedBoneWithSuffix(result, index, prefix, side, parent_bone_id, owner_component_id, deforms_mesh, local_rest_transform, display_length_m, category, "");
}

fn appendPairedBoneWithSuffix(
    result: *[bone_count]BoneSpec,
    index: *usize,
    prefix: []const u8,
    side: []const u8,
    parent_bone_id: []const u8,
    owner_component_id: []const u8,
    deforms_mesh: bool,
    local_rest_transform: math3d.LocalTransform,
    display_length_m: ?f32,
    category: Category,
    suffix: []const u8,
) void {
    const opposite = if (std.mem.eql(u8, side, "left")) "right" else "left";
    appendBone(
        result,
        index,
        std.fmt.comptimePrint("{s}_{s}{s}", .{ prefix, side, suffix }),
        parent_bone_id,
        owner_component_id,
        deforms_mesh,
        std.fmt.comptimePrint("{s}_{s}{s}", .{ prefix, opposite, suffix }),
        local_rest_transform,
        display_length_m,
        category,
    );
}

fn appendBone(
    result: *[bone_count]BoneSpec,
    index: *usize,
    bone_id: []const u8,
    parent_bone_id: ?[]const u8,
    owner_component_id: []const u8,
    deforms_mesh: bool,
    mirror_bone_id: ?[]const u8,
    local_rest_transform: math3d.LocalTransform,
    display_length_m: ?f32,
    category: Category,
) void {
    result[index.*] = .{
        .bone_id = bone_id,
        .parent_bone_id = parent_bone_id,
        .owner_component_id = owner_component_id,
        .deforms_mesh = deforms_mesh,
        .mirror_bone_id = mirror_bone_id,
        .local_rest_transform = local_rest_transform,
        .display_length_m = display_length_m,
        .category = category,
    };
    index.* += 1;
}

fn buildBones() [bone_count]rig.Bone {
    @setEvalBranchQuota(1_000_000);
    var result: [bone_count]rig.Bone = undefined;
    inline for (bone_specs, 0..) |spec, index| {
        result[index] = .{
            .bone_id = makeId(identity.BoneId, spec.bone_id),
            .display_name = null,
            .owner_component_id = makeId(identity.ComponentId, spec.owner_component_id),
            .parent_bone_id = if (spec.parent_bone_id) |parent_id| makeId(identity.BoneId, parent_id) else null,
            .deforms_mesh = spec.deforms_mesh,
            .local_rest_transform = spec.local_rest_transform,
            .semantic_tags = tagsFor(spec),
            .mirror_bone_id = if (spec.mirror_bone_id) |mirror_id| makeId(identity.BoneId, mirror_id) else null,
            .display_length_m = spec.display_length_m,
        };
    }
    return result;
}

fn tagsFor(comptime spec: BoneSpec) []const identity.SemanticTagId {
    if (spec.category == .root) return &root_tags;
    if (spec.category == .torso) return &torso_tags;
    if (spec.category == .tongue) return &tongue_tags;
    if (spec.category == .optional_anatomy) return &optional_tags;
    if (std.mem.indexOf(u8, spec.bone_id, "_left") != null) return &left_tags;
    if (std.mem.indexOf(u8, spec.bone_id, "_right") != null) return &right_tags;
    return &torso_tags;
}

fn transform(x: f32, y: f32, z: f32, rotation: math3d.Quaternion) math3d.LocalTransform {
    return .{
        .translation_m = .{ .x = x, .y = y, .z = z },
        .rotation = rotation,
        .scale = math3d.Vec3.one,
    };
}

fn rotationZDegrees(degrees: f32) math3d.Quaternion {
    const half_radians = degrees * std.math.pi / 360.0;
    return math3d.Quaternion.initCanonical(0, 0, @sin(half_radians), @cos(half_radians)) catch |quaternion_error| @compileError(@errorName(quaternion_error));
}

fn makeId(comptime T: type, comptime bytes: []const u8) T {
    return T.init(bytes) catch |id_error| @compileError(@errorName(id_error) ++ ": " ++ bytes);
}

fn makeIds(comptime T: type, comptime values: []const []const u8) [values.len]T {
    var result: [values.len]T = undefined;
    inline for (values, 0..) |value, index| result[index] = makeId(T, value);
    return result;
}
