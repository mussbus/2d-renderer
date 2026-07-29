const std = @import("std");
const math = @import("math");
const camera2d = @import("camera2d");
const sprite = @import("sprite_batch");

pub const trace_capacity: usize = 256;
pub const landmark_capacity: usize = 16;
pub const mesh_vertex_capacity: usize = 8;
pub const mesh_index_capacity: usize = 18;
pub const metric_capacity: usize = 32768;
pub const alpha_threshold: u8 = 8;

pub const Owner = enum(u8) {
    anatomy,
    base_presentation,
    clothing,
    equipment,
    accessory,
};

pub const Role = enum(u8) {
    head,
    torso,
    pelvis,
    upper_arm,
    forearm,
    hand,
    thigh,
    shin,
    foot,
    torso_garment,
    lower_garment,
    sleeve,
    glove,
    legwear,
    shoe,
    headwear,
    waist_accessory,
    hair,
    face_feature,
    custom,
};

pub const Side = enum(u8) {
    none,
    left,
    right,
};

pub const View = enum(u8) {
    front,
    side_right,
    side_left,
};

pub const LandmarkKind = enum(u8) {
    proximal,
    distal,
    center,
    shoulder,
    shoulder_left,
    shoulder_right,
    elbow,
    wrist,
    palm,
    fingertip,
    hip,
    hip_left,
    hip_right,
    knee,
    ankle,
    heel,
    toe,
    sole_back,
    sole_front,
    scalp,
    headwear_fit,
    opening,
    neck,
    chest_left,
    chest_right,
    waist_left,
    waist_right,
    leg_opening_left,
    leg_opening_right,
    hem,
};

pub const FitDesign = enum(u8) {
    headwear_wide,
    headwear_band,
    headwear_fitted,
    torso_sleeveless,
    torso_fitted,
    torso_outer,
    sleeve_fitted,
    sleeve_puff,
    glove_long,
    wrist_cuff,
    waist_sash,
    waist_belt,
    lower_shorts,
    lower_mini,
    lower_pants,
    lower_long,
    legwear_fitted,
    shoe_strap,
};

pub const CoverageZone = struct {
    minimum_visible_uv: [2]f32 = .{ 0, 0 },
    maximum_visible_uv: [2]f32 = .{ 1, 1 },

    pub fn contains(zone: CoverageZone, visible_uv: [2]f32) bool {
        return visible_uv[0] >= zone.minimum_visible_uv[0] and
            visible_uv[0] <= zone.maximum_visible_uv[0] and
            visible_uv[1] >= zone.minimum_visible_uv[1] and
            visible_uv[1] <= zone.maximum_visible_uv[1];
    }
};

pub const Landmark = struct {
    kind: LandmarkKind,
    /// Normalized inside the alpha-visible bounding box. X grows right and Y
    /// grows from texture top toward texture bottom.
    visible_uv: [2]f32,
};

pub const Geometry = struct {
    role: Role,
    landmarks: [landmark_capacity]Landmark = undefined,
    landmark_count: u8 = 0,

    pub fn init(role: Role, values: []const Landmark) Geometry {
        std.debug.assert(values.len <= landmark_capacity);
        var result = Geometry{ .role = role };
        @memcpy(result.landmarks[0..values.len], values);
        result.landmark_count = @intCast(values.len);
        return result;
    }

    pub fn find(geometry: Geometry, kind: LandmarkKind) ?Landmark {
        for (geometry.landmarks[0..geometry.landmark_count]) |landmark| {
            if (landmark.kind == kind) return landmark;
        }
        return null;
    }
};

pub const WorldLandmark = struct {
    kind: LandmarkKind,
    world: math.Vec2,
};

pub const WorldGeometry = struct {
    landmarks: [landmark_capacity]WorldLandmark = undefined,
    landmark_count: u8 = 0,

    pub fn init(values: []const WorldLandmark) WorldGeometry {
        std.debug.assert(values.len <= landmark_capacity);
        var result = WorldGeometry{};
        @memcpy(result.landmarks[0..values.len], values);
        result.landmark_count = @intCast(values.len);
        return result;
    }

    pub fn find(geometry: WorldGeometry, kind: LandmarkKind) ?math.Vec2 {
        for (geometry.landmarks[0..geometry.landmark_count]) |landmark| {
            if (landmark.kind == kind) return landmark.world;
        }
        return null;
    }
};

pub const MeshVertex = struct {
    world: math.Vec2,
    uv: [2]f32,
};

pub const MeshTrace = struct {
    vertices: [mesh_vertex_capacity]MeshVertex = undefined,
    vertex_count: u8 = 0,
    indices: [mesh_index_capacity]u16 = undefined,
    index_count: u8 = 0,

    pub fn init(vertices: []const MeshVertex, indices: []const u16) MeshTrace {
        std.debug.assert(vertices.len <= mesh_vertex_capacity);
        std.debug.assert(indices.len <= mesh_index_capacity);
        var result = MeshTrace{};
        @memcpy(result.vertices[0..vertices.len], vertices);
        @memcpy(result.indices[0..indices.len], indices);
        result.vertex_count = @intCast(vertices.len);
        result.index_count = @intCast(indices.len);
        return result;
    }
};

