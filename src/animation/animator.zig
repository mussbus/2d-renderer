const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const pose = @import("pose");
const clip = @import("clip");
const events = @import("events");
const state_machine = @import("state_machine");
const fault_injection = @import("fault_injection");

pub const PlaybackState = struct {
    previous_time: f32 = 0,
    current_time: f32 = 0,
    playback_speed: f32,
    loop_count: u64 = 0,
    completed: bool = false,
    completion_count: u32 = 0,
    state_entered: bool = true,
    fallback_pending: bool = false,
};

pub const TransitionState = struct {
    source_state_index: u16,
    destination_state_index: u16,
    elapsed: f32,
    duration: f32,
    source_advances: bool,
    destination_begins_immediately: bool,
    source_playback: PlaybackState,
    destination_playback: PlaybackState,
};

pub const TransitionSnapshot = struct {
    source: state_machine.StateId,
    destination: state_machine.StateId,
    weight: f32,
};

pub const HotPathMetrics = struct {
    clip_sampling_allocations: u64 = 0,
    pose_blending_allocations: u64 = 0,
    event_traversal_allocations: u64 = 0,
    animator_update_allocations: u64 = 0,
    state_transition_allocations: u64 = 0,
};

pub const Animator = struct {
    allocator: std.mem.Allocator,
    definition_token: usize,
    library_token: usize,
    source_pose: []math.Transform2D,
    destination_pose: []math.Transform2D,
    event_storage: []events.EmittedEvent,
    event_buffer: events.EventBuffer,
    current_state_index: u16,
    playback: PlaybackState,
    active_transition: ?TransitionState = null,
    metrics: HotPathMetrics = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        definition: *const skeleton.SkeletonDefinition,
        machine: *const state_machine.Definition,
        library_token: usize,
        event_capacity: usize,
        injector: ?fault_injection.Injector,
    ) !Animator {
        if (machine.clip_library_token != library_token) return error.AnimationLibraryMismatch;
        if (event_capacity == 0) return error.InvalidEventCapacity;
        const source_pose = allocator.alloc(math.Transform2D, definition.boneCount()) catch return error.AllocationFailure;
        errdefer allocator.free(source_pose);
        try after(injector, .animator_pose_buffer_allocation);
        const destination_pose = allocator.alloc(math.Transform2D, definition.boneCount()) catch return error.AllocationFailure;
        errdefer allocator.free(destination_pose);
        const event_storage = allocator.alloc(events.EmittedEvent, event_capacity) catch return error.AllocationFailure;
        errdefer allocator.free(event_storage);
        try after(injector, .animator_event_buffer_allocation);

        const initial_state = machine.states[machine.initial_state_index];
        return .{
            .allocator = allocator,
            .definition_token = definition.compatibilityToken(),
            .library_token = library_token,
            .source_pose = source_pose,
            .destination_pose = destination_pose,
            .event_storage = event_storage,
            .event_buffer = .{ .storage = event_storage },
            .current_state_index = machine.initial_state_index,
            .playback = newPlayback(initial_state.playback_speed),
        };
    }

    pub fn deinit(animator: *Animator) void {
        animator.allocator.free(animator.event_storage);
        animator.allocator.free(animator.destination_pose);
        animator.allocator.free(animator.source_pose);
        animator.* = undefined;
    }

    pub fn emittedEvents(animator: *const Animator) []const events.EmittedEvent {
        return animator.event_buffer.items();
    }

    pub fn currentState(animator: Animator, machine: *const state_machine.Definition) state_machine.StateId {
        return machine.states[animator.current_state_index].id;
    }

    pub fn currentClipTime(animator: Animator) f32 {
        if (animator.active_transition) |transition| return transition.destination_playback.current_time;
        return animator.playback.current_time;
    }

    pub fn transitionSnapshot(animator: Animator, machine: *const state_machine.Definition) ?TransitionSnapshot {
        const transition = animator.active_transition orelse return null;
        return .{
            .source = machine.states[transition.source_state_index].id,
            .destination = machine.states[transition.destination_state_index].id,
            .weight = if (transition.duration == 0) 1 else @min(1, transition.elapsed / transition.duration),
        };
    }

    pub fn enterState(animator: *Animator, machine: *const state_machine.Definition, destination: state_machine.StateId) !void {
        const destination_index = try machine.stateIndex(destination);
        const state = machine.states[destination_index];
        animator.current_state_index = destination_index;
        animator.playback = newPlayback(state.playback_speed);
        animator.active_transition = null;
    }

    pub fn sampleEnteredStateAtTime(
        animator: *Animator,
        machine: *const state_machine.Definition,
        clips: []const clip.ClipDefinition,
        library_token: usize,
        definition: *const skeleton.SkeletonDefinition,
        required_state: state_machine.StateId,
        shared_time_seconds: f32,
        output_pose: *pose.Pose,
    ) !void {
        try animator.validateRuntime(machine, clips, library_token, definition, output_pose);
        if (!std.math.isFinite(shared_time_seconds) or shared_time_seconds < 0) return error.InvalidAnimationTime;
        const required_index = try machine.stateIndex(required_state);
        if (animator.current_state_index != required_index or animator.active_transition != null) {
            return error.InteractionAnimationStateMismatch;
        }
        const animation_state = machine.states[required_index];
        const current_clip = &clips[animation_state.clip_index];
        if (shared_time_seconds > current_clip.duration) return error.InteractionTimeBeyondClip;

        animator.event_buffer.reset();
        try clip.sampleFromRest(
            current_clip,
            definition,
            shared_time_seconds,
            output_pose.definition_token,
            output_pose.local_transforms,
        );
        output_pose.evaluated = false;
        animator.playback.previous_time = animator.playback.current_time;
        animator.playback.current_time = shared_time_seconds;
        animator.playback.state_entered = false;
        animator.playback.completed = shared_time_seconds == current_clip.duration;
        animator.playback.fallback_pending = false;
    }

    pub fn requestState(animator: *Animator, machine: *const state_machine.Definition, destination: state_machine.StateId) !void {
        if (animator.active_transition != null) return error.ActiveTransitionRequestRejected;
        const destination_index = try machine.stateIndex(destination);
        if (destination_index == animator.current_state_index) return;
        const transition = machine.transition(animator.current_state_index, destination_index) orelse return error.MissingTransition;
        try animator.beginTransition(machine, destination_index, transition.blend_duration, transition.source_advances, transition.destination_begins_immediately);
    }

    pub fn update(
        animator: *Animator,
        machine: *const state_machine.Definition,
        clips: []const clip.ClipDefinition,
        library_token: usize,
        definition: *const skeleton.SkeletonDefinition,
        delta_seconds: f32,
        output_pose: *pose.Pose,
    ) !void {
        try animator.validateRuntime(machine, clips, library_token, definition, output_pose);
        if (!std.math.isFinite(delta_seconds) or delta_seconds < 0) return error.InvalidAnimationDelta;
        animator.event_buffer.reset();

        if (animator.active_transition == null and animator.playback.fallback_pending) {
            const current_state = machine.states[animator.current_state_index];
            const fallback = current_state.fallback_state_index orelse return error.InvalidFallbackState;
            try animator.beginTransition(machine, fallback, current_state.fallback_blend_duration, false, true);
        }

        if (animator.active_transition) |transition_value| {
            var transition = transition_value;
            const source_state = machine.states[transition.source_state_index];
            const destination_state = machine.states[transition.destination_state_index];
            const source_clip = &clips[source_state.clip_index];
            const destination_clip = &clips[destination_state.clip_index];
            const source_delta = if (transition.source_advances) delta_seconds else 0;
            const destination_delta = if (transition.destination_begins_immediately) delta_seconds else 0;
            const source_advance = try clip.advanceTime(source_clip, transition.source_playback.current_time, source_delta, transition.source_playback.playback_speed);
            const destination_advance = try clip.advanceTime(destination_clip, transition.destination_playback.current_time, destination_delta, transition.destination_playback.playback_speed);

            try clip.emitEvents(source_clip, source_advance, transition.source_playback.loop_count, transition.source_playback.state_entered, &animator.event_buffer);
            try clip.emitEvents(destination_clip, destination_advance, transition.destination_playback.loop_count, transition.destination_playback.state_entered, &animator.event_buffer);
            try clip.sampleFromRest(source_clip, definition, source_advance.current_time, animator.definition_token, animator.source_pose);
            try clip.sampleFromRest(destination_clip, definition, destination_advance.current_time, animator.definition_token, animator.destination_pose);

            const next_elapsed = @min(transition.duration, transition.elapsed + delta_seconds);
            const weight: f32 = if (transition.duration == 0) 1 else next_elapsed / transition.duration;
            try blendLocalPoses(
                definition,
                animator.definition_token,
                animator.source_pose,
                animator.definition_token,
                animator.destination_pose,
                weight,
                output_pose.definition_token,
                output_pose.local_transforms,
            );
            output_pose.evaluated = false;

            commitPlayback(&transition.source_playback, source_advance);
            commitPlayback(&transition.destination_playback, destination_advance);
            transition.elapsed = next_elapsed;
            if (weight == 1) {
                animator.current_state_index = transition.destination_state_index;
                animator.playback = transition.destination_playback;
                animator.active_transition = null;
            } else {
                animator.active_transition = transition;
            }
            return;
        }

        const current_state = machine.states[animator.current_state_index];
        const current_clip = &clips[current_state.clip_index];
        const advance = try clip.advanceTime(current_clip, animator.playback.current_time, delta_seconds, animator.playback.playback_speed);
        try clip.emitEvents(current_clip, advance, animator.playback.loop_count, animator.playback.state_entered, &animator.event_buffer);
        try clip.sampleFromRest(current_clip, definition, advance.current_time, output_pose.definition_token, output_pose.local_transforms);
        output_pose.evaluated = false;
        commitPlayback(&animator.playback, advance);
    }

    fn beginTransition(
        animator: *Animator,
        machine: *const state_machine.Definition,
        destination_index: u16,
        duration: f32,
        source_advances: bool,
        destination_begins_immediately: bool,
    ) !void {
        if (!std.math.isFinite(duration) or duration < 0) return error.InvalidTransitionDuration;
        const destination = try machine.state(destination_index);
        if (duration == 0) {
            animator.current_state_index = destination_index;
            animator.playback = newPlayback(destination.playback_speed);
            animator.active_transition = null;
            return;
        }
        animator.active_transition = .{
            .source_state_index = animator.current_state_index,
            .destination_state_index = destination_index,
            .elapsed = 0,
            .duration = duration,
            .source_advances = source_advances,
            .destination_begins_immediately = destination_begins_immediately,
            .source_playback = animator.playback,
            .destination_playback = newPlayback(destination.playback_speed),
        };
    }

    fn validateRuntime(
        animator: Animator,
        machine: *const state_machine.Definition,
        clips: []const clip.ClipDefinition,
        library_token: usize,
        definition: *const skeleton.SkeletonDefinition,
        output_pose: *pose.Pose,
    ) !void {
        if (animator.library_token != library_token or machine.clip_library_token != library_token) return error.AnimationLibraryMismatch;
        if (animator.definition_token != definition.compatibilityToken()) return error.PoseDefinitionMismatch;
        try output_pose.validateCompatibility(definition);
        for (machine.states) |state| {
            if (state.clip_index >= clips.len) return error.MissingClip;
            try clips[state.clip_index].validateCompatibility(definition);
        }
    }
};

