const std = @import("std");
const foundation = @import("foundation");
const runtime_entity = @import("runtime_entity.zig");

pub const GrowthCategory = enum {
    entity_slots,
    entity_slot_retired,
    persistent_id_mappings,
    active_levels,
};

pub const GrowthCause = enum {
    level_activation,
    world_activation,
    runtime_create,
    entity_destroy,
    level_deactivation,
    editor_preview,
    snapshot_acquisition,
};

pub const GrowthEvent = struct {
    category: GrowthCategory,
    old_capacity: usize,
    new_capacity: usize,
    hard_capacity: usize,
    cause: GrowthCause,
};

pub const max_growth_events_per_publication: usize = 32;

pub const GrowthEvents = struct {
    storage: [max_growth_events_per_publication]GrowthEvent = undefined,
    count: usize = 0,

    pub fn add(self: *GrowthEvents, event: GrowthEvent) error{GrowthReportCapacity}!void {
        if (self.count == self.storage.len) return error.GrowthReportCapacity;
        self.storage[self.count] = event;
        self.count += 1;
    }

    pub fn values(self: *const GrowthEvents) []const GrowthEvent {
        return self.storage[0..self.count];
    }
};

pub const GrowthSink = struct {
    context: ?*anyopaque,
    emit_fn: *const fn (?*anyopaque, GrowthEvent) void,

    pub fn emit(self: GrowthSink, events: []const GrowthEvent) void {
        for (events) |event| self.emit_fn(self.context, event);
    }
};

pub const Config = struct {
    initial_entity_capacity: usize,
    hard_entity_capacity: usize,
    initial_mapping_capacity: usize,
    hard_mapping_capacity: usize,

    pub fn validate(self: Config) error{InvalidRegistryCapacity}!void {
        const max_slots = std.math.maxInt(u32);
        if (self.initial_entity_capacity == 0 or
            self.initial_entity_capacity > self.hard_entity_capacity or
            self.hard_entity_capacity >= max_slots or
            self.initial_mapping_capacity > self.hard_mapping_capacity or
            self.hard_mapping_capacity > self.hard_entity_capacity)
        {
            return error.InvalidRegistryCapacity;
        }
    }
};

pub const RegistryError = error{
    DuplicateActiveEntityId,
    EntityNotFound,
    GrowthReportCapacity,
    InvalidHandle,
    InvalidRegistryCapacity,
    RegistryCapacity,
    StaleHandle,
};

const SlotState = enum { free, active, retired };

const Slot = struct {
    generation: u32 = 1,
    state: SlotState = .free,
    entity: ?runtime_entity.RuntimeEntity = null,
};

const PersistentMapping = struct {
    id: foundation.identity.EntityId,
    handle: foundation.identity.EntityHandle,
};

