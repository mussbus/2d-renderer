const std = @import("std");
const input = @import("input");
const equipment = @import("equipment");
const humanoid = @import("humanoid");
const modular_body_demo = @import("modular_body_demo");
const wardrobe_catalog = @import("wardrobe_catalog");
const wardrobe_art = @import("wardrobe_art");
const wardrobe_presentation = @import("wardrobe_presentation");
const wardrobe_demo = @import("wardrobe_demo");
const render_queue = @import("render_queue");

const expected_item_names = [_][]const u8{
    "crimson_wide_brim_hat",
    "moon_ear_headband",
    "ember_crescent_headband",
    "rose_pillbox_hat",
    "crimson_halter_top",
    "garnet_wrap_bodice",
    "scarlet_sport_top",
    "rose_romper",
    "crimson_cardigan",
    "ivory_blouse",
    "ruby_day_dress",
    "crimson_strap_shoes",
    "velvet_puff_blouse",
    "crimson_one_shoulder_top",
    "ruby_fitted_suit",
    "ribbon_bodice",
    "crimson_long_gloves",
    "ivory_wrist_cuffs",
    "ribbon_waist_sash",
    "ebony_waist_belt",
    "crimson_tailored_shorts",
    "scarlet_sport_shorts",
    "velvet_mini_skirt",
    "crimson_highwaist_pants",
    "ruby_fitted_pants",
    "ivory_side_laced_shorts",
    "garnet_split_skirt",
    "crimson_thigh_high",
    "rose_mesh_legwear",
    "ember_pattern_legwear",
};

test "Prompt 25 wardrobe definitions initialize with complete side and front bindings" {
    var humanoid_definition = try modular_body_demo.initDefinition(std.testing.allocator);
    defer humanoid_definition.deinit();
    var catalog = try wardrobe_catalog.Catalog.init(
        std.testing.allocator,
        &humanoid_definition,
    );
    defer catalog.deinit();
    var art = try wardrobe_art.Definition.init(std.testing.allocator);
    defer art.deinit();
    var presentation = try wardrobe_presentation.Presentation.init(
        std.testing.allocator,
        &art,
        &catalog,
        3,
    );
    defer presentation.deinit();

    try catalog.validate();
    try art.validateCatalog(&catalog);
    try presentation.validateCompleteness(&catalog);
    try std.testing.expectEqual(wardrobe_catalog.visual_count, art.art.regions.len / 2);
    try std.testing.expectEqual(wardrobe_catalog.preset_count, catalog.presets.len);
}

test "all production IDs resolve and every component has deterministic distinct view art" {
    var humanoid_definition = try modular_body_demo.initDefinition(std.testing.allocator);
    defer humanoid_definition.deinit();
    var catalog = try wardrobe_catalog.Catalog.init(std.testing.allocator, &humanoid_definition);
    defer catalog.deinit();
    var art = try wardrobe_art.Definition.init(std.testing.allocator);
    defer art.deinit();

    try std.testing.expectEqual(expected_item_names.len, catalog.equipment_definition.items.len);
    for (expected_item_names, 0..) |stable_id, expected_index| {
        const item_id = try catalog.equipment_definition.itemId(stable_id);
        try std.testing.expectEqual(expected_index, item_id.index());
    }
    for (wardrobe_catalog.visual_specs, 0..) |spec, expected_index| {
        const component_id = try catalog.equipment_definition.visualComponentId(spec.stable_id);
        const component = catalog.equipment_definition.visual_components[component_id.index()];
        try std.testing.expectEqual(expected_index, component_id.index());
        try std.testing.expectEqual(spec.semantic, component.presentation_semantic.?);

        const side = try art.resolve(spec.semantic, false);
        const front = try art.resolve(spec.semantic, true);
        const side_again = try art.resolve(spec.semantic, false);
        try std.testing.expectEqual(side.region_id, side_again.region_id);
        try std.testing.expectEqual(side.uv_rect, side_again.uv_rect);
        try std.testing.expectEqual(side.semantic_id, front.semantic_id);
        try std.testing.expect(side.region_id != front.region_id);
    }
    for (catalog.presets, 0..) |preset, expected_index| {
        try std.testing.expectEqual(expected_index, preset.id.index());
        try std.testing.expectEqual(preset.id, try catalog.presetId(preset.stable_id));
    }
}

