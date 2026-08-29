const std = @import("std");
const foundation = @import("foundation");
const asset = @import("asset.zig");
const camera = @import("camera.zig");
const extension = @import("extension.zig");
const metadata = @import("metadata.zig");

pub const EntityReferenceRequirement = enum {
    required,
    optional,
};

pub const EntityRef = struct {
    entity_id: foundation.identity.EntityId,
    requirement: EntityReferenceRequirement,
};

pub const VolumeShapeRef = struct {
    asset: foundation.reference.AssetRef,

    pub fn init(reference: foundation.reference.AssetRef) error{WrongAssetKind}!VolumeShapeRef {
        if (!reference.expected_kind.eql(asset.volume_shape_kind)) return error.WrongAssetKind;
        return .{ .asset = reference };
    }
};

pub const OverridePath = struct {
    node_path: []const u8,
    component_type_id: extension.ComponentTypeId,
    property_path: []const u8,

    pub fn validate(self: OverridePath) error{InvalidOverridePath}!void {
        if (!validNodePath(self.node_path) or !validPropertyPath(self.property_path)) return error.InvalidOverridePath;
    }
};

pub const OverrideRecord = struct {
    target: OverridePath,
    canonical_value: []const u8,
};

pub const max_overrides_per_instance: usize = 128;

pub const EntityInstanceDefinition = struct {
    entity_id: foundation.identity.EntityId,
    local_transform: foundation.spatial.LocalTransform = .identity,
    parent: ?EntityRef = null,
    prefab_ref: ?foundation.reference.AssetRef = null,
    overrides: []const OverrideRecord = &.{},
    tags: []const metadata.TagId = &.{},
    enabled: metadata.EnabledIntent = .inherit,
    visibility: metadata.VisibilityIntent = .inherit,
    classification: metadata.PlacementClassification = .authored,
    presentation: ?asset.PresentationRef = null,
    layers: []const metadata.LayerAssignment = &.{},
    extensions: []const extension.ExtensionRecord = &.{},
    camera_definition: ?camera.CameraDefinition = null,
    volume_shape: ?VolumeShapeRef = null,
};

pub fn overrideOrder(a: OverrideRecord, b: OverrideRecord) std.math.Order {
    var result = std.mem.order(u8, a.target.node_path, b.target.node_path);
    if (result != .eq) return result;
    result = a.target.component_type_id.order(b.target.component_type_id);
    if (result != .eq) return result;
    return std.mem.order(u8, a.target.property_path, b.target.property_path);
}

fn validNodePath(value: []const u8) bool {
    if (value.len == 0 or value.len > 255 or value[0] == '/' or value[value.len - 1] == '/') return false;
    var iterator = std.mem.splitScalar(u8, value, '/');
    while (iterator.next()) |segment| if (!validIdentifier(segment)) return false;
    return true;
}

fn validPropertyPath(value: []const u8) bool {
    if (value.len == 0 or value.len > 255 or value[0] == '.' or value[value.len - 1] == '.') return false;
    var iterator = std.mem.splitScalar(u8, value, '.');
    while (iterator.next()) |segment| if (!validIdentifier(segment)) return false;
    return true;
}

pub fn validIdentifier(value: []const u8) bool {
    if (value.len == 0 or value.len > 63 or value[0] < 'a' or value[0] > 'z') return false;
    for (value[1..]) |byte| {
        if (!((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '_')) return false;
    }
    return true;
}
