const std = @import("std");
const canonical = @import("canonical_model");
const geometry = @import("canonical_geometry");
const human_support = @import("canonical_human_test_support.zig");

const valid_fixture_path = "tests/fixtures/canonical_geometry/valid_open_module.authoring.json";
const accepted_structural_hash_hex = "b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda";

test "canonical geometry foundation module compiles" {
    try std.testing.expectEqualStrings("canonical_geometry_schema", geometry.schema.schema_id);
}

test "public loader parses validates and normalizes synthetic file-backed geometry" {
    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);

    var report: ?geometry.diagnostics.OwnedReport = null;
    defer if (report) |*owned| owned.deinit();
    var loaded = try geometry.loader.loadFile(
        std.testing.allocator,
        std.testing.io,
        valid_fixture_path,
        context,
        .{},
        &report,
    );
    defer loaded.deinit();

    try std.testing.expect(report == null);
    try std.testing.expectEqual(@as(usize, 2), loaded.definition().meshes.len);
    try std.testing.expectEqual(@as(usize, 1), loaded.definition().module_interfaces.len);
    try std.testing.expectEqual(@as(usize, 1), loaded.definition().collision_proxies.len);

    var source_result = try geometry.hashing.sourceHashAlloc(std.testing.allocator, loaded.normalized());
    defer source_result.deinit();
    try std.testing.expect(source_result.canonical_bytes.len > 0);
    try std.testing.expectEqual(@as(u8, '}'), source_result.canonical_bytes[source_result.canonical_bytes.len - 1]);
    try std.testing.expect(source_result.geometry_source_sha256.eql(geometry.hashing.hashBytes(source_result.canonical_bytes)));
}

