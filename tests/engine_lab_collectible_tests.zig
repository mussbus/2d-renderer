const std = @import("std");
const h = @import("engine_lab");
const c = h.collectibles_module;
const proof = @import("engine_lab_verification").collectibles;

test "collectible full six pickup physical course and second run preserve grouped observations" {
    const result = try proof.verify(std.testing.allocator, try h.Seed.parseLowerHex(h.default_seed));
    for (result.events) |event| std.debug.print("COLLECTION_EVENT run={d} spawn={d} ordinal={d} tick={d} position={d:.4},{d:.4} segment={s}\n", .{ event.run, @intFromEnum(event.spawn_id), event.ordinal, event.tick, event.position.x, event.position.y, @tagName(event.segment) });
    for (result.digests, result.ticks) |digest, tick| std.debug.print("COLLECTION_CHECKPOINT tick={d} sha256={s}\n", .{ tick, digest.formatLowerHex() });
}

const actions = @import("engine_lab_actions");
const physical = @import("physical_input");
const math = @import("math");
const collider = @import("collider");
const v = @import("engine_lab_view");
const q = @import("render_queue");
const debug = @import("debug_draw");
fn init(allocator: std.mem.Allocator) !h.Hub {
    return h.Hub.initExpanded(allocator, try h.Seed.parseLowerHex(h.default_seed));
}
fn close(hub: *h.Hub) void {
    hub.deinit() catch |err| h.cleanupFailure(err);
}
fn ticks(hub: *h.Hub, count: usize) !void {
    for (0..count) |_| try hub.advanceFrame(1.0 / 240.0, h.neutral_intent);
}
fn sample(hub: *h.Hub, mapper: *actions.Mapper, raw: physical.RawInputState, seconds: f64) !void {
    try actions.advance(hub, mapper, raw, mapper.sample(raw), seconds);
}
// Staging below isolates lifecycle/query tests. Only the physical course above is reachability evidence.
fn atTarget(hub: *h.Hub, index: usize) !void {
    try hub.actor.stageControlledTransform(c.content.spawns[index].position, .right);
}
fn start(hub: *h.Hub) !void {
    hub.challenge.?.requestStart();
    try ticks(hub, 1);
}
fn validate(items: []const c.content.Spawn) !void {
    try c.content.validate(items, &h.layout.expanded_colliders, .{ .x = 0.3, .y = 1.05 });
}

test "collectible authored IDs sequence finite bounds support landing and clearance reject invalid content" {
    try validate(&c.content.spawns);
    try std.testing.expectError(error.CollectibleSequenceLength, validate(c.content.spawns[0..5]));
    var items = c.content.spawns;
    items[1].id = items[0].id;
    try std.testing.expectError(error.CollectibleDuplicateId, validate(&items));
    items = c.content.spawns;
    items[0].id = @enumFromInt(999);
    try std.testing.expectError(error.CollectibleSequence, validate(&items));
    items = c.content.spawns;
    items[0].position.x = std.math.nan(f32);
    try std.testing.expectError(error.CollectibleBounds, validate(&items));
    items = c.content.spawns;
    items[0].half_extents.y = 0;
    try std.testing.expectError(error.CollectibleBounds, validate(&items));
    items = c.content.spawns;
    items[0].position.x = 9;
    try std.testing.expectError(error.CollectibleOutsideRoom, validate(&items));
    items = c.content.spawns;
    items[1].position = items[0].position;
    try std.testing.expectError(error.CollectibleCoincident, validate(&items));
    items = c.content.spawns;
    items[1].support = 11;
    try std.testing.expectError(error.CollectibleSupportSequence, validate(&items));
    items = c.content.spawns;
    items[0].position = .{ .x = 0, .y = 0.3 };
    try std.testing.expectError(error.CollectibleInsideSolid, validate(&items));
    items = c.content.spawns;
    items[1].position.x = -7.4;
    try std.testing.expectError(error.CollectibleLandingMargin, validate(&items));
    items = c.content.spawns;
    items[1].position.y = 3;
    try std.testing.expectError(error.CollectibleStandingHeight, validate(&items));
    var solids = h.layout.expanded_colliders;
    solids[5].id = 99;
    try std.testing.expectError(error.CollectibleMissingSupport, c.content.validate(&c.content.spawns, &solids, .{ .x = 0.3, .y = 1.05 }));
    solids = h.layout.expanded_colliders;
    solids[5].ground_query_eligible = false;
    try std.testing.expectError(error.CollectibleInvalidSupport, c.content.validate(&c.content.spawns, &solids, .{ .x = 0.3, .y = 1.05 }));
    solids = h.layout.expanded_colliders;
    solids[4].bounds.minimum.y = 3.2;
    try std.testing.expectError(error.CollectibleStandingClearance, c.content.validate(&c.content.spawns, &solids, .{ .x = 0.3, .y = 1.05 }));
}

