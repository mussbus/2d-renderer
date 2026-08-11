const std = @import("std");
const canonical = @import("canonical_model");
const identity = @import("identity.zig");
const normalization = @import("normalization.zig");
const schema = @import("schema.zig");

pub const SerializationError = error{
    OutOfMemory,
    NonFiniteFloat,
    InvalidQuaternion,
    InvalidNormalizedCollection,
    OutputTooSmall,
};

pub fn serializeAlloc(
    allocator: std.mem.Allocator,
    normalized: normalization.NormalizedGeometry,
) SerializationError![]u8 {
    var writer = Writer{ .allocator = allocator };
    errdefer writer.bytes.deinit(allocator);
    try writeDefinition(&writer, normalized.source.*);
    return writer.bytes.toOwnedSlice(allocator);
}

const Writer = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,

    fn write(self: *Writer, value: []const u8) SerializationError!void {
        try self.bytes.appendSlice(self.allocator, value);
    }

    fn byte(self: *Writer, value: u8) SerializationError!void {
        try self.bytes.append(self.allocator, value);
    }
};

fn writeDefinition(writer: *Writer, value: schema.GeometryDefinition) SerializationError!void {
    try writer.write("{\"schema_identity\":");
    try writeValue(writer, schema.GeometrySchemaIdentity, value.schema_identity);
    try writer.write(",\"asset_identity\":");
    try writeValue(writer, schema.GeometryAssetIdentity, value.asset_identity);
    try writer.write(",\"compiler_identity\":");
    try writeValue(writer, schema.GeometryCompilerIdentity, value.compiler_identity);
    try writer.write(",\"structural_compatibility\":");
    try writeStructuralCompatibility(writer, value.structural_compatibility);
    try writer.write(",\"topology_identity\":");
    try writeValue(writer, schema.TopologyIdentity, value.topology_identity);
    try writer.write(",\"meshes\":");
    try writeSortedStringRecords(writer, schema.Mesh, value.meshes, "mesh_id");
    try writer.write(",\"face_sets\":");
    try writeSortedStringRecords(writer, schema.FaceSet, value.face_sets, "face_set_id");
    // Keep the Prompt 2A canonical form byte-stable when no internal topology
    // loops exist. Production sources emit the field as soon as they use it.
    if (value.topology_loops.len != 0) {
        try writer.write(",\"topology_loops\":");
        try writeSortedStringRecords(writer, schema.TopologyLoop, value.topology_loops, "topology_loop_id");
    }
    try writer.write(",\"seam_bindings\":");
    try writeSortedStringRecords(writer, schema.GeometrySeamBinding, value.seam_bindings, "geometry_seam_binding_id");
    try writer.write(",\"geometry_bindings\":");
    try writeSortedStringRecords(writer, schema.GeometryBinding, value.geometry_bindings, "geometry_binding_id");
    try writer.write(",\"module_interfaces\":");
    try writeSortedStringRecords(writer, schema.ModuleInterface, value.module_interfaces, "module_interface_id");
    try writer.write(",\"collision_proxies\":");
    try writeSortedStringRecords(writer, schema.CollisionProxy, value.collision_proxies, "collision_proxy_id");
    try writer.byte('}');
}

