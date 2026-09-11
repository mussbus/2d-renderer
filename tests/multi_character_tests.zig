const std = @import("std");
const math = @import("math");
const input = @import("input");
const fault_injection = @import("fault_injection");
const fixed_step = @import("fixed_step");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const animation_system = @import("animation_system");
const controller_demo = @import("controller_demo");
const character = @import("character");
const sprite = @import("sprite_batch");

const tolerance: f32 = 1e-5;

const SharedFixture = struct {
    definition: humanoid.HumanoidDefinition,
    animations: authored.Definitions,

    fn init(allocator: std.mem.Allocator) !SharedFixture {
        var definition = try humanoid.HumanoidDefinition.init(allocator, null);
        errdefer definition.deinit();
        var animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer animations.deinit();
        return .{ .definition = definition, .animations = animations };
    }

    fn deinit(fixture: *SharedFixture) void {
        fixture.animations.deinit();
        fixture.definition.deinit();
        fixture.* = undefined;
    }
};

fn initInstance(
    fixture: *const SharedFixture,
    id: u32,
    position: math.Vec2,
    facing: humanoid.Facing,
    actor_layer: u16,
) !character.CharacterInstance {
    return character.CharacterInstance.init(
        std.testing.allocator,
        try character.entityIdFromRaw(id),
        &fixture.definition,
        &fixture.animations,
        position,
        facing,
        actor_layer,
        null,
    );
}

fn expectVec(expected: math.Vec2, actual: math.Vec2) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
}

fn submitPair(
    a: *character.CharacterInstance,
    b: *character.CharacterInstance,
    batch: *sprite.SpriteBatch,
) !sprite.PreparedBatch {
    batch.beginFrame();
    const instances = [_]*character.CharacterInstance{ b, a };
    try std.testing.expectEqual(@as(u32, 2 * humanoid.default_visual_count), try character.submitGlobally(&instances, batch));
    return batch.prepare();
}

test "entity IDs are deterministic unique non-null and overflow checked" {
    var first = character.EntityIdAllocator{};
    var second = character.EntityIdAllocator{};
    var registry = character.EntityRegistry{};
    for (1..character.maximum_characters + 1) |expected| {
        const first_id = try first.allocate();
        const second_id = try second.allocate();
        try std.testing.expectEqual(@as(u32, @intCast(expected)), first_id.raw());
        try std.testing.expectEqual(first_id, second_id);
        try registry.insert(first_id);
        try std.testing.expect(registry.contains(first_id));
    }
    try std.testing.expectError(error.InvalidEntityId, character.entityIdFromRaw(0));
    try std.testing.expectError(error.InvalidEntityId, registry.insert(.invalid));
    try std.testing.expectError(error.DuplicateEntityId, registry.insert(try character.entityIdFromRaw(1)));
    try std.testing.expectError(error.CharacterCapacityExceeded, registry.insert(try character.entityIdFromRaw(100)));

    var near_overflow = try character.EntityIdAllocator.initAt(std.math.maxInt(u32) - 1);
    try std.testing.expectEqual(std.math.maxInt(u32) - 1, (try near_overflow.allocate()).raw());
    try std.testing.expectEqual(std.math.maxInt(u32), (try near_overflow.allocate()).raw());
    try std.testing.expectError(error.EntityIdOverflow, near_overflow.allocate());
    try std.testing.expectError(error.InvalidEntityId, character.EntityIdAllocator.initAt(0));
}

test "characters share immutable definitions while pose animator and procedural state stay independent" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var a = try initInstance(&fixture, 1, .{ .x = -1, .y = 1.05 }, .right, 0);
    defer a.deinit();
    var b = try initInstance(&fixture, 2, .{ .x = 1, .y = 1.05 }, .left, 1);
    defer b.deinit();

    const a_definition = a.definitionView();
    const b_definition = b.definitionView();
    const a_animations = a.animationDefinitionsView();
    const b_animations = b.animationDefinitionsView();
    try std.testing.expectEqual(a_definition.owner_token, b_definition.owner_token);
    try std.testing.expect(a_definition.attachments.ptr == b_definition.attachments.ptr);
    try std.testing.expect(a_animations.clips.ptr == b_animations.clips.ptr);
    try std.testing.expectEqual(a_animations.library_token, b_animations.library_token);
    try std.testing.expect(a.humanoidView().local_and_world_pose.local_transforms.ptr != b.humanoidView().local_and_world_pose.local_transforms.ptr);
    try std.testing.expect(a.humanoidView().local_and_world_pose.world_transforms.ptr != b.humanoidView().local_and_world_pose.world_transforms.ptr);
    const a_internal = character.testing.stateConst(&a);
    const b_internal = character.testing.stateConst(&b);
    try std.testing.expect(a_internal.animator.source_pose.ptr != b_internal.animator.source_pose.ptr);
    try std.testing.expect(a_internal.animator.destination_pose.ptr != b_internal.animator.destination_pose.ptr);
    try std.testing.expect(a_internal.animator.event_storage.ptr != b_internal.animator.event_storage.ptr);

    const shared_idle_duration = fixture.animations.library.clips[0].duration;
    const b_pelvis_before = try b.humanoidView().local_and_world_pose.localForSemantic(&fixture.definition.skeleton_definition, .pelvis);
    var a_pelvis = try a.humanoidView().local_and_world_pose.localForSemantic(&fixture.definition.skeleton_definition, .pelvis);
    a_pelvis.translation.x += 0.25;
    try a.setLocalPoseSemantic(.pelvis, a_pelvis);
    try a.setFacing(a.facingDirection());
    const b_pelvis_after = try b.humanoidView().local_and_world_pose.localForSemantic(&fixture.definition.skeleton_definition, .pelvis);
    try std.testing.expect(b_pelvis_before.approxEqAbs(b_pelvis_after, tolerance));

    try a.enterAnimationState(.walk);
    for (0..90) |_| try a.advanceVisualTick(.{ .horizontal_velocity = 2.4 });
    try std.testing.expect(a.animationTime() != b.animationTime());
    try std.testing.expectEqual(@as(f32, 0), b.animationTime());
    try std.testing.expect(a.proceduralSnapshot().walk_bounce_amplitude > 0);
    try std.testing.expectEqual(@as(f32, 0), b.proceduralSnapshot().walk_bounce_amplitude);
    try std.testing.expectEqual(shared_idle_duration, fixture.animations.library.clips[0].duration);
}

