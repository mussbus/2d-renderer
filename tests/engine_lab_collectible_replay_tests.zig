const std = @import("std");
const proof = @import("engine_lab_replay_proof");
const replay = proof.replay;
const schema = replay.schema;
const rr = schema.rr;
const options = @import("engine_lab_replay_paths");
const t = std.testing;

fn completed(allocator: std.mem.Allocator) !*replay.Adapter {
    const adapter = try replay.Adapter.initRecording(allocator);
    errdefer adapter.deinit();
    try proof.recordAll(adapter);
    return adapter;
}
test "write recording: complete production record and exact serialized artifact" {
    var audit = proof.AllocationAudit{ .backing = t.allocator };
    const adapter = try replay.Adapter.initRecording(audit.allocator());
    var alive = true;
    defer if (alive) adapter.deinit();
    const before = audit.operations;
    try proof.recordAll(adapter);
    try audit.unchanged(before);
    const encoded = try adapter.encode();
    try audit.unchanged(before);
    try t.expectEqual(schema.nominal_artifact_size, encoded.len);
    try t.expectEqual(@as(usize, 967632), proof.sessionPayload(adapter.session));
    const expected_ticks = [_]u64{ 53, 277, 461, 653, 943, 1137 };
    for (adapter.hub.challenge.?.observations, expected_ticks) |event, tick| try t.expectEqual(tick, event.tick);
    if (options.output_path) |path| try std.Io.Dir.cwd().writeFile(t.io, .{ .sub_path = path, .data = encoded });
    proof.report(adapter, encoded, &audit);
    adapter.deinit();
    alive = false;
    try t.expectEqual(@as(usize, 0), audit.live);
}
test "play recording: serialized commands drive a fresh production hub" {
    var generated: ?*replay.Adapter = null;
    defer if (generated) |adapter| adapter.deinit();
    var file_bytes: ?[]u8 = null;
    defer if (file_bytes) |bytes| t.allocator.free(bytes);
    const bytes = if (options.input_path) |path| block: {
        file_bytes = try std.Io.Dir.cwd().readFileAlloc(t.io, path, t.allocator, .limited(schema.artifact_capacity));
        break :block file_bytes.?;
    } else block: {
        generated = try completed(t.allocator);
        break :block try generated.?.encode();
    };
    var audit = proof.AllocationAudit{ .backing = t.allocator };
    const adapter = try replay.Adapter.initPlayback(audit.allocator(), bytes);
    var alive = true;
    defer if (alive) adapter.deinit();
    const before = audit.operations;
    try proof.playAll(adapter, &.{1});
    try audit.unchanged(before);
    try t.expectEqual(@as(usize, 178664), proof.sessionPayload(adapter.session));
    proof.report(adapter, bytes, &audit);
    adapter.deinit();
    alive = false;
    try t.expectEqual(@as(usize, 0), audit.live);
}

test "repeatable bytes and one-call, four-call, one-three-two invocation groups" {
    const first = try completed(t.allocator);
    defer first.deinit();
    const bytes = try first.encode();
    const second = try replay.Adapter.initRecording(t.allocator);
    defer second.deinit();
    var cursor = proof.RouteCursor{};
    const groups = [_]u8{ 1, 3, 2 };
    var round: usize = 0;
    while (!second.finished) : (round += 1) for (0..groups[round % 3]) |_| {
        if (try cursor.call(second, .run_one) == .finished) break;
    };
    try t.expectEqualSlices(u8, bytes, try second.encode());
    for ([_][]const u8{ &.{1}, &.{4}, &.{ 1, 3, 2 } }) |group| {
        var audit = proof.AllocationAudit{ .backing = t.allocator };
        const player = try replay.Adapter.initPlayback(audit.allocator(), bytes);
        defer player.deinit();
        const before = audit.operations;
        try proof.playAll(player, group);
        try audit.unchanged(before);
        try t.expect(first.last.eql(player.last));
        const end_tick = player.hub.tick;
        const end_cursor = player.cursor();
        for (0..8) |_| try t.expectEqual(replay.Result.finished, try player.play(.run_one));
        try player.setPaused(true);
        try t.expectEqual(end_tick, player.hub.tick);
        try t.expectEqual(end_cursor, player.cursor());
        try t.expectEqual(@as(u32, 10), player.player.?.verified_named_checkpoints);
    }
}

