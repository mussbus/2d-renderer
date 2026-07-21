const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const collision_world = @import("collision_world");
const events = @import("events");
const fixed_step = @import("fixed_step");
const skeleton = @import("skeleton");
const pose = @import("pose");
const leg_ik = @import("leg_ik");
const two_bone = @import("two_bone_ik");

pub const fixed_dt: f32 = @floatCast(fixed_step.fixed_dt_seconds);
pub const ground_query_origin_lift: f32 = 1.00;
pub const maximum_ground_query_distance: f32 = 2.00;
pub const ground_query_epsilon: f32 = 0.00001;
pub const sole_offset: f32 = 0;
pub const plant_acquisition_duration: f32 = 0.10;
pub const plant_release_duration: f32 = 0.08;
pub const left_stance_end_phase: f32 = 0.58;
pub const right_stance_start_phase: f32 = 0.50;
pub const reach_release_margin: f32 = 0.02;
pub const full_plant_error_tolerance: f32 = 0.0002;

pub const PlantState = enum(u8) {
    swing,
    plant_candidate,
    planted,
    releasing,
};

pub const EventKey = struct {
    clip_id: u8,
    loop_index: u64,
    event_id: u16,
};

pub const GroundSample = struct {
    hit: bool = false,
    collider_id: collider.ColliderId = collider.invalid_collider_id,
    hit_position: math.Vec2 = math.Vec2.zero,
    ground_height: f32 = 0,
    normal: math.Vec2 = math.Vec2.zero,
    query_distance: f32 = 0,

    fn fromHit(hit: collision_world.GroundHit) GroundSample {
        return .{
            .hit = true,
            .collider_id = hit.collider_id,
            .hit_position = hit.position,
            .ground_height = hit.ground_height,
            .normal = hit.normal,
            .query_distance = hit.query_distance,
        };
    }
};

pub const LifecycleRecord = struct {
    semantic_contact_tick: ?u64 = null,
    candidate_acquisition_tick: ?u64 = null,
    full_plant_tick: ?u64 = null,
    release_start_tick: ?u64 = null,
    full_release_tick: ?u64 = null,

    pub fn isChronological(record: LifecycleRecord) bool {
        if (record.candidate_acquisition_tick != null and record.semantic_contact_tick == null) return false;
        if (record.full_plant_tick != null and record.candidate_acquisition_tick == null) return false;
        if (record.full_release_tick != null and record.release_start_tick == null) return false;
        var previous: ?u64 = null;
        for ([_]?u64{
            record.semantic_contact_tick,
            record.candidate_acquisition_tick,
            record.full_plant_tick,
            record.release_start_tick,
            record.full_release_tick,
        }) |tick| {
            if (tick) |value| {
                if (previous != null and previous.? > value) return false;
                previous = value;
            }
        }
        return true;
    }
};

pub const FootMetrics = struct {
    first_contact_tick: ?u64 = null,
    last_semantic_contact_tick: ?u64 = null,
    last_candidate_acquisition_tick: ?u64 = null,
    first_plant_tick: ?u64 = null,
    last_plant_tick: ?u64 = null,
    first_release_tick: ?u64 = null,
    last_release_start_tick: ?u64 = null,
    last_fully_released_tick: ?u64 = null,
    maximum_world_space_slip: f32 = 0,
    maximum_penetration: f32 = 0,
    maximum_hover: f32 = 0,
    stable_plant_ticks: u64 = 0,
    contact_events: u32 = 0,
    plant_acquisitions: u32 = 0,
    full_plants: u32 = 0,
    releases_started: u32 = 0,
    full_releases: u32 = 0,
    rejected_no_ground: u32 = 0,
    rejected_airborne: u32 = 0,
    rejected_unreachable: u32 = 0,
    latest_acquired_lifecycle: LifecycleRecord = .{},
};

pub const AppliedLocals = struct {
    applied: bool = false,
    pre_hip_local: math.Transform2D = math.Transform2D.identity(),
    pre_knee_local: math.Transform2D = math.Transform2D.identity(),
};

