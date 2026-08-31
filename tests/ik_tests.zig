const std = @import("std");
const math = @import("math");
const two_bone = @import("two_bone_ik");
const arm_ik = @import("arm_ik");
const humanoid = @import("humanoid");
const skeleton = @import("skeleton");
const authored = @import("authored_clips");
const character = @import("character");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const collision_world = @import("collision_world");
const collider = @import("collider");

const geometry_tolerance: f32 = 0.0001;
const integration_tolerance: f32 = 0.0002;

const PairFixture = struct {
    definition: humanoid.HumanoidDefinition,
    animations: authored.Definitions,
    a: character.CharacterInstance,
    b: character.CharacterInstance,
    manager: interaction_system.Manager,

    fn init(spacing: f32, mirrored: bool, ik_enabled: bool) !PairFixture {
        var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
        errdefer definition.deinit();
        var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
        errdefer animations.deinit();
        const a_x: f32 = if (mirrored) spacing * 0.5 else -spacing * 0.5;
        const b_x: f32 = -a_x;
        var a = try character.CharacterInstance.init(
            std.testing.allocator,
            try character.entityIdFromRaw(1),
            &definition,
            &animations,
            .{ .x = a_x, .y = 1.05 },
            if (mirrored) .left else .right,
            0,
            null,
        );
        errdefer a.deinit();
        var b = try character.CharacterInstance.init(
            std.testing.allocator,
            try character.entityIdFromRaw(2),
            &definition,
            &animations,
            .{ .x = b_x, .y = 1.05 },
            if (mirrored) .right else .left,
            1,
            null,
        );
        errdefer b.deinit();
        const paired = try handshake.definition(&animations);
        return .{
            .definition = definition,
            .animations = animations,
            .a = a,
            .b = b,
            .manager = if (ik_enabled) interaction_system.Manager.initWithIk(paired) else interaction_system.Manager.init(paired),
        };
    }

    fn deinit(fixture: *PairFixture) void {
        fixture.b.deinit();
        fixture.a.deinit();
        fixture.animations.deinit();
        fixture.definition.deinit();
        fixture.* = undefined;
    }

    fn participants(fixture: *PairFixture) [2]*character.CharacterInstance {
        return .{ &fixture.a, &fixture.b };
    }

    fn start(fixture: *PairFixture, start_tick: u64) !interaction_system.InteractionId {
        const participants_value = fixture.participants();
        return fixture.manager.startPair(fixture.a.id(), fixture.b.id(), &participants_value, start_tick, .none);
    }

    fn runElapsed(fixture: *PairFixture, start_tick: u64, elapsed: u32) !void {
        const participants_value = fixture.participants();
        var tick = start_tick + 1;
        const final_tick = start_tick + elapsed;
        while (tick <= final_tick) : (tick += 1) try fixture.manager.updateTick(tick, &participants_value);
    }
};

fn expectLengths(result: two_bone.Result, root: math.Vec2, upper: f32, lower: f32) !void {
    try std.testing.expectApproxEqAbs(upper, result.middle_position.sub(root).length(), geometry_tolerance);
    try std.testing.expectApproxEqAbs(lower, result.end_position.sub(result.middle_position).length(), geometry_tolerance);
}

test "two bone validation rejects invalid lengths and non finite inputs while zero distance is safe" {
    const valid = two_bone.Input{
        .root = .{ .x = 0, .y = 0 },
        .upper_length = 1,
        .lower_length = 1,
        .target = .{ .x = 1, .y = 0 },
        .bend = .positive,
    };
    _ = try two_bone.solve(valid);
    var invalid = valid;
    invalid.upper_length = 0;
    try std.testing.expectError(error.InvalidSegmentLength, two_bone.solve(invalid));
    invalid = valid;
    invalid.lower_length = -1;
    try std.testing.expectError(error.InvalidSegmentLength, two_bone.solve(invalid));
    invalid = valid;
    invalid.upper_length = std.math.inf(f32);
    try std.testing.expectError(error.NonFiniteIkInput, two_bone.solve(invalid));
    invalid = valid;
    invalid.target.x = std.math.nan(f32);
    try std.testing.expectError(error.NonFiniteIkInput, two_bone.solve(invalid));
    invalid = valid;
    invalid.reference_direction = math.Vec2.zero;
    try std.testing.expectError(error.InvalidReferenceDirection, two_bone.solve(invalid));

    var zero_target = valid;
    zero_target.target = zero_target.root;
    const zero_result = try two_bone.solve(zero_target);
    try std.testing.expectEqual(two_bone.Reachability.clamped_near, zero_result.reachability);
    try std.testing.expect(zero_result.end_position.isFinite());
    try expectLengths(zero_result, zero_target.root, 1, 1);
}

