const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const pose = @import("pose");
const humanoid = @import("humanoid");
const sprite = @import("sprite_batch");
const fault_injection = @import("fault_injection");

const tolerance: f32 = 1e-5;

fn expectVec(expected: math.Vec2, actual: math.Vec2) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
}

fn makeDefinition() !humanoid.HumanoidDefinition {
    return humanoid.HumanoidDefinition.init(std.testing.allocator, null);
}

test "valid humanoid definition has stable semantics sockets order and no per-bone allocation" {
    var definition = try makeDefinition();
    defer definition.deinit();
    try std.testing.expectEqual(@as(usize, 16), definition.skeleton_definition.boneCount());
    try std.testing.expectEqual(@as(usize, 4), definition.skeleton_definition.socketCount());
    try std.testing.expectEqual(@as(usize, 15), definition.attachments.len);
    try std.testing.expectEqual(@as(u16, 0), try definition.skeleton_definition.boneIndex(.root));
    try std.testing.expectEqual(@as(u16, 9), try definition.skeleton_definition.boneIndex(.right_hand));
    try std.testing.expectEqual(@as(u16, 1), try definition.skeleton_definition.socketIndex(.right_hand));
    for (definition.skeleton_definition.evaluation_order, 0..) |bone_index, order_index| {
        const bone = try definition.skeleton_definition.bone(bone_index);
        if (bone.parent_index != skeleton.no_parent) {
            var parent_order: ?usize = null;
            for (definition.skeleton_definition.evaluation_order[0..order_index], 0..) |candidate, index| {
                if (candidate == bone.parent_index) parent_order = index;
            }
            try std.testing.expect(parent_order != null);
        }
    }
}

test "invalid parent self-parent cycles roots and semantics are rejected transactionally" {
    const sockets = humanoid.socketInputs();

    var invalid_parent = humanoid.boneInputs();
    invalid_parent[5].parent_index = 99;
    try std.testing.expectError(error.InvalidParentIndex, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &invalid_parent, &sockets, null));

    var self_parent = humanoid.boneInputs();
    self_parent[5].parent_index = 5;
    try std.testing.expectError(error.SelfParent, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &self_parent, &sockets, null));

    var two_cycle = humanoid.boneInputs();
    two_cycle[4].parent_index = 5;
    two_cycle[5].parent_index = 4;
    try std.testing.expectError(error.HierarchyCycle, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &two_cycle, &sockets, null));

    var long_cycle = humanoid.boneInputs();
    long_cycle[4].parent_index = 5;
    long_cycle[5].parent_index = 6;
    long_cycle[6].parent_index = 4;
    try std.testing.expectError(error.HierarchyCycle, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &long_cycle, &sockets, null));

    var no_root = humanoid.boneInputs();
    no_root[0].parent_index = 1;
    try std.testing.expectError(error.MissingRoot, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &no_root, &sockets, null));

    var multiple_roots = humanoid.boneInputs();
    multiple_roots[3].parent_index = null;
    try std.testing.expectError(error.MultipleRoots, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &multiple_roots, &sockets, null));

    var duplicate_semantic = humanoid.boneInputs();
    duplicate_semantic[3].semantic = @intFromEnum(skeleton.BoneSemantic.pelvis);
    try std.testing.expectError(error.DuplicateSemantic, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &duplicate_semantic, &sockets, null));

    var invalid_semantic = humanoid.boneInputs();
    invalid_semantic[3].semantic = 255;
    try std.testing.expectError(error.InvalidSemantic, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &invalid_semantic, &sockets, null));

    const missing_semantic = humanoid.boneInputs();
    try std.testing.expectError(error.MissingRequiredSemantic, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, missing_semantic[0..15], &sockets, null));
}

