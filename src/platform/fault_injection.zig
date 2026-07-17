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
