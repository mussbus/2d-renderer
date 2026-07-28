const std = @import("std");
const math = @import("math");
const sprite = @import("sprite_batch");
const camera2d = @import("camera2d");
const image_decode = @import("image_decode");
const render_queue = @import("render_queue");
const wardrobe_catalog = @import("wardrobe_catalog");
const wardrobe_demo = @import("wardrobe_demo");
const visual = @import("visual_geometry");
const audit = @import("visual_geometry_audit");

test "alpha geometry ignores transparent padding and maps visible landmarks" {
    var pixels = [_]u8{0} ** (8 * 6 * 4);
    for (2..6) |x| {
        for (1..5) |y| pixels[(y * 8 + x) * 4 + 3] = 255;
    }
    const alpha = try visual.deriveAlphaGeometry(
        &pixels,
        8,
        6,
        8 * 4,
        .{ .x = 0, .y = 0, .width = 8, .height = 6 },
    );
    try std.testing.expectEqual(@as(u32, 2), alpha.opaque_bounds.x);
    try std.testing.expectEqual(@as(u32, 1), alpha.opaque_bounds.y);
    try std.testing.expectEqual(@as(u32, 4), alpha.visibleWidth());
    try std.testing.expectEqual(@as(u32, 4), alpha.visibleHeight());
    try std.testing.expectEqual(@as(u32, 16), alpha.opaque_count);
    const top_left = alpha.visibleUvToLocal(.{ 0, 0 });
    const bottom_right = alpha.visibleUvToLocal(.{ 1, 1 });
    try std.testing.expect(top_left[0] < bottom_right[0]);
    try std.testing.expect(top_left[1] > bottom_right[1]);
}

test "semantic landmarks use the production sprite transform and invert exactly" {
    const request = testRequest(.{
        .world_position = .{ 3.25, -1.5 },
        .rotation = 0.37,
        .scale = .{ -2.2, 0.8 },
        .pivot = .{ 0.23, 0.71 },
    });
    const local = [2]f32{ 0.82, 0.14 };
    const world = sprite.localPointToWorld(request, local);
    const recovered = try sprite.worldPointToLocal(request, world);
    try std.testing.expectApproxEqAbs(local[0], recovered[0], 0.00001);
    try std.testing.expectApproxEqAbs(local[1], recovered[1], 0.00001);
}

test "orientation control accepts aligned axes and rejects backwards axes" {
    const aligned = try visual.angleDegrees(
        .{ .x = 0, .y = 0 },
        .{ .x = 4, .y = 0 },
        .{ .x = 1, .y = 2 },
        .{ .x = 5, .y = 2 },
    );
    const backwards = try visual.angleDegrees(
        .{ .x = 0, .y = 0 },
        .{ .x = 4, .y = 0 },
        .{ .x = 5, .y = 2 },
        .{ .x = 1, .y = 2 },
    );
    try std.testing.expectApproxEqAbs(@as(f32, 0), aligned, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 180), backwards, 0.0001);

    var report = visual.Report{};
    try report.recordMaximum(.{
        .character_style = "fixture",
        .outfit = "controlled_orientation",
        .view = .front,
        .pose = "neutral",
        .component = "aligned_shoe",
        .side = .left,
        .metric = "axis_error",
        .actual = aligned,
        .unit = "deg",
        .outcome = .pass,
    }, 5);
    try report.recordMaximum(.{
        .character_style = "fixture",
        .outfit = "controlled_orientation",
        .view = .front,
        .pose = "neutral",
        .component = "backwards_shoe",
        .side = .right,
        .metric = "axis_error",
        .actual = backwards,
        .unit = "deg",
        .outcome = .pass,
    }, 5);
    try std.testing.expectEqual(visual.Outcome.pass, report.metrics[0].outcome);
    try std.testing.expectEqual(visual.Outcome.fail, report.metrics[1].outcome);
    try std.testing.expectEqual(@as(u32, 1), report.failure_count);
}

