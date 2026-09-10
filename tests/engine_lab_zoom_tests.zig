const std = @import("std");
const h = @import("engine_lab");
const actions = @import("engine_lab_actions");
const physical = @import("physical_input");
const v = @import("engine_lab_view");
const q = @import("render_queue");
const math = @import("math");
const routes = @import("engine_lab_verification").traversal;
fn init(allocator: std.mem.Allocator) !h.Hub {
    return h.Hub.initExpanded(allocator, try h.Seed.parseLowerHex(h.default_seed));
}
fn close(hub: *h.Hub) void {
    hub.deinit() catch |err| h.cleanupFailure(err);
}
fn sample(hub: *h.Hub, mapper: *actions.Mapper, raw: physical.RawInputState) !void {
    try actions.advance(hub, mapper, raw, mapper.sample(raw), 0);
}

test "zoom F4 cycles once per press including short taps and reset suppresses held F4" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var mapper = actions.Mapper{};
    hub.clock.setPaused(true);
    const before = try hub.traversalFingerprint();
    try sample(&hub, &mapper, .{ .keyboard = .{ .f4 = true } });
    try std.testing.expectEqual(h.Zoom.out_2x, hub.zoom);
    for (0..3) |_| try sample(&hub, &mapper, .{ .keyboard = .{ .f4 = true } });
    try std.testing.expectEqual(h.Zoom.out_2x, hub.zoom);
    try sample(&hub, &mapper, .{});
    mapper.capturePress(.{ .f4 = true });
    try sample(&hub, &mapper, .{});
    try std.testing.expectEqual(h.Zoom.out_4x, hub.zoom);
    try sample(&hub, &mapper, .{ .keyboard = .{ .f4 = true } });
    try std.testing.expectEqual(h.Zoom.current, hub.zoom);
    try std.testing.expect(before.eql(try hub.traversalFingerprint()));
    try sample(&hub, &mapper, .{ .keyboard = .{ .f4 = true }, .focus_lost = true });
    try sample(&hub, &mapper, .{ .keyboard = .{ .f4 = true } });
    try std.testing.expectEqual(h.Zoom.current, hub.zoom);
    try sample(&hub, &mapper, .{});
    try sample(&hub, &mapper, .{ .keyboard = .{ .f4 = true } });
    try std.testing.expectEqual(h.Zoom.out_2x, hub.zoom);
    try sample(&hub, &mapper, .{});
    try sample(&hub, &mapper, .{ .keyboard = .{ .r = true, .f4 = true, .t = true } });
    try std.testing.expectEqual(h.Zoom.current, hub.zoom);
    try std.testing.expectEqual(@as(u64, 0), hub.tick);
    try sample(&hub, &mapper, .{ .keyboard = .{ .f4 = true } });
    try std.testing.expectEqual(h.Zoom.current, hub.zoom);
    try sample(&hub, &mapper, .{});
    try sample(&hub, &mapper, .{ .keyboard = .{ .f4 = true } });
    try std.testing.expectEqual(h.Zoom.out_2x, hub.zoom);
}

