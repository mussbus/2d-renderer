const std = @import("std");
const hub_module = @import("engine_lab");
const verification = @import("engine_lab_verification");
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const renderer_module = @import("sdl_gpu_renderer");
const platform_module = @import("sdl_input");
const art_pack = @import("art_pack");
const physical = @import("physical_input");
const c = @import("sdl").c;
const impact_smoke = @import("impact_smoke.zig");
const calibration_smoke = @import("calibration_smoke.zig");
const traversal_smoke = @import("traversal_smoke.zig");
const world_time_smoke = @import("world_time_smoke.zig");

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    var seed = try hub_module.Seed.parseLowerHex(hub_module.default_seed);
    var verify = false;
    var verify_time_overflow = false;
    var smoke = false;
    var help = false;
    var impact_capture_dir: []const u8 = ".tmp/engine-lab-traversal/captures/impact";
    var calibration_capture_dir: []const u8 = ".tmp/engine-lab-traversal/captures/calibration";
    var world_time_capture_dir: []const u8 = ".tmp/engine-lab-traversal/captures/world-time";
    var traversal_capture_dir: []const u8 = ".tmp/engine-lab-traversal/captures/traversal";
    var argument: usize = 1;
    while (argument < arguments.len) : (argument += 1) {
        const text = arguments[argument];
        if (std.mem.eql(u8, text, "--help")) {
            help = true;
        } else if (std.mem.eql(u8, text, "--verify")) {
            verify = true;
        } else if (std.mem.eql(u8, text, "--verify-world-time-overflow")) {
            verify_time_overflow = true;
        } else if (std.mem.eql(u8, text, "--smoke")) {
            smoke = true;
        } else if (std.mem.eql(u8, text, "--impact-capture-dir")) {
            argument += 1;
            if (argument == arguments.len or arguments[argument].len == 0) return error.MissingCaptureDirectory;
            impact_capture_dir = arguments[argument];
        } else if (std.mem.eql(u8, text, "--calibration-capture-dir")) {
            argument += 1;
            if (argument == arguments.len or arguments[argument].len == 0) return error.MissingCaptureDirectory;
            calibration_capture_dir = arguments[argument];
        } else if (std.mem.eql(u8, text, "--world-time-capture-dir")) {
            argument += 1;
            if (argument == arguments.len or arguments[argument].len == 0) return error.MissingCaptureDirectory;
            world_time_capture_dir = arguments[argument];
        } else if (std.mem.eql(u8, text, "--traversal-capture-dir")) {
            argument += 1;
            if (argument == arguments.len or arguments[argument].len == 0) return error.MissingCaptureDirectory;
            traversal_capture_dir = arguments[argument];
        } else if (std.mem.eql(u8, text, "--seed")) {
            argument += 1;
            if (argument == arguments.len) return error.MissingSeedValue;
            seed = try hub_module.Seed.parseLowerHex(arguments[argument]);
        } else return error.UnknownArgument;
    }
    if ((verify and smoke) or (verify_time_overflow and (verify or smoke))) return error.ConflictingVerificationModes;
    if (help) {
        std.log.info("Engine Lab opens one persistent hub. --seed 32-lower-hex --verify --smoke --impact-capture-dir path --calibration-capture-dir path --world-time-capture-dir path --traversal-capture-dir path --verify-world-time-overflow (expected failure fixture). A/D or arrows move; Space jumps twice; Shift dashes; gamepad stick/south/right shoulder also move/jump/dash. F1/F2 travel within the hub; E/gamepad west activates the nearby projectile installation. R resets the whole hub; P pauses; T steps; F3 diagnostics; F4 cycles current/2x-out/4x-out zoom; R also restores current zoom; Escape exits.", .{});
        return;
    }
    const allocator = std.heap.page_allocator;
    if (verify_time_overflow) return verification.world_time.verifyOverflow(allocator, seed);
    if (verify) {
        const result = try verification.verify(allocator, seed);
        for (result.checkpoints) |checkpoint| std.log.info("EL1_HUB_CHECKPOINT tick={d} sha256={s}", .{ checkpoint.tick, checkpoint.digest.formatLowerHex() });
        std.log.info("ENGINE_LAB_HUB_VERIFY_OK schedules=60Hz,mixed ticks=1440 stations=2 jumps={d} landings={d} wall_contacts={d}", .{ result.jumps, result.landings, result.wall_contacts });
        const integrated = try verification.verifyImpact(allocator, seed);
        for (integrated.checkpoints) |checkpoint| std.log.info("IMPACT_OBSERVATIONS_V2 tick={d} sha256={s}", .{ checkpoint.tick, checkpoint.digest.formatLowerHex() });
        std.log.info("ENGINE_LAB_IMPACT_VERIFY_OK launches=2 contacts=2 drain_tick=936 native_last_spawn_tick={d} native_last_contact_tick={d} contact_sequence={d}", .{ integrated.launch_tick, integrated.contact_tick, integrated.contact_sequence });
        const multi = try verification.verifyMultiImpact(allocator, seed);
        for (multi.checkpoints) |checkpoint| std.log.info("MULTI_IMPACT_OBSERVATIONS_V2 tick={d} sha256={s}", .{ checkpoint.tick, checkpoint.digest.formatLowerHex() });
        std.log.info("ENGINE_LAB_MULTI_IMPACT_VERIFY_OK launches=16 contacts=16 rejected_full=2 rejected_range=1 drain_tick=888 colors={any} peak_particles={d} peak_emitters={d} drops=0", .{ multi.colors, multi.peak_particles, multi.peak_emitters });
        const calibrated = try verification.calibration.verify(allocator, seed);
        for (calibrated.checkpoints) |checkpoint| std.log.info("CALIBRATION_OBSERVATIONS_V1 tick={d} sha256={s} offset={d:.6} velocity={d:.6}", .{ checkpoint.tick, checkpoint.digest.formatLowerHex(), checkpoint.offset, checkpoint.velocity });
        std.log.info("ENGINE_LAB_CALIBRATION_VERIFY_OK schedules=60Hz,mixed ticks=1440 settled=true axis=world_positive_x external_acceleration=0", .{});
        const timed = try verification.world_time.verify(allocator, seed);
        var time_diagnostic: [hub_module.world_time_module.diagnostic_capacity]u8 = undefined;
        for (timed.checkpoints) |snapshot| std.log.info("{s}", .{try hub_module.world_time_module.diagnostic(snapshot, &time_diagnostic)});
        std.log.info("ENGINE_LAB_WORLD_TIME_VERIFY_OK schedules=60Hz,mixed checkpoints=8 rollover_tick=240 exact_carry=true", .{});
        const traversed = try verification.traversal.verify(allocator, seed);
        for (traversed.checkpoints) |checkpoint| std.log.info("TRAVERSAL_OBSERVATIONS_V1 tick={d} sha256={s}", .{ checkpoint.tick, checkpoint.digest.formatLowerHex() });
        std.log.info("ENGINE_LAB_TRAVERSAL_VERIFY_OK routes=easy,air,dash schedules=60Hz,mixed layout=engine_lab.traversal.layout.v1 profile=engine_lab.traversal.movement.v1", .{});
        return;
    }
    try run(init.io, allocator, seed, smoke, impact_capture_dir, calibration_capture_dir, world_time_capture_dir, traversal_capture_dir);
}

