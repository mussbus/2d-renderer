const std = @import("std");
const attachment = @import("attachment.zig");
const component = @import("component.zig");
const coordinate = @import("coordinate.zig");
const identity = @import("identity.zig");
const material = @import("material.zig");
const math3d = @import("math3d.zig");
const morphology = @import("morphology.zig");
const normalization = @import("normalization.zig");
const rig = @import("rig.zig");
const semantics = @import("semantics.zig");
const visibility = @import("visibility.zig");

pub const SerializationError = error{
    OutputTooSmall,
    NonFiniteFloat,
    InvalidQuaternion,
    InvalidNormalizedCollection,
};

const ByteWriter = struct {
    output: []u8,
    count: usize = 0,

    fn write(self: *ByteWriter, input: []const u8) SerializationError!void {
        if (input.len > self.output.len - self.count) return error.OutputTooSmall;
        @memcpy(self.output[self.count..][0..input.len], input);
        self.count += input.len;
    }

    fn byte(self: *ByteWriter, value: u8) SerializationError!void {
        if (self.count == self.output.len) return error.OutputTooSmall;
        self.output[self.count] = value;
        self.count += 1;
    }

    fn bytes(self: *ByteWriter) []const u8 {
        return self.output[0..self.count];
    }
};

pub fn serialize(
    normalized: normalization.NormalizedDefinition,
    output: []u8,
) SerializationError![]const u8 {
    var writer = ByteWriter{ .output = output };
    const source = normalized.source;
    try writer.write("{\"schema_identity\":");
    try writeSchemaIdentity(&writer, source.schema_identity);
    try writer.write(",\"asset_identity\":");
    try writeAssetIdentity(&writer, source.asset_identity);
    try writer.write(",\"compiler_identity\":");
    try writeCompilerIdentity(&writer, source.compiler_identity);
    try writer.write(",\"coordinate_contract\":");
    try writeCoordinateContract(&writer, normalized.coordinate_contract);
    try writer.write(",\"components\":");
    try writeSortedRecords(&writer, source.components, "component_id", writeComponent);
    try writer.write(",\"bones\":");
    try writeSortedRecords(&writer, source.bones, "bone_id", writeBone);
    try writer.write(",\"joints\":");
    try writeSortedRecords(&writer, source.joints, "joint_id", writeJoint);
    try writer.write(",\"controls\":");
    try writeSortedRecords(&writer, source.controls, "control_id", writeControl);
    try writer.write(",\"anchors\":");
    try writeSortedRecords(&writer, source.anchors, "anchor_id", writeAnchor);
    try writer.write(",\"sockets\":");
    try writeSortedRecords(&writer, source.sockets, "socket_id", writeSocket);
    try writer.write(",\"mount_anchors\":");
    try writeSortedRecords(&writer, source.mount_anchors, "mount_anchor_id", writeMountAnchor);
    try writer.write(",\"attachments\":");
    try writeSortedRecords(&writer, source.attachments, "attachment_id", writeAttachment);
    try writer.write(",\"regions\":");
    try writeSortedRecords(&writer, source.regions, "region_id", writeRegion);
    try writer.write(",\"surfaces\":");
    try writeSortedRecords(&writer, source.surfaces, "surface_id", writeSurface);
    try writer.write(",\"landmarks\":");
    try writeSortedRecords(&writer, source.landmarks, "landmark_id", writeLandmark);
    try writer.write(",\"shared_seams\":");
    try writeSortedRecords(&writer, source.shared_seams, "seam_id", writeSharedSeam);
    try writer.write(",\"interaction_sites\":");
    try writeSortedRecords(&writer, source.interaction_sites, "site_id", writeInteractionSite);
    try writer.write(",\"effectors\":");
    try writeSortedRecords(&writer, source.effectors, "effector_id", writeEffector);
    try writer.write(",\"morphology_parameters\":");
    try writeSortedRecords(&writer, source.morphology_parameters, "parameter_id", writeMorphologyParameter);
    try writer.write(",\"morphology_bindings\":");
    try writeSortedRecords(&writer, source.morphology_bindings, "binding_id", writeMorphologyBinding);
    try writer.write(",\"morphology_dependencies\":");
    try writeSortedRecords(&writer, source.morphology_graph.dependencies, "dependency_id", writeMorphologyDependency);
    try writer.write(",\"morphology_provenance\":");
    try writeSortedRecords(&writer, source.morphology_graph.provenance, "provenance_id", writeMorphologyProvenance);
    try writer.write(",\"material_definitions\":");
    try writeSortedRecords(&writer, source.material_definitions, "material_definition_id", writeMaterialDefinition);
    try writer.write(",\"material_instances\":");
    try writeSortedRecords(&writer, source.material_instances, "material_instance_id", writeMaterialInstance);
    try writer.write(",\"visibility_metadata\":");
    try writeSortedRecords(&writer, source.visibility_metadata, "visibility_metadata_id", writeVisibilityMetadata);
    try writer.byte('}');
    return writer.bytes();
}

pub fn serializeF32(value: f32, output: []u8) SerializationError![]const u8 {
    var writer = ByteWriter{ .output = output };
    try writeF32(&writer, value);
    return writer.bytes();
}

