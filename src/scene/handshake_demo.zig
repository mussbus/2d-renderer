const std = @import("std");
const math = @import("math");
const input = @import("input");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const sprite = @import("sprite_batch");

pub const character_count: usize = 2;
pub const required_frames: u32 = 720;
pub const fixed_ticks_per_frame: u32 = 4;

pub const RunEvidence = struct {
    captured: bool = false,
    request_tick: u64 = 0,
    initiator: character.EntityId = .invalid,
    receiver: character.EntityId = .invalid,
    interaction_id: interaction_system.InteractionId = .invalid,
    starting_spacing: f32 = 0,
    start_tick: u64 = 0,
    contact_tick: u64 = 0,
    release_tick: u64 = 0,
    complete_tick: u64 = 0,
    role_a_normalized_contact: f32 = 0,
    role_b_normalized_contact: f32 = 0,
    role_a_socket: math.Vec2 = math.Vec2.zero,
    role_b_socket: math.Vec2 = math.Vec2.zero,
    socket_separation: f32 = 0,
    contact_handles: [3]u32 = [_]u32{0} ** 3,
    contact_handle_count: usize = 0,
    event_counts: [interaction.event_count]u8 = [_]u8{0} ** interaction.event_count,
    release_override_count: usize = 0,
    final_a_state: ?@import("state_machine").StateId = null,
    final_b_state: ?@import("state_machine").StateId = null,
    locks_released: bool = false,
    contact_order_logged: bool = false,
};

