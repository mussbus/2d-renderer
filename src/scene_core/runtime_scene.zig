const std = @import("std");
const foundation = @import("foundation");
const asset = @import("asset.zig");
const entity = @import("entity.zig");
const hierarchy = @import("hierarchy.zig");
const level = @import("level.zig");
const metadata = @import("metadata.zig");
const prefab = @import("prefab.zig");
const registry_module = @import("registry.zig");
const runtime_asset = @import("runtime_asset.zig");
const runtime_entity = @import("runtime_entity.zig");
const world = @import("world.zig");

const zero_origin = level.WorldCoordinateOrigin{ .x_mm = 0, .y_mm = 0, .z_mm = 0 };

pub const ParentMode = enum { keep_local, keep_world };
pub const RemovalPolicy = enum { reject_if_children, cascade, orphan_keep_world };

pub const RuntimeErrorCode = enum {
    invalid_handle,
    stale_handle,
    registry_capacity,
    duplicate_active_entity_id,
    entity_not_found,
    invalid_parent_handle,
    runtime_parent_cycle,
    asset_resolution_failed,
    level_already_active,
    level_not_active,
    assembly_failed,
    publication_failed,
    generation_exhausted,
    invalid_runtime_transform,
    unauthorized_mutation,
    entity_already_persistent,
    persistent_below_level_owned,
    promotion_requires_world_rebase,
    cross_origin_keep_world,
    snapshot_capacity,
};

pub fn classifyError(runtime_error: anyerror) RuntimeErrorCode {
    return switch (runtime_error) {
        error.InvalidHandle => .invalid_handle,
        error.StaleHandle => .stale_handle,
        error.RegistryCapacity, error.LevelCapacity, error.GrowthReportCapacity => .registry_capacity,
        error.DuplicateActiveEntityId => .duplicate_active_entity_id,
        error.EntityNotFound => .entity_not_found,
        error.InvalidParentHandle => .invalid_parent_handle,
        error.RuntimeParentCycle => .runtime_parent_cycle,
        error.AssetResolutionFailed, error.InvalidResolvedAssetToken, error.SourceRevisionMismatch => .asset_resolution_failed,
        error.LevelAlreadyActive => .level_already_active,
        error.LevelNotActive => .level_not_active,
        error.PublicationPrepareFailed => .publication_failed,
        error.GenerationExhausted => .generation_exhausted,
        error.InvalidRuntimeTransform, error.NonFiniteValue, error.ZeroScale => .invalid_runtime_transform,
        error.UnauthorizedMutation => .unauthorized_mutation,
        error.EntityAlreadyPersistent => .entity_already_persistent,
        error.PersistentBelowLevelOwned => .persistent_below_level_owned,
        error.PromotionRequiresWorldRebase => .promotion_requires_world_rebase,
        error.CrossOriginKeepWorldUnsupported => .cross_origin_keep_world,
        error.SnapshotCapacity => .snapshot_capacity,
        else => .assembly_failed,
    };
}

pub fn foundationDiagnosticCode(code: RuntimeErrorCode) foundation.diagnostics.Code {
    return switch (code) {
        .duplicate_active_entity_id => .duplicate_identity,
        .registry_capacity, .generation_exhausted, .snapshot_capacity => .capacity_exceeded,
        .invalid_runtime_transform, .promotion_requires_world_rebase, .cross_origin_keep_world => .invalid_spatial_value,
        .asset_resolution_failed, .entity_not_found, .invalid_handle, .stale_handle, .invalid_parent_handle => .invalid_reference,
        .runtime_parent_cycle => .dependency_cycle,
        .level_already_active,
        .level_not_active,
        .assembly_failed,
        .publication_failed,
        .unauthorized_mutation,
        .entity_already_persistent,
        .persistent_below_level_owned,
        => .invalid_reference,
    };
}

pub const SceneTime = struct {
    tick: u64,
    fixed_delta_seconds: f32,
    interpolation_alpha: f32,

    pub fn validate(self: SceneTime) error{InvalidSceneTime}!void {
        if (!std.math.isFinite(self.fixed_delta_seconds) or self.fixed_delta_seconds <= 0.0 or
            !std.math.isFinite(self.interpolation_alpha) or self.interpolation_alpha < 0.0 or
            self.interpolation_alpha > 1.0)
        {
            return error.InvalidSceneTime;
        }
    }
};

pub const MutationContext = struct {
    authority: runtime_entity.MutationAuthority,
    participants: []const PublicationParticipant = &.{},
};

pub const PublicationParticipant = struct {
    context: ?*anyopaque,
    prepare_fn: *const fn (?*anyopaque, SceneReadView) anyerror!void,
    commit_fn: *const fn (?*anyopaque, u64) void,
    rollback_fn: *const fn (?*anyopaque) void,
};

pub const PrefabCatalogEntry = struct {
    reference: foundation.reference.AssetRef,
    definition: *const prefab.PrefabDefinition,
};

pub const LevelActivation = struct {
    source: foundation.reference.AssetRef,
    definition: *const level.LevelDefinition,
    prefabs: []const PrefabCatalogEntry = &.{},
    resolver: runtime_asset.Resolver,
};

pub const WorldActivation = struct {
    source: foundation.reference.AssetRef,
    definition: *const world.WorldDefinition,
    prefabs: []const PrefabCatalogEntry = &.{},
    resolver: runtime_asset.Resolver,
};

pub const TransientDefinition = struct {
    owner: runtime_entity.TransientOwner,
    parent: ?foundation.identity.EntityHandle = null,
    local_transform: foundation.spatial.LocalTransform = .identity,
    enabled: metadata.EnabledIntent = .inherit,
    visibility: metadata.VisibilityIntent = .inherit,
    tags: []const metadata.TagId = &.{},
    extensions: []const @import("extension.zig").ExtensionRecord = &.{},
    camera_definition: ?@import("camera.zig").CameraDefinition = null,
    resolver: runtime_asset.Resolver,
};

const ActiveAsset = struct {
    exact: runtime_entity.ExactAsset,
    token: runtime_asset.ResolvedAssetToken,

    fn init(allocator: std.mem.Allocator, reference: foundation.reference.AssetRef, token: runtime_asset.ResolvedAssetToken) !ActiveAsset {
        return .{ .exact = try runtime_entity.ExactAsset.init(allocator, reference), .token = token };
    }

    fn clone(self: ActiveAsset, allocator: std.mem.Allocator) !ActiveAsset {
        return .{ .exact = try self.exact.clone(allocator), .token = self.token };
    }

    fn deinit(self: *ActiveAsset, allocator: std.mem.Allocator) void {
        self.exact.deinit(allocator);
        self.* = undefined;
    }
};

const ActiveLevel = struct {
    source: ActiveAsset,
    origin: level.WorldCoordinateOrigin,

    fn clone(self: ActiveLevel, allocator: std.mem.Allocator) !ActiveLevel {
        return .{ .source = try self.source.clone(allocator), .origin = self.origin };
    }

    fn deinit(self: *ActiveLevel, allocator: std.mem.Allocator) void {
        self.source.deinit(allocator);
        self.* = undefined;
    }
};

