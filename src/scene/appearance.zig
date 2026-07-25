const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const pose = @import("pose");
const fault_injection = @import("fault_injection");

pub const maximum_attachment_points: usize = 64;
pub const maximum_visual_attachments: usize = 128;
pub const maximum_body_regions: usize = 64;
pub const maximum_visual_groups: usize = 32;
pub const maximum_rig_modules: usize = 8;
pub const maximum_joints_per_module: usize = 16;
pub const maximum_sockets_per_module: usize = 16;
pub const maximum_total_module_joints: usize = maximum_rig_modules * maximum_joints_per_module;
pub const maximum_total_module_sockets: usize = maximum_rig_modules * maximum_sockets_per_module;
pub const maximum_hierarchy_depth: u8 = 16;
pub const no_index: u16 = std.math.maxInt(u16);

pub const AttachmentPointId = enum(u16) {
    _,

    pub fn index(id: AttachmentPointId) usize {
        return @intFromEnum(id);
    }
};

pub const VisualAttachmentId = enum(u16) {
    _,

    pub fn index(id: VisualAttachmentId) usize {
        return @intFromEnum(id);
    }
};

pub const BodyRegionId = enum(u16) {
    _,

    pub fn index(id: BodyRegionId) usize {
        return @intFromEnum(id);
    }
};

pub const VisualGroupId = enum(u16) {
    _,

    pub fn index(id: VisualGroupId) usize {
        return @intFromEnum(id);
    }
};

pub const RigModuleId = enum(u16) {
    _,

    pub fn index(id: RigModuleId) usize {
        return @intFromEnum(id);
    }
};

pub const ModuleJointId = enum(u16) {
    _,

    pub fn index(id: ModuleJointId) usize {
        return @intFromEnum(id);
    }
};

pub const ModuleSocketId = enum(u16) {
    _,

    pub fn index(id: ModuleSocketId) usize {
        return @intFromEnum(id);
    }
};

pub const AttachmentPointParentInput = union(enum) {
    canonical_bone: u16,
    attachment_point: []const u8,
};

pub const AttachmentPointParent = union(enum) {
    canonical_bone: u16,
    attachment_point: AttachmentPointId,
};

pub const ModuleMemberInput = struct {
    module_name: []const u8,
    member_name: []const u8,
};

pub const TransformSourceInput = union(enum) {
    canonical_bone: u16,
    attachment_point: []const u8,
    module_joint: ModuleMemberInput,
    module_socket: ModuleMemberInput,
    visual_attachment: []const u8,
};

pub const TransformSource = union(enum) {
    canonical_bone: u16,
    attachment_point: AttachmentPointId,
    module_joint: u16,
    module_socket: u16,
    visual_attachment: VisualAttachmentId,
};

pub const AttachmentPointInput = struct {
    debug_name: []const u8,
    parent: AttachmentPointParentInput,
    local_to_parent: math.Transform2D,
};

pub const BodyRegionInput = struct {
    debug_name: []const u8,
};

pub const VisualGroupInput = struct {
    debug_name: []const u8,
};

pub const ModuleJointInput = struct {
    debug_name: []const u8,
    parent_joint: ?[]const u8,
    rest_local: math.Transform2D,
};

pub const ModuleSocketInput = struct {
    debug_name: []const u8,
    parent_joint: ?[]const u8,
    local_to_parent: math.Transform2D,
};

pub const RigModuleInput = struct {
    debug_name: []const u8,
    parent_attachment_point: []const u8,
    local_to_attachment_point: math.Transform2D,
    joints: []const ModuleJointInput,
    sockets: []const ModuleSocketInput,
};

pub const VisualAttachmentInput = struct {
    debug_name: []const u8,
    canonical_semantic: ?u8,
    transform_source: TransformSourceInput,
    local_to_source: math.Transform2D,
    body_region: []const u8,
    visual_group: []const u8,
    sprite_size: math.Vec2,
    pivot: [2]f32,
    uv_rect: [4]f32,
    tint: [4]f32,
    texture_page: u32,
    body_part_layer: u16,
};

pub const DefinitionInputs = struct {
    attachment_points: []const AttachmentPointInput,
    body_regions: []const BodyRegionInput,
    visual_groups: []const VisualGroupInput,
    rig_modules: []const RigModuleInput,
    visuals: []const VisualAttachmentInput,
};

pub const AttachmentPoint = struct {
    id: AttachmentPointId,
    debug_name: skeleton.DebugName,
    parent: AttachmentPointParent,
    local_to_parent: math.Transform2D,
    hierarchy_depth: u8,
};

pub const BodyRegion = struct {
    id: BodyRegionId,
    debug_name: skeleton.DebugName,
};

