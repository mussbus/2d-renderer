const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const support = @import("support.zig");
const goldens = @import("fixtures/goldens.zig");

test "level canonical round trip materializes defaults and preserves unknown optional payload" {
    const tag_z = try scene_core.metadata.TagId.init("world:street_lamp");
    const tag_a = try scene_core.metadata.TagId.init("gameplay:light_source");
    const extension_record = scene_core.extension.ExtensionRecord{
        .type_id = try scene_core.extension.ComponentTypeId.init("r.light"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .optional_preserve,
        .canonical_payload = "{\"color\":[1,0.75,0.5],\"intensity\":12}",
    };
    const parent = scene_core.entity.EntityInstanceDefinition{
        .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d"),
        .tags = &.{ tag_z, tag_a },
        .extensions = &.{extension_record},
        .camera_definition = .{
            .projection = .perspective,
            .perspective = .{ .focal_length_mm = 35, .sensor_width_mm = 36, .sensor_height_mm = 24 },
            .near_clip_m = 0.1,
            .far_clip_m = 500,
        },
    };
    const child = scene_core.entity.EntityInstanceDefinition{
        .entity_id = try support.entityId("b7e8669c-2d61-5e4f-a898-1be001ee1720"),
        .parent = .{ .entity_id = parent.entity_id, .requirement = .required },
        .enabled = .disabled,
    };
    const definition = scene_core.level.LevelDefinition{
        .header = try support.header(
            scene_core.asset.level_kind,
            scene_core.asset.level_schema_id,
            "8b0bff06-f67d-5ac9-a3d0-5534844ae2cd",
        ),
        .origin = .{ .x_mm = 4_000_000_000, .y_mm = 1250, .z_mm = -2_000_000_000 },
        .entities = &.{ child, parent },
    };
    var canonical_buffer: [16 * 1024]u8 = undefined;
    const canonical = try scene_core.serialization.serializeLevel(definition, &canonical_buffer);
    try std.testing.expect(canonical.len > 0);
    try std.testing.expect(canonical[canonical.len - 1] == '}');
    try std.testing.expect(std.mem.indexOfScalar(u8, canonical, '\n') == null);
    try std.testing.expect(std.mem.indexOf(u8, canonical, "\"gameplay:light_source\",\"world:street_lamp\"") != null);
    var notes: [2]scene_core.migration.MigrationNote = undefined;
    var report = scene_core.migration.MigrationReport{ .storage = &notes };
    var parsed = try scene_core.serialization.parseLevel(std.testing.allocator, canonical, &report);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 0), report.notes().len);
    try std.testing.expectEqualStrings(extension_record.canonical_payload, parsed.value.entities[0].extensions[0].canonical_payload);
    var second_buffer: [16 * 1024]u8 = undefined;
    const second = try scene_core.serialization.serializeLevel(parsed.value, &second_buffer);
    try std.testing.expectEqualStrings(canonical, second);
}

test "canonical level bytes and hash ignore input entity and tag order" {
    const id_a = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d");
    const id_b = try support.entityId("b7e8669c-2d61-5e4f-a898-1be001ee1720");
    const tag_a = try scene_core.metadata.TagId.init("a:first");
    const tag_b = try scene_core.metadata.TagId.init("z:last");
    const header = try support.header(
        scene_core.asset.level_kind,
        scene_core.asset.level_schema_id,
        "8b0bff06-f67d-5ac9-a3d0-5534844ae2cd",
    );
    const first = scene_core.level.LevelDefinition{
        .header = header,
        .origin = .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 },
        .entities = &.{
            .{ .entity_id = id_b },
            .{ .entity_id = id_a, .tags = &.{ tag_b, tag_a } },
        },
    };
    const reordered = scene_core.level.LevelDefinition{
        .header = header,
        .origin = first.origin,
        .entities = &.{
            .{ .entity_id = id_a, .tags = &.{ tag_a, tag_b } },
            .{ .entity_id = id_b },
        },
    };
    var first_buffer: [8192]u8 = undefined;
    var second_buffer: [8192]u8 = undefined;
    const first_bytes = try scene_core.serialization.serializeLevel(first, &first_buffer);
    const second_bytes = try scene_core.serialization.serializeLevel(reordered, &second_buffer);
    try std.testing.expectEqualStrings(first_bytes, second_bytes);
    const first_hash = try scene_core.serialization.canonicalHash(first_bytes);
    const second_hash = try scene_core.serialization.canonicalHash(second_bytes);
    try std.testing.expect(first_hash.eql(second_hash));
}

