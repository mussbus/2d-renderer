//! One-tick application adapter. Playback has no course-generator dependency.
const std = @import("std");
pub const schema = @import("engine_lab_replay_schema");
pub const state = @import("engine_lab_replay_state");
const rr = schema.rr;
const lab = schema.lab;
const fixed = @import("fixed_step");
pub const Control = enum { wait, run_one, single_step };
pub const Result = enum { waiting, stepped, finished };
pub const Stage = enum { preflight, delivery, execution, postcondition, observation, capture, append, verification, checkpoint, finish };
pub const Failure = struct {
    record: u64,
    stage: Stage,
    cause: anyerror,
    capture_error: ?anyerror = null,
    checkpoint_error: ?anyerror = null,
    verification_completed: bool = false,
};
pub const Mode = enum { recording, playback };

/// Sole owner. Do not mutate its Hub or owned Session while running.
/// Public values permit inspection; borrowed const views expire before the next call.
pub const Adapter = struct {
    allocator: std.mem.Allocator,
    hub: *lab.Hub,
    scratch: *state.Scratch,
    session: *rr.Session,
    player: ?*rr.Player = null,
    mode: Mode,
    artifact: []u8,
    content: rr.Digest,
    initial: rr.Digest,
    last: rr.Digest,
    emitted_names: u16 = 0,
    failure: ?Failure = null,
    finished: bool = false,
    ever_live: bool = false,
    counts: [4]u32 = @splat(0),

    pub fn initRecording(allocator: std.mem.Allocator) !*Adapter {
        return init(allocator, null);
    }
    pub fn initPlayback(allocator: std.mem.Allocator, bytes: []const u8) !*Adapter {
        if (bytes.len > schema.artifact_capacity) return error.ArtifactCapacity;
        return init(allocator, bytes);
    }
    fn init(allocator: std.mem.Allocator, serialized: ?[]const u8) !*Adapter {
        const self = try allocator.create(Adapter);
        errdefer allocator.destroy(self);
        const hub = try allocator.create(lab.Hub);
        errdefer allocator.destroy(hub);
        hub.* = try lab.Hub.initExpanded(allocator, schema.seed);
        errdefer hub.deinit() catch |err| lab.cleanupFailure(err);
        const scratch = try allocator.create(state.Scratch);
        errdefer allocator.destroy(scratch);
        scratch.* = .{};
        try boundary(hub, 0);
        const content = try schema.contentIdentity(hub, &scratch.canonical);
        try schema.envelope(content, &scratch.envelope);
        const initial = try state.capture(hub, content, scratch);
        const session = try allocator.create(rr.Session);
        errdefer allocator.destroy(session);
        session.* = if (serialized) |bytes| try rr.decode(allocator, bytes, schema.channels, schema.capacities) else try rr.Session.init(allocator, schema.metadata, schema.channels, &scratch.envelope, initial, schema.capacities);
        errdefer session.deinit();
        const player: ?*rr.Player = if (serialized != null) try allocator.create(rr.Player) else null;
        errdefer if (player) |p| allocator.destroy(p);
        if (player) |p| {
            // decode owns its permitted <=1024 byte initial payload until this guard.
            try validateSession(session, &scratch.envelope);
            p.* = try rr.Player.init(session, schema.metadata, &scratch.envelope, initial);
        }
        const artifact = try allocator.alloc(u8, if (serialized == null) schema.artifact_capacity else 0);
        self.* = .{ .allocator = allocator, .hub = hub, .scratch = scratch, .session = session, .player = player, .mode = if (serialized == null) .recording else .playback, .artifact = artifact, .content = content, .initial = initial, .last = initial };
        return self;
    }
    pub fn deinit(self: *Adapter) void {
        const allocator = self.allocator;
        allocator.free(self.artifact);
        if (self.player) |player| {
            player.deinit();
            allocator.destroy(player);
        }
        self.session.deinit();
        allocator.destroy(self.session);
        allocator.destroy(self.scratch);
        self.hub.deinit() catch |err| lab.cleanupFailure(err);
        allocator.destroy(self.hub);
        allocator.destroy(self);
    }
    pub fn cursor(self: *const Adapter) u32 {
        return if (self.player) |p| p.cursor else self.session.count;
    }
    pub fn setPaused(self: *Adapter, paused: bool) !void {
        try self.healthy();
        if (self.finished) return;
        boundary(self.hub, self.cursor()) catch |err| return self.fail(.preflight, err);
        self.hub.clock.setPaused(paused);
    }
    pub fn record(self: *Adapter, control: Control, intent: lab.Intent, start_challenge: bool) !Result {
        try self.healthy();
        if (self.mode != .recording) return self.fail(.preflight, error.WrongAdapterMode);
        if (self.finished) return .finished;
        const bytes = schema.encodeCommand(intent) catch |err| return self.fail(.preflight, err);
        const causes: []const rr.Event = if (start_challenge) block: {
            self.scratch.causal[0] = rr.Event.init(self.cursor(), 0, schema.start_identity, &.{}) catch |err| return self.fail(.preflight, err);
            break :block &self.scratch.causal;
        } else &.{};
        return self.execute(control, &bytes, causes, null);
    }
    pub fn play(self: *Adapter, control: Control) !Result {
        try self.healthy();
        if (self.mode != .playback) return self.fail(.preflight, error.WrongAdapterMode);
        if (self.finished) return .finished;
        const p = self.player.?;
        if (p.cursor >= self.session.count) return self.fail(.preflight, error.InvalidTick);
        const view = self.session.view(&self.session.storage[p.cursor]);
        return self.execute(control, view.command, view.causal, view);
    }
    pub fn encode(self: *Adapter) ![]const u8 {
        try self.healthy();
        if (self.mode != .recording or !self.finished) return self.fail(.finish, error.SessionNotFinished);
        const size = self.session.encodedSize() catch |err| return self.fail(.finish, err);
        if (size > self.artifact.len) return self.fail(.finish, error.ArtifactCapacity);
        return self.session.encode(self.artifact) catch |err| return self.fail(.finish, err);
    }
    fn healthy(self: *const Adapter) !void {
        if (self.failure) |failure| return failure.cause;
    }
    fn latch(self: *Adapter, stage: Stage, cause: anyerror) void {
        if (self.failure == null) self.failure = .{ .record = self.cursor(), .stage = stage, .cause = cause };
    }
    fn fail(self: *Adapter, stage: Stage, cause: anyerror) anyerror {
        self.latch(stage, cause);
        return self.failure.?.cause;
    }
    fn failAt(self: *Adapter, record_number: u64, stage: Stage, cause: anyerror) anyerror {
        if (self.failure == null) self.failure = .{ .record = record_number, .stage = stage, .cause = cause };
        return self.failure.?.cause;
    }
    fn execute(self: *Adapter, control: Control, bytes: []const u8, causes: []const rr.Event, supplied: ?rr.TickView) !Result {
        const n = self.cursor();
        const intent = schema.decodeCommand(bytes) catch |err| return self.fail(.preflight, err);
        validateInput(n, bytes, causes) catch |err| return self.fail(.preflight, err);
        boundary(self.hub, n) catch |err| return self.fail(.preflight, err);
        if (control == .single_step and !self.hub.clock.paused) return self.fail(.preflight, error.RunningSingleStep);
        if (supplied) |view| {
            if (view.tick != n) return self.fail(.preflight, error.InvalidTick);
        }
        const candidates = self.candidateNames() catch |err| return self.fail(.preflight, err);
        if (self.mode == .recording) self.session.preflight(n, bytes, causes, 4, candidates) catch |err| return self.fail(.preflight, err);
        if (control == .wait or (self.hub.clock.paused and control == .run_one)) return .waiting;
        const before_phase = self.hub.challenge.?.phase;
        if (self.player) |p| {
            _ = (p.next() catch |err| return self.fail(.delivery, err)) orelse return self.fail(.delivery, error.InvalidTick);
        }
        if (causes.len != 0) self.hub.challenge.?.requestStart();
        if (control == .single_step) self.hub.clock.requestSingleStep();
        self.hub.advanceFrame(if (control == .single_step) 0 else fixed.fixed_dt_seconds, intent) catch |err| return self.fail(.execution, err);
        boundary(self.hub, n + 1) catch |err| return self.fail(.postcondition, err);
        if (self.hub.clock.last_frame.substeps != 1 or self.hub.pending.move_axis != intent.move_axis or self.hub.pending.jump_held != intent.jump_held) return self.fail(.postcondition, error.TickConsumption);
        const actual = state.observations(self.hub, &self.scratch.observed) catch |err| return self.fail(.observation, err);
        // Observation mismatch must survive a later capture failure.
        if (self.player) |p| p.observe(actual) catch |err| return self.fail(.observation, err);
        const digest = state.capture(self.hub, self.content, self.scratch) catch |err| {
            if (self.player) |p| if (p.observed_divergence != null) {
                self.latch(.observation, error.ObservedEventDivergence);
                self.failure.?.capture_error = err;
                return self.failure.?.cause;
            };
            self.latch(.capture, err);
            self.failure.?.capture_error = err;
            return self.failure.?.cause;
        };
        var verify_error: ?anyerror = null;
        if (self.player) |p| p.verify(digest) catch |err| {
            verify_error = err;
        };
        const actual_names = self.actualNames(before_phase) catch |err| {
            self.latch(if (verify_error != null) (if (self.player.?.observed_divergence != null) .observation else .verification) else .checkpoint, verify_error orelse err);
            self.failure.?.record = n;
            self.failure.?.verification_completed = self.player != null;
            self.failure.?.checkpoint_error = err;
            return self.failure.?.cause;
        };
        const checkpoint_error: ?anyerror = if (supplied) |view| matchNames(view.checkpoints, actual_names) else null;
        if (verify_error != null or checkpoint_error != null) {
            self.latch(if (verify_error != null) (if (self.player.?.observed_divergence != null) .observation else .verification) else .checkpoint, verify_error orelse checkpoint_error.?);
            self.failure.?.record = n;
            self.failure.?.verification_completed = true;
            self.failure.?.checkpoint_error = checkpoint_error;
            return self.failure.?.cause;
        }
        if (self.mode == .recording) try self.appendCompleted(n, bytes, causes, actual, digest, actual_names);
        for (actual_names) |name| {
            const index = nameIndex(name.slice()) orelse return self.fail(.checkpoint, error.CheckpointInventory);
            self.emitted_names |= @as(u16, 1) << @intCast(index);
        }
        for (actual) |event| {
            const index = event.identity.id - schema.jump_identity.id;
            self.counts[index] += 1;
        }
        self.last = digest;
        if (self.hub.challenge.?.effects.particleCount() > 0) self.ever_live = true;
        if (self.cursor() == schema.record_count) {
            const final_content = schema.contentIdentity(self.hub, &self.scratch.canonical) catch |err| {
                self.latch(.finish, err);
                self.failure.?.record = n;
                return self.failure.?.cause;
            };
            if (!final_content.eql(self.content)) {
                self.latch(.finish, error.ContentChanged);
                self.failure.?.record = n;
                return self.failure.?.cause;
            }
            if (self.emitted_names != 0x3ff or !std.mem.eql(u32, &self.counts, &.{ 4, 1, 5, 6 })) return self.failAt(n, .finish, error.FinalInventory);
            if (self.player) |p| {
                if (p.verified_named_checkpoints != 10 or (p.next() catch |err| return self.failAt(n, .finish, err)) != null) return self.failAt(n, .finish, error.FinalInventory);
            } else self.session.finish() catch |err| return self.failAt(n, .finish, err);
            self.finished = true;
        }
        return .stepped;
    }
    fn appendCompleted(self: *Adapter, tick: u64, command: []const u8, causes: []const rr.Event, observed: []const rr.Event, digest: rr.Digest, names: []const rr.CheckpointName) !void {
        self.session.append(tick, command, causes, observed, digest, names) catch |err| return self.fail(.append, err);
    }
    /// Reserve only names possible at the next production transition, once each.
    pub fn candidateNames(self: *Adapter) ![]const rr.CheckpointName {
        const c = &self.hub.challenge.?;
        var mask: u16 = 0;
        if (self.cursor() == 0) mask |= 1;
        if (c.phase == .active and c.progress < 6) mask |= @as(u16, 1) << @intCast(c.progress + 1);
        const complete_possible = c.phase == .complete or (c.phase == .reaction and c.progress == 6 and c.reaction_remaining == 1);
        if (c.phase == .reaction and c.progress == 6 and c.reaction_remaining == 1) mask |= 1 << 7;
        if (complete_possible and self.ever_live and (c.effects.particleCount() == 0 or (c.progress == 6 and self.hub.tick + 1 >= c.observations[5].tick + 120))) mask |= 1 << 8;
        if (self.cursor() + 1 == schema.record_count) mask |= 1 << 9;
        return fillNames(&self.scratch.names, mask & ~self.emitted_names);
    }
    fn actualNames(self: *Adapter, before: lab.collectibles_module.Phase) ![]const rr.CheckpointName {
        const c = &self.hub.challenge.?;
        var mask: u16 = 0;
        if (before == .idle and c.phase == .active and c.run == 1) mask |= 1;
        if (c.last) |event| mask |= @as(u16, 1) << @intCast(event.ordinal);
        if (before == .reaction and c.phase == .complete) mask |= 1 << 7;
        if (c.phase == .complete and self.ever_live and c.effects.particleCount() == 0 and c.effects.emitterCount() == 0 and self.emitted_names & (1 << 8) == 0) mask |= 1 << 8;
        if (self.hub.tick == schema.record_count) {
            if (c.phase != .complete or c.progress != 6 or c.effects.particleCount() != 0 or c.effects.emitterCount() != 0) return error.IncompleteCourse;
            mask |= 1 << 9;
        }
        if (mask & self.emitted_names != 0) return error.RepeatedCheckpoint;
        return fillNames(&self.scratch.names, mask);
    }
};
pub fn validateInput(n: u64, command: []const u8, causes: []const rr.Event) !void {
    if (n >= schema.record_count) return error.InvalidTick;
    _ = try schema.decodeCommand(command);
    if (n == 0) {
        if (!std.mem.allEqual(u8, command, 0) or causes.len != 1) return error.StartChallengeContract;
        const cause = causes[0];
        if (cause.tick != 0 or cause.ordinal != 0 or !cause.identity.eql(schema.start_identity) or (try cause.payloadBytes()).len != 0) return error.StartChallengeContract;
    } else if (causes.len != 0) return error.StartChallengeContract;
}
pub fn validateSession(session: *const rr.Session, envelope: []const u8) !void {
    if (session.initial.len != schema.envelope_size) return error.InvalidEnvelope;
    if (!std.mem.eql(u8, session.initial, envelope)) return error.EnvelopeMismatch;
    if (session.count != schema.record_count or session.causal_count != 1 or session.named_count != 10) return error.SessionInventory;
    var mask: u16 = 0;
    for (session.ticks()) |*tick| {
        const view = session.view(tick);
        try validateInput(tick.tick, view.command, view.causal);
        if (view.observed.len > 4) return error.ObservationCapacity;
        // Valid alternative observations are compared against production during playback.
        for (view.observed) |event| if (event.identity.eql(schema.collect_identity)) {
            var reader = rr.Reader{ .input = try event.payloadBytes() };
            _ = try reader.raw(11);
            if (try reader.int(u64) != tick.tick + 1) return error.CollectionTick;
        };
        for (view.checkpoints) |checkpoint| {
            const index = nameIndex(checkpoint.name.slice()) orelse return error.CheckpointInventory;
            const bit = @as(u16, 1) << @intCast(index);
            if (mask & bit != 0 or (index == 0 and checkpoint.tick != 0) or (index == 9 and checkpoint.tick != schema.record_count - 1) or (index != 0 and checkpoint.tick == 0)) return error.CheckpointInventory;
            mask |= bit;
        }
    }
    if (mask != 0x3ff) return error.CheckpointInventory;
}
pub fn boundary(h: *const lab.Hub, tick: u64) !void {
    if (tick > schema.record_count or h.tick != tick or h.construction != .expanded or !h.seed.eql(schema.seed) or h.navigation_count != 0) return error.HubBoundary;
    const c = if (h.challenge) |*value| value else return error.MissingChallenge;
    if (@intFromEnum(h.actor.read().id) != 1 or h.actor.read().actor_layer != 0) return error.ActorIdentity;
    const physical = h.actor.controllerSnapshot() orelse return error.MissingController;
    if (h.actor.read().simulation_tick != tick or physical.state.simulation_tick != tick or h.last_physical.simulation_tick != (if (tick == 0) 0 else tick - 1) or h.impact.projectiles.tick() != tick or h.impact.effects.tick() != tick or h.impact.observations.executing_tick != tick or c.effects.tick() != tick or h.calibration.state.fixed_ticks != tick or h.world_time.snapshot().simulation_ticks != tick or h.actor.proceduralSnapshot().metrics.fixed_ticks != tick or h.actor.footPlantingSnapshot().metrics.fixed_ticks != tick) return error.SubsystemTick;
    for (&h.stations) |*station| if (station.updates != tick or station.history_count > 64 or station.history_next >= 64) return error.SubsystemTick;
    if (!std.meta.eql(h.clock.configuration, @as(fixed.Configuration, .{})) or h.clock.accumulator != 0 or h.clock.lifetime_discarded_time != 0 or h.clock.last_frame.accumulator != 0 or h.clock.last_frame.discarded_time != 0 or h.clock.last_frame.lifetime_discarded_time != 0 or h.clock.last_frame.interpolation_alpha != 0 or h.clock.single_step_pending or h.pending.jump_pressed or h.pending.jump_released or h.pending.dash_pressed or h.pending.interact_pressed or c.pending_start) return error.SchedulerBoundary;
    if (!std.meta.eql(h.world_time.snapshot().configuration, lab.world_time_module.configuration)) return error.WorldTimeConfiguration;
    try state.inactiveActor(h);
    try state.inactiveImpact(h);
}
pub fn nameIndex(name: []const u8) ?usize {
    for (schema.names, 0..) |expected, index| if (std.mem.eql(u8, expected, name)) return index;
    return null;
}
fn nameLess(_: void, a: rr.CheckpointName, b: rr.CheckpointName) bool {
    return std.mem.order(u8, a.slice(), b.slice()) == .lt;
}
fn fillNames(output: *[4]rr.CheckpointName, mask: u16) ![]const rr.CheckpointName {
    var count: usize = 0;
    for (schema.names, 0..) |name, index| if (mask & (@as(u16, 1) << @intCast(index)) != 0) {
        if (count == output.len) return error.CheckpointCapacity;
        output[count] = try rr.CheckpointName.init(name);
        count += 1;
    };
    std.mem.sort(rr.CheckpointName, output[0..count], {}, nameLess);
    return output[0..count];
}
fn matchNames(expected: []const rr.NamedCheckpoint, actual: []const rr.CheckpointName) ?anyerror {
    if (expected.len != actual.len) return error.CheckpointPlacement;
    for (expected, actual) |a, b| if (!std.mem.eql(u8, a.name.slice(), b.slice())) return error.CheckpointPlacement;
    return null;
}