pub const FootRuntime = struct {
    plant_state: PlantState = .swing,
    plant_weight: f32 = 0,
    locked_target: ?math.Vec2 = null,
    locked_collider_id: ?collider.ColliderId = null,
    last_ground_sample: GroundSample = .{},
    last_consumed_event: ?EventKey = null,
    pending_contact: bool = false,
    pending_contact_tick: ?u64 = null,
    previous_visual_foot_position: ?math.Vec2 = null,
    pre_ik_sole: math.Vec2 = math.Vec2.zero,
    post_ik_sole: math.Vec2 = math.Vec2.zero,
    target_error: f32 = 0,
    world_space_slip: f32 = 0,
    penetration: f32 = 0,
    hover: f32 = 0,
    reachability: ?leg_ik.Reachability = null,
    applied: AppliedLocals = .{},
    metrics: FootMetrics = .{},

    pub fn hasLock(runtime: FootRuntime) bool {
        return runtime.locked_target != null and runtime.locked_collider_id != null;
    }
};

pub const HotPathMetrics = struct {
    fixed_ticks: u64 = 0,
    ground_query_allocations: u64 = 0,
    plant_update_allocations: u64 = 0,
    leg_binding_allocations: u64 = 0,
    leg_ik_allocations: u64 = 0,
    target_storage_allocations: u64 = 0,
    pose_evaluation_allocations: u64 = 0,
    false_airborne_plants: u32 = 0,
};

pub const State = struct {
    enabled: bool = true,
    left: FootRuntime = .{},
    right: FootRuntime = .{},
    metrics: HotPathMetrics = .{},

    pub fn reset(state: *State) void {
        const enabled = state.enabled;
        state.* = .{ .enabled = enabled };
    }

    pub fn setEnabled(state: *State, enabled: bool) void {
        state.* = .{ .enabled = enabled };
    }

    pub fn foot(state: *State, anatomical: leg_ik.AnatomicalFoot) *FootRuntime {
        return switch (anatomical) {
            .left => &state.left,
            .right => &state.right,
        };
    }

    pub fn footConst(state: *const State, anatomical: leg_ik.AnatomicalFoot) *const FootRuntime {
        return switch (anatomical) {
            .left => &state.left,
            .right => &state.right,
        };
    }
};

pub const TickInput = struct {
    world: *const collision_world.CollisionWorld,
    definition: *const skeleton.SkeletonDefinition,
    mutable_pose: *pose.Pose,
    character_to_world: math.Transform2D,
    left_binding: leg_ik.Binding,
    right_binding: leg_ik.Binding,
    facing_left: bool,
    physically_grounded: bool,
    walking_state: bool,
    walk_phase: f32,
    walk_weight: f32,
    emitted_events: []const events.EmittedEvent,
    simulation_tick: u64,
};

const FrozenInput = struct {
    binding: leg_ik.Binding,
    pre_sole: math.Vec2,
    hip: math.Vec2,
    contact: ?EventKey,
};

pub fn updateAndApply(state: *State, input: TickInput) !void {
    try validateTickInput(input);
    if (!input.mutable_pose.evaluated) return error.PoseNotEvaluated;
    state.metrics.fixed_ticks += 1;

    const left_frozen = try freezeFoot(input, .left, input.left_binding);
    const right_frozen = try freezeFoot(input, .right, input.right_binding);
    state.left.pre_ik_sole = left_frozen.pre_sole;
    state.right.pre_ik_sole = right_frozen.pre_sole;
    state.left.applied = .{};
    state.right.applied = .{};

    if (!state.enabled) {
        clearInactive(&state.left, left_frozen.pre_sole);
        clearInactive(&state.right, right_frozen.pre_sole);
        return;
    }

    try prepareFoot(&state.left, input, left_frozen, .left);
    try prepareFoot(&state.right, input, right_frozen, .right);
    try applyPrepared(&state.left, input, left_frozen);
    try applyPrepared(&state.right, input, right_frozen);
}