pub fn anatomyGeometry(style: []const u8, role: Role, view: View) Geometry {
    const female = std.mem.eql(u8, style, "female");
    const vertical = [_]Landmark{
        .{ .kind = .proximal, .visible_uv = .{ 0.50, 0.04 } },
        .{ .kind = .distal, .visible_uv = .{ 0.50, 0.96 } },
    };
    return switch (role) {
        .upper_arm => if (view == .front)
            Geometry.init(.upper_arm, &.{
                .{ .kind = .shoulder, .visible_uv = .{ 0.50, if (female) 0.035 else 0.045 } },
                // The visible elbow interface occurs before the rounded alpha
                // cap, which supplies the bounded articulation overlap.
                .{ .kind = .elbow, .visible_uv = .{ 0.50, if (female) 0.978 else 0.968 } },
            })
        else
            Geometry.init(.upper_arm, &.{
                .{ .kind = .shoulder, .visible_uv = .{ 0.0, 0.50 } },
                .{ .kind = .elbow, .visible_uv = .{ 1.0, 0.50 } },
            }),
        .forearm => if (view == .front)
            Geometry.init(.forearm, &.{
                .{ .kind = .elbow, .visible_uv = .{ 0.50, 0.001 } },
                .{ .kind = .wrist, .visible_uv = .{ 0.50, 0.999 } },
            })
        else
            Geometry.init(.forearm, &.{
                .{ .kind = .elbow, .visible_uv = .{ 0.0, 0.50 } },
                .{ .kind = .wrist, .visible_uv = .{ 1.0, 0.50 } },
            }),
        .hand => if (view == .front)
            Geometry.init(.hand, &.{
                .{ .kind = .wrist, .visible_uv = .{ 0.50, 0.001 } },
                .{ .kind = .palm, .visible_uv = .{ 0.50, 0.48 } },
                .{ .kind = .fingertip, .visible_uv = .{ 0.50, 0.97 } },
            })
        else
            Geometry.init(.hand, &.{
                .{ .kind = .wrist, .visible_uv = .{ 0.0, 0.50 } },
                .{ .kind = .palm, .visible_uv = .{ 0.52, 0.50 } },
                .{ .kind = .fingertip, .visible_uv = .{ 0.97, 0.50 } },
            }),
        .thigh => if (view == .front)
            Geometry.init(.thigh, &.{
                .{ .kind = .hip, .visible_uv = .{ 0.50, 0.04 } },
                .{ .kind = .knee, .visible_uv = .{ 0.50, if (female) 0.947 else 0.977 } },
            })
        else
            Geometry.init(.thigh, &.{
                .{ .kind = .hip, .visible_uv = .{ 0.50, 0.0 } },
                .{ .kind = .knee, .visible_uv = .{ 0.50, 1.0 } },
            }),
        .shin => if (view == .front)
            Geometry.init(.shin, &.{
                // Both reauthored lower-leg sources own a soft proximal knee
                // overlap, so the semantic knee lies on the visible top edge.
                .{ .kind = .knee, .visible_uv = .{ 0.50, 0.001 } },
                .{ .kind = .ankle, .visible_uv = .{ 0.50, 0.999 } },
            })
        else
            Geometry.init(.shin, &.{
                .{ .kind = .knee, .visible_uv = .{ 0.50, 0.0 } },
                .{ .kind = .ankle, .visible_uv = .{ 0.50, 1.0 } },
            }),
        .foot => if (view == .front)
            Geometry.init(.foot, &.{
                // The ankle is the center of the visible proximal stem. The
                // former mid-height landmark forced almost half the foot
                // sprite underneath the shin and hid the actual articulation.
                .{ .kind = .ankle, .visible_uv = .{ if (female) 0.267 else 0.239, 0.0 } },
                .{ .kind = .heel, .visible_uv = .{ 0.07, 0.70 } },
                .{ .kind = .toe, .visible_uv = .{ 0.97, 0.78 } },
                .{ .kind = .sole_back, .visible_uv = .{ 0.06, 0.91 } },
                .{ .kind = .sole_front, .visible_uv = .{ 0.97, 0.91 } },
            })
        else
            Geometry.init(.foot, &.{
                .{ .kind = .ankle, .visible_uv = .{ if (female) 0.229 else 0.243, 0.0 } },
                .{ .kind = .heel, .visible_uv = .{ 0.06, 0.70 } },
                .{ .kind = .toe, .visible_uv = .{ 0.98, 0.75 } },
                .{ .kind = .sole_back, .visible_uv = .{ 0.05, 0.91 } },
                .{ .kind = .sole_front, .visible_uv = .{ 0.98, 0.91 } },
            }),
        .torso => Geometry.init(.torso, &.{
            .{ .kind = .neck, .visible_uv = .{ 0.50, 0.03 } },
            .{ .kind = .shoulder_left, .visible_uv = .{
                if (view == .front)
                    (if (female) -0.155 else -0.160)
                else if (female)
                    0.750
                else
                    0.773,
                0.162,
            } },
            .{ .kind = .shoulder_right, .visible_uv = .{
                if (view == .front)
                    (if (female) 1.185 else 1.169)
                else if (female)
                    0.750
                else
                    0.773,
                0.162,
            } },
            // Front torso art owns the deltoid caps. Its semantic shoulder
            // span is therefore the outer silhouette, not the inner neck
            // slope. Side sources expose only the visible profile shoulder
            // and retain their measured asymmetric bounds.
            .{ .kind = .shoulder, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.008 else 0.012)
                else if (female)
                    0.021
                else
                    0.096,
                0.16,
            } },
            .{ .kind = .proximal, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.992 else 0.988)
                else if (female)
                    0.711
                else
                    0.830,
                0.16,
            } },
            // Garments contact the chest/rib silhouette around the visible
            // mid-torso row. The earlier 0.34 row crossed the widest breast /
            // pectoral bulge and overstated fit clearance.
            .{ .kind = .chest_left, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.091 else 0.103)
                else if (female)
                    0.040
                else
                    0.053,
                0.50,
            } },
            .{ .kind = .chest_right, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.893 else 0.911)
                else if (female)
                    0.930
                else
                    0.979,
                0.50,
            } },
            .{ .kind = .waist_left, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.091 else 0.130)
                else if (female)
                    0.010
                else
                    0.085,
                0.94,
            } },
            .{ .kind = .waist_right, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.884 else 0.870)
                else if (female)
                    0.897
                else
                    0.894,
                0.94,
            } },
        }),
        .pelvis => Geometry.init(.pelvis, &.{
            .{ .kind = .waist_left, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.160 else 0.231)
                else
                    0.0,
                if (view == .front)
                    (if (female) 0.071 else -0.286)
                else
                    0.193,
            } },
            .{ .kind = .waist_right, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.840 else 0.769)
                else
                    1.0,
                if (view == .front)
                    (if (female) 0.071 else -0.286)
                else
                    0.193,
            } },
            .{ .kind = .hip_left, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.315 else 0.237)
                else
                    0.50,
                if (view == .front)
                    (if (female) 1.10 else 1.045)
                else if (female)
                    0.978
                else
                    0.986,
            } },
            .{ .kind = .hip_right, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.685 else 0.763)
                else
                    0.50,
                if (view == .front)
                    (if (female) 1.10 else 1.045)
                else if (female)
                    0.978
                else
                    0.986,
            } },
            .{ .kind = .hip, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.177 else 0.244)
                else
                    0.0,
                0.88,
            } },
            .{ .kind = .proximal, .visible_uv = .{
                if (view == .front)
                    (if (female) 0.823 else 0.756)
                else
                    1.0,
                0.88,
            } },
        }),
        .head => Geometry.init(.head, &.{
            .{ .kind = .center, .visible_uv = .{ 0.50, 0.50 } },
            .{ .kind = .scalp, .visible_uv = .{ 0.50, 0.03 } },
            .{ .kind = .headwear_fit, .visible_uv = .{ 0.50, 0.12 } },
            .{ .kind = .proximal, .visible_uv = .{ 0.18, 0.52 } },
            .{ .kind = .distal, .visible_uv = .{ 0.82, 0.52 } },
        }),
        else => Geometry.init(role, &vertical),
    };
}