const State = struct {
    allocator: std.mem.Allocator,
    registry: registry_module.EntityRegistry,
    levels: []ActiveLevel,
    level_count: usize = 0,
    logical_level_capacity: usize,
    active_world: ?ActiveAsset = null,
    growth: registry_module.GrowthEvents = .{},

    fn init(
        allocator: std.mem.Allocator,
        registry_config: registry_module.Config,
        initial_level_capacity: usize,
        hard_level_capacity: usize,
    ) !State {
        if (initial_level_capacity > hard_level_capacity) return error.InvalidLevelCapacity;
        var registry = try registry_module.EntityRegistry.init(allocator, registry_config);
        errdefer registry.deinit();
        const levels = try allocator.alloc(ActiveLevel, hard_level_capacity);
        return .{
            .allocator = allocator,
            .registry = registry,
            .levels = levels,
            .logical_level_capacity = initial_level_capacity,
        };
    }

    fn clone(self: *const State) !State {
        var cloned_registry = try self.registry.clone();
        errdefer cloned_registry.deinit();
        const levels = try self.allocator.alloc(ActiveLevel, self.levels.len);
        errdefer self.allocator.free(levels);
        var level_count: usize = 0;
        errdefer for (levels[0..level_count]) |*active_level| active_level.deinit(self.allocator);
        for (self.levels[0..self.level_count], 0..) |active_level, index| {
            levels[index] = try active_level.clone(self.allocator);
            level_count += 1;
        }
        const active_world = if (self.active_world) |active| try active.clone(self.allocator) else null;
        return .{
            .allocator = self.allocator,
            .registry = cloned_registry,
            .levels = levels,
            .level_count = level_count,
            .logical_level_capacity = self.logical_level_capacity,
            .active_world = active_world,
        };
    }

    fn deinit(self: *State) void {
        if (self.active_world) |*active| active.deinit(self.allocator);
        for (self.levels[0..self.level_count]) |*active_level| active_level.deinit(self.allocator);
        self.allocator.free(self.levels);
        self.registry.deinit();
        self.* = undefined;
    }

    fn findLevel(self: *const State, id: foundation.identity.AssetId) ?usize {
        for (self.levels[0..self.level_count], 0..) |active_level, index| {
            if (active_level.source.exact.revision.asset_id.eql(id)) return index;
        }
        return null;
    }

    fn rootOrigin(self: *const State, lifetime: runtime_entity.Lifetime) !level.WorldCoordinateOrigin {
        const level_id = lifetime.owningLevel() orelse return zero_origin;
        const index = self.findLevel(level_id) orelse return error.LevelNotActive;
        return self.levels[index].origin;
    }

    fn reserveLevel(self: *State, cause: registry_module.GrowthCause) !void {
        if (self.level_count < self.logical_level_capacity) return;
        if (self.logical_level_capacity == self.levels.len) return error.LevelCapacity;
        const old = self.logical_level_capacity;
        const doubled = if (old == 0) @as(usize, 1) else if (old > self.levels.len / 2) self.levels.len else old * 2;
        self.logical_level_capacity = @max(old + 1, doubled);
        try self.growth.add(.{
            .category = .active_levels,
            .old_capacity = old,
            .new_capacity = self.logical_level_capacity,
            .hard_capacity = self.levels.len,
            .cause = cause,
        });
    }
};

pub const Config = struct {
    registry: registry_module.Config,
    initial_level_capacity: usize = 1,
    hard_level_capacity: usize = 16,
    max_snapshot_leases: usize = 4,
    growth_sink: ?registry_module.GrowthSink = null,
};

