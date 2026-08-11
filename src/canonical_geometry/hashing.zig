const std = @import("std");
const identity = @import("identity.zig");
const normalization = @import("normalization.zig");
const schema = @import("schema.zig");
const serialization = @import("serialization.zig");

pub const SourceHashResult = struct {
    allocator: std.mem.Allocator,
    canonical_bytes: []u8,
    geometry_source_sha256: identity.Sha256Digest,

    pub fn deinit(self: *SourceHashResult) void {
        self.allocator.free(self.canonical_bytes);
        self.* = undefined;
    }
};

pub fn sourceHashAlloc(
    allocator: std.mem.Allocator,
    normalized: normalization.NormalizedGeometry,
) !SourceHashResult {
    const canonical_bytes = try serialization.serializeAlloc(allocator, normalized);
    errdefer allocator.free(canonical_bytes);
    return .{
        .allocator = allocator,
        .canonical_bytes = canonical_bytes,
        .geometry_source_sha256 = hashBytes(canonical_bytes),
    };
}

pub fn topologyHashAlloc(allocator: std.mem.Allocator, geometry: *const schema.GeometryDefinition) !identity.Sha256Digest {
    var payload = Payload.init(allocator);
    defer payload.deinit();
    try payload.field("canonical_geometry_control_topology_v1");
    try payload.field(geometry.topology_identity.topology_id.value.bytes);
    try payload.version(geometry.topology_identity.compatibility_version);
    try payload.u32Value(geometry.topology_identity.revision);
    try payload.u32Value(try toU32(geometry.meshes.len));

    var previous_mesh: ?[]const u8 = null;
    for (0..geometry.meshes.len) |_| {
        const mesh = nextMesh(geometry.meshes, previous_mesh) orelse return error.DuplicateMeshId;
        try payload.field(mesh.mesh_id.value.bytes);
        try payload.u32Value(try toU32(mesh.vertices.len));
        var previous_vertex: ?u32 = null;
        for (0..mesh.vertices.len) |_| {
            const vertex_id = nextVertexId(mesh.vertices, previous_vertex) orelse return error.DuplicateVertexId;
            try payload.u32Value(vertex_id.value);
            previous_vertex = vertex_id.value;
        }
        try payload.u32Value(try toU32(mesh.faces.len));
        var previous_face: ?u32 = null;
        for (0..mesh.faces.len) |_| {
            const face = nextFace(mesh.faces, previous_face) orelse return error.DuplicateFaceId;
            try payload.u32Value(face.face_id.value);
            try payload.u32Value(4);
            for (face.vertex_ids) |vertex_id| try payload.u32Value(vertex_id.value);
            previous_face = face.face_id.value;
        }
        previous_mesh = mesh.mesh_id.value.bytes;
    }
    return hashBytes(payload.bytes.items);
}

/// Enforces the source-to-source topology revision rule. Position, semantic,
/// UV, diagonal, cursor, binding, and proxy changes do not advance the
/// revision. A stable-ID-set or ordered-connectivity change advances it by
/// exactly one within the same topology identity and compatibility version.
pub fn validateTopologyRevisionTransition(
    allocator: std.mem.Allocator,
    before: *const schema.GeometryDefinition,
    after: *const schema.GeometryDefinition,
) !void {
    if (!before.topology_identity.topology_id.eql(after.topology_identity.topology_id) or
        !before.topology_identity.compatibility_version.eql(after.topology_identity.compatibility_version))
    {
        return error.TopologyIdentityMismatch;
    }

    var before_content = before.*;
    var after_content = after.*;
    before_content.topology_identity.revision = 0;
    after_content.topology_identity.revision = 0;
    const before_hash = try topologyHashAlloc(allocator, &before_content);
    const after_hash = try topologyHashAlloc(allocator, &after_content);
    if (before_hash.eql(after_hash)) {
        if (after.topology_identity.revision != before.topology_identity.revision) {
            return error.UnchangedTopologyRevision;
        }
        return;
    }

    const expected_revision = std.math.add(u32, before.topology_identity.revision, 1) catch
        return error.TopologyRevisionExhausted;
    if (after.topology_identity.revision != expected_revision) {
        return error.TopologyRevisionMustAdvance;
    }
}

