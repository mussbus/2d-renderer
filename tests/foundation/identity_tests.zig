const std = @import("std");
const foundation = @import("foundation");
const canonical_model = @import("canonical_model");

const identity = foundation.identity;
const reference = foundation.reference;
const version = foundation.version;

test "persistent IDs are strong canonical RFC 9562 UUID values" {
    comptime {
        if (identity.AssetId == identity.EntityId) @compileError("persistent ID kinds must not be interchangeable");
        if (identity.AssetId == canonical_model.identity.AssetId) @compileError("H semantic string IDs must remain distinct from F UUID IDs");
    }
    const asset = try identity.AssetId.parseCanonicalVersion("01890f46-0f13-7cc2-98c4-dc0c0c07398f", .v7);
    const next = try identity.AssetId.parseCanonical("01890f46-0f13-7cc2-98c4-dc0c0c073990");
    try std.testing.expectEqualStrings("01890f46-0f13-7cc2-98c4-dc0c0c07398f", &asset.formatCanonical());
    try std.testing.expectEqual(std.math.Order.lt, asset.byteOrder(next));
    try std.testing.expect(@hasDecl(identity.AssetId, "byteOrder"));
    try std.testing.expect(!@hasDecl(identity.AssetId, "order"));
    try std.testing.expectError(error.InvalidCharacter, identity.AssetId.parseCanonical("01890f460-f13-7cc2-98c4-dc0c0c07398f"));
    try std.testing.expectError(error.InvalidCharacter, identity.AssetId.parseCanonical("01890F46-0f13-7cc2-98c4-dc0c0c07398f"));
    try std.testing.expectError(error.InvalidVariant, identity.AssetId.parseCanonical("01890f46-0f13-7cc2-18c4-dc0c0c07398f"));
    try std.testing.expectError(error.InvalidVersion, identity.AssetId.parseCanonical("01890f46-0f13-0cc2-98c4-dc0c0c07398f"));
    try std.testing.expectError(error.NilUuid, identity.AssetId.parseCanonical("00000000-0000-0000-0000-000000000000"));
    try std.testing.expectError(error.NilUuid, identity.AssetId.fromCanonicalBytes([_]u8{0} ** 16));
}

test "UUIDv5 matches the RFC vector and field derivation is unambiguous" {
    const namespace = try identity.NamespaceId.parseCanonical("6ba7b810-9dad-11d1-80b4-00c04fd430c8");
    const vector = identity.uuidV5(identity.AssetId, namespace, "www.widgets.com");
    try std.testing.expectEqualStrings("21f7f8de-8051-5b89-8680-0195ef798b6a", &vector.formatCanonical());

    const first = try identity.uuidV5Fields(identity.AssetId, namespace, &.{ "ab", "c" });
    const second = try identity.uuidV5Fields(identity.AssetId, namespace, &.{ "a", "bc" });
    try std.testing.expectEqualStrings("d2da82ec-d870-5a00-a872-bb67f274fe9f", &first.formatCanonical());
    try std.testing.expect(!first.eql(second));

    const semantic = try identity.SemanticStringId.init("human_base.body");
    const mapped_a = try identity.mapSemanticAssetId(namespace, semantic);
    const mapped_b = try identity.mapSemanticAssetId(namespace, semantic);
    try std.testing.expect(mapped_a.eql(mapped_b));
    try std.testing.expectEqual(identity.UuidVersion.v5, mapped_a.version());
    try std.testing.expectEqualStrings("a444d435-d36f-59e1-b131-05906851406e", &mapped_a.formatCanonical());
}

test "UUIDv7 consumes only explicit clock and entropy inputs" {
    const entropy = [_]u8{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 0x55, 0xaa };
    const first = try identity.uuidV7(identity.EntityId, 1_700_000_000_123, entropy);
    const second = try identity.uuidV7(identity.EntityId, 1_700_000_000_123, entropy);
    try std.testing.expect(first.eql(second));
    try std.testing.expectEqualStrings("018bcfe5-687b-7234-9678-9abcdef055aa", &first.formatCanonical());
    try std.testing.expectEqual(identity.UuidVersion.v7, first.version());
    try std.testing.expectEqual(@as(u8, 0x80), first.bytes[8] & 0xc0);
    const decoded_timestamp = (@as(u64, first.bytes[0]) << 40) |
        (@as(u64, first.bytes[1]) << 32) |
        (@as(u64, first.bytes[2]) << 24) |
        (@as(u64, first.bytes[3]) << 16) |
        (@as(u64, first.bytes[4]) << 8) |
        first.bytes[5];
    try std.testing.expectEqual(@as(u64, 1_700_000_000_123), decoded_timestamp);
    try std.testing.expectError(error.TimestampOutOfRange, identity.uuidV7(identity.EntityId, 0x1_0000_0000_0000, entropy));
}

