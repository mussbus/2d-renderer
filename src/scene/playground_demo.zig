const std = @import("std");
const math = @import("math");
const input = @import("input");
const fixed_step = @import("fixed_step");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const foot_planting = @import("foot_planting");
const sprite = @import("sprite_batch");
const debug_draw = @import("debug_draw");

pub const required_frames: u32 = 1800;
pub const side_scroller_required_frames: u32 = 1100;
pub const character_count: usize = 2;
pub const player_spawn = math.Vec2{ .x = -3.15, .y = 1.05 };
pub const partner_spawn = math.Vec2{ .x = 2.70, .y = 1.05 };
pub const handshake_player_x: f32 = partner_spawn.x - handshake.authored_horizontal_separation;
pub const world_min_x: f32 = -32;
pub const world_max_x: f32 = 32;
pub const distant_camera_x_factor: f32 = 0.125;
pub const midground_camera_x_factor: f32 = 0.45;

pub const InputDiagnostics = struct {
    keyboard_left_held: bool = false,
    keyboard_right_held: bool = false,
    jump_pressed: bool = false,
    jump_held: bool = false,
    jump_released: bool = false,
    interact_pressed: bool = false,
    reset_pressed: bool = false,
    debug_toggle_pressed: bool = false,
    merged_move_axis: f32 = 0,
    substeps_this_frame: u8 = 0,
    pending_edge_count: u8 = 0,
};

pub const Evidence = struct {
    input_frames: u64 = 0,
    jump_press_count: u32 = 0,
    jump_release_count: u32 = 0,
    interact_press_count: u32 = 0,
    reset_press_count: u32 = 0,
    debug_toggle_count: u32 = 0,
    interaction_requests: u32 = 0,
    successful_interactions: u32 = 0,
    rejected_interactions: u32 = 0,
    held_interaction_restarts: u32 = 0,
    contact_events: u32 = 0,
    release_events: u32 = 0,
    completion_events: u32 = 0,
    maximum_substeps: u8 = 0,
    maximum_debug_primitives: u32 = 0,
    ordinary_sprites: u32 = 0,
    debug_primitives: u32 = 0,
};

pub const AuthoritativeState = struct {
    player_position: math.Vec2,
    player_velocity: math.Vec2,
    player_grounded: bool,
    player_support: ?collider.ColliderId,
    player_facing: humanoid.Facing,
    player_animation: @import("state_machine").StateId,
    player_animation_time: f32,
    partner_animation: @import("state_machine").StateId,
    partner_animation_time: f32,
    player_landing_offset: f32,
    player_secondary_offset: f32,
    left_locked_target: ?math.Vec2,
    right_locked_target: ?math.Vec2,
    active_interactions: usize,
    participant_locks: usize,
    active_overrides: usize,
    active_arm_constraints: usize,
};

