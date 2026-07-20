const std = @import("std");
const fixed_step = @import("fixed_step");
const spring = @import("spring");
const skeleton = @import("skeleton");
const pose = @import("pose");

pub const procedural_fixed_dt: f32 = @floatCast(fixed_step.fixed_dt_seconds);
pub const minimum_visual_root_offset_y: f32 = -0.060;
pub const maximum_visual_root_offset_y: f32 = 0.045;

pub const walk_minimum_active_speed: f32 = 0.12;
pub const walk_full_amplitude_speed: f32 = 4.50;
pub const walk_maximum_amplitude: f32 = 0.040;
pub const walk_blend_in_rate: f32 = 0.24;
pub const walk_blend_out_rate: f32 = 0.40;

pub const landing_minimum_trigger_impact: f32 = 1.0;
pub const landing_nominal_impact: f32 = 5.25;
pub const landing_maximum_mapped_impact: f32 = 10.0;
pub const landing_minimum_impulse: f32 = 0.35;
pub const landing_maximum_impulse: f32 = 2.0;
pub const landing_spring_configuration = spring.Configuration{
    .stiffness = 180.0,
    .damping = 22.0,
    .maximum_displacement = 0.060,
    .maximum_velocity = 2.40,
};

pub const secondary_target_radians_per_acceleration: f32 = 0.0025;
pub const secondary_spring_configuration = spring.Configuration{
    .stiffness = 96.0,
    .damping = 17.0,
    .maximum_displacement = 0.120,
    .maximum_velocity = 2.50,
};

pub const LandingEvent = struct {
    simulation_tick: u64,
    impact_speed: f32,
};

pub const TickInput = struct {
    horizontal_velocity: f32,
    physically_grounded: bool,
    walk_cycle_phase: f32,
    walk_layer_weight: f32,
    landing_event: ?LandingEvent = null,
};

pub const ContactFoot = enum(u8) { left, right };

pub const ContactPhase = struct {
    foot: ContactFoot,
    contact_relative_phase: f32,
};

pub const HotPathMetrics = struct {
    walk_update_allocations: u64 = 0,
    landing_event_allocations: u64 = 0,
    spring_update_allocations: u64 = 0,
    secondary_update_allocations: u64 = 0,
    pose_composition_allocations: u64 = 0,
    fixed_ticks: u64 = 0,
    landing_impulses: u32 = 0,
    pose_compositions: u64 = 0,
};

