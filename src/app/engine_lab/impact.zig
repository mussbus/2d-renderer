//! One authored installation. Cores own lifetimes; this hub client owns values,
//! borrowed query adaptation, command consumption and bounded observations.
const std = @import("std");
const f = @import("foundation");
const math = @import("math");
const physics = @import("collision_world");
const collider = @import("collider");
pub const p = @import("projectiles");
pub const e = @import("effects");
pub const composition = @import("projectile_effects");

pub const projectile_namespace = "05a3a5bf-dab2-51fd-b625-cbb14f5fd6dd";
pub const bridge_namespace = "aaaf3d93-c358-535f-ae26-96d6dca205c4";
pub const right_wall_id: collider.ColliderId = 3;
pub const projectile_capacity = 8;
pub const particle_capacity = projectile_capacity * 24;
// Eight impact emitters plus the current tick's empty launch emitter. Empty
// launch emitters retire in the effects step before the following bridge batch.
pub const emitter_capacity = projectile_capacity + 1;
// One spawn, then at most one movement and one contact OR expiry per projectile
// in this despawn-only installation. No removal, bounce or deflection commands.
pub const event_capacity = 2 * projectile_capacity + 1;
pub const placement = math.Vec2{ .x = -0.3, .y = -1.8 };
pub const activation_half_extents = math.Vec2{ .x = 1.35, .y = 1.2 };
pub const velocity = math.Vec2{ .x = 1.875, .y = 0 };
pub const definition = p.Definition{ .half_extents = .{ .x = 0.0625, .y = 0.0625 }, .lifetime_ticks = 480, .response = .despawn };
pub const burst = e.Definition{
    .burst = 24,
    .particle_lifetime_ticks = 144,
    .velocity = .{ .x = -0.75, .y = 0.25 },
    .velocity_spread = .{ .x = 0.6, .y = 0.9 },
    .acceleration = .{ .x = 0, .y = -0.8 },
    .drag = 0.3,
    .start_size = .{ .x = 0.075, .y = 0.045 },
    .end_size = .{ .x = 0.015, .y = 0.01 },
    .start_color = .{ 1, 0.7, 0.2 },
    .end_color = .{ 1, 0.25, 0.05 },
    .sprite = @enumFromInt(1),
    .layer = -1,
};

// Hub content only: Definition.tag is an immutable palette index, never a
// projectile-core color contract. Eight entries allow unbiased three-bit choice.
pub const palette = [8]composition.Rgb{
    .{ 1, 0.25, 0.25 }, .{ 0.5, 1, 0.25 },  .{ 0.25, 1, 1 }, .{ 0.5, 0.5, 1 },
    .{ 1, 0.25, 1 },    .{ 1, 0.75, 0.25 }, .{ 1, 1, 0.5 },  .{ 0.25, 1, 0.625 },
};
pub fn colorForTag(tag: u32) error{InvalidShotColor}!composition.Rgb {
    if (tag >= palette.len) return error.InvalidShotColor;
    return palette[tag];
}

/// Static hub colliders have no F entity/affiliation mapping. Material zero and
/// layer one are explicit hub content choices; source identity is not inferred.
/// Every solid candidate is appended, in immutable world order, before the port
/// applies native-ID exclusions, masks and deterministic time-bucket/ID ties.
/// Capacity failure is propagated, including when a nearer candidate filters out.
pub fn collect(context: ?*const anyopaque, sweep: p.collision.Sweep, output: *p.collision.Hits) p.collision.Error!void {
    const world: *const physics.CollisionWorld = @ptrCast(@alignCast(context orelse return error.QueryFailed));
    for (world.colliders) |value| {
        if (!value.solid) continue;
        const hit = physics.static_sweep.query(.{ .from = sweep.from, .to = sweep.to, .half_extents = sweep.half_extents }, value.bounds) catch return error.QueryFailed;
        if (hit) |contact| try output.append(.{ .collider_id = value.id, .position = contact.position, .normal = contact.normal, .fraction = contact.fraction, .layer = 1, .mask = 0xffffffff, .material = 0, .entity_id = null });
    }
}

pub const Observations = struct {
    launches: u64 = 0,
    busy: u64 = 0,
    out_of_range: u64 = 0,
    contacts: u64 = 0,
    executing_tick: u64 = 0,
    last_launch: ?p.Event = null,
    last_contact: ?p.Event = null,
    last_batch: [event_capacity]p.Event = undefined,
    batch_count: usize = 0,
    events_digest: [32]u8 = @splat(0),
};

