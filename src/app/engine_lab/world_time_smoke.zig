const std = @import("std");
const h = @import("engine_lab");
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const renderer_module = @import("sdl_gpu_renderer");

/// Actual production D3D12 frames. Capture allocations are outside warm frames.
pub fn run(io: std.Io, tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, capture_dir: []const u8) !void {
    if (!std.mem.eql(u8, try renderer.backendName(), "direct3d12")) return error.WrongWorldTimeBackend;
    var mapper = actions.Mapper{};
    try hub.reset();
    try expectTime(hub, 0, 0, 86_340_000_000);
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "initial");
    for ([_]u64{ 120, 239 }) |target| {
        while (hub.tick < target) try frame(tracking, hub, view, renderer, &mapper, .{}, @as(f64, @floatFromInt(@min(@as(u64, 4), target - hub.tick))) / 240.0);
        if (target == 120) try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "advancing");
    }
    try actions.advance(hub, &mapper, .{}, .{ .pause = true }, 0);
    for (0..3) |_| try frame(tracking, hub, view, renderer, &mapper, .{}, 0.1);
    try expectTime(hub, 239, 0, 86_399_750_000);
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "paused-before-rollover");
    const before = hub.world_time.snapshot();
    try actions.advance(hub, &mapper, .{}, .{ .destination = .springs }, 0);
    if (!std.meta.eql(before, hub.world_time.snapshot()) or hub.calibration.state.fixed_ticks != 0) return error.WorldTimeNativeNavigationMutation;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "navigation-before-rollover");
    try frame(tracking, hub, view, renderer, &mapper, .{ .step = true }, 0.1);
    try expectTime(hub, 240, 1, 0);
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "single-step-rollover");
    const after = hub.world_time.snapshot();
    try actions.advance(hub, &mapper, .{}, .{ .destination = .hierarchy }, 0);
    if (!std.meta.eql(after, hub.world_time.snapshot()) or hub.calibration.state.fixed_ticks != 0) return error.WorldTimeNativeNavigationMutation;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "navigation-after-rollover");
    try hub.reset();
    try hub.navigate(.springs);
    while (hub.tick < 312) try frame(tracking, hub, view, renderer, &mapper, .{ .activate = hub.tick == 0 }, 4.0 / 240.0);
    var move = h.neutral_intent;
    move.move_axis = -1;
    for (0..8) |index| try frame(tracking, hub, view, renderer, &mapper, .{ .activate = index == 0, .intent = move }, 4.0 / 240.0);
    try expectTime(hub, 344, 1, 26_000_000);
    if (hub.impact.projectiles.count() != 1 or hub.impact.effects.particleCount() != 24 or hub.calibration.state.response.offset < 0.01) return error.WorldTimeNativeCoexistenceMissing;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "coexist");
    try actions.advance(hub, &mapper, .{}, .{ .reset = true, .pause = true, .step = true, .activate = true, .destination = .springs }, 0.1);
    try expectTime(hub, 0, 0, 86_340_000_000);
    if (hub.clock.paused or hub.calibration.state.fixed_ticks != 0 or hub.impact.projectiles.count() != 0 or hub.impact.effects.particleCount() != 0) return error.WorldTimeNativeResetMismatch;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "reset");
    std.log.info("ENGINE_LAB_WORLD_TIME_SMOKE_OK backend=direct3d12 captures=8 rollover=239,240 navigation_preserves=true coexist=true reset=true batches=3 warm_allocations=0 drops=0", .{});
}
fn expectTime(hub: *const h.Hub, tick: u64, day: u64, us: u64) !void {
    const value = hub.world_time.snapshot();
    if (hub.tick != tick or value.simulation_ticks != tick or value.day_index != day or value.time_of_day_us != us or value.submicrosecond_remainder != 0 or
        !std.meta.eql(value.configuration, h.world_time_module.configuration)) return error.WorldTimeNativeSnapshotMismatch;
}

fn frame(tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, mapper: *actions.Mapper, command: actions.Actions, seconds: f64) !void {
    const allocations = tracking.alloc_index;
    const resizes = tracking.resize_index;
    const tick = hub.tick;
    const time_before = hub.world_time.snapshot();
    const steps = hub.calibration.state.fixed_ticks;
    try actions.advance(hub, mapper, .{}, command, seconds);
    if (hub.calibration.state.fixed_ticks - steps != hub.tick - tick or hub.impact.effects.tick() != hub.tick or hub.impact.projectiles.tick() != hub.tick) return error.WorldTimeNativeTickMismatch;
    if (hub.world_time.snapshot().simulation_ticks != hub.tick or hub.world_time.snapshot().simulation_ticks - time_before.simulation_ticks != hub.tick - tick) return error.WorldTimeNativeTickMismatch;
    try view.render(hub, renderer.renderQueue());
    renderer.camera().* = hub.camera;
    const prepared = renderer.renderQueue().prepare();
    if (prepared.ranges.len != 3 or prepared.sprites.len > view_module.legacy_sprite_capacity or prepared.sprites.len - view.time_sprite_count > view_module.accepted_calibration_bound or prepared.sprites.len - view.time_sprite_count - view.calibration_sprite_count > view_module.preexisting_sprite_bound) return error.WorldTimeNativeQueueBound;
    if (!try renderer.renderUnifiedToWindow(prepared)) return error.WorldTimeWindowUnavailable;
    if (tracking.alloc_index != allocations or tracking.resize_index != resizes) return error.WorldTimeNativeSteadyAllocation;
    const effects = hub.impact.effects.metrics();
    if (effects.dropped_particles != 0 or effects.rejected_emitters != 0 or hub.impact.bridge.metrics.dropped_effects != 0) return error.WorldTimeNativeDrops;
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
    if (prepared.ranges.len != 3 or prepared.sprites.len > view_module.legacy_sprite_capacity) return error.WorldTimeNativeQueueBound;
    renderer.camera().* = hub.camera;
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
    if (!std.meta.eql(time_before, hub.world_time.snapshot())) return error.WorldTimeCaptureMutation;
    if (!before.eql(try hub.calibration.fingerprint()) or !hub_before.eql(try hub.fingerprint()) or !impact_before.eql(try hub.impact.fingerprint())) return error.WorldTimeCaptureMutation;
    var time_text: [h.world_time_module.diagnostic_capacity]u8 = undefined;
    std.log.info("{s} capture={s}", .{ try h.world_time_module.diagnostic(time_before, &time_text), name });
    std.log.info("WORLD_TIME_CAPTURE name={s} simulation_paused={} presentation=completed hub_tick={d} steps_since_reset={d} offset={d:.6} velocity={d:.6} reference={any} response={any} sprites={d} addition={d} batches={d} projectiles={d} particles={d} calibration_observations_v1={s} time_addition={d} rgba_sha256={x}", .{ name, paused, hub.tick, hub.calibration.state.fixed_ticks, hub.calibration.state.response.offset, hub.calibration.state.response.velocity, hub.calibration.reference.toArray(), (try hub.calibration.presentation(1, true)).response.toArray(), prepared.sprites.len, view.calibration_sprite_count, prepared.ranges.len, hub.impact.projectiles.count(), hub.impact.effects.particleCount(), before.formatLowerHex(), view.time_sprite_count, digest });
}
