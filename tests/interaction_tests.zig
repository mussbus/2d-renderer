const std = @import("std");
const math = @import("math");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const handshake = @import("handshake");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");
const character = @import("character");
const state_machine = @import("state_machine");
const clip = @import("clip");
const events = @import("events");
const skeleton = @import("skeleton");
const input = @import("input");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const collider = @import("collider");
const fixed_step = @import("fixed_step");

const PairFixture = struct {
    definition: humanoid.HumanoidDefinition,
    animations: authored.Definitions,
    a: character.CharacterInstance,
    b: character.CharacterInstance,
    manager: interaction_system.Manager,

    fn init() !PairFixture {
        var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
        errdefer definition.deinit();
        var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
        errdefer animations.deinit();
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
        errdefer a.deinit();
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
        errdefer b.deinit();
        return .{
            .definition = definition,
            .animations = animations,
            .a = a,
            .b = b,
            .manager = interaction_system.Manager.init(try handshake.definition(&animations)),
        };
    }

    fn deinit(fixture: *PairFixture) void {
        fixture.b.deinit();
        fixture.a.deinit();
        fixture.animations.deinit();
        fixture.definition.deinit();
        fixture.* = undefined;
    }

    fn characters(fixture: *PairFixture) [2]*character.CharacterInstance {
        return .{ &fixture.a, &fixture.b };
    }
};

fn definitionInput() interaction.DefinitionInput {
    return .{
        .type_id = .handshake,
        .debug_name = "test_handshake",
        .declared_participant_count = 2,
        .role_a_state = .handshake_role_a,
        .role_b_state = .handshake_role_b,
        .role_a_clip_raw = @intFromEnum(clip.ClipId.handshake_role_a),
        .role_b_clip_raw = @intFromEnum(clip.ClipId.handshake_role_b),
        .role_a_socket = .right_hand,
        .role_b_socket = .right_hand,
        .allowed_start_states = .{ .idle, .walk },
        .envelope = .{
            .authored_horizontal_separation = handshake.authored_horizontal_separation,
            .minimum_horizontal_separation = handshake.minimum_horizontal_separation,
            .maximum_horizontal_separation = handshake.maximum_horizontal_separation,
            .maximum_vertical_root_difference = handshake.maximum_vertical_root_difference,
            .facing_tolerance_radians = 0,
        },
        .completion_behavior = .grounded_motion_fallback,
    };
}

fn copiedClips(animations: *const authored.Definitions) [clip.clip_count]clip.ClipDefinition {
    var result: [clip.clip_count]clip.ClipDefinition = undefined;
    for (animations.library.clips, 0..) |value, index| result[index] = value;
    return result;
}

fn initCharacter(
    definition: *const humanoid.HumanoidDefinition,
    animations: *const authored.Definitions,
    id: u32,
    position: math.Vec2,
    facing: humanoid.Facing,
) !character.CharacterInstance {
    return character.CharacterInstance.init(
        std.testing.allocator,
        try character.entityIdFromRaw(id),
        definition,
        animations,
        position,
        facing,
        @intCast(id - 1),
        null,
    );
}

fn runToTick(manager: *interaction_system.Manager, participants: []const *character.CharacterInstance, start: u64, end: u64) !void {
    var tick = start;
    while (tick <= end) : (tick += 1) try manager.updateTick(tick, participants);
}

test "authored handshake creates one immutable paired definition" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    const paired = try handshake.definition(&animations);
    try std.testing.expectEqual(interaction.TypeId.handshake, paired.type_id);
    try std.testing.expectEqual(@as(u8, 2), paired.participant_total);
    try std.testing.expectEqual(@as(u32, 144), paired.event(.contact).elapsed_tick);
    try std.testing.expectEqual(@as(u32, 288), paired.event(.release).elapsed_tick);
    try std.testing.expectEqual(@as(u32, 360), paired.event(.complete).elapsed_tick);
    try std.testing.expectEqual(@as(usize, 4), interaction_system.capacity);
}

