const std = @import("std");
const math = @import("math");
const input = @import("input");
const arm_ik = @import("arm_ik");
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
    name: []const u8 = "",
    interaction_id: interaction_system.InteractionId = .invalid,
    root_a: math.Vec2 = math.Vec2.zero,
    root_b: math.Vec2 = math.Vec2.zero,
    root_spacing: f32 = 0,
    start_tick: u64 = 0,
    contact_tick: u64 = 0,
    release_tick: u64 = 0,
    complete_tick: u64 = 0,
    start_weight: f32 = 0,
    blend_midpoint_weight: f32 = 0,
    contact_weight: f32 = 0,
    release_weight: f32 = 0,
    post_release_weight: f32 = 0,
    after_completion_weight: f32 = 0,
    shared_target: math.Vec2 = math.Vec2.zero,
    pre_a: math.Vec2 = math.Vec2.zero,
    pre_b: math.Vec2 = math.Vec2.zero,
    post_a: math.Vec2 = math.Vec2.zero,
    post_b: math.Vec2 = math.Vec2.zero,
    pre_separation: f32 = 0,
    post_separation: f32 = 0,
    role_a_target_error: f32 = 0,
    role_b_target_error: f32 = 0,
    role_a_metrics: ?arm_ik.Metrics = null,
    role_b_metrics: ?arm_ik.Metrics = null,
    event_counts: [interaction.event_count]u8 = [_]u8{0} ** interaction.event_count,
    contact_handle_count: usize = 0,
    release_override_count: usize = 0,
    contact_order_logged: bool = false,
    roots_unchanged: bool = false,
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
    nominal: RunEvidence = .{ .name = "nominal" },
    mirrored: RunEvidence = .{ .name = "mirrored" },
    perturbed: RunEvidence = .{ .name = "perturbed" },
    active_run: u8 = 0,

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
            .manager = interaction_system.Manager.initWithIk(try handshake.definition(&shared_animations)),
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
        if (frame == 180) try scene.stageArrangement(.mirrored);
        if (frame == 360) try scene.stageArrangement(.perturbed);
        const interact_held = (frame >= 30 and frame < 35) or
            (frame >= 210 and frame < 215) or
            (frame >= 390 and frame < 395);
        const snapshot = try scene.snapshot_builder.update(.{ .interact = interact_held });
        try scene.pending_input.acceptFrame(snapshot);
        const participants_value = scene.participants();

        for (0..fixed_ticks_per_frame) |_| {
            scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch return error.SimulationTickOverflow;
            const intent = scene.pending_input.consumeTick();
            if (intent.interact_pressed) {
                const selected = try scene.manager.selectCandidate(scene.character_a.id, &participants_value);
                const eligibility = scene.manager.evaluateEligibility(scene.character_a.id, selected.receiver, &participants_value);
                const id = (try scene.manager.requestFromIntent(scene.character_a.id, intent, &participants_value, scene.simulation_tick)).?;
                scene.active_run += 1;
                const evidence = scene.currentEvidence();
                evidence.interaction_id = id;
                evidence.root_a = scene.character_a.world_position;
                evidence.root_b = scene.character_b.world_position;
                evidence.root_spacing = eligibility.horizontal_separation;
                evidence.start_tick = scene.manager.instance(id).?.start_tick;
                evidence.start_weight = scene.manager.instance(id).?.ikWeight(&scene.manager.definition);
                std.log.info("handshake IK request run={s} tick={d} spacing={d:.6} weight={d:.3} target_policy=pre_ik_midpoint", .{
                    evidence.name,
                    evidence.start_tick,
                    evidence.root_spacing,
                    evidence.start_weight,
                });
            }

            try scene.manager.updateTick(scene.simulation_tick, &participants_value);
            try scene.captureEvidence();
            if (!scene.character_a.isInteractionLocked()) try scene.character_a.advanceVisualTick(.{});
            if (!scene.character_b.isInteractionLocked()) try scene.character_b.advanceVisualTick(.{});
        }
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        const reverse = [_]*character.CharacterInstance{ &scene.character_b, &scene.character_a };
        const submitted = try character.submitGlobally(&reverse, batch);
        if (scene.active_run != 0) {
            const evidence = scene.currentEvidence();
            if (evidence.contact_tick != 0 and evidence.release_tick == 0 and !evidence.contact_order_logged) {
                const a_hand = try scene.character_a.submittedKey(.right_hand);
                const b_hand = try scene.character_b.submittedKey(.right_hand);
                const a_forearm = try scene.character_a.submittedKey(.right_forearm);
                const b_torso = try scene.character_b.submittedKey(.torso);
                if (!sprite.keyLessThan(b_hand, a_hand) or !sprite.keyLessThan(b_torso, a_forearm)) {
                    return error.HandshakeIkContactOrderingInvalid;
                }
                evidence.contact_order_logged = true;
            }
        }
        return submitted;
    }

    pub fn validateComplete(scene: Scene) !void {
        try validateEvidence(scene.nominal, &scene.manager.definition, false);
        try validateEvidence(scene.mirrored, &scene.manager.definition, false);
        try validateEvidence(scene.perturbed, &scene.manager.definition, true);
        if (@abs(scene.nominal.post_separation - scene.mirrored.post_separation) > 0.0002) {
            return error.MirroredIkSeparationMismatch;
        }
        if (scene.manager.activeCount() != 0 or scene.manager.metrics.starts != 3 or
            scene.manager.metrics.completions != 3 or scene.manager.metrics.cancellations != 0)
        {
            return error.HandshakeIkLifecycleEvidenceIncomplete;
        }
        if (scene.character_a.right_arm_ik.applied or scene.character_b.right_arm_ik.applied or
            scene.character_a.isInteractionLocked() or scene.character_b.isInteractionLocked())
        {
            return error.HandshakeIkRuntimeStateNotCleared;
        }
    }

    fn captureEvidence(scene: *Scene) !void {
        if (scene.active_run == 0) return;
        const evidence = scene.currentEvidence();
        const instance = scene.manager.instance(evidence.interaction_id) orelse return error.HandshakeIkInstanceMissing;
        const contact_elapsed = scene.manager.definition.event(.contact).elapsed_tick;
        const release_elapsed = scene.manager.definition.event(.release).elapsed_tick;
        const complete_elapsed = scene.manager.definition.event(.complete).elapsed_tick;
        if (instance.elapsed_ticks == contact_elapsed / 2 and evidence.blend_midpoint_weight == 0) {
            evidence.blend_midpoint_weight = instance.ik.weight;
            std.log.info("handshake IK blend run={s} tick={d} weight={d:.3}", .{ evidence.name, scene.simulation_tick, instance.ik.weight });
        }
        if (instance.event_ticks[@intFromEnum(interaction.EventSemantic.contact)] != null and evidence.contact_tick == 0) {
            const contact = instance.contact;
            evidence.contact_tick = contact.tick;
            evidence.contact_weight = contact.ik_weight;
            evidence.shared_target = contact.shared_target;
            evidence.pre_a = contact.role_a_pre_socket;
            evidence.pre_b = contact.role_b_pre_socket;
            evidence.post_a = contact.role_a_socket;
            evidence.post_b = contact.role_b_socket;
            evidence.pre_separation = contact.pre_separation;
            evidence.post_separation = contact.post_separation;
            evidence.role_a_target_error = contact.role_a_target_error;
            evidence.role_b_target_error = contact.role_b_target_error;
            evidence.role_a_metrics = instance.ik.role_a;
            evidence.role_b_metrics = instance.ik.role_b;
            evidence.contact_handle_count = instance.owned_override_count;
            const a_metrics = evidence.role_a_metrics.?;
            const b_metrics = evidence.role_b_metrics.?;
            std.log.info("handshake IK contact run={s} tick={d} weight={d:.3} target=({d:.6},{d:.6}) pre_A=({d:.6},{d:.6}) pre_B=({d:.6},{d:.6}) pre_separation={d:.6} post_A=({d:.6},{d:.6}) post_B=({d:.6},{d:.6}) error_A={d:.8} error_B={d:.8} post_separation={d:.8}", .{
                evidence.name,                evidence.contact_tick,    evidence.contact_weight, evidence.shared_target.x, evidence.shared_target.y,
                evidence.pre_a.x,             evidence.pre_a.y,         evidence.pre_b.x,        evidence.pre_b.y,         evidence.pre_separation,
                evidence.post_a.x,            evidence.post_a.y,        evidence.post_b.x,       evidence.post_b.y,        evidence.role_a_target_error,
                evidence.role_b_target_error, evidence.post_separation,
            });
            std.log.info("handshake IK solver run={s} upper={d:.6} lower={d:.6} bend_A={s} bend_B={s} reach_A={s} reach_B={s} shoulder_A=({d:.6},{d:.6}) elbow_A=({d:.6},{d:.6})", .{
                evidence.name,
                a_metrics.upper_length,
                a_metrics.lower_length,
                @tagName(a_metrics.bend),
                @tagName(b_metrics.bend),
                @tagName(a_metrics.reachability),
                @tagName(b_metrics.reachability),
                a_metrics.shoulder_position.x,
                a_metrics.shoulder_position.y,
                a_metrics.elbow_position.x,
                a_metrics.elbow_position.y,
            });
        }
        if (instance.event_ticks[@intFromEnum(interaction.EventSemantic.release)] != null and evidence.release_tick == 0) {
            evidence.release_tick = instance.event_ticks[@intFromEnum(interaction.EventSemantic.release)].?;
            evidence.release_weight = instance.ik.weight;
            evidence.release_override_count = scene.character_a.overrides.activeCount() + scene.character_b.overrides.activeCount();
            std.log.info("handshake IK release run={s} tick={d} weight={d:.3}", .{ evidence.name, evidence.release_tick, evidence.release_weight });
        }
        if (instance.elapsed_ticks == (release_elapsed + complete_elapsed) / 2 and evidence.post_release_weight == 0) {
            evidence.post_release_weight = instance.ik.weight;
            std.log.info("handshake IK release blend run={s} tick={d} weight={d:.3}", .{ evidence.name, scene.simulation_tick, instance.ik.weight });
        }
        if (instance.event_ticks[@intFromEnum(interaction.EventSemantic.complete)] != null and !evidence.captured) {
            evidence.complete_tick = instance.event_ticks[@intFromEnum(interaction.EventSemantic.complete)].?;
            evidence.after_completion_weight = instance.ik.weight;
            evidence.event_counts = instance.event_counts;
            evidence.roots_unchanged = scene.character_a.world_position.approxEqAbs(evidence.root_a, 0) and
                scene.character_b.world_position.approxEqAbs(evidence.root_b, 0);
            evidence.captured = true;
            std.log.info("handshake IK complete run={s} tick={d} weight={d:.3} roots_unchanged={} locks={}/{}", .{
                evidence.name,
                evidence.complete_tick,
                evidence.after_completion_weight,
                evidence.roots_unchanged,
                scene.character_a.isInteractionLocked(),
                scene.character_b.isInteractionLocked(),
            });
        }
    }

    fn stageArrangement(scene: *Scene, next: enum { mirrored, perturbed }) !void {
        if (scene.manager.activeCount() != 0) return error.HandshakeIkStagingDuringInteraction;
        switch (next) {
            .mirrored => {
                if (!scene.nominal.captured) return error.HandshakeIkStagingBeforeCompletion;
                try scene.character_a.setWorldPosition(.{ .x = 1.86, .y = 1.05 });
                try scene.character_b.setWorldPosition(.{ .x = -1.86, .y = 1.05 });
                try scene.character_a.setFacing(.left);
                try scene.character_b.setFacing(.right);
            },
            .perturbed => {
                if (!scene.mirrored.captured) return error.HandshakeIkStagingBeforeCompletion;
                try scene.character_a.setWorldPosition(.{ .x = -1.87, .y = 1.05 });
                try scene.character_b.setWorldPosition(.{ .x = 1.87, .y = 1.05 });
                try scene.character_a.setFacing(.right);
                try scene.character_b.setFacing(.left);
            },
        }
    }

    fn currentEvidence(scene: *Scene) *RunEvidence {
        return switch (scene.active_run) {
            1 => &scene.nominal,
            2 => &scene.mirrored,
            else => &scene.perturbed,
        };
    }

    fn participants(scene: *Scene) [2]*character.CharacterInstance {
        return .{ &scene.character_a, &scene.character_b };
    }
};

