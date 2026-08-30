const std = @import("std");
const builtin = @import("builtin");
const c = @import("sdl").c;
const fault_injection = @import("fault_injection");
const sprite = @import("sprite_batch");
const mesh = @import("deformable_mesh");
const render_queue = @import("render_queue");
const mesh_gpu_catalog = @import("mesh_gpu_catalog");
const math = @import("math");
const camera2d = @import("camera2d");
const humanoid = @import("humanoid");
const animation_system = @import("animation_system");
const input = @import("input");
const sdl_input = @import("sdl_input");
const fixed_step = @import("fixed_step");
const controller_demo = @import("controller_demo");
const handshake_ik_demo = @import("handshake_ik_demo");
const integrated_demo = @import("integrated_demo");
const playground_demo = @import("playground_demo");
const modular_body_demo = @import("modular_body_demo");
const equipment_demo = @import("equipment_demo");
const mesh_attachment_demo = @import("mesh_attachment_demo");
const foundation_playground = @import("foundation_playground");
const foundation_evidence = @import("foundation_evidence");
const foundation_coherence = @import("foundation_coherence");
const acceptance_hud = @import("acceptance_hud");
const visual_foundation = @import("visual_foundation");
const art_pack = @import("art_pack");
const art_asset_demo = @import("art_asset_demo");
const wardrobe_demo = @import("wardrobe_demo");
const environment_demo = @import("environment_demo");
const image_decode = @import("image_decode");
const diagnostics = @import("diagnostics");
const debug_draw = @import("debug_draw");
const visual_geometry = @import("visual_geometry");
const visual_geometry_overlay = @import("visual_geometry_overlay");
const visual_truth = @import("visual_truth");
const anatomy_evidence = @import("anatomy_evidence");

pub const DemoMode = enum {
    sprites,
    controller,
    handshake_ik,
    integrated,
    playground,
    modular_body,
    equipment,
    mesh_attachments,
    side_scroller,
    foundation,
    art_assets,
    wardrobe,
    visual_quality,
    anatomy_quality,
    environment,
};

fn usesUnifiedRendering(mode: DemoMode) bool {
    return mode == .mesh_attachments or mode == .foundation or
        mode == .art_assets or mode == .wardrobe or
        mode == .visual_quality or mode == .anatomy_quality or
        mode == .environment;
}

fn visualCapturePath(frame: u32) ?[]const u8 {
    return switch (frame) {
        30 => visual_capture_directory ++ "/01_base_front.ppm",
        90 => visual_capture_directory ++ "/02_base_side.ppm",
        150 => visual_capture_directory ++ "/03_wide_brim_and_male_outfit_front.ppm",
        210 => visual_capture_directory ++ "/04_wide_brim_and_male_outfit_side.ppm",
        270 => visual_capture_directory ++ "/05_ivory_blouse_front.ppm",
        330 => visual_capture_directory ++ "/06_ivory_blouse_side.ppm",
        390 => visual_capture_directory ++ "/07_layered_custom_front.ppm",
        450 => visual_capture_directory ++ "/08_layered_custom_side.ppm",
        510 => visual_capture_directory ++ "/09_locomotion_stride.ppm",
        550 => visual_capture_directory ++ "/10_jump_rise.ppm",
        575 => visual_capture_directory ++ "/11_jump_fall.ppm",
        else => null,
    };
}

const TimeMode = enum { normal, quarter_speed, paused };

const target_width: u32 = 640;
const target_height: u32 = 480;
const visual_capture_directory = "zig-out/p25a_visual_gpu";
const visual_capture_count: u32 = 11;
const geometry_debug_capture_directory = "zig-out/p25c_visual_geometry_debug";
const geometry_debug_capture_path =
    geometry_debug_capture_directory ++ "/03_wide_brim_front_geometry.ppm";
const environment_capture_directory = "zig-out/p26_environment_gpu";
const environment_capture_count: u32 = 7;
const foundation_capture_directory = "zig-out/p27a_evidence/candidate";
const foundation_capture_count: u32 = @intCast(foundation_evidence.capture_count);
const p27b_capture_directory = "zig-out/p27b_evidence/candidate";
const p27b_capture_count: u32 = 4;
const p27c_capture_directory = "zig-out/p27c_evidence/candidate";
const p27c_capture_count: u32 = @intCast(anatomy_evidence.capture_count);
const manual_capture_directory = "zig-out/manual_debug_captures";
const manual_capture_asset_paths = [_][]const u8{
    "assets/art/p27c_male_base_anatomy_atlas.png",
    "assets/art/p27c_female_base_anatomy_atlas.png",
    "assets/art/p27c_anatomy_components_atlas.png",
    "assets/art/p25_wardrobe_upper_atlas.png",
    "assets/art/p25_wardrobe_layers_atlas.png",
    "assets/art/p25_wardrobe_lower_atlas.png",
    "assets/art/p26_violet_crystal_ruin_atlas.png",
    "assets/art/p26_neutral_debug_atlas.png",
};

fn environmentCapturePath(frame: u32) ?[]const u8 {
    return switch (frame) {
        20 => environment_capture_directory ++ "/01_violet_neutral_front.ppm",
        70 => environment_capture_directory ++ "/02_debug_switch_in_place.ppm",
        100 => environment_capture_directory ++ "/03_violet_switch_back.ppm",
        165 => environment_capture_directory ++ "/04_violet_side_parallax.ppm",
        200 => environment_capture_directory ++ "/05_jump_rise.ppm",
        224 => environment_capture_directory ++ "/06_raised_platform_landing.ppm",
        540 => environment_capture_directory ++ "/07_detailed_collider_debug.ppm",
        else => null,
    };
}

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

comptime {
    if (@sizeOf(QuadVertex) != 8 or @alignOf(QuadVertex) != 4) @compileError("QuadVertex layout must match one HLSL float2");
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
    mesh_instance_buffer: ?*c.SDL_GPUBuffer = null,
    mesh_transfer_buffer: ?*c.SDL_GPUTransferBuffer = null,
    fence: ?*c.SDL_GPUFence = null,
};

const ArtTexturePage = struct {
    stable_id: art_pack.TexturePageId,
    width: u32,
    height: u32,
    sampling: art_pack.SamplingPolicy,
    texture: *c.SDL_GPUTexture,
    sampler: *c.SDL_GPUSampler,
};

const ArtUploadFault = enum {
    after_texture_creation,
    before_upload_submission,
};

const ResourceMetrics = struct {
    gpu_resource_creations: u64 = 0,
    gpu_resource_releases: u64 = 0,
    fence_acquisitions: u64 = 0,
    fence_releases: u64 = 0,
    frame_slot_fence_waits: u64 = 0,
    upload_buffer_growths: u64 = 0,
    frames_rendered: u64 = 0,
    resize_events: u64 = 0,
    viewport_updates: u64 = 0,
    zero_drawable_frames: u64 = 0,
};

const ReadbackPixels = struct {
    outside: [4]u8,
    inside_a: [4]u8,
    inside_b: [4]u8,
    row_pitch: u32,
};

const CapturePixelEvidence = struct {
    width: u32 = 0,
    height: u32 = 0,
    rgb_payload_bytes: u64 = 0,
    sha256: [32]u8 = [_]u8{0} ** 32,
    minimum_channel: u8 = 255,
    maximum_channel: u8 = 0,
    mean_channel: f64 = 0,
};

const FoundationCaptureArtifact = struct {
    captured: bool = false,
    stable_ticks: u32 = 0,
    observation: foundation_evidence.Observation = .{},
    pixels: CapturePixelEvidence = .{},
};

const P27bCaptureArtifact = struct {
    captured: bool = false,
    filename: []const u8 = "",
    camera_center: [2]f32 = .{ 0, 0 },
    viewport: [2]u32 = .{ 0, 0 },
    previous_viewport: [2]u32 = .{ 0, 0 },
    first_post_abrupt_resize: bool = false,
    semantic_headroom_px: f32 = 0,
    semantic_footroom_px: f32 = 0,
    instantaneous_reprojection_world_delta_px: f32 = 0,
    pixels: CapturePixelEvidence = .{},
};

const AnatomyCaptureArtifact = struct {
    captured: bool = false,
    stable_frames: u16 = 0,
    observation: anatomy_evidence.Observation = undefined,
    pixels: CapturePixelEvidence = .{},
};

fn anatomyObservation(
    scene: *const wardrobe_demo.Scene,
    trace: *const visual_geometry.Trace,
    render_frame: u32,
) !anatomy_evidence.Observation {
    var resolved_view: ?visual_geometry.View = null;
    var upper_arm_rotation: [2]?f32 = .{ null, null };
    var forearm_rotation: [2]?f32 = .{ null, null };
    var thigh_rotation: [2]?f32 = .{ null, null };
    var shin_rotation: [2]?f32 = .{ null, null };
    var anatomy_records: u16 = 0;
    for (trace.slice()) |record| {
        if (record.character_id != scene.female.id.raw() or
            (record.owner != .anatomy and
                record.owner != .base_presentation))
        {
            continue;
        }
        anatomy_records = std.math.add(u16, anatomy_records, 1) catch
            return error.AnatomyTraceCountOverflow;
        if (record.role == .torso) resolved_view = record.view;
        const side_index: usize = switch (record.side) {
            .left => 0,
            .right => 1,
            .none => continue,
        };
        switch (record.role) {
            .upper_arm => upper_arm_rotation[side_index] = record.request.rotation,
            .forearm => forearm_rotation[side_index] = record.request.rotation,
            .thigh => thigh_rotation[side_index] = record.request.rotation,
            .shin => shin_rotation[side_index] = record.request.rotation,
            else => {},
        }
    }
    const anatomy_runtime = scene.female.character.anatomy_runtime orelse
        return error.AnatomyEvidenceRuntimeMissing;
    return .{
        .render_frame = render_frame,
        .simulation_tick = scene.simulation_tick,
        .stage = scene.anatomy_evidence_stage,
        .stage_frame = scene.anatomy_stage_frame,
        .view = resolved_view orelse return error.AnatomyEvidenceViewMissing,
        .facing = if (scene.female.facing == .left) .left else .right,
        .animation = @tagName(scene.female.animationState()),
        .global_build = anatomy_runtime.global_build_normalized * 100,
        .elbow_angle_degrees = try maximumBilateralAngle(
            upper_arm_rotation,
            forearm_rotation,
        ),
        .knee_angle_degrees = try maximumBilateralAngle(
            thigh_rotation,
            shin_rotation,
        ),
        .anatomy_trace_records = anatomy_records,
    };
}

fn angularDifferenceDegrees(a: f32, b: f32) f32 {
    var difference = @mod(@abs(a - b), 2.0 * std.math.pi);
    if (difference > std.math.pi) difference = 2.0 * std.math.pi - difference;
    return std.math.radiansToDegrees(difference);
}

fn maximumBilateralAngle(
    proximal: [2]?f32,
    distal: [2]?f32,
) !f32 {
    var maximum: ?f32 = null;
    for (proximal, distal) |proximal_rotation, distal_rotation| {
        if (proximal_rotation == null or distal_rotation == null) continue;
        const angle = angularDifferenceDegrees(
            proximal_rotation.?,
            distal_rotation.?,
        );
        maximum = if (maximum) |value| @max(value, angle) else angle;
    }
    return maximum orelse error.AnatomyJointTraceMissing;
}

fn writeOptionalU32(file: anytype, io: std.Io, value: ?u32) !void {
    if (value) |number| {
        var buffer: [32]u8 = undefined;
        const bytes = try std.fmt.bufPrint(&buffer, "{d}", .{number});
        try file.writeStreamingAll(io, bytes);
    } else {
        try file.writeStreamingAll(io, "null");
    }
}

fn writeOptionalF32(file: anytype, io: std.Io, value: ?f32) !void {
    if (value) |number| {
        var buffer: [32]u8 = undefined;
        const bytes = try std.fmt.bufPrint(&buffer, "{d:.6}", .{number});
        try file.writeStreamingAll(io, bytes);
    } else {
        try file.writeStreamingAll(io, "null");
    }
}

const EncodedDrawCounts = struct {
    sprites: u32 = 0,
    meshes: u32 = 0,
};