test "paired runtime starts samples and completes from one shared tick clock" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    const characters = fixture.characters();
    const id = try fixture.manager.startPair(fixture.a.id, fixture.b.id, &characters, 10, .none);
    try std.testing.expectEqual(fixture.a.interactionOwnerId(), id.raw());
    try std.testing.expectEqual(fixture.b.interactionOwnerId(), id.raw());
    var tick: u64 = 11;
    while (tick <= 370) : (tick += 1) try fixture.manager.updateTick(tick, &characters);
    const completed = fixture.manager.instance(id).?;
    try std.testing.expectEqual(interaction.Lifecycle.completed, completed.lifecycle);
    try std.testing.expectEqual(@as(u8, 1), completed.event_counts[@intFromEnum(interaction.EventSemantic.contact)]);
    try std.testing.expectEqual(@as(u8, 1), completed.event_counts[@intFromEnum(interaction.EventSemantic.release)]);
    try std.testing.expectEqual(@as(u8, 1), completed.event_counts[@intFromEnum(interaction.EventSemantic.complete)]);
    try std.testing.expect(!fixture.a.isInteractionLocked());
    try std.testing.expect(!fixture.b.isInteractionLocked());
    try std.testing.expectEqual(@as(usize, 0), fixture.a.overrides.activeCount());
    try std.testing.expectEqual(@as(usize, 0), fixture.b.overrides.activeCount());
    try std.testing.expectEqual(fixture.a.animationTime(), fixture.b.animationTime());
    try std.testing.expectEqual(state_machine.StateId.idle, fixture.a.animationState());
    try std.testing.expectEqual(state_machine.StateId.idle, fixture.b.animationState());
    try std.testing.expect(std.math.isFinite(completed.contact.separation));
    try std.testing.expect(!completed.contact.role_a_socket.approxEqAbs(math.Vec2.zero, 0.000001));
}

test "interaction definition rejects invalid roles durations events counts and finite configuration" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    var definition_input = definitionInput();
    definition_input.declared_participant_count = 1;
    try std.testing.expectError(error.InvalidParticipantCount, interaction.Definition.init(definition_input, fixture.animations.library.clips, &fixture.animations.machine));

    definition_input = definitionInput();
    definition_input.role_b_clip_raw = 255;
    try std.testing.expectError(error.InvalidRoleClip, interaction.Definition.init(definition_input, fixture.animations.library.clips, &fixture.animations.machine));

    var clips = copiedClips(&fixture.animations);
    clips[@intFromEnum(clip.ClipId.handshake_role_b)].duration += 0.01;
    try std.testing.expectError(error.PairedClipDurationMismatch, interaction.Definition.init(definitionInput(), &clips, &fixture.animations.machine));

    clips = copiedClips(&fixture.animations);
    var a_events: [5]events.EventRecord = undefined;
    var b_events: [5]events.EventRecord = undefined;
    for (fixture.animations.library.clips[@intFromEnum(clip.ClipId.handshake_role_a)].event_records, 0..) |value, index| a_events[index] = value;
    for (fixture.animations.library.clips[@intFromEnum(clip.ClipId.handshake_role_b)].event_records, 0..) |value, index| b_events[index] = value;
    a_events[0].timestamp = 1.30;
    b_events[0].timestamp = 1.30;
    clips[@intFromEnum(clip.ClipId.handshake_role_a)].event_records = &a_events;
    clips[@intFromEnum(clip.ClipId.handshake_role_b)].event_records = &b_events;
    try std.testing.expectError(error.InvalidInteractionEventOrdering, interaction.Definition.init(definitionInput(), &clips, &fixture.animations.machine));

    a_events[0].timestamp = 0.60;
    b_events[0].timestamp = 0.60;
    a_events[2].timestamp = 1.55;
    b_events[2].timestamp = 1.55;
    try std.testing.expectError(error.InvalidInteractionEventOrdering, interaction.Definition.init(definitionInput(), &clips, &fixture.animations.machine));

    definition_input = definitionInput();
    definition_input.envelope.maximum_vertical_root_difference = std.math.nan(f32);
    try std.testing.expectError(error.NonFiniteInteractionConfiguration, interaction.Definition.init(definition_input, fixture.animations.library.clips, &fixture.animations.machine));
}

test "lifecycle transitions and authored event tick boundaries are explicit" {
    try std.testing.expect(interaction.legalTransition(.inactive, .requested));
    try std.testing.expect(interaction.legalTransition(.requested, .active));
    try std.testing.expect(interaction.legalTransition(.active, .completing));
    try std.testing.expect(interaction.legalTransition(.completing, .completed));
    try std.testing.expect(interaction.legalTransition(.active, .cancelled));
    try std.testing.expect(!interaction.legalTransition(.completed, .active));
    try std.testing.expect(!interaction.legalTransition(.cancelled, .active));
    try std.testing.expectEqual(@as(u32, 144), try interaction.timeToTick(0.60));
    try std.testing.expectEqual(@as(u32, 144), try interaction.timeToTick(0.59999));
    try std.testing.expectEqual(@as(u32, 145), try interaction.timeToTick(0.60001));
    try std.testing.expectError(error.InvalidInteractionEventTime, interaction.timeToTick(-0.01));
}