test "fit controls distinguish bounded good and undersized garment spans" {
    var report = visual.Report{};
    const base = visual.Metric{
        .character_style = "fixture",
        .outfit = "controlled_fit",
        .view = .front,
        .pose = "neutral",
        .component = "torso_garment",
        .side = .none,
        .metric = "shoulder_fit_ratio",
        .actual = 1.02,
        .unit = "ratio",
        .outcome = .pass,
    };
    try report.recordRange(base, 0.96, 1.08);
    var undersized = base;
    undersized.actual = 0.78;
    try report.recordRange(undersized, 0.96, 1.08);
    try std.testing.expectEqual(visual.Outcome.pass, report.metrics[0].outcome);
    try std.testing.expectEqual(visual.Outcome.fail, report.metrics[1].outcome);
}

test "joint continuity contracts retain strict distal seams and bounded root caps" {
    const elbow = visual.continuityContract(.upper_arm, .forearm);
    const knee = visual.continuityContract(.thigh, .shin);
    const shoulder = visual.continuityContract(.torso, .upper_arm);
    const hip = visual.continuityContract(.pelvis, .thigh);

    try std.testing.expectEqual(@as(f32, 5.0), elbow.maximum_overlap_px);
    try std.testing.expectEqual(@as(f32, 8.0), knee.maximum_overlap_px);
    try std.testing.expectEqual(@as(f32, 15.0), shoulder.maximum_overlap_px);
    try std.testing.expectEqual(@as(f32, 15.0), hip.maximum_overlap_px);
    try std.testing.expectEqual(@as(?f32, 0.30), shoulder.maximum_overlap_parent_span_ratio);
    try std.testing.expectEqual(@as(?f32, null), hip.maximum_overlap_parent_span_ratio);
    try std.testing.expectEqual(
        @as(f32, 15.0),
        shoulder.maximumOverlapForParentSpan(40.0),
    );
    try std.testing.expectEqual(
        @as(f32, 18.0),
        shoulder.maximumOverlapForParentSpan(60.0),
    );

    var report = visual.Report{};
    const controlled = visual.Metric{
        .character_style = "fixture",
        .outfit = "controlled_continuity",
        .view = .front,
        .pose = "neutral",
        .component = "joint",
        .side = .left,
        .metric = "visible_overlap_depth",
        .actual = 0,
        .unit = "px",
        .outcome = .pass,
    };
    var good_knee = controlled;
    good_knee.actual = 7.9;
    try report.recordMaximum(good_knee, knee.maximum_overlap_px);
    var bad_knee = controlled;
    bad_knee.actual = 8.1;
    try report.recordMaximum(bad_knee, knee.maximum_overlap_px);
    var good_root = controlled;
    good_root.actual = 14.9;
    try report.recordMaximum(good_root, shoulder.maximum_overlap_px);
    var bad_root = controlled;
    bad_root.actual = 15.1;
    try report.recordMaximum(
        bad_root,
        shoulder.maximumOverlapForParentSpan(40.0),
    );
    var good_broad_root = controlled;
    good_broad_root.actual = 17.9;
    try report.recordMaximum(
        good_broad_root,
        shoulder.maximumOverlapForParentSpan(60.0),
    );
    var bad_broad_root = controlled;
    bad_broad_root.actual = 18.1;
    try report.recordMaximum(
        bad_broad_root,
        shoulder.maximumOverlapForParentSpan(60.0),
    );

    try std.testing.expectEqual(visual.Outcome.pass, report.metrics[0].outcome);
    try std.testing.expectEqual(visual.Outcome.fail, report.metrics[1].outcome);
    try std.testing.expectEqual(visual.Outcome.pass, report.metrics[2].outcome);
    try std.testing.expectEqual(visual.Outcome.fail, report.metrics[3].outcome);
    try std.testing.expectEqual(visual.Outcome.pass, report.metrics[4].outcome);
    try std.testing.expectEqual(visual.Outcome.fail, report.metrics[5].outcome);
}

