const std = @import("std");
const canonical = @import("canonical_model");
const geometry = @import("canonical_geometry");

pub const main_body_mesh_id = "human_base_main_body";
pub const geometry_asset_id = "human_base_geometry";
pub const topology_id = "human_base_topology";
pub const canonical_height_m: f32 = 1.8288;

/// OPEN/TUNING Prompt 2C tolerance for matching refined control-mesh locations
/// to M02 anchor-backed landmarks. The measured candidate maximum is below
/// 0.10 m; M02 anchors remain authoritative and are not moved to fit geometry.
pub const landmark_binding_tolerance_m: f64 = 0.10;
/// Numerical validation-only tolerance for exact ground and locked height.
pub const locked_extent_tolerance_m: f64 = 0.000001;
/// Numerical validation-only bilateral mirror tolerance over canonical f32.
pub const symmetry_tolerance_m: f64 = 0.000001;
/// Numerical validation-only separating-axis epsilon for offline triangles.
pub const intersection_epsilon_m: f64 = 0.000000001;

pub const required_broad_surface_ids = [_][]const u8{
    "abdomen_surface",
    "ankle_left_surface",
    "ankle_right_surface",
    "areola_left_surface",
    "areola_right_surface",
    "back_surface",
    "breast_left_surface",
    "breast_right_surface",
    "chest_surface",
    "ear_left_surface",
    "ear_right_surface",
    "elbow_left_surface",
    "elbow_right_surface",
    "face_surface",
    "forearm_left_surface",
    "forearm_right_surface",
    "forefoot_left_surface",
    "forefoot_right_surface",
    "glute_left_surface",
    "glute_right_surface",
    "hand_dorsum_left_surface",
    "hand_dorsum_right_surface",
    "head_surface",
    "heel_left_surface",
    "heel_right_surface",
    "hip_left_surface",
    "hip_right_surface",
    "index_left_surface",
    "index_right_surface",
    "knee_left_surface",
    "knee_right_surface",
    "lip_lower_surface",
    "lip_upper_surface",
    "little_left_surface",
    "little_right_surface",
    "lower_leg_left_surface",
    "lower_leg_right_surface",
    "middle_left_surface",
    "middle_right_surface",
    "midfoot_left_surface",
    "midfoot_right_surface",
    "navel_surface",
    "neck_surface",
    "nipple_left_surface",
    "nipple_right_surface",
    "palm_left_surface",
    "palm_right_surface",
    "pelvis_surface",
    "perineal_surface",
    "pubic_surface",
    "ring_left_surface",
    "ring_right_surface",
    "scalp_surface",
    "shin_left_surface",
    "shin_right_surface",
    "shoulder_left_surface",
    "shoulder_right_surface",
    "sole_left_surface",
    "sole_right_surface",
    "thigh_left_surface",
    "thigh_right_surface",
    "thumb_left_surface",
    "thumb_right_surface",
    "toe_big_left_surface",
    "toe_big_right_surface",
    "toe_index_left_surface",
    "toe_index_right_surface",
    "toe_little_left_surface",
    "toe_little_right_surface",
    "toe_middle_left_surface",
    "toe_middle_right_surface",
    "toe_ring_left_surface",
    "toe_ring_right_surface",
    "torso_surface",
    "upper_arm_left_surface",
    "upper_arm_right_surface",
    "waist_surface",
    "wrist_left_surface",
    "wrist_right_surface",
};

pub const Bounds3 = struct {
    minimum: canonical.math3d.Vec3,
    maximum: canonical.math3d.Vec3,

    pub fn width(self: Bounds3) f32 {
        return self.maximum.x - self.minimum.x;
    }

    pub fn height(self: Bounds3) f32 {
        return self.maximum.y - self.minimum.y;
    }

    pub fn depth(self: Bounds3) f32 {
        return self.maximum.z - self.minimum.z;
    }
};

pub const Measurements = struct {
    overall: Bounds3,
    chest: Bounds3,
    waist: Bounds3,
    hip_glute: Bounds3,
    head: Bounds3,
    arms: Bounds3,
    hands: Bounds3,
    legs: Bounds3,
    feet: Bounds3,
};

pub const LandmarkErrorStats = struct {
    count: usize,
    minimum_m: f64,
    median_m: f64,
    percentile_90_m: f64,
    maximum_m: f64,
    mean_m: f64,
};

pub const ScalarDistribution = struct {
    minimum: f64,
    percentile_25: f64,
    median: f64,
    percentile_75: f64,
    percentile_90: f64,
    percentile_95: f64,
    percentile_99: f64,
    maximum: f64,
    mean: f64,
};

