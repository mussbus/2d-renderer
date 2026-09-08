const std = @import("std");
const h = @import("engine_lab");
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const renderer_module = @import("sdl_gpu_renderer");
const fixture = @import("engine_lab_verification").calibration;

/// Bounded native evidence through the production controller, binding, view and
/// SDL3 D3D12 readback. Capture allocations occur outside measured warm frames.
pub fn run(io: std.Io, tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, capture_dir: []const u8) !void {
    if (!std.mem.eql(u8, try renderer.backendName(), "direct3d12")) return error.WrongCalibrationBackend;
    var mapper = actions.Mapper{};
    try hub.reset();
    // Match the headless semantic fixture; pauses add no ticks, the extra step
    // consumes the same intent at tick 330 as normal execution would consume.
    const expected = try fixture.verify(tracking.allocator(), hub.seed);
    for (expected.checkpoints[1..]) |checkpoint| {
        while (hub.tick < checkpoint.tick) try frame(tracking, hub, view, renderer, &mapper, .{ .intent = fixture.inputAt(hub.tick) }, @as(f64, @floatFromInt(@min(@as(u64, 4), checkpoint.tick - hub.tick))) / 240.0);
        if (!(try hub.calibration.fingerprint()).eql(checkpoint.digest)) return error.CalibrationNativeCheckpointMismatch;
        switch (hub.tick) {
            30 => try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "acceleration"),
            150 => try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "braking"),
            330 => {
                try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "reversal");
                try actions.advance(hub, &mapper, .{}, .{ .pause = true }, 0);
                const frozen = try hub.calibration.fingerprint();
                for (0..3) |_| try frame(tracking, hub, view, renderer, &mapper, .{}, 0.04);
                if (hub.tick != 330 or !frozen.eql(try hub.calibration.fingerprint())) return error.CalibrationNativePauseMutation;
                try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "paused");
                try frame(tracking, hub, view, renderer, &mapper, .{ .step = true, .intent = fixture.inputAt(hub.tick) }, 0.04);
                if (hub.tick != 331 or hub.calibration.state.fixed_ticks != 331) return error.CalibrationNativeSingleStepMismatch;
                try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "single-step");
                try actions.advance(hub, &mapper, .{}, .{ .pause = true }, 0);
            },
            1440 => try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "settled"),
            else => {},
        }
    }
    var move = h.neutral_intent;
    move.move_axis = -1;
    for (0..8) |_| try frame(tracking, hub, view, renderer, &mapper, .{ .intent = move }, 4.0 / 240.0);
    try actions.advance(hub, &mapper, .{}, .{ .pause = true, .destination = .springs }, 0);
    if (hub.tick != 1472 or hub.calibration.state.fixed_ticks != 0 or hub.calibration.state.driver_velocity != 0 or hub.calibration.state.response.offset != 0 or !hub.calibration.reference.approxEqAbs(hub.calibration.previous_reference, 0)) return error.CalibrationNativeReanchorMismatch;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "navigation");
    try actions.advance(hub, &mapper, .{}, .{ .reset = true }, 0);
    try actions.advance(hub, &mapper, .{}, .{ .destination = .springs }, 0);
    while (hub.tick < 312) try frame(tracking, hub, view, renderer, &mapper, .{ .activate = hub.tick == 0 }, 4.0 / 240.0);
    for (0..8) |index| try frame(tracking, hub, view, renderer, &mapper, .{ .activate = index == 0, .intent = move }, 4.0 / 240.0);
    if (hub.impact.projectiles.count() != 1 or hub.impact.effects.particleCount() != 24 or hub.calibration.state.response.offset < 0.01) return error.CalibrationNativeCoexistenceMissing;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "coexist");
    try actions.advance(hub, &mapper, .{}, .{ .reset = true, .step = true, .activate = true, .destination = .springs }, 0.1);
    if (hub.tick != 0 or hub.calibration.state.fixed_ticks != 0 or hub.calibration.state.response.offset != 0 or hub.impact.projectiles.count() != 0 or hub.impact.effects.particleCount() != 0) return error.CalibrationNativeResetMismatch;
    try capture(io, tracking.allocator(), hub, view, renderer, capture_dir, "reset");
    const metrics = hub.impact.effects.metrics();
    if (metrics.dropped_particles != 0 or hub.impact.bridge.metrics.dropped_effects != 0) return error.CalibrationNativeDrops;
    std.log.info("ENGINE_LAB_CALIBRATION_SMOKE_OK backend=direct3d12 captures=9 matched_headless_checkpoints=11 lag_braking_reversal=true settled=true pause_step=true reanchor=true reset_live_effects=true batches=3 warm_allocations=0 drops=0", .{});
}