test "eligibility enforces identity locks grounding distance vertical bounds state and facing" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    const participants = fixture.characters();
    try std.testing.expect(fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).isEligible());
    try std.testing.expectEqual(interaction_system.EligibilityReason.same_entity, fixture.manager.evaluateEligibility(fixture.a.id, fixture.a.id, &participants).reason);
    try std.testing.expectEqual(interaction_system.EligibilityReason.invalid_initiator, fixture.manager.evaluateEligibility(.invalid, fixture.b.id, &participants).reason);
    try std.testing.expectEqual(interaction_system.EligibilityReason.invalid_receiver, fixture.manager.evaluateEligibility(fixture.a.id, try character.entityIdFromRaw(99), &participants).reason);

    try fixture.a.setWorldPosition(.{ .x = 0, .y = 1.05 });
    try fixture.b.setWorldPosition(.{ .x = handshake.minimum_horizontal_separation, .y = 1.05 });
    try std.testing.expect(fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).isEligible());
    try fixture.b.setWorldPosition(.{ .x = handshake.minimum_horizontal_separation - 0.0001, .y = 1.05 });
    try std.testing.expectEqual(interaction_system.EligibilityReason.too_near, fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).reason);
    try fixture.b.setWorldPosition(.{ .x = handshake.maximum_horizontal_separation, .y = 1.05 });
    try std.testing.expect(fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).isEligible());
    try fixture.b.setWorldPosition(.{ .x = handshake.maximum_horizontal_separation + 0.0001, .y = 1.05 });
    try std.testing.expectEqual(interaction_system.EligibilityReason.too_far, fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).reason);

    try fixture.b.setWorldPosition(.{ .x = handshake.authored_horizontal_separation, .y = 1.05 + handshake.maximum_vertical_root_difference });
    try std.testing.expect(fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).isEligible());
    try fixture.b.setWorldPosition(.{ .x = handshake.authored_horizontal_separation, .y = 1.05 + handshake.maximum_vertical_root_difference + 0.0001 });
    try std.testing.expectEqual(interaction_system.EligibilityReason.vertical_misalignment, fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).reason);

    try fixture.b.setWorldPosition(.{ .x = handshake.authored_horizontal_separation, .y = 1.05 });
    try fixture.b.setFacing(.right);
    try std.testing.expectEqual(interaction_system.EligibilityReason.wrong_facing, fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).reason);
    try fixture.a.setFacing(.left);
    try fixture.b.setFacing(.left);
    try std.testing.expectEqual(interaction_system.EligibilityReason.wrong_facing, fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).reason);
    try fixture.a.setFacing(.right);
    try fixture.b.setFacing(.left);

    try fixture.a.setPassiveGrounded(false);
    try std.testing.expectEqual(interaction_system.EligibilityReason.initiator_airborne, fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).reason);
    try fixture.a.setPassiveGrounded(true);
    try fixture.b.setPassiveGrounded(false);
    try std.testing.expectEqual(interaction_system.EligibilityReason.receiver_airborne, fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).reason);
    try fixture.b.setPassiveGrounded(true);
    try fixture.a.enterAnimationState(.jump_start);
    try std.testing.expectEqual(interaction_system.EligibilityReason.initiator_state_rejected, fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).reason);
    try fixture.a.enterAnimationState(.idle);

    const id = try fixture.manager.startPair(fixture.a.id, fixture.b.id, &participants, 0, .none);
    try std.testing.expectEqual(interaction_system.EligibilityReason.initiator_already_interacting, fixture.manager.evaluateEligibility(fixture.a.id, fixture.b.id, &participants).reason);
    var c = try initCharacter(&fixture.definition, &fixture.animations, 3, .{ .x = fixture.b.world_position.x - handshake.authored_horizontal_separation, .y = 1.05 }, .right);
    defer c.deinit();
    const with_c = [_]*character.CharacterInstance{ &fixture.a, &fixture.b, &c };
    try std.testing.expectEqual(interaction_system.EligibilityReason.receiver_already_interacting, fixture.manager.evaluateEligibility(c.id, fixture.b.id, &with_c).reason);
    try std.testing.expect(id != .invalid);
}