test "curved lower garments keep design-specific coverage without weakening the generic ruler" {
    const generic = visual.fitContract(.lower_long);
    const split = findVisualSpec("garnet_split_skirt").fit;
    const dress = findVisualSpec("ruby_day_dress_lower").fit;
    const highwaist = findVisualSpec("crimson_highwaist_pants").fit;

    try std.testing.expectEqual(@as(f32, 0.98), generic.minimumCoverage(.side_right));
    try std.testing.expectEqual(@as(f32, 0.88), split.minimumCoverage(.side_right));
    try std.testing.expectEqual(@as(f32, 0.94), dress.minimumCoverage(.side_right));
    try std.testing.expectEqual(@as(f32, 0.96), highwaist.minimumCoverage(.side_right));

    var report = visual.Report{};
    const controlled = visual.Metric{
        .character_style = "fixture",
        .outfit = "controlled_curved_lower",
        .view = .side_right,
        .pose = "neutral",
        .component = "split_skirt",
        .side = .none,
        .metric = "lower_intended_coverage",
        .actual = 0.90,
        .unit = "ratio",
        .outcome = .pass,
    };
    try report.recordRange(controlled, split.minimumCoverage(.side_right), 1.0);
    var exposed = controlled;
    exposed.actual = 0.75;
    try report.recordRange(exposed, split.minimumCoverage(.side_right), 1.0);
    try std.testing.expectEqual(visual.Outcome.pass, report.metrics[0].outcome);
    try std.testing.expectEqual(visual.Outcome.fail, report.metrics[1].outcome);
}

test "reports are structured and unapproved current captures cannot become goldens" {
    var report = visual.Report{};
    try report.recordMaximum(.{
        .character_style = "fixture",
        .outfit = "controlled_report",
        .view = .front,
        .pose = "neutral",
        .component = "shoe",
        .side = .left,
        .metric = "heel_error",
        .actual = 8.2,
        .unit = "px",
        .outcome = .pass,
    }, 2.0);
    var human_buffer: [1024]u8 = undefined;
    var json_buffer: [2048]u8 = undefined;
    const human = try audit.formatHuman(&report, &human_buffer);
    const json = try audit.formatJson(&report, &json_buffer);
    try std.testing.expect(std.mem.indexOf(u8, human, "heel_error=8.200px fail") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"outcome\":\"fail\"") != null);

    const capture = "fixture capture bytes";
    const digest = audit.hashCapture(capture);
    try std.testing.expectEqual(
        audit.GoldenComparison.unapproved,
        audit.compareGolden(capture, .{ .approved = false, .sha256 = digest }),
    );
    try std.testing.expectEqual(
        audit.GoldenComparison.match,
        audit.compareGolden(capture, .{ .approved = true, .sha256 = digest }),
    );
    try std.testing.expectEqual(
        audit.GoldenComparison.changed,
        audit.compareGolden("changed", .{ .approved = true, .sha256 = digest }),
    );
}

test "trace preserves semantic left and right identities independently of mirror signs" {
    var trace = visual.Trace{};
    const geometry = visual.attachmentGeometry("fixture_shoe", .shoe, .front);
    try trace.append(testRecord(101, .left, .shoe, -0.5, geometry));
    try trace.append(testRecord(202, .right, .shoe, 0.5, geometry));
    try std.testing.expectEqual(visual.Side.left, trace.records[0].side);
    try std.testing.expectEqual(visual.Side.right, trace.records[1].side);
    try std.testing.expect(trace.records[0].bound_identity != trace.records[1].bound_identity);
    // Identity is retained even if both controlled fixture scales use the same
    // sign; scale sign is deliberately not the side discriminator.
    trace.records[0].request.scale[0] = 0.5;
    try std.testing.expectEqual(visual.Side.left, trace.records[0].side);
}

