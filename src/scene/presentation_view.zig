const std = @import("std");

pub const View = enum(u8) {
    side,
    front,
};

pub fn spriteMorphologyScale(source: anytype, rest_rotation: f32) @TypeOf(source) {
    const quarter_turn =
        @abs(@abs(rest_rotation) - std.math.pi / 2.0) <= 0.0001;
    if (!quarter_turn) return source;

    // Morphology is authored in bone-local axes. A quarter-turn source maps
    // bone-local Y thickness to sprite-local X and bone-local X length to
    // sprite-local Y. Preserve the determinant sign on X so a reflected
    // presentation remains a horizontal mirror rather than a vertical flip.
    const determinant_sign: f32 = if (source.x * source.y < 0) -1 else 1;
    return @TypeOf(source){
        .x = determinant_sign * @abs(source.y),
        .y = @abs(source.x),
    };
}

pub const DebugOverride = enum(u8) {
    automatic,
    force_side,
    force_front,

    pub fn next(value: DebugOverride) DebugOverride {
        return switch (value) {
            .automatic => .force_side,
            .force_side => .force_front,
            .force_front => .automatic,
        };
    }
};

pub const Activity = enum(u8) {
    idle,
    walking,
    dashing,
    jumping,
    rising,
    falling,
    landing,
};

pub const AutomaticInput = struct {
    grounded: bool,
    activity: Activity,
};

pub const Change = struct {
    previous: View,
    current: View,

    pub fn changed(change: Change) bool {
        return change.previous != change.current;
    }
};

pub const Runtime = struct {
    current: View = .front,
    debug_override: DebugOverride = .automatic,
    interaction_owner: u32 = 0,
    interaction_view: View = .side,
    transition_count: u32 = 0,
    secondary_reset_count: u32 = 0,

    pub fn resolve(runtime: Runtime, automatic_input: AutomaticInput) View {
        if (runtime.interaction_owner != 0) return runtime.interaction_view;
        return switch (runtime.debug_override) {
            .automatic => automaticView(automatic_input),
            .force_side => .side,
            .force_front => .front,
        };
    }

    pub fn sync(runtime: *Runtime, automatic_input: AutomaticInput) !Change {
        const previous = runtime.current;
        const current = runtime.resolve(automatic_input);
        if (current != previous) {
            runtime.transition_count = std.math.add(u32, runtime.transition_count, 1) catch
                return error.PresentationTransitionCountOverflow;
            runtime.secondary_reset_count = std.math.add(u32, runtime.secondary_reset_count, 1) catch
                return error.PresentationSecondaryResetCountOverflow;
            runtime.current = current;
        }
        return .{ .previous = previous, .current = current };
    }

    pub fn setDebugOverride(runtime: *Runtime, value: DebugOverride) void {
        runtime.debug_override = value;
    }

    pub fn cycleDebugOverride(runtime: *Runtime) void {
        runtime.debug_override = runtime.debug_override.next();
    }

    pub fn claimInteraction(runtime: *Runtime, owner: u32, view: View) !void {
        if (owner == 0) return error.InvalidPresentationInteractionOwner;
        if (runtime.interaction_owner != 0) return error.PresentationViewAlreadyOwned;
        runtime.interaction_owner = owner;
        runtime.interaction_view = view;
    }

    pub fn releaseInteraction(runtime: *Runtime, owner: u32) !void {
        if (owner == 0) return error.InvalidPresentationInteractionOwner;
        if (runtime.interaction_owner != owner) return error.PresentationViewOwnershipMismatch;
        runtime.interaction_owner = 0;
        runtime.interaction_view = .side;
    }

    pub fn reset(runtime: *Runtime) void {
        runtime.* = .{};
    }
};

pub fn automaticView(input: AutomaticInput) View {
    if (!input.grounded) return .side;
    return switch (input.activity) {
        .idle => .front,
        .walking, .dashing, .jumping, .rising, .falling, .landing => .side,
    };
}

test "quarter-turn sprite morphology maps bone length and thickness once" {
    const TestVec2 = struct { x: f32, y: f32 };
    const positive = spriteMorphologyScale(TestVec2{ .x = 1.25, .y = 0.75 }, std.math.pi / 2.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), positive.x, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), positive.y, 0.000001);

    const reflected = spriteMorphologyScale(TestVec2{ .x = -1.25, .y = 0.75 }, -std.math.pi / 2.0);
    try std.testing.expectApproxEqAbs(@as(f32, -0.75), reflected.x, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), reflected.y, 0.000001);

    const unrotated = spriteMorphologyScale(TestVec2{ .x = 1.25, .y = 0.75 }, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.25), unrotated.x, 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), unrotated.y, 0.000001);
}
