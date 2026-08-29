const std = @import("std");
const foundation = @import("foundation");
const asset = @import("asset.zig");
const camera = @import("camera.zig");
const canonical_json = @import("canonical_json.zig");
const entity = @import("entity.zig");
const extension = @import("extension.zig");
const level = @import("level.zig");
const metadata = @import("metadata.zig");
const migration = @import("migration.zig");
const prefab = @import("prefab.zig");
const world = @import("world.zig");

pub const ParseError = error{
    DuplicateField,
    ExpectedArray,
    ExpectedBoolean,
    ExpectedInteger,
    ExpectedNumber,
    ExpectedObject,
    ExpectedString,
    InvalidAssetKind,
    InvalidCanonicalData,
    InvalidEnumValue,
    InvalidIdentity,
    InvalidJson,
    InvalidReference,
    InvalidSpatialValue,
    InvalidVersion,
    MissingField,
    OutOfMemory,
    PayloadTooLarge,
    UnknownField,
    UnsupportedSchemaVersion,
} || migration.MigrationError;

pub const SerializationError = foundation.canonical_data.Error || error{
    InvalidCanonicalPayload,
    InvalidCollection,
};

pub fn Parsed(comptime T: type) type {
    return struct {
        parsed_json: std.json.Parsed(std.json.Value),
        value: T,

        pub fn deinit(self: *@This()) void {
            self.parsed_json.deinit();
            self.* = undefined;
        }
    };
}

pub const ParsedPrefab = Parsed(prefab.PrefabDefinition);
pub const ParsedLevel = Parsed(level.LevelDefinition);
pub const ParsedWorld = Parsed(world.WorldDefinition);

pub fn serializePrefab(definition: prefab.PrefabDefinition, output: []u8) SerializationError![]const u8 {
    var writer = foundation.canonical_data.Writer.init(output);
    try writer.raw("{");
    try writeHeaderPrefix(&writer, definition.header);
    try writer.raw(",\"payload\":{\"nodes\":");
    try writePrefabNodes(&writer, definition.nodes);
    try writer.raw("},");
    try writeHeaderSuffix(&writer, definition.header);
    try writer.raw("}");
    return writer.bytes();
}

pub fn serializeLevel(definition: level.LevelDefinition, output: []u8) SerializationError![]const u8 {
    var writer = foundation.canonical_data.Writer.init(output);
    try writer.raw("{");
    try writeHeaderPrefix(&writer, definition.header);
    try writer.raw(",\"payload\":{\"entities\":");
    try writeEntities(&writer, definition.entities);
    try writer.raw(",\"origin_mm\":[");
    try writer.i64Value(definition.origin.x_mm);
    try writer.raw(",");
    try writer.i64Value(definition.origin.y_mm);
    try writer.raw(",");
    try writer.i64Value(definition.origin.z_mm);
    try writer.raw("]},");
    try writeHeaderSuffix(&writer, definition.header);
    try writer.raw("}");
    return writer.bytes();
}

pub fn serializeWorld(definition: world.WorldDefinition, output: []u8) SerializationError![]const u8 {
    var writer = foundation.canonical_data.Writer.init(output);
    try writer.raw("{");
    try writeHeaderPrefix(&writer, definition.header);
    try writer.raw(",\"payload\":{\"level_refs\":");
    try writeAssetRefs(&writer, definition.level_refs);
    try writer.raw(",\"persistent_entities\":");
    try writeEntities(&writer, definition.persistent_entities);
    try writer.raw("},");
    try writeHeaderSuffix(&writer, definition.header);
    try writer.raw("}");
    return writer.bytes();
}

pub fn canonicalHash(canonical_bytes: []const u8) foundation.canonical_data.Error!foundation.canonical_data.Sha256Digest {
    return foundation.canonical_data.hashDomainSeparated(
        "foundation.scene_core.authored_asset.v1",
        &.{canonical_bytes},
    );
}

fn writeHeaderPrefix(writer: *foundation.canonical_data.Writer, header: asset.AssetHeader) SerializationError!void {
    try writer.raw("\"asset_identity\":{\"asset_id\":");
    try writer.uuidValue(header.asset_id.bytes);
    try writer.raw(",\"asset_version\":");
    try writeVersion(writer, header.asset_version);
    try writer.raw(",\"kind\":");
    try writer.jsonString(header.kind.name);
    try writer.raw(",\"slug\":");
    if (header.slug) |slug| try writer.jsonString(slug) else try writer.raw("null");
    try writer.raw("},\"dependencies\":");
    try writeDependencies(writer, header.dependencies);
}

fn writeHeaderSuffix(writer: *foundation.canonical_data.Writer, header: asset.AssetHeader) SerializationError!void {
    try writer.raw("\"presentation_ref\":");
    if (header.presentation) |reference| try writeAssetRef(writer, reference.asset) else try writer.raw("null");
    try writer.raw(",\"producer_identity\":{\"producer_id\":");
    try writer.uuidValue(header.producer.id.bytes);
    try writer.raw(",\"producer_version\":");
    try writeVersion(writer, header.producer.version);
    try writer.raw("},\"provenance\":");
    if (header.provenance) |provenance| try writeProvenance(writer, provenance) else try writer.raw("null");
    try writer.raw(",\"schema_identity\":{\"schema_id\":");
    try writer.uuidValue(header.schema.id.bytes);
    try writer.raw(",\"schema_version\":");
    try writeVersion(writer, header.schema.version);
    try writer.raw("}");
}

fn writeProvenance(writer: *foundation.canonical_data.Writer, value: asset.GenerationProvenance) SerializationError!void {
    try writer.raw("{\"algorithm_id\":");
    try writer.uuidValue(value.algorithm_id.bytes);
    try writer.raw(",\"algorithm_version\":");
    try writeVersion(writer, value.algorithm_version);
    try writer.raw(",\"generator_id\":");
    try writer.uuidValue(value.generator_id.bytes);
    try writer.raw(",\"generator_version\":");
    try writeVersion(writer, value.generator_version);
    const seed = value.root_seed.formatLowerHex();
    try writer.raw(",\"root_seed\":");
    try writer.jsonString(&seed);
    try writer.raw(",\"stable_generation_key\":");
    try writer.jsonString(value.stable_generation_key);
    try writer.raw("}");
}