test "collectible resolved axis adapter keeps overlap entering grazing separation and avoids diagonal chord" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var controller = hub.actor.controllerSnapshot().?;
    controller.configuration.collider_half_extents = .{ .x = 0.25, .y = 0.25 };
    const target = c.content.Spawn{ .id = .approach, .position = .zero, .half_extents = .{ .x = 0.25, .y = 0.25 }, .support = 1 };
    controller.state.previous_position = .zero;
    controller.state.position = .zero;
    try std.testing.expectEqual(@as(f32, 0), (try c.query(controller, target)).?.contact.fraction);
    controller.state.previous_position = .{ .x = -1, .y = 0 };
    controller.state.position = .zero;
    try std.testing.expectEqual(c.Segment.horizontal, (try c.query(controller, target)).?.segment);
    controller.state.previous_position = .{ .x = -0.5, .y = 0 };
    controller.state.position = .{ .x = -1, .y = 0 };
    try std.testing.expectEqual(@as(?c.Contact, null), try c.query(controller, target));
    controller.state.previous_position = .{ .x = -1, .y = 0.5 };
    controller.state.position = .{ .x = 1, .y = 0.5 };
    try std.testing.expectEqual(@as(?c.Contact, null), try c.query(controller, target));
    controller.state.previous_position = .{ .x = -2, .y = -2 };
    controller.state.position = .{ .x = 2, .y = 2 };
    try std.testing.expectEqual(@as(?c.Contact, null), try c.query(controller, target));
    // The diagonal crosses the target, but neither actually resolved segment does.
    try std.testing.expect((try @import("collision_world").static_sweep.query(.{ .from = controller.state.previous_position, .to = controller.state.position, .half_extents = controller.configuration.collider_half_extents }, try target.bounds())) != null);
    controller.state.position = .{ .x = 0, .y = 2 };
    try std.testing.expectEqual(c.Segment.vertical, (try c.query(controller, target)).?.segment);
}

test "collectible birth excludes same tick exact reaction 24 and particles age zero then one" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try atTarget(&hub, 0);
    try start(&hub);
    try std.testing.expect(hub.challenge.?.phase == .active and hub.challenge.?.progress == 0);
    var storage: [72]c.e.ParticleSnapshot = undefined;
    for (0..6) |i| {
        try atTarget(&hub, i);
        try ticks(&hub, 1);
        const event = hub.challenge.?.last.?;
        try std.testing.expectEqual(i + 1, event.ordinal);
        try std.testing.expectEqual(hub.tick, event.tick);
        try std.testing.expectEqual(c.content.spawns[i].id, event.spawn_id);
        try std.testing.expectEqual(c.Phase.reaction, hub.challenge.?.phase);
        for (try hub.challenge.?.effects.copyParticles(&storage)) |p| if (p.effect_id.eql(try c.effectId(1, @intCast(i + 1)))) try std.testing.expectEqual(@as(u32, 0), p.age_ticks);
        hub.challenge.?.requestStart(); // consumed/ignored during reaction, never queued.
        try ticks(&hub, 1);
        for (try hub.challenge.?.effects.copyParticles(&storage)) |p| if (p.effect_id.eql(try c.effectId(1, @intCast(i + 1)))) try std.testing.expectEqual(@as(u32, 1), p.age_ticks);
        try ticks(&hub, 22);
        try std.testing.expectEqual(c.Phase.reaction, hub.challenge.?.phase);
        try std.testing.expectEqual(@as(u8, 1), hub.challenge.?.reaction_remaining);
        try ticks(&hub, 1);
        try std.testing.expectEqual(if (i == 5) c.Phase.complete else c.Phase.active, hub.challenge.?.phase);
        try std.testing.expectEqual(i + 1, hub.challenge.?.progress);
        try std.testing.expect(hub.challenge.?.last == null and !hub.challenge.?.pending_start);
    }
    const previous_tick = hub.tick;
    const position = hub.actor.worldPosition();
    try hub.cycleZoom();
    hub.challenge.?.requestStart();
    try ticks(&hub, 1);
    try std.testing.expectEqual(@as(u64, 2), hub.challenge.?.run);
    try std.testing.expectEqual(@as(usize, 0), hub.challenge.?.effects.particleCount());
    try std.testing.expectEqual(previous_tick + 1, hub.challenge.?.effects.tick());
    try std.testing.expectEqualDeep(position, hub.actor.worldPosition());
    try std.testing.expect(hub.zoom == .out_2x and hub.world_time.snapshot().simulation_ticks == hub.tick);
    try std.testing.expect(!(try c.effectId(1, 1)).eql(try c.effectId(2, 1)));
}

