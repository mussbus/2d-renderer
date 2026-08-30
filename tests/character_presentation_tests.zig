const std = @import("std");
const input = @import("input");
const humanoid = @import("humanoid");
const character = @import("character");
const presentation_view = @import("presentation_view");
const presentation_pose = @import("presentation_pose");
const character_art = @import("character_art");
const modular_body_demo = @import("modular_body_demo");
const modular_humanoid = @import("modular_humanoid");
const handshake_ik_demo = @import("handshake_ik_demo");
const render_queue = @import("render_queue");

test "automatic presentation policy is authoritative and complete" {
    try std.testing.expectEqual(
        presentation_view.View.front,
        presentation_view.automaticView(.{ .grounded = true, .activity = .idle }),
    );
    for ([_]presentation_view.Activity{
        .walking,
        .dashing,
        .jumping,
        .rising,
        .falling,
        .landing,
    }) |activity| {
        try std.testing.expectEqual(
            presentation_view.View.side,
            presentation_view.automaticView(.{ .grounded = true, .activity = activity }),
        );
    }
    try std.testing.expectEqual(
        presentation_view.View.side,
        presentation_view.automaticView(.{ .grounded = false, .activity = .idle }),
    );
}

test "debug override and interaction authority have deterministic precedence and cleanup" {
    var runtime = presentation_view.Runtime{};
    runtime.setDebugOverride(.force_front);
    try runtime.claimInteraction(37, .side);
    var change = try runtime.sync(.{ .grounded = true, .activity = .idle });
    try std.testing.expect(change.changed());
    try std.testing.expectEqual(presentation_view.View.side, runtime.current);
    try runtime.releaseInteraction(37);
    change = try runtime.sync(.{ .grounded = true, .activity = .idle });
    try std.testing.expect(change.changed());
    try std.testing.expectEqual(presentation_view.View.front, runtime.current);
    try std.testing.expectEqual(@as(u32, 2), runtime.transition_count);
    try std.testing.expectEqual(runtime.transition_count, runtime.secondary_reset_count);
}

test "facing is preserved across view changes and reset restores automatic front" {
    var scene = try modular_body_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const male = &scene.conventional_male;
    try male.setFacing(.left);
    const root_before = male.world_position;
    try std.testing.expectEqual(presentation_view.View.front, male.presentationView());
    try male.enterAnimationState(.walk);
    try std.testing.expectEqual(presentation_view.View.side, male.presentationView());
    try std.testing.expectEqual(humanoid.Facing.left, male.facing);
    try male.setPresentationOverride(.force_front);
    try std.testing.expectEqual(presentation_view.View.front, male.presentationView());
    try std.testing.expectEqual(humanoid.Facing.left, male.facing);
    try std.testing.expect(male.world_position.approxEqAbs(root_before, 0));
    try male.reset();
    try std.testing.expectEqual(presentation_view.DebugOverride.automatic, male.presentationOverride());
    try std.testing.expectEqual(presentation_view.View.front, male.presentationView());
}

test "side reflection remains single-root while front projection never reflects facing" {
    var scene = try modular_body_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const male = &scene.conventional_male;
    const head = try scene.definition.attachment(.head);

    try male.setPresentationOverride(.force_side);
    try male.setFacing(.right);
    const right_side = try humanoid.spriteTransform(try male.character.appearance_runtime.visualWorld(
        male.definition.visual_definition,
        head.id,
    ));
    try male.setFacing(.left);
    const left_side = try humanoid.spriteTransform(try male.character.appearance_runtime.visualWorld(
        male.definition.visual_definition,
        head.id,
    ));
    try std.testing.expect(right_side.signed_scale.x > 0);
    try std.testing.expect(left_side.signed_scale.x < 0);

    const right_front = try presentation_pose.FrontProjection.init(
        &male.definition.skeleton_definition,
        male.character.local_and_world_pose,
        male.definition.visual_definition,
        male.character.appearance_runtime,
        male.world_position,
    );
    try male.setFacing(.right);
    const left_front = try presentation_pose.FrontProjection.init(
        &male.definition.skeleton_definition,
        male.character.local_and_world_pose,
        male.definition.visual_definition,
        male.character.appearance_runtime,
        male.world_position,
    );
    const head_index = try male.definition.skeleton_definition.boneIndex(.head);
    try std.testing.expect(right_front.bone_world[head_index].approxEqAbs(
        left_front.bone_world[head_index],
        0.000001,
    ));
}