test "canonical serialization and identity hashes obey their separate contracts" {
    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);
    var loaded = try loadValid(context);
    defer loaded.deinit();

    var baseline_source = try geometry.hashing.sourceHashAlloc(std.testing.allocator, loaded.normalized());
    defer baseline_source.deinit();
    const baseline_topology = try geometry.hashing.topologyHashAlloc(std.testing.allocator, loaded.definition());
    const baseline_triangulation = try geometry.hashing.triangulationHashAlloc(std.testing.allocator, loaded.definition());
    const baseline_neutral = try geometry.hashing.neutralSignatureAlloc(
        std.testing.allocator,
        loaded.definition(),
        context.normalized_source_sha256,
        baseline_source.geometry_source_sha256,
        baseline_topology,
    );
    try std.testing.expectEqual(@as(usize, 7019), baseline_source.canonical_bytes.len);
    try std.testing.expectEqualStrings("4774698cde129491562f9da468b3e4338c3c672a665701f620c8f3ce9088921e", &baseline_source.geometry_source_sha256.toHex());
    try std.testing.expectEqualStrings("bfe6b0b026d43678d37e504a6ea05d58599aa04c7e18c32812f0301cf51a1e89", &baseline_topology.toHex());
    try std.testing.expectEqualStrings("821aac9a784bb8440fad51da168245049654ac17ef4faf8fdcc8fda7d89862d5", &baseline_triangulation.toHex());
    try std.testing.expectEqualStrings("046a57153102492c27138745bdee22cc6dff9d44221af11b202a0ef62ba9b0e8", &baseline_neutral.toHex());

    var position_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer position_arena.deinit();
    var position_definition = try cloneForMutation(position_arena.allocator(), loaded.definition());
    const position_meshes: []geometry.schema.Mesh = @constCast(position_definition.meshes);
    const position_vertices: []geometry.schema.Vertex = @constCast(position_meshes[0].vertices);
    position_vertices[0].position_m.x += 0.125;
    var position_source = try geometry.hashing.sourceHashAlloc(std.testing.allocator, geometry.normalization.normalize(&position_definition));
    defer position_source.deinit();
    const position_topology = try geometry.hashing.topologyHashAlloc(std.testing.allocator, &position_definition);
    try std.testing.expect(!position_source.geometry_source_sha256.eql(baseline_source.geometry_source_sha256));
    try std.testing.expect(position_topology.eql(baseline_topology));
    try geometry.hashing.validateTopologyRevisionTransition(
        std.testing.allocator,
        loaded.definition(),
        &position_definition,
    );

    var cursor_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer cursor_arena.deinit();
    var cursor_definition = try cloneForMutation(cursor_arena.allocator(), loaded.definition());
    @constCast(cursor_definition.meshes)[0].next_vertex_id += 1;
    var cursor_source = try geometry.hashing.sourceHashAlloc(std.testing.allocator, geometry.normalization.normalize(&cursor_definition));
    defer cursor_source.deinit();
    const cursor_topology = try geometry.hashing.topologyHashAlloc(std.testing.allocator, &cursor_definition);
    try std.testing.expect(!cursor_source.geometry_source_sha256.eql(baseline_source.geometry_source_sha256));
    try std.testing.expect(cursor_topology.eql(baseline_topology));

    var diagonal_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer diagonal_arena.deinit();
    var diagonal_definition = try cloneForMutation(diagonal_arena.allocator(), loaded.definition());
    @constCast(@constCast(diagonal_definition.meshes)[0].faces)[0].diagonal = .v1_v3;
    const diagonal_topology = try geometry.hashing.topologyHashAlloc(std.testing.allocator, &diagonal_definition);
    const diagonal_triangulation = try geometry.hashing.triangulationHashAlloc(std.testing.allocator, &diagonal_definition);
    try std.testing.expect(diagonal_topology.eql(baseline_topology));
    try std.testing.expect(!diagonal_triangulation.eql(baseline_triangulation));

    var connectivity_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer connectivity_arena.deinit();
    var connectivity_definition = try cloneForMutation(connectivity_arena.allocator(), loaded.definition());
    const connectivity_face = &@constCast(@constCast(connectivity_definition.meshes)[0].faces)[0];
    const swapped = connectivity_face.vertex_ids[2];
    connectivity_face.vertex_ids[2] = connectivity_face.vertex_ids[3];
    connectivity_face.vertex_ids[3] = swapped;
    const connectivity_topology = try geometry.hashing.topologyHashAlloc(std.testing.allocator, &connectivity_definition);
    try std.testing.expect(!connectivity_topology.eql(baseline_topology));
    try std.testing.expectError(
        error.TopologyRevisionMustAdvance,
        geometry.hashing.validateTopologyRevisionTransition(
            std.testing.allocator,
            loaded.definition(),
            &connectivity_definition,
        ),
    );
    connectivity_definition.topology_identity.revision += 1;
    try geometry.hashing.validateTopologyRevisionTransition(
        std.testing.allocator,
        loaded.definition(),
        &connectivity_definition,
    );

    var revision_only = loaded.definition().*;
    revision_only.topology_identity.revision += 1;
    try std.testing.expectError(
        error.UnchangedTopologyRevision,
        geometry.hashing.validateTopologyRevisionTransition(
            std.testing.allocator,
            loaded.definition(),
            &revision_only,
        ),
    );

    var reordered_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer reordered_arena.deinit();
    var reordered = try cloneForMutation(reordered_arena.allocator(), loaded.definition());
    std.mem.reverse(geometry.schema.Mesh, @constCast(reordered.meshes));
    for (@constCast(reordered.meshes)) |*mesh| {
        std.mem.reverse(geometry.schema.Vertex, @constCast(mesh.vertices));
        std.mem.reverse(geometry.schema.QuadFace, @constCast(mesh.faces));
    }
    const reordered_bytes = try geometry.serialization.serializeAlloc(std.testing.allocator, geometry.normalization.normalize(&reordered));
    defer std.testing.allocator.free(reordered_bytes);
    try std.testing.expectEqualSlices(u8, baseline_source.canonical_bytes, reordered_bytes);
}