test "prefab and world canonical documents round trip without duplicating prefab data" {
    const prefab_reference = try support.assetRef("2b0a68db-832e-5aa4-9f75-fe3f19320c44", "f.prefab", 0x31);
    const level_reference = try support.assetRef("8b0bff06-f67d-5ac9-a3d0-5534844ae2cd", "f.level", 0x41);
    const prefab_definition = scene_core.prefab.PrefabDefinition{
        .header = try support.header(scene_core.asset.prefab_kind, scene_core.asset.prefab_schema_id, "2b0a68db-832e-5aa4-9f75-fe3f19320c44"),
        .nodes = &.{
            .{ .node_id = try scene_core.prefab.PrefabNodeId.init("lamp_root") },
            .{ .node_id = try scene_core.prefab.PrefabNodeId.init("lamp_head"), .parent = try scene_core.prefab.PrefabNodeId.init("lamp_root") },
        },
    };
    var prefab_buffer: [8192]u8 = undefined;
    const prefab_bytes = try scene_core.serialization.serializePrefab(prefab_definition, &prefab_buffer);
    var parsed_prefab = try scene_core.serialization.parsePrefab(std.testing.allocator, prefab_bytes);
    defer parsed_prefab.deinit();
    try std.testing.expectEqual(@as(usize, 2), parsed_prefab.value.nodes.len);

    const world_definition = scene_core.world.WorldDefinition{
        .header = try support.header(scene_core.asset.world_kind, scene_core.asset.world_schema_id, "f8c08c6e-6f8d-54f2-82dd-22e934b40b48"),
        .level_refs = &.{level_reference},
        .persistent_entities = &.{.{
            .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d"),
            .prefab_ref = prefab_reference,
        }},
    };
    var world_buffer: [8192]u8 = undefined;
    const world_bytes = try scene_core.serialization.serializeWorld(world_definition, &world_buffer);
    var parsed_world = try scene_core.serialization.parseWorld(std.testing.allocator, world_bytes);
    defer parsed_world.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed_world.value.level_refs.len);
    try std.testing.expect(parsed_world.value.persistent_entities[0].prefab_ref.?.eql(prefab_reference));
    try std.testing.expectEqual(@as(usize, 0), parsed_world.value.persistent_entities[0].extensions.len);
}

