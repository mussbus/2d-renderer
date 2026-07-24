const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const pose = @import("pose");
const humanoid = @import("humanoid");
const events = @import("events");
const clip = @import("clip");
const animator_module = @import("animator");
const state_machine = @import("state_machine");
const authored = @import("authored_clips");
const animation_system = @import("animation_system");
const fault_injection = @import("fault_injection");

const tolerance: f32 = 1e-5;
const linear = @intFromEnum(clip.InterpolationMode.linear);
const smooth = @intFromEnum(clip.InterpolationMode.smooth);
const step = @intFromEnum(clip.InterpolationMode.step);

fn makeDefinition() !humanoid.HumanoidDefinition {
    return humanoid.HumanoidDefinition.init(std.testing.allocator, null);
}

fn oneKeyTrack() [1]clip.RotationKeyInput {
    return .{.{ .timestamp = 0, .value_radians = 0.25, .interpolation = linear }};
}

fn minimalInput(tracks: []const clip.TrackInput, event_inputs: []const events.EventInput) clip.ClipDefinitionInput {
    return .{
        .clip_id = @intFromEnum(clip.ClipId.idle),
        .identifier = "test_clip",
        .debug_name = "Test clip",
        .duration = 1,
        .playback_mode = @intFromEnum(clip.PlaybackMode.looping),
        .tracks = tracks,
        .event_inputs = event_inputs,
    };
}

fn initClip(definition: *const skeleton.SkeletonDefinition, input: clip.ClipDefinitionInput) !clip.ClipDefinition {
    return clip.ClipDefinition.init(std.testing.allocator, definition, humanoid.canonical_attachment_semantic_count, input, null);
}

fn fillRest(definition: *const skeleton.SkeletonDefinition, output: []math.Transform2D) void {
    for (definition.bones, 0..) |bone, index| output[index] = bone.rest_local;
}

fn expectVec(expected: math.Vec2, actual: math.Vec2) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
}

