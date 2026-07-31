const std = @import("std");
const math = @import("math");
const camera2d = @import("camera2d");
const sprite = @import("sprite_batch");
const render_queue = @import("render_queue");
const visual_geometry = @import("visual_geometry");

pub const semantic_sole_tolerance_px: f32 = 0.25;
pub const visual_sole_tolerance_px: f32 = 1.50;
pub const sole_endpoint_minimum_height_px: f32 = -0.50;
pub const sole_endpoint_maximum_height_px: f32 = 1.50;
pub const surface_projection_tolerance_px: f32 = 0.75;
pub const maximum_white_interior_pixels: u32 = 0;
pub const maximum_footwear_anatomy_clearance_px: f32 = 8;
pub const minimum_top_headroom_px: f32 = 16;
pub const minimum_bottom_clearance_px: f32 = 16;
pub const maximum_camera_step_px: f32 = 16;
pub const minimum_parallax_camera_travel_m: f32 = 2;
pub const minimum_parallax_separation_px: f32 = 8;
pub const maximum_parallax_prediction_error_px: f32 = 0.50;
pub const maximum_ordinary_overlap_ratio: f32 = 0.02;
pub const maximum_interaction_overlap_ratio: f32 = 0.15;
pub const root_step_slack_m: f32 = 0.001;
pub const abrupt_resize_from_width: u32 = 960;
pub const abrupt_resize_from_height: u32 = 540;
pub const abrupt_resize_to_width: u32 = 640;
pub const abrupt_resize_to_height: u32 = 480;

pub const Bounds = struct {
    minimum: math.Vec2,
    maximum: math.Vec2,

    pub fn init(point: math.Vec2) Bounds {
        return .{ .minimum = point, .maximum = point };
    }

    pub fn include(bounds: *Bounds, point: math.Vec2) !void {
        if (!point.isFinite()) return error.NonFiniteVisibleBounds;
        bounds.minimum.x = @min(bounds.minimum.x, point.x);
        bounds.minimum.y = @min(bounds.minimum.y, point.y);
        bounds.maximum.x = @max(bounds.maximum.x, point.x);
        bounds.maximum.y = @max(bounds.maximum.y, point.y);
    }

    pub fn width(bounds: Bounds) f32 {
        return bounds.maximum.x - bounds.minimum.x;
    }

    pub fn height(bounds: Bounds) f32 {
        return bounds.maximum.y - bounds.minimum.y;
    }

    pub fn validate(bounds: Bounds) !void {
        if (!bounds.minimum.isFinite() or !bounds.maximum.isFinite()) {
            return error.NonFiniteVisibleBounds;
        }
        if (bounds.maximum.x < bounds.minimum.x or
            bounds.maximum.y < bounds.minimum.y)
        {
            return error.InvertedVisibleBounds;
        }
    }
};

pub const CharacterBounds = struct {
    character_id: u32,
    world: Bounds,
    record_count: u32,
};

pub const FramingMeasurement = struct {
    top_headroom_px: f32,
    bottom_clearance_px: f32,
    left_clearance_px: f32,
    right_clearance_px: f32,

    pub fn passes(measurement: FramingMeasurement) bool {
        return measurement.top_headroom_px >= minimum_top_headroom_px and
            measurement.bottom_clearance_px >= minimum_bottom_clearance_px;
    }
};

pub const CameraCorrection = struct {
    previous_center_y: f32,
    corrected_center_y: f32,
    delta_px: f32,
    measurement: FramingMeasurement,
};

pub const AbruptResizeMeasurement = struct {
    previous_viewport: [2]u32,
    current_viewport: [2]u32,
    world_camera_delta_px: f32,
    framing: FramingMeasurement,

    pub fn passes(measurement: AbruptResizeMeasurement) bool {
        return measurement.previous_viewport[0] == abrupt_resize_from_width and
            measurement.previous_viewport[1] == abrupt_resize_from_height and
            measurement.current_viewport[0] == abrupt_resize_to_width and
            measurement.current_viewport[1] == abrupt_resize_to_height and
            measurement.framing.passes();
    }
};

pub const GroundContactInput = struct {
    planted: bool,
    canonical_sole_world: math.Vec2,
    supporting_top_y: f32,
    heel_side_sole_world: math.Vec2,
    toe_side_sole_world: math.Vec2,
};