pub const RuntimeScene = struct {
    allocator: std.mem.Allocator,
    state: State,
    publication_generation: u64 = 0,
    snapshot_leases: usize = 0,
    max_snapshot_leases: usize,
    growth_sink: ?registry_module.GrowthSink,

    pub fn init(allocator: std.mem.Allocator, config: Config) !RuntimeScene {
        if (config.max_snapshot_leases == 0) return error.InvalidSnapshotCapacity;
        return .{
            .allocator = allocator,
            .state = try State.init(
                allocator,
                config.registry,
                config.initial_level_capacity,
                config.hard_level_capacity,
            ),
            .max_snapshot_leases = config.max_snapshot_leases,
            .growth_sink = config.growth_sink,
        };
    }

    pub fn deinit(self: *RuntimeScene) error{OutstandingSnapshotLeases}!void {
        if (self.snapshot_leases != 0) return error.OutstandingSnapshotLeases;
        self.state.deinit();
        self.* = undefined;
    }

    pub fn activateLevel(self: *RuntimeScene, context: MutationContext, activation: LevelActivation) !void {
        if (context.authority != .world) return error.UnauthorizedMutation;
        try verifySource(activation.source, activation.definition.header, asset.level_kind);
        if (self.state.findLevel(activation.source.revision.asset_id) != null) return error.LevelAlreadyActive;
        var candidate = try self.state.clone();
        errdefer candidate.deinit();
        try candidate.reserveLevel(.level_activation);
        const source_token = try activation.resolver.resolve(activation.source);
        candidate.levels[candidate.level_count] = .{
            .source = try ActiveAsset.init(self.allocator, activation.source, source_token),
            .origin = activation.definition.origin,
        };
        candidate.level_count += 1;
        try assembleEntities(
            &candidate,
            activation.definition.entities,
            .{ .level_owned = activation.definition.header.asset_id },
            activation.prefabs,
            activation.resolver,
            .level_activation,
        );
        try evaluateAll(&candidate);
        try self.publish(&candidate, context.participants);
    }

    pub fn activateWorld(self: *RuntimeScene, context: MutationContext, activation: WorldActivation) !void {
        if (context.authority != .world) return error.UnauthorizedMutation;
        try verifySource(activation.source, activation.definition.header, asset.world_kind);
        if (self.state.active_world != null) return error.WorldAlreadyActive;
        var candidate = try self.state.clone();
        errdefer candidate.deinit();
        const source_token = try activation.resolver.resolve(activation.source);
        for (activation.definition.level_refs) |level_reference| {
            if (!level_reference.expected_kind.eql(asset.level_kind)) return error.SourceRevisionMismatch;
            _ = try activation.resolver.resolve(level_reference);
        }
        candidate.active_world = try ActiveAsset.init(self.allocator, activation.source, source_token);
        try assembleEntities(
            &candidate,
            activation.definition.persistent_entities,
            .world_persistent,
            activation.prefabs,
            activation.resolver,
            .world_activation,
        );
        try evaluateAll(&candidate);
        try self.publish(&candidate, context.participants);
    }

    pub fn deactivateLevel(
        self: *RuntimeScene,
        context: MutationContext,
        level_id: foundation.identity.AssetId,
    ) !void {
        if (context.authority != .world) return error.UnauthorizedMutation;
        const active_index = self.state.findLevel(level_id) orelse return error.LevelNotActive;
        var candidate = try self.state.clone();
        errdefer candidate.deinit();

        var active_index_scan: usize = 0;
        while (active_index_scan < candidate.registry.active_count) : (active_index_scan += 1) {
            const handle = candidate.registry.activeHandleAt(active_index_scan).?;
            const record = try candidate.registry.get(handle);
            if (record.lifetime.owningLevel()) |owner| {
                if (!owner.eql(level_id)) continue;
                for (record.children) |child| {
                    const child_record = try candidate.registry.get(child);
                    const child_level = child_record.lifetime.owningLevel();
                    if (child_level == null or !child_level.?.eql(level_id)) return error.LevelHasExternalDependents;
                }
            }
        }

        var index: usize = 0;
        while (index < candidate.registry.active_count) {
            const handle = candidate.registry.activeHandleAt(index).?;
            const record = try candidate.registry.get(handle);
            if (record.lifetime.owningLevel()) |owner| {
                if (owner.eql(level_id)) {
                    try destroySubtreeInternal(&candidate, handle, .level_deactivation);
                    index = 0;
                    continue;
                }
            }
            index += 1;
        }

        candidate.levels[active_index].deinit(self.allocator);
        if (active_index + 1 < candidate.level_count) {
            std.mem.copyForwards(
                ActiveLevel,
                candidate.levels[active_index .. candidate.level_count - 1],
                candidate.levels[active_index + 1 .. candidate.level_count],
            );
        }
        candidate.level_count -= 1;
        try evaluateAll(&candidate);
        try self.publish(&candidate, context.participants);
    }

    pub fn spawnTemporary(
        self: *RuntimeScene,
        context: MutationContext,
        definition: TransientDefinition,
    ) !foundation.identity.EntityHandle {
        try authorizeTransientOwner(context.authority, definition.owner);
        if (ownerLevel(definition)) |id| if (self.state.findLevel(id) == null) return error.LevelNotActive;
        var candidate = try self.state.clone();
        errdefer candidate.deinit();
        const lifetime = runtime_entity.Lifetime{ .transient = definition.owner };
        var record = try runtime_entity.RuntimeEntity.initOwned(
            self.allocator,
            .{
                .persistent_id = null,
                .lifetime = lifetime,
                .local_transform = definition.local_transform,
                .authored_enabled = definition.enabled,
                .visibility = definition.visibility,
                .tags = definition.tags,
                .extensions = definition.extensions,
                .camera_definition = definition.camera_definition,
            },
            definition.resolver,
            try candidate.rootOrigin(lifetime),
        );
        var caller_owns_record = true;
        errdefer if (caller_owns_record) record.deinit(self.allocator);
        const handle = try candidate.registry.insert(record, growthCauseForAuthority(context.authority), &candidate.growth);
        caller_owns_record = false;
        if (definition.parent) |parent| try assignParentInternal(&candidate, handle, parent);
        try evaluateAll(&candidate);
        try self.publish(&candidate, context.participants);
        return handle;
    }

    pub fn promoteTemporary(
        self: *RuntimeScene,
        context: MutationContext,
        handle: foundation.identity.EntityHandle,
        persistent_id: foundation.identity.EntityId,
    ) !void {
        if (context.authority != .physics_gameplay) return error.UnauthorizedMutation;
        const current = try self.state.registry.get(handle);
        const level_host = switch (current.lifetime) {
            .transient => |owner| switch (owner) {
                .physics_gameplay => |host| host,
                else => return error.UnauthorizedMutation,
            },
            else => return error.EntityAlreadyPersistent,
        };
        if (current.parent) |parent| {
            if (!(try self.state.registry.get(parent)).lifetime.isPersistentWorld()) return error.PersistentBelowLevelOwned;
        } else if (level_host != null) {
            // An unparented Level-hosted transient is evaluated relative to its
            // exact Level origin. World persistence would reinterpret the same
            // local affine relative to world zero, and F2C intentionally does
            // not implement that spatial-domain transfer.
            return error.PromotionRequiresWorldRebase;
        }
        const world_before = current.world_transform;
        var candidate = try self.state.clone();
        errdefer candidate.deinit();
        try candidate.registry.assignPersistentId(handle, persistent_id, .runtime_create, &candidate.growth);
        (try candidate.registry.getMutable(handle)).lifetime = .world_persistent;
        try markDirtySubtree(&candidate, handle);
        try evaluateAll(&candidate);
        const world_after = (try candidate.registry.get(handle)).world_transform;
        if (!std.meta.eql(world_before.origin, world_after.origin) or
            !foundation.spatial.approximatelyEqual(world_before.affine, world_after.affine))
        {
            return error.PromotionRequiresWorldRebase;
        }
        try self.publish(&candidate, context.participants);
    }

    pub fn setLocalTransform(
        self: *RuntimeScene,
        context: MutationContext,
        handle: foundation.identity.EntityHandle,
        local_transform: foundation.spatial.LocalTransform,
    ) !void {
        local_transform.validate() catch return error.InvalidRuntimeTransform;
        try authorizeMutation(try self.state.registry.get(handle), context.authority);
        var candidate = try self.state.clone();
        errdefer candidate.deinit();
        const record = try candidate.registry.getMutable(handle);
        record.local_transform = local_transform;
        record.local_revision = std.math.add(u64, record.local_revision, 1) catch return error.GenerationExhausted;
        try markDirtySubtree(&candidate, handle);
        try evaluateAll(&candidate);
        try self.publish(&candidate, context.participants);
    }

    pub fn setEnabled(
        self: *RuntimeScene,
        context: MutationContext,
        handle: foundation.identity.EntityHandle,
        enabled: metadata.EnabledIntent,
    ) !void {
        try authorizeMutation(try self.state.registry.get(handle), context.authority);
        var candidate = try self.state.clone();
        errdefer candidate.deinit();
        const record = try candidate.registry.getMutable(handle);
        record.authored_enabled = enabled;
        try markDirtySubtree(&candidate, handle);
        try evaluateAll(&candidate);
        try self.publish(&candidate, context.participants);
    }

    pub fn setParent(
        self: *RuntimeScene,
        context: MutationContext,
        child: foundation.identity.EntityHandle,
        new_parent: ?foundation.identity.EntityHandle,
        mode: ParentMode,
    ) !void {
        try authorizeMutation(try self.state.registry.get(child), context.authority);
        if (new_parent) |parent| _ = try self.state.registry.get(parent);
        var candidate = try self.state.clone();
        errdefer candidate.deinit();
        try reparentInternal(&candidate, child, new_parent, mode);
        try evaluateAll(&candidate);
        try self.publish(&candidate, context.participants);
    }

    pub fn destroyEntity(
        self: *RuntimeScene,
        context: MutationContext,
        handle: foundation.identity.EntityHandle,
        policy: RemovalPolicy,
    ) !void {
        try authorizeRemovalSubtree(&self.state, handle, context.authority, policy);
        var candidate = try self.state.clone();
        errdefer candidate.deinit();
        switch (policy) {
            .reject_if_children => {
                if ((try candidate.registry.get(handle)).children.len != 0) return error.EntityHasChildren;
                try destroyOneInternal(&candidate, handle, .entity_destroy);
            },
            .cascade => try destroySubtreeInternal(&candidate, handle, .entity_destroy),
            .orphan_keep_world => try orphanAndDestroyInternal(&candidate, handle, .entity_destroy),
        }
        try evaluateAll(&candidate);
        try self.publish(&candidate, context.participants);
    }

    pub fn acquireSnapshot(self: *RuntimeScene, time: SceneTime) !SceneSnapshot {
        try time.validate();
        if (self.snapshot_leases == self.max_snapshot_leases) return error.SnapshotCapacity;
        const storage = try self.allocator.create(SnapshotStorage);
        errdefer self.allocator.destroy(storage);
        storage.* = .{ .state = try self.state.clone() };
        self.snapshot_leases += 1;
        return .{
            .owner_context = self,
            .storage_context = storage,
            .publication_generation = self.publication_generation,
            .time = time,
        };
    }

    fn publish(self: *RuntimeScene, candidate: *State, participants: []const PublicationParticipant) !void {
        const next_generation = std.math.add(u64, self.publication_generation, 1) catch return error.GenerationExhausted;
        const candidate_view = SceneReadView.init(candidate, next_generation);
        var prepared: usize = 0;
        errdefer {
            var index = prepared;
            while (index > 0) {
                index -= 1;
                participants[index].rollback_fn(participants[index].context);
            }
        }
        for (participants) |participant| {
            participant.prepare_fn(participant.context, candidate_view) catch {
                participant.rollback_fn(participant.context);
                return error.PublicationPrepareFailed;
            };
            prepared += 1;
        }
        var previous = self.state;
        self.state = candidate.*;
        candidate.* = undefined;
        self.publication_generation = next_generation;
        for (participants) |participant| participant.commit_fn(participant.context, next_generation);
        previous.deinit();
        if (self.growth_sink) |sink| sink.emit(self.state.growth.values());
        self.state.growth.count = 0;
    }
};

