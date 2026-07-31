const std = @import("std");
const math = @import("math");
const input = @import("input");
const camera2d = @import("camera2d");
const image_decode = @import("image_decode");
const render_queue = @import("render_queue");
const sprite = @import("sprite_batch");
const foundation_evidence = @import("foundation_evidence");
const coherence = @import("foundation_coherence");
const visual_foundation = @import("visual_foundation");
const visual_geometry = @import("visual_geometry");
const visual_geometry_audit = @import("visual_geometry_audit");

const metric_capacity: usize = 32_768;

const Outcome = enum {
    pass,
    fail,
};

const Metric = struct {
    case_id: []const u8,
    render_frame: u32,
    simulation_tick: u64,
    character_style: []const u8,
    view: []const u8,
    facing: []const u8,
    pose: []const u8,
    outfit: []const u8,
    morphology: []const u8,
    component: []const u8,
    side: []const u8,
    metric: []const u8,
    actual: f32,
    unit: []const u8,
    allowed_minimum: ?f32,
    allowed_maximum: ?f32,
    source: []const u8,
    outcome: Outcome,
};

const Report = struct {
    metrics: [metric_capacity]Metric = undefined,
    count: usize = 0,
    failure_count: u32 = 0,

    fn append(report: *Report, metric: Metric) !void {
        if (report.count == report.metrics.len) return error.CoherenceMetricCapacityExceeded;
        if (!std.math.isFinite(metric.actual)) return error.NonFiniteCoherenceMetric;
        if (metric.allowed_minimum) |value| {
            if (!std.math.isFinite(value)) return error.NonFiniteCoherenceThreshold;
        }
        if (metric.allowed_maximum) |value| {
            if (!std.math.isFinite(value)) return error.NonFiniteCoherenceThreshold;
        }
        report.metrics[report.count] = metric;
        report.count += 1;
        if (metric.outcome == .fail) report.failure_count += 1;
    }

    fn maximum(report: *Report, base: Metric, maximum_value: f32) !void {
        var metric = base;
        metric.allowed_maximum = maximum_value;
        metric.outcome = if (metric.actual <= maximum_value) .pass else .fail;
        try report.append(metric);
    }

    fn minimum(report: *Report, base: Metric, minimum_value: f32) !void {
        var metric = base;
        metric.allowed_minimum = minimum_value;
        metric.outcome = if (metric.actual >= minimum_value) .pass else .fail;
        try report.append(metric);
    }

    fn range(
        report: *Report,
        base: Metric,
        minimum_value: f32,
        maximum_value: f32,
    ) !void {
        var metric = base;
        metric.allowed_minimum = minimum_value;
        metric.allowed_maximum = maximum_value;
        metric.outcome = if (metric.actual >= minimum_value and
            metric.actual <= maximum_value)
            .pass
        else
            .fail;
        try report.append(metric);
    }
};

