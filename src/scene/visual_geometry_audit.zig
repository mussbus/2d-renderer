const std = @import("std");
const math = @import("math");
const camera2d = @import("camera2d");
const sprite = @import("sprite_batch");
const visual = @import("visual_geometry");

pub const maximum_pages: usize = 8;

pub const PageImage = struct {
    texture_page: u32,
    pixels: []const u8,
    width: u32,
    height: u32,
    row_bytes: u32,
};

pub const Images = struct {
    pages: [maximum_pages]PageImage = undefined,
    count: usize = 0,

    pub fn append(images: *Images, page: PageImage) !void {
        if (images.count == images.pages.len) return error.VisualGeometryPageCapacityExceeded;
        if (page.width == 0 or page.height == 0 or
            page.row_bytes < page.width * 4 or
            page.pixels.len < @as(usize, page.row_bytes) * page.height)
        {
            return error.InvalidVisualGeometryPage;
        }
        for (images.pages[0..images.count]) |existing| {
            if (existing.texture_page == page.texture_page) return error.DuplicateVisualGeometryPage;
        }
        images.pages[images.count] = page;
        images.count += 1;
    }

    pub fn find(images: *const Images, texture_page: u32) !PageImage {
        for (images.pages[0..images.count]) |page| {
            if (page.texture_page == texture_page) return page;
        }
        return error.MissingVisualGeometryPage;
    }
};

pub const EvaluationContext = struct {
    outfit: []const u8,
    pose: []const u8,
    morphology: []const u8 = "nominal",
    camera: camera2d.Camera2D,
};

pub const Golden = struct {
    approved: bool,
    sha256: [32]u8,
};

pub const GoldenComparison = enum {
    unapproved,
    match,
    changed,
};

pub fn hashCapture(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}

pub fn compareGolden(bytes: []const u8, golden: Golden) GoldenComparison {
    if (!golden.approved) return .unapproved;
    return if (std.mem.eql(u8, &hashCapture(bytes), &golden.sha256)) .match else .changed;
}

pub fn formatHuman(report: *const visual.Report, buffer: []u8) ![]const u8 {
    var offset: usize = 0;
    try appendFormat(buffer, &offset, "semantic_visual_geometry metrics={d} failures={d}\n", .{
        report.count,
        report.failure_count,
    });
    for (report.metrics[0..report.count]) |entry| {
        try appendFormat(
            buffer,
            &offset,
            "{s}/{s}/{s}/{s}/{s}/{s}/{s} {s}={d:.3}{s} {s} min={any} max={any} source={s}\n",
            .{
                entry.character_style,
                @tagName(entry.view),
                entry.outfit,
                entry.pose,
                entry.morphology,
                @tagName(entry.side),
                entry.component,
                entry.metric,
                entry.actual,
                entry.unit,
                @tagName(entry.outcome),
                entry.minimum,
                entry.maximum,
                entry.source,
            },
        );
    }
    return buffer[0..offset];
}

pub fn formatJson(report: *const visual.Report, buffer: []u8) ![]const u8 {
    var offset: usize = 0;
    try appendFormat(buffer, &offset, "{{\"schema\":\"prompt25c.semantic-visual-geometry.v1\",\"metric_count\":{d},\"failure_count\":{d},\"metrics\":[", .{
        report.count,
        report.failure_count,
    });
    for (report.metrics[0..report.count], 0..) |entry, index| {
        if (index != 0) try appendFormat(buffer, &offset, ",", .{});
        try appendFormat(
            buffer,
            &offset,
            "{{\"style\":\"{s}\",\"view\":\"{s}\",\"outfit\":\"{s}\",\"pose\":\"{s}\",\"morphology\":\"{s}\",\"side\":\"{s}\",\"component\":\"{s}\",\"metric\":\"{s}\",\"actual\":{d:.6},\"unit\":\"{s}\",\"source\":\"{s}\",\"minimum\":",
            .{
                entry.character_style,
                @tagName(entry.view),
                entry.outfit,
                entry.pose,
                entry.morphology,
                @tagName(entry.side),
                entry.component,
                entry.metric,
                entry.actual,
                entry.unit,
                entry.source,
            },
        );
        if (entry.minimum) |value|
            try appendFormat(buffer, &offset, "{d:.6}", .{value})
        else
            try appendFormat(buffer, &offset, "null", .{});
        try appendFormat(buffer, &offset, ",\"maximum\":", .{});
        if (entry.maximum) |value|
            try appendFormat(buffer, &offset, "{d:.6}", .{value})
        else
            try appendFormat(buffer, &offset, "null", .{});
        try appendFormat(buffer, &offset, ",\"outcome\":\"{s}\"}}", .{@tagName(entry.outcome)});
    }
    try appendFormat(buffer, &offset, "]}}\n", .{});
    return buffer[0..offset];
}

fn appendFormat(buffer: []u8, offset: *usize, comptime format: []const u8, args: anytype) !void {
    if (offset.* > buffer.len) return error.VisualGeometryReportBufferTooSmall;
    const written = std.fmt.bufPrint(buffer[offset.*..], format, args) catch
        return error.VisualGeometryReportBufferTooSmall;
    offset.* += written.len;
}

pub fn evaluateCurrentProduction(
    trace: *const visual.Trace,
    images: *const Images,
    context: EvaluationContext,
    report: *visual.Report,
) !void {
    if (trace.count == 0) return error.EmptyVisualGeometryTrace;
    try report.recordRange(metric(
        trace.records[0],
        context,
        "trace_component_count",
        @floatFromInt(trace.count),
        "components",
    ), 1, @floatFromInt(visual.trace_capacity));
    try evaluateFootwear(trace, images, context, report);
    try evaluateGarmentFit(trace, images, context, report);
    try evaluateJointContinuity(trace, images, context, report);
    try evaluateProportions(trace, images, context, report);
    try evaluateFrontSymmetry(trace, images, context, report);
}