test "Prompt 25A wardrobe regions are nonzero bounded and alpha-tight where required" {
    for (wardrobe_art.region_inputs) |region| {
        const page = for (wardrobe_art.page_inputs) |candidate| {
            if (candidate.id == region.page_id) break candidate;
        } else return error.MissingWardrobeRegionPage;
        try std.testing.expect(region.source.width > 0);
        try std.testing.expect(region.source.height > 0);
        try std.testing.expect(region.source.x + region.source.width <= page.expected_width);
        try std.testing.expect(region.source.y + region.source.height <= page.expected_height);
        try std.testing.expect(region.authored_size[0] > 0);
        try std.testing.expect(region.authored_size[1] > 0);
        try std.testing.expect(region.pivot[0] >= 0 and region.pivot[0] <= 1);
        try std.testing.expect(region.pivot[1] >= 0 and region.pivot[1] <= 1);
    }

    const shoe_side = try wardrobeRegion("crimson_strap_shoe_side");
    const shoe_front = try wardrobeRegion("crimson_strap_shoe_front");
    const sleeve_front = try wardrobeRegion("ivory_blouse_sleeve_front");
    // These exact rectangles are the audited alpha bounds with two pixels of
    // safety padding. They prevent a return to whole-cell transparent padding.
    try std.testing.expectEqual(@as(u32, 186), shoe_side.source.width);
    try std.testing.expectEqual(@as(u32, 124), shoe_side.source.height);
    try std.testing.expectEqual(@as(u32, 172), shoe_front.source.width);
    try std.testing.expectEqual(@as(u32, 151), shoe_front.source.height);
    try std.testing.expectEqual(@as(u32, 120), sleeve_front.source.width);
    try std.testing.expectEqual(@as(u32, 205), sleeve_front.source.height);
}

test "Prompt 25A side anatomy submission geometry remains registered at joints" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        128,
        120,
        8,
        wardrobe_demo.combined_art_page_count + 1,
    );
    defer queue.deinit();

    for ([_]humanoid.Facing{ .left, .right }) |facing| {
        try scene.male.setFacing(facing);
        try scene.male.setPresentationOverride(.force_side);
        queue.beginFrame();
        _ = try scene.male_art.submit(&scene.male, &queue);

        const thigh_key = scene.male.last_submitted_keys[
            @intFromEnum(humanoid.AttachmentSemantic.left_thigh)
        ].?;
        const shin_key = scene.male.last_submitted_keys[
            @intFromEnum(humanoid.AttachmentSemantic.left_shin)
        ].?;
        const foot_key = scene.male.last_submitted_keys[
            @intFromEnum(humanoid.AttachmentSemantic.left_foot)
        ].?;
        const upper_key = scene.male.last_submitted_keys[
            @intFromEnum(humanoid.AttachmentSemantic.left_upper_arm)
        ].?;
        const forearm_key = scene.male.last_submitted_keys[
            @intFromEnum(humanoid.AttachmentSemantic.left_forearm)
        ].?;
        const hand_key = scene.male.last_submitted_keys[
            @intFromEnum(humanoid.AttachmentSemantic.left_hand)
        ].?;
        const thigh = queue.sprite_submissions[@intCast(thigh_key.submission_index)];
        const shin = queue.sprite_submissions[@intCast(shin_key.submission_index)];
        const foot = queue.sprite_submissions[@intCast(foot_key.submission_index)];
        const upper = queue.sprite_submissions[@intCast(upper_key.submission_index)];
        const forearm = queue.sprite_submissions[@intCast(forearm_key.submission_index)];
        const hand = queue.sprite_submissions[@intCast(hand_key.submission_index)];

        // 0.09 m is tighter than a normal-scale pixel at the 82 px/m
        // acceptance camera and is below every authored limb thickness. It
        // proves the child anchor remains inside the parent's overlap cap.
        const joint_tolerance: f32 = 0.09;
        try std.testing.expect(pointDistance(
            submissionPoint(thigh, .{ 0.5, 0 }),
            shin.world_position,
        ) <= joint_tolerance);
        try std.testing.expect(pointDistance(
            submissionPoint(shin, .{ 0.5, 0 }),
            foot.world_position,
        ) <= joint_tolerance);
        try std.testing.expect(pointDistance(
            submissionPoint(upper, .{ 1, 0.5 }),
            forearm.world_position,
        ) <= joint_tolerance);
        try std.testing.expect(pointDistance(
            submissionPoint(forearm, .{ 1, 0.5 }),
            hand.world_position,
        ) <= joint_tolerance);
    }
}

