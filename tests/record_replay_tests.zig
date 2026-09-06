const std = @import("std");
const replay = @import("record_replay");
const proof = @import("record_replay_proof");
const fixed = @import("fixed_step");
const input = @import("input");
const foundation = @import("foundation");
const testing = std.testing;

const neutral = proof.CharacterIntent{
    .move_axis = 0,
    .jump_pressed = false,
    .jump_held = false,
    .jump_released = false,
    .interact_pressed = false,
};

fn recording(allocator: std.mem.Allocator, tick_count: u32, chunk: u8) !replay.Session {
    const metadata = try proof.metadata();
    const initial = try proof.initialEnvelope(0);
    var client = try proof.Proof.init(allocator, metadata, &initial);
    defer client.deinit();
    var result = try replay.Session.init(allocator, metadata, proof.channels, &initial, try client.digest(), tick_count);
    errdefer result.deinit();
    var clock = try fixed.Clock.init(.{});
    while (client.tick() < tick_count) {
        const remaining = tick_count - client.tick();
        const group = @min(chunk, remaining);
        const frame = try clock.beginFrame(@as(f64, @floatFromInt(group)) * fixed.fixed_dt_seconds);
        for (0..frame.substeps) |_| {
            const tick = client.tick();
            var command = neutral;
            command.move_axis = if (tick < 80) 1 else -0.5;
            command.jump_pressed = tick == 8 or tick == 30;
            command.jump_held = tick >= 8 and tick < 42;
            command.jump_released = tick == 42;
            command.dash_pressed = tick == 65;
            command.interact_pressed = tick == 100;
            const event: ?proof.SetMaximumRunSpeed = if (tick == 50) .{ .metres_per_second = 6 } else null;
            try client.recordTick(&result, command, event);
        }
    }
    try result.finish();
    return result;
}

test "V1 header uses the production fixed tick and validates identities" {
    var metadata = try proof.metadata();
    try metadata.validate();
    try testing.expectEqual(fixed.simulation_hz, metadata.hz);
    metadata.hz = 60;
    try testing.expectError(error.IncompatibleTickRate, metadata.validate());
    metadata = try proof.metadata();
    metadata.command.id = 0;
    try testing.expectError(error.InvalidMetadata, metadata.validate());
    metadata = try proof.metadata();
    metadata.derivation.generator_id.bytes = @splat(0);
    try testing.expectError(error.InvalidMetadata, metadata.validate());
}

test "production proof records loads and replays every checkpoint" {
    var session = try recording(testing.allocator, 480, 1);
    defer session.deinit();
    var bytes: [40000]u8 = undefined;
    const artifact = try session.encode(&bytes);
    var loaded = try replay.decode(testing.allocator, artifact, proof.channels, 480);
    defer loaded.deinit();
    var client = try proof.Proof.init(testing.allocator, loaded.metadata, loaded.initial);
    defer client.deinit();
    var player = try replay.Player.init(&loaded, try proof.metadata(), loaded.initial, try client.digest());
    defer player.deinit();
    while (try client.replayTick(&player)) {}
    try testing.expectEqual(@as(u64, 480), client.tick());
    try testing.expect(session.ticks()[479].checkpoint.eql(try client.digest()));
    try testing.expectEqual(@as(u32, 1), loaded.event_count);
    std.debug.print("RR1_PROOF_OK ticks=480 checkpoints=480 bytes={d} final={s} artifact={s}\n", .{ artifact.len, (try client.digest()).formatLowerHex(), (try replay.artifactDigest(artifact[0 .. artifact.len - 32])).formatLowerHex() });
}

test "repeat artifacts and frame grouping are byte identical" {
    var a = try recording(testing.allocator, 160, 1);
    defer a.deinit();
    var b = try recording(testing.allocator, 160, 7);
    defer b.deinit();
    var c = try recording(testing.allocator, 160, 1);
    defer c.deinit();
    var a_bytes: [20000]u8 = undefined;
    var b_bytes: [20000]u8 = undefined;
    var c_bytes: [20000]u8 = undefined;
    try testing.expectEqualSlices(u8, try a.encode(&a_bytes), try b.encode(&b_bytes));
    try testing.expectEqualSlices(u8, try a.encode(&a_bytes), try c.encode(&c_bytes));
    std.debug.print("RR1_REPEAT_OK ticks=160 runs=3 frame_groups=1,7,1 byte_mismatches=0\n", .{});
}