fn writeDependencies(writer: *foundation.canonical_data.Writer, values: []const foundation.reference.DirectDependency) SerializationError!void {
    try writer.raw("[");
    var previous: ?usize = null;
    for (0..values.len) |emitted| {
        const selected = selectDependency(values, previous) orelse return error.InvalidCollection;
        if (emitted != 0) try writer.raw(",");
        try writer.raw("{\"asset\":");
        try writeAssetRef(writer, values[selected].asset);
        try writer.raw(",\"class\":");
        try writer.jsonString(@tagName(values[selected].class));
        try writer.raw("}");
        previous = selected;
    }
    try writer.raw("]");
}

fn writeAssetRefs(writer: *foundation.canonical_data.Writer, values: []const foundation.reference.AssetRef) SerializationError!void {
    try writer.raw("[");
    var previous: ?usize = null;
    for (0..values.len) |emitted| {
        const selected = selectAssetRef(values, previous) orelse return error.InvalidCollection;
        if (emitted != 0) try writer.raw(",");
        try writeAssetRef(writer, values[selected]);
        previous = selected;
    }
    try writer.raw("]");
}

fn writeAssetRef(writer: *foundation.canonical_data.Writer, value: foundation.reference.AssetRef) SerializationError!void {
    try writer.raw("{\"asset_id\":");
    try writer.uuidValue(value.revision.asset_id.bytes);
    try writer.raw(",\"content_hash\":");
    try writer.sha256Value(value.revision.content_hash);
    try writer.raw(",\"expected_kind\":");
    try writer.jsonString(value.expected_kind.name);
    try writer.raw(",\"version\":");
    try writeVersion(writer, value.revision.version);
    try writer.raw("}");
}

fn writePrefabNodes(writer: *foundation.canonical_data.Writer, values: []const prefab.PrefabNodeDefinition) SerializationError!void {
    try writer.raw("[");
    var previous: ?usize = null;
    for (0..values.len) |emitted| {
        const selected = selectPrefabNode(values, previous) orelse return error.InvalidCollection;
        if (emitted != 0) try writer.raw(",");
        try writePrefabNode(writer, values[selected]);
        previous = selected;
    }
    try writer.raw("]");
}

fn writePrefabNode(writer: *foundation.canonical_data.Writer, value: prefab.PrefabNodeDefinition) SerializationError!void {
    try writer.raw("{\"enabled\":");
    try writer.jsonString(@tagName(value.enabled));
    try writer.raw(",\"extensions\":");
    try writeExtensions(writer, value.extensions);
    try writer.raw(",\"local_transform\":");
    try writeLocalTransform(writer, value.local_transform);
    try writer.raw(",\"nested_prefab_ref\":");
    if (value.nested_prefab_ref) |reference| try writeAssetRef(writer, reference) else try writer.raw("null");
    try writer.raw(",\"node_id\":");
    try writer.jsonString(value.node_id.value);
    try writer.raw(",\"parent\":");
    if (value.parent) |parent| try writer.jsonString(parent.value) else try writer.raw("null");
    try writer.raw(",\"tags\":");
    try writeTags(writer, value.tags);
    try writer.raw(",\"visibility\":");
    try writer.jsonString(@tagName(value.visibility));
    try writer.raw("}");
}

fn writeEntities(writer: *foundation.canonical_data.Writer, values: []const entity.EntityInstanceDefinition) SerializationError!void {
    try writer.raw("[");
    var previous: ?usize = null;
    for (0..values.len) |emitted| {
        const selected = selectEntity(values, previous) orelse return error.InvalidCollection;
        if (emitted != 0) try writer.raw(",");
        try writeEntity(writer, values[selected]);
        previous = selected;
    }
    try writer.raw("]");
}

fn writeEntity(writer: *foundation.canonical_data.Writer, value: entity.EntityInstanceDefinition) SerializationError!void {
    try writer.raw("{\"camera_definition\":");
    if (value.camera_definition) |definition| try writeCamera(writer, definition) else try writer.raw("null");
    try writer.raw(",\"classification\":");
    try writer.jsonString(@tagName(value.classification));
    try writer.raw(",\"enabled\":");
    try writer.jsonString(@tagName(value.enabled));
    try writer.raw(",\"entity_id\":");
    try writer.uuidValue(value.entity_id.bytes);
    try writer.raw(",\"extensions\":");
    try writeExtensions(writer, value.extensions);
    try writer.raw(",\"layers\":");
    try writeLayers(writer, value.layers);
    try writer.raw(",\"local_transform\":");
    try writeLocalTransform(writer, value.local_transform);
    try writer.raw(",\"overrides\":");
    try writeOverrides(writer, value.overrides);
    try writer.raw(",\"parent\":");
    if (value.parent) |parent| {
        try writer.raw("{\"entity_id\":");
        try writer.uuidValue(parent.entity_id.bytes);
        try writer.raw(",\"requirement\":");
        try writer.jsonString(@tagName(parent.requirement));
        try writer.raw("}");
    } else try writer.raw("null");
    try writer.raw(",\"prefab_ref\":");
    if (value.prefab_ref) |reference| try writeAssetRef(writer, reference) else try writer.raw("null");
    try writer.raw(",\"presentation_ref\":");
    if (value.presentation) |reference| try writeAssetRef(writer, reference.asset) else try writer.raw("null");
    try writer.raw(",\"tags\":");
    try writeTags(writer, value.tags);
    try writer.raw(",\"visibility\":");
    try writer.jsonString(@tagName(value.visibility));
    try writer.raw(",\"volume_shape_ref\":");
    if (value.volume_shape) |reference| try writeAssetRef(writer, reference.asset) else try writer.raw("null");
    try writer.raw("}");
}

