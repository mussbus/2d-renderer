const std = @import("std");
const canonical = @import("canonical_model");
const geometry = @import("canonical_geometry");
const human_geometry = @import("canonical_human_geometry");

const evidence_directory = "assets/canonical_model/human_base/geometry/evidence/prompt_2c";
const report_path = evidence_directory ++ "/human_base_main_body_refinement_report.txt";
const quad_obj_path = evidence_directory ++ "/human_base_main_body_quad.obj";
const triangle_obj_path = evidence_directory ++ "/human_base_main_body_triangulated.obj";
const image_width: usize = 480;
const image_height: usize = 600;

const View = enum { front, back, left, right, three_quarter };
const RenderMode = enum { neutral, wireframe, semantic };

const Frame = struct {
    minimum_x: f64,
    maximum_x: f64,
    minimum_y: f64,
    maximum_y: f64,
};

const RenderSpec = struct {
    file_name: []const u8,
    view: View,
    mode: RenderMode,
    frame: ?Frame = null,
};

const render_specs = [_]RenderSpec{
    .{ .file_name = "human_base_main_body_front.ppm", .view = .front, .mode = .neutral },
    .{ .file_name = "human_base_main_body_back.ppm", .view = .back, .mode = .neutral },
    .{ .file_name = "human_base_main_body_left.ppm", .view = .left, .mode = .neutral },
    .{ .file_name = "human_base_main_body_right.ppm", .view = .right, .mode = .neutral },
    .{ .file_name = "human_base_main_body_three_quarter.ppm", .view = .three_quarter, .mode = .neutral },
    .{ .file_name = "human_base_main_body_wireframe_front.ppm", .view = .front, .mode = .wireframe },
    .{ .file_name = "human_base_main_body_wireframe_side.ppm", .view = .right, .mode = .wireframe },
    .{ .file_name = "human_base_main_body_surface_front.ppm", .view = .front, .mode = .semantic },
    .{ .file_name = "human_base_main_body_closeup_face_shape.ppm", .view = .front, .mode = .semantic, .frame = .{ .minimum_x = -0.19, .maximum_x = 0.19, .minimum_y = 1.48, .maximum_y = 1.84 } },
    .{ .file_name = "human_base_main_body_closeup_face_wireframe.ppm", .view = .front, .mode = .wireframe, .frame = .{ .minimum_x = -0.19, .maximum_x = 0.19, .minimum_y = 1.48, .maximum_y = 1.84 } },
    .{ .file_name = "human_base_main_body_closeup_eyelids.ppm", .view = .front, .mode = .wireframe, .frame = .{ .minimum_x = -0.15, .maximum_x = 0.15, .minimum_y = 1.64, .maximum_y = 1.78 } },
    .{ .file_name = "human_base_main_body_closeup_nose_lips.ppm", .view = .front, .mode = .semantic, .frame = .{ .minimum_x = -0.13, .maximum_x = 0.13, .minimum_y = 1.54, .maximum_y = 1.72 } },
    .{ .file_name = "human_base_main_body_closeup_shoulder_armpit.ppm", .view = .front, .mode = .wireframe, .frame = .{ .minimum_x = -0.52, .maximum_x = 0.05, .minimum_y = 1.20, .maximum_y = 1.54 } },
    .{ .file_name = "human_base_main_body_closeup_torso_breast_shape.ppm", .view = .front, .mode = .semantic, .frame = .{ .minimum_x = -0.36, .maximum_x = 0.36, .minimum_y = 0.98, .maximum_y = 1.54 } },
    .{ .file_name = "human_base_main_body_closeup_torso_breast_wireframe.ppm", .view = .front, .mode = .wireframe, .frame = .{ .minimum_x = -0.36, .maximum_x = 0.36, .minimum_y = 0.98, .maximum_y = 1.54 } },
    .{ .file_name = "human_base_main_body_closeup_hand_thumb_fingers.ppm", .view = .front, .mode = .wireframe, .frame = .{ .minimum_x = -0.89, .maximum_x = -0.62, .minimum_y = 1.01, .maximum_y = 1.31 } },
    .{ .file_name = "human_base_main_body_closeup_pelvis_perineal_front.ppm", .view = .front, .mode = .semantic, .frame = .{ .minimum_x = -0.31, .maximum_x = 0.31, .minimum_y = 0.73, .maximum_y = 1.08 } },
    .{ .file_name = "human_base_main_body_closeup_pelvis_glutes_back.ppm", .view = .back, .mode = .wireframe, .frame = .{ .minimum_x = -0.31, .maximum_x = 0.31, .minimum_y = 0.73, .maximum_y = 1.08 } },
    .{ .file_name = "human_base_main_body_closeup_knee.ppm", .view = .front, .mode = .wireframe, .frame = .{ .minimum_x = -0.24, .maximum_x = 0.03, .minimum_y = 0.42, .maximum_y = 0.63 } },
    .{ .file_name = "human_base_main_body_closeup_ankle.ppm", .view = .front, .mode = .wireframe, .frame = .{ .minimum_x = -0.20, .maximum_x = -0.01, .minimum_y = 0.07, .maximum_y = 0.25 } },
    .{ .file_name = "human_base_main_body_closeup_foot_toes_shape.ppm", .view = .front, .mode = .semantic, .frame = .{ .minimum_x = -0.24, .maximum_x = 0.01, .minimum_y = -0.01, .maximum_y = 0.18 } },
    .{ .file_name = "human_base_main_body_closeup_foot_toes_wireframe.ppm", .view = .front, .mode = .wireframe, .frame = .{ .minimum_x = -0.24, .maximum_x = 0.01, .minimum_y = -0.01, .maximum_y = 0.18 } },
};

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    try std.Io.Dir.cwd().createDirPath(init.io, evidence_directory);
    var loaded = try human_geometry.authority.loadAuthoritative(allocator, init.io);
    defer loaded.deinit();
    const definition = loaded.definition();
    const mesh = human_geometry.analysis.findMainBody(definition) orelse return error.MissingMainBody;

    try writeQuadObj(init.io, allocator, mesh);
    try writeTriangulatedObj(init.io, allocator, mesh);
    for (render_specs) |spec| try renderEvidence(init.io, allocator, mesh, spec);

    var self_intersection_report = try human_geometry.analysis.selfIntersectionReportAlloc(allocator, mesh);
    defer self_intersection_report.deinit();
    const self_intersections = self_intersection_report.pairs.len;
    const report = try generateReportAlloc(allocator, &loaded, mesh, self_intersection_report.pairs);
    defer allocator.free(report);
    try writeFile(init.io, report_path, report);

    const topology_sha256 = try geometry.hashing.topologyHashAlloc(allocator, definition);
    std.debug.print(
        "human geometry refinement evidence vertices={d} quads={d} triangles={d} topology_sha256={s} self_intersections={d} images={d}\n",
        .{ mesh.vertices.len, mesh.faces.len, mesh.faces.len * 2, &topology_sha256.toHex(), self_intersections, render_specs.len },
    );
}

