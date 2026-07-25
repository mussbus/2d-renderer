const std = @import("std");
const math = @import("math");
const fixed_step = @import("fixed_step");

pub const default_period_ticks: u32 = fixed_step.simulation_hz * 4;
pub const maximum_period_ticks: u32 = fixed_step.simulation_hz * 60 * 10;
pub const maximum_amplitude: f32 = 1;

pub const Response = struct {
    morphology: f32 = 1,
    breathing: f32 = 1,

    pub fn validate(response: Response) !void {
        if (!std.math.isFinite(response.morphology) or
            !std.math.isFinite(response.breathing) or
            response.morphology < 0 or response.morphology > 1 or
            response.breathing < 0 or response.breathing > 1)
        {
            return error.InvalidDeformationResponse;
        }
    }
};

pub const BreathingBinding = struct {
    translation_at_unit: math.Vec2 = math.Vec2.zero,
    rotation_at_unit: f32 = 0,
    scale_delta_at_unit: math.Vec2 = math.Vec2.zero,

    pub fn validate(binding: BreathingBinding) !void {
        if (!binding.translation_at_unit.isFinite() or
            !std.math.isFinite(binding.rotation_at_unit) or
            !binding.scale_delta_at_unit.isFinite())
        {
            return error.InvalidBreathingBinding;
        }
        if (@abs(binding.scale_delta_at_unit.x) >= 1 or
            @abs(binding.scale_delta_at_unit.y) >= 1)
        {
            return error.InvalidBreathingScaleRange;
        }
    }
};

pub const BreathingConfiguration = struct {
    period_ticks: u32 = default_period_ticks,
    amplitude: f32 = 0.65,

    pub fn init(period_ticks: u32, amplitude: f32) !BreathingConfiguration {
        const configuration = BreathingConfiguration{
            .period_ticks = period_ticks,
            .amplitude = amplitude,
        };
        try configuration.validate();
        return configuration;
    }

    pub fn fromRateHz(rate_hz: f32, amplitude: f32) !BreathingConfiguration {
        if (!std.math.isFinite(rate_hz) or rate_hz <= 0) return error.InvalidBreathingRate;
        const exact_period = @as(f32, @floatFromInt(fixed_step.simulation_hz)) / rate_hz;
        if (!std.math.isFinite(exact_period) or exact_period > @as(f32, @floatFromInt(maximum_period_ticks))) {
            return error.InvalidBreathingRate;
        }
        const rounded_period = @round(exact_period);
        if (@abs(exact_period - rounded_period) > 1e-4) return error.BreathingRateNotTickRepresentable;
        return init(@intFromFloat(rounded_period), amplitude);
    }

    pub fn validate(configuration: BreathingConfiguration) !void {
        if (configuration.period_ticks < 4 or configuration.period_ticks > maximum_period_ticks) {
            return error.InvalidBreathingPeriod;
        }
        if (!std.math.isFinite(configuration.amplitude) or
            configuration.amplitude < 0 or
            configuration.amplitude > maximum_amplitude)
        {
            return error.InvalidBreathingAmplitude;
        }
    }

    pub fn rateHz(configuration: BreathingConfiguration) f32 {
        return @as(f32, @floatFromInt(fixed_step.simulation_hz)) /
            @as(f32, @floatFromInt(configuration.period_ticks));
    }
};

pub const BreathingState = struct {
    configuration: BreathingConfiguration = .{},
    cycle_tick: u32 = 0,

    pub fn init(configuration: BreathingConfiguration) !BreathingState {
        try configuration.validate();
        return .{ .configuration = configuration };
    }

    pub fn configure(state: *BreathingState, configuration: BreathingConfiguration) !void {
        try configuration.validate();
        state.configuration = configuration;
        state.cycle_tick %= configuration.period_ticks;
    }

    pub fn reset(state: *BreathingState) void {
        state.cycle_tick = 0;
    }

    pub fn setPhaseTick(state: *BreathingState, phase_tick: u32) !void {
        try state.configuration.validate();
        state.cycle_tick = phase_tick % state.configuration.period_ticks;
    }

    pub fn advance(state: *BreathingState) !void {
        try state.configuration.validate();
        state.cycle_tick = if (state.cycle_tick + 1 == state.configuration.period_ticks)
            0
        else
            state.cycle_tick + 1;
    }

    pub fn normalizedPhase(state: BreathingState) !f32 {
        try state.configuration.validate();
        if (state.cycle_tick >= state.configuration.period_ticks) return error.InvalidBreathingPhase;
        return @as(f32, @floatFromInt(state.cycle_tick)) /
            @as(f32, @floatFromInt(state.configuration.period_ticks));
    }

    pub fn sample(state: BreathingState) !f32 {
        const phase = try state.normalizedPhase();
        const value = @sin(phase * (2 * std.math.pi)) * state.configuration.amplitude;
        if (!std.math.isFinite(value) or @abs(value) > maximum_amplitude + 1e-6) {
            return error.InvalidBreathingSample;
        }
        return value;
    }
};

pub const ResolveInput = struct {
    base_morphology: math.Transform2D,
    breathing_binding: BreathingBinding,
    breathing_sample: f32,
    response: Response,
};

pub fn resolve(input: ResolveInput) !math.Transform2D {
    if (!input.base_morphology.isFinite()) return error.InvalidBaseMorphology;
    try input.breathing_binding.validate();
    try input.response.validate();
    if (!std.math.isFinite(input.breathing_sample) or @abs(input.breathing_sample) > maximum_amplitude + 1e-6) {
        return error.InvalidBreathingSample;
    }

    const morphology = try responseTransform(input.base_morphology, input.response.morphology);
    const breathing_amount = input.breathing_sample * input.response.breathing;
    const breathing_scale = math.Vec2{
        .x = 1 + input.breathing_binding.scale_delta_at_unit.x * breathing_amount,
        .y = 1 + input.breathing_binding.scale_delta_at_unit.y * breathing_amount,
    };
    if (!breathing_scale.isFinite() or breathing_scale.x <= 0 or breathing_scale.y <= 0) {
        return error.InvalidResolvedDeformationScale;
    }

    const resolved = math.Transform2D{
        .translation = morphology.translation.add(input.breathing_binding.translation_at_unit.scale(breathing_amount)),
        .rotation_radians = morphology.rotation_radians + input.breathing_binding.rotation_at_unit * breathing_amount,
        .scale = morphology.scale.componentMul(breathing_scale),
    };
    if (!resolved.isFinite() or resolved.scale.x <= 0 or resolved.scale.y <= 0) {
        return error.InvalidResolvedDeformation;
    }
    return resolved;
}

fn responseTransform(value: math.Transform2D, strength: f32) !math.Transform2D {
    const resolved = math.Transform2D{
        .translation = value.translation.scale(strength),
        .rotation_radians = value.rotation_radians * strength,
        .scale = .{
            .x = 1 + (value.scale.x - 1) * strength,
            .y = 1 + (value.scale.y - 1) * strength,
        },
    };
    if (!resolved.isFinite() or resolved.scale.x <= 0 or resolved.scale.y <= 0) {
        return error.InvalidResolvedDeformationScale;
    }
    return resolved;
}