fn writeCamera(writer: *foundation.canonical_data.Writer, value: camera.CameraDefinition) SerializationError!void {
    try writer.raw("{\"far_clip_m\":");
    try writer.f32Value(value.far_clip_m);
    try writer.raw(",\"lens_shift\":[");
    try writer.f32Value(value.lens_shift_x);
    try writer.raw(",");
    try writer.f32Value(value.lens_shift_y);
    try writer.raw("],\"near_clip_m\":");
    try writer.f32Value(value.near_clip_m);
    try writer.raw(",\"orthographic\":");
    if (value.orthographic) |orthographic| {
        try writer.raw("{\"horizontal_extent_m\":");
        try writer.f32Value(orthographic.horizontal_extent_m);
        try writer.raw(",\"vertical_extent_m\":");
        try writer.f32Value(orthographic.vertical_extent_m);
        try writer.raw("}");
    } else try writer.raw("null");
    try writer.raw(",\"perspective\":");
    if (value.perspective) |perspective| {
        try writer.raw("{\"focal_length_mm\":");
        try writer.f32Value(perspective.focal_length_mm);
        try writer.raw(",\"sensor_height_mm\":");
        try writer.f32Value(perspective.sensor_height_mm);
        try writer.raw(",\"sensor_width_mm\":");
        try writer.f32Value(perspective.sensor_width_mm);
        try writer.raw("}");
    } else try writer.raw("null");
    try writer.raw(",\"projection\":");
    try writer.jsonString(@tagName(value.projection));
    try writer.raw("}");
}

fn writeExtensions(writer: *foundation.canonical_data.Writer, values: []const extension.ExtensionRecord) SerializationError!void {
    try writer.raw("[");
    var previous: ?usize = null;
    for (0..values.len) |emitted| {
        const selected = selectExtension(values, previous) orelse return error.InvalidCollection;
        const value = values[selected];
        if (emitted != 0) try writer.raw(",");
        try writer.raw("{\"criticality\":");
        try writer.jsonString(@tagName(value.criticality));
        try writer.raw(",\"dependencies\":");
        try writeDependencies(writer, value.dependencies);
        try writer.raw(",\"payload\":");
        var payload_scratch: [extension.max_payload_bytes]u8 = undefined;
        if (!canonical_json.isCanonical(value.canonical_payload, &payload_scratch)) return error.InvalidCanonicalPayload;
        try writer.raw(value.canonical_payload);
        try writer.raw(",\"schema_version\":");
        try writeVersion(writer, value.schema_version);
        try writer.raw(",\"type_id\":");
        try writer.jsonString(value.type_id.value);
        try writer.raw("}");
        previous = selected;
    }
    try writer.raw("]");
}

fn writeLayers(writer: *foundation.canonical_data.Writer, values: []const metadata.LayerAssignment) SerializationError!void {
    try writer.raw("[");
    var previous: ?usize = null;
    for (0..values.len) |emitted| {
        const selected = selectLayer(values, previous) orelse return error.InvalidCollection;
        if (emitted != 0) try writer.raw(",");
        try writer.raw("{\"layer_ref\":");
        try writeAssetRef(writer, values[selected].layer);
        try writer.raw(",\"system\":");
        try writer.jsonString(@tagName(values[selected].system));
        try writer.raw("}");
        previous = selected;
    }
    try writer.raw("]");
}

fn writeOverrides(writer: *foundation.canonical_data.Writer, values: []const entity.OverrideRecord) SerializationError!void {
    try writer.raw("[");
    var previous: ?usize = null;
    for (0..values.len) |emitted| {
        const selected = selectOverride(values, previous) orelse return error.InvalidCollection;
        const value = values[selected];
        if (emitted != 0) try writer.raw(",");
        try writer.raw("{\"component_type_id\":");
        try writer.jsonString(value.target.component_type_id.value);
        try writer.raw(",\"node_path\":");
        try writer.jsonString(value.target.node_path);
        try writer.raw(",\"property_path\":");
        try writer.jsonString(value.target.property_path);
        try writer.raw(",\"value\":");
        var value_scratch: [extension.max_payload_bytes]u8 = undefined;
        if (!canonical_json.isCanonical(value.canonical_value, &value_scratch)) return error.InvalidCanonicalPayload;
        try writer.raw(value.canonical_value);
        try writer.raw("}");
        previous = selected;
    }
    try writer.raw("]");
}

fn writeTags(writer: *foundation.canonical_data.Writer, values: []const metadata.TagId) SerializationError!void {
    try writer.raw("[");
    var previous: ?usize = null;
    for (0..values.len) |emitted| {
        const selected = selectTag(values, previous) orelse return error.InvalidCollection;
        if (emitted != 0) try writer.raw(",");
        try writer.jsonString(values[selected].value);
        previous = selected;
    }
    try writer.raw("]");
}

fn writeLocalTransform(writer: *foundation.canonical_data.Writer, value: foundation.spatial.LocalTransform) SerializationError!void {
    try writer.raw("{\"rotation\":[");
    try writer.f32Value(value.rotation.x);
    try writer.raw(",");
    try writer.f32Value(value.rotation.y);
    try writer.raw(",");
    try writer.f32Value(value.rotation.z);
    try writer.raw(",");
    try writer.f32Value(value.rotation.w);
    try writer.raw("],\"scale\":[");
    try writeVec3Values(writer, value.scale);
    try writer.raw("],\"translation_m\":[");
    try writeVec3Values(writer, value.translation);
    try writer.raw("]}");
}

fn writeVec3Values(writer: *foundation.canonical_data.Writer, value: foundation.spatial.Vec3) SerializationError!void {
    try writer.f32Value(value.x);
    try writer.raw(",");
    try writer.f32Value(value.y);
    try writer.raw(",");
    try writer.f32Value(value.z);
}