test "pre-acceptance level migration preserves IDs and reports every non-exact translation" {
    const source = @embedFile("fixtures/legacy_level_v0_9.json");
    const schema_text = scene_core.asset.level_schema_id.formatCanonical();
    try std.testing.expect(std.mem.indexOf(u8, source, &schema_text) != null);
    try std.testing.expect(std.mem.indexOf(u8, source, "\"schema_version\": \"0.9.0\"") != null);
    var note_storage: [2]scene_core.migration.MigrationNote = undefined;
    var report = scene_core.migration.MigrationReport{ .storage = &note_storage };
    var parsed = try scene_core.serialization.parseLevel(std.testing.allocator, source, &report);
    defer parsed.deinit();
    try std.testing.expect(parsed.value.header.schema.id.eql(scene_core.asset.level_schema_id));
    try std.testing.expect(parsed.value.header.schema.version.eql(scene_core.asset.current_schema_version));
    try std.testing.expectEqual(@as(i64, 4_000_000_000), parsed.value.origin.x_mm);
    try std.testing.expectEqual(@as(usize, 2), report.notes().len);
    try std.testing.expectEqual(scene_core.migration.MigrationCode.origin_metres_to_millimetres, report.notes()[0].code);
    const expected_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d");
    try std.testing.expect(parsed.value.entities[0].entity_id.eql(expected_id));
    try std.testing.expectEqual(scene_core.metadata.EnabledIntent.inherit, parsed.value.entities[0].enabled);

    var descriptor_storage: [0]scene_core.extension.Descriptor = .{};
    var registry = scene_core.extension.DescriptorRegistry.init(&descriptor_storage);
    registry.freeze();
    var order: [1]usize = undefined;
    var depths: [1]u8 = undefined;
    try scene_core.validation.validateLevel(parsed.value, &.{}, &.{}, &registry, .{
        .hierarchy_order = &order,
        .hierarchy_depth = &depths,
    });

    var canonical_buffer: [8192]u8 = undefined;
    const canonical = try scene_core.serialization.serializeLevel(parsed.value, &canonical_buffer);
    try std.testing.expect(std.mem.indexOf(u8, canonical, "\"schema_version\":\"1.0.0\"") != null);
    var current_notes: [2]scene_core.migration.MigrationNote = undefined;
    var current_report = scene_core.migration.MigrationReport{ .storage = &current_notes };
    var current = try scene_core.serialization.parseLevel(std.testing.allocator, canonical, &current_report);
    defer current.deinit();
    try std.testing.expectEqual(@as(usize, 0), current_report.notes().len);
    var second_buffer: [8192]u8 = undefined;
    const second = try scene_core.serialization.serializeLevel(current.value, &second_buffer);
    try std.testing.expectEqualStrings(canonical, second);
}

test "strict parser rejects unknown and duplicate fields and unsupported schema versions" {
    const unknown =
        \\{"asset_identity":{"asset_id":"8b0bff06-f67d-5ac9-a3d0-5534844ae2cd","asset_version":"1.0.0","kind":"f.level","slug":null},"dependencies":[],"payload":{"entities":[],"origin_mm":[0,0,0],"surprise":true},"presentation_ref":null,"producer_identity":{"producer_id":"7bcd9782-6252-5d2f-94be-47e477f0a5aa","producer_version":"1.0.0"},"provenance":null,"schema_identity":{"schema_id":"01a04ad0-e800-7345-a789-abcdef012233","schema_version":"1.0.0"}}
    ;
    var notes: [2]scene_core.migration.MigrationNote = undefined;
    var report = scene_core.migration.MigrationReport{ .storage = &notes };
    try std.testing.expectError(error.UnknownField, scene_core.serialization.parseLevel(std.testing.allocator, unknown, &report));
    const duplicate = "{\"value\":1,\"value\":2}";
    try std.testing.expectError(error.DuplicateField, scene_core.serialization.parseLevel(std.testing.allocator, duplicate, &report));
    const unsupported_minor =
        \\{"asset_identity":{"asset_id":"8b0bff06-f67d-5ac9-a3d0-5534844ae2cd","asset_version":"1.0.0","kind":"f.level","slug":null},"dependencies":[],"payload":{"entities":[],"origin_mm":[0,0,0]},"presentation_ref":null,"producer_identity":{"producer_id":"7bcd9782-6252-5d2f-94be-47e477f0a5aa","producer_version":"1.0.0"},"provenance":null,"schema_identity":{"schema_id":"01a04ad0-e800-7345-a789-abcdef012233","schema_version":"1.1.0"}}
    ;
    try std.testing.expectError(error.UnsupportedSchemaVersion, scene_core.serialization.parseLevel(std.testing.allocator, unsupported_minor, &report));
    const unsupported_major = std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        unsupported_minor,
        "\"schema_version\":\"1.1.0\"",
        "\"schema_version\":\"2.0.0\"",
    ) catch return error.OutOfMemory;
    defer std.testing.allocator.free(unsupported_major);
    try std.testing.expectError(error.UnsupportedSchemaVersion, scene_core.serialization.parseLevel(std.testing.allocator, unsupported_major, &report));
    const malformed = std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        unsupported_minor,
        "\"schema_version\":\"1.1.0\"",
        "\"schema_version\":\"1.0\"",
    ) catch return error.OutOfMemory;
    defer std.testing.allocator.free(malformed);
    try std.testing.expectError(error.InvalidVersion, scene_core.serialization.parseLevel(std.testing.allocator, malformed, &report));
}

