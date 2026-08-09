const identity = @import("identity.zig");
const math3d = @import("math3d.zig");

pub const Bone = struct {
    bone_id: identity.BoneId,
    display_name: ?identity.DisplayName,
    owner_component_id: ?identity.ComponentId = null,
    parent_bone_id: ?identity.BoneId,
    deforms_mesh: bool,
    local_rest_transform: math3d.LocalTransform,
    semantic_tags: []const identity.SemanticTagId,
    mirror_bone_id: ?identity.BoneId,
    display_length_m: ?f32,
};

pub const JointType = enum {
    hinge_like,
    ball_and_socket,
    multi_axis,
    twist,
};

pub const AngularRange = struct {
    minimum_radians: f32,
    maximum_radians: f32,
};

pub const AxisAngularLimits = struct {
    x: ?AngularRange,
    y: ?AngularRange,
    z: ?AngularRange,
};

pub const SwingTwistConstraints = struct {
    swing_y_radians: AngularRange,
    swing_z_radians: AngularRange,
    twist_radians: AngularRange,
};

pub const LimitBehavior = struct {
    stiffness: ?f32,
};

pub const Joint = struct {
    joint_id: identity.JointId,
    display_name: ?identity.DisplayName,
    parent_bone_id: identity.BoneId,
    child_bone_id: identity.BoneId,
    mirror_joint_id: ?identity.JointId = null,
    joint_type: JointType,
    preferred_range: AxisAngularLimits,
    hard_range: AxisAngularLimits,
    preferred_bend_direction: ?math3d.Vec3,
    swing_twist: ?SwingTwistConstraints,
    limit_behavior: LimitBehavior,
    mobility_profile_override: ?identity.MobilityProfileId,
};

pub const ControlType = enum {
    fk_rotation,
    ik_target,
    pole_direction,
    curve_spline,
    whole_region,
    normalized_slider,
    look_target,
    procedural_grasp,
};

pub const ControlSpace = enum {
    local,
    character,
    world,
    target_relative,
};

pub const DrivenTarget = union(enum) {
    bone: identity.BoneId,
    joint: identity.JointId,
    anchor: identity.AnchorId,
    morphology_parameter: identity.MorphologyParameterId,
    constraint: identity.ConstraintId,
};

pub const ControlValue = union(enum) {
    scalar: f32,
    vector: math3d.Vec3,
    quaternion: math3d.Quaternion,
    transform: math3d.LocalTransform,
};

pub const ControlLimits = struct {
    minimum: ?ControlValue,
    maximum: ?ControlValue,
};

pub const Control = struct {
    control_id: identity.ControlId,
    display_name: ?identity.DisplayName,
    control_type: ControlType,
    driven_targets: []const DrivenTarget,
    space: ControlSpace,
    mirror_control_id: ?identity.ControlId,
    default_value: ?ControlValue,
    limits: ?ControlLimits,
    semantic_tags: []const identity.SemanticTagId,
    region_id: ?identity.RegionId,
};
