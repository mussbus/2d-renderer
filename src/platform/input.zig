const std = @import("std");

pub const gamepad_dead_zone: f32 = 0.20;

pub const KeyboardState = struct {
    a: bool = false,
    left_arrow: bool = false,
    d: bool = false,
    right_arrow: bool = false,
    space: bool = false,
    e: bool = false,
    r: bool = false,
    f1: bool = false,
    f2: bool = false,
    f3: bool = false,
    escape: bool = false,

    pub fn leftHeld(state: KeyboardState) bool {
        return state.a or state.left_arrow;
    }

    pub fn rightHeld(state: KeyboardState) bool {
        return state.d or state.right_arrow;
    }
};

pub const RawInputState = struct {
    keyboard: KeyboardState = .{},
    keyboard_focused: bool = true,
    focus_lost: bool = false,
    window_close_requested: bool = false,
    gamepad_move_axis: f32 = 0,
    gamepad_jump: bool = false,
    gamepad_interact: bool = false,
};

pub const ButtonSnapshot = extern struct {
    pressed: bool,
    held: bool,
    released: bool,
};

pub const FrameInputSnapshot = struct {
    keyboard_left_held: bool,
    keyboard_right_held: bool,
    move_axis: f32,
    jump: ButtonSnapshot,
    interact: ButtonSnapshot,
    reset: ButtonSnapshot,
    debug_toggle: ButtonSnapshot,
    time_mode_cycle: ButtonSnapshot,
    single_step: ButtonSnapshot,
    exit: ButtonSnapshot,
    focus_lost: bool,
};

pub const CharacterIntent = extern struct {
    move_axis: f32,
    jump_pressed: bool,
    jump_held: bool,
    jump_released: bool,
    interact_pressed: bool,

    pub fn validate(intent: CharacterIntent) !void {
        if (!std.math.isFinite(intent.move_axis)) return error.NonFiniteMoveAxis;
        if (intent.move_axis < -1 or intent.move_axis > 1) return error.MoveAxisOutOfRange;
    }
};

pub const SnapshotBuilder = struct {
    previous_jump: bool = false,
    previous_interact: bool = false,
    previous_reset: bool = false,
    previous_debug_toggle: bool = false,
    previous_time_mode_cycle: bool = false,
    previous_single_step: bool = false,
    previous_exit: bool = false,
    keyboard_focused: bool = true,
    blocked_until_release: KeyboardState = .{},

    pub fn update(builder: *SnapshotBuilder, raw: RawInputState) !FrameInputSnapshot {
        if (!std.math.isFinite(raw.gamepad_move_axis)) return error.NonFiniteGamepadAxis;

        var effective_keyboard = raw.keyboard;
        if (raw.focus_lost) {
            builder.keyboard_focused = false;
            builder.blocked_until_release = keyboardUnion(builder.blocked_until_release, raw.keyboard);
        }
        if (!raw.keyboard_focused) {
            builder.keyboard_focused = false;
            builder.blocked_until_release = keyboardUnion(builder.blocked_until_release, raw.keyboard);
            effective_keyboard = .{};
        } else {
            builder.keyboard_focused = true;
            effective_keyboard = keyboardWithout(raw.keyboard, builder.blocked_until_release);
            builder.blocked_until_release = keyboardIntersection(builder.blocked_until_release, raw.keyboard);
        }

        const keyboard_left = effective_keyboard.leftHeld();
        const keyboard_right = effective_keyboard.rightHeld();
        const gamepad_axis = applyDeadZone(std.math.clamp(raw.gamepad_move_axis, -1, 1), gamepad_dead_zone);
        const keyboard_axis: f32 = if (keyboard_left == keyboard_right)
            0
        else if (keyboard_left)
            -1
        else
            1;
        const move_axis = mergeMoveAxes(keyboard_axis, gamepad_axis);
        const jump_held = effective_keyboard.space or raw.gamepad_jump;
        const interact_held = effective_keyboard.e or raw.gamepad_interact;
        const exit_held = effective_keyboard.escape or raw.window_close_requested;

        const snapshot = FrameInputSnapshot{
            .keyboard_left_held = keyboard_left,
            .keyboard_right_held = keyboard_right,
            .move_axis = move_axis,
            .jump = button(builder.previous_jump, jump_held),
            .interact = button(builder.previous_interact, interact_held),
            .reset = button(builder.previous_reset, effective_keyboard.r),
            .debug_toggle = button(builder.previous_debug_toggle, effective_keyboard.f1),
            .time_mode_cycle = button(builder.previous_time_mode_cycle, effective_keyboard.f2),
            .single_step = button(builder.previous_single_step, effective_keyboard.f3),
            .exit = button(builder.previous_exit, exit_held),
            .focus_lost = raw.focus_lost,
        };
        builder.previous_jump = jump_held;
        builder.previous_interact = interact_held;
        builder.previous_reset = effective_keyboard.r;
        builder.previous_debug_toggle = effective_keyboard.f1;
        builder.previous_time_mode_cycle = effective_keyboard.f2;
        builder.previous_single_step = effective_keyboard.f3;
        builder.previous_exit = exit_held;
        return snapshot;
    }

    pub fn reset(builder: *SnapshotBuilder) void {
        builder.* = .{};
    }
};

