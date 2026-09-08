const std = @import("std");
const h = @import("engine_lab");
const impact = h.impact_module;
const p = impact.p;
const e = impact.e;
const actions = @import("engine_lab_actions");
const verification = @import("engine_lab_verification");
const view_module = @import("engine_lab_view");
const queue_module = @import("render_queue");
fn init(allocator: std.mem.Allocator) !h.Hub {
    return h.Hub.init(allocator, try h.Seed.parseLowerHex(h.default_seed));
}
fn close(hub: *h.Hub) void {
    hub.deinit() catch |err| h.cleanupFailure(err);
}
fn tick(hub: *h.Hub) !void {
    try hub.advanceFrame(1.0 / 240.0, h.neutral_intent);
    try std.testing.expectEqual(hub.tick, hub.impact.projectiles.tick());
    try std.testing.expectEqual(hub.tick, hub.impact.effects.tick());
}
fn until(hub: *h.Hub, target: u64) !void {
    while (hub.tick < target) try tick(hub);
}
fn shoot(hub: *h.Hub) !p.Snapshot {
    hub.impact.pending_activation = true;
    try tick(hub);
    return hub.impact.observations.last_launch.?.projectile;
}
fn fill(hub: *h.Hub) ![impact.projectile_capacity]p.Snapshot {
    var shots: [impact.projectile_capacity]p.Snapshot = undefined;
    for (&shots) |*shot| shot.* = try shoot(hub);
    return shots;
}

test "eight distinct live shots reject ninth and retirement-tick requests without deferred firing or identities" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var reference = try init(std.testing.allocator);
    defer close(&reference);
    try hub.navigate(.springs);
    try reference.navigate(.springs);
    const first = try fill(&hub);
    const expected = try fill(&reference);
    try std.testing.expectEqualDeep(expected, first);
    for (first, 0..) |shot, index| {
        for (first[0..index]) |prior| try std.testing.expect(!prior.id.eql(shot.id));
    }
    try std.testing.expectEqual(@as(usize, 8), hub.impact.projectiles.count());
    hub.impact.pending_activation = true;
    try tick(&hub);
    try std.testing.expectEqual(@as(u64, 8), hub.impact.next_shot_ordinal);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.busy);
    try std.testing.expect(!hub.impact.pending_activation);
    try until(&hub, 311);
    hub.impact.pending_activation = true;
    try tick(&hub);
    try std.testing.expectEqual(@as(u64, 2), hub.impact.observations.busy);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.contacts);
    try std.testing.expectEqual(@as(usize, 7), hub.impact.projectiles.count());
    try tick(&hub);
    try std.testing.expectEqual(@as(u64, 8), hub.impact.observations.launches);
    try std.testing.expectEqual(@as(usize, 6), hub.impact.projectiles.count());
    const replacement = try shoot(&hub);
    try until(&reference, 313);
    const clean_replacement = try shoot(&reference);
    try std.testing.expectEqualDeep(clean_replacement, replacement);
    try std.testing.expectEqual(@as(u64, 9), hub.impact.next_shot_ordinal);
    try std.testing.expectEqual(@as(u64, 9), hub.impact.observations.launches);
    try std.testing.expectEqual(@as(usize, 6), hub.impact.projectiles.count());
}

test "multiple impact colors reset identically under mixed frame grouping navigation and arbitrary reads" {
    const result = try verification.verifyMultiImpact(std.testing.allocator, try h.Seed.parseLowerHex(h.default_seed));
    try std.testing.expectEqual(@as(usize, 192), result.peak_particles);
    try std.testing.expectEqual(@as(usize, 9), result.peak_emitters);
    var distinct = false;
    for (result.colors[1..]) |color| distinct = distinct or color != result.colors[0];
    try std.testing.expect(distinct);
    try std.testing.expect(!result.checkpoints[0].digest.eql(result.checkpoints[1].digest));
}

