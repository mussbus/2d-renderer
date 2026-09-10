const std = @import("std");
const h = @import("engine_lab");
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const renderer_module = @import("sdl_gpu_renderer");
const routes = @import("engine_lab_verification").traversal;

/// Bounded native evidence client of the same immutable headless route inputs.
pub fn run(io: std.Io, tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, capture_dir: []const u8) !void {
    if (hub.construction != .expanded or !std.mem.eql(u8, try renderer.backendName(), "direct3d12")) return error.TraversalNativeConstruction;
    const expected = try routes.verify(tracking.allocator(), hub.seed);
    var next: usize = 0;
    var frames: usize = 0;
    var captures: usize = 0;
    var mapper = actions.Mapper{};
    for ([_]routes.Scenario{ .easy, .shortcut }) |scenario| {
        try hub.reset();
        mapper = .{};
        if (!expected.checkpoints[next].digest.eql(try hub.traversalFingerprint())) return error.TraversalNativeInitialMismatch;
        next += 1;
        if (scenario == .easy) {
            try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "expanded-initial");
            captures += 1;
        }
        for (routes.segments(scenario)) |segment| {
            var elapsed: u64 = 0;
            while (elapsed < segment.ticks) {
                const count = routes.steps(segment, elapsed, false, frames);
                try frame(tracking, hub, view, renderer, &mapper, .{ .intent = routes.input(hub, segment, elapsed), .cycle_zoom = frames % 24 == 0 }, @as(f64, @floatFromInt(count)) / 240.0);
                frames += 1;
                elapsed += count;
            }
            try routes.validateBoundary(hub, segment);
            if (hub.tick != expected.checkpoints[next].tick or !expected.checkpoints[next].digest.eql(try hub.traversalFingerprint())) return error.TraversalNativeCheckpointMismatch;
            next += 1;
            if (segment.capture) {
                try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, segment.name);
                captures += 1;
            }
        }
    }
    try actions.advance(hub, &mapper, .{}, .{ .pause = true }, 0);
    const paused = try hub.traversalFingerprint();
    for (0..3) |_| try frame(tracking, hub, view, renderer, &mapper, .{ .intent = hub.pending }, 0.1);
    if (!paused.eql(try hub.traversalFingerprint())) return error.TraversalNativePausedMutation;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "paused-upper");
    captures += 1;
    const tick = hub.tick;
    try frame(tracking, hub, view, renderer, &mapper, .{ .step = true }, 0.1);
    if (hub.tick != tick + 1) return error.TraversalNativeStepMismatch;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "single-step-upper");
    captures += 1;
    const time = hub.world_time.snapshot();
    try actions.advance(hub, &mapper, .{}, .{ .destination = .springs }, 0);
    if (!std.meta.eql(time, hub.world_time.snapshot()) or hub.calibration.state.fixed_ticks != 0) return error.TraversalNativeNavigationMutation;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "navigation");
    captures += 1;
    try hub.reset();
    try hub.navigate(.springs);
    mapper = .{};
    while (hub.tick < 319) try frame(tracking, hub, view, renderer, &mapper, .{ .activate = hub.tick < 8 }, 1.0 / 240.0);
    if (hub.impact.effects.particleCount() != 192 or hub.impact.observations.contacts != 8) return error.TraversalNativeFiringMismatch;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "firing-effects");
    captures += 1;
    var movement = h.neutral_intent;
    movement.jump_pressed = true;
    movement.jump_held = true;
    movement.dash_pressed = true;
    movement.move_axis = 1;
    try frame(tracking, hub, view, renderer, &mapper, .{ .activate = true, .intent = movement }, 1.0 / 240.0);
    movement.jump_pressed = false;
    movement.dash_pressed = false;
    for (0..31) |_| try frame(tracking, hub, view, renderer, &mapper, .{ .intent = movement }, 1.0 / 240.0);
    if (hub.impact.projectiles.count() != 1 or hub.impact.effects.particleCount() != 192 or @abs(hub.calibration.state.response.offset) < 0.01) return error.TraversalNativeCoexistenceMissing;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "traversal-coexist");
    captures += 1;
    try actions.advance(hub, &mapper, .{}, .{ .reset = true, .pause = true, .step = true, .activate = true, .destination = .springs, .intent = movement }, 0.1);
    if (hub.tick != 0 or hub.construction != .expanded or hub.clock.paused or hub.impact.projectiles.count() != 0 or hub.impact.effects.particleCount() != 0) return error.TraversalNativeResetMismatch;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "expanded-reset");
    captures += 1;
    std.log.info("ENGINE_LAB_TRAVERSAL_SMOKE_OK backend=direct3d12 route_frames={d} captures={d} routes=easy,air,dash checkpoints={d} pause_step=true navigation=true reset=true batches=3 warm_allocations=0 drops=0", .{ frames, captures, next });
    const zoom_before = try hub.traversalFingerprint();
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "zoom-current");
    for ([_][]const u8{ "zoom-out-2x", "zoom-out-4x" }) |name| {
        try frame(tracking, hub, view, renderer, &mapper, .{ .cycle_zoom = true }, 0);
        if (!zoom_before.eql(try hub.traversalFingerprint())) return error.ZoomChangedSimulation;
        try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, name);
    }
    try actions.advance(hub, &mapper, .{}, .{ .reset = true, .cycle_zoom = true }, 0);
    if (hub.zoom != .current or hub.tick != 0) return error.ZoomResetMismatch;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "zoom-reset");
    std.log.info("ENGINE_LAB_ZOOM_SMOKE_OK cycle=1,2,4 reset=1 simulation_unchanged=true captures=4 window_camera=preserved player_corners=in_frame hud_sections=3", .{});
}

