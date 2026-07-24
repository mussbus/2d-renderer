const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const events = @import("events");
const fault_injection = @import("fault_injection");

pub const maximum_tracks: usize = skeleton.maximum_bones;
pub const maximum_keys_per_component: usize = 4096;
pub const maximum_events: usize = 256;
pub const maximum_event_wraps_per_update: u32 = 8;

pub const ClipId = enum(u8) {
    idle,
    walk,
    jump_start,
    rising,
    falling,
    landing,
    handshake_role_a,
    handshake_role_b,
};

pub const clip_count: usize = 8;

pub const PlaybackMode = enum(u8) {
    looping,
    one_shot,
};

pub const InterpolationMode = enum(u8) {
    step,
    linear,
    smooth,
};

pub const TranslationKeyInput = struct {
    timestamp: f32,
    value: math.Vec2,
    interpolation: u8,
};

pub const RotationKeyInput = struct {
    timestamp: f32,
    value_radians: f32,
    interpolation: u8,
};

pub const ScaleKeyInput = struct {
    timestamp: f32,
    value: math.Vec2,
    interpolation: u8,
};

pub const TrackInput = struct {
    target_semantic: u8,
    translation_keys: []const TranslationKeyInput = &.{},
    rotation_keys: []const RotationKeyInput = &.{},
    scale_keys: []const ScaleKeyInput = &.{},
};

pub const ClipDefinitionInput = struct {
    clip_id: u8,
    identifier: []const u8,
    debug_name: []const u8,
    duration: f32,
    playback_mode: u8,
    tracks: []const TrackInput,
    event_inputs: []const events.EventInput,
};

pub const KeyRange = extern struct {
    start: u32,
    count: u32,
};

pub const TranslationKey = struct {
    timestamp: f32,
    value: math.Vec2,
    interpolation: InterpolationMode,
};

pub const RotationKey = struct {
    timestamp: f32,
    value_radians: f32,
    interpolation: InterpolationMode,
};

pub const ScaleKey = struct {
    timestamp: f32,
    value: math.Vec2,
    interpolation: InterpolationMode,
};

pub const BoneTrack = struct {
    target_bone: u16,
    target_semantic: skeleton.BoneSemantic,
    translation_range: KeyRange,
    rotation_range: KeyRange,
    scale_range: KeyRange,
};

