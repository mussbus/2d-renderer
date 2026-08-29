const std = @import("std");
const foundation = @import("foundation");
const asset = @import("asset.zig");
const canonical_json = @import("canonical_json.zig");
const entity = @import("entity.zig");
const extension = @import("extension.zig");
const hierarchy = @import("hierarchy.zig");
const level = @import("level.zig");
const metadata = @import("metadata.zig");
const prefab = @import("prefab.zig");
const world = @import("world.zig");

pub const CatalogEntry = struct {
    asset: foundation.reference.AssetRef,
};

pub const CatalogError = error{
    CatalogDuplicate,
    InvalidCatalogIdentity,
    InvalidReference,
    MissingAsset,
    RevisionMismatch,
    WrongAssetKind,
};

pub const ValidationError = error{
    AggregateExtensionPayloadTooLarge,
    DuplicateDependency,
    DuplicateLayerAssignment,
    DuplicateLevelReference,
    DuplicateOverride,
    DuplicatePrefabNodeId,
    DuplicateTag,
    InvalidAssetHeader,
    InvalidCamera,
    InvalidExtensionDependency,
    InvalidHierarchy,
    InvalidIdentity,
    InvalidLayerAssignment,
    InvalidOverride,
    InvalidPrefabHierarchy,
    InvalidPresentationDependency,
    InvalidTransform,
    InvalidTag,
    InvalidVolumeShape,
    MissingOverrideTarget,
    NestedPrefabCycle,
    NestedPrefabTooDeep,
    TooManyOverrides,
    TooManyTags,
    UnsupportedSchemaVersion,
    WrongEntityClassification,
} || CatalogError || extension.ValidationError;

pub const Scratch = struct {
    hierarchy_order: []usize,
    hierarchy_depth: []u8,
};

pub fn resolveExact(catalog: []const CatalogEntry, reference: foundation.reference.AssetRef) CatalogError!void {
    validateAssetReference(reference) catch return error.InvalidReference;
    var identity_match: ?foundation.reference.AssetRef = null;
    for (catalog, 0..) |entry, index| {
        validateAssetReference(entry.asset) catch return error.InvalidCatalogIdentity;
        for (catalog[0..index]) |previous| {
            if (entry.asset.revision.asset_id.eql(previous.asset.revision.asset_id)) return error.CatalogDuplicate;
        }
        if (entry.asset.revision.asset_id.eql(reference.revision.asset_id)) identity_match = entry.asset;
    }
    const found = identity_match orelse return error.MissingAsset;
    if (!found.expected_kind.eql(reference.expected_kind)) return error.WrongAssetKind;
    if (!found.revision.eql(reference.revision)) return error.RevisionMismatch;
}

pub fn validatePrefab(
    definition: prefab.PrefabDefinition,
    catalog: []const CatalogEntry,
    registry: *const extension.DescriptorRegistry,
    scratch: Scratch,
) ValidationError!void {
    try validateHeader(definition.header, asset.prefab_schema_id, asset.prefab_kind, catalog);
    var extension_bytes: usize = 0;
    for (definition.nodes, 0..) |node, index| {
        _ = prefab.PrefabNodeId.init(node.node_id.value) catch return error.InvalidIdentity;
        if (node.parent) |parent| _ = prefab.PrefabNodeId.init(parent.value) catch return error.InvalidIdentity;
        for (definition.nodes[0..index]) |previous| if (node.node_id.eql(previous.node_id)) return error.DuplicatePrefabNodeId;
        node.local_transform.validate() catch return error.InvalidTransform;
        try validateTags(node.tags);
        extension_bytes += try extension.validateRecords(node.extensions, registry);
        try validateExtensionDependencies(node.extensions, definition.header.dependencies);
        if (node.nested_prefab_ref) |reference| {
            if (!reference.expected_kind.eql(asset.prefab_kind)) return error.WrongAssetKind;
            try resolveExact(catalog, reference);
        }
    }
    if (extension_bytes > extension.max_payload_bytes_per_asset) return error.AggregateExtensionPayloadTooLarge;
    try validatePrefabHierarchy(definition, scratch);
}

