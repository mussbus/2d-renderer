const std = @import("std");
const canonical_geometry = @import("canonical_geometry");
const human_geometry = @import("canonical_human_geometry");

const evidence_directory = "assets/canonical_model/human_base/geometry/evidence/prompt_2c_r3_hm08_neutral_adaptation";

test "current authority preserves the Prompt 2C-R3 accepted topology-v2 contract" {
    var loaded = try human_geometry.authority.loadAuthoritative(std.testing.allocator, std.testing.io);
    defer loaded.deinit();
    const definition = loaded.definition();
    const mesh = human_geometry.analysis.findMainBody(definition) orelse return error.TestExpectedEqual;

    try std.testing.expectEqual(@as(u32, 4), definition.topology_identity.revision);
    try std.testing.expect(definition.topology_identity.compatibility_version.eql(.{ .major = 2, .minor = 0, .patch = 0 }));
    try std.testing.expectEqual(@as(usize, 13_380), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 13_378), mesh.faces.len);
    try std.testing.expectEqual(@as(u32, 13_380), mesh.next_vertex_id);
    try std.testing.expectEqual(@as(u32, 13_378), mesh.next_face_id);
    try std.testing.expectEqual(@as(usize, 11), definition.seam_bindings.len);
    try std.testing.expectEqual(@as(usize, 35), definition.geometry_bindings.len);

    const quality = try human_geometry.analysis.qualityMetricsAlloc(std.testing.allocator, mesh);
    try std.testing.expectEqual(@as(usize, 0), quality.boundary_edge_count);
    try std.testing.expectEqual(@as(usize, 0), quality.non_manifold_edge_count);
    try std.testing.expectEqual(@as(usize, 0), quality.degenerate_quad_count);
    try std.testing.expectEqual(@as(usize, 320), quality.extraordinary_vertex_count);
    try std.testing.expectEqual(@as(usize, 86), quality.quad_aspect_ratio_over_8_count);
    try std.testing.expectApproxEqAbs(@as(f64, 14.088067850133468), quality.quad_aspect_ratio.maximum, @as(f64, 0.00001));

    const measurements = try human_geometry.analysis.measurements(mesh);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), measurements.overall.minimum.y, @as(f32, 0.000001));
    try std.testing.expectApproxEqAbs(@as(f32, 1.8288), measurements.overall.maximum.y, @as(f32, 0.000001));
    try std.testing.expect(try human_geometry.analysis.bilateralSymmetryValidAlloc(std.testing.allocator, mesh));

    const topology = try canonical_geometry.hashing.topologyHashAlloc(std.testing.allocator, definition);
    const triangulation = try canonical_geometry.hashing.triangulationHashAlloc(std.testing.allocator, definition);
    try std.testing.expectEqualStrings("335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191", &topology.toHex());
    try std.testing.expectEqualStrings("967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444", &triangulation.toHex());
}

test "Prompt 2C-R3 landmark evidence separates surface registration from internal offsets" {
    const report = try readEvidence(evidence_directory ++ "/human_base_main_body_r3_report.json", 256 * 1024);
    defer std.testing.allocator.free(report);
    try expectContains(report, "\"shape_only\": true");
    try expectContains(report, "\"topology_edit_count\": 0");
    try expectContains(report, "\"over_8_count\": 86");
    try expectContains(report, "\"surface_correspondence\"");
    try expectContains(report, "\"count\": 18");
    try expectContains(report, "\"maximum_m\": 0.020506918213832742");
    try expectContains(report, "\"internal_structural_reference\"");
    try expectContains(report, "\"count\": 17");
    try expectContains(report, "\"binding_requires_review_count\": 0");

    const landmarks = try readEvidence(evidence_directory ++ "/human_base_main_body_r3_landmark_bindings.tsv", 64 * 1024);
    defer std.testing.allocator.free(landmarks);
    try std.testing.expectEqual(@as(usize, 36), countLines(landmarks));
    try std.testing.expectEqual(@as(usize, 18), countOccurrences(landmarks, "SURFACE_CORRESPONDENCE"));
    try std.testing.expectEqual(@as(usize, 17), countOccurrences(landmarks, "INTERNAL_STRUCTURAL_REFERENCE"));
    try std.testing.expectEqual(@as(usize, 0), countOccurrences(landmarks, "BINDING_REQUIRES_REVIEW"));
}

