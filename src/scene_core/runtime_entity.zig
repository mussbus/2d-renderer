const std = @import("std");
const foundation = @import("foundation");
const camera = @import("camera.zig");
const entity = @import("entity.zig");
const extension = @import("extension.zig");
const level = @import("level.zig");
const metadata = @import("metadata.zig");
const runtime_asset = @import("runtime_asset.zig");

pub const MutationAuthority = enum {
    world,
    physics_gameplay,
    editor,
    cinematic,
};

pub const TransientOwner = union(enum) {
    level: foundation.identity.AssetId,
    physics_gameplay: ?foundation.identity.AssetId,
    editor_preview: ?foundation.identity.AssetId,
    cutscene_preview: ?foundation.identity.AssetId,
};

pub const Lifetime = union(enum) {
    world_persistent,
    level_owned: foundation.identity.AssetId,
    transient: TransientOwner,

    pub fn owningLevel(self: Lifetime) ?foundation.identity.AssetId {
        return switch (self) {
            .level_owned => |id| id,
            .transient => |owner| switch (owner) {
                .level => |id| id,
                .physics_gameplay, .editor_preview, .cutscene_preview => |host| host,
            },
            .world_persistent => null,
        };
    }

    pub fn isPersistentWorld(self: Lifetime) bool {
        return switch (self) {
            .world_persistent => true,
            else => false,
        };
    }
};

pub const ExactAsset = struct {
    revision: foundation.reference.AssetRevision,
    expected_kind: []u8,

    pub fn init(allocator: std.mem.Allocator, reference: foundation.reference.AssetRef) !ExactAsset {
        return .{
            .revision = reference.revision,
            .expected_kind = try allocator.dupe(u8, reference.expected_kind.name),
        };
    }

    pub fn clone(self: ExactAsset, allocator: std.mem.Allocator) !ExactAsset {
        return .{
            .revision = self.revision,
            .expected_kind = try allocator.dupe(u8, self.expected_kind),
        };
    }

    pub fn deinit(self: *ExactAsset, allocator: std.mem.Allocator) void {
        allocator.free(self.expected_kind);
        self.* = undefined;
    }

    pub fn view(self: ExactAsset) foundation.reference.AssetRef {
        return .{
            .revision = self.revision,
            .expected_kind = .{ .name = self.expected_kind },
        };
    }
};

pub const AssetRole = enum {
    prefab_source,
    nested_prefab_source,
    presentation,
    volume_shape,
    layer,
    extension_dependency,
};

pub const ResolvedAsset = struct {
    role: AssetRole,
    extension_index: ?u16,
    exact: ExactAsset,
    token: runtime_asset.ResolvedAssetToken,

    pub fn clone(self: ResolvedAsset, allocator: std.mem.Allocator) !ResolvedAsset {
        return .{
            .role = self.role,
            .extension_index = self.extension_index,
            .exact = try self.exact.clone(allocator),
            .token = self.token,
        };
    }

    pub fn deinit(self: *ResolvedAsset, allocator: std.mem.Allocator) void {
        self.exact.deinit(allocator);
        self.* = undefined;
    }
};

pub const OwnedDependency = struct {
    class: foundation.reference.DependencyClass,
    exact: ExactAsset,
    token: runtime_asset.ResolvedAssetToken,

    fn clone(self: OwnedDependency, allocator: std.mem.Allocator) !OwnedDependency {
        return .{
            .class = self.class,
            .exact = try self.exact.clone(allocator),
            .token = self.token,
        };
    }

    fn deinit(self: *OwnedDependency, allocator: std.mem.Allocator) void {
        self.exact.deinit(allocator);
        self.* = undefined;
    }
};

