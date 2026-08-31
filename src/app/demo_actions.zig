const std = @import("std");
const physical = @import("physical_input");
const character_intent = @import("character_intent");

pub const gamepad_dead_zone = physical.gamepad_dead_zone;
pub const KeyboardState = physical.KeyboardState;
pub const RawInputState = physical.RawInputState;
pub const CharacterIntent = character_intent.CharacterIntent;

pub const ButtonSnapshot = extern struct {
    pressed: bool,
    held: bool,
    released: bool,
};

const released_button = ButtonSnapshot{ .pressed = false, .held = false, .released = false };

/// Application/demo actions derived from one physical input frame.
pub const FrameInputSnapshot = struct {
    keyboard_left_held: bool,
    keyboard_right_held: bool,
    move_axis: f32,
    jump: ButtonSnapshot,
    dash: ButtonSnapshot = released_button,
    interact: ButtonSnapshot,
    reset: ButtonSnapshot,
    debug_toggle: ButtonSnapshot,
    time_mode_cycle: ButtonSnapshot,
    single_step: ButtonSnapshot,
    manual_debug_capture: ButtonSnapshot = released_button,
    body_preset_cycle: ButtonSnapshot = released_button,
    build_cycle: ButtonSnapshot = released_button,
    hair_cycle: ButtonSnapshot = released_button,
    loadout_cycle: ButtonSnapshot = released_button,
    outfit_cycle: ButtonSnapshot = released_button,
    pause_toggle: ButtonSnapshot = released_button,
    presentation_view_cycle: ButtonSnapshot = released_button,
    environment_theme_cycle: ButtonSnapshot = released_button,
    exit: ButtonSnapshot,
    focus_lost: bool,
};

pub const SnapshotBuilder = struct {
    previous_jump: bool = false,
    previous_dash: bool = false,
    previous_interact: bool = false,
    previous_reset: bool = false,
    previous_debug_toggle: bool = false,
    previous_time_mode_cycle: bool = false,
    previous_single_step: bool = false,
    previous_manual_debug_capture: bool = false,
    previous_body_preset_cycle: bool = false,
    previous_build_cycle: bool = false,
    previous_hair_cycle: bool = false,
    previous_loadout_cycle: bool = false,
    previous_outfit_cycle: bool = false,
    previous_pause_toggle: bool = false,
    previous_presentation_view_cycle: bool = false,
    previous_environment_theme_cycle: bool = false,
    previous_exit: bool = false,
    keyboard_focused: bool = true,
    blocked_until_release: KeyboardState = .{},

    pub fn update(builder: *SnapshotBuilder, raw: RawInputState) !FrameInputSnapshot {
        if (!std.math.isFinite(raw.gamepad_left_x)) return error.NonFiniteGamepadAxis;

        var effective_keyboard = raw.keyboard;
        if (raw.focus_lost) {
            builder.keyboard_focused = false;
            builder.blocked_until_release = physical.keyboardUnion(builder.blocked_until_release, raw.keyboard);
        }
        if (!raw.keyboard_focused) {
            builder.keyboard_focused = false;
            builder.blocked_until_release = physical.keyboardUnion(builder.blocked_until_release, raw.keyboard);
            effective_keyboard = .{};
        } else {
            builder.keyboard_focused = true;
            effective_keyboard = physical.keyboardWithout(raw.keyboard, builder.blocked_until_release);
            builder.blocked_until_release = physical.keyboardIntersection(builder.blocked_until_release, raw.keyboard);
        }

        const keyboard_left = effective_keyboard.leftHeld();
        const keyboard_right = effective_keyboard.rightHeld();
        const gamepad_axis = physical.applyDeadZone(
            std.math.clamp(raw.gamepad_left_x, -1, 1),
            physical.gamepad_dead_zone,
        );
        const keyboard_axis: f32 = if (keyboard_left == keyboard_right)
            0
        else if (keyboard_left)
            -1
        else
            1;
        const move_axis = physical.mergeAxes(keyboard_axis, gamepad_axis);
        const jump_held = effective_keyboard.space or raw.gamepad_button_south;
        const dash_held = effective_keyboard.left_shift or raw.gamepad_button_right_shoulder;
        const interact_held = effective_keyboard.e or raw.gamepad_button_west;
        const exit_held = effective_keyboard.escape or raw.window_close_requested;

        const snapshot = FrameInputSnapshot{
            .keyboard_left_held = keyboard_left,
            .keyboard_right_held = keyboard_right,
            .move_axis = move_axis,
            .jump = button(builder.previous_jump, jump_held),
            .dash = button(builder.previous_dash, dash_held),
            .interact = button(builder.previous_interact, interact_held),
            .reset = button(builder.previous_reset, effective_keyboard.r),
            .debug_toggle = button(builder.previous_debug_toggle, effective_keyboard.f1),
            .time_mode_cycle = button(builder.previous_time_mode_cycle, effective_keyboard.f2),
            .single_step = button(builder.previous_single_step, effective_keyboard.f3),
            .manual_debug_capture = button(builder.previous_manual_debug_capture, effective_keyboard.f4),
            .body_preset_cycle = button(builder.previous_body_preset_cycle, effective_keyboard.c),
            .build_cycle = button(builder.previous_build_cycle, effective_keyboard.v),
            .hair_cycle = button(builder.previous_hair_cycle, effective_keyboard.h),
            .loadout_cycle = button(builder.previous_loadout_cycle, effective_keyboard.l),
            .outfit_cycle = button(builder.previous_outfit_cycle, effective_keyboard.o),
            .pause_toggle = button(builder.previous_pause_toggle, effective_keyboard.p),
            .presentation_view_cycle = button(builder.previous_presentation_view_cycle, effective_keyboard.q),
            .environment_theme_cycle = button(builder.previous_environment_theme_cycle, effective_keyboard.t),
            .exit = button(builder.previous_exit, exit_held),
            .focus_lost = raw.focus_lost,
        };
        builder.previous_jump = jump_held;
        builder.previous_dash = dash_held;
        builder.previous_interact = interact_held;
        builder.previous_reset = effective_keyboard.r;
        builder.previous_debug_toggle = effective_keyboard.f1;
        builder.previous_time_mode_cycle = effective_keyboard.f2;
        builder.previous_single_step = effective_keyboard.f3;
        builder.previous_manual_debug_capture = effective_keyboard.f4;
        builder.previous_body_preset_cycle = effective_keyboard.c;
        builder.previous_build_cycle = effective_keyboard.v;
        builder.previous_hair_cycle = effective_keyboard.h;
        builder.previous_loadout_cycle = effective_keyboard.l;
        builder.previous_outfit_cycle = effective_keyboard.o;
        builder.previous_pause_toggle = effective_keyboard.p;
        builder.previous_presentation_view_cycle = effective_keyboard.q;
        builder.previous_environment_theme_cycle = effective_keyboard.t;
        builder.previous_exit = exit_held;
        return snapshot;
    }

    pub fn reset(builder: *SnapshotBuilder) void {
        builder.* = .{};
    }
};

