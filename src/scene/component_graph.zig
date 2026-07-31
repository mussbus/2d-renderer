const std = @import("std");
const anatomy = @import("anatomy");
const appearance = @import("appearance");

pub const Definition = struct {
    appearance_token: usize,
    anatomy_token: usize,
    topology_fingerprint: u64,

    pub fn init(
        appearance_definition: appearance.DefinitionView,
        anatomy_definition: anatomy.DefinitionView,
    ) !Definition {
        try validateDefinition(appearance_definition, anatomy_definition);
        return .{
            .appearance_token = appearance_definition.owner_token,
            .anatomy_token = anatomy_definition.owner_token,
            .topology_fingerprint = topologyFingerprint(
                appearance_definition,
                anatomy_definition,
            ),
        };
    }

    pub fn validateCompatibility(
        definition: Definition,
        appearance_definition: appearance.DefinitionView,
        anatomy_definition: anatomy.DefinitionView,
    ) !void {
        if (definition.appearance_token != appearance_definition.owner_token or
            definition.anatomy_token != anatomy_definition.owner_token)
        {
            return error.ComponentGraphDefinitionMismatch;
        }
        if (definition.topology_fingerprint != topologyFingerprint(
            appearance_definition,
            anatomy_definition,
        )) return error.RuntimeTopologyMutation;
    }

    pub fn view(
        definition: Definition,
        appearance_definition: appearance.DefinitionView,
        anatomy_definition: anatomy.DefinitionView,
    ) !View {
        try definition.validateCompatibility(
            appearance_definition,
            anatomy_definition,
        );
        return .{
            .compiled = definition,
            .appearance_definition = appearance_definition,
            .anatomy_definition = anatomy_definition,
        };
    }
};

pub const View = struct {
    compiled: Definition,
    appearance_definition: appearance.DefinitionView,
    anatomy_definition: anatomy.DefinitionView,

    pub fn componentCount(view: View) usize {
        return view.anatomy_definition.part_instances.len;
    }

    pub fn component(view: View, id: anatomy.BodyPartInstanceId) !Component {
        if (id.index() >= view.anatomy_definition.part_instances.len) {
            return error.InvalidBodyPartInstanceId;
        }
        const instance = view.anatomy_definition.part_instances[id.index()];
        const component_definition = view.anatomy_definition.part_definitions[
            instance.definition.index()
        ];
        const parent_component: ?anatomy.BodyPartInstanceId = switch (instance.parent) {
            .body_part_socket => |socket_id| view.anatomy_definition
                .instance_sockets[socket_id.index()].owner,
            .attachment_point, .module_socket => null,
        };
        return .{
            .instance = instance,
            .definition = component_definition,
            .parent_component = parent_component,
            .parent_socket = switch (instance.parent) {
                .body_part_socket => |socket_id| socket_id,
                .attachment_point, .module_socket => null,
            },
        };
    }

    pub fn boundVisuals(
        view: View,
        id: anatomy.BodyPartInstanceId,
        profile: anatomy.PresentationProfileId,
    ) ![]const appearance.VisualAttachmentId {
        const component_value = try view.component(id);
        const variants = view.anatomy_definition.visual_variants[component_value.instance.visual_variant_start .. component_value.instance.visual_variant_start +
            component_value.instance.visual_variant_count];
        for (variants) |variant| {
            if (variant.presentation_profile != profile) continue;
            return view.anatomy_definition.variant_visuals[variant.visual_start .. variant.visual_start + variant.visual_count];
        }
        return error.MissingPresentationVariant;
    }

    pub fn articulation(
        view: View,
        id: anatomy.BodyPartInstanceId,
    ) !?Articulation {
        const component_value = try view.component(id);
        const module_id = component_value.instance.articulation_module orelse
            return null;
        if (module_id.index() >= view.appearance_definition.rig_modules.len) {
            return error.InvalidRigModuleId;
        }
        const module = view.appearance_definition.rig_modules[module_id.index()];
        return .{
            .module = module,
            .joints = view.appearance_definition.module_joints[module.joint_start .. module.joint_start + module.joint_count],
            .sockets = view.appearance_definition.module_sockets[module.socket_start .. module.socket_start + module.socket_count],
        };
    }
};