pub const State = struct {
    enabled: bool = true,
    walk_cycle_phase: f32 = 0,
    walk_bounce_offset: f32 = 0,
    walk_bounce_amplitude: f32 = 0,
    landing_spring: spring.State = .{},
    secondary_spring: spring.State = .{},
    visual_root_offset_y: f32 = 0,
    previous_horizontal_velocity: f32 = 0,
    last_landing_impact_speed: f32 = 0,
    last_landing_impulse: f32 = 0,
    landing_peak_displacement: f32 = 0,
    secondary_peak_displacement: f32 = 0,
    last_consumed_landing_tick: ?u64 = null,
    last_composed_simulation_tick: ?u64 = null,
    metrics: HotPathMetrics = .{},

    pub fn init() !State {
        try landing_spring_configuration.validate(procedural_fixed_dt);
        try secondary_spring_configuration.validate(procedural_fixed_dt);
        try validateConstants();
        return .{};
    }

    pub fn reset(state: *State, horizontal_velocity: f32) !void {
        if (!std.math.isFinite(horizontal_velocity)) return error.NonFiniteProceduralInput;
        const enabled = state.enabled;
        state.* = .{ .enabled = enabled, .previous_horizontal_velocity = horizontal_velocity };
    }

    pub fn setEnabled(state: *State, enabled: bool, horizontal_velocity: f32) !void {
        state.enabled = enabled;
        try state.reset(horizontal_velocity);
    }

    pub fn update(state: *State, tick_input: TickInput) !void {
        try validateTickInput(tick_input);
        state.metrics.fixed_ticks += 1;

        if (!state.enabled) {
            state.previous_horizontal_velocity = tick_input.horizontal_velocity;
            state.walk_cycle_phase = normalizedPhase(tick_input.walk_cycle_phase);
            state.walk_bounce_offset = 0;
            state.walk_bounce_amplitude = 0;
            state.landing_spring.reset();
            state.secondary_spring.reset();
            state.visual_root_offset_y = 0;
            state.last_landing_impact_speed = 0;
            state.last_landing_impulse = 0;
            state.landing_peak_displacement = 0;
            state.secondary_peak_displacement = 0;
            state.last_consumed_landing_tick = null;
            return;
        }

        if (tick_input.landing_event) |event| try state.consumeLandingEvent(event);

        const desired_amplitude = if (tick_input.physically_grounded)
            walkAmplitudeForSpeed(tick_input.horizontal_velocity) * tick_input.walk_layer_weight
        else
            0;
        const blend_rate = if (desired_amplitude > state.walk_bounce_amplitude) walk_blend_in_rate else walk_blend_out_rate;
        state.walk_bounce_amplitude = moveToward(
            state.walk_bounce_amplitude,
            desired_amplitude,
            blend_rate * procedural_fixed_dt,
        );
        state.walk_cycle_phase = normalizedPhase(tick_input.walk_cycle_phase);
        state.walk_bounce_offset = if (tick_input.physically_grounded)
            try walkOffsetAtPhase(state.walk_cycle_phase, state.walk_bounce_amplitude)
        else
            0;

        try state.landing_spring.setTarget(0, landing_spring_configuration);
        try state.landing_spring.step(landing_spring_configuration, procedural_fixed_dt);
        state.landing_peak_displacement = @min(state.landing_peak_displacement, state.landing_spring.offset);

        const acceleration = (tick_input.horizontal_velocity - state.previous_horizontal_velocity) / procedural_fixed_dt;
        if (!std.math.isFinite(acceleration)) return error.NonFiniteProceduralInput;
        const secondary_target = std.math.clamp(
            -acceleration * secondary_target_radians_per_acceleration,
            -secondary_spring_configuration.maximum_displacement,
            secondary_spring_configuration.maximum_displacement,
        );
        try state.secondary_spring.setTarget(secondary_target, secondary_spring_configuration);
        try state.secondary_spring.step(secondary_spring_configuration, procedural_fixed_dt);
        state.secondary_peak_displacement = @max(state.secondary_peak_displacement, @abs(state.secondary_spring.offset));
        state.previous_horizontal_velocity = tick_input.horizontal_velocity;

        state.visual_root_offset_y = std.math.clamp(
            state.walk_bounce_offset + state.landing_spring.offset,
            minimum_visual_root_offset_y,
            maximum_visual_root_offset_y,
        );
    }

    pub fn composePose(
        state: *State,
        definition: *const skeleton.SkeletonDefinition,
        local_pose: *pose.Pose,
        simulation_tick: u64,
    ) !void {
        if (state.last_composed_simulation_tick == simulation_tick) return error.ProceduralPoseAlreadyComposed;
        try local_pose.validateCompatibility(definition);
        if (state.enabled) {
            const root_index = try definition.boneIndex(.root);
            var root = local_pose.local_transforms[root_index];
            root.translation.y += state.visual_root_offset_y;
            try local_pose.setLocal(root_index, root);

            const head_index = try definition.boneIndex(.head);
            var head = local_pose.local_transforms[head_index];
            head.rotation_radians += state.secondary_spring.offset;
            try local_pose.setLocal(head_index, head);
        }
        state.last_composed_simulation_tick = simulation_tick;
        state.metrics.pose_compositions += 1;
    }

    fn consumeLandingEvent(state: *State, event: LandingEvent) !void {
        if (state.last_consumed_landing_tick == event.simulation_tick) return;
        const impulse = try landingImpulseForImpact(event.impact_speed);
        state.last_consumed_landing_tick = event.simulation_tick;
        state.last_landing_impact_speed = event.impact_speed;
        state.last_landing_impulse = @abs(impulse);
        state.landing_peak_displacement = 0;
        if (impulse != 0) {
            try state.landing_spring.applyVelocityImpulse(impulse, landing_spring_configuration);
            state.metrics.landing_impulses += 1;
        }
    }
};

pub fn walkAmplitudeForSpeed(horizontal_velocity: f32) f32 {
    if (!std.math.isFinite(horizontal_velocity)) return 0;
    const speed = @abs(horizontal_velocity);
    if (speed <= walk_minimum_active_speed) return 0;
    const normalized = std.math.clamp(
        (speed - walk_minimum_active_speed) / (walk_full_amplitude_speed - walk_minimum_active_speed),
        0,
        1,
    );
    return walk_maximum_amplitude * normalized;
}

pub fn contactPhase(walk_cycle_phase: f32) !ContactPhase {
    if (!std.math.isFinite(walk_cycle_phase)) return error.NonFiniteWalkPhase;
    const phase = normalizedPhase(walk_cycle_phase);
    if (phase < 0.5) return .{ .foot = .left, .contact_relative_phase = phase * 2 };
    return .{ .foot = .right, .contact_relative_phase = (phase - 0.5) * 2 };
}

