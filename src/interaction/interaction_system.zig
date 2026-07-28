const std = @import("std");
const math = @import("math");
const input = @import("input");
const fixed_step = @import("fixed_step");
const humanoid = @import("humanoid");
const skeleton = @import("skeleton");
const state_machine = @import("state_machine");
const arm_ik = @import("arm_ik");
const character = @import("character");
const interaction = @import("interaction");

pub const capacity: usize = 4;
pub const maximum_owned_overrides: usize = 4;

pub const InteractionId = enum(u32) {
    invalid = 0,
    _,

    pub fn raw(id: InteractionId) u32 {
        return @intFromEnum(id);
    }
};

pub const EligibilityReason = enum(u8) {
    eligible,
    invalid_initiator,
    invalid_receiver,
    same_entity,
    initiator_already_interacting,
    receiver_already_interacting,
    initiator_airborne,
    receiver_airborne,
    initiator_state_rejected,
    receiver_state_rejected,
    too_near,
    too_far,
    vertical_misalignment,
    wrong_facing,
};

pub const Eligibility = struct {
    reason: EligibilityReason,
    horizontal_separation: f32 = 0,
    vertical_difference: f32 = 0,
    world_distance: f32 = 0,
    anchor_error: f32 = 0,

    pub fn isEligible(result: Eligibility) bool {
        return result.reason == .eligible;
    }
};

pub const CancellationReason = enum(u8) {
    none,
    startup_failure,
    participant_invalid,
    scene_reset,
    character_reset,
    pre_contact_invariant,
    override_capacity,
    ik_failure,
};

pub const StartFault = enum(u8) {
    none,
    after_reserve_a,
    after_reserve_b,
    animator_a_transition,
    animator_b_transition,
    before_instance_commit,
};

pub const OwnedOverride = struct {
    participant: character.EntityId = .invalid,
    handle: character.OverrideHandle = .invalid,
};

pub const ContactMeasurement = struct {
    captured: bool = false,
    tick: u64 = 0,
    role_a_socket: math.Vec2 = math.Vec2.zero,
    role_b_socket: math.Vec2 = math.Vec2.zero,
    separation: f32 = 0,
    ik_enabled: bool = false,
    ik_weight: f32 = 0,
    shared_target: math.Vec2 = math.Vec2.zero,
    role_a_pre_socket: math.Vec2 = math.Vec2.zero,
    role_b_pre_socket: math.Vec2 = math.Vec2.zero,
    role_a_target_error: f32 = 0,
    role_b_target_error: f32 = 0,
    pre_separation: f32 = 0,
    post_separation: f32 = 0,
    role_a_reachability: arm_ik.Reachability = .reachable,
    role_b_reachability: arm_ik.Reachability = .reachable,
};

pub const IkConstraintState = struct {
    enabled: bool = false,
    weight: f32 = 0,
    target_valid: bool = false,
    shared_target: math.Vec2 = math.Vec2.zero,
    role_a: ?arm_ik.Metrics = null,
    role_b: ?arm_ik.Metrics = null,
    pre_hand_separation: f32 = 0,
    post_hand_separation: f32 = 0,
};

pub const Instance = struct {
    id: InteractionId = .invalid,
    type_id: interaction.TypeId = .invalid,
    participant_a: character.EntityId = .invalid,
    participant_b: character.EntityId = .invalid,
    lifecycle: interaction.Lifecycle = .inactive,
    start_tick: u64 = 0,
    elapsed_ticks: u32 = 0,
    phase: interaction.Phase = .approach,
    event_consumed: [interaction.event_count]bool = [_]bool{false} ** interaction.event_count,
    event_counts: [interaction.event_count]u8 = [_]u8{0} ** interaction.event_count,
    event_ticks: [interaction.event_count]?u64 = [_]?u64{null} ** interaction.event_count,
    owned_overrides: [maximum_owned_overrides]OwnedOverride = [_]OwnedOverride{.{}} ** maximum_owned_overrides,
    owned_override_count: usize = 0,
    cancellation_reason: CancellationReason = .none,
    contact: ContactMeasurement = .{},
    ik: IkConstraintState = .{},

    pub fn participant(instance: Instance, role: interaction.Role) character.EntityId {
        return switch (role) {
            .initiator => instance.participant_a,
            .receiver => instance.participant_b,
        };
    }

    pub fn normalizedProgress(instance: Instance, definition: *const interaction.Definition) f32 {
        return @min(1, @as(f32, @floatFromInt(instance.elapsed_ticks)) /
            @as(f32, @floatFromInt(definition.authoritative_duration_ticks)));
    }

    pub fn ikWeight(instance: Instance, definition: *const interaction.Definition) f32 {
        return weightForElapsed(definition, instance.elapsed_ticks);
    }
};