const Options = struct {
    output_directory: []const u8 =
        "zig-out/p27b_evidence/final_semantic_report",
    expect_failures: bool = false,
};

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    const options = try parseOptions(arguments);
    const allocator = std.heap.page_allocator;
    var scene = try visual_foundation.Scene.init(
        allocator,
        .enforce_acceptance,
    );
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        visual_foundation.configured_texture_page_count,
    );
    defer queue.deinit();
    queue.markStabilized();
    var pages = try ProductionPages.init(allocator);
    defer pages.deinit();
    var report = try allocator.create(Report);
    defer allocator.destroy(report);
    report.* = .{};

    var script = visual_foundation.ScriptedInput{};
    var snapshots = input.SnapshotBuilder{};
    var tracker = foundation_evidence.Tracker{ .log_timeouts = true };
    var parallax_start: ?coherence.ParallaxFrame = null;
    var parallax_finish: ?coherence.ParallaxFrame = null;
    var minimum_camera_x = std.math.inf(f32);
    var maximum_camera_x = -std.math.inf(f32);
    var previous_camera = scene.integrated.camera;

    for (0..visual_foundation.required_frames) |frame_index| {
        const snapshot = try snapshots.update(script.nextRaw(&scene));
        try scene.updateFrame(1.0 / 60.0, snapshot);
        try script.observe(&scene);
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
        scene.recordRendering(queue.frame_metrics);

        const female_bounds = try coherence.traceCharacterBounds(
            scene.visual_trace,
            scene.integrated.production.female.id.raw(),
        );
        const framing = try coherence.framingMeasurement(
            female_bounds.world,
            scene.integrated.camera,
        );
        const interaction_active = scene.presenceInteractionContext();
        const female_presence = try coherence.traceCharacterPresenceBounds(
            scene.visual_trace,
            scene.integrated.production.female.id.raw(),
        );
        const male_presence = try coherence.traceCharacterPresenceBounds(
            scene.visual_trace,
            scene.integrated.production.male.id.raw(),
        );
        const overlap_ratio = try coherence.overlapRatio(
            female_presence.world,
            male_presence.world,
        );
        var route_metric = makeMetric(
            "route_frame",
            "female",
            @tagName(scene.integrated.production.female.presentationView()),
            @tagName(scene.integrated.production.female.facing),
            @tagName(script.phase),
            "",
            "",
            "visible_bounds",
            "none",
            "top_headroom",
            framing.top_headroom_px,
            "px",
            "semantic_submission",
        );
        route_metric.render_frame = @intCast(frame_index);
        route_metric.simulation_tick =
            scene.integrated.production.simulation_tick;
        try report.minimum(
            route_metric,
            coherence.minimum_top_headroom_px,
        );
        route_metric = makeMetric(
            "route_frame",
            "female",
            @tagName(scene.integrated.production.female.presentationView()),
            @tagName(scene.integrated.production.female.facing),
            @tagName(script.phase),
            "",
            "",
            "visible_bounds",
            "none",
            "bottom_clearance",
            framing.bottom_clearance_px,
            "px",
            "semantic_submission",
        );
        route_metric.render_frame = @intCast(frame_index);
        route_metric.simulation_tick =
            scene.integrated.production.simulation_tick;
        try report.minimum(
            route_metric,
            coherence.minimum_bottom_clearance_px,
        );
        route_metric = makeMetric(
            "route_frame",
            "lineup",
            @tagName(scene.integrated.production.female.presentationView()),
            @tagName(scene.integrated.production.female.facing),
            @tagName(script.phase),
            "",
            "",
            "participants",
            "none",
            "visible_overlap_ratio",
            overlap_ratio,
            "ratio",
            "semantic_submission",
        );
        route_metric.render_frame = @intCast(frame_index);
        route_metric.simulation_tick =
            scene.integrated.production.simulation_tick;
        try report.maximum(route_metric, if (interaction_active)
            coherence.maximum_interaction_overlap_ratio
        else
            coherence.maximum_ordinary_overlap_ratio);
        if (script.abrupt_resize_first_post_frame) {
            const abrupt = try coherence.measureAbruptResize(
                previous_camera,
                scene.integrated.camera,
                female_bounds.world,
            );
            try appendAbruptResizeMetrics(
                report,
                @intCast(frame_index),
                scene.integrated.production.simulation_tick,
                abrupt,
            );
        } else {
            const viewport_changed = previous_camera.viewport_width !=
                scene.integrated.camera.viewport_width or
                previous_camera.viewport_height !=
                    scene.integrated.camera.viewport_height;
            const camera_step_px = if (viewport_changed)
                @abs(
                    scene.integrated.camera.center.y -
                        previous_camera.center.y,
                ) * scene.integrated.camera.pixels_per_meter
            else
                try coherence.worldCameraVerticalStepPx(
                    previous_camera,
                    scene.integrated.camera,
                );
            route_metric = makeMetric(
                "route_frame",
                "camera",
                @tagName(scene.integrated.production.female.presentationView()),
                @tagName(scene.integrated.production.female.facing),
                @tagName(script.phase),
                "",
                "",
                "camera",
                "none",
                if (viewport_changed)
                    "viewport_reprojection_world_delta"
                else
                    "vertical_step",
                camera_step_px,
                "px/render",
                if (viewport_changed)
                    "drawable_viewport_reprojection"
                else
                    "semantic_camera",
            );
            route_metric.render_frame = @intCast(frame_index);
            route_metric.simulation_tick =
                scene.integrated.production.simulation_tick;
            if (viewport_changed) {
                try report.append(route_metric);
            } else {
                try report.maximum(
                    route_metric,
                    coherence.maximum_camera_step_px,
                );
            }
        }
        previous_camera = scene.integrated.camera;

        const anchors = try coherenceAnchors(scene.parallax_trace);
        const parallax_frame = try coherence.sampleParallaxFrame(
            scene.integrated.camera,
            anchors,
        );
        if (scene.integrated.camera.center.x < minimum_camera_x) {
            minimum_camera_x = scene.integrated.camera.center.x;
            parallax_start = parallax_frame;
        }
        if (scene.integrated.camera.center.x > maximum_camera_x) {
            maximum_camera_x = scene.integrated.camera.center.x;
            parallax_finish = parallax_frame;
        }

        const observation = try scene.captureObservation(&script, .{
            .render_frame = @intCast(frame_index),
            .texture_pages = visual_foundation.configured_texture_page_count,
            .submitted_sprites = queue.frame_metrics.submitted_sprites,
            .submitted_meshes = queue.frame_metrics.submitted_meshes,
            .sprite_ranges = queue.frame_metrics.sprite_ranges,
            .mesh_ranges = queue.frame_metrics.mesh_ranges,
            .gpu_resource_creations = 0,
            .steady_update_allocations = 0,
            .steady_submission_allocations = 0,
            .steady_queue_allocations = queue.lifetime_metrics.cpu_allocations_after_stabilization,
        });
        if (try tracker.observe(observation)) |candidate| {
            try evaluateCaptureGround(
                &scene,
                &pages.images,
                observation,
                foundation_evidence.specs[candidate.spec_index].id,
                report,
            );
            try tracker.commit(candidate, observation);
        }
    }
    try scene.validateComplete(&script);
    try tracker.validateComplete();

    const parallax = try coherence.measureParallax(
        parallax_start orelse return error.MissingParallaxStart,
        parallax_finish orelse return error.MissingParallaxFinish,
        try coherenceAnchors(scene.parallax_trace),
        scene.integrated.camera.pixels_per_meter,
    );
    try appendParallaxMetrics(report, parallax);
    try appendOrderingMetric(report);
    try writeOutputs(init.io, allocator, options.output_directory, report);

    std.log.info(
        "Prompt 27B semantic baseline: metrics={d} failures={d} output={s}",
        .{ report.count, report.failure_count, options.output_directory },
    );
    if (options.expect_failures) {
        if (report.failure_count == 0) return error.ExpectedProductionFailuresMissing;
    } else if (report.failure_count != 0) {
        return error.ProductionCoherenceRejected;
    }
}

