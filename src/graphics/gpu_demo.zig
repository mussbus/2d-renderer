const std = @import("std");
const c = @import("../platform/sdl.zig").c;
const fault_injection = @import("../platform/fault_injection.zig");

const target_width: u32 = 640;
const target_height: u32 = 480;
const texture_width: u32 = 4;
const texture_height: u32 = 4;
const upload_texture_row_pitch: u32 = 256;
const texture_upload_size: u32 = upload_texture_row_pitch * texture_height;
const clear_color = c.SDL_FColor{ .r = 0.05, .g = 0.10, .b = 0.20, .a = 1.0 };

const Vertex = extern struct {
    position: [2]f32,
    uv: [2]f32,
};

const Instance = extern struct {
    offset: [2]f32,
    scale: [2]f32,
    tint: [4]f32,
};

const vertices = [_]Vertex{
    .{ .position = .{ -1.0, -1.0 }, .uv = .{ 0.0, 1.0 } },
    .{ .position = .{ 1.0, -1.0 }, .uv = .{ 1.0, 1.0 } },
    .{ .position = .{ 1.0, 1.0 }, .uv = .{ 1.0, 0.0 } },
    .{ .position = .{ -1.0, 1.0 }, .uv = .{ 0.0, 0.0 } },
};

const indices = [_]u16{ 0, 1, 2, 0, 2, 3 };

const instances = [_]Instance{
    .{ .offset = .{ 0.0, 0.0 }, .scale = .{ 0.60, 0.60 }, .tint = .{ 1.0, 1.0, 1.0, 1.0 } },
    .{ .offset = .{ 0.72, -0.72 }, .scale = .{ 0.18, 0.18 }, .tint = .{ 0.70, 0.85, 1.0, 1.0 } },
};

const texture_pixels = [_][4]u8{
    .{ 255, 0, 0, 255 }, .{ 255, 0, 0, 255 }, .{ 0, 255, 0, 255 },   .{ 0, 255, 0, 255 },
    .{ 255, 0, 0, 255 }, .{ 255, 0, 0, 255 }, .{ 0, 255, 0, 255 },   .{ 0, 255, 0, 255 },
    .{ 0, 0, 255, 255 }, .{ 0, 0, 255, 255 }, .{ 255, 255, 0, 255 }, .{ 255, 255, 0, 255 },
    .{ 0, 0, 255, 255 }, .{ 0, 0, 255, 255 }, .{ 255, 255, 0, 255 }, .{ 255, 255, 0, 255 },
};

const vertex_upload_offset: u32 = texture_upload_size;
const index_upload_offset: u32 = vertex_upload_offset + @sizeOf(@TypeOf(vertices));
const instance_upload_offset: u32 = std.mem.alignForward(u32, index_upload_offset + @sizeOf(@TypeOf(indices)), 16);
const upload_buffer_size: u32 = instance_upload_offset + @sizeOf(@TypeOf(instances));

