const std = @import("std");
const attachment = @import("attachment.zig");
const component = @import("component.zig");
const coordinate = @import("coordinate.zig");
const definition = @import("definition.zig");
const diagnostics = @import("diagnostics.zig");
const identity = @import("identity.zig");
const material = @import("material.zig");
const math3d = @import("math3d.zig");
const morphology = @import("morphology.zig");
const rig = @import("rig.zig");
const semantics = @import("semantics.zig");
const visibility = @import("visibility.zig");

pub const ValidationContext = struct {
    binding_schema: morphology.BindingValidationSchema = .empty,
};

pub const ValidationError = diagnostics.CollectorError;

pub fn validate(
    source: *const definition.CanonicalCreatureDefinition,
    context: ValidationContext,
    diagnostic_storage: []diagnostics.Diagnostic,
) ValidationError!diagnostics.ValidationReport {
    var collector = diagnostics.Collector.init(diagnostic_storage);

    try validateIdentities(source, &collector);
    try validateCoordinateContract(source, &collector);
    try validateComponents(source, &collector);
    try validateRig(source, &collector);
    try validateAttachments(source, &collector);
    try validateSemantics(source, &collector);
    try validateMorphology(source, context.binding_schema, &collector);
    try validateMaterials(source, &collector);
    try validateVisibility(source, &collector);

    return collector.finish();
}

fn validateIdentities(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
) ValidationError!void {
    try validateDuplicateIds(source.components, "component_id", "component", collector);
    try validateDuplicateIds(source.bones, "bone_id", "bone", collector);
    try validateDuplicateIds(source.joints, "joint_id", "joint", collector);
    try validateDuplicateIds(source.controls, "control_id", "control", collector);
    try validateDuplicateIds(source.anchors, "anchor_id", "anchor", collector);
    try validateDuplicateIds(source.sockets, "socket_id", "socket", collector);
    try validateDuplicateIds(source.mount_anchors, "mount_anchor_id", "mount_anchor", collector);
    try validateDuplicateIds(source.attachments, "attachment_id", "attachment", collector);
    try validateDuplicateIds(source.regions, "region_id", "region", collector);
    try validateDuplicateIds(source.surfaces, "surface_id", "surface", collector);
    try validateDuplicateIds(source.landmarks, "landmark_id", "landmark", collector);
    try validateDuplicateIds(source.shared_seams, "seam_id", "shared_seam", collector);
    try validateDuplicateIds(source.interaction_sites, "site_id", "interaction_site", collector);
    try validateDuplicateIds(source.effectors, "effector_id", "effector", collector);
    try validateDuplicateIds(source.morphology_parameters, "parameter_id", "morphology_parameter", collector);
    try validateDuplicateIds(source.morphology_bindings, "binding_id", "morphology_binding", collector);
    try validateDuplicateIds(source.morphology_graph.dependencies, "dependency_id", "morphology_dependency", collector);
    try validateDuplicateIds(source.morphology_graph.provenance, "provenance_id", "morphology_provenance", collector);
    try validateDuplicateIds(source.material_definitions, "material_definition_id", "material_definition", collector);
    try validateDuplicateIds(source.material_instances, "material_instance_id", "material_instance", collector);
    try validateDuplicateIds(source.visibility_metadata, "visibility_metadata_id", "visibility_metadata", collector);

    try validateDisplayName(source.asset_identity.display_name, "asset", source.asset_identity.asset_id.value.bytes, collector);
    inline for (.{
        .{ source.components, "component_id", "display_name", "component" },
        .{ source.bones, "bone_id", "display_name", "bone" },
        .{ source.joints, "joint_id", "display_name", "joint" },
        .{ source.controls, "control_id", "display_name", "control" },
        .{ source.anchors, "anchor_id", "display_name", "anchor" },
        .{ source.mount_anchors, "mount_anchor_id", "display_name", "mount_anchor" },
        .{ source.regions, "region_id", "display_name", "region" },
        .{ source.surfaces, "surface_id", "display_name", "surface" },
        .{ source.landmarks, "landmark_id", "display_name", "landmark" },
        .{ source.shared_seams, "seam_id", "display_name", "shared_seam" },
        .{ source.interaction_sites, "site_id", "display_name", "interaction_site" },
        .{ source.effectors, "effector_id", "display_name", "effector" },
    }) |entry| {
        for (entry[0]) |record| {
            if (@field(record, entry[2])) |name| {
                try validateDisplayName(name, entry[3], @field(record, entry[1]).value.bytes, collector);
            }
        }
    }
    for (source.morphology_parameters) |record| try validateDisplayName(record.display_name, "morphology_parameter", record.parameter_id.value.bytes, collector);
    for (source.material_definitions) |record| try validateDisplayName(record.display_name, "material_definition", record.material_definition_id.value.bytes, collector);
    for (source.material_instances) |record| try validateDisplayName(record.display_name, "material_instance", record.material_instance_id.value.bytes, collector);
}

fn validateCoordinateContract(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
) ValidationError!void {
    const contract = source.coordinate_contract orelse return;
    if (!std.math.isFinite(contract.authoring_step_m) or
        !std.math.isFinite(contract.ground_y_m) or
        !std.math.isFinite(contract.canonical_height_m))
    {
        try emit(collector, .non_finite_value, .value, "coordinate_contract", null, null, null, null, "coordinate contract values must be finite");
        return;
    }
    if (!std.meta.eql(contract, coordinate.canonical)) {
        try emit(collector, .invalid_coordinate_contract, .value, "coordinate_contract", null, null, null, null, "coordinate contract must match the locked M01 canonical contract");
    }
}

fn validateComponents(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
) ValidationError!void {
    var root_count: usize = 0;
    for (source.components) |record| {
        if (record.parent_component_id == null) root_count += 1;
        try validateUniqueIds(record.semantic_tags, "component", record.component_id.value.bytes, "semantic_tags", collector);
        try validateUniqueIds(record.compatibility.profiles, "component", record.component_id.value.bytes, "compatibility.profiles", collector);
        try validateUniqueIds(record.compatibility.required_tags, "component", record.component_id.value.bytes, "compatibility.required_tags", collector);
        if (record.multiplicity.maximum) |maximum| {
            if (record.multiplicity.minimum > maximum) {
                try emit(collector, .multiplicity_contradiction, .attachment, "component", record.component_id.value.bytes, "multiplicity", null, null, "component minimum multiplicity cannot exceed maximum");
            }
        }
        if (record.parent_component_id) |parent_id| {
            if (record.component_id.eql(parent_id)) {
                try emit(collector, .invalid_parent_relationship, .graph, "component", record.component_id.value.bytes, "parent_component_id", "component", parent_id.value.bytes, "component cannot parent itself");
            } else if (!hasId(source.components, "component_id", parent_id)) {
                try missingOrWrongReference(source, collector, "component", record.component_id.value.bytes, "parent_component_id", "component", parent_id.value.bytes);
            }
        }
    }
    if (root_count != 1) {
        try emit(collector, .invalid_component_root_count, .graph, "component_graph", null, "parent_component_id", null, null, "component ownership graph must contain exactly one root");
    }
    if (root_count == 1) {
        for (source.components) |record| {
            if (record.parent_component_id == null and !std.mem.eql(u8, record.component_id.value.bytes, "body")) {
                try emit(collector, .invalid_component_root_count, .graph, "component", record.component_id.value.bytes, "component_id", null, null, "the single canonical component root must use the stable body ID");
            }
        }
    }
    for (source.components) |record| {
        if (componentParentCycle(source.components, record.component_id)) {
            try emit(collector, .component_tree_cycle, .graph, "component", record.component_id.value.bytes, "parent_component_id", null, null, "component parent chain contains a cycle");
        }
    }
}