fn writeSchemaIdentity(writer: *ByteWriter, value: identity.SchemaIdentity) SerializationError!void {
    try writer.write("{\"schema_id\":");
    try writeId(writer, value.schema_id);
    try writer.write(",\"version\":");
    try writeVersion(writer, value.version);
    try writer.byte('}');
}

fn writeAssetIdentity(writer: *ByteWriter, value: identity.AssetIdentity) SerializationError!void {
    try writer.write("{\"asset_id\":");
    try writeId(writer, value.asset_id);
    try writer.write(",\"display_name\":");
    try writeString(writer, value.display_name.bytes);
    try writer.write(",\"version\":");
    try writeVersion(writer, value.version);
    try writer.byte('}');
}

fn writeCompilerIdentity(writer: *ByteWriter, value: identity.CompilerIdentity) SerializationError!void {
    try writer.write("{\"compiler_id\":");
    try writeId(writer, value.compiler_id);
    try writer.write(",\"version\":");
    try writeVersion(writer, value.version);
    try writer.byte('}');
}

fn writeVersion(writer: *ByteWriter, value: anytype) SerializationError!void {
    try writer.write("{\"major\":");
    try writeUnsigned(writer, value.major);
    try writer.write(",\"minor\":");
    try writeUnsigned(writer, value.minor);
    try writer.write(",\"patch\":");
    try writeUnsigned(writer, value.patch);
    try writer.byte('}');
}

fn writeCoordinateContract(writer: *ByteWriter, value: coordinate.CoordinateContract) SerializationError!void {
    try writer.write("{\"unit\":");
    try writeEnum(writer, value.unit);
    try writer.write(",\"numeric_precision\":");
    try writeEnum(writer, value.numeric_precision);
    try writer.write(",\"authoring_step_m\":");
    try writeF32(writer, value.authoring_step_m);
    try writer.write(",\"handedness\":");
    try writeEnum(writer, value.handedness);
    try writer.write(",\"world_viewer_right\":");
    try writeEnum(writer, value.world_viewer_right);
    try writer.write(",\"up\":");
    try writeEnum(writer, value.up);
    try writer.write(",\"toward_camera\":");
    try writeEnum(writer, value.toward_camera);
    try writer.write(",\"away_from_camera\":");
    try writeEnum(writer, value.away_from_camera);
    try writer.write(",\"canonical_forward\":");
    try writeEnum(writer, value.canonical_forward);
    try writer.write(",\"ground_y_m\":");
    try writeF32(writer, value.ground_y_m);
    try writer.write(",\"asset_origin\":");
    try writeEnum(writer, value.asset_origin);
    try writer.write(",\"canonical_height_m\":");
    try writeF32(writer, value.canonical_height_m);
    try writer.write(",\"bind_pose\":");
    try writeEnum(writer, value.bind_pose);
    try writer.write(",\"canonical_angle_unit\":");
    try writeEnum(writer, value.canonical_angle_unit);
    try writer.byte('}');
}

fn writeComponent(writer: *ByteWriter, value: component.Component) SerializationError!void {
    try writer.write("{\"component_id\":");
    try writeId(writer, value.component_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"component_type\":");
    try writeId(writer, value.component_type);
    try writer.write(",\"parent_component_id\":");
    try writeOptionalId(writer, value.parent_component_id);
    try writer.write(",\"semantic_tags\":");
    try writeSortedIds(writer, value.semantic_tags);
    try writer.write(",\"requirement\":");
    try writeEnum(writer, value.requirement);
    try writer.write(",\"default_state\":");
    try writeEnum(writer, value.default_state);
    try writer.write(",\"multiplicity\":{\"minimum\":");
    try writeUnsigned(writer, value.multiplicity.minimum);
    try writer.write(",\"maximum\":");
    if (value.multiplicity.maximum) |maximum| try writeUnsigned(writer, maximum) else try writer.write("null");
    try writer.write("},\"compatibility\":");
    try writeCompatibility(writer, value.compatibility);
    try writer.byte('}');
}

fn writeBone(writer: *ByteWriter, value: rig.Bone) SerializationError!void {
    try writer.write("{\"bone_id\":");
    try writeId(writer, value.bone_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"parent_bone_id\":");
    try writeOptionalId(writer, value.parent_bone_id);
    try writer.write(",\"deforms_mesh\":");
    try writeBool(writer, value.deforms_mesh);
    try writer.write(",\"local_rest_transform\":");
    try writeLocalTransform(writer, value.local_rest_transform);
    try writer.write(",\"semantic_tags\":");
    try writeSortedIds(writer, value.semantic_tags);
    try writer.write(",\"mirror_bone_id\":");
    try writeOptionalId(writer, value.mirror_bone_id);
    try writer.write(",\"display_length_m\":");
    if (value.display_length_m) |length| try writeF32(writer, length) else try writer.write("null");
    try writer.byte('}');
}