test "collectible short taps held edges keyboard north focus pause zero step and reset precedence" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var mapper = actions.Mapper{};
    hub.clock.setPaused(true);
    mapper.capturePress(.{ .c = true });
    try sample(&hub, &mapper, .{}, 1);
    try std.testing.expect(hub.challenge.?.pending_start and hub.challenge.?.phase == .idle and hub.tick == 0);
    try sample(&hub, &mapper, .{ .keyboard = .{ .t = true } }, 0);
    try std.testing.expect(hub.tick == 1 and hub.challenge.?.phase == .active);
    try sample(&hub, &mapper, .{ .keyboard = .{ .t = true, .c = true } }, 1);
    try std.testing.expect(hub.tick == 1 and !hub.challenge.?.pending_start);
    try actions.advance(&hub, &mapper, .{ .gamepad_button_north = true, .keyboard = .{ .r = true, .c = true } }, .{ .reset = true, .challenge_start = true, .step = true }, 1);
    try std.testing.expect(hub.tick == 0 and hub.challenge.?.phase == .idle);
    try sample(&hub, &mapper, .{ .gamepad_button_north = true, .keyboard = .{ .c = true } }, 0);
    try std.testing.expect(!hub.challenge.?.pending_start);
    try sample(&hub, &mapper, .{}, 0);
    mapper.captureGamepadChallengePress();
    try sample(&hub, &mapper, .{}, 0);
    try std.testing.expect(hub.challenge.?.pending_start and hub.challenge.?.phase == .idle);
    try sample(&hub, &mapper, .{ .focus_lost = true, .gamepad_button_north = true }, 0);
    try std.testing.expect(!hub.challenge.?.pending_start);
    try sample(&hub, &mapper, .{ .gamepad_button_north = true }, 0);
    try std.testing.expect(!hub.challenge.?.pending_start);
    try sample(&hub, &mapper, .{}, 0);
    try sample(&hub, &mapper, .{ .gamepad_button_north = true }, 0);
    try std.testing.expect(hub.challenge.?.pending_start);
    try sample(&hub, &mapper, .{ .keyboard = .{ .f2 = true }, .gamepad_button_north = true }, 0);
    try std.testing.expect(!hub.challenge.?.pending_start);
    try sample(&hub, &mapper, .{}, 0);
    try sample(&hub, &mapper, .{ .keyboard = .{ .c = true } }, 4.0 / 240.0);
    try std.testing.expectEqual(@as(u64, 1), hub.challenge.?.run);
    try std.testing.expectEqual(@as(u64, 4), hub.tick);
    try sample(&hub, &mapper, .{ .keyboard = .{ .c = true } }, 4.0 / 240.0);
    try std.testing.expect(!hub.challenge.?.pending_start and hub.challenge.?.run == 1);
    var legacy = try h.Hub.init(std.testing.allocator, try h.Seed.parseLowerHex(h.default_seed));
    defer close(&legacy);
    try actions.advance(&legacy, &mapper, .{}, .{ .challenge_start = true }, 4.0 / 240.0);
    try std.testing.expect(legacy.challenge == null);
}