pub fn validateLevel(
    definition: level.LevelDefinition,
    world_persistent_anchors: []const foundation.identity.EntityId,
    catalog: []const CatalogEntry,
    registry: *const extension.DescriptorRegistry,
    scratch: Scratch,
) ValidationError!void {
    try validateHeader(definition.header, asset.level_schema_id, asset.level_kind, catalog);
    try validateEntities(definition.entities, .level, catalog, registry);
    for (definition.entities) |instance| try validateExtensionDependencies(instance.extensions, definition.header.dependencies);
    _ = hierarchy.evaluationOrder(
        definition.entities,
        world_persistent_anchors,
        scratch.hierarchy_order,
        scratch.hierarchy_depth,
    ) catch return error.InvalidHierarchy;
}

pub fn validateWorld(
    definition: world.WorldDefinition,
    catalog: []const CatalogEntry,
    registry: *const extension.DescriptorRegistry,
    scratch: Scratch,
) ValidationError!void {
    try validateHeader(definition.header, asset.world_schema_id, asset.world_kind, catalog);
    for (definition.level_refs, 0..) |reference, index| {
        if (!reference.expected_kind.eql(asset.level_kind)) return error.WrongAssetKind;
        try resolveExact(catalog, reference);
        for (definition.level_refs[0..index]) |previous| {
            if (reference.revision.asset_id.eql(previous.revision.asset_id)) return error.DuplicateLevelReference;
        }
    }
    try validateEntities(definition.persistent_entities, .world, catalog, registry);
    for (definition.persistent_entities) |instance| try validateExtensionDependencies(instance.extensions, definition.header.dependencies);
    _ = hierarchy.evaluationOrder(
        definition.persistent_entities,
        &.{},
        scratch.hierarchy_order,
        scratch.hierarchy_depth,
    ) catch return error.InvalidHierarchy;
}

pub const ContainerKind = enum { level, world };

pub fn validateEntities(
    entities: []const entity.EntityInstanceDefinition,
    container_kind: ContainerKind,
    catalog: []const CatalogEntry,
    registry: *const extension.DescriptorRegistry,
) ValidationError!void {
    var aggregate_extension_bytes: usize = 0;
    for (entities) |instance| {
        validateUuid(foundation.identity.EntityId, instance.entity_id.bytes) catch return error.InvalidIdentity;
        if (instance.parent) |parent| validateUuid(foundation.identity.EntityId, parent.entity_id.bytes) catch return error.InvalidIdentity;
        instance.local_transform.validate() catch return error.InvalidTransform;
        if (container_kind == .world and instance.classification != .authored) return error.WrongEntityClassification;
        if (instance.prefab_ref) |reference| {
            if (!reference.expected_kind.eql(asset.prefab_kind)) return error.WrongAssetKind;
            try resolveExact(catalog, reference);
        }
        try validateOverrides(instance.overrides);
        try validateTags(instance.tags);
        try validateLayers(instance.layers, catalog);
        aggregate_extension_bytes += try extension.validateRecords(instance.extensions, registry);
        if (instance.camera_definition) |definition| definition.validate() catch return error.InvalidCamera;
        if (instance.volume_shape) |reference| {
            if (!reference.asset.expected_kind.eql(asset.volume_shape_kind)) return error.InvalidVolumeShape;
            try resolveExact(catalog, reference.asset);
        }
        if (instance.presentation) |reference| {
            if (!reference.asset.expected_kind.eql(asset.presentation_kind)) return error.InvalidPresentationDependency;
            try resolveExact(catalog, reference.asset);
        }
    }
    if (aggregate_extension_bytes > extension.max_payload_bytes_per_asset) return error.AggregateExtensionPayloadTooLarge;
}

pub fn validatePrefabNesting(
    definitions: []const prefab.PrefabDefinition,
    root_index: usize,
    state: []u8,
) ValidationError!void {
    if (root_index >= definitions.len or state.len < definitions.len) return error.MissingAsset;
    @memset(state[0..definitions.len], 0);
    try visitPrefab(definitions, root_index, state, 1);
}

