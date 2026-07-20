const std = @import("std");
const clip = @import("clip");
const fault_injection = @import("fault_injection");

pub const StateId = enum(u8) {
    idle,
    walk,
    jump_start,
    rising,
    falling,
    landing,
    handshake_role_a,
    handshake_role_b,
};

pub const state_id_count: usize = 8;
pub const maximum_states: usize = 16;
pub const maximum_transitions: usize = 32;

pub const TransitionEventPolicy = enum(u8) {
    source_and_destination,
};

pub const StateInput = struct {
    state_id: u8,
    clip_id: u8,
    playback_speed: f32,
    fallback_state: ?u8 = null,
    fallback_blend_duration: f32 = 0,
};

pub const TransitionInput = struct {
    source_state: u8,
    destination_state: u8,
    blend_duration: f32,
    destination_begins_immediately: bool = true,
    source_advances: bool = true,
};

pub const StateDefinition = struct {
    id: StateId,
    clip_index: u16,
    playback_speed: f32,
    fallback_state_index: ?u16,
    fallback_blend_duration: f32,
};

pub const TransitionDefinition = struct {
    source_state_index: u16,
    destination_state_index: u16,
    blend_duration: f32,
    destination_begins_immediately: bool,
    source_advances: bool,
    event_policy: TransitionEventPolicy,
};

pub const Definition = struct {
    allocator: std.mem.Allocator,
    states: []const StateDefinition,
    transitions: []const TransitionDefinition,
    state_indices: [state_id_count]?u16,
    initial_state_index: u16,
    clip_library_token: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        clips: []const clip.ClipDefinition,
        library_token: usize,
        state_inputs: []const StateInput,
        transition_inputs: []const TransitionInput,
        initial_state: u8,
        injector: ?fault_injection.Injector,
    ) !Definition {
        if (state_inputs.len == 0 or state_inputs.len > maximum_states or transition_inputs.len > maximum_transitions) {
            return error.SupportedCountOverflow;
        }
        if (initial_state >= state_id_count) return error.MissingInitialState;

        const states = allocator.alloc(StateDefinition, state_inputs.len) catch return error.AllocationFailure;
        errdefer allocator.free(states);
        try after(injector, .state_machine_state_allocation);
        const transitions = allocator.alloc(TransitionDefinition, transition_inputs.len) catch return error.AllocationFailure;
        errdefer allocator.free(transitions);
        try after(injector, .transition_allocation);

        var lookup = [_]?u16{null} ** state_id_count;
        for (state_inputs, 0..) |input, index| {
            if (input.state_id >= state_id_count) return error.InvalidStateIdentifier;
            if (lookup[input.state_id] != null) return error.DuplicateStateIdentifier;
            if (!std.math.isFinite(input.playback_speed)) return error.InvalidPlaybackSpeed;
            if (input.playback_speed < 0) return error.NegativePlaybackSpeedUnsupported;
            if (!std.math.isFinite(input.fallback_blend_duration) or input.fallback_blend_duration < 0) return error.InvalidTransitionDuration;
            const clip_index = findClipIndex(clips, input.clip_id) orelse return error.MissingClip;
            states[index] = .{
                .id = @enumFromInt(input.state_id),
                .clip_index = clip_index,
                .playback_speed = input.playback_speed,
                .fallback_state_index = null,
                .fallback_blend_duration = input.fallback_blend_duration,
            };
            lookup[input.state_id] = @intCast(index);
        }
        const initial_index = lookup[initial_state] orelse return error.MissingInitialState;

        for (state_inputs, 0..) |input, index| {
            const state_clip = clips[states[index].clip_index];
            if (input.fallback_state) |fallback_raw| {
                if (fallback_raw >= state_id_count) return error.InvalidFallbackState;
                states[index].fallback_state_index = lookup[fallback_raw] orelse return error.InvalidFallbackState;
            }
            if (state_clip.playback_mode == .one_shot and states[index].fallback_state_index == null) {
                return error.MissingOneShotFallback;
            }
        }

        for (transition_inputs, 0..) |input, index| {
            if (input.source_state >= state_id_count or input.destination_state >= state_id_count) return error.InvalidTransitionState;
            const source = lookup[input.source_state] orelse return error.InvalidTransitionState;
            const destination = lookup[input.destination_state] orelse return error.InvalidTransitionState;
            if (!std.math.isFinite(input.blend_duration) or input.blend_duration < 0) return error.InvalidTransitionDuration;
            for (transitions[0..index]) |existing| {
                if (existing.source_state_index == source and existing.destination_state_index == destination) return error.DuplicateTransition;
            }
            transitions[index] = .{
                .source_state_index = source,
                .destination_state_index = destination,
                .blend_duration = input.blend_duration,
                .destination_begins_immediately = input.destination_begins_immediately,
                .source_advances = input.source_advances,
                .event_policy = .source_and_destination,
            };
        }

        return .{
            .allocator = allocator,
            .states = states,
            .transitions = transitions,
            .state_indices = lookup,
            .initial_state_index = initial_index,
            .clip_library_token = library_token,
        };
    }

    pub fn deinit(definition: *Definition) void {
        definition.allocator.free(definition.transitions);
        definition.allocator.free(definition.states);
        definition.* = undefined;
    }

    pub fn stateIndex(definition: Definition, id: StateId) !u16 {
        return definition.state_indices[@intFromEnum(id)] orelse error.InvalidStateIdentifier;
    }

    pub fn state(definition: Definition, index: u16) !*const StateDefinition {
        if (index >= definition.states.len) return error.InvalidStateIdentifier;
        return &definition.states[index];
    }

    pub fn transition(definition: Definition, source: u16, destination: u16) ?*const TransitionDefinition {
        for (definition.transitions) |*candidate| {
            if (candidate.source_state_index == source and candidate.destination_state_index == destination) return candidate;
        }
        return null;
    }
};

fn findClipIndex(clips: []const clip.ClipDefinition, raw_id: u8) ?u16 {
    if (raw_id >= clip.clip_count) return null;
    for (clips, 0..) |candidate, index| {
        if (@intFromEnum(candidate.id) == raw_id) return @intCast(index);
    }
    return null;
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
