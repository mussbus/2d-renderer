const std = @import("std");

pub const capture_count: usize = 16;
pub const idle_velocity_threshold_mps: f32 = 0.02;
pub const locomotion_speed_threshold_mps: f32 = 0.20;
pub const jump_vertical_threshold_mps: f32 = 0.20;
pub const apex_velocity_threshold_mps: f32 = 0.35;
pub const airborne_clearance_threshold_m: f32 = 0.10;
pub const landing_surface_contact_threshold_m: f32 = 0.08;
pub const ordinary_stable_ticks: u32 = 8;
pub const inspection_stable_ticks: u32 = 240;
pub const interaction_stable_ticks: u32 = 12;

pub const Stage = enum(u8) {
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
    theme_switch_press,
    theme_hold,
    theme_restore_press,
    theme_restore_release,
    outfit_motion_press,
    outfit_motion_release,
    double_jump_first,
    double_jump_release,
    double_jump_second,
    double_jump_land,
    dash_to_handshake,
    dash_release,
    approach,
    approach_hold,
    first_interact,
    first_wait,
    first_cleanup_hold,
    debug_press,
    debug_hold,
    long_outfit,
    second_interact,
    second_wait,
    debug_disable_press,
    debug_disable_release,
    ivory_outfit,
    third_interact,
    third_wait,
    cleanup_idle,
    reset_press,
    reset_release,
    final_idle,
};

pub const CaptureId = enum(u8) {
    initial_front_idle,
    side_left_walk,
    stopped_front_facing_left,
    side_right_walk,
    short_jump_rise,
    jump_apex,
    jump_fall,
    raised_platform_landing,
    theme_switch_in_place,
    interaction_approach,
    interaction_reach,
    interaction_first_contact,
    interaction_release,
    interaction_cleanup_front,
    detailed_debug,
    reset_stable_front,
};

pub const Facing = enum(u8) {
    left,
    right,
};

pub const View = enum(u8) {
    side,
    front,
};

pub const PresentationMode = enum(u8) {
    automatic,
    force_side,
    force_front,
    interaction_owned,
};

pub const InteractionLifecycle = enum(u8) {
    none,
    requested,
    active,
    completing,
    completed,
    cancelled,
};

pub const InteractionPhase = enum(u8) {
    none,
    approach,
    contact,
    released,
    complete,
};

pub const DebugCounts = struct {
    collider: u32 = 0,
    root: u32 = 0,
    ground: u32 = 0,
    ik: u32 = 0,
    participant_link: u32 = 0,

    pub fn total(counts: DebugCounts) u32 {
        return counts.collider +
            counts.root +
            counts.ground +
            counts.ik +
            counts.participant_link;
    }

    pub fn complete(counts: DebugCounts) bool {
        return counts.collider > 0 and
            counts.root > 0 and
            counts.ground > 0 and
            counts.ik > 0 and
            counts.participant_link > 0;
    }
};

