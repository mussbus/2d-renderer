const std = @import("std");
const canonical_geometry = @import("canonical_geometry");
const human_geometry = @import("canonical_human_geometry");

const expected_authoring_sha256 = "4bed342c289f1f1238c7397c524b63e32d2037737cde08304fe5c47af1b43b8f";
const expected_normalized_sha256 = "d7fee949a5ee70c926f19dc46615fa965fa2d75176ba1fc0ea4e02d50aa9b096";
const expected_topology_sha256 = "335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191";
const expected_triangulation_sha256 = "967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444";
const expected_neutral_signature = "31beb6c39ffdcfd6ae009c1b416b7c78a000230ca5ce11de6e2f01dd150022f7";

const deformation_zones = [_][]const u8{
    "eye_left",            "eye_right",          "lips",                "mouth_corner_left",  "mouth_corner_right",
    "shoulder_left",       "shoulder_right",     "breast_root_left",    "breast_root_right",  "elbow_left",
    "elbow_right",         "wrist_left",         "wrist_right",         "thumb_base_left",    "thumb_base_right",
    "finger_index_left",   "finger_middle_left", "finger_ring_left",    "finger_little_left", "finger_index_right",
    "finger_middle_right", "finger_ring_right",  "finger_little_right", "groin_thigh_left",   "groin_thigh_right",
    "glute_fold_left",     "glute_fold_right",   "knee_left",           "knee_right",         "ankle_left",
    "ankle_right",         "forefoot_left",      "forefoot_right",      "toe_big_left",       "toe_index_left",
    "toe_middle_left",     "toe_ring_left",      "toe_little_left",     "toe_big_right",      "toe_index_right",
    "toe_middle_right",    "toe_ring_right",     "toe_little_right",
};

test "HM08 adoption establishes the authorized topology-v2 element namespace" {
    var loaded = try human_geometry.authority.loadAuthoritative(std.testing.allocator, std.testing.io);
    defer loaded.deinit();
    const definition = loaded.definition();
    const mesh = human_geometry.analysis.findMainBody(definition) orelse return error.TestExpectedEqual;

    try std.testing.expectEqualStrings("human_base_main_body", mesh.mesh_id.value.bytes);
    try std.testing.expectEqualStrings("human_base_topology", definition.topology_identity.topology_id.value.bytes);
    try std.testing.expect(definition.topology_identity.compatibility_version.eql(.{ .major = 2, .minor = 0, .patch = 0 }));
    try std.testing.expectEqual(@as(u32, 4), definition.topology_identity.revision);
    try std.testing.expectEqual(@as(usize, 13_380), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 13_378), mesh.faces.len);
    try std.testing.expectEqual(@as(u32, 13_380), mesh.next_vertex_id);
    try std.testing.expectEqual(@as(u32, 13_378), mesh.next_face_id);
    for (mesh.vertices, 0..) |vertex, index| try std.testing.expectEqual(@as(u32, @intCast(index)), vertex.vertex_id.value);
    for (mesh.faces, 0..) |face, index| try std.testing.expectEqual(@as(u32, @intCast(index)), face.face_id.value);
}

test "HM08-derived current authority identities and structural bindings match the promoted candidate" {
    var loaded = try human_geometry.authority.loadAuthoritative(std.testing.allocator, std.testing.io);
    defer loaded.deinit();
    const definition = loaded.definition();

    const authoring = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        human_geometry.authority.authoritative_geometry_path,
        std.testing.allocator,
        .limited(canonical_geometry.loader.default_maximum_source_bytes),
    );
    defer std.testing.allocator.free(authoring);
    const authoring_hash = canonical_geometry.hashing.hashBytes(authoring);
    try std.testing.expectEqualStrings(expected_authoring_sha256, &authoring_hash.toHex());

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
    try std.testing.expectEqual(@as(usize, 11), definition.seam_bindings.len);
    try std.testing.expectEqual(@as(usize, 35), definition.geometry_bindings.len);
    try std.testing.expectEqual(@as(usize, 44), definition.face_sets.len);
    try std.testing.expectEqual(@as(usize, 44), definition.topology_loops.len);
}

test "HM08-derived current authority is closed, symmetric, all-quad, and retains the qualified topology quality" {
    var loaded = try human_geometry.authority.loadAuthoritative(std.testing.allocator, std.testing.io);
    defer loaded.deinit();
    const definition = loaded.definition();
    const mesh = human_geometry.analysis.findMainBody(definition) orelse return error.TestExpectedEqual;
    const quality = try human_geometry.analysis.qualityMetricsAlloc(std.testing.allocator, mesh);

    try std.testing.expectEqual(@as(usize, 1), try human_geometry.analysis.connectedComponentCountAlloc(std.testing.allocator, mesh));
    try std.testing.expect(try human_geometry.analysis.bilateralSymmetryValidAlloc(std.testing.allocator, mesh));
    try std.testing.expectEqual(@as(usize, 0), quality.boundary_edge_count);
    try std.testing.expectEqual(@as(usize, 0), quality.non_manifold_edge_count);
    try std.testing.expectEqual(@as(usize, 0), quality.degenerate_quad_count);
    try std.testing.expectEqual(@as(usize, 26_756), quality.derived_triangle_count);
    try std.testing.expectEqual(@as(usize, 320), quality.extraordinary_vertex_count);
    try std.testing.expectEqual(@as(usize, 164), quality.valence_three_count);
    try std.testing.expectEqual(@as(usize, 13_060), quality.valence_four_count);
    try std.testing.expectEqual(@as(usize, 156), quality.valence_five_count);
    try std.testing.expectEqual(@as(usize, 0), quality.other_valence_count);
    try std.testing.expectEqual(@as(usize, 86), quality.quad_aspect_ratio_over_8_count);
    try std.testing.expect(quality.quad_aspect_ratio.percentile_95 < 4.95);
    try std.testing.expect(quality.quad_aspect_ratio.percentile_99 < 7.21);
    try std.testing.expect(quality.quad_aspect_ratio.maximum < 14.09);

    const measurements = try human_geometry.analysis.measurements(mesh);
    try std.testing.expectApproxEqAbs(@as(f32, 0), measurements.overall.minimum.y, @as(f32, 0.000001));
    try std.testing.expectApproxEqAbs(@as(f32, 1.8288), measurements.overall.maximum.y, @as(f32, 0.000001));
    try std.testing.expectEqual(@as(usize, 0), definition.module_interfaces.len);
    try std.testing.expectEqual(@as(usize, 0), definition.collision_proxies.len);
}