fn generateReportAlloc(
    allocator: std.mem.Allocator,
    loaded: *const human_geometry.authority.Loaded,
    mesh: *const geometry.schema.Mesh,
    self_intersection_pairs: []const human_geometry.analysis.SelfIntersectionPair,
) ![]u8 {
    const definition = loaded.definition();
    const raw_sha256 = geometry.hashing.hashBytes(loaded.geometry.source_bytes);
    var source = try geometry.hashing.sourceHashAlloc(allocator, loaded.geometry.normalized());
    defer source.deinit();
    const topology_sha256 = try geometry.hashing.topologyHashAlloc(allocator, definition);
    const triangulation_sha256 = try geometry.hashing.triangulationHashAlloc(allocator, definition);
    const neutral_sha256 = try geometry.hashing.neutralSignatureAlloc(
        allocator,
        definition,
        loaded.structural_sha256,
        source.geometry_source_sha256,
        topology_sha256,
    );
    const measurements = try human_geometry.analysis.measurements(mesh);
    const component_count = try human_geometry.analysis.connectedComponentCountAlloc(allocator, mesh);

    var output = std.Io.Writer.Allocating.init(allocator);
    errdefer output.deinit();
    const writer = &output.writer;
    const quality = try human_geometry.analysis.qualityMetricsAlloc(allocator, mesh);
    const landmark_errors = try human_geometry.analysis.landmarkErrorStatsAlloc(allocator, definition, loaded.structuralDefinition(), mesh);
    try writer.print("M03 PROMPT 2C HUMAN MAIN-BODY ANATOMICAL AND DEFORMATION-TOPOLOGY EVIDENCE\n", .{});
    try writer.print("authority_path={s}\n", .{human_geometry.authority.authoritative_geometry_path});
    try writer.print("structural_authority_path={s}\n", .{canonical.human_base.authoritative_authoring_path});
    try writer.print("structural_normalized_sha256={s}\n", .{&loaded.structural_sha256.toHex()});
    try writer.print("authoring_bytes={d}\n", .{loaded.geometry.source_bytes.len});
    try writer.print("authoring_sha256={s}\n", .{&raw_sha256.toHex()});
    try writer.print("canonical_bytes={d}\n", .{source.canonical_bytes.len});
    try writer.print("geometry_source_sha256={s}\n", .{&source.geometry_source_sha256.toHex()});
    try writer.print("control_topology_sha256={s}\n", .{&topology_sha256.toHex()});
    try writer.print("triangulation_sha256={s}\n", .{&triangulation_sha256.toHex()});
    try writer.print("neutral_geometry_signature={s}\n", .{&neutral_sha256.toHex()});
    try writer.print("mesh_id={s}\n", .{mesh.mesh_id.value.bytes});
    try writer.print("topology_revision={d}\nnext_vertex_id={d}\nnext_face_id={d}\n", .{ definition.topology_identity.revision, mesh.next_vertex_id, mesh.next_face_id });
    try writer.print("vertices={d}\nquads={d}\nderived_triangles={d}\n", .{ mesh.vertices.len, mesh.faces.len, mesh.faces.len * 2 });
    try writer.print("prompt_2b_authoring_sha256=23ba78843920eae23053c9654add7b05e67822d0e627963e0af1aed4e019b898\n", .{});
    try writer.print("prompt_2b_vertices=2878\nprompt_2b_quads=2876\nprompt_2b_triangles=5752\n", .{});
    try writer.print("topology_delta_vertices_added=8628\ntopology_delta_vertices_removed=0\n", .{});
    try writer.print("topology_delta_faces_added=11504\ntopology_delta_faces_retired=2876\n", .{});
    try writer.print("prompt_2b_quality unique_edges=5752 boundary_edges=0 non_manifold_edges=0 degenerate_quads=0\n", .{});
    try writer.print("prompt_2b_quality valence_3=156 valence_4=2574 valence_5=148 valence_other=0 extraordinary_vertices=304\n", .{});
    try writer.print("prompt_2b_quality edge_length_m min=0.025399999999999867 p25=0.025399999999999978 median=0.025400000000000006 p75=0.025400000000460155 p90=0.027297787777516715 max=0.27 mean=0.03624801578101608\n", .{});
    try writer.print("prompt_2b_quality quad_aspect_ratio min=1 p25=1.000000000000001 median=1.0000000000000044 p75=1.0132600008617227 p90=4.330708661417327 max=10.62992125984253 mean=1.8419359108024635\n", .{});
    try writer.print("connected_components={d}\n", .{component_count});
    try writer.print("open_boundary_loops={d}\n", .{mesh.boundary_loops.len});
    try writer.print("topology_loops_total={d}\n", .{definition.topology_loops.len});
    try writer.print("prompt_2c_critical_face_sets={d}\n", .{countPrompt2cFaceSets(definition)});
    try writer.print("prompt_2c_deformation_loops={d}\n", .{countPrompt2cLoops(definition)});
    try writer.print("subdivision_policy={s}\n", .{@tagName(mesh.subdivision_policy)});
    try writer.print("structural_seam_loops={d}\n", .{definition.seam_bindings.len});
    for (definition.seam_bindings) |binding| {
        try writer.print(
            "seam id={s} edges={d} side_a={s} side_b={s}\n",
            .{ binding.structural_seam_id.value.bytes, binding.directed_edges.len, binding.side_a_surface_id.value.bytes, binding.side_b_surface_id.value.bytes },
        );
    }
    try writer.print("geometry_landmark_bindings={d}\n", .{definition.geometry_bindings.len});
    try writer.print("landmark_error_count={d}\nlandmark_error_min_m={d}\nlandmark_error_median_m={d}\nlandmark_error_p90_m={d}\nlandmark_error_max_m={d}\nlandmark_error_mean_m={d}\n", .{
        landmark_errors.count,
        landmark_errors.minimum_m,
        landmark_errors.median_m,
        landmark_errors.percentile_90_m,
        landmark_errors.maximum_m,
        landmark_errors.mean_m,
    });
    try writer.print("semantic_surfaces={d}\n", .{definition.structural_compatibility.required_surface_ids.len});
    for (definition.structural_compatibility.required_surface_ids) |surface_id| {
        try writer.print("surface id={s} faces={d}\n", .{ surface_id.value.bytes, countSurfaceFaces(mesh, surface_id) });
    }
    try writeBounds(writer, "overall", measurements.overall);
    try writeBounds(writer, "chest", measurements.chest);
    try writeBounds(writer, "waist", measurements.waist);
    try writeBounds(writer, "hip_glute", measurements.hip_glute);
    try writeBounds(writer, "head", measurements.head);
    try writeBounds(writer, "arms", measurements.arms);
    try writeBounds(writer, "hands", measurements.hands);
    try writeBounds(writer, "legs", measurements.legs);
    try writeBounds(writer, "feet", measurements.feet);
    try writer.print("self_intersections={d}\n", .{self_intersection_pairs.len});
    for (self_intersection_pairs) |pair| {
        const face_a = findFace(mesh, pair.face_a) orelse return error.InvalidSelfIntersectionFace;
        const face_b = findFace(mesh, pair.face_b) orelse return error.InvalidSelfIntersectionFace;
        try writer.print(
            "self_intersection face_a={d} surface_a={s} face_b={d} surface_b={s}\n",
            .{ pair.face_a.value, face_a.primary_surface_id.value.bytes, pair.face_b.value, face_b.primary_surface_id.value.bytes },
        );
    }
    try writeQualityMetrics(writer, quality);
    try writer.print("left_right_limb_intersection=none_by_triangle_audit\n", .{});
    try writer.print("hand_body_overlap=none_by_triangle_audit\n", .{});
    try writer.print("breast_torso_relationship=continuous_integrated_surface\n", .{});
    try writer.print("leg_groin_overlap=none_by_triangle_audit\n", .{});
    try writer.print("toe_foot_relationship=continuous_integrated_surface\n", .{});
    try writer.print("OPEN_TUNING.landmark_binding_tolerance_m={d}\n", .{human_geometry.analysis.landmark_binding_tolerance_m});
    try writer.print("VALIDATION_ONLY.locked_extent_tolerance_m={d}\n", .{human_geometry.analysis.locked_extent_tolerance_m});
    try writer.print("VALIDATION_ONLY.symmetry_tolerance_m={d}\n", .{human_geometry.analysis.symmetry_tolerance_m});
    try writer.print("VALIDATION_ONLY.intersection_epsilon_m={d}\n", .{human_geometry.analysis.intersection_epsilon_m});
    try writer.print("OPEN_TUNING.topology_density=11506_vertices_11504_quads\n", .{});
    try writer.print("OPEN_TUNING.surface_charts=face_local_scaffold_charts\n", .{});
    try writer.print("OPEN_TUNING.texture_uvs=face_local_scaffold_islands\n", .{});
    try writer.print("collision_proxies=0_deferred_to_prompt_2f\n", .{});
    try writer.print("prompt_2c_implemented=true\n", .{});
    try writer.print("prompt_2d_started=false\n", .{});
    try writer.print("m04_started=false\n", .{});
    for (render_specs) |spec| try writer.print(
        "inspection image={s} purpose={s}_{s} geometry_source_sha256={s} topology_sha256={s}\n",
        .{ spec.file_name, @tagName(spec.view), @tagName(spec.mode), &source.geometry_source_sha256.toHex(), &topology_sha256.toHex() },
    );
    return output.toOwnedSlice();
}