test "collectible navigation preserves each live phase and does not sweep teleport path" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try start(&hub);
    for (0..6) |i| {
        const active_before = try hub.challenge.?.fingerprint();
        try hub.navigate(.springs);
        try std.testing.expect(active_before.eql(try hub.challenge.?.fingerprint()));
        try ticks(&hub, 1);
        try std.testing.expectEqual(i, hub.challenge.?.progress);
        try atTarget(&hub, i);
        try ticks(&hub, 1);
        const reaction_before = try hub.challenge.?.fingerprint();
        try hub.navigate(.hierarchy);
        try std.testing.expect(reaction_before.eql(try hub.challenge.?.fingerprint()));
        try ticks(&hub, 24);
    }
    const complete_before = try hub.challenge.?.fingerprint();
    try hub.navigate(.springs);
    try std.testing.expect(complete_before.eql(try hub.challenge.?.fingerprint()));
    try std.testing.expectEqual(c.Phase.complete, hub.challenge.?.phase);
    try hub.reset();
    try start(&hub);
    // A discontinuity crossing the first pickup is not a collection segment.
    try hub.actor.stageControlledTransform(.{ .x = -12, .y = 1.05 }, .right);
    try hub.navigate(.hierarchy);
    try ticks(&hub, 1);
    try std.testing.expectEqual(@as(u8, 0), hub.challenge.?.progress);
}

fn simultaneous(hub: *h.Hub) !void {
    try hub.navigate(.springs);
    hub.impact.pending_activation = true;
    try start(hub);
    try ticks(hub, 310);
    try atTarget(hub, 0);
    try ticks(hub, 1);
    try std.testing.expectEqual(@as(u64, 312), hub.tick);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.contacts);
    try std.testing.expectEqual(@as(u8, 1), hub.challenge.?.progress);
}
test "collectible simultaneous impact birth ordering independent ownership and fatal partial tick recovery" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try simultaneous(&hub);
    var impact_particles: [192]h.impact_module.e.ParticleSnapshot = undefined;
    var collection_particles: [72]c.e.ParticleSnapshot = undefined;
    for (try hub.impact.effects.copyParticles(&impact_particles)) |p| try std.testing.expectEqual(@as(u32, 0), p.age_ticks);
    for (try hub.challenge.?.effects.copyParticles(&collection_particles)) |p| {
        try std.testing.expectEqual(@as(u32, 0), p.age_ticks);
        try std.testing.expect(!p.effect_id.eql(impact_particles[0].effect_id));
    }
    try ticks(&hub, 1);
    for (try hub.impact.effects.copyParticles(&impact_particles)) |p| try std.testing.expectEqual(@as(u32, 1), p.age_ticks);
    for (try hub.challenge.?.effects.copyParticles(&collection_particles)) |p| try std.testing.expectEqual(@as(u32, 1), p.age_ticks);
    // The application-level fatal path is exercised by --verify-collection-overflow,
    // retaining its error log and nonzero process exit like the World Time fixture.
    try hub.reset();
    hub.challenge.?.run = std.math.maxInt(u64);
    hub.challenge.?.requestStart();
    try hub.challenge.?.advanceParticles(1);
    try std.testing.expectError(error.Overflow, hub.challenge.?.transition(hub.actor.controllerSnapshot().?, 1));
    try hub.reset();
    try ticks(&hub, 1);
    try std.testing.expectEqual(c.Phase.idle, hub.challenge.?.phase);
}

test "collectible every initialization failure cleans up and failed reset preserves both effects and zoom" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    const count = tracking.alloc_index;
    for (0..count) |failure| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        if (init(failing.allocator())) |value| {
            var unexpected = value;
            close(&unexpected);
            return error.ExpectedInitFailure;
        } else |_| try std.testing.expect(failing.has_induced_failure);
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
    try simultaneous(&hub);
    try hub.navigate(.springs);
    hub.impact.pending_activation = true;
    try ticks(&hub, 1);
    try hub.cycleZoom();
    const challenge_before = try hub.challenge.?.fingerprint();
    const world_before = try hub.traversalFingerprint();
    const camera = hub.camera;
    for (0..count) |failure| {
        const live = tracking.allocated_bytes - tracking.freed_bytes;
        tracking.fail_index = tracking.alloc_index + failure;
        tracking.has_induced_failure = false;
        if (hub.reset()) |_| return error.ExpectedResetFailure else |_| try std.testing.expect(tracking.has_induced_failure);
        try std.testing.expectEqual(live, tracking.allocated_bytes - tracking.freed_bytes);
        try std.testing.expect(challenge_before.eql(try hub.challenge.?.fingerprint()));
        try std.testing.expect(world_before.eql(try hub.traversalFingerprint()));
        try std.testing.expectEqualDeep(camera, hub.camera);
        try std.testing.expectEqual(h.Zoom.out_2x, hub.zoom);
    }
    tracking.fail_index = std.math.maxInt(usize);
    try hub.reset();
    try std.testing.expect(hub.tick == 0 and hub.challenge.?.phase == .idle and hub.zoom == .current);
    try std.testing.expect(hub.impact.projectiles.count() == 0 and hub.impact.effects.particleCount() == 0 and hub.challenge.?.effects.particleCount() == 0);
    std.debug.print("COLLECTION_RESET_FAILURES_OK allocation_prefixes={d} initialization=all both_effects_preserved=true\n", .{count});
}