fn evaluateFootwear(
    trace: *const visual.Trace,
    images: *const Images,
    context: EvaluationContext,
    report: *visual.Report,
) !void {
    for (trace.records[0..trace.count]) |*shoe| {
        if (shoe.role != .shoe or shoe.owner != .equipment) continue;
        const foot = findTargetForAttachment(trace, shoe, .foot) orelse
            return error.MissingVisualGeometryTarget;
        const opposite = findRecord(
            trace,
            shoe.character_id,
            .foot,
            if (shoe.side == .left) .right else .left,
            null,
        );
        const foot_alpha = try alphaFor(foot, images);
        const shoe_alpha = try alphaFor(shoe, images);
        const contract = shoe.fit orelse return error.MissingVisualFitContract;

        try report.append(metric(
            shoe.*,
            context,
            "semantic_binding_id",
            @floatFromInt(shoe.semantic_id),
            "id",
        ));
        try report.append(metric(
            shoe.*,
            context,
            "bound_anatomy_identity",
            @floatFromInt(shoe.bound_identity),
            "id",
        ));
        try registrationMetric(report, context, foot, shoe, foot_alpha, shoe_alpha, .ankle, contract.registration_tolerance_px);
        try registrationMetric(report, context, foot, shoe, foot_alpha, shoe_alpha, .heel, contract.registration_tolerance_px);
        try registrationMetric(report, context, foot, shoe, foot_alpha, shoe_alpha, .toe, contract.registration_tolerance_px);

        const foot_heel = try visual.resolveLandmark(foot.*, foot_alpha, .heel, context.camera);
        const foot_toe = try visual.resolveLandmark(foot.*, foot_alpha, .toe, context.camera);
        const shoe_heel = try visual.resolveLandmark(shoe.*, shoe_alpha, .heel, context.camera);
        const shoe_toe = try visual.resolveLandmark(shoe.*, shoe_alpha, .toe, context.camera);
        const forward_angle = try visual.angleDegrees(
            foot_heel.pixel,
            foot_toe.pixel,
            shoe_heel.pixel,
            shoe_toe.pixel,
        );
        try report.recordMaximum(metric(
            shoe.*,
            context,
            "forward_axis_error",
            forward_angle,
            "deg",
        ), contract.axis_tolerance_degrees);

        const foot_sole_back = try visual.resolveLandmark(foot.*, foot_alpha, .sole_back, context.camera);
        const foot_sole_front = try visual.resolveLandmark(foot.*, foot_alpha, .sole_front, context.camera);
        const shoe_sole_back = try visual.resolveLandmark(shoe.*, shoe_alpha, .sole_back, context.camera);
        const shoe_sole_front = try visual.resolveLandmark(shoe.*, shoe_alpha, .sole_front, context.camera);
        const sole_angle = try visual.angleDegrees(
            foot_sole_back.pixel,
            foot_sole_front.pixel,
            shoe_sole_back.pixel,
            shoe_sole_front.pixel,
        );
        try report.recordMaximum(metric(
            shoe.*,
            context,
            "sole_axis_error",
            sole_angle,
            "deg",
        ), contract.sole_tolerance_degrees);

        const foot_length = visual.distance(foot_heel.pixel, foot_toe.pixel);
        const shoe_length = visual.distance(shoe_heel.pixel, shoe_toe.pixel);
        const ratio = if (foot_length > std.math.floatEps(f32)) shoe_length / foot_length else 0;
        try report.recordRange(metric(
            shoe.*,
            context,
            "visible_length_ratio",
            ratio,
            "ratio",
        ), contract.minimum_length_ratio, contract.maximum_length_ratio);

        const stats = try coverageStats(
            foot.*,
            shoe.*,
            opposite,
            images,
            context.camera,
            contract.coverageZone(shoe.view),
            contract.clearance_px,
            contract.coverage_mode,
        );
        if (contract.validate_coverage) {
            try report.recordRange(metric(
                shoe.*,
                context,
                "declared_foot_coverage",
                stats.coverage(),
                "ratio",
            ), contract.minimumCoverage(shoe.view), 1.0);
        }
        if (contract.validate_off_target) {
            try report.recordMaximum(metric(
                shoe.*,
                context,
                "off_target_shoe_fraction",
                stats.offTarget(),
                "ratio",
            ), contract.maximum_off_target);
        }
        // Bilateral feet intentionally overlap in profile projection. Crossing
        // is only a side-identity failure in the front presentation, where the
        // two semantic feet occupy disjoint screen regions.
        if (shoe.view == .front) {
            try report.recordMaximum(metric(
                shoe.*,
                context,
                "opposite_foot_crossing",
                @floatFromInt(stats.opposite_target_pixels),
                "px",
            ), 0);
        }
    }
}

fn evaluateGarmentFit(
    trace: *const visual.Trace,
    images: *const Images,
    context: EvaluationContext,
    report: *visual.Report,
) !void {
    for (trace.records[0..trace.count]) |*attachment| {
        if (attachment.owner == .anatomy or
            attachment.owner == .base_presentation or
            attachment.role == .shoe)
        {
            continue;
        }
        const contract = attachment.fit orelse return error.MissingVisualFitContract;
        const target_role: visual.Role = switch (attachment.role) {
            .torso_garment => .torso,
            .lower_garment, .waist_accessory => .pelvis,
            .sleeve => .upper_arm,
            .glove => .hand,
            .legwear => .shin,
            .headwear => .head,
            else => continue,
        };
        const target = findTargetForAttachment(trace, attachment, target_role) orelse
            return error.MissingVisualGeometryTarget;
        const target_alpha = try alphaFor(target, images);
        const attachment_alpha = try alphaFor(attachment, images);

        switch (contract.design) {
            .torso_sleeveless => {
                try registrationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .neck, contract.registration_tolerance_px);
                try spanMetric(report, context, target, attachment, target_alpha, attachment_alpha, .chest_left, .chest_right, "chest_fit_ratio", contract);
                try spanMetric(report, context, target, attachment, target_alpha, attachment_alpha, .waist_left, .waist_right, "waist_fit_ratio", contract);
                try garmentCoverageMetric(report, context, target.*, attachment.*, images, contract, "torso_intended_coverage");
            },
            .torso_fitted, .torso_outer => {
                try registrationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .neck, contract.registration_tolerance_px);
                try spanMetric(report, context, target, attachment, target_alpha, attachment_alpha, .shoulder, .proximal, "shoulder_fit_ratio", contract);
                try spanMetric(report, context, target, attachment, target_alpha, attachment_alpha, .waist_left, .waist_right, "waist_fit_ratio", contract);
                try orientationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .shoulder, .proximal, .shoulder, .proximal, "torso_orientation_error", contract.axis_tolerance_degrees);
                try garmentCoverageMetric(report, context, target.*, attachment.*, images, contract, "torso_intended_coverage");
            },
            .lower_shorts, .lower_mini, .lower_pants, .lower_long => {
                try pairedSpanCenterRegistrationMetric(
                    report,
                    context,
                    target,
                    attachment,
                    target_alpha,
                    attachment_alpha,
                    .waist_left,
                    .waist_right,
                    "waist_registration",
                    contract.registration_tolerance_px,
                );
                try spanMetric(report, context, target, attachment, target_alpha, attachment_alpha, .waist_left, .waist_right, "waist_fit_ratio", contract);
                try spanMetric(report, context, target, attachment, target_alpha, attachment_alpha, .hip, .proximal, "hip_fit_ratio", contract);
                if (contract.design == .lower_shorts or contract.design == .lower_mini) {
                    // A leg opening is an authored interval, not a zero-width
                    // point. Profile projection does not expose independent
                    // bilateral openings, so the bilateral containment check
                    // applies only to the front presentation.
                    if (attachment.view != .front) {
                        try garmentCoverageMetric(report, context, target.*, attachment.*, images, contract, "lower_intended_coverage");
                        continue;
                    }
                    for ([_]struct {
                        side: visual.Side,
                        opening: visual.LandmarkKind,
                        name: []const u8,
                    }{
                        .{ .side = .left, .opening = .leg_opening_left, .name = "left_leg_opening_error" },
                        .{ .side = .right, .opening = .leg_opening_right, .name = "right_leg_opening_error" },
                    }) |opening| {
                        const thigh = findRecord(trace, attachment.character_id, .thigh, opening.side, null) orelse
                            return error.MissingVisualGeometryTarget;
                        const thigh_alpha = try alphaFor(thigh, images);
                        try pairedLateralRegistrationMetric(
                            report,
                            context,
                            thigh,
                            attachment,
                            thigh_alpha,
                            attachment_alpha,
                            .hip,
                            opening.opening,
                            opening.name,
                            contract.registration_tolerance_px,
                            contract.leg_opening_half_width_visible_uv,
                        );
                    }
                }
                try garmentCoverageMetric(report, context, target.*, attachment.*, images, contract, "lower_intended_coverage");
            },
            .sleeve_fitted, .sleeve_puff => {
                try pairedRegistrationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .shoulder, .proximal, "attachment_registration", contract.registration_tolerance_px);
                try orientationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .shoulder, .elbow, .proximal, .distal, "attachment_axis_error", contract.axis_tolerance_degrees);
                try garmentCoverageMetric(report, context, target.*, attachment.*, images, contract, "attachment_intended_coverage");
            },
            .glove_long, .wrist_cuff => {
                try pairedRegistrationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .wrist, .wrist, "attachment_registration", contract.registration_tolerance_px);
                if (contract.design == .glove_long) {
                    try orientationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .wrist, .fingertip, .wrist, .fingertip, "attachment_axis_error", contract.axis_tolerance_degrees);
                }
                if (contract.secondary_target_role) |secondary_role| {
                    const secondary = findRecord(
                        trace,
                        attachment.character_id,
                        secondary_role,
                        attachment.side,
                        null,
                    ) orelse return error.MissingVisualGeometryTarget;
                    try compositeGarmentCoverageMetric(
                        report,
                        context,
                        target.*,
                        secondary.*,
                        attachment.*,
                        images,
                        contract,
                        "attachment_intended_coverage",
                    );
                } else {
                    try garmentCoverageMetric(
                        report,
                        context,
                        target.*,
                        attachment.*,
                        images,
                        contract,
                        "attachment_intended_coverage",
                    );
                }
            },
            .legwear_fitted => {
                try pairedRegistrationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .knee, .proximal, "attachment_registration", contract.registration_tolerance_px);
                try orientationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .knee, .ankle, .proximal, .ankle, "attachment_axis_error", contract.axis_tolerance_degrees);
                try garmentCoverageMetric(report, context, target.*, attachment.*, images, contract, "attachment_intended_coverage");
            },
            .headwear_wide, .headwear_band, .headwear_fitted => {
                try pairedRegistrationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .headwear_fit, .opening, "head_fit_registration", contract.registration_tolerance_px);
                try orientationMetric(report, context, target, attachment, target_alpha, attachment_alpha, .proximal, .distal, .proximal, .distal, "headwear_orientation_error", contract.axis_tolerance_degrees);
            },
            .waist_sash, .waist_belt => {
                try spanMetric(report, context, target, attachment, target_alpha, attachment_alpha, .waist_left, .waist_right, "waist_accessory_fit_ratio", contract);
            },
            .shoe_strap => return error.ShoeEvaluatedAsGarment,
        }
    }
}

