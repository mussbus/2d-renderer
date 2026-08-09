const std = @import("std");
const human_rig = @import("human_rig.zig");
const math3d = @import("math3d.zig");
const rig = @import("rig.zig");

pub const joint_count: usize = human_rig.bone_count - 1;

pub const ProfileKind = enum {
    pelvis,
    spine,
    neck_head,
    jaw,
    shoulder_girdle,
    shoulder,
    twist_distribution,
    elbow,
    wrist,
    thumb_base,
    finger_base,
    finger_hinge,
    hip,
    knee,
    ankle_foot,
    toe,
    eye,
    eyelid,
    tongue,
    ear,
    optional_soft_chain,
};

pub const MobilityProfile = struct {
    profile_id: []const u8,
    joint_type: rig.JointType,
    preferred_range: rig.AxisAngularLimits,
    hard_range: rig.AxisAngularLimits,
    preferred_bend_direction: ?math3d.Vec3,
    swing_twist: ?rig.SwingTwistConstraints,
    stiffness: f32,
};

/// Prompt 2C provisional degrees-of-freedom and ROM data. Degree literals are
/// accepted here only as human-facing authoring input; `deg` converts them to
/// the canonical radian fields immediately. The resulting profiles and joints
/// store radians only. These values are OPEN/TUNING authoring metadata, not
/// collision limits or medical claims.
pub const open_tuning = struct {
    pub const pelvis = profile(
        "human_pelvis_mobility",
        .multi_axis,
        limits(deg(-15, 15), deg(-20, 20), deg(-12, 12)),
        limits(deg(-35, 35), deg(-45, 45), deg(-30, 30)),
        null,
        null,
        0.65,
    );
    pub const spine = profile(
        "human_spine_mobility",
        .multi_axis,
        limits(deg(-8, 8), deg(-6, 6), deg(-6, 6)),
        limits(deg(-18, 18), deg(-15, 15), deg(-15, 15)),
        null,
        null,
        0.72,
    );
    pub const neck_head = profile(
        "human_neck_head_mobility",
        .ball_and_socket,
        limits(deg(-25, 30), deg(-35, 35), deg(-20, 20)),
        limits(deg(-45, 55), deg(-70, 70), deg(-40, 40)),
        null,
        swing(deg(-30, 30), deg(-25, 25), deg(-35, 35)),
        0.58,
    );
    pub const jaw = profile(
        "human_jaw_mobility",
        .multi_axis,
        limits(deg(0, 25), deg(-5, 5), deg(-4, 4)),
        limits(deg(0, 45), deg(-10, 10), deg(-8, 8)),
        .{ .x = 0, .y = 0, .z = 1 },
        null,
        0.42,
    );
    pub const shoulder_girdle = profile(
        "human_shoulder_girdle_mobility",
        .multi_axis,
        limits(deg(-10, 10), deg(-12, 12), deg(-10, 10)),
        limits(deg(-25, 25), deg(-30, 30), deg(-25, 25)),
        null,
        null,
        0.55,
    );
    pub const shoulder = profile(
        "human_shoulder_mobility",
        .ball_and_socket,
        limits(deg(-45, 90), deg(-60, 60), deg(-80, 80)),
        limits(deg(-90, 150), deg(-100, 100), deg(-120, 120)),
        null,
        swing(deg(-70, 70), deg(-60, 60), deg(-55, 55)),
        0.48,
    );
    pub const twist_distribution = profile(
        "human_twist_distribution_mobility",
        .twist,
        noLimits(),
        noLimits(),
        null,
        swing(deg(-3, 3), deg(-3, 3), deg(-35, 35)),
        0.82,
    );
    pub const elbow = profile(
        "human_elbow_mobility",
        .hinge_like,
        limits(null, null, deg(0, 120)),
        limits(null, null, deg(-5, 150)),
        .{ .x = 0, .y = -1, .z = 0 },
        null,
        0.68,
    );
    pub const wrist = profile(
        "human_wrist_mobility",
        .multi_axis,
        limits(deg(-45, 45), deg(-30, 30), deg(-30, 30)),
        limits(deg(-80, 80), deg(-60, 60), deg(-60, 60)),
        null,
        null,
        0.50,
    );
    pub const thumb_base = profile(
        "human_thumb_base_mobility",
        .ball_and_socket,
        limits(deg(-25, 45), deg(-35, 35), deg(-30, 45)),
        limits(deg(-45, 70), deg(-60, 60), deg(-50, 70)),
        null,
        swing(deg(-35, 35), deg(-30, 30), deg(-35, 45)),
        0.45,
    );
    pub const finger_base = profile(
        "human_finger_base_mobility",
        .multi_axis,
        limits(deg(-8, 75), deg(-12, 12), deg(-8, 8)),
        limits(deg(-15, 95), deg(-25, 25), deg(-15, 15)),
        .{ .x = 0, .y = 0, .z = 1 },
        null,
        0.52,
    );
    pub const finger_hinge = profile(
        "human_finger_hinge_mobility",
        .hinge_like,
        limits(null, null, deg(0, 85)),
        limits(null, null, deg(-5, 115)),
        .{ .x = 0, .y = 0, .z = 1 },
        null,
        0.58,
    );
    pub const hip = profile(
        "human_hip_mobility",
        .ball_and_socket,
        limits(deg(-30, 60), deg(-35, 35), deg(-30, 30)),
        limits(deg(-60, 120), deg(-60, 60), deg(-50, 50)),
        null,
        swing(deg(-55, 55), deg(-45, 45), deg(-35, 35)),
        0.62,
    );
    pub const knee = profile(
        "human_knee_mobility",
        .hinge_like,
        limits(deg(0, 120), null, null),
        limits(deg(-5, 150), null, null),
        .{ .x = 0, .y = 0, .z = 1 },
        null,
        0.72,
    );
    pub const ankle_foot = profile(
        "human_ankle_foot_mobility",
        .multi_axis,
        limits(deg(-20, 30), deg(-12, 12), deg(-15, 15)),
        limits(deg(-40, 55), deg(-25, 25), deg(-30, 30)),
        null,
        null,
        0.60,
    );
    pub const toe = profile(
        "human_toe_mobility",
        .hinge_like,
        limits(deg(-15, 45), null, null),
        limits(deg(-30, 75), null, null),
        .{ .x = 0, .y = 1, .z = 0 },
        null,
        0.46,
    );
    pub const eye = profile(
        "human_eye_mobility",
        .ball_and_socket,
        limits(deg(-25, 25), deg(-25, 25), deg(-15, 15)),
        limits(deg(-45, 45), deg(-45, 45), deg(-30, 30)),
        null,
        swing(deg(-25, 25), deg(-25, 25), deg(-15, 15)),
        0.36,
    );
    pub const eyelid = profile(
        "human_eyelid_mobility",
        .hinge_like,
        limits(deg(0, 45), null, null),
        limits(deg(-5, 70), null, null),
        .{ .x = 0, .y = 0, .z = 1 },
        null,
        0.34,
    );
    pub const tongue = profile(
        "human_tongue_mobility",
        .multi_axis,
        limits(deg(-20, 20), deg(-20, 20), deg(-20, 20)),
        limits(deg(-45, 45), deg(-45, 45), deg(-45, 45)),
        null,
        null,
        0.30,
    );
    pub const ear = profile(
        "human_ear_mobility",
        .multi_axis,
        limits(deg(-5, 5), deg(-5, 5), deg(-5, 5)),
        limits(deg(-15, 15), deg(-15, 15), deg(-15, 15)),
        null,
        null,
        0.40,
    );
    pub const optional_soft_chain = profile(
        "human_optional_soft_chain_mobility",
        .multi_axis,
        limits(deg(-12, 12), deg(-12, 12), deg(-12, 12)),
        limits(deg(-30, 30), deg(-30, 30), deg(-30, 30)),
        null,
        null,
        0.28,
    );
};

