const std = @import("std");
const canonical = @import("canonical_model");
const diagnostics = @import("diagnostics.zig");
const identity = @import("identity.zig");
const schema = @import("schema.zig");
const topology = @import("topology.zig");

pub const StructuralContext = struct {
    definition: *const canonical.definition.CanonicalCreatureDefinition,
    normalized_coordinate_contract: canonical.coordinate.CoordinateContract,
    normalized_source_sha256: identity.Sha256Digest,
};

pub fn validateAlloc(
    allocator: std.mem.Allocator,
    geometry: *const schema.GeometryDefinition,
    structural: StructuralContext,
) !diagnostics.OwnedReport {
    var collector = diagnostics.Collector.init(allocator);
    defer collector.deinit();

    try validateIdentities(&collector, geometry);
    try validateStructuralCompatibility(&collector, geometry, structural);
    try validateTopLevelUniqueness(&collector, geometry);
    for (geometry.meshes) |*mesh| try validateMesh(allocator, &collector, structural, mesh);
    try validateCoordinateMapOverlaps(allocator, &collector, geometry);
    const mesh_edge_indexes = try buildMeshEdgeIndexesAlloc(allocator, geometry.meshes);
    defer deinitMeshEdgeIndexes(allocator, mesh_edge_indexes);
    for (geometry.face_sets) |face_set| try validateFaceSet(&collector, geometry, face_set);
    for (geometry.topology_loops) |loop| try validateTopologyLoop(&collector, geometry, mesh_edge_indexes, loop);
    for (geometry.seam_bindings) |binding| try validateSeamBinding(&collector, geometry, mesh_edge_indexes, structural, binding);
    for (geometry.geometry_bindings) |binding| try validateGeometryBinding(&collector, geometry, structural, binding);
    for (geometry.module_interfaces) |interface| try validateModuleInterface(&collector, geometry, interface);
    for (geometry.collision_proxies) |proxy| try validateCollisionProxy(&collector, geometry, structural, proxy);

    return collector.finish();
}

fn validateIdentities(collector: *diagnostics.Collector, geometry: *const schema.GeometryDefinition) !void {
    if (!std.mem.eql(u8, geometry.schema_identity.geometry_schema_id.value.bytes, schema.schema_id) or
        !geometry.schema_identity.version.eql(schema.schema_version) or
        !std.mem.eql(u8, geometry.compiler_identity.geometry_compiler_id.value.bytes, schema.compiler_id) or
        !geometry.compiler_identity.version.eql(schema.compiler_version))
    {
        try add(collector, .schema_identity_mismatch, "geometry_definition", geometry.asset_identity.geometry_asset_id.value.bytes, "schema_identity", null, null, "geometry schema/compiler identity must match canonical_geometry_schema 1.0.0");
    }
}

fn validateStructuralCompatibility(
    collector: *diagnostics.Collector,
    geometry: *const schema.GeometryDefinition,
    context: StructuralContext,
) !void {
    const compatibility = geometry.structural_compatibility;
    const definition = context.definition;
    if (!compatibility.structural_asset_id.eql(definition.asset_identity.asset_id) or
        !assetVersionEql(compatibility.structural_asset_version, definition.asset_identity.version) or
        !compatibility.structural_schema_id.eql(definition.schema_identity.schema_id) or
        !schemaVersionEql(compatibility.structural_schema_version, definition.schema_identity.version) or
        !compatibility.normalized_source_sha256.eql(context.normalized_source_sha256) or
        !std.meta.eql(compatibility.coordinate_contract, context.normalized_coordinate_contract))
    {
        try add(collector, .structural_compatibility_mismatch, "geometry_definition", geometry.asset_identity.geometry_asset_id.value.bytes, "structural_compatibility", "structural_asset", definition.asset_identity.asset_id.value.bytes, "geometry structural compatibility does not match the supplied normalized structural definition");
    }

    for (compatibility.required_component_ids) |id| if (findComponent(definition, id) == null) try missing(collector, "required_component_id", id.value.bytes, "component");
    for (compatibility.required_bone_ids) |id| if (findBone(definition, id) == null) try missing(collector, "required_bone_id", id.value.bytes, "bone");
    for (compatibility.required_anchor_ids) |id| if (findAnchor(definition, id) == null) try missing(collector, "required_anchor_id", id.value.bytes, "anchor");
    for (compatibility.required_surface_ids) |id| if (findSurface(definition, id) == null) try missing(collector, "required_surface_id", id.value.bytes, "surface");
    for (compatibility.required_region_ids) |id| if (findRegion(definition, id) == null) try missing(collector, "required_region_id", id.value.bytes, "region");
    for (compatibility.required_material_instance_ids) |id| if (findMaterial(definition, id) == null) try missing(collector, "required_material_instance_id", id.value.bytes, "material_instance");
    for (compatibility.required_seam_ids) |id| if (findSeam(definition, id) == null) try missing(collector, "required_seam_id", id.value.bytes, "seam");
    for (compatibility.required_landmark_ids) |id| if (findLandmark(definition, id) == null) try missing(collector, "required_landmark_id", id.value.bytes, "landmark");
    for (compatibility.required_interaction_site_ids) |id| if (findSite(definition, id) == null) try missing(collector, "required_interaction_site_id", id.value.bytes, "interaction_site");
}

fn validateTopLevelUniqueness(collector: *diagnostics.Collector, geometry: *const schema.GeometryDefinition) !void {
    for (geometry.meshes, 0..) |mesh, index| for (geometry.meshes[index + 1 ..]) |other| if (mesh.mesh_id.eql(other.mesh_id)) {
        try add(collector, .duplicate_mesh_id, "mesh", mesh.mesh_id.value.bytes, "mesh_id", null, null, "mesh IDs must be unique");
    };
    try validateUniqueStringRecordIds(collector, schema.FaceSet, geometry.face_sets, "face_set_id", "face_set");
    try validateUniqueStringRecordIds(collector, schema.TopologyLoop, geometry.topology_loops, "topology_loop_id", "topology_loop");
    try validateUniqueStringRecordIds(collector, schema.GeometrySeamBinding, geometry.seam_bindings, "geometry_seam_binding_id", "seam_binding");
    try validateUniqueStringRecordIds(collector, schema.GeometryBinding, geometry.geometry_bindings, "geometry_binding_id", "geometry_binding");
    try validateUniqueStringRecordIds(collector, schema.ModuleInterface, geometry.module_interfaces, "module_interface_id", "module_interface");
    try validateUniqueStringRecordIds(collector, schema.CollisionProxy, geometry.collision_proxies, "collision_proxy_id", "collision_proxy");
}