test "collectible rendering interpolation zoom resize preserve simulation without allocations or resize attempts" {
    var tracking = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(tracking.allocator());
    defer close(&hub);
    var view = try v.View.init(tracking.allocator());
    defer view.deinit();
    var queue = try q.UnifiedRenderQueue.init(tracking.allocator(), v.entry_capacity, v.sprite_capacity, v.mesh_capacity, 2);
    defer queue.deinit();
    queue.markStabilized();
    try simultaneous(&hub);
    const allocations = tracking.alloc_index;
    const resizes = tracking.resize_index;
    tracking.fail_index = allocations;
    for ([_][2]u32{ .{ 640, 480 }, .{ 960, 720 }, .{ 1280, 720 } }) |size| for (std.enums.values(h.Zoom)) |zoom| {
        hub.zoom = zoom;
        try hub.setViewport(size[0], size[1]);
        for ([_]f64{ 0, 0.5, 0.99 }) |alpha| {
            hub.clock.last_frame.interpolation_alpha = alpha;
            const before = try hub.challenge.?.fingerprint();
            try view.render(&hub, &queue);
            _ = queue.prepare();
            try std.testing.expect(before.eql(try hub.challenge.?.fingerprint()));
        }
    };
    try std.testing.expectEqual(allocations, tracking.alloc_index);
    try std.testing.expectEqual(resizes, tracking.resize_index);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
    try std.testing.expectEqual(@as(u64, 0), view.commands.overflow_count);
}