pub const VisualGroup = struct {
    id: VisualGroupId,
    debug_name: skeleton.DebugName,
};

pub const RigModule = struct {
    id: RigModuleId,
    debug_name: skeleton.DebugName,
    parent_attachment_point: AttachmentPointId,
    local_to_attachment_point: math.Transform2D,
    joint_start: u16,
    joint_count: u16,
    socket_start: u16,
    socket_count: u16,
};

pub const ModuleJoint = struct {
    id: ModuleJointId,
    module_id: RigModuleId,
    debug_name: skeleton.DebugName,
    parent_joint_global: u16,
    rest_local: math.Transform2D,
};

pub const ModuleSocket = struct {
    id: ModuleSocketId,
    module_id: RigModuleId,
    debug_name: skeleton.DebugName,
    parent_joint_global: u16,
    local_to_parent: math.Transform2D,
};

pub const VisualAttachment = struct {
    id: VisualAttachmentId,
    debug_name: skeleton.DebugName,
    canonical_semantic: ?u8,
    transform_source: TransformSource,
    local_to_source: math.Transform2D,
    body_region: BodyRegionId,
    visual_group: VisualGroupId,
    hierarchy_depth: u8,
    sprite_size: math.Vec2,
    pivot: [2]f32,
    uv_rect: [4]f32,
    tint: [4]f32,
    texture_page: u32,
    body_part_layer: u16,
};

pub const DefinitionView = struct {
    attachment_points: []const AttachmentPoint,
    attachment_point_evaluation_order: []const u16,
    body_regions: []const BodyRegion,
    visual_groups: []const VisualGroup,
    rig_modules: []const RigModule,
    module_joints: []const ModuleJoint,
    module_joint_evaluation_order: []const u16,
    module_sockets: []const ModuleSocket,
    visuals: []const VisualAttachment,
    visual_evaluation_order: []const u16,
    owner_token: usize,
};