test "encode decode encode preserves bytes" {
    var source = try recording(testing.allocator, 64, 4);
    defer source.deinit();
    var a: [8000]u8 = undefined;
    var b: [8000]u8 = undefined;
    const artifact = try source.encode(&a);
    var loaded = try replay.decode(testing.allocator, artifact, proof.channels, 64);
    defer loaded.deinit();
    try testing.expectEqualSlices(u8, artifact, try loaded.encode(&b));
}

test "command float canonicalization and all flags" {
    var command = neutral;
    command.move_axis = -0.0;
    try testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 0 }, &try proof.encodeCommand(command));
    command.move_axis = 0.5;
    command.jump_pressed = true;
    command.jump_held = true;
    command.jump_released = true;
    command.dash_pressed = true;
    command.interact_pressed = true;
    try testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0x3f, 31 }, &try proof.encodeCommand(command));
    try testing.expectError(error.NonCanonicalFloat, proof.decodeCommand(&.{ 0, 0, 0, 0x80, 0 }));
    for ([_]f32{ std.math.inf(f32), -std.math.inf(f32), std.math.nan(f32), -1.01, 1.01 }) |invalid| {
        command.move_axis = invalid;
        try testing.expectError(error.InvalidPayload, proof.encodeCommand(command));
    }
}

fn goldenDigest() !replay.Digest {
    const digest = try replay.contributorDigest(.{ .id = 2, .version = 1 }, "x");
    return replay.stateDigest(&.{.{ .identity = .{ .id = 2, .version = 1 }, .digest = digest }});
}

fn goldenArtifact() ![306]u8 {
    // Independently calculated with Python struct + hashlib, not the encoder.
    const hex =
        "5252315449434b0001000100f000000000000000000000000100000000112233445566778899aabbccddeeff" ++
        "0195d5b84100700080000000000000010100000000000000000000000195d5b8410070008000000000000002" ++
        "0100000000000000000000000100000001000400ae3d963ed538ed66cca97c684de91225e4ca374a439dae0a4e0bae8d79cd775f" ++
        "99128778c503a3c55a80f0721f5f6beec8be9cea91dc4265fef60f58c783b975010000000100010000000100010000000100000001000000" ++
        "0000000001000000000000000005000000003f0302000000000000000004000000c0400300000000000000002000" ++
        "99128778c503a3c55a80f0721f5f6beec8be9cea91dc4265fef60f58c783b97592638fd5c66ce659d20d54bb58f69449d225f6540540675867325c1c20711f0e";
    var output: [306]u8 = undefined;
    _ = try std.fmt.hexToBytes(&output, hex);
    return output;
}

fn reseal(bytes: []u8) !void {
    const digest = try replay.artifactDigest(bytes[0 .. bytes.len - 32]);
    @memcpy(bytes[bytes.len - 32 ..], &digest.bytes);
}

test "golden domain separated V1 digests and stable derivation key" {
    const initial = try replay.initialDigest(proof.schema, &.{ 0, 0, 0, 0 });
    try testing.expectEqualStrings("ae3d963ed538ed66cca97c684de91225e4ca374a439dae0a4e0bae8d79cd775f", &initial.formatLowerHex());
    const contributor = try replay.contributorDigest(.{ .id = 2, .version = 1 }, "x");
    try testing.expectEqualStrings("9d6b494c2c9e9a1cded74f06b44a5e68c6cb85698119b03ad01ed45b89f24d56", &contributor.formatLowerHex());
    try testing.expectEqualStrings("99128778c503a3c55a80f0721f5f6beec8be9cea91dc4265fef60f58c783b975", &(try goldenDigest()).formatLowerHex());
    const artifact = try goldenArtifact();
    const digest = try replay.artifactDigest(artifact[0..274]);
    try testing.expectEqualStrings("92638fd5c66ce659d20d54bb58f69449d225f6540540675867325c1c20711f0e", &digest.formatLowerHex());
    const key = try foundation.determinism.deriveKey((try proof.metadata()).derivation, &.{ "rr1.controller", "speed" });
    try testing.expectEqualStrings("a98a1a13b0ba3400809e1642b1b534d87498a9d31fb878b6f8f23566f3ed4fab", &(replay.Digest{ .bytes = key }).formatLowerHex());
    const alternate = try foundation.determinism.deriveKey((try proof.metadata()).derivation, &.{ "speed", "rr1.controller" });
    try testing.expect(!std.mem.eql(u8, &key, &alternate));
}