test "canonical JSON round trip is byte stable and newline free" {
    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);
    var loaded = try loadValid(context);
    defer loaded.deinit();
    const first = try geometry.serialization.serializeAlloc(std.testing.allocator, loaded.normalized());
    defer std.testing.allocator.free(first);
    try std.testing.expect(first.len > 0);
    try std.testing.expectEqual(@as(u8, '}'), first[first.len - 1]);
    try std.testing.expect(first[first.len - 1] != '\n');

    var reparsed = try geometry.parsing.parse(std.testing.allocator, first);
    defer reparsed.deinit();
    var report = try geometry.validation.validateAlloc(std.testing.allocator, &reparsed.value, context);
    defer report.deinit();
    try std.testing.expect(report.isValid());
    const second = try geometry.serialization.serializeAlloc(
        std.testing.allocator,
        geometry.normalization.normalize(&reparsed.value),
    );
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
}

test "surface charts reject overlap and UV overlap requires an explicit shared group" {
    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);
    var loaded = try loadValid(context);
    defer loaded.deinit();

    var surface_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer surface_arena.deinit();
    var surface_overlap = try cloneForMutation(surface_arena.allocator(), loaded.definition());
    const surface_meshes: []geometry.schema.Mesh = @constCast(surface_overlap.meshes);
    const receiver_face = surface_meshes[0].faces[0];
    const module_face = &@constCast(surface_meshes[1].faces)[0];
    module_face.primary_surface_id = receiver_face.primary_surface_id;
    module_face.surface_coordinates = receiver_face.surface_coordinates;
    var surface_report = try geometry.validation.validateAlloc(std.testing.allocator, &surface_overlap, context);
    defer surface_report.deinit();
    try std.testing.expect(hasDiagnostic(surface_report, .invalid_surface_coordinate));

    var uv_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer uv_arena.deinit();
    var uv_overlap = try cloneForMutation(uv_arena.allocator(), loaded.definition());
    const uv_meshes: []geometry.schema.Mesh = @constCast(uv_overlap.meshes);
    const receiver_uv = uv_meshes[0].faces[0].texture_coordinates;
    const module_uv_face = &@constCast(uv_meshes[1].faces)[0];
    module_uv_face.texture_coordinates = receiver_uv;
    var uv_report = try geometry.validation.validateAlloc(std.testing.allocator, &uv_overlap, context);
    defer uv_report.deinit();
    try std.testing.expect(hasDiagnostic(uv_report, .invalid_texture_uv));

    const overlap_group = try geometry.identity.OverlapGroupId.init("synthetic_intentional_overlap");
    for (&@constCast(uv_meshes[0].faces)[0].texture_coordinates) |*corner| corner.overlap_group_id = overlap_group;
    for (&module_uv_face.texture_coordinates) |*corner| corner.overlap_group_id = overlap_group;
    var declared_report = try geometry.validation.validateAlloc(std.testing.allocator, &uv_overlap, context);
    defer declared_report.deinit();
    try std.testing.expect(!hasDiagnostic(declared_report, .invalid_texture_uv));
}

test "deterministic triangulation and Catmull-Clark level one preserve semantic provenance" {
    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);
    var loaded = try loadValid(context);
    defer loaded.deinit();
    const mesh = findMesh(loaded.definition(), "synthetic_receiver_patch") orelse return error.TestExpectedEqual;

    var triangles = try geometry.topology.triangulateAlloc(std.testing.allocator, mesh);
    defer triangles.deinit();
    try std.testing.expectEqual(@as(usize, 2), triangles.triangles.len);
    try std.testing.expectEqual(@as(u32, 10), triangles.triangles[0].vertex_ids[0].value);
    try std.testing.expectEqual(@as(u32, 30), triangles.triangles[1].vertex_ids[1].value);

    var subdivided = try geometry.topology.subdivideCatmullClarkLevel1Alloc(std.testing.allocator, mesh);
    defer subdivided.deinit();
    try std.testing.expectEqual(@as(u32, 1), subdivided.level);
    try std.testing.expectEqual(@as(usize, 9), subdivided.vertices.len);
    try std.testing.expectEqual(@as(usize, 4), subdivided.faces.len);
    try std.testing.expectEqual(@as(usize, 8), subdivided.boundary_edges.len);
    for (subdivided.faces) |face| {
        try std.testing.expect(face.primary_surface_id.eql(mesh.faces[0].primary_surface_id));
        try std.testing.expect(face.material_instance_id.eql(mesh.faces[0].material_instance_id));
        try std.testing.expectEqual(@as(u32, 7), face.source_face_id.value);
    }

    const no_subdivision_mesh = findMesh(loaded.definition(), "synthetic_module_patch") orelse return error.TestExpectedEqual;
    try std.testing.expectError(
        error.SubdivisionPolicyNone,
        geometry.topology.subdivideCatmullClarkLevel1Alloc(std.testing.allocator, no_subdivision_mesh),
    );
}

