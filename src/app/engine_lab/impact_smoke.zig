//! Bounded native acceptance fixture. Captures/file writes occur only at explicit
//! proof boundaries, outside the measured simulation/presentation frame loop.
const std = @import("std");
const h = @import("engine_lab");
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const renderer_module = @import("sdl_gpu_renderer");
const impact = h.impact_module;

pub fn run(io: std.Io, tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer) !void {
    if (!std.mem.eql(u8, try renderer.backendName(), "direct3d12")) return error.WrongImpactBackend;
    var mapper = actions.Mapper{};
    try hub.reset();
    try actions.advance(hub, &mapper, .{}, .{ .destination = .springs }, 0);
    try actions.advance(hub, &mapper, .{}, .{ .pause = true, .activate = true }, 1.0 / 60.0);
    if (hub.tick != 0 or !hub.impact.pending_activation or hub.impact.projectiles.count() != 0) return error.ImpactPausedLaunch;
    try capture(io, tracking.allocator(), hub, view, renderer, "ready");
    try frame(tracking, hub, view, renderer, &mapper, .{ .step = true }, 1.0 / 60.0);
    if (hub.tick != 1 or hub.impact.observations.last_launch.?.tick != 0) return error.ImpactSpawnBoundary;
    try capture(io, tracking.allocator(), hub, view, renderer, "launch");
    try frame(tracking, hub, view, renderer, &mapper, .{ .step = true }, 1.0 / 60.0);
    if (hub.impact.observations.launches != 1) return error.ImpactRepeatedActivation;
    try frame(tracking, hub, view, renderer, &mapper, .{ .pause = true, .activate = true }, 2.0 / 240.0);
    if (hub.impact.observations.busy != 1) return error.ImpactBusyCoverage;
    const before_travel = try hub.impact.fingerprint();
    try actions.advance(hub, &mapper, .{}, .{ .destination = .hierarchy }, 0);
    if (!before_travel.eql(try hub.impact.fingerprint())) return error.ImpactTravelMutation;
    try advanceTo(tracking, hub, view, renderer, &mapper, 120);
    try actions.advance(hub, &mapper, .{}, .{ .destination = .springs }, 0);
    try advanceTo(tracking, hub, view, renderer, &mapper, 156);
    try capture(io, tracking.allocator(), hub, view, renderer, "flight");
    try advanceTo(tracking, hub, view, renderer, &mapper, 312);
    var particles: [impact.particle_capacity]impact.e.ParticleSnapshot = undefined;
    const born = try hub.impact.effects.copyParticles(&particles);
    if (born.len != 24 or hub.impact.projectiles.count() != 0 or hub.impact.bridge.metrics.impacts != 1) return error.ImpactContactCoverage;
    for (born) |particle| if (particle.age_ticks != 0) return error.ImpactBirthAge;
    const contact = hub.impact.observations.last_contact.?;
    std.log.info("IMPACT_NATIVE_CONTACT executing_hub_tick={d} native_tick={d} sequence={d} collider={d} fraction={d} surface=({d},{d}) normal=({d},{d}) particles={d} birth_age=0", .{ hub.tick, contact.tick, contact.sequence, contact.hit.?.collider_id, contact.hit.?.fraction, contact.hit.?.position.x, contact.hit.?.position.y, contact.hit.?.normal.x, contact.hit.?.normal.y, born.len });
    try capture(io, tracking.allocator(), hub, view, renderer, "contact");
    try advanceTo(tracking, hub, view, renderer, &mapper, 313);
    const advanced = try hub.impact.effects.copyParticles(&particles);
    for (advanced) |particle| if (particle.age_ticks != 1) return error.ImpactNextTickAge;
    std.log.info("IMPACT_NATIVE_ADVANCEMENT hub_tick=313 particle_age=1 first_x={d} previous_x={d}", .{ advanced[0].position.x, advanced[0].previous_position.x });
    try advanceTo(tracking, hub, view, renderer, &mapper, 384);
    try capture(io, tracking.allocator(), hub, view, renderer, "fade");
    try advanceTo(tracking, hub, view, renderer, &mapper, 456);
    if (hub.impact.effects.particleCount() != 0 or hub.impact.effects.emitterCount() != 0) return error.ImpactDrainCoverage;
    try capture(io, tracking.allocator(), hub, view, renderer, "drain");
    const metrics = hub.impact.effects.metrics();
    if (metrics.dropped_particles != 0 or hub.impact.bridge.metrics.dropped_effects != 0) return error.ImpactNominalSaturation;
    try actions.advance(hub, &mapper, .{}, .{ .reset = true, .activate = true, .pause = true, .step = true }, 0.05);
    try actions.advance(hub, &mapper, .{}, .{ .destination = .springs }, 0);
    try frame(tracking, hub, view, renderer, &mapper, .{ .activate = true }, 4.0 / 240.0);
    try actions.advance(hub, &mapper, .{}, .{ .reset = true }, 0.05);
    if (hub.tick != 0 or hub.impact.projectiles.count() != 0) return error.ImpactFlightReset;
    try actions.advance(hub, &mapper, .{}, .{ .destination = .springs }, 0);
    try frame(tracking, hub, view, renderer, &mapper, .{ .activate = true }, 4.0 / 240.0);
    try advanceTo(tracking, hub, view, renderer, &mapper, 312);
    try actions.advance(hub, &mapper, .{}, .{ .reset = true }, 0.05);
    if (hub.tick != 0 or hub.clock.paused or hub.impact.effects.particleCount() != 0 or hub.impact.bridge.last_sequence != null) return error.ImpactParticleReset;
    try capture(io, tracking.allocator(), hub, view, renderer, "reset");
    std.log.info("ENGINE_LAB_IMPACT_SMOKE_OK backend=direct3d12 contact_tick=312 birth_age=0 next_age=1 drain_tick=456 pause_step=true offscreen_travel=true flight_reset=true particle_reset=true peak_particles={d} peak_emitters={d} dropped_particles=0 dropped_effects=0 steady_allocations=0 captures=7 batches=3", .{ metrics.peak_particles, metrics.peak_emitters });
}

