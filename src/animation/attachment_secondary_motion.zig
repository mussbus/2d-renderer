const std = @import("std");
const math = @import("math");
const fixed_step = @import("fixed_step");
const spring = @import("spring");

pub const fixed_dt: f32 = @floatCast(fixed_step.fixed_dt_seconds);
pub const maximum_dynamic_points: usize = 4;
pub const minimum_rest_offset_length: f32 = 0.0001;
pub const maximum_stiffness_step: f32 = 1.0;
pub const maximum_damping_step: f32 = 1.9;

pub const Facing = enum(u8) {
    right,
    left,
};

pub const Definition = struct {
    dynamic_point_count: u8,
    rest_offsets: [maximum_dynamic_points]math.Vec2,
    spring_configuration: spring.Configuration,
    gravity_displacement: math.Vec2 = math.Vec2.zero,
    acceleration_response: math.Vec2 = math.Vec2.zero,
    velocity_response: math.Vec2 = math.Vec2.zero,
    chain_follow: f32 = 0,
    landing_impulse_scale: f32 = 0,
    output_translation_scale: f32 = 0.35,
    maximum_rotation_radians: f32,

    pub fn validate(definition: Definition) !void {
        if (definition.dynamic_point_count == 0 or definition.dynamic_point_count > maximum_dynamic_points) {
            return error.InvalidSecondaryPointCount;
        }
        try definition.spring_configuration.validate(fixed_dt);
        if (definition.spring_configuration.stiffness * fixed_dt * fixed_dt > maximum_stiffness_step or
            definition.spring_configuration.damping * fixed_dt > maximum_damping_step)
        {
            return error.UnstableSecondaryConfiguration;
        }
        if (!definition.gravity_displacement.isFinite() or
            !definition.acceleration_response.isFinite() or
            !definition.velocity_response.isFinite())
        {
            return error.NonFiniteSecondaryDefinition;
        }
        if (definition.acceleration_response.x < 0 or definition.acceleration_response.y < 0 or
            definition.velocity_response.x < 0 or definition.velocity_response.y < 0)
        {
            return error.InvalidSecondaryResponse;
        }
        const scalar_values = [_]f32{
            definition.chain_follow,
            definition.landing_impulse_scale,
            definition.output_translation_scale,
            definition.maximum_rotation_radians,
        };
        for (scalar_values) |value| {
            if (!std.math.isFinite(value)) return error.NonFiniteSecondaryDefinition;
        }
        if (definition.chain_follow < 0 or definition.chain_follow > 1 or
            definition.landing_impulse_scale < 0 or
            definition.output_translation_scale < 0 or definition.output_translation_scale > 1 or
            definition.maximum_rotation_radians < 0 or definition.maximum_rotation_radians > std.math.pi)
        {
            return error.InvalidSecondaryResponse;
        }

        var previous = math.Vec2.zero;
        for (definition.rest_offsets[0..definition.dynamic_point_count]) |rest_offset| {
            if (!rest_offset.isFinite()) return error.NonFiniteSecondaryDefinition;
            const segment = rest_offset.sub(previous);
            if (segment.lengthSquared() < minimum_rest_offset_length * minimum_rest_offset_length) {
                return error.InvalidSecondaryRestOffset;
            }
            previous = rest_offset;
        }
    }
};

pub const TickInput = struct {
    anchor_world: math.Vec2,
    linear_velocity_world: math.Vec2 = math.Vec2.zero,
    linear_acceleration_world: ?math.Vec2 = null,
    landing_velocity_impulse_world: math.Vec2 = math.Vec2.zero,
    facing: Facing = .right,

    fn validate(input: TickInput) !void {
        if (!input.anchor_world.isFinite() or
            !input.linear_velocity_world.isFinite() or
            !input.landing_velocity_impulse_world.isFinite() or
            (input.linear_acceleration_world != null and !input.linear_acceleration_world.?.isFinite()))
        {
            return error.NonFiniteSecondaryInput;
        }
    }
};

