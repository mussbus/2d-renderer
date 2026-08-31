const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const math = @import("math");
const character = @import("character");

pub const maximum_bindings: usize = character.maximum_characters;
pub const root_tolerance: f32 = foundation.spatial.affine_absolute_tolerance;

const Binding = struct {
    entity_id: foundation.identity.EntityId,
    handle: foundation.identity.EntityHandle,
    character_id: character.EntityId,
    effective_enabled: bool,
    root_position: math.Vec2,
};

const Storage = struct {
    allocator: std.mem.Allocator,
    runtime_scene: scene_core.runtime_scene.RuntimeScene,
    bindings: [maximum_bindings]Binding = undefined,
    binding_count: usize = 0,
    pending_bindings: [maximum_bindings]Binding = undefined,
    pending_count: usize = 0,
    pending_ready: bool = false,
    publication_generation: u64 = 0,
};

/// Specialized character attachment beneath F-owned entity identity and
/// lifecycle. Its mapping and RuntimeScene storage are intentionally opaque.
pub const CharacterEntityBindings = struct {
    opaque_context: *const anyopaque,

    pub fn init(allocator: std.mem.Allocator) !CharacterEntityBindings {
        return initWithRuntimeAllocator(allocator, allocator);
    }

    /// Separates adapter-handle allocation from RuntimeScene's accepted
    /// transactional mutation allocator. Production arena owners can provide
    /// a reclaiming allocator without changing an F or character API.
    pub fn initWithRuntimeAllocator(
        storage_allocator: std.mem.Allocator,
        runtime_allocator: std.mem.Allocator,
    ) !CharacterEntityBindings {
        const storage = try storage_allocator.create(Storage);
        errdefer storage_allocator.destroy(storage);
        storage.* = .{
            .allocator = storage_allocator,
            .runtime_scene = try scene_core.runtime_scene.RuntimeScene.init(runtime_allocator, .{
                .registry = .{
                    .initial_entity_capacity = maximum_bindings,
                    .hard_entity_capacity = maximum_bindings,
                    .initial_mapping_capacity = maximum_bindings,
                    .hard_mapping_capacity = maximum_bindings,
                },
                .initial_level_capacity = 1,
                .hard_level_capacity = 1,
                .max_snapshot_leases = 4,
            }),
        };
        return .{ .opaque_context = storage };
    }

    pub fn deinit(self: *CharacterEntityBindings) void {
        const storage = storageMutable(self);
        storage.runtime_scene.deinit() catch |err| {
            std.debug.panic("character/F adapter deinit failed: {s}", .{@errorName(err)});
        };
        const allocator = storage.allocator;
        allocator.destroy(storage);
        self.* = undefined;
    }

    /// Creates the authoritative F entity, promotes it to persistent world
    /// lifetime, and binds the existing specialized runtime ID. Any later
    /// failure destroys the just-created entity before returning.
    pub fn createPersistent(
        self: *CharacterEntityBindings,
        entity_id: foundation.identity.EntityId,
        character_id: character.EntityId,
        initial_position: math.Vec2,
    ) !foundation.identity.EntityHandle {
        const storage = storageMutable(self);
        try ensureBindingAvailable(storage, entity_id, character_id, null);
        if (!initial_position.isFinite()) return error.InvalidCharacterRoot;
        const handle = try storage.runtime_scene.spawnTemporary(
            .{ .authority = .physics_gameplay },
            .{
                .owner = .{ .physics_gameplay = null },
                .local_transform = localTransform(initial_position),
                .enabled = .enabled,
                .resolver = noAssetsResolver(),
            },
        );
        var rollback_authority: ?scene_core.runtime_scene.MutationAuthority = .physics_gameplay;
        errdefer if (rollback_authority) |authority| rollbackCreatedEntity(storage, handle, authority);
        try storage.runtime_scene.promoteTemporary(
            .{ .authority = .physics_gameplay },
            handle,
            entity_id,
        );
        rollback_authority = .world;
        try self.bindExisting(entity_id, handle, character_id);
        rollback_authority = null;
        return handle;
    }

    /// Attaches an already-live persistent root entity. The character runtime
    /// itself stays owned by the specialized composition; only its runtime ID
    /// is retained here, so moving a containing scenario cannot dangle a
    /// pointer.
    pub fn bindExisting(
        self: *CharacterEntityBindings,
        entity_id: foundation.identity.EntityId,
        handle: foundation.identity.EntityHandle,
        character_id: character.EntityId,
    ) !void {
        const storage = storageMutable(self);
        try ensureBindingAvailable(storage, entity_id, character_id, handle);
        var snapshot = try storage.runtime_scene.acquireSnapshot(validationTime());
        defer snapshot.deinit();
        const view = try snapshot.view().get(handle);
        if (view.persistent_id == null or !view.persistent_id.?.eql(entity_id)) return error.PersistentIdentityMismatch;
        if (!isWorldPersistent(view.lifetime)) return error.CharacterEntityMustBeWorldPersistent;
        const root_position = try validateCharacterRoot(view);
        storage.bindings[storage.binding_count] = .{
            .entity_id = entity_id,
            .handle = handle,
            .character_id = character_id,
            .effective_enabled = view.effective_enabled,
            .root_position = root_position,
        };
        storage.binding_count += 1;
        sortBindings(storage.bindings[0..storage.binding_count]);
    }

    pub fn detachCharacter(self: *CharacterEntityBindings, character_id: character.EntityId) !void {
        const storage = storageMutable(self);
        const index = findByCharacter(storage.bindings[0..storage.binding_count], character_id) orelse
            return error.CharacterBindingNotFound;
        removeBinding(storage.bindings[0..], &storage.binding_count, index);
    }

    pub fn destroyForCharacter(self: *CharacterEntityBindings, character_id: character.EntityId) !void {
        const handle = try self.entityForCharacter(character_id);
        try self.destroyEntity(handle);
    }

    pub fn destroyEntity(self: *CharacterEntityBindings, handle: foundation.identity.EntityHandle) !void {
        const storage = storageMutable(self);
        if (findByHandle(storage.bindings[0..storage.binding_count], handle) == null) {
            return error.CharacterBindingNotFound;
        }
        const participants = [_]scene_core.runtime_scene.PublicationParticipant{publicationParticipant(storage)};
        try storage.runtime_scene.destroyEntity(
            .{ .authority = .world, .participants = &participants },
            handle,
            .reject_if_children,
        );
    }

    pub fn entityForCharacter(
        self: *const CharacterEntityBindings,
        character_id: character.EntityId,
    ) !foundation.identity.EntityHandle {
        const storage = storageConst(self);
        const index = findByCharacter(storage.bindings[0..storage.binding_count], character_id) orelse
            return error.CharacterBindingNotFound;
        return storage.bindings[index].handle;
    }

    pub fn persistentIdForCharacter(
        self: *const CharacterEntityBindings,
        character_id: character.EntityId,
    ) !foundation.identity.EntityId {
        const storage = storageConst(self);
        const index = findByCharacter(storage.bindings[0..storage.binding_count], character_id) orelse
            return error.CharacterBindingNotFound;
        return storage.bindings[index].entity_id;
    }

    pub fn characterForEntity(
        self: *const CharacterEntityBindings,
        handle: foundation.identity.EntityHandle,
    ) !character.EntityId {
        if (!handle.isValid()) return error.InvalidHandle;
        const storage = storageConst(self);
        const index = findByHandle(storage.bindings[0..storage.binding_count], handle) orelse
            return error.CharacterBindingNotFound;
        return storage.bindings[index].character_id;
    }

    pub fn resolveCharacter(
        self: *const CharacterEntityBindings,
        handle: foundation.identity.EntityHandle,
        characters: []const *character.CharacterInstance,
    ) !*character.CharacterInstance {
        const character_id = try self.characterForEntity(handle);
        for (characters) |candidate| {
            if (candidate.id() == character_id) return candidate;
        }
        return error.AttachedCharacterUnavailable;
    }

    pub fn isEnabled(
        self: *const CharacterEntityBindings,
        handle: foundation.identity.EntityHandle,
    ) !bool {
        const storage = storageConst(self);
        const index = findByHandle(storage.bindings[0..storage.binding_count], handle) orelse
            return error.CharacterBindingNotFound;
        return storage.bindings[index].effective_enabled;
    }

    pub fn setEnabled(
        self: *CharacterEntityBindings,
        handle: foundation.identity.EntityHandle,
        enabled: bool,
    ) !void {
        const storage = storageMutable(self);
        if (findByHandle(storage.bindings[0..storage.binding_count], handle) == null) {
            return error.CharacterBindingNotFound;
        }
        const participants = [_]scene_core.runtime_scene.PublicationParticipant{publicationParticipant(storage)};
        try storage.runtime_scene.setEnabled(
            .{ .authority = .world, .participants = &participants },
            handle,
            if (enabled) .enabled else .disabled,
        );
    }

    /// World-authority command for a supported unparented 2D character root.
    /// The next simulation boundary pulls this committed F transform into the
    /// specialized controller/runtime.
    pub fn setSceneRoot(
        self: *CharacterEntityBindings,
        handle: foundation.identity.EntityHandle,
        position: math.Vec2,
    ) !void {
        if (!position.isFinite()) return error.InvalidCharacterRoot;
        const storage = storageMutable(self);
        if (findByHandle(storage.bindings[0..storage.binding_count], handle) == null) {
            return error.CharacterBindingNotFound;
        }
        const participants = [_]scene_core.runtime_scene.PublicationParticipant{publicationParticipant(storage)};
        try storage.runtime_scene.setLocalTransform(
            .{ .authority = .world, .participants = &participants },
            handle,
            localTransform(position),
        );
    }

    /// Applies the last committed F root to the specialized runtime before
    /// simulation. Facing remains character-owned and is not encoded in F.
    pub fn applySceneTransform(
        self: *const CharacterEntityBindings,
        instance: *character.CharacterInstance,
    ) !void {
        const storage = storageConst(self);
        const index = findByCharacter(storage.bindings[0..storage.binding_count], instance.id()) orelse
            return error.CharacterBindingNotFound;
        const binding = storage.bindings[index];
        if (!binding.effective_enabled) return error.CharacterEntityDisabled;
        if (instance.worldPosition().approxEqAbs(binding.root_position, root_tolerance)) return;
        if (instance.controllerSnapshot() != null) {
            try instance.stageControlledTransform(binding.root_position, instance.facingDirection());
        } else {
            try instance.setWorldPosition(binding.root_position);
        }
    }

    /// Publishes a changed physics/character root to RuntimeScene after a
    /// simulation frame or fixed-tick batch. Presentation offsets never enter
    /// this transform.
    pub fn publishCharacterTransform(
        self: *CharacterEntityBindings,
        instance: *const character.CharacterInstance,
    ) !bool {
        const storage = storageMutable(self);
        const index = findByCharacter(storage.bindings[0..storage.binding_count], instance.id()) orelse
            return error.CharacterBindingNotFound;
        const binding = storage.bindings[index];
        if (!binding.effective_enabled) return error.CharacterEntityDisabled;
        const position = instance.worldPosition();
        if (!position.isFinite()) return error.InvalidCharacterRoot;
        if (position.approxEqAbs(binding.root_position, root_tolerance)) return false;
        const participants = [_]scene_core.runtime_scene.PublicationParticipant{publicationParticipant(storage)};
        try storage.runtime_scene.setLocalTransform(
            .{ .authority = .physics_gameplay, .participants = &participants },
            binding.handle,
            localTransform(position),
        );
        return true;
    }

    pub fn acquireSnapshot(
        self: *CharacterEntityBindings,
        time: scene_core.runtime_scene.SceneTime,
    ) !scene_core.runtime_scene.SceneSnapshot {
        return storageMutable(self).runtime_scene.acquireSnapshot(time);
    }

    pub fn bindingCount(self: *const CharacterEntityBindings) usize {
        return storageConst(self).binding_count;
    }

    pub fn publicationGeneration(self: *const CharacterEntityBindings) u64 {
        return storageConst(self).publication_generation;
    }
};