pub const Definition = struct {
    allocator: std.mem.Allocator,
    attachment_points: []const AttachmentPoint,
    attachment_point_evaluation_order: []const u16,
    body_regions: []const BodyRegion,
    visual_groups: []const VisualGroup,
    rig_modules: []const RigModule,
    module_joints: []const ModuleJoint,
    module_joint_evaluation_order: []const u16,
    module_sockets: []const ModuleSocket,
    visuals: []const VisualAttachment,
    visual_evaluation_order: []const u16,

    pub fn init(
        allocator: std.mem.Allocator,
        canonical_skeleton: *const skeleton.SkeletonDefinition,
        canonical_semantic_count: usize,
        inputs: DefinitionInputs,
        injector: ?fault_injection.Injector,
    ) !Definition {
        if (inputs.attachment_points.len == 0) return error.ZeroAttachmentPoints;
        if (inputs.attachment_points.len > maximum_attachment_points or
            inputs.body_regions.len > maximum_body_regions or
            inputs.visual_groups.len > maximum_visual_groups or
            inputs.rig_modules.len > maximum_rig_modules or
            inputs.visuals.len > maximum_visual_attachments or
            canonical_semantic_count > 256)
        {
            return error.SupportedCountOverflow;
        }

        const attachment_points = allocator.alloc(AttachmentPoint, inputs.attachment_points.len) catch return error.AllocationFailure;
        errdefer allocator.free(attachment_points);
        const attachment_point_evaluation_order = allocator.alloc(u16, inputs.attachment_points.len) catch return error.AllocationFailure;
        errdefer allocator.free(attachment_point_evaluation_order);
        try after(injector, .attachment_point_allocation);

        for (inputs.attachment_points, 0..) |input, index| {
            if (!input.local_to_parent.isFinite()) return error.NonFiniteTransform;
            const name = try skeleton.DebugName.init(input.debug_name);
            for (attachment_points[0..index]) |*existing| {
                if (name.eql(&existing.debug_name)) return error.DuplicateAttachmentPointId;
            }
            attachment_points[index] = .{
                .id = @enumFromInt(index),
                .debug_name = name,
                .parent = .{ .canonical_bone = 0 },
                .local_to_parent = input.local_to_parent,
                .hierarchy_depth = 0,
            };
        }
        for (inputs.attachment_points, 0..) |input, index| {
            attachment_points[index].parent = switch (input.parent) {
                .canonical_bone => |bone_index| parent: {
                    if (bone_index >= canonical_skeleton.boneCount()) return error.InvalidAttachmentPointParent;
                    break :parent .{ .canonical_bone = bone_index };
                },
                .attachment_point => |name| .{ .attachment_point = try findAttachmentPoint(attachment_points, name) },
            };
        }
        try resolveAttachmentPointHierarchy(attachment_points, attachment_point_evaluation_order);

        const body_regions = allocator.alloc(BodyRegion, inputs.body_regions.len) catch return error.AllocationFailure;
        errdefer allocator.free(body_regions);
        try after(injector, .body_region_allocation);
        for (inputs.body_regions, 0..) |input, index| {
            const name = try skeleton.DebugName.init(input.debug_name);
            for (body_regions[0..index]) |*existing| {
                if (name.eql(&existing.debug_name)) return error.DuplicateBodyRegionId;
            }
            body_regions[index] = .{ .id = @enumFromInt(index), .debug_name = name };
        }

        const visual_groups = allocator.alloc(VisualGroup, inputs.visual_groups.len) catch return error.AllocationFailure;
        errdefer allocator.free(visual_groups);
        try after(injector, .visual_group_allocation);
        for (inputs.visual_groups, 0..) |input, index| {
            const name = try skeleton.DebugName.init(input.debug_name);
            for (visual_groups[0..index]) |*existing| {
                if (name.eql(&existing.debug_name)) return error.DuplicateVisualGroupId;
            }
            visual_groups[index] = .{ .id = @enumFromInt(index), .debug_name = name };
        }

        var total_joints: usize = 0;
        var total_sockets: usize = 0;
        for (inputs.rig_modules) |input| {
            if (input.joints.len > maximum_joints_per_module or input.sockets.len > maximum_sockets_per_module) {
                return error.SupportedCountOverflow;
            }
            total_joints = std.math.add(usize, total_joints, input.joints.len) catch return error.SupportedCountOverflow;
            total_sockets = std.math.add(usize, total_sockets, input.sockets.len) catch return error.SupportedCountOverflow;
        }
        if (total_joints > maximum_total_module_joints or total_sockets > maximum_total_module_sockets) {
            return error.SupportedCountOverflow;
        }

        const rig_modules = allocator.alloc(RigModule, inputs.rig_modules.len) catch return error.AllocationFailure;
        errdefer allocator.free(rig_modules);
        const module_joints = allocator.alloc(ModuleJoint, total_joints) catch return error.AllocationFailure;
        errdefer allocator.free(module_joints);
        const module_joint_evaluation_order = allocator.alloc(u16, total_joints) catch return error.AllocationFailure;
        errdefer allocator.free(module_joint_evaluation_order);
        const module_sockets = allocator.alloc(ModuleSocket, total_sockets) catch return error.AllocationFailure;
        errdefer allocator.free(module_sockets);
        try after(injector, .rig_module_allocation);

        var joint_cursor: usize = 0;
        var socket_cursor: usize = 0;
        for (inputs.rig_modules, 0..) |input, module_index| {
            if (!input.local_to_attachment_point.isFinite()) return error.NonFiniteTransform;
            const name = try skeleton.DebugName.init(input.debug_name);
            for (rig_modules[0..module_index]) |*existing| {
                if (name.eql(&existing.debug_name)) return error.DuplicateRigModuleId;
            }
            const module_id: RigModuleId = @enumFromInt(module_index);
            const joint_start = joint_cursor;
            const socket_start = socket_cursor;
            rig_modules[module_index] = .{
                .id = module_id,
                .debug_name = name,
                .parent_attachment_point = try findAttachmentPoint(attachment_points, input.parent_attachment_point),
                .local_to_attachment_point = input.local_to_attachment_point,
                .joint_start = @intCast(joint_start),
                .joint_count = @intCast(input.joints.len),
                .socket_start = @intCast(socket_start),
                .socket_count = @intCast(input.sockets.len),
            };

            for (input.joints, 0..) |joint_input, local_index| {
                if (!joint_input.rest_local.isFinite()) return error.NonFiniteTransform;
                const joint_name = try skeleton.DebugName.init(joint_input.debug_name);
                for (module_joints[joint_start..joint_cursor]) |*existing| {
                    if (joint_name.eql(&existing.debug_name)) return error.DuplicateModuleJointId;
                }
                module_joints[joint_cursor] = .{
                    .id = @enumFromInt(local_index),
                    .module_id = module_id,
                    .debug_name = joint_name,
                    .parent_joint_global = no_index,
                    .rest_local = joint_input.rest_local,
                };
                joint_cursor += 1;
            }
            for (input.joints, 0..) |joint_input, local_index| {
                if (joint_input.parent_joint) |parent_name| {
                    const parent_local = try findModuleJointLocal(module_joints[joint_start..joint_cursor], parent_name);
                    if (parent_local.index() == local_index) return error.ModuleJointSelfParent;
                    module_joints[joint_start + local_index].parent_joint_global = @intCast(joint_start + parent_local.index());
                }
            }

            for (input.sockets, 0..) |socket_input, local_index| {
                if (!socket_input.local_to_parent.isFinite()) return error.NonFiniteTransform;
                const socket_name = try skeleton.DebugName.init(socket_input.debug_name);
                for (module_sockets[socket_start..socket_cursor]) |*existing| {
                    if (socket_name.eql(&existing.debug_name)) return error.DuplicateModuleSocketId;
                }
                const parent_joint_global = if (socket_input.parent_joint) |parent_name|
                    @as(u16, @intCast(joint_start + (try findModuleJointLocal(module_joints[joint_start..joint_cursor], parent_name)).index()))
                else
                    no_index;
                module_sockets[socket_cursor] = .{
                    .id = @enumFromInt(local_index),
                    .module_id = module_id,
                    .debug_name = socket_name,
                    .parent_joint_global = parent_joint_global,
                    .local_to_parent = socket_input.local_to_parent,
                };
                socket_cursor += 1;
            }
        }
        try resolveModuleJointHierarchy(rig_modules, module_joints, module_joint_evaluation_order);

        const visuals = allocator.alloc(VisualAttachment, inputs.visuals.len) catch return error.AllocationFailure;
        errdefer allocator.free(visuals);
        const visual_evaluation_order = allocator.alloc(u16, inputs.visuals.len) catch return error.AllocationFailure;
        errdefer allocator.free(visual_evaluation_order);
        try after(injector, .visual_attachment_allocation);

        var semantic_seen = [_]bool{false} ** 256;
        for (inputs.visuals, 0..) |input, index| {
            if (!input.local_to_source.isFinite() or !input.sprite_size.isFinite() or input.sprite_size.x <= 0 or input.sprite_size.y <= 0) {
                return error.NonFiniteTransform;
            }
            const name = try skeleton.DebugName.init(input.debug_name);
            for (visuals[0..index]) |*existing| {
                if (name.eql(&existing.debug_name)) return error.DuplicateVisualAttachmentId;
            }
            if (input.canonical_semantic) |semantic| {
                if (semantic >= canonical_semantic_count) return error.InvalidCanonicalVisualSemantic;
                if (semantic_seen[semantic]) return error.DuplicateCanonicalVisualSemantic;
                semantic_seen[semantic] = true;
            }
            visuals[index] = .{
                .id = @enumFromInt(index),
                .debug_name = name,
                .canonical_semantic = input.canonical_semantic,
                .transform_source = .{ .canonical_bone = 0 },
                .local_to_source = input.local_to_source,
                .body_region = try findBodyRegion(body_regions, input.body_region),
                .visual_group = try findVisualGroup(visual_groups, input.visual_group),
                .hierarchy_depth = 0,
                .sprite_size = input.sprite_size,
                .pivot = input.pivot,
                .uv_rect = input.uv_rect,
                .tint = input.tint,
                .texture_page = input.texture_page,
                .body_part_layer = input.body_part_layer,
            };
        }
        for (inputs.visuals, 0..) |input, index| {
            visuals[index].transform_source = try resolveTransformSource(
                canonical_skeleton,
                attachment_points,
                rig_modules,
                module_joints,
                module_sockets,
                visuals,
                input.transform_source,
            );
        }
        try resolveVisualHierarchy(visuals, visual_evaluation_order);

        return .{
            .allocator = allocator,
            .attachment_points = attachment_points,
            .attachment_point_evaluation_order = attachment_point_evaluation_order,
            .body_regions = body_regions,
            .visual_groups = visual_groups,
            .rig_modules = rig_modules,
            .module_joints = module_joints,
            .module_joint_evaluation_order = module_joint_evaluation_order,
            .module_sockets = module_sockets,
            .visuals = visuals,
            .visual_evaluation_order = visual_evaluation_order,
        };
    }

    pub fn deinit(definition: *Definition) void {
        definition.allocator.free(definition.visual_evaluation_order);
        definition.allocator.free(definition.visuals);
        definition.allocator.free(definition.module_sockets);
        definition.allocator.free(definition.module_joint_evaluation_order);
        definition.allocator.free(definition.module_joints);
        definition.allocator.free(definition.rig_modules);
        definition.allocator.free(definition.visual_groups);
        definition.allocator.free(definition.body_regions);
        definition.allocator.free(definition.attachment_point_evaluation_order);
        definition.allocator.free(definition.attachment_points);
        definition.* = undefined;
    }

    pub fn view(definition: *const Definition) DefinitionView {
        return .{
            .attachment_points = definition.attachment_points,
            .attachment_point_evaluation_order = definition.attachment_point_evaluation_order,
            .body_regions = definition.body_regions,
            .visual_groups = definition.visual_groups,
            .rig_modules = definition.rig_modules,
            .module_joints = definition.module_joints,
            .module_joint_evaluation_order = definition.module_joint_evaluation_order,
            .module_sockets = definition.module_sockets,
            .visuals = definition.visuals,
            .visual_evaluation_order = definition.visual_evaluation_order,
            .owner_token = definition.compatibilityToken(),
        };
    }

    pub fn compatibilityToken(definition: *const Definition) usize {
        return @intFromPtr(definition.attachment_points.ptr);
    }

    pub fn attachmentPointId(definition: *const Definition, name: []const u8) !AttachmentPointId {
        return findAttachmentPoint(definition.attachment_points, name);
    }

    pub fn bodyRegionId(definition: *const Definition, name: []const u8) !BodyRegionId {
        return findBodyRegion(definition.body_regions, name);
    }

    pub fn visualGroupId(definition: *const Definition, name: []const u8) !VisualGroupId {
        return findVisualGroup(definition.visual_groups, name);
    }

    pub fn visualId(definition: *const Definition, name: []const u8) !VisualAttachmentId {
        return findVisual(definition.visuals, name);
    }

    pub fn rigModuleId(definition: *const Definition, name: []const u8) !RigModuleId {
        return findRigModule(definition.rig_modules, name);
    }

    pub fn moduleJointId(definition: *const Definition, module_id: RigModuleId, name: []const u8) !ModuleJointId {
        const module = try moduleById(definition.view(), module_id);
        return findModuleJointLocal(definition.module_joints[module.joint_start .. module.joint_start + module.joint_count], name);
    }

    pub fn moduleSocketId(definition: *const Definition, module_id: RigModuleId, name: []const u8) !ModuleSocketId {
        const module = try moduleById(definition.view(), module_id);
        return findModuleSocketLocal(definition.module_sockets[module.socket_start .. module.socket_start + module.socket_count], name);
    }
};