pub fn restoreApplied(
    state: *State,
    mutable_pose: *pose.Pose,
    definition: *const skeleton.SkeletonDefinition,
    character_to_world: math.Transform2D,
    left_binding: leg_ik.Binding,
    right_binding: leg_ik.Binding,
) !void {
    if (state.left.applied.applied) {
        const saved = state.left.applied;
        state.left.applied = .{};
        try leg_ik.restore(left_binding, mutable_pose, definition, character_to_world, saved.pre_hip_local, saved.pre_knee_local);
    }
    if (state.right.applied.applied) {
        const saved = state.right.applied;
        state.right.applied = .{};
        try leg_ik.restore(right_binding, mutable_pose, definition, character_to_world, saved.pre_hip_local, saved.pre_knee_local);
    }
}

fn freezeFoot(input: TickInput, foot: leg_ik.AnatomicalFoot, binding: leg_ik.Binding) !FrozenInput {
    const pre_sole = try input.mutable_pose.socketPosition(input.definition, foot.socketSemantic());
    const hip = (try input.mutable_pose.worldForBone(input.definition, binding.hip_bone)).translationPart();
    var contact: ?EventKey = null;
    const expected: events.EventType = switch (foot) {
        .left => .left_foot_contact,
        .right => .right_foot_contact,
    };
    for (input.emitted_events) |emitted| {
        if (emitted.record.event_type == expected) {
            contact = .{ .clip_id = emitted.clip_id, .loop_index = emitted.loop_index, .event_id = emitted.record.id };
            break;
        }
    }
    return .{ .binding = binding, .pre_sole = pre_sole, .hip = hip, .contact = contact };
}

fn prepareFoot(
    runtime: *FootRuntime,
    input: TickInput,
    frozen: FrozenInput,
    foot: leg_ik.AnatomicalFoot,
) !void {
    runtime.last_ground_sample = try sampleGround(input.world, frozen.pre_sole);
    runtime.previous_visual_foot_position = frozen.pre_sole;

    if (!input.physically_grounded) {
        if (frozen.contact != null) {
            runtime.metrics.rejected_airborne += 1;
        }
        recordRelease(runtime, input.simulation_tick);
        runtime.pending_contact = false;
        runtime.pending_contact_tick = null;
        clearLock(runtime, frozen.pre_sole, input.simulation_tick);
        return;
    }

    if (runtime.hasLock() and !lockedSurfaceValid(input.world, runtime.*)) beginRelease(runtime, input.simulation_tick);
    if (runtime.hasLock() and !targetReachable(frozen.binding, frozen.hip, runtime.locked_target.?, reach_release_margin)) beginRelease(runtime, input.simulation_tick);
    const stance_active = input.walking_state and input.walk_weight > 0 and inStance(foot, input.walk_phase);
    if (!stance_active) {
        runtime.pending_contact = false;
        runtime.pending_contact_tick = null;
        beginRelease(runtime, input.simulation_tick);
    }

    if (frozen.contact) |event_key| {
        runtime.last_consumed_event = event_key;
        runtime.metrics.contact_events += 1;
        runtime.metrics.last_semantic_contact_tick = input.simulation_tick;
        if (runtime.metrics.first_contact_tick == null) runtime.metrics.first_contact_tick = input.simulation_tick;
        if (input.walking_state and input.walk_weight > 0 and !runtime.hasLock() and runtime.plant_state != .releasing) {
            if (!runtime.pending_contact) runtime.pending_contact_tick = input.simulation_tick;
            runtime.pending_contact = true;
        }
    }

    if (runtime.pending_contact and stance_active and !runtime.hasLock() and runtime.plant_state != .releasing) {
        if (!runtime.last_ground_sample.hit) {
            if (frozen.contact != null) runtime.metrics.rejected_no_ground += 1;
        } else {
            const target = math.Vec2{
                .x = frozen.pre_sole.x,
                .y = runtime.last_ground_sample.ground_height + sole_offset,
            };
            if (!targetReachable(frozen.binding, frozen.hip, target, 0)) {
                if (frozen.contact != null) runtime.metrics.rejected_unreachable += 1;
            } else {
                runtime.locked_target = target;
                runtime.locked_collider_id = runtime.last_ground_sample.collider_id;
                runtime.plant_state = .plant_candidate;
                runtime.pending_contact = false;
                runtime.metrics.latest_acquired_lifecycle = .{
                    .semantic_contact_tick = runtime.pending_contact_tick orelse input.simulation_tick,
                    .candidate_acquisition_tick = input.simulation_tick,
                };
                runtime.pending_contact_tick = null;
                runtime.metrics.last_candidate_acquisition_tick = input.simulation_tick;
                runtime.metrics.plant_acquisitions += 1;
            }
        }
    }

    switch (runtime.plant_state) {
        .swing => runtime.plant_weight = 0,
        .plant_candidate => {
            runtime.plant_weight = moveToward(runtime.plant_weight, 1, fixed_dt / plant_acquisition_duration);
            if (runtime.plant_weight == 1) {
                runtime.plant_state = .planted;
                if (runtime.metrics.first_plant_tick == null) runtime.metrics.first_plant_tick = input.simulation_tick;
                runtime.metrics.last_plant_tick = input.simulation_tick;
                runtime.metrics.full_plants += 1;
                runtime.metrics.latest_acquired_lifecycle.full_plant_tick = input.simulation_tick;
            }
        },
        .planted => runtime.plant_weight = 1,
        .releasing => {
            runtime.plant_weight = moveToward(runtime.plant_weight, 0, fixed_dt / plant_release_duration);
            if (runtime.plant_weight == 0) clearLock(runtime, frozen.pre_sole, input.simulation_tick);
        },
    }
}