fn storageMutable(self: *CharacterEntityBindings) *Storage {
    return @ptrCast(@alignCast(@constCast(self.opaque_context)));
}

fn storageConst(self: *const CharacterEntityBindings) *const Storage {
    return @ptrCast(@alignCast(self.opaque_context));
}

fn ensureBindingAvailable(
    storage: *const Storage,
    entity_id: foundation.identity.EntityId,
    character_id: character.EntityId,
    handle: ?foundation.identity.EntityHandle,
) !void {
    if (!character_id.isValid()) return error.InvalidCharacterId;
    if (storage.binding_count == maximum_bindings) return error.CharacterBindingCapacity;
    for (storage.bindings[0..storage.binding_count]) |binding| {
        if (binding.entity_id.eql(entity_id)) return error.DuplicatePersistentEntityBinding;
        if (binding.character_id == character_id) return error.DuplicateCharacterBinding;
        if (handle) |value| if (binding.handle.eql(value)) return error.DuplicateEntityHandleBinding;
    }
}

fn validateCharacterRoot(view: scene_core.runtime_scene.EntityView) !math.Vec2 {
    if (view.parent != null) return error.CharacterEntityMustBeRoot;
    const local = view.local_transform;
    if (!near(local.translation.z, 0) or
        !near(local.rotation.x, 0) or
        !near(local.rotation.y, 0) or
        !near(local.rotation.z, 0) or
        !near(local.rotation.w, 1) or
        !near(local.scale.x, 1) or
        !near(local.scale.y, 1) or
        !near(local.scale.z, 1))
    {
        return error.UnsupportedCharacterRootTransform;
    }
    if (view.world_transform.origin.x_mm != 0 or
        view.world_transform.origin.y_mm != 0 or
        view.world_transform.origin.z_mm != 0)
    {
        return error.UnsupportedCharacterWorldOrigin;
    }
    const expected = try foundation.spatial.AffineTransform.fromLocal(local);
    if (!foundation.spatial.approximatelyEqual(expected, view.world_transform.affine)) {
        return error.UnsupportedCharacterRootTransform;
    }
    return .{ .x = local.translation.x, .y = local.translation.y };
}