/// Fixed-step delivery for movement/interaction commands. It preserves frame
/// edges until the next simulation tick without owning the domain behavior.
pub const PendingInput = struct {
    move_axis: f32 = 0,
    jump_held: bool = false,
    jump_pressed_pending: bool = false,
    jump_released_pending: bool = false,
    dash_pressed_pending: bool = false,
    interact_pressed_pending: bool = false,

    pub fn acceptFrame(pending: *PendingInput, snapshot: FrameInputSnapshot) !void {
        if (!std.math.isFinite(snapshot.move_axis) or snapshot.move_axis < -1 or snapshot.move_axis > 1) {
            return error.InvalidFrameMoveAxis;
        }
        if (snapshot.focus_lost) {
            pending.jump_held = false;
            pending.jump_pressed_pending = false;
            pending.jump_released_pending = false;
            pending.dash_pressed_pending = false;
            pending.interact_pressed_pending = false;
        }
        pending.move_axis = snapshot.move_axis;
        pending.jump_held = snapshot.jump.held;
        pending.jump_pressed_pending = pending.jump_pressed_pending or snapshot.jump.pressed;
        pending.jump_released_pending = pending.jump_released_pending or snapshot.jump.released;
        pending.dash_pressed_pending = pending.dash_pressed_pending or snapshot.dash.pressed;
        pending.interact_pressed_pending = pending.interact_pressed_pending or snapshot.interact.pressed;
    }

    pub fn consumeTick(pending: *PendingInput) CharacterIntent {
        const result = CharacterIntent{
            .move_axis = pending.move_axis,
            .jump_pressed = pending.jump_pressed_pending,
            .jump_held = pending.jump_held,
            .jump_released = pending.jump_released_pending,
            .dash_pressed = pending.dash_pressed_pending,
            .interact_pressed = pending.interact_pressed_pending,
        };
        pending.jump_pressed_pending = false;
        pending.jump_released_pending = false;
        pending.dash_pressed_pending = false;
        pending.interact_pressed_pending = false;
        return result;
    }

    pub fn pendingEdgeCount(pending: PendingInput) u8 {
        return @as(u8, @intFromBool(pending.jump_pressed_pending)) +
            @as(u8, @intFromBool(pending.jump_released_pending)) +
            @as(u8, @intFromBool(pending.dash_pressed_pending)) +
            @as(u8, @intFromBool(pending.interact_pressed_pending));
    }

    pub fn reset(pending: *PendingInput) void {
        pending.* = .{};
    }
};

pub fn applyDeadZone(axis: f32, dead_zone: f32) f32 {
    return physical.applyDeadZone(axis, dead_zone);
}

pub fn mergeMoveAxes(keyboard_axis: f32, gamepad_axis: f32) f32 {
    return physical.mergeAxes(keyboard_axis, gamepad_axis);
}

fn button(previous: bool, current: bool) ButtonSnapshot {
    return .{
        .pressed = !previous and current,
        .held = current,
        .released = previous and !current,
    };
}