fn parseOptions(arguments: []const []const u8) !Options {
    var result = Options{};
    var index: usize = 1;
    while (index < arguments.len) : (index += 1) {
        if (std.mem.eql(u8, arguments[index], "--output")) {
            index += 1;
            if (index >= arguments.len) return error.MissingOutputDirectory;
            result.output_directory = arguments[index];
        } else if (std.mem.eql(u8, arguments[index], "--expect-failures")) {
            result.expect_failures = true;
        } else {
            return error.UnknownCoherenceReportArgument;
        }
    }
    return result;
}

fn appendAbruptResizeMetrics(
    report: *Report,
    render_frame: u32,
    simulation_tick: u64,
    measurement: coherence.AbruptResizeMeasurement,
) !void {
    const values = [_]struct {
        metric: []const u8,
        actual: f32,
        expected: f32,
        unit: []const u8,
    }{
        .{
            .metric = "previous_viewport_width",
            .actual = @floatFromInt(measurement.previous_viewport[0]),
            .expected = @floatFromInt(coherence.abrupt_resize_from_width),
            .unit = "px",
        },
        .{
            .metric = "previous_viewport_height",
            .actual = @floatFromInt(measurement.previous_viewport[1]),
            .expected = @floatFromInt(coherence.abrupt_resize_from_height),
            .unit = "px",
        },
        .{
            .metric = "current_viewport_width",
            .actual = @floatFromInt(measurement.current_viewport[0]),
            .expected = @floatFromInt(coherence.abrupt_resize_to_width),
            .unit = "px",
        },
        .{
            .metric = "current_viewport_height",
            .actual = @floatFromInt(measurement.current_viewport[1]),
            .expected = @floatFromInt(coherence.abrupt_resize_to_height),
            .unit = "px",
        },
    };
    for (values) |value| {
        var metric = makeMetric(
            "abrupt_resize_first_post",
            "female",
            "front",
            "left",
            "idle",
            "",
            "",
            "camera",
            "none",
            value.metric,
            value.actual,
            value.unit,
            "semantic_viewport",
        );
        metric.render_frame = render_frame;
        metric.simulation_tick = simulation_tick;
        try report.range(metric, value.expected, value.expected);
    }

    var metric = makeMetric(
        "abrupt_resize_first_post",
        "female",
        "front",
        "left",
        "idle",
        "",
        "",
        "visible_bounds",
        "none",
        "top_headroom",
        measurement.framing.top_headroom_px,
        "px",
        "semantic_projection",
    );
    metric.render_frame = render_frame;
    metric.simulation_tick = simulation_tick;
    try report.minimum(metric, coherence.minimum_top_headroom_px);
    metric.metric = "bottom_clearance";
    metric.actual = measurement.framing.bottom_clearance_px;
    try report.minimum(metric, coherence.minimum_bottom_clearance_px);

    metric.component = "camera";
    metric.metric = "instantaneous_reprojection_world_delta";
    metric.actual = measurement.world_camera_delta_px;
    metric.unit = "px";
    metric.source = "semantic_camera_classification";
    metric.allowed_minimum = null;
    metric.allowed_maximum = null;
    metric.outcome = .pass;
    try report.append(metric);
}

