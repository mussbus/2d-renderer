const std = @import("std");
const h = @import("engine_lab");
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const renderer_module = @import("sdl_gpu_renderer");
const proof = @import("engine_lab_verification").collectibles;
const routes = @import("engine_lab_verification").traversal;
const traversal = @import("traversal_smoke.zig");
const c = h.collectibles_module;
const sdl = @import("sdl").c;

const Native = struct {
    io: std.Io,
    tracking: *std.testing.FailingAllocator,
    hub: *h.Hub,
    view: *view_module.View,
    renderer: *renderer_module.Renderer,
    dir: []const u8,
    mapper: actions.Mapper = .{},
    frames: usize = 0,
    captures: usize = 0,

    fn frame(self: *Native, command: actions.Actions, seconds: f64) !void {
        if (command.reset or command.destination != null) {
            const old_tick = self.hub.tick;
            const allocations = self.tracking.alloc_index;
            const resizes = self.tracking.resize_index;
            try actions.advance(self.hub, &self.mapper, .{}, command, seconds);
            if (command.reset) {
                if (self.hub.tick != 0) return error.CollectionNativeResetTicks;
            } else {
                if (seconds != 0 or self.hub.tick != old_tick or self.hub.calibration.state.fixed_ticks != 0) return error.CollectionNativeNavigationTicks;
                if (self.tracking.alloc_index != allocations or self.tracking.resize_index != resizes) return error.CollectionNativeNavigationAllocation;
            }
            // Reanchor/reset is a deliberate counter discontinuity; validate the
            // subsequent zero-step submission using the old helper's full checks.
            try traversal.frame(self.tracking, self.hub, self.view, self.renderer, &self.mapper, .{}, 0);
        } else try traversal.frame(self.tracking, self.hub, self.view, self.renderer, &self.mapper, command, seconds);
        if (self.hub.challenge.?.effects.tick() != self.hub.tick) return error.CollectionNativeTickMismatch;
        const metrics = self.hub.challenge.?.effects.metrics();
        if (metrics.dropped_particles != 0 or metrics.rejected_emitters != 0) return error.CollectionNativeDrops;
        self.frames += 1;
    }
    fn capture(self: *Native, name: []const u8) !void {
        const before = try self.hub.challenge.?.fingerprint();
        try traversal.capture(self.io, self.tracking.allocator(), self.hub, self.view, self.renderer, self.dir, name);
        if (!before.eql(try self.hub.challenge.?.fingerprint())) return error.CollectionNativeCaptureMutation;
        const challenge = &self.hub.challenge.?;
        var storage: [72]c.e.ParticleSnapshot = undefined;
        const particles = try challenge.effects.copyParticles(&storage);
        var minimum_age: ?u32 = null;
        for (particles) |p| minimum_age = if (minimum_age) |age| @min(age, p.age_ticks) else p.age_ticks;
        std.log.info("COLLECTION_NATIVE_CAPTURE name={s} run={d} phase={s} progress={d}/6 tick={d} particles={d} minimum_age={any} indicator={} added={d} sha256={s} post_window_hud=in_frame frame_allocations=0 frame_resizes=0 capture_storage=transient drops=0", .{ name, challenge.run, @tagName(challenge.phase), challenge.progress, self.hub.tick, particles.len, minimum_age, (try view_module.indicator(self.hub)) != null, self.view.collectible_sprite_count, before.formatLowerHex() });
        self.captures += 1;
    }
    fn tick(self: *Native, intent: h.Intent) !void {
        const old = self.hub.challenge.?;
        try self.frame(.{ .intent = intent }, 1.0 / 240.0);
        const challenge = &self.hub.challenge.?;
        var name: [80]u8 = undefined;
        if (challenge.last) |event| {
            var storage: [72]c.e.ParticleSnapshot = undefined;
            const id = try c.effectId(event.run, event.ordinal);
            var born: usize = 0;
            for (try challenge.effects.copyParticles(&storage)) |particle| if (particle.effect_id.eql(id)) {
                if (particle.age_ticks != 0) return error.CollectionNativeBirthAge;
                born += 1;
            };
            if (born != 12) return error.CollectionNativeBurstCount;
            try self.capture(try std.fmt.bufPrint(&name, "run-{d}-pickup-{d}-birth", .{ event.run, event.ordinal }));
        } else if (old.last != null) {
            try self.capture(try std.fmt.bufPrint(&name, "run-{d}-pickup-{d}-age-one", .{ challenge.run, challenge.progress }));
        } else if (old.phase == .reaction and challenge.phase != .reaction) {
            try self.capture(try std.fmt.bufPrint(&name, "run-{d}-after-{d}-next", .{ challenge.run, challenge.progress }));
        }
    }
};