test "four adversarial character states remain isolated when one character resets" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var a = try initInstance(&fixture, 1, .{ .x = -3, .y = 1.05 }, .right, 0);
    defer a.deinit();
    var b = try initInstance(&fixture, 2, .{ .x = -1, .y = 1.05 }, .left, 7);
    defer b.deinit();
    var c = try initInstance(&fixture, 3, .{ .x = 1, .y = 1.05 }, .right, 4);
    defer c.deinit();
    var d = try initInstance(&fixture, 4, .{ .x = 3, .y = 1.05 }, .left, 2);
    defer d.deinit();

    try a.enterAnimationState(.walk);
    for (0..31) |_| try a.advanceVisualTick(.{ .horizontal_velocity = 3.5 });
    _ = try b.applySemanticOverride(.right_forearm, .{ .interaction_layer = 9 });
    character.testing.state(&c).foot_plants.left = .{
        .plant_state = .planted,
        .plant_weight = 1,
        .locked_target = .{ .x = 0.8, .y = 0 },
        .locked_collider_id = 1,
    };
    try d.reserveInteraction(77);

    const b_before = b;
    const c_foot_before = c.footPlantingSnapshot().left;
    const d_owner_before = d.interactionOwnerId();
    try a.reset();
    try std.testing.expectEqual(b_before.animationState(), b.animationState());
    try std.testing.expectEqual(b_before.animationTime(), b.animationTime());
    try std.testing.expectEqual(b_before.facingDirection(), b.facingDirection());
    try std.testing.expectEqual(b_before.actorLayer(), b.actorLayer());
    try std.testing.expectEqual(b_before.activeOverrideCount(), b.activeOverrideCount());
    try std.testing.expectEqualDeep(c_foot_before, c.footPlantingSnapshot().left);
    try std.testing.expectEqual(d_owner_before, d.interactionOwnerId());
    try std.testing.expect(d.isInteractionLocked());

    try c.reset();
    try std.testing.expect(!c.footPlantingSnapshot().left.hasLock());
    try std.testing.expectEqual(b_before.animationTime(), b.animationTime());
    try std.testing.expectEqual(d_owner_before, d.interactionOwnerId());
    try d.releaseInteraction(77);
}

test "destroying one instance leaves the other and shared immutable data valid" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var a = try initInstance(&fixture, 1, .{ .x = -1, .y = 1.05 }, .right, 0);
    var b = try initInstance(&fixture, 2, .{ .x = 1, .y = 1.05 }, .left, 1);
    defer b.deinit();
    const clip_pointer = fixture.animations.library.clips.ptr;
    const b_pose_pointer = b.humanoidView().local_and_world_pose.local_transforms.ptr;
    a.deinit();
    try b.advanceVisualTick(.{});
    try std.testing.expectEqual(@as(u64, 1), b.simulationTick());
    try std.testing.expect(b.humanoidView().local_and_world_pose.local_transforms.ptr == b_pose_pointer);
    try std.testing.expect(fixture.animations.library.clips.ptr == clip_pointer);
}