pub fn triangulationHashAlloc(allocator: std.mem.Allocator, geometry: *const schema.GeometryDefinition) !identity.Sha256Digest {
    var payload = Payload.init(allocator);
    defer payload.deinit();
    try payload.field("canonical_geometry_triangulation_v1");
    try payload.field(geometry.topology_identity.topology_id.value.bytes);
    try payload.version(geometry.topology_identity.compatibility_version);
    try payload.u32Value(geometry.topology_identity.revision);

    var previous_mesh: ?[]const u8 = null;
    for (0..geometry.meshes.len) |_| {
        const mesh = nextMesh(geometry.meshes, previous_mesh) orelse return error.DuplicateMeshId;
        try payload.field(mesh.mesh_id.value.bytes);
        var previous_face: ?u32 = null;
        for (0..mesh.faces.len) |_| {
            const face = nextFace(mesh.faces, previous_face) orelse return error.DuplicateFaceId;
            try payload.u32Value(face.face_id.value);
            try payload.u32Value(@intFromEnum(face.diagonal));
            const triangles: [2][3]identity.VertexId = switch (face.diagonal) {
                .v0_v2 => .{
                    .{ face.vertex_ids[0], face.vertex_ids[1], face.vertex_ids[2] },
                    .{ face.vertex_ids[0], face.vertex_ids[2], face.vertex_ids[3] },
                },
                .v1_v3 => .{
                    .{ face.vertex_ids[0], face.vertex_ids[1], face.vertex_ids[3] },
                    .{ face.vertex_ids[1], face.vertex_ids[2], face.vertex_ids[3] },
                },
            };
            for (triangles, 0..) |triangle, triangle_index| {
                try payload.u32Value(@intCast(triangle_index));
                for (triangle) |vertex_id| try payload.u32Value(vertex_id.value);
            }
            previous_face = face.face_id.value;
        }
        previous_mesh = mesh.mesh_id.value.bytes;
    }
    return hashBytes(payload.bytes.items);
}

pub fn neutralSignatureAlloc(
    allocator: std.mem.Allocator,
    geometry: *const schema.GeometryDefinition,
    structural_sha256: identity.Sha256Digest,
    source_sha256: identity.Sha256Digest,
    topology_sha256: identity.Sha256Digest,
) !identity.Sha256Digest {
    var payload = Payload.init(allocator);
    defer payload.deinit();
    try payload.field("canonical_geometry_neutral_signature_v1");
    try payload.field(geometry.schema_identity.geometry_schema_id.value.bytes);
    try payload.version(geometry.schema_identity.version);
    try payload.field(geometry.compiler_identity.geometry_compiler_id.value.bytes);
    try payload.version(geometry.compiler_identity.version);
    try payload.field(geometry.asset_identity.geometry_asset_id.value.bytes);
    try payload.version(geometry.asset_identity.version);
    try payload.field(&structural_sha256.bytes);
    try payload.field(&source_sha256.bytes);
    try payload.field(&topology_sha256.bytes);
    return hashBytes(payload.bytes.items);
}

pub fn hashBytes(bytes: []const u8) identity.Sha256Digest {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .bytes = digest };
}

const Payload = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,

    fn init(allocator: std.mem.Allocator) Payload {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *Payload) void {
        self.bytes.deinit(self.allocator);
    }

    fn field(self: *Payload, value: []const u8) !void {
        try self.u32Value(try toU32(value.len));
        try self.bytes.appendSlice(self.allocator, value);
    }

    fn version(self: *Payload, value: identity.Version) !void {
        try self.u32Value(value.major);
        try self.u32Value(value.minor);
        try self.u32Value(value.patch);
    }

    fn u32Value(self: *Payload, value: u32) !void {
        const encoded = [4]u8{
            @truncate(value),
            @truncate(value >> 8),
            @truncate(value >> 16),
            @truncate(value >> 24),
        };
        try self.bytes.appendSlice(self.allocator, &encoded);
    }
};

fn toU32(value: usize) !u32 {
    return std.math.cast(u32, value) orelse error.IdentityPayloadTooLarge;
}

fn nextMesh(meshes: []const schema.Mesh, previous: ?[]const u8) ?schema.Mesh {
    var selected: ?schema.Mesh = null;
    for (meshes) |mesh| {
        const bytes = mesh.mesh_id.value.bytes;
        if (previous) |last| if (std.mem.order(u8, bytes, last) != .gt) continue;
        if (selected == null or std.mem.order(u8, bytes, selected.?.mesh_id.value.bytes) == .lt) selected = mesh;
    }
    return selected;
}

fn nextVertexId(vertices: []const schema.Vertex, previous: ?u32) ?identity.VertexId {
    var selected: ?identity.VertexId = null;
    for (vertices) |vertex| {
        if (previous) |last| if (vertex.vertex_id.value <= last) continue;
        if (selected == null or vertex.vertex_id.value < selected.?.value) selected = vertex.vertex_id;
    }
    return selected;
}

fn nextFace(faces: []const schema.QuadFace, previous: ?u32) ?schema.QuadFace {
    var selected: ?schema.QuadFace = null;
    for (faces) |face| {
        if (previous) |last| if (face.face_id.value <= last) continue;
        if (selected == null or face.face_id.value < selected.?.face_id.value) selected = face;
    }
    return selected;
}
