const std = @import("std");
const attachment = @import("attachment.zig");
const component = @import("component.zig");
const definition = @import("definition.zig");
const human_attachments = @import("human_attachments.zig");
const human_joint_control_validation = @import("human_joint_control_validation.zig");
const human_structural_semantics = @import("human_structural_semantics.zig");
const identity = @import("identity.zig");
const math3d = @import("math3d.zig");
const semantics = @import("semantics.zig");

pub const Error = error{
    Prompt2CRegression,
    AnchorCountMismatch,
    DuplicateAnchorId,
    MissingRequiredAnchor,
    AnchorOwnerMismatch,
    AnchorDriverMismatch,
    AnchorContractMismatch,
    MissingAnchorMirrorPartner,
    AnchorMirrorMismatch,
    FootContactOffGround,
    SocketCountMismatch,
    MissingRequiredSocket,
    SocketAnchorMismatch,
    MountCountMismatch,
    MissingRequiredMount,
    MountRelationshipMismatch,
    AttachmentCountMismatch,
    MissingRequiredAttachment,
    LandmarkCountMismatch,
    MissingRequiredLandmark,
    LandmarkOwnerMismatch,
    MissingLandmarkMirrorPartner,
    LandmarkMirrorMismatch,
    MidlineLandmarkOffCenter,
    SeamCountMismatch,
    MissingRequiredSeam,
    SeamContractMismatch,
    InteractionSiteCountMismatch,
    MissingRequiredInteractionSite,
    InteractionSiteOwnerMismatch,
    EffectorCountMismatch,
    MissingRequiredEffector,
    EffectorOwnerMismatch,
    MeshMetadataNotAllowed,
};

pub fn validatePrompt2D(source: *const definition.CanonicalCreatureDefinition) Error!void {
    human_joint_control_validation.validatePrompt2C(source) catch return error.Prompt2CRegression;
    try validateAnchors(source);
    try validateSocketsMountsAttachments(source);
    try validateLandmarks(source);
    try validateSeams(source);
    try validateSitesAndEffectors(source);
    try validateNoMeshMetadata(source);
}

fn validateAnchors(source: *const definition.CanonicalCreatureDefinition) Error!void {
    for (human_attachments.anchor_specs) |spec| {
        const record = findAnchor(source.anchors, spec.anchor_id) orelse return error.MissingRequiredAnchor;
        if (!std.mem.eql(u8, record.owner_component_id.value.bytes, spec.owner_component_id)) return error.AnchorOwnerMismatch;
        switch (record.driver) {
            .bone => |bone_id| if (!std.mem.eql(u8, bone_id.value.bytes, spec.driver_bone_id)) return error.AnchorDriverMismatch,
            else => return error.AnchorDriverMismatch,
        }
        if (spec.mirror_anchor_id) |mirror_id| {
            const declared = record.mirror_anchor_id orelse return error.MissingAnchorMirrorPartner;
            if (!std.mem.eql(u8, declared.value.bytes, mirror_id)) return error.AnchorMirrorMismatch;
            const mirror = findAnchor(source.anchors, mirror_id) orelse return error.MissingAnchorMirrorPartner;
            if (mirror.mirror_anchor_id == null or !mirror.mirror_anchor_id.?.eql(record.anchor_id)) return error.AnchorMirrorMismatch;
            const position = human_attachments.anchorWorldPosition(source, spec.anchor_id) catch return error.AnchorContractMismatch;
            const mirror_position = human_attachments.anchorWorldPosition(source, mirror_id) catch return error.AnchorContractMismatch;
            if (!mirroredPositionsMatch(position, mirror_position)) return error.AnchorMirrorMismatch;
        } else if (record.mirror_anchor_id != null) {
            return error.AnchorMirrorMismatch;
        }
        const position = human_attachments.anchorWorldPosition(source, spec.anchor_id) catch return error.AnchorContractMismatch;
        if (spec.side == .center and @abs(position.x) > human_attachments.report_tolerance_m) return error.AnchorMirrorMismatch;
        if (spec.ground_contact and @abs(position.y) > human_attachments.report_tolerance_m) return error.FootContactOffGround;
        if (!transformMatches(record.local_transform, spec.local_translation_m)) return error.AnchorContractMismatch;
    }
    if (source.anchors.len != human_attachments.anchor_count) return error.AnchorCountMismatch;
    for (source.anchors, 0..) |record, index| for (source.anchors[index + 1 ..]) |other| {
        if (record.anchor_id.eql(other.anchor_id)) return error.DuplicateAnchorId;
    };
}

