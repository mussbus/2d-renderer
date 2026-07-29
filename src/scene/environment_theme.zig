const std = @import("std");
const math = @import("math");
const art_pack = @import("art_pack");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character = @import("character");
const environment_art = @import("environment_art");
const render_queue = @import("render_queue");

pub const theme_count: usize = environment_art.theme_count;
pub const maximum_surface_segments: usize = collision_world.maximum_static_colliders;
pub const environment_renderer_offset: u32 = 7;
pub const expected_standable_surface_count: usize = 6;
pub const distant_camera_x_factor: f32 = 0.12;
pub const midground_camera_x_factor: f32 = 0.46;
pub const gameplay_camera_x_factor: f32 = 1.0;
pub const foreground_camera_x_factor: f32 = 1.0;
pub const surface_scene_layer: i32 = character.SceneLayers.world + 500;

pub const ThemeInput = struct {
    id: environment_art.ThemeId,
    stable_name: []const u8,
    far_tint: [4]f32,
    mid_tint: [4]f32,
    terrain_tint: [4]f32,
    foreground_tint: [4]f32,
    decorative_tint: [4]f32,
    accent_tint: [4]f32,
    surface_tint: [4]f32,
};

pub const theme_inputs = [_]ThemeInput{
    .{
        .id = .violet_crystal_ruin,
        .stable_name = "violet_crystal_ruin",
        .far_tint = .{ 0.64, 0.56, 0.86, 1 },
        .mid_tint = .{ 0.80, 0.72, 1.0, 0.92 },
        .terrain_tint = .{ 0.82, 0.75, 0.98, 1 },
        .foreground_tint = .{ 0.54, 0.46, 0.72, 0.82 },
        .decorative_tint = .{ 0.86, 0.76, 1.0, 0.92 },
        .accent_tint = .{ 1.0, 0.86, 1.0, 0.86 },
        .surface_tint = .{ 1, 1, 1, 1 },
    },
    .{
        .id = .neutral_debug,
        .stable_name = "neutral_debug",
        .far_tint = .{ 0.74, 0.80, 0.88, 1 },
        .mid_tint = .{ 0.74, 0.84, 0.90, 0.88 },
        .terrain_tint = .{ 0.82, 0.86, 0.90, 1 },
        .foreground_tint = .{ 0.60, 0.68, 0.74, 0.72 },
        .decorative_tint = .{ 0.78, 0.86, 0.90, 0.90 },
        .accent_tint = .{ 1.0, 1.0, 1.0, 0.92 },
        .surface_tint = .{ 1, 1, 1, 1 },
    },
};

pub const ResolvedTheme = struct {
    id: environment_art.ThemeId,
    stable_name: art_pack.StableName,
    visuals: [environment_art.visual_count]art_pack.ResolvedVisual,
    tints: [environment_art.visual_count][4]f32,

    pub fn visual(theme: *const ResolvedTheme, role: environment_art.VisualRole) art_pack.ResolvedVisual {
        return theme.visuals[@intFromEnum(role)];
    }

    pub fn tint(theme: *const ResolvedTheme, role: environment_art.VisualRole) [4]f32 {
        return theme.tints[@intFromEnum(role)];
    }
};

pub const Catalog = struct {
    themes: [theme_count]ResolvedTheme,

    pub fn init(
        definition: *const environment_art.Definition,
        inputs: []const ThemeInput,
        renderer_offset: u32,
    ) !Catalog {
        if (inputs.len != theme_count) return error.EnvironmentThemeCountMismatch;
        var seen = [_]bool{false} ** theme_count;
        var themes: [theme_count]ResolvedTheme = undefined;
        for (inputs) |input| {
            const index: usize = @intFromEnum(input.id);
            if (seen[index]) return error.DuplicateEnvironmentTheme;
            seen[index] = true;
            var visuals: [environment_art.visual_count]art_pack.ResolvedVisual = undefined;
            for (std.enums.values(environment_art.VisualRole)) |role| {
                var visual = try definition.resolve(input.id, role);
                visual.texture_page = std.math.add(u32, visual.texture_page, renderer_offset) catch
                    return error.EnvironmentTexturePageOverflow;
                visuals[@intFromEnum(role)] = visual;
            }
            themes[index] = .{
                .id = input.id,
                .stable_name = try art_pack.StableName.init(input.stable_name),
                .visuals = visuals,
                .tints = .{
                    input.far_tint,
                    input.mid_tint,
                    input.terrain_tint,
                    input.foreground_tint,
                    input.decorative_tint,
                    input.accent_tint,
                    input.surface_tint,
                },
            };
        }
        for (seen) |present| if (!present) return error.MissingEnvironmentTheme;
        return .{ .themes = themes };
    }

    pub fn theme(catalog: *const Catalog, id: environment_art.ThemeId) *const ResolvedTheme {
        return &catalog.themes[@intFromEnum(id)];
    }
};