fn writeVersion(writer: *foundation.canonical_data.Writer, value: anytype) SerializationError!void {
    try writer.versionValue(value.major, value.minor, value.patch);
}

fn selectDependency(values: []const foundation.reference.DirectDependency, previous: ?usize) ?usize {
    var selected: ?usize = null;
    for (values, 0..) |candidate, index| {
        if (previous) |previous_index| if (dependencyOrder(candidate, values[previous_index]) != .gt) continue;
        if (selected == null or dependencyOrder(candidate, values[selected.?]) == .lt) selected = index;
    }
    return selected;
}

fn dependencyOrder(a: foundation.reference.DirectDependency, b: foundation.reference.DirectDependency) std.math.Order {
    const class_order = std.math.order(@intFromEnum(a.class), @intFromEnum(b.class));
    if (class_order != .eq) return class_order;
    return a.asset.order(b.asset);
}

fn selectAssetRef(values: []const foundation.reference.AssetRef, previous: ?usize) ?usize {
    var selected: ?usize = null;
    for (values, 0..) |candidate, index| {
        if (previous) |previous_index| if (candidate.order(values[previous_index]) != .gt) continue;
        if (selected == null or candidate.order(values[selected.?]) == .lt) selected = index;
    }
    return selected;
}

fn selectPrefabNode(values: []const prefab.PrefabNodeDefinition, previous: ?usize) ?usize {
    var selected: ?usize = null;
    for (values, 0..) |candidate, index| {
        if (previous) |previous_index| if (candidate.node_id.order(values[previous_index].node_id) != .gt) continue;
        if (selected == null or candidate.node_id.order(values[selected.?].node_id) == .lt) selected = index;
    }
    return selected;
}

fn selectEntity(values: []const entity.EntityInstanceDefinition, previous: ?usize) ?usize {
    var selected: ?usize = null;
    for (values, 0..) |candidate, index| {
        if (previous) |previous_index| if (candidate.entity_id.byteOrder(values[previous_index].entity_id) != .gt) continue;
        if (selected == null or candidate.entity_id.byteOrder(values[selected.?].entity_id) == .lt) selected = index;
    }
    return selected;
}

fn selectExtension(values: []const extension.ExtensionRecord, previous: ?usize) ?usize {
    var selected: ?usize = null;
    for (values, 0..) |candidate, index| {
        if (previous) |previous_index| if (extensionOrder(candidate, values[previous_index]) != .gt) continue;
        if (selected == null or extensionOrder(candidate, values[selected.?]) == .lt) selected = index;
    }
    return selected;
}

fn extensionOrder(a: extension.ExtensionRecord, b: extension.ExtensionRecord) std.math.Order {
    const id_order = a.type_id.order(b.type_id);
    if (id_order != .eq) return id_order;
    return a.schema_version.order(b.schema_version);
}

fn selectLayer(values: []const metadata.LayerAssignment, previous: ?usize) ?usize {
    var selected: ?usize = null;
    for (values, 0..) |candidate, index| {
        if (previous) |previous_index| if (layerOrder(candidate, values[previous_index]) != .gt) continue;
        if (selected == null or layerOrder(candidate, values[selected.?]) == .lt) selected = index;
    }
    return selected;
}

fn layerOrder(a: metadata.LayerAssignment, b: metadata.LayerAssignment) std.math.Order {
    const system_order = std.math.order(@intFromEnum(a.system), @intFromEnum(b.system));
    if (system_order != .eq) return system_order;
    return a.layer.order(b.layer);
}

fn selectOverride(values: []const entity.OverrideRecord, previous: ?usize) ?usize {
    var selected: ?usize = null;
    for (values, 0..) |candidate, index| {
        if (previous) |previous_index| if (entity.overrideOrder(candidate, values[previous_index]) != .gt) continue;
        if (selected == null or entity.overrideOrder(candidate, values[selected.?]) == .lt) selected = index;
    }
    return selected;
}

fn selectTag(values: []const metadata.TagId, previous: ?usize) ?usize {
    var selected: ?usize = null;
    for (values, 0..) |candidate, index| {
        if (previous) |previous_index| if (candidate.order(values[previous_index]) != .gt) continue;
        if (selected == null or candidate.order(values[selected.?]) == .lt) selected = index;
    }
    return selected;
}

pub fn parsePrefab(allocator: std.mem.Allocator, source: []const u8) ParseError!ParsedPrefab {
    var parsed_json = try parseJson(allocator, source);
    errdefer parsed_json.deinit();
    const arena = parsed_json.arena.allocator();
    const root = try expectObject(parsed_json.value);
    try requireOnlyFields(root, document_fields);
    const header = try parseHeader(arena, root);
    if (!header.schema.id.eql(asset.prefab_schema_id) or !asset.isSupportedCurrentVersion(header.schema.version)) {
        return error.UnsupportedSchemaVersion;
    }
    const payload = try expectObject(try requireField(root, "payload"));
    try requireOnlyFields(payload, &.{"nodes"});
    return .{
        .parsed_json = parsed_json,
        .value = .{
            .header = header,
            .nodes = if (payload.get("nodes")) |nodes| try parsePrefabNodes(arena, nodes) else &.{},
        },
    };
}

