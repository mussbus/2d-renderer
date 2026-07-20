const std = @import("std");

pub const simulation_hz: u32 = 240;
pub const fixed_dt_seconds: f64 = 1.0 / @as(f64, @floatFromInt(simulation_hz));
pub const default_maximum_frame_delta: f64 = 0.10;
pub const default_maximum_substeps: u8 = 8;

pub const Configuration = struct {
    fixed_dt: f64 = fixed_dt_seconds,
    maximum_frame_delta: f64 = default_maximum_frame_delta,
    maximum_substeps: u8 = default_maximum_substeps,

    pub fn validate(configuration: Configuration) !void {
        if (!std.math.isFinite(configuration.fixed_dt) or configuration.fixed_dt <= 0) return error.InvalidFixedTimestep;
        if (!std.math.isFinite(configuration.maximum_frame_delta) or configuration.maximum_frame_delta <= 0) return error.InvalidMaximumFrameDelta;
        if (configuration.maximum_substeps == 0) return error.InvalidMaximumSubsteps;
    }
};

pub const FrameMetrics = struct {
    raw_frame_delta: f64 = 0,
    clamped_frame_delta: f64 = 0,
    accumulator: f64 = 0,
    substeps: u8 = 0,
    maximum_substeps: u8 = 0,
    discarded_time: f64 = 0,
    lifetime_discarded_time: f64 = 0,
    interpolation_alpha: f64 = 0,
};

pub const Clock = struct {
    configuration: Configuration,
    accumulator: f64 = 0,
    lifetime_discarded_time: f64 = 0,
    paused: bool = false,
    single_step_pending: bool = false,
    last_frame: FrameMetrics = .{},

    pub fn init(configuration: Configuration) !Clock {
        try configuration.validate();
        return .{ .configuration = configuration };
    }

    pub fn setPaused(clock: *Clock, paused: bool) void {
        clock.paused = paused;
        if (!paused) clock.single_step_pending = false;
    }

    pub fn requestSingleStep(clock: *Clock) void {
        if (clock.paused) clock.single_step_pending = true;
    }

    pub fn beginFrame(clock: *Clock, raw_frame_delta: f64) !FrameMetrics {
        if (!std.math.isFinite(raw_frame_delta)) return error.NonFiniteFrameDelta;
        const non_negative = @max(@as(f64, 0), raw_frame_delta);
        const clamped = @min(non_negative, clock.configuration.maximum_frame_delta);

        if (clock.paused) {
            const substeps: u8 = if (clock.single_step_pending) 1 else 0;
            clock.single_step_pending = false;
            clock.last_frame = .{
                .raw_frame_delta = raw_frame_delta,
                .clamped_frame_delta = 0,
                .accumulator = clock.accumulator,
                .substeps = substeps,
                .maximum_substeps = clock.configuration.maximum_substeps,
                .discarded_time = 0,
                .lifetime_discarded_time = clock.lifetime_discarded_time,
                .interpolation_alpha = interpolationAlpha(clock.accumulator, clock.configuration.fixed_dt),
            };
            return clock.last_frame;
        }

        clock.accumulator += clamped;
        const available_value = @floor(clock.accumulator / clock.configuration.fixed_dt + 1e-12);
        const available: u64 = @intFromFloat(available_value);
        const executed_u64 = @min(available, clock.configuration.maximum_substeps);
        const executed: u8 = @intCast(executed_u64);
        clock.accumulator -= @as(f64, @floatFromInt(executed_u64)) * clock.configuration.fixed_dt;

        var discarded: f64 = 0;
        if (available > clock.configuration.maximum_substeps) {
            const excess = available - clock.configuration.maximum_substeps;
            discarded = @as(f64, @floatFromInt(excess)) * clock.configuration.fixed_dt;
            clock.accumulator -= discarded;
            clock.lifetime_discarded_time += discarded;
        }
        if (clock.accumulator < 0 and clock.accumulator > -1e-12) clock.accumulator = 0;
        if (clock.accumulator >= clock.configuration.fixed_dt) clock.accumulator = @mod(clock.accumulator, clock.configuration.fixed_dt);

        clock.last_frame = .{
            .raw_frame_delta = raw_frame_delta,
            .clamped_frame_delta = clamped,
            .accumulator = clock.accumulator,
            .substeps = executed,
            .maximum_substeps = clock.configuration.maximum_substeps,
            .discarded_time = discarded,
            .lifetime_discarded_time = clock.lifetime_discarded_time,
            .interpolation_alpha = interpolationAlpha(clock.accumulator, clock.configuration.fixed_dt),
        };
        return clock.last_frame;
    }

    pub fn reset(clock: *Clock) void {
        const configuration = clock.configuration;
        clock.* = .{ .configuration = configuration };
    }
};

pub fn interpolateScalar(previous: f32, current: f32, alpha: f64) !f32 {
    if (!std.math.isFinite(previous) or !std.math.isFinite(current) or !std.math.isFinite(alpha)) return error.NonFiniteInterpolation;
    if (alpha < 0 or alpha >= 1) return error.InterpolationAlphaOutOfRange;
    const amount: f32 = @floatCast(alpha);
    return previous + (current - previous) * amount;
}

fn interpolationAlpha(accumulator: f64, fixed_dt: f64) f64 {
    return std.math.clamp(accumulator / fixed_dt, 0, 1.0 - std.math.floatEps(f64));
}