pub const GroundContactMeasurement = struct {
    applicable: bool,
    canonical_error_px: f32,
    visual_midpoint_error_px: f32,
    heel_height_px: f32,
    toe_height_px: f32,

    pub fn passes(measurement: GroundContactMeasurement) bool {
        if (!measurement.applicable) return true;
        return measurement.canonical_error_px <= semantic_sole_tolerance_px and
            measurement.visual_midpoint_error_px <= visual_sole_tolerance_px and
            measurement.heel_height_px >= sole_endpoint_minimum_height_px and
            measurement.heel_height_px <= sole_endpoint_maximum_height_px and
            measurement.toe_height_px >= sole_endpoint_minimum_height_px and
            measurement.toe_height_px <= sole_endpoint_maximum_height_px;
    }
};

pub const GroundAlignment = struct {
    applicable: bool,
    translation_y: f32,
    sampled_sole_y: f32,
    contributing_feet: u8,
};

pub const ParallaxRole = enum(u8) {
    far,
    midground,
    gameplay,
};

pub const ParallaxAnchor = struct {
    role: ParallaxRole,
    world: math.Vec2,
    camera_x_factor: f32,
};

pub const ParallaxFrame = struct {
    camera_center_x: f32,
    screen_x: [3]f32,
};

pub const ParallaxMeasurement = struct {
    camera_travel_m: f32,
    displacement_px: [3]f32,
    predicted_px: [3]f32,
    prediction_error_px: [3]f32,

    pub fn passes(measurement: ParallaxMeasurement) bool {
        return measurement.camera_travel_m >= minimum_parallax_camera_travel_m and
            measurement.displacement_px[0] > 0 and
            measurement.displacement_px[0] < measurement.displacement_px[1] and
            measurement.displacement_px[1] < measurement.displacement_px[2] and
            measurement.displacement_px[1] - measurement.displacement_px[0] >=
                minimum_parallax_separation_px and
            measurement.displacement_px[2] - measurement.displacement_px[1] >=
                minimum_parallax_separation_px and
            measurement.prediction_error_px[0] <= maximum_parallax_prediction_error_px and
            measurement.prediction_error_px[1] <= maximum_parallax_prediction_error_px and
            measurement.prediction_error_px[2] <= maximum_parallax_prediction_error_px;
    }
};

pub fn worldToScreen(
    camera: camera2d.Camera2D,
    world: math.Vec2,
    camera_x_factor: f32,
) !math.Vec2 {
    try camera.validate();
    try camera2d.validateCameraXFactor(camera_x_factor);
    if (!world.isFinite()) return error.NonFiniteWorldPosition;
    const half_width = @as(f32, @floatFromInt(camera.viewport_width)) * 0.5;
    const half_height = @as(f32, @floatFromInt(camera.viewport_height)) * 0.5;
    return .{
        .x = half_width +
            (world.x - camera.center.x * camera_x_factor) * camera.pixels_per_meter,
        .y = half_height -
            (world.y - camera.center.y) * camera.pixels_per_meter,
    };
}

pub fn traceCharacterBounds(
    trace: *const visual_geometry.Trace,
    character_id: u32,
) !CharacterBounds {
    if (character_id == 0) return error.InvalidCharacterIdentity;
    var result: ?Bounds = null;
    var record_count: u32 = 0;
    for (trace.slice()) |record| {
        if (record.character_id != character_id or !record.isRendered()) continue;
        if (record.mesh) |mesh_trace| {
            for (mesh_trace.vertices[0..mesh_trace.vertex_count]) |vertex| {
                try includeOptional(&result, vertex.world);
            }
        } else {
            for ([_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 } }) |local| {
                const world = sprite.localPointToWorld(record.request, local);
                try includeOptional(
                    &result,
                    .{ .x = world[0], .y = world[1] },
                );
            }
        }
        record_count += 1;
    }
    const world = result orelse return error.MissingCharacterVisualBounds;
    try world.validate();
    return .{
        .character_id = character_id,
        .world = world,
        .record_count = record_count,
    };
}

