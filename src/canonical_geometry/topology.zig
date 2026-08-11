const std = @import("std");
const canonical = @import("canonical_model");
const identity = @import("identity.zig");
const schema = @import("schema.zig");

pub const DerivedTriangleId = struct {
    source_face_id: identity.FaceId,
    triangle_index: u8,
};

pub const DerivedTriangle = struct {
    triangle_id: DerivedTriangleId,
    vertex_ids: [3]identity.VertexId,
};

pub const TriangulatedMesh = struct {
    allocator: std.mem.Allocator,
    mesh_id: identity.MeshId,
    triangles: []DerivedTriangle,

    pub fn deinit(self: *TriangulatedMesh) void {
        self.allocator.free(self.triangles);
        self.* = undefined;
    }
};

pub fn triangulateAlloc(allocator: std.mem.Allocator, mesh: *const schema.Mesh) !TriangulatedMesh {
    const triangles = try allocator.alloc(DerivedTriangle, std.math.mul(usize, mesh.faces.len, 2) catch return error.TopologyTooLarge);
    errdefer allocator.free(triangles);
    const sorted_faces = try allocator.dupe(schema.QuadFace, mesh.faces);
    defer allocator.free(sorted_faces);
    std.mem.sort(schema.QuadFace, sorted_faces, {}, lessThanFaceId);

    for (sorted_faces, 0..) |face, emitted| {
        if (emitted > 0 and face.face_id.eql(sorted_faces[emitted - 1].face_id)) return error.DuplicateFaceId;
        const base = emitted * 2;
        triangles[base] = .{
            .triangle_id = .{ .source_face_id = face.face_id, .triangle_index = 0 },
            .vertex_ids = switch (face.diagonal) {
                .v0_v2 => .{ face.vertex_ids[0], face.vertex_ids[1], face.vertex_ids[2] },
                .v1_v3 => .{ face.vertex_ids[0], face.vertex_ids[1], face.vertex_ids[3] },
            },
        };
        triangles[base + 1] = .{
            .triangle_id = .{ .source_face_id = face.face_id, .triangle_index = 1 },
            .vertex_ids = switch (face.diagonal) {
                .v0_v2 => .{ face.vertex_ids[0], face.vertex_ids[2], face.vertex_ids[3] },
                .v1_v3 => .{ face.vertex_ids[1], face.vertex_ids[2], face.vertex_ids[3] },
            },
        };
    }

    return .{ .allocator = allocator, .mesh_id = mesh.mesh_id, .triangles = triangles };
}

pub const EdgeKey = struct {
    low: identity.VertexId,
    high: identity.VertexId,

    pub fn init(a: identity.VertexId, b: identity.VertexId) EdgeKey {
        return if (a.value < b.value) .{ .low = a, .high = b } else .{ .low = b, .high = a };
    }

    pub fn eql(a: EdgeKey, b: EdgeKey) bool {
        return a.low.eql(b.low) and a.high.eql(b.high);
    }
};

pub const SubdivisionVertexId = union(enum) {
    source_vertex: identity.VertexId,
    edge_point: EdgeKey,
    face_point: identity.FaceId,
};

pub const SubdivisionFaceId = struct {
    source_face_id: identity.FaceId,
    corner_index: u8,
};

pub const SubdivisionVertex = struct {
    vertex_id: SubdivisionVertexId,
    position_m: canonical.math3d.Vec3,
};

pub const SubdivisionQuad = struct {
    face_id: SubdivisionFaceId,
    vertex_ids: [4]SubdivisionVertexId,
    source_face_id: identity.FaceId,
    primary_surface_id: canonical.identity.SurfaceId,
    material_instance_id: canonical.identity.MaterialInstanceId,
    region_ids: []const canonical.identity.RegionId,
    surface_coordinates: [4]schema.SurfaceCoordinateCorner,
    texture_coordinates: [4]schema.TextureCoordinateCorner,
};

