const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const sprite = @import("sprite_batch");

pub const persistent_entity_text = "0195d5b8-4000-7000-8000-000000000001";
pub const initial_position = [2]f32{ -0.75, 0.0 };
pub const moved_position = [2]f32{ 0.75, 0.25 };

pub const Observation = struct {
    entity_id: foundation.identity.EntityId,
    handle: foundation.identity.EntityHandle,
    lifetime: scene_core.runtime_scene.Lifetime,
    effective_enabled: bool,
    local_transform: foundation.spatial.LocalTransform,
    world_transform: scene_core.runtime_scene.WorldTransform,
    publication_generation: u64,
};

/// A deliberately small second application composition. It owns one generic
/// RuntimeScene entity and converts only the supported read view into a
/// production sprite request; it has no access to scene-core internals.
pub const Client = struct {
    scene: scene_core.runtime_scene.RuntimeScene,
    entity_id: foundation.identity.EntityId,
    entity_handle: foundation.identity.EntityHandle,

    pub fn init(allocator: std.mem.Allocator) !Client {
        var scene = try scene_core.runtime_scene.RuntimeScene.init(allocator, .{
            .registry = .{
                .initial_entity_capacity = 4,
                .hard_entity_capacity = 4,
                .initial_mapping_capacity = 4,
                .hard_mapping_capacity = 4,
            },
            .initial_level_capacity = 1,
            .hard_level_capacity = 1,
            .max_snapshot_leases = 2,
        });
        errdefer scene.deinit() catch {};

        const entity_id = try foundation.identity.EntityId.parseCanonical(
            persistent_entity_text,
        );
        const handle = try scene.spawnTemporary(
            .{ .authority = .physics_gameplay },
            .{
                .owner = .{ .physics_gameplay = null },
                .local_transform = transformAt(initial_position),
                .enabled = .enabled,
                .resolver = noAssetsResolver(),
            },
        );
        try scene.promoteTemporary(
            .{ .authority = .physics_gameplay },
            handle,
            entity_id,
        );
        return .{
            .scene = scene,
            .entity_id = entity_id,
            .entity_handle = handle,
        };
    }

    pub fn deinit(client: *Client) !void {
        try client.scene.deinit();
        client.* = undefined;
    }

    pub fn setPosition(client: *Client, position: [2]f32) !void {
        try client.scene.setLocalTransform(
            .{ .authority = .world },
            client.entity_handle,
            transformAt(position),
        );
    }

    pub fn observe(client: *Client, tick: u64) !Observation {
        var snapshot = try client.scene.acquireSnapshot(.{
            .tick = tick,
            .fixed_delta_seconds = 1.0 / 240.0,
            .interpolation_alpha = 0,
        });
        defer snapshot.deinit();
        const read = snapshot.view();
        const view = try read.get(client.entity_handle);
        const resolved = read.resolve(client.entity_id) orelse
            return error.PersistentEntityNotResolved;
        if (!resolved.eql(client.entity_handle)) return error.PersistentHandleMismatch;
        if (view.persistent_id == null or !view.persistent_id.?.eql(client.entity_id)) {
            return error.PersistentIdentityMismatch;
        }
        return .{
            .entity_id = view.persistent_id.?,
            .handle = view.handle,
            .lifetime = view.lifetime,
            .effective_enabled = view.effective_enabled,
            .local_transform = view.local_transform,
            .world_transform = view.world_transform,
            .publication_generation = read.publication_generation,
        };
    }

    pub fn renderRequest(_: *const Client, observation: Observation) !sprite.SpriteRequest {
        if (!observation.effective_enabled) return error.EntityNotRenderable;
        switch (observation.lifetime) {
            .world_persistent => {},
            else => return error.EntityNotWorldPersistent,
        }
        const affine = observation.world_transform.affine;
        try affine.validate();
        const scale_x = affine.x_axis.length();
        const scale_y = affine.y_axis.length();
        if (!std.math.isFinite(scale_x) or !std.math.isFinite(scale_y)) {
            return error.InvalidRenderTransform;
        }
        return .{
            .world_position = .{ affine.translation.x, affine.translation.y },
            .rotation = std.math.atan2(affine.x_axis.y, affine.x_axis.x),
            .scale = .{ 1.5 * scale_x, 1.5 * scale_y },
            .pivot = .{ 0.5, 0.5 },
            .uv_rect = .{ 0, 0, 1, 1 },
            .tint = .{ 1, 1, 1, 1 },
            .texture_page = 0,
            .order = .{
                .scene_layer = 0,
                .interaction_layer = 0,
                .actor_layer = 0,
                .body_part_layer = 0,
            },
        };
    }
};

fn transformAt(position: [2]f32) foundation.spatial.LocalTransform {
    return .{
        .translation = .{ .x = position[0], .y = position[1], .z = 0 },
        .rotation = .identity,
        .scale = .one,
    };
}

fn noAssetsResolver() scene_core.runtime_asset.Resolver {
    return .{ .context = null, .resolve_fn = rejectAssetResolution };
}

fn rejectAssetResolution(
    _: ?*anyopaque,
    _: foundation.reference.AssetRef,
) anyerror!scene_core.runtime_asset.ResolvedAssetToken {
    return error.UnexpectedEngineSmokeAssetDependency;
}
