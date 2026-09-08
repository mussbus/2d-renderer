const math = @import("math");
const fixed_step = @import("fixed_step");
const foundation = @import("foundation");
pub const motion = @import("secondary_motion");

/// One fixed hub frame, metres, world +X regardless of facing. The mount clears
/// the provisional actor's head; vertical motion is rigid, with no second solver.
pub const mount = math.Vec2{ .x = 0, .y = 3.4 };
/// Natural frequency 8 rad/s, damping ratio 0.375: readable underdamped lag.
/// Hard limits are 0.4 m and 3 m/s; settling snaps below 1 mm and 1 cm/s.
pub const profile = motion.Profile{
    .stiffness = 64,
    .damping = 6,
    .inertial_gain = 0.65,
    .external_gain = 1,
    .maximum_displacement = 0.4,
    .maximum_velocity = 3,
    .settle_displacement = 0.001,
    .settle_velocity = 0.01,
};
pub const Presentation = struct { reference: math.Vec2, response: math.Vec2 };

pub const Binding = struct {
    state: motion.State,
    previous_response: motion.Response,
    previous_reference: math.Vec2,
    reference: math.Vec2,

    pub fn init(root: math.Vec2) !Binding {
        const reference = try referenceAt(root);
        const state = try motion.State.init(profile, reference.x);
        return .{ .state = state, .previous_response = state.response, .previous_reference = reference, .reference = reference };
    }

    /// Called once after the production controller completes an executed tick.
    /// Driver acceleration is already differentiated by PSM01; external forcing
    /// is independently zero. No clock, rate resolver or render delta is owned.
    pub fn step(self: *Binding, completed_root: math.Vec2) !void {
        const reference = try referenceAt(completed_root);
        const previous = self.state.response;
        _ = try self.state.step(profile, .{
            .driver = .{ .position = reference.x },
            .external_acceleration = 0,
            .fixed_dt_seconds = fixed_step.fixed_dt_seconds,
        });
        self.previous_response = previous;
        self.previous_reference = self.reference;
        self.reference = reference;
    }

    /// Navigation uses the accepted reset API, including derivative history.
    /// fixed_ticks deliberately counts steps since this reset, not hub lifetime.
    pub fn reanchor(self: *Binding, root: math.Vec2) !void {
        const reference = try referenceAt(root);
        try self.state.reset(profile, reference.x);
        self.previous_response = self.state.response;
        self.previous_reference = reference;
        self.reference = reference;
    }

    pub fn presentation(self: *const Binding, alpha: f64, paused: bool) !Presentation {
        const reference = if (paused) self.reference else math.Vec2{
            .x = try fixed_step.interpolateScalar(self.previous_reference.x, self.reference.x, alpha),
            .y = try fixed_step.interpolateScalar(self.previous_reference.y, self.reference.y, alpha),
        };
        const offset = if (paused) self.state.response.offset else try fixed_step.interpolateScalar(self.previous_response.offset, self.state.response.offset, alpha);
        return .{ .reference = reference, .response = reference.add(.{ .x = offset, .y = 0 }) };
    }

    /// Diagnostic schema only, independent of selected hub state v2 and impact
    /// observations v2. Includes presentation history; not save or replay data.
    pub fn fingerprint(self: *const Binding) !foundation.canonical_data.Sha256Digest {
        var storage: [512]u8 = undefined;
        var writer = foundation.canonical_data.Writer.init(&storage);
        try writer.raw("{\"schema\":1,\"steps_since_reset\":");
        try writer.u64Value(self.state.fixed_ticks);
        try writer.raw(",\"samples\":[");
        const values = [_]f32{ self.state.driver_position, self.state.driver_velocity, self.state.response.offset, self.state.response.velocity, self.previous_response.offset, self.previous_response.velocity, self.previous_reference.x, self.previous_reference.y, self.reference.x, self.reference.y };
        for (values, 0..) |value, index| {
            if (index != 0) try writer.byte(',');
            try writer.f32Value(value);
        }
        try writer.raw("]}");
        return foundation.canonical_data.hashDomainSeparated("engine_lab.calibration.observations.v1", &.{writer.bytes()});
    }
};

fn referenceAt(root: math.Vec2) !math.Vec2 {
    const value = root.add(mount);
    if (!root.isFinite() or !value.isFinite()) return error.InvalidCalibrationReference;
    return value;
}
