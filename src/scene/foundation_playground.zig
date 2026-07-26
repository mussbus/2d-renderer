const std = @import("std");
const math = @import("math");
const input = @import("input");
const fixed_step = @import("fixed_step");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const deformation = @import("deformation");
const attachment_secondary_motion = @import("attachment_secondary_motion");
const anatomy = @import("anatomy");
const equipment = @import("equipment");
const mesh = @import("deformable_mesh");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const foot_planting = @import("foot_planting");
const render_queue = @import("render_queue");
const camera2d = @import("camera2d");
const debug_draw = @import("debug_draw");
const modular_body = @import("modular_body_demo");
const mesh_attachment_demo = @import("mesh_attachment_demo");

pub const required_frames: u32 = 1800;
pub const character_count: usize = 3;
pub const mesh_definition_count: usize = 3;
pub const player_spawn = math.Vec2{ .x = -3.15, .y = 1.05 };
pub const partner_spawn = math.Vec2{ .x = -1.40, .y = 1.05 };
pub const showcase_spawn = math.Vec2{ .x = 14.0, .y = 1.05 };
pub const handshake_player_x: f32 = partner_spawn.x - handshake.authored_horizontal_separation;
pub const world_min_x: f32 = -36;
pub const world_max_x: f32 = 36;
pub const distant_camera_x_factor: f32 = 0.12;
pub const midground_camera_x_factor: f32 = 0.46;
pub const loadout_count: u8 = 3;

pub const TimeMode = enum(u8) {
    normal,
    quarter_speed,
    paused,
};

const cape_secondary_motion = attachment_secondary_motion.Definition{
    .dynamic_point_count = 4,
    .rest_offsets = .{
        .{ .x = -0.12, .y = -0.30 },
        .{ .x = -0.22, .y = -0.62 },
        .{ .x = -0.30, .y = -0.94 },
        .{ .x = -0.34, .y = -1.22 },
    },
    .spring_configuration = .{
        .stiffness = 86,
        .damping = 15,
        .maximum_displacement = 0.42,
        .maximum_velocity = 5.5,
    },
    .gravity_displacement = .{ .x = 0, .y = -0.075 },
    .acceleration_response = .{ .x = 0.010, .y = 0.007 },
    .velocity_response = .{ .x = 0.030, .y = 0.016 },
    .chain_follow = 0.46,
    .landing_impulse_scale = 0.055,
    .output_translation_scale = 0.38,
    .maximum_rotation_radians = 0.62,
};

const sleeve_secondary_motion = attachment_secondary_motion.Definition{
    .dynamic_point_count = 2,
    .rest_offsets = .{
        .{ .x = 0.32, .y = -0.02 },
        .{ .x = 0.66, .y = -0.04 },
        math.Vec2.zero,
        math.Vec2.zero,
    },
    .spring_configuration = .{
        .stiffness = 150,
        .damping = 24,
        .maximum_displacement = 0.12,
        .maximum_velocity = 2.8,
    },
    .gravity_displacement = .{ .x = 0, .y = -0.018 },
    .acceleration_response = .{ .x = 0.003, .y = 0.002 },
    .velocity_response = .{ .x = 0.008, .y = 0.005 },
    .chain_follow = 0.22,
    .landing_impulse_scale = 0.012,
    .output_translation_scale = 0.22,
    .maximum_rotation_radians = 0.18,
};

pub const Evidence = struct {
    input_frames: u64 = 0,
    simulation_ticks: u64 = 0,
    camera_min_x: f32 = camera2d.default_center.x,
    camera_max_x: f32 = camera2d.default_center.x,
    camera_follow_observed: bool = false,
    parallax_observed: bool = false,
    resize_events: u32 = 0,
    resize_invariance_observed: bool = false,
    body_changes: u32 = 0,
    build_changes: u32 = 0,
    hair_changes: u32 = 0,
    loadout_changes: u32 = 0,
    topology_rebinds: u32 = 0,
    loadout_restoration_observed: bool = false,
    default_loadout_fingerprint: u64 = 0,
    default_property_fingerprint: u64 = 0,
    default_appearance_fingerprint: u64 = 0,
    maximum_resolved_visuals: u16 = 0,
    conventional_sleeves: u16 = 0,
    nonstandard_sleeves: u16 = 0,
    breathing_minimum: f32 = 1,
    breathing_maximum: f32 = -1,
    maximum_secondary_displacement: f32 = 0,
    speed_attribute: f32 = 0,
    maximum_observed_ground_speed: f32 = 0,
    baseline_jump_velocity: f32 = 0,
    modified_jump_velocity: f32 = 0,
    double_jump_observed: bool = false,
    dash_observed: bool = false,
    dash_distance: f32 = 0,
    carrying_capacity: f32 = 0,
    armor: f32 = 0,
    damage_reduction: f32 = 0,
    landing_observed: bool = false,
    interaction_requests: u32 = 0,
    successful_interactions: u32 = 0,
    contact_events: u32 = 0,
    release_events: u32 = 0,
    completion_events: u32 = 0,
    handshake_root_invariance: bool = true,
    reset_observed: bool = false,
    reset_cleared_mesh_state: bool = false,
    reset_restored_appearance: bool = false,
    stable_final_state: bool = false,
    ordinary_sprites: u32 = 0,
    mesh_instances: u32 = 0,
    debug_primitives: u32 = 0,
};

pub const GameplayState = struct {
    position: math.Vec2,
    velocity: math.Vec2,
    grounded: bool,
    support: ?collider.ColliderId,
    facing: humanoid.Facing,
    air_jumps_used: u8,
    dash_ticks_remaining: u16,
    dash_cooldown_ticks_remaining: u16,
    active_interactions: usize,
    participant_locks: usize,
    active_overrides: usize,
    active_arm_constraints: usize,
    loadout_fingerprint: u64,
    property_fingerprint: u64,
    appearance_fingerprint: u64,
    resolved_visual_count: u16,
    selected_body_preset: anatomy.BodyPresetId,
    selected_hair: ?anatomy.HairDefinitionId,
    global_build_normalized: f32,
};

