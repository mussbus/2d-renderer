const identity = @import("identity.zig");

pub const Region = struct {
    region_id: identity.RegionId,
    display_name: ?identity.DisplayName,
    owner_component_id: identity.ComponentId,
    semantic_tags: []const identity.SemanticTagId,
};

pub const Surface = struct {
    surface_id: identity.SurfaceId,
    display_name: ?identity.DisplayName,
    owner_component_id: identity.ComponentId,
    region_id: identity.RegionId,
    material_instance_id: identity.MaterialInstanceId,
    coordinate_metadata_id: ?identity.SurfaceCoordinateMetadataId,
    visibility_metadata_id: ?identity.VisibilityMetadataId,
};

pub const SemanticOwner = union(enum) {
    component: identity.ComponentId,
    surface: identity.SurfaceId,
    region: identity.RegionId,
    anchor: identity.AnchorId,
};

pub const Landmark = struct {
    landmark_id: identity.LandmarkId,
    display_name: ?identity.DisplayName,
    owner: SemanticOwner,
    coordinate_metadata_id: ?identity.SurfaceCoordinateMetadataId,
    semantic_tags: []const identity.SemanticTagId,
};

pub const SharedSeamMember = struct {
    component_id: identity.ComponentId,
    surface_id: identity.SurfaceId,
};

pub const SharedSeam = struct {
    seam_id: identity.SeamId,
    display_name: ?identity.DisplayName,
    members: []const SharedSeamMember,
    coordinate_metadata_id: ?identity.SurfaceCoordinateMetadataId,
};

pub const InteractionSite = struct {
    site_id: identity.InteractionSiteId,
    display_name: ?identity.DisplayName,
    owner_component_id: identity.ComponentId,
    region_id: ?identity.RegionId,
    preferred_anchor_id: ?identity.AnchorId,
    semantic_tags: []const identity.SemanticTagId,
    approach_metadata_id: ?identity.ApproachMetadataId,
    orientation_metadata_id: ?identity.OrientationMetadataId,
    capacity: u32,
    occupancy_policy_id: ?identity.OccupancyPolicyId,
};

pub const Effector = struct {
    effector_id: identity.EffectorId,
    display_name: ?identity.DisplayName,
    owner_component_id: identity.ComponentId,
    region_id: ?identity.RegionId,
    preferred_anchor_id: ?identity.AnchorId,
    semantic_tags: []const identity.SemanticTagId,
    approach_metadata_id: ?identity.ApproachMetadataId,
    orientation_metadata_id: ?identity.OrientationMetadataId,
    capacity: u32,
    occupancy_policy_id: ?identity.OccupancyPolicyId,
};
