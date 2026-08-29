const std = @import("std");

pub const ProjectionKind = enum {
    perspective,
    orthographic,
};

pub const PerspectiveGeometry = struct {
    focal_length_mm: f32,
    sensor_width_mm: f32,
    sensor_height_mm: f32,
};

pub const OrthographicGeometry = struct {
    horizontal_extent_m: f32,
    vertical_extent_m: f32,
};

pub const CameraDefinition = struct {
    projection: ProjectionKind,
    perspective: ?PerspectiveGeometry = null,
    orthographic: ?OrthographicGeometry = null,
    lens_shift_x: f32 = 0.0,
    lens_shift_y: f32 = 0.0,
    near_clip_m: f32,
    far_clip_m: f32,

    pub fn validate(self: CameraDefinition) error{InvalidCameraGeometry}!void {
        if (!finitePositive(self.near_clip_m) or !std.math.isFinite(self.far_clip_m) or self.far_clip_m <= self.near_clip_m) {
            return error.InvalidCameraGeometry;
        }
        if (!std.math.isFinite(self.lens_shift_x) or !std.math.isFinite(self.lens_shift_y)) return error.InvalidCameraGeometry;
        switch (self.projection) {
            .perspective => {
                if (self.perspective == null or self.orthographic != null) return error.InvalidCameraGeometry;
                const value = self.perspective.?;
                if (!finitePositive(value.focal_length_mm) or !finitePositive(value.sensor_width_mm) or !finitePositive(value.sensor_height_mm)) {
                    return error.InvalidCameraGeometry;
                }
            },
            .orthographic => {
                if (self.orthographic == null or self.perspective != null) return error.InvalidCameraGeometry;
                const value = self.orthographic.?;
                if (!finitePositive(value.horizontal_extent_m) or !finitePositive(value.vertical_extent_m)) return error.InvalidCameraGeometry;
            },
        }
    }
};

fn finitePositive(value: f32) bool {
    return std.math.isFinite(value) and value > 0.0;
}