pub const Component = struct {
    instance: anatomy.BodyPartInstance,
    definition: anatomy.BodyPartDefinition,
    parent_component: ?anatomy.BodyPartInstanceId,
    parent_socket: ?anatomy.PartSocketId,
};

pub const Articulation = struct {
    module: appearance.RigModule,
    joints: []const appearance.ModuleJoint,
    sockets: []const appearance.ModuleSocket,
};

pub fn measuredGap(instance: anatomy.BodyPartInstance) f32 {
    return instance.local_to_parent.translation.length();
}

fn validateDefinition(
    appearance_definition: appearance.DefinitionView,
    anatomy_definition: anatomy.DefinitionView,
) !void {
    var module_owners = [_]?anatomy.BodyPartInstanceId{null} **
        appearance.maximum_rig_modules;
    var socket_occupancy = [_]u16{0} ** anatomy.maximum_part_sockets;
    for (anatomy_definition.part_instances) |instance| {
        const component_definition = anatomy_definition.part_definitions[
            instance.definition.index()
        ];
        if (!component_definition.projected_views.contains(
            component_definition.required_views,
        )) return error.UnsupportedFrontProjectionSource;

        if (!component_definition.supported_connections.supports(
            std.meta.activeTag(instance.connection),
        )) return error.UnsupportedConnectionMode;
        switch (instance.parent) {
            .body_part_socket => |socket_id| {
                if (socket_id.index() >= anatomy_definition.instance_sockets.len) {
                    return error.UnknownParentSocket;
                }
                const socket = anatomy_definition.instance_sockets[socket_id.index()];
                if (!socket.supported_connections.supports(
                    std.meta.activeTag(instance.connection),
                )) return error.UnsupportedConnectionMode;
                if (component_definition.allowed_parent_socket_role) |required_role| {
                    const socket_role = socket.role orelse
                        return error.ParentSocketRoleMismatch;
                    if (!required_role.eql(&socket_role)) {
                        return error.ParentSocketRoleMismatch;
                    }
                }
                socket_occupancy[socket_id.index()] = std.math.add(
                    u16,
                    socket_occupancy[socket_id.index()],
                    1,
                ) catch return error.SocketCapacityExceeded;
                if (socket_occupancy[socket_id.index()] > socket.capacity) {
                    return error.SocketCapacityExceeded;
                }
            },
            .attachment_point, .module_socket => {},
        }

        if (instance.articulation_module) |module_id| {
            if (module_id.index() >= appearance_definition.rig_modules.len) {
                return error.InvalidRigModuleId;
            }
            if (module_owners[module_id.index()] != null) {
                return error.RigModuleOwnedByMultipleComponents;
            }
            module_owners[module_id.index()] = instance.id;
        }

        if (component_definition.rig_module_template) |template| {
            const module_id = instance.articulation_module orelse
                return error.RequiredRigModuleMissing;
            switch (template) {
                .shoulder_elbow_wrist_hand => try validateArmTemplate(
                    appearance_definition,
                    module_id,
                ),
            }
        }

        switch (instance.connection) {
            .hidden => |connection| {
                if (connection.hider_component.index() >=
                    anatomy_definition.part_instances.len)
                {
                    return error.HiddenConnectionOwnerMissing;
                }
            },
            .soft_bridge => |connection| {
                if (connection.bridge_component.index() >=
                    anatomy_definition.part_instances.len)
                {
                    return error.SoftBridgeMissing;
                }
                const bridge_definition = anatomy_definition.part_definitions[
                    anatomy_definition.part_instances[
                        connection.bridge_component.index()
                    ].definition.index()
                ];
                if (bridge_definition.binding_mode != .mesh) {
                    return error.SoftBridgeMissing;
                }
            },
            .continuous, .intentional_gap => {},
        }
    }
}