fn validateRig(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
) ValidationError!void {
    var root_count: usize = 0;
    for (source.bones) |bone| {
        if (bone.parent_bone_id == null) root_count += 1;
        try validateUniqueIds(bone.semantic_tags, "bone", bone.bone_id.value.bytes, "semantic_tags", collector);
        if (bone.owner_component_id) |owner_component_id| {
            if (!schemaSupportsM02TypedExtensions(source.schema_identity.version)) {
                try emit(collector, .schema_feature_version_mismatch, .identity, "bone", bone.bone_id.value.bytes, "owner_component_id", null, null, "component-owned bones require canonical creature schema 1.1.0 or newer");
            }
            if (!hasId(source.components, "component_id", owner_component_id)) {
                try missingOrWrongReference(source, collector, "bone", bone.bone_id.value.bytes, "owner_component_id", "component", owner_component_id.value.bytes);
            }
        }
        if (bone.parent_bone_id) |parent_id| {
            if (bone.bone_id.eql(parent_id)) {
                try emit(collector, .invalid_parent_relationship, .graph, "bone", bone.bone_id.value.bytes, "parent_bone_id", "bone", parent_id.value.bytes, "bone cannot parent itself");
            } else if (!hasId(source.bones, "bone_id", parent_id)) {
                try missingOrWrongReference(source, collector, "bone", bone.bone_id.value.bytes, "parent_bone_id", "bone", parent_id.value.bytes);
            }
        }
        if (bone.mirror_bone_id) |mirror_id| {
            if (!hasId(source.bones, "bone_id", mirror_id)) {
                try missingOrWrongReference(source, collector, "bone", bone.bone_id.value.bytes, "mirror_bone_id", "bone", mirror_id.value.bytes);
            }
        }
        try validateTransform(bone.local_rest_transform, "bone", bone.bone_id.value.bytes, "local_rest_transform", collector);
        if (bone.display_length_m) |length| try validateFinite(length, "bone", bone.bone_id.value.bytes, "display_length_m", collector);
    }
    if (root_count != 1) {
        try emit(collector, .invalid_skeleton_root_count, .graph, "skeleton", null, "parent_bone_id", null, null, "skeleton must contain exactly one root bone");
    }
    if (root_count == 1) {
        for (source.bones) |bone| {
            if (bone.parent_bone_id == null and !std.mem.eql(u8, bone.bone_id.value.bytes, "skeleton_root")) {
                try emit(collector, .invalid_skeleton_root_count, .graph, "bone", bone.bone_id.value.bytes, "bone_id", null, null, "the single canonical skeleton root must use the stable skeleton_root ID");
            }
        }
    }
    for (source.bones) |bone| {
        if (boneParentCycle(source.bones, bone.bone_id)) {
            try emit(collector, .skeleton_cycle, .graph, "bone", bone.bone_id.value.bytes, "parent_bone_id", null, null, "bone parent chain contains a cycle");
        }
    }

    for (source.joints) |joint| {
        if (joint.mirror_joint_id) |mirror_joint_id| {
            if (!schemaSupportsM02TypedExtensions(source.schema_identity.version)) {
                try emit(collector, .schema_feature_version_mismatch, .identity, "joint", joint.joint_id.value.bytes, "mirror_joint_id", null, null, "typed joint mirrors require canonical creature schema 1.1.0 or newer");
            }
            if (!hasId(source.joints, "joint_id", mirror_joint_id)) {
                try missingOrWrongReference(source, collector, "joint", joint.joint_id.value.bytes, "mirror_joint_id", "joint", mirror_joint_id.value.bytes);
            }
        }
        if (!hasId(source.bones, "bone_id", joint.parent_bone_id)) {
            try missingOrWrongReference(source, collector, "joint", joint.joint_id.value.bytes, "parent_bone_id", "bone", joint.parent_bone_id.value.bytes);
        }
        if (!hasId(source.bones, "bone_id", joint.child_bone_id)) {
            try missingOrWrongReference(source, collector, "joint", joint.joint_id.value.bytes, "child_bone_id", "bone", joint.child_bone_id.value.bytes);
        }
        if (joint.parent_bone_id.eql(joint.child_bone_id)) {
            try emit(collector, .invalid_parent_relationship, .graph, "joint", joint.joint_id.value.bytes, "child_bone_id", "bone", joint.child_bone_id.value.bytes, "joint parent and child bones must differ");
        }
        if (findById(source.bones, "bone_id", joint.child_bone_id)) |child_bone| {
            if (child_bone.parent_bone_id == null or !child_bone.parent_bone_id.?.eql(joint.parent_bone_id)) {
                try emit(collector, .invalid_parent_relationship, .graph, "joint", joint.joint_id.value.bytes, "parent_bone_id", "bone", joint.parent_bone_id.value.bytes, "joint parent must match the child bone's skeletal parent");
            }
        }
        try validateAxisRanges(joint.preferred_range, "preferred_range", joint.joint_id.value.bytes, collector);
        try validateAxisRanges(joint.hard_range, "hard_range", joint.joint_id.value.bytes, collector);
        if (joint.preferred_bend_direction) |value| try validateVec3(value, "joint", joint.joint_id.value.bytes, "preferred_bend_direction", collector);
        if (joint.swing_twist) |limits| {
            try validateAngularRange(limits.swing_y_radians, joint.joint_id.value.bytes, "swing_twist.swing_y_radians", collector);
            try validateAngularRange(limits.swing_z_radians, joint.joint_id.value.bytes, "swing_twist.swing_z_radians", collector);
            try validateAngularRange(limits.twist_radians, joint.joint_id.value.bytes, "swing_twist.twist_radians", collector);
        }
        if (joint.limit_behavior.stiffness) |value| try validateFinite(value, "joint", joint.joint_id.value.bytes, "limit_behavior.stiffness", collector);
    }

    for (source.controls) |control| {
        try validateUniqueIds(control.semantic_tags, "control", control.control_id.value.bytes, "semantic_tags", collector);
        if (control.mirror_control_id) |mirror_id| {
            if (!hasId(source.controls, "control_id", mirror_id)) {
                try missingOrWrongReference(source, collector, "control", control.control_id.value.bytes, "mirror_control_id", "control", mirror_id.value.bytes);
            }
        }
        if (control.region_id) |region_id| {
            if (!hasId(source.regions, "region_id", region_id)) {
                try missingOrWrongReference(source, collector, "control", control.control_id.value.bytes, "region_id", "region", region_id.value.bytes);
            }
        }
        for (control.driven_targets) |target| try validateDrivenTarget(source, control, target, collector);
        if (control.default_value) |value| try validateControlValue(value, control.control_id.value.bytes, "default_value", collector);
        if (control.limits) |limits| {
            if (limits.minimum) |value| try validateControlValue(value, control.control_id.value.bytes, "limits.minimum", collector);
            if (limits.maximum) |value| try validateControlValue(value, control.control_id.value.bytes, "limits.maximum", collector);
        }
        if (control.control_type == .normalized_slider) try validateNormalizedControl(control, collector);
    }
}

fn schemaSupportsM02TypedExtensions(version: identity.SchemaVersion) bool {
    return version.major > 1 or (version.major == 1 and version.minor >= 1);
}