pub const VisualRuntimeState = struct {
    visible: bool = true,
    local_deformation: math.Transform2D = math.Transform2D.identity(),
};

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    definition_token: usize,
    attachment_point_world: []math.Mat3,
    module_joint_local: []math.Transform2D,
    module_joint_world: []math.Mat3,
    module_socket_world: []math.Mat3,
    visual_states: []VisualRuntimeState,
    visual_world: []math.Mat3,

    pub fn init(
        allocator: std.mem.Allocator,
        definition: DefinitionView,
        injector: ?fault_injection.Injector,
    ) !Runtime {
        const attachment_point_world = allocator.alloc(math.Mat3, definition.attachment_points.len) catch return error.AllocationFailure;
        errdefer allocator.free(attachment_point_world);
        const module_joint_local = allocator.alloc(math.Transform2D, definition.module_joints.len) catch return error.AllocationFailure;
        errdefer allocator.free(module_joint_local);
        const module_joint_world = allocator.alloc(math.Mat3, definition.module_joints.len) catch return error.AllocationFailure;
        errdefer allocator.free(module_joint_world);
        const module_socket_world = allocator.alloc(math.Mat3, definition.module_sockets.len) catch return error.AllocationFailure;
        errdefer allocator.free(module_socket_world);
        const visual_states = allocator.alloc(VisualRuntimeState, definition.visuals.len) catch return error.AllocationFailure;
        errdefer allocator.free(visual_states);
        const visual_world = allocator.alloc(math.Mat3, definition.visuals.len) catch return error.AllocationFailure;
        errdefer allocator.free(visual_world);
        try after(injector, .appearance_runtime_allocation);

        var runtime = Runtime{
            .allocator = allocator,
            .definition_token = definition.owner_token,
            .attachment_point_world = attachment_point_world,
            .module_joint_local = module_joint_local,
            .module_joint_world = module_joint_world,
            .module_socket_world = module_socket_world,
            .visual_states = visual_states,
            .visual_world = visual_world,
        };
        try runtime.reset(definition);
        return runtime;
    }

    pub fn deinit(runtime: *Runtime) void {
        runtime.allocator.free(runtime.visual_world);
        runtime.allocator.free(runtime.visual_states);
        runtime.allocator.free(runtime.module_socket_world);
        runtime.allocator.free(runtime.module_joint_world);
        runtime.allocator.free(runtime.module_joint_local);
        runtime.allocator.free(runtime.attachment_point_world);
        runtime.* = undefined;
    }

    pub fn validateCompatibility(runtime: Runtime, definition: DefinitionView) !void {
        if (runtime.definition_token != definition.owner_token or
            runtime.attachment_point_world.len != definition.attachment_points.len or
            runtime.module_joint_local.len != definition.module_joints.len or
            runtime.module_joint_world.len != definition.module_joints.len or
            runtime.module_socket_world.len != definition.module_sockets.len or
            runtime.visual_states.len != definition.visuals.len or
            runtime.visual_world.len != definition.visuals.len)
        {
            return error.AppearanceDefinitionMismatch;
        }
    }

    pub fn reset(runtime: *Runtime, definition: DefinitionView) !void {
        try runtime.validateCompatibility(definition);
        for (definition.module_joints, 0..) |joint, index| runtime.module_joint_local[index] = joint.rest_local;
        for (runtime.attachment_point_world) |*world| world.* = math.Mat3.identity();
        for (runtime.module_joint_world) |*world| world.* = math.Mat3.identity();
        for (runtime.module_socket_world) |*world| world.* = math.Mat3.identity();
        for (runtime.visual_states) |*state| state.* = .{};
        for (runtime.visual_world) |*world| world.* = math.Mat3.identity();
    }

    pub fn evaluate(
        runtime: *Runtime,
        definition: DefinitionView,
        canonical_skeleton: *const skeleton.SkeletonDefinition,
        canonical_pose: *const pose.Pose,
    ) !void {
        try runtime.validateCompatibility(definition);
        try canonical_pose.validateCompatibility(canonical_skeleton);

        for (definition.attachment_point_evaluation_order) |raw_index| {
            const point = definition.attachment_points[raw_index];
            const parent_world = switch (point.parent) {
                .canonical_bone => |bone_index| try canonical_pose.worldForBone(canonical_skeleton, bone_index),
                .attachment_point => |parent_id| runtime.attachment_point_world[parent_id.index()],
            };
            runtime.attachment_point_world[point.id.index()] = parent_world.mul(try point.local_to_parent.localToParent());
        }

        for (definition.module_joint_evaluation_order) |global_index| {
            const joint = definition.module_joints[global_index];
            const parent_world = if (joint.parent_joint_global == no_index)
                try runtime.moduleOrigin(definition, joint.module_id)
            else
                runtime.module_joint_world[joint.parent_joint_global];
            runtime.module_joint_world[global_index] = parent_world.mul(try runtime.module_joint_local[global_index].localToParent());
        }

        for (definition.module_sockets, 0..) |module_socket, global_index| {
            const parent_world = if (module_socket.parent_joint_global == no_index)
                try runtime.moduleOrigin(definition, module_socket.module_id)
            else
                runtime.module_joint_world[module_socket.parent_joint_global];
            runtime.module_socket_world[global_index] = parent_world.mul(try module_socket.local_to_parent.localToParent());
        }

        for (definition.visual_evaluation_order) |raw_index| {
            const visual = definition.visuals[raw_index];
            const source_world = switch (visual.transform_source) {
                .canonical_bone => |bone_index| try canonical_pose.worldForBone(canonical_skeleton, bone_index),
                .attachment_point => |point_id| runtime.attachment_point_world[point_id.index()],
                .module_joint => |global_index| runtime.module_joint_world[global_index],
                .module_socket => |global_index| runtime.module_socket_world[global_index],
                .visual_attachment => |parent_id| runtime.visual_world[parent_id.index()],
            };
            runtime.visual_world[visual.id.index()] = source_world
                .mul(try visual.local_to_source.localToParent())
                .mul(try runtime.visual_states[visual.id.index()].local_deformation.localToParent());
        }
    }

    pub fn setVisible(runtime: *Runtime, definition: DefinitionView, id: VisualAttachmentId, visible: bool) !void {
        try runtime.validateCompatibility(definition);
        if (id.index() >= runtime.visual_states.len) return error.InvalidVisualAttachmentId;
        runtime.visual_states[id.index()].visible = visible;
    }

    pub fn isVisible(runtime: Runtime, definition: DefinitionView, id: VisualAttachmentId) !bool {
        try runtime.validateCompatibility(definition);
        if (id.index() >= runtime.visual_states.len) return error.InvalidVisualAttachmentId;
        return runtime.visual_states[id.index()].visible;
    }

    pub fn setVisualDeformation(
        runtime: *Runtime,
        definition: DefinitionView,
        id: VisualAttachmentId,
        deformation: math.Transform2D,
    ) !void {
        try runtime.validateCompatibility(definition);
        if (id.index() >= runtime.visual_states.len) return error.InvalidVisualAttachmentId;
        if (!deformation.isFinite()) return error.NonFiniteTransform;
        runtime.visual_states[id.index()].local_deformation = deformation;
    }

    pub fn setModuleJointLocal(
        runtime: *Runtime,
        definition: DefinitionView,
        module_id: RigModuleId,
        joint_id: ModuleJointId,
        local: math.Transform2D,
    ) !void {
        try runtime.validateCompatibility(definition);
        if (!local.isFinite()) return error.NonFiniteTransform;
        const module = try moduleById(definition, module_id);
        if (joint_id.index() >= module.joint_count) return error.InvalidModuleJointId;
        runtime.module_joint_local[module.joint_start + joint_id.index()] = local;
    }

    pub fn moduleJointLocal(
        runtime: Runtime,
        definition: DefinitionView,
        module_id: RigModuleId,
        joint_id: ModuleJointId,
    ) !math.Transform2D {
        try runtime.validateCompatibility(definition);
        const module = try moduleById(definition, module_id);
        if (joint_id.index() >= module.joint_count) return error.InvalidModuleJointId;
        return runtime.module_joint_local[module.joint_start + joint_id.index()];
    }

    pub fn visualWorld(runtime: Runtime, definition: DefinitionView, id: VisualAttachmentId) !math.Mat3 {
        try runtime.validateCompatibility(definition);
        if (id.index() >= runtime.visual_world.len) return error.InvalidVisualAttachmentId;
        return runtime.visual_world[id.index()];
    }

    pub fn attachmentPointWorld(runtime: Runtime, definition: DefinitionView, id: AttachmentPointId) !math.Mat3 {
        try runtime.validateCompatibility(definition);
        if (id.index() >= runtime.attachment_point_world.len) return error.InvalidAttachmentPointId;
        return runtime.attachment_point_world[id.index()];
    }

    pub fn moduleSocketWorldGlobal(runtime: Runtime, definition: DefinitionView, global_index: u16) !math.Mat3 {
        try runtime.validateCompatibility(definition);
        if (global_index >= runtime.module_socket_world.len) return error.InvalidModuleSocketId;
        return runtime.module_socket_world[global_index];
    }

    fn moduleOrigin(runtime: Runtime, definition: DefinitionView, module_id: RigModuleId) !math.Mat3 {
        const module = try moduleById(definition, module_id);
        return runtime.attachment_point_world[module.parent_attachment_point.index()]
            .mul(try module.local_to_attachment_point.localToParent());
    }
};