fn ownerLevel(definition: TransientDefinition) ?foundation.identity.AssetId {
    return switch (definition.owner) {
        .level => |id| id,
        .physics_gameplay, .editor_preview, .cutscene_preview => |host| host,
    };
}

pub fn transientOwnerLevel(definition: TransientDefinition) ?foundation.identity.AssetId {
    return ownerLevel(definition);
}

const SnapshotStorage = struct {
    state: State,
};

pub const SceneSnapshot = struct {
    owner_context: *anyopaque,
    storage_context: *anyopaque,
    publication_generation: u64,
    time: SceneTime,
    released: bool = false,

    pub fn view(self: *const SceneSnapshot) SceneReadView {
        const storage: *const SnapshotStorage = @ptrCast(@alignCast(self.storage_context));
        return SceneReadView.init(&storage.state, self.publication_generation);
    }

    pub fn deinit(self: *SceneSnapshot) void {
        if (self.released) return;
        const owner: *RuntimeScene = @ptrCast(@alignCast(self.owner_context));
        const storage: *SnapshotStorage = @ptrCast(@alignCast(self.storage_context));
        storage.state.deinit();
        owner.allocator.destroy(storage);
        owner.snapshot_leases -= 1;
        self.released = true;
    }
};

pub const ExtensionView = struct {
    context: *const anyopaque,
    type_id: []const u8,
    schema_version: foundation.version.SchemaVersion,
    criticality: @import("extension.zig").Criticality,
    canonical_payload: []const u8,

    pub fn dependencyCount(self: ExtensionView) usize {
        return extensionRecord(self).dependencies.len;
    }

    pub fn dependencyAt(self: ExtensionView, index: usize) ?DependencyView {
        const dependencies = extensionRecord(self).dependencies;
        if (index >= dependencies.len) return null;
        const dependency = dependencies[index];
        return .{
            .class = dependency.class,
            .reference = dependency.exact.view(),
            .token = dependency.token,
        };
    }

    fn extensionRecord(self: ExtensionView) *const runtime_entity.OwnedExtension {
        return @ptrCast(@alignCast(self.context));
    }
};

pub const DependencyView = struct {
    class: foundation.reference.DependencyClass,
    reference: foundation.reference.AssetRef,
    token: runtime_asset.ResolvedAssetToken,
};

pub const AssetView = struct {
    role: runtime_entity.AssetRole,
    extension_index: ?u16,
    reference: foundation.reference.AssetRef,
    token: runtime_asset.ResolvedAssetToken,
};

pub const OverrideView = struct {
    node_path: []const u8,
    component_type_id: []const u8,
    property_path: []const u8,
    canonical_value: []const u8,
};

pub const EntityView = struct {
    context: *const anyopaque,
    handle: foundation.identity.EntityHandle,
    persistent_id: ?foundation.identity.EntityId,
    lifetime: runtime_entity.Lifetime,
    parent: ?foundation.identity.EntityHandle,
    local_transform: foundation.spatial.LocalTransform,
    world_transform: runtime_entity.WorldTransform,
    authored_enabled: metadata.EnabledIntent,
    effective_enabled: bool,
    visibility: metadata.VisibilityIntent,
    camera_definition: ?@import("camera.zig").CameraDefinition,
    local_revision: u64,
    world_revision: u64,
    recomputation_count: u64,

    pub fn childCount(self: EntityView) usize {
        return entityRecord(self).children.len;
    }

    pub fn childAt(self: EntityView, index: usize) ?foundation.identity.EntityHandle {
        const children = entityRecord(self).children;
        return if (index < children.len) children[index] else null;
    }

    pub fn tagCount(self: EntityView) usize {
        return entityRecord(self).tags.len;
    }

    pub fn tagAt(self: EntityView, index: usize) ?[]const u8 {
        const tags = entityRecord(self).tags;
        return if (index < tags.len) tags[index] else null;
    }

    pub fn extensionCount(self: EntityView) usize {
        return entityRecord(self).extensions.len;
    }

    pub fn extensionAt(self: EntityView, index: usize) ?ExtensionView {
        const records = entityRecord(self).extensions;
        if (index >= records.len) return null;
        const record = records[index];
        return .{
            .context = &records[index],
            .type_id = record.type_id,
            .schema_version = record.schema_version,
            .criticality = record.criticality,
            .canonical_payload = record.canonical_payload,
        };
    }

    pub fn findExtension(self: EntityView, type_id: []const u8) ?ExtensionView {
        const record = entityRecord(self).findExtension(type_id) orelse return null;
        return .{
            .context = record,
            .type_id = record.type_id,
            .schema_version = record.schema_version,
            .criticality = record.criticality,
            .canonical_payload = record.canonical_payload,
        };
    }

    pub fn assetCount(self: EntityView) usize {
        return entityRecord(self).resolved_assets.len;
    }

    pub fn assetAt(self: EntityView, index: usize) ?AssetView {
        const records = entityRecord(self).resolved_assets;
        if (index >= records.len) return null;
        const record = records[index];
        return .{
            .role = record.role,
            .extension_index = record.extension_index,
            .reference = record.exact.view(),
            .token = record.token,
        };
    }

    pub fn overrideCount(self: EntityView) usize {
        return entityRecord(self).applied_overrides.len;
    }

    pub fn overrideAt(self: EntityView, index: usize) ?OverrideView {
        const records = entityRecord(self).applied_overrides;
        if (index >= records.len) return null;
        const record = records[index];
        return .{
            .node_path = record.node_path,
            .component_type_id = record.component_type_id,
            .property_path = record.property_path,
            .canonical_value = record.canonical_value,
        };
    }

    pub fn prefabNodePath(self: EntityView) ?[]const u8 {
        return entityRecord(self).prefab_node_path;
    }

    fn entityRecord(self: EntityView) *const runtime_entity.RuntimeEntity {
        return @ptrCast(@alignCast(self.context));
    }
};

