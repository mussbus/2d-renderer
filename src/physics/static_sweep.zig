//! Read-only complete-segment sweep against one static solid AABB, in metres/Y-up.
//! No controller response or application metadata belongs to this geometry query.
const std = @import("std");
const math = @import("math");
const collider = @import("collider");

pub const Sweep = struct { from: math.Vec2, to: math.Vec2, half_extents: math.Vec2 = .zero };
pub const Contact = struct { fraction: f32, normal: math.Vec2, position: math.Vec2 };
pub const Error = error{ InvalidSweep, InvalidBounds };

/// Fraction measures center travel, not distance to the contact surface. Position
/// lies on the original obstacle face: project the center onto that face and
/// clamp its other coordinate to the face span (also for initial penetration).
/// Strict initial overlap reports fraction zero and the closest expanded face;
/// ties choose min-X, max-X, min-Y, max-Y. This includes stationary overlap.
/// Otherwise touching at entry or at the segment endpoint counts only when
/// entering. Initial tangent/separating motion, stationary boundary contact,
/// travel along a face and isolated corner grazing do not hit. Exact entry
/// corner ties choose X. Every reported normal is an exact axial unit vector.
/// Slab decisions use exact bounded dyadic arithmetic for every finite f32
/// input. Floating-point conversion occurs only after the contact is decided.
pub fn query(sweep: Sweep, bounds: collider.Aabb) Error!?Contact {
    if (!sweep.from.isFinite() or !sweep.to.isFinite() or !sweep.half_extents.isFinite() or
        sweep.half_extents.x < 0 or sweep.half_extents.y < 0) return error.InvalidSweep;
    bounds.validate() catch return error.InvalidBounds;
    const from = [2]i288{ exact(sweep.from.x), exact(sweep.from.y) };
    const delta = [2]i288{ exact(sweep.to.x) - from[0], exact(sweep.to.y) - from[1] };
    const lo = [2]i288{ exact(bounds.minimum.x) - exact(sweep.half_extents.x), exact(bounds.minimum.y) - exact(sweep.half_extents.y) };
    const hi = [2]i288{ exact(bounds.maximum.x) + exact(sweep.half_extents.x), exact(bounds.maximum.y) + exact(sweep.half_extents.y) };
    const normals = [_]math.Vec2{ .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 } };
    if (from[0] > lo[0] and from[0] < hi[0] and from[1] > lo[1] and from[1] < hi[1]) {
        const distances = [_]i288{ from[0] - lo[0], hi[0] - from[0], from[1] - lo[1], hi[1] - from[1] };
        var face: usize = 0;
        for (1..4) |index| if (distances[index] < distances[face]) {
            face = index;
        };
        return contact(from, delta, bounds, .{ .numerator = 0, .denominator = 1 }, normals[face]);
    }
    var enter: ?Ratio = null;
    var leave: ?Ratio = null;
    var normal = math.Vec2.zero;
    for (0..2) |axis| {
        if (delta[axis] == 0) {
            if (from[axis] <= lo[axis] or from[axis] >= hi[axis]) return null;
            continue;
        }
        const forward = delta[axis] > 0;
        const denominator = if (forward) delta[axis] else -delta[axis];
        const near = Ratio{ .numerator = if (forward) lo[axis] - from[axis] else from[axis] - hi[axis], .denominator = denominator };
        const far = Ratio{ .numerator = if (forward) hi[axis] - from[axis] else from[axis] - lo[axis], .denominator = denominator };
        // Strict replacement preserves X for a genuine entry corner tie.
        if (enter == null or near.order(enter.?) == .gt) {
            enter = near;
            normal = normals[axis * 2 + @as(usize, if (forward) 0 else 1)];
        }
        if (leave == null or far.order(leave.?) == .lt) leave = far;
    }
    const entry = enter orelse return null;
    const exit = leave orelse return null;
    // All validated slabs have positive width. A true equal entry/exit is
    // therefore isolated corner grazing, never a rounded finite-width hit.
    if (entry.numerator < 0 or entry.numerator > entry.denominator or entry.order(exit) != .lt) return null;
    return contact(from, delta, bounds, entry, normal);
}

// Every finite binary32 value is an integer multiple of 2^-149, with scaled
// magnitude <2^277. Expanded bounds use two such terms; slab numerators use
// three (<3*2^277), and deltas use two (<2^278). Signed i288 contains all of
// them. Cross products and contact-coordinate sums have magnitude <2^558,
// safely inside signed i576. These fixed compiler integers allocate nothing;
// there are only two axes, with no precision-dependent iteration or fallback.
fn exact(value: f32) i288 {
    const bits: u32 = @bitCast(value);
    const exponent = (bits >> 23) & 0xff;
    const mantissa: i288 = (bits & 0x7fffff) | @as(u32, if (exponent == 0) 0 else 0x800000);
    const magnitude = mantissa << @as(u9, @intCast(if (exponent == 0) 0 else exponent - 1));
    return if (bits >> 31 == 0) magnitude else -magnitude;
}

const Ratio = struct {
    numerator: i288,
    denominator: i288, // Strictly positive; created from nonzero motion or one.

    fn order(a: Ratio, b: Ratio) std.math.Order {
        return std.math.order(@as(i576, a.numerator) * b.denominator, @as(i576, b.numerator) * a.denominator);
    }
};

fn coordinate(from: i288, delta: i288, fraction: Ratio) f64 {
    // Form the exact numerator before conversion to avoid cancellation of
    // opposite extreme endpoints when reconstructing a small face coordinate.
    const numerator = @as(i576, from) * fraction.denominator + @as(i576, delta) * fraction.numerator;
    return (@as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(fraction.denominator))) * 0x1p-149;
}

fn contact(from: [2]i288, delta: [2]i288, bounds: collider.Aabb, fraction: Ratio, normal: math.Vec2) Contact {
    const x = coordinate(from[0], delta[0], fraction);
    const y = coordinate(from[1], delta[1], fraction);
    return .{ .fraction = @floatCast(@as(f64, @floatFromInt(fraction.numerator)) / @as(f64, @floatFromInt(fraction.denominator))), .normal = normal, .position = .{
        .x = if (normal.x < 0) bounds.minimum.x else if (normal.x > 0) bounds.maximum.x else @floatCast(std.math.clamp(x, bounds.minimum.x, bounds.maximum.x)),
        .y = if (normal.y < 0) bounds.minimum.y else if (normal.y > 0) bounds.maximum.y else @floatCast(std.math.clamp(y, bounds.minimum.y, bounds.maximum.y)),
    } };
}