test "zoom spans persist through resize and navigation while reset and failed reset preserve their contracts" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    for ([_][2]u32{ .{ 640, 480 }, .{ 1280, 720 }, .{ 960, 720 }, .{ 4096, 480 } }) |size| {
        try hub.reset();
        try hub.setViewport(size[0], size[1]);
        const baseline = try hub.camera.worldHalfExtents();
        for ([_]f32{ 2, 4 }) |factor| {
            try hub.cycleZoom();
            for (0..3) |_| try hub.setViewport(size[0], size[1]);
            const half = try hub.camera.worldHalfExtents();
            // Exact power-of-two scales; 1e-5 m covers f32 camera arithmetic.
            try std.testing.expectApproxEqAbs(baseline.x * factor, half.x, 1e-5);
            try std.testing.expectApproxEqAbs(baseline.y * factor, half.y, 1e-5);
            for ([_]h.Destination{ .hierarchy, .springs }) |destination| {
                try hub.navigate(destination);
                const root = hub.actor.worldPosition();
                const projected = try hub.camera.worldToClip(root, 1);
                try std.testing.expect(@abs(projected.x) <= 1 and @abs(projected.y) <= 1);
                try std.testing.expectEqual(factor, hub.zoom.factor());
                try std.testing.expect(hub.camera.center.x - half.x <= -24 or hub.camera.center.x + half.x <= 8 + 1e-5);
                try std.testing.expect(hub.camera.center.y - half.y <= 0.00001);
                const floor_pixel = try hub.camera.worldToClip(.{ .x = root.x, .y = 0 }, 1);
                // Floor remains above the footer and frame edge at both zooms.
                try std.testing.expect(floor_pixel.y > -0.8);
            }
            if (factor == 4) try std.testing.expectEqual(@as(f32, 7), hub.camera.center.y);
            const camera_before = hub.camera;
            try std.testing.expectError(error.ZeroViewport, hub.setViewport(0, size[1]));
            try std.testing.expectEqualDeep(camera_before, hub.camera);
        }
        const zoom_before = hub.zoom;
        const camera_before = hub.camera;
        const state_before = try hub.traversalFingerprint();
        tracking.fail_index = tracking.alloc_index;
        try std.testing.expectError(error.OutOfMemory, hub.reset());
        tracking.fail_index = std.math.maxInt(usize);
        try std.testing.expectEqual(zoom_before, hub.zoom);
        try std.testing.expectEqualDeep(camera_before, hub.camera);
        try std.testing.expect(state_before.eql(try hub.traversalFingerprint()));
        try hub.reset();
        try hub.setViewport(size[0], size[1]);
        try std.testing.expectEqual(h.Zoom.current, hub.zoom);
        try std.testing.expectEqualDeep(baseline, try hub.camera.worldHalfExtents());
    }
}

test "zooming throughout production traversal leaves route checkpoints unchanged" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    const expected = try routes.verify(std.testing.allocator, hub.seed);
    var next: usize = 0;
    for ([_]routes.Scenario{ .easy, .shortcut }) |scenario| {
        try hub.reset();
        try std.testing.expect(expected.checkpoints[next].digest.eql(try hub.traversalFingerprint()));
        next += 1;
        for (routes.segments(scenario)) |segment| {
            var elapsed: u64 = 0;
            while (elapsed < segment.ticks) : (elapsed += 1) {
                if (elapsed % 24 == 0) try hub.cycleZoom();
                try hub.advanceFrame(1.0 / 240.0, routes.input(&hub, segment, elapsed));
            }
            try routes.validateBoundary(&hub, segment);
            try std.testing.expect(expected.checkpoints[next].digest.eql(try hub.traversalFingerprint()));
            next += 1;
        }
    }
    try std.testing.expectEqual(expected.checkpoints.len, next);
}

test "zoom keeps time HUD pixels readable and rendering allocation-free" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    var view = try v.View.init(tracking.allocator());
    defer view.deinit();
    var queue = try q.UnifiedRenderQueue.init(tracking.allocator(), v.entry_capacity, v.sprite_capacity, v.mesh_capacity, 2);
    defer queue.deinit();
    queue.markStabilized();
    const allocations = tracking.alloc_index;
    const resizes = tracking.resize_index;
    var pixels: [v.time_sprite_allowance]math.Vec2 = undefined;
    var sizes: [v.time_sprite_allowance]f32 = undefined;
    for ([_][2]u32{ .{ 640, 480 }, .{ 1280, 720 }, .{ 960, 720 } }) |viewport| {
        try std.testing.expectEqual(h.Zoom.current, hub.zoom);
        try hub.setViewport(viewport[0], viewport[1]);
        var count: usize = 0;
        var sprites: usize = 0;
        for (0..3) |zoom| {
            try view.render(&hub, &queue);
            const frame = queue.prepare();
            try std.testing.expectEqual(@as(usize, 3), frame.ranges.len);
            if (zoom == 0) {
                count = view.time_sprite_count;
                sprites = frame.sprites.len;
            }
            try std.testing.expectEqual(count, view.time_sprite_count);
            try std.testing.expectEqual(sprites, frame.sprites.len);
            const time_glyphs = view.commands.commands[view.commands.count - count .. view.commands.count];
            for (time_glyphs, 0..) |command, index| {
                const pixel = try hub.camera.worldToPresentation(.{ .x = command.world_position[0], .y = command.world_position[1] }, 1);
                const size = command.scale[0] * hub.camera.pixels_per_meter;
                if (zoom == 0) {
                    pixels[index] = pixel;
                    sizes[index] = size;
                }
                // 0.001 pixel is below raster visibility and covers world-to-pixel f32 cancellation.
                try std.testing.expect(pixels[index].approxEqAbs(pixel, 0.001));
                try std.testing.expectApproxEqAbs(sizes[index], size, 0.001);
            }
            try hub.cycleZoom();
        }
    }
    try std.testing.expectEqual(allocations, tracking.alloc_index);
    try std.testing.expectEqual(resizes, tracking.resize_index);
}

