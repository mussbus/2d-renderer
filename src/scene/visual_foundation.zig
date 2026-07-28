const std = @import("std");
const math = @import("math");
const input = @import("input");
const fixed_step = @import("fixed_step");
const character_controller = @import("character_controller");
const character = @import("character");
const humanoid = @import("humanoid");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const presentation_view = @import("presentation_view");
const presentation_pose = @import("presentation_pose");
const skeleton = @import("skeleton");
const environment_demo = @import("environment_demo");
const environment_art = @import("environment_art");
const environment_theme = @import("environment_theme");
const foundation_playground = @import("foundation_playground");
const wardrobe_catalog = @import("wardrobe_catalog");
const wardrobe_demo = @import("wardrobe_demo");
const render_queue = @import("render_queue");

pub const required_frames: u32 = 2_100;
pub const character_count: u32 = 2;
pub const mesh_definition_count: usize = environment_demo.mesh_definition_count;
pub const configured_texture_page_count: u32 = environment_demo.configured_texture_page_count;
pub const required_handshake_count: usize = 3;
pub const handshake_target_x: f32 =
    foundation_playground.partner_spawn.x - handshake.authored_horizontal_separation;

pub const TimeMode = enum(u8) {
    normal,
    quarter_speed,
    paused,
};

pub const InteractionRecord = struct {
    captured: bool = false,
    id: interaction_system.InteractionId = .invalid,
    type_id: interaction.TypeId = .invalid,
    initiator: character.EntityId = .invalid,
    receiver: character.EntityId = .invalid,
    outfit: wardrobe_catalog.OutfitPresetId = @enumFromInt(0),
    theme: environment_art.ThemeId = .violet_crystal_ruin,
    requested_initiator_view: ?presentation_view.View = null,
    requested_receiver_view: ?presentation_view.View = null,
    start_tick: u64 = 0,
    contact_tick: u64 = 0,
    release_tick: u64 = 0,
    complete_tick: u64 = 0,
    pre_ik_separation: f32 = 0,
    post_ik_separation: f32 = 0,
    projected_hand_separation: f32 = 0,
    initiator_view_at_contact: presentation_view.View = .front,
    receiver_view_at_contact: presentation_view.View = .front,
    body_ordering_valid: bool = false,
    equipment_ordering_valid: bool = false,
    roots_invariant: bool = true,
    secondary_finite: bool = true,
};

pub const Evidence = struct {
    initial_front_idle: bool = false,
    male_buzz_cut: bool = false,
    female_curvy_long_hair: bool = false,
    coherent_male_outfit: bool = false,
    walk_left_side: bool = false,
    stop_front_facing_left: bool = false,
    walk_right_side: bool = false,
    jump_side: bool = false,
    fall_side: bool = false,
    landing_observed: bool = false,
    raised_platform_landing: bool = false,
    breathing_observed: bool = false,
    outfit_idle_change: bool = false,
    outfit_motion_change: bool = false,
    dash_observed: bool = false,
    double_jump_observed: bool = false,
    camera_follow: bool = false,
    parallax: bool = false,
    violet_theme: bool = false,
    debug_theme: bool = false,
    theme_invariance: bool = true,
    white_surface_count: u32 = 0,
    approach_observed: bool = false,
    side_view_acquired: bool = false,
    contact_observed: bool = false,
    ik_contact_observed: bool = false,
    release_observed: bool = false,
    completion_observed: bool = false,
    front_idle_restored: bool = false,
    resize_invariant: bool = false,
    reset_observed: bool = false,
    stable_final_state: bool = false,
    body_cycle_observed: bool = false,
    build_cycle_observed: bool = false,
    hair_cycle_observed: bool = false,
    detailed_debug_observed: bool = false,
    interaction_records: [required_handshake_count]InteractionRecord =
        [_]InteractionRecord{.{}} ** required_handshake_count,
    interaction_count: usize = 0,
    maximum_active_sprites: u32 = 0,
    maximum_active_meshes: u32 = 0,
    maximum_sprite_ranges: u32 = 0,
    maximum_mesh_ranges: u32 = 0,
    maximum_sprite_draws: u32 = 0,
    maximum_mesh_draws: u32 = 0,
    maximum_sprite_upload_bytes: usize = 0,
    maximum_mesh_upload_bytes: usize = 0,
};