test "small closed quad surface validates and subdivides without derived boundaries" {
    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);
    var loaded = try loadValid(context);
    defer loaded.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var closed = try makeClosedCube(arena.allocator(), loaded.definition());

    var report = try geometry.validation.validateAlloc(std.testing.allocator, &closed, context);
    defer report.deinit();
    try std.testing.expect(report.isValid());
    const mesh = &closed.meshes[0];
    var subdivided = try geometry.topology.subdivideCatmullClarkLevel1Alloc(std.testing.allocator, mesh);
    defer subdivided.deinit();
    try std.testing.expectEqual(@as(usize, 26), subdivided.vertices.len);
    try std.testing.expectEqual(@as(usize, 24), subdivided.faces.len);
    try std.testing.expectEqual(@as(usize, 0), subdivided.boundary_edges.len);
}

test "loader safety limit is explicit and configurable" {
    const source = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        valid_fixture_path,
        std.testing.allocator,
        .limited(1024 * 1024),
    );
    defer std.testing.allocator.free(source);
    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);
    var report: ?geometry.diagnostics.OwnedReport = null;
    try std.testing.expectError(
        error.GeometrySourceTooLarge,
        geometry.loader.loadBytes(
            std.testing.allocator,
            source,
            context,
            .{ .maximum_source_bytes = source.len - 1 },
            &report,
        ),
    );
    try std.testing.expect(report == null);
    try std.testing.expectEqual(@as(usize, 128 * 1024 * 1024), geometry.loader.default_maximum_source_bytes);
}

test "authoring parser is strict about unknown fields and malformed JSON" {
    const source = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        valid_fixture_path,
        std.testing.allocator,
        .limited(1024 * 1024),
    );
    defer std.testing.allocator.free(source);
    const prefix = "{\"unknown_field\":0,";
    const unknown = try std.testing.allocator.alloc(u8, prefix.len + source.len - 1);
    defer std.testing.allocator.free(unknown);
    @memcpy(unknown[0..prefix.len], prefix);
    @memcpy(unknown[prefix.len..], source[1..]);
    try std.testing.expectError(error.UnknownField, geometry.parsing.parse(std.testing.allocator, unknown));
    try std.testing.expect(source.len >= 2 and source[source.len - 1] == '\n');
    try std.testing.expectError(error.InvalidJson, geometry.parsing.parse(std.testing.allocator, source[0 .. source.len - 2]));
}

