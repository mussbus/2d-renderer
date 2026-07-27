const std = @import("std");
const c = @import("sdl").c;
const input = @import("input");

pub const PlatformInput = struct {
    snapshot_builder: input.SnapshotBuilder = .{},
    active_gamepad: ?*c.SDL_Gamepad = null,
    active_gamepad_id: c.SDL_JoystickID = 0,
    keyboard_focused: bool = true,
    focus_lost_pending: bool = false,
    window_close_pending: bool = false,

    pub fn init() PlatformInput {
        var platform = PlatformInput{};
        platform.openLowestAvailableGamepad();
        return platform;
    }

    pub fn deinit(platform: *PlatformInput) void {
        platform.closeActiveGamepad();
        platform.* = .{};
    }

    pub fn handleEvent(platform: *PlatformInput, event: *const c.SDL_Event) void {
        if (event.type == c.SDL_EVENT_QUIT or event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) {
            platform.window_close_pending = true;
        } else if (event.type == c.SDL_EVENT_WINDOW_FOCUS_LOST) {
            platform.keyboard_focused = false;
            platform.focus_lost_pending = true;
        } else if (event.type == c.SDL_EVENT_WINDOW_FOCUS_GAINED) {
            platform.keyboard_focused = true;
        } else if (event.type == c.SDL_EVENT_GAMEPAD_ADDED) {
            platform.considerGamepad(event.gdevice.which);
        } else if (event.type == c.SDL_EVENT_GAMEPAD_REMOVED and event.gdevice.which == platform.active_gamepad_id) {
            platform.closeActiveGamepad();
            platform.openLowestAvailableGamepad();
        }
    }

    pub fn pollFrame(platform: *PlatformInput) !input.FrameInputSnapshot {
        var key_count: c_int = 0;
        const keyboard = c.SDL_GetKeyboardState(&key_count);
        if (keyboard == null or key_count <= 0) return error.KeyboardStateUnavailable;

        if (platform.active_gamepad) |gamepad| {
            if (!c.SDL_GamepadConnected(gamepad)) {
                platform.closeActiveGamepad();
                platform.openLowestAvailableGamepad();
            }
        }

        var raw = input.RawInputState{
            .keyboard = .{
                .a = keyHeld(keyboard, key_count, c.SDL_SCANCODE_A),
                .left_arrow = keyHeld(keyboard, key_count, c.SDL_SCANCODE_LEFT),
                .d = keyHeld(keyboard, key_count, c.SDL_SCANCODE_D),
                .right_arrow = keyHeld(keyboard, key_count, c.SDL_SCANCODE_RIGHT),
                .space = keyHeld(keyboard, key_count, c.SDL_SCANCODE_SPACE),
                .left_shift = keyHeld(keyboard, key_count, c.SDL_SCANCODE_LSHIFT),
                .e = keyHeld(keyboard, key_count, c.SDL_SCANCODE_E),
                .r = keyHeld(keyboard, key_count, c.SDL_SCANCODE_R),
                .f1 = keyHeld(keyboard, key_count, c.SDL_SCANCODE_F1),
                .f2 = keyHeld(keyboard, key_count, c.SDL_SCANCODE_F2),
                .f3 = keyHeld(keyboard, key_count, c.SDL_SCANCODE_F3),
                .c = keyHeld(keyboard, key_count, c.SDL_SCANCODE_C),
                .v = keyHeld(keyboard, key_count, c.SDL_SCANCODE_V),
                .h = keyHeld(keyboard, key_count, c.SDL_SCANCODE_H),
                .l = keyHeld(keyboard, key_count, c.SDL_SCANCODE_L),
                .o = keyHeld(keyboard, key_count, c.SDL_SCANCODE_O),
                .p = keyHeld(keyboard, key_count, c.SDL_SCANCODE_P),
                .q = keyHeld(keyboard, key_count, c.SDL_SCANCODE_Q),
                .escape = keyHeld(keyboard, key_count, c.SDL_SCANCODE_ESCAPE),
            },
            .keyboard_focused = platform.keyboard_focused,
            .focus_lost = platform.focus_lost_pending,
            .window_close_requested = platform.window_close_pending,
        };
        if (platform.active_gamepad) |gamepad| {
            raw.gamepad_move_axis = normalizeAxis(c.SDL_GetGamepadAxis(gamepad, c.SDL_GAMEPAD_AXIS_LEFTX));
            raw.gamepad_jump = c.SDL_GetGamepadButton(gamepad, c.SDL_GAMEPAD_BUTTON_SOUTH);
            raw.gamepad_dash = c.SDL_GetGamepadButton(gamepad, c.SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER);
            raw.gamepad_interact = c.SDL_GetGamepadButton(gamepad, c.SDL_GAMEPAD_BUTTON_WEST);
        }
        const snapshot = try platform.snapshot_builder.update(raw);
        platform.focus_lost_pending = false;
        platform.window_close_pending = false;
        return snapshot;
    }

    pub fn reset(platform: *PlatformInput) void {
        platform.snapshot_builder.reset();
    }

    fn considerGamepad(platform: *PlatformInput, instance_id: c.SDL_JoystickID) void {
        if (platform.active_gamepad != null and instance_id >= platform.active_gamepad_id) return;
        const candidate = c.SDL_OpenGamepad(instance_id);
        if (candidate == null) {
            std.log.warn("SDL_OpenGamepad({d}) failed; keyboard input remains active: {s}", .{ instance_id, sdlErrorText() });
            return;
        }
        platform.closeActiveGamepad();
        platform.active_gamepad = candidate;
        platform.active_gamepad_id = instance_id;
        std.log.info("active SDL gamepad id={d}", .{instance_id});
    }

    fn openLowestAvailableGamepad(platform: *PlatformInput) void {
        var count: c_int = 0;
        const ids = c.SDL_GetGamepads(&count);
        defer if (ids != null) c.SDL_free(ids);
        if (ids == null or count <= 0) return;
        var selected = ids[0];
        var index: usize = 1;
        while (index < @as(usize, @intCast(count))) : (index += 1) {
            if (ids[index] < selected) selected = ids[index];
        }
        platform.considerGamepad(selected);
    }

    fn closeActiveGamepad(platform: *PlatformInput) void {
        if (platform.active_gamepad) |gamepad| c.SDL_CloseGamepad(gamepad);
        platform.active_gamepad = null;
        platform.active_gamepad_id = 0;
    }
};

fn keyHeld(keyboard: [*c]const bool, count: c_int, scancode: c.SDL_Scancode) bool {
    const index: usize = @intCast(scancode);
    if (index >= @as(usize, @intCast(count))) return false;
    return keyboard[index];
}

fn normalizeAxis(value: i16) f32 {
    if (value >= 0) return @as(f32, @floatFromInt(value)) / 32767.0;
    return @as(f32, @floatFromInt(value)) / 32768.0;
}

fn sdlErrorText() []const u8 {
    const pointer = c.SDL_GetError();
    if (pointer == null) return "no SDL diagnostic";
    return std.mem.span(@as([*:0]const u8, @ptrCast(pointer)));
}
