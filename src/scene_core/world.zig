const foundation = @import("foundation");
const asset = @import("asset.zig");
const entity = @import("entity.zig");

pub const WorldDefinition = struct {
    header: asset.AssetHeader,
    level_refs: []const foundation.reference.AssetRef,
    persistent_entities: []const entity.EntityInstanceDefinition,
};
