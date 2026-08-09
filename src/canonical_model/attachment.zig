const component = @import("component.zig");
const identity = @import("identity.zig");
const math3d = @import("math3d.zig");

pub const TransformDriver = union(enum) {
    component: identity.ComponentId,
    bone: identity.BoneId,
    control: identity.ControlId,
    anchor: identity.AnchorId,
};

pub const Anchor = struct {
    anchor_id: identity.AnchorId,
    display_name: ?identity.DisplayName,
    owner_component_id: identity.ComponentId,
    mirror_anchor_id: ?identity.AnchorId = null,
    driver: TransformDriver,
    local_transform: math3d.LocalTransform,
    semantic_tags: []const identity.SemanticTagId,
};

pub const Socket = struct {
    socket_id: identity.SocketId,
    anchor_id: identity.AnchorId,
    accepted_component_types: []const identity.ComponentTypeId,
    accepted_tags: []const identity.SemanticTagId,
    capacity: u32,
    attachment_requirement: component.Requirement,
    compatibility: component.CompatibilityRequirements,
};

pub const MountAnchor = struct {
    mount_anchor_id: identity.MountAnchorId,
    display_name: ?identity.DisplayName,
    owner_component_id: identity.ComponentId,
    driver: TransformDriver,
    local_transform: math3d.LocalTransform,
    semantic_tags: []const identity.SemanticTagId,
};

pub const Attachment = struct {
    attachment_id: identity.AttachmentId,
    parent_socket_id: identity.SocketId,
    child_component_id: identity.ComponentId,
    child_mount_anchor_id: identity.MountAnchorId,
    compatibility_profiles: []const identity.CompatibilityProfileId,
};
