const foundation = @import("foundation");
const scene_core = @import("scene_core");

pub fn assetId(text: []const u8) !foundation.identity.AssetId {
    return foundation.identity.AssetId.parseCanonical(text);
}

pub fn entityId(text: []const u8) !foundation.identity.EntityId {
    return foundation.identity.EntityId.parseCanonical(text);
}

pub fn producerId(text: []const u8) !foundation.identity.ProducerId {
    return foundation.identity.ProducerId.parseCanonical(text);
}

pub fn assetRef(id_text: []const u8, kind_name: []const u8, hash_byte: u8) !foundation.reference.AssetRef {
    return .{
        .revision = .{
            .asset_id = try assetId(id_text),
            .version = foundation.version.AssetVersion.init(1, 0, 0),
            .content_hash = .{ .bytes = [_]u8{hash_byte} ** 32 },
        },
        .expected_kind = try foundation.reference.AssetKind.init(kind_name),
    };
}

pub fn header(
    kind: foundation.reference.AssetKind,
    schema_id: foundation.identity.AssetId,
    id_text: []const u8,
) !scene_core.asset.AssetHeader {
    return .{
        .schema = .{ .id = schema_id, .version = scene_core.asset.current_schema_version },
        .asset_id = try assetId(id_text),
        .asset_version = foundation.version.AssetVersion.init(1, 0, 0),
        .kind = kind,
        .slug = "fixture",
        .producer = .{
            .id = try producerId("7bcd9782-6252-5d2f-94be-47e477f0a5aa"),
            .version = foundation.version.ProducerVersion.init(1, 0, 0),
        },
    };
}

pub fn acceptPayload(
    payload: []const u8,
    dependencies: []const foundation.reference.DirectDependency,
) scene_core.extension.DescriptorError!void {
    _ = dependencies;
    if (payload.len == 0) return error.InvalidPayload;
}

pub fn frozenRegistry(storage: []scene_core.extension.Descriptor) !scene_core.extension.DescriptorRegistry {
    var registry = scene_core.extension.DescriptorRegistry.init(storage);
    try registry.register(.{
        .type_id = try scene_core.extension.ComponentTypeId.init("r.light"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .validate = acceptPayload,
    });
    registry.freeze();
    return registry;
}