fn validateAttachments(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
) ValidationError!void {
    for (source.anchors) |anchor| {
        try validateUniqueIds(anchor.semantic_tags, "anchor", anchor.anchor_id.value.bytes, "semantic_tags", collector);
        if (!hasId(source.components, "component_id", anchor.owner_component_id)) {
            try missingOrWrongReference(source, collector, "anchor", anchor.anchor_id.value.bytes, "owner_component_id", "component", anchor.owner_component_id.value.bytes);
        }
        try validateTransform(anchor.local_transform, "anchor", anchor.anchor_id.value.bytes, "local_transform", collector);
        try validateTransformDriver(source, anchor.driver, "anchor", anchor.anchor_id.value.bytes, collector);
        if (anchor.mirror_anchor_id) |mirror_anchor_id| {
            if (!schemaSupportsM02TypedExtensions(source.schema_identity.version)) {
                try emit(collector, .schema_feature_version_mismatch, .identity, "anchor", anchor.anchor_id.value.bytes, "mirror_anchor_id", null, null, "typed anchor mirrors require canonical creature schema 1.1.0 or newer");
            }
            if (!hasId(source.anchors, "anchor_id", mirror_anchor_id)) {
                try missingOrWrongReference(source, collector, "anchor", anchor.anchor_id.value.bytes, "mirror_anchor_id", "anchor", mirror_anchor_id.value.bytes);
            }
        }
    }
    for (source.mount_anchors) |mount| {
        try validateUniqueIds(mount.semantic_tags, "mount_anchor", mount.mount_anchor_id.value.bytes, "semantic_tags", collector);
        if (!hasId(source.components, "component_id", mount.owner_component_id)) {
            try missingOrWrongReference(source, collector, "mount_anchor", mount.mount_anchor_id.value.bytes, "owner_component_id", "component", mount.owner_component_id.value.bytes);
        }
        try validateTransform(mount.local_transform, "mount_anchor", mount.mount_anchor_id.value.bytes, "local_transform", collector);
        try validateTransformDriver(source, mount.driver, "mount_anchor", mount.mount_anchor_id.value.bytes, collector);
    }
    for (source.sockets) |socket| {
        try validateUniqueIds(socket.accepted_component_types, "socket", socket.socket_id.value.bytes, "accepted_component_types", collector);
        try validateUniqueIds(socket.accepted_tags, "socket", socket.socket_id.value.bytes, "accepted_tags", collector);
        try validateUniqueIds(socket.compatibility.profiles, "socket", socket.socket_id.value.bytes, "compatibility.profiles", collector);
        try validateUniqueIds(socket.compatibility.required_tags, "socket", socket.socket_id.value.bytes, "compatibility.required_tags", collector);
        if (!hasId(source.anchors, "anchor_id", socket.anchor_id)) {
            try emit(collector, .socket_missing_anchor, .attachment, "socket", socket.socket_id.value.bytes, "anchor_id", "anchor", socket.anchor_id.value.bytes, "socket must reference an existing anchor");
        }
        if (socket.attachment_requirement == .required and socket.capacity == 0) {
            try emit(collector, .multiplicity_contradiction, .attachment, "socket", socket.socket_id.value.bytes, "capacity", null, null, "required socket capacity must be greater than zero");
        }
        var attachment_count: usize = 0;
        for (source.attachments) |record| {
            if (record.parent_socket_id.eql(socket.socket_id)) attachment_count += 1;
        }
        if (attachment_count > socket.capacity) {
            try emit(collector, .attachment_capacity_exceeded, .attachment, "socket", socket.socket_id.value.bytes, "capacity", null, null, "attachment count exceeds socket capacity");
        }
        if (socket.attachment_requirement == .required and attachment_count == 0) {
            try emit(collector, .multiplicity_contradiction, .attachment, "socket", socket.socket_id.value.bytes, "attachment_requirement", null, null, "required socket must have at least one attachment");
        }
    }
    for (source.attachments) |record| {
        try validateUniqueIds(record.compatibility_profiles, "attachment", record.attachment_id.value.bytes, "compatibility_profiles", collector);
        const socket = findById(source.sockets, "socket_id", record.parent_socket_id);
        if (socket == null) {
            try emit(collector, .attachment_missing_socket, .attachment, "attachment", record.attachment_id.value.bytes, "parent_socket_id", "socket", record.parent_socket_id.value.bytes, "attachment must reference an existing parent socket");
        }
        if (!hasId(source.components, "component_id", record.child_component_id)) {
            try missingOrWrongReference(source, collector, "attachment", record.attachment_id.value.bytes, "child_component_id", "component", record.child_component_id.value.bytes);
        }
        const mount = findById(source.mount_anchors, "mount_anchor_id", record.child_mount_anchor_id);
        if (mount == null) {
            try emit(collector, .attachment_missing_mount_anchor, .attachment, "attachment", record.attachment_id.value.bytes, "child_mount_anchor_id", "mount_anchor", record.child_mount_anchor_id.value.bytes, "attachment must reference an existing child mount anchor");
        } else if (!mount.?.owner_component_id.eql(record.child_component_id)) {
            try emit(collector, .attachment_parent_mismatch, .attachment, "attachment", record.attachment_id.value.bytes, "child_mount_anchor_id", "component", record.child_component_id.value.bytes, "child mount anchor must be owned by the attached child component");
        }
        if (socket) |parent_socket| {
            if (findById(source.components, "component_id", record.child_component_id)) |child| {
                if (!containsId(parent_socket.accepted_component_types, child.component_type)) {
                    try emit(collector, .incompatible_attachment_type, .attachment, "attachment", record.attachment_id.value.bytes, "child_component_id", "component_type", child.component_type.value.bytes, "child component type is not accepted by the parent socket");
                }
                if (findById(source.anchors, "anchor_id", parent_socket.anchor_id)) |parent_anchor| {
                    if (child.parent_component_id == null or !child.parent_component_id.?.eql(parent_anchor.owner_component_id)) {
                        try emit(collector, .attachment_parent_mismatch, .attachment, "attachment", record.attachment_id.value.bytes, "child_component_id", "component", parent_anchor.owner_component_id.value.bytes, "child ownership parent must match the socket anchor owner");
                    }
                }
            }
        }
    }
}

fn validateSemantics(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
) ValidationError!void {
    for (source.regions) |region| {
        try validateUniqueIds(region.semantic_tags, "region", region.region_id.value.bytes, "semantic_tags", collector);
        if (!hasId(source.components, "component_id", region.owner_component_id)) {
            try missingOrWrongReference(source, collector, "region", region.region_id.value.bytes, "owner_component_id", "component", region.owner_component_id.value.bytes);
        }
    }
    for (source.surfaces) |surface| {
        if (!hasId(source.components, "component_id", surface.owner_component_id)) {
            try missingOrWrongReference(source, collector, "surface", surface.surface_id.value.bytes, "owner_component_id", "component", surface.owner_component_id.value.bytes);
        }
        if (!hasId(source.regions, "region_id", surface.region_id)) {
            try emit(collector, .surface_missing_region, .semantic, "surface", surface.surface_id.value.bytes, "region_id", "region", surface.region_id.value.bytes, "surface must reference an existing semantic region");
        }
        if (!hasId(source.material_instances, "material_instance_id", surface.material_instance_id)) {
            try emit(collector, .surface_missing_material, .semantic, "surface", surface.surface_id.value.bytes, "material_instance_id", "material_instance", surface.material_instance_id.value.bytes, "surface must reference an existing material instance");
        }
        if (surface.visibility_metadata_id) |metadata_id| {
            if (!hasId(source.visibility_metadata, "visibility_metadata_id", metadata_id)) {
                try emit(collector, .visibility_reference_missing, .semantic, "surface", surface.surface_id.value.bytes, "visibility_metadata_id", "visibility_metadata", metadata_id.value.bytes, "surface visibility metadata reference does not resolve");
            }
        }
    }
    for (source.landmarks) |landmark| {
        try validateUniqueIds(landmark.semantic_tags, "landmark", landmark.landmark_id.value.bytes, "semantic_tags", collector);
        if (!semanticOwnerExists(source, landmark.owner)) {
            try emit(collector, .semantic_owner_missing, .semantic, "landmark", landmark.landmark_id.value.bytes, "owner", semanticOwnerType(landmark.owner), semanticOwnerId(landmark.owner), "landmark owner reference does not resolve");
        }
        if (landmark.mirror_landmark_id) |mirror_landmark_id| {
            if (!schemaSupportsM02TypedExtensions(source.schema_identity.version)) {
                try emit(collector, .schema_feature_version_mismatch, .identity, "landmark", landmark.landmark_id.value.bytes, "mirror_landmark_id", null, null, "typed landmark mirrors require canonical creature schema 1.1.0 or newer");
            }
            if (!hasId(source.landmarks, "landmark_id", mirror_landmark_id)) {
                try missingOrWrongReference(source, collector, "landmark", landmark.landmark_id.value.bytes, "mirror_landmark_id", "landmark", mirror_landmark_id.value.bytes);
            }
        }
    }
    for (source.shared_seams) |seam| {
        if (seam.members.len < 2) {
            try emit(collector, .seam_missing_member, .semantic, "shared_seam", seam.seam_id.value.bytes, "members", null, null, "shared seam must contain at least two members");
        }
        for (seam.members) |member| {
            const surface = findById(source.surfaces, "surface_id", member.surface_id);
            if (!hasId(source.components, "component_id", member.component_id) or surface == null) {
                try emit(collector, .seam_missing_member, .semantic, "shared_seam", seam.seam_id.value.bytes, "members", "surface", member.surface_id.value.bytes, "shared seam member references must resolve");
            } else if (!surface.?.owner_component_id.eql(member.component_id)) {
                try emit(collector, .seam_member_mismatch, .semantic, "shared_seam", seam.seam_id.value.bytes, "members", "component", member.component_id.value.bytes, "shared seam member surface must be owned by its declared component");
            }
        }
        var first_member_index: usize = 0;
        while (first_member_index < seam.members.len) : (first_member_index += 1) {
            const first = seam.members[first_member_index];
            for (seam.members[first_member_index + 1 ..]) |other| {
                if (first.component_id.eql(other.component_id) and first.surface_id.eql(other.surface_id)) {
                    try emit(collector, .duplicate_id, .identity, "shared_seam", seam.seam_id.value.bytes, "members", "surface", other.surface_id.value.bytes, "shared seam members must be unique");
                }
            }
        }
    }
    for (source.interaction_sites) |site| {
        try validateUniqueIds(site.semantic_tags, "interaction_site", site.site_id.value.bytes, "semantic_tags", collector);
        try validateSiteReferences(source, "interaction_site", site.site_id.value.bytes, site.owner_component_id, site.region_id, site.preferred_anchor_id, collector);
    }
    for (source.effectors) |effector| {
        try validateUniqueIds(effector.semantic_tags, "effector", effector.effector_id.value.bytes, "semantic_tags", collector);
        try validateSiteReferences(source, "effector", effector.effector_id.value.bytes, effector.owner_component_id, effector.region_id, effector.preferred_anchor_id, collector);
    }
}

