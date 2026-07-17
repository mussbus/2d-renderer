const std = @import("std");
const math = @import("math");
const fault_injection = @import("fault_injection");

pub const maximum_bones: usize = 64;
pub const maximum_sockets: usize = 16;
pub const no_parent: u16 = std.math.maxInt(u16);
pub const maximum_debug_name_bytes: usize = 31;

pub const BoneSemantic = enum(u8) {
    root,
    pelvis,
    torso,
    head,
    left_upper_arm,
    left_forearm,
    left_hand,
    right_upper_arm,
    right_forearm,
    right_hand,
    left_thigh,
    left_shin,
    left_foot,
    right_thigh,
    right_shin,
    right_foot,
};

pub const SocketSemantic = enum(u8) {
    left_hand,
    right_hand,
    left_foot,
    right_foot,
};

pub const bone_semantic_count: usize = 16;
pub const socket_semantic_count: usize = 4;

comptime {
    if (std.enums.values(BoneSemantic).len != bone_semantic_count) @compileError("BoneSemantic lookup size mismatch");
    if (std.enums.values(SocketSemantic).len != socket_semantic_count) @compileError("SocketSemantic lookup size mismatch");
}

pub const DebugName = extern struct {
    length: u8,
    bytes: [maximum_debug_name_bytes]u8,

    pub fn init(text: []const u8) !DebugName {
        if (text.len == 0) return error.EmptyDebugName;
        if (text.len > maximum_debug_name_bytes) return error.DebugNameTooLong;
        var result = DebugName{ .length = @intCast(text.len), .bytes = [_]u8{0} ** maximum_debug_name_bytes };
        @memcpy(result.bytes[0..text.len], text);
        return result;
    }

    pub fn slice(name: *const DebugName) []const u8 {
        return name.bytes[0..name.length];
    }

    pub fn eql(left: *const DebugName, right: *const DebugName) bool {
        return std.mem.eql(u8, left.slice(), right.slice());
    }
};

pub const BoneDefinitionInput = struct {
    debug_name: []const u8,
    parent_index: ?u16,
    rest_local: math.Transform2D,
    semantic: u8,
};

pub const SocketDefinitionInput = struct {
    debug_name: []const u8,
    parent_bone: u16,
    local_to_bone: math.Transform2D,
    semantic: u8,
};

pub const BoneDefinition = struct {
    id: u16,
    debug_name: DebugName,
    parent_index: u16,
    rest_local: math.Transform2D,
    semantic: BoneSemantic,
};

pub const SocketDefinition = struct {
    id: u16,
    debug_name: DebugName,
    parent_bone: u16,
    local_to_bone: math.Transform2D,
    semantic: SocketSemantic,
};