test "golden complete V1 encoding independently fixes field widths order and checksum" {
    const expected = try goldenArtifact();
    var session = try replay.Session.init(testing.allocator, try proof.metadata(), proof.channels, &.{ 0, 0, 0, 0 }, try goldenDigest(), 1);
    defer session.deinit();
    try session.append(0, &.{ 0, 0, 0, 0x3f, 3 }, &.{ 0, 0, 0xc0, 0x40 }, try goldenDigest());
    try session.finish();
    var output: [306]u8 = undefined;
    try testing.expectEqualSlices(u8, &expected, try session.encode(&output));
    var loaded = try replay.decode(testing.allocator, &expected, proof.channels, 1);
    defer loaded.deinit();
    try testing.expectEqual(@as(u32, 1), loaded.count);
    try testing.expectEqual(@as(f32, 0.5), (try proof.decodeCommand(loaded.ticks()[0].commandBytes())).move_axis);
}

test "atomic capacity payload and lifecycle failures" {
    const metadata = try proof.metadata();
    const digest = try goldenDigest();
    var session = try replay.Session.init(testing.allocator, metadata, proof.channels, &.{0}, digest, 1);
    defer session.deinit();
    try testing.expectError(error.SessionNotFinished, session.encodedSize());
    try testing.expectError(error.InvalidTick, session.append(1, &.{ 0, 0, 0, 0, 0 }, null, digest));
    try testing.expectError(error.PayloadTooLarge, session.append(0, &(@as([65]u8, @splat(0))), null, digest));
    try testing.expectError(error.PayloadTooLarge, session.append(0, &.{ 0, 0, 0, 0, 0 }, &(@as([65]u8, @splat(0))), digest));
    try testing.expectEqual(@as(u32, 0), session.count);
    try testing.expectEqual(@as(u32, 0), session.event_count);
    try session.append(0, &.{ 0, 0, 0, 0, 0 }, null, digest);
    try testing.expectError(error.InvalidTick, session.append(0, &.{ 0, 0, 0, 0, 0 }, null, digest));
    try testing.expectError(error.CapacityExceeded, session.append(1, &.{ 0, 0, 0, 0, 0 }, null, digest));
    try testing.expectEqual(@as(u32, 1), session.count);
    try session.finish();
    try testing.expectError(error.SessionFinished, session.append(1, &.{ 0, 0, 0, 0, 0 }, null, digest));
    try testing.expectError(error.SessionFinished, session.finish());
    var too_small: [10]u8 = @splat(0x55);
    try testing.expectError(error.OutputTooSmall, session.encode(&too_small));
    try testing.expectEqualSlices(u8, &(@as([10]u8, @splat(0x55))), &too_small);
    try testing.expectError(error.CapacityExceeded, replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, digest, replay.maximum_ticks + 1));
    try testing.expectError(error.PayloadTooLarge, replay.Session.init(testing.allocator, metadata, proof.channels, &(@as([1025]u8, @splat(0))), digest, 1));
}

test "explicit nonzero start domain and u64 overflow" {
    var metadata = try proof.metadata();
    metadata.start_tick = std.math.maxInt(u64) - 1;
    var session = try replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, try goldenDigest(), 2);
    defer session.deinit();
    try session.append(metadata.start_tick, &.{ 0, 0, 0, 0, 0 }, null, try goldenDigest());
    try testing.expectError(error.TickOverflow, session.append(std.math.maxInt(u64), &.{ 0, 0, 0, 0, 0 }, null, try goldenDigest()));
    try session.finish();
    var bytes: [1000]u8 = undefined;
    var loaded = try replay.decode(testing.allocator, try session.encode(&bytes), proof.channels, 2);
    defer loaded.deinit();
    try testing.expectEqual(metadata.start_tick, loaded.ticks()[0].tick);
    var overflow = try goldenArtifact();
    std.mem.writeInt(u64, overflow[16..24], std.math.maxInt(u64), .little);
    try reseal(&overflow);
    try testing.expectError(error.TickOverflow, replay.decode(testing.allocator, &overflow, proof.channels, 1));
}

