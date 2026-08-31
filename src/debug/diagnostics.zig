const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const fixed_step = @import("fixed_step");
const humanoid = @import("humanoid");
const state_machine = @import("state_machine");
const foot_planting = @import("foot_planting");
const interaction = @import("interaction");
const character = @import("character");
const interaction_system = @import("interaction_system");

pub const maximum_snapshot_characters: usize = character.maximum_characters;
pub const history_capacity: usize = 32;

pub const MilestoneId = enum(u8) {
    walk_first_left_plant,
    walk_first_right_plant,
    jump_takeoff,
    hard_landing,
    platform_right_plant,
    handshake_start,
    handshake_contact,
    handshake_release,
    handshake_complete,
    final_state,
};

pub const milestone_count: usize = @typeInfo(MilestoneId).@"enum".fields.len;

pub const SimulationSnapshot = struct {
    render_frame_index: u64 = 0,
    fixed_tick: u64 = 0,
    fixed_timestep: f64 = fixed_step.fixed_dt_seconds,
    substeps_this_frame: u8 = 0,
    accumulator_alpha: f64 = 0,
    discarded_time_this_frame: f64 = 0,
    discarded_time_lifetime: f64 = 0,
    discarded_simulation_ticks_this_frame: u64 = 0,
    discarded_simulation_ticks_lifetime: u64 = 0,
};

pub const ProceduralSnapshot = struct {
    walk_bounce_offset: f32 = 0,
    landing_spring_displacement: f32 = 0,
    landing_spring_velocity: f32 = 0,
    secondary_head_rotation: f32 = 0,
};

pub const FootSnapshot = struct {
    plant_state: foot_planting.PlantState = .swing,
    plant_weight: f32 = 0,
    semantic_contact_tick: ?u64 = null,
    candidate_acquisition_tick: ?u64 = null,
    full_weight_planted_tick: ?u64 = null,
    release_start_tick: ?u64 = null,
    fully_released_tick: ?u64 = null,
    ground_collider_id: ?collider.ColliderId = null,
    locked_target: ?math.Vec2 = null,
    current_slip: f32 = 0,
    maximum_slip: f32 = 0,
    penetration: f32 = 0,
    hover: f32 = 0,
    acquisition_count: u32 = 0,
    release_count: u32 = 0,
};

pub const CharacterSnapshot = struct {
    entity_id: character.EntityId = .invalid,
    physics_position: math.Vec2 = math.Vec2.zero,
    physics_velocity: math.Vec2 = math.Vec2.zero,
    facing: humanoid.Facing = .right,
    grounded: bool = false,
    supporting_collider: ?collider.ColliderId = null,
    animation_state: state_machine.StateId = .idle,
    animation_normalized_time: f32 = 0,
    interaction_locked: bool = false,
    procedural: ProceduralSnapshot = .{},
    left_foot: FootSnapshot = .{},
    right_foot: FootSnapshot = .{},
};

pub const ArmIkSnapshot = struct {
    weight: f32 = 0,
    shared_target: math.Vec2 = math.Vec2.zero,
    target_valid: bool = false,
    role_a_reachable: bool = false,
    role_b_reachable: bool = false,
    role_a_hand_target_error: f32 = 0,
    role_b_hand_target_error: f32 = 0,
};

pub const InteractionSnapshot = struct {
    active: bool = false,
    interaction_id: interaction_system.InteractionId = .invalid,
    lifecycle: interaction.Lifecycle = .inactive,
    phase: interaction.Phase = .approach,
    participant_a: character.EntityId = .invalid,
    participant_b: character.EntityId = .invalid,
    role_a: interaction.Role = .initiator,
    role_b: interaction.Role = .receiver,
    elapsed_ticks: u32 = 0,
    event_counts: [interaction.event_count]u8 = [_]u8{0} ** interaction.event_count,
    event_ticks: [interaction.event_count]?u64 = [_]?u64{null} ** interaction.event_count,
    owned_override_count: usize = 0,
    arm_ik: ArmIkSnapshot = .{},
};