pub const ClipDefinition = struct {
    allocator: std.mem.Allocator,
    id: ClipId,
    identifier: skeleton.DebugName,
    debug_name: skeleton.DebugName,
    duration: f32,
    playback_mode: PlaybackMode,
    skeleton_token: usize,
    bone_count: usize,
    bone_track_indices: []const ?u16,
    tracks: []const BoneTrack,
    translation_keys: []const TranslationKey,
    rotation_keys: []const RotationKey,
    scale_keys: []const ScaleKey,
    event_records: []const events.EventRecord,

    pub fn init(
        allocator: std.mem.Allocator,
        definition: *const skeleton.SkeletonDefinition,
        attachment_semantic_count: usize,
        input: ClipDefinitionInput,
        injector: ?fault_injection.Injector,
    ) !ClipDefinition {
        if (input.clip_id >= clip_count) return error.InvalidClipIdentifier;
        if (input.identifier.len == 0) return error.EmptyClipIdentifier;
        const identifier = skeleton.DebugName.init(input.identifier) catch |err| return err;
        const debug_name = skeleton.DebugName.init(input.debug_name) catch |err| return err;
        if (!std.math.isFinite(input.duration)) return error.NonFiniteDuration;
        if (input.duration < 0) return error.NegativeDuration;
        if (input.duration == 0) return error.ZeroDuration;
        if (input.playback_mode >= std.enums.values(PlaybackMode).len) return error.UnknownPlaybackMode;
        if (input.tracks.len > maximum_tracks or input.event_inputs.len > maximum_events) return error.SupportedCountOverflow;

        var translation_count: usize = 0;
        var rotation_count: usize = 0;
        var scale_count: usize = 0;
        for (input.tracks) |track| {
            translation_count = std.math.add(usize, translation_count, track.translation_keys.len) catch return error.ByteSizeOverflow;
            rotation_count = std.math.add(usize, rotation_count, track.rotation_keys.len) catch return error.ByteSizeOverflow;
            scale_count = std.math.add(usize, scale_count, track.scale_keys.len) catch return error.ByteSizeOverflow;
        }
        if (translation_count > maximum_keys_per_component or rotation_count > maximum_keys_per_component or scale_count > maximum_keys_per_component) {
            return error.SupportedCountOverflow;
        }
        _ = std.math.mul(usize, translation_count, @sizeOf(TranslationKey)) catch return error.ByteSizeOverflow;
        _ = std.math.mul(usize, rotation_count, @sizeOf(RotationKey)) catch return error.ByteSizeOverflow;
        _ = std.math.mul(usize, scale_count, @sizeOf(ScaleKey)) catch return error.ByteSizeOverflow;

        const mapping = allocator.alloc(?u16, definition.boneCount()) catch return error.AllocationFailure;
        errdefer allocator.free(mapping);
        @memset(mapping, null);
        try after(injector, .clip_definition_allocation);

        const tracks = allocator.alloc(BoneTrack, input.tracks.len) catch return error.AllocationFailure;
        errdefer allocator.free(tracks);
        try after(injector, .track_allocation);

        const translation_keys = allocator.alloc(TranslationKey, translation_count) catch return error.AllocationFailure;
        errdefer allocator.free(translation_keys);
        try after(injector, .translation_key_allocation);
        const rotation_keys = allocator.alloc(RotationKey, rotation_count) catch return error.AllocationFailure;
        errdefer allocator.free(rotation_keys);
        try after(injector, .rotation_key_allocation);
        const scale_keys = allocator.alloc(ScaleKey, scale_count) catch return error.AllocationFailure;
        errdefer allocator.free(scale_keys);
        try after(injector, .scale_key_allocation);
        const event_records = allocator.alloc(events.EventRecord, input.event_inputs.len) catch return error.AllocationFailure;
        errdefer allocator.free(event_records);
        try after(injector, .event_allocation);

        var translation_offset: usize = 0;
        var rotation_offset: usize = 0;
        var scale_offset: usize = 0;
        for (input.tracks, 0..) |track_input, track_index| {
            if (track_input.target_semantic >= skeleton.bone_semantic_count) return error.UnknownTargetBone;
            const semantic: skeleton.BoneSemantic = @enumFromInt(track_input.target_semantic);
            const bone_index = definition.boneIndex(semantic) catch return error.UnknownTargetBone;
            if (mapping[bone_index] != null) return error.DuplicateTrack;
            if (track_input.translation_keys.len == 0 and track_input.rotation_keys.len == 0 and track_input.scale_keys.len == 0) {
                return error.EmptyBoneTrack;
            }

            const translation_start = translation_offset;
            try copyTranslationKeys(translation_keys, &translation_offset, track_input.translation_keys, input.duration);
            const rotation_start = rotation_offset;
            try copyRotationKeys(rotation_keys, &rotation_offset, track_input.rotation_keys, input.duration);
            const scale_start = scale_offset;
            try copyScaleKeys(scale_keys, &scale_offset, track_input.scale_keys, input.duration);
            tracks[track_index] = .{
                .target_bone = bone_index,
                .target_semantic = semantic,
                .translation_range = makeRange(translation_start, track_input.translation_keys.len),
                .rotation_range = makeRange(rotation_start, track_input.rotation_keys.len),
                .scale_range = makeRange(scale_start, track_input.scale_keys.len),
            };
            mapping[bone_index] = @intCast(track_index);
        }

        var previous_event_time: f32 = 0;
        for (input.event_inputs, 0..) |event_input, index| {
            if (!std.math.isFinite(event_input.timestamp)) return error.NonFiniteEventTime;
            if (event_input.timestamp < 0) return error.EventBeforeZero;
            if (event_input.timestamp > input.duration) return error.EventAfterDuration;
            if (index > 0 and event_input.timestamp < previous_event_time) return error.UnsortedEvents;
            previous_event_time = event_input.timestamp;
            for (input.event_inputs[0..index]) |existing| {
                if (existing.id == event_input.id) return error.DuplicateEventIdentifier;
            }
            const event_type = try events.validateType(event_input.event_type);
            const restoration = try events.validateRestoration(event_input.layer_change.restoration);
            if (event_type == .body_part_layer_change) {
                if (event_input.layer_change.attachment_semantic >= attachment_semantic_count) return error.InvalidLayerEventTarget;
            }
            event_records[index] = .{
                .id = event_input.id,
                .timestamp = event_input.timestamp,
                .event_type = event_type,
                .layer_change = .{
                    .attachment_semantic = event_input.layer_change.attachment_semantic,
                    .requested_layer = event_input.layer_change.requested_layer,
                    .restoration = restoration,
                },
            };
        }

        return .{
            .allocator = allocator,
            .id = @enumFromInt(input.clip_id),
            .identifier = identifier,
            .debug_name = debug_name,
            .duration = input.duration,
            .playback_mode = @enumFromInt(input.playback_mode),
            .skeleton_token = definition.compatibilityToken(),
            .bone_count = definition.boneCount(),
            .bone_track_indices = mapping,
            .tracks = tracks,
            .translation_keys = translation_keys,
            .rotation_keys = rotation_keys,
            .scale_keys = scale_keys,
            .event_records = event_records,
        };
    }

    pub fn deinit(clip: *ClipDefinition) void {
        clip.allocator.free(clip.event_records);
        clip.allocator.free(clip.scale_keys);
        clip.allocator.free(clip.rotation_keys);
        clip.allocator.free(clip.translation_keys);
        clip.allocator.free(clip.tracks);
        clip.allocator.free(clip.bone_track_indices);
        clip.* = undefined;
    }

    pub fn validateCompatibility(clip: ClipDefinition, definition: *const skeleton.SkeletonDefinition) !void {
        if (clip.bone_count != definition.boneCount()) return error.ClipSkeletonMismatch;
        if (clip.skeleton_token != definition.compatibilityToken()) return error.ClipSkeletonMismatch;
    }
};

