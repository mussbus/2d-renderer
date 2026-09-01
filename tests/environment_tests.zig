const std = @import("std");
const input = @import("input");
const art_pack = @import("art_pack");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character = @import("character");
const render_queue = @import("render_queue");
const foundation_world = @import("foundation_world");
const environment_art = @import("environment_art");
const environment_theme = @import("environment_theme");
const environment_demo = @import("environment_demo");

test "environment art pack contains both complete nearest-sampled themes" {
    var definition = try environment_art.Definition.init(std.testing.allocator);
    defer definition.deinit();
    try definition.validateComplete();
    try std.testing.expectEqual(environment_art.texture_page_count, definition.art.pages.len);
    try std.testing.expectEqual(environment_art.region_count, definition.art.regions.len);
    try std.testing.expectEqual(environment_art.binding_count, definition.art.bindings.len);
    for (definition.art.pages) |page| {
        try std.testing.expectEqual(art_pack.SamplingPolicy.nearest, page.sampling);
        try std.testing.expect(std.mem.startsWith(u8, page.asset_path.slice(), "art/environment_"));
        try std.testing.expect(std.mem.indexOf(u8, page.asset_path.slice(), "reference") == null);
        try std.testing.expectEqual(@as(u32, 1024), page.expected_width);
        try std.testing.expectEqual(@as(u32, 1024), page.expected_height);
    }
}

test "theme catalog requires both stable theme definitions and every art reference" {
    var definition = try environment_art.Definition.init(std.testing.allocator);
    defer definition.deinit();
    try std.testing.expectError(
        error.EnvironmentThemeCountMismatch,
        environment_theme.Catalog.init(
            &definition,
            environment_theme.theme_inputs[0..1],
            environment_theme.environment_renderer_offset,
        ),
    );
    const duplicates = [_]environment_theme.ThemeInput{
        environment_theme.theme_inputs[0],
        environment_theme.theme_inputs[0],
    };
    try std.testing.expectError(
        error.DuplicateEnvironmentTheme,
        environment_theme.Catalog.init(
            &definition,
            &duplicates,
            environment_theme.environment_renderer_offset,
        ),
    );

    const incomplete_input = art_pack.DefinitionInput{
        .stable_name = "prompt26_missing_binding_fixture",
        .pages = &environment_art.page_inputs,
        .regions = &environment_art.region_inputs,
        .bindings = environment_art.binding_inputs[0 .. environment_art.binding_count - 1],
    };
    var incomplete = environment_art.Definition{
        .art = try art_pack.Definition.init(std.testing.allocator, incomplete_input),
    };
    defer incomplete.deinit();
    try std.testing.expectError(
        error.MissingVisualBinding,
        environment_theme.Catalog.init(
            &incomplete,
            &environment_theme.theme_inputs,
            environment_theme.environment_renderer_offset,
        ),
    );
}

test "theme data owns presentation only and contains no collision spawn or interaction coordinates" {
    try std.testing.expect(!@hasField(environment_theme.ThemeInput, "colliders"));
    try std.testing.expect(!@hasField(environment_theme.ThemeInput, "collision"));
    try std.testing.expect(!@hasField(environment_theme.ThemeInput, "spawn"));
    try std.testing.expect(!@hasField(environment_theme.ThemeInput, "interaction"));
    try std.testing.expectEqual(
        foundation_world.player_spawn.y,
        environment_demo.interaction_position.y,
    );
}

test "standable surface overlay is an exact collision-authority projection" {
    const inputs = foundation_world.colliderInputs();
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &inputs, null);
    defer world.deinit();
    const overlay = try environment_theme.SurfaceOverlay.init(&world);
    try std.testing.expectEqual(environment_theme.expected_standable_surface_count, overlay.count);
    var expected_index: usize = 0;
    for (world.colliders) |static_collider| {
        if (!static_collider.solid or !static_collider.ground_query_eligible) continue;
        const segment = overlay.slice()[expected_index];
        try std.testing.expectEqual(static_collider.id, segment.collider_id);
        try std.testing.expectEqual(static_collider.bounds.minimum.x, segment.minimum_x);
        try std.testing.expectEqual(static_collider.bounds.maximum.x, segment.maximum_x);
        try std.testing.expectEqual(static_collider.bounds.maximum.y, segment.y);
        expected_index += 1;
    }
    try std.testing.expectEqual(overlay.count, expected_index);
    try overlay.validateAgainst(&world);
}