fn validateMorphology(
    source: *const definition.CanonicalCreatureDefinition,
    binding_schema: morphology.BindingValidationSchema,
    collector: *diagnostics.Collector,
) ValidationError!void {
    for (source.morphology_parameters) |parameter| {
        try validateUniqueIds(parameter.binding_ids, "morphology_parameter", parameter.parameter_id.value.bytes, "binding_ids", collector);
        try validateParameterRanges(parameter, collector);
        try validateResponseCurve(parameter.response_curve, parameter.parameter_id.value.bytes, "response_curve", collector);
        switch (parameter.symmetry) {
            .centered => {},
            .mirrored, .independent_pair => |pair| {
                if (!hasId(source.morphology_parameters, "parameter_id", pair.left_parameter_id)) {
                    try missingOrWrongReference(source, collector, "morphology_parameter", parameter.parameter_id.value.bytes, "symmetry.left_parameter_id", "morphology_parameter", pair.left_parameter_id.value.bytes);
                }
                if (!hasId(source.morphology_parameters, "parameter_id", pair.right_parameter_id)) {
                    try missingOrWrongReference(source, collector, "morphology_parameter", parameter.parameter_id.value.bytes, "symmetry.right_parameter_id", "morphology_parameter", pair.right_parameter_id.value.bytes);
                }
            },
        }
        for (parameter.binding_ids) |binding_id| {
            const binding = findById(source.morphology_bindings, "binding_id", binding_id);
            if (binding == null) {
                try missingOrWrongReference(source, collector, "morphology_parameter", parameter.parameter_id.value.bytes, "binding_ids", "morphology_binding", binding_id.value.bytes);
            } else if (!binding.?.source_parameter_id.eql(parameter.parameter_id)) {
                try emit(collector, .conflicting_binding_ownership, .morphology_binding, "morphology_parameter", parameter.parameter_id.value.bytes, "binding_ids", "morphology_binding", binding_id.value.bytes, "binding source parameter does not match the parameter that owns the binding ID");
            }
        }
    }

    for (source.morphology_bindings) |binding| {
        const parameter = findById(source.morphology_parameters, "parameter_id", binding.source_parameter_id);
        if (parameter == null) {
            try missingOrWrongReference(source, collector, "morphology_binding", binding.binding_id.value.bytes, "source_parameter_id", "morphology_parameter", binding.source_parameter_id.value.bytes);
        } else {
            var ownership_count: usize = 0;
            for (source.morphology_parameters) |candidate| {
                if (containsId(candidate.binding_ids, binding.binding_id)) ownership_count += 1;
            }
            if (ownership_count != 1) {
                try emit(collector, .conflicting_binding_ownership, .morphology_binding, "morphology_binding", binding.binding_id.value.bytes, "source_parameter_id", "morphology_parameter", binding.source_parameter_id.value.bytes, "binding must be owned exactly once by its source parameter");
            }
            if (parameter.?.category == .group and std.meta.activeTag(binding.target) != .morphology_parameter) {
                try emit(collector, .group_writes_low_level_target, .morphology_binding, "morphology_binding", binding.binding_id.value.bytes, "target", @tagName(std.meta.activeTag(binding.target)), morphology.targetIdBytes(binding.target), "group parameters may drive parameters but cannot write low-level targets directly");
            }
        }
        try validateBindingRule(binding, binding_schema, collector);
        try validateBindingTargetReference(source, binding, collector);
        if (binding.response_curve_override) |curve| try validateResponseCurve(curve, binding.binding_id.value.bytes, "response_curve_override", collector);
    }

    var first_index: usize = 0;
    while (first_index < source.morphology_bindings.len) : (first_index += 1) {
        const first = source.morphology_bindings[first_index];
        if (first.writer_role != .authoritative) continue;
        for (source.morphology_bindings[first_index + 1 ..]) |second| {
            if (second.writer_role == .authoritative and morphology.bindingTargetsEqual(first.target, second.target)) {
                try emit(collector, .multiple_authoritative_writers, .morphology_binding, "morphology_binding", second.binding_id.value.bytes, "target", @tagName(std.meta.activeTag(second.target)), morphology.targetIdBytes(second.target), "low-level target property has more than one authoritative writer");
            }
        }
    }

    try validateDependencies(source, collector);
}

fn validateMaterials(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
) ValidationError!void {
    for (source.material_definitions) |material_definition| {
        try validateUniqueIds(material_definition.capabilities, "material_definition", material_definition.material_definition_id.value.bytes, "capabilities", collector);
        var first_index: usize = 0;
        while (first_index < material_definition.property_specs.len) : (first_index += 1) {
            const first = material_definition.property_specs[first_index];
            for (material_definition.property_specs[first_index + 1 ..]) |second| {
                if (first.property_id.eql(second.property_id)) {
                    try emit(collector, .duplicate_id, .identity, "material_property_spec", second.property_id.value.bytes, "property_id", null, null, "material definition property IDs must be unique");
                }
            }
        }
    }
    for (source.material_instances) |instance| {
        const material_definition = findById(source.material_definitions, "material_definition_id", instance.definition_id);
        if (material_definition == null) {
            try emit(collector, .material_definition_missing, .semantic, "material_instance", instance.material_instance_id.value.bytes, "definition_id", "material_definition", instance.definition_id.value.bytes, "material instance definition reference does not resolve");
        }
        var first_index: usize = 0;
        while (first_index < instance.properties.len) : (first_index += 1) {
            const property = instance.properties[first_index];
            for (instance.properties[first_index + 1 ..]) |other| {
                if (property.property_id.eql(other.property_id)) {
                    try emit(collector, .duplicate_id, .identity, "material_property", other.property_id.value.bytes, "property_id", null, null, "material instance property IDs must be unique");
                }
            }
            try validateMaterialPropertyValue(instance.material_instance_id.value.bytes, property, collector);
            if (material_definition) |definition_record| {
                const spec = findMaterialPropertySpec(definition_record.property_specs, property.property_id);
                if (spec == null) {
                    try emit(collector, .material_property_unsupported, .semantic, "material_instance", instance.material_instance_id.value.bytes, "properties", "material_property", property.property_id.value.bytes, "material property is not declared by the referenced definition");
                } else if (!materialValueMatchesKind(property.value, spec.?.value_kind)) {
                    try emit(collector, .material_property_type_mismatch, .value, "material_instance", instance.material_instance_id.value.bytes, "properties", "material_property", property.property_id.value.bytes, "material property value type does not match its definition");
                }
            }
        }
        if (material_definition) |definition_record| {
            for (definition_record.property_specs) |spec| {
                if (spec.required and findMaterialProperty(instance.properties, spec.property_id) == null) {
                    try emit(collector, .material_property_unsupported, .semantic, "material_instance", instance.material_instance_id.value.bytes, "properties", "material_property", spec.property_id.value.bytes, "required material property is missing");
                }
            }
        }
    }
}

