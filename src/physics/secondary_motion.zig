const std = @import("std");
const fixed_step = @import("fixed_step");
const spring = @import("spring");

pub const fixed_dt: f32 = @floatCast(fixed_step.fixed_dt_seconds);

pub const Error = spring.Error || error{
    NonFiniteMotionProfile,
    InvalidMotionStiffness,
    InvalidMotionDamping,
    InvalidMotionGain,
    InvalidMotionLimit,
    InvalidMotionSettling,
    UnstableMotionProfile,
    NonFiniteMotionInput,
    UnsupportedMotionTimestep,
    InvalidMotionState,
    MotionNumericalOverflow,
    MotionTickOverflow,
};

/// Immutable authored unit-mass parameters; see the PSM01 contract for units.
/// Rate resolution may change coefficients/gains at tick boundaries without
/// resetting state. Keep units, limits and settling thresholds fixed.
pub const Profile = struct {
    stiffness: f32 = 144,
    damping: f32 = 12,
    inertial_gain: f32 = 1,
    external_gain: f32 = 1,
    maximum_displacement: f32 = 0.25,
    maximum_velocity: ?f32 = null,
    settle_displacement: f32 = 1e-5,
    settle_velocity: f32 = 1e-4,

    pub fn validate(profile: Profile) Error!void {
        @setFloatMode(.strict);
        const values = [_]f32{
            profile.stiffness,            profile.damping,
            profile.inertial_gain,        profile.external_gain,
            profile.maximum_displacement, profile.settle_displacement,
            profile.settle_velocity,
        };
        for (values) |value| if (!std.math.isFinite(value)) return error.NonFiniteMotionProfile;
        if (profile.stiffness < 1) return error.InvalidMotionStiffness;
        if (profile.damping < 0.01) return error.InvalidMotionDamping;
        // k*h*h + 2*c*h <= 3 < 4: a conservative semi-implicit Euler envelope.
        if (profile.stiffness * fixed_dt * fixed_dt > 1 or profile.damping * fixed_dt > 1) {
            return error.UnstableMotionProfile;
        }
        if (profile.inertial_gain < 0 or profile.inertial_gain > 100 or
            profile.external_gain < 0 or profile.external_gain > 100)
        {
            return error.InvalidMotionGain;
        }
        // Numeric budgets keep profile products far below f32 overflow.
        if (profile.maximum_displacement < 1e-6 or profile.maximum_displacement > 1e6) {
            return error.InvalidMotionLimit;
        }
        if (profile.maximum_velocity) |limit| {
            if (!std.math.isFinite(limit)) return error.NonFiniteMotionProfile;
            if (limit <= 0 or limit > 1e6) return error.InvalidMotionLimit;
            if (profile.settle_velocity >= limit) return error.InvalidMotionSettling;
        }
        if (profile.settle_displacement <= 0 or
            profile.settle_displacement >= profile.maximum_displacement or
            profile.settle_velocity <= 0 or profile.settle_velocity > 1e6)
        {
            return error.InvalidMotionSettling;
        }
    }

    fn springConfiguration(profile: Profile) spring.Configuration {
        return .{
            .stiffness = profile.stiffness,
            .damping = profile.damping,
            .maximum_displacement = profile.maximum_displacement,
            .maximum_velocity = profile.maximum_velocity orelse std.math.floatMax(f32),
        };
    }
};

pub const DriverSample = struct {
    /// Equilibrium/base position in U along a binding-owned positive axis in
    /// one consistent frame. Angular channels must be unwrapped.
    /// The core differentiates this history once; no moving spring target.
    position: f32,
    /// Teleport, seek, hard cut or coordinate-frame change: restart at rest.
    discontinuity: bool = false,
};

pub const TickInput = struct {
    driver: DriverSample,
    /// Independent U/s^2 along the same axis, e.g. projected gravity.
    /// Excludes acceleration already represented by driver position history.
    external_acceleration: f32 = 0,
    /// Explicit owner/offline tick duration. Only the established 240 Hz
    /// duration is supported; never multiply this by semantic playback rate.
    fixed_dt_seconds: f64 = fixed_step.fixed_dt_seconds,

    fn validate(input: TickInput) Error!void {
        if (!std.math.isFinite(input.fixed_dt_seconds) or
            input.fixed_dt_seconds != fixed_step.fixed_dt_seconds)
        {
            return error.UnsupportedMotionTimestep;
        }
        if (!std.math.isFinite(input.driver.position) or
            !std.math.isFinite(input.external_acceleration))
        {
            return error.NonFiniteMotionInput;
        }
    }
};

pub const Response = struct {
    /// U relative to the driver; never writes the driver or an attachment.
    offset: f32 = 0,
    /// U/s of relative response, not total world velocity.
    velocity: f32 = 0,
};