test "file-backed invalid fixture matrix fails closed with deterministic diagnostics" {
    const fixture_names = [_][]const u8{
        "01_schema_identity.json",
        "02_structural_hash.json",
        "03_duplicate_vertex_id.json",
        "04_allocation_cursor.json",
        "05_vertex_reference.json",
        "06_duplicate_face_vertex.json",
        "07_degenerate_quad.json",
        "08_inconsistent_winding.json",
        "09_non_manifold_edge.json",
        "10_unexpected_boundary.json",
        "11_missing_surface.json",
        "12_missing_owning_region.json",
        "13_unknown_material.json",
        "14_surface_coordinate.json",
        "15_texture_uv.json",
        "16_seam_loop.json",
        "17_geometry_binding.json",
        "18_module_interface.json",
        "19_proxy_dimensions.json",
    };

    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);
    var loaded = try loadValid(context);
    defer loaded.deinit();

    for (fixture_names) |fixture_name| {
        const path = try std.fmt.allocPrint(
            std.testing.allocator,
            "tests/fixtures/canonical_geometry/invalid/{s}",
            .{fixture_name},
        );
        defer std.testing.allocator.free(path);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(
            std.testing.io,
            path,
            std.testing.allocator,
            .limited(4096),
        );
        defer std.testing.allocator.free(bytes);
        var parsed_descriptor = try std.json.parseFromSlice(InvalidDescriptor, std.testing.allocator, bytes, .{});
        defer parsed_descriptor.deinit();

        var mutation_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer mutation_arena.deinit();
        var invalid = try cloneForMutation(mutation_arena.allocator(), loaded.definition());
        try applyMutation(mutation_arena.allocator(), &invalid, parsed_descriptor.value.mutation);

        var first = try geometry.validation.validateAlloc(std.testing.allocator, &invalid, context);
        defer first.deinit();
        var second = try geometry.validation.validateAlloc(std.testing.allocator, &invalid, context);
        defer second.deinit();
        try std.testing.expect(!first.isValid());
        try std.testing.expect(hasDiagnostic(first, parsed_descriptor.value.expected_code));
        try expectReportsEqual(first, second);
    }
}

test "allocator-backed diagnostics do not truncate a large deterministic failure set" {
    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);
    var loaded = try loadValid(context);
    defer loaded.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var invalid = try cloneForMutation(arena.allocator(), loaded.definition());
    const mesh = &@constCast(invalid.meshes)[0];
    const vertices = try arena.allocator().alloc(geometry.schema.Vertex, 65);
    for (vertices) |*vertex| vertex.* = mesh.vertices[0];
    mesh.vertices = vertices;
    mesh.next_vertex_id = vertices[0].vertex_id.value + 1;

    var report = try geometry.validation.validateAlloc(std.testing.allocator, &invalid, context);
    defer report.deinit();
    try std.testing.expectEqual(@as(usize, 2080), countDiagnostic(report, .duplicate_vertex_id));
    try std.testing.expect(report.diagnostics.len >= 2080);
}

test "public loader returns owned diagnostics instead of accepting incompatible geometry" {
    var human = try human_support.load();
    defer human.deinit();
    const context = try structuralContext(&human);
    var loaded = try loadValid(context);
    defer loaded.deinit();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var invalid = try cloneForMutation(arena.allocator(), loaded.definition());
    invalid.structural_compatibility.normalized_source_sha256.bytes[0] ^= 0xff;
    const source = try geometry.serialization.serializeAlloc(std.testing.allocator, geometry.normalization.normalize(&invalid));
    defer std.testing.allocator.free(source);

    var report: ?geometry.diagnostics.OwnedReport = null;
    defer if (report) |*owned| owned.deinit();
    try std.testing.expectError(
        error.InvalidGeometrySource,
        geometry.loader.loadBytes(std.testing.allocator, source, context, .{}, &report),
    );
    try std.testing.expect(report != null);
    try std.testing.expect(hasDiagnostic(report.?, .structural_compatibility_mismatch));
    try std.testing.expectEqualStrings("geometry_definition", report.?.diagnostics[0].object_type);
    try std.testing.expect(report.?.diagnostics[0].message.len > 0);
}

fn loadValid(context: geometry.validation.StructuralContext) !geometry.loader.LoadedGeometry {
    var report: ?geometry.diagnostics.OwnedReport = null;
    errdefer if (report) |*owned| owned.deinit();
    return geometry.loader.loadFile(
        std.testing.allocator,
        std.testing.io,
        valid_fixture_path,
        context,
        .{},
        &report,
    );
}