pub const EntityRegistry = struct {
    allocator: std.mem.Allocator,
    slots: []Slot,
    logical_entity_capacity: usize,
    mappings: []PersistentMapping,
    logical_mapping_capacity: usize,
    mapping_count: usize = 0,
    active_count: usize = 0,
    retired_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator, config: Config) !EntityRegistry {
        try config.validate();
        const slots = try allocator.alloc(Slot, config.hard_entity_capacity);
        errdefer allocator.free(slots);
        for (slots) |*slot| slot.* = .{};
        const mappings = try allocator.alloc(PersistentMapping, config.hard_mapping_capacity);
        errdefer allocator.free(mappings);
        return .{
            .allocator = allocator,
            .slots = slots,
            .logical_entity_capacity = config.initial_entity_capacity,
            .mappings = mappings,
            .logical_mapping_capacity = config.initial_mapping_capacity,
        };
    }

    pub fn deinit(self: *EntityRegistry) void {
        for (self.slots) |*slot| {
            if (slot.entity) |*record| record.deinit(self.allocator);
        }
        self.allocator.free(self.mappings);
        self.allocator.free(self.slots);
        self.* = undefined;
    }

    pub fn clone(self: *const EntityRegistry) !EntityRegistry {
        const slots = try self.allocator.alloc(Slot, self.slots.len);
        errdefer self.allocator.free(slots);
        for (slots) |*slot| slot.* = .{};
        var initialized: usize = 0;
        errdefer {
            for (slots[0..initialized]) |*slot| if (slot.entity) |*record| record.deinit(self.allocator);
        }
        for (self.slots, 0..) |slot, index| {
            slots[index].generation = slot.generation;
            slots[index].state = slot.state;
            slots[index].entity = if (slot.entity) |record| try record.clone(self.allocator) else null;
            initialized += 1;
        }
        const mappings = try self.allocator.alloc(PersistentMapping, self.mappings.len);
        errdefer self.allocator.free(mappings);
        @memcpy(mappings[0..self.mapping_count], self.mappings[0..self.mapping_count]);
        return .{
            .allocator = self.allocator,
            .slots = slots,
            .logical_entity_capacity = self.logical_entity_capacity,
            .mappings = mappings,
            .logical_mapping_capacity = self.logical_mapping_capacity,
            .mapping_count = self.mapping_count,
            .active_count = self.active_count,
            .retired_count = self.retired_count,
        };
    }

    /// On success ownership of record transfers to the registry. On failure
    /// the caller retains ownership and must deinitialize it.
    pub fn insert(
        self: *EntityRegistry,
        record: runtime_entity.RuntimeEntity,
        cause: GrowthCause,
        growth: *GrowthEvents,
    ) !foundation.identity.EntityHandle {
        if (record.persistent_id) |id| if (self.resolve(id) != null) return error.DuplicateActiveEntityId;
        const slot_index = try self.reserveSlot(cause, growth);
        if (record.persistent_id != null) try self.ensureMappingCapacity(cause, growth);
        const slot = &self.slots[slot_index];
        const handle = try foundation.identity.EntityHandle.init(@intCast(slot_index), slot.generation);
        slot.entity = record;
        slot.entity.?.handle = handle;
        slot.state = .active;
        self.active_count += 1;
        if (record.persistent_id) |id| self.insertMapping(id, handle);
        return handle;
    }

    pub fn destroy(
        self: *EntityRegistry,
        handle: foundation.identity.EntityHandle,
        cause: GrowthCause,
        growth: *GrowthEvents,
    ) RegistryError!void {
        const slot = try self.slotFor(handle);
        if (slot.generation == std.math.maxInt(u32) and growth.count == growth.storage.len) return error.GrowthReportCapacity;
        if (slot.entity.?.persistent_id) |id| self.removeMapping(id);
        slot.entity.?.deinit(self.allocator);
        slot.entity = null;
        self.active_count -= 1;
        if (nextGenerationAfterDestroy(slot.generation)) |next_generation| {
            slot.generation = next_generation;
            slot.state = .free;
        } else {
            slot.state = .retired;
            self.retired_count += 1;
            growth.add(.{
                .category = .entity_slot_retired,
                .old_capacity = self.slots.len - self.retired_count + 1,
                .new_capacity = self.slots.len - self.retired_count,
                .hard_capacity = self.slots.len,
                .cause = cause,
            }) catch return error.GrowthReportCapacity;
        }
    }

    pub fn get(self: *const EntityRegistry, handle: foundation.identity.EntityHandle) RegistryError!*const runtime_entity.RuntimeEntity {
        return &(try self.slotForConst(handle)).entity.?;
    }

    pub fn getMutable(self: *EntityRegistry, handle: foundation.identity.EntityHandle) RegistryError!*runtime_entity.RuntimeEntity {
        return &(try self.slotFor(handle)).entity.?;
    }

    pub fn resolve(self: *const EntityRegistry, id: foundation.identity.EntityId) ?foundation.identity.EntityHandle {
        var low: usize = 0;
        var high = self.mapping_count;
        while (low < high) {
            const middle = low + (high - low) / 2;
            switch (self.mappings[middle].id.byteOrder(id)) {
                .lt => low = middle + 1,
                .gt => high = middle,
                .eq => return self.mappings[middle].handle,
            }
        }
        return null;
    }

    pub fn assignPersistentId(
        self: *EntityRegistry,
        handle: foundation.identity.EntityHandle,
        id: foundation.identity.EntityId,
        cause: GrowthCause,
        growth: *GrowthEvents,
    ) !void {
        const slot = try self.slotFor(handle);
        if (slot.entity.?.persistent_id != null) return error.DuplicateActiveEntityId;
        if (self.resolve(id) != null) return error.DuplicateActiveEntityId;
        try self.ensureMappingCapacity(cause, growth);
        slot.entity.?.persistent_id = id;
        self.insertMapping(id, handle);
    }

    pub fn activeHandleAt(self: *const EntityRegistry, active_index: usize) ?foundation.identity.EntityHandle {
        var current: usize = 0;
        for (self.slots[0..self.logical_entity_capacity], 0..) |slot, slot_index| {
            if (slot.state != .active) continue;
            if (current == active_index) return .{ .slot = @intCast(slot_index), .generation = slot.generation };
            current += 1;
        }
        return null;
    }

    pub fn entityCapacity(self: *const EntityRegistry) usize {
        return self.logical_entity_capacity;
    }

    pub fn hardEntityCapacity(self: *const EntityRegistry) usize {
        return self.slots.len;
    }

    pub fn retiredSlotCount(self: *const EntityRegistry) usize {
        return self.retired_count;
    }

    fn reserveSlot(self: *EntityRegistry, cause: GrowthCause, growth: *GrowthEvents) !usize {
        while (true) {
            for (self.slots[0..self.logical_entity_capacity], 0..) |slot, index| {
                if (slot.state == .free) return index;
            }
            if (self.logical_entity_capacity == self.slots.len) return error.RegistryCapacity;
            const old = self.logical_entity_capacity;
            const doubled = if (old > self.slots.len / 2) self.slots.len else old * 2;
            self.logical_entity_capacity = @max(old + 1, doubled);
            try growth.add(.{
                .category = .entity_slots,
                .old_capacity = old,
                .new_capacity = self.logical_entity_capacity,
                .hard_capacity = self.slots.len,
                .cause = cause,
            });
        }
    }

    fn ensureMappingCapacity(self: *EntityRegistry, cause: GrowthCause, growth: *GrowthEvents) !void {
        if (self.mapping_count < self.logical_mapping_capacity) return;
        if (self.logical_mapping_capacity == self.mappings.len) return error.RegistryCapacity;
        const old = self.logical_mapping_capacity;
        const doubled = if (old == 0) @as(usize, 1) else if (old > self.mappings.len / 2) self.mappings.len else old * 2;
        self.logical_mapping_capacity = @max(old + 1, doubled);
        try growth.add(.{
            .category = .persistent_id_mappings,
            .old_capacity = old,
            .new_capacity = self.logical_mapping_capacity,
            .hard_capacity = self.mappings.len,
            .cause = cause,
        });
    }

    fn insertMapping(self: *EntityRegistry, id: foundation.identity.EntityId, handle: foundation.identity.EntityHandle) void {
        var position = self.mapping_count;
        while (position > 0 and id.byteOrder(self.mappings[position - 1].id) == .lt) : (position -= 1) {
            self.mappings[position] = self.mappings[position - 1];
        }
        self.mappings[position] = .{ .id = id, .handle = handle };
        self.mapping_count += 1;
    }

    fn removeMapping(self: *EntityRegistry, id: foundation.identity.EntityId) void {
        for (self.mappings[0..self.mapping_count], 0..) |mapping, index| {
            if (!mapping.id.eql(id)) continue;
            if (index + 1 < self.mapping_count) {
                std.mem.copyForwards(
                    PersistentMapping,
                    self.mappings[index .. self.mapping_count - 1],
                    self.mappings[index + 1 .. self.mapping_count],
                );
            }
            self.mapping_count -= 1;
            return;
        }
    }

    fn slotFor(self: *EntityRegistry, handle: foundation.identity.EntityHandle) RegistryError!*Slot {
        if (!handle.isValid() or handle.slot >= self.logical_entity_capacity) return error.InvalidHandle;
        const slot = &self.slots[handle.slot];
        if (slot.generation != handle.generation or slot.state != .active or slot.entity == null) return error.StaleHandle;
        return slot;
    }

    fn slotForConst(self: *const EntityRegistry, handle: foundation.identity.EntityHandle) RegistryError!*const Slot {
        if (!handle.isValid() or handle.slot >= self.logical_entity_capacity) return error.InvalidHandle;
        const slot = &self.slots[handle.slot];
        if (slot.generation != handle.generation or slot.state != .active or slot.entity == null) return error.StaleHandle;
        return slot;
    }
};

/// Returns null at the terminal generation. The owning registry then retires
/// the slot permanently, reports capacity loss, and never wraps to zero or a
/// generation that could revalidate an ancient handle.
pub fn nextGenerationAfterDestroy(current: u32) ?u32 {
    if (current == std.math.maxInt(u32)) return null;
    return current + 1;
}

test "terminal handle generation retires instead of wrapping" {
    try std.testing.expectEqual(@as(?u32, null), nextGenerationAfterDestroy(std.math.maxInt(u32)));
    try std.testing.expectEqual(@as(?u32, 2), nextGenerationAfterDestroy(1));
}