test "analytical interior straight and diagonal solves preserve exact segment geometry" {
    const straight = try two_bone.solve(.{
        .root = .{ .x = 0, .y = 0 },
        .upper_length = 1,
        .lower_length = 1,
        .target = .{ .x = 1.5, .y = 0 },
        .bend = .positive,
    });
    try std.testing.expectEqual(two_bone.Reachability.reachable, straight.reachability);
    try expectLengths(straight, math.Vec2.zero, 1, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), straight.end_position.x, geometry_tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0), straight.end_position.y, geometry_tolerance);
    try std.testing.expect(straight.middle_position.y > 0);

    const diagonal = try two_bone.solve(.{
        .root = math.Vec2.zero,
        .upper_length = 3,
        .lower_length = 4,
        .target = .{ .x = 3, .y = 4 },
        .bend = .positive,
    });
    try expectLengths(diagonal, math.Vec2.zero, 3, 4);
    try std.testing.expect(diagonal.end_position.approxEqAbs(.{ .x = 3, .y = 4 }, geometry_tolerance));
    try std.testing.expect(diagonal.middle_position.approxEqAbs(.{ .x = -0.84, .y = 2.88 }, geometry_tolerance));
}

test "configured near and far boundaries clamp without stretch or non finite output" {
    const exact_max = try two_bone.solve(.{
        .root = math.Vec2.zero,
        .upper_length = 1,
        .lower_length = 1,
        .target = .{ .x = 2.0 - two_bone.reach_epsilon, .y = 0 },
        .bend = .positive,
    });
    try std.testing.expectEqual(two_bone.Reachability.reachable, exact_max.reachability);
    const beyond = try two_bone.solve(.{
        .root = math.Vec2.zero,
        .upper_length = 1,
        .lower_length = 1,
        .target = .{ .x = 5, .y = 0 },
        .bend = .positive,
    });
    try std.testing.expectEqual(two_bone.Reachability.clamped_far, beyond.reachability);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 - two_bone.reach_epsilon), beyond.end_position.length(), geometry_tolerance);
    try expectLengths(beyond, math.Vec2.zero, 1, 1);

    const exact_min = try two_bone.solve(.{
        .root = math.Vec2.zero,
        .upper_length = 2,
        .lower_length = 1,
        .target = .{ .x = 1.0 + two_bone.reach_epsilon, .y = 0 },
        .bend = .positive,
    });
    try std.testing.expectEqual(two_bone.Reachability.reachable, exact_min.reachability);
    const too_near = try two_bone.solve(.{
        .root = math.Vec2.zero,
        .upper_length = 2,
        .lower_length = 1,
        .target = .{ .x = 0.25, .y = 0 },
        .bend = .positive,
    });
    try std.testing.expectEqual(two_bone.Reachability.clamped_near, too_near.reachability);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 + two_bone.reach_epsilon), too_near.end_position.length(), geometry_tolerance);
    try expectLengths(too_near, math.Vec2.zero, 2, 1);
}

test "opposite bend signs produce opposite elbows and the same endpoint" {
    const input = two_bone.Input{
        .root = math.Vec2.zero,
        .upper_length = 1,
        .lower_length = 1,
        .target = .{ .x = 1.5, .y = 0 },
        .bend = .positive,
    };
    const positive = try two_bone.solve(input);
    var opposite = input;
    opposite.bend = .negative;
    const negative = try two_bone.solve(opposite);
    try std.testing.expectApproxEqAbs(positive.middle_position.x, negative.middle_position.x, geometry_tolerance);
    try std.testing.expectApproxEqAbs(positive.middle_position.y, -negative.middle_position.y, geometry_tolerance);
    try std.testing.expect(positive.end_position.approxEqAbs(negative.end_position, geometry_tolerance));
}