test "sixteen shots retain per-impact RGB through retirement reuse and the nominal allocation-free maximum" {
    var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(allocator.allocator());
    defer close(&hub);
    var view = try view_module.View.init(allocator.allocator());
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(allocator.allocator(), 2048, 1792, 256, 2);
    defer queue.deinit();
    queue.markStabilized();
    try hub.navigate(.springs);
    hub.diagnostics_enabled = true;
    allocator.fail_index = allocator.alloc_index;
    allocator.resize_fail_index = allocator.resize_index;
    var shots: [16]p.Snapshot = undefined;
    const Group = struct { effect: e.Id, shot: p.Id, rgb: impact.composition.Rgb, born: u64 };
    var groups: [16]Group = undefined;
    var shot_count: usize = 0;
    var group_count: usize = 0;
    var particles: [impact.particle_capacity]e.ParticleSnapshot = undefined;
    var snapshots: [impact.projectile_capacity]p.Snapshot = undefined;
    var rendered: [impact.particle_capacity]e.RenderInstance = undefined;
    var peak_sprites: usize = 0;
    var peak_batch: usize = 0;
    var replacement_with_particles = false;
    while (hub.tick < 888) {
        const launching = shot_count < shots.len and hub.tick == verification.multi_launch_ticks[shot_count];
        if (launching) hub.impact.pending_activation = true;
        try tick(&hub);
        if (launching) {
            shots[shot_count] = hub.impact.observations.last_launch.?.projectile;
            shot_count += 1;
            if (hub.impact.effects.particleCount() > 0) replacement_with_particles = true;
        }
        peak_batch = @max(peak_batch, hub.impact.observations.batch_count);
        for (try hub.impact.projectiles.copySnapshots(&snapshots)) |live| {
            var found = false;
            for (shots[0..shot_count]) |origin| if (origin.id.eql(live.id)) {
                try std.testing.expectEqual(origin.definition.tag, live.definition.tag);
                found = true;
            };
            try std.testing.expect(found);
        }
        const live_particles = try hub.impact.effects.copyParticles(&particles);
        for (hub.impact.observations.last_batch[0..hub.impact.observations.batch_count]) |event| {
            if (event.kind != .collided) continue;
            try std.testing.expect(hub.impact.projectiles.snapshot(event.projectile.id) == null);
            var origin: ?p.Snapshot = null;
            for (shots[0..shot_count]) |shot| if (shot.id.eql(event.projectile.id)) {
                origin = shot;
            };
            try std.testing.expect(origin != null);
            try std.testing.expectEqual(origin.?.definition.tag, event.projectile.definition.tag);
            const rgb = try impact.colorForTag(event.projectile.definition.tag);
            var born_count: usize = 0;
            var effect: ?e.Id = null;
            // Launches are separated by 16 ticks, so a birth-age-zero group
            // identifies this native contact without reproducing bridge IDs.
            for (live_particles) |value| if (value.age_ticks == 0) {
                born_count += 1;
                effect = value.effect_id;
                try std.testing.expectEqual(rgb, value.definition.start_color);
                try std.testing.expectEqual(rgb, value.definition.end_color);
            };
            try std.testing.expectEqual(@as(usize, 24), born_count);
            groups[group_count] = .{ .effect = effect.?, .shot = origin.?.id, .rgb = rgb, .born = hub.tick };
            group_count += 1;
        }
        for (live_particles) |value| {
            var group: ?Group = null;
            for (groups[0..group_count]) |candidate| if (candidate.effect.eql(value.effect_id)) {
                group = candidate;
            };
            try std.testing.expect(group != null);
            try std.testing.expectEqual(group.?.rgb, value.definition.start_color);
            try std.testing.expectEqual(group.?.rgb, value.definition.end_color);
            try std.testing.expectEqual(hub.tick - group.?.born, value.age_ticks);
            var expected_definition = impact.burst;
            expected_definition.start_color = group.?.rgb;
            expected_definition.end_color = group.?.rgb;
            try std.testing.expectEqualDeep(expected_definition, value.definition);
        }
        const before = try hub.impact.fingerprint();
        for ([_]f32{ 0, 0.5, 1 }) |alpha| {
            for (try hub.impact.effects.extract(&rendered, alpha)) |value| {
                var rgb: ?impact.composition.Rgb = null;
                for (groups[0..group_count]) |group| if (group.effect.eql(value.effect_id)) {
                    rgb = group.rgb;
                };
                try std.testing.expect(rgb != null);
                try std.testing.expectEqual(rgb.?, value.color[0..3].*);
            }
        }
        try view.render(&hub, &queue);
        const frame = queue.prepare();
        peak_sprites = @max(peak_sprites, frame.sprites.len);
        try std.testing.expect(frame.sprites.len <= 1792);
        try std.testing.expectEqual(@as(usize, 3), frame.ranges.len);
        try std.testing.expect(before.eql(try hub.impact.fingerprint()));
    }
    try std.testing.expectEqual(@as(usize, 16), group_count);
    try std.testing.expect(replacement_with_particles);
    try std.testing.expectEqual(@as(usize, 192), hub.impact.effects.metrics().peak_particles);
    try std.testing.expectEqual(@as(usize, 9), hub.impact.effects.metrics().peak_emitters);
    try std.testing.expectEqual(@as(u64, 0), hub.impact.effects.metrics().dropped_particles);
    try std.testing.expectEqual(@as(u64, 0), hub.impact.bridge.metrics.dropped_effects);
    try std.testing.expectEqual(@as(u64, 0), hub.impact.bridge.metrics.dropped_trails);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.effects.emitterCount());
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
    try std.testing.expect(!allocator.has_induced_failure);
    std.debug.print("MULTI_IMPACT_NOMINAL_MAX particles=192 emitters=9 sprites={d}/1792 event_batch={d}/17 batches=3 allocations=0 drops=0\n", .{ peak_sprites, peak_batch });
}