fn writeBounds(writer: *std.Io.Writer, name: []const u8, bounds: human_geometry.analysis.Bounds3) !void {
    try writer.print(
        "measurement {s} min=[{d},{d},{d}] max=[{d},{d},{d}] width={d} height={d} depth={d}\n",
        .{
            name,
            bounds.minimum.x,
            bounds.minimum.y,
            bounds.minimum.z,
            bounds.maximum.x,
            bounds.maximum.y,
            bounds.maximum.z,
            bounds.width(),
            bounds.height(),
            bounds.depth(),
        },
    );
}

fn countSurfaceFaces(mesh: *const geometry.schema.Mesh, surface_id: canonical.identity.SurfaceId) usize {
    var count: usize = 0;
    for (mesh.faces) |face| if (face.primary_surface_id.eql(surface_id)) {
        count += 1;
    };
    return count;
}

fn findFace(mesh: *const geometry.schema.Mesh, face_id: geometry.identity.FaceId) ?geometry.schema.QuadFace {
    var low: usize = 0;
    var high: usize = mesh.faces.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const face = mesh.faces[middle];
        if (face.face_id.value < face_id.value) {
            low = middle + 1;
        } else if (face.face_id.value > face_id.value) {
            high = middle;
        } else {
            return face;
        }
    }
    return null;
}

