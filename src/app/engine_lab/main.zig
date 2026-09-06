const std = @import("std");
const labs = @import("engine_lab");
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const renderer_module = @import("sdl_gpu_renderer");
const platform_module = @import("sdl_input");
const art_pack = @import("art_pack");
const physical = @import("physical_input");
const c = @import("sdl").c;

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    var index: usize = 0;
    var seed = try labs.Seed.parseLowerHex(labs.default_seed);
    var verify = false;
    var smoke = false;
    var list = false;
    var argument: usize = 1;
    while (argument < arguments.len) : (argument += 1) {
        const text = arguments[argument];
        if (std.mem.eql(u8, text, "--list") or std.mem.eql(u8, text, "--help")) {
            list = true;
        } else if (std.mem.eql(u8, text, "--verify")) {
            verify = true;
        } else if (std.mem.eql(u8, text, "--smoke")) {
            smoke = true;
        } else if (std.mem.eql(u8, text, "--lab") or std.mem.eql(u8, text, "--seed")) {
            argument += 1;
            if (argument == arguments.len) return error.MissingArgumentValue;
            if (std.mem.eql(u8, text, "--lab")) {
                index = try labs.findDefinition(arguments[argument]);
            } else {
                seed = try labs.Seed.parseLowerHex(arguments[argument]);
            }
        } else return error.UnknownArgument;
    }
    if (list) {
        for (labs.registry) |definition| std.log.info("{s}: {s} - {s}", .{ definition.id, definition.name, definition.description });
        std.log.info("Engine Lab: --lab ID --seed 32-lower-hex --verify --smoke. F1/F2 select, R reset, P play/pause, T step, Space impulse (overview), Escape exit.", .{});
        return;
    }
    const allocator = std.heap.page_allocator;
    if (verify) {
        const checkpoints = try labs.verifyRepeat(.{ .allocator = allocator }, seed);
        for (checkpoints) |checkpoint| reportCheckpoint("determinism-fixed-step", checkpoint);
        std.log.info("ENGINE_LAB_DETERMINISM_OK schedules=60Hz,mixed ticks=960 seed={s}", .{seed.formatLowerHex()});
        return;
    }
    try run(allocator, index, seed, smoke);
}

