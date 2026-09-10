//! Semantic route proof: no navigation, transform writes or synthetic collection.
const std = @import("std");
const h = @import("engine_lab");
const route = @import("traversal_verification.zig");
const c = h.collectibles_module;
pub const Result = struct { events: [12]c.Collected, digests: [2]h.Digest, ticks: [2]u64 };

pub fn returnInput(hub: *const h.Hub, target_x: f32) h.Intent {
    var intent = h.neutral_intent;
    intent.move_axis = std.math.clamp((target_x - hub.actor.worldPosition().x) * 3, -1, 1);
    return intent;
}
pub fn runCourse(hub: *h.Hub, mixed: bool) !void {
    var frame: usize = 0;
    for (route.easy) |segment| {
        var elapsed: u64 = 0;
        while (elapsed < segment.ticks) : (frame += 1) {
            const count = route.steps(segment, elapsed, mixed, frame);
            try hub.advanceFrame(@as(f64, @floatFromInt(count)) / 240.0, route.input(hub, segment, elapsed));
            elapsed += count;
        }
        try route.validateBoundary(hub, segment);
    }
    // Finish the lower-floor return through feedback-driven physical movement.
    for (0..280) |_| try hub.advanceFrame(1.0 / 240.0, returnInput(hub, c.content.spawns[5].position.x));
    const challenge = &hub.challenge.?;
    if (challenge.phase != .complete or challenge.progress != 6) {
        std.log.err("collection course incomplete: phase={s} progress={d} root={any}", .{ @tagName(challenge.phase), challenge.progress, hub.actor.worldPosition() });
        return error.CollectionCourseIncomplete;
    }
    if (hub.navigation_count != 0) return error.CollectionRouteNavigation;
}
pub fn run(hub: *h.Hub, mixed: bool) !Result {
    var result: Result = undefined;
    for (0..2) |run_index| {
        if (run_index != 0) {
            // Walk back on the lower floor. The accepted geometry stays solid.
            for (0..840) |_| try hub.advanceFrame(1.0 / 240.0, returnInput(hub, -5.7));
            // The low first ledge blocks a standing actor returning along the floor.
            // Jump onto and walk off it using the same production movement inputs.
            for (0..260) |tick| {
                var intent = h.neutral_intent;
                intent.move_axis = 1;
                intent.jump_pressed = tick == 0;
                intent.jump_held = true;
                try hub.advanceFrame(1.0 / 240.0, intent);
            }
            for (0..300) |_| try hub.advanceFrame(1.0 / 240.0, returnInput(hub, -5.7));
        }
        hub.challenge.?.requestStart();
        // Birth executes as a normal neutral tick, with no movement discontinuity.
        try hub.advanceFrame(1.0 / 240.0, h.neutral_intent);
        std.debug.print("COLLECTION_ROUTE_BEGIN run={d} root={any}\n", .{ run_index + 1, hub.actor.worldPosition() });
        try runCourse(hub, mixed);
        const challenge = &hub.challenge.?;
        if (challenge.run != run_index + 1) return error.CollectionRunIdentity;
        for (challenge.observations, 0..) |event, i| {
            if (event.ordinal != i + 1 or event.spawn_id != c.content.spawns[i].id or event.run != challenge.run) return error.CollectionEventOrder;
            if (i > 0 and event.tick < challenge.observations[i - 1].tick + 26) return error.CollectionReactionOverlap;
            result.events[run_index * 6 + i] = event;
        }
        result.digests[run_index] = try challenge.fingerprint();
        result.ticks[run_index] = hub.tick;
    }
    return result;
}
pub fn verify(allocator: std.mem.Allocator, seed: h.Seed) !Result {
    var hub = try h.Hub.initExpanded(allocator, seed);
    defer hub.deinit() catch |err| h.cleanupFailure(err);
    const result = try run(&hub, false);
    try hub.reset();
    const grouped = try run(&hub, true);
    if (!std.meta.eql(result, grouped)) return error.CollectionGroupingMismatch;
    return result;
}

/// A deliberate fixture error proves fatal late-tick propagation and reset repair.
pub fn verifyOverflow(allocator: std.mem.Allocator, seed: h.Seed) !void {
    var hub = try h.Hub.initExpanded(allocator, seed);
    defer hub.deinit() catch |err| h.cleanupFailure(err);
    hub.challenge.?.run = std.math.maxInt(u64);
    hub.challenge.?.requestStart();
    if (hub.advanceFrame(8.0 / 240.0, h.neutral_intent)) |_| return error.ExpectedCollectionOverflow else |err| if (err != error.Overflow) return err;
    if (hub.tick != 1 or hub.challenge.?.effects.tick() != 1 or hub.impact.effects.tick() != 1 or hub.world_time.snapshot().simulation_ticks != 0) return error.CollectionPartialTickMismatch;
    const before = try hub.challenge.?.fingerprint();
    for ([_]f64{ 0, 8.0 / 240.0 }) |delta| {
        if (hub.advanceFrame(delta, h.neutral_intent)) |_| return error.ExpectedCollectionContinuationRejection else |err| if (err != error.WorldTimeTickMismatch) return err;
        if (!(try hub.challenge.?.fingerprint()).eql(before)) return error.CollectionContinuedAfterFailure;
    }
    try hub.reset();
    try hub.advanceFrame(1.0 / 240.0, h.neutral_intent);
    if (hub.tick != 1 or hub.challenge.?.phase != .idle or hub.challenge.?.effects.tick() != 1) return error.CollectionResetRecovery;
    std.log.info("COLLECTION_OVERFLOW_PROPAGATION_OK partial_ticks=1 requested_ticks=8 continuation_rejected=true reset_repaired=true", .{});
    return error.Overflow;
}