test "pause wait single-step resume do not latch edges or consume the route" {
    const recorder = try replay.Adapter.initRecording(t.allocator);
    defer recorder.deinit();
    var cursor = proof.RouteCursor{};
    try recorder.setPaused(true);
    const initial = recorder.initial;
    for (0..7) |_| {
        try t.expectEqual(replay.Result.waiting, try cursor.call(recorder, .wait));
        try t.expectEqual(replay.Result.waiting, try cursor.call(recorder, .run_one));
        try t.expectEqual(@as(u32, 0), cursor.record);
        try t.expectEqual(@as(u64, 0), recorder.hub.tick);
        try t.expect(!recorder.hub.challenge.?.pending_start);
        try t.expect(initial.eql(try replay.state.capture(recorder.hub, recorder.content, recorder.scratch)));
    }
    try t.expectEqual(replay.Result.stepped, try cursor.call(recorder, .single_step));
    try recorder.setPaused(false);
    while (cursor.record < 149) _ = try cursor.call(recorder, .run_one);
    try recorder.setPaused(true);
    const before_jump = recorder.last;
    for (0..3) |_| _ = try cursor.call(recorder, .run_one);
    try t.expectEqual(@as(u32, 149), cursor.record);
    try t.expect(!recorder.hub.pending.jump_pressed);
    try t.expect(before_jump.eql(try replay.state.capture(recorder.hub, recorder.content, recorder.scratch)));
    _ = try cursor.call(recorder, .single_step);
    try t.expect(recorder.hub.last_physical.jump_accepted);
    try t.expect(!recorder.hub.pending.jump_pressed and !recorder.hub.clock.single_step_pending);
    try recorder.setPaused(false);
    while (try cursor.call(recorder, .run_one) == .stepped) {}
    const bytes = try recorder.encode();
    const player = try replay.Adapter.initPlayback(t.allocator, bytes);
    defer player.deinit();
    try player.setPaused(true);
    for (0..7) |_| {
        _ = try player.play(.wait);
        _ = try player.play(.run_one);
    }
    try t.expectEqual(@as(u32, 0), player.cursor());
    try t.expectEqual(@as(u64, 0), player.hub.tick);
    try t.expectEqual(.idle, player.player.?.phase);
    _ = try player.play(.single_step);
    try player.setPaused(false);
    try proof.playAll(player, &.{4});
    try t.expect(player.last.eql(recorder.last));
}

test "invalid running step and scheduler or input preflight latch before mutation" {
    const lab = schema.lab;
    for (0..8) |case| {
        const adapter = try replay.Adapter.initRecording(t.allocator);
        defer adapter.deinit();
        var command = lab.neutral_intent;
        const control: replay.Control = if (case == 0) .single_step else .run_one;
        switch (case) {
            0 => {},
            1 => adapter.hub.clock.accumulator = 0.001,
            2 => adapter.hub.clock.lifetime_discarded_time = 1,
            3 => adapter.hub.clock.single_step_pending = true,
            4 => adapter.hub.pending.jump_pressed = true,
            5 => command.interact_pressed = true,
            6 => command.move_axis = std.math.nan(f32),
            7 => adapter.hub.challenge.?.pending_start = true,
            else => return error.InvalidCase,
        }
        const err = if (adapter.record(control, command, true)) |_| return error.ExpectedFailure else |err| err;
        try t.expectEqual(replay.Stage.preflight, adapter.failure.?.stage);
        try t.expectEqual(@as(u64, 0), adapter.failure.?.record);
        try t.expectEqual(@as(u64, 0), adapter.hub.tick);
        try t.expectEqual(@as(u32, 0), adapter.cursor());
        try t.expectError(err, adapter.record(.run_one, lab.neutral_intent, true));
        try t.expectError(err, adapter.setPaused(true));
        try t.expectEqual(@as(u64, 0), adapter.hub.tick);
    }
    const adapter = try replay.Adapter.initRecording(t.allocator);
    defer adapter.deinit();
    try adapter.setPaused(true);
    var unsupported = lab.neutral_intent;
    unsupported.interact_pressed = true;
    try t.expectError(error.UnsupportedInput, adapter.record(.wait, unsupported, true));
}