fn writeJoint(writer: *ByteWriter, value: rig.Joint) SerializationError!void {
    try writer.write("{\"joint_id\":");
    try writeId(writer, value.joint_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"parent_bone_id\":");
    try writeId(writer, value.parent_bone_id);
    try writer.write(",\"child_bone_id\":");
    try writeId(writer, value.child_bone_id);
    try writer.write(",\"joint_type\":");
    try writeEnum(writer, value.joint_type);
    try writer.write(",\"preferred_range\":");
    try writeAxisAngularLimits(writer, value.preferred_range);
    try writer.write(",\"hard_range\":");
    try writeAxisAngularLimits(writer, value.hard_range);
    try writer.write(",\"preferred_bend_direction\":");
    if (value.preferred_bend_direction) |direction| try writeVec3(writer, direction) else try writer.write("null");
    try writer.write(",\"swing_twist\":");
    if (value.swing_twist) |limits| try writeSwingTwist(writer, limits) else try writer.write("null");
    try writer.write(",\"limit_behavior\":{\"stiffness\":");
    if (value.limit_behavior.stiffness) |stiffness| try writeF32(writer, stiffness) else try writer.write("null");
    try writer.write("},\"mobility_profile_override\":");
    try writeOptionalId(writer, value.mobility_profile_override);
    try writer.byte('}');
}

fn writeControl(writer: *ByteWriter, value: rig.Control) SerializationError!void {
    try writer.write("{\"control_id\":");
    try writeId(writer, value.control_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"control_type\":");
    try writeEnum(writer, value.control_type);
    try writer.write(",\"driven_targets\":[");
    for (value.driven_targets, 0..) |target, index| {
        if (index != 0) try writer.byte(',');
        try writeDrivenTarget(writer, target);
    }
    try writer.write("],\"space\":");
    try writeEnum(writer, value.space);
    try writer.write(",\"mirror_control_id\":");
    try writeOptionalId(writer, value.mirror_control_id);
    try writer.write(",\"default_value\":");
    if (value.default_value) |default_value| try writeControlValue(writer, default_value) else try writer.write("null");
    try writer.write(",\"limits\":");
    if (value.limits) |limits| {
        try writer.write("{\"minimum\":");
        if (limits.minimum) |minimum| try writeControlValue(writer, minimum) else try writer.write("null");
        try writer.write(",\"maximum\":");
        if (limits.maximum) |maximum| try writeControlValue(writer, maximum) else try writer.write("null");
        try writer.byte('}');
    } else try writer.write("null");
    try writer.write(",\"semantic_tags\":");
    try writeSortedIds(writer, value.semantic_tags);
    try writer.write(",\"region_id\":");
    try writeOptionalId(writer, value.region_id);
    try writer.byte('}');
}

fn writeAnchor(writer: *ByteWriter, value: attachment.Anchor) SerializationError!void {
    try writer.write("{\"anchor_id\":");
    try writeId(writer, value.anchor_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"owner_component_id\":");
    try writeId(writer, value.owner_component_id);
    try writer.write(",\"driver\":");
    try writeTransformDriver(writer, value.driver);
    try writer.write(",\"local_transform\":");
    try writeLocalTransform(writer, value.local_transform);
    try writer.write(",\"semantic_tags\":");
    try writeSortedIds(writer, value.semantic_tags);
    try writer.byte('}');
}

fn writeSocket(writer: *ByteWriter, value: attachment.Socket) SerializationError!void {
    try writer.write("{\"socket_id\":");
    try writeId(writer, value.socket_id);
    try writer.write(",\"anchor_id\":");
    try writeId(writer, value.anchor_id);
    try writer.write(",\"accepted_component_types\":");
    try writeSortedIds(writer, value.accepted_component_types);
    try writer.write(",\"accepted_tags\":");
    try writeSortedIds(writer, value.accepted_tags);
    try writer.write(",\"capacity\":");
    try writeUnsigned(writer, value.capacity);
    try writer.write(",\"attachment_requirement\":");
    try writeEnum(writer, value.attachment_requirement);
    try writer.write(",\"compatibility\":");
    try writeCompatibility(writer, value.compatibility);
    try writer.byte('}');
}

fn writeMountAnchor(writer: *ByteWriter, value: attachment.MountAnchor) SerializationError!void {
    try writer.write("{\"mount_anchor_id\":");
    try writeId(writer, value.mount_anchor_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"owner_component_id\":");
    try writeId(writer, value.owner_component_id);
    try writer.write(",\"driver\":");
    try writeTransformDriver(writer, value.driver);
    try writer.write(",\"local_transform\":");
    try writeLocalTransform(writer, value.local_transform);
    try writer.write(",\"semantic_tags\":");
    try writeSortedIds(writer, value.semantic_tags);
    try writer.byte('}');
}

fn writeAttachment(writer: *ByteWriter, value: attachment.Attachment) SerializationError!void {
    try writer.write("{\"attachment_id\":");
    try writeId(writer, value.attachment_id);
    try writer.write(",\"parent_socket_id\":");
    try writeId(writer, value.parent_socket_id);
    try writer.write(",\"child_component_id\":");
    try writeId(writer, value.child_component_id);
    try writer.write(",\"child_mount_anchor_id\":");
    try writeId(writer, value.child_mount_anchor_id);
    try writer.write(",\"compatibility_profiles\":");
    try writeSortedIds(writer, value.compatibility_profiles);
    try writer.byte('}');
}

fn writeRegion(writer: *ByteWriter, value: semantics.Region) SerializationError!void {
    try writer.write("{\"region_id\":");
    try writeId(writer, value.region_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"owner_component_id\":");
    try writeId(writer, value.owner_component_id);
    try writer.write(",\"semantic_tags\":");
    try writeSortedIds(writer, value.semantic_tags);
    try writer.byte('}');
}

