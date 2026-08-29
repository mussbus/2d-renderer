const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const support = @import("support.zig");

const RuntimeScene = scene_core.runtime_scene.RuntimeScene;
const SceneTime = scene_core.runtime_scene.SceneTime;

const MockResolver = struct {
    allowed: []const foundation.reference.AssetRef,

    fn resolve(context: ?*anyopaque, reference: foundation.reference.AssetRef) anyerror!scene_core.runtime_asset.ResolvedAssetToken {
        const self: *MockResolver = @ptrCast(@alignCast(context.?));
        for (self.allowed, 0..) |allowed, index| {
            if (allowed.eql(reference)) return scene_core.runtime_asset.ResolvedAssetToken.init(@intCast(index + 1));
        }
        return error.MissingExactAsset;
    }

    fn interface(self: *MockResolver) scene_core.runtime_asset.Resolver {
        return .{ .context = self, .resolve_fn = resolve };
    }
};

fn makeScene() !RuntimeScene {
    return RuntimeScene.init(std.testing.allocator, .{
        .registry = .{
            .initial_entity_capacity = 1,
            .hard_entity_capacity = 64,
            .initial_mapping_capacity = 1,
            .hard_mapping_capacity = 64,
        },
        .initial_level_capacity = 1,
        .hard_level_capacity = 4,
        .max_snapshot_leases = 4,
    });
}

fn closeScene(scene: *RuntimeScene) void {
    scene.deinit() catch |deinit_error| std.debug.panic("runtime scene deinit failed: {s}", .{@errorName(deinit_error)});
}

fn time(tick: u64) SceneTime {
    return .{ .tick = tick, .fixed_delta_seconds = 1.0 / 60.0, .interpolation_alpha = 0.25 };
}

fn levelFixture(
    id_text: []const u8,
    origin: scene_core.level.WorldCoordinateOrigin,
    entities: []const scene_core.entity.EntityInstanceDefinition,
) !scene_core.level.LevelDefinition {
    return .{
        .header = try support.header(scene_core.asset.level_kind, scene_core.asset.level_schema_id, id_text),
        .origin = origin,
        .entities = entities,
    };
}

fn levelRef(id_text: []const u8, hash_byte: u8) !foundation.reference.AssetRef {
    return support.assetRef(id_text, "f.level", hash_byte);
}

fn transform(x: f32, y: f32, z: f32) foundation.spatial.LocalTransform {
    return .{
        .translation = .{ .x = x, .y = y, .z = z },
        .rotation = .identity,
        .scale = .one,
    };
}

fn expectTranslation(expected: foundation.spatial.Vec3, actual: foundation.spatial.Vec3) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, 1.0e-5);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, 1.0e-5);
    try std.testing.expectApproxEqAbs(expected.z, actual.z, 1.0e-5);
}

fn expectWorldTransformEquivalent(
    expected: scene_core.runtime_scene.WorldTransform,
    actual: scene_core.runtime_scene.WorldTransform,
) !void {
    try std.testing.expectEqual(expected.origin, actual.origin);
    try std.testing.expect(foundation.spatial.approximatelyEqual(expected.affine, actual.affine));
}

test "Level assembly resolves deterministic hierarchy and preserves exact large origin" {
    const level_id_text = "11111111-1111-5111-8111-111111111111";
    const root_id = try support.entityId("21111111-1111-5111-8111-111111111111");
    const child_id = try support.entityId("31111111-1111-5111-8111-111111111111");
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{
        .{
            .entity_id = child_id,
            .local_transform = transform(2.0, 0.0, 0.0),
            .parent = .{ .entity_id = root_id, .requirement = .required },
            .enabled = .enabled,
        },
        .{
            .entity_id = root_id,
            .local_transform = transform(10.0, 1.0, -2.0),
            .enabled = .disabled,
        },
    };
    const exact_origin = scene_core.level.WorldCoordinateOrigin{
        .x_mm = 8_000_000_000_000_123,
        .y_mm = -7_000_000_000_000_456,
        .z_mm = 6_000_000_000_000_789,
    };
    const definition = try levelFixture(level_id_text, exact_origin, &definitions);
    const source = try levelRef(level_id_text, 0x11);
    var resolver = MockResolver{ .allowed = &.{source} };
    var scene = try makeScene();
    defer closeScene(&scene);

    try scene.activateLevel(
        .{ .authority = .world },
        .{ .source = source, .definition = &definition, .resolver = resolver.interface() },
    );
    var snapshot = try scene.acquireSnapshot(time(10));
    defer snapshot.deinit();
    const view = snapshot.view();
    try std.testing.expectEqual(@as(u64, 1), view.publication_generation);
    try std.testing.expectEqual(@as(usize, 2), view.entityCount());
    try std.testing.expectEqual(@as(usize, 1), view.levelCount());
    try std.testing.expectEqual(exact_origin, view.levelAt(0).?.origin);
    const root_handle = view.resolve(root_id).?;
    const child_handle = view.resolve(child_id).?;
    const root = try view.get(root_handle);
    const child = try view.get(child_handle);
    try std.testing.expectEqual(root_handle, child.parent.?);
    try std.testing.expectEqual(child_handle, root.childAt(0).?);
    try std.testing.expectEqual(exact_origin, child.world_transform.origin);
    try expectTranslation(.{ .x = 12.0, .y = 1.0, .z = -2.0 }, child.world_transform.affine.translation);
    try std.testing.expect(!root.effective_enabled);
    try std.testing.expect(!child.effective_enabled);
    var lifecycle_scratch: [2]foundation.identity.EntityHandle = undefined;
    const enabling = try view.lifecycleOrder(true, &lifecycle_scratch);
    try std.testing.expectEqual(root_handle, enabling[0]);
    try std.testing.expectEqual(child_handle, enabling[1]);
    const disabling = try view.lifecycleOrder(false, &lifecycle_scratch);
    try std.testing.expectEqual(child_handle, disabling[0]);
    try std.testing.expectEqual(root_handle, disabling[1]);
    try scene.setEnabled(.{ .authority = .world }, root_handle, .enabled);
    var enabled_snapshot = try scene.acquireSnapshot(time(11));
    defer enabled_snapshot.deinit();
    try std.testing.expect((try enabled_snapshot.view().get(root_handle)).effective_enabled);
    try std.testing.expect((try enabled_snapshot.view().get(child_handle)).effective_enabled);
}

test "failed exact source resolution is atomic and a later valid activation succeeds" {
    const level_id_text = "41111111-1111-5111-8111-111111111111";
    const entity_id = try support.entityId("51111111-1111-5111-8111-111111111111");
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{.{ .entity_id = entity_id }};
    const definition = try levelFixture(level_id_text, .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, &definitions);
    const source = try levelRef(level_id_text, 0x41);
    var missing = MockResolver{ .allowed = &.{} };
    var scene = try makeScene();
    defer closeScene(&scene);

    try std.testing.expectError(
        error.AssetResolutionFailed,
        scene.activateLevel(.{ .authority = .world }, .{
            .source = source,
            .definition = &definition,
            .resolver = missing.interface(),
        }),
    );
    var empty = try scene.acquireSnapshot(time(0));
    try std.testing.expectEqual(@as(usize, 0), empty.view().entityCount());
    try std.testing.expectEqual(@as(u64, 0), empty.view().publication_generation);
    empty.deinit();

    var present = MockResolver{ .allowed = &.{source} };
    try scene.activateLevel(.{ .authority = .world }, .{
        .source = source,
        .definition = &definition,
        .resolver = present.interface(),
    });
    var published = try scene.acquireSnapshot(time(1));
    defer published.deinit();
    try std.testing.expect(published.view().resolve(entity_id) != null);
    try std.testing.expectEqual(@as(u64, 1), published.view().publication_generation);
}