test "paused multi-shot contact single-step navigation and reset preserve immutable colors" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try hub.navigate(.springs);
    const shots = try fill(&hub);
    try until(&hub, 311);
    hub.clock.setPaused(true);
    hub.impact.pending_activation = true;
    const waiting = try hub.impact.fingerprint();
    for (0..8) |_| try hub.advanceFrame(0.04, h.neutral_intent);
    try std.testing.expectEqual(@as(u64, 311), hub.tick);
    try std.testing.expect(waiting.eql(try hub.impact.fingerprint()));
    hub.clock.requestSingleStep();
    try hub.advanceFrame(0.04, h.neutral_intent);
    try std.testing.expectEqual(@as(u64, 312), hub.tick);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.busy);
    var particles: [impact.particle_capacity]e.ParticleSnapshot = undefined;
    for (try hub.impact.effects.copyParticles(&particles)) |value| {
        try std.testing.expectEqual(@as(u32, 0), value.age_ticks);
        try std.testing.expectEqual(try impact.colorForTag(shots[0].definition.tag), value.definition.start_color);
    }
    hub.clock.requestSingleStep();
    try hub.advanceFrame(0.04, h.neutral_intent);
    const both = try hub.impact.effects.copyParticles(&particles);
    try std.testing.expectEqual(@as(usize, 48), both.len);
    for (both[0..24]) |value| try std.testing.expectEqual(@as(u32, 1), value.age_ticks);
    for (both[24..48]) |value| try std.testing.expectEqual(@as(u32, 0), value.age_ticks);
    const before_navigation = try hub.impact.fingerprint();
    hub.impact.pending_activation = true;
    try hub.navigate(.hierarchy);
    try std.testing.expect(before_navigation.eql(try hub.impact.fingerprint()));
    hub.clock.setPaused(false);
    try until(&hub, 319);
    try std.testing.expectEqual(@as(usize, 192), hub.impact.effects.particleCount());
    var mapper = actions.Mapper{};
    try actions.advance(&hub, &mapper, .{ .keyboard = .{ .e = true } }, .{ .reset = true, .activate = true, .destination = .springs, .pause = true, .step = true }, 0.04);
    try std.testing.expectEqual(@as(u64, 0), hub.tick);
    try std.testing.expectEqual(@as(u64, 0), hub.impact.next_shot_ordinal);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.effects.particleCount());
    try std.testing.expect(!hub.clock.paused and !hub.impact.pending_activation);
    try std.testing.expect(hub.impact.bridge.last_sequence == null);
    try hub.navigate(.springs);
    try std.testing.expectEqualDeep(shots, try fill(&hub));
}

