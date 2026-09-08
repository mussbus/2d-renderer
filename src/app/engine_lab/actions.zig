const physical = @import("physical_input");
const hub = @import("engine_lab");

pub const Actions = struct {
    destination: ?hub.Destination = null,
    reset: bool = false,
    pause: bool = false,
    step: bool = false,
    diagnostics: bool = false,
    exit: bool = false,
    activate: bool = false,
    clear_activation: bool = false,
    intent: hub.Intent = hub.neutral_intent,
};

/// Physical input becomes explicit application actions and production intent.
/// No sandbox action mapper or device state crosses into the hub simulation.
pub const Mapper = struct {
    previous: physical.KeyboardState = .{},
    blocked: physical.KeyboardState = .{},
    event_presses: physical.KeyboardState = .{},
    previous_jump: bool = false,
    blocked_gamepad_jump: bool = false,
    blocked_gamepad_axis: bool = false,
    previous_activation: bool = false,
    blocked_gamepad_activation: bool = false,

    pub fn capturePress(self: *Mapper, keys: physical.KeyboardState) void {
        self.event_presses = physical.keyboardUnion(self.event_presses, physical.keyboardWithout(keys, self.blocked));
    }

    pub fn suppressHeld(self: *Mapper, raw: physical.RawInputState) void {
        self.blocked = physical.keyboardUnion(raw.keyboard, self.previous);
        self.previous = .{};
        self.event_presses = .{};
        self.previous_jump = false;
        self.previous_activation = false;
        self.blocked_gamepad_activation = self.blocked_gamepad_activation or raw.gamepad_button_west;
        self.blocked_gamepad_jump = raw.gamepad_button_south;
        self.blocked_gamepad_axis = physical.applyDeadZone(raw.gamepad_left_x, physical.gamepad_dead_zone) != 0;
    }

    pub fn sample(self: *Mapper, raw: physical.RawInputState) Actions {
        if (raw.focus_lost or !raw.keyboard_focused) {
            self.suppressHeld(raw);
            return .{ .exit = raw.window_close_requested, .clear_activation = true };
        }
        self.blocked = physical.keyboardIntersection(self.blocked, raw.keyboard);
        const current = physical.keyboardWithout(raw.keyboard, self.blocked);
        const pressed = physical.keyboardUnion(physical.keyboardWithout(current, self.previous), self.event_presses);
        self.event_presses = .{};
        self.previous = current;
        self.blocked_gamepad_jump = self.blocked_gamepad_jump and raw.gamepad_button_south;
        const analog = physical.applyDeadZone(raw.gamepad_left_x, physical.gamepad_dead_zone);
        self.blocked_gamepad_axis = self.blocked_gamepad_axis and analog != 0;
        const jump = current.space or (raw.gamepad_button_south and !self.blocked_gamepad_jump);
        const jump_pressed = pressed.space or (jump and !self.previous_jump);
        const jump_released = (!jump and self.previous_jump) or (jump_pressed and !jump);
        self.previous_jump = jump;
        self.blocked_gamepad_activation = self.blocked_gamepad_activation and raw.gamepad_button_west;
        const activation = current.e or (raw.gamepad_button_west and !self.blocked_gamepad_activation);
        const activate = pressed.e or (activation and !self.previous_activation);
        self.previous_activation = activation;
        const digital: f32 = @as(f32, @floatFromInt(@intFromBool(current.rightHeld()))) - @as(f32, @floatFromInt(@intFromBool(current.leftHeld())));
        return .{
            .destination = if (pressed.f1) .hierarchy else if (pressed.f2) .springs else null,
            .reset = pressed.r,
            .pause = pressed.p,
            .step = pressed.t,
            .diagnostics = pressed.f3,
            .exit = raw.window_close_requested or pressed.escape,
            .activate = activate,
            .intent = .{
                .move_axis = physical.mergeAxes(digital, if (self.blocked_gamepad_axis) 0 else analog),
                .jump_pressed = jump_pressed,
                .jump_held = jump,
                .jump_released = jump_released,
                .interact_pressed = false,
            },
        };
    }
};

/// One application composition point shared by native input and headless tests.
/// Reset dominates every other action and executes zero ticks. Travel/focus loss
/// clear activation in both owners; held physical actions require release.
pub fn advance(world: *hub.Hub, mapper: *Mapper, raw: physical.RawInputState, command: Actions, seconds: f64) !void {
    if (command.reset) {
        try world.reset();
        mapper.suppressHeld(raw);
        return;
    }
    var intent = command.intent;
    if (command.clear_activation) world.impact.pending_activation = false;
    if (command.destination) |destination| {
        try world.navigate(destination);
        mapper.suppressHeld(raw);
        intent = hub.neutral_intent;
    } else if (command.activate and !command.clear_activation) world.impact.pending_activation = true;
    if (command.pause) world.clock.setPaused(!world.clock.paused);
    if (command.step) world.clock.requestSingleStep();
    if (command.diagnostics) world.diagnostics_enabled = !world.diagnostics_enabled;
    try world.advanceFrame(seconds, intent);
}