pub fn parseLevel(
    allocator: std.mem.Allocator,
    source: []const u8,
    migration_report: *migration.MigrationReport,
) ParseError!ParsedLevel {
    var parsed_json = try parseJson(allocator, source);
    errdefer parsed_json.deinit();
    const arena = parsed_json.arena.allocator();
    const root = try expectObject(parsed_json.value);
    try requireOnlyFields(root, document_fields);
    const header = try parseHeader(arena, root);
    if (!header.schema.id.eql(asset.level_schema_id)) return error.UnsupportedSchemaVersion;
    const payload = try expectObject(try requireField(root, "payload"));
    if (asset.isSupportedCurrentVersion(header.schema.version)) {
        try requireOnlyFields(payload, &.{ "entities", "origin_mm" });
        return .{
            .parsed_json = parsed_json,
            .value = .{
                .header = header,
                .origin = try parseOriginMm(try requireField(payload, "origin_mm")),
                .entities = if (payload.get("entities")) |entities| try parseEntities(arena, entities, false) else &.{},
            },
        };
    }
    if (asset.isSupportedPreAcceptanceVersion(header.schema.version)) {
        try requireOnlyFields(payload, &.{ "entities", "origin_m" });
        const legacy = level.PreAcceptanceLevelDefinitionV0_9{
            .header = header,
            .origin_m = try parseOriginM(try requireField(payload, "origin_m")),
            .entities = try parseEntities(arena, try requireField(payload, "entities"), true),
        };
        return .{ .parsed_json = parsed_json, .value = try migration.levelV0_9ToCurrent(legacy, migration_report) };
    }
    return error.UnsupportedSchemaVersion;
}

pub fn parseWorld(allocator: std.mem.Allocator, source: []const u8) ParseError!ParsedWorld {
    var parsed_json = try parseJson(allocator, source);
    errdefer parsed_json.deinit();
    const arena = parsed_json.arena.allocator();
    const root = try expectObject(parsed_json.value);
    try requireOnlyFields(root, document_fields);
    const header = try parseHeader(arena, root);
    if (!header.schema.id.eql(asset.world_schema_id) or !asset.isSupportedCurrentVersion(header.schema.version)) {
        return error.UnsupportedSchemaVersion;
    }
    const payload = try expectObject(try requireField(root, "payload"));
    try requireOnlyFields(payload, &.{ "level_refs", "persistent_entities" });
    return .{
        .parsed_json = parsed_json,
        .value = .{
            .header = header,
            .level_refs = if (payload.get("level_refs")) |references| try parseAssetRefs(arena, references) else &.{},
            .persistent_entities = if (payload.get("persistent_entities")) |entities| try parseEntities(arena, entities, false) else &.{},
        },
    };
}

const document_fields = &.{
    "asset_identity",
    "dependencies",
    "payload",
    "presentation_ref",
    "producer_identity",
    "provenance",
    "schema_identity",
};

fn parseJson(allocator: std.mem.Allocator, source: []const u8) ParseError!std.json.Parsed(std.json.Value) {
    return std.json.parseFromSlice(std.json.Value, allocator, source, .{ .parse_numbers = false }) catch |parse_error| switch (parse_error) {
        error.OutOfMemory => error.OutOfMemory,
        error.DuplicateField => error.DuplicateField,
        else => error.InvalidJson,
    };
}

fn parseHeader(allocator: std.mem.Allocator, root: std.json.ObjectMap) ParseError!asset.AssetHeader {
    const asset_identity = try expectObject(try requireField(root, "asset_identity"));
    try requireOnlyFields(asset_identity, &.{ "asset_id", "asset_version", "kind", "slug" });
    const schema_identity = try expectObject(try requireField(root, "schema_identity"));
    try requireOnlyFields(schema_identity, &.{ "schema_id", "schema_version" });
    const producer_identity = try expectObject(try requireField(root, "producer_identity"));
    try requireOnlyFields(producer_identity, &.{ "producer_id", "producer_version" });
    const kind = foundation.reference.AssetKind.init(try expectString(try requireField(asset_identity, "kind"))) catch return error.InvalidAssetKind;
    return .{
        .schema = .{
            .id = try parseUuid(foundation.identity.AssetId, try requireField(schema_identity, "schema_id")),
            .version = try parseVersion(foundation.version.SchemaVersion, try requireField(schema_identity, "schema_version")),
        },
        .asset_id = try parseUuid(foundation.identity.AssetId, try requireField(asset_identity, "asset_id")),
        .asset_version = try parseVersion(foundation.version.AssetVersion, try requireField(asset_identity, "asset_version")),
        .kind = kind,
        .slug = if (asset_identity.get("slug")) |slug| try parseOptionalString(slug) else null,
        .producer = .{
            .id = try parseUuid(foundation.identity.ProducerId, try requireField(producer_identity, "producer_id")),
            .version = try parseVersion(foundation.version.ProducerVersion, try requireField(producer_identity, "producer_version")),
        },
        .dependencies = if (root.get("dependencies")) |dependencies| try parseDependencies(allocator, dependencies) else &.{},
        .provenance = if (root.get("provenance")) |provenance| try parseOptionalProvenance(provenance) else null,
        .presentation = if (root.get("presentation_ref")) |presentation| try parseOptionalPresentation(presentation) else null,
    };
}

fn parseOptionalProvenance(value: std.json.Value) ParseError!?asset.GenerationProvenance {
    if (value == .null) return null;
    const object = try expectObject(value);
    try requireOnlyFields(object, &.{
        "algorithm_id",
        "algorithm_version",
        "generator_id",
        "generator_version",
        "root_seed",
        "stable_generation_key",
    });
    return .{
        .algorithm_id = try parseUuid(foundation.identity.AlgorithmId, try requireField(object, "algorithm_id")),
        .algorithm_version = try parseVersion(foundation.version.AlgorithmVersion, try requireField(object, "algorithm_version")),
        .generator_id = try parseUuid(foundation.identity.GeneratorId, try requireField(object, "generator_id")),
        .generator_version = try parseVersion(foundation.version.GeneratorVersion, try requireField(object, "generator_version")),
        .root_seed = foundation.determinism.Seed128.parseLowerHex(try expectString(try requireField(object, "root_seed"))) catch return error.InvalidCanonicalData,
        .stable_generation_key = try expectString(try requireField(object, "stable_generation_key")),
    };
}

fn parseOptionalPresentation(value: std.json.Value) ParseError!?asset.PresentationRef {
    if (value == .null) return null;
    return asset.PresentationRef.init(try parseAssetRef(value)) catch return error.InvalidReference;
}

