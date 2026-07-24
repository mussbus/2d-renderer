const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const humanoid = @import("humanoid");
const clip = @import("clip");
const events = @import("events");
const state_machine = @import("state_machine");
const fault_injection = @import("fault_injection");

const linear = @intFromEnum(clip.InterpolationMode.linear);
const smooth = @intFromEnum(clip.InterpolationMode.smooth);

pub const Library = struct {
    allocator: std.mem.Allocator,
    clips: []clip.ClipDefinition,

    pub fn init(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !Library {
        const storage = allocator.alloc(clip.ClipDefinition, clip.clip_count) catch return error.AllocationFailure;
        errdefer allocator.free(storage);
        var initialized: usize = 0;
        errdefer {
            var index = initialized;
            while (index > 0) {
                index -= 1;
                storage[index].deinit();
            }
        }

        storage[initialized] = try createIdle(allocator, definition, injector);
        initialized += 1;
        storage[initialized] = try createWalk(allocator, definition, injector);
        initialized += 1;
        storage[initialized] = try createJumpStart(allocator, definition, injector);
        initialized += 1;
        storage[initialized] = try createRising(allocator, definition, injector);
        initialized += 1;
        try after(injector, .partial_authored_animation_library);
        storage[initialized] = try createFalling(allocator, definition, injector);
        initialized += 1;
        storage[initialized] = try createLanding(allocator, definition, injector);
        initialized += 1;
        storage[initialized] = try createHandshakeA(allocator, definition, injector);
        initialized += 1;
        storage[initialized] = try createHandshakeB(allocator, definition, injector);
        initialized += 1;

        return .{ .allocator = allocator, .clips = storage };
    }

    pub fn deinit(library: *Library) void {
        var index = library.clips.len;
        while (index > 0) {
            index -= 1;
            library.clips[index].deinit();
        }
        library.allocator.free(library.clips);
        library.* = undefined;
    }

    pub fn token(library: Library) usize {
        return @intFromPtr(library.clips.ptr);
    }

    pub fn byId(library: Library, id: clip.ClipId) !*const clip.ClipDefinition {
        for (library.clips) |*candidate| {
            if (candidate.id == id) return candidate;
        }
        return error.MissingClip;
    }
};

pub const Definitions = struct {
    library: Library,
    machine: state_machine.Definition,

    pub fn init(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !Definitions {
        var library = try Library.init(allocator, definition, injector);
        errdefer library.deinit();
        const states = authoredStates();
        const transitions = authoredTransitions();
        var machine = try state_machine.Definition.init(
            allocator,
            library.clips,
            library.token(),
            &states,
            &transitions,
            @intFromEnum(state_machine.StateId.idle),
            injector,
        );
        errdefer machine.deinit();
        return .{ .library = library, .machine = machine };
    }

    pub fn deinit(definitions: *Definitions) void {
        definitions.machine.deinit();
        definitions.library.deinit();
        definitions.* = undefined;
    }
};

pub fn authoredStates() [state_machine.state_id_count]state_machine.StateInput {
    return .{
        stateInput(.idle, .idle, 1, null, 0),
        stateInput(.walk, .walk, 1, null, 0),
        stateInput(.jump_start, .jump_start, 1, .rising, 0.12),
        stateInput(.rising, .rising, 1, null, 0),
        stateInput(.falling, .falling, 1, null, 0),
        stateInput(.landing, .landing, 1, .idle, 0.20),
        stateInput(.handshake_role_a, .handshake_role_a, 1, .idle, 0.20),
        stateInput(.handshake_role_b, .handshake_role_b, 1, .idle, 0.20),
    };
}

pub fn authoredTransitions() [2]state_machine.TransitionInput {
    return .{
        .{ .source_state = @intFromEnum(state_machine.StateId.idle), .destination_state = @intFromEnum(state_machine.StateId.walk), .blend_duration = 0.30 },
        .{ .source_state = @intFromEnum(state_machine.StateId.walk), .destination_state = @intFromEnum(state_machine.StateId.idle), .blend_duration = 0.30 },
    };
}

fn createIdle(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !clip.ClipDefinition {
    const pelvis_translation = [_]clip.TranslationKeyInput{
        translationKey(0, 0, 0.90, smooth),
        translationKey(1, 0, 0.94, smooth),
        translationKey(2, 0, 0.90, smooth),
    };
    const torso_rotation = [_]clip.RotationKeyInput{
        rotationKey(0, -0.02, smooth),
        rotationKey(1, 0.02, smooth),
        rotationKey(2, -0.02, smooth),
    };
    const torso_scale = [_]clip.ScaleKeyInput{
        scaleKey(0, 1, 1, smooth),
        scaleKey(1, 1.01, 0.99, smooth),
        scaleKey(2, 1, 1, smooth),
    };
    const left_arm = [_]clip.RotationKeyInput{
        rotationKey(0, std.math.pi + 0.04, smooth),
        rotationKey(1, std.math.pi - 0.04, smooth),
        rotationKey(2, std.math.pi + 0.04, smooth),
    };
    const right_arm = [_]clip.RotationKeyInput{
        rotationKey(0, -0.04, smooth),
        rotationKey(1, 0.04, smooth),
        rotationKey(2, -0.04, smooth),
    };
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = semantic(.pelvis), .translation_keys = &pelvis_translation },
        .{ .target_semantic = semantic(.torso), .rotation_keys = &torso_rotation, .scale_keys = &torso_scale },
        .{ .target_semantic = semantic(.left_upper_arm), .rotation_keys = &left_arm },
        .{ .target_semantic = semantic(.right_upper_arm), .rotation_keys = &right_arm },
    };
    return create(allocator, definition, .idle, "idle", "Idle breathing", 2.0, .looping, &tracks, &.{}, injector);
}

fn createWalk(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !clip.ClipDefinition {
    const pelvis = [_]clip.TranslationKeyInput{
        translationKey(0, 0, 0.90, smooth),
        translationKey(0.25, 0, 0.97, smooth),
        translationKey(0.50, 0, 0.90, smooth),
        translationKey(0.75, 0, 0.97, smooth),
        translationKey(1.0, 0, 0.90, smooth),
    };
    const left_thigh = swingKeys(-std.math.pi / 2.0, 0.52);
    const right_thigh = swingKeys(-std.math.pi / 2.0, -0.52);
    const left_shin = bendKeys(0.08, 0.55);
    const right_shin = bendKeys(0.55, 0.08);
    const left_arm = swingKeys(std.math.pi, -0.46);
    const right_arm = swingKeys(0, 0.46);
    const left_forearm = bendKeys(-0.12, 0.18);
    const right_forearm = bendKeys(0.18, -0.12);
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = semantic(.pelvis), .translation_keys = &pelvis },
        .{ .target_semantic = semantic(.left_thigh), .rotation_keys = &left_thigh },
        .{ .target_semantic = semantic(.right_thigh), .rotation_keys = &right_thigh },
        .{ .target_semantic = semantic(.left_shin), .rotation_keys = &left_shin },
        .{ .target_semantic = semantic(.right_shin), .rotation_keys = &right_shin },
        .{ .target_semantic = semantic(.left_upper_arm), .rotation_keys = &left_arm },
        .{ .target_semantic = semantic(.right_upper_arm), .rotation_keys = &right_arm },
        .{ .target_semantic = semantic(.left_forearm), .rotation_keys = &left_forearm },
        .{ .target_semantic = semantic(.right_forearm), .rotation_keys = &right_forearm },
    };
    const event_inputs = [_]events.EventInput{
        eventInput(1, 0, .left_foot_contact),
        eventInput(2, 0.5, .right_foot_contact),
    };
    return create(allocator, definition, .walk, "walk", "Alternating walk", 1.0, .looping, &tracks, &event_inputs, injector);
}