pub const LevelView = struct {
    source: foundation.reference.AssetRef,
    token: runtime_asset.ResolvedAssetToken,
    origin: level.WorldCoordinateOrigin,
};

pub const SceneReadView = struct {
    context: *const anyopaque,
    publication_generation: u64,

    fn init(state: *const State, generation: u64) SceneReadView {
        return .{ .context = state, .publication_generation = generation };
    }

    pub fn entityCount(self: SceneReadView) usize {
        return sceneState(self).registry.active_count;
    }

    pub fn entityAt(self: SceneReadView, index: usize) ?EntityView {
        const state = sceneState(self);
        const handle = state.registry.activeHandleAt(index) orelse return null;
        return makeEntityView(state.registry.get(handle) catch return null);
    }

    pub fn get(self: SceneReadView, handle: foundation.identity.EntityHandle) !EntityView {
        return makeEntityView(try sceneState(self).registry.get(handle));
    }

    pub fn resolve(self: SceneReadView, id: foundation.identity.EntityId) ?foundation.identity.EntityHandle {
        return sceneState(self).registry.resolve(id);
    }

    pub fn levelCount(self: SceneReadView) usize {
        return sceneState(self).level_count;
    }

    pub fn levelAt(self: SceneReadView, index: usize) ?LevelView {
        const state = sceneState(self);
        if (index >= state.level_count) return null;
        const active_level = state.levels[index];
        return .{
            .source = active_level.source.exact.view(),
            .token = active_level.source.token,
            .origin = active_level.origin,
        };
    }

    pub fn entityCapacity(self: SceneReadView) usize {
        return sceneState(self).registry.entityCapacity();
    }

    /// Emits the deterministic shared enabled-transition order. Enabling is
    /// parent-before-child; disabling is the exact reverse, so children always
    /// transition before parents. Root and sibling ties use persistent
    /// EntityId order, then handle order for runtime-only temporaries.
    pub fn lifecycleOrder(
        self: SceneReadView,
        enabling: bool,
        output: []foundation.identity.EntityHandle,
    ) ![]const foundation.identity.EntityHandle {
        const state = sceneState(self);
        if (output.len < state.registry.active_count) return error.ScratchTooSmall;
        var emitted: usize = 0;
        var previous_root: ?foundation.identity.EntityHandle = null;
        while (true) {
            var selected: ?foundation.identity.EntityHandle = null;
            var index: usize = 0;
            while (index < state.registry.active_count) : (index += 1) {
                const handle = state.registry.activeHandleAt(index).?;
                if ((try state.registry.get(handle)).parent != null) continue;
                if (previous_root) |previous| if (childOrder(state, handle, previous) != .gt) continue;
                if (selected == null or childOrder(state, handle, selected.?) == .lt) selected = handle;
            }
            const root = selected orelse break;
            try appendPreorder(state, root, output, &emitted);
            previous_root = root;
        }
        if (!enabling) std.mem.reverse(foundation.identity.EntityHandle, output[0..emitted]);
        return output[0..emitted];
    }

    fn sceneState(self: SceneReadView) *const State {
        return @ptrCast(@alignCast(self.context));
    }
};

fn appendPreorder(
    state: *const State,
    handle: foundation.identity.EntityHandle,
    output: []foundation.identity.EntityHandle,
    emitted: *usize,
) !void {
    if (emitted.* == output.len) return error.ScratchTooSmall;
    output[emitted.*] = handle;
    emitted.* += 1;
    for ((try state.registry.get(handle)).children) |child| try appendPreorder(state, child, output, emitted);
}

fn makeEntityView(record: *const runtime_entity.RuntimeEntity) EntityView {
    return .{
        .context = record,
        .handle = record.handle,
        .persistent_id = record.persistent_id,
        .lifetime = record.lifetime,
        .parent = record.parent,
        .local_transform = record.local_transform,
        .world_transform = record.world_transform,
        .authored_enabled = record.authored_enabled,
        .effective_enabled = record.effective_enabled,
        .visibility = record.visibility,
        .camera_definition = record.camera_definition,
        .local_revision = record.local_revision,
        .world_revision = record.world_revision,
        .recomputation_count = record.recomputation_count,
    };
}

fn assembleEntities(
    state: *State,
    definitions: []const entity.EntityInstanceDefinition,
    default_lifetime: runtime_entity.Lifetime,
    prefabs: []const PrefabCatalogEntry,
    resolver: runtime_asset.Resolver,
    cause: registry_module.GrowthCause,
) !void {
    const order = try state.allocator.alloc(usize, definitions.len);
    defer state.allocator.free(order);
    const depths = try state.allocator.alloc(u8, definitions.len);
    defer state.allocator.free(depths);
    const anchors = try collectWorldAnchors(state);
    defer state.allocator.free(anchors);
    const evaluation_order = hierarchy.evaluationOrder(definitions, anchors, order, depths) catch return error.InvalidAuthoredHierarchy;
    for (evaluation_order) |definition_index| {
        const definition = definitions[definition_index];
        const lifetime = lifetimeForDefinition(default_lifetime, definition.classification);
        var record = try runtime_entity.RuntimeEntity.initOwned(
            state.allocator,
            .{
                .persistent_id = definition.entity_id,
                .lifetime = lifetime,
                .local_transform = definition.local_transform,
                .authored_enabled = definition.enabled,
                .visibility = definition.visibility,
                .tags = definition.tags,
                .extensions = definition.extensions,
                .camera_definition = definition.camera_definition,
            },
            resolver,
            try state.rootOrigin(lifetime),
        );
        var caller_owns_record = true;
        errdefer if (caller_owns_record) record.deinit(state.allocator);
        try resolveInstanceAssets(state.allocator, &record, definition, resolver);
        const handle = try state.registry.insert(record, cause, &state.growth);
        caller_owns_record = false;
        if (definition.parent) |parent_reference| {
            const parent_handle = state.registry.resolve(parent_reference.entity_id) orelse return error.EntityNotFound;
            try assignParentInternal(state, handle, parent_handle);
        }
        if (definition.prefab_ref) |prefab_reference| {
            var stack: [prefab.max_nested_prefab_depth]foundation.identity.AssetId = undefined;
            try expandPrefab(
                state,
                definition.entity_id,
                handle,
                "",
                prefab_reference,
                definition.overrides,
                prefabs,
                resolver,
                lifetime,
                cause,
                &stack,
                0,
            );
        }
    }
}