fn evaluateCaptureGround(
    scene: *visual_foundation.Scene,
    images: *const visual_geometry_audit.Images,
    observation: foundation_evidence.Observation,
    capture_id: foundation_evidence.CaptureId,
    report: *Report,
) !void {
    if (!observation.grounded or observation.supporting_collider == null) return;
    const require_rest_contact =
        observation.view == .front and
        @abs(observation.velocity[0]) <= foundation_evidence.idle_velocity_threshold_mps;
    const female = &scene.integrated.production.female;
    const FootEntry = struct {
        name: []const u8,
        side: visual_geometry.Side,
        foot: @TypeOf(&female.foot_plants.left),
    };
    const feet = [_]FootEntry{
        .{ .name = "left", .side = .left, .foot = &female.foot_plants.left },
        .{ .name = "right", .side = .right, .foot = &female.foot_plants.right },
    };
    for (feet) |entry| {
        const side_name = entry.name;
        const side = entry.side;
        const foot = entry.foot;
        const fully_planted = foot.plant_state == .planted and foot.plant_weight == 1;
        if (!require_rest_contact and !fully_planted and
            capture_id != .raised_platform_landing)
        {
            continue;
        }
        const record = findOutermostFootVisual(scene.visual_trace, female.id.raw(), side) orelse
            return error.MissingGroundContactVisual;
        const anatomy_record = findAnatomyFoot(
            scene.visual_trace,
            female.id.raw(),
            side,
        ) orelse return error.MissingGroundContactAnatomy;
        const page = try images.find(record.request.texture_page);
        const alpha = try visual_geometry.deriveAlphaGeometry(
            page.pixels,
            page.width,
            page.height,
            page.row_bytes,
            record.source,
        );
        const heel = try visual_geometry.resolveLandmark(
            record,
            alpha,
            .sole_back,
            scene.integrated.camera,
        );
        const toe = try visual_geometry.resolveLandmark(
            record,
            alpha,
            .sole_front,
            scene.integrated.camera,
        );
        const anatomy_page = try images.find(anatomy_record.request.texture_page);
        const anatomy_alpha = try visual_geometry.deriveAlphaGeometry(
            anatomy_page.pixels,
            anatomy_page.width,
            anatomy_page.height,
            anatomy_page.row_bytes,
            anatomy_record.source,
        );
        const anatomy_heel = try visual_geometry.resolveLandmark(
            anatomy_record,
            anatomy_alpha,
            .sole_back,
            scene.integrated.camera,
        );
        const anatomy_toe = try visual_geometry.resolveLandmark(
            anatomy_record,
            anatomy_alpha,
            .sole_front,
            scene.integrated.camera,
        );
        const anatomy_sole = anatomy_heel.world
            .add(anatomy_toe.world)
            .scale(0.5);
        const projected_post_ik_sole = heel.world.add(toe.world).scale(0.5);
        const supporting_top = try supportingTop(
            scene,
            @intCast(observation.supporting_collider.?),
        );
        const measurement = try coherence.measureGroundContact(
            scene.integrated.camera,
            .{
                .planted = true,
                .canonical_sole_world = projected_post_ik_sole,
                .supporting_top_y = supporting_top,
                .heel_side_sole_world = heel.world,
                .toe_side_sole_world = toe.world,
            },
        );
        const capture_name = @tagName(capture_id);
        const common = makeMetric(
            capture_name,
            record.style,
            @tagName(record.view),
            @tagName(observation.facing),
            observation.animation_state,
            observation.outfit,
            observation.morphology,
            record.stable_id,
            side_name,
            "",
            0,
            "",
            "semantic_alpha",
        );
        var value = common;
        value.render_frame = observation.render_frame;
        value.simulation_tick = observation.simulation_tick;
        value.metric = "canonical_sole_error";
        value.actual = measurement.canonical_error_px;
        value.unit = "px";
        try report.maximum(value, coherence.semantic_sole_tolerance_px);
        value.metric = "canonical_sole_height";
        value.actual =
            (projected_post_ik_sole.y - supporting_top) *
            scene.integrated.camera.pixels_per_meter;
        try report.range(
            value,
            -coherence.semantic_sole_tolerance_px,
            coherence.semantic_sole_tolerance_px,
        );
        value.metric = "ik_target_surface_error";
        value.actual = if (foot.locked_target) |target|
            @abs(target.y - supporting_top) *
                scene.integrated.camera.pixels_per_meter
        else
            0;
        try report.maximum(value, coherence.semantic_sole_tolerance_px);
        value.metric = "anatomy_inside_outer_sole_clearance";
        const registered_anatomy_clearance =
            (anatomy_sole.y - projected_post_ik_sole.y) *
            scene.integrated.camera.pixels_per_meter;
        if (!anatomy_record.isRendered()) {
            var hidden_evidence = value;
            hidden_evidence.metric = "hidden_registered_anatomy_sole_clearance";
            hidden_evidence.actual = registered_anatomy_clearance;
            hidden_evidence.allowed_minimum = null;
            hidden_evidence.allowed_maximum = null;
            hidden_evidence.outcome = .pass;
            try report.append(hidden_evidence);
        }
        value.actual = if (anatomy_record.isRendered())
            registered_anatomy_clearance
        else
            0;
        try report.range(
            value,
            coherence.sole_endpoint_minimum_height_px,
            coherence.maximum_footwear_anatomy_clearance_px,
        );
        value.metric = "visual_sole_midpoint_error";
        value.actual = measurement.visual_midpoint_error_px;
        try report.maximum(value, coherence.visual_sole_tolerance_px);
        value.metric = "heel_side_sole_height";
        value.actual = measurement.heel_height_px;
        try report.range(
            value,
            coherence.sole_endpoint_minimum_height_px,
            coherence.sole_endpoint_maximum_height_px,
        );
        value.metric = "toe_side_sole_height";
        value.actual = measurement.toe_height_px;
        try report.range(
            value,
            coherence.sole_endpoint_minimum_height_px,
            coherence.sole_endpoint_maximum_height_px,
        );
        if (observation.view == .front) {
            const sole_delta = toe.world.sub(heel.world);
            value.metric = "front_sole_support_tangent_angle";
            value.actual = @abs(std.math.radiansToDegrees(std.math.atan2(
                sole_delta.y,
                @abs(sole_delta.x),
            )));
            value.unit = "deg";
            try report.maximum(value, 0.01);

            var alpha_minimum_y = std.math.inf(f32);
            for ([_][2]f32{
                .{ 0, 0 },
                .{ 1, 0 },
                .{ 0, 1 },
                .{ 1, 1 },
            }) |visible_uv| {
                const local = alpha.visibleUvToLocal(visible_uv);
                const world = sprite.localPointToWorld(
                    record.request,
                    local,
                );
                alpha_minimum_y = @min(alpha_minimum_y, world[1]);
            }
            value.metric = "front_alpha_support_penetration";
            value.actual = @max(
                @as(f32, 0),
                (supporting_top - alpha_minimum_y) *
                    scene.integrated.camera.pixels_per_meter,
            );
            value.unit = "px";
            try report.maximum(
                value,
                coherence.sole_endpoint_maximum_height_px,
            );
        }
    }
}