fn run(io: std.Io, backing_allocator: std.mem.Allocator, seed: hub_module.Seed, smoke: bool, impact_capture_dir: []const u8, calibration_capture_dir: []const u8, world_time_capture_dir: []const u8, traversal_capture_dir: []const u8) !void {
    var tracking = std.testing.FailingAllocator.init(backing_allocator, .{});
    const allocator = tracking.allocator();
    var hub = if (smoke) try hub_module.Hub.initLegacy(allocator, seed) else try hub_module.Hub.initExpanded(allocator, seed);
    defer hub.deinit() catch |err| hub_module.cleanupFailure(err);
    var view = try view_module.View.init(allocator);
    defer view.deinit();
    var renderer = renderer_module.Renderer.init(allocator, smoke, null) catch |err| {
        std.log.err("Engine Lab renderer initialization: {s}; SDL: {s}", .{ @errorName(err), sdlError() });
        return err;
    };
    var renderer_live = true;
    defer if (renderer_live) renderer.deinit();
    var art = try art_pack.Definition.init(allocator, .{
        .stable_name = "engine_lab_ui",
        .pages = &.{.{ .id = @enumFromInt(1), .stable_name = "neutral_white", .asset_path = "engine_lab/white.png", .sampling = .nearest, .expected_width = 2, .expected_height = 2 }},
        .regions = &.{},
        .bindings = &.{},
    });
    defer art.deinit();
    try renderer.initializeArtTexturePages(&art);
    try renderer.initializeUnifiedQueueWithCapacities(view_module.entry_capacity, view_module.sprite_capacity, view_module.mesh_capacity);
    if (smoke) try renderer.initializeCapture();
    var platform = platform_module.PlatformInput.init();
    var platform_live = true;
    defer if (platform_live) platform.deinit();
    var mapper = actions.Mapper{};
    const queue = renderer.renderQueue();
    try renderer.ensureGpuCapacity(view_module.sprite_capacity, null);
    std.log.info("ENGINE_LAB_PRESENTATION_CAPACITY entries={d} cpu_sprites={d} meshes={d} gpu_requested={d} preexisting_bound={d} calibration_allowance={d} time_allowance={d}", .{ queue.entries.len, queue.sprite_submissions.len, queue.mesh_submissions.len, view_module.sprite_capacity, view_module.preexisting_sprite_bound, view_module.calibration_sprite_allowance, view_module.time_sprite_allowance });
    queue.markStabilized();
    const resources = renderer.metrics();
    try reportInitial(&hub);
    var previous_time = c.SDL_GetPerformanceCounter();
    const frequency = c.SDL_GetPerformanceFrequency();
    if (frequency == 0) return error.InvalidPerformanceFrequency;
    var frame: u64 = 0;
    var rendered_frames: u64 = 0;
    var draw_calls: u64 = 0;
    var movement_seen = false;
    var jump_seen = false;
    var collision_seen = false;
    while (true) : (frame += 1) {
        const allocations_before = tracking.allocations;
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            platform.handleEvent(&event);
            try renderer.handleWindowEvent(&event);
            if (event.type == c.SDL_EVENT_KEY_DOWN and !event.key.repeat) mapper.capturePress(keyPress(event.key.scancode));
            if (event.type == c.SDL_EVENT_GAMEPAD_BUTTON_DOWN and event.gbutton.which == platform.active_gamepad_id and event.gbutton.button == c.SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER) mapper.captureGamepadDashPress();
        }
        const raw = try platform.pollRaw();
        var command = mapper.sample(raw);
        if (smoke) {
            command = .{ .intent = verification.inputAt(frame * 4) };
            switch (frame) {
                105 => command.destination = .springs,
                120 => command.pause = true,
                121 => command.step = true,
                122 => command.pause = true,
                135 => command.destination = .hierarchy,
                140 => command.diagnostics = true,
                150 => command.reset = true,
                else => {},
            }
        }
        if (command.exit) break;
        const reset = command.reset;
        const now = c.SDL_GetPerformanceCounter();
        const delta = if (reset) 0 else if (smoke) 1.0 / 60.0 else @as(f64, @floatFromInt(now - previous_time)) / @as(f64, @floatFromInt(frequency));
        previous_time = now;
        try actions.advance(&hub, &mapper, raw, command, delta);
        if (reset) try reportInitial(&hub);
        if (!reset) if (command.destination) |destination| std.log.info("EL1_HUB_TRAVEL destination={s} tick={d} stations_retained=true", .{ @tagName(destination), hub.tick });
        movement_seen = movement_seen or @abs(hub.actor.worldPosition().x - hub_module.spawn.x) > 0.5;
        jump_seen = jump_seen or hub.jumps > 0;
        collision_seen = collision_seen or hub.wall_contacts > 0;
        const window_camera = renderer.camera();
        try hub.setViewport(window_camera.viewport_width, window_camera.viewport_height);
        renderer.camera().* = hub.camera;
        try view.render(&hub, queue);
        const prepared = queue.prepare();
        if (prepared.ranges.len != 3) return error.HubBatchRangeMismatch;
        const rendered = renderer.renderUnifiedToWindow(prepared) catch |err| {
            std.log.err("Engine Lab frame submission: {s}; SDL: {s}", .{ @errorName(err), sdlError() });
            return err;
        };
        renderer.recordFrameResult(rendered);
        if (!reset and tracking.allocations != allocations_before) return error.EngineLabSteadyStateGrowth;
        if (rendered) {
            rendered_frames += 1;
            draw_calls += queue.frame_metrics.sprite_draws;
        }
        if (smoke and frame == 179) break;
        c.SDL_Delay(if (!rendered or hub.clock.paused) 8 else 1);
    }
    if (smoke) {
        if (rendered_frames != 180 or draw_calls != 540 or !movement_seen or !jump_seen or !collision_seen) return error.HubSmokeCoverageIncomplete;
        var capture = try renderer.captureUnified(queue.prepare());
        defer capture.deinit();
        const rgba = capture.bytes();
        var changed: usize = 0;
        var offset: usize = 4;
        while (offset + 4 <= rgba.len) : (offset += 4) if (!std.mem.eql(u8, rgba[0..4], rgba[offset .. offset + 4])) {
            changed += 1;
        };
        if (changed < 1000) return error.HubSmokeUniformFrame;
        std.log.info("Engine Lab hub physical proof: frames={d} draws={d} readback_changed_pixels={d} movement=true jump=true collision=true", .{ rendered_frames, draw_calls, changed });
        var single_path: [1024]u8 = undefined;
        try impact_smoke.run(io, &tracking, &hub, &view, &renderer, try std.fmt.bufPrint(&single_path, "{s}/single", .{impact_capture_dir}));
        try impact_smoke.runMulti(io, &tracking, &hub, &view, &renderer, impact_capture_dir);
        try calibration_smoke.run(io, &tracking, &hub, &view, &renderer, calibration_capture_dir);
        try world_time_smoke.run(io, &tracking, &hub, &view, &renderer, world_time_capture_dir);
        {
            var candidate = try hub_module.Hub.initExpanded(allocator, seed);
            errdefer candidate.deinit() catch |err| hub_module.cleanupFailure(err);
            try hub.deinit();
            hub = candidate;
        }
        try traversal_smoke.run(io, &tracking, &hub, &view, &renderer, traversal_capture_dir);
    }
    const steady = renderer.metrics();
    if (steady.gpu_resource_creations != resources.gpu_resource_creations or steady.upload_buffer_growths != resources.upload_buffer_growths or
        queue.lifetime_metrics.cpu_allocations_after_stabilization != 0 or view.actor_queue.lifetime_metrics.cpu_allocations_after_stabilization != 0) return error.EngineLabSteadyStateGrowth;
    platform.deinit();
    platform_live = false;
    const final = renderer.deinitWithMetrics();
    renderer_live = false;
    if (final.gpu_resource_creations != final.gpu_resource_releases or final.fence_acquisitions != final.fence_releases) return error.EngineLabGpuResourceLeak;
    std.log.info("ENGINE_LAB_HUB_SHUTDOWN_OK frames={d} resources={d}/{d} fences={d}/{d} queue_allocations_after_warmup=0 tick={d} stations={any}", .{ rendered_frames, final.gpu_resource_creations, final.gpu_resource_releases, final.fence_acquisitions, final.fence_releases, hub.tick, hub.visited });
    if (smoke) std.log.info("ENGINE_LAB_HUB_SMOKE_OK travel=2 resets=1 backend=direct3d12", .{});
}