fn validateMesh(
    allocator: std.mem.Allocator,
    collector: *diagnostics.Collector,
    context: StructuralContext,
    mesh: *const schema.Mesh,
) !void {
    for (mesh.owner_component_ids, 0..) |owner_id, index| {
        if (findComponent(context.definition, owner_id) == null) try missingFor(collector, "mesh", mesh.mesh_id.value.bytes, "owner_component_ids", "component", owner_id.value.bytes);
        for (mesh.owner_component_ids[index + 1 ..]) |other| if (owner_id.eql(other)) try add(collector, .missing_structural_reference, "mesh", mesh.mesh_id.value.bytes, "owner_component_ids", "component", owner_id.value.bytes, "mesh owner component IDs must be unique");
    }

    var max_vertex_id: u32 = 0;
    var has_vertex = false;
    const vertex_ids_are_strictly_increasing = vertexIdsStrictlyIncrease(mesh.vertices);
    const vertex_ids_are_nondecreasing = vertexIdsNondecreasing(mesh.vertices);
    for (mesh.vertices, 0..) |vertex, index| {
        if (!has_vertex or vertex.vertex_id.value > max_vertex_id) max_vertex_id = vertex.vertex_id.value;
        has_vertex = true;
        if (!finite3(vertex.position_m)) try add(collector, .non_finite_position, "mesh", mesh.mesh_id.value.bytes, "vertices.position_m", "vertex", null, "vertex positions must be finite f32 values");
        if (!vertex_ids_are_strictly_increasing) for (mesh.vertices[index + 1 ..]) |other| if (vertex.vertex_id.eql(other.vertex_id)) try add(collector, .duplicate_vertex_id, "mesh", mesh.mesh_id.value.bytes, "vertices.vertex_id", "vertex", null, "vertex IDs must be unique within a mesh");
    }
    if (has_vertex and mesh.next_vertex_id <= max_vertex_id) try add(collector, .invalid_allocation_cursor, "mesh", mesh.mesh_id.value.bytes, "next_vertex_id", null, null, "next_vertex_id must remain greater than every allocated vertex ID");

    var max_face_id: u32 = 0;
    var has_face = false;
    var edge_occurrences = std.ArrayList(EdgeOccurrence).empty;
    defer edge_occurrences.deinit(allocator);
    const face_ids_are_strictly_increasing = faceIdsStrictlyIncrease(mesh.faces);
    for (mesh.faces, 0..) |face, index| {
        if (!has_face or face.face_id.value > max_face_id) max_face_id = face.face_id.value;
        has_face = true;
        if (!face_ids_are_strictly_increasing) for (mesh.faces[index + 1 ..]) |other| if (face.face_id.eql(other.face_id)) try add(collector, .duplicate_face_id, "mesh", mesh.mesh_id.value.bytes, "faces.face_id", "face", null, "face IDs must be unique within a mesh");

        var valid_refs = true;
        for (face.vertex_ids, 0..) |vertex_id, corner| {
            if (findMeshVertexWithOrder(mesh, vertex_id, vertex_ids_are_nondecreasing) == null) {
                valid_refs = false;
                try add(collector, .invalid_vertex_reference, "mesh", mesh.mesh_id.value.bytes, "faces.vertex_ids", "vertex", null, "face references an unknown vertex ID");
            }
            for (face.vertex_ids[corner + 1 ..]) |other| if (vertex_id.eql(other)) try add(collector, .duplicate_face_vertex, "mesh", mesh.mesh_id.value.bytes, "faces.vertex_ids", "vertex", null, "a quad must reference four distinct vertex IDs");
            const next = face.vertex_ids[(corner + 1) % 4];
            try edge_occurrences.append(allocator, .{
                .key = topology.EdgeKey.init(vertex_id, next),
                .from = vertex_id,
                .to = next,
                .face_id = face.face_id,
            });
        }
        if (valid_refs and quadDegenerate(mesh, face, vertex_ids_are_nondecreasing)) try add(collector, .degenerate_quad, "mesh", mesh.mesh_id.value.bytes, "faces.vertex_ids", "face", null, "quad triangulation contains a zero-area triangle");
        try validateFaceSemantics(collector, mesh, context.definition, face);
    }
    try validateDuplicateFaceConnectivityAlloc(allocator, collector, mesh);
    if (has_face and mesh.next_face_id <= max_face_id) try add(collector, .invalid_allocation_cursor, "mesh", mesh.mesh_id.value.bytes, "next_face_id", null, null, "next_face_id must remain greater than every allocated face ID");

    try validateBoundaryLoops(collector, mesh, edge_occurrences.items);
    try validateEdgeIncidence(allocator, collector, mesh, edge_occurrences.items);
    try validateConnectedAlloc(allocator, collector, mesh, vertex_ids_are_nondecreasing);
}

fn validateFaceSemantics(
    collector: *diagnostics.Collector,
    mesh: *const schema.Mesh,
    definition: *const canonical.definition.CanonicalCreatureDefinition,
    face: schema.QuadFace,
) !void {
    const surface = findSurface(definition, face.primary_surface_id);
    if (surface == null) try add(collector, .missing_surface, "mesh", mesh.mesh_id.value.bytes, "faces.primary_surface_id", "surface", face.primary_surface_id.value.bytes, "face primary surface must exist structurally");
    if (findMaterial(definition, face.material_instance_id) == null) try add(collector, .unknown_material, "mesh", mesh.mesh_id.value.bytes, "faces.material_instance_id", "material_instance", face.material_instance_id.value.bytes, "face material instance must exist structurally");
    for (face.region_ids, 0..) |region_id, index| {
        if (findRegion(definition, region_id) == null) try add(collector, .missing_region, "mesh", mesh.mesh_id.value.bytes, "faces.region_ids", "region", region_id.value.bytes, "face region membership must exist structurally");
        for (face.region_ids[index + 1 ..]) |other| if (region_id.eql(other)) try add(collector, .missing_region, "mesh", mesh.mesh_id.value.bytes, "faces.region_ids", "region", region_id.value.bytes, "face region memberships must be unique");
    }
    if (surface) |resolved_surface| {
        if (!containsTyped(canonical.identity.RegionId, face.region_ids, resolved_surface.region_id)) try add(collector, .missing_owning_region, "mesh", mesh.mesh_id.value.bytes, "faces.region_ids", "region", resolved_surface.region_id.value.bytes, "face must include its primary surface owning region");
        if (!containsTyped(canonical.identity.ComponentId, mesh.owner_component_ids, resolved_surface.owner_component_id)) try add(collector, .missing_structural_reference, "mesh", mesh.mesh_id.value.bytes, "owner_component_ids", "component", resolved_surface.owner_component_id.value.bytes, "mesh ownership must cover the primary surface owner component");
    }

    const first_chart = face.surface_coordinates[0].chart_id;
    const first_island = face.texture_coordinates[0].uv_island_id;
    const first_texture_space = face.texture_coordinates[0].texture_space_id;
    const first_overlap = face.texture_coordinates[0].overlap_group_id;
    for (face.surface_coordinates) |corner| {
        if (!corner.surface_id.eql(face.primary_surface_id) or !corner.chart_id.eql(first_chart) or !finiteUnit2(corner.coordinate)) try add(collector, .invalid_surface_coordinate, "mesh", mesh.mesh_id.value.bytes, "faces.surface_coordinates", "surface", face.primary_surface_id.value.bytes, "surface-coordinate corners must use the primary surface, one chart per face, and the [0,1] domain");
    }
    for (face.texture_coordinates) |corner| {
        if (!corner.uv_island_id.eql(first_island) or !corner.texture_space_id.eql(first_texture_space) or !optionalIdEql(identity.OverlapGroupId, corner.overlap_group_id, first_overlap) or !finiteUnit2(corner.uv)) try add(collector, .invalid_texture_uv, "mesh", mesh.mesh_id.value.bytes, "faces.texture_coordinates", "uv_island", first_island.value.bytes, "texture corners must use one island/space/overlap group per face and the [0,1] domain");
    }
    const surface_points = surfacePoints(face);
    if (quadMapDegenerate(surface_points, face.diagonal) or quadSelfCrossing(surface_points)) {
        try add(collector, .invalid_surface_coordinate, "mesh", mesh.mesh_id.value.bytes, "faces.surface_coordinates", "surface", face.primary_surface_id.value.bytes, "a canonical surface-coordinate quad must have nonzero derived triangles and may not cross itself");
    }
    const texture_points = texturePoints(face);
    if (quadMapDegenerate(texture_points, face.diagonal) or quadSelfCrossing(texture_points)) {
        try add(collector, .invalid_texture_uv, "mesh", mesh.mesh_id.value.bytes, "faces.texture_coordinates", "uv_island", first_island.value.bytes, "a texture-UV quad must have nonzero derived triangles and may not cross itself");
    }
}