test "facing overrides and single-character reset do not cross character ownership" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var a = try initInstance(&fixture, 1, .{ .x = -1, .y = 1.05 }, .right, 0);
    defer a.deinit();
    var b = try initInstance(&fixture, 2, .{ .x = 1, .y = 1.05 }, .left, 1);
    defer b.deinit();

    try b.enterAnimationState(.walk);
    for (0..37) |_| try b.advanceVisualTick(.{ .horizontal_velocity = -1.5 });
    _ = try b.applySemanticOverride(.left_hand, .{ .interaction_layer = -1 });
    const b_time = b.animationTime();
    const b_offset = b.proceduralSnapshot().walk_bounce_offset;
    const b_facing = b.facingDirection();
    const b_override_count = b.activeOverrideCount();

    try a.setFacing(.left);
    _ = try a.applySemanticOverride(.right_hand, .{ .interaction_layer = 1 });
    try a.reset();
    try std.testing.expectEqual(b_time, b.animationTime());
    try std.testing.expectEqual(b_offset, b.proceduralSnapshot().walk_bounce_offset);
    try std.testing.expectEqual(b_facing, b.facingDirection());
    try std.testing.expectEqual(b_override_count, b.activeOverrideCount());
    try std.testing.expectEqual(humanoid.Facing.right, a.facingDirection());
    try std.testing.expectEqual(@as(usize, 0), a.activeOverrideCount());
}

test "controlled character state steps and resets independently per instance" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    var a = try character.CharacterInstance.initControlled(
        std.testing.allocator,
        try character.entityIdFromRaw(1),
        &fixture.definition,
        &fixture.animations,
        &world,
        .{},
        controller_demo.spawn_position,
        .right,
        0,
        null,
    );
    defer a.deinit();
    var b = try character.CharacterInstance.initControlled(
        std.testing.allocator,
        try character.entityIdFromRaw(2),
        &fixture.definition,
        &fixture.animations,
        &world,
        .{},
        controller_demo.spawn_position,
        .left,
        1,
        null,
    );
    defer b.deinit();
    const b_before = b.controllerSnapshot().?.state;
    for (0..120) |_| {
        _ = try a.stepController(&world, .{
            .move_axis = 1,
            .jump_pressed = false,
            .jump_held = false,
            .jump_released = false,
            .interact_pressed = false,
        });
    }
    try std.testing.expect(!a.controllerSnapshot().?.state.position.approxEqAbs(b.controllerSnapshot().?.state.position, tolerance));
    try std.testing.expectEqualDeep(b_before, b.controllerSnapshot().?.state);
    try a.resetControlled(&world);
    try expectVec(controller_demo.spawn_position, a.controllerSnapshot().?.state.position);
    try std.testing.expectEqualDeep(b_before, b.controllerSnapshot().?.state);
}

test "failed second-character allocation leaves the first valid and permits retry" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    const stages = [_]fault_injection.InitStage{
        .pose_local_transform_allocation,
        .pose_world_transform_allocation,
        .humanoid_character_initialization,
        .animator_pose_buffer_allocation,
        .animator_event_buffer_allocation,
    };
    for (stages) |stage| {
        var first = try initInstance(&fixture, 1, .{ .x = -1, .y = 1.05 }, .right, 0);
        defer first.deinit();
        const shared_token = fixture.animations.library.token();
        try std.testing.expectError(error.InjectedInitializationFailure, character.CharacterInstance.init(
            std.testing.allocator,
            try character.entityIdFromRaw(2),
            &fixture.definition,
            &fixture.animations,
            .{ .x = 1, .y = 1.05 },
            .left,
            1,
            .{ .fail_after = stage },
        ));
        try first.advanceVisualTick(.{});
        try std.testing.expectEqual(@as(u64, 1), first.simulationTick());
        try std.testing.expectEqual(shared_token, fixture.animations.library.token());
        var retry = try initInstance(&fixture, 2, .{ .x = 1, .y = 1.05 }, .left, 1);
        retry.deinit();
    }
}

test "global actor ordering is reversible stable and interleaves equal-layer characters" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var a = try initInstance(&fixture, 1, .{ .x = -0.7, .y = 1.05 }, .right, 0);
    defer a.deinit();
    var b = try initInstance(&fixture, 2, .{ .x = 0.7, .y = 1.05 }, .right, 1);
    defer b.deinit();
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 64, 1);
    defer batch.deinit();

    _ = try submitPair(&a, &b, &batch);
    try std.testing.expect(sprite.keyLessThan(try a.submittedKey(.torso), try b.submittedKey(.torso)));
    try a.setActorLayer(2);
    try b.setActorLayer(0);
    _ = try submitPair(&a, &b, &batch);
    try std.testing.expect(sprite.keyLessThan(try b.submittedKey(.torso), try a.submittedKey(.torso)));

    try a.setActorLayer(0);
    try b.setActorLayer(0);
    const prepared = try submitPair(&a, &b, &batch);
    try std.testing.expect((try a.submittedKey(.torso)).submission_index < (try b.submittedKey(.torso)).submission_index);
    var ownership_switches: usize = 0;
    var previous_is_a = prepared.sprites[0].order.submission_index < humanoid.default_visual_count;
    for (prepared.sprites[1..]) |submission| {
        const is_a = submission.order.submission_index < humanoid.default_visual_count;
        if (is_a != previous_is_a) ownership_switches += 1;
        previous_is_a = is_a;
    }
    try std.testing.expect(ownership_switches > 2);
    const original_b_id = b.id();
    character.testing.state(&b).id = a.id();
    batch.beginFrame();
    const duplicates = [_]*character.CharacterInstance{ &a, &b };
    try std.testing.expectError(error.DuplicateEntityId, character.submitGlobally(&duplicates, &batch));
    character.testing.state(&b).id = original_b_id;
}

