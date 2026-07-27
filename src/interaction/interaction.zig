const std = @import("std");
const skeleton = @import("skeleton");
const clip = @import("clip");
const events = @import("events");
const state_machine = @import("state_machine");
const fixed_step = @import("fixed_step");
const presentation_view = @import("presentation_view");

pub const participant_count: usize = 2;
pub const event_count: usize = 3;
pub const paired_event_time_tolerance: f32 = 0.000001;
pub const authored_tick_noise_tolerance: f64 = 0.0001;

pub const TypeId = enum(u32) {
    invalid = 0,
    handshake = 1,
    _,

    pub fn isValid(id: TypeId) bool {
        return id != .invalid;
    }
};

pub const Role = enum(u8) {
    initiator,
    receiver,
};

pub const Lifecycle = enum(u8) {
    inactive,
    requested,
    active,
    completing,
    completed,
    cancelled,
};

pub const Phase = enum(u8) {
    approach,
    contact,
    released,
    complete,
};

pub const EventSemantic = enum(u8) {
    contact,
    release,
    complete,
};

pub const CompletionBehavior = enum(u8) {
    grounded_motion_fallback,
};

pub const RoleDefinition = struct {
    role: Role,
    state: state_machine.StateId,
    clip_id: clip.ClipId,
    handshake_socket: skeleton.SocketSemantic,
};

pub const EventDefinition = struct {
    semantic: EventSemantic,
    time_seconds: f32,
    elapsed_tick: u32,
};

pub const SpatialEnvelope = struct {
    authored_horizontal_separation: f32,
    minimum_horizontal_separation: f32,
    maximum_horizontal_separation: f32,
    maximum_vertical_root_difference: f32,
    facing_tolerance_radians: f32,

    pub fn validate(envelope: SpatialEnvelope) !void {
        const values = [_]f32{
            envelope.authored_horizontal_separation,
            envelope.minimum_horizontal_separation,
            envelope.maximum_horizontal_separation,
            envelope.maximum_vertical_root_difference,
            envelope.facing_tolerance_radians,
        };
        for (values) |value| {
            if (!std.math.isFinite(value)) return error.NonFiniteInteractionConfiguration;
        }
        if (envelope.minimum_horizontal_separation < 0 or
            envelope.maximum_horizontal_separation < envelope.minimum_horizontal_separation or
            envelope.authored_horizontal_separation < envelope.minimum_horizontal_separation or
            envelope.authored_horizontal_separation > envelope.maximum_horizontal_separation or
            envelope.maximum_vertical_root_difference < 0 or
            envelope.facing_tolerance_radians < 0)
        {
            return error.InvalidSpatialEnvelope;
        }
    }
};

pub const DefinitionInput = struct {
    type_id: TypeId,
    debug_name: []const u8,
    declared_participant_count: u8,
    role_a_state: state_machine.StateId,
    role_b_state: state_machine.StateId,
    role_a_clip_raw: u8,
    role_b_clip_raw: u8,
    role_a_socket: skeleton.SocketSemantic,
    role_b_socket: skeleton.SocketSemantic,
    allowed_start_states: [2]state_machine.StateId,
    envelope: SpatialEnvelope,
    completion_behavior: CompletionBehavior,
    required_presentation_view: ?presentation_view.View = null,
};