pub const Scene = struct {
    definition: humanoid.HumanoidDefinition,
    animations: authored.Definitions,
    world: collision_world.CollisionWorld,
    player: character.CharacterInstance,
    partner: character.CharacterInstance,
    manager: interaction_system.Manager,
    clock: fixed_step.Clock,
    pending_input: input.PendingInput = .{},
    debug_visualization: bool = false,
    simulation_tick: u64 = 0,
    render_frame: u64 = 0,
    active_interaction: interaction_system.InteractionId = .invalid,
    observed_interaction: interaction_system.InteractionId = .invalid,
    observed_event_counts: [interaction.event_count]u8 = [_]u8{0} ** interaction.event_count,
    last_terminal_id: interaction_system.InteractionId = .invalid,
    latest_input: InputDiagnostics = .{},
    evidence: Evidence = .{},
    debug_commands: debug_draw.CommandBuffer = .{},

    pub fn init(allocator: std.mem.Allocator, debug_visualization: bool) !Scene {
        var definition = try humanoid.HumanoidDefinition.init(allocator, null);
        errdefer definition.deinit();
        var animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer animations.deinit();
        const world_inputs = sideScrollingColliderInputs();
        var world = try collision_world.CollisionWorld.init(allocator, &world_inputs, null);
        errdefer world.deinit();
        var player = try character.CharacterInstance.initControlled(
            allocator,
            try character.entityIdFromRaw(1),
            &definition,
            &animations,
            &world,
            .{},
            player_spawn,
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
            partner_spawn,
            .left,
            1,
            null,
        );
        errdefer partner.deinit();
        return .{
            .definition = definition,
            .animations = animations,
            .world = world,
            .player = player,
            .partner = partner,
            .manager = interaction_system.Manager.initWithIk(try handshake.definition(&animations)),
            .clock = try fixed_step.Clock.init(.{}),
            .debug_visualization = debug_visualization,
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.partner.deinit();
        scene.player.deinit();
        scene.world.deinit();
        scene.animations.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn updateFrame(scene: *Scene, frame_delta: f64, snapshot: input.FrameInputSnapshot) !void {
        scene.evidence.input_frames = std.math.add(u64, scene.evidence.input_frames, 1) catch return error.InputFrameOverflow;
        scene.recordInputEdges(snapshot);

        if (snapshot.reset.pressed) {
            try scene.resetWorld();
            scene.latest_input = diagnosticsFrom(snapshot, 0, 0);
            scene.render_frame = std.math.add(u64, scene.render_frame, 1) catch return error.RenderFrameOverflow;
            return;
        }
        if (snapshot.debug_toggle.pressed) scene.debug_visualization = !scene.debug_visualization;

        try scene.pending_input.acceptFrame(snapshot);
        const frame = try scene.clock.beginFrame(frame_delta);
        scene.evidence.maximum_substeps = @max(scene.evidence.maximum_substeps, frame.substeps);
        for (0..frame.substeps) |_| try scene.updateTick(snapshot.interact.held);
        scene.latest_input = diagnosticsFrom(snapshot, frame.substeps, scene.pending_input.pendingEdgeCount());
        scene.render_frame = std.math.add(u64, scene.render_frame, 1) catch return error.RenderFrameOverflow;
    }

    fn updateTick(scene: *Scene, interact_held: bool) !void {
        scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch return error.SimulationTickOverflow;
        const intent_value = scene.pending_input.consumeTick();

        const physics_result = try scene.player.stepController(&scene.world, intent_value);
        if (!scene.player.isInteractionLocked()) {
            try scene.player.selectControllerAnimation(physics_result);
            try scene.player.advanceVisualTickWithFootPlanting(&scene.world, visualInput(&scene.player, physics_result));
        }
        if (!scene.partner.isInteractionLocked()) {
            try scene.partner.advanceVisualTickWithFootPlanting(&scene.world, .{
                .horizontal_velocity = 0,
                .physically_grounded = true,
            });
        }

        const participants_value = scene.participants();
        if (intent_value.interact_pressed) {
            scene.evidence.interaction_requests += 1;
            const requested = scene.manager.requestFromIntent(
                scene.player.id(),
                intent_value,
                &participants_value,
                scene.simulation_tick,
            ) catch |err| switch (err) {
                error.NoEligibleInteractionCandidate => blk: {
                    scene.evidence.rejected_interactions += 1;
                    break :blk null;
                },
                else => return err,
            };
            if (requested) |id| {
                if (interact_held and !intent_value.interact_pressed) scene.evidence.held_interaction_restarts += 1;
                scene.active_interaction = id;
                scene.observed_interaction = id;
                scene.observed_event_counts = [_]u8{0} ** interaction.event_count;
                scene.evidence.successful_interactions += 1;
            }
        }

        try scene.manager.updateTick(scene.simulation_tick, &participants_value);
        if (scene.manager.firstActiveInstance()) |active| {
            if (active.elapsed_ticks > 0) {
                try scene.player.maintainFootPlantingDuringInteraction(&scene.world);
                try scene.partner.maintainFootPlantingDuringInteraction(&scene.world);
            }
            scene.observeInteraction(active);
        } else if (scene.manager.lastTerminal()) |terminal| {
            if (terminal.id != scene.last_terminal_id) {
                scene.observeInteraction(terminal);
                scene.last_terminal_id = terminal.id;
                scene.active_interaction = .invalid;
            }
        }
    }

    fn recordInputEdges(scene: *Scene, snapshot: input.FrameInputSnapshot) void {
        scene.evidence.jump_press_count += @intFromBool(snapshot.jump.pressed);
        scene.evidence.jump_release_count += @intFromBool(snapshot.jump.released);
        scene.evidence.interact_press_count += @intFromBool(snapshot.interact.pressed);
        scene.evidence.reset_press_count += @intFromBool(snapshot.reset.pressed);
        scene.evidence.debug_toggle_count += @intFromBool(snapshot.debug_toggle.pressed);
    }

    fn observeInteraction(scene: *Scene, instance: *const interaction_system.Instance) void {
        if (scene.observed_interaction != instance.id) {
            scene.observed_interaction = instance.id;
            scene.observed_event_counts = [_]u8{0} ** interaction.event_count;
        }
        for (instance.event_counts, 0..) |count, index| {
            const previous = scene.observed_event_counts[index];
            if (count <= previous) continue;
            const delta: u32 = count - previous;
            switch (@as(interaction.EventSemantic, @enumFromInt(index))) {
                .contact => scene.evidence.contact_events += delta,
                .release => scene.evidence.release_events += delta,
                .complete => scene.evidence.completion_events += delta,
            }
            scene.observed_event_counts[index] = count;
        }
    }

    pub fn resetWorld(scene: *Scene) !void {
        const participants_value = scene.participants();
        try scene.manager.reset(&participants_value);
        try scene.player.resetControlled(&scene.world);
        try scene.partner.reset();
        scene.pending_input.reset();
        scene.clock.reset();
        scene.simulation_tick = 0;
        scene.active_interaction = .invalid;
        scene.observed_interaction = .invalid;
        scene.observed_event_counts = [_]u8{0} ** interaction.event_count;
        scene.latest_input = .{};
        scene.debug_commands.beginFrame();
    }

    pub fn interactionEligibility(scene: *Scene) interaction_system.Eligibility {
        const participants_value = scene.participants();
        return scene.manager.evaluateEligibility(scene.player.id(), scene.partner.id(), &participants_value);
    }

    pub fn authoritativeState(scene: *const Scene) AuthoritativeState {
        const controller = scene.player.controllerSnapshot().?.state;
        const procedural = scene.player.proceduralSnapshot();
        const feet = scene.player.footPlantingSnapshot();
        return .{
            .player_position = controller.position,
            .player_velocity = controller.velocity,
            .player_grounded = controller.grounded,
            .player_support = controller.supporting_collider,
            .player_facing = scene.player.facingDirection(),
            .player_animation = scene.player.animationState(),
            .player_animation_time = scene.player.animationTime(),
            .partner_animation = scene.partner.animationState(),
            .partner_animation_time = scene.partner.animationTime(),
            .player_landing_offset = procedural.landing_spring.offset,
            .player_secondary_offset = procedural.secondary_spring.offset,
            .left_locked_target = feet.left.locked_target,
            .right_locked_target = feet.right.locked_target,
            .active_interactions = scene.manager.activeCount(),
            .participant_locks = @intFromBool(scene.player.isInteractionLocked()) + @intFromBool(scene.partner.isInteractionLocked()),
            .active_overrides = scene.manager.activeOwnedOverrideCount(),
            .active_arm_constraints = scene.manager.activeIkConstraintCount(),
        };
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        const participants_value = scene.participants();
        var ordinary = try submitCaveEnvironment(batch);
        ordinary += try character.submitGlobally(&participants_value, batch);
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
        if (scene.debug_visualization) {
            try scene.buildDebugCommands();
            debug_count = try scene.debug_commands.submit(batch);
            scene.evidence.maximum_debug_primitives = @max(scene.evidence.maximum_debug_primitives, debug_count);
        } else {
            scene.debug_commands.beginFrame();
        }
        scene.evidence.debug_primitives = debug_count;
        return ordinary + debug_count;
    }

    fn buildDebugCommands(scene: *Scene) !void {
        scene.debug_commands.beginFrame();
        for (scene.world.colliders) |static_collider| try scene.debug_commands.addAabb(static_collider.bounds, .{ 0.20, 0.80, 1.0, 0.72 });
        for ([_]*const character.CharacterInstance{ &scene.player, &scene.partner }) |instance| {
            try scene.debug_commands.addMarker(instance.worldPosition(), .{ 1, 0.20, 0.20, 1 });
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

    fn participants(scene: *Scene) [character_count]*character.CharacterInstance {
        return .{ &scene.player, &scene.partner };
    }
};

pub fn sideScrollingColliderInputs() [5]collider.StaticColliderInput {
    return .{
        staticCollider(@intFromEnum(collision_world.DemoColliderId.floor), world_min_x, -1, world_max_x, 0, true),
        staticCollider(@intFromEnum(collision_world.DemoColliderId.right_wall), world_max_x - 0.3, 0, world_max_x, 6, false),
        staticCollider(@intFromEnum(collision_world.DemoColliderId.ceiling), -2.8, 2.6, -1.8, 2.9, false),
        staticCollider(@intFromEnum(collision_world.DemoColliderId.raised_platform_1), -0.7, 0.9, 0.4, 1.15, true),
        staticCollider(@intFromEnum(collision_world.DemoColliderId.raised_platform_2), 1.8, 1.5, 2.7, 1.75, true),
    };
}

fn staticCollider(
    id: collider.ColliderId,
    minimum_x: f32,
    minimum_y: f32,
    maximum_x: f32,
    maximum_y: f32,
    ground_query_eligible: bool,
) collider.StaticColliderInput {
    return .{
        .id = id,
        .bounds = .{
            .minimum = .{ .x = minimum_x, .y = minimum_y },
            .maximum = .{ .x = maximum_x, .y = maximum_y },
        },
        .ground_query_eligible = ground_query_eligible,
    };
}

const CaveQuad = struct {
    position: [2]f32,
    size: [2]f32,
    tint: [4]f32,
};

fn submitCaveEnvironment(batch: *sprite.SpriteBatch) !u32 {
    const distant = [_]CaveQuad{
        .{ .position = .{ 0, 3.0 }, .size = .{ 96, 8.5 }, .tint = .{ 0.08, 0.10, 0.18, 1 } },
        .{ .position = .{ -24, 1.6 }, .size = .{ 5.0, 4.2 }, .tint = .{ 0.13, 0.17, 0.27, 0.92 } },
        .{ .position = .{ -12, 1.3 }, .size = .{ 3.2, 3.5 }, .tint = .{ 0.12, 0.16, 0.25, 0.94 } },
        .{ .position = .{ 0, 1.5 }, .size = .{ 4.5, 4.0 }, .tint = .{ 0.15, 0.18, 0.29, 0.90 } },
        .{ .position = .{ 12, 1.2 }, .size = .{ 3.8, 3.4 }, .tint = .{ 0.11, 0.15, 0.24, 0.94 } },
        .{ .position = .{ 24, 1.7 }, .size = .{ 5.4, 4.4 }, .tint = .{ 0.14, 0.17, 0.28, 0.92 } },
    };
    const midground = [_]CaveQuad{
        .{ .position = .{ -28, 1.4 }, .size = .{ 0.65, 4.4 }, .tint = .{ 0.20, 0.24, 0.34, 0.88 } },
        .{ .position = .{ -20, 1.1 }, .size = .{ 0.45, 3.6 }, .tint = .{ 0.24, 0.27, 0.38, 0.84 } },
        .{ .position = .{ -12, 1.6 }, .size = .{ 0.75, 4.6 }, .tint = .{ 0.19, 0.23, 0.35, 0.88 } },
        .{ .position = .{ -4, 1.0 }, .size = .{ 0.50, 3.3 }, .tint = .{ 0.25, 0.29, 0.40, 0.84 } },
        .{ .position = .{ 4, 1.5 }, .size = .{ 0.70, 4.3 }, .tint = .{ 0.20, 0.24, 0.36, 0.88 } },
        .{ .position = .{ 12, 1.2 }, .size = .{ 0.55, 3.8 }, .tint = .{ 0.24, 0.28, 0.39, 0.84 } },
        .{ .position = .{ 20, 1.7 }, .size = .{ 0.80, 4.8 }, .tint = .{ 0.18, 0.22, 0.34, 0.88 } },
        .{ .position = .{ 28, 1.1 }, .size = .{ 0.48, 3.5 }, .tint = .{ 0.24, 0.28, 0.40, 0.84 } },
    };

    var submitted: u32 = 0;
    for (distant, 0..) |quad, index| {
        try submitCaveQuad(batch, quad, character.SceneLayers.background, @intCast(index), distant_camera_x_factor);
        submitted += 1;
    }
    for (midground, 0..) |quad, index| {
        try submitCaveQuad(batch, quad, character.SceneLayers.midground, @intCast(index), midground_camera_x_factor);
        submitted += 1;
    }
    return submitted;
}

fn submitCaveQuad(
    batch: *sprite.SpriteBatch,
    quad: CaveQuad,
    scene_layer: i16,
    body_part_layer: u16,
    camera_x_factor: f32,
) !void {
    try batch.submit(.{
        .world_position = quad.position,
        .rotation = 0,
        .scale = quad.size,
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 0.5, 0.5 },
        .tint = quad.tint,
        .texture_page = 0,
        .camera_x_factor = camera_x_factor,
        .order = .{
            .scene_layer = scene_layer,
            .interaction_layer = 0,
            .actor_layer = 0,
            .body_part_layer = body_part_layer,
        },
    });
}

pub fn authoritativeStatesEqual(left: AuthoritativeState, right: AuthoritativeState, tolerance: f32) bool {
    return left.player_position.approxEqAbs(right.player_position, tolerance) and
        left.player_velocity.approxEqAbs(right.player_velocity, tolerance) and
        left.player_grounded == right.player_grounded and left.player_support == right.player_support and
        left.player_facing == right.player_facing and left.player_animation == right.player_animation and
        @abs(left.player_animation_time - right.player_animation_time) <= tolerance and
        left.partner_animation == right.partner_animation and
        @abs(left.partner_animation_time - right.partner_animation_time) <= tolerance and
        @abs(left.player_landing_offset - right.player_landing_offset) <= tolerance and
        @abs(left.player_secondary_offset - right.player_secondary_offset) <= tolerance and
        optionalVecEqual(left.left_locked_target, right.left_locked_target, tolerance) and
        optionalVecEqual(left.right_locked_target, right.right_locked_target, tolerance) and
        left.active_interactions == right.active_interactions and left.participant_locks == right.participant_locks and
        left.active_overrides == right.active_overrides and left.active_arm_constraints == right.active_arm_constraints;
}

fn diagnosticsFrom(snapshot: input.FrameInputSnapshot, substeps: u8, pending_edge_count: u8) InputDiagnostics {
    return .{
        .keyboard_left_held = snapshot.keyboard_left_held,
        .keyboard_right_held = snapshot.keyboard_right_held,
        .jump_pressed = snapshot.jump.pressed,
        .jump_held = snapshot.jump.held,
        .jump_released = snapshot.jump.released,
        .interact_pressed = snapshot.interact.pressed,
        .reset_pressed = snapshot.reset.pressed,
        .debug_toggle_pressed = snapshot.debug_toggle.pressed,
        .merged_move_axis = snapshot.move_axis,
        .substeps_this_frame = substeps,
        .pending_edge_count = pending_edge_count,
    };
}

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

fn optionalVecEqual(left: ?math.Vec2, right: ?math.Vec2, tolerance: f32) bool {
    if (left == null or right == null) return left == null and right == null;
    return left.?.approxEqAbs(right.?, tolerance);
}

pub const ScriptPhase = enum(u8) {
    idle,
    move_left,
    decelerate_left,
    move_right,
    decelerate_right,
    opposing,
    short_jump_press,
    short_jump_airborne,
    held_jump_press,
    held_jump_airborne,
    debug_on,
    debug_release,
    debug_off,
    approach,
    interact_press,
    interact_hold,
    interact_release,
    reset_press,
    reset_hold,
    final_idle,
};

pub const ScriptMilestones = packed struct(u16) {
    idle: bool = false,
    left: bool = false,
    deceleration: bool = false,
    right: bool = false,
    opposing_neutral: bool = false,
    short_jump: bool = false,
    held_jump: bool = false,
    landed: bool = false,
    debug_on: bool = false,
    debug_off: bool = false,
    approached: bool = false,
    interaction: bool = false,
    reset: bool = false,
    stable: bool = false,
    reserved_14: bool = false,
    reserved_15: bool = false,
};

pub const ScriptedInput = struct {
    phase: ScriptPhase = .idle,
    phase_frame: u32 = 0,
    milestones: ScriptMilestones = .{},
    phase_start_x: f32 = player_spawn.x,
    left_displacement: f32 = 0,
    right_displacement: f32 = 0,
    opposing_displacement: f32 = 0,
    opposing_start_x: f32 = 0,
    short_jump_apex: f32 = player_spawn.y,
    held_jump_apex: f32 = player_spawn.y,
    completion_hold_frames: u32 = 0,

    pub fn nextRaw(script: *ScriptedInput, scene: *Scene) input.RawInputState {
        var raw = input.RawInputState{};
        const controller = scene.player.controllerSnapshot().?.state;
        switch (script.phase) {
            .idle => {},
            .move_left => raw.keyboard.a = true,
            .decelerate_left => {},
            .move_right => raw.keyboard.right_arrow = true,
            .decelerate_right => {},
            .opposing => {
                raw.keyboard.left_arrow = true;
                raw.keyboard.d = true;
            },
            .short_jump_press => raw.keyboard.space = script.phase_frame < 3,
            .short_jump_airborne => {},
            .held_jump_press => raw.keyboard.space = controller.velocity.y > 0 or controller.grounded,
            .held_jump_airborne => {},
            .debug_on, .debug_off => raw.keyboard.f1 = true,
            .debug_release => {},
            .approach => {
                const target = handshake_player_x - 0.01;
                const command = std.math.clamp((target - controller.position.x) * 0.5 - controller.velocity.x * 0.8, 0, 0.15);
                raw.gamepad_left_x = encodeGamepadAxis(command);
            },
            .interact_press, .interact_hold => raw.keyboard.e = true,
            .interact_release => {},
            .reset_press, .reset_hold => raw.keyboard.r = true,
            .final_idle => {},
        }
        return raw;
    }

    pub fn observe(script: *ScriptedInput, scene: *Scene) !void {
        const controller = scene.player.controllerSnapshot().?.state;
        script.phase_frame += 1;
        switch (script.phase) {
            .idle => if (script.phase_frame >= 30) {
                script.milestones.idle = true;
                script.transition(.move_left, controller.position.x);
            },
            .move_left => if (script.phase_frame >= 12) {
                script.left_displacement = controller.position.x - script.phase_start_x;
                script.milestones.left = script.left_displacement < -0.05;
                script.transition(.decelerate_left, controller.position.x);
            },
            .decelerate_left => if (script.phase_frame >= 10 and @abs(controller.velocity.x) < 0.01) {
                script.milestones.deceleration = true;
                script.transition(.move_right, controller.position.x);
            },
            .move_right => if (script.phase_frame >= 10) {
                script.right_displacement = controller.position.x - script.phase_start_x;
                script.milestones.right = script.right_displacement > 0.05;
                script.transition(.decelerate_right, controller.position.x);
            },
            .decelerate_right => if (script.phase_frame >= 10 and @abs(controller.velocity.x) < 0.01) {
                script.opposing_start_x = controller.position.x;
                script.transition(.opposing, controller.position.x);
            },
            .opposing => if (script.phase_frame >= 20) {
                script.opposing_displacement = controller.position.x - script.opposing_start_x;
                script.milestones.opposing_neutral = @abs(script.opposing_displacement) <= 0.0001;
                script.transition(.short_jump_press, controller.position.x);
            },
            .short_jump_press => {
                script.short_jump_apex = @max(script.short_jump_apex, controller.position.y);
                if (script.phase_frame >= 4) script.transition(.short_jump_airborne, controller.position.x);
            },
            .short_jump_airborne => {
                script.short_jump_apex = @max(script.short_jump_apex, controller.position.y);
                if (script.phase_frame > 5 and controller.grounded) {
                    script.milestones.short_jump = script.short_jump_apex > player_spawn.y + 0.1;
                    script.milestones.landed = true;
                    script.transition(.held_jump_press, controller.position.x);
                }
            },
            .held_jump_press => {
                script.held_jump_apex = @max(script.held_jump_apex, controller.position.y);
                if (!controller.grounded and controller.velocity.y <= 0) script.transition(.held_jump_airborne, controller.position.x);
            },
            .held_jump_airborne => {
                script.held_jump_apex = @max(script.held_jump_apex, controller.position.y);
                if (script.phase_frame > 5 and controller.grounded) {
                    script.milestones.held_jump = script.held_jump_apex > script.short_jump_apex + 0.05;
                    script.transition(.debug_on, controller.position.x);
                }
            },
            .debug_on => if (script.phase_frame >= 1) {
                script.milestones.debug_on = scene.debug_visualization;
                script.transition(.debug_release, controller.position.x);
            },
            .debug_release => if (script.phase_frame >= 3) script.transition(.debug_off, controller.position.x),
            .debug_off => if (script.phase_frame >= 1) {
                script.milestones.debug_off = !scene.debug_visualization;
                script.transition(.approach, controller.position.x);
            },
            .approach => if (scene.interactionEligibility().isEligible() and @abs(controller.velocity.x) < 0.035) {
                script.milestones.approached = true;
                script.transition(.interact_press, controller.position.x);
            },
            .interact_press => if (scene.evidence.successful_interactions == 1) script.transition(.interact_hold, controller.position.x),
            .interact_hold => {
                if (scene.evidence.completion_events == 1) script.completion_hold_frames += 1;
                if (script.completion_hold_frames >= 60) {
                    script.milestones.interaction = scene.evidence.successful_interactions == 1 and scene.evidence.held_interaction_restarts == 0;
                    script.transition(.interact_release, controller.position.x);
                }
            },
            .interact_release => if (script.phase_frame >= 5) script.transition(.reset_press, controller.position.x),
            .reset_press => if (scene.evidence.reset_press_count == 1) script.transition(.reset_hold, controller.position.x),
            .reset_hold => if (script.phase_frame >= 10) {
                const state = scene.authoritativeState();
                script.milestones.reset = state.player_position.approxEqAbs(player_spawn, 0.000001) and
                    state.player_velocity.approxEqAbs(math.Vec2.zero, 0.000001) and state.player_grounded and
                    state.active_interactions == 0 and state.participant_locks == 0 and state.active_overrides == 0 and
                    state.active_arm_constraints == 0 and state.left_locked_target == null and state.right_locked_target == null;
                script.transition(.final_idle, controller.position.x);
            },
            .final_idle => {
                if (script.phase_frame >= 60) script.milestones.stable = true;
            },
        }
    }

    pub fn completed(script: *const ScriptedInput) bool {
        const bits: u16 = @bitCast(script.milestones);
        return (bits & 0x3fff) == 0x3fff;
    }

    pub fn validate(script: *const ScriptedInput, scene: *const Scene) !void {
        if (!script.completed()) {
            std.log.err("playground script incomplete phase={s} phase_frame={d} milestones={any} position=({d:.6},{d:.6}) velocity=({d:.6},{d:.6}) short_apex={d:.6} held_apex={d:.6}", .{
                @tagName(script.phase),
                script.phase_frame,
                script.milestones,
                scene.player.controllerSnapshot().?.state.position.x,
                scene.player.controllerSnapshot().?.state.position.y,
                scene.player.controllerSnapshot().?.state.velocity.x,
                scene.player.controllerSnapshot().?.state.velocity.y,
                script.short_jump_apex,
                script.held_jump_apex,
            });
            return error.PlaygroundScriptMilestoneMissing;
        }
        if (script.held_jump_apex <= script.short_jump_apex + 0.05) return error.PlaygroundJumpApexOrderingInvalid;
        if (scene.evidence.interaction_requests != 1 or scene.evidence.successful_interactions != 1 or
            scene.evidence.contact_events != 1 or scene.evidence.release_events != 1 or scene.evidence.completion_events != 1 or
            scene.evidence.held_interaction_restarts != 0 or scene.evidence.reset_press_count != 1 or
            scene.evidence.debug_toggle_count != 2)
        {
            std.log.err("playground evidence invalid requests={d} successful={d} rejected={d} held_restarts={d} contact={d} release={d} complete={d} reset={d} debug={d} jump_press={d} jump_release={d}", .{
                scene.evidence.interaction_requests,
                scene.evidence.successful_interactions,
                scene.evidence.rejected_interactions,
                scene.evidence.held_interaction_restarts,
                scene.evidence.contact_events,
                scene.evidence.release_events,
                scene.evidence.completion_events,
                scene.evidence.reset_press_count,
                scene.evidence.debug_toggle_count,
                scene.evidence.jump_press_count,
                scene.evidence.jump_release_count,
            });
            return error.PlaygroundEvidenceInvalid;
        }
        const final = scene.authoritativeState();
        if (!final.player_position.approxEqAbs(player_spawn, 0.000001) or
            !final.player_velocity.approxEqAbs(math.Vec2.zero, 0.000001) or !final.player_grounded or
            final.active_interactions != 0 or final.participant_locks != 0 or final.active_overrides != 0 or
            final.active_arm_constraints != 0)
        {
            return error.PlaygroundFinalStateInvalid;
        }
    }

    fn transition(script: *ScriptedInput, next: ScriptPhase, position_x: f32) void {
        script.phase = next;
        script.phase_frame = 0;
        script.phase_start_x = position_x;
    }
};

pub const SideScrollerScriptedInput = struct {
    frame: u32 = 0,
    reached_destination: bool = false,
    maximum_player_x: f32 = player_spawn.x,
    minimum_player_x: f32 = player_spawn.x,
    idle_frames: u32 = 0,

    pub fn nextRaw(script: *SideScrollerScriptedInput, _: *const Scene) input.RawInputState {
        var raw = input.RawInputState{};
        if (!script.reached_destination) raw.keyboard.a = true;
        return raw;
    }

    pub fn observe(script: *SideScrollerScriptedInput, scene: *const Scene) void {
        const state = scene.player.controllerSnapshot().?.state;
        script.frame += 1;
        script.maximum_player_x = @max(script.maximum_player_x, state.position.x);
        script.minimum_player_x = @min(script.minimum_player_x, state.position.x);
        if (!script.reached_destination and state.position.x <= -24) script.reached_destination = true;
        if (script.reached_destination and @abs(state.velocity.x) < 0.01) script.idle_frames += 1;
    }

    pub fn validate(script: SideScrollerScriptedInput, scene: *const Scene) !void {
        if (!script.reached_destination or script.minimum_player_x > -24 or
            script.maximum_player_x - script.minimum_player_x < 20 or script.idle_frames < 30)
        {
            std.log.err("side-scroller route incomplete frame={d} min_x={d:.5} max_x={d:.5} final_x={d:.5} velocity_x={d:.5} idle_frames={d}", .{
                script.frame,
                script.minimum_player_x,
                script.maximum_player_x,
                scene.player.controllerSnapshot().?.state.position.x,
                scene.player.controllerSnapshot().?.state.velocity.x,
                script.idle_frames,
            });
            return error.SideScrollerTravelMissing;
        }
    }
};

fn encodeGamepadAxis(desired_axis: f32) f32 {
    if (@abs(desired_axis) <= std.math.floatEps(f32)) return 0;
    return std.math.sign(desired_axis) * (input.gamepad_dead_zone + @abs(desired_axis) * (1 - input.gamepad_dead_zone));
}

comptime {
    if (required_frames * (fixed_step.simulation_hz / 60) < 3600) @compileError("playground verification route is too short");
    if (side_scroller_required_frames * (fixed_step.simulation_hz / 60) < 3600) {
        @compileError("side-scroller verification route is too short");
    }
}
