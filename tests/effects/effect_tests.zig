const std = @import("std");
const e = @import("effects");
const t = @import("support.zig");
fn system() !e.System {
    return e.System.init(t.allocator, .{ .seed = t.seed });
}
fn spawn(s: *e.System, def: e.Definition) !void {
    _ = try s.spawn(.{ .id = t.id("burst"), .definition = def, .position = .zero });
}
test "effects burst, spread bounds and seed determinism" {
    var a = try system();
    defer a.deinit();
    var b = try system();
    defer b.deinit();
    const def = e.Definition{ .burst = 16, .position_spread = .{ .x = 2, .y = 3 }, .velocity = .{ .x = 10, .y = 20 }, .velocity_spread = .{ .x = 1, .y = 2 } };
    try spawn(&a, def);
    try spawn(&b, def);
    var pa: [16]e.ParticleSnapshot = undefined;
    var pb: [16]e.ParticleSnapshot = undefined;
    try std.testing.expectEqualDeep(try a.copyParticles(&pa), try b.copyParticles(&pb));
    for (pa) |p| {
        try std.testing.expect(@abs(p.position.x) <= 2 and @abs(p.position.y) <= 3);
        try std.testing.expect(p.velocity.x >= 9 and p.velocity.x < 11 and p.velocity.y >= 18 and p.velocity.y < 22);
    }
    b.reset(.{ .bytes = .{2} ** 16 });
    try spawn(&b, def);
    _ = try b.copyParticles(&pb);
    try std.testing.expect(!std.meta.eql(pa[0].position, pb[0].position));
}
test "effects continuous fixed-point rate and emitter duration are exact" {
    var s = try system();
    defer s.deinit();
    try spawn(&s, .{ .rate_milli = 7500, .duration_ticks = 240, .particle_lifetime_ticks = 1000 });
    for (0..31) |_| try s.step();
    try std.testing.expectEqual(@as(usize, 0), s.particleCount());
    try s.step();
    try std.testing.expectEqual(@as(usize, 1), s.particleCount());
    for (32..240) |_| try s.step();
    try std.testing.expectEqual(@as(usize, 7), s.particleCount());
    try std.testing.expect(!s.emitter(t.id("burst")).?.emitting);
    for (0..32) |_| try s.step();
    try std.testing.expectEqual(@as(usize, 7), s.particleCount());
}
test "effects particle lifetime, emitter drain and exact retirement" {
    var s = try system();
    defer s.deinit();
    try spawn(&s, .{ .burst = 1, .particle_lifetime_ticks = 2 });
    try s.step();
    try std.testing.expectEqual(@as(usize, 1), s.particleCount());
    try s.step();
    try std.testing.expectEqual(@as(usize, 0), s.particleCount());
    try std.testing.expectEqual(@as(usize, 0), s.emitterCount());
}
test "effects gravity drag and angular motion" {
    var s = try system();
    defer s.deinit();
    try spawn(&s, .{ .burst = 1, .velocity = .{ .x = 240, .y = 0 }, .acceleration = .{ .x = 0, .y = -240 }, .drag = 240, .rotation = 1, .angular_velocity = 240 });
    try s.step();
    var particles: [1]e.ParticleSnapshot = undefined;
    _ = try s.copyParticles(&particles);
    try std.testing.expectApproxEqAbs(@as(f32, 120), particles[0].velocity.x, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), particles[0].position.x, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), particles[0].velocity.y, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 2), particles[0].rotation, t.tolerance);
}
test "effects size opacity color and render interpolation are read only" {
    var s = try system();
    defer s.deinit();
    try spawn(&s, .{ .burst = 1, .particle_lifetime_ticks = 4, .start_size = .{ .x = 2, .y = 4 }, .end_size = .zero, .start_color = .{ 1, 0, 0 }, .end_color = .{ 0, 0, 1 } });
    try s.step();
    try s.step();
    var out: [1]e.RenderInstance = undefined;
    _ = try s.extract(&out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 1), out[0].size.x, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), out[0].color[3], t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), out[0].color[0], t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), out[0].color[2], t.tolerance);
    const before = s.tick();
    out[0].size.x = 999;
    _ = try s.extract(&out, 0);
    try std.testing.expectEqual(before, s.tick());
    try std.testing.expect(out[0].size.x < 2);
    try std.testing.expectError(error.InvalidInterpolation, s.extract(&out, std.math.nan(f32)));
}
test "effects particle drop and emitter rejection are explicit bounded policies" {
    var s = try e.System.init(t.allocator, .{ .seed = t.seed, .emitter_capacity = 1, .particle_capacity = 2 });
    defer s.deinit();
    try spawn(&s, .{ .burst = 5 });
    try std.testing.expectEqual(@as(usize, 2), s.particleCount());
    try std.testing.expectEqual(@as(u64, 3), s.metrics().dropped_particles);
    try std.testing.expectError(error.DuplicateEffect, spawn(&s, .{}));
    try std.testing.expectError(error.EmitterCapacity, s.spawn(.{ .id = t.id("second"), .definition = .{}, .position = .zero }));
    try std.testing.expectEqual(@as(u64, 1), s.metrics().rejected_emitters);
    var out: [1]e.RenderInstance = undefined;
    try std.testing.expectError(error.SnapshotCapacity, s.extract(&out, 1));
}
test "effects stop drains, clear removes and reset reproduces seed" {
    var s = try system();
    defer s.deinit();
    try spawn(&s, .{ .burst = 1, .rate_milli = 240000, .duration_ticks = 100 });
    try s.stop(t.id("burst"));
    try s.step();
    try std.testing.expectEqual(@as(usize, 1), s.particleCount());
    try s.clear(t.id("burst"));
    try std.testing.expectEqual(@as(usize, 0), s.particleCount());
    try std.testing.expectEqual(@as(usize, 0), s.emitterCount());
    try std.testing.expectError(error.UnknownEffect, s.stop(t.id("burst")));
    const def = e.Definition{ .burst = 2, .position_spread = .one };
    s.reset(t.seed);
    try spawn(&s, def);
    var a: [2]e.RenderInstance = undefined;
    _ = try s.extract(&a, 1);
    s.reset(t.seed);
    try spawn(&s, def);
    var b: [2]e.RenderInstance = undefined;
    _ = try s.extract(&b, 1);
    try std.testing.expectEqualDeep(a, b);
}
test "effects streams and extraction order independent of spawn ordering" {
    var a = try system();
    defer a.deinit();
    var b = try system();
    defer b.deinit();
    const def = e.Definition{ .burst = 2, .rate_milli = 240000, .duration_ticks = 30, .position_spread = .one };
    for ([_][]const u8{ "a", "b" }) |key| _ = try a.spawn(.{ .id = t.id(key), .definition = def, .position = .zero });
    for ([_][]const u8{ "b", "a" }) |key| _ = try b.spawn(.{ .id = t.id(key), .definition = def, .position = .zero });
    for (0..30) |_| {
        try a.step();
        try b.step();
    }
    var pa: [64]e.RenderInstance = undefined;
    var pb: [64]e.RenderInstance = undefined;
    try std.testing.expectEqualDeep(try a.extract(&pa, 1), try b.extract(&pb, 1));
}
test "effects moving an emitter never drags existing world-space particles" {
    var s = try system();
    defer s.deinit();
    try spawn(&s, .{ .burst = 1, .rate_milli = 240000, .duration_ticks = 2 });
    try s.setPosition(t.id("burst"), .{ .x = 10, .y = 20 });
    try s.step();
    var values: [2]e.ParticleSnapshot = undefined;
    _ = try s.copyParticles(&values);
    try std.testing.expectEqual(@as(f32, 0), values[0].position.x);
    try std.testing.expectEqual(@as(f32, 10), values[1].position.x);
}
test "effects reject invalid inputs without creating runtime state" {
    var s = try system();
    defer s.deinit();
    try std.testing.expectError(error.InvalidDefinition, spawn(&s, .{ .drag = -1 }));
    try std.testing.expectError(error.InvalidDefinition, spawn(&s, .{ .particle_lifetime_ticks = 0 }));
    try std.testing.expectError(error.InvalidDefinition, spawn(&s, .{ .start_opacity = 2 }));
    try std.testing.expectEqual(@as(usize, 0), s.emitterCount());
}
fn allocationScenario(allocator: std.mem.Allocator) !void {
    var s = try e.System.init(allocator, .{ .seed = t.seed });
    defer s.deinit();
    try spawn(&s, .{ .burst = 2 });
    try s.step();
}
test "effects allocation failures clean every partial initialization" {
    try std.testing.checkAllAllocationFailures(t.allocator, allocationScenario, .{});
}