fn parseDependencies(allocator: std.mem.Allocator, value: std.json.Value) ParseError![]const foundation.reference.DirectDependency {
    const array = try expectArray(value);
    const result = try allocator.alloc(foundation.reference.DirectDependency, array.items.len);
    for (array.items, 0..) |item, index| {
        const object = try expectObject(item);
        try requireOnlyFields(object, &.{ "asset", "class" });
        result[index] = .{
            .asset = try parseAssetRef(try requireField(object, "asset")),
            .class = try parseEnum(foundation.reference.DependencyClass, try requireField(object, "class")),
        };
    }
    return result;
}

fn parseAssetRefs(allocator: std.mem.Allocator, value: std.json.Value) ParseError![]const foundation.reference.AssetRef {
    const array = try expectArray(value);
    const result = try allocator.alloc(foundation.reference.AssetRef, array.items.len);
    for (array.items, 0..) |item, index| result[index] = try parseAssetRef(item);
    return result;
}

fn parseAssetRef(value: std.json.Value) ParseError!foundation.reference.AssetRef {
    const object = try expectObject(value);
    try requireOnlyFields(object, &.{ "asset_id", "content_hash", "expected_kind", "version" });
    return .{
        .revision = .{
            .asset_id = try parseUuid(foundation.identity.AssetId, try requireField(object, "asset_id")),
            .version = try parseVersion(foundation.version.AssetVersion, try requireField(object, "version")),
            .content_hash = foundation.canonical_data.Sha256Digest.parseLowerHex(try expectString(try requireField(object, "content_hash"))) catch return error.InvalidCanonicalData,
        },
        .expected_kind = foundation.reference.AssetKind.init(try expectString(try requireField(object, "expected_kind"))) catch return error.InvalidAssetKind,
    };
}

fn parsePrefabNodes(allocator: std.mem.Allocator, value: std.json.Value) ParseError![]const prefab.PrefabNodeDefinition {
    const array = try expectArray(value);
    const result = try allocator.alloc(prefab.PrefabNodeDefinition, array.items.len);
    for (array.items, 0..) |item, index| {
        const object = try expectObject(item);
        try requireOnlyFields(object, &.{
            "enabled",
            "extensions",
            "local_transform",
            "nested_prefab_ref",
            "node_id",
            "parent",
            "tags",
            "visibility",
        });
        result[index] = .{
            .node_id = prefab.PrefabNodeId.init(try expectString(try requireField(object, "node_id"))) catch return error.InvalidIdentity,
            .parent = if (object.get("parent")) |parent| try parseOptionalPrefabNodeId(parent) else null,
            .local_transform = if (object.get("local_transform")) |transform| try parseLocalTransform(transform) else .identity,
            .nested_prefab_ref = if (object.get("nested_prefab_ref")) |reference| try parseOptionalAssetRef(reference) else null,
            .tags = if (object.get("tags")) |tags| try parseTags(allocator, tags) else &.{},
            .enabled = if (object.get("enabled")) |enabled| try parseEnum(metadata.EnabledIntent, enabled) else .inherit,
            .visibility = if (object.get("visibility")) |visibility| try parseEnum(metadata.VisibilityIntent, visibility) else .inherit,
            .extensions = if (object.get("extensions")) |extensions| try parseExtensions(allocator, extensions) else &.{},
        };
    }
    return result;
}

fn parseEntities(allocator: std.mem.Allocator, value: std.json.Value, legacy: bool) ParseError![]const entity.EntityInstanceDefinition {
    const array = try expectArray(value);
    const result = try allocator.alloc(entity.EntityInstanceDefinition, array.items.len);
    for (array.items, 0..) |item, index| result[index] = try parseEntity(allocator, item, legacy);
    return result;
}

fn parseEntity(allocator: std.mem.Allocator, value: std.json.Value, legacy: bool) ParseError!entity.EntityInstanceDefinition {
    const object = try expectObject(value);
    if (legacy) {
        try requireOnlyFields(object, &.{ "entity_id", "local_transform", "parent", "prefab_ref", "extensions" });
        return .{
            .entity_id = try parseUuid(foundation.identity.EntityId, try requireField(object, "entity_id")),
            .local_transform = try parseLocalTransform(try requireField(object, "local_transform")),
            .parent = try parseOptionalEntityRef(try requireField(object, "parent")),
            .prefab_ref = try parseOptionalAssetRef(try requireField(object, "prefab_ref")),
            .extensions = try parseExtensions(allocator, try requireField(object, "extensions")),
        };
    }
    try requireOnlyFields(object, &.{
        "camera_definition",
        "classification",
        "enabled",
        "entity_id",
        "extensions",
        "layers",
        "local_transform",
        "overrides",
        "parent",
        "prefab_ref",
        "presentation_ref",
        "tags",
        "visibility",
        "volume_shape_ref",
    });
    return .{
        .entity_id = try parseUuid(foundation.identity.EntityId, try requireField(object, "entity_id")),
        .local_transform = if (object.get("local_transform")) |transform| try parseLocalTransform(transform) else .identity,
        .parent = if (object.get("parent")) |parent| try parseOptionalEntityRef(parent) else null,
        .prefab_ref = if (object.get("prefab_ref")) |reference| try parseOptionalAssetRef(reference) else null,
        .overrides = if (object.get("overrides")) |overrides| try parseOverrides(allocator, overrides) else &.{},
        .tags = if (object.get("tags")) |tags| try parseTags(allocator, tags) else &.{},
        .enabled = if (object.get("enabled")) |enabled| try parseEnum(metadata.EnabledIntent, enabled) else .inherit,
        .visibility = if (object.get("visibility")) |visibility| try parseEnum(metadata.VisibilityIntent, visibility) else .inherit,
        .classification = if (object.get("classification")) |classification| try parseEnum(metadata.PlacementClassification, classification) else .authored,
        .presentation = if (object.get("presentation_ref")) |presentation| try parseOptionalPresentation(presentation) else null,
        .layers = if (object.get("layers")) |layers| try parseLayers(allocator, layers) else &.{},
        .extensions = if (object.get("extensions")) |extensions| try parseExtensions(allocator, extensions) else &.{},
        .camera_definition = if (object.get("camera_definition")) |definition| try parseOptionalCamera(definition) else null,
        .volume_shape = if (object.get("volume_shape_ref")) |reference| try parseOptionalVolumeShape(reference) else null,
    };
}

