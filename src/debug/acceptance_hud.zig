const std = @import("std");
const math = @import("math");
const camera2d = @import("camera2d");
const character = @import("character");
const sprite = @import("sprite_batch");
const render_queue = @import("render_queue");
const foundation_evidence = @import("foundation_evidence");

pub const maximum_hud_sprites: u32 = 1_500;
const glyph_columns: u32 = 3;
const glyph_rows: u32 = 5;
const pixel_size: f32 = 1.5;
const glyph_advance: f32 = 5;
const line_advance: f32 = 10;
const origin_padding: f32 = 8;

pub fn submit(
    queue: *render_queue.UnifiedRenderQueue,
    camera: camera2d.Camera2D,
    observation: foundation_evidence.Observation,
    target: ?foundation_evidence.CaptureId,
) !u32 {
    try observation.validate();
    const half = try camera.worldHalfExtents();
    const origin = math.Vec2{
        .x = camera.center.x - half.x + origin_padding / camera.pixels_per_meter,
        .y = camera.center.y + half.y - origin_padding / camera.pixels_per_meter,
    };
    var submitted: u32 = 0;
    _ = try queue.submitSprite(.{
        .world_position = .{
            origin.x + 218 / camera.pixels_per_meter,
            origin.y - 34 / camera.pixels_per_meter,
        },
        .rotation = 0,
        .scale = .{
            436 / camera.pixels_per_meter,
            76 / camera.pixels_per_meter,
        },
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 1, 1 },
        .tint = .{ 0.01, 0.015, 0.03, 0.82 },
        .texture_page = 0,
        .order = hudOrder(submitted),
    });
    submitted += 1;

    var line_0: [64]u8 = undefined;
    var line_1: [64]u8 = undefined;
    var line_2: [64]u8 = undefined;
    var line_3: [64]u8 = undefined;
    var line_4: [64]u8 = undefined;
    var line_5: [96]u8 = undefined;
    const phase = try std.fmt.bufPrint(&line_0, "PH {s}", .{
        clipped(@tagName(observation.stage), 42),
    });
    const capture = try std.fmt.bufPrint(&line_1, "CAP {s}", .{
        if (target) |id| clipped(@tagName(id), 38) else "COMPLETE",
    });
    const state = try std.fmt.bufPrint(
        &line_2,
        "FACE {s} VIEW {s} G {d} SUP {s}",
        .{
            if (observation.facing == .left) "L" else "R",
            if (observation.view == .front) "FRONT" else "SIDE",
            @intFromBool(observation.grounded),
            if (observation.supporting_collider) |support|
                try decimal(&line_4, support)
            else
                "NONE",
        },
    );
    const outfit = try std.fmt.bufPrint(&line_3, "OUT {s}", .{
        clipped(observation.outfit, 42),
    });
    const theme = try std.fmt.bufPrint(&line_4, "THEME {s}", .{
        clipped(observation.theme, 38),
    });
    const interaction = try std.fmt.bufPrint(
        &line_5,
        "VEL {d:.2}/{d:.2} INT {s}/{s} DBG {d}",
        .{
            observation.velocity[0],
            observation.velocity[1],
            clipped(@tagName(observation.interaction_lifecycle), 12),
            clipped(@tagName(observation.interaction_phase), 12),
            observation.debug_counts.total(),
        },
    );
    const lines = [_][]const u8{ phase, capture, state, outfit, theme, interaction };
    for (lines, 0..) |line, line_index| {
        submitted += try submitLine(
            queue,
            camera,
            origin,
            @intCast(line_index),
            line,
            submitted,
        );
    }
    if (submitted > maximum_hud_sprites) return error.AcceptanceHudCapacityExceeded;
    return submitted;
}

fn submitLine(
    queue: *render_queue.UnifiedRenderQueue,
    camera: camera2d.Camera2D,
    origin: math.Vec2,
    line_index: u32,
    text: []const u8,
    first_order: u32,
) !u32 {
    var submitted: u32 = 0;
    for (text, 0..) |raw, character_index| {
        const glyph = glyphBits(toUpper(raw));
        for (0..glyph_rows) |row| {
            for (0..glyph_columns) |column| {
                const bit: u4 = @intCast(row * glyph_columns + column);
                if (glyph & (@as(u16, 1) << bit) == 0) continue;
                const x_pixels =
                    @as(f32, @floatFromInt(character_index)) * glyph_advance +
                    @as(f32, @floatFromInt(column)) * pixel_size;
                const y_pixels =
                    @as(f32, @floatFromInt(line_index)) * line_advance +
                    @as(f32, @floatFromInt(row)) * pixel_size;
                _ = try queue.submitSprite(.{
                    .world_position = .{
                        origin.x + x_pixels / camera.pixels_per_meter,
                        origin.y - y_pixels / camera.pixels_per_meter,
                    },
                    .rotation = 0,
                    .scale = .{
                        pixel_size / camera.pixels_per_meter,
                        pixel_size / camera.pixels_per_meter,
                    },
                    .pivot = .{ 0.5, 0.5 },
                    .uv_rect = .{ 0, 0, 1, 1 },
                    .tint = .{ 0.86, 0.96, 1.0, 0.96 },
                    .texture_page = 0,
                    .order = hudOrder(first_order + submitted),
                });
                submitted += 1;
            }
        }
    }
    return submitted;
}