fn validateSocketsMountsAttachments(source: *const definition.CanonicalCreatureDefinition) Error!void {
    for (human_attachments.socket_specs) |spec| {
        const socket = findSocket(source.sockets, spec.socket_id) orelse return error.MissingRequiredSocket;
        if (!std.mem.eql(u8, socket.anchor_id.value.bytes, spec.anchor_id) or
            socket.accepted_component_types.len != 1 or
            !std.mem.eql(u8, socket.accepted_component_types[0].value.bytes, spec.accepted_component_type) or
            socket.capacity != 1 or
            socket.attachment_requirement != spec.attachment_requirement)
        {
            return error.SocketAnchorMismatch;
        }
    }
    if (source.sockets.len != human_attachments.socket_count) return error.SocketCountMismatch;

    for (human_attachments.mount_specs) |spec| {
        const mount = findMount(source.mount_anchors, spec.mount_anchor_id) orelse return error.MissingRequiredMount;
        if (!std.mem.eql(u8, mount.owner_component_id.value.bytes, spec.owner_component_id)) return error.MountRelationshipMismatch;
        switch (mount.driver) {
            .component => |component_id| if (!std.mem.eql(u8, component_id.value.bytes, spec.owner_component_id)) return error.MountRelationshipMismatch,
            else => return error.MountRelationshipMismatch,
        }
        if (!transformMatches(mount.local_transform, math3d.Vec3.zero)) return error.MountRelationshipMismatch;
    }
    if (source.mount_anchors.len != human_attachments.mount_anchor_count) return error.MountCountMismatch;

    for (human_attachments.attachment_specs) |spec| {
        const record = findAttachment(source.attachments, spec.attachment_id) orelse return error.MissingRequiredAttachment;
        if (!std.mem.eql(u8, record.parent_socket_id.value.bytes, spec.parent_socket_id) or
            !std.mem.eql(u8, record.child_component_id.value.bytes, spec.child_component_id) or
            !std.mem.eql(u8, record.child_mount_anchor_id.value.bytes, spec.child_mount_anchor_id))
        {
            return error.MountRelationshipMismatch;
        }
        const socket = findSocket(source.sockets, spec.parent_socket_id) orelse return error.MountRelationshipMismatch;
        const mount = findMount(source.mount_anchors, spec.child_mount_anchor_id) orelse return error.MountRelationshipMismatch;
        if (!mount.owner_component_id.eql(record.child_component_id)) return error.MountRelationshipMismatch;
        const parent_anchor = findAnchorById(source.anchors, socket.anchor_id) orelse return error.SocketAnchorMismatch;
        const child = findComponent(source, record.child_component_id) orelse return error.MountRelationshipMismatch;
        if (child.parent_component_id == null or !child.parent_component_id.?.eql(parent_anchor.owner_component_id)) return error.MountRelationshipMismatch;
    }
    if (source.attachments.len != human_attachments.attachment_count) return error.AttachmentCountMismatch;
}

fn validateLandmarks(source: *const definition.CanonicalCreatureDefinition) Error!void {
    for (human_structural_semantics.landmark_specs) |spec| {
        const record = findLandmark(source.landmarks, spec.landmark_id) orelse return error.MissingRequiredLandmark;
        const anchor_id = switch (record.owner) {
            .anchor => |id| id,
            else => return error.LandmarkOwnerMismatch,
        };
        if (!std.mem.eql(u8, anchor_id.value.bytes, spec.anchor_id)) return error.LandmarkOwnerMismatch;
        if (spec.mirror_landmark_id) |mirror_id| {
            const declared = record.mirror_landmark_id orelse return error.MissingLandmarkMirrorPartner;
            if (!std.mem.eql(u8, declared.value.bytes, mirror_id)) return error.LandmarkMirrorMismatch;
            const mirror = findLandmark(source.landmarks, mirror_id) orelse return error.MissingLandmarkMirrorPartner;
            if (mirror.mirror_landmark_id == null or !mirror.mirror_landmark_id.?.eql(record.landmark_id)) return error.LandmarkMirrorMismatch;
            const position = human_attachments.anchorWorldPosition(source, spec.anchor_id) catch return error.LandmarkOwnerMismatch;
            const mirror_anchor_id = switch (mirror.owner) {
                .anchor => |id| id.value.bytes,
                else => return error.LandmarkOwnerMismatch,
            };
            const mirror_position = human_attachments.anchorWorldPosition(source, mirror_anchor_id) catch return error.LandmarkOwnerMismatch;
            if (!mirroredPositionsMatch(position, mirror_position)) return error.LandmarkMirrorMismatch;
        } else if (record.mirror_landmark_id != null) {
            return error.LandmarkMirrorMismatch;
        }
        const position = human_attachments.anchorWorldPosition(source, spec.anchor_id) catch return error.LandmarkOwnerMismatch;
        if (spec.side == .center and @abs(position.x) > human_attachments.report_tolerance_m) return error.MidlineLandmarkOffCenter;
        if ((std.mem.startsWith(u8, spec.landmark_id, "heel_") or std.mem.startsWith(u8, spec.landmark_id, "toe_tip_")) and
            @abs(position.y) > human_attachments.report_tolerance_m)
        {
            return error.FootContactOffGround;
        }
    }
    if (source.landmarks.len != human_structural_semantics.landmark_count) return error.LandmarkCountMismatch;
}

