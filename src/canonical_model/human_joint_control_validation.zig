const std = @import("std");
const definition = @import("definition.zig");
const human_controls = @import("human_controls.zig");
const human_joints = @import("human_joints.zig");
const human_validation = @import("human_validation.zig");
const identity = @import("identity.zig");
const math3d = @import("math3d.zig");
const rig = @import("rig.zig");

pub const Error = error{
    Prompt2BRegression,
    JointCountMismatch,
    DuplicateJointId,
    MissingApprovedJoint,
    JointContractMismatch,
    IncompatibleJointBones,
    MissingJointMirrorPartner,
    JointMirrorMismatch,
    NonFiniteJointRange,
    ReversedJointRange,
    PreferredRangeOutsideHardRange,
    MalformedSwingTwist,
    ControlCountMismatch,
    DuplicateStructuralControlOwnership,
    MissingApprovedControl,
    ControlContractMismatch,
    MissingDrivenTarget,
    WrongDrivenTargetType,
    DisallowedDrivenTarget,
    MissingControlMirrorPartner,
    ControlMirrorMismatch,
    WrongSpineControlCount,
};

pub fn validatePrompt2C(source: *const definition.CanonicalCreatureDefinition) Error!void {
    human_validation.validatePrompt2B(source) catch return error.Prompt2BRegression;
    try validateJoints(source);
    try validateControls(source);
}

fn validateJoints(source: *const definition.CanonicalCreatureDefinition) Error!void {
    @setEvalBranchQuota(1_000_000);
    if (source.joints.len != human_joints.joint_count) return error.JointCountMismatch;
    for (source.joints, 0..) |joint, index| for (source.joints[index + 1 ..]) |other| {
        if (joint.joint_id.eql(other.joint_id)) return error.DuplicateJointId;
    };

    inline for (human_joints.joint_specs) |spec| {
        const joint = findJoint(source, spec.joint_id) orelse return error.MissingApprovedJoint;
        const child = findBone(source, joint.child_bone_id.value.bytes) orelse return error.IncompatibleJointBones;
        const child_parent = child.parent_bone_id orelse return error.IncompatibleJointBones;
        if (!child_parent.eql(joint.parent_bone_id) or
            !std.mem.eql(u8, joint.parent_bone_id.value.bytes, spec.parent_bone_id) or
            !std.mem.eql(u8, joint.child_bone_id.value.bytes, spec.child_bone_id))
        {
            return error.IncompatibleJointBones;
        }

        if (!jointNumbersFinite(joint)) return error.NonFiniteJointRange;
        if (axisHasReversedRange(joint.preferred_range) or
            axisHasReversedRange(joint.hard_range) or
            swingHasReversedRange(joint.swing_twist))
        {
            return error.ReversedJointRange;
        }
        if (!preferredInsideHard(joint.preferred_range, joint.hard_range)) {
            return error.PreferredRangeOutsideHardRange;
        }

        const mobility = human_joints.profileForKind(spec.profile_kind);
        if ((joint.swing_twist == null) != (mobility.swing_twist == null)) return error.MalformedSwingTwist;
        if (spec.mirror_joint_id) |expected_mirror_id| {
            const actual_mirror_id = joint.mirror_joint_id orelse return error.MissingJointMirrorPartner;
            if (!std.mem.eql(u8, actual_mirror_id.value.bytes, expected_mirror_id)) return error.JointMirrorMismatch;
            const mirror = findJoint(source, expected_mirror_id) orelse return error.MissingJointMirrorPartner;
            const reciprocal = mirror.mirror_joint_id orelse return error.MissingJointMirrorPartner;
            if (!reciprocal.eql(joint.joint_id) or
                joint.joint_type != mirror.joint_type or
                !std.meta.eql(joint.preferred_range, mirror.preferred_range) or
                !std.meta.eql(joint.hard_range, mirror.hard_range) or
                !optionalDirectionsMirror(joint.preferred_bend_direction, mirror.preferred_bend_direction))
            {
                return error.JointMirrorMismatch;
            }
        } else if (joint.mirror_joint_id != null) return error.JointMirrorMismatch;

        const profile_id = joint.mobility_profile_override orelse return error.JointContractMismatch;
        if (joint.joint_type != mobility.joint_type or
            !std.meta.eql(joint.preferred_range, mobility.preferred_range) or
            !std.meta.eql(joint.hard_range, mobility.hard_range) or
            !optionalDirectionsEqual(joint.preferred_bend_direction, mobility.preferred_bend_direction) or
            !optionalSwingEqual(joint.swing_twist, mobility.swing_twist) or
            joint.limit_behavior.stiffness == null or
            joint.limit_behavior.stiffness.? != mobility.stiffness or
            !std.mem.eql(u8, profile_id.value.bytes, mobility.profile_id))
        {
            return error.JointContractMismatch;
        }
    }
}

