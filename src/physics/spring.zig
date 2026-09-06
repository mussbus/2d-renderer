const std = @import("std");

pub const Error = error{
    InvalidSpringTimestep,
    InvalidSpringStiffness,
    InvalidSpringDamping,
    InvalidSpringDisplacementLimit,
    InvalidSpringVelocityLimit,
    NonFiniteSpringState,
    SpringStateOutsideLimits,
};

pub const Configuration = struct {
    stiffness: f32,
    damping: f32,
    maximum_displacement: f32,
    maximum_velocity: f32,

    pub fn validate(configuration: Configuration, fixed_dt: f32) Error!void {
        if (!std.math.isFinite(fixed_dt) or fixed_dt <= 0) return error.InvalidSpringTimestep;
        try validateParameters(configuration);
    }
};

fn validateParameters(configuration: Configuration) Error!void {
    if (!std.math.isFinite(configuration.stiffness) or configuration.stiffness < 0) return error.InvalidSpringStiffness;
    if (!std.math.isFinite(configuration.damping) or configuration.damping < 0) return error.InvalidSpringDamping;
    if (!std.math.isFinite(configuration.maximum_displacement) or configuration.maximum_displacement < 0) {
        return error.InvalidSpringDisplacementLimit;
    }
    if (!std.math.isFinite(configuration.maximum_velocity) or configuration.maximum_velocity < 0) {
        return error.InvalidSpringVelocityLimit;
    }
}

pub const State = struct {
    offset: f32 = 0,
    velocity: f32 = 0,
    target_offset: f32 = 0,

    pub fn init(
        configuration: Configuration,
        fixed_dt: f32,
        offset: f32,
        velocity: f32,
        target_offset: f32,
    ) Error!State {
        try configuration.validate(fixed_dt);
        const values = [_]f32{ offset, velocity, target_offset };
        for (values) |value| if (!std.math.isFinite(value)) return error.NonFiniteSpringState;
        if (@abs(offset) > configuration.maximum_displacement or
            @abs(target_offset) > configuration.maximum_displacement or
            @abs(velocity) > configuration.maximum_velocity)
        {
            return error.SpringStateOutsideLimits;
        }
        return .{ .offset = offset, .velocity = velocity, .target_offset = target_offset };
    }

    pub fn reset(state: *State) void {
        state.* = .{};
    }

    pub fn setTarget(state: *State, target_offset: f32, configuration: Configuration) Error!void {
        try validateParameters(configuration);
        if (!std.math.isFinite(target_offset)) return error.NonFiniteSpringState;
        state.target_offset = std.math.clamp(
            target_offset,
            -configuration.maximum_displacement,
            configuration.maximum_displacement,
        );
    }

    pub fn applyVelocityImpulse(state: *State, impulse: f32, configuration: Configuration) Error!void {
        try validateParameters(configuration);
        if (!std.math.isFinite(impulse) or !std.math.isFinite(state.velocity)) return error.NonFiniteSpringState;
        const candidate = state.velocity + impulse;
        if (!std.math.isFinite(candidate)) return error.NonFiniteSpringState;
        state.velocity = std.math.clamp(candidate, -configuration.maximum_velocity, configuration.maximum_velocity);
    }

    /// Semi-implicit Euler for unit mass:
    /// a = -stiffness * (offset - target) - damping * velocity,
    /// then velocity += a * dt and offset += velocity * dt.
    pub fn step(state: *State, configuration: Configuration, fixed_dt: f32) Error!void {
        try state.stepWithAcceleration(configuration, fixed_dt, 0);
    }

    /// The same unit-mass integrator with explicit acceleration in channel
    /// units/s^2. A zero input retains the legacy arithmetic sequence.
    pub fn stepWithAcceleration(
        state: *State,
        configuration: Configuration,
        fixed_dt: f32,
        external_acceleration: f32,
    ) Error!void {
        try configuration.validate(fixed_dt);
        if (!std.math.isFinite(external_acceleration)) return error.NonFiniteSpringState;
        const values = [_]f32{ state.offset, state.velocity, state.target_offset };
        for (values) |value| if (!std.math.isFinite(value)) return error.NonFiniteSpringState;

        var acceleration = -configuration.stiffness * (state.offset - state.target_offset) -
            configuration.damping * state.velocity;
        if (external_acceleration != 0) acceleration += external_acceleration;
        if (!std.math.isFinite(acceleration)) return error.NonFiniteSpringState;
        const velocity = state.velocity + acceleration * fixed_dt;
        if (!std.math.isFinite(velocity)) return error.NonFiniteSpringState;
        state.velocity = std.math.clamp(velocity, -configuration.maximum_velocity, configuration.maximum_velocity);

        const offset = state.offset + state.velocity * fixed_dt;
        if (!std.math.isFinite(offset)) return error.NonFiniteSpringState;
        state.offset = std.math.clamp(offset, -configuration.maximum_displacement, configuration.maximum_displacement);
        if (state.offset != offset) {
            const moving_outward = (state.offset < 0 and state.velocity < 0) or
                (state.offset > 0 and state.velocity > 0);
            if (moving_outward) state.velocity = 0;
        }
    }
};