pub const TimeAdvance = struct {
    previous_time: f32,
    current_time: f32,
    wraps: u32,
    completed_now: bool,
    moved: bool,
};

pub fn advanceTime(clip: *const ClipDefinition, current_time: f32, delta_seconds: f32, playback_speed: f32) !TimeAdvance {
    if (!std.math.isFinite(current_time) or current_time < 0 or current_time > clip.duration) return error.InvalidPlaybackTime;
    if (!std.math.isFinite(delta_seconds) or delta_seconds < 0) return error.InvalidAnimationDelta;
    if (!std.math.isFinite(playback_speed)) return error.InvalidPlaybackSpeed;
    if (playback_speed < 0) return error.NegativePlaybackSpeedUnsupported;
    const scaled_delta = delta_seconds * playback_speed;
    if (!std.math.isFinite(scaled_delta)) return error.InvalidAnimationDelta;
    if (scaled_delta == 0) return .{
        .previous_time = current_time,
        .current_time = current_time,
        .wraps = 0,
        .completed_now = false,
        .moved = false,
    };

    if (clip.playback_mode == .one_shot) {
        const next = @min(clip.duration, current_time + scaled_delta);
        return .{
            .previous_time = current_time,
            .current_time = next,
            .wraps = 0,
            .completed_now = current_time < clip.duration and next == clip.duration,
            .moved = next != current_time,
        };
    }

    const total: f64 = @as(f64, current_time) + @as(f64, scaled_delta);
    const duration: f64 = clip.duration;
    const wrap_value = @floor(total / duration);
    if (wrap_value > maximum_event_wraps_per_update) return error.EventTraversalLimitExceeded;
    const wraps: u32 = @intFromFloat(wrap_value);
    var wrapped = total - @as(f64, @floatFromInt(wraps)) * duration;
    if (wrapped >= duration) wrapped = 0;
    return .{
        .previous_time = current_time,
        .current_time = @floatCast(wrapped),
        .wraps = wraps,
        .completed_now = false,
        .moved = true,
    };
}

pub fn emitEvents(
    clip: *const ClipDefinition,
    advance: TimeAdvance,
    starting_loop: u64,
    state_entered: bool,
    output: *events.EventBuffer,
) !void {
    if (state_entered) try emitZeroEvents(clip, starting_loop, output);
    if (!advance.moved) return;
    if (clip.playback_mode == .one_shot or advance.wraps == 0) {
        try emitOpenClosed(clip, advance.previous_time, advance.current_time, starting_loop, output);
        return;
    }

    try emitOpenClosed(clip, advance.previous_time, clip.duration, starting_loop, output);
    var wrap_index: u32 = 1;
    while (wrap_index <= advance.wraps) : (wrap_index += 1) {
        const loop_index = std.math.add(u64, starting_loop, wrap_index) catch return error.LoopCountOverflow;
        try emitZeroEvents(clip, loop_index, output);
        if (wrap_index < advance.wraps) {
            try emitOpenClosed(clip, 0, clip.duration, loop_index, output);
        } else if (advance.current_time > 0) {
            try emitOpenClosed(clip, 0, advance.current_time, loop_index, output);
        }
    }
}

