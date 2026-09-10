const std = @import("std");
const hub_module = @import("engine_lab");
const debug = @import("debug_draw");
const math = @import("math");
const sprite = @import("sprite_batch");
const queue_module = @import("render_queue");
const fixed_step = @import("fixed_step");
const collider = @import("collider");
const impact = hub_module.impact_module;

// Presentation policy belongs here, outside the headless hub/physics graph.
pub const preexisting_sprite_bound: usize = 1792;
pub const calibration_sprite_allowance: usize = 64;
pub const accepted_calibration_bound: usize = preexisting_sprite_bound + calibration_sprite_allowance;
pub const time_sprite_allowance: usize = 128;
pub const legacy_sprite_capacity: usize = accepted_calibration_bound + time_sprite_allowance;
// Traversal bound 2200 plus 54 F4 ZOOM glyph sprites and 32 spare.
pub const sprite_capacity: usize = 2286;
pub const legacy_entry_capacity: usize = 2048;
pub const entry_capacity: usize = sprite_capacity;
pub const mesh_capacity: usize = 256;

const colors = [hub_module.mass_count][4]f32{ .{ 0.25, 0.85, 1, 1 }, .{ 1, 0.65, 0.2, 1 }, .{ 0.85, 0.4, 1, 1 } };
const text_color = [4]f32{ 0.85, 0.93, 1, 1 };

pub const HudRange = struct { start: usize = 0, end: usize = 0 };