fn evaluateJointContinuity(
    trace: *const visual.Trace,
    images: *const Images,
    context: EvaluationContext,
    report: *visual.Report,
) !void {
    const pairs = [_]struct {
        parent: visual.Role,
        child: visual.Role,
        parent_landmark: visual.LandmarkKind,
        child_landmark: visual.LandmarkKind,
        name: []const u8,
    }{
        .{ .parent = .upper_arm, .child = .forearm, .parent_landmark = .elbow, .child_landmark = .elbow, .name = "elbow" },
        .{ .parent = .forearm, .child = .hand, .parent_landmark = .wrist, .child_landmark = .wrist, .name = "wrist" },
        .{ .parent = .thigh, .child = .shin, .parent_landmark = .knee, .child_landmark = .knee, .name = "knee" },
        .{ .parent = .shin, .child = .foot, .parent_landmark = .ankle, .child_landmark = .ankle, .name = "ankle" },
    };
    for ([_]u32{ 1, 2 }) |character_id| {
        for ([_]visual.Side{ .left, .right }) |side| {
            for (pairs) |pair| {
                const continuity_contract = visual.continuityContract(pair.parent, pair.child);
                const parent = findRecord(trace, character_id, pair.parent, side, null) orelse continue;
                const child = findRecord(trace, character_id, pair.child, side, null) orelse continue;
                const parent_alpha = try alphaFor(parent, images);
                const child_alpha = try alphaFor(child, images);
                const parent_joint = try visual.resolveLandmark(parent.*, parent_alpha, pair.parent_landmark, context.camera);
                const child_joint = try visual.resolveLandmark(child.*, child_alpha, pair.child_landmark, context.camera);
                const semantic_error = visual.distance(parent_joint.pixel, child_joint.pixel);
                try report.recordMaximum(metric(
                    child.*,
                    context,
                    pair.name,
                    semantic_error,
                    "px semantic_error",
                ), 2.0);
                const continuity = try continuityStats(
                    parent.*,
                    child.*,
                    parent_joint.pixel.add(child_joint.pixel).scale(0.5),
                    images,
                    context.camera,
                );
                try report.recordMaximum(metric(
                    child.*,
                    context,
                    if (std.mem.eql(u8, pair.name, "elbow")) "elbow_visible_gap" else "joint_visible_gap",
                    continuity.gap_px,
                    "px",
                ), continuity_contract.maximum_gap_px);
                try report.recordMaximum(metric(
                    child.*,
                    context,
                    if (std.mem.eql(u8, pair.name, "elbow")) "elbow_visible_overlap_depth" else "joint_visible_overlap_depth",
                    continuity.overlap_equivalent_depth_px,
                    "px",
                ), continuity_contract.maximum_overlap_px);
            }
        }
    }
    const root_pairs = [_]struct {
        parent: visual.Role,
        child: visual.Role,
        left_landmark: visual.LandmarkKind,
        right_landmark: visual.LandmarkKind,
        child_landmark: visual.LandmarkKind,
        name: []const u8,
    }{
        .{
            .parent = .torso,
            .child = .upper_arm,
            .left_landmark = .shoulder_left,
            .right_landmark = .shoulder_right,
            .child_landmark = .shoulder,
            .name = "shoulder",
        },
        .{
            .parent = .pelvis,
            .child = .thigh,
            .left_landmark = .hip_left,
            .right_landmark = .hip_right,
            .child_landmark = .hip,
            .name = "hip_pelvis",
        },
    };
    for ([_]u32{ 1, 2 }) |character_id| {
        for ([_]visual.Side{ .left, .right }) |side| {
            for (root_pairs) |pair| {
                const continuity_contract = visual.continuityContract(pair.parent, pair.child);
                const parent = findRecord(trace, character_id, pair.parent, .none, null) orelse continue;
                const child = findRecord(trace, character_id, pair.child, side, null) orelse continue;
                const parent_alpha = try alphaFor(parent, images);
                const child_alpha = try alphaFor(child, images);
                const parent_kind = if (side == .left) pair.left_landmark else pair.right_landmark;
                const parent_joint = try visual.resolveLandmark(parent.*, parent_alpha, parent_kind, context.camera);
                const child_joint = try visual.resolveLandmark(child.*, child_alpha, pair.child_landmark, context.camera);
                try report.recordMaximum(metric(
                    child.*,
                    context,
                    pair.name,
                    visual.distance(parent_joint.pixel, child_joint.pixel),
                    "px semantic_error",
                ), 2.0);
                const continuity = try continuityStats(
                    parent.*,
                    child.*,
                    parent_joint.pixel.add(child_joint.pixel).scale(0.5),
                    images,
                    context.camera,
                );
                const root_axis = try bindingAxis(parent.*, child.*, context.camera);
                const parent_axis_span = try projectedVisibleAxisSpan(
                    parent.*,
                    parent_alpha,
                    root_axis,
                    context.camera,
                );
                const maximum_overlap = continuity_contract.maximumOverlapForParentSpan(
                    parent_axis_span,
                );
                try report.recordMaximum(metric(
                    child.*,
                    context,
                    if (pair.parent == .torso) "shoulder_visible_gap" else "hip_visible_gap",
                    continuity.gap_px,
                    "px",
                ), continuity_contract.maximum_gap_px);
                try report.recordMaximum(metric(
                    child.*,
                    context,
                    if (pair.parent == .torso) "shoulder_visible_overlap_depth" else "hip_visible_overlap_depth",
                    continuity.overlap_equivalent_depth_px,
                    "px",
                ), maximum_overlap);
                if (continuity_contract.maximum_overlap_parent_span_ratio) |maximum_ratio| {
                    const overlap_ratio = if (parent_axis_span > std.math.floatEps(f32))
                        continuity.overlap_equivalent_depth_px / parent_axis_span
                    else
                        std.math.inf(f32);
                    try report.recordMaximum(metric(
                        child.*,
                        context,
                        "shoulder_visible_overlap_parent_span_ratio",
                        overlap_ratio,
                        "ratio",
                    ), maximum_ratio);
                }
            }
        }
    }
}