test "HM08 adoption maps every face and exposes source-derived deformation zones" {
    var loaded = try human_geometry.authority.loadAuthoritative(std.testing.allocator, std.testing.io);
    defer loaded.deinit();
    const definition = loaded.definition();
    const mesh = human_geometry.analysis.findMainBody(definition) orelse return error.TestExpectedEqual;

    for (mesh.faces) |face| {
        try std.testing.expect(face.region_ids.len > 0);
        try std.testing.expectEqualStrings("hm08_provisional_imported_uv", face.texture_coordinates[0].texture_space_id.value.bytes);
        for (face.surface_coordinates, face.texture_coordinates) |surface_corner, texture_corner| {
            try std.testing.expectEqualStrings(face.primary_surface_id.value.bytes, surface_corner.surface_id.value.bytes);
            try std.testing.expect(!std.mem.eql(u8, surface_corner.chart_id.value.bytes, texture_corner.uv_island_id.value.bytes));
        }
    }
    try std.testing.expect(human_geometry.analysis.broadSurfaceCoverageValid(mesh));
    try std.testing.expect(human_geometry.analysis.seamSemanticsValid(definition, mesh));
    try std.testing.expect(human_geometry.analysis.receiverInterfaceValid(definition));
    for (deformation_zones) |zone| {
        var face_set_buffer: [128]u8 = undefined;
        const face_set_id = try std.fmt.bufPrint(&face_set_buffer, "prompt_2c_t3_{s}_zone_faces_01", .{zone});
        try std.testing.expect(hasFaceSet(definition, face_set_id));
        var loop_buffer: [128]u8 = undefined;
        const loop_id = try std.fmt.bufPrint(&loop_buffer, "prompt_2c_t3_{s}_deformation_loop_01", .{zone});
        try std.testing.expect(hasTopologyLoop(definition, loop_id));
    }
}

test "HM08 adoption evidence preserves provenance, semantic classifications, and five-run proof" {
    const evidence_directory = "assets/canonical_model/human_base/geometry/evidence/prompt_2c_t3_hm08_adoption";
    const manifest = try readEvidence(evidence_directory ++ "/hm08_t3_adoption_manifest.json", 256 * 1024);
    defer std.testing.allocator.free(manifest);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "437dd513888a92399d1d3200d2e80859fae55abc") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "bea00279464133e86b634220cd2774ebf3b470de280d11222a6b2269e4a8d950") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "5f3ab0cf6f7ebe92efe4b83213131c617d308d164eeefd5da230373640b0c226") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "HISTORICAL_SUPERSEDED_M03_R1_CANDIDATE") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "PROVISIONAL_IMPORTED_UV") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "OPEN_TUNING_PROVISIONAL_PER_FACE_CHARTS") != null);

    const semantics = try readEvidence(evidence_directory ++ "/hm08_t3_semantic_classification.tsv", 128 * 1024);
    defer std.testing.allocator.free(semantics);
    try std.testing.expectEqual(@as(usize, 417), countLines(semantics));
    for ([_][]const u8{ "DIRECT_MAPPING", "REGION_SPLIT", "LOCAL_RETOPOLOGY_REQUIRED", "MODULE_GEOMETRY_REQUIRED", "NOT_RENDERED_AT_THIS_STAGE" }) |classification| {
        try std.testing.expect(std.mem.indexOf(u8, semantics, classification) != null);
    }

    const determinism = try readEvidence(evidence_directory ++ "/hm08_t3_five_run_determinism.txt", 64 * 1024);
    defer std.testing.allocator.free(determinism);
    try std.testing.expectEqual(@as(usize, 5), countOccurrences(determinism, "candidate_authoring_sha256="));
    try std.testing.expect(std.mem.endsWith(u8, determinism, "result=PASS\n"));

    const round_trip = try readEvidence(evidence_directory ++ "/hm08_t3_blender_roundtrip.txt", 16 * 1024);
    defer std.testing.allocator.free(round_trip);
    try std.testing.expect(std.mem.indexOf(u8, round_trip, "canonical_semantic_identities_equal=true") != null);
}

fn hasFaceSet(definition: *const canonical_geometry.schema.GeometryDefinition, id: []const u8) bool {
    for (definition.face_sets) |face_set| if (std.mem.eql(u8, face_set.face_set_id.value.bytes, id)) return true;
    return false;
}

fn hasTopologyLoop(definition: *const canonical_geometry.schema.GeometryDefinition, id: []const u8) bool {
    for (definition.topology_loops) |loop| if (std.mem.eql(u8, loop.topology_loop_id.value.bytes, id) and loop.directed_edges.len >= 4) return true;
    return false;
}

fn readEvidence(path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(limit));
}

fn countLines(bytes: []const u8) usize {
    return std.mem.count(u8, bytes, "\n");
}

fn countOccurrences(bytes: []const u8, needle: []const u8) usize {
    return std.mem.count(u8, bytes, needle);
}