test "clip validation rejects malformed identifiers duration tracks keys events and layer data transactionally" {
    var definition = try makeDefinition();
    defer definition.deinit();
    const key = oneKeyTrack();
    const valid_tracks = [_]clip.TrackInput{.{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.right_upper_arm), .rotation_keys = &key }};

    var valid = try initClip(&definition.skeleton_definition, minimalInput(&valid_tracks, &.{}));
    valid.deinit();

    var input = minimalInput(&valid_tracks, &.{});
    input.identifier = "";
    try std.testing.expectError(error.EmptyClipIdentifier, initClip(&definition.skeleton_definition, input));
    input = minimalInput(&valid_tracks, &.{});
    input.debug_name = "";
    try std.testing.expectError(error.EmptyDebugName, initClip(&definition.skeleton_definition, input));
    input = minimalInput(&valid_tracks, &.{});
    input.duration = -1;
    try std.testing.expectError(error.NegativeDuration, initClip(&definition.skeleton_definition, input));
    input.duration = 0;
    try std.testing.expectError(error.ZeroDuration, initClip(&definition.skeleton_definition, input));
    input.duration = std.math.nan(f32);
    try std.testing.expectError(error.NonFiniteDuration, initClip(&definition.skeleton_definition, input));

    const unknown_tracks = [_]clip.TrackInput{.{ .target_semantic = 255, .rotation_keys = &key }};
    try std.testing.expectError(error.UnknownTargetBone, initClip(&definition.skeleton_definition, minimalInput(&unknown_tracks, &.{})));
    const duplicate_tracks = [_]clip.TrackInput{ valid_tracks[0], valid_tracks[0] };
    try std.testing.expectError(error.DuplicateTrack, initClip(&definition.skeleton_definition, minimalInput(&duplicate_tracks, &.{})));
    const too_many_tracks = [_]clip.TrackInput{valid_tracks[0]} ** (clip.maximum_tracks + 1);
    try std.testing.expectError(error.SupportedCountOverflow, initClip(&definition.skeleton_definition, minimalInput(&too_many_tracks, &.{})));
    const empty_tracks = [_]clip.TrackInput{.{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.pelvis) }};
    try std.testing.expectError(error.EmptyBoneTrack, initClip(&definition.skeleton_definition, minimalInput(&empty_tracks, &.{})));

    var malformed_keys = [_]clip.TranslationKeyInput{
        .{ .timestamp = 0.8, .value = .{ .x = 1, .y = 2 }, .interpolation = linear },
        .{ .timestamp = 0.2, .value = .{ .x = 3, .y = 4 }, .interpolation = linear },
    };
    var malformed_track = [_]clip.TrackInput{.{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.pelvis), .translation_keys = &malformed_keys }};
    try std.testing.expectError(error.UnsortedKeyTimes, initClip(&definition.skeleton_definition, minimalInput(&malformed_track, &.{})));
    malformed_keys[1].timestamp = 0.8;
    try std.testing.expectError(error.DuplicateKeyTimestamp, initClip(&definition.skeleton_definition, minimalInput(&malformed_track, &.{})));
    malformed_keys[0].timestamp = -0.1;
    try std.testing.expectError(error.KeyBeforeZero, initClip(&definition.skeleton_definition, minimalInput(&malformed_track, &.{})));
    malformed_keys[0].timestamp = 0;
    malformed_keys[1].timestamp = 1.1;
    try std.testing.expectError(error.KeyAfterDuration, initClip(&definition.skeleton_definition, minimalInput(&malformed_track, &.{})));
    malformed_keys[1].timestamp = 1;
    malformed_keys[1].value.x = std.math.inf(f32);
    try std.testing.expectError(error.NonFiniteKeyValue, initClip(&definition.skeleton_definition, minimalInput(&malformed_track, &.{})));
    malformed_keys[1].value.x = 1;
    malformed_keys[1].interpolation = 255;
    try std.testing.expectError(error.UnknownInterpolationMode, initClip(&definition.skeleton_definition, minimalInput(&malformed_track, &.{})));
    malformed_keys[1].interpolation = linear;
    malformed_keys[0].timestamp = std.math.nan(f32);
    try std.testing.expectError(error.NonFiniteKeyTime, initClip(&definition.skeleton_definition, minimalInput(&malformed_track, &.{})));

    var event_inputs = [_]events.EventInput{.{ .id = 1, .timestamp = -0.1, .event_type = @intFromEnum(events.EventType.hand_contact) }};
    try std.testing.expectError(error.EventBeforeZero, initClip(&definition.skeleton_definition, minimalInput(&valid_tracks, &event_inputs)));
    event_inputs[0].timestamp = 1.1;
    try std.testing.expectError(error.EventAfterDuration, initClip(&definition.skeleton_definition, minimalInput(&valid_tracks, &event_inputs)));
    event_inputs[0].timestamp = std.math.nan(f32);
    try std.testing.expectError(error.NonFiniteEventTime, initClip(&definition.skeleton_definition, minimalInput(&valid_tracks, &event_inputs)));
    event_inputs[0] = .{
        .id = 1,
        .timestamp = 0.5,
        .event_type = @intFromEnum(events.EventType.body_part_layer_change),
        .layer_change = .{ .attachment_semantic = 255, .requested_layer = 20 },
    };
    try std.testing.expectError(error.InvalidLayerEventTarget, initClip(&definition.skeleton_definition, minimalInput(&valid_tracks, &event_inputs)));
    event_inputs[0].layer_change.attachment_semantic = 0;
    event_inputs[0].layer_change.restoration = 255;
    try std.testing.expectError(error.InvalidLayerEventData, initClip(&definition.skeleton_definition, minimalInput(&valid_tracks, &event_inputs)));
    const duplicate_events = [_]events.EventInput{
        .{ .id = 9, .timestamp = 0.2, .event_type = @intFromEnum(events.EventType.hand_contact) },
        .{ .id = 9, .timestamp = 0.4, .event_type = @intFromEnum(events.EventType.hand_release) },
    };
    try std.testing.expectError(error.DuplicateEventIdentifier, initClip(&definition.skeleton_definition, minimalInput(&valid_tracks, &duplicate_events)));
    const unsorted_events = [_]events.EventInput{
        .{ .id = 10, .timestamp = 0.7, .event_type = @intFromEnum(events.EventType.hand_contact) },
        .{ .id = 11, .timestamp = 0.3, .event_type = @intFromEnum(events.EventType.hand_release) },
    };
    try std.testing.expectError(error.UnsortedEvents, initClip(&definition.skeleton_definition, minimalInput(&valid_tracks, &unsorted_events)));
}

