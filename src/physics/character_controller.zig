const std = @import("std");
const math = @import("math");
const character_intent = @import("character_intent");
const collider = @import("collider");
const collision_world = @import("collision_world");
const fixed_step = @import("fixed_step");

pub const Facing = enum(u8) { left, right };
pub const JumpSource = enum(u8) { grounded, coyote, buffered, air };
pub const additional_air_jumps_with_double_jump: u8 = 1;

pub const Configuration = struct {
    fixed_dt: f32 = @floatCast(fixed_step.fixed_dt_seconds),
    gravity: f32 = -28.0,
    ground_acceleration: f32 = 36.0,
    air_acceleration: f32 = 18.0,
    ground_deceleration: f32 = 44.0,
    maximum_run_speed: f32 = 4.5,
    jump_speed: f32 = 9.0,
    jump_release_speed: f32 = 3.5,
    dash_speed: f32 = 12.0,
    dash_duration: f32 = 0.12,
    dash_reuse_delay: f32 = 0.20,
    coyote_duration: f32 = 0.10,
    jump_buffer_duration: f32 = 0.125,
    maximum_fall_speed: f32 = 18.0,
    collider_half_extents: math.Vec2 = .{ .x = 0.30, .y = 1.05 },
    ground_epsilon: f32 = 0.0001,
    landing_impact_threshold: f32 = 0.25,
    facing_threshold: f32 = 0.20,

    pub fn validate(configuration: Configuration) !void {
        const scalars = [_]f32{
            configuration.fixed_dt,
            configuration.gravity,
            configuration.ground_acceleration,
            configuration.air_acceleration,
            configuration.ground_deceleration,
            configuration.maximum_run_speed,
            configuration.jump_speed,
            configuration.jump_release_speed,
            configuration.dash_speed,
            configuration.dash_duration,
            configuration.dash_reuse_delay,
            configuration.coyote_duration,
            configuration.jump_buffer_duration,
            configuration.maximum_fall_speed,
            configuration.ground_epsilon,
            configuration.landing_impact_threshold,
            configuration.facing_threshold,
        };
        for (scalars) |value| if (!std.math.isFinite(value)) return error.NonFinitePhysicsConfiguration;
        if (configuration.fixed_dt <= 0) return error.InvalidFixedTimestep;
        if (@abs(configuration.fixed_dt - @as(f32, @floatCast(fixed_step.fixed_dt_seconds))) > 1e-8) return error.InvalidFixedTimestep;
        if (configuration.gravity >= 0) return error.InvalidGravity;
        if (configuration.ground_acceleration < 0 or configuration.air_acceleration < 0 or configuration.ground_deceleration < 0) return error.InvalidAcceleration;
        if (configuration.maximum_run_speed <= 0 or configuration.maximum_fall_speed <= 0) return error.InvalidMaximumSpeed;
        if (configuration.jump_speed <= 0 or configuration.jump_release_speed <= 0 or configuration.jump_release_speed >= configuration.jump_speed) return error.InvalidJumpConfiguration;
        if (configuration.dash_speed <= 0 or configuration.dash_duration <= 0 or configuration.dash_reuse_delay < 0) {
            return error.InvalidDashConfiguration;
        }
        if (configuration.coyote_duration < 0) return error.InvalidCoyoteDuration;
        if (configuration.jump_buffer_duration < 0) return error.InvalidJumpBufferDuration;
        if (!configuration.collider_half_extents.isFinite() or configuration.collider_half_extents.x <= 0 or configuration.collider_half_extents.y <= 0) return error.InvalidColliderDimensions;
        if (configuration.ground_epsilon < 0 or configuration.landing_impact_threshold < 0) return error.InvalidCollisionConfiguration;
        if (configuration.facing_threshold < 0 or configuration.facing_threshold > 1) return error.InvalidFacingThreshold;
        _ = try durationTicks(configuration.coyote_duration);
        _ = try durationTicks(configuration.jump_buffer_duration);
        _ = try durationTicks(configuration.dash_duration);
        _ = try durationTicks(configuration.dash_duration + configuration.dash_reuse_delay);
    }
};