test "decoder rejects truncation at every byte boundary" {
    const artifact = try goldenArtifact();
    for (0..artifact.len) |length| {
        if (replay.decode(testing.allocator, artifact[0..length], proof.channels, 1)) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.AcceptedTruncatedArtifact;
        } else |err| {
            try testing.expect(err == error.TruncatedArtifact or err == error.CorruptArtifact);
        }
    }
}

test "decoder rejects corruption at every byte and checksum boundary" {
    const original = try goldenArtifact();
    for (0..original.len) |index| {
        var bytes = original;
        bytes[index] ^= 0x40;
        if (replay.decode(testing.allocator, &bytes, proof.channels, 1)) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.AcceptedCorruptArtifact;
        } else |_| {}
    }
}

test "unknown required records channels and versions fail closed" {
    var bytes = try goldenArtifact();
    bytes[200] = 9;
    try reseal(&bytes);
    try testing.expectError(error.UnknownRecordKind, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    bytes[8] = 2;
    try testing.expectError(error.UnsupportedVersion, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    bytes[10] = 2;
    try testing.expectError(error.IncompatibleProtocol, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    bytes[12] = 60;
    try testing.expectError(error.IncompatibleTickRate, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    bytes[24] = 2;
    try testing.expectError(error.DerivationMismatch, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    for ([_]usize{ 172, 176, 178, 182 }) |offset| {
        bytes = try goldenArtifact();
        bytes[offset] = 2;
        try reseal(&bytes);
        try testing.expectError(error.UnsupportedChannel, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    }
}

test "decoder validates record phases ticks counts sizes and canonical payload" {
    for ([_]usize{ 201, 217, 232 }) |tick_offset| {
        var bytes = try goldenArtifact();
        bytes[tick_offset] = 1;
        try reseal(&bytes);
        try testing.expectError(error.InvalidTick, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    }
    var bytes = try goldenArtifact();
    bytes[216] = 1;
    try reseal(&bytes);
    try testing.expectError(error.InvalidOrdering, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    bytes[188] = 0;
    try reseal(&bytes);
    try testing.expectError(error.InvalidCounts, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    bytes[192] = 0;
    try testing.expectError(error.InvalidCounts, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    bytes[209] = 65;
    try reseal(&bytes);
    try testing.expectError(error.PayloadTooLarge, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    std.mem.writeInt(u32, bytes[211..215], 0x80000000, .little);
    try reseal(&bytes);
    try testing.expectError(error.NonCanonicalFloat, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    bytes[215] = 0x80;
    try reseal(&bytes);
    try testing.expectError(error.InvalidPayload, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    bytes[200 - 4] = 1;
    try reseal(&bytes);
    try testing.expectError(error.InitialStateMismatch, replay.decode(testing.allocator, &bytes, proof.channels, 1));
}

test "duplicate decreasing and skipped ticks cannot load even with valid integrity" {
    var session = try recording(testing.allocator, 3, 1);
    defer session.deinit();
    var output: [1000]u8 = undefined;
    const length = (try session.encode(&output)).len;
    const second_tick_offset = 200 + 59 + 1;
    for ([_]u64{ 0, 2, std.math.maxInt(u64) }) |bad_tick| {
        _ = try session.encode(&output);
        std.mem.writeInt(u64, output[second_tick_offset..][0..8], bad_tick, .little);
        try reseal(output[0..length]);
        try testing.expectError(error.InvalidTick, replay.decode(testing.allocator, output[0..length], proof.channels, 3));
    }
}

test "initial identity root seed and algorithm compatibility precede simulation" {
    var session = try recording(testing.allocator, 1, 1);
    defer session.deinit();
    var client = try proof.Proof.init(testing.allocator, session.metadata, session.initial);
    defer client.deinit();
    const digest = try client.digest();
    try testing.expectError(error.InitialStateMismatch, replay.Player.init(&session, session.metadata, &try proof.initialEnvelope(1), digest));
    var bad_digest = digest;
    bad_digest.bytes[0] ^= 1;
    try testing.expectError(error.InitialStateMismatch, replay.Player.init(&session, session.metadata, session.initial, bad_digest));
    var expected = session.metadata;
    expected.derivation.root_seed.bytes[0] ^= 1;
    try testing.expectError(error.SeedMismatch, replay.Player.init(&session, expected, session.initial, digest));
    expected = session.metadata;
    expected.derivation.algorithm_version.patch += 1;
    try testing.expectError(error.DerivationMismatch, replay.Player.init(&session, expected, session.initial, digest));
    try testing.expectError(error.DerivationMismatch, proof.Proof.init(testing.allocator, expected, session.initial));
    expected = session.metadata;
    expected.derivation.generator_version.major += 1;
    try testing.expectError(error.DerivationMismatch, replay.Player.init(&session, expected, session.initial, digest));
    expected = session.metadata;
    expected.derivation.algorithm_id.bytes[15] += 1;
    try testing.expectError(error.DerivationMismatch, replay.Player.init(&session, expected, session.initial, digest));
    expected = session.metadata;
    expected.initial_schema.version += 1;
    try testing.expectError(error.InitialStateMismatch, replay.Player.init(&session, expected, session.initial, digest));
    try testing.expectEqual(@as(u64, 0), client.tick());
}

test "first changed command reports exact tick and latches expected actual digests" {
    try changedCauseDiverges(12, false);
}

test "first changed accepted exogenous event reports divergence" {
    try changedCauseDiverges(50, true);
}

fn changedCauseDiverges(changed_tick: usize, event: bool) !void {
    var source = try recording(testing.allocator, 100, 4);
    defer source.deinit();
    var output: [10000]u8 = undefined;
    const length = (try source.encode(&output)).len;
    const offset = 200 + changed_tick * 59 + (if (event) @as(usize, 16 + 11) else 11);
    std.mem.writeInt(u32, output[offset..][0..4], @bitCast(@as(f32, if (event) 7 else -1)), .little);
    try reseal(output[0..length]);
    var changed = try replay.decode(testing.allocator, output[0..length], proof.channels, 100);
    defer changed.deinit();
    var client = try proof.Proof.init(testing.allocator, changed.metadata, changed.initial);
    defer client.deinit();
    var player = try replay.Player.init(&changed, try proof.metadata(), changed.initial, try client.digest());
    defer player.deinit();
    for (0..changed_tick) |_| try testing.expect(try client.replayTick(&player));
    try testing.expectError(error.StateDivergence, client.replayTick(&player));
    const failure = player.divergence orelse return error.MissingDivergence;
    try testing.expectEqual(@as(u64, changed_tick), failure.tick);
    try testing.expect(failure.expected.eql(source.ticks()[changed_tick].checkpoint));
    try testing.expect(failure.actual.eql(try client.digest()));
    try testing.expect(!failure.expected.eql(failure.actual));
    try testing.expectError(error.StateDivergence, player.next());
    try testing.expectError(error.StateDivergence, player.verify(failure.expected));
    try testing.expectEqualDeep(failure, player.divergence.?);
    std.debug.print("RR1_DIVERGENCE tick={d} expected={s} actual={s}\n", .{ failure.tick, failure.expected.formatLowerHex(), failure.actual.formatLowerHex() });
    try testing.expectEqual(@as(u64, changed_tick + 1), client.tick());
}

test "player enforces verify before advance and handles empty sessions" {
    var session = try recording(testing.allocator, 1, 1);
    defer session.deinit();
    var player = try replay.Player.init(&session, session.metadata, session.initial, session.initial_state);
    defer player.deinit();
    try testing.expectError(error.NoPendingTick, player.verify(session.initial_state));
    const record = (try player.next()).?;
    try testing.expectError(error.VerificationPending, player.next());
    try player.verify(record.checkpoint);
    try testing.expectEqual(@as(?*const replay.Tick, null), try player.next());
    try testing.expectError(error.NoPendingTick, player.verify(record.checkpoint));
    var empty = try recording(testing.allocator, 0, 1);
    defer empty.deinit();
    var empty_player = try replay.Player.init(&empty, empty.metadata, empty.initial, empty.initial_state);
    defer empty_player.deinit();
    try testing.expectEqual(@as(?*const replay.Tick, null), try empty_player.next());
}

test "application pending edges are recorded only after tick consumption" {
    var builder = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .space = true, .d = true } }));
    try testing.expectEqual(@as(u8, 1), pending.pendingEdgeCount());
    const initial = try proof.initialEnvelope(0);
    var client = try proof.Proof.init(testing.allocator, try proof.metadata(), &initial);
    defer client.deinit();
    var session = try replay.Session.init(testing.allocator, try proof.metadata(), proof.channels, &initial, try client.digest(), 2);
    defer session.deinit();
    try client.recordTick(&session, pending.consumeTick(), null);
    try client.recordTick(&session, pending.consumeTick(), null);
    const first = try proof.decodeCommand(session.ticks()[0].commandBytes());
    const second = try proof.decodeCommand(session.ticks()[1].commandBytes());
    try testing.expect(first.jump_pressed and first.jump_held);
    try testing.expect(!second.jump_pressed and second.jump_held);
    try testing.expectEqual(@as(f32, 1), second.move_axis);
    try testing.expectEqual(@as(?u64, 0), client.controllerState().last_jump_tick);
}

test "playback ignores conflicting live gameplay and frame timing" {
    var session = try recording(testing.allocator, 160, 1);
    defer session.deinit();
    var a = try proof.Proof.init(testing.allocator, session.metadata, session.initial);
    defer a.deinit();
    var b = try proof.Proof.init(testing.allocator, session.metadata, session.initial);
    defer b.deinit();
    var pa = try replay.Player.init(&session, session.metadata, session.initial, try a.digest());
    defer pa.deinit();
    var pb = try replay.Player.init(&session, session.metadata, session.initial, try b.digest());
    defer pb.deinit();
    var live = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    var clock = try fixed.Clock.init(.{});
    for (0..160) |index| {
        try pending.acceptFrame(try live.update(.{ .keyboard = .{ .a = true, .space = index % 2 == 0 } }));
        const ignored_gameplay = pending.consumeTick();
        try testing.expectEqual(@as(f32, -1), ignored_gameplay.move_axis);
        _ = try clock.beginFrame(if (index % 2 == 0) 0 else 10);
        try testing.expect(try a.replayTick(&pa));
        try testing.expect(try b.replayTick(&pb));
    }
    try testing.expectEqualDeep(a.controllerState(), b.controllerState());
    try testing.expect((try a.digest()).eql(try b.digest()));
    try testing.expect(clock.lifetime_discarded_time > 0);
}

test "state contributors reject duplicate unordered and excessive identities" {
    const entry = replay.Contributor{ .identity = .{ .id = 2, .version = 1 }, .digest = try goldenDigest() };
    try testing.expectError(error.ContributorOrder, replay.stateDigest(&.{ entry, entry }));
    try testing.expectError(error.ContributorOrder, replay.stateDigest(&.{ entry, .{ .identity = .{ .id = 1, .version = 1 }, .digest = entry.digest } }));
    try testing.expectError(error.TooManyContributors, replay.stateDigest(&(@as([17]replay.Contributor, @splat(entry)))));
    try testing.expectError(error.InvalidMetadata, replay.stateDigest(&.{}));
    const changed_version = try replay.contributorDigest(.{ .id = 2, .version = 2 }, "x");
    const original = try replay.contributorDigest(.{ .id = 2, .version = 1 }, "x");
    try testing.expect(!original.eql(changed_version));
}

test "every production controller field participates in its digest" {
    const initial = try proof.initialEnvelope(0);
    var client = try proof.Proof.init(testing.allocator, try proof.metadata(), &initial);
    defer client.deinit();
    const state = client.controllerState();
    const original = try proof.controllerDigest(state);
    inline for (@typeInfo(@TypeOf(state)).@"struct".fields) |field| {
        var changed = state;
        const value = &@field(changed, field.name);
        switch (@typeInfo(field.type)) {
            .float => value.* += 1,
            .int => value.* += 1,
            .bool => value.* = !value.*,
            .@"enum" => value.* = if (@intFromEnum(value.*) == 0) @enumFromInt(1) else @enumFromInt(0),
            .optional => value.* = if (value.* == null) 7 else null,
            .@"struct" => value.x += 1,
            else => @compileError("Review controller digest coverage for new field type"),
        }
        try testing.expect(!original.eql(try proof.controllerDigest(changed)));
    }
}

test "no allocation or resize succeeds or is attempted during record play and checkpoint ticks" {
    var failing = testing.FailingAllocator.init(testing.allocator, .{});
    var allocation_audit = AllocationAudit{ .backing = failing.allocator() };
    const allocator = allocation_audit.allocator();
    const initial = try proof.initialEnvelope(0);
    const metadata = try proof.metadata();
    var recording_client = try proof.Proof.init(allocator, metadata, &initial);
    defer recording_client.deinit();
    var playing_client = try proof.Proof.init(allocator, metadata, &initial);
    defer playing_client.deinit();
    var session = try replay.Session.init(allocator, metadata, proof.channels, &initial, try recording_client.digest(), 120);
    defer session.deinit();
    const allocations_before = failing.allocations;
    const resize_before = failing.resize_index;
    allocation_audit.locked = true;
    failing.fail_index = failing.alloc_index;
    failing.resize_fail_index = failing.resize_index;
    for (0..120) |index| {
        var command = neutral;
        command.move_axis = 1;
        command.jump_pressed = index == 4;
        try recording_client.recordTick(&session, command, if (index == 20) .{ .metres_per_second = 5 } else null);
    }
    try session.finish();
    var player = try replay.Player.init(&session, metadata, &initial, try playing_client.digest());
    defer player.deinit();
    while (try playing_client.replayTick(&player)) {}
    var bytes: [12000]u8 = undefined;
    _ = try session.encode(&bytes);
    try testing.expectEqualDeep(recording_client.controllerState(), playing_client.controllerState());
    try testing.expect((try recording_client.digest()).eql(try playing_client.digest()));
    try testing.expectEqual(allocations_before, failing.allocations);
    try testing.expectEqual(resize_before, failing.resize_index);
    try testing.expect(!failing.has_induced_failure);
    try testing.expectEqual(@as(usize, 0), allocation_audit.attempted_while_locked);
    std.debug.print("RR1_ALLOCATION_OK ticks=120 record+replay allocation_resize_remap_attempts=0\n", .{});
}

test "recorder and decoder allocation failure cleanup" {
    const artifact = try goldenArtifact();
    for (0..2) |index| {
        var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = index });
        try testing.expectError(error.OutOfMemory, replay.Session.init(failing.allocator(), try proof.metadata(), proof.channels, &.{0}, try goldenDigest(), 1));
        try testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        var decoding = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = index });
        try testing.expectError(error.OutOfMemory, replay.decode(decoding.allocator(), &artifact, proof.channels, 1));
        try testing.expectEqual(decoding.allocated_bytes, decoding.freed_bytes);
    }
    var malformed = artifact;
    malformed[200] = 8;
    try reseal(&malformed);
    var tracking = testing.FailingAllocator.init(testing.allocator, .{});
    try testing.expectError(error.UnknownRecordKind, replay.decode(tracking.allocator(), &malformed, proof.channels, 1));
    try testing.expectEqual(tracking.allocated_bytes, tracking.freed_bytes);
}

test "proof initialization failure releases every acquired resource" {
    const initial = try proof.initialEnvelope(0);
    var index: usize = 0;
    while (index < 200) : (index += 1) {
        var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = index });
        if (proof.Proof.init(failing.allocator(), try proof.metadata(), &initial)) |value| {
            var client = value;
            client.deinit();
            try testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
            return;
        } else |err| {
            try testing.expect(err == error.OutOfMemory or err == error.AllocationFailure);
            try testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        }
    }
    return error.InitializationNeverSucceeded;
}

test "bounded writer propagates sink failure" {
    var session = try recording(testing.allocator, 1, 1);
    defer session.deinit();
    var failing_writer: std.Io.Writer = .failing;
    var scratch: [1000]u8 = undefined;
    try testing.expectError(error.WriteFailed, session.write(&failing_writer, &scratch));
    var sink: [1000]u8 = undefined;
    var writer = std.Io.Writer.fixed(&sink);
    try session.write(&writer, &scratch);
    try testing.expectEqualSlices(u8, try session.encode(&scratch), sink[0..writer.end]);
}

test "invalid exogenous values and decoded nonfinite commands fail" {
    for ([_]f32{ 0, -1, 0.49, 20.01, std.math.inf(f32), std.math.nan(f32) }) |value| {
        try testing.expectError(error.InvalidPayload, proof.encodeEvent(.{ .metres_per_second = value }));
    }
    for ([_]u32{ 0x7f800000, 0xff800000, 0x7fc00001 }) |bits| {
        var payload = [_]u8{ 0, 0, 0, 0, 0 };
        std.mem.writeInt(u32, payload[0..4], bits, .little);
        try testing.expectError(error.NonFiniteFloat, proof.decodeCommand(&payload));
    }
    try testing.expectError(error.InvalidPayload, proof.decodeCommand(&.{ 0, 0, 0, 0 }));
    try testing.expectError(error.InvalidPayload, proof.decodeEvent(&.{ 0, 0, 0 }));
}

const AllocationAudit = struct {
    backing: std.mem.Allocator,
    locked: bool = false,
    attempted_while_locked: usize = 0,

    fn allocator(self: *AllocationAudit) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(context: *anyopaque, length: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *AllocationAudit = @ptrCast(@alignCast(context));
        if (self.locked) {
            self.attempted_while_locked += 1;
            return null;
        }
        return self.backing.rawAlloc(length, alignment, address);
    }

    fn resize(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, length: usize, address: usize) bool {
        const self: *AllocationAudit = @ptrCast(@alignCast(context));
        if (self.locked) {
            self.attempted_while_locked += 1;
            return false;
        }
        return self.backing.rawResize(memory, alignment, length, address);
    }

    fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, length: usize, address: usize) ?[*]u8 {
        const self: *AllocationAudit = @ptrCast(@alignCast(context));
        if (self.locked) {
            self.attempted_while_locked += 1;
            return null;
        }
        return self.backing.rawRemap(memory, alignment, length, address);
    }

    fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *AllocationAudit = @ptrCast(@alignCast(context));
        self.backing.rawFree(memory, alignment, address);
    }
};

test "oversized envelope reserved header and trailing records are rejected" {
    var bytes = try goldenArtifact();
    bytes[26] = 1;
    try testing.expectError(error.InvalidMetadata, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    std.mem.writeInt(u16, bytes[106..108], 1025, .little);
    try testing.expectError(error.PayloadTooLarge, replay.decode(testing.allocator, &bytes, proof.channels, 1));
    bytes = try goldenArtifact();
    try testing.expectError(error.CapacityExceeded, replay.decode(testing.allocator, &bytes, proof.channels, 0));
    var extended: [307]u8 = undefined;
    @memcpy(extended[0..274], bytes[0..274]);
    extended[274] = 1;
    try reseal(&extended);
    try testing.expectError(error.InvalidOrdering, replay.decode(testing.allocator, &extended, proof.channels, 1));
}

test "full recorder does not advance production state" {
    const initial = try proof.initialEnvelope(0);
    var client = try proof.Proof.init(testing.allocator, try proof.metadata(), &initial);
    defer client.deinit();
    const before = try client.digest();
    var session = try replay.Session.init(testing.allocator, try proof.metadata(), proof.channels, &initial, before, 0);
    defer session.deinit();
    try testing.expectError(error.CapacityExceeded, client.recordTick(&session, neutral, null));
    try testing.expect(before.eql(try client.digest()));
    try testing.expectEqual(@as(u64, 0), client.tick());
}

test "recreated state changes with seed or envelope before tick zero" {
    const initial = try proof.initialEnvelope(0);
    var metadata = try proof.metadata();
    var original = try proof.Proof.init(testing.allocator, metadata, &initial);
    defer original.deinit();
    metadata.derivation.root_seed.bytes[15] ^= 1;
    var reseeded = try proof.Proof.init(testing.allocator, metadata, &initial);
    defer reseeded.deinit();
    var moved = try proof.Proof.init(testing.allocator, try proof.metadata(), &try proof.initialEnvelope(1));
    defer moved.deinit();
    try testing.expect(!(try original.digest()).eql(try reseeded.digest()));
    try testing.expect(!(try original.digest()).eql(try moved.digest()));
    try testing.expect(!std.mem.eql(u8, &original.derivedKey(), &reseeded.derivedKey()));
    try testing.expectEqual(@as(u64, 0), original.tick());
    try testing.expectEqual(@as(u64, 0), reseeded.tick());
}