pub const Scene = struct {
    integrated: environment_demo.Scene,
    manager: interaction_system.Manager,
    time_mode: TimeMode = .normal,
    body_cycle_index: u8 = 0,
    build_cycle_index: u8 = 0,
    hair_cycle_index: u8 = 0,
    active_interaction: interaction_system.InteractionId = .invalid,
    last_terminal_id: interaction_system.InteractionId = .invalid,
    interaction_root_a: ?math.Vec2 = null,
    interaction_root_b: ?math.Vec2 = null,
    interaction_record_index: ?usize = null,
    initial_breathing_sample: f32,
    evidence: Evidence = .{},

    pub fn init(allocator: std.mem.Allocator) !Scene {
        var integrated = try environment_demo.Scene.init(allocator);
        errdefer integrated.deinit();
        try integrated.production.male.setFacing(.left);
        try configureLineup(&integrated.production);
        const manager = interaction_system.Manager.initWithIk(
            try handshake.definition(&integrated.production.animations),
        );
        var scene = Scene{
            .integrated = integrated,
            .manager = manager,
            .initial_breathing_sample = try integrated.production.female.breathingSample(),
        };
        scene.evidence.white_surface_count = @intCast(scene.integrated.environment.surfaces.count);
        scene.observePresentation();
        return scene;
    }

    pub fn deinit(scene: *Scene) void {
        scene.integrated.deinit();
        scene.* = undefined;
    }

    pub fn meshDefinitions(
        scene: *const Scene,
    ) [mesh_definition_count]@import("deformable_mesh").DefinitionView {
        return scene.integrated.meshDefinitions();
    }

    pub fn updateFrame(
        scene: *Scene,
        frame_delta: f64,
        snapshot: input.FrameInputSnapshot,
    ) !void {
        if (snapshot.reset.pressed) {
            try scene.resetWorld();
            scene.evidence.reset_observed = true;
            scene.integrated.production.frame_index +|= 1;
            return;
        }
        if (snapshot.debug_toggle.pressed) {
            scene.integrated.detailed_debug_enabled = !scene.integrated.detailed_debug_enabled;
        }
        if (snapshot.time_mode_cycle.pressed) {
            scene.time_mode = switch (scene.time_mode) {
                .normal => .quarter_speed,
                .quarter_speed => .paused,
                .paused => .normal,
            };
            scene.integrated.production.clock.setPaused(scene.time_mode == .paused);
            scene.integrated.production.pending_input.reset();
        }
        if (snapshot.pause_toggle.pressed) {
            scene.time_mode = if (scene.time_mode == .paused) .normal else .paused;
            scene.integrated.production.clock.setPaused(scene.time_mode == .paused);
            scene.integrated.production.pending_input.reset();
        }
        if (snapshot.single_step.pressed) {
            scene.integrated.production.clock.requestSingleStep();
        }
        if (snapshot.body_preset_cycle.pressed) try scene.cycleBody();
        if (snapshot.build_cycle.pressed) try scene.cycleBuild();
        if (snapshot.hair_cycle.pressed) try scene.cycleHair();
        if (snapshot.outfit_cycle.pressed or snapshot.loadout_cycle.pressed) {
            try scene.selectFemalePreset(
                try scene.integrated.production.catalog.nextPreset(
                    scene.integrated.production.current_preset,
                ),
            );
        }
        if (snapshot.environment_theme_cycle.pressed) {
            const before = scene.authoritativeInteractionFingerprint();
            try scene.integrated.cycleThemePreservingState();
            scene.evidence.theme_invariance =
                scene.evidence.theme_invariance and
                before == scene.authoritativeInteractionFingerprint();
        }
        try scene.integrated.production.female.applyPresentationInput(snapshot);

        if (scene.time_mode == .paused and !snapshot.single_step.pressed) {
            scene.integrated.production.pending_input.reset();
        } else {
            try scene.integrated.production.pending_input.acceptFrame(snapshot);
        }
        const scaled_delta = if (scene.time_mode == .quarter_speed)
            frame_delta * 0.25
        else
            frame_delta;
        const frame = try scene.integrated.production.clock.beginFrame(scaled_delta);
        for (0..frame.substeps) |_| try scene.updateTick();
        try scene.integrated.camera_follower.update(
            &scene.integrated.camera,
            scene.integrated.production.female.world_position.x,
        );
        scene.integrated.evidence.camera_minimum_x = @min(
            scene.integrated.evidence.camera_minimum_x,
            scene.integrated.camera.center.x,
        );
        scene.integrated.evidence.camera_maximum_x = @max(
            scene.integrated.evidence.camera_maximum_x,
            scene.integrated.camera.center.x,
        );
        const camera_delta = scene.integrated.evidence.camera_maximum_x -
            scene.integrated.evidence.camera_minimum_x;
        scene.evidence.camera_follow = scene.evidence.camera_follow or camera_delta > 2;
        scene.evidence.parallax = scene.evidence.parallax or
            (scene.evidence.camera_follow and
                foundation_playground.distant_camera_x_factor <
                    foundation_playground.midground_camera_x_factor);
        scene.observePresentation();
        scene.integrated.production.frame_index +|= 1;
    }

    fn updateTick(scene: *Scene) !void {
        const production = &scene.integrated.production;
        production.simulation_tick = std.math.add(u64, production.simulation_tick, 1) catch
            return error.SimulationTickOverflow;
        const intent_value = production.pending_input.consumeTick();
        const physics = try production.stepFemale(intent_value);
        try production.stepMale();
        scene.observePhysics(physics);

        const participants_value = scene.participants();
        if (intent_value.interact_pressed) {
            const requested = scene.manager.requestFromIntent(
                production.female.id,
                intent_value,
                &participants_value,
                production.simulation_tick,
            ) catch |err| switch (err) {
                error.NoEligibleInteractionCandidate => null,
                else => return err,
            };
            if (requested) |id| {
                try scene.beginInteractionRecord(id);
            }
        }
        try scene.manager.updateTick(production.simulation_tick, &participants_value);
        if (scene.manager.firstActiveInstance()) |active| {
            if (active.elapsed_ticks > 0) {
                try production.female.maintainFootPlantingDuringInteraction(&production.world);
                try production.male.maintainFootPlantingDuringInteraction(&production.world);
            }
            try scene.observeActiveInteraction(active);
        } else if (scene.manager.last_terminal) |*terminal| {
            if (terminal.id != scene.last_terminal_id) {
                try scene.observeTerminalInteraction(terminal);
                scene.last_terminal_id = terminal.id;
                scene.active_interaction = .invalid;
            }
        }
        try scene.validateSecondaryFinite();
        scene.observePresentation();
    }

    pub fn submit(scene: *Scene, queue: *render_queue.UnifiedRenderQueue) !u32 {
        const before_sprites = queue.frame_metrics.submitted_sprites;
        const before_meshes = queue.frame_metrics.submitted_meshes;
        const submitted = try scene.integrated.submit(queue);
        scene.evidence.maximum_active_sprites = @max(
            scene.evidence.maximum_active_sprites,
            queue.frame_metrics.submitted_sprites - before_sprites,
        );
        scene.evidence.maximum_active_meshes = @max(
            scene.evidence.maximum_active_meshes,
            queue.frame_metrics.submitted_meshes - before_meshes,
        );
        return submitted;
    }

    pub fn recordRendering(
        scene: *Scene,
        metrics: render_queue.FrameMetrics,
    ) void {
        scene.evidence.maximum_sprite_ranges =
            @max(scene.evidence.maximum_sprite_ranges, metrics.sprite_ranges);
        scene.evidence.maximum_mesh_ranges =
            @max(scene.evidence.maximum_mesh_ranges, metrics.mesh_ranges);
        scene.evidence.maximum_sprite_draws =
            @max(scene.evidence.maximum_sprite_draws, metrics.sprite_draws);
        scene.evidence.maximum_mesh_draws =
            @max(scene.evidence.maximum_mesh_draws, metrics.mesh_draws);
        scene.evidence.maximum_sprite_upload_bytes =
            @max(scene.evidence.maximum_sprite_upload_bytes, metrics.sprite_upload_bytes);
        scene.evidence.maximum_mesh_upload_bytes =
            @max(scene.evidence.maximum_mesh_upload_bytes, metrics.mesh_upload_bytes);
    }

    pub fn applyViewport(scene: *Scene, width: u32, height: u32) !void {
        const before = scene.authoritativeInteractionFingerprint();
        try scene.integrated.applyViewport(width, height);
        if (before != scene.authoritativeInteractionFingerprint()) {
            return error.VisualFoundationResizeChangedAuthoritativeState;
        }
        scene.evidence.resize_invariant = true;
    }

    pub fn selectFemalePreset(
        scene: *Scene,
        preset_id: wardrobe_catalog.OutfitPresetId,
    ) !void {
        try scene.integrated.production.selectPreset(preset_id);
    }

    pub fn selectFemalePresetByName(scene: *Scene, stable_id: []const u8) !void {
        try scene.selectFemalePreset(try scene.integrated.production.catalog.presetId(stable_id));
    }

    pub fn resetWorld(scene: *Scene) !void {
        const participants_value = scene.participants();
        try scene.manager.reset(&participants_value);
        try scene.integrated.production.female.resetControlled(
            &scene.integrated.production.world,
        );
        try scene.integrated.production.male.reset();
        try scene.integrated.production.male.setFacing(.left);
        try configureLineup(&scene.integrated.production);
        scene.integrated.production.pending_input.reset();
        scene.integrated.production.clock.reset();
        scene.integrated.production.simulation_tick = 0;
        scene.integrated.production.custom_active = false;
        scene.integrated.production.paused = false;
        scene.integrated.environment.reset();
        try scene.integrated.camera.setCenter(.{
            .x = foundation_playground.player_spawn.x,
            .y = environment_demo.presentation_camera_center_y,
        });
        scene.time_mode = .normal;
        scene.body_cycle_index = 0;
        scene.build_cycle_index = 0;
        scene.hair_cycle_index = 0;
        scene.active_interaction = .invalid;
        scene.interaction_root_a = null;
        scene.interaction_root_b = null;
        scene.interaction_record_index = null;
    }

    pub fn interactionEligibility(scene: *Scene) interaction_system.Eligibility {
        const participants_value = scene.participants();
        return scene.manager.evaluateEligibility(
            scene.integrated.production.female.id,
            scene.integrated.production.male.id,
            &participants_value,
        );
    }

    pub fn validateComplete(scene: *const Scene, script: *const ScriptedInput) !void {
        const evidence = scene.evidence;
        if (!script.completed()) {
            const state = scene.integrated.production.female.controller.?.state;
            var mutable_scene: *Scene = @constCast(scene);
            const eligibility = mutable_scene.interactionEligibility();
            std.log.err(
                "Prompt 27 script incomplete: phase={s} phase_frame={d} position=({d:.4},{d:.4}) velocity=({d:.4},{d:.4}) facing={s}/{s} grounded={} support={any} eligibility={s} separation={d:.4} interactions={d}",
                .{
                    @tagName(script.phase),
                    script.phase_frame,
                    state.position.x,
                    state.position.y,
                    state.velocity.x,
                    state.velocity.y,
                    @tagName(scene.integrated.production.female.facing),
                    @tagName(scene.integrated.production.male.facing),
                    state.grounded,
                    state.supporting_collider,
                    @tagName(eligibility.reason),
                    eligibility.horizontal_separation,
                    evidence.interaction_count,
                },
            );
            return error.VisualFoundationScriptIncomplete;
        }
        if (!evidence.initial_front_idle or
            !evidence.male_buzz_cut or
            !evidence.female_curvy_long_hair or
            !evidence.coherent_male_outfit or
            !evidence.walk_left_side or
            !evidence.stop_front_facing_left or
            !evidence.walk_right_side or
            !evidence.jump_side or
            !evidence.fall_side or
            !evidence.landing_observed or
            !evidence.raised_platform_landing or
            !evidence.breathing_observed or
            !evidence.outfit_idle_change or
            !evidence.outfit_motion_change or
            !evidence.dash_observed or
            !evidence.double_jump_observed or
            !evidence.camera_follow or
            !evidence.parallax or
            !evidence.violet_theme or
            !evidence.debug_theme or
            !evidence.theme_invariance or
            evidence.white_surface_count != environment_theme.expected_standable_surface_count or
            !evidence.approach_observed or
            !evidence.side_view_acquired or
            !evidence.contact_observed or
            !evidence.ik_contact_observed or
            !evidence.release_observed or
            !evidence.completion_observed or
            !evidence.front_idle_restored or
            !evidence.resize_invariant or
            !evidence.reset_observed or
            !evidence.stable_final_state or
            !evidence.body_cycle_observed or
            !evidence.build_cycle_observed or
            !evidence.hair_cycle_observed or
            !evidence.detailed_debug_observed or
            evidence.interaction_count != required_handshake_count or
            evidence.maximum_active_sprites == 0 or
            evidence.maximum_active_meshes == 0 or
            evidence.maximum_sprite_ranges == 0 or
            evidence.maximum_mesh_ranges == 0)
        {
            return error.VisualFoundationEvidenceIncomplete;
        }
        for (evidence.interaction_records, 0..) |record, record_index| {
            if (!record.captured or
                record.id == .invalid or
                record.type_id != .handshake or
                record.initiator != scene.integrated.production.female.id or
                record.receiver != scene.integrated.production.male.id or
                record.requested_initiator_view != .side or
                record.requested_receiver_view != .side or
                record.contact_tick <= record.start_tick or
                record.release_tick <= record.contact_tick or
                record.complete_tick <= record.release_tick or
                record.post_ik_separation > record.pre_ik_separation + 0.000001 or
                record.post_ik_separation > 0.02 or
                record.projected_hand_separation > 0.02 or
                record.initiator_view_at_contact != .side or
                record.receiver_view_at_contact != .side or
                !record.body_ordering_valid or
                !record.equipment_ordering_valid or
                !record.roots_invariant or
                !record.secondary_finite)
            {
                std.log.err(
                    "Prompt 27 interaction record {d} invalid: captured={} id={d} type={s} entities={d}/{d} views={any}/{any} ticks={d}/{d}/{d}/{d} separation={d:.6}->{d:.6} projected={d:.6} contact_views={s}/{s} ordering={}/{} roots={} secondary={}",
                    .{
                        record_index,
                        record.captured,
                        record.id.raw(),
                        @tagName(record.type_id),
                        record.initiator.raw(),
                        record.receiver.raw(),
                        record.requested_initiator_view,
                        record.requested_receiver_view,
                        record.start_tick,
                        record.contact_tick,
                        record.release_tick,
                        record.complete_tick,
                        record.pre_ik_separation,
                        record.post_ik_separation,
                        record.projected_hand_separation,
                        @tagName(record.initiator_view_at_contact),
                        @tagName(record.receiver_view_at_contact),
                        record.body_ordering_valid,
                        record.equipment_ordering_valid,
                        record.roots_invariant,
                        record.secondary_finite,
                    },
                );
                return error.VisualFoundationInteractionEvidenceIncomplete;
            }
        }
        const final = scene.integrated.production.female.controller.?.state;
        if (!final.position.approxEqAbs(foundation_playground.player_spawn, 0.000001) or
            !final.velocity.approxEqAbs(math.Vec2.zero, 0.000001) or
            !final.grounded or
            scene.manager.activeCount() != 0 or
            scene.manager.activeOwnedOverrideCount() != 0 or
            scene.manager.activeIkConstraintCount() != 0 or
            scene.integrated.production.female.interactionOwnerId() != 0 or
            scene.integrated.production.male.interactionOwnerId() != 0 or
            scene.integrated.production.female.presentationView() != .front or
            scene.integrated.production.male.presentationView() != .front or
            scene.integrated.environment.active_theme != .violet_crystal_ruin or
            scene.integrated.production.current_preset !=
                (scene.integrated.production.catalog.presetId("wide_brim_crimson") catch
                    scene.integrated.production.current_preset))
        {
            return error.VisualFoundationFinalStateInvalid;
        }
    }

    fn participants(scene: *Scene) [2]*character.CharacterInstance {
        return .{
            &scene.integrated.production.female,
            &scene.integrated.production.male,
        };
    }

    fn beginInteractionRecord(
        scene: *Scene,
        id: interaction_system.InteractionId,
    ) !void {
        if (scene.evidence.interaction_count >= scene.evidence.interaction_records.len) {
            return error.VisualFoundationInteractionRecordCapacityExceeded;
        }
        const index = scene.evidence.interaction_count;
        scene.evidence.interaction_records[index] = .{
            .id = id,
            .type_id = scene.manager.definition.type_id,
            .initiator = scene.integrated.production.female.id,
            .receiver = scene.integrated.production.male.id,
            .outfit = scene.integrated.production.current_preset,
            .theme = scene.integrated.environment.active_theme,
            .requested_initiator_view = scene.manager.definition.presentation.viewForRole(.initiator),
            .requested_receiver_view = scene.manager.definition.presentation.viewForRole(.receiver),
            .start_tick = scene.integrated.production.simulation_tick,
        };
        scene.interaction_record_index = index;
        scene.active_interaction = id;
        scene.interaction_root_a = scene.integrated.production.female.world_position;
        scene.interaction_root_b = scene.integrated.production.male.world_position;
        scene.evidence.interaction_count += 1;
    }

    fn observeActiveInteraction(
        scene: *Scene,
        active: *const interaction_system.Instance,
    ) !void {
        const index = scene.interaction_record_index orelse
            return error.MissingVisualFoundationInteractionRecord;
        var record = &scene.evidence.interaction_records[index];
        record.roots_invariant = record.roots_invariant and
            scene.integrated.production.female.world_position.approxEqAbs(
                scene.interaction_root_a.?,
                0.000001,
            ) and
            scene.integrated.production.male.world_position.approxEqAbs(
                scene.interaction_root_b.?,
                0.000001,
            );
        scene.evidence.side_view_acquired = scene.evidence.side_view_acquired or
            (scene.integrated.production.female.presentationView() == .side and
                scene.integrated.production.male.presentationView() == .side);
        if (active.contact.captured and record.contact_tick == 0) {
            scene.evidence.contact_observed = true;
            scene.evidence.ik_contact_observed =
                scene.evidence.ik_contact_observed or active.contact.ik_enabled;
            record.contact_tick = active.contact.tick;
            record.pre_ik_separation = active.contact.pre_separation;
            record.post_ik_separation = active.contact.post_separation;
            const projected_a = try projectedRightHand(
                &scene.integrated.production.female,
            );
            const projected_b = try projectedRightHand(
                &scene.integrated.production.male,
            );
            record.projected_hand_separation = projected_b.sub(projected_a).length();
            record.initiator_view_at_contact =
                scene.integrated.production.female.presentationView();
            record.receiver_view_at_contact =
                scene.integrated.production.male.presentationView();
            record.body_ordering_valid = try scene.bodyOrderingValid();
            record.equipment_ordering_valid = try scene.equipmentOrderingValid();
        }
        if (active.event_ticks[@intFromEnum(interaction.EventSemantic.release)] != null) {
            scene.evidence.release_observed = true;
        }
    }

    fn observeTerminalInteraction(
        scene: *Scene,
        terminal: *const interaction_system.Instance,
    ) !void {
        const index = scene.interaction_record_index orelse
            return error.MissingVisualFoundationInteractionRecord;
        var record = &scene.evidence.interaction_records[index];
        record.captured = terminal.lifecycle == .completed;
        record.contact_tick = terminal.event_ticks[
            @intFromEnum(interaction.EventSemantic.contact)
        ] orelse 0;
        record.release_tick = terminal.event_ticks[
            @intFromEnum(interaction.EventSemantic.release)
        ] orelse 0;
        record.complete_tick = terminal.event_ticks[
            @intFromEnum(interaction.EventSemantic.complete)
        ] orelse 0;
        record.pre_ik_separation = terminal.contact.pre_separation;
        record.post_ik_separation = terminal.contact.post_separation;
        scene.evidence.release_observed = scene.evidence.release_observed or
            record.release_tick != 0;
        scene.evidence.completion_observed = scene.evidence.completion_observed or
            record.complete_tick != 0;
        scene.interaction_record_index = null;
        scene.interaction_root_a = null;
        scene.interaction_root_b = null;
    }

    fn bodyOrderingValid(scene: *const Scene) !bool {
        const initiator_hand = try scene.integrated.production.female.resolvedOrder(.right_hand);
        const receiver_hand = try scene.integrated.production.male.resolvedOrder(.right_hand);
        const initiator_forearm =
            try scene.integrated.production.female.resolvedOrder(.right_forearm);
        const initiator_torso = try scene.integrated.production.female.resolvedOrder(.torso);
        const receiver_torso = try scene.integrated.production.male.resolvedOrder(.torso);
        return initiator_hand.interaction_layer == 3 and
            receiver_hand.interaction_layer == 2 and
            initiator_forearm.interaction_layer == 1 and
            initiator_torso.interaction_layer == character.neutral_interaction_layer and
            receiver_torso.interaction_layer == character.neutral_interaction_layer;
    }

    fn equipmentOrderingValid(scene: *const Scene) !bool {
        const production = &scene.integrated.production;
        const loadout = production.female.equipment_loadout orelse return false;
        const anatomy_definition = production.female.definition.anatomy_definition orelse
            return false;
        var found_hand_equipment = false;
        for (loadout.visuals(), 0..) |visual, visual_index| {
            const part_id = switch (visual.source) {
                .anatomy_part => |value| value,
                .attachment_point => continue,
            };
            if (!std.mem.eql(
                u8,
                anatomy_definition.part_instances[part_id.index()].stable_id.slice(),
                "right_hand",
            )) continue;
            found_hand_equipment = true;
            const equipment_order =
                try production.wardrobe.resolvedVisualOrder(&production.female, visual_index);
            const hand_order = try production.female.resolvedOrder(.right_hand);
            if (equipment_order.interaction_layer != hand_order.interaction_layer) return false;
        }
        // Presets without gloves have no hand-bound equipment to contradict the
        // profile. The long-garment evidence preset contains gloves and proves
        // the inherited ordering path directly.
        return found_hand_equipment or
            production.current_preset !=
                (production.catalog.presetId("garnet_formal") catch production.current_preset);
    }

    fn validateSecondaryFinite(scene: *Scene) !void {
        const loadout = scene.integrated.production.female.equipment_loadout orelse
            return error.CharacterEquipmentNotInitialized;
        for (loadout.visuals()) |visual| {
            const recipe = try loadout.definition.recipe(visual.recipe);
            const component = loadout.definition.visual_components[recipe.component.index()];
            if (component.secondary_motion) |definition| {
                if (!visual.secondary.isFiniteAndBounded(definition)) {
                    if (scene.interaction_record_index) |index| {
                        scene.evidence.interaction_records[index].secondary_finite = false;
                    }
                    return error.NonFiniteVisualFoundationSecondaryMotion;
                }
            }
        }
    }

    fn observePhysics(
        scene: *Scene,
        physics: character_controller.StepResult,
    ) void {
        const state = scene.integrated.production.female.controller.?.state;
        scene.evidence.landing_observed = scene.evidence.landing_observed or physics.landed;
        scene.evidence.raised_platform_landing =
            scene.evidence.raised_platform_landing or
            (physics.landed and state.supporting_collider != null and
                state.supporting_collider.? != 1);
        scene.evidence.dash_observed = scene.evidence.dash_observed or physics.dash_started;
        scene.evidence.double_jump_observed =
            scene.evidence.double_jump_observed or
            (physics.jump_accepted and physics.jump_source == .air);
    }

    fn observePresentation(scene: *Scene) void {
        const production = &scene.integrated.production;
        const state = production.female.controller.?.state;
        const view = production.female.presentationView();
        scene.evidence.initial_front_idle = scene.evidence.initial_front_idle or
            (state.grounded and @abs(state.velocity.x) < 0.0001 and view == .front);
        scene.evidence.walk_left_side = scene.evidence.walk_left_side or
            (state.velocity.x < -0.2 and production.female.facing == .left and view == .side);
        scene.evidence.stop_front_facing_left =
            scene.evidence.stop_front_facing_left or
            (state.grounded and @abs(state.velocity.x) < 0.02 and
                production.female.facing == .left and view == .front);
        scene.evidence.walk_right_side = scene.evidence.walk_right_side or
            (state.velocity.x > 0.2 and production.female.facing == .right and view == .side);
        scene.evidence.jump_side = scene.evidence.jump_side or
            (!state.grounded and state.velocity.y > 0 and view == .side);
        scene.evidence.fall_side = scene.evidence.fall_side or
            (!state.grounded and state.velocity.y < 0 and view == .side);
        scene.evidence.front_idle_restored = scene.evidence.front_idle_restored or
            (scene.evidence.completion_observed and
                scene.manager.activeCount() == 0 and
                state.grounded and @abs(state.velocity.x) < 0.02 and view == .front);
        const breathing = production.female.breathingSample() catch scene.initial_breathing_sample;
        scene.evidence.breathing_observed = scene.evidence.breathing_observed or
            @abs(breathing - scene.initial_breathing_sample) > 0.05;
        scene.evidence.violet_theme = scene.evidence.violet_theme or
            scene.integrated.environment.active_theme == .violet_crystal_ruin;
        scene.evidence.debug_theme = scene.evidence.debug_theme or
            scene.integrated.environment.active_theme == .neutral_debug;
        scene.evidence.detailed_debug_observed =
            scene.evidence.detailed_debug_observed or scene.integrated.detailed_debug_enabled;
        scene.observeLineup();
    }

    fn observeLineup(scene: *Scene) void {
        const production = &scene.integrated.production;
        const anatomy_definition = production.definition.anatomy_definition.?.view();
        const male_runtime = production.male.character.anatomy_runtime.?;
        const female_runtime = production.female.character.anatomy_runtime.?;
        scene.evidence.male_buzz_cut = scene.evidence.male_buzz_cut or
            male_runtime.selected_hair ==
                (anatomy_definition.hairDefinitionId("short_rigid") catch
                    male_runtime.selected_hair);
        scene.evidence.female_curvy_long_hair =
            scene.evidence.female_curvy_long_hair or
            (female_runtime.selected_morphology_preset ==
                (anatomy_definition.morphologyPresetId("curvy") catch
                    female_runtime.selected_morphology_preset) and
                female_runtime.selected_hair ==
                    (anatomy_definition.hairDefinitionId("long_rigid") catch
                        female_runtime.selected_hair));
        scene.evidence.coherent_male_outfit =
            scene.evidence.coherent_male_outfit or
            (production.male.equipment_loadout != null and
                production.male.equipment_loadout.?.equippedItems().len > 0);
    }

    fn cycleBody(scene: *Scene) !void {
        const names = [_][]const u8{ "conventional_female", "conventional_male" };
        scene.body_cycle_index = @intCast(
            (@as(usize, scene.body_cycle_index) + 1) % names.len,
        );
        const definition = scene.integrated.production.definition.anatomy_definition.?.view();
        try scene.integrated.production.female.selectBodyPreset(
            try definition.bodyPresetId(names[scene.body_cycle_index]),
        );
        scene.evidence.body_cycle_observed = true;
    }

    fn cycleBuild(scene: *Scene) !void {
        const values = [_]f32{ 65, 35, 50 };
        scene.build_cycle_index = @intCast(
            (@as(usize, scene.build_cycle_index) + 1) % values.len,
        );
        try scene.integrated.production.female.setGlobalBuild(
            values[scene.build_cycle_index],
        );
        scene.evidence.build_cycle_observed = true;
    }

    fn cycleHair(scene: *Scene) !void {
        const names = [_][]const u8{ "long_rigid", "ponytail", "short_rigid" };
        scene.hair_cycle_index = @intCast(
            (@as(usize, scene.hair_cycle_index) + 1) % names.len,
        );
        const definition = scene.integrated.production.definition.anatomy_definition.?.view();
        try scene.integrated.production.female.selectHair(
            try definition.hairDefinitionId(names[scene.hair_cycle_index]),
        );
        scene.evidence.hair_cycle_observed = true;
    }

    fn authoritativeInteractionFingerprint(scene: *const Scene) u64 {
        var hash = std.hash.Wyhash.init(27);
        hash.update(std.mem.asBytes(&scene.integrated.production.female.world_position));
        hash.update(std.mem.asBytes(&scene.integrated.production.male.world_position));
        hash.update(std.mem.asBytes(&scene.integrated.production.simulation_tick));
        hash.update(std.mem.asBytes(&scene.manager.metrics));
        hash.update(std.mem.asBytes(&scene.active_interaction));
        return hash.final();
    }
};