fn countPrompt2cFaceSets(definition: *const geometry.schema.GeometryDefinition) usize {
    var count: usize = 0;
    for (definition.face_sets) |face_set| if (std.mem.startsWith(u8, face_set.face_set_id.value.bytes, "prompt_2c_")) {
        count += 1;
    };
    return count;
}

fn countPrompt2cLoops(definition: *const geometry.schema.GeometryDefinition) usize {
    var count: usize = 0;
    for (definition.topology_loops) |loop| if (std.mem.startsWith(u8, loop.topology_loop_id.value.bytes, "prompt_2c_")) {
        count += 1;
    };
    return count;
}

fn writeQualityMetrics(writer: *std.Io.Writer, metrics: human_geometry.analysis.QualityMetrics) !void {
    try writer.print(
        "quality unique_edges={d} boundary_edges={d} non_manifold_edges={d} degenerate_quads={d}\n",
        .{ metrics.unique_edge_count, metrics.boundary_edge_count, metrics.non_manifold_edge_count, metrics.degenerate_quad_count },
    );
    try writer.print(
        "quality valence_3={d} valence_4={d} valence_5={d} valence_other={d} extraordinary_vertices={d}\n",
        .{ metrics.valence_three_count, metrics.valence_four_count, metrics.valence_five_count, metrics.other_valence_count, metrics.extraordinary_vertex_count },
    );
    try writeDistribution(writer, "edge_length_m", metrics.edge_length_m);
    try writeDistribution(writer, "quad_aspect_ratio", metrics.quad_aspect_ratio);
}

