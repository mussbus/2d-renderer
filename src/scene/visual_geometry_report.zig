const std = @import("std");
const camera2d = @import("camera2d");
const image_decode = @import("image_decode");
const render_queue = @import("render_queue");
const wardrobe_demo = @import("wardrobe_demo");
const presentation_view = @import("presentation_view");
const humanoid = @import("humanoid");
const visual = @import("visual_geometry");
const audit = @import("visual_geometry_audit");

const output_directory = "zig-out/p25d_visual_geometry";

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    var scene = try wardrobe_demo.Scene.init(allocator);
    defer scene.deinit();
    try scene.enableVisualQualityAcceptance();
    var queue = try render_queue.UnifiedRenderQueue.init(
        allocator,
        256,
        240,
        16,
        wardrobe_demo.combined_art_page_count + 1,
    );
    defer queue.deinit();
    var decoded = try ProductionPages.init(allocator);
    defer decoded.deinit();
    var report = visual.Report{};
    var submitted_trace_records: usize = 0;
    try evaluateNeutralWardrobeMatrix(
        &scene,
        &queue,
        &decoded.images,
        &report,
        &submitted_trace_records,
    );
    try evaluateMorphologyMatrix(
        &scene,
        &queue,
        &decoded.images,
        &report,
        &submitted_trace_records,
    );
    try evaluatePoseMatrix(
        &scene,
        &queue,
        &decoded.images,
        &report,
        &submitted_trace_records,
    );
    const human_buffer = try allocator.alloc(u8, 4 * 1024 * 1024);
    defer allocator.free(human_buffer);
    const json_buffer = try allocator.alloc(u8, 8 * 1024 * 1024);
    defer allocator.free(json_buffer);
    const human = try audit.formatHuman(&report, human_buffer);
    const json = try audit.formatJson(&report, json_buffer);
    try std.Io.Dir.cwd().createDirPath(init.io, output_directory);
    try writeFile(init.io, output_directory ++ "/final_report.txt", human);
    try writeFile(init.io, output_directory ++ "/final_report.json", json);
    std.log.info(
        "Prompt 25D acceptance report: trace_records={d} metrics={d} production_failures={d} output={s}",
        .{ submitted_trace_records, report.count, report.failure_count, output_directory },
    );
    if (report.failure_count != 0) return error.ProductionVisualGeometryRejected;
}

fn evaluateNeutralWardrobeMatrix(
    scene: *wardrobe_demo.Scene,
    queue: *render_queue.UnifiedRenderQueue,
    images: *const audit.Images,
    report: *visual.Report,
    submitted_trace_records: *usize,
) !void {
    const views = [_]struct {
        override: presentation_view.DebugOverride,
        facing: humanoid.Facing,
    }{
        .{ .override = .force_front, .facing = .right },
        .{ .override = .force_side, .facing = .right },
        .{ .override = .force_side, .facing = .left },
    };
    for (scene.catalog.presets) |preset| {
        try scene.selectPreset(preset.id);
        try scene.male.selectEquipmentItems(preset.items());
        for (views) |view| {
            try evaluateFrame(
                scene,
                queue,
                images,
                report,
                submitted_trace_records,
                preset.stable_id,
                "neutral",
                view.override,
                view.facing,
            );
        }
    }
    try scene.selectCustom();
    const custom_items = try scene.catalog.customItems();
    try scene.male.selectEquipmentItems(&custom_items);
    for (views) |view| {
        try evaluateFrame(
            scene,
            queue,
            images,
            report,
            submitted_trace_records,
            "custom_outfit",
            "neutral",
            view.override,
            view.facing,
        );
    }
}

fn evaluateMorphologyMatrix(
    scene: *wardrobe_demo.Scene,
    queue: *render_queue.UnifiedRenderQueue,
    images: *const audit.Images,
    report: *visual.Report,
    submitted_trace_records: *usize,
) !void {
    try scene.selectPreset(try scene.catalog.presetId("wide_brim_crimson"));
    const wide_brim = try scene.catalog.preset(scene.current_preset);
    try scene.male.selectEquipmentItems(wide_brim.items());
    const views = [_]struct {
        override: presentation_view.DebugOverride,
        facing: humanoid.Facing,
    }{
        .{ .override = .force_front, .facing = .right },
        .{ .override = .force_side, .facing = .right },
        .{ .override = .force_side, .facing = .left },
    };
    for ([_]f32{ 15, 50, 85 }) |build| {
        try scene.male.setGlobalBuild(build);
        try scene.female.setGlobalBuild(build);
        const pose = if (build < 20) "build_low" else if (build > 80) "build_high" else "build_nominal";
        for (views) |view| {
            try evaluateFrame(
                scene,
                queue,
                images,
                report,
                submitted_trace_records,
                "wide_brim_crimson",
                pose,
                view.override,
                view.facing,
            );
        }
    }
    try scene.male.setGlobalBuild(50);
    try scene.female.setGlobalBuild(50);
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
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
            const pose = morphologyPoseName(name, value < 50);
            for (views) |view| {
                try evaluateFrame(
                    scene,
                    queue,
                    images,
                    report,
                    submitted_trace_records,
                    "wide_brim_crimson",
                    pose,
                    view.override,
                    view.facing,
                );
            }
        }
        try scene.male.setMorphologyChannelOverride(channel_id, null);
        try scene.female.setMorphologyChannelOverride(channel_id, null);
    }
}

