const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;

/// Column-major affine matrix applied to column vectors as `result = M * v`.
pub const Mat3 = extern struct {
    values: [9]f32,

    pub fn identity() Mat3 {
        return .{ .values = .{
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
        } };
    }

    pub fn translation(offset: Vec2) Mat3 {
        return .{ .values = .{
            1,        0,        0,
            0,        1,        0,
            offset.x, offset.y, 1,
        } };
    }

    pub fn rotation(radians: f32) Mat3 {
        const cosine = @cos(radians);
        const sine = @sin(radians);
        return .{ .values = .{
            cosine, sine,   0,
            -sine,  cosine, 0,
            0,      0,      1,
        } };
    }

    pub fn nonuniformScale(amount: Vec2) Mat3 {
        return .{ .values = .{
            amount.x, 0,        0,
            0,        amount.y, 0,
            0,        0,        1,
        } };
    }

    /// Matrix product `left * right`; `right` is therefore applied first.
    pub fn mul(left: Mat3, right: Mat3) Mat3 {
        var result: Mat3 = undefined;
        for (0..3) |column| {
            for (0..3) |row| {
                var value: f32 = 0;
                for (0..3) |inner| value += left.at(row, inner) * right.at(inner, column);
                result.values[column * 3 + row] = value;
            }
        }
        return result;
    }

    pub fn transformPoint(matrix: Mat3, point: Vec2) Vec2 {
        return .{
            .x = matrix.values[0] * point.x + matrix.values[3] * point.y + matrix.values[6],
            .y = matrix.values[1] * point.x + matrix.values[4] * point.y + matrix.values[7],
        };
    }

    pub fn transformDirection(matrix: Mat3, direction: Vec2) Vec2 {
        return .{
            .x = matrix.values[0] * direction.x + matrix.values[3] * direction.y,
            .y = matrix.values[1] * direction.x + matrix.values[4] * direction.y,
        };
    }

    pub fn translationPart(matrix: Mat3) Vec2 {
        return .{ .x = matrix.values[6], .y = matrix.values[7] };
    }

    pub fn basisScale(matrix: Mat3) Vec2 {
        return .{
            .x = @sqrt(matrix.values[0] * matrix.values[0] + matrix.values[1] * matrix.values[1]),
            .y = @sqrt(matrix.values[3] * matrix.values[3] + matrix.values[4] * matrix.values[4]),
        };
    }

    pub fn rotationRadians(matrix: Mat3) f32 {
        return std.math.atan2(matrix.values[1], matrix.values[0]);
    }

    pub fn isFinite(matrix: Mat3) bool {
        for (matrix.values) |value| {
            if (!std.math.isFinite(value)) return false;
        }
        return true;
    }

    pub fn approxEqAbs(left: Mat3, right: Mat3, tolerance: f32) bool {
        if (!left.isFinite() or !right.isFinite() or !std.math.isFinite(tolerance) or tolerance < 0) return false;
        for (left.values, right.values) |left_value, right_value| {
            if (@abs(left_value - right_value) > tolerance) return false;
        }
        return true;
    }

    fn at(matrix: Mat3, row: usize, column: usize) f32 {
        return matrix.values[column * 3 + row];
    }
};

comptime {
    if (@sizeOf(Mat3) != 36 or @alignOf(Mat3) != 4) @compileError("Mat3 must remain nine contiguous column-major f32 values");
}