test "character art definitions cover both views bald buzz cut and long hair" {
    var art = try character_art.Definition.init(std.testing.allocator);
    defer art.deinit();
    var definition = try modular_humanoid.initDefinition(std.testing.allocator);
    defer definition.deinit();
    const male = try character_art.Presentation.init(&art, &definition, .male, 1);
    const female = try character_art.Presentation.init(&art, &definition, .female, 1);
    try std.testing.expectEqual(character_art.texture_page_count, art.art.pages.len);
    try std.testing.expectEqual(@as(usize, 72), art.art.regions.len);
    // VF-03-R1 adds six optional-arm production bindings per
    // style/view combination without adding atlas regions.
    try std.testing.expectEqual(@as(usize, 128), art.art.bindings.len);
    try std.testing.expect(male.hasHair(.bald));
    try std.testing.expect(male.hasHair(.buzz_cut));
    try std.testing.expect(!male.hasHair(.long));
    try std.testing.expect(female.hasHair(.long));
    try std.testing.expect(!female.hasHair(.buzz_cut));
}

test "Prompt 25B production anatomy pages and regions have exact valid bounds" {
    try std.testing.expectEqualStrings(
        "art/p27c_male_base_anatomy_atlas.png",
        character_art.page_inputs[0].asset_path,
    );
    try std.testing.expectEqual(@as(u32, 1600), character_art.page_inputs[0].expected_width);
    try std.testing.expectEqual(@as(u32, 983), character_art.page_inputs[0].expected_height);
    try std.testing.expectEqualStrings(
        "art/p27c_female_base_anatomy_atlas.png",
        character_art.page_inputs[1].asset_path,
    );
    try std.testing.expectEqual(@as(u32, 1599), character_art.page_inputs[1].expected_width);
    try std.testing.expectEqual(@as(u32, 984), character_art.page_inputs[1].expected_height);
    try std.testing.expectEqualStrings(
        "art/p27c_anatomy_components_atlas.png",
        character_art.page_inputs[2].asset_path,
    );
    try std.testing.expectEqual(@as(u32, 1792), character_art.page_inputs[2].expected_width);
    try std.testing.expectEqual(@as(u32, 1024), character_art.page_inputs[2].expected_height);

    for (character_art.region_inputs) |region| {
        const page = for (character_art.page_inputs) |candidate| {
            if (candidate.id == region.page_id) break candidate;
        } else return error.MissingCharacterRegionPage;
        try std.testing.expect(region.source.width > 0);
        try std.testing.expect(region.source.height > 0);
        try std.testing.expect(region.source.x + region.source.width <= page.expected_width);
        try std.testing.expect(region.source.y + region.source.height <= page.expected_height);
        try std.testing.expect(region.authored_size[0] > 0);
        try std.testing.expect(region.authored_size[1] > 0);
        try std.testing.expect(region.pivot[0] >= 0 and region.pivot[0] <= 1);
        try std.testing.expect(region.pivot[1] >= 0 and region.pivot[1] <= 1);
    }
}