test "Prompt 25A front anatomy geometry overlaps every core limb joint" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        128,
        120,
        8,
        wardrobe_demo.combined_art_page_count + 1,
    );
    defer queue.deinit();

    try expectFrontJointRegistration(&scene.male, scene.male_art, &queue);
    try expectFrontJointRegistration(&scene.female, scene.female_art, &queue);
}

test "Prompt 25A wardrobe pivots match semantic anchor ends" {
    const sleeve = try visualSpec("ivory_blouse_sleeve");
    const glove = try visualSpec("crimson_long_glove");
    const cuff = try visualSpec("ivory_wrist_cuff");
    const legwear = try visualSpec("crimson_thigh_high");
    const shoe = try visualSpec("crimson_strap_shoe");
    try std.testing.expectApproxEqAbs(@as(f32, 0.90), sleeve.pivot[1], 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.12), glove.pivot[1], 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.20), cuff.pivot[1], 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.08), legwear.pivot[1], 0.000001);
    // Semantic footwear binds at the canonical toe point, so its horizontal
    // pivot is placed at the authored toe while the vertical pivot follows
    // the sole. The 1e-6 tolerance is exact enough for authored constants.
    try std.testing.expectApproxEqAbs(@as(f32, 0.95), shoe.pivot[0], 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), shoe.pivot[1], 0.000001);

    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const definition = scene.catalog.equipment_definition.view();
    const shoes = try definition.item(try definition.itemId("crimson_strap_shoes"));
    try std.testing.expectEqual(@as(u16, 1), shoes.visual_recipe_count);
    const recipe = definition.visual_recipes[shoes.visual_recipe_start];
    try std.testing.expectApproxEqAbs(
        wardrobe_catalog.footwear_ankle_offset_metres,
        recipe.local_to_binding.translation.x,
        0.000001,
    );
    try std.testing.expectApproxEqAbs(
        @as(f32, 0),
        recipe.local_to_binding.translation.y,
        0.000001,
    );
}