fn findOutermostFootVisual(
    trace: *const visual_geometry.Trace,
    character_id: u32,
    side: visual_geometry.Side,
) ?visual_geometry.TraceRecord {
    var result: ?visual_geometry.TraceRecord = null;
    for (trace.slice()) |record| {
        if (record.character_id != character_id or record.side != side) continue;
        if (!record.isRendered()) continue;
        if (record.role != .shoe and record.role != .foot) continue;
        if (result == null or
            record.request.order.body_part_layer >
                result.?.request.order.body_part_layer)
        {
            result = record;
        }
    }
    return result;
}

fn findAnatomyFoot(
    trace: *const visual_geometry.Trace,
    character_id: u32,
    side: visual_geometry.Side,
) ?visual_geometry.TraceRecord {
    for (trace.slice()) |record| {
        if (record.character_id == character_id and
            record.owner == .anatomy and
            record.role == .foot and
            record.side == side)
        {
            return record;
        }
    }
    return null;
}

fn supportingTop(scene: *const visual_foundation.Scene, id: u16) !f32 {
    for (scene.integrated.production.world.colliders) |static_collider| {
        if (static_collider.id == id) return static_collider.bounds.maximum.y;
    }
    return error.MissingSupportingCollider;
}

fn coherenceAnchors(
    trace: @import("environment_theme").ParallaxTrace,
) ![3]coherence.ParallaxAnchor {
    try trace.validateComplete();
    var result: [3]coherence.ParallaxAnchor = undefined;
    for (trace.anchors, 0..) |anchor, index| {
        result[index] = .{
            .role = @enumFromInt(@intFromEnum(anchor.role)),
            .world = anchor.world,
            .camera_x_factor = anchor.camera_x_factor,
        };
    }
    return result;
}