/// A contact-relative authored curve: contact (0), compression (0.18),
/// support pass-through (0.50), rise (0.76), then opposite contact (1).
pub fn walkOffsetAtPhase(walk_cycle_phase: f32, amplitude: f32) !f32 {
    if (!std.math.isFinite(amplitude) or amplitude < 0) return error.InvalidWalkAmplitude;
    const contact = try contactPhase(walk_cycle_phase);
    const value = if (contact.contact_relative_phase < 0.18)
        smoothSegment(contact.contact_relative_phase, 0, 0.18, 0, -0.35)
    else if (contact.contact_relative_phase < 0.50)
        smoothSegment(contact.contact_relative_phase, 0.18, 0.50, -0.35, 0)
    else if (contact.contact_relative_phase < 0.76)
        smoothSegment(contact.contact_relative_phase, 0.50, 0.76, 0, 1)
    else
        smoothSegment(contact.contact_relative_phase, 0.76, 1, 1, 0);
    return value * @min(amplitude, walk_maximum_amplitude);
}

pub fn landingImpulseForImpact(impact_speed: f32) !f32 {
    if (!std.math.isFinite(impact_speed) or impact_speed < 0) return error.InvalidLandingImpact;
    if (impact_speed <= landing_minimum_trigger_impact) return 0;
    const normalized = std.math.clamp(
        (impact_speed - landing_minimum_trigger_impact) /
            (landing_maximum_mapped_impact - landing_minimum_trigger_impact),
        0,
        1,
    );
    const curved = normalized * normalized * (3 - 2 * normalized);
    const magnitude = landing_minimum_impulse +
        (landing_maximum_impulse - landing_minimum_impulse) * curved;
    return -magnitude;
}

fn validateConstants() !void {
    const values = [_]f32{
        walk_minimum_active_speed,
        walk_full_amplitude_speed,
        walk_maximum_amplitude,
        walk_blend_in_rate,
        walk_blend_out_rate,
        landing_minimum_trigger_impact,
        landing_nominal_impact,
        landing_maximum_mapped_impact,
        landing_minimum_impulse,
        landing_maximum_impulse,
        secondary_target_radians_per_acceleration,
        minimum_visual_root_offset_y,
        maximum_visual_root_offset_y,
    };
    for (values) |value| if (!std.math.isFinite(value)) return error.InvalidProceduralConfiguration;
    if (walk_minimum_active_speed < 0 or walk_full_amplitude_speed <= walk_minimum_active_speed or
        walk_maximum_amplitude < 0 or walk_blend_in_rate <= 0 or walk_blend_out_rate <= 0)
    {
        return error.InvalidProceduralConfiguration;
    }
    if (landing_minimum_trigger_impact < 0 or landing_nominal_impact <= landing_minimum_trigger_impact or
        landing_maximum_mapped_impact <= landing_nominal_impact or landing_minimum_impulse < 0 or
        landing_maximum_impulse < landing_minimum_impulse)
    {
        return error.InvalidProceduralConfiguration;
    }
    if (minimum_visual_root_offset_y > 0 or maximum_visual_root_offset_y < 0) return error.InvalidProceduralConfiguration;
}

fn validateTickInput(tick_input: TickInput) !void {
    const values = [_]f32{
        tick_input.horizontal_velocity,
        tick_input.walk_cycle_phase,
        tick_input.walk_layer_weight,
    };
    for (values) |value| if (!std.math.isFinite(value)) return error.NonFiniteProceduralInput;
    if (tick_input.walk_layer_weight < 0 or tick_input.walk_layer_weight > 1) return error.InvalidWalkLayerWeight;
}

fn normalizedPhase(value: f32) f32 {
    const whole = @floor(value);
    return value - whole;
}

fn smoothSegment(value: f32, start: f32, end: f32, from: f32, to: f32) f32 {
    const normalized = std.math.clamp((value - start) / (end - start), 0, 1);
    const smooth = normalized * normalized * (3 - 2 * normalized);
    return from + (to - from) * smooth;
}

fn moveToward(value: f32, target: f32, maximum_delta: f32) f32 {
    if (value < target) return @min(value + maximum_delta, target);
    return @max(value - maximum_delta, target);
}

comptime {
    if (@sizeOf(State) > 256) @compileError("procedural state must remain compact and embedded per character");
    if (procedural_fixed_dt != @as(f32, 1.0 / 240.0)) @compileError("procedural motion must use the authoritative 240 Hz timestep");
}
