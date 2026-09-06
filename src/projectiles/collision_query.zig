const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const foundation = @import("foundation");

pub const Error = error{ QueryFailed, HitCapacity, InvalidHit };
pub const maximum_hits = 64;
pub const maximum_iterations = 8;
/// Transitive ordering: floor(TOI * 1,000,000), then native collider ID.
/// Within one bucket, a lower ID may win up to one millionth of a step later.
pub const time_buckets: f32 = 1_000_000;
pub const Sweep = struct {
    from: math.Vec2,
    to: math.Vec2,
    half_extents: math.Vec2,
    layer: u32,
    mask: u32,
    source: ?foundation.identity.EntityId,
    excluded: []const collider.ColliderId,
};
pub const Hit = struct {
    collider_id: collider.ColliderId,
    entity_id: ?foundation.identity.EntityId = null,
    position: math.Vec2,
    normal: math.Vec2,
    fraction: f32,
    layer: u32 = 1,
    mask: u32 = std.math.maxInt(u32),
    material: u32 = 0,
};
pub const Hits = struct {
    storage: []Hit,
    count: usize = 0,
    pub fn append(self: *Hits, hit: Hit) Error!void {
        if (self.count == self.storage.len) return error.HitCapacity;
        self.storage[self.count] = hit;
        self.count += 1;
    }
};
/// The host lends immutable context for this call only. Queries must be pure,
/// enumerate every candidate (or fail), and never mutate gameplay or this system.
/// Position is the surface contact; fraction is the swept center's travel time.
pub const Query = struct {
    context: ?*const anyopaque,
    collect: *const fn (?*const anyopaque, Sweep, *Hits) Error!void,
};

pub fn earliest(sweep: Sweep, hits: []const Hit) Error!?Hit {
    var result: ?Hit = null;
    for (hits, 0..) |hit, index| {
        const length_squared = hit.normal.lengthSquared();
        // 1e-4 permits ordinary normalized f32 query normals, not arbitrary scale.
        if (hit.collider_id == collider.invalid_collider_id or !hit.position.isFinite() or
            !hit.normal.isFinite() or @abs(length_squared - 1) > 1e-4 or
            !std.math.isFinite(hit.fraction) or hit.fraction < 0 or hit.fraction > 1)
            return error.InvalidHit;
        if (hit.entity_id) |id| _ = foundation.identity.EntityId.fromCanonicalBytes(id.bytes) catch return error.InvalidHit;
        for (hits[0..index]) |previous| if (previous.collider_id == hit.collider_id) return error.InvalidHit;
        if (sweep.layer & hit.mask == 0 or sweep.mask & hit.layer == 0) continue;
        if (std.mem.indexOfScalar(collider.ColliderId, sweep.excluded, hit.collider_id) != null) continue;
        // A tangent or separating zero-time touch does not obstruct travel.
        if (hit.fraction == 0 and sweep.to.sub(sweep.from).dot(hit.normal) >= 0) continue;
        if (result == null or before(hit, result.?)) result = hit;
    }
    return result;
}
fn before(a: Hit, b: Hit) bool {
    const a_bucket: u32 = @intFromFloat(@floor(a.fraction * time_buckets));
    const b_bucket: u32 = @intFromFloat(@floor(b.fraction * time_buckets));
    return a_bucket < b_bucket or (a_bucket == b_bucket and a.collider_id < b.collider_id);
}