test "camera presentation fields remain outside the strict F camera schema" {
    const source =
        \\{"asset_identity":{"asset_id":"8b0bff06-f67d-5ac9-a3d0-5534844ae2cd","asset_version":"1.0.0","kind":"f.level","slug":null},"dependencies":[],"payload":{"entities":[{"camera_definition":{"exposure":1,"far_clip_m":100,"lens_shift":[0,0],"near_clip_m":0.1,"orthographic":null,"perspective":{"focal_length_mm":50,"sensor_height_mm":24,"sensor_width_mm":36},"projection":"perspective"},"classification":"authored","enabled":"inherit","entity_id":"a0610ba8-d264-5dcd-9c43-7ce374501e0d","extensions":[],"layers":[],"local_transform":{"rotation":[0,0,0,1],"scale":[1,1,1],"translation_m":[0,0,0]},"overrides":[],"parent":null,"prefab_ref":null,"presentation_ref":null,"tags":[],"visibility":"inherit","volume_shape_ref":null}],"origin_mm":[0,0,0]},"presentation_ref":null,"producer_identity":{"producer_id":"7bcd9782-6252-5d2f-94be-47e477f0a5aa","producer_version":"1.0.0"},"provenance":null,"schema_identity":{"schema_id":"01a04ad0-e800-7345-a789-abcdef012233","schema_version":"1.0.0"}}
    ;
    var notes: [2]scene_core.migration.MigrationNote = undefined;
    var report = scene_core.migration.MigrationReport{ .storage = &notes };
    try std.testing.expectError(error.UnknownField, scene_core.serialization.parseLevel(std.testing.allocator, source, &report));
}

test "supported current patch input may omit defaults and canonical output materializes them" {
    const source = @embedFile("fixtures/omitted_defaults_level_v1.json");
    var notes: [2]scene_core.migration.MigrationNote = undefined;
    var report = scene_core.migration.MigrationReport{ .storage = &notes };
    var parsed = try scene_core.serialization.parseLevel(std.testing.allocator, source, &report);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u32, 7), parsed.value.header.schema.version.patch);
    var buffer: [8192]u8 = undefined;
    const canonical = try scene_core.serialization.serializeLevel(parsed.value, &buffer);
    try std.testing.expect(std.mem.indexOf(u8, canonical, "\"classification\":\"authored\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, canonical, "\"local_transform\":{\"rotation\":[0,0,0,1]") != null);
    try std.testing.expect(std.mem.indexOf(u8, canonical, "\"dependencies\":[]") != null);
    try std.testing.expect(std.mem.indexOf(u8, canonical, "\"schema_version\":\"1.0.7\"") != null);
}

test "empty level canonical bytes and versioned domain hash match the reviewed golden" {
    const definition = scene_core.level.LevelDefinition{
        .header = try support.header(scene_core.asset.level_kind, scene_core.asset.level_schema_id, "8b0bff06-f67d-5ac9-a3d0-5534844ae2cd"),
        .origin = .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 },
        .entities = &.{},
    };
    var buffer: [4096]u8 = undefined;
    const canonical = try scene_core.serialization.serializeLevel(definition, &buffer);
    const hash = try scene_core.serialization.canonicalHash(canonical);
    try std.testing.expectEqual(@as(usize, 432), canonical.len);
    try std.testing.expectEqualStrings(goldens.empty_level_v1, canonical);
    const formatted = hash.formatLowerHex();
    try std.testing.expectEqualStrings(goldens.empty_level_v1_domain_hash, &formatted);
}

