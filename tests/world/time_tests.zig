const std = @import("std");
const world = @import("world");
const time = world.time;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectError = std.testing.expectError;

fn configuration() time.Configuration {
    return .{
        .simulation_hz = 240,
        .rate = .{ .numerator = 1, .denominator = 1 },
        .day_duration_us = 1_234_567_890,
    };
}

test "initial epoch and zero advancement preserve the complete snapshot" {
    var clock = try world.WorldTime.init(configuration());
    const initial = clock.snapshot();
    try expectEqual(@as(u64, 0), initial.simulation_ticks);
    try expectEqual(@as(u64, 0), initial.day_index);
    try expectEqual(@as(u64, 0), initial.time_of_day_us);
    try expectEqual(@as(u64, 0), initial.submicrosecond_remainder);
    try clock.advanceSimulationTicks(0);
    try expectEqualDeep(initial, clock.snapshot());
}

test "240 Hz single step retains the exact two thirds microsecond" {
    var clock = try world.WorldTime.init(configuration());
    try clock.advanceSimulationTicks(1);
    try expectEqual(@as(u64, 1), clock.snapshot().simulation_ticks);
    try expectEqual(@as(u64, 4166), clock.snapshot().time_of_day_us);
    try expectEqual(@as(u64, 160), clock.snapshot().submicrosecond_remainder);
    try clock.advanceSimulationTicks(239);
    try expectEqual(@as(u128, 1_000_000), try clock.snapshot().totalWholeMicroseconds());
    try expectEqual(@as(u64, 0), clock.snapshot().submicrosecond_remainder);
}

test "nondefault rational rate has exact whole-second accumulation" {
    var config = configuration();
    config.rate = .{ .numerator = 7, .denominator = 3 };
    var clock = try world.WorldTime.init(config);
    try clock.advanceSimulationTicks(720);
    try expectEqual(@as(u64, 7_000_000), clock.snapshot().time_of_day_us);
    try expectEqual(@as(u64, 0), clock.snapshot().submicrosecond_remainder);
}

test "submicrosecond rate carry accumulates without rounding loss" {
    var config = configuration();
    config.simulation_hz = 1_000_000;
    config.rate = .{ .numerator = 1, .denominator = 3 };
    var clock = try world.WorldTime.init(config);
    try clock.advanceSimulationTicks(2);
    try expectEqual(@as(u64, 0), clock.snapshot().time_of_day_us);
    try expectEqual(@as(u64, 2_000_000), clock.snapshot().submicrosecond_remainder);
    try clock.advanceSimulationTicks(1);
    try expectEqual(@as(u64, 1), clock.snapshot().time_of_day_us);
    try expectEqual(@as(u64, 0), clock.snapshot().submicrosecond_remainder);
}

test "many partitions and one batch produce identical snapshots across rates and days" {
    for ([_]time.Rate{
        .{ .numerator = 0, .denominator = 1 },
        .{ .numerator = 1, .denominator = 7 },
        .{ .numerator = 17, .denominator = 3 },
        .{ .numerator = 1000, .denominator = 11 },
    }) |rate| {
        var config = configuration();
        config.rate = rate;
        config.day_duration_us = 1_000_003;
        var batch = try world.WorldTime.init(config);
        var single = batch;
        var chunks = batch;
        try batch.advanceSimulationTicks(100_000);
        for (0..100_000) |_| try single.advanceSimulationTicks(1);
        for (0..1000) |_| {
            try chunks.advanceSimulationTicks(31);
            try chunks.advanceSimulationTicks(0);
            try chunks.advanceSimulationTicks(69);
        }
        try expectEqualDeep(batch.snapshot(), single.snapshot());
        try expectEqualDeep(batch.snapshot(), chunks.snapshot());
    }
}

test "zero progression preserves fractional carry for the next supplied ticks" {
    var clock = try world.WorldTime.init(configuration());
    try clock.advanceSimulationTicks(1);
    const before = clock.snapshot();
    try clock.advanceSimulationTicks(0);
    try expectEqualDeep(before, clock.snapshot());
    try clock.advanceSimulationTicks(2);
    try expectEqual(@as(u64, 3), clock.snapshot().simulation_ticks);
    try expectEqual(@as(u64, 12_500), clock.snapshot().time_of_day_us);
    try expectEqual(@as(u64, 0), clock.snapshot().submicrosecond_remainder);
}

test "zero numeric rate adds no world duration for maximum legal tick batch" {
    var config = configuration();
    config.rate.numerator = 0;
    var clock = try world.WorldTime.init(config);
    try clock.advanceSimulationTicks(std.math.maxInt(u64));
    try expectEqual(@as(u128, 0), try clock.snapshot().totalWholeMicroseconds());
    const before = clock.snapshot();
    try expectError(error.SimulationTickOverflow, clock.advanceSimulationTicks(1));
    try expectEqualDeep(before, clock.snapshot());
    try clock.advanceSimulationTicks(0);
}