fn validateArmTemplate(
    definition: appearance.DefinitionView,
    module_id: appearance.RigModuleId,
) !void {
    const module = definition.rig_modules[module_id.index()];
    const shoulder = findJoint(definition, module, "shoulder") orelse
        return error.RigModuleJointMissing;
    const elbow = findJoint(definition, module, "elbow") orelse
        return error.RigModuleJointMissing;
    const wrist = findJoint(definition, module, "wrist") orelse
        return error.RigModuleJointMissing;
    if (shoulder.parent_joint_global != appearance.no_index or
        elbow.parent_joint_global != module.joint_start + shoulder.id.index() or
        wrist.parent_joint_global != module.joint_start + elbow.id.index())
    {
        return error.InvalidRigModuleJointChain;
    }
    const hand = findSocket(definition, module, "hand_tip") orelse
        return error.RigModuleEndSocketMissing;
    if (hand.parent_joint_global != module.joint_start + wrist.id.index()) {
        return error.InvalidRigModuleEndSocket;
    }
}

fn findJoint(
    definition: appearance.DefinitionView,
    module: appearance.RigModule,
    name: []const u8,
) ?appearance.ModuleJoint {
    for (definition.module_joints[module.joint_start .. module.joint_start + module.joint_count]) |joint| {
        if (std.mem.eql(u8, joint.debug_name.slice(), name)) return joint;
    }
    return null;
}

fn findSocket(
    definition: appearance.DefinitionView,
    module: appearance.RigModule,
    name: []const u8,
) ?appearance.ModuleSocket {
    for (definition.module_sockets[module.socket_start .. module.socket_start + module.socket_count]) |socket| {
        if (std.mem.eql(u8, socket.debug_name.slice(), name)) return socket;
    }
    return null;
}