pub const RenderingSnapshot = struct {
    submitted_sprite_count: u32 = 0,
    ordinary_sprite_count: u32 = 0,
    debug_primitive_count: u32 = 0,
    texture_pages: u32 = 1,
    sprite_draw_ranges: u32 = 0,
    sprite_draw_calls: u32 = 0,
    debug_draw_calls: u32 = 0,
    total_actual_draw_calls: u32 = 0,
};

pub const ResourceSnapshot = struct {
    cpu_allocation_bytes: usize = 0,
    gpu_textures: u32 = 0,
    gpu_buffers: u32 = 0,
    gpu_pipelines: u32 = 0,
    gpu_samplers: u32 = 0,
    other_gpu_resources: u32 = 0,
    gpu_resources_created_this_frame: u64 = 0,
    gpu_resources_created_lifetime: u64 = 0,
};

pub const AllocationSnapshot = struct {
    controller: u64 = 0,
    animator: u64 = 0,
    procedural_motion: u64 = 0,
    interaction_update: u64 = 0,
    arm_ik: u64 = 0,
    foot_planting: u64 = 0,
    ground_query: u64 = 0,
    pose_evaluation: u64 = 0,
    layer_resolution: u64 = 0,
    sprite_submission: u64 = 0,
    diagnostics_snapshot_update: u64 = 0,
    debug_command_submission: u64 = 0,

    pub fn total(snapshot: AllocationSnapshot) u64 {
        return snapshot.controller + snapshot.animator + snapshot.procedural_motion +
            snapshot.interaction_update + snapshot.arm_ik + snapshot.foot_planting +
            snapshot.ground_query + snapshot.pose_evaluation + snapshot.layer_resolution +
            snapshot.sprite_submission + snapshot.diagnostics_snapshot_update +
            snapshot.debug_command_submission;
    }
};

pub const Snapshot = struct {
    simulation: SimulationSnapshot = .{},
    characters: [maximum_snapshot_characters]CharacterSnapshot = [_]CharacterSnapshot{.{}} ** maximum_snapshot_characters,
    character_count: usize = 0,
    interaction_state: InteractionSnapshot = .{},
    rendering: RenderingSnapshot = .{},
    resources: ResourceSnapshot = .{},
    allocations: AllocationSnapshot = .{},
};

pub const CaptureInput = struct {
    render_frame_index: u64,
    fixed_tick: u64,
    clock: *const fixed_step.Clock,
    characters: []const *const character.CharacterInstance,
    manager: *const interaction_system.Manager,
    rendering: RenderingSnapshot = .{},
    resources: ResourceSnapshot = .{},
    diagnostics_snapshot_allocations: u64 = 0,
    debug_command_allocations: u64 = 0,
};

pub fn capture(input_value: CaptureInput) !Snapshot {
    if (input_value.characters.len > maximum_snapshot_characters) return error.DiagnosticCharacterCapacityExceeded;
    var result = Snapshot{
        .simulation = .{
            .render_frame_index = input_value.render_frame_index,
            .fixed_tick = input_value.fixed_tick,
            .substeps_this_frame = input_value.clock.last_frame.substeps,
            .accumulator_alpha = input_value.clock.last_frame.interpolation_alpha,
            .discarded_time_this_frame = input_value.clock.last_frame.discarded_time,
            .discarded_time_lifetime = input_value.clock.lifetime_discarded_time,
            .discarded_simulation_ticks_this_frame = discardedTicks(input_value.clock.last_frame.discarded_time),
            .discarded_simulation_ticks_lifetime = discardedTicks(input_value.clock.lifetime_discarded_time),
        },
        .rendering = input_value.rendering,
        .resources = input_value.resources,
        .character_count = input_value.characters.len,
    };
    for (input_value.characters, 0..) |instance, index| {
        result.characters[index] = captureCharacter(instance);
        accumulateCharacterAllocations(&result.allocations, instance);
    }
    const manager_metrics = input_value.manager.metricsSnapshot();
    result.allocations.interaction_update = manager_metrics.request_allocations +
        manager_metrics.eligibility_allocations + manager_metrics.candidate_selection_allocations +
        manager_metrics.active_update_allocations + manager_metrics.event_processing_allocations +
        manager_metrics.completion_allocations;
    result.allocations.arm_ik += manager_metrics.ik_solver_allocations +
        manager_metrics.ik_binding_lookup_allocations + manager_metrics.ik_target_computation_allocations +
        manager_metrics.ik_pose_application_allocations + manager_metrics.ik_hierarchy_evaluation_allocations;
    result.allocations.diagnostics_snapshot_update = input_value.diagnostics_snapshot_allocations;
    result.allocations.debug_command_submission = input_value.debug_command_allocations;
    if (input_value.manager.firstActiveInstance()) |active| {
        result.interaction_state = captureInteraction(active, true);
    } else if (input_value.manager.lastTerminal()) |terminal| {
        result.interaction_state = captureInteraction(terminal, false);
    }
    return result;
}