fn writeSurface(writer: *ByteWriter, value: semantics.Surface) SerializationError!void {
    try writer.write("{\"surface_id\":");
    try writeId(writer, value.surface_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"owner_component_id\":");
    try writeId(writer, value.owner_component_id);
    try writer.write(",\"region_id\":");
    try writeId(writer, value.region_id);
    try writer.write(",\"material_instance_id\":");
    try writeId(writer, value.material_instance_id);
    try writer.write(",\"coordinate_metadata_id\":");
    try writeOptionalId(writer, value.coordinate_metadata_id);
    try writer.write(",\"visibility_metadata_id\":");
    try writeOptionalId(writer, value.visibility_metadata_id);
    try writer.byte('}');
}

fn writeLandmark(writer: *ByteWriter, value: semantics.Landmark) SerializationError!void {
    try writer.write("{\"landmark_id\":");
    try writeId(writer, value.landmark_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"owner\":");
    try writeTaggedId(writer, value.owner);
    try writer.write(",\"coordinate_metadata_id\":");
    try writeOptionalId(writer, value.coordinate_metadata_id);
    try writer.write(",\"semantic_tags\":");
    try writeSortedIds(writer, value.semantic_tags);
    try writer.byte('}');
}

fn writeSharedSeam(writer: *ByteWriter, value: semantics.SharedSeam) SerializationError!void {
    try writer.write("{\"seam_id\":");
    try writeId(writer, value.seam_id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, value.display_name);
    try writer.write(",\"members\":[");
    for (value.members, 0..) |member, index| {
        if (index != 0) try writer.byte(',');
        try writer.write("{\"component_id\":");
        try writeId(writer, member.component_id);
        try writer.write(",\"surface_id\":");
        try writeId(writer, member.surface_id);
        try writer.byte('}');
    }
    try writer.write("],\"coordinate_metadata_id\":");
    try writeOptionalId(writer, value.coordinate_metadata_id);
    try writer.byte('}');
}

fn writeInteractionSite(writer: *ByteWriter, value: semantics.InteractionSite) SerializationError!void {
    try writeSiteFields(writer, "site_id", value.site_id, value.display_name, value.owner_component_id, value.region_id, value.preferred_anchor_id, value.semantic_tags, value.approach_metadata_id, value.orientation_metadata_id, value.capacity, value.occupancy_policy_id);
}

fn writeEffector(writer: *ByteWriter, value: semantics.Effector) SerializationError!void {
    try writeSiteFields(writer, "effector_id", value.effector_id, value.display_name, value.owner_component_id, value.region_id, value.preferred_anchor_id, value.semantic_tags, value.approach_metadata_id, value.orientation_metadata_id, value.capacity, value.occupancy_policy_id);
}

fn writeMorphologyParameter(writer: *ByteWriter, value: morphology.MorphologyParameter) SerializationError!void {
    try writer.write("{\"parameter_id\":");
    try writeId(writer, value.parameter_id);
    try writer.write(",\"display_name\":");
    try writeString(writer, value.display_name.bytes);
    try writer.write(",\"category\":");
    try writeEnum(writer, value.category);
    try writer.write(",\"unit\":");
    try writeEnum(writer, value.unit);
    try writer.write(",\"ranges\":{\"default_value\":");
    try writeParameterValue(writer, value.ranges.default_value);
    try writer.write(",\"recommended\":");
    if (value.ranges.recommended) |recommended| try writeParameterDomain(writer, recommended) else try writer.write("null");
    try writer.write(",\"hard\":");
    try writeParameterDomain(writer, value.ranges.hard);
    try writer.write("},\"response_curve\":");
    try writeResponseCurve(writer, value.response_curve);
    try writer.write(",\"symmetry\":");
    try writeSymmetry(writer, value.symmetry);
    try writer.write(",\"topology_policy\":");
    try writeEnum(writer, value.topology_policy);
    try writer.write(",\"binding_ids\":");
    try writeSortedIds(writer, value.binding_ids);
    try writer.byte('}');
}

fn writeMorphologyBinding(writer: *ByteWriter, value: morphology.MorphologyBinding) SerializationError!void {
    try writer.write("{\"binding_id\":");
    try writeId(writer, value.binding_id);
    try writer.write(",\"source_parameter_id\":");
    try writeId(writer, value.source_parameter_id);
    try writer.write(",\"target\":");
    try writeBindingTarget(writer, value.target);
    try writer.write(",\"operation\":");
    try writeEnum(writer, value.operation);
    try writer.write(",\"writer_role\":");
    try writeEnum(writer, value.writer_role);
    try writer.write(",\"resolution_stage\":");
    try writeEnum(writer, value.resolution_stage);
    try writer.write(",\"response_curve_override\":");
    if (value.response_curve_override) |curve| try writeResponseCurve(writer, curve) else try writer.write("null");
    try writer.byte('}');
}