pub const QualityMetrics = struct {
    vertex_count: usize,
    quad_count: usize,
    derived_triangle_count: usize,
    unique_edge_count: usize,
    boundary_edge_count: usize,
    non_manifold_edge_count: usize,
    degenerate_quad_count: usize,
    extraordinary_vertex_count: usize,
    valence_three_count: usize,
    valence_four_count: usize,
    valence_five_count: usize,
    other_valence_count: usize,
    quad_aspect_ratio_over_8_count: usize,
    edge_length_m: ScalarDistribution,
    quad_aspect_ratio: ScalarDistribution,
};

pub const SelfIntersectionPair = struct {
    face_a: geometry.identity.FaceId,
    face_b: geometry.identity.FaceId,
};

pub const SelfIntersectionReport = struct {
    allocator: std.mem.Allocator,
    pairs: []SelfIntersectionPair,

    pub fn deinit(self: *SelfIntersectionReport) void {
        self.allocator.free(self.pairs);
        self.* = undefined;
    }
};

pub fn findMainBody(definition: *const geometry.schema.GeometryDefinition) ?*const geometry.schema.Mesh {
    for (definition.meshes) |*mesh| if (std.mem.eql(u8, mesh.mesh_id.value.bytes, main_body_mesh_id)) return mesh;
    return null;
}

pub fn measurements(mesh: *const geometry.schema.Mesh) !Measurements {
    return .{
        .overall = try meshBounds(mesh),
        .chest = try spatialBounds(mesh, -0.31, 0.31, 1.1176, 1.4986),
        .waist = try spatialBounds(mesh, -0.25, 0.25, 1.016, 1.1176),
        .hip_glute = try spatialBounds(mesh, -0.25, 0.25, 0.8128, 1.016),
        .head = try spatialBounds(mesh, -0.18, 0.18, 1.6002, canonical_height_m),
        .arms = try semanticBounds(mesh, &.{ "upper_arm_left", "upper_arm_right", "elbow_left", "elbow_right", "forearm_left", "forearm_right", "wrist_left", "wrist_right" }),
        .hands = try semanticBounds(mesh, &.{ "palm_left", "palm_right", "hand_dorsum_left", "hand_dorsum_right", "thumb_left", "thumb_right", "index_left", "index_right", "middle_left", "middle_right", "ring_left", "ring_right", "little_left", "little_right" }),
        .legs = try semanticBounds(mesh, &.{ "thigh_left", "thigh_right", "knee_left", "knee_right", "lower_leg_left", "lower_leg_right", "shin_left", "shin_right", "calf_left", "calf_right", "ankle_left", "ankle_right" }),
        .feet = try semanticBounds(mesh, &.{ "midfoot_left", "midfoot_right", "forefoot_left", "forefoot_right", "heel_left", "heel_right", "sole_left", "sole_right", "toe_big_left", "toe_big_right", "toe_index_left", "toe_index_right", "toe_middle_left", "toe_middle_right", "toe_ring_left", "toe_ring_right", "toe_little_left", "toe_little_right" }),
    };
}

pub fn broadSurfaceCoverageValid(mesh: *const geometry.schema.Mesh) bool {
    for (required_broad_surface_ids) |required| {
        var found = false;
        for (mesh.faces) |face| if (std.mem.eql(u8, face.primary_surface_id.value.bytes, required)) {
            found = true;
            break;
        };
        if (!found) return false;
    }
    return true;
}

pub fn bilateralSymmetryValidAlloc(allocator: std.mem.Allocator, mesh: *const geometry.schema.Mesh) !bool {
    const positions = try allocator.alloc(PositionRecord, mesh.vertices.len);
    defer allocator.free(positions);
    for (mesh.vertices, positions) |vertex, *position| position.* = .{
        .x = vertex.position_m.x,
        .y = vertex.position_m.y,
        .z = vertex.position_m.z,
    };
    std.mem.sort(PositionRecord, positions, {}, lessThanPositionRecord);
    for (mesh.vertices) |vertex| {
        if (!mirroredPositionExists(positions, vertex.position_m)) return false;
    }
    return true;
}

pub fn seamSemanticsValid(definition: *const geometry.schema.GeometryDefinition, mesh: *const geometry.schema.Mesh) bool {
    if (definition.seam_bindings.len != 11) return false;
    for (definition.seam_bindings) |binding| {
        if (!binding.mesh_id.eql(mesh.mesh_id) or !binding.is_closed) return false;
        for (binding.directed_edges) |edge| {
            var side_a_count: usize = 0;
            var side_b_count: usize = 0;
            var incident_count: usize = 0;
            for (mesh.faces) |face| for (0..4) |corner| {
                const a = face.vertex_ids[corner];
                const b = face.vertex_ids[(corner + 1) % 4];
                if (!sameUndirected(a, b, edge.from_vertex_id, edge.to_vertex_id)) continue;
                incident_count += 1;
                if (face.primary_surface_id.eql(binding.side_a_surface_id)) side_a_count += 1;
                if (face.primary_surface_id.eql(binding.side_b_surface_id)) side_b_count += 1;
            };
            if (incident_count != 2 or side_a_count != 1 or side_b_count != 1) return false;
        }
    }
    return true;
}