test "component sampling has explicit boundaries modes shortest rotation and source preservation" {
    var definition = try makeDefinition();
    defer definition.deinit();
    const translations = [_]clip.TranslationKeyInput{
        .{ .timestamp = 0.2, .value = .{ .x = 2, .y = 4 }, .interpolation = linear },
        .{ .timestamp = 0.5, .value = .{ .x = 8, .y = 10 }, .interpolation = linear },
        .{ .timestamp = 0.8, .value = .{ .x = 14, .y = 16 }, .interpolation = linear },
    };
    const rotations = [_]clip.RotationKeyInput{
        .{ .timestamp = 0, .value_radians = 350 * std.math.pi / 180.0, .interpolation = linear },
        .{ .timestamp = 1, .value_radians = 10 * std.math.pi / 180.0, .interpolation = linear },
    };
    const scales = [_]clip.ScaleKeyInput{
        .{ .timestamp = 0, .value = .{ .x = 1, .y = 2 }, .interpolation = smooth },
        .{ .timestamp = 1, .value = .{ .x = 3, .y = 6 }, .interpolation = smooth },
    };
    const one_key = [_]clip.TranslationKeyInput{.{ .timestamp = 0.4, .value = .{ .x = 7, .y = 9 }, .interpolation = step }};
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.pelvis), .translation_keys = &translations },
        .{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.right_upper_arm), .rotation_keys = &rotations },
        .{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.torso), .scale_keys = &scales },
        .{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.head), .translation_keys = &one_key },
    };
    var definition_clip = try initClip(&definition.skeleton_definition, minimalInput(&tracks, &.{}));
    defer definition_clip.deinit();

    var source_storage: [skeleton.maximum_bones]math.Transform2D = undefined;
    var output_storage: [skeleton.maximum_bones]math.Transform2D = undefined;
    const bone_count = definition.skeleton_definition.boneCount();
    const source = source_storage[0..bone_count];
    const output = output_storage[0..bone_count];
    fillRest(&definition.skeleton_definition, source);
    const source_before = source_storage;
    const first_key_before = definition_clip.translation_keys[0];
    const token = definition.skeleton_definition.compatibilityToken();
    const pelvis = try definition.skeleton_definition.boneIndex(.pelvis);
    const arm = try definition.skeleton_definition.boneIndex(.right_upper_arm);
    const torso = try definition.skeleton_definition.boneIndex(.torso);
    const head = try definition.skeleton_definition.boneIndex(.head);

    try clip.sampleWithSource(&definition_clip, &definition.skeleton_definition, 0, token, source, token, output);
    try expectVec(.{ .x = 2, .y = 4 }, output[pelvis].translation);
    try expectVec(.{ .x = 7, .y = 9 }, output[head].translation);
    try clip.sampleWithSource(&definition_clip, &definition.skeleton_definition, 0.35, token, source, token, output);
    try expectVec(.{ .x = 5, .y = 7 }, output[pelvis].translation);
    try clip.sampleWithSource(&definition_clip, &definition.skeleton_definition, 0.5, token, source, token, output);
    try expectVec(.{ .x = 8, .y = 10 }, output[pelvis].translation);
    try std.testing.expectApproxEqAbs(@as(f32, 0), output[arm].rotation_radians, tolerance);
    try expectVec(.{ .x = 2, .y = 4 }, output[torso].scale);
    try clip.sampleWithSource(&definition_clip, &definition.skeleton_definition, 1, token, source, token, output);
    try expectVec(.{ .x = 14, .y = 16 }, output[pelvis].translation);
    try clip.sampleWithSource(&definition_clip, &definition.skeleton_definition, 1.5, token, source, token, output);
    try expectVec(.{ .x = 8, .y = 10 }, output[pelvis].translation);

    try std.testing.expectEqualSlices(math.Transform2D, source_before[0..bone_count], source);
    try std.testing.expectEqual(first_key_before, definition_clip.translation_keys[0]);
    try std.testing.expect(output[pelvis].rotation_radians == source[pelvis].rotation_radians);
    try std.testing.expect(output[arm].translation.approxEqAbs(source[arm].translation, tolerance));
    try std.testing.expect(output[torso].rotation_radians == source[torso].rotation_radians);
    try std.testing.expectError(error.NonFiniteSampleTime, clip.sampleWithSource(&definition_clip, &definition.skeleton_definition, std.math.nan(f32), token, source, token, output));
    try std.testing.expectError(error.SourceOutputAliasing, clip.sampleWithSource(&definition_clip, &definition.skeleton_definition, 0.5, token, source, token, source));

    var second_definition = try makeDefinition();
    defer second_definition.deinit();
    try std.testing.expectError(error.PoseDefinitionMismatch, clip.sampleWithSource(&definition_clip, &definition.skeleton_definition, 0.5, second_definition.skeleton_definition.compatibilityToken(), source, token, output));
}

test "step and smooth interpolation use hand-derived weights" {
    var definition = try makeDefinition();
    defer definition.deinit();
    const step_keys = [_]clip.TranslationKeyInput{
        .{ .timestamp = 0, .value = .{ .x = 2, .y = 4 }, .interpolation = step },
        .{ .timestamp = 1, .value = .{ .x = 10, .y = 20 }, .interpolation = linear },
    };
    const smooth_keys = [_]clip.ScaleKeyInput{
        .{ .timestamp = 0, .value = .{ .x = 1, .y = 2 }, .interpolation = smooth },
        .{ .timestamp = 1, .value = .{ .x = 3, .y = 6 }, .interpolation = linear },
    };
    const tracks = [_]clip.TrackInput{
        .{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.pelvis), .translation_keys = &step_keys },
        .{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.torso), .scale_keys = &smooth_keys },
    };
    var definition_clip = try initClip(&definition.skeleton_definition, minimalInput(&tracks, &.{}));
    defer definition_clip.deinit();
    var output: [skeleton.maximum_bones]math.Transform2D = undefined;
    const values = output[0..definition.skeleton_definition.boneCount()];
    try clip.sampleFromRest(&definition_clip, &definition.skeleton_definition, 0.25, definition.skeleton_definition.compatibilityToken(), values);
    try expectVec(.{ .x = 2, .y = 4 }, values[try definition.skeleton_definition.boneIndex(.pelvis)].translation);
    try expectVec(.{ .x = 1.3125, .y = 2.625 }, values[try definition.skeleton_definition.boneIndex(.torso)].scale);
}