const Fixture = struct {
    session: rr.Session,
    output: []u8,
    fn init(bytes: []const u8) !Fixture {
        var session = try rr.decode(t.allocator, bytes, schema.channels, schema.capacities);
        errdefer session.deinit();
        return .{ .session = session, .output = try t.allocator.alloc(u8, schema.artifact_capacity) };
    }
    fn encode(self: *Fixture) ![]const u8 {
        return self.session.encode(self.output);
    }
    fn deinit(self: *Fixture) void {
        self.session.deinit();
        t.allocator.free(self.output);
    }
    fn addObserved(self: *Fixture, tick: usize, event: rr.Event, before: bool) !void {
        const existing = self.session.view(&self.session.storage[tick]).observed;
        const length = self.session.observed_storage.len;
        const next = try t.allocator.alloc(rr.Event, length + existing.len + 1);
        @memcpy(next[0..length], self.session.observed_storage);
        const base = length;
        if (before) {
            next[base] = event;
            @memcpy(next[base + 1 ..], existing);
        } else {
            @memcpy(next[base..][0..existing.len], existing);
            next[base + existing.len] = event;
        }
        for (next[base..], 0..) |*item, index| item.ordinal = @intCast(index);
        t.allocator.free(self.session.observed_storage);
        self.session.observed_storage = next;
        self.session.storage[tick].observed_start = @intCast(base);
        self.session.storage[tick].observed_count += 1;
        self.session.observed_count += 1;
    }
};
fn reach(player: *replay.Adapter, record: u32) !void {
    while (player.cursor() < record) _ = try player.play(.run_one);
}
fn assertTerminal(player: *replay.Adapter, expected: anyerror, record: u64) !void {
    try t.expectEqual(record, player.failure.?.record);
    const tick = player.hub.tick;
    const cursor = player.cursor();
    const first = player.failure.?;
    try t.expectError(expected, player.play(.run_one));
    try t.expectError(expected, player.play(.single_step));
    try t.expectEqual(tick, player.hub.tick);
    try t.expectEqual(cursor, player.cursor());
    try t.expectEqualDeep(first, player.failure.?);
    std.debug.print("DIVERGENCE record={d} stage={s} cause={s} observation={any} state={any} checkpoint={any} capture={s} verified={any} halted_hub_tick={d}\n", .{ first.record, @tagName(first.stage), @errorName(first.cause), player.player.?.observed_divergence != null, player.player.?.divergence != null, player.player.?.checkpoint_divergence != null, if (first.capture_error) |e| @errorName(e) else "none", first.verification_completed, tick });
}

test "resealed metadata envelope initial-state command cause and checkpoint rejection" {
    const source = try completed(t.allocator);
    defer source.deinit();
    const original = try source.encode();
    const expected = [_]anyerror{ error.IncompatibleTickRate, error.SeedMismatch, error.EnvelopeMismatch, error.InitialStateMismatch, error.InvalidEnvelope, error.InvalidPayload, error.StartChallengeContract, error.CheckpointInventory, error.SessionInventory };
    for (expected, 0..) |err, case| {
        var fixture = try Fixture.init(original);
        defer fixture.deinit();
        switch (case) {
            0 => fixture.session.metadata.hz = 120,
            1 => fixture.session.metadata.derivation.root_seed.bytes[0] ^= 1,
            2 => {
                const initial = try t.allocator.dupe(u8, fixture.session.initial);
                initial[16] ^= 1;
                t.allocator.free(fixture.session.initial);
                fixture.session.initial = initial;
                fixture.session.initial_identity = try rr.initialDigest(schema.envelope_identity, initial);
            },
            3 => fixture.session.initial_state.bytes[0] ^= 1,
            4 => {
                const initial = try t.allocator.dupe(u8, fixture.session.initial[0..87]);
                t.allocator.free(fixture.session.initial);
                fixture.session.initial = initial;
                fixture.session.initial_identity = try rr.initialDigest(schema.envelope_identity, initial);
            },
            5 => fixture.session.storage[1].command[4] = 0x80,
            6 => {
                fixture.session.storage[0].causal_count = 0;
                fixture.session.storage[1].causal_start = 0;
                fixture.session.storage[1].causal_count = 1;
                fixture.session.causal_storage[0].tick = 1;
            },
            7 => fixture.session.named_storage[1].name = try rr.CheckpointName.init("unexpected"),
            8 => {
                fixture.session.named_count -= 1;
                fixture.session.storage[1468].named_count = 0;
            },
            else => return error.InvalidCase,
        }
        const bytes = try fixture.encode();
        // Cases 0 and 5 are codec rejections; the others reach application validation.
        if (case != 0 and case != 5) {
            var decoded = try rr.decode(t.allocator, bytes, schema.channels, schema.capacities);
            decoded.deinit();
        }
        try t.expectError(err, replay.Adapter.initPlayback(t.allocator, bytes));
    }
}