test "authored count name and ordering policies are enforced" {
    const sockets = humanoid.socketInputs();
    const no_bones = [_]skeleton.BoneDefinitionInput{};
    try std.testing.expectError(error.ZeroBoneDefinition, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &no_bones, &sockets, null));

    var too_many_bones: [skeleton.maximum_bones + 1]skeleton.BoneDefinitionInput = undefined;
    try std.testing.expectError(error.SupportedCountOverflow, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &too_many_bones, &sockets, null));

    const bones = humanoid.boneInputs();
    var too_many_sockets: [skeleton.maximum_sockets + 1]skeleton.SocketDefinitionInput = undefined;
    try std.testing.expectError(error.SupportedCountOverflow, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &bones, &too_many_sockets, null));

    var empty_name = bones;
    empty_name[3].debug_name = "";
    try std.testing.expectError(error.EmptyDebugName, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &empty_name, &sockets, null));

    var duplicate_name = bones;
    duplicate_name[3].debug_name = "torso";
    try std.testing.expectError(error.DuplicateDebugName, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &duplicate_name, &sockets, null));

    try std.testing.expectError(error.MissingRequiredSocket, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &bones, sockets[0..3], null));

    var out_of_order = bones;
    const upper_arm = out_of_order[4];
    out_of_order[4] = out_of_order[5];
    out_of_order[5] = upper_arm;
    out_of_order[4].parent_index = 5;
    out_of_order[6].parent_index = 4;
    var definition = try skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &out_of_order, &sockets, null);
    defer definition.deinit();
    var upper_order: ?usize = null;
    var forearm_order: ?usize = null;
    for (definition.evaluation_order, 0..) |bone_index, index| {
        if (bone_index == 5) upper_order = index;
        if (bone_index == 4) forearm_order = index;
    }
    try std.testing.expect(upper_order.? < forearm_order.?);
}

test "non-finite rest and malformed sockets fail before publication" {
    const valid_bones = humanoid.boneInputs();
    const valid_sockets = humanoid.socketInputs();

    var non_finite = valid_bones;
    non_finite[8].rest_local.rotation_radians = std.math.inf(f32);
    try std.testing.expectError(error.NonFiniteTransform, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &non_finite, &valid_sockets, null));

    var invalid_parent = valid_sockets;
    invalid_parent[0].parent_bone = 99;
    try std.testing.expectError(error.InvalidSocketParent, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &valid_bones, &invalid_parent, null));

    var duplicate = valid_sockets;
    duplicate[1].semantic = @intFromEnum(skeleton.SocketSemantic.left_hand);
    try std.testing.expectError(error.DuplicateSocket, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &valid_bones, &duplicate, null));

    var invalid_transform = valid_sockets;
    invalid_transform[0].local_to_bone.translation.x = std.math.nan(f32);
    try std.testing.expectError(error.NonFiniteTransform, skeleton.SkeletonDefinition.initHumanoid(std.testing.allocator, &valid_bones, &invalid_transform, null));
}

test "humanoid allocation fault stages clean up transactionally and allow a later clean instance" {
    for (fault_injection.humanoid_initialization_stages) |stage| {
        var attempt = humanoid.DemoCharacter.init(std.testing.allocator, .{ .fail_after = stage }) catch |err| {
            try std.testing.expectEqual(error.InjectedInitializationFailure, err);
            var clean = try humanoid.DemoCharacter.init(std.testing.allocator, null);
            clean.deinit();
            continue;
        };
        attempt.deinit();
        return error.FaultInjectionDidNotTrigger;
    }
}

test "rest pose hierarchy and sockets match independent world positions" {
    var definition = try makeDefinition();
    defer definition.deinit();
    var pose_state = try pose.Pose.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer pose_state.deinit();
    try pose_state.evaluateWorld(&definition.skeleton_definition, math.Transform2D.identity());

    try expectVec(.{ .x = 1.9, .y = 2.25 }, try pose_state.socketPosition(&definition.skeleton_definition, .right_hand));
    try expectVec(.{ .x = -1.9, .y = 2.25 }, try pose_state.socketPosition(&definition.skeleton_definition, .left_hand));
    try expectVec(.{ .x = 0.15, .y = -1.05 }, try pose_state.socketPosition(&definition.skeleton_definition, .left_foot));
    try expectVec(.{ .x = 0.55, .y = -1.05 }, try pose_state.socketPosition(&definition.skeleton_definition, .right_foot));

    const right_elbow = (try pose_state.worldForSemantic(&definition.skeleton_definition, .right_forearm)).translationPart();
    try expectVec(.{ .x = 1.1, .y = 2.25 }, right_elbow);
}

