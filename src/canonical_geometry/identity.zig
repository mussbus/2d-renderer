const canonical = @import("canonical_model");

pub const GeometrySchemaId = canonical.identity.TypedId("geometry_schema");
pub const GeometryAssetId = canonical.identity.TypedId("geometry_asset");
pub const GeometryCompilerId = canonical.identity.TypedId("geometry_compiler");
pub const MeshId = canonical.identity.TypedId("geometry_mesh");
pub const TopologyId = canonical.identity.TypedId("geometry_topology");
pub const ChartId = canonical.identity.TypedId("geometry_chart");
pub const TextureSpaceId = canonical.identity.TypedId("geometry_texture_space");
pub const UvIslandId = canonical.identity.TypedId("geometry_uv_island");
pub const OverlapGroupId = canonical.identity.TypedId("geometry_overlap_group");
pub const BoundaryLoopId = canonical.identity.TypedId("geometry_boundary_loop");
pub const FaceSetId = canonical.identity.TypedId("geometry_face_set");
pub const GeometrySeamBindingId = canonical.identity.TypedId("geometry_seam_binding");
pub const GeometryBindingId = canonical.identity.TypedId("geometry_binding");
pub const ModuleInterfaceId = canonical.identity.TypedId("geometry_module_interface");
pub const CollisionProxyId = canonical.identity.TypedId("geometry_collision_proxy");

pub const VertexId = struct {
    value: u32,

    pub fn eql(a: VertexId, b: VertexId) bool {
        return a.value == b.value;
    }
};

pub const FaceId = struct {
    value: u32,

    pub fn eql(a: FaceId, b: FaceId) bool {
        return a.value == b.value;
    }
};

pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,

    pub fn eql(a: Version, b: Version) bool {
        return a.major == b.major and a.minor == b.minor and a.patch == b.patch;
    }
};

pub const Sha256Digest = struct {
    bytes: [32]u8,

    pub fn eql(a: Sha256Digest, b: Sha256Digest) bool {
        return @import("std").mem.eql(u8, &a.bytes, &b.bytes);
    }

    pub fn toHex(self: Sha256Digest) [64]u8 {
        return @import("std").fmt.bytesToHex(self.bytes, .lower);
    }
};
