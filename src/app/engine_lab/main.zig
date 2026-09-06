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

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    var seed = try hub_module.Seed.parseLowerHex(hub_module.default_seed);
    var verify = false;
    var smoke = false;
    var help = false;
    var argument: usize = 1;
    while (argument < arguments.len) : (argument += 1) {
        const text = arguments[argument];
        if (std.mem.eql(u8, text, "--help")) {
            help = true;
        } else if (std.mem.eql(u8, text, "--verify")) {
            verify = true;
        } else if (std.mem.eql(u8, text, "--smoke")) {
            smoke = true;
        } else if (std.mem.eql(u8, text, "--seed")) {
            argument += 1;
            if (argument == arguments.len) return error.MissingSeedValue;
            seed = try hub_module.Seed.parseLowerHex(arguments[argument]);
        } else return error.UnknownArgument;
    }
    if (verify and smoke) return error.ConflictingVerificationModes;
    if (help) {
        std.log.info("Engine Lab opens one persistent hub. --seed 32-lower-hex --verify --smoke. A/D or arrows move; Space jumps; gamepad stick/south also move/jump. F1/F2 travel within the hub; R resets the whole hub; P pauses; T steps; F3 diagnostics; Escape exits.", .{});
        return;
    }
    const allocator = std.heap.page_allocator;
    if (verify) {
        const result = try verification.verify(allocator, seed);
        for (result.checkpoints) |checkpoint| std.log.info("EL1_HUB_CHECKPOINT tick={d} sha256={s}", .{ checkpoint.tick, checkpoint.digest.formatLowerHex() });
        std.log.info("ENGINE_LAB_HUB_VERIFY_OK schedules=60Hz,mixed ticks=1440 stations=2 jumps={d} landings={d} wall_contacts={d}", .{ result.jumps, result.landings, result.wall_contacts });
        return;
    }
    try run(allocator, seed, smoke);
}

fn run(allocator: std.mem.Allocator, seed: hub_module.Seed, smoke: bool) !void {
    var hub = try hub_module.Hub.init(allocator, seed);
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
    try renderer.initializeUnifiedQueue();
    if (smoke) try renderer.initializeCapture();
    var platform = platform_module.PlatformInput.init();
    var platform_live = true;
    defer if (platform_live) platform.deinit();
    var mapper = actions.Mapper{};
    const queue = renderer.renderQueue();
    try renderer.ensureGpuCapacity(1792, null);
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
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            platform.handleEvent(&event);
            try renderer.handleWindowEvent(&event);
            if (event.type == c.SDL_EVENT_KEY_DOWN and !event.key.repeat) mapper.capturePress(keyPress(event.key.scancode));
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
        if (reset) {
            try hub.reset();
            mapper.suppressHeld(raw);
            command.intent = hub_module.neutral_intent;
            try reportInitial(&hub);
        } else if (command.destination) |destination| {
            const old_updates = [2]u64{ hub.stations[0].updates, hub.stations[1].updates };
            try hub.navigate(destination);
            if (hub.stations[0].updates != old_updates[0] or hub.stations[1].updates != old_updates[1]) return error.NavigationResetStation;
            mapper.suppressHeld(raw);
            command.intent = hub_module.neutral_intent;
            std.log.info("EL1_HUB_TRAVEL destination={s} tick={d} stations_retained=true", .{ @tagName(destination), hub.tick });
        }
        if (command.pause) hub.clock.setPaused(!hub.clock.paused);
        if (command.step) hub.clock.requestSingleStep();
        if (command.diagnostics) hub.diagnostics_enabled = !hub.diagnostics_enabled;
        const now = c.SDL_GetPerformanceCounter();
        const delta = if (reset) 0 else if (smoke) 1.0 / 60.0 else @as(f64, @floatFromInt(now - previous_time)) / @as(f64, @floatFromInt(frequency));
        previous_time = now;
        try hub.advanceFrame(delta, command.intent);
        movement_seen = movement_seen or @abs(hub.actor.worldPosition().x - hub_module.spawn.x) > 0.5;
        jump_seen = jump_seen or hub.jumps > 0;
        collision_seen = collision_seen or hub.wall_contacts > 0;
        const window_camera = renderer.camera();
        try hub.camera.setViewport(window_camera.viewport_width, window_camera.viewport_height);
        renderer.camera().* = hub.camera;
        try view.render(&hub, queue);
        const prepared = queue.prepare();
        if (prepared.ranges.len != 3) return error.HubBatchRangeMismatch;
        const rendered = renderer.renderUnifiedToWindow(prepared) catch |err| {
            std.log.err("Engine Lab frame submission: {s}; SDL: {s}", .{ @errorName(err), sdlError() });
            return err;
        };
        renderer.recordFrameResult(rendered);
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
    std.log.info("EL1_HUB_START seed={s} tick=0 sha256={s}. A/D arrows move; Space jump; F1/F2 travel; R whole-hub reset; P pause; T step; F3 diagnostics; Escape exit.", .{ hub.seed.formatLowerHex(), (try hub.fingerprint()).formatLowerHex() });
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
        c.SDL_SCANCODE_R => .{ .r = true },
        c.SDL_SCANCODE_P => .{ .p = true },
        c.SDL_SCANCODE_T => .{ .t = true },
        c.SDL_SCANCODE_SPACE => .{ .space = true },
        c.SDL_SCANCODE_ESCAPE => .{ .escape = true },
        else => .{},
    };
}