fn validateVisibility(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
) ValidationError!void {
    for (source.visibility_metadata) |metadata| {
        var first_source_index: usize = 0;
        while (first_source_index < metadata.coverage_sources.len) : (first_source_index += 1) {
            const first = metadata.coverage_sources[first_source_index];
            for (metadata.coverage_sources[first_source_index + 1 ..]) |other| {
                if (first.source_id.eql(other.source_id)) {
                    try emit(collector, .duplicate_id, .identity, "visibility_metadata", metadata.visibility_metadata_id.value.bytes, "coverage_sources", "coverage_source", other.source_id.value.bytes, "coverage source IDs must be unique within one visibility record");
                }
            }
        }
        switch (metadata.subject) {
            .component => |id| if (!hasId(source.components, "component_id", id)) {
                try emit(collector, .visibility_reference_missing, .semantic, "visibility_metadata", metadata.visibility_metadata_id.value.bytes, "subject", "component", id.value.bytes, "visibility subject component reference does not resolve");
            },
            .surface => |id| if (!hasId(source.surfaces, "surface_id", id)) {
                try emit(collector, .visibility_reference_missing, .semantic, "visibility_metadata", metadata.visibility_metadata_id.value.bytes, "subject", "surface", id.value.bytes, "visibility subject surface reference does not resolve");
            },
            .region => |id| if (!hasId(source.regions, "region_id", id)) {
                try emit(collector, .visibility_reference_missing, .semantic, "visibility_metadata", metadata.visibility_metadata_id.value.bytes, "subject", "region", id.value.bytes, "visibility subject region reference does not resolve");
            },
        }
        if (!isNormalized(metadata.coverage.value)) {
            try emit(collector, .coverage_out_of_range, .value, "visibility_metadata", metadata.visibility_metadata_id.value.bytes, "coverage", null, null, "coverage must be finite and within 0.0 through 1.0");
        }
        if (metadata.coverage_region_id) |region_id| {
            if (!hasId(source.regions, "region_id", region_id)) {
                try emit(collector, .visibility_reference_missing, .semantic, "visibility_metadata", metadata.visibility_metadata_id.value.bytes, "coverage_region_id", "region", region_id.value.bytes, "coverage region reference does not resolve");
            }
        }
        for (metadata.coverage_sources) |contribution| {
            if (!isNormalized(contribution.amount.value)) {
                try emit(collector, .coverage_out_of_range, .value, "visibility_metadata", metadata.visibility_metadata_id.value.bytes, "coverage_sources.amount", "coverage_source", contribution.source_id.value.bytes, "coverage source amount must be finite and within 0.0 through 1.0");
            }
        }
        switch (metadata.visibility_state) {
            .replaced_by_variant => switch (metadata.representation) {
                .variant, .substitution => {},
                .canonical => try emit(collector, .visibility_reference_missing, .semantic, "visibility_metadata", metadata.visibility_metadata_id.value.bytes, "representation", "representation_variant", null, "replaced visibility requires an explicit variant or substitution"),
            },
            else => {},
        }
    }
}

fn validateDependencies(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
) ValidationError!void {
    const dependencies = source.morphology_graph.dependencies;
    for (dependencies) |dependency| {
        try validateUniqueIds(dependency.input_parameter_ids, "morphology_dependency", dependency.dependency_id.value.bytes, "input_parameter_ids", collector);
        try validateUniqueIds(dependency.source_binding_ids, "morphology_dependency", dependency.dependency_id.value.bytes, "source_binding_ids", collector);
        if (!hasId(source.morphology_parameters, "parameter_id", dependency.output_parameter_id)) {
            try emit(collector, .unresolved_dependency, .morphology_binding, "morphology_dependency", dependency.dependency_id.value.bytes, "output_parameter_id", "morphology_parameter", dependency.output_parameter_id.value.bytes, "dependency output parameter does not resolve");
        }
        if (dependency.kind == .derived_value and dependency.input_parameter_ids.len == 0) {
            try emit(collector, .invalid_derived_input_reference, .morphology_binding, "morphology_dependency", dependency.dependency_id.value.bytes, "input_parameter_ids", null, null, "derived dependency must declare at least one input");
        }
        for (dependency.input_parameter_ids) |input_id| {
            if (!hasId(source.morphology_parameters, "parameter_id", input_id)) {
                try emit(collector, .invalid_derived_input_reference, .morphology_binding, "morphology_dependency", dependency.dependency_id.value.bytes, "input_parameter_ids", "morphology_parameter", input_id.value.bytes, "derived dependency input parameter does not resolve");
            }
        }
        for (dependency.source_binding_ids) |binding_id| {
            if (!hasId(source.morphology_bindings, "binding_id", binding_id)) {
                try emit(collector, .unresolved_dependency, .morphology_binding, "morphology_dependency", dependency.dependency_id.value.bytes, "source_binding_ids", "morphology_binding", binding_id.value.bytes, "dependency source binding does not resolve");
            }
        }
        for (dependencies) |other| {
            if (!dependency.dependency_id.eql(other.dependency_id) and dependency.output_parameter_id.eql(other.output_parameter_id)) {
                try emit(collector, .conflicting_binding_ownership, .morphology_binding, "morphology_dependency", other.dependency_id.value.bytes, "output_parameter_id", "morphology_parameter", other.output_parameter_id.value.bytes, "derived output parameter has more than one dependency writer");
            }
        }
        for (dependency.input_parameter_ids) |input_id| {
            if (dependencyPathExists(dependencies, dependency.output_parameter_id, input_id, 0)) {
                try emit(collector, .morphology_dependency_cycle, .graph, "morphology_dependency", dependency.dependency_id.value.bytes, "input_parameter_ids", "morphology_parameter", input_id.value.bytes, "morphology dependency graph contains a cycle");
            }
        }
    }
    for (source.morphology_graph.provenance) |trace| {
        if (!hasId(source.morphology_parameters, "parameter_id", trace.output_parameter_id)) {
            try emit(collector, .unresolved_dependency, .morphology_binding, "morphology_provenance", trace.provenance_id.value.bytes, "output_parameter_id", "morphology_parameter", trace.output_parameter_id.value.bytes, "provenance output parameter does not resolve");
        }
        for (trace.sources) |provenance_source| switch (provenance_source) {
            .parameter => |id| if (!hasId(source.morphology_parameters, "parameter_id", id)) {
                try emit(collector, .unresolved_dependency, .morphology_binding, "morphology_provenance", trace.provenance_id.value.bytes, "sources", "morphology_parameter", id.value.bytes, "provenance parameter source does not resolve");
            },
            .binding => |id| if (!hasId(source.morphology_bindings, "binding_id", id)) {
                try emit(collector, .unresolved_dependency, .morphology_binding, "morphology_provenance", trace.provenance_id.value.bytes, "sources", "morphology_binding", id.value.bytes, "provenance binding source does not resolve");
            },
            .dependency => |id| if (!hasId(dependencies, "dependency_id", id)) {
                try emit(collector, .unresolved_dependency, .morphology_binding, "morphology_provenance", trace.provenance_id.value.bytes, "sources", "morphology_dependency", id.value.bytes, "provenance dependency source does not resolve");
            },
            .preset, .manual_adjustment => {},
        };
    }
}

fn validateParameterRanges(
    parameter: morphology.MorphologyParameter,
    collector: *diagnostics.Collector,
) ValidationError!void {
    const id = parameter.parameter_id.value.bytes;
    try validateDomain(parameter.ranges.hard, id, "ranges.hard", collector);
    if (parameter.ranges.recommended) |recommended| {
        try validateDomain(recommended, id, "ranges.recommended", collector);
        if (!domainWithin(recommended, parameter.ranges.hard)) {
            try emit(collector, .invalid_parameter_range, .value, "morphology_parameter", id, "ranges.recommended", null, null, "recommended range must use the hard-range type and remain within the hard range");
        }
    }
    try validateParameterValue(parameter.ranges.default_value, id, "ranges.default_value", collector);
    if (!domainContains(parameter.ranges.hard, parameter.ranges.default_value)) {
        try emit(collector, .default_outside_hard_range, .value, "morphology_parameter", id, "ranges.default_value", null, null, "parameter default must match its hard-range type and remain inside the hard range");
    }
    if (parameter.unit == .normalized and
        (!normalizedDomain(parameter.ranges.hard) or !normalizedValue(parameter.ranges.default_value)))
    {
        try emit(collector, .invalid_normalized_range, .value, "morphology_parameter", id, "ranges", null, null, "normalized parameter ranges and defaults must remain within 0.0 through 1.0");
    }
}

