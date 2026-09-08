const std = @import("std");
const h = @import("engine_lab");
const impact = h.impact_module;
const p = impact.p;
const e = impact.e;
const actions = @import("engine_lab_actions");
const physics = @import("collision_world");
const view_module = @import("engine_lab_view");
const queue_module = @import("render_queue");
fn init(allocator: std.mem.Allocator) !h.Hub {
    return h.Hub.init(allocator, try h.Seed.parseLowerHex(h.default_seed));
}
fn close(hub: *h.Hub) void {
    hub.deinit() catch |err| h.cleanupFailure(err);
}
fn ticks(hub: *h.Hub, count: usize) !void {
    for (0..count) |_| try hub.advanceFrame(1.0 / 240.0, h.neutral_intent);
}
fn ready(hub: *h.Hub) !void {
    try hub.navigate(.springs);
    hub.impact.pending_activation = true;
}
fn aligned(hub: *const h.Hub) !void {
    try std.testing.expectEqual(hub.tick, hub.impact.projectiles.tick());
    try std.testing.expectEqual(hub.tick, hub.impact.effects.tick());
}

test "integration observation schema repeats after reset under equivalent frame groupings and arbitrary reads" {
    const result = try @import("engine_lab_verification").verifyImpact(std.testing.allocator, try h.Seed.parseLowerHex(h.default_seed));
    try std.testing.expectEqual(@as(u64, 792), result.contact_tick);
    try std.testing.expectEqual(@as(u64, 480), result.launch_tick);
    try std.testing.expect(!result.checkpoints[0].digest.eql(result.checkpoints[2].digest));
}

test "presentation saturation is observable and cannot alter projectile contact or native event history" {
    var nominal = try init(std.testing.allocator);
    defer close(&nominal);
    var saturated = try init(std.testing.allocator);
    defer close(&saturated);
    const id = saturated.installations.roots[0].id;
    _ = try saturated.impact.effects.spawn(.{ .id = id, .position = .zero, .definition = .{ .burst = impact.particle_capacity, .particle_lifetime_ticks = 1000 } });
    try ready(&nominal);
    try ready(&saturated);
    try ticks(&nominal, 312);
    try ticks(&saturated, 312);
    try std.testing.expectEqual(nominal.impact.observations.events_digest, saturated.impact.observations.events_digest);
    try std.testing.expectEqual(nominal.impact.observations.last_contact, saturated.impact.observations.last_contact);
    try std.testing.expectEqual(@as(usize, 0), saturated.impact.projectiles.count());
    try std.testing.expectEqual(@as(u64, 24), saturated.impact.effects.metrics().dropped_particles);
    try std.testing.expectEqual(@as(u64, 0), nominal.impact.effects.metrics().dropped_particles);
    try std.testing.expectEqual(@as(u64, 1), saturated.impact.bridge.metrics.impacts);
}

test "full emitter capacity drops bridge presentation without changing native contact" {
    var nominal = try init(std.testing.allocator);
    defer close(&nominal);
    var saturated = try init(std.testing.allocator);
    defer close(&saturated);
    for (saturated.installations.roots, saturated.installations.anchors) |root, anchors| {
        _ = try saturated.impact.effects.spawn(.{ .id = root.id, .position = .zero, .definition = .{ .duration_ticks = 1000 } });
        for (anchors) |anchor| _ = try saturated.impact.effects.spawn(.{ .id = anchor.id, .position = .zero, .definition = .{ .duration_ticks = 1000 } });
    }
    try ready(&nominal);
    try ready(&saturated);
    try ticks(&nominal, 312);
    try ticks(&saturated, 312);
    try std.testing.expectEqual(nominal.impact.observations.events_digest, saturated.impact.observations.events_digest);
    try std.testing.expectEqual(@as(u64, 2), saturated.impact.bridge.metrics.dropped_effects);
    try std.testing.expectEqual(@as(u64, 2), saturated.impact.effects.metrics().rejected_emitters);
    try std.testing.expectEqual(@as(usize, 0), saturated.impact.projectiles.count());
}

test "activation observes completed actor position before controller movement in that tick" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    const edge = hub.impact.launcher.x - impact.activation_half_extents.x;
    try hub.actor.stageControlledTransform(.{ .x = edge - 0.001, .y = 1.05 }, .right);
    hub.impact.pending_activation = true;
    var moving = h.neutral_intent;
    moving.move_axis = 1;
    try hub.advanceFrame(1.0 / 240.0, moving);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.out_of_range);
    try std.testing.expectEqual(@as(u64, 0), hub.impact.observations.launches);
    try hub.actor.stageControlledTransform(.{ .x = edge + 0.001, .y = 1.05 }, .left);
    hub.impact.pending_activation = true;
    moving.move_axis = -1;
    try hub.advanceFrame(1.0 / 240.0, moving);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.launches);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.last_launch.?.tick);
}

