const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const math = @import("math");
const input = @import("input");
const fixed_step = @import("fixed_step");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const character_entity_binding = @import("character_entity_binding");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const foot_planting = @import("foot_planting");
const sprite = @import("sprite_batch");
const diagnostics = @import("diagnostics");
const debug_draw = @import("debug_draw");

pub const required_frames: u32 = 2400;
pub const character_count: usize = 2;
pub const fixed_ticks_per_nominal_frame: u8 = 4;
pub const final_stability_ticks: u32 = 240;

pub const Phase = enum(u8) {
    initial_idle,
    walk_floor,
    jump,
    airborne,
    landing,
    walk_platform,
    approach_interaction,
    handshake,
    post_interaction,
    final_idle,
};

pub const Milestone = enum(u8) {
    walk_started,
    left_foot_planted,
    right_foot_planted,
    jump_started,
    both_feet_released_airborne,
    landing_observed,
    post_landing_replant,
    platform_ground_sample,
    handshake_requested,
    handshake_started,
    handshake_contact,
    arm_ik_contact_satisfied,
    handshake_release,
    handshake_completed,
    interaction_cleanup_complete,
    final_stable_state,
};

pub const milestone_count: usize = @typeInfo(Milestone).@"enum".fields.len;

pub const Configuration = struct {
    debug_visualization: bool = false,
    diagnostics_each_tick: bool = true,
    capture_milestones: bool = true,
};

pub const Evidence = struct {
    milestone_ticks: [milestone_count]?u64 = [_]?u64{null} ** milestone_count,
    phase_entry_ticks: [@typeInfo(Phase).@"enum".fields.len]?u64 = [_]?u64{null} ** @typeInfo(Phase).@"enum".fields.len,
    phase_exit_ticks: [@typeInfo(Phase).@"enum".fields.len]?u64 = [_]?u64{null} ** @typeInfo(Phase).@"enum".fields.len,
    maximum_substeps: u8 = 0,
    jump_count: u32 = 0,
    landing_count: u32 = 0,
    maximum_landing_impact: f32 = 0,
    maximum_landing_compression: f32 = 0,
    interaction_requests: u32 = 0,
    successful_handshakes: u32 = 0,
    rejected_requests: u32 = 0,
    contact_events: u32 = 0,
    release_events: u32 = 0,
    completion_events: u32 = 0,
    maximum_pre_ik_contact_error: f32 = 0,
    maximum_post_ik_contact_error: f32 = 0,
    airborne_false_plants: u32 = 0,
    landing_event_delivery_count: u32 = 0,
    foot_contact_changed_physics: bool = false,
    shared_target_from_pre_ik: bool = false,
    final_pose_after_ik: bool = false,
    partial_interleaving_observed: bool = false,
    foot_placement_during_handshake: bool = false,
    maximum_debug_primitives: u32 = 0,
    ordinary_sprites: u32 = 0,
    debug_primitives: u32 = 0,
};

pub const AuthoritativeState = struct {
    simulation_tick: u64,
    phase: Phase,
    player_position: math.Vec2,
    player_velocity: math.Vec2,
    player_grounded: bool,
    player_support: ?collider.ColliderId,
    player_animation: @import("state_machine").StateId,
    player_animation_time: f32,
    partner_animation: @import("state_machine").StateId,
    partner_animation_time: f32,
    interaction_event_ticks: [interaction.event_count]?u64,
    left_candidate_tick: ?u64,
    left_plant_tick: ?u64,
    left_release_tick: ?u64,
    right_candidate_tick: ?u64,
    right_plant_tick: ?u64,
    right_release_tick: ?u64,
    left_locked_target: ?math.Vec2,
    right_locked_target: ?math.Vec2,
    shared_hand_target: math.Vec2,
    active_interactions: usize,
    participant_locks: usize,
    active_overrides: usize,
    active_arm_constraints: usize,
    maximum_interaction_id: u32,
    milestone_ticks: [milestone_count]?u64,
    allocation_total: u64,
    resources: diagnostics.ResourceSnapshot,
};

pub const FEntityObservation = struct {
    entity_id: foundation.identity.EntityId,
    handle: foundation.identity.EntityHandle,
    effective_enabled: bool,
    local_position: math.Vec2,
    world_position: math.Vec2,
    publication_generation: u64,
};

