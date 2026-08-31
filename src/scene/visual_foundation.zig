const std = @import("std");
const foundation_evidence = @import("foundation_evidence");
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
const foundation_world = @import("foundation_world");
const wardrobe_catalog = @import("wardrobe_catalog");
const wardrobe_demo = @import("wardrobe_demo");
const render_queue = @import("render_queue");
const debug_draw = @import("debug_draw");
const camera2d = @import("camera2d");
const visual_geometry = @import("visual_geometry");
const visual_geometry_overlay = @import("visual_geometry_overlay");
const visual_truth = @import("visual_truth");
const foundation_coherence = @import("foundation_coherence");
const modular_humanoid = @import("modular_humanoid");

pub const required_frames: u32 = 2_400;
pub const character_count: u32 = 2;
pub const mesh_definition_count: usize = environment_demo.mesh_definition_count;
pub const configured_texture_page_count: u32 = environment_demo.configured_texture_page_count;
pub const required_handshake_count: usize = 3;
pub const handshake_target_x: f32 =
    foundation_world.partner_spawn.x - handshake.authored_horizontal_separation;
pub const raised_platform_collider: u32 = 4;
pub const partner_clear_x: f32 = 12;
pub const partner_route_speed_mps: f32 = 3;
pub const coherence_marker_size_m: f32 = 7.0 / 82.0;
pub const coherence_line_thickness_m: f32 = 2.0 / 82.0;
pub const coherence_surface_color: [4]f32 = .{
    11.0 / 255.0,
    239.0 / 255.0,
    239.0 / 255.0,
    1,
};
pub const coherence_safe_top_color: [4]f32 = .{
    247.0 / 255.0,
    13.0 / 255.0,
    167.0 / 255.0,
    1,
};
pub const coherence_safe_bottom_color: [4]f32 = .{
    31.0 / 255.0,
    241.0 / 255.0,
    71.0 / 255.0,
    1,
};
pub const coherence_parallax_colors = [3][4]f32{
    .{ 3.0 / 255.0, 251.0 / 255.0, 113.0 / 255.0, 1 },
    .{ 17.0 / 255.0, 89.0 / 255.0, 253.0 / 255.0, 1 },
    .{ 241.0 / 255.0, 29.0 / 255.0, 197.0 / 255.0, 1 },
};
pub const coherence_sole_colors = [4][4]f32{
    .{ 251.0 / 255.0, 47.0 / 255.0, 23.0 / 255.0, 1 },
    .{ 83.0 / 255.0, 253.0 / 255.0, 37.0 / 255.0, 1 },
    .{ 37.0 / 255.0, 71.0 / 255.0, 251.0 / 255.0, 1 },
    .{ 251.0 / 255.0, 211.0 / 255.0, 19.0 / 255.0, 1 },
};
pub const coherence_bounds_top_color: [4]f32 = .{
    199.0 / 255.0,
    59.0 / 255.0,
    251.0 / 255.0,
    1,
};
pub const coherence_bounds_bottom_color: [4]f32 = .{
    239.0 / 255.0,
    137.0 / 255.0,
    53.0 / 255.0,
    1,
};

pub const RegistrationProofCase = enum(u8) {
    body_front,
    body_side_left,
    body_side_right,
    equipped_front,
    equipped_side_left,
    equipped_side_right,

    pub fn parse(text: []const u8) !RegistrationProofCase {
        inline for (std.meta.fields(RegistrationProofCase)) |field| {
            const value: RegistrationProofCase = @enumFromInt(field.value);
            if (std.mem.eql(u8, text, value.cliName())) return value;
        }
        return error.UnknownRegistrationProofCase;
    }

    pub fn cliName(value: RegistrationProofCase) []const u8 {
        return switch (value) {
            .body_front => "body-front",
            .body_side_left => "body-side-left",
            .body_side_right => "body-side-right",
            .equipped_front => "equipped-front",
            .equipped_side_left => "equipped-side-left",
            .equipped_side_right => "equipped-side-right",
        };
    }

    pub fn bodyOnly(value: RegistrationProofCase) bool {
        return switch (value) {
            .body_front, .body_side_left, .body_side_right => true,
            .equipped_front, .equipped_side_left, .equipped_side_right => false,
        };
    }

    pub fn view(value: RegistrationProofCase) presentation_view.View {
        return switch (value) {
            .body_front, .equipped_front => .front,
            .body_side_left,
            .body_side_right,
            .equipped_side_left,
            .equipped_side_right,
            => .side,
        };
    }

    pub fn facing(value: RegistrationProofCase) humanoid.Facing {
        return switch (value) {
            .body_side_left, .equipped_side_left => .left,
            .body_front,
            .body_side_right,
            .equipped_front,
            .equipped_side_right,
            => .right,
        };
    }
};

pub const ComponentProofCase = enum(u8) {
    eye_eyebrow,
    scalp_hair,
    extra_arm,
    continuous,
    intentional_gap,
    front,
    side_left,
    side_right,
    disabled,
    continuous_front,
    intentional_gap_front,
    continuous_side_left,
    continuous_side_right,
    intentional_gap_side_left,
    intentional_gap_side_right,
    two_modules,

    pub fn parse(text: []const u8) !ComponentProofCase {
        inline for (std.meta.fields(ComponentProofCase)) |field| {
            const value: ComponentProofCase = @enumFromInt(field.value);
            if (std.mem.eql(u8, text, value.cliName())) return value;
        }
        return error.UnknownComponentProofCase;
    }

    pub fn cliName(value: ComponentProofCase) []const u8 {
        return switch (value) {
            .eye_eyebrow => "eye-eyebrow",
            .scalp_hair => "scalp-hair",
            .extra_arm => "extra-arm",
            .continuous => "continuous",
            .intentional_gap => "intentional-gap",
            .front => "front",
            .side_left => "side-left",
            .side_right => "side-right",
            .disabled => "disabled",
            .continuous_front => "continuous-front",
            .intentional_gap_front => "intentional-gap-front",
            .continuous_side_left => "continuous-side-left",
            .continuous_side_right => "continuous-side-right",
            .intentional_gap_side_left => "intentional-gap-side-left",
            .intentional_gap_side_right => "intentional-gap-side-right",
            .two_modules => "two-modules",
        };
    }

    pub fn usesNonstandardMale(value: ComponentProofCase) bool {
        return switch (value) {
            .extra_arm,
            .continuous,
            .intentional_gap,
            .continuous_front,
            .intentional_gap_front,
            .continuous_side_left,
            .continuous_side_right,
            .intentional_gap_side_left,
            .intentional_gap_side_right,
            .two_modules,
            => true,
            .eye_eyebrow,
            .scalp_hair,
            .front,
            .side_left,
            .side_right,
            .disabled,
            => false,
        };
    }

    pub fn view(value: ComponentProofCase) presentation_view.View {
        return switch (value) {
            .side_left,
            .side_right,
            .continuous_side_left,
            .continuous_side_right,
            .intentional_gap_side_left,
            .intentional_gap_side_right,
            => .side,
            else => .front,
        };
    }

    pub fn facing(value: ComponentProofCase) humanoid.Facing {
        return switch (value) {
            .side_left,
            .continuous_side_left,
            .intentional_gap_side_left,
            => .left,
            else => .right,
        };
    }

    pub fn rootContract(
        value: ComponentProofCase,
    ) modular_humanoid.OptionalArmRootContract {
        return switch (value) {
            .intentional_gap_front,
            .intentional_gap_side_left,
            .intentional_gap_side_right,
            => .primary_intentional_gap,
            .continuous_front,
            .continuous_side_left,
            .continuous_side_right,
            => .primary_continuous,
            else => .standard,
        };
    }

    fn maleBodyPreset(value: ComponentProofCase) []const u8 {
        return switch (value) {
            .extra_arm,
            .continuous,
            .intentional_gap,
            => "nonstandard_humanoid",
            .continuous_front,
            .intentional_gap_front,
            .continuous_side_left,
            .continuous_side_right,
            .intentional_gap_side_left,
            .intentional_gap_side_right,
            => "optional_arm_primary_proof",
            .two_modules => "optional_arm_two_module_proof",
            else => "conventional_male",
        };
    }
};

pub const TimeMode = enum(u8) {
    normal,
    quarter_speed,
    paused,
};

pub const DebugMode = visual_truth.Mode;

pub const PresenceValidationPolicy = enum(u8) {
    /// Ordinary interactive play measures and exposes overlap without making
    /// the Prompt 27B acceptance ruler a simulation invariant.
    measure_only,
    /// Scripted acceptance/reporting routes fail closed on the unchanged
    /// Prompt 27B ordinary and interaction thresholds.
    enforce_acceptance,
};

pub const PresenceMeasurement = struct {
    render_frame: u64,
    simulation_tick: u64,
    female_position: math.Vec2,
    male_position: math.Vec2,
    overlap_ratio: f32,
    interaction_context: bool,
    passes_acceptance: bool,
};

const PartnerMotion = enum(u8) {
    stopped,
    moving_left,
    moving_right,
};

pub const ScriptPhase = foundation_evidence.Stage;