test "mirrored analytical target mirrors elbow and preserves target error" {
    const right = try two_bone.solve(.{
        .root = .{ .x = 0.2, .y = 0.1 },
        .upper_length = 0.8,
        .lower_length = 0.7,
        .target = .{ .x = 1.2, .y = 0.4 },
        .bend = .positive,
    });
    const left = try two_bone.solve(.{
        .root = .{ .x = -0.2, .y = 0.1 },
        .upper_length = 0.8,
        .lower_length = 0.7,
        .target = .{ .x = -1.2, .y = 0.4 },
        .bend = .negative,
    });
    try std.testing.expectApproxEqAbs(right.middle_position.x, -left.middle_position.x, geometry_tolerance);
    try std.testing.expectApproxEqAbs(right.middle_position.y, left.middle_position.y, geometry_tolerance);
    try std.testing.expectApproxEqAbs(right.end_position.sub(right.effective_target).length(), left.end_position.sub(left.effective_target).length(), geometry_tolerance);
}

test "near extension and moving targets retain configured elbow side and bounded angles" {
    var previous_rotation: ?f32 = null;
    var index: u32 = 0;
    while (index < 20) : (index += 1) {
        const target = math.Vec2.init(1.98 + @as(f32, @floatFromInt(index)) * 0.0000004, -0.002 + @as(f32, @floatFromInt(index)) * 0.0002);
        const result = try two_bone.solve(.{
            .root = math.Vec2.zero,
            .upper_length = 1,
            .lower_length = 1,
            .target = target,
            .bend = .positive,
        });
        const cross = target.x * result.middle_position.y - target.y * result.middle_position.x;
        try std.testing.expect(cross >= -geometry_tolerance);
        if (previous_rotation) |previous| {
            const change = try math.interpolation.signedShortestAngleDifference(previous, result.root_rotation_radians);
            try std.testing.expect(@abs(change) < 0.02);
        }
        previous_rotation = result.root_rotation_radians;
        try expectLengths(result, math.Vec2.zero, 1, 1);
    }
}

test "repeated analytical solve is bit deterministic" {
    const input = two_bone.Input{
        .root = .{ .x = -0.3, .y = 0.7 },
        .upper_length = 0.65,
        .lower_length = 0.8,
        .target = .{ .x = 0.9, .y = 1.1 },
        .bend = .positive,
    };
    const expected = try two_bone.solve(input);
    for (0..100) |_| {
        const actual = try two_bone.solve(input);
        try std.testing.expectEqualDeep(expected, actual);
    }
}

test "right arm binding validates stable indices hierarchy socket and immutable lengths" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    const binding = try arm_ik.Binding.initRightArm(&definition.skeleton_definition);
    try std.testing.expectEqual(try definition.skeleton_definition.boneIndex(.right_upper_arm), binding.root_bone);
    try std.testing.expectEqual(try definition.skeleton_definition.boneIndex(.right_forearm), binding.middle_bone);
    try std.testing.expectEqual(try definition.skeleton_definition.boneIndex(.right_hand), binding.hand_bone);
    try std.testing.expectEqual(try definition.skeleton_definition.socketIndex(.right_hand), binding.end_socket);
    try std.testing.expectApproxEqAbs(@as(f32, 0.65), binding.upper_length, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.80), binding.lower_length, 0.000001);

    const input = arm_ik.BindingInput{
        .root_bone = binding.root_bone,
        .middle_bone = binding.middle_bone,
        .hand_bone = binding.hand_bone,
        .end_socket = binding.end_socket,
        .character_local_bend = .positive,
    };
    var invalid = input;
    invalid.root_bone = @intCast(definition.skeleton_definition.boneCount());
    try std.testing.expectError(error.InvalidBoneIndex, arm_ik.Binding.init(&definition.skeleton_definition, invalid));
    invalid = input;
    invalid.end_socket = @intCast(definition.skeleton_definition.socketCount());
    try std.testing.expectError(error.InvalidSocketIndex, arm_ik.Binding.init(&definition.skeleton_definition, invalid));
    invalid = input;
    invalid.middle_bone = try definition.skeleton_definition.boneIndex(.left_forearm);
    try std.testing.expectError(error.InvalidMiddleBoneParent, arm_ik.Binding.init(&definition.skeleton_definition, invalid));
}