test "namespace and persistent ID duplicates are rejected" {
    var registrations: [2]identity.NamespaceRegistration = undefined;
    var registry = identity.NamespaceRegistry.init(&registrations);
    const first = try identity.NamespaceId.parseCanonical("6ba7b810-9dad-11d1-80b4-00c04fd430c8");
    const second = try identity.NamespaceId.parseCanonical("6ba7b811-9dad-11d1-80b4-00c04fd430c8");
    try registry.register(.{ .id = first, .owner = "foundation", .purpose = "asset_ids" });
    try std.testing.expectError(error.DuplicateNamespace, registry.register(.{ .id = first, .owner = "world", .purpose = "entity_ids" }));
    try std.testing.expectError(error.DuplicateOwnerPurpose, registry.register(.{ .id = second, .owner = "foundation", .purpose = "asset_ids" }));

    var ordered_storage: [2]identity.NamespaceRegistration = undefined;
    var ordered_registry = identity.NamespaceRegistry.init(&ordered_storage);
    try ordered_registry.register(.{ .id = second, .owner = "world", .purpose = "entity_ids" });
    try ordered_registry.register(.{ .id = first, .owner = "foundation", .purpose = "asset_ids" });
    try std.testing.expect(ordered_registry.registrations()[0].id.eql(first));
    try std.testing.expect(ordered_registry.registrations()[1].id.eql(second));

    const id = try identity.AssetId.parseCanonical("01890f46-0f13-7cc2-98c4-dc0c0c07398f");
    try std.testing.expectError(error.DuplicateId, identity.rejectDuplicateIds(identity.AssetId, &.{ id, id }));
}

test "version kinds parse canonical semantic triples without interchangeability" {
    comptime {
        if (version.SchemaVersion == version.AssetVersion) @compileError("version kinds must remain distinct");
        if (version.GeneratorVersion == version.AlgorithmVersion) @compileError("algorithm and generator versions must remain distinct");
    }
    const parsed = try version.AssetVersion.parse("12.0.37");
    var output: [32]u8 = undefined;
    try std.testing.expectEqualStrings("12.0.37", try parsed.format(&output));
    try std.testing.expectError(error.LeadingZero, version.AssetVersion.parse("01.0.0"));
    try std.testing.expectError(error.MissingComponent, version.AssetVersion.parse("1.0"));
    try std.testing.expectError(error.Overflow, version.AssetVersion.parse("4294967296.0.0"));
}

test "EntityHandle is a non-persistent strongly typed value only" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(identity.EntityHandle));
    const handle = try identity.EntityHandle.init(7, 2);
    try std.testing.expect(handle.isValid());
    try std.testing.expect(handle.eql(.{ .slot = 7, .generation = 2 }));
    try std.testing.expect(!identity.EntityHandle.invalid.isValid());
    try std.testing.expectError(error.InvalidHandle, identity.EntityHandle.init(7, 0));
    try std.testing.expect(!@hasDecl(identity.EntityHandle, "formatCanonical"));
    try std.testing.expect(!@hasDecl(identity.EntityHandle, "parseCanonical"));
}

test "asset refs pin kind version and content hash" {
    const asset = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c07398f", "scene.mesh", 0x11);
    const changed_hash = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c07398f", "scene.mesh", 0x22);
    const wrong_kind = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c07398f", "scene.texture", 0x11);
    var changed_version = asset;
    changed_version.revision.version = version.AssetVersion.init(1, 0, 1);
    try std.testing.expect(!asset.eql(changed_hash));
    try std.testing.expect(!asset.eql(wrong_kind));
    try std.testing.expect(!asset.eql(changed_version));
    try std.testing.expectError(error.InvalidAssetKind, reference.AssetKind.init("Scene.Mesh"));
    try std.testing.expectError(error.InvalidHex, reference.ContentHash.parseLowerHex("ABCDEF"));

    const required = [_]reference.DirectDependency{.{ .asset = asset, .class = .semantic_runtime_required }};
    const optional = [_]reference.DirectDependency{.{ .asset = asset, .class = .optional_presentation }};
    var required_scratch: [1]usize = undefined;
    var optional_scratch: [1]usize = undefined;
    const required_hash = try reference.hashDirectDependencies(.semantic_runtime_required, &required, &required_scratch);
    const optional_hash = try reference.hashDirectDependencies(.optional_presentation, &optional, &optional_scratch);
    try std.testing.expectEqualStrings(
        "a4c94bd2dbf344fbd2da9c5a7cc363bd79e6975e2d56b3ed998e7a73088c88d6",
        &required_hash.formatLowerHex(),
    );
    try std.testing.expect(!required_hash.eql(optional_hash));
}