fn frame(tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, mapper: *actions.Mapper, command: actions.Actions, seconds: f64) !void {
    const allocations = tracking.alloc_index;
    const resizes = tracking.resize_index;
    const tick = hub.tick;
    const steps = hub.calibration.state.fixed_ticks;
    try actions.advance(hub, mapper, .{}, command, seconds);
    if (hub.calibration.state.fixed_ticks - steps != hub.tick - tick or hub.impact.effects.tick() != hub.tick or hub.impact.projectiles.tick() != hub.tick) return error.CalibrationNativeTickMismatch;
    try view.render(hub, renderer.renderQueue());
    renderer.camera().* = hub.camera;
    const prepared = renderer.renderQueue().prepare();
    if (prepared.ranges.len != 3 or prepared.sprites.len > view_module.legacy_sprite_capacity or prepared.sprites.len - view.time_sprite_count > view_module.accepted_calibration_bound or prepared.sprites.len - view.time_sprite_count - view.calibration_sprite_count > view_module.preexisting_sprite_bound) return error.CalibrationNativeQueueBound;
    if (!try renderer.renderUnifiedToWindow(prepared)) return error.CalibrationWindowUnavailable;
    if (tracking.alloc_index != allocations or tracking.resize_index != resizes) return error.CalibrationNativeSteadyAllocation;
    const effects = hub.impact.effects.metrics();
    if (effects.dropped_particles != 0 or effects.rejected_emitters != 0 or hub.impact.bridge.metrics.dropped_effects != 0) return error.CalibrationNativeDrops;
}

fn capture(io: std.Io, allocator: std.mem.Allocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, capture_dir: []const u8, name: []const u8) !void {
    const paused = hub.clock.paused;
    hub.clock.paused = true;
    defer hub.clock.paused = paused;
    const before = try hub.calibration.fingerprint();
    const hub_before = try hub.fingerprint();
    const impact_before = try hub.impact.fingerprint();
    try view.render(hub, renderer.renderQueue());
    const prepared = renderer.renderQueue().prepare();
    if (prepared.ranges.len != 3 or prepared.sprites.len > view_module.legacy_sprite_capacity) return error.CalibrationNativeQueueBound;
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
    if (!before.eql(try hub.calibration.fingerprint()) or !hub_before.eql(try hub.fingerprint()) or !impact_before.eql(try hub.impact.fingerprint())) return error.CalibrationCaptureMutation;
    std.log.info("CALIBRATION_CAPTURE name={s} simulation_paused={} presentation=completed hub_tick={d} steps_since_reset={d} offset={d:.6} velocity={d:.6} reference={any} response={any} sprites={d} addition={d} batches={d} projectiles={d} particles={d} observations_v1={s} rgba_sha256={x}", .{ name, paused, hub.tick, hub.calibration.state.fixed_ticks, hub.calibration.state.response.offset, hub.calibration.state.response.velocity, hub.calibration.reference.toArray(), (try hub.calibration.presentation(1, true)).response.toArray(), prepared.sprites.len, view.calibration_sprite_count, prepared.ranges.len, hub.impact.projectiles.count(), hub.impact.effects.particleCount(), before.formatLowerHex(), digest });
}