pub fn landmarkBindingsValid(
    allocator: std.mem.Allocator,
    definition: *const geometry.schema.GeometryDefinition,
    structural: *const canonical.definition.CanonicalCreatureDefinition,
    mesh: *const geometry.schema.Mesh,
) !bool {
    const stats = try landmarkErrorStatsAlloc(allocator, definition, structural, mesh);
    return stats.count == structural.landmarks.len and stats.maximum_m <= landmark_binding_tolerance_m;
}

pub fn landmarkErrorStatsAlloc(
    allocator: std.mem.Allocator,
    definition: *const geometry.schema.GeometryDefinition,
    structural: *const canonical.definition.CanonicalCreatureDefinition,
    mesh: *const geometry.schema.Mesh,
) !LandmarkErrorStats {
    if (definition.geometry_bindings.len != structural.landmarks.len or structural.landmarks.len == 0) return error.InvalidLandmarkBindings;
    const errors = try allocator.alloc(f64, structural.landmarks.len);
    defer allocator.free(errors);
    var sum: f64 = 0;
    for (structural.landmarks, errors) |landmark, *error_m| {
        const binding = findLandmarkBinding(definition, landmark.landmark_id) orelse return error.InvalidLandmarkBindings;
        const face = findFace(mesh, binding.face_id) orelse return error.InvalidLandmarkBindings;
        const anchor_id = switch (landmark.owner) {
            .anchor => |id| id,
            else => return error.InvalidLandmarkBindings,
        };
        const anchor = try canonical.human_attachments.anchorWorldPosition(structural, anchor_id.value.bytes);
        const binding_position = try facePoint(mesh, face, binding.local_face_coordinate);
        error_m.* = distance(anchor, binding_position);
        sum += error_m.*;
    }
    std.mem.sort(f64, errors, {}, lessThanF64);
    return .{
        .count = errors.len,
        .minimum_m = errors[0],
        .median_m = percentile(errors, 0.50),
        .percentile_90_m = percentile(errors, 0.90),
        .maximum_m = errors[errors.len - 1],
        .mean_m = sum / @as(f64, @floatFromInt(errors.len)),
    };
}

pub fn qualityMetricsAlloc(allocator: std.mem.Allocator, mesh: *const geometry.schema.Mesh) !QualityMetrics {
    if (mesh.vertices.len == 0 or mesh.faces.len == 0) return error.EmptyMesh;
    const edge_records = try allocator.alloc(QualityEdgeRecord, try std.math.mul(usize, mesh.faces.len, 4));
    defer allocator.free(edge_records);
    const vertex_valence = try allocator.alloc(usize, mesh.vertices.len);
    defer allocator.free(vertex_valence);
    @memset(vertex_valence, 0);
    const edge_lengths = try allocator.alloc(f64, edge_records.len);
    defer allocator.free(edge_lengths);
    const aspect_ratios = try allocator.alloc(f64, mesh.faces.len);
    defer allocator.free(aspect_ratios);

    var degenerate_quad_count: usize = 0;
    var quad_aspect_ratio_over_8_count: usize = 0;
    for (mesh.faces, 0..) |face, face_index| {
        var face_edge_lengths: [4]f64 = undefined;
        for (0..4) |corner| {
            const from = face.vertex_ids[corner];
            const to = face.vertex_ids[(corner + 1) % 4];
            edge_records[face_index * 4 + corner] = QualityEdgeRecord.init(from, to);
            const from_position = (findVertex(mesh, from) orelse return error.InvalidVertexReference).position_m;
            const to_position = (findVertex(mesh, to) orelse return error.InvalidVertexReference).position_m;
            face_edge_lengths[corner] = distance(from_position, to_position);
        }
        var minimum_edge = face_edge_lengths[0];
        var maximum_edge = face_edge_lengths[0];
        for (face_edge_lengths[1..]) |length| {
            minimum_edge = @min(minimum_edge, length);
            maximum_edge = @max(maximum_edge, length);
        }
        aspect_ratios[face_index] = if (minimum_edge > 0) maximum_edge / minimum_edge else std.math.inf(f64);
        if (aspect_ratios[face_index] > 8.0) quad_aspect_ratio_over_8_count += 1;
        if (quadIsDegenerate(mesh, face)) degenerate_quad_count += 1;
    }

    std.mem.sort(QualityEdgeRecord, edge_records, {}, lessThanQualityEdgeRecord);
    var unique_edge_count: usize = 0;
    var boundary_edge_count: usize = 0;
    var non_manifold_edge_count: usize = 0;
    var start: usize = 0;
    while (start < edge_records.len) {
        var end = start + 1;
        while (end < edge_records.len and edge_records[start].eql(edge_records[end])) : (end += 1) {}
        const edge = edge_records[start];
        const from_index = findVertexIndex(mesh, edge.low) orelse return error.InvalidVertexReference;
        const to_index = findVertexIndex(mesh, edge.high) orelse return error.InvalidVertexReference;
        vertex_valence[from_index] += 1;
        vertex_valence[to_index] += 1;
        const from_position = mesh.vertices[from_index].position_m;
        const to_position = mesh.vertices[to_index].position_m;
        edge_lengths[unique_edge_count] = distance(from_position, to_position);
        unique_edge_count += 1;
        const incidence = end - start;
        if (incidence == 1) boundary_edge_count += 1;
        if (incidence > 2) non_manifold_edge_count += 1;
        start = end;
    }

    var valence_three_count: usize = 0;
    var valence_four_count: usize = 0;
    var valence_five_count: usize = 0;
    var other_valence_count: usize = 0;
    for (vertex_valence) |valence| switch (valence) {
        3 => valence_three_count += 1,
        4 => valence_four_count += 1,
        5 => valence_five_count += 1,
        else => other_valence_count += 1,
    };
    const extraordinary_vertex_count = mesh.vertices.len - valence_four_count;
    std.mem.sort(f64, edge_lengths[0..unique_edge_count], {}, lessThanF64);
    std.mem.sort(f64, aspect_ratios, {}, lessThanF64);
    return .{
        .vertex_count = mesh.vertices.len,
        .quad_count = mesh.faces.len,
        .derived_triangle_count = mesh.faces.len * 2,
        .unique_edge_count = unique_edge_count,
        .boundary_edge_count = boundary_edge_count,
        .non_manifold_edge_count = non_manifold_edge_count,
        .degenerate_quad_count = degenerate_quad_count,
        .extraordinary_vertex_count = extraordinary_vertex_count,
        .valence_three_count = valence_three_count,
        .valence_four_count = valence_four_count,
        .valence_five_count = valence_five_count,
        .other_valence_count = other_valence_count,
        .quad_aspect_ratio_over_8_count = quad_aspect_ratio_over_8_count,
        .edge_length_m = scalarDistribution(edge_lengths[0..unique_edge_count]),
        .quad_aspect_ratio = scalarDistribution(aspect_ratios),
    };
}