test "dependency closure hashes are order-independent and class-isolated" {
    const asset_a = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c07398f", "scene.mesh", 0x11);
    const asset_b = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c073990", "scene.buffer", 0x22);
    const asset_c = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c073991", "ui.icon", 0x33);
    const asset_d = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c073992", "ui.icon", 0x44);
    const a_dependencies = [_]reference.DirectDependency{
        .{ .asset = asset_c, .class = .optional_presentation },
        .{ .asset = asset_b, .class = .semantic_runtime_required },
    };
    const a_changed_optional = [_]reference.DirectDependency{
        .{ .asset = asset_d, .class = .optional_presentation },
        .{ .asset = asset_b, .class = .semantic_runtime_required },
    };
    const roots = [_]reference.DirectDependency{.{ .asset = asset_a, .class = .semantic_runtime_required }};
    const catalog_one = [_]reference.DependencyNode{
        .{ .asset = asset_a, .dependencies = &a_dependencies },
        .{ .asset = asset_b, .dependencies = &.{} },
        .{ .asset = asset_c, .dependencies = &.{} },
        .{ .asset = asset_d, .dependencies = &.{} },
    };
    const catalog_two = [_]reference.DependencyNode{
        .{ .asset = asset_d, .dependencies = &.{} },
        .{ .asset = asset_c, .dependencies = &.{} },
        .{ .asset = asset_b, .dependencies = &.{} },
        .{ .asset = asset_a, .dependencies = &a_changed_optional },
    };
    var states_one: [4]u8 = undefined;
    var selected_one: [4]usize = undefined;
    var states_two: [4]u8 = undefined;
    var selected_two: [4]usize = undefined;
    const hash_one = try reference.hashTransitiveDependencySet(.semantic_runtime_required, &roots, &catalog_one, .{
        .states = &states_one,
        .selected_indices = &selected_one,
    });
    const hash_two = try reference.hashTransitiveDependencySet(.semantic_runtime_required, &roots, &catalog_two, .{
        .states = &states_two,
        .selected_indices = &selected_two,
    });
    try std.testing.expectEqualStrings(
        "1f5078214df900758d5fa1702d7a9c3660176d8e9304324cb1bcd203cc6f0ee4",
        &hash_one.formatLowerHex(),
    );
    try std.testing.expect(hash_one.eql(hash_two));
}

test "dependency duplicate mismatch and cycle failures are explicit" {
    const asset_a = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c07398f", "scene.mesh", 0x11);
    const asset_b = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c073990", "scene.buffer", 0x22);
    const duplicate = [_]reference.DirectDependency{
        .{ .asset = asset_a, .class = .semantic_runtime_required },
        .{ .asset = asset_a, .class = .semantic_runtime_required },
    };
    var direct_scratch: [2]usize = undefined;
    try std.testing.expectError(error.DuplicateDependency, reference.hashDirectDependencies(.semantic_runtime_required, &duplicate, &direct_scratch));

    const a_dependencies = [_]reference.DirectDependency{.{ .asset = asset_b, .class = .semantic_runtime_required }};
    const b_dependencies = [_]reference.DirectDependency{.{ .asset = asset_a, .class = .semantic_runtime_required }};
    const cycle_catalog = [_]reference.DependencyNode{
        .{ .asset = asset_a, .dependencies = &a_dependencies },
        .{ .asset = asset_b, .dependencies = &b_dependencies },
    };
    const roots = [_]reference.DirectDependency{.{ .asset = asset_a, .class = .semantic_runtime_required }};
    var states: [2]u8 = undefined;
    var selected: [2]usize = undefined;
    try std.testing.expectError(error.DependencyCycle, reference.hashTransitiveDependencySet(.semantic_runtime_required, &roots, &cycle_catalog, .{
        .states = &states,
        .selected_indices = &selected,
    }));

    const mismatched_b = try makeAssetRef("01890f46-0f13-7cc2-98c4-dc0c0c073990", "scene.buffer", 0x99);
    const mismatched_catalog = [_]reference.DependencyNode{
        .{ .asset = asset_a, .dependencies = &a_dependencies },
        .{ .asset = mismatched_b, .dependencies = &.{} },
    };
    try std.testing.expectError(error.DependencyMismatch, reference.hashTransitiveDependencySet(.semantic_runtime_required, &roots, &mismatched_catalog, .{
        .states = &states,
        .selected_indices = &selected,
    }));

    var wrong_kind_b = asset_b;
    wrong_kind_b.expected_kind = try reference.AssetKind.init("scene.texture");
    const wrong_kind_catalog = [_]reference.DependencyNode{
        .{ .asset = asset_a, .dependencies = &a_dependencies },
        .{ .asset = wrong_kind_b, .dependencies = &.{} },
    };
    try std.testing.expectError(error.DependencyMismatch, reference.hashTransitiveDependencySet(.semantic_runtime_required, &roots, &wrong_kind_catalog, .{
        .states = &states,
        .selected_indices = &selected,
    }));
}

fn makeAssetRef(uuid: []const u8, kind: []const u8, hash_byte: u8) !reference.AssetRef {
    return .{
        .revision = .{
            .asset_id = try identity.AssetId.parseCanonical(uuid),
            .version = version.AssetVersion.init(1, 0, 0),
            .content_hash = .{ .bytes = [_]u8{hash_byte} ** 32 },
        },
        .expected_kind = try reference.AssetKind.init(kind),
    };
}