fn resolveAttachmentPointHierarchy(points: []AttachmentPoint, evaluation_order: []u16) !void {
    var resolved = [_]bool{false} ** maximum_attachment_points;
    var resolved_count: usize = 0;
    while (resolved_count < points.len) {
        var progress = false;
        for (points, 0..) |*point, index| {
            if (resolved[index]) continue;
            const parent_depth: ?u8 = switch (point.parent) {
                .canonical_bone => 0,
                .attachment_point => |parent_id| if (resolved[parent_id.index()])
                    points[parent_id.index()].hierarchy_depth
                else
                    null,
            };
            if (parent_depth) |depth| {
                const point_depth = std.math.add(u8, depth, 1) catch return error.AttachmentHierarchyTooDeep;
                if (point_depth > maximum_hierarchy_depth) return error.AttachmentHierarchyTooDeep;
                point.hierarchy_depth = point_depth;
                evaluation_order[resolved_count] = @intCast(index);
                resolved[index] = true;
                resolved_count += 1;
                progress = true;
            }
        }
        if (!progress) return error.AttachmentPointCycle;
    }
}

fn resolveModuleJointHierarchy(
    modules: []const RigModule,
    joints: []const ModuleJoint,
    evaluation_order: []u16,
) !void {
    var resolved = [_]bool{false} ** maximum_total_module_joints;
    var order_cursor: usize = 0;
    for (modules) |module| {
        var module_resolved: usize = 0;
        while (module_resolved < module.joint_count) {
            var progress = false;
            for (0..module.joint_count) |local_index| {
                const global_index = module.joint_start + local_index;
                if (resolved[global_index]) continue;
                const parent = joints[global_index].parent_joint_global;
                if (parent == no_index or resolved[parent]) {
                    resolved[global_index] = true;
                    evaluation_order[order_cursor] = @intCast(global_index);
                    order_cursor += 1;
                    module_resolved += 1;
                    progress = true;
                }
            }
            if (!progress) return error.ModuleJointCycle;
        }
    }
}