test "bounded maximum impact diagnostics and particle extraction retain exact queue limits" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var view = try view_module.View.init(std.testing.allocator);
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(std.testing.allocator, 2048, 1792, 256, 2);
    defer queue.deinit();
    try ticks(&hub, 256);
    hub.diagnostics_enabled = true;
    hub.impact.observations.launches = std.math.maxInt(u64);
    hub.impact.observations.contacts = std.math.maxInt(u64);
    hub.impact.bridge.metrics.dropped_effects = std.math.maxInt(u64);
    _ = try hub.impact.effects.spawn(.{ .id = hub.installations.roots[0].id, .position = .zero, .definition = .{ .burst = impact.particle_capacity } });
    try view.render(&hub, &queue);
    try std.testing.expectEqual(@as(usize, 3), queue.prepare().ranges.len);
    try std.testing.expect(queue.prepare().sprites.len <= 1792);
}

test "failed reconstruction at every allocation retains in flight and live particle integration state" {
    var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(allocator.allocator());
    defer close(&hub);
    try ready(&hub);
    try ticks(&hub, 8);
    const allocations_per_init = allocator.alloc_index;
    for ([_]usize{ 0, 304 }) |advance| {
        try ticks(&hub, advance);
        const before = try hub.impact.fingerprint();
        const old_world = hub.world.colliders.ptr;
        for (0..allocations_per_init) |failure| {
            allocator.fail_index = allocator.alloc_index + failure;
            allocator.has_induced_failure = false;
            if (hub.reset()) |_| return error.ExpectedAllocationFailure else |_| try std.testing.expect(allocator.has_induced_failure);
            try std.testing.expect((try hub.impact.fingerprint()).eql(before));
            try std.testing.expect(old_world == hub.world.colliders.ptr);
        }
        allocator.fail_index = std.math.maxInt(usize);
    }
}

test "hub adapter uses real world IDs preserves metadata exclusions and farther eligible hits" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try std.testing.expect(hub.impact.source.eql(hub.installations.roots[1].id));
    try std.testing.expectEqual(@as(f32, 8), hub.impact.wall_marker.x);
    var storage: [64]p.collision.Hit = undefined;
    var hits = p.collision.Hits{ .storage = &storage };
    var sweep = p.collision.Sweep{ .from = .{ .x = -1, .y = 0.3 }, .to = .{ .x = 9, .y = 0.3 }, .half_extents = .zero, .layer = 1, .mask = 1, .source = hub.impact.source, .affiliation = @enumFromInt(9), .excluded = &.{} };
    try impact.collect(&hub.world, sweep, &hits);
    try std.testing.expectEqual(@as(usize, 2), hits.count);
    try std.testing.expectEqual(@as(u16, 3), storage[0].collider_id);
    try std.testing.expectEqual(@as(u16, 4), storage[1].collider_id);
    for (storage[0..hits.count]) |hit| {
        try std.testing.expect(hit.entity_id == null);
        try std.testing.expectEqual(@as(u32, 0), hit.material);
    }
    try std.testing.expectEqual(@as(u16, 4), (try p.collision.earliest(sweep, storage[0..hits.count])).?.collider_id);
    sweep.excluded = &.{4};
    try std.testing.expectEqual(@as(u16, 3), (try p.collision.earliest(sweep, storage[0..hits.count])).?.collider_id);
    sweep.excluded = &.{};
    // Explicit test metadata: filtering a nearer candidate must reveal the wall.
    storage[1].layer = 2;
    try std.testing.expectEqual(@as(u16, 3), (try p.collision.earliest(sweep, storage[0..hits.count])).?.collider_id);
    sweep.mask = 0;
    try std.testing.expect((try p.collision.earliest(sweep, storage[0..hits.count])) == null);
    var tiny = p.collision.Hits{ .storage = storage[0..1] };
    try std.testing.expectError(error.HitCapacity, impact.collect(&hub.world, sweep, &tiny));
    try std.testing.expectError(error.QueryFailed, impact.collect(null, sweep, &hits));
}