pub const Observation = struct {
    render_frame: u32 = 0,
    simulation_tick: u64 = 0,
    stage: Stage = .idle,
    stage_frame: u32 = 0,
    female_entity: u32 = 0,
    male_entity: u32 = 0,
    position: [2]f32 = .{ 0, 0 },
    velocity: [2]f32 = .{ 0, 0 },
    facing: Facing = .right,
    presentation_mode: PresentationMode = .automatic,
    view: View = .front,
    grounded: bool = true,
    supporting_collider: ?u32 = null,
    animation_state: []const u8 = "idle",
    animation_normalized_time: f32 = 0,
    locomotion_phase_valid: bool = true,
    airborne_clearance_m: f32 = 0,
    landed_this_frame: bool = false,
    landing_support: ?u32 = null,
    raised_support: u32 = 0,
    left_surface_error_m: ?f32 = null,
    right_surface_error_m: ?f32 = null,
    feet_surface_contact_valid: bool = false,
    body: []const u8 = "",
    morphology: []const u8 = "",
    global_build: f32 = 0,
    hair: []const u8 = "",
    outfit: []const u8 = "",
    theme: []const u8 = "",
    theme_transition_count: u32 = 0,
    theme_changed: bool = false,
    theme_fingerprint_unchanged: bool = false,
    theme_root_delta_m: f32 = 0,
    theme_camera_delta_m: f32 = 0,
    interaction_eligible: bool = false,
    interaction_id: u32 = 0,
    interaction_lifecycle: InteractionLifecycle = .none,
    interaction_phase: InteractionPhase = .none,
    interaction_elapsed_ticks: u32 = 0,
    contact_tick: u64 = 0,
    release_tick: u64 = 0,
    complete_tick: u64 = 0,
    ik_active: bool = false,
    ordering_valid: bool = false,
    active_interactions: u32 = 0,
    active_ik_constraints: u32 = 0,
    active_overrides: u32 = 0,
    participant_owner_count: u32 = 0,
    detailed_debug_enabled: bool = false,
    debug_enabled_ticks: u32 = 0,
    debug_counts: DebugCounts = .{},
    camera_center: [2]f32 = .{ 0, 0 },
    viewport: [2]u32 = .{ 640, 480 },
    texture_pages: u32 = 0,
    submitted_sprites: u32 = 0,
    submitted_meshes: u32 = 0,
    sprite_ranges: u32 = 0,
    mesh_ranges: u32 = 0,
    gpu_resource_creations: u64 = 0,
    steady_update_allocations: u64 = 0,
    steady_submission_allocations: u64 = 0,
    steady_queue_allocations: u64 = 0,
    reset_generation: u32 = 0,

    pub fn validate(observation: Observation) !void {
        const values = [_]f32{
            observation.position[0],
            observation.position[1],
            observation.velocity[0],
            observation.velocity[1],
            observation.animation_normalized_time,
            observation.airborne_clearance_m,
            observation.global_build,
            observation.theme_root_delta_m,
            observation.theme_camera_delta_m,
            observation.camera_center[0],
            observation.camera_center[1],
        };
        for (values) |value| {
            if (!std.math.isFinite(value)) return error.NonFiniteCaptureObservation;
        }
        for ([_]?f32{
            observation.left_surface_error_m,
            observation.right_surface_error_m,
        }) |value| {
            if (value) |present| {
                if (!std.math.isFinite(present) or present < 0) {
                    return error.InvalidCaptureSurfaceContactMeasurement;
                }
            }
        }
        if (observation.female_entity == 0 or observation.male_entity == 0) {
            return error.MissingCaptureEntityIdentity;
        }
        if (observation.viewport[0] == 0 or observation.viewport[1] == 0) {
            return error.InvalidCaptureViewport;
        }
        if (observation.animation_state.len == 0 or
            observation.body.len == 0 or
            observation.morphology.len == 0 or
            observation.hair.len == 0 or
            observation.outfit.len == 0 or
            observation.theme.len == 0)
        {
            return error.MissingCaptureMetadata;
        }
    }
};

const AuthoritativePredicate = enum(u8) {
    idle,
    locomotion_left,
    locomotion_right,
    jump_rise,
    jump_apex,
    jump_fall,
    raised_landing,
    theme_switch,
    eligible_approach,
    interaction_reach,
    first_contact,
    interaction_release,
    cleanup,
    detailed_debug,
    reset_idle,
};

const PresentationPredicate = enum(u8) {
    automatic_front,
    automatic_front_left,
    side_left,
    side_right,
    side,
    interaction_side,
    front,
    any,
};

const InteractionPredicate = enum(u8) {
    none,
    eligible_without_active,
    active_reach,
    first_contact,
    released,
    cleanup,
    any,
};

pub const CaptureSpec = struct {
    id: CaptureId,
    filename: []const u8,
    stage: ?Stage,
    authoritative: AuthoritativePredicate,
    presentation: PresentationPredicate,
    interaction: InteractionPredicate,
    minimum_stable_ticks: u32,
    timeout_render_frames: u32,
    require_debug_categories: bool = false,
};