pub const GameplayProperties = struct {
    maximum_run_speed: f32,
    jump_speed: f32,
    double_jump: bool = false,
    dash: bool = false,

    pub fn fromConfiguration(configuration: Configuration) GameplayProperties {
        return .{
            .maximum_run_speed = configuration.maximum_run_speed,
            .jump_speed = configuration.jump_speed,
        };
    }

    pub fn validate(properties: GameplayProperties, configuration: Configuration) !void {
        if (!std.math.isFinite(properties.maximum_run_speed) or properties.maximum_run_speed <= 0) {
            return error.InvalidResolvedMovementSpeed;
        }
        if (!std.math.isFinite(properties.jump_speed) or properties.jump_speed <= configuration.jump_release_speed) {
            return error.InvalidResolvedJumpStrength;
        }
    }
};

pub const State = struct {
    position: math.Vec2,
    previous_position: math.Vec2,
    velocity: math.Vec2 = math.Vec2.zero,
    facing: Facing,
    grounded: bool = false,
    previous_grounded: bool = false,
    ground_normal: math.Vec2 = math.Vec2.zero,
    supporting_collider: ?collider.ColliderId = null,
    previous_vertical_velocity: f32 = 0,
    last_landing_impact_speed: f32 = 0,
    last_landing_tick: ?u64 = null,
    last_jump_tick: ?u64 = null,
    coyote_ticks_remaining: u16 = 0,
    jump_buffer_ticks_remaining: u16 = 0,
    air_jumps_used: u8 = 0,
    jump_was_consumed: bool = false,
    dash_ticks_remaining: u16 = 0,
    dash_cooldown_ticks_remaining: u16 = 0,
    dash_direction: Facing = .right,
    simulation_tick: u64 = 0,
};

pub const StepResult = struct {
    simulation_tick: u64,
    jump_pressed: bool = false,
    jump_released: bool = false,
    jump_buffer_started: bool = false,
    jump_buffer_consumed: bool = false,
    jump_accepted: bool = false,
    jump_source: ?JumpSource = null,
    dash_pressed: bool = false,
    dash_started: bool = false,
    dash_denied: bool = false,
    dash_ended: bool = false,
    ground_left: bool = false,
    coyote_started: bool = false,
    coyote_consumed: bool = false,
    landed: bool = false,
    landing_impact_speed: f32 = 0,
    wall_collision: bool = false,
    ceiling_collision: bool = false,
};

