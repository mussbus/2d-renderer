const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const effects = @import("effects");

pub const SpawnId = enum(u16) { approach = 101, first = 102, second = 103, upper = 104, far = 105, returning = 106, _ };
pub const Spawn = struct {
    id: SpawnId,
    position: math.Vec2,
    half_extents: math.Vec2 = .{ .x = 0.12, .y = 0.12 },
    support: collider.ColliderId,

    pub fn bounds(self: Spawn) !collider.Aabb {
        return collider.characterBounds(self.position, self.half_extents);
    }
};

// Authored world metres, Y up. The six entries belong only to this application slice.
pub const spawns = [_]Spawn{
    .{ .id = .approach, .position = .{ .x = -5.7, .y = 1.05 }, .support = 1 },
    .{ .id = .first, .position = .{ .x = -8.2, .y = 2.65 }, .support = 10 },
    .{ .id = .second, .position = .{ .x = -11.6, .y = 4.25 }, .support = 11 },
    .{ .id = .upper, .position = .{ .x = -15.2, .y = 5.85 }, .support = 12 },
    .{ .id = .far, .position = .{ .x = -21.7, .y = 5.85 }, .support = 13 },
    .{ .id = .returning, .position = .{ .x = -17.2, .y = 1.05 }, .support = 1 },
};
pub const reaction_ticks: u8 = 24;
pub const color = [3]f32{ 0.35, 1, 0.55 };
pub const reaction = effects.Definition{
    .burst = 12,
    .particle_lifetime_ticks = 120,
    .velocity = .{ .x = 0, .y = 0.6 },
    .velocity_spread = .{ .x = 1.8, .y = 1.8 },
    .acceleration = .{ .x = 0, .y = -1.4 },
    .drag = 0.8,
    .start_size = .{ .x = 0.09, .y = 0.09 },
    .end_size = .{ .x = 0.025, .y = 0.025 },
    .start_color = color,
    .end_color = color,
    .layer = -1,
};

pub fn validate(items: []const Spawn, solids: []const collider.StaticColliderInput, actor_half: math.Vec2) !void {
    if (items.len != spawns.len) return error.CollectibleSequenceLength;
    if (!std.math.isFinite(actor_half.x) or !std.math.isFinite(actor_half.y) or actor_half.x <= 0 or actor_half.y <= 0) return error.CollectibleActorBounds;
    try reaction.validate();
    for (items, 0..) |item, index| {
        for (items[0..index]) |prior| if (prior.id == item.id) return error.CollectibleDuplicateId;
        if (item.id != spawns[index].id) return error.CollectibleSequence;
        if (!std.math.isFinite(item.position.x) or !std.math.isFinite(item.position.y) or !std.math.isFinite(item.half_extents.x) or !std.math.isFinite(item.half_extents.y) or item.half_extents.x <= 0 or item.half_extents.y <= 0) return error.CollectibleBounds;
        const bounds = try item.bounds();
        if (bounds.minimum.x < -24 or bounds.maximum.x > 8 or bounds.minimum.y < 0 or bounds.maximum.y > 14) return error.CollectibleOutsideRoom;
        if (index > 0 and item.position.x == items[index - 1].position.x and item.position.y == items[index - 1].position.y) return error.CollectibleCoincident;
        if (item.support != spawns[index].support) return error.CollectibleSupportSequence;
        var support: ?collider.StaticColliderInput = null;
        for (solids) |solid| {
            if (solid.id == item.support) support = solid;
            if (solid.solid and collider.overlapsStrict(bounds, solid.bounds)) return error.CollectibleInsideSolid;
        }
        const base = support orelse return error.CollectibleMissingSupport;
        if (!base.solid or !base.ground_query_eligible) return error.CollectibleInvalidSupport;
        const margin = actor_half.x + item.half_extents.x;
        if (item.position.x < base.bounds.minimum.x + margin or item.position.x > base.bounds.maximum.x - margin) return error.CollectibleLandingMargin;
        // Authored decimal heights are f32; 1e-5 covers their rounding, not another placement tier.
        if (@abs(item.position.y - base.bounds.maximum.y - actor_half.y) > 0.00001) return error.CollectibleStandingHeight;
        const standing = try collider.characterBounds(item.position, actor_half);
        for (solids) |solid| if (solid.id != item.support and solid.solid and collider.overlapsStrict(standing, solid.bounds)) return error.CollectibleStandingClearance;
    }
}
