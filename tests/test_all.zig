const std = @import("std");
const fault_injection = @import("fault_injection");
const sprite = @import("sprite_batch");

test {
    _ = @import("math_tests.zig");
    _ = @import("skeleton_tests.zig");
    _ = @import("animation_tests.zig");
}

test "every initialization stage round-trips through its command-line name" {
    for (fault_injection.all_stages) |stage| {
        try std.testing.expectEqual(stage, fault_injection.parse(@tagName(stage)).?);
    }
    try std.testing.expect(fault_injection.parse("not_a_stage") == null);
}

test "fault injection fails exactly after the selected acquisition stage" {
    for (fault_injection.all_stages) |selected| {
        const injector = fault_injection.Injector{ .fail_after = selected };
        var observed = false;
        for (fault_injection.all_stages) |visited| {
            injector.after(visited) catch |err| {
                try std.testing.expectEqual(error.InjectedInitializationFailure, err);
                try std.testing.expectEqual(selected, visited);
                observed = true;
                break;
            };
        }
        try std.testing.expect(observed);
    }
}

fn requestWith(position: [2]f32, order: sprite.OrderInput, page: u32) sprite.SpriteRequest {
    return .{
        .world_position = position,
        .rotation = 0,
        .scale = .{ 2, 3 },
        .pivot = .{ 0, 0 },
        .uv_rect = .{ 0, 0, 1, 1 },
        .tint = .{ 1, 1, 1, 1 },
        .texture_page = page,
        .order = order,
    };
}

fn defaultOrder() sprite.OrderInput {
    return .{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 0 };
}

fn expectPoint(expected: [2]f32, actual: [2]f32) !void {
    try std.testing.expectApproxEqAbs(expected[0], actual[0], 1e-5);
    try std.testing.expectApproxEqAbs(expected[1], actual[1], 1e-5);
}

test "GPU instance layout is exact and contains only transferred scalar data" {
    try std.testing.expectEqual(@as(usize, 80), @sizeOf(sprite.SpriteSubmission));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(sprite.SpriteSubmission));
    try std.testing.expectEqual(@as(usize, 60), @offsetOf(sprite.SpriteSubmission, "texture_page"));
    try std.testing.expectEqual(@as(usize, 64), @offsetOf(sprite.SpriteSubmission, "order"));
    try std.testing.expectEqual(@as(usize, 60), @sizeOf(sprite.GpuInstance));
    try std.testing.expectEqual(@as(usize, 4), @alignOf(sprite.GpuInstance));
    try std.testing.expectEqual(@as(usize, 28), @offsetOf(sprite.GpuInstance, "uv_rect"));
    try std.testing.expectEqual(@as(usize, 44), @offsetOf(sprite.GpuInstance, "tint"));
}

test "hand-computed transform cases cover pivots rotation scale translation and degeneracy" {
    var value = requestWith(.{ 10, 20 }, defaultOrder(), 0);
    try expectPoint(.{ 12, 23 }, try sprite.transformLocalPoint(value, .{ 1, 1 }));

    value.rotation = std.math.pi / 2.0;
    value.scale = .{ 2, 4 };
    try expectPoint(.{ 10, 22 }, try sprite.transformLocalPoint(value, .{ 1, 0 }));

    value.rotation = 0;
    value.world_position = .{ 0, 0 };
    value.scale = .{ 4, 2 };
    value.pivot = .{ 0.5, 0.5 };
    try expectPoint(.{ -2, -1 }, try sprite.transformLocalPoint(value, .{ 0, 0 }));

    value.pivot = .{ 0, 1 };
    try expectPoint(.{ 4, 0 }, try sprite.transformLocalPoint(value, .{ 1, 1 }));

    value.pivot = .{ 0.25, 0.75 };
    try expectPoint(.{ 3, -0.5 }, try sprite.transformLocalPoint(value, .{ 1, 0.5 }));

    value.rotation = std.math.pi / 2.0;
    value.world_position = .{ 7, 11 };
    value.scale = .{ 2, 2 };
    value.pivot = .{ 0, 0 };
    try expectPoint(.{ 7, 13 }, try sprite.transformLocalPoint(value, .{ 1, 0 }));

    value.rotation = 0;
    value.scale = .{ -2, 3 };
    value.world_position = .{ 5, 5 };
    try expectPoint(.{ 3, 8 }, try sprite.transformLocalPoint(value, .{ 1, 1 }));

    value.scale = .{ 0, 0 };
    value.pivot = .{ 0.37, 0.91 };
    try expectPoint(.{ 5, 5 }, try sprite.transformLocalPoint(value, .{ 1, 1 }));
}

