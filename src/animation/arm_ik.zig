const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const pose = @import("pose");
const two_bone = @import("two_bone_ik");

pub const Bend = two_bone.Bend;
pub const Reachability = two_bone.Reachability;

pub const rotation_axis_epsilon: f32 = 0.000001;

pub const BindingInput = struct {
    root_bone: u16,
    middle_bone: u16,
    hand_bone: u16,
    end_socket: u16,
    character_local_bend: Bend,
};

pub const Binding = struct {
    root_bone: u16,
    middle_bone: u16,
    hand_bone: u16,
    end_socket: u16,
    upper_axis_local: math.Vec2,
    lower_axis_local: math.Vec2,
    upper_length: f32,
    lower_length: f32,
    character_local_bend: Bend,

    pub fn init(definition: *const skeleton.SkeletonDefinition, input: BindingInput) !Binding {
        const root = try definition.bone(input.root_bone);
        const middle = try definition.bone(input.middle_bone);
        const hand = try definition.bone(input.hand_bone);
        const end_socket = try definition.socket(input.end_socket);
        if (root.parent_index == skeleton.no_parent) return error.ArmRootRequiresParent;
        if (middle.parent_index != input.root_bone) return error.InvalidMiddleBoneParent;
        if (hand.parent_index != input.middle_bone) return error.InvalidHandBoneParent;
        if (end_socket.parent_bone != input.hand_bone) return error.InvalidEndSocketParent;

        const upper_axis = middle.rest_local.translation;
        const hand_to_middle = try hand.rest_local.localToParent();
        const socket_to_hand = try end_socket.local_to_bone.localToParent();
        const lower_axis = hand_to_middle.mul(socket_to_hand).transformPoint(math.Vec2.zero);
        const upper_length = upper_axis.length();
        const lower_length = lower_axis.length();
        if (!upper_axis.isFinite() or !lower_axis.isFinite() or
            !std.math.isFinite(upper_length) or !std.math.isFinite(lower_length) or
            upper_length < two_bone.minimum_segment_length or lower_length < two_bone.minimum_segment_length)
        {
            return error.InvalidArmSegmentLength;
        }
        return .{
            .root_bone = input.root_bone,
            .middle_bone = input.middle_bone,
            .hand_bone = input.hand_bone,
            .end_socket = input.end_socket,
            .upper_axis_local = upper_axis,
            .lower_axis_local = lower_axis,
            .upper_length = upper_length,
            .lower_length = lower_length,
            .character_local_bend = input.character_local_bend,
        };
    }

    pub fn initRightArm(definition: *const skeleton.SkeletonDefinition) !Binding {
        return init(definition, .{
            .root_bone = try definition.boneIndex(.right_upper_arm),
            .middle_bone = try definition.boneIndex(.right_forearm),
            .hand_bone = try definition.boneIndex(.right_hand),
            .end_socket = try definition.socketIndex(.right_hand),
            .character_local_bend = .positive,
        });
    }
};

pub const Metrics = struct {
    weight: f32,
    reachability: Reachability,
    target_position: math.Vec2,
    pre_ik_hand_position: math.Vec2,
    post_ik_hand_position: math.Vec2,
    target_error: f32,
    shoulder_position: math.Vec2,
    elbow_position: math.Vec2,
    upper_length: f32,
    lower_length: f32,
    solved_upper_length: f32,
    solved_lower_length: f32,
    bend: Bend,
};

pub const Application = struct {
    pre_root_local: math.Transform2D,
    pre_middle_local: math.Transform2D,
    metrics: Metrics,
};

pub fn blendRotation(from: f32, to: f32, weight: f32) !f32 {
    if (!std.math.isFinite(weight) or weight < 0 or weight > 1) return error.InvalidIkBlendWeight;
    return math.interpolation.lerpAngleShortest(from, to, weight);
}

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

    const pre_root_local = mutable_pose.local_transforms[binding.root_bone];
    const pre_middle_local = mutable_pose.local_transforms[binding.middle_bone];
    const root_definition = try definition.bone(binding.root_bone);
    const parent_world = try mutable_pose.worldForBone(definition, root_definition.parent_index);
    const shoulder = (try mutable_pose.worldForBone(definition, binding.root_bone)).translationPart();
    const pre_elbow = (try mutable_pose.worldForBone(definition, binding.middle_bone)).translationPart();
    const pre_hand = try socketPosition(mutable_pose.*, definition, binding.end_socket);
    const reference_direction = pre_elbow.sub(shoulder);
    const solved = try two_bone.solve(.{
        .root = shoulder,
        .upper_length = binding.upper_length,
        .lower_length = binding.lower_length,
        .target = target_world,
        .bend = bend_world,
        .reference_direction = reference_direction,
    });

    const upper_axis_scaled = binding.upper_axis_local.componentMul(pre_root_local.scale);
    const solved_root_rotation = try localRotationForWorldDirection(parent_world, upper_axis_scaled, solved.middle_position.sub(shoulder));
    var solved_root_local = pre_root_local;
    solved_root_local.rotation_radians = solved_root_rotation;
    const solved_root_world = parent_world.mul(try solved_root_local.localToParent());
    const lower_axis_scaled = binding.lower_axis_local.componentMul(pre_middle_local.scale);
    const solved_middle_rotation = try localRotationForWorldDirection(solved_root_world, lower_axis_scaled, solved.end_position.sub(solved.middle_position));

    var blended_root = pre_root_local;
    blended_root.rotation_radians = try blendRotation(pre_root_local.rotation_radians, solved_root_rotation, weight);
    var blended_middle = pre_middle_local;
    blended_middle.rotation_radians = try blendRotation(pre_middle_local.rotation_radians, solved_middle_rotation, weight);
    try mutable_pose.setLocal(binding.root_bone, blended_root);
    try mutable_pose.setLocal(binding.middle_bone, blended_middle);
    try mutable_pose.evaluateWorld(definition, character_to_world);

    const post_hand = try socketPosition(mutable_pose.*, definition, binding.end_socket);
    const post_shoulder = (try mutable_pose.worldForBone(definition, binding.root_bone)).translationPart();
    const post_elbow = (try mutable_pose.worldForBone(definition, binding.middle_bone)).translationPart();
    const target_error = post_hand.sub(target_world).length();
    const solved_upper_length = post_elbow.sub(post_shoulder).length();
    const solved_lower_length = post_hand.sub(post_elbow).length();
    if (!post_hand.isFinite() or !post_elbow.isFinite() or !std.math.isFinite(target_error) or
        !std.math.isFinite(solved_upper_length) or !std.math.isFinite(solved_lower_length))
    {
        return error.NonFiniteIkApplicationResult;
    }
    return .{
        .pre_root_local = pre_root_local,
        .pre_middle_local = pre_middle_local,
        .metrics = .{
            .weight = weight,
            .reachability = solved.reachability,
            .target_position = target_world,
            .pre_ik_hand_position = pre_hand,
            .post_ik_hand_position = post_hand,
            .target_error = target_error,
            .shoulder_position = post_shoulder,
            .elbow_position = post_elbow,
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
    root_local: math.Transform2D,
    middle_local: math.Transform2D,
) !void {
    try mutable_pose.setLocal(binding.root_bone, root_local);
    try mutable_pose.setLocal(binding.middle_bone, middle_local);
    try mutable_pose.evaluateWorld(definition, character_to_world);
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