/// Caller-owned inline storage. Copying this value captures all replay state.
/// Public fields follow the existing low-level spring convention; stepping
/// validates them, and failed operations do not modify the value.
pub const State = struct {
    response: Response,
    driver_position: f32,
    driver_velocity: f32,
    fixed_ticks: u64,

    pub fn init(profile: Profile, driver_position: f32) Error!State {
        try profile.validate();
        if (!std.math.isFinite(driver_position)) return error.NonFiniteMotionInput;
        return .{
            .response = .{},
            .driver_position = driver_position,
            .driver_velocity = 0,
            .fixed_ticks = 0,
        };
    }

    pub fn reset(state: *State, profile: Profile, driver_position: f32) Error!void {
        state.* = try init(profile, driver_position);
    }

    /// Explicit delta velocity in U/s; callers convert mass-based impulses.
    pub fn applyVelocityDelta(state: *State, profile: Profile, delta_velocity: f32) Error!void {
        try profile.validate();
        try state.validate(profile);
        var oscillator = state.springState();
        try oscillator.applyVelocityImpulse(delta_velocity, profile.springConfiguration());
        state.response.velocity = oscillator.velocity;
    }

    /// Exactly one production fixed tick, independent of rendering and rate.
    /// A discontinuity consumes the tick but suppresses that tick's forcing.
    pub fn step(state: *State, profile: Profile, input: TickInput) Error!Response {
        @setFloatMode(.strict);
        try profile.validate();
        try input.validate();
        const next_tick = std.math.add(u64, state.fixed_ticks, 1) catch return error.MotionTickOverflow;
        if (input.driver.discontinuity) {
            var restarted = try init(profile, input.driver.position);
            restarted.fixed_ticks = next_tick;
            state.* = restarted;
            return restarted.response;
        }
        try state.validate(profile);
        // Widen subtraction before division, then reject unrepresentable
        // derivatives instead of saturating invalid input into motion.
        const velocity = try checkedScalar(
            (@as(f64, input.driver.position) - @as(f64, state.driver_position)) / @as(f64, fixed_dt),
        );
        const acceleration = try checkedScalar(
            (@as(f64, velocity) - @as(f64, state.driver_velocity)) / @as(f64, fixed_dt),
        );
        const forcing = try checkedScalar(
            @as(f64, input.external_acceleration) * profile.external_gain -
                @as(f64, acceleration) * profile.inertial_gain,
        );
        var oscillator = state.springState();
        // Two fixed integration stages improve first-order Euler accuracy.
        // Driver history and the owner tick still advance once at 240 Hz;
        // forcing is held over that tick, with no new clock or accumulator.
        try oscillator.stepWithAcceleration(profile.springConfiguration(), fixed_dt * 0.5, forcing);
        try oscillator.stepWithAcceleration(profile.springConfiguration(), fixed_dt * 0.5, forcing);
        // The legacy spring projects overshoot. At exact contact also remove
        // outward velocity so a boundary never stores a deferred outward kick.
        if (@abs(oscillator.offset) == profile.maximum_displacement and
            ((oscillator.offset > 0 and oscillator.velocity > 0) or
                (oscillator.offset < 0 and oscillator.velocity < 0)))
        {
            oscillator.velocity = 0;
        }
        // Both tests are required. A turning point alone must never sleep.
        // Nonzero forcing must remain observable even below these thresholds.
        if (forcing == 0 and @abs(oscillator.offset) < profile.settle_displacement and
            @abs(oscillator.velocity) < profile.settle_velocity)
        {
            oscillator.reset();
        }
        const candidate = State{
            .response = .{ .offset = oscillator.offset, .velocity = oscillator.velocity },
            .driver_position = input.driver.position,
            .driver_velocity = velocity,
            .fixed_ticks = next_tick,
        };
        try candidate.validate(profile);
        state.* = candidate;
        return candidate.response;
    }

    fn springState(state: State) spring.State {
        return .{ .offset = state.response.offset, .velocity = state.response.velocity };
    }

    fn validate(state: State, profile: Profile) Error!void {
        const values = [_]f32{
            state.response.offset, state.response.velocity,
            state.driver_position, state.driver_velocity,
        };
        for (values) |value| if (!std.math.isFinite(value)) return error.InvalidMotionState;
        if (@abs(state.response.offset) > profile.maximum_displacement or
            @abs(state.response.velocity) > (profile.maximum_velocity orelse std.math.floatMax(f32)))
        {
            return error.InvalidMotionState;
        }
    }
};

fn checkedScalar(value: f64) Error!f32 {
    if (!std.math.isFinite(value) or @abs(value) > std.math.floatMax(f32)) {
        return error.MotionNumericalOverflow;
    }
    return @floatCast(value);
}
