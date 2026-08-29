const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const support = @import("support.zig");

test "hierarchy order is parent first with EntityId sibling ties" {
    const parent_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d");
    const child_b_id = try support.entityId("c580c3cd-a3fb-55c7-9991-bb8d8c07fe2f");
    const child_a_id = try support.entityId("b7e8669c-2d61-5e4f-a898-1be001ee1720");
    const entities = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = child_b_id, .parent = .{ .entity_id = parent_id, .requirement = .required } },
        .{ .entity_id = parent_id },
        .{ .entity_id = child_a_id, .parent = .{ .entity_id = parent_id, .requirement = .required } },
    };
    var order: [3]usize = undefined;
    var depths: [3]u8 = undefined;
    const result = try scene_core.hierarchy.evaluationOrder(&entities, &.{}, &order, &depths);
    try std.testing.expectEqual(@as(usize, 1), result[0]);
    try std.testing.expectEqual(@as(usize, 2), result[1]);
    try std.testing.expectEqual(@as(usize, 0), result[2]);
}

test "hierarchy rejects self missing and cyclic parents" {
    const first = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d");
    const second = try support.entityId("b7e8669c-2d61-5e4f-a898-1be001ee1720");
    var order: [2]usize = undefined;
    var depths: [2]u8 = undefined;
    const self_parent = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = first, .parent = .{ .entity_id = first, .requirement = .required } },
    };
    try std.testing.expectError(error.SelfParent, scene_core.hierarchy.evaluationOrder(&self_parent, &.{}, &order, &depths));
    const cycle = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = first, .parent = .{ .entity_id = second, .requirement = .required } },
        .{ .entity_id = second, .parent = .{ .entity_id = first, .requirement = .required } },
    };
    try std.testing.expectError(error.HierarchyCycle, scene_core.hierarchy.evaluationOrder(&cycle, &.{}, &order, &depths));
    const optional_parent = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = second },
        .{ .entity_id = first, .parent = .{ .entity_id = second, .requirement = .optional } },
    };
    try std.testing.expectError(error.OptionalParent, scene_core.hierarchy.evaluationOrder(&optional_parent, &.{}, &order, &depths));
}

test "effective enabled state and lifecycle order follow the accepted parent rules" {
    const parent_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d");
    const child_id = try support.entityId("b7e8669c-2d61-5e4f-a898-1be001ee1720");
    const entities = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = child_id, .parent = .{ .entity_id = parent_id, .requirement = .required }, .enabled = .enabled },
        .{ .entity_id = parent_id, .enabled = .disabled },
    };
    var order: [2]usize = undefined;
    var depths: [2]u8 = undefined;
    const evaluation = try scene_core.hierarchy.evaluationOrder(&entities, &.{}, &order, &depths);
    var enabled: [2]bool = undefined;
    _ = try scene_core.hierarchy.effectiveEnabledStates(&entities, evaluation, &enabled);
    try std.testing.expect(!enabled[0]);
    try std.testing.expect(!enabled[1]);
    var lifecycle: [2]usize = undefined;
    const enable_order = try scene_core.hierarchy.lifecycleOrder(evaluation, true, &lifecycle);
    try std.testing.expectEqual(@as(usize, 1), enable_order[0]);
    const disable_order = try scene_core.hierarchy.lifecycleOrder(evaluation, false, &lifecycle);
    try std.testing.expectEqual(@as(usize, 0), disable_order[0]);
}

test "synthetic catalog enforces one exact revision and kind per AssetId" {
    const exact = try support.assetRef("2b0a68db-832e-5aa4-9f75-fe3f19320c44", "f.prefab", 0x31);
    const catalog = [_]scene_core.validation.CatalogEntry{.{ .asset = exact }};
    try scene_core.validation.resolveExact(&catalog, exact);
    var wrong_hash = exact;
    wrong_hash.revision.content_hash.bytes[0] = 0xff;
    try std.testing.expectError(error.RevisionMismatch, scene_core.validation.resolveExact(&catalog, wrong_hash));
    var wrong_version = exact;
    wrong_version.revision.version = foundation.version.AssetVersion.init(1, 1, 0);
    try std.testing.expectError(error.RevisionMismatch, scene_core.validation.resolveExact(&catalog, wrong_version));
    var wrong_kind = exact;
    wrong_kind.expected_kind = scene_core.asset.level_kind;
    try std.testing.expectError(error.WrongAssetKind, scene_core.validation.resolveExact(&catalog, wrong_kind));
    const missing = try support.assetRef("8b0bff06-f67d-5ac9-a3d0-5534844ae2cd", "f.level", 0x41);
    try std.testing.expectError(error.MissingAsset, scene_core.validation.resolveExact(&catalog, missing));
    const duplicate_catalog = [_]scene_core.validation.CatalogEntry{ .{ .asset = exact }, .{ .asset = wrong_hash } };
    try std.testing.expectError(error.CatalogDuplicate, scene_core.validation.resolveExact(&duplicate_catalog, exact));
}

