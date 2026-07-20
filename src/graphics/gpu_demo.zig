const std = @import("std");
const c = @import("sdl").c;
const fault_injection = @import("fault_injection");
const sprite = @import("sprite_batch");
const humanoid = @import("humanoid");
const animation_system = @import("animation_system");
const sdl_input = @import("sdl_input");
const fixed_step = @import("fixed_step");
const controller_demo = @import("controller_demo");

pub const DemoMode = enum {
    sprites,
    humanoid,
    animation,
    controller,
    secondary_motion,
};

const TimeMode = enum { normal, quarter_speed, paused };

const target_width: u32 = 640;
const target_height: u32 = 480;
const texture_width: u32 = 4;
const texture_height: u32 = 4;
const upload_texture_row_pitch: u32 = 256;
const texture_upload_size: u32 = upload_texture_row_pitch * texture_height;
const frame_slot_count: usize = 3;
const demonstration_sprite_count: usize = 1000;
const clear_color = c.SDL_FColor{ .r = 0.05, .g = 0.10, .b = 0.20, .a = 1.0 };

const QuadVertex = extern struct {
    local_position: [2]f32,
};

const CameraUniform = extern struct {
    viewport_data: [4]f32,
};

comptime {
    if (@sizeOf(QuadVertex) != 8 or @alignOf(QuadVertex) != 4) @compileError("QuadVertex layout must match one HLSL float2");
    if (@sizeOf(CameraUniform) != 16 or @alignOf(CameraUniform) != 4) @compileError("CameraUniform must match one HLSL float4");
}

const quad_vertices = [_]QuadVertex{
    .{ .local_position = .{ 0.0, 0.0 } },
    .{ .local_position = .{ 1.0, 0.0 } },
    .{ .local_position = .{ 1.0, 1.0 } },
    .{ .local_position = .{ 0.0, 1.0 } },
};

const quad_indices = [_]u16{ 0, 1, 2, 0, 2, 3 };

const texture_pixels = [_][4]u8{
    .{ 255, 0, 0, 255 }, .{ 255, 0, 0, 255 }, .{ 0, 255, 0, 255 },   .{ 0, 255, 0, 255 },
    .{ 255, 0, 0, 255 }, .{ 255, 0, 0, 255 }, .{ 0, 255, 0, 255 },   .{ 0, 255, 0, 255 },
    .{ 0, 0, 255, 255 }, .{ 0, 0, 255, 255 }, .{ 255, 255, 0, 255 }, .{ 255, 255, 0, 255 },
    .{ 0, 0, 255, 255 }, .{ 0, 0, 255, 255 }, .{ 255, 255, 0, 255 }, .{ 255, 255, 0, 255 },
};

const vertex_upload_offset: u32 = texture_upload_size;
const index_upload_offset: u32 = vertex_upload_offset + @sizeOf(@TypeOf(quad_vertices));
const static_upload_buffer_size: u32 = index_upload_offset + @sizeOf(@TypeOf(quad_indices));

const FrameSlot = struct {
    instance_buffer: ?*c.SDL_GPUBuffer = null,
    transfer_buffer: ?*c.SDL_GPUTransferBuffer = null,
    fence: ?*c.SDL_GPUFence = null,
};

const ResourceMetrics = struct {
    gpu_resource_creations: u64 = 0,
    gpu_resource_releases: u64 = 0,
    fence_acquisitions: u64 = 0,
    fence_releases: u64 = 0,
    frame_slot_fence_waits: u64 = 0,
    upload_buffer_growths: u64 = 0,
    frames_rendered: u64 = 0,
};

const ReadbackPixels = struct {
    outside: [4]u8,
    inside_a: [4]u8,
    inside_b: [4]u8,
    row_pitch: u32,
};

const HierarchyPositions = struct {
    right_shoulder: @TypeOf(humanoid.presentation_origin),
    right_elbow: @TypeOf(humanoid.presentation_origin),
    right_hand: @TypeOf(humanoid.presentation_origin),
    left_knee: @TypeOf(humanoid.presentation_origin),
    left_foot: @TypeOf(humanoid.presentation_origin),
};

const maximum_landing_evidence: usize = 16;

const LandingEvidence = struct {
    simulation_tick: u64 = 0,
    impact_speed: f32 = 0,
    impulse: f32 = 0,
    peak_displacement: f32 = 0,
};

