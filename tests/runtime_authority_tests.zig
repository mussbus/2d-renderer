const std = @import("std");
const authored = @import("authored_clips");
const character = @import("character");
const collision_world = @import("collision_world");
const handshake = @import("handshake");
const humanoid = @import("humanoid");
const interaction_system = @import("interaction_system");

test "character and interaction supported roots hide protected mutable state" {
    try std.testing.expectEqual(@as(usize, 1), @typeInfo(character.CharacterInstance).@"struct".fields.len);
    try std.testing.expect(@hasField(character.CharacterInstance, "opaque_storage"));
    try std.testing.expect(!@hasField(character.CharacterInstance, "animator"));
    try std.testing.expect(!@hasField(character.CharacterInstance, "controller"));
    try std.testing.expect(!@hasField(character.CharacterInstance, "foot_plants"));
    try std.testing.expect(!@hasField(character.CharacterInstance, "equipment_loadout"));
    try std.testing.expect(!@hasField(character.CharacterInstance, "presentation"));
    try std.testing.expect(!@hasField(character.CharacterInstance, "interaction_owner_id"));
    try std.testing.expect(!@hasField(character.CharacterInstance, "simulation_tick"));
    try std.testing.expect(!@hasField(character.CharacterInstance, "last_submitted_keys"));

    try std.testing.expectEqual(@as(usize, 1), @typeInfo(interaction_system.Manager).@"struct".fields.len);
    try std.testing.expect(@hasField(interaction_system.Manager, "opaque_storage"));
    try std.testing.expect(!@hasField(interaction_system.Manager, "slots"));
    try std.testing.expect(!@hasField(interaction_system.Manager, "next_id"));
    try std.testing.expect(!@hasField(interaction_system.Manager, "metrics"));
    try std.testing.expect(!@hasField(interaction_system.Manager, "last_terminal"));
    try std.testing.expect(!@hasField(interaction_system.Manager, "ik_enabled"));
}

test "character commands publish read-only views and detached value snapshots" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    var instance = try character.CharacterInstance.initControlled(
        std.testing.allocator,
        try character.entityIdFromRaw(1),
        &definition,
        &animations,
        &world,
        .{},
        .{ .x = -4, .y = 1.05 },
        .right,
        0,
        null,
    );
    defer instance.deinit();

    try std.testing.expect(@TypeOf(instance.humanoidView()) == *const humanoid.HumanoidCharacter);
    const initial = instance.read();
    try instance.setFacing(.left);
    try instance.setActorLayer(3);
    try instance.setWorldPosition(.{ .x = -3.5, .y = 1.05 });
    const changed = instance.read();
    try std.testing.expectEqual(humanoid.Facing.left, changed.facing);
    try std.testing.expectEqual(@as(u16, 3), changed.actor_layer);
    try std.testing.expect(!initial.world_position.approxEqAbs(changed.world_position, 0));

    var controller_copy = instance.controllerSnapshot().?;
    controller_copy.state.position.x += 100;
    try std.testing.expect(!controller_copy.state.position.approxEqAbs(instance.controllerSnapshot().?.state.position, 0));
    var planting_copy = instance.footPlantingSnapshot();
    planting_copy.left.plant_weight = 1;
    try std.testing.expectEqual(@as(f32, 0), instance.footPlantingSnapshot().left.plant_weight);
}

test "interaction lifecycle authority publishes const observations only" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var a = try character.CharacterInstance.init(
        std.testing.allocator,
        try character.entityIdFromRaw(1),
        &definition,
        &animations,
        .{ .x = -1.86, .y = 1.05 },
        .right,
        0,
        null,
    );
    defer a.deinit();
    var b = try character.CharacterInstance.init(
        std.testing.allocator,
        try character.entityIdFromRaw(2),
        &definition,
        &animations,
        .{ .x = 1.86, .y = 1.05 },
        .left,
        1,
        null,
    );
    defer b.deinit();
    var manager = interaction_system.Manager.init(try handshake.definition(&animations));
    const participants = [_]*character.CharacterInstance{ &a, &b };
    const id = try manager.startPair(a.id(), b.id(), &participants, 0, .none);
    const observation = manager.instance(id) orelse return error.MissingInteractionObservation;
    try std.testing.expect(@TypeOf(observation) == *const interaction_system.Instance);
    try std.testing.expectEqual(@as(usize, 1), manager.activeCount());
    try std.testing.expectEqual(@as(u64, 1), manager.metricsSnapshot().starts);
    try manager.reset(&participants);
    try std.testing.expectEqual(@as(usize, 0), manager.activeCount());
}
