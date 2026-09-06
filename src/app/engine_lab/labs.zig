const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const fixed_step = @import("fixed_step");
const spring = @import("spring");
const math = @import("math");

pub const Seed = foundation.determinism.Seed128;
pub const Digest = foundation.canonical_data.Sha256Digest;
pub const default_seed = "0123456789abcdef0123456789abcdef";
pub const checkpoint_ticks = [_]u64{ 0, 240, 480, 960 };
pub const mass_count = 3;
pub const Kind = enum { integration, determinism };

pub const Definition = struct {
    kind: Kind,
    id: []const u8,
    name: []const u8,
    description: []const u8,
    damping: [mass_count]f32,
    scripted_impulse_ticks: u64,
};

/// Registration order and identifiers are versioned application contracts.
/// Array order is intentional; discovery and hash-map iteration are not used.
pub const registry = [_]Definition{
    .{
        .kind = .integration,
        .id = "integration-overview",
        .name = "INTEGRATION OVERVIEW",
        .description = "F scene hierarchy + seeded spring offsets + interpolated instanced sprites",
        .damping = .{ 1.2, 3.0, 7.0 },
        .scripted_impulse_ticks = 480,
    },
    .{
        .kind = .determinism,
        .id = "determinism-fixed-step",
        .name = "DETERMINISM / FIXED STEP",
        .description = "Repeat 960 ticks at 240 Hz; compare checkpoints across frame schedules",
        .damping = .{ 0.5, 4.0, 12.0 },
        .scripted_impulse_ticks = 360,
    },
};

pub fn findDefinition(id: []const u8) error{UnknownLab}!usize {
    for (registry, 0..) |definition, index| {
        if (std.mem.eql(u8, id, definition.id)) return index;
    }
    return error.UnknownLab;
}

pub const Context = struct {
    allocator: std.mem.Allocator,
};

pub const Anchor = struct {
    id: foundation.identity.EntityId,
    world: math.Vec2,
};

/// Owns one live F scene. Only its immutable, copied anchor observations cross
/// into frame work. No snapshot lease or pointer into scene storage survives init.
pub const AnchorScene = struct {
    scene: scene_core.runtime_scene.RuntimeScene,
    root: Anchor,
    anchors: [mass_count]Anchor,

    pub fn init(allocator: std.mem.Allocator) !AnchorScene {
        var scene = try scene_core.runtime_scene.RuntimeScene.init(allocator, .{
            .registry = .{
                .initial_entity_capacity = 4,
                .hard_entity_capacity = 4,
                .initial_mapping_capacity = 4,
                .hard_mapping_capacity = 4,
            },
            .initial_level_capacity = 1,
            .hard_level_capacity = 1,
            .max_snapshot_leases = 1,
        });
        errdefer scene.deinit() catch |err| cleanupFailure(err);
        const ids = [_][]const u8{
            "019a1800-1000-7000-8000-000000000001",
            "019a1800-1000-7000-8000-000000000002",
            "019a1800-1000-7000-8000-000000000003",
            "019a1800-1000-7000-8000-000000000004",
        };
        var handles: [4]foundation.identity.EntityHandle = undefined;
        var persistent: [4]foundation.identity.EntityId = undefined;
        for (ids, 0..) |text, index| {
            persistent[index] = try foundation.identity.EntityId.parseCanonical(text);
            const translation: foundation.spatial.LocalTransform = .{
                .translation = .{
                    .x = if (index == 0) 0 else (@as(f32, @floatFromInt(index)) - 2) * 1.8,
                    .y = if (index == 0) 2.8 else -0.4,
                    .z = 0,
                },
                .rotation = .identity,
                .scale = .one,
            };
            handles[index] = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
                .owner = .{ .physics_gameplay = null },
                .parent = if (index == 0) null else handles[0],
                .local_transform = translation,
                .enabled = .enabled,
                .resolver = .{ .context = null, .resolve_fn = rejectAsset },
            });
            try scene.promoteTemporary(.{ .authority = .physics_gameplay }, handles[index], persistent[index]);
        }
        var snapshot = try scene.acquireSnapshot(.{
            .tick = 0,
            .fixed_delta_seconds = @floatCast(fixed_step.fixed_dt_seconds),
            .interpolation_alpha = 0,
        });
        defer snapshot.deinit();
        const view = snapshot.view();
        if (view.entityCount() != 4) return error.AnchorSceneEntityCount;
        var observed: [4]Anchor = undefined;
        for (handles, 0..) |handle, index| {
            const entity = try view.get(handle);
            const resolved = view.resolve(persistent[index]) orelse return error.AnchorIdentityMissing;
            if (!resolved.eql(handle) or !entity.effective_enabled) return error.AnchorIdentityMismatch;
            const affine = entity.world_transform.affine;
            try affine.validate();
            observed[index] = .{ .id = persistent[index], .world = .{
                .x = affine.translation.x,
                .y = affine.translation.y,
            } };
        }
        return .{ .scene = scene, .root = observed[0], .anchors = observed[1..4].* };
    }

    pub fn deinit(self: *AnchorScene) !void {
        try self.scene.deinit();
        self.* = undefined;
    }
};