fn evaluateProportions(
    trace: *const visual.Trace,
    images: *const Images,
    context: EvaluationContext,
    report: *visual.Report,
) !void {
    for ([_]u32{ 1, 2 }) |character_id| {
        for ([_]visual.Side{ .left, .right }) |side| {
            const forearm = findRecord(trace, character_id, .forearm, side, null) orelse continue;
            const hand = findRecord(trace, character_id, .hand, side, null) orelse continue;
            const forearm_alpha = try alphaFor(forearm, images);
            const hand_alpha = try alphaFor(hand, images);
            const forearm_a = try visual.resolveLandmark(forearm.*, forearm_alpha, .elbow, context.camera);
            const forearm_b = try visual.resolveLandmark(forearm.*, forearm_alpha, .wrist, context.camera);
            const hand_a = try visual.resolveLandmark(hand.*, hand_alpha, .wrist, context.camera);
            const hand_b = try visual.resolveLandmark(hand.*, hand_alpha, .fingertip, context.camera);
            const forearm_length = visual.distance(forearm_a.pixel, forearm_b.pixel);
            const hand_length = visual.distance(hand_a.pixel, hand_b.pixel);
            const ratio = if (forearm_length > std.math.floatEps(f32)) hand_length / forearm_length else 0;
            // These bounds belong to the conventional presentation contract,
            // not a global human-proportion rule. Other profiles may declare
            // different ranges.
            try report.recordRange(metric(
                hand.*,
                context,
                "hand_to_forearm_ratio",
                ratio,
                "ratio",
            ), 0.42 * hand.morphology_length_scale / forearm.morphology_length_scale, 0.62 * hand.morphology_length_scale / forearm.morphology_length_scale);

            const span_pairs = [_]struct {
                parent: visual.Role,
                child: visual.Role,
                start: visual.LandmarkKind,
                end: visual.LandmarkKind,
                name: []const u8,
                minimum: f32,
                maximum: f32,
            }{
                .{ .parent = .upper_arm, .child = .forearm, .start = .shoulder, .end = .elbow, .name = "upper_arm_to_skeleton_span", .minimum = 0.82, .maximum = 1.18 },
                .{ .parent = .forearm, .child = .hand, .start = .elbow, .end = .wrist, .name = "forearm_to_skeleton_span", .minimum = 0.82, .maximum = 1.18 },
                .{ .parent = .thigh, .child = .shin, .start = .hip, .end = .knee, .name = "thigh_to_skeleton_span", .minimum = 0.82, .maximum = 1.18 },
                .{ .parent = .shin, .child = .foot, .start = .knee, .end = .ankle, .name = "shin_to_skeleton_span", .minimum = 0.82, .maximum = 1.18 },
            };
            for (span_pairs) |pair| {
                const parent = findRecord(trace, character_id, pair.parent, side, null) orelse continue;
                const child = findRecord(trace, character_id, pair.child, side, null) orelse continue;
                const parent_alpha = try alphaFor(parent, images);
                const visible_start = try visual.resolveLandmark(parent.*, parent_alpha, pair.start, context.camera);
                const visible_end = try visual.resolveLandmark(parent.*, parent_alpha, pair.end, context.camera);
                const rendered_span = visual.distance(visible_start.pixel, visible_end.pixel);
                const parent_binding = try context.camera.worldToPresentation(.{
                    .x = parent.request.world_position[0],
                    .y = parent.request.world_position[1],
                }, parent.request.camera_x_factor);
                const child_binding = try context.camera.worldToPresentation(.{
                    .x = child.request.world_position[0],
                    .y = child.request.world_position[1],
                }, child.request.camera_x_factor);
                const skeleton_span = visual.distance(parent_binding, child_binding);
                const span_ratio = if (skeleton_span > std.math.floatEps(f32))
                    rendered_span / skeleton_span
                else
                    0;
                try report.recordRange(metric(
                    parent.*,
                    context,
                    pair.name,
                    span_ratio,
                    "ratio",
                ), pair.minimum, pair.maximum);
            }

            const foot = findRecord(trace, character_id, .foot, side, null) orelse continue;
            const shin = findRecord(trace, character_id, .shin, side, null) orelse continue;
            const foot_alpha = try alphaFor(foot, images);
            const heel = try visual.resolveLandmark(foot.*, foot_alpha, .heel, context.camera);
            const toe = try visual.resolveLandmark(foot.*, foot_alpha, .toe, context.camera);
            const shin_alpha = try alphaFor(shin, images);
            const knee = try visual.resolveLandmark(shin.*, shin_alpha, .knee, context.camera);
            const ankle = try visual.resolveLandmark(shin.*, shin_alpha, .ankle, context.camera);
            const lower_leg_span = visual.distance(knee.pixel, ankle.pixel);
            const foot_ratio = if (lower_leg_span > std.math.floatEps(f32))
                visual.distance(heel.pixel, toe.pixel) / lower_leg_span
            else
                0;
            try report.recordRange(metric(
                foot.*,
                context,
                "foot_to_lower_leg_ratio",
                foot_ratio,
                "ratio",
            ), 0.24, 0.62);
        }
    }
}

fn evaluateFrontSymmetry(
    trace: *const visual.Trace,
    images: *const Images,
    context: EvaluationContext,
    report: *visual.Report,
) !void {
    if (context.camera.viewport_width == 0) return;
    // Conventional-profile symmetry is a neutral-pose contract. Walk, jump,
    // landing, and authored morphology sweeps may intentionally contain
    // bilateral pose asymmetry and are covered by their attachment/joint
    // contracts instead.
    if (!std.mem.eql(u8, context.pose, "neutral")) return;
    for ([_]u32{ 1, 2 }) |character_id| {
        const torso = findRecord(trace, character_id, .torso, .none, null) orelse continue;
        if (torso.view != .front) continue;
        const pelvis = findRecord(trace, character_id, .pelvis, .none, null) orelse
            return error.MissingVisualGeometryTarget;
        // Bilateral anatomy is symmetric about the authoritative submitted
        // skeleton centerline. Deriving that axis from painted torso/pelvis
        // alpha edges made a deliberately asymmetric silhouette tilt the
        // ruler itself and falsely report symmetric bone submissions as bad.
        const torso_center = try context.camera.worldToPresentation(
            .{
                .x = torso.request.world_position[0],
                .y = torso.request.world_position[1],
            },
            torso.request.camera_x_factor,
        );
        const pelvis_center = try context.camera.worldToPresentation(
            .{
                .x = pelvis.request.world_position[0],
                .y = pelvis.request.world_position[1],
            },
            pelvis.request.camera_x_factor,
        );
        const centerline = torso_center.sub(pelvis_center);
        const centerline_length = centerline.length();
        if (centerline_length <= std.math.floatEps(f32)) {
            return error.DegeneratePresentationSymmetryAxis;
        }
        const centerline_unit = centerline.scale(1.0 / centerline_length);
        for ([_]visual.Role{ .upper_arm, .forearm, .hand, .thigh, .shin, .foot, .shoe }) |role| {
            const left = findRecord(trace, character_id, role, .left, null) orelse continue;
            const right = findRecord(trace, character_id, role, .right, null) orelse continue;
            const left_alpha = try alphaFor(left, images);
            const right_alpha = try alphaFor(right, images);
            const kind: visual.LandmarkKind = switch (role) {
                .upper_arm => .shoulder,
                .forearm => .elbow,
                .hand => .wrist,
                .thigh => .hip,
                .shin => .knee,
                .foot, .shoe => .ankle,
                else => .proximal,
            };
            const left_point = try visual.resolveLandmark(left.*, left_alpha, kind, context.camera);
            const right_point = try visual.resolveLandmark(right.*, right_alpha, kind, context.camera);
            const upper_body = role == .upper_arm or role == .forearm or role == .hand;
            const axis_origin = if (upper_body) torso_center else pelvis_center;
            const axis_unit = centerline_unit;
            const origin_to_left = left_point.pixel.sub(axis_origin);
            const projected = axis_origin.add(axis_unit.scale(
                origin_to_left.dot(axis_unit),
            ));
            const reflected_left = projected.scale(2.0).sub(left_point.pixel);
            const symmetry_error = visual.distance(reflected_left, right_point.pixel);
            try report.recordMaximum(metric(
                left.*,
                context,
                "bilateral_symmetry_error",
                symmetry_error,
                "px",
            ), 2.0);
        }
    }
}