fn createJumpStart(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !clip.ClipDefinition {
    const pelvis = [_]clip.TranslationKeyInput{
        translationKey(0, 0, 0.90, smooth),
        translationKey(0.24, 0, 0.70, smooth),
        translationKey(0.40, 0, 0.78, linear),
    };
    const thighs = [_]clip.RotationKeyInput{
        rotationKey(0, -std.math.pi / 2.0, smooth),
        rotationKey(0.24, -1.18, smooth),
        rotationKey(0.40, -1.30, linear),
    };
    const shins = [_]clip.RotationKeyInput{
        rotationKey(0, 0, smooth),
        rotationKey(0.24, -0.62, smooth),
        rotationKey(0.40, -0.35, linear),
    };
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = semantic(.pelvis), .translation_keys = &pelvis },
        .{ .target_semantic = semantic(.left_thigh), .rotation_keys = &thighs },
        .{ .target_semantic = semantic(.right_thigh), .rotation_keys = &thighs },
        .{ .target_semantic = semantic(.left_shin), .rotation_keys = &shins },
        .{ .target_semantic = semantic(.right_shin), .rotation_keys = &shins },
    };
    return create(allocator, definition, .jump_start, "jump_start", "Jump preparation", 0.40, .one_shot, &tracks, &.{}, injector);
}