fn isWorldPersistent(lifetime: scene_core.runtime_scene.Lifetime) bool {
    return switch (lifetime) {
        .world_persistent => true,
        else => false,
    };
}

fn localTransform(position: math.Vec2) foundation.spatial.LocalTransform {
    return .{
        .translation = .{ .x = position.x, .y = position.y, .z = 0 },
        .rotation = .identity,
        .scale = .one,
    };
}

fn near(left: f32, right: f32) bool {
    return @abs(left - right) <= root_tolerance;
}

fn findByCharacter(bindings: []const Binding, character_id: character.EntityId) ?usize {
    for (bindings, 0..) |binding, index| {
        if (binding.character_id == character_id) return index;
    }
    return null;
}

fn findByHandle(bindings: []const Binding, handle: foundation.identity.EntityHandle) ?usize {
    for (bindings, 0..) |binding, index| {
        if (binding.handle.eql(handle)) return index;
    }
    return null;
}

fn removeBinding(bindings: []Binding, count: *usize, index: usize) void {
    if (index + 1 < count.*) {
        std.mem.copyForwards(Binding, bindings[index .. count.* - 1], bindings[index + 1 .. count.*]);
    }
    count.* -= 1;
}

fn sortBindings(bindings: []Binding) void {
    var index: usize = 1;
    while (index < bindings.len) : (index += 1) {
        const value = bindings[index];
        var insertion = index;
        while (insertion > 0 and bindingLess(value, bindings[insertion - 1])) : (insertion -= 1) {
            bindings[insertion] = bindings[insertion - 1];
        }
        bindings[insertion] = value;
    }
}