pub const Scene = struct {
    definition: humanoid.HumanoidDefinition,
    fitted_mesh: mesh.Definition,
    sleeve_mesh: mesh.Definition,
    cape_mesh: mesh.Definition,
    equipment_definition: equipment.Definition,
    animations: authored.Definitions,
    world: collision_world.CollisionWorld,
    player: character.CharacterInstance,
    partner: character.CharacterInstance,
    showcase: character.CharacterInstance,
    manager: interaction_system.Manager,
    clock: fixed_step.Clock,
    pending_input: input.PendingInput = .{},
    camera: camera2d.Camera2D = camera2d.Camera2D.initDefault(),
    camera_follower: camera2d.HorizontalFollower,
    debug_visualization: bool = false,
    time_mode: TimeMode = .normal,
    simulation_tick: u64 = 0,
    render_frame: u64 = 0,
    body_index: u8 = 0,
    build_index: u8 = 0,
    hair_index: u8 = 0,
    loadout_index: u8 = 0,
    active_interaction: interaction_system.InteractionId = .invalid,
    observed_interaction: interaction_system.InteractionId = .invalid,
    observed_event_counts: [interaction.event_count]u8 = [_]u8{0} ** interaction.event_count,
    last_terminal_id: interaction_system.InteractionId = .invalid,
    handshake_player_root: ?math.Vec2 = null,
    handshake_partner_root: ?math.Vec2 = null,
    dash_start_x: ?f32 = null,
    evidence: Evidence = .{},
    debug_commands: debug_draw.CommandBuffer = .{},

    pub fn init(allocator: std.mem.Allocator, debug_visualization: bool) !Scene {
        var definition = try modular_body.initDefinition(allocator);
        errdefer definition.deinit();
        var fitted_mesh = try mesh_attachment_demo.initFittedGarmentMesh(allocator);
        errdefer fitted_mesh.deinit();
        var sleeve_mesh = try mesh_attachment_demo.initSleeveMesh(allocator);
        errdefer sleeve_mesh.deinit();
        var cape_mesh = try mesh_attachment_demo.initCapeMesh(allocator);
        errdefer cape_mesh.deinit();
        var equipment_definition = try initEquipmentDefinition(
            allocator,
            &definition,
            fitted_mesh.view(),
            sleeve_mesh.view(),
            cape_mesh.view(),
        );
        errdefer equipment_definition.deinit();
        var animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer animations.deinit();
        const colliders = worldColliderInputs();
        var world = try collision_world.CollisionWorld.init(allocator, &colliders, null);
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
        var showcase = try character.CharacterInstance.init(
            allocator,
            try character.entityIdFromRaw(3),
            &definition,
            &animations,
            showcase_spawn,
            .left,
            2,
            null,
        );
        errdefer showcase.deinit();

        try player.initializeEquipment(equipment_definition.view());
        try partner.initializeEquipment(equipment_definition.view());
        try showcase.initializeEquipment(equipment_definition.view());

        var scene = Scene{
            .definition = definition,
            .fitted_mesh = fitted_mesh,
            .sleeve_mesh = sleeve_mesh,
            .cape_mesh = cape_mesh,
            .equipment_definition = equipment_definition,
            .animations = animations,
            .world = world,
            .player = player,
            .partner = partner,
            .showcase = showcase,
            .manager = interaction_system.Manager.initWithIk(try handshake.definition(&animations)),
            .clock = try fixed_step.Clock.init(.{}),
            .camera_follower = try camera2d.HorizontalFollower.init(3.25),
            .debug_visualization = debug_visualization,
        };
        try scene.configureInitialAppearance();
        scene.evidence.default_loadout_fingerprint = loadoutFingerprint(&scene.player);
        scene.evidence.default_property_fingerprint = propertyFingerprint(&scene.player);
        scene.evidence.default_appearance_fingerprint = appearanceFingerprint(&scene.player);
        scene.evidence.conventional_sleeves = try scene.countComponentVisuals(&scene.player, "topology_sleeve_mesh");
        scene.evidence.nonstandard_sleeves = try scene.countComponentVisuals(&scene.showcase, "topology_sleeve_mesh");
        if (scene.evidence.conventional_sleeves != 2 or scene.evidence.nonstandard_sleeves != 4) {
            return error.FoundationTopologyEvidenceMissing;
        }
        try scene.observeResolvedProperties();
        try scene.observeVisualState();
        return scene;
    }

    pub fn deinit(scene: *Scene) void {
        scene.showcase.deinit();
        scene.partner.deinit();
        scene.player.deinit();
        scene.world.deinit();
        scene.animations.deinit();
        scene.equipment_definition.deinit();
        scene.cape_mesh.deinit();
        scene.sleeve_mesh.deinit();
        scene.fitted_mesh.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn meshDefinitions(scene: *const Scene) [mesh_definition_count]mesh.DefinitionView {
        return .{
            scene.fitted_mesh.view(),
            scene.sleeve_mesh.view(),
            scene.cape_mesh.view(),
        };
    }

    pub fn updateFrame(scene: *Scene, frame_delta: f64, snapshot: input.FrameInputSnapshot) !void {
        scene.evidence.input_frames = std.math.add(u64, scene.evidence.input_frames, 1) catch return error.InputFrameOverflow;
        if (snapshot.reset.pressed) {
            try scene.resetWorld();
            scene.evidence.reset_observed = true;
            scene.render_frame = std.math.add(u64, scene.render_frame, 1) catch return error.RenderFrameOverflow;
            return;
        }
        if (snapshot.debug_toggle.pressed) scene.debug_visualization = !scene.debug_visualization;
        if (snapshot.time_mode_cycle.pressed) {
            scene.time_mode = switch (scene.time_mode) {
                .normal => .quarter_speed,
                .quarter_speed => .paused,
                .paused => .normal,
            };
            scene.clock.setPaused(scene.time_mode == .paused);
            scene.pending_input.reset();
        }
        if (snapshot.single_step.pressed) scene.clock.requestSingleStep();
        if (snapshot.body_preset_cycle.pressed) try scene.cycleBodyPreset();
        if (snapshot.build_cycle.pressed) try scene.cycleBuild();
        if (snapshot.hair_cycle.pressed) try scene.cycleHair();
        if (snapshot.loadout_cycle.pressed) try scene.cycleLoadout();

        if (scene.clock.paused and !snapshot.single_step.pressed) {
            scene.pending_input.reset();
        } else {
            try scene.pending_input.acceptFrame(snapshot);
        }
        const scaled_delta = if (scene.time_mode == .quarter_speed) frame_delta * 0.25 else frame_delta;
        const frame = try scene.clock.beginFrame(scaled_delta);
        for (0..frame.substeps) |_| try scene.updateTick();
        try scene.camera_follower.update(&scene.camera, scene.player.world_position.x);
        scene.evidence.camera_min_x = @min(scene.evidence.camera_min_x, scene.camera.center.x);
        scene.evidence.camera_max_x = @max(scene.evidence.camera_max_x, scene.camera.center.x);
        const camera_displacement = scene.evidence.camera_max_x - scene.evidence.camera_min_x;
        scene.evidence.camera_follow_observed = camera_displacement > 4;
        scene.evidence.parallax_observed = scene.evidence.camera_follow_observed and
            distant_camera_x_factor < midground_camera_x_factor and midground_camera_x_factor < 1;
        scene.render_frame = std.math.add(u64, scene.render_frame, 1) catch return error.RenderFrameOverflow;
    }

    fn updateTick(scene: *Scene) !void {
        scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch return error.SimulationTickOverflow;
        scene.evidence.simulation_ticks += 1;
        const intent_value = scene.pending_input.consumeTick();
        const physics_result = try scene.player.stepController(&scene.world, intent_value);
        if (physics_result.jump_accepted) {
            if (physics_result.jump_source == .air) {
                scene.evidence.double_jump_observed = true;
            } else if (scene.loadout_index == 0 and scene.evidence.baseline_jump_velocity == 0) {
                scene.evidence.baseline_jump_velocity = scene.player.controller.?.state.velocity.y;
            } else if (scene.loadout_index == 1 and scene.evidence.modified_jump_velocity == 0) {
                scene.evidence.modified_jump_velocity = scene.player.controller.?.state.velocity.y;
            }
        }
        if (physics_result.dash_started) {
            scene.evidence.dash_observed = true;
            scene.dash_start_x = scene.player.world_position.x;
        }
        if (scene.dash_start_x) |start_x| {
            scene.evidence.dash_distance = @max(scene.evidence.dash_distance, @abs(scene.player.world_position.x - start_x));
            if (physics_result.dash_ended) scene.dash_start_x = null;
        }
        scene.evidence.landing_observed = scene.evidence.landing_observed or physics_result.landed;
        if (scene.player.controller.?.state.grounded and scene.loadout_index == 0 and !scene.evidence.dash_observed) {
            scene.evidence.maximum_observed_ground_speed = @max(
                scene.evidence.maximum_observed_ground_speed,
                @abs(scene.player.controller.?.state.velocity.x),
            );
        }

        if (!scene.player.isInteractionLocked()) {
            try scene.player.selectControllerAnimation(physics_result);
            try scene.player.advanceVisualTickWithFootPlanting(&scene.world, visualInput(&scene.player, physics_result));
        }
        if (!scene.partner.isInteractionLocked()) {
            try scene.partner.advanceVisualTickWithFootPlanting(&scene.world, .{ .physically_grounded = true });
        }
        try scene.showcase.advanceVisualTick(.{
            .horizontal_velocity = @sin(@as(f32, @floatFromInt(scene.simulation_tick)) * 0.018) * 3.0,
            .vertical_velocity = @sin(@as(f32, @floatFromInt(scene.simulation_tick)) * 0.011) * 1.4,
            .physically_grounded = true,
        });

        const participants_value = scene.participants();
        if (intent_value.interact_pressed) {
            scene.evidence.interaction_requests += 1;
            const requested = scene.manager.requestFromIntent(
                scene.player.id,
                intent_value,
                &participants_value,
                scene.simulation_tick,
            ) catch |err| switch (err) {
                error.NoEligibleInteractionCandidate => null,
                else => return err,
            };
            if (requested) |id| {
                scene.active_interaction = id;
                scene.observed_interaction = id;
                scene.observed_event_counts = [_]u8{0} ** interaction.event_count;
                scene.evidence.successful_interactions += 1;
                scene.handshake_player_root = scene.player.world_position;
                scene.handshake_partner_root = scene.partner.world_position;
            }
        }

        try scene.manager.updateTick(scene.simulation_tick, &participants_value);
        if (scene.manager.firstActiveInstance()) |active| {
            if (active.elapsed_ticks > 0) {
                try scene.player.maintainFootPlantingDuringInteraction(&scene.world);
                try scene.partner.maintainFootPlantingDuringInteraction(&scene.world);
            }
            scene.observeInteraction(active);
            if (scene.handshake_player_root) |player_root| {
                scene.evidence.handshake_root_invariance = scene.evidence.handshake_root_invariance and
                    scene.player.world_position.approxEqAbs(player_root, 0.000001) and
                    scene.partner.world_position.approxEqAbs(scene.handshake_partner_root.?, 0.000001);
            }
        } else if (scene.manager.last_terminal) |*terminal| {
            if (terminal.id != scene.last_terminal_id) {
                scene.observeInteraction(terminal);
                scene.last_terminal_id = terminal.id;
                scene.active_interaction = .invalid;
            }
        }
        try scene.observeResolvedProperties();
        try scene.observeVisualState();
    }

    pub fn applyViewport(scene: *Scene, width: u32, height: u32) !void {
        if (scene.camera.viewport_width == width and scene.camera.viewport_height == height) return;
        const before = scene.gameplayState();
        const pending_edges = scene.pending_input.pendingEdgeCount();
        try scene.camera.setViewport(width, height);
        const after = scene.gameplayState();
        if (!gameplayStatesEqual(before, after, 0) or pending_edges != scene.pending_input.pendingEdgeCount()) {
            return error.ResizeChangedAuthoritativeState;
        }
        scene.evidence.resize_events += 1;
        scene.evidence.resize_invariance_observed = true;
    }

    pub fn resetWorld(scene: *Scene) !void {
        const participants_value = scene.participants();
        try scene.manager.reset(&participants_value);
        try scene.player.resetControlled(&scene.world);
        try scene.partner.reset();
        try scene.showcase.reset();
        try scene.configureInitialAppearance();
        scene.pending_input.reset();
        scene.clock.reset();
        scene.simulation_tick = 0;
        scene.body_index = 0;
        scene.build_index = 0;
        scene.hair_index = 0;
        scene.loadout_index = 0;
        scene.time_mode = .normal;
        scene.active_interaction = .invalid;
        if (scene.manager.last_terminal) |terminal| {
            scene.observed_interaction = terminal.id;
            scene.observed_event_counts = terminal.event_counts;
            scene.last_terminal_id = terminal.id;
        } else {
            scene.observed_interaction = .invalid;
            scene.observed_event_counts = [_]u8{0} ** interaction.event_count;
            scene.last_terminal_id = .invalid;
        }
        scene.handshake_player_root = null;
        scene.handshake_partner_root = null;
        scene.dash_start_x = null;
        try scene.camera.setCenter(camera2d.default_center);
        scene.debug_commands.beginFrame();
        scene.evidence.reset_cleared_mesh_state = allMeshStatesCleared(&scene.player) and
            allSecondaryStatesCleared(&scene.player);
        scene.evidence.reset_restored_appearance =
            appearanceFingerprint(&scene.player) == scene.evidence.default_appearance_fingerprint;
    }

    pub fn interactionEligibility(scene: *Scene) interaction_system.Eligibility {
        const participants_value = scene.participants();
        return scene.manager.evaluateEligibility(scene.player.id, scene.partner.id, &participants_value);
    }

    pub fn gameplayState(scene: *const Scene) GameplayState {
        const controller = scene.player.controller.?.state;
        const runtime = scene.player.character.anatomy_runtime.?;
        const loadout = scene.player.equipment_loadout.?;
        return .{
            .position = controller.position,
            .velocity = controller.velocity,
            .grounded = controller.grounded,
            .support = controller.supporting_collider,
            .facing = scene.player.facing,
            .air_jumps_used = controller.air_jumps_used,
            .dash_ticks_remaining = controller.dash_ticks_remaining,
            .dash_cooldown_ticks_remaining = controller.dash_cooldown_ticks_remaining,
            .active_interactions = scene.manager.activeCount(),
            .participant_locks = @intFromBool(scene.player.isInteractionLocked()) +
                @intFromBool(scene.partner.isInteractionLocked()),
            .active_overrides = scene.manager.activeOwnedOverrideCount(),
            .active_arm_constraints = scene.manager.activeIkConstraintCount(),
            .loadout_fingerprint = loadoutFingerprint(&scene.player),
            .property_fingerprint = propertyFingerprint(&scene.player),
            .appearance_fingerprint = appearanceFingerprint(&scene.player),
            .resolved_visual_count = loadout.resolved_visual_count,
            .selected_body_preset = runtime.selected_body_preset,
            .selected_hair = runtime.selected_hair,
            .global_build_normalized = runtime.global_build_normalized,
        };
    }

    pub fn submit(scene: *Scene, queue: *render_queue.UnifiedRenderQueue) !u32 {
        var submitted = try submitCaveEnvironment(queue);
        for (scene.world.colliders) |static_collider| {
            const center = static_collider.bounds.center();
            const size = static_collider.bounds.size();
            _ = try queue.submitSprite(.{
                .world_position = center.toArray(),
                .rotation = 0,
                .scale = size.toArray(),
                .pivot = .{ 0.5, 0.5 },
                .uv_rect = .{ 0, 0.5, 0.5, 1 },
                .tint = .{ 0.23, 0.30, 0.40, 0.82 },
                .texture_page = 0,
                .order = .{
                    .scene_layer = character.SceneLayers.world,
                    .interaction_layer = 0,
                    .actor_layer = 0,
                    .body_part_layer = static_collider.id,
                },
            });
            submitted += 1;
        }
        submitted += try scene.player.submitUnified(queue);
        submitted += try scene.partner.submitUnified(queue);
        submitted += try scene.showcase.submitUnified(queue);
        scene.evidence.ordinary_sprites = queue.frame_metrics.submitted_sprites;
        scene.evidence.mesh_instances = queue.frame_metrics.submitted_meshes;
        if (scene.debug_visualization) {
            try scene.buildDebugCommands();
            const debug_count = try scene.debug_commands.submitUnified(queue);
            scene.evidence.debug_primitives = debug_count;
            submitted += debug_count;
        } else {
            scene.debug_commands.beginFrame();
            scene.evidence.debug_primitives = 0;
        }
        return submitted;
    }

    pub fn validateComplete(scene: *Scene, script: *const ScriptedInput) !void {
        if (!script.completed()) {
            std.log.err("foundation script incomplete phase={s} frame={d} milestones={any} position=({d:.5},{d:.5}) velocity=({d:.5},{d:.5})", .{
                @tagName(script.phase),
                script.phase_frame,
                script.milestones,
                scene.player.controller.?.state.position.x,
                scene.player.controller.?.state.position.y,
                scene.player.controller.?.state.velocity.x,
                scene.player.controller.?.state.velocity.y,
            });
            return error.FoundationScriptMilestoneMissing;
        }
        if (scene.evidence.input_frames != required_frames or
            !scene.evidence.camera_follow_observed or
            !scene.evidence.parallax_observed or
            !scene.evidence.resize_invariance_observed or
            scene.evidence.resize_events < 2 or
            scene.evidence.body_changes == 0 or
            scene.evidence.build_changes == 0 or
            scene.evidence.hair_changes == 0 or
            scene.evidence.loadout_changes < 3 or
            scene.evidence.topology_rebinds == 0 or
            !scene.evidence.loadout_restoration_observed or
            scene.evidence.conventional_sleeves != 2 or
            scene.evidence.nonstandard_sleeves != 4 or
            scene.evidence.breathing_maximum - scene.evidence.breathing_minimum < 0.35 or
            scene.evidence.maximum_secondary_displacement <= 0.001 or
            scene.evidence.speed_attribute <= 4.5 or
            scene.evidence.maximum_observed_ground_speed < scene.evidence.speed_attribute - 0.02 or
            scene.evidence.baseline_jump_velocity <= 0 or
            scene.evidence.modified_jump_velocity <= scene.evidence.baseline_jump_velocity + 0.5 or
            !scene.evidence.double_jump_observed or
            !scene.evidence.dash_observed or
            scene.evidence.dash_distance < 0.5 or
            scene.evidence.carrying_capacity <= 50 or
            scene.evidence.armor <= 0 or
            scene.evidence.damage_reduction <= 0 or
            !scene.evidence.landing_observed or
            scene.evidence.successful_interactions != 1 or
            scene.evidence.contact_events != 1 or
            scene.evidence.release_events != 1 or
            scene.evidence.completion_events != 1 or
            !scene.evidence.handshake_root_invariance or
            !scene.evidence.reset_observed or
            !scene.evidence.reset_cleared_mesh_state or
            !scene.evidence.reset_restored_appearance or
            !scene.evidence.stable_final_state)
        {
            std.log.err("foundation evidence incomplete: {any}", .{scene.evidence});
            return error.FoundationEvidenceIncomplete;
        }
        const final = scene.gameplayState();
        const resolved = scene.player.resolved_properties.?;
        try resolved.validate();
        if (!final.position.approxEqAbs(player_spawn, 0.000001) or
            !final.velocity.approxEqAbs(math.Vec2.zero, 0.000001) or
            !final.grounded or
            final.air_jumps_used != 0 or
            final.dash_ticks_remaining != 0 or
            final.dash_cooldown_ticks_remaining != 0 or
            final.active_interactions != 0 or
            final.participant_locks != 0 or
            final.active_overrides != 0 or
            final.active_arm_constraints != 0 or
            final.loadout_fingerprint != scene.evidence.default_loadout_fingerprint or
            final.property_fingerprint != scene.evidence.default_property_fingerprint or
            resolved.attribute_count != scene.equipment_definition.attributes.len or
            resolved.capability_count != scene.equipment_definition.capabilities.len or
            !scene.camera.center.approxEqAbs(camera2d.default_center, 0.000001))
        {
            return error.FoundationFinalStateInvalid;
        }
    }

    fn configureInitialAppearance(scene: *Scene) !void {
        const definition = scene.definition.anatomy_definition.?.view();
        try scene.player.selectBodyPreset(try definition.bodyPresetId("conventional_male"));
        try scene.partner.selectBodyPreset(try definition.bodyPresetId("conventional_female"));
        try scene.showcase.selectBodyPreset(try definition.bodyPresetId("nonstandard_humanoid"));
        try scene.player.setGlobalBuild(50);
        try scene.partner.setGlobalBuild(68);
        try scene.showcase.setGlobalBuild(82);
        try scene.player.setPartMorphologyOverride(
            try definition.partInstanceId("left_upper_arm"),
            try definition.morphologyChannelId("upper_arm_thickness"),
            82,
        );
        try scene.player.configureBreathing(try deformation.BreathingConfiguration.init(960, 0.75));
        try scene.partner.configureBreathing(try deformation.BreathingConfiguration.init(720, 0.62));
        try scene.showcase.configureBreathing(try deformation.BreathingConfiguration.init(1200, 0.88));
        try scene.partner.setBreathingPhaseTick(160);
        try scene.showcase.setBreathingPhaseTick(320);
    }

    fn cycleBodyPreset(scene: *Scene) !void {
        const definition = scene.definition.anatomy_definition.?.view();
        scene.body_index = (scene.body_index + 1) % 2;
        const preset = if (scene.body_index == 0) "conventional_male" else "conventional_female";
        try scene.player.selectBodyPreset(try definition.bodyPresetId(preset));
        scene.evidence.body_changes += 1;
        scene.evidence.topology_rebinds += 1;
    }

    fn cycleBuild(scene: *Scene) !void {
        const values = [_]f32{ 50, 78, 24 };
        scene.build_index = (scene.build_index + 1) % @as(u8, @intCast(values.len));
        try scene.player.setGlobalBuild(values[scene.build_index]);
        scene.evidence.build_changes += 1;
    }

    fn cycleHair(scene: *Scene) !void {
        const definition = scene.definition.anatomy_definition.?.view();
        const names = [_][]const u8{ "short_rigid", "long_rigid", "ponytail" };
        scene.hair_index = (scene.hair_index + 1) % @as(u8, @intCast(names.len));
        try scene.player.selectHair(try definition.hairDefinitionId(names[scene.hair_index]));
        scene.evidence.hair_changes += 1;
    }

    fn cycleLoadout(scene: *Scene) !void {
        scene.loadout_index = (scene.loadout_index + 1) % loadout_count;
        try scene.applyLoadout(scene.loadout_index);
        scene.evidence.loadout_changes += 1;
        if (scene.loadout_index == 0) {
            scene.evidence.loadout_restoration_observed =
                loadoutFingerprint(&scene.player) == scene.evidence.default_loadout_fingerprint;
        }
    }

    fn applyLoadout(scene: *Scene, index: u8) !void {
        const definition = scene.equipment_definition.view();
        switch (index) {
            0 => {
                try replaceIfNeeded(&scene.player, try definition.itemId("speed_boots"));
                try restoreIndependentArmor(&scene.player, definition);
            },
            1 => {
                try replaceIfNeeded(&scene.player, try definition.itemId("spring_boots"));
                try replaceIfNeeded(&scene.player, try definition.itemId("full_plate_armor"));
            },
            2 => {
                try replaceIfNeeded(&scene.player, try definition.itemId("winged_boots"));
                try restoreIndependentArmor(&scene.player, definition);
            },
            else => return error.InvalidFoundationLoadout,
        }
    }

    fn observeResolvedProperties(scene: *Scene) !void {
        const definition = scene.equipment_definition.view();
        scene.evidence.speed_attribute = @max(
            scene.evidence.speed_attribute,
            try scene.player.attributeValue(try definition.attributeId("movement_speed")),
        );
        scene.evidence.carrying_capacity = @max(
            scene.evidence.carrying_capacity,
            try scene.player.attributeValue(try definition.attributeId("carrying_capacity")),
        );
        scene.evidence.armor = @max(
            scene.evidence.armor,
            try scene.player.attributeValue(try definition.attributeId("armor")),
        );
        scene.evidence.damage_reduction = @max(
            scene.evidence.damage_reduction,
            try scene.player.attributeValue(try definition.attributeId("physical_damage_reduction")),
        );
    }

    fn observeVisualState(scene: *Scene) !void {
        const sample = try scene.player.breathingSample();
        scene.evidence.breathing_minimum = @min(scene.evidence.breathing_minimum, sample);
        scene.evidence.breathing_maximum = @max(scene.evidence.breathing_maximum, sample);
        const loadout = &scene.player.equipment_loadout.?;
        scene.evidence.maximum_resolved_visuals = @max(scene.evidence.maximum_resolved_visuals, loadout.resolved_visual_count);
        const cape_component = try scene.equipment_definition.visualComponentId("cape_mesh");
        for (loadout.visuals()) |visual| {
            const recipe = try loadout.definition.recipe(visual.recipe);
            if (recipe.component != cape_component) continue;
            for (visual.secondary.points) |point| {
                scene.evidence.maximum_secondary_displacement = @max(
                    scene.evidence.maximum_secondary_displacement,
                    point.displacement().length(),
                );
            }
        }
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

    fn countComponentVisuals(scene: *const Scene, instance: *const character.CharacterInstance, name: []const u8) !u16 {
        const component_id = try scene.equipment_definition.visualComponentId(name);
        var count: u16 = 0;
        for (instance.equipment_loadout.?.visuals()) |visual| {
            const recipe = try scene.equipment_definition.view().recipe(visual.recipe);
            if (recipe.component == component_id) count += 1;
        }
        return count;
    }

    fn buildDebugCommands(scene: *Scene) !void {
        scene.debug_commands.beginFrame();
        for (scene.world.colliders) |static_collider| {
            try scene.debug_commands.addAabb(static_collider.bounds, .{ 0.20, 0.80, 1.0, 0.72 });
        }
        for ([_]*const character.CharacterInstance{ &scene.player, &scene.partner, &scene.showcase }) |instance| {
            try scene.addCharacterDebug(instance);
        }
        if (scene.manager.firstActiveInstance()) |active| {
            if (active.ik.target_valid) try scene.debug_commands.addMarker(active.ik.shared_target, .{ 0.10, 1, 1, 1 });
        }
    }

    fn addCharacterDebug(scene: *Scene, instance: *const character.CharacterInstance) !void {
        try scene.debug_commands.addMarker(instance.world_position, .{ 1, 0.20, 0.20, 1 });
        const skeleton_definition = &instance.definition.skeleton_definition;
        for (skeleton_definition.bones, 0..) |bone, index| {
            const position = instance.character.local_and_world_pose.world_transforms[index].transformPoint(math.Vec2.zero);
            try scene.debug_commands.addMarker(position, .{ 1, 0.72, 0.16, 0.9 });
            if (bone.parent_index != std.math.maxInt(u16)) {
                const parent = instance.character.local_and_world_pose.world_transforms[bone.parent_index].transformPoint(math.Vec2.zero);
                try scene.debug_commands.addLine(parent, position, .{ 1, 0.56, 0.12, 0.86 });
            }
        }
        for (skeleton_definition.sockets) |socket_definition| {
            const world = instance.character.local_and_world_pose.world_transforms[socket_definition.parent_bone]
                .mul((socket_definition.local_to_bone.localToParent() catch return error.InvalidDebugSocketTransform));
            try scene.debug_commands.addMarker(world.transformPoint(math.Vec2.zero), .{ 0.20, 1, 0.85, 1 });
        }
        for ([_]*const foot_planting.FootRuntime{ &instance.foot_plants.left, &instance.foot_plants.right }) |foot| {
            if (foot.locked_target) |target| try scene.debug_commands.addMarker(target, .{ 1, 0.20, 1, 1 });
        }
    }

    fn participants(scene: *Scene) [2]*character.CharacterInstance {
        return .{ &scene.player, &scene.partner };
    }
};

pub const ScriptPhase = enum(u8) {
    idle,
    move_left,
    decelerate_left,
    move_right,
    decelerate_right,
    short_jump_press,
    short_jump_airborne,
    body_press,
    body_release,
    build_press,
    build_release,
    hair_press,
    hair_release,
    jump_loadout_press,
    jump_loadout_release,
    held_jump_press,
    held_jump_airborne,
    ability_loadout_press,
    ability_loadout_release,
    double_jump_first,
    double_jump_release,
    double_jump_second,
    double_jump_airborne,
    dash_press,
    dash_release,
    restore_loadout_press,
    restore_loadout_release,
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
    right: bool = false,
    camera: bool = false,
    short_jump: bool = false,
    appearance: bool = false,
    stronger_jump: bool = false,
    double_jump: bool = false,
    dash: bool = false,
    resize: bool = false,
    restoration: bool = false,
    approach: bool = false,
    interaction: bool = false,
    reset: bool = false,
    stable: bool = false,
    reserved: bool = false,
};

pub const ScriptedInput = struct {
    phase: ScriptPhase = .idle,
    phase_frame: u32 = 0,
    milestones: ScriptMilestones = .{},
    phase_start_x: f32 = player_spawn.x,
    minimum_x: f32 = player_spawn.x,
    maximum_x: f32 = player_spawn.x,
    short_jump_apex: f32 = player_spawn.y,
    modified_jump_apex: f32 = player_spawn.y,
    completion_hold_frames: u32 = 0,
    synthetic_resize_stage: u8 = 0,

    pub fn nextRaw(script: *ScriptedInput, scene: *const Scene) input.RawInputState {
        var raw = input.RawInputState{};
        const controller = scene.player.controller.?.state;
        switch (script.phase) {
            .idle,
            .decelerate_left,
            .decelerate_right,
            .short_jump_airborne,
            .body_release,
            .build_release,
            .hair_release,
            .jump_loadout_release,
            .held_jump_airborne,
            .ability_loadout_release,
            .double_jump_release,
            .double_jump_airborne,
            .dash_release,
            .restore_loadout_release,
            .interact_release,
            .reset_hold,
            .final_idle,
            => {},
            .move_left => raw.keyboard.a = true,
            .move_right => raw.keyboard.d = true,
            .short_jump_press => raw.keyboard.space = script.phase_frame < 3,
            .body_press => raw.keyboard.c = true,
            .build_press => raw.keyboard.v = true,
            .hair_press => raw.keyboard.h = true,
            .jump_loadout_press, .ability_loadout_press, .restore_loadout_press => raw.keyboard.l = true,
            .held_jump_press => raw.keyboard.space = controller.grounded or controller.velocity.y > 0,
            .double_jump_first, .double_jump_second => raw.keyboard.space = true,
            .dash_press => {
                raw.keyboard.d = true;
                raw.keyboard.left_shift = true;
            },
            .approach => {
                const error_value = handshake_player_x - controller.position.x;
                if (@abs(error_value) > 0.012) {
                    const command = std.math.clamp(error_value * 0.5 - controller.velocity.x * 0.8, -0.15, 0.15);
                    raw.gamepad_move_axis = encodeGamepadAxis(command);
                }
            },
            .interact_press, .interact_hold => raw.keyboard.e = true,
            .reset_press => raw.keyboard.r = true,
        }
        return raw;
    }

    pub fn observe(script: *ScriptedInput, scene: *Scene) !void {
        const controller = scene.player.controller.?.state;
        script.phase_frame += 1;
        script.minimum_x = @min(script.minimum_x, controller.position.x);
        script.maximum_x = @max(script.maximum_x, controller.position.x);
        switch (script.phase) {
            .idle => if (script.phase_frame >= 35) {
                script.milestones.idle = true;
                script.transition(.move_left, controller.position.x);
            },
            .move_left => if (controller.position.x <= -18 or script.phase_frame >= 260) {
                script.milestones.left = controller.position.x < player_spawn.x - 10;
                script.transition(.decelerate_left, controller.position.x);
            },
            .decelerate_left => if (script.phase_frame >= 20 and @abs(controller.velocity.x) < 0.02) {
                script.milestones.camera = scene.evidence.camera_follow_observed and scene.evidence.parallax_observed;
                script.transition(.move_right, controller.position.x);
            },
            .move_right => if (controller.position.x >= player_spawn.x - 0.1 or script.phase_frame >= 320) {
                script.milestones.right = controller.position.x - script.phase_start_x > 10;
                script.transition(.decelerate_right, controller.position.x);
            },
            .decelerate_right => if (script.phase_frame >= 20 and @abs(controller.velocity.x) < 0.02) {
                script.transition(.short_jump_press, controller.position.x);
            },
            .short_jump_press => {
                script.short_jump_apex = @max(script.short_jump_apex, controller.position.y);
                if (script.phase_frame >= 4) script.transition(.short_jump_airborne, controller.position.x);
            },
            .short_jump_airborne => {
                script.short_jump_apex = @max(script.short_jump_apex, controller.position.y);
                if (script.phase_frame > 6 and controller.grounded) {
                    script.milestones.short_jump = script.short_jump_apex > player_spawn.y + 0.2;
                    script.transition(.body_press, controller.position.x);
                }
            },
            .body_press => if (script.phase_frame >= 1) script.transition(.body_release, controller.position.x),
            .body_release => if (script.phase_frame >= 2) script.transition(.build_press, controller.position.x),
            .build_press => if (script.phase_frame >= 1) script.transition(.build_release, controller.position.x),
            .build_release => if (script.phase_frame >= 2) script.transition(.hair_press, controller.position.x),
            .hair_press => if (script.phase_frame >= 1) script.transition(.hair_release, controller.position.x),
            .hair_release => if (script.phase_frame >= 2) {
                script.milestones.appearance = scene.evidence.body_changes == 1 and
                    scene.evidence.build_changes == 1 and scene.evidence.hair_changes == 1;
                script.transition(.jump_loadout_press, controller.position.x);
            },
            .jump_loadout_press => if (script.phase_frame >= 1) script.transition(.jump_loadout_release, controller.position.x),
            .jump_loadout_release => if (script.phase_frame >= 3) script.transition(.held_jump_press, controller.position.x),
            .held_jump_press => {
                script.modified_jump_apex = @max(script.modified_jump_apex, controller.position.y);
                if (!controller.grounded and controller.velocity.y <= 0) script.transition(.held_jump_airborne, controller.position.x);
            },
            .held_jump_airborne => {
                script.modified_jump_apex = @max(script.modified_jump_apex, controller.position.y);
                if (script.phase_frame > 6 and controller.grounded) {
                    script.milestones.stronger_jump = scene.evidence.modified_jump_velocity >
                        scene.evidence.baseline_jump_velocity + 0.5;
                    script.transition(.ability_loadout_press, controller.position.x);
                }
            },
            .ability_loadout_press => if (script.phase_frame >= 1) script.transition(.ability_loadout_release, controller.position.x),
            .ability_loadout_release => if (script.phase_frame >= 3) script.transition(.double_jump_first, controller.position.x),
            .double_jump_first => if (script.phase_frame >= 1) script.transition(.double_jump_release, controller.position.x),
            .double_jump_release => if (script.phase_frame >= 7 and !controller.grounded) script.transition(.double_jump_second, controller.position.x),
            .double_jump_second => if (script.phase_frame >= 1) script.transition(.double_jump_airborne, controller.position.x),
            .double_jump_airborne => if (script.phase_frame > 8 and controller.grounded) {
                script.milestones.double_jump = scene.evidence.double_jump_observed;
                script.transition(.dash_press, controller.position.x);
            },
            .dash_press => {
                if (script.synthetic_resize_stage == 0 and script.phase_frame >= 1) {
                    try scene.applyViewport(960, 540);
                    script.synthetic_resize_stage = 1;
                } else if (script.synthetic_resize_stage == 1 and script.phase_frame >= 3) {
                    try scene.applyViewport(1280, 720);
                    script.synthetic_resize_stage = 2;
                }
                if (script.phase_frame >= 5) script.transition(.dash_release, controller.position.x);
            },
            .dash_release => if (script.phase_frame >= 30 and controller.dash_ticks_remaining == 0) {
                script.milestones.dash = scene.evidence.dash_observed and scene.evidence.dash_distance > 0.5;
                script.milestones.resize = scene.evidence.resize_invariance_observed and scene.evidence.resize_events == 2;
                script.transition(.restore_loadout_press, controller.position.x);
            },
            .restore_loadout_press => if (script.phase_frame >= 1) script.transition(.restore_loadout_release, controller.position.x),
            .restore_loadout_release => if (script.phase_frame >= 4) {
                script.milestones.restoration = scene.evidence.loadout_restoration_observed;
                script.transition(.approach, controller.position.x);
            },
            .approach => if (scene.interactionEligibility().isEligible() and @abs(controller.velocity.x) < 0.04) {
                script.milestones.approach = true;
                script.transition(.interact_press, controller.position.x);
            },
            .interact_press => if (scene.evidence.successful_interactions == 1) {
                script.transition(.interact_hold, controller.position.x);
            },
            .interact_hold => {
                if (scene.evidence.completion_events == 1) script.completion_hold_frames += 1;
                if (script.completion_hold_frames >= 30) {
                    script.milestones.interaction = scene.evidence.contact_events == 1 and
                        scene.evidence.release_events == 1 and scene.evidence.completion_events == 1;
                    script.transition(.interact_release, controller.position.x);
                }
            },
            .interact_release => if (script.phase_frame >= 4) script.transition(.reset_press, controller.position.x),
            .reset_press => if (scene.evidence.reset_observed) script.transition(.reset_hold, controller.position.x),
            .reset_hold => if (script.phase_frame >= 8) {
                const state = scene.gameplayState();
                script.milestones.reset = state.position.approxEqAbs(player_spawn, 0.000001) and
                    state.velocity.approxEqAbs(math.Vec2.zero, 0.000001) and state.grounded and
                    state.loadout_fingerprint == scene.evidence.default_loadout_fingerprint and
                    scene.evidence.reset_cleared_mesh_state;
                script.transition(.final_idle, controller.position.x);
            },
            .final_idle => if (script.phase_frame >= 60) {
                scene.evidence.stable_final_state = true;
                script.milestones.stable = true;
            },
        }
    }

    pub fn completed(script: *const ScriptedInput) bool {
        const bits: u16 = @bitCast(script.milestones);
        return (bits & 0x7fff) == 0x7fff;
    }

    fn transition(script: *ScriptedInput, next: ScriptPhase, position_x: f32) void {
        script.phase = next;
        script.phase_frame = 0;
        script.phase_start_x = position_x;
    }
};

pub fn gameplayStatesEqual(left: GameplayState, right: GameplayState, tolerance: f32) bool {
    return left.position.approxEqAbs(right.position, tolerance) and
        left.velocity.approxEqAbs(right.velocity, tolerance) and
        left.grounded == right.grounded and
        left.support == right.support and
        left.facing == right.facing and
        left.air_jumps_used == right.air_jumps_used and
        left.dash_ticks_remaining == right.dash_ticks_remaining and
        left.dash_cooldown_ticks_remaining == right.dash_cooldown_ticks_remaining and
        left.active_interactions == right.active_interactions and
        left.participant_locks == right.participant_locks and
        left.active_overrides == right.active_overrides and
        left.active_arm_constraints == right.active_arm_constraints and
        left.loadout_fingerprint == right.loadout_fingerprint and
        left.property_fingerprint == right.property_fingerprint and
        left.appearance_fingerprint == right.appearance_fingerprint and
        left.resolved_visual_count == right.resolved_visual_count and
        left.selected_body_preset == right.selected_body_preset and
        left.selected_hair == right.selected_hair and
        @abs(left.global_build_normalized - right.global_build_normalized) <= tolerance;
}

pub fn worldColliderInputs() [8]collider.StaticColliderInput {
    return .{
        staticCollider(1, world_min_x, -1, world_max_x, 0, true),
        staticCollider(2, world_max_x - 0.3, 0, world_max_x, 7, false),
        staticCollider(3, world_min_x, 0, world_min_x + 0.3, 7, false),
        staticCollider(4, 4.5, 0.75, 7.0, 1.0, true),
        staticCollider(5, 9.0, 1.45, 11.5, 1.70, true),
        staticCollider(6, 15.0, 0.85, 18.0, 1.10, true),
        staticCollider(7, 23.0, 1.75, 26.0, 2.0, true),
        staticCollider(8, -27.0, 1.15, -23.0, 1.40, true),
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

fn submitCaveEnvironment(queue: *render_queue.UnifiedRenderQueue) !u32 {
    const distant = [_]CaveQuad{
        .{ .position = .{ 0, 3.0 }, .size = .{ 108, 9 }, .tint = .{ 0.06, 0.08, 0.15, 1 } },
        .{ .position = .{ -28, 1.6 }, .size = .{ 6.0, 4.5 }, .tint = .{ 0.11, 0.15, 0.26, 0.94 } },
        .{ .position = .{ -14, 1.2 }, .size = .{ 4.0, 3.7 }, .tint = .{ 0.14, 0.17, 0.29, 0.92 } },
        .{ .position = .{ 0, 1.5 }, .size = .{ 5.0, 4.2 }, .tint = .{ 0.12, 0.16, 0.27, 0.93 } },
        .{ .position = .{ 14, 1.3 }, .size = .{ 4.4, 3.8 }, .tint = .{ 0.10, 0.14, 0.25, 0.94 } },
        .{ .position = .{ 28, 1.7 }, .size = .{ 6.2, 4.7 }, .tint = .{ 0.13, 0.16, 0.28, 0.92 } },
    };
    const midground = [_]CaveQuad{
        .{ .position = .{ -30, 1.4 }, .size = .{ 0.70, 4.6 }, .tint = .{ 0.20, 0.24, 0.34, 0.88 } },
        .{ .position = .{ -20, 1.0 }, .size = .{ 0.48, 3.5 }, .tint = .{ 0.25, 0.28, 0.39, 0.85 } },
        .{ .position = .{ -10, 1.6 }, .size = .{ 0.78, 4.8 }, .tint = .{ 0.18, 0.23, 0.35, 0.88 } },
        .{ .position = .{ 0, 1.1 }, .size = .{ 0.52, 3.6 }, .tint = .{ 0.24, 0.29, 0.40, 0.84 } },
        .{ .position = .{ 10, 1.5 }, .size = .{ 0.72, 4.4 }, .tint = .{ 0.20, 0.24, 0.36, 0.88 } },
        .{ .position = .{ 20, 1.2 }, .size = .{ 0.56, 3.9 }, .tint = .{ 0.24, 0.28, 0.39, 0.84 } },
        .{ .position = .{ 30, 1.7 }, .size = .{ 0.82, 4.9 }, .tint = .{ 0.18, 0.22, 0.34, 0.88 } },
    };
    var submitted: u32 = 0;
    for (distant, 0..) |quad, index| {
        try submitCaveQuad(queue, quad, character.SceneLayers.background, @intCast(index), distant_camera_x_factor);
        submitted += 1;
    }
    for (midground, 0..) |quad, index| {
        try submitCaveQuad(queue, quad, character.SceneLayers.midground, @intCast(index), midground_camera_x_factor);
        submitted += 1;
    }
    return submitted;
}

fn submitCaveQuad(
    queue: *render_queue.UnifiedRenderQueue,
    quad: CaveQuad,
    scene_layer: i16,
    body_part_layer: u16,
    camera_x_factor: f32,
) !void {
    _ = try queue.submitSprite(.{
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

fn visualInput(instance: *const character.CharacterInstance, physics: character_controller.StepResult) character.VisualTickInput {
    const controller = instance.controller.?;
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

fn loadoutFingerprint(instance: *const character.CharacterInstance) u64 {
    const loadout = instance.equipment_loadout orelse return 0;
    var hash = std.hash.Wyhash.init(0);
    for (loadout.equippedItems()) |item| hash.update(std.mem.asBytes(&item));
    for (loadout.visuals()) |visual| {
        hash.update(std.mem.asBytes(&visual.item));
        hash.update(std.mem.asBytes(&visual.recipe));
        const encoded = switch (visual.source) {
            .anatomy_part => |part| @as(u32, @intFromEnum(part)),
            .attachment_point => |point| 0x1_0000 + @as(u32, @intFromEnum(point)),
        };
        hash.update(std.mem.asBytes(&encoded));
    }
    return hash.final();
}

fn propertyFingerprint(instance: *const character.CharacterInstance) u64 {
    const resolved = instance.resolved_properties orelse return 0;
    var hash = std.hash.Wyhash.init(0);
    hash.update(std.mem.asBytes(&resolved.attribute_count));
    hash.update(std.mem.sliceAsBytes(resolved.attribute_values[0..resolved.attribute_count]));
    hash.update(std.mem.asBytes(&resolved.capability_count));
    hash.update(std.mem.sliceAsBytes(resolved.capability_source_counts[0..resolved.capability_count]));
    hash.update(std.mem.asBytes(&resolved.applied_modifier_count));
    hash.update(std.mem.asBytes(&resolved.active_grant_count));
    return hash.final();
}

fn appearanceFingerprint(instance: *const character.CharacterInstance) u64 {
    const runtime = instance.character.anatomy_runtime orelse return 0;
    var hash = std.hash.Wyhash.init(0);
    hash.update(std.mem.asBytes(&runtime.selected_body_preset));
    hash.update(std.mem.asBytes(&runtime.selected_morphology_preset));
    hash.update(std.mem.asBytes(&runtime.selected_presentation_profile));
    hash.update(std.mem.asBytes(&runtime.selected_hair));
    hash.update(std.mem.asBytes(&runtime.global_build_normalized));
    hash.update(std.mem.sliceAsBytes(runtime.channel_override_set));
    hash.update(std.mem.sliceAsBytes(runtime.channel_override_normalized));
    hash.update(std.mem.sliceAsBytes(runtime.instance_override_set));
    hash.update(std.mem.sliceAsBytes(runtime.instance_override_normalized));
    hash.update(std.mem.asBytes(&runtime.breathing.configuration));
    hash.update(std.mem.asBytes(&runtime.breathing.cycle_tick));
    return hash.final();
}

fn allMeshStatesCleared(instance: *const character.CharacterInstance) bool {
    const loadout = instance.equipment_loadout orelse return false;
    for (loadout.visuals()) |visual| {
        if (visual.mesh_state.owning_character != 0 or visual.mesh_state.update_serial != 0) return false;
    }
    return true;
}

fn allSecondaryStatesCleared(instance: *const character.CharacterInstance) bool {
    const loadout = instance.equipment_loadout orelse return false;
    for (loadout.visuals()) |visual| {
        if (visual.secondary.initialized or visual.secondary.fixed_ticks != 0) return false;
    }
    return true;
}

fn replaceIfNeeded(instance: *character.CharacterInstance, item_id: equipment.EquipmentItemId) !void {
    const loadout = instance.equipment_loadout orelse return error.CharacterEquipmentNotInitialized;
    if (!loadout.isEquipped(item_id)) try instance.replaceItem(item_id);
}

fn restoreIndependentArmor(instance: *character.CharacterInstance, definition: equipment.DefinitionView) !void {
    const full_plate = try definition.itemId("full_plate_armor");
    if (instance.equipment_loadout.?.isEquipped(full_plate)) try instance.unequipItem(full_plate);
    const left = try definition.itemId("left_shoulder_armor");
    const right = try definition.itemId("right_gauntlet");
    if (!instance.equipment_loadout.?.isEquipped(left)) try instance.equipItem(left);
    if (!instance.equipment_loadout.?.isEquipped(right)) try instance.equipItem(right);
}

fn encodeGamepadAxis(desired_axis: f32) f32 {
    if (@abs(desired_axis) <= std.math.floatEps(f32)) return 0;
    return std.math.sign(desired_axis) *
        (input.gamepad_dead_zone + @abs(desired_axis) * (1 - input.gamepad_dead_zone));
}

fn initEquipmentDefinition(
    allocator: std.mem.Allocator,
    humanoid_definition: *const humanoid.HumanoidDefinition,
    fitted: mesh.DefinitionView,
    sleeve: mesh.DefinitionView,
    cape: mesh.DefinitionView,
) !equipment.Definition {
    const anatomy_definition = humanoid_definition.anatomy_definition.?.view();
    const appearance_definition = humanoid_definition.visual_definition.view();
    const slots = [_]equipment.EquipmentSlotInput{
        .{ .stable_id = "tailored_outfit" },
        .{ .stable_id = "shoes" },
        .{ .stable_id = "torso_armor" },
        .{ .stable_id = "left_shoulder_armor" },
        .{ .stable_id = "right_gauntlet" },
        .{ .stable_id = "neck_accessory" },
        .{ .stable_id = "back" },
        .{ .stable_id = "pack" },
    };
    const roles = [_]equipment.AnatomyRoleInput{
        .{ .stable_id = "torso_role", .compatible_part_type = "torso" },
        .{ .stable_id = "upper_arm_role", .compatible_part_type = "upper_arm" },
        .{ .stable_id = "hand_role", .compatible_part_type = "hand" },
        .{ .stable_id = "foot_role", .compatible_part_type = "foot" },
    };
    const layers = [_]equipment.VisualLayerInput{
        .{ .stable_id = "cape_behind_body", .render_layer = 5 },
        .{ .stable_id = "sleeve_between_limbs", .render_layer = 23 },
        .{ .stable_id = "fitted_over_torso", .render_layer = 33 },
        .{ .stable_id = "armor", .render_layer = 72 },
        .{ .stable_id = "accessory", .render_layer = 78 },
    };
    const attributes = [_]equipment.AttributeDefinitionInput{
        .{ .stable_id = "armor", .base_value = 0, .minimum = 0, .maximum = 10_000 },
        .{ .stable_id = "physical_damage_reduction", .base_value = 0, .minimum = 0, .maximum = 0.95 },
        .{ .stable_id = "movement_speed", .base_value = 4.5, .minimum = 0.1, .maximum = 20 },
        .{ .stable_id = "jump_strength", .base_value = 9, .minimum = 3.51, .maximum = 30 },
        .{ .stable_id = "carrying_capacity", .base_value = 50, .minimum = 0, .maximum = 10_000 },
    };
    const capabilities = [_]equipment.CapabilityDefinitionInput{
        .{ .stable_id = "double_jump" },
        .{ .stable_id = "dash" },
    };
    const components = [_]equipment.VisualComponentInput{
        meshComponent("fitted_torso_mesh", fitted, .{ .morphology = 1, .breathing = 1 }, null),
        meshComponent("topology_sleeve_mesh", sleeve, .{ .morphology = 0.9, .breathing = 0.8 }, sleeve_secondary_motion),
        meshComponent("cape_mesh", cape, .{ .morphology = 0.65, .breathing = 0.6 }, cape_secondary_motion),
        rigidComponent("rigid_collar_clasp", .{ .x = 0.18, .y = 0.14 }, .{ 0.94, 0.72, 0.18, 1 }, .{ .morphology = 0.2, .breathing = 0.2 }),
        rigidComponent("boot", .{ .x = 0.46, .y = 0.30 }, .{ 0.22, 0.42, 0.16, 1 }, .{ .morphology = 0.25, .breathing = 0 }),
        rigidComponent("shoulder_plate", .{ .x = 0.30, .y = 0.28 }, .{ 0.62, 0.66, 0.72, 1 }, .{ .morphology = 0.15, .breathing = 0 }),
        rigidComponent("gauntlet", .{ .x = 0.30, .y = 0.24 }, .{ 0.58, 0.62, 0.70, 1 }, .{ .morphology = 0, .breathing = 0 }),
        rigidComponent("armor_torso", .{ .x = 1.02, .y = 1.16 }, .{ 0.46, 0.50, 0.58, 1 }, .{ .morphology = 0.1, .breathing = 0 }),
        rigidComponent("amulet_visual", .{ .x = 0.18, .y = 0.24 }, .{ 0.92, 0.72, 0.16, 1 }, .{ .morphology = 0, .breathing = 0 }),
        rigidComponent("backpack_visual", .{ .x = 0.72, .y = 0.92 }, .{ 0.28, 0.20, 0.12, 1 }, .{ .morphology = 0, .breathing = 0 }),
    };
    const items = [_]equipment.EquipmentItemInput{
        .{
            .stable_id = "tailored_mesh_set",
            .occupied_slots = &.{"tailored_outfit"},
            .visual_recipes = &.{
                firstRecipe("fitted_torso_mesh", "torso_role", "torso", "fitted_over_torso", torsoLocal()),
                everyRecipe("topology_sleeve_mesh", "upper_arm_role", 4, "left_arm", "sleeve_between_limbs", math.Transform2D.identity()),
                firstRecipe("rigid_collar_clasp", "torso_role", "torso", "accessory", math.Transform2D.init(.{ .x = 0, .y = 1.02 }, 0, math.Vec2.one)),
            },
            .covered_body_regions = &.{ "torso", "left_arm", "right_arm" },
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "upper_back_cape",
            .occupied_slots = &.{"back"},
            .visual_recipes = &.{firstRecipe("cape_mesh", "torso_role", "torso", "cape_behind_body", math.Transform2D.init(.{ .x = -0.08, .y = 0.58 }, 0, math.Vec2.one))},
            .covered_body_regions = &.{"torso"},
            .attribute_modifiers = &.{},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "left_shoulder_armor",
            .occupied_slots = &.{"left_shoulder_armor"},
            .visual_recipes = &.{specificRecipe("shoulder_plate", "upper_arm_role", "left_upper_arm", "left_arm", "armor")},
            .covered_body_regions = &.{"left_arm"},
            .attribute_modifiers = &.{.{ .attribute = "armor", .operation = .add, .amount = 4 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "right_gauntlet",
            .occupied_slots = &.{"right_gauntlet"},
            .visual_recipes = &.{specificRecipe("gauntlet", "hand_role", "right_hand", "right_hand", "armor")},
            .covered_body_regions = &.{"right_hand"},
            .attribute_modifiers = &.{.{ .attribute = "armor", .operation = .add, .amount = 2 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "full_plate_armor",
            .occupied_slots = &.{ "torso_armor", "left_shoulder_armor", "right_gauntlet" },
            .visual_recipes = &.{
                firstRecipe("armor_torso", "torso_role", "torso", "armor", torsoLocal()),
                specificRecipe("shoulder_plate", "upper_arm_role", "left_upper_arm", "left_arm", "armor"),
                specificRecipe("gauntlet", "hand_role", "right_hand", "right_hand", "armor"),
            },
            .covered_body_regions = &.{ "torso", "left_arm", "right_hand" },
            .attribute_modifiers = &.{
                .{ .attribute = "armor", .operation = .add, .amount = 25 },
                .{ .attribute = "physical_damage_reduction", .operation = .add, .amount = 0.20 },
                .{ .attribute = "movement_speed", .operation = .multiply, .amount = 0.90 },
            },
            .capability_grants = &.{},
        },
        .{
            .stable_id = "speed_boots",
            .occupied_slots = &.{"shoes"},
            .visual_recipes = &.{everyRecipe("boot", "foot_role", 2, "left_foot", "accessory", math.Transform2D.identity())},
            .covered_body_regions = &.{ "left_foot", "right_foot" },
            .attribute_modifiers = &.{.{ .attribute = "movement_speed", .operation = .multiply, .amount = 1.15 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "spring_boots",
            .occupied_slots = &.{"shoes"},
            .visual_recipes = &.{everyRecipe("boot", "foot_role", 2, "left_foot", "accessory", math.Transform2D.identity())},
            .covered_body_regions = &.{ "left_foot", "right_foot" },
            .attribute_modifiers = &.{.{ .attribute = "jump_strength", .operation = .multiply, .amount = 1.20 }},
            .capability_grants = &.{},
        },
        .{
            .stable_id = "winged_boots",
            .occupied_slots = &.{"shoes"},
            .visual_recipes = &.{everyRecipe("boot", "foot_role", 2, "left_foot", "accessory", math.Transform2D.identity())},
            .covered_body_regions = &.{ "left_foot", "right_foot" },
            .attribute_modifiers = &.{},
            .capability_grants = &.{"double_jump"},
        },
        .{
            .stable_id = "dash_amulet",
            .occupied_slots = &.{"neck_accessory"},
            .visual_recipes = &.{attachmentRecipe("amulet_visual", "neck", "torso", "accessory", math.Transform2D.init(.{ .x = 0, .y = -0.08 }, 0, math.Vec2.one))},
            .covered_body_regions = &.{},
            .attribute_modifiers = &.{},
            .capability_grants = &.{"dash"},
        },
        .{
            .stable_id = "backpack",
            .occupied_slots = &.{"pack"},
            .visual_recipes = &.{attachmentRecipe("backpack_visual", "upper_back", "torso", "accessory", math.Transform2D.init(.{ .x = -0.12, .y = -0.20 }, 0, math.Vec2.one))},
            .covered_body_regions = &.{"torso"},
            .attribute_modifiers = &.{.{ .attribute = "carrying_capacity", .operation = .add, .amount = 20 }},
            .capability_grants = &.{},
        },
    };
    return equipment.Definition.init(allocator, anatomy_definition, appearance_definition, .{
        .equipment_slots = &slots,
        .anatomy_roles = &roles,
        .visual_layers = &layers,
        .visual_components = &components,
        .attributes = &attributes,
        .capabilities = &capabilities,
        .items = &items,
        .default_loadout = &.{
            "tailored_mesh_set",
            "upper_back_cape",
            "left_shoulder_armor",
            "right_gauntlet",
            "speed_boots",
            "dash_amulet",
            "backpack",
        },
    });
}

fn meshComponent(
    stable_id: []const u8,
    definition: mesh.DefinitionView,
    response: deformation.Response,
    secondary_motion: ?attachment_secondary_motion.Definition,
) equipment.VisualComponentInput {
    return .{
        .stable_id = stable_id,
        .sprite_size = .{ .x = 1, .y = 1 },
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 1, 1 },
        .tint = definition.material.tint,
        .texture_page = definition.material.texture_page,
        .deformation_response = response,
        .secondary_motion = secondary_motion,
        .primitive = .{ .deformable_mesh = definition },
    };
}

fn rigidComponent(
    stable_id: []const u8,
    size: math.Vec2,
    tint: [4]f32,
    response: deformation.Response,
) equipment.VisualComponentInput {
    return .{
        .stable_id = stable_id,
        .sprite_size = size,
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 0.5, 0.5 },
        .tint = tint,
        .texture_page = 0,
        .deformation_response = response,
    };
}

fn torsoLocal() math.Transform2D {
    return math.Transform2D.init(.{ .x = 0, .y = 0.56 }, 0, math.Vec2.one);
}

fn firstRecipe(
    component_name: []const u8,
    role: []const u8,
    region: []const u8,
    layer: []const u8,
    local: math.Transform2D,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component_name,
        .binding = .{ .anatomy = .{
            .role = role,
            .selection = .first_compatible,
            .maximum_matches = 1,
        } },
        .local_to_binding = local,
        .body_region = region,
        .visual_layer = layer,
    };
}

fn everyRecipe(
    component_name: []const u8,
    role: []const u8,
    maximum_matches: u16,
    region: []const u8,
    layer: []const u8,
    local: math.Transform2D,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component_name,
        .binding = .{ .anatomy = .{
            .role = role,
            .selection = .every_compatible,
            .maximum_matches = maximum_matches,
        } },
        .local_to_binding = local,
        .body_region = region,
        .visual_layer = layer,
    };
}

fn specificRecipe(
    component_name: []const u8,
    role: []const u8,
    part_name: []const u8,
    region: []const u8,
    layer: []const u8,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component_name,
        .binding = .{ .anatomy = .{
            .role = role,
            .selection = .specific_instance,
            .specific_instance = part_name,
            .maximum_matches = 1,
        } },
        .body_region = region,
        .visual_layer = layer,
    };
}

fn attachmentRecipe(
    component_name: []const u8,
    point_name: []const u8,
    region: []const u8,
    layer: []const u8,
    local: math.Transform2D,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component_name,
        .binding = .{ .attachment_point = point_name },
        .local_to_binding = local,
        .body_region = region,
        .visual_layer = layer,
    };
}

comptime {
    if (required_frames * (fixed_step.simulation_hz / 60) < 6000) {
        @compileError("foundation playground verification route is too short");
    }
}