fn parseOptionalEntityRef(value: std.json.Value) ParseError!?entity.EntityRef {
    if (value == .null) return null;
    const object = try expectObject(value);
    try requireOnlyFields(object, &.{ "entity_id", "requirement" });
    return .{
        .entity_id = try parseUuid(foundation.identity.EntityId, try requireField(object, "entity_id")),
        .requirement = try parseEnum(entity.EntityReferenceRequirement, try requireField(object, "requirement")),
    };
}

fn parseOverrides(allocator: std.mem.Allocator, value: std.json.Value) ParseError![]const entity.OverrideRecord {
    const array = try expectArray(value);
    const result = try allocator.alloc(entity.OverrideRecord, array.items.len);
    for (array.items, 0..) |item, index| {
        const object = try expectObject(item);
        try requireOnlyFields(object, &.{ "component_type_id", "node_path", "property_path", "value" });
        result[index] = .{
            .target = .{
                .node_path = try expectString(try requireField(object, "node_path")),
                .component_type_id = extension.ComponentTypeId.init(try expectString(try requireField(object, "component_type_id"))) catch return error.InvalidIdentity,
                .property_path = try expectString(try requireField(object, "property_path")),
            },
            .canonical_value = try canonicalizeJsonValue(allocator, try requireField(object, "value")),
        };
    }
    return result;
}

fn parseTags(allocator: std.mem.Allocator, value: std.json.Value) ParseError![]const metadata.TagId {
    const array = try expectArray(value);
    const result = try allocator.alloc(metadata.TagId, array.items.len);
    for (array.items, 0..) |item, index| {
        result[index] = metadata.TagId.init(try expectString(item)) catch return error.InvalidIdentity;
    }
    return result;
}

fn parseLayers(allocator: std.mem.Allocator, value: std.json.Value) ParseError![]const metadata.LayerAssignment {
    const array = try expectArray(value);
    const result = try allocator.alloc(metadata.LayerAssignment, array.items.len);
    for (array.items, 0..) |item, index| {
        const object = try expectObject(item);
        try requireOnlyFields(object, &.{ "layer_ref", "system" });
        result[index] = .{
            .system = try parseEnum(metadata.LayerSystem, try requireField(object, "system")),
            .layer = try parseAssetRef(try requireField(object, "layer_ref")),
        };
    }
    return result;
}

fn parseExtensions(allocator: std.mem.Allocator, value: std.json.Value) ParseError![]const extension.ExtensionRecord {
    const array = try expectArray(value);
    const result = try allocator.alloc(extension.ExtensionRecord, array.items.len);
    for (array.items, 0..) |item, index| {
        const object = try expectObject(item);
        try requireOnlyFields(object, &.{ "criticality", "dependencies", "payload", "schema_version", "type_id" });
        result[index] = .{
            .type_id = extension.ComponentTypeId.init(try expectString(try requireField(object, "type_id"))) catch return error.InvalidIdentity,
            .schema_version = try parseVersion(foundation.version.SchemaVersion, try requireField(object, "schema_version")),
            .criticality = try parseEnum(extension.Criticality, try requireField(object, "criticality")),
            .canonical_payload = try canonicalizeJsonValue(allocator, try requireField(object, "payload")),
            .dependencies = try parseDependencies(allocator, try requireField(object, "dependencies")),
        };
    }
    return result;
}

fn parseOptionalCamera(value: std.json.Value) ParseError!?camera.CameraDefinition {
    if (value == .null) return null;
    const object = try expectObject(value);
    try requireOnlyFields(object, &.{ "far_clip_m", "lens_shift", "near_clip_m", "orthographic", "perspective", "projection" });
    const lens_shift = if (object.get("lens_shift")) |shift| try expectArray(shift) else null;
    if (lens_shift) |shift| if (shift.items.len != 2) return error.InvalidSpatialValue;
    return .{
        .projection = try parseEnum(camera.ProjectionKind, try requireField(object, "projection")),
        .perspective = try parseOptionalPerspective(try requireField(object, "perspective")),
        .orthographic = try parseOptionalOrthographic(try requireField(object, "orthographic")),
        .lens_shift_x = if (lens_shift) |shift| try parseF32(shift.items[0]) else 0.0,
        .lens_shift_y = if (lens_shift) |shift| try parseF32(shift.items[1]) else 0.0,
        .near_clip_m = try parseF32(try requireField(object, "near_clip_m")),
        .far_clip_m = try parseF32(try requireField(object, "far_clip_m")),
    };
}

fn parseOptionalPerspective(value: std.json.Value) ParseError!?camera.PerspectiveGeometry {
    if (value == .null) return null;
    const object = try expectObject(value);
    try requireOnlyFields(object, &.{ "focal_length_mm", "sensor_height_mm", "sensor_width_mm" });
    return .{
        .focal_length_mm = try parseF32(try requireField(object, "focal_length_mm")),
        .sensor_height_mm = try parseF32(try requireField(object, "sensor_height_mm")),
        .sensor_width_mm = try parseF32(try requireField(object, "sensor_width_mm")),
    };
}

fn parseOptionalOrthographic(value: std.json.Value) ParseError!?camera.OrthographicGeometry {
    if (value == .null) return null;
    const object = try expectObject(value);
    try requireOnlyFields(object, &.{ "horizontal_extent_m", "vertical_extent_m" });
    return .{
        .horizontal_extent_m = try parseF32(try requireField(object, "horizontal_extent_m")),
        .vertical_extent_m = try parseF32(try requireField(object, "vertical_extent_m")),
    };
}