test "dirty propagation updates only affected branches and old snapshots remain immutable" {
    const level_id_text = "61111111-1111-5111-8111-111111111111";
    const root_id = try support.entityId("71111111-1111-5111-8111-111111111111");
    const child_id = try support.entityId("81111111-1111-5111-8111-111111111111");
    const grandchild_id = try support.entityId("91111111-1111-5111-8111-111111111111");
    const sibling_id = try support.entityId("a1111111-1111-5111-8111-111111111111");
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = root_id, .local_transform = transform(1.0, 0.0, 0.0) },
        .{ .entity_id = child_id, .local_transform = transform(2.0, 0.0, 0.0), .parent = .{ .entity_id = root_id, .requirement = .required } },
        .{ .entity_id = grandchild_id, .local_transform = transform(3.0, 0.0, 0.0), .parent = .{ .entity_id = child_id, .requirement = .required } },
        .{ .entity_id = sibling_id, .local_transform = transform(4.0, 0.0, 0.0), .parent = .{ .entity_id = root_id, .requirement = .required } },
    };
    const definition = try levelFixture(level_id_text, .{ .x_mm = 1000, .y_mm = 0, .z_mm = 0 }, &definitions);
    const source = try levelRef(level_id_text, 0x61);
    var resolver = MockResolver{ .allowed = &.{source} };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{ .source = source, .definition = &definition, .resolver = resolver.interface() });

    var before = try scene.acquireSnapshot(time(1));
    defer before.deinit();
    const before_view = before.view();
    const root_handle = before_view.resolve(root_id).?;
    const child_handle = before_view.resolve(child_id).?;
    const grandchild_handle = before_view.resolve(grandchild_id).?;
    const sibling_handle = before_view.resolve(sibling_id).?;
    try scene.setLocalTransform(.{ .authority = .world }, child_handle, transform(5.0, 0.0, 0.0));

    var after_child = try scene.acquireSnapshot(time(2));
    defer after_child.deinit();
    try expectTranslation(.{ .x = 3.0, .y = 0.0, .z = 0.0 }, (try before_view.get(child_handle)).world_transform.affine.translation);
    const after_child_view = after_child.view();
    try expectTranslation(.{ .x = 6.0, .y = 0.0, .z = 0.0 }, (try after_child_view.get(child_handle)).world_transform.affine.translation);
    try expectTranslation(.{ .x = 9.0, .y = 0.0, .z = 0.0 }, (try after_child_view.get(grandchild_handle)).world_transform.affine.translation);
    try std.testing.expectEqual(@as(u64, 1), (try after_child_view.get(root_handle)).recomputation_count);
    try std.testing.expectEqual(@as(u64, 2), (try after_child_view.get(child_handle)).recomputation_count);
    try std.testing.expectEqual(@as(u64, 2), (try after_child_view.get(grandchild_handle)).recomputation_count);
    try std.testing.expectEqual(@as(u64, 1), (try after_child_view.get(sibling_handle)).recomputation_count);
    const repeated_count = (try after_child_view.get(child_handle)).recomputation_count;
    try std.testing.expectEqual(repeated_count, (try after_child_view.get(child_handle)).recomputation_count);

    try scene.setLocalTransform(.{ .authority = .world }, root_handle, transform(10.0, 0.0, 0.0));
    var after_root = try scene.acquireSnapshot(time(3));
    defer after_root.deinit();
    const after_root_view = after_root.view();
    try std.testing.expectEqual(@as(u64, 2), (try after_root_view.get(root_handle)).recomputation_count);
    try std.testing.expectEqual(@as(u64, 3), (try after_root_view.get(child_handle)).recomputation_count);
    try std.testing.expectEqual(@as(u64, 3), (try after_root_view.get(grandchild_handle)).recomputation_count);
    try std.testing.expectEqual(@as(u64, 2), (try after_root_view.get(sibling_handle)).recomputation_count);
}

test "reparent modes preserve the requested space and reject cycles transactionally" {
    const level_id_text = "b1111111-1111-5111-8111-111111111111";
    const a_id = try support.entityId("c1111111-1111-5111-8111-111111111111");
    const b_id = try support.entityId("d1111111-1111-5111-8111-111111111111");
    const child_id = try support.entityId("e1111111-1111-5111-8111-111111111111");
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = a_id, .local_transform = transform(10.0, 0.0, 0.0) },
        .{ .entity_id = b_id, .local_transform = transform(20.0, 0.0, 0.0) },
        .{ .entity_id = child_id, .local_transform = transform(2.0, 0.0, 0.0), .parent = .{ .entity_id = a_id, .requirement = .required } },
    };
    const definition = try levelFixture(level_id_text, .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, &definitions);
    const source = try levelRef(level_id_text, 0xb1);
    var resolver = MockResolver{ .allowed = &.{source} };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{ .source = source, .definition = &definition, .resolver = resolver.interface() });
    var initial = try scene.acquireSnapshot(time(1));
    const a = initial.view().resolve(a_id).?;
    const b = initial.view().resolve(b_id).?;
    const child = initial.view().resolve(child_id).?;
    initial.deinit();

    try scene.setParent(.{ .authority = .world }, child, b, .keep_world);
    var kept_world = try scene.acquireSnapshot(time(2));
    try expectTranslation(.{ .x = 12.0, .y = 0.0, .z = 0.0 }, (try kept_world.view().get(child)).world_transform.affine.translation);
    try expectTranslation(.{ .x = -8.0, .y = 0.0, .z = 0.0 }, (try kept_world.view().get(child)).local_transform.translation);
    kept_world.deinit();

    try scene.setParent(.{ .authority = .world }, child, a, .keep_local);
    var kept_local = try scene.acquireSnapshot(time(3));
    try expectTranslation(.{ .x = 2.0, .y = 0.0, .z = 0.0 }, (try kept_local.view().get(child)).world_transform.affine.translation);
    const generation_before_failure = kept_local.view().publication_generation;
    kept_local.deinit();
    try std.testing.expectError(error.RuntimeParentCycle, scene.setParent(.{ .authority = .world }, a, child, .keep_local));
    var unchanged = try scene.acquireSnapshot(time(4));
    defer unchanged.deinit();
    try std.testing.expectEqual(generation_before_failure, unchanged.view().publication_generation);
    try std.testing.expect((try unchanged.view().get(a)).parent == null);
}