/// Broad-phase visible body space for participant-presence checks. Wide
/// headwear, hair, handheld accessories, and garment flare may overlap while
/// two body cores remain clearly distinct, so occupancy is derived from the
/// submitted anatomy head/torso/pelvis instead of the full outfit AABB.
pub fn traceCharacterPresenceBounds(
    trace: *const visual_geometry.Trace,
    character_id: u32,
) !CharacterBounds {
    if (character_id == 0) return error.InvalidCharacterIdentity;
    var result: ?Bounds = null;
    var record_count: u32 = 0;
    for (trace.slice()) |record| {
        if (record.character_id != character_id or record.owner != .anatomy) {
            continue;
        }
        switch (record.role) {
            .head, .torso, .pelvis => {},
            else => continue,
        }
        if (record.mesh) |mesh_trace| {
            for (mesh_trace.vertices[0..mesh_trace.vertex_count]) |vertex| {
                try includeOptional(&result, vertex.world);
            }
        } else {
            for ([_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 } }) |local| {
                const world = sprite.localPointToWorld(record.request, local);
                try includeOptional(&result, .{ .x = world[0], .y = world[1] });
            }
        }
        record_count += 1;
    }
    const world = result orelse return error.MissingCharacterPresenceBounds;
    try world.validate();
    return .{
        .character_id = character_id,
        .world = world,
        .record_count = record_count,
    };
}

pub fn framingMeasurement(
    bounds: Bounds,
    camera: camera2d.Camera2D,
) !FramingMeasurement {
    try bounds.validate();
    const top_left = try worldToScreen(
        camera,
        .{ .x = bounds.minimum.x, .y = bounds.maximum.y },
        1,
    );
    const bottom_right = try worldToScreen(
        camera,
        .{ .x = bounds.maximum.x, .y = bounds.minimum.y },
        1,
    );
    return .{
        .top_headroom_px = top_left.y,
        .bottom_clearance_px = @as(f32, @floatFromInt(camera.viewport_height)) - bottom_right.y,
        .left_clearance_px = top_left.x,
        .right_clearance_px = @as(f32, @floatFromInt(camera.viewport_width)) - bottom_right.x,
    };
}

pub fn applyVerticalSafeRegion(
    camera: *camera2d.Camera2D,
    bounds: Bounds,
) !CameraCorrection {
    return applyVerticalSafeRegionWithPlacement(camera, bounds, .nearest);
}

pub fn centerVerticalSafeRegion(
    camera: *camera2d.Camera2D,
    bounds: Bounds,
) !CameraCorrection {
    return applyVerticalSafeRegionWithPlacement(camera, bounds, .centered);
}

const VerticalSafeRegionPlacement = enum {
    nearest,
    centered,
};

fn applyVerticalSafeRegionWithPlacement(
    camera: *camera2d.Camera2D,
    bounds: Bounds,
    placement: VerticalSafeRegionPlacement,
) !CameraCorrection {
    try bounds.validate();
    try camera.validate();
    const half_height_world =
        @as(f32, @floatFromInt(camera.viewport_height)) *
        0.5 /
        camera.pixels_per_meter;
    // Prompt 27B's 16 px margins are part of the 640x480 reference
    // composition. Keep their world size constant as drawable height scales,
    // otherwise resizing alone would move the camera center.
    const minimum_top_headroom_world =
        minimum_top_headroom_px / camera2d.reference_pixels_per_meter;
    const minimum_bottom_clearance_world =
        minimum_bottom_clearance_px / camera2d.reference_pixels_per_meter;
    const lower_center_y = bounds.maximum.y -
        (half_height_world - minimum_top_headroom_world);
    const upper_center_y = bounds.minimum.y +
        (half_height_world - minimum_bottom_clearance_world);
    if (lower_center_y > upper_center_y) return error.VisibleBoundsExceedSafeViewport;

    const previous_center_y = camera.center.y;
    const corrected_center_y = switch (placement) {
        .nearest => std.math.clamp(
            previous_center_y,
            lower_center_y,
            upper_center_y,
        ),
        .centered => lower_center_y + (upper_center_y - lower_center_y) * 0.5,
    };
    try camera.setCenter(.{
        .x = camera.center.x,
        .y = corrected_center_y,
    });
    const measurement = try framingMeasurement(bounds, camera.*);
    return .{
        .previous_center_y = previous_center_y,
        .corrected_center_y = corrected_center_y,
        .delta_px = @abs(corrected_center_y - previous_center_y) *
            camera.pixels_per_meter,
        .measurement = measurement,
    };
}

