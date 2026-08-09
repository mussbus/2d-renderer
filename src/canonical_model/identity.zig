const std = @import("std");

pub const IdError = error{
    EmptyCanonicalId,
    InvalidCanonicalId,
};

pub const DisplayNameError = error{InvalidUtf8DisplayName};

pub const CanonicalId = struct {
    bytes: []const u8,

    pub fn init(bytes: []const u8) IdError!CanonicalId {
        if (bytes.len == 0) return error.EmptyCanonicalId;
        if (!isLowercaseLetter(bytes[0])) return error.InvalidCanonicalId;

        for (bytes[1..]) |byte| {
            if (!isLowercaseLetter(byte) and !std.ascii.isDigit(byte) and byte != '_') {
                return error.InvalidCanonicalId;
            }
        }
        if (bytes[bytes.len - 1] == '_') return error.InvalidCanonicalId;

        return .{ .bytes = bytes };
    }

    pub fn eql(a: CanonicalId, b: CanonicalId) bool {
        return std.mem.eql(u8, a.bytes, b.bytes);
    }
};

pub const DisplayName = struct {
    bytes: []const u8,

    pub fn init(bytes: []const u8) DisplayNameError!DisplayName {
        if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8DisplayName;
        return .{ .bytes = bytes };
    }
};

pub fn TypedId(comptime kind: []const u8) type {
    return struct {
        value: CanonicalId,

        pub const kind_name = kind;
        const Self = @This();

        pub fn init(bytes: []const u8) IdError!Self {
            return .{ .value = try CanonicalId.init(bytes) };
        }

        pub fn eql(a: Self, b: Self) bool {
            return a.value.eql(b.value);
        }
    };
}

pub const SchemaId = TypedId("schema");
pub const AssetId = TypedId("asset");
pub const CompilerId = TypedId("compiler");
pub const ComponentId = TypedId("component");
pub const ComponentTypeId = TypedId("component_type");
pub const SemanticTagId = TypedId("semantic_tag");
pub const CompatibilityProfileId = TypedId("compatibility_profile");
pub const BoneId = TypedId("bone");
pub const JointId = TypedId("joint");
pub const MobilityProfileId = TypedId("mobility_profile");
pub const ControlId = TypedId("control");
pub const MorphologyParameterId = TypedId("morphology_parameter");
pub const MorphologyBindingId = TypedId("morphology_binding");
pub const MorphologyDependencyId = TypedId("morphology_dependency");
pub const MorphologyProvenanceId = TypedId("morphology_provenance");
pub const PropertyId = TypedId("property");
pub const EnumValueId = TypedId("enum_value");
pub const ResponseCurveId = TypedId("response_curve");
pub const PresetId = TypedId("preset");
pub const MorphTargetId = TypedId("morph_target");
pub const CorrectiveShapeId = TypedId("corrective_shape");
pub const CollisionGeometryId = TypedId("collision_geometry");
pub const GarmentFittingEnvelopeId = TypedId("garment_fitting_envelope");
pub const SoftTissueProfileId = TypedId("soft_tissue_profile");
pub const ConstraintId = TypedId("constraint");
pub const AnchorId = TypedId("anchor");
pub const SocketId = TypedId("socket");
pub const MountAnchorId = TypedId("mount_anchor");
pub const AttachmentId = TypedId("attachment");
pub const SurfaceId = TypedId("surface");
pub const RegionId = TypedId("region");
pub const MaterialInstanceId = TypedId("material_instance");
pub const MaterialDefinitionId = TypedId("material_definition");
pub const MaterialPropertyId = TypedId("material_property");
pub const MaterialCapabilityId = TypedId("material_capability");
pub const MaterialResponseId = TypedId("material_response");
pub const MaterialDetailId = TypedId("material_detail");
pub const SurfaceCoordinateMetadataId = TypedId("surface_coordinate_metadata");
pub const VisibilityMetadataId = TypedId("visibility_metadata");
pub const CoverageSourceId = TypedId("coverage_source");
pub const RepresentationVariantId = TypedId("representation_variant");
pub const LandmarkId = TypedId("landmark");
pub const SeamId = TypedId("seam");
pub const InteractionSiteId = TypedId("interaction_site");
pub const EffectorId = TypedId("effector");
pub const ApproachMetadataId = TypedId("approach_metadata");
pub const OrientationMetadataId = TypedId("orientation_metadata");
pub const OccupancyPolicyId = TypedId("occupancy_policy");

pub const SchemaVersion = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

pub const AssetVersion = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

pub const CompilerVersion = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

pub const SchemaIdentity = struct {
    schema_id: SchemaId,
    version: SchemaVersion,
};

pub const AssetIdentity = struct {
    asset_id: AssetId,
    display_name: DisplayName,
    version: AssetVersion,
};

pub const CompilerIdentity = struct {
    compiler_id: CompilerId,
    version: CompilerVersion,
};

fn isLowercaseLetter(byte: u8) bool {
    return byte >= 'a' and byte <= 'z';
}
