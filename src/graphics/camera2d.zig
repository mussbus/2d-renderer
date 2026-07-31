const std = @import("std");
const math = @import("math");

pub const reference_drawable_width: u32 = 640;
pub const reference_drawable_height: u32 = 480;
pub const reference_pixels_per_meter: f32 = 82.0;
pub const reference_vertical_world_span: f32 =
    @as(f32, @floatFromInt(reference_drawable_height)) / reference_pixels_per_meter;

pub const default_viewport_width: u32 = reference_drawable_width;
pub const default_viewport_height: u32 = reference_drawable_height;
pub const default_pixels_per_meter: f32 = reference_pixels_per_meter;
pub const default_center = math.Vec2{
    .x = 0,
    .y = (default_viewport_height / 2 - 105) / default_pixels_per_meter,
};

pub const CameraUniform = extern struct {
    center: [2]f32,
    clip_scale: [2]f32,
};

pub const Camera2D = struct {
    center: math.Vec2,
    viewport_width: u32,
    viewport_height: u32,
    pixels_per_meter: f32,

    pub fn init(center: math.Vec2, viewport_width: u32, viewport_height: u32, pixels_per_meter: f32) !Camera2D {
        const camera = Camera2D{
            .center = center,
            .viewport_width = viewport_width,
            .viewport_height = viewport_height,
            .pixels_per_meter = pixels_per_meter,
        };
        try camera.validate();
        return camera;
    }

    pub fn initDefault() Camera2D {
        return .{
            .center = default_center,
            .viewport_width = default_viewport_width,
            .viewport_height = default_viewport_height,
            .pixels_per_meter = default_pixels_per_meter,
        };
    }

    pub fn validate(camera: Camera2D) !void {
        if (!camera.center.isFinite()) return error.NonFiniteCameraCenter;
        if (camera.viewport_width == 0 or camera.viewport_height == 0) return error.ZeroViewport;
        if (!std.math.isFinite(camera.pixels_per_meter) or camera.pixels_per_meter <= 0) {
            return error.InvalidPixelsPerMeter;
        }
    }

    pub fn setCenter(camera: *Camera2D, center: math.Vec2) !void {
        if (!center.isFinite()) return error.NonFiniteCameraCenter;
        camera.center = center;
    }

    pub fn setViewport(camera: *Camera2D, width: u32, height: u32) !void {
        if (width == 0 or height == 0) return error.ZeroViewport;
        const pixels_per_meter = try pixelsPerMeterForDrawableHeight(height);
        camera.viewport_width = width;
        camera.viewport_height = height;
        camera.pixels_per_meter = pixels_per_meter;
    }

    pub fn setPixelsPerMeter(camera: *Camera2D, pixels_per_meter: f32) !void {
        if (!std.math.isFinite(pixels_per_meter) or pixels_per_meter <= 0) return error.InvalidPixelsPerMeter;
        camera.pixels_per_meter = pixels_per_meter;
    }

    pub fn worldToPresentation(camera: Camera2D, world: math.Vec2, camera_x_factor: f32) !math.Vec2 {
        try camera.validate();
        try validateCameraXFactor(camera_x_factor);
        if (!world.isFinite()) return error.NonFiniteWorldPosition;
        const half_width: f32 = @as(f32, @floatFromInt(camera.viewport_width)) * 0.5;
        const half_height: f32 = @as(f32, @floatFromInt(camera.viewport_height)) * 0.5;
        return .{
            .x = half_width + (world.x - camera.center.x * camera_x_factor) * camera.pixels_per_meter,
            .y = half_height + (world.y - camera.center.y) * camera.pixels_per_meter,
        };
    }

    pub fn presentationToWorld(camera: Camera2D, presentation: math.Vec2) !math.Vec2 {
        try camera.validate();
        if (!presentation.isFinite()) return error.NonFinitePresentationPosition;
        const half_width: f32 = @as(f32, @floatFromInt(camera.viewport_width)) * 0.5;
        const half_height: f32 = @as(f32, @floatFromInt(camera.viewport_height)) * 0.5;
        return .{
            .x = camera.center.x + (presentation.x - half_width) / camera.pixels_per_meter,
            .y = camera.center.y + (presentation.y - half_height) / camera.pixels_per_meter,
        };
    }

    pub fn worldToClip(camera: Camera2D, world: math.Vec2, camera_x_factor: f32) !math.Vec2 {
        const presentation = try camera.worldToPresentation(world, camera_x_factor);
        return .{
            .x = presentation.x / @as(f32, @floatFromInt(camera.viewport_width)) * 2.0 - 1.0,
            .y = presentation.y / @as(f32, @floatFromInt(camera.viewport_height)) * 2.0 - 1.0,
        };
    }

    pub fn worldHalfExtents(camera: Camera2D) !math.Vec2 {
        try camera.validate();
        return .{
            .x = @as(f32, @floatFromInt(camera.viewport_width)) * 0.5 / camera.pixels_per_meter,
            .y = @as(f32, @floatFromInt(camera.viewport_height)) * 0.5 / camera.pixels_per_meter,
        };
    }

    pub fn uniform(camera: Camera2D) !CameraUniform {
        try camera.validate();
        return .{
            .center = camera.center.toArray(),
            .clip_scale = .{
                2.0 * camera.pixels_per_meter / @as(f32, @floatFromInt(camera.viewport_width)),
                2.0 * camera.pixels_per_meter / @as(f32, @floatFromInt(camera.viewport_height)),
            },
        };
    }
};

pub fn pixelsPerMeterForDrawableHeight(drawable_height: u32) !f32 {
    if (drawable_height == 0) return error.ZeroViewport;
    const pixels_per_meter = reference_pixels_per_meter *
        @as(f32, @floatFromInt(drawable_height)) /
        @as(f32, @floatFromInt(reference_drawable_height));
    if (!std.math.isFinite(pixels_per_meter) or pixels_per_meter <= 0) {
        return error.InvalidPixelsPerMeter;
    }
    return pixels_per_meter;
}

pub const HorizontalFollower = struct {
    dead_zone_half_width: f32,

    pub fn init(dead_zone_half_width: f32) !HorizontalFollower {
        if (!std.math.isFinite(dead_zone_half_width) or dead_zone_half_width < 0) {
            return error.InvalidDeadZone;
        }
        return .{ .dead_zone_half_width = dead_zone_half_width };
    }

    pub fn update(follower: HorizontalFollower, camera: *Camera2D, target_x: f32) !void {
        if (!std.math.isFinite(target_x)) return error.NonFiniteFollowTarget;
        var next_x = camera.center.x;
        if (target_x < next_x - follower.dead_zone_half_width) {
            next_x = target_x + follower.dead_zone_half_width;
        } else if (target_x > next_x + follower.dead_zone_half_width) {
            next_x = target_x - follower.dead_zone_half_width;
        }
        try camera.setCenter(.{ .x = next_x, .y = camera.center.y });
    }
};

pub fn validateCameraXFactor(camera_x_factor: f32) !void {
    if (!std.math.isFinite(camera_x_factor) or camera_x_factor < 0 or camera_x_factor > 1) {
        return error.InvalidCameraXFactor;
    }
}

comptime {
    if (@sizeOf(CameraUniform) != 16 or @alignOf(CameraUniform) != 4) {
        @compileError("CameraUniform must remain one 16-byte HLSL constant block");
    }
    if (@offsetOf(CameraUniform, "center") != 0 or @offsetOf(CameraUniform, "clip_scale") != 8) {
        @compileError("CameraUniform field offsets must match HLSL");
    }
}
