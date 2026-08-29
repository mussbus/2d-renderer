const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");

const Registry = scene_core.registry.EntityRegistry;

fn acceptAsset(_: ?*anyopaque, _: foundation.reference.AssetRef) anyerror!scene_core.runtime_asset.ResolvedAssetToken {
    return scene_core.runtime_asset.ResolvedAssetToken.init(1);
}

const resolver = scene_core.runtime_asset.Resolver{ .context = null, .resolve_fn = acceptAsset };

fn id(text: []const u8) !foundation.identity.EntityId {
    return foundation.identity.EntityId.parseCanonical(text);
}

fn record(entity_id: ?foundation.identity.EntityId) !scene_core.runtime_entity.RuntimeEntity {
    return scene_core.runtime_entity.RuntimeEntity.initOwned(
        std.testing.allocator,
        .{
            .persistent_id = entity_id,
            .lifetime = .world_persistent,
            .local_transform = .identity,
            .authored_enabled = .inherit,
            .visibility = .inherit,
            .tags = &.{},
            .extensions = &.{},
        },
        resolver,
        .{ .x_mm = 0, .y_mm = 0, .z_mm = 0 },
    );
}

fn initRegistry(initial: usize, hard: usize) !Registry {
    return Registry.init(std.testing.allocator, .{
        .initial_entity_capacity = initial,
        .hard_entity_capacity = hard,
        .initial_mapping_capacity = initial,
        .hard_mapping_capacity = hard,
    });
}

test "registry allocates resolves destroys reuses and rejects stale handles" {
    var registry = try initRegistry(1, 4);
    defer registry.deinit();
    var growth = scene_core.registry.GrowthEvents{};
    const first_id = try id("9b7e2c18-6f3a-5d41-8c20-1234567890ab");
    const second_id = try id("a47e2c18-6f3a-5d41-8c20-1234567890ab");
    const first = try registry.insert(try record(first_id), .runtime_create, &growth);
    try std.testing.expectEqual(first, registry.resolve(first_id).?);
    try std.testing.expectEqual(first_id, (try registry.get(first)).persistent_id.?);
    try registry.destroy(first, .entity_destroy, &growth);
    try std.testing.expect(registry.resolve(first_id) == null);
    try std.testing.expectError(error.StaleHandle, registry.get(first));

    const second = try registry.insert(try record(second_id), .runtime_create, &growth);
    try std.testing.expectEqual(first.slot, second.slot);
    try std.testing.expectEqual(first.generation + 1, second.generation);
    try std.testing.expectError(error.StaleHandle, registry.get(first));
    try std.testing.expectEqual(second_id, (try registry.get(second)).persistent_id.?);
}

test "registry rejects invalid and duplicate persistent identities" {
    var registry = try initRegistry(1, 2);
    defer registry.deinit();
    var growth = scene_core.registry.GrowthEvents{};
    const persistent_id = try id("b57e2c18-6f3a-5d41-8c20-1234567890ab");
    _ = try registry.insert(try record(persistent_id), .runtime_create, &growth);
    var duplicate = try record(persistent_id);
    defer duplicate.deinit(std.testing.allocator);
    try std.testing.expectError(error.DuplicateActiveEntityId, registry.insert(duplicate, .runtime_create, &growth));
    try std.testing.expectError(error.InvalidHandle, registry.get(.invalid));
}

test "registry logical growth preserves handles and reports bounded capacity" {
    var registry = try initRegistry(1, 3);
    defer registry.deinit();
    var growth = scene_core.registry.GrowthEvents{};
    const first = try registry.insert(try record(null), .runtime_create, &growth);
    const second = try registry.insert(try record(null), .runtime_create, &growth);
    try std.testing.expect((try registry.get(first)).handle.eql(first));
    try std.testing.expect((try registry.get(second)).handle.eql(second));
    try std.testing.expectEqual(@as(usize, 1), growth.values().len);
    try std.testing.expectEqual(scene_core.registry.GrowthCategory.entity_slots, growth.values()[0].category);
    try std.testing.expectEqual(@as(usize, 2), registry.entityCapacity());
    _ = try registry.insert(try record(null), .runtime_create, &growth);
    var overflow = try record(null);
    defer overflow.deinit(std.testing.allocator);
    try std.testing.expectError(error.RegistryCapacity, registry.insert(overflow, .runtime_create, &growth));
}

test "generation exhaustion retires instead of wrapping" {
    try std.testing.expectEqual(@as(?u32, 2), scene_core.registry.nextGenerationAfterDestroy(1));
    try std.testing.expectEqual(@as(?u32, null), scene_core.registry.nextGenerationAfterDestroy(std.math.maxInt(u32)));
}
