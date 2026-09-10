const std = @import("std");
const math = @import("math");
const camera2d = @import("camera2d");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const input = @import("input");

const tolerance: f32 = 0.00001;
// World-to-presentation subtracts nearby f32 values whose magnitude reaches
// thousands at 4K. 0.0001 px covers that observed cancellation error while
// remaining four orders of magnitude below one physical pixel.
const presentation_pixel_tolerance: f32 = 0.0001;

fn expectVec(expected: math.Vec2, actual: math.Vec2) !void {
    try std.testing.expect(expected.approxEqAbs(actual, tolerance));
}

test "default camera preserves the original 640 by 480 presentation" {
    const camera = camera2d.Camera2D.initDefault();
    try camera.validate();
    try std.testing.expectApproxEqAbs(
        camera2d.reference_pixels_per_meter,
        camera.pixels_per_meter,
        tolerance,
    );
    const extents = try camera.worldHalfExtents();
    try std.testing.expectApproxEqAbs(
        camera2d.reference_vertical_world_span,
        extents.y * 2,
        tolerance,
    );
    try expectVec(.{ .x = 320, .y = 240 }, try camera.worldToPresentation(camera.center, 1));
    try expectVec(math.Vec2.zero, try camera.worldToClip(camera.center, 1));
    try expectVec(.{ .x = 320, .y = 105 }, try camera.worldToPresentation(math.Vec2.zero, 1));

    const offset = camera.center.add(.{ .x = 2, .y = 1 });
    try expectVec(.{ .x = 484, .y = 322 }, try camera.worldToPresentation(offset, 1));
    const clip = try camera.worldToClip(offset, 1);
    try std.testing.expect(clip.x > 0);
    try std.testing.expect(clip.y > 0);
}

test "drawable height scales pixel density linearly and preserves vertical world span" {
    var camera = camera2d.Camera2D.initDefault();
    const cases = [_]struct {
        width: u32,
        height: u32,
        pixels_per_meter: f32,
    }{
        .{ .width = 640, .height = 480, .pixels_per_meter = 82.0 },
        .{ .width = 1280, .height = 720, .pixels_per_meter = 123.0 },
        .{ .width = 1920, .height = 1080, .pixels_per_meter = 184.5 },
        .{ .width = 2560, .height = 1440, .pixels_per_meter = 246.0 },
        .{ .width = 3840, .height = 2160, .pixels_per_meter = 369.0 },
    };

    for (cases) |case| {
        try camera.setViewport(case.width, case.height);
        const center = try camera.worldToPresentation(camera.center, 1);
        try std.testing.expectApproxEqAbs(
            @as(f32, @floatFromInt(case.width)) * 0.5,
            center.x,
            tolerance,
        );
        try std.testing.expectApproxEqAbs(
            @as(f32, @floatFromInt(case.height)) * 0.5,
            center.y,
            tolerance,
        );
        try std.testing.expectApproxEqAbs(case.pixels_per_meter, camera.pixels_per_meter, tolerance);
        const extents = try camera.worldHalfExtents();
        try std.testing.expectApproxEqAbs(
            camera2d.reference_vertical_world_span,
            extents.y * 2,
            tolerance,
        );
        std.debug.print(
            "camera_scaling_evidence viewport={d}x{d} ppm={d:.6} vertical_span_m={d:.9} horizontal_span_m={d:.9} center=[{d:.6},{d:.6}] reference_height_m=1.000000 reference_height_px={d:.3}\n",
            .{
                case.width,
                case.height,
                camera.pixels_per_meter,
                extents.y * 2,
                extents.x * 2,
                camera.center.x,
                camera.center.y,
                camera.pixels_per_meter,
            },
        );
    }
}