fn frame(tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, mapper: *actions.Mapper, command: actions.Actions, seconds: f64) !void {
    const allocations = tracking.alloc_index;
    const resizes = tracking.resize_index;
    const tick = hub.tick;
    const time_before = hub.world_time.snapshot();
    const steps = hub.calibration.state.fixed_ticks;
    try actions.advance(hub, mapper, .{}, command, seconds);
    if (hub.calibration.state.fixed_ticks - steps != hub.tick - tick or hub.impact.effects.tick() != hub.tick or hub.impact.projectiles.tick() != hub.tick) return error.TraversalNativeTickMismatch;
    if (hub.world_time.snapshot().simulation_ticks != hub.tick or hub.world_time.snapshot().simulation_ticks - time_before.simulation_ticks != hub.tick - tick) return error.TraversalNativeTickMismatch;
    try view.render(hub, renderer.renderQueue());
    renderer.camera().* = hub.camera;
    const prepared = renderer.renderQueue().prepare();
    if (prepared.ranges.len != 3 or prepared.sprites.len > view_module.sprite_capacity) return error.TraversalNativeQueueBound;
    if (!try renderer.renderUnifiedToWindow(prepared)) return error.WorldTimeWindowUnavailable;
    try validatePresentation(hub, view, renderer);
    if (tracking.alloc_index != allocations or tracking.resize_index != resizes) return error.TraversalNativeSteadyAllocation;
    const effects = hub.impact.effects.metrics();
    if (effects.dropped_particles != 0 or effects.rejected_emitters != 0 or hub.impact.bridge.metrics.dropped_effects != 0) return error.TraversalNativeDrops;
}