fn resolveVisualHierarchy(visuals: []VisualAttachment, evaluation_order: []u16) !void {
    var resolved = [_]bool{false} ** maximum_visual_attachments;
    var resolved_count: usize = 0;
    while (resolved_count < visuals.len) {
        var progress = false;
        for (visuals, 0..) |*visual, index| {
            if (resolved[index]) continue;
            const parent_depth: ?u8 = switch (visual.transform_source) {
                .visual_attachment => |parent_id| if (resolved[parent_id.index()])
                    visuals[parent_id.index()].hierarchy_depth
                else
                    null,
                else => 0,
            };
            if (parent_depth) |depth| {
                const visual_depth = std.math.add(u8, depth, 1) catch return error.AttachmentHierarchyTooDeep;
                if (visual_depth > maximum_hierarchy_depth) return error.AttachmentHierarchyTooDeep;
                visual.hierarchy_depth = visual_depth;
                evaluation_order[resolved_count] = @intCast(index);
                resolved[index] = true;
                resolved_count += 1;
                progress = true;
            }
        }
        if (!progress) return error.VisualAttachmentCycle;
    }
}

fn resolveTransformSource(
    canonical_skeleton: *const skeleton.SkeletonDefinition,
    attachment_points: []const AttachmentPoint,
    modules: []const RigModule,
    joints: []const ModuleJoint,
    sockets: []const ModuleSocket,
    visuals: []const VisualAttachment,
    source: TransformSourceInput,
) !TransformSource {
    return switch (source) {
        .canonical_bone => |bone_index| source_value: {
            if (bone_index >= canonical_skeleton.boneCount()) return error.InvalidVisualTransformSource;
            break :source_value .{ .canonical_bone = bone_index };
        },
        .attachment_point => |name| .{ .attachment_point = try findAttachmentPoint(attachment_points, name) },
        .module_joint => |member| .{ .module_joint = try findModuleJointGlobal(modules, joints, member) },
        .module_socket => |member| .{ .module_socket = try findModuleSocketGlobal(modules, sockets, member) },
        .visual_attachment => |name| .{ .visual_attachment = try findVisual(visuals, name) },
    };
}