pub const History = struct {
    entries: [history_capacity]Snapshot = [_]Snapshot{.{}} ** history_capacity,
    start: usize = 0,
    count: usize = 0,
    overwrite_count: u64 = 0,

    pub fn push(history: *History, snapshot: Snapshot) void {
        if (history.count < history.entries.len) {
            const index = (history.start + history.count) % history.entries.len;
            history.entries[index] = snapshot;
            history.count += 1;
            return;
        }
        history.entries[history.start] = snapshot;
        history.start = (history.start + 1) % history.entries.len;
        history.overwrite_count += 1;
    }

    pub fn oldest(history: *const History, offset: usize) ?*const Snapshot {
        if (offset >= history.count) return null;
        return &history.entries[(history.start + offset) % history.entries.len];
    }

    pub fn reset(history: *History) void {
        history.* = .{};
    }
};

pub const MilestoneStore = struct {
    entries: [milestone_count]?Snapshot = [_]?Snapshot{null} ** milestone_count,

    pub fn record(store: *MilestoneStore, id: MilestoneId, snapshot: Snapshot) !void {
        const index = @intFromEnum(id);
        if (store.entries[index] != null) return error.DuplicateDiagnosticMilestone;
        store.entries[index] = snapshot;
    }

    pub fn get(store: *const MilestoneStore, id: MilestoneId) ?*const Snapshot {
        const entry = &store.entries[@intFromEnum(id)];
        return if (entry.* != null) &entry.*.? else null;
    }

    pub fn reset(store: *MilestoneStore) void {
        store.* = .{};
    }
};

fn captureCharacter(instance: *const character.CharacterInstance) CharacterSnapshot {
    const controller = instance.controllerSnapshot();
    const procedural = instance.proceduralSnapshot();
    const feet = instance.footPlantingSnapshot();
    const physics_position = if (controller) |value| value.state.position else instance.worldPosition();
    const physics_velocity = if (controller) |value| value.state.velocity else math.Vec2.zero;
    const supporting_collider = if (controller) |value| value.state.supporting_collider else null;
    return .{
        .entity_id = instance.id(),
        .physics_position = physics_position,
        .physics_velocity = physics_velocity,
        .facing = instance.facingDirection(),
        .grounded = instance.interactionGrounded(),
        .supporting_collider = supporting_collider,
        .animation_state = instance.animationState(),
        .animation_normalized_time = instance.animationNormalizedTime(),
        .interaction_locked = instance.isInteractionLocked(),
        .procedural = .{
            .walk_bounce_offset = procedural.walk_bounce_offset,
            .landing_spring_displacement = procedural.landing_spring.offset,
            .landing_spring_velocity = procedural.landing_spring.velocity,
            .secondary_head_rotation = procedural.secondary_spring.offset,
        },
        .left_foot = captureFoot(&feet.left),
        .right_foot = captureFoot(&feet.right),
    };
}