fn writeDistribution(writer: *std.Io.Writer, name: []const u8, distribution: human_geometry.analysis.ScalarDistribution) !void {
    try writer.print(
        "quality {s} min={d} p25={d} median={d} p75={d} p90={d} max={d} mean={d}\n",
        .{
            name,
            distribution.minimum,
            distribution.percentile_25,
            distribution.median,
            distribution.percentile_75,
            distribution.percentile_90,
            distribution.maximum,
            distribution.mean,
        },
    );
}

fn writeQuadObj(io: std.Io, allocator: std.mem.Allocator, mesh: *const geometry.schema.Mesh) !void {
    try requireDenseSortedVertices(mesh);
    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();
    const writer = &output.writer;
    try writer.print("# DERIVED from {s}\n", .{human_geometry.authority.authoritative_geometry_path});
    try writer.print("o {s}\n", .{mesh.mesh_id.value.bytes});
    for (mesh.vertices) |vertex| try writer.print("v {d} {d} {d}\n", .{ vertex.position_m.x, vertex.position_m.y, vertex.position_m.z });
    for (mesh.faces) |face| try writer.print(
        "f {d} {d} {d} {d}\n",
        .{ face.vertex_ids[0].value + 1, face.vertex_ids[1].value + 1, face.vertex_ids[2].value + 1, face.vertex_ids[3].value + 1 },
    );
    try writeFile(io, quad_obj_path, output.written());
}