pub fn attachmentGeometry(stable_id: []const u8, role: Role, view: View) Geometry {
    return switch (role) {
        .shoe => if (view == .front)
            Geometry.init(.shoe, &.{
                // The production source drawing points toward texture-left:
                // heel and opening are at the right, toe at the left.
                .{ .kind = .ankle, .visible_uv = .{ 0.70, 0.38 } },
                .{ .kind = .heel, .visible_uv = .{ 0.90, 0.72 } },
                .{ .kind = .toe, .visible_uv = .{ 0.05, 0.76 } },
                .{ .kind = .sole_back, .visible_uv = .{ 0.92, 0.91 } },
                .{ .kind = .sole_front, .visible_uv = .{ 0.04, 0.91 } },
            })
        else
            Geometry.init(.shoe, &.{
                .{ .kind = .ankle, .visible_uv = .{ 0.763, 0.38 } },
                .{ .kind = .heel, .visible_uv = .{ 0.91, 0.72 } },
                .{ .kind = .toe, .visible_uv = .{ 0.05, 0.74 } },
                .{ .kind = .sole_back, .visible_uv = .{ 0.92, 0.91 } },
                .{ .kind = .sole_front, .visible_uv = .{ 0.04, 0.91 } },
            }),
        .sleeve => Geometry.init(.sleeve, &.{
            .{ .kind = .proximal, .visible_uv = .{ 0.50, 0.05 } },
            .{ .kind = .distal, .visible_uv = .{ 0.50, 0.95 } },
        }),
        .glove => if (std.mem.eql(u8, stable_id, "crimson_long_glove"))
            Geometry.init(.glove, &.{
                // A long glove's visible top edge is its forearm cuff, not
                // the anatomical wrist. The wrist is an internal semantic
                // landmark derived from the authored hand-length portion.
                .{ .kind = .proximal, .visible_uv = .{ 0.50, 0.05 } },
                .{ .kind = .wrist, .visible_uv = .{ 0.50, 0.55 } },
                .{ .kind = .fingertip, .visible_uv = .{ 0.50, 0.95 } },
            })
        else
            Geometry.init(.glove, &.{
                .{ .kind = .wrist, .visible_uv = .{ 0.50, 0.05 } },
                .{ .kind = .fingertip, .visible_uv = .{ 0.50, 0.95 } },
            }),
        .legwear => Geometry.init(.legwear, &.{
            .{ .kind = .proximal, .visible_uv = .{ 0.50, 0.04 } },
            .{ .kind = .ankle, .visible_uv = .{ 0.50, 0.96 } },
        }),
        .torso_garment => torsoGarmentGeometry(stable_id, view),
        .lower_garment => Geometry.init(.lower_garment, &.{
            .{ .kind = .waist_left, .visible_uv = .{ 0.04, 0.05 } },
            .{ .kind = .waist_right, .visible_uv = .{ 0.96, 0.05 } },
            .{ .kind = .hip, .visible_uv = .{ 0.06, 0.42 } },
            .{ .kind = .proximal, .visible_uv = .{ 0.94, 0.42 } },
            .{ .kind = .leg_opening_left, .visible_uv = .{ 0.28, 0.88 } },
            .{ .kind = .leg_opening_right, .visible_uv = .{ 0.72, 0.88 } },
            .{ .kind = .hem, .visible_uv = .{ 0.50, 0.96 } },
        }),
        .headwear => Geometry.init(.headwear, &.{
            .{ .kind = .center, .visible_uv = .{ 0.50, 0.58 } },
            .{
                .kind = .opening,
                .visible_uv = .{
                    0.50,
                    if (std.mem.eql(u8, stable_id, "crimson_wide_brim_hat"))
                        0.68
                    else if (std.mem.eql(u8, stable_id, "moon_ear_headband") or
                        std.mem.eql(u8, stable_id, "ember_crescent_headband"))
                        // These sources include tall decoration above a circular
                        // band. The fit point is the top-inside intersection of
                        // that band with the scalp, visible around row 0.32; the
                        // old generic 0.78 row measured its lower arc.
                        0.32
                    else
                        0.78,
                },
            },
            .{ .kind = .proximal, .visible_uv = .{ 0.12, 0.68 } },
            .{ .kind = .distal, .visible_uv = .{ 0.88, 0.68 } },
        }),
        .waist_accessory => Geometry.init(.waist_accessory, &.{
            .{ .kind = .waist_left, .visible_uv = .{ 0.04, 0.50 } },
            .{ .kind = .waist_right, .visible_uv = .{ 0.96, 0.50 } },
        }),
        else => Geometry.init(role, &.{
            .{ .kind = .proximal, .visible_uv = .{ 0.50, 0.05 } },
            .{ .kind = .distal, .visible_uv = .{ 0.50, 0.95 } },
        }),
    };
}