fn validateCoordinateMapOverlaps(
    allocator: std.mem.Allocator,
    collector: *diagnostics.Collector,
    geometry: *const schema.GeometryDefinition,
) !void {
    var face_count: usize = 0;
    for (geometry.meshes) |mesh| face_count = std.math.add(usize, face_count, mesh.faces.len) catch
        return error.GeometryTooLarge;
    const entries = try allocator.alloc(CoordinateMapEntry, face_count);
    defer allocator.free(entries);

    var cursor: usize = 0;
    for (geometry.meshes) |*mesh| for (mesh.faces) |*face| {
        entries[cursor] = .{ .mesh = mesh, .face = face };
        cursor += 1;
    };

    std.mem.sort(CoordinateMapEntry, entries, {}, lessThanSurfaceMapEntry);
    var run_start: usize = 0;
    while (run_start < entries.len) {
        var run_end = run_start + 1;
        while (run_end < entries.len and sameSurfaceMap(entries[run_start], entries[run_end])) : (run_end += 1) {}
        for (entries[run_start..run_end], 0..) |entry_a, index| for (entries[run_start + index + 1 .. run_end]) |entry_b| {
            if (quadsInteriorOverlap(
                surfacePoints(entry_a.face.*),
                entry_a.face.diagonal,
                surfacePoints(entry_b.face.*),
                entry_b.face.diagonal,
            )) try add(collector, .invalid_surface_coordinate, "mesh", entry_a.mesh.mesh_id.value.bytes, "faces.surface_coordinates", "surface", entry_a.face.primary_surface_id.value.bytes, "faces in one canonical surface chart may not overlap in their interiors");
        };
        run_start = run_end;
    }

    std.mem.sort(CoordinateMapEntry, entries, {}, lessThanTextureMapEntry);
    run_start = 0;
    while (run_start < entries.len) {
        var run_end = run_start + 1;
        while (run_end < entries.len and sameTextureMap(entries[run_start], entries[run_end])) : (run_end += 1) {}
        for (entries[run_start..run_end], 0..) |entry_a, index| for (entries[run_start + index + 1 .. run_end]) |entry_b| {
            const texture_a = entry_a.face.texture_coordinates[0];
            const texture_b = entry_b.face.texture_coordinates[0];
            if (quadsInteriorOverlap(
                texturePoints(entry_a.face.*),
                entry_a.face.diagonal,
                texturePoints(entry_b.face.*),
                entry_b.face.diagonal,
            ) and !declaresSameOverlapGroup(texture_a.overlap_group_id, texture_b.overlap_group_id)) try add(collector, .invalid_texture_uv, "mesh", entry_a.mesh.mesh_id.value.bytes, "faces.texture_coordinates", "uv_island", texture_a.uv_island_id.value.bytes, "overlapping UV interiors require the same explicit non-null overlap group");
        };
        run_start = run_end;
    }
}

const CoordinateMapEntry = struct {
    mesh: *const schema.Mesh,
    face: *const schema.QuadFace,
};

fn lessThanSurfaceMapEntry(_: void, a: CoordinateMapEntry, b: CoordinateMapEntry) bool {
    const surface_order = std.mem.order(u8, a.face.primary_surface_id.value.bytes, b.face.primary_surface_id.value.bytes);
    if (surface_order != .eq) return surface_order == .lt;
    const chart_order = std.mem.order(u8, a.face.surface_coordinates[0].chart_id.value.bytes, b.face.surface_coordinates[0].chart_id.value.bytes);
    if (chart_order != .eq) return chart_order == .lt;
    return lessThanCoordinateTie(a, b);
}

fn lessThanTextureMapEntry(_: void, a: CoordinateMapEntry, b: CoordinateMapEntry) bool {
    const texture_a = a.face.texture_coordinates[0];
    const texture_b = b.face.texture_coordinates[0];
    const space_order = std.mem.order(u8, texture_a.texture_space_id.value.bytes, texture_b.texture_space_id.value.bytes);
    if (space_order != .eq) return space_order == .lt;
    const island_order = std.mem.order(u8, texture_a.uv_island_id.value.bytes, texture_b.uv_island_id.value.bytes);
    if (island_order != .eq) return island_order == .lt;
    return lessThanCoordinateTie(a, b);
}

fn lessThanCoordinateTie(a: CoordinateMapEntry, b: CoordinateMapEntry) bool {
    const mesh_order = std.mem.order(u8, a.mesh.mesh_id.value.bytes, b.mesh.mesh_id.value.bytes);
    if (mesh_order != .eq) return mesh_order == .lt;
    return a.face.face_id.value < b.face.face_id.value;
}

fn sameSurfaceMap(a: CoordinateMapEntry, b: CoordinateMapEntry) bool {
    return a.face.primary_surface_id.eql(b.face.primary_surface_id) and
        a.face.surface_coordinates[0].chart_id.eql(b.face.surface_coordinates[0].chart_id);
}

fn sameTextureMap(a: CoordinateMapEntry, b: CoordinateMapEntry) bool {
    return a.face.texture_coordinates[0].texture_space_id.eql(b.face.texture_coordinates[0].texture_space_id) and
        a.face.texture_coordinates[0].uv_island_id.eql(b.face.texture_coordinates[0].uv_island_id);
}

fn surfacePoints(face: schema.QuadFace) [4]schema.Vec2 {
    return .{
        face.surface_coordinates[0].coordinate,
        face.surface_coordinates[1].coordinate,
        face.surface_coordinates[2].coordinate,
        face.surface_coordinates[3].coordinate,
    };
}

fn texturePoints(face: schema.QuadFace) [4]schema.Vec2 {
    return .{
        face.texture_coordinates[0].uv,
        face.texture_coordinates[1].uv,
        face.texture_coordinates[2].uv,
        face.texture_coordinates[3].uv,
    };
}

fn declaresSameOverlapGroup(a: ?identity.OverlapGroupId, b: ?identity.OverlapGroupId) bool {
    return a != null and b != null and a.?.eql(b.?);
}

fn quadsInteriorOverlap(
    a: [4]schema.Vec2,
    diagonal_a: schema.TriangulationDiagonal,
    b: [4]schema.Vec2,
    diagonal_b: schema.TriangulationDiagonal,
) bool {
    const triangles_a = splitQuad2(a, diagonal_a);
    const triangles_b = splitQuad2(b, diagonal_b);
    for (triangles_a) |triangle_a| for (triangles_b) |triangle_b| {
        if (trianglesInteriorOverlap(triangle_a, triangle_b)) return true;
    };
    return false;
}

fn splitQuad2(points: [4]schema.Vec2, diagonal: schema.TriangulationDiagonal) [2][3]schema.Vec2 {
    return switch (diagonal) {
        .v0_v2 => .{ .{ points[0], points[1], points[2] }, .{ points[0], points[2], points[3] } },
        .v1_v3 => .{ .{ points[0], points[1], points[3] }, .{ points[1], points[2], points[3] } },
    };
}

fn quadMapDegenerate(points: [4]schema.Vec2, diagonal: schema.TriangulationDiagonal) bool {
    const triangles = splitQuad2(points, diagonal);
    return orient2(triangles[0][0], triangles[0][1], triangles[0][2]) == 0 or
        orient2(triangles[1][0], triangles[1][1], triangles[1][2]) == 0;
}

fn quadSelfCrossing(points: [4]schema.Vec2) bool {
    return segmentsProperlyIntersect(points[0], points[1], points[2], points[3]) or
        segmentsProperlyIntersect(points[1], points[2], points[3], points[0]);
}

fn trianglesInteriorOverlap(a: [3]schema.Vec2, b: [3]schema.Vec2) bool {
    for (0..3) |a_index| for (0..3) |b_index| {
        if (segmentsProperlyIntersect(
            a[a_index],
            a[(a_index + 1) % 3],
            b[b_index],
            b[(b_index + 1) % 3],
        )) return true;
    };
    return pointStrictlyInsideTriangle(centroid2(a), b) or
        pointStrictlyInsideTriangle(centroid2(b), a);
}