pub const mobility_profiles = [_]MobilityProfile{
    open_tuning.pelvis,
    open_tuning.spine,
    open_tuning.neck_head,
    open_tuning.jaw,
    open_tuning.shoulder_girdle,
    open_tuning.shoulder,
    open_tuning.twist_distribution,
    open_tuning.elbow,
    open_tuning.wrist,
    open_tuning.thumb_base,
    open_tuning.finger_base,
    open_tuning.finger_hinge,
    open_tuning.hip,
    open_tuning.knee,
    open_tuning.ankle_foot,
    open_tuning.toe,
    open_tuning.eye,
    open_tuning.eyelid,
    open_tuning.tongue,
    open_tuning.ear,
    open_tuning.optional_soft_chain,
};

pub const JointSpec = struct {
    joint_id: []const u8,
    parent_bone_id: []const u8,
    child_bone_id: []const u8,
    mirror_joint_id: ?[]const u8,
    profile_kind: ProfileKind,
};

pub const joint_specs = buildJointSpecs();

pub fn profileForKind(kind: ProfileKind) MobilityProfile {
    return switch (kind) {
        .pelvis => open_tuning.pelvis,
        .spine => open_tuning.spine,
        .neck_head => open_tuning.neck_head,
        .jaw => open_tuning.jaw,
        .shoulder_girdle => open_tuning.shoulder_girdle,
        .shoulder => open_tuning.shoulder,
        .twist_distribution => open_tuning.twist_distribution,
        .elbow => open_tuning.elbow,
        .wrist => open_tuning.wrist,
        .thumb_base => open_tuning.thumb_base,
        .finger_base => open_tuning.finger_base,
        .finger_hinge => open_tuning.finger_hinge,
        .hip => open_tuning.hip,
        .knee => open_tuning.knee,
        .ankle_foot => open_tuning.ankle_foot,
        .toe => open_tuning.toe,
        .eye => open_tuning.eye,
        .eyelid => open_tuning.eyelid,
        .tongue => open_tuning.tongue,
        .ear => open_tuning.ear,
        .optional_soft_chain => open_tuning.optional_soft_chain,
    };
}