fn advanceTo(tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, mapper: *actions.Mapper, tick: u64) !void {
    while (hub.tick < tick) try frame(tracking, hub, view, renderer, mapper, .{}, @as(f64, @floatFromInt(@min(@as(u64, 4), tick - hub.tick))) / 240.0);
}
fn frame(tracking: *std.testing.FailingAllocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, mapper: *actions.Mapper, command: actions.Actions, seconds: f64) !void {
    const allocations = tracking.allocations;
    try actions.advance(hub, mapper, .{}, command, seconds);
    try view.render(hub, renderer.renderQueue());
    renderer.camera().* = hub.camera;
    const prepared = renderer.renderQueue().prepare();
    if (prepared.ranges.len != 3 or prepared.sprites.len > 1792) return error.ImpactQueueBound;
    if (!try renderer.renderUnifiedToWindow(prepared)) return error.ImpactWindowUnavailable;
    if (tracking.allocations != allocations) return error.ImpactSteadyAllocation;
}
fn capture(io: std.Io, allocator: std.mem.Allocator, hub: *h.Hub, view: *view_module.View, renderer: *renderer_module.Renderer, name: []const u8) !void {
    const paused = hub.clock.paused;
    hub.clock.paused = true;
    defer hub.clock.paused = paused;
    const before = try hub.impact.fingerprint();
    try view.render(hub, renderer.renderQueue());
    const prepared = renderer.renderQueue().prepare();
    if (prepared.ranges.len != 3 or prepared.sprites.len > 1792) return error.ImpactQueueBound;
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
    try std.Io.Dir.cwd().createDirPath(io, ".tmp/projectile-impact/captures");
    var path: [128]u8 = undefined;
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.bufPrint(&path, ".tmp/projectile-impact/captures/{s}.ppm", .{name}), .data = ppm });
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(rgba, &digest, .{});
    if (!before.eql(try hub.impact.fingerprint())) return error.ImpactCaptureMutation;
    std.log.info("IMPACT_CAPTURE name={s} tick={d} sprites={d} rgba_sha256={x}", .{ name, hub.tick, prepared.sprites.len, digest });
}
