const canonical = @import("canonical_model");
const identity = @import("identity.zig");

pub const schema_id = "canonical_geometry_schema";
pub const schema_version = identity.Version{ .major = 1, .minor = 0, .patch = 0 };
pub const compiler_id = "canonical_geometry_compiler";
pub const compiler_version = identity.Version{ .major = 1, .minor = 0, .patch = 0 };

pub const GeometrySchemaIdentity = struct {
    geometry_schema_id: identity.GeometrySchemaId,
    version: identity.Version,
};

pub const GeometryAssetIdentity = struct {
    geometry_asset_id: identity.GeometryAssetId,
    version: identity.Version,
};

pub const GeometryCompilerIdentity = struct {
    geometry_compiler_id: identity.GeometryCompilerId,
    version: identity.Version,
};

pub const TopologyIdentity = struct {
    topology_id: identity.TopologyId,
    compatibility_version: identity.Version,
    revision: u32,
};

pub const StructuralCompatibility = struct {
    structural_asset_id: canonical.identity.AssetId,
    structural_asset_version: canonical.identity.AssetVersion,
    structural_schema_id: canonical.identity.SchemaId,
    structural_schema_version: canonical.identity.SchemaVersion,
    normalized_source_sha256: identity.Sha256Digest,
    coordinate_contract: canonical.coordinate.CoordinateContract,
    required_component_ids: []const canonical.identity.ComponentId = &.{},
    required_bone_ids: []const canonical.identity.BoneId = &.{},
    required_anchor_ids: []const canonical.identity.AnchorId = &.{},
    required_surface_ids: []const canonical.identity.SurfaceId = &.{},
    required_region_ids: []const canonical.identity.RegionId = &.{},
    required_material_instance_ids: []const canonical.identity.MaterialInstanceId = &.{},
    required_seam_ids: []const canonical.identity.SeamId = &.{},
    required_landmark_ids: []const canonical.identity.LandmarkId = &.{},
    required_interaction_site_ids: []const canonical.identity.InteractionSiteId = &.{},
};

pub const Vec2 = struct {
    x: f32,
    y: f32,
};

pub const Vertex = struct {
    vertex_id: identity.VertexId,
    position_m: canonical.math3d.Vec3,
};

pub const TriangulationDiagonal = enum {
    v0_v2,
    v1_v3,
};

pub const SurfaceCoordinateCorner = struct {
    surface_id: canonical.identity.SurfaceId,
    chart_id: identity.ChartId,
    coordinate: Vec2,
};

pub const TextureCoordinateCorner = struct {
    texture_space_id: identity.TextureSpaceId,
    uv_island_id: identity.UvIslandId,
    uv: Vec2,
    overlap_group_id: ?identity.OverlapGroupId = null,
};

pub const QuadFace = struct {
    face_id: identity.FaceId,
    vertex_ids: [4]identity.VertexId,
    diagonal: TriangulationDiagonal,
    primary_surface_id: canonical.identity.SurfaceId,
    material_instance_id: canonical.identity.MaterialInstanceId,
    region_ids: []const canonical.identity.RegionId,
    surface_coordinates: [4]SurfaceCoordinateCorner,
    texture_coordinates: [4]TextureCoordinateCorner,
};

pub const DirectedEdge = struct {
    from_vertex_id: identity.VertexId,
    to_vertex_id: identity.VertexId,
};

pub const BoundaryClassification = enum {
    intentional_open,
};

pub const BoundaryLoop = struct {
    boundary_loop_id: identity.BoundaryLoopId,
    classification: BoundaryClassification,
    directed_edges: []const DirectedEdge,
};

pub const ConnectivityPolicy = enum {
    connected,
};

pub const SubdivisionPolicy = enum {
    none,
    catmull_clark_v1,
};

pub const Mesh = struct {
    mesh_id: identity.MeshId,
    owner_component_ids: []const canonical.identity.ComponentId,
    next_vertex_id: u32,
    next_face_id: u32,
    connectivity_policy: ConnectivityPolicy,
    subdivision_policy: SubdivisionPolicy,
    vertices: []const Vertex,
    faces: []const QuadFace,
    boundary_loops: []const BoundaryLoop = &.{},
};

pub const FaceSet = struct {
    face_set_id: identity.FaceSetId,
    mesh_id: identity.MeshId,
    face_ids: []const identity.FaceId,
};

/// A stable directed loop over existing mesh edges. Unlike `BoundaryLoop`, a
/// topology loop may be internal while a closure face set is present. The
/// optional face-set reference proves that suppressing those faces exposes
/// this exact loop as a boundary for later module assembly.
pub const TopologyLoop = struct {
    topology_loop_id: identity.BoundaryLoopId,
    mesh_id: identity.MeshId,
    directed_edges: []const DirectedEdge,
    becomes_boundary_when_face_set_removed: ?identity.FaceSetId = null,
};

pub const GeometrySeamBinding = struct {
    geometry_seam_binding_id: identity.GeometrySeamBindingId,
    structural_seam_id: canonical.identity.SeamId,
    mesh_id: identity.MeshId,
    directed_edges: []const DirectedEdge,
    is_closed: bool,
    side_a_surface_id: canonical.identity.SurfaceId,
    side_b_surface_id: canonical.identity.SurfaceId,
};

pub const GeometryBinding = struct {
    geometry_binding_id: identity.GeometryBindingId,
    landmark_id: ?canonical.identity.LandmarkId = null,
    interaction_site_id: ?canonical.identity.InteractionSiteId = null,
    mesh_id: identity.MeshId,
    face_id: identity.FaceId,
    local_face_coordinate: Vec2,
    surface_coordinate: SurfaceCoordinateCorner,
};

pub const ModuleInterface = struct {
    module_interface_id: identity.ModuleInterfaceId,
    receiver_mesh_id: identity.MeshId,
    module_mesh_id: identity.MeshId,
    receiver_closure_face_set_id: identity.FaceSetId,
    body_receiver_loop_id: identity.BoundaryLoopId,
    module_root_loop_id: identity.BoundaryLoopId,
};

pub const CollisionPrimitive = enum {
    sphere,
    capsule,
    box,
};

pub const CollisionProxyDimensions = struct {
    radius_m: ?f32 = null,
    half_length_m: ?f32 = null,
    half_extents_m: ?canonical.math3d.Vec3 = null,
};

pub const CollisionProxy = struct {
    collision_proxy_id: identity.CollisionProxyId,
    owner_component_id: canonical.identity.ComponentId,
    driver_bone_id: ?canonical.identity.BoneId = null,
    driver_anchor_id: ?canonical.identity.AnchorId = null,
    local_transform: canonical.math3d.LocalTransform,
    primitive: CollisionPrimitive,
    dimensions: CollisionProxyDimensions,
    semantic_region_id: canonical.identity.RegionId,
    topology_id: identity.TopologyId,
    topology_compatibility_version: identity.Version,
    topology_revision: u32,
};

pub const GeometryDefinition = struct {
    schema_identity: GeometrySchemaIdentity,
    asset_identity: GeometryAssetIdentity,
    compiler_identity: GeometryCompilerIdentity,
    structural_compatibility: StructuralCompatibility,
    topology_identity: TopologyIdentity,
    meshes: []const Mesh,
    face_sets: []const FaceSet = &.{},
    topology_loops: []const TopologyLoop = &.{},
    seam_bindings: []const GeometrySeamBinding = &.{},
    geometry_bindings: []const GeometryBinding = &.{},
    module_interfaces: []const ModuleInterface = &.{},
    collision_proxies: []const CollisionProxy = &.{},
};
