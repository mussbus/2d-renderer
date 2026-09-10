const std = @import("std");
const foundation = @import("foundation");
const math = @import("math");
const controller_module = @import("character_controller");
const sweep = @import("collision_world").static_sweep;
pub const e = @import("effects");
pub const content = @import("collectible_content.zig");
pub const emitter_capacity = 6;
pub const particle_capacity = 72;
pub const Phase = enum { idle, active, reaction, complete };
pub const Segment = enum { horizontal, vertical };
pub const Contact = struct { segment: Segment, contact: sweep.Contact };
pub const Collected = struct { run: u64, spawn_id: content.SpawnId, ordinal: u8, tick: u64, position: math.Vec2, segment: Segment };

/// Borrow only the completed physical controller. Its resolved path is X then Y.
pub fn query(controller: controller_module.CharacterController, target: content.Spawn) !?Contact {
    const previous = controller.state.previous_position;
    const current = controller.state.position;
    const corner = math.Vec2{ .x = current.x, .y = previous.y };
    const half = controller.configuration.collider_half_extents;
    const bounds = try target.bounds();
    if (try sweep.query(.{ .from = previous, .to = corner, .half_extents = half }, bounds)) |hit| return .{ .segment = .horizontal, .contact = hit };
    if (try sweep.query(.{ .from = corner, .to = current, .half_extents = half }, bounds)) |hit| return .{ .segment = .vertical, .contact = hit };
    return null;
}

pub const Challenge = struct {
    effects: e.System,
    phase: Phase = .idle,
    run: u64 = 0,
    progress: u8 = 0,
    born_tick: u64 = 0,
    reaction_remaining: u8 = 0,
    pending_start: bool = false,
    last: ?Collected = null,
    observations: [content.spawns.len]Collected = undefined,
    effect_ids: [emitter_capacity]?e.Id = @splat(null),

    pub fn init(allocator: std.mem.Allocator, seed: e.Seed, half: math.Vec2) !Challenge {
        try content.validate(&content.spawns, &@import("layout.zig").expanded_colliders, half);
        return .{ .effects = try e.System.init(allocator, .{ .seed = seed, .emitter_capacity = emitter_capacity, .particle_capacity = particle_capacity }) };
    }
    pub fn deinit(self: *Challenge) void {
        self.effects.deinit();
        self.* = undefined;
    }
    pub fn requestStart(self: *Challenge) void {
        if (self.phase == .idle or self.phase == .complete) self.pending_start = true;
    }
    pub fn activeTarget(self: *const Challenge) ?content.Spawn {
        return if (self.phase == .active) content.spawns[self.progress] else null;
    }
    pub fn advanceParticles(self: *Challenge, tick: u64) !void {
        if (tick == 0 or self.effects.tick() != tick - 1) return error.CollectionTickMismatch;
        try self.effects.step();
    }
    /// Exactly one transition. A birth cannot fall through into contact work.
    pub fn transition(self: *Challenge, controller: controller_module.CharacterController, tick: u64) !?Collected {
        if (self.effects.tick() != tick) return error.CollectionTickMismatch;
        self.last = null;
        const start = self.pending_start;
        self.pending_start = false;
        if (start and (self.phase == .idle or self.phase == .complete)) {
            const next_run = try std.math.add(u64, self.run, 1);
            for (self.effect_ids) |maybe| if (maybe) |id| {
                if (self.effects.emitter(id) != null) try self.effects.clear(id);
            };
            self.effect_ids = @splat(null);
            self.run = next_run;
            self.progress = 0;
            self.reaction_remaining = 0;
            self.born_tick = tick;
            self.phase = .active;
            return null;
        }
        switch (self.phase) {
            .idle, .complete => return null,
            .reaction => {
                if (self.reaction_remaining == 0) return error.CollectionReactionInvariant;
                self.reaction_remaining -= 1;
                if (self.reaction_remaining == 0) {
                    self.phase = if (self.progress == content.spawns.len) .complete else .active;
                    self.born_tick = tick;
                }
                return null;
            },
            .active => {
                if (tick <= self.born_tick) return null;
                const target = self.activeTarget() orelse return error.CollectionTargetInvariant;
                const hit = try query(controller, target) orelse return null;
                const event = Collected{ .run = self.run, .spawn_id = target.id, .ordinal = self.progress + 1, .tick = tick, .position = target.position, .segment = hit.segment };
                self.observations[self.progress] = event;
                self.progress += 1;
                self.phase = .reaction;
                self.reaction_remaining = content.reaction_ticks;
                self.last = event;
                return event;
            },
        }
    }
    pub fn emit(self: *Challenge, event: Collected) !void {
        if (event.run != self.run or event.ordinal != self.progress or event.tick != self.effects.tick() or self.phase != .reaction) return error.CollectionObservationMismatch;
        const id = try effectId(event.run, event.ordinal);
        _ = try self.effects.spawn(.{ .id = id, .definition = content.reaction, .position = event.position });
        self.effect_ids[event.ordinal - 1] = id;
        const metrics = self.effects.metrics();
        if (metrics.dropped_particles != 0 or metrics.rejected_emitters != 0) return error.CollectionCapacityExceeded;
    }
    /// Bounded diagnostic of challenge state, observations and particle ages/positions.
    /// Excludes presentation and fixed-clock residue; it is not a replay protocol.
    pub fn fingerprint(self: *const Challenge) !foundation.canonical_data.Sha256Digest {
        var bytes: [32768]u8 = undefined;
        var writer = foundation.canonical_data.Writer.init(&bytes);
        try writer.u64Value(@intFromEnum(self.phase));
        for ([_]u64{ self.run, self.progress, self.born_tick, self.reaction_remaining, self.effects.tick(), @intFromBool(self.pending_start) }) |value| {
            try writer.byte(',');
            try writer.u64Value(value);
        }
        for (self.observations[0..self.progress]) |event| {
            for ([_]u64{ event.run, @intFromEnum(event.spawn_id), event.ordinal, event.tick, @intFromEnum(event.segment) }) |value| {
                try writer.byte(',');
                try writer.u64Value(value);
            }
        }
        var particles: [particle_capacity]e.ParticleSnapshot = undefined;
        for (try self.effects.copyParticles(&particles)) |p| {
            try writer.byte(',');
            try writer.raw(&p.effect_id.bytes);
            try writer.u64Value(p.ordinal);
            try writer.byte(',');
            try writer.u64Value(p.age_ticks);
            for ([_]f32{ p.position.x, p.position.y, p.velocity.x, p.velocity.y }) |value| {
                try writer.byte(',');
                try writer.u64Value(@as(u32, @bitCast(value)));
            }
        }
        return foundation.canonical_data.hashDomainSeparated("engine_lab.collection.observations.v1", &.{writer.bytes()});
    }
};

pub fn effectId(run: u64, ordinal: u8) !e.Id {
    if (run == 0 or ordinal == 0 or ordinal > content.spawns.len) return error.CollectionIdentity;
    const namespace = try foundation.identity.NamespaceId.parseCanonical("c7cd2000-0771-5a66-b205-90e5e0121f06");
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, run, .big);
    return foundation.identity.uuidV5Fields(e.Id, namespace, &.{ "engine_lab.collection.v1", &bytes, &.{ordinal} });
}