test "actual playback detects missing extra reordered altered observations and state-only divergence" {
    const source = try completed(t.allocator);
    defer source.deinit();
    const original = try source.encode();
    for (0..5) |case| {
        var fixture = try Fixture.init(original);
        defer fixture.deinit();
        const tick: usize = if (case == 4) 51 else 52;
        const offset = fixture.session.storage[52].observed_start;
        switch (case) {
            0 => {
                fixture.session.storage[52].observed_count = 0;
                fixture.session.observed_count -= 1;
            },
            1 => try fixture.addObserved(52, try rr.Event.init(52, 1, schema.dash_identity, &.{}), false),
            2 => try fixture.addObserved(52, try rr.Event.init(52, 0, schema.dash_identity, &.{}), true),
            3 => fixture.session.observed_storage[offset].payload[27] ^= 1,
            4 => fixture.session.storage[tick].fingerprint.bytes[0] ^= 1,
            else => return error.InvalidCase,
        }
        const player = try replay.Adapter.initPlayback(t.allocator, try fixture.encode());
        defer player.deinit();
        try reach(player, @intCast(tick));
        const expected: anyerror = if (case == 4) error.StateDivergence else error.ObservedEventDivergence;
        try t.expectError(expected, player.play(.run_one));
        if (case < 4) try t.expectEqual(([_]rr.ObservedMismatch{ .extra, .missing, .wrong_order, .wrong_payload })[case], player.player.?.observed_divergence.?.category);
        try t.expectEqual(tick + 1, player.hub.tick);
        try assertTerminal(player, expected, tick);
    }
}

test "checkpoint placement and combined observation state checkpoint divergence" {
    const source = try completed(t.allocator);
    defer source.deinit();
    const original = try source.encode();
    for ([_]bool{ false, true }) |combined| {
        var fixture = try Fixture.init(original);
        defer fixture.deinit();
        const tick: u32 = if (combined) 52 else 51;
        if (combined) {
            const offset = fixture.session.storage[52].observed_start;
            fixture.session.observed_storage[offset].payload[27] ^= 1;
            fixture.session.storage[52].fingerprint.bytes[0] ^= 1;
            fixture.session.named_storage[1].digest = fixture.session.storage[52].fingerprint;
            std.mem.swap(rr.CheckpointName, &fixture.session.named_storage[1].name, &fixture.session.named_storage[2].name);
        } else {
            fixture.session.storage[52].named_count = 0;
            fixture.session.storage[51].named_count = 1;
            fixture.session.storage[51].named_start = 1;
            fixture.session.named_storage[1].tick = 51;
            fixture.session.named_storage[1].digest = fixture.session.storage[51].fingerprint;
        }
        const player = try replay.Adapter.initPlayback(t.allocator, try fixture.encode());
        defer player.deinit();
        try reach(player, tick);
        const expected: anyerror = if (combined) error.ObservedEventDivergence else error.CheckpointPlacement;
        try t.expectError(expected, player.play(.run_one));
        try t.expectEqual(error.CheckpointPlacement, player.failure.?.checkpoint_error.?);
        try t.expect(player.failure.?.verification_completed);
        if (combined) {
            try t.expect(player.player.?.observed_divergence != null);
            try t.expect(player.player.?.divergence != null);
            try t.expect(player.player.?.checkpoint_divergence != null);
        } else try t.expect(player.player.?.divergence == null);
        try assertTerminal(player, expected, tick);
    }
}

