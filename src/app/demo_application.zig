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

const sdl_gpu_renderer = @import("sdl_gpu_renderer");
const capture_writer = @import("capture_writer");

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
const demonstration_sprite_count: usize = 1000;
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

const CapturePixelEvidence = capture_writer.PixelEvidence;

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
        if (record.character_id != scene.female.id().raw() or
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
    const anatomy_runtime = scene.female.humanoidView().anatomy_runtime orelse
        return error.AnatomyEvidenceRuntimeMissing;
    return .{
        .render_frame = render_frame,
        .simulation_tick = scene.simulation_tick,
        .stage = scene.anatomy_evidence_stage,
        .stage_frame = scene.anatomy_stage_frame,
        .view = resolved_view orelse return error.AnatomyEvidenceViewMissing,
        .facing = if (scene.female.facingDirection() == .left) .left else .right,
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

pub const DemoApplication = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    renderer: sdl_gpu_renderer.Renderer,
    visual_captures_written: u32 = 0,
    manual_capture_next_index: u64 = 0,
    manual_captures_written: u64 = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        hidden: bool,
        injector: ?fault_injection.Injector,
    ) !DemoApplication {
        return .{
            .allocator = allocator,
            .io = io,
            .renderer = try sdl_gpu_renderer.Renderer.init(
                allocator,
                hidden,
                injector,
            ),
        };
    }

    pub fn deinit(self: *DemoApplication) void {
        self.renderer.deinit();
    }

    pub fn runRuntimeFaultChecks(self: *DemoApplication) !void {
        try self.renderer.runRuntimeFaultChecks();
    }

    pub fn runSmoke(self: *DemoApplication) !void {
        try self.renderer.runSmoke();
    }

    fn initializeUnifiedQueue(self: *DemoApplication) !void {
        try self.renderer.initializeUnifiedQueue();
    }

    fn ensureGpuCapacity(
        self: *DemoApplication,
        required: usize,
        injector: ?fault_injection.Injector,
    ) !void {
        try self.renderer.ensureGpuCapacity(required, injector);
    }

    fn initializeMeshRendering(
        self: *DemoApplication,
        definitions: []const mesh.DefinitionView,
    ) !void {
        try self.renderer.initializeMeshRendering(definitions);
    }

    fn initializeArtTexturePages(
        self: *DemoApplication,
        definition: *const art_pack.Definition,
    ) !void {
        try self.renderer.initializeArtTexturePages(definition);
    }

    fn initializeArtTexturePageSets(
        self: *DemoApplication,
        definitions: []const *const art_pack.Definition,
    ) !void {
        try self.renderer.initializeArtTexturePageSets(definitions);
    }

    fn runArtTextureFaultChecks(
        self: *DemoApplication,
        definition: *const art_pack.Definition,
    ) !void {
        try self.renderer.runArtTextureFaultChecks(definition);
    }

    fn initializeVisualCaptureTransfer(
        self: *DemoApplication,
        geometry_debug: bool,
    ) !void {
        try std.Io.Dir.cwd().createDirPath(self.io, visual_capture_directory);
        try std.Io.Dir.cwd().createDirPath(self.io, environment_capture_directory);
        try std.Io.Dir.cwd().createDirPath(self.io, foundation_capture_directory);
        try std.Io.Dir.cwd().createDirPath(self.io, p27b_capture_directory);
        try std.Io.Dir.cwd().createDirPath(self.io, manual_capture_directory);
        if (geometry_debug) {
            try std.Io.Dir.cwd().createDirPath(
                self.io,
                geometry_debug_capture_directory,
            );
        }
        try self.renderer.initializeCapture();
    }

    fn handleWindowEvent(
        self: *DemoApplication,
        event: *const c.SDL_Event,
    ) !void {
        try self.renderer.handleWindowEvent(event);
    }

    fn renderUnifiedToWindow(
        self: *DemoApplication,
        prepared: render_queue.PreparedQueue,
    ) !bool {
        return self.renderer.renderUnifiedToWindow(prepared);
    }

    fn renderPreparedToWindow(
        self: *DemoApplication,
        prepared: sprite.PreparedBatch,
        injector: ?fault_injection.Injector,
    ) !bool {
        return self.renderer.renderPreparedToWindow(prepared, injector);
    }

    fn updateWindowTitle(self: *DemoApplication) !void {
        try self.renderer.updateWindowTitle(false);
    }

    fn updateUnifiedWindowTitle(self: *DemoApplication) !void {
        try self.renderer.updateWindowTitle(true);
    }

    fn captureUnifiedToPpm(
        self: *DemoApplication,
        prepared: render_queue.PreparedQueue,
        path: []const u8,
    ) !CapturePixelEvidence {
        var capture = try self.renderer.captureUnified(prepared);
        defer capture.deinit();
        const evidence = try capture_writer.writePpm(self.io, path, &capture);
        self.visual_captures_written += 1;
        return evidence;
    }

    fn captureUnifiedToPng(
        self: *DemoApplication,
        prepared: render_queue.PreparedQueue,
        path: []const u8,
    ) !void {
        var capture = try self.renderer.captureUnified(prepared);
        defer capture.deinit();
        try capture_writer.writePng(self.io, path, &capture);
    }

    fn submitDemonstrationSprites(self: *DemoApplication, frame: u32) !void {
        var batch = self.renderer.spriteBatch();
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

    pub fn runVisible(
        self: *DemoApplication,
        maximum_frames: ?u32,
        mode: DemoMode,
        scripted_input_enabled: bool,
        integrated_debug_enabled: bool,
        interactive_enabled: bool,
        registration_proof_case: ?visual_foundation.RegistrationProofCase,
        component_proof_case: ?visual_foundation.ComponentProofCase,
        capture_manual_bundle: bool,
    ) !void {
        self.renderer.camera().* = camera2d.Camera2D.initDefault();
        if (self.renderer.drawable().available) try self.renderer.camera().*.setViewport(self.renderer.drawable().width, self.renderer.drawable().height);
        const camera_follower = try camera2d.HorizontalFollower.init(3.25);
        var minimum_camera_x = self.renderer.camera().*.center.x;
        var maximum_camera_x = self.renderer.camera().*.center.x;
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

        const gpu_creations_before_humanoid_initialization = self.renderer.metrics().gpu_resource_creations;
        if (mode == .controller) {
            try humanoid.runFaultInjectionChecks(self.allocator);
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.HumanoidInitializationCreatedGpuResources;
            }
            humanoid_demo = try humanoid.DemoCharacter.init(humanoid_allocator.allocator(), null);
        }
        if (mode == .controller) {
            try animation_system.runFaultInjectionChecks(self.allocator, &humanoid_demo.?.definition);
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.AnimationInitializationCreatedGpuResources;
            }
            animation_runtime = try animation_system.Runtime.init(humanoid_allocator.allocator(), &humanoid_demo.?.definition, null);
        }
        if (mode == .controller) {
            try controller_demo.runFaultInjectionChecks(self.allocator);
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.ControllerInitializationCreatedGpuResources;
            }
            controller_runtime = try controller_demo.Runtime.init(humanoid_allocator.allocator(), null);
            platform_input = sdl_input.PlatformInput.init();
        }
        if (mode == .handshake_ik) {
            if (!scripted_input_enabled) return error.HandshakeIkDemoRequiresScriptedInput;
            handshake_ik_scene = try handshake_ik_demo.Scene.init(humanoid_allocator.allocator());
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.HandshakeIkInitializationCreatedGpuResources;
            }
        }
        if (mode == .integrated) {
            if (!scripted_input_enabled) return error.IntegratedDemoRequiresScriptedInput;
            integrated_scene = try integrated_demo.Scene.init(humanoid_allocator.allocator(), .{
                .debug_visualization = integrated_debug_enabled,
                .diagnostics_each_tick = true,
            });
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.IntegratedInitializationCreatedGpuResources;
            }
            integrated_scene.?.setResourceSnapshot(self.renderer.resourceSnapshot(humanoid_allocator.end_index, 0));
        }
        if (mode == .playground or mode == .side_scroller) {
            if (mode == .playground and scripted_input_enabled == interactive_enabled) return error.PlaygroundRequiresExactlyOneInputMode;
            if (mode == .side_scroller and (!scripted_input_enabled or interactive_enabled)) return error.SideScrollerRequiresScriptedInput;
            playground_scene = try playground_demo.Scene.init(humanoid_allocator.allocator(), integrated_debug_enabled);
            if (mode == .playground and !scripted_input_enabled) platform_input = sdl_input.PlatformInput.init();
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.PlaygroundInitializationCreatedGpuResources;
            }
        }
        if (mode == .modular_body) {
            try modular_body_demo.runFaultInjectionChecks(self.allocator);
            modular_body_scene = try modular_body_demo.Scene.init(humanoid_allocator.allocator());
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.ModularBodyInitializationCreatedGpuResources;
            }
        }
        if (mode == .equipment) {
            equipment_scene = try equipment_demo.Scene.init(humanoid_allocator.allocator());
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
                return error.EquipmentInitializationCreatedGpuResources;
            }
        }
        if (mode == .mesh_attachments) {
            mesh_attachment_scene = try mesh_attachment_demo.Scene.init(humanoid_allocator.allocator());
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
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
            if (self.renderer.drawable().available and
                (foundation_scene.?.integrated.camera.viewport_width != self.renderer.drawable().width or
                    foundation_scene.?.integrated.camera.viewport_height != self.renderer.drawable().height))
            {
                try foundation_scene.?.applyViewport(
                    self.renderer.drawable().width,
                    self.renderer.drawable().height,
                );
            }
            if (capture_manual_bundle) {
                try foundation_scene.?.requestManualDebugCapture();
            }
            if (!scripted_input_enabled) platform_input = sdl_input.PlatformInput.init();
            if (self.renderer.metrics().gpu_resource_creations != gpu_creations_before_humanoid_initialization) {
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
            try self.renderer.camera().*.setCenter(.{
                .x = 0,
                .y = self.renderer.camera().*.center.y,
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
            if (self.renderer.drawable().available and
                (environment_scene.?.camera.viewport_width != self.renderer.drawable().width or
                    environment_scene.?.camera.viewport_height != self.renderer.drawable().height))
            {
                try environment_scene.?.applyViewport(
                    self.renderer.drawable().width,
                    self.renderer.drawable().height,
                );
            }
            self.renderer.camera().* = environment_scene.?.camera;
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
        const creations_before_run = self.renderer.metrics().gpu_resource_creations;
        var creations_after_warmup = creations_before_run;
        self.renderer.spriteBatch().markStabilized();
        if (self.renderer.renderQueueOptional()) |queue| queue.markStabilized();
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
                if ((mode == .foundation or mode == .environment) and self.renderer.drawable().available and
                    (event.type == c.SDL_EVENT_WINDOW_RESIZED or
                        event.type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED or
                        event.type == c.SDL_EVENT_WINDOW_RESTORED))
                {
                    if (mode == .foundation) {
                        try foundation_scene.?.applyViewport(self.renderer.drawable().width, self.renderer.drawable().height);
                    } else {
                        try environment_scene.?.applyViewport(self.renderer.drawable().width, self.renderer.drawable().height);
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

                    self.renderer.spriteBatch().beginFrame();
                    var allocation_checkpoint = humanoid_allocator.end_index;
                    try simulation.evaluateRenderPose(&demo.character, &demo.definition);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    if (debug_geometry) _ = try simulation.submitCollisionGeometry(self.renderer.spriteBatch());
                    allocation_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try demo.character.submitAttachments(&demo.definition, self.renderer.spriteBatch(), 0);
                    humanoid_submission_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                },
                .handshake_ik => {
                    const scene = &handshake_ik_scene.?;
                    var allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(frame);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.renderer.spriteBatch().beginFrame();
                    allocation_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(self.renderer.spriteBatch());
                    humanoid_submission_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                },
                .integrated => {
                    const scene = &integrated_scene.?;
                    scene.setResourceSnapshot(self.renderer.resourceSnapshot(humanoid_allocator.end_index, 0));
                    var allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(1.0 / 60.0);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.renderer.spriteBatch().beginFrame();
                    allocation_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(self.renderer.spriteBatch());
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
                        try self.renderer.camera().*.setCenter(camera2d.default_center);
                    } else {
                        try camera_follower.update(self.renderer.camera(), scene.player.worldPosition().x);
                    }
                    minimum_camera_x = @min(minimum_camera_x, self.renderer.camera().*.center.x);
                    maximum_camera_x = @max(maximum_camera_x, self.renderer.camera().*.center.x);
                    self.renderer.spriteBatch().beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(self.renderer.spriteBatch());
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .modular_body => {
                    const scene = &modular_body_scene.?;
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(frame);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.renderer.spriteBatch().beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(self.renderer.spriteBatch());
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .equipment => {
                    const scene = &equipment_scene.?;
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(frame);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.renderer.spriteBatch().beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(self.renderer.spriteBatch());
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .mesh_attachments => {
                    const scene = &mesh_attachment_scene.?;
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(frame);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    self.renderer.renderQueue().beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(self.renderer.renderQueue());
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .side_scroller => {
                    const scene = &playground_scene.?;
                    const snapshot = try playground_snapshot_builder.update(side_scroller_sequence.nextRaw(scene));
                    const allocation_checkpoint = humanoid_allocator.end_index;
                    try scene.updateFrame(1.0 / 60.0, snapshot);
                    pose_evaluation_allocations += humanoid_allocator.end_index - allocation_checkpoint;
                    side_scroller_sequence.observe(scene);
                    try camera_follower.update(self.renderer.camera(), scene.player.worldPosition().x);
                    minimum_camera_x = @min(minimum_camera_x, self.renderer.camera().*.center.x);
                    maximum_camera_x = @max(maximum_camera_x, self.renderer.camera().*.center.x);
                    self.renderer.spriteBatch().beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(self.renderer.spriteBatch());
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                },
                .foundation => {
                    const scene = foundation_scene.?;
                    if (self.renderer.drawable().available and
                        (scene.integrated.camera.viewport_width != self.renderer.drawable().width or
                            scene.integrated.camera.viewport_height != self.renderer.drawable().height))
                    {
                        try scene.applyViewport(
                            self.renderer.drawable().width,
                            self.renderer.drawable().height,
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
                    self.renderer.camera().* = scene.integrated.camera;
                    minimum_camera_x = @min(minimum_camera_x, scene.integrated.camera.center.x);
                    maximum_camera_x = @max(maximum_camera_x, scene.integrated.camera.center.x);
                    self.renderer.renderQueue().beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(self.renderer.renderQueue());
                    humanoid_submission_allocations += humanoid_allocator.end_index - submission_checkpoint;
                    // Ground/camera presentation correction is resolved from
                    // the real submitted trace, so publish that same-frame
                    // camera to the production renderer before encoding.
                    self.renderer.camera().* = scene.integrated.camera;
                },
                .art_assets => {
                    self.renderer.renderQueue().beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try art_scene.?.submit(self.renderer.renderQueue(), frame);
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
                    self.renderer.renderQueue().beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    if ((mode == .visual_quality and integrated_debug_enabled) or
                        mode == .anatomy_quality)
                    {
                        geometry_trace.begin();
                        humanoid_instances = try scene.submitTraced(
                            self.renderer.renderQueue(),
                            &geometry_trace,
                        );
                        if (mode == .visual_quality) {
                            try visual_geometry_overlay.build(
                                &geometry_debug_commands,
                                &geometry_trace,
                                &geometry_alpha_catalog.?,
                                self.renderer.camera().*,
                            );
                            humanoid_instances += try geometry_debug_commands.submitUnified(
                                self.renderer.renderQueue(),
                            );
                        }
                    } else {
                        humanoid_instances = try scene.submit(self.renderer.renderQueue());
                    }
                    humanoid_submission_allocations +=
                        humanoid_allocator.end_index - submission_checkpoint;
                },
                .environment => {
                    const scene = &environment_scene.?;
                    if (self.renderer.drawable().available and
                        (scene.camera.viewport_width != self.renderer.drawable().width or
                            scene.camera.viewport_height != self.renderer.drawable().height))
                    {
                        try scene.applyViewport(
                            self.renderer.drawable().width,
                            self.renderer.drawable().height,
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
                    self.renderer.camera().* = scene.camera;
                    minimum_camera_x = @min(minimum_camera_x, scene.camera.center.x);
                    maximum_camera_x = @max(maximum_camera_x, scene.camera.center.x);
                    self.renderer.renderQueue().beginFrame();
                    const submission_checkpoint = humanoid_allocator.end_index;
                    humanoid_instances = try scene.submit(self.renderer.renderQueue());
                    humanoid_submission_allocations +=
                        humanoid_allocator.end_index - submission_checkpoint;
                },
            }
            const rendered = if (usesUnifiedRendering(mode)) unified: {
                var prepared = self.renderer.renderQueue().prepare();
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
                            self.renderer.renderQueue(),
                        );
                        prepared = self.renderer.renderQueue().prepare();
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
                        const driver = try self.renderer.backendName();
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
                                .texture_pages = self.renderer.texturePageCount(),
                                .submitted_sprites = self.renderer.renderQueue().frame_metrics.submitted_sprites,
                                .submitted_meshes = self.renderer.renderQueue().frame_metrics.submitted_meshes,
                                .sprite_ranges = self.renderer.renderQueue().frame_metrics.sprite_ranges,
                                .mesh_ranges = self.renderer.renderQueue().frame_metrics.mesh_ranges,
                                .gpu_resource_creations = self.renderer.metrics().gpu_resource_creations,
                                .steady_update_allocations = pose_evaluation_allocations,
                                .steady_submission_allocations = humanoid_submission_allocations,
                                .steady_queue_allocations = self.renderer.renderQueue().lifetime_metrics.cpu_allocations_after_stabilization,
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
                                        .female.id().raw(),
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
                                self.renderer.renderQueue(),
                            );
                            prepared = self.renderer.renderQueue().prepare();
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
                                self.renderer.renderQueue(),
                            );
                            prepared = self.renderer.renderQueue().prepare();
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
                            self.renderer.renderQueue(),
                            self.renderer.camera().*,
                            observation,
                            next_target,
                        );
                        prepared = self.renderer.renderQueue().prepare();
                    }
                    const window_rendered = try self.renderUnifiedToWindow(prepared);
                    foundation_scene.?.recordRendering(self.renderer.renderQueue().frame_metrics);
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
            } else try self.renderPreparedToWindow(self.renderer.spriteBatch().prepare(), null);
            self.renderer.recordFrameResult(rendered);
            if (mode == .integrated) {
                integrated_scene.?.recordRendering(.{
                    .submitted_sprite_count = self.renderer.spriteBatch().frame_metrics.submitted_sprites,
                    .ordinary_sprite_count = integrated_scene.?.evidence.ordinary_sprites,
                    .debug_primitive_count = integrated_scene.?.evidence.debug_primitives,
                    .texture_pages = 1,
                    .sprite_draw_ranges = self.renderer.spriteBatch().frame_metrics.draw_ranges,
                    .sprite_draw_calls = self.renderer.spriteBatch().frame_metrics.draw_calls,
                    .debug_draw_calls = 0,
                    .total_actual_draw_calls = self.renderer.spriteBatch().frame_metrics.draw_calls,
                });
            }
            if (usesUnifiedRendering(mode)) {
                try self.updateUnifiedWindowTitle();
            } else {
                try self.updateWindowTitle();
            }
            if (frame == 0) creations_after_warmup = self.renderer.metrics().gpu_resource_creations;
        }

        const metrics = self.renderer.spriteBatch().frame_metrics;
        if (!usesUnifiedRendering(mode)) {
            std.log.info("sprite-batch final metrics: frames={d} submitted={d} visible={d} culled={d} sorted={d} ranges={d} actual_draw_calls={d} upload_bytes={d}", .{
                self.renderer.metrics().frames_rendered,
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
                self.renderer.metrics().gpu_resource_creations,
                self.renderer.metrics().upload_buffer_growths,
                self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization,
                self.renderer.metrics().frame_slot_fence_waits,
                self.renderer.currentFrameSlot(),
            });
            std.log.info("actual sprite draw command: SDL_DrawGPUIndexedPrimitives num_instances={d} draw_calls={d} draw_ranges={d}", .{
                metrics.visible_sprites, metrics.draw_calls, metrics.draw_ranges,
            });
        }
        if (mode == .controller) {
            const simulation = &controller_runtime.?;
            const animation = &animation_runtime.?;
            const state = simulation.controller.state;
            const gpu_resources_for_movement = self.renderer.metrics().gpu_resource_creations - creations_before_run;
            std.log.info("controller final metrics: frames={d} simulation_ticks={d} animator_ticks={d} humanoid_sprites={d} collider_sprites={d} total_sprites={d} ranges={d} actual_draw_calls={d} jump_events={d} coyote_jumps={d} buffered_jumps={d} landing_events={d} wall_collisions={d} ceiling_collisions={d}", .{
                self.renderer.metrics().frames_rendered,
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
            if (self.renderer.metrics().frames_rendered != handshake_ik_demo.required_frames) return error.HandshakeIkFrameCountMismatch;
            const gpu_resources_for_ik = self.renderer.metrics().gpu_resource_creations - creations_before_run;
            const nominal = scene.nominal;
            const mirrored = scene.mirrored;
            const perturbed = scene.perturbed;
            const nominal_a = nominal.role_a_metrics.?;
            const nominal_b = nominal.role_b_metrics.?;
            const reduction_percent = (1.0 - perturbed.post_separation / perturbed.pre_separation) * 100.0;
            std.log.info("handshake IK final metrics: frames={d} characters={d} humanoid_sprites={d} texture_pages=1 ranges={d} actual_draw_calls={d} gpu_resources_created_by_ik={d}", .{
                self.renderer.metrics().frames_rendered,
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
            const manager_metrics = scene.manager.metricsSnapshot();
            std.log.info("handshake IK steady state: initialized_bytes={d} final_bytes={d} solver_allocations={d} binding_allocations={d} target_allocations={d} pose_allocations={d} hierarchy_allocations={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                manager_metrics.ik_solver_allocations,
                manager_metrics.ik_binding_lookup_allocations,
                manager_metrics.ik_target_computation_allocations,
                manager_metrics.ik_pose_application_allocations,
                manager_metrics.ik_hierarchy_evaluation_allocations,
            });
            if (humanoid_instances != handshake_ik_demo.character_count * humanoid.default_visual_count or
                metrics.visible_sprites != humanoid_instances or metrics.draw_ranges != 1 or metrics.draw_calls != 1 or
                self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resources_for_ik != 0 or
                humanoid_allocator.end_index != humanoid_initialized_bytes)
            {
                return error.HandshakeIkEvidenceIncomplete;
            }
        } else if (mode == .integrated) {
            const scene = &integrated_scene.?;
            try scene.validateComplete();
            if (self.renderer.metrics().frames_rendered != integrated_demo.required_frames) return error.IntegratedFrameCountMismatch;
            const gpu_resource_delta = self.renderer.metrics().gpu_resource_creations - creations_before_run;
            const final_state = try scene.authoritativeState();
            const final_diagnostics = try scene.captureDiagnostics();
            const player_state = scene.player.controllerSnapshot().?.state;
            const player_feet = scene.player.footPlantingSnapshot();
            const partner_feet = scene.partner.footPlantingSnapshot();
            const left_metrics = player_feet.left.metrics;
            const right_metrics = player_feet.right.metrics;
            const total_left_acquisitions = left_metrics.plant_acquisitions + partner_feet.left.metrics.plant_acquisitions;
            const total_right_acquisitions = right_metrics.plant_acquisitions + partner_feet.right.metrics.plant_acquisitions;
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
                scene.partner.worldPosition().x,
                scene.partner.worldPosition().y,
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
                final_state.allocation_total + self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization,
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
                scene.player.proceduralSnapshot().landing_spring.offset,
                scene.player.proceduralSnapshot().landing_spring.velocity,
                scene.player.proceduralSnapshot().secondary_spring.offset,
                scene.player.proceduralSnapshot().secondary_spring.velocity,
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
                self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resource_delta != 0 or
                humanoid_allocator.end_index != humanoid_initialized_bytes)
            {
                return error.IntegratedRenderingEvidenceIncomplete;
            }
        } else if (mode == .playground) {
            const scene = &playground_scene.?;
            if (scripted_input_enabled) {
                if (self.renderer.metrics().frames_rendered != playground_demo.required_frames) return error.PlaygroundFrameCountMismatch;
                try playground_sequence.validate(scene);
            }
            const final_state = scene.authoritativeState();
            const gpu_resource_delta = self.renderer.metrics().gpu_resource_creations - creations_before_run;
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
                runtime_allocation_delta != 0 or self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization != 0)
            {
                return error.PlaygroundRenderingEvidenceIncomplete;
            }
        } else if (mode == .modular_body) {
            const scene = &modular_body_scene.?;
            try scene.validateComplete();
            if (self.renderer.metrics().frames_rendered != modular_body_demo.required_frames) {
                return error.ModularBodyFrameCountMismatch;
            }
            const gpu_resource_delta = self.renderer.metrics().gpu_resource_creations - creations_before_run;
            const runtime_allocation_delta = humanoid_allocator.end_index - humanoid_initialized_bytes;
            const anatomy_definition = scene.definition.anatomy_definition.?.view();
            const male_parts = try scene.conventional_male.anatomyRuntimeSnapshot().?.activePartCount(anatomy_definition);
            const female_parts = try scene.conventional_female.anatomyRuntimeSnapshot().?.activePartCount(anatomy_definition);
            const nonstandard_parts_count = try scene.nonstandard.humanoidView().anatomy_runtime.?.activePartCount(anatomy_definition);
            std.log.info("MODULAR BODY EVIDENCE", .{});
            std.log.info("Presets: conventional_male_parts={d} conventional_female_parts={d} nonstandard_parts={d} shared_skeleton={} shared_animation_library={}", .{
                male_parts,
                female_parts,
                nonstandard_parts_count,
                scene.conventional_male.definitionView().owner_token == scene.conventional_female.definitionView().owner_token and
                    scene.conventional_female.definitionView().owner_token == scene.nonstandard.definitionView().owner_token,
                scene.conventional_male.animationDefinitionsView().library_token == scene.conventional_female.animationDefinitionsView().library_token and
                    scene.conventional_female.animationDefinitionsView().library_token == scene.nonstandard.animationDefinitionsView().library_token,
            });
            std.log.info("Nonstandard features: extra_arms=2 articulated_tail=true horns=2 canonical_bones={d} canonical_right_arm_lengths=({d:.3},{d:.3})", .{
                scene.definition.skeleton_definition.boneCount(),
                scene.nonstandard.rightArmBinding().upper_length,
                scene.nonstandard.rightArmBinding().lower_length,
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
                self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization,
                gpu_resource_delta,
            });
            if (humanoid_instances == 0 or metrics.visible_sprites != humanoid_instances or
                metrics.draw_ranges != 1 or metrics.draw_calls != 1 or
                runtime_allocation_delta != 0 or pose_evaluation_allocations != 0 or humanoid_submission_allocations != 0 or
                self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resource_delta != 0)
            {
                return error.ModularBodyRenderingEvidenceIncomplete;
            }
        } else if (mode == .equipment) {
            const scene = &equipment_scene.?;
            try scene.validateComplete();
            if (self.renderer.metrics().frames_rendered != equipment_demo.required_frames) {
                return error.EquipmentFrameCountMismatch;
            }
            const gpu_resource_delta = self.renderer.metrics().gpu_resource_creations - creations_before_run;
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
            for (scene.two_arm.equipmentView().?.modifiers()) |modifier| {
                const item = scene.two_arm.equipmentView().?.definition.items[modifier.item.index()];
                const attribute = scene.two_arm.equipmentView().?.definition.attributes[modifier.attribute.index()];
                std.log.info("Two-arm modifier: item={s} attribute={s} operation={s} amount={d:.3}", .{
                    item.stable_id.slice(),
                    attribute.stable_id.slice(),
                    @tagName(modifier.operation),
                    modifier.amount,
                });
            }
            for (scene.four_arm.equipmentView().?.capabilities()) |grant| {
                const item = scene.four_arm.equipmentView().?.definition.items[grant.item.index()];
                const capability = scene.four_arm.equipmentView().?.definition.capabilities[grant.capability.index()];
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
                self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization,
                gpu_resource_delta,
            });
            if (humanoid_instances == 0 or metrics.visible_sprites != humanoid_instances or
                metrics.draw_ranges != 1 or metrics.draw_calls != 1 or
                runtime_allocation_delta != 0 or pose_evaluation_allocations != 0 or humanoid_submission_allocations != 0 or
                self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resource_delta != 0)
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
                if (self.renderer.metrics().frames_rendered != required_frames) {
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
            const unified_metrics = self.renderer.renderQueue().frame_metrics;
            const runtime_allocation_delta = humanoid_allocator.end_index - humanoid_initialized_bytes;
            const gpu_resource_delta =
                self.renderer.metrics().gpu_resource_creations - creations_before_run;
            const male_page = try self.renderer.texturePageInfo(0);
            const female_page = try self.renderer.texturePageInfo(1);
            const component_page = try self.renderer.texturePageInfo(2);
            const upper_page = try self.renderer.texturePageInfo(3);
            const layers_page = try self.renderer.texturePageInfo(4);
            const lower_page = try self.renderer.texturePageInfo(5);
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
                    self.renderer.imageDecodeMetrics().successful_decodes,
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
                    self.renderer.renderQueue().lifetime_metrics.cpu_allocations_after_stabilization,
                    gpu_resource_delta,
                },
            );
            const expected_decoded_bytes =
                (1600 * 983 + 1599 * 984 + 1792 * 1024) * 4 +
                3 * 1536 * 1024 * 4;
            if (self.renderer.imageDecodeMetrics().decode_attempts != 6 or
                self.renderer.imageDecodeMetrics().successful_decodes != 6 or
                self.renderer.imageDecodeMetrics().decoded_bytes != expected_decoded_bytes or
                self.renderer.artTexturePageCount() != 6 or
                self.renderer.texturePageCount() != 7 or
                male_page.sampling != .nearest or
                female_page.sampling != .nearest or
                component_page.sampling != .nearest or
                upper_page.sampling != .linear or
                layers_page.sampling != .linear or
                lower_page.sampling != .linear or
                runtime_allocation_delta != 0 or
                pose_evaluation_allocations != 0 or
                humanoid_submission_allocations != 0 or
                self.renderer.renderQueue().lifetime_metrics.cpu_allocations_after_stabilization != 0 or
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
                if (self.renderer.metrics().frames_rendered != visual_foundation.required_frames) {
                    return error.FoundationFrameCountMismatch;
                }
                try scene.validateComplete(&foundation_sequence);
                try foundation_capture_tracker.validateComplete();
                try self.writeFoundationEvidence(&foundation_capture_artifacts);
                try self.writeP27bSupplementalEvidence(&p27b_capture_artifacts);
            }
            const unified_metrics = self.renderer.renderQueue().frame_metrics;
            const gpu_resource_delta = self.renderer.metrics().gpu_resource_creations - creations_before_run;
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
                    self.renderer.artTexturePageCount(),
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
                self.renderer.renderQueue().lifetime_metrics.cpu_allocations_after_stabilization,
                gpu_resource_delta,
            });
            if (self.renderer.imageDecodeMetrics().decode_attempts != 8 or
                self.renderer.imageDecodeMetrics().successful_decodes != 8 or
                self.renderer.imageDecodeMetrics().decoded_bytes != expected_decoded_bytes or
                self.renderer.artTexturePageCount() != 8 or
                self.renderer.texturePageCount() != 9 or
                humanoid_instances == 0 or
                unified_metrics.submitted_sprites == 0 or
                scene.evidence.maximum_sprite_ranges == 0 or
                scene.evidence.maximum_sprite_draws == 0 or
                runtime_allocation_delta != 0 or
                pose_evaluation_allocations != 0 or
                humanoid_submission_allocations != 0 or
                self.renderer.renderQueue().lifetime_metrics.cpu_allocations_after_stabilization != 0 or
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
            if (self.renderer.metrics().frames_rendered != mesh_attachment_demo.required_frames) {
                return error.MeshAttachmentFrameCountMismatch;
            }
            const unified_metrics = self.renderer.renderQueue().frame_metrics;
            const catalog = self.renderer.meshCatalog();
            const gpu_resource_delta = self.renderer.metrics().gpu_resource_creations - creations_before_run;
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
                sdl_gpu_renderer.frame_slot_count,
            });
            std.log.info("Steady-state: initialized_bytes={d} final_bytes={d} update_allocations={d} submission_allocations={d} queue_allocations={d} gpu_resource_delta={d}", .{
                humanoid_initialized_bytes,
                humanoid_allocator.end_index,
                pose_evaluation_allocations,
                humanoid_submission_allocations,
                self.renderer.renderQueue().lifetime_metrics.cpu_allocations_after_stabilization,
                gpu_resource_delta,
            });
            if (humanoid_instances == 0 or unified_metrics.submitted_sprites == 0 or unified_metrics.submitted_meshes != 10 or
                unified_metrics.sprite_ranges == 0 or unified_metrics.mesh_ranges == 0 or
                unified_metrics.sprite_draws == 0 or unified_metrics.mesh_draws == 0 or
                runtime_allocation_delta != 0 or pose_evaluation_allocations != 0 or humanoid_submission_allocations != 0 or
                self.renderer.renderQueue().lifetime_metrics.cpu_allocations_after_stabilization != 0 or gpu_resource_delta != 0)
            {
                return error.MeshAttachmentRenderingEvidenceIncomplete;
            }
        } else if (mode == .side_scroller) {
            const scene = &playground_scene.?;
            if (self.renderer.metrics().frames_rendered != playground_demo.side_scroller_required_frames) {
                return error.SideScrollerFrameCountMismatch;
            }
            try side_scroller_sequence.validate(scene);
            const camera_displacement = maximum_camera_x - minimum_camera_x;
            if (camera_displacement < 12) return error.SideScrollerCameraTravelMissing;
            const gpu_resource_delta = self.renderer.metrics().gpu_resource_creations - creations_before_run;
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
                self.renderer.camera().*.viewport_width,
                self.renderer.camera().*.viewport_height,
                self.renderer.camera().*.pixels_per_meter,
            });
            std.log.info("Parallax response: distant_factor={d:.3} distant_displacement={d:.5} midground_factor={d:.3} midground_displacement={d:.5} gameplay_factor=1.000 gameplay_displacement={d:.5}", .{
                playground_demo.distant_camera_x_factor,
                camera_displacement * playground_demo.distant_camera_x_factor,
                playground_demo.midground_camera_x_factor,
                camera_displacement * playground_demo.midground_camera_x_factor,
                camera_displacement,
            });
            std.log.info("Resize: events={d} viewport_updates={d} zero_drawable_frames={d} unrelated_resource_recreations={d}", .{
                self.renderer.metrics().resize_events,
                self.renderer.metrics().viewport_updates,
                self.renderer.metrics().zero_drawable_frames,
                gpu_resource_delta,
            });
            if (metrics.draw_ranges != 1 or metrics.draw_calls != 1 or gpu_resource_delta != 0 or
                runtime_allocation_delta != 0 or self.renderer.spriteBatch().lifetime_metrics.cpu_allocations_after_stabilization != 0)
            {
                return error.SideScrollerRenderingEvidenceIncomplete;
            }
        }
    }

    fn writeFoundationEvidence(
        self: *DemoApplication,
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
        self: *DemoApplication,
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
        self: *DemoApplication,
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
        self: *DemoApplication,
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
