const std = @import("std");

pub const View = enum(u8) {
    side,
    front,
};

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
