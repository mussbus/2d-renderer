const std = @import("std");
const p = @import("projectiles");
const e = @import("effects");
const math = @import("math");
const f = @import("foundation");
pub const Config = struct {
    namespace: f.identity.NamespaceId,
    trail_capacity: usize = 128,
    trail_spacing: f32 = 0.08,
    maximum_samples_per_segment: u16 = 64,
    launch: e.Definition,
    trail: e.Definition,
    impact: e.Definition,
    expiration: e.Definition,
};
pub const Metrics = struct { launches: u64 = 0, trail_samples: u64 = 0, impacts: u64 = 0, expirations: u64 = 0, dropped_effects: u64 = 0, dropped_trails: u64 = 0, truncated_segments: u64 = 0 };
pub const Error = e.Error || error{ InvalidConfiguration, EventsOutOfOrder };
const Trail = struct { id: p.Id, remainder: f64 = 0 };
/// Optional client-owned adapter. The projectile system is never passed by
/// mutable reference. Presentation capacity cannot change projectile outcomes.
pub const Bridge = struct {
    allocator: std.mem.Allocator,
    config: Config,
    trails: []Trail,
    count: usize = 0,
    last_sequence: ?u64 = null,
    metrics: Metrics = .{},
    pub fn init(allocator: std.mem.Allocator, config: Config) Error!Bridge {
        if (config.trail_capacity == 0 or config.trail_capacity > 65536 or
            !std.math.isFinite(config.trail_spacing) or config.trail_spacing < 1e-5 or
            config.maximum_samples_per_segment == 0 or config.maximum_samples_per_segment > 4096)
            return error.InvalidConfiguration;
        _ = f.identity.NamespaceId.fromCanonicalBytes(config.namespace.bytes) catch return error.InvalidIdentity;
        try config.launch.validate();
        try config.trail.validate();
        try config.impact.validate();
        try config.expiration.validate();
        return .{ .allocator = allocator, .config = config, .trails = try allocator.alloc(Trail, config.trail_capacity) };
    }
    pub fn deinit(self: *Bridge) void {
        self.allocator.free(self.trails);
        self.* = undefined;
    }
    pub fn reset(self: *Bridge) void {
        self.count = 0;
        self.last_sequence = null;
        self.metrics = .{};
    }
    /// Consume each ordered event batch once, before the core clears its buffer.
    /// Validate event sequence first, so duplicate delivery cannot repeat bursts.
    pub fn consume(self: *Bridge, events: []const p.Event, effects: *e.System) Error!void {
        var last = self.last_sequence;
        for (events) |event| {
            if (last) |sequence| if (event.sequence <= sequence) return error.EventsOutOfOrder;
            last = event.sequence;
        }
        for (events) |event| {
            switch (event.kind) {
                .spawned => {
                    if (self.count < self.trails.len) {
                        self.trails[self.count] = .{ .id = event.projectile.id };
                        self.count += 1;
                    } else self.metrics.dropped_trails +|= 1;
                    try self.emit(effects, event, 0, event.projectile.position, self.config.launch);
                    self.metrics.launches +|= 1;
                },
                .moved => try self.trail(event, effects),
                .collided => {
                    try self.emit(effects, event, 0, event.hit.?.position, self.config.impact);
                    self.metrics.impacts +|= 1;
                    if (event.projectile.definition.response == .despawn) self.removeTrail(event.projectile.id);
                },
                .expired => {
                    try self.emit(effects, event, 0, event.projectile.position, self.config.expiration);
                    self.metrics.expirations +|= 1;
                    self.removeTrail(event.projectile.id);
                },
                .removed => self.removeTrail(event.projectile.id),
                .deflected, .collision_limit => {},
            }
        }
        self.last_sequence = last;
    }
    fn trail(self: *Bridge, event: p.Event, effects: *e.System) Error!void {
        for (self.trails[0..self.count]) |*value| {
            if (!value.id.eql(event.projectile.id)) continue;
            const delta = event.projectile.position.sub(event.from);
            const dx: f64 = delta.x;
            const dy: f64 = delta.y;
            const length = @sqrt(dx * dx + dy * dy);
            if (length == 0) return;
            const spacing: f64 = self.config.trail_spacing;
            const total = value.remainder + length;
            // The total may exceed u64 for extreme valid projectile velocities;
            // keep it in f64 and convert only the explicitly bounded sample count.
            const available = @floor(total / spacing);
            const samples: u16 = @intFromFloat(@min(available, self.config.maximum_samples_per_segment));
            for (0..samples) |index| {
                const distance = spacing - value.remainder + @as(f64, @floatFromInt(index)) * spacing;
                const position = event.from.add(delta.scale(@floatCast(@min(distance / length, 1))));
                try self.emit(effects, event, @intCast(index), position, self.config.trail);
                self.metrics.trail_samples +|= 1;
            }
            if (available > self.config.maximum_samples_per_segment) self.metrics.truncated_segments +|= 1;
            value.remainder = @mod(total, spacing);
            return;
        }
    }
    fn emit(self: *Bridge, effects: *e.System, event: p.Event, sample: u32, position: math.Vec2, definition: e.Definition) Error!void {
        var key: [12]u8 = undefined;
        std.mem.writeInt(u64, key[0..8], event.sequence, .big);
        std.mem.writeInt(u32, key[8..12], sample, .big);
        const id = f.identity.uuidV5Fields(e.Id, self.config.namespace, &.{ "e.projectile_bridge.v1", &event.projectile.id.bytes, &key }) catch return error.InvalidIdentity;
        _ = effects.spawn(.{ .id = id, .definition = definition, .position = position }) catch |err| switch (err) {
            error.EmitterCapacity, error.InvalidSpawn => {
                self.metrics.dropped_effects +|= 1;
            },
            else => return err,
        };
    }
    fn removeTrail(self: *Bridge, id: p.Id) void {
        for (self.trails[0..self.count], 0..) |value, index| {
            if (value.id.eql(id)) {
                std.mem.copyForwards(Trail, self.trails[index .. self.count - 1], self.trails[index + 1 .. self.count]);
                self.count -= 1;
                return;
            }
        }
    }
};