fn hudOrder(index: u32) sprite.OrderInput {
    return .{
        .scene_layer = character.SceneLayers.debug_overlay,
        .interaction_layer = 1,
        .actor_layer = 65_000,
        .body_part_layer = @intCast(index),
    };
}

fn clipped(value: []const u8, maximum: usize) []const u8 {
    return value[0..@min(value.len, maximum)];
}

fn decimal(buffer: []u8, value: u32) ![]const u8 {
    return std.fmt.bufPrint(buffer, "{d}", .{value});
}

fn toUpper(value: u8) u8 {
    return if (value >= 'a' and value <= 'z') value - ('a' - 'A') else value;
}

fn rows(a: u3, b: u3, c: u3, d: u3, e: u3) u16 {
    return @as(u16, a) |
        (@as(u16, b) << 3) |
        (@as(u16, c) << 6) |
        (@as(u16, d) << 9) |
        (@as(u16, e) << 12);
}

fn glyphBits(value: u8) u16 {
    return switch (value) {
        'A' => rows(0b010, 0b101, 0b111, 0b101, 0b101),
        'B' => rows(0b110, 0b101, 0b110, 0b101, 0b110),
        'C' => rows(0b011, 0b100, 0b100, 0b100, 0b011),
        'D' => rows(0b110, 0b101, 0b101, 0b101, 0b110),
        'E' => rows(0b111, 0b100, 0b110, 0b100, 0b111),
        'F' => rows(0b111, 0b100, 0b110, 0b100, 0b100),
        'G' => rows(0b011, 0b100, 0b101, 0b101, 0b011),
        'H' => rows(0b101, 0b101, 0b111, 0b101, 0b101),
        'I' => rows(0b111, 0b010, 0b010, 0b010, 0b111),
        'J' => rows(0b001, 0b001, 0b001, 0b101, 0b010),
        'K' => rows(0b101, 0b101, 0b110, 0b101, 0b101),
        'L' => rows(0b100, 0b100, 0b100, 0b100, 0b111),
        'M' => rows(0b101, 0b111, 0b111, 0b101, 0b101),
        'N' => rows(0b101, 0b111, 0b111, 0b111, 0b101),
        'O' => rows(0b010, 0b101, 0b101, 0b101, 0b010),
        'P' => rows(0b110, 0b101, 0b110, 0b100, 0b100),
        'Q' => rows(0b010, 0b101, 0b101, 0b111, 0b011),
        'R' => rows(0b110, 0b101, 0b110, 0b101, 0b101),
        'S' => rows(0b011, 0b100, 0b010, 0b001, 0b110),
        'T' => rows(0b111, 0b010, 0b010, 0b010, 0b010),
        'U' => rows(0b101, 0b101, 0b101, 0b101, 0b111),
        'V' => rows(0b101, 0b101, 0b101, 0b101, 0b010),
        'W' => rows(0b101, 0b101, 0b111, 0b111, 0b101),
        'X' => rows(0b101, 0b101, 0b010, 0b101, 0b101),
        'Y' => rows(0b101, 0b101, 0b010, 0b010, 0b010),
        'Z' => rows(0b111, 0b001, 0b010, 0b100, 0b111),
        '0' => rows(0b111, 0b101, 0b101, 0b101, 0b111),
        '1' => rows(0b010, 0b110, 0b010, 0b010, 0b111),
        '2' => rows(0b110, 0b001, 0b010, 0b100, 0b111),
        '3' => rows(0b110, 0b001, 0b010, 0b001, 0b110),
        '4' => rows(0b101, 0b101, 0b111, 0b001, 0b001),
        '5' => rows(0b111, 0b100, 0b110, 0b001, 0b110),
        '6' => rows(0b011, 0b100, 0b111, 0b101, 0b111),
        '7' => rows(0b111, 0b001, 0b010, 0b010, 0b010),
        '8' => rows(0b111, 0b101, 0b111, 0b101, 0b111),
        '9' => rows(0b111, 0b101, 0b111, 0b001, 0b110),
        '-' => rows(0, 0, 0b111, 0, 0),
        '+' => rows(0, 0b010, 0b111, 0b010, 0),
        '.' => rows(0, 0, 0, 0, 0b010),
        '/' => rows(0b001, 0b001, 0b010, 0b100, 0b100),
        ':' => rows(0, 0b010, 0, 0b010, 0),
        '_', ' ' => 0,
        else => rows(0b111, 0b001, 0b010, 0, 0b010),
    };
}