pub fn run(io: std.Io, tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, dir: []const u8) !void {
    const expected = try proof.verify(tracking.allocator(), hub.seed);
    var native = Native{ .io = io, .tracking = tracking, .hub = hub, .view = view, .renderer = renderer, .dir = dir };
    try hub.reset();
    try native.frame(.{ .pause = true, .challenge_start = true }, 1);
    if (hub.tick != 0 or !hub.challenge.?.pending_start or hub.challenge.?.phase != .idle) return error.CollectionNativePausedBirth;
    try native.capture("paused-pending-start");
    try native.frame(.{ .step = true }, 0);
    if (hub.tick != 1 or hub.challenge.?.phase != .active) return error.CollectionNativeSingleStep;
    try native.capture("single-step-start");
    try hub.reset();
    native.mapper = .{};
    for (0..2) |run_index| {
        if (run_index != 0) {
            for (0..840) |_| try native.tick(proof.returnInput(hub, -5.7));
            for (0..260) |tick| {
                var intent = h.neutral_intent;
                intent.move_axis = 1;
                intent.jump_pressed = tick == 0;
                intent.jump_held = true;
                try native.tick(intent);
            }
            for (0..300) |_| try native.tick(proof.returnInput(hub, -5.7));
        }
        try native.frame(.{ .challenge_start = true }, 1.0 / 240.0);
        try native.capture(if (run_index == 0) "active-first-target" else "restarted-second-run");
        for (routes.easy) |segment| {
            for (0..segment.ticks) |elapsed| try native.tick(routes.input(hub, segment, elapsed));
            try routes.validateBoundary(hub, segment);
            if (segment.capture and run_index == 0) try native.capture(segment.name);
        }
        for (0..280) |_| try native.tick(proof.returnInput(hub, c.content.spawns[5].position.x));
        if (hub.tick != expected.ticks[run_index] or !(try hub.challenge.?.fingerprint()).eql(expected.digests[run_index])) return error.CollectionNativeRouteMismatch;
        if (hub.navigation_count != 0) return error.CollectionNativeRouteNavigation;
    }
    try native.capture("second-run-complete");
    try native.frame(.{ .destination = .springs }, 0);
    try native.capture("navigation-complete");
    try native.frame(.{ .challenge_start = true }, 1.0 / 240.0);
    const active = try hub.challenge.?.fingerprint();
    try native.frame(.{ .destination = .springs }, 0);
    if (!active.eql(try hub.challenge.?.fingerprint())) return error.CollectionNativeNavigationMutation;
    for ([_][]const u8{ "indicator-current", "indicator-out-2x", "indicator-out-4x" }, 0..) |name, i| {
        if (i != 0) try native.frame(.{ .cycle_zoom = true }, 0);
        try native.capture(name);
    }
    // SDL enumerates only this process's one production window. Resize remains
    // native test orchestration, with no shared renderer API or resource changes.
    var window_count: c_int = 0;
    const windows = sdl.SDL_GetWindows(&window_count);
    if (windows == null or window_count != 1) return error.CollectionNativeWindowEnumeration;
    defer sdl.SDL_free(@ptrCast(windows));
    const window = windows[0];
    var original_w: c_int = 0;
    var original_h: c_int = 0;
    if (!sdl.SDL_GetWindowSize(window, &original_w, &original_h)) return nativeSdlFailure("SDL_GetWindowSize");
    for ([_][2]c_int{ .{ 640, 480 }, .{ 960, 720 }, .{ 1280, 720 } }) |size| {
        if (!sdl.SDL_SetWindowSize(window, size[0], size[1]) or !sdl.SDL_SyncWindow(window)) return nativeSdlFailure("SDL_SetWindowSize/SDL_SyncWindow");
        var width: c_int = 0;
        var height: c_int = 0;
        if (!sdl.SDL_GetWindowSizeInPixels(window, &width, &height) or width <= 0 or height <= 0) return nativeSdlFailure("SDL_GetWindowSizeInPixels");
        for (std.enums.values(h.Zoom)) |zoom| {
            hub.zoom = zoom;
            try hub.setViewport(@intCast(width), @intCast(height));
            try native.frame(.{}, 0);
            var name: [80]u8 = undefined;
            try native.capture(try std.fmt.bufPrint(&name, "window-{d}x{d}-zoom-{s}", .{ width, height, @tagName(zoom) }));
        }
    }
    if (!sdl.SDL_SetWindowSize(window, original_w, original_h) or !sdl.SDL_SyncWindow(window)) return nativeSdlFailure("SDL_SetWindowSize/SDL_SyncWindow restore");
    // Isolated coexistence fixture; the course above used no staged transforms.
    try hub.reset();
    native.mapper = .{};
    try native.frame(.{ .destination = .springs }, 0);
    try native.frame(.{ .challenge_start = true, .activate = true }, 1.0 / 240.0);
    for (0..310) |_| try native.frame(.{}, 1.0 / 240.0);
    try hub.actor.stageControlledTransform(c.content.spawns[0].position, .right);
    try native.frame(.{}, 1.0 / 240.0);
    if (hub.impact.observations.contacts != 1 or hub.challenge.?.progress != 1) return error.CollectionNativeSimultaneous;
    try hub.cycleZoom();
    try hub.cycleZoom();
    try native.capture("simultaneous-bursts");
    const reacting = try hub.challenge.?.fingerprint();
    try native.frame(.{ .destination = .springs }, 0);
    if (!reacting.eql(try hub.challenge.?.fingerprint())) return error.CollectionNativeNavigationMutation;
    try native.capture("navigation-reaction");
    try native.frame(.{ .activate = true }, 1.0 / 240.0);
    try native.capture("both-effects-and-flight");
    try native.frame(.{ .reset = true, .challenge_start = true, .step = true }, 1);
    if (hub.tick != 0 or hub.challenge.?.phase != .idle or hub.challenge.?.effects.particleCount() != 0 or hub.impact.effects.particleCount() != 0 or hub.impact.projectiles.count() != 0 or hub.zoom != .current) return error.CollectionNativeReset;
    try native.capture("whole-hub-reset");
    std.log.info("ENGINE_LAB_COLLECTION_SMOKE_OK frames={d} captures={d} runs=2 pickups=12 navigation_in_route=0 post_window_hud=true allocations=0 resizes=0 drops=0 batches=3", .{ native.frames, native.captures });
}

fn nativeSdlFailure(operation: []const u8) error{CollectionNativeWindowFailure} {
    const message = sdl.SDL_GetError();
    std.log.err("collection native {s}: SDL: {s}", .{ operation, if (message == null) "no diagnostic" else std.mem.span(message) });
    return error.CollectionNativeWindowFailure;
}
