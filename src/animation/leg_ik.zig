const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const pose = @import("pose");
const two_bone = @import("two_bone_ik");

pub const Bend = two_bone.Bend;
pub const Reachability = two_bone.Reachability;
pub const rotation_axis_epsilon: f32 = 0.000001;

pub const AnatomicalFoot = enum(u8) {
    left,
    right,

    pub fn socketSemantic(foot: AnatomicalFoot) skeleton.SocketSemantic {
        return switch (foot) {
            .left => .left_foot,
            .right => .right_foot,
        };
    }
};

pub const BindingInput = struct {
    hip_bone: u16,
    knee_bone: u16,
    ankle_bone: u16,
    sole_socket: u16,
    character_local_bend: Bend,
};

pub const Binding = struct {
    foot: AnatomicalFoot,
    hip_bone: u16,
    knee_bone: u16,
    ankle_bone: u16,
    sole_socket: u16,
    upper_axis_local: math.Vec2,
    lower_axis_local: math.Vec2,
    upper_length: f32,
    lower_length: f32,
    character_local_bend: Bend,

    pub fn init(
        definition: *const skeleton.SkeletonDefinition,
        foot: AnatomicalFoot,
        input: BindingInput,
    ) !Binding {
        const hip = try definition.bone(input.hip_bone);
        const knee = try definition.bone(input.knee_bone);
        const ankle = try definition.bone(input.ankle_bone);
        const sole = try definition.socket(input.sole_socket);
        if (hip.parent_index == skeleton.no_parent) return error.LegRootRequiresParent;
        if (knee.parent_index != input.hip_bone) return error.InvalidKneeBoneParent;
        if (ankle.parent_index != input.knee_bone) return error.InvalidAnkleBoneParent;
        if (sole.parent_bone != input.ankle_bone) return error.InvalidSoleSocketParent;
        if (try definition.socketIndex(foot.socketSemantic()) != input.sole_socket) return error.AnatomicalSoleMismatch;

        const upper_axis = knee.rest_local.translation;
        const ankle_to_knee = try ankle.rest_local.localToParent();
        const sole_to_ankle = try sole.local_to_bone.localToParent();
        const lower_axis = ankle_to_knee.mul(sole_to_ankle).transformPoint(math.Vec2.zero);
        const upper_length = upper_axis.length();
        const lower_length = lower_axis.length();
        if (!upper_axis.isFinite() or !lower_axis.isFinite() or
            !std.math.isFinite(upper_length) or !std.math.isFinite(lower_length) or
            upper_length < two_bone.minimum_segment_length or lower_length < two_bone.minimum_segment_length)
        {
            return error.InvalidLegSegmentLength;
        }
        return .{
            .foot = foot,
            .hip_bone = input.hip_bone,
            .knee_bone = input.knee_bone,
            .ankle_bone = input.ankle_bone,
            .sole_socket = input.sole_socket,
            .upper_axis_local = upper_axis,
            .lower_axis_local = lower_axis,
            .upper_length = upper_length,
            .lower_length = lower_length,
            .character_local_bend = input.character_local_bend,
        };
    }

    pub fn initLeft(definition: *const skeleton.SkeletonDefinition) !Binding {
        return init(definition, .left, .{
            .hip_bone = try definition.boneIndex(.left_thigh),
            .knee_bone = try definition.boneIndex(.left_shin),
            .ankle_bone = try definition.boneIndex(.left_foot),
            .sole_socket = try definition.socketIndex(.left_foot),
            .character_local_bend = .positive,
        });
    }

    pub fn initRight(definition: *const skeleton.SkeletonDefinition) !Binding {
        return init(definition, .right, .{
            .hip_bone = try definition.boneIndex(.right_thigh),
            .knee_bone = try definition.boneIndex(.right_shin),
            .ankle_bone = try definition.boneIndex(.right_foot),
            .sole_socket = try definition.socketIndex(.right_foot),
            .character_local_bend = .positive,
        });
    }
};

pub const Metrics = struct {
    weight: f32,
    reachability: Reachability,
    target_position: math.Vec2,
    pre_ik_sole_position: math.Vec2,
    post_ik_sole_position: math.Vec2,
    target_error: f32,
    hip_position: math.Vec2,
    knee_position: math.Vec2,
    upper_length: f32,
    lower_length: f32,
    solved_upper_length: f32,
    solved_lower_length: f32,
    bend: Bend,
};

pub const Application = struct {
    pre_hip_local: math.Transform2D,
    pre_knee_local: math.Transform2D,
    metrics: Metrics,
};