test "world affine preserves negative scale and hierarchy-generated shear" {
    const level_id_text = "f1111111-1111-5111-8111-111111111111";
    const parent_id = try support.entityId("12111111-1111-5111-8111-111111111111");
    const child_id = try support.entityId("13111111-1111-5111-8111-111111111111");
    const negative_id = try support.entityId("14111111-1111-5111-8111-111111111111");
    const z_axis = try foundation.spatial.Vec3.init(0.0, 0.0, 1.0);
    const rotation = try foundation.spatial.Quaternion.fromAxisAngle(z_axis, std.math.pi / 4.0);
    const parent_transform = try foundation.spatial.LocalTransform.init(.zero, rotation, try foundation.spatial.Vec3.init(2.0, 1.0, 1.0));
    const child_transform = try foundation.spatial.LocalTransform.init(.zero, rotation, .one);
    const negative_transform = try foundation.spatial.LocalTransform.init(.zero, .identity, try foundation.spatial.Vec3.init(-2.0, 1.0, 1.0));
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = parent_id, .local_transform = parent_transform },
        .{ .entity_id = child_id, .local_transform = child_transform, .parent = .{ .entity_id = parent_id, .requirement = .required } },
        .{ .entity_id = negative_id, .local_transform = negative_transform },
    };
    const definition = try levelFixture(level_id_text, .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, &definitions);
    const source = try levelRef(level_id_text, 0xf1);
    var resolver = MockResolver{ .allowed = &.{source} };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{ .source = source, .definition = &definition, .resolver = resolver.interface() });
    var snapshot = try scene.acquireSnapshot(time(1));
    defer snapshot.deinit();
    const child = try snapshot.view().get(snapshot.view().resolve(child_id).?);
    const expected = try foundation.spatial.AffineTransform.compose(
        try foundation.spatial.AffineTransform.fromLocal(parent_transform),
        try foundation.spatial.AffineTransform.fromLocal(child_transform),
    );
    try std.testing.expect(foundation.spatial.approximatelyEqual(expected, child.world_transform.affine));
    try std.testing.expectError(error.NonRepresentableAffine, child.world_transform.affine.toLocal());
    const negative = try snapshot.view().get(snapshot.view().resolve(negative_id).?);
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), negative.world_transform.affine.x_axis.x, 1.0e-5);
}

test "removal policies reject children by default and orphan or cascade explicitly" {
    const level_id_text = "15111111-1111-5111-8111-111111111111";
    const parent_id = try support.entityId("16111111-1111-5111-8111-111111111111");
    const child_id = try support.entityId("17111111-1111-5111-8111-111111111111");
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = parent_id, .local_transform = transform(5.0, 0.0, 0.0) },
        .{ .entity_id = child_id, .local_transform = transform(2.0, 0.0, 0.0), .parent = .{ .entity_id = parent_id, .requirement = .required } },
    };
    const definition = try levelFixture(level_id_text, .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, &definitions);
    const source = try levelRef(level_id_text, 0x15);
    var resolver = MockResolver{ .allowed = &.{source} };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{ .source = source, .definition = &definition, .resolver = resolver.interface() });
    var before = try scene.acquireSnapshot(time(1));
    const parent = before.view().resolve(parent_id).?;
    const child = before.view().resolve(child_id).?;
    before.deinit();
    try std.testing.expectError(error.EntityHasChildren, scene.destroyEntity(.{ .authority = .world }, parent, .reject_if_children));
    try scene.destroyEntity(.{ .authority = .world }, parent, .orphan_keep_world);
    var orphaned = try scene.acquireSnapshot(time(2));
    try std.testing.expectError(error.StaleHandle, orphaned.view().get(parent));
    const child_view = try orphaned.view().get(child);
    try std.testing.expect(child_view.parent == null);
    try expectTranslation(.{ .x = 7.0, .y = 0.0, .z = 0.0 }, child_view.world_transform.affine.translation);
    orphaned.deinit();
    try scene.destroyEntity(.{ .authority = .world }, child, .cascade);
    var empty = try scene.acquireSnapshot(time(3));
    defer empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty.view().entityCount());
    try std.testing.expectError(error.StaleHandle, empty.view().get(child));
}

test "multiple Levels coexist and unload invalidates only owned and host-scoped entities" {
    const level_a_text = "18111111-1111-5111-8111-111111111111";
    const level_b_text = "19111111-1111-5111-8111-111111111111";
    const entity_a_id = try support.entityId("1a111111-1111-5111-8111-111111111111");
    const entity_b_id = try support.entityId("1b111111-1111-5111-8111-111111111111");
    const entities_a = [_]scene_core.entity.EntityInstanceDefinition{.{ .entity_id = entity_a_id }};
    const entities_b = [_]scene_core.entity.EntityInstanceDefinition{.{ .entity_id = entity_b_id, .local_transform = transform(20.0, 0.0, 0.0) }};
    const level_a = try levelFixture(level_a_text, .{ .x_mm = 1000, .y_mm = 0, .z_mm = 0 }, &entities_a);
    const level_b = try levelFixture(level_b_text, .{ .x_mm = 2000, .y_mm = 0, .z_mm = 0 }, &entities_b);
    const source_a = try levelRef(level_a_text, 0x18);
    const source_b = try levelRef(level_b_text, 0x19);
    var resolver = MockResolver{ .allowed = &.{ source_a, source_b } };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{ .source = source_a, .definition = &level_a, .resolver = resolver.interface() });
    try scene.activateLevel(.{ .authority = .world }, .{ .source = source_b, .definition = &level_b, .resolver = resolver.interface() });
    try std.testing.expectError(error.LevelAlreadyActive, scene.activateLevel(.{ .authority = .world }, .{ .source = source_a, .definition = &level_a, .resolver = resolver.interface() }));

    var active = try scene.acquireSnapshot(time(2));
    const handle_a = active.view().resolve(entity_a_id).?;
    const handle_b = active.view().resolve(entity_b_id).?;
    active.deinit();
    try std.testing.expectError(error.CrossLevelParent, scene.setParent(.{ .authority = .world }, handle_a, handle_b, .keep_local));
    const external_temporary = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
        .owner = .{ .physics_gameplay = null },
        .parent = handle_a,
        .resolver = resolver.interface(),
    });
    try std.testing.expectError(error.LevelHasExternalDependents, scene.deactivateLevel(.{ .authority = .world }, source_a.revision.asset_id));
    var still_active = try scene.acquireSnapshot(time(21));
    try std.testing.expect(still_active.view().resolve(entity_a_id) != null);
    still_active.deinit();
    try scene.destroyEntity(.{ .authority = .physics_gameplay }, external_temporary, .reject_if_children);
    const temporary = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
        .owner = .{ .physics_gameplay = source_a.revision.asset_id },
        .parent = handle_a,
        .local_transform = transform(1.0, 0.0, 0.0),
        .resolver = resolver.interface(),
    });
    try std.testing.expectError(error.UnauthorizedMutation, scene.spawnTemporary(.{ .authority = .editor }, .{
        .owner = .{ .physics_gameplay = source_a.revision.asset_id },
        .resolver = resolver.interface(),
    }));

    try scene.deactivateLevel(.{ .authority = .world }, source_a.revision.asset_id);
    var after = try scene.acquireSnapshot(time(3));
    defer after.deinit();
    try std.testing.expectEqual(@as(usize, 1), after.view().levelCount());
    try std.testing.expect(after.view().resolve(entity_a_id) == null);
    try std.testing.expectError(error.StaleHandle, after.view().get(handle_a));
    try std.testing.expectError(error.StaleHandle, after.view().get(temporary));
    try std.testing.expectEqual(entity_b_id, (try after.view().get(handle_b)).persistent_id.?);
    try std.testing.expectError(error.LevelNotActive, scene.deactivateLevel(.{ .authority = .world }, source_a.revision.asset_id));
}

