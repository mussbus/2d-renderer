const std = @import("std");
const motion = @import("secondary_motion");
const fixed_step = @import("fixed_step");
const spring = @import("spring");

const profile = motion.Profile{};
// 1e-6 U accommodates f32 rounding in small response comparisons, well below
// the 0.01 U contact bound used in these tests. Replay uses exact scalar bits.
const tolerance: f32 = 1e-6;

fn tick(state: *motion.State, config: motion.Profile, position: f32) !motion.Response {
    return state.step(config, .{ .driver = .{ .position = position } });
}

fn expectSame(expected: motion.State, actual: motion.State) !void {
    try std.testing.expectEqual(@as(u32, @bitCast(expected.response.offset)), @as(u32, @bitCast(actual.response.offset)));
    try std.testing.expectEqual(@as(u32, @bitCast(expected.response.velocity)), @as(u32, @bitCast(actual.response.velocity)));
    try std.testing.expectEqual(@as(u32, @bitCast(expected.driver_position)), @as(u32, @bitCast(actual.driver_position)));
    try std.testing.expectEqual(@as(u32, @bitCast(expected.driver_velocity)), @as(u32, @bitCast(actual.driver_velocity)));
    try std.testing.expectEqual(expected.fixed_ticks, actual.fixed_ticks);
}

fn energy(response: motion.Response, stiffness: f32) f64 {
    const x: f64 = response.offset;
    const v: f64 = response.velocity;
    return 0.5 * (v * v + stiffness * x * x);
}

test "PSM01 stationary and zero input preserve exact rest without energy" {
    var state = try motion.State.init(profile, 12);
    for (0..10_000) |_| {
        try state.applyVelocityImpulse(profile, 0);
        const output = try tick(&state, profile, 12);
        try std.testing.expectEqual(@as(f32, 0), output.offset);
        try std.testing.expectEqual(@as(f32, 0), output.velocity);
        try std.testing.expectEqual(@as(f64, 0), energy(output, profile.stiffness));
    }
    try std.testing.expectEqual(@as(u64, 10_000), state.fixed_ticks);
}

test "PSM01 displaced channel returns to equilibrium and underdamping overshoots" {
    const config = motion.Profile{ .stiffness = 100, .damping = 4 };
    var state = try motion.State.init(config, 0);
    state.response.offset = 0.1;
    var minimum: f32 = 0;
    var peak_energy = energy(state.response, config.stiffness);
    for (0..6000) |_| {
        const output = try tick(&state, config, 0);
        minimum = @min(minimum, output.offset);
        peak_energy = @max(peak_energy, energy(output, config.stiffness));
    }
    // Continuous overshoot at damping ratio 0.2 is about 53%; require a
    // substantial signed crossing rather than accepting numerical noise.
    try std.testing.expect(minimum < -0.04 and minimum > -0.07);
    try std.testing.expect(peak_energy < 0.51);
    try std.testing.expectEqual(motion.Response{}, state.response);
    std.debug.print("PSM01 underdamped minimum={d:.8} peak_energy={d:.8} settled_tick={d}\n", .{ minimum, peak_energy, state.fixed_ticks });
}

test "PSM01 critical and high damping settle without sign oscillation" {
    for ([_]f32{ 20, 60 }) |damping| {
        const config = motion.Profile{ .stiffness = 100, .damping = damping };
        var state = try motion.State.init(config, 0);
        state.response.offset = 0.1;
        var previous: f32 = 0.1;
        for (0..6000) |_| {
            const output = try tick(&state, config, 0);
            try std.testing.expect(output.offset >= 0);
            try std.testing.expect(output.offset <= previous + tolerance);
            previous = output.offset;
        }
        try std.testing.expectEqual(motion.Response{}, state.response);
    }
}

test "PSM01 critical response agrees with independent continuous solution" {
    const config = motion.Profile{ .stiffness = 100, .damping = 20 };
    var state = try motion.State.init(config, 0);
    state.response.offset = 0.1;
    for (0..120) |_| _ = try tick(&state, config, 0);
    // x(t)=x0*(1+w*t)*exp(-w*t), w=10, t=0.5 s.
    // 0.00015 U allows first-order integration error at h=1/240, while being
    // much smaller than the response (0.00404 U). This is not an Euler oracle.
    const analytic: f32 = 0.1 * 6 * @exp(@as(f32, -5));
    try std.testing.expectApproxEqAbs(analytic, state.response.offset, 0.00015);
    std.debug.print("PSM01 critical at_0.5s={d:.8} analytic={d:.8}\n", .{ state.response.offset, analytic });
}

