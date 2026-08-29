const std = @import("std");
const foundation = @import("foundation");
const asset = @import("asset.zig");
const entity = @import("entity.zig");
const extension = @import("extension.zig");
const metadata = @import("metadata.zig");

pub const max_nested_prefab_depth: usize = 32;

pub const PrefabNodeId = struct {
    value: []const u8,

    pub fn init(value: []const u8) error{InvalidPrefabNodeId}!PrefabNodeId {
        if (!entity.validIdentifier(value)) return error.InvalidPrefabNodeId;
        return .{ .value = value };
    }

    pub fn eql(a: PrefabNodeId, b: PrefabNodeId) bool {
        return std.mem.eql(u8, a.value, b.value);
    }

    pub fn order(a: PrefabNodeId, b: PrefabNodeId) std.math.Order {
        return std.mem.order(u8, a.value, b.value);
    }
};

pub const PrefabNodeDefinition = struct {
    node_id: PrefabNodeId,
    parent: ?PrefabNodeId = null,
    local_transform: foundation.spatial.LocalTransform = .identity,
    nested_prefab_ref: ?foundation.reference.AssetRef = null,
    tags: []const metadata.TagId = &.{},
    enabled: metadata.EnabledIntent = .inherit,
    visibility: metadata.VisibilityIntent = .inherit,
    extensions: []const extension.ExtensionRecord = &.{},
};

pub const PrefabDefinition = struct {
    header: asset.AssetHeader,
    nodes: []const PrefabNodeDefinition,
};

pub fn deriveInstantiatedEntityId(
    root_entity_id: foundation.identity.EntityId,
    canonical_node_path: []const u8,
) error{ InvalidPrefabNodePath, FieldTooLarge }!foundation.identity.EntityId {
    if (!validNodePath(canonical_node_path)) return error.InvalidPrefabNodePath;
    const namespace = foundation.identity.NamespaceId.fromCanonicalBytes(root_entity_id.bytes) catch return error.InvalidPrefabNodePath;
    return foundation.identity.uuidV5Fields(
        foundation.identity.EntityId,
        namespace,
        &.{ "foundation.prefab_child.v1", canonical_node_path },
    ) catch error.FieldTooLarge;
}

pub fn findNode(definition: PrefabDefinition, id: PrefabNodeId) ?PrefabNodeDefinition {
    for (definition.nodes) |node| if (node.node_id.eql(id)) return node;
    return null;
}

fn validNodePath(value: []const u8) bool {
    if (value.len == 0 or value.len > 255 or value[0] == '/' or value[value.len - 1] == '/') return false;
    var iterator = std.mem.splitScalar(u8, value, '/');
    while (iterator.next()) |segment| if (!entity.validIdentifier(segment)) return false;
    return true;
}