fn bindingLess(left: Binding, right: Binding) bool {
    return switch (left.entity_id.byteOrder(right.entity_id)) {
        .lt => true,
        .gt => false,
        .eq => if (left.handle.slot != right.handle.slot)
            left.handle.slot < right.handle.slot
        else
            left.handle.generation < right.handle.generation,
    };
}

fn publicationParticipant(storage: *Storage) scene_core.runtime_scene.PublicationParticipant {
    return .{
        .context = storage,
        .prepare_fn = preparePublication,
        .commit_fn = commitPublication,
        .rollback_fn = rollbackPublication,
    };
}

fn preparePublication(context: ?*anyopaque, candidate: scene_core.runtime_scene.SceneReadView) anyerror!void {
    const storage: *Storage = @ptrCast(@alignCast(context.?));
    storage.pending_count = 0;
    storage.pending_ready = false;
    for (storage.bindings[0..storage.binding_count]) |binding| {
        const view = candidate.get(binding.handle) catch |err| switch (scene_core.runtime_scene.classifyError(err)) {
            .stale_handle, .entity_not_found => continue,
            else => return err,
        };
        if (view.persistent_id == null or !view.persistent_id.?.eql(binding.entity_id)) {
            return error.PersistentIdentityMismatch;
        }
        storage.pending_bindings[storage.pending_count] = .{
            .entity_id = binding.entity_id,
            .handle = binding.handle,
            .character_id = binding.character_id,
            .effective_enabled = view.effective_enabled,
            .root_position = try validateCharacterRoot(view),
        };
        storage.pending_count += 1;
    }
    storage.pending_ready = true;
}