test "multi-flight and live-particle reconstruction failures retain both cores and color progression" {
    var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var hub = try init(allocator.allocator());
    defer close(&hub);
    const allocation_count = allocator.alloc_index;
    try hub.navigate(.springs);
    _ = try fill(&hub);
    try until(&hub, 320);
    _ = try fill(&hub);
    try std.testing.expectEqual(@as(usize, 8), hub.impact.projectiles.count());
    try std.testing.expectEqual(@as(usize, 192), hub.impact.effects.particleCount());
    const before = try hub.impact.fingerprint();
    const world = hub.world.colliders.ptr;
    for (0..allocation_count) |offset| {
        allocator.fail_index = allocator.alloc_index + offset;
        allocator.has_induced_failure = false;
        if (hub.reset()) |_| return error.ExpectedAllocationFailure else |_| try std.testing.expect(allocator.has_induced_failure);
        try std.testing.expectEqual(@as(u64, 16), hub.impact.next_shot_ordinal);
        try std.testing.expectEqual(@as(usize, 8), hub.impact.projectiles.count());
        try std.testing.expectEqual(@as(usize, 192), hub.impact.effects.particleCount());
        try std.testing.expect(before.eql(try hub.impact.fingerprint()));
        try std.testing.expect(world == hub.world.colliders.ptr);
    }
    allocator.fail_index = std.math.maxInt(usize);
    try hub.reset();
    try std.testing.expectEqual(@as(u64, 0), hub.impact.next_shot_ordinal);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.count());
    try std.testing.expectEqual(@as(usize, 0), hub.impact.effects.emitterCount());
}

test "shot color state is explicit and only successful spawn commits its ordinal" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try hub.navigate(.springs);
    const initial = try hub.impact.fingerprint();
    hub.impact.next_shot_ordinal = 1;
    try std.testing.expect(!initial.eql(try hub.impact.fingerprint()));
    hub.impact.next_shot_ordinal = 0;
    hub.impact.pending_activation = true;
    const first = (try hub.impact.consumeActivation(hub.impact.launcher)).?;
    try std.testing.expectEqual(@as(u64, 0), hub.impact.next_shot_ordinal);
    hub.impact.observations.launches = std.math.maxInt(u64);
    hub.impact.pending_activation = true;
    const second = (try hub.impact.consumeActivation(hub.impact.launcher)).?;
    try std.testing.expectEqualDeep(first, second);
    var invalid = first;
    invalid.definition.lifetime_ticks = 0;
    try std.testing.expectError(error.InvalidDefinition, hub.impact.step(invalid, &hub.world, 1));
    try std.testing.expectEqual(@as(u64, 0), hub.impact.next_shot_ordinal);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.count());
    // As documented, the effects tick has advanced on failure; discard this hub.
}

test "seventeen events cover one spawn plus eight movement contact or expiry pairs" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    for ([_]bool{ true, false }) |contact| {
        hub.impact.projectiles.reset();
        var def = impact.definition;
        def.lifetime_ticks = 1;
        for (0..impact.projectile_capacity) |index| {
            if (index == impact.projectile_capacity - 1) hub.impact.projectiles.clearEvents();
            _ = try hub.impact.projectiles.spawn(.{ .definition = def, .position = if (contact) .{ .x = 7.93359375, .y = 1.2 } else hub.impact.launcher, .velocity = impact.velocity });
        }
        try hub.impact.projectiles.step(.{ .context = &hub.world, .collect = impact.collect });
        const events = hub.impact.projectiles.events();
        try std.testing.expectEqual(@as(usize, impact.event_capacity), events.len);
        try std.testing.expectEqual(p.EventKind.spawned, events[0].kind);
        for (0..impact.projectile_capacity) |index| {
            try std.testing.expectEqual(p.EventKind.moved, events[1 + index * 2].kind);
            try std.testing.expectEqual(if (contact) p.EventKind.collided else p.EventKind.expired, events[2 + index * 2].kind);
        }
        try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.count());
    }
}