const Slot = struct {
    occupied: bool = false,
    instance: Instance = .{},
};

pub const Metrics = struct {
    requests: u64 = 0,
    starts: u64 = 0,
    cancellations: u64 = 0,
    completions: u64 = 0,
    request_allocations: u64 = 0,
    eligibility_allocations: u64 = 0,
    candidate_selection_allocations: u64 = 0,
    active_update_allocations: u64 = 0,
    event_processing_allocations: u64 = 0,
    completion_allocations: u64 = 0,
    ik_solver_allocations: u64 = 0,
    ik_binding_lookup_allocations: u64 = 0,
    ik_target_computation_allocations: u64 = 0,
    ik_pose_application_allocations: u64 = 0,
    ik_hierarchy_evaluation_allocations: u64 = 0,
};

pub const Candidate = struct {
    receiver: character.EntityId,
    eligibility: Eligibility,
};

pub const Manager = struct {
    definition: interaction.Definition,
    slots: [capacity]Slot = [_]Slot{.{}} ** capacity,
    next_id: u32 = 1,
    ids_exhausted: bool = false,
    metrics: Metrics = .{},
    last_terminal: ?Instance = null,
    ik_enabled: bool = false,

    pub fn init(definition: interaction.Definition) Manager {
        return .{ .definition = definition };
    }

    pub fn initWithIk(definition: interaction.Definition) Manager {
        return .{ .definition = definition, .ik_enabled = true };
    }

    pub fn activeCount(manager: Manager) usize {
        var count: usize = 0;
        for (manager.slots) |slot| {
            if (slot.occupied) count += 1;
        }
        return count;
    }

    pub fn firstActiveInstance(manager: *const Manager) ?*const Instance {
        for (&manager.slots) |*slot| {
            if (slot.occupied) return &slot.instance;
        }
        return null;
    }

    pub fn activeOwnedOverrideCount(manager: *const Manager) usize {
        var count: usize = 0;
        for (manager.slots) |slot| {
            if (slot.occupied) count += slot.instance.owned_override_count;
        }
        return count;
    }

    pub fn activeIkConstraintCount(manager: *const Manager) usize {
        var count: usize = 0;
        for (manager.slots) |slot| {
            if (slot.occupied and slot.instance.ik.enabled) count += 1;
        }
        return count;
    }

    pub fn maximumIssuedId(manager: *const Manager) u32 {
        return if (manager.next_id == 1) 0 else manager.next_id - 1;
    }

    pub fn instance(manager: *const Manager, id: InteractionId) ?*const Instance {
        if (id == .invalid) return null;
        for (&manager.slots) |*slot| {
            if (slot.instance.id == id) return &slot.instance;
        }
        if (manager.last_terminal) |*terminal| {
            if (terminal.id == id) return terminal;
        }
        return null;
    }

    pub fn evaluateEligibility(
        manager: *const Manager,
        initiator_id: character.EntityId,
        receiver_id: character.EntityId,
        characters: []const *character.CharacterInstance,
    ) Eligibility {
        if (!initiator_id.isValid()) return .{ .reason = .invalid_initiator };
        if (!receiver_id.isValid()) return .{ .reason = .invalid_receiver };
        if (initiator_id == receiver_id) return .{ .reason = .same_entity };
        const initiator = findCharacter(characters, initiator_id) orelse return .{ .reason = .invalid_initiator };
        const receiver = findCharacter(characters, receiver_id) orelse return .{ .reason = .invalid_receiver };
        if (initiator.isInteractionLocked()) return .{ .reason = .initiator_already_interacting };
        if (receiver.isInteractionLocked()) return .{ .reason = .receiver_already_interacting };
        if (manager.definition.required_grounded and !initiator.interactionGrounded()) return .{ .reason = .initiator_airborne };
        if (manager.definition.required_grounded and !receiver.interactionGrounded()) return .{ .reason = .receiver_airborne };
        if (!manager.definition.allowsStartState(initiator.animationState())) return .{ .reason = .initiator_state_rejected };
        if (!manager.definition.allowsStartState(receiver.animationState())) return .{ .reason = .receiver_state_rejected };

        const delta = receiver.world_position.sub(initiator.world_position);
        const horizontal = @abs(delta.x);
        const vertical = @abs(delta.y);
        const distance = @sqrt(delta.x * delta.x + delta.y * delta.y);
        const anchor_error = @abs(horizontal - manager.definition.envelope.authored_horizontal_separation);
        const measured = Eligibility{
            .reason = .eligible,
            .horizontal_separation = horizontal,
            .vertical_difference = vertical,
            .world_distance = distance,
            .anchor_error = anchor_error,
        };
        if (horizontal < manager.definition.envelope.minimum_horizontal_separation) return withReason(measured, .too_near);
        if (horizontal > manager.definition.envelope.maximum_horizontal_separation) return withReason(measured, .too_far);
        if (vertical > manager.definition.envelope.maximum_vertical_root_difference) return withReason(measured, .vertical_misalignment);
        if (!faceToFace(initiator.*, receiver.*)) return withReason(measured, .wrong_facing);
        return measured;
    }

    pub fn selectCandidate(
        manager: *const Manager,
        initiator_id: character.EntityId,
        characters: []const *character.CharacterInstance,
    ) !Candidate {
        var best: ?Candidate = null;
        for (characters) |candidate| {
            if (candidate.id == initiator_id) continue;
            const eligibility = manager.evaluateEligibility(initiator_id, candidate.id, characters);
            if (!eligibility.isEligible()) continue;
            const next = Candidate{ .receiver = candidate.id, .eligibility = eligibility };
            if (best == null or candidateRanksBefore(next, best.?)) best = next;
        }
        return best orelse error.NoEligibleInteractionCandidate;
    }

    pub fn requestFromIntent(
        manager: *Manager,
        initiator_id: character.EntityId,
        intent: input.CharacterIntent,
        characters: []const *character.CharacterInstance,
        current_tick: u64,
    ) !?InteractionId {
        try intent.validate();
        if (!intent.interact_pressed) return null;
        manager.metrics.requests += 1;
        const selected = try manager.selectCandidate(initiator_id, characters);
        return try manager.startPair(initiator_id, selected.receiver, characters, current_tick, .none);
    }

    pub fn startPair(
        manager: *Manager,
        initiator_id: character.EntityId,
        receiver_id: character.EntityId,
        characters: []const *character.CharacterInstance,
        current_tick: u64,
        fault: StartFault,
    ) !InteractionId {
        const eligibility = manager.evaluateEligibility(initiator_id, receiver_id, characters);
        if (!eligibility.isEligible()) return eligibilityError(eligibility.reason);
        const slot_index = manager.availableSlot() orelse return error.InteractionCapacityExceeded;
        if (manager.ids_exhausted) return error.InteractionIdOverflow;
        const id: InteractionId = @enumFromInt(manager.next_id);
        const participant_a = findCharacter(characters, initiator_id) orelse return error.InvalidInitiator;
        const participant_b = findCharacter(characters, receiver_id) orelse return error.InvalidReceiver;
        if (!participant_a.canEnterAnimationState(manager.definition.role(.initiator).state) or
            !participant_b.canEnterAnimationState(manager.definition.role(.receiver).state))
        {
            return error.InteractionAnimationUnavailable;
        }

        const animator_a_before = participant_a.animator;
        const animator_b_before = participant_b.animator;
        var a_reserved = false;
        var b_reserved = false;
        errdefer {
            participant_a.animator = animator_a_before;
            participant_b.animator = animator_b_before;
            if (b_reserved) participant_b.releaseInteraction(id.raw()) catch {};
            if (a_reserved) participant_a.releaseInteraction(id.raw()) catch {};
        }

        try participant_a.reserveInteraction(id.raw());
        a_reserved = true;
        if (manager.definition.presentation.viewForRole(.initiator)) |view| {
            try participant_a.claimInteractionPresentation(id.raw(), view);
        }
        if (fault == .after_reserve_a) return error.InjectedInteractionStartFailure;
        try participant_b.reserveInteraction(id.raw());
        b_reserved = true;
        if (manager.definition.presentation.viewForRole(.receiver)) |view| {
            try participant_b.claimInteractionPresentation(id.raw(), view);
        }
        if (fault == .after_reserve_b) return error.InjectedInteractionStartFailure;
        if (fault == .animator_a_transition) return error.InjectedInteractionStartFailure;
        try participant_a.enterAnimationState(manager.definition.role(.initiator).state);
        if (fault == .animator_b_transition) return error.InjectedInteractionStartFailure;
        try participant_b.enterAnimationState(manager.definition.role(.receiver).state);
        if (fault == .before_instance_commit) return error.InjectedInteractionStartFailure;

        var prepared = Instance{
            .id = id,
            .type_id = manager.definition.type_id,
            .participant_a = initiator_id,
            .participant_b = receiver_id,
            .lifecycle = .requested,
            .start_tick = current_tick,
        };
        try transitionLifecycle(&prepared, .active);
        manager.slots[slot_index] = .{
            .occupied = true,
            .instance = prepared,
        };
        if (manager.next_id == std.math.maxInt(u32)) {
            manager.ids_exhausted = true;
        } else {
            manager.next_id += 1;
        }
        manager.metrics.starts += 1;
        return id;
    }

    pub fn updateTick(
        manager: *Manager,
        current_tick: u64,
        characters: []const *character.CharacterInstance,
    ) !void {
        var slot_index: usize = 0;
        while (slot_index < manager.slots.len) : (slot_index += 1) {
            if (!manager.slots[slot_index].occupied) continue;
            try manager.updateSlot(slot_index, current_tick, characters);
        }
    }

    pub fn cancelForCharacter(
        manager: *Manager,
        entity_id: character.EntityId,
        reason: CancellationReason,
        characters: []const *character.CharacterInstance,
    ) !bool {
        for (&manager.slots) |*slot| {
            if (!slot.occupied) continue;
            if (slot.instance.participant_a == entity_id or slot.instance.participant_b == entity_id) {
                try manager.cancelSlot(slot, reason, characters);
                return true;
            }
        }
        return false;
    }

    pub fn reset(manager: *Manager, characters: []const *character.CharacterInstance) !void {
        for (&manager.slots) |*slot| {
            if (slot.occupied) try manager.cancelSlot(slot, .scene_reset, characters);
        }
    }

    pub fn resetPassiveCharacter(
        manager: *Manager,
        entity_id: character.EntityId,
        characters: []const *character.CharacterInstance,
    ) !void {
        const participant = findCharacter(characters, entity_id) orelse return error.InvalidCharacterResetTarget;
        _ = try manager.cancelForCharacter(entity_id, .character_reset, characters);
        try participant.reset();
    }

    fn updateSlot(
        manager: *Manager,
        slot_index: usize,
        current_tick: u64,
        characters: []const *character.CharacterInstance,
    ) !void {
        const slot = &manager.slots[slot_index];
        const participant_a = findCharacter(characters, slot.instance.participant_a) orelse {
            try manager.cancelSlot(slot, .participant_invalid, characters);
            return;
        };
        const participant_b = findCharacter(characters, slot.instance.participant_b) orelse {
            try manager.cancelSlot(slot, .participant_invalid, characters);
            return;
        };
        if (participant_a.interactionOwnerId() != slot.instance.id.raw() or
            participant_b.interactionOwnerId() != slot.instance.id.raw() or
            participant_a.animationState() != manager.definition.role(.initiator).state or
            participant_b.animationState() != manager.definition.role(.receiver).state)
        {
            try manager.cancelSlot(slot, .pre_contact_invariant, characters);
            return;
        }
        if (current_tick <= slot.instance.start_tick) return;
        const expected_elapsed = current_tick - slot.instance.start_tick;
        if (expected_elapsed != @as(u64, slot.instance.elapsed_ticks) + 1) return error.NonSequentialInteractionTick;
        slot.instance.elapsed_ticks = std.math.add(u32, slot.instance.elapsed_ticks, 1) catch return error.InteractionTimelineOverflow;
        const shared_time: f32 = @floatCast(@min(
            manager.definition.authoritative_duration_seconds,
            @as(f64, @floatFromInt(slot.instance.elapsed_ticks)) * fixed_step.fixed_dt_seconds,
        ));
        participant_a.sampleInteractionAnimation(manager.definition.role(.initiator).state, shared_time) catch {
            try manager.cancelSlot(slot, .pre_contact_invariant, characters);
            return;
        };
        participant_b.sampleInteractionAnimation(manager.definition.role(.receiver).state, shared_time) catch {
            try manager.cancelSlot(slot, .pre_contact_invariant, characters);
            return;
        };
        if (manager.ik_enabled) {
            manager.applySharedHandIk(&slot.instance, participant_a, participant_b) catch {
                try manager.cancelSlot(slot, .ik_failure, characters);
                return;
            };
        }

        for (manager.definition.events, 0..) |event_definition, event_index| {
            if (!slot.instance.event_consumed[event_index] and slot.instance.elapsed_ticks >= event_definition.elapsed_tick) {
                slot.instance.event_consumed[event_index] = true;
                slot.instance.event_counts[event_index] += 1;
                slot.instance.event_ticks[event_index] = current_tick;
                switch (event_definition.semantic) {
                    .contact => manager.beginContact(slot, participant_a, participant_b, current_tick) catch {
                        try manager.cancelSlot(slot, .override_capacity, characters);
                        return;
                    },
                    .release => {
                        try manager.clearOwnedOverrides(&slot.instance, characters);
                        slot.instance.phase = .released;
                    },
                    .complete => {
                        slot.instance.phase = .complete;
                        try transitionLifecycle(&slot.instance, .completing);
                        try manager.completeSlot(slot, participant_a, participant_b, characters);
                        return;
                    },
                }
            }
        }
    }

    fn beginContact(
        manager: *Manager,
        slot: *Slot,
        participant_a: *character.CharacterInstance,
        participant_b: *character.CharacterInstance,
        current_tick: u64,
    ) !void {
        slot.instance.phase = .contact;
        try manager.applyOcclusionProfile(&slot.instance, participant_a, participant_b);
        errdefer manager.clearOwnedOverrides(&slot.instance, &.{ participant_a, participant_b }) catch {};
        const a_socket = try participant_a.socketPosition(manager.definition.role(.initiator).handshake_socket);
        const b_socket = try participant_b.socketPosition(manager.definition.role(.receiver).handshake_socket);
        const delta = b_socket.sub(a_socket);
        const separation = @sqrt(delta.x * delta.x + delta.y * delta.y);
        if (!a_socket.isFinite() or !b_socket.isFinite() or !std.math.isFinite(separation)) return error.NonFiniteContactMeasurement;
        if (slot.instance.ik.enabled and slot.instance.ik.target_valid) {
            const role_a = slot.instance.ik.role_a orelse return error.MissingRoleAIkMeasurement;
            const role_b = slot.instance.ik.role_b orelse return error.MissingRoleBIkMeasurement;
            slot.instance.contact = .{
                .captured = true,
                .tick = current_tick,
                .role_a_socket = role_a.post_ik_hand_position,
                .role_b_socket = role_b.post_ik_hand_position,
                .separation = slot.instance.ik.post_hand_separation,
                .ik_enabled = true,
                .ik_weight = slot.instance.ik.weight,
                .shared_target = slot.instance.ik.shared_target,
                .role_a_pre_socket = role_a.pre_ik_hand_position,
                .role_b_pre_socket = role_b.pre_ik_hand_position,
                .role_a_target_error = role_a.target_error,
                .role_b_target_error = role_b.target_error,
                .pre_separation = slot.instance.ik.pre_hand_separation,
                .post_separation = slot.instance.ik.post_hand_separation,
                .role_a_reachability = role_a.reachability,
                .role_b_reachability = role_b.reachability,
            };
        } else {
            slot.instance.contact = .{
                .captured = true,
                .tick = current_tick,
                .role_a_socket = a_socket,
                .role_b_socket = b_socket,
                .separation = separation,
                .shared_target = sharedTarget(a_socket, b_socket),
                .role_a_pre_socket = a_socket,
                .role_b_pre_socket = b_socket,
                .pre_separation = separation,
                .post_separation = separation,
            };
        }
    }

    fn applyOcclusionProfile(
        manager: *Manager,
        instance_value: *Instance,
        participant_a: *character.CharacterInstance,
        participant_b: *character.CharacterInstance,
    ) !void {
        switch (manager.definition.presentation.occlusion_profile) {
            .none => {},
            .handshake_right_hand_contact => {
                try manager.addOverride(instance_value, participant_a, .right_hand, .{
                    .interaction_layer = 3,
                });
                try manager.addOverride(instance_value, participant_b, .right_hand, .{
                    .interaction_layer = 2,
                });
                try manager.addOverride(instance_value, participant_a, .right_forearm, .{
                    .interaction_layer = 1,
                });
            },
        }
    }

    fn applySharedHandIk(
        manager: *Manager,
        instance_value: *Instance,
        participant_a: *character.CharacterInstance,
        participant_b: *character.CharacterInstance,
    ) !void {
        const pre_a = try participant_a.socketPosition(manager.definition.role(.initiator).handshake_socket);
        const pre_b = try participant_b.socketPosition(manager.definition.role(.receiver).handshake_socket);
        const target = sharedTarget(pre_a, pre_b);
        const weight = weightForElapsed(&manager.definition, instance_value.elapsed_ticks);
        const pre_separation = pre_b.sub(pre_a).length();
        if (!target.isFinite() or !std.math.isFinite(pre_separation) or !std.math.isFinite(weight)) {
            return error.NonFiniteIkConstraint;
        }
        const role_a = try participant_a.applyRightHandIk(target, weight);
        const role_b = try participant_b.applyRightHandIk(target, weight);
        const post_separation = role_b.post_ik_hand_position.sub(role_a.post_ik_hand_position).length();
        if (!std.math.isFinite(post_separation)) return error.NonFiniteIkConstraint;
        instance_value.ik = .{
            .enabled = true,
            .weight = weight,
            .target_valid = true,
            .shared_target = target,
            .role_a = role_a,
            .role_b = role_b,
            .pre_hand_separation = pre_separation,
            .post_hand_separation = post_separation,
        };
    }

    fn addOverride(
        manager: *Manager,
        instance_value: *Instance,
        participant: *character.CharacterInstance,
        semantic: humanoid.AttachmentSemantic,
        request: character.LayerOverrideRequest,
    ) !void {
        _ = manager;
        if (instance_value.owned_override_count == instance_value.owned_overrides.len) return error.InteractionOverrideCapacityExceeded;
        const handle = try participant.applySemanticOverride(semantic, request);
        instance_value.owned_overrides[instance_value.owned_override_count] = .{ .participant = participant.id, .handle = handle };
        instance_value.owned_override_count += 1;
    }

    fn clearOwnedOverrides(
        manager: *Manager,
        instance_value: *Instance,
        characters: []const *character.CharacterInstance,
    ) !void {
        _ = manager;
        var index = instance_value.owned_override_count;
        while (index > 0) {
            index -= 1;
            const owned = instance_value.owned_overrides[index];
            if (findCharacter(characters, owned.participant)) |participant| {
                try participant.clearOverride(owned.handle);
            }
            instance_value.owned_overrides[index] = .{};
        }
        instance_value.owned_override_count = 0;
    }

    fn completeSlot(
        manager: *Manager,
        slot: *Slot,
        participant_a: *character.CharacterInstance,
        participant_b: *character.CharacterInstance,
        characters: []const *character.CharacterInstance,
    ) !void {
        try manager.clearOwnedOverrides(&slot.instance, characters);
        try manager.clearIkConstraint(&slot.instance, participant_a, participant_b);
        try participant_a.enterAnimationState(participant_a.fallbackAnimationState());
        try participant_b.enterAnimationState(participant_b.fallbackAnimationState());
        try participant_a.releaseInteraction(slot.instance.id.raw());
        try participant_b.releaseInteraction(slot.instance.id.raw());
        try transitionLifecycle(&slot.instance, .completed);
        manager.last_terminal = slot.instance;
        slot.occupied = false;
        manager.metrics.completions += 1;
    }

    fn cancelSlot(
        manager: *Manager,
        slot: *Slot,
        reason: CancellationReason,
        characters: []const *character.CharacterInstance,
    ) !void {
        try manager.clearOwnedOverrides(&slot.instance, characters);
        if (findCharacter(characters, slot.instance.participant_a)) |participant_a| try participant_a.clearRightHandIk();
        if (findCharacter(characters, slot.instance.participant_b)) |participant_b| try participant_b.clearRightHandIk();
        slot.instance.ik = .{};
        if (findCharacter(characters, slot.instance.participant_a)) |participant_a| {
            if (participant_a.interactionOwnerId() == slot.instance.id.raw()) {
                try participant_a.enterAnimationState(participant_a.fallbackAnimationState());
                try participant_a.releaseInteraction(slot.instance.id.raw());
            }
        }
        if (findCharacter(characters, slot.instance.participant_b)) |participant_b| {
            if (participant_b.interactionOwnerId() == slot.instance.id.raw()) {
                try participant_b.enterAnimationState(participant_b.fallbackAnimationState());
                try participant_b.releaseInteraction(slot.instance.id.raw());
            }
        }
        try transitionLifecycle(&slot.instance, .cancelled);
        slot.instance.cancellation_reason = reason;
        manager.last_terminal = slot.instance;
        slot.occupied = false;
        manager.metrics.cancellations += 1;
    }

    fn clearIkConstraint(
        manager: *Manager,
        instance_value: *Instance,
        participant_a: *character.CharacterInstance,
        participant_b: *character.CharacterInstance,
    ) !void {
        _ = manager;
        try participant_a.clearRightHandIk();
        try participant_b.clearRightHandIk();
        instance_value.ik = .{};
    }

    fn availableSlot(manager: *const Manager) ?usize {
        for (manager.slots, 0..) |slot, index| {
            if (!slot.occupied) return index;
        }
        return null;
    }
};

