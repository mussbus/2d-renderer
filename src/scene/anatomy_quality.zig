const std = @import("std");
const math = @import("math");
const camera2d = @import("camera2d");
const sprite = @import("sprite_batch");
const visual = @import("visual_geometry");
const audit = @import("visual_geometry_audit");

pub const Joint = enum(u8) {
    shoulder,
    elbow,
    wrist,
    hip,
    knee,
    ankle,
};

pub const Range = struct {
    minimum: f32,
    maximum: f32,
};

pub const Contract = struct {
    shoulder_slope_degrees: Range,
    shoulder_curve_ratio: Range,
    shoulder_width_ratio: Range = .{ .minimum = 0.62, .maximum = 1.42 },
    elbow_width_ratio: Range = .{ .minimum = 0.70, .maximum = 1.34 },
    wrist_width_ratio: Range = .{ .minimum = 0.68, .maximum = 1.34 },
    hip_width_ratio: Range = .{ .minimum = 0.64, .maximum = 1.42 },
    knee_width_ratio: Range = .{ .minimum = 0.68, .maximum = 1.34 },
    ankle_width_ratio: Range = .{ .minimum = 0.62, .maximum = 1.38 },
    hand_forearm_length_ratio: Range,
    hand_forearm_width_ratio: Range,
    arm_torso_length_ratio: Range,
    head_torso_height_ratio: Range = .{ .minimum = 0.58, .maximum = 0.84 },
    pelvis_torso_height_ratio: Range,
    thigh_shin_length_ratio: Range = .{ .minimum = 1.00, .maximum = 1.24 },
    maximum_dark_joint_edge_ratio: f32 = 0.20,
    maximum_side_foot_axis_error_degrees: f32 = 7.0,
    front_toe_out_degrees: Range,
    maximum_bilateral_ankle_error_px: f32 = 2.0,
    maximum_bilateral_toe_out_error_degrees: f32 = 3.0,
};

pub fn contract(style: []const u8, view: visual.View) !Contract {
    const male = std.mem.eql(u8, style, "male");
    const female = std.mem.eql(u8, style, "female");
    if (!male and !female) return error.UnsupportedAnatomyStyle;
    return .{
        .shoulder_slope_degrees = if (view == .front)
            (if (male)
                .{ .minimum = 8.0, .maximum = 30.0 }
            else
                .{ .minimum = 10.0, .maximum = 34.0 })
        else
            .{ .minimum = 6.0, .maximum = 36.0 },
        .shoulder_curve_ratio = if (female)
            .{ .minimum = 0.008, .maximum = 0.140 }
        else
            .{ .minimum = 0.008, .maximum = 0.120 },
        .hand_forearm_length_ratio = if (male)
            .{ .minimum = 0.43, .maximum = 0.57 }
        else
            .{ .minimum = 0.40, .maximum = 0.54 },
        .hand_forearm_width_ratio = if (male)
            .{ .minimum = 0.74, .maximum = 1.34 }
        else
            .{ .minimum = 0.72, .maximum = 1.32 },
        .arm_torso_length_ratio = if (male)
            .{ .minimum = 0.94, .maximum = 1.18 }
        else
            .{ .minimum = 0.92, .maximum = 1.17 },
        .pelvis_torso_height_ratio = if (view == .front)
            (if (male)
                .{ .minimum = 0.38, .maximum = 0.58 }
            else
                .{ .minimum = 0.38, .maximum = 0.60 })
        else if (male)
            .{ .minimum = 0.68, .maximum = 0.96 }
        else
            .{ .minimum = 0.68, .maximum = 0.98 },
        .front_toe_out_degrees = if (male)
            .{ .minimum = 8.0, .maximum = 24.0 }
        else
            .{ .minimum = 6.0, .maximum = 20.0 },
    };
}

pub fn widthRange(value: Contract, joint: Joint) Range {
    return switch (joint) {
        .shoulder => value.shoulder_width_ratio,
        .elbow => value.elbow_width_ratio,
        .wrist => value.wrist_width_ratio,
        .hip => value.hip_width_ratio,
        .knee => value.knee_width_ratio,
        .ankle => value.ankle_width_ratio,
    };
}

pub const MatrixCase = struct {
    style: []const u8,
    view: visual.View,
    pose: []const u8,
    morphology: []const u8,
};

pub const MatrixTracker = struct {
    expected: []const MatrixCase,
    observed: [128]bool = [_]bool{false} ** 128,

    pub fn init(expected: []const MatrixCase) !MatrixTracker {
        if (expected.len == 0 or expected.len > 128) return error.InvalidAnatomyMatrix;
        return .{ .expected = expected };
    }

    pub fn observe(tracker: *MatrixTracker, value: MatrixCase) !void {
        for (tracker.expected, 0..) |expected, index| {
            if (sameCase(expected, value)) {
                tracker.observed[index] = true;
                return;
            }
        }
        return error.UndeclaredAnatomyMatrixCase;
    }

    pub fn validateComplete(tracker: *const MatrixTracker) !void {
        for (tracker.observed[0..tracker.expected.len]) |observed| {
            if (!observed) return error.MissingAnatomyMatrixCase;
        }
    }
};