test "Prompt 2C-R3 evidence preserves integrity determinism and carried receiver work" {
    const intersections = try readEvidence(evidence_directory ++ "/human_base_main_body_r3_self_intersection.json", 16 * 1024);
    defer std.testing.allocator.free(intersections);
    try expectContains(intersections, "\"status\": \"completed\"");
    try expectContains(intersections, "\"detected_nonadjacent_triangle_intersection_count\": 0");

    const determinism = try readEvidence(evidence_directory ++ "/r3_five_run_determinism.txt", 16 * 1024);
    defer std.testing.allocator.free(determinism);
    try std.testing.expectEqual(@as(usize, 5), countOccurrences(determinism, "run_1_candidate_authoring_sha256=") +
        countOccurrences(determinism, "run_2_candidate_authoring_sha256=") +
        countOccurrences(determinism, "run_3_candidate_authoring_sha256=") +
        countOccurrences(determinism, "run_4_candidate_authoring_sha256=") +
        countOccurrences(determinism, "run_5_candidate_authoring_sha256="));
    try std.testing.expect(std.mem.endsWith(u8, determinism, "result=PASS\n"));

    const retopology = try readEvidence(evidence_directory ++ "/r3_local_retopology_disposition.tsv", 16 * 1024);
    defer std.testing.allocator.free(retopology);
    try std.testing.expectEqual(@as(usize, 7), countLines(retopology));
    try std.testing.expectEqual(@as(usize, 6), countOccurrences(retopology, "CARRIED_FORWARD"));
    try expectContains(retopology, "final module-interface loop work remains Prompt 2E");
}

test "Prompt 2C-R3 persistent owner-review images are complete" {
    const index = try readEvidence(evidence_directory ++ "/r3_visual_index.json", 32 * 1024);
    defer std.testing.allocator.free(index);
    try expectContains(index, "35a7ab3c433795bcd47975050a5f7ee74a72c43ba3c5d754f9ebbce7886716f7");
    try expectContains(index, "7354f67a78000abf4cad63177a492e45ee72a993a9d0a17b5b6ec7c8b1861417");
    try std.testing.expectEqual(@as(usize, 43), countOccurrences(index, ".png"));

    for ([_][]const u8{
        "mobile_sheets/prompt_2c_r3_mobile_sheet_a_whole_body.png",
        "mobile_sheets/prompt_2c_r3_mobile_sheet_b_topology.png",
        "mobile_sheets/prompt_2c_r3_mobile_sheet_c_anatomy.png",
        "comparisons/t3_vs_r3_whole_body.png",
        "comparisons/t3_vs_r3_head.png",
        "comparisons/t3_vs_r3_shoulder.png",
        "comparisons/t3_vs_r3_breast_torso.png",
        "comparisons/t3_vs_r3_hand.png",
        "comparisons/t3_vs_r3_pelvis.png",
        "comparisons/t3_vs_r3_knee.png",
        "comparisons/t3_vs_r3_ankle.png",
        "comparisons/t3_vs_r3_foot.png",
    }) |relative_path| {
        var path_buffer: [320]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ evidence_directory, relative_path });
        const png = try readEvidence(path, 20 * 1024 * 1024);
        defer std.testing.allocator.free(png);
        try std.testing.expect(png.len > 8);
        try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", png[0..8]);
    }
}

test "Blender candidate export requires explicit authorization for position edits" {
    const bridge = try readEvidence("tools/blender_bridge/bridge.py", 512 * 1024);
    defer std.testing.allocator.free(bridge);
    try expectContains(bridge, "--allow-position-edits");
    try expectContains(bridge, "round-trip f32 position changed for VertexId");
    const wrapper = try readEvidence("tools/blender_bridge.ps1", 128 * 1024);
    defer std.testing.allocator.free(wrapper);
    try expectContains(wrapper, "[switch]$AllowPositionEdits");
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