fn createRising(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !clip.ClipDefinition {
    const left_arm = heldMotion(std.math.pi, -0.72, -0.66);
    const right_arm = heldMotion(0, 0.72, 0.66);
    const thigh = heldMotion(-std.math.pi / 2.0, 0.18, 0.12);
    const shin = heldMotion(0, -0.18, -0.12);
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = semantic(.left_upper_arm), .rotation_keys = &left_arm },
        .{ .target_semantic = semantic(.right_upper_arm), .rotation_keys = &right_arm },
        .{ .target_semantic = semantic(.left_thigh), .rotation_keys = &thigh },
        .{ .target_semantic = semantic(.right_thigh), .rotation_keys = &thigh },
        .{ .target_semantic = semantic(.left_shin), .rotation_keys = &shin },
        .{ .target_semantic = semantic(.right_shin), .rotation_keys = &shin },
    };
    return create(allocator, definition, .rising, "rising", "Airborne rising", 0.60, .looping, &tracks, &.{}, injector);
}

fn createFalling(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !clip.ClipDefinition {
    const left_arm = heldMotion(std.math.pi, 0.82, 0.74);
    const right_arm = heldMotion(0, -0.82, -0.74);
    const thigh = heldMotion(-std.math.pi / 2.0, -0.32, -0.25);
    const shin = heldMotion(0, 0.58, 0.50);
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = semantic(.left_upper_arm), .rotation_keys = &left_arm },
        .{ .target_semantic = semantic(.right_upper_arm), .rotation_keys = &right_arm },
        .{ .target_semantic = semantic(.left_thigh), .rotation_keys = &thigh },
        .{ .target_semantic = semantic(.right_thigh), .rotation_keys = &thigh },
        .{ .target_semantic = semantic(.left_shin), .rotation_keys = &shin },
        .{ .target_semantic = semantic(.right_shin), .rotation_keys = &shin },
    };
    return create(allocator, definition, .falling, "falling", "Airborne falling", 0.60, .looping, &tracks, &.{}, injector);
}

fn createLanding(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !clip.ClipDefinition {
    const pelvis = [_]clip.TranslationKeyInput{
        translationKey(0, 0, 0.90, smooth),
        translationKey(0.16, 0, 0.67, smooth),
        translationKey(0.34, 0, 0.84, smooth),
        translationKey(0.50, 0, 0.90, linear),
    };
    const thigh = [_]clip.RotationKeyInput{
        rotationKey(0, -std.math.pi / 2.0, smooth),
        rotationKey(0.16, -1.20, smooth),
        rotationKey(0.50, -std.math.pi / 2.0, linear),
    };
    const shin = [_]clip.RotationKeyInput{
        rotationKey(0, 0, smooth),
        rotationKey(0.16, -0.60, smooth),
        rotationKey(0.50, 0, linear),
    };
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = semantic(.pelvis), .translation_keys = &pelvis },
        .{ .target_semantic = semantic(.left_thigh), .rotation_keys = &thigh },
        .{ .target_semantic = semantic(.right_thigh), .rotation_keys = &thigh },
        .{ .target_semantic = semantic(.left_shin), .rotation_keys = &shin },
        .{ .target_semantic = semantic(.right_shin), .rotation_keys = &shin },
    };
    return create(allocator, definition, .landing, "landing", "Landing compression", 0.50, .one_shot, &tracks, &.{}, injector);
}

fn createHandshakeA(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !clip.ClipDefinition {
    const upper = handshakeMotion(0, 0.34);
    const forearm = handshakeMotion(0, -0.42);
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = semantic(.right_upper_arm), .rotation_keys = &upper },
        .{ .target_semantic = semantic(.right_forearm), .rotation_keys = &forearm },
    };
    const event_inputs = handshakeEvents(@intFromEnum(humanoid.AttachmentSemantic.right_forearm), 70);
    return create(allocator, definition, .handshake_role_a, "handshake_role_a", "Handshake role A", 1.60, .one_shot, &tracks, &event_inputs, injector);
}

fn createHandshakeB(allocator: std.mem.Allocator, definition: *const skeleton.SkeletonDefinition, injector: ?fault_injection.Injector) !clip.ClipDefinition {
    // Facing reflection makes the anatomical right arm the receiver's inward handshake limb.
    // The previous left-arm track reflected outward, keeping the paired sockets a full root-spacing apart.
    const upper = handshakeMotion(0, 0.34);
    const forearm = handshakeMotion(0, -0.42);
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = semantic(.right_upper_arm), .rotation_keys = &upper },
        .{ .target_semantic = semantic(.right_forearm), .rotation_keys = &forearm },
    };
    const event_inputs = handshakeEvents(@intFromEnum(humanoid.AttachmentSemantic.right_forearm), 72);
    return create(allocator, definition, .handshake_role_b, "handshake_role_b", "Handshake role B", 1.60, .one_shot, &tracks, &event_inputs, injector);
}