fn segmentsProperlyIntersect(a: schema.Vec2, b: schema.Vec2, c: schema.Vec2, d: schema.Vec2) bool {
    const ab_c = orient2(a, b, c);
    const ab_d = orient2(a, b, d);
    const cd_a = orient2(c, d, a);
    const cd_b = orient2(c, d, b);
    return ((ab_c > 0 and ab_d < 0) or (ab_c < 0 and ab_d > 0)) and
        ((cd_a > 0 and cd_b < 0) or (cd_a < 0 and cd_b > 0));
}

fn pointStrictlyInsideTriangle(point: schema.Vec2, triangle: [3]schema.Vec2) bool {
    const a = orient2(triangle[0], triangle[1], point);
    const b = orient2(triangle[1], triangle[2], point);
    const c = orient2(triangle[2], triangle[0], point);
    return (a > 0 and b > 0 and c > 0) or (a < 0 and b < 0 and c < 0);
}

fn centroid2(triangle: [3]schema.Vec2) schema.Vec2 {
    return .{
        .x = (triangle[0].x + triangle[1].x + triangle[2].x) / 3,
        .y = (triangle[0].y + triangle[1].y + triangle[2].y) / 3,
    };
}

fn orient2(a: schema.Vec2, b: schema.Vec2, c: schema.Vec2) f64 {
    return (@as(f64, b.x) - @as(f64, a.x)) * (@as(f64, c.y) - @as(f64, a.y)) -
        (@as(f64, b.y) - @as(f64, a.y)) * (@as(f64, c.x) - @as(f64, a.x));
}

const FaceConnectivitySignature = struct {
    vertices: [4]u32,
};

fn validateDuplicateFaceConnectivityAlloc(
    allocator: std.mem.Allocator,
    collector: *diagnostics.Collector,
    mesh: *const schema.Mesh,
) !void {
    const signatures = try allocator.alloc(FaceConnectivitySignature, mesh.faces.len);
    defer allocator.free(signatures);
    for (mesh.faces, signatures) |face, *signature| {
        signature.vertices = .{
            face.vertex_ids[0].value,
            face.vertex_ids[1].value,
            face.vertex_ids[2].value,
            face.vertex_ids[3].value,
        };
        std.mem.sort(u32, signature.vertices[0..], {}, lessThanU32);
    }
    std.mem.sort(FaceConnectivitySignature, signatures, {}, lessThanFaceConnectivity);
    var start: usize = 0;
    while (start < signatures.len) {
        var end = start + 1;
        while (end < signatures.len and std.mem.eql(u32, &signatures[start].vertices, &signatures[end].vertices)) : (end += 1) {}
        const duplicate_count = end - start;
        if (duplicate_count > 1) {
            const pair_count = duplicate_count * (duplicate_count - 1) / 2;
            for (0..pair_count) |_| try add(collector, .duplicate_face, "mesh", mesh.mesh_id.value.bytes, "faces.vertex_ids", "face", null, "duplicate quad connectivity is not allowed");
        }
        start = end;
    }
}

fn lessThanU32(_: void, a: u32, b: u32) bool {
    return a < b;
}

fn lessThanFaceConnectivity(_: void, a: FaceConnectivitySignature, b: FaceConnectivitySignature) bool {
    for (a.vertices, b.vertices) |a_vertex, b_vertex| {
        if (a_vertex != b_vertex) return a_vertex < b_vertex;
    }
    return false;
}

fn vertexIdsStrictlyIncrease(vertices: []const schema.Vertex) bool {
    for (vertices[1..], vertices[0..vertices.len -| 1]) |current, previous| {
        if (current.vertex_id.value <= previous.vertex_id.value) return false;
    }
    return true;
}

fn faceIdsStrictlyIncrease(faces: []const schema.QuadFace) bool {
    for (faces[1..], faces[0..faces.len -| 1]) |current, previous| {
        if (current.face_id.value <= previous.face_id.value) return false;
    }
    return true;
}

const EdgeOccurrence = struct {
    key: topology.EdgeKey,
    from: identity.VertexId,
    to: identity.VertexId,
    face_id: identity.FaceId,
};

fn validateEdgeIncidence(allocator: std.mem.Allocator, collector: *diagnostics.Collector, mesh: *const schema.Mesh, edges: []const EdgeOccurrence) !void {
    const sorted = try allocator.dupe(EdgeOccurrence, edges);
    defer allocator.free(sorted);
    std.mem.sort(EdgeOccurrence, sorted, {}, lessThanEdgeOccurrence);
    var start: usize = 0;
    while (start < sorted.len) {
        var end = start + 1;
        while (end < sorted.len and sorted[start].key.eql(sorted[end].key)) : (end += 1) {}
        const edge = sorted[start];
        const count = end - start;
        if (count > 2) try add(collector, .non_manifold_edge, "mesh", mesh.mesh_id.value.bytes, "faces.vertex_ids", "edge", null, "an edge may have at most two incident quad faces");
        if (count == 2 and sorted[start].from.eql(sorted[start + 1].from) and sorted[start].to.eql(sorted[start + 1].to)) try add(collector, .inconsistent_winding, "mesh", mesh.mesh_id.value.bytes, "faces.vertex_ids", "edge", null, "two incident faces must traverse their shared edge in opposite directions");
        if (count == 1 and !boundaryContains(mesh, edge.from, edge.to)) try add(collector, .unexpected_boundary, "mesh", mesh.mesh_id.value.bytes, "boundary_loops", "edge", null, "every one-face edge must be explicitly classified in a boundary loop");
        start = end;
    }
}

fn lessThanEdgeOccurrence(_: void, a: EdgeOccurrence, b: EdgeOccurrence) bool {
    if (a.key.low.value != b.key.low.value) return a.key.low.value < b.key.low.value;
    if (a.key.high.value != b.key.high.value) return a.key.high.value < b.key.high.value;
    if (a.face_id.value != b.face_id.value) return a.face_id.value < b.face_id.value;
    if (a.from.value != b.from.value) return a.from.value < b.from.value;
    return a.to.value < b.to.value;
}

fn validateBoundaryLoops(collector: *diagnostics.Collector, mesh: *const schema.Mesh, edges: []const EdgeOccurrence) !void {
    for (mesh.boundary_loops, 0..) |loop, loop_index| {
        for (mesh.boundary_loops[loop_index + 1 ..]) |other| if (loop.boundary_loop_id.eql(other.boundary_loop_id)) try add(collector, .malformed_boundary_loop, "mesh", mesh.mesh_id.value.bytes, "boundary_loops.boundary_loop_id", "boundary_loop", loop.boundary_loop_id.value.bytes, "boundary loop IDs must be unique within a mesh");
        if (loop.directed_edges.len < 3) {
            try add(collector, .malformed_boundary_loop, "mesh", mesh.mesh_id.value.bytes, "boundary_loops.directed_edges", "boundary_loop", loop.boundary_loop_id.value.bytes, "a boundary loop requires at least three directed edges");
            continue;
        }
        var minimum_from = loop.directed_edges[0].from_vertex_id.value;
        for (loop.directed_edges, 0..) |edge, index| {
            minimum_from = @min(minimum_from, edge.from_vertex_id.value);
            const next = loop.directed_edges[(index + 1) % loop.directed_edges.len];
            if (!edge.to_vertex_id.eql(next.from_vertex_id)) try add(collector, .malformed_boundary_loop, "mesh", mesh.mesh_id.value.bytes, "boundary_loops.directed_edges", "boundary_loop", loop.boundary_loop_id.value.bytes, "boundary loop edges must form one connected closed directed cycle");
            for (loop.directed_edges[index + 1 ..]) |other| if (edge.from_vertex_id.eql(other.from_vertex_id)) try add(collector, .malformed_boundary_loop, "mesh", mesh.mesh_id.value.bytes, "boundary_loops.directed_edges", "boundary_loop", loop.boundary_loop_id.value.bytes, "boundary loop may not repeat a vertex");
            if (!edgeOccurrenceExists(edges, edge.from_vertex_id, edge.to_vertex_id, true)) try add(collector, .malformed_boundary_loop, "mesh", mesh.mesh_id.value.bytes, "boundary_loops.directed_edges", "edge", null, "boundary loop must reference directed topology boundary edges");
        }
        if (loop.directed_edges[0].from_vertex_id.value != minimum_from or
            loop.directed_edges[0].to_vertex_id.value >= loop.directed_edges[loop.directed_edges.len - 1].from_vertex_id.value)
        {
            try add(collector, .malformed_boundary_loop, "mesh", mesh.mesh_id.value.bytes, "boundary_loops.directed_edges", "boundary_loop", loop.boundary_loop_id.value.bytes, "boundary loop canonical order starts at its lowest vertex ID and chooses the lexicographically smaller direction");
        }
    }
}