pub const OwnedExtension = struct {
    type_id: []u8,
    schema_version: foundation.version.SchemaVersion,
    criticality: extension.Criticality,
    canonical_payload: []u8,
    dependencies: []OwnedDependency,

    fn init(
        allocator: std.mem.Allocator,
        source: extension.ExtensionRecord,
        resolver: runtime_asset.Resolver,
    ) !OwnedExtension {
        const type_id = try allocator.dupe(u8, source.type_id.value);
        errdefer allocator.free(type_id);
        const payload = try allocator.dupe(u8, source.canonical_payload);
        errdefer allocator.free(payload);
        const dependencies = try allocator.alloc(OwnedDependency, source.dependencies.len);
        errdefer allocator.free(dependencies);
        var initialized: usize = 0;
        errdefer for (dependencies[0..initialized]) |*dependency| dependency.deinit(allocator);
        for (source.dependencies, 0..) |dependency, index| {
            var exact = try ExactAsset.init(allocator, dependency.asset);
            errdefer exact.deinit(allocator);
            dependencies[index] = .{
                .class = dependency.class,
                .exact = exact,
                .token = try resolver.resolve(dependency.asset),
            };
            initialized += 1;
        }
        return .{
            .type_id = type_id,
            .schema_version = source.schema_version,
            .criticality = source.criticality,
            .canonical_payload = payload,
            .dependencies = dependencies,
        };
    }

    fn clone(self: OwnedExtension, allocator: std.mem.Allocator) !OwnedExtension {
        const type_id = try allocator.dupe(u8, self.type_id);
        errdefer allocator.free(type_id);
        const payload = try allocator.dupe(u8, self.canonical_payload);
        errdefer allocator.free(payload);
        const dependencies = try allocator.alloc(OwnedDependency, self.dependencies.len);
        errdefer allocator.free(dependencies);
        var initialized: usize = 0;
        errdefer for (dependencies[0..initialized]) |*dependency| dependency.deinit(allocator);
        for (self.dependencies, 0..) |dependency, index| {
            dependencies[index] = try dependency.clone(allocator);
            initialized += 1;
        }
        return .{
            .type_id = type_id,
            .schema_version = self.schema_version,
            .criticality = self.criticality,
            .canonical_payload = payload,
            .dependencies = dependencies,
        };
    }

    fn deinit(self: *OwnedExtension, allocator: std.mem.Allocator) void {
        for (self.dependencies) |*dependency| dependency.deinit(allocator);
        allocator.free(self.dependencies);
        allocator.free(self.canonical_payload);
        allocator.free(self.type_id);
        self.* = undefined;
    }
};

pub const AppliedOverride = struct {
    node_path: []u8,
    component_type_id: []u8,
    property_path: []u8,
    canonical_value: []u8,

    pub fn init(allocator: std.mem.Allocator, source: entity.OverrideRecord) !AppliedOverride {
        const node_path = try allocator.dupe(u8, source.target.node_path);
        errdefer allocator.free(node_path);
        const component_type_id = try allocator.dupe(u8, source.target.component_type_id.value);
        errdefer allocator.free(component_type_id);
        const property_path = try allocator.dupe(u8, source.target.property_path);
        errdefer allocator.free(property_path);
        const canonical_value = try allocator.dupe(u8, source.canonical_value);
        errdefer allocator.free(canonical_value);
        return .{
            .node_path = node_path,
            .component_type_id = component_type_id,
            .property_path = property_path,
            .canonical_value = canonical_value,
        };
    }

    fn clone(self: AppliedOverride, allocator: std.mem.Allocator) !AppliedOverride {
        const node_path = try allocator.dupe(u8, self.node_path);
        errdefer allocator.free(node_path);
        const component_type_id = try allocator.dupe(u8, self.component_type_id);
        errdefer allocator.free(component_type_id);
        const property_path = try allocator.dupe(u8, self.property_path);
        errdefer allocator.free(property_path);
        const canonical_value = try allocator.dupe(u8, self.canonical_value);
        errdefer allocator.free(canonical_value);
        return .{
            .node_path = node_path,
            .component_type_id = component_type_id,
            .property_path = property_path,
            .canonical_value = canonical_value,
        };
    }

    fn deinit(self: *AppliedOverride, allocator: std.mem.Allocator) void {
        allocator.free(self.canonical_value);
        allocator.free(self.property_path);
        allocator.free(self.component_type_id);
        allocator.free(self.node_path);
        self.* = undefined;
    }
};

pub const WorldTransform = struct {
    /// Exact large-scale stable-frame origin. The affine remains small f32
    /// metre data and is never permanently collapsed into this origin.
    origin: level.WorldCoordinateOrigin,
    affine: foundation.spatial.AffineTransform,
};