test "published zoom survives the renderer drawable refresh" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    for ([_][2]u32{ .{ 640, 480 }, .{ 1280, 720 }, .{ 1920, 1080 } }) |viewport| {
        try hub.setViewport(viewport[0], viewport[1]);
        for (0..3) |_| {
            var submitted_camera = hub.camera;
            // Window submission always refreshes the acquired drawable size.
            try submitted_camera.setViewport(viewport[0], viewport[1]);
            try std.testing.expectEqualDeep(try hub.camera.uniform(), try submitted_camera.uniform());
            const player = try submitted_camera.worldToClip(hub.actor.worldPosition(), 1);
            try std.testing.expect(@abs(player.x) < 1 and @abs(player.y) < 1);
            try hub.cycleZoom();
        }
    }
}

test "all HUD sections stay fixed on the submitted screen across movement zoom and resize" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    var view = try v.View.init(tracking.allocator());
    defer view.deinit();
    var queue = try q.UnifiedRenderQueue.init(tracking.allocator(), v.entry_capacity, v.sprite_capacity, v.mesh_capacity, 2);
    defer queue.deinit();
    queue.markStabilized();
    hub.clock.setPaused(true);
    const allocations = tracking.alloc_index;
    const resizes = tracking.resize_index;
    var pixels: [3][2048]math.Vec2 = undefined;
    var sizes: [3][2048]f32 = undefined;
    for ([_][2]u32{ .{ 640, 480 }, .{ 1280, 720 }, .{ 960, 720 }, .{ 1920, 1080 } }) |viewport| {
        for ([_]bool{ false, true }) |diagnostics| {
            hub.diagnostics_enabled = diagnostics;
            for (0..3) |zoom| {
                // Presentation-only placement covers both room edges and levels;
                // the separate traversal test proves movement with real physics.
                for ([_]math.Vec2{ .{ .x = -4, .y = 1.05 }, .{ .x = -22, .y = 1.05 }, .{ .x = -22, .y = 5.85 }, .{ .x = -15, .y = 7.5 }, .{ .x = 5, .y = 1.05 } }, 0..) |position, placement| {
                    try hub.actor.stageControlledTransform(position, .right);
                    try hub.setViewport(viewport[0], viewport[1]);
                    try view.render(&hub, &queue);
                    var submitted_camera = hub.camera;
                    try submitted_camera.setViewport(viewport[0], viewport[1]);
                    for (view.hud_ranges, 0..) |range, section| {
                        try std.testing.expect(range.start < range.end);
                        for (view.commands.commands[range.start..range.end], 0..) |command, index| {
                            const point = math.Vec2{ .x = command.world_position[0], .y = command.world_position[1] };
                            const pixel = try submitted_camera.worldToPresentation(point, 1);
                            const size = command.scale[0] * submitted_camera.pixels_per_meter;
                            for ([_]f32{ -0.5, 0.5 }) |side| {
                                const clip = try submitted_camera.worldToClip(point.add(.{ .x = side * command.scale[0], .y = side * command.scale[1] }), 1);
                                try std.testing.expect(@abs(clip.x) < 1 and @abs(clip.y) < 1);
                            }
                            if (zoom == 0 and placement == 0) {
                                pixels[section][index] = pixel;
                                sizes[section][index] = size;
                            }
                            // Status text changes with the diagnostic digest, so
                            // compare its anchor; controls/time compare every pixel.
                            if (section != 1 or index == 0) {
                                // 0.001 px covers f32 cancellation, below visible motion.
                                try std.testing.expect(pixels[section][index].approxEqAbs(pixel, 0.001));
                                try std.testing.expectApproxEqAbs(sizes[section][index], size, 0.001);
                            }
                        }
                    }
                }
                try hub.cycleZoom();
            }
        }
    }
    try std.testing.expectEqual(allocations, tracking.alloc_index);
    try std.testing.expectEqual(resizes, tracking.resize_index);
}