test "observation mismatch survives a subsequent capture failure with no fabricated verification" {
    const source = try completed(t.allocator);
    defer source.deinit();
    var fixture = try Fixture.init(try source.encode());
    defer fixture.deinit();
    fixture.session.observed_storage[fixture.session.storage[52].observed_start].payload[27] ^= 1;
    const player = try replay.Adapter.initPlayback(t.allocator, try fixture.encode());
    defer player.deinit();
    try reach(player, 52);
    const last_complete = player.last;
    // Initialized public history is not read by Hub stepping at tick53. Capture must reject it.
    player.hub.stations[0].history[0][0] = std.math.nan(f32);
    try t.expectError(error.ObservedEventDivergence, player.play(.run_one));
    try t.expectEqual(replay.Stage.observation, player.failure.?.stage);
    try t.expectEqual(error.NonFiniteFloat, player.failure.?.capture_error.?);
    try t.expect(!player.failure.?.verification_completed);
    try t.expect(player.player.?.observed_divergence != null);
    try t.expect(player.player.?.divergence == null and player.player.?.checkpoint_divergence == null);
    try t.expectEqual(.observed, player.player.?.phase);
    try t.expect(last_complete.eql(player.last));
    try assertTerminal(player, error.ObservedEventDivergence, 52);
}

test "capacity preflight and not-yet-emitted candidate names preserve production state" {
    const expected = [_]anyerror{ error.CapacityExceeded, error.CausalCapacityExceeded, error.ObservedCapacityExceeded, error.CheckpointCapacityExceeded };
    for (expected, 0..) |err, case| {
        const adapter = try replay.Adapter.initRecording(t.allocator);
        defer adapter.deinit();
        const ticks = adapter.session.storage;
        const causes = adapter.session.causal_storage;
        const observed = adapter.session.observed_storage;
        const names = adapter.session.named_storage;
        defer {
            adapter.session.storage = ticks;
            adapter.session.causal_storage = causes;
            adapter.session.observed_storage = observed;
            adapter.session.named_storage = names;
        }
        switch (case) {
            0 => adapter.session.storage = ticks[0..0],
            1 => adapter.session.causal_storage = causes[0..0],
            2 => adapter.session.observed_storage = observed[0..3],
            3 => adapter.session.named_storage = names[0..0],
            else => return error.InvalidCase,
        }
        try t.expectError(err, adapter.record(.run_one, schema.lab.neutral_intent, true));
        try t.expectEqual(@as(u64, 0), adapter.hub.tick);
        try t.expect(adapter.initial.eql(try replay.state.capture(adapter.hub, adapter.content, adapter.scratch)));
        try t.expect(!adapter.hub.challenge.?.pending_start);
        try t.expectEqual(replay.Stage.preflight, adapter.failure.?.stage);
    }
    const adapter = try replay.Adapter.initRecording(t.allocator);
    defer adapter.deinit();
    _ = try adapter.record(.run_one, schema.lab.neutral_intent, true);
    const candidates = try adapter.candidateNames();
    try t.expectEqual(@as(usize, 1), candidates.len);
    try t.expectEqualStrings("collected_1", candidates[0].slice());
    var route_cursor = proof.RouteCursor{ .record = 1 };
    while (!adapter.finished) _ = try route_cursor.call(adapter, .run_one);
    try t.expectEqual(@as(usize, 0), (try adapter.candidateNames()).len);
}