test "loop advance and event traversal cover exact boundaries multiple wraps capacity and speed policy" {
    var definition = try makeDefinition();
    defer definition.deinit();
    const key = oneKeyTrack();
    const tracks = [_]clip.TrackInput{.{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.right_upper_arm), .rotation_keys = &key }};
    const event_inputs = [_]events.EventInput{
        .{ .id = 1, .timestamp = 0, .event_type = @intFromEnum(events.EventType.left_foot_contact) },
        .{ .id = 2, .timestamp = 0.25, .event_type = @intFromEnum(events.EventType.right_foot_contact) },
        .{ .id = 3, .timestamp = 0.5, .event_type = @intFromEnum(events.EventType.hand_contact) },
        .{ .id = 4, .timestamp = 0.5, .event_type = @intFromEnum(events.EventType.hand_release) },
        .{ .id = 5, .timestamp = 1, .event_type = @intFromEnum(events.EventType.interaction_complete) },
    };
    var definition_clip = try initClip(&definition.skeleton_definition, minimalInput(&tracks, &event_inputs));
    defer definition_clip.deinit();
    var event_storage: [128]events.EmittedEvent = undefined;
    var output = events.EventBuffer{ .storage = &event_storage };

    const exact = try clip.advanceTime(&definition_clip, 0, 1, 1);
    const exact_repeat = try clip.advanceTime(&definition_clip, 0, 1, 1);
    try std.testing.expectEqual(exact, exact_repeat);
    try std.testing.expectEqual(@as(u32, 1), exact.wraps);
    try std.testing.expectEqual(@as(f32, 0), exact.current_time);
    try clip.emitEvents(&definition_clip, exact, 0, false, &output);
    try std.testing.expectEqual(@as(usize, 5), output.count);
    try std.testing.expectEqual(events.EventType.right_foot_contact, output.items()[0].record.event_type);
    try std.testing.expectEqual(events.EventType.interaction_complete, output.items()[3].record.event_type);
    try std.testing.expectEqual(events.EventType.left_foot_contact, output.items()[4].record.event_type);

    output.reset();
    const two_wraps = try clip.advanceTime(&definition_clip, 0.1, 2, 1);
    try std.testing.expectEqual(@as(u32, 2), two_wraps.wraps);
    try clip.emitEvents(&definition_clip, two_wraps, 7, false, &output);
    try std.testing.expect(output.count > event_inputs.len);
    var previous_loop: u64 = 7;
    for (output.items()) |emitted| {
        try std.testing.expect(emitted.loop_index >= previous_loop);
        previous_loop = emitted.loop_index;
    }

    output.reset();
    const five_wraps = try clip.advanceTime(&definition_clip, 0, 5, 1);
    try std.testing.expectEqual(@as(u32, 5), five_wraps.wraps);
    try clip.emitEvents(&definition_clip, five_wraps, 0, false, &output);
    try std.testing.expect(output.count >= 20);
    _ = try clip.advanceTime(&definition_clip, 0, clip.maximum_event_wraps_per_update, 1);
    try std.testing.expectError(error.EventTraversalLimitExceeded, clip.advanceTime(&definition_clip, 0, clip.maximum_event_wraps_per_update + 1, 1));
    const paused = try clip.advanceTime(&definition_clip, 0.4, 10, 0);
    try std.testing.expect(!paused.moved);
    try std.testing.expectError(error.NegativePlaybackSpeedUnsupported, clip.advanceTime(&definition_clip, 0.4, 0.1, -1));

    var tiny_storage: [2]events.EmittedEvent = undefined;
    var tiny = events.EventBuffer{ .storage = &tiny_storage };
    try std.testing.expectError(error.EventOutputOverflow, clip.emitEvents(&definition_clip, exact, 0, true, &tiny));
    try std.testing.expectEqual(@as(usize, 2), tiny.count);

    output.reset();
    const exact_interval = try clip.advanceTime(&definition_clip, 0.25, 0.25, 1);
    try clip.emitEvents(&definition_clip, exact_interval, 0, false, &output);
    try std.testing.expectEqual(@as(usize, 2), output.count);
    try std.testing.expectEqual(@as(u16, 3), output.items()[0].record.id);
    try std.testing.expectEqual(@as(u16, 4), output.items()[1].record.id);
    var exact_storage: [2]events.EmittedEvent = undefined;
    var exact_capacity = events.EventBuffer{ .storage = &exact_storage };
    try clip.emitEvents(&definition_clip, exact_interval, 0, false, &exact_capacity);
    try std.testing.expectEqual(@as(usize, 2), exact_capacity.count);
    output.reset();
    const zero_delta = try clip.advanceTime(&definition_clip, 0.25, 0, 1);
    try clip.emitEvents(&definition_clip, zero_delta, 0, false, &output);
    try std.testing.expectEqual(@as(usize, 0), output.count);
    try clip.emitEvents(&definition_clip, zero_delta, 0, true, &output);
    try std.testing.expectEqual(@as(usize, 1), output.count);
}

