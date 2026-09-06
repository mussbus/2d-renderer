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

fn verifyTick(player: *replay.Player, observed: []const replay.Event, digest: replay.Digest) !void {
    try player.observe(observed);
    try player.verify(digest);
}

fn capacities(ticks: u32) replay.Capacities {
    return .{
        .ticks = ticks,
        .causal_events = @as(u32, @min(ticks, replay.maximum_events / 2)) * 2,
        .observed_events = @as(u32, @min(ticks, replay.maximum_events / 3)) * 3,
        .named_checkpoints = @intCast(@min(ticks * 3, replay.maximum_checkpoints)),
    };
}

fn recording(allocator: std.mem.Allocator, tick_count: u32, chunk: u8) !replay.Session {
    return recordingWithFinal(allocator, tick_count, chunk, null);
}

fn recordingWithFinal(allocator: std.mem.Allocator, tick_count: u32, chunk: u8, final_state: ?*proof.ControllerState) !replay.Session {
    if (chunk == 0) return error.InvalidBatchSize;
    const metadata = try proof.metadata();
    const initial = try proof.initialEnvelope(0);
    var client = try proof.Proof.init(allocator, metadata, &initial);
    defer client.deinit();
    var result = try replay.Session.init(allocator, metadata, proof.channels, &initial, try client.digest(), capacities(tick_count));
    errdefer result.deinit();
    while (client.tick() < tick_count) {
        const group = @min(chunk, tick_count - client.tick());
        for (0..group) |_| {
            const tick = client.tick();
            var command = neutral;
            command.move_axis = if (tick < 80) 1 else -0.5;
            command.jump_pressed = tick == 8 or tick == 30;
            command.jump_held = tick >= 8 and tick < 42;
            command.jump_released = tick == 42;
            command.dash_pressed = tick == 65;
            command.interact_pressed = tick == 100;
            const causal: []const proof.SetMaximumRunSpeed = if (tick == 50)
                &.{ .{ .metres_per_second = 4 }, .{ .metres_per_second = 6 } }
            else
                &.{};
            var names: [3]replay.CheckpointName = undefined;
            var name_count: usize = 0;
            // Canonical lexical order, even when the final tick shares a phase marker.
            if (tick + 1 == tick_count) {
                names[name_count] = try replay.CheckpointName.init("final_state");
                name_count += 1;
            }
            const first_jump = command.jump_pressed and client.controllerState().last_jump_tick == null;
            if (first_jump) {
                names[name_count] = try replay.CheckpointName.init("jump_accepted");
                name_count += 1;
            }
            if (causal.len > 0) {
                names[name_count] = try replay.CheckpointName.init("speed_changed");
                name_count += 1;
            }
            const observed = try client.recordTick(&result, command, causal, names[0..name_count]);
            if (first_jump) {
                try testing.expect(observed.count > 0);
                try testing.expectEqual(proof.ObservedEvent{ .jump_accepted = .grounded }, try proof.decodeObserved(observed.storage[0]));
            }
        }
    }
    if (final_state) |output| output.* = client.controllerState();
    try result.finish();
    return result;
}