fn validateConnectedAlloc(
    allocator: std.mem.Allocator,
    collector: *diagnostics.Collector,
    mesh: *const schema.Mesh,
    vertex_ids_are_nondecreasing: bool,
) !void {
    if (mesh.vertices.len == 0 or mesh.faces.len == 0) {
        try add(collector, .disconnected_mesh, "mesh", mesh.mesh_id.value.bytes, "connectivity_policy", null, null, "a connected mesh requires vertices and faces");
        return;
    }
    const parents = try allocator.alloc(usize, mesh.vertices.len);
    defer allocator.free(parents);
    for (parents, 0..) |*parent, index| parent.* = index;

    for (mesh.faces) |face| {
        const first_index = findVertexIndexWithOrder(mesh, face.vertex_ids[0], vertex_ids_are_nondecreasing) orelse continue;
        for (face.vertex_ids[1..]) |vertex_id| {
            const index = findVertexIndexWithOrder(mesh, vertex_id, vertex_ids_are_nondecreasing) orelse continue;
            unionVertexSets(parents, first_index, index);
        }
    }

    const first_root = vertexSetRoot(parents, 0);
    for (1..parents.len) |index| {
        if (vertexSetRoot(parents, index) == first_root) continue;
        try add(collector, .disconnected_mesh, "mesh", mesh.mesh_id.value.bytes, "connectivity_policy", null, null, "all mesh vertices must belong to one connected component");
        break;
    }
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

fn validateFaceSet(collector: *diagnostics.Collector, geometry: *const schema.GeometryDefinition, face_set: schema.FaceSet) !void {
    const mesh = findMesh(geometry, face_set.mesh_id);
    if (mesh == null) {
        try add(collector, .invalid_face_set, "face_set", face_set.face_set_id.value.bytes, "mesh_id", "mesh", face_set.mesh_id.value.bytes, "face set mesh must exist");
        return;
    }
    const face_ids_are_nondecreasing = faceIdsNondecreasing(mesh.?.faces);
    for (face_set.face_ids, 0..) |face_id, index| {
        if (findMeshFaceWithOrder(mesh.?, face_id, face_ids_are_nondecreasing) == null) try add(collector, .invalid_face_set, "face_set", face_set.face_set_id.value.bytes, "face_ids", "face", null, "face set references an unknown face ID");
        for (face_set.face_ids[index + 1 ..]) |other| if (face_id.eql(other)) try add(collector, .invalid_face_set, "face_set", face_set.face_set_id.value.bytes, "face_ids", "face", null, "face set face IDs must be unique");
    }
}

fn validateTopologyLoop(
    collector: *diagnostics.Collector,
    geometry: *const schema.GeometryDefinition,
    mesh_edge_indexes: []const MeshEdgeIndex,
    loop: schema.TopologyLoop,
) !void {
    const mesh = findMesh(geometry, loop.mesh_id);
    const edge_index = findMeshEdgeIndex(mesh_edge_indexes, loop.mesh_id);
    if (mesh == null or edge_index == null or loop.directed_edges.len < 3 or
        !directedLoopConnected(loop.directed_edges) or
        !directedLoopSimple(loop.directed_edges) or
        !directedLoopCanonical(loop.directed_edges))
    {
        try add(collector, .malformed_boundary_loop, "topology_loop", loop.topology_loop_id.value.bytes, "directed_edges", "mesh", loop.mesh_id.value.bytes, "topology loop must reference one mesh and form a simple canonical directed cycle");
        return;
    }
    for (loop.directed_edges) |edge| if (!meshEdgeExists(edge_index.?, edge.from_vertex_id, edge.to_vertex_id)) {
        try add(collector, .malformed_boundary_loop, "topology_loop", loop.topology_loop_id.value.bytes, "directed_edges", "edge", null, "topology loop edges must exist in mesh topology");
    };

    if (loop.becomes_boundary_when_face_set_removed) |face_set_id| {
        const face_set = findFaceSet(geometry, face_set_id);
        if (face_set == null or !face_set.?.mesh_id.eql(loop.mesh_id) or
            !suppressedBoundaryMatchesLoop(mesh.?, face_set.?, loop.directed_edges))
        {
            try add(collector, .invalid_face_set, "topology_loop", loop.topology_loop_id.value.bytes, "becomes_boundary_when_face_set_removed", "face_set", face_set_id.value.bytes, "suppressing the referenced closure face set must expose exactly this directed topology loop");
        }
    }
}

fn validateSeamBinding(
    collector: *diagnostics.Collector,
    geometry: *const schema.GeometryDefinition,
    mesh_edge_indexes: []const MeshEdgeIndex,
    context: StructuralContext,
    binding: schema.GeometrySeamBinding,
) !void {
    const seam = findSeam(context.definition, binding.structural_seam_id);
    const mesh = findMesh(geometry, binding.mesh_id);
    const edge_index = findMeshEdgeIndex(mesh_edge_indexes, binding.mesh_id);
    if (seam == null or mesh == null or edge_index == null) {
        try add(collector, .malformed_seam_loop, "seam_binding", binding.geometry_seam_binding_id.value.bytes, if (seam == null) "structural_seam_id" else "mesh_id", if (seam == null) "seam" else "mesh", if (seam == null) binding.structural_seam_id.value.bytes else binding.mesh_id.value.bytes, "seam binding references must resolve");
        return;
    }
    if (!binding.is_closed or binding.directed_edges.len < 3 or
        !directedLoopConnected(binding.directed_edges) or
        !directedLoopSimple(binding.directed_edges) or
        !directedLoopCanonical(binding.directed_edges))
    {
        try add(collector, .malformed_seam_loop, "seam_binding", binding.geometry_seam_binding_id.value.bytes, "directed_edges", "mesh", binding.mesh_id.value.bytes, "structural seam binding must be a simple closed loop in canonical lowest-ID and lexicographically minimal orientation");
    }
    for (binding.directed_edges) |edge| if (!meshEdgeExists(edge_index.?, edge.from_vertex_id, edge.to_vertex_id)) try add(collector, .malformed_seam_loop, "seam_binding", binding.geometry_seam_binding_id.value.bytes, "directed_edges", "edge", null, "seam loop edges must exist in mesh topology");
    if (binding.side_a_surface_id.eql(binding.side_b_surface_id) or !seamContainsSurface(seam.?, binding.side_a_surface_id) or !seamContainsSurface(seam.?, binding.side_b_surface_id)) try add(collector, .invalid_seam_semantics, "seam_binding", binding.geometry_seam_binding_id.value.bytes, "side_a_surface_id", "surface", binding.side_a_surface_id.value.bytes, "seam sides must be distinct members of the structural seam");
}

fn validateGeometryBinding(
    collector: *diagnostics.Collector,
    geometry: *const schema.GeometryDefinition,
    context: StructuralContext,
    binding: schema.GeometryBinding,
) !void {
    const subject_count: u8 = @as(u8, @intFromBool(binding.landmark_id != null)) +
        @as(u8, @intFromBool(binding.interaction_site_id != null));
    const mesh = findMesh(geometry, binding.mesh_id);
    const face = if (mesh) |resolved| findMeshFaceWithOrder(resolved, binding.face_id, faceIdsNondecreasing(resolved.faces)) else null;
    var subject_valid = subject_count == 1;
    if (binding.landmark_id) |id| subject_valid = subject_valid and findLandmark(context.definition, id) != null;
    if (binding.interaction_site_id) |id| subject_valid = subject_valid and findSite(context.definition, id) != null;
    if (!subject_valid or mesh == null or face == null or !finiteUnit2(binding.local_face_coordinate) or !finiteUnit2(binding.surface_coordinate.coordinate) or (face != null and !binding.surface_coordinate.surface_id.eql(face.?.primary_surface_id))) try add(collector, .invalid_geometry_binding, "geometry_binding", binding.geometry_binding_id.value.bytes, "binding", "mesh", binding.mesh_id.value.bytes, "geometry binding requires exactly one valid structural subject, a valid face, and in-domain matching surface coordinates");
}

fn validateModuleInterface(collector: *diagnostics.Collector, geometry: *const schema.GeometryDefinition, interface: schema.ModuleInterface) !void {
    const receiver = findMesh(geometry, interface.receiver_mesh_id);
    const module = findMesh(geometry, interface.module_mesh_id);
    const face_set = findFaceSet(geometry, interface.receiver_closure_face_set_id);
    const body_boundary_loop = if (receiver) |mesh| findBoundaryLoop(mesh, interface.body_receiver_loop_id) else null;
    const body_topology_loop = findTopologyLoop(geometry, interface.body_receiver_loop_id);
    const module_loop = if (module) |mesh| findBoundaryLoop(mesh, interface.module_root_loop_id) else null;
    const body_loop_len: ?usize = if (body_boundary_loop) |loop| loop.directed_edges.len else if (body_topology_loop) |loop| if (loop.mesh_id.eql(interface.receiver_mesh_id)) loop.directed_edges.len else null else null;
    if (receiver == null or module == null or face_set == null or body_loop_len == null or module_loop == null or !face_set.?.mesh_id.eql(interface.receiver_mesh_id) or body_loop_len.? != module_loop.?.directed_edges.len) try add(collector, .invalid_module_interface, "module_interface", interface.module_interface_id.value.bytes, "interface", "mesh", interface.receiver_mesh_id.value.bytes, "module interface meshes, closure face set, loops, and loop cardinality must agree");
}

fn validateCollisionProxy(
    collector: *diagnostics.Collector,
    geometry: *const schema.GeometryDefinition,
    context: StructuralContext,
    proxy: schema.CollisionProxy,
) !void {
    if (findComponent(context.definition, proxy.owner_component_id) == null or findRegion(context.definition, proxy.semantic_region_id) == null) try add(collector, .invalid_proxy_owner, "collision_proxy", proxy.collision_proxy_id.value.bytes, "owner_component_id", "component", proxy.owner_component_id.value.bytes, "collision proxy owner and semantic region must exist structurally");
    const driver_count: u8 = @as(u8, @intFromBool(proxy.driver_bone_id != null)) +
        @as(u8, @intFromBool(proxy.driver_anchor_id != null));
    var driver_valid = driver_count == 1;
    if (proxy.driver_bone_id) |id| driver_valid = driver_valid and findBone(context.definition, id) != null;
    if (proxy.driver_anchor_id) |id| driver_valid = driver_valid and findAnchor(context.definition, id) != null;
    if (!driver_valid or !finiteTransform(proxy.local_transform)) try add(collector, .invalid_proxy_driver, "collision_proxy", proxy.collision_proxy_id.value.bytes, "driver", null, null, "collision proxy requires exactly one valid structural driver and a finite canonical local transform");
    if (!validDimensions(proxy.primitive, proxy.dimensions)) try add(collector, .invalid_proxy_dimensions, "collision_proxy", proxy.collision_proxy_id.value.bytes, "dimensions", null, null, "collision proxy dimensions must match the primitive and be finite and positive");
    if (!proxy.topology_id.eql(geometry.topology_identity.topology_id) or !proxy.topology_compatibility_version.eql(geometry.topology_identity.compatibility_version) or proxy.topology_revision != geometry.topology_identity.revision) try add(collector, .topology_compatibility_mismatch, "collision_proxy", proxy.collision_proxy_id.value.bytes, "topology_id", "topology", proxy.topology_id.value.bytes, "collision proxy topology compatibility must match the geometry definition");
}

fn validDimensions(primitive: schema.CollisionPrimitive, dimensions: schema.CollisionProxyDimensions) bool {
    return switch (primitive) {
        .sphere => positive(dimensions.radius_m) and dimensions.half_length_m == null and dimensions.half_extents_m == null,
        .capsule => positive(dimensions.radius_m) and positive(dimensions.half_length_m) and dimensions.half_extents_m == null,
        .box => dimensions.radius_m == null and dimensions.half_length_m == null and if (dimensions.half_extents_m) |extents| finite3(extents) and extents.x > 0 and extents.y > 0 and extents.z > 0 else false,
    };
}

fn positive(value: ?f32) bool {
    return if (value) |number| std.math.isFinite(number) and number > 0 else false;
}

fn finiteTransform(value: canonical.math3d.LocalTransform) bool {
    if (!finite3(value.translation_m) or !finite3(value.scale)) return false;
    _ = canonical.math3d.Quaternion.initCanonical(value.rotation.x, value.rotation.y, value.rotation.z, value.rotation.w) catch return false;
    return true;
}

fn finite3(value: canonical.math3d.Vec3) bool {
    return std.math.isFinite(value.x) and std.math.isFinite(value.y) and std.math.isFinite(value.z);
}

fn finiteUnit2(value: schema.Vec2) bool {
    return std.math.isFinite(value.x) and std.math.isFinite(value.y) and value.x >= 0 and value.x <= 1 and value.y >= 0 and value.y <= 1;
}

fn quadDegenerate(mesh: *const schema.Mesh, face: schema.QuadFace, vertex_ids_are_nondecreasing: bool) bool {
    const a = findMeshVertexWithOrder(mesh, face.vertex_ids[0], vertex_ids_are_nondecreasing).?.position_m;
    const b = findMeshVertexWithOrder(mesh, face.vertex_ids[1], vertex_ids_are_nondecreasing).?.position_m;
    const c = findMeshVertexWithOrder(mesh, face.vertex_ids[2], vertex_ids_are_nondecreasing).?.position_m;
    const d = findMeshVertexWithOrder(mesh, face.vertex_ids[3], vertex_ids_are_nondecreasing).?.position_m;
    return switch (face.diagonal) {
        .v0_v2 => triangleAreaSquared(a, b, c) == 0 or triangleAreaSquared(a, c, d) == 0,
        .v1_v3 => triangleAreaSquared(a, b, d) == 0 or triangleAreaSquared(b, c, d) == 0,
    };
}

fn triangleAreaSquared(a: canonical.math3d.Vec3, b: canonical.math3d.Vec3, c: canonical.math3d.Vec3) f64 {
    const ab = [3]f64{ b.x - a.x, b.y - a.y, b.z - a.z };
    const ac = [3]f64{ c.x - a.x, c.y - a.y, c.z - a.z };
    const cross = [3]f64{
        ab[1] * ac[2] - ab[2] * ac[1],
        ab[2] * ac[0] - ab[0] * ac[2],
        ab[0] * ac[1] - ab[1] * ac[0],
    };
    return cross[0] * cross[0] + cross[1] * cross[1] + cross[2] * cross[2];
}

fn sameFaceVertexSet(a: [4]identity.VertexId, b: [4]identity.VertexId) bool {
    for (a) |id| {
        var found = false;
        for (b) |other| if (id.eql(other)) {
            found = true;
            break;
        };
        if (!found) return false;
    }
    return true;
}

fn boundaryContains(mesh: *const schema.Mesh, from: identity.VertexId, to: identity.VertexId) bool {
    for (mesh.boundary_loops) |loop| for (loop.directed_edges) |edge| if (edge.from_vertex_id.eql(from) and edge.to_vertex_id.eql(to)) return true;
    return false;
}

fn edgeOccurrenceExists(edges: []const EdgeOccurrence, from: identity.VertexId, to: identity.VertexId, require_boundary: bool) bool {
    var count: usize = 0;
    var direction = false;
    const key = topology.EdgeKey.init(from, to);
    for (edges) |edge| if (edge.key.eql(key)) {
        count += 1;
        if (edge.from.eql(from) and edge.to.eql(to)) direction = true;
    };
    return direction and (!require_boundary or count == 1);
}

fn directedLoopConnected(edges: []const schema.DirectedEdge) bool {
    if (edges.len == 0) return false;
    for (edges, 0..) |edge, index| if (!edge.to_vertex_id.eql(edges[(index + 1) % edges.len].from_vertex_id)) return false;
    return true;
}

fn minimumLoopVertex(edges: []const schema.DirectedEdge) u32 {
    var result = edges[0].from_vertex_id.value;
    for (edges[1..]) |edge| result = @min(result, edge.from_vertex_id.value);
    return result;
}

fn directedLoopSimple(edges: []const schema.DirectedEdge) bool {
    for (edges, 0..) |edge, index| for (edges[index + 1 ..]) |other| {
        if (edge.from_vertex_id.eql(other.from_vertex_id)) return false;
    };
    return true;
}

fn directedLoopCanonical(edges: []const schema.DirectedEdge) bool {
    if (edges.len < 3) return false;
    return edges[0].from_vertex_id.value == minimumLoopVertex(edges) and
        edges[0].to_vertex_id.value < edges[edges.len - 1].from_vertex_id.value;
}

const MeshEdgeIndex = struct {
    mesh_id: identity.MeshId,
    edge_keys: []topology.EdgeKey,
};

fn buildMeshEdgeIndexesAlloc(allocator: std.mem.Allocator, meshes: []const schema.Mesh) ![]MeshEdgeIndex {
    const indexes = try allocator.alloc(MeshEdgeIndex, meshes.len);
    var initialized: usize = 0;
    errdefer {
        for (indexes[0..initialized]) |index| allocator.free(index.edge_keys);
        allocator.free(indexes);
    }
    for (meshes, indexes) |mesh, *index| {
        const edge_count = try std.math.mul(usize, mesh.faces.len, 4);
        const edge_keys = try allocator.alloc(topology.EdgeKey, edge_count);
        for (mesh.faces, 0..) |face, face_index| for (0..4) |corner| {
            edge_keys[face_index * 4 + corner] = topology.EdgeKey.init(
                face.vertex_ids[corner],
                face.vertex_ids[(corner + 1) % 4],
            );
        };
        std.mem.sort(topology.EdgeKey, edge_keys, {}, lessThanEdgeKey);
        index.* = .{ .mesh_id = mesh.mesh_id, .edge_keys = edge_keys };
        initialized += 1;
    }
    return indexes;
}

fn deinitMeshEdgeIndexes(allocator: std.mem.Allocator, indexes: []MeshEdgeIndex) void {
    for (indexes) |index| allocator.free(index.edge_keys);
    allocator.free(indexes);
}

fn lessThanEdgeKey(_: void, a: topology.EdgeKey, b: topology.EdgeKey) bool {
    if (a.low.value != b.low.value) return a.low.value < b.low.value;
    return a.high.value < b.high.value;
}

fn findMeshEdgeIndex(indexes: []const MeshEdgeIndex, mesh_id: identity.MeshId) ?*const MeshEdgeIndex {
    for (indexes) |*index| if (index.mesh_id.eql(mesh_id)) return index;
    return null;
}

fn meshEdgeExists(index: *const MeshEdgeIndex, from: identity.VertexId, to: identity.VertexId) bool {
    const key = topology.EdgeKey.init(from, to);
    var low: usize = 0;
    var high: usize = index.edge_keys.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const candidate = index.edge_keys[middle];
        if (candidate.low.value < key.low.value or
            (candidate.low.value == key.low.value and candidate.high.value < key.high.value))
        {
            low = middle + 1;
        } else if (candidate.low.value > key.low.value or
            (candidate.low.value == key.low.value and candidate.high.value > key.high.value))
        {
            high = middle;
        } else {
            return true;
        }
    }
    return false;
}

