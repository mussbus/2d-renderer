const identity = @import("identity.zig");

pub const ComponentExistence = enum {
    absent,
    present,
};

pub const ComponentEnabledState = enum {
    disabled,
    enabled,
};

pub const VisibilityState = enum {
    visible,
    partially_visible,
    fully_occluded,
    hidden_by_policy,
    hidden_for_representation,
    replaced_by_variant,
};

pub const NormalizedCoverage = struct {
    value: f32,

    pub const minimum: f32 = 0.0;
    pub const maximum: f32 = 1.0;
};

pub const RepresentationSelection = union(enum) {
    canonical,
    variant: identity.RepresentationVariantId,
    substitution: identity.RepresentationVariantId,
};

pub const CoverageSourceType = enum {
    clothing,
    armor,
    hair,
    accessory,
    body_overlap,
    prop,
};

pub const CoverageContribution = struct {
    source_type: CoverageSourceType,
    source_id: identity.CoverageSourceId,
    amount: NormalizedCoverage,
};

pub const VisibilitySubject = union(enum) {
    component: identity.ComponentId,
    surface: identity.SurfaceId,
    region: identity.RegionId,
};

pub const VisibilityCoverageMetadata = struct {
    visibility_metadata_id: identity.VisibilityMetadataId,
    subject: VisibilitySubject,
    component_existence: ComponentExistence,
    component_enabled_state: ComponentEnabledState,
    visibility_state: VisibilityState,
    coverage: NormalizedCoverage,
    coverage_region_id: ?identity.RegionId,
    coverage_sources: []const CoverageContribution,
    representation: RepresentationSelection,
};