pub const testing = if (@import("builtin").is_test) struct {
    pub fn verifyPostExecutionAppendFailure() !void {
        const adapter = try Adapter.initRecording(std.testing.allocator);
        defer adapter.deinit();
        const command = try schema.encodeCommand(lab.neutral_intent);
        const cause = try rr.Event.init(0, 0, schema.start_identity, &.{});
        const name = try rr.CheckpointName.init("run_started");
        try adapter.session.preflight(0, &command, &.{cause}, 4, &.{name});
        adapter.hub.challenge.?.requestStart();
        try adapter.hub.advanceFrame(fixed.fixed_dt_seconds, lab.neutral_intent);
        const observed = try state.observations(adapter.hub, &adapter.scratch.observed);
        const digest = try state.capture(adapter.hub, adapter.content, adapter.scratch);
        // Test-local invalidation after a real completed Hub tick and successful preflight.
        try adapter.session.finish();
        try std.testing.expectError(error.SessionFinished, adapter.appendCompleted(0, &command, &.{cause}, observed, digest, &.{name}));
        try std.testing.expectEqual(Stage.append, adapter.failure.?.stage);
        try std.testing.expectEqual(@as(u64, 0), adapter.failure.?.record);
        try std.testing.expectEqual(@as(u64, 1), adapter.hub.tick);
        try std.testing.expectEqual(@as(u32, 0), adapter.cursor());
        try std.testing.expectError(error.SessionFinished, adapter.record(.run_one, lab.neutral_intent, true));
        try std.testing.expectEqual(@as(u64, 1), adapter.hub.tick);
    }
} else struct {};