test "arm application weight zero preserves authored pose full weight reaches and half is intermediate" {
    var fixture = try PairFixture.init(handshake.maximum_horizontal_separation, false, true);
    defer fixture.deinit();
    try fixture.a.enterAnimationState(.handshake_role_a);
    try fixture.a.sampleInteractionAnimation(.handshake_role_a, 0.60);
    const authored_socket = try fixture.a.socketPosition(.right_hand);
    const binding = fixture.a.rightArmBinding();
    const shoulder = (try fixture.a.humanoidView().local_and_world_pose.worldForBone(&fixture.definition.skeleton_definition, binding.root_bone)).translationPart();
    const target = authored_socket.add(.{ .x = 0.01, .y = 0.006 });
    const root_before = fixture.a.worldPosition();
    const zero = try fixture.a.applyRightHandIk(target, 0);
    try std.testing.expect(zero.post_ik_hand_position.approxEqAbs(authored_socket, 0.000001));
    try fixture.a.clearRightHandIk();
    const half = try fixture.a.applyRightHandIk(target, 0.5);
    try fixture.a.clearRightHandIk();
    const full = try fixture.a.applyRightHandIk(target, 1);
    try std.testing.expect(full.target_error < integration_tolerance);
    try std.testing.expect(half.target_error < zero.target_error);
    try std.testing.expect(half.target_error > full.target_error);
    try std.testing.expectApproxEqAbs(binding.upper_length, full.solved_upper_length, integration_tolerance);
    try std.testing.expectApproxEqAbs(binding.lower_length, full.solved_lower_length, integration_tolerance);
    try std.testing.expect(fixture.a.worldPosition().approxEqAbs(root_before, 0));
    try std.testing.expect(shoulder.isFinite());
}

test "IK rotation blending follows the shortest path across pi" {
    const from = std.math.pi - 0.1;
    const to = -std.math.pi + 0.1;
    const halfway = try arm_ik.blendRotation(from, to, 0.5);
    try std.testing.expect(@abs(@abs(halfway) - std.math.pi) < 0.0001);
    try std.testing.expectError(error.InvalidIkBlendWeight, arm_ik.blendRotation(from, to, 1.1));
}

test "shared midpoint is symmetric and A then B equals B then A" {
    var first = try PairFixture.init(handshake.maximum_horizontal_separation, false, true);
    defer first.deinit();
    var second = try PairFixture.init(handshake.maximum_horizontal_separation, false, true);
    defer second.deinit();
    try first.a.enterAnimationState(.handshake_role_a);
    try first.b.enterAnimationState(.handshake_role_b);
    try second.a.enterAnimationState(.handshake_role_a);
    try second.b.enterAnimationState(.handshake_role_b);
    try first.a.sampleInteractionAnimation(.handshake_role_a, 0.60);
    try first.b.sampleInteractionAnimation(.handshake_role_b, 0.60);
    try second.a.sampleInteractionAnimation(.handshake_role_a, 0.60);
    try second.b.sampleInteractionAnimation(.handshake_role_b, 0.60);
    const pre_a = try first.a.socketPosition(.right_hand);
    const pre_b = try first.b.socketPosition(.right_hand);
    const target_ab = interaction_system.sharedTarget(pre_a, pre_b);
    const target_ba = interaction_system.sharedTarget(pre_b, pre_a);
    try std.testing.expectEqualDeep(target_ab, target_ba);
    const first_a = try first.a.applyRightHandIk(target_ab, 1);
    const first_b = try first.b.applyRightHandIk(target_ab, 1);
    const second_b = try second.b.applyRightHandIk(target_ba, 1);
    const second_a = try second.a.applyRightHandIk(target_ba, 1);
    try std.testing.expect(first_a.post_ik_hand_position.approxEqAbs(second_a.post_ik_hand_position, integration_tolerance));
    try std.testing.expect(first_b.post_ik_hand_position.approxEqAbs(second_b.post_ik_hand_position, integration_tolerance));
    try std.testing.expect(first.a.humanoidView().local_and_world_pose.local_transforms[first.a.rightArmBinding().root_bone].approxEqAbs(second.a.humanoidView().local_and_world_pose.local_transforms[second.a.rightArmBinding().root_bone], integration_tolerance));
    try std.testing.expect(first.b.humanoidView().local_and_world_pose.local_transforms[first.b.rightArmBinding().middle_bone].approxEqAbs(second.b.humanoidView().local_and_world_pose.local_transforms[second.b.rightArmBinding().middle_bone], integration_tolerance));
}