test "Level-hosted gameplay promotion rejects atomically before changing spatial basis" {
    const level_id_text = "1a111111-1111-5111-8111-111111111111";
    const proposed_id = try support.entityId("1a111111-1111-5111-8111-111111111112");
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{};
    const exact_origin = scene_core.level.WorldCoordinateOrigin{
        .x_mm = 4_000_000_000_000,
        .y_mm = -3_000_000_000_000,
        .z_mm = 2_000_000_000_000,
    };
    const level_definition = try levelFixture(level_id_text, exact_origin, &definitions);
    const level_source = try levelRef(level_id_text, 0x1a);
    var resolver = MockResolver{ .allowed = &.{level_source} };
    var scene = try makeScene();
    defer closeScene(&scene);

    try scene.activateLevel(.{ .authority = .world }, .{
        .source = level_source,
        .definition = &level_definition,
        .resolver = resolver.interface(),
    });
    const local = transform(5.0, -2.0, 1.0);
    const handle = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
        .owner = .{ .physics_gameplay = level_source.revision.asset_id },
        .local_transform = local,
        .resolver = resolver.interface(),
    });
    var before = try scene.acquireSnapshot(time(1));
    const before_view = before.view();
    const before_entity = try before_view.get(handle);
    const world_before = before_entity.world_transform;
    const generation_before = before_view.publication_generation;
    try std.testing.expectEqual(exact_origin, world_before.origin);
    try std.testing.expectEqual(local, before_entity.local_transform);
    try std.testing.expect(before_entity.persistent_id == null);
    try std.testing.expect(before_entity.parent == null);
    before.deinit();

    try std.testing.expectError(
        error.PromotionRequiresWorldRebase,
        scene.promoteTemporary(.{ .authority = .physics_gameplay }, handle, proposed_id),
    );
    try std.testing.expectEqual(
        scene_core.runtime_scene.RuntimeErrorCode.promotion_requires_world_rebase,
        scene_core.runtime_scene.classifyError(error.PromotionRequiresWorldRebase),
    );
    try std.testing.expectEqual(
        foundation.diagnostics.Code.invalid_spatial_value,
        scene_core.runtime_scene.foundationDiagnosticCode(.promotion_requires_world_rebase),
    );

    var after = try scene.acquireSnapshot(time(2));
    defer after.deinit();
    const after_view = after.view();
    const unchanged = try after_view.get(handle);
    try std.testing.expectEqual(generation_before, after_view.publication_generation);
    try std.testing.expect(after_view.resolve(proposed_id) == null);
    try std.testing.expect(unchanged.persistent_id == null);
    try std.testing.expectEqual(local, unchanged.local_transform);
    try expectWorldTransformEquivalent(world_before, unchanged.world_transform);
    try std.testing.expect(unchanged.parent == null);
    try std.testing.expectEqual(level_source.revision.asset_id, unchanged.lifetime.owningLevel().?);
}

test "supported gameplay promotion preserves hierarchy local transform and world affine" {
    const level_id_text = "1b111111-1111-5111-8111-111111111120";
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{};
    const level_definition = try levelFixture(
        level_id_text,
        .{ .x_mm = 6_000_000_000_000, .y_mm = 0, .z_mm = 0 },
        &definitions,
    );
    const level_source = try levelRef(level_id_text, 0x1d);
    var resolver = MockResolver{ .allowed = &.{level_source} };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{
        .source = level_source,
        .definition = &level_definition,
        .resolver = resolver.interface(),
    });
    const local = transform(2.0, -3.0, 4.0);
    const handle = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
        .owner = .{ .physics_gameplay = null },
        .local_transform = local,
        .resolver = resolver.interface(),
    });
    var temporary = try scene.acquireSnapshot(time(1));
    const temporary_entity = try temporary.view().get(handle);
    const world_before = temporary_entity.world_transform;
    const parent_before = temporary_entity.parent;
    const child_count_before = temporary_entity.childCount();
    try std.testing.expect(temporary_entity.persistent_id == null);
    temporary.deinit();
    const persistent_id = try support.entityId("1b111111-1111-5111-8111-111111111112");
    try scene.promoteTemporary(.{ .authority = .physics_gameplay }, handle, persistent_id);
    var promoted = try scene.acquireSnapshot(time(2));
    const promoted_entity = try promoted.view().get(handle);
    try std.testing.expectEqual(handle, promoted.view().resolve(persistent_id).?);
    try std.testing.expect(promoted_entity.lifetime.isPersistentWorld());
    try std.testing.expectEqual(local, promoted_entity.local_transform);
    try expectWorldTransformEquivalent(world_before, promoted_entity.world_transform);
    try std.testing.expectEqual(parent_before, promoted_entity.parent);
    try std.testing.expectEqual(child_count_before, promoted_entity.childCount());
    promoted.deinit();

    const anchored_id = try support.entityId("1b111111-1111-5111-8111-111111111121");
    const anchored_local = transform(-4.0, 5.0, 6.0);
    const anchored = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
        .owner = .{ .physics_gameplay = level_source.revision.asset_id },
        .parent = handle,
        .local_transform = anchored_local,
        .resolver = resolver.interface(),
    });
    var anchored_before = try scene.acquireSnapshot(time(3));
    const anchored_before_entity = try anchored_before.view().get(anchored);
    const anchored_world_before = anchored_before_entity.world_transform;
    try std.testing.expectEqual(scene_core.level.WorldCoordinateOrigin{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, anchored_world_before.origin);
    anchored_before.deinit();
    try scene.promoteTemporary(.{ .authority = .physics_gameplay }, anchored, anchored_id);
    var anchored_after = try scene.acquireSnapshot(time(4));
    const anchored_after_entity = try anchored_after.view().get(anchored);
    try std.testing.expectEqual(anchored, anchored_after.view().resolve(anchored_id).?);
    try std.testing.expect(anchored_after_entity.lifetime.isPersistentWorld());
    try std.testing.expectEqual(handle, anchored_after_entity.parent.?);
    try std.testing.expectEqual(anchored_local, anchored_after_entity.local_transform);
    try expectWorldTransformEquivalent(anchored_world_before, anchored_after_entity.world_transform);
    anchored_after.deinit();

    const second = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
        .owner = .{ .physics_gameplay = null },
        .resolver = resolver.interface(),
    });
    try std.testing.expectError(error.DuplicateActiveEntityId, scene.promoteTemporary(.{ .authority = .physics_gameplay }, second, persistent_id));
    var unchanged = try scene.acquireSnapshot(time(3));
    try std.testing.expect((try unchanged.view().get(second)).persistent_id == null);
    unchanged.deinit();
    try scene.destroyEntity(.{ .authority = .physics_gameplay }, second, .reject_if_children);
    try scene.destroyEntity(.{ .authority = .physics_gameplay }, anchored, .reject_if_children);
    try scene.destroyEntity(.{ .authority = .physics_gameplay }, handle, .reject_if_children);
}

test "already-persistent promotion has a dedicated diagnostic and publishes nothing" {
    var resolver = MockResolver{ .allowed = &.{} };
    var scene = try makeScene();
    defer closeScene(&scene);
    const persistent_id = try support.entityId("1b111111-1111-5111-8111-111111111113");
    const replacement_id = try support.entityId("1b111111-1111-5111-8111-111111111114");
    const handle = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
        .owner = .{ .physics_gameplay = null },
        .local_transform = transform(7.0, 8.0, 9.0),
        .resolver = resolver.interface(),
    });
    try scene.promoteTemporary(.{ .authority = .physics_gameplay }, handle, persistent_id);
    var before = try scene.acquireSnapshot(time(1));
    const before_view = before.view();
    const entity_before = try before_view.get(handle);
    const world_before = entity_before.world_transform;
    const local_before = entity_before.local_transform;
    const generation_before = before_view.publication_generation;
    before.deinit();

    try std.testing.expectError(
        error.EntityAlreadyPersistent,
        scene.promoteTemporary(.{ .authority = .physics_gameplay }, handle, replacement_id),
    );
    try std.testing.expectEqual(
        scene_core.runtime_scene.RuntimeErrorCode.entity_already_persistent,
        scene_core.runtime_scene.classifyError(error.EntityAlreadyPersistent),
    );
    var after = try scene.acquireSnapshot(time(2));
    defer after.deinit();
    const after_view = after.view();
    const unchanged = try after_view.get(handle);
    try std.testing.expectEqual(generation_before, after_view.publication_generation);
    try std.testing.expectEqual(handle, after_view.resolve(persistent_id).?);
    try std.testing.expect(after_view.resolve(replacement_id) == null);
    try std.testing.expect(unchanged.lifetime.isPersistentWorld());
    try std.testing.expectEqual(local_before, unchanged.local_transform);
    try expectWorldTransformEquivalent(world_before, unchanged.world_transform);
}

