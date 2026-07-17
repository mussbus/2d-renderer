const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;

pub const InterpolationError = error{InvalidNonFiniteInterpolation};
pub const tau: f32 = 2.0 * std.math.pi;

/// Maps finite angles to the half-open range [-pi, pi).
pub fn wrapAngle(radians: f32) InterpolationError!f32 {
    if (!std.math.isFinite(radians)) return error.InvalidNonFiniteInterpolation;
    const turns = @floor((radians + std.math.pi) / tau);
    return radians - turns * tau;
}

pub fn signedShortestAngleDifference(from: f32, to: f32) InterpolationError!f32 {
    if (!std.math.isFinite(from) or !std.math.isFinite(to)) return error.InvalidNonFiniteInterpolation;
    return wrapAngle(to - from);
}

pub fn lerpScalar(from: f32, to: f32, amount: f32) InterpolationError!f32 {
    if (!std.math.isFinite(from) or !std.math.isFinite(to) or !std.math.isFinite(amount)) return error.InvalidNonFiniteInterpolation;
    return from + (to - from) * amount;
}

pub fn lerpVec2(from: Vec2, to: Vec2, amount: f32) InterpolationError!Vec2 {
    if (!from.isFinite() or !to.isFinite() or !std.math.isFinite(amount)) return error.InvalidNonFiniteInterpolation;
    return .{
        .x = from.x + (to.x - from.x) * amount,
        .y = from.y + (to.y - from.y) * amount,
    };
}

pub fn lerpAngleShortest(from: f32, to: f32, amount: f32) InterpolationError!f32 {
    if (!std.math.isFinite(amount)) return error.InvalidNonFiniteInterpolation;
    return wrapAngle(from + try signedShortestAngleDifference(from, to) * amount);
}
