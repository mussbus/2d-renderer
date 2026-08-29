const std = @import("std");
const foundation = @import("foundation");

const canonical_data = foundation.canonical_data;
const determinism = foundation.determinism;
const diagnostics = foundation.diagnostics;
const identity = foundation.identity;
const version = foundation.version;

test "seed and key derivation are stable keyed and domain-separated" {
    const context = try derivationContext();
    const seed_a = try determinism.deriveSeed(context, &.{ "level_7", "entity_42" });
    const seed_b = try determinism.deriveSeed(context, &.{ "level_7", "entity_42" });
    const seed_reordered = try determinism.deriveSeed(context, &.{ "entity_42", "level_7" });
    const seed_ambiguous_other = try determinism.deriveSeed(context, &.{ "level_7entity_", "42" });
    const key = try determinism.deriveKey(context, &.{ "level_7", "entity_42" });
    try std.testing.expectEqualStrings("6b00742bb4af43281b71229730f8f709", &seed_a.formatLowerHex());
    try std.testing.expectEqualStrings(
        "2823de51114f8ce37afeeaa40cbe1455bce52eb356888b4a7604ba6612cd8c7c",
        &(canonical_data.Sha256Digest{ .bytes = key }).formatLowerHex(),
    );
    try std.testing.expect(seed_a.eql(seed_b));
    try std.testing.expect(!seed_a.eql(seed_reordered));
    try std.testing.expect(!seed_a.eql(seed_ambiguous_other));
    try std.testing.expect(!std.mem.eql(u8, &seed_a.bytes, key[0..16]));

    var changed_generator = context;
    changed_generator.generator_version = version.GeneratorVersion.init(2, 1, 1);
    var changed_algorithm = context;
    changed_algorithm.algorithm_version = version.AlgorithmVersion.init(4, 3, 3);
    try std.testing.expect(!seed_a.eql(try determinism.deriveSeed(changed_generator, &.{ "level_7", "entity_42" })));
    try std.testing.expect(!seed_a.eql(try determinism.deriveSeed(changed_algorithm, &.{ "level_7", "entity_42" })));

    const encoded = seed_a.formatLowerHex();
    try std.testing.expect((try determinism.Seed128.parseLowerHex(&encoded)).eql(seed_a));
    try std.testing.expectError(error.InvalidSeed, determinism.Seed128.parseLowerHex("ABCDEF"));
}

test "scene time uses normalized explicit rational sub-ticks" {
    const time = try determinism.SceneTime.init(-3, 2, 4);
    try std.testing.expectEqual(@as(i64, -3), time.tick);
    try std.testing.expectEqual(@as(u32, 1), time.sub_tick.?.numerator);
    try std.testing.expectEqual(@as(u32, 2), time.sub_tick.?.denominator);
    const exact_tick = try determinism.SceneTime.init(9, 0, 1);
    try std.testing.expect(exact_tick.sub_tick == null);
    const negative_half = try determinism.SceneTime.init(-1, 2, 4);
    try std.testing.expectEqual(@as(i64, -1), negative_half.tick);
    try std.testing.expectEqual(@as(u32, 1), negative_half.sub_tick.?.numerator);
    try std.testing.expectEqual(@as(u32, 2), negative_half.sub_tick.?.denominator);
    try std.testing.expectError(error.InvalidSubTick, determinism.SceneTime.init(0, 1, 0));
    try std.testing.expectError(error.InvalidSubTick, determinism.SceneTime.init(0, 2, 2));
}

test "diagnostics sort identically across insertion permutations" {
    const asset = try identity.AssetId.parseCanonical("01890f46-0f13-7cc2-98c4-dc0c0c07398f");
    const entity = try identity.EntityId.parseCanonical("01890f46-0f13-7cc2-98c4-dc0c0c073990");
    const entries = [_]diagnostics.Diagnostic{
        .{
            .severity = .warning,
            .code = .invalid_reference,
            .schema = .{ .id = asset, .version = version.SchemaVersion.init(1, 0, 0) },
            .object_path = "entities/player",
            .property_path = "mesh",
            .reference = diagnostics.ReferenceIdentity.entity(entity),
            .message = "reference is unresolved",
        },
        .{
            .severity = .error_severity,
            .code = .invalid_spatial_value,
            .object_path = "entities/player",
            .property_path = "transform.scale",
            .message = "scale contains zero",
        },
        .{
            .severity = .error_severity,
            .code = .duplicate_identity,
            .object_path = "entities/enemy",
            .reference = diagnostics.ReferenceIdentity.asset(asset),
            .message = "identity is duplicated",
        },
    };
    var storage_one: [3]diagnostics.Diagnostic = undefined;
    var storage_two: [3]diagnostics.Diagnostic = undefined;
    var first = diagnostics.Collector.init(&storage_one);
    var second = diagnostics.Collector.init(&storage_two);
    for (entries) |entry| try first.add(entry);
    var index: usize = entries.len;
    while (index > 0) {
        index -= 1;
        try second.add(entries[index]);
    }
    const sorted_one = first.sorted();
    const sorted_two = second.sorted();
    for (sorted_one, sorted_two) |left, right| {
        try std.testing.expectEqual(left.code, right.code);
        try std.testing.expectEqualStrings(left.object_path, right.object_path);
        try std.testing.expectEqualStrings(left.property_path, right.property_path);
    }

    var zero_storage: [0]diagnostics.Diagnostic = .{};
    var full = diagnostics.Collector.init(&zero_storage);
    try std.testing.expectError(error.CapacityExceeded, full.add(entries[0]));
}

fn derivationContext() !determinism.DerivationContext {
    return .{
        .root_seed = .{ .bytes = [_]u8{0x5a} ** 16 },
        .generator_id = try identity.GeneratorId.parseCanonical("01890f46-0f13-7cc2-98c4-dc0c0c07398f"),
        .generator_version = version.GeneratorVersion.init(2, 1, 0),
        .algorithm_id = try identity.AlgorithmId.parseCanonical("01890f46-0f13-7cc2-98c4-dc0c0c073990"),
        .algorithm_version = version.AlgorithmVersion.init(4, 3, 2),
    };
}
