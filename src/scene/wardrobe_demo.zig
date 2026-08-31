const std = @import("std");
const math = @import("math");
const fixed_step = @import("fixed_step");
const input = @import("input");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const authored = @import("authored_clips");
const humanoid = @import("humanoid");
const character = @import("character");
const character_art = @import("character_art");
const modular_humanoid = @import("modular_humanoid");
const wardrobe_catalog = @import("wardrobe_catalog");
const wardrobe_art = @import("wardrobe_art");
const wardrobe_presentation = @import("wardrobe_presentation");
const render_queue = @import("render_queue");
const visual_geometry = @import("visual_geometry");
const anatomy_evidence = @import("anatomy_evidence");

pub const required_frames: u32 = 600;
pub const visual_quality_required_frames: u32 = 600;
pub const fixed_ticks_per_frame: usize = 4;
pub const character_count: u32 = 2;
pub const character_art_renderer_offset: u32 = 1;
pub const wardrobe_art_renderer_offset: u32 =
    character_art_renderer_offset + character_art.texture_page_count;
pub const combined_art_page_count: usize =
    character_art.texture_page_count + wardrobe_art.texture_page_count;
pub const mesh_definition_count: usize = wardrobe_presentation.mesh_definition_count;
const preset_frames: u32 = 24;

fn anatomyStageForFrame(frame: u32) anatomy_evidence.Stage {
    return if (frame < 40)
        .neutral_front
    else if (frame < 80)
        .neutral_side_right
    else if (frame < 120)
        .neutral_side_left
    else if (frame < 160)
        .build_low_front
    else if (frame < 200)
        .build_high_front
    else if (frame < 360)
        .arm_extended_side
    else if (frame < 480)
        .elbow_bent_side
    else
        .deep_knee_bend_side;
}

pub const Initialization = struct {
    collider_inputs: ?[]const collider.StaticColliderInput = null,
    male_spawn: math.Vec2 = .{ .x = 1.40, .y = 1.05 },
    female_spawn: math.Vec2 = .{ .x = -1.02, .y = 1.05 },
    male_facing: humanoid.Facing = .left,
    female_facing: humanoid.Facing = .left,
    optional_arm_root_contract: modular_humanoid.OptionalArmRootContract =
        .standard,
};

pub const Evidence = struct {
    preset_selected: [wardrobe_catalog.preset_count]bool =
        [_]bool{false} ** wardrobe_catalog.preset_count,
    preset_front_observed: [wardrobe_catalog.preset_count]bool =
        [_]bool{false} ** wardrobe_catalog.preset_count,
    preset_side_observed: [wardrobe_catalog.preset_count]bool =
        [_]bool{false} ** wardrobe_catalog.preset_count,
    mandatory_wide_brim: bool = false,
    mandatory_ivory_blouse_red_shorts: bool = false,
    long_garment_mesh: bool = false,
    long_garment_secondary_motion: bool = false,
    long_hair_with_headwear: bool = false,
    legwear_observed: bool = false,
    footwear_observed: bool = false,
    custom_recombination: bool = false,
    breathing_observed: bool = false,
    locomotion_observed: bool = false,
    jump_observed: bool = false,
    landing_observed: bool = false,
    male_unchanged: bool = false,
    rapid_cycle_complete: bool = false,
};

pub const VisualQualityEvidence = struct {
    base_front: bool = false,
    base_side: bool = false,
    male_outfit_front: bool = false,
    male_outfit_side: bool = false,
    female_outfit_front: bool = false,
    female_outfit_side: bool = false,
    wide_brim_front: bool = false,
    wide_brim_side: bool = false,
    ivory_blouse_front: bool = false,
    ivory_blouse_side: bool = false,
    layered_custom_front: bool = false,
    layered_custom_side: bool = false,
    locomotion_observed: bool = false,
    jump_observed: bool = false,
};