test "current Prompt 25D production content satisfies visual geometry" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    try scene.enableVisualQualityAcceptance();
    try scene.selectPreset(try scene.catalog.presetId("wide_brim_crimson"));
    try scene.male.setPresentationOverride(.force_front);
    try scene.female.setPresentationOverride(.force_front);

    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        256,
        240,
        16,
        wardrobe_demo.combined_art_page_count + 1,
    );
    defer queue.deinit();
    var trace = visual.Trace{};
    queue.beginFrame();
    _ = try scene.submitTraced(&queue, &trace);
    _ = queue.prepare();
    var decoded = try decodeProductionPages(std.testing.allocator);
    defer decoded.deinit();
    var report = visual.Report{};
    try audit.evaluateCurrentProduction(&trace, &decoded.images, .{
        .outfit = "wide_brim_crimson",
        .pose = "neutral",
        .camera = camera2d.Camera2D.initDefault(),
    }, &report);

    try std.testing.expect(trace.count > 40);
    try expectSemanticSides(&trace, .shoe);
    try std.testing.expect(report.count >= 129);
    try std.testing.expectEqual(@as(u32, 0), report.failure_count);
    std.debug.print(
        "Prompt 25D focused production geometry: {d}/{d} PASS\n",
        .{ report.count, report.count },
    );
}

test "pose and morphology sweep traces production transforms without allocations after stabilization" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    try scene.enableVisualQualityAcceptance();
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        256,
        240,
        16,
        wardrobe_demo.combined_art_page_count + 1,
    );
    defer queue.deinit();
    queue.markStabilized();

    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    var decoded = try decodeProductionPages(std.testing.allocator);
    defer decoded.deinit();
    var sweep_report = visual.Report{};
    const build_values = [_]f32{ 15, 50, 85 };
    const views = [_]struct {
        override: @import("presentation_view").DebugOverride,
        facing: @import("humanoid").Facing,
    }{
        .{ .override = .force_front, .facing = .right },
        .{ .override = .force_side, .facing = .right },
        .{ .override = .force_side, .facing = .left },
    };
    var observed_records: usize = 0;
    for (build_values) |build| {
        try scene.male.setGlobalBuild(build);
        try scene.female.setGlobalBuild(build);
        for (views) |value| {
            try scene.male.setPresentationOverride(value.override);
            try scene.male.setFacing(value.facing);
            try scene.female.setPresentationOverride(value.override);
            try scene.female.setFacing(value.facing);
            var trace = visual.Trace{};
            queue.beginFrame();
            _ = try scene.submitTraced(&queue, &trace);
            observed_records += trace.count;
            try audit.evaluateCurrentProduction(&trace, &decoded.images, .{
                .outfit = "wide_brim_crimson",
                .pose = "morphology_view_sweep",
                .camera = camera2d.Camera2D.initDefault(),
            }, &sweep_report);
        }
    }
    // The declared matrix evaluates build extrema and motion independently.
    // Do not leak the final high-build sample into every channel and authored
    // motion case; the production acceptance report resets the same authority
    // before those matrices.
    try scene.male.setGlobalBuild(50);
    try scene.female.setGlobalBuild(50);

    const channel_names = [_][]const u8{
        "shoulder_width",
        "hip_width",
        "upper_arm_thickness",
        "thigh_thickness",
        "hand_scale",
        "foot_scale",
    };
    for (channel_names) |name| {
        const channel_id = try anatomy_definition.morphologyChannelId(name);
        for ([_]f32{ 20, 80 }) |value| {
            try scene.male.setMorphologyChannelOverride(channel_id, value);
            try scene.female.setMorphologyChannelOverride(channel_id, value);
            for (views) |view| {
                try scene.male.setPresentationOverride(view.override);
                try scene.male.setFacing(view.facing);
                try scene.female.setPresentationOverride(view.override);
                try scene.female.setFacing(view.facing);
                var trace = visual.Trace{};
                queue.beginFrame();
                _ = try scene.submitTraced(&queue, &trace);
                observed_records += trace.count;
                try audit.evaluateCurrentProduction(&trace, &decoded.images, .{
                    .outfit = "wide_brim_crimson",
                    .pose = "channel_sweep",
                    .camera = camera2d.Camera2D.initDefault(),
                }, &sweep_report);
            }
        }
        try scene.male.setMorphologyChannelOverride(channel_id, null);
        try scene.female.setMorphologyChannelOverride(channel_id, null);
    }

    // Exercise deterministic authored walk/jump/landing poses through the
    // existing visual-quality state schedule rather than constructing a second
    // animation representation.
    var frame: u32 = 0;
    while (frame < wardrobe_demo.visual_quality_required_frames) : (frame += 1) {
        try scene.updateVisualQualityFrame();
        if (frame == 484 or
            frame == 492 or
            frame == 500 or
            frame == 508 or
            frame == 525 or
            frame == 540 or
            frame == 550 or
            frame == 575 or
            frame == 599)
        {
            var trace = visual.Trace{};
            queue.beginFrame();
            _ = try scene.submitTraced(&queue, &trace);
            observed_records += trace.count;
            try audit.evaluateCurrentProduction(&trace, &decoded.images, .{
                .outfit = "wide_brim_crimson",
                .pose = if (frame == 484)
                    "walk_phase_0"
                else if (frame == 492)
                    "walk_phase_25"
                else if (frame == 500)
                    "walk_phase_50"
                else if (frame == 508)
                    "walk_phase_75"
                else if (frame == 525)
                    "deep_knee_bend"
                else if (frame == 540)
                    "jump_compression"
                else if (frame == 550)
                    "jump_rise"
                else if (frame == 575)
                    "jump_fall"
                else
                    "landing",
                .camera = camera2d.Camera2D.initDefault(),
            }, &sweep_report);
        }
    }
    try std.testing.expect(observed_records > 400);
    try std.testing.expect(sweep_report.count > 500);
    if (sweep_report.failure_count != 0) {
        for (sweep_report.metrics[0..sweep_report.count]) |entry| {
            if (entry.outcome != .fail) continue;
            std.debug.print(
                "{s}/{s}/{s}/{s}/{s}/{s}/{s}: actual={d:.3} min={?d:.3} max={?d:.3} {s}\n",
                .{
                    entry.character_style,
                    @tagName(entry.view),
                    entry.outfit,
                    entry.pose,
                    @tagName(entry.side),
                    entry.component,
                    entry.metric,
                    entry.actual,
                    entry.minimum,
                    entry.maximum,
                    entry.unit,
                },
            );
        }
    }
    try std.testing.expectEqual(@as(u32, 0), sweep_report.failure_count);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
    try std.testing.expectEqual(@as(u64, 0), scene.male.metrics.submission_allocations);
    try std.testing.expectEqual(@as(u64, 0), scene.female.metrics.submission_allocations);
    std.debug.print(
        "Prompt 25D pose/morphology geometry: {d}/{d} PASS\n",
        .{ sweep_report.count, sweep_report.count },
    );
}