test "one-shot sampling holds its final pose and final events fire once" {
    var definition = try makeDefinition();
    defer definition.deinit();
    const keys = [_]clip.TranslationKeyInput{
        .{ .timestamp = 0, .value = .{ .x = 0, .y = 0.9 }, .interpolation = linear },
        .{ .timestamp = 1, .value = .{ .x = 0, .y = 0.7 }, .interpolation = linear },
    };
    const tracks = [_]clip.TrackInput{.{ .target_semantic = @intFromEnum(skeleton.BoneSemantic.pelvis), .translation_keys = &keys }};
    const event_inputs = [_]events.EventInput{.{ .id = 1, .timestamp = 1, .event_type = @intFromEnum(events.EventType.interaction_complete) }};
    var input = minimalInput(&tracks, &event_inputs);
    input.playback_mode = @intFromEnum(clip.PlaybackMode.one_shot);
    var definition_clip = try initClip(&definition.skeleton_definition, input);
    defer definition_clip.deinit();
    const final = try clip.advanceTime(&definition_clip, 0.8, 0.5, 1);
    try std.testing.expect(final.completed_now);
    try std.testing.expectEqual(@as(f32, 1), final.current_time);
    var storage: [4]events.EmittedEvent = undefined;
    var output = events.EventBuffer{ .storage = &storage };
    try clip.emitEvents(&definition_clip, final, 0, false, &output);
    try std.testing.expectEqual(@as(usize, 1), output.count);
    const again = try clip.advanceTime(&definition_clip, 1, 1, 1);
    try std.testing.expect(!again.completed_now);
    try std.testing.expect(!again.moved);
}

test "component pose blending covers endpoints midpoint shortest angle validation and input immutability" {
    var definition = try makeDefinition();
    defer definition.deinit();
    const count = definition.skeleton_definition.boneCount();
    var left_storage: [skeleton.maximum_bones]math.Transform2D = undefined;
    var right_storage: [skeleton.maximum_bones]math.Transform2D = undefined;
    var output_storage: [skeleton.maximum_bones]math.Transform2D = undefined;
    const left = left_storage[0..count];
    const right = right_storage[0..count];
    const output = output_storage[0..count];
    fillRest(&definition.skeleton_definition, left);
    fillRest(&definition.skeleton_definition, right);
    const pelvis = try definition.skeleton_definition.boneIndex(.pelvis);
    left[pelvis] = math.Transform2D.init(.{ .x = 0, .y = 2 }, 350 * std.math.pi / 180.0, .{ .x = 1, .y = 2 });
    right[pelvis] = math.Transform2D.init(.{ .x = 10, .y = 6 }, 10 * std.math.pi / 180.0, .{ .x = 3, .y = 6 });
    const left_before = left_storage;
    const right_before = right_storage;
    const token = definition.skeleton_definition.compatibilityToken();

    try animator_module.blendLocalPoses(&definition.skeleton_definition, token, left, token, right, 0, token, output);
    try std.testing.expect(output[pelvis].approxEqAbs(left[pelvis], tolerance));
    try animator_module.blendLocalPoses(&definition.skeleton_definition, token, left, token, right, 1, token, output);
    try std.testing.expect(output[pelvis].approxEqAbs(right[pelvis], tolerance));
    try animator_module.blendLocalPoses(&definition.skeleton_definition, token, left, token, right, 0.5, token, output);
    try expectVec(.{ .x = 5, .y = 4 }, output[pelvis].translation);
    try expectVec(.{ .x = 2, .y = 4 }, output[pelvis].scale);
    try std.testing.expectApproxEqAbs(@as(f32, 0), output[pelvis].rotation_radians, tolerance);
    try std.testing.expectEqualSlices(math.Transform2D, left_before[0..count], left);
    try std.testing.expectEqualSlices(math.Transform2D, right_before[0..count], right);
    try std.testing.expectError(error.BlendWeightOutOfRange, animator_module.blendLocalPoses(&definition.skeleton_definition, token, left, token, right, -0.1, token, output));
    try std.testing.expectError(error.InvalidBlendWeight, animator_module.blendLocalPoses(&definition.skeleton_definition, token, left, token, right, std.math.nan(f32), token, output));
    try std.testing.expectError(error.BlendOutputAliasing, animator_module.blendLocalPoses(&definition.skeleton_definition, token, left, token, right, 0.5, token, left));
    try std.testing.expectError(error.PoseLengthMismatch, animator_module.blendLocalPoses(&definition.skeleton_definition, token, left[0 .. count - 1], token, right, 0.5, token, output));
    var other_definition = try makeDefinition();
    defer other_definition.deinit();
    try std.testing.expectError(error.PoseDefinitionMismatch, animator_module.blendLocalPoses(&definition.skeleton_definition, other_definition.skeleton_definition.compatibilityToken(), left, token, right, 0.5, token, output));
}