pub const GpuDemo = struct {
    sdl_initialized: bool = false,
    window_claimed: bool = false,
    window: ?*c.SDL_Window = null,
    device: ?*c.SDL_GPUDevice = null,
    vertex_shader: ?*c.SDL_GPUShader = null,
    fragment_shader: ?*c.SDL_GPUShader = null,
    sampler: ?*c.SDL_GPUSampler = null,
    sampled_texture: ?*c.SDL_GPUTexture = null,
    render_target: ?*c.SDL_GPUTexture = null,
    vertex_buffer: ?*c.SDL_GPUBuffer = null,
    index_buffer: ?*c.SDL_GPUBuffer = null,
    instance_buffer: ?*c.SDL_GPUBuffer = null,
    upload_transfer_buffer: ?*c.SDL_GPUTransferBuffer = null,
    pipeline: ?*c.SDL_GPUGraphicsPipeline = null,

    pub fn init(hidden: bool, injector: ?fault_injection.Injector) !GpuDemo {
        var self = GpuDemo{};
        errdefer self.deinit();

        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return fail("SDL_Init(SDL_INIT_VIDEO)");
        self.sdl_initialized = true;
        try after(injector, .sdl_initialization);

        const window_flags: c.SDL_WindowFlags = if (hidden) c.SDL_WINDOW_HIDDEN else 0;
        self.window = c.SDL_CreateWindow("Pinned SDL GPU D3D12/DXIL demo", target_width, target_height, window_flags);
        if (self.window == null) return fail("SDL_CreateWindow");
        try after(injector, .window_creation);

        const driver_count = c.SDL_GetNumGPUDrivers();
        if (driver_count < 0) return fail("SDL_GetNumGPUDrivers");
        var driver_index: c_int = 0;
        while (driver_index < driver_count) : (driver_index += 1) {
            const available_driver = c.SDL_GetGPUDriver(driver_index);
            if (available_driver != null) {
                std.log.info("available SDL GPU driver: {s}", .{std.mem.span(@as([*:0]const u8, @ptrCast(available_driver)))});
            }
        }
        if (!c.SDL_GPUSupportsShaderFormats(c.SDL_GPU_SHADERFORMAT_DXIL, "direct3d12")) {
            std.log.err("SDL reports that direct3d12 cannot consume the repository-generated DXIL format", .{});
            return error.ShaderFormatMismatch;
        }

        const properties = c.SDL_CreateProperties();
        if (properties == 0) return fail("SDL_CreateProperties for GPU device");
        defer c.SDL_DestroyProperties(properties);
        if (!c.SDL_SetBooleanProperty(properties, c.SDL_PROP_GPU_DEVICE_CREATE_DEBUGMODE_BOOLEAN, true) or
            !c.SDL_SetBooleanProperty(properties, c.SDL_PROP_GPU_DEVICE_CREATE_VERBOSE_BOOLEAN, true) or
            !c.SDL_SetStringProperty(properties, c.SDL_PROP_GPU_DEVICE_CREATE_NAME_STRING, "direct3d12") or
            !c.SDL_SetBooleanProperty(properties, c.SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXIL_BOOLEAN, true))
        {
            return fail("configure D3D12/DXIL-only GPU device properties");
        }

        self.device = c.SDL_CreateGPUDeviceWithProperties(properties);
        if (self.device == null) return fail("SDL_CreateGPUDeviceWithProperties(direct3d12, DXIL)");
        const actual_driver = c.SDL_GetGPUDeviceDriver(self.device.?);
        if (actual_driver == null) return fail("SDL_GetGPUDeviceDriver");
        const driver_name = std.mem.span(@as([*:0]const u8, @ptrCast(actual_driver)));
        std.log.info("actual SDL GPU driver: {s}", .{driver_name});
        if (!std.mem.eql(u8, driver_name, "direct3d12")) {
            std.log.err("required SDL GPU driver direct3d12, received {s}; no fallback is permitted", .{driver_name});
            return error.WrongGpuDriver;
        }
        const shader_formats = c.SDL_GetGPUShaderFormats(self.device.?);
        if ((shader_formats & c.SDL_GPU_SHADERFORMAT_DXIL) == 0) {
            std.log.err("SDL GPU device does not report DXIL support; generated shaders are DXIL and no fallback is permitted", .{});
            return error.ShaderFormatMismatch;
        }
        std.log.info("generated shader format DXIL agrees with SDL_GPU_SHADERFORMAT_DXIL", .{});
        try after(injector, .gpu_device_creation);

        if (!c.SDL_ClaimWindowForGPUDevice(self.device.?, self.window.?)) return fail("SDL_ClaimWindowForGPUDevice");
        self.window_claimed = true;
        try after(injector, .window_claim);

        self.vertex_shader = try createShader(self.device.?, "shaders\\sprite_vs.dxil", "VSMain", c.SDL_GPU_SHADERSTAGE_VERTEX, 0);
        self.fragment_shader = try createShader(self.device.?, "shaders\\sprite_ps.dxil", "PSMain", c.SDL_GPU_SHADERSTAGE_FRAGMENT, 1);
        try after(injector, .shader_creation);

        var sampler_info: c.SDL_GPUSamplerCreateInfo = std.mem.zeroes(c.SDL_GPUSamplerCreateInfo);
        sampler_info.min_filter = c.SDL_GPU_FILTER_NEAREST;
        sampler_info.mag_filter = c.SDL_GPU_FILTER_NEAREST;
        sampler_info.mipmap_mode = c.SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
        sampler_info.address_mode_u = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        sampler_info.address_mode_v = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        sampler_info.address_mode_w = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        self.sampler = c.SDL_CreateGPUSampler(self.device.?, &sampler_info);
        if (self.sampler == null) return fail("SDL_CreateGPUSampler");
        try after(injector, .sampler_creation);

        const render_target_usage = c.SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | c.SDL_GPU_TEXTUREUSAGE_SAMPLER;
        if (!c.SDL_GPUTextureSupportsFormat(self.device.?, c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM, c.SDL_GPU_TEXTURETYPE_2D, c.SDL_GPU_TEXTUREUSAGE_SAMPLER) or
            !c.SDL_GPUTextureSupportsFormat(self.device.?, c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM, c.SDL_GPU_TEXTURETYPE_2D, render_target_usage))
        {
            std.log.err("required R8G8B8A8_UNORM sampler/color-target support is unavailable", .{});
            return error.UnsupportedTextureFormat;
        }
        self.sampled_texture = createTexture(self.device.?, c.SDL_GPU_TEXTUREUSAGE_SAMPLER, texture_width, texture_height) orelse return fail("SDL_CreateGPUTexture(sampled procedural texture)");
        self.render_target = createTexture(self.device.?, render_target_usage, target_width, target_height) orelse return fail("SDL_CreateGPUTexture(offscreen color target)");
        self.vertex_buffer = createBuffer(self.device.?, c.SDL_GPU_BUFFERUSAGE_VERTEX, @sizeOf(@TypeOf(vertices))) orelse return fail("SDL_CreateGPUBuffer(vertex)");
        self.index_buffer = createBuffer(self.device.?, c.SDL_GPU_BUFFERUSAGE_INDEX, @sizeOf(@TypeOf(indices))) orelse return fail("SDL_CreateGPUBuffer(index)");
        self.instance_buffer = createBuffer(self.device.?, c.SDL_GPU_BUFFERUSAGE_VERTEX, @sizeOf(@TypeOf(instances))) orelse return fail("SDL_CreateGPUBuffer(instance)");
        try after(injector, .texture_creation);

        var transfer_info: c.SDL_GPUTransferBufferCreateInfo = std.mem.zeroes(c.SDL_GPUTransferBufferCreateInfo);
        transfer_info.usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
        transfer_info.size = upload_buffer_size;
        self.upload_transfer_buffer = c.SDL_CreateGPUTransferBuffer(self.device.?, &transfer_info);
        if (self.upload_transfer_buffer == null) return fail("SDL_CreateGPUTransferBuffer(upload)");
        try after(injector, .transfer_buffer_creation);

        try self.populateUploadTransferBuffer();
        try self.submitUpload();
        try after(injector, .upload);

        self.pipeline = try createPipeline(self);
        try after(injector, .pipeline_creation);
        return self;
    }

    pub fn deinit(self: *GpuDemo) void {
        if (self.device) |device| {
            if (!c.SDL_WaitForGPUIdle(device)) {
                std.log.err("SDL_WaitForGPUIdle during cleanup: {s}", .{sdlErrorText()});
            }
            if (self.pipeline) |resource| c.SDL_ReleaseGPUGraphicsPipeline(device, resource);
            if (self.upload_transfer_buffer) |resource| c.SDL_ReleaseGPUTransferBuffer(device, resource);
            if (self.instance_buffer) |resource| c.SDL_ReleaseGPUBuffer(device, resource);
            if (self.index_buffer) |resource| c.SDL_ReleaseGPUBuffer(device, resource);
            if (self.vertex_buffer) |resource| c.SDL_ReleaseGPUBuffer(device, resource);
            if (self.render_target) |resource| c.SDL_ReleaseGPUTexture(device, resource);
            if (self.sampled_texture) |resource| c.SDL_ReleaseGPUTexture(device, resource);
            if (self.sampler) |resource| c.SDL_ReleaseGPUSampler(device, resource);
            if (self.fragment_shader) |resource| c.SDL_ReleaseGPUShader(device, resource);
            if (self.vertex_shader) |resource| c.SDL_ReleaseGPUShader(device, resource);
            if (self.window_claimed and self.window != null) c.SDL_ReleaseWindowFromGPUDevice(device, self.window.?);
            c.SDL_DestroyGPUDevice(device);
        }
        if (self.window) |window| c.SDL_DestroyWindow(window);
        if (self.sdl_initialized) c.SDL_Quit();
        self.* = .{};
    }

    pub fn runVisible(self: *GpuDemo, maximum_frames: ?u32) !void {
        var frame: u32 = 0;
        var running = true;
        while (running and (maximum_frames == null or frame < maximum_frames.?)) : (frame += 1) {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event)) {
                if (event.type == c.SDL_EVENT_QUIT or event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) running = false;
            }
            if (!running) break;
            _ = try self.renderVisibleFrame();
        }
    }

    pub fn runSmoke(self: *GpuDemo) !void {
        for (0..3) |_| {
            if (!try self.renderVisibleFrame()) {
                std.log.err("GPU smoke could not acquire a swapchain texture; presentation is required and is not treated as a skip", .{});
                return error.SwapchainUnavailable;
            }
        }

        const device = self.device.?;
        const row_pitch = alignForward(target_width * 4, 256);
        const readback_size = row_pitch * target_height;
        std.log.info("GPU readback format=R8G8B8A8_UNORM width={d} height={d} row_pitch={d} (SDL pixels_per_row={d}); rows are not assumed tightly packed", .{
            target_width, target_height, row_pitch, row_pitch / 4,
        });
        if (c.SDL_GPUTextureFormatTexelBlockSize(c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM) != 4) {
            return error.UnexpectedTexelBlockSize;
        }

        var transfer_info: c.SDL_GPUTransferBufferCreateInfo = std.mem.zeroes(c.SDL_GPUTransferBufferCreateInfo);
        transfer_info.usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD;
        transfer_info.size = readback_size;
        const download = c.SDL_CreateGPUTransferBuffer(device, &transfer_info) orelse return fail("SDL_CreateGPUTransferBuffer(download)");
        defer c.SDL_ReleaseGPUTransferBuffer(device, download);

        const command = c.SDL_AcquireGPUCommandBuffer(device) orelse return fail("SDL_AcquireGPUCommandBuffer(smoke)");
        var command_active = true;
        errdefer if (command_active) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) std.log.err("SDL_CancelGPUCommandBuffer(smoke): {s}", .{sdlErrorText()});
        };
        try self.encodeDraw(command, self.render_target.?);

        const copy_pass = c.SDL_BeginGPUCopyPass(command);
        if (copy_pass == null) return fail("SDL_BeginGPUCopyPass(readback)");
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
        if (fence == null) return fail("SDL_SubmitGPUCommandBufferAndAcquireFence(smoke)");
        defer c.SDL_ReleaseGPUFence(device, fence.?);
        const fences = [_]*c.SDL_GPUFence{fence.?};
        if (!c.SDL_WaitForGPUFences(device, true, &fences, 1)) return fail("SDL_WaitForGPUFences(smoke readback)");

        const mapped = c.SDL_MapGPUTransferBuffer(device, download, false) orelse return fail("SDL_MapGPUTransferBuffer(download after fence)");
        defer c.SDL_UnmapGPUTransferBuffer(device, download);
        const bytes: [*]const u8 = @ptrCast(mapped);
        const outside = readPixel(bytes, row_pitch, 20, 20);
        const inside_a = readPixel(bytes, row_pitch, 200, 140);
        const inside_b = readPixel(bytes, row_pitch, 440, 340);
        const expected_clear = [4]u8{ 13, 26, 51, 255 };
        if (!colorNear(outside, expected_clear, 1)) {
            std.log.err("outside pixel expected clear RGBA {any}, got {any}", .{ expected_clear, outside });
            return error.SmokeOutsidePixelMismatch;
        }
        if (!isProceduralColor(inside_a) or !isProceduralColor(inside_b) or std.mem.eql(u8, &inside_a, &inside_b)) {
            std.log.err("interior pixels did not prove distinct procedural texture samples: A={any}, B={any}", .{ inside_a, inside_b });
            return error.SmokeInteriorPixelMismatch;
        }
        std.log.info("GPU smoke passed: outside={any}, interior A={any}, interior B={any}; indexed draw used {d} instances", .{
            outside, inside_a, inside_b, instances.len,
        });
    }

    fn populateUploadTransferBuffer(self: *GpuDemo) !void {
        const mapped = c.SDL_MapGPUTransferBuffer(self.device.?, self.upload_transfer_buffer.?, false) orelse return fail("SDL_MapGPUTransferBuffer(upload)");
        defer c.SDL_UnmapGPUTransferBuffer(self.device.?, self.upload_transfer_buffer.?);
        const bytes: [*]u8 = @ptrCast(mapped);

        for (0..texture_height) |y| {
            const source_start = y * texture_width;
            const source_bytes = std.mem.sliceAsBytes(texture_pixels[source_start .. source_start + texture_width]);
            const destination_start = y * upload_texture_row_pitch;
            @memcpy(bytes[destination_start .. destination_start + source_bytes.len], source_bytes);
        }
        copyBytes(bytes, vertex_upload_offset, std.mem.asBytes(&vertices));
        copyBytes(bytes, index_upload_offset, std.mem.asBytes(&indices));
        copyBytes(bytes, instance_upload_offset, std.mem.asBytes(&instances));
    }

    fn submitUpload(self: *GpuDemo) !void {
        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse return fail("SDL_AcquireGPUCommandBuffer(upload)");
        var command_active = true;
        errdefer if (command_active) {
            if (!c.SDL_CancelGPUCommandBuffer(command)) std.log.err("SDL_CancelGPUCommandBuffer(upload): {s}", .{sdlErrorText()});
        };
        const copy_pass = c.SDL_BeginGPUCopyPass(command);
        if (copy_pass == null) return fail("SDL_BeginGPUCopyPass(upload)");

        const texture_source = c.SDL_GPUTextureTransferInfo{
            .transfer_buffer = self.upload_transfer_buffer.?,
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
        uploadBuffer(copy_pass.?, self.upload_transfer_buffer.?, vertex_upload_offset, self.vertex_buffer.?, @sizeOf(@TypeOf(vertices)));
        uploadBuffer(copy_pass.?, self.upload_transfer_buffer.?, index_upload_offset, self.index_buffer.?, @sizeOf(@TypeOf(indices)));
        uploadBuffer(copy_pass.?, self.upload_transfer_buffer.?, instance_upload_offset, self.instance_buffer.?, @sizeOf(@TypeOf(instances)));
        c.SDL_EndGPUCopyPass(copy_pass.?);

        const fence = c.SDL_SubmitGPUCommandBufferAndAcquireFence(command);
        command_active = false;
        if (fence == null) return fail("SDL_SubmitGPUCommandBufferAndAcquireFence(upload)");
        defer c.SDL_ReleaseGPUFence(self.device.?, fence.?);
        const fences = [_]*c.SDL_GPUFence{fence.?};
        if (!c.SDL_WaitForGPUFences(self.device.?, true, &fences, 1)) return fail("SDL_WaitForGPUFences(upload)");
    }

    fn encodeDraw(self: *GpuDemo, command: *c.SDL_GPUCommandBuffer, target: *c.SDL_GPUTexture) !void {
        var target_info: c.SDL_GPUColorTargetInfo = std.mem.zeroes(c.SDL_GPUColorTargetInfo);
        target_info.texture = target;
        target_info.clear_color = clear_color;
        target_info.load_op = c.SDL_GPU_LOADOP_CLEAR;
        target_info.store_op = c.SDL_GPU_STOREOP_STORE;
        const render_pass = c.SDL_BeginGPURenderPass(command, &target_info, 1, null);
        if (render_pass == null) return fail("SDL_BeginGPURenderPass");
        c.SDL_BindGPUGraphicsPipeline(render_pass.?, self.pipeline.?);
        const vertex_bindings = [_]c.SDL_GPUBufferBinding{
            .{ .buffer = self.vertex_buffer.?, .offset = 0 },
            .{ .buffer = self.instance_buffer.?, .offset = 0 },
        };
        c.SDL_BindGPUVertexBuffers(render_pass.?, 0, &vertex_bindings, vertex_bindings.len);
        const index_binding = c.SDL_GPUBufferBinding{ .buffer = self.index_buffer.?, .offset = 0 };
        c.SDL_BindGPUIndexBuffer(render_pass.?, &index_binding, c.SDL_GPU_INDEXELEMENTSIZE_16BIT);
        const texture_binding = c.SDL_GPUTextureSamplerBinding{ .texture = self.sampled_texture.?, .sampler = self.sampler.? };
        c.SDL_BindGPUFragmentSamplers(render_pass.?, 0, &texture_binding, 1);
        c.SDL_DrawGPUIndexedPrimitives(render_pass.?, indices.len, instances.len, 0, 0, 0);
        c.SDL_EndGPURenderPass(render_pass.?);
    }

    fn renderVisibleFrame(self: *GpuDemo) !bool {
        const command = c.SDL_AcquireGPUCommandBuffer(self.device.?) orelse return fail("SDL_AcquireGPUCommandBuffer(frame)");
        var command_active = true;
        var swapchain_acquired = false;
        errdefer if (command_active) {
            if (swapchain_acquired) {
                if (!c.SDL_SubmitGPUCommandBuffer(command)) std.log.err("SDL_SubmitGPUCommandBuffer(failed frame cleanup): {s}", .{sdlErrorText()});
            } else {
                if (!c.SDL_CancelGPUCommandBuffer(command)) std.log.err("SDL_CancelGPUCommandBuffer(frame): {s}", .{sdlErrorText()});
            }
        };
        var swapchain_texture: ?*c.SDL_GPUTexture = null;
        var width: u32 = 0;
        var height: u32 = 0;
        if (!c.SDL_WaitAndAcquireGPUSwapchainTexture(command, self.window.?, &swapchain_texture, &width, &height)) {
            return fail("SDL_WaitAndAcquireGPUSwapchainTexture");
        }
        if (swapchain_texture == null) {
            if (!c.SDL_SubmitGPUCommandBuffer(command)) {
                command_active = false;
                return fail("SDL_SubmitGPUCommandBuffer(empty frame)");
            }
            command_active = false;
            return false;
        }
        swapchain_acquired = true;
        try self.encodeDraw(command, self.render_target.?);
        var blit_info: c.SDL_GPUBlitInfo = std.mem.zeroes(c.SDL_GPUBlitInfo);
        blit_info.source = .{ .texture = self.render_target.?, .mip_level = 0, .layer_or_depth_plane = 0, .x = 0, .y = 0, .w = target_width, .h = target_height };
        blit_info.destination = .{ .texture = swapchain_texture.?, .mip_level = 0, .layer_or_depth_plane = 0, .x = 0, .y = 0, .w = width, .h = height };
        blit_info.load_op = c.SDL_GPU_LOADOP_DONT_CARE;
        blit_info.filter = c.SDL_GPU_FILTER_LINEAR;
        c.SDL_BlitGPUTexture(command, &blit_info);
        const submitted = c.SDL_SubmitGPUCommandBuffer(command);
        command_active = false;
        if (!submitted) return fail("SDL_SubmitGPUCommandBuffer(frame)");
        return true;
    }
};