pub fn receiverInterfaceValid(definition: *const geometry.schema.GeometryDefinition) bool {
    var closure_found = false;
    for (definition.face_sets) |face_set| if (std.mem.eql(u8, face_set.face_set_id.value.bytes, "anus_receiver_closure_faces_01")) {
        closure_found = face_set.face_ids.len > 0 and std.mem.eql(u8, face_set.mesh_id.value.bytes, main_body_mesh_id);
    };
    var loop_found = false;
    for (definition.topology_loops) |loop| if (std.mem.eql(u8, loop.topology_loop_id.value.bytes, "anus_body_receiver_loop_01")) {
        loop_found = loop.directed_edges.len >= 3 and loop.becomes_boundary_when_face_set_removed != null and
            std.mem.eql(u8, loop.becomes_boundary_when_face_set_removed.?.value.bytes, "anus_receiver_closure_faces_01");
    };
    return closure_found and loop_found and definition.module_interfaces.len == 0;
}

pub fn connectedComponentCountAlloc(allocator: std.mem.Allocator, mesh: *const geometry.schema.Mesh) !usize {
    if (mesh.vertices.len == 0) return 0;
    const parents = try allocator.alloc(usize, mesh.vertices.len);
    defer allocator.free(parents);
    for (parents, 0..) |*parent, index| parent.* = index;
    for (mesh.faces) |face| {
        const first = findVertexIndex(mesh, face.vertex_ids[0]) orelse return error.InvalidVertexReference;
        for (face.vertex_ids[1..]) |vertex_id| {
            const index = findVertexIndex(mesh, vertex_id) orelse return error.InvalidVertexReference;
            unionVertexSets(parents, first, index);
        }
    }
    var component_count: usize = 0;
    for (parents, 0..) |_, index| if (vertexSetRoot(parents, index) == index) {
        component_count += 1;
    };
    return component_count;
}

pub fn selfIntersectionCountAlloc(allocator: std.mem.Allocator, mesh: *const geometry.schema.Mesh) !usize {
    var report = try selfIntersectionReportAlloc(allocator, mesh);
    defer report.deinit();
    return report.pairs.len;
}