test "hub adapter enumeration independent ties use native ID and no candidate truncation" {
    const c = @import("collider");
    const bounds = c.Aabb{ .minimum = .{ .x = 1, .y = -1 }, .maximum = .{ .x = 2, .y = 1 } };
    var world = try physics.CollisionWorld.init(std.testing.allocator, &.{ .{ .id = 9, .bounds = bounds }, .{ .id = 2, .bounds = bounds } }, null);
    defer world.deinit();
    const sweep = p.collision.Sweep{ .from = .zero, .to = .{ .x = 3, .y = 0 }, .half_extents = .zero, .layer = 1, .mask = 1, .source = null, .excluded = &.{} };
    var storage: [2]p.collision.Hit = undefined;
    var hits = p.collision.Hits{ .storage = &storage };
    try impact.collect(&world, sweep, &hits);
    try std.testing.expectEqual(@as(u16, 9), storage[0].collider_id);
    try std.testing.expectEqual(@as(u16, 2), (try p.collision.earliest(sweep, storage[0..hits.count])).?.collider_id);
    std.mem.swap(p.collision.Hit, &storage[0], &storage[1]);
    try std.testing.expectEqual(@as(u16, 2), (try p.collision.earliest(sweep, storage[0..hits.count])).?.collider_id);
}

test "activation real contact retirement bridge extraction obey exact ticks events and particle birth" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try ready(&hub);
    try ticks(&hub, 1);
    try aligned(&hub);
    const launch = hub.impact.observations.last_launch.?;
    try std.testing.expectEqual(@as(u64, 0), launch.tick);
    try std.testing.expectEqual(@as(u64, 0), launch.sequence);
    try std.testing.expectEqual(@as(usize, 2), hub.impact.observations.batch_count);
    try std.testing.expectEqual(p.EventKind.spawned, hub.impact.observations.last_batch[0].kind);
    try std.testing.expectEqual(p.EventKind.moved, hub.impact.observations.last_batch[1].kind);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.last_batch[1].tick);
    try ticks(&hub, 310);
    try std.testing.expectEqual(@as(usize, 1), hub.impact.projectiles.count());
    try std.testing.expectEqual(@as(u64, 0), hub.impact.observations.contacts);
    try ticks(&hub, 1);
    try aligned(&hub);
    const contact = hub.impact.observations.last_contact.?;
    try std.testing.expectEqual(@as(u64, 312), hub.tick);
    try std.testing.expectEqual(hub.tick, contact.tick);
    try std.testing.expectEqual(@as(u64, 313), contact.sequence);
    try std.testing.expectEqual(@as(u16, 3), contact.hit.?.collider_id);
    try std.testing.expectEqual(@as(f32, 8), contact.hit.?.position.x);
    try std.testing.expectEqual(@as(f32, -1), contact.hit.?.normal.x);
    try std.testing.expectEqual(@as(f32, 7.9375), contact.projectile.position.x);
    try std.testing.expectEqual(@as(usize, 2), hub.impact.observations.batch_count);
    try std.testing.expectEqual(p.EventKind.moved, hub.impact.observations.last_batch[0].kind);
    try std.testing.expectEqual(p.EventKind.collided, hub.impact.observations.last_batch[1].kind);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.count());
    try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.events().len);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.bridge.metrics.impacts);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.bridge.count);
    var particles: [impact.particle_capacity]e.ParticleSnapshot = undefined;
    const born = try hub.impact.effects.copyParticles(&particles);
    try std.testing.expectEqual(@as(usize, 24), born.len);
    for (born) |value| try std.testing.expectEqual(@as(u32, 0), value.age_ticks);
    const first = born[0];
    var render: [impact.particle_capacity]e.RenderInstance = undefined;
    const rendered = try hub.impact.effects.extract(&render, 1);
    try std.testing.expectEqual(@as(usize, 24), rendered.len);
    try std.testing.expectEqual(impact.burst.start_size, rendered[0].size);
    try ticks(&hub, 1);
    try aligned(&hub);
    const advanced = try hub.impact.effects.copyParticles(&particles);
    try std.testing.expectEqual(@as(u32, 1), advanced[0].age_ticks);
    try std.testing.expectEqual(first.position, advanced[0].previous_position);
    try std.testing.expect(advanced[0].position.x < first.position.x);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.bridge.metrics.impacts);
    try ticks(&hub, 143);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.effects.particleCount());
    try std.testing.expectEqual(@as(usize, 0), hub.impact.effects.emitterCount());
}

test "pause step and multi substep frames consume activation once and never queue busy or distant shots" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    hub.impact.pending_activation = true;
    try ticks(&hub, 1);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.out_of_range);
    try ready(&hub);
    hub.clock.setPaused(true);
    try hub.advanceFrame(0.04, h.neutral_intent);
    try std.testing.expect(hub.impact.pending_activation);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.count());
    hub.clock.requestSingleStep();
    try hub.advanceFrame(0.04, h.neutral_intent);
    try aligned(&hub);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.launches);
    hub.clock.requestSingleStep();
    try hub.advanceFrame(0.04, h.neutral_intent);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.launches);
    hub.clock.setPaused(false);
    hub.impact.pending_activation = true;
    try hub.advanceFrame(4.0 / 240.0, h.neutral_intent);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.busy);
    try ticks(&hub, 480);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.launches);
    hub.impact.pending_activation = true;
    try hub.advanceFrame(4.0 / 240.0, h.neutral_intent);
    try std.testing.expectEqual(@as(u64, 2), hub.impact.observations.launches);
    try aligned(&hub);
}