pub const specs = [_]CaptureSpec{
    .{ .id = .initial_front_idle, .filename = "01_initial_front_idle.ppm", .stage = .idle, .authoritative = .idle, .presentation = .automatic_front, .interaction = .none, .minimum_stable_ticks = inspection_stable_ticks, .timeout_render_frames = 180 },
    .{ .id = .side_left_walk, .filename = "02_side_left_walk.ppm", .stage = .move_left, .authoritative = .locomotion_left, .presentation = .side_left, .interaction = .none, .minimum_stable_ticks = ordinary_stable_ticks, .timeout_render_frames = 180 },
    .{ .id = .stopped_front_facing_left, .filename = "03_stopped_front_facing_left.ppm", .stage = .stop_left, .authoritative = .idle, .presentation = .automatic_front_left, .interaction = .none, .minimum_stable_ticks = inspection_stable_ticks, .timeout_render_frames = 600 },
    .{ .id = .side_right_walk, .filename = "04_side_right_walk.ppm", .stage = .move_right, .authoritative = .locomotion_right, .presentation = .side_right, .interaction = .none, .minimum_stable_ticks = ordinary_stable_ticks, .timeout_render_frames = 240 },
    .{ .id = .short_jump_rise, .filename = "05_short_jump_rise.ppm", .stage = .short_jump_release, .authoritative = .jump_rise, .presentation = .side, .interaction = .none, .minimum_stable_ticks = ordinary_stable_ticks, .timeout_render_frames = 90 },
    .{ .id = .jump_apex, .filename = "06_jump_apex.ppm", .stage = .short_jump_release, .authoritative = .jump_apex, .presentation = .side, .interaction = .none, .minimum_stable_ticks = 1, .timeout_render_frames = 90 },
    .{ .id = .jump_fall, .filename = "07_jump_fall.ppm", .stage = .short_jump_release, .authoritative = .jump_fall, .presentation = .side, .interaction = .none, .minimum_stable_ticks = ordinary_stable_ticks, .timeout_render_frames = 90 },
    .{ .id = .raised_platform_landing, .filename = "08_raised_platform_landing.ppm", .stage = .wait_raised_landing, .authoritative = .raised_landing, .presentation = .any, .interaction = .none, .minimum_stable_ticks = 1, .timeout_render_frames = 300 },
    .{ .id = .theme_switch_in_place, .filename = "09_theme_switch_in_place.ppm", .stage = .theme_hold, .authoritative = .theme_switch, .presentation = .front, .interaction = .none, .minimum_stable_ticks = inspection_stable_ticks, .timeout_render_frames = 300 },
    .{ .id = .interaction_approach, .filename = "10_interaction_approach.ppm", .stage = .approach_hold, .authoritative = .eligible_approach, .presentation = .front, .interaction = .eligible_without_active, .minimum_stable_ticks = interaction_stable_ticks, .timeout_render_frames = 1_200 },
    .{ .id = .interaction_reach, .filename = "11_interaction_reach.ppm", .stage = .first_wait, .authoritative = .interaction_reach, .presentation = .interaction_side, .interaction = .active_reach, .minimum_stable_ticks = interaction_stable_ticks, .timeout_render_frames = 120 },
    .{ .id = .interaction_first_contact, .filename = "12_interaction_first_contact.ppm", .stage = .first_wait, .authoritative = .first_contact, .presentation = .interaction_side, .interaction = .first_contact, .minimum_stable_ticks = 1, .timeout_render_frames = 120 },
    .{ .id = .interaction_release, .filename = "13_interaction_release.ppm", .stage = .first_wait, .authoritative = .interaction_release, .presentation = .interaction_side, .interaction = .released, .minimum_stable_ticks = 1, .timeout_render_frames = 120 },
    .{ .id = .interaction_cleanup_front, .filename = "14_interaction_cleanup_front.ppm", .stage = .first_cleanup_hold, .authoritative = .cleanup, .presentation = .automatic_front, .interaction = .cleanup, .minimum_stable_ticks = inspection_stable_ticks, .timeout_render_frames = 180 },
    .{ .id = .detailed_debug, .filename = "15_detailed_debug.ppm", .stage = .second_wait, .authoritative = .detailed_debug, .presentation = .interaction_side, .interaction = .first_contact, .minimum_stable_ticks = 1, .timeout_render_frames = 300, .require_debug_categories = true },
    .{ .id = .reset_stable_front, .filename = "16_reset_stable_front.ppm", .stage = .final_idle, .authoritative = .reset_idle, .presentation = .automatic_front, .interaction = .cleanup, .minimum_stable_ticks = inspection_stable_ticks, .timeout_render_frames = 500 },
};