pub const SurfaceSegment = extern struct {
    collider_id: collider.ColliderId,
    minimum_x: f32,
    maximum_x: f32,
    y: f32,
};

pub const SurfaceOverlay = struct {
    segments: [maximum_surface_segments]SurfaceSegment = undefined,
    count: usize = 0,

    pub fn init(world: *const collision_world.CollisionWorld) !SurfaceOverlay {
        var overlay = SurfaceOverlay{};
        for (world.colliders) |static_collider| {
            if (!static_collider.solid or !static_collider.ground_query_eligible) continue;
            if (overlay.count >= overlay.segments.len) return error.SurfaceOverlayCapacityExceeded;
            const bounds = static_collider.bounds;
            overlay.segments[overlay.count] = .{
                .collider_id = static_collider.id,
                .minimum_x = bounds.minimum.x,
                .maximum_x = bounds.maximum.x,
                .y = bounds.maximum.y,
            };
            overlay.count += 1;
        }
        if (overlay.count == 0) return error.MissingStandableSurfaces;
        return overlay;
    }

    pub fn slice(overlay: *const SurfaceOverlay) []const SurfaceSegment {
        return overlay.segments[0..overlay.count];
    }

    pub fn validateAgainst(
        overlay: *const SurfaceOverlay,
        world: *const collision_world.CollisionWorld,
    ) !void {
        var expected = try SurfaceOverlay.init(world);
        if (expected.count != overlay.count) return error.SurfaceOverlayCountDrift;
        for (overlay.slice(), expected.slice()) |actual, wanted| {
            if (actual.collider_id != wanted.collider_id or
                actual.minimum_x != wanted.minimum_x or
                actual.maximum_x != wanted.maximum_x or
                actual.y != wanted.y)
            {
                return error.SurfaceOverlayCoordinateDrift;
            }
        }
    }

    pub fn fingerprint(overlay: *const SurfaceOverlay) u64 {
        var hash = std.hash.Fnv1a_64.init();
        for (overlay.slice()) |segment| {
            hash.update(std.mem.asBytes(&segment.collider_id));
            hash.update(std.mem.asBytes(&segment.minimum_x));
            hash.update(std.mem.asBytes(&segment.maximum_x));
            hash.update(std.mem.asBytes(&segment.y));
        }
        return hash.final();
    }
};

pub const ParallaxRole = enum(u8) {
    far,
    midground,
    gameplay,
};

pub const ParallaxAnchor = struct {
    role: ParallaxRole,
    world: math.Vec2,
    camera_x_factor: f32,
};

pub const ParallaxTrace = struct {
    anchors: [3]ParallaxAnchor = undefined,
    present: [3]bool = [_]bool{false} ** 3,

    pub fn begin(trace: *ParallaxTrace) void {
        trace.present = [_]bool{false} ** trace.present.len;
    }

    pub fn record(trace: *ParallaxTrace, anchor: ParallaxAnchor) !void {
        const index: usize = @intFromEnum(anchor.role);
        if (trace.present[index]) return error.DuplicateParallaxAnchor;
        if (!anchor.world.isFinite()) return error.NonFiniteParallaxAnchor;
        try @import("camera2d").validateCameraXFactor(anchor.camera_x_factor);
        trace.anchors[index] = anchor;
        trace.present[index] = true;
    }

    pub fn validateComplete(trace: *const ParallaxTrace) !void {
        for (trace.present) |present| {
            if (!present) return error.MissingParallaxAnchor;
        }
    }
};

