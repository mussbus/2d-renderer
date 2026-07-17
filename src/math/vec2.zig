const std = @import("std");

pub const Vec2Error = error{
    InvalidNonFiniteVector,
    InvalidNormalizationEpsilon,
};

pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub const zero = Vec2{ .x = 0, .y = 0 };
    pub const one = Vec2{ .x = 1, .y = 1 };

    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn add(left: Vec2, right: Vec2) Vec2 {
        return .{ .x = left.x + right.x, .y = left.y + right.y };
    }

    pub fn sub(left: Vec2, right: Vec2) Vec2 {
        return .{ .x = left.x - right.x, .y = left.y - right.y };
    }

    pub fn scale(value: Vec2, scalar: f32) Vec2 {
        return .{ .x = value.x * scalar, .y = value.y * scalar };
    }

    pub fn componentMul(left: Vec2, right: Vec2) Vec2 {
        return .{ .x = left.x * right.x, .y = left.y * right.y };
    }

    pub fn dot(left: Vec2, right: Vec2) f32 {
        return left.x * right.x + left.y * right.y;
    }

    pub fn lengthSquared(value: Vec2) f32 {
        return dot(value, value);
    }

    pub fn length(value: Vec2) f32 {
        return @sqrt(lengthSquared(value));
    }

    /// Returns zero for finite vectors shorter than epsilon. Non-finite input
    /// and a non-positive or non-finite epsilon are rejected explicitly.
    pub fn normalizeSafe(value: Vec2, epsilon: f32) Vec2Error!Vec2 {
        if (!value.isFinite()) return error.InvalidNonFiniteVector;
        if (!std.math.isFinite(epsilon) or epsilon <= 0) return error.InvalidNormalizationEpsilon;
        const squared = value.lengthSquared();
        if (squared < epsilon * epsilon) return zero;
        return value.scale(1.0 / @sqrt(squared));
    }

    pub fn isFinite(value: Vec2) bool {
        return std.math.isFinite(value.x) and std.math.isFinite(value.y);
    }

    pub fn approxEqAbs(left: Vec2, right: Vec2, tolerance: f32) bool {
        if (!left.isFinite() or !right.isFinite() or !std.math.isFinite(tolerance) or tolerance < 0) return false;
        return @abs(left.x - right.x) <= tolerance and @abs(left.y - right.y) <= tolerance;
    }

    pub fn toArray(value: Vec2) [2]f32 {
        return .{ value.x, value.y };
    }
};

comptime {
    if (@sizeOf(Vec2) != 8 or @alignOf(Vec2) != 4) @compileError("Vec2 must remain two contiguous f32 values");
}
