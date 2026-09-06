const std = @import("std");
const p = @import("projectiles");
const math = @import("math");
const t = @import("support.zig");
fn system() !p.System {
    return p.System.init(t.allocator, .{ .namespace = t.namespace });
}
fn spawn(s: *p.System, definition: p.Definition) !p.Id {
    return s.spawn(.{ .definition = definition, .position = .zero, .velocity = .{ .x = 240, .y = 0 } });
}
const Fake = struct {
    hits: []const p.collision.Hit,
    fn query(self: *const Fake) p.collision.Query {
        return .{ .context = self, .collect = collect };
    }
    fn collect(context: ?*const anyopaque, _: p.collision.Sweep, output: *p.collision.Hits) p.collision.Error!void {
        const self: *const Fake = @ptrCast(@alignCast(context.?));
        for (self.hits) |candidate| try output.append(candidate);
    }
};
fn hit(id: u16, fraction: f32) p.collision.Hit {
    return .{ .collider_id = id, .fraction = fraction, .position = .{ .x = fraction, .y = 0 }, .normal = .{ .x = -1, .y = 0 } };
}
test "projectiles deterministic identities, capacity rejection and no ID consumption" {
    var a = try p.System.init(t.allocator, .{ .namespace = t.namespace, .capacity = 1 });
    defer a.deinit();
    var b = try system();
    defer b.deinit();
    const first = try spawn(&a, .{});
    try std.testing.expect(first.eql(try spawn(&b, .{})));
    try std.testing.expectError(error.CapacityExceeded, spawn(&a, .{}));
    try a.remove(first);
    const second = try spawn(&a, .{});
    try std.testing.expect(!second.eql(first));
    try std.testing.expect(second.eql(try spawn(&b, .{})));
    try std.testing.expect(a.snapshot(first) == null);
}
test "projectiles fixed-step semi-implicit motion and acceleration" {
    var s = try system();
    defer s.deinit();
    const id = try spawn(&s, .{ .acceleration = .{ .x = 0, .y = -240 } });
    try s.step(null);
    const value = s.snapshot(id).?;
    try std.testing.expectApproxEqAbs(@as(f32, 1), value.position.x, t.tolerance);
    try std.testing.expectApproxEqAbs(-p.dt, value.position.y, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, -1), value.velocity.y, t.tolerance);
    try std.testing.expectEqual(@as(u64, 1), s.tick());
}
test "projectiles disabled state freezes motion and lifetime then expires exactly" {
    var s = try system();
    defer s.deinit();
    const id = try spawn(&s, .{ .lifetime_ticks = 2 });
    try s.setEnabled(id, false);
    try s.step(null);
    try std.testing.expectEqual(@as(u32, 0), s.snapshot(id).?.age_ticks);
    try s.setEnabled(id, true);
    try s.step(null);
    try std.testing.expect(s.snapshot(id) != null);
    try s.step(null);
    try std.testing.expect(s.snapshot(id) == null);
    try std.testing.expectEqual(p.EventKind.expired, s.events()[s.events().len - 1].kind);
}
test "projectiles explicit removal emits one value and rejects stale identity" {
    var s = try system();
    defer s.deinit();
    const id = try spawn(&s, .{});
    s.clearEvents();
    try s.remove(id);
    try std.testing.expectEqual(@as(usize, 1), s.events().len);
    try std.testing.expectEqual(p.EventKind.removed, s.events()[0].kind);
    try std.testing.expectError(error.UnknownProjectile, s.remove(id));
}
test "projectiles masks filter both directions before earliest-hit selection" {
    var s = try system();
    defer s.deinit();
    var a = hit(1, 0.1);
    a.layer = 2;
    var b = hit(2, 0.2);
    b.mask = 2;
    const candidates = [_]p.collision.Hit{ a, b, hit(3, 0.7), hit(4, 0.4) };
    const fake = Fake{ .hits = &candidates };
    _ = try spawn(&s, .{ .mask = 1 });
    s.clearEvents();
    try s.step(fake.query());
    try std.testing.expectEqual(@as(usize, 0), s.count());
    const event = s.events()[1];
    try std.testing.expectEqual(p.EventKind.collided, event.kind);
    try std.testing.expectEqual(@as(u16, 4), event.hit.?.collider_id);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), event.step_fraction, t.tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 240), event.incoming_velocity.x, t.tolerance);
}
test "projectiles transitive near-equal hit ties ignore enumeration order" {
    const candidates = [_]p.collision.Hit{ hit(7, 0.25), hit(2, 0.2500003), hit(1, 0.250002) };
    const reversed = [_]p.collision.Hit{ candidates[2], candidates[1], candidates[0] };
    var a = try system();
    defer a.deinit();
    var b = try system();
    defer b.deinit();
    _ = try spawn(&a, .{});
    _ = try spawn(&b, .{});
    const qa = Fake{ .hits = &candidates };
    const qb = Fake{ .hits = &reversed };
    try a.step(qa.query());
    try b.step(qb.query());
    try std.testing.expectEqual(@as(u16, 2), a.events()[2].hit.?.collider_id);
    try std.testing.expectEqualDeep(a.events(), b.events());
}
test "projectiles continue hit reports once per collider and spends remaining travel" {
    var s = try system();
    defer s.deinit();
    const id = try spawn(&s, .{ .response = .continue_travel });
    s.clearEvents();
    const fake = Fake{ .hits = &.{hit(1, 0.5)} };
    try s.step(fake.query());
    try std.testing.expectApproxEqAbs(@as(f32, 1), s.snapshot(id).?.position.x, t.tolerance);
    var collisions: usize = 0;
    for (s.events()) |event| if (event.kind == .collided) {
        collisions += 1;
    };
    try std.testing.expectEqual(@as(usize, 1), collisions);
}
test "projectiles bounded bounce prevents same-tick collision loops" {
    var s = try system();
    defer s.deinit();
    const id = try spawn(&s, .{ .response = .bounce, .restitution = 0.5, .collision_iterations = 2 });
    s.clearEvents();
    const fake = Fake{ .hits = &.{hit(1, 0.5)} };
    try s.step(fake.query());
    try std.testing.expectApproxEqAbs(@as(f32, 60), s.snapshot(id).?.velocity.x, t.tolerance);
    try std.testing.expectEqual(p.EventKind.collision_limit, s.events()[s.events().len - 1].kind);
    try std.testing.expectEqual(@as(usize, 7), s.events().len);
}
test "projectiles deflection relaunch changes owner, position and lifetime explicitly" {
    var s = try system();
    defer s.deinit();
    const id = try spawn(&s, .{});
    try s.step(null);
    try s.deflect(id, .{ .velocity = .{ .x = -10, .y = 3 }, .source = .{ .value = t.id("owner") }, .position = .{ .x = 5, .y = 7 }, .restart_lifetime = true });
    const value = s.snapshot(id).?;
    try std.testing.expect(value.source.?.eql(t.id("owner")));
    try std.testing.expectEqual(@as(u32, 0), value.age_ticks);
    try std.testing.expectEqualDeep(value.position, value.previous_position);
    try s.deflect(id, .{ .velocity = .zero, .source = .{ .value = null } });
    try std.testing.expect(s.snapshot(id).?.source == null);
}
test "projectiles event overflow rolls back commands and entire tick" {
    var s = try p.System.init(t.allocator, .{ .namespace = t.namespace, .event_capacity = 1 });
    defer s.deinit();
    const id = try spawn(&s, .{});
    const before = s.snapshot(id).?;
    try std.testing.expectError(error.EventCapacity, s.step(null));
    try std.testing.expectEqualDeep(before, s.snapshot(id).?);
    try std.testing.expectEqual(@as(u64, 0), s.tick());
    try std.testing.expectError(error.EventCapacity, s.remove(id));
    try std.testing.expectError(error.EventCapacity, s.deflect(id, .{ .velocity = .zero }));
    s.clearEvents();
    try s.step(null);
    try std.testing.expectEqual(@as(u64, 1), s.events()[0].sequence);
}
test "projectiles invalid collision result rolls back earlier projectile updates" {
    var s = try system();
    defer s.deinit();
    const id = try spawn(&s, .{});
    var bad = hit(1, 0.5);
    bad.normal = .zero;
    const fake = Fake{ .hits = &.{bad} };
    try std.testing.expectError(error.InvalidHit, s.step(fake.query()));
    try std.testing.expectEqual(@as(u64, 0), s.tick());
    try std.testing.expectEqual(@as(f32, 0), s.snapshot(id).?.position.x);
    try std.testing.expectEqual(@as(usize, 1), s.events().len);
}
test "projectiles ordered repeated runs and copied snapshots cannot mutate authority" {
    var a = try system();
    defer a.deinit();
    var b = try system();
    defer b.deinit();
    _ = try spawn(&a, .{});
    _ = try spawn(&a, .{});
    _ = try spawn(&b, .{});
    _ = try spawn(&b, .{});
    for (0..100) |_| {
        a.clearEvents();
        b.clearEvents();
        try a.step(null);
        try b.step(null);
        try std.testing.expectEqualDeep(a.events(), b.events());
    }
    var copies: [2]p.Snapshot = undefined;
    _ = try a.copySnapshots(&copies);
    const id = copies[0].id;
    copies[0].position.x = -999;
    try std.testing.expect(a.snapshot(id).?.position.x > 0);
    try std.testing.expectError(error.SnapshotCapacity, a.copySnapshots(copies[0..1]));
    a.reset();
    b.reset();
    try std.testing.expect((try spawn(&a, .{})).eql(try spawn(&b, .{})));
}
fn allocationScenario(allocator: std.mem.Allocator) !void {
    var s = try p.System.init(allocator, .{ .namespace = t.namespace });
    defer s.deinit();
    _ = try spawn(&s, .{});
    try s.step(null);
}
test "projectiles allocation failures clean every partial initialization" {
    try std.testing.checkAllAllocationFailures(t.allocator, allocationScenario, .{});
}

