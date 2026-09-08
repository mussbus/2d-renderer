const std = @import("std");
const c = @import("sdl").c;
const fault_injection = @import("fault_injection");
const sprite = @import("sprite_batch");
const mesh = @import("deformable_mesh");
const render_queue = @import("render_queue");
const mesh_gpu_catalog = @import("mesh_gpu_catalog");
const camera2d = @import("camera2d");
const art_pack = @import("art_pack");
const image_decode = @import("image_decode");
const diagnostics = @import("diagnostics");
const frame_capture = @import("frame_capture");

pub const target_width: u32 = 640;
pub const target_height: u32 = 480;

const texture_width: u32 = 4;
const texture_height: u32 = 4;
const upload_texture_row_pitch: u32 = 256;
const texture_upload_size: u32 = upload_texture_row_pitch * texture_height;
pub const frame_slot_count: usize = 3;
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

pub const ResourceMetrics = struct {
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

const PlatformWindow = struct {
    sdl_initialized: bool = false,
    window: ?*c.SDL_Window = null,
};

pub const DrawableInfo = struct {
    width: u32,
    height: u32,
    available: bool,
};

pub const TexturePageInfo = struct {
    stable_id: art_pack.TexturePageId,
    width: u32,
    height: u32,
    sampling: art_pack.SamplingPolicy,
};

const EncodedDrawCounts = struct {
    sprites: u32 = 0,
    meshes: u32 = 0,
};

pub const Renderer = struct {
    state: *State,

    pub fn init(
        allocator: std.mem.Allocator,
        hidden: bool,
        injector: ?fault_injection.Injector,
    ) !Renderer {
        const state = try allocator.create(State);
        errdefer allocator.destroy(state);
        state.* = try State.init(allocator, hidden, injector);
        return .{ .state = state };
    }

    pub fn deinit(self: *Renderer) void {
        _ = self.deinitWithMetrics();
    }

    /// Performs the existing complete shutdown path and returns only copied
    /// diagnostics after every tracked resource has been released. The opaque
    /// renderer state remains inaccessible to clients.
    pub fn deinitWithMetrics(self: *Renderer) ResourceMetrics {
        const allocator = self.state.allocator;
        self.state.deinit();
        const final_metrics = self.state.resource_metrics;
        allocator.destroy(self.state);
        self.* = undefined;
        return final_metrics;
    }

    pub fn runRuntimeFaultChecks(self: *Renderer) !void {
        try self.state.runRuntimeFaultChecks();
    }

    pub fn runSmoke(self: *Renderer) !void {
        try self.state.runSmoke();
    }

    pub fn spriteBatch(self: *Renderer) *sprite.SpriteBatch {
        return &self.state.batch.?;
    }

    pub fn renderQueue(self: *Renderer) *render_queue.UnifiedRenderQueue {
        return &self.state.unified_queue.?;
    }

    pub fn renderQueueOptional(self: *Renderer) ?*render_queue.UnifiedRenderQueue {
        if (self.state.unified_queue) |*queue| return queue;
        return null;
    }

    pub fn meshCatalog(self: *Renderer) *mesh_gpu_catalog.Catalog {
        return &self.state.mesh_catalog.?;
    }

    pub fn camera(self: *Renderer) *camera2d.Camera2D {
        return &self.state.visible_camera;
    }

    pub fn drawable(self: *const Renderer) DrawableInfo {
        return .{
            .width = self.state.drawable_width,
            .height = self.state.drawable_height,
            .available = self.state.drawable_available,
        };
    }

    pub fn metrics(self: *const Renderer) ResourceMetrics {
        return self.state.resource_metrics;
    }

    pub fn resourceSnapshot(
        self: *const Renderer,
        cpu_allocation_bytes: usize,
        created_this_frame: u64,
    ) diagnostics.ResourceSnapshot {
        return stateResourceSnapshot(
            self.state,
            cpu_allocation_bytes,
            created_this_frame,
        );
    }

    pub fn recordFrameResult(self: *Renderer, rendered: bool) void {
        if (rendered) {
            self.state.resource_metrics.frames_rendered += 1;
        } else {
            self.state.resource_metrics.zero_drawable_frames += 1;
        }
    }

    pub fn texturePageCount(self: *const Renderer) u32 {
        return self.state.texture_page_count;
    }

    pub fn artTexturePageCount(self: *const Renderer) usize {
        return self.state.art_texture_page_count;
    }

    pub fn imageDecodeMetrics(self: *const Renderer) image_decode.Metrics {
        return self.state.image_decode_metrics;
    }

    pub fn texturePageInfo(self: *const Renderer, index: usize) !TexturePageInfo {
        if (index >= self.state.art_texture_page_count) return error.InvalidTexturePage;
        const page = self.state.art_texture_pages[index] orelse
            return error.InvalidTexturePage;
        return .{
            .stable_id = page.stable_id,
            .width = page.width,
            .height = page.height,
            .sampling = page.sampling,
        };
    }

    pub fn backendName(self: *const Renderer) ![]const u8 {
        const pointer = c.SDL_GetGPUDeviceDriver(self.state.device.?) orelse
            return failSdl(
                "SDL_GetGPUDeviceDriver",
                error.GpuDeviceCreationFailure,
            );
        return std.mem.span(@as([*:0]const u8, @ptrCast(pointer)));
    }

    pub fn initializeUnifiedQueue(self: *Renderer) !void {
        try self.state.initializeUnifiedQueue();
    }

    /// Caller-selected CPU queue capacities; GPU storage remains explicitly
    /// configured through ensureGpuCapacity. Existing defaults are unchanged.
    pub fn initializeUnifiedQueueWithCapacities(self: *Renderer, entries: usize, sprites: usize, meshes: usize) !void {
        try self.state.initializeUnifiedQueueWithCapacities(entries, sprites, meshes);
    }

    pub fn ensureGpuCapacity(
        self: *Renderer,
        required: usize,
        injector: ?fault_injection.Injector,
    ) !void {
        try self.state.ensureGpuCapacity(required, injector);
    }

    pub fn currentFrameSlot(self: *const Renderer) usize {
        return self.state.current_frame_slot;
    }

    pub fn initializeCapture(self: *Renderer) !void {
        try self.state.initializeVisualCaptureTransfer();
    }

    pub fn initializeMeshRendering(
        self: *Renderer,
        definitions: []const mesh.DefinitionView,
    ) !void {
        try self.state.initializeMeshRendering(definitions);
    }

    pub fn initializeArtTexturePages(
        self: *Renderer,
        definition: *const art_pack.Definition,
    ) !void {
        try self.state.initializeArtTexturePages(definition);
    }

    pub fn initializeArtTexturePageSets(
        self: *Renderer,
        definitions: []const *const art_pack.Definition,
    ) !void {
        try self.state.initializeArtTexturePageSets(definitions);
    }

    pub fn runArtTextureFaultChecks(
        self: *Renderer,
        definition: *const art_pack.Definition,
    ) !void {
        try self.state.runArtTextureFaultChecks(definition);
    }

    pub fn handleWindowEvent(
        self: *Renderer,
        event: *const c.SDL_Event,
    ) !void {
        try self.state.handleWindowEvent(event);
    }

    pub fn renderUnifiedToWindow(
        self: *Renderer,
        prepared: render_queue.PreparedQueue,
    ) !bool {
        return self.state.renderUnifiedToWindow(prepared);
    }

    pub fn renderPreparedToWindow(
        self: *Renderer,
        prepared: sprite.PreparedBatch,
        injector: ?fault_injection.Injector,
    ) !bool {
        return self.state.renderPreparedToWindow(prepared, injector);
    }

    pub fn captureUnified(
        self: *Renderer,
        prepared: render_queue.PreparedQueue,
    ) !frame_capture.CapturedFrame {
        return self.state.captureUnified(prepared);
    }

    pub fn updateWindowTitle(self: *Renderer, unified: bool) !void {
        if (unified) {
            try self.state.updateUnifiedWindowTitle();
        } else {
            try self.state.updateWindowTitle();
        }
    }
};

const State = struct {
    allocator: std.mem.Allocator,
    batch: ?sprite.SpriteBatch = null,
    unified_queue: ?render_queue.UnifiedRenderQueue = null,
    mesh_catalog: ?mesh_gpu_catalog.Catalog = null,
    platform: PlatformWindow = .{},
    window_claimed: bool = false,
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

    pub fn init(
        allocator: std.mem.Allocator,
        hidden: bool,
        injector: ?fault_injection.Injector,
    ) !State {
        var self = State{ .allocator = allocator };
        errdefer self.deinit();

        self.batch = try sprite.SpriteBatch.init(allocator, sprite.initial_capacity, 1);
        try after(injector, .sprite_batch_cpu_allocation);

        if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_GAMEPAD)) return failSdl("SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)", error.SdlInitializationFailure);
        self.platform.sdl_initialized = true;
        try after(injector, .sdl_initialization);

        const window_flags: c.SDL_WindowFlags = if (hidden) c.SDL_WINDOW_HIDDEN else c.SDL_WINDOW_RESIZABLE;
        self.platform.window = c.SDL_CreateWindow("Authoritative SDL GPU sprite batch", target_width, target_height, window_flags);
        if (self.platform.window == null) return failSdl("SDL_CreateWindow", error.WindowCreationFailure);
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

        if (!c.SDL_ClaimWindowForGPUDevice(self.device.?, self.platform.window.?)) return failSdl("SDL_ClaimWindowForGPUDevice", error.WindowClaimFailure);
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
        const swapchain_format = c.SDL_GetGPUSwapchainTextureFormat(self.device.?, self.platform.window.?);
        if (swapchain_format == c.SDL_GPU_TEXTUREFORMAT_INVALID) {
            return failSdl("SDL_GetGPUSwapchainTextureFormat", error.SwapchainFormatQueryFailure);
        }
        self.window_pipeline = try createPipeline(self, swapchain_format);
        self.resource_metrics.gpu_resource_creations += 1;
        try after(injector, .pipeline_creation);
        return self;
    }

    pub fn deinit(self: *State) void {
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
            if (self.window_claimed and self.platform.window != null) c.SDL_ReleaseWindowFromGPUDevice(device, self.platform.window.?);
            c.SDL_DestroyGPUDevice(device);
        }
        if (self.platform.window) |window| c.SDL_DestroyWindow(window);
        if (self.platform.sdl_initialized) c.SDL_Quit();
        if (self.batch) |*batch| batch.deinit();
        self.batch = null;
        if (self.unified_queue) |*queue| queue.deinit();
        self.unified_queue = null;
        if (self.mesh_catalog) |*catalog| catalog.deinit();
        self.mesh_catalog = null;
    }

    fn initializeUnifiedQueue(self: *State) !void {
        try self.initializeUnifiedQueueWithCapacities(render_queue.default_entry_capacity, render_queue.default_sprite_capacity, render_queue.default_mesh_capacity);
    }

    fn initializeUnifiedQueueWithCapacities(self: *State, entries: usize, sprites: usize, meshes: usize) !void {
        if (self.unified_queue != null) return error.UnifiedQueueAlreadyInitialized;
        self.unified_queue = try render_queue.UnifiedRenderQueue.init(self.allocator, entries, sprites, meshes, self.texture_page_count);
    }

    fn initializeVisualCaptureTransfer(self: *State) !void {
        if (self.visual_capture_transfer != null) {
            return error.VisualCaptureTransferAlreadyInitialized;
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
            "SDL_CreateGPUTransferBuffer(persistent frame capture)",
            error.GpuTransferBufferCreationFailure,
        );
        self.resource_metrics.gpu_resource_creations += 1;
    }

    fn initializeMeshRendering(self: *State, definitions: []const mesh.DefinitionView) !void {
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
        const swapchain_format = c.SDL_GetGPUSwapchainTextureFormat(self.device.?, self.platform.window.?);
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

    fn initializeArtTexturePages(self: *State, definition: *const art_pack.Definition) !void {
        return self.initializeArtTexturePageSets(&.{definition});
    }

    fn initializeArtTexturePageSets(
        self: *State,
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

    fn runArtTextureFaultChecks(self: *State, definition: *const art_pack.Definition) !void {
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
        self: *State,
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

    fn textureBinding(self: *const State, texture_page: u32) !c.SDL_GPUTextureSamplerBinding {
        if (texture_page == 0) {
            return .{ .texture = self.sampled_texture.?, .sampler = self.sampler.? };
        }
        const index: usize = texture_page - 1;
        if (index >= self.art_texture_page_count) return error.InvalidTexturePage;
        const page = self.art_texture_pages[index] orelse return error.InvalidTexturePage;
        return .{ .texture = page.texture, .sampler = page.sampler };
    }

    fn handleWindowEvent(self: *State, event: *const c.SDL_Event) !void {
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

    fn refreshDrawableSize(self: *State) !void {
        var pixel_width: c_int = 0;
        var pixel_height: c_int = 0;
        if (!c.SDL_GetWindowSizeInPixels(self.platform.window.?, &pixel_width, &pixel_height)) {
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

    fn applyDrawableSize(self: *State, pixel_width: u32, pixel_height: u32) !void {
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

    pub fn runRuntimeFaultChecks(self: *State) !void {
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

    pub fn runSmoke(self: *State) !void {
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

    fn submitSmokeSprites(self: *State) !void {
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

    fn renderUnifiedToWindow(self: *State, prepared: render_queue.PreparedQueue) !bool {
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
        if (!c.SDL_WaitAndAcquireGPUSwapchainTexture(command, self.platform.window.?, &swapchain_texture, &swapchain_width, &swapchain_height)) {
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

    fn captureUnified(
        self: *State,
        prepared: render_queue.PreparedQueue,
    ) !frame_capture.CapturedFrame {
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
                "SDL_AcquireGPUCommandBuffer(frame capture)",
                error.PipelineResourceBindingFailure,
            );
        var command_active = true;
        errdefer if (command_active) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) {
                std.log.err(
                    "SDL_CancelGPUCommandBuffer(frame capture): {s}",
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
                "SDL_BeginGPUCopyPass(frame capture)",
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
                "SDL_SubmitGPUCommandBufferAndAcquireFence(frame capture)",
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
            "SDL_MapGPUTransferBuffer(frame capture)",
            error.ReadbackFailure,
        );
        defer c.SDL_UnmapGPUTransferBuffer(self.device.?, transfer);
        const padded_rgba: [*]const u8 = @ptrCast(mapped);
        const compact_row_bytes: usize = target_width * 4;
        const compact_bytes = try self.allocator.alloc(
            u8,
            compact_row_bytes * target_height,
        );
        errdefer self.allocator.free(compact_bytes);
        for (0..target_height) |y| {
            const source_start: usize = @intCast(y * row_pitch);
            const destination_start: usize = y * compact_row_bytes;
            @memcpy(
                compact_bytes[destination_start .. destination_start + compact_row_bytes],
                padded_rgba[source_start .. source_start + compact_row_bytes],
            );
        }
        return frame_capture.CapturedFrame.initOwned(
            self.allocator,
            target_width,
            target_height,
            compact_bytes,
        );
    }

    fn renderPreparedToWindow(self: *State, prepared: sprite.PreparedBatch, injector: ?fault_injection.Injector) !bool {
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
        if (!c.SDL_WaitAndAcquireGPUSwapchainTexture(command, self.platform.window.?, &swapchain_texture, &swapchain_width, &swapchain_height)) {
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

    fn renderPreparedForReadback(self: *State, prepared: sprite.PreparedBatch) !ReadbackPixels {
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
        self: *State,
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
        self: *State,
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

    fn populateInstanceTransfer(self: *State, slot_index: usize, submissions: []const sprite.SpriteSubmission) !void {
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
        self: *State,
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

    fn acquireFrameSlot(self: *State) !usize {
        const slot_index = self.current_frame_slot;
        try self.waitAndReleaseFence(&self.frame_slots[slot_index], true);
        return slot_index;
    }

    fn waitAndReleaseFence(self: *State, slot: *FrameSlot, count_slot_wait: bool) !void {
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

    fn waitReleaseStandaloneFence(self: *State, fence: *c.SDL_GPUFence) !void {
        const fences = [_]*c.SDL_GPUFence{fence};
        if (!c.SDL_WaitForGPUFences(self.device.?, true, &fences, 1)) {
            c.SDL_ReleaseGPUFence(self.device.?, fence);
            self.resource_metrics.fence_releases += 1;
            return failSdl("SDL_WaitForGPUFences(standalone)", error.FrameSlotSynchronizationFailure);
        }
        c.SDL_ReleaseGPUFence(self.device.?, fence);
        self.resource_metrics.fence_releases += 1;
    }

    fn ensureGpuCapacity(self: *State, required: usize, injector: ?fault_injection.Injector) !void {
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

    fn createSlotSet(self: *State, capacity: usize) ![frame_slot_count]FrameSlot {
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

    fn createMeshSlotResources(self: *State, capacity: usize) !void {
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

    fn releaseMeshSlotResources(self: *State) void {
        const device = self.device orelse return;
        for (&self.frame_slots) |*slot| {
            if (slot.mesh_transfer_buffer) |resource| self.releaseTransfer(device, resource);
            if (slot.mesh_instance_buffer) |resource| self.releaseBuffer(device, resource);
            slot.mesh_transfer_buffer = null;
            slot.mesh_instance_buffer = null;
        }
    }

    fn releaseSlotResources(self: *State, slots: *[frame_slot_count]FrameSlot) void {
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

    fn populateStaticUpload(self: *State) !void {
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

    fn submitStaticUpload(self: *State) !void {
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

    fn cleanupFailedCommand(self: *State, command: *c.SDL_GPUCommandBuffer, swapchain_acquired: bool) void {
        if (swapchain_acquired) {
            if (!c.SDL_SubmitGPUCommandBuffer(command)) std.log.err("SDL_SubmitGPUCommandBuffer(failed frame cleanup): {s}", .{sdlErrorText()});
            if (!c.SDL_WaitForGPUIdle(self.device.?)) std.log.err("SDL_WaitForGPUIdle(failed frame cleanup): {s}", .{sdlErrorText()});
        } else if (!c.SDL_CancelGPUCommandBuffer(command)) {
            std.log.err("SDL_CancelGPUCommandBuffer(failed frame): {s}", .{sdlErrorText()});
        }
    }

    fn updateWindowTitle(self: *State) !void {
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
        if (!c.SDL_SetWindowTitle(self.platform.window.?, title.ptr)) return failSdl("SDL_SetWindowTitle(metrics)", error.WindowTitleUpdateFailure);
    }

    fn updateUnifiedWindowTitle(self: *State) !void {
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
        if (!c.SDL_SetWindowTitle(self.platform.window.?, title.ptr)) {
            return failSdl("SDL_SetWindowTitle(unified metrics)", error.WindowTitleUpdateFailure);
        }
    }

    fn releaseBuffer(self: *State, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUBuffer) void {
        c.SDL_ReleaseGPUBuffer(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releaseTransfer(self: *State, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUTransferBuffer) void {
        c.SDL_ReleaseGPUTransferBuffer(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releaseTexture(self: *State, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUTexture) void {
        c.SDL_ReleaseGPUTexture(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releaseSampler(self: *State, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUSampler) void {
        c.SDL_ReleaseGPUSampler(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releaseShader(self: *State, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUShader) void {
        c.SDL_ReleaseGPUShader(device, resource);
        self.resource_metrics.gpu_resource_releases += 1;
    }

    fn releasePipeline(self: *State, device: *c.SDL_GPUDevice, resource: *c.SDL_GPUGraphicsPipeline) void {
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

fn createPipeline(self: State, target_format: c.SDL_GPUTextureFormat) !*c.SDL_GPUGraphicsPipeline {
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

fn createMeshPipeline(self: *const State, target_format: c.SDL_GPUTextureFormat) !*c.SDL_GPUGraphicsPipeline {
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

fn stateResourceSnapshot(self: *const State, cpu_allocation_bytes: usize, created_this_frame: u64) diagnostics.ResourceSnapshot {
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

fn sdlErrorText() []const u8 {
    const pointer = c.SDL_GetError();
    if (pointer == null) return "no SDL diagnostic";
    return std.mem.span(@as([*:0]const u8, @ptrCast(pointer)));
}

fn failSdl(operation: []const u8, result: anyerror) @TypeOf(result) {
    std.log.err("{s}: {s}", .{ operation, sdlErrorText() });
    return result;
}

// CPU queue initialization uses the public renderer entry points against an
// unstarted State. These tests require no window, GPU or SDL initialization.
test "renderer queue defaults remain unchanged and both entry points reject reinitialization" {
    var state = State{ .allocator = std.testing.allocator };
    var renderer = Renderer{ .state = &state };
    try renderer.initializeUnifiedQueue();
    defer state.unified_queue.?.deinit();
    const queue = renderer.renderQueue();
    try std.testing.expectEqual(render_queue.default_entry_capacity, queue.entries.len);
    try std.testing.expectEqual(render_queue.default_sprite_capacity, queue.sprite_submissions.len);
    try std.testing.expectEqual(render_queue.default_mesh_capacity, queue.mesh_submissions.len);
    const allocation = queue.entries.ptr;
    try std.testing.expectError(error.UnifiedQueueAlreadyInitialized, renderer.initializeUnifiedQueue());
    try std.testing.expectError(error.UnifiedQueueAlreadyInitialized, renderer.initializeUnifiedQueueWithCapacities(1, 1, 1));
    try std.testing.expect(allocation == renderer.renderQueue().entries.ptr);
}

test "renderer custom queue capacities delegate validation before publication" {
    var state = State{ .allocator = std.testing.allocator, .texture_page_count = 2 };
    var renderer = Renderer{ .state = &state };
    for ([_][3]usize{ .{ 0, 1, 1 }, .{ 8, 9, 1 }, .{ 8, 1, 1 }, .{ 8, 8, 0 }, .{ 8, 8, 9 } }) |invalid| {
        try std.testing.expectError(error.InvalidRenderQueueCapacity, renderer.initializeUnifiedQueueWithCapacities(invalid[0], invalid[1], invalid[2]));
        try std.testing.expect(renderer.renderQueueOptional() == null);
    }
    state.texture_page_count = 0;
    try std.testing.expectError(error.InvalidTexturePageCount, renderer.initializeUnifiedQueueWithCapacities(24, 20, 8));
    try std.testing.expect(renderer.renderQueueOptional() == null);
    state.texture_page_count = 2;
    try renderer.initializeUnifiedQueueWithCapacities(24, 20, 8);
    defer state.unified_queue.?.deinit();
    try std.testing.expectEqual(@as(usize, 24), renderer.renderQueue().entries.len);
    try std.testing.expectEqual(@as(usize, 20), renderer.renderQueue().sprite_submissions.len);
    try std.testing.expectEqual(@as(usize, 8), renderer.renderQueue().mesh_submissions.len);
    try std.testing.expectEqual(@as(u32, 2), renderer.renderQueue().texture_page_count);
}

test "renderer queue allocation failures free every prefix and permit a later initialization" {
    // The queue owns eight allocations. Exercise each partial initialization,
    // including both default and explicit paths, with the existing allocator.
    for ([_]bool{ false, true }) |custom| for (0..8) |failure| {
        var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        var state = State{ .allocator = tracking.allocator() };
        var renderer = Renderer{ .state = &state };
        const result = if (custom) renderer.initializeUnifiedQueueWithCapacities(24, 20, 8) else renderer.initializeUnifiedQueue();
        try std.testing.expectError(error.CpuAllocationFailure, result);
        try std.testing.expect(renderer.renderQueueOptional() == null);
        try std.testing.expectEqual(tracking.allocated_bytes, tracking.freed_bytes);
        tracking.fail_index = std.math.maxInt(usize);
        try renderer.initializeUnifiedQueueWithCapacities(24, 20, 8);
        state.unified_queue.?.deinit();
        state.unified_queue = null;
        try std.testing.expectEqual(tracking.allocated_bytes, tracking.freed_bytes);
    };
}