pub const GpuDemo = struct {
    allocator: std.mem.Allocator,
    batch: ?sprite.SpriteBatch = null,
    sdl_initialized: bool = false,
    window_claimed: bool = false,
    window: ?*c.SDL_Window = null,
    device: ?*c.SDL_GPUDevice = null,
    vertex_shader: ?*c.SDL_GPUShader = null,
    fragment_shader: ?*c.SDL_GPUShader = null,
    sampler: ?*c.SDL_GPUSampler = null,
    sampled_texture: ?*c.SDL_GPUTexture = null,
    render_target: ?*c.SDL_GPUTexture = null,
    quad_vertex_buffer: ?*c.SDL_GPUBuffer = null,
    quad_index_buffer: ?*c.SDL_GPUBuffer = null,
    static_upload_transfer: ?*c.SDL_GPUTransferBuffer = null,
    pipeline: ?*c.SDL_GPUGraphicsPipeline = null,
    frame_slots: [frame_slot_count]FrameSlot = [_]FrameSlot{.{}} ** frame_slot_count,
    gpu_instance_capacity: usize = 0,
    current_frame_slot: usize = 0,
    resource_metrics: ResourceMetrics = .{},

    pub fn init(allocator: std.mem.Allocator, hidden: bool, injector: ?fault_injection.Injector) !GpuDemo {
        var self = GpuDemo{ .allocator = allocator };
        errdefer self.deinit();

        self.batch = try sprite.SpriteBatch.init(allocator, sprite.initial_capacity, 1);
        try after(injector, .sprite_batch_cpu_allocation);

        if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_GAMEPAD)) return failSdl("SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)", error.SdlInitializationFailure);
        self.sdl_initialized = true;
        try after(injector, .sdl_initialization);

        const window_flags: c.SDL_WindowFlags = if (hidden) c.SDL_WINDOW_HIDDEN else 0;
        self.window = c.SDL_CreateWindow("Authoritative SDL GPU sprite batch", target_width, target_height, window_flags);
        if (self.window == null) return failSdl("SDL_CreateWindow", error.WindowCreationFailure);
        try after(injector, .window_creation);

        try logAndVerifyDriverSupport();
        const properties = c.SDL_CreateProperties();
        if (properties == 0) return failSdl("SDL_CreateProperties for GPU device", error.GpuDeviceCreationFailure);
        defer c.SDL_DestroyProperties(properties);
        if (!c.SDL_SetBooleanProperty(properties, c.SDL_PROP_GPU_DEVICE_CREATE_DEBUGMODE_BOOLEAN, true) or
            !c.SDL_SetBooleanProperty(properties, c.SDL_PROP_GPU_DEVICE_CREATE_VERBOSE_BOOLEAN, true) or
            !c.SDL_SetStringProperty(properties, c.SDL_PROP_GPU_DEVICE_CREATE_NAME_STRING, "direct3d12") or
            !c.SDL_SetBooleanProperty(properties, c.SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXIL_BOOLEAN, true))
        {
            return failSdl("configure D3D12/DXIL-only GPU device properties", error.GpuDeviceCreationFailure);
        }

        self.device = c.SDL_CreateGPUDeviceWithProperties(properties);
        if (self.device == null) return failSdl("SDL_CreateGPUDeviceWithProperties(direct3d12, DXIL)", error.GpuDeviceCreationFailure);
        const actual_driver = c.SDL_GetGPUDeviceDriver(self.device.?);
        if (actual_driver == null) return failSdl("SDL_GetGPUDeviceDriver", error.GpuDeviceCreationFailure);
        const driver_name = std.mem.span(@as([*:0]const u8, @ptrCast(actual_driver)));
        std.log.info("actual SDL GPU driver: {s}", .{driver_name});
        if (!std.mem.eql(u8, driver_name, "direct3d12")) {
            std.log.err("required SDL GPU driver direct3d12, received {s}; no fallback is permitted", .{driver_name});
            return error.WrongGpuDriver;
        }
        if ((c.SDL_GetGPUShaderFormats(self.device.?) & c.SDL_GPU_SHADERFORMAT_DXIL) == 0) {
            std.log.err("SDL GPU device does not report DXIL support; generated shaders are DXIL", .{});
            return error.ShaderFormatMismatch;
        }
        std.log.info("generated shader format DXIL agrees with SDL_GPU_SHADERFORMAT_DXIL", .{});
        try after(injector, .gpu_device_creation);

        if (!c.SDL_ClaimWindowForGPUDevice(self.device.?, self.window.?)) return failSdl("SDL_ClaimWindowForGPUDevice", error.WindowClaimFailure);
        self.window_claimed = true;
        if (!c.SDL_SetGPUAllowedFramesInFlight(self.device.?, frame_slot_count)) return failSdl("SDL_SetGPUAllowedFramesInFlight(3)", error.FrameSlotInitializationFailure);
        try after(injector, .window_claim);

        self.vertex_shader = try createShader(self.device.?, "shaders\\sprite_vs.dxil", "VSMain", c.SDL_GPU_SHADERSTAGE_VERTEX, 0, 1);
        self.resource_metrics.gpu_resource_creations += 1;
        self.fragment_shader = try createShader(self.device.?, "shaders\\sprite_ps.dxil", "PSMain", c.SDL_GPU_SHADERSTAGE_FRAGMENT, 1, 0);
        self.resource_metrics.gpu_resource_creations += 1;
        try after(injector, .shader_creation);

        var sampler_info: c.SDL_GPUSamplerCreateInfo = std.mem.zeroes(c.SDL_GPUSamplerCreateInfo);
        sampler_info.min_filter = c.SDL_GPU_FILTER_NEAREST;
        sampler_info.mag_filter = c.SDL_GPU_FILTER_NEAREST;
        sampler_info.mipmap_mode = c.SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
        sampler_info.address_mode_u = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        sampler_info.address_mode_v = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        sampler_info.address_mode_w = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        self.sampler = c.SDL_CreateGPUSampler(self.device.?, &sampler_info);
        if (self.sampler == null) return failSdl("SDL_CreateGPUSampler", error.SamplerCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        try after(injector, .sampler_creation);

        const render_target_usage = c.SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | c.SDL_GPU_TEXTUREUSAGE_SAMPLER;
        if (!c.SDL_GPUTextureSupportsFormat(self.device.?, c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM, c.SDL_GPU_TEXTURETYPE_2D, c.SDL_GPU_TEXTUREUSAGE_SAMPLER) or
            !c.SDL_GPUTextureSupportsFormat(self.device.?, c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM, c.SDL_GPU_TEXTURETYPE_2D, render_target_usage))
        {
            return error.UnsupportedTextureFormat;
        }
        self.sampled_texture = createTexture(self.device.?, c.SDL_GPU_TEXTUREUSAGE_SAMPLER, texture_width, texture_height) orelse return failSdl("SDL_CreateGPUTexture(procedural texture)", error.TextureCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        self.render_target = createTexture(self.device.?, render_target_usage, target_width, target_height) orelse return failSdl("SDL_CreateGPUTexture(offscreen target)", error.TextureCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        try after(injector, .texture_creation);

        self.quad_vertex_buffer = createBuffer(self.device.?, c.SDL_GPU_BUFFERUSAGE_VERTEX, @sizeOf(@TypeOf(quad_vertices))) orelse return failSdl("SDL_CreateGPUBuffer(shared quad vertex)", error.SharedQuadVertexBufferCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        try after(injector, .shared_quad_vertex_buffer);
        self.quad_index_buffer = createBuffer(self.device.?, c.SDL_GPU_BUFFERUSAGE_INDEX, @sizeOf(@TypeOf(quad_indices))) orelse return failSdl("SDL_CreateGPUBuffer(shared quad index)", error.SharedQuadIndexBufferCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        try after(injector, .shared_quad_index_buffer);

        var static_transfer_info: c.SDL_GPUTransferBufferCreateInfo = std.mem.zeroes(c.SDL_GPUTransferBufferCreateInfo);
        static_transfer_info.usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
        static_transfer_info.size = static_upload_buffer_size;
        self.static_upload_transfer = c.SDL_CreateGPUTransferBuffer(self.device.?, &static_transfer_info);
        if (self.static_upload_transfer == null) return failSdl("SDL_CreateGPUTransferBuffer(static upload)", error.GpuTransferBufferCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        try after(injector, .transfer_buffer_creation);
        try self.populateStaticUpload();
        try self.submitStaticUpload();
        c.SDL_ReleaseGPUTransferBuffer(self.device.?, self.static_upload_transfer.?);
        self.static_upload_transfer = null;
        self.resource_metrics.gpu_resource_releases += 1;
        try after(injector, .upload);

        self.frame_slots = try self.createSlotSet(sprite.initial_capacity);
        self.gpu_instance_capacity = sprite.initial_capacity;
        try after(injector, .instance_frame_slots);

        self.pipeline = try createPipeline(self);
        self.resource_metrics.gpu_resource_creations += 1;
        try after(injector, .pipeline_creation);
        return self;
    }

    pub fn deinit(self: *GpuDemo) void {
        if (self.device) |device| {
            for (&self.frame_slots) |*slot| self.waitAndReleaseFence(slot, false) catch {};
            if (!c.SDL_WaitForGPUIdle(device)) std.log.err("SDL_WaitForGPUIdle during cleanup: {s}", .{sdlErrorText()});
            self.releaseSlotResources(&self.frame_slots);
            if (self.pipeline) |resource| self.releasePipeline(device, resource);
            if (self.static_upload_transfer) |resource| self.releaseTransfer(device, resource);
            if (self.quad_index_buffer) |resource| self.releaseBuffer(device, resource);
            if (self.quad_vertex_buffer) |resource| self.releaseBuffer(device, resource);
            if (self.render_target) |resource| self.releaseTexture(device, resource);
            if (self.sampled_texture) |resource| self.releaseTexture(device, resource);
            if (self.sampler) |resource| self.releaseSampler(device, resource);
            if (self.fragment_shader) |resource| self.releaseShader(device, resource);
            if (self.vertex_shader) |resource| self.releaseShader(device, resource);
            if (self.window_claimed and self.window != null) c.SDL_ReleaseWindowFromGPUDevice(device, self.window.?);
            c.SDL_DestroyGPUDevice(device);
        }
        if (self.window) |window| c.SDL_DestroyWindow(window);
        if (self.sdl_initialized) c.SDL_Quit();
        if (self.batch) |*batch| batch.deinit();
        self.batch = null;
    }

    pub fn runVisible(self: *GpuDemo, maximum_frames: ?u32, mode: DemoMode, scripted_input_enabled: bool) !void {
        const demo_storage = self.allocator.alloc(u8, 512 * 1024) catch return error.DemoStorageAllocationFailure;
        defer self.allocator.free(demo_storage);
        var humanoid_allocator = std.heap.FixedBufferAllocator.init(demo_storage);
        var humanoid_demo: ?humanoid.DemoCharacter = null;
        defer if (humanoid_demo) |*demo| demo.deinit();
        var animation_runtime: ?animation_system.Runtime = null;
        defer if (animation_runtime) |*runtime| runtime.deinit();
        var controller_runtime: ?controller_demo.Runtime = null;
        defer if (controller_runtime) |*runtime| runtime.deinit();
        var platform_input: ?sdl_input.PlatformInput = null;
        defer if (platform_input) |*platform| platform.deinit();
        var scripted_sequence = controller_demo.ScriptedInput{};
        var secondary_sequence = controller_demo.SecondaryMotionScriptedInput{};
        var animation_clock = try fixed_step.Clock.init(.{});
        var time_mode: TimeMode = .normal;
        var debug_geometry = true;

        const gpu_creations_before_humanoid_initialization = self.resource_metrics.gpu_resource_creations;
        if (mode == .humanoid or mode == .animation or mode == .controller or mode == .secondary_motion) {
            try humanoid.runFaultInjectionChecks(self.allocator);
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.HumanoidInitializationCreatedGpuResources;
            }
            humanoid_demo = try humanoid.DemoCharacter.init(humanoid_allocator.allocator(), null);
        }
        if (mode == .animation or mode == .controller or mode == .secondary_motion) {
            try animation_system.runFaultInjectionChecks(self.allocator, &humanoid_demo.?.definition);
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.AnimationInitializationCreatedGpuResources;
            }
            animation_runtime = try animation_system.Runtime.init(humanoid_allocator.allocator(), &humanoid_demo.?.definition, null);
        }
        if (mode == .controller or mode == .secondary_motion) {
            try controller_demo.runFaultInjectionChecks(self.allocator);
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.ControllerInitializationCreatedGpuResources;
            }
            controller_runtime = try controller_demo.Runtime.init(humanoid_allocator.allocator(), null);
            platform_input = sdl_input.PlatformInput.init();
        }
        const humanoid_initialized_bytes = humanoid_allocator.end_index;
        const creations_before_run = self.resource_metrics.gpu_resource_creations;
        var creations_after_warmup = creations_before_run;
        self.batch.?.markStabilized();
        var pose_evaluation_allocations: usize = 0;
        var socket_evaluation_allocations: usize = 0;
        var humanoid_submission_allocations: usize = 0;
        var humanoid_instances: u32 = 0;
        var rest_right_hand: ?@TypeOf(humanoid.presentation_origin) = null;
        var modified_right_hand: ?@TypeOf(humanoid.presentation_origin) = null;
        var rest_left_foot: ?@TypeOf(humanoid.presentation_origin) = null;
        var modified_left_foot: ?@TypeOf(humanoid.presentation_origin) = null;
        var animation_update_allocations: usize = 0;
        var animation_event_count: u64 = 0;
        var left_foot_contacts: u32 = 0;
        var right_foot_contacts: u32 = 0;
        var idle_right_hand: ?@TypeOf(humanoid.presentation_origin) = null;
        var walk_right_hand: ?@TypeOf(humanoid.presentation_origin) = null;
        var idle_left_foot: ?@TypeOf(humanoid.presentation_origin) = null;
        var walk_left_foot: ?@TypeOf(humanoid.presentation_origin) = null;
        var world_root_before = @TypeOf(humanoid.presentation_origin).zero;
        if (humanoid_demo) |*demo| world_root_before = demo.character.character_to_world.translation;
        var landing_evidence = [_]LandingEvidence{.{}} ** maximum_landing_evidence;
        var landing_evidence_count: usize = 0;
        var secondary_left_contacts: u32 = 0;
        var secondary_right_contacts: u32 = 0;
        var partial_speed_amplitude_peak: f32 = 0;
        var full_speed_amplitude_peak: f32 = 0;
        var last_ticks_ns = c.SDL_GetTicksNS();

        var frame: u32 = 0;
        var running = true;
        while (running and (maximum_frames == null or frame < maximum_frames.?)) : (frame += 1) {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event)) {
                if (event.type == c.SDL_EVENT_QUIT or event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) running = false;
                if (platform_input) |*platform| platform.handleEvent(&event);
            }
            if (!running) break;

            switch (mode) {
                .sprites => try self.submitDemonstrationSprites(frame),
                .humanoid => {
                    const demo = &humanoid_demo.?;
                    self.batch.?.beginFrame();
                    var allocation_checkpoint = humanoid_allocator.end_index;
                    try demo.character.applyProgrammaticPose(&demo.definition, frame);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;

                    if (frame == 0 or frame == 100 or frame == 200 or frame == 299) {
                        allocation_checkpoint = humanoid_allocator.end_index;
                        const positions = try hierarchyPositions(demo);
                        socket_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                        std.log.info("humanoid hierarchy frame={d}: right_shoulder=({d:.5},{d:.5}) right_elbow=({d:.5},{d:.5}) right_hand=({d:.5},{d:.5}) left_knee=({d:.5},{d:.5}) left_foot=({d:.5},{d:.5})", .{
                            frame,
                            positions.right_shoulder.x,
                            positions.right_shoulder.y,
                            positions.right_elbow.x,
                            positions.right_elbow.y,
                            positions.right_hand.x,
                            positions.right_hand.y,
                            positions.left_knee.x,
                            positions.left_knee.y,
                            positions.left_foot.x,
                            positions.left_foot.y,
                        });
                        if (frame == 0) {
                            rest_right_hand = positions.right_hand;
                            rest_left_foot = positions.left_foot;
                        } else if (frame == 100) {
                            modified_right_hand = positions.right_hand;
                        } else if (frame == 200) {
                            modified_left_foot = positions.left_foot;
                        }
                    }

                    allocation_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try demo.character.submitAttachments(&demo.definition, &self.batch.?, 0);
                    humanoid_submission_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                },
                .animation => {
                    const demo = &humanoid_demo.?;
                    const runtime = &animation_runtime.?;
                    self.batch.?.beginFrame();
                    if (frame == 60) try runtime.animator.requestState(&runtime.definitions.machine, .walk);
                    if (frame == 300) try runtime.animator.requestState(&runtime.definitions.machine, .idle);

                    var allocation_checkpoint = humanoid_allocator.end_index;
                    const animation_frame = try animation_clock.beginFrame(1.0 / 60.0);
                    for (0..animation_frame.substeps) |_| {
                        try runtime.animator.update(
                            &runtime.definitions.machine,
                            runtime.definitions.library.clips,
                            runtime.definitions.library.token(),
                            &demo.definition.skeleton_definition,
                            @floatCast(fixed_step.fixed_dt_seconds),
                            &demo.character.local_and_world_pose,
                        );
                        const tick_events = runtime.animator.emittedEvents();
                        animation_event_count += tick_events.len;
                        for (tick_events) |emitted_event| {
                            switch (emitted_event.record.event_type) {
                                .left_foot_contact => {
                                    left_foot_contacts += 1;
                                    std.log.info("animation event frame={d} type=left_foot_contact clip={s} loop={d}", .{
                                        frame,
                                        @tagName(runtime.definitions.library.clips[emitted_event.clip_id].id),
                                        emitted_event.loop_index,
                                    });
                                },
                                .right_foot_contact => {
                                    right_foot_contacts += 1;
                                    std.log.info("animation event frame={d} type=right_foot_contact clip={s} loop={d}", .{
                                        frame,
                                        @tagName(runtime.definitions.library.clips[emitted_event.clip_id].id),
                                        emitted_event.loop_index,
                                    });
                                },
                                else => {},
                            }
                        }
                    }
                    animation_update_allocations += humanoid_allocator.end_index - allocation_checkpoint;

                    allocation_checkpoint = humanoid_allocator.end_index;
                    try demo.character.local_and_world_pose.evaluateWorld(&demo.definition.skeleton_definition, demo.character.character_to_world);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;

                    const emitted = runtime.animator.emittedEvents();

                    const should_log = frame == 0 or frame == 59 or frame == 60 or frame == 69 or frame == 77 or
                        frame == 120 or frame == 180 or frame == 240 or frame == 299 or frame == 300 or
                        frame == 309 or frame == 317 or frame == 359;
                    if (should_log) {
                        const state = runtime.animator.currentState(&runtime.definitions.machine);
                        if (runtime.animator.transitionSnapshot(&runtime.definitions.machine)) |transition| {
                            std.log.info("animation frame={d} state={s} clip_time={d:.5} transition={s}->{s} weight={d:.5} emitted_events={d}", .{
                                frame,
                                @tagName(state),
                                runtime.animator.currentClipTime(),
                                @tagName(transition.source),
                                @tagName(transition.destination),
                                transition.weight,
                                emitted.len,
                            });
                        } else {
                            std.log.info("animation frame={d} state={s} clip_time={d:.5} transition=none weight=0.00000 emitted_events={d}", .{
                                frame,
                                @tagName(state),
                                runtime.animator.currentClipTime(),
                                emitted.len,
                            });
                        }
                    }

                    allocation_checkpoint = humanoid_allocator.end_index;
                    if (frame == 30 or frame == 180 or frame == 359) {
                        const positions = try hierarchyPositions(demo);
                        socket_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                        if (frame == 30) {
                            idle_right_hand = positions.right_hand;
                            idle_left_foot = positions.left_foot;
                        } else if (frame == 180) {
                            walk_right_hand = positions.right_hand;
                            walk_left_foot = positions.left_foot;
                        }
                    }

                    allocation_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try demo.character.submitAttachments(&demo.definition, &self.batch.?, 0);
                    humanoid_submission_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                },
                .controller, .secondary_motion => {
                    const demo = &humanoid_demo.?;
                    const animation = &animation_runtime.?;
                    const simulation = &controller_runtime.?;
                    const now_ticks_ns = c.SDL_GetTicksNS();
                    const measured_delta = @as(f64, @floatFromInt(now_ticks_ns - last_ticks_ns)) / 1_000_000_000.0;
                    last_ticks_ns = now_ticks_ns;
                    const snapshot = if (scripted_input_enabled and mode == .secondary_motion)
                        try secondary_sequence.nextFrame(&simulation.controller)
                    else if (scripted_input_enabled)
                        try scripted_sequence.nextFrame(&simulation.controller)
                    else
                        try platform_input.?.pollFrame();

                    var reset_this_frame = false;
                    if (snapshot.reset.pressed) {
                        try simulation.reset(animation, &demo.character, &demo.definition);
                        simulation.clock.setPaused(time_mode == .paused);
                        reset_this_frame = true;
                        std.log.info("controller reset: authoritative and interpolated state synchronized without recreating GPU resources", .{});
                    }
                    if (snapshot.debug_toggle.pressed) {
                        debug_geometry = !debug_geometry;
                        std.log.info("controller debug collision geometry enabled={}", .{debug_geometry});
                    }
                    if (snapshot.time_mode_cycle.pressed) {
                        time_mode = switch (time_mode) {
                            .normal => .quarter_speed,
                            .quarter_speed => .paused,
                            .paused => .normal,
                        };
                        simulation.clock.setPaused(time_mode == .paused);
                        simulation.pending_input.reset();
                        std.log.info("controller time mode={s}", .{@tagName(time_mode)});
                    }
                    if (snapshot.single_step.pressed) simulation.clock.requestSingleStep();

                    if (reset_this_frame or (simulation.clock.paused and !snapshot.single_step.pressed)) {
                        simulation.pending_input.reset();
                    } else {
                        try simulation.acceptFrameInput(snapshot);
                    }
                    const raw_delta = if (scripted_input_enabled) 1.0 / 60.0 else measured_delta;
                    const scaled_delta = if (time_mode == .quarter_speed) raw_delta * 0.25 else raw_delta;
                    const simulation_frame = try simulation.beginFrame(scaled_delta);
                    for (0..simulation_frame.substeps) |_| {
                        const tick = try simulation.simulateTick(animation, &demo.character, &demo.definition);
                        if (scripted_input_enabled and mode == .secondary_motion) {
                            secondary_sequence.observe(tick, &simulation.controller);
                        } else if (scripted_input_enabled) {
                            scripted_sequence.observe(tick, &simulation.controller);
                        }
                        if (mode == .secondary_motion) {
                            if (secondary_sequence.prelude_frame >= 31 and secondary_sequence.prelude_frame <= 90) {
                                partial_speed_amplitude_peak = @max(partial_speed_amplitude_peak, simulation.procedural.walk_bounce_amplitude);
                            } else if (secondary_sequence.prelude_frame > 90 and secondary_sequence.prelude_frame <= 150) {
                                full_speed_amplitude_peak = @max(full_speed_amplitude_peak, simulation.procedural.walk_bounce_amplitude);
                            }
                            for (animation.animator.emittedEvents()) |emitted_event| {
                                switch (emitted_event.record.event_type) {
                                    .left_foot_contact => {
                                        secondary_left_contacts += 1;
                                        std.log.info("secondary contact tick={d} type=left_foot_contact speed={d:.5} walk_phase={d:.5} walk_offset={d:.6}", .{
                                            tick.physics.simulation_tick,
                                            @abs(simulation.controller.state.velocity.x),
                                            simulation.procedural.walk_cycle_phase,
                                            simulation.procedural.walk_bounce_offset,
                                        });
                                    },
                                    .right_foot_contact => {
                                        secondary_right_contacts += 1;
                                        std.log.info("secondary contact tick={d} type=right_foot_contact speed={d:.5} walk_phase={d:.5} walk_offset={d:.6}", .{
                                            tick.physics.simulation_tick,
                                            @abs(simulation.controller.state.velocity.x),
                                            simulation.procedural.walk_cycle_phase,
                                            simulation.procedural.walk_bounce_offset,
                                        });
                                    },
                                    else => {},
                                }
                            }
                            if (tick.physics.landed and landing_evidence_count < landing_evidence.len) {
                                landing_evidence[landing_evidence_count] = .{
                                    .simulation_tick = tick.physics.simulation_tick,
                                    .impact_speed = tick.physics.landing_impact_speed,
                                    .impulse = simulation.procedural.last_landing_impulse,
                                    .peak_displacement = simulation.procedural.landing_peak_displacement,
                                };
                                landing_evidence_count += 1;
                                std.log.info("secondary landing tick={d} speed={d:.5} walk_phase={d:.5} walk_offset={d:.6} impact={d:.5} impulse={d:.6}", .{
                                    tick.physics.simulation_tick,
                                    @abs(simulation.controller.state.velocity.x),
                                    simulation.procedural.walk_cycle_phase,
                                    simulation.procedural.walk_bounce_offset,
                                    tick.physics.landing_impact_speed,
                                    simulation.procedural.last_landing_impulse,
                                });
                            }
                            if (landing_evidence_count > 0) {
                                const current = &landing_evidence[landing_evidence_count - 1];
                                current.peak_displacement = @min(current.peak_displacement, simulation.procedural.landing_spring.offset);
                            }
                        }
                        const first_wall = tick.physics.wall_collision and simulation.metrics.wall_collisions == 1;
                        const first_ceiling = tick.physics.ceiling_collision and simulation.metrics.ceiling_collisions == 1;
                        const animation_changed = tick.animation_before != tick.animation_after;
                        if (tick.physics.jump_pressed or tick.physics.jump_released or tick.physics.jump_accepted or
                            tick.physics.ground_left or tick.physics.landed or tick.physics.coyote_started or
                            tick.physics.jump_buffer_started or tick.physics.jump_buffer_consumed or
                            first_wall or first_ceiling or animation_changed)
                        {
                            const jump_source = if (tick.physics.jump_source) |source| @tagName(source) else "none";
                            std.log.info("controller milestone tick={d} jump_pressed={} jump_released={} jump_accepted={} jump_source={s} ground_left={} landed={} impact={d:.5} coyote_started={} coyote_consumed={} buffer_started={} buffer_consumed={} wall={} ceiling={} animation={s}->{s}", .{
                                tick.physics.simulation_tick,
                                tick.physics.jump_pressed,
                                tick.physics.jump_released,
                                tick.physics.jump_accepted,
                                jump_source,
                                tick.physics.ground_left,
                                tick.physics.landed,
                                tick.physics.landing_impact_speed,
                                tick.physics.coyote_started,
                                tick.physics.coyote_consumed,
                                tick.physics.jump_buffer_started,
                                tick.physics.jump_buffer_consumed,
                                first_wall,
                                first_ceiling,
                                @tagName(tick.animation_before),
                                @tagName(tick.animation_after),
                            });
                        }
                    }

                    self.batch.?.beginFrame();
                    var allocation_checkpoint = humanoid_allocator.end_index;
                    try simulation.evaluateRenderPose(&demo.character, &demo.definition);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    if (debug_geometry) _ = try simulation.submitCollisionGeometry(&self.batch.?);
                    allocation_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try demo.character.submitAttachments(&demo.definition, &self.batch.?, 0);
                    humanoid_submission_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                },
            }
            const prepared = self.batch.?.prepare();
            _ = try self.renderPreparedToWindow(prepared, null);
            self.resource_metrics.frames_rendered += 1;
            try self.updateWindowTitle();
            if (frame == 0) creations_after_warmup = self.resource_metrics.gpu_resource_creations;
        }

        const metrics = self.batch.?.frame_metrics;
        std.log.info("sprite-batch final metrics: frames={d} submitted={d} visible={d} culled={d} sorted={d} ranges={d} actual_draw_calls={d} upload_bytes={d}", .{
            self.resource_metrics.frames_rendered,
            metrics.submitted_sprites,
            metrics.visible_sprites,
            metrics.culled_sprites,
            metrics.sorted_sprites,
            metrics.draw_ranges,
            metrics.draw_calls,
            metrics.upload_bytes,
        });
        std.log.info("steady-state resources: creations_before_run={d} after_warmup={d} after_final_frame={d} gpu_buffer_growths={d} cpu_allocations_after_stabilization={d} frame_slot_waits={d} current_slot={d}", .{
            creations_before_run,
            creations_after_warmup,
            self.resource_metrics.gpu_resource_creations,
            self.resource_metrics.upload_buffer_growths,
            self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization,
            self.resource_metrics.frame_slot_fence_waits,
            self.current_frame_slot,
        });
        std.log.info("actual sprite draw command: SDL_DrawGPUIndexedPrimitives num_instances={d} draw_calls={d} draw_ranges={d}", .{
            metrics.visible_sprites, metrics.draw_calls, metrics.draw_ranges,
        });
        if (mode == .humanoid) {
            const gpu_resources_for_pose_changes = self.resource_metrics.gpu_resource_creations - creations_before_run;
            std.log.info("humanoid final metrics: frames={d} bones={d} sockets={d} attachments={d} humanoid_sprites={d} total_sprites={d} ranges={d} actual_draw_calls={d}", .{
                self.resource_metrics.frames_rendered,
                humanoid_demo.?.definition.skeleton_definition.boneCount(),
                humanoid_demo.?.definition.skeleton_definition.socketCount(),
                humanoid_demo.?.definition.attachments.len,
                humanoid_instances,
                metrics.visible_sprites,
                metrics.draw_ranges,
                metrics.draw_calls,
            });
            std.log.info("humanoid steady state: initialized_bytes={d} final_bytes={d} pose_evaluation_allocations={d} socket_evaluation_allocations={d} humanoid_submission_allocations={d} gpu_resources_for_pose_changes={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                pose_evaluation_allocations,
                socket_evaluation_allocations,
                humanoid_submission_allocations,
                gpu_resources_for_pose_changes,
            });
            if (rest_right_hand != null and modified_right_hand != null and rest_left_foot != null and modified_left_foot != null) {
                std.log.info("humanoid hierarchy proof: rest_right_hand=({d:.5},{d:.5}) modified_right_hand=({d:.5},{d:.5}) rest_left_foot=({d:.5},{d:.5}) modified_left_foot=({d:.5},{d:.5})", .{
                    rest_right_hand.?.x,
                    rest_right_hand.?.y,
                    modified_right_hand.?.x,
                    modified_right_hand.?.y,
                    rest_left_foot.?.x,
                    rest_left_foot.?.y,
                    modified_left_foot.?.x,
                    modified_left_foot.?.y,
                });
            }
        } else if (mode == .animation) {
            const demo = &humanoid_demo.?;
            const runtime = &animation_runtime.?;
            const gpu_resources_for_animation = self.resource_metrics.gpu_resource_creations - creations_before_run;
            const final_positions = try hierarchyPositions(demo);
            const right_hand_local = try demo.character.local_and_world_pose.localForSemantic(&demo.definition.skeleton_definition, .right_hand);
            const left_foot_local = try demo.character.local_and_world_pose.localForSemantic(&demo.definition.skeleton_definition, .left_foot);
            std.log.info("animation final metrics: frames={d} clips={d} states={d} transitions={d} humanoid_sprites={d} total_sprites={d} ranges={d} actual_draw_calls={d} events={d} left_contacts={d} right_contacts={d}", .{
                self.resource_metrics.frames_rendered,
                runtime.definitions.library.clips.len,
                runtime.definitions.machine.states.len,
                runtime.definitions.machine.transitions.len,
                humanoid_instances,
                metrics.visible_sprites,
                metrics.draw_ranges,
                metrics.draw_calls,
                animation_event_count,
                left_foot_contacts,
                right_foot_contacts,
            });
            std.log.info("animation steady state: initialized_bytes={d} final_bytes={d} sampling_allocations={d} blending_allocations={d} event_traversal_allocations={d} animator_update_allocations={d} measured_update_allocations={d} pose_evaluation_allocations={d} socket_evaluation_allocations={d} submission_allocations={d} gpu_resources_for_animation={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                runtime.animator.metrics.clip_sampling_allocations,
                runtime.animator.metrics.pose_blending_allocations,
                runtime.animator.metrics.event_traversal_allocations,
                runtime.animator.metrics.animator_update_allocations,
                animation_update_allocations,
                pose_evaluation_allocations,
                socket_evaluation_allocations,
                humanoid_submission_allocations,
                gpu_resources_for_animation,
            });
            std.log.info("animation pose proof: idle_right_hand=({d:.5},{d:.5}) walk_right_hand=({d:.5},{d:.5}) idle_left_foot=({d:.5},{d:.5}) walk_left_foot=({d:.5},{d:.5})", .{
                idle_right_hand.?.x,
                idle_right_hand.?.y,
                walk_right_hand.?.x,
                walk_right_hand.?.y,
                idle_left_foot.?.x,
                idle_left_foot.?.y,
                walk_left_foot.?.x,
                walk_left_foot.?.y,
            });
            std.log.info("animation final pose: state={s} right_hand_local=({d:.5},{d:.5}) right_hand_world=({d:.5},{d:.5}) left_foot_local=({d:.5},{d:.5}) left_foot_world=({d:.5},{d:.5}) world_root_before=({d:.5},{d:.5}) world_root_after=({d:.5},{d:.5})", .{
                @tagName(runtime.animator.currentState(&runtime.definitions.machine)),
                right_hand_local.translation.x,
                right_hand_local.translation.y,
                final_positions.right_hand.x,
                final_positions.right_hand.y,
                left_foot_local.translation.x,
                left_foot_local.translation.y,
                final_positions.left_foot.x,
                final_positions.left_foot.y,
                world_root_before.x,
                world_root_before.y,
                demo.character.character_to_world.translation.x,
                demo.character.character_to_world.translation.y,
            });
        } else if (mode == .controller or mode == .secondary_motion) {
            const simulation = &controller_runtime.?;
            const animation = &animation_runtime.?;
            const state = simulation.controller.state;
            const gpu_resources_for_movement = self.resource_metrics.gpu_resource_creations - creations_before_run;
            std.log.info("controller final metrics: frames={d} simulation_ticks={d} animator_ticks={d} humanoid_sprites={d} collider_sprites={d} total_sprites={d} ranges={d} actual_draw_calls={d} jump_events={d} coyote_jumps={d} buffered_jumps={d} landing_events={d} wall_collisions={d} ceiling_collisions={d}", .{
                self.resource_metrics.frames_rendered,
                simulation.metrics.simulation_ticks,
                simulation.metrics.animator_ticks,
                humanoid_instances,
                simulation.world.colliders.len,
                metrics.visible_sprites,
                metrics.draw_ranges,
                metrics.draw_calls,
                simulation.metrics.jump_events,
                simulation.metrics.coyote_jumps,
                simulation.metrics.buffered_jumps,
                simulation.metrics.landing_events,
                simulation.metrics.wall_collisions,
                simulation.metrics.ceiling_collisions,
            });
            std.log.info("controller final state: position=({d:.6},{d:.6}) velocity=({d:.6},{d:.6}) grounded={} facing={s} support={any} animation={s} previous_position=({d:.6},{d:.6}) interpolation_alpha={d:.6}", .{
                state.position.x,
                state.position.y,
                state.velocity.x,
                state.velocity.y,
                state.grounded,
                @tagName(state.facing),
                state.supporting_collider,
                @tagName(animation.animator.currentState(&animation.definitions.machine)),
                state.previous_position.x,
                state.previous_position.y,
                simulation.clock.last_frame.interpolation_alpha,
            });
            std.log.info("controller clock: fixed_dt={d:.9} raw_delta={d:.9} clamped_delta={d:.9} accumulator={d:.9} substeps={d} maximum_substeps={d} discarded_frame={d:.9} discarded_lifetime={d:.9}", .{
                fixed_step.fixed_dt_seconds,
                simulation.clock.last_frame.raw_frame_delta,
                simulation.clock.last_frame.clamped_frame_delta,
                simulation.clock.last_frame.accumulator,
                simulation.clock.last_frame.substeps,
                simulation.clock.last_frame.maximum_substeps,
                simulation.clock.last_frame.discarded_time,
                simulation.clock.last_frame.lifetime_discarded_time,
            });
            std.log.info("controller steady state: initialized_bytes={d} final_bytes={d} clock_allocations={d} input_allocations={d} intent_allocations={d} controller_allocations={d} collision_allocations={d} animation_selection_allocations={d} animator_allocations={d} render_interpolation_allocations={d} pose_evaluation_allocations={d} submission_allocations={d} gpu_resources_for_movement={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                simulation.metrics.clock_allocations,
                simulation.metrics.input_allocations,
                simulation.metrics.intent_allocations,
                simulation.metrics.controller_allocations,
                simulation.metrics.collision_allocations,
                simulation.metrics.animation_selection_allocations,
                simulation.metrics.animator_allocations,
                simulation.metrics.render_interpolation_allocations,
                pose_evaluation_allocations,
                humanoid_submission_allocations,
                gpu_resources_for_movement,
            });
            if (scripted_input_enabled) {
                if (mode == .controller) {
                    std.log.info("scripted controller milestones: phase={s} complete={} ceiling={} platform1={} platform2={} coyote={} buffered={} wall={}", .{
                        @tagName(scripted_sequence.phase),
                        scripted_sequence.completed(),
                        scripted_sequence.ceiling_seen,
                        scripted_sequence.first_platform_landed,
                        scripted_sequence.second_platform_landed,
                        scripted_sequence.coyote_jump_seen,
                        scripted_sequence.buffered_jump_seen,
                        scripted_sequence.wall_seen,
                    });
                    if (!scripted_sequence.completed() or !scripted_sequence.ceiling_seen or
                        !scripted_sequence.first_platform_landed or !scripted_sequence.second_platform_landed or
                        !scripted_sequence.coyote_jump_seen or !scripted_sequence.buffered_jump_seen or
                        !scripted_sequence.wall_seen or !state.grounded)
                    {
                        return error.ScriptedControllerMilestonesIncomplete;
                    }
                } else {
                    const route = secondary_sequence.controller_sequence;
                    std.log.info("secondary scripted milestones: complete={} prelude_frames={d} phase={s} ceiling={} platform1={} platform2={} coyote={} buffered={} wall={} left_contacts={d} right_contacts={d}", .{
                        secondary_sequence.completed(),
                        secondary_sequence.prelude_frame,
                        @tagName(route.phase),
                        route.ceiling_seen,
                        route.first_platform_landed,
                        route.second_platform_landed,
                        route.coyote_jump_seen,
                        route.buffered_jump_seen,
                        route.wall_seen,
                        secondary_left_contacts,
                        secondary_right_contacts,
                    });
                    var softest_index: usize = 0;
                    var hardest_index: usize = 0;
                    for (landing_evidence[0..landing_evidence_count], 0..) |evidence, index| {
                        std.log.info("secondary landing evidence index={d} tick={d} impact={d:.5} impulse={d:.6} peak={d:.6}", .{
                            index,
                            evidence.simulation_tick,
                            evidence.impact_speed,
                            evidence.impulse,
                            evidence.peak_displacement,
                        });
                        if (evidence.impact_speed < landing_evidence[softest_index].impact_speed) softest_index = index;
                        if (evidence.impact_speed > landing_evidence[hardest_index].impact_speed) hardest_index = index;
                    }
                    const softest = landing_evidence[softest_index];
                    const hardest = landing_evidence[hardest_index];
                    std.log.info("secondary final metrics: walk_cycle_phase={d:.6} walk_bounce_offset={d:.6} walk_bounce_amplitude={d:.6} partial_amplitude_peak={d:.6} full_amplitude_peak={d:.6} last_landing_impact={d:.5} landing_displacement={d:.8} landing_velocity={d:.8} landing_peak={d:.6} secondary_offset={d:.8} secondary_velocity={d:.8} secondary_peak={d:.6} visual_root_offset={d:.8} final_physics_position=({d:.6},{d:.6})", .{
                        simulation.procedural.walk_cycle_phase,
                        simulation.procedural.walk_bounce_offset,
                        simulation.procedural.walk_bounce_amplitude,
                        partial_speed_amplitude_peak,
                        full_speed_amplitude_peak,
                        simulation.procedural.last_landing_impact_speed,
                        simulation.procedural.landing_spring.offset,
                        simulation.procedural.landing_spring.velocity,
                        simulation.procedural.landing_peak_displacement,
                        simulation.procedural.secondary_spring.offset,
                        simulation.procedural.secondary_spring.velocity,
                        simulation.procedural.secondary_peak_displacement,
                        simulation.procedural.visual_root_offset_y,
                        state.position.x,
                        state.position.y,
                    });
                    std.log.info("secondary steady state: initialized_bytes={d} final_bytes={d} walk_allocations={d} landing_allocations={d} spring_allocations={d} secondary_allocations={d} pose_composition_allocations={d} measured_pose_evaluation_allocations={d} submission_allocations={d} gpu_resources_for_procedural_motion={d}", .{
                        humanoid_initialized_bytes,
                        humanoid_allocator.end_index,
                        simulation.procedural.metrics.walk_update_allocations,
                        simulation.procedural.metrics.landing_event_allocations,
                        simulation.procedural.metrics.spring_update_allocations,
                        simulation.procedural.metrics.secondary_update_allocations,
                        simulation.procedural.metrics.pose_composition_allocations,
                        pose_evaluation_allocations,
                        humanoid_submission_allocations,
                        gpu_resources_for_movement,
                    });
                    if (!secondary_sequence.completed() or !route.ceiling_seen or !route.first_platform_landed or
                        !route.second_platform_landed or !route.coyote_jump_seen or !route.buffered_jump_seen or
                        !route.wall_seen or !state.grounded or landing_evidence_count < 2 or
                        hardest.impact_speed <= softest.impact_speed or
                        @abs(hardest.peak_displacement) <= @abs(softest.peak_displacement) + 0.0001 or
                        partial_speed_amplitude_peak <= 0 or full_speed_amplitude_peak <= partial_speed_amplitude_peak or
                        @abs(simulation.procedural.landing_spring.offset) > 0.001 or
                        @abs(simulation.procedural.landing_spring.velocity) > 0.02 or
                        @abs(simulation.procedural.secondary_spring.offset) > 0.001 or
                        @abs(simulation.procedural.secondary_spring.velocity) > 0.02 or
                        self.resource_metrics.gpu_resource_creations != creations_before_run or
                        animation.animator.currentState(&animation.definitions.machine) != .idle)
                    {
                        return error.SecondaryMotionEvidenceIncomplete;
                    }
                }
            }
        }
    }

    pub fn runRuntimeFaultChecks(self: *GpuDemo) !void {
        const old_capacity = self.gpu_instance_capacity;
        self.ensureGpuCapacity(old_capacity + 1, .{ .fail_after = .capacity_growth_replacement }) catch |err| {
            if (err != error.InjectedInitializationFailure) return err;
        };
        if (self.gpu_instance_capacity != old_capacity or self.resource_metrics.upload_buffer_growths != 0) return error.FailedGrowthBecameAuthoritative;
        std.log.info("fault-injection cleanup check passed after capacity_growth_replacement", .{});

        try self.submitSmokeSprites();
        const prepared = self.batch.?.prepare();
        _ = self.renderPreparedToWindow(prepared, .{ .fail_after = .frame_fence_acquisition }) catch |err| {
            if (err != error.InjectedInitializationFailure) return err;
            std.log.info("fault-injection cleanup check passed after frame_fence_acquisition", .{});
            return;
        };
        return error.FaultInjectionDidNotTrigger;
    }

    pub fn runSmoke(self: *GpuDemo) !void {
        self.batch.?.markStabilized();
        self.batch.?.beginFrame();
        const empty = self.batch.?.prepare();
        if (!try self.renderPreparedToWindow(empty, null)) return error.SwapchainUnavailable;
        if (self.batch.?.frame_metrics.draw_calls != 0 or self.batch.?.frame_metrics.upload_bytes != 0) return error.EmptyBatchMetricsMismatch;
        std.log.info("empty sprite batch cleared and presented with draw_calls=0 upload_bytes=0", .{});

        for (0..3) |_| {
            try self.submitSmokeSprites();
            const prepared = self.batch.?.prepare();
            if (!try self.renderPreparedToWindow(prepared, null)) return error.SwapchainUnavailable;
        }

        try self.submitSmokeSprites();
        const prepared = self.batch.?.prepare();
        const pixels = try self.renderPreparedForReadback(prepared);
        const expected_clear = [4]u8{ 13, 26, 51, 255 };
        const expected_a = [4]u8{ 255, 0, 0, 255 };
        const expected_b = [4]u8{ 255, 255, 0, 255 };
        const tolerance: u8 = 1;
        if (!colorNear(pixels.outside, expected_clear, tolerance)) return error.SmokeOutsidePixelMismatch;
        if (!colorNear(pixels.inside_a, expected_a, tolerance) or !colorNear(pixels.inside_b, expected_b, tolerance)) {
            std.log.err("smoke interior mismatch: A expected={any} actual={any}, B expected={any} actual={any}", .{ expected_a, pixels.inside_a, expected_b, pixels.inside_b });
            return error.SmokeInteriorPixelMismatch;
        }
        const metrics = self.batch.?.frame_metrics;
        if (metrics.draw_calls != 1 or metrics.draw_ranges != 1 or metrics.visible_sprites != 2) return error.SmokeBatchMetricsMismatch;
        std.log.info("GPU readback format=R8G8B8A8_UNORM width={d} height={d} row_pitch={d}; rows use explicit pitch", .{ target_width, target_height, pixels.row_pitch });
        std.log.info("GPU smoke passed through shared production SpriteBatch: outside={any}, interior A={any}, interior B={any}, expected A={any}, expected B={any}, tolerance={d}, SDL_DrawGPUIndexedPrimitives instances=2 draw_calls=1", .{
            pixels.outside, pixels.inside_a, pixels.inside_b, expected_a, expected_b, tolerance,
        });
    }

    fn submitDemonstrationSprites(self: *GpuDemo, frame: u32) !void {
        var batch = &self.batch.?;
        batch.beginFrame();
        const time: f32 = @as(f32, @floatFromInt(frame)) * 0.025;
        for (0..demonstration_sprite_count) |index| {
            const column = index % 40;
            const row = index / 40;
            const index_f: f32 = @floatFromInt(index);
            const x: f32 = 8.0 + @as(f32, @floatFromInt(column)) * 16.0 + @sin(time + index_f * 0.071) * 1.5;
            const y: f32 = 10.0 + @as(f32, @floatFromInt(row)) * 18.5 + @cos(time * 0.7 + index_f * 0.053) * 1.5;
            const uv = switch (index % 4) {
                0 => [4]f32{ 0.0, 0.0, 0.5, 0.5 },
                1 => [4]f32{ 0.5, 0.0, 1.0, 0.5 },
                2 => [4]f32{ 0.0, 0.5, 0.5, 1.0 },
                else => [4]f32{ 0.5, 0.5, 1.0, 1.0 },
            };
            try batch.submit(.{
                .world_position = .{ x, y },
                .rotation = @sin(time + index_f * 0.031) * 0.45,
                .scale = .{ 7.0 + @as(f32, @floatFromInt(index % 5)), 9.0 + @as(f32, @floatFromInt(index % 7)) },
                .pivot = if (index % 2 == 0) .{ 0.5, 0.5 } else .{ 0.0, 1.0 },
                .uv_rect = uv,
                .tint = .{
                    0.65 + @as(f32, @floatFromInt(index % 4)) * 0.1,
                    0.70 + @as(f32, @floatFromInt(index % 3)) * 0.1,
                    0.75 + @as(f32, @floatFromInt(index % 2)) * 0.2,
                    1.0,
                },
                .texture_page = 0,
                .order = .{
                    .scene_layer = @intCast(index % 3),
                    .interaction_layer = @as(i32, @intCast(index % 5)) - 2,
                    .actor_layer = @intCast(index % 32),
                    .body_part_layer = @intCast(index % 64),
                },
            });
        }
    }

    fn hierarchyPositions(demo: *const humanoid.DemoCharacter) !HierarchyPositions {
        const skeleton_definition = &demo.definition.skeleton_definition;
        return .{
            .right_shoulder = (try demo.character.local_and_world_pose.worldForSemantic(skeleton_definition, .right_upper_arm)).translationPart(),
            .right_elbow = (try demo.character.local_and_world_pose.worldForSemantic(skeleton_definition, .right_forearm)).translationPart(),
            .right_hand = try demo.character.local_and_world_pose.socketPosition(skeleton_definition, .right_hand),
            .left_knee = (try demo.character.local_and_world_pose.worldForSemantic(skeleton_definition, .left_shin)).translationPart(),
            .left_foot = try demo.character.local_and_world_pose.socketPosition(skeleton_definition, .left_foot),
        };
    }

    fn submitSmokeSprites(self: *GpuDemo) !void {
        var batch = &self.batch.?;
        batch.beginFrame();
        try batch.submit(.{
            .world_position = .{ 208, 200 },
            .rotation = 0,
            .scale = .{ 160, 160 },
            .pivot = .{ 0.5, 0.5 },
            .uv_rect = .{ 0, 0, 0.5, 0.5 },
            .tint = .{ 1, 1, 1, 1 },
            .texture_page = 0,
            .order = .{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 0 },
        });
        try batch.submit(.{
            .world_position = .{ 432, 280 },
            .rotation = 0,
            .scale = .{ 160, 160 },
            .pivot = .{ 0.5, 0.5 },
            .uv_rect = .{ 0.5, 0.5, 1, 1 },
            .tint = .{ 1, 1, 1, 1 },
            .texture_page = 0,
            .order = .{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 1 },
        });
    }

    fn renderPreparedToWindow(self: *GpuDemo, prepared: sprite.PreparedBatch, injector: ?fault_injection.Injector) !bool {
        try self.ensureGpuCapacity(prepared.sprites.len, null);
        const slot_index = try self.acquireFrameSlot();
        try self.populateInstanceTransfer(slot_index, prepared.sprites);

        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse return failSdl("SDL_AcquireGPUCommandBuffer(frame)", error.PipelineResourceBindingFailure);
        var command_active = true;
        var swapchain_acquired = false;
        errdefer if (command_active) self.cleanupFailedCommand(command, swapchain_acquired);

        var swapchain_texture: ?*c.SDL_GPUTexture = null;
        var swapchain_width: u32 = 0;
        var swapchain_height: u32 = 0;
        if (!c.SDL_WaitAndAcquireGPUSwapchainTexture(command, self.window.?, &swapchain_texture, &swapchain_width, &swapchain_height)) {
            return failSdl("SDL_WaitAndAcquireGPUSwapchainTexture", error.SwapchainAcquisitionFailure);
        }
        swapchain_acquired = swapchain_texture != null;
        const encoded_draws = try self.encodeAuthoritativeSpriteBatch(command, slot_index, prepared, self.render_target.?, true);
        if (swapchain_texture) |swapchain| {
            var blit_info: c.SDL_GPUBlitInfo = std.mem.zeroes(c.SDL_GPUBlitInfo);
            blit_info.source = .{ .texture = self.render_target.?, .mip_level = 0, .layer_or_depth_plane = 0, .x = 0, .y = 0, .w = target_width, .h = target_height };
            blit_info.destination = .{ .texture = swapchain, .mip_level = 0, .layer_or_depth_plane = 0, .x = 0, .y = 0, .w = swapchain_width, .h = swapchain_height };
            blit_info.load_op = c.SDL_GPU_LOADOP_DONT_CARE;
            blit_info.filter = c.SDL_GPU_FILTER_LINEAR;
            c.SDL_BlitGPUTexture(command, &blit_info);
        }

        const fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
        command_active = false;
        if (fence == null) {
            _ = c.SDL_WaitForGPUIdle(self.device.?);
            return failSdl("SDL_SubmitGPUCommandBufferAndAcquireFence(frame)", error.FrameFenceAcquisitionFailure);
        }
        self.resource_metrics.fence_acquisitions += 1;
        if (injector) |value| {
            value.after(.frame_fence_acquisition) catch |err| {
                try self.waitReleaseStandaloneFence(fence.?);
                return err;
            };
        }
        self.frame_slots[slot_index].fence = fence.?;
        self.current_frame_slot = (slot_index + 1) % frame_slot_count;
        for (0..encoded_draws) |_| self.batch.?.recordDraw();
        return swapchain_acquired;
    }

    fn renderPreparedForReadback(self: *GpuDemo, prepared: sprite.PreparedBatch) !ReadbackPixels {
        const row_pitch = alignForward(target_width * 4, 256);
        const readback_size = row_pitch * target_height;
        if (c.SDL_GPUTextureFormatTexelBlockSize(c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM) != 4) return error.UnexpectedTexelBlockSize;

        var info: c.SDL_GPUTransferBufferCreateInfo = std.mem.zeroes(c.SDL_GPUTransferBufferCreateInfo);
        info.usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD;
        info.size = readback_size;
        const download = c.SDL_CreateGPUTransferBuffer(self.device.?, &info) orelse return failSdl("SDL_CreateGPUTransferBuffer(readback)", error.GpuTransferBufferCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        defer {
            c.SDL_ReleaseGPUTransferBuffer(self.device.?, download);
            self.resource_metrics.gpu_resource_releases += 1;
        }

        try self.ensureGpuCapacity(prepared.sprites.len, null);
        const slot_index = try self.acquireFrameSlot();
        try self.populateInstanceTransfer(slot_index, prepared.sprites);
        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse return failSdl("SDL_AcquireGPUCommandBuffer(readback)", error.PipelineResourceBindingFailure);
        var command_active = true;
        errdefer if (command_active) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) std.log.err("SDL_CancelGPUCommandBuffer(readback): {s}", .{sdlErrorText()});
        };
        const encoded_draws = try self.encodeAuthoritativeSpriteBatch(command, slot_index, prepared, self.render_target.?, false);
        const copy_pass = c.SDL_BeginGPUCopyPass(command);
        if (copy_pass == null) return failSdl("SDL_BeginGPUCopyPass(readback)", error.UploadFailure);
        const source = c.SDL_GPUTextureRegion{
            .texture = self.render_target.?,
            .mip_level = 0,
            .layer = 0,
            .x = 0,
            .y = 0,
            .z = 0,
            .w = target_width,
            .h = target_height,
            .d = 1,
        };
        const destination = c.SDL_GPUTextureTransferInfo{
            .transfer_buffer = download,
            .offset = 0,
            .pixels_per_row = row_pitch / 4,
            .rows_per_layer = target_height,
        };
        c.SDL_DownloadFromGPUTexture(copy_pass.?, &source, &destination);
        c.SDL_EndGPUCopyPass(copy_pass.?);

        const fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
        command_active = false;
        if (fence == null) return failSdl("SDL_SubmitGPUCommandBufferAndAcquireFence(readback)", error.FrameFenceAcquisitionFailure);
        self.resource_metrics.fence_acquisitions += 1;
        try self.waitReleaseStandaloneFence(fence.?);
        self.current_frame_slot = (slot_index + 1) % frame_slot_count;
        for (0..encoded_draws) |_| self.batch.?.recordDraw();

        const mapped = c.SDL_MapGPUTransferBuffer(self.device.?, download, false) orelse return failSdl("SDL_MapGPUTransferBuffer(readback)", error.ReadbackFailure);
        defer c.SDL_UnmapGPUTransferBuffer(self.device.?, download);
        const bytes: [*]const u8 = @ptrCast(mapped);
        return .{
            .outside = readPixel(bytes, row_pitch, 20, 20),
            .inside_a = readPixel(bytes, row_pitch, 200, 200),
            .inside_b = readPixel(bytes, row_pitch, 440, 200),
            .row_pitch = row_pitch,
        };
    }

    fn encodeAuthoritativeSpriteBatch(self: *GpuDemo, command: *c.SDL_GPUCommandBuffer, slot_index: usize, prepared: sprite.PreparedBatch, target: *c.SDL_GPUTexture, cycle_target: bool) !u32 {
        const upload_bytes = try sprite.instanceByteSize(prepared.sprites.len);
        self.batch.?.recordUpload(upload_bytes);
        if (upload_bytes > 0) {
            const copy_pass = c.SDL_BeginGPUCopyPass(command);
            if (copy_pass == null) return failSdl("SDL_BeginGPUCopyPass(instance upload)", error.UploadFailure);
            const source = c.SDL_GPUTransferBufferLocation{ .transfer_buffer = self.frame_slots[slot_index].transfer_buffer.?, .offset = 0 };
            const destination = c.SDL_GPUBufferRegion{ .buffer = self.frame_slots[slot_index].instance_buffer.?, .offset = 0, .size = upload_bytes };
            c.SDL_UploadToGPUBuffer(copy_pass.?, &source, &destination, false);
            c.SDL_EndGPUCopyPass(copy_pass.?);
        }

        const camera = CameraUniform{ .viewport_data = .{ @floatFromInt(target_width), @floatFromInt(target_height), 0, 0 } };
        c.SDL_PushGPUVertexUniformData(command, 0, &camera, @sizeOf(CameraUniform));
        var target_info: c.SDL_GPUColorTargetInfo = std.mem.zeroes(c.SDL_GPUColorTargetInfo);
        target_info.texture = target;
        target_info.clear_color = clear_color;
        target_info.load_op = c.SDL_GPU_LOADOP_CLEAR;
        target_info.store_op = c.SDL_GPU_STOREOP_STORE;
        target_info.cycle = cycle_target;
        const render_pass = c.SDL_BeginGPURenderPass(command, &target_info, 1, null);
        if (render_pass == null) return failSdl("SDL_BeginGPURenderPass(sprite batch)", error.PipelineResourceBindingFailure);

        var encoded_draws: u32 = 0;
        if (prepared.ranges.len > 0) {
            c.SDL_BindGPUGraphicsPipeline(render_pass.?, self.pipeline.?);
            const vertex_bindings = [_]c.SDL_GPUBufferBinding{
                .{ .buffer = self.quad_vertex_buffer.?, .offset = 0 },
                .{ .buffer = self.frame_slots[slot_index].instance_buffer.?, .offset = 0 },
            };
            c.SDL_BindGPUVertexBuffers(render_pass.?, 0, &vertex_bindings, vertex_bindings.len);
            const index_binding = c.SDL_GPUBufferBinding{ .buffer = self.quad_index_buffer.?, .offset = 0 };
            c.SDL_BindGPUIndexBuffer(render_pass.?, &index_binding, c.SDL_GPU_INDEXELEMENTSIZE_16BIT);
            for (prepared.ranges) |range| {
                if (range.texture_page != 0) {
                    std.log.err("bind sprite texture page: invalid texture_page={d}, configured_pages=1, first_instance={d}", .{ range.texture_page, range.first_instance });
                    c.SDL_EndGPURenderPass(render_pass.?);
                    return error.InvalidTexturePage;
                }
                const binding = c.SDL_GPUTextureSamplerBinding{ .texture = self.sampled_texture.?, .sampler = self.sampler.? };
                c.SDL_BindGPUFragmentSamplers(render_pass.?, 0, &binding, 1);
                c.SDL_DrawGPUIndexedPrimitives(render_pass.?, quad_indices.len, range.instance_count, 0, 0, range.first_instance);
                encoded_draws += 1;
            }
        }
        c.SDL_EndGPURenderPass(render_pass.?);
        return encoded_draws;
    }

    fn populateInstanceTransfer(self: *GpuDemo, slot_index: usize, submissions: []const sprite.SpriteSubmission) !void {
        if (submissions.len == 0) return;
        const transfer = self.frame_slots[slot_index].transfer_buffer.?;
        const mapped = c.SDL_MapGPUTransferBuffer(self.device.?, transfer, false) orelse {
            std.log.err("SDL_MapGPUTransferBuffer(instance upload): slot={d} instances={d} bytes={d}: {s}", .{ slot_index, submissions.len, sprite.instanceByteSize(submissions.len) catch 0, sdlErrorText() });
            return error.UploadFailure;
        };
        defer c.SDL_UnmapGPUTransferBuffer(self.device.?, transfer);
        const bytes: [*]u8 = @ptrCast(mapped);
        for (submissions, 0..) |submission, index| {
            const gpu_instance = sprite.GpuInstance.fromSubmission(submission);
            const offset = index * @sizeOf(sprite.GpuInstance);
            copyBytes(bytes, offset, std.mem.asBytes(&gpu_instance));
        }
    }

    fn acquireFrameSlot(self: *GpuDemo) !usize {
        const slot_index = self.current_frame_slot;
        try self.waitAndReleaseFence(&self.frame_slots[slot_index], true);
        return slot_index;
    }

    fn waitAndReleaseFence(self: *GpuDemo, slot: *FrameSlot, count_slot_wait: bool) !void {
        const fence = slot.fence orelse return;
        if (!c.SDL_QueryGPUFence(self.device.?, fence)) {
            const fences = [_]*c.SDL_GPUFence{fence};
            if (!c.SDL_WaitForGPUFences(self.device.?, true, &fences, 1)) {
                std.log.err("SDL_WaitForGPUFences(slot reuse): slot={d}: {s}", .{ self.current_frame_slot, sdlErrorText() });
                return error.FrameSlotSynchronizationFailure;
            }
            if (count_slot_wait) self.resource_metrics.frame_slot_fence_waits += 1;
        }
        c.SDL_ReleaseGPUFence(self.device.?, fence);
        self.resource_metrics.fence_releases += 1;
        slot.fence = null;
    }

    fn waitReleaseStandaloneFence(self: *GpuDemo, fence: *c.SDL_GPUFence) !void {
        const fences = [_]*c.SDL_GPUFence{fence};
        if (!c.SDL_WaitForGPUFences(self.device.?, true, &fences, 1)) {
            c.SDL_ReleaseGPUFence(self.device.?, fence);
            self.resource_metrics.fence_releases += 1;
            return failSdl("SDL_WaitForGPUFences(standalone)", error.FrameSlotSynchronizationFailure);
        }
        c.SDL_ReleaseGPUFence(self.device.?, fence);
        self.resource_metrics.fence_releases += 1;
    }

    fn ensureGpuCapacity(self: *GpuDemo, required: usize, injector: ?fault_injection.Injector) !void {
        if (required <= self.gpu_instance_capacity) return;
        const replacement_capacity = try sprite.nextCapacity(self.gpu_instance_capacity, required, sprite.maximum_capacity);
        var replacements = try self.createSlotSet(replacement_capacity);
        var replacements_authoritative = false;
        defer if (!replacements_authoritative) self.releaseSlotResources(&replacements);
        try after(injector, .capacity_growth_replacement);

        for (&self.frame_slots) |*slot| try self.waitAndReleaseFence(slot, true);
        self.releaseSlotResources(&self.frame_slots);
        self.frame_slots = replacements;
        self.gpu_instance_capacity = replacement_capacity;
        self.current_frame_slot = 0;
        self.resource_metrics.upload_buffer_growths += 1;
        replacements_authoritative = true;
        std.log.info("grew authoritative GPU instance/upload slots: requested={d} capacity={d} bytes_per_slot={d}", .{
            required, replacement_capacity, try sprite.instanceByteSize(replacement_capacity),
        });
    }

    fn createSlotSet(self: *GpuDemo, capacity: usize) ![frame_slot_count]FrameSlot {
        const byte_size = try sprite.instanceByteSize(capacity);
        var slots = [_]FrameSlot{.{}} ** frame_slot_count;
        errdefer self.releaseSlotResources(&slots);
        for (&slots, 0..) |*slot, index| {
            slot.instance_buffer = createBuffer(self.device.?, c.SDL_GPU_BUFFERUSAGE_VERTEX, byte_size);
            if (slot.instance_buffer == null) {
                std.log.err("SDL_CreateGPUBuffer(instance): capacity={d} bytes={d} slot={d}: {s}", .{ capacity, byte_size, index, sdlErrorText() });
                return error.GpuInstanceBufferCreationFailure;
            }
            self.resource_metrics.gpu_resource_creations += 1;
            var transfer_info: c.SDL_GPUTransferBufferCreateInfo = std.mem.zeroes(c.SDL_GPUTransferBufferCreateInfo);
            transfer_info.usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
            transfer_info.size = byte_size;
            slot.transfer_buffer = c.SDL_CreateGPUTransferBuffer(self.device.?, &transfer_info);
            if (slot.transfer_buffer == null) {
                std.log.err("SDL_CreateGPUTransferBuffer(instance): capacity={d} bytes={d} slot={d}: {s}", .{ capacity, byte_size, index, sdlErrorText() });
                return error.GpuTransferBufferCreationFailure;
            }
            self.resource_metrics.gpu_resource_creations += 1;
        }
        return slots;
    }

    fn releaseSlotResources(self: *GpuDemo, slots: *[frame_slot_count]FrameSlot) void {
        const device = self.device orelse return;
        for (slots) |*slot| {
            if (slot.transfer_buffer) |resource| self.releaseTransfer(device, resource);
            if (slot.instance_buffer) |resource| self.releaseBuffer(device, resource);
            slot.transfer_buffer = null;
            slot.instance_buffer = null;
        }
    }

    fn populateStaticUpload(self: *GpuDemo) !void {
        const mapped = c.SDL_MapGPUTransferBuffer(self.device.?, self.static_upload_transfer.?, false) orelse return failSdl("SDL_MapGPUTransferBuffer(static upload)", error.UploadFailure);
        defer c.SDL_UnmapGPUTransferBuffer(self.device.?, self.static_upload_transfer.?);
        const bytes: [*]u8 = @ptrCast(mapped);
        for (0..texture_height) |y| {
            const source_start = y * texture_width;
            const source_bytes = std.mem.sliceAsBytes(texture_pixels[source_start .. source_start + texture_width]);
            const destination_start = y * upload_texture_row_pitch;
            @memcpy(bytes[destination_start .. destination_start + source_bytes.len], source_bytes);
        }
        copyBytes(bytes, vertex_upload_offset, std.mem.asBytes(&quad_vertices));
        copyBytes(bytes, index_upload_offset, std.mem.asBytes(&quad_indices));
    }

    fn submitStaticUpload(self: *GpuDemo) !void {
        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse return failSdl("SDL_AcquireGPUCommandBuffer(static upload)", error.UploadFailure);
        var command_active = true;
        errdefer if (command_active) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) std.log.err("SDL_CancelGPUCommandBuffer(static upload): {s}", .{sdlErrorText()});
        };
        const copy_pass = c.SDL_BeginGPUCopyPass(command);
        if (copy_pass == null) return failSdl("SDL_BeginGPUCopyPass(static upload)", error.UploadFailure);
        const texture_source = c.SDL_GPUTextureTransferInfo{
            .transfer_buffer = self.static_upload_transfer.?,
            .offset = 0,
            .pixels_per_row = upload_texture_row_pitch / 4,
            .rows_per_layer = texture_height,
        };
        const texture_destination = c.SDL_GPUTextureRegion{
            .texture = self.sampled_texture.?,
            .mip_level = 0,
            .layer = 0,
            .x = 0,
            .y = 0,
            .z = 0,
            .w = texture_width,
            .h = texture_height,
            .d = 1,
        };
        c.SDL_UploadToGPUTexture(copy_pass.?, &texture_source, &texture_destination, false);
        uploadBuffer(copy_pass.?, self.static_upload_transfer.?, vertex_upload_offset, self.quad_vertex_buffer.?, @sizeOf(@TypeOf(quad_vertices)));
        uploadBuffer(copy_pass.?, self.static_upload_transfer.?, index_upload_offset, self.quad_index_buffer.?, @sizeOf(@TypeOf(quad_indices)));
        c.SDL_EndGPUCopyPass(copy_pass.?);
        const fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
        command_active = false;
        if (fence == null) return failSdl("SDL_SubmitGPUCommandBufferAndAcquireFence(static upload)", error.UploadFailure);
        self.resource_metrics.fence_acquisitions += 1;
        try self.waitReleaseStandaloneFence(fence.?);
    }

    fn cleanupFailedCommand(self: *GpuDemo, command: *c.SDL_GPUCommandBuffer, swapchain_acquired: bool) void {
        if (swapchain_acquired) {
            if (!c.SDL_SubmitGPUCommandBuffer(command)) std.log.err("SDL_SubmitGPUCommandBuffer(failed frame cleanup): {s}", .{sdlErrorText()});
            if (!c.SDL_WaitForGPUIdle(self.device.?)) std.log.err("SDL_WaitForGPUIdle(failed frame cleanup): {s}", .{sdlErrorText()});
        } else if (!c.SDL_CancelGPUCommandBuffer(command)) {
            std.log.err("SDL_CancelGPUCommandBuffer(failed frame): {s}", .{sdlErrorText()});
        }
    }

    fn updateWindowTitle(self: *GpuDemo) !void {
        const metrics = self.batch.?.frame_metrics;
        var buffer: [256]u8 = undefined;
        const title = std.fmt.bufPrintZ(&buffer, "sprites {d} visible {d} culled {d} ranges {d} draws {d} upload {d}B slot {d} waits {d}", .{
            metrics.submitted_sprites,
            metrics.visible_sprites,
            metrics.culled_sprites,
            metrics.draw_ranges,
            metrics.draw_calls,
            metrics.upload_bytes,
            self.current_frame_slot,
            self.resource_metrics.frame_slot_fence_waits,
        }) catch return error.WindowTitleFormatFailure;
        if (!c.SDL_SetWindowTitle(self.window.?, title.ptr)) return failSdl("SDL_SetWindowTitle(metrics)", error.WindowTitleUpdateFailure);
    }

    fn releaseBuffer(self: *GpuDemo, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUBuffer) void {
        c.SDL_ReleaseGPUBuffer(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releaseTransfer(self: *GpuDemo, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUTransferBuffer) void {
        c.SDL_ReleaseGPUTransferBuffer(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releaseTexture(self: *GpuDemo, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUTexture) void {
        c.SDL_ReleaseGPUTexture(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releaseSampler(self: *GpuDemo, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUSampler) void {
        c.SDL_ReleaseGPUSampler(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releaseShader(self: *GpuDemo, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUShader) void {
        c.SDL_ReleaseGPUShader(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releasePipeline(self: *GpuDemo, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUGraphicsPipeline) void {
        c.SDL_ReleaseGPUGraphicsPipeline(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }
};

fn logAndVerifyDriverSupport() !void {
    const driver_count = c.SDL_GetNumGPUDrivers();
    if (driver_count < 0) return failSdl("SDL_GetNumGPUDrivers", error.GpuDeviceCreationFailure);
    var index: c_int = 0;
    while (index < driver_count) : (index += 1) {
        const available = c.SDL_GetGPUDriver(index);
        if (available != null) std.log.info("available SDL GPU driver: {s}", .{std.mem.span(@as([*:0]const u8, @ptrCast(available)))});
    }
    if (!c.SDL_GPUSupportsShaderFormats(c.SDL_GPU_SHADERFORMAT_DXIL, "direct3d12")) return error.ShaderFormatMismatch;
}

fn createShader(device: *c.SDL_GPUDevice, relative_path: []const u8, entry_point: [*:0]const u8, stage: c.SDL_GPUShaderStage, num_samplers: u32, num_uniform_buffers: u32) !*c.SDL_GPUShader {
    const base_pointer = c.SDL_GetBasePath();
    if (base_pointer == null) return failSdl("SDL_GetBasePath(shader)", error.ShaderCreationFailure);
    const base = std.mem.span(@as([*:0]const u8, @ptrCast(base_pointer)));
    var path_buffer: [4096]u8 = undefined;
    const path = std.fmt.bufPrintZ(&path_buffer, "{s}{s}", .{ base, relative_path }) catch return error.ShaderPathTooLong;
    var code_size: usize = 0;
    const code = c.SDL_LoadFile(path.ptr, &code_size);
    if (code == null) return failSdl("SDL_LoadFile(DXIL shader)", error.ShaderCreationFailure);
    defer c.SDL_free(code);
    var info: c.SDL_GPUShaderCreateInfo = std.mem.zeroes(c.SDL_GPUShaderCreateInfo);
    info.code_size = code_size;
    info.code = @ptrCast(code);
    info.entrypoint = entry_point;
    info.format = c.SDL_GPU_SHADERFORMAT_DXIL;
    info.stage = stage;
    info.num_samplers = num_samplers;
    info.num_uniform_buffers = num_uniform_buffers;
    return c.SDL_CreateGPUShader(device, &info) orelse failSdl("SDL_CreateGPUShader(DXIL)", error.ShaderCreationFailure);
}

fn createTexture(device: *c.SDL_GPUDevice, usage: c.SDL_GPUTextureUsageFlags, width: u32, height: u32) ?*c.SDL_GPUTexture {
    var info: c.SDL_GPUTextureCreateInfo = std.mem.zeroes(c.SDL_GPUTextureCreateInfo);
    info.type = c.SDL_GPU_TEXTURETYPE_2D;
    info.format = c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    info.usage = usage;
    info.width = width;
    info.height = height;
    info.layer_count_or_depth = 1;
    info.num_levels = 1;
    info.sample_count = c.SDL_GPU_SAMPLECOUNT_1;
    return c.SDL_CreateGPUTexture(device, &info);
}

fn createBuffer(device: *c.SDL_GPUDevice, usage: c.SDL_GPUBufferUsageFlags, size: u32) ?*c.SDL_GPUBuffer {
    var info: c.SDL_GPUBufferCreateInfo = std.mem.zeroes(c.SDL_GPUBufferCreateInfo);
    info.usage = usage;
    info.size = size;
    return c.SDL_CreateGPUBuffer(device, &info);
}

fn createPipeline(self: GpuDemo) !*c.SDL_GPUGraphicsPipeline {
    const descriptions = [_]c.SDL_GPUVertexBufferDescription{
        .{ .slot = 0, .pitch = @sizeOf(QuadVertex), .input_rate = c.SDL_GPU_VERTEXINPUTRATE_VERTEX, .instance_step_rate = 0 },
        .{ .slot = 1, .pitch = @sizeOf(sprite.GpuInstance), .input_rate = c.SDL_GPU_VERTEXINPUTRATE_INSTANCE, .instance_step_rate = 0 },
    };
    const attributes = [_]c.SDL_GPUVertexAttribute{
        .{ .location = 0, .buffer_slot = 0, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(QuadVertex, "local_position") },
        .{ .location = 1, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(sprite.GpuInstance, "world_position") },
        .{ .location = 2, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT, .offset = @offsetOf(sprite.GpuInstance, "rotation") },
        .{ .location = 3, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(sprite.GpuInstance, "scale") },
        .{ .location = 4, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(sprite.GpuInstance, "pivot") },
        .{ .location = 5, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, .offset = @offsetOf(sprite.GpuInstance, "uv_rect") },
        .{ .location = 6, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, .offset = @offsetOf(sprite.GpuInstance, "tint") },
    };
    var color_target: c.SDL_GPUColorTargetDescription = std.mem.zeroes(c.SDL_GPUColorTargetDescription);
    color_target.format = c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    color_target.blend_state.src_color_blendfactor = c.SDL_GPU_BLENDFACTOR_SRC_ALPHA;
    color_target.blend_state.dst_color_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    color_target.blend_state.color_blend_op = c.SDL_GPU_BLENDOP_ADD;
    color_target.blend_state.src_alpha_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE;
    color_target.blend_state.dst_alpha_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    color_target.blend_state.alpha_blend_op = c.SDL_GPU_BLENDOP_ADD;
    color_target.blend_state.enable_blend = true;
    var info: c.SDL_GPUGraphicsPipelineCreateInfo = std.mem.zeroes(c.SDL_GPUGraphicsPipelineCreateInfo);
    info.vertex_shader = self.vertex_shader.?;
    info.fragment_shader = self.fragment_shader.?;
    info.vertex_input_state = .{
        .vertex_buffer_descriptions = &descriptions,
        .num_vertex_buffers = descriptions.len,
        .vertex_attributes = &attributes,
        .num_vertex_attributes = attributes.len,
    };
    info.primitive_type = c.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
    info.rasterizer_state.fill_mode = c.SDL_GPU_FILLMODE_FILL;
    info.rasterizer_state.cull_mode = c.SDL_GPU_CULLMODE_NONE;
    info.rasterizer_state.front_face = c.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
    info.rasterizer_state.enable_depth_clip = true;
    info.multisample_state.sample_count = c.SDL_GPU_SAMPLECOUNT_1;
    info.target_info.color_target_descriptions = &color_target;
    info.target_info.num_color_targets = 1;
    return c.SDL_CreateGPUGraphicsPipeline(self.device.?, &info) orelse failSdl("SDL_CreateGPUGraphicsPipeline(sprite batch)", error.PipelineCreationFailure);
}

fn uploadBuffer(copy_pass: *c.SDL_GPUCopyPass, transfer: *c.SDL_GPUTransferBuffer, source_offset: u32, destination_buffer: *c.SDL_GPUBuffer, size: u32) void {
    const source = c.SDL_GPUTransferBufferLocation{ .transfer_buffer = transfer, .offset = source_offset };
    const destination = c.SDL_GPUBufferRegion{ .buffer = destination_buffer, .offset = 0, .size = size };
    c.SDL_UploadToGPUBuffer(copy_pass, &source, &destination, false);
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}

fn copyBytes(destination: [*]u8, offset: usize, source: []const u8) void {
    @memcpy(destination[offset .. offset + source.len], source);
}

fn alignForward(value: u32, alignment: u32) u32 {
    return (value + alignment - 1) & ~(alignment - 1);
}

fn readPixel(bytes: [*]const u8, row_pitch: u32, x: u32, y: u32) [4]u8 {
    const offset = y * row_pitch + x * 4;
    return bytes[offset..][0..4].*;
}

fn colorNear(actual: [4]u8, expected: [4]u8, tolerance: u8) bool {
    for (actual, expected) |a, e| {
        const difference = if (a > e) a - e else e - a;
        if (difference > tolerance) return false;
    }
    return true;
}

fn sdlErrorText() []const u8 {
    const pointer = c.SDL_GetError();
    if (pointer == null) return "no SDL diagnostic";
    return std.mem.span(@as([*:0]const u8, @ptrCast(pointer)));
}

fn failSdl(operation: []const u8, result: anyerror) @TypeOf(result) {
    std.log.err("{s}: {s}", .{ operation, sdlErrorText() });
    return result;
}