fn alphaFor(record: *const visual.TraceRecord, images: *const Images) !visual.AlphaGeometry {
    const page = try images.find(record.request.texture_page);
    return visual.deriveAlphaGeometry(
        page.pixels,
        page.width,
        page.height,
        page.row_bytes,
        record.source,
    );
}

fn findRecord(
    trace: *const visual.Trace,
    character_id: u32,
    role: visual.Role,
    side: visual.Side,
    stable_id: ?[]const u8,
) ?*const visual.TraceRecord {
    for (trace.records[0..trace.count]) |*record| {
        if (record.character_id != character_id or record.role != role or record.side != side) continue;
        if (stable_id) |name| {
            if (!std.mem.eql(u8, record.stable_id, name)) continue;
        }
        return record;
    }
    return null;
}

fn findTargetForAttachment(
    trace: *const visual.Trace,
    attachment: *const visual.TraceRecord,
    role: visual.Role,
) ?*const visual.TraceRecord {
    var side_fallback: ?*const visual.TraceRecord = null;
    for (trace.records[0..trace.count]) |*record| {
        if (record.character_id != attachment.character_id or
            record.role != role or
            (record.owner != .anatomy and record.owner != .base_presentation))
        {
            continue;
        }
        if (attachment.side != .none and record.side != attachment.side) continue;
        if (record.bound_identity == attachment.bound_identity) return record;
        if (side_fallback == null) side_fallback = record;
    }
    return side_fallback;
}

fn metric(
    record: visual.TraceRecord,
    context: EvaluationContext,
    metric_name: []const u8,
    actual: f32,
    unit: []const u8,
) visual.Metric {
    return .{
        .character_style = record.style,
        .outfit = context.outfit,
        .view = record.view,
        .pose = context.pose,
        .morphology = context.morphology,
        .component = record.stable_id,
        .side = record.side,
        .metric = metric_name,
        .actual = actual,
        .unit = unit,
        .outcome = .pass,
    };
}

fn registrationMetric(
    report: *visual.Report,
    context: EvaluationContext,
    target: *const visual.TraceRecord,
    attachment: *const visual.TraceRecord,
    target_alpha: visual.AlphaGeometry,
    attachment_alpha: visual.AlphaGeometry,
    kind: visual.LandmarkKind,
    tolerance: f32,
) !void {
    return pairedRegistrationMetric(
        report,
        context,
        target,
        attachment,
        target_alpha,
        attachment_alpha,
        kind,
        kind,
        switch (kind) {
            .ankle => "ankle_error",
            .heel => "heel_error",
            .toe => "toe_error",
            else => "landmark_error",
        },
        tolerance,
    );
}

fn pairedLateralRegistrationMetric(
    report: *visual.Report,
    context: EvaluationContext,
    target: *const visual.TraceRecord,
    attachment: *const visual.TraceRecord,
    target_alpha: visual.AlphaGeometry,
    attachment_alpha: visual.AlphaGeometry,
    target_kind: visual.LandmarkKind,
    attachment_kind: visual.LandmarkKind,
    name: []const u8,
    tolerance: f32,
    opening_half_width_visible_uv: f32,
) !void {
    const target_point = try visual.resolveLandmark(target.*, target_alpha, target_kind, context.camera);
    const attachment_point = try visual.resolveLandmark(
        attachment.*,
        attachment_alpha,
        attachment_kind,
        context.camera,
    );
    const opening_landmark = attachment.geometry.find(attachment_kind) orelse
        return error.MissingSemanticLandmark;
    const opening_edge_uv = [2]f32{
        @min(1.0, opening_landmark.visible_uv[0] + opening_half_width_visible_uv),
        opening_landmark.visible_uv[1],
    };
    const opening_edge_local = attachment_alpha.visibleUvToLocal(opening_edge_uv);
    const opening_edge_world_array = @import("sprite_batch").localPointToWorld(
        attachment.request,
        opening_edge_local,
    );
    const opening_edge_pixel = try context.camera.worldToPresentation(
        .{ .x = opening_edge_world_array[0], .y = opening_edge_world_array[1] },
        attachment.request.camera_x_factor,
    );
    const opening_half_width_px = visual.distance(
        attachment_point.pixel,
        opening_edge_pixel,
    );
    try report.recordMaximum(metric(
        attachment.*,
        context,
        name,
        @max(
            @as(f32, 0),
            @abs(target_point.pixel.x - attachment_point.pixel.x) - opening_half_width_px,
        ),
        "px lateral",
    ), tolerance);
}

fn pairedRegistrationMetric(
    report: *visual.Report,
    context: EvaluationContext,
    target: *const visual.TraceRecord,
    attachment: *const visual.TraceRecord,
    target_alpha: visual.AlphaGeometry,
    attachment_alpha: visual.AlphaGeometry,
    target_kind: visual.LandmarkKind,
    attachment_kind: visual.LandmarkKind,
    name: []const u8,
    tolerance: f32,
) !void {
    const target_point = try visual.resolveLandmark(target.*, target_alpha, target_kind, context.camera);
    const attachment_point = try visual.resolveLandmark(attachment.*, attachment_alpha, attachment_kind, context.camera);
    try report.recordMaximum(metric(
        attachment.*,
        context,
        name,
        visual.distance(target_point.pixel, attachment_point.pixel),
        "px",
    ), tolerance);
}

fn pairedSpanCenterRegistrationMetric(
    report: *visual.Report,
    context: EvaluationContext,
    target: *const visual.TraceRecord,
    attachment: *const visual.TraceRecord,
    target_alpha: visual.AlphaGeometry,
    attachment_alpha: visual.AlphaGeometry,
    start_kind: visual.LandmarkKind,
    end_kind: visual.LandmarkKind,
    name: []const u8,
    tolerance: f32,
) !void {
    const target_start = try visual.resolveLandmark(target.*, target_alpha, start_kind, context.camera);
    const target_end = try visual.resolveLandmark(target.*, target_alpha, end_kind, context.camera);
    const attachment_start = try visual.resolveLandmark(attachment.*, attachment_alpha, start_kind, context.camera);
    const attachment_end = try visual.resolveLandmark(attachment.*, attachment_alpha, end_kind, context.camera);
    const target_center = target_start.pixel.add(target_end.pixel).scale(0.5);
    const attachment_center = attachment_start.pixel.add(attachment_end.pixel).scale(0.5);
    try report.recordMaximum(metric(
        attachment.*,
        context,
        name,
        visual.distance(target_center, attachment_center),
        "px",
    ), tolerance);
}