fn applyPrepared(runtime: *FootRuntime, input: TickInput, frozen: FrozenInput) !void {
    runtime.post_ik_sole = frozen.pre_sole;
    runtime.target_error = 0;
    runtime.world_space_slip = 0;
    runtime.penetration = 0;
    runtime.hover = 0;
    runtime.reachability = null;
    const target = runtime.locked_target orelse return;
    if (runtime.plant_weight <= 0) return;
    const bend_world = if (input.facing_left)
        frozen.binding.character_local_bend.opposite()
    else
        frozen.binding.character_local_bend;
    const application = try leg_ik.apply(
        frozen.binding,
        input.mutable_pose,
        input.definition,
        input.character_to_world,
        target,
        bend_world,
        runtime.plant_weight,
    );
    runtime.applied = .{
        .applied = true,
        .pre_hip_local = application.pre_hip_local,
        .pre_knee_local = application.pre_knee_local,
    };
    runtime.post_ik_sole = application.metrics.post_ik_sole_position;
    runtime.target_error = application.metrics.target_error;
    runtime.world_space_slip = application.metrics.post_ik_sole_position.sub(target).length();
    runtime.penetration = @max(target.y - application.metrics.post_ik_sole_position.y, 0);
    runtime.hover = @max(application.metrics.post_ik_sole_position.y - target.y, 0);
    runtime.reachability = application.metrics.reachability;
    if (runtime.plant_state == .planted and runtime.plant_weight == 1 and application.metrics.reachability == .reachable) {
        runtime.metrics.stable_plant_ticks += 1;
        runtime.metrics.maximum_world_space_slip = @max(runtime.metrics.maximum_world_space_slip, runtime.world_space_slip);
        runtime.metrics.maximum_penetration = @max(runtime.metrics.maximum_penetration, runtime.penetration);
        runtime.metrics.maximum_hover = @max(runtime.metrics.maximum_hover, runtime.hover);
    }
}

fn sampleGround(world: *const collision_world.CollisionWorld, pre_sole: math.Vec2) !GroundSample {
    const origin = pre_sole.add(.{ .x = 0, .y = ground_query_origin_lift });
    const hit = try world.queryGroundDown(origin, maximum_ground_query_distance, ground_query_epsilon);
    return if (hit) |value| GroundSample.fromHit(value) else .{};
}

fn lockedSurfaceValid(world: *const collision_world.CollisionWorld, runtime: FootRuntime) bool {
    const id = runtime.locked_collider_id orelse return false;
    const target = runtime.locked_target orelse return false;
    for (world.colliders) |static_collider| {
        if (static_collider.id != id or !static_collider.solid or !static_collider.ground_query_eligible) continue;
        return target.x >= static_collider.bounds.minimum.x - ground_query_epsilon and
            target.x <= static_collider.bounds.maximum.x + ground_query_epsilon and
            @abs(target.y - (static_collider.bounds.maximum.y + sole_offset)) <= ground_query_epsilon;
    }
    return false;
}