test "persistent-below-Level-owned promotion failure wins before rebase and is atomic" {
    const level_id_text = "1b111111-1111-5111-8111-111111111115";
    const parent_id = try support.entityId("1b111111-1111-5111-8111-111111111116");
    const proposed_id = try support.entityId("1b111111-1111-5111-8111-111111111117");
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{.{ .entity_id = parent_id }};
    const level_definition = try levelFixture(
        level_id_text,
        .{ .x_mm = 5_000_000_000_000, .y_mm = 0, .z_mm = 0 },
        &definitions,
    );
    const level_source = try levelRef(level_id_text, 0x1b);
    var resolver = MockResolver{ .allowed = &.{level_source} };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{
        .source = level_source,
        .definition = &level_definition,
        .resolver = resolver.interface(),
    });
    var active = try scene.acquireSnapshot(time(1));
    const parent = active.view().resolve(parent_id).?;
    active.deinit();
    const handle = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
        .owner = .{ .physics_gameplay = level_source.revision.asset_id },
        .parent = parent,
        .local_transform = transform(1.0, 2.0, 3.0),
        .resolver = resolver.interface(),
    });
    var before = try scene.acquireSnapshot(time(2));
    const before_view = before.view();
    const entity_before = try before_view.get(handle);
    const world_before = entity_before.world_transform;
    const local_before = entity_before.local_transform;
    const generation_before = before_view.publication_generation;
    before.deinit();

    try std.testing.expectError(
        error.PersistentBelowLevelOwned,
        scene.promoteTemporary(.{ .authority = .physics_gameplay }, handle, proposed_id),
    );
    try std.testing.expectEqual(
        scene_core.runtime_scene.RuntimeErrorCode.persistent_below_level_owned,
        scene_core.runtime_scene.classifyError(error.PersistentBelowLevelOwned),
    );
    var after = try scene.acquireSnapshot(time(3));
    defer after.deinit();
    const after_view = after.view();
    const unchanged = try after_view.get(handle);
    try std.testing.expectEqual(generation_before, after_view.publication_generation);
    try std.testing.expect(after_view.resolve(proposed_id) == null);
    try std.testing.expect(unchanged.persistent_id == null);
    try std.testing.expectEqual(parent, unchanged.parent.?);
    try std.testing.expectEqual(local_before, unchanged.local_transform);
    try expectWorldTransformEquivalent(world_before, unchanged.world_transform);
    try std.testing.expectEqual(level_source.revision.asset_id, unchanged.lifetime.owningLevel().?);
}

test "promotion authority remains gameplay-only for every transient class" {
    const level_id_text = "1b111111-1111-5111-8111-111111111118";
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{};
    const level_definition = try levelFixture(level_id_text, .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, &definitions);
    const level_source = try levelRef(level_id_text, 0x1c);
    const proposed_id = try support.entityId("1b111111-1111-5111-8111-111111111119");
    var resolver = MockResolver{ .allowed = &.{level_source} };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{
        .source = level_source,
        .definition = &level_definition,
        .resolver = resolver.interface(),
    });
    const gameplay = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
        .owner = .{ .physics_gameplay = null },
        .resolver = resolver.interface(),
    });
    const editor = try scene.spawnTemporary(.{ .authority = .editor }, .{
        .owner = .{ .editor_preview = null },
        .resolver = resolver.interface(),
    });
    const cinematic = try scene.spawnTemporary(.{ .authority = .cinematic }, .{
        .owner = .{ .cutscene_preview = null },
        .resolver = resolver.interface(),
    });
    const level_owned = try scene.spawnTemporary(.{ .authority = .world }, .{
        .owner = .{ .level = level_source.revision.asset_id },
        .resolver = resolver.interface(),
    });
    var before = try scene.acquireSnapshot(time(1));
    const generation_before = before.view().publication_generation;
    before.deinit();

    try std.testing.expectError(error.UnauthorizedMutation, scene.promoteTemporary(.{ .authority = .editor }, gameplay, proposed_id));
    try std.testing.expectError(error.UnauthorizedMutation, scene.promoteTemporary(.{ .authority = .cinematic }, gameplay, proposed_id));
    try std.testing.expectError(error.UnauthorizedMutation, scene.promoteTemporary(.{ .authority = .physics_gameplay }, editor, proposed_id));
    try std.testing.expectError(error.UnauthorizedMutation, scene.promoteTemporary(.{ .authority = .physics_gameplay }, cinematic, proposed_id));
    try std.testing.expectError(error.UnauthorizedMutation, scene.promoteTemporary(.{ .authority = .physics_gameplay }, level_owned, proposed_id));
    try std.testing.expectEqual(
        scene_core.runtime_scene.RuntimeErrorCode.unauthorized_mutation,
        scene_core.runtime_scene.classifyError(error.UnauthorizedMutation),
    );

    var after = try scene.acquireSnapshot(time(2));
    defer after.deinit();
    const after_view = after.view();
    try std.testing.expectEqual(generation_before, after_view.publication_generation);
    try std.testing.expect(after_view.resolve(proposed_id) == null);
    for ([_]foundation.identity.EntityHandle{ gameplay, editor, cinematic, level_owned }) |handle| {
        try std.testing.expect((try after_view.get(handle)).persistent_id == null);
    }
}