fn run(allocator: std.mem.Allocator, index: usize, seed: labs.Seed, smoke: bool) !void {
    var host = try labs.Host.init(.{ .allocator = allocator }, index, seed, null);
    defer host.deinit() catch |err| std.debug.panic("Engine Lab shutdown: {s}", .{@errorName(err)});
    var renderer = renderer_module.Renderer.init(allocator, smoke, null) catch |err| {
        std.log.err("Engine Lab renderer initialization: {s}; SDL: {s}", .{ @errorName(err), sdlError() });
        return err;
    };
    var renderer_live = true;
    defer if (renderer_live) renderer.deinit();
    var art = try art_pack.Definition.init(allocator, .{
        .stable_name = "engine_lab_ui",
        .pages = &.{.{
            .id = @enumFromInt(1),
            .stable_name = "neutral_white",
            .asset_path = "engine_lab/white.png",
            .sampling = .nearest,
            .expected_width = 2,
            .expected_height = 2,
        }},
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
    var view = view_module.View{};
    const queue = renderer.renderQueue();
    // Warm the maximum bounded EL1 HUD/trace submission and GPU capacity outside the loop.
    try renderer.ensureGpuCapacity(1792, null);
    queue.markStabilized();
    const resources = renderer.metrics();
    reportActive(&host);
    var reported = host.active.?.checkpoint_count;
    var previous_time = c.SDL_GetPerformanceCounter();
    const frequency = c.SDL_GetPerformanceFrequency();
    if (frequency == 0) return error.InvalidPerformanceFrequency;
    var frame: u32 = 0;
    var rendered_frames: u32 = 0;
    var draw_calls: u64 = 0;
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
            command = switch (frame) {
                0 => .{ .pause = true },
                4 => .{ .select = 1 },
                5 => .{ .pause = true },
                9 => .{ .reset = true },
                10 => .{ .step = true },
                12 => .{ .select = 0 },
                13 => .{ .pause = true },
                else => .{},
            };
        }
        if (command.exit) break;
        if (try applyActions(&host, command)) {
            mapper.suppressHeld(raw);
            reported = host.active.?.checkpoint_count;
            reportActive(&host);
        }
        const now = c.SDL_GetPerformanceCounter();
        const delta = if (smoke) 1.0 / 60.0 else @as(f64, @floatFromInt(now - previous_time)) / @as(f64, @floatFromInt(frequency));
        previous_time = now;
        try host.advanceFrame(delta);
        const active = host.active.?;
        for (active.checkpoints[reported..active.checkpoint_count]) |checkpoint| reportCheckpoint(active.definition().id, checkpoint);
        reported = active.checkpoint_count;
        try view.render(&host, queue);
        const rendered = renderer.renderUnifiedToWindow(queue.prepare()) catch |err| {
            std.log.err("Engine Lab frame submission: {s}; SDL: {s}", .{ @errorName(err), sdlError() });
            return err;
        };
        renderer.recordFrameResult(rendered);
        if (rendered) {
            rendered_frames += 1;
            draw_calls += queue.frame_metrics.sprite_draws;
        }
        if (smoke and frame == 15) break;
        if (!rendered or host.clock.paused) c.SDL_Delay(8);
    }
    if (smoke) {
        if (rendered_frames != 16 or draw_calls != 16) return error.EngineLabSmokeSubmissionMismatch;
        var capture = try renderer.captureUnified(queue.prepare());
        defer capture.deinit();
        const rgba = capture.bytes();
        var changed: usize = 0;
        var offset: usize = 4;
        while (offset + 4 <= rgba.len) : (offset += 4) {
            if (!std.mem.eql(u8, rgba[0..4], rgba[offset .. offset + 4])) changed += 1;
        }
        if (changed < 100) return error.EngineLabSmokeUniformFrame;
        std.log.info("Engine Lab physical proof: frames={d} draws={d} readback_changed_pixels={d}", .{ rendered_frames, draw_calls, changed });
    }
    const steady = renderer.metrics();
    if (steady.gpu_resource_creations != resources.gpu_resource_creations or
        steady.upload_buffer_growths != resources.upload_buffer_growths or
        queue.lifetime_metrics.cpu_allocations_after_stabilization != 0)
    {
        return error.EngineLabSteadyStateGrowth;
    }
    platform.deinit();
    platform_live = false;
    const final = renderer.deinitWithMetrics();
    renderer_live = false;
    if (final.gpu_resource_creations != final.gpu_resource_releases or final.fence_acquisitions != final.fence_releases) return error.EngineLabGpuResourceLeak;
    std.log.info("ENGINE_LAB_SHUTDOWN_OK frames={d} resources={d}/{d} fences={d}/{d} queue_allocations_after_warmup=0", .{
        rendered_frames, final.gpu_resource_creations, final.gpu_resource_releases, final.fence_acquisitions, final.fence_releases,
    });
    if (smoke) std.log.info("ENGINE_LAB_SMOKE_OK switches=2 resets=1 backend={s}", .{"direct3d12"});
}

fn applyActions(host: *labs.Host, command: actions.Actions) !bool {
    if (command.select) |index| {
        try host.switchTo(index);
        return true;
    }
    if (command.reset) {
        try host.reset();
        return true;
    }
    if (command.pause and !host.active.?.complete()) host.clock.setPaused(!host.clock.paused);
    if (command.step) host.clock.requestSingleStep();
    if (command.impulse and host.active.?.definition().kind == .integration) host.pending_impulse = true;
    return false;
}

fn reportActive(host: *const labs.Host) void {
    const active = host.active.?;
    std.log.info("Engine Lab active={s} seed={s} paused=true tick=0. F1/F2 select; R reset; P play/pause; T step; Space impulse; Escape exit.", .{ active.definition().id, active.seed.formatLowerHex() });
    reportCheckpoint(active.definition().id, active.checkpoints[0]);
}

fn reportCheckpoint(id: []const u8, checkpoint: labs.Checkpoint) void {
    std.log.info("EL1_CHECKPOINT lab={s} tick={d} sha256={s}", .{ id, checkpoint.tick, checkpoint.digest.formatLowerHex() });
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
        c.SDL_SCANCODE_R => .{ .r = true },
        c.SDL_SCANCODE_P => .{ .p = true },
        c.SDL_SCANCODE_T => .{ .t = true },
        c.SDL_SCANCODE_SPACE => .{ .space = true },
        c.SDL_SCANCODE_ESCAPE => .{ .escape = true },
        else => .{},
    };
}