fn expandPrefab(
    state: *State,
    root_id: foundation.identity.EntityId,
    parent_handle: foundation.identity.EntityHandle,
    path_prefix: []const u8,
    prefab_reference: foundation.reference.AssetRef,
    overrides: []const entity.OverrideRecord,
    catalog: []const PrefabCatalogEntry,
    resolver: runtime_asset.Resolver,
    lifetime: runtime_entity.Lifetime,
    cause: registry_module.GrowthCause,
    stack: *[prefab.max_nested_prefab_depth]foundation.identity.AssetId,
    depth: usize,
) !void {
    if (depth == stack.len) return error.NestedPrefabTooDeep;
    for (stack[0..depth]) |id| if (id.eql(prefab_reference.revision.asset_id)) return error.NestedPrefabCycle;
    stack[depth] = prefab_reference.revision.asset_id;
    const definition = findPrefabExact(catalog, prefab_reference) orelse return error.AssetResolutionFailed;
    _ = try resolver.resolve(prefab_reference);
    const order = try state.allocator.alloc(usize, definition.nodes.len);
    defer state.allocator.free(order);
    const depths = try state.allocator.alloc(u8, definition.nodes.len);
    defer state.allocator.free(depths);
    const node_order = try prefabEvaluationOrder(definition.*, order, depths);
    const bindings = try state.allocator.alloc(NodeBinding, definition.nodes.len);
    defer state.allocator.free(bindings);
    var binding_count: usize = 0;

    for (node_order) |node_index| {
        const node = definition.nodes[node_index];
        const full_path = try joinNodePath(state.allocator, path_prefix, node.node_id.value);
        defer state.allocator.free(full_path);
        const persistent_id = prefab.deriveInstantiatedEntityId(root_id, full_path) catch return error.InvalidPrefabNodePath;
        var record = try runtime_entity.RuntimeEntity.initOwned(
            state.allocator,
            .{
                .persistent_id = persistent_id,
                .lifetime = lifetime,
                .local_transform = node.local_transform,
                .authored_enabled = node.enabled,
                .visibility = node.visibility,
                .tags = node.tags,
                .extensions = node.extensions,
                .prefab_node_path = full_path,
            },
            resolver,
            try state.rootOrigin(lifetime),
        );
        var caller_owns_record = true;
        errdefer if (caller_owns_record) record.deinit(state.allocator);
        try appendExtensionDependencyAssets(state.allocator, &record, resolver);
        const handle = try state.registry.insert(record, cause, &state.growth);
        caller_owns_record = false;
        const runtime_parent = if (node.parent) |parent_node| findNodeBinding(bindings[0..binding_count], parent_node) orelse return error.InvalidAuthoredHierarchy else parent_handle;
        try assignParentInternal(state, handle, runtime_parent);
        bindings[binding_count] = .{ .id = node.node_id, .handle = handle };
        binding_count += 1;
        const mutable_record = try state.registry.getMutable(handle);
        for (overrides) |override| {
            if (std.mem.eql(u8, override.target.node_path, full_path)) try mutable_record.appendOverride(state.allocator, override);
        }
        if (node.nested_prefab_ref) |nested| {
            const nested_token = try resolver.resolve(nested);
            try mutable_record.appendResolvedAsset(state.allocator, .nested_prefab_source, null, nested, nested_token);
            try expandPrefab(
                state,
                root_id,
                handle,
                full_path,
                nested,
                overrides,
                catalog,
                resolver,
                lifetime,
                cause,
                stack,
                depth + 1,
            );
        }
    }
}

const NodeBinding = struct {
    id: prefab.PrefabNodeId,
    handle: foundation.identity.EntityHandle,
};

fn findNodeBinding(bindings: []const NodeBinding, id: prefab.PrefabNodeId) ?foundation.identity.EntityHandle {
    for (bindings) |binding| if (binding.id.eql(id)) return binding.handle;
    return null;
}

fn prefabEvaluationOrder(definition: prefab.PrefabDefinition, output: []usize, depth: []u8) ![]const usize {
    @memset(depth, 0);
    var emitted: usize = 0;
    while (emitted < definition.nodes.len) : (emitted += 1) {
        var selected: ?usize = null;
        var selected_depth: usize = 0;
        for (definition.nodes, 0..) |node, index| {
            if (depth[index] != 0) continue;
            const node_depth = if (node.parent) |parent_id| blk: {
                var parent_index: ?usize = null;
                for (definition.nodes, 0..) |candidate, candidate_index| {
                    if (candidate.node_id.eql(parent_id)) parent_index = candidate_index;
                }
                const resolved_parent = parent_index orelse return error.InvalidAuthoredHierarchy;
                if (depth[resolved_parent] == 0) continue;
                break :blk @as(usize, depth[resolved_parent]) + 1;
            } else 1;
            if (node_depth > hierarchy.max_entity_hierarchy_depth) return error.HierarchyTooDeep;
            if (selected == null or node.node_id.order(definition.nodes[selected.?].node_id) == .lt) {
                selected = index;
                selected_depth = node_depth;
            }
        }
        const index = selected orelse return error.RuntimeParentCycle;
        depth[index] = @intCast(selected_depth);
        output[emitted] = index;
    }
    return output[0..definition.nodes.len];
}

fn resolveInstanceAssets(
    allocator: std.mem.Allocator,
    record: *runtime_entity.RuntimeEntity,
    definition: entity.EntityInstanceDefinition,
    resolver: runtime_asset.Resolver,
) !void {
    if (definition.prefab_ref) |reference| try record.appendResolvedAsset(allocator, .prefab_source, null, reference, try resolver.resolve(reference));
    if (definition.presentation) |reference| try record.appendResolvedAsset(allocator, .presentation, null, reference.asset, try resolver.resolve(reference.asset));
    if (definition.volume_shape) |reference| try record.appendResolvedAsset(allocator, .volume_shape, null, reference.asset, try resolver.resolve(reference.asset));
    for (definition.layers) |layer_assignment| try record.appendResolvedAsset(allocator, .layer, null, layer_assignment.layer, try resolver.resolve(layer_assignment.layer));
    try appendExtensionDependencyAssets(allocator, record, resolver);
}

fn appendExtensionDependencyAssets(allocator: std.mem.Allocator, record: *runtime_entity.RuntimeEntity, resolver: runtime_asset.Resolver) !void {
    for (record.extensions, 0..) |owned_extension, extension_index| {
        for (owned_extension.dependencies) |dependency| {
            try record.appendResolvedAsset(
                allocator,
                .extension_dependency,
                @intCast(extension_index),
                dependency.exact.view(),
                try resolver.resolve(dependency.exact.view()),
            );
        }
    }
}

