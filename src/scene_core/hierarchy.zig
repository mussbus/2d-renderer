const std = @import("std");
const foundation = @import("foundation");
const entity = @import("entity.zig");
const metadata = @import("metadata.zig");

pub const max_entity_hierarchy_depth: usize = 64;

pub const HierarchyError = error{
    DuplicateEntityId,
    HierarchyCycle,
    HierarchyTooDeep,
    MissingParent,
    OptionalParent,
    ScratchTooSmall,
    SelfParent,
};

pub fn evaluationOrder(
    entities: []const entity.EntityInstanceDefinition,
    external_parent_ids: []const foundation.identity.EntityId,
    output_indices: []usize,
    depth_scratch: []u8,
) HierarchyError![]const usize {
    if (output_indices.len < entities.len or depth_scratch.len < entities.len) return error.ScratchTooSmall;
    try rejectDuplicateIds(entities);
    @memset(depth_scratch[0..entities.len], 0);
    var emitted: usize = 0;
    while (emitted < entities.len) : (emitted += 1) {
        var selected: ?usize = null;
        for (entities, 0..) |candidate, index| {
            if (depth_scratch[index] != 0) continue;
            const depth = try readyDepth(candidate, entities, external_parent_ids, depth_scratch);
            if (depth == null) continue;
            if (selected == null or candidate.entity_id.byteOrder(entities[selected.?].entity_id) == .lt) selected = index;
        }
        const index = selected orelse return error.HierarchyCycle;
        const depth = (try readyDepth(entities[index], entities, external_parent_ids, depth_scratch)).?;
        if (depth > max_entity_hierarchy_depth) return error.HierarchyTooDeep;
        depth_scratch[index] = @intCast(depth);
        output_indices[emitted] = index;
    }
    return output_indices[0..entities.len];
}

pub fn effectiveEnabledStates(
    entities: []const entity.EntityInstanceDefinition,
    evaluation_order: []const usize,
    output: []bool,
) error{ScratchTooSmall}![]const bool {
    if (output.len < entities.len) return error.ScratchTooSmall;
    for (evaluation_order) |index| {
        const parent_enabled = if (entities[index].parent) |parent| blk: {
            const parent_index = findEntity(entities, parent.entity_id) orelse break :blk true;
            break :blk output[parent_index];
        } else true;
        output[index] = metadata.effectiveEnabled(parent_enabled, entities[index].enabled);
    }
    return output[0..entities.len];
}

pub fn lifecycleOrder(
    evaluation_order: []const usize,
    enabling: bool,
    output: []usize,
) error{ScratchTooSmall}![]const usize {
    if (output.len < evaluation_order.len) return error.ScratchTooSmall;
    if (enabling) {
        @memcpy(output[0..evaluation_order.len], evaluation_order);
    } else {
        for (evaluation_order, 0..) |_, index| output[index] = evaluation_order[evaluation_order.len - 1 - index];
    }
    return output[0..evaluation_order.len];
}

fn readyDepth(
    candidate: entity.EntityInstanceDefinition,
    entities: []const entity.EntityInstanceDefinition,
    external_parent_ids: []const foundation.identity.EntityId,
    depth_scratch: []const u8,
) HierarchyError!?usize {
    const parent = candidate.parent orelse return 1;
    if (parent.requirement != .required) return error.OptionalParent;
    if (parent.entity_id.eql(candidate.entity_id)) return error.SelfParent;
    if (findEntity(entities, parent.entity_id)) |parent_index| {
        if (depth_scratch[parent_index] == 0) return null;
        return @as(usize, depth_scratch[parent_index]) + 1;
    }
    for (external_parent_ids) |external| if (external.eql(parent.entity_id)) return 1;
    return error.MissingParent;
}

fn rejectDuplicateIds(entities: []const entity.EntityInstanceDefinition) HierarchyError!void {
    for (entities, 0..) |candidate, index| {
        for (entities[0..index]) |previous| if (candidate.entity_id.eql(previous.entity_id)) return error.DuplicateEntityId;
    }
}

fn findEntity(entities: []const entity.EntityInstanceDefinition, id: foundation.identity.EntityId) ?usize {
    for (entities, 0..) |candidate, index| if (candidate.entity_id.eql(id)) return index;
    return null;
}