fn validateDomain(
    domain: morphology.ParameterDomain,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    switch (domain) {
        .float => |range| {
            if (!std.math.isFinite(range.minimum) or !std.math.isFinite(range.maximum)) {
                try emit(collector, .non_finite_value, .value, "morphology_parameter", object_id, property, null, null, "floating parameter ranges must be finite");
            } else if (range.minimum > range.maximum) {
                try emit(collector, .invalid_parameter_range, .value, "morphology_parameter", object_id, property, null, null, "parameter range minimum cannot exceed maximum");
            }
        },
        .integer => |range| if (range.minimum > range.maximum) {
            try emit(collector, .invalid_parameter_range, .value, "morphology_parameter", object_id, property, null, null, "integer parameter range minimum cannot exceed maximum");
        },
        .enumeration => |values| {
            var first_index: usize = 0;
            while (first_index < values.len) : (first_index += 1) {
                for (values[first_index + 1 ..]) |other| {
                    if (values[first_index].eql(other)) {
                        try emit(collector, .duplicate_id, .identity, "morphology_parameter", object_id, property, "enum_value", other.value.bytes, "enumeration domain values must be unique");
                    }
                }
            }
        },
        .boolean => |values| if (!values.allows_false and !values.allows_true) {
            try emit(collector, .invalid_parameter_range, .value, "morphology_parameter", object_id, property, null, null, "Boolean domain must permit at least one value");
        },
    }
}

fn validateParameterValue(
    value: morphology.ParameterValue,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    switch (value) {
        .float => |number| try validateFinite(number, "morphology_parameter", object_id, property, collector),
        else => {},
    }
}

fn validateResponseCurve(
    curve: morphology.ResponseCurve,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    switch (curve) {
        .linear, .smooth => {},
        .custom => |custom| switch (custom) {
            .reference => {},
            .authored_data => |points| for (points) |point| {
                if (!std.math.isFinite(point.input) or !std.math.isFinite(point.output)) {
                    try emit(collector, .non_finite_value, .value, "response_curve", object_id, property, null, null, "custom response curve points must be finite");
                }
            },
        },
    }
}

fn validateBindingRule(
    binding: morphology.MorphologyBinding,
    schema: morphology.BindingValidationSchema,
    collector: *diagnostics.Collector,
) ValidationError!void {
    const target_type = std.meta.activeTag(binding.target);
    const property_id = morphology.targetPropertyId(binding.target);
    var matching_rule: ?morphology.BindingPropertyRule = null;
    for (schema.property_rules) |rule| {
        if (rule.target_type == target_type and rule.property_id.eql(property_id)) {
            matching_rule = rule;
            break;
        }
    }
    if (matching_rule == null) {
        try emit(collector, .unsupported_binding_target_property, .morphology_binding, "morphology_binding", binding.binding_id.value.bytes, "target.property_id", @tagName(target_type), property_id.value.bytes, "target type does not define this property in the active binding schema");
        return;
    }
    var operation_supported = false;
    for (matching_rule.?.allowed_operations) |operation| {
        if (operation == binding.operation) operation_supported = true;
    }
    if (!operation_supported) {
        try emit(collector, .unsupported_target_operation, .morphology_binding, "morphology_binding", binding.binding_id.value.bytes, "operation", @tagName(target_type), property_id.value.bytes, "binding operation is not supported for this target property");
    }
}

fn validateBindingTargetReference(
    source: *const definition.CanonicalCreatureDefinition,
    binding: morphology.MorphologyBinding,
    collector: *diagnostics.Collector,
) ValidationError!void {
    const object_id = binding.binding_id.value.bytes;
    switch (binding.target) {
        .rest_bone_transform => |address| if (!hasId(source.bones, "bone_id", address.target_id)) {
            try missingOrWrongReference(source, collector, "morphology_binding", object_id, "target.target_id", "bone", address.target_id.value.bytes);
        },
        .anchor_transform => |address| if (!hasId(source.anchors, "anchor_id", address.target_id)) {
            try missingOrWrongReference(source, collector, "morphology_binding", object_id, "target.target_id", "anchor", address.target_id.value.bytes);
        },
        .socket => |address| if (!hasId(source.sockets, "socket_id", address.target_id)) {
            try missingOrWrongReference(source, collector, "morphology_binding", object_id, "target.target_id", "socket", address.target_id.value.bytes);
        },
        .material_parameter => |address| if (!hasId(source.material_instances, "material_instance_id", address.target_id)) {
            try missingOrWrongReference(source, collector, "morphology_binding", object_id, "target.target_id", "material_instance", address.target_id.value.bytes);
        },
        .interaction_site => |address| if (!hasId(source.interaction_sites, "site_id", address.target_id)) {
            try missingOrWrongReference(source, collector, "morphology_binding", object_id, "target.target_id", "interaction_site", address.target_id.value.bytes);
        },
        .semantic_landmark => |address| if (!hasId(source.landmarks, "landmark_id", address.target_id)) {
            try missingOrWrongReference(source, collector, "morphology_binding", object_id, "target.target_id", "landmark", address.target_id.value.bytes);
        },
        .morphology_parameter => |address| if (!hasId(source.morphology_parameters, "parameter_id", address.target_id)) {
            try missingOrWrongReference(source, collector, "morphology_binding", object_id, "target.target_id", "morphology_parameter", address.target_id.value.bytes);
        },
        .garment_fitting_surface => |address| if (!hasId(source.surfaces, "surface_id", address.target_id)) {
            try missingOrWrongReference(source, collector, "morphology_binding", object_id, "target.target_id", "surface", address.target_id.value.bytes);
        },
        .mesh_morph_target,
        .corrective_shape_input,
        .collision_geometry,
        .garment_fitting_envelope,
        .soft_tissue_property,
        => {},
    }
}

fn validateDrivenTarget(
    source: *const definition.CanonicalCreatureDefinition,
    control: rig.Control,
    target: rig.DrivenTarget,
    collector: *diagnostics.Collector,
) ValidationError!void {
    const object_id = control.control_id.value.bytes;
    switch (target) {
        .bone => |id| if (!hasId(source.bones, "bone_id", id)) try missingOrWrongReference(source, collector, "control", object_id, "driven_targets", "bone", id.value.bytes),
        .joint => |id| if (!hasId(source.joints, "joint_id", id)) try missingOrWrongReference(source, collector, "control", object_id, "driven_targets", "joint", id.value.bytes),
        .anchor => |id| if (!hasId(source.anchors, "anchor_id", id)) try missingOrWrongReference(source, collector, "control", object_id, "driven_targets", "anchor", id.value.bytes),
        .morphology_parameter => |id| if (!hasId(source.morphology_parameters, "parameter_id", id)) try missingOrWrongReference(source, collector, "control", object_id, "driven_targets", "morphology_parameter", id.value.bytes),
        .constraint => {},
    }
}

fn validateTransformDriver(
    source: *const definition.CanonicalCreatureDefinition,
    driver: attachment.TransformDriver,
    object_type: []const u8,
    object_id: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    switch (driver) {
        .component => |id| if (!hasId(source.components, "component_id", id)) try missingOrWrongReference(source, collector, object_type, object_id, "driver", "component", id.value.bytes),
        .bone => |id| if (!hasId(source.bones, "bone_id", id)) try missingOrWrongReference(source, collector, object_type, object_id, "driver", "bone", id.value.bytes),
        .control => |id| if (!hasId(source.controls, "control_id", id)) try missingOrWrongReference(source, collector, object_type, object_id, "driver", "control", id.value.bytes),
        .anchor => |id| if (!hasId(source.anchors, "anchor_id", id)) try missingOrWrongReference(source, collector, object_type, object_id, "driver", "anchor", id.value.bytes),
    }
}

