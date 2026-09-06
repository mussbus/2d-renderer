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
    // Age two is two thirds through the three-tick visible span. The existing
    // 2e-5 tolerance also bounds ordinary f32 appearance interpolation rounding.
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 3.0), out[0].size.x, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 3.0), out[0].color[3], t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 3.0), out[0].color[0], t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 3.0), out[0].color[2], t.tolerance);
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

fn appearanceDefinition(lifetime: u32) e.Definition {
    return .{ .burst = 1, .particle_lifetime_ticks = lifetime, .start_size = .{ .x = 2, .y = 4 }, .end_size = .{ .x = 6, .y = 0 }, .start_opacity = 0.875, .end_opacity = 0.125, .start_color = .{ 0.25, 0.5, 0.75 }, .end_color = .{ 0.75, 0.25, 0.125 } };
}
fn expectAppearance(value: e.RenderInstance, size: [2]f32, rgba: [4]f32) !void {
    try std.testing.expectEqual(size[0], value.size.x);
    try std.testing.expectEqual(size[1], value.size.y);
    try std.testing.expectEqualDeep(rgba, value.color);
}
// Dyadic keyframes are exactly representable; endpoint assertions use no tolerance.
const appearance_samples = [_]struct { alpha: f32, size: [2]f32, rgba: [4]f32 }{
    .{ .alpha = 0, .size = .{ 2, 4 }, .rgba = .{ 0.25, 0.5, 0.75, 0.875 } },
    .{ .alpha = 0.25, .size = .{ 3, 3 }, .rgba = .{ 0.375, 0.4375, 0.59375, 0.6875 } },
    .{ .alpha = 0.5, .size = .{ 4, 2 }, .rgba = .{ 0.5, 0.375, 0.4375, 0.5 } },
    .{ .alpha = 0.75, .size = .{ 5, 1 }, .rgba = .{ 0.625, 0.3125, 0.28125, 0.3125 } },
    .{ .alpha = 1, .size = .{ 6, 0 }, .rgba = .{ 0.75, 0.25, 0.125, 0.125 } },
};

test "effects four-tick appearance reaches exact endpoints before unchanged retirement" {
    var s = try system();
    defer s.deinit();
    var def = appearanceDefinition(4);
    // Large-to-small size and non-dyadic color/opacity expose endpoint rounding
    // in a generic from + (to - from) * 1 calculation as well as short curves.
    def.start_size = .{ .x = 1000000, .y = 10000 };
    def.end_size = .{ .x = 0.1, .y = 0.3 };
    def.start_opacity = 1;
    def.end_opacity = 0.1;
    def.start_color = .{ 1, 1, 1 };
    def.end_color = .{ 0.1, 0.2, 0.3 };
    def.velocity = .{ .x = 240, .y = 0 };
    def.angular_velocity = 240;
    try spawn(&s, def);
    var out: [1]e.RenderInstance = undefined;
    for ([_]f32{ 0, 0.5, 1 }) |alpha| {
        _ = try s.extract(&out, alpha);
        try expectAppearance(out[0], .{ 1000000, 10000 }, .{ 1, 1, 1, 1 });
    }
    for (0..3) |_| try s.step();
    var particles: [1]e.ParticleSnapshot = undefined;
    _ = try s.copyParticles(&particles);
    try std.testing.expectEqual(@as(u32, 3), particles[0].age_ticks);
    _ = try s.extract(&out, 0.5);
    // Existing 240 Hz motion rounding tolerance, independent of appearance.
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), out[0].position.x, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), out[0].rotation, t.tolerance);
    _ = try s.extract(&out, 1);
    try expectAppearance(out[0], .{ def.end_size.x, def.end_size.y }, def.end_color ++ .{def.end_opacity});
    try std.testing.expectEqual(@as(usize, 1), s.particleCount());
    try s.step();
    try std.testing.expectEqual(@as(u64, 4), s.tick());
    try std.testing.expectEqual(@as(usize, 0), s.particleCount());
    try std.testing.expectEqual(@as(usize, 0), s.emitterCount());
    try std.testing.expectEqual(@as(usize, 0), (try s.extract(&out, 1)).len);
}

test "effects two-tick appearance starts constant then progresses monotonically to its endpoint" {
    var s = try system();
    defer s.deinit();
    try spawn(&s, appearanceDefinition(2));
    var out: [1]e.RenderInstance = undefined;
    for (appearance_samples) |sample| {
        _ = try s.extract(&out, sample.alpha);
        try expectAppearance(out[0], appearance_samples[0].size, appearance_samples[0].rgba);
    }
    try s.step();
    var previous: ?e.RenderInstance = null;
    for (appearance_samples) |sample| {
        _ = try s.extract(&out, sample.alpha);
        try expectAppearance(out[0], sample.size, sample.rgba);
        if (previous) |before| {
            try std.testing.expect(out[0].size.x > before.size.x and out[0].size.y < before.size.y);
            try std.testing.expect(out[0].color[0] > before.color[0]);
            for (1..4) |channel| try std.testing.expect(out[0].color[channel] < before.color[channel]);
        }
        previous = out[0];
    }
    try std.testing.expectEqual(@as(usize, 1), s.particleCount());
    try s.step();
    try std.testing.expectEqual(@as(u64, 2), s.tick());
    try std.testing.expectEqual(@as(usize, 0), s.particleCount());
    try std.testing.expectEqual(@as(usize, 0), s.emitterCount());
}