fn orientationMetric(
    report: *visual.Report,
    context: EvaluationContext,
    target: *const visual.TraceRecord,
    attachment: *const visual.TraceRecord,
    target_alpha: visual.AlphaGeometry,
    attachment_alpha: visual.AlphaGeometry,
    target_start_kind: visual.LandmarkKind,
    target_end_kind: visual.LandmarkKind,
    attachment_start_kind: visual.LandmarkKind,
    attachment_end_kind: visual.LandmarkKind,
    name: []const u8,
    tolerance: f32,
) !void {
    const target_start = try visual.resolveLandmark(target.*, target_alpha, target_start_kind, context.camera);
    const target_end = try visual.resolveLandmark(target.*, target_alpha, target_end_kind, context.camera);
    const attachment_start = try visual.resolveLandmark(attachment.*, attachment_alpha, attachment_start_kind, context.camera);
    const attachment_end = try visual.resolveLandmark(attachment.*, attachment_alpha, attachment_end_kind, context.camera);
    const angle = try visual.angleDegrees(
        target_start.pixel,
        target_end.pixel,
        attachment_start.pixel,
        attachment_end.pixel,
    );
    try report.recordMaximum(metric(
        attachment.*,
        context,
        name,
        angle,
        "deg",
    ), tolerance);
}

fn spanMetric(
    report: *visual.Report,
    context: EvaluationContext,
    target: *const visual.TraceRecord,
    attachment: *const visual.TraceRecord,
    target_alpha: visual.AlphaGeometry,
    attachment_alpha: visual.AlphaGeometry,
    start_kind: visual.LandmarkKind,
    end_kind: visual.LandmarkKind,
    name: []const u8,
    contract: visual.FitContract,
) !void {
    const target_start = try visual.resolveLandmark(target.*, target_alpha, start_kind, context.camera);
    const target_end = try visual.resolveLandmark(target.*, target_alpha, end_kind, context.camera);
    const attachment_start = try visual.resolveLandmark(attachment.*, attachment_alpha, start_kind, context.camera);
    const attachment_end = try visual.resolveLandmark(attachment.*, attachment_alpha, end_kind, context.camera);
    const target_span = visual.distance(target_start.pixel, target_end.pixel);
    const attachment_span = visual.distance(attachment_start.pixel, attachment_end.pixel);
    const ratio = if (target_span > std.math.floatEps(f32)) attachment_span / target_span else 0;
    const design_span = std.mem.eql(u8, name, "chest_fit_ratio") or
        std.mem.eql(u8, name, "shoulder_fit_ratio");
    const waist_span = std.mem.eql(u8, name, "waist_fit_ratio");
    const hip_span = std.mem.eql(u8, name, "hip_fit_ratio");
    const range = if (design_span)
        contract.spanRange(attachment.view)
    else if (waist_span)
        contract.waistSpanRange(attachment.view)
    else if (hip_span)
        contract.spanRange(attachment.view)
    else
        [2]f32{ contract.minimum_span_ratio, contract.maximum_span_ratio };
    try report.recordRange(metric(
        attachment.*,
        context,
        name,
        ratio,
        "ratio",
    ), range[0], range[1]);
}

fn garmentCoverageMetric(
    report: *visual.Report,
    context: EvaluationContext,
    target: visual.TraceRecord,
    garment: visual.TraceRecord,
    images: *const Images,
    contract: visual.FitContract,
    name: []const u8,
) !void {
    const stats = try coverageStats(
        target,
        garment,
        null,
        images,
        context.camera,
        contract.coverageZone(garment.view),
        contract.clearance_px,
        contract.coverage_mode,
    );
    if (contract.validate_coverage) {
        try report.recordRange(metric(
            garment,
            context,
            name,
            stats.coverage(),
            "ratio",
        ), contract.minimumCoverage(garment.view), 1.0);
    }
    if (contract.validate_off_target) {
        try report.recordMaximum(metric(
            garment,
            context,
            "off_target_garment_fraction",
            stats.offTarget(),
            "ratio",
        ), contract.maximum_off_target);
    }
}

fn compositeGarmentCoverageMetric(
    report: *visual.Report,
    context: EvaluationContext,
    primary: visual.TraceRecord,
    secondary: visual.TraceRecord,
    garment: visual.TraceRecord,
    images: *const Images,
    contract: visual.FitContract,
    name: []const u8,
) !void {
    const stats = try compositeCoverageStats(
        primary,
        secondary,
        garment,
        images,
        context.camera,
        contract.coverageZone(garment.view),
        contract.secondaryCoverageZone(garment.view),
        contract.clearance_px,
        contract.coverage_mode,
    );
    if (contract.validate_coverage) {
        try report.recordRange(metric(
            garment,
            context,
            name,
            stats.coverage(),
            "ratio",
        ), contract.minimumCoverage(garment.view), 1.0);
    }
    if (contract.validate_off_target) {
        try report.recordMaximum(metric(
            garment,
            context,
            "off_target_garment_fraction",
            stats.offTarget(),
            "ratio",
        ), contract.maximum_off_target);
    }
}

fn coverageStats(
    target: visual.TraceRecord,
    attachment: visual.TraceRecord,
    opposite: ?*const visual.TraceRecord,
    images: *const Images,
    camera: camera2d.Camera2D,
    coverage_zone: visual.CoverageZone,
    clearance_px: u8,
    coverage_mode: visual.CoverageMode,
) !visual.MaskStats {
    const target_page = try images.find(target.request.texture_page);
    const attachment_page = try images.find(attachment.request.texture_page);
    const target_alpha = try visual.deriveAlphaGeometry(
        target_page.pixels,
        target_page.width,
        target_page.height,
        target_page.row_bytes,
        target.source,
    );
    const attachment_alpha = try visual.deriveAlphaGeometry(
        attachment_page.pixels,
        attachment_page.width,
        attachment_page.height,
        attachment_page.row_bytes,
        attachment.source,
    );
    const opposite_page = if (opposite) |record|
        try images.find(record.request.texture_page)
    else
        null;
    const bounds = try unionPixelBounds(target, attachment, camera);
    var stats = visual.MaskStats{
        .target_pixels = 0,
        .covered_target_pixels = 0,
        .attachment_pixels = 0,
        .attachment_off_target_pixels = 0,
        .opposite_target_pixels = 0,
    };
    var y = bounds.min_y;
    while (y <= bounds.max_y) : (y += 1) {
        var x = bounds.min_x;
        while (x <= bounds.max_x) : (x += 1) {
            const world = try camera.presentationToWorld(.{
                .x = @as(f32, @floatFromInt(x)) + 0.5,
                .y = @as(f32, @floatFromInt(y)) + 0.5,
            });
            const in_target = try visual.sampleAlphaAtWorld(
                target,
                target_page.pixels,
                target_page.width,
                target_page.height,
                target_page.row_bytes,
                world,
            );
            const target_local = try @import("sprite_batch").worldPointToLocal(
                target.request,
                world.toArray(),
            );
            const target_visible_uv = target_alpha.localToVisibleUv(target_local);
            const in_target_zone = in_target and coverage_zone.contains(target_visible_uv);
            const in_attachment = try visual.sampleAlphaAtWorld(
                attachment,
                attachment_page.pixels,
                attachment_page.width,
                attachment_page.height,
                attachment_page.row_bytes,
                world,
            );
            const attachment_covers_target = switch (coverage_mode) {
                .opaque_overlap => in_attachment,
                .enclosure_bounds => insideVisibleBounds(
                    attachment,
                    attachment_alpha,
                    world,
                ),
            };
            if (in_target_zone) stats.target_pixels += 1;
            if (in_target_zone and attachment_covers_target) {
                stats.covered_target_pixels += 1;
            }
            if (in_attachment) {
                stats.attachment_pixels += 1;
                if (!in_target and !insideTargetClearance(
                    target,
                    target_alpha,
                    world,
                    camera,
                    clearance_px,
                )) stats.attachment_off_target_pixels += 1;
                if (opposite) |record| {
                    // A fitted shoe is allowed its declared few-pixel
                    // clearance beyond the foot silhouette. Count crossing
                    // only when that shoe pixel is outside its own semantic
                    // fit envelope and lands on the opposite foot.
                    if (!in_target and !insideTargetClearance(
                        target,
                        target_alpha,
                        world,
                        camera,
                        clearance_px,
                    ) and try visual.sampleAlphaAtWorld(
                        record.*,
                        opposite_page.?.pixels,
                        opposite_page.?.width,
                        opposite_page.?.height,
                        opposite_page.?.row_bytes,
                        world,
                    )) stats.opposite_target_pixels += 1;
                }
            }
        }
    }
    return stats;
}