fn validateSiteReferences(
    source: *const definition.CanonicalCreatureDefinition,
    object_type: []const u8,
    object_id: []const u8,
    owner_component_id: identity.ComponentId,
    region_id: ?identity.RegionId,
    preferred_anchor_id: ?identity.AnchorId,
    collector: *diagnostics.Collector,
) ValidationError!void {
    if (!hasId(source.components, "component_id", owner_component_id)) {
        try emit(collector, .semantic_owner_missing, .semantic, object_type, object_id, "owner_component_id", "component", owner_component_id.value.bytes, "semantic site owner component does not resolve");
    }
    if (region_id) |id| {
        if (!hasId(source.regions, "region_id", id)) {
            try missingOrWrongReference(source, collector, object_type, object_id, "region_id", "region", id.value.bytes);
        }
    }
    if (preferred_anchor_id) |id| {
        if (!hasId(source.anchors, "anchor_id", id)) {
            try missingOrWrongReference(source, collector, object_type, object_id, "preferred_anchor_id", "anchor", id.value.bytes);
        }
    }
}

fn validateControlValue(
    value: rig.ControlValue,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    switch (value) {
        .scalar => |number| try validateFinite(number, "control", object_id, property, collector),
        .vector => |vector| try validateVec3(vector, "control", object_id, property, collector),
        .quaternion => |quaternion| try validateQuaternion(quaternion, "control", object_id, property, collector),
        .transform => |transform| try validateTransform(transform, "control", object_id, property, collector),
    }
}

fn validateNormalizedControl(
    control: rig.Control,
    collector: *diagnostics.Collector,
) ValidationError!void {
    if (control.default_value) |value| switch (value) {
        .scalar => |number| if (!isNormalized(number)) try emit(collector, .invalid_normalized_range, .value, "control", control.control_id.value.bytes, "default_value", null, null, "normalized slider default must be within 0.0 through 1.0"),
        else => try emit(collector, .invalid_normalized_range, .value, "control", control.control_id.value.bytes, "default_value", null, null, "normalized slider default must be a scalar"),
    };
    if (control.limits) |limits| {
        if (limits.minimum) |value| switch (value) {
            .scalar => |number| if (!isNormalized(number)) try emit(collector, .invalid_normalized_range, .value, "control", control.control_id.value.bytes, "limits.minimum", null, null, "normalized slider minimum must be within 0.0 through 1.0"),
            else => try emit(collector, .invalid_normalized_range, .value, "control", control.control_id.value.bytes, "limits.minimum", null, null, "normalized slider minimum must be a scalar"),
        };
        if (limits.maximum) |value| switch (value) {
            .scalar => |number| if (!isNormalized(number)) try emit(collector, .invalid_normalized_range, .value, "control", control.control_id.value.bytes, "limits.maximum", null, null, "normalized slider maximum must be within 0.0 through 1.0"),
            else => try emit(collector, .invalid_normalized_range, .value, "control", control.control_id.value.bytes, "limits.maximum", null, null, "normalized slider maximum must be a scalar"),
        };
    }
}

fn validateTransform(
    transform: math3d.LocalTransform,
    object_type: []const u8,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    try validateVec3(transform.translation_m, object_type, object_id, property, collector);
    try validateQuaternion(transform.rotation, object_type, object_id, property, collector);
    try validateVec3(transform.scale, object_type, object_id, property, collector);
}

fn validateVec3(
    vector: math3d.Vec3,
    object_type: []const u8,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    if (!std.math.isFinite(vector.x) or !std.math.isFinite(vector.y) or !std.math.isFinite(vector.z)) {
        try emit(collector, .non_finite_value, .transform, object_type, object_id, property, null, null, "vector components must be finite");
    }
}

fn validateQuaternion(
    quaternion: math3d.Quaternion,
    object_type: []const u8,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    _ = math3d.Quaternion.initCanonical(quaternion.x, quaternion.y, quaternion.z, quaternion.w) catch |validation_error| {
        const code: diagnostics.Code = if (validation_error == error.NonFiniteQuaternion) .non_finite_value else .malformed_quaternion;
        try emit(collector, code, .transform, object_type, object_id, property, null, null, "quaternion must contain finite components and satisfy the locked unit-length tolerance");
        return;
    };
}

fn validateFinite(
    value: f32,
    object_type: []const u8,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    if (!std.math.isFinite(value)) {
        try emit(collector, .non_finite_value, .value, object_type, object_id, property, null, null, "canonical numeric value must be finite");
    }
}

fn validateAxisRanges(
    ranges: rig.AxisAngularLimits,
    property_prefix: []const u8,
    object_id: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    if (ranges.x) |range| try validateAngularRange(range, object_id, if (std.mem.eql(u8, property_prefix, "preferred_range")) "preferred_range.x" else "hard_range.x", collector);
    if (ranges.y) |range| try validateAngularRange(range, object_id, if (std.mem.eql(u8, property_prefix, "preferred_range")) "preferred_range.y" else "hard_range.y", collector);
    if (ranges.z) |range| try validateAngularRange(range, object_id, if (std.mem.eql(u8, property_prefix, "preferred_range")) "preferred_range.z" else "hard_range.z", collector);
}

fn validateAngularRange(
    range: rig.AngularRange,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    if (!std.math.isFinite(range.minimum_radians) or !std.math.isFinite(range.maximum_radians)) {
        try emit(collector, .non_finite_value, .value, "joint", object_id, property, null, null, "joint range values must be finite");
    } else if (range.minimum_radians > range.maximum_radians) {
        try emit(collector, .invalid_joint_range, .value, "joint", object_id, property, null, null, "joint range minimum cannot exceed maximum");
    }
}

fn validateMaterialPropertyValue(
    instance_id: []const u8,
    property: material.MaterialProperty,
    collector: *diagnostics.Collector,
) ValidationError!void {
    switch (property.value) {
        .linear_srgb_rgba => |color| {
            for (color.channels) |channel| {
                if (!isNormalized(channel)) {
                    try emit(collector, .invalid_material_color, .value, "material_instance", instance_id, "properties", "material_property", property.property_id.value.bytes, "base material color channels must be finite linear-sRGB values within 0.0 through 1.0");
                    break;
                }
            }
        },
        .scalar => |number| try validateFinite(number, "material_instance", instance_id, "properties", collector),
        .vector4 => |vector| for (vector) |number| try validateFinite(number, "material_instance", instance_id, "properties", collector),
        .boolean, .response_reference, .detail_reference => {},
    }
}

fn materialValueMatchesKind(value: material.MaterialPropertyValue, kind: material.MaterialValueKind) bool {
    return switch (value) {
        .linear_srgb_rgba => kind == .linear_srgb_rgba,
        .scalar => kind == .scalar,
        .boolean => kind == .boolean,
        .vector4 => kind == .vector4,
        .response_reference => kind == .response_reference,
        .detail_reference => kind == .detail_reference,
    };
}

fn findMaterialPropertySpec(
    specs: []const material.MaterialPropertySpec,
    property_id: identity.MaterialPropertyId,
) ?material.MaterialPropertySpec {
    for (specs) |spec| if (spec.property_id.eql(property_id)) return spec;
    return null;
}

fn findMaterialProperty(
    properties: []const material.MaterialProperty,
    property_id: identity.MaterialPropertyId,
) ?material.MaterialProperty {
    for (properties) |property| if (property.property_id.eql(property_id)) return property;
    return null;
}

fn domainContains(domain: morphology.ParameterDomain, value: morphology.ParameterValue) bool {
    return switch (domain) {
        .float => |range| switch (value) {
            .float => |number| std.math.isFinite(number) and number >= range.minimum and number <= range.maximum,
            else => false,
        },
        .integer => |range| switch (value) {
            .integer => |number| number >= range.minimum and number <= range.maximum,
            else => false,
        },
        .enumeration => |values| switch (value) {
            .enumeration => |selected| containsId(values, selected),
            else => false,
        },
        .boolean => |values| switch (value) {
            .boolean => |selected| if (selected) values.allows_true else values.allows_false,
            else => false,
        },
    };
}

