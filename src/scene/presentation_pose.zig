const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const pose = @import("pose");
const appearance = @import("appearance");
const anatomy = @import("anatomy");

const front_arm_x_compression: f32 = 0.90;
const side_arm_x_compression: f32 = 0.68;

pub const FrontProjection = struct {
    bone_world: [skeleton.maximum_bones]math.Mat3 = [_]math.Mat3{math.Mat3.identity()} ** skeleton.maximum_bones,
    attachment_point_world: [appearance.maximum_attachment_points]math.Mat3 =
        [_]math.Mat3{math.Mat3.identity()} ** appearance.maximum_attachment_points,
    module_joint_world: [appearance.maximum_total_module_joints]math.Mat3 =
        [_]math.Mat3{math.Mat3.identity()} ** appearance.maximum_total_module_joints,
    module_socket_world: [appearance.maximum_total_module_sockets]math.Mat3 =
        [_]math.Mat3{math.Mat3.identity()} ** appearance.maximum_total_module_sockets,
    bone_count: usize = 0,
    attachment_point_count: usize = 0,
    module_joint_count: usize = 0,
    module_socket_count: usize = 0,

    pub fn init(
        skeleton_definition: *const skeleton.SkeletonDefinition,
        source_pose: pose.Pose,
        appearance_definition: appearance.DefinitionView,
        appearance_runtime: appearance.Runtime,
        world_position: math.Vec2,
    ) !FrontProjection {
        try source_pose.validateCompatibility(skeleton_definition);
        try appearance_runtime.validateCompatibility(appearance_definition);
        if (!source_pose.evaluated) return error.PoseNotEvaluated;
        if (!world_position.isFinite()) return error.InvalidNonFiniteTransform;

        var projection = FrontProjection{
            .bone_count = skeleton_definition.boneCount(),
            .attachment_point_count = appearance_definition.attachment_points.len,
            .module_joint_count = appearance_definition.module_joints.len,
            .module_socket_count = appearance_definition.module_sockets.len,
        };
        var remapped_locals = [_]math.Transform2D{math.Transform2D.identity()} ** skeleton.maximum_bones;
        @memcpy(
            remapped_locals[0..skeleton_definition.boneCount()],
            source_pose.local_transforms,
        );
        try remapArm(
            skeleton_definition,
            &remapped_locals,
            .left_upper_arm,
            -std.math.pi / 2.0,
            true,
        );
        try remapArm(
            skeleton_definition,
            &remapped_locals,
            .right_upper_arm,
            -std.math.pi / 2.0,
            false,
        );
        try remapArm(
            skeleton_definition,
            &remapped_locals,
            .left_forearm,
            0,
            true,
        );
        try remapArm(
            skeleton_definition,
            &remapped_locals,
            .right_forearm,
            0,
            false,
        );
        try remapArm(
            skeleton_definition,
            &remapped_locals,
            .left_hand,
            0,
            true,
        );
        try remapArm(
            skeleton_definition,
            &remapped_locals,
            .right_hand,
            0,
            false,
        );

        const character_matrix = math.Mat3.translation(world_position);
        for (skeleton_definition.evaluation_order) |bone_index| {
            const bone = skeleton_definition.bones[bone_index];
            const local_matrix = try remapped_locals[bone_index].localToParent();
            projection.bone_world[bone_index] = if (bone.parent_index == skeleton.no_parent)
                character_matrix.mul(local_matrix)
            else
                projection.bone_world[bone.parent_index].mul(local_matrix);
        }

        try compressArmRoots(
            &projection,
            skeleton_definition,
            world_position.x,
            front_arm_x_compression,
        );
        try projection.rebuildDerivedWorlds(
            appearance_definition,
            appearance_runtime,
        );
        return projection;
    }

    fn rebuildDerivedWorlds(
        projection: *FrontProjection,
        appearance_definition: appearance.DefinitionView,
        appearance_runtime: appearance.Runtime,
    ) !void {
        for (appearance_definition.attachment_point_evaluation_order) |raw_index| {
            const point = appearance_definition.attachment_points[raw_index];
            const parent_world = switch (point.parent) {
                .canonical_bone => |bone_index| projection.bone_world[bone_index],
                .attachment_point => |parent_id| projection.attachment_point_world[parent_id.index()],
            };
            projection.attachment_point_world[point.id.index()] =
                parent_world.mul(try point.local_to_parent.localToParent());
        }

        for (appearance_definition.module_joint_evaluation_order) |global_index| {
            const joint = appearance_definition.module_joints[global_index];
            const parent_world = if (joint.parent_joint_global == appearance.no_index)
                try projection.moduleOrigin(appearance_definition, joint.module_id)
            else
                projection.module_joint_world[joint.parent_joint_global];
            projection.module_joint_world[global_index] = parent_world.mul(
                try appearance_runtime.module_joint_local[global_index].localToParent(),
            );
        }

        for (appearance_definition.module_sockets, 0..) |module_socket, global_index| {
            const parent_world = if (module_socket.parent_joint_global == appearance.no_index)
                try projection.moduleOrigin(appearance_definition, module_socket.module_id)
            else
                projection.module_joint_world[module_socket.parent_joint_global];
            projection.module_socket_world[global_index] =
                parent_world.mul(try module_socket.local_to_parent.localToParent());
        }
    }

    pub fn initSide(
        skeleton_definition: *const skeleton.SkeletonDefinition,
        source_pose: pose.Pose,
        appearance_definition: appearance.DefinitionView,
        appearance_runtime: appearance.Runtime,
        world_position: math.Vec2,
        reflect_x: bool,
    ) !FrontProjection {
        var projection = try FrontProjection.init(
            skeleton_definition,
            source_pose,
            appearance_definition,
            appearance_runtime,
            world_position,
        );
        try compressArmRoots(
            &projection,
            skeleton_definition,
            world_position.x,
            side_arm_x_compression,
        );
        try projection.rebuildDerivedWorlds(
            appearance_definition,
            appearance_runtime,
        );
        if (!reflect_x) return projection;

        const reflection = math.Mat3.translation(world_position)
            .mul(math.Mat3.nonuniformScale(.{ .x = -1, .y = 1 }))
            .mul(math.Mat3.translation(.{
            .x = -world_position.x,
            .y = -world_position.y,
        }));
        for (projection.bone_world[0..projection.bone_count]) |*world| {
            world.* = reflection.mul(world.*);
        }
        for (projection.attachment_point_world[0..projection.attachment_point_count]) |*world| {
            world.* = reflection.mul(world.*);
        }
        for (projection.module_joint_world[0..projection.module_joint_count]) |*world| {
            world.* = reflection.mul(world.*);
        }
        for (projection.module_socket_world[0..projection.module_socket_count]) |*world| {
            world.* = reflection.mul(world.*);
        }
        return projection;
    }

    pub fn attachmentPointWorld(
        projection: FrontProjection,
        id: appearance.AttachmentPointId,
    ) !math.Mat3 {
        if (id.index() >= projection.attachment_point_count) return error.InvalidAttachmentPointId;
        return projection.attachment_point_world[id.index()];
    }

    pub fn moduleSocketWorldGlobal(projection: FrontProjection, global_index: u16) !math.Mat3 {
        if (global_index >= projection.module_socket_count) return error.InvalidModuleSocketId;
        return projection.module_socket_world[global_index];
    }

    pub fn visualWorld(
        projection: FrontProjection,
        runtime: appearance.Runtime,
        visual: appearance.VisualAttachment,
    ) !math.Mat3 {
        if (visual.id.index() >= runtime.visual_states.len) return error.InvalidVisualAttachmentId;
        const source_world = switch (visual.transform_source) {
            .canonical_bone => |bone_index| projection.bone_world[bone_index],
            .attachment_point => |point_id| projection.attachment_point_world[point_id.index()],
            .module_joint, .module_socket, .visual_attachment => return error.UnsupportedFrontProjectionSource,
        };
        const state = runtime.visual_states[visual.id.index()];
        const base_world = source_world
            .mul(try visual.local_to_source.localToParent())
            .mul(try state.local_deformation.localToParent());
        return if (visual.secondary_motion) |motion_definition|
            base_world.mul(try (try state.secondary.resolvedTransform(motion_definition)).localToParent())
        else
            base_world;
    }

    fn moduleOrigin(
        projection: FrontProjection,
        definition: appearance.DefinitionView,
        module_id: appearance.RigModuleId,
    ) !math.Mat3 {
        if (module_id.index() >= definition.rig_modules.len) return error.InvalidRigModuleId;
        const module = definition.rig_modules[module_id.index()];
        return (try projection.attachmentPointWorld(module.parent_attachment_point))
            .mul(try module.local_to_attachment_point.localToParent());
    }
};