test "cross-character hand and forearm overrides provide partial anatomical interleaving" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var a = try initInstance(&fixture, 1, .{ .x = -0.7, .y = 1.05 }, .right, 0);
    defer a.deinit();
    var b = try initInstance(&fixture, 2, .{ .x = 0.7, .y = 1.05 }, .left, 1);
    defer b.deinit();
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 64, 1);
    defer batch.deinit();

    const a_hand_default = try a.resolvedOrder(.right_hand);
    _ = try a.applySemanticOverride(.right_hand, .{ .interaction_layer = 1 });
    _ = try submitPair(&a, &b, &batch);
    try std.testing.expect(sprite.keyLessThan(try a.submittedKey(.torso), try b.submittedKey(.torso)));
    try std.testing.expect(sprite.keyLessThan(try b.submittedKey(.right_hand), try a.submittedKey(.right_hand)));
    a.clearOverrides();
    try std.testing.expectEqualDeep(a_hand_default, try a.resolvedOrder(.right_hand));

    try a.setActorLayer(1);
    try b.setActorLayer(0);
    _ = try b.applySemanticOverride(.right_hand, .{ .interaction_layer = 1 });
    _ = try submitPair(&a, &b, &batch);
    try std.testing.expect(sprite.keyLessThan(try b.submittedKey(.torso), try a.submittedKey(.torso)));
    try std.testing.expect(sprite.keyLessThan(try a.submittedKey(.right_hand), try b.submittedKey(.right_hand)));

    b.clearOverrides();
    try a.setActorLayer(0);
    try b.setActorLayer(1);
    _ = try a.applySemanticOverride(.right_forearm, .{ .interaction_layer = 1 });
    _ = try submitPair(&a, &b, &batch);
    try std.testing.expect(sprite.keyLessThan(try a.submittedKey(.torso), try b.submittedKey(.torso)));
    try std.testing.expect(sprite.keyLessThan(try b.submittedKey(.torso), try a.submittedKey(.right_forearm)));
}

test "override precedence clearing validation and bounded capacity are explicit" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var a = try initInstance(&fixture, 1, .{ .x = 0, .y = 1.05 }, .right, 0);
    defer a.deinit();

    const first = try a.applySemanticOverride(.right_hand, .{ .interaction_layer = -1, .body_part_layer = 70 });
    const second = try a.applySemanticOverride(.right_hand, .{ .interaction_layer = 2 });
    var resolved = try a.resolvedOrder(.right_hand);
    try std.testing.expectEqual(@as(i32, 2), resolved.interaction_layer);
    try std.testing.expectEqual(@as(i32, 70), resolved.body_part_layer);
    try a.clearOverride(second);
    resolved = try a.resolvedOrder(.right_hand);
    try std.testing.expectEqual(@as(i32, -1), resolved.interaction_layer);
    try std.testing.expectEqual(@as(i32, 70), resolved.body_part_layer);
    try a.clearOverride(first);
    try std.testing.expectEqualDeep(
        sprite.OrderInput{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = humanoid.BodyPartLayers.front_hand },
        try a.resolvedOrder(.right_hand),
    );

    try std.testing.expectError(error.InvalidAttachmentTarget, a.applyAttachmentOverride(100, .{ .interaction_layer = 1 }));
    try std.testing.expectError(error.InvalidBodyPartSemantic, character.testing.state(&a).overrides.applySemanticRaw(&fixture.definition, 255, .{ .interaction_layer = 1 }));
    try std.testing.expectError(error.EmptyLayerOverride, a.applySemanticOverride(.right_hand, .{}));
    try std.testing.expectError(error.InvalidInteractionLayer, a.applySemanticOverride(.right_hand, .{ .interaction_layer = character.maximum_interaction_layer + 1 }));
    try std.testing.expectError(error.InvalidBodyPartLayer, a.applySemanticOverride(.right_hand, .{ .body_part_layer = -1 }));
    try std.testing.expectError(error.InvalidOverrideHandle, a.clearOverride(.invalid));

    for (0..character.maximum_layer_overrides) |_| _ = try a.applySemanticOverride(.right_hand, .{ .interaction_layer = 1 });
    try std.testing.expectError(error.LayerOverrideCapacityExceeded, a.applySemanticOverride(.right_forearm, .{ .interaction_layer = 1 }));
    a.clearOverrides();
    character.testing.state(&a).overrides.next_handle = std.math.maxInt(u32);
    _ = try a.applySemanticOverride(.right_hand, .{ .interaction_layer = 1 });
    a.clearOverrides();
    try std.testing.expectError(error.OverrideHandleOverflow, a.applySemanticOverride(.right_hand, .{ .interaction_layer = 1 }));
}