pub const Candidate = struct {
    spec_index: usize,
    stable_ticks: u32,
};

pub const CapturedState = struct {
    captured: bool = false,
    render_frame: u32 = 0,
    simulation_tick: u64 = 0,
    stable_ticks: u32 = 0,
    reset_generation: u32 = 0,
};

pub const Tracker = struct {
    next_index: usize = 0,
    stable_ticks: u32 = 0,
    waited_render_frames: u32 = 0,
    last_observed_tick: ?u64 = null,
    last_reset_generation: u32 = 0,
    log_timeouts: bool = true,
    states: [capture_count]CapturedState = [_]CapturedState{.{}} ** capture_count,

    pub fn currentSpec(tracker: *const Tracker) ?*const CaptureSpec {
        if (tracker.next_index >= specs.len) return null;
        return &specs[tracker.next_index];
    }

    pub fn observe(tracker: *Tracker, observation: Observation) !?Candidate {
        try observation.validate();
        const spec = tracker.currentSpec() orelse return null;
        tracker.waited_render_frames = std.math.add(
            u32,
            tracker.waited_render_frames,
            1,
        ) catch return error.CaptureWaitOverflow;
        if (tracker.waited_render_frames > spec.timeout_render_frames) {
            if (tracker.log_timeouts) {
                std.log.err(
                    "Prompt 27A capture timeout: id={s} required_stage={any} actual_stage={s} frame={d} tick={d} stable_ticks={d} position=({d:.4},{d:.4}) velocity=({d:.4},{d:.4}) facing={s} mode={s} view={s} grounded={} support={any} animation={s} interaction={s}/{s} debug={d}",
                    .{
                        @tagName(spec.id),
                        spec.stage,
                        @tagName(observation.stage),
                        observation.render_frame,
                        observation.simulation_tick,
                        tracker.stable_ticks,
                        observation.position[0],
                        observation.position[1],
                        observation.velocity[0],
                        observation.velocity[1],
                        @tagName(observation.facing),
                        @tagName(observation.presentation_mode),
                        @tagName(observation.view),
                        observation.grounded,
                        observation.supporting_collider,
                        observation.animation_state,
                        @tagName(observation.interaction_lifecycle),
                        @tagName(observation.interaction_phase),
                        observation.debug_counts.total(),
                    },
                );
            }
            return error.CapturePredicateTimeout;
        }

        if (observation.reset_generation < tracker.last_reset_generation) {
            return error.NonMonotonicCaptureResetGeneration;
        }
        if (observation.reset_generation > tracker.last_reset_generation) {
            tracker.last_observed_tick = null;
            tracker.last_reset_generation = observation.reset_generation;
        }
        const tick_delta: u32 = if (tracker.last_observed_tick) |last| delta: {
            if (observation.simulation_tick < last) return error.NonMonotonicCaptureTick;
            const raw = observation.simulation_tick - last;
            break :delta @intCast(@min(raw, std.math.maxInt(u32)));
        } else 1;
        tracker.last_observed_tick = observation.simulation_tick;

        if (!matches(spec.*, observation)) {
            tracker.stable_ticks = 0;
            return null;
        }
        tracker.stable_ticks = std.math.add(
            u32,
            tracker.stable_ticks,
            tick_delta,
        ) catch return error.CaptureStableTickOverflow;
        if (tracker.stable_ticks < spec.minimum_stable_ticks) return null;
        return .{ .spec_index = tracker.next_index, .stable_ticks = tracker.stable_ticks };
    }

    pub fn commit(
        tracker: *Tracker,
        candidate: Candidate,
        observation: Observation,
    ) !void {
        if (candidate.spec_index != tracker.next_index or
            candidate.spec_index >= tracker.states.len)
        {
            return error.CaptureCommitOrderMismatch;
        }
        if (!matches(specs[candidate.spec_index], observation)) {
            return error.CaptureCommitStateMismatch;
        }
        tracker.states[candidate.spec_index] = .{
            .captured = true,
            .render_frame = observation.render_frame,
            .simulation_tick = observation.simulation_tick,
            .stable_ticks = candidate.stable_ticks,
            .reset_generation = observation.reset_generation,
        };
        tracker.next_index += 1;
        tracker.stable_ticks = 0;
        tracker.waited_render_frames = 0;
    }

    pub fn validateComplete(tracker: *const Tracker) !void {
        if (tracker.next_index != specs.len) return error.CaptureMatrixIncomplete;
        var previous_tick: u64 = 0;
        var previous_reset_generation: u32 = 0;
        for (tracker.states, specs) |state, spec| {
            if (!state.captured or state.stable_ticks < spec.minimum_stable_ticks) {
                return error.InvalidCaptureManifestState;
            }
            if (state.reset_generation < previous_reset_generation) {
                return error.CaptureManifestOutOfOrder;
            }
            if (state.reset_generation == previous_reset_generation and
                state.simulation_tick < previous_tick)
            {
                return error.CaptureManifestOutOfOrder;
            }
            previous_tick = state.simulation_tick;
            previous_reset_generation = state.reset_generation;
        }
    }
};