test "Prompt 25A acceptance schedule is deterministic and allocation free" {
    var storage: [4 * 1024 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var scene = try wardrobe_demo.Scene.init(fixed.allocator());
    defer scene.deinit();
    try scene.enableVisualQualityAcceptance();
    var queue = try render_queue.UnifiedRenderQueue.init(
        fixed.allocator(),
        256,
        224,
        32,
        wardrobe_demo.combined_art_page_count + 1,
    );
    defer queue.deinit();
    queue.markStabilized();
    const allocation_checkpoint = fixed.end_index;

    var frame: u32 = 0;
    while (frame < wardrobe_demo.visual_quality_required_frames) : (frame += 1) {
        try scene.updateVisualQualityFrame();
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
    }
    try scene.validateVisualQualityComplete();
    try std.testing.expectEqual(allocation_checkpoint, fixed.end_index);
    try std.testing.expectEqual(
        @as(u64, 0),
        queue.lifetime_metrics.cpu_allocations_after_stabilization,
    );
}

test "presets are cosmetic conflict-free recipes with reuse and a non-monolithic custom outfit" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();

    for (scene.catalog.equipment_definition.items) |item| {
        try std.testing.expectEqual(@as(u16, 0), item.modifier_count);
        try std.testing.expectEqual(@as(u16, 0), item.capability_count);
    }
    try std.testing.expectEqual(
        @as(usize, 0),
        scene.catalog.equipment_definition.attributes.len,
    );
    try std.testing.expectEqual(
        @as(usize, 0),
        scene.catalog.equipment_definition.capabilities.len,
    );

    for (scene.catalog.presets) |preset| {
        for (preset.items(), 0..) |item_id, item_index| {
            for (preset.items()[0..item_index]) |prior| {
                try std.testing.expect(item_id != prior);
            }
        }
        try scene.selectPreset(preset.id);
        try std.testing.expectEqual(preset.items().len, scene.female.equipment_loadout.?.equippedItems().len);
    }

    const tailored = try scene.catalog.equipment_definition.itemId("crimson_tailored_shorts");
    const shoes = try scene.catalog.equipment_definition.itemId("crimson_strap_shoes");
    try std.testing.expect(presetReferenceCount(&scene.catalog, tailored) >= 5);
    try std.testing.expect(presetReferenceCount(&scene.catalog, shoes) >= 10);

    const custom = try scene.catalog.customItems();
    for (custom, 0..) |item_id, item_index| {
        for (custom[0..item_index]) |prior| try std.testing.expect(item_id != prior);
        var found_in_preset = false;
        for (scene.catalog.presets) |preset| {
            for (preset.items()) |preset_item| {
                if (preset_item == item_id) found_in_preset = true;
            }
        }
        try std.testing.expect(found_in_preset);
    }
    try scene.selectCustom();
    try std.testing.expectEqual(custom.len, scene.female.equipment_loadout.?.equippedItems().len);
}

test "repeated sleeves follow two and four arm topology while headwear preserves long hair" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    const blouse = try scene.catalog.equipment_definition.itemId("ivory_blouse");
    const sleeve = try scene.catalog.equipment_definition.visualComponentId("ivory_blouse_sleeve");
    const hat = try scene.catalog.equipment_definition.itemId("crimson_wide_brim_hat");

    try scene.female.selectEquipmentItems(&.{blouse});
    try std.testing.expectEqual(@as(u16, 2), countComponentVisuals(
        &scene.female.equipment_loadout.?,
        sleeve,
    ));
    try scene.female.selectBodyPreset(
        try anatomy_definition.bodyPresetId("nonstandard_humanoid"),
    );
    try std.testing.expectEqual(@as(u16, 4), countComponentVisuals(
        &scene.female.equipment_loadout.?,
        sleeve,
    ));
    try scene.female.selectBodyPreset(
        try anatomy_definition.bodyPresetId("conventional_female"),
    );
    const expected_hair = try anatomy_definition.hairDefinitionId("long_rigid");
    try scene.female.selectEquipmentItems(&.{hat});
    try std.testing.expectEqual(
        expected_hair,
        scene.female.character.anatomy_runtime.?.selected_hair.?,
    );
    try std.testing.expectEqual(@as(usize, 1), scene.female.equipment_loadout.?.equippedItems().len);
}