fn captureFoot(runtime: *const foot_planting.FootRuntime) FootSnapshot {
    const lifecycle = runtime.metrics.latest_acquired_lifecycle;
    return .{
        .plant_state = runtime.plant_state,
        .plant_weight = runtime.plant_weight,
        .semantic_contact_tick = lifecycle.semantic_contact_tick,
        .candidate_acquisition_tick = lifecycle.candidate_acquisition_tick,
        .full_weight_planted_tick = lifecycle.full_plant_tick,
        .release_start_tick = lifecycle.release_start_tick,
        .fully_released_tick = lifecycle.full_release_tick,
        .ground_collider_id = runtime.locked_collider_id,
        .locked_target = runtime.locked_target,
        .current_slip = runtime.world_space_slip,
        .maximum_slip = runtime.metrics.maximum_world_space_slip,
        .penetration = runtime.penetration,
        .hover = runtime.hover,
        .acquisition_count = runtime.metrics.plant_acquisitions,
        .release_count = runtime.metrics.full_releases,
    };
}

fn captureInteraction(instance: *const interaction_system.Instance, active: bool) InteractionSnapshot {
    var result = InteractionSnapshot{
        .active = active,
        .interaction_id = instance.id,
        .lifecycle = instance.lifecycle,
        .phase = instance.phase,
        .participant_a = instance.participant_a,
        .participant_b = instance.participant_b,
        .elapsed_ticks = instance.elapsed_ticks,
        .event_counts = instance.event_counts,
        .event_ticks = instance.event_ticks,
        .owned_override_count = instance.owned_override_count,
        .arm_ik = .{
            .weight = instance.ik.weight,
            .shared_target = instance.ik.shared_target,
            .target_valid = instance.ik.target_valid,
        },
    };
    if (instance.ik.role_a) |role| {
        result.arm_ik.role_a_reachable = role.reachability == .reachable;
        result.arm_ik.role_a_hand_target_error = role.target_error;
    }
    if (instance.ik.role_b) |role| {
        result.arm_ik.role_b_reachable = role.reachability == .reachable;
        result.arm_ik.role_b_hand_target_error = role.target_error;
    }
    return result;
}

fn accumulateCharacterAllocations(result: *AllocationSnapshot, instance: *const character.CharacterInstance) void {
    const hot_path = instance.hotPathMetrics();
    const animator_metrics = instance.animatorMetrics();
    const procedural = instance.proceduralSnapshot();
    const feet = instance.footPlantingSnapshot();
    result.animator += hot_path.animator_allocations + animator_metrics.clip_sampling_allocations +
        animator_metrics.pose_blending_allocations + animator_metrics.event_traversal_allocations +
        animator_metrics.animator_update_allocations + animator_metrics.state_transition_allocations;
    result.procedural_motion += hot_path.procedural_allocations +
        procedural.metrics.walk_update_allocations + procedural.metrics.landing_event_allocations +
        procedural.metrics.spring_update_allocations + procedural.metrics.secondary_update_allocations +
        procedural.metrics.pose_composition_allocations;
    result.arm_ik += hot_path.ik_solver_allocations + hot_path.ik_binding_lookup_allocations +
        hot_path.ik_pose_application_allocations + hot_path.ik_hierarchy_evaluation_allocations;
    result.foot_planting += hot_path.foot_plant_update_allocations + hot_path.leg_binding_allocations +
        hot_path.leg_ik_allocations + hot_path.foot_target_allocations;
    result.ground_query += hot_path.ground_query_allocations;
    result.pose_evaluation += hot_path.pose_allocations + feet.metrics.pose_evaluation_allocations;
    result.layer_resolution += hot_path.layer_resolution_allocations + hot_path.override_allocations;
    result.sprite_submission += hot_path.submission_allocations;
}

fn discardedTicks(seconds: f64) u64 {
    if (seconds <= 0) return 0;
    return @intFromFloat(@round(seconds / fixed_step.fixed_dt_seconds));
}

comptime {
    if (history_capacity == 0) @compileError("diagnostic history must be bounded and non-empty");
    if (@sizeOf(History) > 256 * 1024) @compileError("diagnostic history must remain bounded scalar storage");
}
