const std = @import("std");
const math = @import("math");

pub const ColliderId = u16;
pub const invalid_collider_id: ColliderId = 0;

pub const Aabb = extern struct {
    minimum: math.Vec2,
    maximum: math.Vec2,

    pub fn validate(bounds: Aabb) !void {
        if (!bounds.minimum.isFinite() or !bounds.maximum.isFinite()) return error.NonFiniteColliderBounds;
        if (bounds.minimum.x >= bounds.maximum.x or bounds.minimum.y >= bounds.maximum.y) return error.InvertedColliderBounds;
    }

    pub fn center(bounds: Aabb) math.Vec2 {
        return .{
            .x = (bounds.minimum.x + bounds.maximum.x) * 0.5,
            .y = (bounds.minimum.y + bounds.maximum.y) * 0.5,
        };
    }

    pub fn size(bounds: Aabb) math.Vec2 {
        return bounds.maximum.sub(bounds.minimum);
    }
};

pub const StaticColliderInput = struct {
    id: ColliderId,
    bounds: Aabb,
    solid: bool = true,
    ground_query_eligible: bool = true,
};

pub const StaticCollider = extern struct {
    id: ColliderId,
    bounds: Aabb,
    solid: bool,
    ground_query_eligible: bool,
};

pub fn characterBounds(position: math.Vec2, half_extents: math.Vec2) !Aabb {
    if (!position.isFinite()) return error.NonFinitePosition;
    if (!half_extents.isFinite()) return error.NonFiniteColliderDimensions;
    if (half_extents.x <= 0 or half_extents.y <= 0) return error.InvalidColliderDimensions;
    return .{
        .minimum = position.sub(half_extents),
        .maximum = position.add(half_extents),
    };
}

pub fn overlapsStrict(left: Aabb, right: Aabb) bool {
    return left.maximum.x > right.minimum.x and left.minimum.x < right.maximum.x and
        left.maximum.y > right.minimum.y and left.minimum.y < right.maximum.y;
}

pub fn overlapsX(left: Aabb, right: Aabb, epsilon: f32) bool {
    return left.maximum.x > right.minimum.x + epsilon and left.minimum.x < right.maximum.x - epsilon;
}

pub fn overlapsY(left: Aabb, right: Aabb, epsilon: f32) bool {
    return left.maximum.y > right.minimum.y + epsilon and left.minimum.y < right.maximum.y - epsilon;
}

pub fn validateEpsilon(epsilon: f32) !void {
    if (!std.math.isFinite(epsilon) or epsilon < 0) return error.InvalidCollisionEpsilon;
}