test "candidate ranking is alignment first then distance then stable entity id independent of order" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    try fixture.a.setWorldPosition(.{ .x = 0, .y = 1.05 });
    try fixture.b.setWorldPosition(.{ .x = handshake.authored_horizontal_separation + 0.01, .y = 1.05 });
    var c = try initCharacter(&fixture.definition, &fixture.animations, 3, .{ .x = handshake.authored_horizontal_separation, .y = 1.05 }, .left);
    defer c.deinit();
    const ordered = [_]*character.CharacterInstance{ &fixture.a, &fixture.b, &c };
    const reversed = [_]*character.CharacterInstance{ &c, &fixture.b, &fixture.a };
    try std.testing.expectEqual(c.id, (try fixture.manager.selectCandidate(fixture.a.id, &ordered)).receiver);
    try std.testing.expectEqual(c.id, (try fixture.manager.selectCandidate(fixture.a.id, &reversed)).receiver);

    try fixture.b.setWorldPosition(c.world_position);
    try std.testing.expectEqual(fixture.b.id, (try fixture.manager.selectCandidate(fixture.a.id, &ordered)).receiver);
    try std.testing.expectEqual(fixture.b.id, (try fixture.manager.selectCandidate(fixture.a.id, &reversed)).receiver);
    try fixture.b.setFacing(.right);
    try std.testing.expectEqual(c.id, (try fixture.manager.selectCandidate(fixture.a.id, &ordered)).receiver);
}

test "interact edge is buffered across zero steps consumed once and requires a new press" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    const participants = fixture.characters();
    var builder = input.SnapshotBuilder{};
    var pending = input.PendingInput{};
    try pending.acceptFrame(try builder.update(.{ .interact = true }));
    try std.testing.expectEqual(@as(usize, 0), fixture.manager.activeCount());
    const first_intent = pending.consumeTick();
    try std.testing.expect(first_intent.interact_pressed);
    const id = (try fixture.manager.requestFromIntent(fixture.a.id, first_intent, &participants, 0)).?;
    try std.testing.expect((try fixture.manager.requestFromIntent(fixture.a.id, pending.consumeTick(), &participants, 0)) == null);
    try runToTick(&fixture.manager, &participants, 1, 360);
    try std.testing.expectEqual(interaction.Lifecycle.completed, fixture.manager.instance(id).?.lifecycle);

    try pending.acceptFrame(try builder.update(.{ .interact = true }));
    try std.testing.expect(!(pending.consumeTick().interact_pressed));
    try pending.acceptFrame(try builder.update(.{ .interact = false }));
    _ = pending.consumeTick();
    try pending.acceptFrame(try builder.update(.{ .interact = true }));
    const second_intent = pending.consumeTick();
    try std.testing.expect(second_intent.interact_pressed);
    try std.testing.expect((try fixture.manager.requestFromIntent(fixture.a.id, second_intent, &participants, 361)) != null);
    try std.testing.expectEqual(@as(u64, 2), fixture.manager.metrics.starts);
}

test "pause freezes the shared clock single-step advances one tick and reset cancels ownership" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    const participants = fixture.characters();
    const id = try fixture.manager.startPair(fixture.a.id, fixture.b.id, &participants, 0, .none);
    var clock = try fixed_step.Clock.init(.{});
    clock.setPaused(true);
    const paused_frame = try clock.beginFrame(1.0);
    try std.testing.expectEqual(@as(u8, 0), paused_frame.substeps);
    try std.testing.expectEqual(@as(u32, 0), fixture.manager.instance(id).?.elapsed_ticks);
    clock.requestSingleStep();
    const stepped_frame = try clock.beginFrame(0);
    try std.testing.expectEqual(@as(u8, 1), stepped_frame.substeps);
    try fixture.manager.updateTick(1, &participants);
    try std.testing.expectEqual(@as(u32, 1), fixture.manager.instance(id).?.elapsed_ticks);
    const paused_again = try clock.beginFrame(0.5);
    try std.testing.expectEqual(@as(u8, 0), paused_again.substeps);
    try std.testing.expectEqual(@as(u32, 1), fixture.manager.instance(id).?.elapsed_ticks);
    try fixture.manager.reset(&participants);
    clock.reset();
    try std.testing.expectEqual(@as(usize, 0), fixture.manager.activeCount());
    try std.testing.expect(!fixture.a.isInteractionLocked() and !fixture.b.isInteractionLocked());
    try std.testing.expectEqual(interaction.Lifecycle.cancelled, fixture.manager.instance(id).?.lifecycle);
}