fn appendParallaxMetrics(
    report: *Report,
    measurement: coherence.ParallaxMeasurement,
) !void {
    const names = [_][]const u8{ "far", "midground", "gameplay" };
    for (names, 0..) |name, index| {
        try report.minimum(makeMetric(
            "route_parallax",
            "environment",
            "all",
            "all",
            "camera_travel",
            "",
            "",
            name,
            "none",
            "screen_displacement",
            measurement.displacement_px[index],
            "px",
            "semantic_submission",
        ), if (index == 0) std.math.floatEps(f32) else 0);
        try report.maximum(makeMetric(
            "route_parallax",
            "environment",
            "all",
            "all",
            "camera_travel",
            "",
            "",
            name,
            "none",
            "factor_prediction_error",
            measurement.prediction_error_px[index],
            "px",
            "semantic_submission",
        ), coherence.maximum_parallax_prediction_error_px);
    }
    try report.minimum(makeMetric(
        "route_parallax",
        "environment",
        "all",
        "all",
        "camera_travel",
        "",
        "",
        "camera",
        "none",
        "camera_travel",
        measurement.camera_travel_m,
        "m",
        "semantic_camera",
    ), coherence.minimum_parallax_camera_travel_m);
    try report.minimum(makeMetric(
        "route_parallax",
        "environment",
        "all",
        "all",
        "camera_travel",
        "",
        "",
        "far_to_midground",
        "none",
        "displacement_separation",
        measurement.displacement_px[1] - measurement.displacement_px[0],
        "px",
        "semantic_submission",
    ), coherence.minimum_parallax_separation_px);
    try report.minimum(makeMetric(
        "route_parallax",
        "environment",
        "all",
        "all",
        "camera_travel",
        "",
        "",
        "midground_to_gameplay",
        "none",
        "displacement_separation",
        measurement.displacement_px[2] - measurement.displacement_px[1],
        "px",
        "semantic_submission",
    ), coherence.minimum_parallax_separation_px);
}

