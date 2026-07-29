const std = @import("std");
const visual = @import("visual_geometry");

pub const capture_count: usize = 8;
pub const minimum_stable_frames: u16 = 4;

pub const Stage = enum(u8) {
    neutral_front,
    neutral_side_right,
    neutral_side_left,
    build_low_front,
    build_high_front,
    arm_extended_side,
    elbow_bent_side,
    deep_knee_bend_side,
};

pub const CaptureSpec = struct {
    stage: Stage,
    filename: []const u8,
    required_view: visual.View,
    required_facing: visual.Side = .none,
    required_animation: []const u8,
    minimum_elbow_angle_degrees: ?f32 = null,
    maximum_elbow_angle_degrees: ?f32 = null,
    minimum_knee_angle_degrees: ?f32 = null,
    required_build: f32,
    timeout_frames: u16,
};

pub const specs = [_]CaptureSpec{
    .{ .stage = .neutral_front, .filename = "01_neutral_front.ppm", .required_view = .front, .required_animation = "idle", .required_build = 50, .timeout_frames = 48 },
    .{ .stage = .neutral_side_right, .filename = "02_neutral_side_right.ppm", .required_view = .side_right, .required_facing = .right, .required_animation = "idle", .required_build = 50, .timeout_frames = 48 },
    .{ .stage = .neutral_side_left, .filename = "03_neutral_side_left.ppm", .required_view = .side_left, .required_facing = .left, .required_animation = "idle", .required_build = 50, .timeout_frames = 48 },
    .{ .stage = .build_low_front, .filename = "04_build_low_front.ppm", .required_view = .front, .required_animation = "idle", .required_build = 15, .timeout_frames = 48 },
    .{ .stage = .build_high_front, .filename = "05_build_high_front.ppm", .required_view = .front, .required_animation = "idle", .required_build = 85, .timeout_frames = 48 },
    .{ .stage = .arm_extended_side, .filename = "06_arm_extended_side.ppm", .required_view = .side_right, .required_facing = .right, .required_animation = "walk", .maximum_elbow_angle_degrees = 18, .required_build = 50, .timeout_frames = 160 },
    .{ .stage = .elbow_bent_side, .filename = "07_elbow_bent_side.ppm", .required_view = .side_right, .required_facing = .right, .required_animation = "handshake_role_b", .minimum_elbow_angle_degrees = 20, .required_build = 50, .timeout_frames = 160 },
    .{ .stage = .deep_knee_bend_side, .filename = "08_deep_knee_bend_side.ppm", .required_view = .side_right, .required_facing = .right, .required_animation = "jump_start", .minimum_knee_angle_degrees = 24, .required_build = 50, .timeout_frames = 96 },
};

pub const Observation = struct {
    render_frame: u32,
    simulation_tick: u64,
    stage: Stage,
    stage_frame: u16,
    view: visual.View,
    facing: visual.Side,
    animation: []const u8,
    global_build: f32,
    elbow_angle_degrees: f32,
    knee_angle_degrees: f32,
    anatomy_trace_records: u16,
};

pub const Candidate = struct {
    spec_index: usize,
    stable_frames: u16,
};

pub const CapturedState = struct {
    captured: bool = false,
    stable_frames: u16 = 0,
    observation: Observation = undefined,
};