test "maximum diagnostics and eight replacement flights plus 192 particles fit unchanged presentation" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var view = try view_module.View.init(std.testing.allocator);
    defer view.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(std.testing.allocator, 2048, 1792, 256, 2);
    defer queue.deinit();
    try hub.navigate(.springs);
    _ = try fill(&hub);
    try until(&hub, 320);
    _ = try fill(&hub);
    try std.testing.expectEqual(@as(usize, 8), hub.impact.projectiles.count());
    try std.testing.expectEqual(@as(usize, 192), hub.impact.effects.particleCount());
    for (hub.stations) |station| try std.testing.expectEqual(station.history.len, station.history_count);
    var largest: usize = 0;
    var conservative: usize = 0;
    var glyphs = @import("debug_draw").CommandBuffer{};
    var maximum_hex_glyph: usize = 0;
    for ("0123456789abcdef") |letter| {
        glyphs.beginFrame();
        maximum_hex_glyph = @max(maximum_hex_glyph, try glyphs.addLabel(.zero, &.{letter}, .{ 1, 1, 1, 1 }));
    }
    // Measure formatted values with the production font. The leading digit of
    // a three-digit integer cannot be zero, so a dense zero glyph alone does
    // not identify its most expensive legal prefix.
    var text: [32]u8 = undefined;
    var maximum_integer: u64 = 0;
    var maximum_integer_cost: u32 = 0;
    var maximum_fraction: usize = 0;
    var maximum_fraction_cost: u32 = 0;
    var maximum_decimal_glyph: u32 = 0;
    for (0..1000) |value| {
        glyphs.beginFrame();
        const integer_cost = try glyphs.addLabel(.zero, try std.fmt.bufPrint(&text, "{d}", .{value}), .{ 1, 1, 1, 1 });
        if (value < 10) maximum_decimal_glyph = @max(maximum_decimal_glyph, integer_cost);
        if (integer_cost > maximum_integer_cost) {
            maximum_integer = value;
            maximum_integer_cost = integer_cost;
        }
        // Every nonnegative clamped value formats as one of the integer
        // prefixes above plus a dot and exactly three fractional digits.
        // Enumerate those 1,000 suffixes independently, avoiding a million
        // full-value samples. addLabel's per-character costs are additive.
        const fraction = @as(f64, @floatFromInt(value)) / 1000.0;
        const formatted = try std.fmt.bufPrint(&text, "{d:.3}", .{fraction});
        try std.testing.expectEqual(@as(usize, 5), formatted.len);
        try std.testing.expectEqualStrings("0.", formatted[0..2]);
        glyphs.beginFrame();
        const fraction_cost = try glyphs.addLabel(.zero, formatted[1..], .{ 1, 1, 1, 1 });
        if (fraction_cost > maximum_fraction_cost) {
            maximum_fraction = value;
            maximum_fraction_cost = fraction_cost;
        }
    }
    const maximum_seconds = @as(f64, @floatFromInt(maximum_integer)) + @as(f64, @floatFromInt(maximum_fraction)) / 1000.0;
    glyphs.beginFrame();
    const maximum_seconds_cost = try glyphs.addLabel(.zero, try std.fmt.bufPrint(&text, "{d:.3}", .{@min(maximum_seconds, 999.999)}), .{ 1, 1, 1, 1 });
    try std.testing.expectEqual(maximum_integer_cost + maximum_fraction_cost, maximum_seconds_cost);
    // Check the actual clamp boundary and saturated input: rounding must not
    // introduce a fourth integer digit or omit the three fractional digits.
    for ([_]f64{ 999.999, 1000, std.math.floatMax(f64) }) |seconds| {
        const formatted = try std.fmt.bufPrint(&text, "{d:.3}", .{@min(seconds, 999.999)});
        try std.testing.expectEqualStrings("999.999", formatted);
        glyphs.beginFrame();
        try std.testing.expect(try glyphs.addLabel(.zero, formatted, .{ 1, 1, 1, 1 }) <= maximum_seconds_cost);
    }
    glyphs.beginFrame();
    try std.testing.expectEqual(maximum_decimal_glyph, try glyphs.addLabel(.zero, "0", .{ 1, 1, 1, 1 }));
    glyphs.beginFrame();
    const old_integer_cost = try glyphs.addLabel(.zero, "900", .{ 1, 1, 1, 1 });
    glyphs.beginFrame();
    const old_seconds_cost = try glyphs.addLabel(.zero, "900.000", .{ 1, 1, 1, 1 });
    std.debug.print("GLYPH_BUDGET integer_900={d} integer_max_value={d} integer_max_cost={d} seconds_900_000={d} seconds_max={d:.3} seconds_max_cost={d} fractional_suffix_max_cost={d} decimal_glyph_max={d} hex_glyph_max={d}\n", .{ old_integer_cost, maximum_integer, maximum_integer_cost, old_seconds_cost, maximum_seconds, maximum_seconds_cost, maximum_fraction_cost, maximum_decimal_glyph, maximum_hex_glyph });
    for (0..9) |removed| {
        for ([_]bool{ false, true }) |paused| {
            hub.clock.paused = paused;
            for ([_]bool{ false, true }) |diagnostics| {
                hub.diagnostics_enabled = diagnostics;
                for ([_]u64{ 10000000000000000000, std.math.maxInt(u64) }) |counter| {
                    // Zero was verified as the densest decimal glyph. Only a
                    // leading 1 permits 20 decimal digits within u64, so 10^19
                    // maximizes its cost. Exercise the derived bounded-field
                    // maxima as well as saturated raw counters/clamped seconds.
                    // Full values survive; only presentation is exercised.
                    hub.tick = counter;
                    hub.impact.observations.launches = if (counter == std.math.maxInt(u64)) counter else maximum_integer;
                    hub.impact.observations.contacts = hub.impact.observations.launches;
                    hub.impact.bridge.metrics.dropped_effects = hub.impact.observations.launches;
                    hub.clock.lifetime_discarded_time = if (counter == std.math.maxInt(u64)) std.math.floatMax(f64) else maximum_seconds;
                    try view.render(&hub, &queue);
                    const count = queue.prepare().sprites.len;
                    largest = @max(largest, count);
                    try std.testing.expect(count <= 1792);
                    try std.testing.expectEqual(@as(usize, 3), queue.prepare().ranges.len);
                    try std.testing.expectEqual(counter, hub.tick);
                    if (diagnostics) {
                        const digest = (try hub.fingerprint()).formatLowerHex();
                        glyphs.beginFrame();
                        const actual_hash = try glyphs.addLabel(.zero, digest[0..12], .{ 1, 1, 1, 1 });
                        const upper = count - actual_hash + 12 * maximum_hex_glyph;
                        conservative = @max(conservative, upper);
                        if (upper > 1792) std.debug.print("DIAGNOSTIC_GLYPH_BOUND actual={d} upper={d} hash_cost={d} glyph_max={d} removed={d} paused={} tick={d}\n", .{ count, upper, actual_hash, maximum_hex_glyph, removed, paused, counter });
                        try std.testing.expect(upper <= 1792);
                    }
                }
            }
        }
        if (removed < 8) {
            var snapshots: [impact.projectile_capacity]p.Snapshot = undefined;
            const values = try hub.impact.projectiles.copySnapshots(&snapshots);
            try hub.impact.projectiles.remove(values[0].id);
            hub.impact.projectiles.clearEvents();
        }
    }
    std.debug.print("MULTI_IMPACT_DIAGNOSTIC_MAX sprites={d}/1792 conservative_hash_bound={d}/1792 projectiles=0..8 particles=192 batches=3 full_u64_ticks=true paused=true saturated_counters=true\n", .{ largest, conservative });
}

