const std = @import("std");
const math = @import("math");
const foundation = @import("foundation");
const fixed_step = @import("fixed_step");
const collider = @import("collider");
pub const collision = @import("collision_query.zig");
pub const Id = foundation.identity.EntityId;
pub const dt: f32 = @floatCast(fixed_step.fixed_dt_seconds);
pub const Response = enum { despawn, continue_travel, bounce };
pub const Definition = struct {
    acceleration: math.Vec2 = .zero,
    lifetime_ticks: u32 = 240,
    half_extents: math.Vec2 = .zero,
    layer: u32 = 1,
    mask: u32 = std.math.maxInt(u32),
    response: Response = .despawn,
    restitution: f32 = 1,
    collision_iterations: u8 = 4,
    tag: u32 = 0,
    pub fn validate(self: Definition) Error!void {
        if (!self.acceleration.isFinite() or !self.half_extents.isFinite() or
            self.half_extents.x < 0 or self.half_extents.y < 0 or
            self.lifetime_ticks == 0 or !std.math.isFinite(self.restitution) or
            self.restitution < 0 or self.restitution > 1 or self.collision_iterations == 0 or
            self.collision_iterations > collision.maximum_iterations) return error.InvalidDefinition;
    }
};
pub const Spawn = struct {
    definition: Definition,
    position: math.Vec2,
    velocity: math.Vec2,
    source: ?Id = null,
    enabled: bool = true,
};
pub const Snapshot = struct {
    id: Id,
    source: ?Id,
    definition: Definition,
    previous_position: math.Vec2,
    position: math.Vec2,
    velocity: math.Vec2,
    age_ticks: u32 = 0,
    enabled: bool,
};
pub const EventKind = enum { spawned, moved, collided, deflected, expired, removed, collision_limit };
pub const Event = struct {
    sequence: u64,
    tick: u64,
    kind: EventKind,
    projectile: Snapshot,
    from: math.Vec2,
    hit: ?collision.Hit = null,
    incoming_velocity: math.Vec2,
    /// Fraction of the entire fixed step, including preceding bounce segments.
    step_fraction: f32 = 0,
};
pub const Deflect = struct {
    velocity: math.Vec2,
    /// Null leaves ownership unchanged; a populated optional can also clear it.
    source: ?struct { value: ?Id } = null,
    position: ?math.Vec2 = null,
    restart_lifetime: bool = false,
};
pub const Config = struct { capacity: usize = 128, event_capacity: usize = 4096, namespace: foundation.identity.NamespaceId };
pub const Error = collision.Error || error{
    OutOfMemory,
    InvalidCapacity,
    InvalidDefinition,
    InvalidSpawn,
    InvalidIdentity,
    InvalidDeflection,
    CapacityExceeded,
    EventCapacity,
    UnknownProjectile,
    IdentityExhausted,
    TickExhausted,
    NonFiniteMotion,
    SnapshotCapacity,
};
const State = struct {
    allocator: std.mem.Allocator,
    namespace: foundation.identity.NamespaceId,
    items: []Snapshot,
    scratch: []Snapshot,
    events: []Event,
    scratch_events: []Event,
    count: usize = 0,
    event_count: usize = 0,
    next_id: u64 = 1,
    next_event: u64 = 0,
    tick: u64 = 0,
};
/// Unique owner. Snapshots are copied values. Events borrow a const batch
/// valid until the next command, step, reset or clearEvents call.
pub const System = struct {
    opaque_context: *const anyopaque,
    fn storage(self: *const System) *State {
        return @ptrCast(@alignCast(@constCast(self.opaque_context)));
    }
    pub fn init(allocator: std.mem.Allocator, config: Config) Error!System {
        if (config.capacity == 0 or config.capacity > 65536 or config.event_capacity == 0 or config.event_capacity > 1048576) return error.InvalidCapacity;
        _ = foundation.identity.NamespaceId.fromCanonicalBytes(config.namespace.bytes) catch return error.InvalidIdentity;
        const state = try allocator.create(State);
        errdefer allocator.destroy(state);
        const items = try allocator.alloc(Snapshot, config.capacity);
        errdefer allocator.free(items);
        const scratch = try allocator.alloc(Snapshot, config.capacity);
        errdefer allocator.free(scratch);
        const event_storage = try allocator.alloc(Event, config.event_capacity);
        errdefer allocator.free(event_storage);
        const scratch_events = try allocator.alloc(Event, config.event_capacity);
        state.* = .{ .allocator = allocator, .namespace = config.namespace, .items = items, .scratch = scratch, .events = event_storage, .scratch_events = scratch_events };
        return .{ .opaque_context = state };
    }
    pub fn deinit(self: *System) void {
        const s = self.storage();
        const allocator = s.allocator;
        allocator.free(s.scratch_events);
        allocator.free(s.events);
        allocator.free(s.scratch);
        allocator.free(s.items);
        allocator.destroy(s);
        self.* = undefined;
    }
    pub fn count(self: *const System) usize {
        return self.storage().count;
    }
    pub fn tick(self: *const System) u64 {
        return self.storage().tick;
    }
    pub fn events(self: *const System) []const Event {
        return self.storage().events[0..self.storage().event_count];
    }
    pub fn clearEvents(self: *System) void {
        self.storage().event_count = 0;
    }
    /// Explicit scenario reset. All previously observed IDs/events are invalidated.
    pub fn reset(self: *System) void {
        const s = self.storage();
        s.count = 0;
        s.event_count = 0;
        s.next_id = 1;
        s.next_event = 0;
        s.tick = 0;
    }
    pub fn snapshot(self: *const System, id: Id) ?Snapshot {
        for (self.storage().items[0..self.storage().count]) |item| if (item.id.eql(id)) return item;
        return null;
    }
    pub fn copySnapshots(self: *const System, output: []Snapshot) Error![]const Snapshot {
        if (output.len < self.storage().count) return error.SnapshotCapacity;
        @memcpy(output[0..self.storage().count], self.storage().items[0..self.storage().count]);
        return output[0..self.storage().count];
    }
    pub fn spawn(self: *System, request: Spawn) Error!Id {
        try request.definition.validate();
        if (!request.position.isFinite() or !request.velocity.isFinite()) return error.InvalidSpawn;
        try validateSource(request.source);
        const s = self.storage();
        if (s.count == s.items.len) return error.CapacityExceeded;
        if (s.next_id == std.math.maxInt(u64)) return error.IdentityExhausted;
        var key: [8]u8 = undefined;
        std.mem.writeInt(u64, &key, s.next_id, .big);
        const id = foundation.identity.uuidV5Fields(Id, s.namespace, &.{ "p.projectile.v1", &key }) catch return error.InvalidIdentity;
        const item = Snapshot{ .id = id, .source = request.source, .definition = request.definition, .previous_position = request.position, .position = request.position, .velocity = request.velocity, .enabled = request.enabled };
        try emit(s, .spawned, item, item.position, null, item.velocity, 0);
        s.items[s.count] = item;
        s.count += 1;
        s.next_id += 1;
        return id;
    }
    pub fn remove(self: *System, id: Id) Error!void {
        const s = self.storage();
        const index = try find(s, id);
        const item = s.items[index];
        try emit(s, .removed, item, item.position, null, item.velocity, 0);
        erase(s, index);
    }
    pub fn setEnabled(self: *System, id: Id, enabled: bool) Error!void {
        const index = try find(self.storage(), id);
        self.storage().items[index].enabled = enabled;
        self.storage().items[index].previous_position = self.storage().items[index].position;
    }
    pub fn deflect(self: *System, id: Id, command: Deflect) Error!void {
        if (!command.velocity.isFinite()) return error.InvalidDeflection;
        if (command.position) |position| if (!position.isFinite()) return error.InvalidDeflection;
        if (command.source) |source| try validateSource(source.value);
        const s = self.storage();
        const index = try find(s, id);
        var item = s.items[index];
        const incoming = item.velocity;
        item.velocity = command.velocity;
        if (command.source) |source| item.source = source.value;
        if (command.position) |position| {
            item.position = position;
            item.previous_position = position;
        }
        if (command.restart_lifetime) item.age_ticks = 0;
        try emit(s, .deflected, item, item.position, null, incoming, 0);
        s.items[index] = item;
    }
    /// Transactional fixed tick. Query failures, nonfinite arithmetic and event
    /// overflow leave tick, records and previously queued events unchanged.
    pub fn step(self: *System, query: ?collision.Query) Error!void {
        const s = self.storage();
        if (s.tick == std.math.maxInt(u64)) return error.TickExhausted;
        @memcpy(s.scratch[0..s.count], s.items[0..s.count]);
        @memcpy(s.scratch_events[0..s.event_count], s.events[0..s.event_count]);
        var staged = s.*;
        staged.items = s.scratch;
        staged.events = s.scratch_events;
        staged.tick += 1;
        var index: usize = 0;
        while (index < staged.count) {
            var item = staged.items[index];
            item.previous_position = item.position;
            if (!item.enabled) {
                staged.items[index] = item;
                index += 1;
                continue;
            }
            item.velocity = item.velocity.add(item.definition.acceleration.scale(dt));
            if (!item.velocity.isFinite()) return error.NonFiniteMotion;
            const alive = try advance(&staged, &item, query);
            if (!alive) {
                erase(&staged, index);
                continue;
            }
            item.age_ticks += 1;
            if (item.age_ticks >= item.definition.lifetime_ticks) {
                try emit(&staged, .expired, item, item.position, null, item.velocity, 1);
                erase(&staged, index);
                continue;
            }
            staged.items[index] = item;
            index += 1;
        }
        @memcpy(s.items[0..staged.count], staged.items[0..staged.count]);
        @memcpy(s.events[0..staged.event_count], staged.events[0..staged.event_count]);
        s.count = staged.count;
        s.event_count = staged.event_count;
        s.next_event = staged.next_event;
        s.tick = staged.tick;
    }
};
fn advance(s: *State, item: *Snapshot, query: ?collision.Query) Error!bool {
    var remaining: f32 = 1;
    var elapsed: f32 = 0;
    var excluded: [collision.maximum_iterations]collider.ColliderId = undefined;
    var excluded_count: usize = 0;
    for (0..item.definition.collision_iterations) |_| {
        const from = item.position;
        const to = from.add(item.velocity.scale(dt * remaining));
        if (!to.isFinite()) return error.NonFiniteMotion;
        var hit: ?collision.Hit = null;
        if (query) |q| {
            var storage: [collision.maximum_hits]collision.Hit = undefined;
            var hits = collision.Hits{ .storage = &storage };
            const sweep = collision.Sweep{ .from = from, .to = to, .half_extents = item.definition.half_extents, .layer = item.definition.layer, .mask = item.definition.mask, .source = item.source, .excluded = excluded[0..excluded_count] };
            try q.collect(q.context, sweep, &hits);
            if (hits.count > storage.len) return error.HitCapacity;
            hit = try collision.earliest(sweep, storage[0..hits.count]);
        }
        const fraction: f32 = if (hit) |h| h.fraction else 1;
        item.position = from.add(to.sub(from).scale(fraction));
        elapsed += remaining * fraction;
        if (from.x != item.position.x or from.y != item.position.y)
            try emit(s, .moved, item.*, from, null, item.velocity, elapsed);
        const contact = hit orelse return true;
        try emit(s, .collided, item.*, from, contact, item.velocity, elapsed);
        remaining *= 1 - fraction;
        switch (item.definition.response) {
            .despawn => return false,
            .continue_travel => {
                excluded[excluded_count] = contact.collider_id;
                excluded_count += 1;
            },
            .bounce => {
                const incoming = item.velocity;
                const normal = contact.normal.normalizeSafe(1e-6) catch return error.InvalidHit;
                item.velocity = incoming.sub(normal.scale(2 * incoming.dot(normal))).scale(item.definition.restitution);
                if (!item.velocity.isFinite()) return error.NonFiniteMotion;
                try emit(s, .deflected, item.*, item.position, contact, incoming, elapsed);
            },
        }
        if (remaining == 0) return true;
    }
    try emit(s, .collision_limit, item.*, item.position, null, item.velocity, elapsed);
    return true;
}
fn emit(s: *State, kind: EventKind, item: Snapshot, from: math.Vec2, hit: ?collision.Hit, incoming: math.Vec2, fraction: f32) Error!void {
    if (s.event_count == s.events.len) return error.EventCapacity;
    if (s.next_event == std.math.maxInt(u64)) return error.IdentityExhausted;
    s.events[s.event_count] = .{ .sequence = s.next_event, .tick = s.tick, .kind = kind, .projectile = item, .from = from, .hit = hit, .incoming_velocity = incoming, .step_fraction = fraction };
    s.event_count += 1;
    s.next_event += 1;
}
fn find(s: *const State, id: Id) Error!usize {
    for (s.items[0..s.count], 0..) |item, index| if (item.id.eql(id)) return index;
    return error.UnknownProjectile;
}
fn erase(s: *State, index: usize) void {
    std.mem.copyForwards(Snapshot, s.items[index .. s.count - 1], s.items[index + 1 .. s.count]);
    s.count -= 1;
}
fn validateSource(source: ?Id) Error!void {
    if (source) |id| _ = foundation.identity.EntityId.fromCanonicalBytes(id.bytes) catch return error.InvalidIdentity;
}