test "effects independently calculated version-one UUID and Xoshiro sample vectors" {
    // Fixed vectors independently calculated with Python hashlib/uuid and
    // integer Xoshiro256++ arithmetic, using the accepted F framing protocol.
    var s = try system();
    defer s.deinit();
    try spawn(&s, .{ .burst = 1, .position_spread = .one, .velocity_spread = .one });
    var particles: [1]e.ParticleSnapshot = undefined;
    _ = try s.copyParticles(&particles);
    try std.testing.expectEqualStrings("c2912a4d-6283-5683-a40e-a285a8893193", &particles[0].emitter_id.formatCanonical());
    // The top-24-bit dyadic samples are exactly representable in f32.
    try std.testing.expectEqual(@as(f32, -0.10140180587768555), particles[0].position.x);
    try std.testing.expectEqual(@as(f32, -0.43032050132751465), particles[0].position.y);
    try std.testing.expectEqual(@as(f32, -0.16226696968078613), particles[0].velocity.x);
    try std.testing.expectEqual(@as(f32, 0.12758278846740723), particles[0].velocity.y);
}
test "effects dropped particles consume their samples and freed capacity resumes deterministically" {
    var small = try e.System.init(t.allocator, .{ .seed = t.seed, .particle_capacity = 1 });
    defer small.deinit();
    var large = try system();
    defer large.deinit();
    const def = e.Definition{ .burst = 3, .rate_milli = 240000, .duration_ticks = 2, .particle_lifetime_ticks = 1, .position_spread = .one };
    try spawn(&small, def);
    try spawn(&large, def);
    try small.step();
    try large.step();
    var a: [1]e.ParticleSnapshot = undefined;
    var b: [1]e.ParticleSnapshot = undefined;
    try std.testing.expectEqualDeep(try small.copyParticles(&a), try large.copyParticles(&b));
    try std.testing.expectEqual(@as(u64, 3), a[0].ordinal);
    try std.testing.expectEqual(@as(u64, 2), small.metrics().dropped_particles);
}