test "real partial Hub overflow and post-execution capture failure are terminal" {
    const adapter = try replay.Adapter.initRecording(t.allocator);
    defer adapter.deinit();
    _ = try adapter.record(.run_one, schema.lab.neutral_intent, true);
    // Public Hub counter overflow occurs after its controller, animation and Hub tick advance.
    // This intentionally invalid fixture is confined to this adapter and is never resumed.
    adapter.hub.jumps = std.math.maxInt(u32);
    var jump = schema.lab.neutral_intent;
    jump.jump_pressed = true;
    jump.jump_held = true;
    try t.expectError(error.Overflow, adapter.record(.run_one, jump, false));
    try t.expectEqual(replay.Stage.execution, adapter.failure.?.stage);
    try t.expectEqual(@as(u64, 1), adapter.failure.?.record);
    try t.expectEqual(@as(u64, 2), adapter.hub.tick);
    try t.expectEqual(@as(u64, 2), adapter.hub.actor.read().simulation_tick);
    try t.expectEqual(@as(u64, 1), adapter.hub.world_time.snapshot().simulation_ticks);
    try t.expectEqual(@as(u64, 1), adapter.hub.stations[0].updates);
    try t.expectEqual(@as(u32, 1), adapter.cursor());
    try t.expectError(error.Overflow, adapter.record(.run_one, schema.lab.neutral_intent, false));
    try t.expectEqual(@as(u64, 2), adapter.hub.tick);

    const capture = try replay.Adapter.initRecording(t.allocator);
    defer capture.deinit();
    var cursor = proof.RouteCursor{};
    while (cursor.record < 4) _ = try cursor.call(capture, .run_one);
    capture.hub.stations[0].history[0][1] = std.math.nan(f32);
    try t.expectError(error.NonFiniteFloat, cursor.call(capture, .run_one));
    try t.expectEqual(replay.Stage.capture, capture.failure.?.stage);
    try t.expectEqual(@as(u64, 5), capture.hub.tick);
    try t.expectEqual(@as(u32, 4), capture.cursor());
    try t.expectError(error.NonFiniteFloat, cursor.call(capture, .run_one));
}

fn checkInitFailures(bytes: ?[]const u8) !void {
    var index: usize = 0;
    while (index < 250) : (index += 1) {
        var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = index });
        const result = if (bytes) |input| replay.Adapter.initPlayback(failing.allocator(), input) else replay.Adapter.initRecording(failing.allocator());
        const adapter = result catch {
            try t.expect(failing.has_induced_failure);
            try t.expectEqual(failing.allocated_bytes, failing.freed_bytes);
            continue;
        };
        adapter.deinit();
        try t.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        std.debug.print("INITIALIZATION_FAILURE_CLEANUP_OK mode={s} boundaries={d}\n", .{ if (bytes == null) "record" else "decode-playback", index });
        return;
    }
    return error.AllocationBoundaryProofDidNotComplete;
}
test "initialization and decoding allocation failure cleanup at every acquisition" {
    try checkInitFailures(null);
    const source = try completed(t.allocator);
    defer source.deinit();
    const bytes = try source.encode();
    try checkInitFailures(bytes);
    for (0..5) |index| {
        var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = index });
        try t.expectError(error.OutOfMemory, rr.decode(failing.allocator(), bytes, schema.channels, schema.capacities));
        try t.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}

test "correctly checksummed 1024-byte envelope exercises maximum decoded allocation then rejects" {
    const initial = try t.allocator.alloc(u8, rr.maximum_initial_bytes);
    defer t.allocator.free(initial);
    @memset(initial, 0);
    const source = try completed(t.allocator);
    defer source.deinit();
    var session = try rr.Session.init(t.allocator, schema.metadata, schema.channels, initial, source.initial, schema.capacities);
    defer session.deinit();
    var events: [4]rr.Event = undefined;
    for (0..schema.capacities.ticks) |tick| {
        for (&events, 0..) |*event, ordinal| event.* = try rr.Event.init(tick, @intCast(ordinal), schema.dash_identity, &.{});
        const cause = try rr.Event.init(tick, 0, schema.start_identity, &.{});
        const name = if (tick < 10) try rr.CheckpointName.init(schema.names[tick]) else null;
        try session.append(tick, &.{ 0, 0, 0, 0, 0 }, if (tick == 0) &.{cause} else &.{}, &events, source.initial, if (name) |n| &.{n} else &.{});
    }
    try session.finish();
    const output = try t.allocator.alloc(u8, schema.artifact_capacity);
    defer t.allocator.free(output);
    const bytes = try session.encode(output);
    var audit = proof.AllocationAudit{ .backing = t.allocator };
    const decoded = try audit.allocator().create(rr.Session);
    decoded.* = try rr.decode(audit.allocator(), bytes, schema.channels, schema.capacities);
    try t.expectEqual(@as(usize, 968568), proof.sessionPayload(decoded));
    try t.expectEqual(@as(usize, 968944), audit.live);
    try t.expectEqual(@as(usize, 936), decoded.initial.len - schema.envelope_size);
    decoded.deinit();
    audit.allocator().destroy(decoded);
    try t.expectEqual(@as(usize, 0), audit.live);
    try t.expectError(error.InvalidEnvelope, replay.Adapter.initPlayback(audit.allocator(), bytes));
    try t.expectEqual(@as(usize, 0), audit.live);
    for (0..5) |index| {
        var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = index });
        try t.expectError(error.OutOfMemory, rr.decode(failing.allocator(), bytes, schema.channels, schema.capacities));
        try t.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
    std.debug.print("OVERSIZED_ENVELOPE_OK encoded={d} initial=1024 session_payload=968568 owner_inclusive=968944 extra=936 cleanup=true\n", .{bytes.len});
}