pub const Presentation = struct {
    catalog: Catalog,
    surfaces: SurfaceOverlay,
    active_theme: environment_art.ThemeId = .violet_crystal_ruin,
    switch_count: u32 = 0,

    pub fn init(
        definition: *const environment_art.Definition,
        world: *const collision_world.CollisionWorld,
    ) !Presentation {
        try definition.validateComplete();
        return .{
            .catalog = try Catalog.init(definition, &theme_inputs, environment_renderer_offset),
            .surfaces = try SurfaceOverlay.init(world),
        };
    }

    pub fn cycle(presentation: *Presentation) !void {
        presentation.active_theme = presentation.active_theme.next();
        presentation.switch_count = std.math.add(u32, presentation.switch_count, 1) catch
            return error.EnvironmentThemeSwitchCountOverflow;
    }

    pub fn reset(presentation: *Presentation) void {
        presentation.active_theme = .violet_crystal_ruin;
    }

    pub fn submit(
        presentation: *const Presentation,
        world: *const collision_world.CollisionWorld,
        queue: *render_queue.UnifiedRenderQueue,
    ) !u32 {
        return presentation.submitTraced(world, queue, null);
    }

    pub fn submitTraced(
        presentation: *const Presentation,
        world: *const collision_world.CollisionWorld,
        queue: *render_queue.UnifiedRenderQueue,
        parallax_trace: ?*ParallaxTrace,
    ) !u32 {
        try presentation.surfaces.validateAgainst(world);
        const theme = presentation.catalog.theme(presentation.active_theme);
        var submitted: u32 = 0;

        const far = theme.visual(.far_backdrop);
        for ([_]f32{ -48, -24, 0, 24, 48 }) |x| {
            try submitVisual(queue, far, .{ x, 4.4 }, far.authored_size, theme.tint(.far_backdrop), character.SceneLayers.background, distant_camera_x_factor, submitted);
            if (x == 0) {
                if (parallax_trace) |trace| {
                    try trace.record(.{
                        .role = .far,
                        .world = .{ .x = x, .y = 4.4 },
                        .camera_x_factor = distant_camera_x_factor,
                    });
                }
            }
            submitted += 1;
        }

        const mid = theme.visual(.midground_structure);
        for ([_]f32{ -36, -24, -12, 0, 12, 24, 36 }) |x| {
            try submitVisual(queue, mid, .{ x, 2.55 }, mid.authored_size, theme.tint(.midground_structure), character.SceneLayers.midground, midground_camera_x_factor, submitted);
            if (x == 0) {
                if (parallax_trace) |trace| {
                    try trace.record(.{
                        .role = .midground,
                        .world = .{ .x = x, .y = 2.55 },
                        .camera_x_factor = midground_camera_x_factor,
                    });
                }
            }
            submitted += 1;
        }

        const terrain = theme.visual(.terrain_body);
        for (world.colliders) |static_collider| {
            const bounds = static_collider.bounds;
            const width = bounds.maximum.x - bounds.minimum.x;
            const authored_height = @max(bounds.maximum.y - bounds.minimum.y, @as(f32, 0.62));
            try submitVisual(
                queue,
                terrain,
                .{ (bounds.minimum.x + bounds.maximum.x) * 0.5, bounds.maximum.y - authored_height * 0.5 },
                .{ width, authored_height },
                theme.tint(.terrain_body),
                character.SceneLayers.world,
                gameplay_camera_x_factor,
                submitted,
            );
            if (static_collider.id == 1) {
                if (parallax_trace) |trace| {
                    try trace.record(.{
                        .role = .gameplay,
                        .world = .{
                            .x = (bounds.minimum.x + bounds.maximum.x) * 0.5,
                            .y = bounds.maximum.y - authored_height * 0.5,
                        },
                        .camera_x_factor = gameplay_camera_x_factor,
                    });
                }
            }
            submitted += 1;
        }

        const decorative = theme.visual(.decorative_ledge);
        for ([_][2]f32{ .{ -18.5, 4.7 }, .{ 2.0, 5.0 }, .{ 20.5, 4.3 } }) |position| {
            try submitVisual(queue, decorative, position, decorative.authored_size, theme.tint(.decorative_ledge), character.SceneLayers.world + 50, gameplay_camera_x_factor, submitted);
            submitted += 1;
        }

        const accent = theme.visual(.accent_cluster);
        for ([_][2]f32{ .{ -29.0, 3.1 }, .{ 11.8, 3.7 }, .{ 29.0, 3.0 } }) |position| {
            try submitVisual(queue, accent, position, .{ 3.2, 3.2 }, theme.tint(.accent_cluster), character.SceneLayers.midground + 100, midground_camera_x_factor, submitted);
            submitted += 1;
        }

        for (presentation.surfaces.slice()) |surface| {
            const surface_visual = theme.visual(.surface_white);
            const width = surface.maximum_x - surface.minimum_x;
            _ = try queue.submitSprite(.{
                .world_position = .{ (surface.minimum_x + surface.maximum_x) * 0.5, surface.y + 0.018 },
                .rotation = 0,
                .scale = .{ width, 0.045 },
                .pivot = .{ 0.5, 0.5 },
                .uv_rect = surface_visual.uv_rect,
                .tint = theme.tint(.surface_white),
                .texture_page = surface_visual.texture_page,
                .camera_x_factor = gameplay_camera_x_factor,
                .order = .{
                    .scene_layer = surface_scene_layer,
                    .interaction_layer = 0,
                    .actor_layer = 0,
                    .body_part_layer = @intCast(submitted),
                },
            });
            submitted += 1;
        }

        const foreground = theme.visual(.foreground_frame);
        for ([_]f32{ -36, -12, 12, 36 }) |x| {
            try submitVisual(queue, foreground, .{ x, 1.9 }, foreground.authored_size, theme.tint(.foreground_frame), character.SceneLayers.foreground, foreground_camera_x_factor, submitted);
            submitted += 1;
        }
        if (parallax_trace) |trace| try trace.validateComplete();
        return submitted;
    }
};