fn collectWorldAnchors(state: *const State) ![]foundation.identity.EntityId {
    var count: usize = 0;
    var index: usize = 0;
    while (index < state.registry.active_count) : (index += 1) {
        const handle = state.registry.activeHandleAt(index).?;
        const record = try state.registry.get(handle);
        if (record.lifetime.isPersistentWorld() and record.persistent_id != null) count += 1;
    }
    const result = try state.allocator.alloc(foundation.identity.EntityId, count);
    var output_index: usize = 0;
    index = 0;
    while (index < state.registry.active_count) : (index += 1) {
        const handle = state.registry.activeHandleAt(index).?;
        const record = try state.registry.get(handle);
        if (record.lifetime.isPersistentWorld()) if (record.persistent_id) |id| {
            result[output_index] = id;
            output_index += 1;
        };
    }
    return result;
}

fn lifetimeForDefinition(default_lifetime: runtime_entity.Lifetime, classification: metadata.PlacementClassification) runtime_entity.Lifetime {
    const host = default_lifetime.owningLevel();
    return switch (classification) {
        .authored => default_lifetime,
        .editor_preview => .{ .transient = .{ .editor_preview = host } },
        .cutscene_overlay => .{ .transient = .{ .cutscene_preview = host } },
    };
}

fn assignParentInternal(state: *State, child: foundation.identity.EntityHandle, parent: foundation.identity.EntityHandle) !void {
    if (child.eql(parent)) return error.RuntimeParentCycle;
    const child_record = try state.registry.get(child);
    const parent_record = try state.registry.get(parent);
    try validateParentScope(child_record.lifetime, parent_record.lifetime);
    var cursor: ?foundation.identity.EntityHandle = parent;
    while (cursor) |ancestor| {
        if (ancestor.eql(child)) return error.RuntimeParentCycle;
        cursor = (try state.registry.get(ancestor)).parent;
    }
    if (child_record.parent != null) return error.ParentAlreadyAssigned;
    (try state.registry.getMutable(child)).parent = parent;
    try appendChildSorted(state, parent, child);
    try markDirtySubtree(state, child);
}

fn reparentInternal(
    state: *State,
    child: foundation.identity.EntityHandle,
    new_parent: ?foundation.identity.EntityHandle,
    mode: ParentMode,
) !void {
    const before = try state.registry.get(child);
    const old_world = before.world_transform;
    if (new_parent) |parent| {
        if (parent.eql(child)) return error.RuntimeParentCycle;
        const parent_record = try state.registry.get(parent);
        try validateParentScope(before.lifetime, parent_record.lifetime);
        var cursor: ?foundation.identity.EntityHandle = parent;
        while (cursor) |ancestor| {
            if (ancestor.eql(child)) return error.RuntimeParentCycle;
            cursor = (try state.registry.get(ancestor)).parent;
        }
    }
    var replacement_local = before.local_transform;
    if (mode == .keep_world) {
        const new_origin = if (new_parent) |parent| (try state.registry.get(parent)).world_transform.origin else try state.rootOrigin(before.lifetime);
        if (!sameOrigin(old_world.origin, new_origin)) return error.CrossOriginKeepWorldUnsupported;
        const local_affine = if (new_parent) |parent| try foundation.spatial.AffineTransform.compose(
            try (try state.registry.get(parent)).world_transform.affine.inverse(),
            old_world.affine,
        ) else old_world.affine;
        replacement_local = local_affine.toLocal() catch |spatial_error| return spatial_error;
    }
    if (before.parent) |old_parent| try removeChild(state, old_parent, child);
    const mutable = try state.registry.getMutable(child);
    mutable.parent = new_parent;
    mutable.local_transform = replacement_local;
    mutable.local_revision = std.math.add(u64, mutable.local_revision, 1) catch return error.GenerationExhausted;
    if (new_parent) |parent| try appendChildSorted(state, parent, child);
    try markDirtySubtree(state, child);
}

fn appendChildSorted(state: *State, parent: foundation.identity.EntityHandle, child: foundation.identity.EntityHandle) !void {
    const parent_record = try state.registry.getMutable(parent);
    const replacement = try state.allocator.alloc(foundation.identity.EntityHandle, parent_record.children.len + 1);
    errdefer state.allocator.free(replacement);
    @memcpy(replacement[0..parent_record.children.len], parent_record.children);
    replacement[parent_record.children.len] = child;
    if (parent_record.children.len != 0) state.allocator.free(parent_record.children);
    parent_record.children = replacement;
    var index = parent_record.children.len - 1;
    while (index > 0 and childOrder(state, parent_record.children[index], parent_record.children[index - 1]) == .lt) : (index -= 1) {
        std.mem.swap(foundation.identity.EntityHandle, &parent_record.children[index], &parent_record.children[index - 1]);
    }
}

fn removeChild(state: *State, parent: foundation.identity.EntityHandle, child: foundation.identity.EntityHandle) !void {
    const parent_record = try state.registry.getMutable(parent);
    for (parent_record.children, 0..) |candidate, index| {
        if (!candidate.eql(child)) continue;
        if (parent_record.children.len == 1) {
            state.allocator.free(parent_record.children);
            parent_record.children = &.{};
            return;
        }
        const replacement = try state.allocator.alloc(foundation.identity.EntityHandle, parent_record.children.len - 1);
        @memcpy(replacement[0..index], parent_record.children[0..index]);
        @memcpy(replacement[index..], parent_record.children[index + 1 ..]);
        state.allocator.free(parent_record.children);
        parent_record.children = replacement;
        return;
    }
    return error.InvalidHierarchyAdjacency;
}

fn childOrder(state: *const State, a: foundation.identity.EntityHandle, b: foundation.identity.EntityHandle) std.math.Order {
    const a_record = state.registry.get(a) catch return handleOrder(a, b);
    const b_record = state.registry.get(b) catch return handleOrder(a, b);
    if (a_record.persistent_id) |a_id| {
        if (b_record.persistent_id) |b_id| return a_id.byteOrder(b_id);
        return .lt;
    }
    if (b_record.persistent_id != null) return .gt;
    return handleOrder(a, b);
}

fn handleOrder(a: foundation.identity.EntityHandle, b: foundation.identity.EntityHandle) std.math.Order {
    const slot_order = std.math.order(a.slot, b.slot);
    return if (slot_order != .eq) slot_order else std.math.order(a.generation, b.generation);
}

fn markDirtySubtree(state: *State, handle: foundation.identity.EntityHandle) !void {
    const record = try state.registry.getMutable(handle);
    record.dirty = true;
    const children = record.children;
    for (children) |child| try markDirtySubtree(state, child);
}

fn evaluateAll(state: *State) !void {
    const visit = try state.allocator.alloc(u8, state.registry.hardEntityCapacity());
    defer state.allocator.free(visit);
    @memset(visit, 0);
    var index: usize = 0;
    while (index < state.registry.active_count) : (index += 1) {
        const handle = state.registry.activeHandleAt(index).?;
        try evaluateOne(state, handle, visit);
    }
}