test "level validation allows declared world anchors and rejects arbitrary cross-level parents" {
    const anchor = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d");
    const child = scene_core.entity.EntityInstanceDefinition{
        .entity_id = try support.entityId("b7e8669c-2d61-5e4f-a898-1be001ee1720"),
        .parent = .{ .entity_id = anchor, .requirement = .required },
    };
    const definition = scene_core.level.LevelDefinition{
        .header = try support.header(scene_core.asset.level_kind, scene_core.asset.level_schema_id, "8b0bff06-f67d-5ac9-a3d0-5534844ae2cd"),
        .origin = .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 },
        .entities = &.{child},
    };
    var descriptor_storage: [1]scene_core.extension.Descriptor = undefined;
    const registry = try support.frozenRegistry(&descriptor_storage);
    var order: [1]usize = undefined;
    var depths: [1]u8 = undefined;
    try scene_core.validation.validateLevel(definition, &.{anchor}, &.{}, &registry, .{
        .hierarchy_order = &order,
        .hierarchy_depth = &depths,
    });
    try std.testing.expectError(error.InvalidHierarchy, scene_core.validation.validateLevel(definition, &.{}, &.{}, &registry, .{
        .hierarchy_order = &order,
        .hierarchy_depth = &depths,
    }));
}

test "world definition composes multiple exact levels and only authored persistent entities" {
    const level_a = try support.assetRef("8b0bff06-f67d-5ac9-a3d0-5534844ae2cd", "f.level", 0x41);
    const level_b = try support.assetRef("5d17a40e-e00c-5636-b09c-3dddaefbd6e5", "f.level", 0x42);
    const definition = scene_core.world.WorldDefinition{
        .header = try support.header(scene_core.asset.world_kind, scene_core.asset.world_schema_id, "f8c08c6e-6f8d-54f2-82dd-22e934b40b48"),
        .level_refs = &.{ level_b, level_a },
        .persistent_entities = &.{.{ .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d") }},
    };
    const catalog = [_]scene_core.validation.CatalogEntry{ .{ .asset = level_a }, .{ .asset = level_b } };
    var descriptor_storage: [1]scene_core.extension.Descriptor = undefined;
    const registry = try support.frozenRegistry(&descriptor_storage);
    var order: [1]usize = undefined;
    var depths: [1]u8 = undefined;
    try scene_core.validation.validateWorld(definition, &catalog, &registry, .{
        .hierarchy_order = &order,
        .hierarchy_depth = &depths,
    });
    var preview = definition;
    preview.persistent_entities = &.{.{
        .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d"),
        .classification = .editor_preview,
    }};
    try std.testing.expectError(error.WrongEntityClassification, scene_core.validation.validateWorld(preview, &catalog, &registry, .{
        .hierarchy_order = &order,
        .hierarchy_depth = &depths,
    }));
}

test "prefab nesting cycles and invalid override targets fail deterministically" {
    const ref_a = try support.assetRef("2b0a68db-832e-5aa4-9f75-fe3f19320c44", "f.prefab", 0x31);
    const ref_b = try support.assetRef("39bff85d-3f8f-5ea4-9786-2ac6f01f4daf", "f.prefab", 0x32);
    const prefab_a = scene_core.prefab.PrefabDefinition{
        .header = try support.header(scene_core.asset.prefab_kind, scene_core.asset.prefab_schema_id, "2b0a68db-832e-5aa4-9f75-fe3f19320c44"),
        .nodes = &.{.{ .node_id = try scene_core.prefab.PrefabNodeId.init("root"), .nested_prefab_ref = ref_b }},
    };
    const light_extension = scene_core.extension.ExtensionRecord{
        .type_id = try scene_core.extension.ComponentTypeId.init("r.light"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .required,
        .canonical_payload = "{}",
    };
    const prefab_b = scene_core.prefab.PrefabDefinition{
        .header = try support.header(scene_core.asset.prefab_kind, scene_core.asset.prefab_schema_id, "39bff85d-3f8f-5ea4-9786-2ac6f01f4daf"),
        .nodes = &.{.{ .node_id = try scene_core.prefab.PrefabNodeId.init("lamp"), .nested_prefab_ref = ref_a, .extensions = &.{light_extension} }},
    };
    var states: [2]u8 = undefined;
    try std.testing.expectError(error.NestedPrefabCycle, scene_core.validation.validatePrefabNesting(&.{ prefab_a, prefab_b }, 0, &states));

    const valid_override = scene_core.entity.OverrideRecord{
        .target = .{
            .node_path = "lamp",
            .component_type_id = light_extension.type_id,
            .property_path = "intensity",
        },
        .canonical_value = "12",
    };
    const instance = scene_core.entity.EntityInstanceDefinition{
        .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d"),
        .overrides = &.{valid_override},
    };
    try scene_core.validation.validateInstanceOverrides(instance, prefab_b);
    var invalid_override = valid_override;
    invalid_override.target.node_path = "missing";
    var invalid_instance = instance;
    invalid_instance.overrides = &.{invalid_override};
    try std.testing.expectError(error.MissingOverrideTarget, scene_core.validation.validateInstanceOverrides(invalid_instance, prefab_b));
}

test "presentation reference requires optional-presentation dependency classification" {
    const presentation_asset = try support.assetRef("ed549ae5-dd95-57ef-853c-f5a6c76a29b5", "u.presentation", 0x61);
    const dependency = foundation.reference.DirectDependency{ .asset = presentation_asset, .class = .optional_presentation };
    var header = try support.header(scene_core.asset.level_kind, scene_core.asset.level_schema_id, "8b0bff06-f67d-5ac9-a3d0-5534844ae2cd");
    header.presentation = try scene_core.asset.PresentationRef.init(presentation_asset);
    header.dependencies = &.{dependency};
    const definition = scene_core.level.LevelDefinition{
        .header = header,
        .origin = .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 },
        .entities = &.{},
    };
    const catalog = [_]scene_core.validation.CatalogEntry{.{ .asset = presentation_asset }};
    var descriptor_storage: [1]scene_core.extension.Descriptor = undefined;
    const registry = try support.frozenRegistry(&descriptor_storage);
    try scene_core.validation.validateLevel(definition, &.{}, &catalog, &registry, .{
        .hierarchy_order = &.{},
        .hierarchy_depth = &.{},
    });
    var semantic_dependency = dependency;
    semantic_dependency.class = .semantic_runtime_required;
    var invalid = definition;
    invalid.header.dependencies = &.{semantic_dependency};
    try std.testing.expectError(error.InvalidPresentationDependency, scene_core.validation.validateLevel(invalid, &.{}, &catalog, &registry, .{
        .hierarchy_order = &.{},
        .hierarchy_depth = &.{},
    }));
}

test "scene diagnostics preserve stable codes and deterministic sort order" {
    const header = try support.header(scene_core.asset.level_kind, scene_core.asset.level_schema_id, "8b0bff06-f67d-5ac9-a3d0-5534844ae2cd");
    var storage: [2]foundation.diagnostics.Diagnostic = undefined;
    var collector = foundation.diagnostics.Collector.init(&storage);
    try scene_core.validation.addDiagnostic(&collector, .invalid_reference, header, "entities[1]", "parent", "missing parent");
    try scene_core.validation.addDiagnostic(&collector, .duplicate_identity, header, "entities[0]", "entity_id", "duplicate entity");
    const sorted = collector.sorted();
    try std.testing.expectEqual(foundation.diagnostics.Code.duplicate_identity, sorted[0].code);
    try std.testing.expectEqualStrings("entities[0]", sorted[0].object_path);
}

test "extension dependency reports must be present in the owning asset header" {
    const dependency_asset = try support.assetRef("e780eb86-d412-513e-8f61-99a7f1d4e153", "r.light_profile", 0x81);
    const dependency = foundation.reference.DirectDependency{ .asset = dependency_asset, .class = .semantic_runtime_required };
    const light = scene_core.extension.ExtensionRecord{
        .type_id = try scene_core.extension.ComponentTypeId.init("r.light"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .required,
        .canonical_payload = "{\"intensity\":12}",
        .dependencies = &.{dependency},
    };
    const entity_definition = scene_core.entity.EntityInstanceDefinition{
        .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d"),
        .extensions = &.{light},
    };
    var header = try support.header(scene_core.asset.level_kind, scene_core.asset.level_schema_id, "8b0bff06-f67d-5ac9-a3d0-5534844ae2cd");
    var definition = scene_core.level.LevelDefinition{
        .header = header,
        .origin = .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 },
        .entities = &.{entity_definition},
    };
    var descriptor_storage: [1]scene_core.extension.Descriptor = undefined;
    const registry = try support.frozenRegistry(&descriptor_storage);
    const catalog = [_]scene_core.validation.CatalogEntry{.{ .asset = dependency_asset }};
    var order: [1]usize = undefined;
    var depth: [1]u8 = undefined;
    try std.testing.expectError(error.InvalidExtensionDependency, scene_core.validation.validateLevel(definition, &.{}, &catalog, &registry, .{
        .hierarchy_order = &order,
        .hierarchy_depth = &depth,
    }));
    header.dependencies = &.{dependency};
    definition.header = header;
    try scene_core.validation.validateLevel(definition, &.{}, &catalog, &registry, .{
        .hierarchy_order = &order,
        .hierarchy_depth = &depth,
    });
}

test "reusable street-lamp prefab remains separate from two placed instances" {
    const prefab_reference = try support.assetRef("2b0a68db-832e-5aa4-9f75-fe3f19320c44", "f.prefab", 0x31);
    const light = scene_core.extension.ExtensionRecord{
        .type_id = try scene_core.extension.ComponentTypeId.init("r.light"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .required,
        .canonical_payload = "{\"intensity\":12}",
    };
    const lamp = scene_core.prefab.PrefabDefinition{
        .header = try support.header(scene_core.asset.prefab_kind, scene_core.asset.prefab_schema_id, "2b0a68db-832e-5aa4-9f75-fe3f19320c44"),
        .nodes = &.{
            .{ .node_id = try scene_core.prefab.PrefabNodeId.init("root") },
            .{ .node_id = try scene_core.prefab.PrefabNodeId.init("light"), .parent = try scene_core.prefab.PrefabNodeId.init("root"), .extensions = &.{light} },
        },
    };
    const override = scene_core.entity.OverrideRecord{
        .target = .{
            .node_path = "light",
            .component_type_id = light.type_id,
            .property_path = "intensity",
        },
        .canonical_value = "18",
    };
    const placed = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d"), .prefab_ref = prefab_reference },
        .{ .entity_id = try support.entityId("b7e8669c-2d61-5e4f-a898-1be001ee1720"), .prefab_ref = prefab_reference, .overrides = &.{override} },
    };
    try scene_core.validation.validateInstanceOverrides(placed[1], lamp);
    try std.testing.expectEqual(@as(usize, 0), placed[0].extensions.len);
    try std.testing.expectEqual(@as(usize, 1), placed[1].overrides.len);
    try std.testing.expectEqual(@as(usize, 2), lamp.nodes.len);
}

test "tag capacity and deterministic provenance validation fail closed" {
    var tags: [scene_core.metadata.max_tags_per_entity + 1]scene_core.metadata.TagId = undefined;
    var buffers: [scene_core.metadata.max_tags_per_entity + 1][16]u8 = undefined;
    for (&tags, 0..) |*tag, index| {
        const text = try std.fmt.bufPrint(&buffers[index], "game:t{d}", .{index});
        tag.* = try scene_core.metadata.TagId.init(text);
    }
    const instance = scene_core.entity.EntityInstanceDefinition{
        .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d"),
        .tags = &tags,
    };
    var descriptor_storage: [1]scene_core.extension.Descriptor = undefined;
    const registry = try support.frozenRegistry(&descriptor_storage);
    try std.testing.expectError(error.TooManyTags, scene_core.validation.validateEntities(&.{instance}, .level, &.{}, &registry));

    var header = try support.header(scene_core.asset.level_kind, scene_core.asset.level_schema_id, "8b0bff06-f67d-5ac9-a3d0-5534844ae2cd");
    header.provenance = .{
        .root_seed = .{ .bytes = [_]u8{0x91} ** 16 },
        .generator_id = try foundation.identity.GeneratorId.parseCanonical("d465b3d7-4ad7-5745-b692-d97426e9ad79"),
        .generator_version = foundation.version.GeneratorVersion.init(1, 0, 0),
        .algorithm_id = try foundation.identity.AlgorithmId.parseCanonical("3aefbc52-909e-5c35-a7c4-f409124f2457"),
        .algorithm_version = foundation.version.AlgorithmVersion.init(1, 0, 0),
        .stable_generation_key = "",
    };
    const invalid_level = scene_core.level.LevelDefinition{
        .header = header,
        .origin = .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 },
        .entities = &.{},
    };
    try std.testing.expectError(error.InvalidAssetHeader, scene_core.validation.validateLevel(invalid_level, &.{}, &.{}, &registry, .{
        .hierarchy_order = &.{},
        .hierarchy_depth = &.{},
    }));
}
