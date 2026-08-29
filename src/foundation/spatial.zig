const std = @import("std");

/// Shared engine/world coordinates are right-handed metres: +X right, +Y up,
/// and +Z forward. Vectors are treated as columns. Renderer, clip-space,
/// texture, and specialized physics conventions convert at their boundaries.
/// These tolerances are reviewed numerical contracts because changing them can
/// change whether inversion or affine-to-TRS decomposition succeeds.
pub const quaternion_unit_tolerance: f32 = 1.0e-5;
pub const basis_orthogonality_tolerance: f32 = 1.0e-5;
pub const affine_absolute_tolerance: f32 = 1.0e-5;
pub const affine_relative_tolerance: f32 = 1.0e-5;
pub const minimum_abs_scale_for_inverse: f32 = 1.0e-6;
pub const inverse_relative_determinant_tolerance: f32 = 1.0e-8;

pub const SpatialError = error{
    InvalidQuaternion,
    NonFiniteValue,
    NonRepresentableAffine,
    SingularTransform,
    ZeroScale,
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const zero = Vec3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    pub const one = Vec3{ .x = 1.0, .y = 1.0, .z = 1.0 };

    pub fn init(x: f32, y: f32, z: f32) SpatialError!Vec3 {
        const result = Vec3{ .x = normalizeZero(x), .y = normalizeZero(y), .z = normalizeZero(z) };
        try result.validate();
        return result;
    }

    pub fn validate(self: Vec3) SpatialError!void {
        if (!std.math.isFinite(self.x) or !std.math.isFinite(self.y) or !std.math.isFinite(self.z)) {
            return error.NonFiniteValue;
        }
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn subtract(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn multiply(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z };
    }

    pub fn scale(self: Vec3, scalar: f32) Vec3 {
        return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn lengthSquared(self: Vec3) f32 {
        return self.dot(self);
    }

    pub fn length(self: Vec3) f32 {
        return @sqrt(self.lengthSquared());
    }

    pub fn normalized(self: Vec3) SpatialError!Vec3 {
        try self.validate();
        const magnitude = self.length();
        if (!std.math.isFinite(magnitude) or magnitude < minimum_abs_scale_for_inverse) {
            return error.SingularTransform;
        }
        return self.scale(1.0 / magnitude);
    }
};

/// Unit quaternion stored as x, y, z, w. Equivalent q/-q inputs are normalized
/// into one deterministic hemisphere by canonicalizeNormalized.
pub const Quaternion = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const identity = Quaternion{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 };

    pub fn initCanonical(x: f32, y: f32, z: f32, w: f32) SpatialError!Quaternion {
        if (!std.math.isFinite(x) or !std.math.isFinite(y) or !std.math.isFinite(z) or !std.math.isFinite(w)) {
            return error.NonFiniteValue;
        }
        const length_squared = x * x + y * y + z * z + w * w;
        if (@abs(length_squared - 1.0) > quaternion_unit_tolerance) return error.InvalidQuaternion;
        const inverse_length = 1.0 / @sqrt(length_squared);
        return canonicalizeNormalized(.{
            .x = x * inverse_length,
            .y = y * inverse_length,
            .z = z * inverse_length,
            .w = w * inverse_length,
        });
    }

    pub fn fromAxisAngle(axis: Vec3, radians: f32) SpatialError!Quaternion {
        if (!std.math.isFinite(radians)) return error.NonFiniteValue;
        const normalized_axis = try axis.normalized();
        const half = radians * 0.5;
        const sine = @sin(half);
        return normalizedFromRaw(.{
            .x = normalized_axis.x * sine,
            .y = normalized_axis.y * sine,
            .z = normalized_axis.z * sine,
            .w = @cos(half),
        });
    }

    pub fn compose(parent: Quaternion, local: Quaternion) SpatialError!Quaternion {
        try parent.validate();
        try local.validate();
        return normalizedFromRaw(.{
            .x = parent.w * local.x + parent.x * local.w + parent.y * local.z - parent.z * local.y,
            .y = parent.w * local.y - parent.x * local.z + parent.y * local.w + parent.z * local.x,
            .z = parent.w * local.z + parent.x * local.y - parent.y * local.x + parent.z * local.w,
            .w = parent.w * local.w - parent.x * local.x - parent.y * local.y - parent.z * local.z,
        });
    }

    pub fn rotate(self: Quaternion, value: Vec3) Vec3 {
        const vector = Vec3{ .x = self.x, .y = self.y, .z = self.z };
        const twice_cross = vector.cross(value).scale(2.0);
        return value.add(twice_cross.scale(self.w)).add(vector.cross(twice_cross));
    }

    pub fn validate(self: Quaternion) SpatialError!void {
        _ = try initCanonical(self.x, self.y, self.z, self.w);
    }

    fn fromBasis(x_axis: Vec3, y_axis: Vec3, z_axis: Vec3) SpatialError!Quaternion {
        const m00 = x_axis.x;
        const m01 = y_axis.x;
        const m02 = z_axis.x;
        const m10 = x_axis.y;
        const m11 = y_axis.y;
        const m12 = z_axis.y;
        const m20 = x_axis.z;
        const m21 = y_axis.z;
        const m22 = z_axis.z;
        const trace = m00 + m11 + m22;
        var raw: Quaternion = undefined;
        if (trace > 0.0) {
            const scale = @sqrt(trace + 1.0) * 2.0;
            raw = .{
                .x = (m21 - m12) / scale,
                .y = (m02 - m20) / scale,
                .z = (m10 - m01) / scale,
                .w = 0.25 * scale,
            };
        } else if (m00 > m11 and m00 > m22) {
            const scale = @sqrt(1.0 + m00 - m11 - m22) * 2.0;
            raw = .{
                .x = 0.25 * scale,
                .y = (m01 + m10) / scale,
                .z = (m02 + m20) / scale,
                .w = (m21 - m12) / scale,
            };
        } else if (m11 > m22) {
            const scale = @sqrt(1.0 + m11 - m00 - m22) * 2.0;
            raw = .{
                .x = (m01 + m10) / scale,
                .y = 0.25 * scale,
                .z = (m12 + m21) / scale,
                .w = (m02 - m20) / scale,
            };
        } else {
            const scale = @sqrt(1.0 + m22 - m00 - m11) * 2.0;
            raw = .{
                .x = (m02 + m20) / scale,
                .y = (m12 + m21) / scale,
                .z = 0.25 * scale,
                .w = (m10 - m01) / scale,
            };
        }
        return normalizedFromRaw(raw);
    }
};

/// Authored parent-relative TRS. transformPoint applies scale, then rotation,
/// then translation: T * R * S * point under the column-vector convention.
pub const LocalTransform = struct {
    translation: Vec3,
    rotation: Quaternion,
    scale: Vec3,

    pub const identity = LocalTransform{
        .translation = Vec3.zero,
        .rotation = Quaternion.identity,
        .scale = Vec3.one,
    };

    pub fn init(translation: Vec3, rotation: Quaternion, scale: Vec3) SpatialError!LocalTransform {
        const result = LocalTransform{
            .translation = translation,
            .rotation = try Quaternion.initCanonical(rotation.x, rotation.y, rotation.z, rotation.w),
            .scale = scale,
        };
        try result.validate();
        return result;
    }

    pub fn validate(self: LocalTransform) SpatialError!void {
        try self.translation.validate();
        try self.rotation.validate();
        try self.scale.validate();
        if (self.scale.x == 0.0 or self.scale.y == 0.0 or self.scale.z == 0.0) return error.ZeroScale;
    }

    pub fn transformPoint(self: LocalTransform, point: Vec3) Vec3 {
        return self.rotation.rotate(point.multiply(self.scale)).add(self.translation);
    }
};

/// General resolved affine transform. x_axis, y_axis, and z_axis are the three
/// linear-matrix basis columns; translation is the fourth affine column.
/// Composition is parent * local, so the result applies local before parent.
pub const AffineTransform = struct {
    x_axis: Vec3,
    y_axis: Vec3,
    z_axis: Vec3,
    translation: Vec3,

    pub const identity = AffineTransform{
        .x_axis = .{ .x = 1.0, .y = 0.0, .z = 0.0 },
        .y_axis = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .z_axis = .{ .x = 0.0, .y = 0.0, .z = 1.0 },
        .translation = Vec3.zero,
    };

    pub fn fromLocal(local: LocalTransform) SpatialError!AffineTransform {
        try local.validate();
        const rotation = try Quaternion.initCanonical(
            local.rotation.x,
            local.rotation.y,
            local.rotation.z,
            local.rotation.w,
        );
        return .{
            .x_axis = rotation.rotate(.{ .x = local.scale.x, .y = 0.0, .z = 0.0 }),
            .y_axis = rotation.rotate(.{ .x = 0.0, .y = local.scale.y, .z = 0.0 }),
            .z_axis = rotation.rotate(.{ .x = 0.0, .y = 0.0, .z = local.scale.z }),
            .translation = local.translation,
        };
    }

    pub fn validate(self: AffineTransform) SpatialError!void {
        try self.x_axis.validate();
        try self.y_axis.validate();
        try self.z_axis.validate();
        try self.translation.validate();
    }

    pub fn transformVector(self: AffineTransform, value: Vec3) Vec3 {
        return self.x_axis.scale(value.x).add(self.y_axis.scale(value.y)).add(self.z_axis.scale(value.z));
    }

    pub fn transformPoint(self: AffineTransform, point: Vec3) Vec3 {
        return self.transformVector(point).add(self.translation);
    }

    pub fn compose(parent: AffineTransform, local: AffineTransform) SpatialError!AffineTransform {
        try parent.validate();
        try local.validate();
        return .{
            .x_axis = parent.transformVector(local.x_axis),
            .y_axis = parent.transformVector(local.y_axis),
            .z_axis = parent.transformVector(local.z_axis),
            .translation = parent.transformPoint(local.translation),
        };
    }

    pub fn inverse(self: AffineTransform) SpatialError!AffineTransform {
        try self.validate();
        const a = self.x_axis.x;
        const b = self.y_axis.x;
        const c = self.z_axis.x;
        const d = self.x_axis.y;
        const e = self.y_axis.y;
        const f = self.z_axis.y;
        const g = self.x_axis.z;
        const h = self.y_axis.z;
        const i = self.z_axis.z;
        const determinant = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
        const x_length = self.x_axis.length();
        const y_length = self.y_axis.length();
        const z_length = self.z_axis.length();
        if (x_length < minimum_abs_scale_for_inverse or
            y_length < minimum_abs_scale_for_inverse or
            z_length < minimum_abs_scale_for_inverse)
        {
            return error.SingularTransform;
        }
        const determinant_scale = x_length * y_length * z_length;
        if (!std.math.isFinite(determinant) or @abs(determinant) <= inverse_relative_determinant_tolerance * determinant_scale) {
            return error.SingularTransform;
        }
        const inverse_determinant = 1.0 / determinant;
        const inverse_linear = AffineTransform{
            .x_axis = .{
                .x = (e * i - f * h) * inverse_determinant,
                .y = (f * g - d * i) * inverse_determinant,
                .z = (d * h - e * g) * inverse_determinant,
            },
            .y_axis = .{
                .x = (c * h - b * i) * inverse_determinant,
                .y = (a * i - c * g) * inverse_determinant,
                .z = (b * g - a * h) * inverse_determinant,
            },
            .z_axis = .{
                .x = (b * f - c * e) * inverse_determinant,
                .y = (c * d - a * f) * inverse_determinant,
                .z = (a * e - b * d) * inverse_determinant,
            },
            .translation = undefined,
        };
        var result = inverse_linear;
        result.translation = inverse_linear.transformVector(self.translation).scale(-1.0);
        try result.validate();
        return result;
    }

    /// Converts only when this affine is representable as TRS within the
    /// published tolerances. Shear is never approximated away. A reflection is
    /// canonicalized onto negative X scale, so the result preserves the
    /// transform but need not reproduce the originally authored scale signs.
    pub fn toLocal(self: AffineTransform) SpatialError!LocalTransform {
        try self.validate();
        var scale = Vec3{
            .x = self.x_axis.length(),
            .y = self.y_axis.length(),
            .z = self.z_axis.length(),
        };
        if (scale.x < minimum_abs_scale_for_inverse or scale.y < minimum_abs_scale_for_inverse or scale.z < minimum_abs_scale_for_inverse) {
            return error.SingularTransform;
        }
        var x_basis = self.x_axis.scale(1.0 / scale.x);
        const y_basis = self.y_axis.scale(1.0 / scale.y);
        const z_basis = self.z_axis.scale(1.0 / scale.z);
        if (@abs(x_basis.dot(y_basis)) > basis_orthogonality_tolerance or
            @abs(x_basis.dot(z_basis)) > basis_orthogonality_tolerance or
            @abs(y_basis.dot(z_basis)) > basis_orthogonality_tolerance)
        {
            return error.NonRepresentableAffine;
        }
        const handedness = x_basis.dot(y_basis.cross(z_basis));
        if (@abs(handedness) < minimum_abs_scale_for_inverse) return error.SingularTransform;
        if (handedness < 0.0) {
            scale.x = -scale.x;
            x_basis = x_basis.scale(-1.0);
        }
        const result = LocalTransform{
            .translation = self.translation,
            .rotation = try Quaternion.fromBasis(x_basis, y_basis, z_basis),
            .scale = scale,
        };
        try result.validate();
        const recomposed = try AffineTransform.fromLocal(result);
        if (!approximatelyEqual(self, recomposed)) return error.NonRepresentableAffine;
        return result;
    }
};

pub fn approximatelyEqual(a: AffineTransform, b: AffineTransform) bool {
    return vectorApproximatelyEqual(a.x_axis, b.x_axis) and
        vectorApproximatelyEqual(a.y_axis, b.y_axis) and
        vectorApproximatelyEqual(a.z_axis, b.z_axis) and
        vectorApproximatelyEqual(a.translation, b.translation);
}

fn vectorApproximatelyEqual(a: Vec3, b: Vec3) bool {
    return scalarApproximatelyEqual(a.x, b.x) and
        scalarApproximatelyEqual(a.y, b.y) and
        scalarApproximatelyEqual(a.z, b.z);
}

fn scalarApproximatelyEqual(a: f32, b: f32) bool {
    const scale = @max(@abs(a), @abs(b));
    return @abs(a - b) <= affine_absolute_tolerance + affine_relative_tolerance * scale;
}

fn normalizedFromRaw(raw: Quaternion) SpatialError!Quaternion {
    if (!std.math.isFinite(raw.x) or !std.math.isFinite(raw.y) or !std.math.isFinite(raw.z) or !std.math.isFinite(raw.w)) {
        return error.NonFiniteValue;
    }
    const length_squared = raw.x * raw.x + raw.y * raw.y + raw.z * raw.z + raw.w * raw.w;
    if (!std.math.isFinite(length_squared) or length_squared <= 0.0) return error.InvalidQuaternion;
    const inverse_length = 1.0 / @sqrt(length_squared);
    return canonicalizeNormalized(.{
        .x = raw.x * inverse_length,
        .y = raw.y * inverse_length,
        .z = raw.z * inverse_length,
        .w = raw.w * inverse_length,
    });
}

fn canonicalizeNormalized(value: Quaternion) Quaternion {
    var result = value;
    // Prefer positive w. On the w == 0 boundary, prefer the sign for which the
    // first nonzero component in x, y, z is positive. Normalize signed zero so
    // q and -q have one stable canonical representation.
    const should_negate = result.w < 0.0 or
        (result.w == 0.0 and (result.x < 0.0 or
            (result.x == 0.0 and (result.y < 0.0 or
                (result.y == 0.0 and result.z < 0.0)))));
    if (should_negate) {
        result.x = -result.x;
        result.y = -result.y;
        result.z = -result.z;
        result.w = -result.w;
    }
    result.x = normalizeZero(result.x);
    result.y = normalizeZero(result.y);
    result.z = normalizeZero(result.z);
    result.w = normalizeZero(result.w);
    return result;
}

fn normalizeZero(value: f32) f32 {
    return if (value == 0.0) 0.0 else value;
}