pub const Tracker = struct {
    states: [capture_count]CapturedState = [_]CapturedState{.{}} ** capture_count,
    next_index: usize = 0,
    consecutive_matches: u16 = 0,
    frames_in_spec: u16 = 0,

    pub fn observe(tracker: *Tracker, observation: Observation) !?Candidate {
        if (tracker.next_index == specs.len) return null;
        const spec = specs[tracker.next_index];
        const observed_stage = @intFromEnum(observation.stage);
        const required_stage = @intFromEnum(spec.stage);
        if (observed_stage < required_stage) return null;
        if (observed_stage > required_stage) {
            return error.AnatomyEvidenceRequiredStageMissed;
        }
        tracker.frames_in_spec = std.math.add(u16, tracker.frames_in_spec, 1) catch
            return error.AnatomyEvidenceFrameOverflow;
        if (tracker.frames_in_spec > spec.timeout_frames) {
            std.log.err(
                "Prompt 27C capture timeout: id={s} stage={s} actual_stage={s} view={s} facing={s} animation={s} build={d:.2} elbow={d:.3} knee={d:.3} trace_records={d}",
                .{
                    @tagName(spec.stage),
                    @tagName(spec.stage),
                    @tagName(observation.stage),
                    @tagName(observation.view),
                    @tagName(observation.facing),
                    observation.animation,
                    observation.global_build,
                    observation.elbow_angle_degrees,
                    observation.knee_angle_degrees,
                    observation.anatomy_trace_records,
                },
            );
            return error.AnatomyEvidenceCaptureTimeout;
        }
        if (!matches(spec, observation)) {
            tracker.consecutive_matches = 0;
            return null;
        }
        tracker.consecutive_matches = std.math.add(
            u16,
            tracker.consecutive_matches,
            1,
        ) catch return error.AnatomyEvidenceStableFrameOverflow;
        if (tracker.consecutive_matches < minimum_stable_frames) return null;
        return .{
            .spec_index = tracker.next_index,
            .stable_frames = tracker.consecutive_matches,
        };
    }

    pub fn commit(
        tracker: *Tracker,
        candidate: Candidate,
        observation: Observation,
    ) !void {
        if (candidate.spec_index != tracker.next_index or
            candidate.spec_index >= tracker.states.len or
            tracker.states[candidate.spec_index].captured)
        {
            return error.InvalidAnatomyEvidenceCommit;
        }
        tracker.states[candidate.spec_index] = .{
            .captured = true,
            .stable_frames = candidate.stable_frames,
            .observation = observation,
        };
        tracker.next_index += 1;
        tracker.consecutive_matches = 0;
        tracker.frames_in_spec = 0;
    }

    pub fn validateComplete(tracker: Tracker) !void {
        if (tracker.next_index != specs.len) return error.AnatomyEvidenceIncomplete;
        for (tracker.states) |state| {
            if (!state.captured or state.stable_frames < minimum_stable_frames) {
                return error.AnatomyEvidenceIncomplete;
            }
        }
    }
};

fn matches(spec: CaptureSpec, observation: Observation) bool {
    if (observation.stage != spec.stage or
        observation.view != spec.required_view or
        observation.anatomy_trace_records < 15 or
        !std.mem.eql(u8, observation.animation, spec.required_animation) or
        @abs(observation.global_build - spec.required_build) > 0.001)
    {
        return false;
    }
    if (spec.required_facing != .none and
        observation.facing != spec.required_facing)
    {
        return false;
    }
    if (spec.minimum_elbow_angle_degrees) |minimum| {
        if (!std.math.isFinite(observation.elbow_angle_degrees) or
            observation.elbow_angle_degrees < minimum)
        {
            return false;
        }
    }
    if (spec.maximum_elbow_angle_degrees) |maximum| {
        if (!std.math.isFinite(observation.elbow_angle_degrees) or
            observation.elbow_angle_degrees > maximum)
        {
            return false;
        }
    }
    if (spec.minimum_knee_angle_degrees) |minimum| {
        if (!std.math.isFinite(observation.knee_angle_degrees) or
            observation.knee_angle_degrees < minimum)
        {
            return false;
        }
    }
    return true;
}

test "Prompt 27C tracker rejects filenames without matching authoritative state" {
    var tracker = Tracker{};
    const nominal = Observation{
        .render_frame = 1,
        .simulation_tick = 4,
        .stage = .neutral_front,
        .stage_frame = 1,
        .view = .front,
        .facing = .right,
        .animation = "idle",
        .global_build = 50,
        .elbow_angle_degrees = 2,
        .knee_angle_degrees = 3,
        .anatomy_trace_records = 30,
    };
    var wrong = nominal;
    wrong.view = .side_right;
    try std.testing.expect((try tracker.observe(wrong)) == null);
    try std.testing.expectEqual(@as(u16, 0), tracker.consecutive_matches);
    for (0..minimum_stable_frames - 1) |_| {
        try std.testing.expect((try tracker.observe(nominal)) == null);
    }
    const candidate = (try tracker.observe(nominal)).?;
    try tracker.commit(candidate, nominal);
    try std.testing.expect(tracker.states[0].captured);
}

test "Prompt 27C bent-elbow capture boundary rejects a minimally invalid pose" {
    const spec = specs[@intFromEnum(Stage.elbow_bent_side)];
    var observation = Observation{
        .render_frame = 360,
        .simulation_tick = 1444,
        .stage = .elbow_bent_side,
        .stage_frame = 4,
        .view = .side_right,
        .facing = .right,
        .animation = "handshake_role_b",
        .global_build = 50,
        .elbow_angle_degrees = 19.999,
        .knee_angle_degrees = 0,
        .anatomy_trace_records = 15,
    };
    try std.testing.expect(!matches(spec, observation));
    observation.elbow_angle_degrees = 20;
    try std.testing.expect(matches(spec, observation));
}