pub fn validateInstanceOverrides(instance: entity.EntityInstanceDefinition, definition: prefab.PrefabDefinition) ValidationError!void {
    try validateOverrides(instance.overrides);
    for (instance.overrides) |override| {
        const slash = std.mem.lastIndexOfScalar(u8, override.target.node_path, '/');
        const node_name = if (slash) |index| override.target.node_path[index + 1 ..] else override.target.node_path;
        const node_id = prefab.PrefabNodeId.init(node_name) catch return error.InvalidOverride;
        const node = prefab.findNode(definition, node_id) orelse return error.MissingOverrideTarget;
        var found_component = false;
        for (node.extensions) |record| {
            if (record.type_id.eql(override.target.component_type_id)) found_component = true;
        }
        if (!found_component) return error.MissingOverrideTarget;
    }
}

pub fn addDiagnostic(
    collector: *foundation.diagnostics.Collector,
    code: foundation.diagnostics.Code,
    header: asset.AssetHeader,
    object_path: []const u8,
    property_path: []const u8,
    message: []const u8,
) error{CapacityExceeded}!void {
    try collector.add(.{
        .severity = .error_severity,
        .code = code,
        .schema = .{ .id = header.schema.id, .version = header.schema.version },
        .object_path = object_path,
        .property_path = property_path,
        .message = message,
    });
}

fn validateHeader(
    header: asset.AssetHeader,
    expected_schema_id: foundation.identity.AssetId,
    expected_kind: foundation.reference.AssetKind,
    catalog: []const CatalogEntry,
) ValidationError!void {
    if (!header.schema.id.eql(expected_schema_id) or !header.kind.eql(expected_kind)) return error.InvalidAssetHeader;
    validateUuid(foundation.identity.AssetId, header.schema.id.bytes) catch return error.InvalidAssetHeader;
    validateUuid(foundation.identity.AssetId, header.asset_id.bytes) catch return error.InvalidAssetHeader;
    validateUuid(foundation.identity.ProducerId, header.producer.id.bytes) catch return error.InvalidAssetHeader;
    _ = foundation.reference.AssetKind.init(header.kind.name) catch return error.InvalidAssetHeader;
    if (!asset.isSupportedCurrentVersion(header.schema.version)) return error.UnsupportedSchemaVersion;
    if (header.slug) |slug| if (!asset.validSlug(slug)) return error.InvalidAssetHeader;
    if (header.provenance) |provenance| {
        provenance.validate() catch return error.InvalidAssetHeader;
        validateUuid(foundation.identity.GeneratorId, provenance.generator_id.bytes) catch return error.InvalidAssetHeader;
        validateUuid(foundation.identity.AlgorithmId, provenance.algorithm_id.bytes) catch return error.InvalidAssetHeader;
    }
    for (header.dependencies, 0..) |dependency, index| {
        try resolveExact(catalog, dependency.asset);
        for (header.dependencies[0..index]) |previous| {
            if (dependency.asset.revision.asset_id.eql(previous.asset.revision.asset_id)) return error.DuplicateDependency;
        }
    }
    if (header.presentation) |presentation| {
        var found = false;
        for (header.dependencies) |dependency| {
            if (dependency.asset.eql(presentation.asset) and dependency.class == .optional_presentation) found = true;
        }
        if (!found) return error.InvalidPresentationDependency;
    }
}

fn validateTags(tags: []const metadata.TagId) ValidationError!void {
    if (tags.len > metadata.max_tags_per_entity) return error.TooManyTags;
    for (tags, 0..) |tag, index| {
        _ = metadata.TagId.init(tag.value) catch return error.InvalidTag;
        for (tags[0..index]) |previous| if (tag.eql(previous)) return error.DuplicateTag;
    }
}

fn validateLayers(layers: []const metadata.LayerAssignment, catalog: []const CatalogEntry) ValidationError!void {
    for (layers, 0..) |layer, index| {
        layer.validate() catch return error.InvalidLayerAssignment;
        try resolveExact(catalog, layer.layer);
        for (layers[0..index]) |previous| {
            if (layer.system == previous.system and layer.layer.revision.asset_id.eql(previous.layer.revision.asset_id)) {
                return error.DuplicateLayerAssignment;
            }
        }
    }
}