fn validateControls(source: *const definition.CanonicalCreatureDefinition) Error!void {
    @setEvalBranchQuota(1_000_000);
    if (source.controls.len != human_controls.control_count) return error.ControlCountMismatch;
    for (source.controls, 0..) |control, index| for (source.controls[index + 1 ..]) |other| {
        if (control.control_id.eql(other.control_id)) return error.DuplicateStructuralControlOwnership;
    };

    var spine_count: usize = 0;
    for (source.controls) |control| if (isSpineControl(control.control_id.value.bytes)) {
        spine_count += 1;
    };
    if (spine_count != human_controls.spine_control_count) return error.WrongSpineControlCount;

    inline for (human_controls.control_specs) |spec| {
        const control = human_controls.findControl(source, spec.control_id) orelse return error.MissingApprovedControl;
        if (control.control_type == .procedural_grasp) return error.DisallowedDrivenTarget;
        if (control.control_type != spec.control_type or control.space != spec.space) return error.ControlContractMismatch;
        if (findComponent(source, spec.owner_component_id) == null) return error.DuplicateStructuralControlOwnership;
        if (control.driven_targets.len < spec.target_count) return error.MissingDrivenTarget;
        if (control.driven_targets.len > spec.target_count) return error.DisallowedDrivenTarget;

        for (control.driven_targets) |target| switch (target) {
            .bone, .joint => {},
            .anchor, .morphology_parameter, .constraint => return error.DisallowedDrivenTarget,
        };
        inline for (spec.targets[0..spec.target_count]) |expected| {
            var found = false;
            for (control.driven_targets) |actual| {
                const actual_kind = targetKind(actual) orelse continue;
                if (std.mem.eql(u8, targetId(actual), expected.id)) {
                    if (actual_kind != expected.kind) return error.WrongDrivenTargetType;
                    found = true;
                }
            }
            if (!found) return error.MissingDrivenTarget;
        }
        for (control.driven_targets) |target| switch (target) {
            .bone => |id| if (findBone(source, id.value.bytes) == null) return error.MissingDrivenTarget,
            .joint => |id| if (findJoint(source, id.value.bytes) == null) return error.MissingDrivenTarget,
            .anchor, .morphology_parameter, .constraint => return error.DisallowedDrivenTarget,
        };

        if (spec.mirror_control_id) |expected_mirror_id| {
            const actual_mirror_id = control.mirror_control_id orelse return error.MissingControlMirrorPartner;
            if (!std.mem.eql(u8, actual_mirror_id.value.bytes, expected_mirror_id)) return error.ControlMirrorMismatch;
            const mirror = human_controls.findControl(source, expected_mirror_id) orelse return error.MissingControlMirrorPartner;
            const reciprocal = mirror.mirror_control_id orelse return error.MissingControlMirrorPartner;
            if (!reciprocal.eql(control.control_id) or control.control_type != mirror.control_type or control.space != mirror.space) {
                return error.ControlMirrorMismatch;
            }
        } else if (control.mirror_control_id != null) return error.ControlMirrorMismatch;

        if (!controlMetadataMatches(control, spec)) return error.ControlContractMismatch;
        if (spec.relevant_joint_id) |joint_id| {
            if (findJoint(source, joint_id) == null) return error.MissingDrivenTarget;
        }
    }
}

fn controlMetadataMatches(control: rig.Control, spec: human_controls.ControlSpec) bool {
    if (control.region_id != null or control.semantic_tags.len != 2) return false;
    if (!std.mem.eql(u8, control.semantic_tags[0].value.bytes, "human") or
        !std.mem.eql(u8, control.semantic_tags[1].value.bytes, "structural_control")) return false;
    return switch (spec.control_type) {
        .fk_rotation => control.default_value != null and std.meta.activeTag(control.default_value.?) == .quaternion and control.limits == null,
        .normalized_slider => control.default_value != null and
            std.meta.activeTag(control.default_value.?) == .scalar and
            control.default_value.?.scalar == spec.normalized_default.? and
            control.limits != null and
            control.limits.?.minimum != null and
            control.limits.?.maximum != null and
            std.meta.activeTag(control.limits.?.minimum.?) == .scalar and
            std.meta.activeTag(control.limits.?.maximum.?) == .scalar and
            control.limits.?.minimum.?.scalar == human_controls.open_tuning.normalized_minimum and
            control.limits.?.maximum.?.scalar == human_controls.open_tuning.normalized_maximum,
        else => control.default_value == null and control.limits == null,
    };
}