fn parseOptionalVolumeShape(value: std.json.Value) ParseError!?entity.VolumeShapeRef {
    if (value == .null) return null;
    return entity.VolumeShapeRef.init(try parseAssetRef(value)) catch return error.InvalidReference;
}

fn parseOriginMm(value: std.json.Value) ParseError!level.WorldCoordinateOrigin {
    const array = try expectArray(value);
    if (array.items.len != 3) return error.InvalidSpatialValue;
    return .{
        .x_mm = try parseI64(array.items[0]),
        .y_mm = try parseI64(array.items[1]),
        .z_mm = try parseI64(array.items[2]),
    };
}

fn parseOriginM(value: std.json.Value) ParseError![3]i64 {
    const array = try expectArray(value);
    if (array.items.len != 3) return error.InvalidSpatialValue;
    return .{ try parseI64(array.items[0]), try parseI64(array.items[1]), try parseI64(array.items[2]) };
}

fn parseLocalTransform(value: std.json.Value) ParseError!foundation.spatial.LocalTransform {
    const object = try expectObject(value);
    try requireOnlyFields(object, &.{ "rotation", "scale", "translation_m" });
    const translation = try parseVec3(try requireField(object, "translation_m"));
    const scale = try parseVec3(try requireField(object, "scale"));
    const rotation_values = try expectArray(try requireField(object, "rotation"));
    if (rotation_values.items.len != 4) return error.InvalidSpatialValue;
    const rotation = foundation.spatial.Quaternion.initCanonical(
        try parseF32(rotation_values.items[0]),
        try parseF32(rotation_values.items[1]),
        try parseF32(rotation_values.items[2]),
        try parseF32(rotation_values.items[3]),
    ) catch return error.InvalidSpatialValue;
    return foundation.spatial.LocalTransform.init(translation, rotation, scale) catch return error.InvalidSpatialValue;
}

fn parseVec3(value: std.json.Value) ParseError!foundation.spatial.Vec3 {
    const array = try expectArray(value);
    if (array.items.len != 3) return error.InvalidSpatialValue;
    return foundation.spatial.Vec3.init(
        try parseF32(array.items[0]),
        try parseF32(array.items[1]),
        try parseF32(array.items[2]),
    ) catch return error.InvalidSpatialValue;
}

fn parseOptionalAssetRef(value: std.json.Value) ParseError!?foundation.reference.AssetRef {
    if (value == .null) return null;
    return try parseAssetRef(value);
}

fn parseOptionalPrefabNodeId(value: std.json.Value) ParseError!?prefab.PrefabNodeId {
    if (value == .null) return null;
    return prefab.PrefabNodeId.init(try expectString(value)) catch return error.InvalidIdentity;
}

fn parseUuid(comptime T: type, value: std.json.Value) ParseError!T {
    return T.parseCanonical(try expectString(value)) catch return error.InvalidIdentity;
}

fn parseVersion(comptime T: type, value: std.json.Value) ParseError!T {
    return T.parse(try expectString(value)) catch return error.InvalidVersion;
}

fn parseEnum(comptime T: type, value: std.json.Value) ParseError!T {
    const text = try expectString(value);
    inline for (@typeInfo(T).@"enum".fields) |field| {
        if (std.mem.eql(u8, field.name, text)) return @enumFromInt(field.value);
    }
    return error.InvalidEnumValue;
}

fn parseF32(value: std.json.Value) ParseError!f32 {
    const result: f32 = switch (value) {
        .integer => |number| @floatFromInt(number),
        .float => |number| @floatCast(number),
        .number_string => |number| std.fmt.parseFloat(f32, number) catch return error.ExpectedNumber,
        else => return error.ExpectedNumber,
    };
    if (!std.math.isFinite(result)) return error.ExpectedNumber;
    return if (result == 0.0) 0.0 else result;
}

fn parseI64(value: std.json.Value) ParseError!i64 {
    return switch (value) {
        .integer => |number| number,
        .number_string => |number| std.fmt.parseInt(i64, number, 10) catch return error.ExpectedInteger,
        else => error.ExpectedInteger,
    };
}

fn parseOptionalString(value: std.json.Value) ParseError!?[]const u8 {
    if (value == .null) return null;
    return try expectString(value);
}

fn expectObject(value: std.json.Value) ParseError!std.json.ObjectMap {
    return switch (value) {
        .object => |object| object,
        else => error.ExpectedObject,
    };
}

fn expectArray(value: std.json.Value) ParseError!std.json.Array {
    return switch (value) {
        .array => |array| array,
        else => error.ExpectedArray,
    };
}

fn expectString(value: std.json.Value) ParseError![]const u8 {
    return switch (value) {
        .string => |string| string,
        else => error.ExpectedString,
    };
}

fn requireField(object: std.json.ObjectMap, field: []const u8) ParseError!std.json.Value {
    return object.get(field) orelse error.MissingField;
}

fn requireOnlyFields(object: std.json.ObjectMap, fields: []const []const u8) ParseError!void {
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        var known = false;
        for (fields) |field| {
            if (std.mem.eql(u8, field, entry.key_ptr.*)) known = true;
        }
        if (!known) return error.UnknownField;
    }
}

fn canonicalizeJsonValue(allocator: std.mem.Allocator, value: std.json.Value) ParseError![]const u8 {
    var buffer: [extension.max_payload_bytes]u8 = undefined;
    var writer = foundation.canonical_data.Writer.init(&buffer);
    canonical_json.writeValue(&writer, value) catch |write_error| switch (write_error) {
        error.OutputTooSmall => return error.PayloadTooLarge,
        else => return error.InvalidCanonicalData,
    };
    return allocator.dupe(u8, writer.bytes()) catch error.OutOfMemory;
}
