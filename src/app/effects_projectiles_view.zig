const std = @import("std");
const math = @import("math");
const p = @import("projectiles");
const e = @import("effects");
const sprite = @import("sprite_batch");
const queue_module = @import("render_queue");
const scene_module = @import("effects_projectiles_scene");
/// This proof's four material tokens resolve to the renderer's existing four
/// procedural atlas quadrants: blue, red, green and yellow. No GPU resource is
/// owned here and no material token is interpreted by either simulation core.
pub fn request(position: math.Vec2, size: math.Vec2, rotation: f32, color: [4]f32, token: u32, layer: i16) !sprite.SpriteRequest {
    const uv: [4]f32 = switch (token) {
        1 => .{ 0, 0.5, 0.5, 1 },
        2 => .{ 0, 0, 0.5, 0.5 },
        3 => .{ 0.5, 0, 1, 0.5 },
        4 => .{ 0.5, 0.5, 1, 1 },
        else => return error.UnknownProofSprite,
    };
    return .{ .world_position = position.toArray(), .rotation = rotation, .scale = size.toArray(), .pivot = .{ 0.5, 0.5 }, .uv_rect = uv, .tint = color, .texture_page = 0, .order = .{ .scene_layer = layer, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = 0 } };
}
pub fn submit(scene: *const scene_module.Scene, queue: *queue_module.UnifiedRenderQueue, alpha: f32, debug: bool) !void {
    const tint = [4]f32{ 1, 1, 1, 1 };
    for (scene.world.colliders) |target| {
        if (target.id >= 4 and scene.ownership_projectile == null) continue;
        _ = try queue.submitSprite(try request(target.bounds.center(), target.bounds.size(), 0, .{ 0.5, 0.5, 0.5, 1 }, if (target.id == 4) 1 else if (target.id == 5) 2 else 4, -1));
    }
    // Four lane labels use compact colored bars, keeping the proof independent
    // of fonts, UI frameworks and character assets.
    for ([_]f32{ 3.6, 2.5, 1.2, 0.4 }, [_]u32{ 1, 3, 2, 4 }) |y, token| {
        _ = try queue.submitSprite(try request(.{ .x = -3.35, .y = y }, .{ .x = 0.12, .y = 0.24 }, 0, tint, token, 0));
    }
    var particles: [1500]e.RenderInstance = undefined;
    for (try scene.effects.extract(&particles, alpha)) |particle| {
        _ = try queue.submitSprite(try request(particle.position, particle.size, particle.rotation, particle.color, @intFromEnum(particle.sprite), particle.layer));
    }
    var projectiles: [32]p.Snapshot = undefined;
    for (try scene.projectiles.copySnapshots(&projectiles)) |projectile| {
        if (!projectile.enabled) continue;
        const position = try math.interpolation.lerpVec2(projectile.previous_position, projectile.position, alpha);
        _ = try queue.submitSprite(try request(position, .{ .x = 0.16, .y = 0.09 }, std.math.atan2(projectile.velocity.y, projectile.velocity.x), tint, projectile.definition.tag, 4));
        if (debug) {
            const delta = projectile.velocity.scale(0.06);
            _ = try queue.submitSprite(try request(position.add(delta.scale(0.5)), .{ .x = delta.length(), .y = 0.015 }, std.math.atan2(delta.y, delta.x), .{ 1, 1, 1, 0.55 }, 4, 5));
        }
    }
}