test "occupancy layering coverage and semantic foot binding remain independent" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const definition = scene.catalog.equipment_definition.view();

    const blouse_id = try definition.itemId("ivory_blouse");
    const cardigan_id = try definition.itemId("crimson_cardigan");
    const blouse = try definition.item(blouse_id);
    const cardigan = try definition.item(cardigan_id);
    try std.testing.expectEqual(@as(u16, 2), blouse.occupied_slot_count);
    try std.testing.expectEqual(@as(u16, 2), blouse.visual_recipe_count);
    try std.testing.expectEqual(@as(u16, 3), blouse.coverage_count);
    try std.testing.expectEqual(@as(u16, 2), cardigan.occupied_slot_count);
    try std.testing.expectEqual(@as(u16, 2), cardigan.visual_recipe_count);
    try std.testing.expectEqual(@as(u16, 3), cardigan.coverage_count);

    const blouse_recipes = definition.visual_recipes[blouse.visual_recipe_start .. blouse.visual_recipe_start + blouse.visual_recipe_count];
    const cardigan_recipes = definition.visual_recipes[cardigan.visual_recipe_start .. cardigan.visual_recipe_start + cardigan.visual_recipe_count];
    try std.testing.expectEqualStrings(
        "upper",
        definition.visual_layers[blouse_recipes[0].visual_layer.index()].stable_id.slice(),
    );
    try std.testing.expectEqualStrings(
        "sleeves",
        definition.visual_layers[blouse_recipes[1].visual_layer.index()].stable_id.slice(),
    );
    try std.testing.expectEqualStrings(
        "upper_outer",
        definition.visual_layers[cardigan_recipes[0].visual_layer.index()].stable_id.slice(),
    );
    try std.testing.expectEqualStrings(
        "sleeves_outer",
        definition.visual_layers[cardigan_recipes[1].visual_layer.index()].stable_id.slice(),
    );
    try scene.female.selectEquipmentItems(&.{ blouse_id, cardigan_id });
    try std.testing.expectEqual(@as(usize, 2), scene.female.equipment_loadout.?.equippedItems().len);

    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    const left_foot = try anatomy_definition.partInstanceId("left_foot");
    const right_foot = try anatomy_definition.partInstanceId("right_foot");
    const left_before = try scene.female.character.anatomy_runtime.?.partBindingWorld(
        anatomy_definition,
        left_foot,
    );
    const right_before = try scene.female.character.anatomy_runtime.?.partBindingWorld(
        anatomy_definition,
        right_foot,
    );
    const shoes = try definition.itemId("crimson_strap_shoes");
    try scene.female.selectEquipmentItems(&.{shoes});
    var found_left = false;
    var found_right = false;
    for (scene.female.equipment_loadout.?.visuals()) |visual| {
        switch (visual.source) {
            .anatomy_part => |part_id| {
                found_left = found_left or part_id == left_foot;
                found_right = found_right or part_id == right_foot;
            },
            .attachment_point => return error.FootwearDidNotBindToSemanticFoot,
        }
    }
    try std.testing.expect(found_left and found_right);
    try std.testing.expect(left_before.approxEqAbs(
        try scene.female.character.anatomy_runtime.?.partBindingWorld(
            anatomy_definition,
            left_foot,
        ),
        0.000001,
    ));
    try std.testing.expect(right_before.approxEqAbs(
        try scene.female.character.anatomy_runtime.?.partBindingWorld(
            anatomy_definition,
            right_foot,
        ),
        0.000001,
    ));
}

test "preset selection is transactional and preserves non-equipment character state" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    try scene.female.setPresentationOverride(.force_side);
    try scene.female.setFacing(.right);

    const body_before = scene.female.character.anatomy_runtime.?.selected_body_preset;
    const hair_before = scene.female.character.anatomy_runtime.?.selected_hair;
    const world_before = scene.female.world_position;
    const facing_before = scene.female.facing;
    const view_before = scene.female.presentationView();
    const override_before = scene.female.presentationOverride();
    const animation_before = scene.female.animationState();
    const controller_before = scene.female.controller.?.state;

    try scene.selectPreset(try scene.catalog.presetId("ivory_blouse_red_shorts"));
    try std.testing.expectEqual(body_before, scene.female.character.anatomy_runtime.?.selected_body_preset);
    try std.testing.expectEqual(hair_before, scene.female.character.anatomy_runtime.?.selected_hair);
    try std.testing.expect(world_before.approxEqAbs(scene.female.world_position, 0.000001));
    try std.testing.expectEqual(facing_before, scene.female.facing);
    try std.testing.expectEqual(view_before, scene.female.presentationView());
    try std.testing.expectEqual(override_before, scene.female.presentationOverride());
    try std.testing.expectEqual(animation_before, scene.female.animationState());
    try expectControllerStateEqual(controller_before, scene.female.controller.?.state);

    const fingerprint_before = loadoutFingerprint(&scene.female.equipment_loadout.?);
    const tailored = try scene.catalog.equipment_definition.itemId("crimson_tailored_shorts");
    const sport = try scene.catalog.equipment_definition.itemId("scarlet_sport_shorts");
    try std.testing.expectError(
        error.EquipmentSlotOccupied,
        scene.female.selectEquipmentItems(&.{ tailored, sport }),
    );
    try std.testing.expectEqual(
        fingerprint_before,
        loadoutFingerprint(&scene.female.equipment_loadout.?),
    );
    try std.testing.expect(scene.male.equipment_loadout == null);
}