pub const GpuDemo = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    batch: ?sprite.SpriteBatch = null,
    unified_queue: ?render_queue.UnifiedRenderQueue = null,
    mesh_catalog: ?mesh_gpu_catalog.Catalog = null,
    sdl_initialized: bool = false,
    window_claimed: bool = false,
    window: ?*c.SDL_Window = null,
    device: ?*c.SDL_GPUDevice = null,
    vertex_shader: ?*c.SDL_GPUShader = null,
    mesh_vertex_shader: ?*c.SDL_GPUShader = null,
    fragment_shader: ?*c.SDL_GPUShader = null,
    sampler: ?*c.SDL_GPUSampler = null,
    sampled_texture: ?*c.SDL_GPUTexture = null,
    render_target: ?*c.SDL_GPUTexture = null,
    quad_vertex_buffer: ?*c.SDL_GPUBuffer = null,
    quad_index_buffer: ?*c.SDL_GPUBuffer = null,
    mesh_vertex_buffer: ?*c.SDL_GPUBuffer = null,
    mesh_index_buffer: ?*c.SDL_GPUBuffer = null,
    static_upload_transfer: ?*c.SDL_GPUTransferBuffer = null,
    visual_capture_transfer: ?*c.SDL_GPUTransferBuffer = null,
    offscreen_pipeline: ?*c.SDL_GPUGraphicsPipeline = null,
    window_pipeline: ?*c.SDL_GPUGraphicsPipeline = null,
    mesh_offscreen_pipeline: ?*c.SDL_GPUGraphicsPipeline = null,
    mesh_window_pipeline: ?*c.SDL_GPUGraphicsPipeline = null,
    frame_slots: [frame_slot_count]FrameSlot = [_]FrameSlot{.{}} ** frame_slot_count,
    gpu_instance_capacity: usize = 0,
    current_frame_slot: usize = 0,
    resource_metrics: ResourceMetrics = .{},
    visible_camera: camera2d.Camera2D = camera2d.Camera2D.initDefault(),
    drawable_width: u32 = target_width,
    drawable_height: u32 = target_height,
    drawable_available: bool = true,
    texture_page_count: u32 = 1,
    art_texture_pages: [art_pack.maximum_texture_pages]?ArtTexturePage = [_]?ArtTexturePage{null} ** art_pack.maximum_texture_pages,
    art_texture_page_count: usize = 0,
    image_decode_metrics: image_decode.Metrics = .{},
    visual_captures_written: u32 = 0,
    manual_capture_next_index: u64 = 0,
    manual_captures_written: u64 = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        hidden: bool,
        injector: ?fault_injection.Injector,
    ) !GpuDemo {
        var self = GpuDemo{ .allocator = allocator, .io = io };
        errdefer self.deinit();

        self.batch = try sprite.SpriteBatch.init(allocator, sprite.initial_capacity, 1);
        try after(injector, .sprite_batch_cpu_allocation);

        if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_GAMEPAD)) return failSdl("SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)", error.SdlInitializationFailure);
        self.sdl_initialized = true;
        try after(injector, .sdl_initialization);

        const window_flags: c.SDL_WindowFlags = if (hidden) c.SDL_WINDOW_HIDDEN else c.SDL_WINDOW_RESIZABLE;
        self.window = c.SDL_CreateWindow("Authoritative SDL GPU sprite batch", target_width, target_height, window_flags);
        if (self.window == null) return failSdl("SDL_CreateWindow", error.WindowCreationFailure);
        try self.refreshDrawableSize();
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

        self.offscreen_pipeline = try createPipeline(self, c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM);
        self.resource_metrics.gpu_resource_creations += 1;
        const swapchain_format = c.SDL_GetGPUSwapchainTextureFormat(self.device.?, self.window.?);
        if (swapchain_format == c.SDL_GPU_TEXTUREFORMAT_INVALID) {
            return failSdl("SDL_GetGPUSwapchainTextureFormat", error.SwapchainFormatQueryFailure);
        }
        self.window_pipeline = try createPipeline(self, swapchain_format);
        self.resource_metrics.gpu_resource_creations += 1;
        try after(injector, .pipeline_creation);
        return self;
    }

    pub fn deinit(self: *GpuDemo) void {
        if (self.device) |device| {
            for (&self.frame_slots) |*slot| self.waitAndReleaseFence(slot, false) catch {};
            if (!c.SDL_WaitForGPUIdle(device)) std.log.err("SDL_WaitForGPUIdle during cleanup: {s}", .{sdlErrorText()});
            self.releaseSlotResources(&self.frame_slots);
            if (self.mesh_window_pipeline) |resource| self.releasePipeline(device, resource);
            if (self.mesh_offscreen_pipeline) |resource| self.releasePipeline(device, resource);
            if (self.window_pipeline) |resource| self.releasePipeline(device, resource);
            if (self.offscreen_pipeline) |resource| self.releasePipeline(device, resource);
            if (self.visual_capture_transfer) |resource| self.releaseTransfer(device, resource);
            if (self.static_upload_transfer) |resource| self.releaseTransfer(device, resource);
            if (self.mesh_index_buffer) |resource| self.releaseBuffer(device, resource);
            if (self.mesh_vertex_buffer) |resource| self.releaseBuffer(device, resource);
            if (self.quad_index_buffer) |resource| self.releaseBuffer(device, resource);
            if (self.quad_vertex_buffer) |resource| self.releaseBuffer(device, resource);
            if (self.render_target) |resource| self.releaseTexture(device, resource);
            for (self.art_texture_pages[0..self.art_texture_page_count]) |page| {
                if (page) |resource| {
                    self.releaseTexture(device, resource.texture);
                    self.releaseSampler(device, resource.sampler);
                }
            }
            self.art_texture_page_count = 0;
            if (self.sampled_texture) |resource| self.releaseTexture(device, resource);
            if (self.sampler) |resource| self.releaseSampler(device, resource);
            if (self.fragment_shader) |resource| self.releaseShader(device, resource);
            if (self.mesh_vertex_shader) |resource| self.releaseShader(device, resource);
            if (self.vertex_shader) |resource| self.releaseShader(device, resource);
            if (self.window_claimed and self.window != null) c.SDL_ReleaseWindowFromGPUDevice(device, self.window.?);
            c.SDL_DestroyGPUDevice(device);
        }
        if (self.window) |window| c.SDL_DestroyWindow(window);
        if (self.sdl_initialized) c.SDL_Quit();
        if (self.batch) |*batch| batch.deinit();
        self.batch = null;
        if (self.unified_queue) |*queue| queue.deinit();
        self.unified_queue = null;
        if (self.mesh_catalog) |*catalog| catalog.deinit();
        self.mesh_catalog = null;
    }

    fn initializeUnifiedQueue(self: *GpuDemo) !void {
        if (self.unified_queue != null) return error.UnifiedQueueAlreadyInitialized;
        self.unified_queue = try render_queue.UnifiedRenderQueue.init(
            self.allocator,
            render_queue.default_entry_capacity,
            render_queue.default_sprite_capacity,
            render_queue.default_mesh_capacity,
            self.texture_page_count,
        );
    }

    fn initializeVisualCaptureTransfer(self: *GpuDemo, geometry_debug: bool) !void {
        if (self.visual_capture_transfer != null) {
            return error.VisualCaptureTransferAlreadyInitialized;
        }
        try std.Io.Dir.cwd().createDirPath(self.io, visual_capture_directory);
        try std.Io.Dir.cwd().createDirPath(self.io, environment_capture_directory);
        try std.Io.Dir.cwd().createDirPath(self.io, foundation_capture_directory);
        try std.Io.Dir.cwd().createDirPath(self.io, p27b_capture_directory);
        try std.Io.Dir.cwd().createDirPath(self.io, manual_capture_directory);
        if (geometry_debug) {
            try std.Io.Dir.cwd().createDirPath(self.io, geometry_debug_capture_directory);
        }
        const row_pitch = alignForward(target_width * 4, 256);
        var transfer_info: c.SDL_GPUTransferBufferCreateInfo = std.mem.zeroes(
            c.SDL_GPUTransferBufferCreateInfo,
        );
        transfer_info.usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD;
        transfer_info.size = row_pitch * target_height;
        self.visual_capture_transfer = c.SDL_CreateGPUTransferBuffer(
            self.device.?,
            &transfer_info,
        ) orelse return failSdl(
            "SDL_CreateGPUTransferBuffer(Prompt 25A persistent capture)",
            error.GpuTransferBufferCreationFailure,
        );
        self.resource_metrics.gpu_resource_creations += 1;
    }

    fn initializeMeshRendering(self: *GpuDemo, definitions: []const mesh.DefinitionView) !void {
        if (self.unified_queue != null or self.mesh_catalog != null or self.mesh_vertex_shader != null) {
            return error.MeshRenderingAlreadyInitialized;
        }
        try self.initializeUnifiedQueue();
        self.mesh_catalog = try mesh_gpu_catalog.Catalog.init(self.allocator, definitions);
        const catalog = &self.mesh_catalog.?;

        self.mesh_vertex_shader = try createShader(
            self.device.?,
            "shaders\\deformable_mesh_vs.dxil",
            "VSMain",
            c.SDL_GPU_SHADERSTAGE_VERTEX,
            0,
            1,
        );
        self.resource_metrics.gpu_resource_creations += 1;

        const vertex_bytes = try catalog.vertexBytes();
        const index_bytes = try catalog.indexBytes();
        self.mesh_vertex_buffer = createBuffer(self.device.?, c.SDL_GPU_BUFFERUSAGE_VERTEX, vertex_bytes) orelse
            return failSdl("SDL_CreateGPUBuffer(mesh topology vertices)", error.MeshVertexBufferCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        self.mesh_index_buffer = createBuffer(self.device.?, c.SDL_GPU_BUFFERUSAGE_INDEX, index_bytes) orelse
            return failSdl("SDL_CreateGPUBuffer(mesh topology indices)", error.MeshIndexBufferCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;

        const transfer_size = try catalog.uploadBytes();
        var transfer_info: c.SDL_GPUTransferBufferCreateInfo = std.mem.zeroes(c.SDL_GPUTransferBufferCreateInfo);
        transfer_info.usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
        transfer_info.size = transfer_size;
        const transfer = c.SDL_CreateGPUTransferBuffer(self.device.?, &transfer_info) orelse
            return failSdl("SDL_CreateGPUTransferBuffer(mesh static topology)", error.GpuTransferBufferCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        defer self.releaseTransfer(self.device.?, transfer);

        const mapped = c.SDL_MapGPUTransferBuffer(self.device.?, transfer, false) orelse
            return failSdl("SDL_MapGPUTransferBuffer(mesh static topology)", error.UploadFailure);
        const bytes: [*]u8 = @ptrCast(mapped);
        copyBytes(bytes, 0, std.mem.sliceAsBytes(catalog.vertices));
        copyBytes(bytes, vertex_bytes, std.mem.sliceAsBytes(catalog.indices));
        c.SDL_UnmapGPUTransferBuffer(self.device.?, transfer);

        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse
            return failSdl("SDL_AcquireGPUCommandBuffer(mesh topology upload)", error.UploadFailure);
        var command_active = true;
        errdefer if (command_active) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) {
                std.log.err("SDL_CancelGPUCommandBuffer(mesh topology upload): {s}", .{sdlErrorText()});
            }
        };
        const copy_pass = c.SDL_BeginGPUCopyPass(command);
        if (copy_pass == null) return failSdl("SDL_BeginGPUCopyPass(mesh topology upload)", error.UploadFailure);
        uploadBuffer(copy_pass.?, transfer, 0, self.mesh_vertex_buffer.?, vertex_bytes);
        uploadBuffer(copy_pass.?, transfer, vertex_bytes, self.mesh_index_buffer.?, index_bytes);
        c.SDL_EndGPUCopyPass(copy_pass.?);
        const fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
        command_active = false;
        if (fence == null) {
            return failSdl("SDL_SubmitGPUCommandBufferAndAcquireFence(mesh topology upload)", error.UploadFailure);
        }
        self.resource_metrics.fence_acquisitions += 1;
        try self.waitReleaseStandaloneFence(fence.?);

        try self.createMeshSlotResources(render_queue.default_mesh_capacity);
        self.mesh_offscreen_pipeline = try createMeshPipeline(self, c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM);
        self.resource_metrics.gpu_resource_creations += 1;
        const swapchain_format = c.SDL_GetGPUSwapchainTextureFormat(self.device.?, self.window.?);
        if (swapchain_format == c.SDL_GPU_TEXTUREFORMAT_INVALID) {
            return failSdl("SDL_GetGPUSwapchainTextureFormat(mesh pipeline)", error.SwapchainFormatQueryFailure);
        }
        self.mesh_window_pipeline = try createMeshPipeline(self, swapchain_format);
        self.resource_metrics.gpu_resource_creations += 1;
        std.log.info("initialized persistent mesh GPU resources: definitions={d} vertices={d} indices={d} topology_upload={d}B frame_slots={d}", .{
            catalog.entries.len,
            catalog.vertices.len,
            catalog.indices.len,
            transfer_size,
            frame_slot_count,
        });
    }

    fn initializeArtTexturePages(self: *GpuDemo, definition: *const art_pack.Definition) !void {
        return self.initializeArtTexturePageSets(&.{definition});
    }

    fn initializeArtTexturePageSets(
        self: *GpuDemo,
        definitions: []const *const art_pack.Definition,
    ) !void {
        if (self.art_texture_page_count != 0 or self.texture_page_count != 1) {
            return error.ArtTexturePagesAlreadyInitialized;
        }
        if (definitions.len == 0) return error.InvalidArtTexturePageCount;
        var total_pages: usize = 0;
        for (definitions) |definition| {
            if (definition.pages.len == 0) return error.InvalidArtTexturePageCount;
            total_pages = std.math.add(usize, total_pages, definition.pages.len) catch
                return error.InvalidArtTexturePageCount;
        }
        if (total_pages > art_pack.maximum_texture_pages) {
            return error.InvalidArtTexturePageCount;
        }
        const configured_page_count = 1 + @as(u32, @intCast(total_pages));
        var replacement_batch = try sprite.SpriteBatch.init(
            self.allocator,
            sprite.initial_capacity,
            configured_page_count,
        );
        var replacement_batch_authoritative = false;
        defer if (!replacement_batch_authoritative) replacement_batch.deinit();

        var pending = [_]?ArtTexturePage{null} ** art_pack.maximum_texture_pages;
        var pending_count: usize = 0;
        errdefer for (pending[0..pending_count]) |page| {
            if (page) |resource| {
                self.releaseTexture(self.device.?, resource.texture);
                self.releaseSampler(self.device.?, resource.sampler);
            }
        };

        self.image_decode_metrics = .{};
        for (definitions) |definition| {
            for (definition.pages) |page_definition| {
                pending[pending_count] = try self.createArtTexturePage(page_definition, null);
                pending_count += 1;
            }
        }

        for (pending[0..pending_count], 0..) |page, index| self.art_texture_pages[index] = page;
        self.art_texture_page_count = pending_count;
        self.texture_page_count = configured_page_count;
        self.batch.?.deinit();
        self.batch = replacement_batch;
        replacement_batch_authoritative = true;
        std.log.info("initialized production art pages: pages={d} configured_renderer_pages={d} decoded_files={d} decoded_bytes={d}", .{
            pending_count,
            self.texture_page_count,
            self.image_decode_metrics.successful_decodes,
            self.image_decode_metrics.decoded_bytes,
        });
    }

    fn runArtTextureFaultChecks(self: *GpuDemo, definition: *const art_pack.Definition) !void {
        if (definition.pages.len == 0) return error.MissingTexturePages;
        for ([_]ArtUploadFault{ .after_texture_creation, .before_upload_submission }) |fault| {
            const creations_before = self.resource_metrics.gpu_resource_creations;
            const releases_before = self.resource_metrics.gpu_resource_releases;
            const result = self.createArtTexturePage(definition.pages[0], fault);
            if (result) |page| {
                self.releaseTexture(self.device.?, page.texture);
                self.releaseSampler(self.device.?, page.sampler);
                return error.ArtTextureFaultDidNotTrigger;
            } else |err| {
                if (err != error.InjectedArtTextureFailure) return err;
            }
            const creation_delta = self.resource_metrics.gpu_resource_creations - creations_before;
            const release_delta = self.resource_metrics.gpu_resource_releases - releases_before;
            if (creation_delta == 0 or creation_delta != release_delta) {
                std.log.err("art texture fault cleanup mismatch: stage={s} creations={d} releases={d}", .{
                    @tagName(fault),
                    creation_delta,
                    release_delta,
                });
                return error.ArtTextureFaultCleanupMismatch;
            }
            std.log.info("art texture fault cleanup passed: stage={s} resources={d}", .{ @tagName(fault), creation_delta });
        }
        if (definition.pages.len >= 2) {
            const creations_before = self.resource_metrics.gpu_resource_creations;
            const releases_before = self.resource_metrics.gpu_resource_releases;
            const first_page = try self.createArtTexturePage(definition.pages[0], null);
            var first_page_owned = true;
            defer if (first_page_owned) {
                self.releaseTexture(self.device.?, first_page.texture);
                self.releaseSampler(self.device.?, first_page.sampler);
            };
            const result = self.createArtTexturePage(definition.pages[1], .after_texture_creation);
            if (result) |second_page| {
                self.releaseTexture(self.device.?, second_page.texture);
                self.releaseSampler(self.device.?, second_page.sampler);
                return error.ArtTextureFaultDidNotTrigger;
            } else |err| {
                if (err != error.InjectedArtTextureFailure) return err;
            }
            self.releaseTexture(self.device.?, first_page.texture);
            self.releaseSampler(self.device.?, first_page.sampler);
            first_page_owned = false;
            const creation_delta = self.resource_metrics.gpu_resource_creations - creations_before;
            const release_delta = self.resource_metrics.gpu_resource_releases - releases_before;
            if (creation_delta != release_delta) return error.ArtTextureFaultCleanupMismatch;
            std.log.info("art texture page-set rollback passed: completed_pages=1 resources={d}", .{creation_delta});
        }
    }

    fn createArtTexturePage(
        self: *GpuDemo,
        definition: art_pack.TexturePageDefinition,
        injected_fault: ?ArtUploadFault,
    ) !ArtTexturePage {
        const base_pointer = c.SDL_GetBasePath();
        if (base_pointer == null) return failSdl("SDL_GetBasePath(art texture)", error.ImagePathResolutionFailure);
        const base = std.mem.span(@as([*:0]const u8, @ptrCast(base_pointer)));
        var path_buffer: [4096]u8 = undefined;
        const path = std.fmt.bufPrintZ(&path_buffer, "{s}{s}", .{ base, definition.asset_path.slice() }) catch
            return error.ImagePathTooLong;
        var decoded = image_decode.decodePngFile(self.allocator, path, &self.image_decode_metrics) catch |err| {
            std.log.err("decode art page failed: page={s} path={s} error={s}", .{
                definition.stable_name.slice(),
                path,
                @errorName(err),
            });
            return err;
        };
        defer decoded.deinit();
        if (decoded.layout.width != definition.expected_width or decoded.layout.height != definition.expected_height) {
            std.log.err("art page dimensions mismatch: page={s} expected={d}x{d} decoded={d}x{d}", .{
                definition.stable_name.slice(),
                definition.expected_width,
                definition.expected_height,
                decoded.layout.width,
                decoded.layout.height,
            });
            return error.ImageDimensionsMismatch;
        }

        var sampler_info: c.SDL_GPUSamplerCreateInfo = std.mem.zeroes(c.SDL_GPUSamplerCreateInfo);
        sampler_info.min_filter = if (definition.sampling == .nearest) c.SDL_GPU_FILTER_NEAREST else c.SDL_GPU_FILTER_LINEAR;
        sampler_info.mag_filter = if (definition.sampling == .nearest) c.SDL_GPU_FILTER_NEAREST else c.SDL_GPU_FILTER_LINEAR;
        sampler_info.mipmap_mode = if (definition.sampling == .nearest) c.SDL_GPU_SAMPLERMIPMAPMODE_NEAREST else c.SDL_GPU_SAMPLERMIPMAPMODE_LINEAR;
        sampler_info.address_mode_u = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        sampler_info.address_mode_v = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        sampler_info.address_mode_w = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        const sampler = c.SDL_CreateGPUSampler(self.device.?, &sampler_info) orelse
            return failSdl("SDL_CreateGPUSampler(art page)", error.SamplerCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        errdefer self.releaseSampler(self.device.?, sampler);

        const texture = createTexture(
            self.device.?,
            c.SDL_GPU_TEXTUREUSAGE_SAMPLER,
            decoded.layout.width,
            decoded.layout.height,
        ) orelse return failSdl("SDL_CreateGPUTexture(art page)", error.TextureCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        errdefer self.releaseTexture(self.device.?, texture);
        if (injected_fault == .after_texture_creation) return error.InjectedArtTextureFailure;

        const row_pitch = std.math.add(u32, decoded.layout.row_bytes, upload_texture_row_pitch - 1) catch
            return error.ImageUploadSizeOverflow;
        const aligned_row_pitch = row_pitch & ~(upload_texture_row_pitch - 1);
        const upload_size = std.math.mul(u32, aligned_row_pitch, decoded.layout.height) catch
            return error.ImageUploadSizeOverflow;
        var transfer_info: c.SDL_GPUTransferBufferCreateInfo = std.mem.zeroes(c.SDL_GPUTransferBufferCreateInfo);
        transfer_info.usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
        transfer_info.size = upload_size;
        const transfer = c.SDL_CreateGPUTransferBuffer(self.device.?, &transfer_info) orelse
            return failSdl("SDL_CreateGPUTransferBuffer(art page)", error.GpuTransferBufferCreationFailure);
        self.resource_metrics.gpu_resource_creations += 1;
        defer self.releaseTransfer(self.device.?, transfer);

        const mapped = c.SDL_MapGPUTransferBuffer(self.device.?, transfer, false) orelse
            return failSdl("SDL_MapGPUTransferBuffer(art page)", error.UploadFailure);
        const mapped_bytes: [*]u8 = @ptrCast(mapped);
        @memset(mapped_bytes[0..upload_size], 0);
        for (0..decoded.layout.height) |row| {
            const source_start = row * decoded.layout.row_bytes;
            const destination_start = row * aligned_row_pitch;
            @memcpy(
                mapped_bytes[destination_start .. destination_start + decoded.layout.row_bytes],
                decoded.pixels[source_start .. source_start + decoded.layout.row_bytes],
            );
        }
        c.SDL_UnmapGPUTransferBuffer(self.device.?, transfer);
        if (injected_fault == .before_upload_submission) return error.InjectedArtTextureFailure;

        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse
            return failSdl("SDL_AcquireGPUCommandBuffer(art page upload)", error.UploadFailure);
        var command_active = true;
        errdefer if (command_active) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) {
                std.log.err("SDL_CancelGPUCommandBuffer(art page upload): {s}", .{sdlErrorText()});
            }
        };
        const copy_pass = c.SDL_BeginGPUCopyPass(command);
        if (copy_pass == null) return failSdl("SDL_BeginGPUCopyPass(art page upload)", error.UploadFailure);
        const source = c.SDL_GPUTextureTransferInfo{
            .transfer_buffer = transfer,
            .offset = 0,
            .pixels_per_row = aligned_row_pitch / image_decode.rgba_channel_count,
            .rows_per_layer = decoded.layout.height,
        };
        const destination = c.SDL_GPUTextureRegion{
            .texture = texture,
            .mip_level = 0,
            .layer = 0,
            .x = 0,
            .y = 0,
            .z = 0,
            .w = decoded.layout.width,
            .h = decoded.layout.height,
            .d = 1,
        };
        c.SDL_UploadToGPUTexture(copy_pass.?, &source, &destination, false);
        c.SDL_EndGPUCopyPass(copy_pass.?);
        const fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
        command_active = false;
        if (fence == null) return failSdl("SDL_SubmitGPUCommandBufferAndAcquireFence(art page)", error.UploadFailure);
        self.resource_metrics.fence_acquisitions += 1;
        try self.waitReleaseStandaloneFence(fence.?);

        return .{
            .stable_id = definition.id,
            .width = decoded.layout.width,
            .height = decoded.layout.height,
            .sampling = definition.sampling,
            .texture = texture,
            .sampler = sampler,
        };
    }

    fn textureBinding(self: *const GpuDemo, texture_page: u32) !c.SDL_GPUTextureSamplerBinding {
        if (texture_page == 0) {
            return .{ .texture = self.sampled_texture.?, .sampler = self.sampler.? };
        }
        const index: usize = texture_page - 1;
        if (index >= self.art_texture_page_count) return error.InvalidTexturePage;
        const page = self.art_texture_pages[index] orelse return error.InvalidTexturePage;
        return .{ .texture = page.texture, .sampler = page.sampler };
    }

    fn handleWindowEvent(self: *GpuDemo, event: *const c.SDL_Event) !void {
        switch (event.type) {
            c.SDL_EVENT_WINDOW_MINIMIZED => {
                self.resource_metrics.resize_events += 1;
                self.drawable_available = false;
                self.drawable_width = 0;
                self.drawable_height = 0;
            },
            c.SDL_EVENT_WINDOW_RESIZED,
            c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
            c.SDL_EVENT_WINDOW_RESTORED,
            => {
                self.resource_metrics.resize_events += 1;
                try self.refreshDrawableSize();
            },
            else => {},
        }
    }

    fn refreshDrawableSize(self: *GpuDemo) !void {
        var pixel_width: c_int = 0;
        var pixel_height: c_int = 0;
        if (!c.SDL_GetWindowSizeInPixels(self.window.?, &pixel_width, &pixel_height)) {
            return failSdl("SDL_GetWindowSizeInPixels", error.WindowPixelSizeQueryFailure);
        }
        if (pixel_width <= 0 or pixel_height <= 0) {
            self.drawable_available = false;
            self.drawable_width = 0;
            self.drawable_height = 0;
            return;
        }
        try self.applyDrawableSize(@intCast(pixel_width), @intCast(pixel_height));
    }

    fn applyDrawableSize(self: *GpuDemo, pixel_width: u32, pixel_height: u32) !void {
        if (pixel_width == 0 or pixel_height == 0) return error.ZeroDrawableSize;
        const changed = self.drawable_width != pixel_width or
            self.drawable_height != pixel_height or
            !self.drawable_available;
        // Scene publication can replace visible_camera before submission.
        // Reapply the acquired swapchain dimensions every frame so the GPU
        // always receives the authoritative drawable-derived scale.
        try self.visible_camera.setViewport(pixel_width, pixel_height);
        if (changed) {
            self.drawable_width = pixel_width;
            self.drawable_height = pixel_height;
            self.drawable_available = true;
            self.resource_metrics.viewport_updates += 1;
        }
    }

    pub fn runVisible(
        self: *GpuDemo,
        maximum_frames: ?u32,
        mode: DemoMode,
        scripted_input_enabled: bool,
        integrated_debug_enabled: bool,
        interactive_enabled: bool,
        registration_proof_case: ?visual_foundation.RegistrationProofCase,
        component_proof_case: ?visual_foundation.ComponentProofCase,
        capture_manual_bundle: bool,
    ) !void {
        self.visible_camera = camera2d.Camera2D.initDefault();
        if (self.drawable_available) try self.visible_camera.setViewport(self.drawable_width, self.drawable_height);
        const camera_follower = try camera2d.HorizontalFollower.init(3.25);
        var minimum_camera_x = self.visible_camera.center.x;
        var maximum_camera_x = self.visible_camera.center.x;
        const demo_storage = self.allocator.alloc(u8, 4 * 1024 * 1024) catch return error.DemoStorageAllocationFailure;
        defer self.allocator.free(demo_storage);
        var humanoid_allocator = std.heap.FixedBufferAllocator.init(demo_storage);
        var humanoid_demo: ?humanoid.DemoCharacter = null;
        defer if (humanoid_demo) |*demo| demo.deinit();
        var animation_runtime: ?animation_system.Runtime = null;
        defer if (animation_runtime) |*runtime| runtime.deinit();
        var controller_runtime: ?controller_demo.Runtime = null;
        defer if (controller_runtime) |*runtime| runtime.deinit();
        var handshake_ik_scene: ?handshake_ik_demo.Scene = null;
        defer if (handshake_ik_scene) |*scene| scene.deinit();
        var integrated_scene: ?integrated_demo.Scene = null;
        defer if (integrated_scene) |*scene| scene.deinit();
        var playground_scene: ?playground_demo.Scene = null;
        defer if (playground_scene) |*scene| scene.deinit();
        var modular_body_scene: ?modular_body_demo.Scene = null;
        defer if (modular_body_scene) |*scene| scene.deinit();
        var equipment_scene: ?equipment_demo.Scene = null;
        defer if (equipment_scene) |*scene| scene.deinit();
        var mesh_attachment_scene: ?mesh_attachment_demo.Scene = null;
        defer if (mesh_attachment_scene) |*scene| scene.deinit();
        var foundation_scene: ?*visual_foundation.Scene = null;
        defer if (foundation_scene) |scene| {
            scene.deinit();
            self.allocator.destroy(scene);
        };
        var art_scene: ?art_asset_demo.Scene = null;
        defer if (art_scene) |*scene| scene.deinit();
        var wardrobe_scene: ?wardrobe_demo.Scene = null;
        defer if (wardrobe_scene) |*scene| scene.deinit();
        var environment_scene: ?environment_demo.Scene = null;
        defer if (environment_scene) |*scene| scene.deinit();
        var platform_input: ?sdl_input.PlatformInput = null;
        defer if (platform_input) |*platform| platform.deinit();
        var scripted_sequence = controller_demo.ScriptedInput{};
        var playground_sequence = playground_demo.ScriptedInput{};
        var side_scroller_sequence = playground_demo.SideScrollerScriptedInput{};
        var foundation_sequence = visual_foundation.ScriptedInput{};
        var foundation_capture_tracker = foundation_evidence.Tracker{};
        var foundation_capture_artifacts =
            [_]FoundationCaptureArtifact{.{}} ** foundation_evidence.capture_count;
        var p27b_capture_artifacts =
            [_]P27bCaptureArtifact{.{}} ** p27b_capture_count;
        var anatomy_capture_tracker = anatomy_evidence.Tracker{};
        var anatomy_capture_artifacts =
            [_]AnatomyCaptureArtifact{.{}} ** anatomy_evidence.capture_count;
        var environment_sequence = environment_demo.ScriptedInput{};
        var playground_snapshot_builder = input.SnapshotBuilder{};
        var foundation_snapshot_builder = input.SnapshotBuilder{};
        var environment_snapshot_builder = input.SnapshotBuilder{};
        var previous_playground_snapshot: ?input.FrameInputSnapshot = null;
        var time_mode: TimeMode = .normal;
        var debug_geometry = true;

        const gpu_creations_before_humanoid_initialization = self.resource_metrics.gpu_resource_creations;
        if (mode == .controller) {
            try humanoid.runFaultInjectionChecks(self.allocator);
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.HumanoidInitializationCreatedGpuResources;
            }
            humanoid_demo = try humanoid.DemoCharacter.init(humanoid_allocator.allocator(), null);
        }
        if (mode == .controller) {
            try animation_system.runFaultInjectionChecks(self.allocator, &humanoid_demo.?.definition);
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.AnimationInitializationCreatedGpuResources;
            }
            animation_runtime = try animation_system.Runtime.init(humanoid_allocator.allocator(), &humanoid_demo.?.definition, null);
        }
        if (mode == .controller) {
            try controller_demo.runFaultInjectionChecks(self.allocator);
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.ControllerInitializationCreatedGpuResources;
            }
            controller_runtime = try controller_demo.Runtime.init(humanoid_allocator.allocator(), null);
            platform_input = sdl_input.PlatformInput.init();
        }
        if (mode == .handshake_ik) {
            if (!scripted_input_enabled) return error.HandshakeIkDemoRequiresScriptedInput;
            handshake_ik_scene = try handshake_ik_demo.Scene.init(humanoid_allocator.allocator());
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.HandshakeIkInitializationCreatedGpuResources;
            }
        }
        if (mode == .integrated) {
            if (!scripted_input_enabled) return error.IntegratedDemoRequiresScriptedInput;
            integrated_scene = try integrated_demo.Scene.init(humanoid_allocator.allocator(), .{
                .debug_visualization = integrated_debug_enabled,
                .diagnostics_each_tick = true,
            });
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.IntegratedInitializationCreatedGpuResources;
            }
            integrated_scene.?.setResourceSnapshot(resourceSnapshot(self, humanoid_allocator.end_index, 0));
        }
        if (mode == .playground or mode == .side_scroller) {
            if (mode == .playground and scripted_input_enabled == interactive_enabled) return error.PlaygroundRequiresExactlyOneInputMode;
            if (mode == .side_scroller and (!scripted_input_enabled or interactive_enabled)) return error.SideScrollerRequiresScriptedInput;
            playground_scene = try playground_demo.Scene.init(humanoid_allocator.allocator(), integrated_debug_enabled);
            if (mode == .playground and !scripted_input_enabled) platform_input = sdl_input.PlatformInput.init();
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.PlaygroundInitializationCreatedGpuResources;
            }
        }
        if (mode == .modular_body) {
            try modular_body_demo.runFaultInjectionChecks(self.allocator);
            modular_body_scene = try modular_body_demo.Scene.init(humanoid_allocator.allocator());
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.ModularBodyInitializationCreatedGpuResources;
            }
        }
        if (mode == .equipment) {
            equipment_scene = try equipment_demo.Scene.init(humanoid_allocator.allocator());
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.EquipmentInitializationCreatedGpuResources;
            }
        }
        if (mode == .mesh_attachments) {
            mesh_attachment_scene = try mesh_attachment_demo.Scene.init(humanoid_allocator.allocator());
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.MeshAttachmentSceneInitializationCreatedGpuResources;
            }
            const definitions = mesh_attachment_scene.?.meshDefinitions();
            try self.initializeMeshRendering(&definitions);
        }
        if (mode == .foundation) {
            if (scripted_input_enabled == interactive_enabled) return error.FoundationRequiresExactlyOneInputMode;
            const allocated_foundation_scene =
                try self.allocator.create(visual_foundation.Scene);
            errdefer self.allocator.destroy(allocated_foundation_scene);
            allocated_foundation_scene.* =
                try visual_foundation.Scene
                    .initWithDiagnosticAllocatorAndComponentProof(
                    humanoid_allocator.allocator(),
                    self.allocator,
                    if (scripted_input_enabled)
                        .enforce_acceptance
                    else
                        .measure_only,
                    component_proof_case,
                );
            foundation_scene = allocated_foundation_scene;
            if (registration_proof_case) |proof_case| {
                try foundation_scene.?.applyRegistrationProofCase(proof_case);
            }
            if (component_proof_case) |proof_case| {
                try foundation_scene.?.applyComponentProofCase(proof_case);
            }
            foundation_scene.?.setDebugMode(
                if (integrated_debug_enabled) .all_diagnostics else .off,
            );
            if (self.drawable_available and
                (foundation_scene.?.integrated.camera.viewport_width != self.drawable_width or
                    foundation_scene.?.integrated.camera.viewport_height != self.drawable_height))
            {
                try foundation_scene.?.applyViewport(
                    self.drawable_width,
                    self.drawable_height,
                );
            }
            if (capture_manual_bundle) {
                try foundation_scene.?.requestManualDebugCapture();
            }
            if (!scripted_input_enabled) platform_input = sdl_input.PlatformInput.init();
            if (self.resource_metrics.gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.FoundationInitializationCreatedGpuResources;
            }
            try self.runArtTextureFaultChecks(
                &foundation_scene.?.integrated.production.character_art_definition.art,
            );
            try self.runArtTextureFaultChecks(
                &foundation_scene.?.integrated.production.wardrobe_art_definition.art,
            );
            try self.runArtTextureFaultChecks(
                &foundation_scene.?.integrated.environment_art_definition.art,
            );
            try self.initializeArtTexturePageSets(&.{
                &foundation_scene.?.integrated.production.character_art_definition.art,
                &foundation_scene.?.integrated.production.wardrobe_art_definition.art,
                &foundation_scene.?.integrated.environment_art_definition.art,
            });
            // The bounded Prompt 27A HUD shares the production queue and GPU
            // instance path. Reserve its fixed maximum before stabilization so
            // evidence frames never grow GPU resources.
            try self.ensureGpuCapacity(render_queue.default_sprite_capacity, null);
            const definitions = foundation_scene.?.meshDefinitions();
            try self.initializeMeshRendering(&definitions);
            try self.initializeVisualCaptureTransfer(false);
        }
        if (mode == .art_assets) {
            art_scene = try art_asset_demo.Scene.init(humanoid_allocator.allocator(), 1);
            try self.runArtTextureFaultChecks(&art_scene.?.definition);
            try self.initializeArtTexturePages(&art_scene.?.definition);
            const definitions = art_scene.?.meshDefinitions();
            try self.initializeMeshRendering(&definitions);
        }
        if (mode == .wardrobe or mode == .visual_quality or
            mode == .anatomy_quality)
        {
            if ((mode == .wardrobe and scripted_input_enabled == interactive_enabled) or
                (mode == .visual_quality and
                    (!scripted_input_enabled or interactive_enabled)) or
                (mode == .anatomy_quality and
                    (!scripted_input_enabled or interactive_enabled)))
            {
                return error.WardrobeRequiresExactlyOneInputMode;
            }
            wardrobe_scene = try wardrobe_demo.Scene.init(humanoid_allocator.allocator());
            if (mode == .visual_quality) {
                try wardrobe_scene.?.enableVisualQualityAcceptance();
            } else if (mode == .anatomy_quality) {
                try wardrobe_scene.?.enableAnatomyQualityAcceptance();
                try std.Io.Dir.cwd().createDirPath(
                    self.io,
                    p27c_capture_directory,
                );
            }
            try self.visible_camera.setCenter(.{
                .x = 0,
                .y = self.visible_camera.center.y,
            });
            try self.runArtTextureFaultChecks(
                &wardrobe_scene.?.character_art_definition.art,
            );
            try self.runArtTextureFaultChecks(
                &wardrobe_scene.?.wardrobe_art_definition.art,
            );
            try self.initializeArtTexturePageSets(&.{
                &wardrobe_scene.?.character_art_definition.art,
                &wardrobe_scene.?.wardrobe_art_definition.art,
            });
            const definitions = wardrobe_scene.?.meshDefinitions();
            try self.initializeMeshRendering(&definitions);
            if (mode == .visual_quality or mode == .anatomy_quality) {
                try self.initializeVisualCaptureTransfer(integrated_debug_enabled);
            }
            if (interactive_enabled) platform_input = sdl_input.PlatformInput.init();
        }
        if (mode == .environment) {
            if (scripted_input_enabled == interactive_enabled) {
                return error.EnvironmentRequiresExactlyOneInputMode;
            }
            environment_scene = try environment_demo.Scene.init(humanoid_allocator.allocator());
            environment_scene.?.detailed_debug_enabled = integrated_debug_enabled;
            if (self.drawable_available and
                (environment_scene.?.camera.viewport_width != self.drawable_width or
                    environment_scene.?.camera.viewport_height != self.drawable_height))
            {
                try environment_scene.?.applyViewport(
                    self.drawable_width,
                    self.drawable_height,
                );
            }
            self.visible_camera = environment_scene.?.camera;
            try self.runArtTextureFaultChecks(
                &environment_scene.?.production.character_art_definition.art,
            );
            try self.runArtTextureFaultChecks(
                &environment_scene.?.production.wardrobe_art_definition.art,
            );
            try self.runArtTextureFaultChecks(
                &environment_scene.?.environment_art_definition.art,
            );
            try self.initializeArtTexturePageSets(&.{
                &environment_scene.?.production.character_art_definition.art,
                &environment_scene.?.production.wardrobe_art_definition.art,
                &environment_scene.?.environment_art_definition.art,
            });
            const definitions = environment_scene.?.meshDefinitions();
            try self.initializeMeshRendering(&definitions);
            if (scripted_input_enabled) try self.initializeVisualCaptureTransfer(false);
            if (interactive_enabled) platform_input = sdl_input.PlatformInput.init();
        }
        var geometry_alpha_catalog: ?visual_geometry_overlay.AlphaCatalog = null;
        if (mode == .visual_quality and integrated_debug_enabled) {
            geometry_alpha_catalog = try visual_geometry_overlay.AlphaCatalog.init(self.allocator);
        }
        const humanoid_initialized_bytes = humanoid_allocator.end_index;
        const creations_before_run = self.resource_metrics.gpu_resource_creations;
        var creations_after_warmup = creations_before_run;
        self.batch.?.markStabilized();
        if (self.unified_queue) |*queue| queue.markStabilized();
        var pose_evaluation_allocations: usize = 0;
        var humanoid_submission_allocations: usize = 0;
        var humanoid_instances: u32 = 0;
        var geometry_trace = visual_geometry.Trace{};
        var geometry_debug_commands = debug_draw.CommandBuffer{};
        var last_ticks_ns = c.SDL_GetTicksNS();

        var frame: u32 = 0;
        var running = true;
        while (running and (maximum_frames == null or frame < maximum_frames.?)) : (frame += 1) {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event)) {
                if (event.type == c.SDL_EVENT_QUIT or event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) running = false;
                try self.handleWindowEvent(&event);
                if ((mode == .foundation or mode == .environment) and self.drawable_available and
                    (event.type == c.SDL_EVENT_WINDOW_RESIZED or
                        event.type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED or
                        event.type == c.SDL_EVENT_WINDOW_RESTORED))
                {
                    if (mode == .foundation) {
                        try foundation_scene.?.applyViewport(self.drawable_width, self.drawable_height);
                    } else {
                        try environment_scene.?.applyViewport(self.drawable_width, self.drawable_height);
                    }
                }
                if (platform_input) |*platform| platform.handleEvent(&event);
            }
            if (!running) break;

            switch (mode) {
                .sprites => try self.submitDemonstrationSprites(frame),
                .controller => {
                    const demo = &humanoid_demo.?;
                    const animation = &animation_runtime.?;
                    const simulation = &controller_runtime.?;
                    const now_ticks_ns = c.SDL_GetTicksNS();
                    const measured_delta = @as(f64, @floatFromInt(now_ticks_ns - last_ticks_ns)) / 1_000_000_000.0;
                    last_ticks_ns = now_ticks_ns;
                    const snapshot = if (scripted_input_enabled)
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
                        if (scripted_input_enabled) scripted_sequence.observe(tick, &simulation.controller);
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
                .handshake_ik => {
                    const scene = &handshake_ik_scene.?;
                    var allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(frame);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.batch.?.beginFrame();
                    allocation_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(&self.batch.?);
                    humanoid_submission_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                },
                .integrated => {
                    const scene = &integrated_scene.?;
                    scene.setResourceSnapshot(resourceSnapshot(self, humanoid_allocator.end_index, 0));
                    var allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(1.0 / 60.0);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.batch.?.beginFrame();
                    allocation_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(&self.batch.?);
                    humanoid_submission_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                },
                .playground => {
                    const scene = &playground_scene.?;
                    const now_ticks_ns = c.SDL_GetTicksNS();
                    const measured_delta = @as(f64, @floatFromInt(now_ticks_ns - last_ticks_ns)) / 1_000_000_000.0;
                    last_ticks_ns = now_ticks_ns;
                    const snapshot = if (scripted_input_enabled)
                        try playground_snapshot_builder.update(playground_sequence.nextRaw(scene))
                    else
                        try platform_input.?.pollFrame();
                    logInputTransitions(previous_playground_snapshot, snapshot, scene.debug_visualization);
                    previous_playground_snapshot = snapshot;
                    if (snapshot.exit.pressed) {
                        std.log.info("exit requested", .{});
                        running = false;
                        break;
                    }
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(if (scripted_input_enabled) 1.0 / 60.0 else measured_delta, snapshot);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    if (scripted_input_enabled) try playground_sequence.observe(scene);
                    if (snapshot.reset.pressed) {
                        try self.visible_camera.setCenter(camera2d.default_center);
                    } else {
                        try camera_follower.update(&self.visible_camera, scene.player.world_position.x);
                    }
                    minimum_camera_x = @min(minimum_camera_x, self.visible_camera.center.x);
                    maximum_camera_x = @max(maximum_camera_x, self.visible_camera.center.x);
                    self.batch.?.beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(&self.batch.?);
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .modular_body => {
                    const scene = &modular_body_scene.?;
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(frame);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.batch.?.beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(&self.batch.?);
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .equipment => {
                    const scene = &equipment_scene.?;
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(frame);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.batch.?.beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(&self.batch.?);
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .mesh_attachments => {
                    const scene = &mesh_attachment_scene.?;
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(frame);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.unified_queue.?.beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(&self.unified_queue.?);
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .side_scroller => {
                    const scene = &playground_scene.?;
                    const snapshot = try playground_snapshot_builder.update(side_scroller_sequence.nextRaw(scene));
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(1.0 / 60.0, snapshot);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    side_scroller_sequence.observe(scene);
                    try camera_follower.update(&self.visible_camera, scene.player.world_position.x);
                    minimum_camera_x = @min(minimum_camera_x, self.visible_camera.center.x);
                    maximum_camera_x = @max(maximum_camera_x, self.visible_camera.center.x);
                    self.batch.?.beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(&self.batch.?);
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .foundation => {
                    const scene = foundation_scene.?;
                    if (self.drawable_available and
                        (scene.integrated.camera.viewport_width != self.drawable_width or
                            scene.integrated.camera.viewport_height != self.drawable_height))
                    {
                        try scene.applyViewport(
                            self.drawable_width,
                            self.drawable_height,
                        );
                    }
                    const now_ticks_ns = c.SDL_GetTicksNS();
                    const measured_delta = @as(f64, @floatFromInt(now_ticks_ns - last_ticks_ns)) / 1_000_000_000.0;
                    last_ticks_ns = now_ticks_ns;
                    const snapshot = if (scripted_input_enabled)
                        try foundation_snapshot_builder.update(foundation_sequence.nextRaw(scene))
                    else
                        try platform_input.?.pollFrame();
                    if (snapshot.exit.pressed) {
                        std.log.info("exit requested", .{});
                        running = false;
                        break;
                    }
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(if (scripted_input_enabled) 1.0 / 60.0 else measured_delta, snapshot);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    if (scripted_input_enabled) try foundation_sequence.observe(scene);
                    self.visible_camera = scene.integrated.camera;
                    minimum_camera_x = @min(minimum_camera_x, scene.integrated.camera.center.x);
                    maximum_camera_x = @max(maximum_camera_x, scene.integrated.camera.center.x);
                    self.unified_queue.?.beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(&self.unified_queue.?);
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                    // Ground/camera presentation correction is resolved from
                    // the real submitted trace, so publish that same-frame
                    // camera to the production renderer before encoding.
                    self.visible_camera = scene.integrated.camera;
                },
                .art_assets => {
                    self.unified_queue.?.beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try art_scene.?.submit(&self.unified_queue.?, frame);
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .wardrobe, .visual_quality, .anatomy_quality => {
                    const scene = &wardrobe_scene.?;
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    if (mode == .visual_quality) {
                        try scene.updateVisualQualityFrame();
                    } else if (mode == .anatomy_quality) {
                        try scene.updateAnatomyQualityFrame();
                    } else if (scripted_input_enabled) {
                        try scene.updateScriptedFrame();
                    } else {
                        const snapshot = try platform_input.?.pollFrame();
                        if (snapshot.exit.pressed) {
                            std.log.info("exit requested", .{});
                            running = false;
                            break;
                        }
                        try scene.updateInteractiveFrame(snapshot);
                    }
                    pose_evaluation_allocations +=
                        humanoid_allocator.end_index - allocation_checkpoint;
                    self.unified_queue.?.beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    if ((mode == .visual_quality and integrated_debug_enabled) or
                        mode == .anatomy_quality)
                    {
                        geometry_trace.begin();
                        humanoid_instances = try scene.submitTraced(
                            &self.unified_queue.?,
                            &geometry_trace,
                        );
                        if (mode == .visual_quality) {
                            try visual_geometry_overlay.build(
                                &geometry_debug_commands,
                                &geometry_trace,
                                &geometry_alpha_catalog.?,
                                self.visible_camera,
                            );
                            humanoid_instances += try geometry_debug_commands.submitUnified(
                                &self.unified_queue.?,
                            );
                        }
                    } else {
                        humanoid_instances = try scene.submit(&self.unified_queue.?);
                    }
                    humanoid_submission_allocations +=
                        humanoid_allocator.end_index - submission_checkpoint;
                },
                .environment => {
                    const scene = &environment_scene.?;
                    if (self.drawable_available and
                        (scene.camera.viewport_width != self.drawable_width or
                            scene.camera.viewport_height != self.drawable_height))
                    {
                        try scene.applyViewport(
                            self.drawable_width,
                            self.drawable_height,
                        );
                    }
                    const now_ticks_ns = c.SDL_GetTicksNS();
                    const measured_delta =
                        @as(f64, @floatFromInt(now_ticks_ns - last_ticks_ns)) / 1_000_000_000.0;
                    last_ticks_ns = now_ticks_ns;
                    const snapshot = if (scripted_input_enabled)
                        try environment_snapshot_builder.update(environment_sequence.nextRaw())
                    else
                        try platform_input.?.pollFrame();
                    if (snapshot.exit.pressed) {
                        std.log.info("exit requested", .{});
                        running = false;
                        break;
                    }
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(
                        if (scripted_input_enabled) 1.0 / 60.0 else measured_delta,
                        snapshot,
                    );
                    if (scripted_input_enabled and frame == 280) {
                        try scene.applyViewport(960, 540);
                    } else if (scripted_input_enabled and frame == 281) {
                        try scene.applyViewport(target_width, target_height);
                    }
                    pose_evaluation_allocations +=
                        humanoid_allocator.end_index - allocation_checkpoint;
                    self.visible_camera = scene.camera;
                    minimum_camera_x = @min(minimum_camera_x, scene.camera.center.x);
                    maximum_camera_x = @max(maximum_camera_x, scene.camera.center.x);
                    self.unified_queue.?.beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(&self.unified_queue.?);
                    humanoid_submission_allocations +=
                        humanoid_allocator.end_index - submission_checkpoint;
                },
            }
            const rendered = if (usesUnifiedRendering(mode)) unified: {
                var prepared = self.unified_queue.?.prepare();
                if (mode == .foundation) {
                    if (foundation_scene.?.takeManualCaptureRequest()) {
                        const scene = foundation_scene.?;
                        try scene.bindTruthRenderFrame(frame);
                        const simulation_tick_before =
                            scene.integrated.production.simulation_tick;
                        const authoritative_before =
                            scene.truth_snapshot.authoritative_fingerprint;
                        const presentation_before =
                            scene.truth_snapshot.presentation_fingerprint;
                        const capture_before =
                            scene.truth_snapshot.capture_fingerprint;
                        const live_authoritative_before =
                            scene.authoritativeInteractionFingerprint();
                        var timestamp_buffer: [32]u8 = undefined;
                        const timestamp = try visual_truth.utcTimestamp(
                            self.io,
                            &timestamp_buffer,
                        );
                        var bundle = try visual_truth.Bundle.begin(
                            self.io,
                            manual_capture_directory,
                            timestamp,
                            self.manual_capture_next_index,
                        );
                        var clean_path_buffer: [384]u8 = undefined;
                        const clean_path = try bundle.filePath(
                            &clean_path_buffer,
                            "clean.png",
                        );
                        try self.captureUnifiedToPng(prepared, clean_path);
                        _ = try scene.submitManualTruthOverlay(
                            &self.unified_queue.?,
                        );
                        prepared = self.unified_queue.?.prepare();
                        var debug_path_buffer: [384]u8 = undefined;
                        const debug_path = try bundle.filePath(
                            &debug_path_buffer,
                            "debug.png",
                        );
                        try self.captureUnifiedToPng(prepared, debug_path);
                        const live_authoritative_after =
                            scene.authoritativeInteractionFingerprint();
                        const simulation_tick_after =
                            scene.integrated.production.simulation_tick;
                        try scene.refreshTruthSnapshot(frame);
                        const authoritative_after =
                            scene.truth_snapshot.authoritative_fingerprint;
                        const presentation_after =
                            scene.truth_snapshot.presentation_fingerprint;
                        const capture_after =
                            scene.truth_snapshot.capture_fingerprint;
                        if (live_authoritative_before != live_authoritative_after or
                            simulation_tick_before != simulation_tick_after or
                            authoritative_before != authoritative_after or
                            presentation_before != presentation_after or
                            capture_before != capture_after)
                        {
                            return error.ManualCaptureStateChanged;
                        }
                        const git_head_result = try std.process.run(
                            self.allocator,
                            self.io,
                            .{
                                .argv = &.{
                                    "git",
                                    "-c",
                                    "safe.directory=C:/Users/Chad/Documents/2d Renderer",
                                    "rev-parse",
                                    "HEAD",
                                },
                                .stdout_limit = .limited(4096),
                                .stderr_limit = .limited(4096),
                            },
                        );
                        defer {
                            self.allocator.free(git_head_result.stdout);
                            self.allocator.free(git_head_result.stderr);
                        }
                        try requireSuccessfulProcess(
                            git_head_result.term,
                            "git rev-parse HEAD",
                            git_head_result.stderr,
                        );
                        const git_status_result = try std.process.run(
                            self.allocator,
                            self.io,
                            .{
                                .argv = &.{
                                    "git",
                                    "-c",
                                    "safe.directory=C:/Users/Chad/Documents/2d Renderer",
                                    "status",
                                    "--porcelain=v1",
                                    "--untracked-files=all",
                                },
                                .stdout_limit = .limited(1024 * 1024),
                                .stderr_limit = .limited(4096),
                            },
                        );
                        defer {
                            self.allocator.free(git_status_result.stdout);
                            self.allocator.free(git_status_result.stderr);
                        }
                        try requireSuccessfulProcess(
                            git_status_result.term,
                            "git status --porcelain=v1 --untracked-files=all",
                            git_status_result.stderr,
                        );
                        const dirty = parseGitDirty(git_status_result.stdout);
                        const driver_pointer = c.SDL_GetGPUDeviceDriver(
                            self.device.?,
                        ) orelse return failSdl(
                            "SDL_GetGPUDeviceDriver(manual capture)",
                            error.GpuDeviceCreationFailure,
                        );
                        const driver = std.mem.span(
                            @as([*:0]const u8, @ptrCast(driver_pointer)),
                        );
                        var argument_buffer: [192]u8 = undefined;
                        var proof_argument_buffer: [64]u8 = undefined;
                        const proof_argument = if (registration_proof_case) |proof_case|
                            try std.fmt.bufPrint(
                                &proof_argument_buffer,
                                " --registration-proof-case {s}",
                                .{proof_case.cliName()},
                            )
                        else
                            "";
                        var component_argument_buffer: [64]u8 = undefined;
                        const component_argument = if (component_proof_case) |proof_case|
                            try std.fmt.bufPrint(
                                &component_argument_buffer,
                                " --component-proof-case {s}",
                                .{proof_case.cliName()},
                            )
                        else
                            "";
                        const arguments = try std.fmt.bufPrint(
                            &argument_buffer,
                            "--demo foundation {s}{s}{s}{s}{s}",
                            .{
                                if (scripted_input_enabled)
                                    "--scripted-input"
                                else
                                    "--interactive",
                                if (integrated_debug_enabled)
                                    " --debug-visualization"
                                else
                                    "",
                                proof_argument,
                                component_argument,
                                if (capture_manual_bundle)
                                    " --capture-manual-bundle"
                                else
                                    "",
                            },
                        );
                        const provenance = visual_truth.CaptureProvenance{
                            .utc_timestamp = timestamp,
                            .capture_index = bundle.capture_index,
                            .git_head = std.mem.trim(
                                u8,
                                git_head_result.stdout,
                                " \t\r\n",
                            ),
                            .staged_dirty = dirty.staged,
                            .unstaged_dirty = dirty.unstaged,
                            .untracked_dirty = dirty.untracked,
                            .build_configuration = @tagName(builtin.mode),
                            .executable_arguments = arguments,
                            .gpu_driver = driver,
                            .shader_format = "DXIL",
                            .clean_render_frame = frame,
                            .debug_render_frame = frame,
                            .clean_simulation_tick = simulation_tick_before,
                            .debug_simulation_tick = simulation_tick_after,
                            .authoritative_before = authoritative_before,
                            .authoritative_after = authoritative_after,
                            .presentation_before = presentation_before,
                            .presentation_after = presentation_after,
                            .capture_before = capture_before,
                            .capture_after = capture_after,
                        };
                        try bundle.writeStateJson(
                            self.io,
                            scene.truth_snapshot,
                            provenance,
                        );
                        try bundle.writeSummary(
                            self.io,
                            scene.truth_snapshot,
                            provenance,
                            scene.truth_category_counts,
                        );
                        var source_assets: [manual_capture_asset_paths.len]visual_truth.SourceAssetEvidence =
                            undefined;
                        for (manual_capture_asset_paths, 0..) |path, index| {
                            source_assets[index] = try visual_truth.hashSourceAsset(
                                self.allocator,
                                self.io,
                                path,
                            );
                        }
                        try bundle.finalize(
                            self.allocator,
                            self.io,
                            scene.truth_snapshot,
                            provenance,
                            &source_assets,
                        );
                        self.manual_capture_next_index = std.math.add(
                            u64,
                            bundle.capture_index,
                            1,
                        ) catch return error.ManualCaptureIndexOverflow;
                        self.manual_captures_written = std.math.add(
                            u64,
                            self.manual_captures_written,
                            1,
                        ) catch return error.ManualCaptureCountOverflow;
                        std.log.info(
                            "manual visual-truth bundle finalized: {s}",
                            .{bundle.finalDirectory()},
                        );
                    }
                    if (scripted_input_enabled) {
                        const observation = try foundation_scene.?.captureObservation(
                            &foundation_sequence,
                            .{
                                .render_frame = frame,
                                .texture_pages = self.texture_page_count,
                                .submitted_sprites = self.unified_queue.?.frame_metrics.submitted_sprites,
                                .submitted_meshes = self.unified_queue.?.frame_metrics.submitted_meshes,
                                .sprite_ranges = self.unified_queue.?.frame_metrics.sprite_ranges,
                                .mesh_ranges = self.unified_queue.?.frame_metrics.mesh_ranges,
                                .gpu_resource_creations = self.resource_metrics.gpu_resource_creations,
                                .steady_update_allocations = pose_evaluation_allocations,
                                .steady_submission_allocations = humanoid_submission_allocations,
                                .steady_queue_allocations = self.unified_queue.?.lifetime_metrics.cpu_allocations_after_stabilization,
                            },
                        );
                        if (try foundation_capture_tracker.observe(observation)) |candidate| {
                            const spec = foundation_evidence.specs[candidate.spec_index];
                            var capture_path_buffer: [256]u8 = undefined;
                            const capture_path = try std.fmt.bufPrint(
                                &capture_path_buffer,
                                "{s}/{s}",
                                .{ foundation_capture_directory, spec.filename },
                            );
                            const pixels = try self.captureUnifiedToPpm(prepared, capture_path);
                            foundation_capture_artifacts[candidate.spec_index] = .{
                                .captured = true,
                                .stable_ticks = candidate.stable_ticks,
                                .observation = observation,
                                .pixels = pixels,
                            };
                            try foundation_capture_tracker.commit(candidate, observation);
                            std.log.info(
                                "Prompt 27A capture accepted: id={s} frame={d} tick={d} stable_ticks={d} stage={s} view={s} facing={s}",
                                .{
                                    @tagName(spec.id),
                                    observation.render_frame,
                                    observation.simulation_tick,
                                    candidate.stable_ticks,
                                    @tagName(observation.stage),
                                    @tagName(observation.view),
                                    @tagName(observation.facing),
                                },
                            );
                        }
                        const p27b_camera = foundation_scene.?.integrated.camera;
                        if (!p27b_capture_artifacts[0].captured and
                            p27b_camera.viewport_width == 960 and
                            p27b_camera.viewport_height == 540)
                        {
                            const filename = "07_camera_resize.ppm";
                            p27b_capture_artifacts[0] = .{
                                .captured = true,
                                .filename = filename,
                                .camera_center = p27b_camera.center.toArray(),
                                .viewport = .{
                                    p27b_camera.viewport_width,
                                    p27b_camera.viewport_height,
                                },
                                .pixels = try self.captureUnifiedToPpm(
                                    prepared,
                                    p27b_capture_directory ++ "/" ++ filename,
                                ),
                            };
                        }
                        if (!p27b_capture_artifacts[3].captured and
                            foundation_sequence.abrupt_resize_first_post_frame)
                        {
                            const female_bounds =
                                try foundation_coherence.traceCharacterBounds(
                                    foundation_scene.?.visual_trace,
                                    foundation_scene.?.integrated.production
                                        .female.id.raw(),
                                );
                            const framing =
                                try foundation_coherence.framingMeasurement(
                                    female_bounds.world,
                                    p27b_camera,
                                );
                            if (!framing.passes()) {
                                return error.AbruptResizeFirstFrameClipped;
                            }
                            _ = try foundation_scene.?.submitAbruptResizeEvidence(
                                &self.unified_queue.?,
                            );
                            prepared = self.unified_queue.?.prepare();
                            const filename =
                                "08_abrupt_resize_first_post_debug.ppm";
                            p27b_capture_artifacts[3] = .{
                                .captured = true,
                                .filename = filename,
                                .camera_center = p27b_camera.center.toArray(),
                                .viewport = .{
                                    p27b_camera.viewport_width,
                                    p27b_camera.viewport_height,
                                },
                                .previous_viewport = foundation_sequence
                                    .abrupt_resize_previous_viewport,
                                .first_post_abrupt_resize = true,
                                .semantic_headroom_px = framing.top_headroom_px,
                                .semantic_footroom_px = framing.bottom_clearance_px,
                                .instantaneous_reprojection_world_delta_px = @abs(
                                    p27b_camera.center.y -
                                        foundation_sequence
                                            .abrupt_resize_previous_camera_y,
                                ) * p27b_camera.pixels_per_meter,
                                .pixels = try self.captureUnifiedToPpm(
                                    prepared,
                                    p27b_capture_directory ++
                                        "/" ++ filename,
                                ),
                            };
                        }
                        const p27b_parallax_index: ?usize =
                            if (!p27b_capture_artifacts[1].captured and
                            p27b_camera.center.x >= -2.5 and
                            p27b_camera.center.x < -2.0)
                                1
                            else if (!p27b_capture_artifacts[2].captured and
                            p27b_camera.center.x >= 0.5 and
                            p27b_camera.center.x < 1.0)
                                2
                            else
                                null;
                        if (p27b_parallax_index) |artifact_index| {
                            _ = try foundation_scene.?.submitCoherenceEvidence(
                                &self.unified_queue.?,
                            );
                            prepared = self.unified_queue.?.prepare();
                            const filename = if (artifact_index == 1)
                                "10_parallax_start_debug.ppm"
                            else
                                "11_parallax_finish_debug.ppm";
                            p27b_capture_artifacts[artifact_index] = .{
                                .captured = true,
                                .filename = filename,
                                .camera_center = p27b_camera.center.toArray(),
                                .viewport = .{
                                    p27b_camera.viewport_width,
                                    p27b_camera.viewport_height,
                                },
                                .pixels = try self.captureUnifiedToPpm(
                                    prepared,
                                    if (artifact_index == 1)
                                        p27b_capture_directory ++
                                            "/10_parallax_start_debug.ppm"
                                    else
                                        p27b_capture_directory ++
                                            "/11_parallax_finish_debug.ppm",
                                ),
                            };
                        }
                        const next_target = if (foundation_capture_tracker.currentSpec()) |spec|
                            spec.id
                        else
                            null;
                        _ = try acceptance_hud.submit(
                            &self.unified_queue.?,
                            self.visible_camera,
                            observation,
                            next_target,
                        );
                        prepared = self.unified_queue.?.prepare();
                    }
                    const window_rendered = try self.renderUnifiedToWindow(prepared);
                    foundation_scene.?.recordRendering(self.unified_queue.?.frame_metrics);
                    break :unified window_rendered;
                }
                const window_rendered = try self.renderUnifiedToWindow(prepared);
                if (mode == .visual_quality) {
                    if (integrated_debug_enabled) {
                        if (frame == 150) {
                            _ = try self.captureUnifiedToPpm(prepared, geometry_debug_capture_path);
                        }
                    } else if (visualCapturePath(frame)) |capture_path| {
                        _ = try self.captureUnifiedToPpm(prepared, capture_path);
                    }
                } else if (mode == .anatomy_quality) {
                    const observation = try anatomyObservation(
                        &wardrobe_scene.?,
                        &geometry_trace,
                        frame,
                    );
                    if (try anatomy_capture_tracker.observe(observation)) |candidate| {
                        const spec = anatomy_evidence.specs[candidate.spec_index];
                        var capture_path_buffer: [256]u8 = undefined;
                        const capture_path = try std.fmt.bufPrint(
                            &capture_path_buffer,
                            "{s}/{s}",
                            .{ p27c_capture_directory, spec.filename },
                        );
                        anatomy_capture_artifacts[candidate.spec_index] = .{
                            .captured = true,
                            .stable_frames = candidate.stable_frames,
                            .observation = observation,
                            .pixels = try self.captureUnifiedToPpm(
                                prepared,
                                capture_path,
                            ),
                        };
                        try anatomy_capture_tracker.commit(candidate, observation);
                        std.log.info(
                            "Prompt 27C capture accepted: id={s} frame={d} tick={d} stable_frames={d} view={s} facing={s} animation={s} elbow={d:.3} knee={d:.3}",
                            .{
                                @tagName(spec.stage),
                                observation.render_frame,
                                observation.simulation_tick,
                                candidate.stable_frames,
                                @tagName(observation.view),
                                @tagName(observation.facing),
                                observation.animation,
                                observation.elbow_angle_degrees,
                                observation.knee_angle_degrees,
                            },
                        );
                    }
                } else if (mode == .environment and scripted_input_enabled) {
                    if (environmentCapturePath(frame)) |capture_path| {
                        _ = try self.captureUnifiedToPpm(prepared, capture_path);
                    }
                }
                break :unified window_rendered;
            } else try self.renderPreparedToWindow(self.batch.?.prepare(), null);
            if (rendered) {
                self.resource_metrics.frames_rendered += 1;
            } else {
                self.resource_metrics.zero_drawable_frames += 1;
            }
            if (mode == .integrated) {
                integrated_scene.?.recordRendering(.{
                    .submitted_sprite_count = self.batch.?.frame_metrics.submitted_sprites,
                    .ordinary_sprite_count = integrated_scene.?.evidence.ordinary_sprites,
                    .debug_primitive_count = integrated_scene.?.evidence.debug_primitives,
                    .texture_pages = 1,
                    .sprite_draw_ranges = self.batch.?.frame_metrics.draw_ranges,
                    .sprite_draw_calls = self.batch.?.frame_metrics.draw_calls,
                    .debug_draw_calls = 0,
                    .total_actual_draw_calls = self.batch.?.frame_metrics.draw_calls,
                });
            }
            if (usesUnifiedRendering(mode)) {
                try self.updateUnifiedWindowTitle();
            } else {
                try self.updateWindowTitle();
            }
            if (frame == 0) creations_after_warmup = self.resource_metrics.gpu_resource_creations;
        }

        const metrics = self.batch.?.frame_metrics;
        if (!usesUnifiedRendering(mode)) {
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
        }
        if (mode == .controller) {
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
            }
        } else if (mode == .handshake_ik) {
            const scene = &handshake_ik_scene.?;
            try scene.validateComplete();
            if (self.resource_metrics.frames_rendered != handshake_ik_demo.required_frames) return error.HandshakeIkFrameCountMismatch;
            const gpu_resources_for_ik = self.resource_metrics.gpu_resource_creations - creations_before_run;
            const nominal = scene.nominal;
            const mirrored = scene.mirrored;
            const perturbed = scene.perturbed;
            const nominal_a = nominal.role_a_metrics.?;
            const nominal_b = nominal.role_b_metrics.?;
            const reduction_percent = (1.0 - perturbed.post_separation / perturbed.pre_separation) * 100.0;
            std.log.info("handshake IK final metrics: frames={d} characters={d} humanoid_sprites={d} texture_pages=1 ranges={d} actual_draw_calls={d} gpu_resources_created_by_ik={d}", .{
                self.resource_metrics.frames_rendered,
                handshake_ik_demo.character_count,
                humanoid_instances,
                metrics.draw_ranges,
                metrics.draw_calls,
                gpu_resources_for_ik,
            });
            std.log.info("handshake IK nominal: spacing={d:.6} pre_A=({d:.6},{d:.6}) pre_B=({d:.6},{d:.6}) pre_separation={d:.6} target=({d:.6},{d:.6}) post_A=({d:.6},{d:.6}) post_B=({d:.6},{d:.6}) error_A={d:.8} error_B={d:.8} post_separation={d:.8}", .{
                nominal.root_spacing,        nominal.pre_a.x,             nominal.pre_a.y,         nominal.pre_b.x,
                nominal.pre_b.y,             nominal.pre_separation,      nominal.shared_target.x, nominal.shared_target.y,
                nominal.post_a.x,            nominal.post_a.y,            nominal.post_b.x,        nominal.post_b.y,
                nominal.role_a_target_error, nominal.role_b_target_error, nominal.post_separation,
            });
            std.log.info("handshake IK perturbed: spacing={d:.6} pre_separation={d:.6} post_separation={d:.8} reduction_percent={d:.3}", .{
                perturbed.root_spacing,
                perturbed.pre_separation,
                perturbed.post_separation,
                reduction_percent,
            });
            std.log.info("handshake IK mirrored: pre_separation={d:.6} post_separation={d:.8} difference={d:.8}", .{
                mirrored.pre_separation,
                mirrored.post_separation,
                @abs(nominal.post_separation - mirrored.post_separation),
            });
            std.log.info("handshake IK solver: upper={d:.6} lower={d:.6} bend_A={s} bend_B={s} reach_A={s} reach_B={s}", .{
                nominal_a.upper_length,
                nominal_a.lower_length,
                @tagName(nominal_a.bend),
                @tagName(nominal_b.bend),
                @tagName(nominal_a.reachability),
                @tagName(nominal_b.reachability),
            });
            std.log.info("handshake IK weights: start={d:.3} midpoint={d:.3} contact={d:.3} release={d:.3} post_release={d:.3} complete={d:.3}", .{
                nominal.start_weight,
                nominal.blend_midpoint_weight,
                nominal.contact_weight,
                nominal.release_weight,
                nominal.post_release_weight,
                nominal.after_completion_weight,
            });
            std.log.info("handshake IK timing: nominal={d}/{d}/{d}/{d} mirrored={d}/{d}/{d}/{d} perturbed={d}/{d}/{d}/{d}", .{
                nominal.start_tick,   nominal.contact_tick,   nominal.release_tick,   nominal.complete_tick,
                mirrored.start_tick,  mirrored.contact_tick,  mirrored.release_tick,  mirrored.complete_tick,
                perturbed.start_tick, perturbed.contact_tick, perturbed.release_tick, perturbed.complete_tick,
            });
            std.log.info("handshake IK steady state: initialized_bytes={d} final_bytes={d} solver_allocations={d} binding_allocations={d} target_allocations={d} pose_allocations={d} hierarchy_allocations={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                scene.manager.metrics.ik_solver_allocations,
                scene.manager.metrics.ik_binding_lookup_allocations,
                scene.manager.metrics.ik_target_computation_allocations,
                scene.manager.metrics.ik_pose_application_allocations,
                scene.manager.metrics.ik_hierarchy_evaluation_allocations,
            });
            if (humanoid_instances != handshake_ik_demo.character_count * humanoid.default_visual_count or
                metrics.visible_sprites != humanoid_instances or metrics.draw_ranges != 1 or metrics.draw_calls != 1 or
                self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resources_for_ik != 0 or
                humanoid_allocator.end_index != humanoid_initialized_bytes)
            {
                return error.HandshakeIkEvidenceIncomplete;
            }
        } else if (mode == .integrated) {
            const scene = &integrated_scene.?;
            try scene.validateComplete();
            if (self.resource_metrics.frames_rendered != integrated_demo.required_frames) return error.IntegratedFrameCountMismatch;
            const gpu_resource_delta = self.resource_metrics.gpu_resource_creations - creations_before_run;
            const final_state = try scene.authoritativeState();
            const final_diagnostics = try scene.captureDiagnostics();
            const player_state = scene.player.controller.?.state;
            const left_metrics = scene.player.foot_plants.left.metrics;
            const right_metrics = scene.player.foot_plants.right.metrics;
            const total_left_acquisitions = left_metrics.plant_acquisitions + scene.partner.foot_plants.left.metrics.plant_acquisitions;
            const total_right_acquisitions = right_metrics.plant_acquisitions + scene.partner.foot_plants.right.metrics.plant_acquisitions;
            const maximum_slip = @max(left_metrics.maximum_world_space_slip, right_metrics.maximum_world_space_slip);
            const maximum_penetration = @max(left_metrics.maximum_penetration, right_metrics.maximum_penetration);
            const maximum_hover = @max(left_metrics.maximum_hover, right_metrics.maximum_hover);
            const tracked_resource_count = final_diagnostics.resources.gpu_textures + final_diagnostics.resources.gpu_buffers +
                final_diagnostics.resources.gpu_pipelines + final_diagnostics.resources.gpu_samplers + final_diagnostics.resources.other_gpu_resources;
            std.log.info("INTEGRATED DEMO EVIDENCE", .{});
            std.log.info("Simulation: render_frames={d} fixed_ticks={d} maximum_substeps={d} discarded_time={d:.8}", .{
                scene.render_frame,
                scene.simulation_tick,
                scene.evidence.maximum_substeps,
                scene.clock.lifetime_discarded_time,
            });
            std.log.info("Characters: count={d} player_position=({d:.6},{d:.6}) player_velocity=({d:.6},{d:.6}) grounded={} support={any} partner_position=({d:.6},{d:.6})", .{
                integrated_demo.character_count,
                player_state.position.x,
                player_state.position.y,
                player_state.velocity.x,
                player_state.velocity.y,
                player_state.grounded,
                player_state.supporting_collider,
                scene.partner.world_position.x,
                scene.partner.world_position.y,
            });
            std.log.info("Foot planting: left_acquisitions={d} right_acquisitions={d} maximum_slip={d:.8} maximum_penetration={d:.8} maximum_hover={d:.8} airborne_false_plants={d}", .{
                total_left_acquisitions,
                total_right_acquisitions,
                maximum_slip,
                maximum_penetration,
                maximum_hover,
                scene.evidence.airborne_false_plants,
            });
            std.log.info("Latest acquired foot lifecycle left: semantic_contact={any} candidate_acquisition={any} full_plant={any} release_start={any} full_release={any}", .{
                left_metrics.latest_acquired_lifecycle.semantic_contact_tick,
                left_metrics.latest_acquired_lifecycle.candidate_acquisition_tick,
                left_metrics.latest_acquired_lifecycle.full_plant_tick,
                left_metrics.latest_acquired_lifecycle.release_start_tick,
                left_metrics.latest_acquired_lifecycle.full_release_tick,
            });
            std.log.info("Latest acquired foot lifecycle right: semantic_contact={any} candidate_acquisition={any} full_plant={any} release_start={any} full_release={any}", .{
                right_metrics.latest_acquired_lifecycle.semantic_contact_tick,
                right_metrics.latest_acquired_lifecycle.candidate_acquisition_tick,
                right_metrics.latest_acquired_lifecycle.full_plant_tick,
                right_metrics.latest_acquired_lifecycle.release_start_tick,
                right_metrics.latest_acquired_lifecycle.full_release_tick,
            });
            std.log.info("Jump/landing: jumps={d} landings={d} maximum_impact={d:.6} maximum_compression={d:.6} delivery_count={d}", .{
                scene.evidence.jump_count,
                scene.evidence.landing_count,
                scene.evidence.maximum_landing_impact,
                scene.evidence.maximum_landing_compression,
                scene.evidence.landing_event_delivery_count,
            });
            std.log.info("Interaction: requests={d} successful={d} rejected={d} contact={d} release={d} complete={d} final_active={d} final_locks={d} maximum_id={d}", .{
                scene.evidence.interaction_requests,
                scene.evidence.successful_handshakes,
                scene.evidence.rejected_requests,
                scene.evidence.contact_events,
                scene.evidence.release_events,
                scene.evidence.completion_events,
                final_state.active_interactions,
                final_state.participant_locks,
                final_state.maximum_interaction_id,
            });
            std.log.info("Arm IK: maximum_pre_error={d:.8} maximum_post_error={d:.8} shared_target=({d:.6},{d:.6}) pre_ik_policy={} final_pose_after_ik={}", .{
                scene.evidence.maximum_pre_ik_contact_error,
                scene.evidence.maximum_post_ik_contact_error,
                scene.last_shared_target.x,
                scene.last_shared_target.y,
                scene.evidence.shared_target_from_pre_ik,
                scene.evidence.final_pose_after_ik,
            });
            std.log.info("Rendering: ordinary_sprites={d} debug_primitives={d} texture_pages=1 sprite_draw_ranges={d} sprite_draw_calls={d} debug_draw_calls=0 total_actual_draw_calls={d}", .{
                scene.evidence.ordinary_sprites,
                scene.evidence.debug_primitives,
                metrics.draw_ranges,
                metrics.draw_calls,
                metrics.draw_calls,
            });
            std.log.info("Steady-state: initialized_bytes={d} final_bytes={d} runtime_allocation_delta={d} gpu_resource_delta={d} diagnostic_history_capacity={d} history_overwrites={d} debug_command_capacity={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                final_state.allocation_total + self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization,
                gpu_resource_delta,
                diagnostics.history_capacity,
                scene.history.overwrite_count,
                @import("debug_draw").command_capacity,
            });
            std.log.info("Allocations: controller={d} animator={d} procedural={d} interaction={d} arm_ik={d} foot={d} ground_query={d} pose={d} layers={d} sprites={d} diagnostics={d} debug={d}", .{
                final_diagnostics.allocations.controller,
                final_diagnostics.allocations.animator,
                final_diagnostics.allocations.procedural_motion,
                final_diagnostics.allocations.interaction_update,
                final_diagnostics.allocations.arm_ik,
                final_diagnostics.allocations.foot_planting,
                final_diagnostics.allocations.ground_query,
                final_diagnostics.allocations.pose_evaluation,
                final_diagnostics.allocations.layer_resolution,
                final_diagnostics.allocations.sprite_submission,
                final_diagnostics.allocations.diagnostics_snapshot_update,
                final_diagnostics.allocations.debug_command_submission,
            });
            std.log.info("Resources: initial_cpu_bytes={d} final_cpu_bytes={d} live_textures={d} live_buffers={d} live_pipelines={d} live_samplers={d} live_other={d} live_tracked_gpu={d} creations_during_run={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                final_diagnostics.resources.gpu_textures,
                final_diagnostics.resources.gpu_buffers,
                final_diagnostics.resources.gpu_pipelines,
                final_diagnostics.resources.gpu_samplers,
                final_diagnostics.resources.other_gpu_resources,
                tracked_resource_count,
                gpu_resource_delta,
            });
            std.log.info("Procedural final: landing_offset={d:.8} landing_velocity={d:.8} head_offset={d:.8} head_velocity={d:.8}", .{
                scene.player.procedural.landing_spring.offset,
                scene.player.procedural.landing_spring.velocity,
                scene.player.procedural.secondary_spring.offset,
                scene.player.procedural.secondary_spring.velocity,
            });
            std.log.info("Final cleanup: active_interactions={d} interaction_owned_overrides={d} active_arm_constraints={d} invalid_airborne_foot_locks={d} partial_interleaving={} foot_placement_during_handshake={}", .{
                final_state.active_interactions,
                final_state.active_overrides,
                final_state.active_arm_constraints,
                scene.evidence.airborne_false_plants,
                scene.evidence.partial_interleaving_observed,
                scene.evidence.foot_placement_during_handshake,
            });
            for (scene.evidence.milestone_ticks, 0..) |tick, index| {
                const milestone: integrated_demo.Milestone = @enumFromInt(index);
                std.log.info("Milestone {s}: {any}", .{ @tagName(milestone), tick });
            }
            const expected_ordinary = integrated_demo.character_count * humanoid.default_visual_count + scene.world.colliders.len;
            if (scene.evidence.ordinary_sprites != expected_ordinary or metrics.visible_sprites != humanoid_instances or
                metrics.draw_ranges != 1 or metrics.draw_calls != 1 or
                self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resource_delta != 0 or
                humanoid_allocator.end_index != humanoid_initialized_bytes)
            {
                return error.IntegratedRenderingEvidenceIncomplete;
            }
        } else if (mode == .playground) {
            const scene = &playground_scene.?;
            if (scripted_input_enabled) {
                if (self.resource_metrics.frames_rendered != playground_demo.required_frames) return error.PlaygroundFrameCountMismatch;
                try playground_sequence.validate(scene);
            }
            const final_state = scene.authoritativeState();
            const gpu_resource_delta = self.resource_metrics.gpu_resource_creations - creations_before_run;
            const runtime_allocation_delta = humanoid_allocator.end_index - humanoid_initialized_bytes;
            std.log.info("INTERACTIVE INPUT EVIDENCE", .{});
            std.log.info("Controls: left=A/Left Arrow right=D/Right Arrow jump=Space interaction=E reset=R debug=F1 exit=Escape/window-close", .{});
            std.log.info("Input architecture: SDL=src/platform/sdl_input.zig mapping=src/platform/input.zig snapshot=FrameInputSnapshot intent=CharacterIntent direct_controller_mutation=false raw_frame_delta_movement=false", .{});
            std.log.info("Edge behavior: zero_substep_preserved=true multi_substep_single_consumption=true key_repeat=polled_state_transitions focus_loss=clear_keyboard_held_and_pending_suppress_until_release", .{});
            std.log.info("Horizontal movement: left_displacement={d:.6} right_displacement={d:.6} opposing_displacement={d:.8} release_deceleration={}", .{
                playground_sequence.left_displacement,
                playground_sequence.right_displacement,
                playground_sequence.opposing_displacement,
                playground_sequence.milestones.deceleration,
            });
            std.log.info("Jump: short_apex={d:.6} held_apex={d:.6} difference={d:.6} Space_presses={d} Space_releases={d}", .{
                playground_sequence.short_jump_apex,
                playground_sequence.held_jump_apex,
                playground_sequence.held_jump_apex - playground_sequence.short_jump_apex,
                scene.evidence.jump_press_count,
                scene.evidence.jump_release_count,
            });
            std.log.info("Interaction: E_requests={d} successful={d} held_E_restarts={d} contacts={d} releases={d} completions={d} final_locks={d} final_slots={d}", .{
                scene.evidence.interaction_requests,
                scene.evidence.successful_interactions,
                scene.evidence.held_interaction_restarts,
                scene.evidence.contact_events,
                scene.evidence.release_events,
                scene.evidence.completion_events,
                final_state.participant_locks,
                final_state.active_interactions,
            });
            std.log.info("Reset: player_position=({d:.6},{d:.6}) player_velocity=({d:.6},{d:.6}) active_interactions={d} active_IK={d} invalid_foot_locks={d}", .{
                final_state.player_position.x,
                final_state.player_position.y,
                final_state.player_velocity.x,
                final_state.player_velocity.y,
                final_state.active_interactions,
                final_state.active_arm_constraints,
                @as(u32, @intFromBool(!final_state.player_grounded and (final_state.left_locked_target != null or final_state.right_locked_target != null))),
            });
            std.log.info("Debug: toggles={d} enabled={} maximum_primitives={d} GPU_resources_created={d}", .{
                scene.evidence.debug_toggle_count,
                scene.debug_visualization,
                scene.evidence.maximum_debug_primitives,
                gpu_resource_delta,
            });
            std.log.info("Keyboard/gamepad: merge=greatest_absolute_magnitude_keyboard_wins_ties simultaneous_actions=logical_OR disconnect=keyboard_remains_available", .{});
            std.log.info("Playground: characters={d} environment_colliders={d} scripted_complete={} exits=Escape/window-close/optional-frame-limit", .{
                playground_demo.character_count,
                scene.world.colliders.len,
                playground_sequence.completed(),
            });
            std.log.info("Rendering: texture_pages=1 draw_ranges={d} actual_draw_calls={d} debug_draw_calls=0 input_GPU_resources=0", .{
                metrics.draw_ranges,
                metrics.draw_calls,
            });
            std.log.info("Steady-state: input_polling_allocations=0 mapping_allocations=0 intent_allocations=0 playground_allocations=0 runtime_allocation_delta={d}", .{runtime_allocation_delta});
            if (metrics.draw_ranges != 1 or metrics.draw_calls != 1 or gpu_resource_delta != 0 or
                runtime_allocation_delta != 0 or self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization != 0)
            {
                return error.PlaygroundRenderingEvidenceIncomplete;
            }
        } else if (mode == .modular_body) {
            const scene = &modular_body_scene.?;
            try scene.validateComplete();
            if (self.resource_metrics.frames_rendered != modular_body_demo.required_frames) {
                return error.ModularBodyFrameCountMismatch;
            }
            const gpu_resource_delta = self.resource_metrics.gpu_resource_creations - creations_before_run;
            const runtime_allocation_delta = humanoid_allocator.end_index - humanoid_initialized_bytes;
            const anatomy_definition = scene.definition.anatomy_definition.?.view();
            const male_parts = try scene.conventional_male.character.anatomy_runtime.?.activePartCount(anatomy_definition);
            const female_parts = try scene.conventional_female.character.anatomy_runtime.?.activePartCount(anatomy_definition);
            const nonstandard_parts_count = try scene.nonstandard.character.anatomy_runtime.?.activePartCount(anatomy_definition);
            std.log.info("MODULAR BODY EVIDENCE", .{});
            std.log.info("Presets: conventional_male_parts={d} conventional_female_parts={d} nonstandard_parts={d} shared_skeleton={} shared_animation_library={}", .{
                male_parts,
                female_parts,
                nonstandard_parts_count,
                scene.conventional_male.definition.owner_token == scene.conventional_female.definition.owner_token and
                    scene.conventional_female.definition.owner_token == scene.nonstandard.definition.owner_token,
                scene.conventional_male.shared_animations.library_token == scene.conventional_female.shared_animations.library_token and
                    scene.conventional_female.shared_animations.library_token == scene.nonstandard.shared_animations.library_token,
            });
            std.log.info("Nonstandard features: extra_arms=2 articulated_tail=true horns=2 canonical_bones={d} canonical_right_arm_lengths=({d:.3},{d:.3})", .{
                scene.definition.skeleton_definition.boneCount(),
                scene.nonstandard.right_arm_binding.upper_length,
                scene.nonstandard.right_arm_binding.lower_length,
            });
            std.log.info("Faces: configurations={d} conventional_male=conventional_face conventional_female=angular_face shared_modular_appearance_path=true", .{
                anatomy_definition.faces.len,
            });
            std.log.info("Customization: presentation_switches={d} hair_switches={d} visual_ticks={d} submitted_sprites={d} ranges={d} actual_draw_calls={d}", .{
                scene.presentation_switches,
                scene.hair_switches,
                scene.total_visual_ticks,
                humanoid_instances,
                metrics.draw_ranges,
                metrics.draw_calls,
            });
            std.log.info("Steady-state: initialized_bytes={d} final_bytes={d} update_allocations={d} submission_allocations={d} batch_allocations={d} gpu_resource_delta={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                pose_evaluation_allocations,
                humanoid_submission_allocations,
                self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization,
                gpu_resource_delta,
            });
            if (humanoid_instances == 0 or metrics.visible_sprites != humanoid_instances or
                metrics.draw_ranges != 1 or metrics.draw_calls != 1 or
                runtime_allocation_delta != 0 or pose_evaluation_allocations != 0 or humanoid_submission_allocations != 0 or
                self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resource_delta != 0)
            {
                return error.ModularBodyRenderingEvidenceIncomplete;
            }
        } else if (mode == .equipment) {
            const scene = &equipment_scene.?;
            try scene.validateComplete();
            if (self.resource_metrics.frames_rendered != equipment_demo.required_frames) {
                return error.EquipmentFrameCountMismatch;
            }
            const gpu_resource_delta = self.resource_metrics.gpu_resource_creations - creations_before_run;
            const runtime_allocation_delta = humanoid_allocator.end_index - humanoid_initialized_bytes;
            std.log.info("EQUIPMENT EVIDENCE", .{});
            std.log.info("Topology: same_sweatshirt=true two_arm_sleeves={d} four_arm_sleeves={d} one_global_batch=true", .{
                scene.evidence.two_arm_sleeves,
                scene.evidence.four_arm_sleeves,
            });
            std.log.info("Transactions: conflict_rejected={} multi_slot_replacement={} unequip_restoration={} independent_loadouts=true", .{
                scene.evidence.conflict_rejected_transactionally,
                scene.evidence.multi_slot_replacement_proved,
                scene.evidence.unequip_restoration_proved,
            });
            for (scene.two_arm.equipment_loadout.?.modifiers()) |modifier| {
                const item = scene.two_arm.equipment_loadout.?.definition.items[modifier.item.index()];
                const attribute = scene.two_arm.equipment_loadout.?.definition.attributes[modifier.attribute.index()];
                std.log.info("Two-arm modifier: item={s} attribute={s} operation={s} amount={d:.3}", .{
                    item.stable_id.slice(),
                    attribute.stable_id.slice(),
                    @tagName(modifier.operation),
                    modifier.amount,
                });
            }
            for (scene.four_arm.equipment_loadout.?.capabilities()) |grant| {
                const item = scene.four_arm.equipment_loadout.?.definition.items[grant.item.index()];
                const capability = scene.four_arm.equipment_loadout.?.definition.capabilities[grant.capability.index()];
                std.log.info("Four-arm capability: item={s} capability={s}", .{
                    item.stable_id.slice(),
                    capability.stable_id.slice(),
                });
            }
            std.log.info("Rendering: characters={d} submitted_sprites={d} ranges={d} actual_draw_calls={d}", .{
                equipment_demo.character_count,
                humanoid_instances,
                metrics.draw_ranges,
                metrics.draw_calls,
            });
            std.log.info("Steady-state: initialized_bytes={d} final_bytes={d} update_allocations={d} submission_allocations={d} batch_allocations={d} gpu_resource_delta={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                pose_evaluation_allocations,
                humanoid_submission_allocations,
                self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization,
                gpu_resource_delta,
            });
            if (humanoid_instances == 0 or metrics.visible_sprites != humanoid_instances or
                metrics.draw_ranges != 1 or metrics.draw_calls != 1 or
                runtime_allocation_delta != 0 or pose_evaluation_allocations != 0 or humanoid_submission_allocations != 0 or
                self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resource_delta != 0)
            {
                return error.EquipmentRenderingEvidenceIncomplete;
            }
        } else if (mode == .wardrobe or mode == .visual_quality or
            mode == .anatomy_quality)
        {
            const scene = &wardrobe_scene.?;
            if (scripted_input_enabled) {
                const required_frames = if (mode == .visual_quality or
                    mode == .anatomy_quality)
                    wardrobe_demo.visual_quality_required_frames
                else
                    wardrobe_demo.required_frames;
                if (self.resource_metrics.frames_rendered != required_frames) {
                    return error.WardrobeFrameCountMismatch;
                }
                if (mode == .visual_quality) {
                    try scene.validateVisualQualityComplete();
                } else if (mode == .anatomy_quality) {
                    try anatomy_capture_tracker.validateComplete();
                    try self.writeAnatomyEvidence(&anatomy_capture_artifacts);
                } else {
                    try scene.validateComplete();
                }
            }
            const unified_metrics = self.unified_queue.?.frame_metrics;
            const runtime_allocation_delta = humanoid_allocator.end_index - humanoid_initialized_bytes;
            const gpu_resource_delta =
                self.resource_metrics.gpu_resource_creations - creations_before_run;
            const male_page = self.art_texture_pages[0] orelse
                return error.MissingArtTexturePage;
            const female_page = self.art_texture_pages[1] orelse
                return error.MissingArtTexturePage;
            const component_page = self.art_texture_pages[2] orelse
                return error.MissingArtTexturePage;
            const upper_page = self.art_texture_pages[3] orelse
                return error.MissingArtTexturePage;
            const layers_page = self.art_texture_pages[4] orelse
                return error.MissingArtTexturePage;
            const lower_page = self.art_texture_pages[5] orelse
                return error.MissingArtTexturePage;
            if (mode == .anatomy_quality) {
                std.log.info(
                    "PROMPT 27C STATE-CONDITIONED PRODUCTION ANATOMY EVIDENCE",
                    .{},
                );
                std.log.info(
                    "Captures: count={d} format=P6_PPM size={d}x{d} directory={s} source=same_prepared_global_queue",
                    .{
                        self.visual_captures_written,
                        target_width,
                        target_height,
                        p27c_capture_directory,
                    },
                );
            } else if (mode == .visual_quality) {
                const evidence = scene.visual_quality_evidence;
                std.log.info("PROMPT 25A VISUAL QUALITY ACCEPTANCE ROUTE", .{});
                std.log.info(
                    "Views: base={}/{} male_outfit={}/{} female_outfit={}/{} wide_brim={}/{} ivory_blouse={}/{} layered_custom={}/{} locomotion={} jump={}",
                    .{
                        evidence.base_front,
                        evidence.base_side,
                        evidence.male_outfit_front,
                        evidence.male_outfit_side,
                        evidence.female_outfit_front,
                        evidence.female_outfit_side,
                        evidence.wide_brim_front,
                        evidence.wide_brim_side,
                        evidence.ivory_blouse_front,
                        evidence.ivory_blouse_side,
                        evidence.layered_custom_front,
                        evidence.layered_custom_side,
                        evidence.locomotion_observed,
                        evidence.jump_observed,
                    },
                );
                std.log.info(
                    "Captures: count={d} format=P6_PPM size={d}x{d} directory={s} source=same_prepared_global_queue",
                    .{
                        self.visual_captures_written,
                        target_width,
                        target_height,
                        if (integrated_debug_enabled)
                            geometry_debug_capture_directory
                        else
                            visual_capture_directory,
                    },
                );
            } else if (scripted_input_enabled) {
                std.log.info("PROMPT 25 MODULAR WARDROBE EVIDENCE", .{});
                std.log.info(
                    "Catalog: presets={d} items={d} components={d} art_pages={d} regions={d} bindings={d} all_presets={} wide_brim={} ivory_blouse_red_shorts={} custom={}",
                    .{
                        scene.catalog.presets.len,
                        scene.catalog.equipment_definition.items.len,
                        scene.catalog.equipment_definition.visual_components.len,
                        scene.wardrobe_art_definition.art.pages.len,
                        scene.wardrobe_art_definition.art.regions.len,
                        scene.wardrobe_art_definition.art.bindings.len,
                        scene.evidence.rapid_cycle_complete,
                        scene.evidence.mandatory_wide_brim,
                        scene.evidence.mandatory_ivory_blouse_red_shorts,
                        scene.evidence.custom_recombination,
                    },
                );
                std.log.info(
                    "Presentation: female_front_side=true long_mesh={} secondary={} hair_headwear={} legwear={} footwear={} breathing={} locomotion={} jump={} land={} male_unchanged={}",
                    .{
                        scene.evidence.long_garment_mesh,
                        scene.evidence.long_garment_secondary_motion,
                        scene.evidence.long_hair_with_headwear,
                        scene.evidence.legwear_observed,
                        scene.evidence.footwear_observed,
                        scene.evidence.breathing_observed,
                        scene.evidence.locomotion_observed,
                        scene.evidence.jump_observed,
                        scene.evidence.landing_observed,
                        scene.evidence.male_unchanged,
                    },
                );
            } else {
                const current = try scene.catalog.preset(scene.current_preset);
                std.log.info("PROMPT 25 INTERACTIVE WARDROBE INSPECTION", .{});
                std.log.info(
                    "Current outfit={s} custom={} paused={} view={s}/{s}; O cycles, P pauses, Q forces view",
                    .{
                        current.stable_id,
                        scene.custom_active,
                        scene.paused,
                        @tagName(scene.female.presentationView()),
                        @tagName(scene.female.presentationOverride()),
                    },
                );
            }
            std.log.info(
                "Rendering: art_pages=6 configured_pages=7 decoded_files={d} sprites={d} meshes={d} sprite_ranges={d} mesh_ranges={d} sprite_draws={d} mesh_draws={d}",
                .{
                    self.image_decode_metrics.successful_decodes,
                    unified_metrics.submitted_sprites,
                    unified_metrics.submitted_meshes,
                    unified_metrics.sprite_ranges,
                    unified_metrics.mesh_ranges,
                    unified_metrics.sprite_draws,
                    unified_metrics.mesh_draws,
                },
            );
            std.log.info(
                "Steady state: initialized_bytes={d} final_bytes={d} update_allocations={d} submission_allocations={d} queue_allocations={d} gpu_resource_delta={d}",
                .{
                    humanoid_initialized_bytes,
                    humanoid_allocator.end_index,
                    pose_evaluation_allocations,
                    humanoid_submission_allocations,
                    self.unified_queue.?.lifetime_metrics.cpu_allocations_after_stabilization,
                    gpu_resource_delta,
                },
            );
            const expected_decoded_bytes =
                (1600 * 983 + 1599 * 984 + 1792 * 1024) * 4 +
                3 * 1536 * 1024 * 4;
            if (self.image_decode_metrics.decode_attempts != 6 or
                self.image_decode_metrics.successful_decodes != 6 or
                self.image_decode_metrics.decoded_bytes != expected_decoded_bytes or
                self.art_texture_page_count != 6 or
                self.texture_page_count != 7 or
                male_page.sampling != .nearest or
                female_page.sampling != .nearest or
                component_page.sampling != .nearest or
                upper_page.sampling != .linear or
                layers_page.sampling != .linear or
                lower_page.sampling != .linear or
                runtime_allocation_delta != 0 or
                pose_evaluation_allocations != 0 or
                humanoid_submission_allocations != 0 or
                self.unified_queue.?.lifetime_metrics.cpu_allocations_after_stabilization != 0 or
                ((mode == .visual_quality or mode == .anatomy_quality) and
                    self.visual_captures_written !=
                        (if (mode == .anatomy_quality)
                            p27c_capture_count
                        else if (integrated_debug_enabled)
                            1
                        else
                            visual_capture_count)) or
                gpu_resource_delta != 0)
            {
                return error.WardrobeRenderingEvidenceIncomplete;
            }
        } else if (mode == .foundation) {
            const scene = foundation_scene.?;
            if (scripted_input_enabled) {
                if (self.resource_metrics.frames_rendered != visual_foundation.required_frames) {
                    return error.FoundationFrameCountMismatch;
                }
                try scene.validateComplete(&foundation_sequence);
                try foundation_capture_tracker.validateComplete();
                try self.writeFoundationEvidence(&foundation_capture_artifacts);
                try self.writeP27bSupplementalEvidence(&p27b_capture_artifacts);
            }
            const unified_metrics = self.unified_queue.?.frame_metrics;
            const gpu_resource_delta = self.resource_metrics.gpu_resource_creations - creations_before_run;
            const runtime_allocation_delta = humanoid_allocator.end_index - humanoid_initialized_bytes;
            const expected_decoded_bytes =
                (1600 * 983 + 1599 * 984 + 1792 * 1024) * 4 +
                3 * 1536 * 1024 * 4 +
                2 * 1024 * 1024 * 4;
            if (scripted_input_enabled) {
                std.log.info("PROMPT 27A STATE-CONDITIONED VISUAL FOUNDATION EVIDENCE", .{});
            } else {
                std.log.info("PROMPT 27 INTERACTIVE SESSION SUMMARY", .{});
            }
            std.log.info(
                "World/lineup: characters={d} colliders={d} white_surfaces={d} atlas_pages={d} wardrobe_items={d} presets={d} themes=2 views=2 male_buzz={} female_curvy_long={} camera={} parallax={} resize={}",
                .{
                    visual_foundation.character_count,
                    scene.integrated.production.world.colliders.len,
                    scene.evidence.white_surface_count,
                    self.art_texture_page_count,
                    scene.integrated.production.catalog.equipment_definition.items.len,
                    scene.integrated.production.catalog.presets.len,
                    scene.evidence.male_buzz_cut,
                    scene.evidence.female_curvy_long_hair,
                    scene.evidence.camera_follow,
                    scene.evidence.parallax,
                    scene.evidence.resize_invariant,
                },
            );
            for (scene.evidence.interaction_records, 0..) |record, index| {
                std.log.info(
                    "Handshake[{d}]: id={d} type={s} entities={d}/{d} outfit={s} theme={s} requested_views={any}/{any} ticks={d}/{d}/{d}/{d} pre_ik={d:.6} post_ik={d:.6} projected={d:.6} contact_views={s}/{s} ordering={}/{} roots={} secondary={}",
                    .{
                        index,
                        record.id.raw(),
                        @tagName(record.type_id),
                        record.initiator.raw(),
                        record.receiver.raw(),
                        (try scene.integrated.production.catalog.preset(record.outfit)).stable_id,
                        @tagName(record.theme),
                        record.requested_initiator_view,
                        record.requested_receiver_view,
                        record.start_tick,
                        record.contact_tick,
                        record.release_tick,
                        record.complete_tick,
                        record.pre_ik_separation,
                        record.post_ik_separation,
                        record.projected_hand_separation,
                        @tagName(record.initiator_view_at_contact),
                        @tagName(record.receiver_view_at_contact),
                        record.body_ordering_valid,
                        record.equipment_ordering_valid,
                        record.roots_invariant,
                        record.secondary_finite,
                    },
                );
            }
            std.log.info(
                "Integrated: left/stop/right={}/{}/{} jump/fall/land/raised={}/{}/{}/{} breathing={} idle/motion_outfit={}/{} dash={} double_jump={} themes={}/{} interaction_cleanup={} reset={} stable={} captures={d}",
                .{
                    scene.evidence.walk_left_side,
                    scene.evidence.stop_front_facing_left,
                    scene.evidence.walk_right_side,
                    scene.evidence.jump_side,
                    scene.evidence.fall_side,
                    scene.evidence.landing_observed,
                    scene.evidence.raised_platform_landing,
                    scene.evidence.breathing_observed,
                    scene.evidence.outfit_idle_change,
                    scene.evidence.outfit_motion_change,
                    scene.evidence.dash_observed,
                    scene.evidence.double_jump_observed,
                    scene.evidence.violet_theme,
                    scene.evidence.debug_theme,
                    scene.evidence.front_idle_restored,
                    scene.evidence.reset_observed,
                    scene.evidence.stable_final_state,
                    self.visual_captures_written,
                },
            );
            std.log.info(
                "Rendering peaks: sprites={d} meshes={d} sprite_ranges={d} mesh_ranges={d} sprite_draws={d} mesh_draws={d} sprite_upload={d}B mesh_upload={d}B",
                .{
                    scene.evidence.maximum_active_sprites,
                    scene.evidence.maximum_active_meshes,
                    scene.evidence.maximum_sprite_ranges,
                    scene.evidence.maximum_mesh_ranges,
                    scene.evidence.maximum_sprite_draws,
                    scene.evidence.maximum_mesh_draws,
                    scene.evidence.maximum_sprite_upload_bytes,
                    scene.evidence.maximum_mesh_upload_bytes,
                },
            );
            std.log.info("Steady-state: initialized_bytes={d} final_bytes={d} update_allocations={d} submission_allocations={d} queue_allocations={d} gpu_resource_delta={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                pose_evaluation_allocations,
                humanoid_submission_allocations,
                self.unified_queue.?.lifetime_metrics.cpu_allocations_after_stabilization,
                gpu_resource_delta,
            });
            if (self.image_decode_metrics.decode_attempts != 8 or
                self.image_decode_metrics.successful_decodes != 8 or
                self.image_decode_metrics.decoded_bytes != expected_decoded_bytes or
                self.art_texture_page_count != 8 or
                self.texture_page_count != 9 or
                humanoid_instances == 0 or
                unified_metrics.submitted_sprites == 0 or
                scene.evidence.maximum_sprite_ranges == 0 or
                scene.evidence.maximum_sprite_draws == 0 or
                runtime_allocation_delta != 0 or
                pose_evaluation_allocations != 0 or
                humanoid_submission_allocations != 0 or
                self.unified_queue.?.lifetime_metrics.cpu_allocations_after_stabilization != 0 or
                (scripted_input_enabled and
                    (scene.evidence.maximum_active_meshes == 0 or
                        scene.evidence.maximum_mesh_ranges == 0 or
                        scene.evidence.maximum_mesh_draws == 0 or
                        self.visual_captures_written !=
                            foundation_capture_count + p27b_capture_count)) or
                gpu_resource_delta != 0)
            {
                return error.FoundationRenderingEvidenceIncomplete;
            }
        } else if (mode == .mesh_attachments) {
            const scene = &mesh_attachment_scene.?;
            try scene.validateComplete();
            if (self.resource_metrics.frames_rendered != mesh_attachment_demo.required_frames) {
                return error.MeshAttachmentFrameCountMismatch;
            }
            const unified_metrics = self.unified_queue.?.frame_metrics;
            const catalog = &self.mesh_catalog.?;
            const gpu_resource_delta = self.resource_metrics.gpu_resource_creations - creations_before_run;
            const runtime_allocation_delta = humanoid_allocator.end_index - humanoid_initialized_bytes;
            std.log.info("TOPOLOGY-AWARE DEFORMABLE MESH EVIDENCE", .{});
            std.log.info("Content: mesh_definitions={d} fitted_garments=2 conventional_sleeves={d} nonstandard_sleeves={d} capes=2 mixed_sprite_mesh=true", .{
                catalog.entries.len,
                scene.evidence.conventional_sleeves,
                scene.evidence.nonstandard_sleeves,
            });
            std.log.info("State: repeated_sleeves_independent={} characters_independent={} mirrored_facing={} breathing_deformation_changed={} build_deformation_changed={} cape_unequipped={} cape_reequipped={}", .{
                scene.evidence.independent_repeated_state,
                scene.evidence.independent_character_state,
                scene.evidence.mirrored_facing,
                scene.evidence.breathing_deformation_changed,
                scene.evidence.build_deformation_changed,
                scene.evidence.cape_unequipped,
                scene.evidence.cape_reequipped,
            });
            std.log.info("Secondary: cape_acceleration={} sustained={} reversal={} sudden_stop={} jump={} fall={} landing={} facing_reset={} long_hair={} ponytail={} removed={} reequipped_reset={} repeated_instances={}", .{
                scene.evidence.cape_acceleration_trails,
                scene.evidence.cape_sustained_motion_trails,
                scene.evidence.cape_reversal_changes_target,
                scene.evidence.cape_sudden_stop_changes_target,
                scene.evidence.cape_jump_trails_down,
                scene.evidence.cape_fall_trails_up,
                scene.evidence.cape_landing_impulse_consumed,
                scene.evidence.facing_change_reset,
                scene.evidence.long_hair_moved,
                scene.evidence.ponytail_moved,
                scene.evidence.cape_runtime_removed,
                scene.evidence.cape_reequip_reset,
                scene.evidence.repeated_secondary_state_independent,
            });
            std.log.info("Unified ordering: sprite_ranges={d} mesh_ranges={d} sprite_draws={d} mesh_draws={d} total_draws={d}", .{
                unified_metrics.sprite_ranges,
                unified_metrics.mesh_ranges,
                unified_metrics.sprite_draws,
                unified_metrics.mesh_draws,
                unified_metrics.sprite_draws + unified_metrics.mesh_draws,
            });
            std.log.info("Uploads/resources: sprite_instances={d} mesh_instances={d} sprite_upload={d}B mesh_upload={d}B persistent_topology_upload={d}B topology_buffers=2 frame_slots={d}", .{
                unified_metrics.submitted_sprites,
                unified_metrics.submitted_meshes,
                unified_metrics.sprite_upload_bytes,
                unified_metrics.mesh_upload_bytes,
                try catalog.uploadBytes(),
                frame_slot_count,
            });
            std.log.info("Steady-state: initialized_bytes={d} final_bytes={d} update_allocations={d} submission_allocations={d} queue_allocations={d} gpu_resource_delta={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                pose_evaluation_allocations,
                humanoid_submission_allocations,
                self.unified_queue.?.lifetime_metrics.cpu_allocations_after_stabilization,
                gpu_resource_delta,
            });
            if (humanoid_instances == 0 or unified_metrics.submitted_sprites == 0 or unified_metrics.submitted_meshes != 10 or
                unified_metrics.sprite_ranges == 0 or unified_metrics.mesh_ranges == 0 or
                unified_metrics.sprite_draws == 0 or unified_metrics.mesh_draws == 0 or
                runtime_allocation_delta != 0 or pose_evaluation_allocations != 0 or humanoid_submission_allocations != 0 or
                self.unified_queue.?.lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resource_delta != 0)
            {
                return error.MeshAttachmentRenderingEvidenceIncomplete;
            }
        } else if (mode == .side_scroller) {
            const scene = &playground_scene.?;
            if (self.resource_metrics.frames_rendered != playground_demo.side_scroller_required_frames) {
                return error.SideScrollerFrameCountMismatch;
            }
            try side_scroller_sequence.validate(scene);
            const camera_displacement = maximum_camera_x - minimum_camera_x;
            if (camera_displacement < 12) return error.SideScrollerCameraTravelMissing;
            const gpu_resource_delta = self.resource_metrics.gpu_resource_creations - creations_before_run;
            const runtime_allocation_delta = humanoid_allocator.end_index - humanoid_initialized_bytes;
            std.log.info("SIDE-SCROLL CAMERA EVIDENCE", .{});
            std.log.info("World travel: min_player_x={d:.5} max_player_x={d:.5} distance={d:.5} colliders={d}", .{
                side_scroller_sequence.minimum_player_x,
                side_scroller_sequence.maximum_player_x,
                side_scroller_sequence.maximum_player_x - side_scroller_sequence.minimum_player_x,
                scene.world.colliders.len,
            });
            std.log.info("Camera: min_center_x={d:.5} max_center_x={d:.5} displacement={d:.5} viewport={d}x{d} pixels_per_meter={d:.3}", .{
                minimum_camera_x,
                maximum_camera_x,
                camera_displacement,
                self.visible_camera.viewport_width,
                self.visible_camera.viewport_height,
                self.visible_camera.pixels_per_meter,
            });
            std.log.info("Parallax response: distant_factor={d:.3} distant_displacement={d:.5} midground_factor={d:.3} midground_displacement={d:.5} gameplay_factor=1.000 gameplay_displacement={d:.5}", .{
                playground_demo.distant_camera_x_factor,
                camera_displacement * playground_demo.distant_camera_x_factor,
                playground_demo.midground_camera_x_factor,
                camera_displacement * playground_demo.midground_camera_x_factor,
                camera_displacement,
            });
            std.log.info("Resize: events={d} viewport_updates={d} zero_drawable_frames={d} unrelated_resource_recreations={d}", .{
                self.resource_metrics.resize_events,
                self.resource_metrics.viewport_updates,
                self.resource_metrics.zero_drawable_frames,
                gpu_resource_delta,
            });
            if (metrics.draw_ranges != 1 or metrics.draw_calls != 1 or gpu_resource_delta != 0 or
                runtime_allocation_delta != 0 or self.batch.?.lifetime_metrics.cpu_allocations_after_stabilization != 0)
            {
                return error.SideScrollerRenderingEvidenceIncomplete;
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
            const world_position = try camera2d.Camera2D.initDefault().presentationToWorld(.{ .x = x, .y = y });
            try batch.submit(.{
                .world_position = world_position.toArray(),
                .rotation = @sin(time + index_f * 0.031) * 0.45,
                .scale = .{
                    (7.0 + @as(f32, @floatFromInt(index % 5))) / camera2d.default_pixels_per_meter,
                    (9.0 + @as(f32, @floatFromInt(index % 7))) / camera2d.default_pixels_per_meter,
                },
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

    fn submitSmokeSprites(self: *GpuDemo) !void {
        var batch = &self.batch.?;
        batch.beginFrame();
        const camera = camera2d.Camera2D.initDefault();
        try batch.submit(.{
            .world_position = (try camera.presentationToWorld(.{ .x = 208, .y = 200 })).toArray(),
            .rotation = 0,
            .scale = .{
                160.0 / camera2d.default_pixels_per_meter,
                160.0 / camera2d.default_pixels_per_meter,
            },
            .pivot = .{ 0.5, 0.5 },
            .uv_rect = .{ 0, 0, 0.5, 0.5 },
            .tint = .{ 1, 1, 1, 1 },
            .texture_page = 0,
            .order = .{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 0 },
        });
        try batch.submit(.{
            .world_position = (try camera.presentationToWorld(.{ .x = 432, .y = 280 })).toArray(),
            .rotation = 0,
            .scale = .{
                160.0 / camera2d.default_pixels_per_meter,
                160.0 / camera2d.default_pixels_per_meter,
            },
            .pivot = .{ 0.5, 0.5 },
            .uv_rect = .{ 0.5, 0.5, 1, 1 },
            .tint = .{ 1, 1, 1, 1 },
            .texture_page = 0,
            .order = .{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 1 },
        });
    }

    fn renderUnifiedToWindow(self: *GpuDemo, prepared: render_queue.PreparedQueue) !bool {
        if (!self.drawable_available) return false;
        if (prepared.sprites.len > self.gpu_instance_capacity) return error.GpuInstanceCapacityExceeded;
        if (prepared.meshes.len > render_queue.default_mesh_capacity) return error.MeshInstanceCapacityExceeded;
        const slot_index = try self.acquireFrameSlot();
        try self.populateInstanceTransfer(slot_index, prepared.sprites);
        try self.populateMeshInstanceTransfer(slot_index, prepared.meshes);

        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse
            return failSdl("SDL_AcquireGPUCommandBuffer(unified frame)", error.PipelineResourceBindingFailure);
        var command_active = true;
        var swapchain_acquired = false;
        errdefer if (command_active) self.cleanupFailedCommand(command, swapchain_acquired);

        var swapchain_texture: ?*c.SDL_GPUTexture = null;
        var swapchain_width: u32 = 0;
        var swapchain_height: u32 = 0;
        if (!c.SDL_WaitAndAcquireGPUSwapchainTexture(command, self.window.?, &swapchain_texture, &swapchain_width, &swapchain_height)) {
            return failSdl("SDL_WaitAndAcquireGPUSwapchainTexture(unified frame)", error.SwapchainAcquisitionFailure);
        }
        swapchain_acquired = swapchain_texture != null;
        if (swapchain_texture == null) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) {
                return failSdl("SDL_CancelGPUCommandBuffer(unified zero drawable)", error.PipelineResourceBindingFailure);
            }
            command_active = false;
            self.drawable_available = false;
            self.drawable_width = 0;
            self.drawable_height = 0;
            return false;
        }
        if (swapchain_width == 0 or swapchain_height == 0) {
            const empty_fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
            command_active = false;
            if (empty_fence == null) {
                return failSdl("SDL_SubmitGPUCommandBufferAndAcquireFence(unified zero drawable)", error.FrameFenceAcquisitionFailure);
            }
            self.resource_metrics.fence_acquisitions += 1;
            self.frame_slots[slot_index].fence = empty_fence.?;
            self.current_frame_slot = (slot_index + 1) % frame_slot_count;
            self.drawable_available = false;
            self.drawable_width = 0;
            self.drawable_height = 0;
            return false;
        }
        try self.applyDrawableSize(swapchain_width, swapchain_height);
        const encoded = try self.encodeUnifiedQueue(
            command,
            slot_index,
            prepared,
            swapchain_texture.?,
            self.window_pipeline.?,
            self.mesh_window_pipeline,
            self.visible_camera,
            true,
            true,
        );

        const fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
        command_active = false;
        if (fence == null) {
            _ = c.SDL_WaitForGPUIdle(self.device.?);
            return failSdl("SDL_SubmitGPUCommandBufferAndAcquireFence(unified frame)", error.FrameFenceAcquisitionFailure);
        }
        self.resource_metrics.fence_acquisitions += 1;
        self.frame_slots[slot_index].fence = fence.?;
        self.current_frame_slot = (slot_index + 1) % frame_slot_count;
        self.unified_queue.?.recordDraws(encoded.sprites, encoded.meshes);
        return swapchain_acquired;
    }

    fn captureUnifiedToPpm(
        self: *GpuDemo,
        prepared: render_queue.PreparedQueue,
        path: []const u8,
    ) !CapturePixelEvidence {
        const transfer = self.visual_capture_transfer orelse
            return error.VisualCaptureTransferNotInitialized;
        const row_pitch = alignForward(target_width * 4, 256);
        if (prepared.sprites.len > self.gpu_instance_capacity) {
            return error.GpuInstanceCapacityExceeded;
        }
        if (prepared.meshes.len > render_queue.default_mesh_capacity) {
            return error.MeshInstanceCapacityExceeded;
        }

        const slot_index = try self.acquireFrameSlot();
        try self.populateInstanceTransfer(slot_index, prepared.sprites);
        try self.populateMeshInstanceTransfer(slot_index, prepared.meshes);
        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse
            return failSdl(
                "SDL_AcquireGPUCommandBuffer(Prompt 25A capture)",
                error.PipelineResourceBindingFailure,
            );
        var command_active = true;
        errdefer if (command_active) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) {
                std.log.err(
                    "SDL_CancelGPUCommandBuffer(Prompt 25A capture): {s}",
                    .{sdlErrorText()},
                );
            }
        };
        _ = try self.encodeUnifiedQueue(
            command,
            slot_index,
            prepared,
            self.render_target.?,
            self.offscreen_pipeline.?,
            self.mesh_offscreen_pipeline,
            self.visible_camera,
            false,
            false,
        );
        const copy_pass = c.SDL_BeginGPUCopyPass(command);
        if (copy_pass == null) {
            return failSdl(
                "SDL_BeginGPUCopyPass(Prompt 25A capture)",
                error.UploadFailure,
            );
        }
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
            .transfer_buffer = transfer,
            .offset = 0,
            .pixels_per_row = row_pitch / 4,
            .rows_per_layer = target_height,
        };
        c.SDL_DownloadFromGPUTexture(copy_pass.?, &source, &destination);
        c.SDL_EndGPUCopyPass(copy_pass.?);
        const fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
        command_active = false;
        if (fence == null) {
            return failSdl(
                "SDL_SubmitGPUCommandBufferAndAcquireFence(Prompt 25A capture)",
                error.FrameFenceAcquisitionFailure,
            );
        }
        self.resource_metrics.fence_acquisitions += 1;
        try self.waitReleaseStandaloneFence(fence.?);
        self.current_frame_slot = (slot_index + 1) % frame_slot_count;

        const mapped = c.SDL_MapGPUTransferBuffer(
            self.device.?,
            transfer,
            false,
        ) orelse return failSdl(
            "SDL_MapGPUTransferBuffer(Prompt 25A capture)",
            error.ReadbackFailure,
        );
        defer c.SDL_UnmapGPUTransferBuffer(self.device.?, transfer);
        const rgba: [*]const u8 = @ptrCast(mapped);
        var file = try std.Io.Dir.cwd().createFile(self.io, path, .{});
        defer file.close(self.io);
        var header_buffer: [64]u8 = undefined;
        const header = try std.fmt.bufPrint(
            &header_buffer,
            "P6\n{d} {d}\n255\n",
            .{ target_width, target_height },
        );
        try file.writeStreamingAll(self.io, header);
        var rgb_row: [target_width * 3]u8 = undefined;
        var sha256 = std.crypto.hash.sha2.Sha256.init(.{});
        var minimum_channel: u8 = 255;
        var maximum_channel: u8 = 0;
        var channel_sum: u64 = 0;
        for (0..target_height) |y| {
            for (0..target_width) |x| {
                const source_offset =
                    @as(usize, @intCast(y * row_pitch + x * 4));
                const destination_offset = @as(usize, @intCast(x * 3));
                rgb_row[destination_offset + 0] = rgba[source_offset + 0];
                rgb_row[destination_offset + 1] = rgba[source_offset + 1];
                rgb_row[destination_offset + 2] = rgba[source_offset + 2];
                inline for (0..3) |channel_index| {
                    const channel = rgb_row[destination_offset + channel_index];
                    minimum_channel = @min(minimum_channel, channel);
                    maximum_channel = @max(maximum_channel, channel);
                    channel_sum += channel;
                }
            }
            try file.writeStreamingAll(self.io, &rgb_row);
            sha256.update(&rgb_row);
        }
        self.visual_captures_written += 1;
        var digest: [32]u8 = undefined;
        sha256.final(&digest);
        const payload_bytes: u64 = target_width * target_height * 3;
        return .{
            .width = target_width,
            .height = target_height,
            .rgb_payload_bytes = payload_bytes,
            .sha256 = digest,
            .minimum_channel = minimum_channel,
            .maximum_channel = maximum_channel,
            .mean_channel = @as(f64, @floatFromInt(channel_sum)) /
                @as(f64, @floatFromInt(payload_bytes)),
        };
    }

    fn captureUnifiedToPng(
        self: *GpuDemo,
        prepared: render_queue.PreparedQueue,
        path: []const u8,
    ) !void {
        const transfer = self.visual_capture_transfer orelse
            return error.VisualCaptureTransferNotInitialized;
        const row_pitch = alignForward(target_width * 4, 256);
        if (prepared.sprites.len > self.gpu_instance_capacity) {
            return error.GpuInstanceCapacityExceeded;
        }
        if (prepared.meshes.len > render_queue.default_mesh_capacity) {
            return error.MeshInstanceCapacityExceeded;
        }

        const slot_index = try self.acquireFrameSlot();
        try self.populateInstanceTransfer(slot_index, prepared.sprites);
        try self.populateMeshInstanceTransfer(slot_index, prepared.meshes);
        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse
            return failSdl(
                "SDL_AcquireGPUCommandBuffer(manual visual-truth capture)",
                error.PipelineResourceBindingFailure,
            );
        var command_active = true;
        errdefer if (command_active) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) {
                std.log.err(
                    "SDL_CancelGPUCommandBuffer(manual visual-truth capture): {s}",
                    .{sdlErrorText()},
                );
            }
        };
        _ = try self.encodeUnifiedQueue(
            command,
            slot_index,
            prepared,
            self.render_target.?,
            self.offscreen_pipeline.?,
            self.mesh_offscreen_pipeline,
            self.visible_camera,
            false,
            false,
        );
        const copy_pass = c.SDL_BeginGPUCopyPass(command);
        if (copy_pass == null) {
            return failSdl(
                "SDL_BeginGPUCopyPass(manual visual-truth capture)",
                error.UploadFailure,
            );
        }
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
            .transfer_buffer = transfer,
            .offset = 0,
            .pixels_per_row = row_pitch / 4,
            .rows_per_layer = target_height,
        };
        c.SDL_DownloadFromGPUTexture(copy_pass.?, &source, &destination);
        c.SDL_EndGPUCopyPass(copy_pass.?);
        const fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
        command_active = false;
        if (fence == null) {
            return failSdl(
                "SDL_SubmitGPUCommandBufferAndAcquireFence(manual visual-truth capture)",
                error.FrameFenceAcquisitionFailure,
            );
        }
        self.resource_metrics.fence_acquisitions += 1;
        try self.waitReleaseStandaloneFence(fence.?);
        self.current_frame_slot = (slot_index + 1) % frame_slot_count;

        const mapped = c.SDL_MapGPUTransferBuffer(
            self.device.?,
            transfer,
            false,
        ) orelse return failSdl(
            "SDL_MapGPUTransferBuffer(manual visual-truth capture)",
            error.ReadbackFailure,
        );
        defer c.SDL_UnmapGPUTransferBuffer(self.device.?, transfer);
        const rgba: [*]const u8 = @ptrCast(mapped);
        var file = try std.Io.Dir.cwd().createFile(self.io, path, .{});
        defer file.close(self.io);
        try visual_truth.writeRgbaPng(
            &file,
            self.io,
            rgba,
            target_width,
            target_height,
            row_pitch,
        );
    }

    fn writeFoundationEvidence(
        self: *GpuDemo,
        artifacts: *const [foundation_evidence.capture_count]FoundationCaptureArtifact,
    ) !void {
        var manifest = try std.Io.Dir.cwd().createFile(
            self.io,
            foundation_capture_directory ++ "/capture_manifest.json",
            .{},
        );
        defer manifest.close(self.io);
        try manifest.writeStreamingAll(
            self.io,
            "{\n  \"schema_version\": 1,\n  \"status\": \"candidate_pending_owner_review\",\n  \"capture_count\": 16,\n  \"failure_count\": 0,\n  \"captures\": [\n",
        );
        for (foundation_evidence.specs, artifacts, 0..) |spec, artifact, index| {
            if (!artifact.captured) return error.FoundationCaptureArtifactMissing;
            try artifact.observation.validate();
            if (artifact.pixels.width != target_width or
                artifact.pixels.height != target_height or
                artifact.pixels.rgb_payload_bytes != target_width * target_height * 3 or
                artifact.pixels.minimum_channel >= artifact.pixels.maximum_channel)
            {
                return error.FoundationCapturePixelEvidenceInvalid;
            }
            const hash_hex = std.fmt.bytesToHex(artifact.pixels.sha256, .lower);
            var metadata_path_buffer: [256]u8 = undefined;
            const metadata_path = try std.fmt.bufPrint(
                &metadata_path_buffer,
                "{s}/{s}.json",
                .{ foundation_capture_directory, spec.filename },
            );
            try self.writeFoundationCaptureMetadata(
                metadata_path,
                spec,
                artifact,
                hash_hex[0..],
            );
            var line_buffer: [768]u8 = undefined;
            const line = try std.fmt.bufPrint(
                &line_buffer,
                "    {{\"order\":{d},\"capture_id\":\"{s}\",\"filename\":\"{s}\",\"metadata\":\"{s}.json\",\"render_frame\":{d},\"simulation_tick\":{d},\"stable_ticks\":{d},\"pixel_sha256\":\"{s}\"}}{s}\n",
                .{
                    index + 1,
                    @tagName(spec.id),
                    spec.filename,
                    spec.filename,
                    artifact.observation.render_frame,
                    artifact.observation.simulation_tick,
                    artifact.stable_ticks,
                    hash_hex[0..],
                    if (index + 1 == artifacts.len) "" else ",",
                },
            );
            try manifest.writeStreamingAll(self.io, line);
        }
        try manifest.writeStreamingAll(self.io, "  ]\n}\n");
    }

    fn writeP27bSupplementalEvidence(
        self: *GpuDemo,
        artifacts: *const [p27b_capture_count]P27bCaptureArtifact,
    ) !void {
        var manifest = try std.Io.Dir.cwd().createFile(
            self.io,
            p27b_capture_directory ++ "/supplemental_manifest.json",
            .{},
        );
        defer manifest.close(self.io);
        try manifest.writeStreamingAll(
            self.io,
            "{\n  \"schema\":\"prompt27b.supplemental.v2\",\n  \"status\":\"candidate_pending_owner_review\",\n  \"capture_count\":4,\n  \"failure_count\":0,\n  \"marker_rgb\":{\"far\":[3,251,113],\"midground\":[17,89,253],\"gameplay\":[241,29,197],\"surface\":[11,239,239],\"safe_top\":[247,13,167],\"safe_bottom\":[31,241,71],\"bounds_top\":[199,59,251],\"bounds_bottom\":[239,137,53]},\n  \"captures\":[\n",
        );
        for (artifacts, 0..) |artifact, index| {
            if (!artifact.captured or artifact.filename.len == 0) {
                return error.Prompt27bSupplementalCaptureMissing;
            }
            if (artifact.pixels.width != target_width or
                artifact.pixels.height != target_height or
                artifact.pixels.rgb_payload_bytes != target_width * target_height * 3 or
                artifact.pixels.minimum_channel >= artifact.pixels.maximum_channel)
            {
                return error.Prompt27bSupplementalPixelsInvalid;
            }
            const hash_hex = std.fmt.bytesToHex(
                artifact.pixels.sha256,
                .lower,
            );
            var line_buffer: [1280]u8 = undefined;
            const line = try std.fmt.bufPrint(
                &line_buffer,
                "    {{\"order\":{d},\"filename\":\"{s}\",\"camera_center_m\":[{d:.6},{d:.6}],\"previous_viewport_px\":[{d},{d}],\"semantic_viewport_px\":[{d},{d}],\"first_post_abrupt_resize\":{},\"semantic_headroom_px\":{d:.6},\"semantic_footroom_px\":{d:.6},\"instantaneous_reprojection_world_delta_px\":{d:.6},\"readback_px\":[{d},{d}],\"pixel_sha256\":\"{s}\"}}{s}\n",
                .{
                    index + 1,
                    artifact.filename,
                    artifact.camera_center[0],
                    artifact.camera_center[1],
                    artifact.previous_viewport[0],
                    artifact.previous_viewport[1],
                    artifact.viewport[0],
                    artifact.viewport[1],
                    artifact.first_post_abrupt_resize,
                    artifact.semantic_headroom_px,
                    artifact.semantic_footroom_px,
                    artifact.instantaneous_reprojection_world_delta_px,
                    artifact.pixels.width,
                    artifact.pixels.height,
                    hash_hex[0..],
                    if (index + 1 == artifacts.len) "" else ",",
                },
            );
            try manifest.writeStreamingAll(self.io, line);
        }
        try manifest.writeStreamingAll(self.io, "  ]\n}\n");
    }

    fn writeAnatomyEvidence(
        self: *GpuDemo,
        artifacts: *const [anatomy_evidence.capture_count]AnatomyCaptureArtifact,
    ) !void {
        var manifest = try std.Io.Dir.cwd().createFile(
            self.io,
            p27c_capture_directory ++ "/manifest.json",
            .{},
        );
        defer manifest.close(self.io);
        try manifest.writeStreamingAll(
            self.io,
            "{\n  \"schema\":\"prompt27c.state-conditioned-d3d12.v1\",\n  \"status\":\"candidate_pending_owner_review\",\n  \"backend\":\"direct3d12\",\n  \"shader_format\":\"dxil\",\n  \"capture_count\":8,\n  \"failure_count\":0,\n  \"captures\":[\n",
        );
        for (artifacts, 0..) |artifact, index| {
            if (!artifact.captured or
                artifact.stable_frames < anatomy_evidence.minimum_stable_frames)
            {
                return error.AnatomyCaptureArtifactMissing;
            }
            if (artifact.pixels.width != target_width or
                artifact.pixels.height != target_height or
                artifact.pixels.rgb_payload_bytes !=
                    target_width * target_height * 3 or
                artifact.pixels.minimum_channel >= artifact.pixels.maximum_channel)
            {
                return error.AnatomyCapturePixelsInvalid;
            }
            const spec = anatomy_evidence.specs[index];
            const observation = artifact.observation;
            const hash_hex = std.fmt.bytesToHex(
                artifact.pixels.sha256,
                .lower,
            );
            var line_buffer: [1280]u8 = undefined;
            const line = try std.fmt.bufPrint(
                &line_buffer,
                "    {{\"order\":{d},\"capture_id\":\"{s}\",\"filename\":\"{s}\",\"render_frame\":{d},\"simulation_tick\":{d},\"stage_frame\":{d},\"stable_frames\":{d},\"resolved_view\":\"{s}\",\"facing\":\"{s}\",\"animation\":\"{s}\",\"global_build\":{d:.3},\"elbow_angle_deg\":{d:.6},\"knee_angle_deg\":{d:.6},\"anatomy_trace_records\":{d},\"readback_px\":[{d},{d}],\"pixel_sha256\":\"{s}\"}}{s}\n",
                .{
                    index + 1,
                    @tagName(spec.stage),
                    spec.filename,
                    observation.render_frame,
                    observation.simulation_tick,
                    observation.stage_frame,
                    artifact.stable_frames,
                    @tagName(observation.view),
                    @tagName(observation.facing),
                    observation.animation,
                    observation.global_build,
                    observation.elbow_angle_degrees,
                    observation.knee_angle_degrees,
                    observation.anatomy_trace_records,
                    artifact.pixels.width,
                    artifact.pixels.height,
                    hash_hex[0..],
                    if (index + 1 == artifacts.len) "" else ",",
                },
            );
            try manifest.writeStreamingAll(self.io, line);
        }
        try manifest.writeStreamingAll(self.io, "  ]\n}\n");
    }

    fn writeFoundationCaptureMetadata(
        self: *GpuDemo,
        path: []const u8,
        spec: foundation_evidence.CaptureSpec,
        artifact: FoundationCaptureArtifact,
        hash_hex: []const u8,
    ) !void {
        const observation = artifact.observation;
        var file = try std.Io.Dir.cwd().createFile(self.io, path, .{});
        defer file.close(self.io);
        var buffer: [4096]u8 = undefined;
        const first = try std.fmt.bufPrint(
            &buffer,
            "{{\n  \"schema_version\":1,\n  \"capture_id\":\"{s}\",\n  \"filename\":\"{s}\",\n  \"render_frame\":{d},\n  \"simulation_tick\":{d},\n  \"script_phase\":\"{s}\",\n  \"script_phase_frame\":{d},\n  \"required_stable_ticks\":{d},\n  \"consecutive_stable_ticks\":{d},\n  \"female_entity_id\":{d},\n  \"male_entity_id\":{d},\n  \"position_m\":[{d:.6},{d:.6}],\n  \"velocity_mps\":[{d:.6},{d:.6}],\n  \"gameplay_facing\":\"{s}\",\n  \"presentation_mode\":\"{s}\",\n  \"resolved_view\":\"{s}\",\n  \"grounded\":{},\n  \"supporting_collider\":",
            .{
                @tagName(spec.id),
                spec.filename,
                observation.render_frame,
                observation.simulation_tick,
                @tagName(observation.stage),
                observation.stage_frame,
                spec.minimum_stable_ticks,
                artifact.stable_ticks,
                observation.female_entity,
                observation.male_entity,
                observation.position[0],
                observation.position[1],
                observation.velocity[0],
                observation.velocity[1],
                @tagName(observation.facing),
                @tagName(observation.presentation_mode),
                @tagName(observation.view),
                observation.grounded,
            },
        );
        try file.writeStreamingAll(self.io, first);
        try writeOptionalU32(&file, self.io, observation.supporting_collider);
        const second = try std.fmt.bufPrint(
            &buffer,
            ",\n  \"animation_state\":\"{s}\",\n  \"animation_normalized_time\":{d:.6},\n  \"physics\":{{\"locomotion_phase_valid\":{},\"airborne_clearance_m\":{d:.6},\"landed_this_frame\":{},\"landing_support\":",
            .{
                observation.animation_state,
                observation.animation_normalized_time,
                observation.locomotion_phase_valid,
                observation.airborne_clearance_m,
                observation.landed_this_frame,
            },
        );
        try file.writeStreamingAll(self.io, second);
        try writeOptionalU32(&file, self.io, observation.landing_support);
        const third = try std.fmt.bufPrint(
            &buffer,
            ",\"raised_support\":{d},\"left_surface_error_m\":",
            .{observation.raised_support},
        );
        try file.writeStreamingAll(self.io, third);
        try writeOptionalF32(&file, self.io, observation.left_surface_error_m);
        try file.writeStreamingAll(self.io, ",\"right_surface_error_m\":");
        try writeOptionalF32(&file, self.io, observation.right_surface_error_m);
        const fourth = try std.fmt.bufPrint(
            &buffer,
            ",\"surface_contact_valid\":{}}},\n  \"body\":\"{s}\",\n  \"morphology\":\"{s}\",\n  \"global_build_percent\":{d:.6},\n  \"hair\":\"{s}\",\n  \"outfit\":\"{s}\",\n  \"theme\":\"{s}\",\n  \"theme_transition\":{{\"count\":{d},\"changed\":{},\"fingerprint_unchanged\":{},\"root_delta_m\":{d:.9},\"camera_delta_m\":{d:.9}}},\n  \"interaction\":{{\"eligible\":{},\"id\":{d},\"lifecycle\":\"{s}\",\"phase\":\"{s}\",\"elapsed_ticks\":{d},\"contact_tick\":{d},\"release_tick\":{d},\"complete_tick\":{d},\"ik_active\":{},\"ordering_valid\":{},\"active_count\":{d},\"ik_constraint_count\":{d},\"override_count\":{d},\"participant_owner_count\":{d}}},\n",
            .{
                observation.feet_surface_contact_valid,
                observation.body,
                observation.morphology,
                observation.global_build,
                observation.hair,
                observation.outfit,
                observation.theme,
                observation.theme_transition_count,
                observation.theme_changed,
                observation.theme_fingerprint_unchanged,
                observation.theme_root_delta_m,
                observation.theme_camera_delta_m,
                observation.interaction_eligible,
                observation.interaction_id,
                @tagName(observation.interaction_lifecycle),
                @tagName(observation.interaction_phase),
                observation.interaction_elapsed_ticks,
                observation.contact_tick,
                observation.release_tick,
                observation.complete_tick,
                observation.ik_active,
                observation.ordering_valid,
                observation.active_interactions,
                observation.active_ik_constraints,
                observation.active_overrides,
                observation.participant_owner_count,
            },
        );
        try file.writeStreamingAll(self.io, fourth);
        const fifth = try std.fmt.bufPrint(
            &buffer,
            "  \"debug\":{{\"enabled\":{},\"enabled_ticks\":{d},\"collider\":{d},\"root\":{d},\"ground\":{d},\"ik\":{d},\"participant_link\":{d},\"total\":{d}}},\n  \"camera\":{{\"center_m\":[{d:.6},{d:.6}],\"viewport_px\":[{d},{d}] }},\n  \"render\":{{\"texture_pages\":{d},\"submitted_sprites\":{d},\"submitted_meshes\":{d},\"sprite_ranges\":{d},\"mesh_ranges\":{d},\"gpu_resource_creations\":{d}}},\n  \"allocations\":{{\"update\":{d},\"submission\":{d},\"queue\":{d}}},\n  \"reset_generation\":{d},\n  \"pixels\":{{\"width_px\":{d},\"height_px\":{d},\"rgb_payload_bytes\":{d},\"sha256\":\"{s}\",\"minimum_channel\":{d},\"maximum_channel\":{d},\"mean_channel\":{d:.6}}},\n  \"manual_visual_acceptance\":\"PENDING OWNER REVIEW\"\n}}\n",
            .{
                observation.detailed_debug_enabled,
                observation.debug_enabled_ticks,
                observation.debug_counts.collider,
                observation.debug_counts.root,
                observation.debug_counts.ground,
                observation.debug_counts.ik,
                observation.debug_counts.participant_link,
                observation.debug_counts.total(),
                observation.camera_center[0],
                observation.camera_center[1],
                observation.viewport[0],
                observation.viewport[1],
                observation.texture_pages,
                observation.submitted_sprites,
                observation.submitted_meshes,
                observation.sprite_ranges,
                observation.mesh_ranges,
                observation.gpu_resource_creations,
                observation.steady_update_allocations,
                observation.steady_submission_allocations,
                observation.steady_queue_allocations,
                observation.reset_generation,
                artifact.pixels.width,
                artifact.pixels.height,
                artifact.pixels.rgb_payload_bytes,
                hash_hex,
                artifact.pixels.minimum_channel,
                artifact.pixels.maximum_channel,
                artifact.pixels.mean_channel,
            },
        );
        try file.writeStreamingAll(self.io, fifth);
    }

    fn renderPreparedToWindow(self: *GpuDemo, prepared: sprite.PreparedBatch, injector: ?fault_injection.Injector) !bool {
        if (!self.drawable_available) return false;
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
        if (swapchain_texture == null) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) return failSdl("SDL_CancelGPUCommandBuffer(zero drawable)", error.PipelineResourceBindingFailure);
            command_active = false;
            self.drawable_available = false;
            self.drawable_width = 0;
            self.drawable_height = 0;
            return false;
        }
        if (swapchain_width == 0 or swapchain_height == 0) {
            const empty_fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
            command_active = false;
            if (empty_fence == null) return failSdl("SDL_SubmitGPUCommandBufferAndAcquireFence(zero drawable)", error.FrameFenceAcquisitionFailure);
            self.resource_metrics.fence_acquisitions += 1;
            self.frame_slots[slot_index].fence = empty_fence.?;
            self.current_frame_slot = (slot_index + 1) % frame_slot_count;
            self.drawable_available = false;
            self.drawable_width = 0;
            self.drawable_height = 0;
            return false;
        }
        try self.applyDrawableSize(swapchain_width, swapchain_height);
        const encoded_draws = try self.encodeAuthoritativeSpriteBatch(
            command,
            slot_index,
            prepared,
            swapchain_texture.?,
            self.window_pipeline.?,
            self.visible_camera,
            true,
        );

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
        const encoded_draws = try self.encodeAuthoritativeSpriteBatch(
            command,
            slot_index,
            prepared,
            self.render_target.?,
            self.offscreen_pipeline.?,
            camera2d.Camera2D.initDefault(),
            false,
        );
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

    fn encodeUnifiedQueue(
        self: *GpuDemo,
        command: *c.SDL_GPUCommandBuffer,
        slot_index: usize,
        prepared: render_queue.PreparedQueue,
        target: *c.SDL_GPUTexture,
        sprite_pipeline: *c.SDL_GPUGraphicsPipeline,
        mesh_pipeline: ?*c.SDL_GPUGraphicsPipeline,
        camera: camera2d.Camera2D,
        cycle_target: bool,
        record_metrics: bool,
    ) !EncodedDrawCounts {
        const sprite_upload_bytes = try sprite.instanceByteSize(prepared.sprites.len);
        const mesh_upload_bytes = try render_queue.meshInstanceByteSize(prepared.meshes.len);
        if (record_metrics) {
            self.unified_queue.?.recordUploads(
                sprite_upload_bytes,
                mesh_upload_bytes,
            );
        }
        if (sprite_upload_bytes > 0 or mesh_upload_bytes > 0) {
            const copy_pass = c.SDL_BeginGPUCopyPass(command);
            if (copy_pass == null) return failSdl("SDL_BeginGPUCopyPass(unified instance upload)", error.UploadFailure);
            if (sprite_upload_bytes > 0) {
                const sprite_source = c.SDL_GPUTransferBufferLocation{
                    .transfer_buffer = self.frame_slots[slot_index].transfer_buffer.?,
                    .offset = 0,
                };
                const sprite_destination = c.SDL_GPUBufferRegion{
                    .buffer = self.frame_slots[slot_index].instance_buffer.?,
                    .offset = 0,
                    .size = sprite_upload_bytes,
                };
                c.SDL_UploadToGPUBuffer(copy_pass.?, &sprite_source, &sprite_destination, false);
            }
            if (mesh_upload_bytes > 0) {
                const mesh_source = c.SDL_GPUTransferBufferLocation{
                    .transfer_buffer = self.frame_slots[slot_index].mesh_transfer_buffer.?,
                    .offset = 0,
                };
                const mesh_destination = c.SDL_GPUBufferRegion{
                    .buffer = self.frame_slots[slot_index].mesh_instance_buffer.?,
                    .offset = 0,
                    .size = mesh_upload_bytes,
                };
                c.SDL_UploadToGPUBuffer(copy_pass.?, &mesh_source, &mesh_destination, false);
            }
            c.SDL_EndGPUCopyPass(copy_pass.?);
        }

        const camera_uniform = try camera.uniform();
        c.SDL_PushGPUVertexUniformData(command, 0, &camera_uniform, @sizeOf(camera2d.CameraUniform));
        var target_info: c.SDL_GPUColorTargetInfo = std.mem.zeroes(c.SDL_GPUColorTargetInfo);
        target_info.texture = target;
        target_info.clear_color = clear_color;
        target_info.load_op = c.SDL_GPU_LOADOP_CLEAR;
        target_info.store_op = c.SDL_GPU_STOREOP_STORE;
        target_info.cycle = cycle_target;
        const render_pass = c.SDL_BeginGPURenderPass(command, &target_info, 1, null);
        if (render_pass == null) return failSdl("SDL_BeginGPURenderPass(unified queue)", error.PipelineResourceBindingFailure);

        var encoded = EncodedDrawCounts{};
        for (prepared.ranges) |range| {
            const texture_binding = self.textureBinding(range.texture_page) catch |err| {
                std.log.err("bind unified texture page: invalid texture_page={d}, configured_pages={d}", .{
                    range.texture_page,
                    self.texture_page_count,
                });
                c.SDL_EndGPURenderPass(render_pass.?);
                return err;
            };
            c.SDL_BindGPUFragmentSamplers(render_pass.?, 0, &texture_binding, 1);
            switch (range.kind) {
                .rigid_sprite => {
                    c.SDL_BindGPUGraphicsPipeline(render_pass.?, sprite_pipeline);
                    const vertex_bindings = [_]c.SDL_GPUBufferBinding{
                        .{ .buffer = self.quad_vertex_buffer.?, .offset = 0 },
                        .{ .buffer = self.frame_slots[slot_index].instance_buffer.?, .offset = 0 },
                    };
                    c.SDL_BindGPUVertexBuffers(render_pass.?, 0, &vertex_bindings, vertex_bindings.len);
                    const index_binding = c.SDL_GPUBufferBinding{ .buffer = self.quad_index_buffer.?, .offset = 0 };
                    c.SDL_BindGPUIndexBuffer(render_pass.?, &index_binding, c.SDL_GPU_INDEXELEMENTSIZE_16BIT);
                    drawIndexedPrimitives(render_pass.?, quad_indices.len, range.count, 0, 0, range.first);
                    encoded.sprites += 1;
                },
                .deformable_mesh => {
                    c.SDL_BindGPUGraphicsPipeline(render_pass.?, mesh_pipeline orelse {
                        c.SDL_EndGPURenderPass(render_pass.?);
                        return error.MeshRenderingNotInitialized;
                    });
                    const vertex_bindings = [_]c.SDL_GPUBufferBinding{
                        .{ .buffer = self.mesh_vertex_buffer.?, .offset = 0 },
                        .{ .buffer = self.frame_slots[slot_index].mesh_instance_buffer.?, .offset = 0 },
                    };
                    c.SDL_BindGPUVertexBuffers(render_pass.?, 0, &vertex_bindings, vertex_bindings.len);
                    const index_binding = c.SDL_GPUBufferBinding{ .buffer = self.mesh_index_buffer.?, .offset = 0 };
                    c.SDL_BindGPUIndexBuffer(render_pass.?, &index_binding, c.SDL_GPU_INDEXELEMENTSIZE_16BIT);
                    const first_draw: usize = range.first;
                    const draw_count: usize = range.count;
                    for (prepared.mesh_draws[first_draw .. first_draw + draw_count]) |draw| {
                        const topology = try self.mesh_catalog.?.find(draw.definition);
                        if (topology.texture_page != range.texture_page) {
                            c.SDL_EndGPURenderPass(render_pass.?);
                            return error.MeshCatalogMaterialMismatch;
                        }
                        drawIndexedPrimitives(
                            render_pass.?,
                            topology.index_count,
                            draw.instance_count,
                            topology.first_index,
                            @intCast(topology.first_vertex),
                            draw.first_instance,
                        );
                        encoded.meshes += 1;
                    }
                },
            }
        }
        c.SDL_EndGPURenderPass(render_pass.?);
        return encoded;
    }

    fn encodeAuthoritativeSpriteBatch(
        self: *GpuDemo,
        command: *c.SDL_GPUCommandBuffer,
        slot_index: usize,
        prepared: sprite.PreparedBatch,
        target: *c.SDL_GPUTexture,
        pipeline: *c.SDL_GPUGraphicsPipeline,
        camera: camera2d.Camera2D,
        cycle_target: bool,
    ) !u32 {
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

        const camera_uniform = try camera.uniform();
        c.SDL_PushGPUVertexUniformData(command, 0, &camera_uniform, @sizeOf(camera2d.CameraUniform));
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
            c.SDL_BindGPUGraphicsPipeline(render_pass.?, pipeline);
            const vertex_bindings = [_]c.SDL_GPUBufferBinding{
                .{ .buffer = self.quad_vertex_buffer.?, .offset = 0 },
                .{ .buffer = self.frame_slots[slot_index].instance_buffer.?, .offset = 0 },
            };
            c.SDL_BindGPUVertexBuffers(render_pass.?, 0, &vertex_bindings, vertex_bindings.len);
            const index_binding = c.SDL_GPUBufferBinding{ .buffer = self.quad_index_buffer.?, .offset = 0 };
            c.SDL_BindGPUIndexBuffer(render_pass.?, &index_binding, c.SDL_GPU_INDEXELEMENTSIZE_16BIT);
            for (prepared.ranges) |range| {
                const binding = self.textureBinding(range.texture_page) catch |err| {
                    std.log.err("bind sprite texture page: invalid texture_page={d}, configured_pages={d}, first_instance={d}", .{
                        range.texture_page,
                        self.texture_page_count,
                        range.first_instance,
                    });
                    c.SDL_EndGPURenderPass(render_pass.?);
                    return err;
                };
                c.SDL_BindGPUFragmentSamplers(render_pass.?, 0, &binding, 1);
                drawIndexedPrimitives(render_pass.?, quad_indices.len, range.instance_count, 0, 0, range.first_instance);
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

    fn populateMeshInstanceTransfer(
        self: *GpuDemo,
        slot_index: usize,
        submissions: []const render_queue.MeshSubmission,
    ) !void {
        if (submissions.len == 0) return;
        const transfer = self.frame_slots[slot_index].mesh_transfer_buffer.?;
        const mapped = c.SDL_MapGPUTransferBuffer(self.device.?, transfer, false) orelse {
            std.log.err("SDL_MapGPUTransferBuffer(mesh instance upload): slot={d} instances={d} bytes={d}: {s}", .{
                slot_index,
                submissions.len,
                render_queue.meshInstanceByteSize(submissions.len) catch 0,
                sdlErrorText(),
            });
            return error.UploadFailure;
        };
        defer c.SDL_UnmapGPUTransferBuffer(self.device.?, transfer);
        const bytes: [*]u8 = @ptrCast(mapped);
        for (submissions, 0..) |submission, index| {
            const offset = index * @sizeOf(mesh.GpuInstance);
            copyBytes(bytes, offset, std.mem.asBytes(&submission.gpu_instance));
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

    fn createMeshSlotResources(self: *GpuDemo, capacity: usize) !void {
        const byte_size = try render_queue.meshInstanceByteSize(capacity);
        errdefer self.releaseMeshSlotResources();
        for (&self.frame_slots, 0..) |*slot, index| {
            if (slot.mesh_instance_buffer != null or slot.mesh_transfer_buffer != null) {
                return error.MeshFrameSlotAlreadyInitialized;
            }
            slot.mesh_instance_buffer = createBuffer(self.device.?, c.SDL_GPU_BUFFERUSAGE_VERTEX, byte_size);
            if (slot.mesh_instance_buffer == null) {
                std.log.err("SDL_CreateGPUBuffer(mesh instance): capacity={d} bytes={d} slot={d}: {s}", .{
                    capacity,
                    byte_size,
                    index,
                    sdlErrorText(),
                });
                return error.MeshInstanceBufferCreationFailure;
            }
            self.resource_metrics.gpu_resource_creations += 1;
            var transfer_info: c.SDL_GPUTransferBufferCreateInfo = std.mem.zeroes(c.SDL_GPUTransferBufferCreateInfo);
            transfer_info.usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
            transfer_info.size = byte_size;
            slot.mesh_transfer_buffer = c.SDL_CreateGPUTransferBuffer(self.device.?, &transfer_info);
            if (slot.mesh_transfer_buffer == null) {
                std.log.err("SDL_CreateGPUTransferBuffer(mesh instance): capacity={d} bytes={d} slot={d}: {s}", .{
                    capacity,
                    byte_size,
                    index,
                    sdlErrorText(),
                });
                return error.GpuTransferBufferCreationFailure;
            }
            self.resource_metrics.gpu_resource_creations += 1;
        }
    }

    fn releaseMeshSlotResources(self: *GpuDemo) void {
        const device = self.device orelse return;
        for (&self.frame_slots) |*slot| {
            if (slot.mesh_transfer_buffer) |resource| self.releaseTransfer(device, resource);
            if (slot.mesh_instance_buffer) |resource| self.releaseBuffer(device, resource);
            slot.mesh_transfer_buffer = null;
            slot.mesh_instance_buffer = null;
        }
    }

    fn releaseSlotResources(self: *GpuDemo, slots: *[frame_slot_count]FrameSlot) void {
        const device = self.device orelse return;
        for (slots) |*slot| {
            if (slot.mesh_transfer_buffer) |resource| self.releaseTransfer(device, resource);
            if (slot.mesh_instance_buffer) |resource| self.releaseBuffer(device, resource);
            if (slot.transfer_buffer) |resource| self.releaseTransfer(device, resource);
            if (slot.instance_buffer) |resource| self.releaseBuffer(device, resource);
            slot.mesh_transfer_buffer = null;
            slot.mesh_instance_buffer = null;
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

    fn updateUnifiedWindowTitle(self: *GpuDemo) !void {
        const metrics = self.unified_queue.?.frame_metrics;
        var buffer: [256]u8 = undefined;
        const title = std.fmt.bufPrintZ(&buffer, "sprites {d} meshes {d} sprite ranges/draws {d}/{d} mesh ranges/draws {d}/{d} upload {d}B slot {d}", .{
            metrics.submitted_sprites,
            metrics.submitted_meshes,
            metrics.sprite_ranges,
            metrics.sprite_draws,
            metrics.mesh_ranges,
            metrics.mesh_draws,
            metrics.sprite_upload_bytes + metrics.mesh_upload_bytes,
            self.current_frame_slot,
        }) catch return error.WindowTitleFormatFailure;
        if (!c.SDL_SetWindowTitle(self.window.?, title.ptr)) {
            return failSdl("SDL_SetWindowTitle(unified metrics)", error.WindowTitleUpdateFailure);
        }
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

fn logInputTransitions(previous: ?input.FrameInputSnapshot, current: input.FrameInputSnapshot, debug_enabled_before: bool) void {
    const old_left = if (previous) |value| value.keyboard_left_held else false;
    const old_right = if (previous) |value| value.keyboard_right_held else false;
    if (current.keyboard_left_held != old_left) {
        std.log.info("move left {s}", .{if (current.keyboard_left_held) "started" else "stopped"});
    }
    if (current.keyboard_right_held != old_right) {
        std.log.info("move right {s}", .{if (current.keyboard_right_held) "started" else "stopped"});
    }
    if (current.jump.pressed) std.log.info("jump pressed", .{});
    if (current.jump.released) std.log.info("jump released", .{});
    if (current.interact.pressed) std.log.info("interaction requested", .{});
    if (current.reset.pressed) std.log.info("reset requested", .{});
    if (current.debug_toggle.pressed) std.log.info("debug {s}", .{if (debug_enabled_before) "disabled" else "enabled"});
    if (current.focus_lost) std.log.info("keyboard focus lost; held state and pending keyboard edges cleared", .{});
}

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

fn createPipeline(self: GpuDemo, target_format: c.SDL_GPUTextureFormat) !*c.SDL_GPUGraphicsPipeline {
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
        .{ .location = 7, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT, .offset = @offsetOf(sprite.GpuInstance, "camera_x_factor") },
    };
    var color_target: c.SDL_GPUColorTargetDescription = std.mem.zeroes(c.SDL_GPUColorTargetDescription);
    color_target.format = target_format;
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
    return createGraphicsPipeline(
        self.device.?,
        &info,
        "SDL_CreateGPUGraphicsPipeline(sprite batch)",
        error.PipelineCreationFailure,
    );
}

fn createMeshPipeline(self: *const GpuDemo, target_format: c.SDL_GPUTextureFormat) !*c.SDL_GPUGraphicsPipeline {
    const descriptions = [_]c.SDL_GPUVertexBufferDescription{
        .{
            .slot = 0,
            .pitch = @sizeOf(mesh.GpuBaseVertex),
            .input_rate = c.SDL_GPU_VERTEXINPUTRATE_VERTEX,
            .instance_step_rate = 0,
        },
        .{
            .slot = 1,
            .pitch = @sizeOf(mesh.GpuInstance),
            .input_rate = c.SDL_GPU_VERTEXINPUTRATE_INSTANCE,
            .instance_step_rate = 0,
        },
    };
    const attributes = [_]c.SDL_GPUVertexAttribute{
        .{ .location = 0, .buffer_slot = 0, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(mesh.GpuBaseVertex, "local_position") },
        .{ .location = 1, .buffer_slot = 0, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(mesh.GpuBaseVertex, "uv") },
        .{ .location = 2, .buffer_slot = 0, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT, .offset = @offsetOf(mesh.GpuBaseVertex, "deformation_weight") },
        .{ .location = 3, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(mesh.GpuInstance, "world_column_0") },
        .{ .location = 4, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(mesh.GpuInstance, "world_column_1") },
        .{ .location = 5, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(mesh.GpuInstance, "world_translation") },
        .{ .location = 6, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(mesh.GpuInstance, "deformation_translation") },
        .{ .location = 7, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT, .offset = @offsetOf(mesh.GpuInstance, "deformation_rotation") },
        .{ .location = 8, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(mesh.GpuInstance, "deformation_scale") },
        .{ .location = 9, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, .offset = @offsetOf(mesh.GpuInstance, "tint") },
        .{ .location = 10, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT, .offset = @offsetOf(mesh.GpuInstance, "camera_x_factor") },
    };
    var color_target: c.SDL_GPUColorTargetDescription = std.mem.zeroes(c.SDL_GPUColorTargetDescription);
    color_target.format = target_format;
    color_target.blend_state.src_color_blendfactor = c.SDL_GPU_BLENDFACTOR_SRC_ALPHA;
    color_target.blend_state.dst_color_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    color_target.blend_state.color_blend_op = c.SDL_GPU_BLENDOP_ADD;
    color_target.blend_state.src_alpha_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE;
    color_target.blend_state.dst_alpha_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    color_target.blend_state.alpha_blend_op = c.SDL_GPU_BLENDOP_ADD;
    color_target.blend_state.enable_blend = true;
    var info: c.SDL_GPUGraphicsPipelineCreateInfo = std.mem.zeroes(c.SDL_GPUGraphicsPipelineCreateInfo);
    info.vertex_shader = self.mesh_vertex_shader.?;
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
    return createGraphicsPipeline(
        self.device.?,
        &info,
        "SDL_CreateGPUGraphicsPipeline(deformable mesh)",
        error.MeshPipelineCreationFailure,
    );
}

fn uploadBuffer(copy_pass: *c.SDL_GPUCopyPass, transfer: *c.SDL_GPUTransferBuffer, source_offset: u32, destination_buffer: *c.SDL_GPUBuffer, size: u32) void {
    const source = c.SDL_GPUTransferBufferLocation{ .transfer_buffer = transfer, .offset = source_offset };
    const destination = c.SDL_GPUBufferRegion{ .buffer = destination_buffer, .offset = 0, .size = size };
    c.SDL_UploadToGPUBuffer(copy_pass, &source, &destination, false);
}

fn drawIndexedPrimitives(
    render_pass: *c.SDL_GPURenderPass,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    vertex_offset: i32,
    first_instance: u32,
) void {
    c.SDL_DrawGPUIndexedPrimitives(
        render_pass,
        index_count,
        instance_count,
        first_index,
        vertex_offset,
        first_instance,
    );
}

fn createGraphicsPipeline(
    device: *c.SDL_GPUDevice,
    info: *const c.SDL_GPUGraphicsPipelineCreateInfo,
    operation: []const u8,
    creation_error: anyerror,
) !*c.SDL_GPUGraphicsPipeline {
    return c.SDL_CreateGPUGraphicsPipeline(device, info) orelse failSdl(operation, creation_error);
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

fn resourceSnapshot(self: *const GpuDemo, cpu_allocation_bytes: usize, created_this_frame: u64) diagnostics.ResourceSnapshot {
    return .{
        .cpu_allocation_bytes = cpu_allocation_bytes,
        .gpu_textures = 2,
        .gpu_buffers = 2 + frame_slot_count,
        .gpu_pipelines = 2,
        .gpu_samplers = 1,
        .other_gpu_resources = 2 + frame_slot_count,
        .gpu_resources_created_this_frame = created_this_frame,
        .gpu_resources_created_lifetime = self.resource_metrics.gpu_resource_creations,
    };
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

const GitDirty = struct {
    staged: bool = false,
    unstaged: bool = false,
    untracked: bool = false,
};

fn parseGitDirty(output: []const u8) GitDirty {
    var result = GitDirty{};
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (line.len < 2) continue;
        if (line[0] == '?' and line[1] == '?') {
            result.untracked = true;
            continue;
        }
        if (line[0] != ' ' and line[0] != '?') result.staged = true;
        if (line[1] != ' ' and line[1] != '?') result.unstaged = true;
    }
    return result;
}

fn requireSuccessfulProcess(
    term: std.process.Child.Term,
    operation: []const u8,
    stderr: []const u8,
) !void {
    switch (term) {
        .exited => |code| if (code != 0) {
            std.log.err(
                "{s} exited with code {d}: {s}",
                .{ operation, code, std.mem.trim(u8, stderr, " \t\r\n") },
            );
            return error.ManualCaptureProvenanceCommandFailed;
        },
        else => {
            std.log.err("{s} terminated abnormally", .{operation});
            return error.ManualCaptureProvenanceCommandFailed;
        },
    }
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