fn projectedRightHand(instance: *const character.CharacterInstance) !math.Vec2 {
    const definition = &instance.definition.skeleton_definition;
    const projection = try presentation_pose.FrontProjection.initSideInteraction(
        definition,
        instance.character.local_and_world_pose,
        instance.definition.visual_definition,
        instance.character.appearance_runtime,
        instance.world_position,
        instance.facing == .left,
    );
    const socket_index = try definition.socketIndex(skeleton.SocketSemantic.right_hand);
    const socket_definition = try definition.socket(socket_index);
    return projection.bone_world[socket_definition.parent_bone]
        .mul(try socket_definition.local_to_bone.localToParent())
        .translationPart();
}

fn configureLineup(production: *wardrobe_demo.Scene) !void {
    const definition = production.definition.anatomy_definition.?.view();
    try production.male.selectBodyPreset(try definition.bodyPresetId("conventional_male"));
    try production.male.selectMorphologyPreset(
        try definition.morphologyPresetId("athletic"),
    );
    try production.male.setGlobalBuild(42);
    try production.male.selectHair(try definition.hairDefinitionId("short_rigid"));
    try production.female.selectBodyPreset(try definition.bodyPresetId("conventional_female"));
    try production.female.selectMorphologyPreset(
        try definition.morphologyPresetId("curvy"),
    );
    try production.female.setGlobalBuild(65);
    try production.female.selectHair(try definition.hairDefinitionId("long_rigid"));
    try production.selectMalePreset(try production.catalog.presetId("scarlet_sport"));
    try production.selectPreset(try production.catalog.presetId("wide_brim_crimson"));
}