fn writeMorphologyDependency(writer: *ByteWriter, value: morphology.ParameterDependency) SerializationError!void {
    try writer.write("{\"dependency_id\":");
    try writeId(writer, value.dependency_id);
    try writer.write(",\"kind\":");
    try writeEnum(writer, value.kind);
    try writer.write(",\"input_parameter_ids\":");
    try writeSortedIds(writer, value.input_parameter_ids);
    try writer.write(",\"output_parameter_id\":");
    try writeId(writer, value.output_parameter_id);
    try writer.write(",\"source_binding_ids\":");
    try writeSortedIds(writer, value.source_binding_ids);
    try writer.write(",\"resolution_stage\":");
    try writeEnum(writer, value.resolution_stage);
    try writer.byte('}');
}

fn writeMorphologyProvenance(writer: *ByteWriter, value: morphology.ProvenanceTrace) SerializationError!void {
    try writer.write("{\"provenance_id\":");
    try writeId(writer, value.provenance_id);
    try writer.write(",\"output_parameter_id\":");
    try writeId(writer, value.output_parameter_id);
    try writer.write(",\"sources\":[");
    for (value.sources, 0..) |source, index| {
        if (index != 0) try writer.byte(',');
        switch (source) {
            inline .parameter, .binding, .dependency, .preset => |id, tag| {
                try writer.write("{\"source_type\":");
                try writeString(writer, @tagName(tag));
                try writer.write(",\"source_id\":");
                try writeId(writer, id);
                try writer.byte('}');
            },
            .manual_adjustment => try writer.write("{\"source_type\":\"manual_adjustment\"}"),
        }
    }
    try writer.write("]}");
}

fn writeParameterValue(writer: *ByteWriter, value: morphology.ParameterValue) SerializationError!void {
    switch (value) {
        .float => |number| {
            try writer.write("{\"value_type\":\"float\",\"value\":");
            try writeF32(writer, number);
        },
        .integer => |number| {
            try writer.write("{\"value_type\":\"integer\",\"value\":");
            try writeSigned(writer, number);
        },
        .enumeration => |id| {
            try writer.write("{\"value_type\":\"enumeration\",\"value\":");
            try writeId(writer, id);
        },
        .boolean => |boolean| {
            try writer.write("{\"value_type\":\"boolean\",\"value\":");
            try writeBool(writer, boolean);
        },
    }
    try writer.byte('}');
}

fn writeParameterDomain(writer: *ByteWriter, value: morphology.ParameterDomain) SerializationError!void {
    switch (value) {
        .float => |range| {
            try writer.write("{\"value_type\":\"float\",\"minimum\":");
            try writeF32(writer, range.minimum);
            try writer.write(",\"maximum\":");
            try writeF32(writer, range.maximum);
        },
        .integer => |range| {
            try writer.write("{\"value_type\":\"integer\",\"minimum\":");
            try writeSigned(writer, range.minimum);
            try writer.write(",\"maximum\":");
            try writeSigned(writer, range.maximum);
        },
        .enumeration => |ids| {
            try writer.write("{\"value_type\":\"enumeration\",\"values\":");
            try writeSortedIds(writer, ids);
        },
        .boolean => |domain| {
            try writer.write("{\"value_type\":\"boolean\",\"allows_false\":");
            try writeBool(writer, domain.allows_false);
            try writer.write(",\"allows_true\":");
            try writeBool(writer, domain.allows_true);
        },
    }
    try writer.byte('}');
}

fn writeResponseCurve(writer: *ByteWriter, value: morphology.ResponseCurve) SerializationError!void {
    switch (value) {
        .linear => try writer.write("{\"curve_type\":\"linear\"}"),
        .smooth => try writer.write("{\"curve_type\":\"smooth\"}"),
        .custom => |custom| switch (custom) {
            .reference => |id| {
                try writer.write("{\"curve_type\":\"custom_reference\",\"curve_id\":");
                try writeId(writer, id);
                try writer.byte('}');
            },
            .authored_data => |points| {
                try writer.write("{\"curve_type\":\"custom_data\",\"points\":[");
                for (points, 0..) |point, index| {
                    if (index != 0) try writer.byte(',');
                    try writer.write("{\"input\":");
                    try writeF32(writer, point.input);
                    try writer.write(",\"output\":");
                    try writeF32(writer, point.output);
                    try writer.byte('}');
                }
                try writer.write("]}");
            },
        },
    }
}

fn writeMaterialDefinition(writer: *ByteWriter, value: material.MaterialDefinition) SerializationError!void {
    try writer.write("{\"material_definition_id\":");
    try writeId(writer, value.material_definition_id);
    try writer.write(",\"display_name\":");
    try writeString(writer, value.display_name.bytes);
    try writer.write(",\"capabilities\":");
    try writeSortedIds(writer, value.capabilities);
    try writer.write(",\"property_specs\":");
    try writeSortedRecords(writer, value.property_specs, "property_id", writeMaterialPropertySpec);
    try writer.byte('}');
}

fn writeMaterialPropertySpec(writer: *ByteWriter, value: material.MaterialPropertySpec) SerializationError!void {
    try writer.write("{\"property_id\":");
    try writeId(writer, value.property_id);
    try writer.write(",\"value_kind\":");
    try writeEnum(writer, value.value_kind);
    try writer.write(",\"required\":");
    try writeBool(writer, value.required);
    try writer.byte('}');
}