test "world-persistent anchors survive Level unload and cannot be parented below Level ownership" {
    const world_id_text = "1c111111-1111-5111-8111-111111111111";
    const level_id_text = "1d111111-1111-5111-8111-111111111111";
    const anchor_id = try support.entityId("1e111111-1111-5111-8111-111111111111");
    const level_child_id = try support.entityId("1f111111-1111-5111-8111-111111111111");
    const level_root_id = try support.entityId("1f111111-1111-5111-8111-111111111112");
    const level_source = try levelRef(level_id_text, 0x1d);
    const world_entities = [_]scene_core.entity.EntityInstanceDefinition{.{ .entity_id = anchor_id, .local_transform = transform(3.0, 0.0, 0.0) }};
    const world_definition = scene_core.world.WorldDefinition{
        .header = try support.header(scene_core.asset.world_kind, scene_core.asset.world_schema_id, world_id_text),
        .level_refs = &.{level_source},
        .persistent_entities = &world_entities,
    };
    const world_source = try support.assetRef(world_id_text, "f.world", 0x1c);
    const level_entities = [_]scene_core.entity.EntityInstanceDefinition{
        .{
            .entity_id = level_child_id,
            .local_transform = transform(4.0, 0.0, 0.0),
            .parent = .{ .entity_id = anchor_id, .requirement = .required },
        },
        .{ .entity_id = level_root_id, .local_transform = transform(1.0, 0.0, 0.0) },
    };
    const level_definition = try levelFixture(level_id_text, .{ .x_mm = 9_000_000_000, .y_mm = 0, .z_mm = 0 }, &level_entities);
    var resolver = MockResolver{ .allowed = &.{ world_source, level_source } };
    var scene = try makeScene();
    defer closeScene(&scene);

    try scene.activateWorld(.{ .authority = .world }, .{ .source = world_source, .definition = &world_definition, .resolver = resolver.interface() });
    try std.testing.expectError(error.WorldAlreadyActive, scene.activateWorld(.{ .authority = .world }, .{ .source = world_source, .definition = &world_definition, .resolver = resolver.interface() }));
    try scene.activateLevel(.{ .authority = .world }, .{ .source = level_source, .definition = &level_definition, .resolver = resolver.interface() });
    var active = try scene.acquireSnapshot(time(2));
    const anchor = active.view().resolve(anchor_id).?;
    const level_child = active.view().resolve(level_child_id).?;
    const level_root = active.view().resolve(level_root_id).?;
    const child_view = try active.view().get(level_child);
    try std.testing.expectEqual(anchor, child_view.parent.?);
    try std.testing.expectEqual(scene_core.level.WorldCoordinateOrigin{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, child_view.world_transform.origin);
    try expectTranslation(.{ .x = 7.0, .y = 0.0, .z = 0.0 }, child_view.world_transform.affine.translation);
    active.deinit();
    try std.testing.expectError(error.PersistentBelowLevelOwned, scene.setParent(.{ .authority = .world }, anchor, level_child, .keep_local));
    try std.testing.expectError(error.CrossOriginKeepWorldUnsupported, scene.setParent(.{ .authority = .world }, level_root, anchor, .keep_world));
    try scene.deactivateLevel(.{ .authority = .world }, level_source.revision.asset_id);
    var after = try scene.acquireSnapshot(time(3));
    defer after.deinit();
    try std.testing.expectEqual(anchor_id, (try after.view().get(anchor)).persistent_id.?);
    try std.testing.expectError(error.StaleHandle, after.view().get(level_child));
}

test "nested prefab expansion derives identities applies overrides and isolates reused placements" {
    const level_id_text = "20111111-1111-5111-8111-111111111111";
    const lamp_prefab_text = "21111111-2222-5111-8111-111111111111";
    const shade_prefab_text = "22111111-2222-5111-8111-111111111111";
    const first_root_id = try support.entityId("23111111-1111-5111-8111-111111111111");
    const second_root_id = try support.entityId("24111111-1111-5111-8111-111111111111");
    const lamp_ref = try support.assetRef(lamp_prefab_text, "f.prefab", 0x21);
    const shade_ref = try support.assetRef(shade_prefab_text, "f.prefab", 0x22);
    const light_type = try scene_core.extension.ComponentTypeId.init("r.light");
    const light_extension = scene_core.extension.ExtensionRecord{
        .type_id = light_type,
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .required,
        .canonical_payload = "{\"intensity\":1}",
    };
    const shade_nodes = [_]scene_core.prefab.PrefabNodeDefinition{.{
        .node_id = try scene_core.prefab.PrefabNodeId.init("cap"),
        .local_transform = transform(0.0, 1.0, 0.0),
    }};
    const shade_definition = scene_core.prefab.PrefabDefinition{
        .header = try support.header(scene_core.asset.prefab_kind, scene_core.asset.prefab_schema_id, shade_prefab_text),
        .nodes = &shade_nodes,
    };
    const lamp_nodes = [_]scene_core.prefab.PrefabNodeDefinition{
        .{
            .node_id = try scene_core.prefab.PrefabNodeId.init("bulb"),
            .parent = try scene_core.prefab.PrefabNodeId.init("post"),
            .local_transform = transform(0.0, 2.0, 0.0),
            .nested_prefab_ref = shade_ref,
            .extensions = &.{light_extension},
        },
        .{
            .node_id = try scene_core.prefab.PrefabNodeId.init("post"),
            .local_transform = transform(0.0, 1.0, 0.0),
        },
    };
    const lamp_definition = scene_core.prefab.PrefabDefinition{
        .header = try support.header(scene_core.asset.prefab_kind, scene_core.asset.prefab_schema_id, lamp_prefab_text),
        .nodes = &lamp_nodes,
    };
    const override = scene_core.entity.OverrideRecord{
        .target = .{
            .node_path = "bulb",
            .component_type_id = light_type,
            .property_path = "intensity",
        },
        .canonical_value = "2",
    };
    const placements = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = first_root_id, .local_transform = transform(1.0, 0.0, 0.0), .prefab_ref = lamp_ref, .overrides = &.{override} },
        .{ .entity_id = second_root_id, .local_transform = transform(10.0, 0.0, 0.0), .prefab_ref = lamp_ref },
    };
    const level_definition = try levelFixture(level_id_text, .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, &placements);
    const level_source = try levelRef(level_id_text, 0x20);
    const catalog = [_]scene_core.runtime_scene.PrefabCatalogEntry{
        .{ .reference = shade_ref, .definition = &shade_definition },
        .{ .reference = lamp_ref, .definition = &lamp_definition },
    };
    var resolver = MockResolver{ .allowed = &.{ level_source, lamp_ref, shade_ref } };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{
        .source = level_source,
        .definition = &level_definition,
        .prefabs = &catalog,
        .resolver = resolver.interface(),
    });
    var snapshot = try scene.acquireSnapshot(time(1));
    const view = snapshot.view();
    try std.testing.expectEqual(@as(usize, 8), view.entityCount());
    const first_root = view.resolve(first_root_id).?;
    const second_root = view.resolve(second_root_id).?;
    try std.testing.expect(!first_root.eql(second_root));
    const first_bulb_id = try scene_core.prefab.deriveInstantiatedEntityId(first_root_id, "bulb");
    const second_bulb_id = try scene_core.prefab.deriveInstantiatedEntityId(second_root_id, "bulb");
    const first_cap_id = try scene_core.prefab.deriveInstantiatedEntityId(first_root_id, "bulb/cap");
    const first_bulb = try view.get(view.resolve(first_bulb_id).?);
    const second_bulb = try view.get(view.resolve(second_bulb_id).?);
    const first_cap = try view.get(view.resolve(first_cap_id).?);
    try std.testing.expectEqualStrings("bulb", first_bulb.prefabNodePath().?);
    try std.testing.expectEqualStrings("bulb/cap", first_cap.prefabNodePath().?);
    try std.testing.expectEqual(@as(usize, 1), first_bulb.overrideCount());
    try std.testing.expectEqualStrings("2", first_bulb.overrideAt(0).?.canonical_value);
    try std.testing.expectEqual(@as(usize, 0), second_bulb.overrideCount());
    try std.testing.expect(first_bulb.findExtension("r.light") != null);
    snapshot.deinit();

    try scene.destroyEntity(.{ .authority = .world }, first_root, .cascade);
    var remaining = try scene.acquireSnapshot(time(2));
    defer remaining.deinit();
    try std.testing.expectEqual(@as(usize, 4), remaining.view().entityCount());
    try std.testing.expect(remaining.view().resolve(first_root_id) == null);
    try std.testing.expect(remaining.view().resolve(first_bulb_id) == null);
    try std.testing.expect(remaining.view().resolve(second_root_id) != null);
    try std.testing.expect(remaining.view().resolve(second_bulb_id) != null);
}