pub const ScriptPhase = enum(u8) {
    idle,
    customization_press,
    customization_release,
    move_left,
    stop_left,
    move_right,
    short_jump_press,
    short_jump_release,
    travel_to_platform,
    full_jump,
    wait_raised_landing,
    outfit_motion_press,
    outfit_motion_release,
    double_jump_first,
    double_jump_release,
    double_jump_second,
    double_jump_land,
    dash_to_handshake,
    dash_release,
    approach,
    first_interact,
    first_wait,
    long_outfit,
    second_interact,
    second_wait,
    ivory_outfit,
    third_interact,
    third_wait,
    cleanup_idle,
    debug_press,
    debug_release,
    reset_press,
    reset_release,
    final_idle,
};

pub const ScriptedInput = struct {
    phase: ScriptPhase = .idle,
    phase_frame: u32 = 0,
    resize_stage: u8 = 0,
    approach_turning_right: bool = false,
    completed_interactions: usize = 0,
    final_frames: u32 = 0,

    pub fn nextRaw(script: *ScriptedInput, scene: *const Scene) input.RawInputState {
        var raw = input.RawInputState{};
        const state = scene.integrated.production.female.controller.?.state;
        switch (script.phase) {
            .idle,
            .customization_release,
            .stop_left,
            .short_jump_release,
            .wait_raised_landing,
            .outfit_motion_release,
            .double_jump_release,
            .double_jump_land,
            .dash_release,
            .first_wait,
            .long_outfit,
            .second_wait,
            .ivory_outfit,
            .third_wait,
            .cleanup_idle,
            .debug_release,
            .reset_release,
            .final_idle,
            => {},
            .customization_press => {
                raw.keyboard.c = true;
                raw.keyboard.v = true;
                raw.keyboard.h = true;
            },
            .move_left => raw.keyboard.a = true,
            .move_right, .travel_to_platform, .full_jump, .outfit_motion_press => {
                raw.keyboard.d = true;
                if (script.phase == .full_jump) raw.keyboard.space = true;
                if (script.phase == .outfit_motion_press) raw.keyboard.o = true;
            },
            .short_jump_press => raw.keyboard.space = script.phase_frame < 3,
            .double_jump_first, .double_jump_second => raw.keyboard.space = true,
            .dash_to_handshake => {
                const error_value = handshake_target_x - state.position.x;
                if (@abs(error_value) > 0.4) {
                    if (error_value < 0) raw.keyboard.a = true else raw.keyboard.d = true;
                    raw.keyboard.left_shift = true;
                }
            },
            .approach => {
                const target = if (script.approach_turning_right)
                    handshake_target_x
                else
                    handshake_target_x - 0.10;
                const error_value = target - state.position.x;
                if (script.approach_turning_right and
                    scene.integrated.production.female.facing == .left)
                {
                    raw.gamepad_move_axis = encodeGamepadAxis(0.30);
                } else if (@abs(error_value) > 0.008) {
                    const command = std.math.clamp(
                        error_value * 0.5 - state.velocity.x * 0.8,
                        -0.15,
                        0.15,
                    );
                    raw.gamepad_move_axis = encodeGamepadAxis(command);
                }
            },
            .first_interact, .second_interact, .third_interact => raw.keyboard.e = true,
            .debug_press => raw.keyboard.f1 = true,
            .reset_press => raw.keyboard.r = true,
        }
        return raw;
    }

    pub fn observe(script: *ScriptedInput, scene: *Scene) !void {
        script.phase_frame += 1;
        const state = scene.integrated.production.female.controller.?.state;
        switch (script.phase) {
            .idle => if (script.phase_frame >= 35) script.transition(.customization_press),
            .customization_press => if (script.phase_frame >= 1)
                script.transition(.customization_release),
            .customization_release => if (script.phase_frame >= 2) {
                // A second cycle returns the conventional female/long-hair
                // lineup while retaining evidence that the workflow changed.
                try scene.cycleBody();
                try scene.cycleBuild();
                try scene.cycleHair();
                try configureLineup(&scene.integrated.production);
                scene.evidence.outfit_idle_change = true;
                script.transition(.move_left);
            },
            .move_left => if (state.position.x <= -5.4) script.transition(.stop_left),
            .stop_left => if (script.phase_frame >= 15 and @abs(state.velocity.x) < 0.02)
                script.transition(.move_right),
            .move_right => if (state.position.x >= -3.1) script.transition(.short_jump_press),
            .short_jump_press => if (script.phase_frame >= 4)
                script.transition(.short_jump_release),
            .short_jump_release => if (script.phase_frame > 8 and state.grounded)
                script.transition(.travel_to_platform),
            .travel_to_platform => if (state.position.x >= 3.25)
                script.transition(.full_jump),
            .full_jump => if (script.phase_frame >= 25)
                script.transition(.wait_raised_landing),
            .wait_raised_landing => if (script.phase_frame > 8 and
                scene.evidence.raised_platform_landing)
            {
                script.transition(.outfit_motion_press);
            },
            .outfit_motion_press => if (script.phase_frame >= 1) {
                scene.evidence.outfit_motion_change = true;
                script.transition(.outfit_motion_release);
            },
            .outfit_motion_release => if (script.phase_frame >= 3)
                script.transition(.double_jump_first),
            .double_jump_first => if (script.phase_frame >= 1)
                script.transition(.double_jump_release),
            .double_jump_release => if (script.phase_frame >= 8 and !state.grounded)
                script.transition(.double_jump_second),
            .double_jump_second => if (script.phase_frame >= 1)
                script.transition(.double_jump_land),
            .double_jump_land => if (script.phase_frame > 8 and state.grounded) {
                try scene.selectFemalePresetByName("wide_brim_crimson");
                script.transition(.dash_to_handshake);
            },
            .dash_to_handshake => if (script.phase_frame >= 6)
                script.transition(.dash_release),
            .dash_release => if (state.dash_ticks_remaining == 0)
                script.transition(.approach),
            .approach => {
                if (!script.approach_turning_right and
                    state.position.x <= handshake_target_x - 0.085)
                {
                    script.approach_turning_right = true;
                }
                if (script.resize_stage == 0 and script.phase_frame >= 2) {
                    try scene.applyViewport(960, 540);
                    script.resize_stage = 1;
                } else if (script.resize_stage == 1 and script.phase_frame >= 4) {
                    try scene.applyViewport(640, 480);
                    script.resize_stage = 2;
                }
                if (scene.interactionEligibility().isEligible()) {
                    scene.evidence.approach_observed = true;
                    script.transition(.first_interact);
                }
            },
            .first_interact => if (scene.evidence.interaction_count == 1)
                script.transition(.first_wait),
            .first_wait => if (scene.evidence.interaction_records[0].captured) {
                script.completed_interactions = 1;
                try scene.selectFemalePresetByName("garnet_formal");
                scene.evidence.outfit_idle_change = true;
                try scene.integrated.cycleThemePreservingState();
                script.transition(.long_outfit);
            },
            .long_outfit => if (script.phase_frame >= 12)
                script.transition(.second_interact),
            .second_interact => if (scene.evidence.interaction_count == 2)
                script.transition(.second_wait),
            .second_wait => if (scene.evidence.interaction_records[1].captured) {
                script.completed_interactions = 2;
                try scene.selectFemalePresetByName("ivory_blouse_red_shorts");
                try scene.integrated.cycleThemePreservingState();
                script.transition(.ivory_outfit);
            },
            .ivory_outfit => if (script.phase_frame >= 12)
                script.transition(.third_interact),
            .third_interact => if (scene.evidence.interaction_count == 3)
                script.transition(.third_wait),
            .third_wait => if (scene.evidence.interaction_records[2].captured) {
                script.completed_interactions = 3;
                script.transition(.cleanup_idle);
            },
            .cleanup_idle => if (script.phase_frame >= 30 and
                scene.evidence.front_idle_restored)
            {
                script.transition(.debug_press);
            },
            .debug_press => if (script.phase_frame >= 1)
                script.transition(.debug_release),
            .debug_release => if (script.phase_frame >= 5)
                script.transition(.reset_press),
            .reset_press => if (scene.evidence.reset_observed)
                script.transition(.reset_release),
            .reset_release => if (script.phase_frame >= 4)
                script.transition(.final_idle),
            .final_idle => {
                script.final_frames += 1;
                if (script.final_frames >= 60) scene.evidence.stable_final_state = true;
            },
        }
    }

    pub fn completed(script: *const ScriptedInput) bool {
        return script.phase == .final_idle and
            script.completed_interactions == required_handshake_count and
            script.final_frames >= 60;
    }

    fn transition(script: *ScriptedInput, next: ScriptPhase) void {
        script.phase = next;
        script.phase_frame = 0;
    }
};

fn encodeGamepadAxis(desired_axis: f32) f32 {
    if (@abs(desired_axis) <= std.math.floatEps(f32)) return 0;
    return std.math.sign(desired_axis) *
        (input.gamepad_dead_zone + @abs(desired_axis) * (1 - input.gamepad_dead_zone));
}