test "fresh keyboard and gamepad presses launch concurrently while holds and pending edges coalesce" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    try hub.navigate(.springs);
    var mapper = actions.Mapper{};
    const Raw = @import("physical_input").RawInputState;
    const held = Raw{ .keyboard = .{ .e = true }, .gamepad_button_west = true };
    try actions.advance(&hub, &mapper, held, mapper.sample(held), 4.0 / 240.0);
    for (0..12) |_| try actions.advance(&hub, &mapper, held, mapper.sample(held), 4.0 / 240.0);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.launches);
    try std.testing.expectEqual(@as(u64, 0), hub.impact.observations.busy);
    for (1..8) |index| {
        _ = mapper.sample(.{});
        const pressed = if (index % 2 == 0) Raw{ .keyboard = .{ .e = true } } else Raw{ .gamepad_button_west = true };
        try actions.advance(&hub, &mapper, pressed, mapper.sample(pressed), 4.0 / 240.0);
        try std.testing.expectEqual(@as(u64, @intCast(index + 1)), hub.impact.observations.launches);
    }
    try std.testing.expectEqual(@as(usize, 8), hub.impact.projectiles.count());
    try hub.reset();
    try hub.navigate(.springs);
    hub.clock.setPaused(true);
    mapper = .{};
    for (0..5) |_| {
        mapper.capturePress(.{ .e = true });
        try actions.advance(&hub, &mapper, .{}, mapper.sample(.{}), 0.04);
    }
    try std.testing.expectEqual(@as(u64, 0), hub.impact.next_shot_ordinal);
    try std.testing.expect(hub.impact.pending_activation);
    try actions.advance(&hub, &mapper, .{}, .{ .step = true }, 0.04);
    try std.testing.expectEqual(@as(u64, 1), hub.tick);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.next_shot_ordinal);
    try actions.advance(&hub, &mapper, .{}, .{ .step = true }, 0.04);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.next_shot_ordinal);
}

