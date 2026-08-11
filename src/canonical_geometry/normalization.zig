const schema = @import("schema.zig");

/// A validated geometry definition whose canonical serializer applies the
/// schema-declared stable ordering. Source array order remains non-authoritative
/// for record collections; face winding and loop edge order remain semantic.
pub const NormalizedGeometry = struct {
    source: *const schema.GeometryDefinition,
};

pub fn normalize(source: *const schema.GeometryDefinition) NormalizedGeometry {
    return .{ .source = source };
}