test "pose restoration repeated evaluation and character transforms are independent" {
    var definition = try makeDefinition();
    defer definition.deinit();
    var pose_state = try pose.Pose.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer pose_state.deinit();

    const hand_index = try definition.skeleton_definition.boneIndex(.right_hand);
    const rest_hand = definition.skeleton_definition.bones[hand_index].rest_local;
    var changed = rest_hand;
    changed.rotation_radians = 0.4;
    try pose_state.setLocal(hand_index, changed);
    try pose_state.restoreBoneToRest(&definition.skeleton_definition, hand_index);
    try std.testing.expect(rest_hand.approxEqAbs(pose_state.local_transforms[hand_index], tolerance));

    try pose_state.evaluateWorld(&definition.skeleton_definition, math.Transform2D.init(.{ .x = 3, .y = 4 }, 0, math.Vec2.one));
    try expectVec(.{ .x = 4.9, .y = 6.25 }, try pose_state.socketPosition(&definition.skeleton_definition, .right_hand));
    const first = try pose_state.worldForSemantic(&definition.skeleton_definition, .right_hand);
    try pose_state.evaluateWorld(&definition.skeleton_definition, math.Transform2D.init(.{ .x = 3, .y = 4 }, 0, math.Vec2.one));
    const second = try pose_state.worldForSemantic(&definition.skeleton_definition, .right_hand);
    try std.testing.expect(first.approxEqAbs(second, tolerance));

    try pose_state.evaluateWorld(&definition.skeleton_definition, math.Transform2D.init(math.Vec2.zero, std.math.pi / 2.0, math.Vec2.one));
    try expectVec(.{ .x = -2.25, .y = 1.9 }, try pose_state.socketPosition(&definition.skeleton_definition, .right_hand));
}

test "two poses share one immutable definition without sharing mutable state" {
    var definition = try makeDefinition();
    defer definition.deinit();
    const rest_upper = definition.skeleton_definition.bones[try definition.skeleton_definition.boneIndex(.right_upper_arm)].rest_local;
    var pose_a = try pose.Pose.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer pose_a.deinit();
    var pose_b = try pose.Pose.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer pose_b.deinit();

    var modified = rest_upper;
    modified.rotation_radians = std.math.pi / 2.0;
    try pose_a.setLocalSemantic(&definition.skeleton_definition, .right_upper_arm, modified);
    try pose_a.evaluateWorld(&definition.skeleton_definition, math.Transform2D.init(.{ .x = 10, .y = 0 }, 0, math.Vec2.one));
    try pose_b.evaluateWorld(&definition.skeleton_definition, math.Transform2D.identity());
    const a_hand = try pose_a.socketPosition(&definition.skeleton_definition, .right_hand);
    const b_hand = try pose_b.socketPosition(&definition.skeleton_definition, .right_hand);
    try std.testing.expect(!a_hand.approxEqAbs(b_hand, tolerance));
    try expectVec(.{ .x = 1.9, .y = 2.25 }, b_hand);
    try std.testing.expect(rest_upper.approxEqAbs(definition.skeleton_definition.bones[try definition.skeleton_definition.boneIndex(.right_upper_arm)].rest_local, tolerance));

    try pose_a.restoreAllToRest(&definition.skeleton_definition);
    try expectVec(.{ .x = 1.9, .y = 2.25 }, try pose_b.socketPosition(&definition.skeleton_definition, .right_hand));
}

test "pose length and definition mismatch are rejected before indexing" {
    var definition_a = try makeDefinition();
    defer definition_a.deinit();
    var definition_b = try makeDefinition();
    defer definition_b.deinit();
    var pose_state = try pose.Pose.init(std.testing.allocator, &definition_a.skeleton_definition, null);
    defer pose_state.deinit();
    try std.testing.expectError(error.PoseDefinitionMismatch, pose_state.validateCompatibility(&definition_b.skeleton_definition));

    const original = pose_state.local_transforms;
    pose_state.local_transforms = original[0 .. original.len - 1];
    try std.testing.expectError(error.PoseLengthMismatch, pose_state.validateCompatibility(&definition_a.skeleton_definition));
    pose_state.local_transforms = original;
}

test "definition outlives poses and invalid bone access is checked" {
    var definition = try makeDefinition();
    defer definition.deinit();
    {
        var temporary_pose = try pose.Pose.init(std.testing.allocator, &definition.skeleton_definition, null);
        temporary_pose.deinit();
    }
    try std.testing.expectEqual(@as(u16, 7), try definition.skeleton_definition.boneIndex(.right_upper_arm));
    try std.testing.expectError(error.InvalidBoneIndex, definition.skeleton_definition.bone(99));
}