fn cloneForMutation(
    allocator: std.mem.Allocator,
    source: *const geometry.schema.GeometryDefinition,
) !geometry.schema.GeometryDefinition {
    var result = source.*;
    const meshes = try allocator.dupe(geometry.schema.Mesh, source.meshes);
    for (meshes, source.meshes) |*destination, original| {
        destination.vertices = try allocator.dupe(geometry.schema.Vertex, original.vertices);
        destination.faces = try allocator.dupe(geometry.schema.QuadFace, original.faces);
        destination.boundary_loops = try allocator.dupe(geometry.schema.BoundaryLoop, original.boundary_loops);
    }
    result.meshes = meshes;
    result.face_sets = try allocator.dupe(geometry.schema.FaceSet, source.face_sets);
    result.seam_bindings = try allocator.dupe(geometry.schema.GeometrySeamBinding, source.seam_bindings);
    result.geometry_bindings = try allocator.dupe(geometry.schema.GeometryBinding, source.geometry_bindings);
    result.module_interfaces = try allocator.dupe(geometry.schema.ModuleInterface, source.module_interfaces);
    result.collision_proxies = try allocator.dupe(geometry.schema.CollisionProxy, source.collision_proxies);
    return result;
}

fn makeClosedCube(
    allocator: std.mem.Allocator,
    source: *const geometry.schema.GeometryDefinition,
) !geometry.schema.GeometryDefinition {
    var result = source.*;
    result.asset_identity.geometry_asset_id = try geometry.identity.GeometryAssetId.init("synthetic_closed_cube_geometry");
    result.topology_identity.topology_id = try geometry.identity.TopologyId.init("synthetic_closed_cube_topology");
    result.topology_identity.revision = 1;
    result.face_sets = &.{};
    result.seam_bindings = &.{};
    result.geometry_bindings = &.{};
    result.module_interfaces = &.{};
    result.collision_proxies = &.{};

    const vertices = try allocator.alloc(geometry.schema.Vertex, 8);
    const positions = [8]canonical.math3d.Vec3{
        .{ .x = -1, .y = -1, .z = -1 },
        .{ .x = 1, .y = -1, .z = -1 },
        .{ .x = 1, .y = 1, .z = -1 },
        .{ .x = -1, .y = 1, .z = -1 },
        .{ .x = -1, .y = -1, .z = 1 },
        .{ .x = 1, .y = -1, .z = 1 },
        .{ .x = 1, .y = 1, .z = 1 },
        .{ .x = -1, .y = 1, .z = 1 },
    };
    for (vertices, positions, 0..) |*vertex, position, index| vertex.* = .{
        .vertex_id = .{ .value = @intCast(index) },
        .position_m = position,
    };

    const connectivity = [6][4]u32{
        .{ 0, 3, 2, 1 },
        .{ 4, 5, 6, 7 },
        .{ 0, 1, 5, 4 },
        .{ 3, 7, 6, 2 },
        .{ 0, 4, 7, 3 },
        .{ 1, 2, 6, 5 },
    };
    const chart_names = [6][]const u8{
        "cube_back_chart",
        "cube_front_chart",
        "cube_bottom_chart",
        "cube_top_chart",
        "cube_left_chart",
        "cube_right_chart",
    };
    const island_names = [6][]const u8{
        "cube_back_island",
        "cube_front_island",
        "cube_bottom_island",
        "cube_top_island",
        "cube_left_island",
        "cube_right_island",
    };
    const faces = try allocator.alloc(geometry.schema.QuadFace, 6);
    const template = source.meshes[0].faces[0];
    for (faces, connectivity, chart_names, island_names, 0..) |*face, ids, chart_name, island_name, index| {
        face.* = template;
        face.face_id = .{ .value = @intCast(index) };
        for (ids, 0..) |vertex_id, corner| face.vertex_ids[corner] = .{ .value = vertex_id };
        const chart_id = try geometry.identity.ChartId.init(chart_name);
        const island_id = try geometry.identity.UvIslandId.init(island_name);
        for (&face.surface_coordinates) |*corner| corner.chart_id = chart_id;
        for (&face.texture_coordinates) |*corner| corner.uv_island_id = island_id;
    }

    const meshes = try allocator.alloc(geometry.schema.Mesh, 1);
    meshes[0] = .{
        .mesh_id = try geometry.identity.MeshId.init("synthetic_closed_cube"),
        .owner_component_ids = source.meshes[0].owner_component_ids,
        .next_vertex_id = 8,
        .next_face_id = 6,
        .connectivity_policy = .connected,
        .subdivision_policy = .catmull_clark_v1,
        .vertices = vertices,
        .faces = faces,
        .boundary_loops = &.{},
    };
    result.meshes = meshes;
    return result;
}