fn writeMaterialInstance(writer: *ByteWriter, value: material.MaterialInstance) SerializationError!void {
    try writer.write("{\"material_instance_id\":");
    try writeId(writer, value.material_instance_id);
    try writer.write(",\"display_name\":");
    try writeString(writer, value.display_name.bytes);
    try writer.write(",\"definition_id\":");
    try writeId(writer, value.definition_id);
    try writer.write(",\"properties\":");
    try writeSortedRecords(writer, value.properties, "property_id", writeMaterialProperty);
    try writer.byte('}');
}

fn writeMaterialProperty(writer: *ByteWriter, value: material.MaterialProperty) SerializationError!void {
    try writer.write("{\"property_id\":");
    try writeId(writer, value.property_id);
    try writer.write(",\"value\":");
    switch (value.value) {
        .linear_srgb_rgba => |color| {
            try writer.write("{\"value_type\":\"linear_srgb_rgba\",\"channels\":[");
            for (color.channels, 0..) |channel, index| {
                if (index != 0) try writer.byte(',');
                try writeF32(writer, channel);
            }
            try writer.write("]}");
        },
        .scalar => |number| {
            try writer.write("{\"value_type\":\"scalar\",\"value\":");
            try writeF32(writer, number);
            try writer.byte('}');
        },
        .boolean => |boolean| {
            try writer.write("{\"value_type\":\"boolean\",\"value\":");
            try writeBool(writer, boolean);
            try writer.byte('}');
        },
        .vector4 => |vector| {
            try writer.write("{\"value_type\":\"vector4\",\"value\":[");
            for (vector, 0..) |number, index| {
                if (index != 0) try writer.byte(',');
                try writeF32(writer, number);
            }
            try writer.write("]}");
        },
        .response_reference => |id| {
            try writer.write("{\"value_type\":\"response_reference\",\"value\":");
            try writeId(writer, id);
            try writer.byte('}');
        },
        .detail_reference => |id| {
            try writer.write("{\"value_type\":\"detail_reference\",\"value\":");
            try writeId(writer, id);
            try writer.byte('}');
        },
    }
    try writer.byte('}');
}

fn writeVisibilityMetadata(writer: *ByteWriter, value: visibility.VisibilityCoverageMetadata) SerializationError!void {
    try writer.write("{\"visibility_metadata_id\":");
    try writeId(writer, value.visibility_metadata_id);
    try writer.write(",\"subject\":");
    try writeTaggedId(writer, value.subject);
    try writer.write(",\"component_existence\":");
    try writeEnum(writer, value.component_existence);
    try writer.write(",\"component_enabled_state\":");
    try writeEnum(writer, value.component_enabled_state);
    try writer.write(",\"visibility_state\":");
    try writeEnum(writer, value.visibility_state);
    try writer.write(",\"coverage\":");
    try writeF32(writer, value.coverage.value);
    try writer.write(",\"coverage_region_id\":");
    try writeOptionalId(writer, value.coverage_region_id);
    try writer.write(",\"coverage_sources\":");
    try writeSortedRecords(writer, value.coverage_sources, "source_id", writeCoverageContribution);
    try writer.write(",\"representation\":");
    switch (value.representation) {
        .canonical => try writer.write("{\"selection_type\":\"canonical\"}"),
        .variant => |id| {
            try writer.write("{\"selection_type\":\"variant\",\"variant_id\":");
            try writeId(writer, id);
            try writer.byte('}');
        },
        .substitution => |id| {
            try writer.write("{\"selection_type\":\"substitution\",\"variant_id\":");
            try writeId(writer, id);
            try writer.byte('}');
        },
    }
    try writer.byte('}');
}

fn writeCoverageContribution(writer: *ByteWriter, value: visibility.CoverageContribution) SerializationError!void {
    try writer.write("{\"source_type\":");
    try writeEnum(writer, value.source_type);
    try writer.write(",\"source_id\":");
    try writeId(writer, value.source_id);
    try writer.write(",\"amount\":");
    try writeF32(writer, value.amount.value);
    try writer.byte('}');
}

fn writeCompatibility(writer: *ByteWriter, value: component.CompatibilityRequirements) SerializationError!void {
    try writer.write("{\"profiles\":");
    try writeSortedIds(writer, value.profiles);
    try writer.write(",\"required_tags\":");
    try writeSortedIds(writer, value.required_tags);
    try writer.byte('}');
}

fn writeLocalTransform(writer: *ByteWriter, value: math3d.LocalTransform) SerializationError!void {
    try writer.write("{\"translation_m\":");
    try writeVec3(writer, value.translation_m);
    try writer.write(",\"rotation\":[");
    const canonical = math3d.Quaternion.initCanonical(value.rotation.x, value.rotation.y, value.rotation.z, value.rotation.w) catch return error.InvalidQuaternion;
    try writeF32(writer, canonical.x);
    try writer.byte(',');
    try writeF32(writer, canonical.y);
    try writer.byte(',');
    try writeF32(writer, canonical.z);
    try writer.byte(',');
    try writeF32(writer, canonical.w);
    try writer.write("],\"scale\":");
    try writeVec3(writer, value.scale);
    try writer.byte('}');
}

fn writeVec3(writer: *ByteWriter, value: math3d.Vec3) SerializationError!void {
    try writer.byte('[');
    try writeF32(writer, value.x);
    try writer.byte(',');
    try writeF32(writer, value.y);
    try writer.byte(',');
    try writeF32(writer, value.z);
    try writer.byte(']');
}

