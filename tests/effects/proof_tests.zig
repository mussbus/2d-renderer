const std = @import("std");
const p = @import("projectiles");
const e = @import("effects");
const scene_module = @import("effects_projectiles_scene");
const view = @import("effects_projectiles_view");
const queue_module = @import("render_queue");
const t = @import("support.zig");
test "proof true segment sweep catches thin walls, diagonal hits and shape extent" {
    const box = scene_module.targets[0].bounds;
    var sweep = p.collision.Sweep{ .from = .{ .x = -100, .y = 1 }, .to = .{ .x = 100, .y = 1 }, .half_extents = .zero, .layer = 1, .mask = 1, .source = null, .excluded = &.{} };
    const contact = scene_module.sweepBox(sweep, box).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.511), contact.fraction, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 2.2), contact.position.x, t.tolerance);
    sweep.half_extents.x = 0.1;
    try std.testing.expect(scene_module.sweepBox(sweep, box).?.fraction < contact.fraction);
    sweep.from = .{ .x = 0, .y = 0 };
    sweep.to = .{ .x = 4, .y = 2 };
    sweep.half_extents = .zero;
    try std.testing.expect(scene_module.sweepBox(sweep, box) != null);
    sweep.to.y = 5;
    try std.testing.expect(scene_module.sweepBox(sweep, box) == null);
}
test "proof bounce conserves remaining travel without repeated separating hits" {
    var scene = try scene_module.Scene.init(t.allocator, false);
    defer scene.deinit();
    scene.projectiles.reset();
    const id = try scene.projectiles.spawn(.{ .definition = .{ .response = .bounce, .restitution = 1 }, .position = .{ .x = 1, .y = 2.5 }, .velocity = .{ .x = 480, .y = 0 } });
    try scene.step(false);
    const result = scene.projectiles.snapshot(id).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), result.position.x, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, -480), result.velocity.x, t.tolerance);
    try std.testing.expectEqual(@as(u64, 1), scene.statistics.collisions);
}
test "proof same-seed replay and arbitrary render submissions preserve gameplay" {
    var a = try scene_module.Scene.init(t.allocator, true);
    defer a.deinit();
    var b = try scene_module.Scene.init(t.allocator, false);
    defer b.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(t.allocator, 2048, 1792, 256, 1);
    defer queue.deinit();
    var first: [1500]e.RenderInstance = undefined;
    var first_count: usize = 0;
    for (0..2) |run| {
        try a.reset(scene_module.seed, true);
        try b.reset(scene_module.seed, false);
        for (0..480) |tick| {
            try a.step(true);
            try b.step(false);
            if (tick % 4 == 0) {
                queue.beginFrame();
                try view.submit(&a, &queue, 0.3, true);
                _ = queue.prepare();
            }
            var pa: [32]p.Snapshot = undefined;
            var pb: [32]p.Snapshot = undefined;
            try std.testing.expectEqualDeep(try a.projectiles.copySnapshots(&pa), try b.projectiles.copySnapshots(&pb));
            if (tick == 255) {
                if (run == 0) first_count = (try a.effects.extract(&first, 1)).len else {
                    var second: [1500]e.RenderInstance = undefined;
                    try std.testing.expectEqualDeep(first[0..first_count], try a.effects.extract(&second, 1));
                }
            }
        }
        try std.testing.expectEqual(@as(u64, 3), a.statistics.collisions);
        try std.testing.expectEqual(@as(u64, 1), a.statistics.deflections);
        try std.testing.expectEqual(@as(u64, 3), a.statistics.expirations);
        try std.testing.expectEqual(@as(u64, 0), a.effects.metrics().dropped_particles);
        try std.testing.expectEqual(@as(u64, 0), a.bridge.metrics.dropped_effects);
    }
}
test "proof update reset spawn deflect and extraction allocate nothing after initialization" {
    var allocator = std.testing.FailingAllocator.init(t.allocator, .{});
    var scene = try scene_module.Scene.init(allocator.allocator(), true);
    defer scene.deinit();
    const initial = allocator.allocations;
    allocator.fail_index = allocator.alloc_index;
    try scene.resetWithOwnershipProof(scene_module.seed, true);
    allocator.resize_fail_index = allocator.resize_index;
    for (0..720) |_| try scene.step(true);
    try scene.reset(scene_module.seed, true);
    try scene.spawnExtra();
    try scene.deflectFirst();
    try scene.step(true);
    var output: [1500]e.RenderInstance = undefined;
    _ = try scene.effects.extract(&output, 0.5);
    try std.testing.expectEqual(initial, allocator.allocations);
    try std.testing.expect(!allocator.has_induced_failure);
}
fn allocate(allocator: std.mem.Allocator) !void {
    var scene = try scene_module.Scene.init(allocator, true);
    defer scene.deinit();
    try scene.step(true);
}
test "proof composed initialization cleans every allocation failure" {
    try std.testing.checkAllAllocationFailures(t.allocator, allocate, .{});
}