test "interaction IK weight is authoritative bounded and phase driven" {
    var fixture = try PairFixture.init(handshake.authored_horizontal_separation, false, true);
    defer fixture.deinit();
    const definition_value = fixture.manager.definitionView();
    const definition = &definition_value;
    try std.testing.expectApproxEqAbs(@as(f32, 0), interaction_system.weightForElapsed(definition, 0), 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), interaction_system.weightForElapsed(definition, definition.event(.contact).elapsed_tick / 2), 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), interaction_system.weightForElapsed(definition, definition.event(.contact).elapsed_tick), 0);
    try std.testing.expectApproxEqAbs(@as(f32, 1), interaction_system.weightForElapsed(definition, definition.event(.release).elapsed_tick), 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), interaction_system.weightForElapsed(definition, (definition.event(.release).elapsed_tick + definition.event(.complete).elapsed_tick) / 2), 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), interaction_system.weightForElapsed(definition, definition.event(.complete).elapsed_tick), 0);
}

test "nominal and perturbed handshakes converge both hands on one shared target" {
    var nominal = try PairFixture.init(handshake.authored_horizontal_separation, false, true);
    defer nominal.deinit();
    const nominal_id = try nominal.start(100);
    try nominal.runElapsed(100, nominal.manager.definitionView().event(.contact).elapsed_tick);
    const nominal_contact = nominal.manager.instance(nominal_id).?.contact;
    try std.testing.expect(nominal_contact.ik_enabled);
    try std.testing.expectApproxEqAbs(@as(f32, 0.000464), nominal_contact.pre_separation, 0.00001);
    try std.testing.expect(nominal_contact.post_separation <= nominal_contact.pre_separation);
    try std.testing.expect(nominal_contact.role_a_target_error < integration_tolerance);
    try std.testing.expect(nominal_contact.role_b_target_error < integration_tolerance);

    var perturbed = try PairFixture.init(handshake.maximum_horizontal_separation, false, true);
    defer perturbed.deinit();
    const perturbed_id = try perturbed.start(100);
    try perturbed.runElapsed(100, perturbed.manager.definitionView().event(.contact).elapsed_tick);
    const contact = perturbed.manager.instance(perturbed_id).?.contact;
    try std.testing.expect(contact.pre_separation > 0.015);
    try std.testing.expect(contact.post_separation < 0.001);
    try std.testing.expect(contact.post_separation < contact.pre_separation * 0.1);
    try std.testing.expect(contact.role_a_target_error < integration_tolerance);
    try std.testing.expect(contact.role_b_target_error < integration_tolerance);
}

test "mirrored handshake retains anatomy timing and equivalent IK error" {
    var regular = try PairFixture.init(handshake.maximum_horizontal_separation, false, true);
    defer regular.deinit();
    var mirrored = try PairFixture.init(handshake.maximum_horizontal_separation, true, true);
    defer mirrored.deinit();
    const regular_id = try regular.start(7);
    const mirrored_id = try mirrored.start(7);
    const contact_ticks = regular.manager.definitionView().event(.contact).elapsed_tick;
    try regular.runElapsed(7, contact_ticks);
    try mirrored.runElapsed(7, contact_ticks);
    const a = regular.manager.instance(regular_id).?.contact;
    const b = mirrored.manager.instance(mirrored_id).?.contact;
    try std.testing.expectApproxEqAbs(a.post_separation, b.post_separation, integration_tolerance);
    try std.testing.expectApproxEqAbs(a.role_a_target_error, b.role_a_target_error, integration_tolerance);
    try std.testing.expectApproxEqAbs(a.role_b_target_error, b.role_b_target_error, integration_tolerance);
    try std.testing.expectEqual(arm_ik.Bend.positive, regular.manager.instance(regular_id).?.ik.role_a.?.bend);
    try std.testing.expectEqual(arm_ik.Bend.negative, regular.manager.instance(regular_id).?.ik.role_b.?.bend);
    try std.testing.expectEqual(arm_ik.Bend.negative, mirrored.manager.instance(mirrored_id).?.ik.role_a.?.bend);
    try std.testing.expectEqual(arm_ik.Bend.positive, mirrored.manager.instance(mirrored_id).?.ik.role_b.?.bend);
}

const ScheduleEvidence = struct {
    weight: f32,
    target: math.Vec2,
    post_separation: f32,
};

fn executeGroupedSchedule(groups: []const u8) !ScheduleEvidence {
    var fixture = try PairFixture.init(handshake.maximum_horizontal_separation, false, true);
    defer fixture.deinit();
    const id = try fixture.start(0);
    const participants_value = fixture.participants();
    var tick: u64 = 0;
    for (groups) |group| {
        for (0..group) |_| {
            tick += 1;
            try fixture.manager.updateTick(tick, &participants_value);
        }
    }
    const current = fixture.manager.instance(id).?;
    return .{ .weight = current.ik.weight, .target = current.ik.shared_target, .post_separation = current.ik.post_hand_separation };
}

