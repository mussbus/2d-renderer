const std = @import("std");

test "Prompt 2C-R1 is retained as historical superseded evidence after the topology reset" {
    const report = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "assets/canonical_model/human_base/geometry/evidence/prompt_2c_r1/human_base_main_body_r1_report.txt",
        std.testing.allocator,
        .limited(2 * 1024 * 1024),
    );
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "topology_revision=3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "vertices=11506\nquads=11504") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "authoring_sha256=e501458b9cf78991aa4290bcecd81ebcc5cb112d4c735c2a9e0a381653766623") != null);
}

test "original Prompt 2C report and visual inventory remain preserved historical evidence" {
    const evidence_directory = "assets/canonical_model/human_base/geometry/evidence/prompt_2c";
    const report_path = evidence_directory ++ "/human_base_main_body_refinement_report.txt";
    const report = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, report_path, std.testing.allocator, .limited(512 * 1024));
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "M03 PROMPT 2C HUMAN MAIN-BODY") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "topology_revision=2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "vertices=11506\nquads=11504\nderived_triangles=23008") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "prompt_2c_critical_face_sets=39") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "prompt_2c_deformation_loops=55") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "quality unique_edges=") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "landmark_error_max_m=") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "self_intersections=0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "prompt_2d_started=false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "m04_started=false") != null);

    const image_names = [_][]const u8{
        "front",
        "back",
        "left",
        "right",
        "three_quarter",
        "wireframe_front",
        "wireframe_side",
        "surface_front",
        "closeup_face_shape",
        "closeup_face_wireframe",
        "closeup_eyelids",
        "closeup_nose_lips",
        "closeup_shoulder_armpit",
        "closeup_torso_breast_shape",
        "closeup_torso_breast_wireframe",
        "closeup_hand_thumb_fingers",
        "closeup_pelvis_perineal_front",
        "closeup_pelvis_glutes_back",
        "closeup_knee",
        "closeup_ankle",
        "closeup_foot_toes_shape",
        "closeup_foot_toes_wireframe",
    };
    for (image_names) |name| {
        var path_buffer: [256]u8 = undefined;
        const ppm_path = try std.fmt.bufPrint(&path_buffer, "{s}/human_base_main_body_{s}.ppm", .{ evidence_directory, name });
        const ppm = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, ppm_path, std.testing.allocator, .limited(1_024 * 1_024));
        defer std.testing.allocator.free(ppm);
        try std.testing.expect(std.mem.startsWith(u8, ppm, "P6\n480 600\n255\n"));

        var png_path_buffer: [256]u8 = undefined;
        const png_path = try std.fmt.bufPrint(&png_path_buffer, "{s}/human_base_main_body_{s}.png", .{ evidence_directory, name });
        const png = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, png_path, std.testing.allocator, .limited(1_024 * 1_024));
        defer std.testing.allocator.free(png);
        try std.testing.expect(png.len > 8);
        try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", png[0..8]);
    }

    try expectPng(evidence_directory ++ "/human_base_main_body_owner_review_contact_sheet.png", 16 * 1_024 * 1_024);
    try expectDerivedObj(evidence_directory ++ "/human_base_main_body_quad.obj", 4 * 1_024 * 1_024);
    try expectDerivedObj(evidence_directory ++ "/human_base_main_body_triangulated.obj", 4 * 1_024 * 1_024);
}

test "Prompt 2C-R1 report and high-fidelity visual inventory match the current authority" {
    const evidence_directory = "assets/canonical_model/human_base/geometry/evidence/prompt_2c_r1";
    const report_path = evidence_directory ++ "/human_base_main_body_r1_report.txt";
    const report = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, report_path, std.testing.allocator, .limited(2 * 1024 * 1024));
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "M03 PROMPT 2C-R1 TARGETED ANATOMICAL AND DEFORMATION-TOPOLOGY EVIDENCE") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "topology_revision=3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next_face_id=14598") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "vertices=11506\nquads=11504\nderived_triangles=23008") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "prompt_2c_r1_topology_delta_faces_added=218") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "quality quad_aspect_ratio_over_8=396") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "self_intersections=0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "quality unique_edges=23008 boundary_edges=0 non_manifold_edges=0 degenerate_quads=0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "landmark_error_max_m=0.09541839144313213") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "deformation_loop id=prompt_2c_eye_left_deformation_loop_01") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "deformation_region face_set=prompt_2c_shoulder_left_zone_faces_01") != null);

    const image_names = [_][]const u8{
        "front_smooth",
        "back_smooth",
        "left_smooth",
        "right_smooth",
        "front_three_quarter_smooth",
        "wireframe_front",
        "wireframe_side",
        "semantic_surface_front",
        "head_front_smooth",
        "head_side_smooth",
        "face_wireframe",
        "eye_eyelid_topology",
        "nose_lips_chin_jaw",
        "ear_head_transition",
        "shoulder_armpit_smooth",
        "shoulder_armpit_wireframe",
        "torso_front",
        "torso_side",
        "breast_nipple_areola_smooth",
        "breast_nipple_areola_wireframe",
        "hand_palm",
        "hand_back",
        "thumb_base",
        "finger_topology",
        "hand_wireframe",
        "pelvis_front",
        "glutes_back",
        "pelvis_glute_wireframe",
        "groin_perineal_base",
        "thigh_groin_aspect_region",
        "knee_front",
        "knee_side",
        "calf_ankle_achilles",
        "foot_side",
        "foot_top",
        "foot_toe_wireframe",
        "forefoot_aspect_region",
    };
    for (image_names) |name| {
        var path_buffer: [256]u8 = undefined;
        const ppm_path = try std.fmt.bufPrint(&path_buffer, "{s}/human_base_main_body_{s}.ppm", .{ evidence_directory, name });
        const ppm = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, ppm_path, std.testing.allocator, .limited(8 * 1024 * 1024));
        defer std.testing.allocator.free(ppm);
        try std.testing.expect(std.mem.startsWith(u8, ppm, "P6\n1440 1800\n255\n"));

        var png_path_buffer: [256]u8 = undefined;
        const png_path = try std.fmt.bufPrint(&png_path_buffer, "{s}/human_base_main_body_{s}.png", .{ evidence_directory, name });
        try expectPng(png_path, 4 * 1024 * 1024);
    }

    try expectPng(evidence_directory ++ "/human_base_main_body_r1_owner_review_contact_sheet.png", 16 * 1024 * 1024);
    try expectDerivedObj(evidence_directory ++ "/human_base_main_body_quad.obj", 4 * 1024 * 1024);
    try expectDerivedObj(evidence_directory ++ "/human_base_main_body_triangulated.obj", 4 * 1024 * 1024);
}

fn expectPng(path: []const u8, limit: usize) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(limit));
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(bytes.len > 8);
    try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", bytes[0..8]);
}

fn expectDerivedObj(path: []const u8, limit: usize) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(limit));
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(std.mem.startsWith(u8, bytes, "# DERIVED"));
}
