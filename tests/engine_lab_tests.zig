const std = @import("std");
const labs = @import("engine_lab");
const actions = @import("engine_lab_actions");
const view_module = @import("engine_lab_view");
const queue_module = @import("render_queue");

fn seed() !labs.Seed {
    return labs.Seed.parseLowerHex(labs.default_seed);
}

fn close(host: *labs.Host) void {
    host.deinit() catch |err| std.debug.panic("test cleanup: {s}", .{@errorName(err)});
}

test "registry preserves public order, unique IDs, descriptions and lookup" {
    try std.testing.expectEqual(@as(usize, 2), labs.registry.len);
    try std.testing.expectEqualStrings("integration-overview", labs.registry[0].id);
    try std.testing.expectEqualStrings("determinism-fixed-step", labs.registry[1].id);
    for (labs.registry, 0..) |definition, index| {
        try std.testing.expectEqual(index, try labs.findDefinition(definition.id));
        try std.testing.expect(definition.name.len > 0 and definition.description.len > 0);
        for (labs.registry[0..index]) |previous| {
            try std.testing.expect(!std.mem.eql(u8, previous.id, definition.id));
            try std.testing.expect(previous.kind != definition.kind);
        }
    }
    try std.testing.expectError(error.UnknownLab, labs.findDefinition("absent"));
}

const Log = struct {
    events: [8]labs.LifecycleEvent = undefined,
    kinds: [8]labs.Kind = undefined,
    count: usize = 0,
    fn record(context: *anyopaque, event: labs.LifecycleEvent, kind: labs.Kind) void {
        const self: *Log = @ptrCast(@alignCast(context));
        std.debug.assert(self.count < self.events.len);
        self.events[self.count] = event;
        self.kinds[self.count] = kind;
        self.count += 1;
    }
};

test "real sessions initialize, shut down, reset and switch in order" {
    var log = Log{};
    var host = try labs.Host.init(.{ .allocator = std.testing.allocator }, 0, try seed(), .{
        .context = &log,
        .notify = Log.record,
    });
    defer close(&host);
    try host.switchTo(1);
    try host.reset();
    try host.deinit();
    try std.testing.expectEqualSlices(labs.LifecycleEvent, &.{
        .initialized, .shutdown, .initialized, .shutdown, .initialized, .shutdown,
    }, log.events[0..log.count]);
    try std.testing.expectEqualSlices(labs.Kind, &.{
        .integration, .integration, .determinism, .determinism, .determinism, .determinism,
    }, log.kinds[0..log.count]);
    try std.testing.expect(host.active == null);
}

test "reset reconstructs initial fingerprint, history, pending input and clock" {
    var host = try labs.Host.init(.{ .allocator = std.testing.allocator }, 0, try seed(), null);
    defer close(&host);
    const initial = try host.active.?.fingerprint();
    host.clock.setPaused(false);
    host.pending_impulse = true;
    for (0..65) |_| try host.advanceFrame(1.0 / 60.0);
    try std.testing.expect(!(try host.active.?.fingerprint()).eql(initial));
    try std.testing.expect(host.active.?.history_count > 0);
    host.pending_impulse = true;
    try host.reset();
    try std.testing.expect((try host.active.?.fingerprint()).eql(initial));
    try std.testing.expectEqual(@as(u64, 0), host.active.?.tick);
    try std.testing.expectEqual(@as(usize, 0), host.active.?.history_count);
    try std.testing.expectEqual(@as(usize, 1), host.active.?.checkpoint_count);
    try std.testing.expect(host.clock.paused and !host.pending_impulse);
    try std.testing.expectEqual(@as(f64, 0), host.clock.accumulator);
    try std.testing.expectEqual(@as(f64, 0), host.clock.lifetime_discarded_time);
}

test "switch round trip isolates lab configuration and state" {
    var host = try labs.Host.init(.{ .allocator = std.testing.allocator }, 0, try seed(), null);
    defer close(&host);
    const initial = try host.active.?.fingerprint();
    host.clock.setPaused(false);
    try host.advanceFrame(1.0 / 60.0);
    try host.switchTo(1);
    try std.testing.expect(!(try host.active.?.fingerprint()).eql(initial));
    host.clock.setPaused(false);
    for (0..120) |_| try host.advanceFrame(1.0 / 60.0);
    try host.switchTo(0);
    try std.testing.expect((try host.active.?.fingerprint()).eql(initial));
    try std.testing.expectEqual(@as(usize, 0), host.active.?.history_count);
}