pub const ThemeTransitionEvidence = struct {
    count: u32 = 0,
    changed: bool = false,
    fingerprint_unchanged: bool = false,
    root_delta_m: f32 = 0,
    camera_delta_m: f32 = 0,
};

pub const FramePhysicsEvidence = struct {
    landed: bool = false,
    landing_support: ?u16 = null,
};

pub const RenderObservationInput = struct {
    render_frame: u32,
    texture_pages: u32,
    submitted_sprites: u32,
    submitted_meshes: u32,
    sprite_ranges: u32,
    mesh_ranges: u32,
    gpu_resource_creations: u64,
    steady_update_allocations: u64,
    steady_submission_allocations: u64,
    steady_queue_allocations: u64,
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
    maximum_ordinary_overlap_ratio: f32 = 0,
    maximum_interaction_overlap_ratio: f32 = 0,
    maximum_controlled_root_step_m: f32 = 0,
    maximum_passive_root_step_m: f32 = 0,
    presence_violation_count: u64 = 0,
};

pub const Scene = struct {
    allocator: std.mem.Allocator,
    diagnostic_allocator: std.mem.Allocator,
    integrated: environment_demo.Scene,
    manager: interaction_system.Manager,
    presence_validation_policy: PresenceValidationPolicy,
    latest_presence: ?PresenceMeasurement = null,
    time_mode: TimeMode = .normal,
    debug_mode: DebugMode = .off,
    manual_capture_pending: bool = false,
    manual_capture_request_count: u64 = 0,
    body_cycle_index: u8 = 0,
    build_cycle_index: u8 = 0,
    hair_cycle_index: u8 = 0,
    active_interaction: interaction_system.InteractionId = .invalid,
    last_terminal_id: interaction_system.InteractionId = .invalid,
    interaction_root_a: ?math.Vec2 = null,
    interaction_root_b: ?math.Vec2 = null,
    interaction_record_index: ?usize = null,
    initial_breathing_sample: f32,
    last_grounded_y: f32 = foundation_world.player_spawn.y,
    frame_physics: FramePhysicsEvidence = .{},
    theme_transition: ThemeTransitionEvidence = .{},
    debug_commands: *debug_draw.CommandBuffer,
    truth_alpha_catalog: visual_geometry_overlay.AlphaCatalog,
    truth_snapshot: *visual_truth.Snapshot,
    truth_snapshot_valid: bool = false,
    truth_category_counts: visual_truth.CategoryCounts = .{},
    visual_trace: *visual_geometry.Trace,
    parallax_trace: environment_theme.ParallaxTrace = .{},
    female_ground_alignment_y: f32 = 0,
    male_ground_alignment_y: f32 = 0,
    viewport_recenter_pending: bool = false,
    partner_motion: PartnerMotion = .stopped,
    partner_motion_target_x: f32 = foundation_world.partner_spawn.x,
    debug_counts: foundation_evidence.DebugCounts = .{},
    debug_enabled_ticks: u32 = 0,
    reset_generation: u32 = 0,
    evidence: Evidence = .{},
    component_proof_root_contract: modular_humanoid.OptionalArmRootContract = .standard,

    pub fn init(
        allocator: std.mem.Allocator,
        presence_validation_policy: PresenceValidationPolicy,
    ) !Scene {
        return initWithDiagnosticAllocator(
            allocator,
            allocator,
            presence_validation_policy,
        );
    }

    pub fn initWithDiagnosticAllocator(
        allocator: std.mem.Allocator,
        diagnostic_allocator: std.mem.Allocator,
        presence_validation_policy: PresenceValidationPolicy,
    ) !Scene {
        return initWithDiagnosticAllocatorAndComponentProof(
            allocator,
            diagnostic_allocator,
            presence_validation_policy,
            null,
        );
    }

    pub fn initWithDiagnosticAllocatorAndComponentProof(
        allocator: std.mem.Allocator,
        diagnostic_allocator: std.mem.Allocator,
        presence_validation_policy: PresenceValidationPolicy,
        component_proof_case: ?ComponentProofCase,
    ) !Scene {
        const root_contract = if (component_proof_case) |proof_case|
            proof_case.rootContract()
        else
            modular_humanoid.OptionalArmRootContract.standard;
        var integrated =
            try environment_demo.Scene.initWithOptionalArmRootContract(
                allocator,
                root_contract,
            );
        errdefer integrated.deinit();
        try integrated.production.male.setFacing(.left);
        try configureLineup(&integrated.production);
        const manager = interaction_system.Manager.initWithIk(
            try handshake.definition(&integrated.production.animations),
        );
        const truth_alpha_catalog =
            try visual_geometry_overlay.AlphaCatalog.init(diagnostic_allocator);
        const truth_snapshot =
            try diagnostic_allocator.create(visual_truth.Snapshot);
        errdefer diagnostic_allocator.destroy(truth_snapshot);
        const debug_commands =
            try diagnostic_allocator.create(debug_draw.CommandBuffer);
        errdefer diagnostic_allocator.destroy(debug_commands);
        const visual_trace =
            try diagnostic_allocator.create(visual_geometry.Trace);
        errdefer diagnostic_allocator.destroy(visual_trace);
        debug_commands.count = 0;
        debug_commands.overflow_count = 0;
        debug_commands.submission_allocations = 0;
        visual_trace.* = .{};
        var scene = Scene{
            .allocator = allocator,
            .diagnostic_allocator = diagnostic_allocator,
            .integrated = integrated,
            .manager = manager,
            .presence_validation_policy = presence_validation_policy,
            .initial_breathing_sample = try integrated.production.female.breathingSample(),
            .truth_alpha_catalog = truth_alpha_catalog,
            .truth_snapshot = truth_snapshot,
            .debug_commands = debug_commands,
            .visual_trace = visual_trace,
            .component_proof_root_contract = root_contract,
        };
        scene.evidence.white_surface_count = @intCast(scene.integrated.environment.surfaces.count);
        scene.observePresentation();
        return scene;
    }

    pub fn deinit(scene: *Scene) void {
        scene.integrated.deinit();
        scene.diagnostic_allocator.destroy(scene.visual_trace);
        scene.diagnostic_allocator.destroy(scene.debug_commands);
        scene.diagnostic_allocator.destroy(scene.truth_snapshot);
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
        scene.frame_physics = .{};
        if (snapshot.reset.pressed) {
            try scene.resetWorld();
            scene.evidence.reset_observed = true;
            scene.integrated.production.frame_index +|= 1;
            return;
        }
        if (snapshot.debug_toggle.pressed) {
            scene.setDebugMode(scene.debug_mode.next());
        }
        if (snapshot.manual_debug_capture.pressed) {
            try scene.requestManualDebugCapture();
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
            const before_theme = scene.integrated.environment.active_theme;
            const before_root = scene.integrated.production.female.worldPosition();
            const before_camera = scene.integrated.camera.center;
            try scene.integrated.cycleThemePreservingState();
            const after = scene.authoritativeInteractionFingerprint();
            const root_delta = scene.integrated.production.female.worldPosition()
                .sub(before_root).length();
            const camera_delta = scene.integrated.camera.center.sub(before_camera).length();
            const unchanged = before == after;
            scene.evidence.theme_invariance = scene.evidence.theme_invariance and unchanged;
            scene.theme_transition = .{
                .count = scene.theme_transition.count +| 1,
                .changed = before_theme != scene.integrated.environment.active_theme,
                .fingerprint_unchanged = unchanged,
                .root_delta_m = root_delta,
                .camera_delta_m = camera_delta,
            };
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
            scene.integrated.production.female.worldPosition().x,
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
                foundation_world.distant_camera_x_factor <
                    foundation_world.midground_camera_x_factor);
        scene.observePresentation();
        scene.integrated.production.frame_index +|= 1;
    }

    fn updateTick(scene: *Scene) !void {
        const production = &scene.integrated.production;
        const previous_female_root = production.female.worldPosition();
        const previous_male_root = production.male.worldPosition();
        const previous_partner_motion = scene.partner_motion;
        const previous_velocity = production.female.controllerSnapshot().?.state.velocity;
        production.simulation_tick = std.math.add(u64, production.simulation_tick, 1) catch
            return error.SimulationTickOverflow;
        const intent_value = production.pending_input.consumeTick();
        const physics = try production.stepFemale(intent_value);
        try production.stepMale();
        try scene.advancePartnerMotion();
        scene.observePhysics(physics);

        const participants_value = scene.participants();
        if (intent_value.interact_pressed) {
            const requested = scene.manager.requestFromIntent(
                production.female.id(),
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
        } else if (scene.manager.lastTerminal()) |terminal| {
            if (terminal.id != scene.last_terminal_id) {
                try scene.observeTerminalInteraction(terminal);
                scene.last_terminal_id = terminal.id;
                scene.active_interaction = .invalid;
            }
        }
        const current_velocity = production.female.controllerSnapshot().?.state.velocity;
        const controlled_step = production.female.worldPosition()
            .sub(previous_female_root)
            .length();
        const passive_step = production.male.worldPosition()
            .sub(previous_male_root)
            .length();
        scene.evidence.maximum_controlled_root_step_m = @max(
            scene.evidence.maximum_controlled_root_step_m,
            controlled_step,
        );
        scene.evidence.maximum_passive_root_step_m = @max(
            scene.evidence.maximum_passive_root_step_m,
            passive_step,
        );
        const maximum_speed = @max(
            previous_velocity.length(),
            current_velocity.length(),
        );
        if (!foundation_coherence.controlledRootStepPasses(
            previous_female_root,
            production.female.worldPosition(),
            maximum_speed,
            @floatCast(fixed_step.fixed_dt_seconds),
        )) return error.UnexplainedControlledRootCorrection;
        if (previous_partner_motion == .stopped) {
            if (passive_step > 0.000001) {
                return error.UnexplainedPassiveRootCorrection;
            }
        } else if (!foundation_coherence.controlledRootStepPasses(
            previous_male_root,
            production.male.worldPosition(),
            partner_route_speed_mps,
            @floatCast(fixed_step.fixed_dt_seconds),
        )) {
            return error.UnboundedPartnerRouteStep;
        }
        try scene.validateSecondaryFinite();
        if (scene.debug_mode == .all_diagnostics) {
            scene.debug_enabled_ticks = std.math.add(
                u32,
                scene.debug_enabled_ticks,
                1,
            ) catch return error.DebugEnabledTickOverflow;
        } else {
            scene.debug_enabled_ticks = 0;
        }
        scene.observePresentation();
    }

    pub fn submit(scene: *Scene, queue: *render_queue.UnifiedRenderQueue) !u32 {
        const before_sprites = queue.frame_metrics.submitted_sprites;
        const before_meshes = queue.frame_metrics.submitted_meshes;
        const detailed_debug_before = scene.integrated.detailed_debug_enabled;
        if (scene.manual_capture_pending) {
            scene.integrated.detailed_debug_enabled = false;
        }
        defer scene.integrated.detailed_debug_enabled = detailed_debug_before;
        scene.visual_trace.begin();
        scene.parallax_trace.begin();
        var submitted = try scene.integrated.submitTraced(
            queue,
            scene.visual_trace,
            &scene.parallax_trace,
        );
        try scene.applyGroundAlignment(queue);
        try scene.applyCameraSafeRegion();
        try scene.measureCharacterPresence();
        scene.debug_counts = .{};
        scene.truth_snapshot_valid = false;
        scene.truth_category_counts = .{};
        if (scene.debug_mode != .off or scene.manual_capture_pending) {
            try scene.buildTruthSnapshot();
        }
        if (scene.debug_mode != .off and !scene.manual_capture_pending) {
            scene.truth_category_counts = try scene.truth_snapshot.buildOverlay(
                scene.debug_mode,
                scene.debug_commands,
            );
            if (scene.debug_mode == .all_diagnostics) {
                scene.debug_counts.collider =
                    @as(u32, @intCast(scene.integrated.production.world.colliders.len)) * 4;
                try scene.appendLegacyDiagnosticCommands();
            }
            submitted += try scene.debug_commands.submitUnified(queue);
        } else {
            scene.debug_commands.beginFrame();
        }
        if (scene.debug_mode == .all_diagnostics and !scene.manual_capture_pending) {
            scene.debug_counts.collider =
                @as(u32, @intCast(scene.integrated.production.world.colliders.len)) * 4;
            submitted += try scene.submitCoherenceEvidence(queue);
        }
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

    pub fn setDebugMode(scene: *Scene, mode: DebugMode) void {
        scene.debug_mode = mode;
        scene.integrated.detailed_debug_enabled = mode == .all_diagnostics;
    }

    pub fn takeManualCaptureRequest(scene: *Scene) bool {
        const pending = scene.manual_capture_pending;
        scene.manual_capture_pending = false;
        return pending;
    }

    /// Queues the same frame-level diagnostic event as an F4 press. This
    /// exists for deterministic evidence automation and deliberately bypasses
    /// CharacterIntent and authoritative simulation.
    pub fn requestManualDebugCapture(scene: *Scene) !void {
        if (scene.manual_capture_pending) {
            return error.ManualCaptureRequestAlreadyPending;
        }
        scene.manual_capture_pending = true;
        scene.manual_capture_request_count = std.math.add(
            u64,
            scene.manual_capture_request_count,
            1,
        ) catch return error.ManualCaptureRequestOverflow;
    }

    pub fn bindTruthRenderFrame(scene: *Scene, render_frame: u64) !void {
        if (!scene.truth_snapshot_valid) return error.VisualTruthSnapshotUnavailable;
        scene.truth_snapshot.bindRenderFrame(render_frame);
    }

    pub fn refreshTruthSnapshot(
        scene: *Scene,
        render_frame: u64,
    ) !void {
        try scene.buildTruthSnapshot();
        scene.truth_snapshot.bindRenderFrame(render_frame);
    }

    /// Appends the capture-only All Diagnostics overlay to the clean queue.
    /// It consumes the frozen truth snapshot built during the same submit and
    /// does not advance or mutate any authoritative state.
    pub fn submitManualTruthOverlay(
        scene: *Scene,
        queue: *render_queue.UnifiedRenderQueue,
    ) !u32 {
        if (!scene.truth_snapshot_valid) return error.VisualTruthSnapshotUnavailable;
        const before = scene.authoritativeInteractionFingerprint();
        scene.truth_category_counts = try scene.truth_snapshot.buildOverlay(
            .all_diagnostics,
            scene.debug_commands,
        );
        try scene.appendLegacyDiagnosticCommands();
        for (scene.integrated.production.world.colliders) |static_collider| {
            try scene.debug_commands.addAabb(
                static_collider.bounds,
                if (static_collider.ground_query_eligible)
                    .{ 0.10, 0.92, 1.0, 0.88 }
                else
                    .{ 1.0, 0.34, 0.12, 0.88 },
            );
        }
        var submitted = try scene.debug_commands.submitUnified(queue);
        submitted += try scene.submitCoherenceEvidence(queue);
        if (before != scene.authoritativeInteractionFingerprint()) {
            return error.VisualTruthOverlayChangedAuthoritativeState;
        }
        return submitted;
    }

    /// Submits diagnostic-only Prompt 27B rulers through the production
    /// UnifiedRenderQueue. The caller captures this augmented queue after the
    /// corresponding clean production frame has already been read back.
    pub fn submitCoherenceEvidence(
        scene: *Scene,
        queue: *render_queue.UnifiedRenderQueue,
    ) !u32 {
        var submitted: u32 = 0;
        const camera = scene.integrated.camera;
        const evidence_visual = scene.integrated.environment.catalog
            .theme(scene.integrated.environment.active_theme)
            .visual(.surface_white);
        const half_width_m =
            @as(f32, @floatFromInt(camera.viewport_width)) * 0.5 /
            camera.pixels_per_meter;
        const half_height_px =
            @as(f32, @floatFromInt(camera.viewport_height)) * 0.5;
        const safe_top_y = camera.center.y +
            (half_height_px - foundation_coherence.minimum_top_headroom_px) /
                camera.pixels_per_meter;
        const safe_bottom_y = camera.center.y -
            (half_height_px - foundation_coherence.minimum_bottom_clearance_px) /
                camera.pixels_per_meter;
        submitted += try submitCoherenceLine(
            queue,
            .{ .x = camera.center.x - half_width_m, .y = safe_top_y },
            .{ .x = camera.center.x + half_width_m, .y = safe_top_y },
            1,
            coherence_safe_top_color,
            evidence_visual.texture_page,
            evidence_visual.uv_rect,
            submitted,
        );
        submitted += try submitCoherenceLine(
            queue,
            .{ .x = camera.center.x - half_width_m, .y = safe_bottom_y },
            .{ .x = camera.center.x + half_width_m, .y = safe_bottom_y },
            1,
            coherence_safe_bottom_color,
            evidence_visual.texture_page,
            evidence_visual.uv_rect,
            submitted,
        );

        const female = &scene.integrated.production.female;
        const controller = female.controllerSnapshot().?.state;
        if (controller.grounded) {
            const support_id = controller.supporting_collider orelse
                return error.GroundedCharacterMissingSupport;
            const support_y = try scene.supportingTop(support_id);
            const bounds = try foundation_coherence.traceCharacterBounds(
                scene.visual_trace,
                female.id().raw(),
            );
            submitted += try submitCoherenceLine(
                queue,
                .{ .x = bounds.world.minimum.x - 0.4, .y = support_y },
                .{ .x = bounds.world.maximum.x + 0.4, .y = support_y },
                1,
                coherence_surface_color,
                evidence_visual.texture_page,
                evidence_visual.uv_rect,
                submitted,
            );
            const sides = [_]visual_geometry.Side{ .left, .right };
            for (sides, 0..) |side, side_index| {
                const record = scene.outermostFootVisual(
                    female.id().raw(),
                    side,
                ) orelse return error.MissingGroundContactVisual;
                const heel = try foundation_coherence.alphaTightLandmarkWorld(
                    record,
                    .sole_back,
                );
                const toe = try foundation_coherence.alphaTightLandmarkWorld(
                    record,
                    .sole_front,
                );
                submitted += try submitCoherenceMarker(
                    queue,
                    heel,
                    1,
                    coherence_sole_colors[side_index * 2],
                    evidence_visual.texture_page,
                    evidence_visual.uv_rect,
                    submitted,
                );
                submitted += try submitCoherenceMarker(
                    queue,
                    toe,
                    1,
                    coherence_sole_colors[side_index * 2 + 1],
                    evidence_visual.texture_page,
                    evidence_visual.uv_rect,
                    submitted,
                );
            }
        }

        try scene.parallax_trace.validateComplete();
        for (scene.parallax_trace.anchors, 0..) |anchor, index| {
            submitted += try submitCoherenceMarker(
                queue,
                anchor.world,
                anchor.camera_x_factor,
                coherence_parallax_colors[index],
                evidence_visual.texture_page,
                evidence_visual.uv_rect,
                submitted,
            );
        }
        return submitted;
    }

    /// Adds alpha-derived character top/bottom markers to the ordinary
    /// coherence rulers for the first frame after the direct Prompt 27B
    /// 960x540 -> 640x480 viewport transition.
    pub fn submitAbruptResizeEvidence(
        scene: *Scene,
        queue: *render_queue.UnifiedRenderQueue,
    ) !u32 {
        var submitted = try scene.submitCoherenceEvidence(queue);
        const female = &scene.integrated.production.female;
        const bounds = try foundation_coherence.traceCharacterBounds(
            scene.visual_trace,
            female.id().raw(),
        );
        const evidence_visual = scene.integrated.environment.catalog
            .theme(scene.integrated.environment.active_theme)
            .visual(.surface_white);
        const marker_x = bounds.world.minimum.x - 0.15;
        submitted += try submitCoherenceMarker(
            queue,
            .{ .x = marker_x, .y = bounds.world.maximum.y },
            1,
            coherence_bounds_top_color,
            evidence_visual.texture_page,
            evidence_visual.uv_rect,
            submitted,
        );
        submitted += try submitCoherenceMarker(
            queue,
            .{ .x = marker_x, .y = bounds.world.minimum.y },
            1,
            coherence_bounds_bottom_color,
            evidence_visual.texture_page,
            evidence_visual.uv_rect,
            submitted,
        );
        return submitted;
    }

    fn outermostFootVisual(
        scene: *const Scene,
        character_id: u32,
        side: visual_geometry.Side,
    ) ?visual_geometry.TraceRecord {
        var result: ?visual_geometry.TraceRecord = null;
        for (scene.visual_trace.slice()) |record| {
            if (record.character_id != character_id or
                !record.isRendered() or
                record.side != side or
                (record.role != .foot and record.role != .shoe))
            {
                continue;
            }
            if (result == null or
                record.request.order.body_part_layer >
                    result.?.request.order.body_part_layer)
            {
                result = record;
            }
        }
        return result;
    }

    fn submitCoherenceMarker(
        queue: *render_queue.UnifiedRenderQueue,
        world: math.Vec2,
        camera_x_factor: f32,
        color: [4]f32,
        texture_page: u32,
        uv_rect: [4]f32,
        order_index: u32,
    ) !u32 {
        if (!world.isFinite()) return error.NonFiniteCoherenceMarker;
        _ = try queue.submitSprite(.{
            .world_position = world.toArray(),
            .rotation = 0,
            .scale = .{ coherence_marker_size_m, coherence_marker_size_m },
            .pivot = .{ 0.5, 0.5 },
            .uv_rect = uv_rect,
            .tint = color,
            .texture_page = texture_page,
            .camera_x_factor = camera_x_factor,
            .order = .{
                .scene_layer = character.SceneLayers.debug_overlay,
                .interaction_layer = 0,
                .actor_layer = 0,
                .body_part_layer = @intCast(order_index),
            },
        });
        return 1;
    }

    fn submitCoherenceLine(
        queue: *render_queue.UnifiedRenderQueue,
        from_world: math.Vec2,
        to_world: math.Vec2,
        camera_x_factor: f32,
        color: [4]f32,
        texture_page: u32,
        uv_rect: [4]f32,
        order_index: u32,
    ) !u32 {
        if (!from_world.isFinite() or !to_world.isFinite()) {
            return error.NonFiniteCoherenceLine;
        }
        const delta = to_world.sub(from_world);
        const length = delta.length();
        if (length <= std.math.floatEps(f32)) {
            return submitCoherenceMarker(
                queue,
                from_world,
                camera_x_factor,
                color,
                texture_page,
                uv_rect,
                order_index,
            );
        }
        _ = try queue.submitSprite(.{
            .world_position = from_world.toArray(),
            .rotation = std.math.atan2(delta.y, delta.x),
            .scale = .{ length, coherence_line_thickness_m },
            .pivot = .{ 0, 0.5 },
            .uv_rect = uv_rect,
            .tint = color,
            .texture_page = texture_page,
            .camera_x_factor = camera_x_factor,
            .order = .{
                .scene_layer = character.SceneLayers.debug_overlay,
                .interaction_layer = 0,
                .actor_layer = 0,
                .body_part_layer = @intCast(order_index),
            },
        });
        return 1;
    }

    fn applyGroundAlignment(
        scene: *Scene,
        queue: *render_queue.UnifiedRenderQueue,
    ) !void {
        const production = &scene.integrated.production;
        const female_controller = production.female.controllerSnapshot() orelse
            return error.CharacterHasNoController;
        if (female_controller.state.grounded) {
            const support_id = female_controller.state.supporting_collider orelse
                return error.GroundedCharacterMissingSupport;
            const support_y = try scene.supportingTop(support_id);
            const female_feet = production.female.footPlantingSnapshot();
            const left_locked = female_feet.left.hasLock();
            const right_locked = female_feet.right.hasLock();
            const alignment = try foundation_coherence.groundAlignment(
                scene.visual_trace,
                production.female.id().raw(),
                support_y,
                if (left_locked or right_locked) left_locked else true,
                if (left_locked or right_locked) right_locked else true,
            );
            if (alignment.applicable) {
                scene.female_ground_alignment_y = alignment.translation_y;
            }
        }
        const male_feet = production.male.footPlantingSnapshot();
        const male_alignment = try foundation_coherence.groundAlignment(
            scene.visual_trace,
            production.male.id().raw(),
            0,
            if (male_feet.left.hasLock() or male_feet.right.hasLock())
                male_feet.left.hasLock()
            else
                true,
            if (male_feet.left.hasLock() or male_feet.right.hasLock())
                male_feet.right.hasLock()
            else
                true,
        );
        if (male_alignment.applicable) {
            scene.male_ground_alignment_y = male_alignment.translation_y;
        }
        try foundation_coherence.translateCharacterSubmissions(
            queue,
            scene.visual_trace,
            production.female.id().raw(),
            .{ .x = 0, .y = scene.female_ground_alignment_y },
        );
        try foundation_coherence.translateCharacterSubmissions(
            queue,
            scene.visual_trace,
            production.male.id().raw(),
            .{ .x = 0, .y = scene.male_ground_alignment_y },
        );
    }

    fn applyCameraSafeRegion(scene: *Scene) !void {
        const production = &scene.integrated.production;
        const female = try foundation_coherence.traceCharacterBounds(
            scene.visual_trace,
            production.female.id().raw(),
        );
        if (scene.viewport_recenter_pending) {
            const nearest = try foundation_coherence.applyVerticalSafeRegion(
                &scene.integrated.camera,
                female.world,
            );
            // A drawable change alone cannot move the camera. Balance the
            // interval only when this frame's submitted bounds independently
            // required a safe-region correction.
            if (nearest.delta_px > 0) {
                _ = try foundation_coherence.centerVerticalSafeRegion(
                    &scene.integrated.camera,
                    female.world,
                );
            }
            scene.viewport_recenter_pending = false;
        } else {
            _ = try foundation_coherence.applyVerticalSafeRegion(
                &scene.integrated.camera,
                female.world,
            );
        }
    }

    fn measureCharacterPresence(scene: *Scene) !void {
        const production = &scene.integrated.production;
        const female = try foundation_coherence.traceCharacterPresenceBounds(
            scene.visual_trace,
            production.female.id().raw(),
        );
        const male = try foundation_coherence.traceCharacterPresenceBounds(
            scene.visual_trace,
            production.male.id().raw(),
        );
        const ratio = try foundation_coherence.overlapRatio(
            female.world,
            male.world,
        );
        const interaction_active = scene.presenceInteractionContext();
        if (interaction_active) {
            scene.evidence.maximum_interaction_overlap_ratio = @max(
                scene.evidence.maximum_interaction_overlap_ratio,
                ratio,
            );
        } else {
            scene.evidence.maximum_ordinary_overlap_ratio = @max(
                scene.evidence.maximum_ordinary_overlap_ratio,
                ratio,
            );
        }
        const measurement = PresenceMeasurement{
            .render_frame = production.frame_index,
            .simulation_tick = production.simulation_tick,
            .female_position = production.female.worldPosition(),
            .male_position = production.male.worldPosition(),
            .overlap_ratio = ratio,
            .interaction_context = interaction_active,
            .passes_acceptance = foundation_coherence.overlapPasses(
                ratio,
                interaction_active,
            ),
        };
        scene.latest_presence = measurement;
        if (!measurement.passes_acceptance) {
            scene.evidence.presence_violation_count = std.math.add(
                u64,
                scene.evidence.presence_violation_count,
                1,
            ) catch return error.PresenceViolationCountOverflow;
        }
        enforcePresenceMeasurement(
            measurement,
            scene.presence_validation_policy,
        ) catch |err| {
            std.log.err(
                "character presence acceptance failed: frame={d} tick={d} ratio={d:.6} interaction_context={} female=({d:.6},{d:.6}) male=({d:.6},{d:.6}) policy={s}",
                .{
                    measurement.render_frame,
                    measurement.simulation_tick,
                    measurement.overlap_ratio,
                    measurement.interaction_context,
                    measurement.female_position.x,
                    measurement.female_position.y,
                    measurement.male_position.x,
                    measurement.male_position.y,
                    @tagName(scene.presence_validation_policy),
                },
            );
            return err;
        };
    }

    pub fn presenceInteractionContext(scene: *const Scene) bool {
        return scene.manager.activeCount() != 0;
    }

    fn supportingTop(scene: *const Scene, collider_id: u16) !f32 {
        for (scene.integrated.production.world.colliders) |static_collider| {
            if (static_collider.id == collider_id) {
                return static_collider.bounds.maximum.y;
            }
        }
        return error.MissingSupportingCollider;
    }

    fn startPartnerMotion(scene: *Scene, target_x: f32) !void {
        if (!std.math.isFinite(target_x)) return error.NonFinitePartnerRouteTarget;
        const male = &scene.integrated.production.male;
        const difference = target_x - male.worldPosition().x;
        if (@abs(difference) <= 0.000001) {
            scene.partner_motion = .stopped;
            scene.partner_motion_target_x = target_x;
            return;
        }
        scene.partner_motion = if (difference < 0) .moving_left else .moving_right;
        scene.partner_motion_target_x = target_x;
        try male.setFacing(if (difference < 0) .left else .right);
        try male.enterAnimationState(.walk);
    }

    fn advancePartnerMotion(scene: *Scene) !void {
        if (scene.partner_motion == .stopped) return;
        const male = &scene.integrated.production.male;
        const difference = scene.partner_motion_target_x - male.worldPosition().x;
        const maximum_step =
            partner_route_speed_mps * @as(f32, @floatCast(fixed_step.fixed_dt_seconds));
        const step = std.math.clamp(difference, -maximum_step, maximum_step);
        try male.setWorldPosition(.{
            .x = male.worldPosition().x + step,
            .y = male.worldPosition().y,
        });
        if (@abs(scene.partner_motion_target_x - male.worldPosition().x) <= 0.000001) {
            scene.partner_motion = .stopped;
            try male.setFacing(.left);
            try male.enterAnimationState(.idle);
        }
    }

    fn handshakeTargetX(scene: *const Scene) f32 {
        return scene.integrated.production.male.worldPosition().x -
            handshake.authored_horizontal_separation;
    }

    fn buildTruthSnapshot(scene: *Scene) !void {
        try scene.truth_snapshot.build(
            scene.debug_mode,
            scene.integrated.production.frame_index,
            scene.integrated.production.simulation_tick,
            scene.integrated.camera,
            .{
                &scene.integrated.production.female,
                &scene.integrated.production.male,
            },
            .{
                scene.integrated.production.female_art,
                scene.integrated.production.male_art,
            },
            scene.visual_trace,
            &scene.truth_alpha_catalog,
        );
        const production = &scene.integrated.production;
        const preset = try production.catalog.preset(production.current_preset);
        try scene.truth_snapshot.setOutfit(
            production.female.id().raw(),
            preset.stable_id,
            if (production.female.equipmentView()) |loadout|
                loadout.equippedItems().len
            else
                0,
        );
        try scene.truth_snapshot.setOutfit(
            production.male.id().raw(),
            "foundation_male_lineup",
            if (production.male.equipmentView()) |loadout|
                loadout.equippedItems().len
            else
                0,
        );
        scene.truth_snapshot_valid = true;
    }

    fn appendLegacyDiagnosticCommands(scene: *Scene) !void {
        const characters = [_]*const character.CharacterInstance{
            &scene.integrated.production.female,
            &scene.integrated.production.male,
        };
        for (characters) |instance| {
            try scene.debug_commands.addMarker(
                instance.worldPosition(),
                .{ 1, 0.20, 0.20, 1 },
            );
            scene.debug_counts.root += 1;
            const definition = instance.definitionView();
            const humanoid_view = instance.humanoidView();
            const root_index = try definition.skeleton_definition.boneIndex(.root);
            const visual_root = (try humanoid_view.local_and_world_pose.worldForBone(
                &definition.skeleton_definition,
                root_index,
            )).translationPart();
            try scene.debug_commands.addMarker(visual_root, .{ 1, 0.85, 0.10, 1 });
            scene.debug_counts.root += 1;

            const foot_plants = instance.footPlantingSnapshot();
            const feet = .{ &foot_plants.left, &foot_plants.right };
            inline for (feet) |foot| {
                if (foot.last_ground_sample.hit) {
                    const origin = foot.pre_ik_sole.add(.{ .x = 0, .y = 0.12 });
                    try scene.debug_commands.addLine(
                        origin,
                        foot.last_ground_sample.hit_position,
                        .{ 0.20, 1, 0.40, 0.80 },
                    );
                    try scene.debug_commands.addMarker(
                        foot.last_ground_sample.hit_position,
                        .{ 0.20, 1, 0.40, 1 },
                    );
                    scene.debug_counts.ground += 2;
                }
            }
            if (instance.rightHandIkMetrics()) |metrics| {
                try scene.debug_commands.addLine(
                    metrics.shoulder_position,
                    metrics.elbow_position,
                    .{ 1, 0.65, 0.05, 1 },
                );
                try scene.debug_commands.addLine(
                    metrics.elbow_position,
                    metrics.post_ik_hand_position,
                    .{ 1, 0.65, 0.05, 1 },
                );
                try scene.debug_commands.addMarker(
                    metrics.post_ik_hand_position,
                    .{ 1, 1, 0.10, 1 },
                );
                scene.debug_counts.ik += 3;
            }
        }
        if (scene.manager.firstActiveInstance()) |active| {
            if (active.ik.target_valid) {
                try scene.debug_commands.addMarker(
                    active.ik.shared_target,
                    .{ 0.10, 1, 1, 1 },
                );
                scene.debug_counts.ik += 1;
            }
            try scene.debug_commands.addLine(
                scene.integrated.production.female.worldPosition(),
                scene.integrated.production.male.worldPosition(),
                .{ 0.65, 0.25, 1, 0.70 },
            );
            scene.debug_counts.participant_link += 1;
        }
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
        const changed = width != scene.integrated.camera.viewport_width or
            height != scene.integrated.camera.viewport_height;
        try scene.integrated.applyViewport(width, height);
        if (before != scene.authoritativeInteractionFingerprint()) {
            return error.VisualFoundationResizeChangedAuthoritativeState;
        }
        if (changed) {
            scene.viewport_recenter_pending =
                height != camera2d.reference_drawable_height;
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

    pub fn applyRegistrationProofCase(
        scene: *Scene,
        proof_case: RegistrationProofCase,
    ) !void {
        if (scene.integrated.production.frame_index != 0 or
            scene.integrated.production.simulation_tick != 0)
        {
            return error.RegistrationProofCaseMustPrecedeSimulation;
        }
        if (proof_case.bodyOnly()) {
            const base = try scene.integrated.production.catalog.presetId("base_only");
            try scene.integrated.production.selectMalePreset(base);
            try scene.integrated.production.selectPreset(base);
        } else {
            try scene.integrated.production.selectMalePreset(
                try scene.integrated.production.catalog.presetId("scarlet_sport"),
            );
            try scene.integrated.production.selectPreset(
                try scene.integrated.production.catalog.presetId("wide_brim_crimson"),
            );
        }
        const view_override: presentation_view.DebugOverride =
            if (proof_case.view() == .front) .force_front else .force_side;
        const facing = proof_case.facing();
        try scene.integrated.production.male.setFacing(facing);
        try scene.integrated.production.female.stageControlledTransform(
            scene.integrated.production.female.worldPosition(),
            facing,
        );
        try scene.integrated.production.male.setPresentationOverride(view_override);
        try scene.integrated.production.female.setPresentationOverride(view_override);
        scene.observePresentation();
    }

    pub fn applyComponentProofCase(
        scene: *Scene,
        proof_case: ComponentProofCase,
    ) !void {
        if (scene.integrated.production.frame_index != 0 or
            scene.integrated.production.simulation_tick != 0)
        {
            return error.ComponentProofCaseMustPrecedeSimulation;
        }
        const production = &scene.integrated.production;
        const definition = production.definition.anatomy_definition.?.view();
        const base = try production.catalog.presetId("base_only");
        try production.selectMalePreset(base);
        try production.selectPreset(base);
        if (scene.component_proof_root_contract != proof_case.rootContract()) {
            return error.ComponentProofTopologyMismatch;
        }
        try production.male.selectBodyPreset(try definition.bodyPresetId(
            proof_case.maleBodyPreset(),
        ));
        try production.female.selectBodyPreset(
            try definition.bodyPresetId("conventional_female"),
        );
        try production.male.selectHair(try definition.hairDefinitionId(
            if (proof_case.usesNonstandardMale())
                "ponytail"
            else
                "short_rigid",
        ));
        try production.female.selectHair(
            try definition.hairDefinitionId("long_rigid"),
        );

        const view_override: presentation_view.DebugOverride =
            if (proof_case.view() == .front) .force_front else .force_side;
        const facing = proof_case.facing();
        try production.male.setFacing(facing);
        try production.female.stageControlledTransform(production.female.worldPosition(), facing);
        try production.male.setPresentationOverride(view_override);
        try production.female.setPresentationOverride(view_override);
        scene.observePresentation();
    }

    pub fn resetWorld(scene: *Scene) !void {
        const participants_value = scene.participants();
        try scene.manager.reset(&participants_value);
        try scene.integrated.production.female.resetControlled(
            &scene.integrated.production.world,
        );
        try scene.integrated.production.male.reset();
        scene.partner_motion = .stopped;
        scene.partner_motion_target_x = foundation_world.partner_spawn.x;
        try scene.integrated.production.male.setFacing(.left);
        try configureLineup(&scene.integrated.production);
        scene.integrated.production.pending_input.reset();
        scene.integrated.production.clock.reset();
        scene.integrated.production.simulation_tick = 0;
        scene.integrated.production.custom_active = false;
        scene.integrated.production.paused = false;
        scene.integrated.environment.reset();
        try scene.integrated.camera.setCenter(.{
            .x = foundation_world.player_spawn.x,
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
        scene.last_grounded_y = foundation_world.player_spawn.y;
        scene.frame_physics = .{};
        scene.debug_counts = .{};
        scene.debug_enabled_ticks = 0;
        scene.reset_generation = std.math.add(u32, scene.reset_generation, 1) catch
            return error.ResetGenerationOverflow;
    }

    pub fn interactionEligibility(scene: *Scene) interaction_system.Eligibility {
        const participants_value = scene.participants();
        return scene.manager.evaluateEligibility(
            scene.integrated.production.female.id(),
            scene.integrated.production.male.id(),
            &participants_value,
        );
    }

    pub fn validateComplete(scene: *const Scene, script: *const ScriptedInput) !void {
        const evidence = scene.evidence;
        if (!script.completed()) {
            const state = scene.integrated.production.female.controllerSnapshot().?.state;
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
                    @tagName(scene.integrated.production.female.facingDirection()),
                    @tagName(scene.integrated.production.male.facingDirection()),
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
                record.initiator != scene.integrated.production.female.id() or
                record.receiver != scene.integrated.production.male.id() or
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
        const final = scene.integrated.production.female.controllerSnapshot().?.state;
        if (!final.position.approxEqAbs(foundation_world.player_spawn, 0.000001) or
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
        const definition = scene.manager.definitionView();
        scene.evidence.interaction_records[index] = .{
            .id = id,
            .type_id = definition.type_id,
            .initiator = scene.integrated.production.female.id(),
            .receiver = scene.integrated.production.male.id(),
            .outfit = scene.integrated.production.current_preset,
            .theme = scene.integrated.environment.active_theme,
            .requested_initiator_view = definition.presentation.viewForRole(.initiator),
            .requested_receiver_view = definition.presentation.viewForRole(.receiver),
            .start_tick = scene.integrated.production.simulation_tick,
        };
        scene.interaction_record_index = index;
        scene.active_interaction = id;
        scene.interaction_root_a = scene.integrated.production.female.worldPosition();
        scene.interaction_root_b = scene.integrated.production.male.worldPosition();
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
            scene.integrated.production.female.worldPosition().approxEqAbs(
                scene.interaction_root_a.?,
                0.000001,
            ) and
            scene.integrated.production.male.worldPosition().approxEqAbs(
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
        const loadout = production.female.equipmentView() orelse return false;
        const anatomy_definition = production.female.definitionView().anatomy_definition orelse
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
        const loadout = scene.integrated.production.female.equipmentView() orelse
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
        const state = scene.integrated.production.female.controllerSnapshot().?.state;
        scene.evidence.landing_observed = scene.evidence.landing_observed or physics.landed;
        if (physics.landed) {
            scene.frame_physics.landed = true;
            scene.frame_physics.landing_support = state.supporting_collider;
        }
        scene.evidence.raised_platform_landing =
            scene.evidence.raised_platform_landing or
            (physics.landed and state.supporting_collider != null and
                state.supporting_collider.? != 1);
        scene.evidence.dash_observed = scene.evidence.dash_observed or physics.dash_started;
        scene.evidence.double_jump_observed =
            scene.evidence.double_jump_observed or
            (physics.jump_accepted and physics.jump_source == .air);
        if (state.grounded) scene.last_grounded_y = state.position.y;
    }

    fn observePresentation(scene: *Scene) void {
        const production = &scene.integrated.production;
        const state = production.female.controllerSnapshot().?.state;
        const view = production.female.presentationView();
        scene.evidence.initial_front_idle = scene.evidence.initial_front_idle or
            (state.grounded and @abs(state.velocity.x) < 0.0001 and view == .front);
        scene.evidence.walk_left_side = scene.evidence.walk_left_side or
            (state.velocity.x < -0.2 and production.female.facingDirection() == .left and view == .side);
        scene.evidence.stop_front_facing_left =
            scene.evidence.stop_front_facing_left or
            (state.grounded and @abs(state.velocity.x) < 0.02 and
                production.female.facingDirection() == .left and view == .front);
        scene.evidence.walk_right_side = scene.evidence.walk_right_side or
            (state.velocity.x > 0.2 and production.female.facingDirection() == .right and view == .side);
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
            scene.evidence.detailed_debug_observed or
            scene.debug_mode == .all_diagnostics;
        scene.observeLineup();
    }

    fn observeLineup(scene: *Scene) void {
        const production = &scene.integrated.production;
        const anatomy_definition = production.definition.anatomy_definition.?.view();
        const male_runtime = production.male.humanoidView().anatomy_runtime.?;
        const female_runtime = production.female.humanoidView().anatomy_runtime.?;
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
            (production.male.hasEquipment() and
                production.male.equipmentView().?.equippedItems().len > 0);
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

    pub fn authoritativeInteractionFingerprint(scene: *const Scene) u64 {
        var hash = std.hash.Wyhash.init(27);
        const female_world = scene.integrated.production.female.worldPosition();
        const male_world = scene.integrated.production.male.worldPosition();
        hash.update(std.mem.asBytes(&female_world));
        hash.update(std.mem.asBytes(&male_world));
        hash.update(std.mem.asBytes(&scene.integrated.production.simulation_tick));
        const manager_metrics = scene.manager.metricsSnapshot();
        hash.update(std.mem.asBytes(&manager_metrics));
        hash.update(std.mem.asBytes(&scene.active_interaction));
        return hash.final();
    }

    pub fn captureObservation(
        scene: *Scene,
        script: *const ScriptedInput,
        render: RenderObservationInput,
    ) !foundation_evidence.Observation {
        const production = &scene.integrated.production;
        const female = &production.female;
        const male = &production.male;
        const state = female.controllerSnapshot().?.state;
        const anatomy_definition = production.definition.anatomy_definition.?.view();
        const anatomy_runtime = female.anatomyRuntimeSnapshot().?;
        const body = anatomy_definition.body_presets[
            anatomy_runtime.selected_body_preset.index()
        ].stable_id.slice();
        const morphology = anatomy_definition.morphology_presets[
            anatomy_runtime.selected_morphology_preset.index()
        ].stable_id.slice();
        const hair = if (anatomy_runtime.selected_hair) |hair_id|
            anatomy_definition.hair_definitions[hair_id.index()].stable_id.slice()
        else
            "none";
        const outfit = (try production.catalog.preset(production.current_preset)).stable_id;
        const override = female.presentationOverride();
        const presentation_mode: foundation_evidence.PresentationMode =
            if (female.interactionOwnerId() != 0)
                .interaction_owned
            else switch (override) {
                .automatic => .automatic,
                .force_side => .force_side,
                .force_front => .force_front,
            };
        var interaction_id: u32 = 0;
        var interaction_lifecycle: foundation_evidence.InteractionLifecycle = .none;
        var interaction_phase: foundation_evidence.InteractionPhase = .none;
        var interaction_elapsed_ticks: u32 = 0;
        var contact_tick: u64 = 0;
        var release_tick: u64 = 0;
        var complete_tick: u64 = 0;
        var ik_active = false;
        var ordering_valid = false;
        if (scene.manager.firstActiveInstance()) |active| {
            interaction_id = active.id.raw();
            interaction_lifecycle = evidenceLifecycle(active.lifecycle);
            interaction_phase = evidenceInteractionPhase(active.phase);
            interaction_elapsed_ticks = active.elapsed_ticks;
            contact_tick = active.event_ticks[
                @intFromEnum(interaction.EventSemantic.contact)
            ] orelse 0;
            release_tick = active.event_ticks[
                @intFromEnum(interaction.EventSemantic.release)
            ] orelse 0;
            complete_tick = active.event_ticks[
                @intFromEnum(interaction.EventSemantic.complete)
            ] orelse 0;
            ik_active = active.ik.target_valid;
            if (active.phase == .contact) {
                ordering_valid =
                    (try scene.bodyOrderingValid()) and
                    (try scene.equipmentOrderingValid());
            }
        }
        const eligibility = scene.interactionEligibility();
        const animation_state = female.animationState();
        const animation_normalized_time = female.animationNormalizedTime();
        const supporting_collider: ?u32 = if (state.supporting_collider) |value|
            @intCast(value)
        else
            null;
        const landing_support: ?u32 = if (scene.frame_physics.landing_support) |value|
            @intCast(value)
        else
            null;
        const raised_collider: u16 = @intCast(raised_platform_collider);
        const foot_plants = female.footPlantingSnapshot();
        const left_surface_error_m: ?f32 =
            if (foot_plants.left.last_ground_sample.hit and
            foot_plants.left.last_ground_sample.collider_id == raised_collider)
                @abs(
                    foot_plants.left.post_ik_sole.y -
                        foot_plants.left.last_ground_sample.ground_height,
                )
            else
                null;
        const right_surface_error_m: ?f32 =
            if (foot_plants.right.last_ground_sample.hit and
            foot_plants.right.last_ground_sample.collider_id == raised_collider)
                @abs(
                    foot_plants.right.post_ik_sole.y -
                        foot_plants.right.last_ground_sample.ground_height,
                )
            else
                null;
        const feet_surface_contact_valid =
            left_surface_error_m != null and right_surface_error_m != null and
            left_surface_error_m.? <=
                foundation_evidence.landing_surface_contact_threshold_m and
            right_surface_error_m.? <=
                foundation_evidence.landing_surface_contact_threshold_m;
        const participant_owner_count: u32 =
            @as(u32, @intFromBool(female.interactionOwnerId() != 0)) +
            @as(u32, @intFromBool(male.interactionOwnerId() != 0));
        return .{
            .render_frame = render.render_frame,
            .simulation_tick = production.simulation_tick,
            .stage = script.phase,
            .stage_frame = script.phase_frame,
            .female_entity = female.id().raw(),
            .male_entity = male.id().raw(),
            .position = state.position.toArray(),
            .velocity = state.velocity.toArray(),
            .facing = switch (female.facingDirection()) {
                .left => .left,
                .right => .right,
            },
            .presentation_mode = presentation_mode,
            .view = switch (female.presentationView()) {
                .side => .side,
                .front => .front,
            },
            .grounded = state.grounded,
            .supporting_collider = supporting_collider,
            .animation_state = @tagName(animation_state),
            .animation_normalized_time = animation_normalized_time,
            .locomotion_phase_valid = animation_state == .walk and
                animation_normalized_time >= 0 and
                animation_normalized_time <= 1,
            .airborne_clearance_m = @max(0, state.position.y - scene.last_grounded_y),
            .landed_this_frame = scene.frame_physics.landed,
            .landing_support = landing_support,
            .raised_support = raised_platform_collider,
            .left_surface_error_m = left_surface_error_m,
            .right_surface_error_m = right_surface_error_m,
            .feet_surface_contact_valid = feet_surface_contact_valid,
            .body = body,
            .morphology = morphology,
            .global_build = anatomy_runtime.global_build_normalized * 100,
            .hair = hair,
            .outfit = outfit,
            .theme = @tagName(scene.integrated.environment.active_theme),
            .theme_transition_count = scene.theme_transition.count,
            .theme_changed = scene.theme_transition.changed,
            .theme_fingerprint_unchanged = scene.theme_transition.fingerprint_unchanged,
            .theme_root_delta_m = scene.theme_transition.root_delta_m,
            .theme_camera_delta_m = scene.theme_transition.camera_delta_m,
            .interaction_eligible = eligibility.isEligible(),
            .interaction_id = interaction_id,
            .interaction_lifecycle = interaction_lifecycle,
            .interaction_phase = interaction_phase,
            .interaction_elapsed_ticks = interaction_elapsed_ticks,
            .contact_tick = contact_tick,
            .release_tick = release_tick,
            .complete_tick = complete_tick,
            .ik_active = ik_active,
            .ordering_valid = ordering_valid,
            .active_interactions = @intCast(scene.manager.activeCount()),
            .active_ik_constraints = @intCast(scene.manager.activeIkConstraintCount()),
            .active_overrides = @intCast(scene.manager.activeOwnedOverrideCount()),
            .participant_owner_count = participant_owner_count,
            .detailed_debug_enabled = scene.integrated.detailed_debug_enabled,
            .debug_enabled_ticks = scene.debug_enabled_ticks,
            .debug_counts = scene.debug_counts,
            .camera_center = scene.integrated.camera.center.toArray(),
            .viewport = .{
                scene.integrated.camera.viewport_width,
                scene.integrated.camera.viewport_height,
            },
            .texture_pages = render.texture_pages,
            .submitted_sprites = render.submitted_sprites,
            .submitted_meshes = render.submitted_meshes,
            .sprite_ranges = render.sprite_ranges,
            .mesh_ranges = render.mesh_ranges,
            .gpu_resource_creations = render.gpu_resource_creations,
            .steady_update_allocations = render.steady_update_allocations,
            .steady_submission_allocations = render.steady_submission_allocations,
            .steady_queue_allocations = render.steady_queue_allocations,
            .reset_generation = scene.reset_generation,
        };
    }
};

pub fn enforcePresenceMeasurement(
    measurement: PresenceMeasurement,
    policy: PresenceValidationPolicy,
) !void {
    if (!std.math.isFinite(measurement.overlap_ratio) or
        measurement.overlap_ratio < 0 or
        measurement.overlap_ratio > 1)
    {
        return error.InvalidCharacterPresenceMeasurement;
    }
    if (policy == .enforce_acceptance and !measurement.passes_acceptance) {
        return error.CharacterPresenceOverlapExceeded;
    }
}

fn evidenceLifecycle(
    value: interaction.Lifecycle,
) foundation_evidence.InteractionLifecycle {
    return switch (value) {
        .inactive => .none,
        .requested => .requested,
        .active => .active,
        .completing => .completing,
        .completed => .completed,
        .cancelled => .cancelled,
    };
}

fn evidenceInteractionPhase(
    value: interaction.Phase,
) foundation_evidence.InteractionPhase {
    return switch (value) {
        .approach => .approach,
        .contact => .contact,
        .released => .released,
        .complete => .complete,
    };
}

fn projectedRightHand(instance: *const character.CharacterInstance) !math.Vec2 {
    const definition_view = instance.definitionView();
    const definition = &definition_view.skeleton_definition;
    const humanoid_view = instance.humanoidView();
    const projection = try presentation_pose.FrontProjection.initSideInteraction(
        definition,
        humanoid_view.local_and_world_pose,
        definition_view.visual_definition,
        humanoid_view.appearance_runtime,
        instance.worldPosition(),
        instance.facingDirection() == .left,
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

pub const ScriptedInput = struct {
    phase: ScriptPhase = .idle,
    phase_frame: u32 = 0,
    resize_stage: u8 = 0,
    abrupt_resize_first_post_frame: bool = false,
    abrupt_resize_previous_viewport: [2]u32 = .{ 0, 0 },
    abrupt_resize_previous_camera_y: f32 = 0,
    approach_nudge_direction: i8 = 0,
    return_nudge_direction: i8 = 0,
    completed_interactions: usize = 0,
    final_frames: u32 = 0,

    pub fn nextRaw(script: *ScriptedInput, scene: *const Scene) input.RawInputState {
        var raw = input.RawInputState{};
        const state = scene.integrated.production.female.controllerSnapshot().?.state;
        switch (script.phase) {
            .idle,
            .customization_release,
            .stop_left,
            .short_jump_release,
            .partner_step_aside,
            .wait_raised_landing,
            .theme_hold,
            .theme_restore_release,
            .outfit_motion_release,
            .double_jump_release,
            .double_jump_land,
            .dash_release,
            .first_wait,
            .first_cleanup_hold,
            .long_outfit,
            .second_wait,
            .debug_disable_release,
            .ivory_outfit,
            .third_wait,
            .cleanup_idle,
            .partner_return,
            .reset_release,
            .final_idle,
            => {},
            .customization_press => {
                raw.keyboard.c = true;
                raw.keyboard.v = true;
                raw.keyboard.h = true;
            },
            .move_left => raw.keyboard.a = true,
            .move_right, .outfit_motion_press => {
                raw.keyboard.d = true;
                if (script.phase == .outfit_motion_press) raw.keyboard.o = true;
            },
            .travel_to_platform => raw.keyboard.d = true,
            .full_jump => {
                raw.keyboard.d = true;
                raw.keyboard.space = true;
            },
            .short_jump_press => raw.keyboard.space = script.phase_frame < 3,
            .theme_switch_press, .theme_restore_press => raw.keyboard.t = true,
            .double_jump_first, .double_jump_second => raw.keyboard.space = true,
            .dash_to_handshake => {
                const error_value = scene.handshakeTargetX() - state.position.x;
                if (@abs(error_value) > 0.4) {
                    if (error_value < 0) raw.keyboard.a = true else raw.keyboard.d = true;
                    raw.keyboard.left_shift = true;
                }
            },
            .approach => {
                if (script.approach_nudge_direction == 2) {
                    raw.gamepad_move_axis = encodeGamepadAxis(0.25);
                } else {
                    raw.keyboard.a = script.approach_nudge_direction < 0;
                    raw.keyboard.d = script.approach_nudge_direction > 0;
                }
            },
            .depart_interaction => {
                if (script.phase_frame < 20) {
                    raw.keyboard.a = true;
                    raw.keyboard.space = true;
                } else if (state.position.x >
                    foundation_world.player_spawn.x + 0.5)
                {
                    raw.keyboard.a = true;
                } else {
                    raw.keyboard.a = script.return_nudge_direction < 0;
                    raw.keyboard.d = script.return_nudge_direction > 0;
                }
            },
            .first_interact, .second_interact, .third_interact => raw.keyboard.e = true,
            .debug_press => raw.keyboard.f1 = true,
            .debug_hold => raw.keyboard.f1 =
                script.phase_frame == 1 or script.phase_frame == 3,
            .debug_disable_press => raw.keyboard.f1 = true,
            .reset_press => raw.keyboard.r = true,
            .approach_hold => {},
        }
        return raw;
    }

    pub fn observe(script: *ScriptedInput, scene: *Scene) !void {
        script.abrupt_resize_first_post_frame = false;
        script.phase_frame += 1;
        const state = scene.integrated.production.female.controllerSnapshot().?.state;
        switch (script.phase) {
            .idle => if (script.phase_frame >= 65) script.transition(.customization_press),
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
            .stop_left => if (script.phase_frame >= 130 and
                @abs(state.velocity.x) < 0.02 and
                scene.integrated.production.female.animationState() == .idle and
                scene.integrated.production.female.presentationView() == .front)
                script.transition(.move_right),
            .move_right => if (state.position.x >= -4.3) script.transition(.short_jump_press),
            .short_jump_press => if (script.phase_frame >= 4)
                script.transition(.short_jump_release),
            .short_jump_release => if (script.phase_frame > 8 and state.grounded) {
                try scene.startPartnerMotion(partner_clear_x);
                script.transition(.partner_step_aside);
            },
            .partner_step_aside => if (scene.partner_motion == .stopped)
                script.transition(.travel_to_platform),
            .travel_to_platform => {
                if (state.position.x >= 3.25) {
                    script.transition(.full_jump);
                }
            },
            .full_jump => if (script.phase_frame >= 25)
                script.transition(.wait_raised_landing),
            .wait_raised_landing => if (script.phase_frame > 8 and
                scene.evidence.raised_platform_landing)
            {
                script.transition(.theme_switch_press);
            },
            .theme_switch_press => if (script.phase_frame >= 1)
                script.transition(.theme_hold),
            .theme_hold => if (script.phase_frame >= 130)
                script.transition(.theme_restore_press),
            .theme_restore_press => if (script.phase_frame >= 1)
                script.transition(.theme_restore_release),
            .theme_restore_release => if (script.phase_frame >= 2)
                script.transition(.outfit_motion_press),
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
            .dash_to_handshake => if (@abs(
                scene.handshakeTargetX() - state.position.x,
            ) <= 0.14)
                script.transition(.dash_release),
            .dash_release => if (state.dash_ticks_remaining == 0)
                script.transition(.approach),
            .approach => {
                if (script.approach_nudge_direction != 0) {
                    script.approach_nudge_direction = 0;
                } else if (@abs(state.velocity.x) < 0.02) {
                    const error_value = scene.handshakeTargetX() - state.position.x;
                    if (@abs(error_value) <= handshake.horizontal_tolerance * 0.5 and
                        scene.integrated.production.female.facingDirection() == .left)
                    {
                        script.approach_nudge_direction = 2;
                    } else if (error_value > handshake.horizontal_tolerance * 0.5) {
                        script.approach_nudge_direction = 1;
                    } else if (error_value < -handshake.horizontal_tolerance * 0.5) {
                        script.approach_nudge_direction = -1;
                    }
                }
                if (script.resize_stage == 0 and script.phase_frame >= 2) {
                    try scene.applyViewport(960, 540);
                    script.resize_stage = 1;
                } else if (script.resize_stage == 1 and script.phase_frame >= 4) {
                    try scene.applyViewport(800, 510);
                    script.resize_stage = 2;
                } else if (script.resize_stage == 2 and script.phase_frame >= 6) {
                    try scene.applyViewport(640, 480);
                    script.resize_stage = 3;
                }
                if (scene.interactionEligibility().isEligible()) {
                    scene.evidence.approach_observed = true;
                    script.transition(.approach_hold);
                }
            },
            .approach_hold => {
                if (script.resize_stage == 3 and script.phase_frame >= 20) {
                    try scene.applyViewport(
                        foundation_coherence.abrupt_resize_from_width,
                        foundation_coherence.abrupt_resize_from_height,
                    );
                    script.resize_stage = 4;
                } else if (script.resize_stage == 4 and
                    script.phase_frame >= 21)
                {
                    const camera = scene.integrated.camera;
                    if (camera.viewport_width !=
                        foundation_coherence.abrupt_resize_from_width or
                        camera.viewport_height !=
                            foundation_coherence.abrupt_resize_from_height)
                    {
                        return error.AbruptResizeSourceViewportMismatch;
                    }
                    script.abrupt_resize_previous_viewport = .{
                        camera.viewport_width,
                        camera.viewport_height,
                    };
                    script.abrupt_resize_previous_camera_y = camera.center.y;
                    try scene.applyViewport(
                        foundation_coherence.abrupt_resize_to_width,
                        foundation_coherence.abrupt_resize_to_height,
                    );
                    script.abrupt_resize_first_post_frame = true;
                    script.resize_stage = 5;
                }
                if (script.phase_frame >= 130 and
                    @abs(state.velocity.x) < 0.02 and
                    scene.integrated.production.female.animationState() == .idle and
                    scene.integrated.production.female.presentationView() == .front)
                {
                    script.transition(.first_interact);
                }
            },
            .first_interact => if (scene.evidence.interaction_count == 1)
                script.transition(.first_wait),
            .first_wait => if (scene.evidence.interaction_records[0].captured) {
                script.completed_interactions = 1;
                script.transition(.first_cleanup_hold);
            },
            .first_cleanup_hold => if (script.phase_frame >= 65) {
                try scene.selectFemalePresetByName("garnet_formal");
                scene.evidence.outfit_idle_change = true;
                try scene.integrated.cycleThemePreservingState();
                script.transition(.debug_press);
            },
            .debug_press => if (script.phase_frame >= 1)
                script.transition(.debug_hold),
            .debug_hold => if (script.phase_frame >= 65)
                script.transition(.long_outfit),
            .long_outfit => if (script.phase_frame >= 2)
                script.transition(.second_interact),
            .second_interact => if (scene.evidence.interaction_count == 2)
                script.transition(.second_wait),
            .second_wait => if (scene.evidence.interaction_records[1].captured) {
                script.completed_interactions = 2;
                script.transition(.debug_disable_press);
            },
            .debug_disable_press => if (script.phase_frame >= 1)
                script.transition(.debug_disable_release),
            .debug_disable_release => if (script.phase_frame >= 2) {
                try scene.selectFemalePresetByName("ivory_blouse_red_shorts");
                try scene.integrated.cycleThemePreservingState();
                script.transition(.ivory_outfit);
            },
            .ivory_outfit => if (script.phase_frame >= 60)
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
                script.transition(.depart_interaction);
            },
            .depart_interaction => {
                if (script.phase_frame < 20) {
                    script.return_nudge_direction = 0;
                } else if (state.position.x >
                    foundation_world.player_spawn.x + 0.5)
                {
                    script.return_nudge_direction = 0;
                } else if (script.return_nudge_direction != 0) {
                    script.return_nudge_direction = 0;
                } else if (@abs(state.velocity.x) < 0.02) {
                    const error_value =
                        foundation_world.player_spawn.x - state.position.x;
                    if (error_value > 0.04) {
                        script.return_nudge_direction = 1;
                    } else if (error_value < -0.04) {
                        script.return_nudge_direction = -1;
                    } else {
                        try scene.startPartnerMotion(
                            foundation_world.partner_spawn.x,
                        );
                        script.transition(.partner_return);
                    }
                }
            },
            .partner_return => if (scene.partner_motion == .stopped) {
                script.transition(.reset_press);
            },
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
            script.resize_stage == 5 and
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
