const std = @import("std");

pub const gamepad_dead_zone: f32 = 0.20;

pub const KeyboardState = struct {
    a: bool = false,
    left_arrow: bool = false,
    d: bool = false,
    right_arrow: bool = false,
    space: bool = false,
    left_shift: bool = false,
    e: bool = false,
    r: bool = false,
    f1: bool = false,
    f2: bool = false,
    f3: bool = false,
    f4: bool = false,
    c: bool = false,
    v: bool = false,
    h: bool = false,
    l: bool = false,
    o: bool = false,
    p: bool = false,
    q: bool = false,
    t: bool = false,
    escape: bool = false,

    pub fn leftHeld(state: KeyboardState) bool {
        return state.a or state.left_arrow;
    }

    pub fn rightHeld(state: KeyboardState) bool {
        return state.d or state.right_arrow;
    }
};

/// One frame of physical device/window state. Names describe hardware rather
/// than application actions; semantic mapping belongs to the application.
pub const RawInputState = struct {
    keyboard: KeyboardState = .{},
    keyboard_focused: bool = true,
    focus_lost: bool = false,
    window_close_requested: bool = false,
    gamepad_left_x: f32 = 0,
    gamepad_button_south: bool = false,
    gamepad_button_right_shoulder: bool = false,
    gamepad_button_west: bool = false,
};

pub fn keyboardWithout(state: KeyboardState, blocked: KeyboardState) KeyboardState {
    var result = state;
    inline for (std.meta.fields(KeyboardState)) |field| {
        @field(result, field.name) = @field(state, field.name) and !@field(blocked, field.name);
    }
    return result;
}

pub fn keyboardUnion(left: KeyboardState, right: KeyboardState) KeyboardState {
    var result = left;
    inline for (std.meta.fields(KeyboardState)) |field| {
        @field(result, field.name) = @field(left, field.name) or @field(right, field.name);
    }
    return result;
}

pub fn keyboardIntersection(left: KeyboardState, right: KeyboardState) KeyboardState {
    var result = left;
    inline for (std.meta.fields(KeyboardState)) |field| {
        @field(result, field.name) = @field(left, field.name) and @field(right, field.name);
    }
    return result;
}

pub fn applyDeadZone(axis: f32, dead_zone: f32) f32 {
    if (!std.math.isFinite(axis) or !std.math.isFinite(dead_zone) or dead_zone < 0 or dead_zone >= 1) return 0;
    const magnitude = @abs(axis);
    if (magnitude <= dead_zone) return 0;
    const remapped = (magnitude - dead_zone) / (1 - dead_zone);
    return if (axis < 0) -remapped else remapped;
}

pub fn mergeAxes(digital_axis: f32, analog_axis: f32) f32 {
    const digital = std.math.clamp(digital_axis, -1, 1);
    const analog = std.math.clamp(analog_axis, -1, 1);
    return if (@abs(digital) >= @abs(analog)) digital else analog;
}