pub const SubdivisionDirectedEdge = struct {
    from_vertex_id: SubdivisionVertexId,
    to_vertex_id: SubdivisionVertexId,
};

pub const SubdividedMesh = struct {
    allocator: std.mem.Allocator,
    mesh_id: identity.MeshId,
    level: u32,
    vertices: []SubdivisionVertex,
    faces: []SubdivisionQuad,
    boundary_edges: []SubdivisionDirectedEdge,

    pub fn deinit(self: *SubdividedMesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.faces);
        self.allocator.free(self.boundary_edges);
        self.* = undefined;
    }
};

const EdgeData = struct {
    key: EdgeKey,
    face_ids: [2]identity.FaceId = undefined,
    face_count: u8 = 0,
};

const EdgeOccurrence = struct {
    key: EdgeKey,
    face_id: identity.FaceId,
};

const VertexEdgeReference = struct {
    vertex_id: identity.VertexId,
    edge_index: usize,
};

const VertexFaceReference = struct {
    vertex_id: identity.VertexId,
    face_index: usize,
};

pub fn subdivideCatmullClarkLevel1Alloc(
    allocator: std.mem.Allocator,
    mesh: *const schema.Mesh,
) !SubdividedMesh {
    if (mesh.subdivision_policy != .catmull_clark_v1) return error.SubdivisionPolicyNone;

    const sorted_vertices = try allocator.dupe(schema.Vertex, mesh.vertices);
    defer allocator.free(sorted_vertices);
    std.mem.sort(schema.Vertex, sorted_vertices, {}, lessThanVertexId);
    for (sorted_vertices[1..], sorted_vertices[0..sorted_vertices.len -| 1]) |current, previous| {
        if (current.vertex_id.eql(previous.vertex_id)) return error.DuplicateVertexId;
    }
    const sorted_faces = try allocator.dupe(schema.QuadFace, mesh.faces);
    defer allocator.free(sorted_faces);
    std.mem.sort(schema.QuadFace, sorted_faces, {}, lessThanFaceId);
    for (sorted_faces[1..], sorted_faces[0..sorted_faces.len -| 1]) |current, previous| {
        if (current.face_id.eql(previous.face_id)) return error.DuplicateFaceId;
    }

    const edge_occurrence_count = std.math.mul(usize, sorted_faces.len, 4) catch return error.TopologyTooLarge;
    const edge_occurrences = try allocator.alloc(EdgeOccurrence, edge_occurrence_count);
    defer allocator.free(edge_occurrences);
    for (sorted_faces, 0..) |face, face_index| for (0..4) |corner| {
        edge_occurrences[face_index * 4 + corner] = .{
            .key = EdgeKey.init(face.vertex_ids[corner], face.vertex_ids[(corner + 1) % 4]),
            .face_id = face.face_id,
        };
    };
    std.mem.sort(EdgeOccurrence, edge_occurrences, {}, lessThanEdgeOccurrence);

    var edges = std.ArrayList(EdgeData).empty;
    defer edges.deinit(allocator);
    var occurrence_start: usize = 0;
    while (occurrence_start < edge_occurrences.len) {
        var occurrence_end = occurrence_start + 1;
        while (occurrence_end < edge_occurrences.len and edge_occurrences[occurrence_start].key.eql(edge_occurrences[occurrence_end].key)) : (occurrence_end += 1) {}
        const face_count = occurrence_end - occurrence_start;
        if (face_count > 2) return error.NonManifoldEdge;
        var edge = EdgeData{ .key = edge_occurrences[occurrence_start].key };
        for (edge_occurrences[occurrence_start..occurrence_end], 0..) |occurrence, index| edge.face_ids[index] = occurrence.face_id;
        edge.face_count = @intCast(face_count);
        try edges.append(allocator, edge);
        occurrence_start = occurrence_end;
    }

    const edge_references = try buildVertexEdgeReferencesAlloc(allocator, edges.items);
    defer allocator.free(edge_references);
    const face_references = try buildVertexFaceReferencesAlloc(allocator, sorted_faces);
    defer allocator.free(face_references);
    const face_points = try allocator.alloc(canonical.math3d.Vec3, sorted_faces.len);
    defer allocator.free(face_points);
    for (sorted_faces, face_points) |face, *point| point.* = try facePointSorted(sorted_vertices, face);

    const total_vertices = std.math.add(usize, mesh.vertices.len, edges.items.len) catch return error.TopologyTooLarge;
    const final_vertex_count = std.math.add(usize, total_vertices, mesh.faces.len) catch return error.TopologyTooLarge;
    const vertices = try allocator.alloc(SubdivisionVertex, final_vertex_count);
    errdefer allocator.free(vertices);
    const faces = try allocator.alloc(SubdivisionQuad, std.math.mul(usize, mesh.faces.len, 4) catch return error.TopologyTooLarge);
    errdefer allocator.free(faces);

    var boundary_source_edge_count: usize = 0;
    for (edges.items) |edge| if (edge.face_count == 1) {
        boundary_source_edge_count += 1;
    };
    const boundary_edges = try allocator.alloc(
        SubdivisionDirectedEdge,
        std.math.mul(usize, boundary_source_edge_count, 2) catch return error.TopologyTooLarge,
    );
    errdefer allocator.free(boundary_edges);

    var output_index: usize = 0;
    for (sorted_vertices) |source_vertex| {
        vertices[output_index] = .{
            .vertex_id = .{ .source_vertex = source_vertex.vertex_id },
            .position_m = try catmullClarkVertexPointSorted(
                sorted_vertices,
                sorted_faces,
                face_points,
                edges.items,
                edge_references,
                face_references,
                source_vertex,
            ),
        };
        output_index += 1;
    }

    for (edges.items) |edge| {
        vertices[output_index] = .{
            .vertex_id = .{ .edge_point = edge.key },
            .position_m = try catmullClarkEdgePointSorted(sorted_vertices, sorted_faces, face_points, edge),
        };
        output_index += 1;
    }

    for (sorted_faces, face_points) |face, point| {
        vertices[output_index] = .{
            .vertex_id = .{ .face_point = face.face_id },
            .position_m = point,
        };
        output_index += 1;
    }

    for (sorted_faces, 0..) |face, face_order| {
        const surface_center = averageSurfaceCorners(face.surface_coordinates);
        const texture_center = averageTextureCorners(face.texture_coordinates);
        for (0..4) |corner| {
            const next = (corner + 1) % 4;
            const previous = (corner + 3) % 4;
            faces[face_order * 4 + corner] = .{
                .face_id = .{ .source_face_id = face.face_id, .corner_index = @intCast(corner) },
                .vertex_ids = .{
                    .{ .source_vertex = face.vertex_ids[corner] },
                    .{ .edge_point = EdgeKey.init(face.vertex_ids[corner], face.vertex_ids[next]) },
                    .{ .face_point = face.face_id },
                    .{ .edge_point = EdgeKey.init(face.vertex_ids[previous], face.vertex_ids[corner]) },
                },
                .source_face_id = face.face_id,
                .primary_surface_id = face.primary_surface_id,
                .material_instance_id = face.material_instance_id,
                .region_ids = face.region_ids,
                .surface_coordinates = .{
                    face.surface_coordinates[corner],
                    midpointSurface(face.surface_coordinates[corner], face.surface_coordinates[next]),
                    surface_center,
                    midpointSurface(face.surface_coordinates[previous], face.surface_coordinates[corner]),
                },
                .texture_coordinates = .{
                    face.texture_coordinates[corner],
                    midpointTexture(face.texture_coordinates[corner], face.texture_coordinates[next]),
                    texture_center,
                    midpointTexture(face.texture_coordinates[previous], face.texture_coordinates[corner]),
                },
            };
        }
    }

    var boundary_index: usize = 0;
    for (mesh.boundary_loops) |loop| for (loop.directed_edges) |edge| {
        const key = EdgeKey.init(edge.from_vertex_id, edge.to_vertex_id);
        boundary_edges[boundary_index] = .{
            .from_vertex_id = .{ .source_vertex = edge.from_vertex_id },
            .to_vertex_id = .{ .edge_point = key },
        };
        boundary_edges[boundary_index + 1] = .{
            .from_vertex_id = .{ .edge_point = key },
            .to_vertex_id = .{ .source_vertex = edge.to_vertex_id },
        };
        boundary_index += 2;
    };
    if (boundary_index != boundary_edges.len) return error.MalformedBoundaryInventory;

    return .{
        .allocator = allocator,
        .mesh_id = mesh.mesh_id,
        .level = 1,
        .vertices = vertices,
        .faces = faces,
        .boundary_edges = boundary_edges,
    };
}