test "horizontal reflection preserves anatomical sockets through rotated ancestors and double mirror" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    const root = math.Vec2{ .x = 0.35, .y = 1.05 };
    var instance = try initInstance(&fixture, 1, root, .right, 0);
    defer instance.deinit();

    var torso = try instance.humanoidView().local_and_world_pose.localForSemantic(&fixture.definition.skeleton_definition, .torso);
    torso.rotation_radians += 0.23;
    try instance.setLocalPoseSemantic(.torso, torso);
    var right_arm = try instance.humanoidView().local_and_world_pose.localForSemantic(&fixture.definition.skeleton_definition, .right_upper_arm);
    right_arm.rotation_radians += 0.47;
    try instance.setLocalPoseSemantic(.right_upper_arm, right_arm);
    try instance.setFacing(.right);
    const right_hand_right = try instance.socketPosition(.right_hand);
    const left_hand_right = try instance.socketPosition(.left_hand);
    const right_foot_right = try instance.socketPosition(.right_foot);
    const left_foot_right = try instance.socketPosition(.left_foot);

    try instance.setFacing(.left);
    const right_hand_left = try instance.socketPosition(.right_hand);
    const left_hand_left = try instance.socketPosition(.left_hand);
    const right_foot_left = try instance.socketPosition(.right_foot);
    const left_foot_left = try instance.socketPosition(.left_foot);
    try expectVec(.{ .x = -(right_hand_right.x - root.x), .y = right_hand_right.y - root.y }, .{ .x = right_hand_left.x - root.x, .y = right_hand_left.y - root.y });
    try expectVec(.{ .x = -(left_hand_right.x - root.x), .y = left_hand_right.y - root.y }, .{ .x = left_hand_left.x - root.x, .y = left_hand_left.y - root.y });
    try expectVec(.{ .x = -(right_foot_right.x - root.x), .y = right_foot_right.y - root.y }, .{ .x = right_foot_left.x - root.x, .y = right_foot_left.y - root.y });
    try expectVec(.{ .x = -(left_foot_right.x - root.x), .y = left_foot_right.y - root.y }, .{ .x = left_foot_left.x - root.x, .y = left_foot_left.y - root.y });
    try std.testing.expect(!right_hand_left.approxEqAbs(left_hand_left, tolerance));

    try std.testing.expectEqual(@as(i32, humanoid.BodyPartLayers.back_hand), (try instance.resolvedOrder(.right_hand)).body_part_layer);
    try std.testing.expectEqual(@as(i32, humanoid.BodyPartLayers.front_hand), (try instance.resolvedOrder(.left_hand)).body_part_layer);
    try instance.setFacing(.right);
    try expectVec(right_hand_right, try instance.socketPosition(.right_hand));
    try expectVec(left_foot_right, try instance.socketPosition(.left_foot));
}

test "reflected attachment decomposition retains negative scale with no culling dependency" {
    const reflected = math.Mat3.translation(.{ .x = 3, .y = -2 })
        .mul(math.Mat3.nonuniformScale(.{ .x = -1, .y = 1 }))
        .mul(math.Mat3.rotation(0.37))
        .mul(math.Mat3.nonuniformScale(.{ .x = 2, .y = 0.5 }));
    const transformed = try humanoid.spriteTransform(reflected);
    try std.testing.expect(transformed.signed_scale.x < 0);
    const local = math.Vec2{ .x = 0.31, .y = -0.42 };
    const expected = reflected.transformPoint(local);
    const actual_array = try sprite.transformLocalPoint(.{
        .world_position = transformed.world_position.toArray(),
        .rotation = transformed.rotation_radians,
        .scale = transformed.signed_scale.toArray(),
        .pivot = .{ 0, 0 },
        .uv_rect = .{ 0, 0, 1, 1 },
        .tint = .{ 1, 1, 1, 1 },
        .texture_page = 0,
        .order = .{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 0 },
    }, local.toArray());
    try expectVec(expected, .{ .x = actual_array[0], .y = actual_array[1] });
}

const FacingPhysicsResult = struct {
    state: character_controller.State,
    half_extents: math.Vec2,
};

fn runFacingPhysics(facing: character_controller.Facing) !FacingPhysicsResult {
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    var controller = try character_controller.CharacterController.init(.{}, &world, controller_demo.spawn_position, facing);
    for (0..600) |tick| {
        _ = try controller.step(&world, .{
            .move_axis = if (tick < 300) 1 else 0,
            .jump_pressed = false,
            .jump_held = false,
            .jump_released = false,
            .interact_pressed = false,
        });
    }
    return .{ .state = controller.state, .half_extents = controller.configuration.collider_half_extents };
}

test "visual facing leaves equivalent physics and collider dimensions unchanged" {
    const left = try runFacingPhysics(.left);
    const right = try runFacingPhysics(.right);
    try expectVec(left.state.position, right.state.position);
    try expectVec(left.state.velocity, right.state.velocity);
    try std.testing.expectEqual(left.state.grounded, right.state.grounded);
    try std.testing.expectEqual(left.state.supporting_collider, right.state.supporting_collider);
    try std.testing.expectEqual(left.half_extents, right.half_extents);

    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var instance = try initInstance(&fixture, 1, .{ .x = 0, .y = 1.05 }, .right, 0);
    defer instance.deinit();
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    const controller = try character_controller.CharacterController.init(.{}, &world, controller_demo.spawn_position, .right);
    const state_before = controller.state;
    try instance.setFacing(.left);
    try instance.setFacing(.right);
    try std.testing.expectEqualDeep(state_before, controller.state);
}