fn domainWithin(inner: morphology.ParameterDomain, outer: morphology.ParameterDomain) bool {
    return switch (inner) {
        .float => |inner_range| switch (outer) {
            .float => |outer_range| inner_range.minimum >= outer_range.minimum and inner_range.maximum <= outer_range.maximum,
            else => false,
        },
        .integer => |inner_range| switch (outer) {
            .integer => |outer_range| inner_range.minimum >= outer_range.minimum and inner_range.maximum <= outer_range.maximum,
            else => false,
        },
        .enumeration => |inner_values| switch (outer) {
            .enumeration => |outer_values| blk: {
                for (inner_values) |value| if (!containsId(outer_values, value)) break :blk false;
                break :blk true;
            },
            else => false,
        },
        .boolean => |inner_values| switch (outer) {
            .boolean => |outer_values| (!inner_values.allows_false or outer_values.allows_false) and
                (!inner_values.allows_true or outer_values.allows_true),
            else => false,
        },
    };
}

fn normalizedDomain(domain: morphology.ParameterDomain) bool {
    return switch (domain) {
        .float => |range| std.math.isFinite(range.minimum) and std.math.isFinite(range.maximum) and
            range.minimum >= 0 and range.maximum <= 1,
        .integer => |range| range.minimum >= 0 and range.maximum <= 1,
        .enumeration, .boolean => true,
    };
}

fn normalizedValue(value: morphology.ParameterValue) bool {
    return switch (value) {
        .float => |number| isNormalized(number),
        .integer => |number| number >= 0 and number <= 1,
        .enumeration, .boolean => true,
    };
}

fn isNormalized(value: f32) bool {
    return std.math.isFinite(value) and value >= 0 and value <= 1;
}

fn componentParentCycle(items: []const component.Component, start_id: identity.ComponentId) bool {
    var current = start_id;
    var depth: usize = 0;
    while (findById(items, "component_id", current)) |record| {
        const parent_id = record.parent_component_id orelse return false;
        depth += 1;
        if (depth > items.len) return true;
        current = parent_id;
    }
    return false;
}

fn boneParentCycle(items: []const rig.Bone, start_id: identity.BoneId) bool {
    var current = start_id;
    var depth: usize = 0;
    while (findById(items, "bone_id", current)) |record| {
        const parent_id = record.parent_bone_id orelse return false;
        depth += 1;
        if (depth > items.len) return true;
        current = parent_id;
    }
    return false;
}

fn dependencyPathExists(
    dependencies: []const morphology.ParameterDependency,
    from: identity.MorphologyParameterId,
    target: identity.MorphologyParameterId,
    depth: usize,
) bool {
    if (from.eql(target)) return true;
    if (depth >= dependencies.len) return false;
    for (dependencies) |dependency| {
        var consumes_from = false;
        for (dependency.input_parameter_ids) |input| {
            if (input.eql(from)) consumes_from = true;
        }
        if (consumes_from and dependencyPathExists(dependencies, dependency.output_parameter_id, target, depth + 1)) return true;
    }
    return false;
}

fn semanticOwnerExists(
    source: *const definition.CanonicalCreatureDefinition,
    owner: semantics.SemanticOwner,
) bool {
    return switch (owner) {
        .component => |id| hasId(source.components, "component_id", id),
        .surface => |id| hasId(source.surfaces, "surface_id", id),
        .region => |id| hasId(source.regions, "region_id", id),
        .anchor => |id| hasId(source.anchors, "anchor_id", id),
    };
}

fn semanticOwnerType(owner: semantics.SemanticOwner) []const u8 {
    return @tagName(std.meta.activeTag(owner));
}

fn semanticOwnerId(owner: semantics.SemanticOwner) []const u8 {
    return switch (owner) {
        inline else => |id| id.value.bytes,
    };
}

fn validateDuplicateIds(
    items: anytype,
    comptime id_field: []const u8,
    object_type: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    var first_index: usize = 0;
    while (first_index < items.len) : (first_index += 1) {
        const first_id = @field(items[first_index], id_field);
        for (items[first_index + 1 ..]) |other| {
            const other_id = @field(other, id_field);
            if (first_id.eql(other_id)) {
                try emit(collector, .duplicate_id, .identity, object_type, other_id.value.bytes, id_field, null, null, "stable IDs must be unique within their canonical type");
            }
        }
    }
}

fn validateUniqueIds(
    items: anytype,
    object_type: []const u8,
    object_id: []const u8,
    property: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    var first_index: usize = 0;
    while (first_index < items.len) : (first_index += 1) {
        for (items[first_index + 1 ..]) |other| {
            if (items[first_index].eql(other)) {
                try emit(collector, .duplicate_id, .identity, object_type, object_id, property, null, other.value.bytes, "ID sets must not contain duplicate values");
            }
        }
    }
}

fn validateDisplayName(
    display_name: identity.DisplayName,
    object_type: []const u8,
    object_id: []const u8,
    collector: *diagnostics.Collector,
) ValidationError!void {
    if (!std.unicode.utf8ValidateSlice(display_name.bytes)) {
        try emit(collector, .invalid_utf8, .value, object_type, object_id, "display_name", null, null, "display name must contain valid UTF-8");
    }
}

fn hasId(items: anytype, comptime id_field: []const u8, id: anytype) bool {
    return findById(items, id_field, id) != null;
}

fn findById(items: anytype, comptime id_field: []const u8, id: anytype) ?@TypeOf(items[0]) {
    for (items) |item| {
        if (@field(item, id_field).eql(id)) return item;
    }
    return null;
}

fn containsId(items: anytype, id: anytype) bool {
    for (items) |item| if (item.eql(id)) return true;
    return false;
}

fn missingOrWrongReference(
    source: *const definition.CanonicalCreatureDefinition,
    collector: *diagnostics.Collector,
    object_type: []const u8,
    object_id: []const u8,
    property: []const u8,
    reference_type: []const u8,
    reference_id: []const u8,
) ValidationError!void {
    if (anyStableIdExists(source, reference_id)) {
        try emit(collector, .wrong_reference_type, .reference, object_type, object_id, property, reference_type, reference_id, "reference ID exists under a different canonical type");
    } else {
        try emit(collector, .missing_reference, .reference, object_type, object_id, property, reference_type, reference_id, "reference does not resolve to an existing canonical object");
    }
}

fn anyStableIdExists(source: *const definition.CanonicalCreatureDefinition, bytes: []const u8) bool {
    inline for (.{
        .{ source.components, "component_id" },
        .{ source.bones, "bone_id" },
        .{ source.joints, "joint_id" },
        .{ source.controls, "control_id" },
        .{ source.anchors, "anchor_id" },
        .{ source.sockets, "socket_id" },
        .{ source.mount_anchors, "mount_anchor_id" },
        .{ source.attachments, "attachment_id" },
        .{ source.regions, "region_id" },
        .{ source.surfaces, "surface_id" },
        .{ source.landmarks, "landmark_id" },
        .{ source.shared_seams, "seam_id" },
        .{ source.interaction_sites, "site_id" },
        .{ source.effectors, "effector_id" },
        .{ source.morphology_parameters, "parameter_id" },
        .{ source.morphology_bindings, "binding_id" },
        .{ source.morphology_graph.dependencies, "dependency_id" },
        .{ source.material_definitions, "material_definition_id" },
        .{ source.material_instances, "material_instance_id" },
        .{ source.visibility_metadata, "visibility_metadata_id" },
    }) |entry| {
        for (entry[0]) |item| {
            if (std.mem.eql(u8, @field(item, entry[1]).value.bytes, bytes)) return true;
        }
    }
    return false;
}

fn emit(
    collector: *diagnostics.Collector,
    code: diagnostics.Code,
    category: diagnostics.Category,
    object_type: []const u8,
    object_id: ?[]const u8,
    property: ?[]const u8,
    reference_type: ?[]const u8,
    reference_id: ?[]const u8,
    message: []const u8,
) ValidationError!void {
    try collector.add(.{
        .severity = .@"error",
        .code = code,
        .category = category,
        .object_type = object_type,
        .object_id = object_id,
        .property = property,
        .reference_type = reference_type,
        .reference_id = reference_id,
        .message = message,
    });
}