test "last legal intra-day microsecond rolls over precisely" {
    var config = configuration();
    config.simulation_hz = 1_000_000;
    var clock = try world.WorldTime.fromSnapshot(.{
        .configuration = config,
        .day_index = 9,
        .time_of_day_us = config.day_duration_us - 1,
    });
    try clock.advanceSimulationTicks(1);
    try expectEqual(@as(u64, 10), clock.snapshot().day_index);
    try expectEqual(@as(u64, 0), clock.snapshot().time_of_day_us);
    // The f64 convenience view uses a 1e-15 rounding tolerance near zero.
    try std.testing.expectApproxEqAbs(@as(f64, 0), try clock.snapshot().dayFraction(), 1e-15);
}

test "single call crosses multiple authored days and retains intra-day time" {
    var config = configuration();
    config.simulation_hz = 1;
    config.day_duration_us = 10_000_000;
    var clock = try world.WorldTime.init(config);
    try clock.advanceSimulationTicks(37);
    try expectEqual(@as(u64, 3), clock.snapshot().day_index);
    try expectEqual(@as(u64, 7_000_000), clock.snapshot().time_of_day_us);
    try expectEqual(@as(u128, 37_000_000), try clock.snapshot().totalWholeMicroseconds());
    // f64 division view is approximate; 1e-15 allows only rounding near 0.7.
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), try clock.snapshot().dayFraction(), 1e-15);
}

test "invalid configurations reject zero frequency denominator and day duration" {
    var config = configuration();
    config.simulation_hz = 0;
    try expectError(error.InvalidSimulationFrequency, world.WorldTime.init(config));
    config = configuration();
    config.rate.denominator = 0;
    try expectError(error.InvalidRateDenominator, world.WorldTime.init(config));
    config = configuration();
    config.day_duration_us = 0;
    try expectError(error.InvalidDayDuration, world.WorldTime.init(config));
}

test "restored snapshot rejects both noncanonical intra-day boundaries" {
    var value = (try world.WorldTime.init(configuration())).snapshot();
    value.time_of_day_us = value.configuration.day_duration_us;
    try expectError(error.InvalidTimeWithinDay, world.WorldTime.fromSnapshot(value));
    try expectError(error.InvalidTimeWithinDay, value.dayFraction());
    value.time_of_day_us = 0;
    value.submicrosecond_remainder = 240;
    try expectError(error.InvalidSubMicrosecondRemainder, world.WorldTime.fromSnapshot(value));
}

test "simulation exhaustion leaves the complete continuation state unchanged" {
    var clock = try world.WorldTime.fromSnapshot(.{
        .configuration = configuration(),
        .simulation_ticks = std.math.maxInt(u64),
        .day_index = 7,
        .time_of_day_us = 4166,
        .submicrosecond_remainder = 160,
    });
    const before = clock.snapshot();
    try expectError(error.SimulationTickOverflow, clock.advanceSimulationTicks(1));
    try expectEqualDeep(before, clock.snapshot());
}

test "world day exhaustion rejects atomically while zero advancement remains legal" {
    var config = configuration();
    config.simulation_hz = 1_000_000;
    var clock = try world.WorldTime.fromSnapshot(.{
        .configuration = config,
        .day_index = std.math.maxInt(u64),
        .time_of_day_us = config.day_duration_us - 1,
    });
    const before = clock.snapshot();
    try clock.advanceSimulationTicks(0);
    try expectError(error.WorldDayOverflow, clock.advanceSimulationTicks(1));
    try expectEqualDeep(before, clock.snapshot());
}

test "extreme legal arithmetic neither overflows intermediates nor rounds phase to one" {
    const config = time.Configuration{
        .simulation_hz = std.math.maxInt(u32),
        .rate = .{ .numerator = std.math.maxInt(u32), .denominator = std.math.maxInt(u32) },
        .day_duration_us = std.math.maxInt(u64),
    };
    var clock = try world.WorldTime.init(config);
    try clock.advanceSimulationTicks(std.math.maxInt(u64));
    // (2^64-1)/(2^32-1) = 2^32+1 exactly; equal numerator/denominator cancel.
    try expectEqual(@as(u64, 4_294_967_297_000_000), clock.snapshot().time_of_day_us);
    try expectEqual(@as(u64, 0), clock.snapshot().submicrosecond_remainder);
    var end = clock.snapshot();
    end.day_index = std.math.maxInt(u64);
    end.time_of_day_us = config.day_duration_us - 1;
    end.submicrosecond_remainder = @as(u64, std.math.maxInt(u32)) * std.math.maxInt(u32) - 1;
    try expect((try end.dayFraction()) < 1);
    try expect((try end.totalWholeMicroseconds()) > std.math.maxInt(u64));
}

test "largest increment rejects day overflow instead of trapping in any build mode" {
    var config = configuration();
    config.simulation_hz = 1;
    config.rate.numerator = std.math.maxInt(u32);
    config.day_duration_us = 1;
    var clock = try world.WorldTime.init(config);
    const before = clock.snapshot();
    try expectError(error.WorldDayOverflow, clock.advanceSimulationTicks(std.math.maxInt(u64)));
    try expectEqualDeep(before, clock.snapshot());
}