fn catmullClarkVertexPointSorted(
    vertices: []const schema.Vertex,
    faces: []const schema.QuadFace,
    face_points: []const canonical.math3d.Vec3,
    edges: []const EdgeData,
    edge_references: []const VertexEdgeReference,
    face_references: []const VertexFaceReference,
    source_vertex: schema.Vertex,
) !canonical.math3d.Vec3 {
    const original = source_vertex.position_m;
    var boundary_neighbors: [2]canonical.math3d.Vec3 = undefined;
    var boundary_count: usize = 0;
    var incident_midpoint_sum = canonical.math3d.Vec3.zero;
    const edge_range = vertexEdgeReferenceRange(edge_references, source_vertex.vertex_id);
    for (edge_references[edge_range.start..edge_range.end]) |reference| {
        const edge = edges[reference.edge_index];
        const other_id = if (edge.key.low.value == source_vertex.vertex_id.value) edge.key.high else edge.key.low;
        const other = (findVertexSorted(vertices, other_id) orelse return error.InvalidVertexReference).position_m;
        incident_midpoint_sum = add(incident_midpoint_sum, scale(add(original, other), 0.5));
        if (edge.face_count == 1) {
            if (boundary_count == boundary_neighbors.len) return error.MalformedBoundaryVertex;
            boundary_neighbors[boundary_count] = other;
            boundary_count += 1;
        }
    }

    if (boundary_count != 0) {
        if (boundary_count != 2) return error.MalformedBoundaryVertex;
        return scale(add(add(scale(original, 6), boundary_neighbors[0]), boundary_neighbors[1]), 0.125);
    }
    const face_range = vertexFaceReferenceRange(face_references, source_vertex.vertex_id);
    if (edge_range.start == edge_range.end or face_range.start == face_range.end) return error.IsolatedVertex;

    var face_sum = canonical.math3d.Vec3.zero;
    for (face_references[face_range.start..face_range.end]) |reference| {
        if (reference.face_index >= faces.len) return error.InvalidFaceReference;
        face_sum = add(face_sum, face_points[reference.face_index]);
    }
    const incident_edge_count = edge_range.end - edge_range.start;
    const incident_face_count = face_range.end - face_range.start;
    const n: f32 = @floatFromInt(incident_face_count);
    const average_faces = scale(face_sum, 1.0 / n);
    const average_edges = scale(incident_midpoint_sum, 1.0 / @as(f32, @floatFromInt(incident_edge_count)));
    return scale(add(add(average_faces, scale(average_edges, 2)), scale(original, n - 3)), 1.0 / n);
}