test "walls ceilings and decoration never acquire standable white edges" {
    const inputs = [_]collider.StaticColliderInput{
        .{
            .id = 1,
            .bounds = .{ .minimum = .{ .x = -2, .y = -1 }, .maximum = .{ .x = 2, .y = 0 } },
            .solid = true,
            .ground_query_eligible = true,
        },
        .{
            .id = 2,
            .bounds = .{ .minimum = .{ .x = 2, .y = 0 }, .maximum = .{ .x = 2.4, .y = 5 } },
            .solid = true,
            .ground_query_eligible = false,
        },
        .{
            .id = 3,
            .bounds = .{ .minimum = .{ .x = -2, .y = 5 }, .maximum = .{ .x = 2, .y = 5.4 } },
            .solid = true,
            .ground_query_eligible = false,
        },
    };
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &inputs, null);
    defer world.deinit();
    const overlay = try environment_theme.SurfaceOverlay.init(&world);
    try std.testing.expectEqual(@as(usize, 1), overlay.count);
    try std.testing.expectEqual(@as(collider.ColliderId, 1), overlay.slice()[0].collider_id);
}

test "hot swapping changes only presentation theme and performs no allocation" {
    var storage: [2_500_000]u8 align(@alignOf(u64)) = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(&storage);
    var scene = try environment_demo.Scene.init(allocator.allocator());
    defer scene.deinit();
    const before = scene.gameplaySnapshot();
    const allocation_checkpoint = allocator.end_index;
    for (0..1000) |_| try scene.cycleThemePreservingState();
    try std.testing.expectEqual(allocation_checkpoint, allocator.end_index);
    try std.testing.expect(std.meta.eql(before, scene.gameplaySnapshot()));
    try std.testing.expectEqual(@as(u32, 1000), scene.environment.switch_count);
    try std.testing.expectEqual(environment_art.ThemeId.violet_crystal_ruin, scene.environment.active_theme);
}

test "theme switching preserves collision spawn view outfit clock input and interaction state" {
    var scene = try environment_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    scene.production.pending_input.jump_pressed_pending = true;
    const before = scene.gameplaySnapshot();
    try scene.cycleThemePreservingState();
    const after = scene.gameplaySnapshot();
    try std.testing.expect(std.meta.eql(before, after));
    try std.testing.expectEqual(@as(u8, 1), scene.production.pending_input.pendingEdgeCount());
    try std.testing.expectEqual(environment_art.ThemeId.neutral_debug, scene.environment.active_theme);
}

test "both themes share one world fingerprint and one derived surface fingerprint" {
    var scene = try environment_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const world_before = environment_theme.collisionFingerprint(&scene.production.world);
    const surfaces_before = scene.environment.surfaces.fingerprint();
    try scene.cycleThemePreservingState();
    try std.testing.expectEqual(world_before, environment_theme.collisionFingerprint(&scene.production.world));
    try std.testing.expectEqual(surfaces_before, scene.environment.surfaces.fingerprint());
}

test "environment submission orders terrain then white surfaces then characters and debug" {
    var scene = try environment_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    scene.detailed_debug_enabled = true;
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        environment_demo.configured_texture_page_count,
    );
    defer queue.deinit();
    queue.beginFrame();
    _ = try scene.submit(&queue);
    const prepared = queue.prepare();
    var surface_count: usize = 0;
    var terrain_observed = false;
    var character_observed = false;
    var debug_observed = false;
    for (prepared.sprites) |sprite| {
        if (sprite.order.scene_layer == environment_theme.surface_scene_layer) {
            surface_count += 1;
            try std.testing.expectEqual(@as(u32, 7), sprite.texture_page);
        }
        terrain_observed = terrain_observed or
            sprite.order.scene_layer == character.SceneLayers.world;
        character_observed = character_observed or
            sprite.order.scene_layer == character.SceneLayers.characters;
        debug_observed = debug_observed or
            sprite.order.scene_layer == character.SceneLayers.debug_overlay;
    }
    try std.testing.expectEqual(scene.environment.surfaces.count, surface_count);
    try std.testing.expect(terrain_observed);
    try std.testing.expect(character_observed);
    try std.testing.expect(debug_observed);
    try std.testing.expect(
        character.SceneLayers.world < environment_theme.surface_scene_layer and
            environment_theme.surface_scene_layer < character.SceneLayers.characters and
            character.SceneLayers.characters < character.SceneLayers.debug_overlay,
    );
}