test "missing nested prefab resolution rolls back every candidate entity" {
    const level_id_text = "25111111-1111-5111-8111-111111111111";
    const outer_prefab_text = "26111111-1111-5111-8111-111111111111";
    const nested_prefab_text = "27111111-1111-5111-8111-111111111111";
    const placement_id = try support.entityId("28111111-1111-5111-8111-111111111111");
    const outer_ref = try support.assetRef(outer_prefab_text, "f.prefab", 0x26);
    const nested_ref = try support.assetRef(nested_prefab_text, "f.prefab", 0x27);
    const nested_nodes = [_]scene_core.prefab.PrefabNodeDefinition{.{ .node_id = try scene_core.prefab.PrefabNodeId.init("leaf") }};
    const nested_definition = scene_core.prefab.PrefabDefinition{
        .header = try support.header(scene_core.asset.prefab_kind, scene_core.asset.prefab_schema_id, nested_prefab_text),
        .nodes = &nested_nodes,
    };
    const outer_nodes = [_]scene_core.prefab.PrefabNodeDefinition{.{
        .node_id = try scene_core.prefab.PrefabNodeId.init("root"),
        .nested_prefab_ref = nested_ref,
    }};
    const outer_definition = scene_core.prefab.PrefabDefinition{
        .header = try support.header(scene_core.asset.prefab_kind, scene_core.asset.prefab_schema_id, outer_prefab_text),
        .nodes = &outer_nodes,
    };
    const placements = [_]scene_core.entity.EntityInstanceDefinition{.{ .entity_id = placement_id, .prefab_ref = outer_ref }};
    const level_definition = try levelFixture(level_id_text, .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, &placements);
    const level_source = try levelRef(level_id_text, 0x25);
    const catalog = [_]scene_core.runtime_scene.PrefabCatalogEntry{
        .{ .reference = outer_ref, .definition = &outer_definition },
        .{ .reference = nested_ref, .definition = &nested_definition },
    };
    var resolver = MockResolver{ .allowed = &.{ level_source, outer_ref } };
    var scene = try makeScene();
    defer closeScene(&scene);
    try std.testing.expectError(error.AssetResolutionFailed, scene.activateLevel(.{ .authority = .world }, .{
        .source = level_source,
        .definition = &level_definition,
        .prefabs = &catalog,
        .resolver = resolver.interface(),
    }));
    var snapshot = try scene.acquireSnapshot(time(0));
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 0), snapshot.view().entityCount());
    try std.testing.expectEqual(@as(usize, 0), snapshot.view().levelCount());
    try std.testing.expect(snapshot.view().resolve(placement_id) == null);
}

test "runtime owns authored slices and neutral mock consumers share one published identity" {
    const level_id_text = "29111111-1111-5111-8111-111111111111";
    const entity_id = try support.entityId("2a111111-1111-5111-8111-111111111111");
    const presentation_asset = try support.assetRef("2b111111-1111-5111-8111-111111111111", "u.presentation", 0x2b);
    const presentation = try scene_core.asset.PresentationRef.init(presentation_asset);
    const tag_bytes = try std.testing.allocator.dupe(u8, "gameplay:lamp");
    var tag_owned = true;
    defer if (tag_owned) std.testing.allocator.free(tag_bytes);
    const type_bytes = try std.testing.allocator.dupe(u8, "p.body");
    var type_owned = true;
    defer if (type_owned) std.testing.allocator.free(type_bytes);
    const payload_bytes = try std.testing.allocator.dupe(u8, "{\"mass\":2}");
    var payload_owned = true;
    defer if (payload_owned) std.testing.allocator.free(payload_bytes);
    const tags = [_]scene_core.metadata.TagId{try scene_core.metadata.TagId.init(tag_bytes)};
    const dependencies = [_]foundation.reference.DirectDependency{.{ .asset = presentation_asset, .class = .optional_presentation }};
    const extensions = [_]scene_core.extension.ExtensionRecord{.{
        .type_id = try scene_core.extension.ComponentTypeId.init(type_bytes),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .optional_preserve,
        .canonical_payload = payload_bytes,
        .dependencies = &dependencies,
    }};
    const camera = scene_core.camera.CameraDefinition{
        .projection = .perspective,
        .perspective = .{ .focal_length_mm = 50.0, .sensor_width_mm = 36.0, .sensor_height_mm = 24.0 },
        .near_clip_m = 0.1,
        .far_clip_m = 1000.0,
    };
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{.{
        .entity_id = entity_id,
        .local_transform = transform(3.0, 4.0, 5.0),
        .tags = &tags,
        .visibility = .visible,
        .presentation = presentation,
        .extensions = &extensions,
        .camera_definition = camera,
    }};
    var level_definition = try levelFixture(level_id_text, .{ .x_mm = 123_456_789, .y_mm = -4, .z_mm = 8 }, &definitions);
    level_definition.header.dependencies = &dependencies;
    const level_source = try levelRef(level_id_text, 0x29);
    var resolver = MockResolver{ .allowed = &.{ level_source, presentation_asset } };
    var scene = try makeScene();
    defer closeScene(&scene);
    try scene.activateLevel(.{ .authority = .world }, .{
        .source = level_source,
        .definition = &level_definition,
        .resolver = resolver.interface(),
    });
    @memset(tag_bytes, 'x');
    @memset(type_bytes, 'x');
    @memset(payload_bytes, 'x');
    std.testing.allocator.free(tag_bytes);
    tag_owned = false;
    std.testing.allocator.free(type_bytes);
    type_owned = false;
    std.testing.allocator.free(payload_bytes);
    payload_owned = false;

    var snapshot = try scene.acquireSnapshot(time(42));
    defer snapshot.deinit();
    const view = snapshot.view();
    const gameplay_handle = view.resolve(entity_id).?;
    const shared = try view.get(gameplay_handle);

    // Mock R consumes only shared transform, visibility, and neutral asset token.
    const render_handle = shared.handle;
    const render_world = shared.world_transform;
    try std.testing.expectEqual(scene_core.metadata.VisibilityIntent.visible, shared.visibility);
    try std.testing.expectEqual(scene_core.runtime_scene.AssetRole.presentation, shared.assetAt(0).?.role);
    try std.testing.expectEqual(@as(u32, 2), shared.assetAt(0).?.token.value);

    // Mock P consumes the same handle/world plus only its namespaced envelope.
    const physics_handle = shared.handle;
    const physics_world = shared.world_transform;
    const physics_extension = shared.findExtension("p.body").?;
    try std.testing.expectEqualStrings("{\"mass\":2}", physics_extension.canonical_payload);
    try std.testing.expectEqual(scene_core.extension.Criticality.optional_preserve, physics_extension.criticality);
    try std.testing.expectEqual(@as(usize, 1), physics_extension.dependencyCount());
    try std.testing.expect(physics_extension.dependencyAt(0).?.reference.eql(presentation_asset));

    // Mock gameplay resolves persistent identity and shared tags.
    try std.testing.expectEqualStrings("gameplay:lamp", shared.tagAt(0).?);

    // Mock C reads the same entity and F-owned neutral camera geometry.
    const cinematic_handle = shared.handle;
    const cinematic_world = shared.world_transform;
    try std.testing.expectEqual(camera, shared.camera_definition.?);
    try std.testing.expectEqual(@as(u64, 42), snapshot.time.tick);

    try std.testing.expectEqual(render_handle, physics_handle);
    try std.testing.expectEqual(render_handle, gameplay_handle);
    try std.testing.expectEqual(render_handle, cinematic_handle);
    try std.testing.expectEqual(render_world.origin, physics_world.origin);
    try std.testing.expectEqual(render_world.origin, cinematic_world.origin);
    try std.testing.expect(foundation.spatial.approximatelyEqual(render_world.affine, physics_world.affine));
    try std.testing.expect(foundation.spatial.approximatelyEqual(render_world.affine, cinematic_world.affine));
    try std.testing.expectEqual(level_source.revision.asset_id, shared.lifetime.owningLevel().?);
}

