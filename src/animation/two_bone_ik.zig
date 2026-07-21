const std = @import("std");
const math = @import("math");

pub const reach_epsilon: f32 = 0.00001;
pub const direction_epsilon: f32 = 0.000001;
pub const minimum_segment_length: f32 = reach_epsilon;

pub const Bend = enum(i8) {
    negative = -1,
    positive = 1,

    pub fn scalar(value: Bend) f32 {
        return @floatFromInt(@intFromEnum(value));
    }

    pub fn opposite(value: Bend) Bend {
        return if (value == .positive) .negative else .positive;
    }
};

pub const Reachability = enum(u8) {
    reachable,
    clamped_near,
    clamped_far,
};

pub const Input = struct {
    root: math.Vec2,
    upper_length: f32,
    lower_length: f32,
    target: math.Vec2,
    bend: Bend,
    reference_direction: math.Vec2 = .{ .x = 1, .y = 0 },
};

pub const Result = struct {
    root_rotation_radians: f32,
    middle_rotation_radians: f32,
    middle_position: math.Vec2,
    end_position: math.Vec2,
    effective_target: math.Vec2,
    requested_distance: f32,
    solved_distance: f32,
    minimum_reach: f32,
    maximum_reach: f32,
    reachability: Reachability,
};

/// Solves in an arbitrary right-handed 2D Cartesian plane. +X is right, +Y is
/// up, radians are counterclockwise-positive, and all positions and lengths use
/// the caller's physical units. Camera, pixel, sprite, entity, and animation
/// state are intentionally absent.
pub fn solve(input: Input) !Result {
    try validate(input);

    const raw_delta = input.target.sub(input.root);
    const requested_distance = raw_delta.length();
    const minimum_reach = @abs(input.upper_length - input.lower_length);
    const maximum_reach = input.upper_length + input.lower_length;
    const safe_minimum = minimum_reach + reach_epsilon;
    const safe_maximum = maximum_reach - reach_epsilon;
    if (!(safe_minimum <= safe_maximum)) return error.SegmentLengthsTooSmallForReachEpsilon;

    const direction = if (requested_distance >= direction_epsilon)
        raw_delta.scale(1.0 / requested_distance)
    else
        try input.reference_direction.normalizeSafe(direction_epsilon);
    if (direction.approxEqAbs(math.Vec2.zero, 0)) return error.InvalidReferenceDirection;

    const reachability: Reachability = if (requested_distance < safe_minimum)
        .clamped_near
    else if (requested_distance > safe_maximum)
        .clamped_far
    else
        .reachable;
    const solved_distance = @min(safe_maximum, @max(safe_minimum, requested_distance));
    const effective_target = input.root.add(direction.scale(solved_distance));

    const upper_squared = input.upper_length * input.upper_length;
    const lower_squared = input.lower_length * input.lower_length;
    const distance_squared = solved_distance * solved_distance;
    const root_cosine = clampUnit(
        (upper_squared + distance_squared - lower_squared) /
            (2.0 * input.upper_length * solved_distance),
    );
    const middle_cosine = clampUnit(
        (upper_squared + lower_squared - distance_squared) /
            (2.0 * input.upper_length * input.lower_length),
    );
    const target_rotation = std.math.atan2(direction.y, direction.x);
    const root_offset = std.math.acos(root_cosine) * input.bend.scalar();
    const internal_middle_angle = std.math.acos(middle_cosine);
    const middle_rotation = -input.bend.scalar() * (std.math.pi - internal_middle_angle);
    const root_rotation = target_rotation + root_offset;
    const middle_position = input.root.add(math.Vec2.init(@cos(root_rotation), @sin(root_rotation)).scale(input.upper_length));
    const lower_rotation = root_rotation + middle_rotation;
    const end_position = middle_position.add(math.Vec2.init(@cos(lower_rotation), @sin(lower_rotation)).scale(input.lower_length));

    const result = Result{
        .root_rotation_radians = try math.interpolation.wrapAngle(root_rotation),
        .middle_rotation_radians = try math.interpolation.wrapAngle(middle_rotation),
        .middle_position = middle_position,
        .end_position = end_position,
        .effective_target = effective_target,
        .requested_distance = requested_distance,
        .solved_distance = solved_distance,
        .minimum_reach = minimum_reach,
        .maximum_reach = maximum_reach,
        .reachability = reachability,
    };
    if (!result.middle_position.isFinite() or !result.end_position.isFinite() or
        !std.math.isFinite(result.root_rotation_radians) or !std.math.isFinite(result.middle_rotation_radians))
    {
        return error.NonFiniteSolveResult;
    }
    return result;
}

fn validate(input: Input) !void {
    if (!input.root.isFinite() or !input.target.isFinite() or !input.reference_direction.isFinite()) {
        return error.NonFiniteIkInput;
    }
    if (!std.math.isFinite(input.upper_length) or !std.math.isFinite(input.lower_length)) {
        return error.NonFiniteIkInput;
    }
    if (input.upper_length < minimum_segment_length or input.lower_length < minimum_segment_length) {
        return error.InvalidSegmentLength;
    }
    if (input.reference_direction.lengthSquared() < direction_epsilon * direction_epsilon) {
        return error.InvalidReferenceDirection;
    }
}

fn clampUnit(value: f32) f32 {
    return @min(1.0, @max(-1.0, value));
}