pub fn apply(
    binding: Binding,
    mutable_pose: *pose.Pose,
    definition: *const skeleton.SkeletonDefinition,
    character_to_world: math.Transform2D,
    target_world: math.Vec2,
    bend_world: Bend,
    weight: f32,
) !Application {
    try mutable_pose.validateCompatibility(definition);
    if (!mutable_pose.evaluated) return error.PoseNotEvaluated;
    if (!target_world.isFinite() or !std.math.isFinite(weight) or weight < 0 or weight > 1) return error.InvalidIkApplication;

    const pre_hip_local = mutable_pose.local_transforms[binding.hip_bone];
    const pre_knee_local = mutable_pose.local_transforms[binding.knee_bone];
    const hip_definition = try definition.bone(binding.hip_bone);
    const parent_world = try mutable_pose.worldForBone(definition, hip_definition.parent_index);
    const hip = (try mutable_pose.worldForBone(definition, binding.hip_bone)).translationPart();
    const pre_knee = (try mutable_pose.worldForBone(definition, binding.knee_bone)).translationPart();
    const pre_sole = try socketPosition(mutable_pose.*, definition, binding.sole_socket);
    const solved = try two_bone.solve(.{
        .root = hip,
        .upper_length = binding.upper_length,
        .lower_length = binding.lower_length,
        .target = target_world,
        .bend = bend_world,
        .reference_direction = pre_knee.sub(hip),
    });

    const upper_axis_scaled = binding.upper_axis_local.componentMul(pre_hip_local.scale);
    const solved_hip_rotation = try localRotationForWorldDirection(parent_world, upper_axis_scaled, solved.middle_position.sub(hip));
    var solved_hip_local = pre_hip_local;
    solved_hip_local.rotation_radians = solved_hip_rotation;
    const solved_hip_world = parent_world.mul(try solved_hip_local.localToParent());
    const lower_axis_scaled = binding.lower_axis_local.componentMul(pre_knee_local.scale);
    const solved_knee_rotation = try localRotationForWorldDirection(solved_hip_world, lower_axis_scaled, solved.end_position.sub(solved.middle_position));

    var blended_hip = pre_hip_local;
    blended_hip.rotation_radians = try blendRotation(pre_hip_local.rotation_radians, solved_hip_rotation, weight);
    var blended_knee = pre_knee_local;
    blended_knee.rotation_radians = try blendRotation(pre_knee_local.rotation_radians, solved_knee_rotation, weight);
    try mutable_pose.setLocal(binding.hip_bone, blended_hip);
    try mutable_pose.setLocal(binding.knee_bone, blended_knee);
    try mutable_pose.evaluateWorld(definition, character_to_world);

    const post_sole = try socketPosition(mutable_pose.*, definition, binding.sole_socket);
    const post_hip = (try mutable_pose.worldForBone(definition, binding.hip_bone)).translationPart();
    const post_knee = (try mutable_pose.worldForBone(definition, binding.knee_bone)).translationPart();
    const target_error = post_sole.sub(target_world).length();
    const solved_upper_length = post_knee.sub(post_hip).length();
    const solved_lower_length = post_sole.sub(post_knee).length();
    if (!post_sole.isFinite() or !post_knee.isFinite() or !std.math.isFinite(target_error) or
        !std.math.isFinite(solved_upper_length) or !std.math.isFinite(solved_lower_length))
    {
        return error.NonFiniteIkApplicationResult;
    }
    return .{
        .pre_hip_local = pre_hip_local,
        .pre_knee_local = pre_knee_local,
        .metrics = .{
            .weight = weight,
            .reachability = solved.reachability,
            .target_position = target_world,
            .pre_ik_sole_position = pre_sole,
            .post_ik_sole_position = post_sole,
            .target_error = target_error,
            .hip_position = post_hip,
            .knee_position = post_knee,
            .upper_length = binding.upper_length,
            .lower_length = binding.lower_length,
            .solved_upper_length = solved_upper_length,
            .solved_lower_length = solved_lower_length,
            .bend = bend_world,
        },
    };
}

pub fn restore(
    binding: Binding,
    mutable_pose: *pose.Pose,
    definition: *const skeleton.SkeletonDefinition,
    character_to_world: math.Transform2D,
    hip_local: math.Transform2D,
    knee_local: math.Transform2D,
) !void {
    try mutable_pose.setLocal(binding.hip_bone, hip_local);
    try mutable_pose.setLocal(binding.knee_bone, knee_local);
    try mutable_pose.evaluateWorld(definition, character_to_world);
}

fn blendRotation(from: f32, to: f32, weight: f32) !f32 {
    if (!std.math.isFinite(weight) or weight < 0 or weight > 1) return error.InvalidIkBlendWeight;
    if (weight == 0) return from;
    if (weight == 1) return to;
    return math.interpolation.lerpAngleShortest(from, to, weight);
}

fn socketPosition(current_pose: pose.Pose, definition: *const skeleton.SkeletonDefinition, socket_index: u16) !math.Vec2 {
    const socket_definition = try definition.socket(socket_index);
    const parent_world = try current_pose.worldForBone(definition, socket_definition.parent_bone);
    return parent_world.mul(try socket_definition.local_to_bone.localToParent()).transformPoint(math.Vec2.zero);
}

fn localRotationForWorldDirection(parent_world: math.Mat3, local_axis: math.Vec2, desired_world: math.Vec2) !f32 {
    if (!parent_world.isFinite() or !local_axis.isFinite() or !desired_world.isFinite() or
        local_axis.lengthSquared() < rotation_axis_epsilon * rotation_axis_epsilon or
        desired_world.lengthSquared() < rotation_axis_epsilon * rotation_axis_epsilon)
    {
        return error.InvalidIkRotationAxis;
    }
    const values = parent_world.values;
    const determinant = values[0] * values[4] - values[3] * values[1];
    if (!std.math.isFinite(determinant) or @abs(determinant) < rotation_axis_epsilon) return error.SingularIkParentTransform;
    const desired_parent = math.Vec2.init(
        (values[4] * desired_world.x - values[3] * desired_world.y) / determinant,
        (-values[1] * desired_world.x + values[0] * desired_world.y) / determinant,
    );
    return try math.interpolation.wrapAngle(
        std.math.atan2(desired_parent.y, desired_parent.x) - std.math.atan2(local_axis.y, local_axis.x),
    );
}