fn torsoGarmentGeometry(stable_id: []const u8, view: View) Geometry {
    const front = view == .front;
    var waist_left: f32 = 0.08;
    var waist_right: f32 = 0.92;
    var waist_y: f32 = 0.94;
    var neck_x: f32 = 0.50;
    const neck_y: f32 = 0.03;
    var shoulder_left: f32 = 0.05;
    var shoulder_right: f32 = 0.95;
    var chest_left: f32 = 0.08;
    var chest_right: f32 = 0.92;
    if (std.mem.eql(u8, stable_id, "crimson_halter_top")) {
        waist_left = if (front) 0.079 else 0.121;
        waist_right = if (front) 0.929 else 0.871;
        neck_x = if (front) 0.50 else 0.641;
        shoulder_left = if (front) 0.302 else 0.452;
        shoulder_right = if (front) 0.698 else 0.798;
        chest_left = if (front) 0.063 else 0.121;
        chest_right = if (front) 0.937 else 0.669;
    } else if (std.mem.eql(u8, stable_id, "garnet_wrap_bodice")) {
        waist_left = if (front) 0.083 else 0.110;
        waist_right = if (front) 0.910 else 0.907;
        neck_x = if (front) 0.50 else 0.780;
        shoulder_left = if (front) 0.045 else 0.314;
        shoulder_right = if (front) 0.947 else 0.898;
        chest_left = if (front) 0.030 else 0.119;
        chest_right = if (front) 0.955 else 0.847;
    } else if (std.mem.eql(u8, stable_id, "scarlet_sport_top")) {
        waist_left = if (front) 0.077 else 0.081;
        waist_right = if (front) 0.915 else 0.865;
        neck_x = if (front) 0.493 else 0.578;
        shoulder_left = if (front) 0.070 else 0.196;
        shoulder_right = if (front) 0.923 else 0.939;
        chest_left = if (front) 0.007 else 0.014;
        chest_right = if (front) 0.993 else 0.993;
    } else if (std.mem.eql(u8, stable_id, "rose_romper_torso")) {
        waist_left = if (front) 0.058 else 0.064;
        waist_right = if (front) 0.934 else 0.900;
        neck_x = if (front) 0.50 else 0.546;
        shoulder_left = if (front) 0.050 else 0.227;
        shoulder_right = if (front) 0.942 else 0.964;
        chest_left = if (front) 0.008 else 0.018;
        chest_right = if (front) 0.983 else 0.927;
    } else if (std.mem.eql(u8, stable_id, "crimson_cardigan_torso")) {
        waist_left = if (front) 0.081 else 0.047;
        waist_right = if (front) 0.926 else 0.819;
        waist_y = 0.70;
        neck_x = if (front) 0.504 else 0.595;
        shoulder_left = if (front) 0.000 else 0.260;
        shoulder_right = if (front) 1.000 else 0.890;
        chest_left = if (front) 0.040 else 0.055;
        chest_right = if (front) 0.960 else 0.921;
    } else if (std.mem.eql(u8, stable_id, "ivory_blouse_torso")) {
        waist_left = if (front) 0.058 else 0.066;
        waist_right = if (front) 0.942 else 0.844;
        neck_x = if (front) 0.504 else 0.615;
        shoulder_left = if (front) 0.065 else 0.328;
        shoulder_right = if (front) 0.942 else 0.852;
        chest_left = if (front) 0.000 else 0.016;
        chest_right = if (front) 0.993 else 0.967;
    } else if (std.mem.eql(u8, stable_id, "ruby_day_dress_torso")) {
        waist_left = if (front) 0.082 else 0.074;
        waist_right = if (front) 0.910 else 0.926;
        neck_x = if (front) 0.668 else 0.472;
        shoulder_left = if (front) 0.352 else 0.241;
        shoulder_right = if (front) 0.762 else 0.537;
        chest_left = if (front) 0.033 else 0.037;
        chest_right = if (front) 0.967 else 0.963;
    } else if (std.mem.eql(u8, stable_id, "velvet_puff_blouse_torso")) {
        waist_left = if (front) 0.018 else 0.075;
        waist_right = if (front) 0.982 else 0.891;
        waist_y = 0.80;
        neck_x = if (front) 0.504 else 0.442;
        shoulder_left = if (front) 0.341 else 0.245;
        shoulder_right = if (front) 0.664 else 0.633;
        chest_left = if (front) 0.036 else 0.041;
        chest_right = if (front) 0.960 else 0.986;
    } else if (std.mem.eql(u8, stable_id, "crimson_one_shoulder_top")) {
        waist_left = if (front) 0.081 else 0.064;
        waist_right = if (front) 0.801 else 0.768;
        waist_y = 0.70;
        neck_x = if (front) 0.816 else 0.540;
        shoulder_left = if (front) 0.453 else 0.264;
        shoulder_right = if (front) 0.988 else 0.832;
        chest_left = if (front) 0.025 else 0.000;
        chest_right = if (front) 0.863 else 0.920;
    } else if (std.mem.eql(u8, stable_id, "ruby_fitted_jacket_torso")) {
        waist_left = if (front) 0.076 else 0.040;
        waist_right = if (front) 0.959 else 0.996;
        waist_y = 0.70;
        neck_x = if (front) 0.357 else 0.311;
        shoulder_left = if (front) 0.018 else 0.164;
        shoulder_right = if (front) 0.702 else 1.000;
        chest_left = if (front) 0.000 else 0.009;
        chest_right = if (front) 0.906 else 1.000;
    } else if (std.mem.eql(u8, stable_id, "ribbon_bodice")) {
        waist_left = if (front) 0.095 else 0.167;
        waist_right = if (front) 0.905 else 0.841;
        waist_y = 0.70;
        neck_x = if (front) 0.50 else 0.30;
        shoulder_left = if (front) 0.007 else 0.030;
        shoulder_right = if (front) 0.993 else 0.636;
        chest_left = if (front) 0.051 else 0.106;
        chest_right = if (front) 0.949 else 0.970;
    }
    return Geometry.init(.torso_garment, &.{
        .{ .kind = .neck, .visible_uv = .{ neck_x, neck_y } },
        .{ .kind = .shoulder, .visible_uv = .{ shoulder_left, 0.14 } },
        .{ .kind = .proximal, .visible_uv = .{ shoulder_right, 0.14 } },
        .{ .kind = .chest_left, .visible_uv = .{ chest_left, 0.50 } },
        .{ .kind = .chest_right, .visible_uv = .{ chest_right, 0.50 } },
        .{ .kind = .waist_left, .visible_uv = .{ waist_left, waist_y } },
        .{ .kind = .waist_right, .visible_uv = .{ waist_right, waist_y } },
        .{ .kind = .hem, .visible_uv = .{ 0.50, 0.97 } },
    });
}

pub const PixelRect = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

pub const AlphaGeometry = struct {
    source: PixelRect,
    opaque_bounds: PixelRect,
    opaque_count: u32,
    centroid_source_px: [2]f32,

    pub fn visibleWidth(alpha: AlphaGeometry) u32 {
        return alpha.opaque_bounds.width;
    }

    pub fn visibleHeight(alpha: AlphaGeometry) u32 {
        return alpha.opaque_bounds.height;
    }

    /// Converts a visible-bounds-relative point into the unit quad used by the
    /// production sprite vertex shader. Texture rows run down while local Y
    /// runs up, hence the explicit Y inversion.
    pub fn visibleUvToLocal(alpha: AlphaGeometry, visible_uv: [2]f32) [2]f32 {
        const source_width: f32 = @floatFromInt(alpha.source.width);
        const source_height: f32 = @floatFromInt(alpha.source.height);
        const x_in_source = @as(f32, @floatFromInt(alpha.opaque_bounds.x - alpha.source.x)) +
            visible_uv[0] * @as(f32, @floatFromInt(alpha.opaque_bounds.width -| 1));
        const y_in_source = @as(f32, @floatFromInt(alpha.opaque_bounds.y - alpha.source.y)) +
            visible_uv[1] * @as(f32, @floatFromInt(alpha.opaque_bounds.height -| 1));
        return .{
            (x_in_source + 0.5) / source_width,
            1.0 - (y_in_source + 0.5) / source_height,
        };
    }

    pub fn localToVisibleUv(alpha: AlphaGeometry, local: [2]f32) [2]f32 {
        const source_width: f32 = @floatFromInt(alpha.source.width);
        const source_height: f32 = @floatFromInt(alpha.source.height);
        const source_x = local[0] * source_width - 0.5;
        const source_y = (1.0 - local[1]) * source_height - 0.5;
        const opaque_x: f32 = @floatFromInt(alpha.opaque_bounds.x - alpha.source.x);
        const opaque_y: f32 = @floatFromInt(alpha.opaque_bounds.y - alpha.source.y);
        const opaque_width: f32 = @floatFromInt(alpha.opaque_bounds.width -| 1);
        const opaque_height: f32 = @floatFromInt(alpha.opaque_bounds.height -| 1);
        return .{
            if (opaque_width > 0) (source_x - opaque_x) / opaque_width else 0.5,
            if (opaque_height > 0) (source_y - opaque_y) / opaque_height else 0.5,
        };
    }
};

