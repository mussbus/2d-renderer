const std = @import("std");

/// Domain command consumed by character physics. Device and demo action names
/// intentionally do not cross this boundary.
pub const CharacterIntent = extern struct {
    move_axis: f32,
    jump_pressed: bool,
    jump_held: bool,
    jump_released: bool,
    dash_pressed: bool = false,
    interact_pressed: bool,

    pub fn validate(intent: CharacterIntent) !void {
        if (!std.math.isFinite(intent.move_axis)) return error.NonFiniteMoveAxis;
        if (intent.move_axis < -1 or intent.move_axis > 1) return error.MoveAxisOutOfRange;
    }
};