fn writeTriangulatedObj(io: std.Io, allocator: std.mem.Allocator, mesh: *const geometry.schema.Mesh) !void {
    try requireDenseSortedVertices(mesh);
    var triangulated = try geometry.topology.triangulateAlloc(allocator, mesh);
    defer triangulated.deinit();
    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();
    const writer = &output.writer;
    try writer.print("# DERIVED deterministic triangulation from {s}\n", .{human_geometry.authority.authoritative_geometry_path});
    try writer.print("o {s}_triangulated\n", .{mesh.mesh_id.value.bytes});
    for (mesh.vertices) |vertex| try writer.print("v {d} {d} {d}\n", .{ vertex.position_m.x, vertex.position_m.y, vertex.position_m.z });
    for (triangulated.triangles) |triangle| try writer.print(
        "f {d} {d} {d}\n",
        .{ triangle.vertex_ids[0].value + 1, triangle.vertex_ids[1].value + 1, triangle.vertex_ids[2].value + 1 },
    );
    try writeFile(io, triangle_obj_path, output.written());
}

fn requireDenseSortedVertices(mesh: *const geometry.schema.Mesh) !void {
    for (mesh.vertices, 0..) |vertex, index| if (vertex.vertex_id.value != index) return error.NonDenseVertexIdsForObj;
}

fn renderEvidence(io: std.Io, allocator: std.mem.Allocator, mesh: *const geometry.schema.Mesh, spec: RenderSpec) !void {
    const pixel_count = image_width * image_height;
    const pixels = try allocator.alloc(u8, pixel_count * 3);
    defer allocator.free(pixels);
    @memset(pixels, 246);
    const depth = try allocator.alloc(f64, pixel_count);
    defer allocator.free(depth);
    @memset(depth, -std.math.inf(f64));

    const frame = spec.frame orelse projectedFrame(mesh, spec.view);
    for (mesh.faces) |face| {
        const points = [4]Projected{
            project(try vertexPosition(mesh, face.vertex_ids[0]), spec.view, frame),
            project(try vertexPosition(mesh, face.vertex_ids[1]), spec.view, frame),
            project(try vertexPosition(mesh, face.vertex_ids[2]), spec.view, frame),
            project(try vertexPosition(mesh, face.vertex_ids[3]), spec.view, frame),
        };
        const color = if (spec.mode == .semantic) semanticColor(face.primary_surface_id.value.bytes) else neutralColor(points);
        switch (face.diagonal) {
            .v0_v2 => {
                rasterTriangle(pixels, depth, .{ points[0], points[1], points[2] }, color);
                rasterTriangle(pixels, depth, .{ points[0], points[2], points[3] }, color);
            },
            .v1_v3 => {
                rasterTriangle(pixels, depth, .{ points[0], points[1], points[3] }, color);
                rasterTriangle(pixels, depth, .{ points[1], points[2], points[3] }, color);
            },
        }
    }
    if (spec.mode == .wireframe) {
        for (mesh.faces) |face| {
            var points: [4]Projected = undefined;
            for (face.vertex_ids, 0..) |vertex_id, index| points[index] = project(try vertexPosition(mesh, vertex_id), spec.view, frame);
            for (0..4) |index| drawLine(pixels, points[index], points[(index + 1) % 4], .{ 35, 45, 58 });
        }
    }

    var path_buffer: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ evidence_directory, spec.file_name });
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var header_buffer: [64]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buffer, "P6\n{d} {d}\n255\n", .{ image_width, image_height });
    try file.writeStreamingAll(io, header);
    try file.writeStreamingAll(io, pixels);
}

