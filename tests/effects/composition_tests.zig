const std = @import("std");
const p = @import("projectiles");
const e = @import("effects");
const bridge = @import("projectile_effects");
const t = @import("support.zig");
fn config() bridge.Config {
    return .{ .namespace = t.namespace, .trail_spacing = 0.25, .launch = .{ .burst = 1 }, .trail = .{ .burst = 1 }, .impact = .{ .burst = 2 }, .expiration = .{ .burst = 3 } };
}
fn spawn(s: *p.System, lifetime: u32) !void {
    _ = try s.spawn(.{ .definition = .{ .lifetime_ticks = lifetime }, .position = .zero, .velocity = .{ .x = 240, .y = 0 } });
}
test "composition launch distance-trail and expiration mapping" {
    var projectiles = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer projectiles.deinit();
    var effects = try e.System.init(t.allocator, .{ .seed = t.seed });
    defer effects.deinit();
    var adapter = try bridge.Bridge.init(t.allocator, config());
    defer adapter.deinit();
    try spawn(&projectiles, 1);
    try adapter.consume(projectiles.events(), &effects);
    projectiles.clearEvents();
    try std.testing.expectEqual(@as(usize, 1), effects.particleCount());
    try projectiles.step(null);
    try adapter.consume(projectiles.events(), &effects);
    try std.testing.expectEqual(@as(u64, 1), adapter.metrics.launches);
    try std.testing.expectEqual(@as(u64, 4), adapter.metrics.trail_samples);
    try std.testing.expectEqual(@as(u64, 1), adapter.metrics.expirations);
    try std.testing.expectEqual(@as(usize, 8), effects.particleCount());
    try std.testing.expectEqual(@as(usize, 0), adapter.count);
    var particles: [8]e.ParticleSnapshot = undefined;
    _ = try effects.copyParticles(&particles);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), particles[1].position.x, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 1), particles[4].position.x, t.tolerance);
    try std.testing.expectError(error.EventsOutOfOrder, adapter.consume(projectiles.events(), &effects));
    try std.testing.expectEqual(@as(usize, 8), effects.particleCount());
}
fn collision(_: ?*const anyopaque, _: p.collision.Sweep, hits: *p.collision.Hits) p.collision.Error!void {
    try hits.append(.{ .collider_id = 1, .fraction = 0.5, .normal = .{ .x = -1, .y = 0 }, .position = .{ .x = 0.5, .y = 0 } });
}
test "composition impact uses contact location and retires trail tracking" {
    var projectiles = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer projectiles.deinit();
    var effects = try e.System.init(t.allocator, .{ .seed = t.seed });
    defer effects.deinit();
    var adapter = try bridge.Bridge.init(t.allocator, config());
    defer adapter.deinit();
    try spawn(&projectiles, 10);
    try adapter.consume(projectiles.events(), &effects);
    projectiles.clearEvents();
    try projectiles.step(.{ .context = null, .collect = collision });
    try adapter.consume(projectiles.events(), &effects);
    try std.testing.expectEqual(@as(u64, 1), adapter.metrics.impacts);
    try std.testing.expectEqual(@as(usize, 0), adapter.count);
    var particles: [5]e.ParticleSnapshot = undefined;
    _ = try effects.copyParticles(&particles);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), particles[4].position.x, t.tolerance);
}
test "composition saturation and arbitrary render reads cannot affect projectile simulation" {
    var a = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer a.deinit();
    var b = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer b.deinit();
    var effects = try e.System.init(t.allocator, .{ .seed = t.seed, .emitter_capacity = 1, .particle_capacity = 1 });
    defer effects.deinit();
    var adapter = try bridge.Bridge.init(t.allocator, config());
    defer adapter.deinit();
    try spawn(&a, 90);
    try spawn(&b, 90);
    try adapter.consume(a.events(), &effects);
    for (0..90) |_| {
        a.clearEvents();
        b.clearEvents();
        try a.step(null);
        try b.step(null);
        try adapter.consume(a.events(), &effects);
        try effects.step();
        var output: [1]e.RenderInstance = undefined;
        _ = try effects.extract(&output, 0.3);
        _ = try effects.extract(&output, 0.9);
        try std.testing.expectEqualDeep(a.events(), b.events());
    }
    try std.testing.expect(adapter.metrics.dropped_effects > 0);
    try std.testing.expectEqual(@as(usize, 0), a.count());
}
test "composition trail samples are bounded and reset reproduces mappings" {
    var projectiles = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer projectiles.deinit();
    var effects = try e.System.init(t.allocator, .{ .seed = t.seed });
    defer effects.deinit();
    var limited = config();
    limited.maximum_samples_per_segment = 2;
    var adapter = try bridge.Bridge.init(t.allocator, limited);
    defer adapter.deinit();
    var first: [6]e.RenderInstance = undefined;
    var second: [6]e.RenderInstance = undefined;
    for (0..2) |iteration| {
        projectiles.reset();
        effects.reset(t.seed);
        adapter.reset();
        try spawn(&projectiles, 1);
        try projectiles.step(null);
        try adapter.consume(projectiles.events(), &effects);
        try std.testing.expectEqual(@as(u64, 2), adapter.metrics.trail_samples);
        try std.testing.expectEqual(@as(u64, 1), adapter.metrics.truncated_segments);
        _ = try effects.extract(if (iteration == 0) &first else &second, 1);
    }
    try std.testing.expectEqualDeep(first, second);
}

test "composition distance remainder survives many subspacing steps" {
    var projectiles = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer projectiles.deinit();
    var effects = try e.System.init(t.allocator, .{ .seed = t.seed });
    defer effects.deinit();
    var adapter = try bridge.Bridge.init(t.allocator, config());
    defer adapter.deinit();
    _ = try projectiles.spawn(.{ .definition = .{}, .position = .zero, .velocity = .{ .x = 15, .y = 0 } });
    try adapter.consume(projectiles.events(), &effects);
    for (0..16) |_| {
        projectiles.clearEvents();
        try projectiles.step(null);
        try adapter.consume(projectiles.events(), &effects);
    }
    try std.testing.expectEqual(@as(u64, 4), adapter.metrics.trail_samples);
    var particles: [5]e.ParticleSnapshot = undefined;
    _ = try effects.copyParticles(&particles);
    for (1..5) |index| try std.testing.expectApproxEqAbs(@as(f32, @floatFromInt(index)) * 0.25, particles[index].position.x, t.tolerance);
}