pub fn deriveAlphaGeometry(
    pixels: []const u8,
    image_width: u32,
    image_height: u32,
    row_bytes: u32,
    source: PixelRect,
) !AlphaGeometry {
    if (image_width == 0 or image_height == 0 or
        row_bytes < image_width * 4 or
        source.width == 0 or source.height == 0 or
        source.x > image_width - source.width or
        source.y > image_height - source.height)
    {
        return error.InvalidAlphaGeometryInput;
    }
    const required = @as(usize, row_bytes) * image_height;
    if (pixels.len < required) return error.InvalidAlphaGeometryInput;

    var min_x = source.x + source.width;
    var min_y = source.y + source.height;
    var max_x: u32 = source.x;
    var max_y: u32 = source.y;
    var count: u32 = 0;
    var sum_x: f64 = 0;
    var sum_y: f64 = 0;
    var y = source.y;
    while (y < source.y + source.height) : (y += 1) {
        var x = source.x;
        while (x < source.x + source.width) : (x += 1) {
            const alpha_index = @as(usize, y) * row_bytes + @as(usize, x) * 4 + 3;
            if (pixels[alpha_index] < alpha_threshold) continue;
            min_x = @min(min_x, x);
            min_y = @min(min_y, y);
            max_x = @max(max_x, x);
            max_y = @max(max_y, y);
            count += 1;
            sum_x += @floatFromInt(x);
            sum_y += @floatFromInt(y);
        }
    }
    if (count == 0) return error.EmptyAlphaRegion;
    return .{
        .source = source,
        .opaque_bounds = .{
            .x = min_x,
            .y = min_y,
            .width = max_x - min_x + 1,
            .height = max_y - min_y + 1,
        },
        .opaque_count = count,
        .centroid_source_px = .{
            @floatCast(sum_x / @as(f64, @floatFromInt(count))),
            @floatCast(sum_y / @as(f64, @floatFromInt(count))),
        },
    };
}

pub const FitContract = struct {
    design: FitDesign,
    registration_tolerance_px: f32 = 2.0,
    axis_tolerance_degrees: f32 = 5.0,
    sole_tolerance_degrees: f32 = 5.0,
    minimum_length_ratio: f32 = 0.95,
    maximum_length_ratio: f32 = 1.15,
    minimum_coverage: f32 = 0.90,
    minimum_front_coverage: ?f32 = null,
    minimum_side_coverage: ?f32 = null,
    maximum_off_target: f32 = 0.15,
    minimum_span_ratio: f32 = 0.96,
    maximum_span_ratio: f32 = 1.08,
    minimum_front_span_ratio: ?f32 = null,
    maximum_front_span_ratio: ?f32 = null,
    minimum_side_span_ratio: ?f32 = null,
    maximum_side_span_ratio: ?f32 = null,
    minimum_front_waist_span_ratio: ?f32 = null,
    maximum_front_waist_span_ratio: ?f32 = null,
    minimum_side_waist_span_ratio: ?f32 = null,
    maximum_side_waist_span_ratio: ?f32 = null,
    maximum_visible_gap_px: f32 = 2.0,
    maximum_visible_overlap_px: f32 = 5.0,
    coverage_zone: CoverageZone = .{},
    side_coverage_zone: ?CoverageZone = null,
    validate_coverage: bool = true,
    validate_off_target: bool = true,
    clearance_px: u8 = 2,
    male_front_scale_x: f32 = 1.0,
    male_side_scale_x: f32 = 1.0,
    male_front_scale_y: f32 = 1.0,
    male_side_scale_y: f32 = 1.0,
    female_front_scale_x: f32 = 1.0,
    female_side_scale_x: f32 = 1.0,
    /// Local-Y attachment response per unit authoritative morphology scale,
    /// plus a nominal authored bias. Used by fitted headwear whose semantic
    /// opening must follow a scalp landmark away from the head bone origin.
    morphology_fit_y_per_scale: f32 = 0,
    morphology_fit_y_bias: f32 = 0,
    secondary_target_role: ?Role = null,
    secondary_coverage_zone: CoverageZone = .{},
    side_secondary_coverage_zone: ?CoverageZone = null,
    coverage_mode: CoverageMode = .opaque_overlap,
    /// Half-width of each declared lower-garment leg opening in
    /// alpha-visible UV. Registration succeeds when the anatomy hip axis lies
    /// inside this authored opening plus the normal pixel tolerance.
    leg_opening_half_width_visible_uv: f32 = 0,

    pub fn minimumCoverage(contract: FitContract, view: View) f32 {
        return switch (view) {
            .front => contract.minimum_front_coverage orelse contract.minimum_coverage,
            .side_left, .side_right => contract.minimum_side_coverage orelse contract.minimum_coverage,
        };
    }

    pub fn coverageZone(contract: FitContract, view: View) CoverageZone {
        return switch (view) {
            .front => contract.coverage_zone,
            .side_left, .side_right => contract.side_coverage_zone orelse
                contract.coverage_zone,
        };
    }

    pub fn secondaryCoverageZone(contract: FitContract, view: View) CoverageZone {
        return switch (view) {
            .front => contract.secondary_coverage_zone,
            .side_left, .side_right => contract.side_secondary_coverage_zone orelse
                contract.secondary_coverage_zone,
        };
    }

    pub fn spanRange(contract: FitContract, view: View) [2]f32 {
        return switch (view) {
            .front => .{
                contract.minimum_front_span_ratio orelse contract.minimum_span_ratio,
                contract.maximum_front_span_ratio orelse contract.maximum_span_ratio,
            },
            .side_left, .side_right => .{
                contract.minimum_side_span_ratio orelse contract.minimum_span_ratio,
                contract.maximum_side_span_ratio orelse contract.maximum_span_ratio,
            },
        };
    }

    pub fn waistSpanRange(contract: FitContract, view: View) [2]f32 {
        return switch (view) {
            .front => .{
                contract.minimum_front_waist_span_ratio orelse contract.minimum_span_ratio,
                contract.maximum_front_waist_span_ratio orelse contract.maximum_span_ratio,
            },
            .side_left, .side_right => .{
                contract.minimum_side_waist_span_ratio orelse contract.minimum_span_ratio,
                contract.maximum_side_waist_span_ratio orelse contract.maximum_span_ratio,
            },
        };
    }
};