test "short keyboard taps held keyboard gamepad focus navigation and reset obey application priority" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try hub.navigate(.springs);
    var mapper = actions.Mapper{};
    mapper.capturePress(.{ .e = true });
    const tap = mapper.sample(.{});
    try std.testing.expect(tap.activate and !tap.intent.interact_pressed);
    try actions.advance(&hub, &mapper, .{}, tap, 0);
    try std.testing.expect(hub.impact.pending_activation);
    const lost = @import("physical_input").RawInputState{ .focus_lost = true, .keyboard = .{ .e = true }, .gamepad_button_west = true };
    try actions.advance(&hub, &mapper, lost, mapper.sample(lost), 0);
    try std.testing.expect(!hub.impact.pending_activation);
    const held = @import("physical_input").RawInputState{ .keyboard = .{ .e = true }, .gamepad_button_west = true };
    try std.testing.expect(!mapper.sample(held).activate);
    _ = mapper.sample(.{});
    try std.testing.expect(mapper.sample(held).activate);
    try std.testing.expect(!mapper.sample(held).activate);
    _ = mapper.sample(.{});
    try std.testing.expect(mapper.sample(.{ .gamepad_button_west = true }).activate);
    try std.testing.expect(!mapper.sample(.{ .gamepad_button_west = true }).activate);
    hub.impact.pending_activation = true;
    try actions.advance(&hub, &mapper, held, .{ .destination = .hierarchy, .activate = true }, 0);
    try std.testing.expect(!hub.impact.pending_activation and !mapper.sample(held).activate);
    try actions.advance(&hub, &mapper, held, .{ .reset = true, .destination = .springs, .activate = true, .pause = true, .step = true, .diagnostics = true }, 0.04);
    try std.testing.expectEqual(@as(u64, 0), hub.tick);
    try aligned(&hub);
    try std.testing.expect(!hub.clock.paused and !hub.clock.single_step_pending and !hub.diagnostics_enabled);
    try std.testing.expect(!hub.impact.pending_activation and hub.impact.bridge.last_sequence == null);
    try std.testing.expect(!mapper.sample(held).activate);
}

test "navigation preserves flight world positions particles bridge and offscreen advancement reset clears each" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try ready(&hub);
    try ticks(&hub, 10);
    const before = try hub.impact.fingerprint();
    const world = hub.world.colliders.ptr;
    try hub.navigate(.hierarchy);
    try std.testing.expect((try hub.impact.fingerprint()).eql(before));
    try std.testing.expect(world == hub.world.colliders.ptr);
    try ticks(&hub, 302);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.contacts);
    const contact = try hub.impact.fingerprint();
    try hub.navigate(.springs);
    try std.testing.expect((try hub.impact.fingerprint()).eql(contact));
    try hub.reset();
    try aligned(&hub);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.effects.particleCount());
    try ready(&hub);
    try ticks(&hub, 5);
    try hub.reset();
    try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.count());
    try std.testing.expectEqual(@as(u64, 0), hub.impact.observations.launches);
}

test "integration allocation guard includes flight navigation diagnostics extraction and failed reset preservation" {
    var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(allocator.allocator());
    defer close(&hub);
    var view = try view_module.View.init(allocator.allocator());
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(allocator.allocator(), 2048, 1792, 256, 2);
    defer queue.deinit();
    queue.markStabilized();
    try ready(&hub);
    hub.diagnostics_enabled = true;
    allocator.fail_index = allocator.alloc_index;
    allocator.resize_fail_index = allocator.resize_index;
    for (0..456) |tick| {
        try ticks(&hub, 1);
        const before = try hub.impact.fingerprint();
        try view.render(&hub, &queue);
        try std.testing.expect((try hub.impact.fingerprint()).eql(before));
        try std.testing.expectEqual(@as(usize, 3), queue.prepare().ranges.len);
        try std.testing.expect(queue.prepare().sprites.len <= 1792);
        if (tick == 50) try hub.navigate(.hierarchy);
    }
    try std.testing.expect(!allocator.has_induced_failure);
    const before = try hub.impact.fingerprint();
    if (hub.reset()) |_| return error.ExpectedAllocationFailure else |_| try std.testing.expect(allocator.has_induced_failure);
    try std.testing.expect((try hub.impact.fingerprint()).eql(before));
}
