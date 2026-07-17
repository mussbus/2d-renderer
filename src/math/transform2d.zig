const std = @import("std");
const vec2 = @import("vec2.zig");
const mat3 = @import("mat3.zig");
pub const interpolation = @import("interpolation.zig");

pub const Vec2 = vec2.Vec2;
pub const Vec2Error = vec2.Vec2Error;
pub const Mat3 = mat3.Mat3;

pub const TransformError = error{InvalidNonFiniteTransform};

pub const Transform2D = extern struct {
    translation: Vec2,
    rotation_radians: f32,
    scale: Vec2,

    pub fn identity() Transform2D {
        return .{ .translation = Vec2.zero, .rotation_radians = 0, .scale = Vec2.one };
    }

    pub fn init(translation_value: Vec2, rotation_radians: f32, scale_value: Vec2) Transform2D {
        return .{ .translation = translation_value, .rotation_radians = rotation_radians, .scale = scale_value };
    }

    /// Returns `translation * rotation * scale`, so scale is applied first.
    pub fn localToParent(transform: Transform2D) TransformError!Mat3 {
        try transform.validate();
        return Mat3.translation(transform.translation).mul(Mat3.rotation(transform.rotation_radians)).mul(Mat3.nonuniformScale(transform.scale));
    }

    pub fn validate(transform: Transform2D) TransformError!void {
        if (!transform.translation.isFinite() or !std.math.isFinite(transform.rotation_radians) or !transform.scale.isFinite()) {
            return error.InvalidNonFiniteTransform;
        }
    }

    pub fn isFinite(transform: Transform2D) bool {
        transform.validate() catch return false;
        return true;
    }

    pub fn approxEqAbs(left: Transform2D, right: Transform2D, tolerance: f32) bool {
        if (!left.isFinite() or !right.isFinite() or !std.math.isFinite(tolerance) or tolerance < 0) return false;
        const angle_difference = interpolation.signedShortestAngleDifference(left.rotation_radians, right.rotation_radians) catch return false;
        return left.translation.approxEqAbs(right.translation, tolerance) and
            left.scale.approxEqAbs(right.scale, tolerance) and
            @abs(angle_difference) <= tolerance;
    }

    pub fn interpolateComponents(from: Transform2D, to: Transform2D, amount: f32) (TransformError || interpolation.InterpolationError)!Transform2D {
        try from.validate();
        try to.validate();
        return .{
            .translation = try interpolation.lerpVec2(from.translation, to.translation, amount),
            .rotation_radians = try interpolation.lerpAngleShortest(from.rotation_radians, to.rotation_radians, amount),
            .scale = try interpolation.lerpVec2(from.scale, to.scale, amount),
        };
    }
};

/// Applies `childLocal` and then `parentToWorld`; the result maps child-local
/// points directly into world space.
pub fn composeParentChild(parentToWorld: Mat3, childLocal: Transform2D) TransformError!Mat3 {
    if (!parentToWorld.isFinite()) return error.InvalidNonFiniteTransform;
    return parentToWorld.mul(try childLocal.localToParent());
}

comptime {
    if (@sizeOf(Transform2D) != 20 or @alignOf(Transform2D) != 4) @compileError("Transform2D component layout changed unexpectedly");
}