fn valueDigest(adapter: *replay.Adapter, value: anytype) !rr.Digest {
    var writer = rr.Bytes.init(&adapter.scratch.canonical);
    try schema.value(&writer, value);
    return rr.contributorDigest(schema.id(0x454C1003), writer.slice());
}
fn contributorDigest(adapter: *replay.Adapter, index: usize) !rr.Digest {
    return rr.contributorDigest(schema.id(0x454C1001 + @as(u32, @intCast(index))), try replay.state.contributor(adapter.hub, adapter.content, adapter.scratch, index));
}
test "all twelve contributors cover mutable production state or legitimate copied values" {
    const adapter = try replay.Adapter.initRecording(t.allocator);
    defer adapter.deinit();
    const h = adapter.hub;
    const c1 = try schema.contentIdentity(h, &adapter.scratch.canonical);
    h.stations[0].configurations[0].damping += 0.01;
    try t.expect(!c1.eql(try schema.contentIdentity(h, &adapter.scratch.canonical)));
    h.stations[0].configurations[0].damping -= 0.01;
    const c2 = try contributorDigest(adapter, 1);
    h.pending.move_axis = 0.5;
    try t.expect(!c2.eql(try contributorDigest(adapter, 1)));
    h.pending.move_axis = 0;
    var controller = h.actor.controllerSnapshot().?;
    const old_controller = try valueDigest(adapter, controller);
    controller.state.jump_buffer_ticks_remaining = 2;
    try t.expect(!old_controller.eql(try valueDigest(adapter, controller)));
    var cursor = proof.RouteCursor{};
    while (cursor.record < 4) _ = try cursor.call(adapter, .run_one);
    var animation = h.actor.animationPlaybackSnapshot();
    try t.expect(animation.active_transition != null);
    const original_animation = animation;
    const old_animation = try valueDigest(adapter, animation);
    animation.active_transition.?.source_playback.loop_count += 1;
    try t.expect(!old_animation.eql(try valueDigest(adapter, animation)));
    animation = original_animation;
    animation.active_transition.?.destination_playback.fallback_pending = true;
    try t.expect(!old_animation.eql(try valueDigest(adapter, animation)));
    animation = original_animation;
    animation.active_transition.?.source_advances = !animation.active_transition.?.source_advances;
    try t.expect(!old_animation.eql(try valueDigest(adapter, animation)));
    animation = original_animation;
    animation.active_transition.?.destination_begins_immediately = !animation.active_transition.?.destination_begins_immediately;
    try t.expect(!old_animation.eql(try valueDigest(adapter, animation)));
    var feet = h.actor.footPlantingSnapshot();
    const old_feet = try valueDigest(adapter, feet);
    feet.left.applied.pre_hip_local.translation.x += 0.01;
    try t.expect(!old_feet.eql(try valueDigest(adapter, feet)));
    var proc = h.actor.proceduralSnapshot();
    const old_proc = try valueDigest(adapter, proc);
    proc.secondary_spring.velocity += 0.01;
    try t.expect(!old_proc.eql(try valueDigest(adapter, proc)));
    const c5 = try contributorDigest(adapter, 4);
    var pelvis = try h.actor.humanoidView().local_and_world_pose.localForSemantic(&h.definition.skeleton_definition, .pelvis);
    pelvis.translation.x += 0.01;
    try h.actor.setLocalPoseSemantic(.pelvis, pelvis);
    try t.expect(!c5.eql(try contributorDigest(adapter, 4)));
    const c6 = try contributorDigest(adapter, 5);
    h.stations[0].history[0][1] += 0.01;
    try t.expect(!c6.eql(try contributorDigest(adapter, 5)));
    const c7 = try contributorDigest(adapter, 6);
    h.calibration.state.driver_velocity += 0.01;
    try t.expect(!c7.eql(try contributorDigest(adapter, 6)));
    const c8 = try contributorDigest(adapter, 7);
    var time = h.world_time.snapshot();
    time.submicrosecond_remainder = 1;
    h.world_time = try schema.lab.world_time_module.WorldTime.fromSnapshot(time);
    try t.expect(!c8.eql(try contributorDigest(adapter, 7)));
    const c9 = try contributorDigest(adapter, 8);
    h.challenge.?.born_tick += 1;
    try t.expect(!c9.eql(try contributorDigest(adapter, 8)));
    const c11 = try contributorDigest(adapter, 10);
    h.impact.observations.executing_tick += 1;
    try t.expect(!c11.eql(try contributorDigest(adapter, 10)));
    h.impact.bridge.metrics.truncated_segments = 1;
    try t.expectError(error.UnsupportedImpact, contributorDigest(adapter, 10));
    const c12 = try contributorDigest(adapter, 11);
    h.visited[1] = !h.visited[1];
    try t.expect(!c12.eql(try contributorDigest(adapter, 11)));

    const live = try replay.Adapter.initRecording(t.allocator);
    defer live.deinit();
    var live_cursor = proof.RouteCursor{};
    while (live_cursor.record < 53) _ = try live_cursor.call(live, .run_one);
    _ = try contributorDigest(live, 9);
    var particle = live.scratch.particles[0];
    const original_particle = try valueDigest(live, particle);
    particle.previous_position.x += 0.01;
    try t.expect(!original_particle.eql(try valueDigest(live, particle)));
    var emitter = live.scratch.emitters[0];
    const original_emitter = try valueDigest(live, emitter);
    emitter.remainder += 1;
    try t.expect(!original_emitter.eql(try valueDigest(live, emitter)));
    const id = live.hub.challenge.?.effect_ids[0].?;
    try live.hub.challenge.?.effects.setPosition(id, .{ .x = 1, .y = 2 });
    try t.expectError(error.EmitterLifecycle, contributorDigest(live, 9));
    try live.hub.challenge.?.effects.clear(id);
    try t.expectError(error.MissingEmitter, contributorDigest(live, 9));
}

