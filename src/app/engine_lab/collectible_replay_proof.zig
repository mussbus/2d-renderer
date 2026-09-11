//! Recording fixture and headless proof. The adapter's playback imports no route helper.
const std = @import("std");
pub const replay = @import("engine_lab_replay");
const schema = replay.schema;
const lab = schema.lab;
const route = @import("traversal_verification.zig");

pub const RouteCursor = struct {
    record: u32 = 0,
    segment: usize = 0,
    elapsed: u16 = 0,
    pub fn call(self: *RouteCursor, adapter: *replay.Adapter, control: replay.Control) !replay.Result {
        if (adapter.mode != .recording or self.record != adapter.cursor()) return error.RouteCursor;
        var intent = lab.neutral_intent;
        if (self.record > 0 and self.record <= 1188) {
            if (self.segment >= route.easy.len) return error.RouteCursor;
            intent = route.input(adapter.hub, route.easy[self.segment], self.elapsed);
        } else if (self.record > 1188) {
            intent.move_axis = std.math.clamp((lab.collectibles_module.content.spawns[5].position.x - adapter.hub.actor.worldPosition().x) * 3, -1, 1);
        }
        const result = try adapter.record(control, intent, self.record == 0);
        if (result == .stepped) {
            if (self.record > 0 and self.record <= 1188) {
                self.elapsed += 1;
                if (self.elapsed == route.easy[self.segment].ticks) {
                    try route.validateBoundary(adapter.hub, route.easy[self.segment]);
                    self.segment += 1;
                    self.elapsed = 0;
                }
            }
            self.record += 1;
        }
        return result;
    }
};
pub fn recordAll(adapter: *replay.Adapter) !void {
    var cursor = RouteCursor{};
    while (try cursor.call(adapter, .run_one) == .stepped) {}
    if (!adapter.finished or cursor.record != schema.record_count) return error.IncompleteRecording;
}
pub fn playAll(adapter: *replay.Adapter, groups: []const u8) !void {
    if (groups.len == 0) return error.InvalidGrouping;
    for (groups) |group| if (group == 0 or group > 4) return error.InvalidGrouping;
    var round: usize = 0;
    while (!adapter.finished) : (round += 1) {
        for (0..groups[round % groups.len]) |_| {
            if (try adapter.play(.run_one) == .finished) break;
        }
    }
}

pub const Operations = struct { alloc: usize = 0, resize: usize = 0, remap: usize = 0, free: usize = 0 };
/// Counts attempted allocator operations, including unsuccessful resize/remap calls.
/// This is application proof instrumentation, never simulation state or authority.
pub const AllocationAudit = struct {
    backing: std.mem.Allocator,
    operations: Operations = .{},
    live: usize = 0,
    peak: usize = 0,
    allocated: usize = 0,
    freed: usize = 0,
    pub fn allocator(self: *AllocationAudit) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn grow(self: *AllocationAudit, old: usize, new: usize) void {
        self.live = self.live - old + new;
        if (new >= old) self.allocated += new - old else self.freed += old - new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *AllocationAudit = @ptrCast(@alignCast(ctx));
        self.operations.alloc += 1;
        const result = self.backing.rawAlloc(len, alignment, ra) orelse return null;
        self.grow(0, len);
        return result;
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *AllocationAudit = @ptrCast(@alignCast(ctx));
        self.operations.resize += 1;
        if (!self.backing.rawResize(memory, alignment, new_len, ra)) return false;
        self.grow(memory.len, new_len);
        return true;
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *AllocationAudit = @ptrCast(@alignCast(ctx));
        self.operations.remap += 1;
        const result = self.backing.rawRemap(memory, alignment, new_len, ra) orelse return null;
        self.grow(memory.len, new_len);
        return result;
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *AllocationAudit = @ptrCast(@alignCast(ctx));
        self.operations.free += 1;
        self.backing.rawFree(memory, alignment, ra);
        self.grow(memory.len, 0);
    }
    pub fn unchanged(self: *const AllocationAudit, before: Operations) !void {
        if (!std.meta.eql(before, self.operations)) return error.SteadyStateAllocation;
    }
};
pub fn sessionPayload(session: *const schema.rr.Session) usize {
    return session.initial.len + session.storage.len * @sizeOf(schema.rr.Tick) + (session.causal_storage.len + session.observed_storage.len) * @sizeOf(schema.rr.Event) + session.named_storage.len * @sizeOf(schema.rr.NamedCheckpoint);
}
pub fn report(adapter: *const replay.Adapter, artifact: []const u8, audit: *const AllocationAudit) void {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(artifact, &hash, .{});
    std.debug.print("ENGINE_LAB_REPLAY_OK mode={s} records={d} hub_ticks={d} events={any} names={d} contributors={d} bytes={d} sha256={x}\n", .{ @tagName(adapter.mode), adapter.cursor(), adapter.hub.tick, adapter.counts, adapter.session.named_count, adapter.scratch.contributors.len, artifact.len, hash });
    std.debug.print("IDENTITY content={s} initial={s} final={s}\n", .{ adapter.content.formatLowerHex(), adapter.initial.formatLowerHex(), adapter.last.formatLowerHex() });
    std.debug.print("STORAGE adapter={d} hub={d} session_owner={d} player={d} scratch={d} animation={d} session_payload={d} live={d} initialization_peak={d} allocated={d} freed={d} operations={any}\n", .{ @sizeOf(replay.Adapter), @sizeOf(lab.Hub), @sizeOf(schema.rr.Session), @sizeOf(schema.rr.Player), @sizeOf(replay.state.Scratch), @sizeOf(@TypeOf(adapter.scratch.playback)), sessionPayload(adapter.session), audit.live, audit.peak, audit.allocated, audit.freed, audit.operations });
    std.debug.print("CANONICAL maximum_observed={any} final={any}\n", .{ adapter.scratch.maximum_lengths, adapter.scratch.lengths });
    for (adapter.session.named_storage[0..adapter.session.named_count]) |checkpoint| std.debug.print("CHECKPOINT {s} record={d} digest={s}\n", .{ checkpoint.name.slice(), checkpoint.tick, checkpoint.digest.formatLowerHex() });
    for (adapter.scratch.contributors) |contributor| std.debug.print("FINAL_CONTRIBUTOR {x} {s}\n", .{ contributor.identity.id, contributor.digest.formatLowerHex() });
}