pub const Definition = struct {
    type_id: TypeId,
    debug_name: skeleton.DebugName,
    participant_total: u8,
    roles: [participant_count]RoleDefinition,
    authoritative_duration_seconds: f32,
    authoritative_duration_ticks: u32,
    envelope: SpatialEnvelope,
    required_grounded: bool,
    allowed_start_states: [2]state_machine.StateId,
    events: [event_count]EventDefinition,
    completion_behavior: CompletionBehavior,
    required_presentation_view: ?presentation_view.View,

    pub fn init(
        input: DefinitionInput,
        clips: []const clip.ClipDefinition,
        machine: *const state_machine.Definition,
    ) !Definition {
        if (!input.type_id.isValid()) return error.InvalidInteractionType;
        if (input.declared_participant_count != participant_count) return error.InvalidParticipantCount;
        try input.envelope.validate();
        if (input.role_a_clip_raw >= clip.clip_count or input.role_b_clip_raw >= clip.clip_count) {
            return error.InvalidRoleClip;
        }
        const role_a_clip: clip.ClipId = @enumFromInt(input.role_a_clip_raw);
        const role_b_clip: clip.ClipId = @enumFromInt(input.role_b_clip_raw);
        if (role_a_clip == role_b_clip) return error.DuplicateRoleClip;
        const clip_a = findClip(clips, role_a_clip) orelse return error.InvalidRoleClip;
        const clip_b = findClip(clips, role_b_clip) orelse return error.InvalidRoleClip;
        try validateStateClip(machine, clips, input.role_a_state, role_a_clip);
        try validateStateClip(machine, clips, input.role_b_state, role_b_clip);
        if (!std.math.isFinite(clip_a.duration) or !std.math.isFinite(clip_b.duration)) {
            return error.NonFiniteInteractionConfiguration;
        }
        if (@abs(clip_a.duration - clip_b.duration) > paired_event_time_tolerance) {
            return error.PairedClipDurationMismatch;
        }

        const a_times = try pairedEventTimes(clip_a);
        const b_times = try pairedEventTimes(clip_b);
        var shared_events: [event_count]EventDefinition = undefined;
        const semantics = [_]EventSemantic{ .contact, .release, .complete };
        for (semantics, 0..) |semantic, index| {
            if (@abs(a_times[index] - b_times[index]) > paired_event_time_tolerance) {
                return error.PairedClipEventTimeMismatch;
            }
            shared_events[index] = .{
                .semantic = semantic,
                .time_seconds = a_times[index],
                .elapsed_tick = try timeToTick(a_times[index]),
            };
        }
        if (!(shared_events[0].time_seconds < shared_events[1].time_seconds and
            shared_events[1].time_seconds < shared_events[2].time_seconds and
            shared_events[2].time_seconds <= clip_a.duration))
        {
            return error.InvalidInteractionEventOrdering;
        }

        return .{
            .type_id = input.type_id,
            .debug_name = try skeleton.DebugName.init(input.debug_name),
            .participant_total = participant_count,
            .roles = .{
                .{ .role = .initiator, .state = input.role_a_state, .clip_id = role_a_clip, .handshake_socket = input.role_a_socket },
                .{ .role = .receiver, .state = input.role_b_state, .clip_id = role_b_clip, .handshake_socket = input.role_b_socket },
            },
            .authoritative_duration_seconds = clip_a.duration,
            .authoritative_duration_ticks = try timeToTick(clip_a.duration),
            .envelope = input.envelope,
            .required_grounded = true,
            .allowed_start_states = input.allowed_start_states,
            .events = shared_events,
            .completion_behavior = input.completion_behavior,
            .required_presentation_view = input.required_presentation_view,
        };
    }

    pub fn role(definition: *const Definition, role_value: Role) *const RoleDefinition {
        return &definition.roles[@intFromEnum(role_value)];
    }

    pub fn event(definition: *const Definition, semantic: EventSemantic) *const EventDefinition {
        return &definition.events[@intFromEnum(semantic)];
    }

    pub fn allowsStartState(definition: *const Definition, state: state_machine.StateId) bool {
        for (definition.allowed_start_states) |allowed| {
            if (allowed == state) return true;
        }
        return false;
    }
};

pub fn legalTransition(from: Lifecycle, to: Lifecycle) bool {
    return switch (from) {
        .inactive => to == .requested,
        .requested => to == .active or to == .cancelled,
        .active => to == .completing or to == .cancelled,
        .completing => to == .completed or to == .cancelled,
        .completed, .cancelled => false,
    };
}

pub fn timeToTick(seconds: f32) !u32 {
    if (!std.math.isFinite(seconds) or seconds < 0) return error.InvalidInteractionEventTime;
    // Authored event times are f32. Remove only sub-0.0001-tick representation noise before applying
    // the open-closed interval's ceiling; this maps authored 0.60/1.20/1.50 exactly to 144/288/360.
    const ticks = @ceil(@as(f64, seconds) * @as(f64, @floatFromInt(fixed_step.simulation_hz)) - authored_tick_noise_tolerance);
    if (ticks > std.math.maxInt(u32)) return error.InteractionTimelineOverflow;
    return @intFromFloat(ticks);
}

fn findClip(clips: []const clip.ClipDefinition, id: clip.ClipId) ?*const clip.ClipDefinition {
    for (clips) |*candidate| {
        if (candidate.id == id) return candidate;
    }
    return null;
}

fn validateStateClip(
    machine: *const state_machine.Definition,
    clips: []const clip.ClipDefinition,
    state: state_machine.StateId,
    expected_clip: clip.ClipId,
) !void {
    const index = machine.stateIndex(state) catch return error.InvalidRoleClip;
    const clip_index = machine.states[index].clip_index;
    if (clip_index >= clips.len or clips[clip_index].id != expected_clip) return error.InvalidRoleClip;
}

fn pairedEventTimes(animation_clip: *const clip.ClipDefinition) ![event_count]f32 {
    var times: [event_count]f32 = undefined;
    var found = [_]bool{false} ** event_count;
    for (animation_clip.event_records) |record| {
        const index: ?usize = switch (record.event_type) {
            .hand_contact => @intFromEnum(EventSemantic.contact),
            .hand_release => @intFromEnum(EventSemantic.release),
            .interaction_complete => @intFromEnum(EventSemantic.complete),
            else => null,
        };
        if (index) |event_index| {
            if (found[event_index]) return error.DuplicatePairedClipEvent;
            if (!std.math.isFinite(record.timestamp) or record.timestamp < 0 or record.timestamp > animation_clip.duration) {
                return error.InvalidInteractionEventTime;
            }
            times[event_index] = record.timestamp;
            found[event_index] = true;
        }
    }
    for (found) |present| {
        if (!present) return error.MissingPairedClipEvent;
    }
    return times;
}