test "socket evaluation includes multiple rotated and scaled ancestors" {
    var definition = try makeDefinition();
    defer definition.deinit();
    var pose_state = try pose.Pose.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer pose_state.deinit();

    var upper = try pose_state.localForSemantic(&definition.skeleton_definition, .right_upper_arm);
    upper.rotation_radians = std.math.pi / 2.0;
    try pose_state.setLocalSemantic(&definition.skeleton_definition, .right_upper_arm, upper);
    var forearm = try pose_state.localForSemantic(&definition.skeleton_definition, .right_forearm);
    forearm.rotation_radians = std.math.pi / 2.0;
    try pose_state.setLocalSemantic(&definition.skeleton_definition, .right_forearm, forearm);
    try pose_state.evaluateWorld(&definition.skeleton_definition, math.Transform2D.identity());
    try expectVec(.{ .x = -0.35, .y = 2.9 }, try pose_state.socketPosition(&definition.skeleton_definition, .right_hand));

    try pose_state.restoreAllToRest(&definition.skeleton_definition);
    var torso = try pose_state.localForSemantic(&definition.skeleton_definition, .torso);
    torso.scale = .{ .x = 2, .y = 3 };
    try pose_state.setLocalSemantic(&definition.skeleton_definition, .torso, torso);
    try pose_state.evaluateWorld(&definition.skeleton_definition, math.Transform2D.identity());
    try expectVec(.{ .x = 3.8, .y = 4.25 }, try pose_state.socketPosition(&definition.skeleton_definition, .right_hand));
    try std.testing.expectError(error.InvalidSocketIndex, definition.skeleton_definition.socket(99));
}

test "attachments follow hierarchy preserve pivots layers page and pose immutability" {
    var demo = try humanoid.DemoCharacter.init(std.testing.allocator, null);
    defer demo.deinit();
    try demo.character.applyProgrammaticPose(&demo.definition, 0);
    const right_hand_attachment = demo.definition.attachment(.right_hand);
    const right_hand_world = try demo.character.attachmentWorld(&demo.definition, right_hand_attachment);
    try expectVec(.{ .x = 1.65, .y = 2.25 }, right_hand_world.translationPart());

    var local_copy: [skeleton.maximum_bones]math.Transform2D = undefined;
    @memcpy(local_copy[0..demo.character.local_and_world_pose.local_transforms.len], demo.character.local_and_world_pose.local_transforms);
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 32, 1);
    defer batch.deinit();
    batch.beginFrame();
    const submitted = try demo.character.submitAttachments(&demo.definition, &batch, 7);
    try std.testing.expectEqual(@as(u32, humanoid.attachment_count), submitted);
    const prepared = batch.prepare();
    try std.testing.expectEqual(@as(usize, humanoid.attachment_count), prepared.sprites.len);
    try std.testing.expectEqual(@as(usize, 1), prepared.ranges.len);
    for (demo.character.local_and_world_pose.local_transforms, 0..) |local, index| {
        try std.testing.expect(local.approxEqAbs(local_copy[index], tolerance));
    }
    var found_hand = false;
    for (prepared.sprites) |submission| {
        try std.testing.expectEqual(@as(u32, 0), submission.texture_page);
        if (submission.order.body_part_layer == 62) {
            found_hand = true;
            try std.testing.expectEqual(right_hand_attachment.pivot, submission.pivot);
            try std.testing.expectEqual(@as(u16, 7), submission.order.actor_layer);
        }
    }
    try std.testing.expect(found_hand);
}

test "attachment validation retains texture-page and parent checks" {
    const bones = humanoid.boneInputs();
    const sockets = humanoid.socketInputs();
    var attachments = humanoid.attachmentInputs();
    attachments[0].texture_page = 1;
    try std.testing.expectError(error.InvalidTexturePage, humanoid.HumanoidDefinition.initFromInputs(std.testing.allocator, &bones, &sockets, &attachments, null));
    attachments = humanoid.attachmentInputs();
    attachments[0].parent_bone = 99;
    try std.testing.expectError(error.InvalidAttachmentParent, humanoid.HumanoidDefinition.initFromInputs(std.testing.allocator, &bones, &sockets, &attachments, null));
    attachments = humanoid.attachmentInputs();
    try std.testing.expectError(error.AttachmentLengthMismatch, humanoid.HumanoidDefinition.initFromInputs(std.testing.allocator, &bones, &sockets, attachments[0 .. attachments.len - 1], null));
}

test "pose socket and attachment submission allocate zero bytes after initialization" {
    var storage: [64 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var demo = try humanoid.DemoCharacter.init(fixed.allocator(), null);
    defer demo.deinit();
    var batch = try sprite.SpriteBatch.init(fixed.allocator(), 32, 1);
    defer batch.deinit();
    batch.markStabilized();
    const initialized_bytes = fixed.end_index;

    try demo.character.applyProgrammaticPose(&demo.definition, 180);
    _ = try demo.character.local_and_world_pose.socketPosition(&demo.definition.skeleton_definition, .right_hand);
    batch.beginFrame();
    _ = try demo.character.submitAttachments(&demo.definition, &batch, 0);
    _ = batch.prepare();
    try std.testing.expectEqual(initialized_bytes, fixed.end_index);
    try std.testing.expectEqual(@as(u64, 0), batch.lifetime_metrics.cpu_allocations_after_stabilization);
}