fn evaluateOne(state: *State, handle: foundation.identity.EntityHandle, visit: []u8) !void {
    if (visit[handle.slot] == 2) return;
    if (visit[handle.slot] == 1) return error.RuntimeParentCycle;
    visit[handle.slot] = 1;
    const parent = (try state.registry.get(handle)).parent;
    if (parent) |parent_handle| try evaluateOne(state, parent_handle, visit);
    const record = try state.registry.getMutable(handle);
    const parent_revision = if (parent) |parent_handle| (try state.registry.get(parent_handle)).world_revision else 0;
    if (record.dirty or record.evaluated_parent_revision != parent_revision) {
        const local_affine = try foundation.spatial.AffineTransform.fromLocal(record.local_transform);
        if (parent) |parent_handle| {
            const parent_record = try state.registry.get(parent_handle);
            record.world_transform = .{
                .origin = parent_record.world_transform.origin,
                .affine = try foundation.spatial.AffineTransform.compose(parent_record.world_transform.affine, local_affine),
            };
            record.effective_enabled = metadata.effectiveEnabled(parent_record.effective_enabled, record.authored_enabled);
        } else {
            record.world_transform = .{ .origin = try state.rootOrigin(record.lifetime), .affine = local_affine };
            record.effective_enabled = metadata.effectiveEnabled(true, record.authored_enabled);
        }
        record.evaluated_parent_revision = parent_revision;
        record.world_revision = std.math.add(u64, record.world_revision, 1) catch return error.GenerationExhausted;
        record.recomputation_count = std.math.add(u64, record.recomputation_count, 1) catch return error.GenerationExhausted;
        record.dirty = false;
    }
    visit[handle.slot] = 2;
}

fn authorizeTransientOwner(authority: runtime_entity.MutationAuthority, owner: runtime_entity.TransientOwner) !void {
    const allowed = switch (owner) {
        .level => authority == .world,
        .physics_gameplay => authority == .physics_gameplay,
        .editor_preview => authority == .editor,
        .cutscene_preview => authority == .cinematic,
    };
    if (!allowed) return error.UnauthorizedMutation;
}

fn authorizeMutation(record: *const runtime_entity.RuntimeEntity, authority: runtime_entity.MutationAuthority) !void {
    const allowed = switch (record.lifetime) {
        .world_persistent, .level_owned => authority == .world or authority == .physics_gameplay,
        .transient => |owner| switch (owner) {
            .level => authority == .world,
            .physics_gameplay => authority == .physics_gameplay,
            .editor_preview => authority == .editor,
            .cutscene_preview => authority == .cinematic,
        },
    };
    if (!allowed) return error.UnauthorizedMutation;
}

fn authorizeRemovalSubtree(state: *const State, handle: foundation.identity.EntityHandle, authority: runtime_entity.MutationAuthority, policy: RemovalPolicy) !void {
    const record = try state.registry.get(handle);
    try authorizeMutation(record, authority);
    if (policy == .cascade) for (record.children) |child| try authorizeRemovalSubtree(state, child, authority, policy);
    if (policy == .orphan_keep_world) for (record.children) |child| try authorizeMutation(try state.registry.get(child), authority);
}

fn destroyOneInternal(state: *State, handle: foundation.identity.EntityHandle, cause: registry_module.GrowthCause) !void {
    const parent = (try state.registry.get(handle)).parent;
    if (parent) |parent_handle| try removeChild(state, parent_handle, handle);
    try state.registry.destroy(handle, cause, &state.growth);
}

fn destroySubtreeInternal(state: *State, handle: foundation.identity.EntityHandle, cause: registry_module.GrowthCause) !void {
    while ((try state.registry.get(handle)).children.len != 0) {
        const children = (try state.registry.get(handle)).children;
        try destroySubtreeInternal(state, children[children.len - 1], cause);
    }
    try destroyOneInternal(state, handle, cause);
}

fn orphanAndDestroyInternal(state: *State, handle: foundation.identity.EntityHandle, cause: registry_module.GrowthCause) !void {
    const record = try state.registry.get(handle);
    const children = try state.allocator.dupe(foundation.identity.EntityHandle, record.children);
    defer state.allocator.free(children);
    const locals = try state.allocator.alloc(foundation.spatial.LocalTransform, children.len);
    defer state.allocator.free(locals);
    for (children, 0..) |child, index| {
        const child_record = try state.registry.get(child);
        const new_origin = try state.rootOrigin(child_record.lifetime);
        if (!sameOrigin(child_record.world_transform.origin, new_origin)) return error.CrossOriginKeepWorldUnsupported;
        locals[index] = child_record.world_transform.affine.toLocal() catch |spatial_error| return spatial_error;
    }
    for (children, 0..) |child, index| {
        const child_record = try state.registry.getMutable(child);
        child_record.parent = null;
        child_record.local_transform = locals[index];
        child_record.local_revision = std.math.add(u64, child_record.local_revision, 1) catch return error.GenerationExhausted;
        try markDirtySubtree(state, child);
    }
    const mutable = try state.registry.getMutable(handle);
    state.allocator.free(mutable.children);
    mutable.children = &.{};
    try destroyOneInternal(state, handle, cause);
}

fn findPrefabExact(catalog: []const PrefabCatalogEntry, reference: foundation.reference.AssetRef) ?*const prefab.PrefabDefinition {
    for (catalog) |entry| if (entry.reference.eql(reference)) return entry.definition;
    return null;
}

fn verifySource(reference: foundation.reference.AssetRef, header: asset.AssetHeader, expected_kind: foundation.reference.AssetKind) !void {
    if (!reference.expected_kind.eql(expected_kind) or
        !header.kind.eql(expected_kind) or
        !reference.revision.asset_id.eql(header.asset_id) or
        !reference.revision.version.eql(header.asset_version))
    {
        return error.SourceRevisionMismatch;
    }
}

fn joinNodePath(allocator: std.mem.Allocator, prefix: []const u8, node: []const u8) ![]u8 {
    const separator: usize = if (prefix.len == 0) 0 else 1;
    const length = std.math.add(usize, prefix.len, separator + node.len) catch return error.InvalidPrefabNodePath;
    if (length > 255) return error.InvalidPrefabNodePath;
    const result = try allocator.alloc(u8, length);
    @memcpy(result[0..prefix.len], prefix);
    if (separator != 0) result[prefix.len] = '/';
    @memcpy(result[prefix.len + separator ..], node);
    return result;
}

fn sameOrigin(a: level.WorldCoordinateOrigin, b: level.WorldCoordinateOrigin) bool {
    return a.x_mm == b.x_mm and a.y_mm == b.y_mm and a.z_mm == b.z_mm;
}

fn validateParentScope(child: runtime_entity.Lifetime, parent: runtime_entity.Lifetime) !void {
    if (child.isPersistentWorld() and !parent.isPersistentWorld()) return error.PersistentBelowLevelOwned;
    const child_level = child.owningLevel();
    const parent_level = parent.owningLevel();
    if (child_level != null and parent_level != null and !child_level.?.eql(parent_level.?)) return error.CrossLevelParent;
}

fn growthCauseForAuthority(authority: runtime_entity.MutationAuthority) registry_module.GrowthCause {
    return switch (authority) {
        .world => .runtime_create,
        .physics_gameplay => .runtime_create,
        .editor => .editor_preview,
        .cinematic => .runtime_create,
    };
}