test "projectiles fixed F UUID vector and definition ownership" {
    var s = try system();
    defer s.deinit();
    var definition = p.Definition{ .tag = 17 };
    const id = try spawn(&s, definition);
    definition.tag = 42;
    try std.testing.expectEqualStrings("7e622a86-4f84-5657-9ffb-81808e8ce8d4", &id.formatCanonical());
    try std.testing.expectEqual(@as(u32, 17), s.snapshot(id).?.definition.tag);
    try std.testing.expectEqual(@as(u32, 42), definition.tag);
    try std.testing.expectError(error.InvalidDefinition, spawn(&s, .{ .lifetime_ticks = 0 }));
    try std.testing.expectError(error.InvalidDefinition, spawn(&s, .{ .restitution = 2 }));
    try std.testing.expectError(error.InvalidSpawn, s.spawn(.{ .definition = .{}, .position = .{ .x = std.math.nan(f32), .y = 0 }, .velocity = .zero }));
}
fn failSecond(_: ?*const anyopaque, sweep: p.collision.Sweep, _: *p.collision.Hits) p.collision.Error!void {
    if (sweep.from.y > 0) return error.QueryFailed;
}
fn tooMany(_: ?*const anyopaque, _: p.collision.Sweep, hits: *p.collision.Hits) p.collision.Error!void {
    for (0..p.collision.maximum_hits + 1) |index| try hits.append(hit(@intCast(index + 1), 0.5));
}
fn zeroLoop(_: ?*const anyopaque, sweep: p.collision.Sweep, hits: *p.collision.Hits) p.collision.Error!void {
    var contact = hit(1, 0);
    contact.normal.x = if (sweep.to.x >= sweep.from.x) -1 else 1;
    try hits.append(contact);
}
test "projectiles query failure on later item and hit overflow publish nothing" {
    var s = try system();
    defer s.deinit();
    const first = try spawn(&s, .{});
    _ = try s.spawn(.{ .definition = .{}, .position = .{ .x = 0, .y = 1 }, .velocity = .one });
    try std.testing.expectError(error.QueryFailed, s.step(.{ .context = null, .collect = failSecond }));
    try std.testing.expectEqual(@as(f32, 0), s.snapshot(first).?.position.x);
    try std.testing.expectEqual(@as(usize, 2), s.events().len);
    try std.testing.expectEqual(@as(u64, 0), s.tick());
    try std.testing.expectError(error.HitCapacity, s.step(.{ .context = null, .collect = tooMany }));
    try std.testing.expectEqual(@as(u64, 0), s.tick());
}
test "projectiles zero-time opposing contacts terminate at configured bound" {
    var s = try system();
    defer s.deinit();
    const id = try spawn(&s, .{ .response = .bounce, .collision_iterations = 3 });
    s.clearEvents();
    try s.step(.{ .context = null, .collect = zeroLoop });
    try std.testing.expectEqual(@as(usize, 7), s.events().len);
    try std.testing.expectEqual(p.EventKind.collision_limit, s.events()[6].kind);
    try std.testing.expectEqual(@as(f32, 0), s.events()[6].step_fraction);
    try std.testing.expectEqual(@as(f32, 0), s.snapshot(id).?.position.x);
}
test "projectiles exact equal-hit tie uses collider ID and preserves metadata" {
    var s = try system();
    defer s.deinit();
    _ = try spawn(&s, .{});
    var selected = hit(1, 0.5);
    selected.material = 91;
    selected.entity_id = t.id("target");
    const fake = Fake{ .hits = &.{ hit(2, 0.5), selected } };
    try s.step(fake.query());
    const contact = s.events()[2].hit.?;
    try std.testing.expectEqual(@as(u16, 1), contact.collider_id);
    try std.testing.expectEqual(@as(u32, 91), contact.material);
    try std.testing.expect(contact.entity_id.?.eql(t.id("target")));
}