test "seed participates in initial state and repeated mixed-frame checkpoint proof" {
    const original_seed = try seed();
    const checkpoints = try labs.verifyRepeat(.{ .allocator = std.testing.allocator }, original_seed);
    for (checkpoints, labs.checkpoint_ticks, 0..) |checkpoint, tick, index| {
        try std.testing.expectEqual(tick, checkpoint.tick);
        if (index != 0) try std.testing.expect(!checkpoint.digest.eql(checkpoints[index - 1].digest));
    }
    var other_seed = original_seed;
    other_seed.bytes[0] ^= 1;
    var host = try labs.Host.init(.{ .allocator = std.testing.allocator }, 1, other_seed, null);
    defer close(&host);
    try std.testing.expect(!(try host.active.?.fingerprint()).eql(checkpoints[0].digest));
}

test "scene hierarchy read view supplies resolved anchors and stable F identities" {
    var host = try labs.Host.init(.{ .allocator = std.testing.allocator }, 0, try seed(), null);
    defer close(&host);
    const anchors = &host.active.?.anchors;
    // 1e-6 m accommodates f32 addition of parent 2.8 and local -0.4, far below a pixel.
    for (anchors.anchors, 0..) |anchor, index| {
        try std.testing.expectApproxEqAbs(@as(f32, 2.4), anchor.world.y, 1e-6);
        try std.testing.expectApproxEqAbs((@as(f32, @floatFromInt(index)) - 1) * 1.8, anchor.world.x, 1e-6);
        try std.testing.expect(!anchor.id.eql(anchors.root.id));
    }
}

test "pause single-step completion and interpolation preserve simulation authority" {
    var host = try labs.Host.init(.{ .allocator = std.testing.allocator }, 1, try seed(), null);
    defer close(&host);
    try host.advanceFrame(0.05);
    try std.testing.expectEqual(@as(u64, 0), host.active.?.tick);
    host.clock.requestSingleStep();
    try host.advanceFrame(0.05);
    try std.testing.expectEqual(@as(u64, 1), host.active.?.tick);
    const digest = try host.active.?.fingerprint();
    _ = try host.active.?.offsets(0.0);
    _ = try host.active.?.offsets(0.75);
    try std.testing.expect((try host.active.?.fingerprint()).eql(digest));
    host.clock.setPaused(false);
    while (!host.active.?.complete()) try host.advanceFrame(1.0 / 60.0);
    try std.testing.expectEqual(@as(u64, 960), host.active.?.tick);
    try std.testing.expect(host.clock.paused);
    host.clock.requestSingleStep();
    try host.advanceFrame(1.0);
    try std.testing.expectEqual(@as(u64, 960), host.active.?.tick);
}

test "manual impulse changes overview but is excluded from deterministic experiment" {
    var left = try labs.Host.init(.{ .allocator = std.testing.allocator }, 0, try seed(), null);
    defer close(&left);
    var right = try labs.Host.init(.{ .allocator = std.testing.allocator }, 0, try seed(), null);
    defer close(&right);
    try left.active.?.fixedUpdate(true);
    try right.active.?.fixedUpdate(false);
    try std.testing.expect(!(try left.active.?.fingerprint()).eql(try right.active.?.fingerprint()));
    try left.switchTo(1);
    try right.switchTo(1);
    try left.active.?.fixedUpdate(true);
    try right.active.?.fixedUpdate(false);
    try std.testing.expect((try left.active.?.fingerprint()).eql(try right.active.?.fingerprint()));
}

test "input edges and focus/reset suppression do not replay held controls" {
    var mapper = actions.Mapper{};
    try std.testing.expect(mapper.sample(.{ .keyboard = .{ .r = true } }).reset);
    try std.testing.expect(!mapper.sample(.{ .keyboard = .{ .r = true } }).reset);
    mapper.suppressHeld(.{ .keyboard = .{ .r = true, .space = true } });
    const held = mapper.sample(.{ .keyboard = .{ .r = true, .space = true } });
    try std.testing.expect(!held.reset and !held.impulse);
    _ = mapper.sample(.{});
    try std.testing.expect(mapper.sample(.{ .keyboard = .{ .space = true } }).impulse);
    _ = mapper.sample(.{ .keyboard = .{ .p = true }, .focus_lost = true });
    try std.testing.expect(!mapper.sample(.{ .keyboard = .{ .p = true } }).pause);
    try std.testing.expect(mapper.sample(.{ .keyboard_focused = false, .window_close_requested = true }).exit);
}