pub fn blendLocalPoses(
    definition: *const skeleton.SkeletonDefinition,
    token_a: usize,
    pose_a: []const math.Transform2D,
    token_b: usize,
    pose_b: []const math.Transform2D,
    weight: f32,
    output_token: usize,
    output: []math.Transform2D,
) !void {
    if (!std.math.isFinite(weight)) return error.InvalidBlendWeight;
    if (weight < 0 or weight > 1) return error.BlendWeightOutOfRange;
    const expected = definition.compatibilityToken();
    if (token_a != expected or token_b != expected or output_token != expected) return error.PoseDefinitionMismatch;
    if (pose_a.len != definition.boneCount() or pose_b.len != definition.boneCount() or output.len != definition.boneCount()) return error.PoseLengthMismatch;
    if (slicesOverlap(pose_a, output) or slicesOverlap(pose_b, output)) return error.BlendOutputAliasing;
    for (pose_a) |value| try value.validate();
    for (pose_b) |value| try value.validate();

    for (pose_a, pose_b, output) |left, right, *result| {
        result.* = .{
            .translation = try math.interpolation.lerpVec2(left.translation, right.translation, weight),
            .rotation_radians = try math.interpolation.lerpAngleShortest(left.rotation_radians, right.rotation_radians, weight),
            .scale = try math.interpolation.lerpVec2(left.scale, right.scale, weight),
        };
    }
}

fn newPlayback(speed: f32) PlaybackState {
    return .{ .playback_speed = speed };
}

fn commitPlayback(playback: *PlaybackState, advance: clip.TimeAdvance) void {
    playback.previous_time = advance.previous_time;
    playback.current_time = advance.current_time;
    playback.loop_count += advance.wraps;
    playback.state_entered = false;
    if (advance.completed_now and !playback.completed) {
        playback.completed = true;
        playback.completion_count += 1;
        playback.fallback_pending = true;
    }
}

fn slicesOverlap(source: []const math.Transform2D, output: []math.Transform2D) bool {
    if (source.len == 0 or output.len == 0) return false;
    const source_start = @intFromPtr(source.ptr);
    const source_end = source_start + source.len * @sizeOf(math.Transform2D);
    const output_start = @intFromPtr(output.ptr);
    const output_end = output_start + output.len * @sizeOf(math.Transform2D);
    return source_start < output_end and output_start < source_end;
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
