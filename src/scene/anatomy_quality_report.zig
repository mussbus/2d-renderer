const std = @import("std");
const camera2d = @import("camera2d");
const image_decode = @import("image_decode");
const render_queue = @import("render_queue");
const presentation_view = @import("presentation_view");
const humanoid = @import("humanoid");
const wardrobe_demo = @import("wardrobe_demo");
const visual = @import("visual_geometry");
const audit = @import("visual_geometry_audit");
const anatomy_quality = @import("anatomy_quality");

const Expectation = enum { failures, pass };

const Options = struct {
    output_directory: []const u8 = "zig-out/p27c_evidence/final_semantic_report",
    expectation: Expectation = .pass,
};

const ViewCase = struct {
    view: visual.View,
    override: presentation_view.DebugOverride,
    facing: humanoid.Facing,
};

const views = [_]ViewCase{
    .{ .view = .front, .override = .force_front, .facing = .right },
    .{ .view = .side_right, .override = .force_side, .facing = .right },
    .{ .view = .side_left, .override = .force_side, .facing = .left },
};

const styles = [_][]const u8{ "male", "female" };

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    const options = try parseOptions(arguments);
    const allocator = std.heap.page_allocator;
    var scene = try wardrobe_demo.Scene.init(allocator);
    defer scene.deinit();
    try scene.enableVisualQualityAcceptance();
    const base = try scene.catalog.presetId("base_only");
    try scene.selectPreset(base);
    try scene.selectMalePreset(base);
    var queue = try render_queue.UnifiedRenderQueue.init(
        allocator,
        256,
        240,
        16,
        wardrobe_demo.combined_art_page_count + 1,
    );
    defer queue.deinit();
    queue.markStabilized();
    var pages = try ProductionPages.init(allocator);
    defer pages.deinit();

    var expected_storage: [128]anatomy_quality.MatrixCase = undefined;
    const expected = try buildExpectedMatrix(&expected_storage);
    var tracker = try anatomy_quality.MatrixTracker.init(expected);
    var report = visual.Report{};
    var trace_records: usize = 0;

    for (views) |view| {
        try evaluateFrame(
            &scene,
            &queue,
            &pages.images,
            &report,
            &tracker,
            &trace_records,
            view,
            "neutral",
            "nominal",
            null,
        );
    }

    for ([_]struct { value: f32, name: []const u8 }{
        .{ .value = 15, .name = "global_build_low" },
        .{ .value = 50, .name = "global_build_nominal" },
        .{ .value = 85, .name = "global_build_high" },
    }) |build| {
        try scene.male.setGlobalBuild(build.value);
        try scene.female.setGlobalBuild(build.value);
        for (views) |view| {
            try evaluateFrame(
                &scene,
                &queue,
                &pages.images,
                &report,
                &tracker,
                &trace_records,
                view,
                "neutral",
                build.name,
                null,
            );
        }
    }
    try scene.male.setGlobalBuild(50);
    try scene.female.setGlobalBuild(50);

    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    for ([_][]const u8{
        "shoulder_width",
        "torso_width",
        "upper_arm_thickness",
        "thigh_thickness",
        "calf_thickness",
    }) |channel_name| {
        const channel = try anatomy_definition.morphologyChannelId(channel_name);
        for ([_]struct { value: f32, suffix: []const u8 }{
            .{ .value = 20, .suffix = "low" },
            .{ .value = 80, .suffix = "high" },
        }) |sample| {
            try scene.male.setMorphologyChannelOverride(channel, sample.value);
            try scene.female.setMorphologyChannelOverride(channel, sample.value);
            const morphology = morphologyName(channel_name, sample.suffix);
            for (views) |view| {
                try evaluateFrame(
                    &scene,
                    &queue,
                    &pages.images,
                    &report,
                    &tracker,
                    &trace_records,
                    view,
                    "neutral",
                    morphology,
                    null,
                );
            }
        }
        try scene.male.setMorphologyChannelOverride(channel, null);
        try scene.female.setMorphologyChannelOverride(channel, null);
    }

    var frame: u32 = 0;
    while (frame < wardrobe_demo.visual_quality_required_frames) : (frame += 1) {
        try scene.updateVisualQualityFrame();
        const pose = poseName(frame) orelse continue;
        for (views[1..]) |view| {
            try evaluateFrame(
                &scene,
                &queue,
                &pages.images,
                &report,
                &tracker,
                &trace_records,
                view,
                pose,
                "nominal",
                "female",
            );
        }
    }

    try tracker.validateComplete();
    if (queue.lifetime_metrics.cpu_allocations_after_stabilization != 0 or
        scene.male.metrics.submission_allocations != 0 or
        scene.female.metrics.submission_allocations != 0)
    {
        return error.AnatomySteadyStateAllocation;
    }

    const human_buffer = try allocator.alloc(u8, 8 * 1024 * 1024);
    defer allocator.free(human_buffer);
    const json_buffer = try allocator.alloc(u8, 16 * 1024 * 1024);
    defer allocator.free(json_buffer);
    const human = try audit.formatHuman(&report, human_buffer);
    const json = try audit.formatJson(&report, json_buffer);
    try std.Io.Dir.cwd().createDirPath(init.io, options.output_directory);
    try writeNamed(init.io, options.output_directory, "report.txt", human);
    try writeNamed(init.io, options.output_directory, "report.json", json);
    const summary = try std.fmt.allocPrint(
        allocator,
        "{{\"schema\":\"prompt27c.anatomy-quality.summary.v1\",\"required_case_count\":{d},\"observed_case_count\":{d},\"trace_record_count\":{d},\"metric_count\":{d},\"failure_count\":{d},\"steady_state_queue_allocations\":0,\"steady_state_male_submission_allocations\":0,\"steady_state_female_submission_allocations\":0}}\n",
        .{ expected.len, expected.len, trace_records, report.count, report.failure_count },
    );
    defer allocator.free(summary);
    try writeNamed(init.io, options.output_directory, "summary.json", summary);
    std.log.info(
        "Prompt 27C anatomy report: cases={d} trace_records={d} metrics={d} failures={d} output={s}",
        .{ expected.len, trace_records, report.count, report.failure_count, options.output_directory },
    );
    switch (options.expectation) {
        .failures => if (report.failure_count == 0)
            return error.ExpectedAnatomyBaselineFailuresMissing,
        .pass => if (report.failure_count != 0)
            return error.ProductionAnatomyRejected,
    }
}