pub fn sampleWithSource(
    clip: *const ClipDefinition,
    definition: *const skeleton.SkeletonDefinition,
    sample_time: f32,
    source_token: usize,
    source: []const math.Transform2D,
    output_token: usize,
    output: []math.Transform2D,
) !void {
    try validateSamplingInputs(clip, definition, sample_time, source_token, source, output_token, output);
    if (slicesOverlap(source, output)) return error.SourceOutputAliasing;
    @memcpy(output, source);
    try applyTracks(clip, try normalizedSampleTime(clip, sample_time), output);
}

pub fn sampleFromRest(
    clip: *const ClipDefinition,
    definition: *const skeleton.SkeletonDefinition,
    sample_time: f32,
    output_token: usize,
    output: []math.Transform2D,
) !void {
    try clip.validateCompatibility(definition);
    if (output_token != definition.compatibilityToken()) return error.PoseDefinitionMismatch;
    if (output.len != definition.boneCount()) return error.PoseLengthMismatch;
    _ = try normalizedSampleTime(clip, sample_time);
    for (definition.bones, 0..) |bone, index| output[index] = bone.rest_local;
    try applyTracks(clip, try normalizedSampleTime(clip, sample_time), output);
}

fn validateSamplingInputs(
    clip: *const ClipDefinition,
    definition: *const skeleton.SkeletonDefinition,
    sample_time: f32,
    source_token: usize,
    source: []const math.Transform2D,
    output_token: usize,
    output: []math.Transform2D,
) !void {
    try clip.validateCompatibility(definition);
    if (source_token != definition.compatibilityToken() or output_token != definition.compatibilityToken()) return error.PoseDefinitionMismatch;
    if (source.len != definition.boneCount() or output.len != definition.boneCount()) return error.PoseLengthMismatch;
    _ = try normalizedSampleTime(clip, sample_time);
    for (source) |transform| try transform.validate();
}

fn normalizedSampleTime(clip: *const ClipDefinition, time: f32) !f32 {
    if (!std.math.isFinite(time)) return error.NonFiniteSampleTime;
    if (time < 0) return error.SampleTimeBeforeZero;
    if (time <= clip.duration) return time;
    if (clip.playback_mode == .one_shot) return clip.duration;
    const cycles = @floor(time / clip.duration);
    return time - cycles * clip.duration;
}

fn applyTracks(clip: *const ClipDefinition, time: f32, output: []math.Transform2D) !void {
    for (clip.tracks) |track| {
        var value = output[track.target_bone];
        const translations = rangeSlice(TranslationKey, clip.translation_keys, track.translation_range);
        if (translations.len > 0) value.translation = sampleTranslation(translations, time);
        const rotations = rangeSlice(RotationKey, clip.rotation_keys, track.rotation_range);
        if (rotations.len > 0) value.rotation_radians = sampleRotation(rotations, time);
        const scales = rangeSlice(ScaleKey, clip.scale_keys, track.scale_range);
        if (scales.len > 0) value.scale = sampleScale(scales, time);
        try value.validate();
        output[track.target_bone] = value;
    }
}

fn sampleTranslation(keys: []const TranslationKey, time: f32) math.Vec2 {
    const interval = findInterval(TranslationKey, keys, time);
    if (interval.left == interval.right) return keys[interval.left].value;
    const left = keys[interval.left];
    const right = keys[interval.right];
    const amount = interpolationAmount(left.timestamp, right.timestamp, time, left.interpolation);
    return .{
        .x = left.value.x + (right.value.x - left.value.x) * amount,
        .y = left.value.y + (right.value.y - left.value.y) * amount,
    };
}

fn sampleRotation(keys: []const RotationKey, time: f32) f32 {
    const interval = findInterval(RotationKey, keys, time);
    if (interval.left == interval.right) return wrapFinite(keys[interval.left].value_radians);
    const left = keys[interval.left];
    const right = keys[interval.right];
    const amount = interpolationAmount(left.timestamp, right.timestamp, time, left.interpolation);
    const difference = wrapFinite(right.value_radians - left.value_radians);
    return wrapFinite(left.value_radians + difference * amount);
}

fn sampleScale(keys: []const ScaleKey, time: f32) math.Vec2 {
    const interval = findInterval(ScaleKey, keys, time);
    if (interval.left == interval.right) return keys[interval.left].value;
    const left = keys[interval.left];
    const right = keys[interval.right];
    const amount = interpolationAmount(left.timestamp, right.timestamp, time, left.interpolation);
    return .{
        .x = left.value.x + (right.value.x - left.value.x) * amount,
        .y = left.value.y + (right.value.y - left.value.y) * amount,
    };
}

const Interval = struct { left: usize, right: usize };