fn validateOverrides(overrides: []const entity.OverrideRecord) ValidationError!void {
    if (overrides.len > entity.max_overrides_per_instance) return error.TooManyOverrides;
    for (overrides, 0..) |override, index| {
        override.target.validate() catch return error.InvalidOverride;
        if (override.canonical_value.len > extension.max_payload_bytes) return error.InvalidOverride;
        var canonical_scratch: [extension.max_payload_bytes]u8 = undefined;
        if (!canonical_json.isCanonical(override.canonical_value, &canonical_scratch)) return error.InvalidOverride;
        for (overrides[0..index]) |previous| if (entity.overrideOrder(override, previous) == .eq) return error.DuplicateOverride;
    }
}

fn validatePrefabHierarchy(definition: prefab.PrefabDefinition, scratch: Scratch) ValidationError!void {
    if (scratch.hierarchy_order.len < definition.nodes.len or scratch.hierarchy_depth.len < definition.nodes.len) return error.InvalidPrefabHierarchy;
    @memset(scratch.hierarchy_depth[0..definition.nodes.len], 0);
    var emitted: usize = 0;
    while (emitted < definition.nodes.len) : (emitted += 1) {
        var selected: ?usize = null;
        for (definition.nodes, 0..) |node, index| {
            if (scratch.hierarchy_depth[index] != 0) continue;
            const depth = if (node.parent) |parent_id| blk: {
                const parent_index = findPrefabNodeIndex(definition, parent_id) orelse return error.InvalidPrefabHierarchy;
                if (parent_id.eql(node.node_id)) return error.InvalidPrefabHierarchy;
                if (scratch.hierarchy_depth[parent_index] == 0) continue;
                break :blk @as(usize, scratch.hierarchy_depth[parent_index]) + 1;
            } else 1;
            if (depth > hierarchy.max_entity_hierarchy_depth) return error.InvalidPrefabHierarchy;
            if (selected == null or node.node_id.order(definition.nodes[selected.?].node_id) == .lt) selected = index;
        }
        const selected_index = selected orelse return error.InvalidPrefabHierarchy;
        const selected_node = definition.nodes[selected_index];
        const depth = if (selected_node.parent) |parent_id| @as(usize, scratch.hierarchy_depth[findPrefabNodeIndex(definition, parent_id).?]) + 1 else 1;
        scratch.hierarchy_depth[selected_index] = @intCast(depth);
        scratch.hierarchy_order[emitted] = selected_index;
    }
}

fn findPrefabNodeIndex(definition: prefab.PrefabDefinition, id: prefab.PrefabNodeId) ?usize {
    for (definition.nodes, 0..) |node, index| if (node.node_id.eql(id)) return index;
    return null;
}

fn visitPrefab(definitions: []const prefab.PrefabDefinition, index: usize, state: []u8, depth: usize) ValidationError!void {
    if (depth > prefab.max_nested_prefab_depth) return error.NestedPrefabTooDeep;
    if (state[index] == 1) return error.NestedPrefabCycle;
    if (state[index] == 2) return;
    state[index] = 1;
    for (definitions[index].nodes) |node| if (node.nested_prefab_ref) |reference| {
        var child_index: ?usize = null;
        for (definitions, 0..) |candidate, candidate_index| {
            if (candidate.header.asset_id.eql(reference.revision.asset_id)) child_index = candidate_index;
        }
        try visitPrefab(definitions, child_index orelse return error.MissingAsset, state, depth + 1);
    };
    state[index] = 2;
}

fn validateAssetReference(reference: foundation.reference.AssetRef) error{InvalidReference}!void {
    validateUuid(foundation.identity.AssetId, reference.revision.asset_id.bytes) catch return error.InvalidReference;
    _ = foundation.reference.AssetKind.init(reference.expected_kind.name) catch return error.InvalidReference;
}

fn validateExtensionDependencies(
    records: []const extension.ExtensionRecord,
    header_dependencies: []const foundation.reference.DirectDependency,
) ValidationError!void {
    for (records) |record| for (record.dependencies) |dependency| {
        var found = false;
        for (header_dependencies) |header_dependency| {
            if (dependency.class == header_dependency.class and dependency.asset.eql(header_dependency.asset)) found = true;
        }
        if (!found) return error.InvalidExtensionDependency;
    };
}

fn validateUuid(comptime T: type, bytes: [16]u8) foundation.identity.ParseError!void {
    _ = try T.fromCanonicalBytes(bytes);
}