pub fn sharedTarget(role_a_pre_ik_hand: math.Vec2, role_b_pre_ik_hand: math.Vec2) math.Vec2 {
    return role_a_pre_ik_hand.add(role_b_pre_ik_hand).scale(0.5);
}

pub fn weightForElapsed(definition: *const interaction.Definition, elapsed_ticks: u32) f32 {
    const contact_tick = definition.event(.contact).elapsed_tick;
    const release_tick = definition.event(.release).elapsed_tick;
    const complete_tick = definition.event(.complete).elapsed_tick;
    if (elapsed_ticks <= contact_tick) {
        return @as(f32, @floatFromInt(elapsed_ticks)) / @as(f32, @floatFromInt(contact_tick));
    }
    if (elapsed_ticks <= release_tick) return 1;
    if (elapsed_ticks >= complete_tick) return 0;
    return 1.0 - @as(f32, @floatFromInt(elapsed_ticks - release_tick)) /
        @as(f32, @floatFromInt(complete_tick - release_tick));
}

fn findCharacter(characters: []const *character.CharacterInstance, id: character.EntityId) ?*character.CharacterInstance {
    for (characters) |candidate| {
        if (candidate.id == id) return candidate;
    }
    return null;
}

fn faceToFace(a: character.CharacterInstance, b: character.CharacterInstance) bool {
    if (a.world_position.x < b.world_position.x) return a.facing == .right and b.facing == .left;
    if (b.world_position.x < a.world_position.x) return b.facing == .right and a.facing == .left;
    return false;
}