fn compositeCoverageStats(
    primary: visual.TraceRecord,
    secondary: visual.TraceRecord,
    garment: visual.TraceRecord,
    images: *const Images,
    camera: camera2d.Camera2D,
    primary_zone: visual.CoverageZone,
    secondary_zone: visual.CoverageZone,
    clearance_px: u8,
    coverage_mode: visual.CoverageMode,
) !visual.MaskStats {
    const primary_page = try images.find(primary.request.texture_page);
    const secondary_page = try images.find(secondary.request.texture_page);
    const garment_page = try images.find(garment.request.texture_page);
    const primary_alpha = try visual.deriveAlphaGeometry(
        primary_page.pixels,
        primary_page.width,
        primary_page.height,
        primary_page.row_bytes,
        primary.source,
    );
    const secondary_alpha = try visual.deriveAlphaGeometry(
        secondary_page.pixels,
        secondary_page.width,
        secondary_page.height,
        secondary_page.row_bytes,
        secondary.source,
    );
    const garment_alpha = try visual.deriveAlphaGeometry(
        garment_page.pixels,
        garment_page.width,
        garment_page.height,
        garment_page.row_bytes,
        garment.source,
    );
    var bounds = try unionPixelBounds(primary, garment, camera);
    const secondary_bounds = try unionPixelBounds(secondary, garment, camera);
    bounds.min_x = @min(bounds.min_x, secondary_bounds.min_x);
    bounds.min_y = @min(bounds.min_y, secondary_bounds.min_y);
    bounds.max_x = @max(bounds.max_x, secondary_bounds.max_x);
    bounds.max_y = @max(bounds.max_y, secondary_bounds.max_y);
    var stats = visual.MaskStats{
        .target_pixels = 0,
        .covered_target_pixels = 0,
        .attachment_pixels = 0,
        .attachment_off_target_pixels = 0,
        .opposite_target_pixels = 0,
    };
    var y = bounds.min_y;
    while (y <= bounds.max_y) : (y += 1) {
        var x = bounds.min_x;
        while (x <= bounds.max_x) : (x += 1) {
            const world = try camera.presentationToWorld(.{
                .x = @as(f32, @floatFromInt(x)) + 0.5,
                .y = @as(f32, @floatFromInt(y)) + 0.5,
            });
            const in_primary = try visual.sampleAlphaAtWorld(
                primary,
                primary_page.pixels,
                primary_page.width,
                primary_page.height,
                primary_page.row_bytes,
                world,
            );
            const primary_local = try @import("sprite_batch").worldPointToLocal(
                primary.request,
                world.toArray(),
            );
            const in_primary_zone = in_primary and
                primary_zone.contains(primary_alpha.localToVisibleUv(primary_local));
            const in_secondary = try visual.sampleAlphaAtWorld(
                secondary,
                secondary_page.pixels,
                secondary_page.width,
                secondary_page.height,
                secondary_page.row_bytes,
                world,
            );
            const secondary_local = try @import("sprite_batch").worldPointToLocal(
                secondary.request,
                world.toArray(),
            );
            const in_secondary_zone = in_secondary and
                secondary_zone.contains(secondary_alpha.localToVisibleUv(secondary_local));
            const in_target_zone = in_primary_zone or in_secondary_zone;
            const in_garment = try visual.sampleAlphaAtWorld(
                garment,
                garment_page.pixels,
                garment_page.width,
                garment_page.height,
                garment_page.row_bytes,
                world,
            );
            const garment_covers_target = switch (coverage_mode) {
                .opaque_overlap => in_garment,
                .enclosure_bounds => insideVisibleBounds(
                    garment,
                    garment_alpha,
                    world,
                ),
            };
            if (in_target_zone) stats.target_pixels += 1;
            if (in_target_zone and garment_covers_target) {
                stats.covered_target_pixels += 1;
            }
            if (in_garment) {
                stats.attachment_pixels += 1;
                const inside_clearance = in_primary or
                    in_secondary or
                    insideTargetClearance(
                        primary,
                        primary_alpha,
                        world,
                        camera,
                        clearance_px,
                    ) or
                    insideTargetClearance(
                        secondary,
                        secondary_alpha,
                        world,
                        camera,
                        clearance_px,
                    );
                if (!inside_clearance) stats.attachment_off_target_pixels += 1;
            }
        }
    }
    return stats;
}

fn insideVisibleBounds(
    record: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    world: math.Vec2,
) bool {
    if (record.mesh) |mesh_trace| {
        var index: usize = 0;
        while (index + 2 < mesh_trace.index_count) : (index += 3) {
            const a = mesh_trace.vertices[mesh_trace.indices[index]].world;
            const b = mesh_trace.vertices[mesh_trace.indices[index + 1]].world;
            const c = mesh_trace.vertices[mesh_trace.indices[index + 2]].world;
            const v0 = b.sub(a);
            const v1 = c.sub(a);
            const v2 = world.sub(a);
            const denominator = v0.x * v1.y - v1.x * v0.y;
            if (@abs(denominator) <= std.math.floatEps(f32)) continue;
            const inverse = 1.0 / denominator;
            const beta = (v2.x * v1.y - v1.x * v2.y) * inverse;
            const gamma = (v0.x * v2.y - v2.x * v0.y) * inverse;
            const alpha_weight = 1.0 - beta - gamma;
            if (alpha_weight >= -0.0001 and beta >= -0.0001 and gamma >= -0.0001) {
                return true;
            }
        }
        return false;
    }
    const local = @import("sprite_batch").worldPointToLocal(
        record.request,
        world.toArray(),
    ) catch return false;
    const uv = alpha.localToVisibleUv(local);
    return uv[0] >= 0 and uv[0] <= 1 and uv[1] >= 0 and uv[1] <= 1;
}

fn insideTargetClearance(
    target: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    world: math.Vec2,
    camera: camera2d.Camera2D,
    clearance_px: u8,
) bool {
    const local = @import("sprite_batch").worldPointToLocal(target.request, world.toArray()) catch
        return false;
    const visible_min = alpha.visibleUvToLocal(.{ 0, 1 });
    const visible_max = alpha.visibleUvToLocal(.{ 1, 0 });
    const world_per_pixel = 1.0 / camera.pixels_per_meter;
    const pad_x = @as(f32, @floatFromInt(clearance_px)) * world_per_pixel /
        @max(@abs(target.request.scale[0]), std.math.floatEps(f32));
    const pad_y = @as(f32, @floatFromInt(clearance_px)) * world_per_pixel /
        @max(@abs(target.request.scale[1]), std.math.floatEps(f32));
    return local[0] >= @min(visible_min[0], visible_max[0]) - pad_x and
        local[0] <= @max(visible_min[0], visible_max[0]) + pad_x and
        local[1] >= @min(visible_min[1], visible_max[1]) - pad_y and
        local[1] <= @max(visible_min[1], visible_max[1]) + pad_y;
}

const PixelBounds = struct {
    min_x: i32,
    min_y: i32,
    max_x: i32,
    max_y: i32,
};

