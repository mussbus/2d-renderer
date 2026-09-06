const physical = @import("physical_input");

pub const Actions = struct {
    select: ?usize = null,
    reset: bool = false,
    pause: bool = false,
    step: bool = false,
    impulse: bool = false,
    exit: bool = false,
};

/// Application semantics stop here. Production physical input has no lab names.
/// Held keys crossing focus/reset/switch boundaries must be released before reuse.
pub const Mapper = struct {
    previous: physical.KeyboardState = .{},
    blocked: physical.KeyboardState = .{},
    event_presses: physical.KeyboardState = .{},

    pub fn capturePress(self: *Mapper, keys: physical.KeyboardState) void {
        self.event_presses = physical.keyboardUnion(self.event_presses, physical.keyboardWithout(keys, self.blocked));
    }

    pub fn suppressHeld(self: *Mapper, raw: physical.RawInputState) void {
        self.blocked = raw.keyboard;
        self.previous = .{};
        self.event_presses = .{};
    }

    pub fn sample(self: *Mapper, raw: physical.RawInputState) Actions {
        if (raw.focus_lost or !raw.keyboard_focused) {
            self.suppressHeld(raw);
            return .{ .exit = raw.window_close_requested };
        }
        self.blocked = physical.keyboardIntersection(self.blocked, raw.keyboard);
        const current = physical.keyboardWithout(raw.keyboard, self.blocked);
        const pressed = physical.keyboardUnion(physical.keyboardWithout(current, self.previous), self.event_presses);
        self.event_presses = .{};
        self.previous = current;
        return .{
            .select = if (pressed.f1) 0 else if (pressed.f2) 1 else null,
            .reset = pressed.r,
            .pause = pressed.p,
            .step = pressed.t,
            .impulse = pressed.space,
            .exit = raw.window_close_requested or pressed.escape,
        };
    }
};