test "render grouping including zero substep frames cannot change IK state" {
    const singles = [_]u8{1} ** 144;
    const mixed = [_]u8{ 0, 8, 0, 4, 16, 0, 32, 20, 0, 24, 16, 24 };
    const a = try executeGroupedSchedule(&singles);
    const b = try executeGroupedSchedule(&mixed);
    try std.testing.expectEqualDeep(a, b);
}

test "IK enabled and disabled preserve interaction timing and controlled physics" {
    const floor_input = [_]collider.StaticColliderInput{
        .{ .id = 1, .bounds = .{ .minimum = .{ .x = -20, .y = -1 }, .maximum = .{ .x = 20, .y = 0 } } },
    };
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &floor_input, null);
    defer world.deinit();
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var disabled_a = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(1), &definition, &animations, &world, .{}, .{ .x = -1.86, .y = 1.05 }, .right, 0, null);
    defer disabled_a.deinit();
    var disabled_b = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(2), &definition, &animations, &world, .{}, .{ .x = 1.86, .y = 1.05 }, .left, 1, null);
    defer disabled_b.deinit();
    var enabled_a = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(3), &definition, &animations, &world, .{}, .{ .x = -1.86, .y = 1.05 }, .right, 2, null);
    defer enabled_a.deinit();
    var enabled_b = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(4), &definition, &animations, &world, .{}, .{ .x = 1.86, .y = 1.05 }, .left, 3, null);
    defer enabled_b.deinit();
    const paired = try handshake.definition(&animations);
    var disabled = interaction_system.Manager.init(paired);
    var enabled = interaction_system.Manager.initWithIk(paired);
    const disabled_participants = [_]*character.CharacterInstance{ &disabled_a, &disabled_b };
    const enabled_participants = [_]*character.CharacterInstance{ &enabled_a, &enabled_b };
    const disabled_id = try disabled.startPair(disabled_a.id(), disabled_b.id(), &disabled_participants, 20, .none);
    const enabled_id = try enabled.startPair(enabled_a.id(), enabled_b.id(), &enabled_participants, 20, .none);
    var tick: u64 = 21;
    while (tick <= 380) : (tick += 1) {
        try disabled.updateTick(tick, &disabled_participants);
        try enabled.updateTick(tick, &enabled_participants);
    }
    const disabled_done = disabled.instance(disabled_id).?;
    const enabled_done = enabled.instance(enabled_id).?;
    try std.testing.expectEqualDeep(disabled_done.event_ticks, enabled_done.event_ticks);
    try std.testing.expect(disabled_a.controllerSnapshot().?.state.position.approxEqAbs(enabled_a.controllerSnapshot().?.state.position, 0));
    try std.testing.expect(disabled_b.controllerSnapshot().?.state.position.approxEqAbs(enabled_b.controllerSnapshot().?.state.position, 0));
    try std.testing.expect(disabled_a.controllerSnapshot().?.state.velocity.approxEqAbs(enabled_a.controllerSnapshot().?.state.velocity, 0));
    try std.testing.expect(disabled_b.controllerSnapshot().?.state.velocity.approxEqAbs(enabled_b.controllerSnapshot().?.state.velocity, 0));
    try std.testing.expectEqual(disabled_a.controllerSnapshot().?.state.grounded, enabled_a.controllerSnapshot().?.state.grounded);
    try std.testing.expectEqual(disabled_b.controllerSnapshot().?.state.grounded, enabled_b.controllerSnapshot().?.state.grounded);
    try std.testing.expectEqual(disabled_a.controllerSnapshot().?.state.supporting_collider, enabled_a.controllerSnapshot().?.state.supporting_collider);
    try std.testing.expectEqual(disabled_b.controllerSnapshot().?.state.supporting_collider, enabled_b.controllerSnapshot().?.state.supporting_collider);
    try std.testing.expect(enabled_a.rightHandIkMetrics() == null and enabled_b.rightHandIkMetrics() == null);
}