test "two page-zero characters produce one range exact count and no character-specific batch" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var a = try initInstance(&fixture, 1, .{ .x = -0.7, .y = 1.05 }, .right, 0);
    defer a.deinit();
    var b = try initInstance(&fixture, 2, .{ .x = 0.7, .y = 1.05 }, .left, 1);
    defer b.deinit();
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 64, 1);
    defer batch.deinit();

    const prepared = try submitPair(&a, &b, &batch);
    try std.testing.expectEqual(@as(usize, 30), prepared.sprites.len);
    try std.testing.expectEqual(@as(usize, 1), prepared.ranges.len);
    try std.testing.expectEqual(@as(u32, 30), prepared.ranges[0].instance_count);
    batch.beginFrame();
    const empty = [_]*character.CharacterInstance{};
    try std.testing.expectEqual(@as(u32, 0), try character.submitGlobally(&empty, &batch));
    try std.testing.expectEqual(@as(usize, 0), batch.prepare().sprites.len);
}

test "single and whole-scene reset restore only requested character state" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var a = try initInstance(&fixture, 1, .{ .x = -1, .y = 1.05 }, .right, 0);
    defer a.deinit();
    var b = try initInstance(&fixture, 2, .{ .x = 1, .y = 1.05 }, .left, 1);
    defer b.deinit();

    try a.setFacing(.left);
    try b.setFacing(.right);
    _ = try a.applySemanticOverride(.right_hand, .{ .interaction_layer = 1 });
    const b_first = try b.applySemanticOverride(.left_hand, .{ .interaction_layer = -1 });
    _ = try b.applySemanticOverride(.right_forearm, .{ .body_part_layer = 99 });
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 32, 1);
    defer batch.deinit();
    batch.beginFrame();
    _ = try a.submitAttachments(&batch);
    _ = try a.submittedKey(.right_hand);
    try a.reset();
    try std.testing.expectEqual(@as(usize, 0), a.activeOverrideCount());
    try std.testing.expectError(error.AttachmentNotSubmitted, a.submittedKey(.right_hand));
    try std.testing.expectEqual(@as(usize, 2), b.activeOverrideCount());
    try b.clearOverride(b_first);
    try std.testing.expectEqual(@as(usize, 1), b.activeOverrideCount());

    const instances = [_]*character.CharacterInstance{ &a, &b };
    try character.resetAll(&instances);
    try std.testing.expectEqual(humanoid.Facing.right, a.facingDirection());
    try std.testing.expectEqual(humanoid.Facing.left, b.facingDirection());
    try std.testing.expectEqual(@as(usize, 0), a.activeOverrideCount());
    try std.testing.expectEqual(@as(usize, 0), b.activeOverrideCount());
    try std.testing.expectEqual(@as(u16, 0), a.actorLayer());
    try std.testing.expectEqual(@as(u16, 1), b.actorLayer());
}

const ControllerReplayResult = struct {
    position: math.Vec2,
    velocity: math.Vec2,
    grounded: bool,
    support: ?u16,
    landing_count: u32,
};

fn runControllerReplay(with_passive_character: bool) !ControllerReplayResult {
    var demo = try humanoid.DemoCharacter.init(std.testing.allocator, null);
    defer demo.deinit();
    var animation = try animation_system.Runtime.init(std.testing.allocator, &demo.definition, null);
    defer animation.deinit();
    var simulation = try controller_demo.Runtime.init(std.testing.allocator, null);
    defer simulation.deinit();
    var passive: ?character.CharacterInstance = null;
    defer if (passive) |*instance| instance.deinit();
    if (with_passive_character) {
        passive = try character.CharacterInstance.init(
            std.testing.allocator,
            try character.entityIdFromRaw(2),
            &demo.definition,
            &animation.definitions,
            .{ .x = 1.5, .y = 1.05 },
            .left,
            1,
            null,
        );
    }
    var script = controller_demo.ScriptedInput{};
    for (0..600) |_| {
        const snapshot = try script.nextFrame(&simulation.controller);
        try simulation.acceptFrameInput(snapshot);
        const frame = try simulation.beginFrame(1.0 / 60.0);
        for (0..frame.substeps) |_| {
            const tick = try simulation.simulateTick(&animation, &demo.character, &demo.definition);
            script.observe(tick, &simulation.controller);
            if (passive) |*instance| try instance.advanceVisualTick(.{});
        }
    }
    if (!script.completed()) return error.ScriptedControllerMilestonesIncomplete;
    return .{
        .position = simulation.controller.state.position,
        .velocity = simulation.controller.state.velocity,
        .grounded = simulation.controller.state.grounded,
        .support = simulation.controller.state.supporting_collider,
        .landing_count = simulation.metrics.landing_events,
    };
}