fn sameCase(a: MatrixCase, b: MatrixCase) bool {
    return std.mem.eql(u8, a.style, b.style) and
        a.view == b.view and
        std.mem.eql(u8, a.pose, b.pose) and
        std.mem.eql(u8, a.morphology, b.morphology);
}

pub fn evaluate(
    trace: *const visual.Trace,
    images: *const audit.Images,
    context: audit.EvaluationContext,
    report: *visual.Report,
) !void {
    if (trace.count == 0) return error.EmptyAnatomyTrace;
    var anatomy_records: u32 = 0;
    for (trace.slice()) |record| {
        if (isBodyRole(record.role)) anatomy_records += 1;
    }
    if (anatomy_records == 0) return error.EmptyAnatomyTrace;
    try report.recordRange(baseMetric(
        trace.records[0],
        context,
        "anatomy",
        .none,
        "anatomy_record_count",
        @floatFromInt(anatomy_records),
        "records",
    ), 1, @floatFromInt(visual.trace_capacity));

    for (trace.slice()) |*torso| {
        if (torso.role != .torso or torso.side != .none) continue;
        const style_contract = try contract(torso.style, torso.view);
        try evaluateShoulders(torso.*, trace, images, context, style_contract, report);
        try evaluateBodyRatios(torso.*, trace, images, context, style_contract, report);
        if (torso.view == .front and std.mem.eql(u8, context.pose, "neutral")) {
            try evaluateFrontStance(torso.*, trace, images, context, style_contract, report);
        }
        for ([_]visual.Side{ .left, .right }) |side| {
            try evaluateSideJoints(
                torso.character_id,
                torso.style,
                torso.view,
                side,
                trace,
                images,
                context,
                style_contract,
                report,
            );
            try evaluateFoot(
                torso.character_id,
                torso.style,
                torso.view,
                side,
                trace,
                images,
                context,
                style_contract,
                report,
            );
        }
    }
}

fn isBodyRole(role: visual.Role) bool {
    return switch (role) {
        .head,
        .torso,
        .pelvis,
        .upper_arm,
        .forearm,
        .hand,
        .thigh,
        .shin,
        .foot,
        => true,
        else => false,
    };
}

fn evaluateShoulders(
    torso: visual.TraceRecord,
    trace: *const visual.Trace,
    images: *const audit.Images,
    context: audit.EvaluationContext,
    style_contract: Contract,
    report: *visual.Report,
) !void {
    const page = try images.find(torso.request.texture_page);
    const alpha = try alphaFor(torso, page);
    const left = try shoulderContour(torso, page, alpha, true, context.camera);
    const right = try shoulderContour(torso, page, alpha, false, context.camera);
    for ([_]struct {
        side: visual.Side,
        value: ShoulderContour,
    }{
        .{ .side = .left, .value = left },
        .{ .side = .right, .value = right },
    }) |sample| {
        try recordRange(
            report,
            torso,
            context,
            "torso",
            sample.side,
            "shoulder_slope",
            sample.value.slope_degrees,
            "deg",
            style_contract.shoulder_slope_degrees,
        );
        try recordRange(
            report,
            torso,
            context,
            "torso",
            sample.side,
            "shoulder_contour_curve",
            sample.value.curve_ratio,
            "ratio",
            style_contract.shoulder_curve_ratio,
        );

        const arm = findRecord(
            trace,
            torso.character_id,
            .upper_arm,
            sample.side,
        ) orelse return error.MissingAnatomyTarget;
        const arm_page = try images.find(arm.request.texture_page);
        const arm_alpha = try alphaFor(arm.*, arm_page);
        const arm_axis = try recordAxis(arm.*, arm_alpha, context.camera);
        const torso_kind: visual.LandmarkKind =
            if (sample.side == .left) .shoulder_left else .shoulder_right;
        const torso_joint = try visual.resolveLandmark(
            torso,
            alpha,
            torso_kind,
            context.camera,
        );
        const arm_joint = try visual.resolveLandmark(
            arm.*,
            arm_alpha,
            .shoulder,
            context.camera,
        );
        const full_parent_width = try crossSectionWidth(
            torso,
            page,
            torso_joint.pixel,
            arm_axis,
            -2.0,
            context.camera,
        );
        const parent_width = full_parent_width *
            (if (torso.view == .front) @as(f32, 0.5) else @as(f32, 0.25));
        const child_width = try crossSectionWidth(
            arm.*,
            arm_page,
            arm_joint.pixel,
            arm_axis,
            2.0,
            context.camera,
        );
        try recordRange(
            report,
            arm.*,
            context,
            "upper_arm",
            sample.side,
            "shoulder_root_width_ratio",
            safeRatio(child_width, parent_width),
            "ratio",
            style_contract.shoulder_width_ratio,
        );
    }
}

const ShoulderContour = struct {
    slope_degrees: f32,
    curve_ratio: f32,
};

