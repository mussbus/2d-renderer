const std = @import("std");
const labs = @import("engine_lab");
const debug = @import("debug_draw");
const math = @import("math");
const sprite = @import("sprite_batch");
const queue_module = @import("render_queue");

const colors = [labs.mass_count][4]f32{
    .{ 0.25, 0.85, 1, 1 },
    .{ 1, 0.65, 0.2, 1 },
    .{ 0.85, 0.4, 1, 1 },
};
const text_color = [4]f32{ 0.85, 0.93, 1, 1 };

pub const View = struct {
    commands: debug.CommandBuffer = .{},
    texture_page: u32 = 1,

    pub fn render(self: *View, host: *const labs.Host, queue: *queue_module.UnifiedRenderQueue) !void {
        const active = host.active orelse return error.NoActiveLab;
        self.commands.beginFrame();
        queue.beginFrame();
        // Paused states display exact current positions, including the final tick.
        const offsets = if (host.clock.paused) blk: {
            var values: [labs.mass_count]f32 = undefined;
            for (active.springs, 0..) |state, index| values[index] = state.offset;
            break :blk values;
        } else try active.offsets(host.clock.last_frame.interpolation_alpha);
        try self.label(.{ .x = -3.6, .y = 4.3 }, active.definition().name);
        try self.label(.{ .x = -3.6, .y = 4.07 }, "F1 OVERVIEW  F2 FIXED STEP");
        try self.label(.{ .x = -3.6, .y = 3.84 }, "R RESET  P PLAY/PAUSE  T STEP");
        try self.label(.{ .x = -3.6, .y = 3.61 }, if (active.definition().kind == .integration)
            "SPACE IMPULSE  ESC EXIT"
        else
            "960 TICKS / RUN  ESC EXIT");

        for (active.anchors.anchors, offsets, 0..) |anchor, offset, index| {
            try self.commands.addLine(active.anchors.root.world, anchor.world, .{ 0.3, 0.4, 0.55, 1 });
            try self.commands.addMarker(anchor.world, text_color);
            const center = math.Vec2{ .x = anchor.world.x, .y = anchor.world.y - 1.0 + offset };
            try self.commands.addLine(anchor.world, center, colors[index]);
            var mass_sprite = box(center, .{ .x = 0.32, .y = 0.25 }, colors[index]);
            mass_sprite.texture_page = self.texture_page;
            _ = try queue.submitSprite(mass_sprite);
            try self.commands.addMarker(.{ .x = center.x, .y = anchor.world.y - 1.0 }, .{ 0.45, 0.5, 0.6, 1 });
        }
        try self.commands.addMarker(active.anchors.root.world, text_color);

        if (active.definition().kind == .determinism) {
            // Last 64 samples, chronological ring traversal, presentation only.
            const count = @min(active.history_count, 64);
            try self.commands.addLine(.{ .x = -3, .y = 0.25 }, .{ .x = 3, .y = 0.25 }, .{ 0.3, 0.4, 0.55, 1 });
            if (count > 1) {
                const first = (active.history_next + active.history.len - count) % active.history.len;
                for (1..count) |sample| {
                    const previous = active.history[(first + sample - 1) % active.history.len];
                    const current = active.history[(first + sample) % active.history.len];
                    for (0..labs.mass_count) |mass| {
                        try self.commands.addLine(
                            .{ .x = -3 + @as(f32, @floatFromInt(sample - 1)) * (6.0 / 63.0), .y = 0.25 + previous[mass] * 0.7 },
                            .{ .x = -3 + @as(f32, @floatFromInt(sample)) * (6.0 / 63.0), .y = 0.25 + current[mass] * 0.7 },
                            colors[mass],
                        );
                    }
                }
            }
        }
        var text: [128]u8 = undefined;
        const status = if (active.complete()) "COMPLETE" else if (host.clock.paused) "PAUSED" else "RUNNING";
        try self.label(.{ .x = -3.6, .y = -0.45 }, try std.fmt.bufPrint(&text, "{s}  TICK {d}  240 HZ", .{ status, active.tick }));
        const checkpoint = active.checkpoints[active.checkpoint_count - 1];
        const digest = checkpoint.digest.formatLowerHex();
        try self.label(.{ .x = -3.6, .y = -0.69 }, try std.fmt.bufPrint(&text, "CP {d} HASH {s}", .{ checkpoint.tick, digest[0..16] }));
        try self.label(.{ .x = -3.6, .y = -0.93 }, try std.fmt.bufPrint(&text, "STEPS {d} DROP {d:.3}S", .{ host.clock.last_frame.substeps, host.clock.lifetime_discarded_time }));
        for (self.commands.commands[0..self.commands.count]) |*command| command.texture_page = self.texture_page;
        _ = try self.commands.submitUnified(queue);
    }

    fn label(self: *View, origin: math.Vec2, text: []const u8) !void {
        const start = self.commands.count;
        _ = try self.commands.addLabel(origin, text, text_color);
        // Enlarge the existing production diagnostic glyph geometry for a 640px window.
        for (self.commands.commands[start..self.commands.count]) |*command| {
            for (0..2) |axis| {
                const origin_axis = if (axis == 0) origin.x else origin.y;
                command.world_position[axis] = origin_axis + (command.world_position[axis] - origin_axis) * 1.6;
                command.scale[axis] *= 1.6;
            }
        }
    }
};

fn box(center: math.Vec2, size: math.Vec2, tint: [4]f32) sprite.SpriteRequest {
    return .{
        .world_position = center.toArray(),
        .rotation = 0,
        .scale = size.toArray(),
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 0.5, 0.5 },
        .tint = tint,
        .texture_page = 0,
        .order = .{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 0 },
    };
}