test "cancellation at approach blend contact and release clears all IK state" {
    const elapsed_values = [_]u32{ 0, 72, 144, 300 };
    for (elapsed_values) |elapsed| {
        var fixture = try PairFixture.init(handshake.authored_horizontal_separation, false, true);
        defer fixture.deinit();
        const id = try fixture.start(10);
        try fixture.runElapsed(10, elapsed);
        const participants_value = fixture.participants();
        try std.testing.expect(try fixture.manager.cancelForCharacter(fixture.a.id(), .character_reset, &participants_value));
        const cancelled = fixture.manager.instance(id).?;
        try std.testing.expectEqual(interaction.Lifecycle.cancelled, cancelled.lifecycle);
        try std.testing.expect(!cancelled.ik.target_valid and cancelled.ik.weight == 0);
        try std.testing.expect(fixture.a.rightHandIkMetrics() == null and fixture.b.rightHandIkMetrics() == null);
        try std.testing.expect(!fixture.a.isInteractionLocked() and !fixture.b.isInteractionLocked());
        try fixture.a.advanceVisualTick(.{});
        try fixture.b.advanceVisualTick(.{});
    }
}

test "completion scene reset and character reset clear IK without disturbing unrelated characters" {
    var fixture = try PairFixture.init(handshake.authored_horizontal_separation, false, true);
    defer fixture.deinit();
    const id = try fixture.start(0);
    try fixture.runElapsed(0, fixture.manager.definitionView().event(.complete).elapsed_tick);
    const completed = fixture.manager.instance(id).?;
    try std.testing.expectEqual(interaction.Lifecycle.completed, completed.lifecycle);
    try std.testing.expect(!completed.ik.target_valid and completed.ik.weight == 0);
    try std.testing.expect(fixture.a.rightHandIkMetrics() == null and fixture.b.rightHandIkMetrics() == null);

    var active = try PairFixture.init(handshake.authored_horizontal_separation, false, true);
    defer active.deinit();
    _ = try active.start(0);
    try active.runElapsed(0, 72);
    const participants_value = active.participants();
    try active.manager.reset(&participants_value);
    try std.testing.expectEqual(@as(usize, 0), active.manager.activeCount());
    try std.testing.expect(active.a.rightHandIkMetrics() == null and active.b.rightHandIkMetrics() == null);
}

test "active participant reset clears its pair while unrelated reset leaves another pair active" {
    var active = try PairFixture.init(handshake.authored_horizontal_separation, false, true);
    defer active.deinit();
    const active_id = try active.start(0);
    try active.runElapsed(0, 72);
    const active_participants = active.participants();
    try active.manager.resetPassiveCharacter(active.a.id(), &active_participants);
    try std.testing.expectEqual(interaction.Lifecycle.cancelled, active.manager.instance(active_id).?.lifecycle);
    try std.testing.expect(active.a.rightHandIkMetrics() == null and active.b.rightHandIkMetrics() == null);
    try std.testing.expect(!active.a.isInteractionLocked() and !active.b.isInteractionLocked());

    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var a = try initPassive(&definition, &animations, 1, -1.86, .right);
    defer a.deinit();
    var b = try initPassive(&definition, &animations, 2, 1.86, .left);
    defer b.deinit();
    var unrelated = try initPassive(&definition, &animations, 3, 8, .right);
    defer unrelated.deinit();
    var manager = interaction_system.Manager.initWithIk(try handshake.definition(&animations));
    const participants_value = [_]*character.CharacterInstance{ &a, &b, &unrelated };
    const pair_id = try manager.startPair(a.id(), b.id(), &participants_value, 0, .none);
    var tick: u64 = 1;
    while (tick <= 72) : (tick += 1) try manager.updateTick(tick, &participants_value);
    const target_before = manager.instance(pair_id).?.ik.shared_target;
    try manager.resetPassiveCharacter(unrelated.id(), &participants_value);
    try std.testing.expectEqual(@as(usize, 1), manager.activeCount());
    try std.testing.expect(manager.instance(pair_id).?.ik.target_valid);
    try std.testing.expect(manager.instance(pair_id).?.ik.shared_target.approxEqAbs(target_before, 0));
}