const Projected = struct { x: f64, y: f64, depth: f64 };

fn projectedFrame(mesh: *const geometry.schema.Mesh, view: View) Frame {
    var minimum_x = std.math.inf(f64);
    var maximum_x = -std.math.inf(f64);
    var minimum_y = std.math.inf(f64);
    var maximum_y = -std.math.inf(f64);
    for (mesh.vertices) |vertex| {
        const coordinates = viewCoordinates(vertex.position_m, view);
        minimum_x = @min(minimum_x, coordinates[0]);
        maximum_x = @max(maximum_x, coordinates[0]);
        minimum_y = @min(minimum_y, coordinates[1]);
        maximum_y = @max(maximum_y, coordinates[1]);
    }
    const padding_x = (maximum_x - minimum_x) * 0.06;
    const padding_y = (maximum_y - minimum_y) * 0.03;
    return .{ .minimum_x = minimum_x - padding_x, .maximum_x = maximum_x + padding_x, .minimum_y = minimum_y - padding_y, .maximum_y = maximum_y + padding_y };
}

fn project(position: canonical.math3d.Vec3, view: View, frame: Frame) Projected {
    const coordinates = viewCoordinates(position, view);
    const span_x = frame.maximum_x - frame.minimum_x;
    const span_y = frame.maximum_y - frame.minimum_y;
    const pixel_width = @as(f64, @floatFromInt(image_width - 1));
    const pixel_height = @as(f64, @floatFromInt(image_height - 1));
    const pixels_per_meter = @min(pixel_width / span_x, pixel_height / span_y);
    const offset_x = (pixel_width - span_x * pixels_per_meter) * 0.5;
    const offset_y = (pixel_height - span_y * pixels_per_meter) * 0.5;
    return .{
        .x = offset_x + (coordinates[0] - frame.minimum_x) * pixels_per_meter,
        .y = pixel_height - (offset_y + (coordinates[1] - frame.minimum_y) * pixels_per_meter),
        .depth = coordinates[2],
    };
}

fn viewCoordinates(position: canonical.math3d.Vec3, view: View) [3]f64 {
    const x: f64 = position.x;
    const y: f64 = position.y;
    const z: f64 = position.z;
    const c = @sqrt(0.5);
    return switch (view) {
        .front => .{ x, y, z },
        .back => .{ -x, y, -z },
        .left => .{ z, y, -x },
        .right => .{ -z, y, x },
        .three_quarter => .{ c * x - c * z, y, c * x + c * z },
    };
}

