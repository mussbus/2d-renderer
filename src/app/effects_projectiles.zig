const std = @import("std");
const c = @import("sdl").c;
const scene_module = @import("effects_projectiles_scene");
const view = @import("effects_projectiles_view");
const renderer_module = @import("sdl_gpu_renderer");
const fixed_step = @import("fixed_step");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var smoke = false;
    var capture = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--smoke")) smoke = true else if (std.mem.eql(u8, arg, "--capture")) capture = true else return error.UnknownArgument;
    }
    if (capture and !smoke) return error.CaptureRequiresSmoke;
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer if (debug_allocator.deinit() == .leak) @panic("E1 proof allocator leak");
    var tracking = std.testing.FailingAllocator.init(debug_allocator.allocator(), .{});
    const allocator = tracking.allocator();
    var scene = try scene_module.Scene.init(allocator, true);
    defer scene.deinit();
    var renderer = try renderer_module.Renderer.init(allocator, smoke, null);
    var renderer_live = true;
    defer if (renderer_live) renderer.deinit();
    try renderer.initializeUnifiedQueue();
    try renderer.ensureGpuCapacity(1792, null);
    if (capture) try renderer.initializeCapture();
    if (!std.mem.eql(u8, try renderer.backendName(), "direct3d12")) return error.WrongGpuBackend;
    const queue = renderer.renderQueue();
    queue.markStabilized();
    const initial = renderer.metrics();
    const initial_allocations = tracking.allocations;
    var clock = try fixed_step.Clock.init(.{});
    var previous_time = c.SDL_GetTicksNS();
    var running = true;
    var debug = true;
    var frames: u32 = 0;
    var peak_sprites: u32 = 0;
    var peak_draws: u32 = 0;
    var current_seed = scene_module.seed;
    var window: ?*c.SDL_Window = null;
    const started = c.SDL_GetTicksNS();
    var simulation_ns: u64 = 0;
    std.log.info("E1: Space pause, period step, R same seed, N next seed, P spawn, D deflect, F1 debug, Esc quit. Blue expires; green bounces; red impacts; yellow passes through.", .{});
    while (running and (!smoke or frames < 180)) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            try renderer.handleWindowEvent(&event);
            switch (event.type) {
                c.SDL_EVENT_QUIT => running = false,
                c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => running = false,
                c.SDL_EVENT_WINDOW_SHOWN => {
                    window = c.SDL_GetWindowFromID(event.window.windowID);
                },
                c.SDL_EVENT_KEY_DOWN => {
                    if (event.key.repeat) continue;
                    switch (event.key.scancode) {
                        c.SDL_SCANCODE_ESCAPE => running = false,
                        c.SDL_SCANCODE_SPACE => clock.setPaused(!clock.paused),
                        c.SDL_SCANCODE_PERIOD => clock.requestSingleStep(),
                        c.SDL_SCANCODE_R => {
                            try scene.reset(current_seed, true);
                            clock = try fixed_step.Clock.init(.{});
                        },
                        c.SDL_SCANCODE_N => {
                            current_seed.bytes[0] +%= 1;
                            try scene.reset(current_seed, true);
                            clock = try fixed_step.Clock.init(.{});
                        },
                        c.SDL_SCANCODE_P => scene.spawnExtra() catch |err| switch (err) {
                            error.CapacityExceeded, error.EventCapacity => std.log.warn("E1 projectile request rejected: {s}", .{@errorName(err)}),
                            else => return err,
                        },
                        c.SDL_SCANCODE_D => try scene.deflectFirst(),
                        c.SDL_SCANCODE_F1 => debug = !debug,
                        else => {},
                    }
                },
                else => {},
            }
        }
        const now = c.SDL_GetTicksNS();
        const frame = try clock.beginFrame(if (smoke) 1.0 / 60.0 else @as(f64, @floatFromInt(now - previous_time)) / 1e9);
        previous_time = now;
        const before_simulation = c.SDL_GetTicksNS();
        for (0..frame.substeps) |_| try scene.step(true);
        simulation_ns += c.SDL_GetTicksNS() - before_simulation;
        queue.beginFrame();
        try view.submit(&scene, queue, if (smoke) 1 else @floatCast(frame.interpolation_alpha), debug);
        const rendered = try renderer.renderUnifiedToWindow(queue.prepare());
        renderer.recordFrameResult(rendered);
        if (smoke and !rendered) return error.ProofWindowUnavailable;
        peak_sprites = @max(peak_sprites, queue.frame_metrics.submitted_sprites);
        peak_draws = @max(peak_draws, queue.frame_metrics.sprite_draws);
        if (frames % 60 == 0) {
            var title_buffer: [256]u8 = undefined;
            const title = try std.fmt.bufPrintZ(&title_buffer, "E1 | tick {d} | projectiles {d} emitters {d} particles {d} | Space pause . step R reset N seed P spawn D deflect F1 debug", .{ scene.projectiles.tick(), scene.projectiles.count(), scene.effects.emitterCount(), scene.effects.particleCount() });
            if (window) |handle| if (!c.SDL_SetWindowTitle(handle, title)) {
                std.log.err("SDL_SetWindowTitle(E1): {s}", .{c.SDL_GetError()});
                return error.WindowTitleFailure;
            };
        }
        frames += 1;
        if (!smoke) c.SDL_Delay(1);
    }
    const elapsed_ns = c.SDL_GetTicksNS() - started;
    const steady = renderer.metrics();
    if (tracking.allocations != initial_allocations or queue.lifetime_metrics.cpu_allocations_after_stabilization != 0 or
        steady.gpu_resource_creations != initial.gpu_resource_creations or steady.upload_buffer_growths != initial.upload_buffer_growths)
        return error.SteadyStateAllocationGrowth;
    if (smoke and (scene.statistics.collisions < 3 or scene.statistics.deflections < 1 or scene.statistics.expirations < 3 or
        scene.statistics.peak_projectiles < 4 or scene.bridge.metrics.trail_samples == 0 or peak_draws != 1 or peak_sprites < 20)) return error.MissingProofBehavior;
    std.log.info("E1_PROOF frames={d} ticks={d} collisions={d} deflections={d} expirations={d} peak_projectiles={d} peak_emitters={d} peak_particles={d} trail_samples={d} peak_sprites={d} peak_draws={d} dropped_particles={d} dropped_effects={d} steady_allocations={d} simulation_ns={d} wall_ns={d}", .{
        frames,                                scene.projectiles.tick(),                   scene.statistics.collisions,        scene.statistics.deflections, scene.statistics.expirations, scene.statistics.peak_projectiles,
        scene.effects.metrics().peak_emitters, scene.effects.metrics().peak_particles,     scene.bridge.metrics.trail_samples, peak_sprites,                 peak_draws,                   scene.effects.metrics().dropped_particles,
        scene.bridge.metrics.dropped_effects,  tracking.allocations - initial_allocations, simulation_ns,                      elapsed_ns,
    });
    // Explicit acceptance readback is outside the steady-state render loop.
    // CapturedFrame and PPM output own bounded temporary CPU allocations.
    if (capture) {
        try std.Io.Dir.cwd().createDirPath(init.io, ".zig-cache/e1-captures");
        for ([_]u32{ 120, 176, 212, 256 }) |tick| {
            try scene.reset(scene_module.seed, true);
            for (0..tick) |_| try scene.step(true);
            queue.beginFrame();
            try view.submit(&scene, queue, 1, true);
            var pixels = try renderer.captureUnified(queue.prepare());
            defer pixels.deinit();
            const header = try std.fmt.allocPrint(allocator, "P6\n{d} {d}\n255\n", .{ pixels.width, pixels.height });
            defer allocator.free(header);
            const ppm = try allocator.alloc(u8, header.len + @as(usize, pixels.width) * pixels.height * 3);
            defer allocator.free(ppm);
            @memcpy(ppm[0..header.len], header);
            var changed: usize = 0;
            for (0..@as(usize, pixels.width) * pixels.height) |index| {
                @memcpy(ppm[header.len + index * 3 ..][0..3], pixels.bytes()[index * 4 ..][0..3]);
                if (!std.mem.eql(u8, pixels.bytes()[0..4], pixels.bytes()[index * 4 ..][0..4])) changed += 1;
            }
            if (changed < 100) return error.EmptyProofReadback;
            var path_buffer: [96]u8 = undefined;
            const path = try std.fmt.bufPrint(&path_buffer, ".zig-cache/e1-captures/tick_{d}.ppm", .{tick});
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = ppm });
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(pixels.bytes(), &digest, .{});
            std.log.info("E1_CAPTURE tick={d} changed_pixels={d} rgba_sha256={x}", .{ tick, changed, digest });
        }
    }
    const final = renderer.deinitWithMetrics();
    renderer_live = false;
    if (final.gpu_resource_creations != final.gpu_resource_releases or final.fence_acquisitions != final.fence_releases) return error.GpuResourceLeak;
    std.log.info("E1_PROOF_OK backend=direct3d12 created={d} released={d} fences_acquired={d} fences_released={d}", .{ final.gpu_resource_creations, final.gpu_resource_releases, final.fence_acquisitions, final.fence_releases });
}