const ParticipantProbe = struct {
    fail_prepare: bool,
    prepared: usize = 0,
    committed: usize = 0,
    rolled_back: usize = 0,
    seen_entities: usize = 0,

    fn prepare(context: ?*anyopaque, view: scene_core.runtime_scene.SceneReadView) anyerror!void {
        const self: *ParticipantProbe = @ptrCast(@alignCast(context.?));
        self.prepared += 1;
        self.seen_entities = view.entityCount();
        if (self.fail_prepare) return error.SyntheticCompileFailure;
    }

    fn commit(context: ?*anyopaque, _: u64) void {
        const self: *ParticipantProbe = @ptrCast(@alignCast(context.?));
        self.committed += 1;
    }

    fn rollback(context: ?*anyopaque) void {
        const self: *ParticipantProbe = @ptrCast(@alignCast(context.?));
        self.rolled_back += 1;
    }

    fn participant(self: *ParticipantProbe) scene_core.runtime_scene.PublicationParticipant {
        return .{ .context = self, .prepare_fn = prepare, .commit_fn = commit, .rollback_fn = rollback };
    }
};

test "two-phase publication rolls back core and prepared extension tables together" {
    const level_id_text = "2c111111-1111-5111-8111-111111111111";
    const entity_id = try support.entityId("2d111111-1111-5111-8111-111111111111");
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{.{ .entity_id = entity_id }};
    const level_definition = try levelFixture(level_id_text, .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, &definitions);
    const level_source = try levelRef(level_id_text, 0x2c);
    var resolver = MockResolver{ .allowed = &.{level_source} };
    var first = ParticipantProbe{ .fail_prepare = false };
    var second = ParticipantProbe{ .fail_prepare = true };
    var participants = [_]scene_core.runtime_scene.PublicationParticipant{ first.participant(), second.participant() };
    var scene = try makeScene();
    defer closeScene(&scene);

    try std.testing.expectError(error.PublicationPrepareFailed, scene.activateLevel(.{
        .authority = .world,
        .participants = &participants,
    }, .{
        .source = level_source,
        .definition = &level_definition,
        .resolver = resolver.interface(),
    }));
    try std.testing.expectEqual(@as(usize, 1), first.prepared);
    try std.testing.expectEqual(@as(usize, 1), first.rolled_back);
    try std.testing.expectEqual(@as(usize, 0), first.committed);
    try std.testing.expectEqual(@as(usize, 1), second.rolled_back);
    var empty = try scene.acquireSnapshot(time(0));
    try std.testing.expectEqual(@as(usize, 0), empty.view().entityCount());
    try std.testing.expectEqual(@as(u64, 0), empty.view().publication_generation);
    empty.deinit();

    second.fail_prepare = false;
    participants = .{ first.participant(), second.participant() };
    try scene.activateLevel(.{ .authority = .world, .participants = &participants }, .{
        .source = level_source,
        .definition = &level_definition,
        .resolver = resolver.interface(),
    });
    try std.testing.expectEqual(@as(usize, 1), first.committed);
    try std.testing.expectEqual(@as(usize, 1), second.committed);
    try std.testing.expectEqual(@as(usize, 1), first.seen_entities);
    try std.testing.expectEqual(@as(usize, 1), second.seen_entities);
    var published = try scene.acquireSnapshot(time(1));
    defer published.deinit();
    try std.testing.expectEqual(@as(u64, 1), published.view().publication_generation);
    try std.testing.expect(published.view().resolve(entity_id) != null);
}

test "snapshot leases are bounded and release permits later acquisition" {
    var scene = try makeScene();
    var snapshots: [4]scene_core.runtime_scene.SceneSnapshot = undefined;
    for (&snapshots, 0..) |*snapshot, index| snapshot.* = try scene.acquireSnapshot(time(index));
    try std.testing.expectError(error.SnapshotCapacity, scene.acquireSnapshot(time(5)));
    try std.testing.expectError(error.OutstandingSnapshotLeases, scene.deinit());
    for (&snapshots) |*snapshot| snapshot.deinit();
    var replacement = try scene.acquireSnapshot(time(6));
    replacement.deinit();
    closeScene(&scene);
}

test "runtime failures map to stable machine-readable F diagnostics" {
    try std.testing.expectEqual(scene_core.runtime_scene.RuntimeErrorCode.stale_handle, scene_core.runtime_scene.classifyError(error.StaleHandle));
    try std.testing.expectEqual(foundation.diagnostics.Code.invalid_reference, scene_core.runtime_scene.foundationDiagnosticCode(.stale_handle));
    try std.testing.expectEqual(foundation.diagnostics.Code.capacity_exceeded, scene_core.runtime_scene.foundationDiagnosticCode(.registry_capacity));
    try std.testing.expectEqual(foundation.diagnostics.Code.invalid_spatial_value, scene_core.runtime_scene.foundationDiagnosticCode(.cross_origin_keep_world));
}

const GrowthProbe = struct {
    events: [16]scene_core.runtime_scene.GrowthEvent = undefined,
    count: usize = 0,

    fn emit(context: ?*anyopaque, event: scene_core.runtime_scene.GrowthEvent) void {
        const self: *GrowthProbe = @ptrCast(@alignCast(context.?));
        if (self.count < self.events.len) {
            self.events[self.count] = event;
            self.count += 1;
        }
    }
};

test "publication reports authorized growth and capacity failure remains atomic" {
    const level_id_text = "2e111111-1111-5111-8111-111111111111";
    const ids = [_]foundation.identity.EntityId{
        try support.entityId("2f111111-1111-5111-8111-111111111111"),
        try support.entityId("30111111-1111-5111-8111-111111111111"),
        try support.entityId("31111111-1111-5111-8111-111111111112"),
        try support.entityId("32111111-1111-5111-8111-111111111112"),
        try support.entityId("33111111-1111-5111-8111-111111111112"),
    };
    const definitions = [_]scene_core.entity.EntityInstanceDefinition{
        .{ .entity_id = ids[0] }, .{ .entity_id = ids[1] }, .{ .entity_id = ids[2] }, .{ .entity_id = ids[3] }, .{ .entity_id = ids[4] },
    };
    const level_definition = try levelFixture(level_id_text, .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 }, &definitions);
    const level_source = try levelRef(level_id_text, 0x2e);
    var resolver = MockResolver{ .allowed = &.{level_source} };
    var growth = GrowthProbe{};
    var scene = try RuntimeScene.init(std.testing.allocator, .{
        .registry = .{
            .initial_entity_capacity = 1,
            .hard_entity_capacity = 4,
            .initial_mapping_capacity = 1,
            .hard_mapping_capacity = 4,
        },
        .initial_level_capacity = 1,
        .hard_level_capacity = 2,
        .max_snapshot_leases = 2,
        .growth_sink = .{ .context = &growth, .emit_fn = GrowthProbe.emit },
    });
    defer closeScene(&scene);
    try std.testing.expectError(error.RegistryCapacity, scene.activateLevel(.{ .authority = .world }, .{
        .source = level_source,
        .definition = &level_definition,
        .resolver = resolver.interface(),
    }));
    try std.testing.expectEqual(@as(usize, 0), growth.count);
    var empty = try scene.acquireSnapshot(time(0));
    try std.testing.expectEqual(@as(usize, 0), empty.view().entityCount());
    empty.deinit();

    var accepted_definition = level_definition;
    accepted_definition.entities = definitions[0..3];
    try scene.activateLevel(.{ .authority = .world }, .{
        .source = level_source,
        .definition = &accepted_definition,
        .resolver = resolver.interface(),
    });
    try std.testing.expect(growth.count >= 4);
    var snapshot = try scene.acquireSnapshot(time(1));
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 3), snapshot.view().entityCount());
    try std.testing.expect(snapshot.view().entityCapacity() >= 3);
    for (ids[0..3]) |persistent_id| try std.testing.expect(snapshot.view().resolve(persistent_id) != null);
}