fn validateSeams(source: *const definition.CanonicalCreatureDefinition) Error!void {
    for (human_structural_semantics.seam_specs) |spec| {
        const seam = findSeam(source.shared_seams, spec.seam_id) orelse return error.MissingRequiredSeam;
        if (seam.members.len != 2 or seam.coordinate_metadata_id != null) return error.SeamContractMismatch;
        if (!std.mem.eql(u8, seam.members[0].component_id.value.bytes, spec.component_a_id) or
            !std.mem.eql(u8, seam.members[0].surface_id.value.bytes, spec.surface_a_id) or
            !std.mem.eql(u8, seam.members[1].component_id.value.bytes, spec.component_b_id) or
            !std.mem.eql(u8, seam.members[1].surface_id.value.bytes, spec.surface_b_id))
        {
            return error.SeamContractMismatch;
        }
        if (!surfaceOwnedBy(source, spec.surface_a_id, spec.component_a_id) or
            !surfaceOwnedBy(source, spec.surface_b_id, spec.component_b_id))
        {
            return error.SeamContractMismatch;
        }
    }
    if (source.shared_seams.len != human_structural_semantics.shared_seam_count) return error.SeamCountMismatch;
}

fn validateSitesAndEffectors(source: *const definition.CanonicalCreatureDefinition) Error!void {
    for (human_structural_semantics.site_specs) |spec| {
        const site = findSite(source.interaction_sites, spec.site_id) orelse return error.MissingRequiredInteractionSite;
        if (!siteMatches(site, spec.owner_component_id, spec.region_id, spec.preferred_anchor_id)) return error.InteractionSiteOwnerMismatch;
    }
    if (source.interaction_sites.len != human_structural_semantics.interaction_site_count) return error.InteractionSiteCountMismatch;

    for (human_structural_semantics.effector_specs) |spec| {
        const effector = findEffector(source.effectors, spec.effector_id) orelse return error.MissingRequiredEffector;
        if (!effectorMatches(effector, spec.owner_component_id, spec.region_id, spec.preferred_anchor_id)) return error.EffectorOwnerMismatch;
    }
    if (source.effectors.len != human_structural_semantics.effector_count) return error.EffectorCountMismatch;
}

fn validateNoMeshMetadata(source: *const definition.CanonicalCreatureDefinition) Error!void {
    for (source.landmarks) |record| if (record.coordinate_metadata_id != null) return error.MeshMetadataNotAllowed;
    for (source.shared_seams) |record| if (record.coordinate_metadata_id != null) return error.MeshMetadataNotAllowed;
    for (source.surfaces) |record| if (record.coordinate_metadata_id != null) return error.MeshMetadataNotAllowed;
}

fn transformMatches(transform: math3d.LocalTransform, expected_translation: math3d.Vec3) bool {
    return vectorsMatch(transform.translation_m, expected_translation) and
        vectorsMatch(transform.scale, math3d.Vec3.one) and
        @abs(transform.rotation.x) <= human_attachments.report_tolerance_m and
        @abs(transform.rotation.y) <= human_attachments.report_tolerance_m and
        @abs(transform.rotation.z) <= human_attachments.report_tolerance_m and
        @abs(transform.rotation.w - 1) <= human_attachments.report_tolerance_m;
}