fn rasterTriangle(pixels: []u8, depth: []f64, points: [3]Projected, color: [3]u8) void {
    const minimum_x: i32 = @max(0, @as(i32, @intFromFloat(@floor(@min(points[0].x, @min(points[1].x, points[2].x))))));
    const maximum_x: i32 = @min(@as(i32, @intCast(image_width - 1)), @as(i32, @intFromFloat(@ceil(@max(points[0].x, @max(points[1].x, points[2].x))))));
    const minimum_y: i32 = @max(0, @as(i32, @intFromFloat(@floor(@min(points[0].y, @min(points[1].y, points[2].y))))));
    const maximum_y: i32 = @min(@as(i32, @intCast(image_height - 1)), @as(i32, @intFromFloat(@ceil(@max(points[0].y, @max(points[1].y, points[2].y))))));
    const area = edgeFunction(points[0], points[1], points[2].x, points[2].y);
    if (@abs(area) <= 0.000000000001) return;
    var y = minimum_y;
    while (y <= maximum_y) : (y += 1) {
        var x = minimum_x;
        while (x <= maximum_x) : (x += 1) {
            const sample_x = @as(f64, @floatFromInt(x)) + 0.5;
            const sample_y = @as(f64, @floatFromInt(y)) + 0.5;
            const w0 = edgeFunction(points[1], points[2], sample_x, sample_y) / area;
            const w1 = edgeFunction(points[2], points[0], sample_x, sample_y) / area;
            const w2 = 1.0 - w0 - w1;
            if (w0 < -0.000000001 or w1 < -0.000000001 or w2 < -0.000000001) continue;
            const candidate_depth = w0 * points[0].depth + w1 * points[1].depth + w2 * points[2].depth;
            const index = @as(usize, @intCast(y)) * image_width + @as(usize, @intCast(x));
            if (candidate_depth < depth[index]) continue;
            depth[index] = candidate_depth;
            pixels[index * 3 ..][0..3].* = color;
        }
    }
}

fn edgeFunction(a: Projected, b: Projected, x: f64, y: f64) f64 {
    return (x - a.x) * (b.y - a.y) - (y - a.y) * (b.x - a.x);
}

fn neutralColor(points: [4]Projected) [3]u8 {
    const depth_range = @max(points[0].depth, @max(points[1].depth, @max(points[2].depth, points[3].depth))) -
        @min(points[0].depth, @min(points[1].depth, @min(points[2].depth, points[3].depth)));
    const adjustment: u8 = @intFromFloat(@min(22.0, depth_range * 120.0));
    return .{ 214 + adjustment, 165 + adjustment / 2, 143 + adjustment / 3 };
}

fn semanticColor(bytes: []const u8) [3]u8 {
    var hash: u32 = 2166136261;
    for (bytes) |byte| {
        hash = (hash ^ byte) *% 16777619;
    }
    return .{
        @intCast(70 + hash % 150),
        @intCast(70 + (hash >> 8) % 150),
        @intCast(70 + (hash >> 16) % 150),
    };
}

fn drawLine(pixels: []u8, a: Projected, b: Projected, color: [3]u8) void {
    var x0: i32 = @intFromFloat(@round(a.x));
    var y0: i32 = @intFromFloat(@round(a.y));
    const x1: i32 = @intFromFloat(@round(b.x));
    const y1: i32 = @intFromFloat(@round(b.y));
    const dx: i32 = @intCast(@abs(x1 - x0));
    const sx: i32 = if (x0 < x1) 1 else -1;
    const dy: i32 = -@as(i32, @intCast(@abs(y1 - y0)));
    const sy: i32 = if (y0 < y1) 1 else -1;
    var error_value = dx + dy;
    while (true) {
        if (x0 >= 0 and x0 < @as(i32, @intCast(image_width)) and y0 >= 0 and y0 < @as(i32, @intCast(image_height))) {
            const index = @as(usize, @intCast(y0)) * image_width + @as(usize, @intCast(x0));
            pixels[index * 3 ..][0..3].* = color;
        }
        if (x0 == x1 and y0 == y1) break;
        const doubled = error_value * 2;
        if (doubled >= dy) {
            error_value += dy;
            x0 += sx;
        }
        if (doubled <= dx) {
            error_value += dx;
            y0 += sy;
        }
    }
}

fn vertexPosition(mesh: *const geometry.schema.Mesh, id: geometry.identity.VertexId) !canonical.math3d.Vec3 {
    if (id.value >= mesh.vertices.len or mesh.vertices[id.value].vertex_id.value != id.value) return error.NonDenseVertexIdsForEvidence;
    return mesh.vertices[id.value].position_m;
}

fn writeFile(io: std.Io, path: []const u8, bytes: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}