test "PSM01 impulse repeats exactly and independent instances share no state" {
    var first = try motion.State.init(profile, 0);
    var replay = first;
    var untouched = first;
    try first.applyVelocityImpulse(profile, 1);
    try replay.applyVelocityImpulse(profile, 1);
    var peak: f32 = 0;
    for (0..4000) |_| {
        const output = try tick(&first, profile, 0);
        _ = try tick(&replay, profile, 0);
        _ = try tick(&untouched, profile, 0);
        try expectSame(first, replay);
        try std.testing.expectEqual(motion.Response{}, untouched.response);
        peak = @max(peak, output.offset);
    }
    try std.testing.expect(peak > 0.03 and peak < 0.06);
    try std.testing.expectEqual(motion.Response{}, first.response);
    std.debug.print("PSM01 impulse peak={d:.8} final_energy={d:.8}\n", .{ peak, energy(first.response, profile.stiffness) });
}

test "PSM01 displacement projection removes energy and sustained contact stores no outward velocity" {
    const limited = motion.Profile{
        .stiffness = 100,
        .damping = 10,
        .maximum_displacement = 0.01,
        .settle_displacement = 1e-8,
        .settle_velocity = 1e-7,
    };
    var generous = limited;
    generous.maximum_displacement = 1;
    var contact = try motion.State.init(limited, 0);
    contact.response = .{ .offset = 0.009, .velocity = 1 };
    var free = contact;
    // Hold an outward force through both integration stages so contact is
    // sustained; without it, a later spring stage may already move inward.
    const contact_input = motion.TickInput{ .driver = .{ .position = 0 }, .external_acceleration = 1000 };
    const projected = try contact.step(limited, contact_input);
    const unprojected = try free.step(generous, contact_input);
    try std.testing.expectEqual(limited.maximum_displacement, projected.offset);
    try std.testing.expectEqual(@as(f32, 0), projected.velocity);
    try std.testing.expect(energy(projected, limited.stiffness) < energy(unprojected, limited.stiffness));

    for (0..2400) |_| {
        const output = try contact.step(limited, .{
            .driver = .{ .position = 0 },
            .external_acceleration = 1000,
        });
        try std.testing.expectEqual(limited.maximum_displacement, output.offset);
        try std.testing.expectEqual(@as(f32, 0), output.velocity);
    }
    for (0..6000) |_| {
        const output = try tick(&contact, limited, 0);
        try std.testing.expect(@abs(output.offset) <= limited.maximum_displacement);
    }
    try std.testing.expectEqual(motion.Response{}, contact.response);
    std.debug.print("PSM01 contact projected_energy={d:.8} free_energy={d:.8} contact_ticks=2400\n", .{
        energy(projected, limited.stiffness), energy(unprojected, limited.stiffness),
    });
}

test "PSM01 exact boundary contact clears outward motion and preserves inward motion" {
    // Choose the next unconstrained position itself as the limit, ensuring
    // an exact boundary hit with no displacement overshoot.
    var free = try motion.State.init(profile, 0);
    try free.applyVelocityImpulse(profile, 1);
    const next = try tick(&free, profile, 0);
    var config = profile;
    config.maximum_displacement = next.offset;
    var outward = try motion.State.init(config, 0);
    try outward.applyVelocityImpulse(config, 1);
    const output = try tick(&outward, config, 0);
    try std.testing.expectEqual(config.maximum_displacement, output.offset);
    try std.testing.expectEqual(@as(f32, 0), output.velocity);
    outward.response.velocity = -0.1;
    const inward = try tick(&outward, config, 0);
    try std.testing.expect(inward.offset < config.maximum_displacement);
    try std.testing.expect(inward.velocity < 0);
}