pub const Installation = struct {
    projectiles: p.System,
    effects: e.System,
    bridge: composition.Bridge,
    source: f.identity.EntityId,
    launcher: math.Vec2,
    wall_marker: math.Vec2,
    pending_activation: bool = false,
    // Authoritative successful-shot sequence, separate from diagnostic counters.
    color_context: f.determinism.DerivationContext,
    next_shot_ordinal: u64 = 0,
    color_overrides: [event_capacity]?composition.Rgb = undefined,
    observations: Observations = .{},

    pub fn init(allocator: std.mem.Allocator, seed: e.Seed, source: f.identity.EntityId, anchor: math.Vec2, world: *const physics.CollisionWorld) !Installation {
        const launcher = anchor.add(placement);
        var wall: ?collider.StaticCollider = null;
        for (world.colliders) |value| if (value.id == right_wall_id) {
            wall = value;
        };
        const target = wall orelse return error.ImpactWallMissing;
        if (launcher.x >= target.bounds.minimum.x or launcher.y <= target.bounds.minimum.y or launcher.y >= target.bounds.maximum.y) return error.InvalidImpactPlacement;
        var projectiles = try p.System.init(allocator, .{ .namespace = try f.identity.NamespaceId.parseCanonical(projectile_namespace), .capacity = projectile_capacity, .event_capacity = event_capacity });
        errdefer projectiles.deinit();
        var effects = try e.System.init(allocator, .{ .seed = seed, .emitter_capacity = emitter_capacity, .particle_capacity = particle_capacity });
        errdefer effects.deinit();
        const bridge = try composition.Bridge.init(allocator, .{
            .namespace = try f.identity.NamespaceId.parseCanonical(bridge_namespace),
            .trail_capacity = projectile_capacity,
            // This installation authors no launch/trail/expiration particles.
            // The accepted bridge still receives every native event once.
            .trail_spacing = 100,
            .maximum_samples_per_segment = 1,
            .launch = .{ .burst = 0 },
            .trail = .{ .burst = 0 },
            .impact = burst,
            .expiration = .{ .burst = 0 },
        });
        return .{ .color_context = .{
            .root_seed = seed,
            .generator_id = comptime f.identity.GeneratorId.parseCanonical("f898e009-d4ae-51af-ad48-a862d2471277") catch @compileError("valid hub palette generator ID"),
            .generator_version = .{ .major = 1, .minor = 0, .patch = 0 },
            .algorithm_id = comptime f.identity.AlgorithmId.parseCanonical("08c28ecd-7338-5c97-b7e0-37059add6f8e") catch @compileError("valid hub palette algorithm ID"),
            .algorithm_version = .{ .major = 1, .minor = 0, .patch = 0 },
        }, .projectiles = projectiles, .effects = effects, .bridge = bridge, .source = source, .launcher = launcher, .wall_marker = .{ .x = target.bounds.minimum.x, .y = launcher.y } };
    }
    pub fn deinit(self: *Installation) void {
        self.bridge.deinit();
        self.effects.deinit();
        self.projectiles.deinit();
        self.* = undefined;
    }
    pub fn inRange(self: *const Installation, actor_position: math.Vec2) bool {
        const delta = actor_position.sub(self.launcher);
        return @abs(delta.x) <= activation_half_extents.x and @abs(delta.y) <= activation_half_extents.y;
    }
    /// Executed before any actor update, while both cores remain at tick N.
    /// The returned command is a value. Busy/out-of-range edges never queue shots.
    pub fn consumeActivation(self: *Installation, actor_position: math.Vec2) !?p.Spawn {
        if (!self.pending_activation) return null;
        self.pending_activation = false;
        if (!self.inRange(actor_position)) {
            self.observations.out_of_range +|= 1;
            return null;
        }
        if (self.projectiles.count() >= projectile_capacity) {
            self.observations.busy +|= 1;
            return null;
        }
        if (self.next_shot_ordinal == std.math.maxInt(u64)) return error.ShotSequenceExhausted;
        var ordinal: [8]u8 = undefined;
        std.mem.writeInt(u64, &ordinal, self.next_shot_ordinal, .big);
        const key = try f.determinism.deriveKey(self.color_context, &.{ "engine_lab.shot_palette.v1", &ordinal });
        var shot = definition;
        shot.tag = key[0] & 7;
        return .{ .definition = shot, .position = self.launcher, .velocity = velocity, .source = self.source };
    }
    /// After the existing actor/station/camera block: effects N->N+1; spawn at
    /// native N; projectiles N->N+1; copy observations; bridge once; clear batch.
    /// Impact particles are born at age zero and advance on the next hub tick.
    /// Query context is borrowed only here. Errors abort the run; no hub rollback.
    pub fn step(self: *Installation, command: ?p.Spawn, world: *const physics.CollisionWorld, executing_tick: u64) !void {
        try self.effects.step();
        if (command) |request| {
            _ = try self.projectiles.spawn(request);
            self.next_shot_ordinal += 1;
        }
        try self.projectiles.step(.{ .context = world, .collect = collect });
        {
            const events = self.projectiles.events();
            if (events.len > self.observations.last_batch.len) return error.ImpactObservationCapacity;
            self.observations.executing_tick = executing_tick;
            self.observations.batch_count = events.len;
            @memcpy(self.observations.last_batch[0..events.len], events);
            for (events, 0..) |event, index| {
                self.color_overrides[index] = try colorForTag(event.projectile.definition.tag);
                var hash = std.crypto.hash.sha2.Sha256.init(.{});
                hash.update(&self.observations.events_digest);
                hashValue(&hash, event);
                hash.final(&self.observations.events_digest);
                switch (event.kind) {
                    .spawned => {
                        self.observations.launches +|= 1;
                        self.observations.last_launch = event;
                    },
                    .collided => {
                        self.observations.contacts +|= 1;
                        self.observations.last_contact = event;
                    },
                    else => {},
                }
            }
            try self.bridge.consumeWithColors(events, &self.effects, self.color_overrides[0..events.len]);
        }
        self.projectiles.clearEvents();
        if (self.projectiles.tick() != executing_tick or self.effects.tick() != executing_tick) return error.ImpactTickMismatch;
    }
    /// Integration observation schema v2, separate from EL1 selected-state v2.
    /// Covers authored configuration, core ticks, copied live projectile/particle
    /// records (including immutable shot tags and particle RGB), color derivation
    /// context/palette/successful-shot ordinal, particle-reachable live emitters,
    /// ordered event history,
    /// command/capacity observations and bridge sequence/count/metrics. Excludes
    /// private RNG/storage, empty emitters, camera, frame residue and EL1 state.
    /// A diagnostic comparison only; never a save/restore or RR1 serialization.
    pub fn fingerprint(self: *const Installation) !f.canonical_data.Sha256Digest {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("engine_lab.projectile_impact.observations.v2");
        hashValue(&hash, self.color_context);
        hashValue(&hash, palette);
        hashValue(&hash, self.next_shot_ordinal);
        hashValue(&hash, self.source);
        hashValue(&hash, self.launcher);
        hashValue(&hash, self.wall_marker);
        hashValue(&hash, definition);
        hashValue(&hash, velocity);
        hashValue(&hash, self.bridge.config);
        hashValue(&hash, self.projectiles.tick());
        hashValue(&hash, self.effects.tick());
        hashValue(&hash, self.pending_activation);
        var projectiles: [projectile_capacity]p.Snapshot = undefined;
        const values = try self.projectiles.copySnapshots(&projectiles);
        hashValue(&hash, @as(u64, @intCast(values.len)));
        for (values) |value| hashValue(&hash, value);
        var particles: [particle_capacity]e.ParticleSnapshot = undefined;
        const particle_values = try self.effects.copyParticles(&particles);
        hashValue(&hash, @as(u64, @intCast(particle_values.len)));
        for (particle_values) |value| {
            hashValue(&hash, value);
            hashValue(&hash, self.effects.emitter(value.effect_id));
        }
        hashValue(&hash, self.effects.metrics());
        hashValue(&hash, @as(u64, @intCast(self.effects.emitterCount())));
        hashValue(&hash, self.bridge.last_sequence);
        hashValue(&hash, @as(u64, @intCast(self.bridge.count)));
        hashValue(&hash, self.bridge.metrics);
        hashValue(&hash, self.observations.launches);
        hashValue(&hash, self.observations.contacts);
        hashValue(&hash, self.observations.busy);
        hashValue(&hash, self.observations.out_of_range);
        hashValue(&hash, self.observations.events_digest);
        return .{ .bytes = hash.finalResult() };
    }
};

// Explicit field encoding, never padding/pointers/private core memory. Fixed
// scalar byte order and struct declaration order define this local schema.
fn hashValue(hash: *std.crypto.hash.sha2.Sha256, value: anytype) void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .@"struct" => inline for (std.meta.fields(T)) |field| hashValue(hash, @field(value, field.name)),
        .array => for (value) |item| hashValue(hash, item),
        .optional => {
            hashValue(hash, value != null);
            if (value) |item| hashValue(hash, item);
        },
        .@"enum" => hashValue(hash, @intFromEnum(value)),
        .bool => hash.update(&.{@intFromBool(value)}),
        .int => {
            var bytes: [@sizeOf(T)]u8 = undefined;
            const bits: std.meta.Int(.unsigned, @bitSizeOf(T)) = @bitCast(value);
            std.mem.writeInt(std.meta.Int(.unsigned, @sizeOf(T) * 8), &bytes, @intCast(bits), .little);
            hash.update(&bytes);
        },
        .float => hashValue(hash, @as(std.meta.Int(.unsigned, @bitSizeOf(T)), @bitCast(value))),
        else => @compileError("Unsupported integration observation field"),
    }
}
