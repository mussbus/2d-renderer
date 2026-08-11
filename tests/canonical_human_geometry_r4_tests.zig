const std = @import("std");
const canonical_geometry = @import("canonical_geometry");
const human_geometry = @import("canonical_human_geometry");

const evidence_directory = "assets/canonical_model/human_base/geometry/evidence/prompt_2c_r4_final_neutral";
const expected_authority_sha256 = "4bed342c289f1f1238c7397c524b63e32d2037737cde08304fe5c47af1b43b8f";
const expected_normalized_sha256 = "d7fee949a5ee70c926f19dc46615fa965fa2d75176ba1fc0ea4e02d50aa9b096";
const expected_topology_sha256 = "335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191";
const expected_triangulation_sha256 = "967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444";
const expected_neutral_signature = "31beb6c39ffdcfd6ae009c1b416b7c78a000230ca5ce11de6e2f01dd150022f7";

test "Prompt 2C-R4 promotes the reviewed shape-only authority" {
    var loaded = try human_geometry.authority.loadAuthoritative(std.testing.allocator, std.testing.io);
    defer loaded.deinit();
    const definition = loaded.definition();
    const mesh = human_geometry.analysis.findMainBody(definition) orelse return error.TestExpectedEqual;

    const authoring = try readEvidence(human_geometry.authority.authoritative_geometry_path, 64 * 1024 * 1024);
    defer std.testing.allocator.free(authoring);
    const authoring_hash = canonical_geometry.hashing.hashBytes(authoring);
    try std.testing.expectEqualStrings(expected_authority_sha256, &authoring_hash.toHex());

    var source = try canonical_geometry.hashing.sourceHashAlloc(std.testing.allocator, loaded.geometry.normalized());
    defer source.deinit();
    const topology = try canonical_geometry.hashing.topologyHashAlloc(std.testing.allocator, definition);
    const triangulation = try canonical_geometry.hashing.triangulationHashAlloc(std.testing.allocator, definition);
    const neutral = try canonical_geometry.hashing.neutralSignatureAlloc(
        std.testing.allocator,
        definition,
        loaded.structural_sha256,
        source.geometry_source_sha256,
        topology,
    );
    try std.testing.expectEqualStrings(expected_normalized_sha256, &source.geometry_source_sha256.toHex());
    try std.testing.expectEqualStrings(expected_topology_sha256, &topology.toHex());
    try std.testing.expectEqualStrings(expected_triangulation_sha256, &triangulation.toHex());
    try std.testing.expectEqualStrings(expected_neutral_signature, &neutral.toHex());
    try std.testing.expectEqualStrings(
        "b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda",
        &loaded.structural_sha256.toHex(),
    );

    try std.testing.expectEqual(@as(u32, 4), definition.topology_identity.revision);
    try std.testing.expectEqual(@as(usize, 13_380), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 13_378), mesh.faces.len);
    try std.testing.expectEqual(@as(u32, 13_380), mesh.next_vertex_id);
    try std.testing.expectEqual(@as(u32, 13_378), mesh.next_face_id);
}

test "Prompt 2C-R4 preserves topology integrity height ground and symmetry" {
    var loaded = try human_geometry.authority.loadAuthoritative(std.testing.allocator, std.testing.io);
    defer loaded.deinit();
    const mesh = human_geometry.analysis.findMainBody(loaded.definition()) orelse return error.TestExpectedEqual;
    const quality = try human_geometry.analysis.qualityMetricsAlloc(std.testing.allocator, mesh);

    try std.testing.expectEqual(@as(usize, 1), try human_geometry.analysis.connectedComponentCountAlloc(std.testing.allocator, mesh));
    try std.testing.expect(try human_geometry.analysis.bilateralSymmetryValidAlloc(std.testing.allocator, mesh));
    try std.testing.expectEqual(@as(usize, 0), quality.boundary_edge_count);
    try std.testing.expectEqual(@as(usize, 0), quality.non_manifold_edge_count);
    try std.testing.expectEqual(@as(usize, 0), quality.degenerate_quad_count);
    try std.testing.expectEqual(@as(usize, 320), quality.extraordinary_vertex_count);
    try std.testing.expectEqual(@as(usize, 86), quality.quad_aspect_ratio_over_8_count);
    try std.testing.expectApproxEqAbs(@as(f64, 14.088067850133468), quality.quad_aspect_ratio.maximum, @as(f64, 0.00001));
    try std.testing.expect(quality.quad_aspect_ratio.percentile_95 < 4.95);
    try std.testing.expect(quality.quad_aspect_ratio.percentile_99 < 7.21);

    const measured = try human_geometry.analysis.measurements(mesh);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), measured.overall.minimum.y, @as(f32, 0.000001));
    try std.testing.expectApproxEqAbs(@as(f32, 1.8288), measured.overall.maximum.y, @as(f32, 0.000001));
}