test "long garment mesh and secondary state clear on replacement and reset returns empty default" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        256,
        224,
        32,
        6,
    );
    defer queue.deinit();
    try scene.selectPreset(try scene.catalog.presetId("garnet_formal"));
    for (0..8) |_| {
        try scene.female.advanceVisualTick(.{
            .horizontal_velocity = 2.0,
            .physically_grounded = true,
        });
    }
    queue.beginFrame();
    _ = try scene.submit(&queue);
    _ = queue.prepare();

    var long_state_observed = false;
    for (scene.female.equipment_loadout.?.visuals()) |visual| {
        const component = try componentForVisual(&scene.female.equipment_loadout.?, visual);
        if (component.presentation_semantic != null and
            @intFromEnum(component.presentation_semantic.?) == 25_032)
        {
            try std.testing.expect(visual.secondary.initialized);
            try std.testing.expect(visual.secondary.fixed_ticks > 0);
            try std.testing.expect(visual.mesh_state.update_serial > 0);
            long_state_observed = true;
        }
    }
    try std.testing.expect(long_state_observed);

    try scene.selectPreset(try scene.catalog.presetId("scarlet_sport"));
    for (scene.female.equipment_loadout.?.visuals()) |visual| {
        try std.testing.expect(!visual.secondary.initialized);
        try std.testing.expectEqual(@as(u64, 0), visual.mesh_state.update_serial);
    }
    try scene.female.resetControlled(&scene.world);
    try std.testing.expectEqual(
        @as(usize, 0),
        scene.female.equipment_loadout.?.equippedItems().len,
    );
    try std.testing.expectEqual(
        @as(usize, 0),
        scene.female.equipment_loadout.?.visuals().len,
    );
}

test "front and side preset cycling and submission allocate nothing after initialization" {
    const backing = try std.testing.allocator.alloc(u8, 2 * 1024 * 1024);
    defer std.testing.allocator.free(backing);
    var fixed = std.heap.FixedBufferAllocator.init(backing);
    var scene = try wardrobe_demo.Scene.init(fixed.allocator());
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        fixed.allocator(),
        256,
        224,
        32,
        6,
    );
    defer queue.deinit();
    queue.markStabilized();
    const allocation_checkpoint = fixed.end_index;

    for (scene.catalog.presets) |preset| {
        try scene.selectPreset(preset.id);
        for ([_]@import("presentation_view").DebugOverride{
            .force_front,
            .force_side,
        }) |view_override| {
            try scene.female.setPresentationOverride(view_override);
            queue.beginFrame();
            const submitted = try scene.submit(&queue);
            const prepared = queue.prepare();
            try std.testing.expectEqual(
                @as(usize, submitted),
                prepared.sprites.len + prepared.meshes.len,
            );
            try std.testing.expect(
                submitted > scene.female.equipment_loadout.?.visuals().len,
            );
            try std.testing.expect(prepared.ranges.len > 0);
        }
    }
    try scene.selectCustom();
    queue.beginFrame();
    _ = try scene.submit(&queue);
    _ = queue.prepare();

    try std.testing.expectEqual(allocation_checkpoint, fixed.end_index);
    try std.testing.expectEqual(
        @as(u64, 0),
        queue.lifetime_metrics.cpu_allocations_after_stabilization,
    );
}