test "transactional start rolls back every reservation and animator fault stage" {
    const faults = [_]interaction_system.StartFault{
        .after_reserve_a,
        .after_reserve_b,
        .animator_a_transition,
        .animator_b_transition,
        .before_instance_commit,
    };
    for (faults) |fault| {
        var fixture = try PairFixture.init();
        defer fixture.deinit();
        const participants = fixture.characters();
        try std.testing.expectError(error.InjectedInteractionStartFailure, fixture.manager.startPair(fixture.a.id, fixture.b.id, &participants, 0, fault));
        try std.testing.expect(!fixture.a.isInteractionLocked());
        try std.testing.expect(!fixture.b.isInteractionLocked());
        try std.testing.expectEqual(state_machine.StateId.idle, fixture.a.animationState());
        try std.testing.expectEqual(state_machine.StateId.idle, fixture.b.animationState());
        try std.testing.expectEqual(@as(usize, 0), fixture.manager.activeCount());
        try std.testing.expectEqual(@as(usize, 0), fixture.a.overrides.activeCount());
        try std.testing.expectEqual(@as(usize, 0), fixture.b.overrides.activeCount());
    }
}

test "contact layering is partial owned and preserves unrelated overrides through release and completion" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    const unrelated = try fixture.b.applySemanticOverride(.torso, .{ .body_part_layer = 90 });
    const participants = fixture.characters();
    const id = try fixture.manager.startPair(fixture.a.id, fixture.b.id, &participants, 0, .none);
    try runToTick(&fixture.manager, &participants, 1, 144);
    try std.testing.expectEqual(@as(i32, 3), fixture.a.resolvedOrder(.right_hand).interaction_layer);
    try std.testing.expectEqual(@as(i32, 2), fixture.b.resolvedOrder(.right_hand).interaction_layer);
    try std.testing.expectEqual(@as(i32, 1), fixture.a.resolvedOrder(.right_forearm).interaction_layer);
    try std.testing.expectEqual(@as(i32, 0), fixture.a.resolvedOrder(.torso).interaction_layer);
    try std.testing.expectEqual(@as(i32, 0), fixture.b.resolvedOrder(.torso).interaction_layer);
    try std.testing.expectEqual(@as(i32, 90), fixture.b.resolvedOrder(.torso).body_part_layer);
    try runToTick(&fixture.manager, &participants, 145, 288);
    try std.testing.expectEqual(@as(usize, 0), fixture.a.overrides.activeCount());
    try std.testing.expectEqual(@as(usize, 1), fixture.b.overrides.activeCount());
    try std.testing.expectEqual(@as(i32, 90), fixture.b.resolvedOrder(.torso).body_part_layer);
    try runToTick(&fixture.manager, &participants, 289, 360);
    try std.testing.expectEqual(interaction.Lifecycle.completed, fixture.manager.instance(id).?.lifecycle);
    try std.testing.expectEqual(@as(usize, 1), fixture.b.overrides.activeCount());
    try fixture.b.clearOverride(unrelated);
}

test "cancellation before and after contact restores only owned state and is idempotent" {
    var before = try PairFixture.init();
    defer before.deinit();
    const before_participants = before.characters();
    const before_id = try before.manager.startPair(before.a.id, before.b.id, &before_participants, 0, .none);
    try before.manager.resetPassiveCharacter(before.a.id, &before_participants);
    try std.testing.expectEqual(interaction.Lifecycle.cancelled, before.manager.instance(before_id).?.lifecycle);
    try std.testing.expect(!before.a.isInteractionLocked() and !before.b.isInteractionLocked());
    try std.testing.expectEqual(state_machine.StateId.idle, before.a.animationState());
    try std.testing.expect(!(try before.manager.cancelForCharacter(before.a.id, .character_reset, &before_participants)));

    var after = try PairFixture.init();
    defer after.deinit();
    const unrelated = try after.b.applySemanticOverride(.head, .{ .interaction_layer = -1 });
    const after_participants = after.characters();
    const after_id = try after.manager.startPair(after.a.id, after.b.id, &after_participants, 0, .none);
    try runToTick(&after.manager, &after_participants, 1, 144);
    try std.testing.expect(try after.manager.cancelForCharacter(after.b.id, .scene_reset, &after_participants));
    try std.testing.expectEqual(interaction.Lifecycle.cancelled, after.manager.instance(after_id).?.lifecycle);
    try std.testing.expectEqual(@as(usize, 0), after.a.overrides.activeCount());
    try std.testing.expectEqual(@as(usize, 1), after.b.overrides.activeCount());
    try std.testing.expectEqual(@as(u8, 0), after.manager.instance(after_id).?.event_counts[@intFromEnum(interaction.EventSemantic.complete)]);
    try after.b.clearOverride(unrelated);
}