fn shoulderContour(
    torso: visual.TraceRecord,
    page: audit.PageImage,
    alpha: visual.AlphaGeometry,
    left: bool,
    camera: camera2d.Camera2D,
) !ShoulderContour {
    // These samples start at the authored neck-to-deltoid transition and
    // proceed to the outer shoulder. The reauthored front and profile sources
    // both expose that semantic arc at the same visible-space fractions.
    const xs: [5]f32 = if (left)
        .{ 0.34, 0.27, 0.20, 0.13, 0.06 }
    else
        .{ 0.66, 0.73, 0.80, 0.87, 0.94 };
    var points: [xs.len]math.Vec2 = undefined;
    for (xs, 0..) |x, index| {
        const y = try topContourVisibleY(page, alpha, x);
        points[index] = try visiblePointPixel(torso, alpha, .{ x, y }, camera);
    }
    // Measure the submitted contour in the submitted torso's visual basis.
    // Screen X/Y made this art contract depend on an idle-pose torso tilt,
    // even though the exact same alpha contour and production transform were
    // valid. Deriving the basis through visiblePointPixel keeps the real
    // pivot/scale/rotation/camera path while making the authored shoulder
    // slope relative to its owning torso.
    const horizontal_start = try visiblePointPixel(torso, alpha, .{ 0, 0.5 }, camera);
    const horizontal_end = try visiblePointPixel(torso, alpha, .{ 1, 0.5 }, camera);
    const vertical_start = try visiblePointPixel(torso, alpha, .{ 0.5, 0 }, camera);
    const vertical_end = try visiblePointPixel(torso, alpha, .{ 0.5, 1 }, camera);
    var horizontal_axis = horizontal_end.sub(horizontal_start);
    var vertical_axis = vertical_end.sub(vertical_start);
    const horizontal_length = horizontal_axis.length();
    const vertical_length = vertical_axis.length();
    if (horizontal_length <= std.math.floatEps(f32) or
        vertical_length <= std.math.floatEps(f32))
    {
        return error.DegenerateShoulderContour;
    }
    horizontal_axis = horizontal_axis.scale(1.0 / horizontal_length);
    vertical_axis = vertical_axis.scale(1.0 / vertical_length);
    const world_delta = points[points.len - 1].sub(points[0]);
    const delta = math.Vec2{
        .x = world_delta.dot(horizontal_axis),
        .y = world_delta.dot(vertical_axis),
    };
    const horizontal = @abs(delta.x);
    if (horizontal <= std.math.floatEps(f32)) return error.DegenerateShoulderContour;
    const slope = std.math.radiansToDegrees(std.math.atan2(@abs(delta.y), horizontal));
    var maximum_residual: f32 = 0;
    for (points[1 .. points.len - 1], 1..) |point, index| {
        const t = @as(f32, @floatFromInt(index)) /
            @as(f32, @floatFromInt(points.len - 1));
        const from_start = point.sub(points[0]);
        const local_y = from_start.dot(vertical_axis);
        const predicted_y = delta.y * t;
        maximum_residual = @max(maximum_residual, @abs(local_y - predicted_y));
    }
    return .{
        .slope_degrees = slope,
        .curve_ratio = maximum_residual / horizontal,
    };
}

fn topContourVisibleY(
    page: audit.PageImage,
    alpha: visual.AlphaGeometry,
    visible_x: f32,
) !f32 {
    const width = alpha.opaque_bounds.width;
    const height = alpha.opaque_bounds.height;
    if (width < 2 or height < 2) return error.DegenerateShoulderContour;
    const local_x: i32 = @intFromFloat(@round(
        visible_x * @as(f32, @floatFromInt(width - 1)),
    ));
    var best_y = height;
    var offset: i32 = -1;
    while (offset <= 1) : (offset += 1) {
        const raw_x = local_x + offset;
        if (raw_x < 0 or raw_x >= width) continue;
        const x: u32 = alpha.opaque_bounds.x + @as(u32, @intCast(raw_x));
        var y = alpha.opaque_bounds.y;
        while (y < alpha.opaque_bounds.y + height) : (y += 1) {
            if (isOpaque(page, x, y)) {
                best_y = @min(best_y, y - alpha.opaque_bounds.y);
                break;
            }
        }
    }
    if (best_y == height) return error.MissingShoulderContour;
    return @as(f32, @floatFromInt(best_y)) /
        @as(f32, @floatFromInt(height - 1));
}

