const std = @import("std");
const p = @import("projectiles");
const e = @import("effects");
const composition = @import("projectile_effects");
const math = @import("math");
const f = @import("foundation");
const collider = @import("collider");
const physics = @import("collision_world");
pub const seed = e.Seed{ .bytes = .{7} ** 16 };
pub const namespace = f.identity.NamespaceId.parseCanonical("e8994868-c00c-58c9-bac0-79c85cb24dc7") catch @compileError("valid Effects/projectiles proof namespace");
pub const source_a = blk: {
    // Compile the fixed UUIDv5 input once; SHA-1 exceeds Zig's default quota.
    @setEvalBranchQuota(10000);
    break :blk f.identity.uuidV5(p.Id, namespace, "proof-source-a");
};
pub const source_b = blk: {
    // Compile the fixed UUIDv5 input once; SHA-1 exceeds Zig's default quota.
    @setEvalBranchQuota(10000);
    break :blk f.identity.uuidV5(p.Id, namespace, "proof-source-b");
};
pub const affiliation_a: p.Affiliation = @enumFromInt(1);
pub const affiliation_b: p.Affiliation = @enumFromInt(2);
pub const targets = [_]collider.StaticColliderInput{
    .{ .id = 1, .bounds = .{ .minimum = .{ .x = 2.2, .y = 0.8 }, .maximum = .{ .x = 2.3, .y = 1.8 } } },
    .{ .id = 2, .bounds = .{ .minimum = .{ .x = 1.8, .y = 2 }, .maximum = .{ .x = 1.9, .y = 2.8 } } },
    .{ .id = 3, .bounds = .{ .minimum = .{ .x = 0.2, .y = 0.1 }, .maximum = .{ .x = 0.204, .y = 0.7 } } },
    .{ .id = 4, .bounds = .{ .minimum = .{ .x = -1.9, .y = -0.8 }, .maximum = .{ .x = -1.7, .y = -0.5 } } },
    .{ .id = 5, .bounds = .{ .minimum = .{ .x = 1.4, .y = -0.8 }, .maximum = .{ .x = 1.6, .y = -0.5 } } },
};
pub const Statistics = struct { collisions: u64 = 0, deflections: u64 = 0, expirations: u64 = 0, peak_projectiles: usize = 0, ownership_transfers: u64 = 0, former_source_hits: u64 = 0, new_source_hits: u64 = 0 };
pub const Scene = struct {
    projectiles: p.System,
    effects: e.System,
    bridge: composition.Bridge,
    world: physics.CollisionWorld,
    statistics: Statistics = .{},
    ownership_projectile: ?p.Id = null,
    pub fn init(allocator: std.mem.Allocator, presentation: bool) !Scene {
        var projectiles = try p.System.init(allocator, .{ .namespace = namespace, .capacity = 32 });
        errdefer projectiles.deinit();
        var effects = try e.System.init(allocator, .{ .seed = seed, .emitter_capacity = 512, .particle_capacity = 1500 });
        errdefer effects.deinit();
        var bridge = try composition.Bridge.init(allocator, .{
            .namespace = namespace,
            .trail_capacity = 32,
            .trail_spacing = 0.06,
            .launch = .{ .burst = 10, .particle_lifetime_ticks = 48, .velocity_spread = .{ .x = 1.4, .y = 1.4 }, .start_size = .{ .x = 0.08, .y = 0.08 }, .sprite = @enumFromInt(4), .layer = 2 },
            .trail = .{ .burst = 1, .particle_lifetime_ticks = 100, .position_spread = .{ .x = 0.015, .y = 0.015 }, .start_size = .{ .x = 0.055, .y = 0.055 }, .sprite = @enumFromInt(3), .layer = 1 },
            .impact = .{ .burst = 32, .particle_lifetime_ticks = 150, .velocity_spread = .{ .x = 2, .y = 2 }, .acceleration = .{ .x = 0, .y = -2 }, .drag = 0.5, .angular_velocity = 3, .start_size = .{ .x = 0.085, .y = 0.045 }, .sprite = @enumFromInt(4), .layer = 3 },
            .expiration = .{ .burst = 18, .particle_lifetime_ticks = 150, .velocity_spread = .{ .x = 0.7, .y = 0.7 }, .start_size = .{ .x = 0.12, .y = 0.12 }, .end_size = .{ .x = 0.025, .y = 0.025 }, .sprite = @enumFromInt(1), .layer = 2 },
        });
        errdefer bridge.deinit();
        var world = physics.CollisionWorld.init(allocator, &targets, null) catch |err| switch (err) {
            error.AllocationFailure => return error.OutOfMemory,
            else => return err,
        };
        errdefer world.deinit();
        var self = Scene{ .projectiles = projectiles, .effects = effects, .bridge = bridge, .world = world };
        try self.reset(seed, presentation);
        return self;
    }
    pub fn deinit(self: *Scene) void {
        self.world.deinit();
        self.bridge.deinit();
        self.effects.deinit();
        self.projectiles.deinit();
        self.* = undefined;
    }
    pub fn reset(self: *Scene, new_seed: e.Seed, presentation: bool) !void {
        self.projectiles.reset();
        self.effects.reset(new_seed);
        self.bridge.reset();
        self.statistics = .{};
        self.ownership_projectile = null;
        _ = try self.projectiles.spawn(.{ .definition = .{ .lifetime_ticks = 360, .acceleration = .{ .x = 0, .y = -1 }, .half_extents = .{ .x = 0.06, .y = 0.06 }, .tag = 2 }, .position = .{ .x = -3, .y = 1.2 }, .velocity = .{ .x = 6, .y = 0.5 } });
        _ = try self.projectiles.spawn(.{ .definition = .{ .lifetime_ticks = 400, .response = .bounce, .tag = 3 }, .position = .{ .x = -3, .y = 2.5 }, .velocity = .{ .x = 7, .y = 0 } });
        _ = try self.projectiles.spawn(.{ .definition = .{ .lifetime_ticks = 240, .tag = 1 }, .position = .{ .x = -3, .y = 3.6 }, .velocity = .{ .x = 3, .y = 0 } });
        _ = try self.projectiles.spawn(.{ .definition = .{ .lifetime_ticks = 210, .response = .continue_travel, .tag = 4 }, .position = .{ .x = -3, .y = 0.4 }, .velocity = .{ .x = 8, .y = 0 } });
        self.statistics.peak_projectiles = self.projectiles.count();
        if (presentation) {
            _ = try self.effects.spawn(.{ .id = f.identity.uuidV5(e.Id, namespace, "continuous-proof"), .definition = .{ .rate_milli = 16000, .duration_ticks = 480, .particle_lifetime_ticks = 180, .velocity = .{ .x = 0.1, .y = 0.9 }, .velocity_spread = .{ .x = 0.3, .y = 0.25 }, .acceleration = .{ .x = 0, .y = -0.5 }, .sprite = @enumFromInt(3), .start_size = .{ .x = 0.05, .y = 0.05 } }, .position = .{ .x = -2.8, .y = -0.5 } });
            try self.bridge.consume(self.projectiles.events(), &self.effects);
        }
        self.projectiles.clearEvents();
    }
    /// Adds one bounded neutral ownership/filter example to the original four cases.
    /// The original reset remains independently covered by its unchanged assertions.
    pub fn resetWithOwnershipProof(self: *Scene, new_seed: e.Seed, presentation: bool) !void {
        try self.reset(new_seed, presentation);
        self.ownership_projectile = try self.projectiles.spawn(.{
            .definition = .{ .lifetime_ticks = 400, .layer = 4, .mask = 8, .tag = 4 },
            .position = .{ .x = -1.7, .y = -0.65 },
            .velocity = .{ .x = 6, .y = 0 },
            .source = source_a,
            .affiliation = affiliation_a,
        });
        self.statistics.peak_projectiles = self.projectiles.count();
        if (presentation) try self.bridge.consume(self.projectiles.events(), &self.effects);
        self.projectiles.clearEvents();
    }
    pub fn spawnExtra(self: *Scene) !void {
        _ = try self.projectiles.spawn(.{ .definition = .{ .lifetime_ticks = 320, .response = .bounce, .acceleration = .{ .x = 0, .y = -1 }, .tag = 4 }, .position = .{ .x = -2.8, .y = 2.4 }, .velocity = .{ .x = 6, .y = 0.2 } });
        self.statistics.peak_projectiles = @max(self.statistics.peak_projectiles, self.projectiles.count());
    }
    pub fn deflectFirst(self: *Scene) !void {
        var storage: [32]p.Snapshot = undefined;
        const values = try self.projectiles.copySnapshots(&storage);
        if (values.len == 0) return;
        try self.projectiles.deflect(values[0].id, .{ .velocity = .{ .x = 4, .y = 1.5 }, .restart_lifetime = true });
    }
    pub fn step(self: *Scene, presentation: bool) !void {
        // Explicit client command between completed tick 120 and tick 121.
        // Source B becomes owner; its layer is excluded, while former source A
        // becomes hittable. The engine assigns no meaning to these tokens/bits.
        if (self.projectiles.tick() == 120) {
            if (self.ownership_projectile) |id| {
                if (self.projectiles.snapshot(id) != null) try self.projectiles.deflect(id, .{
                    .velocity = .{ .x = -6, .y = 0 },
                    .source = .{ .value = source_b },
                    .affiliation = .{ .value = affiliation_b },
                    .layer = 8,
                    .mask = 4,
                });
            }
        }
        if (presentation) try self.effects.step();
        try self.projectiles.step(.{ .context = &self.world, .collect = collectTargets });
        for (self.projectiles.events()) |event| switch (event.kind) {
            .collided => {
                self.statistics.collisions += 1;
                if (event.projectile.source) |source| {
                    if (source.eql(source_b)) {
                        if (event.hit.?.entity_id) |entity| {
                            if (entity.eql(source_a)) self.statistics.former_source_hits += 1;
                            if (entity.eql(source_b)) self.statistics.new_source_hits += 1;
                        }
                    }
                }
            },
            .deflected => {
                self.statistics.deflections += 1;
                const before = event.before_deflection.?;
                if (before.source) |source| {
                    if (source.eql(source_a) and event.projectile.source != null and event.projectile.source.?.eql(source_b)) self.statistics.ownership_transfers += 1;
                }
            },
            .expired => self.statistics.expirations += 1,
            else => {},
        };
        if (presentation) try self.bridge.consume(self.projectiles.events(), &self.effects);
        self.projectiles.clearEvents();
    }
};
/// Proof-only swept point/AABB query against the accepted CollisionWorld's
/// immutable colliders. Production PHY query/layer/material integration remains
/// a separate adapter. This client neither changes nor copies physics authority.
pub fn collectTargets(context: ?*const anyopaque, sweep: p.collision.Sweep, output: *p.collision.Hits) p.collision.Error!void {
    const world: *const physics.CollisionWorld = @ptrCast(@alignCast(context.?));
    for (world.colliders) |value| {
        if (!value.solid) continue;
        if (sweepBox(sweep, value.bounds)) |contact| {
            try output.append(.{
                .collider_id = value.id,
                .position = contact.position,
                .normal = contact.normal,
                .fraction = contact.fraction,
                .material = value.id,
                .entity_id = if (value.id == 4) source_a else if (value.id == 5) source_b else null,
                .layer = if (value.id == 4) 4 else if (value.id == 5) 8 else 1,
                .mask = if (value.id == 4) 8 else if (value.id == 5) 4 else 0xffffffff,
            });
        }
    }
}
pub const Contact = struct { position: math.Vec2, normal: math.Vec2, fraction: f32 };
pub fn sweepBox(sweep: p.collision.Sweep, bounds: collider.Aabb) ?Contact {
    const minimum = bounds.minimum.sub(sweep.half_extents);
    const maximum = bounds.maximum.add(sweep.half_extents);
    const from = sweep.from.toArray();
    const delta = sweep.to.sub(sweep.from).toArray();
    const lo = minimum.toArray();
    const hi = maximum.toArray();
    var enter: f32 = -std.math.inf(f32);
    var leave: f32 = 1;
    var normal = math.Vec2.zero;
    for (0..2) |axis| {
        if (delta[axis] == 0) {
            if (from[axis] < lo[axis] or from[axis] > hi[axis]) return null;
            continue;
        }
        const a = (lo[axis] - from[axis]) / delta[axis];
        const b = (hi[axis] - from[axis]) / delta[axis];
        const near = @min(a, b);
        const far = @max(a, b);
        // Exact corner ties choose X before Y, independent of collider ordering.
        if (near > enter) {
            enter = near;
            const sign: f32 = if (delta[axis] > 0) -1 else 1;
            normal = if (axis == 0) .{ .x = sign, .y = 0 } else .{ .x = 0, .y = sign };
        }
        leave = @min(leave, far);
    }
    if (enter > leave or leave < 0 or enter > 1 or normal.lengthSquared() == 0) return null;
    if (enter < 0) {
        // Strict initial overlap reports at zero against the direction of travel.
        // A boundary touch moving away has no entry in this segment.
        const strict_inside = from[0] > lo[0] and from[0] < hi[0] and from[1] > lo[1] and from[1] < hi[1];
        if (!strict_inside) return null;
        enter = 0;
    }
    const center = sweep.from.add(sweep.to.sub(sweep.from).scale(enter));
    const position = center.sub(normal.componentMul(sweep.half_extents));
    return .{ .position = position, .normal = normal, .fraction = enter };
}