test "override capacity failure at contact cancels safely without clearing prior handles" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    var unrelated: [7]character.OverrideHandle = undefined;
    for (&unrelated) |*handle| handle.* = try fixture.a.applySemanticOverride(.torso, .{ .body_part_layer = 80 });
    const participants = fixture.characters();
    const id = try fixture.manager.startPair(fixture.a.id, fixture.b.id, &participants, 0, .none);
    try runToTick(&fixture.manager, &participants, 1, 144);
    try std.testing.expectEqual(interaction.Lifecycle.cancelled, fixture.manager.instance(id).?.lifecycle);
    try std.testing.expectEqual(interaction_system.CancellationReason.override_capacity, fixture.manager.instance(id).?.cancellation_reason);
    try std.testing.expectEqual(@as(usize, 7), fixture.a.overrides.activeCount());
    try std.testing.expectEqual(@as(usize, 0), fixture.b.overrides.activeCount());
    try std.testing.expect(!fixture.a.isInteractionLocked() and !fixture.b.isInteractionLocked());
    for (unrelated) |handle| try fixture.a.clearOverride(handle);
}

test "four-slot pool reports overflow before locking a fifth pair" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var instances: [10]character.CharacterInstance = undefined;
    var initialized: usize = 0;
    defer {
        var index = initialized;
        while (index > 0) {
            index -= 1;
            instances[index].deinit();
        }
    }
    var participants: [10]*character.CharacterInstance = undefined;
    for (0..instances.len) |index| {
        const pair_index = index / 2;
        const left = index % 2 == 0;
        const center: f32 = @as(f32, @floatFromInt(pair_index)) * 10;
        const offset: f32 = if (left) -1.86 else 1.86;
        instances[index] = try initCharacter(
            &definition,
            &animations,
            @intCast(index + 1),
            .{ .x = center + offset, .y = 1.05 },
            if (left) .right else .left,
        );
        initialized += 1;
        participants[index] = &instances[index];
    }
    var manager = interaction_system.Manager.init(try handshake.definition(&animations));
    for (0..interaction_system.capacity) |pair_index| {
        _ = try manager.startPair(instances[pair_index * 2].id, instances[pair_index * 2 + 1].id, &participants, 0, .none);
    }
    try std.testing.expectEqual(interaction_system.capacity, manager.activeCount());
    try std.testing.expectError(error.InteractionCapacityExceeded, manager.startPair(instances[8].id, instances[9].id, &participants, 0, .none));
    try std.testing.expect(!instances[8].isInteractionLocked());
    try std.testing.expect(!instances[9].isInteractionLocked());
}

test "interaction IDs issue maximum u32 once and never wrap" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    const participants = fixture.characters();
    fixture.manager.next_id = std.math.maxInt(u32);
    const maximum = try fixture.manager.startPair(fixture.a.id, fixture.b.id, &participants, 0, .none);
    try std.testing.expectEqual(std.math.maxInt(u32), maximum.raw());
    try fixture.manager.reset(&participants);
    try std.testing.expectError(error.InteractionIdOverflow, fixture.manager.startPair(fixture.a.id, fixture.b.id, &participants, 1, .none));
    try std.testing.expect(!fixture.a.isInteractionLocked() and !fixture.b.isInteractionLocked());
}