pub const PendingInput = struct {
    move_axis: f32 = 0,
    jump_held: bool = false,
    jump_pressed_pending: bool = false,
    jump_released_pending: bool = false,
    interact_pressed_pending: bool = false,

    pub fn acceptFrame(pending: *PendingInput, snapshot: FrameInputSnapshot) !void {
        if (!std.math.isFinite(snapshot.move_axis) or snapshot.move_axis < -1 or snapshot.move_axis > 1) {
            return error.InvalidFrameMoveAxis;
        }
        if (snapshot.focus_lost) {
            pending.jump_held = false;
            pending.jump_pressed_pending = false;
            pending.jump_released_pending = false;
            pending.interact_pressed_pending = false;
        }
        pending.move_axis = snapshot.move_axis;
        pending.jump_held = snapshot.jump.held;
        pending.jump_pressed_pending = pending.jump_pressed_pending or snapshot.jump.pressed;
        pending.jump_released_pending = pending.jump_released_pending or snapshot.jump.released;
        pending.interact_pressed_pending = pending.interact_pressed_pending or snapshot.interact.pressed;
    }

    pub fn consumeTick(pending: *PendingInput) CharacterIntent {
        const result = CharacterIntent{
            .move_axis = pending.move_axis,
            .jump_pressed = pending.jump_pressed_pending,
            .jump_held = pending.jump_held,
            .jump_released = pending.jump_released_pending,
            .interact_pressed = pending.interact_pressed_pending,
        };
        pending.jump_pressed_pending = false;
        pending.jump_released_pending = false;
        pending.interact_pressed_pending = false;
        return result;
    }

    pub fn pendingEdgeCount(pending: PendingInput) u8 {
        return @as(u8, @intFromBool(pending.jump_pressed_pending)) +
            @as(u8, @intFromBool(pending.jump_released_pending)) +
            @as(u8, @intFromBool(pending.interact_pressed_pending));
    }

    pub fn reset(pending: *PendingInput) void {
        pending.* = .{};
    }
};

pub fn applyDeadZone(axis: f32, dead_zone: f32) f32 {
    if (!std.math.isFinite(axis) or !std.math.isFinite(dead_zone) or dead_zone < 0 or dead_zone >= 1) return 0;
    const magnitude = @abs(axis);
    if (magnitude <= dead_zone) return 0;
    const remapped = (magnitude - dead_zone) / (1 - dead_zone);
    return if (axis < 0) -remapped else remapped;
}

pub fn mergeMoveAxes(keyboard_axis: f32, gamepad_axis: f32) f32 {
    const keyboard = std.math.clamp(keyboard_axis, -1, 1);
    const gamepad = std.math.clamp(gamepad_axis, -1, 1);
    return if (@abs(keyboard) >= @abs(gamepad)) keyboard else gamepad;
}

fn keyboardWithout(state: KeyboardState, blocked: KeyboardState) KeyboardState {
    return .{
        .a = state.a and !blocked.a,
        .left_arrow = state.left_arrow and !blocked.left_arrow,
        .d = state.d and !blocked.d,
        .right_arrow = state.right_arrow and !blocked.right_arrow,
        .space = state.space and !blocked.space,
        .e = state.e and !blocked.e,
        .r = state.r and !blocked.r,
        .f1 = state.f1 and !blocked.f1,
        .f2 = state.f2 and !blocked.f2,
        .f3 = state.f3 and !blocked.f3,
        .escape = state.escape and !blocked.escape,
    };
}

fn keyboardUnion(left: KeyboardState, right: KeyboardState) KeyboardState {
    return .{
        .a = left.a or right.a,
        .left_arrow = left.left_arrow or right.left_arrow,
        .d = left.d or right.d,
        .right_arrow = left.right_arrow or right.right_arrow,
        .space = left.space or right.space,
        .e = left.e or right.e,
        .r = left.r or right.r,
        .f1 = left.f1 or right.f1,
        .f2 = left.f2 or right.f2,
        .f3 = left.f3 or right.f3,
        .escape = left.escape or right.escape,
    };
}

fn keyboardIntersection(left: KeyboardState, right: KeyboardState) KeyboardState {
    return .{
        .a = left.a and right.a,
        .left_arrow = left.left_arrow and right.left_arrow,
        .d = left.d and right.d,
        .right_arrow = left.right_arrow and right.right_arrow,
        .space = left.space and right.space,
        .e = left.e and right.e,
        .r = left.r and right.r,
        .f1 = left.f1 and right.f1,
        .f2 = left.f2 and right.f2,
        .f3 = left.f3 and right.f3,
        .escape = left.escape and right.escape,
    };
}

fn button(previous: bool, current: bool) ButtonSnapshot {
    return .{
        .pressed = !previous and current,
        .held = current,
        .released = previous and !current,
    };
}