fn vectorsMatch(a: math3d.Vec3, b: math3d.Vec3) bool {
    return @abs(a.x - b.x) <= human_attachments.report_tolerance_m and
        @abs(a.y - b.y) <= human_attachments.report_tolerance_m and
        @abs(a.z - b.z) <= human_attachments.report_tolerance_m;
}

fn mirroredPositionsMatch(a: math3d.Vec3, b: math3d.Vec3) bool {
    return @abs(a.x + b.x) <= human_attachments.report_tolerance_m and
        @abs(a.y - b.y) <= human_attachments.report_tolerance_m and
        @abs(a.z - b.z) <= human_attachments.report_tolerance_m;
}

fn siteMatches(site: semantics.InteractionSite, owner: []const u8, region: []const u8, anchor: []const u8) bool {
    return std.mem.eql(u8, site.owner_component_id.value.bytes, owner) and
        site.region_id != null and std.mem.eql(u8, site.region_id.?.value.bytes, region) and
        site.preferred_anchor_id != null and std.mem.eql(u8, site.preferred_anchor_id.?.value.bytes, anchor) and
        site.capacity == 1 and site.approach_metadata_id == null and site.orientation_metadata_id == null and site.occupancy_policy_id == null;
}

fn effectorMatches(effector: semantics.Effector, owner: []const u8, region: []const u8, anchor: []const u8) bool {
    return std.mem.eql(u8, effector.owner_component_id.value.bytes, owner) and
        effector.region_id != null and std.mem.eql(u8, effector.region_id.?.value.bytes, region) and
        effector.preferred_anchor_id != null and std.mem.eql(u8, effector.preferred_anchor_id.?.value.bytes, anchor) and
        effector.capacity == 1 and effector.approach_metadata_id == null and effector.orientation_metadata_id == null and effector.occupancy_policy_id == null;
}

fn surfaceOwnedBy(source: *const definition.CanonicalCreatureDefinition, surface_id: []const u8, component_id: []const u8) bool {
    for (source.surfaces) |surface| {
        if (std.mem.eql(u8, surface.surface_id.value.bytes, surface_id)) return std.mem.eql(u8, surface.owner_component_id.value.bytes, component_id);
    }
    return false;
}

fn findAnchor(records: []const attachment.Anchor, id: []const u8) ?attachment.Anchor {
    for (records) |record| if (std.mem.eql(u8, record.anchor_id.value.bytes, id)) return record;
    return null;
}

fn findAnchorById(records: []const attachment.Anchor, id: identity.AnchorId) ?attachment.Anchor {
    for (records) |record| if (record.anchor_id.eql(id)) return record;
    return null;
}

fn findSocket(records: []const attachment.Socket, id: []const u8) ?attachment.Socket {
    for (records) |record| if (std.mem.eql(u8, record.socket_id.value.bytes, id)) return record;
    return null;
}

fn findMount(records: []const attachment.MountAnchor, id: []const u8) ?attachment.MountAnchor {
    for (records) |record| if (std.mem.eql(u8, record.mount_anchor_id.value.bytes, id)) return record;
    return null;
}

fn findAttachment(records: []const attachment.Attachment, id: []const u8) ?attachment.Attachment {
    for (records) |record| if (std.mem.eql(u8, record.attachment_id.value.bytes, id)) return record;
    return null;
}

fn findComponent(source: *const definition.CanonicalCreatureDefinition, id: identity.ComponentId) ?component.Component {
    for (source.components) |record| if (record.component_id.eql(id)) return record;
    return null;
}

fn findLandmark(records: []const semantics.Landmark, id: []const u8) ?semantics.Landmark {
    for (records) |record| if (std.mem.eql(u8, record.landmark_id.value.bytes, id)) return record;
    return null;
}

fn findSeam(records: []const semantics.SharedSeam, id: []const u8) ?semantics.SharedSeam {
    for (records) |record| if (std.mem.eql(u8, record.seam_id.value.bytes, id)) return record;
    return null;
}

fn findSite(records: []const semantics.InteractionSite, id: []const u8) ?semantics.InteractionSite {
    for (records) |record| if (std.mem.eql(u8, record.site_id.value.bytes, id)) return record;
    return null;
}

fn findEffector(records: []const semantics.Effector, id: []const u8) ?semantics.Effector {
    for (records) |record| if (std.mem.eql(u8, record.effector_id.value.bytes, id)) return record;
    return null;
}