test "theme selection changes preloaded page identity without GPU or file ownership" {
    var definition = try environment_art.Definition.init(std.testing.allocator);
    defer definition.deinit();
    const catalog = try environment_theme.Catalog.init(
        &definition,
        &environment_theme.theme_inputs,
        environment_theme.environment_renderer_offset,
    );
    const violet = catalog.theme(.violet_crystal_ruin).visual(.far_backdrop);
    const debug = catalog.theme(.neutral_debug).visual(.far_backdrop);
    try std.testing.expectEqual(@as(u32, 7), violet.texture_page);
    try std.testing.expectEqual(@as(u32, 8), debug.texture_page);
    try std.testing.expect(violet.texture_page != debug.texture_page);
    try std.testing.expect(!@hasField(environment_theme.Presentation, "gpu_texture"));
    try std.testing.expect(!@hasField(environment_theme.Presentation, "asset_path"));
}

test "reset returns the visual theme to violet without changing world authority" {
    var scene = try environment_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const world_fingerprint = environment_theme.collisionFingerprint(&scene.production.world);
    try scene.cycleThemePreservingState();
    scene.environment.reset();
    try std.testing.expectEqual(environment_art.ThemeId.violet_crystal_ruin, scene.environment.active_theme);
    try std.testing.expectEqual(world_fingerprint, environment_theme.collisionFingerprint(&scene.production.world));
}

test "T key creates one deterministic theme-cycle edge and survives focus filtering" {
    var builder = input.SnapshotBuilder{};
    const pressed = try builder.update(.{ .keyboard = .{ .t = true } });
    try std.testing.expect(pressed.environment_theme_cycle.pressed);
    try std.testing.expect(pressed.environment_theme_cycle.held);
    const held = try builder.update(.{ .keyboard = .{ .t = true } });
    try std.testing.expect(!held.environment_theme_cycle.pressed);
    const released = try builder.update(.{});
    try std.testing.expect(released.environment_theme_cycle.released);

    _ = try builder.update(.{
        .keyboard = .{ .t = true },
        .keyboard_focused = false,
        .focus_lost = true,
    });
    const blocked = try builder.update(.{ .keyboard = .{ .t = true } });
    try std.testing.expect(!blocked.environment_theme_cycle.pressed);
}

test "scripted Prompt 26 matrix proves front side parallax swap raised-platform landing reset resize and stability" {
    var storage: [3_000_000]u8 align(@alignOf(u64)) = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(&storage);
    var scene = try environment_demo.Scene.init(allocator.allocator());
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        allocator.allocator(),
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        environment_demo.configured_texture_page_count,
    );
    defer queue.deinit();
    var sequence = environment_demo.ScriptedInput{};
    var builder = input.SnapshotBuilder{};
    const allocation_checkpoint = allocator.end_index;
    for (0..environment_demo.required_frames) |frame| {
        const snapshot = try builder.update(sequence.nextRaw());
        try scene.updateFrame(1.0 / 60.0, snapshot);
        if (frame == 280) try scene.applyViewport(960, 540);
        if (frame == 281) try scene.applyViewport(640, 480);
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
    }
    try scene.validateComplete();
    try std.testing.expectEqual(allocation_checkpoint, allocator.end_index);
    try std.testing.expectEqual(@as(u64, environment_demo.required_frames * 4), scene.production.simulation_tick);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}