fn createShader(device: *c.SDL_GPUDevice, relative_path: []const u8, entry_point: [*:0]const u8, stage: c.SDL_GPUShaderStage, num_samplers: u32) !*c.SDL_GPUShader {
    const base_path_pointer = c.SDL_GetBasePath();
    if (base_path_pointer == null) return fail("SDL_GetBasePath(shader)");
    const base_path = std.mem.span(@as([*:0]const u8, @ptrCast(base_path_pointer)));
    var path_buffer: [4096]u8 = undefined;
    const path = std.fmt.bufPrintZ(&path_buffer, "{s}{s}", .{ base_path, relative_path }) catch return error.ShaderPathTooLong;
    var code_size: usize = 0;
    const code = c.SDL_LoadFile(path.ptr, &code_size);
    if (code == null) return fail("SDL_LoadFile(DXIL shader)");
    defer c.SDL_free(code);
    var create_info: c.SDL_GPUShaderCreateInfo = std.mem.zeroes(c.SDL_GPUShaderCreateInfo);
    create_info.code_size = code_size;
    create_info.code = @ptrCast(code);
    create_info.entrypoint = entry_point;
    create_info.format = c.SDL_GPU_SHADERFORMAT_DXIL;
    create_info.stage = stage;
    create_info.num_samplers = num_samplers;
    return c.SDL_CreateGPUShader(device, &create_info) orelse fail("SDL_CreateGPUShader(DXIL)");
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
        .{ .slot = 0, .pitch = @sizeOf(Vertex), .input_rate = c.SDL_GPU_VERTEXINPUTRATE_VERTEX, .instance_step_rate = 0 },
        .{ .slot = 1, .pitch = @sizeOf(Instance), .input_rate = c.SDL_GPU_VERTEXINPUTRATE_INSTANCE, .instance_step_rate = 0 },
    };
    const attributes = [_]c.SDL_GPUVertexAttribute{
        .{ .location = 0, .buffer_slot = 0, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(Vertex, "position") },
        .{ .location = 1, .buffer_slot = 0, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(Vertex, "uv") },
        .{ .location = 2, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(Instance, "offset") },
        .{ .location = 3, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(Instance, "scale") },
        .{ .location = 4, .buffer_slot = 1, .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, .offset = @offsetOf(Instance, "tint") },
    };
    var color_target: c.SDL_GPUColorTargetDescription = std.mem.zeroes(c.SDL_GPUColorTargetDescription);
    color_target.format = c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
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
    return c.SDL_CreateGPUGraphicsPipeline(self.device.?, &info) orelse fail("SDL_CreateGPUGraphicsPipeline(DXIL textured quad)");
}