test "same aspect ratios preserve both world extents and width changes only horizontal visibility" {
    var camera = camera2d.Camera2D.initDefault();
    var expected_16_by_9_extents: ?math.Vec2 = null;
    for ([_][2]u32{
        .{ 1280, 720 },
        .{ 1920, 1080 },
        .{ 3840, 2160 },
    }) |viewport| {
        try camera.setViewport(viewport[0], viewport[1]);
        const extents = try camera.worldHalfExtents();
        if (expected_16_by_9_extents) |expected| {
            try expectVec(expected, extents);
        } else {
            expected_16_by_9_extents = extents;
        }
    }

    try camera.setViewport(960, 1080);
    const narrow = try camera.worldHalfExtents();
    try camera.setViewport(1920, 1080);
    const standard = try camera.worldHalfExtents();
    try camera.setViewport(2560, 1080);
    const wide = try camera.worldHalfExtents();
    try std.testing.expectApproxEqAbs(narrow.y, standard.y, tolerance);
    try std.testing.expectApproxEqAbs(standard.y, wide.y, tolerance);
    try std.testing.expect(narrow.x < standard.x);
    try std.testing.expect(standard.x < wide.x);
    std.debug.print(
        "camera_aspect_evidence height=1080 vertical_span_m={d:.9} widths=[960,1920,2560] horizontal_spans_m=[{d:.9},{d:.9},{d:.9}]\n",
        .{ standard.y * 2, narrow.x * 2, standard.x * 2, wide.x * 2 },
    );
}

test "resized camera keeps uniform axes and inverse-compatible transforms" {
    var camera = camera2d.Camera2D.initDefault();
    for ([_][2]u32{
        .{ 1280, 720 },
        .{ 1024, 1024 },
        .{ 3840, 2160 },
    }) |viewport| {
        try camera.setViewport(viewport[0], viewport[1]);
        const center = try camera.worldToPresentation(camera.center, 1);
        const right = try camera.worldToPresentation(camera.center.add(.{ .x = 1, .y = 0 }), 1);
        const up = try camera.worldToPresentation(camera.center.add(.{ .x = 0, .y = 1 }), 1);
        try std.testing.expectApproxEqAbs(
            right.x - center.x,
            up.y - center.y,
            presentation_pixel_tolerance,
        );
        try std.testing.expectApproxEqAbs(
            camera.pixels_per_meter,
            right.x - center.x,
            presentation_pixel_tolerance,
        );

        const world = camera.center.add(.{ .x = 1.75, .y = -0.625 });
        const round_trip = try camera.presentationToWorld(try camera.worldToPresentation(world, 1));
        try expectVec(world, round_trip);
    }
}

test "resize round trip derives from reference without drift or center movement" {
    var camera = camera2d.Camera2D.initDefault();
    const original = camera;
    for ([_][2]u32{
        .{ 640, 480 },
        .{ 1280, 720 },
        .{ 1920, 1080 },
        .{ 3840, 2160 },
        .{ 1024, 1024 },
        .{ 640, 480 },
    }) |viewport| {
        try camera.setViewport(viewport[0], viewport[1]);
    }
    try std.testing.expectApproxEqAbs(camera2d.reference_pixels_per_meter, camera.pixels_per_meter, tolerance);
    try expectVec(original.center, camera.center);
    try expectVec(try original.worldHalfExtents(), try camera.worldHalfExtents());
}

test "positive world Y maps upward in presentation and clip space" {
    const camera = camera2d.Camera2D.initDefault();
    const below = camera.center.add(.{ .x = 0, .y = -1 });
    const above = camera.center.add(.{ .x = 0, .y = 1 });
    const below_presentation = try camera.worldToPresentation(below, 1);
    const above_presentation = try camera.worldToPresentation(above, 1);
    const below_clip = try camera.worldToClip(below, 1);
    const above_clip = try camera.worldToClip(above, 1);
    try std.testing.expect(above_presentation.y > below_presentation.y);
    try std.testing.expect(above_clip.y > below_clip.y);
}