pub fn selfIntersectionReportAlloc(allocator: std.mem.Allocator, mesh: *const geometry.schema.Mesh) !SelfIntersectionReport {
    var triangulated = try geometry.topology.triangulateAlloc(allocator, mesh);
    defer triangulated.deinit();
    const records = try allocator.alloc(TriangleRecord, triangulated.triangles.len);
    defer allocator.free(records);
    for (triangulated.triangles, 0..) |triangle, index| {
        const points = [3]Vec3d{
            toVec3d((findVertex(mesh, triangle.vertex_ids[0]) orelse return error.InvalidVertexReference).position_m),
            toVec3d((findVertex(mesh, triangle.vertex_ids[1]) orelse return error.InvalidVertexReference).position_m),
            toVec3d((findVertex(mesh, triangle.vertex_ids[2]) orelse return error.InvalidVertexReference).position_m),
        };
        records[index] = .{
            .source_face_id = triangle.triangle_id.source_face_id,
            .vertex_ids = triangle.vertex_ids,
            .points = points,
            .bounds = triangleBounds(points),
        };
    }
    std.mem.sort(TriangleRecord, records, {}, lessThanTriangleRecord);

    var bvh_nodes = std.ArrayList(BvhNode).empty;
    defer bvh_nodes.deinit(allocator);
    const root_node = try buildBvhAlloc(allocator, &bvh_nodes, records, 0, records.len);
    var pairs = std.ArrayList(SelfIntersectionPair).empty;
    defer pairs.deinit(allocator);
    for (records, 0..) |_, triangle_index| try queryTriangleAgainstBvh(
        allocator,
        &pairs,
        records,
        bvh_nodes.items,
        root_node,
        triangle_index,
    );
    return .{ .allocator = allocator, .pairs = try pairs.toOwnedSlice(allocator) };
}

fn meshBounds(mesh: *const geometry.schema.Mesh) !Bounds3 {
    if (mesh.vertices.len == 0) return error.EmptyMesh;
    var result = Bounds3{ .minimum = mesh.vertices[0].position_m, .maximum = mesh.vertices[0].position_m };
    for (mesh.vertices[1..]) |vertex| include(&result, vertex.position_m);
    return result;
}

fn semanticBounds(mesh: *const geometry.schema.Mesh, region_ids: []const []const u8) !Bounds3 {
    var result: ?Bounds3 = null;
    for (mesh.faces) |face| {
        var matches = false;
        for (face.region_ids) |region_id| for (region_ids) |expected| if (std.mem.eql(u8, region_id.value.bytes, expected)) {
            matches = true;
        };
        if (!matches) continue;
        for (face.vertex_ids) |vertex_id| {
            const position = (findVertex(mesh, vertex_id) orelse return error.InvalidVertexReference).position_m;
            if (result) |*bounds| include(bounds, position) else result = .{ .minimum = position, .maximum = position };
        }
    }
    return result orelse error.MissingSemanticBounds;
}

fn spatialBounds(mesh: *const geometry.schema.Mesh, minimum_x: f32, maximum_x: f32, minimum_y: f32, maximum_y: f32) !Bounds3 {
    var result: ?Bounds3 = null;
    for (mesh.vertices) |vertex| {
        const position = vertex.position_m;
        if (position.x < minimum_x or position.x > maximum_x or position.y < minimum_y or position.y > maximum_y) continue;
        if (result) |*bounds| include(bounds, position) else result = .{ .minimum = position, .maximum = position };
    }
    return result orelse error.MissingSpatialBounds;
}

fn include(bounds: *Bounds3, point: canonical.math3d.Vec3) void {
    bounds.minimum.x = @min(bounds.minimum.x, point.x);
    bounds.minimum.y = @min(bounds.minimum.y, point.y);
    bounds.minimum.z = @min(bounds.minimum.z, point.z);
    bounds.maximum.x = @max(bounds.maximum.x, point.x);
    bounds.maximum.y = @max(bounds.maximum.y, point.y);
    bounds.maximum.z = @max(bounds.maximum.z, point.z);
}

fn findLandmarkBinding(definition: *const geometry.schema.GeometryDefinition, id: canonical.identity.LandmarkId) ?geometry.schema.GeometryBinding {
    for (definition.geometry_bindings) |binding| if (binding.landmark_id) |candidate| if (candidate.eql(id)) return binding;
    return null;
}

fn findFace(mesh: *const geometry.schema.Mesh, id: geometry.identity.FaceId) ?geometry.schema.QuadFace {
    for (mesh.faces) |face| if (face.face_id.eql(id)) return face;
    return null;
}

fn findVertex(mesh: *const geometry.schema.Mesh, id: geometry.identity.VertexId) ?geometry.schema.Vertex {
    var low: usize = 0;
    var high: usize = mesh.vertices.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const candidate = mesh.vertices[middle];
        if (candidate.vertex_id.value < id.value) {
            low = middle + 1;
        } else if (candidate.vertex_id.value > id.value) {
            high = middle;
        } else {
            return candidate;
        }
    }
    return null;
}

fn findVertexIndex(mesh: *const geometry.schema.Mesh, id: geometry.identity.VertexId) ?usize {
    var low: usize = 0;
    var high: usize = mesh.vertices.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const candidate = mesh.vertices[middle].vertex_id.value;
        if (candidate < id.value) {
            low = middle + 1;
        } else if (candidate > id.value) {
            high = middle;
        } else {
            return middle;
        }
    }
    return null;
}