pub fn matches(spec: CaptureSpec, observation: Observation) bool {
    if (spec.stage) |required_stage| {
        if (observation.stage != required_stage) return false;
    }
    if (!matchesAuthoritative(spec.authoritative, observation)) return false;
    if (!matchesPresentation(spec.presentation, observation)) return false;
    if (!matchesInteraction(spec.interaction, observation)) return false;
    if (spec.require_debug_categories and !observation.debug_counts.complete()) return false;
    return true;
}

fn matchesAuthoritative(
    predicate: AuthoritativePredicate,
    observation: Observation,
) bool {
    const idle = observation.grounded and
        @abs(observation.velocity[0]) <= idle_velocity_threshold_mps and
        @abs(observation.velocity[1]) <= idle_velocity_threshold_mps and
        std.mem.eql(u8, observation.animation_state, "idle");
    return switch (predicate) {
        .idle => idle,
        .locomotion_left => observation.velocity[0] <= -locomotion_speed_threshold_mps and
            observation.facing == .left and observation.locomotion_phase_valid,
        .locomotion_right => observation.velocity[0] >= locomotion_speed_threshold_mps and
            observation.facing == .right and observation.locomotion_phase_valid,
        .jump_rise => !observation.grounded and
            observation.velocity[1] > jump_vertical_threshold_mps and
            observation.airborne_clearance_m >= airborne_clearance_threshold_m and
            observation.supporting_collider == null,
        .jump_apex => !observation.grounded and
            @abs(observation.velocity[1]) <= apex_velocity_threshold_mps and
            observation.airborne_clearance_m >= airborne_clearance_threshold_m and
            observation.supporting_collider == null,
        .jump_fall => !observation.grounded and
            observation.velocity[1] < -jump_vertical_threshold_mps and
            observation.airborne_clearance_m >= airborne_clearance_threshold_m and
            observation.supporting_collider == null,
        .raised_landing => observation.landed_this_frame and
            observation.grounded and
            observation.landing_support != null and
            observation.landing_support.? == observation.raised_support and
            observation.supporting_collider == observation.landing_support and
            observation.left_surface_error_m != null and
            observation.right_surface_error_m != null and
            observation.left_surface_error_m.? <=
                landing_surface_contact_threshold_m and
            observation.right_surface_error_m.? <=
                landing_surface_contact_threshold_m and
            observation.feet_surface_contact_valid,
        .theme_switch => observation.theme_changed and
            observation.theme_transition_count > 0 and
            observation.theme_fingerprint_unchanged and
            @abs(observation.theme_root_delta_m) <= 0.000001 and
            @abs(observation.theme_camera_delta_m) <= 0.000001 and idle,
        .eligible_approach => idle and observation.interaction_eligible,
        .interaction_reach => observation.interaction_id != 0 and
            observation.interaction_lifecycle == .active and
            observation.interaction_phase == .approach and
            observation.interaction_elapsed_ticks > 0 and
            observation.contact_tick == 0,
        .first_contact => observation.interaction_id != 0 and
            observation.interaction_lifecycle == .active and
            observation.interaction_phase == .contact and
            observation.contact_tick != 0 and
            observation.simulation_tick >= observation.contact_tick and
            observation.simulation_tick - observation.contact_tick <= 4 and
            observation.ik_active and
            observation.ordering_valid,
        .interaction_release => observation.interaction_id != 0 and
            observation.interaction_phase == .released and
            observation.release_tick != 0 and
            observation.simulation_tick >= observation.release_tick and
            observation.simulation_tick - observation.release_tick <= 4,
        .cleanup => idle and cleanupComplete(observation),
        .detailed_debug => observation.detailed_debug_enabled and
            observation.debug_enabled_ticks >= inspection_stable_ticks and
            observation.debug_counts.complete(),
        .reset_idle => observation.reset_generation > 0 and idle and
            cleanupComplete(observation),
    };
}