pub const Scene = struct {
    definition: humanoid.HumanoidDefinition,
    shared_animations: authored.Definitions,
    character_a: character.CharacterInstance,
    character_b: character.CharacterInstance,
    manager: interaction_system.Manager,
    snapshot_builder: input.SnapshotBuilder = .{},
    pending_input: input.PendingInput = .{},
    simulation_tick: u64 = 0,
    first: RunEvidence = .{},
    mirrored: RunEvidence = .{},
    active_run: u8 = 0,
    first_root_a: math.Vec2,
    first_root_b: math.Vec2,
    mirrored_root_a: math.Vec2 = .{ .x = 1.86, .y = 1.05 },
    mirrored_root_b: math.Vec2 = .{ .x = -1.86, .y = 1.05 },

    pub fn init(allocator: std.mem.Allocator) !Scene {
        var definition = try humanoid.HumanoidDefinition.init(allocator, null);
        errdefer definition.deinit();
        var shared_animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer shared_animations.deinit();
        var character_a = try character.CharacterInstance.init(
            allocator,
            try character.entityIdFromRaw(1),
            &definition,
            &shared_animations,
            .{ .x = -1.86, .y = 1.05 },
            .right,
            0,
            null,
        );
        errdefer character_a.deinit();
        var character_b = try character.CharacterInstance.init(
            allocator,
            try character.entityIdFromRaw(2),
            &definition,
            &shared_animations,
            .{ .x = 1.86, .y = 1.05 },
            .left,
            1,
            null,
        );
        errdefer character_b.deinit();
        return .{
            .definition = definition,
            .shared_animations = shared_animations,
            .character_a = character_a,
            .character_b = character_b,
            .manager = interaction_system.Manager.init(try handshake.definition(&shared_animations)),
            .first_root_a = character_a.world_position,
            .first_root_b = character_b.world_position,
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.character_b.deinit();
        scene.character_a.deinit();
        scene.shared_animations.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn updateFrame(scene: *Scene, frame: u32) !void {
        if (frame == 180) try scene.stageMirroredArrangement();
        const interact_held = (frame >= 30 and frame < 35) or (frame >= 210 and frame < 215);
        const snapshot = try scene.snapshot_builder.update(.{ .keyboard = .{ .e = interact_held } });
        try scene.pending_input.acceptFrame(snapshot);
        const participants = scene.characters();

        for (0..fixed_ticks_per_frame) |_| {
            scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch return error.SimulationTickOverflow;
            const intent = scene.pending_input.consumeTick();
            if (intent.interact_pressed) {
                const selected = try scene.manager.selectCandidate(scene.character_a.id, &participants);
                const eligibility = scene.manager.evaluateEligibility(scene.character_a.id, selected.receiver, &participants);
                const id = (try scene.manager.requestFromIntent(scene.character_a.id, intent, &participants, scene.simulation_tick)).?;
                scene.active_run += 1;
                const evidence = scene.currentEvidence();
                evidence.request_tick = scene.simulation_tick;
                evidence.initiator = scene.character_a.id;
                evidence.receiver = selected.receiver;
                evidence.interaction_id = id;
                evidence.starting_spacing = eligibility.horizontal_separation;
                evidence.start_tick = scene.manager.instance(id).?.start_tick;
                std.log.info("handshake request tick={d} initiator={d} selected_receiver={d} role_a=initiator role_b=receiver eligibility={s} spacing={d:.6} start_tick={d}", .{
                    evidence.request_tick,
                    evidence.initiator.raw(),
                    evidence.receiver.raw(),
                    @tagName(eligibility.reason),
                    evidence.starting_spacing,
                    evidence.start_tick,
                });
            }

            try scene.manager.updateTick(scene.simulation_tick, &participants);
            try scene.captureInteractionEvidence();
            if (!scene.character_a.isInteractionLocked()) try scene.character_a.advanceVisualTick(.{});
            if (!scene.character_b.isInteractionLocked()) try scene.character_b.advanceVisualTick(.{});
        }
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        const participants = scene.charactersReversed();
        const submitted = try character.submitGlobally(&participants, batch);
        if (scene.active_run != 0) {
            const evidence = scene.currentEvidence();
            if (evidence.contact_tick != 0 and evidence.release_tick == 0 and !evidence.contact_order_logged) {
                const a_hand = try scene.character_a.submittedKey(.right_hand);
                const b_hand = try scene.character_b.submittedKey(.right_hand);
                const a_forearm = try scene.character_a.submittedKey(.right_forearm);
                const b_torso = try scene.character_b.submittedKey(.torso);
                if (!sprite.keyLessThan(b_hand, a_hand) or !sprite.keyLessThan(b_torso, a_forearm)) {
                    return error.HandshakeContactOrderingInvalid;
                }
                evidence.contact_order_logged = true;
                std.log.info("handshake contact order A.right_hand=({d},{d},{d},{d}) B.right_hand=({d},{d},{d},{d}) A.right_forearm=({d},{d},{d},{d}) B.torso=({d},{d},{d},{d})", .{
                    a_hand.scene_layer,    a_hand.interaction_layer,    a_hand.actor_layer,    a_hand.body_part_layer,
                    b_hand.scene_layer,    b_hand.interaction_layer,    b_hand.actor_layer,    b_hand.body_part_layer,
                    a_forearm.scene_layer, a_forearm.interaction_layer, a_forearm.actor_layer, a_forearm.body_part_layer,
                    b_torso.scene_layer,   b_torso.interaction_layer,   b_torso.actor_layer,   b_torso.body_part_layer,
                });
            }
        }
        return submitted;
    }

    pub fn validateComplete(scene: Scene) !void {
        if (!scene.first.captured or !scene.mirrored.captured) return error.HandshakeRunMissing;
        try validateEvidence(scene.first, &scene.manager.definition);
        try validateEvidence(scene.mirrored, &scene.manager.definition);
        if (@abs(scene.first.socket_separation - scene.mirrored.socket_separation) > 0.00001) {
            return error.MirroredSocketSeparationMismatch;
        }
        if (!scene.character_a.world_position.approxEqAbs(scene.mirrored_root_a, 0.000001) or
            !scene.character_b.world_position.approxEqAbs(scene.mirrored_root_b, 0.000001))
        {
            return error.InteractionMovedCharacterRoot;
        }
        if (scene.manager.activeCount() != 0 or scene.manager.metrics.starts != 2 or
            scene.manager.metrics.completions != 2 or scene.manager.metrics.cancellations != 0)
        {
            return error.HandshakeLifecycleEvidenceIncomplete;
        }
    }

    fn captureInteractionEvidence(scene: *Scene) !void {
        if (scene.active_run == 0) return;
        const evidence = scene.currentEvidence();
        const instance = scene.manager.instance(evidence.interaction_id) orelse return error.HandshakeInstanceMissing;
        const contact_index = @intFromEnum(interaction.EventSemantic.contact);
        const release_index = @intFromEnum(interaction.EventSemantic.release);
        const complete_index = @intFromEnum(interaction.EventSemantic.complete);
        if (instance.event_ticks[contact_index] != null and evidence.contact_tick == 0) {
            evidence.contact_tick = instance.event_ticks[contact_index].?;
            evidence.role_a_normalized_contact = scene.character_a.animationTime() / scene.manager.definition.authoritative_duration_seconds;
            evidence.role_b_normalized_contact = scene.character_b.animationTime() / scene.manager.definition.authoritative_duration_seconds;
            evidence.role_a_socket = instance.contact.role_a_socket;
            evidence.role_b_socket = instance.contact.role_b_socket;
            evidence.socket_separation = instance.contact.separation;
            evidence.contact_handle_count = instance.owned_override_count;
            for (instance.owned_overrides[0..instance.owned_override_count], 0..) |owned, index| {
                evidence.contact_handles[index] = owned.handle.raw();
            }
            std.log.info("handshake contact tick={d} normalized_a={d:.6} normalized_b={d:.6} socket_a=({d:.6},{d:.6}) socket_b=({d:.6},{d:.6}) separation={d:.6} handles={d},{d},{d}", .{
                evidence.contact_tick,
                evidence.role_a_normalized_contact,
                evidence.role_b_normalized_contact,
                evidence.role_a_socket.x,
                evidence.role_a_socket.y,
                evidence.role_b_socket.x,
                evidence.role_b_socket.y,
                evidence.socket_separation,
                evidence.contact_handles[0],
                evidence.contact_handles[1],
                evidence.contact_handles[2],
            });
        }
        if (instance.event_ticks[release_index] != null and evidence.release_tick == 0) {
            evidence.release_tick = instance.event_ticks[release_index].?;
            evidence.release_override_count = scene.character_a.overrides.activeCount() + scene.character_b.overrides.activeCount();
            std.log.info("handshake release tick={d} interaction_owned_overrides={d}", .{ evidence.release_tick, evidence.release_override_count });
        }
        if (instance.event_ticks[complete_index] != null and !evidence.captured) {
            evidence.complete_tick = instance.event_ticks[complete_index].?;
            evidence.final_a_state = scene.character_a.animationState();
            evidence.final_b_state = scene.character_b.animationState();
            evidence.event_counts = instance.event_counts;
            evidence.locks_released = !scene.character_a.isInteractionLocked() and !scene.character_b.isInteractionLocked();
            evidence.captured = true;
            std.log.info("handshake complete tick={d} final_a={s} final_b={s} lock_a={} lock_b={} active_slots={d}", .{
                evidence.complete_tick,
                @tagName(evidence.final_a_state.?),
                @tagName(evidence.final_b_state.?),
                scene.character_a.isInteractionLocked(),
                scene.character_b.isInteractionLocked(),
                scene.manager.activeCount(),
            });
        }
    }

    fn stageMirroredArrangement(scene: *Scene) !void {
        if (!scene.first.captured or scene.manager.activeCount() != 0) return error.MirroredStagingBeforeCompletion;
        try scene.character_a.setWorldPosition(scene.mirrored_root_a);
        try scene.character_b.setWorldPosition(scene.mirrored_root_b);
        try scene.character_a.setFacing(.left);
        try scene.character_b.setFacing(.right);
        std.log.info("handshake demo staged mirrored idle arrangement A_id={d} A_x={d:.3} facing={s} B_id={d} B_x={d:.3} facing={s}", .{
            scene.character_a.id.raw(),
            scene.character_a.world_position.x,
            @tagName(scene.character_a.facing),
            scene.character_b.id.raw(),
            scene.character_b.world_position.x,
            @tagName(scene.character_b.facing),
        });
    }

    fn currentEvidence(scene: *Scene) *RunEvidence {
        return if (scene.active_run == 1) &scene.first else &scene.mirrored;
    }

    fn characters(scene: *Scene) [2]*character.CharacterInstance {
        return .{ &scene.character_a, &scene.character_b };
    }

    fn charactersReversed(scene: *Scene) [2]*character.CharacterInstance {
        return .{ &scene.character_b, &scene.character_a };
    }
};

fn validateEvidence(evidence: RunEvidence, definition: *const interaction.Definition) !void {
    if (evidence.start_tick != evidence.request_tick or
        evidence.contact_tick != evidence.start_tick + definition.event(.contact).elapsed_tick or
        evidence.release_tick != evidence.start_tick + definition.event(.release).elapsed_tick or
        evidence.complete_tick != evidence.start_tick + definition.event(.complete).elapsed_tick or
        evidence.contact_handle_count != 3 or evidence.release_override_count != 0 or
        evidence.final_a_state != .idle or evidence.final_b_state != .idle or
        !evidence.locks_released or !evidence.contact_order_logged or
        !std.math.isFinite(evidence.socket_separation))
    {
        return error.HandshakeEvidenceIncomplete;
    }
    for (evidence.event_counts) |count| {
        if (count != 1) return error.HandshakeEventCountMismatch;
    }
    if (@abs(evidence.role_a_normalized_contact - evidence.role_b_normalized_contact) > 0.000001) {
        return error.PairedNormalizedTimeMismatch;
    }
}
