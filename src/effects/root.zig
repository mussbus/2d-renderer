const std = @import("std");
const foundation = @import("foundation");
const math = @import("math");
const fixed_step = @import("fixed_step");
const art = @import("art_pack");
pub const Id = foundation.identity.EntityId;
pub const Seed = foundation.determinism.Seed128;
pub const dt: f32 = @floatCast(fixed_step.fixed_dt_seconds);
pub const generator_version = foundation.version.GeneratorVersion{ .major = 1, .minor = 0, .patch = 0 };
pub const algorithm_version = foundation.version.AlgorithmVersion{ .major = 1, .minor = 0, .patch = 0 };
pub const algorithm_name = "zig-0.16.xoshiro256plusplus.top24.v1";
const generator_text = "24f9a3ce-5076-5520-949f-0a57a3cabd21";
const algorithm_text = "b8d2af34-fb7c-5390-a655-3fbd83f70142";
const emitter_namespace_text = "8cd4a7b7-a2ab-528c-81cb-06e3703c9207";
const rate_denominator: u64 = fixed_step.simulation_hz * 1000;

pub const Definition = struct {
    burst: u32 = 0,
    /// Integer milli-particles per second. No floating-point accumulation drift.
    rate_milli: u32 = 0,
    duration_ticks: u32 = 1,
    particle_lifetime_ticks: u32 = 120,
    position_spread: math.Vec2 = .zero,
    velocity: math.Vec2 = .zero,
    velocity_spread: math.Vec2 = .zero,
    acceleration: math.Vec2 = .zero,
    drag: f32 = 0,
    rotation: f32 = 0,
    angular_velocity: f32 = 0,
    start_size: math.Vec2 = .{ .x = 0.1, .y = 0.1 },
    end_size: math.Vec2 = .zero,
    start_opacity: f32 = 1,
    end_opacity: f32 = 0,
    start_color: [3]f32 = .{ 1, 1, 1 },
    end_color: [3]f32 = .{ 1, 1, 1 },
    sprite: art.AtlasRegionId = @enumFromInt(1),
    layer: i16 = 0,
    pub fn validate(self: Definition) Error!void {
        if (self.burst > 4096 or self.rate_milli > rate_denominator * 1024 or
            self.duration_ticks == 0 or self.duration_ticks > 1000000 or
            self.particle_lifetime_ticks == 0 or self.particle_lifetime_ticks > 1000000 or
            !bounded(self.position_spread) or !nonnegative(self.position_spread) or
            !bounded(self.velocity) or !bounded(self.velocity_spread) or !nonnegative(self.velocity_spread) or
            !bounded(self.acceleration) or !bounded(self.start_size) or !nonnegative(self.start_size) or
            !bounded(self.end_size) or !nonnegative(self.end_size) or
            !scalar(self.drag) or self.drag < 0 or !scalar(self.rotation) or !scalar(self.angular_velocity) or
            !unit(self.start_opacity) or !unit(self.end_opacity) or @intFromEnum(self.sprite) == 0)
            return error.InvalidDefinition;
        for (self.start_color ++ self.end_color) |value| if (!unit(value)) return error.InvalidDefinition;
    }
};
pub const Spawn = struct { id: Id, definition: Definition, position: math.Vec2 };
pub const EmitterSnapshot = struct {
    effect_id: Id,
    emitter_id: Id,
    definition: Definition,
    position: math.Vec2,
    age_ticks: u32 = 0,
    emitting: bool = true,
    remainder: u64 = 0,
    emitted: u64 = 0,
};
pub const ParticleSnapshot = struct {
    effect_id: Id,
    emitter_id: Id,
    ordinal: u64,
    previous_position: math.Vec2,
    position: math.Vec2,
    velocity: math.Vec2,
    previous_rotation: f32,
    rotation: f32,
    age_ticks: u32,
    definition: Definition,
};
pub const RenderInstance = struct {
    effect_id: Id,
    ordinal: u64,
    position: math.Vec2,
    rotation: f32,
    size: math.Vec2,
    color: [4]f32,
    sprite: art.AtlasRegionId,
    layer: i16,
};
pub const Metrics = struct { dropped_particles: u64 = 0, rejected_emitters: u64 = 0, peak_particles: usize = 0, peak_emitters: usize = 0 };
pub const Config = struct { emitter_capacity: usize = 128, particle_capacity: usize = 2048, seed: Seed };
pub const Error = error{ OutOfMemory, InvalidCapacity, InvalidDefinition, InvalidSpawn, InvalidIdentity, DuplicateEffect, EmitterCapacity, UnknownEffect, SnapshotCapacity, InvalidInterpolation, TickExhausted };
const Emitter = struct { snapshot: EmitterSnapshot, rng: std.Random.Xoshiro256 };
const State = struct {
    allocator: std.mem.Allocator,
    seed: Seed,
    emitters: []Emitter,
    particles: []ParticleSnapshot,
    emitter_count: usize = 0,
    particle_count: usize = 0,
    tick: u64 = 0,
    metrics: Metrics = .{},
};
pub const System = struct {
    opaque_context: *const anyopaque,
    fn storage(self: *const System) *State {
        return @ptrCast(@alignCast(@constCast(self.opaque_context)));
    }
    pub fn init(allocator: std.mem.Allocator, config: Config) Error!System {
        if (config.emitter_capacity == 0 or config.emitter_capacity > 4096 or config.particle_capacity == 0 or config.particle_capacity > 65536) return error.InvalidCapacity;
        const state = try allocator.create(State);
        errdefer allocator.destroy(state);
        const emitters = try allocator.alloc(Emitter, config.emitter_capacity);
        errdefer allocator.free(emitters);
        const particles = try allocator.alloc(ParticleSnapshot, config.particle_capacity);
        state.* = .{ .allocator = allocator, .seed = config.seed, .emitters = emitters, .particles = particles };
        return .{ .opaque_context = state };
    }
    pub fn deinit(self: *System) void {
        const s = self.storage();
        const allocator = s.allocator;
        allocator.free(s.particles);
        allocator.free(s.emitters);
        allocator.destroy(s);
        self.* = undefined;
    }
    pub fn particleCount(self: *const System) usize {
        return self.storage().particle_count;
    }
    pub fn emitterCount(self: *const System) usize {
        return self.storage().emitter_count;
    }
    pub fn metrics(self: *const System) Metrics {
        return self.storage().metrics;
    }
    pub fn tick(self: *const System) u64 {
        return self.storage().tick;
    }
    pub fn emitter(self: *const System, id: Id) ?EmitterSnapshot {
        for (self.storage().emitters[0..self.storage().emitter_count]) |value| if (value.snapshot.effect_id.eql(id)) return value.snapshot;
        return null;
    }
    pub fn copyParticles(self: *const System, output: []ParticleSnapshot) Error![]const ParticleSnapshot {
        if (output.len < self.storage().particle_count) return error.SnapshotCapacity;
        @memcpy(output[0..self.storage().particle_count], self.storage().particles[0..self.storage().particle_count]);
        return output[0..self.storage().particle_count];
    }
    /// New effect IDs must be unique for the host's replay session. Reuse after
    /// a complete reset is explicit. No unbounded tombstone history is kept.
    pub fn spawn(self: *System, request: Spawn) Error!Id {
        try request.definition.validate();
        if (!bounded(request.position)) return error.InvalidSpawn;
        _ = Id.fromCanonicalBytes(request.id.bytes) catch return error.InvalidIdentity;
        if (self.emitter(request.id) != null) return error.DuplicateEffect;
        const s = self.storage();
        if (s.emitter_count == s.emitters.len) {
            s.metrics.rejected_emitters +|= 1;
            return error.EmitterCapacity;
        }
        const namespace = foundation.identity.NamespaceId.parseCanonical(emitter_namespace_text) catch return error.InvalidIdentity;
        const emitter_id = foundation.identity.uuidV5Fields(Id, namespace, &.{ "e.emitter.v1", &request.id.bytes }) catch return error.InvalidIdentity;
        const context = foundation.determinism.DerivationContext{
            .root_seed = s.seed,
            .generator_id = foundation.identity.GeneratorId.parseCanonical(generator_text) catch return error.InvalidIdentity,
            .generator_version = generator_version,
            .algorithm_id = foundation.identity.AlgorithmId.parseCanonical(algorithm_text) catch return error.InvalidIdentity,
            .algorithm_version = algorithm_version,
        };
        const key = foundation.determinism.deriveKey(context, &.{ &request.id.bytes, &emitter_id.bytes }) catch return error.InvalidIdentity;
        var value = Emitter{ .snapshot = .{ .effect_id = request.id, .emitter_id = emitter_id, .definition = request.definition, .position = request.position }, .rng = std.Random.Xoshiro256.init(std.mem.readInt(u64, key[0..8], .big)) };
        // Stable identity order, including simultaneous continuous emissions.
        var index = s.emitter_count;
        while (index > 0 and request.id.byteOrder(s.emitters[index - 1].snapshot.effect_id) == .lt) : (index -= 1) s.emitters[index] = s.emitters[index - 1];
        emitParticles(s, &value, request.definition.burst);
        s.emitters[index] = value;
        s.emitter_count += 1;
        s.metrics.peak_emitters = @max(s.metrics.peak_emitters, s.emitter_count);
        return emitter_id;
    }
    pub fn setPosition(self: *System, id: Id, position: math.Vec2) Error!void {
        if (!bounded(position)) return error.InvalidSpawn;
        const index = try find(self.storage(), id);
        self.storage().emitters[index].snapshot.position = position;
    }
    /// Stops future emissions; existing world-space particles drain naturally.
    pub fn stop(self: *System, id: Id) Error!void {
        const index = try find(self.storage(), id);
        self.storage().emitters[index].snapshot.emitting = false;
    }
    pub fn clear(self: *System, id: Id) Error!void {
        const s = self.storage();
        const index = try find(s, id);
        var write: usize = 0;
        for (s.particles[0..s.particle_count]) |particle| {
            if (!particle.effect_id.eql(id)) {
                s.particles[write] = particle;
                write += 1;
            }
        }
        s.particle_count = write;
        eraseEmitter(s, index);
    }
    pub fn reset(self: *System, seed: Seed) void {
        const s = self.storage();
        s.seed = seed;
        s.emitter_count = 0;
        s.particle_count = 0;
        s.tick = 0;
        s.metrics = .{};
    }
    /// Existing particles age/move before this tick's continuous emission.
    /// Saturation drops newest emissions while consuming their exact RNG draws.
    pub fn step(self: *System) Error!void {
        const s = self.storage();
        if (s.tick == std.math.maxInt(u64)) return error.TickExhausted;
        s.tick += 1;
        var write: usize = 0;
        for (s.particles[0..s.particle_count]) |initial| {
            var particle = initial;
            particle.age_ticks += 1;
            if (particle.age_ticks >= particle.definition.particle_lifetime_ticks) continue;
            particle.previous_position = particle.position;
            particle.previous_rotation = particle.rotation;
            particle.velocity = particle.velocity.add(particle.definition.acceleration.scale(dt)).scale(1 / (1 + particle.definition.drag * dt));
            particle.position = particle.position.add(particle.velocity.scale(dt));
            particle.rotation += particle.definition.angular_velocity * dt;
            s.particles[write] = particle;
            write += 1;
        }
        s.particle_count = write;
        var index: usize = 0;
        while (index < s.emitter_count) {
            const value = &s.emitters[index];
            if (value.snapshot.emitting) {
                value.snapshot.remainder += value.snapshot.definition.rate_milli;
                const count: u32 = @intCast(value.snapshot.remainder / rate_denominator);
                value.snapshot.remainder %= rate_denominator;
                emitParticles(s, value, count);
                value.snapshot.age_ticks += 1;
                if (value.snapshot.age_ticks >= value.snapshot.definition.duration_ticks) value.snapshot.emitting = false;
            }
            var living = false;
            if (!value.snapshot.emitting) {
                for (s.particles[0..s.particle_count]) |particle| if (particle.effect_id.eql(value.snapshot.effect_id)) {
                    living = true;
                    break;
                };
                if (!living) {
                    eraseEmitter(s, index);
                    continue;
                }
            }
            index += 1;
        }
    }
    /// Caller owns output. Alpha interpolates completed states for rendering
    /// only; output is ordered by effect UUID then particle ordinal.
    pub fn extract(self: *const System, output: []RenderInstance, alpha: f32) Error![]const RenderInstance {
        if (!unit(alpha)) return error.InvalidInterpolation;
        const s = self.storage();
        if (output.len < s.particle_count) return error.SnapshotCapacity;
        var count: usize = 0;
        for (s.emitters[0..s.emitter_count]) |value| {
            for (s.particles[0..s.particle_count]) |particle| {
                if (!particle.effect_id.eql(value.snapshot.effect_id)) continue;
                const def = particle.definition;
                const age: f32 = if (particle.age_ticks == 0) 0 else @as(f32, @floatFromInt(particle.age_ticks - 1)) + alpha;
                const t = age / @as(f32, @floatFromInt(def.particle_lifetime_ticks));
                var color: [4]f32 = undefined;
                for (0..3) |channel| color[channel] = math.interpolation.lerpScalar(def.start_color[channel], def.end_color[channel], t) catch return error.InvalidInterpolation;
                color[3] = math.interpolation.lerpScalar(def.start_opacity, def.end_opacity, t) catch return error.InvalidInterpolation;
                output[count] = .{
                    .effect_id = particle.effect_id,
                    .ordinal = particle.ordinal,
                    .position = math.interpolation.lerpVec2(particle.previous_position, particle.position, alpha) catch return error.InvalidInterpolation,
                    .rotation = math.interpolation.lerpScalar(particle.previous_rotation, particle.rotation, alpha) catch return error.InvalidInterpolation,
                    .size = math.interpolation.lerpVec2(def.start_size, def.end_size, t) catch return error.InvalidInterpolation,
                    .color = color,
                    .sprite = def.sprite,
                    .layer = def.layer,
                };
                count += 1;
            }
        }
        return output[0..count];
    }
};
fn emitParticles(s: *State, emitter: *Emitter, count: u32) void {
    const def = emitter.snapshot.definition;
    for (0..count) |_| {
        const position = emitter.snapshot.position.add(.{ .x = signed(&emitter.rng) * def.position_spread.x, .y = signed(&emitter.rng) * def.position_spread.y });
        const velocity = def.velocity.add(.{ .x = signed(&emitter.rng) * def.velocity_spread.x, .y = signed(&emitter.rng) * def.velocity_spread.y });
        const ordinal = emitter.snapshot.emitted;
        emitter.snapshot.emitted += 1;
        if (s.particle_count == s.particles.len) {
            s.metrics.dropped_particles +|= 1;
            continue;
        }
        s.particles[s.particle_count] = .{ .effect_id = emitter.snapshot.effect_id, .emitter_id = emitter.snapshot.emitter_id, .ordinal = ordinal, .previous_position = position, .position = position, .velocity = velocity, .previous_rotation = def.rotation, .rotation = def.rotation, .age_ticks = 0, .definition = def };
        s.particle_count += 1;
        s.metrics.peak_particles = @max(s.metrics.peak_particles, s.particle_count);
    }
}
fn signed(rng: *std.Random.Xoshiro256) f32 {
    const sample: u24 = @truncate(rng.next() >> 40);
    return @as(f32, @floatFromInt(sample)) * (2.0 / 16777216.0) - 1;
}
fn find(s: *const State, id: Id) Error!usize {
    for (s.emitters[0..s.emitter_count], 0..) |value, index| if (value.snapshot.effect_id.eql(id)) return index;
    return error.UnknownEffect;
}
fn eraseEmitter(s: *State, index: usize) void {
    std.mem.copyForwards(Emitter, s.emitters[index .. s.emitter_count - 1], s.emitters[index + 1 .. s.emitter_count]);
    s.emitter_count -= 1;
}
fn scalar(value: f32) bool {
    return std.math.isFinite(value) and @abs(value) <= 1000000;
}
fn bounded(value: math.Vec2) bool {
    return scalar(value.x) and scalar(value.y);
}
fn nonnegative(value: math.Vec2) bool {
    return value.x >= 0 and value.y >= 0;
}
fn unit(value: f32) bool {
    return std.math.isFinite(value) and value >= 0 and value <= 1;
}