test "effects one-tick appearance uses alpha through its only live interval" {
    var s = try system();
    defer s.deinit();
    try spawn(&s, appearanceDefinition(1));
    var out: [1]e.RenderInstance = undefined;
    for (appearance_samples) |sample| {
        _ = try s.extract(&out, sample.alpha);
        try expectAppearance(out[0], sample.size, sample.rgba);
        try std.testing.expectEqual(@as(u64, 0), s.tick());
        try std.testing.expectEqual(@as(usize, 1), s.particleCount());
    }
    try s.step();
    try std.testing.expectEqual(@as(u64, 1), s.tick());
    try std.testing.expectEqual(@as(usize, 0), s.particleCount());
    try std.testing.expectEqual(@as(usize, 0), s.emitterCount());
    try std.testing.expectEqual(@as(usize, 0), (try s.extract(&out, 1)).len);
}

test "effects appearance extraction preserves state allocation metrics and future random emissions" {
    var allocator = std.testing.FailingAllocator.init(t.allocator, .{});
    var a = try e.System.init(allocator.allocator(), .{ .seed = t.seed });
    defer a.deinit();
    var b = try system();
    defer b.deinit();
    var def = appearanceDefinition(4);
    def.burst = 2;
    def.rate_milli = 480000;
    def.duration_ticks = 6;
    def.position_spread = .one;
    def.velocity_spread = .{ .x = 2, .y = 3 };
    try spawn(&a, def);
    try spawn(&b, def);
    const allocations = allocator.allocations;
    allocator.fail_index = allocator.alloc_index;
    allocator.resize_fail_index = allocator.resize_index;
    var pa: [32]e.ParticleSnapshot = undefined;
    var pb: [32]e.ParticleSnapshot = undefined;
    var out: [32]e.RenderInstance = undefined;
    for (0..12) |_| {
        const before = try a.copyParticles(&pa);
        const tick = a.tick();
        const metrics = a.metrics();
        const emitter = a.emitter(t.id("burst"));
        for ([_]f32{ 1, 0, 0.125, 0.75, 0.5, 1 }) |alpha| {
            _ = try a.extract(&out, alpha);
            try std.testing.expectEqual(tick, a.tick());
            try std.testing.expectEqualDeep(metrics, a.metrics());
            try std.testing.expectEqualDeep(emitter, a.emitter(t.id("burst")));
            try std.testing.expectEqualDeep(before, try a.copyParticles(&pb));
        }
        for ([_]f32{ -0.1, 1.1, std.math.nan(f32) }) |alpha|
            try std.testing.expectError(error.InvalidInterpolation, a.extract(&out, alpha));
        // The unobserved twin's subsequent particles expose any extra RNG draw
        // without breaking the core's opaque ownership boundary.
        try a.step();
        try b.step();
        try std.testing.expectEqualDeep(try a.copyParticles(&pa), try b.copyParticles(&pb));
        try std.testing.expectEqualDeep(a.emitter(t.id("burst")), b.emitter(t.id("burst")));
        try std.testing.expectEqualDeep(a.metrics(), b.metrics());
        try std.testing.expectEqual(a.tick(), b.tick());
    }
    try std.testing.expectEqual(allocations, allocator.allocations);
    try std.testing.expect(!allocator.has_induced_failure);
}

fn renderDigest(values: []const e.RenderInstance) [32]u8 {
    // Serialize explicit fields, never struct padding or allocator addresses.
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var word: [8]u8 = undefined;
    std.mem.writeInt(u64, &word, values.len, .little);
    hash.update(&word);
    for (values) |value| {
        hash.update(&value.effect_id.bytes);
        std.mem.writeInt(u64, &word, value.ordinal, .little);
        hash.update(&word);
        for ([_]f32{ value.position.x, value.position.y, value.rotation, value.size.x, value.size.y } ++ value.color) |number| {
            var bits: [4]u8 = undefined;
            std.mem.writeInt(u32, &bits, @bitCast(number), .little);
            hash.update(&bits);
        }
        var sprite: [4]u8 = undefined;
        std.mem.writeInt(u32, &sprite, @intFromEnum(value.sprite), .little);
        hash.update(&sprite);
        var layer: [2]u8 = undefined;
        std.mem.writeInt(i16, &layer, value.layer, .little);
        hash.update(&layer);
    }
    return hash.finalResult();
}

test "effects corrected appearance instances and field hashes repeat across identical runs" {
    var a = try system();
    defer a.deinit();
    var b = try system();
    defer b.deinit();
    var expected: [55][32]u8 = undefined;
    for (0..2) |run| {
        a.reset(t.seed);
        b.reset(t.seed);
        for ([_]u32{ 1, 2, 4 }, [_][]const u8{ "appearance-one", "appearance-two", "appearance-four" }) |lifetime, key| {
            var def = appearanceDefinition(lifetime);
            def.rate_milli = 240000;
            def.duration_ticks = 6;
            def.position_spread = .one;
            def.velocity_spread = .one;
            _ = try a.spawn(.{ .id = t.id(key), .definition = def, .position = .zero });
            _ = try b.spawn(.{ .id = t.id(key), .definition = def, .position = .zero });
        }
        var index: usize = 0;
        for (0..11) |_| {
            for (appearance_samples) |sample| {
                var ra: [32]e.RenderInstance = undefined;
                var rb: [32]e.RenderInstance = undefined;
                const va = try a.extract(&ra, sample.alpha);
                const vb = try b.extract(&rb, sample.alpha);
                try std.testing.expectEqualDeep(va, vb);
                const digest = renderDigest(va);
                try std.testing.expectEqualDeep(digest, renderDigest(vb));
                if (run == 0) expected[index] = digest else try std.testing.expectEqualDeep(expected[index], digest);
                index += 1;
            }
            try a.step();
            try b.step();
        }
        try std.testing.expectEqual(expected.len, index);
    }
}