pub const ContinuityContract = struct {
    maximum_gap_px: f32 = 2.0,
    maximum_overlap_px: f32,
    maximum_overlap_parent_span_ratio: ?f32 = null,

    pub fn maximumOverlapForParentSpan(
        contract: ContinuityContract,
        parent_span_px: f32,
    ) f32 {
        const scaled = if (contract.maximum_overlap_parent_span_ratio) |ratio|
            parent_span_px * ratio
        else
            0;
        return @max(contract.maximum_overlap_px, scaled);
    }
};

/// Pixel continuity is evaluated at the deterministic 640x480 acceptance
/// camera. Torso-owned deltoids and the pelvis bridge deliberately overlap
/// their child sprites more deeply than intermediate joints so the root
/// attachment reads as one silhouette. Knees retain a smaller articulated
/// cap through deep bends. Elbows, wrists, and ankles keep the strict generic
/// cap; callers cannot substitute one joint class for another.
pub fn continuityContract(parent: Role, child: Role) ContinuityContract {
    if (parent == .torso and child == .upper_arm) {
        // The torso owns the deltoid silhouette. Its permitted shoulder cap
        // therefore grows with the active torso morphology, while the 15 px
        // floor preserves the nominal acceptance-camera contract. The ratio
        // independently rejects an arm buried too deeply in a broad torso.
        return .{
            .maximum_overlap_px = 15.0,
            .maximum_overlap_parent_span_ratio = 0.30,
        };
    }
    if (parent == .pelvis and child == .thigh) {
        return .{ .maximum_overlap_px = 15.0 };
    }
    if (parent == .thigh and child == .shin) {
        return .{ .maximum_overlap_px = 8.0 };
    }
    return .{ .maximum_overlap_px = 5.0 };
}

pub const CoverageMode = enum(u8) {
    /// The garment promises to paint over the declared target pixels.
    opaque_overlap,
    /// The garment is an open ring (for example a wrist cuff). Target pixels
    /// must lie within its visible outer bounds, while its transparent opening
    /// is intentionally not counted as missing cloth.
    enclosure_bounds,
};

pub fn fitContract(design: FitDesign) FitContract {
    return switch (design) {
        .headwear_wide => .{
            .design = design,
            .validate_coverage = false,
            .validate_off_target = false,
        },
        .headwear_band, .headwear_fitted => .{
            .design = design,
            .validate_coverage = false,
            .validate_off_target = false,
        },
        .torso_sleeveless => .{
            .design = design,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.35, 0.30 },
                .maximum_visible_uv = .{ 0.65, 0.85 },
            },
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.40, 0.40 },
                .maximum_visible_uv = .{ 0.60, 0.82 },
            },
            .minimum_span_ratio = 0.92,
            .maximum_span_ratio = 1.13,
            .maximum_off_target = 0.28,
            .clearance_px = 5,
            .male_front_scale_x = 0.727,
            .male_side_scale_x = 0.836,
            .female_front_scale_x = 0.730,
        },
        .torso_fitted => .{
            .design = design,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.12, 0.12 },
                .maximum_visible_uv = .{ 0.88, 0.94 },
            },
            .clearance_px = 5,
            .male_front_scale_x = 0.727,
            .male_side_scale_x = 0.836,
            .female_front_scale_x = 0.730,
        },
        .torso_outer => .{
            .design = design,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.08, 0.10 },
                .maximum_visible_uv = .{ 0.92, 0.96 },
            },
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.25, 0.25 },
                .maximum_visible_uv = .{ 0.75, 0.90 },
            },
            .minimum_span_ratio = 0.90,
            .maximum_span_ratio = 1.12,
            .maximum_off_target = 0.45,
            .clearance_px = 10,
            .male_front_scale_x = 0.727,
            .male_side_scale_x = 0.836,
            .female_front_scale_x = 0.730,
        },
        .sleeve_fitted => .{
            .design = design,
            // Cylindrical sleeves promise to enclose the authored arm band.
            // Their open cuff/armhole contours are not missing garment.
            .coverage_mode = .enclosure_bounds,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.12, 0.05 },
                .maximum_visible_uv = .{ 0.88, 0.95 },
            },
            // The side anatomy sources are authored horizontally. This is the
            // same proximal-to-distal arm band expressed in their local
            // visible space, not a weaker coverage requirement.
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.05, 0.12 },
                .maximum_visible_uv = .{ 0.95, 0.88 },
            },
            .maximum_off_target = 0.30,
            .clearance_px = 5,
        },
        .sleeve_puff => .{
            .design = design,
            .coverage_mode = .enclosure_bounds,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.18, 0.06 },
                .maximum_visible_uv = .{ 0.82, 0.88 },
            },
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.06, 0.18 },
                .maximum_visible_uv = .{ 0.88, 0.82 },
            },
            .maximum_off_target = 0.65,
            .clearance_px = 12,
        },
        .glove_long => .{
            .design = design,
            .coverage_mode = .enclosure_bounds,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.12, 0.02 },
                .maximum_visible_uv = .{ 0.88, 0.98 },
            },
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.02, 0.12 },
                .maximum_visible_uv = .{ 0.98, 0.88 },
            },
            .secondary_target_role = .forearm,
            .secondary_coverage_zone = .{
                .minimum_visible_uv = .{ 0.10, 0.45 },
                .maximum_visible_uv = .{ 0.90, 0.98 },
            },
            .side_secondary_coverage_zone = .{
                .minimum_visible_uv = .{ 0.45, 0.10 },
                .maximum_visible_uv = .{ 0.98, 0.90 },
            },
            .maximum_off_target = 0.30,
            .clearance_px = 5,
        },
        .wrist_cuff => .{
            .design = design,
            .coverage_mode = .enclosure_bounds,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.38, 0.00 },
                .maximum_visible_uv = .{ 0.62, 0.08 },
            },
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.00, 0.38 },
                .maximum_visible_uv = .{ 0.08, 0.62 },
            },
            .maximum_off_target = 0.55,
            .clearance_px = 6,
        },
        .waist_sash, .waist_belt => .{
            .design = design,
            .validate_coverage = false,
            .maximum_off_target = 0.55,
            .clearance_px = 8,
            .male_front_scale_x = 0.704,
            // The male side pelvis is deeper than the earlier generic side
            // projection assumed. This restores the authored accessory span;
            // the same 0.96..1.08 fit ruler remains in force.
            .male_side_scale_x = 0.975,
        },
        .lower_shorts => .{
            .design = design,
            // Waist, hip span, leg-opening containment, and waist
            // registration are checked independently. Coverage therefore
            // asks whether the declared pelvis zone is enclosed by the
            // alpha-tight garment silhouette, without treating intentional
            // leg openings as missing cloth.
            .coverage_mode = .enclosure_bounds,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.30, 0.25 },
                .maximum_visible_uv = .{ 0.70, 0.65 },
            },
            // Profile bottoms must enclose the visible front-to-back pelvis,
            // not merely a narrow strip through its center. This catches the
            // previously exposed buttock behind otherwise "bound" shorts.
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.01, 0.15 },
                .maximum_visible_uv = .{ 0.99, 0.70 },
            },
            .minimum_side_coverage = 0.98,
            .maximum_off_target = 0.30,
            .clearance_px = 6,
            .male_front_scale_x = 0.704,
            .male_side_scale_x = 1.150,
            .female_side_scale_x = 1.290,
            .minimum_side_span_ratio = 0.96,
            .maximum_side_span_ratio = 1.40,
            .minimum_side_waist_span_ratio = 0.96,
            .maximum_side_waist_span_ratio = 1.40,
            .leg_opening_half_width_visible_uv = 0.13,
        },
        .lower_mini => .{
            .design = design,
            .coverage_mode = .enclosure_bounds,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.25, 0.22 },
                .maximum_visible_uv = .{ 0.75, 0.70 },
            },
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.01, 0.15 },
                .maximum_visible_uv = .{ 0.99, 0.72 },
            },
            .minimum_side_coverage = 0.98,
            .maximum_off_target = 0.45,
            .clearance_px = 9,
            .male_front_scale_x = 0.704,
            .male_side_scale_x = 1.130,
            .female_side_scale_x = 1.270,
            .minimum_side_span_ratio = 0.96,
            .maximum_side_span_ratio = 1.40,
            .minimum_side_waist_span_ratio = 0.96,
            .maximum_side_waist_span_ratio = 1.40,
            .leg_opening_half_width_visible_uv = 0.18,
        },
        .lower_pants, .lower_long => .{
            .design = design,
            .coverage_mode = .enclosure_bounds,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.25, 0.15 },
                .maximum_visible_uv = .{ 0.75, 0.65 },
            },
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.01, 0.10 },
                .maximum_visible_uv = .{ 0.99, 0.72 },
            },
            .minimum_side_coverage = 0.98,
            .maximum_off_target = 0.60,
            .clearance_px = 12,
            .male_front_scale_x = 0.704,
            .male_side_scale_x = 1.150,
            .female_side_scale_x = 1.290,
            .minimum_side_span_ratio = 0.96,
            .maximum_side_span_ratio = 1.40,
            .minimum_side_waist_span_ratio = 0.96,
            .maximum_side_waist_span_ratio = 1.40,
        },
        .legwear_fitted => .{
            .design = design,
            .coverage_mode = .enclosure_bounds,
            .coverage_zone = .{
                .minimum_visible_uv = .{ 0.12, 0.04 },
                .maximum_visible_uv = .{ 0.88, 0.96 },
            },
            .side_coverage_zone = .{
                .minimum_visible_uv = .{ 0.04, 0.12 },
                .maximum_visible_uv = .{ 0.96, 0.88 },
            },
            .maximum_off_target = 0.30,
            .clearance_px = 5,
        },
        .shoe_strap => .{
            .design = design,
            .coverage_zone = .{
                // Strappy footwear promises sole/heel/toe enclosure. Open
                // instep pixels above this zone are intentionally visible and
                // are not the target of the coverage contract.
                .minimum_visible_uv = .{ 0.02, 0.68 },
                .maximum_visible_uv = .{ 0.98, 0.96 },
            },
            .maximum_off_target = 0.32,
            .minimum_coverage = 0.65,
            .clearance_px = 4,
            .male_front_scale_x = 1.166,
            .male_side_scale_x = 0.988,
            .male_front_scale_y = 0.91,
        },
    };
}