test "submission rejects non-finite transforms invalid UV tint page and unsigned layers" {
    var value = requestWith(.{ 0, 0 }, defaultOrder(), 0);
    value.rotation = std.math.inf(f32);
    try std.testing.expectError(error.InvalidNonFiniteTransform, sprite.validateRequest(value, 1));
    value.rotation = 0;
    value.uv_rect = .{ 0.8, 0, 0.2, 1 };
    try std.testing.expectError(error.InvalidUvRectangle, sprite.validateRequest(value, 1));
    value.uv_rect = .{ -0.1, 0, 1, 1 };
    try std.testing.expectError(error.InvalidUvRectangle, sprite.validateRequest(value, 1));
    value.uv_rect = .{ 0, 0, 1, 1 };
    value.tint[3] = 1.1;
    try std.testing.expectError(error.InvalidTint, sprite.validateRequest(value, 1));
    value.tint[3] = 1;
    value.texture_page = 1;
    try std.testing.expectError(error.InvalidTexturePage, sprite.validateRequest(value, 1));
    value.texture_page = 0;
    value.order.actor_layer = -1;
    try std.testing.expectError(error.InvalidActorLayer, sprite.validateRequest(value, 1));
    value.order.actor_layer = 0;
    value.order.body_part_layer = -1;
    try std.testing.expectError(error.InvalidBodyPartLayer, sprite.validateRequest(value, 1));
}

test "draw-order ranges are checked lexicographically without packing overflow" {
    const minimum = try sprite.validateOrder(.{
        .scene_layer = std.math.minInt(i16),
        .interaction_layer = std.math.minInt(i16),
        .actor_layer = 0,
        .body_part_layer = 0,
    }, 0);
    const maximum = try sprite.validateOrder(.{
        .scene_layer = std.math.maxInt(i16),
        .interaction_layer = std.math.maxInt(i16),
        .actor_layer = std.math.maxInt(u16),
        .body_part_layer = std.math.maxInt(u16),
    }, std.math.maxInt(u64));
    try std.testing.expect(sprite.keyLessThan(minimum, maximum));
    try std.testing.expectError(error.InvalidSceneLayer, sprite.validateOrder(.{
        .scene_layer = std.math.maxInt(i16) + 1,
        .interaction_layer = 0,
        .actor_layer = 0,
        .body_part_layer = 0,
    }, 0));
    const near_wrap = sprite.DrawOrderKey{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 0, .submission_index = std.math.maxInt(u64) - 1 };
    const at_limit = sprite.DrawOrderKey{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 0, .submission_index = std.math.maxInt(u64) };
    try std.testing.expect(sprite.keyLessThan(near_wrap, at_limit));
}

test "stable equal-key ordering and deterministic reverse sorting" {
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 4, 1);
    defer batch.deinit();
    batch.beginFrame();
    try batch.submit(requestWith(.{ 3, 0 }, defaultOrder(), 0));
    try batch.submit(requestWith(.{ 2, 0 }, defaultOrder(), 0));
    try batch.submit(requestWith(.{ 1, 0 }, defaultOrder(), 0));
    const equal = batch.prepare();
    try std.testing.expectEqual(@as(f32, 3), equal.sprites[0].world_position[0]);
    try std.testing.expectEqual(@as(f32, 2), equal.sprites[1].world_position[0]);
    try std.testing.expectEqual(@as(f32, 1), equal.sprites[2].world_position[0]);

    var run: usize = 0;
    while (run < 8) : (run += 1) {
        batch.beginFrame();
        var index: i32 = 3;
        while (index >= 0) : (index -= 1) {
            var order = defaultOrder();
            order.body_part_layer = index;
            try batch.submit(requestWith(.{ @floatFromInt(index), 0 }, order, 0));
        }
        const prepared = batch.prepare();
        for (prepared.sprites, 0..) |submitted, expected| {
            try std.testing.expectEqual(@as(f32, @floatFromInt(expected)), submitted.world_position[0]);
        }
    }
}