fn reportInitial(hub: *const hub_module.Hub) !void {
    var buffer: [hub_module.world_time_module.diagnostic_capacity]u8 = undefined;
    std.log.info("{s}", .{try hub_module.world_time_module.diagnostic(hub.world_time.snapshot(), &buffer)});
    if (hub.construction == .expanded) std.log.info("TRAVERSAL_HUB_START layout={s} profile={s} sha256={s} Shift/right shoulder dash; Space/south ground plus one air jump", .{ hub_module.layout.identity(hub.construction), hub_module.layout.profileIdentity(hub.construction), (try hub.traversalFingerprint()).formatLowerHex() });
    std.log.info("EL1_HUB_START seed={s} tick=0 sha256={s}. A/D arrows move; Space jump; F1/F2 travel; E/west nearby launch; R whole-hub reset; P pause; T step; F3 diagnostics; F4 cycles current/2x-out/4x-out zoom; R also restores current zoom; Escape exit.", .{ hub.seed.formatLowerHex(), (try hub.fingerprint()).formatLowerHex() });
}
fn sdlError() []const u8 {
    const text = c.SDL_GetError();
    if (text == null) return "no SDL diagnostic";
    return std.mem.span(@as([*:0]const u8, @ptrCast(text)));
}
fn keyPress(scancode: c.SDL_Scancode) physical.KeyboardState {
    return switch (scancode) {
        c.SDL_SCANCODE_F1 => .{ .f1 = true },
        c.SDL_SCANCODE_F2 => .{ .f2 = true },
        c.SDL_SCANCODE_F3 => .{ .f3 = true },
        c.SDL_SCANCODE_F4 => .{ .f4 = true },
        c.SDL_SCANCODE_R => .{ .r = true },
        c.SDL_SCANCODE_P => .{ .p = true },
        c.SDL_SCANCODE_T => .{ .t = true },
        c.SDL_SCANCODE_LSHIFT => .{ .left_shift = true },
        c.SDL_SCANCODE_SPACE => .{ .space = true },
        c.SDL_SCANCODE_E => .{ .e = true },
        c.SDL_SCANCODE_ESCAPE => .{ .escape = true },
        else => .{},
    };
}