pub const TraceRecord = struct {
    character_id: u32,
    style: []const u8,
    view: View,
    owner: Owner,
    role: Role,
    side: Side,
    semantic_id: u32,
    component_id: u32,
    bound_identity: u32,
    stable_id: []const u8,
    region_id: u32,
    source: PixelRect,
    request: sprite.SpriteRequest,
    geometry: Geometry,
    fit: ?FitContract = null,
    world_geometry: ?WorldGeometry = null,
    mesh: ?MeshTrace = null,
    /// Production UnifiedRenderQueue index. Rigid records address
    /// sprite_submissions and mesh records address mesh_submissions. Pure
    /// geometry fixtures retain the sentinel because they submit no GPU work.
    submission_index: u32 = std.math.maxInt(u32),
    /// Longitudinal scale contributed by the authoritative morphology/bone
    /// transform before authored art size is applied. Proportion contracts
    /// use this to evaluate supported morphology rather than one screenshot.
    morphology_length_scale: f32 = 1,
};

pub const Trace = struct {
    records: [trace_capacity]TraceRecord = undefined,
    count: usize = 0,
    overflow_count: u32 = 0,

    pub fn begin(trace: *Trace) void {
        trace.count = 0;
    }

    pub fn append(trace: *Trace, record: TraceRecord) !void {
        if (trace.count == trace.records.len) {
            trace.overflow_count += 1;
            return error.VisualGeometryTraceCapacityExceeded;
        }
        trace.records[trace.count] = record;
        trace.count += 1;
    }

    pub fn slice(trace: *const Trace) []const TraceRecord {
        return trace.records[0..trace.count];
    }

    pub fn sliceMutable(trace: *Trace) []TraceRecord {
        return trace.records[0..trace.count];
    }
};

pub const ResolvedLandmark = struct {
    world: math.Vec2,
    pixel: math.Vec2,
};

pub fn resolveLandmark(
    record: TraceRecord,
    alpha: AlphaGeometry,
    kind: LandmarkKind,
    camera: camera2d.Camera2D,
) !ResolvedLandmark {
    const world = if (record.world_geometry) |geometry|
        geometry.find(kind) orelse blk: {
            const landmark = record.geometry.find(kind) orelse return error.MissingSemanticLandmark;
            const local = alpha.visibleUvToLocal(landmark.visible_uv);
            const world_array = sprite.localPointToWorld(record.request, local);
            break :blk math.Vec2{ .x = world_array[0], .y = world_array[1] };
        }
    else blk: {
        const landmark = record.geometry.find(kind) orelse return error.MissingSemanticLandmark;
        const local = alpha.visibleUvToLocal(landmark.visible_uv);
        const world_array = sprite.localPointToWorld(record.request, local);
        break :blk math.Vec2{ .x = world_array[0], .y = world_array[1] };
    };
    return .{
        .world = world,
        .pixel = try camera.worldToPresentation(world, record.request.camera_x_factor),
    };
}