fn recordOffset(artifact: []const u8, kind: u8, tick: u64, ordinal: usize) !usize {
    var offset: usize = replay.header_size + std.mem.readInt(u16, artifact[106..108], .little);
    var found: usize = 0;
    while (offset + 11 <= artifact.len - 32) {
        const size = std.mem.readInt(u16, artifact[offset + 9 ..][0..2], .little);
        if (artifact[offset] == kind and std.mem.readInt(u64, artifact[offset + 1 ..][0..8], .little) == tick) {
            if (found == ordinal) return offset;
            found += 1;
        }
        offset += 11 + @as(usize, size);
    }
    return error.MissingFixtureRecord;
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

test "production proof verifies every observation fingerprint named checkpoint and final state" {
    var final_state: proof.ControllerState = undefined;
    var session = try recordingWithFinal(testing.allocator, 480, 1, &final_state);
    defer session.deinit();
    var bytes: [40000]u8 = undefined;
    const artifact = try session.encode(&bytes);
    var loaded = try replay.decode(testing.allocator, artifact, proof.channels, capacities(480));
    defer loaded.deinit();
    var client = try proof.Proof.init(testing.allocator, loaded.metadata, loaded.initial);
    defer client.deinit();
    var player = try replay.Player.init(&loaded, try proof.metadata(), loaded.initial, try client.digest());
    defer player.deinit();
    while (try client.replayTick(&player)) {}
    try testing.expectEqual(@as(u64, 480), client.tick());
    try testing.expect(session.ticks()[479].fingerprint.eql(try client.digest()));
    try testing.expectEqualDeep(final_state, client.controllerState());
    try testing.expectEqual(@as(u32, 2), loaded.causal_count);
    var jumps: u32 = 0;
    var dashes: u32 = 0;
    var landings: u32 = 0;
    for (loaded.observed_storage[0..loaded.observed_count]) |event| {
        switch (try proof.decodeObserved(event)) {
            .jump_accepted => jumps += 1,
            .dash_started => dashes += 1,
            .landed => landings += 1,
        }
        std.debug.print("RR1_OBSERVED tick={d} ordinal={d} type={d} schema={d}\n", .{ event.tick, event.ordinal, event.identity.id, event.identity.version });
    }
    try testing.expect(jumps > 0 and dashes > 0 and landings > 0);
    try testing.expectEqual(@as(u32, 3), player.verified_named_checkpoints);
    try testing.expectEqualStrings("jump_accepted", loaded.named_storage[0].name.slice());
    try testing.expectEqualStrings("speed_changed", loaded.named_storage[1].name.slice());
    try testing.expectEqualStrings("final_state", loaded.named_storage[2].name.slice());
    try testing.expectEqual(@as(u64, 8), loaded.named_storage[0].tick);
    try testing.expectEqual(@as(u64, 50), loaded.named_storage[1].tick);
    try testing.expectEqual(@as(u64, 479), loaded.named_storage[2].tick);
    std.debug.print("RR1_PROOF_OK ticks=480 fingerprints=480 named=3 bytes={d} final={s} artifact={s}\n", .{ artifact.len, (try client.digest()).formatLowerHex(), (try replay.artifactDigest(artifact[0 .. artifact.len - 32])).formatLowerHex() });
}

test "repeat artifacts and tick-batch grouping are byte identical" {
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
    std.debug.print("RR1_REPEAT_OK ticks=160 runs=3 tick_batches=1,7,1 byte_mismatches=0\n", .{});
}

test "encode decode encode preserves bytes" {
    var source = try recording(testing.allocator, 64, 4);
    defer source.deinit();
    var a: [8000]u8 = undefined;
    var b: [8000]u8 = undefined;
    const artifact = try source.encode(&a);
    var loaded = try replay.decode(testing.allocator, artifact, proof.channels, capacities(64));
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

fn goldenArtifact() ![490]u8 {
    // Independently calculated with Python struct/hashlib from the documented V1 contract.
    const hex =
        "5252315449434b0101000100f000000000000000000000000100000000112233445566778899aabbccddeeff0195d5b84100" ++
        "700080000000000000010100000000000000000000000195d5b8410070008000000000000002010000000000000000000000" ++
        "0100000001000400ae3d963ed538ed66cca97c684de91225e4ca374a439dae0a4e0bae8d79cd775f99128778c503a3c55a80" ++
        "f0721f5f6beec8be9cea91dc4265fef60f58c783b97501000000010001000000010001000000010001000100000002000000" ++
        "0200000001000000020000000000000001000000000000000005000000003f030200000000000000000c0000000100000001" ++
        "000000a0400200000000000000000c0001000100000001000000c04004000000000000000009000000010000000100000400" ++
        "0000000000000008000100020000000100030000000000000000200099128778c503a3c55a80f0721f5f6beec8be9cea91dc" ++
        "4265fef60f58c783b975050000000000000000260005616c70686199128778c503a3c55a80f0721f5f6beec8be9cea91dc42" ++
        "65fef60f58c783b9750500000000000000002600056f6d65676199128778c503a3c55a80f0721f5f6beec8be9cea91dc4265" ++
        "fef60f58c783b975e404ce8406310a93a0ed6ed7ccb5e173945ff4825c66d61c3a5c82a01d1f5c23";
    var output: [490]u8 = undefined;
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
    const digest = try replay.artifactDigest(artifact[0..458]);
    try testing.expectEqualStrings("e404ce8406310a93a0ed6ed7ccb5e173945ff4825c66d61c3a5c82a01d1f5c23", &digest.formatLowerHex());
    const key = try foundation.determinism.deriveKey((try proof.metadata()).derivation, &.{ "rr1.controller", "speed" });
    try testing.expectEqualStrings("a98a1a13b0ba3400809e1642b1b534d87498a9d31fb878b6f8f23566f3ed4fab", &(replay.Digest{ .bytes = key }).formatLowerHex());
    const alternate = try foundation.determinism.deriveKey((try proof.metadata()).derivation, &.{ "speed", "rr1.controller" });
    try testing.expect(!std.mem.eql(u8, &key, &alternate));
}

test "golden complete V1 encoding independently fixes field widths order and checksum" {
    const expected = try goldenArtifact();
    var session = try replay.Session.init(testing.allocator, try proof.metadata(), proof.channels, &.{ 0, 0, 0, 0 }, try goldenDigest(), capacities(1));
    defer session.deinit();
    try session.append(0, &.{ 0, 0, 0, 0x3f, 3 }, &.{ try proof.causalRecord(0, 0, .{ .metres_per_second = 5 }), try proof.causalRecord(0, 1, .{ .metres_per_second = 6 }) }, &.{ try proof.observedRecord(0, 0, .{ .jump_accepted = .grounded }), try proof.observedRecord(0, 1, .dash_started) }, try goldenDigest(), &.{ try replay.CheckpointName.init("alpha"), try replay.CheckpointName.init("omega") });
    try session.finish();
    var output: [490]u8 = undefined;
    try testing.expectEqualSlices(u8, &expected, try session.encode(&output));
    var loaded = try replay.decode(testing.allocator, &expected, proof.channels, capacities(1));
    defer loaded.deinit();
    try testing.expectEqual(@as(u32, 1), loaded.count);
    try testing.expectEqual(@as(f32, 0.5), (try proof.decodeCommand(loaded.ticks()[0].commandBytes())).move_axis);
}

test "atomic capacity payload and lifecycle failures" {
    const metadata = try proof.metadata();
    const digest = try goldenDigest();
    var session = try replay.Session.init(testing.allocator, metadata, proof.channels, &.{0}, digest, capacities(1));
    defer session.deinit();
    try testing.expectError(error.SessionNotFinished, session.encodedSize());
    try testing.expectError(error.InvalidTick, session.append(1, &.{ 0, 0, 0, 0, 0 }, &.{}, &.{}, digest, &.{}));
    try testing.expectError(error.PayloadTooLarge, session.append(0, &(@as([65]u8, @splat(0))), &.{}, &.{}, digest, &.{}));
    try testing.expectError(error.PayloadTooLarge, replay.Event.init(0, 0, proof.schema, &(@as([65]u8, @splat(0)))));
    try testing.expectEqual(@as(u32, 0), session.count);
    try testing.expectEqual(@as(u32, 0), session.causal_count);
    try session.append(0, &.{ 0, 0, 0, 0, 0 }, &.{}, &.{}, digest, &.{});
    try testing.expectError(error.InvalidTick, session.append(0, &.{ 0, 0, 0, 0, 0 }, &.{}, &.{}, digest, &.{}));
    try testing.expectError(error.CapacityExceeded, session.append(1, &.{ 0, 0, 0, 0, 0 }, &.{}, &.{}, digest, &.{}));
    try testing.expectEqual(@as(u32, 1), session.count);
    try session.finish();
    try testing.expectError(error.SessionFinished, session.append(1, &.{ 0, 0, 0, 0, 0 }, &.{}, &.{}, digest, &.{}));
    try testing.expectError(error.SessionFinished, session.finish());
    var too_small: [10]u8 = @splat(0x55);
    try testing.expectError(error.OutputTooSmall, session.encode(&too_small));
    try testing.expectEqualSlices(u8, &(@as([10]u8, @splat(0x55))), &too_small);
    try testing.expectError(error.CapacityExceeded, replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, digest, capacities(replay.maximum_ticks + 1)));
    try testing.expectError(error.PayloadTooLarge, replay.Session.init(testing.allocator, metadata, proof.channels, &(@as([1025]u8, @splat(0))), digest, capacities(1)));
}

test "explicit nonzero start domain and u64 overflow" {
    var metadata = try proof.metadata();
    metadata.start_tick = std.math.maxInt(u64) - 1;
    var session = try replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, try goldenDigest(), capacities(2));
    defer session.deinit();
    try session.append(metadata.start_tick, &.{ 0, 0, 0, 0, 0 }, &.{}, &.{}, try goldenDigest(), &.{});
    try testing.expectError(error.TickOverflow, session.append(std.math.maxInt(u64), &.{ 0, 0, 0, 0, 0 }, &.{}, &.{}, try goldenDigest(), &.{}));
    try session.finish();
    var bytes: [1000]u8 = undefined;
    var loaded = try replay.decode(testing.allocator, try session.encode(&bytes), proof.channels, capacities(2));
    defer loaded.deinit();
    try testing.expectEqual(metadata.start_tick, loaded.ticks()[0].tick);
    var overflow = try goldenArtifact();
    std.mem.writeInt(u64, overflow[16..24], std.math.maxInt(u64), .little);
    try reseal(&overflow);
    try testing.expectError(error.TickOverflow, replay.decode(testing.allocator, &overflow, proof.channels, capacities(1)));
}