pub const CharacterController = struct {
    configuration: Configuration,
    spawn_position: math.Vec2,
    spawn_facing: Facing,
    state: State,

    pub fn init(
        configuration: Configuration,
        world: *const collision_world.CollisionWorld,
        spawn_position: math.Vec2,
        spawn_facing: Facing,
    ) !CharacterController {
        try configuration.validate();
        if (!spawn_position.isFinite()) return error.NonFinitePosition;
        const bounds = try collider.characterBounds(spawn_position, configuration.collider_half_extents);
        if (world.containsPenetration(bounds)) return error.UnsupportedInitialPenetration;
        const support = try world.supportingCollider(bounds, configuration.ground_epsilon);
        const grounded = support != null;
        return .{
            .configuration = configuration,
            .spawn_position = spawn_position,
            .spawn_facing = spawn_facing,
            .state = makeState(spawn_position, spawn_facing, support, grounded),
        };
    }

    pub fn reset(controller: *CharacterController, world: *const collision_world.CollisionWorld) !void {
        const bounds = try collider.characterBounds(controller.spawn_position, controller.configuration.collider_half_extents);
        if (world.containsPenetration(bounds)) return error.UnsupportedInitialPenetration;
        const support = try world.supportingCollider(bounds, controller.configuration.ground_epsilon);
        controller.state = makeState(controller.spawn_position, controller.spawn_facing, support, support != null);
    }

    pub fn step(
        controller: *CharacterController,
        world: *const collision_world.CollisionWorld,
        intent: character_intent.CharacterIntent,
    ) !StepResult {
        return controller.stepWithProperties(world, intent, GameplayProperties.fromConfiguration(controller.configuration));
    }

    pub fn stepWithProperties(
        controller: *CharacterController,
        world: *const collision_world.CollisionWorld,
        intent: character_intent.CharacterIntent,
        properties: GameplayProperties,
    ) !StepResult {
        try intent.validate();
        try controller.validateState(world);
        const configuration = controller.configuration;
        try properties.validate(configuration);
        const state = &controller.state;
        const tick = state.simulation_tick;
        var result = StepResult{
            .simulation_tick = tick,
            .jump_pressed = intent.jump_pressed,
            .jump_released = intent.jump_released,
            .dash_pressed = intent.dash_pressed,
        };

        state.previous_position = state.position;
        state.previous_grounded = state.grounded;
        state.previous_vertical_velocity = state.velocity.y;
        state.jump_was_consumed = false;

        if (intent.jump_pressed) {
            state.jump_buffer_ticks_remaining = try durationTicks(configuration.jump_buffer_duration);
            result.jump_buffer_started = true;
        }

        if (state.dash_ticks_remaining == 0 and @abs(intent.move_axis) >= configuration.facing_threshold) {
            state.facing = if (intent.move_axis < 0) .left else .right;
        }

        if (state.jump_buffer_ticks_remaining > 0 and (state.grounded or state.coyote_ticks_remaining > 0)) {
            const source: JumpSource = if (state.grounded) .grounded else .coyote;
            acceptJump(state, properties.jump_speed, source, tick, &result);
        } else if (state.jump_buffer_ticks_remaining > 0 and
            properties.double_jump and
            state.air_jumps_used < additional_air_jumps_with_double_jump)
        {
            acceptJump(state, properties.jump_speed, .air, tick, &result);
        }

        if (intent.dash_pressed) {
            if (properties.dash and state.dash_ticks_remaining == 0 and state.dash_cooldown_ticks_remaining == 0) {
                state.dash_direction = if (@abs(intent.move_axis) >= configuration.facing_threshold)
                    (if (intent.move_axis < 0) .left else .right)
                else
                    state.facing;
                state.facing = state.dash_direction;
                state.dash_ticks_remaining = try durationTicks(configuration.dash_duration);
                state.dash_cooldown_ticks_remaining = try durationTicks(
                    configuration.dash_duration + configuration.dash_reuse_delay,
                );
                result.dash_started = true;
            } else {
                result.dash_denied = true;
            }
        }

        if (state.dash_ticks_remaining > 0) {
            state.velocity.x = if (state.dash_direction == .left) -configuration.dash_speed else configuration.dash_speed;
        } else {
            const target_velocity_x = intent.move_axis * properties.maximum_run_speed;
            const acceleration = if (state.grounded)
                (if (intent.move_axis == 0) configuration.ground_deceleration else configuration.ground_acceleration)
            else
                configuration.air_acceleration;
            state.velocity.x = moveToward(state.velocity.x, target_velocity_x, acceleration * configuration.fixed_dt);
            state.velocity.x = std.math.clamp(state.velocity.x, -properties.maximum_run_speed, properties.maximum_run_speed);
        }

        state.velocity.y += configuration.gravity * configuration.fixed_dt;
        state.velocity.y = @max(state.velocity.y, -configuration.maximum_fall_speed);
        if (intent.jump_released and state.velocity.y > configuration.jump_release_speed) {
            state.velocity.y = configuration.jump_release_speed;
        }

        const horizontal = try world.sweepHorizontal(
            state.position,
            configuration.collider_half_extents,
            state.velocity.x * configuration.fixed_dt,
            configuration.ground_epsilon,
        );
        state.position.x = horizontal.resolved_position_x;
        if (horizontal.hit_wall) {
            state.velocity.x = 0;
            if (state.dash_ticks_remaining > 0) {
                state.dash_ticks_remaining = 0;
                result.dash_ended = true;
            }
            result.wall_collision = true;
        }

        const vertical_velocity_before_resolution = state.velocity.y;
        const vertical = try world.sweepVertical(
            state.position,
            configuration.collider_half_extents,
            state.velocity.y * configuration.fixed_dt,
            configuration.ground_epsilon,
        );
        state.position.y = vertical.resolved_position_y;
        state.grounded = vertical.hit_ground;
        state.ground_normal = if (vertical.hit_ground) .{ .x = 0, .y = 1 } else math.Vec2.zero;
        state.supporting_collider = if (vertical.hit_ground) vertical.collider_id else null;
        if (vertical.hit_ground and state.velocity.y < 0) state.velocity.y = 0;
        if (vertical.hit_ceiling and state.velocity.y > 0) state.velocity.y = 0;
        if (vertical.hit_ground) state.air_jumps_used = 0;
        result.ceiling_collision = vertical.hit_ceiling;

        if (!state.previous_grounded and vertical.hit_ground) {
            const impact_speed = @max(@as(f32, 0), -vertical_velocity_before_resolution);
            if (impact_speed > configuration.landing_impact_threshold) {
                result.landed = true;
                result.landing_impact_speed = impact_speed;
                state.last_landing_impact_speed = impact_speed;
                state.last_landing_tick = tick;
            }
        }

        if (vertical.hit_ground and state.jump_buffer_ticks_remaining > 0 and !result.jump_accepted) {
            acceptJump(state, properties.jump_speed, .buffered, tick, &result);
        }

        if (state.previous_grounded and !state.grounded and !result.jump_accepted) {
            state.coyote_ticks_remaining = try durationTicks(configuration.coyote_duration);
            result.ground_left = true;
            result.coyote_started = state.coyote_ticks_remaining > 0;
        } else if (state.grounded) {
            state.coyote_ticks_remaining = try durationTicks(configuration.coyote_duration);
        } else if (!result.coyote_consumed and state.coyote_ticks_remaining > 0) {
            state.coyote_ticks_remaining -= 1;
        }

        if (!result.jump_buffer_consumed and state.jump_buffer_ticks_remaining > 0) {
            state.jump_buffer_ticks_remaining -= 1;
        }
        if (state.dash_ticks_remaining > 0) {
            state.dash_ticks_remaining -= 1;
            if (state.dash_ticks_remaining == 0) result.dash_ended = true;
        }
        if (state.dash_cooldown_ticks_remaining > 0) state.dash_cooldown_ticks_remaining -= 1;
        state.simulation_tick = std.math.add(u64, state.simulation_tick, 1) catch return error.SimulationTickOverflow;
        try controller.validateState(world);
        return result;
    }

    pub fn interpolatedPosition(controller: CharacterController, alpha: f64) !math.Vec2 {
        return .{
            .x = try fixed_step.interpolateScalar(controller.state.previous_position.x, controller.state.position.x, alpha),
            .y = try fixed_step.interpolateScalar(controller.state.previous_position.y, controller.state.position.y, alpha),
        };
    }

    fn validateState(controller: CharacterController, world: *const collision_world.CollisionWorld) !void {
        if (!controller.state.position.isFinite()) return error.NonFinitePosition;
        if (!controller.state.previous_position.isFinite()) return error.NonFinitePosition;
        if (!controller.state.velocity.isFinite()) return error.NonFiniteVelocity;
        const bounds = try collider.characterBounds(controller.state.position, controller.configuration.collider_half_extents);
        if (try world.containsPenetrationBeyond(bounds, controller.configuration.ground_epsilon)) return error.UnsupportedPenetrationState;
    }
};