fn evaluateBodyRatios(
    torso: visual.TraceRecord,
    trace: *const visual.Trace,
    images: *const audit.Images,
    context: audit.EvaluationContext,
    style_contract: Contract,
    report: *visual.Report,
) !void {
    const torso_page = try images.find(torso.request.texture_page);
    const torso_alpha = try alphaFor(torso, torso_page);
    const torso_height = try visibleVerticalSpan(torso, torso_alpha, context.camera);
    const head = findRecord(trace, torso.character_id, .head, .none) orelse
        return error.MissingAnatomyTarget;
    const head_page = try images.find(head.request.texture_page);
    const head_alpha = try alphaFor(head.*, head_page);
    try recordRange(
        report,
        head.*,
        context,
        "head",
        .none,
        "head_to_torso_height_ratio",
        safeRatio(
            try visibleVerticalSpan(head.*, head_alpha, context.camera),
            torso_height,
        ),
        "ratio",
        style_contract.head_torso_height_ratio,
    );

    const pelvis = findRecord(trace, torso.character_id, .pelvis, .none) orelse
        return error.MissingAnatomyTarget;
    const pelvis_page = try images.find(pelvis.request.texture_page);
    const pelvis_alpha = try alphaFor(pelvis.*, pelvis_page);
    try recordRange(
        report,
        pelvis.*,
        context,
        "pelvis",
        .none,
        "pelvis_to_torso_height_ratio",
        safeRatio(
            try visibleVerticalSpan(pelvis.*, pelvis_alpha, context.camera),
            torso_height,
        ),
        "ratio",
        style_contract.pelvis_torso_height_ratio,
    );

    for ([_]visual.Side{ .left, .right }) |side| {
        const upper = findRecord(trace, torso.character_id, .upper_arm, side) orelse
            return error.MissingAnatomyTarget;
        const forearm = findRecord(trace, torso.character_id, .forearm, side) orelse
            return error.MissingAnatomyTarget;
        const hand = findRecord(trace, torso.character_id, .hand, side) orelse
            return error.MissingAnatomyTarget;
        const thigh = findRecord(trace, torso.character_id, .thigh, side) orelse
            return error.MissingAnatomyTarget;
        const shin = findRecord(trace, torso.character_id, .shin, side) orelse
            return error.MissingAnatomyTarget;
        const upper_alpha = try alphaFor(upper.*, try images.find(upper.request.texture_page));
        const forearm_page = try images.find(forearm.request.texture_page);
        const forearm_alpha = try alphaFor(forearm.*, forearm_page);
        const hand_page = try images.find(hand.request.texture_page);
        const hand_alpha = try alphaFor(hand.*, hand_page);
        const thigh_alpha = try alphaFor(thigh.*, try images.find(thigh.request.texture_page));
        const shin_alpha = try alphaFor(shin.*, try images.find(shin.request.texture_page));

        const upper_length = try semanticSpan(upper.*, upper_alpha, .shoulder, .elbow, context.camera);
        const forearm_length = try semanticSpan(forearm.*, forearm_alpha, .elbow, .wrist, context.camera);
        const hand_length = try semanticSpan(hand.*, hand_alpha, .wrist, .fingertip, context.camera);
        try recordRange(
            report,
            hand.*,
            context,
            "hand",
            side,
            "hand_to_forearm_length_ratio",
            safeRatio(hand_length, forearm_length),
            "ratio",
            style_contract.hand_forearm_length_ratio,
        );
        try recordRange(
            report,
            upper.*,
            context,
            "arm",
            side,
            "arm_to_torso_length_ratio",
            safeRatio(upper_length + forearm_length, torso_height),
            "ratio",
            style_contract.arm_torso_length_ratio,
        );
        const forearm_axis = try recordAxis(forearm.*, forearm_alpha, context.camera);
        const wrist = try visual.resolveLandmark(forearm.*, forearm_alpha, .wrist, context.camera);
        const palm = try visual.resolveLandmark(hand.*, hand_alpha, .palm, context.camera);
        const forearm_width = try crossSectionWidth(
            forearm.*,
            forearm_page,
            wrist.pixel,
            forearm_axis,
            -3.0,
            context.camera,
        );
        const hand_width = try crossSectionWidth(
            hand.*,
            hand_page,
            palm.pixel,
            try recordAxis(hand.*, hand_alpha, context.camera),
            0,
            context.camera,
        );
        try recordRange(
            report,
            hand.*,
            context,
            "hand",
            side,
            "hand_to_forearm_width_ratio",
            safeRatio(hand_width, forearm_width),
            "ratio",
            style_contract.hand_forearm_width_ratio,
        );
        const thigh_length = try semanticSpan(thigh.*, thigh_alpha, .hip, .knee, context.camera);
        const shin_length = try semanticSpan(shin.*, shin_alpha, .knee, .ankle, context.camera);
        try recordRange(
            report,
            thigh.*,
            context,
            "leg",
            side,
            "thigh_to_shin_length_ratio",
            safeRatio(thigh_length, shin_length),
            "ratio",
            style_contract.thigh_shin_length_ratio,
        );
    }
}

