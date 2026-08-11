const std = @import("std");
const canonical_geometry = @import("canonical_geometry");
const human_geometry = @import("canonical_human_geometry");

test "current file-backed human main body preserves the accepted Prompt 2B scaffold contracts" {
    var loaded = try human_geometry.authority.loadAuthoritative(std.testing.allocator, std.testing.io);
    defer loaded.deinit();
    const definition = loaded.definition();

    try std.testing.expectEqualStrings(human_geometry.analysis.geometry_asset_id, definition.asset_identity.geometry_asset_id.value.bytes);
    try std.testing.expectEqualStrings(human_geometry.analysis.topology_id, definition.topology_identity.topology_id.value.bytes);
    try std.testing.expectEqual(@as(usize, 1), definition.meshes.len);
    try std.testing.expect(definition.topology_identity.revision >= 1);
    try std.testing.expectEqual(@as(usize, 0), definition.collision_proxies.len);
    try std.testing.expectEqual(@as(usize, 0), definition.module_interfaces.len);

    const mesh = human_geometry.analysis.findMainBody(definition) orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(canonical_geometry.schema.SubdivisionPolicy.catmull_clark_v1, mesh.subdivision_policy);
    try std.testing.expect(mesh.vertices.len >= 2000);
    try std.testing.expect(mesh.faces.len >= 2000);
    try std.testing.expect(mesh.next_vertex_id > mesh.vertices[mesh.vertices.len - 1].vertex_id.value);
    try std.testing.expect(mesh.next_face_id > mesh.faces[mesh.faces.len - 1].face_id.value);
    try std.testing.expectEqual(@as(usize, 0), mesh.boundary_loops.len);
    try std.testing.expectEqual(@as(usize, 1), try human_geometry.analysis.connectedComponentCountAlloc(std.testing.allocator, mesh));
    try std.testing.expect(try human_geometry.analysis.bilateralSymmetryValidAlloc(std.testing.allocator, mesh));
    try std.testing.expect(human_geometry.analysis.broadSurfaceCoverageValid(mesh));
    try std.testing.expect(human_geometry.analysis.seamSemanticsValid(definition, mesh));
    try std.testing.expect(human_geometry.analysis.receiverInterfaceValid(definition));
    // The HM08 topology-reset checkpoint binds every landmark, while exact
    // pose/shape registration remains an explicit Prompt 2C-R3 tuning task.
    try std.testing.expectEqual(loaded.structuralDefinition().landmarks.len, definition.geometry_bindings.len);

    const measurements = try human_geometry.analysis.measurements(mesh);
    try std.testing.expectApproxEqAbs(@as(f32, 0), measurements.overall.minimum.y, @as(f32, @floatCast(human_geometry.analysis.locked_extent_tolerance_m)));
    try std.testing.expectApproxEqAbs(human_geometry.analysis.canonical_height_m, measurements.overall.maximum.y, @as(f32, @floatCast(human_geometry.analysis.locked_extent_tolerance_m)));
    try std.testing.expectApproxEqAbs(-measurements.overall.minimum.x, measurements.overall.maximum.x, @as(f32, @floatCast(human_geometry.analysis.symmetry_tolerance_m)));
    try expectPositiveBounds(measurements.chest);
    try expectPositiveBounds(measurements.waist);
    try expectPositiveBounds(measurements.hip_glute);
    try expectPositiveBounds(measurements.head);
    try expectPositiveBounds(measurements.arms);
    try expectPositiveBounds(measurements.hands);
    try expectPositiveBounds(measurements.legs);
    try expectPositiveBounds(measurements.feet);

    var first_source = try canonical_geometry.hashing.sourceHashAlloc(std.testing.allocator, loaded.geometry.normalized());
    defer first_source.deinit();
    var second_source = try canonical_geometry.hashing.sourceHashAlloc(std.testing.allocator, loaded.geometry.normalized());
    defer second_source.deinit();
    try std.testing.expect(first_source.geometry_source_sha256.eql(second_source.geometry_source_sha256));
    try std.testing.expectEqualSlices(u8, first_source.canonical_bytes, second_source.canonical_bytes);
    try std.testing.expect(first_source.canonical_bytes.len > 1_000_000);
    try std.testing.expectEqual(@as(u8, '}'), first_source.canonical_bytes[first_source.canonical_bytes.len - 1]);

    const topology_a = try canonical_geometry.hashing.topologyHashAlloc(std.testing.allocator, definition);
    const topology_b = try canonical_geometry.hashing.topologyHashAlloc(std.testing.allocator, definition);
    try std.testing.expect(topology_a.eql(topology_b));
    const triangulation_a = try canonical_geometry.hashing.triangulationHashAlloc(std.testing.allocator, definition);
    const triangulation_b = try canonical_geometry.hashing.triangulationHashAlloc(std.testing.allocator, definition);
    try std.testing.expect(triangulation_a.eql(triangulation_b));

    var triangulated = try canonical_geometry.topology.triangulateAlloc(std.testing.allocator, mesh);
    defer triangulated.deinit();
    try std.testing.expectEqual(mesh.faces.len * 2, triangulated.triangles.len);

    var subdivided = try canonical_geometry.topology.subdivideCatmullClarkLevel1Alloc(std.testing.allocator, mesh);
    defer subdivided.deinit();
    try std.testing.expectEqual(@as(u32, 1), subdivided.level);
    try std.testing.expectEqual(mesh.faces.len * 4, subdivided.faces.len);
    try std.testing.expectEqual(@as(usize, 0), subdivided.boundary_edges.len);
}