test "capacity growth preserves submissions and byte arithmetic rejects overflow" {
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 2, 1);
    defer batch.deinit();
    batch.beginFrame();
    try batch.submit(requestWith(.{ 1, 0 }, defaultOrder(), 0));
    try batch.submit(requestWith(.{ 2, 0 }, defaultOrder(), 0));
    try std.testing.expectEqual(@as(usize, 2), batch.capacity());
    batch.markStabilized();
    try batch.submit(requestWith(.{ 3, 0 }, defaultOrder(), 0));
    try std.testing.expectEqual(@as(usize, 4), batch.capacity());
    try std.testing.expectEqual(@as(u32, 1), batch.lifetime_metrics.cpu_submission_capacity_growths);
    try std.testing.expectEqual(@as(u64, 3), batch.lifetime_metrics.cpu_allocations_after_stabilization);
    const prepared = batch.prepare();
    try std.testing.expectEqual(@as(usize, 3), prepared.sprites.len);
    try std.testing.expectError(error.InstanceCapacityOverflow, sprite.nextCapacity(sprite.maximum_capacity, sprite.maximum_capacity + 1, sprite.maximum_capacity));
    try std.testing.expectError(error.ByteSizeOverflow, sprite.instanceByteSize(std.math.maxInt(usize)));
}

test "allocation failure is meaningful" {
    var bytes: [1]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&bytes);
    try std.testing.expectError(error.CpuAllocationFailure, sprite.SpriteBatch.init(fixed.allocator(), 1, 1));
}

test "empty one thousand and page-boundary batches report actual metrics" {
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, sprite.initial_capacity, 2);
    defer batch.deinit();

    batch.beginFrame();
    const empty = batch.prepare();
    try std.testing.expectEqual(@as(usize, 0), empty.sprites.len);
    try std.testing.expectEqual(@as(u32, 0), batch.frame_metrics.draw_calls);
    try std.testing.expectEqual(@as(u32, 0), batch.frame_metrics.upload_bytes);

    batch.beginFrame();
    try batch.submit(requestWith(.{ 0, 0 }, defaultOrder(), 0));
    var prepared = batch.prepare();
    try std.testing.expectEqual(@as(usize, 1), prepared.ranges.len);
    batch.recordUpload(try sprite.instanceByteSize(prepared.sprites.len));
    batch.recordDraw();
    try std.testing.expectEqual(@as(u32, 1), batch.frame_metrics.draw_calls);

    batch.beginFrame();
    for (0..1000) |index| {
        var order = defaultOrder();
        order.body_part_layer = @intCast(index % 17);
        try batch.submit(requestWith(.{ @floatFromInt(index), 0 }, order, 0));
    }
    prepared = batch.prepare();
    try std.testing.expectEqual(@as(usize, 1000), prepared.sprites.len);
    try std.testing.expectEqual(@as(usize, 1), prepared.ranges.len);
    try std.testing.expectEqual(@as(u32, 1000), batch.frame_metrics.visible_sprites);

    batch.beginFrame();
    for ([_]u32{ 0, 0, 1, 1 }) |page| {
        var order = defaultOrder();
        order.body_part_layer = @intCast(batch.frame_metrics.submitted_sprites);
        try batch.submit(requestWith(.{ 0, 0 }, order, page));
    }
    prepared = batch.prepare();
    try std.testing.expectEqual(@as(usize, 2), prepared.ranges.len);

    batch.beginFrame();
    for ([_]u32{ 0, 1, 0 }) |page| {
        var order = defaultOrder();
        order.body_part_layer = @intCast(batch.frame_metrics.submitted_sprites);
        try batch.submit(requestWith(.{ 0, 0 }, order, page));
    }
    prepared = batch.prepare();
    try std.testing.expectEqual(@as(usize, 3), prepared.ranges.len);

    batch.beginFrame();
    try std.testing.expectError(error.InvalidTexturePage, batch.submit(requestWith(.{ 0, 0 }, defaultOrder(), 2)));
    try std.testing.expectEqual(@as(u32, 0), batch.frame_metrics.submitted_sprites);
}