fn commitPublication(context: ?*anyopaque, generation: u64) void {
    const storage: *Storage = @ptrCast(@alignCast(context.?));
    std.debug.assert(storage.pending_ready);
    for (storage.pending_bindings[0..storage.pending_count], 0..) |binding, index| {
        storage.bindings[index] = binding;
    }
    storage.binding_count = storage.pending_count;
    storage.pending_count = 0;
    storage.pending_ready = false;
    storage.publication_generation = generation;
}

fn rollbackPublication(context: ?*anyopaque) void {
    const storage: *Storage = @ptrCast(@alignCast(context.?));
    storage.pending_count = 0;
    storage.pending_ready = false;
}

fn noAssetsResolver() scene_core.runtime_asset.Resolver {
    return .{ .context = null, .resolve_fn = rejectAssetResolution };
}

fn rejectAssetResolution(_: ?*anyopaque, _: foundation.reference.AssetRef) anyerror!scene_core.runtime_asset.ResolvedAssetToken {
    return error.UnexpectedCharacterAssetDependency;
}

fn validationTime() scene_core.runtime_scene.SceneTime {
    return .{ .tick = 0, .fixed_delta_seconds = 1.0 / 120.0, .interpolation_alpha = 0 };
}

fn rollbackCreatedEntity(
    storage: *Storage,
    handle: foundation.identity.EntityHandle,
    authority: scene_core.runtime_scene.MutationAuthority,
) void {
    storage.runtime_scene.destroyEntity(
        .{ .authority = authority },
        handle,
        .reject_if_children,
    ) catch |err| {
        std.debug.panic("character/F creation rollback failed: {s}", .{@errorName(err)});
    };
}