fn suppressedBoundaryMatchesLoop(
    mesh: *const schema.Mesh,
    face_set: schema.FaceSet,
    loop_edges: []const schema.DirectedEdge,
) bool {
    if (face_set.face_ids.len == 0) return false;

    for (loop_edges) |loop_edge| {
        var kept_occurrences: usize = 0;
        var suppressed_occurrences: usize = 0;
        const loop_key = topology.EdgeKey.init(loop_edge.from_vertex_id, loop_edge.to_vertex_id);
        for (mesh.faces) |face| for (0..4) |corner| {
            const face_key = topology.EdgeKey.init(face.vertex_ids[corner], face.vertex_ids[(corner + 1) % 4]);
            if (!face_key.eql(loop_key)) continue;
            if (faceSetContains(face_set, face.face_id)) {
                suppressed_occurrences += 1;
            } else {
                kept_occurrences += 1;
            }
        };
        if (kept_occurrences != 1 or suppressed_occurrences != 1) return false;
    }

    for (mesh.faces) |face| {
        if (faceSetContains(face_set, face.face_id)) continue;
        for (0..4) |corner| {
            const from = face.vertex_ids[corner];
            const to = face.vertex_ids[(corner + 1) % 4];
            var touches_suppressed = false;
            const key = topology.EdgeKey.init(from, to);
            for (mesh.faces) |candidate| {
                if (!faceSetContains(face_set, candidate.face_id)) continue;
                for (0..4) |candidate_corner| {
                    const candidate_key = topology.EdgeKey.init(
                        candidate.vertex_ids[candidate_corner],
                        candidate.vertex_ids[(candidate_corner + 1) % 4],
                    );
                    if (candidate_key.eql(key)) touches_suppressed = true;
                }
            }
            if (touches_suppressed and !loopContainsUndirected(loop_edges, from, to)) return false;
        }
    }
    return true;
}