test "authored clips validate timelines meaningful poses and physics-root separation" {
    var definition = try makeDefinition();
    defer definition.deinit();
    var definitions = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer definitions.deinit();
    try std.testing.expectEqual(@as(usize, clip.clip_count), definitions.library.clips.len);
    try std.testing.expectEqual(@as(usize, state_machine.state_id_count), definitions.machine.states.len);
    try std.testing.expectEqual(@as(usize, 2), definitions.machine.transitions.len);

    const expected_durations = [_]f32{ 2, 1, 0.4, 0.6, 0.6, 0.5, 1.6, 1.6 };
    for (definitions.library.clips, expected_durations) |definition_clip, duration| {
        try std.testing.expectApproxEqAbs(duration, definition_clip.duration, tolerance);
        try definition_clip.validateCompatibility(&definition.skeleton_definition);
        try std.testing.expect(definition_clip.tracks.len > 0);
        for (definition_clip.tracks) |track| try std.testing.expect(track.target_semantic != .root);
    }

    const walk_clip = definitions.library.clips[@intFromEnum(clip.ClipId.walk)];
    try std.testing.expectEqual(events.EventType.left_foot_contact, walk_clip.event_records[0].event_type);
    try std.testing.expectEqual(events.EventType.right_foot_contact, walk_clip.event_records[1].event_type);
    try std.testing.expectApproxEqAbs(@as(f32, 0), walk_clip.event_records[0].timestamp, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), walk_clip.event_records[1].timestamp, tolerance);
    var walk_start: [skeleton.maximum_bones]math.Transform2D = undefined;
    var walk_end: [skeleton.maximum_bones]math.Transform2D = undefined;
    var idle_start: [skeleton.maximum_bones]math.Transform2D = undefined;
    var idle_end: [skeleton.maximum_bones]math.Transform2D = undefined;
    const authored_count = definition.skeleton_definition.boneCount();
    const authored_token = definition.skeleton_definition.compatibilityToken();
    try clip.sampleFromRest(&walk_clip, &definition.skeleton_definition, 0, authored_token, walk_start[0..authored_count]);
    try clip.sampleFromRest(&walk_clip, &definition.skeleton_definition, walk_clip.duration, authored_token, walk_end[0..authored_count]);
    try clip.sampleFromRest(&definitions.library.clips[@intFromEnum(clip.ClipId.idle)], &definition.skeleton_definition, 0, authored_token, idle_start[0..authored_count]);
    try clip.sampleFromRest(&definitions.library.clips[@intFromEnum(clip.ClipId.idle)], &definition.skeleton_definition, 2, authored_token, idle_end[0..authored_count]);
    for (walk_start[0..authored_count], walk_end[0..authored_count], idle_start[0..authored_count], idle_end[0..authored_count]) |walk_a, walk_b, idle_a, idle_b| {
        try std.testing.expect(walk_a.approxEqAbs(walk_b, tolerance));
        try std.testing.expect(idle_a.approxEqAbs(idle_b, tolerance));
    }

    const handshake_a = definitions.library.clips[@intFromEnum(clip.ClipId.handshake_role_a)];
    const handshake_b = definitions.library.clips[@intFromEnum(clip.ClipId.handshake_role_b)];
    try std.testing.expectEqual(handshake_a.duration, handshake_b.duration);
    try std.testing.expectEqual(handshake_a.event_records.len, handshake_b.event_records.len);
    for (handshake_a.event_records, handshake_b.event_records) |event_a, event_b| {
        try std.testing.expectEqual(event_a.timestamp, event_b.timestamp);
        try std.testing.expectEqual(event_a.event_type, event_b.event_type);
    }
    try std.testing.expect(handshake_a.event_records[0].event_type == .hand_contact);
    try std.testing.expect(handshake_a.event_records[2].event_type == .hand_release);
    try std.testing.expect(handshake_a.event_records[4].event_type == .interaction_complete);
    try std.testing.expect(handshake_a.event_records[0].timestamp < handshake_a.event_records[2].timestamp);
    try std.testing.expect(handshake_a.event_records[2].timestamp < handshake_a.event_records[4].timestamp);

    var rising: [skeleton.maximum_bones]math.Transform2D = undefined;
    var falling: [skeleton.maximum_bones]math.Transform2D = undefined;
    const count = definition.skeleton_definition.boneCount();
    const token = definition.skeleton_definition.compatibilityToken();
    try clip.sampleFromRest(&definitions.library.clips[@intFromEnum(clip.ClipId.rising)], &definition.skeleton_definition, 0.3, token, rising[0..count]);
    try clip.sampleFromRest(&definitions.library.clips[@intFromEnum(clip.ClipId.falling)], &definition.skeleton_definition, 0.3, token, falling[0..count]);
    const arm = try definition.skeleton_definition.boneIndex(.right_upper_arm);
    try std.testing.expect(@abs(rising[arm].rotation_radians - falling[arm].rotation_radians) > 0.5);
}