fn catmullClarkEdgePointSorted(
    vertices: []const schema.Vertex,
    faces: []const schema.QuadFace,
    face_points: []const canonical.math3d.Vec3,
    edge: EdgeData,
) !canonical.math3d.Vec3 {
    const a = (findVertexSorted(vertices, edge.key.low) orelse return error.InvalidVertexReference).position_m;
    const b = (findVertexSorted(vertices, edge.key.high) orelse return error.InvalidVertexReference).position_m;
    if (edge.face_count == 1) return scale(add(a, b), 0.5);
    if (edge.face_count != 2) return error.NonManifoldEdge;
    const face_a_index = findFaceIndexSorted(faces, edge.face_ids[0]) orelse return error.InvalidFaceReference;
    const face_b_index = findFaceIndexSorted(faces, edge.face_ids[1]) orelse return error.InvalidFaceReference;
    return scale(add(add(a, b), add(face_points[face_a_index], face_points[face_b_index])), 0.25);
}

fn facePointSorted(vertices: []const schema.Vertex, face: schema.QuadFace) !canonical.math3d.Vec3 {
    var sum = canonical.math3d.Vec3.zero;
    for (face.vertex_ids) |vertex_id| {
        const vertex = findVertexSorted(vertices, vertex_id) orelse return error.InvalidVertexReference;
        sum = add(sum, vertex.position_m);
    }
    return scale(sum, 0.25);
}

