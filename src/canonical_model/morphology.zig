const std = @import("std");
const identity = @import("identity.zig");

pub const ParameterCategory = enum {
    structural,
    morphological,
    appearance,
    group,
};

pub const ValueUnit = enum {
    unitless,
    meter,
    normalized,
};

pub const ParameterValue = union(enum) {
    float: f32,
    integer: i64,
    enumeration: identity.EnumValueId,
    boolean: bool,
};

pub const FloatRange = struct {
    minimum: f32,
    maximum: f32,
};

pub const IntegerRange = struct {
    minimum: i64,
    maximum: i64,
};

pub const BooleanDomain = struct {
    allows_false: bool,
    allows_true: bool,
};

pub const ParameterDomain = union(enum) {
    float: FloatRange,
    integer: IntegerRange,
    enumeration: []const identity.EnumValueId,
    boolean: BooleanDomain,
};

pub const ParameterRanges = struct {
    default_value: ParameterValue,
    recommended: ?ParameterDomain,
    hard: ParameterDomain,
};

pub const ResponseCurvePoint = struct {
    input: f32,
    output: f32,
};

pub const CustomResponseCurve = union(enum) {
    reference: identity.ResponseCurveId,
    authored_data: []const ResponseCurvePoint,
};

pub const ResponseCurve = union(enum) {
    linear,
    smooth,
    custom: CustomResponseCurve,
};

pub const PairedParameterIds = struct {
    left_parameter_id: identity.MorphologyParameterId,
    right_parameter_id: identity.MorphologyParameterId,
    linked_by_default: bool,
};

pub const Symmetry = union(enum) {
    centered,
    mirrored: PairedParameterIds,
    independent_pair: PairedParameterIds,
};

pub const TopologyPolicy = enum {
    preserve_existing_topology,
};

pub const MorphologyParameter = struct {
    parameter_id: identity.MorphologyParameterId,
    display_name: identity.DisplayName,
    category: ParameterCategory,
    unit: ValueUnit,
    ranges: ParameterRanges,
    response_curve: ResponseCurve,
    symmetry: Symmetry,
    topology_policy: TopologyPolicy,
    binding_ids: []const identity.MorphologyBindingId,
};

pub fn TargetAddress(comptime IdType: type) type {
    return struct {
        target_id: IdType,
        property_id: identity.PropertyId,
    };
}

pub const BindingTargetType = enum {
    rest_bone_transform,
    anchor_transform,
    socket,
    mesh_morph_target,
    corrective_shape_input,
    material_parameter,
    collision_geometry,
    interaction_site,
    garment_fitting_envelope,
    garment_fitting_surface,
    semantic_landmark,
    soft_tissue_property,
    morphology_parameter,
};

pub const BindingTarget = union(BindingTargetType) {
    rest_bone_transform: TargetAddress(identity.BoneId),
    anchor_transform: TargetAddress(identity.AnchorId),
    socket: TargetAddress(identity.SocketId),
    mesh_morph_target: TargetAddress(identity.MorphTargetId),
    corrective_shape_input: TargetAddress(identity.CorrectiveShapeId),
    material_parameter: TargetAddress(identity.MaterialInstanceId),
    collision_geometry: TargetAddress(identity.CollisionGeometryId),
    interaction_site: TargetAddress(identity.InteractionSiteId),
    garment_fitting_envelope: TargetAddress(identity.GarmentFittingEnvelopeId),
    garment_fitting_surface: TargetAddress(identity.SurfaceId),
    semantic_landmark: TargetAddress(identity.LandmarkId),
    soft_tissue_property: TargetAddress(identity.SoftTissueProfileId),
    morphology_parameter: TargetAddress(identity.MorphologyParameterId),
};

pub const BindingOperation = enum {
    set,
    offset,
    scale,
    weight,
    remap,
    derive,
};

pub const BindingPropertyRule = struct {
    target_type: BindingTargetType,
    property_id: identity.PropertyId,
    allowed_operations: []const BindingOperation,
};

pub const BindingValidationSchema = struct {
    property_rules: []const BindingPropertyRule,

    pub const empty = BindingValidationSchema{ .property_rules = &.{} };
};

pub const WriterRole = enum {
    authoritative,
    contributing,
};

pub const ResolutionStage = enum(u8) {
    structural_parameters = 0,
    rest_skeleton_and_anchors = 1,
    mesh_morphology = 2,
    soft_tissue = 3,
    collisions_and_interaction_sites = 4,
    garment_fitting = 5,
    corrective_validation = 6,
};

pub const MorphologyBinding = struct {
    binding_id: identity.MorphologyBindingId,
    source_parameter_id: identity.MorphologyParameterId,
    target: BindingTarget,
    operation: BindingOperation,
    writer_role: WriterRole,
    resolution_stage: ResolutionStage,
    response_curve_override: ?ResponseCurve,
};

pub const DependencyKind = enum {
    group_drive,
    derived_value,
};

pub const ParameterDependency = struct {
    dependency_id: identity.MorphologyDependencyId,
    kind: DependencyKind,
    input_parameter_ids: []const identity.MorphologyParameterId,
    output_parameter_id: identity.MorphologyParameterId,
    source_binding_ids: []const identity.MorphologyBindingId,
    resolution_stage: ResolutionStage,
};

pub const ProvenanceSource = union(enum) {
    parameter: identity.MorphologyParameterId,
    binding: identity.MorphologyBindingId,
    dependency: identity.MorphologyDependencyId,
    preset: identity.PresetId,
    manual_adjustment,
};

pub const ProvenanceTrace = struct {
    provenance_id: identity.MorphologyProvenanceId,
    output_parameter_id: identity.MorphologyParameterId,
    sources: []const ProvenanceSource,
};

pub const DependencyGraph = struct {
    dependencies: []const ParameterDependency,
    provenance: []const ProvenanceTrace,
};

pub fn targetIdBytes(target: BindingTarget) []const u8 {
    return switch (target) {
        inline else => |address| address.target_id.value.bytes,
    };
}

pub fn targetPropertyId(target: BindingTarget) identity.PropertyId {
    return switch (target) {
        inline else => |address| address.property_id,
    };
}

pub fn bindingTargetsEqual(a: BindingTarget, b: BindingTarget) bool {
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
    return std.mem.eql(u8, targetIdBytes(a), targetIdBytes(b)) and
        targetPropertyId(a).eql(targetPropertyId(b));
}
