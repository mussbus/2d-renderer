const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const physical = @import("physical_input");
const input = @import("input");
const character = @import("character");
const bindings_module = @import("character_entity_binding");
const integrated = @import("integrated_demo");

fn entityId(last_digit: u8) !foundation.identity.EntityId {
    var text = "0195d5b8-2000-7000-8000-000000000000".*;
    text[text.len - 1] = last_digit;
    return foundation.identity.EntityId.parseCanonical(&text);
}

fn snapshotEntityCount(bindings: *bindings_module.CharacterEntityBindings) !usize {
    var snapshot = try bindings.acquireSnapshot(.{
        .tick = 0,
        .fixed_delta_seconds = 1.0 / 240.0,
        .interpolation_alpha = 0,
    });
    defer snapshot.deinit();
    return snapshot.view().entityCount();
}

test "physical input maps to application actions and physics intent without content in platform state" {
    const raw = physical.RawInputState{
        .keyboard = .{
            .d = true,
            .space = true,
            .left_shift = true,
            .e = true,
            .r = true,
            .f1 = true,
            .f2 = true,
            .f3 = true,
            .f4 = true,
            .c = true,
            .v = true,
            .h = true,
            .l = true,
            .o = true,
            .p = true,
            .q = true,
            .t = true,
            .escape = true,
        },
        .gamepad_left_x = -0.5,
        .gamepad_button_south = true,
        .gamepad_button_right_shoulder = true,
        .gamepad_button_west = true,
    };
    var mapper = input.SnapshotBuilder{};
    const actions = try mapper.update(raw);
    try std.testing.expectEqual(@as(f32, 1), actions.move_axis);
    try std.testing.expect(actions.jump.pressed and actions.dash.pressed and actions.interact.pressed);
    try std.testing.expect(actions.reset.pressed and actions.debug_toggle.pressed);
    try std.testing.expect(actions.time_mode_cycle.pressed and actions.single_step.pressed);
    try std.testing.expect(actions.manual_debug_capture.pressed);
    try std.testing.expect(actions.body_preset_cycle.pressed and actions.build_cycle.pressed and actions.hair_cycle.pressed);
    try std.testing.expect(actions.loadout_cycle.pressed and actions.outfit_cycle.pressed);
    try std.testing.expect(actions.pause_toggle.pressed and actions.presentation_view_cycle.pressed);
    try std.testing.expect(actions.environment_theme_cycle.pressed and actions.exit.pressed);

    var pending = input.PendingInput{};
    try pending.acceptFrame(actions);
    const intent = pending.consumeTick();
    try intent.validate();
    try std.testing.expectEqual(@as(f32, 1), intent.move_axis);
    try std.testing.expect(intent.jump_pressed and intent.jump_held);
    try std.testing.expect(intent.dash_pressed and intent.interact_pressed);
    try std.testing.expectEqual(@as(u8, 0), pending.pendingEdgeCount());
}

test "application action mapping preserves focus blocking scripted parity and evidence ownership" {
    var focused = input.SnapshotBuilder{};
    var actions = try focused.update(.{
        .keyboard = .{ .q = true, .f4 = true },
        .keyboard_focused = false,
        .focus_lost = true,
    });
    try std.testing.expect(!actions.presentation_view_cycle.pressed);
    try std.testing.expect(!actions.manual_debug_capture.pressed);
    try std.testing.expect(actions.focus_lost);

    actions = try focused.update(.{ .keyboard = .{ .q = true, .f4 = true } });
    try std.testing.expect(!actions.presentation_view_cycle.pressed);
    try std.testing.expect(!actions.manual_debug_capture.pressed);
    _ = try focused.update(.{});
    actions = try focused.update(.{ .keyboard = .{ .q = true, .f4 = true } });
    try std.testing.expect(actions.presentation_view_cycle.pressed);
    try std.testing.expect(actions.manual_debug_capture.pressed);

    const scripted_raw = physical.RawInputState{
        .keyboard = .{ .a = true, .e = true, .o = true },
        .gamepad_button_south = true,
    };
    var first = input.SnapshotBuilder{};
    var second = input.SnapshotBuilder{};
    try std.testing.expectEqualDeep(try first.update(scripted_raw), try second.update(scripted_raw));
    try std.testing.expectEqualDeep(try first.update(scripted_raw), try second.update(scripted_raw));
    try std.testing.expectEqualDeep(try first.update(.{}), try second.update(.{}));
}