fn faceSetContains(face_set: schema.FaceSet, face_id: identity.FaceId) bool {
    for (face_set.face_ids) |candidate| if (candidate.eql(face_id)) return true;
    return false;
}

fn loopContainsUndirected(edges: []const schema.DirectedEdge, a: identity.VertexId, b: identity.VertexId) bool {
    for (edges) |edge| if ((edge.from_vertex_id.eql(a) and edge.to_vertex_id.eql(b)) or
        (edge.from_vertex_id.eql(b) and edge.to_vertex_id.eql(a))) return true;
    return false;
}

fn seamContainsSurface(seam: canonical.semantics.SharedSeam, surface_id: canonical.identity.SurfaceId) bool {
    for (seam.members) |member| if (member.surface_id.eql(surface_id)) return true;
    return false;
}

fn validateUniqueStringRecordIds(collector: *diagnostics.Collector, comptime T: type, values: []const T, comptime field: []const u8, object_type: []const u8) !void {
    for (values, 0..) |item, index| for (values[index + 1 ..]) |other| if (@field(item, field).eql(@field(other, field))) try add(collector, .duplicate_mesh_id, object_type, @field(item, field).value.bytes, field, null, null, "stable record IDs must be unique");
}

fn containsTyped(comptime T: type, values: []const T, target: T) bool {
    for (values) |value| if (value.eql(target)) return true;
    return false;
}