test "simultaneous interactions own independent shared targets and cleanup" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var a = try initPassive(&definition, &animations, 1, -6.0, .right);
    defer a.deinit();
    var b = try initPassive(&definition, &animations, 2, -2.28, .left);
    defer b.deinit();
    var c = try initPassive(&definition, &animations, 3, 2.0, .right);
    defer c.deinit();
    var d = try initPassive(&definition, &animations, 4, 5.74, .left);
    defer d.deinit();
    var manager = interaction_system.Manager.initWithIk(try handshake.definition(&animations));
    const participants_value = [_]*character.CharacterInstance{ &a, &b, &c, &d };
    const ab = try manager.startPair(a.id(), b.id(), &participants_value, 0, .none);
    const cd = try manager.startPair(c.id(), d.id(), &participants_value, 0, .none);
    var tick: u64 = 1;
    while (tick <= 144) : (tick += 1) try manager.updateTick(tick, &participants_value);
    const ab_target = manager.instance(ab).?.ik.shared_target;
    const cd_target = manager.instance(cd).?.ik.shared_target;
    try std.testing.expect(!ab_target.approxEqAbs(cd_target, 0.1));
    try std.testing.expect(try manager.cancelForCharacter(a.id(), .character_reset, &participants_value));
    try std.testing.expect(!manager.instance(ab).?.ik.target_valid);
    try std.testing.expect(manager.instance(cd).?.ik.target_valid);
    try std.testing.expect(manager.instance(cd).?.ik.shared_target.approxEqAbs(cd_target, integration_tolerance));
    try std.testing.expect(c.rightHandIkMetrics() != null and d.rightHandIkMetrics() != null);
}

test "completion of one pair cannot clear a later independent pair constraint" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var a = try initPassive(&definition, &animations, 1, -6.0, .right);
    defer a.deinit();
    var b = try initPassive(&definition, &animations, 2, -2.28, .left);
    defer b.deinit();
    var c = try initPassive(&definition, &animations, 3, 2.0, .right);
    defer c.deinit();
    var d = try initPassive(&definition, &animations, 4, 5.74, .left);
    defer d.deinit();
    var manager = interaction_system.Manager.initWithIk(try handshake.definition(&animations));
    const participants_value = [_]*character.CharacterInstance{ &a, &b, &c, &d };
    const ab = try manager.startPair(a.id(), b.id(), &participants_value, 0, .none);
    var tick: u64 = 1;
    while (tick <= 100) : (tick += 1) try manager.updateTick(tick, &participants_value);
    const cd = try manager.startPair(c.id(), d.id(), &participants_value, 100, .none);
    while (tick <= 360) : (tick += 1) try manager.updateTick(tick, &participants_value);
    try std.testing.expectEqual(interaction.Lifecycle.completed, manager.instance(ab).?.lifecycle);
    try std.testing.expectEqual(interaction.Lifecycle.active, manager.instance(cd).?.lifecycle);
    try std.testing.expect(manager.instance(cd).?.ik.target_valid);
    try std.testing.expect(c.rightHandIkMetrics() != null and d.rightHandIkMetrics() != null);
}

test "unreachable character target clamps arm without root or physics mutation" {
    var fixture = try PairFixture.init(handshake.authored_horizontal_separation, false, true);
    defer fixture.deinit();
    const root_before = fixture.a.worldPosition();
    const binding = fixture.a.rightArmBinding();
    const shoulder = (try fixture.a.humanoidView().local_and_world_pose.worldForBone(&fixture.definition.skeleton_definition, binding.root_bone)).translationPart();
    const target = shoulder.add(.{ .x = 20, .y = 3 });
    const result = try fixture.a.applyRightHandIk(target, 1);
    try std.testing.expectEqual(arm_ik.Reachability.clamped_far, result.reachability);
    try std.testing.expectApproxEqAbs(binding.upper_length, result.solved_upper_length, integration_tolerance);
    try std.testing.expectApproxEqAbs(binding.lower_length, result.solved_lower_length, integration_tolerance);
    try std.testing.expectApproxEqAbs(binding.upper_length + binding.lower_length - two_bone.reach_epsilon, result.post_ik_hand_position.sub(result.shoulder_position).length(), integration_tolerance);
    try std.testing.expect(fixture.a.worldPosition().approxEqAbs(root_before, 0));
}

fn initPassive(
    definition: *const humanoid.HumanoidDefinition,
    animations: *const authored.Definitions,
    id: u32,
    x: f32,
    facing: humanoid.Facing,
) !character.CharacterInstance {
    return character.CharacterInstance.init(
        std.testing.allocator,
        try character.entityIdFromRaw(id),
        definition,
        animations,
        .{ .x = x, .y = 1.05 },
        facing,
        @intCast(id - 1),
        null,
    );
}