fn buildVertexEdgeReferencesAlloc(allocator: std.mem.Allocator, edges: []const EdgeData) ![]VertexEdgeReference {
    const references = try allocator.alloc(VertexEdgeReference, std.math.mul(usize, edges.len, 2) catch return error.TopologyTooLarge);
    for (edges, 0..) |edge, edge_index| {
        references[edge_index * 2] = .{ .vertex_id = edge.key.low, .edge_index = edge_index };
        references[edge_index * 2 + 1] = .{ .vertex_id = edge.key.high, .edge_index = edge_index };
    }
    std.mem.sort(VertexEdgeReference, references, {}, lessThanVertexEdgeReference);
    return references;
}

fn buildVertexFaceReferencesAlloc(allocator: std.mem.Allocator, faces: []const schema.QuadFace) ![]VertexFaceReference {
    const references = try allocator.alloc(VertexFaceReference, std.math.mul(usize, faces.len, 4) catch return error.TopologyTooLarge);
    for (faces, 0..) |face, face_index| for (face.vertex_ids, 0..) |vertex_id, corner| {
        references[face_index * 4 + corner] = .{ .vertex_id = vertex_id, .face_index = face_index };
    };
    std.mem.sort(VertexFaceReference, references, {}, lessThanVertexFaceReference);
    return references;
}

const ReferenceRange = struct { start: usize, end: usize };

fn vertexEdgeReferenceRange(references: []const VertexEdgeReference, vertex_id: identity.VertexId) ReferenceRange {
    const start = lowerBoundVertexEdgeReference(references, vertex_id.value);
    var end = start;
    while (end < references.len and references[end].vertex_id.eql(vertex_id)) : (end += 1) {}
    return .{ .start = start, .end = end };
}

fn vertexFaceReferenceRange(references: []const VertexFaceReference, vertex_id: identity.VertexId) ReferenceRange {
    const start = lowerBoundVertexFaceReference(references, vertex_id.value);
    var end = start;
    while (end < references.len and references[end].vertex_id.eql(vertex_id)) : (end += 1) {}
    return .{ .start = start, .end = end };
}

fn lowerBoundVertexEdgeReference(references: []const VertexEdgeReference, vertex_id: u32) usize {
    var low: usize = 0;
    var high: usize = references.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (references[middle].vertex_id.value < vertex_id) low = middle + 1 else high = middle;
    }
    return low;
}

fn lowerBoundVertexFaceReference(references: []const VertexFaceReference, vertex_id: u32) usize {
    var low: usize = 0;
    var high: usize = references.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (references[middle].vertex_id.value < vertex_id) low = middle + 1 else high = middle;
    }
    return low;
}