fn create(
    allocator: std.mem.Allocator,
    definition: *const skeleton.SkeletonDefinition,
    id: clip.ClipId,
    identifier: []const u8,
    debug_name: []const u8,
    duration: f32,
    playback: clip.PlaybackMode,
    tracks: []const clip.TrackInput,
    event_inputs: []const events.EventInput,
    injector: ?fault_injection.Injector,
) !clip.ClipDefinition {
    return clip.ClipDefinition.init(allocator, definition, humanoid.canonical_attachment_semantic_count, .{
        .clip_id = @intFromEnum(id),
        .identifier = identifier,
        .debug_name = debug_name,
        .duration = duration,
        .playback_mode = @intFromEnum(playback),
        .tracks = tracks,
        .event_inputs = event_inputs,
    }, injector);
}

fn stateInput(id: state_machine.StateId, clip_id: clip.ClipId, speed: f32, fallback: ?state_machine.StateId, fallback_blend: f32) state_machine.StateInput {
    return .{
        .state_id = @intFromEnum(id),
        .clip_id = @intFromEnum(clip_id),
        .playback_speed = speed,
        .fallback_state = if (fallback) |value| @intFromEnum(value) else null,
        .fallback_blend_duration = fallback_blend,
    };
}

fn semantic(value: skeleton.BoneSemantic) u8 {
    return @intFromEnum(value);
}

fn translationKey(time: f32, x: f32, y: f32, interpolation: u8) clip.TranslationKeyInput {
    return .{ .timestamp = time, .value = .{ .x = x, .y = y }, .interpolation = interpolation };
}

fn rotationKey(time: f32, radians: f32, interpolation: u8) clip.RotationKeyInput {
    return .{ .timestamp = time, .value_radians = radians, .interpolation = interpolation };
}

fn scaleKey(time: f32, x: f32, y: f32, interpolation: u8) clip.ScaleKeyInput {
    return .{ .timestamp = time, .value = .{ .x = x, .y = y }, .interpolation = interpolation };
}

fn eventInput(id: u16, time: f32, event_type: events.EventType) events.EventInput {
    return .{ .id = id, .timestamp = time, .event_type = @intFromEnum(event_type) };
}

fn swingKeys(center: f32, amplitude: f32) [3]clip.RotationKeyInput {
    return .{
        rotationKey(0, center + amplitude, smooth),
        rotationKey(0.5, center - amplitude, smooth),
        rotationKey(1, center + amplitude, smooth),
    };
}

fn bendKeys(first: f32, second: f32) [3]clip.RotationKeyInput {
    return .{
        rotationKey(0, first, smooth),
        rotationKey(0.5, second, smooth),
        rotationKey(1, first, smooth),
    };
}

fn heldMotion(base: f32, first_offset: f32, middle_offset: f32) [3]clip.RotationKeyInput {
    return .{
        rotationKey(0, base + first_offset, smooth),
        rotationKey(0.3, base + middle_offset, smooth),
        rotationKey(0.6, base + first_offset, smooth),
    };
}

fn handshakeMotion(base: f32, extension: f32) [4]clip.RotationKeyInput {
    return .{
        rotationKey(0, base, smooth),
        rotationKey(0.55, base + extension, smooth),
        rotationKey(1.20, base + extension, smooth),
        rotationKey(1.60, base, smooth),
    };
}

fn handshakeEvents(attachment: u8, layer: u16) [5]events.EventInput {
    return .{
        eventInput(1, 0.60, .hand_contact),
        .{ .id = 2, .timestamp = 0.60, .event_type = @intFromEnum(events.EventType.body_part_layer_change), .layer_change = .{ .attachment_semantic = attachment, .requested_layer = layer, .restoration = @intFromEnum(events.LayerRestoration.restore_authored) } },
        eventInput(3, 1.20, .hand_release),
        .{ .id = 4, .timestamp = 1.20, .event_type = @intFromEnum(events.EventType.body_part_layer_change), .layer_change = .{ .attachment_semantic = attachment, .requested_layer = 0, .restoration = @intFromEnum(events.LayerRestoration.restore_authored) } },
        eventInput(5, 1.50, .interaction_complete),
    };
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
