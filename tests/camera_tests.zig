const std = @import("std");
const math = @import("math");
const camera2d = @import("camera2d");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const input = @import("input");

const tolerance: f32 = 0.00001;

fn expectVec(expected: math.Vec2, actual: math.Vec2) !void {
    try std.testing.expect(expected.approxEqAbs(actual, tolerance));
}

test "default camera preserves the original 640 by 480 presentation" {
    const camera = camera2d.Camera2D.initDefault();
    try camera.validate();
    try expectVec(.{ .x = 320, .y = 240 }, try camera.worldToPresentation(camera.center, 1));
    try expectVec(math.Vec2.zero, try camera.worldToClip(camera.center, 1));
    try expectVec(.{ .x = 320, .y = 105 }, try camera.worldToPresentation(math.Vec2.zero, 1));

    const offset = camera.center.add(.{ .x = 2, .y = 1 });
    try expectVec(.{ .x = 484, .y = 322 }, try camera.worldToPresentation(offset, 1));
    const clip = try camera.worldToClip(offset, 1);
    try std.testing.expect(clip.x > 0);
    try std.testing.expect(clip.y > 0);
}

test "camera keeps zoom at 640 by 480 and two other aspect ratios" {
    var camera = camera2d.Camera2D.initDefault();
    const viewports = [_][2]u32{
        .{ 640, 480 },
        .{ 1280, 720 },
        .{ 800, 800 },
    };
    for (viewports) |viewport| {
        try camera.setViewport(viewport[0], viewport[1]);
        const center = try camera.worldToPresentation(camera.center, 1);
        try std.testing.expectApproxEqAbs(@as(f32, @floatFromInt(viewport[0])) * 0.5, center.x, tolerance);
        try std.testing.expectApproxEqAbs(@as(f32, @floatFromInt(viewport[1])) * 0.5, center.y, tolerance);
        const one_meter_right = try camera.worldToPresentation(camera.center.add(.{ .x = 1, .y = 0 }), 1);
        try std.testing.expectApproxEqAbs(camera2d.default_pixels_per_meter, one_meter_right.x - center.x, tolerance);
        const extents = try camera.worldHalfExtents();
        try std.testing.expectApproxEqAbs(
            @as(f32, @floatFromInt(viewport[0])) * 0.5 / camera2d.default_pixels_per_meter,
            extents.x,
            tolerance,
        );
    }
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
    try std.testing.expectError(error.NonFiniteCameraCenter, camera.setCenter(.{ .x = 0, .y = std.math.nan(f32) }));
    try std.testing.expectEqualDeep(before, camera);
    try std.testing.expectError(error.InvalidPixelsPerMeter, camera.setPixelsPerMeter(-1));
    try std.testing.expectEqualDeep(before, camera);
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
