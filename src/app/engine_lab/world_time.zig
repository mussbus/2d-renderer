//! Engine Lab content policy and copied-value presentation; the accepted world
//! module alone owns exact accumulation. No clock or mutable display cache here.
const std = @import("std");
const fixed_step = @import("fixed_step");
pub const WorldTime = @import("world").WorldTime;
pub const Snapshot = @import("world").time.Snapshot;
pub const configuration = @import("world").time.Configuration{
    .simulation_hz = fixed_step.simulation_hz,
    .rate = .{ .numerator = 60, .denominator = 1 },
    .day_duration_us = 86_400_000_000,
};
pub const initial_snapshot = Snapshot{ .configuration = configuration, .time_of_day_us = 86_340_000_000 };
pub const label_capacity = 13; // D1000UP HH:MM; exact days 0..999 are shorter.
pub const diagnostic_capacity = 320;

pub fn init() !WorldTime {
    return WorldTime.fromSnapshot(initial_snapshot);
}

pub fn formatLabel(snapshot: Snapshot, buffer: *[label_capacity]u8) ![]const u8 {
    try snapshot.validate();
    if (snapshot.configuration.day_duration_us != configuration.day_duration_us) return error.UnexpectedLabDayDuration;
    const minutes = snapshot.time_of_day_us / 60_000_000;
    const hour = minutes / 60;
    const minute = minutes % 60;
    if (snapshot.day_index >= 1000) return std.fmt.bufPrint(buffer, "D1000UP {d:0>2}:{d:0>2}", .{ hour, minute });
    return std.fmt.bufPrint(buffer, "D{d} {d:0>2}:{d:0>2}", .{ snapshot.day_index, hour, minute });
}

/// Exact bounded diagnostics, not an authoritative serialization or restore API.
pub fn diagnostic(snapshot: Snapshot, buffer: *[diagnostic_capacity]u8) ![]const u8 {
    try snapshot.validate();
    const config = snapshot.configuration;
    return std.fmt.bufPrint(buffer, "WORLD_TIME_STATE_V1 simulation_hz={d} rate_numerator={d} rate_denominator={d} day_duration_us={d} simulation_ticks={d} day_index={d} time_of_day_us={d} submicrosecond_remainder={d}", .{ config.simulation_hz, config.rate.numerator, config.rate.denominator, config.day_duration_us, snapshot.simulation_ticks, snapshot.day_index, snapshot.time_of_day_us, snapshot.submicrosecond_remainder });
}