test "passive second character preserves the controlled scripted physics result" {
    const single = try runControllerReplay(false);
    const pair = try runControllerReplay(true);
    try expectVec(single.position, pair.position);
    try expectVec(single.velocity, pair.velocity);
    try std.testing.expectEqual(single.grounded, pair.grounded);
    try std.testing.expectEqual(single.support, pair.support);
    try std.testing.expectEqual(single.landing_count, pair.landing_count);
}

test "draw-order mutations leave animation procedural pose and physics state invariant" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var baseline = try initInstance(&fixture, 1, .{ .x = 0, .y = 1.05 }, .right, 0);
    defer baseline.deinit();
    var reordered = try initInstance(&fixture, 2, .{ .x = 0, .y = 1.05 }, .right, 0);
    defer reordered.deinit();
    try baseline.enterAnimationState(.walk);
    try reordered.enterAnimationState(.walk);

    for (0..480) |tick| {
        if (tick % 40 == 0) {
            reordered.clearOverrides();
            try reordered.setActorLayer(@intCast((tick / 40) % 3));
            _ = try reordered.applySemanticOverride(.right_hand, .{ .interaction_layer = if ((tick / 40) % 2 == 0) 1 else -1 });
        }
        try baseline.advanceVisualTick(.{ .horizontal_velocity = 2.2 });
        try reordered.advanceVisualTick(.{ .horizontal_velocity = 2.2 });
    }
    try std.testing.expectApproxEqAbs(baseline.animationTime(), reordered.animationTime(), tolerance);
    const baseline_procedural = baseline.proceduralSnapshot();
    const reordered_procedural = reordered.proceduralSnapshot();
    try std.testing.expectApproxEqAbs(baseline_procedural.walk_bounce_offset, reordered_procedural.walk_bounce_offset, tolerance);
    try std.testing.expectApproxEqAbs(baseline_procedural.landing_spring.offset, reordered_procedural.landing_spring.offset, tolerance);
    try std.testing.expectApproxEqAbs(baseline_procedural.secondary_spring.offset, reordered_procedural.secondary_spring.offset, tolerance);
    for (baseline.humanoidView().local_and_world_pose.local_transforms, reordered.humanoidView().local_and_world_pose.local_transforms) |left, right| {
        try std.testing.expect(left.approxEqAbs(right, tolerance));
    }

    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    const controller = try character_controller.CharacterController.init(.{}, &world, controller_demo.spawn_position, .right);
    const physics_before = controller.state;
    try reordered.setActorLayer(7);
    reordered.clearOverrides();
    _ = try reordered.applySemanticOverride(.right_forearm, .{ .interaction_layer = 3, .body_part_layer = 80 });
    try std.testing.expectEqualDeep(physics_before, controller.state);
}

comptime {
    if (@as(f64, fixed_step.fixed_dt_seconds) != 1.0 / 240.0) @compileError("multi-character tests require the authoritative 240 Hz clock");
}

test "copied animation snapshot ordinary playback loops completion and independence" {
    var fixture = try SharedFixture.init(std.testing.allocator);
    defer fixture.deinit();
    var allocation = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const actor = try allocation.allocator().create(character.CharacterInstance);
    defer allocation.allocator().destroy(actor);
    actor.* = try character.CharacterInstance.init(allocation.allocator(), try character.entityIdFromRaw(1), &fixture.definition, &fixture.animations, .zero, .right, 0, null);
    defer actor.deinit();
    const allocated = allocation.allocations;
    const resized = allocation.resize_index;
    const initial = actor.animationPlaybackSnapshot();
    try std.testing.expectEqual(@as(usize, 128), @sizeOf(character.AnimationPlaybackSnapshot));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(character.AnimationPlaybackSnapshot));
    try std.testing.expectEqual(fixture.animations.machine.initial_state_index, initial.current_state_index);
    try std.testing.expect(initial.active_transition == null);
    try std.testing.expectEqualDeep(@as(@TypeOf(initial.playback), .{ .playback_speed = 1, .state_entered = false }), initial.playback);
    try actor.enterAnimationState(.walk);
    for (0..600) |_| try actor.advanceVisualTick(.{ .horizontal_velocity = 2 });
    const looping = actor.animationPlaybackSnapshot();
    try std.testing.expect(looping.playback.loop_count > 0);
    try std.testing.expect(!looping.playback.completed and !looping.playback.fallback_pending and !looping.playback.state_entered);
    try std.testing.expectEqual(@as(u32, 0), looping.playback.completion_count);
    try std.testing.expectEqual(actor.animationTime(), looping.playback.current_time);
    var copy = looping;
    copy.playback.current_time = 0;
    copy.playback.loop_count += 1;
    try std.testing.expectEqualDeep(looping, actor.animationPlaybackSnapshot());
    try actor.enterAnimationState(.jump_start);
    var ticks: usize = 0;
    while (!actor.animationPlaybackSnapshot().playback.fallback_pending and ticks < 240) : (ticks += 1) try actor.advanceVisualTick(.{});
    const completed = actor.animationPlaybackSnapshot();
    try std.testing.expect(completed.playback.completed and completed.playback.fallback_pending);
    try std.testing.expectEqual(@as(u32, 1), completed.playback.completion_count);
    try std.testing.expect(looping.current_state_index != completed.current_state_index);
    try std.testing.expectEqual(allocated, allocation.allocations);
    try std.testing.expectEqual(resized, allocation.resize_index);
}