fn facePoint(mesh: *const geometry.schema.Mesh, face: geometry.schema.QuadFace, coordinate: geometry.schema.Vec2) !canonical.math3d.Vec3 {
    const p0 = (findVertex(mesh, face.vertex_ids[0]) orelse return error.InvalidVertexReference).position_m;
    const p1 = (findVertex(mesh, face.vertex_ids[1]) orelse return error.InvalidVertexReference).position_m;
    const p2 = (findVertex(mesh, face.vertex_ids[2]) orelse return error.InvalidVertexReference).position_m;
    const p3 = (findVertex(mesh, face.vertex_ids[3]) orelse return error.InvalidVertexReference).position_m;
    const u = coordinate.x;
    const v = coordinate.y;
    const w0 = (1 - u) * (1 - v);
    const w1 = u * (1 - v);
    const w2 = u * v;
    const w3 = (1 - u) * v;
    return .{
        .x = p0.x * w0 + p1.x * w1 + p2.x * w2 + p3.x * w3,
        .y = p0.y * w0 + p1.y * w1 + p2.y * w2 + p3.y * w3,
        .z = p0.z * w0 + p1.z * w1 + p2.z * w2 + p3.z * w3,
    };
}

fn distance(a: canonical.math3d.Vec3, b: canonical.math3d.Vec3) f64 {
    const x = @as(f64, a.x) - @as(f64, b.x);
    const y = @as(f64, a.y) - @as(f64, b.y);
    const z = @as(f64, a.z) - @as(f64, b.z);
    return @sqrt(x * x + y * y + z * z);
}

fn lessThanF64(_: void, a: f64, b: f64) bool {
    return a < b;
}

fn percentile(sorted: []const f64, fraction: f64) f64 {
    const scaled = fraction * @as(f64, @floatFromInt(sorted.len - 1));
    const lower: usize = @intFromFloat(@floor(scaled));
    const upper: usize = @min(lower + 1, sorted.len - 1);
    const blend = scaled - @as(f64, @floatFromInt(lower));
    return sorted[lower] * (1 - blend) + sorted[upper] * blend;
}

fn scalarDistribution(sorted: []const f64) ScalarDistribution {
    var sum: f64 = 0;
    for (sorted) |value| sum += value;
    return .{
        .minimum = sorted[0],
        .percentile_25 = percentile(sorted, 0.25),
        .median = percentile(sorted, 0.50),
        .percentile_75 = percentile(sorted, 0.75),
        .percentile_90 = percentile(sorted, 0.90),
        .percentile_95 = percentile(sorted, 0.95),
        .percentile_99 = percentile(sorted, 0.99),
        .maximum = sorted[sorted.len - 1],
        .mean = sum / @as(f64, @floatFromInt(sorted.len)),
    };
}

const PositionRecord = struct {
    x: f32,
    y: f32,
    z: f32,
};

fn lessThanPositionRecord(_: void, a: PositionRecord, b: PositionRecord) bool {
    if (a.x != b.x) return a.x < b.x;
    if (a.y != b.y) return a.y < b.y;
    return a.z < b.z;
}

fn mirroredPositionExists(positions: []const PositionRecord, source: canonical.math3d.Vec3) bool {
    const target_x = -source.x;
    var low: usize = 0;
    var high: usize = positions.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (@as(f64, positions[middle].x) < @as(f64, target_x) - symmetry_tolerance_m) {
            low = middle + 1;
        } else {
            high = middle;
        }
    }
    var index = low;
    while (index < positions.len and @as(f64, positions[index].x) <= @as(f64, target_x) + symmetry_tolerance_m) : (index += 1) {
        if (approx(positions[index].y, source.y, symmetry_tolerance_m) and
            approx(positions[index].z, source.z, symmetry_tolerance_m)) return true;
    }
    return false;
}

const QualityEdgeRecord = struct {
    low: geometry.identity.VertexId,
    high: geometry.identity.VertexId,

    fn init(a: geometry.identity.VertexId, b: geometry.identity.VertexId) QualityEdgeRecord {
        return if (a.value <= b.value) .{ .low = a, .high = b } else .{ .low = b, .high = a };
    }

    fn eql(a: QualityEdgeRecord, b: QualityEdgeRecord) bool {
        return a.low.eql(b.low) and a.high.eql(b.high);
    }
};

fn lessThanQualityEdgeRecord(_: void, a: QualityEdgeRecord, b: QualityEdgeRecord) bool {
    if (a.low.value != b.low.value) return a.low.value < b.low.value;
    return a.high.value < b.high.value;
}