fn evaluateSideJoints(
    character_id: u32,
    style: []const u8,
    view: visual.View,
    side: visual.Side,
    trace: *const visual.Trace,
    images: *const audit.Images,
    context: audit.EvaluationContext,
    style_contract: Contract,
    report: *visual.Report,
) !void {
    _ = style;
    _ = view;
    const pairs = [_]struct {
        joint: Joint,
        parent: visual.Role,
        child: visual.Role,
        parent_kind: visual.LandmarkKind,
        child_kind: visual.LandmarkKind,
        parent_axis_start: visual.LandmarkKind,
        parent_axis_end: visual.LandmarkKind,
        child_axis_start: visual.LandmarkKind,
        child_axis_end: visual.LandmarkKind,
    }{
        .{ .joint = .elbow, .parent = .upper_arm, .child = .forearm, .parent_kind = .elbow, .child_kind = .elbow, .parent_axis_start = .shoulder, .parent_axis_end = .elbow, .child_axis_start = .elbow, .child_axis_end = .wrist },
        .{ .joint = .wrist, .parent = .forearm, .child = .hand, .parent_kind = .wrist, .child_kind = .wrist, .parent_axis_start = .elbow, .parent_axis_end = .wrist, .child_axis_start = .wrist, .child_axis_end = .fingertip },
        .{ .joint = .knee, .parent = .thigh, .child = .shin, .parent_kind = .knee, .child_kind = .knee, .parent_axis_start = .hip, .parent_axis_end = .knee, .child_axis_start = .knee, .child_axis_end = .ankle },
        .{ .joint = .ankle, .parent = .shin, .child = .foot, .parent_kind = .ankle, .child_kind = .ankle, .parent_axis_start = .knee, .parent_axis_end = .ankle, .child_axis_start = .ankle, .child_axis_end = .toe },
    };
    for (pairs) |pair| {
        const parent = findRecord(trace, character_id, pair.parent, side) orelse
            return error.MissingAnatomyTarget;
        const child = findRecord(trace, character_id, pair.child, side) orelse
            return error.MissingAnatomyTarget;
        const parent_page = try images.find(parent.request.texture_page);
        const child_page = try images.find(child.request.texture_page);
        const parent_alpha = try alphaFor(parent.*, parent_page);
        const child_alpha = try alphaFor(child.*, child_page);
        const parent_axis = try axisBetween(
            parent.*,
            parent_alpha,
            pair.parent_axis_start,
            pair.parent_axis_end,
            context.camera,
        );
        const child_axis = try axisBetween(
            child.*,
            child_alpha,
            pair.child_axis_start,
            pair.child_axis_end,
            context.camera,
        );
        const parent_joint = try visual.resolveLandmark(
            parent.*,
            parent_alpha,
            pair.parent_kind,
            context.camera,
        );
        const child_joint = try visual.resolveLandmark(
            child.*,
            child_alpha,
            pair.child_kind,
            context.camera,
        );
        const parent_width = try crossSectionWidth(
            parent.*,
            parent_page,
            parent_joint.pixel,
            parent_axis,
            -2.0,
            context.camera,
        );
        const child_width = try crossSectionWidth(
            child.*,
            child_page,
            child_joint.pixel,
            child_axis,
            2.0,
            context.camera,
        );
        try recordRange(
            report,
            child.*,
            context,
            @tagName(pair.child),
            side,
            jointWidthMetricName(pair.joint),
            safeRatio(child_width, parent_width),
            "ratio",
            widthRange(style_contract, pair.joint),
        );
        const parent_dark = try endpointDarkRatio(
            parent.*,
            parent_page,
            parent_alpha,
            pair.parent_axis_start,
            pair.parent_axis_end,
            false,
        );
        const child_dark = try endpointDarkRatio(
            child.*,
            child_page,
            child_alpha,
            pair.child_axis_start,
            pair.child_axis_end,
            true,
        );
        try report.recordMaximum(baseMetric(
            child.*,
            context,
            @tagName(pair.child),
            side,
            jointDarkMetricName(pair.joint),
            @max(parent_dark, child_dark),
            "ratio",
        ), style_contract.maximum_dark_joint_edge_ratio);
    }

    const pelvis = findRecord(trace, character_id, .pelvis, .none) orelse
        return error.MissingAnatomyTarget;
    const thigh = findRecord(trace, character_id, .thigh, side) orelse
        return error.MissingAnatomyTarget;
    try evaluateRootWidth(
        .hip,
        pelvis.*,
        thigh.*,
        if (side == .left) .hip_left else .hip_right,
        .hip,
        images,
        context,
        style_contract,
        report,
    );
}

fn evaluateRootWidth(
    joint: Joint,
    parent: visual.TraceRecord,
    child: visual.TraceRecord,
    parent_kind: visual.LandmarkKind,
    child_kind: visual.LandmarkKind,
    images: *const audit.Images,
    context: audit.EvaluationContext,
    style_contract: Contract,
    report: *visual.Report,
) !void {
    const parent_page = try images.find(parent.request.texture_page);
    const child_page = try images.find(child.request.texture_page);
    const parent_alpha = try alphaFor(parent, parent_page);
    const child_alpha = try alphaFor(child, child_page);
    const child_axis = try recordAxis(child, child_alpha, context.camera);
    const parent_joint = try visual.resolveLandmark(parent, parent_alpha, parent_kind, context.camera);
    const child_joint = try visual.resolveLandmark(child, child_alpha, child_kind, context.camera);
    const full_parent_width = try crossSectionWidth(
        parent,
        parent_page,
        parent_joint.pixel,
        child_axis,
        -2.0,
        context.camera,
    );
    // Torso and pelvis are bilateral continuous surfaces. At one semantic
    // shoulder/hip, the comparable parent contour is the corresponding lobe,
    // not the full cross-body span that also includes the opposite side.
    const parent_width = full_parent_width * 0.5;
    const child_width = try crossSectionWidth(
        child,
        child_page,
        child_joint.pixel,
        child_axis,
        2.0,
        context.camera,
    );
    try recordRange(
        report,
        child,
        context,
        @tagName(child.role),
        child.side,
        jointRootMetricName(joint),
        safeRatio(child_width, parent_width),
        "ratio",
        widthRange(style_contract, joint),
    );
}