test "PSM01 optional velocity cap removes impulse energy and bounds forced stepping" {
    var config = profile;
    config.maximum_velocity = 0.1;
    var limited = try motion.State.init(config, 0);
    var free = try motion.State.init(profile, 0);
    try limited.applyVelocityImpulse(config, 10);
    try free.applyVelocityImpulse(profile, 10);
    try std.testing.expectEqual(@as(f32, 0.1), limited.response.velocity);
    try std.testing.expectEqual(@as(f32, 10), free.response.velocity);
    try std.testing.expect(energy(limited.response, config.stiffness) < energy(free.response, profile.stiffness));
    for (0..2400) |index| {
        const acceleration: f32 = if (index % 2 == 0) 1000 else -1000;
        const output = try limited.step(config, .{ .driver = .{ .position = 0 }, .external_acceleration = acceleration });
        try std.testing.expect(@abs(output.velocity) <= 0.1);
        try std.testing.expect(@abs(output.offset) <= config.maximum_displacement);
    }
}

test "PSM01 reset clears response derivative history and tick count" {
    var state = try motion.State.init(profile, 0);
    _ = try tick(&state, profile, 1);
    try state.applyVelocityImpulse(profile, 3);
    try state.reset(profile, 100);
    try expectSame(try motion.State.init(profile, 100), state);
    try std.testing.expectEqual(motion.Response{}, try tick(&state, profile, 100));
    // Reset is also a recovery operation and need not trust corrupted old state.
    state.response.offset = std.math.nan(f32);
    try state.reset(profile, 0);
    try expectSame(try motion.State.init(profile, 0), state);
}

test "PSM01 teleport and seek discard inherited response without differentiating the jump" {
    var state = try motion.State.init(profile, -std.math.floatMax(f32));
    try state.applyVelocityImpulse(profile, 1);
    const output = try state.step(profile, .{
        .driver = .{ .position = std.math.floatMax(f32), .discontinuity = true },
        .external_acceleration = 1,
    });
    try std.testing.expectEqual(motion.Response{}, output);
    try std.testing.expectEqual(@as(u64, 1), state.fixed_ticks);
    try std.testing.expectEqual(@as(f32, 0), state.driver_velocity);
    try std.testing.expectEqual(motion.Response{}, try tick(&state, profile, std.math.floatMax(f32)));
}

test "PSM01 ordinary step and sudden reversal create signed inertial response" {
    var state = try motion.State.init(profile, 0);
    const start = try tick(&state, profile, 0.01);
    try std.testing.expect(start.offset < 0);
    _ = try tick(&state, profile, 0.02);
    const before = state.response.velocity;
    _ = try tick(&state, profile, 0.01);
    try std.testing.expect(state.response.velocity > before);
    for (0..4000) |_| _ = try tick(&state, profile, 0.01);
    try std.testing.expectEqual(motion.Response{}, state.response);
}

test "PSM01 constant external acceleration tends to the correct forced equilibrium" {
    var config = profile;
    config.inertial_gain = 0;
    config.external_gain = 0.5;
    var state = try motion.State.init(config, 0);
    for (0..6000) |_| {
        _ = try state.step(config, .{ .driver = .{ .position = 0 }, .external_acceleration = -9.8 });
    }
    // Continuous equilibrium k*x = gain*a; 1e-6 U covers accumulated f32
    // rounding, and checks that acceleration is not confused with target U.
    try std.testing.expectApproxEqAbs(@as(f32, -4.9 / 144.0), state.response.offset, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0), state.response.velocity, tolerance);
    std.debug.print("PSM01 gravity equilibrium={d:.8}\n", .{state.response.offset});
}

test "PSM01 settling preserves turning points and arbitrarily small nonzero forcing" {
    var state = try motion.State.init(profile, 0);
    state.response.offset = 0.01;
    try std.testing.expect((try tick(&state, profile, 0)).offset > 0);
    try state.reset(profile, 0);
    const output = try state.step(profile, .{
        .driver = .{ .position = 0 },
        .external_acceleration = 1e-5,
    });
    try std.testing.expect(output.offset > 0 and output.velocity > 0);
    try state.reset(profile, 0);
    var disabled = profile;
    disabled.inertial_gain = 0;
    disabled.external_gain = 0;
    const off = try state.step(disabled, .{
        .driver = .{ .position = 1 },
        .external_acceleration = 100,
    });
    try std.testing.expectEqual(motion.Response{}, off);
}

test "PSM01 all profile fields reject NaN and infinities" {
    inline for (std.meta.fields(motion.Profile)) |field| {
        for ([_]f32{ std.math.nan(f32), std.math.inf(f32), -std.math.inf(f32) }) |invalid| {
            var config = profile;
            @field(config, field.name) = invalid;
            try std.testing.expectError(error.NonFiniteMotionProfile, config.validate());
        }
    }
}