fn quadIsDegenerate(mesh: *const geometry.schema.Mesh, face: geometry.schema.QuadFace) bool {
    const a = (findVertex(mesh, face.vertex_ids[0]) orelse return true).position_m;
    const b = (findVertex(mesh, face.vertex_ids[1]) orelse return true).position_m;
    const c = (findVertex(mesh, face.vertex_ids[2]) orelse return true).position_m;
    const d = (findVertex(mesh, face.vertex_ids[3]) orelse return true).position_m;
    return switch (face.diagonal) {
        .v0_v2 => triangleAreaSquared(a, b, c) == 0 or triangleAreaSquared(a, c, d) == 0,
        .v1_v3 => triangleAreaSquared(a, b, d) == 0 or triangleAreaSquared(b, c, d) == 0,
    };
}

fn triangleAreaSquared(a: canonical.math3d.Vec3, b: canonical.math3d.Vec3, c: canonical.math3d.Vec3) f64 {
    const ab = Vec3d{ .x = b.x - a.x, .y = b.y - a.y, .z = b.z - a.z };
    const ac = Vec3d{ .x = c.x - a.x, .y = c.y - a.y, .z = c.z - a.z };
    const area = cross(ab, ac);
    return dot(area, area);
}

fn vertexSetRoot(parents: []const usize, start: usize) usize {
    var current = start;
    while (parents[current] != current) current = parents[current];
    return current;
}

fn unionVertexSets(parents: []usize, a: usize, b: usize) void {
    const root_a = vertexSetRoot(parents, a);
    const root_b = vertexSetRoot(parents, b);
    if (root_a == root_b) return;
    if (root_a < root_b) {
        parents[root_b] = root_a;
    } else {
        parents[root_a] = root_b;
    }
}

fn approx(a: f32, b: f32, tolerance: f64) bool {
    return @abs(@as(f64, a) - @as(f64, b)) <= tolerance;
}

fn sameUndirected(a: geometry.identity.VertexId, b: geometry.identity.VertexId, c: geometry.identity.VertexId, d: geometry.identity.VertexId) bool {
    return (a.eql(c) and b.eql(d)) or (a.eql(d) and b.eql(c));
}

const Vec3d = struct { x: f64, y: f64, z: f64 };
const Bounds3d = struct { minimum: Vec3d, maximum: Vec3d };
const TriangleRecord = struct {
    source_face_id: geometry.identity.FaceId,
    vertex_ids: [3]geometry.identity.VertexId,
    points: [3]Vec3d,
    bounds: Bounds3d,
};

const BvhNode = struct {
    bounds: Bounds3d,
    start: usize,
    end: usize,
    left: ?usize = null,
    right: ?usize = null,
};

fn buildBvhAlloc(
    allocator: std.mem.Allocator,
    nodes: *std.ArrayList(BvhNode),
    records: []const TriangleRecord,
    start: usize,
    end: usize,
) !usize {
    if (start >= end) return error.EmptyBvhRange;
    var bounds = records[start].bounds;
    for (records[start + 1 .. end]) |record| bounds = unionBounds(bounds, record.bounds);
    const node_index = nodes.items.len;
    try nodes.append(allocator, .{ .bounds = bounds, .start = start, .end = end });
    if (end - start <= 8) return node_index;
    const middle = start + (end - start) / 2;
    const left = try buildBvhAlloc(allocator, nodes, records, start, middle);
    const right = try buildBvhAlloc(allocator, nodes, records, middle, end);
    nodes.items[node_index].left = left;
    nodes.items[node_index].right = right;
    return node_index;
}

fn queryTriangleAgainstBvh(
    allocator: std.mem.Allocator,
    pairs: *std.ArrayList(SelfIntersectionPair),
    records: []const TriangleRecord,
    nodes: []const BvhNode,
    node_index: usize,
    triangle_index: usize,
) !void {
    const triangle = records[triangle_index];
    const node = nodes[node_index];
    if (!boundsOverlap(triangle.bounds, node.bounds)) return;
    if (node.left == null and node.right == null) {
        for (node.start..node.end) |candidate_index| {
            if (candidate_index <= triangle_index) continue;
            const candidate = records[candidate_index];
            if (triangle.source_face_id.eql(candidate.source_face_id) or sharesVertex(triangle.vertex_ids, candidate.vertex_ids)) continue;
            if (!boundsOverlap(triangle.bounds, candidate.bounds)) continue;
            if (trianglesIntersect(triangle.points, candidate.points)) try pairs.append(allocator, .{
                .face_a = triangle.source_face_id,
                .face_b = candidate.source_face_id,
            });
        }
        return;
    }
    if (node.left) |left| try queryTriangleAgainstBvh(allocator, pairs, records, nodes, left, triangle_index);
    if (node.right) |right| try queryTriangleAgainstBvh(allocator, pairs, records, nodes, right, triangle_index);
}

