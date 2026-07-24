const std = @import("std");

pub const InitStage = enum {
    sprite_batch_cpu_allocation,
    sdl_initialization,
    window_creation,
    gpu_device_creation,
    window_claim,
    shader_creation,
    sampler_creation,
    texture_creation,
    shared_quad_vertex_buffer,
    shared_quad_index_buffer,
    transfer_buffer_creation,
    upload,
    instance_frame_slots,
    pipeline_creation,
    capacity_growth_replacement,
    frame_fence_acquisition,
    skeleton_definition_allocation,
    socket_definition_allocation,
    attachment_point_allocation,
    body_region_allocation,
    visual_group_allocation,
    rig_module_allocation,
    visual_attachment_allocation,
    pose_local_transform_allocation,
    pose_world_transform_allocation,
    appearance_runtime_allocation,
    humanoid_character_initialization,
    clip_definition_allocation,
    track_allocation,
    translation_key_allocation,
    rotation_key_allocation,
    scale_key_allocation,
    event_allocation,
    state_machine_state_allocation,
    transition_allocation,
    animator_pose_buffer_allocation,
    animator_event_buffer_allocation,
    partial_authored_animation_library,
    collision_world_collider_allocation,
    partial_controller_demo_creation,
};

pub const all_stages = std.enums.values(InitStage);
pub const initialization_stages = [_]InitStage{
    .sprite_batch_cpu_allocation,
    .sdl_initialization,
    .window_creation,
    .gpu_device_creation,
    .window_claim,
    .shader_creation,
    .sampler_creation,
    .texture_creation,
    .shared_quad_vertex_buffer,
    .shared_quad_index_buffer,
    .transfer_buffer_creation,
    .upload,
    .instance_frame_slots,
    .pipeline_creation,
};
pub const runtime_stages = [_]InitStage{ .capacity_growth_replacement, .frame_fence_acquisition };
pub const humanoid_initialization_stages = [_]InitStage{
    .skeleton_definition_allocation,
    .socket_definition_allocation,
    .attachment_point_allocation,
    .body_region_allocation,
    .visual_group_allocation,
    .rig_module_allocation,
    .visual_attachment_allocation,
    .pose_local_transform_allocation,
    .pose_world_transform_allocation,
    .appearance_runtime_allocation,
    .humanoid_character_initialization,
};
pub const animation_initialization_stages = [_]InitStage{
    .clip_definition_allocation,
    .track_allocation,
    .translation_key_allocation,
    .rotation_key_allocation,
    .scale_key_allocation,
    .event_allocation,
    .state_machine_state_allocation,
    .transition_allocation,
    .animator_pose_buffer_allocation,
    .animator_event_buffer_allocation,
    .partial_authored_animation_library,
};
pub const controller_initialization_stages = [_]InitStage{
    .collision_world_collider_allocation,
    .partial_controller_demo_creation,
};

pub const Injector = struct {
    fail_after: InitStage,

    pub fn after(self: Injector, stage: InitStage) error{InjectedInitializationFailure}!void {
        if (self.fail_after == stage) return error.InjectedInitializationFailure;
    }
};

pub fn parse(name: []const u8) ?InitStage {
    inline for (all_stages) |stage| {
        if (std.mem.eql(u8, name, @tagName(stage))) return stage;
    }
    return null;
}