pub const Scene = struct {
    character_art_definition: character_art.Definition,
    wardrobe_art_definition: wardrobe_art.Definition,
    definition: humanoid.HumanoidDefinition,
    catalog: wardrobe_catalog.Catalog,
    animations: authored.Definitions,
    world: collision_world.CollisionWorld,
    male: character.CharacterInstance,
    female: character.CharacterInstance,
    male_art: character_art.Presentation,
    female_art: character_art.Presentation,
    wardrobe: wardrobe_presentation.Presentation,
    clock: fixed_step.Clock,
    pending_input: input.PendingInput = .{},
    frame_index: u32 = 0,
    simulation_tick: u64 = 0,
    current_preset: wardrobe_catalog.OutfitPresetId = @enumFromInt(0),
    custom_active: bool = false,
    paused: bool = false,
    initial_breathing_sample: f32,
    male_initial_world: math.Vec2,
    male_initial_facing: humanoid.Facing,
    evidence: Evidence = .{},
    visual_quality_enabled: bool = false,
    visual_quality_evidence: VisualQualityEvidence = .{},
    anatomy_quality_enabled: bool = false,
    anatomy_evidence_stage: anatomy_evidence.Stage = .neutral_front,
    anatomy_stage_frame: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) !Scene {
        return initWithConfiguration(allocator, .{});
    }

    pub fn initWithConfiguration(
        allocator: std.mem.Allocator,
        configuration: Initialization,
    ) !Scene {
        var character_art_definition = try character_art.Definition.init(allocator);
        errdefer character_art_definition.deinit();
        var wardrobe_art_definition = try wardrobe_art.Definition.init(allocator);
        errdefer wardrobe_art_definition.deinit();
        var definition =
            try modular_humanoid.initDefinitionWithOptionalArmRootContract(
                allocator,
                configuration.optional_arm_root_contract,
            );
        errdefer definition.deinit();
        var catalog = try wardrobe_catalog.Catalog.init(allocator, &definition);
        errdefer catalog.deinit();
        var animations = try authored.Definitions.init(
            allocator,
            &definition.skeleton_definition,
            null,
        );
        errdefer animations.deinit();
        var world = if (configuration.collider_inputs) |inputs|
            try collision_world.CollisionWorld.init(allocator, inputs, null)
        else
            try collision_world.CollisionWorld.initDemo(allocator, null);
        errdefer world.deinit();

        var male = try character.CharacterInstance.init(
            allocator,
            try character.entityIdFromRaw(1),
            &definition,
            &animations,
            configuration.male_spawn,
            configuration.male_facing,
            0,
            null,
        );
        errdefer male.deinit();
        var female = try character.CharacterInstance.initControlled(
            allocator,
            try character.entityIdFromRaw(2),
            &definition,
            &animations,
            &world,
            .{},
            configuration.female_spawn,
            configuration.female_facing,
            1,
            null,
        );
        errdefer female.deinit();

        const anatomy_definition = if (definition.anatomy_definition) |*value|
            value.view()
        else
            return error.WardrobeDemoRequiresAnatomy;
        try male.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_male"));
        try female.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_female"));
        try female.initializeEquipment(catalog.equipment_definition.view());
        const first = try catalog.preset(@enumFromInt(0));
        try female.selectEquipmentItems(first.items());

        var wardrobe = try wardrobe_presentation.Presentation.init(
            allocator,
            &wardrobe_art_definition,
            &catalog,
            wardrobe_art_renderer_offset,
        );
        errdefer wardrobe.deinit();

        return .{
            .character_art_definition = character_art_definition,
            .wardrobe_art_definition = wardrobe_art_definition,
            .definition = definition,
            .catalog = catalog,
            .animations = animations,
            .world = world,
            .male = male,
            .female = female,
            .male_art = try character_art.Presentation.init(
                &character_art_definition,
                &definition,
                .male,
                character_art_renderer_offset,
            ),
            .female_art = try character_art.Presentation.init(
                &character_art_definition,
                &definition,
                .female,
                character_art_renderer_offset,
            ),
            .wardrobe = wardrobe,
            .clock = try fixed_step.Clock.init(.{}),
            .initial_breathing_sample = try female.breathingSample(),
            .male_initial_world = male.worldPosition(),
            .male_initial_facing = male.facingDirection(),
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.wardrobe.deinit();
        scene.female.deinit();
        scene.male.deinit();
        scene.world.deinit();
        scene.animations.deinit();
        scene.catalog.deinit();
        scene.definition.deinit();
        scene.wardrobe_art_definition.deinit();
        scene.character_art_definition.deinit();
        scene.* = undefined;
    }

    pub fn meshDefinitions(
        scene: *const Scene,
    ) [mesh_definition_count]@import("deformable_mesh").DefinitionView {
        return scene.wardrobe.meshDefinitions();
    }

    pub fn updateScriptedFrame(scene: *Scene) !void {
        try scene.applyScriptedSelection();
        const frame = try scene.clock.beginFrame(1.0 / 60.0);
        if (frame.substeps != fixed_ticks_per_frame) return error.WardrobeFixedTickGroupingMismatch;
        for (0..frame.substeps) |_| try scene.stepScriptedTick();
        scene.captureEvidence();
        scene.frame_index = std.math.add(u32, scene.frame_index, 1) catch
            return error.WardrobeFrameOverflow;
    }

    pub fn updateInteractiveFrame(
        scene: *Scene,
        snapshot: input.FrameInputSnapshot,
    ) !void {
        return scene.updateInteractiveFrameDelta(snapshot, 1.0 / 60.0);
    }

    pub fn updateInteractiveFrameDelta(
        scene: *Scene,
        snapshot: input.FrameInputSnapshot,
        frame_delta: f64,
    ) !void {
        try scene.female.applyPresentationInput(snapshot);
        if (snapshot.outfit_cycle.pressed) {
            try scene.selectPreset(try scene.catalog.nextPreset(scene.current_preset));
        }
        if (snapshot.pause_toggle.pressed) scene.paused = !scene.paused;
        if (snapshot.reset.pressed) {
            try scene.female.resetControlled(&scene.world);
            try scene.selectPreset(@enumFromInt(0));
            scene.paused = false;
        }
        if (!scene.paused) {
            try scene.pending_input.acceptFrame(snapshot);
            const frame = try scene.clock.beginFrame(frame_delta);
            for (0..frame.substeps) |_| {
                scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch
                    return error.SimulationTickOverflow;
                _ = try scene.stepFemale(scene.pending_input.consumeTick());
                try scene.stepMale();
            }
        }
        scene.captureEvidence();
        scene.frame_index +|= 1;
    }

    pub fn enableVisualQualityAcceptance(scene: *Scene) !void {
        if (scene.visual_quality_enabled) return error.VisualQualityAlreadyEnabled;
        if (scene.frame_index != 0 or scene.male.hasEquipment()) {
            return error.VisualQualityMustBeEnabledBeforeSimulation;
        }
        try scene.male.initializeEquipment(scene.catalog.equipment_definition.view());
        const base = try scene.catalog.presetId("base_only");
        const base_items = (try scene.catalog.preset(base)).items();
        try scene.male.selectEquipmentItems(base_items);
        try scene.female.selectEquipmentItems(base_items);
        scene.current_preset = base;
        scene.custom_active = false;
        scene.visual_quality_enabled = true;
    }

    pub fn enableAnatomyQualityAcceptance(scene: *Scene) !void {
        if (scene.anatomy_quality_enabled) {
            return error.AnatomyQualityAlreadyEnabled;
        }
        try scene.enableVisualQualityAcceptance();
        scene.anatomy_quality_enabled = true;
        try scene.configureAnatomyEvidenceStage(.neutral_front);
    }

    pub fn updateAnatomyQualityFrame(scene: *Scene) !void {
        if (!scene.anatomy_quality_enabled) {
            return error.AnatomyQualityNotEnabled;
        }
        const next_stage = anatomyStageForFrame(scene.frame_index);
        if (next_stage != scene.anatomy_evidence_stage) {
            try scene.configureAnatomyEvidenceStage(next_stage);
            scene.anatomy_stage_frame = 0;
        }
        const frame = try scene.clock.beginFrame(1.0 / 60.0);
        if (frame.substeps != fixed_ticks_per_frame) {
            return error.WardrobeFixedTickGroupingMismatch;
        }
        for (0..frame.substeps) |substep| {
            scene.simulation_tick = std.math.add(
                u64,
                scene.simulation_tick,
                1,
            ) catch return error.SimulationTickOverflow;
            if (scene.anatomy_evidence_stage == .elbow_bent_side) {
                try scene.female.sampleInteractionAnimation(
                    .handshake_role_b,
                    0.55,
                );
                try scene.stepMale();
                continue;
            }
            const moving = scene.anatomy_evidence_stage ==
                .arm_extended_side;
            const turn_right = scene.anatomy_evidence_stage ==
                .neutral_side_right and scene.anatomy_stage_frame < 3;
            const turn_left = scene.anatomy_evidence_stage ==
                .neutral_side_left and scene.anatomy_stage_frame < 3;
            const jumping = scene.anatomy_evidence_stage ==
                .deep_knee_bend_side;
            _ = try scene.stepFemale(.{
                .move_axis = if (moving or turn_right or jumping)
                    0.58
                else if (turn_left)
                    -0.58
                else
                    0,
                .jump_pressed = jumping and
                    scene.anatomy_stage_frame == 0 and substep == 0,
                .jump_held = jumping and scene.anatomy_stage_frame < 12,
                .jump_released = jumping and
                    scene.anatomy_stage_frame == 12 and substep == 0,
                .interact_pressed = false,
            });
            try scene.stepMale();
        }
        scene.anatomy_stage_frame = std.math.add(
            u16,
            scene.anatomy_stage_frame,
            1,
        ) catch return error.AnatomyEvidenceStageFrameOverflow;
        scene.frame_index = std.math.add(u32, scene.frame_index, 1) catch
            return error.WardrobeFrameOverflow;
    }

    fn configureAnatomyEvidenceStage(
        scene: *Scene,
        stage: anatomy_evidence.Stage,
    ) !void {
        scene.anatomy_evidence_stage = stage;
        if (stage == .arm_extended_side or
            stage == .elbow_bent_side or
            stage == .deep_knee_bend_side)
        {
            try scene.female.resetControlled(&scene.world);
        }
        const side = switch (stage) {
            .neutral_side_right,
            .arm_extended_side,
            .elbow_bent_side,
            .deep_knee_bend_side,
            => true,
            else => false,
        };
        const facing: humanoid.Facing = if (stage == .neutral_side_left)
            .left
        else
            .right;
        try scene.male.setFacing(facing);
        try scene.female.setFacing(facing);
        try scene.male.setPresentationOverride(
            if (side or stage == .neutral_side_left)
                .force_side
            else
                .force_front,
        );
        try scene.female.setPresentationOverride(
            if (side or stage == .neutral_side_left)
                .force_side
            else
                .force_front,
        );
        const build: f32 = switch (stage) {
            .build_low_front => 15,
            .build_high_front => 85,
            else => 50,
        };
        try scene.male.setGlobalBuild(build);
        try scene.female.setGlobalBuild(build);
        if (stage == .elbow_bent_side) {
            try scene.female.enterAnimationState(.handshake_role_b);
        }
    }

    pub fn updateVisualQualityFrame(scene: *Scene) !void {
        if (!scene.visual_quality_enabled) return error.VisualQualityNotEnabled;
        try scene.applyVisualQualitySelection();
        const frame = try scene.clock.beginFrame(1.0 / 60.0);
        if (frame.substeps != fixed_ticks_per_frame) {
            return error.WardrobeFixedTickGroupingMismatch;
        }
        var last_physics = character_controller.StepResult{
            .simulation_tick = scene.simulation_tick,
        };
        const dynamic_start_tick: u64 = 480 * fixed_ticks_per_frame;
        for (0..frame.substeps) |_| {
            scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch
                return error.SimulationTickOverflow;
            const dynamic_tick = if (scene.simulation_tick > dynamic_start_tick)
                scene.simulation_tick - dynamic_start_tick
            else
                0;
            const intent: input.CharacterIntent = if (dynamic_tick == 0)
                .{
                    .move_axis = 0,
                    .jump_pressed = false,
                    .jump_held = false,
                    .jump_released = false,
                    .interact_pressed = false,
                }
            else
                .{
                    .move_axis = if (dynamic_tick < 120)
                        0.55
                    else if (dynamic_tick < 240)
                        -0.55
                    else
                        0.40,
                    .jump_pressed = dynamic_tick == 241,
                    .jump_held = dynamic_tick >= 241 and dynamic_tick < 266,
                    .jump_released = dynamic_tick == 266,
                    .interact_pressed = false,
                };
            last_physics = try scene.stepFemale(intent);
            try scene.stepMale();
        }
        scene.captureVisualQualityEvidence(last_physics);
        scene.frame_index = std.math.add(u32, scene.frame_index, 1) catch
            return error.WardrobeFrameOverflow;
    }

    pub fn selectPreset(
        scene: *Scene,
        preset_id: wardrobe_catalog.OutfitPresetId,
    ) !void {
        const preset = try scene.catalog.preset(preset_id);
        try scene.female.selectEquipmentItems(preset.items());
        scene.current_preset = preset_id;
        scene.custom_active = false;
        scene.evidence.preset_selected[preset_id.index()] = true;
    }

    pub fn selectCustom(scene: *Scene) !void {
        const custom = try scene.catalog.customItems();
        try scene.female.selectEquipmentItems(&custom);
        scene.custom_active = true;
        scene.evidence.custom_recombination = true;
    }

    pub fn submit(scene: *Scene, queue: *render_queue.UnifiedRenderQueue) !u32 {
        return scene.submitTraced(queue, null);
    }

    pub fn submitTraced(
        scene: *Scene,
        queue: *render_queue.UnifiedRenderQueue,
        trace: ?*visual_geometry.Trace,
    ) !u32 {
        var male_registered_feet = character_art.RegisteredFeet{};
        var female_registered_feet = character_art.RegisteredFeet{};
        const male_foot_coverage = try scene.wardrobe.baseFootCoverage(&scene.male);
        const female_foot_coverage = try scene.wardrobe.baseFootCoverage(&scene.female);
        var submitted = try scene.male_art.submitTracedWithRegisteredFeetAndCoverage(
            &scene.male,
            queue,
            trace,
            &male_registered_feet,
            male_foot_coverage,
        );
        submitted += try scene.female_art.submitTracedWithRegisteredFeetAndCoverage(
            &scene.female,
            queue,
            trace,
            &female_registered_feet,
            female_foot_coverage,
        );
        const meshes_before = queue.frame_metrics.submitted_meshes;
        if (scene.male.hasEquipment()) {
            submitted += try scene.wardrobe.submitTraced(
                &scene.male,
                queue,
                male_registered_feet,
                trace,
            );
        }
        submitted += try scene.wardrobe.submitTraced(
            &scene.female,
            queue,
            female_registered_feet,
            trace,
        );
        scene.evidence.long_garment_mesh = scene.evidence.long_garment_mesh or
            queue.frame_metrics.submitted_meshes > meshes_before;
        return submitted;
    }

    pub fn validateComplete(scene: *const Scene) !void {
        for (scene.evidence.preset_selected, 0..) |selected, index| {
            if (!selected or !scene.evidence.preset_front_observed[index] or
                !scene.evidence.preset_side_observed[index])
            {
                return error.WardrobePresetViewEvidenceIncomplete;
            }
        }
        const evidence = scene.evidence;
        if (!evidence.mandatory_wide_brim or
            !evidence.mandatory_ivory_blouse_red_shorts or
            !evidence.long_garment_mesh or
            !evidence.long_garment_secondary_motion or
            !evidence.long_hair_with_headwear or
            !evidence.legwear_observed or
            !evidence.footwear_observed or
            !evidence.custom_recombination or
            !evidence.breathing_observed or
            !evidence.locomotion_observed or
            !evidence.jump_observed or
            !evidence.landing_observed or
            !evidence.male_unchanged or
            !evidence.rapid_cycle_complete)
        {
            return error.WardrobeEvidenceIncomplete;
        }
        if (scene.male.hasEquipment() or
            !scene.male.worldPosition().approxEqAbs(scene.male_initial_world, 0.000001) or
            scene.male.facingDirection() != scene.male_initial_facing or
            scene.male.hotPathMetrics().submission_allocations != 0 or
            scene.female.hotPathMetrics().submission_allocations != 0)
        {
            return error.WardrobeIsolationEvidenceIncomplete;
        }
    }

    pub fn validateVisualQualityComplete(scene: *const Scene) !void {
        if (!scene.visual_quality_enabled or
            scene.frame_index != visual_quality_required_frames or
            !scene.male.hasEquipment() or
            !scene.female.hasEquipment())
        {
            return error.VisualQualityRouteIncomplete;
        }
        const evidence = scene.visual_quality_evidence;
        if (!evidence.base_front or
            !evidence.base_side or
            !evidence.male_outfit_front or
            !evidence.male_outfit_side or
            !evidence.female_outfit_front or
            !evidence.female_outfit_side or
            !evidence.wide_brim_front or
            !evidence.wide_brim_side or
            !evidence.ivory_blouse_front or
            !evidence.ivory_blouse_side or
            !evidence.layered_custom_front or
            !evidence.layered_custom_side or
            !evidence.locomotion_observed or
            !evidence.jump_observed or
            scene.male.hotPathMetrics().submission_allocations != 0 or
            scene.female.hotPathMetrics().submission_allocations != 0)
        {
            return error.VisualQualityEvidenceIncomplete;
        }
    }

    fn applyScriptedSelection(scene: *Scene) !void {
        const preset_index = scene.frame_index / preset_frames;
        const within_preset = scene.frame_index % preset_frames;
        if (preset_index < wardrobe_catalog.preset_count) {
            const id: wardrobe_catalog.OutfitPresetId = @enumFromInt(preset_index);
            if (within_preset == 0) try scene.selectPreset(id);
            try scene.female.setPresentationOverride(
                if (within_preset < preset_frames / 2) .force_front else .force_side,
            );
        } else if (scene.frame_index == wardrobe_catalog.preset_count * preset_frames) {
            try scene.selectCustom();
            try scene.female.setPresentationOverride(.force_front);
        } else if (scene.custom_active and scene.frame_index % 60 == 0) {
            try scene.female.setPresentationOverride(
                if (scene.female.presentationView() == .front) .force_side else .force_front,
            );
        }
    }

    fn applyVisualQualitySelection(scene: *Scene) !void {
        if (scene.frame_index % 60 != 0) return;
        const stage = scene.frame_index / 60;
        switch (stage) {
            0 => {
                const base = try scene.catalog.presetId("base_only");
                try scene.selectMalePreset(base);
                try scene.selectPreset(base);
                try scene.male.setPresentationOverride(.force_front);
                try scene.female.setPresentationOverride(.force_front);
            },
            1 => {
                try scene.male.setPresentationOverride(.force_side);
                try scene.female.setPresentationOverride(.force_side);
            },
            2 => {
                try scene.selectMalePreset(try scene.catalog.presetId("scarlet_sport"));
                try scene.selectPreset(try scene.catalog.presetId("wide_brim_crimson"));
                try scene.male.setPresentationOverride(.force_front);
                try scene.female.setPresentationOverride(.force_front);
            },
            3 => {
                try scene.male.setPresentationOverride(.force_side);
                try scene.female.setPresentationOverride(.force_side);
            },
            4 => {
                try scene.selectPreset(try scene.catalog.presetId("ivory_blouse_red_shorts"));
                try scene.male.setPresentationOverride(.force_front);
                try scene.female.setPresentationOverride(.force_front);
            },
            5 => {
                try scene.male.setPresentationOverride(.force_side);
                try scene.female.setPresentationOverride(.force_side);
            },
            6 => {
                try scene.selectCustom();
                try scene.male.setPresentationOverride(.force_front);
                try scene.female.setPresentationOverride(.force_front);
            },
            7 => {
                try scene.male.setPresentationOverride(.force_side);
                try scene.female.setPresentationOverride(.force_side);
            },
            8, 9 => {
                try scene.male.setPresentationOverride(.force_side);
                try scene.female.setPresentationOverride(.force_side);
            },
            else => return error.InvalidVisualQualityStage,
        }
    }

    pub fn selectMalePreset(
        scene: *Scene,
        preset_id: wardrobe_catalog.OutfitPresetId,
    ) !void {
        const preset = try scene.catalog.preset(preset_id);
        try scene.male.selectEquipmentItems(preset.items());
    }

    fn captureVisualQualityEvidence(
        scene: *Scene,
        physics: character_controller.StepResult,
    ) void {
        const stage = scene.frame_index / 60;
        switch (stage) {
            0 => scene.visual_quality_evidence.base_front = true,
            1 => scene.visual_quality_evidence.base_side = true,
            2 => {
                scene.visual_quality_evidence.male_outfit_front = true;
                scene.visual_quality_evidence.female_outfit_front = true;
                scene.visual_quality_evidence.wide_brim_front = true;
            },
            3 => {
                scene.visual_quality_evidence.male_outfit_side = true;
                scene.visual_quality_evidence.female_outfit_side = true;
                scene.visual_quality_evidence.wide_brim_side = true;
            },
            4 => scene.visual_quality_evidence.ivory_blouse_front = true,
            5 => scene.visual_quality_evidence.ivory_blouse_side = true,
            6 => scene.visual_quality_evidence.layered_custom_front = true,
            7 => scene.visual_quality_evidence.layered_custom_side = true,
            8, 9 => {
                scene.visual_quality_evidence.locomotion_observed =
                    scene.visual_quality_evidence.locomotion_observed or
                    @abs(scene.female.controllerSnapshot().?.state.velocity.x) > 0.1;
                scene.visual_quality_evidence.jump_observed =
                    scene.visual_quality_evidence.jump_observed or
                    physics.jump_accepted or
                    !scene.female.controllerSnapshot().?.state.grounded;
            },
            else => {},
        }
    }

    fn stepScriptedTick(scene: *Scene) !void {
        scene.simulation_tick = std.math.add(u64, scene.simulation_tick, 1) catch
            return error.SimulationTickOverflow;
        const phase = scene.simulation_tick % 480;
        const move_axis: f32 = if (phase < 160)
            -0.45
        else if (phase < 320)
            0.45
        else
            0;
        const jump_tick = scene.simulation_tick == 1_460;
        const physics = try scene.stepFemale(.{
            .move_axis = move_axis,
            .jump_pressed = jump_tick,
            .jump_held = scene.simulation_tick >= 1_460 and scene.simulation_tick < 1_490,
            .jump_released = scene.simulation_tick == 1_490,
            .interact_pressed = false,
        });
        scene.evidence.jump_observed = scene.evidence.jump_observed or physics.jump_accepted;
        scene.evidence.landing_observed = scene.evidence.landing_observed or physics.landed;
        try scene.stepMale();
    }

    pub fn stepFemale(
        scene: *Scene,
        intent: input.CharacterIntent,
    ) !character_controller.StepResult {
        const physics = try scene.female.stepController(&scene.world, intent);
        if (!scene.female.isInteractionLocked()) {
            try scene.female.selectControllerAnimation(physics);
            try scene.female.advanceVisualTickWithFootPlanting(&scene.world, .{
                .horizontal_velocity = scene.female.controllerSnapshot().?.state.velocity.x,
                .vertical_velocity = scene.female.controllerSnapshot().?.state.velocity.y,
                .physically_grounded = scene.female.controllerSnapshot().?.state.grounded,
                .landing_event = if (physics.landed) .{
                    .simulation_tick = physics.simulation_tick,
                    .impact_speed = physics.landing_impact_speed,
                } else null,
            });
        }
        return physics;
    }

    pub fn stepMale(scene: *Scene) !void {
        if (!scene.male.isInteractionLocked()) {
            try scene.male.advanceVisualTick(.{
                .horizontal_velocity = 0,
                .physically_grounded = true,
            });
        }
    }

    fn captureEvidence(scene: *Scene) void {
        if (!scene.custom_active) {
            const index = scene.current_preset.index();
            scene.evidence.preset_front_observed[index] =
                scene.evidence.preset_front_observed[index] or
                scene.female.presentationView() == .front;
            scene.evidence.preset_side_observed[index] =
                scene.evidence.preset_side_observed[index] or
                scene.female.presentationView() == .side;
        }
        scene.evidence.rapid_cycle_complete = allTrue(&scene.evidence.preset_selected);
        scene.evidence.mandatory_wide_brim = scene.evidence.mandatory_wide_brim or
            scene.current_preset == (scene.catalog.presetId("wide_brim_crimson") catch
                scene.current_preset);
        scene.evidence.mandatory_ivory_blouse_red_shorts =
            scene.evidence.mandatory_ivory_blouse_red_shorts or
            scene.current_preset ==
                (scene.catalog.presetId("ivory_blouse_red_shorts") catch scene.current_preset);
        scene.evidence.long_hair_with_headwear =
            scene.evidence.long_hair_with_headwear or
            (hasEquippedSlot(scene, "headwear") and femaleLongHairSelected(scene));
        scene.evidence.legwear_observed = scene.evidence.legwear_observed or
            hasEquippedSlot(scene, "legwear");
        scene.evidence.footwear_observed = scene.evidence.footwear_observed or
            hasEquippedSlot(scene, "footwear");
        scene.evidence.locomotion_observed = scene.evidence.locomotion_observed or
            @abs(scene.female.controllerSnapshot().?.state.velocity.x) > 0.1;
        const breathing = scene.female.breathingSample() catch scene.initial_breathing_sample;
        scene.evidence.breathing_observed = scene.evidence.breathing_observed or
            @abs(breathing - scene.initial_breathing_sample) > 0.05;
        scene.evidence.male_unchanged =
            !scene.male.hasEquipment() and
            scene.male.worldPosition().approxEqAbs(scene.male_initial_world, 0.000001) and
            scene.male.facingDirection() == scene.male_initial_facing;

        if (scene.female.equipmentView()) |loadout| {
            for (loadout.visuals()) |visual| {
                const recipe = loadout.definition.recipe(visual.recipe) catch continue;
                const component = loadout.definition.visual_components[recipe.component.index()];
                if (component.presentation_semantic != null and
                    @intFromEnum(component.presentation_semantic.?) == 25_032)
                {
                    scene.evidence.long_garment_secondary_motion =
                        scene.evidence.long_garment_secondary_motion or
                        (visual.secondary.initialized and visual.secondary.fixed_ticks > 0);
                }
            }
        }
    }
};

fn allTrue(values: []const bool) bool {
    for (values) |value| {
        if (!value) return false;
    }
    return true;
}

fn hasEquippedSlot(scene: *const Scene, stable_id: []const u8) bool {
    const loadout = scene.female.equipmentView().?;
    const slot = loadout.definition.slotId(stable_id) catch return false;
    return (loadout.itemInSlot(slot) catch null) != null;
}

fn femaleLongHairSelected(scene: *const Scene) bool {
    const anatomy_runtime = scene.female.humanoidView().anatomy_runtime orelse return false;
    const anatomy_definition = scene.female.definitionView().anatomy_definition orelse return false;
    const expected = anatomy_definition.hairDefinitionId("long_rigid") catch return false;
    return anatomy_runtime.selected_hair == expected;
}
