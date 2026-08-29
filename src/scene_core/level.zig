const asset = @import("asset.zig");
const entity = @import("entity.zig");

/// Stable world-frame origin expressed in exact integer millimetres. Entity
/// transforms remain level-local f32 metres. Future floating-origin work must
/// publish a derived shift generation and cannot rewrite this authored value.
pub const WorldCoordinateOrigin = struct {
    x_mm: i64,
    y_mm: i64,
    z_mm: i64,
};

pub const LevelDefinition = struct {
    header: asset.AssetHeader,
    origin: WorldCoordinateOrigin,
    entities: []const entity.EntityInstanceDefinition,
};

pub const PreAcceptanceLevelDefinitionV0_9 = struct {
    header: asset.AssetHeader,
    origin_m: [3]i64,
    entities: []const entity.EntityInstanceDefinition,
};