test "bounded binding contains legacy identity and rolls back failed persistent creation" {
    var bindings = try bindings_module.CharacterEntityBindings.init(std.testing.allocator);
    defer bindings.deinit();
    const character_one = try character.entityIdFromRaw(1);
    const character_two = try character.entityIdFromRaw(2);
    const first_id = try entityId('1');
    const first_handle = try bindings.createPersistent(first_id, character_one, .{ .x = 1, .y = 2 });
    try std.testing.expectEqual(@as(usize, 1), bindings.bindingCount());
    try std.testing.expectEqual(@as(usize, 1), try snapshotEntityCount(&bindings));
    try std.testing.expectEqual(character_one, try bindings.characterForEntity(first_handle));
    try std.testing.expect((try bindings.persistentIdForCharacter(character_one)).eql(first_id));

    try std.testing.expectError(
        error.DuplicatePersistentEntityBinding,
        bindings.createPersistent(first_id, character_two, .{ .x = 3, .y = 4 }),
    );
    try std.testing.expectError(
        error.DuplicateCharacterBinding,
        bindings.createPersistent(try entityId('2'), character_one, .{ .x = 3, .y = 4 }),
    );
    try std.testing.expectEqual(@as(usize, 1), try snapshotEntityCount(&bindings));

    // Removing the specialized runtime binding leaves the F entity alive.
    // Reusing its persistent ID then fails during F promotion after a new
    // temporary was created; the temporary is destroyed atomically.
    try bindings.detachCharacter(character_one);
    try std.testing.expectEqual(@as(usize, 0), bindings.bindingCount());
    try std.testing.expectEqual(@as(usize, 1), try snapshotEntityCount(&bindings));
    try std.testing.expectError(
        error.DuplicateActiveEntityId,
        bindings.createPersistent(first_id, character_two, .{ .x = 3, .y = 4 }),
    );
    try std.testing.expectEqual(@as(usize, 1), try snapshotEntityCount(&bindings));

    try bindings.bindExisting(first_id, first_handle, character_one);
    try bindings.destroyForCharacter(character_one);
    try std.testing.expectEqual(@as(usize, 0), bindings.bindingCount());
    try std.testing.expectEqual(@as(usize, 0), try snapshotEntityCount(&bindings));
    try std.testing.expectError(error.CharacterBindingNotFound, bindings.characterForEntity(first_handle));

    const replacement = try bindings.createPersistent(try entityId('3'), character_two, .{ .x = 5, .y = 6 });
    try std.testing.expect(!replacement.eql(first_handle));
    try std.testing.expectError(error.CharacterBindingNotFound, bindings.characterForEntity(first_handle));
    try std.testing.expectEqual(character_two, try bindings.characterForEntity(replacement));
}

test "binding publication keeps snapshots immutable and enabled cache transactional" {
    var bindings = try bindings_module.CharacterEntityBindings.init(std.testing.allocator);
    defer bindings.deinit();
    const handle = try bindings.createPersistent(
        try entityId('4'),
        try character.entityIdFromRaw(4),
        .{ .x = -1, .y = 2 },
    );
    var old_snapshot = try bindings.acquireSnapshot(.{
        .tick = 1,
        .fixed_delta_seconds = 1.0 / 240.0,
        .interpolation_alpha = 0,
    });
    defer old_snapshot.deinit();
    try std.testing.expect((try old_snapshot.view().get(handle)).effective_enabled);
    const generation_before = bindings.publicationGeneration();
    try bindings.setEnabled(handle, false);
    try std.testing.expect(!try bindings.isEnabled(handle));
    try std.testing.expect(bindings.publicationGeneration() > generation_before);
    try std.testing.expect((try old_snapshot.view().get(handle)).effective_enabled);

    var new_snapshot = try bindings.acquireSnapshot(.{
        .tick = 2,
        .fixed_delta_seconds = 1.0 / 240.0,
        .interpolation_alpha = 0,
    });
    defer new_snapshot.deinit();
    try std.testing.expect(!(try new_snapshot.view().get(handle)).effective_enabled);
}

test "integrated route uses F transform lifecycle snapshot and preserves identity on reset" {
    var scene = try integrated.Scene.init(std.testing.allocator, .{
        .diagnostics_each_tick = false,
        .capture_milestones = false,
    });
    defer scene.deinit();
    const original = try scene.fEntityObservation(scene.player_entity);
    try std.testing.expect(original.handle.eql(scene.player_entity));
    try std.testing.expect(original.effective_enabled);
    try std.testing.expect(original.world_position.approxEqAbs(scene.player.worldPosition(), bindings_module.root_tolerance));

    const commanded = scene.player.worldPosition().add(.{ .x = 0.25, .y = 0 });
    try scene.entity_bindings.setSceneRoot(scene.player_entity, commanded);
    try std.testing.expect(!scene.player.worldPosition().approxEqAbs(commanded, 0));
    try scene.updateFixedTicks(1);
    const moved = try scene.fEntityObservation(scene.player_entity);
    try std.testing.expect(moved.world_position.approxEqAbs(scene.player.worldPosition(), bindings_module.root_tolerance));
    try std.testing.expect(moved.entity_id.eql(original.entity_id));
    try std.testing.expect(moved.handle.eql(original.handle));

    try scene.resetCharacter(scene.player.id());
    const reset = try scene.fEntityObservation(scene.player_entity);
    try std.testing.expect(reset.entity_id.eql(original.entity_id));
    try std.testing.expect(reset.handle.eql(original.handle));
    try std.testing.expect(reset.world_position.approxEqAbs(scene.player.worldPosition(), bindings_module.root_tolerance));

    const tick_before_disable = scene.simulation_tick;
    try scene.setEntityEnabled(scene.player_entity, false);
    try scene.updateFixedTicks(8);
    try std.testing.expectEqual(tick_before_disable, scene.simulation_tick);
    try std.testing.expect(!(try scene.fEntityObservation(scene.player_entity)).effective_enabled);
    try scene.setEntityEnabled(scene.player_entity, true);
    try scene.updateFixedTicks(1);
    try std.testing.expectEqual(tick_before_disable + 1, scene.simulation_tick);

    const stale = scene.player_entity;
    try scene.destroyEntity(stale);
    try std.testing.expectError(error.CharacterBindingNotFound, scene.entity_bindings.characterForEntity(stale));
    try std.testing.expectError(error.CharacterBindingNotFound, scene.updateFixedTicks(1));
}

comptime {
    // Compile-time dependency evidence: the application mapper consumes the
    // physical type, while CharacterIntent has its own domain module/type.
    if (input.RawInputState != physical.RawInputState) @compileError("demo actions must re-export the physical input value");
    if (@sizeOf(input.CharacterIntent) == 0) @compileError("CharacterIntent must be a concrete domain command");
    _ = scene_core.runtime_scene.RuntimeScene;
}
