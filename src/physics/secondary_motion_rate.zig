const std = @import("std");
const motion = @import("secondary_motion");
const fixed_step = @import("fixed_step");

pub const Error = motion.Error || error{
    InvalidMotionRate,
    MotionRateOutOfRange,
    InvalidMotionRateKnots,
    MissingMotionRateReference,
    NonIdentityMotionRateReference,
    InvalidMotionRateMultiplier,
    NonFiniteInterpolation,
    InterpolationAlphaOutOfRange,
};

/// Dimensionless multipliers of the existing four coefficient authorities.
/// Frequency, damping ratio, lag and settling time remain derived behavior.
pub const Multipliers = struct {
    stiffness: f32 = 1,
    damping: f32 = 1,
    inertial_gain: f32 = 1,
    external_gain: f32 = 1,

    fn validate(values: Multipliers) Error!void {
        inline for (std.meta.fields(Multipliers)) |field| {
            const value = @field(values, field.name);
            if (!std.math.isFinite(value) or value < 0 or value > 100) {
                return error.InvalidMotionRateMultiplier;
            }
        }
        if (values.stiffness == 0 or values.damping == 0) return error.InvalidMotionRateMultiplier;
    }
};

pub const Knot = struct {
    /// Positive semantic animation rate, independent of simulation duration.
    rate: f32,
    multipliers: Multipliers = .{},
};

pub const maximum_knots = 8;
const identity_knots = [_]Knot{ .{ .rate = 0.25 }, .{ .rate = 1 }, .{ .rate = 4 } };

/// Borrowed immutable authored storage: keep knots alive and unmodified while
/// resolving. Endpoints define the supported range; extrapolation is rejected.
/// Three to eight strictly ordered knots must straddle an exact identity 1x.
/// Default policy is identity over [0.25, 4]; custom endpoints own their range.
pub const Policy = struct {
    knots: []const Knot = &identity_knots,

    /// Validates the whole curve against the base, including unqueried knots.
    /// Coefficients interpolate linearly, so endpoint envelopes also bound
    /// segment interiors. Every computed profile is additionally validated.
    pub fn validate(policy: Policy, base: motion.Profile) Error!void {
        @setFloatMode(.strict);
        try base.validate();
        if (policy.knots.len < 3 or policy.knots.len > maximum_knots) return error.InvalidMotionRateKnots;
        var previous_rate: f32 = 0;
        var found_reference = false;
        for (policy.knots) |knot| {
            if (!std.math.isFinite(knot.rate) or knot.rate <= 0) return error.InvalidMotionRate;
            if (knot.rate <= previous_rate) return error.InvalidMotionRateKnots;
            previous_rate = knot.rate;
            try knot.multipliers.validate();
            if (knot.rate == 1) {
                if (!std.meta.eql(knot.multipliers, Multipliers{})) return error.NonIdentityMotionRateReference;
                found_reference = true;
            }
            _ = try apply(base, knot.multipliers);
        }
        if (!found_reference) return error.MissingMotionRateReference;
        if (policy.knots[0].rate >= 1 or policy.knots[policy.knots.len - 1].rate <= 1) {
            return error.InvalidMotionRateKnots;
        }
    }

    /// Pure resolution: no State argument, allocation, clock or animation type.
    /// Reevaluation at a tick boundary preserves all existing instance state.
    pub fn resolve(policy: Policy, base: motion.Profile, rate: f32) Error!motion.Profile {
        @setFloatMode(.strict);
        try policy.validate(base);
        if (!std.math.isFinite(rate) or rate <= 0) return error.InvalidMotionRate;
        if (rate < policy.knots[0].rate or rate > policy.knots[policy.knots.len - 1].rate) {
            return error.MotionRateOutOfRange;
        }
        // Return base directly to preserve every reference scalar bit.
        if (rate == 1) return base;
        for (policy.knots, 0..) |right, index| {
            if (rate == right.rate) return apply(base, right.multipliers);
            if (rate < right.rate and index > 0) {
                const left = policy.knots[index - 1];
                const amount = (@as(f64, rate) - left.rate) / (@as(f64, right.rate) - left.rate);
                var values: Multipliers = .{};
                inline for (std.meta.fields(Multipliers)) |field| {
                    @field(values, field.name) = try fixed_step.interpolateScalar(
                        @field(left.multipliers, field.name),
                        @field(right.multipliers, field.name),
                        amount,
                    );
                }
                return apply(base, values);
            }
        }
        // Range/order checks above cover valid curves; fail closed if violated.
        return error.InvalidMotionRateKnots;
    }
};

fn apply(base: motion.Profile, values: Multipliers) Error!motion.Profile {
    @setFloatMode(.strict);
    var resolved = base;
    resolved.stiffness *= values.stiffness;
    resolved.damping *= values.damping;
    resolved.inertial_gain *= values.inertial_gain;
    resolved.external_gain *= values.external_gain;
    try resolved.validate();
    return resolved;
}