fn writeStructuralCompatibility(writer: *Writer, value: schema.StructuralCompatibility) SerializationError!void {
    try writer.write("{\"structural_asset_id\":");
    try writeValue(writer, canonical.identity.AssetId, value.structural_asset_id);
    try writer.write(",\"structural_asset_version\":");
    try writeValue(writer, canonical.identity.AssetVersion, value.structural_asset_version);
    try writer.write(",\"structural_schema_id\":");
    try writeValue(writer, canonical.identity.SchemaId, value.structural_schema_id);
    try writer.write(",\"structural_schema_version\":");
    try writeValue(writer, canonical.identity.SchemaVersion, value.structural_schema_version);
    try writer.write(",\"normalized_source_sha256\":");
    try writeValue(writer, identity.Sha256Digest, value.normalized_source_sha256);
    try writer.write(",\"coordinate_contract\":");
    try writeValue(writer, canonical.coordinate.CoordinateContract, value.coordinate_contract);
    try writer.write(",\"required_component_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.ComponentId, value.required_component_ids);
    try writer.write(",\"required_bone_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.BoneId, value.required_bone_ids);
    try writer.write(",\"required_anchor_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.AnchorId, value.required_anchor_ids);
    try writer.write(",\"required_surface_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.SurfaceId, value.required_surface_ids);
    try writer.write(",\"required_region_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.RegionId, value.required_region_ids);
    try writer.write(",\"required_material_instance_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.MaterialInstanceId, value.required_material_instance_ids);
    try writer.write(",\"required_seam_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.SeamId, value.required_seam_ids);
    try writer.write(",\"required_landmark_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.LandmarkId, value.required_landmark_ids);
    try writer.write(",\"required_interaction_site_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.InteractionSiteId, value.required_interaction_site_ids);
    try writer.byte('}');
}

fn writeMesh(writer: *Writer, value: schema.Mesh) SerializationError!void {
    try writer.write("{\"mesh_id\":");
    try writeValue(writer, identity.MeshId, value.mesh_id);
    try writer.write(",\"owner_component_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.ComponentId, value.owner_component_ids);
    try writer.write(",\"next_vertex_id\":");
    try writeUnsigned(writer, value.next_vertex_id);
    try writer.write(",\"next_face_id\":");
    try writeUnsigned(writer, value.next_face_id);
    try writer.write(",\"connectivity_policy\":");
    try writeEnum(writer, value.connectivity_policy);
    try writer.write(",\"subdivision_policy\":");
    try writeEnum(writer, value.subdivision_policy);
    try writer.write(",\"vertices\":");
    try writeSortedNumericRecords(writer, schema.Vertex, value.vertices, "vertex_id");
    try writer.write(",\"faces\":");
    try writeSortedNumericRecords(writer, schema.QuadFace, value.faces, "face_id");
    try writer.write(",\"boundary_loops\":");
    try writeSortedStringRecords(writer, schema.BoundaryLoop, value.boundary_loops, "boundary_loop_id");
    try writer.byte('}');
}

fn writeQuadFace(writer: *Writer, value: schema.QuadFace) SerializationError!void {
    try writer.write("{\"face_id\":");
    try writeValue(writer, identity.FaceId, value.face_id);
    try writer.write(",\"vertex_ids\":");
    try writeValue(writer, [4]identity.VertexId, value.vertex_ids);
    try writer.write(",\"diagonal\":");
    try writeEnum(writer, value.diagonal);
    try writer.write(",\"primary_surface_id\":");
    try writeValue(writer, canonical.identity.SurfaceId, value.primary_surface_id);
    try writer.write(",\"material_instance_id\":");
    try writeValue(writer, canonical.identity.MaterialInstanceId, value.material_instance_id);
    try writer.write(",\"region_ids\":");
    try writeSortedTypedIds(writer, canonical.identity.RegionId, value.region_ids);
    try writer.write(",\"surface_coordinates\":");
    try writeValue(writer, [4]schema.SurfaceCoordinateCorner, value.surface_coordinates);
    try writer.write(",\"texture_coordinates\":");
    try writeValue(writer, [4]schema.TextureCoordinateCorner, value.texture_coordinates);
    try writer.byte('}');
}

fn writeFaceSet(writer: *Writer, value: schema.FaceSet) SerializationError!void {
    try writer.write("{\"face_set_id\":");
    try writeValue(writer, identity.FaceSetId, value.face_set_id);
    try writer.write(",\"mesh_id\":");
    try writeValue(writer, identity.MeshId, value.mesh_id);
    try writer.write(",\"face_ids\":");
    try writeSortedNumericIds(writer, identity.FaceId, value.face_ids);
    try writer.byte('}');
}

fn writeValue(writer: *Writer, comptime T: type, value: T) SerializationError!void {
    if (comptime isTypedStringId(T)) return writeString(writer, value.value.bytes);
    if (comptime T == identity.VertexId or T == identity.FaceId) return writeUnsigned(writer, value.value);
    if (comptime T == identity.Sha256Digest) return writeString(writer, &value.toHex());
    if (comptime T == schema.GeometryDefinition) return writeDefinition(writer, value);
    if (comptime T == schema.StructuralCompatibility) return writeStructuralCompatibility(writer, value);
    if (comptime T == schema.Mesh) return writeMesh(writer, value);
    if (comptime T == schema.QuadFace) return writeQuadFace(writer, value);
    if (comptime T == schema.FaceSet) return writeFaceSet(writer, value);
    if (comptime T == schema.Vec2) {
        try writer.byte('[');
        try writeF32(writer, value.x);
        try writer.byte(',');
        try writeF32(writer, value.y);
        return writer.byte(']');
    }
    if (comptime T == canonical.math3d.Vec3) return writeVec3(writer, value);
    if (comptime T == canonical.math3d.Quaternion) return writeQuaternion(writer, value);

    switch (@typeInfo(T)) {
        .bool => try writer.write(if (value) "true" else "false"),
        .float => try writeF32(writer, value),
        .int => try writeUnsigned(writer, value),
        .@"enum" => try writeEnum(writer, value),
        .optional => |optional_info| {
            if (value) |item| try writeValue(writer, optional_info.child, item) else try writer.write("null");
        },
        .pointer => |pointer_info| switch (pointer_info.size) {
            .slice => try writeSlice(writer, pointer_info.child, value),
            else => @compileError("canonical geometry serializer only supports slice pointers"),
        },
        .array => |array_info| try writeArray(writer, array_info.child, value),
        .@"struct" => try writeStruct(writer, T, value),
        else => @compileError("unsupported canonical geometry serialization type: " ++ @typeName(T)),
    }
}

fn isTypedStringId(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "kind_name"),
        else => false,
    };
}

fn writeStruct(writer: *Writer, comptime T: type, value: T) SerializationError!void {
    try writer.byte('{');
    inline for (@typeInfo(T).@"struct".fields, 0..) |field, index| {
        if (index != 0) try writer.byte(',');
        try writeString(writer, field.name);
        try writer.byte(':');
        try writeValue(writer, field.type, @field(value, field.name));
    }
    try writer.byte('}');
}

fn writeSlice(writer: *Writer, comptime Child: type, values: []const Child) SerializationError!void {
    try writer.byte('[');
    for (values, 0..) |item, index| {
        if (index != 0) try writer.byte(',');
        try writeValue(writer, Child, item);
    }
    try writer.byte(']');
}

fn writeArray(writer: *Writer, comptime Child: type, values: anytype) SerializationError!void {
    try writer.byte('[');
    for (values, 0..) |item, index| {
        if (index != 0) try writer.byte(',');
        try writeValue(writer, Child, item);
    }
    try writer.byte(']');
}

fn writeSortedTypedIds(writer: *Writer, comptime T: type, values: []const T) SerializationError!void {
    try writer.byte('[');
    var previous: ?[]const u8 = null;
    for (0..values.len) |emitted| {
        var selected: ?usize = null;
        for (values, 0..) |item, index| {
            const bytes = item.value.bytes;
            if (previous) |last| if (std.mem.order(u8, bytes, last) != .gt) continue;
            if (selected == null or std.mem.order(u8, bytes, values[selected.?].value.bytes) == .lt) selected = index;
        }
        if (selected == null) return error.InvalidNormalizedCollection;
        if (emitted != 0) try writer.byte(',');
        try writeValue(writer, T, values[selected.?]);
        previous = values[selected.?].value.bytes;
    }
    try writer.byte(']');
}

fn writeSortedNumericIds(writer: *Writer, comptime T: type, values: []const T) SerializationError!void {
    try writer.byte('[');
    var previous: ?u32 = null;
    for (0..values.len) |emitted| {
        var selected: ?usize = null;
        for (values, 0..) |item, index| {
            if (previous) |last| if (item.value <= last) continue;
            if (selected == null or item.value < values[selected.?].value) selected = index;
        }
        if (selected == null) return error.InvalidNormalizedCollection;
        if (emitted != 0) try writer.byte(',');
        try writeValue(writer, T, values[selected.?]);
        previous = values[selected.?].value;
    }
    try writer.byte(']');
}

fn writeSortedStringRecords(
    writer: *Writer,
    comptime T: type,
    values: []const T,
    comptime id_field: []const u8,
) SerializationError!void {
    try writer.byte('[');
    var previous: ?[]const u8 = null;
    for (0..values.len) |emitted| {
        var selected: ?usize = null;
        for (values, 0..) |item, index| {
            const bytes = @field(item, id_field).value.bytes;
            if (previous) |last| if (std.mem.order(u8, bytes, last) != .gt) continue;
            if (selected == null or std.mem.order(u8, bytes, @field(values[selected.?], id_field).value.bytes) == .lt) selected = index;
        }
        if (selected == null) return error.InvalidNormalizedCollection;
        if (emitted != 0) try writer.byte(',');
        try writeValue(writer, T, values[selected.?]);
        previous = @field(values[selected.?], id_field).value.bytes;
    }
    try writer.byte(']');
}

fn writeSortedNumericRecords(
    writer: *Writer,
    comptime T: type,
    values: []const T,
    comptime id_field: []const u8,
) SerializationError!void {
    try writer.byte('[');
    var previous: ?u32 = null;
    for (0..values.len) |emitted| {
        var selected: ?usize = null;
        for (values, 0..) |item, index| {
            const numeric = @field(item, id_field).value;
            if (previous) |last| if (numeric <= last) continue;
            if (selected == null or numeric < @field(values[selected.?], id_field).value) selected = index;
        }
        if (selected == null) return error.InvalidNormalizedCollection;
        if (emitted != 0) try writer.byte(',');
        try writeValue(writer, T, values[selected.?]);
        previous = @field(values[selected.?], id_field).value;
    }
    try writer.byte(']');
}

fn writeVec3(writer: *Writer, value: canonical.math3d.Vec3) SerializationError!void {
    try writer.byte('[');
    try writeF32(writer, value.x);
    try writer.byte(',');
    try writeF32(writer, value.y);
    try writer.byte(',');
    try writeF32(writer, value.z);
    try writer.byte(']');
}

fn writeQuaternion(writer: *Writer, value: canonical.math3d.Quaternion) SerializationError!void {
    const normalized = canonical.math3d.Quaternion.initCanonical(value.x, value.y, value.z, value.w) catch return error.InvalidQuaternion;
    try writer.byte('[');
    try writeF32(writer, normalized.x);
    try writer.byte(',');
    try writeF32(writer, normalized.y);
    try writer.byte(',');
    try writeF32(writer, normalized.z);
    try writer.byte(',');
    try writeF32(writer, normalized.w);
    try writer.byte(']');
}

fn writeEnum(writer: *Writer, value: anytype) SerializationError!void {
    try writeString(writer, @tagName(value));
}

fn writeUnsigned(writer: *Writer, value: anytype) SerializationError!void {
    var buffer: [32]u8 = undefined;
    const rendered = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch return error.OutputTooSmall;
    try writer.write(rendered);
}

fn writeF32(writer: *Writer, raw_value: f32) SerializationError!void {
    if (!std.math.isFinite(raw_value)) return error.NonFiniteFloat;
    const value: f32 = if (raw_value == 0) 0 else raw_value;
    var buffer: [64]u8 = undefined;
    const rendered = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch return error.OutputTooSmall;
    try writer.write(rendered);
}

fn writeString(writer: *Writer, value: []const u8) SerializationError!void {
    try writer.byte('"');
    for (value) |byte_value| switch (byte_value) {
        '"' => try writer.write("\\\""),
        '\\' => try writer.write("\\\\"),
        '\n' => try writer.write("\\n"),
        '\r' => try writer.write("\\r"),
        '\t' => try writer.write("\\t"),
        else => try writer.byte(byte_value),
    };
    try writer.byte('"');
}