fn withReason(value: Eligibility, reason: EligibilityReason) Eligibility {
    var result = value;
    result.reason = reason;
    return result;
}

fn candidateRanksBefore(left: Candidate, right: Candidate) bool {
    if (left.eligibility.anchor_error != right.eligibility.anchor_error) {
        return left.eligibility.anchor_error < right.eligibility.anchor_error;
    }
    if (left.eligibility.world_distance != right.eligibility.world_distance) {
        return left.eligibility.world_distance < right.eligibility.world_distance;
    }
    return left.receiver.raw() < right.receiver.raw();
}

fn eligibilityError(reason: EligibilityReason) anyerror {
    return switch (reason) {
        .eligible => error.InvalidEligibilityError,
        .invalid_initiator => error.InvalidInitiator,
        .invalid_receiver => error.InvalidReceiver,
        .same_entity => error.DuplicateParticipant,
        .initiator_already_interacting => error.InitiatorAlreadyInteracting,
        .receiver_already_interacting => error.ReceiverAlreadyInteracting,
        .initiator_airborne => error.InitiatorAirborne,
        .receiver_airborne => error.ReceiverAirborne,
        .initiator_state_rejected => error.InitiatorStateRejected,
        .receiver_state_rejected => error.ReceiverStateRejected,
        .too_near => error.ParticipantsTooNear,
        .too_far => error.ParticipantsTooFar,
        .vertical_misalignment => error.ParticipantVerticalMisalignment,
        .wrong_facing => error.ParticipantsNotFacing,
    };
}

fn transitionLifecycle(instance_value: *Instance, next: interaction.Lifecycle) !void {
    if (!interaction.legalTransition(instance_value.lifecycle, next)) return error.IllegalInteractionLifecycleTransition;
    instance_value.lifecycle = next;
}