const DecodedPages = struct {
    male: image_decode.DecodedImage,
    female: image_decode.DecodedImage,
    components: image_decode.DecodedImage,
    upper: image_decode.DecodedImage,
    layers: image_decode.DecodedImage,
    lower: image_decode.DecodedImage,
    images: audit.Images,

    fn deinit(pages: *DecodedPages) void {
        pages.lower.deinit();
        pages.layers.deinit();
        pages.upper.deinit();
        pages.components.deinit();
        pages.female.deinit();
        pages.male.deinit();
        pages.* = undefined;
    }
};

fn decodeProductionPages(allocator: std.mem.Allocator) !DecodedPages {
    var male = try image_decode.decodePngFile(allocator, "assets/art/p25a_male_base_anatomy_atlas.png", null);
    errdefer male.deinit();
    var female = try image_decode.decodePngFile(allocator, "assets/art/p25a_female_base_anatomy_atlas.png", null);
    errdefer female.deinit();
    var components = try image_decode.decodePngFile(allocator, "assets/art/p25b_anatomy_components_atlas.png", null);
    errdefer components.deinit();
    var upper = try image_decode.decodePngFile(allocator, "assets/art/p25_wardrobe_upper_atlas.png", null);
    errdefer upper.deinit();
    var layers = try image_decode.decodePngFile(allocator, "assets/art/p25_wardrobe_layers_atlas.png", null);
    errdefer layers.deinit();
    var lower = try image_decode.decodePngFile(allocator, "assets/art/p25_wardrobe_lower_atlas.png", null);
    errdefer lower.deinit();
    var images = audit.Images{};
    try addImage(&images, 1, male);
    try addImage(&images, 2, female);
    try addImage(&images, 3, components);
    try addImage(&images, 4, upper);
    try addImage(&images, 5, layers);
    try addImage(&images, 6, lower);
    return .{
        .male = male,
        .female = female,
        .components = components,
        .upper = upper,
        .layers = layers,
        .lower = lower,
        .images = images,
    };
}

