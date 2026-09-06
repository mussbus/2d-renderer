const std = @import("std");

pub const microseconds_per_second: u64 = 1_000_000;

pub const Error = error{
    InvalidSimulationFrequency,
    InvalidRateDenominator,
    InvalidDayDuration,
    InvalidTimeWithinDay,
    InvalidSubMicrosecondRemainder,
    SimulationTickOverflow,
    WorldDayOverflow,
};

/// Rational world seconds per accepted simulation second.
/// A zero numerator contributes no world duration; supplied ticks still count.
/// Configuration is fixed for each clock; runtime rate transitions are undefined.
pub const Rate = struct {
    numerator: u32,
    denominator: u32,
};

pub const Configuration = struct {
    /// Caller supplies its fixed simulation frequency; no scheduler is owned here.
    simulation_hz: u32,
    /// Maps accepted simulation duration into authoritative world duration.
    rate: Rate,
    /// World microseconds per logical day cycle. Projects accumulated world
    /// duration into day index and time within day; no calendar meaning or default.
    day_duration_us: u64,

    pub fn validate(self: Configuration) Error!void {
        if (self.simulation_hz == 0) return error.InvalidSimulationFrequency;
        if (self.rate.denominator == 0) return error.InvalidRateDenominator;
        if (self.day_duration_us == 0) return error.InvalidDayDuration;
    }

    fn divisor(self: Configuration) u64 {
        // Both factors are u32, so the product always fits u64.
        return @as(u64, self.simulation_hz) * self.rate.denominator;
    }
};

/// An independent value copy, with all state needed to resume exact accumulation.
/// Raw construction is supported for loading only after validate/fromSnapshot.
/// No binary layout, serialized schema, calendar, or OS epoch is implied.
pub const Snapshot = struct {
    configuration: Configuration,
    /// Number of accepted simulation ticks, including ticks at a zero numeric rate.
    simulation_ticks: u64 = 0,
    /// Nonnegative whole logical cycles from the caller's world epoch.
    day_index: u64 = 0,
    /// Whole world microseconds within the day: [0, day_duration_us).
    time_of_day_us: u64 = 0,
    /// Fraction of one world microsecond: remainder / (simulation_hz * rate.denominator).
    submicrosecond_remainder: u64 = 0,

    pub fn validate(self: Snapshot) Error!void {
        try self.configuration.validate();
        if (self.time_of_day_us >= self.configuration.day_duration_us) return error.InvalidTimeWithinDay;
        if (self.submicrosecond_remainder >= self.configuration.divisor()) return error.InvalidSubMicrosecondRemainder;
    }

    /// Whole accumulated world microseconds. The submicrosecond carry is separate.
    /// This scalar view is insufficient for exact continuation; retain Snapshot.
    pub fn totalWholeMicroseconds(self: Snapshot) Error!u128 {
        try self.validate();
        // u64 days * u64 day length + an intra-day value is strictly below 2^128.
        return @as(u128, self.day_index) * self.configuration.day_duration_us + self.time_of_day_us;
    }

    /// Approximate presentation view in [0, 1); never authoritative accumulation.
    /// Clamp rounding near the endpoint so a valid final instant never reads as 1.
    pub fn dayFraction(self: Snapshot) Error!f64 {
        try self.validate();
        const fraction_us = @as(f64, @floatFromInt(self.submicrosecond_remainder)) /
            @as(f64, @floatFromInt(self.configuration.divisor()));
        const phase = (@as(f64, @floatFromInt(self.time_of_day_us)) + fraction_us) /
            @as(f64, @floatFromInt(self.configuration.day_duration_us));
        return @min(phase, 1.0 - std.math.floatEps(f64));
    }
};

pub const WorldTime = struct {
    // Modify through the methods below; direct field mutation is not a supported
    // clock API. Every advance revalidates state, including restored configurations.
    state: Snapshot,

    pub fn init(configuration: Configuration) Error!WorldTime {
        return fromSnapshot(.{ .configuration = configuration });
    }

    pub fn fromSnapshot(value: Snapshot) Error!WorldTime {
        try value.validate();
        return .{ .state = value };
    }

    pub fn snapshot(self: *const WorldTime) Snapshot {
        return self.state;
    }

    /// Consume executed fixed simulation ticks, never render frames or wall time.
    /// Equal successful tick totals from the same initial state/configuration
    /// are partition-independent. Withhold calls or supply zero ticks for no
    /// progression; this module owns no pause policy.
    /// Any error leaves the entire clock unchanged. A zero-rate clock still
    /// counts simulation ticks and can exhaust that counter.
    pub fn advanceSimulationTicks(self: *WorldTime, ticks: u64) Error!void {
        try self.state.validate();
        var next = self.state;
        next.simulation_ticks = std.math.add(u64, next.simulation_ticks, ticks) catch
            return error.SimulationTickOverflow;
        if (next.configuration.rate.numerator != 0) {
            const divisor = next.configuration.divisor();
            // u64 ticks * u32 rate * 10^6 plus u64 carry fits u128.
            const scaled = @as(u128, ticks) * next.configuration.rate.numerator *
                microseconds_per_second + next.submicrosecond_remainder;
            const within_day = @as(u128, next.time_of_day_us) + scaled / divisor;
            const days = within_day / next.configuration.day_duration_us;
            if (days > std.math.maxInt(u64) - next.day_index) return error.WorldDayOverflow;
            next.day_index += @intCast(days);
            next.time_of_day_us = @intCast(within_day % next.configuration.day_duration_us);
            next.submicrosecond_remainder = @intCast(scaled % divisor);
        }
        self.state = next;
    }
};