fn uploadBuffer(copy_pass: *c.SDL_GPUCopyPass, transfer: *c.SDL_GPUTransferBuffer, source_offset: u32, destination_buffer: *c.SDL_GPUBuffer, size: u32) void {
    const source = c.SDL_GPUTransferBufferLocation{ .transfer_buffer = transfer, .offset = source_offset };
    const destination = c.SDL_GPUBufferRegion{ .buffer = destination_buffer, .offset = 0, .size = size };
    c.SDL_UploadToGPUBuffer(copy_pass, &source, &destination, false);
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}

fn copyBytes(destination: [*]u8, offset: u32, source: []const u8) void {
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

fn isProceduralColor(color: [4]u8) bool {
    for ([_][4]u8{
        .{ 255, 0, 0, 255 }, .{ 0, 255, 0, 255 }, .{ 0, 0, 255, 255 }, .{ 255, 255, 0, 255 },
    }) |expected| {
        if (colorNear(color, expected, 1)) return true;
    }
    return false;
}

fn sdlErrorText() []const u8 {
    const pointer = c.SDL_GetError();
    if (pointer == null) return "no SDL diagnostic";
    return std.mem.span(@as([*:0]const u8, @ptrCast(pointer)));
}

fn fail(operation: []const u8) error{SdlFailure} {
    std.log.err("{s}: {s}", .{ operation, sdlErrorText() });
    return error.SdlFailure;
}