test "PSM01 invalid zero negative contradictory and unstable profiles fail closed" {
    var config = profile;
    config.stiffness = 0;
    try std.testing.expectError(error.InvalidMotionStiffness, config.validate());
    config = profile;
    config.damping = -1;
    try std.testing.expectError(error.InvalidMotionDamping, config.validate());
    config.damping = 0;
    try std.testing.expectError(error.InvalidMotionDamping, config.validate());
    config = profile;
    config.stiffness = 60_000;
    try std.testing.expectError(error.UnstableMotionProfile, config.validate());
    config = profile;
    config.damping = 300;
    try std.testing.expectError(error.UnstableMotionProfile, config.validate());
    inline for (.{ "inertial_gain", "external_gain" }) |field| {
        for ([_]f32{ -1, 101 }) |value| {
            config = profile;
            @field(config, field) = value;
            try std.testing.expectError(error.InvalidMotionGain, config.validate());
        }
    }
    for ([_]f32{ -1, 0, 1e-7, 1e7 }) |value| {
        config = profile;
        config.maximum_displacement = value;
        try std.testing.expectError(error.InvalidMotionLimit, config.validate());
    }
    for ([_]f32{ -1, 0, 1e7 }) |value| {
        config = profile;
        config.maximum_velocity = value;
        try std.testing.expectError(error.InvalidMotionLimit, config.validate());
    }
    config = profile;
    config.settle_displacement = config.maximum_displacement;
    try std.testing.expectError(error.InvalidMotionSettling, config.validate());
    config = profile;
    config.settle_velocity = 0;
    try std.testing.expectError(error.InvalidMotionSettling, config.validate());
    config = profile;
    config.maximum_velocity = config.settle_velocity;
    try std.testing.expectError(error.InvalidMotionSettling, config.validate());
}

test "PSM01 rejected inputs overflow and state leave the complete instance unchanged" {
    var state = try motion.State.init(profile, 0);
    try state.applyVelocityImpulse(profile, 1);
    const before = state;
    for ([_]f32{ std.math.nan(f32), std.math.inf(f32), -std.math.inf(f32) }) |value| {
        try std.testing.expectError(error.NonFiniteMotionInput, tick(&state, profile, value));
        try expectSame(before, state);
        try std.testing.expectError(error.NonFiniteMotionInput, state.step(profile, .{
            .driver = .{ .position = 0, .discontinuity = true },
            .external_acceleration = value,
        }));
        try expectSame(before, state);
        try std.testing.expectError(error.NonFiniteSpringState, state.applyVelocityImpulse(profile, value));
        try expectSame(before, state);
        try std.testing.expectError(error.NonFiniteMotionInput, state.reset(profile, value));
        try expectSame(before, state);
    }
    try std.testing.expectError(error.MotionNumericalOverflow, tick(&state, profile, std.math.floatMax(f32)));
    try expectSame(before, state);
    var gain = profile;
    gain.external_gain = 100;
    try std.testing.expectError(error.MotionNumericalOverflow, state.step(gain, .{
        .driver = .{ .position = 0 },
        .external_acceleration = std.math.floatMax(f32),
    }));
    try expectSame(before, state);
    state.response.offset = profile.maximum_displacement * 2;
    const invalid_state = state;
    try std.testing.expectError(error.InvalidMotionState, tick(&state, profile, 0));
    try expectSame(invalid_state, state);
    state = before;
    state.fixed_ticks = std.math.maxInt(u64);
    const overflowed = state;
    try std.testing.expectError(error.MotionTickOverflow, tick(&state, profile, 0));
    try expectSame(overflowed, state);
}