fn findMesh(definition: *const geometry.schema.GeometryDefinition, id: []const u8) ?*const geometry.schema.Mesh {
    for (definition.meshes) |*mesh| if (std.mem.eql(u8, mesh.mesh_id.value.bytes, id)) return mesh;
    return null;
}

const InvalidDescriptor = struct {
    fixture_id: []const u8,
    mutation: Mutation,
    expected_code: geometry.diagnostics.Code,
};

const Mutation = enum {
    schema_identity,
    structural_hash,
    duplicate_vertex_id,
    allocation_cursor,
    vertex_reference,
    duplicate_face_vertex,
    degenerate_quad,
    inconsistent_winding,
    non_manifold_edge,
    unexpected_boundary,
    missing_surface,
    missing_owning_region,
    unknown_material,
    surface_coordinate,
    texture_uv,
    seam_loop,
    geometry_binding,
    module_interface,
    proxy_dimensions,
};

fn applyMutation(
    allocator: std.mem.Allocator,
    definition: *geometry.schema.GeometryDefinition,
    mutation: Mutation,
) !void {
    const meshes: []geometry.schema.Mesh = @constCast(definition.meshes);
    const mesh = &meshes[0];
    const vertices: []geometry.schema.Vertex = @constCast(mesh.vertices);
    const faces: []geometry.schema.QuadFace = @constCast(mesh.faces);
    switch (mutation) {
        .schema_identity => definition.schema_identity.geometry_schema_id = try geometry.identity.GeometrySchemaId.init("incompatible_geometry_schema"),
        .structural_hash => definition.structural_compatibility.normalized_source_sha256.bytes[0] ^= 0xff,
        .duplicate_vertex_id => vertices[1].vertex_id = vertices[0].vertex_id,
        .allocation_cursor => mesh.next_vertex_id = 40,
        .vertex_reference => faces[0].vertex_ids[1] = .{ .value = 999 },
        .duplicate_face_vertex => faces[0].vertex_ids[2] = faces[0].vertex_ids[1],
        .degenerate_quad => {
            const source = findMutableVertex(vertices, 20) orelse return error.TestExpectedEqual;
            const destination = findMutableVertex(vertices, 30) orelse return error.TestExpectedEqual;
            destination.position_m = source.position_m;
        },
        .inconsistent_winding => try appendSharedEdgeFaces(allocator, mesh, 1),
        .non_manifold_edge => try appendSharedEdgeFaces(allocator, mesh, 2),
        .unexpected_boundary => mesh.boundary_loops = &.{},
        .missing_surface => {
            faces[0].primary_surface_id = try canonical.identity.SurfaceId.init("unknown_surface");
            for (&faces[0].surface_coordinates) |*corner| corner.surface_id = faces[0].primary_surface_id;
        },
        .missing_owning_region => faces[0].region_ids = try allocator.dupe(canonical.identity.RegionId, &.{try canonical.identity.RegionId.init("chest")}),
        .unknown_material => faces[0].material_instance_id = try canonical.identity.MaterialInstanceId.init("unknown_material"),
        .surface_coordinate => faces[0].surface_coordinates[0].coordinate.x = 1.25,
        .texture_uv => faces[0].texture_coordinates[0].uv.y = -0.25,
        .seam_loop => @constCast(definition.seam_bindings)[0].is_closed = false,
        .geometry_binding => @constCast(definition.geometry_bindings)[0].interaction_site_id = try canonical.identity.InteractionSiteId.init("chest_support_site"),
        .module_interface => @constCast(definition.module_interfaces)[0].module_mesh_id = try geometry.identity.MeshId.init("unknown_module_mesh"),
        .proxy_dimensions => @constCast(definition.collision_proxies)[0].dimensions.radius_m = -0.25,
    }
}