fn rejectAsset(_: ?*anyopaque, _: foundation.reference.AssetRef) anyerror!scene_core.runtime_asset.ResolvedAssetToken {
    return error.EngineLabHasNoAssetReferences;
}

fn cleanupFailure(err: anyerror) noreturn {
    std.debug.panic("Engine Lab scene cleanup violated lifetime contract: {s}", .{@errorName(err)});
}

pub const Checkpoint = struct { tick: u64, digest: Digest };

pub const Session = struct {
    definition_index: usize,
    seed: Seed,
    anchors: AnchorScene,
    configurations: [mass_count]spring.Configuration,
    springs: [mass_count]spring.State,
    previous_offsets: [mass_count]f32,
    tick: u64 = 0,
    checkpoint_count: usize = 0,
    checkpoints: [checkpoint_ticks.len]Checkpoint = undefined,
    // Bounded presentation history: sampled at 60 Hz, never read by simulation.
    history: [240][mass_count]f32 = @splat(@splat(0)),
    history_count: usize = 0,
    history_next: usize = 0,

    pub fn init(context: Context, definition_index: usize, seed: Seed) !Session {
        if (definition_index >= registry.len) return error.UnknownLab;
        var anchors = try AnchorScene.init(context.allocator);
        errdefer anchors.deinit() catch |err| cleanupFailure(err);
        const descriptor = registry[definition_index];
        var states: [mass_count]spring.State = undefined;
        var configurations: [mass_count]spring.Configuration = undefined;
        var previous: [mass_count]f32 = undefined;
        for (0..mass_count) |index| {
            configurations[index] = .{
                .stiffness = 24,
                .damping = descriptor.damping[index],
                .maximum_displacement = 0.65,
                .maximum_velocity = 6,
            };
            // Each initial offset is keyed by stable F identity and lab ID.
            const key = try foundation.canonical_data.hashDomainSeparated(
                "engine_lab.initial_offset.v1",
                &.{ &seed.bytes, descriptor.id, &anchors.anchors[index].id.bytes },
            );
            const offset = 0.25 + @as(f32, @floatFromInt(key.bytes[0])) * (0.35 / 255.0);
            states[index] = try spring.State.init(configurations[index], @floatCast(fixed_step.fixed_dt_seconds), offset, 0, 0);
            previous[index] = offset;
        }
        var result = Session{
            .definition_index = definition_index,
            .seed = seed,
            .anchors = anchors,
            .configurations = configurations,
            .springs = states,
            .previous_offsets = previous,
        };
        try result.recordCheckpoint();
        return result;
    }

    pub fn deinit(self: *Session) !void {
        try self.anchors.deinit();
        self.* = undefined;
    }

    pub fn definition(self: *const Session) Definition {
        return registry[self.definition_index];
    }

    pub fn complete(self: *const Session) bool {
        return self.definition().kind == .determinism and self.tick >= checkpoint_ticks[checkpoint_ticks.len - 1];
    }

    pub fn fixedUpdate(self: *Session, manual_impulse: bool) !void {
        if (self.complete()) return error.ScenarioAlreadyComplete;
        self.tick = try std.math.add(u64, self.tick, 1);
        const scripted = self.tick % self.definition().scripted_impulse_ticks == 0;
        for (&self.springs, self.configurations, 0..) |*state, configuration, index| {
            self.previous_offsets[index] = state.offset;
            // Manual input is deliberately disabled for the repeatable experiment.
            if (scripted or (manual_impulse and self.definition().kind == .integration)) {
                try state.applyVelocityImpulse(-2.5, configuration);
            }
            try state.step(configuration, @floatCast(fixed_step.fixed_dt_seconds));
        }
        if (self.tick % 4 == 0) {
            for (self.springs, 0..) |state, index| self.history[self.history_next][index] = state.offset;
            self.history_next = (self.history_next + 1) % self.history.len;
            self.history_count = @min(self.history_count + 1, self.history.len);
        }
        if (self.checkpoint_count < checkpoint_ticks.len and self.tick == checkpoint_ticks[self.checkpoint_count]) {
            try self.recordCheckpoint();
        }
    }

    pub fn offsets(self: *const Session, alpha: f64) ![mass_count]f32 {
        var result: [mass_count]f32 = undefined;
        for (self.springs, self.previous_offsets, 0..) |state, previous, index| {
            result[index] = try fixed_step.interpolateScalar(previous, state.offset, alpha);
        }
        return result;
    }

    pub fn fingerprint(self: *const Session) !Digest {
        var output: [4096]u8 = undefined;
        var writer = foundation.canonical_data.Writer.init(&output);
        // Sorted object keys, stable anchor-array order, normalized finite f32s.
        // No pointers, runtime handles, padding, clock residue or UI state.
        try writer.raw("{\"anchors\":[");
        for (self.anchors.anchors, 0..) |anchor, index| {
            if (index != 0) try writer.byte(',');
            try writer.raw("{\"id\":");
            try writer.uuidValue(anchor.id.bytes);
            try writer.raw(",\"x\":");
            try writer.f32Value(anchor.world.x);
            try writer.raw(",\"y\":");
            try writer.f32Value(anchor.world.y);
            try writer.byte('}');
        }
        try writer.raw("],\"fixed_hz\":");
        try writer.u64Value(fixed_step.simulation_hz);
        try writer.raw(",\"impulse_period\":");
        try writer.u64Value(self.definition().scripted_impulse_ticks);
        try writer.raw(",\"lab\":");
        try writer.jsonString(self.definition().id);
        try writer.raw(",\"schema\":1,\"seed\":");
        try writer.jsonString(&self.seed.formatLowerHex());
        try writer.raw(",\"springs\":[");
        for (self.springs, self.configurations, 0..) |state, configuration, index| {
            if (index != 0) try writer.byte(',');
            try writer.raw("{\"damping\":");
            try writer.f32Value(configuration.damping);
            try writer.raw(",\"maximum_displacement\":");
            try writer.f32Value(configuration.maximum_displacement);
            try writer.raw(",\"maximum_velocity\":");
            try writer.f32Value(configuration.maximum_velocity);
            try writer.raw(",\"offset\":");
            try writer.f32Value(state.offset);
            try writer.raw(",\"previous_offset\":");
            try writer.f32Value(self.previous_offsets[index]);
            try writer.raw(",\"stiffness\":");
            try writer.f32Value(configuration.stiffness);
            try writer.raw(",\"target_offset\":");
            try writer.f32Value(state.target_offset);
            try writer.raw(",\"velocity\":");
            try writer.f32Value(state.velocity);
            try writer.byte('}');
        }
        try writer.raw("],\"tick\":");
        try writer.u64Value(self.tick);
        try writer.byte('}');
        return foundation.canonical_data.hashDomainSeparated("engine_lab.state.v1", &.{writer.bytes()});
    }

    fn recordCheckpoint(self: *Session) !void {
        self.checkpoints[self.checkpoint_count] = .{ .tick = self.tick, .digest = try self.fingerprint() };
        self.checkpoint_count += 1;
    }
};