pub const View = struct {
    // Actual glyph ranges for window-framing verification: controls, status, time.
    hud_ranges: [3]HudRange = .{ .{}, .{}, .{} },
    commands: debug.CommandBuffer = .{},
    calibration_sprite_count: usize = 0,
    time_sprite_count: usize = 0,
    actor_queue: queue_module.UnifiedRenderQueue,
    particles: [impact.particle_capacity]impact.e.RenderInstance = undefined,
    projectiles: [impact.projectile_capacity]impact.p.Snapshot = undefined,

    pub fn init(allocator: std.mem.Allocator) !View {
        var queue = try queue_module.UnifiedRenderQueue.init(allocator, 16, 16, 1, 1);
        queue.markStabilized();
        return .{ .actor_queue = queue };
    }
    pub fn deinit(self: *View) void {
        self.actor_queue.deinit();
        self.* = undefined;
    }

    /// Production extraction supplies the complete segmented pose. This adapter
    /// translates its copied submissions by the interpolated physics-root delta;
    /// it never rewrites character pose or controller authority.
    pub fn render(self: *View, hub: *hub_module.Hub, queue: *queue_module.UnifiedRenderQueue) !void {
        self.commands.beginFrame();
        queue.beginFrame();
        for (hub_module.layout.colliders(hub.construction), 0..) |item, index| {
            _ = try queue.submitSprite(box(item.bounds.center(), item.bounds.size(), if (index == 3) .{ 0.27, 0.37, 0.47, 1 } else .{ 0.12, 0.19, 0.27, 1 }, -10));
            if (hub.diagnostics_enabled) try self.commands.addAabb(item.bounds, .{ 0.5, 0.75, 0.9, 1 });
        }
        const mark_count: usize = if (hub.construction == .expanded) 31 else 15;
        for (0..mark_count) |mark| {
            const x = @as(f32, @floatFromInt(mark)) - @as(f32, if (hub.construction == .expanded) 23 else 7);
            _ = try queue.submitSprite(box(.{ .x = x, .y = -0.07 }, .{ .x = 0.06, .y = 0.1 }, .{ 0.4, 0.6, 0.7, 1 }, -9));
        }
        if (hub.construction == .expanded) for (hub_module.layout.routes) |route| try self.label(route.label_origin, route.label);
        for (hub.stations, hub.installations.roots, hub.installations.anchors, 0..) |station, root, anchors, index| {
            try self.label(.{ .x = root.world.x - 1.05, .y = 3.55 }, if (index == 0) "F1 LINKS" else "F2 DAMPING");
            for (anchors, station.springs, station.previous_offsets, 0..) |anchor, state, previous, mass| {
                try self.commands.addLine(root.world, anchor.world, .{ 0.3, 0.45, 0.6, 1 });
                try self.commands.addMarker(anchor.world, text_color);
                const offset = if (hub.clock.paused) state.offset else try fixed_step.interpolateScalar(previous, state.offset, hub.clock.last_frame.interpolation_alpha);
                const center = math.Vec2{ .x = anchor.world.x, .y = anchor.world.y - 0.85 + offset };
                try self.commands.addLine(anchor.world, center, colors[mass]);
                _ = try queue.submitSprite(box(center, .{ .x = 0.22, .y = 0.2 }, colors[mass], -1));
                try self.commands.addMarker(.{ .x = center.x, .y = anchor.world.y - 0.85 }, .{ 0.4, 0.5, 0.6, 1 });
            }
            try self.commands.addMarker(root.world, text_color);
            if (index == 1) {
                const count = @min(station.history_count, 32);
                if (count > 1) {
                    const first = (station.history_next + station.history.len - count) % station.history.len;
                    for (1..count) |sample| {
                        const previous = station.history[(first + sample - 1) % station.history.len];
                        const current = station.history[(first + sample) % station.history.len];
                        for (0..hub_module.mass_count) |mass| try self.commands.addLine(
                            .{ .x = root.world.x - 1.2 + @as(f32, @floatFromInt(sample - 1)) * (2.4 / 31.0), .y = 0.5 + previous[mass] * 0.45 },
                            .{ .x = root.world.x - 1.2 + @as(f32, @floatFromInt(sample)) * (2.4 / 31.0), .y = 0.5 + current[mass] * 0.45 },
                            colors[mass],
                        );
                    }
                }
            }
        }
        const installation = &hub.impact;
        _ = try queue.submitSprite(box(installation.launcher, .{ .x = 0.28, .y = 0.18 }, .{ 0.2, 0.8, 0.85, 1 }, -1));
        _ = try queue.submitSprite(box(installation.wall_marker, .{ .x = 0.035, .y = 0.5 }, .{ 1, 0.65, 0.2, 1 }, -1));
        var readiness: [32]u8 = undefined;
        const active = installation.projectiles.count();
        try self.label(.{ .x = installation.launcher.x - 0.75, .y = installation.launcher.y - 0.25 }, try std.fmt.bufPrint(&readiness, "{s} {d}/8", .{ if (active == impact.projectile_capacity) "FULL" else "E/WEST", active }));
        const alpha: f32 = if (hub.clock.paused) 1 else @floatCast(hub.clock.last_frame.interpolation_alpha);
        for (try installation.projectiles.copySnapshots(&self.projectiles)) |value| {
            const position = try math.interpolation.lerpVec2(value.previous_position, value.position, alpha);
            const rgb = try impact.colorForTag(value.definition.tag);
            _ = try queue.submitSprite(box(position, value.definition.half_extents.scale(2), .{ rgb[0], rgb[1], rgb[2], 1 }, -1));
        }
        for (try installation.effects.extract(&self.particles, alpha)) |value| {
            // Explicit hub presentation map: one effect sprite -> neutral page.
            if (@intFromEnum(value.sprite) != 1) return error.UnknownHubEffectSprite;
            var request = box(value.position, value.size, value.color, value.layer);
            request.rotation = value.rotation;
            _ = try queue.submitSprite(request);
        }
        self.actor_queue.beginFrame();
        const submitted = try hub.actor.submitUnified(&self.actor_queue);
        const actor_frame = self.actor_queue.prepare();
        if (submitted != 15 or actor_frame.sprites.len != 15 or actor_frame.meshes.len != 0) return error.HubActorRepresentationMismatch;
        const delta = (try hub.renderedActorPosition()).sub(hub.actor.worldPosition());
        for (actor_frame.sprites) |item| {
            _ = try queue.submitSprite(.{
                .world_position = .{ item.world_position[0] + delta.x, item.world_position[1] + delta.y },
                .rotation = item.rotation,
                .scale = item.scale,
                .pivot = item.pivot,
                .uv_rect = item.uv_rect,
                .tint = item.tint,
                .texture_page = item.texture_page,
                .camera_x_factor = item.camera_x_factor,
                .order = .{ .scene_layer = item.order.scene_layer, .interaction_layer = item.order.interaction_layer, .actor_layer = item.order.actor_layer, .body_part_layer = item.order.body_part_layer },
            });
        }
        if (hub.diagnostics_enabled) {
            const controller = hub.actor.controllerSnapshot() orelse return error.HubActorHasNoController;
            try self.commands.addAabb(try collider.characterBounds(controller.state.position, controller.configuration.collider_half_extents), .{ 1, 1, 1, 1 });
        }
        const half = try hub.camera.worldHalfExtents();
        const zoom = hub.zoom.factor();
        const left = hub.camera.center.x - half.x + 0.2 * zoom;
        const top = hub.camera.center.y + half.y - 0.2 * zoom;
        self.hud_ranges[0].start = self.commands.count;
        try self.hudLabel(hub, .{ .x = left, .y = top }, "ENGINE LAB");
        try self.hudLabel(hub, .{ .x = left, .y = top - 0.24 * zoom }, "A/D ARROWS  SPACE JUMP");
        try self.hudLabel(hub, .{ .x = left, .y = top - 0.48 * zoom }, if (hub.construction == .expanded) "F1 F2 R RESET P PAUSE T STEP" else "F1 F2  R RESET  P PAUSE  T STEP");
        try self.hudLabel(hub, .{ .x = left, .y = top - 0.72 * zoom }, if (hub.construction == .expanded) "F3 INFO  ESC  SHIFT/RB DASH  F4 ZOOM" else "F3 INFO  ESC");
        self.hud_ranges[0].end = self.commands.count;
        self.hud_ranges[1].start = self.commands.count;
        var text: [128]u8 = undefined;
        const status = if (hub.clock.paused) "PAUSED" else "RUN";
        const visited = @as(u8, @intFromBool(hub.visited[0])) + @as(u8, @intFromBool(hub.visited[1]));
        const bottom = hub.camera.center.y - half.y + 0.42 * zoom;
        try self.hudLabel(hub, .{ .x = left, .y = bottom }, try std.fmt.bufPrint(&text, "{s} T{d}  {d}/2", .{ status, hub.tick, visited }));
        if (hub.diagnostics_enabled) {
            const digest = (try hub.fingerprint()).formatLowerHex();
            try self.hudLabel(hub, .{ .x = left, .y = bottom - 0.24 * zoom }, try std.fmt.bufPrint(&text, "H {s} D{d:.3}S", .{ digest[0..12], @min(hub.clock.lifetime_discarded_time, 999.999) }));
            self.hud_ranges[1].end = self.commands.count;
            try self.label(.{ .x = installation.launcher.x - 0.9, .y = 0.18 }, try std.fmt.bufPrint(&text, "L{d} C{d} D{d}", .{ @min(installation.observations.launches, 999), @min(installation.observations.contacts, 999), @min(installation.bridge.metrics.dropped_effects +| installation.effects.metrics().dropped_particles, 999) }));
        } else {
            try self.hudLabel(hub, .{ .x = left, .y = bottom - 0.24 * zoom }, "PROVISIONAL 2D ACTOR / 240 HZ");
            self.hud_ranges[1].end = self.commands.count;
        }
        try self.drawCalibration(hub);
        try self.drawTime(hub);
        for (self.commands.commands[0..self.commands.count]) |*command| command.texture_page = 1;
        _ = try self.commands.submitUnified(queue);
    }

    fn drawTime(self: *View, hub: *const hub_module.Hub) !void {
        const start = self.commands.count;
        const half = try hub.camera.worldHalfExtents();
        var buffer: [hub_module.world_time_module.label_capacity]u8 = undefined;
        const text = try hub_module.world_time_module.formatLabel(hub.world_time.snapshot(), &buffer);
        try self.hudLabel(hub, .{ .x = 0, .y = hub.camera.center.y + half.y - 0.2 * hub.zoom.factor() }, text);
        self.hud_ranges[2] = .{ .start = start, .end = self.commands.count };
        self.time_sprite_count = self.commands.count - start;
        if (self.time_sprite_count > time_sprite_allowance) return error.WorldTimePresentationAllowanceExceeded;
        // Measure the actual production glyphs; align their outer edge with the
        // existing HUD inset without duplicating font metrics or allocating.
        var right: f32 = 0;
        for (self.commands.commands[start..self.commands.count]) |command| right = @max(right, command.world_position[0] + command.scale[0] * 0.5);
        const shift = hub.camera.center.x + half.x - 0.2 * hub.zoom.factor() - right;
        for (self.commands.commands[start..self.commands.count]) |*command| command.world_position[0] += shift;
    }

    fn drawCalibration(self: *View, hub: *const hub_module.Hub) !void {
        const start = self.commands.count;
        const sample = try hub.calibration.presentation(hub.clock.last_frame.interpolation_alpha, hub.clock.paused);
        const limit = hub_module.calibration_module.profile.maximum_displacement;
        const left = sample.reference.add(.{ .x = -limit, .y = 0 });
        const right = sample.reference.add(.{ .x = limit, .y = 0 });
        const guide = [4]f32{ 0.3, 0.55, 0.65, 1 };
        try self.commands.addLine(left, right, guide);
        for ([_]math.Vec2{ left, right }) |point| try self.commands.addLine(point.add(.{ .x = 0, .y = -0.05 }), point.add(.{ .x = 0, .y = 0.05 }), guide);
        try self.commands.addLine(sample.reference, sample.response, .{ 1, 0.65, 0.2, 1 });
        // Tall white reference and orange response square remain distinct at rest.
        try self.commands.addLine(sample.reference.add(.{ .x = 0, .y = -0.1 }), sample.reference.add(.{ .x = 0, .y = 0.1 }), text_color);
        try self.commands.addAabb(.{ .minimum = sample.response.sub(.{ .x = 0.065, .y = 0.065 }), .maximum = sample.response.add(.{ .x = 0.065, .y = 0.065 }) }, .{ 1, 0.65, 0.2, 1 });
        try self.label(sample.reference.add(.{ .x = -0.12, .y = 0.23 }), "LAG");
        self.calibration_sprite_count = self.commands.count - start;
        if (self.calibration_sprite_count > calibration_sprite_allowance) return error.CalibrationPresentationAllowanceExceeded;
    }

    /// Keep camera-anchored text at its original drawable-relative size.
    fn hudLabel(self: *View, hub: *const hub_module.Hub, origin: math.Vec2, text: []const u8) !void {
        const start = self.commands.count;
        try self.label(origin, text);
        const zoom = hub.zoom.factor();
        if (zoom == 1) return;
        for (self.commands.commands[start..self.commands.count]) |*command| {
            for (0..2) |axis| {
                const base = if (axis == 0) origin.x else origin.y;
                command.world_position[axis] = base + (command.world_position[axis] - base) * zoom;
                command.scale[axis] *= zoom;
            }
        }
    }

    fn label(self: *View, origin: math.Vec2, text: []const u8) !void {
        const start = self.commands.count;
        _ = try self.commands.addLabel(origin, text, text_color);
        for (self.commands.commands[start..self.commands.count]) |*command| {
            for (0..2) |axis| {
                const base = if (axis == 0) origin.x else origin.y;
                command.world_position[axis] = base + (command.world_position[axis] - base) * 1.6;
                command.scale[axis] *= 1.6;
            }
        }
    }
};

fn box(center: math.Vec2, size: math.Vec2, tint: [4]f32, layer: i32) sprite.SpriteRequest {
    return .{ .world_position = center.toArray(), .rotation = 0, .scale = size.toArray(), .pivot = .{ 0.5, 0.5 }, .uv_rect = .{ 0, 0, 0.5, 0.5 }, .tint = tint, .texture_page = 1, .order = .{ .scene_layer = layer, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 0 } };
}