pub const FrontAnatomyProjection = struct {
    part_binding_world: [anatomy.maximum_part_instances]math.Mat3 =
        [_]math.Mat3{math.Mat3.identity()} ** anatomy.maximum_part_instances,
    part_world: [anatomy.maximum_part_instances]math.Mat3 =
        [_]math.Mat3{math.Mat3.identity()} ** anatomy.maximum_part_instances,
    socket_world: [anatomy.maximum_part_sockets]math.Mat3 =
        [_]math.Mat3{math.Mat3.identity()} ** anatomy.maximum_part_sockets,
    part_count: usize = 0,
    socket_count: usize = 0,

    pub fn init(
        front: FrontProjection,
        definition: anatomy.DefinitionView,
        runtime: anatomy.Runtime,
    ) !FrontAnatomyProjection {
        try runtime.validateCompatibility(definition);
        var projection = FrontAnatomyProjection{
            .part_count = definition.part_instances.len,
            .socket_count = definition.instance_sockets.len,
        };
        for (definition.instance_evaluation_order) |raw_index| {
            const part = definition.part_instances[raw_index];
            if (!try runtime.isPartActive(definition, part.id)) continue;
            const parent_world = switch (part.parent) {
                .attachment_point => |id| try front.attachmentPointWorld(id),
                .body_part_socket => |id| projection.socket_world[id.index()],
                .module_socket => |global_index| try front.moduleSocketWorldGlobal(global_index),
            };
            const binding_world =
                parent_world.mul(try part.local_to_parent.localToParent());
            const world = binding_world.mul(try (try runtime.resolvedDeformationForPart(
                definition,
                part.id,
                .{},
            )).localToParent());
            projection.part_binding_world[part.id.index()] = binding_world;
            projection.part_world[part.id.index()] = world;
            for (definition.instance_sockets[part.instance_socket_start .. part.instance_socket_start + part.instance_socket_count]) |socket| {
                projection.socket_world[socket.id.index()] =
                    world.mul(try socket.local_to_part.localToParent());
            }
        }
        return projection;
    }

    pub fn partBindingWorld(
        projection: FrontAnatomyProjection,
        part_id: anatomy.BodyPartInstanceId,
    ) !math.Mat3 {
        if (part_id.index() >= projection.part_count) return error.InvalidBodyPartInstanceId;
        return projection.part_binding_world[part_id.index()];
    }
};