fn topologyFingerprint(
    appearance_definition: appearance.DefinitionView,
    anatomy_definition: anatomy.DefinitionView,
) u64 {
    var hash: u64 = 14695981039346656037;
    hashUsize(&hash, anatomy_definition.part_definitions.len);
    hashUsize(&hash, anatomy_definition.part_instances.len);
    hashUsize(&hash, anatomy_definition.instance_sockets.len);
    hashUsize(&hash, appearance_definition.rig_modules.len);
    hashUsize(&hash, appearance_definition.module_joints.len);
    hashUsize(&hash, appearance_definition.module_sockets.len);

    for (anatomy_definition.part_definitions) |definition| {
        hashBytes(&hash, definition.stable_id.slice());
        hashBytes(&hash, definition.category_tag.slice());
        hashBytes(&hash, definition.type_tag.slice());
        hashByte(&hash, @intFromEnum(definition.binding_mode));
        hashByte(&hash, @bitCast(definition.supported_connections));
        hashByte(&hash, @bitCast(definition.required_views));
        hashByte(&hash, @bitCast(definition.projected_views));
        hashU16(&hash, definition.validation.maximum_instances);
        hashByte(&hash, @intFromBool(definition.validation.allow_children));
        hashOptionalName(&hash, definition.allowed_parent_socket_role);
        hashOptionalName(&hash, definition.material_slot);
        hashOptionalName(&hash, definition.morphology_response);
        hashByte(&hash, if (definition.rig_module_template) |value|
            @intFromEnum(value) + 1
        else
            0);
    }
    for (anatomy_definition.instance_sockets) |socket| {
        hashBytes(&hash, socket.stable_id.slice());
        hashU16(&hash, @intFromEnum(socket.owner));
        hashOptionalName(&hash, socket.accepted_child_tag);
        hashOptionalName(&hash, socket.role);
        hashU16(&hash, socket.capacity);
        hashByte(&hash, @bitCast(socket.supported_connections));
        hashTransform(&hash, socket.local_to_part);
    }
    for (anatomy_definition.part_instances) |instance| {
        hashBytes(&hash, instance.stable_id.slice());
        hashU16(&hash, @intFromEnum(instance.definition));
        switch (instance.parent) {
            .attachment_point => |id| {
                hashByte(&hash, 0);
                hashU16(&hash, @intFromEnum(id));
            },
            .body_part_socket => |id| {
                hashByte(&hash, 1);
                hashU16(&hash, @intFromEnum(id));
            },
            .module_socket => |id| {
                hashByte(&hash, 2);
                hashU16(&hash, id);
            },
        }
        hashTransform(&hash, instance.local_to_parent);
        hashByte(&hash, @intFromEnum(std.meta.activeTag(instance.connection)));
        switch (instance.connection) {
            .continuous => |value| hashF32(&hash, value.maximum_gap),
            .intentional_gap => |value| {
                hashF32(&hash, value.minimum_gap);
                hashF32(&hash, value.maximum_gap);
            },
            .hidden => |value| hashU16(
                &hash,
                @intFromEnum(value.hider_component),
            ),
            .soft_bridge => |value| hashU16(
                &hash,
                @intFromEnum(value.bridge_component),
            ),
        }
        hashByte(&hash, @intFromEnum(instance.topology_status));
        hashU16(&hash, instance.visual_variant_start);
        hashU16(&hash, instance.visual_variant_count);
        hashU16(&hash, if (instance.articulation_module) |id|
            @intCast(id.index() + 1)
        else
            0);
    }
    for (appearance_definition.rig_modules) |module| {
        hashBytes(&hash, module.debug_name.slice());
        hashU16(&hash, @intFromEnum(module.parent_attachment_point));
        hashTransform(&hash, module.local_to_attachment_point);
        hashU16(&hash, module.joint_count);
        hashU16(&hash, module.socket_count);
    }
    for (appearance_definition.module_joints) |joint| {
        hashBytes(&hash, joint.debug_name.slice());
        hashU16(&hash, @intFromEnum(joint.module_id));
        hashU16(&hash, joint.parent_joint_global);
        hashTransform(&hash, joint.rest_local);
    }
    for (appearance_definition.module_sockets) |socket| {
        hashBytes(&hash, socket.debug_name.slice());
        hashU16(&hash, @intFromEnum(socket.module_id));
        hashU16(&hash, socket.parent_joint_global);
        hashTransform(&hash, socket.local_to_parent);
    }
    return hash;
}

fn hashTransform(hash: *u64, value: @import("math").Transform2D) void {
    hashF32(hash, value.translation.x);
    hashF32(hash, value.translation.y);
    hashF32(hash, value.rotation_radians);
    hashF32(hash, value.scale.x);
    hashF32(hash, value.scale.y);
}

fn hashOptionalName(hash: *u64, value: ?@import("skeleton").DebugName) void {
    if (value) |name| {
        hashByte(hash, 1);
        hashBytes(hash, name.slice());
    } else {
        hashByte(hash, 0);
    }
}

fn hashF32(hash: *u64, value: f32) void {
    hashU32(hash, @bitCast(value));
}

fn hashUsize(hash: *u64, value: usize) void {
    hashU64(hash, @intCast(value));
}

fn hashU64(hash: *u64, value: u64) void {
    for (std.mem.asBytes(&value)) |byte| hashByte(hash, byte);
}

fn hashU32(hash: *u64, value: u32) void {
    for (std.mem.asBytes(&value)) |byte| hashByte(hash, byte);
}

fn hashU16(hash: *u64, value: u16) void {
    for (std.mem.asBytes(&value)) |byte| hashByte(hash, byte);
}

fn hashBytes(hash: *u64, bytes: []const u8) void {
    hashUsize(hash, bytes.len);
    for (bytes) |byte| hashByte(hash, byte);
}

fn hashByte(hash: *u64, byte: u8) void {
    hash.* = (hash.* ^ byte) *% 1099511628211;
}