fn appendOrderingMetric(report: *Report) !void {
    const valid = coherence.surfaceOrderingValid(-10_000, -9_500, 0, 30_000);
    try report.range(makeMetric(
        "all_themes",
        "environment",
        "all",
        "all",
        "all",
        "",
        "",
        "surface_white",
        "none",
        "semantic_order",
        @floatFromInt(@intFromBool(valid)),
        "bool",
        "semantic_queue_order",
    ), 1, 1);
}

fn makeMetric(
    case_id: []const u8,
    character_style: []const u8,
    view: []const u8,
    facing: []const u8,
    pose: []const u8,
    outfit: []const u8,
    morphology: []const u8,
    component: []const u8,
    side: []const u8,
    metric_name: []const u8,
    actual: f32,
    unit: []const u8,
    source: []const u8,
) Metric {
    return .{
        .case_id = case_id,
        .render_frame = 0,
        .simulation_tick = 0,
        .character_style = character_style,
        .view = view,
        .facing = facing,
        .pose = pose,
        .outfit = outfit,
        .morphology = morphology,
        .component = component,
        .side = side,
        .metric = metric_name,
        .actual = actual,
        .unit = unit,
        .allowed_minimum = null,
        .allowed_maximum = null,
        .source = source,
        .outcome = .pass,
    };
}

fn writeOutputs(
    io: std.Io,
    allocator: std.mem.Allocator,
    output_directory: []const u8,
    report: *const Report,
) !void {
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    const text_path = try std.fs.path.join(
        allocator,
        &.{ output_directory, "report.txt" },
    );
    defer allocator.free(text_path);
    const json_path = try std.fs.path.join(
        allocator,
        &.{ output_directory, "report.json" },
    );
    defer allocator.free(json_path);
    var text_file = try std.Io.Dir.cwd().createFile(io, text_path, .{});
    defer text_file.close(io);
    var json_file = try std.Io.Dir.cwd().createFile(io, json_path, .{});
    defer json_file.close(io);

    var line_buffer: [2048]u8 = undefined;
    const header = try std.fmt.bufPrint(
        &line_buffer,
        "prompt27b.coherence metrics={d} failures={d}\n",
        .{ report.count, report.failure_count },
    );
    try text_file.writeStreamingAll(io, header);
    const json_header = try std.fmt.bufPrint(
        &line_buffer,
        "{{\"schema\":\"prompt27b.coherence.v1\",\"metric_count\":{d},\"failure_count\":{d},\"metrics\":[",
        .{ report.count, report.failure_count },
    );
    try json_file.writeStreamingAll(io, json_header);
    for (report.metrics[0..report.count], 0..) |entry, index| {
        const text = try std.fmt.bufPrint(
            &line_buffer,
            "frame={d} tick={d} {s}/{s}/{s}/{s}/{s}/{s} {s}={d:.6}{s} {s} min={any} max={any} source={s}\n",
            .{
                entry.render_frame,
                entry.simulation_tick,
                entry.character_style,
                entry.view,
                entry.facing,
                entry.pose,
                entry.side,
                entry.component,
                entry.metric,
                entry.actual,
                entry.unit,
                @tagName(entry.outcome),
                entry.allowed_minimum,
                entry.allowed_maximum,
                entry.source,
            },
        );
        try text_file.writeStreamingAll(io, text);
        var minimum_buffer: [64]u8 = undefined;
        var maximum_buffer: [64]u8 = undefined;
        const minimum = try optionalNumber(&minimum_buffer, entry.allowed_minimum);
        const maximum = try optionalNumber(&maximum_buffer, entry.allowed_maximum);
        const json = try std.fmt.bufPrint(
            &line_buffer,
            "{s}{{\"case_id\":\"{s}\",\"render_frame\":{d},\"simulation_tick\":{d},\"character_style\":\"{s}\",\"view\":\"{s}\",\"facing\":\"{s}\",\"pose\":\"{s}\",\"outfit\":\"{s}\",\"morphology\":\"{s}\",\"component\":\"{s}\",\"side\":\"{s}\",\"metric\":\"{s}\",\"actual\":{d:.9},\"unit\":\"{s}\",\"allowed_minimum\":{s},\"allowed_maximum\":{s},\"source\":\"{s}\",\"outcome\":\"{s}\"}}",
            .{
                if (index == 0) "" else ",",
                entry.case_id,
                entry.render_frame,
                entry.simulation_tick,
                entry.character_style,
                entry.view,
                entry.facing,
                entry.pose,
                entry.outfit,
                entry.morphology,
                entry.component,
                entry.side,
                entry.metric,
                entry.actual,
                entry.unit,
                minimum,
                maximum,
                entry.source,
                @tagName(entry.outcome),
            },
        );
        try json_file.writeStreamingAll(io, json);
    }
    try json_file.writeStreamingAll(io, "]}\n");
}