fn unionPixelBounds(
    first: visual.TraceRecord,
    second: visual.TraceRecord,
    camera: camera2d.Camera2D,
) !PixelBounds {
    var bounds = PixelBounds{
        .min_x = @intCast(camera.viewport_width),
        .min_y = @intCast(camera.viewport_height),
        .max_x = 0,
        .max_y = 0,
    };
    for ([_]visual.TraceRecord{ first, second }) |record| {
        for ([_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 } }) |local| {
            const world_array = @import("sprite_batch").localPointToWorld(record.request, local);
            const pixel = try camera.worldToPresentation(.{
                .x = world_array[0],
                .y = world_array[1],
            }, record.request.camera_x_factor);
            bounds.min_x = @min(bounds.min_x, @as(i32, @intFromFloat(@floor(pixel.x))) - 1);
            bounds.min_y = @min(bounds.min_y, @as(i32, @intFromFloat(@floor(pixel.y))) - 1);
            bounds.max_x = @max(bounds.max_x, @as(i32, @intFromFloat(@ceil(pixel.x))) + 1);
            bounds.max_y = @max(bounds.max_y, @as(i32, @intFromFloat(@ceil(pixel.y))) + 1);
        }
    }
    bounds.min_x = std.math.clamp(bounds.min_x, 0, @as(i32, @intCast(camera.viewport_width)) - 1);
    bounds.min_y = std.math.clamp(bounds.min_y, 0, @as(i32, @intCast(camera.viewport_height)) - 1);
    bounds.max_x = std.math.clamp(bounds.max_x, 0, @as(i32, @intCast(camera.viewport_width)) - 1);
    bounds.max_y = std.math.clamp(bounds.max_y, 0, @as(i32, @intCast(camera.viewport_height)) - 1);
    return bounds;
}

const ContinuityStats = struct {
    gap_px: f32,
    overlap_equivalent_depth_px: f32,
};

pub fn longestContiguousProjectionRun(bins: []const bool) f32 {
    var longest: u32 = 0;
    var current: u32 = 0;
    for (bins) |occupied| {
        if (occupied) {
            current += 1;
            longest = @max(longest, current);
        } else {
            current = 0;
        }
    }
    return @floatFromInt(longest);
}

fn continuityStats(
    first: visual.TraceRecord,
    second: visual.TraceRecord,
    center: math.Vec2,
    images: *const Images,
    camera: camera2d.Camera2D,
) !ContinuityStats {
    const first_page = try images.find(first.request.texture_page);
    const second_page = try images.find(second.request.texture_page);
    var first_points: [625]math.Vec2 = undefined;
    var second_points: [625]math.Vec2 = undefined;
    var first_count: usize = 0;
    var second_count: usize = 0;
    var overlap: u32 = 0;
    const projection_bin_radius: i32 = 18;
    var overlap_projection_bins = [_]bool{false} ** 37;
    const first_binding = try camera.worldToPresentation(.{
        .x = first.request.world_position[0],
        .y = first.request.world_position[1],
    }, first.request.camera_x_factor);
    const second_binding = try camera.worldToPresentation(.{
        .x = second.request.world_position[0],
        .y = second.request.world_position[1],
    }, second.request.camera_x_factor);
    const raw_axis = second_binding.sub(first_binding);
    const axis_length = raw_axis.length();
    const axis = if (axis_length > std.math.floatEps(f32))
        raw_axis.scale(1.0 / axis_length)
    else
        math.Vec2{ .x = 0, .y = 1 };
    const perpendicular = math.Vec2{ .x = -axis.y, .y = axis.x };
    // Measure continuity in a narrow band through the semantic joint. Treating
    // any overlap anywhere in the 25 px neighborhood as success allowed a
    // small off-axis lobe to hide a clearly visible centerline gap.
    const band_half_width_px: f32 = 3.5;
    const center_x: i32 = @intFromFloat(@round(center.x));
    const center_y: i32 = @intFromFloat(@round(center.y));
    var y: i32 = center_y - 12;
    while (y <= center_y + 12) : (y += 1) {
        if (y < 0 or y >= camera.viewport_height) continue;
        var x: i32 = center_x - 12;
        while (x <= center_x + 12) : (x += 1) {
            if (x < 0 or x >= camera.viewport_width) continue;
            const world = try camera.presentationToWorld(.{
                .x = @as(f32, @floatFromInt(x)) + 0.5,
                .y = @as(f32, @floatFromInt(y)) + 0.5,
            });
            const in_first = try visual.sampleAlphaAtWorld(
                first,
                first_page.pixels,
                first_page.width,
                first_page.height,
                first_page.row_bytes,
                world,
            );
            const in_second = try visual.sampleAlphaAtWorld(
                second,
                second_page.pixels,
                second_page.width,
                second_page.height,
                second_page.row_bytes,
                world,
            );
            const sample = math.Vec2{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
            const inside_band = @abs(sample.sub(center).dot(perpendicular)) <= band_half_width_px;
            if (in_first and inside_band) {
                first_points[first_count] = .{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
                first_count += 1;
            }
            if (in_second and inside_band) {
                second_points[second_count] = .{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
                second_count += 1;
            }
            if (in_first and in_second and inside_band) {
                overlap += 1;
                const projection = sample.sub(center).dot(axis);
                const projection_bin: i32 = @intFromFloat(@round(projection));
                if (projection_bin >= -projection_bin_radius and
                    projection_bin <= projection_bin_radius)
                {
                    const index: usize = @intCast(
                        projection_bin + projection_bin_radius,
                    );
                    overlap_projection_bins[index] = true;
                }
            }
        }
    }
    if (overlap > 0) {
        // Measure the deepest contiguous overlap along the semantic limb
        // axis. Using only the first and last occupied projections turned
        // separated antialias islands into a fictitious solid overlap.
        const contiguous_depth = longestContiguousProjectionRun(
            &overlap_projection_bins,
        );
        return .{
            .gap_px = 0,
            .overlap_equivalent_depth_px = contiguous_depth,
        };
    }
    var minimum = std.math.inf(f32);
    for (first_points[0..first_count]) |a| {
        for (second_points[0..second_count]) |b| {
            minimum = @min(minimum, visual.distance(a, b));
        }
    }
    if (!std.math.isFinite(minimum)) minimum = 25;
    return .{ .gap_px = minimum, .overlap_equivalent_depth_px = 0 };
}

fn bindingAxis(
    first: visual.TraceRecord,
    second: visual.TraceRecord,
    camera: camera2d.Camera2D,
) !math.Vec2 {
    const first_binding = try camera.worldToPresentation(.{
        .x = first.request.world_position[0],
        .y = first.request.world_position[1],
    }, first.request.camera_x_factor);
    const second_binding = try camera.worldToPresentation(.{
        .x = second.request.world_position[0],
        .y = second.request.world_position[1],
    }, second.request.camera_x_factor);
    const raw_axis = second_binding.sub(first_binding);
    const axis_length = raw_axis.length();
    return if (axis_length > std.math.floatEps(f32))
        raw_axis.scale(1.0 / axis_length)
    else
        math.Vec2{ .x = 0, .y = 1 };
}

fn projectedVisibleAxisSpan(
    record: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    axis: math.Vec2,
    camera: camera2d.Camera2D,
) !f32 {
    var minimum = std.math.inf(f32);
    var maximum = -std.math.inf(f32);
    for ([_][2]f32{
        .{ 0, 0 },
        .{ 1, 0 },
        .{ 0, 1 },
        .{ 1, 1 },
    }) |visible_uv| {
        const local = alpha.visibleUvToLocal(visible_uv);
        const world = sprite.localPointToWorld(record.request, local);
        const pixel = try camera.worldToPresentation(.{
            .x = world[0],
            .y = world[1],
        }, record.request.camera_x_factor);
        const projection = pixel.dot(axis);
        minimum = @min(minimum, projection);
        maximum = @max(maximum, projection);
    }
    return @max(@as(f32, 0), maximum - minimum);
}