pub const PointState = struct {
    horizontal: spring.State = .{},
    vertical: spring.State = .{},

    pub fn displacement(point: PointState) math.Vec2 {
        return .{ .x = point.horizontal.offset, .y = point.vertical.offset };
    }

    pub fn velocity(point: PointState) math.Vec2 {
        return .{ .x = point.horizontal.velocity, .y = point.vertical.velocity };
    }
};

pub const RuntimeState = struct {
    initialized: bool = false,
    facing: Facing = .right,
    anchor_world: math.Vec2 = math.Vec2.zero,
    previous_linear_velocity_world: math.Vec2 = math.Vec2.zero,
    points: [maximum_dynamic_points]PointState = [_]PointState{.{}} ** maximum_dynamic_points,
    fixed_ticks: u64 = 0,
    reset_count: u32 = 0,

    pub fn clear(state: *RuntimeState) void {
        state.* = .{};
    }

    pub fn reset(state: *RuntimeState, definition: Definition, input: TickInput) !void {
        try definition.validate();
        try input.validate();
        const next_reset_count = state.reset_count +| 1;
        state.* = .{
            .initialized = true,
            .facing = input.facing,
            .anchor_world = input.anchor_world,
            .previous_linear_velocity_world = input.linear_velocity_world,
            .reset_count = next_reset_count,
        };
    }

    pub fn step(state: *RuntimeState, definition: Definition, input: TickInput) !void {
        try definition.validate();
        try input.validate();
        if (!state.initialized or state.facing != input.facing) {
            try state.reset(definition, input);
            return;
        }
        if (!state.isFiniteAndBounded(definition)) return error.InvalidSecondaryRuntimeState;

        const acceleration_world = input.linear_acceleration_world orelse
            input.linear_velocity_world.sub(state.previous_linear_velocity_world).scale(1.0 / fixed_dt);
        if (!acceleration_world.isFinite()) return error.NonFiniteSecondaryInput;
        const velocity_local = worldVectorToLocal(input.linear_velocity_world, input.facing);
        const acceleration_local = worldVectorToLocal(acceleration_world, input.facing);
        const landing_impulse_local = worldVectorToLocal(input.landing_velocity_impulse_world, input.facing);
        const driven_target = definition.gravity_displacement
            .sub(acceleration_local.componentMul(definition.acceleration_response))
            .sub(velocity_local.componentMul(definition.velocity_response));
        if (!driven_target.isFinite()) return error.NonFiniteSecondaryInput;

        var previous_displacement = math.Vec2.zero;
        var point_index: usize = 0;
        while (point_index < definition.dynamic_point_count) : (point_index += 1) {
            const point_factor = @as(f32, @floatFromInt(point_index + 1)) /
                @as(f32, @floatFromInt(definition.dynamic_point_count));
            const propagated = previous_displacement.scale(definition.chain_follow);
            const target = clampMagnitude(
                driven_target.scale(point_factor).add(propagated),
                definition.spring_configuration.maximum_displacement,
            );
            var point = &state.points[point_index];
            try point.horizontal.setTarget(target.x, definition.spring_configuration);
            try point.vertical.setTarget(target.y, definition.spring_configuration);
            if (landing_impulse_local.x != 0 or landing_impulse_local.y != 0) {
                const impulse = landing_impulse_local.scale(definition.landing_impulse_scale * point_factor);
                try point.horizontal.applyVelocityImpulse(impulse.x, definition.spring_configuration);
                try point.vertical.applyVelocityImpulse(impulse.y, definition.spring_configuration);
            }
            try point.horizontal.step(definition.spring_configuration, fixed_dt);
            try point.vertical.step(definition.spring_configuration, fixed_dt);
            clampPoint(point, definition.spring_configuration);
            previous_displacement = point.displacement();
        }

        state.anchor_world = input.anchor_world;
        state.previous_linear_velocity_world = input.linear_velocity_world;
        state.fixed_ticks +%= 1;
        if (!state.isFiniteAndBounded(definition)) return error.InvalidSecondaryRuntimeState;
    }

    pub fn displacement(state: RuntimeState, definition: Definition, point_index: usize) !math.Vec2 {
        try definition.validate();
        if (point_index >= definition.dynamic_point_count) return error.InvalidSecondaryPointIndex;
        if (!state.initialized) return math.Vec2.zero;
        if (!state.isFiniteAndBounded(definition)) return error.InvalidSecondaryRuntimeState;
        return state.points[point_index].displacement();
    }

    pub fn resolvedPointWorld(state: RuntimeState, definition: Definition, point_index: usize) !math.Vec2 {
        const local_point = definition.rest_offsets[point_index].add(try state.displacement(definition, point_index));
        return state.anchor_world.add(localVectorToWorld(local_point, state.facing));
    }

    pub fn resolvedTransform(state: RuntimeState, definition: Definition) !math.Transform2D {
        try definition.validate();
        if (!state.initialized) return math.Transform2D.identity();
        if (!state.isFiniteAndBounded(definition)) return error.InvalidSecondaryRuntimeState;
        const point_index = definition.dynamic_point_count - 1;
        const rest = definition.rest_offsets[point_index];
        const displacement_value = state.points[point_index].displacement();
        const resolved = rest.add(displacement_value);
        var rotation = std.math.atan2(resolved.y, resolved.x) - std.math.atan2(rest.y, rest.x);
        if (rotation > std.math.pi) rotation -= 2.0 * std.math.pi;
        if (rotation < -std.math.pi) rotation += 2.0 * std.math.pi;
        rotation = std.math.clamp(
            rotation,
            -definition.maximum_rotation_radians,
            definition.maximum_rotation_radians,
        );
        const result = math.Transform2D.init(
            displacement_value.scale(definition.output_translation_scale),
            rotation,
            math.Vec2.one,
        );
        if (!result.isFinite()) return error.InvalidSecondaryRuntimeState;
        return result;
    }

    pub fn isFiniteAndBounded(state: RuntimeState, definition: Definition) bool {
        if (!state.anchor_world.isFinite() or !state.previous_linear_velocity_world.isFinite()) return false;
        for (state.points[0..definition.dynamic_point_count]) |point| {
            const values = [_]f32{
                point.horizontal.offset,
                point.horizontal.velocity,
                point.horizontal.target_offset,
                point.vertical.offset,
                point.vertical.velocity,
                point.vertical.target_offset,
            };
            for (values) |value| if (!std.math.isFinite(value)) return false;
            if (point.displacement().length() > definition.spring_configuration.maximum_displacement + 0.000001 or
                point.velocity().length() > definition.spring_configuration.maximum_velocity + 0.000001)
            {
                return false;
            }
        }
        return true;
    }
};