fn matchesPresentation(
    predicate: PresentationPredicate,
    observation: Observation,
) bool {
    return switch (predicate) {
        .automatic_front => observation.presentation_mode == .automatic and
            observation.view == .front,
        .automatic_front_left => observation.presentation_mode == .automatic and
            observation.view == .front and observation.facing == .left,
        .side_left => observation.view == .side and observation.facing == .left,
        .side_right => observation.view == .side and observation.facing == .right,
        .side => observation.view == .side,
        .interaction_side => observation.presentation_mode == .interaction_owned and
            observation.view == .side,
        .front => observation.view == .front,
        .any => true,
    };
}

fn matchesInteraction(
    predicate: InteractionPredicate,
    observation: Observation,
) bool {
    return switch (predicate) {
        .none => observation.active_interactions == 0 and
            observation.participant_owner_count == 0,
        .eligible_without_active => observation.interaction_eligible and
            observation.active_interactions == 0 and
            observation.participant_owner_count == 0,
        .active_reach => observation.active_interactions == 1 and
            observation.interaction_phase == .approach and
            observation.contact_tick == 0,
        .first_contact => observation.active_interactions == 1 and
            observation.interaction_phase == .contact and
            observation.contact_tick != 0,
        .released => observation.active_interactions == 1 and
            observation.interaction_phase == .released and
            observation.release_tick != 0,
        .cleanup => cleanupComplete(observation),
        .any => true,
    };
}

fn cleanupComplete(observation: Observation) bool {
    return observation.active_interactions == 0 and
        observation.active_ik_constraints == 0 and
        observation.active_overrides == 0 and
        observation.participant_owner_count == 0 and
        observation.interaction_id == 0 and
        observation.interaction_phase == .none and
        observation.presentation_mode == .automatic;
}

comptime {
    if (specs.len != capture_count) @compileError("Prompt 27A capture matrix count changed");
    for (specs, 0..) |spec, index| {
        if (@intFromEnum(spec.id) != index) {
            @compileError("Prompt 27A capture IDs must match ordered specification indices");
        }
        if (spec.minimum_stable_ticks == 0 or spec.timeout_render_frames == 0) {
            @compileError("Prompt 27A capture specs require bounded stability and timeout");
        }
    }
}