fn evaluateFoot(
    character_id: u32,
    style: []const u8,
    view: visual.View,
    side: visual.Side,
    trace: *const visual.Trace,
    images: *const audit.Images,
    context: audit.EvaluationContext,
    style_contract: Contract,
    report: *visual.Report,
) !void {
    _ = style;
    const foot = findRecord(trace, character_id, .foot, side) orelse
        return error.MissingAnatomyTarget;
    const page = try images.find(foot.request.texture_page);
    const alpha = try alphaFor(foot.*, page);
    const heel = try visual.resolveLandmark(foot.*, alpha, .heel, context.camera);
    const toe = try visual.resolveLandmark(foot.*, alpha, .toe, context.camera);
    if (view == .front) {
        const delta = toe.pixel.sub(heel.pixel);
        const outward_sign: f32 = if (side == .left) -1.0 else 1.0;
        const outward = delta.x * outward_sign;
        const angle = if (delta.y <= 0 or outward <= 0)
            180.0
        else
            std.math.radiansToDegrees(std.math.atan2(outward, delta.y));
        try recordRange(
            report,
            foot.*,
            context,
            "foot",
            side,
            "front_foot_toe_out",
            angle,
            "deg",
            style_contract.front_toe_out_degrees,
        );
    } else {
        const scale_sign: f32 = if (foot.request.scale[0] < 0) -1 else 1;
        const expected_world_start = math.Vec2{
            .x = foot.request.world_position[0],
            .y = foot.request.world_position[1],
        };
        const expected_world_end = expected_world_start.add(.{
            .x = std.math.cos(foot.binding_rotation_radians) * scale_sign,
            .y = std.math.sin(foot.binding_rotation_radians) * scale_sign,
        });
        const expected_start = try context.camera.worldToPresentation(
            expected_world_start,
            foot.request.camera_x_factor,
        );
        const expected_end = try context.camera.worldToPresentation(
            expected_world_end,
            foot.request.camera_x_factor,
        );
        try report.recordMaximum(baseMetric(
            foot.*,
            context,
            "foot",
            side,
            "side_foot_forward_axis_error",
            try visual.angleDegrees(heel.pixel, toe.pixel, expected_start, expected_end),
            "deg",
        ), style_contract.maximum_side_foot_axis_error_degrees);
    }
}

fn evaluateFrontStance(
    torso: visual.TraceRecord,
    trace: *const visual.Trace,
    images: *const audit.Images,
    context: audit.EvaluationContext,
    style_contract: Contract,
    report: *visual.Report,
) !void {
    const left = findRecord(trace, torso.character_id, .foot, .left) orelse
        return error.MissingAnatomyTarget;
    const right = findRecord(trace, torso.character_id, .foot, .right) orelse
        return error.MissingAnatomyTarget;
    const left_alpha = try alphaFor(left.*, try images.find(left.request.texture_page));
    const right_alpha = try alphaFor(right.*, try images.find(right.request.texture_page));
    const left_ankle = try visual.resolveLandmark(left.*, left_alpha, .ankle, context.camera);
    const right_ankle = try visual.resolveLandmark(right.*, right_alpha, .ankle, context.camera);
    const torso_center = try context.camera.worldToPresentation(.{
        .x = torso.request.world_position[0],
        .y = torso.request.world_position[1],
    }, torso.request.camera_x_factor);
    const symmetry_error = @abs(
        @abs(left_ankle.pixel.x - torso_center.x) -
            @abs(right_ankle.pixel.x - torso_center.x),
    );
    try report.recordMaximum(baseMetric(
        torso,
        context,
        "stance",
        .none,
        "bilateral_ankle_symmetry_error",
        symmetry_error,
        "px",
    ), style_contract.maximum_bilateral_ankle_error_px);

    const left_angle = try frontToeOut(left.*, left_alpha, .left, context.camera);
    const right_angle = try frontToeOut(right.*, right_alpha, .right, context.camera);
    try report.recordMaximum(baseMetric(
        torso,
        context,
        "stance",
        .none,
        "bilateral_toe_out_difference",
        @abs(left_angle - right_angle),
        "deg",
    ), style_contract.maximum_bilateral_toe_out_error_degrees);
}

fn frontToeOut(
    foot: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    side: visual.Side,
    camera: camera2d.Camera2D,
) !f32 {
    const heel = try visual.resolveLandmark(foot, alpha, .heel, camera);
    const toe = try visual.resolveLandmark(foot, alpha, .toe, camera);
    const delta = toe.pixel.sub(heel.pixel);
    const outward_sign: f32 = if (side == .left) -1.0 else 1.0;
    const outward = delta.x * outward_sign;
    if (delta.y <= 0 or outward <= 0) return 180.0;
    return std.math.radiansToDegrees(std.math.atan2(outward, delta.y));
}

fn findRecord(
    trace: *const visual.Trace,
    character_id: u32,
    role: visual.Role,
    side: visual.Side,
) ?*const visual.TraceRecord {
    for (trace.records[0..trace.count]) |*record| {
        if (record.character_id == character_id and
            record.role == role and
            record.side == side and
            (record.owner == .anatomy or record.owner == .base_presentation))
        {
            return record;
        }
    }
    return null;
}