test "AB ownership blocks C to B while AB and CD remain independent" {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    var c = try initCharacter(&fixture.definition, &fixture.animations, 3, .{ .x = 8.14, .y = 1.05 }, .right);
    defer c.deinit();
    var d = try initCharacter(&fixture.definition, &fixture.animations, 4, .{ .x = 11.86, .y = 1.05 }, .left);
    defer d.deinit();
    const participants = [_]*character.CharacterInstance{ &fixture.a, &fixture.b, &c, &d };
    const ab = try fixture.manager.startPair(fixture.a.id, fixture.b.id, &participants, 0, .none);
    try std.testing.expectEqual(interaction_system.EligibilityReason.receiver_already_interacting, fixture.manager.evaluateEligibility(c.id, fixture.b.id, &participants).reason);
    try runToTick(&fixture.manager, &participants, 1, 60);
    const cd = try fixture.manager.startPair(c.id, d.id, &participants, 60, .none);
    try runToTick(&fixture.manager, &participants, 61, 144);
    try std.testing.expectEqual(interaction.Phase.contact, fixture.manager.instance(ab).?.phase);
    try std.testing.expectEqual(interaction.Phase.approach, fixture.manager.instance(cd).?.phase);
    try runToTick(&fixture.manager, &participants, 145, 204);
    try std.testing.expectEqual(interaction.Phase.contact, fixture.manager.instance(cd).?.phase);
    try std.testing.expect(fixture.a.overrides.activeCount() > 0 and c.overrides.activeCount() > 0);
    try runToTick(&fixture.manager, &participants, 205, 360);
    try std.testing.expectEqual(interaction.Lifecycle.completed, fixture.manager.instance(ab).?.lifecycle);
    try std.testing.expectEqual(interaction.Lifecycle.active, fixture.manager.instance(cd).?.lifecycle);
    try std.testing.expect(!fixture.a.isInteractionLocked() and !fixture.b.isInteractionLocked());
    try std.testing.expect(c.isInteractionLocked() and d.isInteractionLocked());
    try std.testing.expectEqual(@as(usize, 0), fixture.a.overrides.activeCount());
    try runToTick(&fixture.manager, &participants, 361, 420);
    try std.testing.expectEqual(interaction.Lifecycle.completed, fixture.manager.instance(cd).?.lifecycle);
    try std.testing.expectEqual(@as(u8, 1), fixture.manager.instance(ab).?.event_counts[@intFromEnum(interaction.EventSemantic.complete)]);
    try std.testing.expectEqual(@as(u8, 1), fixture.manager.instance(cd).?.event_counts[@intFromEnum(interaction.EventSemantic.complete)]);
}

test "mirrored arrangement preserves roles timing anatomy and socket separation" {
    var left_to_right = try PairFixture.init();
    defer left_to_right.deinit();
    const first_participants = left_to_right.characters();
    const first_id = try left_to_right.manager.startPair(left_to_right.a.id, left_to_right.b.id, &first_participants, 20, .none);
    try runToTick(&left_to_right.manager, &first_participants, 21, 164);
    const first = left_to_right.manager.instance(first_id).?.*;

    var right_to_left = try PairFixture.init();
    defer right_to_left.deinit();
    try right_to_left.a.setWorldPosition(.{ .x = 1.86, .y = 1.05 });
    try right_to_left.b.setWorldPosition(.{ .x = -1.86, .y = 1.05 });
    try right_to_left.a.setFacing(.left);
    try right_to_left.b.setFacing(.right);
    const mirrored_participants = right_to_left.characters();
    const mirrored_id = try right_to_left.manager.startPair(right_to_left.a.id, right_to_left.b.id, &mirrored_participants, 20, .none);
    try runToTick(&right_to_left.manager, &mirrored_participants, 21, 164);
    const mirrored = right_to_left.manager.instance(mirrored_id).?.*;

    try std.testing.expectEqual(left_to_right.a.id, first.participant(.initiator));
    try std.testing.expectEqual(right_to_left.a.id, mirrored.participant(.initiator));
    try std.testing.expectEqual(first.event_ticks[@intFromEnum(interaction.EventSemantic.contact)], mirrored.event_ticks[@intFromEnum(interaction.EventSemantic.contact)]);
    try std.testing.expectApproxEqAbs(first.contact.separation, mirrored.contact.separation, 0.00001);
    try std.testing.expectApproxEqAbs(first.contact.role_a_socket.x, -mirrored.contact.role_a_socket.x, 0.00001);
    try std.testing.expectApproxEqAbs(first.contact.role_b_socket.x, -mirrored.contact.role_b_socket.x, 0.00001);
    try std.testing.expectEqual(@as(i32, 3), right_to_left.a.resolvedOrder(.right_hand).interaction_layer);
    try std.testing.expectEqual(@as(i32, 2), right_to_left.b.resolvedOrder(.right_hand).interaction_layer);
}

const ScheduleEvidence = struct {
    start_tick: u64,
    event_ticks: [interaction.event_count]?u64,
    event_counts: [interaction.event_count]u8,
    lifecycle: interaction.Lifecycle,
    separation: f32,
    a_locked: bool,
    b_locked: bool,
};