test "core public facades expose only an opaque const ownership context" {
    inline for (.{ p.System, e.System }) |System| {
        inline for (@typeInfo(System).@"struct".fields) |field| {
            const pointer = @typeInfo(field.type).pointer;
            try std.testing.expect(pointer.is_const);
            try std.testing.expect(pointer.child == anyopaque);
        }
    }
}

test "proof real sweep excludes overlapping new source and hits former source after transfer" {
    var scene = try scene_module.Scene.init(t.allocator, false);
    defer scene.deinit();
    scene.projectiles.reset();
    const id = try scene.projectiles.spawn(.{ .definition = .{ .layer = 4, .mask = 8 }, .position = .{ .x = 1.5, .y = -0.65 }, .velocity = .{ .x = 6, .y = 0 }, .source = scene_module.source_a, .affiliation = scene_module.affiliation_a });
    try scene.projectiles.deflect(id, .{ .velocity = .{ .x = -960, .y = 0 }, .source = .{ .value = scene_module.source_b }, .affiliation = .{ .value = scene_module.affiliation_b }, .layer = 8, .mask = 4 });
    scene.projectiles.clearEvents();
    try scene.projectiles.step(.{ .context = &scene.world, .collect = scene_module.collectTargets });
    try std.testing.expectEqual(@as(usize, 2), scene.projectiles.events().len);
    const event = scene.projectiles.events()[1];
    try std.testing.expectEqual(p.EventKind.collided, event.kind);
    try std.testing.expectEqual(@as(u16, 4), event.hit.?.collider_id);
    try std.testing.expect(event.hit.?.entity_id.?.eql(scene_module.source_a));
    try std.testing.expect(event.projectile.source.?.eql(scene_module.source_b));
    try std.testing.expectEqual(@as(usize, 0), scene.projectiles.count());
}
test "proof ownership scenario repeats and presentation cannot change redirected simulation" {
    var a = try scene_module.Scene.init(t.allocator, true);
    defer a.deinit();
    var b = try scene_module.Scene.init(t.allocator, false);
    defer b.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(t.allocator, 2048, 1792, 256, 1);
    defer queue.deinit();
    var first: [1500]e.RenderInstance = undefined;
    var first_count: usize = 0;
    for (0..2) |run| {
        try a.resetWithOwnershipProof(scene_module.seed, true);
        try b.resetWithOwnershipProof(scene_module.seed, false);
        for (0..480) |tick| {
            try a.step(true);
            try b.step(false);
            var pa: [32]p.Snapshot = undefined;
            var pb: [32]p.Snapshot = undefined;
            try std.testing.expectEqualDeep(try a.projectiles.copySnapshots(&pa), try b.projectiles.copySnapshots(&pb));
            try std.testing.expectEqualDeep(a.statistics, b.statistics);
            if (tick % 4 == 0) {
                queue.beginFrame();
                try view.submit(&a, &queue, 0.7, true);
                _ = queue.prepare();
            }
            if (tick == 255) {
                if (run == 0) first_count = (try a.effects.extract(&first, 1)).len else {
                    var second: [1500]e.RenderInstance = undefined;
                    try std.testing.expectEqualDeep(first[0..first_count], try a.effects.extract(&second, 1));
                }
            }
        }
        try std.testing.expectEqual(@as(u64, 4), a.statistics.collisions);
        try std.testing.expectEqual(@as(u64, 2), a.statistics.deflections);
        try std.testing.expectEqual(@as(u64, 3), a.statistics.expirations);
        try std.testing.expectEqual(@as(u64, 1), a.statistics.ownership_transfers);
        try std.testing.expectEqual(@as(u64, 1), a.statistics.former_source_hits);
        try std.testing.expectEqual(@as(u64, 0), a.statistics.new_source_hits);
        try std.testing.expectEqual(@as(u64, 0), a.effects.metrics().dropped_particles);
        try std.testing.expectEqual(@as(u64, 0), a.bridge.metrics.dropped_effects);
    }
}