test "range rejection leaves the seeded first color and projectile identity unchanged" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var reference = try init(std.testing.allocator);
    defer close(&reference);
    hub.impact.pending_activation = true;
    try tick(&hub);
    try tick(&reference);
    try std.testing.expectEqual(@as(u64, 1), hub.impact.observations.out_of_range);
    try std.testing.expectEqual(@as(u64, 0), hub.impact.next_shot_ordinal);
    try hub.navigate(.springs);
    try reference.navigate(.springs);
    try std.testing.expectEqualDeep(try shoot(&reference), try shoot(&hub));
}

test "multiple native contact outcomes remain identical under presentation saturation" {
    var hub = try init(std.testing.allocator);
    defer close(&hub);
    var reference = try init(std.testing.allocator);
    defer close(&reference);
    _ = try hub.impact.effects.spawn(.{ .id = hub.installations.roots[0].id, .position = .zero, .definition = .{ .burst = impact.particle_capacity, .particle_lifetime_ticks = 1000 } });
    try hub.navigate(.springs);
    try reference.navigate(.springs);
    _ = try fill(&hub);
    _ = try fill(&reference);
    while (hub.tick < 319) {
        try tick(&hub);
        try tick(&reference);
        try std.testing.expectEqualDeep(reference.impact.observations.last_batch[0..reference.impact.observations.batch_count], hub.impact.observations.last_batch[0..hub.impact.observations.batch_count]);
    }
    try std.testing.expectEqual(@as(u64, 192), hub.impact.effects.metrics().dropped_particles);
    try std.testing.expectEqual(@as(u64, 0), reference.impact.effects.metrics().dropped_particles);
    try std.testing.expectEqual(@as(u64, 8), hub.impact.observations.contacts);
    try std.testing.expectEqual(@as(usize, 0), hub.impact.projectiles.count());
    try std.testing.expectEqual(reference.impact.observations.events_digest, hub.impact.observations.events_digest);
}