fn parseOptions(arguments: []const []const u8) !Options {
    var result = Options{};
    var index: usize = 1;
    while (index < arguments.len) : (index += 1) {
        if (std.mem.eql(u8, arguments[index], "--output")) {
            index += 1;
            if (index >= arguments.len) return error.MissingAnatomyReportOutput;
            result.output_directory = arguments[index];
        } else if (std.mem.eql(u8, arguments[index], "--expect-failures")) {
            result.expectation = .failures;
        } else if (std.mem.eql(u8, arguments[index], "--expect-pass")) {
            result.expectation = .pass;
        } else {
            return error.UnknownAnatomyReportArgument;
        }
    }
    return result;
}

fn buildExpectedMatrix(
    storage: *[128]anatomy_quality.MatrixCase,
) ![]const anatomy_quality.MatrixCase {
    var count: usize = 0;
    for (styles) |style| {
        for (views) |view| {
            try appendCase(storage, &count, .{
                .style = style,
                .view = view.view,
                .pose = "neutral",
                .morphology = "nominal",
            });
        }
    }
    for ([_][]const u8{
        "global_build_low",
        "global_build_nominal",
        "global_build_high",
    }) |morphology| {
        for (styles) |style| {
            for (views) |view| {
                try appendCase(storage, &count, .{
                    .style = style,
                    .view = view.view,
                    .pose = "neutral",
                    .morphology = morphology,
                });
            }
        }
    }
    for ([_][]const u8{
        "shoulder_width_low",
        "shoulder_width_high",
        "torso_width_low",
        "torso_width_high",
        "upper_arm_thickness_low",
        "upper_arm_thickness_high",
        "thigh_thickness_low",
        "thigh_thickness_high",
        "calf_thickness_low",
        "calf_thickness_high",
    }) |morphology| {
        for (styles) |style| {
            for (views) |view| {
                try appendCase(storage, &count, .{
                    .style = style,
                    .view = view.view,
                    .pose = "neutral",
                    .morphology = morphology,
                });
            }
        }
    }
    for ([_][]const u8{
        "walk_phase_0",
        "walk_phase_25",
        "walk_phase_50",
        "walk_phase_75",
        "deep_knee_bend",
        "jump_compression",
        "jump_rise",
        "jump_fall",
        "landing",
    }) |pose| {
        for (views[1..]) |view| {
            try appendCase(storage, &count, .{
                .style = "female",
                .view = view.view,
                .pose = pose,
                .morphology = "nominal",
            });
        }
    }
    return storage[0..count];
}

