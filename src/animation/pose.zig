const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const fault_injection = @import("fault_injection");

pub const Pose = struct {
    allocator: std.mem.Allocator,
    local_transforms: []math.Transform2D,
    world_transforms: []math.Mat3,
    definition_token: usize,
    evaluated: bool = false,

    pub fn init(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !Pose {
        const locals = allocator.alloc(math.Transform2D, definition.boneCount()) catch return error.AllocationFailure;
        errdefer allocator.free(locals);
        try after(injector, .pose_local_transform_allocation);
        const worlds = allocator.alloc(math.Mat3, definition.boneCount()) catch return error.AllocationFailure;
        errdefer allocator.free(worlds);
        try after(injector, .pose_world_transform_allocation);

        for (definition.bones, 0..) |bone, index| locals[index] = bone.rest_local;
        for (worlds) |*world| world.* = math.Mat3.identity();
        return .{
            .allocator = allocator,
            .local_transforms = locals,
            .world_transforms = worlds,
            .definition_token = definition.compatibilityToken(),
        };
    }

    pub fn deinit(pose: *Pose) void {
        pose.allocator.free(pose.world_transforms);
        pose.allocator.free(pose.local_transforms);
        pose.* = undefined;
    }

    pub fn validateCompatibility(pose: Pose, definition: *const skeleton.SkeletonDefinition) !void {
        if (pose.local_transforms.len != definition.boneCount() or pose.world_transforms.len != definition.boneCount()) {
            std.log.warn("pose compatibility: expected bone_count={d}, local_count={d}, world_count={d}", .{ definition.boneCount(), pose.local_transforms.len, pose.world_transforms.len });
            return error.PoseLengthMismatch;
        }
        if (pose.definition_token != definition.compatibilityToken()) return error.PoseDefinitionMismatch;
    }

    pub fn restoreAllToRest(pose: *Pose, definition: *const skeleton.SkeletonDefinition) !void {
        try pose.validateCompatibility(definition);
        for (definition.bones, 0..) |bone, index| pose.local_transforms[index] = bone.rest_local;
        pose.evaluated = false;
    }

    pub fn restoreBoneToRest(pose: *Pose, definition: *const skeleton.SkeletonDefinition, bone_index: u16) !void {
        try pose.validateCompatibility(definition);
        const bone = try definition.bone(bone_index);
        pose.local_transforms[bone_index] = bone.rest_local;
        pose.evaluated = false;
    }

    pub fn setLocal(pose: *Pose, bone_index: u16, transform: math.Transform2D) !void {
        if (bone_index >= pose.local_transforms.len) return error.InvalidBoneIndex;
        try transform.validate();
        pose.local_transforms[bone_index] = transform;
        pose.evaluated = false;
    }

    pub fn setLocalSemantic(pose: *Pose, definition: *const skeleton.SkeletonDefinition, semantic: skeleton.BoneSemantic, transform: math.Transform2D) !void {
        try pose.validateCompatibility(definition);
        try pose.setLocal(try definition.boneIndex(semantic), transform);
    }

    pub fn localForSemantic(pose: Pose, definition: *const skeleton.SkeletonDefinition, semantic: skeleton.BoneSemantic) !math.Transform2D {
        try pose.validateCompatibility(definition);
        return pose.local_transforms[try definition.boneIndex(semantic)];
    }

    pub fn evaluateWorld(pose: *Pose, definition: *const skeleton.SkeletonDefinition, character_to_world: math.Transform2D) !void {
        try pose.validateCompatibility(definition);
        try character_to_world.validate();
        for (pose.local_transforms, 0..) |local, index| {
            local.validate() catch {
                std.log.warn("pose evaluation: non-finite local transform at bone={d} name={s}", .{ index, definition.bones[index].debug_name.slice() });
                return error.NonFiniteTransform;
            };
        }

        const character_matrix = try character_to_world.localToParent();
        for (definition.evaluation_order) |bone_index| {
            const bone = definition.bones[bone_index];
            const local_matrix = try pose.local_transforms[bone_index].localToParent();
            pose.world_transforms[bone_index] = if (bone.parent_index == skeleton.no_parent)
                character_matrix.mul(local_matrix)
            else
                pose.world_transforms[bone.parent_index].mul(local_matrix);
        }
        pose.evaluated = true;
    }

    pub fn worldForBone(pose: Pose, definition: *const skeleton.SkeletonDefinition, bone_index: u16) !math.Mat3 {
        try pose.validateCompatibility(definition);
        if (!pose.evaluated) return error.PoseNotEvaluated;
        if (bone_index >= pose.world_transforms.len) return error.InvalidBoneIndex;
        return pose.world_transforms[bone_index];
    }

    pub fn worldForSemantic(pose: Pose, definition: *const skeleton.SkeletonDefinition, semantic: skeleton.BoneSemantic) !math.Mat3 {
        return pose.worldForBone(definition, try definition.boneIndex(semantic));
    }

    pub fn socketWorld(pose: Pose, definition: *const skeleton.SkeletonDefinition, semantic: skeleton.SocketSemantic) !math.Mat3 {
        try pose.validateCompatibility(definition);
        if (!pose.evaluated) return error.PoseNotEvaluated;
        const socket_definition = try definition.socket(try definition.socketIndex(semantic));
        return pose.world_transforms[socket_definition.parent_bone].mul(try socket_definition.local_to_bone.localToParent());
    }

    pub fn socketPosition(pose: Pose, definition: *const skeleton.SkeletonDefinition, semantic: skeleton.SocketSemantic) !math.Vec2 {
        return (try pose.socketWorld(definition, semantic)).transformPoint(math.Vec2.zero);
    }
};

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