test "collectible caller selected debug capacity retains default and fails at exact caller bound" {
    const defaults = debug.CommandBuffer{};
    try std.testing.expectEqual(@as(usize, 2048), defaults.commands.len);
    var small = debug.CommandBufferWithCapacity(2){};
    try small.addMarker(.zero, .{ 1, 1, 1, 1 });
    try small.addMarker(.zero, .{ 1, 1, 1, 1 });
    try std.testing.expectError(error.DebugCommandCapacityExceeded, small.addMarker(.zero, .{ 1, 1, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 1), small.overflow_count);
    small.beginFrame();
    try small.addMarker(.zero, .{ 1, 1, 1, 1 });
    try std.testing.expectEqual(@as(usize, 1), small.count);
    try std.testing.expect(!(physical.RawInputState{}).gamepad_button_north);
}

fn framed(hub: *const h.Hub, view: *const v.View, range: v.HudRange) !void {
    for (view.commands.commands[range.start..range.end]) |command| {
        const cosine = @cos(command.rotation);
        const sine = @sin(command.rotation);
        for ([_]f32{ 0, 1 }) |x| for ([_]f32{ 0, 1 }) |y| {
            const dx = (x - command.pivot[0]) * command.scale[0];
            const dy = (y - command.pivot[1]) * command.scale[1];
            const clip = try hub.camera.worldToClip(.{ .x = command.world_position[0] + dx * cosine - dy * sine, .y = command.world_position[1] + dy * cosine + dx * sine }, 1);
            try std.testing.expect(@abs(clip.x) < 1 and @abs(clip.y) < 1);
        };
    }
}
test "collectible complete combined saturation all phases directions zoom viewports protects original bound" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var view = try v.View.init(std.testing.allocator);
    defer view.deinit();
    var queue = try q.UnifiedRenderQueue.init(std.testing.allocator, v.entry_capacity, v.sprite_capacity, v.mesh_capacity, 2);
    defer queue.deinit();
    queue.markStabilized();
    try hub.navigate(.springs);
    for (0..8) |_| {
        hub.impact.pending_activation = true;
        try ticks(&hub, 1);
    }
    while (hub.tick < 320) try ticks(&hub, 1);
    for (0..8) |_| {
        hub.impact.pending_activation = true;
        try ticks(&hub, 1);
    }
    try std.testing.expectEqual(@as(usize, 192), hub.impact.effects.particleCount());
    try std.testing.expectEqual(@as(usize, 8), hub.impact.projectiles.count());
    // Presentation-only saturation, not achievable-route or tick-order evidence.
    for (0..6) |i| _ = try hub.challenge.?.effects.spawn(.{ .id = try c.effectId(1, @intCast(i + 1)), .definition = c.content.reaction, .position = c.content.spawns[i].position });
    try std.testing.expectEqual(@as(usize, 72), hub.challenge.?.effects.particleCount());
    hub.diagnostics_enabled = true;
    hub.clock.paused = true;
    hub.tick = 10000000000000000000;
    hub.impact.observations.launches = 888;
    hub.impact.observations.contacts = 888;
    hub.impact.bridge.metrics.dropped_effects = 888;
    hub.clock.lifetime_discarded_time = 888.888;
    const time_max = try @import("engine_lab_world_time_tests.zig").presentationMaximum();
    var time = h.world_time_module.initial_snapshot;
    time.day_index = time_max.day;
    time.time_of_day_us = time_max.minute * 60_000_000;
    hub.world_time = try h.world_time_module.WorldTime.fromSnapshot(time);
    var added: usize = 0;
    var observed: usize = 0;
    var command_max: usize = 0;
    var frames: usize = 0;
    for (std.enums.values(c.Phase)) |phase| for (0..6) |ordinal| for ([_][2]u32{ .{ 640, 480 }, .{ 960, 720 }, .{ 1280, 720 } }) |size| for (std.enums.values(h.Zoom)) |zoom| {
        hub.challenge.?.phase = phase;
        hub.challenge.?.progress = if (phase == .complete) 6 else if (phase == .idle) 0 else @intCast(ordinal);
        hub.zoom = zoom;
        try hub.setViewport(size[0], size[1]);
        const target = c.content.spawns[ordinal].position;
        for ([_]math.Vec2{ .zero, .{ .x = -100, .y = 0 }, .{ .x = 100, .y = 0 }, .{ .x = 0, .y = -100 }, .{ .x = 0, .y = 100 }, .{ .x = -100, .y = -100 }, .{ .x = 100, .y = 100 }, .{ .x = -100, .y = 100 }, .{ .x = 100, .y = -100 } }) |offset| {
            try hub.camera.setCenter(target.add(offset));
            try view.render(&hub, &queue);
            const frame = queue.prepare();
            try std.testing.expectEqual(@as(usize, 3), frame.ranges.len);
            try framed(&hub, &view, view.collectible_range);
            try framed(&hub, &view, view.indicator_range);
            const mark = try v.indicator(&hub);
            if (phase != .active or (offset.x == 0 and offset.y == 0)) try std.testing.expect(mark == null) else try std.testing.expect(mark != null);
            for (view.hud_ranges) |range| try framed(&hub, &view, range);
            added = @max(added, view.collectible_sprite_count);
            observed = @max(observed, frame.sprites.len);
            command_max = @max(command_max, view.commands.count);
            frames += 1;
            try std.testing.expect(frame.sprites.len - view.collectible_sprite_count <= v.accepted_traversal_bound);
        }
    };
    const bound = v.accepted_traversal_bound + added;
    try std.testing.expect(bound + 32 <= v.sprite_capacity and v.sprite_capacity <= 2560 and v.entry_capacity <= 2560 and v.mesh_capacity == 256);
    try std.testing.expect(command_max <= 2304 and view.commands.overflow_count == 0);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
    std.debug.print("COLLECTION_PRESENTATION_BOUND original={d}/{d} added={d} observed={d} conservative={d}/{d} spare={d} commands={d}/2304 frames={d} batches=3 impact_particles=192 collection_particles=72 flights=8\n", .{ v.accepted_traversal_bound, v.accepted_traversal_capacity, added, observed, bound, v.sprite_capacity, v.sprite_capacity - bound, command_max, frames });
}