pub fn measureAbruptResize(
    previous_camera: camera2d.Camera2D,
    current_camera: camera2d.Camera2D,
    bounds: Bounds,
) !AbruptResizeMeasurement {
    if (previous_camera.viewport_width != abrupt_resize_from_width or
        previous_camera.viewport_height != abrupt_resize_from_height or
        current_camera.viewport_width != abrupt_resize_to_width or
        current_camera.viewport_height != abrupt_resize_to_height)
    {
        return error.InvalidAbruptResizeTransition;
    }
    if (!std.math.isFinite(previous_camera.center.y) or
        !std.math.isFinite(current_camera.center.y) or
        !std.math.isFinite(current_camera.pixels_per_meter))
    {
        return error.NonFiniteAbruptResizeProjection;
    }
    const framing = try framingMeasurement(bounds, current_camera);
    return .{
        .previous_viewport = .{
            previous_camera.viewport_width,
            previous_camera.viewport_height,
        },
        .current_viewport = .{
            current_camera.viewport_width,
            current_camera.viewport_height,
        },
        .world_camera_delta_px = @abs(current_camera.center.y - previous_camera.center.y) *
            current_camera.pixels_per_meter,
        .framing = framing,
    };
}

pub fn worldCameraVerticalStepPx(
    previous_camera: camera2d.Camera2D,
    current_camera: camera2d.Camera2D,
) !f32 {
    if (previous_camera.viewport_width != current_camera.viewport_width or
        previous_camera.viewport_height != current_camera.viewport_height)
    {
        return error.ViewportReprojectionIsNotWorldCameraStep;
    }
    if (!std.math.isFinite(previous_camera.center.y) or
        !std.math.isFinite(current_camera.center.y) or
        !std.math.isFinite(current_camera.pixels_per_meter))
    {
        return error.NonFiniteWorldCameraStep;
    }
    return @abs(current_camera.center.y - previous_camera.center.y) *
        current_camera.pixels_per_meter;
}

pub fn worldCameraVerticalStepPasses(
    previous_camera: camera2d.Camera2D,
    current_camera: camera2d.Camera2D,
) !bool {
    return try worldCameraVerticalStepPx(
        previous_camera,
        current_camera,
    ) <= maximum_camera_step_px;
}

pub fn measureGroundContact(
    camera: camera2d.Camera2D,
    input: GroundContactInput,
) !GroundContactMeasurement {
    const finite_values = [_]f32{
        input.supporting_top_y,
        input.canonical_sole_world.x,
        input.canonical_sole_world.y,
        input.heel_side_sole_world.x,
        input.heel_side_sole_world.y,
        input.toe_side_sole_world.x,
        input.toe_side_sole_world.y,
    };
    for (finite_values) |value| {
        if (!std.math.isFinite(value)) return error.NonFiniteGroundContactMeasurement;
    }
    if (!input.planted) {
        return .{
            .applicable = false,
            .canonical_error_px = 0,
            .visual_midpoint_error_px = 0,
            .heel_height_px = 0,
            .toe_height_px = 0,
        };
    }
    const midpoint_y =
        (input.heel_side_sole_world.y + input.toe_side_sole_world.y) * 0.5;
    return .{
        .applicable = true,
        .canonical_error_px = @abs(input.canonical_sole_world.y - input.supporting_top_y) *
            camera.pixels_per_meter,
        .visual_midpoint_error_px = @abs(midpoint_y - input.supporting_top_y) * camera.pixels_per_meter,
        .heel_height_px = (input.heel_side_sole_world.y - input.supporting_top_y) *
            camera.pixels_per_meter,
        .toe_height_px = (input.toe_side_sole_world.y - input.supporting_top_y) *
            camera.pixels_per_meter,
    };
}

/// Resolves an alpha-tight semantic landmark without decoding pixels in the
/// steady-state route. Prompt 23/25D production regions are audited
/// alpha-tight; the half-texel convention keeps this transform within one
/// source texel of the audit-time alpha-derived resolver.
pub fn alphaTightLandmarkWorld(
    record: visual_geometry.TraceRecord,
    kind: visual_geometry.LandmarkKind,
) !math.Vec2 {
    if (record.mesh != null) {
        if (record.world_geometry) |geometry| {
            return geometry.find(kind) orelse error.MissingSemanticLandmark;
        }
    }
    const landmark = record.geometry.find(kind) orelse
        return error.MissingSemanticLandmark;
    const width: f32 = @floatFromInt(record.source.width);
    const height: f32 = @floatFromInt(record.source.height);
    if (width <= 0 or height <= 0) return error.InvalidSemanticSource;
    // Prompt 25's alpha-tight source rectangles retain a two-source-pixel
    // sampling guard. The same guard is present on the Prompt 25B component
    // atlas. Keeping it explicit here makes the hot-path transform match the
    // audit-time alpha resolver without reading texture pixels per frame.
    const guard: f32 = 2;
    if (width <= guard * 2 or height <= guard * 2) {
        return error.InvalidSemanticSource;
    }
    const local = [2]f32{
        (guard + landmark.visible_uv[0] * (width - guard * 2 - 1) + 0.5) / width,
        1.0 -
            (guard + landmark.visible_uv[1] * (height - guard * 2 - 1) + 0.5) /
                height,
    };
    const world = sprite.localPointToWorld(record.request, local);
    return .{ .x = world[0], .y = world[1] };
}

