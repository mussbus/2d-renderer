const std = @import("std");
const c = @import("sdl").c;
const input = @import("input");

pub const PlatformInput = struct {
    snapshot_builder: input.SnapshotBuilder = .{},
    active_gamepad: ?*c.SDL_Gamepad = null,
    active_gamepad_id: c.SDL_JoystickID = 0,

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
        if (event.type == c.SDL_EVENT_GAMEPAD_ADDED) {
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
            .keyboard_left = keyHeld(keyboard, key_count, c.SDL_SCANCODE_A) or keyHeld(keyboard, key_count, c.SDL_SCANCODE_LEFT),
            .keyboard_right = keyHeld(keyboard, key_count, c.SDL_SCANCODE_D) or keyHeld(keyboard, key_count, c.SDL_SCANCODE_RIGHT),
            .jump = keyHeld(keyboard, key_count, c.SDL_SCANCODE_SPACE),
            .interact = keyHeld(keyboard, key_count, c.SDL_SCANCODE_E),
            .reset = keyHeld(keyboard, key_count, c.SDL_SCANCODE_R),
            .debug_toggle = keyHeld(keyboard, key_count, c.SDL_SCANCODE_F1),
            .time_mode_cycle = keyHeld(keyboard, key_count, c.SDL_SCANCODE_F2),
            .single_step = keyHeld(keyboard, key_count, c.SDL_SCANCODE_F3),
        };
        if (platform.active_gamepad) |gamepad| {
            raw.gamepad_move_axis = normalizeAxis(c.SDL_GetGamepadAxis(gamepad, c.SDL_GAMEPAD_AXIS_LEFTX));
            raw.gamepad_jump = c.SDL_GetGamepadButton(gamepad, c.SDL_GAMEPAD_BUTTON_SOUTH);
            raw.gamepad_interact = c.SDL_GetGamepadButton(gamepad, c.SDL_GAMEPAD_BUTTON_WEST);
        }
        return platform.snapshot_builder.update(raw);
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