fn validateEvidence(evidence: RunEvidence, definition: *const interaction.Definition, perturbed: bool) !void {
    if (!evidence.captured or evidence.contact_tick != evidence.start_tick + definition.event(.contact).elapsed_tick or
        evidence.release_tick != evidence.start_tick + definition.event(.release).elapsed_tick or
        evidence.complete_tick != evidence.start_tick + definition.event(.complete).elapsed_tick or
        evidence.start_weight != 0 or @abs(evidence.blend_midpoint_weight - 0.5) > 0.000001 or
        evidence.contact_weight != 1 or evidence.release_weight != 1 or
        @abs(evidence.post_release_weight - 0.5) > 0.000001 or evidence.after_completion_weight != 0 or
        evidence.contact_handle_count != 3 or evidence.release_override_count != 0 or
        !evidence.contact_order_logged or !evidence.roots_unchanged or
        evidence.role_a_target_error > 0.0002 or evidence.role_b_target_error > 0.0002)
    {
        return error.HandshakeIkEvidenceIncomplete;
    }
    for (evidence.event_counts) |count| if (count != 1) return error.HandshakeIkEventCountMismatch;
    if (perturbed) {
        if (evidence.pre_separation < 0.015 or evidence.post_separation >= evidence.pre_separation * 0.1) {
            return error.PerturbedHandshakeIkCorrectionInsufficient;
        }
    } else if (evidence.post_separation > evidence.pre_separation + 0.000001) {
        return error.NominalHandshakeIkRegressed;
    }
}