fn jointNumbersFinite(joint: rig.Joint) bool {
    if (!axisFinite(joint.preferred_range) or !axisFinite(joint.hard_range)) return false;
    if (joint.swing_twist) |limits| {
        if (!rangeFinite(limits.swing_y_radians) or
            !rangeFinite(limits.swing_z_radians) or
            !rangeFinite(limits.twist_radians)) return false;
    }
    if (joint.preferred_bend_direction) |direction| {
        if (!vecFinite(direction)) return false;
    }
    if (joint.limit_behavior.stiffness) |stiffness| {
        if (!std.math.isFinite(stiffness)) return false;
    }
    return true;
}

fn axisFinite(limits: rig.AxisAngularLimits) bool {
    const ranges = [_]?rig.AngularRange{ limits.x, limits.y, limits.z };
    for (ranges) |maybe_range| {
        if (maybe_range) |range| if (!rangeFinite(range)) return false;
    }
    return true;
}

fn rangeFinite(range: rig.AngularRange) bool {
    return std.math.isFinite(range.minimum_radians) and std.math.isFinite(range.maximum_radians);
}

fn axisHasReversedRange(limits: rig.AxisAngularLimits) bool {
    const ranges = [_]?rig.AngularRange{ limits.x, limits.y, limits.z };
    for (ranges) |maybe_range| {
        if (maybe_range) |range| if (range.minimum_radians > range.maximum_radians) return true;
    }
    return false;
}

fn swingHasReversedRange(limits: ?rig.SwingTwistConstraints) bool {
    const value = limits orelse return false;
    return value.swing_y_radians.minimum_radians > value.swing_y_radians.maximum_radians or
        value.swing_z_radians.minimum_radians > value.swing_z_radians.maximum_radians or
        value.twist_radians.minimum_radians > value.twist_radians.maximum_radians;
}

fn preferredInsideHard(preferred: rig.AxisAngularLimits, hard: rig.AxisAngularLimits) bool {
    return preferredAxisInsideHard(preferred.x, hard.x) and
        preferredAxisInsideHard(preferred.y, hard.y) and
        preferredAxisInsideHard(preferred.z, hard.z);
}

fn preferredAxisInsideHard(preferred: ?rig.AngularRange, hard: ?rig.AngularRange) bool {
    const preferred_range = preferred orelse return true;
    const hard_range = hard orelse return false;
    return preferred_range.minimum_radians >= hard_range.minimum_radians and
        preferred_range.maximum_radians <= hard_range.maximum_radians;
}

fn optionalDirectionsEqual(a: ?math3d.Vec3, b: ?math3d.Vec3) bool {
    if (a == null or b == null) return a == null and b == null;
    return std.meta.eql(a.?, b.?);
}

fn optionalDirectionsMirror(a: ?math3d.Vec3, b: ?math3d.Vec3) bool {
    if (a == null or b == null) return a == null and b == null;
    return a.?.x == -b.?.x and a.?.y == b.?.y and a.?.z == b.?.z;
}

fn optionalSwingEqual(a: ?rig.SwingTwistConstraints, b: ?rig.SwingTwistConstraints) bool {
    if (a == null or b == null) return a == null and b == null;
    return std.meta.eql(a.?, b.?);
}

fn vecFinite(value: math3d.Vec3) bool {
    return std.math.isFinite(value.x) and std.math.isFinite(value.y) and std.math.isFinite(value.z);
}

fn targetKind(target: rig.DrivenTarget) ?human_controls.TargetKind {
    return switch (target) {
        .bone => .bone,
        .joint => .joint,
        else => null,
    };
}

fn targetId(target: rig.DrivenTarget) []const u8 {
    return switch (target) {
        .bone => |id| id.value.bytes,
        .joint => |id| id.value.bytes,
        .anchor => |id| id.value.bytes,
        .morphology_parameter => |id| id.value.bytes,
        .constraint => |id| id.value.bytes,
    };
}

fn isSpineControl(control_id: []const u8) bool {
    inline for (.{
        "spine_lower_control",
        "spine_mid_control",
        "spine_chest_control",
        "spine_upper_chest_control",
        "spine_curve_control",
    }) |expected| if (std.mem.eql(u8, control_id, expected)) return true;
    return false;
}

fn findJoint(source: *const definition.CanonicalCreatureDefinition, joint_id: []const u8) ?rig.Joint {
    for (source.joints) |joint| if (std.mem.eql(u8, joint.joint_id.value.bytes, joint_id)) return joint;
    return null;
}

fn findBone(source: *const definition.CanonicalCreatureDefinition, bone_id: []const u8) ?rig.Bone {
    for (source.bones) |bone| if (std.mem.eql(u8, bone.bone_id.value.bytes, bone_id)) return bone;
    return null;
}

fn findComponent(source: *const definition.CanonicalCreatureDefinition, component_id: []const u8) ?identity.ComponentId {
    for (source.components) |component| {
        if (std.mem.eql(u8, component.component_id.value.bytes, component_id)) return component.component_id;
    }
    return null;
}