pub fn groundAlignment(
    trace: *const visual_geometry.Trace,
    character_id: u32,
    supporting_top_y: f32,
    left_planted: bool,
    right_planted: bool,
) !GroundAlignment {
    if (character_id == 0 or !std.math.isFinite(supporting_top_y)) {
        return error.InvalidGroundAlignmentInput;
    }
    var selected: [2]?visual_geometry.TraceRecord = .{ null, null };
    for (trace.slice()) |record| {
        if (record.character_id != character_id or
            !record.isRendered() or
            (record.role != .foot and record.role != .shoe) or
            record.side == .none)
        {
            continue;
        }
        const side_index: usize = if (record.side == .left) 0 else 1;
        if (selected[side_index] == null or
            record.request.order.body_part_layer >
                selected[side_index].?.request.order.body_part_layer)
        {
            selected[side_index] = record;
        }
    }
    var sole_sum: f32 = 0;
    var contributing_feet: u8 = 0;
    for (selected, 0..) |maybe_record, index| {
        const record = maybe_record orelse continue;
        const use_foot = if (index == 0) left_planted else right_planted;
        if (!use_foot) continue;
        const heel = try alphaTightLandmarkWorld(record, .sole_back);
        const toe = try alphaTightLandmarkWorld(record, .sole_front);
        sole_sum += (heel.y + toe.y) * 0.5;
        contributing_feet = std.math.add(u8, contributing_feet, 1) catch
            return error.GroundAlignmentFootCountOverflow;
    }
    if (contributing_feet == 0) {
        return .{
            .applicable = false,
            .translation_y = 0,
            .sampled_sole_y = 0,
            .contributing_feet = 0,
        };
    }
    const sampled_sole_y = sole_sum / @as(f32, @floatFromInt(contributing_feet));
    return .{
        .applicable = true,
        .translation_y = supporting_top_y - sampled_sole_y,
        .sampled_sole_y = sampled_sole_y,
        .contributing_feet = contributing_feet,
    };
}

pub fn translateCharacterSubmissions(
    queue: *render_queue.UnifiedRenderQueue,
    trace: *visual_geometry.Trace,
    character_id: u32,
    translation: math.Vec2,
) !void {
    if (character_id == 0 or !translation.isFinite()) {
        return error.InvalidPresentationTranslation;
    }
    for (trace.sliceMutable()) |*record| {
        if (record.character_id != character_id) continue;
        record.request.world_position[0] += translation.x;
        record.request.world_position[1] += translation.y;
        if (record.registration) |*registration| {
            for (registration.points[0..registration.point_count]) |*point| {
                point.target_world = point.target_world.add(translation);
                point.transformed_world = point.transformed_world.add(translation);
            }
            if (registration.axis) |*axis| {
                axis.transformed_start_world =
                    axis.transformed_start_world.add(translation);
                axis.transformed_end_world =
                    axis.transformed_end_world.add(translation);
                axis.expected_end_world = axis.expected_end_world.add(translation);
            }
        }
        if (record.world_geometry) |*geometry| {
            for (geometry.landmarks[0..geometry.landmark_count]) |*landmark| {
                landmark.world = landmark.world.add(translation);
            }
        }
        if (record.mesh) |*mesh_trace| {
            for (mesh_trace.vertices[0..mesh_trace.vertex_count]) |*vertex| {
                vertex.world = vertex.world.add(translation);
            }
        }
        if (!record.isRendered()) continue;
        if (record.submission_index == std.math.maxInt(u32)) {
            return error.MissingProductionSubmissionIdentity;
        }
        const index: usize = @intCast(record.submission_index);
        if (record.mesh != null) {
            if (index >= queue.mesh_count) return error.InvalidMeshSubmissionIdentity;
            queue.mesh_submissions[index].gpu_instance.world_translation[0] += translation.x;
            queue.mesh_submissions[index].gpu_instance.world_translation[1] += translation.y;
        } else {
            if (index >= queue.sprite_count) return error.InvalidSpriteSubmissionIdentity;
            queue.sprite_submissions[index].world_position[0] += translation.x;
            queue.sprite_submissions[index].world_position[1] += translation.y;
        }
    }
}