fn alphaFor(
    record: visual.TraceRecord,
    page: audit.PageImage,
) !visual.AlphaGeometry {
    return visual.deriveAlphaGeometry(
        page.pixels,
        page.width,
        page.height,
        page.row_bytes,
        record.source,
    );
}

fn visiblePointPixel(
    record: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    visible_uv: [2]f32,
    camera: camera2d.Camera2D,
) !math.Vec2 {
    const local = alpha.visibleUvToLocal(visible_uv);
    const world = sprite.localPointToWorld(record.request, local);
    return camera.worldToPresentation(.{ .x = world[0], .y = world[1] }, record.request.camera_x_factor);
}

fn semanticSpan(
    record: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    start: visual.LandmarkKind,
    end: visual.LandmarkKind,
    camera: camera2d.Camera2D,
) !f32 {
    const a = try visual.resolveLandmark(record, alpha, start, camera);
    const b = try visual.resolveLandmark(record, alpha, end, camera);
    return visual.distance(a.pixel, b.pixel);
}

fn recordAxis(
    record: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    camera: camera2d.Camera2D,
) !math.Vec2 {
    const kinds = switch (record.role) {
        .upper_arm => .{ visual.LandmarkKind.shoulder, visual.LandmarkKind.elbow },
        .forearm => .{ visual.LandmarkKind.elbow, visual.LandmarkKind.wrist },
        .hand => .{ visual.LandmarkKind.wrist, visual.LandmarkKind.fingertip },
        .thigh => .{ visual.LandmarkKind.hip, visual.LandmarkKind.knee },
        .shin => .{ visual.LandmarkKind.knee, visual.LandmarkKind.ankle },
        .foot => .{ visual.LandmarkKind.ankle, visual.LandmarkKind.toe },
        else => return error.UnsupportedAnatomyAxis,
    };
    return axisBetween(record, alpha, kinds[0], kinds[1], camera);
}

fn axisBetween(
    record: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    start: visual.LandmarkKind,
    end: visual.LandmarkKind,
    camera: camera2d.Camera2D,
) !math.Vec2 {
    const a = try visual.resolveLandmark(record, alpha, start, camera);
    const b = try visual.resolveLandmark(record, alpha, end, camera);
    const delta = b.pixel.sub(a.pixel);
    const length = delta.length();
    if (length <= std.math.floatEps(f32)) return error.DegenerateAnatomyAxis;
    return delta.scale(1.0 / length);
}

fn crossSectionWidth(
    record: visual.TraceRecord,
    page: audit.PageImage,
    center: math.Vec2,
    axis: math.Vec2,
    axial_inset_px: f32,
    camera: camera2d.Camera2D,
) !f32 {
    const perpendicular = math.Vec2{ .x = -axis.y, .y = axis.x };
    var best: f32 = 0;
    var axial_offset: i32 = -1;
    while (axial_offset <= 1) : (axial_offset += 1) {
        const sample_center = center.add(axis.scale(
            axial_inset_px + @as(f32, @floatFromInt(axial_offset)),
        ));
        var minimum = std.math.inf(f32);
        var maximum = -std.math.inf(f32);
        var offset: i32 = -48;
        while (offset <= 48) : (offset += 1) {
            const pixel = sample_center.add(perpendicular.scale(@floatFromInt(offset)));
            if (pixel.x < 0 or pixel.y < 0 or
                pixel.x >= @as(f32, @floatFromInt(camera.viewport_width)) or
                pixel.y >= @as(f32, @floatFromInt(camera.viewport_height)))
            {
                continue;
            }
            const world = try camera.presentationToWorld(pixel);
            if (try visual.sampleAlphaAtWorld(
                record,
                page.pixels,
                page.width,
                page.height,
                page.row_bytes,
                world,
            )) {
                const value: f32 = @floatFromInt(offset);
                minimum = @min(minimum, value);
                maximum = @max(maximum, value);
            }
        }
        if (std.math.isFinite(minimum) and std.math.isFinite(maximum)) {
            best = @max(best, maximum - minimum + 1.0);
        }
    }
    if (best <= 0) return error.EmptyAnatomyCrossSection;
    return best;
}

fn visibleVerticalSpan(
    record: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    camera: camera2d.Camera2D,
) !f32 {
    const top = try visiblePointPixel(record, alpha, .{ 0.5, 0 }, camera);
    const bottom = try visiblePointPixel(record, alpha, .{ 0.5, 1 }, camera);
    return visual.distance(top, bottom);
}