pub const RuntimeEntity = struct {
    handle: foundation.identity.EntityHandle = .invalid,
    persistent_id: ?foundation.identity.EntityId,
    lifetime: Lifetime,
    parent: ?foundation.identity.EntityHandle = null,
    children: []foundation.identity.EntityHandle = &.{},
    local_transform: foundation.spatial.LocalTransform,
    world_transform: WorldTransform,
    dirty: bool = true,
    local_revision: u64 = 1,
    world_revision: u64 = 0,
    evaluated_parent_revision: u64 = 0,
    recomputation_count: u64 = 0,
    authored_enabled: metadata.EnabledIntent,
    effective_enabled: bool = true,
    visibility: metadata.VisibilityIntent,
    tags: [][]u8 = &.{},
    extensions: []OwnedExtension = &.{},
    resolved_assets: []ResolvedAsset = &.{},
    applied_overrides: []AppliedOverride = &.{},
    camera_definition: ?camera.CameraDefinition,
    prefab_node_path: ?[]u8 = null,

    pub const Source = struct {
        persistent_id: ?foundation.identity.EntityId,
        lifetime: Lifetime,
        local_transform: foundation.spatial.LocalTransform,
        authored_enabled: metadata.EnabledIntent,
        visibility: metadata.VisibilityIntent,
        tags: []const metadata.TagId,
        extensions: []const extension.ExtensionRecord,
        camera_definition: ?camera.CameraDefinition = null,
        prefab_node_path: ?[]const u8 = null,
    };

    pub fn initOwned(
        allocator: std.mem.Allocator,
        source: Source,
        resolver: runtime_asset.Resolver,
        origin: level.WorldCoordinateOrigin,
    ) !RuntimeEntity {
        source.local_transform.validate() catch return error.InvalidRuntimeTransform;
        if (source.camera_definition) |definition| definition.validate() catch return error.InvalidCameraGeometry;

        const tags = try allocator.alloc([]u8, source.tags.len);
        errdefer allocator.free(tags);
        var tag_count: usize = 0;
        errdefer for (tags[0..tag_count]) |tag| allocator.free(tag);
        for (source.tags, 0..) |tag, index| {
            tags[index] = try allocator.dupe(u8, tag.value);
            tag_count += 1;
        }

        const extensions = try allocator.alloc(OwnedExtension, source.extensions.len);
        errdefer allocator.free(extensions);
        var extension_count: usize = 0;
        errdefer for (extensions[0..extension_count]) |*record| record.deinit(allocator);
        for (source.extensions, 0..) |record, index| {
            extensions[index] = try OwnedExtension.init(allocator, record, resolver);
            extension_count += 1;
        }

        const node_path = if (source.prefab_node_path) |path| try allocator.dupe(u8, path) else null;
        errdefer if (node_path) |path| allocator.free(path);
        return .{
            .persistent_id = source.persistent_id,
            .lifetime = source.lifetime,
            .local_transform = source.local_transform,
            .world_transform = .{
                .origin = origin,
                .affine = try foundation.spatial.AffineTransform.fromLocal(source.local_transform),
            },
            .authored_enabled = source.authored_enabled,
            .visibility = source.visibility,
            .tags = tags,
            .extensions = extensions,
            .camera_definition = source.camera_definition,
            .prefab_node_path = node_path,
        };
    }

    pub fn clone(self: RuntimeEntity, allocator: std.mem.Allocator) !RuntimeEntity {
        var result = RuntimeEntity{
            .handle = self.handle,
            .persistent_id = self.persistent_id,
            .lifetime = self.lifetime,
            .parent = self.parent,
            .local_transform = self.local_transform,
            .world_transform = self.world_transform,
            .dirty = self.dirty,
            .local_revision = self.local_revision,
            .world_revision = self.world_revision,
            .evaluated_parent_revision = self.evaluated_parent_revision,
            .recomputation_count = self.recomputation_count,
            .authored_enabled = self.authored_enabled,
            .effective_enabled = self.effective_enabled,
            .visibility = self.visibility,
            .camera_definition = self.camera_definition,
        };
        errdefer result.deinit(allocator);
        result.children = try allocator.dupe(foundation.identity.EntityHandle, self.children);
        result.tags = try cloneTags(allocator, self.tags);
        result.extensions = try cloneExtensions(allocator, self.extensions);
        result.resolved_assets = try cloneAssets(allocator, self.resolved_assets);
        result.applied_overrides = try cloneOverrides(allocator, self.applied_overrides);
        result.prefab_node_path = if (self.prefab_node_path) |path| try allocator.dupe(u8, path) else null;
        return result;
    }

    pub fn deinit(self: *RuntimeEntity, allocator: std.mem.Allocator) void {
        if (self.prefab_node_path) |path| allocator.free(path);
        for (self.applied_overrides) |*record| record.deinit(allocator);
        if (self.applied_overrides.len != 0) allocator.free(self.applied_overrides);
        for (self.resolved_assets) |*resolved| resolved.deinit(allocator);
        if (self.resolved_assets.len != 0) allocator.free(self.resolved_assets);
        for (self.extensions) |*record| record.deinit(allocator);
        if (self.extensions.len != 0) allocator.free(self.extensions);
        for (self.tags) |tag| allocator.free(tag);
        if (self.tags.len != 0) allocator.free(self.tags);
        if (self.children.len != 0) allocator.free(self.children);
        self.* = undefined;
    }

    pub fn appendResolvedAsset(
        self: *RuntimeEntity,
        allocator: std.mem.Allocator,
        role: AssetRole,
        extension_index: ?u16,
        reference: foundation.reference.AssetRef,
        token: runtime_asset.ResolvedAssetToken,
    ) !void {
        const replacement = try allocator.alloc(ResolvedAsset, self.resolved_assets.len + 1);
        errdefer allocator.free(replacement);
        @memcpy(replacement[0..self.resolved_assets.len], self.resolved_assets);
        replacement[self.resolved_assets.len] = .{
            .role = role,
            .extension_index = extension_index,
            .exact = try ExactAsset.init(allocator, reference),
            .token = token,
        };
        if (self.resolved_assets.len != 0) allocator.free(self.resolved_assets);
        self.resolved_assets = replacement;
    }

    pub fn appendOverride(self: *RuntimeEntity, allocator: std.mem.Allocator, source: entity.OverrideRecord) !void {
        const replacement = try allocator.alloc(AppliedOverride, self.applied_overrides.len + 1);
        errdefer allocator.free(replacement);
        @memcpy(replacement[0..self.applied_overrides.len], self.applied_overrides);
        replacement[self.applied_overrides.len] = try AppliedOverride.init(allocator, source);
        if (self.applied_overrides.len != 0) allocator.free(self.applied_overrides);
        self.applied_overrides = replacement;
    }

    pub fn findExtension(self: *const RuntimeEntity, type_id: []const u8) ?*const OwnedExtension {
        for (self.extensions) |*record| if (std.mem.eql(u8, record.type_id, type_id)) return record;
        return null;
    }
};