test "animator transitions events interruption policy one-shot fallback replay and independent players" {
    var definition = try makeDefinition();
    defer definition.deinit();
    var runtime_a = try animation_system.Runtime.init(std.testing.allocator, &definition, null);
    defer runtime_a.deinit();
    var runtime_b = try animation_system.Runtime.init(std.testing.allocator, &definition, null);
    defer runtime_b.deinit();
    var pose_a = try pose.Pose.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer pose_a.deinit();
    var pose_b = try pose.Pose.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer pose_b.deinit();

    const machine = &runtime_a.definitions.machine;
    const clips = runtime_a.definitions.library.clips;
    const token = runtime_a.definitions.library.token();
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0, &pose_a);
    try std.testing.expectEqual(state_machine.StateId.idle, runtime_a.animator.currentState(machine));
    try runtime_a.animator.requestState(machine, .walk);
    try std.testing.expectError(error.ActiveTransitionRequestRejected, runtime_a.animator.requestState(machine, .idle));
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0, &pose_a);
    try std.testing.expect(runtime_a.animator.emittedEvents().len == 1);
    try std.testing.expect(runtime_a.animator.emittedEvents()[0].record.event_type == .left_foot_contact);
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0.15, &pose_a);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), runtime_a.animator.transitionSnapshot(machine).?.weight, tolerance);
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0.15, &pose_a);
    try std.testing.expectEqual(state_machine.StateId.walk, runtime_a.animator.currentState(machine));
    try std.testing.expect(runtime_a.animator.transitionSnapshot(machine) == null);
    var exact_destination: [skeleton.maximum_bones]math.Transform2D = undefined;
    try clip.sampleFromRest(
        &clips[@intFromEnum(clip.ClipId.walk)],
        &definition.skeleton_definition,
        0.30,
        definition.skeleton_definition.compatibilityToken(),
        exact_destination[0..definition.skeleton_definition.boneCount()],
    );
    for (pose_a.local_transforms, exact_destination[0..definition.skeleton_definition.boneCount()]) |actual, expected| {
        try std.testing.expect(actual.approxEqAbs(expected, tolerance));
    }
    try runtime_a.animator.requestState(machine, .walk);
    try std.testing.expect(runtime_a.animator.transitionSnapshot(machine) == null);
    try runtime_a.animator.requestState(machine, .idle);
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0.15, &pose_a);
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0.15, &pose_a);
    try std.testing.expectEqual(state_machine.StateId.idle, runtime_a.animator.currentState(machine));

    try runtime_a.animator.enterState(machine, .jump_start);
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0.4, &pose_a);
    try std.testing.expectEqual(@as(u32, 1), runtime_a.animator.playback.completion_count);
    try std.testing.expectEqual(state_machine.StateId.jump_start, runtime_a.animator.currentState(machine));
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0, &pose_a);
    try std.testing.expect(runtime_a.animator.active_transition != null);
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0.12, &pose_a);
    try std.testing.expectEqual(state_machine.StateId.rising, runtime_a.animator.currentState(machine));
    try runtime_a.animator.enterState(machine, .jump_start);
    try std.testing.expectEqual(@as(u32, 0), runtime_a.animator.playback.completion_count);
    try runtime_a.animator.update(machine, clips, token, &definition.skeleton_definition, 0.4, &pose_a);
    try std.testing.expectEqual(@as(u32, 1), runtime_a.animator.playback.completion_count);

    const machine_b = &runtime_b.definitions.machine;
    const clips_b = runtime_b.definitions.library.clips;
    const token_b = runtime_b.definitions.library.token();
    try runtime_b.animator.update(machine_b, clips_b, token_b, &definition.skeleton_definition, 0.8, &pose_b);
    try std.testing.expectEqual(state_machine.StateId.idle, runtime_b.animator.currentState(machine_b));
    try std.testing.expectEqual(state_machine.StateId.jump_start, runtime_a.animator.currentState(machine));
    try runtime_b.animator.requestState(machine_b, .walk);
    try runtime_b.animator.update(machine_b, clips_b, token_b, &definition.skeleton_definition, 0, &pose_b);
    try std.testing.expectEqual(@as(usize, 1), runtime_b.animator.emittedEvents().len);
    try std.testing.expectEqual(events.EventType.left_foot_contact, runtime_b.animator.emittedEvents()[0].record.event_type);
}

test "zero-duration transition enters destination immediately and resets its playback" {
    var definition = try makeDefinition();
    defer definition.deinit();
    var library = try authored.Library.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer library.deinit();
    const states = authored.authoredStates();
    var transitions = authored.authoredTransitions();
    transitions[0].blend_duration = 0;
    var machine = try state_machine.Definition.init(
        std.testing.allocator,
        library.clips,
        library.token(),
        &states,
        &transitions,
        @intFromEnum(state_machine.StateId.idle),
        null,
    );
    defer machine.deinit();
    var player = try animator_module.Animator.init(std.testing.allocator, &definition.skeleton_definition, &machine, library.token(), 8, null);
    defer player.deinit();
    try player.requestState(&machine, .walk);
    try std.testing.expectEqual(state_machine.StateId.walk, player.currentState(&machine));
    try std.testing.expectEqual(@as(f32, 0), player.currentClipTime());
    try std.testing.expect(player.active_transition == null);
}

