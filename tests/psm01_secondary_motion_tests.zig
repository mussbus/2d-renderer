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
        try state.applyVelocityDelta(profile, 0);
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
    try first.applyVelocityDelta(profile, 1);
    try replay.applyVelocityDelta(profile, 1);
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
    try free.applyVelocityDelta(profile, 1);
    const next = try tick(&free, profile, 0);
    var config = profile;
    config.maximum_displacement = next.offset;
    var outward = try motion.State.init(config, 0);
    try outward.applyVelocityDelta(config, 1);
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
    try limited.applyVelocityDelta(config, 10);
    try free.applyVelocityDelta(profile, 10);
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
    try state.applyVelocityDelta(profile, 3);
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
    try state.applyVelocityDelta(profile, 1);
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
    try state.applyVelocityDelta(profile, 1);
    const before = state;
    for ([_]f32{ std.math.nan(f32), std.math.inf(f32), -std.math.inf(f32) }) |value| {
        try std.testing.expectError(error.NonFiniteMotionInput, tick(&state, profile, value));
        try expectSame(before, state);
        try std.testing.expectError(error.NonFiniteMotionInput, state.step(profile, .{
            .driver = .{ .position = 0, .discontinuity = true },
            .external_acceleration = value,
        }));
        try expectSame(before, state);
        try std.testing.expectError(error.NonFiniteSpringState, state.applyVelocityDelta(profile, value));
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
                    try state.applyVelocityDelta(config, 1000);
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
            if (tick_index == 83) try state.applyVelocityDelta(profile, 0.2);
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
    try state.applyVelocityDelta(profile, 1);
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

const rate_response = @import("secondary_motion_rate");

// Synthetic calibration only: no production content or anatomical defaults.
// k/c remain the authorities; omega=sqrt(k), zeta=c/(2*sqrt(k)).
const calibration_knots = [_]rate_response.Knot{
    .{ .rate = 0.5, .multipliers = .{ .stiffness = 0.25, .damping = 0.5 } },
    .{ .rate = 1 },
    .{ .rate = 2, .multipliers = .{ .stiffness = 4, .damping = 1, .inertial_gain = 2, .external_gain = 2 } },
};
const calibration_policy = rate_response.Policy{ .knots = &calibration_knots };
const rates = [_]f32{ 0.5, 1, 2 };

fn expectProfileBits(expected: motion.Profile, actual: motion.Profile) !void {
    inline for (std.meta.fields(motion.Profile)) |field| {
        if (comptime field.type == ?f32) {
            const left = @field(expected, field.name);
            const right = @field(actual, field.name);
            try std.testing.expectEqual(left == null, right == null);
            if (left) |value| {
                try std.testing.expectEqual(@as(u32, @bitCast(value)), @as(u32, @bitCast(right.?)));
            }
        } else {
            try std.testing.expectEqual(@as(u32, @bitCast(@field(expected, field.name))), @as(u32, @bitCast(@field(actual, field.name))));
        }
    }
}

test "PSM01 identity policy preserves base profile bits and every response tick" {
    const identity = rate_response.Policy{};
    var base = profile;
    base.maximum_velocity = 2;
    base.inertial_gain = -0.0;
    for ([_]f32{ 0.25, 0.5, 1, 1.75, 2, 4 }) |rate| {
        const resolved = try identity.resolve(base, rate);
        try expectProfileBits(base, resolved);
        var original = try motion.State.init(base, 0);
        original.response.offset = 0.1;
        var corrected = original;
        for (0..480) |index| {
            const input = motion.TickInput{
                .driver = .{ .position = path(@as(f32, @floatFromInt(index)) * motion.fixed_dt) },
                .external_acceleration = if (index < 120) -0.1 else 0,
            };
            _ = try original.step(base, input);
            _ = try corrected.step(resolved, input);
            try expectSame(original, corrected);
        }
    }
    try expectProfileBits(profile, try calibration_policy.resolve(profile, 1));
}

test "PSM01 rate resolution is deterministic and linear between authored knots" {
    const expected = motion.Profile{
        .stiffness = 360,
        .damping = 12,
        .inertial_gain = 1.5,
        .external_gain = 1.5,
    };
    const first = try calibration_policy.resolve(profile, 1.5);
    try expectProfileBits(expected, first);
    for (0..1000) |_| try expectProfileBits(first, try calibration_policy.resolve(profile, 1.5));
    const slow_midpoint = try calibration_policy.resolve(profile, 0.75);
    try std.testing.expectEqual(@as(f32, 90), slow_midpoint.stiffness);
    try std.testing.expectEqual(@as(f32, 9), slow_midpoint.damping);
}

test "PSM01 supported endpoints are inclusive and out of range rates are rejected" {
    const slow = try calibration_policy.resolve(profile, 0.5);
    const fast = try calibration_policy.resolve(profile, 2);
    try std.testing.expectEqual(@as(f32, 36), slow.stiffness);
    try std.testing.expectEqual(@as(f32, 576), fast.stiffness);
    for ([_]f32{ 0.49999, 2.00001, 0.01, 100 }) |rate| {
        try std.testing.expectError(error.MotionRateOutOfRange, calibration_policy.resolve(profile, rate));
    }
    try std.testing.expectEqual(@as(f32, 144), (try (rate_response.Policy{}).resolve(profile, 4)).stiffness);
}

test "PSM01 malformed knot counts order range and reference fail validation" {
    const empty = rate_response.Policy{ .knots = &.{} };
    try std.testing.expectError(error.InvalidMotionRateKnots, empty.validate(profile));
    const short = rate_response.Policy{ .knots = calibration_knots[0..2] };
    try std.testing.expectError(error.InvalidMotionRateKnots, short.validate(profile));
    const excessive = [_]rate_response.Knot{.{ .rate = 1 }} ** (rate_response.maximum_knots + 1);
    try std.testing.expectError(error.InvalidMotionRateKnots, (rate_response.Policy{ .knots = &excessive }).validate(profile));
    var knots = calibration_knots;
    knots[2].rate = 1;
    try std.testing.expectError(error.InvalidMotionRateKnots, (rate_response.Policy{ .knots = &knots }).validate(profile));
    knots = calibration_knots;
    knots[2].rate = 0.75;
    try std.testing.expectError(error.InvalidMotionRateKnots, (rate_response.Policy{ .knots = &knots }).validate(profile));
    knots = calibration_knots;
    knots[1].rate = 0.75;
    try std.testing.expectError(error.MissingMotionRateReference, (rate_response.Policy{ .knots = &knots }).validate(profile));
    knots = .{ .{ .rate = 1 }, .{ .rate = 2 }, .{ .rate = 3 } };
    try std.testing.expectError(error.InvalidMotionRateKnots, (rate_response.Policy{ .knots = &knots }).validate(profile));
    knots = .{ .{ .rate = 0.25 }, .{ .rate = 0.5 }, .{ .rate = 1 } };
    try std.testing.expectError(error.InvalidMotionRateKnots, (rate_response.Policy{ .knots = &knots }).validate(profile));
    knots = calibration_knots;
    knots[1].multipliers.damping = 2;
    try std.testing.expectError(error.NonIdentityMotionRateReference, (rate_response.Policy{ .knots = &knots }).validate(profile));
}

test "PSM01 query and knot rates reject nonfinite and nonpositive values" {
    for ([_]f32{ std.math.nan(f32), std.math.inf(f32), -std.math.inf(f32), 0, -1 }) |invalid| {
        try std.testing.expectError(error.InvalidMotionRate, calibration_policy.resolve(profile, invalid));
        for (0..calibration_knots.len) |index| {
            var knots = calibration_knots;
            knots[index].rate = invalid;
            try std.testing.expectError(error.InvalidMotionRate, (rate_response.Policy{ .knots = &knots }).validate(profile));
        }
    }
}

test "PSM01 every rate multiplier rejects nonfinite negative and excessive values" {
    inline for (std.meta.fields(rate_response.Multipliers)) |field| {
        for ([_]f32{ std.math.nan(f32), std.math.inf(f32), -std.math.inf(f32), -0.1, 100.01 }) |invalid| {
            var knots = calibration_knots;
            @field(knots[2].multipliers, field.name) = invalid;
            try std.testing.expectError(error.InvalidMotionRateMultiplier, (rate_response.Policy{ .knots = &knots }).validate(profile));
        }
    }
    inline for (.{ "stiffness", "damping" }) |field| {
        var knots = calibration_knots;
        @field(knots[0].multipliers, field) = 0;
        try std.testing.expectError(error.InvalidMotionRateMultiplier, (rate_response.Policy{ .knots = &knots }).validate(profile));
    }
    var knots = calibration_knots;
    knots[0].multipliers.inertial_gain = 0;
    knots[0].multipliers.external_gain = 0;
    const disabled = try (rate_response.Policy{ .knots = &knots }).resolve(profile, 0.5);
    try std.testing.expectEqual(@as(f32, 0), disabled.inertial_gain);
    try std.testing.expectEqual(@as(f32, 0), disabled.external_gain);
}

test "PSM01 curve validation rejects unsafe profiles even at unqueried knots" {
    var base = profile;
    base.stiffness = 20_000;
    try base.validate();
    try std.testing.expectError(error.UnstableMotionProfile, calibration_policy.resolve(base, 1));
    base = profile;
    base.inertial_gain = 60;
    try base.validate();
    try std.testing.expectError(error.InvalidMotionGain, calibration_policy.resolve(base, 1));
    var knots = calibration_knots;
    knots[0].multipliers.damping = 0.0001;
    try std.testing.expectError(error.InvalidMotionDamping, (rate_response.Policy{ .knots = &knots }).validate(profile));
    knots = calibration_knots;
    knots[0].multipliers.stiffness = 0.001;
    try std.testing.expectError(error.InvalidMotionStiffness, (rate_response.Policy{ .knots = &knots }).validate(profile));
    knots = calibration_knots;
    knots[2].multipliers.damping = 100;
    try std.testing.expectError(error.UnstableMotionProfile, (rate_response.Policy{ .knots = &knots }).validate(profile));
    base = profile;
    base.damping = std.math.inf(f32);
    try std.testing.expectError(error.NonFiniteMotionProfile, calibration_policy.resolve(base, 1));
}

test "PSM01 integrator accepts only explicit established dt independently of semantic rate" {
    var reference = try motion.State.init(profile, 0);
    try reference.applyVelocityDelta(profile, 1);
    _ = try reference.step(profile, .{ .driver = .{ .position = 0 } });
    for (rates) |rate| {
        const config = try (rate_response.Policy{}).resolve(profile, rate);
        var state = try motion.State.init(config, 0);
        try state.applyVelocityDelta(config, 1);
        _ = try state.step(config, .{
            .driver = .{ .position = 0 },
            .fixed_dt_seconds = fixed_step.fixed_dt_seconds,
        });
        try expectSame(reference, state);
        const before = state;
        for ([_]f64{ 0, -1, std.math.nan(f64), std.math.inf(f64), -std.math.inf(f64), fixed_step.fixed_dt_seconds * 0.5, fixed_step.fixed_dt_seconds * 2 }) |invalid| {
            try std.testing.expectError(error.UnsupportedMotionTimestep, state.step(config, .{
                .driver = .{ .position = 4, .discontinuity = true },
                .fixed_dt_seconds = invalid,
            }));
            try expectSame(before, state);
        }
    }
}

const Calibration = struct {
    first_crossing: usize = 0,
    kick_peak_tick: usize = 0,
    settled_tick: usize = 0,
    minimum: f32 = 0,
};

fn measureCalibration(config: motion.Profile) !Calibration {
    var displaced = try motion.State.init(config, 0);
    displaced.response.offset = 0.1;
    var kicked = try motion.State.init(config, 0);
    try kicked.applyVelocityDelta(config, 0.5);
    var metrics: Calibration = .{};
    var peak: f32 = 0;
    for (1..6001) |index| {
        const output = try tick(&displaced, config, 0);
        const kick = try tick(&kicked, config, 0);
        if (output.offset < 0 and metrics.first_crossing == 0) metrics.first_crossing = index;
        if (kick.offset > peak) {
            peak = kick.offset;
            metrics.kick_peak_tick = index;
        }
        metrics.minimum = @min(metrics.minimum, output.offset);
        if (std.meta.eql(output, motion.Response{}) and metrics.settled_tick == 0) metrics.settled_tick = index;
        try std.testing.expect(@abs(output.offset) < config.maximum_displacement);
    }
    try std.testing.expect(metrics.first_crossing > 0 and metrics.settled_tick > 0);
    return metrics;
}

test "PSM01 authored calibration gives slower lag and settling and faster energetic reversal" {
    var metrics: [3]Calibration = undefined;
    for (rates, 0..) |rate, index| {
        const config = try calibration_policy.resolve(profile, rate);
        metrics[index] = try measureCalibration(config);
        const sample = metrics[index];
        std.debug.print("PSM01 correction calibration rate={d:.1} omega={d:.2} zeta={d:.2} first_crossing={d} kick_peak={d} settled={d} minimum={d:.8}\n", .{
            rate,                  @sqrt(config.stiffness), config.damping / (2 * @sqrt(config.stiffness)),
            sample.first_crossing, sample.kick_peak_tick,   sample.settled_tick,
            sample.minimum,
        });
    }
    // Tick separations are intentionally large compared with one-tick sampling.
    // Peak delay after the same delta-v is the fixture's measurable lag.
    try std.testing.expect(metrics[0].kick_peak_tick > metrics[1].kick_peak_tick * 3 / 2);
    try std.testing.expect(metrics[0].first_crossing > metrics[1].first_crossing * 3 / 2);
    try std.testing.expect(metrics[0].settled_tick > metrics[1].settled_tick * 3 / 2);
    try std.testing.expect(metrics[2].first_crossing < metrics[1].first_crossing);
    try std.testing.expect(metrics[2].kick_peak_tick < metrics[1].kick_peak_tick);
    try std.testing.expect(@abs(metrics[2].minimum) > 2 * @abs(metrics[1].minimum));
}

fn resolvedPathPeak(policy: rate_response.Policy, semantic_rate: f32) !f32 {
    const config = try policy.resolve(profile, semantic_rate);
    var state = try motion.State.init(config, path(0));
    var peak: f32 = 0;
    const count: u32 = @intFromFloat(40.0 / (semantic_rate * motion.fixed_dt));
    for (0..count) |index| {
        const time = @as(f32, @floatFromInt(index + 1)) * motion.fixed_dt * semantic_rate;
        const output = try tick(&state, config, path(time));
        peak = @max(peak, @abs(output.offset));
    }
    try std.testing.expect(peak < profile.maximum_displacement);
    return peak;
}

test "PSM01 natural trajectory speed and authored rate effects are measured separately" {
    for (rates) |rate| {
        const natural = try resolvedPathPeak(.{}, rate);
        try std.testing.expectEqual(@as(u32, @bitCast(try pathPeak(rate))), @as(u32, @bitCast(natural)));
        const authored = try resolvedPathPeak(calibration_policy, rate);
        if (rate == 1) {
            try std.testing.expectEqual(@as(u32, @bitCast(natural)), @as(u32, @bitCast(authored)));
        } else {
            try std.testing.expect(@abs(natural - authored) > 0.00001);
        }
        std.debug.print("PSM01 correction trajectory rate={d:.1} natural_peak={d:.8} authored_peak={d:.8}\n", .{ rate, natural, authored });
    }
}

test "PSM01 dynamic rate reevaluation preserves response history and tick continuity" {
    var state = try motion.State.init(profile, 0);
    state.response = .{ .offset = 0.02, .velocity = 0.1 };
    var replay = state;
    for (0..1200) |index| {
        const rate: f32 = switch ((index / 80) % 3) {
            0 => 0.5,
            1 => 1,
            else => 2,
        };
        const before = state;
        const config = try calibration_policy.resolve(profile, rate);
        try expectSame(before, state);
        try std.testing.expectEqual(profile.maximum_displacement, config.maximum_displacement);
        try std.testing.expectEqual(profile.maximum_velocity, config.maximum_velocity);
        const input = motion.TickInput{
            .driver = .{ .position = path(@as(f32, @floatFromInt(index + 1)) * motion.fixed_dt) },
        };
        _ = try state.step(config, input);
        _ = try replay.step(try calibration_policy.resolve(profile, rate), input);
        try expectSame(state, replay);
        try std.testing.expectEqual(@as(u64, @intCast(index + 1)), state.fixed_ticks);
        try std.testing.expect(std.math.isFinite(state.response.velocity));
        try std.testing.expect(@abs(state.response.offset) < profile.maximum_displacement);
        if (index % 80 == 0) try std.testing.expect(!std.meta.eql(state.response, motion.Response{}));
    }
}

test "PSM01 frozen driver continues settling under each resolved profile" {
    for (rates) |rate| {
        const config = try calibration_policy.resolve(profile, rate);
        var state = try motion.State.init(config, 5);
        try state.applyVelocityDelta(config, 0.5);
        for (0..6000) |_| _ = try tick(&state, config, 5);
        try std.testing.expectEqual(motion.Response{}, state.response);
        try std.testing.expectEqual(@as(u64, 6000), state.fixed_ticks);
    }
    // Global pause is separately exercised above through fixed_step.Clock:
    // 100 paused frames preserve full state; single-step advances exactly once.
}

const EvaluationSample = struct {
    rate: f32,
    driver: motion.DriverSample,
    external_acceleration: f32 = 0,
    velocity_delta: ?f32 = null,
    reset: bool = false,
};

fn evaluateSample(
    state: *motion.State,
    base: motion.Profile,
    policy: rate_response.Policy,
    dt: f64,
    sample: EvaluationSample,
) !void {
    const config = try policy.resolve(base, sample.rate);
    // Ordered caller commands: reset, optional delta-v, then sample the tick.
    // A teleport within step deliberately clears any preceding kick.
    if (sample.reset) try state.reset(config, sample.driver.position);
    if (sample.velocity_delta) |delta| try state.applyVelocityDelta(config, delta);
    _ = try state.step(config, .{
        .driver = sample.driver,
        .external_acceleration = sample.external_acceleration,
        .fixed_dt_seconds = dt,
    });
}

fn evaluateOffline(
    base: motion.Profile,
    policy: rate_response.Policy,
    initial: motion.State,
    dt: f64,
    samples: []const EvaluationSample,
    trace: []motion.State,
) !void {
    try std.testing.expectEqual(samples.len, trace.len);
    var state = initial;
    for (samples, trace) |sample, *result| {
        try evaluateSample(&state, base, policy, dt, sample);
        result.* = state;
    }
}

fn evaluationSamples() [240]EvaluationSample {
    var samples: [240]EvaluationSample = undefined;
    var phase: f32 = 0;
    for (&samples, 0..) |*sample, index| {
        const rate: f32 = if (index < 80) 0.5 else if (index < 160) 1 else 2;
        phase += rate * motion.fixed_dt;
        sample.* = .{
            .rate = rate,
            .driver = .{
                .position = path(phase) + @as(f32, if (index >= 160) 1 else 0),
                .discontinuity = index == 160,
            },
            .external_acceleration = if (index >= 30 and index < 60) -0.2 else 0,
            .velocity_delta = if (index == 4 or index == 90) 0.1 else null,
            .reset = index == 120,
        };
    }
    return samples;
}

test "PSM01 offline evaluation repeats every complete trace state from explicit inputs" {
    const samples = evaluationSamples();
    var initial = try motion.State.init(profile, 0);
    initial.response = .{ .offset = 0.01, .velocity = 0.02 };
    var first: [240]motion.State = undefined;
    var second: [240]motion.State = undefined;
    try evaluateOffline(profile, calibration_policy, initial, fixed_step.fixed_dt_seconds, &samples, &first);
    try evaluateOffline(profile, calibration_policy, initial, fixed_step.fixed_dt_seconds, &samples, &second);
    for (first, second) |left, right| try expectSame(left, right);
    try std.testing.expectEqual(@as(u64, 1), first[120].fixed_ticks);
    try std.testing.expectEqual(motion.Response{}, first[160].response);
    try std.testing.expectEqual(@as(u64, 120), first[239].fixed_ticks);
    std.debug.print("PSM01 correction offline repeated_trace_states=240 reset_tick=121 teleport_tick=161\n", .{});
}

test "PSM01 runtime frame groups and offline evaluation produce identical ordered traces" {
    const samples = evaluationSamples();
    var initial = try motion.State.init(profile, 0);
    initial.response = .{ .offset = 0.01, .velocity = 0.02 };
    var offline: [240]motion.State = undefined;
    try evaluateOffline(profile, calibration_policy, initial, fixed_step.fixed_dt_seconds, &samples, &offline);
    const singles = [_]u8{1} ** 240;
    const fours = [_]u8{4} ** 60;
    const mixed = [_]u8{ 0, 1, 7, 0, 3, 5 } ** 15;
    for ([_][]const u8{ &singles, &fours, &mixed }) |groups| {
        var clock = try fixed_step.Clock.init(.{});
        var state = initial;
        var cursor: usize = 0;
        for (groups) |group| {
            const frame = try clock.beginFrame(@as(f64, @floatFromInt(group)) * fixed_step.fixed_dt_seconds);
            try std.testing.expectEqual(@as(f64, 0), frame.discarded_time);
            for (0..frame.substeps) |_| {
                try evaluateSample(&state, profile, calibration_policy, clock.configuration.fixed_dt, samples[cursor]);
                try expectSame(offline[cursor], state);
                cursor += 1;
            }
        }
        try std.testing.expectEqual(samples.len, cursor);
    }
    std.debug.print("PSM01 correction runtime_offline states=240 frame_partitions=3 exact=true\n", .{});
}

test "PSM01 driver acceleration and independent external acceleration superpose without duplicate target force" {
    const config = motion.Profile{
        .inertial_gain = 0.75,
        .external_gain = 0.5,
        .maximum_displacement = 10,
        .settle_displacement = 1e-12,
        .settle_velocity = 1e-12,
    };
    var movement = try motion.State.init(config, 0);
    var external = movement;
    var combined = movement;
    var disabled_driver = movement;
    var no_inertia = config;
    no_inertia.inertial_gain = 0;
    var maximum_error: f32 = 0;
    for (1..241) |index| {
        const n: f32 = @floatFromInt(index);
        const position = 0.0001 * n * n;
        const moving = try movement.step(config, .{ .driver = .{ .position = position } });
        const independent = try external.step(config, .{ .driver = .{ .position = 0 }, .external_acceleration = 0.4 });
        const both = try combined.step(config, .{ .driver = .{ .position = position }, .external_acceleration = 0.4 });
        const no_target_force = try tick(&disabled_driver, no_inertia, position);
        try std.testing.expectEqual(motion.Response{}, no_target_force);
        // Linear superposition in the unconstrained regime; 1e-6 U and
        // 1e-5 U/s cover separate f32 accumulation, not excitation doubling.
        try std.testing.expectApproxEqAbs(moving.offset + independent.offset, both.offset, 1e-6);
        try std.testing.expectApproxEqAbs(moving.velocity + independent.velocity, both.velocity, 1e-5);
        maximum_error = @max(maximum_error, @abs(moving.offset + independent.offset - both.offset));
        try std.testing.expect(@abs(both.offset) < config.maximum_displacement);
        if (index == 1) {
            try std.testing.expect(moving.offset < 0);
            try std.testing.expect(independent.offset > 0);
            try std.testing.expect(both.offset > moving.offset);
        }
    }
    std.debug.print("PSM01 correction independent_forcing superposition_max_offset_error={d:.10}\n", .{maximum_error});
}

test "PSM01 velocity delta is immediate relative U per second with no mass or dt factor" {
    var state = try motion.State.init(profile, 3);
    state.response = .{ .offset = 0.02, .velocity = 0.25 };
    state.driver_velocity = 2;
    state.fixed_ticks = 7;
    var expected = state;
    expected.response.velocity = 1;
    try state.applyVelocityDelta(profile, 0.75);
    try expectSame(expected, state);
    expected.response.velocity = 0.5;
    try state.applyVelocityDelta(profile, -0.5);
    try expectSame(expected, state);
    var capped = profile;
    capped.maximum_velocity = 0.75;
    try state.applyVelocityDelta(capped, 1);
    try std.testing.expectEqual(@as(f32, 0.75), state.response.velocity);
    try std.testing.expect(@hasDecl(spring.State, "applyVelocityImpulse"));
    try std.testing.expect(!@hasDecl(motion.State, "applyVelocityImpulse"));
}

test "PSM01 resolved segments preserve limits and stay finite across the supported range" {
    var base = profile;
    base.maximum_velocity = 2;
    for (0..1501) |index| {
        const rate = 0.5 + @as(f32, @floatFromInt(index)) / 1000;
        const config = try calibration_policy.resolve(base, rate);
        try config.validate();
        try std.testing.expectEqual(base.maximum_displacement, config.maximum_displacement);
        try std.testing.expectEqual(base.maximum_velocity, config.maximum_velocity);
        try std.testing.expectEqual(base.settle_displacement, config.settle_displacement);
        try std.testing.expectEqual(base.settle_velocity, config.settle_velocity);
        var state = try motion.State.init(config, 0);
        try state.applyVelocityDelta(config, 0.1);
        for (0..48) |_| {
            const output = try tick(&state, config, 0);
            try std.testing.expect(std.math.isFinite(output.offset) and std.math.isFinite(output.velocity));
            try std.testing.expect(@abs(output.offset) <= config.maximum_displacement);
            try std.testing.expect(@abs(output.velocity) <= config.maximum_velocity.?);
        }
    }
}