pub const Scene = struct {
    definition: humanoid.HumanoidDefinition,
    animations: authored.Definitions,
    world: collision_world.CollisionWorld,
    player: character.CharacterInstance,
    partner: character.CharacterInstance,
    entity_bindings: character_entity_binding.CharacterEntityBindings,
    player_entity: foundation.identity.EntityHandle,
    partner_entity: foundation.identity.EntityHandle,
    manager: interaction_system.Manager,
    clock: fixed_step.Clock,
    snapshot_builder: input.SnapshotBuilder = .{},
    pending_input: input.PendingInput = .{},
    configuration: Configuration,
    phase: Phase = .initial_idle,
    phase_tick: u32 = 0,
    platform_stage: u8 = 0,
    approach_stage: u8 = 0,
    simulation_tick: u64 = 0,
    render_frame: u64 = 0,
    active_interaction: interaction_system.InteractionId = .invalid,
    last_interaction_events: [interaction.event_count]?u64 = [_]?u64{null} ** interaction.event_count,
    last_shared_target: math.Vec2 = math.Vec2.zero,
    last_rendering: diagnostics.RenderingSnapshot = .{},
    resources: diagnostics.ResourceSnapshot = .{},
    evidence: Evidence = .{},
    history: diagnostics.History = .{},
    milestones: diagnostics.MilestoneStore = .{},
    latest_diagnostics: diagnostics.Snapshot = .{},
    debug_commands: debug_draw.CommandBuffer = .{},

    pub fn init(allocator: std.mem.Allocator, configuration: Configuration) !Scene {
        return initWithRuntimeAllocator(allocator, allocator, configuration);
    }

    pub fn initWithRuntimeAllocator(
        allocator: std.mem.Allocator,
        runtime_allocator: std.mem.Allocator,
        configuration: Configuration,
    ) !Scene {
        var definition = try humanoid.HumanoidDefinition.init(allocator, null);
        errdefer definition.deinit();
        var animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer animations.deinit();
        var world = try collision_world.CollisionWorld.initDemo(allocator, null);
        errdefer world.deinit();
        var player = try character.CharacterInstance.initControlled(
            allocator,
            try character.entityIdFromRaw(1),
            &definition,
            &animations,
            &world,
            .{},
            .{ .x = -3.15, .y = 1.05 },
            .right,
            0,
            null,
        );
        errdefer player.deinit();
        var partner = try character.CharacterInstance.init(
            allocator,
            try character.entityIdFromRaw(2),
            &definition,
            &animations,
            .{ .x = 2.70, .y = 1.05 },
            .left,
            1,
            null,
        );
        errdefer partner.deinit();
        var entity_bindings = try character_entity_binding.CharacterEntityBindings.initWithRuntimeAllocator(
            allocator,
            runtime_allocator,
        );
        errdefer entity_bindings.deinit();
        const player_entity = try entity_bindings.createPersistent(
            try foundation.identity.EntityId.parseCanonical("0195d5b8-1000-7000-8000-000000000001"),
            player.id(),
            player.worldPosition(),
        );
        const partner_entity = try entity_bindings.createPersistent(
            try foundation.identity.EntityId.parseCanonical("0195d5b8-1000-7000-8000-000000000002"),
            partner.id(),
            partner.worldPosition(),
        );
        var result = Scene{
            .definition = definition,
            .animations = animations,
            .world = world,
            .player = player,
            .partner = partner,
            .entity_bindings = entity_bindings,
            .player_entity = player_entity,
            .partner_entity = partner_entity,
            .manager = interaction_system.Manager.initWithIk(try handshake.definition(&animations)),
            .clock = try fixed_step.Clock.init(.{}),
            .configuration = configuration,
        };
        result.evidence.phase_entry_ticks[@intFromEnum(Phase.initial_idle)] = 0;
        return result;
    }

    pub fn deinit(scene: *Scene) void {
        scene.entity_bindings.deinit();
        scene.partner.deinit();
        scene.player.deinit();
        scene.world.deinit();
        scene.animations.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn updateFrame(scene: *Scene, frame_delta: f64) !void {
        if (!try scene.prepareFBackedSimulation()) {
            scene.render_frame = std.math.add(u64, scene.render_frame, 1) catch return error.RenderFrameOverflow;
            return;
        }
        const frame = try scene.clock.beginFrame(frame_delta);
        scene.evidence.maximum_substeps = @max(scene.evidence.maximum_substeps, frame.substeps);
        for (0..frame.substeps) |_| try scene.updateTick();
        try scene.publishFBackedTransforms();
        scene.render_frame = std.math.add(u64, scene.render_frame, 1) catch return error.RenderFrameOverflow;
    }

    pub fn updateFixedTicks(scene: *Scene, count: u32) !void {
        if (!try scene.prepareFBackedSimulation()) return;
        for (0..count) |_| try scene.updateTick();
        try scene.publishFBackedTransforms();
    }

    fn updateTick(scene: *Scene) !void {
        scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch return error.SimulationTickOverflow;
        const raw = try scene.scriptedRawInput();
        const snapshot = try scene.snapshot_builder.update(raw);
        try scene.pending_input.acceptFrame(snapshot);
        const intent_value = scene.pending_input.consumeTick();

        const physics_result = try scene.player.stepController(&scene.world, intent_value);
        const physics_before_visual = scene.player.controllerSnapshot().?.state;
        if (!scene.player.isInteractionLocked()) try scene.player.selectControllerAnimation(physics_result);
        const player_was_locked = scene.player.isInteractionLocked();
        if (!player_was_locked) {
            try scene.player.advanceVisualTickWithFootPlanting(&scene.world, visualInput(&scene.player, physics_result));
        }
        if (!scene.partner.isInteractionLocked()) {
            if (scene.phase == .walk_floor and scene.partner.animationState() != .walk) {
                try scene.partner.enterAnimationState(.walk);
            }
            const partner_velocity: f32 = if (scene.phase == .walk_floor or scene.phase == .landing or
                scene.phase == .walk_platform or scene.phase == .approach_interaction) -1 else 0;
            try scene.partner.advanceVisualTickWithFootPlanting(&scene.world, .{
                .horizontal_velocity = partner_velocity,
                .physically_grounded = true,
            });
        }

        scene.observeAnimationAndPhysics(physics_before_visual, physics_result);
        const participants_value = scene.participants();
        if (intent_value.interact_pressed) {
            try scene.requireLiveFParticipants();
            scene.evidence.interaction_requests += 1;
            const requested = scene.manager.requestFromIntent(scene.player.id(), intent_value, &participants_value, scene.simulation_tick) catch {
                scene.evidence.rejected_requests += 1;
                return error.IntegratedHandshakeRequestRejected;
            };
            scene.active_interaction = requested orelse return error.IntegratedHandshakeRequestMissing;
            try scene.mark(.handshake_requested);
            try scene.mark(.handshake_started);
            scene.evidence.successful_handshakes += 1;
            try scene.recordDiagnosticMilestone(.handshake_start);
            try scene.transition(.handshake);
        }

        try scene.manager.updateTick(scene.simulation_tick, &participants_value);
        if (scene.manager.firstActiveInstance()) |active| {
            if (active.elapsed_ticks > 0) {
                try scene.player.maintainFootPlantingDuringInteraction(&scene.world);
                try scene.partner.maintainFootPlantingDuringInteraction(&scene.world);
                scene.evidence.foot_placement_during_handshake = scene.evidence.foot_placement_during_handshake or
                    scene.player.footPlantingSnapshot().left.hasLock() or scene.player.footPlantingSnapshot().right.hasLock() or
                    scene.partner.footPlantingSnapshot().left.hasLock() or scene.partner.footPlantingSnapshot().right.hasLock();
            }
            try scene.observeInteraction(active);
        } else if (scene.phase == .handshake) {
            const terminal = scene.manager.lastTerminal() orelse return error.IntegratedHandshakeTerminalMissing;
            scene.last_interaction_events = terminal.event_ticks;
            scene.last_shared_target = terminal.contact.shared_target;
            scene.evidence.completion_events += terminal.event_counts[@intFromEnum(interaction.EventSemantic.complete)];
            try scene.mark(.handshake_completed);
            try scene.mark(.interaction_cleanup_complete);
            try scene.recordDiagnosticMilestone(.handshake_complete);
            try scene.transition(.post_interaction);
        }

        try scene.observePhaseMilestones(physics_result);
        scene.phase_tick = std.math.add(u32, scene.phase_tick, 1) catch return error.PhaseTickOverflow;
        scene.evidence.maximum_landing_compression = @max(
            scene.evidence.maximum_landing_compression,
            @abs(scene.player.proceduralSnapshot().landing_spring.offset),
        );
        if (!scene.player.controllerSnapshot().?.state.grounded and
            (scene.player.footPlantingSnapshot().left.hasLock() or scene.player.footPlantingSnapshot().right.hasLock()))
        {
            scene.evidence.airborne_false_plants += 1;
        }
        if (scene.configuration.diagnostics_each_tick) {
            scene.latest_diagnostics = try scene.captureDiagnostics();
            scene.history.push(scene.latest_diagnostics);
        }
    }

    fn scriptedRawInput(scene: *Scene) !input.RawInputState {
        var raw = input.RawInputState{};
        switch (scene.phase) {
            .initial_idle => {
                if (scene.phase_tick >= 119) try scene.transition(.walk_floor);
            },
            .walk_floor => {
                const interval = (scene.phase_tick / 360) % 2;
                raw.gamepad_left_x = if (interval == 0) 0.56 else -0.56;
            },
            .jump => raw.keyboard.space = scene.phase_tick < 32,
            .airborne => {},
            .landing => {
                const interval = (scene.phase_tick / 240) % 2;
                raw.gamepad_left_x = if (interval == 0) 0.48 else -0.48;
            },
            .walk_platform => switch (scene.platform_stage) {
                0 => raw.keyboard.d = true,
                1 => {
                    raw.keyboard.d = true;
                    raw.keyboard.space = true;
                },
                2 => {
                    raw.keyboard.d = true;
                    raw.keyboard.space = scene.phase_tick < 80;
                },
                3 => raw.keyboard.d = true,
                else => {
                    const position = scene.player.controllerSnapshot().?.state.position.x;
                    raw.gamepad_left_x = if (position > -0.05) -0.44 else 0.44;
                },
            },
            .approach_interaction => switch (scene.approach_stage) {
                0 => {
                    const controller = scene.player.controllerSnapshot().?.state;
                    const target: f32 = -1.02;
                    const command = std.math.clamp((target - controller.position.x) * 1.8 - controller.velocity.x * 0.45, -0.42, 0.42);
                    raw.gamepad_left_x = encodeGamepadAxis(command);
                },
                1 => raw.gamepad_left_x = encodeGamepadAxis(0.25),
                else => {
                    try scene.requireLiveFParticipants();
                    const participants_value = scene.participants();
                    const eligibility = scene.manager.evaluateEligibility(scene.player.id(), scene.partner.id(), &participants_value);
                    if (eligibility.isEligible()) raw.keyboard.e = true;
                },
            },
            .handshake, .post_interaction, .final_idle => {},
        }
        return raw;
    }

    fn observeAnimationAndPhysics(
        scene: *Scene,
        physics_before_visual: character_controller.State,
        physics_result: character_controller.StepResult,
    ) void {
        if (scene.player.emittedAnimationEventCount() > 0) {
            const physics_after_visual = scene.player.controllerSnapshot().?.state;
            scene.evidence.foot_contact_changed_physics = scene.evidence.foot_contact_changed_physics or
                !physics_before_visual.position.approxEqAbs(physics_after_visual.position, 0) or
                !physics_before_visual.velocity.approxEqAbs(physics_after_visual.velocity, 0) or
                physics_before_visual.grounded != physics_after_visual.grounded or
                physics_before_visual.supporting_collider != physics_after_visual.supporting_collider;
        }
        if (physics_result.jump_accepted) scene.evidence.jump_count += 1;
        if (physics_result.landed) {
            scene.evidence.landing_count += 1;
            scene.evidence.maximum_landing_impact = @max(scene.evidence.maximum_landing_impact, physics_result.landing_impact_speed);
            if (scene.player.proceduralSnapshot().last_consumed_landing_tick == physics_result.simulation_tick) {
                scene.evidence.landing_event_delivery_count += 1;
            }
        }
    }

    fn observePhaseMilestones(scene: *Scene, physics_result: character_controller.StepResult) !void {
        switch (scene.phase) {
            .initial_idle => {},
            .walk_floor => {
                if (scene.player.animationState() == .walk) try scene.mark(.walk_started);
                if (scene.player.footPlantingSnapshot().left.metrics.first_plant_tick != null) {
                    try scene.mark(.left_foot_planted);
                    try scene.recordDiagnosticMilestone(.walk_first_left_plant);
                }
                if (scene.player.footPlantingSnapshot().right.metrics.first_plant_tick != null) {
                    try scene.mark(.right_foot_planted);
                    try scene.recordDiagnosticMilestone(.walk_first_right_plant);
                }
                if (scene.hasMilestone(.walk_started) and scene.hasMilestone(.left_foot_planted) and
                    scene.hasMilestone(.right_foot_planted) and scene.phase_tick >= 720)
                {
                    try scene.transition(.jump);
                }
            },
            .jump => if (physics_result.jump_accepted) {
                try scene.mark(.jump_started);
                try scene.recordDiagnosticMilestone(.jump_takeoff);
                try scene.transition(.airborne);
            },
            .airborne => {
                if (!scene.player.controllerSnapshot().?.state.grounded and !scene.player.footPlantingSnapshot().left.hasLock() and
                    !scene.player.footPlantingSnapshot().right.hasLock())
                {
                    try scene.mark(.both_feet_released_airborne);
                }
                if (physics_result.landed) {
                    try scene.mark(.landing_observed);
                    try scene.recordDiagnosticMilestone(.hard_landing);
                    try scene.transition(.landing);
                }
            },
            .landing => {
                const landing_tick = scene.player.controllerSnapshot().?.state.last_landing_tick orelse 0;
                const replanted = (scene.player.footPlantingSnapshot().left.metrics.last_plant_tick orelse 0) > landing_tick or
                    (scene.player.footPlantingSnapshot().right.metrics.last_plant_tick orelse 0) > landing_tick;
                if (replanted and scene.phase_tick >= 240) {
                    try scene.mark(.post_landing_replant);
                    try scene.transition(.walk_platform);
                }
            },
            .walk_platform => {
                const controller = scene.player.controllerSnapshot().?.state;
                switch (scene.platform_stage) {
                    0 => if (controller.grounded and controller.position.x >= -1.75) {
                        scene.platform_stage = 1;
                        scene.phase_tick = 0;
                    },
                    1 => if (physics_result.jump_accepted) {
                        scene.platform_stage = 2;
                        scene.phase_tick = 0;
                    },
                    2 => if (scene.phase_tick >= 80) {
                        scene.platform_stage = 3;
                        scene.phase_tick = 0;
                    },
                    3 => if (physics_result.landed and controller.supporting_collider == @intFromEnum(collision_world.DemoColliderId.raised_platform_1)) {
                        scene.platform_stage = 4;
                        scene.phase_tick = 0;
                    },
                    else => {
                        const left_raised = scene.player.footPlantingSnapshot().left.locked_collider_id == @intFromEnum(collision_world.DemoColliderId.raised_platform_1);
                        const right_raised = scene.player.footPlantingSnapshot().right.locked_collider_id == @intFromEnum(collision_world.DemoColliderId.raised_platform_1);
                        if ((left_raised or right_raised) and scene.phase_tick >= 240) {
                            try scene.mark(.platform_ground_sample);
                            try scene.recordDiagnosticMilestone(.platform_right_plant);
                            try scene.transition(.approach_interaction);
                        }
                    },
                }
            },
            .approach_interaction => {
                const controller = scene.player.controllerSnapshot().?.state;
                if (scene.approach_stage == 0 and controller.grounded and
                    controller.supporting_collider == @intFromEnum(collision_world.DemoColliderId.floor) and
                    @abs(controller.position.x - -1.02) <= 0.015)
                {
                    scene.approach_stage = 1;
                    scene.phase_tick = 0;
                } else if (scene.approach_stage == 1 and scene.phase_tick >= 1) {
                    scene.approach_stage = 2;
                    scene.phase_tick = 0;
                }
            },
            .handshake => {},
            .post_interaction => {
                if (scene.phase_tick >= 240 and scene.manager.activeCount() == 0 and
                    !scene.player.isInteractionLocked() and !scene.partner.isInteractionLocked())
                {
                    try scene.transition(.final_idle);
                }
            },
            .final_idle => if (scene.phase_tick >= final_stability_ticks and !scene.hasMilestone(.final_stable_state)) {
                try scene.mark(.final_stable_state);
                try scene.recordDiagnosticMilestone(.final_state);
            },
        }
    }

    fn observeInteraction(scene: *Scene, active: *const interaction_system.Instance) !void {
        const contact_index = @intFromEnum(interaction.EventSemantic.contact);
        const release_index = @intFromEnum(interaction.EventSemantic.release);
        if (active.event_ticks[contact_index] != null and !scene.hasMilestone(.handshake_contact)) {
            try scene.mark(.handshake_contact);
            scene.evidence.contact_events += active.event_counts[contact_index];
            scene.last_shared_target = active.contact.shared_target;
            scene.evidence.maximum_pre_ik_contact_error = @max(
                active.contact.role_a_pre_socket.sub(active.contact.shared_target).length(),
                active.contact.role_b_pre_socket.sub(active.contact.shared_target).length(),
            );
            scene.evidence.maximum_post_ik_contact_error = @max(active.contact.role_a_target_error, active.contact.role_b_target_error);
            const expected_target = interaction_system.sharedTarget(active.contact.role_a_pre_socket, active.contact.role_b_pre_socket);
            scene.evidence.shared_target_from_pre_ik = expected_target.approxEqAbs(active.contact.shared_target, 0.000001);
            scene.evidence.final_pose_after_ik = (try scene.player.socketPosition(.right_hand)).approxEqAbs(active.contact.role_a_socket, 0.0002) and
                (try scene.partner.socketPosition(.right_hand)).approxEqAbs(active.contact.role_b_socket, 0.0002);
            if (active.contact.role_a_target_error <= 0.0002 and active.contact.role_b_target_error <= 0.0002) {
                try scene.mark(.arm_ik_contact_satisfied);
            }
            try scene.recordDiagnosticMilestone(.handshake_contact);
        }
        if (active.event_ticks[release_index] != null and !scene.hasMilestone(.handshake_release)) {
            try scene.mark(.handshake_release);
            scene.evidence.release_events += active.event_counts[release_index];
            try scene.recordDiagnosticMilestone(.handshake_release);
        }
    }

    fn transition(scene: *Scene, destination: Phase) !void {
        try scene.assertPhaseExit(scene.phase);
        scene.evidence.phase_exit_ticks[@intFromEnum(scene.phase)] = scene.simulation_tick;
        scene.phase = destination;
        scene.phase_tick = 0;
        scene.evidence.phase_entry_ticks[@intFromEnum(destination)] = scene.simulation_tick;
        try scene.assertPhaseEntry(destination);
    }

    fn assertPhaseEntry(scene: *const Scene, phase: Phase) !void {
        switch (phase) {
            .initial_idle => {},
            .walk_floor => if (!scene.player.controllerSnapshot().?.state.grounded) return error.WalkPhaseEnteredAirborne,
            .jump => if (!scene.player.controllerSnapshot().?.state.grounded) return error.JumpPhaseEnteredAirborne,
            .airborne => if (scene.player.controllerSnapshot().?.state.grounded) return error.AirbornePhaseEnteredGrounded,
            .landing => if (!scene.player.controllerSnapshot().?.state.grounded) return error.LandingPhaseEnteredAirborne,
            .walk_platform => if (!scene.hasMilestone(.post_landing_replant)) return error.PlatformPhaseBeforeReplant,
            .approach_interaction => if (!scene.hasMilestone(.platform_ground_sample)) return error.ApproachBeforePlatformSample,
            .handshake => if (scene.manager.activeCount() != 1) return error.HandshakePhaseWithoutInteraction,
            .post_interaction => if (scene.manager.activeCount() != 0) return error.PostInteractionPhaseStillActive,
            .final_idle => if (scene.manager.activeCount() != 0) return error.FinalIdleInteractionActive,
        }
    }

    fn assertPhaseExit(scene: *const Scene, phase: Phase) !void {
        switch (phase) {
            .initial_idle => if (scene.player.animationState() != .idle or !scene.player.controllerSnapshot().?.state.grounded) return error.InitialIdleExitInvalid,
            .walk_floor => if (!scene.hasMilestone(.walk_started) or !scene.hasMilestone(.left_foot_planted) or
                !scene.hasMilestone(.right_foot_planted) or scene.evidence.airborne_false_plants != 0) return error.WalkExitEvidenceMissing,
            .jump => if (!scene.hasMilestone(.jump_started)) return error.JumpExitEvidenceMissing,
            .airborne => if (!scene.hasMilestone(.both_feet_released_airborne) or !scene.hasMilestone(.landing_observed)) return error.AirborneExitEvidenceMissing,
            .landing => if (!scene.hasMilestone(.post_landing_replant) or scene.evidence.landing_event_delivery_count != scene.evidence.landing_count) return error.LandingExitEvidenceMissing,
            .walk_platform => if (!scene.hasMilestone(.platform_ground_sample)) return error.PlatformExitEvidenceMissing,
            .approach_interaction => if (!scene.hasMilestone(.handshake_requested)) return error.ApproachExitEvidenceMissing,
            .handshake => if (!scene.hasMilestone(.handshake_contact) or !scene.hasMilestone(.handshake_release) or
                !scene.hasMilestone(.arm_ik_contact_satisfied)) return error.HandshakeExitEvidenceMissing,
            .post_interaction => if (!scene.hasMilestone(.interaction_cleanup_complete)) return error.PostInteractionExitEvidenceMissing,
            .final_idle => {},
        }
    }

    fn mark(scene: *Scene, milestone: Milestone) !void {
        const index = @intFromEnum(milestone);
        if (scene.evidence.milestone_ticks[index] == null) scene.evidence.milestone_ticks[index] = scene.simulation_tick;
    }

    pub fn hasMilestone(scene: *const Scene, milestone: Milestone) bool {
        return scene.evidence.milestone_ticks[@intFromEnum(milestone)] != null;
    }

    fn recordDiagnosticMilestone(scene: *Scene, milestone: diagnostics.MilestoneId) !void {
        if (!scene.configuration.capture_milestones) return;
        if (scene.milestones.get(milestone) != null) return;
        const snapshot = try scene.captureDiagnostics();
        try scene.milestones.record(milestone, snapshot);
    }

    fn prepareFBackedSimulation(scene: *Scene) !bool {
        const player_enabled = try scene.entity_bindings.isEnabled(scene.player_entity);
        const partner_enabled = try scene.entity_bindings.isEnabled(scene.partner_entity);
        if (player_enabled) try scene.entity_bindings.applySceneTransform(&scene.player);
        if (partner_enabled) try scene.entity_bindings.applySceneTransform(&scene.partner);
        return player_enabled and partner_enabled;
    }

    fn publishFBackedTransforms(scene: *Scene) !void {
        if (try scene.entity_bindings.isEnabled(scene.player_entity)) {
            _ = try scene.entity_bindings.publishCharacterTransform(&scene.player);
        }
        if (try scene.entity_bindings.isEnabled(scene.partner_entity)) {
            _ = try scene.entity_bindings.publishCharacterTransform(&scene.partner);
        }
    }

    fn requireLiveFParticipants(scene: *Scene) !void {
        if (!try scene.entity_bindings.isEnabled(scene.player_entity) or
            !try scene.entity_bindings.isEnabled(scene.partner_entity))
        {
            return error.IntegratedCharacterEntityDisabled;
        }
        const participants_value = scene.participants();
        const resolved_player = try scene.entity_bindings.resolveCharacter(scene.player_entity, &participants_value);
        const resolved_partner = try scene.entity_bindings.resolveCharacter(scene.partner_entity, &participants_value);
        if (resolved_player != &scene.player or resolved_partner != &scene.partner) {
            return error.IntegratedCharacterBindingMismatch;
        }
    }

    pub fn setEntityEnabled(
        scene: *Scene,
        handle: foundation.identity.EntityHandle,
        enabled: bool,
    ) !void {
        const character_id = try scene.entity_bindings.characterForEntity(handle);
        if (!enabled) {
            const participants_value = scene.participants();
            _ = try scene.manager.cancelForCharacter(character_id, .character_reset, &participants_value);
        }
        try scene.entity_bindings.setEnabled(handle, enabled);
    }

    pub fn destroyEntity(scene: *Scene, handle: foundation.identity.EntityHandle) !void {
        const character_id = try scene.entity_bindings.characterForEntity(handle);
        const participants_value = scene.participants();
        _ = try scene.manager.cancelForCharacter(character_id, .character_reset, &participants_value);
        try scene.entity_bindings.destroyEntity(handle);
    }

    pub fn fEntityObservation(
        scene: *Scene,
        handle: foundation.identity.EntityHandle,
    ) !FEntityObservation {
        var snapshot = try scene.entity_bindings.acquireSnapshot(.{
            .tick = scene.simulation_tick,
            .fixed_delta_seconds = @floatCast(fixed_step.fixed_dt_seconds),
            .interpolation_alpha = @floatCast(scene.clock.last_frame.interpolation_alpha),
        });
        defer snapshot.deinit();
        const view = try snapshot.view().get(handle);
        return .{
            .entity_id = view.persistent_id orelse return error.IntegratedPersistentEntityIdMissing,
            .handle = view.handle,
            .effective_enabled = view.effective_enabled,
            .local_position = .{ .x = view.local_transform.translation.x, .y = view.local_transform.translation.y },
            .world_position = .{ .x = view.world_transform.affine.translation.x, .y = view.world_transform.affine.translation.y },
            .publication_generation = snapshot.publication_generation,
        };
    }

    pub fn captureDiagnostics(scene: *const Scene) !diagnostics.Snapshot {
        const participants_value = scene.participantsConst();
        return diagnostics.capture(.{
            .render_frame_index = scene.render_frame,
            .fixed_tick = scene.simulation_tick,
            .clock = &scene.clock,
            .characters = &participants_value,
            .manager = &scene.manager,
            .rendering = scene.last_rendering,
            .resources = scene.resources,
            .debug_command_allocations = scene.debug_commands.submission_allocations,
        });
    }

    pub fn setResourceSnapshot(scene: *Scene, resources: diagnostics.ResourceSnapshot) void {
        scene.resources = resources;
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        var active_characters: [character_count]*character.CharacterInstance = undefined;
        var active_count: usize = 0;
        if (scene.entity_bindings.isEnabled(scene.player_entity) catch false) {
            active_characters[active_count] = &scene.player;
            active_count += 1;
        }
        if (scene.entity_bindings.isEnabled(scene.partner_entity) catch false) {
            active_characters[active_count] = &scene.partner;
            active_count += 1;
        }
        var ordinary = try character.submitGlobally(active_characters[0..active_count], batch);
        for (scene.world.colliders) |static_collider| {
            const center = static_collider.bounds.center();
            const size = static_collider.bounds.size();
            try batch.submit(.{
                .world_position = center.toArray(),
                .rotation = 0,
                .scale = size.toArray(),
                .pivot = .{ 0.5, 0.5 },
                .uv_rect = .{ 0, 0.5, 0.5, 1 },
                .tint = .{ 0.24, 0.31, 0.42, 0.75 },
                .texture_page = 0,
                .order = .{ .scene_layer = character.SceneLayers.world, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = static_collider.id },
            });
            ordinary += 1;
        }
        scene.evidence.ordinary_sprites = ordinary;
        var debug_count: u32 = 0;
        if (scene.configuration.debug_visualization) {
            try scene.buildDebugCommands();
            debug_count = try scene.debug_commands.submit(batch);
            scene.evidence.maximum_debug_primitives = @max(scene.evidence.maximum_debug_primitives, debug_count);
        } else {
            scene.debug_commands.beginFrame();
        }
        scene.evidence.debug_primitives = debug_count;
        scene.observeSubmittedOrdering();
        return ordinary + debug_count;
    }

    fn buildDebugCommands(scene: *Scene) !void {
        scene.debug_commands.beginFrame();
        for (scene.world.colliders) |static_collider| try scene.debug_commands.addAabb(static_collider.bounds, .{ 0.20, 0.80, 1.0, 0.72 });
        const DebugParticipant = struct {
            handle: foundation.identity.EntityHandle,
            instance: *const character.CharacterInstance,
        };
        for ([_]DebugParticipant{
            .{ .handle = scene.player_entity, .instance = &scene.player },
            .{ .handle = scene.partner_entity, .instance = &scene.partner },
        }) |participant| {
            if (!(scene.entity_bindings.isEnabled(participant.handle) catch false)) continue;
            const instance = participant.instance;
            try scene.debug_commands.addMarker(instance.worldPosition(), .{ 1, 0.20, 0.20, 1 });
            const definition = instance.definitionView();
            const root_index = try definition.skeleton_definition.boneIndex(.root);
            const visual_root = (try instance.humanoidView().local_and_world_pose.worldForBone(
                &definition.skeleton_definition,
                root_index,
            )).translationPart();
            try scene.debug_commands.addMarker(visual_root, .{ 1, 0.85, 0.10, 1 });
            const feet = instance.footPlantingSnapshot();
            for ([_]*const foot_planting.FootRuntime{ &feet.left, &feet.right }) |foot| {
                if (foot.last_ground_sample.hit) {
                    const origin = foot.pre_ik_sole.add(.{ .x = 0, .y = foot_planting.ground_query_origin_lift });
                    try scene.debug_commands.addLine(origin, foot.last_ground_sample.hit_position, .{ 0.20, 1, 0.40, 0.80 });
                    try scene.debug_commands.addMarker(foot.last_ground_sample.hit_position, .{ 0.20, 1, 0.40, 1 });
                }
                if (foot.locked_target) |target| {
                    try scene.debug_commands.addMarker(target, .{ 1, 0.20, 1, 1 });
                    try scene.debug_commands.addLine(foot.pre_ik_sole, foot.post_ik_sole, .{ 1, 0.55, 0.10, 0.90 });
                }
            }
            if (instance.rightHandIkMetrics()) |metrics| {
                try scene.debug_commands.addLine(metrics.shoulder_position, metrics.elbow_position, .{ 1, 0.65, 0.05, 1 });
                try scene.debug_commands.addLine(metrics.elbow_position, metrics.post_ik_hand_position, .{ 1, 0.65, 0.05, 1 });
                try scene.debug_commands.addMarker(metrics.post_ik_hand_position, .{ 1, 1, 0.10, 1 });
            }
        }
        if (scene.manager.firstActiveInstance()) |active| {
            if (active.ik.target_valid) try scene.debug_commands.addMarker(active.ik.shared_target, .{ 0.10, 1, 1, 1 });
            try scene.debug_commands.addLine(scene.player.worldPosition(), scene.partner.worldPosition(), .{ 0.65, 0.25, 1, 0.70 });
        }
    }

    fn observeSubmittedOrdering(scene: *Scene) void {
        if (!(scene.entity_bindings.isEnabled(scene.player_entity) catch false) or
            !(scene.entity_bindings.isEnabled(scene.partner_entity) catch false)) return;
        if (!scene.hasMilestone(.handshake_contact) or scene.hasMilestone(.handshake_release)) return;
        const a_hand = scene.player.submittedKey(.right_hand) catch return;
        const b_hand = scene.partner.submittedKey(.right_hand) catch return;
        const a_forearm = scene.player.submittedKey(.right_forearm) catch return;
        const b_torso = scene.partner.submittedKey(.torso) catch return;
        scene.evidence.partial_interleaving_observed = sprite.keyLessThan(b_hand, a_hand) and sprite.keyLessThan(b_torso, a_forearm);
    }

    pub fn recordRendering(scene: *Scene, rendering: diagnostics.RenderingSnapshot) void {
        scene.last_rendering = rendering;
    }

    pub fn authoritativeState(scene: *const Scene) !AuthoritativeState {
        const controller = scene.player.controllerSnapshot().?.state;
        const snapshot = try scene.captureDiagnostics();
        const feet = scene.player.footPlantingSnapshot();
        const left_lifecycle = feet.left.metrics.latest_acquired_lifecycle;
        const right_lifecycle = feet.right.metrics.latest_acquired_lifecycle;
        return .{
            .simulation_tick = scene.simulation_tick,
            .phase = scene.phase,
            .player_position = controller.position,
            .player_velocity = controller.velocity,
            .player_grounded = controller.grounded,
            .player_support = controller.supporting_collider,
            .player_animation = scene.player.animationState(),
            .player_animation_time = scene.player.animationTime(),
            .partner_animation = scene.partner.animationState(),
            .partner_animation_time = scene.partner.animationTime(),
            .interaction_event_ticks = scene.last_interaction_events,
            .left_candidate_tick = left_lifecycle.candidate_acquisition_tick,
            .left_plant_tick = left_lifecycle.full_plant_tick,
            .left_release_tick = left_lifecycle.release_start_tick,
            .right_candidate_tick = right_lifecycle.candidate_acquisition_tick,
            .right_plant_tick = right_lifecycle.full_plant_tick,
            .right_release_tick = right_lifecycle.release_start_tick,
            .left_locked_target = feet.left.locked_target,
            .right_locked_target = feet.right.locked_target,
            .shared_hand_target = scene.last_shared_target,
            .active_interactions = scene.manager.activeCount(),
            .participant_locks = @as(usize, @intFromBool(scene.player.isInteractionLocked())) +
                @as(usize, @intFromBool(scene.partner.isInteractionLocked())),
            .active_overrides = scene.manager.activeOwnedOverrideCount(),
            .active_arm_constraints = scene.manager.activeIkConstraintCount(),
            .maximum_interaction_id = scene.manager.maximumIssuedId(),
            .milestone_ticks = scene.evidence.milestone_ticks,
            .allocation_total = snapshot.allocations.total(),
            .resources = snapshot.resources,
        };
    }

    pub fn validateComplete(scene: *Scene) !void {
        for (scene.evidence.milestone_ticks) |tick| {
            if (tick == null) {
                const controller_state = scene.player.controllerSnapshot().?.state;
                const feet = scene.player.footPlantingSnapshot();
                std.log.err("integrated route incomplete phase={s} phase_tick={d} platform_stage={d} approach_stage={d} simulation_tick={d} milestones={any} position=({d:.6},{d:.6}) velocity=({d:.6},{d:.6}) grounded={} support={any} animation={s} plants={s}/{s} locks={}/{}", .{
                    @tagName(scene.phase),
                    scene.phase_tick,
                    scene.platform_stage,
                    scene.approach_stage,
                    scene.simulation_tick,
                    scene.evidence.milestone_ticks,
                    controller_state.position.x,
                    controller_state.position.y,
                    controller_state.velocity.x,
                    controller_state.velocity.y,
                    controller_state.grounded,
                    controller_state.supporting_collider,
                    @tagName(scene.player.animationState()),
                    @tagName(feet.left.plant_state),
                    @tagName(feet.right.plant_state),
                    feet.left.hasLock(),
                    feet.right.hasLock(),
                });
                return error.IntegratedMilestoneMissing;
            }
        }
        try scene.validateMilestoneDependencies();
        const controller = scene.player.controllerSnapshot().?.state;
        if (scene.phase != .final_idle or !controller.position.isFinite() or !controller.velocity.isFinite() or
            scene.manager.activeCount() != 0 or scene.player.isInteractionLocked() or scene.partner.isInteractionLocked() or
            scene.manager.activeOwnedOverrideCount() != 0 or scene.manager.activeIkConstraintCount() != 0 or
            scene.player.activeOverrideCount() != 0 or scene.partner.activeOverrideCount() != 0 or
            scene.evidence.airborne_false_plants != 0 or scene.evidence.foot_contact_changed_physics or
            scene.evidence.landing_event_delivery_count != scene.evidence.landing_count or
            !scene.evidence.shared_target_from_pre_ik or !scene.evidence.final_pose_after_ik or
            !scene.evidence.partial_interleaving_observed or !scene.evidence.foot_placement_during_handshake or
            scene.evidence.contact_events != 1 or scene.evidence.release_events != 1 or scene.evidence.successful_handshakes != 1 or
            scene.evidence.maximum_post_ik_contact_error > 0.0002 or
            @abs(scene.player.proceduralSnapshot().landing_spring.offset) > 0.01 or
            @abs(scene.player.proceduralSnapshot().secondary_spring.offset) > 0.01)
        {
            return error.IntegratedFinalStateInvalid;
        }
        const snapshot = try scene.captureDiagnostics();
        if (snapshot.allocations.total() != 0 or scene.debug_commands.overflow_count != 0) return error.IntegratedSteadyStateGateFailed;
        const player_f = try scene.fEntityObservation(scene.player_entity);
        const partner_f = try scene.fEntityObservation(scene.partner_entity);
        if (scene.entity_bindings.bindingCount() != character_count or
            !player_f.handle.eql(scene.player_entity) or
            !partner_f.handle.eql(scene.partner_entity) or
            !player_f.entity_id.eql(try scene.entity_bindings.persistentIdForCharacter(scene.player.id())) or
            !partner_f.entity_id.eql(try scene.entity_bindings.persistentIdForCharacter(scene.partner.id())) or
            !player_f.effective_enabled or !partner_f.effective_enabled or
            !player_f.local_position.approxEqAbs(scene.player.worldPosition(), character_entity_binding.root_tolerance) or
            !player_f.world_position.approxEqAbs(scene.player.worldPosition(), character_entity_binding.root_tolerance) or
            !partner_f.local_position.approxEqAbs(scene.partner.worldPosition(), character_entity_binding.root_tolerance) or
            !partner_f.world_position.approxEqAbs(scene.partner.worldPosition(), character_entity_binding.root_tolerance))
        {
            return error.IntegratedFSceneStateInvalid;
        }
    }

    pub fn validateMilestoneDependencies(scene: *const Scene) !void {
        const ticks = scene.evidence.milestone_ticks;
        try requireMilestoneOrder(ticks, .walk_started, .jump_started);
        try requireMilestoneOrder(ticks, .left_foot_planted, .jump_started);
        try requireMilestoneOrder(ticks, .right_foot_planted, .jump_started);
        try requireMilestoneOrder(ticks, .jump_started, .both_feet_released_airborne);
        try requireMilestoneOrder(ticks, .both_feet_released_airborne, .landing_observed);
        try requireMilestoneOrder(ticks, .landing_observed, .post_landing_replant);
        try requireMilestoneOrder(ticks, .post_landing_replant, .platform_ground_sample);
        try requireMilestoneOrder(ticks, .platform_ground_sample, .handshake_requested);
        try requireMilestoneOrder(ticks, .handshake_requested, .handshake_started);
        try requireMilestoneOrder(ticks, .handshake_started, .handshake_contact);
        try requireMilestoneOrder(ticks, .handshake_contact, .arm_ik_contact_satisfied);
        try requireMilestoneOrder(ticks, .arm_ik_contact_satisfied, .handshake_release);
        try requireMilestoneOrder(ticks, .handshake_release, .handshake_completed);
        try requireMilestoneOrder(ticks, .handshake_completed, .interaction_cleanup_complete);
        try requireMilestoneOrder(ticks, .interaction_cleanup_complete, .final_stable_state);
    }

    pub fn resetAll(scene: *Scene) !void {
        const participants_value = scene.participants();
        try scene.manager.reset(&participants_value);
        try scene.player.resetControlled(&scene.world);
        try scene.partner.reset();
        try scene.publishFBackedTransforms();
        scene.snapshot_builder.reset();
        scene.pending_input.reset();
        scene.clock.reset();
        scene.phase = .initial_idle;
        scene.phase_tick = 0;
        scene.platform_stage = 0;
        scene.approach_stage = 0;
        scene.simulation_tick = 0;
        scene.render_frame = 0;
        scene.active_interaction = .invalid;
        scene.last_interaction_events = [_]?u64{null} ** interaction.event_count;
        scene.last_shared_target = math.Vec2.zero;
        scene.evidence = .{};
        scene.evidence.phase_entry_ticks[@intFromEnum(Phase.initial_idle)] = 0;
        scene.history.reset();
        scene.milestones.reset();
        scene.latest_diagnostics = .{};
        scene.debug_commands.beginFrame();
    }

    pub fn restartCyclePreservingCounters(scene: *Scene) !void {
        if (scene.manager.activeCount() != 0) return error.StressCycleRestartWhileInteractionActive;
        const preserved_tick = scene.simulation_tick;
        const preserved_frame = scene.render_frame;
        try scene.player.resetControlled(&scene.world);
        try scene.partner.reset();
        try scene.publishFBackedTransforms();
        scene.snapshot_builder.reset();
        scene.pending_input.reset();
        scene.phase = .initial_idle;
        scene.phase_tick = 0;
        scene.platform_stage = 0;
        scene.approach_stage = 0;
        scene.simulation_tick = preserved_tick;
        scene.render_frame = preserved_frame;
        scene.active_interaction = .invalid;
        scene.last_interaction_events = [_]?u64{null} ** interaction.event_count;
        scene.last_shared_target = math.Vec2.zero;
        scene.evidence = .{};
        scene.evidence.phase_entry_ticks[@intFromEnum(Phase.initial_idle)] = preserved_tick;
        scene.history.reset();
        scene.milestones.reset();
        scene.latest_diagnostics = .{};
        scene.debug_commands.beginFrame();
    }

    pub fn resetCharacter(scene: *Scene, entity_id: character.EntityId) !void {
        const participants_value = scene.participants();
        _ = try scene.manager.cancelForCharacter(entity_id, .character_reset, &participants_value);
        if (entity_id == scene.player.id()) {
            try scene.player.resetControlled(&scene.world);
            _ = try scene.entity_bindings.publishCharacterTransform(&scene.player);
        } else if (entity_id == scene.partner.id()) {
            try scene.partner.reset();
            _ = try scene.entity_bindings.publishCharacterTransform(&scene.partner);
        } else {
            return error.InvalidCharacterResetTarget;
        }
    }

    fn participants(scene: *Scene) [character_count]*character.CharacterInstance {
        return .{ &scene.player, &scene.partner };
    }

    fn participantsConst(scene: *const Scene) [character_count]*const character.CharacterInstance {
        return .{ &scene.player, &scene.partner };
    }
};

fn visualInput(instance: *const character.CharacterInstance, physics: character_controller.StepResult) character.VisualTickInput {
    const controller = instance.controllerSnapshot().?;
    return .{
        .horizontal_velocity = controller.state.velocity.x,
        .vertical_velocity = controller.state.velocity.y,
        .physically_grounded = controller.state.grounded,
        .landing_event = if (physics.landed) .{
            .simulation_tick = physics.simulation_tick,
            .impact_speed = physics.landing_impact_speed,
        } else null,
    };
}

fn encodeGamepadAxis(desired_axis: f32) f32 {
    if (@abs(desired_axis) <= std.math.floatEps(f32)) return 0;
    return std.math.sign(desired_axis) * (input.gamepad_dead_zone + @abs(desired_axis) * (1 - input.gamepad_dead_zone));
}

pub fn authoritativeStatesEqual(left: AuthoritativeState, right: AuthoritativeState, tolerance: f32) bool {
    if (left.simulation_tick != right.simulation_tick or left.phase != right.phase or
        !left.player_position.approxEqAbs(right.player_position, tolerance) or
        !left.player_velocity.approxEqAbs(right.player_velocity, tolerance) or
        left.player_grounded != right.player_grounded or left.player_support != right.player_support or
        left.player_animation != right.player_animation or @abs(left.player_animation_time - right.player_animation_time) > tolerance or
        left.partner_animation != right.partner_animation or @abs(left.partner_animation_time - right.partner_animation_time) > tolerance or
        !std.meta.eql(left.interaction_event_ticks, right.interaction_event_ticks) or
        left.left_candidate_tick != right.left_candidate_tick or left.left_plant_tick != right.left_plant_tick or left.left_release_tick != right.left_release_tick or
        left.right_candidate_tick != right.right_candidate_tick or left.right_plant_tick != right.right_plant_tick or left.right_release_tick != right.right_release_tick or
        !optionalVecEqual(left.left_locked_target, right.left_locked_target, tolerance) or
        !optionalVecEqual(left.right_locked_target, right.right_locked_target, tolerance) or
        !left.shared_hand_target.approxEqAbs(right.shared_hand_target, tolerance) or
        left.active_interactions != right.active_interactions or left.participant_locks != right.participant_locks or
        left.active_overrides != right.active_overrides or left.active_arm_constraints != right.active_arm_constraints or
        left.maximum_interaction_id != right.maximum_interaction_id or
        !std.meta.eql(left.milestone_ticks, right.milestone_ticks) or left.allocation_total != right.allocation_total)
    {
        return false;
    }
    if (!std.meta.eql(left.resources, right.resources)) return false;
    return true;
}

fn optionalVecEqual(left: ?math.Vec2, right: ?math.Vec2, tolerance: f32) bool {
    if (left == null or right == null) return left == null and right == null;
    return left.?.approxEqAbs(right.?, tolerance);
}

fn requireMilestoneOrder(ticks: [milestone_count]?u64, prerequisite: Milestone, dependent: Milestone) !void {
    const prerequisite_tick = ticks[@intFromEnum(prerequisite)] orelse return error.IntegratedMilestoneMissing;
    const dependent_tick = ticks[@intFromEnum(dependent)] orelse return error.IntegratedMilestoneMissing;
    if (prerequisite_tick > dependent_tick) return error.IntegratedMilestoneDependencyViolation;
}

comptime {
    if (fixed_ticks_per_nominal_frame != fixed_step.simulation_hz / 60) @compileError("integrated demo cadence must represent the authoritative fixed step");
    if (required_frames * fixed_ticks_per_nominal_frame < 2400) @compileError("integrated route must provide enough fixed ticks for every phase");
}