test "zero and invalid camera state is rejected transactionally" {
    try std.testing.expectError(error.ZeroViewport, camera2d.Camera2D.init(math.Vec2.zero, 0, 480, 82));
    try std.testing.expectError(error.ZeroViewport, camera2d.Camera2D.init(math.Vec2.zero, 640, 0, 82));
    try std.testing.expectError(error.NonFiniteCameraCenter, camera2d.Camera2D.init(.{ .x = std.math.inf(f32), .y = 0 }, 640, 480, 82));
    try std.testing.expectError(error.InvalidPixelsPerMeter, camera2d.Camera2D.init(math.Vec2.zero, 640, 480, 0));

    var camera = camera2d.Camera2D.initDefault();
    const before = camera;
    try std.testing.expectError(error.ZeroViewport, camera.setViewport(0, 720));
    try std.testing.expectEqualDeep(before, camera);
    try std.testing.expectError(error.ZeroViewport, camera.setViewport(1280, 0));
    try std.testing.expectEqualDeep(before, camera);
    try std.testing.expectError(error.ZeroViewport, camera2d.pixelsPerMeterForDrawableHeight(0));
    try camera.setViewport(1920, 1080);
    try std.testing.expectApproxEqAbs(@as(f32, 184.5), camera.pixels_per_meter, tolerance);
    try camera.validate();
    const before_invalid_center = camera;
    try std.testing.expectError(error.NonFiniteCameraCenter, camera.setCenter(.{ .x = 0, .y = std.math.nan(f32) }));
    try std.testing.expectEqualDeep(before_invalid_center, camera);
    try std.testing.expectError(error.InvalidPixelsPerMeter, camera.setPixelsPerMeter(-1));
    try std.testing.expectEqualDeep(before_invalid_center, camera);
    try std.testing.expectError(error.InvalidCameraXFactor, camera.worldToPresentation(math.Vec2.zero, -0.01));
    try std.testing.expectError(error.InvalidCameraXFactor, camera.worldToPresentation(math.Vec2.zero, 1.01));
}

test "parallax factors produce hand-derived relative camera displacement" {
    var camera = camera2d.Camera2D.initDefault();
    const world = math.Vec2{ .x = 8, .y = 2 };
    const initial_full = try camera.worldToPresentation(world, 1);
    const initial_mid = try camera.worldToPresentation(world, 0.5);
    const initial_far = try camera.worldToPresentation(world, 0.125);
    try camera.setCenter(.{ .x = 4, .y = camera.center.y });
    const moved_full = try camera.worldToPresentation(world, 1);
    const moved_mid = try camera.worldToPresentation(world, 0.5);
    const moved_far = try camera.worldToPresentation(world, 0.125);
    try std.testing.expectApproxEqAbs(-328, moved_full.x - initial_full.x, tolerance);
    try std.testing.expectApproxEqAbs(-164, moved_mid.x - initial_mid.x, tolerance);
    try std.testing.expectApproxEqAbs(-41, moved_far.x - initial_far.x, tolerance);
}

test "resize changes presentation without changing authoritative simulation" {
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    const controller = try character_controller.CharacterController.init(.{}, &world, .{ .x = -4, .y = 1.05 }, .right);
    const before = controller.state;
    var camera = camera2d.Camera2D.initDefault();
    const before_pixel = try camera.worldToPresentation(controller.state.position, 1);
    try camera.setViewport(1280, 720);
    const after_pixel = try camera.worldToPresentation(controller.state.position, 1);
    try std.testing.expect(after_pixel.x != before_pixel.x);
    try std.testing.expect(after_pixel.y != before_pixel.y);
    try std.testing.expectEqualDeep(before, controller.state);
}

