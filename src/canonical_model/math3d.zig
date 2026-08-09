const std = @import("std");

pub const quaternion_unit_tolerance: f32 = 1e-5;

pub const VectorError = error{NonFiniteVector};
pub const QuaternionError = error{
    NonFiniteQuaternion,
    QuaternionOutsideUnitTolerance,
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const zero = Vec3{ .x = 0, .y = 0, .z = 0 };
    pub const one = Vec3{ .x = 1, .y = 1, .z = 1 };

    pub fn init(x: f32, y: f32, z: f32) VectorError!Vec3 {
        if (!std.math.isFinite(x) or !std.math.isFinite(y) or !std.math.isFinite(z)) {
            return error.NonFiniteVector;
        }
        return .{
            .x = normalizeZero(x),
            .y = normalizeZero(y),
            .z = normalizeZero(z),
        };
    }
};

pub const Quaternion = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const identity = Quaternion{ .x = 0, .y = 0, .z = 0, .w = 1 };

    pub fn initCanonical(x: f32, y: f32, z: f32, w: f32) QuaternionError!Quaternion {
        if (!std.math.isFinite(x) or !std.math.isFinite(y) or
            !std.math.isFinite(z) or !std.math.isFinite(w))
        {
            return error.NonFiniteQuaternion;
        }

        const length_squared = x * x + y * y + z * z + w * w;
        if (@abs(length_squared - 1.0) > quaternion_unit_tolerance) {
            return error.QuaternionOutsideUnitTolerance;
        }

        const inverse_length: f32 = 1.0 / @sqrt(length_squared);
        var canonical = Quaternion{
            .x = x * inverse_length,
            .y = y * inverse_length,
            .z = z * inverse_length,
            .w = w * inverse_length,
        };

        if (canonical.requiresHemisphereNegation()) {
            canonical.x = -canonical.x;
            canonical.y = -canonical.y;
            canonical.z = -canonical.z;
            canonical.w = -canonical.w;
        }

        canonical.x = normalizeZero(canonical.x);
        canonical.y = normalizeZero(canonical.y);
        canonical.z = normalizeZero(canonical.z);
        canonical.w = normalizeZero(canonical.w);
        return canonical;
    }

    pub fn lengthSquared(self: Quaternion) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w;
    }

    pub fn rotateVector(self: Quaternion, vector: Vec3) Vec3 {
        const twice_cross = Vec3{
            .x = 2.0 * (self.y * vector.z - self.z * vector.y),
            .y = 2.0 * (self.z * vector.x - self.x * vector.z),
            .z = 2.0 * (self.x * vector.y - self.y * vector.x),
        };
        const quaternion_cross = Vec3{
            .x = self.y * twice_cross.z - self.z * twice_cross.y,
            .y = self.z * twice_cross.x - self.x * twice_cross.z,
            .z = self.x * twice_cross.y - self.y * twice_cross.x,
        };
        return .{
            .x = vector.x + self.w * twice_cross.x + quaternion_cross.x,
            .y = vector.y + self.w * twice_cross.y + quaternion_cross.y,
            .z = vector.z + self.w * twice_cross.z + quaternion_cross.z,
        };
    }

    pub fn compose(parent: Quaternion, local: Quaternion) QuaternionError!Quaternion {
        return initCanonical(
            parent.w * local.x + parent.x * local.w + parent.y * local.z - parent.z * local.y,
            parent.w * local.y - parent.x * local.z + parent.y * local.w + parent.z * local.x,
            parent.w * local.z + parent.x * local.y - parent.y * local.x + parent.z * local.w,
            parent.w * local.w - parent.x * local.x - parent.y * local.y - parent.z * local.z,
        );
    }

    fn requiresHemisphereNegation(self: Quaternion) bool {
        if (self.w > 0) return false;
        if (self.w < 0) return true;
        if (self.x != 0) return self.x < 0;
        if (self.y != 0) return self.y < 0;
        return self.z < 0;
    }
};

pub const LocalTransform = struct {
    translation_m: Vec3,
    rotation: Quaternion,
    scale: Vec3,

    pub const identity = LocalTransform{
        .translation_m = Vec3.zero,
        .rotation = Quaternion.identity,
        .scale = Vec3.one,
    };
};

pub const AffineTransform = struct {
    x_axis: Vec3,
    y_axis: Vec3,
    z_axis: Vec3,
    translation_m: Vec3,

    pub const identity = AffineTransform{
        .x_axis = .{ .x = 1, .y = 0, .z = 0 },
        .y_axis = .{ .x = 0, .y = 1, .z = 0 },
        .z_axis = .{ .x = 0, .y = 0, .z = 1 },
        .translation_m = Vec3.zero,
    };

    pub fn fromLocal(local: LocalTransform) AffineTransform {
        return .{
            .x_axis = local.rotation.rotateVector(.{ .x = local.scale.x, .y = 0, .z = 0 }),
            .y_axis = local.rotation.rotateVector(.{ .x = 0, .y = local.scale.y, .z = 0 }),
            .z_axis = local.rotation.rotateVector(.{ .x = 0, .y = 0, .z = local.scale.z }),
            .translation_m = local.translation_m,
        };
    }

    pub fn compose(parent: AffineTransform, local: AffineTransform) AffineTransform {
        return .{
            .x_axis = parent.transformVector(local.x_axis),
            .y_axis = parent.transformVector(local.y_axis),
            .z_axis = parent.transformVector(local.z_axis),
            .translation_m = parent.transformPoint(local.translation_m),
        };
    }

    pub fn transformPoint(self: AffineTransform, point: Vec3) Vec3 {
        const transformed = self.transformVector(point);
        return .{
            .x = self.translation_m.x + transformed.x,
            .y = self.translation_m.y + transformed.y,
            .z = self.translation_m.z + transformed.z,
        };
    }

    pub fn transformVector(self: AffineTransform, vector: Vec3) Vec3 {
        return .{
            .x = self.x_axis.x * vector.x + self.y_axis.x * vector.y + self.z_axis.x * vector.z,
            .y = self.x_axis.y * vector.x + self.y_axis.y * vector.y + self.z_axis.y * vector.z,
            .z = self.x_axis.z * vector.x + self.y_axis.z * vector.y + self.z_axis.z * vector.z,
        };
    }
};

pub fn normalizeZero(value: f32) f32 {
    return if (value == 0) 0 else value;
}