fn targetReachable(binding: leg_ik.Binding, hip: math.Vec2, target: math.Vec2, margin: f32) bool {
    const distance = target.sub(hip).length();
    const minimum = @abs(binding.upper_length - binding.lower_length) + two_bone.reach_epsilon;
    const maximum = binding.upper_length + binding.lower_length - two_bone.reach_epsilon;
    return std.math.isFinite(distance) and distance >= minimum - margin and distance <= maximum + margin;
}

fn beginRelease(runtime: *FootRuntime, simulation_tick: u64) void {
    if (runtime.hasLock() and runtime.plant_state != .releasing) {
        recordRelease(runtime, simulation_tick);
        runtime.plant_state = .releasing;
    }
}

fn recordRelease(runtime: *FootRuntime, simulation_tick: u64) void {
    if (!runtime.hasLock() or runtime.plant_state == .releasing) return;
    if (runtime.metrics.first_release_tick == null) runtime.metrics.first_release_tick = simulation_tick;
    runtime.metrics.last_release_start_tick = simulation_tick;
    runtime.metrics.releases_started += 1;
    runtime.metrics.latest_acquired_lifecycle.release_start_tick = simulation_tick;
}

fn clearLock(runtime: *FootRuntime, visual_position: math.Vec2, simulation_tick: ?u64) void {
    const had_lock = runtime.hasLock();
    runtime.plant_state = .swing;
    runtime.plant_weight = 0;
    runtime.locked_target = null;
    runtime.locked_collider_id = null;
    runtime.pending_contact = false;
    runtime.pending_contact_tick = null;
    runtime.post_ik_sole = visual_position;
    runtime.target_error = 0;
    runtime.world_space_slip = 0;
    runtime.penetration = 0;
    runtime.hover = 0;
    runtime.reachability = null;
    runtime.applied = .{};
    if (had_lock) {
        runtime.metrics.last_fully_released_tick = simulation_tick;
        runtime.metrics.full_releases += 1;
        runtime.metrics.latest_acquired_lifecycle.full_release_tick = simulation_tick;
    }
}

fn clearInactive(runtime: *FootRuntime, visual_position: math.Vec2) void {
    clearLock(runtime, visual_position, null);
    runtime.last_ground_sample = .{};
}

pub fn inStance(foot: leg_ik.AnatomicalFoot, phase_value: f32) bool {
    const phase = normalizedPhase(phase_value);
    return switch (foot) {
        .left => phase < left_stance_end_phase,
        .right => phase >= right_stance_start_phase,
    };
}

fn normalizedPhase(value: f32) f32 {
    return value - @floor(value);
}

fn moveToward(value: f32, target: f32, maximum_delta: f32) f32 {
    if (value < target) return @min(value + maximum_delta, target);
    return @max(value - maximum_delta, target);
}

fn validateTickInput(input: TickInput) !void {
    if (!input.character_to_world.isFinite() or !std.math.isFinite(input.walk_phase) or !std.math.isFinite(input.walk_weight)) {
        return error.NonFiniteFootPlantInput;
    }
    if (input.walk_weight < 0 or input.walk_weight > 1) return error.InvalidWalkWeight;
    if (input.left_binding.foot != .left or input.right_binding.foot != .right) return error.AnatomicalBindingMismatch;
}

comptime {
    if (fixed_dt != @as(f32, 1.0 / 240.0)) @compileError("foot planting must use the authoritative 240 Hz timestep");
    if (plant_acquisition_duration <= 0 or plant_release_duration <= 0) @compileError("foot blend durations must be positive");
    if (left_stance_end_phase <= right_stance_start_phase) @compileError("stance intervals must overlap for a deterministic dual-contact transition");
    if (@sizeOf(State) > 1024) @compileError("foot planting state must remain inline per character");
}