test "PSM01 supported envelope extremes remain finite and bounded through forced long runs" {
    var configurations: usize = 0;
    for ([_]f32{ 1, 144, 57_599 }) |stiffness| {
        for ([_]f32{ 0.01, 12, 239.99 }) |damping| {
            for ([_]f32{ 1e-6, 1e6 }) |limit| {
                for ([_]?f32{ null, 1e6 }) |velocity_limit| {
                    const config = motion.Profile{
                        .stiffness = stiffness,
                        .damping = damping,
                        .maximum_displacement = limit,
                        .maximum_velocity = velocity_limit,
                        .settle_displacement = limit * 0.001,
                        .settle_velocity = 1e-7,
                        .inertial_gain = 100,
                        .external_gain = 100,
                    };
                    var state = try motion.State.init(config, 0);
                    try state.applyVelocityImpulse(config, 1000);
                    for (0..24_000) |index| {
                        const driven = index < 2000;
                        const position: f32 = if (driven and index % 2 == 0) 1 else 0;
                        const output = try state.step(config, .{
                            .driver = .{ .position = position },
                            .external_acceleration = if (driven) -1000 else 0,
                        });
                        try std.testing.expect(std.math.isFinite(output.offset) and std.math.isFinite(output.velocity));
                        try std.testing.expect(@abs(output.offset) <= limit);
                        if (velocity_limit) |cap| try std.testing.expect(@abs(output.velocity) <= cap);
                    }
                    configurations += 1;
                }
            }
        }
    }
    std.debug.print("PSM01 stable_envelope configurations={d} ticks_each=24000\n", .{configurations});
}

fn path(time: f32) f32 {
    // One common normalized cosine path, sampled only by the fixture.
    return 0.02 * (1 - @cos(2 * std.math.pi * 0.25 * time));
}

fn replayPartitions(groups: []const u8) !motion.State {
    var clock = try fixed_step.Clock.init(.{});
    var state = try motion.State.init(profile, path(0));
    var tick_index: u32 = 0;
    for (groups) |group| {
        const frame = try clock.beginFrame(@as(f64, @floatFromInt(group)) * fixed_step.fixed_dt_seconds);
        for (0..frame.substeps) |_| {
            tick_index += 1;
            if (tick_index == 83) try state.applyVelocityImpulse(profile, 0.2);
            _ = try tick(&state, profile, path(@as(f32, @floatFromInt(tick_index)) * motion.fixed_dt));
        }
        try std.testing.expectEqual(@as(f64, 0), frame.discarded_time);
    }
    return state;
}

test "PSM01 identical fixed ticks ignore render partitions including zero tick frames" {
    const singles = [_]u8{1} ** 240;
    const fours = [_]u8{4} ** 60;
    const mixed = [_]u8{ 0, 1, 7, 0, 3, 5 } ** 15;
    const first = try replayPartitions(&singles);
    try expectSame(first, try replayPartitions(&fours));
    try expectSame(first, try replayPartitions(&mixed));
    try std.testing.expectEqual(@as(u64, 240), first.fixed_ticks);
}

test "PSM01 pause single step and resumed clock retain established lifecycle" {
    var clock = try fixed_step.Clock.init(.{});
    var state = try motion.State.init(profile, 0);
    try state.applyVelocityImpulse(profile, 1);
    const before = state;
    clock.setPaused(true);
    for (0..100) |_| {
        const frame = try clock.beginFrame(0.05);
        for (0..frame.substeps) |_| _ = try tick(&state, profile, 0);
    }
    try expectSame(before, state);
    clock.requestSingleStep();
    const frame = try clock.beginFrame(0.05);
    try std.testing.expectEqual(@as(u8, 1), frame.substeps);
    for (0..frame.substeps) |_| _ = try tick(&state, profile, 0);
    try std.testing.expectEqual(@as(u64, 1), state.fixed_ticks);
    clock.setPaused(false);
    const resumed = try clock.beginFrame(fixed_step.fixed_dt_seconds);
    try std.testing.expectEqual(@as(u8, 1), resumed.substeps);
}

fn pathPeak(rate: f32) !f32 {
    var state = try motion.State.init(profile, path(0));
    var peak: f32 = 0;
    // Ten common normalized cycles. At each rate only driver time changes.
    const count: u32 = @intFromFloat(40.0 / (rate * motion.fixed_dt));
    for (0..count) |index| {
        const time = @as(f32, @floatFromInt(index + 1)) * motion.fixed_dt * rate;
        const output = try tick(&state, profile, path(time));
        peak = @max(peak, @abs(output.offset));
    }
    return peak;
}

test "PSM01 faster same-path traversal naturally strengthens response with fixed dt" {
    const slow = try pathPeak(0.5);
    const normal = try pathPeak(1);
    const fast = try pathPeak(2);
    // All three frequencies are below the spring resonance. Acceleration
    // scales with rate squared: require clear separated responses here,
    // without claiming monotonic amplification at arbitrary frequencies.
    try std.testing.expect(normal > 3 * slow);
    try std.testing.expect(fast > 3 * normal);
    try std.testing.expect(fast < profile.maximum_displacement);
    try std.testing.expectEqual(@as(f32, @floatCast(fixed_step.fixed_dt_seconds)), motion.fixed_dt);
    std.debug.print("PSM01 playback peaks 0.5x={d:.8} 1x={d:.8} 2x={d:.8} dt={d:.9}\n", .{ slow, normal, fast, motion.fixed_dt });
}