fn remapArm(
    definition: *const skeleton.SkeletonDefinition,
    locals: *[skeleton.maximum_bones]math.Transform2D,
    semantic: skeleton.BoneSemantic,
    front_rest_rotation: f32,
    mirror_delta: bool,
) !void {
    const index = try definition.boneIndex(semantic);
    const rest = definition.bones[index].rest_local.rotation_radians;
    const delta = try math.interpolation.signedShortestAngleDifference(
        rest,
        locals[index].rotation_radians,
    );
    locals[index].rotation_radians = front_rest_rotation + if (mirror_delta) -delta else delta;
}

fn compressArmRoots(
    projection: *FrontProjection,
    definition: *const skeleton.SkeletonDefinition,
    root_x: f32,
    factor: f32,
) !void {
    for ([_]skeleton.BoneSemantic{ .left_upper_arm, .right_upper_arm }) |semantic| {
        const arm_root = try definition.boneIndex(semantic);
        const shoulder_x = projection.bone_world[arm_root].translationPart().x;
        const delta_x = (shoulder_x - root_x) * (factor - 1);
        const adjustment = math.Mat3.translation(.{ .x = delta_x, .y = 0 });
        for (definition.bones, 0..) |_, bone_index| {
            if (isDescendantOf(definition, bone_index, arm_root)) {
                projection.bone_world[bone_index] =
                    adjustment.mul(projection.bone_world[bone_index]);
            }
        }
    }
}

fn isDescendantOf(
    definition: *const skeleton.SkeletonDefinition,
    bone_index: usize,
    ancestor_index: usize,
) bool {
    var current = bone_index;
    while (true) {
        if (current == ancestor_index) return true;
        const parent = definition.bones[current].parent_index;
        if (parent == skeleton.no_parent) return false;
        current = parent;
    }
}