pub fn distance(a: math.Vec2, b: math.Vec2) f32 {
    return a.sub(b).length();
}

pub fn angleDegrees(a_start: math.Vec2, a_end: math.Vec2, b_start: math.Vec2, b_end: math.Vec2) !f32 {
    const a = a_end.sub(a_start);
    const b = b_end.sub(b_start);
    const a_length = a.length();
    const b_length = b.length();
    if (a_length <= std.math.floatEps(f32) or b_length <= std.math.floatEps(f32)) {
        return error.DegenerateSemanticAxis;
    }
    const cosine = std.math.clamp(a.dot(b) / (a_length * b_length), -1.0, 1.0);
    return std.math.radiansToDegrees(std.math.acos(cosine));
}

pub const Outcome = enum(u8) { pass, fail };

pub const Metric = struct {
    character_style: []const u8,
    outfit: []const u8,
    view: View,
    pose: []const u8,
    component: []const u8,
    side: Side,
    metric: []const u8,
    actual: f32,
    minimum: ?f32 = null,
    maximum: ?f32 = null,
    unit: []const u8,
    outcome: Outcome,
};

pub const Report = struct {
    metrics: [metric_capacity]Metric = undefined,
    count: usize = 0,
    failure_count: u32 = 0,

    pub fn append(report: *Report, metric: Metric) !void {
        if (report.count == report.metrics.len) return error.VisualGeometryMetricCapacityExceeded;
        report.metrics[report.count] = metric;
        report.count += 1;
        if (metric.outcome == .fail) report.failure_count += 1;
    }

    pub fn recordMaximum(
        report: *Report,
        context: Metric,
        maximum: f32,
    ) !void {
        var value = context;
        value.maximum = maximum;
        value.outcome = if (value.actual <= maximum) .pass else .fail;
        try report.append(value);
    }

    pub fn recordRange(
        report: *Report,
        context: Metric,
        minimum: f32,
        maximum: f32,
    ) !void {
        var value = context;
        value.minimum = minimum;
        value.maximum = maximum;
        value.outcome = if (value.actual >= minimum and value.actual <= maximum) .pass else .fail;
        try report.append(value);
    }
};

pub const MaskStats = struct {
    target_pixels: u32,
    covered_target_pixels: u32,
    attachment_pixels: u32,
    attachment_off_target_pixels: u32,
    opposite_target_pixels: u32,

    pub fn coverage(stats: MaskStats) f32 {
        if (stats.target_pixels == 0) return 0;
        return @as(f32, @floatFromInt(stats.covered_target_pixels)) /
            @as(f32, @floatFromInt(stats.target_pixels));
    }

    pub fn offTarget(stats: MaskStats) f32 {
        if (stats.attachment_pixels == 0) return 1;
        return @as(f32, @floatFromInt(stats.attachment_off_target_pixels)) /
            @as(f32, @floatFromInt(stats.attachment_pixels));
    }
};

pub fn sampleAlphaAtWorld(
    record: TraceRecord,
    image_pixels: []const u8,
    image_width: u32,
    image_height: u32,
    row_bytes: u32,
    world: math.Vec2,
) !bool {
    if (record.mesh) |mesh_trace| {
        return sampleMeshAlphaAtWorld(
            mesh_trace,
            image_pixels,
            image_width,
            image_height,
            row_bytes,
            world,
        );
    }
    const local = try sprite.worldPointToLocal(record.request, world.toArray());
    if (local[0] < 0 or local[0] > 1 or local[1] < 0 or local[1] > 1) return false;
    const u = record.request.uv_rect[0] +
        (record.request.uv_rect[2] - record.request.uv_rect[0]) * local[0];
    const v = record.request.uv_rect[3] +
        (record.request.uv_rect[1] - record.request.uv_rect[3]) * local[1];
    const clamped_u = std.math.clamp(u, 0.0, 0.999999);
    const clamped_v = std.math.clamp(v, 0.0, 0.999999);
    const x: u32 = @intFromFloat(clamped_u * @as(f32, @floatFromInt(image_width)));
    const y: u32 = @intFromFloat(clamped_v * @as(f32, @floatFromInt(image_height)));
    const index = @as(usize, y) * row_bytes + @as(usize, x) * 4 + 3;
    if (index >= image_pixels.len) return error.InvalidAlphaGeometryInput;
    return image_pixels[index] >= alpha_threshold;
}

fn sampleMeshAlphaAtWorld(
    mesh_trace: MeshTrace,
    image_pixels: []const u8,
    image_width: u32,
    image_height: u32,
    row_bytes: u32,
    world: math.Vec2,
) !bool {
    var index: usize = 0;
    while (index + 2 < mesh_trace.index_count) : (index += 3) {
        const a = mesh_trace.vertices[mesh_trace.indices[index]];
        const b = mesh_trace.vertices[mesh_trace.indices[index + 1]];
        const c = mesh_trace.vertices[mesh_trace.indices[index + 2]];
        const v0 = b.world.sub(a.world);
        const v1 = c.world.sub(a.world);
        const v2 = world.sub(a.world);
        const denominator = v0.x * v1.y - v1.x * v0.y;
        if (@abs(denominator) <= std.math.floatEps(f32)) continue;
        const inverse = 1.0 / denominator;
        const beta = (v2.x * v1.y - v1.x * v2.y) * inverse;
        const gamma = (v0.x * v2.y - v2.x * v0.y) * inverse;
        const alpha_weight = 1.0 - beta - gamma;
        if (alpha_weight < -0.0001 or beta < -0.0001 or gamma < -0.0001) continue;
        const u = alpha_weight * a.uv[0] + beta * b.uv[0] + gamma * c.uv[0];
        const v = alpha_weight * a.uv[1] + beta * b.uv[1] + gamma * c.uv[1];
        const x: u32 = @intFromFloat(std.math.clamp(u, 0.0, 0.999999) *
            @as(f32, @floatFromInt(image_width)));
        const y: u32 = @intFromFloat(std.math.clamp(v, 0.0, 0.999999) *
            @as(f32, @floatFromInt(image_height)));
        const alpha_index = @as(usize, y) * row_bytes + @as(usize, x) * 4 + 3;
        if (alpha_index >= image_pixels.len) return error.InvalidAlphaGeometryInput;
        return image_pixels[alpha_index] >= alpha_threshold;
    }
    return false;
}

pub fn roleForAnchor(anchor: anytype) Role {
    return switch (anchor) {
        .head => .headwear,
        .torso => .torso_garment,
        .pelvis => .lower_garment,
        .upper_arm => .sleeve,
        .hand => .glove,
        .lower_leg => .legwear,
        .foot => .shoe,
        .waist => .waist_accessory,
    };
}