test "Prompt 25D real component bindings are distinct with valid authored extents" {
    var art = try character_art.Definition.init(std.testing.allocator);
    defer art.deinit();

    for (std.enums.values(character_art.Style)) |style| {
        for (std.enums.values(presentation_view.View)) |view| {
            const upper_arm = try art.resolveBaseAnatomy(style, .left_upper_arm, view);
            const forearm = try art.resolveBaseAnatomy(style, .left_forearm, view);
            const hand = try art.resolveBaseAnatomy(style, .left_hand, view);
            const thigh = try art.resolveBaseAnatomy(style, .left_thigh, view);
            const shin = try art.resolveBaseAnatomy(style, .left_shin, view);
            const foot = try art.resolveBaseAnatomy(style, .left_foot, view);
            const pelvis = try art.resolveBaseAnatomy(style, .pelvis, view);

            try std.testing.expect(upper_arm.region_id != forearm.region_id);
            try std.testing.expect(!std.meta.eql(upper_arm.uv_rect, forearm.uv_rect));
            try std.testing.expect(thigh.region_id != shin.region_id);
            try std.testing.expect(!std.meta.eql(thigh.uv_rect, shin.uv_rect));
            try std.testing.expect(!std.meta.eql(shin.uv_rect, foot.uv_rect));
            for ([_]@TypeOf(upper_arm){
                upper_arm,
                forearm,
                hand,
                thigh,
                shin,
                foot,
                pelvis,
            }) |component| {
                try std.testing.expectEqual(@as(u32, 2), component.texture_page);
            }
        }
    }

    for (character_art.region_inputs) |region| {
        if (region.page_id != character_art.component_page_id and
            !isCoreBaseRegionName(region.stable_name))
        {
            continue;
        }
        // Alpha-tight source bounds are axis-aligned while several production
        // components have a quarter-turn rest rotation and morphology-aware
        // semantic axes. Raw rectangle aspect is therefore not a fit metric.
        // The Prompt 25D semantic-geometry gate owns anatomy proportions; this
        // routing test retains the bounded authored-data guarantee.
        try std.testing.expect(std.math.isFinite(region.authored_size[0]));
        try std.testing.expect(std.math.isFinite(region.authored_size[1]));
        try std.testing.expect(region.authored_size[0] > 0);
        try std.testing.expect(region.authored_size[1] > 0);
    }
}

test "Prompt 27C component sizes and pivots follow view-specific rig spans" {
    var art = try character_art.Definition.init(std.testing.allocator);
    defer art.deinit();

    for (std.enums.values(character_art.Style)) |style| {
        for (std.enums.values(presentation_view.View)) |view| {
            const upper_arm = try art.resolveBaseAnatomy(style, .left_upper_arm, view);
            const forearm = try art.resolveBaseAnatomy(style, .left_forearm, view);
            const hand = try art.resolveBaseAnatomy(style, .left_hand, view);
            const thigh = try art.resolveBaseAnatomy(style, .left_thigh, view);
            const shin = try art.resolveBaseAnatomy(style, .left_shin, view);
            const foot = try art.resolveBaseAnatomy(style, .left_foot, view);

            const upper_length = if (view == .side)
                upper_arm.authored_size[0]
            else
                upper_arm.authored_size[1];
            const forearm_length = if (view == .side)
                forearm.authored_size[0]
            else
                forearm.authored_size[1];
            if (view == .side) {
                try std.testing.expect(upper_length >= 0.65 and upper_length <= 0.70);
                try std.testing.expect(forearm_length >= 0.57 and forearm_length <= 0.60);
            } else {
                try std.testing.expect(upper_length >= 0.78 and upper_length <= 0.82);
                try std.testing.expect(forearm_length >= 0.56 and forearm_length <= 0.58);
            }
            try std.testing.expect(thigh.authored_size[1] >= 0.90 and thigh.authored_size[1] <= 1.05);
            try std.testing.expect(shin.authored_size[1] >= 0.85 and shin.authored_size[1] <= 0.96);
            // The two views use separately authored foot silhouettes. Keep
            // their declared spans narrow and style-specific so neither
            // presentation can drift while retaining footwear fit.
            if (view == .side) {
                try std.testing.expect(foot.authored_size[0] >= 0.43);
                try std.testing.expect(foot.authored_size[0] <= 0.45);
            } else if (style == .male) {
                try std.testing.expect(foot.authored_size[0] >= 0.415);
                try std.testing.expect(foot.authored_size[0] <= 0.425);
            } else {
                try std.testing.expect(foot.authored_size[0] >= 0.355);
                try std.testing.expect(foot.authored_size[0] <= 0.365);
            }

            if (view == .side) {
                try std.testing.expect(upper_arm.pivot[0] <= 0.10);
                try std.testing.expect(forearm.pivot[0] <= 0.15);
                try std.testing.expect(hand.pivot[0] <= 0.15);
            } else {
                try std.testing.expect(upper_arm.pivot[1] >= 0.85);
                try std.testing.expect(upper_arm.pivot[1] <= 0.87);
                try std.testing.expect(forearm.pivot[1] >= 0.98);
                try std.testing.expect(hand.pivot[1] >= 0.95);
            }
            try std.testing.expect(thigh.pivot[1] >= 0.90);
            try std.testing.expect(shin.pivot[1] >= 0.90);
            // Side and front source axes are distinct. Their style-specific
            // alpha-derived ankle pivots stay in narrow declared bands.
            if (view == .side) {
                try std.testing.expect(foot.pivot[0] >= 0.24);
                try std.testing.expect(foot.pivot[0] <= 0.27);
            } else if (style == .male) {
                try std.testing.expect(foot.pivot[0] >= 0.30);
                try std.testing.expect(foot.pivot[0] <= 0.31);
            } else {
                try std.testing.expect(foot.pivot[0] >= 0.33);
                try std.testing.expect(foot.pivot[0] <= 0.34);
            }
        }
    }
}