fn findInterval(comptime Key: type, keys: []const Key, time: f32) Interval {
    if (keys.len == 1 or time <= keys[0].timestamp) return .{ .left = 0, .right = 0 };
    if (time >= keys[keys.len - 1].timestamp) return .{ .left = keys.len - 1, .right = keys.len - 1 };
    var low: usize = 1;
    var high: usize = keys.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (keys[middle].timestamp <= time) low = middle + 1 else high = middle;
    }
    return .{ .left = low - 1, .right = low };
}

fn interpolationAmount(from_time: f32, to_time: f32, time: f32, mode: InterpolationMode) f32 {
    if (mode == .step) return 0;
    const linear = (time - from_time) / (to_time - from_time);
    if (mode == .linear) return linear;
    return linear * linear * (3.0 - 2.0 * linear);
}

fn wrapFinite(radians: f32) f32 {
    const tau = 2.0 * std.math.pi;
    return radians - @floor((radians + std.math.pi) / tau) * tau;
}

fn copyTranslationKeys(output: []TranslationKey, offset: *usize, inputs: []const TranslationKeyInput, duration: f32) !void {
    for (inputs, 0..) |input, index| {
        try validateKeyTime(inputs, index, input.timestamp, duration);
        if (!input.value.isFinite()) return error.NonFiniteKeyValue;
        output[offset.*] = .{ .timestamp = input.timestamp, .value = input.value, .interpolation = try interpolationMode(input.interpolation) };
        offset.* += 1;
    }
}

fn copyRotationKeys(output: []RotationKey, offset: *usize, inputs: []const RotationKeyInput, duration: f32) !void {
    for (inputs, 0..) |input, index| {
        try validateKeyTime(inputs, index, input.timestamp, duration);
        if (!std.math.isFinite(input.value_radians)) return error.NonFiniteKeyValue;
        output[offset.*] = .{ .timestamp = input.timestamp, .value_radians = input.value_radians, .interpolation = try interpolationMode(input.interpolation) };
        offset.* += 1;
    }
}

fn copyScaleKeys(output: []ScaleKey, offset: *usize, inputs: []const ScaleKeyInput, duration: f32) !void {
    for (inputs, 0..) |input, index| {
        try validateKeyTime(inputs, index, input.timestamp, duration);
        if (!input.value.isFinite()) return error.NonFiniteKeyValue;
        output[offset.*] = .{ .timestamp = input.timestamp, .value = input.value, .interpolation = try interpolationMode(input.interpolation) };
        offset.* += 1;
    }
}

fn validateKeyTime(inputs: anytype, index: usize, timestamp: f32, duration: f32) !void {
    if (!std.math.isFinite(timestamp)) return error.NonFiniteKeyTime;
    if (timestamp < 0) return error.KeyBeforeZero;
    if (timestamp > duration) return error.KeyAfterDuration;
    if (index > 0) {
        const previous = inputs[index - 1].timestamp;
        if (timestamp < previous) return error.UnsortedKeyTimes;
        if (timestamp == previous) return error.DuplicateKeyTimestamp;
    }
}

fn interpolationMode(raw: u8) !InterpolationMode {
    if (raw >= std.enums.values(InterpolationMode).len) return error.UnknownInterpolationMode;
    return @enumFromInt(raw);
}

fn makeRange(start: usize, count: usize) KeyRange {
    return .{ .start = @intCast(start), .count = @intCast(count) };
}

fn rangeSlice(comptime Key: type, keys: []const Key, range: KeyRange) []const Key {
    const start: usize = range.start;
    return keys[start .. start + range.count];
}

fn slicesOverlap(source: []const math.Transform2D, output: []math.Transform2D) bool {
    if (source.len == 0 or output.len == 0) return false;
    const source_start = @intFromPtr(source.ptr);
    const source_end = source_start + source.len * @sizeOf(math.Transform2D);
    const output_start = @intFromPtr(output.ptr);
    const output_end = output_start + output.len * @sizeOf(math.Transform2D);
    return source_start < output_end and output_start < source_end;
}

fn emitZeroEvents(clip: *const ClipDefinition, loop_index: u64, output: *events.EventBuffer) !void {
    for (clip.event_records) |record| {
        if (record.timestamp == 0) try output.append(@intFromEnum(clip.id), loop_index, record);
    }
}

fn emitOpenClosed(clip: *const ClipDefinition, from: f32, to: f32, loop_index: u64, output: *events.EventBuffer) !void {
    for (clip.event_records) |record| {
        if (record.timestamp > from and record.timestamp <= to) {
            try output.append(@intFromEnum(clip.id), loop_index, record);
        }
    }
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