fn endpointDarkRatio(
    record: visual.TraceRecord,
    page: audit.PageImage,
    alpha: visual.AlphaGeometry,
    start: visual.LandmarkKind,
    end: visual.LandmarkKind,
    at_start: bool,
) !f32 {
    const start_landmark = record.geometry.find(start) orelse
        return error.MissingSemanticLandmark;
    const end_landmark = record.geometry.find(end) orelse
        return error.MissingSemanticLandmark;
    const endpoint = if (at_start) start_landmark.visible_uv else end_landmark.visible_uv;
    const interior = if (at_start) end_landmark.visible_uv else start_landmark.visible_uv;
    const width: f32 = @floatFromInt(alpha.opaque_bounds.width -| 1);
    const height: f32 = @floatFromInt(alpha.opaque_bounds.height -| 1);
    var inward = math.Vec2{
        .x = (interior[0] - endpoint[0]) * width,
        .y = (interior[1] - endpoint[1]) * height,
    };
    const inward_length = inward.length();
    if (inward_length <= std.math.floatEps(f32)) return error.DegenerateAnatomyAxis;
    inward = inward.scale(1.0 / inward_length);
    const perpendicular = math.Vec2{ .x = -inward.y, .y = inward.x };
    const origin = math.Vec2{
        .x = @as(f32, @floatFromInt(alpha.opaque_bounds.x)) + endpoint[0] * width,
        .y = @as(f32, @floatFromInt(alpha.opaque_bounds.y)) + endpoint[1] * height,
    };
    const half_width: i32 = @intFromFloat(@max(
        @as(f32, 2),
        @min(@as(f32, 24), @as(f32, @floatFromInt(alpha.opaque_bounds.width)) * 0.45),
    ));
    var opaque_count: u32 = 0;
    var dark_count: u32 = 0;
    var depth: i32 = 0;
    while (depth <= 3) : (depth += 1) {
        var lateral = -half_width;
        while (lateral <= half_width) : (lateral += 1) {
            const sample = origin
                .add(inward.scale(@floatFromInt(depth)))
                .add(perpendicular.scale(@floatFromInt(lateral)));
            if (sample.x < 0 or sample.y < 0 or
                sample.x >= @as(f32, @floatFromInt(page.width)) or
                sample.y >= @as(f32, @floatFromInt(page.height)))
            {
                continue;
            }
            const x: u32 = @intFromFloat(@round(sample.x));
            const y: u32 = @intFromFloat(@round(sample.y));
            if (!isOpaque(page, x, y)) continue;
            opaque_count += 1;
            const index = @as(usize, y) * page.row_bytes + @as(usize, x) * 4;
            const luminance =
                @as(u32, page.pixels[index]) * 54 +
                @as(u32, page.pixels[index + 1]) * 183 +
                @as(u32, page.pixels[index + 2]) * 19;
            if (luminance < 110 * 256) dark_count += 1;
        }
    }
    if (opaque_count == 0) return error.EmptyJointEdgeSample;
    return @as(f32, @floatFromInt(dark_count)) /
        @as(f32, @floatFromInt(opaque_count));
}

fn isOpaque(page: audit.PageImage, x: u32, y: u32) bool {
    if (x >= page.width or y >= page.height) return false;
    const index = @as(usize, y) * page.row_bytes + @as(usize, x) * 4 + 3;
    return page.pixels[index] >= visual.alpha_threshold;
}

fn jointWidthMetricName(joint: Joint) []const u8 {
    return switch (joint) {
        .shoulder => "shoulder_width_ratio",
        .elbow => "elbow_width_ratio",
        .wrist => "wrist_width_ratio",
        .hip => "hip_width_ratio",
        .knee => "knee_width_ratio",
        .ankle => "ankle_width_ratio",
    };
}

fn jointDarkMetricName(joint: Joint) []const u8 {
    return switch (joint) {
        .shoulder => "shoulder_dark_transverse_edge",
        .elbow => "elbow_dark_transverse_edge",
        .wrist => "wrist_dark_transverse_edge",
        .hip => "hip_dark_transverse_edge",
        .knee => "knee_dark_transverse_edge",
        .ankle => "ankle_dark_transverse_edge",
    };
}

fn jointRootMetricName(joint: Joint) []const u8 {
    return switch (joint) {
        .shoulder => "shoulder_root_width_ratio",
        .hip => "hip_root_width_ratio",
        else => "unsupported_root_width_ratio",
    };
}

fn safeRatio(numerator: f32, denominator: f32) f32 {
    if (!std.math.isFinite(numerator) or !std.math.isFinite(denominator) or
        denominator <= std.math.floatEps(f32))
    {
        return std.math.inf(f32);
    }
    return numerator / denominator;
}

fn recordRange(
    report: *visual.Report,
    record: visual.TraceRecord,
    context: audit.EvaluationContext,
    component: []const u8,
    side: visual.Side,
    name: []const u8,
    actual: f32,
    unit: []const u8,
    accepted: Range,
) !void {
    try report.recordRange(
        baseMetric(record, context, component, side, name, actual, unit),
        accepted.minimum,
        accepted.maximum,
    );
}

fn baseMetric(
    record: visual.TraceRecord,
    context: audit.EvaluationContext,
    component: []const u8,
    side: visual.Side,
    name: []const u8,
    actual: f32,
    unit: []const u8,
) visual.Metric {
    return .{
        .character_style = record.style,
        .outfit = context.outfit,
        .view = record.view,
        .pose = context.pose,
        .morphology = context.morphology,
        .component = component,
        .side = side,
        .metric = name,
        .actual = actual,
        .unit = unit,
        .source = "production_trace_and_alpha",
        .outcome = .pass,
    };
}
