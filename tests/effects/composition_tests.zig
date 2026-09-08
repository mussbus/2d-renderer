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

test "composition optional color batch retains the complete default appearance" {
    var projectiles = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer projectiles.deinit();
    var authored = config();
    authored.launch.start_color = .{ 0.2, 0.4, 0.6 };
    authored.launch.end_color = .{ 0.8, 0.6, 0.4 };
    var a = try e.System.init(t.allocator, .{ .seed = t.seed });
    defer a.deinit();
    var b = try e.System.init(t.allocator, .{ .seed = t.seed });
    defer b.deinit();
    var left = try bridge.Bridge.init(t.allocator, authored);
    defer left.deinit();
    var right = try bridge.Bridge.init(t.allocator, authored);
    defer right.deinit();
    try spawn(&projectiles, 1);
    try left.consume(projectiles.events(), &a);
    try right.consumeWithColors(projectiles.events(), &b, null);
    projectiles.clearEvents();
    try projectiles.step(null);
    try left.consume(projectiles.events(), &a);
    try right.consumeWithColors(projectiles.events(), &b, &.{ null, null });
    var ap: [8]e.ParticleSnapshot = undefined;
    var bp: [8]e.ParticleSnapshot = undefined;
    try std.testing.expectEqualDeep(try a.copyParticles(&ap), try b.copyParticles(&bp));
    try std.testing.expectEqualDeep(left.metrics, right.metrics);
    try std.testing.expectEqual(left.last_sequence, right.last_sequence);
}

test "composition aligned RGB changes only color and retains no caller values by reference" {
    var projectiles = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer projectiles.deinit();
    var a = try e.System.init(t.allocator, .{ .seed = t.seed });
    defer a.deinit();
    var b = try e.System.init(t.allocator, .{ .seed = t.seed });
    defer b.deinit();
    var authored = config();
    authored.launch.velocity_spread = .{ .x = 1, .y = 2 };
    authored.trail.velocity_spread = .{ .x = 3, .y = 4 };
    authored.expiration.velocity_spread = .{ .x = 5, .y = 6 };
    var left = try bridge.Bridge.init(t.allocator, authored);
    defer left.deinit();
    var right = try bridge.Bridge.init(t.allocator, authored);
    defer right.deinit();
    try spawn(&projectiles, 1);
    try projectiles.step(null);
    // Native batch is spawn, movement, expiration. Its emissions are one
    // launch, four quarter-metre samples, then three expiration particles.
    const rgb = [3]bridge.Rgb{ .{ 1, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 0, 1 } };
    var overrides = [3]?bridge.Rgb{ rgb[0], rgb[1], rgb[2] };
    try left.consume(projectiles.events(), &a);
    try right.consumeWithColors(projectiles.events(), &b, &overrides);
    overrides = @splat(.{ 1, 1, 0 });
    try std.testing.expectEqualDeep(authored, right.config);
    var ap: [8]e.ParticleSnapshot = undefined;
    var bp: [8]e.ParticleSnapshot = undefined;
    for (0..3) |_| {
        const plain = try a.copyParticles(&ap);
        const tinted = try b.copyParticles(&bp);
        try std.testing.expectEqual(@as(usize, 8), tinted.len);
        for (plain, tinted, 0..) |original, value, index| {
            const expected = rgb[if (index == 0) 0 else if (index < 5) 1 else 2];
            try std.testing.expectEqual(expected, value.definition.start_color);
            try std.testing.expectEqual(expected, value.definition.end_color);
            var normalized = value;
            normalized.definition.start_color = original.definition.start_color;
            normalized.definition.end_color = original.definition.end_color;
            // IDs, emitter IDs, ordinals, RNG-driven positions/velocities, age,
            // opacity and all physical/appearance parameters must match exactly.
            try std.testing.expectEqualDeep(original, normalized);
        }
        try a.step();
        try b.step();
    }
    try std.testing.expectEqualDeep(left.metrics, right.metrics);
    try std.testing.expectEqualDeep(a.metrics(), b.metrics());
    try std.testing.expectEqual(left.last_sequence, right.last_sequence);
    const before = try b.copyParticles(&bp);
    try std.testing.expectError(error.EventsOutOfOrder, right.consumeWithColors(projectiles.events(), &b, &overrides));
    var after: [8]e.ParticleSnapshot = undefined;
    try std.testing.expectEqualDeep(before, try b.copyParticles(&after));
}

test "composition validates all RGB overrides and event order before mutation" {
    var projectiles = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer projectiles.deinit();
    var effects = try e.System.init(t.allocator, .{ .seed = t.seed });
    defer effects.deinit();
    var adapter = try bridge.Bridge.init(t.allocator, config());
    defer adapter.deinit();
    try spawn(&projectiles, 1);
    try projectiles.step(null);
    const events = projectiles.events();
    try std.testing.expectEqual(@as(usize, 3), events.len);
    for ([_]usize{ 0, 2, 4 }) |length| {
        const colors = [_]?bridge.Rgb{ null, null, null, null };
        try std.testing.expectError(error.InvalidColorOverrides, adapter.consumeWithColors(events, &effects, colors[0..length]));
    }
    for ([_]f32{ -0.01, 1.01, std.math.nan(f32), std.math.inf(f32), -std.math.inf(f32) }) |bad| {
        for (0..3) |channel| {
            var colors = [3]?bridge.Rgb{ .{ 1, 0, 0 }, null, .{ 0, 1, 0 } };
            colors[2].?[channel] = bad;
            try std.testing.expectError(error.InvalidColorOverrides, adapter.consumeWithColors(events, &effects, &colors));
        }
    }
    var reordered = [3]p.Event{ events[1], events[0], events[2] };
    try std.testing.expectError(error.EventsOutOfOrder, adapter.consumeWithColors(&reordered, &effects, &.{ null, null, null }));
    try std.testing.expect(adapter.last_sequence == null);
    try std.testing.expectEqual(@as(usize, 0), adapter.count);
    try std.testing.expectEqualDeep(bridge.Metrics{}, adapter.metrics);
    try std.testing.expectEqualDeep(e.Metrics{}, effects.metrics());
    try std.testing.expectEqual(@as(usize, 0), effects.emitterCount());
    try std.testing.expectEqual(@as(usize, 0), effects.particleCount());
    try adapter.consumeWithColors(events, &effects, &.{ null, null, .{ 0, 1, 1 } });
    try std.testing.expectEqual(@as(usize, 8), effects.particleCount());
}

test "composition contact RGB belongs to the copied event after projectile retirement" {
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
    try std.testing.expectEqual(@as(usize, 0), projectiles.count());
    try adapter.consumeWithColors(projectiles.events(), &effects, &.{ null, .{ 1, 0, 1 } });
    projectiles.clearEvents();
    var particles: [5]e.ParticleSnapshot = undefined;
    _ = try effects.copyParticles(&particles);
    for (particles[3..5]) |value| {
        try std.testing.expectEqual(bridge.Rgb{ 1, 0, 1 }, value.definition.start_color);
        try std.testing.expectEqual(bridge.Rgb{ 1, 0, 1 }, value.definition.end_color);
    }
    try std.testing.expectEqual(@as(usize, 0), adapter.count);
    try std.testing.expectEqual(@as(u64, 1), adapter.metrics.impacts);
}
