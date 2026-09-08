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
/// f64 intermediates avoid overflow for finite f32 endpoints and extents.
pub fn query(sweep: Sweep, bounds: collider.Aabb) Error!?Contact {
    if (!sweep.from.isFinite() or !sweep.to.isFinite() or !sweep.half_extents.isFinite() or
        sweep.half_extents.x < 0 or sweep.half_extents.y < 0) return error.InvalidSweep;
    bounds.validate() catch return error.InvalidBounds;
    const from = [2]f64{ sweep.from.x, sweep.from.y };
    const delta = [2]f64{ @as(f64, sweep.to.x) - from[0], @as(f64, sweep.to.y) - from[1] };
    const lo = [2]f64{ @as(f64, bounds.minimum.x) - sweep.half_extents.x, @as(f64, bounds.minimum.y) - sweep.half_extents.y };
    const hi = [2]f64{ @as(f64, bounds.maximum.x) + sweep.half_extents.x, @as(f64, bounds.maximum.y) + sweep.half_extents.y };
    const normals = [_]math.Vec2{ .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 } };
    if (from[0] > lo[0] and from[0] < hi[0] and from[1] > lo[1] and from[1] < hi[1]) {
        const distances = [_]f64{ from[0] - lo[0], hi[0] - from[0], from[1] - lo[1], hi[1] - from[1] };
        var face: usize = 0;
        for (1..4) |index| if (distances[index] < distances[face]) {
            face = index;
        };
        return contact(sweep, bounds, 0, normals[face]);
    }
    var enter: f64 = -std.math.inf(f64);
    var leave: f64 = std.math.inf(f64);
    var normal = math.Vec2.zero;
    var entry_axis: usize = 2;
    var exit_axis: usize = 2;
    for (0..2) |axis| {
        if (delta[axis] == 0) {
            if (from[axis] <= lo[axis] or from[axis] >= hi[axis]) return null;
            continue;
        }
        const a = (lo[axis] - from[axis]) / delta[axis];
        const b = (hi[axis] - from[axis]) / delta[axis];
        const near = @min(a, b);
        if (near > enter) {
            enter = near;
            entry_axis = axis;
            normal = normals[axis * 2 + @as(usize, if (delta[axis] > 0) 0 else 1)];
        }
        if (@max(a, b) < leave) {
            leave = @max(a, b);
            exit_axis = axis;
        }
    }
    // One finite-width slab may collapse to the same f64 fraction at extreme
    // travel distances. It still crosses that slab; a tie between different
    // entry/exit axes instead describes an isolated corner graze.
    if (enter < 0 or enter > 1 or enter > leave or
        (enter == leave and entry_axis != exit_axis) or !std.math.isFinite(enter)) return null;
    return contact(sweep, bounds, enter, normal);
}

fn contact(sweep: Sweep, bounds: collider.Aabb, fraction: f64, normal: math.Vec2) Contact {
    const x = @as(f64, sweep.from.x) + (@as(f64, sweep.to.x) - sweep.from.x) * fraction;
    const y = @as(f64, sweep.from.y) + (@as(f64, sweep.to.y) - sweep.from.y) * fraction;
    return .{ .fraction = @floatCast(fraction), .normal = normal, .position = .{
        .x = if (normal.x < 0) bounds.minimum.x else if (normal.x > 0) bounds.maximum.x else @floatCast(std.math.clamp(x, bounds.minimum.x, bounds.maximum.x)),
        .y = if (normal.y < 0) bounds.minimum.y else if (normal.y > 0) bounds.maximum.y else @floatCast(std.math.clamp(y, bounds.minimum.y, bounds.maximum.y)),
    } };
}