fn averageSurfaceCorners(corners: [4]schema.SurfaceCoordinateCorner) schema.SurfaceCoordinateCorner {
    var coordinate = schema.Vec2{ .x = 0, .y = 0 };
    for (corners) |corner| coordinate = add2(coordinate, corner.coordinate);
    var result = corners[0];
    result.coordinate = scale2(coordinate, 0.25);
    return result;
}

fn averageTextureCorners(corners: [4]schema.TextureCoordinateCorner) schema.TextureCoordinateCorner {
    var uv = schema.Vec2{ .x = 0, .y = 0 };
    for (corners) |corner| uv = add2(uv, corner.uv);
    var result = corners[0];
    result.uv = scale2(uv, 0.25);
    return result;
}

fn midpointSurface(a: schema.SurfaceCoordinateCorner, b: schema.SurfaceCoordinateCorner) schema.SurfaceCoordinateCorner {
    var result = a;
    result.coordinate = scale2(add2(a.coordinate, b.coordinate), 0.5);
    return result;
}

fn midpointTexture(a: schema.TextureCoordinateCorner, b: schema.TextureCoordinateCorner) schema.TextureCoordinateCorner {
    var result = a;
    result.uv = scale2(add2(a.uv, b.uv), 0.5);
    return result;
}

fn lessThanVertexId(_: void, a: schema.Vertex, b: schema.Vertex) bool {
    return a.vertex_id.value < b.vertex_id.value;
}

fn lessThanFaceId(_: void, a: schema.QuadFace, b: schema.QuadFace) bool {
    return a.face_id.value < b.face_id.value;
}

fn findVertexSorted(vertices: []const schema.Vertex, vertex_id: identity.VertexId) ?schema.Vertex {
    var low: usize = 0;
    var high: usize = vertices.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const candidate = vertices[middle];
        if (candidate.vertex_id.value < vertex_id.value) {
            low = middle + 1;
        } else if (candidate.vertex_id.value > vertex_id.value) {
            high = middle;
        } else {
            return candidate;
        }
    }
    return null;
}

fn findFaceIndexSorted(faces: []const schema.QuadFace, face_id: identity.FaceId) ?usize {
    var low: usize = 0;
    var high: usize = faces.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const candidate = faces[middle].face_id.value;
        if (candidate < face_id.value) {
            low = middle + 1;
        } else if (candidate > face_id.value) {
            high = middle;
        } else {
            return middle;
        }
    }
    return null;
}

fn lessThanEdgeOccurrence(_: void, a: EdgeOccurrence, b: EdgeOccurrence) bool {
    if (a.key.low.value != b.key.low.value) return a.key.low.value < b.key.low.value;
    if (a.key.high.value != b.key.high.value) return a.key.high.value < b.key.high.value;
    return a.face_id.value < b.face_id.value;
}

fn lessThanVertexEdgeReference(_: void, a: VertexEdgeReference, b: VertexEdgeReference) bool {
    if (a.vertex_id.value != b.vertex_id.value) return a.vertex_id.value < b.vertex_id.value;
    return a.edge_index < b.edge_index;
}

fn lessThanVertexFaceReference(_: void, a: VertexFaceReference, b: VertexFaceReference) bool {
    if (a.vertex_id.value != b.vertex_id.value) return a.vertex_id.value < b.vertex_id.value;
    return a.face_index < b.face_index;
}

fn add(a: canonical.math3d.Vec3, b: canonical.math3d.Vec3) canonical.math3d.Vec3 {
    return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
}

fn scale(value: canonical.math3d.Vec3, factor: f32) canonical.math3d.Vec3 {
    return .{ .x = value.x * factor, .y = value.y * factor, .z = value.z * factor };
}

fn add2(a: schema.Vec2, b: schema.Vec2) schema.Vec2 {
    return .{ .x = a.x + b.x, .y = a.y + b.y };
}

fn scale2(value: schema.Vec2, factor: f32) schema.Vec2 {
    return .{ .x = value.x * factor, .y = value.y * factor };
}