fn findAttachmentPoint(points: []const AttachmentPoint, name: []const u8) !AttachmentPointId {
    for (points) |*point| {
        if (std.mem.eql(u8, point.debug_name.slice(), name)) return point.id;
    }
    return error.DanglingAttachmentPointReference;
}

fn findBodyRegion(regions: []const BodyRegion, name: []const u8) !BodyRegionId {
    for (regions) |*region| {
        if (std.mem.eql(u8, region.debug_name.slice(), name)) return region.id;
    }
    return error.DanglingBodyRegionReference;
}

fn findVisualGroup(groups: []const VisualGroup, name: []const u8) !VisualGroupId {
    for (groups) |*group| {
        if (std.mem.eql(u8, group.debug_name.slice(), name)) return group.id;
    }
    return error.DanglingVisualGroupReference;
}

fn findVisual(visuals: []const VisualAttachment, name: []const u8) !VisualAttachmentId {
    for (visuals) |*visual| {
        if (std.mem.eql(u8, visual.debug_name.slice(), name)) return visual.id;
    }
    return error.DanglingVisualAttachmentReference;
}

fn findRigModule(modules: []const RigModule, name: []const u8) !RigModuleId {
    for (modules) |*module| {
        if (std.mem.eql(u8, module.debug_name.slice(), name)) return module.id;
    }
    return error.DanglingRigModuleReference;
}