test "PSM01 retimed sampled input and precomputed trajectory agree without a second rate factor" {
    var retimed = try motion.State.init(profile, 0);
    var precomputed = retimed;
    for (0..480) |index| {
        // Binary-exact positions: retiming a normalized ramp 2x and indexing
        // its already-retimed sample table must produce identical histories.
        const unit = @as(f32, @floatFromInt(index + 1)) / 1024;
        _ = try tick(&retimed, profile, unit * 2);
        _ = try tick(&precomputed, profile, @as(f32, @floatFromInt((index + 1) * 2)) / 1024);
        try expectSame(retimed, precomputed);
    }
    // A constant-speed ramp has one start transient; it does not supply a
    // persistent acceleration merely because its positions keep changing.
    for (0..4000) |index| {
        _ = try tick(&retimed, profile, @as(f32, @floatFromInt(481 + index)) / 512);
    }
    try std.testing.expectEqual(motion.Response{}, retimed.response);
}

test "PSM01 independent channel ordering cannot change per-instance traces" {
    var forward = [_]motion.State{
        try motion.State.init(profile, 0), try motion.State.init(profile, 0),
        try motion.State.init(profile, 0),
    };
    var reverse = forward;
    for (0..1000) |tick_index| {
        for (0..3) |index| {
            _ = try tick(&forward[index], profile, path(@as(f32, @floatFromInt(tick_index * (index + 1))) * motion.fixed_dt));
        }
        for (0..3) |reversed| {
            const index = 2 - reversed;
            _ = try tick(&reverse[index], profile, path(@as(f32, @floatFromInt(tick_index * (index + 1))) * motion.fixed_dt));
        }
        for (forward, reverse) |left, right| try expectSame(left, right);
    }
}

test "PSM01 legacy and zero-acceleration paths match accepted base-commit spring samples" {
    const config = spring.Configuration{
        .stiffness = 180,
        .damping = 22,
        .maximum_displacement = 0.06,
        .maximum_velocity = 2.4,
    };
    // Captured by running the spring source from cb60fc9a9b24ba7d69578ffc721948e9b00de8fd
    // with Zig 0.16.0 Debug Windows x64, before comparison to the new paths.
    const samples = [_]struct { tick: usize, offset: f32, velocity: f32 }{
        .{ .tick = 1, .offset = 0.009652778, .velocity = -0.083333336 },
        .{ .tick = 12, .offset = 0.009095982, .velocity = 0.030116135 },
        .{ .tick = 120, .offset = 0.020074176, .velocity = -0.000441230920 },
        .{ .tick = 181, .offset = -0.002618122, .velocity = -0.933918100 },
        .{ .tick = 240, .offset = -0.006931186, .velocity = 0.097023815 },
        .{ .tick = 2400, .offset = 0, .velocity = 0 },
    };
    var legacy = try spring.State.init(config, motion.fixed_dt, 0.01, -0.1, 0);
    var extended = legacy;
    var sample_index: usize = 0;
    for (0..2400) |index| {
        const target: f32 = if (index < 120) 0.02 else 0;
        try legacy.setTarget(target, config);
        try extended.setTarget(target, config);
        if (index == 180) {
            try legacy.applyVelocityImpulse(-1, config);
            try extended.applyVelocityImpulse(-1, config);
        }
        try legacy.step(config, motion.fixed_dt);
        try extended.stepWithAcceleration(config, motion.fixed_dt, 0);
        if (index + 1 == samples[sample_index].tick) {
            const expected = samples[sample_index];
            // 1e-7 U and 1e-6 U/s allow decimal capture/f32 rounding; both
            // are small relative to the sampled motion, including reversals.
            for ([_]spring.State{ legacy, extended }) |actual| {
                try std.testing.expectApproxEqAbs(expected.offset, actual.offset, 1e-7);
                try std.testing.expectApproxEqAbs(expected.velocity, actual.velocity, tolerance);
            }
            sample_index += 1;
        }
    }
    try std.testing.expectEqual(samples.len, sample_index);
}