fn morphologyPoseName(channel: []const u8, low: bool) []const u8 {
    if (std.mem.eql(u8, channel, "shoulder_width")) {
        return if (low) "shoulder_width_low" else "shoulder_width_high";
    }
    if (std.mem.eql(u8, channel, "hip_width")) {
        return if (low) "hip_width_low" else "hip_width_high";
    }
    if (std.mem.eql(u8, channel, "upper_arm_thickness")) {
        return if (low) "upper_arm_thickness_low" else "upper_arm_thickness_high";
    }
    if (std.mem.eql(u8, channel, "thigh_thickness")) {
        return if (low) "thigh_thickness_low" else "thigh_thickness_high";
    }
    if (std.mem.eql(u8, channel, "hand_scale")) {
        return if (low) "hand_scale_low" else "hand_scale_high";
    }
    if (std.mem.eql(u8, channel, "foot_scale")) {
        return if (low) "foot_scale_low" else "foot_scale_high";
    }
    return if (low) "morphology_low" else "morphology_high";
}

fn evaluatePoseMatrix(
    scene: *wardrobe_demo.Scene,
    queue: *render_queue.UnifiedRenderQueue,
    images: *const audit.Images,
    report: *visual.Report,
    submitted_trace_records: *usize,
) !void {
    var frame: u32 = 0;
    while (frame < wardrobe_demo.visual_quality_required_frames) : (frame += 1) {
        try scene.updateVisualQualityFrame();
        const pose: ?[]const u8 = if (frame == 484)
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
        else if (frame == 599)
            "landing"
        else
            null;
        if (pose) |name| {
            const preset = try scene.catalog.preset(scene.current_preset);
            for ([_]humanoid.Facing{ .right, .left }) |facing| {
                try evaluateFrame(
                    scene,
                    queue,
                    images,
                    report,
                    submitted_trace_records,
                    preset.stable_id,
                    name,
                    .force_side,
                    facing,
                );
            }
        }
    }
}

fn evaluateFrame(
    scene: *wardrobe_demo.Scene,
    queue: *render_queue.UnifiedRenderQueue,
    images: *const audit.Images,
    report: *visual.Report,
    submitted_trace_records: *usize,
    outfit: []const u8,
    pose: []const u8,
    override: presentation_view.DebugOverride,
    facing: humanoid.Facing,
) !void {
    try scene.male.setPresentationOverride(override);
    try scene.female.setPresentationOverride(override);
    try scene.male.setFacing(facing);
    try scene.female.setFacing(facing);
    var trace = visual.Trace{};
    queue.beginFrame();
    _ = try scene.submitTraced(queue, &trace);
    _ = queue.prepare();
    submitted_trace_records.* += trace.count;
    try audit.evaluateCurrentProduction(&trace, images, .{
        .outfit = outfit,
        .pose = pose,
        .camera = camera2d.Camera2D.initDefault(),
    }, report);
}

fn writeFile(io: std.Io, path: []const u8, bytes: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}

const ProductionPages = struct {
    male: image_decode.DecodedImage,
    female: image_decode.DecodedImage,
    components: image_decode.DecodedImage,
    upper: image_decode.DecodedImage,
    layers: image_decode.DecodedImage,
    lower: image_decode.DecodedImage,
    images: audit.Images,

    fn init(allocator: std.mem.Allocator) !ProductionPages {
        var male = try image_decode.decodePngFile(
            allocator,
            "assets/art/male_base_anatomy_atlas.png",
            null,
        );
        errdefer male.deinit();
        var female = try image_decode.decodePngFile(
            allocator,
            "assets/art/female_base_anatomy_atlas.png",
            null,
        );
        errdefer female.deinit();
        var components = try image_decode.decodePngFile(
            allocator,
            "assets/art/anatomy_components_atlas.png",
            null,
        );
        errdefer components.deinit();
        var upper = try image_decode.decodePngFile(
            allocator,
            "assets/art/wardrobe_upper_atlas.png",
            null,
        );
        errdefer upper.deinit();
        var layers = try image_decode.decodePngFile(
            allocator,
            "assets/art/wardrobe_layers_atlas.png",
            null,
        );
        errdefer layers.deinit();
        var lower = try image_decode.decodePngFile(
            allocator,
            "assets/art/wardrobe_lower_atlas.png",
            null,
        );
        errdefer lower.deinit();
        var images = audit.Images{};
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