test "orphan emitter inventory and excluded features cannot silently disappear" {
    const adapter = try replay.Adapter.initRecording(t.allocator);
    defer adapter.deinit();
    _ = try adapter.record(.run_one, schema.lab.neutral_intent, true);
    const id = try schema.lab.collectibles_module.effectId(1, 6);
    _ = try adapter.hub.challenge.?.effects.spawn(.{ .id = id, .definition = .{ .burst = 0 }, .position = .zero });
    try t.expectError(error.OrphanEffect, contributorDigest(adapter, 9));
    adapter.hub.impact.pending_activation = true;
    try t.expectError(error.UnsupportedImpact, adapter.record(.run_one, schema.lab.neutral_intent, false));
    try t.expectEqual(@as(u64, 1), adapter.hub.tick);
}

test "post-execution append rejection retains completed Hub and terminal failure" {
    try replay.testing.verifyPostExecutionAppendFailure();
}

test "every application envelope field rejects resealed incompatible bootstrap values" {
    const source = try completed(t.allocator);
    defer source.deinit();
    const bytes = try source.encode();
    for ([_]usize{ 0, 16, 48, 64, 68, 72, 76, 80, 81, 82, 84 }) |offset| {
        var fixture = try Fixture.init(bytes);
        defer fixture.deinit();
        const initial = try t.allocator.dupe(u8, fixture.session.initial);
        initial[offset] ^= 1;
        t.allocator.free(fixture.session.initial);
        fixture.session.initial = initial;
        fixture.session.initial_identity = try rr.initialDigest(schema.envelope_identity, initial);
        const mutated = try fixture.encode();
        var decoded = try rr.decode(t.allocator, mutated, schema.channels, schema.capacities);
        decoded.deinit();
        try t.expectError(error.EnvelopeMismatch, replay.Adapter.initPlayback(t.allocator, mutated));
    }
}