test "accepted Prompt 2B scaffold evidence remains frozen as historical derived evidence" {
    const report_path = "assets/canonical_model/human_base/geometry/evidence/prompt_2b/human_base_main_body_scaffold_report.txt";
    const report = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, report_path, std.testing.allocator, .limited(64 * 1024));
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "authoring_sha256=23ba78843920eae23053c9654add7b05e67822d0e627963e0af1aed4e019b898") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "geometry_source_sha256=d3000ce3eadb200d6468b1b47ad0cc129b418b81ef22f0a973238bc1d7851fae") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "control_topology_sha256=0637911b42c167f3dc05bbc3e8aac01224d6b035fd79a9e159f7c567ec96ccad") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "triangulation_sha256=486c58345505bf6f84d8c205a77fcbd4937e15ae257586f29c89b44845598af5") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "neutral_geometry_signature=3bd042c1b0fac4e3d59d31f409b5087078835cc04f27fc7aab9db6745fe38895") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "vertices=2878\nquads=2876\nderived_triangles=5752") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "self_intersections=0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "prompt_2c_started=false") != null);

    const image_names = [_][]const u8{
        "front",
        "back",
        "left",
        "right",
        "three_quarter",
        "wireframe_front",
        "wireframe_side",
        "surface_front",
        "closeup_face",
        "closeup_hand",
        "closeup_foot",
        "closeup_torso_breast",
        "closeup_pelvis_perineal",
    };
    for (image_names) |name| {
        var path_buffer: [256]u8 = undefined;
        const ppm_path = try std.fmt.bufPrint(&path_buffer, "assets/canonical_model/human_base/geometry/evidence/prompt_2b/human_base_main_body_{s}.ppm", .{name});
        const ppm = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, ppm_path, std.testing.allocator, .limited(512 * 1024));
        defer std.testing.allocator.free(ppm);
        try std.testing.expect(std.mem.startsWith(u8, ppm, "P6\n320 400\n255\n"));

        var png_path_buffer: [256]u8 = undefined;
        const png_path = try std.fmt.bufPrint(&png_path_buffer, "assets/canonical_model/human_base/geometry/evidence/prompt_2b/human_base_main_body_{s}.png", .{name});
        const png = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, png_path, std.testing.allocator, .limited(128 * 1024));
        defer std.testing.allocator.free(png);
        try std.testing.expect(png.len > 8);
        try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", png[0..8]);
    }

    const quad_obj = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "assets/canonical_model/human_base/geometry/evidence/prompt_2b/human_base_main_body_quad.obj",
        std.testing.allocator,
        .limited(512 * 1024),
    );
    defer std.testing.allocator.free(quad_obj);
    try std.testing.expect(std.mem.startsWith(u8, quad_obj, "# DERIVED"));
}

fn expectPositiveBounds(bounds: human_geometry.analysis.Bounds3) !void {
    try std.testing.expect(bounds.width() > 0);
    try std.testing.expect(bounds.height() > 0);
    try std.testing.expect(bounds.depth() > 0);
}