pub const SkeletonDefinition = struct {
    allocator: std.mem.Allocator,
    bones: []const BoneDefinition,
    sockets: []const SocketDefinition,
    evaluation_order: []const u16,
    bone_semantic_indices: [bone_semantic_count]?u16,
    socket_semantic_indices: [socket_semantic_count]?u16,
    root_index: u16,

    pub fn initHumanoid(
        allocator: std.mem.Allocator,
        bone_inputs: []const BoneDefinitionInput,
        socket_inputs: []const SocketDefinitionInput,
        injector: ?fault_injection.Injector,
    ) !SkeletonDefinition {
        if (bone_inputs.len == 0) return error.ZeroBoneDefinition;
        if (bone_inputs.len > maximum_bones) return error.SupportedCountOverflow;
        if (socket_inputs.len > maximum_sockets) return error.SupportedCountOverflow;

        const bones = allocator.alloc(BoneDefinition, bone_inputs.len) catch return error.AllocationFailure;
        errdefer allocator.free(bones);
        const evaluation_order = allocator.alloc(u16, bone_inputs.len) catch return error.AllocationFailure;
        errdefer allocator.free(evaluation_order);
        try after(injector, .skeleton_definition_allocation);

        var bone_lookup = [_]?u16{null} ** bone_semantic_count;
        var root_index: ?u16 = null;
        for (bone_inputs, 0..) |input, index| {
            if (input.semantic >= bone_semantic_count) {
                std.log.warn("skeleton bone validation: bone={d} name={s} semantic={d} is invalid", .{ index, input.debug_name, input.semantic });
                return error.InvalidSemantic;
            }
            const semantic: BoneSemantic = @enumFromInt(input.semantic);
            if (bone_lookup[input.semantic] != null) {
                std.log.warn("skeleton bone validation: duplicate semantic={s} at bone={d} name={s}", .{ @tagName(semantic), index, input.debug_name });
                return error.DuplicateSemantic;
            }
            if (!input.rest_local.isFinite()) {
                std.log.warn("skeleton bone validation: non-finite rest transform at bone={d} name={s}", .{ index, input.debug_name });
                return error.NonFiniteTransform;
            }
            const parent = input.parent_index orelse no_parent;
            if (parent != no_parent and parent >= bone_inputs.len) {
                std.log.warn("skeleton bone validation: bone={d} name={s} parent={d} bone_count={d}", .{ index, input.debug_name, parent, bone_inputs.len });
                return error.InvalidParentIndex;
            }
            if (parent == index) {
                std.log.warn("skeleton bone validation: self-parent bone={d} name={s}", .{ index, input.debug_name });
                return error.SelfParent;
            }
            if (parent == no_parent) {
                if (root_index != null) {
                    std.log.warn("skeleton bone validation: multiple roots first={d} second={d} name={s}", .{ root_index.?, index, input.debug_name });
                    return error.MultipleRoots;
                }
                root_index = @intCast(index);
            }

            const name = DebugName.init(input.debug_name) catch |err| {
                std.log.warn("skeleton bone validation: bone={d} invalid name length={d}", .{ index, input.debug_name.len });
                return err;
            };
            for (bones[0..index]) |*existing| {
                if (name.eql(&existing.debug_name)) {
                    std.log.warn("skeleton bone validation: duplicate name={s} bone={d}", .{ input.debug_name, index });
                    return error.DuplicateDebugName;
                }
            }
            bones[index] = .{
                .id = @intCast(index),
                .debug_name = name,
                .parent_index = parent,
                .rest_local = input.rest_local,
                .semantic = semantic,
            };
            bone_lookup[input.semantic] = @intCast(index);
        }

        if (root_index == null) return error.MissingRoot;
        for (bone_lookup, 0..) |index, semantic| {
            if (index == null) {
                std.log.warn("skeleton bone validation: missing required semantic={d}", .{semantic});
                return error.MissingRequiredSemantic;
            }
        }
        if (bone_lookup[@intFromEnum(BoneSemantic.root)].? != root_index.?) return error.RootSemanticMismatch;

        var resolved = [_]bool{false} ** maximum_bones;
        var resolved_count: usize = 0;
        while (resolved_count < bones.len) {
            var progress = false;
            for (bones, 0..) |bone_definition, index| {
                if (resolved[index]) continue;
                if (bone_definition.parent_index == no_parent or resolved[bone_definition.parent_index]) {
                    resolved[index] = true;
                    evaluation_order[resolved_count] = @intCast(index);
                    resolved_count += 1;
                    progress = true;
                }
            }
            if (!progress) {
                for (bones, 0..) |bone_definition, index| {
                    if (!resolved[index]) {
                        std.log.warn("skeleton hierarchy cycle: unresolved bone={d} name={s} parent={d}", .{ index, bone_definition.debug_name.slice(), bone_definition.parent_index });
                        break;
                    }
                }
                return error.HierarchyCycle;
            }
        }

        const sockets = allocator.alloc(SocketDefinition, socket_inputs.len) catch return error.AllocationFailure;
        errdefer allocator.free(sockets);
        try after(injector, .socket_definition_allocation);
        var socket_lookup = [_]?u16{null} ** socket_semantic_count;
        for (socket_inputs, 0..) |input, index| {
            if (input.semantic >= socket_semantic_count) {
                std.log.warn("skeleton socket validation: socket={d} name={s} semantic={d} is invalid", .{ index, input.debug_name, input.semantic });
                return error.InvalidSemantic;
            }
            const semantic: SocketSemantic = @enumFromInt(input.semantic);
            if (socket_lookup[input.semantic] != null) {
                std.log.warn("skeleton socket validation: duplicate semantic={s} socket={d} name={s}", .{ @tagName(semantic), index, input.debug_name });
                return error.DuplicateSocket;
            }
            if (input.parent_bone >= bones.len) {
                std.log.warn("skeleton socket validation: socket={d} name={s} parent={d} bone_count={d}", .{ index, input.debug_name, input.parent_bone, bones.len });
                return error.InvalidSocketParent;
            }
            if (!input.local_to_bone.isFinite()) return error.NonFiniteTransform;
            const name = DebugName.init(input.debug_name) catch |err| return err;
            for (sockets[0..index]) |*existing| {
                if (name.eql(&existing.debug_name)) return error.DuplicateSocket;
            }
            sockets[index] = .{
                .id = @intCast(index),
                .debug_name = name,
                .parent_bone = input.parent_bone,
                .local_to_bone = input.local_to_bone,
                .semantic = semantic,
            };
            socket_lookup[input.semantic] = @intCast(index);
        }
        for (socket_lookup, 0..) |index, semantic| {
            if (index == null) {
                std.log.warn("skeleton socket validation: missing required semantic={d}", .{semantic});
                return error.MissingRequiredSocket;
            }
        }

        return .{
            .allocator = allocator,
            .bones = bones,
            .sockets = sockets,
            .evaluation_order = evaluation_order,
            .bone_semantic_indices = bone_lookup,
            .socket_semantic_indices = socket_lookup,
            .root_index = root_index.?,
        };
    }

    pub fn deinit(definition: *SkeletonDefinition) void {
        definition.allocator.free(definition.sockets);
        definition.allocator.free(definition.evaluation_order);
        definition.allocator.free(definition.bones);
        definition.* = undefined;
    }

    pub fn boneCount(definition: SkeletonDefinition) usize {
        return definition.bones.len;
    }

    pub fn socketCount(definition: SkeletonDefinition) usize {
        return definition.sockets.len;
    }

    pub fn bone(definition: SkeletonDefinition, index: u16) !*const BoneDefinition {
        if (index >= definition.bones.len) return error.InvalidBoneIndex;
        return &definition.bones[index];
    }

    pub fn socket(definition: SkeletonDefinition, index: u16) !*const SocketDefinition {
        if (index >= definition.sockets.len) return error.InvalidSocketIndex;
        return &definition.sockets[index];
    }

    pub fn boneIndex(definition: SkeletonDefinition, semantic: BoneSemantic) !u16 {
        return definition.bone_semantic_indices[@intFromEnum(semantic)] orelse error.MissingRequiredSemantic;
    }

    pub fn socketIndex(definition: SkeletonDefinition, semantic: SocketSemantic) !u16 {
        return definition.socket_semantic_indices[@intFromEnum(semantic)] orelse error.InvalidSocketLookup;
    }

    pub fn compatibilityToken(definition: SkeletonDefinition) usize {
        return @intFromPtr(definition.bones.ptr);
    }
};

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