test "representative populated level canonical bytes length hash and unordered inputs are fixed" {
    const prefab_reference = try support.assetRef("2b0a68db-832e-5aa4-9f75-fe3f19320c44", "f.prefab", 0x31);
    const tag_z = try scene_core.metadata.TagId.init("world:street_lamp");
    const tag_a = try scene_core.metadata.TagId.init("gameplay:light_source");
    const interactive_tag = try scene_core.metadata.TagId.init("gameplay:interactive");
    const extension_record = scene_core.extension.ExtensionRecord{
        .type_id = try scene_core.extension.ComponentTypeId.init("r.light"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .optional_preserve,
        .canonical_payload = "{\"color\":[1,0.75,0.5],\"intensity\":12}",
    };
    const parent = scene_core.entity.EntityInstanceDefinition{
        .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d"),
        .local_transform = try foundation.spatial.LocalTransform.init(
            try foundation.spatial.Vec3.init(2, 0, 3),
            .identity,
            .one,
        ),
        .prefab_ref = prefab_reference,
        .tags = &.{ tag_z, tag_a },
        .extensions = &.{extension_record},
        .camera_definition = .{
            .projection = .perspective,
            .perspective = .{ .focal_length_mm = 35, .sensor_width_mm = 36, .sensor_height_mm = 24 },
            .near_clip_m = 0.1,
            .far_clip_m = 500,
        },
    };
    const child = scene_core.entity.EntityInstanceDefinition{
        .entity_id = try support.entityId("b7e8669c-2d61-5e4f-a898-1be001ee1720"),
        .local_transform = try foundation.spatial.LocalTransform.init(
            try foundation.spatial.Vec3.init(-1.5, 0, 2.25),
            .identity,
            .one,
        ),
        .parent = .{ .entity_id = parent.entity_id, .requirement = .required },
        .prefab_ref = prefab_reference,
        .overrides = &.{.{
            .target = .{
                .node_path = "lamp_root/lamp_head",
                .component_type_id = try scene_core.extension.ComponentTypeId.init("r.light"),
                .property_path = "intensity",
            },
            .canonical_value = "24",
        }},
        .tags = &.{interactive_tag},
        .enabled = .disabled,
    };
    var header = try support.header(
        scene_core.asset.level_kind,
        scene_core.asset.level_schema_id,
        "8b0bff06-f67d-5ac9-a3d0-5534844ae2cd",
    );
    header.slug = "representative";
    header.dependencies = &.{.{ .asset = prefab_reference, .class = .semantic_runtime_required }};
    const definition = scene_core.level.LevelDefinition{
        .header = header,
        .origin = .{ .x_mm = 4_000_000_000, .y_mm = 1250, .z_mm = -2_000_000_000 },
        .entities = &.{ child, parent },
    };
    var canonical_buffer: [8192]u8 = undefined;
    const canonical = try scene_core.serialization.serializeLevel(definition, &canonical_buffer);
    try std.testing.expectEqual(@as(usize, 2331), canonical.len);
    try std.testing.expectEqualStrings(goldens.populated_level_v1, canonical);
    const hash = try scene_core.serialization.canonicalHash(canonical);
    try std.testing.expectEqualStrings(goldens.populated_level_v1_domain_hash, &hash.formatLowerHex());

    var parent_sorted = parent;
    parent_sorted.tags = &.{ tag_a, tag_z };
    const reordered = scene_core.level.LevelDefinition{
        .header = header,
        .origin = definition.origin,
        .entities = &.{ parent_sorted, child },
    };
    var reordered_buffer: [8192]u8 = undefined;
    const reordered_bytes = try scene_core.serialization.serializeLevel(reordered, &reordered_buffer);
    try std.testing.expectEqualStrings(canonical, reordered_bytes);
}