test "copied snapshots restore carry and configuration without aliasing" {
    var original = try world.WorldTime.init(configuration());
    try original.advanceSimulationTicks(1);
    const saved = original.snapshot();
    var restored = try world.WorldTime.fromSnapshot(saved);
    try expectEqualDeep(saved, restored.snapshot());
    try original.advanceSimulationTicks(701);
    try restored.advanceSimulationTicks(701);
    try expectEqualDeep(original.snapshot(), restored.snapshot());
    try expectEqual(@as(u64, 1), saved.simulation_ticks);
    try expectEqual(@as(u64, 160), saved.submicrosecond_remainder);
    try restored.advanceSimulationTicks(7);
    try expect(original.snapshot().simulation_ticks != restored.snapshot().simulation_ticks);
}

test "fractional final microsecond crosses a one-microsecond authored day exactly" {
    var clock = try world.WorldTime.init(.{
        .simulation_hz = 1_000_000,
        .rate = .{ .numerator = 1, .denominator = 3 },
        .day_duration_us = 1,
    });
    try clock.advanceSimulationTicks(2);
    try expectEqual(@as(u64, 0), clock.snapshot().day_index);
    // Only the f64 convenience division rounds; the authoritative fraction is 2/3.
    try std.testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), try clock.snapshot().dayFraction(), 1e-15);
    try clock.advanceSimulationTicks(1);
    try expectEqual(@as(u64, 1), clock.snapshot().day_index);
    try expectEqual(@as(u64, 0), clock.snapshot().time_of_day_us);
    try expectEqual(@as(u64, 0), clock.snapshot().submicrosecond_remainder);
}

test "independently configured clocks and repeated snapshot reads never interfere" {
    var first = try world.WorldTime.init(configuration());
    var other_config = configuration();
    other_config.simulation_hz = 7;
    other_config.rate = .{ .numerator = 5, .denominator = 3 };
    other_config.day_duration_us = 123_457;
    var second = try world.WorldTime.init(other_config);
    const second_initial = second.snapshot();
    try first.advanceSimulationTicks(1);
    try expectEqualDeep(second_initial, second.snapshot());
    const first_saved = first.snapshot();
    try second.advanceSimulationTicks(11);
    for (0..100) |_| try expectEqualDeep(first_saved, first.snapshot());
    try expectEqual(@as(u128, 2_619_047), try second.snapshot().totalWholeMicroseconds());
    try expectEqual(@as(u64, 13), second.snapshot().submicrosecond_remainder);
    const second_saved = second.snapshot();
    try first.advanceSimulationTicks(239);
    try expectEqualDeep(second_saved, second.snapshot());
}

test "rate controls world duration while cycle size only changes its projection" {
    const config = time.Configuration{
        .simulation_hz = 8,
        .rate = .{ .numerator = 3, .denominator = 2 },
        .day_duration_us = 1_000_000,
    };
    var longer_cycle = config;
    longer_cycle.day_duration_us = 2_000_000;
    var faster_rate = config;
    faster_rate.rate.numerator = 6;
    var first = try world.WorldTime.init(config);
    var second = try world.WorldTime.init(longer_cycle);
    var third = try world.WorldTime.init(faster_rate);
    try first.advanceSimulationTicks(20);
    try second.advanceSimulationTicks(20);
    try third.advanceSimulationTicks(20);
    try expectEqual(@as(u128, 3_750_000), try first.snapshot().totalWholeMicroseconds());
    try expectEqual(try first.snapshot().totalWholeMicroseconds(), try second.snapshot().totalWholeMicroseconds());
    try expectEqual(first.snapshot().submicrosecond_remainder, second.snapshot().submicrosecond_remainder);
    try expectEqual(@as(u64, 3), first.snapshot().day_index);
    try expectEqual(@as(u64, 1), second.snapshot().day_index);
    try expectEqual(@as(u64, 1_750_000), second.snapshot().time_of_day_us);
    try expectEqual(@as(u128, 7_500_000), try third.snapshot().totalWholeMicroseconds());
    try expectEqual(@as(u64, 7), third.snapshot().day_index);
}

test "headless progression to copied day and time snapshot is a complete vertical slice" {
    var clock = try world.WorldTime.init(.{
        .simulation_hz = 8,
        .rate = .{ .numerator = 3, .denominator = 2 },
        .day_duration_us = 1_000_000,
    });
    // Twenty caller-supplied ticks span 2.5 simulation seconds and 3.75 world seconds.
    try clock.advanceSimulationTicks(20);
    const observation = clock.snapshot();
    try expectEqual(@as(u64, 20), observation.simulation_ticks);
    try expectEqual(@as(u64, 3), observation.day_index);
    try expectEqual(@as(u64, 750_000), observation.time_of_day_us);
    try expectEqual(@as(u64, 0), observation.submicrosecond_remainder);
    // f64 is presentation only; 1e-15 bounds rounding in the normalized view.
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), try observation.dayFraction(), 1e-15);
    try clock.advanceSimulationTicks(4);
    try expectEqual(@as(u64, 3), observation.day_index);
    try expectEqual(@as(u64, 4), clock.snapshot().day_index);
    try expectEqual(@as(u64, 500_000), clock.snapshot().time_of_day_us);
}
