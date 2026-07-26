const std = @import("std");
const input = @import("input");
const render_queue = @import("render_queue");
const camera2d = @import("camera2d");
const foundation = @import("foundation_playground");

test "bounded foundation script verifies world customization properties abilities interaction resize and reset" {
    var scene = try foundation.Scene.init(std.testing.allocator, false);
    defer scene.deinit();
    var builder = input.SnapshotBuilder{};
    var script = foundation.ScriptedInput{};
    var queue = try render_queue.UnifiedRenderQueue.init(std.testing.allocator, 512, 448, 64, 1);
    defer queue.deinit();
    queue.markStabilized();

    for (0..foundation.required_frames) |_| {
        const snapshot = try builder.update(script.nextRaw(&scene));
        try scene.updateFrame(1.0 / 60.0, snapshot);
        try script.observe(&scene);
        queue.beginFrame();
        _ = try scene.submit(&queue);
        const prepared = queue.prepare();
        try std.testing.expect(prepared.sprites.len > 0);
        try std.testing.expect(prepared.meshes.len > 0);
        try std.testing.expect(prepared.ranges.len <= prepared.sprites.len + prepared.meshes.len);
    }
    try scene.validateComplete(&script);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}

test "synthetic viewport changes preserve gameplay loadout capabilities and pending input edges" {
    var scene = try foundation.Scene.init(std.testing.allocator, false);
    defer scene.deinit();
    var builder = input.SnapshotBuilder{};
    var raw = input.RawInputState{};
    raw.keyboard.space = true;
    const snapshot = try builder.update(raw);
    try scene.updateFrame(0, snapshot);
    const before = scene.gameplayState();
    const pending_before = scene.pending_input.pendingEdgeCount();
    try scene.applyViewport(1024, 576);
    try scene.applyViewport(1440, 900);
    const after = scene.gameplayState();
    try std.testing.expect(foundation.gameplayStatesEqual(before, after, 0));
    try std.testing.expectEqual(pending_before, scene.pending_input.pendingEdgeCount());
    try std.testing.expectEqual(@as(u32, 1440), scene.camera.viewport_width);
    try std.testing.expectEqual(@as(u32, 900), scene.camera.viewport_height);
    try std.testing.expectEqual(@as(u32, 2), scene.evidence.resize_events);
}

test "foundation reset restores the complete configured baseline without stale mesh or secondary state" {
    var scene = try foundation.Scene.init(std.testing.allocator, false);
    defer scene.deinit();
    var builder = input.SnapshotBuilder{};
    for ([_]input.KeyboardState{
        .{ .c = true },
        .{},
        .{ .v = true },
        .{},
        .{ .h = true },
        .{},
        .{ .l = true },
        .{},
        .{ .r = true },
    }) |keyboard| {
        const snapshot = try builder.update(.{ .keyboard = keyboard });
        try scene.updateFrame(1.0 / 60.0, snapshot);
    }
    const state = scene.gameplayState();
    try std.testing.expect(state.position.approxEqAbs(foundation.player_spawn, 0.000001));
    try std.testing.expect(state.velocity.approxEqAbs(@import("math").Vec2.zero, 0.000001));
    try std.testing.expect(state.grounded);
    try std.testing.expectEqual(scene.evidence.default_loadout_fingerprint, state.loadout_fingerprint);
    try std.testing.expectEqual(@as(u8, 0), state.air_jumps_used);
    try std.testing.expectEqual(@as(u16, 0), state.dash_ticks_remaining);
    try std.testing.expect(scene.evidence.reset_cleared_mesh_state);
    try std.testing.expect(scene.evidence.reset_restored_appearance);
    try std.testing.expect(scene.camera.center.approxEqAbs(camera2d.default_center, 0.000001));
}

test "foundation unified ordering stays deterministic and bounded across topology and loadout changes" {
    var scene = try foundation.Scene.init(std.testing.allocator, true);
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(std.testing.allocator, 512, 448, 64, 1);
    defer queue.deinit();
    queue.markStabilized();
    var builder = input.SnapshotBuilder{};

    for (0..96) |frame| {
        var raw = input.RawInputState{};
        raw.keyboard.d = frame < 48;
        raw.keyboard.c = frame == 12;
        raw.keyboard.l = frame == 24 or frame == 48 or frame == 72;
        const snapshot = try builder.update(raw);
        try scene.updateFrame(1.0 / 60.0, snapshot);
        queue.beginFrame();
        _ = try scene.submit(&queue);
        const prepared = queue.prepare();
        try std.testing.expect(queue.frame_metrics.submitted_sprites > 0);
        try std.testing.expect(queue.frame_metrics.submitted_meshes > 0);
        try std.testing.expect(queue.frame_metrics.submitted_meshes <= 16);
        for (prepared.ranges) |range| try std.testing.expect(range.count > 0);
        var index: usize = 1;
        while (index < prepared.ranges.len) : (index += 1) {
            const previous = prepared.ranges[index - 1];
            const current = prepared.ranges[index];
            try std.testing.expect(previous.first + previous.count <= current.first or previous.kind != current.kind);
        }
    }
    try std.testing.expect(scene.evidence.maximum_resolved_visuals <= @import("equipment").maximum_resolved_visuals);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}