test "O and P controls produce focus-safe outfit-cycle and pause edges" {
    var builder = input.SnapshotBuilder{};
    const pressed = try builder.update(.{ .keyboard = .{ .o = true, .p = true } });
    try std.testing.expect(pressed.outfit_cycle.pressed);
    try std.testing.expect(pressed.pause_toggle.pressed);
    const held = try builder.update(.{ .keyboard = .{ .o = true, .p = true } });
    try std.testing.expect(!held.outfit_cycle.pressed);
    try std.testing.expect(!held.pause_toggle.pressed);
    const lost = try builder.update(.{
        .keyboard = .{ .o = true, .p = true },
        .keyboard_focused = false,
        .focus_lost = true,
    });
    try std.testing.expect(!lost.outfit_cycle.pressed);
    try std.testing.expect(!lost.pause_toggle.pressed);
    const refocused_held = try builder.update(.{
        .keyboard = .{ .o = true, .p = true },
        .keyboard_focused = true,
    });
    try std.testing.expect(!refocused_held.outfit_cycle.pressed);
    try std.testing.expect(!refocused_held.pause_toggle.pressed);
}

test "Prompt 25 scene composes base anatomy and wardrobe through one bounded queue" {
    var scene = try wardrobe_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        256,
        224,
        32,
        6,
    );
    defer queue.deinit();

    try scene.updateScriptedFrame();
    queue.beginFrame();
    const submitted = try scene.submit(&queue);
    const prepared = queue.prepare();
    try std.testing.expect(submitted > 46);
    try std.testing.expect(prepared.sprites.len > 46);
    try std.testing.expectEqual(@as(usize, 0), prepared.meshes.len);
}

fn presetReferenceCount(
    catalog: *const wardrobe_catalog.Catalog,
    item_id: equipment.EquipmentItemId,
) usize {
    var count: usize = 0;
    for (catalog.presets) |preset| {
        for (preset.items()) |candidate| count += @intFromBool(candidate == item_id);
    }
    return count;
}

fn visualSpec(stable_id: []const u8) !wardrobe_catalog.VisualSpec {
    for (wardrobe_catalog.visual_specs) |spec| {
        if (std.mem.eql(u8, stable_id, spec.stable_id)) return spec;
    }
    return error.MissingWardrobeVisualSpec;
}

fn wardrobeRegion(stable_id: []const u8) !@TypeOf(wardrobe_art.region_inputs[0]) {
    for (wardrobe_art.region_inputs) |region| {
        if (std.mem.eql(u8, stable_id, region.stable_name)) return region;
    }
    return error.MissingWardrobeRegion;
}