fn optionalIdEql(comptime T: type, a: ?T, b: ?T) bool {
    if (a == null or b == null) return a == null and b == null;
    return a.?.eql(b.?);
}

fn assetVersionEql(a: canonical.identity.AssetVersion, b: canonical.identity.AssetVersion) bool {
    return a.major == b.major and a.minor == b.minor and a.patch == b.patch;
}

fn schemaVersionEql(a: canonical.identity.SchemaVersion, b: canonical.identity.SchemaVersion) bool {
    return a.major == b.major and a.minor == b.minor and a.patch == b.patch;
}

fn findMesh(geometry: *const schema.GeometryDefinition, id: identity.MeshId) ?*const schema.Mesh {
    for (geometry.meshes) |*mesh| if (mesh.mesh_id.eql(id)) return mesh;
    return null;
}

fn findFaceSet(geometry: *const schema.GeometryDefinition, id: identity.FaceSetId) ?schema.FaceSet {
    for (geometry.face_sets) |item| if (item.face_set_id.eql(id)) return item;
    return null;
}

fn findTopologyLoop(geometry: *const schema.GeometryDefinition, id: identity.BoundaryLoopId) ?schema.TopologyLoop {
    for (geometry.topology_loops) |item| if (item.topology_loop_id.eql(id)) return item;
    return null;
}

fn findBoundaryLoop(mesh: *const schema.Mesh, id: identity.BoundaryLoopId) ?schema.BoundaryLoop {
    for (mesh.boundary_loops) |item| if (item.boundary_loop_id.eql(id)) return item;
    return null;
}

fn findMeshVertex(mesh: *const schema.Mesh, id: identity.VertexId) ?schema.Vertex {
    for (mesh.vertices) |item| if (item.vertex_id.eql(id)) return item;
    return null;
}

fn findMeshVertexWithOrder(mesh: *const schema.Mesh, id: identity.VertexId, ids_are_nondecreasing: bool) ?schema.Vertex {
    if (ids_are_nondecreasing) {
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
    return findMeshVertex(mesh, id);
}

fn findVertexIndex(mesh: *const schema.Mesh, id: identity.VertexId) ?usize {
    for (mesh.vertices, 0..) |item, index| if (item.vertex_id.eql(id)) return index;
    return null;
}

fn findVertexIndexWithOrder(mesh: *const schema.Mesh, id: identity.VertexId, ids_are_nondecreasing: bool) ?usize {
    if (ids_are_nondecreasing) {
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
    return findVertexIndex(mesh, id);
}

fn findMeshFace(mesh: *const schema.Mesh, id: identity.FaceId) ?schema.QuadFace {
    for (mesh.faces) |item| if (item.face_id.eql(id)) return item;
    return null;
}

fn findMeshFaceWithOrder(mesh: *const schema.Mesh, id: identity.FaceId, ids_are_nondecreasing: bool) ?schema.QuadFace {
    if (ids_are_nondecreasing) {
        var low: usize = 0;
        var high: usize = mesh.faces.len;
        while (low < high) {
            const middle = low + (high - low) / 2;
            const candidate = mesh.faces[middle];
            if (candidate.face_id.value < id.value) {
                low = middle + 1;
            } else if (candidate.face_id.value > id.value) {
                high = middle;
            } else {
                return candidate;
            }
        }
        return null;
    }
    return findMeshFace(mesh, id);
}

fn vertexIdsNondecreasing(vertices: []const schema.Vertex) bool {
    for (vertices[1..], vertices[0..vertices.len -| 1]) |current, previous| {
        if (current.vertex_id.value < previous.vertex_id.value) return false;
    }
    return true;
}

fn faceIdsNondecreasing(faces: []const schema.QuadFace) bool {
    for (faces[1..], faces[0..faces.len -| 1]) |current, previous| {
        if (current.face_id.value < previous.face_id.value) return false;
    }
    return true;
}

fn findComponent(definition: *const canonical.definition.CanonicalCreatureDefinition, id: canonical.identity.ComponentId) ?canonical.component.Component {
    for (definition.components) |item| if (item.component_id.eql(id)) return item;
    return null;
}

fn findBone(definition: *const canonical.definition.CanonicalCreatureDefinition, id: canonical.identity.BoneId) ?canonical.rig.Bone {
    for (definition.bones) |item| if (item.bone_id.eql(id)) return item;
    return null;
}

fn findAnchor(definition: *const canonical.definition.CanonicalCreatureDefinition, id: canonical.identity.AnchorId) ?canonical.attachment.Anchor {
    for (definition.anchors) |item| if (item.anchor_id.eql(id)) return item;
    return null;
}

fn findSurface(definition: *const canonical.definition.CanonicalCreatureDefinition, id: canonical.identity.SurfaceId) ?canonical.semantics.Surface {
    for (definition.surfaces) |item| if (item.surface_id.eql(id)) return item;
    return null;
}

fn findRegion(definition: *const canonical.definition.CanonicalCreatureDefinition, id: canonical.identity.RegionId) ?canonical.semantics.Region {
    for (definition.regions) |item| if (item.region_id.eql(id)) return item;
    return null;
}

fn findMaterial(definition: *const canonical.definition.CanonicalCreatureDefinition, id: canonical.identity.MaterialInstanceId) ?canonical.material.MaterialInstance {
    for (definition.material_instances) |item| if (item.material_instance_id.eql(id)) return item;
    return null;
}

fn findSeam(definition: *const canonical.definition.CanonicalCreatureDefinition, id: canonical.identity.SeamId) ?canonical.semantics.SharedSeam {
    for (definition.shared_seams) |item| if (item.seam_id.eql(id)) return item;
    return null;
}

fn findLandmark(definition: *const canonical.definition.CanonicalCreatureDefinition, id: canonical.identity.LandmarkId) ?canonical.semantics.Landmark {
    for (definition.landmarks) |item| if (item.landmark_id.eql(id)) return item;
    return null;
}

fn findSite(definition: *const canonical.definition.CanonicalCreatureDefinition, id: canonical.identity.InteractionSiteId) ?canonical.semantics.InteractionSite {
    for (definition.interaction_sites) |item| if (item.site_id.eql(id)) return item;
    return null;
}

fn missing(collector: *diagnostics.Collector, property: []const u8, reference_id: []const u8, reference_type: []const u8) !void {
    try add(collector, .missing_structural_reference, "structural_compatibility", null, property, reference_type, reference_id, "required structural ID is absent from the supplied definition");
}

fn missingFor(collector: *diagnostics.Collector, object_type: []const u8, object_id: []const u8, property: []const u8, reference_type: []const u8, reference_id: []const u8) !void {
    try add(collector, .missing_structural_reference, object_type, object_id, property, reference_type, reference_id, "geometry reference is absent from the supplied structural definition");
}

fn add(
    collector: *diagnostics.Collector,
    code: diagnostics.Code,
    object_type: []const u8,
    object_id: ?[]const u8,
    property: ?[]const u8,
    reference_type: ?[]const u8,
    reference_id: ?[]const u8,
    message: []const u8,
) !void {
    try collector.add(.{
        .code = code,
        .object_type = object_type,
        .object_id = object_id,
        .property = property,
        .reference_type = reference_type,
        .reference_id = reference_id,
        .message = message,
    });
}