test "steady fixed/render updates allocate nothing and submit one instanced range" {
    var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var host = try labs.Host.init(.{ .allocator = allocator.allocator() }, 1, try seed(), null);
    defer close(&host);
    var queue = try queue_module.UnifiedRenderQueue.init(allocator.allocator(), 2048, 1792, 256, 2);
    defer queue.deinit();
    queue.markStabilized();
    allocator.fail_index = allocator.alloc_index;
    allocator.resize_fail_index = allocator.resize_index;
    var view = view_module.View{};
    host.clock.setPaused(false);
    for (0..240) |_| {
        try host.advanceFrame(1.0 / 60.0);
        try view.render(&host, &queue);
        const prepared = queue.prepare();
        try std.testing.expectEqual(@as(usize, 1), prepared.ranges.len);
        try std.testing.expect(prepared.sprites.len > labs.mass_count);
        try std.testing.expect(prepared.sprites.len <= 1792);
    }
    try std.testing.expect(!allocator.has_induced_failure);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}

test "invalid selection and allocation failure retain the old active session" {
    var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var host = try labs.Host.init(.{ .allocator = allocator.allocator() }, 0, try seed(), null);
    defer close(&host);
    const initial = try host.active.?.fingerprint();
    try std.testing.expectError(error.UnknownLab, host.switchTo(200));
    try std.testing.expect((try host.active.?.fingerprint()).eql(initial));
    allocator.fail_index = allocator.alloc_index;
    try std.testing.expectError(error.OutOfMemory, host.switchTo(1));
    try std.testing.expect((try host.active.?.fingerprint()).eql(initial));
}

test "all partial construction allocation failures clean up acquired resources" {
    // Exercise every allocation boundary, including scene cloning and snapshots.
    var fail_index: usize = 0;
    while (fail_index < 2000) : (fail_index += 1) {
        var allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index });
        var host = labs.Host.init(.{ .allocator = allocator.allocator() }, 0, try seed(), null) catch |err| {
            try std.testing.expect(allocator.has_induced_failure);
            try std.testing.expect(err == error.OutOfMemory or err == error.AllocationFailure);
            try std.testing.expectEqual(allocator.allocated_bytes, allocator.freed_bytes);
            continue;
        };
        try host.deinit();
        try std.testing.expectEqual(allocator.allocated_bytes, allocator.freed_bytes);
        return;
    }
    return error.AllocationFailureTestDidNotReachSuccessfulConstruction;
}

test "short key taps survive key-down and key-up within one render frame" {
    var mapper = actions.Mapper{};
    mapper.capturePress(.{ .p = true });
    try std.testing.expect(mapper.sample(.{}).pause);
    try std.testing.expect(!mapper.sample(.{}).pause);
    mapper.capturePress(.{ .escape = true });
    try std.testing.expect(mapper.sample(.{}).exit);
    mapper.capturePress(.{ .space = true });
    mapper.suppressHeld(.{});
    try std.testing.expect(!mapper.sample(.{}).impulse);
}

test "production diagnostic glyphs have readable orientation and distinct digits" {
    const debug = @import("debug_draw");
    var commands = debug.CommandBuffer{};
    _ = try commands.addLabel(.{ .x = 0, .y = 0 }, "L", .{ 1, 1, 1, 1 });
    // A readable L occupies the left edge on its upper rows; a mirrored L does not.
    for (commands.commands[0..4]) |command| try std.testing.expectEqual(@as(f32, 0), command.world_position[0]);
    try std.testing.expect(commands.commands[commands.count - 1].world_position[0] > 0);
    commands.beginFrame();
    _ = try commands.addLabel(.{ .x = 0, .y = 0 }, "0", .{ 1, 1, 1, 1 });
    const zero_count = commands.count;
    commands.beginFrame();
    _ = try commands.addLabel(.{ .x = 0, .y = 0 }, "1", .{ 1, 1, 1, 1 });
    try std.testing.expect(zero_count != commands.count);
}