fn lessThanTriangleRecord(_: void, a: TriangleRecord, b: TriangleRecord) bool {
    if (a.bounds.minimum.x != b.bounds.minimum.x) return a.bounds.minimum.x < b.bounds.minimum.x;
    if (a.bounds.maximum.x != b.bounds.maximum.x) return a.bounds.maximum.x < b.bounds.maximum.x;
    if (a.source_face_id.value != b.source_face_id.value) return a.source_face_id.value < b.source_face_id.value;
    for (a.vertex_ids, b.vertex_ids) |a_id, b_id| if (a_id.value != b_id.value) return a_id.value < b_id.value;
    return false;
}

fn toVec3d(value: canonical.math3d.Vec3) Vec3d {
    return .{ .x = value.x, .y = value.y, .z = value.z };
}

fn triangleBounds(points: [3]Vec3d) Bounds3d {
    var result = Bounds3d{ .minimum = points[0], .maximum = points[0] };
    for (points[1..]) |point| {
        result.minimum.x = @min(result.minimum.x, point.x);
        result.minimum.y = @min(result.minimum.y, point.y);
        result.minimum.z = @min(result.minimum.z, point.z);
        result.maximum.x = @max(result.maximum.x, point.x);
        result.maximum.y = @max(result.maximum.y, point.y);
        result.maximum.z = @max(result.maximum.z, point.z);
    }
    return result;
}

fn unionBounds(a: Bounds3d, b: Bounds3d) Bounds3d {
    return .{
        .minimum = .{
            .x = @min(a.minimum.x, b.minimum.x),
            .y = @min(a.minimum.y, b.minimum.y),
            .z = @min(a.minimum.z, b.minimum.z),
        },
        .maximum = .{
            .x = @max(a.maximum.x, b.maximum.x),
            .y = @max(a.maximum.y, b.maximum.y),
            .z = @max(a.maximum.z, b.maximum.z),
        },
    };
}

fn boundsOverlap(a: Bounds3d, b: Bounds3d) bool {
    return a.maximum.x + intersection_epsilon_m >= b.minimum.x and b.maximum.x + intersection_epsilon_m >= a.minimum.x and
        a.maximum.y + intersection_epsilon_m >= b.minimum.y and b.maximum.y + intersection_epsilon_m >= a.minimum.y and
        a.maximum.z + intersection_epsilon_m >= b.minimum.z and b.maximum.z + intersection_epsilon_m >= a.minimum.z;
}

fn sharesVertex(a: [3]geometry.identity.VertexId, b: [3]geometry.identity.VertexId) bool {
    for (a) |left| for (b) |right| if (left.eql(right)) return true;
    return false;
}

fn trianglesIntersect(a: [3]Vec3d, b: [3]Vec3d) bool {
    const edges_a = [3]Vec3d{ subtract(a[1], a[0]), subtract(a[2], a[1]), subtract(a[0], a[2]) };
    const edges_b = [3]Vec3d{ subtract(b[1], b[0]), subtract(b[2], b[1]), subtract(b[0], b[2]) };
    const normal_a = cross(edges_a[0], subtract(a[2], a[0]));
    const normal_b = cross(edges_b[0], subtract(b[2], b[0]));
    if (separatedOnAxis(a, b, normal_a) or separatedOnAxis(a, b, normal_b)) return false;
    for (edges_a) |edge_a| {
        if (separatedOnAxis(a, b, cross(normal_a, edge_a))) return false;
        for (edges_b) |edge_b| if (separatedOnAxis(a, b, cross(edge_a, edge_b))) return false;
    }
    for (edges_b) |edge_b| if (separatedOnAxis(a, b, cross(normal_b, edge_b))) return false;
    return true;
}

fn separatedOnAxis(a: [3]Vec3d, b: [3]Vec3d, axis: Vec3d) bool {
    const length_squared = dot(axis, axis);
    if (length_squared <= intersection_epsilon_m * intersection_epsilon_m) return false;
    var minimum_a = dot(a[0], axis);
    var maximum_a = minimum_a;
    var minimum_b = dot(b[0], axis);
    var maximum_b = minimum_b;
    for (a[1..]) |point| {
        const projection = dot(point, axis);
        minimum_a = @min(minimum_a, projection);
        maximum_a = @max(maximum_a, projection);
    }
    for (b[1..]) |point| {
        const projection = dot(point, axis);
        minimum_b = @min(minimum_b, projection);
        maximum_b = @max(maximum_b, projection);
    }
    const scaled_epsilon = intersection_epsilon_m * @sqrt(length_squared);
    return maximum_a < minimum_b - scaled_epsilon or maximum_b < minimum_a - scaled_epsilon;
}

fn subtract(a: Vec3d, b: Vec3d) Vec3d {
    return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
}

fn cross(a: Vec3d, b: Vec3d) Vec3d {
    return .{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}

fn dot(a: Vec3d, b: Vec3d) f64 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}
