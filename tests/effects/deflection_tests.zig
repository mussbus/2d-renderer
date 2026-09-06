const std = @import("std");
const p = @import("projectiles");
const t = @import("support.zig");
const affiliation_a: p.Affiliation = @enumFromInt(11);
const affiliation_b: p.Affiliation = @enumFromInt(22);
fn owned(system: *p.System, lifetime: u32) !p.Id {
    return system.spawn(.{ .definition = .{ .layer = 4, .mask = 2, .lifetime_ticks = lifetime }, .position = .zero, .velocity = .{ .x = 240, .y = 0 }, .source = t.id("source-a"), .affiliation = affiliation_a });
}
fn transfer() p.Deflect {
    return .{ .velocity = .{ .x = -240, .y = 0 }, .source = .{ .value = t.id("source-b") }, .affiliation = .{ .value = affiliation_b }, .layer = 8, .mask = 1 };
}
test "deflection publishes coherent owner affiliation filter velocity and copied before-after state" {
    var system = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer system.deinit();
    const id = try owned(&system, 20);
    const before = system.snapshot(id).?;
    system.clearEvents();
    try system.deflect(id, transfer());
    const after = system.snapshot(id).?;
    try std.testing.expect(after.source.?.eql(t.id("source-b")));
    try std.testing.expectEqual(affiliation_b, after.affiliation.?);
    try std.testing.expectEqual(@as(u32, 8), after.layer);
    try std.testing.expectEqual(@as(u32, 1), after.mask);
    try std.testing.expectEqual(@as(f32, -240), after.velocity.x);
    try std.testing.expectEqualDeep(before.definition, after.definition);
    try std.testing.expectEqual(@as(usize, 1), system.events().len);
    const event = system.events()[0];
    try std.testing.expectEqual(p.EventKind.deflected, event.kind);
    try std.testing.expectEqualDeep(before, event.before_deflection.?);
    try std.testing.expectEqualDeep(after, event.projectile);
    try std.testing.expectEqualDeep(before.velocity, event.incoming_velocity);
    try std.testing.expectEqual(@as(u64, 0), event.tick);
    try std.testing.expectEqual(@as(u64, 1), event.sequence);
    var copied: [1]p.Snapshot = undefined;
    _ = try system.copySnapshots(&copied);
    copied[0].mask = 0;
    try std.testing.expectEqual(@as(u32, 1), system.snapshot(id).?.mask);
    try system.deflect(id, .{ .velocity = .zero });
    try std.testing.expectEqualDeep(before, event.before_deflection.?);
    try std.testing.expectEqualDeep(after, event.projectile);
}
test "deflection event capacity and invalid input publish no partial transfer" {
    var system = try p.System.init(t.allocator, .{ .namespace = t.namespace, .event_capacity = 1 });
    defer system.deinit();
    const id = try owned(&system, 20);
    const before = system.snapshot(id).?;
    const initial_event = system.events()[0];
    try std.testing.expectError(error.EventCapacity, system.deflect(id, transfer()));
    try std.testing.expectEqualDeep(before, system.snapshot(id).?);
    try std.testing.expectEqualDeep(initial_event, system.events()[0]);
    var invalid = transfer();
    invalid.velocity.x = std.math.nan(f32);
    try std.testing.expectError(error.InvalidDeflection, system.deflect(id, invalid));
    invalid = transfer();
    invalid.source = .{ .value = .{ .bytes = .{0} ** 16 } };
    try std.testing.expectError(error.InvalidIdentity, system.deflect(id, invalid));
    try std.testing.expectEqualDeep(before, system.snapshot(id).?);
    try std.testing.expectEqualDeep(initial_event, system.events()[0]);
    system.clearEvents();
    try system.deflect(id, transfer());
    try std.testing.expectEqual(@as(u64, 1), system.events()[0].sequence);
}
const FilterQuery = struct {
    system: *const p.System,
    id: p.Id,
    expected: p.Snapshot,
    fn query(self: *const FilterQuery) p.collision.Query {
        return .{ .context = self, .collect = collect };
    }
    fn collect(context: ?*const anyopaque, sweep: p.collision.Sweep, hits: *p.collision.Hits) p.collision.Error!void {
        const self: *const FilterQuery = @ptrCast(@alignCast(context.?));
        const current = self.system.snapshot(self.id).?;
        if (!std.meta.eql(current.source, self.expected.source) or current.affiliation != self.expected.affiliation or
            current.layer != self.expected.layer or current.mask != self.expected.mask or
            !std.meta.eql(sweep.source, current.source) or sweep.affiliation != current.affiliation or sweep.layer != current.layer or sweep.mask != current.mask)
            return error.QueryFailed;
        const reversed = sweep.to.x < sweep.from.x;
        const normal: @TypeOf(sweep.from) = .{ .x = if (reversed) 1 else -1, .y = 0 };
        try hits.append(.{ .collider_id = 1, .entity_id = t.id("source-a"), .position = .{ .x = -0.5, .y = 0 }, .normal = normal, .fraction = 0.5, .layer = 1, .mask = 8 });
        // An opposing zero-time new-owner contact must be rejected by the new
        // mask, not by the separating-contact rule or candidate enumeration.
        try hits.append(.{ .collider_id = 2, .entity_id = t.id("source-b"), .position = .zero, .normal = normal, .fraction = if (reversed) 0 else 0.25, .layer = 2, .mask = 12 });
        try hits.append(.{ .collider_id = 3, .position = .zero, .normal = normal, .fraction = 0.1, .layer = 1, .mask = 4 });
    }
};
test "deflection transfers both filter directions and exposes new state to next query" {
    var before = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer before.deinit();
    var after = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer after.deinit();
    const initial = try owned(&before, 20);
    const redirected = try owned(&after, 20);
    try after.deflect(redirected, transfer());
    const query_before = FilterQuery{ .system = &before, .id = initial, .expected = before.snapshot(initial).? };
    const query_after = FilterQuery{ .system = &after, .id = redirected, .expected = after.snapshot(redirected).? };
    before.clearEvents();
    after.clearEvents();
    try before.step(query_before.query());
    try after.step(query_after.query());
    try std.testing.expect(before.events()[1].hit.?.entity_id.?.eql(t.id("source-b")));
    try std.testing.expect(after.events()[1].hit.?.entity_id.?.eql(t.id("source-a")));
    try std.testing.expectEqual(@as(usize, 2), after.events().len);
    try std.testing.expectEqual(@as(usize, 0), after.count());
    try std.testing.expectEqual(@as(u32, 8), after.events()[1].projectile.layer);
    try std.testing.expectEqual(affiliation_b, after.events()[1].projectile.affiliation.?);
}
fn boundary(system: *p.System) !void {
    const first = try owned(system, 1);
    const second = try owned(system, 2);
    try system.deflect(first, transfer());
    try system.step(null);
    try system.remove(second);
}
test "deflection and lifecycle boundary ordering repeat across reset with identical event logs" {
    var system = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer system.deinit();
    try boundary(&system);
    const kinds = [_]p.EventKind{ .spawned, .spawned, .deflected, .moved, .expired, .moved, .removed };
    try std.testing.expectEqual(kinds.len, system.events().len);
    var events: [kinds.len]p.Event = undefined;
    @memcpy(&events, system.events());
    for (events, kinds, 0..) |event, kind, index| {
        try std.testing.expectEqual(kind, event.kind);
        try std.testing.expectEqual(@as(u64, @intCast(index)), event.sequence);
        try std.testing.expectEqual(@as(u64, if (index < 3) 0 else 1), event.tick);
    }
    try std.testing.expectEqual(affiliation_b, events[4].projectile.affiliation.?);
    system.reset();
    try boundary(&system);
    try std.testing.expectEqualDeep(&events, system.events());
}
fn bounce(_: ?*const anyopaque, _: p.collision.Sweep, hits: *p.collision.Hits) p.collision.Error!void {
    try hits.append(.{ .collider_id = 1, .position = .{ .x = 0.5, .y = 0 }, .normal = .{ .x = -1, .y = 0 }, .fraction = 0.5, .layer = 2 });
}
test "automatic bounce supplies before-after state while retaining ownership affiliation and filters" {
    var system = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer system.deinit();
    _ = try system.spawn(.{ .definition = .{ .response = .bounce, .collision_iterations = 1, .layer = 4, .mask = 2 }, .source = t.id("source-a"), .affiliation = affiliation_a, .position = .zero, .velocity = .{ .x = 240, .y = 0 } });
    system.clearEvents();
    try system.step(.{ .context = null, .collect = bounce });
    const event = system.events()[2];
    try std.testing.expectEqual(p.EventKind.deflected, event.kind);
    const before = event.before_deflection.?;
    try std.testing.expectEqual(@as(f32, 240), before.velocity.x);
    try std.testing.expectEqual(@as(f32, -240), event.projectile.velocity.x);
    try std.testing.expectEqualDeep(before.source, event.projectile.source);
    try std.testing.expectEqual(before.affiliation, event.projectile.affiliation);
    try std.testing.expectEqual(before.layer, event.projectile.layer);
    try std.testing.expectEqual(before.mask, event.projectile.mask);
    try std.testing.expectEqualDeep(before.position, event.projectile.position);
}
test "deflection absent fields preserve state and explicit optionals clear affiliation and owner" {
    var system = try p.System.init(t.allocator, .{ .namespace = t.namespace });
    defer system.deinit();
    const id = try owned(&system, 20);
    try system.deflect(id, transfer());
    try system.deflect(id, .{ .velocity = .zero, .affiliation = .{ .value = null }, .mask = 0 });
    const after = system.snapshot(id).?;
    try std.testing.expect(after.source.?.eql(t.id("source-b")));
    try std.testing.expect(after.affiliation == null);
    try std.testing.expectEqual(@as(u32, 8), after.layer);
    try std.testing.expectEqual(@as(u32, 0), after.mask);
    try system.deflect(id, .{ .velocity = .zero, .source = .{ .value = null } });
    try std.testing.expect(system.snapshot(id).?.source == null);
}