fn executeSchedule(groups: []const u8) !ScheduleEvidence {
    var fixture = try PairFixture.init();
    defer fixture.deinit();
    const participants = fixture.characters();
    const id = try fixture.manager.startPair(fixture.a.id, fixture.b.id, &participants, 50, .none);
    var tick: u64 = 50;
    var group_index: usize = 0;
    while (tick < 410) {
        const substeps = groups[group_index % groups.len];
        group_index += 1;
        for (0..substeps) |_| {
            if (tick == 410) break;
            tick += 1;
            try fixture.manager.updateTick(tick, &participants);
        }
    }
    const finished = fixture.manager.instance(id).?.*;
    return .{
        .start_tick = finished.start_tick,
        .event_ticks = finished.event_ticks,
        .event_counts = finished.event_counts,
        .lifecycle = finished.lifecycle,
        .separation = finished.contact.separation,
        .a_locked = fixture.a.isInteractionLocked(),
        .b_locked = fixture.b.isInteractionLocked(),
    };
}

test "zero one and multi-substep render schedules produce identical paired results" {
    const a = try executeSchedule(&.{1});
    const b = try executeSchedule(&.{8});
    const c = try executeSchedule(&.{ 0, 1, 4, 0, 3 });
    try std.testing.expectEqualDeep(a.event_ticks, b.event_ticks);
    try std.testing.expectEqualDeep(a.event_ticks, c.event_ticks);
    try std.testing.expectEqualDeep(a.event_counts, b.event_counts);
    try std.testing.expectEqualDeep(a.event_counts, c.event_counts);
    try std.testing.expectEqual(a.lifecycle, b.lifecycle);
    try std.testing.expectEqual(a.lifecycle, c.lifecycle);
    try std.testing.expectApproxEqAbs(a.separation, b.separation, 0.000001);
    try std.testing.expectApproxEqAbs(a.separation, c.separation, 0.000001);
    try std.testing.expect(!a.a_locked and !a.b_locked and !b.a_locked and !b.b_locked and !c.a_locked and !c.b_locked);
}

test "interaction sampling and socket measurement leave authoritative controller physics unchanged" {
    const floor_input = [_]collider.StaticColliderInput{.{
        .id = 1,
        .bounds = .{ .minimum = .{ .x = -10, .y = -1 }, .maximum = .{ .x = 10, .y = 0 } },
    }};
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &floor_input, null);
    defer world.deinit();
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var control_a = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(1), &definition, &animations, &world, character_controller.Configuration{}, .{ .x = -1.86, .y = 1.05 }, .right, 0, null);
    defer control_a.deinit();
    var control_b = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(2), &definition, &animations, &world, character_controller.Configuration{}, .{ .x = 1.86, .y = 1.05 }, .left, 1, null);
    defer control_b.deinit();
    var active_a = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(3), &definition, &animations, &world, character_controller.Configuration{}, .{ .x = -1.86, .y = 1.05 }, .right, 2, null);
    defer active_a.deinit();
    var active_b = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(4), &definition, &animations, &world, character_controller.Configuration{}, .{ .x = 1.86, .y = 1.05 }, .left, 3, null);
    defer active_b.deinit();
    const active_participants = [_]*character.CharacterInstance{ &active_a, &active_b };
    var manager = interaction_system.Manager.init(try handshake.definition(&animations));
    _ = try manager.startPair(active_a.id, active_b.id, &active_participants, 0, .none);
    const no_input = input.CharacterIntent{ .move_axis = 0, .jump_pressed = false, .jump_held = false, .jump_released = false, .interact_pressed = false };
    for (1..361) |tick| {
        _ = try control_a.stepController(&world, no_input);
        _ = try control_b.stepController(&world, no_input);
        _ = try active_a.stepController(&world, no_input);
        _ = try active_b.stepController(&world, no_input);
        try manager.updateTick(@intCast(tick), &active_participants);
    }
    const control_states = [_]character_controller.State{ control_a.controller.?.state, control_b.controller.?.state };
    const active_states = [_]character_controller.State{ active_a.controller.?.state, active_b.controller.?.state };
    for (control_states, active_states) |expected, actual| {
        try std.testing.expect(expected.position.approxEqAbs(actual.position, 0.000001));
        try std.testing.expect(expected.velocity.approxEqAbs(actual.velocity, 0.000001));
        try std.testing.expectEqual(expected.grounded, actual.grounded);
        try std.testing.expectEqual(expected.supporting_collider, actual.supporting_collider);
    }
}