fn optionalNumber(buffer: []u8, value: ?f32) ![]const u8 {
    if (value) |present| return std.fmt.bufPrint(buffer, "{d:.9}", .{present});
    return "null";
}

const ProductionPages = struct {
    male: image_decode.DecodedImage,
    female: image_decode.DecodedImage,
    components: image_decode.DecodedImage,
    upper: image_decode.DecodedImage,
    layers: image_decode.DecodedImage,
    lower: image_decode.DecodedImage,
    images: visual_geometry_audit.Images,

    fn init(allocator: std.mem.Allocator) !ProductionPages {
        var male = try image_decode.decodePngFile(
            allocator,
            "assets/art/p27c_male_base_anatomy_atlas.png",
            null,
        );
        errdefer male.deinit();
        var female = try image_decode.decodePngFile(
            allocator,
            "assets/art/p27c_female_base_anatomy_atlas.png",
            null,
        );
        errdefer female.deinit();
        var components = try image_decode.decodePngFile(
            allocator,
            "assets/art/p27c_anatomy_components_atlas.png",
            null,
        );
        errdefer components.deinit();
        var upper = try image_decode.decodePngFile(
            allocator,
            "assets/art/p25_wardrobe_upper_atlas.png",
            null,
        );
        errdefer upper.deinit();
        var layers = try image_decode.decodePngFile(
            allocator,
            "assets/art/p25_wardrobe_layers_atlas.png",
            null,
        );
        errdefer layers.deinit();
        var lower = try image_decode.decodePngFile(
            allocator,
            "assets/art/p25_wardrobe_lower_atlas.png",
            null,
        );
        errdefer lower.deinit();
        var images = visual_geometry_audit.Images{};
        try appendImage(&images, 1, male);
        try appendImage(&images, 2, female);
        try appendImage(&images, 3, components);
        try appendImage(&images, 4, upper);
        try appendImage(&images, 5, layers);
        try appendImage(&images, 6, lower);
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

    fn deinit(pages: *ProductionPages) void {
        pages.lower.deinit();
        pages.layers.deinit();
        pages.upper.deinit();
        pages.components.deinit();
        pages.female.deinit();
        pages.male.deinit();
        pages.* = undefined;
    }
};

fn appendImage(
    images: *visual_geometry_audit.Images,
    texture_page: u32,
    image: image_decode.DecodedImage,
) !void {
    try images.append(.{
        .texture_page = texture_page,
        .pixels = image.pixels,
        .width = image.layout.width,
        .height = image.layout.height,
        .row_bytes = image.layout.row_bytes,
    });
}