fn makeState(position: math.Vec2, facing: Facing, support: ?collider.ColliderId, grounded: bool) State {
    return .{
        .position = position,
        .previous_position = position,
        .facing = facing,
        .dash_direction = facing,
        .grounded = grounded,
        .previous_grounded = grounded,
        .ground_normal = if (grounded) .{ .x = 0, .y = 1 } else math.Vec2.zero,
        .supporting_collider = support,
    };
}

fn acceptJump(state: *State, jump_speed: f32, source: JumpSource, tick: u64, result: *StepResult) void {
    state.velocity.y = jump_speed;
    state.grounded = false;
    state.ground_normal = math.Vec2.zero;
    state.supporting_collider = null;
    state.coyote_ticks_remaining = 0;
    state.jump_buffer_ticks_remaining = 0;
    state.jump_was_consumed = true;
    if (source == .air) state.air_jumps_used += 1;
    state.last_jump_tick = tick;
    result.jump_accepted = true;
    result.jump_source = source;
    result.jump_buffer_consumed = true;
    result.coyote_consumed = source == .coyote;
}

fn moveToward(current: f32, target: f32, maximum_delta: f32) f32 {
    if (current < target) return @min(current + maximum_delta, target);
    if (current > target) return @max(current - maximum_delta, target);
    return target;
}

fn durationTicks(seconds: f32) !u16 {
    if (!std.math.isFinite(seconds) or seconds < 0) return error.InvalidTimerDuration;
    // Authored durations are f32; remove only their sub-microtick representation noise before ceiling.
    const ticks_f64 = @ceil(@as(f64, seconds) * @as(f64, @floatFromInt(fixed_step.simulation_hz)) - 1e-6);
    if (ticks_f64 > std.math.maxInt(u16)) return error.TimerDurationOverflow;
    return @intFromFloat(ticks_f64);
}