fn buildJointSpecs() [joint_count]JointSpec {
    @setEvalBranchQuota(500_000);
    var result: [joint_count]JointSpec = undefined;
    var index: usize = 0;
    inline for (human_rig.bone_specs) |bone_spec| {
        const parent_bone_id = bone_spec.parent_bone_id orelse continue;
        result[index] = .{
            .joint_id = std.fmt.comptimePrint("{s}_joint", .{bone_spec.bone_id}),
            .parent_bone_id = parent_bone_id,
            .child_bone_id = bone_spec.bone_id,
            .mirror_joint_id = if (bone_spec.mirror_bone_id) |mirror_id| std.fmt.comptimePrint("{s}_joint", .{mirror_id}) else null,
            .profile_kind = profileKindForBone(bone_spec.bone_id),
        };
        index += 1;
    }
    if (index != joint_count) @compileError("human joint manifest count mismatch");
    return result;
}

fn profileKindForBone(comptime bone_id: []const u8) ProfileKind {
    if (std.mem.startsWith(u8, bone_id, "penis_")) return .optional_soft_chain;
    if (std.mem.eql(u8, bone_id, "pelvis")) return .pelvis;
    if (std.mem.startsWith(u8, bone_id, "spine_")) return .spine;
    if (std.mem.startsWith(u8, bone_id, "neck_") or std.mem.eql(u8, bone_id, "head")) return .neck_head;
    if (std.mem.eql(u8, bone_id, "jaw")) return .jaw;
    if (std.mem.startsWith(u8, bone_id, "tongue_")) return .tongue;
    if (std.mem.startsWith(u8, bone_id, "clavicle_") or std.mem.startsWith(u8, bone_id, "scapula_")) return .shoulder_girdle;
    if (std.mem.indexOf(u8, bone_id, "_twist_") != null) return .twist_distribution;
    if (std.mem.startsWith(u8, bone_id, "upper_arm_")) return .shoulder;
    if (std.mem.startsWith(u8, bone_id, "forearm_")) return .elbow;
    if (std.mem.startsWith(u8, bone_id, "hand_")) return .wrist;
    if (std.mem.startsWith(u8, bone_id, "thumb_metacarpal_")) return .thumb_base;
    if (std.mem.startsWith(u8, bone_id, "thumb_")) return .finger_hinge;
    inline for (.{ "index", "middle", "ring", "little" }) |digit| {
        if (std.mem.startsWith(u8, bone_id, digit ++ "_")) {
            return if (std.mem.indexOf(u8, bone_id, "_metacarpal_") != null) .finger_base else .finger_hinge;
        }
    }
    if (std.mem.startsWith(u8, bone_id, "thigh_")) return .hip;
    if (std.mem.startsWith(u8, bone_id, "lower_leg_")) return .knee;
    if (std.mem.startsWith(u8, bone_id, "ankle_") or
        std.mem.startsWith(u8, bone_id, "foot_") or
        std.mem.startsWith(u8, bone_id, "midfoot_") or
        std.mem.startsWith(u8, bone_id, "forefoot_")) return .ankle_foot;
    if (std.mem.startsWith(u8, bone_id, "toe_")) return .toe;
    if (std.mem.startsWith(u8, bone_id, "eyeball_")) return .eye;
    if (std.mem.startsWith(u8, bone_id, "eyelid_")) return .eyelid;
    if (std.mem.startsWith(u8, bone_id, "ear_root_")) return .ear;
    @compileError("no Prompt 2C mobility profile for bone: " ++ bone_id);
}

fn profile(
    profile_id: []const u8,
    joint_type: rig.JointType,
    preferred_range: rig.AxisAngularLimits,
    hard_range: rig.AxisAngularLimits,
    preferred_bend_direction: ?math3d.Vec3,
    swing_twist: ?rig.SwingTwistConstraints,
    stiffness: f32,
) MobilityProfile {
    return .{
        .profile_id = profile_id,
        .joint_type = joint_type,
        .preferred_range = preferred_range,
        .hard_range = hard_range,
        .preferred_bend_direction = preferred_bend_direction,
        .swing_twist = swing_twist,
        .stiffness = stiffness,
    };
}

fn deg(minimum_degrees: f32, maximum_degrees: f32) rig.AngularRange {
    return .{
        .minimum_radians = minimum_degrees * std.math.pi / 180.0,
        .maximum_radians = maximum_degrees * std.math.pi / 180.0,
    };
}

fn limits(
    x: ?rig.AngularRange,
    y: ?rig.AngularRange,
    z: ?rig.AngularRange,
) rig.AxisAngularLimits {
    return .{ .x = x, .y = y, .z = z };
}

fn noLimits() rig.AxisAngularLimits {
    return .{ .x = null, .y = null, .z = null };
}

fn swing(
    swing_y: rig.AngularRange,
    swing_z: rig.AngularRange,
    twist: rig.AngularRange,
) rig.SwingTwistConstraints {
    return .{
        .swing_y_radians = swing_y,
        .swing_z_radians = swing_z,
        .twist_radians = twist,
    };
}
