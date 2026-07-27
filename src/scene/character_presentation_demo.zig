const std = @import("std");
const fixed_step = @import("fixed_step");
const input = @import("input");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const authored = @import("authored_clips");
const humanoid = @import("humanoid");
const character = @import("character");
const character_art = @import("character_art");
const modular_body_demo = @import("modular_body_demo");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const render_queue = @import("render_queue");

pub const required_frames: u32 = 360;
pub const fixed_ticks_per_frame: usize = 4;
pub const character_count: u32 = 2;
pub const renderer_page_offset: u32 = 1;

pub const Evidence = struct {
    male_front_idle: bool = false,
    male_side_left: bool = false,
    front_preserved_left_facing: bool = false,
    male_side_right: bool = false,
    jump_observed: bool = false,
    fall_observed: bool = false,
    landing_observed: bool = false,
    bald_observed: bool = false,
    buzz_cut_observed: bool = false,
    female_front_idle: bool = false,
    female_side_movement: bool = false,
    breathing_observed: bool = false,
    long_hair_motion_observed: bool = false,
    forced_front_observed: bool = false,
    forced_side_observed: bool = false,
    handshake_side_view_observed: bool = false,
    returned_to_front_after_interaction: bool = false,
    interaction_completed: bool = false,
};

pub const Scene = struct {
    art_definition: character_art.Definition,
    definition: humanoid.HumanoidDefinition,
    animations: authored.Definitions,
    world: collision_world.CollisionWorld,
    male: character.CharacterInstance,
    female: character.CharacterInstance,
    male_art: character_art.Presentation,
    female_art: character_art.Presentation,
    manager: interaction_system.Manager,
    clock: fixed_step.Clock,
    pending_input: input.PendingInput = .{},
    simulation_tick: u64 = 0,
    scripted_hair_is_bald: bool = false,
    initial_breathing_sample: f32 = 0,
    evidence: Evidence = .{},

    pub fn init(allocator: std.mem.Allocator) !Scene {
        var art_definition = try character_art.Definition.init(allocator);
        errdefer art_definition.deinit();
        var definition = try modular_body_demo.initDefinition(allocator);
        errdefer definition.deinit();
        var animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer animations.deinit();
        var world = try collision_world.CollisionWorld.initDemo(allocator, null);
        errdefer world.deinit();

        var male = try character.CharacterInstance.initControlled(
            allocator,
            try character.entityIdFromRaw(1),
            &definition,
            &animations,
            &world,
            .{},
            .{ .x = -1.02, .y = 1.05 },
            .left,
            0,
            null,
        );
        errdefer male.deinit();
        var female = try character.CharacterInstance.init(
            allocator,
            try character.entityIdFromRaw(2),
            &definition,
            &animations,
            .{ .x = 1.40, .y = 1.05 },
            .left,
            1,
            null,
        );
        errdefer female.deinit();

        const anatomy_definition = if (definition.anatomy_definition) |*value|
            value.view()
        else
            return error.CharacterPresentationRequiresAnatomy;
        try male.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_male"));
        try female.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_female"));

        return .{
            .art_definition = art_definition,
            .definition = definition,
            .animations = animations,
            .world = world,
            .male = male,
            .female = female,
            .male_art = try character_art.Presentation.init(
                &art_definition,
                &definition,
                .male,
                renderer_page_offset,
            ),
            .female_art = try character_art.Presentation.init(
                &art_definition,
                &definition,
                .female,
                renderer_page_offset,
            ),
            .manager = interaction_system.Manager.initWithIk(try handshake.definition(&animations)),
            .clock = try fixed_step.Clock.init(.{}),
            .initial_breathing_sample = try male.breathingSample(),
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.female.deinit();
        scene.male.deinit();
        scene.world.deinit();
        scene.animations.deinit();
        scene.definition.deinit();
        scene.art_definition.deinit();
        scene.* = undefined;
    }

    pub fn updateScriptedFrame(scene: *Scene) !void {
        const frame = try scene.clock.beginFrame(1.0 / 60.0);
        if (frame.substeps != fixed_ticks_per_frame) return error.PresentationFixedTickGroupingMismatch;
        for (0..frame.substeps) |_| try scene.updateScriptedTick();
    }

    pub fn updateInteractiveFrame(
        scene: *Scene,
        snapshot: input.FrameInputSnapshot,
    ) !void {
        try scene.male.applyPresentationInput(snapshot);
        if (snapshot.hair_cycle.pressed) {
            const anatomy_definition = scene.definition.anatomy_definition.?.view();
            if (scene.scripted_hair_is_bald) {
                try scene.male.selectHair(try anatomy_definition.hairDefinitionId("short_rigid"));
            } else {
                try scene.male.selectHair(null);
            }
            scene.scripted_hair_is_bald = !scene.scripted_hair_is_bald;
        }
        try scene.pending_input.acceptFrame(snapshot);
        const frame = try scene.clock.beginFrame(1.0 / 60.0);
        for (0..frame.substeps) |_| {
            scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch
                return error.SimulationTickOverflow;
            const participants_value = scene.participants();
            const intent = scene.pending_input.consumeTick();
            if (intent.interact_pressed and scene.manager.activeCount() == 0) {
                _ = scene.manager.requestFromIntent(
                    scene.male.id,
                    intent,
                    &participants_value,
                    scene.simulation_tick,
                ) catch null;
            }
            if (scene.manager.activeCount() != 0) {
                try scene.manager.updateTick(scene.simulation_tick, &participants_value);
            } else {
                _ = try scene.stepOrdinary(&scene.male, intent);
                _ = try scene.stepOrdinary(&scene.female, .{
                    .move_axis = 0,
                    .jump_pressed = false,
                    .jump_held = false,
                    .jump_released = false,
                    .interact_pressed = false,
                });
            }
        }
    }

    pub fn submit(scene: *Scene, queue: *render_queue.UnifiedRenderQueue) !u32 {
        var submitted = try scene.male_art.submit(&scene.male, queue);
        submitted += try scene.female_art.submit(&scene.female, queue);
        return submitted;
    }

    pub fn validateComplete(scene: *const Scene) !void {
        const evidence = scene.evidence;
        std.log.info(
            "character presentation evidence: male_front_idle={} male_side_left={} front_preserved_left_facing={} male_side_right={} jump={} fall={} landing={} bald={} buzz_cut={} female_front_idle={} female_side_movement={} breathing={} long_hair_motion={} forced_front={} forced_side={} handshake_side={} returned_front={} interaction_completed={}",
            .{
                evidence.male_front_idle,
                evidence.male_side_left,
                evidence.front_preserved_left_facing,
                evidence.male_side_right,
                evidence.jump_observed,
                evidence.fall_observed,
                evidence.landing_observed,
                evidence.bald_observed,
                evidence.buzz_cut_observed,
                evidence.female_front_idle,
                evidence.female_side_movement,
                evidence.breathing_observed,
                evidence.long_hair_motion_observed,
                evidence.forced_front_observed,
                evidence.forced_side_observed,
                evidence.handshake_side_view_observed,
                evidence.returned_to_front_after_interaction,
                evidence.interaction_completed,
            },
        );
        if (!evidence.male_front_idle or
            !evidence.male_side_left or
            !evidence.front_preserved_left_facing or
            !evidence.male_side_right or
            !evidence.jump_observed or
            !evidence.fall_observed or
            !evidence.landing_observed or
            !evidence.bald_observed or
            !evidence.buzz_cut_observed or
            !evidence.female_front_idle or
            !evidence.female_side_movement or
            !evidence.breathing_observed or
            !evidence.long_hair_motion_observed or
            !evidence.forced_front_observed or
            !evidence.forced_side_observed or
            !evidence.handshake_side_view_observed or
            !evidence.returned_to_front_after_interaction or
            !evidence.interaction_completed)
        {
            return error.CharacterPresentationEvidenceIncomplete;
        }
        if (scene.manager.activeCount() != 0 or scene.manager.metrics.starts != 1 or
            scene.manager.metrics.completions != 1 or scene.manager.metrics.cancellations != 0)
        {
            return error.CharacterPresentationInteractionEvidenceIncomplete;
        }
        if (scene.male.presentationView() != .front or scene.female.presentationView() != .front) {
            return error.CharacterPresentationDidNotReturnToFront;
        }
        if (scene.male.metrics.submission_allocations != 0 or
            scene.female.metrics.submission_allocations != 0)
        {
            return error.CharacterPresentationAllocatedDuringSubmission;
        }
    }

    fn updateScriptedTick(scene: *Scene) !void {
        scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch
            return error.SimulationTickOverflow;
        const tick = scene.simulation_tick;
        const participants_value = scene.participants();

        if (tick == 500) {
            try scene.male.selectHair(null);
            scene.scripted_hair_is_bald = true;
            scene.evidence.bald_observed = true;
        } else if (tick == 540) {
            const anatomy_definition = scene.definition.anatomy_definition.?.view();
            try scene.male.selectHair(try anatomy_definition.hairDefinitionId("short_rigid"));
            scene.scripted_hair_is_bald = false;
            scene.evidence.buzz_cut_observed = true;
        } else if (tick == 650) {
            try scene.female.setPresentationOverride(.force_front);
        } else if (tick == 670) {
            try scene.female.setPresentationOverride(.force_side);
        } else if (tick == 690) {
            try scene.female.setPresentationOverride(.automatic);
        } else if (tick == 760) {
            try scene.prepareHandshake();
            _ = try scene.manager.startPair(
                scene.male.id,
                scene.female.id,
                &participants_value,
                scene.simulation_tick,
                .none,
            );
        }

        if (scene.manager.activeCount() != 0) {
            try scene.manager.updateTick(scene.simulation_tick, &participants_value);
            scene.evidence.handshake_side_view_observed =
                scene.evidence.handshake_side_view_observed or
                (scene.male.presentationView() == .side and scene.female.presentationView() == .side);
        } else {
            const male_intent = scriptedMaleIntent(tick);
            const female_intent = scriptedFemaleIntent(tick);
            const male_physics = try scene.stepOrdinary(&scene.male, male_intent);
            const female_physics = try scene.stepOrdinary(&scene.female, female_intent);
            _ = female_physics;
            scene.captureOrdinaryEvidence(tick, male_physics);
        }

        if (scene.manager.metrics.completions == 1) {
            scene.evidence.interaction_completed = true;
            scene.evidence.returned_to_front_after_interaction =
                scene.evidence.returned_to_front_after_interaction or
                (scene.male.presentationView() == .front and scene.female.presentationView() == .front);
        }
    }

    fn prepareHandshake(scene: *Scene) !void {
        try scene.male.resetControlled(&scene.world);
        try scene.female.reset();
        try scene.female.setWorldPosition(.{ .x = 2.70, .y = 1.05 });
        const anatomy_definition = scene.definition.anatomy_definition.?.view();
        try scene.male.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_male"));
        try scene.female.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_female"));
        try scene.male.setFacing(.right);
        try scene.female.setFacing(.left);
    }

    fn stepOrdinary(
        scene: *Scene,
        instance: *character.CharacterInstance,
        intent: input.CharacterIntent,
    ) !character_controller.StepResult {
        if (instance.controller == null) {
            if (@abs(intent.move_axis) > 0.001) {
                try instance.setFacing(if (intent.move_axis < 0) .left else .right);
                try instance.setWorldPosition(instance.world_position.add(.{
                    .x = intent.move_axis * 2.5 * @as(f32, @floatCast(fixed_step.fixed_dt_seconds)),
                    .y = 0,
                }));
                if (instance.animationState() != .walk) try instance.enterAnimationState(.walk);
            } else if (instance.animationState() == .walk) {
                try instance.enterAnimationState(.idle);
            }
            try instance.advanceVisualTick(.{
                .horizontal_velocity = intent.move_axis * 2.5,
                .physically_grounded = true,
            });
            return .{ .simulation_tick = instance.simulation_tick };
        }
        const physics = try instance.stepController(&scene.world, intent);
        if (!instance.isInteractionLocked()) try instance.selectControllerAnimation(physics);
        try instance.advanceVisualTickWithFootPlanting(&scene.world, .{
            .horizontal_velocity = instance.controller.?.state.velocity.x,
            .vertical_velocity = instance.controller.?.state.velocity.y,
            .physically_grounded = instance.controller.?.state.grounded,
            .landing_event = if (physics.landed) .{
                .simulation_tick = physics.simulation_tick,
                .impact_speed = physics.landing_impact_speed,
            } else null,
        });
        return physics;
    }

    fn captureOrdinaryEvidence(
        scene: *Scene,
        tick: u64,
        male_physics: character_controller.StepResult,
    ) void {
        scene.evidence.male_front_idle = scene.evidence.male_front_idle or
            (tick < 80 and scene.male.presentationView() == .front);
        scene.evidence.male_side_left = scene.evidence.male_side_left or
            (tick >= 80 and tick < 160 and scene.male.facing == .left and
                scene.male.presentationView() == .side);
        scene.evidence.front_preserved_left_facing = scene.evidence.front_preserved_left_facing or
            (tick >= 260 and tick < 300 and scene.male.facing == .left and
                scene.male.presentationView() == .front);
        scene.evidence.male_side_right = scene.evidence.male_side_right or
            (tick >= 300 and tick < 380 and scene.male.facing == .right and
                scene.male.presentationView() == .side);
        scene.evidence.jump_observed = scene.evidence.jump_observed or male_physics.jump_accepted;
        scene.evidence.fall_observed = scene.evidence.fall_observed or
            (!scene.male.controller.?.state.grounded and scene.male.controller.?.state.velocity.y < 0);
        scene.evidence.landing_observed = scene.evidence.landing_observed or male_physics.landed;
        scene.evidence.female_front_idle = scene.evidence.female_front_idle or
            (tick < 600 and scene.female.presentationView() == .front);
        scene.evidence.female_side_movement = scene.evidence.female_side_movement or
            (tick >= 580 and tick < 650 and scene.female.presentationView() == .side);
        scene.evidence.forced_front_observed = scene.evidence.forced_front_observed or
            (scene.female.presentationOverride() == .force_front and scene.female.presentationView() == .front);
        scene.evidence.forced_side_observed = scene.evidence.forced_side_observed or
            (scene.female.presentationOverride() == .force_side and scene.female.presentationView() == .side);
        const sample = scene.male.breathingSample() catch 0;
        scene.evidence.breathing_observed = scene.evidence.breathing_observed or
            @abs(sample - scene.initial_breathing_sample) > 0.05;
        scene.evidence.long_hair_motion_observed = scene.evidence.long_hair_motion_observed or
            femaleHairHasMotion(scene);
    }

    fn participants(scene: *Scene) [character_count]*character.CharacterInstance {
        return .{ &scene.male, &scene.female };
    }
};

fn scriptedMaleIntent(tick: u64) input.CharacterIntent {
    return .{
        .move_axis = if (tick >= 80 and tick < 160)
            -1
        else if (tick >= 300 and tick < 380)
            1
        else
            0,
        .jump_pressed = tick == 381,
        .jump_held = tick >= 381 and tick < 410,
        .jump_released = tick == 410,
        .interact_pressed = false,
    };
}

fn scriptedFemaleIntent(tick: u64) input.CharacterIntent {
    return .{
        .move_axis = if (tick >= 580 and tick < 650) -0.75 else 0,
        .jump_pressed = false,
        .jump_held = false,
        .jump_released = false,
        .interact_pressed = false,
    };
}

fn femaleHairHasMotion(scene: *Scene) bool {
    const hair_id = scene.definition.visual_definition.visualId("long_hair") catch return false;
    const state = scene.female.character.appearance_runtime.visualSecondaryState(
        scene.female.definition.visual_definition,
        hair_id,
    ) catch return false;
    if (!state.initialized or state.fixed_ticks == 0) return false;
    for (state.points) |point| {
        const displacement = point.displacement();
        if (displacement.lengthSquared() > 0.000001) return true;
    }
    return false;
}