fn writeAngularRange(writer: *ByteWriter, value: rig.AngularRange) SerializationError!void {
    try writer.write("{\"minimum_radians\":");
    try writeF32(writer, value.minimum_radians);
    try writer.write(",\"maximum_radians\":");
    try writeF32(writer, value.maximum_radians);
    try writer.byte('}');
}

fn writeAxisAngularLimits(writer: *ByteWriter, value: rig.AxisAngularLimits) SerializationError!void {
    try writer.write("{\"x\":");
    if (value.x) |range| try writeAngularRange(writer, range) else try writer.write("null");
    try writer.write(",\"y\":");
    if (value.y) |range| try writeAngularRange(writer, range) else try writer.write("null");
    try writer.write(",\"z\":");
    if (value.z) |range| try writeAngularRange(writer, range) else try writer.write("null");
    try writer.byte('}');
}

fn writeSwingTwist(writer: *ByteWriter, value: rig.SwingTwistConstraints) SerializationError!void {
    try writer.write("{\"swing_y_radians\":");
    try writeAngularRange(writer, value.swing_y_radians);
    try writer.write(",\"swing_z_radians\":");
    try writeAngularRange(writer, value.swing_z_radians);
    try writer.write(",\"twist_radians\":");
    try writeAngularRange(writer, value.twist_radians);
    try writer.byte('}');
}

fn writeDrivenTarget(writer: *ByteWriter, value: rig.DrivenTarget) SerializationError!void {
    try writeTaggedId(writer, value);
}

fn writeControlValue(writer: *ByteWriter, value: rig.ControlValue) SerializationError!void {
    switch (value) {
        .scalar => |number| {
            try writer.write("{\"value_type\":\"scalar\",\"value\":");
            try writeF32(writer, number);
        },
        .vector => |vector| {
            try writer.write("{\"value_type\":\"vector\",\"value\":");
            try writeVec3(writer, vector);
        },
        .quaternion => |quaternion| {
            const canonical = math3d.Quaternion.initCanonical(quaternion.x, quaternion.y, quaternion.z, quaternion.w) catch return error.InvalidQuaternion;
            try writer.write("{\"value_type\":\"quaternion\",\"value\":[");
            try writeF32(writer, canonical.x);
            try writer.byte(',');
            try writeF32(writer, canonical.y);
            try writer.byte(',');
            try writeF32(writer, canonical.z);
            try writer.byte(',');
            try writeF32(writer, canonical.w);
            try writer.byte(']');
        },
        .transform => |transform| {
            try writer.write("{\"value_type\":\"transform\",\"value\":");
            try writeLocalTransform(writer, transform);
        },
    }
    try writer.byte('}');
}

fn writeTransformDriver(writer: *ByteWriter, value: attachment.TransformDriver) SerializationError!void {
    try writeTaggedId(writer, value);
}

fn writeTaggedId(writer: *ByteWriter, value: anytype) SerializationError!void {
    const tag = std.meta.activeTag(value);
    switch (value) {
        inline else => |id| {
            try writer.write("{\"type\":");
            try writeString(writer, @tagName(tag));
            try writer.write(",\"id\":");
            try writeId(writer, id);
            try writer.byte('}');
        },
    }
}

fn writeSiteFields(
    writer: *ByteWriter,
    comptime id_field: []const u8,
    id: anytype,
    display_name: ?identity.DisplayName,
    owner_component_id: identity.ComponentId,
    region_id: ?identity.RegionId,
    preferred_anchor_id: ?identity.AnchorId,
    semantic_tags: []const identity.SemanticTagId,
    approach_metadata_id: ?identity.ApproachMetadataId,
    orientation_metadata_id: ?identity.OrientationMetadataId,
    capacity: u32,
    occupancy_policy_id: ?identity.OccupancyPolicyId,
) SerializationError!void {
    try writer.write("{\"");
    try writer.write(id_field);
    try writer.write("\":");
    try writeId(writer, id);
    try writer.write(",\"display_name\":");
    try writeOptionalDisplayName(writer, display_name);
    try writer.write(",\"owner_component_id\":");
    try writeId(writer, owner_component_id);
    try writer.write(",\"region_id\":");
    try writeOptionalId(writer, region_id);
    try writer.write(",\"preferred_anchor_id\":");
    try writeOptionalId(writer, preferred_anchor_id);
    try writer.write(",\"semantic_tags\":");
    try writeSortedIds(writer, semantic_tags);
    try writer.write(",\"approach_metadata_id\":");
    try writeOptionalId(writer, approach_metadata_id);
    try writer.write(",\"orientation_metadata_id\":");
    try writeOptionalId(writer, orientation_metadata_id);
    try writer.write(",\"capacity\":");
    try writeUnsigned(writer, capacity);
    try writer.write(",\"occupancy_policy_id\":");
    try writeOptionalId(writer, occupancy_policy_id);
    try writer.byte('}');
}