fn cloneTags(allocator: std.mem.Allocator, source: [][]u8) ![][]u8 {
    const result = try allocator.alloc([]u8, source.len);
    errdefer allocator.free(result);
    var initialized: usize = 0;
    errdefer for (result[0..initialized]) |tag| allocator.free(tag);
    for (source, 0..) |tag, index| {
        result[index] = try allocator.dupe(u8, tag);
        initialized += 1;
    }
    return result;
}

fn cloneExtensions(allocator: std.mem.Allocator, source: []OwnedExtension) ![]OwnedExtension {
    const result = try allocator.alloc(OwnedExtension, source.len);
    errdefer allocator.free(result);
    var initialized: usize = 0;
    errdefer for (result[0..initialized]) |*record| record.deinit(allocator);
    for (source, 0..) |record, index| {
        result[index] = try record.clone(allocator);
        initialized += 1;
    }
    return result;
}

fn cloneAssets(allocator: std.mem.Allocator, source: []ResolvedAsset) ![]ResolvedAsset {
    const result = try allocator.alloc(ResolvedAsset, source.len);
    errdefer allocator.free(result);
    var initialized: usize = 0;
    errdefer for (result[0..initialized]) |*record| record.deinit(allocator);
    for (source, 0..) |record, index| {
        result[index] = try record.clone(allocator);
        initialized += 1;
    }
    return result;
}

fn cloneOverrides(allocator: std.mem.Allocator, source: []AppliedOverride) ![]AppliedOverride {
    const result = try allocator.alloc(AppliedOverride, source.len);
    errdefer allocator.free(result);
    var initialized: usize = 0;
    errdefer for (result[0..initialized]) |*record| record.deinit(allocator);
    for (source, 0..) |record, index| {
        result[index] = try record.clone(allocator);
        initialized += 1;
    }
    return result;
}
