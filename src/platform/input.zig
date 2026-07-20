const std = @import("std");

pub const gamepad_dead_zone: f32 = 0.20;

pub const RawInputState = struct {
    keyboard_left: bool = false,
    keyboard_right: bool = false,
    jump: bool = false,
    interact: bool = false,
    reset: bool = false,
    debug_toggle: bool = false,
    time_mode_cycle: bool = false,
    single_step: bool = false,
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
    move_axis: f32,
    jump: ButtonSnapshot,
    interact: ButtonSnapshot,
    reset: ButtonSnapshot,
    debug_toggle: ButtonSnapshot,
    time_mode_cycle: ButtonSnapshot,
    single_step: ButtonSnapshot,
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

    pub fn update(builder: *SnapshotBuilder, raw: RawInputState) !FrameInputSnapshot {
        if (!std.math.isFinite(raw.gamepad_move_axis)) return error.NonFiniteGamepadAxis;
        const gamepad_axis = applyDeadZone(std.math.clamp(raw.gamepad_move_axis, -1, 1), gamepad_dead_zone);
        const keyboard_axis: f32 = if (raw.keyboard_left == raw.keyboard_right)
            0
        else if (raw.keyboard_left)
            -1
        else
            1;
        const move_axis = mergeMoveAxes(keyboard_axis, gamepad_axis);
        const jump_held = raw.jump or raw.gamepad_jump;
        const interact_held = raw.interact or raw.gamepad_interact;

        const snapshot = FrameInputSnapshot{
            .move_axis = move_axis,
            .jump = button(builder.previous_jump, jump_held),
            .interact = button(builder.previous_interact, interact_held),
            .reset = button(builder.previous_reset, raw.reset),
            .debug_toggle = button(builder.previous_debug_toggle, raw.debug_toggle),
            .time_mode_cycle = button(builder.previous_time_mode_cycle, raw.time_mode_cycle),
            .single_step = button(builder.previous_single_step, raw.single_step),
        };
        builder.previous_jump = jump_held;
        builder.previous_interact = interact_held;
        builder.previous_reset = raw.reset;
        builder.previous_debug_toggle = raw.debug_toggle;
        builder.previous_time_mode_cycle = raw.time_mode_cycle;
        builder.previous_single_step = raw.single_step;
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

fn button(previous: bool, current: bool) ButtonSnapshot {
    return .{
        .pressed = !previous and current,
        .held = current,
        .released = previous and !current,
    };
}
