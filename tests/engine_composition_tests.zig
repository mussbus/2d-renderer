const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const client_module = @import("engine_smoke_client");
const math = @import("math");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const bindings_module = @import("character_entity_binding");
const handshake = @import("handshake");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");

fn entityId(last_digit: u8) !foundation.identity.EntityId {
    var text = "0195d5b8-4000-7000-8000-000000000010".*;
    text[text.len - 1] = last_digit;
    return foundation.identity.EntityId.parseCanonical(&text);
}

const CharacterFixture = struct {
    definition: humanoid.HumanoidDefinition,
    animations: authored.Definitions,
    first: character.CharacterInstance,
    second: character.CharacterInstance,

    fn init() !CharacterFixture {
        var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
        errdefer definition.deinit();
        var animations = try authored.Definitions.init(
            std.testing.allocator,
            &definition.skeleton_definition,
            null,
        );
        errdefer animations.deinit();
        var first = try character.CharacterInstance.init(
            std.testing.allocator,
            try character.entityIdFromRaw(1),
            &definition,
            &animations,
            .{ .x = -1.86, .y = 1.05 },
            .right,
            0,
            null,
        );
        errdefer first.deinit();
        var second = try character.CharacterInstance.init(
            std.testing.allocator,
            try character.entityIdFromRaw(2),
            &definition,
            &animations,
            .{ .x = 1.86, .y = 1.05 },
            .left,
            1,
            null,
        );
        errdefer second.deinit();
        return .{
            .definition = definition,
            .animations = animations,
            .first = first,
            .second = second,
        };
    }

    fn deinit(fixture: *CharacterFixture) void {
        fixture.second.deinit();
        fixture.first.deinit();
        fixture.animations.deinit();
        fixture.definition.deinit();
        fixture.* = undefined;
    }

    fn characters(fixture: *CharacterFixture) [2]*character.CharacterInstance {
        return .{ &fixture.first, &fixture.second };
    }
};

test "second client composes RuntimeScene identity transform lifecycle and render data without demo authority" {
    var client = try client_module.Client.init(std.testing.allocator);
    defer client.deinit() catch |err| {
        std.debug.panic("test RuntimeScene cleanup failed: {s}", .{@errorName(err)});
    };

    const initial = try client.observe(0);
    try std.testing.expect(initial.handle.isValid());
    try std.testing.expect(initial.entity_id.eql(client.entity_id));
    try std.testing.expect(initial.effective_enabled);
    switch (initial.lifetime) {
        .world_persistent => {},
        else => return error.ExpectedWorldPersistentEntity,
    }

    try client.setPosition(client_module.moved_position);
    const moved = try client.observe(1);
    try std.testing.expect(moved.publication_generation > initial.publication_generation);
    try std.testing.expectEqual(client_module.moved_position[0], moved.local_transform.translation.x);
    try std.testing.expectEqual(client_module.moved_position[1], moved.local_transform.translation.y);
    const request = try client.renderRequest(moved);
    try std.testing.expectEqual(client_module.moved_position[0], request.world_position[0]);
    try std.testing.expectEqual(client_module.moved_position[1], request.world_position[1]);
}

test "character bindings synchronize two specialized runtimes through F without a demo application" {
    var fixture = try CharacterFixture.init();
    defer fixture.deinit();
    var bindings = try bindings_module.CharacterEntityBindings.init(std.testing.allocator);
    defer bindings.deinit();

    const first_handle = try bindings.createPersistent(
        try entityId('1'),
        fixture.first.id(),
        fixture.first.worldPosition(),
    );
    const second_handle = try bindings.createPersistent(
        try entityId('2'),
        fixture.second.id(),
        fixture.second.worldPosition(),
    );
    try std.testing.expectEqual(@as(usize, 2), bindings.bindingCount());
    try std.testing.expectEqual(fixture.first.id(), try bindings.characterForEntity(first_handle));
    try std.testing.expectEqual(fixture.second.id(), try bindings.characterForEntity(second_handle));

    const commanded = math.Vec2{ .x = -1.5, .y = 1.25 };
    try bindings.setSceneRoot(first_handle, commanded);
    try bindings.applySceneTransform(&fixture.first);
    try std.testing.expect(fixture.first.worldPosition().approxEqAbs(commanded, bindings_module.root_tolerance));

    const simulated = math.Vec2{ .x = -1.25, .y = 1.25 };
    try fixture.first.setWorldPosition(simulated);
    try std.testing.expect(try bindings.publishCharacterTransform(&fixture.first));
    try bindings.setEnabled(second_handle, false);
    try std.testing.expect(!try bindings.isEnabled(second_handle));

    var snapshot = try bindings.acquireSnapshot(.{
        .tick = 2,
        .fixed_delta_seconds = 1.0 / 240.0,
        .interpolation_alpha = 0,
    });
    defer snapshot.deinit();
    const first_view = try snapshot.view().get(first_handle);
    const second_view = try snapshot.view().get(second_handle);
    try std.testing.expectEqual(simulated.x, first_view.local_transform.translation.x);
    try std.testing.expectEqual(simulated.y, first_view.local_transform.translation.y);
    try std.testing.expect(!second_view.effective_enabled);
}

test "production interaction coordinates F-bound characters without scenario fixtures" {
    var fixture = try CharacterFixture.init();
    defer fixture.deinit();
    var bindings = try bindings_module.CharacterEntityBindings.init(std.testing.allocator);
    defer bindings.deinit();
    const first_handle = try bindings.createPersistent(
        try entityId('3'),
        fixture.first.id(),
        fixture.first.worldPosition(),
    );
    const second_handle = try bindings.createPersistent(
        try entityId('4'),
        fixture.second.id(),
        fixture.second.worldPosition(),
    );

    var manager = interaction_system.Manager.init(try handshake.definition(&fixture.animations));
    const characters = fixture.characters();
    const interaction_id = try manager.startPair(
        fixture.first.id(),
        fixture.second.id(),
        &characters,
        10,
        .none,
    );
    var tick: u64 = 11;
    while (tick <= 370) : (tick += 1) try manager.updateTick(tick, &characters);
    const completed = manager.instance(interaction_id) orelse
        return error.MissingCompletedInteraction;
    try std.testing.expectEqual(interaction.Lifecycle.completed, completed.lifecycle);
    try std.testing.expectEqual(@as(usize, 0), manager.activeCount());
    try std.testing.expect(!fixture.first.isInteractionLocked());
    try std.testing.expect(!fixture.second.isInteractionLocked());
    try std.testing.expectEqual(fixture.first.id(), try bindings.characterForEntity(first_handle));
    try std.testing.expectEqual(fixture.second.id(), try bindings.characterForEntity(second_handle));
    try std.testing.expect(!(try bindings.publishCharacterTransform(&fixture.first)));
    try std.testing.expect(!(try bindings.publishCharacterTransform(&fixture.second)));
}

comptime {
    _ = scene_core.runtime_scene.RuntimeScene;
}
