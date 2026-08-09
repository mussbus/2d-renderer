const attachment = @import("attachment.zig");
const component = @import("component.zig");
const coordinate = @import("coordinate.zig");
const identity = @import("identity.zig");
const material = @import("material.zig");
const morphology = @import("morphology.zig");
const rig = @import("rig.zig");
const semantics = @import("semantics.zig");
const visibility = @import("visibility.zig");

pub const CanonicalCreatureDefinition = struct {
    schema_identity: identity.SchemaIdentity,
    asset_identity: identity.AssetIdentity,
    compiler_identity: identity.CompilerIdentity,
    coordinate_contract: ?coordinate.CoordinateContract = null,
    components: []const component.Component = &.{},
    bones: []const rig.Bone = &.{},
    joints: []const rig.Joint = &.{},
    controls: []const rig.Control = &.{},
    anchors: []const attachment.Anchor = &.{},
    sockets: []const attachment.Socket = &.{},
    mount_anchors: []const attachment.MountAnchor = &.{},
    attachments: []const attachment.Attachment = &.{},
    regions: []const semantics.Region = &.{},
    surfaces: []const semantics.Surface = &.{},
    landmarks: []const semantics.Landmark = &.{},
    shared_seams: []const semantics.SharedSeam = &.{},
    interaction_sites: []const semantics.InteractionSite = &.{},
    effectors: []const semantics.Effector = &.{},
    morphology_parameters: []const morphology.MorphologyParameter = &.{},
    morphology_bindings: []const morphology.MorphologyBinding = &.{},
    morphology_graph: morphology.DependencyGraph = .{
        .dependencies = &.{},
        .provenance = &.{},
    },
    material_definitions: []const material.MaterialDefinition = &.{},
    material_instances: []const material.MaterialInstance = &.{},
    visibility_metadata: []const visibility.VisibilityCoverageMetadata = &.{},
};