pub fn collisionFingerprint(world: *const collision_world.CollisionWorld) u64 {
    var hash = std.hash.Fnv1a_64.init();
    for (world.colliders) |static_collider| {
        hash.update(std.mem.asBytes(&static_collider.id));
        hash.update(std.mem.asBytes(&static_collider.bounds.minimum.x));
        hash.update(std.mem.asBytes(&static_collider.bounds.minimum.y));
        hash.update(std.mem.asBytes(&static_collider.bounds.maximum.x));
        hash.update(std.mem.asBytes(&static_collider.bounds.maximum.y));
        hash.update(std.mem.asBytes(&static_collider.solid));
        hash.update(std.mem.asBytes(&static_collider.ground_query_eligible));
    }
    return hash.final();
}

fn submitVisual(
    queue: *render_queue.UnifiedRenderQueue,
    visual: art_pack.ResolvedVisual,
    position: [2]f32,
    scale: [2]f32,
    tint: [4]f32,
    scene_layer: i32,
    camera_x_factor: f32,
    body_part_layer: u32,
) !void {
    _ = try queue.submitSprite(.{
        .world_position = position,
        .rotation = 0,
        .scale = scale,
        .pivot = visual.pivot,
        .uv_rect = visual.uv_rect,
        .tint = tint,
        .texture_page = visual.texture_page,
        .camera_x_factor = camera_x_factor,
        .order = .{
            .scene_layer = scene_layer,
            .interaction_layer = 0,
            .actor_layer = 0,
            .body_part_layer = @intCast(body_part_layer),
        },
    });
}

comptime {
    if (environment_renderer_offset + environment_art.texture_page_count > 9) {
        @compileError("Prompt 26 environment art exceeds the preloaded global texture-page budget");
    }
}