fn addImage(images: *audit.Images, texture_page: u32, image: image_decode.DecodedImage) !void {
    try images.append(.{
        .texture_page = texture_page,
        .pixels = image.pixels,
        .width = image.layout.width,
        .height = image.layout.height,
        .row_bytes = image.layout.row_bytes,
    });
}

fn expectFailureMetric(report: *const visual.Report, name: []const u8) !void {
    for (report.metrics[0..report.count]) |entry| {
        if (entry.outcome == .fail and std.mem.eql(u8, entry.metric, name)) return;
    }
    return error.ExpectedVisualGeometryFailureMissing;
}

fn expectAnyFailure(report: *const visual.Report, names: []const []const u8) !void {
    for (names) |name| {
        if (expectFailureMetric(report, name)) |_| return else |_| {}
    }
    return error.ExpectedVisualGeometryFailureCategoryMissing;
}

fn expectSemanticSides(trace: *const visual.Trace, role: visual.Role) !void {
    var left: ?u32 = null;
    var right: ?u32 = null;
    for (trace.records[0..trace.count]) |record| {
        if (record.character_id != 2 or record.role != role) continue;
        switch (record.side) {
            .left => left = record.bound_identity,
            .right => right = record.bound_identity,
            .none => {},
        }
    }
    try std.testing.expect(left != null and right != null);
    try std.testing.expect(left.? != right.?);
}

fn findVisualSpec(stable_id: []const u8) wardrobe_catalog.VisualSpec {
    for (wardrobe_catalog.visual_specs) |spec| {
        if (std.mem.eql(u8, spec.stable_id, stable_id)) return spec;
    }
    std.debug.panic("missing controlled visual spec: {s}", .{stable_id});
}

fn testRequest(overrides: struct {
    world_position: [2]f32,
    rotation: f32,
    scale: [2]f32,
    pivot: [2]f32,
}) sprite.SpriteRequest {
    return .{
        .world_position = overrides.world_position,
        .rotation = overrides.rotation,
        .scale = overrides.scale,
        .pivot = overrides.pivot,
        .uv_rect = .{ 0, 0, 1, 1 },
        .tint = .{ 1, 1, 1, 1 },
        .texture_page = 0,
        .order = .{
            .scene_layer = 0,
            .interaction_layer = 0,
            .actor_layer = 0,
            .body_part_layer = 0,
        },
    };
}

fn testRecord(
    identity: u32,
    side: visual.Side,
    role: visual.Role,
    scale_x: f32,
    geometry: visual.Geometry,
) visual.TraceRecord {
    return .{
        .character_id = 1,
        .style = "fixture",
        .view = .front,
        .owner = .equipment,
        .role = role,
        .side = side,
        .semantic_id = 7,
        .component_id = identity,
        .bound_identity = identity,
        .stable_id = "fixture",
        .region_id = 9,
        .source = .{ .x = 0, .y = 0, .width = 4, .height = 4 },
        .request = testRequest(.{
            .world_position = .{ 0, 0 },
            .rotation = 0,
            .scale = .{ scale_x, 0.3 },
            .pivot = .{ 0.5, 0.5 },
        }),
        .geometry = geometry,
        .fit = visual.fitContract(.shoe_strap),
    };
}