test "camera follow cannot change controller physics" {
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    var baseline = try character_controller.CharacterController.init(.{}, &world, .{ .x = -4, .y = 1.05 }, .right);
    var observed = try character_controller.CharacterController.init(.{}, &world, .{ .x = -4, .y = 1.05 }, .right);
    var camera = camera2d.Camera2D.initDefault();
    const follower = try camera2d.HorizontalFollower.init(1.5);

    for (0..720) |tick| {
        const axis: f32 = if (tick < 240) 1 else if (tick < 480) -1 else 0;
        const intent_value = input.CharacterIntent{
            .move_axis = axis,
            .jump_pressed = tick == 120,
            .jump_held = tick >= 120 and tick < 150,
            .jump_released = tick == 150,
            .interact_pressed = false,
        };
        _ = try baseline.step(&world, intent_value);
        _ = try observed.step(&world, intent_value);
        try follower.update(&camera, observed.state.position.x);
    }
    try std.testing.expectEqualDeep(baseline.state, observed.state);
}

test "repeated horizontal camera updates are bit deterministic" {
    var first = camera2d.Camera2D.initDefault();
    var second = camera2d.Camera2D.initDefault();
    const follower = try camera2d.HorizontalFollower.init(2.75);
    const targets = [_]f32{ 0, 1, 4, 8, 8, -3, -9, 2, 2, 12 };
    for (0..128) |_| {
        for (targets) |target| {
            try follower.update(&first, target);
            try follower.update(&second, target);
        }
    }
    try std.testing.expectEqualDeep(first, second);
}

test "camera uniform is the exact GPU clip contract" {
    const camera = try camera2d.Camera2D.init(.{ .x = 3, .y = -2 }, 800, 600, 100);
    const uniform = try camera.uniform();
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(camera2d.CameraUniform));
    try std.testing.expectEqual([2]f32{ 3, -2 }, uniform.center);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), uniform.clip_scale[0], tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 3.0), uniform.clip_scale[1], tolerance);
}

test "explicit camera zoom survives repeated submission refresh and drawable resizing" {
    var camera = camera2d.Camera2D.initDefault();
    for ([_]f32{ 1, 0.5, 0.25, 1 }) |scale| {
        try camera.setZoomScale(scale);
        for ([_][2]u32{ .{ 640, 480 }, .{ 1280, 720 }, .{ 1920, 1080 }, .{ 640, 480 } }) |viewport| {
            for (0..3) |_| try camera.setViewport(viewport[0], viewport[1]);
            const extents = try camera.worldHalfExtents();
            try std.testing.expectApproxEqAbs(camera2d.reference_vertical_world_span / scale, extents.y * 2, tolerance);
            try expectVec(camera2d.default_center, camera.center);
            try expectVec(math.Vec2.zero, try camera.worldToClip(camera.center, 1));
        }
    }
    try std.testing.expectEqualDeep(camera2d.Camera2D.initDefault(), camera);
}

test "invalid zoom and overflowing viewport updates leave the camera unchanged" {
    var camera = camera2d.Camera2D.initDefault();
    const before = camera;
    for ([_]f32{ 0, -1, std.math.nan(f32), std.math.inf(f32) }) |scale| {
        try std.testing.expectError(error.InvalidCameraZoom, camera.setZoomScale(scale));
        try std.testing.expectEqualDeep(before, camera);
    }
    try std.testing.expectError(error.InvalidPixelsPerMeter, camera.setZoomScale(std.math.floatMax(f32)));
    try std.testing.expectEqualDeep(before, camera);
    try camera.setZoomScale(std.math.floatMax(f32) / 100);
    const large = camera;
    try std.testing.expectError(error.InvalidPixelsPerMeter, camera.setViewport(1920, 1080));
    try std.testing.expectEqualDeep(large, camera);
    try camera.setViewport(1, 1);
    const small = camera;
    const smallest: f32 = @bitCast(@as(u32, 1));
    try std.testing.expectError(error.InvalidPixelsPerMeter, camera.setZoomScale(smallest));
    try std.testing.expectEqualDeep(small, camera);
}