fn expectFrontJointRegistration(
    instance: anytype,
    presentation: anytype,
    queue: *render_queue.UnifiedRenderQueue,
) !void {
    try instance.setPresentationOverride(.force_front);
    queue.beginFrame();
    _ = try presentation.submit(instance, queue);

    const pairs = [_]struct {
        parent: humanoid.AttachmentSemantic,
        child: humanoid.AttachmentSemantic,
        parent_end: [2]f32,
    }{
        .{ .parent = .left_upper_arm, .child = .left_forearm, .parent_end = .{ 0.5, 0 } },
        .{ .parent = .left_forearm, .child = .left_hand, .parent_end = .{ 0.5, 0 } },
        .{ .parent = .right_upper_arm, .child = .right_forearm, .parent_end = .{ 0.5, 0 } },
        .{ .parent = .right_forearm, .child = .right_hand, .parent_end = .{ 0.5, 0 } },
        .{ .parent = .left_thigh, .child = .left_shin, .parent_end = .{ 0.5, 0 } },
        .{ .parent = .left_shin, .child = .left_foot, .parent_end = .{ 0.5, 0 } },
        .{ .parent = .right_thigh, .child = .right_shin, .parent_end = .{ 0.5, 0 } },
        .{ .parent = .right_shin, .child = .right_foot, .parent_end = .{ 0.5, 0 } },
    };
    // The 0.78 m upper-arm quad intentionally extends 0.13 m beyond the
    // 0.65 m semantic joint. Maximum production morphology scales that
    // extension to 0.1612 m; 0.17 m leaves 0.0088 m for float composition.
    const joint_tolerance: f32 = 0.17;
    for (pairs) |pair| {
        const parent_key = instance.last_submitted_keys[@intFromEnum(pair.parent)].?;
        const child_key = instance.last_submitted_keys[@intFromEnum(pair.child)].?;
        const parent = queue.sprite_submissions[@intCast(parent_key.submission_index)];
        const child = queue.sprite_submissions[@intCast(child_key.submission_index)];
        const distance = pointDistance(
            submissionPoint(parent, pair.parent_end),
            child.world_position,
        );
        try std.testing.expect(distance <= joint_tolerance);
    }
}

fn countComponentVisuals(
    loadout: *const equipment.Loadout,
    component_id: equipment.VisualComponentId,
) u16 {
    var count: u16 = 0;
    for (loadout.visuals()) |visual| {
        const recipe = loadout.definition.recipe(visual.recipe) catch continue;
        count += @intFromBool(recipe.component == component_id);
    }
    return count;
}

fn submissionPoint(submission: anytype, local: [2]f32) [2]f32 {
    const x = (local[0] - submission.pivot[0]) * submission.scale[0];
    const y = (local[1] - submission.pivot[1]) * submission.scale[1];
    const cosine = @cos(submission.rotation);
    const sine = @sin(submission.rotation);
    return .{
        cosine * x - sine * y + submission.world_position[0],
        sine * x + cosine * y + submission.world_position[1],
    };
}

fn pointDistance(left: [2]f32, right: [2]f32) f32 {
    const x = left[0] - right[0];
    const y = left[1] - right[1];
    return @sqrt(x * x + y * y);
}

fn loadoutFingerprint(loadout: *const equipment.Loadout) u64 {
    var hash: u64 = 14695981039346656037;
    for (loadout.equippedItems()) |item_id| {
        hash = (hash ^ @as(u64, @intFromEnum(item_id))) *% 1099511628211;
    }
    for (loadout.visuals()) |visual| {
        hash = (hash ^ @as(u64, @intFromEnum(visual.recipe))) *% 1099511628211;
        const source: u64 = switch (visual.source) {
            .anatomy_part => |part_id| @intFromEnum(part_id),
            .attachment_point => |point_id| 0x1_0000 + @as(u64, @intFromEnum(point_id)),
        };
        hash = (hash ^ source) *% 1099511628211;
    }
    return hash;
}

fn componentForVisual(
    loadout: *const equipment.Loadout,
    visual: equipment.ResolvedVisualInstance,
) !equipment.VisualComponent {
    const recipe = try loadout.definition.recipe(visual.recipe);
    return loadout.definition.visual_components[recipe.component.index()];
}

fn expectControllerStateEqual(
    expected: @import("character_controller").State,
    actual: @import("character_controller").State,
) !void {
    try std.testing.expect(expected.position.approxEqAbs(actual.position, 0.000001));
    try std.testing.expect(expected.previous_position.approxEqAbs(actual.previous_position, 0.000001));
    try std.testing.expect(expected.velocity.approxEqAbs(actual.velocity, 0.000001));
    try std.testing.expectEqual(expected.facing, actual.facing);
    try std.testing.expectEqual(expected.grounded, actual.grounded);
    try std.testing.expectEqual(expected.supporting_collider, actual.supporting_collider);
    try std.testing.expectEqual(expected.simulation_tick, actual.simulation_tick);
}