fn appendCase(
    storage: *[128]anatomy_quality.MatrixCase,
    count: *usize,
    value: anatomy_quality.MatrixCase,
) !void {
    if (count.* == storage.len) return error.AnatomyMatrixCapacityExceeded;
    storage[count.*] = value;
    count.* += 1;
}

fn evaluateFrame(
    scene: *wardrobe_demo.Scene,
    queue: *render_queue.UnifiedRenderQueue,
    images: *const audit.Images,
    report: *visual.Report,
    tracker: *anatomy_quality.MatrixTracker,
    trace_records: *usize,
    view: ViewCase,
    pose: []const u8,
    morphology: []const u8,
    style_filter: ?[]const u8,
) !void {
    try scene.male.setPresentationOverride(view.override);
    try scene.female.setPresentationOverride(view.override);
    try scene.male.setFacing(view.facing);
    try scene.female.setFacing(view.facing);
    var trace = visual.Trace{};
    queue.beginFrame();
    _ = try scene.submitTraced(queue, &trace);
    _ = queue.prepare();
    var filtered = visual.Trace{};
    const selected = if (style_filter) |required_style| blk: {
        for (trace.slice()) |record| {
            if (std.mem.eql(u8, record.style, required_style)) try filtered.append(record);
        }
        break :blk &filtered;
    } else &trace;
    trace_records.* += selected.count;
    try anatomy_quality.evaluate(selected, images, .{
        .outfit = "base_only",
        .pose = pose,
        .morphology = morphology,
        .camera = camera2d.Camera2D.initDefault(),
    }, report);
    for (selected.slice()) |record| {
        if (record.role != .torso or record.side != .none) continue;
        try tracker.observe(.{
            .style = record.style,
            .view = record.view,
            .pose = pose,
            .morphology = morphology,
        });
    }
}

fn morphologyName(channel: []const u8, suffix: []const u8) []const u8 {
    const low = std.mem.eql(u8, suffix, "low");
    if (std.mem.eql(u8, channel, "shoulder_width")) {
        return if (low) "shoulder_width_low" else "shoulder_width_high";
    }
    if (std.mem.eql(u8, channel, "torso_width")) {
        return if (low) "torso_width_low" else "torso_width_high";
    }
    if (std.mem.eql(u8, channel, "upper_arm_thickness")) {
        return if (low) "upper_arm_thickness_low" else "upper_arm_thickness_high";
    }
    if (std.mem.eql(u8, channel, "thigh_thickness")) {
        return if (low) "thigh_thickness_low" else "thigh_thickness_high";
    }
    if (std.mem.eql(u8, channel, "calf_thickness")) {
        return if (low) "calf_thickness_low" else "calf_thickness_high";
    }
    return "unknown_morphology";
}

fn poseName(frame: u32) ?[]const u8 {
    return switch (frame) {
        484 => "walk_phase_0",
        492 => "walk_phase_25",
        500 => "walk_phase_50",
        508 => "walk_phase_75",
        525 => "deep_knee_bend",
        540 => "jump_compression",
        550 => "jump_rise",
        575 => "jump_fall",
        599 => "landing",
        else => null,
    };
}

fn writeNamed(io: std.Io, directory: []const u8, name: []const u8, bytes: []const u8) !void {
    var path_buffer: [512]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ directory, name });
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}

const ProductionPages = struct {
    male: image_decode.DecodedImage,
    female: image_decode.DecodedImage,
    components: image_decode.DecodedImage,
    images: audit.Images,

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
        var images = audit.Images{};
        try appendImage(&images, 1, male);
        try appendImage(&images, 2, female);
        try appendImage(&images, 3, components);
        return .{
            .male = male,
            .female = female,
            .components = components,
            .images = images,
        };
    }

    fn deinit(pages: *ProductionPages) void {
        pages.components.deinit();
        pages.female.deinit();
        pages.male.deinit();
        pages.* = undefined;
    }
};

fn appendImage(
    images: *audit.Images,
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