test "animator event overflow preserves partial output and leaves playback uncommitted" {
    var definition = try makeDefinition();
    defer definition.deinit();
    var definitions = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer definitions.deinit();
    var player = try animator_module.Animator.init(
        std.testing.allocator,
        &definition.skeleton_definition,
        &definitions.machine,
        definitions.library.token(),
        1,
        null,
    );
    defer player.deinit();
    var output_pose = try pose.Pose.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer output_pose.deinit();
    try player.enterState(&definitions.machine, .handshake_role_a);
    try std.testing.expectError(error.EventOutputOverflow, player.update(
        &definitions.machine,
        definitions.library.clips,
        definitions.library.token(),
        &definition.skeleton_definition,
        0.60,
        &output_pose,
    ));
    try std.testing.expectEqual(@as(f32, 0), player.playback.current_time);
    try std.testing.expect(player.playback.state_entered);
    try std.testing.expectEqual(@as(usize, 1), player.emittedEvents().len);
    try std.testing.expectEqual(events.EventType.hand_contact, player.emittedEvents()[0].record.event_type);
}

test "state-machine validation rejects missing initial duplicate state missing clip fallback and invalid transition" {
    var definition = try makeDefinition();
    defer definition.deinit();
    var library = try authored.Library.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer library.deinit();
    var states = authored.authoredStates();
    const transitions = authored.authoredTransitions();

    try std.testing.expectError(error.MissingInitialState, state_machine.Definition.init(std.testing.allocator, library.clips, library.token(), states[1..], &transitions, @intFromEnum(state_machine.StateId.idle), null));
    states[1].state_id = states[0].state_id;
    try std.testing.expectError(error.DuplicateStateIdentifier, state_machine.Definition.init(std.testing.allocator, library.clips, library.token(), &states, &transitions, @intFromEnum(state_machine.StateId.idle), null));
    states = authored.authoredStates();
    states[0].clip_id = 255;
    try std.testing.expectError(error.MissingClip, state_machine.Definition.init(std.testing.allocator, library.clips, library.token(), &states, &transitions, @intFromEnum(state_machine.StateId.idle), null));
    states = authored.authoredStates();
    states[2].fallback_state = 255;
    try std.testing.expectError(error.InvalidFallbackState, state_machine.Definition.init(std.testing.allocator, library.clips, library.token(), &states, &transitions, @intFromEnum(state_machine.StateId.idle), null));
    states = authored.authoredStates();
    var invalid_transition = transitions;
    invalid_transition[0].destination_state = 255;
    try std.testing.expectError(error.InvalidTransitionState, state_machine.Definition.init(std.testing.allocator, library.clips, library.token(), &states, &invalid_transition, @intFromEnum(state_machine.StateId.idle), null));
}

test "animation initialization fault stages clean transactionally and steady updates allocate zero" {
    var definition = try makeDefinition();
    defer definition.deinit();
    for (fault_injection.animation_initialization_stages) |stage| {
        var attempt = animation_system.Runtime.init(std.testing.allocator, &definition, .{ .fail_after = stage }) catch |err| {
            try std.testing.expectEqual(error.InjectedInitializationFailure, err);
            var clean = try animation_system.Runtime.init(std.testing.allocator, &definition, null);
            clean.deinit();
            continue;
        };
        attempt.deinit();
        return error.FaultInjectionDidNotTrigger;
    }

    var storage: [512 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var fixed_definition = try humanoid.HumanoidDefinition.init(fixed.allocator(), null);
    defer fixed_definition.deinit();
    var runtime = try animation_system.Runtime.init(fixed.allocator(), &fixed_definition, null);
    defer runtime.deinit();
    var output_pose = try pose.Pose.init(fixed.allocator(), &fixed_definition.skeleton_definition, null);
    defer output_pose.deinit();
    const initialized = fixed.end_index;
    for (0..360) |frame| {
        if (frame == 90) try runtime.animator.requestState(&runtime.definitions.machine, .walk);
        if (frame == 300) try runtime.animator.requestState(&runtime.definitions.machine, .idle);
        try runtime.animator.update(
            &runtime.definitions.machine,
            runtime.definitions.library.clips,
            runtime.definitions.library.token(),
            &fixed_definition.skeleton_definition,
            1.0 / 60.0,
            &output_pose,
        );
        try output_pose.evaluateWorld(&fixed_definition.skeleton_definition, math.Transform2D.identity());
    }
    try std.testing.expectEqual(initialized, fixed.end_index);
    try std.testing.expectEqual(@as(u64, 0), runtime.animator.metrics.clip_sampling_allocations);
    try std.testing.expectEqual(@as(u64, 0), runtime.animator.metrics.pose_blending_allocations);
    try std.testing.expectEqual(@as(u64, 0), runtime.animator.metrics.event_traversal_allocations);
    try std.testing.expectEqual(@as(u64, 0), runtime.animator.metrics.animator_update_allocations);
}