fn findModuleJointLocal(joints: []const ModuleJoint, name: []const u8) !ModuleJointId {
    for (joints) |*joint| {
        if (std.mem.eql(u8, joint.debug_name.slice(), name)) return joint.id;
    }
    return error.DanglingModuleJointReference;
}

fn findModuleSocketLocal(sockets: []const ModuleSocket, name: []const u8) !ModuleSocketId {
    for (sockets) |*module_socket| {
        if (std.mem.eql(u8, module_socket.debug_name.slice(), name)) return module_socket.id;
    }
    return error.DanglingModuleSocketReference;
}

fn findModuleJointGlobal(
    modules: []const RigModule,
    joints: []const ModuleJoint,
    member: ModuleMemberInput,
) !u16 {
    const module_id = try findRigModule(modules, member.module_name);
    const module = modules[module_id.index()];
    const local_id = try findModuleJointLocal(joints[module.joint_start .. module.joint_start + module.joint_count], member.member_name);
    return @intCast(module.joint_start + local_id.index());
}

fn findModuleSocketGlobal(
    modules: []const RigModule,
    sockets: []const ModuleSocket,
    member: ModuleMemberInput,
) !u16 {
    const module_id = try findRigModule(modules, member.module_name);
    const module = modules[module_id.index()];
    const local_id = try findModuleSocketLocal(sockets[module.socket_start .. module.socket_start + module.socket_count], member.member_name);
    return @intCast(module.socket_start + local_id.index());
}

fn moduleById(definition: DefinitionView, id: RigModuleId) !*const RigModule {
    if (id.index() >= definition.rig_modules.len) return error.InvalidRigModuleId;
    return &definition.rig_modules[id.index()];
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