pub const LifecycleEvent = enum { initialized, shutdown };
pub const LifecycleObserver = struct {
    context: *anyopaque,
    notify: *const fn (*anyopaque, LifecycleEvent, Kind) void,
};

/// Session addresses remain stable, and failed construction leaves the old lab
/// live. Reset/switch/shutdown are explicit allocation boundaries.
pub const Host = struct {
    context: Context,
    active: ?*Session = null,
    clock: fixed_step.Clock,
    seed: Seed,
    observer: ?LifecycleObserver,
    pending_impulse: bool = false,

    pub fn init(context: Context, index: usize, seed: Seed, observer: ?LifecycleObserver) !Host {
        var host = Host{
            .context = context,
            .clock = try fixed_step.Clock.init(.{}),
            .seed = seed,
            .observer = observer,
        };
        try host.switchTo(index);
        return host;
    }

    pub fn deinit(self: *Host) !void {
        if (self.active) |active| {
            const kind = active.definition().kind;
            try active.deinit();
            self.context.allocator.destroy(active);
            self.active = null;
            self.emit(.shutdown, kind);
        }
        self.pending_impulse = false;
    }

    pub fn switchTo(self: *Host, index: usize) !void {
        const candidate = try self.context.allocator.create(Session);
        errdefer self.context.allocator.destroy(candidate);
        candidate.* = try Session.init(self.context, index, self.seed);
        errdefer candidate.deinit() catch |err| cleanupFailure(err);
        if (self.active) |previous| {
            const kind = previous.definition().kind;
            try previous.deinit();
            self.context.allocator.destroy(previous);
            self.emit(.shutdown, kind);
        }
        self.active = candidate;
        self.clock.reset();
        self.clock.setPaused(true);
        self.pending_impulse = false;
        self.emit(.initialized, candidate.definition().kind);
    }

    pub fn reset(self: *Host) !void {
        const active = self.active orelse return error.NoActiveLab;
        try self.switchTo(active.definition_index);
    }

    pub fn advanceFrame(self: *Host, delta_seconds: f64) !void {
        const active = self.active orelse return error.NoActiveLab;
        if (active.complete()) {
            self.clock.setPaused(true);
            self.pending_impulse = false;
        }
        const metrics = try self.clock.beginFrame(delta_seconds);
        for (0..metrics.substeps) |_| {
            if (active.complete()) break;
            try active.fixedUpdate(self.pending_impulse);
            self.pending_impulse = false;
        }
        if (active.complete()) self.clock.setPaused(true);
    }

    fn emit(self: *Host, event: LifecycleEvent, kind: Kind) void {
        if (self.observer) |observer| observer.notify(observer.context, event, kind);
    }
};

/// Permanent headless integration proof used by CLI and tests. No SDL required.
pub fn verifyRepeat(context: Context, seed: Seed) ![checkpoint_ticks.len]Checkpoint {
    var host = try Host.init(context, try findDefinition("determinism-fixed-step"), seed, null);
    defer host.deinit() catch |err| cleanupFailure(err);
    host.clock.setPaused(false);
    while (!host.active.?.complete()) try host.advanceFrame(1.0 / 60.0);
    const expected = host.active.?.checkpoints;
    try host.reset();
    host.clock.setPaused(false);
    var frame: usize = 0;
    const schedule = [_]f64{ 1.0 / 240.0, 3.0 / 240.0, 1.0 / 120.0 };
    while (!host.active.?.complete()) : (frame += 1) {
        try host.advanceFrame(schedule[frame % schedule.len]);
    }
    for (expected, host.active.?.checkpoints) |left, right| {
        if (left.tick != right.tick or !left.digest.eql(right.digest)) return error.DeterministicCheckpointMismatch;
    }
    return expected;
}