test "decoder rejects truncation at every byte boundary" {
    const artifact = try goldenArtifact();
    for (0..artifact.len) |length| {
        if (replay.decode(testing.allocator, artifact[0..length], proof.channels, capacities(1))) |value| {
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
        if (replay.decode(testing.allocator, &bytes, proof.channels, capacities(1))) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.AcceptedCorruptArtifact;
        } else |err| {
            try testing.expect(err != error.StateDivergence and err != error.ObservedEventDivergence and err != error.NamedCheckpointDivergence);
        }
    }
}

test "unknown required records channels and versions fail closed" {
    var bytes = try goldenArtifact();
    bytes[216] = 9;
    try reseal(&bytes);
    try testing.expectError(error.UnknownRecordKind, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    bytes[8] = 2;
    try testing.expectError(error.UnsupportedVersion, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    bytes[10] = 2;
    try testing.expectError(error.IncompatibleProtocol, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    bytes[12] = 60;
    try testing.expectError(error.IncompatibleTickRate, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    bytes[24] = 2;
    try testing.expectError(error.DerivationMismatch, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    for ([_]usize{ 172, 176, 178, 182, 184, 188 }) |offset| {
        bytes = try goldenArtifact();
        bytes[offset] = 2;
        try reseal(&bytes);
        try testing.expectError(error.UnsupportedChannel, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    }
}

test "decoder validates record phases ticks counts sizes and canonical payload" {
    for ([_]usize{ 217, 233, 256, 279, 299, 318, 361, 410 }) |tick_offset| {
        var bytes = try goldenArtifact();
        bytes[tick_offset] = 1;
        try reseal(&bytes);
        try testing.expectError(error.InvalidTick, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    }
    var bytes = try goldenArtifact();
    bytes[232] = 1;
    try reseal(&bytes);
    try testing.expectError(error.InvalidOrdering, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    bytes[196] = 0;
    try reseal(&bytes);
    try testing.expectError(error.InvalidCounts, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    bytes[204] = 0;
    try testing.expectError(error.InvalidCounts, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    bytes[225] = 65;
    try reseal(&bytes);
    try testing.expectError(error.PayloadTooLarge, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    std.mem.writeInt(u32, bytes[227..231], 0x80000000, .little);
    try reseal(&bytes);
    try testing.expectError(error.NonCanonicalFloat, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    bytes[231] = 0x80;
    try reseal(&bytes);
    try testing.expectError(error.InvalidPayload, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    bytes[212] = 1;
    try reseal(&bytes);
    try testing.expectError(error.InitialStateMismatch, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
}

test "duplicate decreasing and skipped ticks cannot load even with valid integrity" {
    var session = try recording(testing.allocator, 3, 1);
    defer session.deinit();
    var output: [1000]u8 = undefined;
    const length = (try session.encode(&output)).len;
    const second_tick_offset = (try recordOffset(output[0..length], 1, 1, 0)) + 1;
    for ([_]u64{ 0, 2, std.math.maxInt(u64) }) |bad_tick| {
        _ = try session.encode(&output);
        std.mem.writeInt(u64, output[second_tick_offset..][0..8], bad_tick, .little);
        try reseal(output[0..length]);
        try testing.expectError(error.InvalidTick, replay.decode(testing.allocator, output[0..length], proof.channels, capacities(3)));
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
    const offset = (try recordOffset(output[0..length], if (event) 2 else 1, changed_tick, if (event) 1 else 0)) +
        (if (event) @as(usize, 19) else 11);
    std.mem.writeInt(u32, output[offset..][0..4], @bitCast(@as(f32, if (event) 7 else -1)), .little);
    try reseal(output[0..length]);
    var changed = try replay.decode(testing.allocator, output[0..length], proof.channels, capacities(100));
    defer changed.deinit();
    var client = try proof.Proof.init(testing.allocator, changed.metadata, changed.initial);
    defer client.deinit();
    var player = try replay.Player.init(&changed, try proof.metadata(), changed.initial, try client.digest());
    defer player.deinit();
    for (0..changed_tick) |_| try testing.expect(try client.replayTick(&player));
    try testing.expectError(error.StateDivergence, client.replayTick(&player));
    const failure = player.divergence orelse return error.MissingDivergence;
    try testing.expectEqual(@as(u64, changed_tick), failure.tick);
    try testing.expect(failure.expected.eql(source.ticks()[changed_tick].fingerprint));
    try testing.expect(failure.actual.eql(try client.digest()));
    try testing.expect(!failure.expected.eql(failure.actual));
    try testing.expectError(error.StateDivergence, player.next());
    try testing.expectError(error.StateDivergence, verifyTick(&player, &.{}, failure.expected));
    try testing.expectEqualDeep(failure, player.divergence.?);
    std.debug.print("RR1_DIVERGENCE tick={d} expected={s} actual={s}\n", .{ failure.tick, failure.expected.formatLowerHex(), failure.actual.formatLowerHex() });
    try testing.expectEqual(@as(u64, changed_tick + 1), client.tick());
}

test "player enforces verify before advance and handles empty sessions" {
    var session = try recording(testing.allocator, 1, 1);
    defer session.deinit();
    var player = try replay.Player.init(&session, session.metadata, session.initial, session.initial_state);
    defer player.deinit();
    try testing.expectError(error.NoPendingTick, verifyTick(&player, &.{}, session.initial_state));
    const record = (try player.next()).?;
    try testing.expectError(error.VerificationPending, player.next());
    try verifyTick(&player, record.observed, record.fingerprint);
    try testing.expectEqual(@as(?replay.TickView, null), try player.next());
    try testing.expectError(error.NoPendingTick, verifyTick(&player, record.observed, record.fingerprint));
    var empty = try recording(testing.allocator, 0, 1);
    defer empty.deinit();
    var empty_player = try replay.Player.init(&empty, empty.metadata, empty.initial, empty.initial_state);
    defer empty_player.deinit();
    try testing.expectEqual(@as(?replay.TickView, null), try empty_player.next());
}

test "application pending edges are recorded only after tick consumption" {
    var builder = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    try pending.acceptFrame(try builder.update(.{ .keyboard = .{ .space = true, .d = true } }));
    try testing.expectEqual(@as(u8, 1), pending.pendingEdgeCount());
    const initial = try proof.initialEnvelope(0);
    var client = try proof.Proof.init(testing.allocator, try proof.metadata(), &initial);
    defer client.deinit();
    var session = try replay.Session.init(testing.allocator, try proof.metadata(), proof.channels, &initial, try client.digest(), capacities(2));
    defer session.deinit();
    _ = try client.recordTick(&session, pending.consumeTick(), &.{}, &.{});
    _ = try client.recordTick(&session, pending.consumeTick(), &.{}, &.{});
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
    var fault_client = try proof.Proof.init(allocator, metadata, &initial);
    defer fault_client.deinit();
    var session = try replay.Session.init(allocator, metadata, proof.channels, &initial, try recording_client.digest(), capacities(120));
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
        command.dash_pressed = index == 4;
        _ = try recording_client.recordTick(&session, command, if (index == 20)
            &.{ .{ .metres_per_second = 4 }, .{ .metres_per_second = 5 } }
        else
            &.{}, if (index == 4) &.{ try replay.CheckpointName.init("jump_and_dash"), try replay.CheckpointName.init("transition") } else if (index == 20) &.{try replay.CheckpointName.init("speed_changed")} else &.{});
    }
    try session.finish();
    var player = try replay.Player.init(&session, metadata, &initial, try playing_client.digest());
    defer player.deinit();
    while (try playing_client.replayTick(&player)) {}
    var bytes: [12000]u8 = undefined;
    _ = try session.encode(&bytes);
    try testing.expectEqualDeep(recording_client.controllerState(), playing_client.controllerState());
    try testing.expect((try recording_client.digest()).eql(try playing_client.digest()));
    try testing.expectEqual(@as(u32, 3), player.verified_named_checkpoints);
    try testing.expect(session.observed_count >= 2);
    var fault_player = try replay.Player.init(&session, metadata, &initial, try fault_client.digest());
    defer fault_player.deinit();
    for (0..4) |_| try testing.expect(try fault_client.replayTick(&fault_player));
    const failed_record = (try fault_player.next()).?;
    const actual_events = try fault_client.step(failed_record.tick, try proof.decodeCommand(failed_record.command), &.{});
    try testing.expectEqual(@as(u8, 2), actual_events.count);
    var wrong_digest = try fault_client.digest();
    wrong_digest.bytes[0] ^= 1;
    try testing.expectError(error.ObservedEventDivergence, verifyTick(&fault_player, &.{}, wrong_digest));
    try testing.expect(fault_player.observed_divergence != null and fault_player.divergence != null and fault_player.checkpoint_divergence != null);
    try testing.expectError(error.ObservedEventDivergence, fault_client.replayTick(&fault_player));
    try testing.expectEqual(@as(u64, 5), fault_client.tick());
    try testing.expectEqual(allocations_before, failing.allocations);
    try testing.expectEqual(resize_before, failing.resize_index);
    try testing.expect(!failing.has_induced_failure);
    try testing.expectEqual(@as(usize, 0), allocation_audit.attempted_while_locked);
    std.debug.print("RR1_ALLOCATION_OK ticks=120 causal+observed+fingerprints+named+divergence allocation_resize_remap_attempts=0\n", .{});
}

test "recorder and decoder allocation failure cleanup" {
    const artifact = try goldenArtifact();
    for (0..5) |index| {
        var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = index });
        try testing.expectError(error.OutOfMemory, replay.Session.init(failing.allocator(), try proof.metadata(), proof.channels, &.{0}, try goldenDigest(), capacities(1)));
        try testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        var decoding = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = index });
        try testing.expectError(error.OutOfMemory, replay.decode(decoding.allocator(), &artifact, proof.channels, capacities(1)));
        try testing.expectEqual(decoding.allocated_bytes, decoding.freed_bytes);
    }
    var malformed = artifact;
    malformed[216] = 8;
    try reseal(&malformed);
    var tracking = testing.FailingAllocator.init(testing.allocator, .{});
    try testing.expectError(error.UnknownRecordKind, replay.decode(tracking.allocator(), &malformed, proof.channels, capacities(1)));
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
    try testing.expectError(error.InvalidMetadata, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    std.mem.writeInt(u16, bytes[106..108], 1025, .little);
    try testing.expectError(error.PayloadTooLarge, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = try goldenArtifact();
    try testing.expectError(error.CapacityExceeded, replay.decode(testing.allocator, &bytes, proof.channels, capacities(0)));
    var extended: [491]u8 = undefined;
    @memcpy(extended[0..458], bytes[0..458]);
    extended[458] = 1;
    try reseal(&extended);
    try testing.expectError(error.InvalidOrdering, replay.decode(testing.allocator, &extended, proof.channels, capacities(1)));
}

test "full recorder does not advance production state" {
    const initial = try proof.initialEnvelope(0);
    var client = try proof.Proof.init(testing.allocator, try proof.metadata(), &initial);
    defer client.deinit();
    const before = try client.digest();
    var session = try replay.Session.init(testing.allocator, try proof.metadata(), proof.channels, &initial, before, capacities(0));
    defer session.deinit();
    try testing.expectError(error.CapacityExceeded, client.recordTick(&session, neutral, &.{}, &.{}));
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

test "half-open interval is dense including empty and nonzero domains" {
    var metadata = try proof.metadata();
    metadata.start_tick = 17;
    var session = try replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, try goldenDigest(), capacities(2));
    defer session.deinit();
    const command = try proof.encodeCommand(neutral);
    try testing.expectEqual(@as(u64, 17), try session.endTickExclusive());
    try session.append(17, &command, &.{}, &.{}, try goldenDigest(), &.{});
    try testing.expectEqual(@as(u64, 18), try session.endTickExclusive());
    try testing.expectError(error.InvalidTick, session.append(19, &command, &.{}, &.{}, try goldenDigest(), &.{}));
    try testing.expectEqual(@as(u32, 1), session.count);
    try session.finish();
    var bytes: [1000]u8 = undefined;
    const artifact = try session.encode(&bytes);
    var loaded = try replay.decode(testing.allocator, artifact, proof.channels, capacities(2));
    defer loaded.deinit();
    try testing.expectEqual(@as(u64, 18), try loaded.endTickExclusive());
    try testing.expectEqual(@as(u64, 17), loaded.ticks()[0].tick);
    std.mem.writeInt(u64, bytes[replay.header_size + 1 ..][0..8], 18, .little);
    try reseal(bytes[0..artifact.len]);
    try testing.expectError(error.InvalidTick, replay.decode(testing.allocator, bytes[0..artifact.len], proof.channels, capacities(2)));

    metadata.start_tick = std.math.maxInt(u64);
    var empty = try replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, try goldenDigest(), capacities(0));
    defer empty.deinit();
    try empty.finish();
    var empty_loaded = try replay.decode(testing.allocator, try empty.encode(&bytes), proof.channels, capacities(0));
    defer empty_loaded.deinit();
    try testing.expectEqual(std.math.maxInt(u64), try empty_loaded.endTickExclusive());
    try testing.expectEqual(@as(u32, 0), empty_loaded.count);
}

test "missing and duplicate command records fail loading after integrity is recomputed" {
    const original = try goldenArtifact();
    const offset = try recordOffset(&original, 1, 0, 0);
    const record_size = 16;
    var missing: [490 - record_size]u8 = undefined;
    @memcpy(missing[0..offset], original[0..offset]);
    @memcpy(missing[offset..], original[offset + record_size ..]);
    try reseal(&missing);
    try testing.expectError(error.InvalidOrdering, replay.decode(testing.allocator, &missing, proof.channels, capacities(1)));

    var duplicate: [490 + record_size]u8 = undefined;
    @memcpy(duplicate[0 .. offset + record_size], original[0 .. offset + record_size]);
    @memcpy(duplicate[offset + record_size ..], original[offset..]);
    try reseal(&duplicate);
    try testing.expectError(error.InvalidOrdering, replay.decode(testing.allocator, &duplicate, proof.channels, capacities(1)));
}

test "same-tick causal order is encoded and changes the actual controller result" {
    const initial = try proof.initialEnvelope(0);
    const metadata = try proof.metadata();
    var a = try proof.Proof.init(testing.allocator, metadata, &initial);
    defer a.deinit();
    var b = try proof.Proof.init(testing.allocator, metadata, &initial);
    defer b.deinit();
    var source = try replay.Session.init(testing.allocator, metadata, proof.channels, &initial, try a.digest(), capacities(1));
    defer source.deinit();
    _ = try a.recordTick(&source, neutral, &.{ .{ .metres_per_second = 4 }, .{ .metres_per_second = 6 } }, &.{});
    _ = try b.step(0, neutral, &.{ .{ .metres_per_second = 6 }, .{ .metres_per_second = 4 } });
    try testing.expect(!(try a.digest()).eql(try b.digest()));
    try source.finish();
    var bytes: [1000]u8 = undefined;
    var loaded = try replay.decode(testing.allocator, try source.encode(&bytes), proof.channels, capacities(1));
    defer loaded.deinit();
    const causal = loaded.view(&loaded.ticks()[0]).causal;
    try testing.expectEqual(@as(usize, 2), causal.len);
    try testing.expectEqual(@as(u16, 0), causal[0].ordinal);
    try testing.expectEqual(@as(u16, 1), causal[1].ordinal);
    try testing.expectEqual(@as(f32, 4), (try proof.decodeEvent(try causal[0].payloadBytes())).metres_per_second);
    try testing.expectEqual(@as(f32, 6), (try proof.decodeEvent(try causal[1].payloadBytes())).metres_per_second);
}

test "causal and observed ordinals reject duplicate decreasing skipped and overflow values" {
    const original = try goldenArtifact();
    for ([_]u8{ 2, 4 }) |kind| {
        for ([_]struct { ordinal: usize, value: u16, expected: replay.Error }{
            .{ .ordinal = 1, .value = 0, .expected = error.InvalidEventOrdinal },
            .{ .ordinal = 0, .value = 1, .expected = error.InvalidEventOrdinal },
            .{ .ordinal = 1, .value = 3, .expected = error.InvalidEventOrdinal },
            .{ .ordinal = 1, .value = std.math.maxInt(u16), .expected = error.OrdinalOverflow },
        }) |change| {
            var bytes = original;
            const offset = try recordOffset(&bytes, kind, 0, change.ordinal);
            std.mem.writeInt(u16, bytes[offset + 11 ..][0..2], change.value, .little);
            try reseal(&bytes);
            try testing.expectError(change.expected, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
        }
        var reversed = original;
        const first = try recordOffset(&reversed, kind, 0, 0);
        const second = try recordOffset(&reversed, kind, 0, 1);
        std.mem.writeInt(u16, reversed[first + 11 ..][0..2], 1, .little);
        std.mem.writeInt(u16, reversed[second + 11 ..][0..2], 0, .little);
        try reseal(&reversed);
        try testing.expectError(error.InvalidEventOrdinal, replay.decode(testing.allocator, &reversed, proof.channels, capacities(1)));
    }
}

test "event ticks types schemas and bounded payloads fail closed during load" {
    const original = try goldenArtifact();
    for ([_]u8{ 2, 4 }) |kind| {
        const offset = try recordOffset(&original, kind, 0, 0);
        var bytes = original;
        std.mem.writeInt(u64, bytes[offset + 1 ..][0..8], 1, .little);
        try reseal(&bytes);
        try testing.expectError(error.InvalidTick, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
        bytes = original;
        std.mem.writeInt(u32, bytes[offset + 13 ..][0..4], 99, .little);
        try reseal(&bytes);
        try testing.expectError(error.UnknownEventType, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
        bytes = original;
        std.mem.writeInt(u16, bytes[offset + 17 ..][0..2], 2, .little);
        try reseal(&bytes);
        try testing.expectError(error.UnsupportedEventSchema, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
        bytes = original;
        std.mem.writeInt(u16, bytes[offset + 9 ..][0..2], 73, .little);
        try reseal(&bytes);
        try testing.expectError(error.PayloadTooLarge, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    }
}

test "real production jump and dash observations share a tick in canonical order" {
    const initial = try proof.initialEnvelope(0);
    var client = try proof.Proof.init(testing.allocator, try proof.metadata(), &initial);
    defer client.deinit();
    var command = neutral;
    command.jump_pressed = true;
    command.dash_pressed = true;
    const observed = try client.step(0, command, &.{});
    try testing.expectEqual(@as(u8, 2), observed.count);
    try testing.expectEqual(proof.ObservedEvent{ .jump_accepted = .grounded }, try proof.decodeObserved(observed.storage[0]));
    try testing.expectEqual(proof.ObservedEvent.dash_started, try proof.decodeObserved(observed.storage[1]));
    try testing.expectEqual(@as(u64, 0), observed.storage[0].tick);
    try testing.expectEqual(@as(u16, 0), observed.storage[0].ordinal);
    try testing.expectEqual(@as(u16, 1), observed.storage[1].ordinal);
}

test "independent golden covers observed events and multiple named markers" {
    const bytes = try goldenArtifact();
    var session = try replay.decode(testing.allocator, &bytes, proof.channels, capacities(1));
    defer session.deinit();
    const tick = session.view(&session.ticks()[0]);
    try testing.expectEqual(@as(usize, 2), tick.observed.len);
    try testing.expectEqual(proof.ObservedEvent{ .jump_accepted = .grounded }, try proof.decodeObserved(tick.observed[0]));
    try testing.expectEqual(proof.ObservedEvent.dash_started, try proof.decodeObserved(tick.observed[1]));
    try testing.expectEqual(@as(usize, 2), tick.checkpoints.len);
    try testing.expectEqualStrings("alpha", tick.checkpoints[0].name.slice());
    try testing.expectEqualStrings("omega", tick.checkpoints[1].name.slice());
    for (tick.checkpoints) |checkpoint| {
        try testing.expectEqual(tick.tick, checkpoint.tick);
        try testing.expect(checkpoint.digest.eql(tick.fingerprint));
    }
    var encoded: [490]u8 = undefined;
    try testing.expectEqualSlices(u8, &bytes, try session.encode(&encoded));
}

test "observed mismatch categories preserve tick ordinal and bounded expected actual values" {
    const bytes = try goldenArtifact();
    var session = try replay.decode(testing.allocator, &bytes, proof.channels, capacities(1));
    defer session.deinit();
    const tick = session.view(&session.ticks()[0]);
    for ([_]replay.ObservedMismatch{ .missing, .extra, .wrong_type, .wrong_schema, .wrong_payload, .wrong_order, .wrong_tick }) |category| {
        var actual = [_]replay.Event{ tick.observed[0], tick.observed[1], try proof.observedRecord(0, 2, .dash_started) };
        var count: usize = 2;
        var ordinal: u16 = 0;
        switch (category) {
            .missing => {
                count = 1;
                ordinal = 1;
            },
            .extra => {
                count = 3;
                ordinal = 2;
            },
            .wrong_type => actual[0].identity.id = 99,
            .wrong_schema => actual[0].identity.version = 2,
            .wrong_payload => actual[0].payload[0] = 1,
            .wrong_order => {
                actual[0] = tick.observed[1];
                actual[0].ordinal = 0;
                actual[1] = tick.observed[0];
                actual[1].ordinal = 1;
            },
            .wrong_tick => actual[0].tick = 1,
        }
        var player = try replay.Player.init(&session, session.metadata, session.initial, session.initial_state);
        defer player.deinit();
        _ = try player.next();
        try testing.expectError(error.ObservedEventDivergence, verifyTick(&player, actual[0..count], tick.fingerprint));
        const failure = player.observed_divergence orelse return error.MissingObservedDiagnostic;
        try testing.expectEqual(category, failure.category);
        try testing.expectEqual(@as(u64, 0), failure.tick);
        try testing.expectEqual(ordinal, failure.ordinal);
        if (ordinal < tick.observed.len) try testing.expectEqualDeep(tick.observed[ordinal], failure.expected.?) else try testing.expect(failure.expected == null);
        if (ordinal < count) try testing.expectEqualDeep(actual[ordinal], failure.actual.?) else try testing.expect(failure.actual == null);
        try testing.expect(player.divergence == null);
        try testing.expectError(error.ObservedEventDivergence, player.next());
        try testing.expectError(error.ObservedEventDivergence, verifyTick(&player, tick.observed, tick.fingerprint));
        try testing.expectEqualDeep(failure, player.observed_divergence.?);
        try testing.expectEqual(@as(u32, 0), player.cursor);
    }
}

test "valid resealed observed expectation diverges after real tick without driving state" {
    var source = try recording(testing.allocator, 20, 3);
    defer source.deinit();
    var bytes: [4000]u8 = undefined;
    const size = (try source.encode(&bytes)).len;
    const offset = try recordOffset(bytes[0..size], 4, 8, 0);
    bytes[offset + 19] = 1; // Canonical accepted-jump source coyote, actual result is grounded.
    try reseal(bytes[0..size]);
    var changed = try replay.decode(testing.allocator, bytes[0..size], proof.channels, capacities(20));
    defer changed.deinit();
    var client = try proof.Proof.init(testing.allocator, changed.metadata, changed.initial);
    defer client.deinit();
    var player = try replay.Player.init(&changed, changed.metadata, changed.initial, try client.digest());
    defer player.deinit();
    for (0..8) |_| try testing.expect(try client.replayTick(&player));
    try testing.expectError(error.ObservedEventDivergence, client.replayTick(&player));
    const failure = player.observed_divergence.?;
    try testing.expectEqual(@as(u64, 8), failure.tick);
    try testing.expectEqual(@as(u16, 0), failure.ordinal);
    try testing.expectEqual(replay.ObservedMismatch.wrong_payload, failure.category);
    try testing.expectEqual(@as(u8, 1), failure.expected.?.payload[0]);
    try testing.expectEqual(@as(u8, 0), failure.actual.?.payload[0]);
    try testing.expect(player.divergence == null);
    try testing.expect((try client.digest()).eql(source.ticks()[8].fingerprint));
    try testing.expectEqual(@as(u64, 9), client.tick());
    try testing.expectError(error.ObservedEventDivergence, client.replayTick(&player));
    try testing.expectEqual(@as(u64, 9), client.tick());
    std.debug.print("RR1_OBSERVED_DIVERGENCE tick=8 ordinal=0 category=wrong_payload expected=1/1:coyote actual=1/1:grounded state_equal=true next_tick_blocked=true\n", .{});
}

test "byte corruption fails integrity before any semantic playback" {
    var bytes = try goldenArtifact();
    const offset = try recordOffset(&bytes, 4, 0, 0);
    bytes[offset + 19] = 1;
    try testing.expectError(error.CorruptArtifact, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
}

test "named identifiers enforce lowercase ASCII length and grammar" {
    for ([_][]const u8{ "", "A", "_first", "1first", "with space", "hy-phen", "dot.name", "café", "line\nbreak", "null\x00byte" }) |bad|
        try testing.expectError(error.InvalidCheckpointIdentifier, replay.CheckpointName.init(bad));
    try testing.expectError(error.InvalidCheckpointIdentifier, replay.CheckpointName.init(&(@as([33]u8, @splat('a')))));
    const longest = try replay.CheckpointName.init(&(@as([32]u8, @splat('z'))));
    try testing.expectEqual(@as(usize, 32), longest.slice().len);
    const valid = try replay.CheckpointName.init("after_jump_2");
    try testing.expectEqualStrings("after_jump_2", valid.slice());
    var malformed = valid;
    malformed.length = 33;
    try testing.expectError(error.InvalidCheckpointIdentifier, malformed.validate());
}

test "named marker duplicates across ticks and within a tick are atomic failures" {
    var session = try replay.Session.init(testing.allocator, try proof.metadata(), proof.channels, &.{}, try goldenDigest(), capacities(3));
    defer session.deinit();
    const command = try proof.encodeCommand(neutral);
    const alpha = try replay.CheckpointName.init("alpha");
    const omega = try replay.CheckpointName.init("omega");
    try testing.expectError(error.DuplicateCheckpoint, session.append(0, &command, &.{}, &.{}, try goldenDigest(), &.{ alpha, alpha }));
    try testing.expectError(error.CheckpointOrder, session.append(0, &command, &.{}, &.{}, try goldenDigest(), &.{ omega, alpha }));
    try testing.expectEqual(@as(u32, 0), session.count);
    try session.append(0, &command, &.{}, &.{}, try goldenDigest(), &.{ alpha, omega });
    try testing.expectError(error.DuplicateCheckpoint, session.append(1, &command, &.{}, &.{}, try goldenDigest(), &.{alpha}));
    try testing.expectEqual(@as(u32, 1), session.count);
    try testing.expectEqual(@as(u8, 2), session.named_count);
}

test "named bytes reject duplicate order invalid name tick digest and encoding version" {
    const original = try goldenArtifact();
    const first = try recordOffset(&original, 5, 0, 0);
    const second = try recordOffset(&original, 5, 0, 1);
    var bytes = original;
    @memcpy(bytes[second + 12 ..][0..5], "alpha");
    try reseal(&bytes);
    try testing.expectError(error.DuplicateCheckpoint, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = original;
    @memcpy(bytes[first + 12 ..][0..5], "omega");
    @memcpy(bytes[second + 12 ..][0..5], "alpha");
    try reseal(&bytes);
    try testing.expectError(error.CheckpointOrder, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = original;
    bytes[first + 12] = 'A';
    try reseal(&bytes);
    try testing.expectError(error.InvalidCheckpointIdentifier, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = original;
    bytes[first + 11] = 33;
    try reseal(&bytes);
    try testing.expectError(error.InvalidCheckpointIdentifier, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = original;
    bytes[first + 1] = 1;
    try reseal(&bytes);
    try testing.expectError(error.InvalidTick, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = original;
    bytes[first + 17] ^= 1;
    try reseal(&bytes);
    try testing.expectError(error.CheckpointDigestMismatch, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
    bytes = original;
    bytes[190] = 2;
    try reseal(&bytes);
    try testing.expectError(error.UnsupportedVersion, replay.decode(testing.allocator, &bytes, proof.channels, capacities(1)));
}

test "event and marker capacities fail explicitly without partially appending" {
    const metadata = try proof.metadata();
    const digest = try goldenDigest();
    const command = try proof.encodeCommand(neutral);
    const causal = try proof.causalRecord(0, 0, .{ .metres_per_second = 6 });
    const observed = try proof.observedRecord(0, 0, .dash_started);
    const name = try replay.CheckpointName.init("phase");
    var session = try replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, digest, .{ .ticks = 1 });
    defer session.deinit();
    try testing.expectError(error.CausalCapacityExceeded, session.append(0, &command, &.{causal}, &.{}, digest, &.{}));
    try testing.expectError(error.ObservedCapacityExceeded, session.append(0, &command, &.{}, &.{observed}, digest, &.{}));
    try testing.expectError(error.CheckpointCapacityExceeded, session.append(0, &command, &.{}, &.{}, digest, &.{name}));
    try testing.expectEqual(@as(u32, 0), session.count);
    try testing.expectEqual(@as(u32, 0), session.causal_count);
    try testing.expectEqual(@as(u32, 0), session.observed_count);
    try testing.expectEqual(@as(u8, 0), session.named_count);
    try testing.expectError(error.CausalCapacityExceeded, replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, digest, .{ .ticks = 1, .causal_events = replay.maximum_events + 1 }));
    try testing.expectError(error.ObservedCapacityExceeded, replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, digest, .{ .ticks = 1, .observed_events = replay.maximum_events + 1 }));
    try testing.expectError(error.CheckpointCapacityExceeded, replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, digest, .{ .ticks = 1, .named_checkpoints = 33 }));
}

test "per-tick event bounds and global marker capacity are enforced" {
    const metadata = try proof.metadata();
    const digest = try goldenDigest();
    const command = try proof.encodeCommand(neutral);
    var session = try replay.Session.init(testing.allocator, metadata, proof.channels, &.{}, digest, .{ .ticks = 5, .causal_events = 16, .observed_events = 16, .named_checkpoints = 32 });
    defer session.deinit();
    var events: [9]replay.Event = undefined;
    for (&events, 0..) |*event, ordinal| event.* = try proof.causalRecord(0, @intCast(ordinal), .{ .metres_per_second = 6 });
    try testing.expectError(error.OrdinalOverflow, session.append(0, &command, &events, &.{}, digest, &.{}));
    try testing.expectError(error.ObservedCapacityExceeded, session.append(0, &command, &.{}, &events, digest, &.{}));
    for (0..4) |tick| {
        var names: [8]replay.CheckpointName = undefined;
        for (&names, 0..) |*name, index| {
            var buffer: [32]u8 = undefined;
            name.* = try replay.CheckpointName.init(try std.fmt.bufPrint(&buffer, "point_{d:0>2}", .{tick * 8 + index}));
        }
        try session.append(tick, &command, &.{}, &.{}, digest, &names);
    }
    try testing.expectEqual(@as(u8, 32), session.named_count);
    try testing.expectError(error.CheckpointCapacityExceeded, session.append(4, &command, &.{}, &.{}, digest, &.{try replay.CheckpointName.init("point_extra")}));
    try testing.expectEqual(@as(u32, 4), session.count);
}

test "adapter preflight refuses missing observation or marker capacity before simulation" {
    const initial = try proof.initialEnvelope(0);
    const metadata = try proof.metadata();
    var client = try proof.Proof.init(testing.allocator, metadata, &initial);
    defer client.deinit();
    const digest = try client.digest();
    var session = try replay.Session.init(testing.allocator, metadata, proof.channels, &initial, digest, .{ .ticks = 1 });
    defer session.deinit();
    try testing.expectError(error.ObservedCapacityExceeded, client.recordTick(&session, neutral, &.{}, &.{}));
    try testing.expectEqual(@as(u64, 0), client.tick());
    try testing.expect((try client.digest()).eql(digest));
    var markers = try replay.Session.init(testing.allocator, metadata, proof.channels, &initial, digest, .{ .ticks = 1, .observed_events = 3 });
    defer markers.deinit();
    try testing.expectError(error.CheckpointCapacityExceeded, client.recordTick(&markers, neutral, &.{}, &.{try replay.CheckpointName.init("phase")}));
    try testing.expectError(error.CausalCapacityExceeded, client.recordTick(&markers, neutral, &.{.{ .metres_per_second = 6 }}, &.{}));
    try testing.expectEqual(@as(u64, 0), client.tick());
    try testing.expect((try client.digest()).eql(digest));
}

test "channel registries reject unordered duplicate invalid and excessive required types" {
    var channels = proof.channels;
    const entry = channels.observed.types[0];
    const metadata = try proof.metadata();
    const digest = try goldenDigest();
    for ([_][]const replay.Channel{ &.{}, &.{ entry, entry }, &.{ channels.observed.types[1], entry } }) |types| {
        channels.observed.types = types;
        try testing.expectError(error.InvalidMetadata, replay.Session.init(testing.allocator, metadata, channels, &.{}, digest, capacities(1)));
    }
    const too_many = [_]replay.Channel{entry} ** 9;
    channels.observed.types = &too_many;
    try testing.expectError(error.InvalidMetadata, replay.Session.init(testing.allocator, metadata, channels, &.{}, digest, capacities(1)));
}

test "playback invocation batches preserve final state and marker evaluation counts" {
    var session = try recording(testing.allocator, 160, 7);
    defer session.deinit();
    var expected: ?proof.ControllerState = null;
    for ([_]usize{ 1, 7, 23 }) |batch| {
        var client = try proof.Proof.init(testing.allocator, session.metadata, session.initial);
        defer client.deinit();
        var player = try replay.Player.init(&session, session.metadata, session.initial, try client.digest());
        defer player.deinit();
        while (client.tick() < session.count) {
            const count = @min(batch, session.count - client.tick());
            for (0..count) |_| try testing.expect(try client.replayTick(&player));
        }
        try testing.expect(!(try client.replayTick(&player)));
        try testing.expectEqual(@as(u32, 3), player.verified_named_checkpoints);
        if (expected) |value| try testing.expectEqualDeep(value, client.controllerState()) else expected = client.controllerState();
    }
    std.debug.print("RR1_STORAGE tick={d} event={d} named={d} bytes; proof480 capacities=480,960,1440,32\n", .{ @sizeOf(replay.Tick), @sizeOf(replay.Event), @sizeOf(replay.NamedCheckpoint) });
}

test "valid command change retains observed state and named failures at the same first tick" {
    var source = try recording(testing.allocator, 20, 1);
    defer source.deinit();
    var bytes: [4000]u8 = undefined;
    const size = (try source.encode(&bytes)).len;
    const command = try recordOffset(bytes[0..size], 1, 8, 0);
    bytes[command + 15] &= ~@as(u8, 1);
    try reseal(bytes[0..size]);
    var loaded = try replay.decode(testing.allocator, bytes[0..size], proof.channels, capacities(20));
    defer loaded.deinit();
    var client = try proof.Proof.init(testing.allocator, loaded.metadata, loaded.initial);
    defer client.deinit();
    var player = try replay.Player.init(&loaded, loaded.metadata, loaded.initial, try client.digest());
    defer player.deinit();
    for (0..8) |_| try testing.expect(try client.replayTick(&player));
    try testing.expectError(error.ObservedEventDivergence, client.replayTick(&player));
    const observed = player.observed_divergence.?;
    const state = player.divergence.?;
    const marker = player.checkpoint_divergence.?;
    try testing.expectEqual(replay.ObservedMismatch.missing, observed.category);
    try testing.expectEqual(@as(u64, 8), observed.tick);
    try testing.expectEqual(@as(u64, 8), state.tick);
    try testing.expectEqual(@as(u64, 8), marker.state.tick);
    try testing.expectEqualStrings("jump_accepted", marker.name.slice());
    try testing.expect(state.expected.eql(source.ticks()[8].fingerprint));
    try testing.expect(state.actual.eql(try client.digest()));
    try testing.expectError(error.ObservedEventDivergence, client.replayTick(&player));
    try testing.expectEqualDeep(observed, player.observed_divergence.?);
    try testing.expectEqualDeep(state, player.divergence.?);
    try testing.expectEqualDeep(marker, player.checkpoint_divergence.?);
    try testing.expectEqual(@as(u64, 9), client.tick());
}

test "player requires observed comparison before state verification and preserves both failures" {
    const bytes = try goldenArtifact();
    var session = try replay.decode(testing.allocator, &bytes, proof.channels, capacities(1));
    defer session.deinit();
    var player = try replay.Player.init(&session, session.metadata, session.initial, session.initial_state);
    defer player.deinit();
    try testing.expectError(error.NoPendingTick, player.observe(&.{}));
    const record = (try player.next()).?;
    try testing.expectError(error.VerificationPending, player.verify(record.fingerprint));
    try testing.expectEqual(@as(u32, 0), player.cursor);
    try player.observe(&.{});
    try testing.expectEqual(replay.ObservedMismatch.missing, player.observed_divergence.?.category);
    try testing.expectError(error.ObservedEventDivergence, player.next());
    var drift = record.fingerprint;
    drift.bytes[0] ^= 1;
    try testing.expectError(error.ObservedEventDivergence, player.verify(drift));
    try testing.expect(player.divergence != null and player.checkpoint_divergence != null);
    const saved = player.divergence.?;
    try testing.expectError(error.ObservedEventDivergence, player.verify(record.fingerprint));
    try testing.expectEqualDeep(saved, player.divergence.?);
}