test "Prompt 27C final front joins retain accepted authored geometry" {
    var art = try character_art.Definition.init(std.testing.allocator);
    defer art.deinit();

    const male_torso = try art.resolveBaseAnatomy(.male, .torso, .front);
    const female_torso = try art.resolveBaseAnatomy(.female, .torso, .front);
    const male_pelvis = try art.resolveBaseAnatomy(.male, .pelvis, .front);
    const male_thigh = try art.resolveBaseAnatomy(.male, .left_thigh, .front);
    const female_hand = try art.resolveBaseAnatomy(.female, .left_hand, .front);

    try std.testing.expectEqual([2]f32{ 0.94, 1.30 }, male_torso.authored_size);
    try std.testing.expectEqual([2]f32{ 0.85, 1.30 }, female_torso.authored_size);
    try std.testing.expectEqual([2]f32{ 0.96, 0.62 }, male_pelvis.authored_size);
    try std.testing.expectEqual([2]f32{ 0.5, 0.305 }, male_pelvis.pivot);
    try std.testing.expectEqual([2]f32{ 0.38, 0.980 }, male_thigh.authored_size);
    try std.testing.expectEqual([2]f32{ 0.15, 0.282 }, female_hand.authored_size);

    // The alpha-tight upper-arm distal ends own the bounded elbow overlap.
    // This is normal anatomy ordering, not a connector sprite.
    try std.testing.expect(
        character_art.frontPresentationLayer(.left_upper_arm) >
            character_art.frontPresentationLayer(.left_forearm),
    );
    try std.testing.expect(
        character_art.frontPresentationLayer(.right_upper_arm) >
            character_art.frontPresentationLayer(.right_forearm),
    );
    try std.testing.expect(
        character_art.frontPresentationLayer(.pelvis) <
            character_art.frontPresentationLayer(.left_thigh),
    );
    try std.testing.expect(
        character_art.frontPresentationLayer(.pelvis) <
            character_art.frontPresentationLayer(.right_thigh),
    );
    try std.testing.expect(
        character_art.frontPresentationLayer(.torso) >
            character_art.frontPresentationLayer(.left_thigh),
    );
}

test "Prompt 25D side projection preserves one readable profile root per bilateral pair" {
    var scene = try modular_body_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const male = &scene.conventional_male;
    const definition = &male.definition.skeleton_definition;
    const source = male.character.local_and_world_pose;
    const projection = try presentation_pose.FrontProjection.initSide(
        definition,
        source,
        male.definition.visual_definition,
        male.character.appearance_runtime,
        male.world_position,
        false,
    );
    const upper_index = try definition.boneIndex(.right_upper_arm);
    const source_upper = source.world_transforms[upper_index].translationPart();
    const root_x = male.world_position.x;
    const tolerance: f32 = 0.000001; // Matrix composition is the same f32 path, so six decimals is ample.
    try std.testing.expect(projection.bone_world[upper_index].translationPart().approxEqAbs(
        .{ .x = root_x + presentation_pose.side_profile_arm_root_offset, .y = source_upper.y },
        tolerance,
    ));
    const thigh_index = try definition.boneIndex(.right_thigh);
    const source_thigh = source.world_transforms[thigh_index].translationPart();
    try std.testing.expect(projection.bone_world[thigh_index].translationPart().approxEqAbs(
        .{ .x = root_x + presentation_pose.side_profile_thigh_root_offset, .y = source_thigh.y },
        tolerance,
    ));
}