fn writeSymmetry(writer: *ByteWriter, value: morphology.Symmetry) SerializationError!void {
    switch (value) {
        .centered => try writer.write("{\"symmetry_type\":\"centered\"}"),
        .mirrored, .independent_pair => |pair, tag| {
            try writer.write("{\"symmetry_type\":");
            try writeString(writer, @tagName(tag));
            try writer.write(",\"left_parameter_id\":");
            try writeId(writer, pair.left_parameter_id);
            try writer.write(",\"right_parameter_id\":");
            try writeId(writer, pair.right_parameter_id);
            try writer.write(",\"linked_by_default\":");
            try writeBool(writer, pair.linked_by_default);
            try writer.byte('}');
        },
    }
}

fn writeBindingTarget(writer: *ByteWriter, value: morphology.BindingTarget) SerializationError!void {
    const tag = std.meta.activeTag(value);
    switch (value) {
        inline else => |address| {
            try writer.write("{\"target_type\":");
            try writeString(writer, @tagName(tag));
            try writer.write(",\"target_id\":");
            try writeId(writer, address.target_id);
            try writer.write(",\"property_id\":");
            try writeId(writer, address.property_id);
            try writer.byte('}');
        },
    }
}

fn writeSortedRecords(
    writer: *ByteWriter,
    items: anytype,
    comptime id_field: []const u8,
    comptime writeRecord: anytype,
) SerializationError!void {
    try writer.byte('[');
    var previous_id: ?[]const u8 = null;
    var emitted: usize = 0;
    while (emitted < items.len) : (emitted += 1) {
        var selected: ?usize = null;
        for (items, 0..) |item, index| {
            const id_bytes = @field(item, id_field).value.bytes;
            if (previous_id) |previous| {
                if (std.mem.order(u8, id_bytes, previous) != .gt) continue;
            }
            if (selected == null or std.mem.order(u8, id_bytes, @field(items[selected.?], id_field).value.bytes) == .lt) {
                selected = index;
            }
        }
        if (selected == null) return error.InvalidNormalizedCollection;
        if (emitted != 0) try writer.byte(',');
        try writeRecord(writer, items[selected.?]);
        previous_id = @field(items[selected.?], id_field).value.bytes;
    }
    try writer.byte(']');
}

fn writeSortedIds(writer: *ByteWriter, items: anytype) SerializationError!void {
    try writer.byte('[');
    var previous_id: ?[]const u8 = null;
    var emitted: usize = 0;
    while (emitted < items.len) : (emitted += 1) {
        var selected: ?usize = null;
        for (items, 0..) |item, index| {
            const id_bytes = item.value.bytes;
            if (previous_id) |previous| {
                if (std.mem.order(u8, id_bytes, previous) != .gt) continue;
            }
            if (selected == null or std.mem.order(u8, id_bytes, items[selected.?].value.bytes) == .lt) {
                selected = index;
            }
        }
        if (selected == null) return error.InvalidNormalizedCollection;
        if (emitted != 0) try writer.byte(',');
        try writeId(writer, items[selected.?]);
        previous_id = items[selected.?].value.bytes;
    }
    try writer.byte(']');
}

fn writeId(writer: *ByteWriter, value: anytype) SerializationError!void {
    try writeString(writer, value.value.bytes);
}

fn writeOptionalId(writer: *ByteWriter, value: anytype) SerializationError!void {
    if (value) |id| try writeId(writer, id) else try writer.write("null");
}

fn writeOptionalDisplayName(writer: *ByteWriter, value: ?identity.DisplayName) SerializationError!void {
    if (value) |name| try writeString(writer, name.bytes) else try writer.write("null");
}

fn writeEnum(writer: *ByteWriter, value: anytype) SerializationError!void {
    try writeString(writer, @tagName(value));
}

fn writeBool(writer: *ByteWriter, value: bool) SerializationError!void {
    try writer.write(if (value) "true" else "false");
}

fn writeUnsigned(writer: *ByteWriter, value: anytype) SerializationError!void {
    var buffer: [32]u8 = undefined;
    const rendered = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch return error.OutputTooSmall;
    try writer.write(rendered);
}

fn writeSigned(writer: *ByteWriter, value: anytype) SerializationError!void {
    var buffer: [32]u8 = undefined;
    const rendered = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch return error.OutputTooSmall;
    try writer.write(rendered);
}

fn writeF32(writer: *ByteWriter, raw_value: f32) SerializationError!void {
    if (!std.math.isFinite(raw_value)) return error.NonFiniteFloat;
    const value = math3d.normalizeZero(raw_value);
    var buffer: [64]u8 = undefined;
    const rendered = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch return error.OutputTooSmall;
    try writer.write(rendered);
}

fn writeString(writer: *ByteWriter, value: []const u8) SerializationError!void {
    try writer.byte('"');
    const hex = "0123456789abcdef";
    for (value) |byte_value| {
        switch (byte_value) {
            '"' => try writer.write("\\\""),
            '\\' => try writer.write("\\\\"),
            '\x08' => try writer.write("\\b"),
            '\x0c' => try writer.write("\\f"),
            '\n' => try writer.write("\\n"),
            '\r' => try writer.write("\\r"),
            '\t' => try writer.write("\\t"),
            0...0x07, 0x0b, 0x0e...0x1f => {
                try writer.write("\\u00");
                try writer.byte(hex[byte_value >> 4]);
                try writer.byte(hex[byte_value & 0x0f]);
            },
            else => try writer.byte(byte_value),
        }
    }
    try writer.byte('"');
}