fn capture(io: std.Io, allocator: std.mem.Allocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, capture_dir: []const u8, name: []const u8) !void {
    const paused = hub.clock.paused;
    hub.clock.paused = true;
    defer hub.clock.paused = paused;
    const time_before = hub.world_time.snapshot();
    const before = try hub.calibration.fingerprint();
    const hub_before = try hub.fingerprint();
    const impact_before = try hub.impact.fingerprint();
    try view.render(hub, renderer.renderQueue());
    const prepared = renderer.renderQueue().prepare();
    if (prepared.ranges.len != 3 or prepared.sprites.len > view_module.sprite_capacity) return error.TraversalNativeQueueBound;
    renderer.camera().* = hub.camera;
    // Capture the camera that actually survived window submission. Reassigning
    // it here would hide drawable-refresh bugs from the offscreen evidence.
    if (!try renderer.renderUnifiedToWindow(prepared)) return error.WorldTimeWindowUnavailable;
    try validatePresentation(hub, view, renderer);
    var pixels = try renderer.captureUnified(prepared);
    defer pixels.deinit();
    var header_buffer: [64]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buffer, "P6\n{d} {d}\n255\n", .{ pixels.width, pixels.height });
    const ppm = try allocator.alloc(u8, header.len + pixels.bytes().len / 4 * 3);
    defer allocator.free(ppm);
    @memcpy(ppm[0..header.len], header);
    const rgba = pixels.bytes();
    for (0..rgba.len / 4) |index| @memcpy(ppm[header.len + index * 3 ..][0..3], rgba[index * 4 ..][0..3]);
    try std.Io.Dir.cwd().createDirPath(io, capture_dir);
    var path: [1024]u8 = undefined;
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.bufPrint(&path, "{s}/{s}.ppm", .{ capture_dir, name }), .data = ppm });
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(rgba, &digest, .{});
    if (!std.meta.eql(time_before, hub.world_time.snapshot())) return error.TraversalCaptureMutation;
    if (!before.eql(try hub.calibration.fingerprint()) or !hub_before.eql(try hub.fingerprint()) or !impact_before.eql(try hub.impact.fingerprint())) return error.TraversalCaptureMutation;
    var time_text: [h.world_time_module.diagnostic_capacity]u8 = undefined;
    std.log.info("{s} capture={s}", .{ try h.world_time_module.diagnostic(time_before, &time_text), name });
    std.log.info("TRAVERSAL_NATIVE_OBSERVATION name={s} root={any} camera={any} sha256={s}", .{ name, hub.actor.worldPosition(), hub.camera.center, (try hub.traversalFingerprint()).formatLowerHex() });
    std.log.info("TRAVERSAL_CAPTURE name={s} simulation_paused={} presentation=completed hub_tick={d} steps_since_reset={d} offset={d:.6} velocity={d:.6} reference={any} response={any} sprites={d} addition={d} batches={d} projectiles={d} particles={d} calibration_observations_v1={s} time_addition={d} rgba_sha256={x}", .{ name, paused, hub.tick, hub.calibration.state.fixed_ticks, hub.calibration.state.response.offset, hub.calibration.state.response.velocity, hub.calibration.reference.toArray(), (try hub.calibration.presentation(1, true)).response.toArray(), prepared.sprites.len, view.calibration_sprite_count, prepared.ranges.len, hub.impact.projectiles.count(), hub.impact.effects.particleCount(), before.formatLowerHex(), view.time_sprite_count, digest });
}

fn validatePresentation(hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer) !void {
    const camera = renderer.camera().*;
    if (!std.meta.eql(try hub.camera.uniform(), try camera.uniform())) return error.WindowCameraChangedAfterPublication;
    for (view.hud_ranges) |range| {
        if (range.start >= range.end) return error.EmptyWindowHud;
        for (view.commands.commands[range.start..range.end]) |command| {
            for ([_]f32{ -0.5, 0.5 }) |side| {
                const clip = try camera.worldToClip(.{ .x = command.world_position[0] + side * command.scale[0], .y = command.world_position[1] + side * command.scale[1] }, 1);
                if (@abs(clip.x) > 1 or @abs(clip.y) > 1) return error.WindowHudOutsideFrame;
            }
        }
    }
    const delta = (try hub.renderedActorPosition()).sub(hub.actor.worldPosition());
    for (view.actor_queue.prepare().sprites) |part| {
        const cosine = @cos(part.rotation);
        const sine = @sin(part.rotation);
        for ([_]f32{ 0, 1 }) |x| for ([_]f32{ 0, 1 }) |y| {
            const local_x = (x - part.pivot[0]) * part.scale[0];
            const local_y = (y - part.pivot[1]) * part.scale[1];
            const clip = try camera.worldToClip(.{ .x = part.world_position[0] + delta.x + local_x * cosine - local_y * sine, .y = part.world_position[1] + delta.y + local_x * sine + local_y * cosine }, part.camera_x_factor);
            if (@abs(clip.x) > 1 or @abs(clip.y) > 1) return error.WindowPlayerOutsideFrame;
        };
    }
}