test "actual base anatomy resolves without a garment and garment identity cannot replace anatomy" {
    var storage: [128 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var art = try character_art.Definition.init(fixed.allocator());
    defer art.deinit();
    const allocation_checkpoint = fixed.end_index;

    for (std.enums.values(character_art.Style)) |style| {
        for (std.enums.values(presentation_view.View)) |view| {
            for (std.enums.values(humanoid.AttachmentSemantic)) |semantic| {
                const base_without_garment = try art.resolveBaseAnatomy(style, semantic, view);
                try std.testing.expect(base_without_garment.authored_size[0] > 0);
                try std.testing.expect(base_without_garment.authored_size[1] > 0);
            }

            const torso_before = try art.resolveBaseAnatomy(style, .torso, view);
            var removable_garment: ?@TypeOf(torso_before) =
                try art.resolveGarment(style, .training_vest, view);
            try std.testing.expect(torso_before.semantic_id != removable_garment.?.semantic_id);
            try std.testing.expect(torso_before.region_id != removable_garment.?.region_id);
            try std.testing.expectEqual(torso_before.texture_page, removable_garment.?.texture_page);

            removable_garment = null;
            try std.testing.expect(removable_garment == null);
            const torso_after_removal = try art.resolveBaseAnatomy(style, .torso, view);
            try std.testing.expectEqualDeep(torso_before, torso_after_removal);

            removable_garment = try art.resolveGarment(style, .training_vest, view);
            const torso_after_replacement = try art.resolveBaseAnatomy(style, .torso, view);
            try std.testing.expect(removable_garment != null);
            try std.testing.expectEqualDeep(torso_before, torso_after_replacement);
        }
    }

    try std.testing.expectEqual(allocation_checkpoint, fixed.end_index);
}

test "front layers are explicit stable and use anatomy-owned overlap" {
    try std.testing.expectEqual(@as(u16, 22), character_art.frontBodyPartLayer(.left_upper_arm));
    try std.testing.expectEqual(@as(u16, 26), character_art.frontBodyPartLayer(.right_upper_arm));
    try std.testing.expectEqual(@as(u16, 12), character_art.frontBodyPartLayer(.left_thigh));
    try std.testing.expectEqual(@as(u16, 16), character_art.frontBodyPartLayer(.right_thigh));
    try std.testing.expectEqual(@as(u16, 30), character_art.frontBodyPartLayer(.pelvis));
    try std.testing.expectEqual(@as(u16, 31), character_art.frontBodyPartLayer(.torso));
    try std.testing.expectEqual(@as(u16, 40), character_art.frontBodyPartLayer(.head));
    try std.testing.expectEqual(@as(u16, 21), character_art.frontPresentationLayer(.left_forearm));
    try std.testing.expectEqual(@as(u16, 25), character_art.frontPresentationLayer(.right_forearm));
    try std.testing.expectEqual(@as(u16, 12), character_art.frontPresentationLayer(.left_thigh));
    try std.testing.expectEqual(@as(u16, 16), character_art.frontPresentationLayer(.right_thigh));
    try std.testing.expectEqual(@as(u16, 9), character_art.frontPresentationLayer(.pelvis));
}

test "interaction owns side view and cancellation releases both participants to front" {
    var scene = try handshake_ik_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    var frame: u32 = 0;
    while (frame <= 31) : (frame += 1) try scene.updateFrame(frame);
    try std.testing.expectEqual(@as(usize, 1), scene.manager.activeCount());
    try std.testing.expectEqual(presentation_view.View.side, scene.character_a.presentationView());
    try std.testing.expectEqual(presentation_view.View.side, scene.character_b.presentationView());
    const participants = [_]*character.CharacterInstance{ &scene.character_a, &scene.character_b };
    try std.testing.expect(try scene.manager.cancelForCharacter(
        scene.character_a.id,
        .character_reset,
        &participants,
    ));
    try std.testing.expectEqual(presentation_view.View.front, scene.character_a.presentationView());
    try std.testing.expectEqual(presentation_view.View.front, scene.character_b.presentationView());
    try std.testing.expectEqual(@as(u32, 0), scene.character_a.presentation.interaction_owner);
    try std.testing.expectEqual(@as(u32, 0), scene.character_b.presentation.interaction_owner);
}

test "view transition clears long-hair spring state without allocation or cross-character mutation" {
    var storage: [2 * 1024 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var scene = try modular_body_demo.Scene.init(fixed.allocator());
    defer scene.deinit();
    const female = &scene.conventional_female;
    const male = &scene.conventional_male;
    try female.enterAnimationState(.walk);
    var tick: usize = 0;
    while (tick < 48) : (tick += 1) {
        try female.advanceVisualTick(.{
            .horizontal_velocity = -2.5,
            .physically_grounded = true,
        });
    }
    const hair_id = try scene.definition.visual_definition.visualId("long_hair");
    const before = try female.character.appearance_runtime.visualSecondaryState(
        female.definition.visual_definition,
        hair_id,
    );
    try std.testing.expect(before.initialized);
    try std.testing.expect(before.fixed_ticks > 0);
    const male_view_before = male.presentationView();
    const allocation_checkpoint = fixed.end_index;
    try female.setPresentationOverride(.force_front);
    const after = try female.character.appearance_runtime.visualSecondaryState(
        female.definition.visual_definition,
        hair_id,
    );
    try std.testing.expect(!after.initialized);
    try std.testing.expectEqual(allocation_checkpoint, fixed.end_index);
    try std.testing.expectEqual(male_view_before, male.presentationView());
}

test "Q input cycles presentation only and art submission remains bounded in both views" {
    var scene = try modular_body_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    var art = try character_art.Definition.init(std.testing.allocator);
    defer art.deinit();
    const male_art = try character_art.Presentation.init(&art, &scene.definition, .male, 1);
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        64,
        62,
        2,
        1 + character_art.texture_page_count,
    );
    defer queue.deinit();

    var builder = input.SnapshotBuilder{};
    const snapshot = try builder.update(.{ .keyboard = .{ .q = true } });
    const facing_before = scene.conventional_male.facing;
    try scene.conventional_male.applyPresentationInput(snapshot);
    try std.testing.expectEqual(presentation_view.DebugOverride.force_side, scene.conventional_male.presentationOverride());
    try std.testing.expectEqual(facing_before, scene.conventional_male.facing);

    queue.beginFrame();
    const side_count = try male_art.submit(&scene.conventional_male, &queue);
    try std.testing.expect(side_count >= humanoid.default_visual_count);
    _ = queue.prepare();
    try scene.conventional_male.setPresentationOverride(.force_front);
    queue.beginFrame();
    const front_count = try male_art.submit(&scene.conventional_male, &queue);
    try std.testing.expect(front_count > side_count);
    const prepared = queue.prepare();
    try std.testing.expectEqual(@as(usize, front_count), prepared.sprites.len);
    try std.testing.expect(queue.frame_metrics.sprite_ranges >= 2);
    try std.testing.expectEqual(@as(u32, 0), queue.frame_metrics.sprite_draws);

    for ([_][2]humanoid.AttachmentSemantic{
        .{ .left_upper_arm, .right_upper_arm },
        .{ .left_forearm, .right_forearm },
        .{ .left_hand, .right_hand },
        .{ .left_thigh, .right_thigh },
        .{ .left_shin, .right_shin },
        .{ .left_foot, .right_foot },
    }) |pair| {
        const left = spriteForLayer(prepared.sprites, character_art.frontPresentationLayer(pair[0])) orelse
            return error.MissingLeftFrontComponent;
        const right = spriteForLayer(prepared.sprites, character_art.frontPresentationLayer(pair[1])) orelse
            return error.MissingRightFrontComponent;
        try std.testing.expect(left.scale[0] * right.scale[0] < 0);
        try std.testing.expectApproxEqAbs(@abs(left.scale[0]), @abs(right.scale[0]), 0.000001);
    }
}

fn isCoreBaseRegionName(name: []const u8) bool {
    for ([_][]const u8{
        "_head",
        "_torso",
        "_pelvis",
        "_upper_arm",
        "_forearm",
        "_hand",
        "_thigh",
        "_shin",
        "_foot",
    }) |suffix| {
        if (std.mem.endsWith(u8, name, suffix)) return true;
    }
    return false;
}

fn spriteForLayer(
    sprites: anytype,
    layer: u16,
) ?@TypeOf(sprites[0]) {
    for (sprites) |submitted| {
        if (submitted.order.body_part_layer == layer) return submitted;
    }
    return null;
}