fn appendSharedEdgeFaces(allocator: std.mem.Allocator, mesh: *geometry.schema.Mesh, additional_face_count: usize) !void {
    const old_vertices = mesh.vertices;
    const vertices = try allocator.alloc(geometry.schema.Vertex, old_vertices.len + additional_face_count * 2);
    @memcpy(vertices[0..old_vertices.len], old_vertices);
    for (0..additional_face_count) |index| {
        const base_id: u32 = @intCast(50 + index * 20);
        const y: f32 = -1.0 - @as(f32, @floatFromInt(index));
        vertices[old_vertices.len + index * 2] = .{
            .vertex_id = .{ .value = base_id },
            .position_m = .{ .x = 1, .y = y, .z = 0 },
        };
        vertices[old_vertices.len + index * 2 + 1] = .{
            .vertex_id = .{ .value = base_id + 10 },
            .position_m = .{ .x = 0, .y = y, .z = 0 },
        };
    }
    mesh.vertices = vertices;
    mesh.next_vertex_id = if (additional_face_count == 1) 61 else 81;

    const old_faces = mesh.faces;
    const faces = try allocator.alloc(geometry.schema.QuadFace, old_faces.len + additional_face_count);
    @memcpy(faces[0..old_faces.len], old_faces);
    for (0..additional_face_count) |index| {
        const base_id: u32 = @intCast(50 + index * 20);
        var added = old_faces[0];
        added.face_id = .{ .value = @intCast(8 + index) };
        added.vertex_ids = .{ .{ .value = 10 }, .{ .value = 20 }, .{ .value = base_id }, .{ .value = base_id + 10 } };
        faces[old_faces.len + index] = added;
    }
    mesh.faces = faces;
    mesh.next_face_id = @intCast(8 + additional_face_count);
}

fn findMutableVertex(vertices: []geometry.schema.Vertex, id: u32) ?*geometry.schema.Vertex {
    for (vertices) |*vertex| if (vertex.vertex_id.value == id) return vertex;
    return null;
}

fn hasDiagnostic(report: geometry.diagnostics.OwnedReport, expected: geometry.diagnostics.Code) bool {
    for (report.diagnostics) |diagnostic| if (diagnostic.code == expected) return true;
    return false;
}

fn countDiagnostic(report: geometry.diagnostics.OwnedReport, expected: geometry.diagnostics.Code) usize {
    var count: usize = 0;
    for (report.diagnostics) |diagnostic| if (diagnostic.code == expected) {
        count += 1;
    };
    return count;
}

fn expectReportsEqual(a: geometry.diagnostics.OwnedReport, b: geometry.diagnostics.OwnedReport) !void {
    try std.testing.expectEqual(a.diagnostics.len, b.diagnostics.len);
    for (a.diagnostics, b.diagnostics) |left, right| {
        try std.testing.expectEqual(left.code, right.code);
        try std.testing.expectEqualStrings(left.object_type, right.object_type);
        try expectOptionalStringsEqual(left.object_id, right.object_id);
        try expectOptionalStringsEqual(left.property, right.property);
        try expectOptionalStringsEqual(left.reference_type, right.reference_type);
        try expectOptionalStringsEqual(left.reference_id, right.reference_id);
        try std.testing.expectEqualStrings(left.message, right.message);
    }
}

fn expectOptionalStringsEqual(a: ?[]const u8, b: ?[]const u8) !void {
    try std.testing.expectEqual(a == null, b == null);
    if (a) |left| try std.testing.expectEqualStrings(left, b.?);
}

fn structuralContext(human: *const canonical.human_base.LoadedHumanBase) !geometry.validation.StructuralContext {
    const canonical_bytes = try canonical.serialization.serializeAlloc(std.testing.allocator, human.normalized());
    defer std.testing.allocator.free(canonical_bytes);
    const digest = geometry.hashing.hashBytes(canonical_bytes);
    try std.testing.expectEqualStrings(accepted_structural_hash_hex, &digest.toHex());
    return .{
        .definition = human.definition(),
        .normalized_coordinate_contract = human.normalized_coordinate_contract,
        .normalized_source_sha256 = digest,
    };
}