test "Prompt 2C-R4 evidence proves neutral shape adaptation and landmark separation" {
    const report = try readEvidence(evidence_directory ++ "/human_base_main_body_r4_report.json", 512 * 1024);
    defer std.testing.allocator.free(report);
    for ([_][]const u8{
        expected_authority_sha256,
        expected_normalized_sha256,
        expected_topology_sha256,
        expected_triangulation_sha256,
        expected_neutral_signature,
        "\"connectivity_changes\": 0",
        "\"non_position_semantic_identity_equal_to_r3\": true",
        "\"over_8_count\": 86",
        "\"r4_created_outliers\": 0",
        "\"neutrality_classification\": \"SLIGHT_FEMALE_LEAN\"",
    }) |needle| try expectContains(report, needle);

    const landmarks = try readEvidence(evidence_directory ++ "/human_base_main_body_r4_landmark_bindings.tsv", 64 * 1024);
    defer std.testing.allocator.free(landmarks);
    try std.testing.expectEqual(@as(usize, 36), countLines(landmarks));
    try std.testing.expectEqual(@as(usize, 18), countOccurrences(landmarks, "SURFACE_CORRESPONDENCE"));
    try std.testing.expectEqual(@as(usize, 17), countOccurrences(landmarks, "INTERNAL_STRUCTURAL_REFERENCE"));

    const adaptation = try readEvidence(evidence_directory ++ "/human_base_main_body_r4_adaptation.json", 32 * 1024);
    defer std.testing.allocator.free(adaptation);
    try expectContains(adaptation, "\"shape_only\": true");
    try expectContains(adaptation, "\"moved_vertex_count\": 2709");
    try expectContains(adaptation, "\"topology_edit_count\": 0");
}

test "Prompt 2C-R4 evidence proves zero detected self intersections" {
    const intersections = try readEvidence(evidence_directory ++ "/human_base_main_body_r4_self_intersection.json", 32 * 1024);
    defer std.testing.allocator.free(intersections);
    try expectContains(intersections, "\"status\": \"completed\"");
    try expectContains(intersections, "\"detected_nonadjacent_triangle_intersection_count\": 0");
}

test "Prompt 2C-R4 persistent owner-review package is complete" {
    const index = try readEvidence(evidence_directory ++ "/r4_visual_index.json", 32 * 1024);
    defer std.testing.allocator.free(index);
    try expectContains(index, expected_authority_sha256);
    try expectContains(index, expected_normalized_sha256);
    try expectContains(index, expected_topology_sha256);
    try std.testing.expectEqual(@as(usize, 43), countOccurrences(index, ".png"));

    for ([_][]const u8{
        "mobile_sheets/prompt_2c_r4_mobile_sheet_a_neutrality.png",
        "mobile_sheets/prompt_2c_r4_mobile_sheet_b_topology.png",
        "mobile_sheets/prompt_2c_r4_mobile_sheet_c_anatomy.png",
        "comparisons/r3_vs_r4_front.png",
        "comparisons/r3_vs_r4_side.png",
        "comparisons/r3_vs_r4_back.png",
    }) |relative_path| {
        var path_buffer: [320]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ evidence_directory, relative_path });
        const png = try readEvidence(path, 20 * 1024 * 1024);
        defer std.testing.allocator.free(png);
        try std.testing.expect(png.len > 8);
        try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", png[0..8]);
    }
}

fn readEvidence(path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(limit));
}

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) != null);
}

fn countLines(bytes: []const u8) usize {
    return std.mem.count(u8, bytes, "\n");
}

fn countOccurrences(bytes: []const u8, needle: []const u8) usize {
    return std.mem.count(u8, bytes, needle);
}
