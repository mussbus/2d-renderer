const std = @import("std");
const hub_module = @import("engine_lab");
const debug = @import("debug_draw");
const math = @import("math");
const sprite = @import("sprite_batch");
const queue_module = @import("render_queue");
const fixed_step = @import("fixed_step");
const collider = @import("collider");
const impact = hub_module.impact_module;

const colors = [hub_module.mass_count][4]f32{ .{ 0.25, 0.85, 1, 1 }, .{ 1, 0.65, 0.2, 1 }, .{ 0.85, 0.4, 1, 1 } };
const text_color = [4]f32{ 0.85, 0.93, 1, 1 };

pub const View = struct {
    commands: debug.CommandBuffer = .{},
    actor_queue: queue_module.UnifiedRenderQueue,
    particles: [impact.particle_capacity]impact.e.RenderInstance = undefined,
    projectiles: [1]impact.p.Snapshot = undefined,

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
        for (hub_module.collider_inputs, 0..) |item, index| {
            _ = try queue.submitSprite(box(item.bounds.center(), item.bounds.size(), if (index == 3) .{ 0.27, 0.37, 0.47, 1 } else .{ 0.12, 0.19, 0.27, 1 }, -10));
            if (hub.diagnostics_enabled) try self.commands.addAabb(item.bounds, .{ 0.5, 0.75, 0.9, 1 });
        }
        for (0..15) |mark| {
            const x = @as(f32, @floatFromInt(mark)) - 7;
            _ = try queue.submitSprite(box(.{ .x = x, .y = -0.07 }, .{ .x = 0.06, .y = 0.1 }, .{ 0.4, 0.6, 0.7, 1 }, -9));
        }
        for (hub.stations, hub.installations.roots, hub.installations.anchors, 0..) |station, root, anchors, index| {
            try self.label(.{ .x = root.world.x - 1.05, .y = 3.55 }, if (index == 0) "F1 HIERARCHY" else "F2 DAMPING");
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
        try self.label(.{ .x = installation.launcher.x - 0.75, .y = installation.launcher.y - 0.25 }, if (installation.projectiles.count() != 0) "IN FLIGHT" else "READY E/WEST");
        const alpha: f32 = if (hub.clock.paused) 1 else @floatCast(hub.clock.last_frame.interpolation_alpha);
        for (try installation.projectiles.copySnapshots(&self.projectiles)) |value| {
            const position = try math.interpolation.lerpVec2(value.previous_position, value.position, alpha);
            _ = try queue.submitSprite(box(position, value.definition.half_extents.scale(2), .{ 1, 0.9, 0.3, 1 }, -1));
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
        const left = hub.camera.center.x - half.x + 0.2;
        const top = hub.camera.center.y + half.y - 0.2;
        try self.label(.{ .x = left, .y = top }, "ENGINE LAB");
        try self.label(.{ .x = left, .y = top - 0.24 }, "A D / ARROWS MOVE  SPACE JUMP");
        try self.label(.{ .x = left, .y = top - 0.48 }, "F1 F2 TRAVEL  R RESET  P PAUSE  T STEP");
        try self.label(.{ .x = left, .y = top - 0.72 }, "F3 INFO  ESC EXIT");
        var text: [128]u8 = undefined;
        const status = if (hub.clock.paused) "PAUSED" else "RUNNING";
        const visited = @as(u8, @intFromBool(hub.visited[0])) + @as(u8, @intFromBool(hub.visited[1]));
        const bottom = hub.camera.center.y - half.y + 0.42;
        try self.label(.{ .x = left, .y = bottom }, try std.fmt.bufPrint(&text, "{s}  TICK {d}  STATIONS {d}/2", .{ status, hub.tick, visited }));
        if (hub.diagnostics_enabled) {
            const digest = (try hub.fingerprint()).formatLowerHex();
            try self.label(.{ .x = left, .y = bottom - 0.24 }, try std.fmt.bufPrint(&text, "HASH {s} DROP {d:.3}S", .{ digest[0..12], hub.clock.lifetime_discarded_time }));
            try self.label(.{ .x = installation.launcher.x - 0.9, .y = 0.18 }, try std.fmt.bufPrint(&text, "L{d} C{d} D{d}", .{ @min(installation.observations.launches, 999), @min(installation.observations.contacts, 999), @min(installation.bridge.metrics.dropped_effects +| installation.effects.metrics().dropped_particles, 999) }));
        } else try self.label(.{ .x = left, .y = bottom - 0.24 }, "PROVISIONAL 2D ACTOR / 240 HZ");
        for (self.commands.commands[0..self.commands.count]) |*command| command.texture_page = 1;
        _ = try self.commands.submitUnified(queue);
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