pub fn composeResolvedDeformation(
    base: math.Transform2D,
    secondary: math.Transform2D,
) !math.Transform2D {
    if (!base.isFinite() or !secondary.isFinite()) return error.NonFiniteSecondaryComposition;
    const result = math.Transform2D.init(
        base.translation.add(secondary.translation),
        base.rotation_radians + secondary.rotation_radians,
        base.scale.componentMul(secondary.scale),
    );
    if (!result.isFinite() or result.scale.x <= 0 or result.scale.y <= 0) {
        return error.NonFiniteSecondaryComposition;
    }
    return result;
}

fn clampPoint(point: *PointState, configuration: spring.Configuration) void {
    const displacement_value = clampMagnitude(point.displacement(), configuration.maximum_displacement);
    point.horizontal.offset = displacement_value.x;
    point.vertical.offset = displacement_value.y;
    const velocity_value = clampMagnitude(point.velocity(), configuration.maximum_velocity);
    point.horizontal.velocity = velocity_value.x;
    point.vertical.velocity = velocity_value.y;
}

fn clampMagnitude(value: math.Vec2, maximum: f32) math.Vec2 {
    const length_squared = value.lengthSquared();
    if (length_squared <= maximum * maximum or length_squared == 0) return value;
    return value.scale(maximum / @sqrt(length_squared));
}

fn worldVectorToLocal(value: math.Vec2, facing: Facing) math.Vec2 {
    return .{ .x = if (facing == .left) -value.x else value.x, .y = value.y };
}

fn localVectorToWorld(value: math.Vec2, facing: Facing) math.Vec2 {
    return .{ .x = if (facing == .left) -value.x else value.x, .y = value.y };
}