pub fn overlapRatio(first: Bounds, second: Bounds) !f32 {
    try first.validate();
    try second.validate();
    const overlap_width = @max(
        @as(f32, 0),
        @min(first.maximum.x, second.maximum.x) -
            @max(first.minimum.x, second.minimum.x),
    );
    const overlap_height = @max(
        @as(f32, 0),
        @min(first.maximum.y, second.maximum.y) -
            @max(first.minimum.y, second.minimum.y),
    );
    const first_area = first.width() * first.height();
    const second_area = second.width() * second.height();
    const smaller_area = @min(first_area, second_area);
    if (smaller_area <= std.math.floatEps(f32)) return error.DegenerateCharacterBounds;
    return overlap_width * overlap_height / smaller_area;
}

pub fn overlapPasses(ratio: f32, interaction_active: bool) bool {
    if (!std.math.isFinite(ratio) or ratio < 0) return false;
    return ratio <= if (interaction_active)
        maximum_interaction_overlap_ratio
    else
        maximum_ordinary_overlap_ratio;
}

pub fn surfaceOrderingValid(
    terrain_layer: i32,
    surface_layer: i32,
    character_layer: i32,
    debug_layer: i32,
) bool {
    return terrain_layer < surface_layer and
        surface_layer < character_layer and
        character_layer < debug_layer;
}

pub fn sampleParallaxFrame(
    camera: camera2d.Camera2D,
    anchors: [3]ParallaxAnchor,
) !ParallaxFrame {
    var screen_x: [3]f32 = undefined;
    for (anchors, 0..) |anchor, index| {
        if (@intFromEnum(anchor.role) != index) return error.ParallaxAnchorOrderMismatch;
        screen_x[index] = (try worldToScreen(
            camera,
            anchor.world,
            anchor.camera_x_factor,
        )).x;
    }
    return .{ .camera_center_x = camera.center.x, .screen_x = screen_x };
}

pub fn measureParallax(
    start: ParallaxFrame,
    finish: ParallaxFrame,
    anchors: [3]ParallaxAnchor,
    pixels_per_meter: f32,
) !ParallaxMeasurement {
    if (!std.math.isFinite(pixels_per_meter) or pixels_per_meter <= 0) {
        return error.InvalidPixelsPerMeter;
    }
    const camera_travel_m = @abs(finish.camera_center_x - start.camera_center_x);
    var displacement_px: [3]f32 = undefined;
    var predicted_px: [3]f32 = undefined;
    var prediction_error_px: [3]f32 = undefined;
    for (anchors, 0..) |anchor, index| {
        displacement_px[index] =
            @abs(finish.screen_x[index] - start.screen_x[index]);
        predicted_px[index] =
            camera_travel_m * anchor.camera_x_factor * pixels_per_meter;
        prediction_error_px[index] =
            @abs(displacement_px[index] - predicted_px[index]);
    }
    return .{
        .camera_travel_m = camera_travel_m,
        .displacement_px = displacement_px,
        .predicted_px = predicted_px,
        .prediction_error_px = prediction_error_px,
    };
}

pub fn controlledRootStepPasses(
    previous: math.Vec2,
    current: math.Vec2,
    maximum_speed_mps: f32,
    fixed_dt: f32,
) bool {
    if (!previous.isFinite() or !current.isFinite() or
        !std.math.isFinite(maximum_speed_mps) or maximum_speed_mps < 0 or
        !std.math.isFinite(fixed_dt) or fixed_dt <= 0)
    {
        return false;
    }
    return current.sub(previous).length() <=
        maximum_speed_mps * fixed_dt + root_step_slack_m;
}

fn includeOptional(bounds: *?Bounds, point: math.Vec2) !void {
    if (!point.isFinite()) return error.NonFiniteVisibleBounds;
    if (bounds.*) |*present| {
        try present.include(point);
    } else {
        bounds.* = Bounds.init(point);
    }
}