test "copied animation snapshot real transitions retain both sides and all policies" {
    for ([_]bool{ false, true }) |advances| {
        var fixture = try SharedFixture.init(std.testing.allocator);
        defer fixture.deinit();
        var states = authored.authoredStates();
        states[0].playback_speed = 0.75;
        states[1].playback_speed = 1.25;
        var transitions = authored.authoredTransitions();
        transitions[0].source_advances = advances;
        transitions[0].destination_begins_immediately = !advances;
        const machine_module = @import("state_machine");
        const machine = try machine_module.Definition.init(std.testing.allocator, fixture.animations.library.clips, fixture.animations.library.token(), &states, &transitions, 0, null);
        fixture.animations.machine.deinit();
        fixture.animations.machine = machine;
        var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
        defer world.deinit();
        var allocation = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        const actor = try allocation.allocator().create(character.CharacterInstance);
        defer allocation.allocator().destroy(actor);
        actor.* = try character.CharacterInstance.initControlled(allocation.allocator(), try character.entityIdFromRaw(1), &fixture.definition, &fixture.animations, &world, .{}, controller_demo.spawn_position, .right, 0, null);
        defer actor.deinit();
        for (0..8) |_| try actor.advanceVisualTick(.{});
        const before = actor.animationPlaybackSnapshot();
        const physical = try actor.stepController(&world, .{ .move_axis = 1, .jump_pressed = false, .jump_held = false, .jump_released = false, .interact_pressed = false });
        try actor.selectControllerAnimation(physical);
        const snapshot = actor.animationPlaybackSnapshot();
        const transition = snapshot.active_transition orelse return error.ExpectedProductionTransition;
        try std.testing.expectEqual(@as(u16, 0), snapshot.current_state_index);
        try std.testing.expectEqual(@as(u16, 0), transition.source_state_index);
        try std.testing.expectEqual(@as(u16, 1), transition.destination_state_index);
        try std.testing.expectEqual(@as(f32, 0), transition.elapsed);
        try std.testing.expectEqual(@as(f32, 0.3), transition.duration);
        try std.testing.expectEqual(advances, transition.source_advances);
        try std.testing.expectEqual(!advances, transition.destination_begins_immediately);
        try std.testing.expectEqualDeep(before.playback, transition.source_playback);
        try std.testing.expectEqualDeep(before.playback, snapshot.playback);
        try std.testing.expectEqualDeep(@as(@TypeOf(transition.destination_playback), .{ .playback_speed = 1.25 }), transition.destination_playback);
        const allocated = allocation.allocations;
        const resized = allocation.resize_index;
        try actor.advanceVisualTick(.{ .horizontal_velocity = 1 });
        const after = actor.animationPlaybackSnapshot();
        const active = after.active_transition orelse return error.ExpectedProductionTransition;
        // 1e-5 covers f32 accumulation for one fixed animation tick, not replay comparison.
        const dt: f32 = @floatCast(fixed_step.fixed_dt_seconds);
        try std.testing.expectApproxEqAbs(transition.elapsed + dt, active.elapsed, tolerance);
        try std.testing.expectApproxEqAbs(transition.source_playback.current_time + (if (advances) dt * 0.75 else 0), active.source_playback.current_time, tolerance);
        try std.testing.expectApproxEqAbs(if (advances) @as(f32, 0) else dt * 1.25, active.destination_playback.current_time, tolerance);
        try std.testing.expectEqual(transition.source_playback.current_time, active.source_playback.previous_time);
        try std.testing.expect(!active.source_playback.state_entered and !active.destination_playback.state_entered);
        try std.testing.expectEqual(@as(u64, 0), active.source_playback.loop_count);
        try std.testing.expectEqual(@as(u64, 0), active.destination_playback.loop_count);
        try std.testing.expectEqual(@as(u32, 0), active.source_playback.completion_count);
        try std.testing.expectEqual(@as(u32, 0), active.destination_playback.completion_count);
        try std.testing.expect(!active.source_playback.completed and !active.destination_playback.completed);
        try std.testing.expect(!active.source_playback.fallback_pending and !active.destination_playback.fallback_pending);
        try std.testing.expect(!std.meta.eql(snapshot, after));
        var independent = after;
        independent.active_transition.?.source_advances = !advances;
        independent.active_transition.?.destination_playback.loop_count = 91;
        try std.testing.expectEqualDeep(after, actor.animationPlaybackSnapshot());
        try std.testing.expectEqual(allocated, allocation.allocations);
        try std.testing.expectEqual(resized, allocation.resize_index);
    }
}
