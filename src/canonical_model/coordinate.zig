pub const DistanceUnit = enum {
    meter,
};

pub const NumericPrecision = enum {
    f32,
};

pub const Handedness = enum {
    right_handed,
};

pub const AxisDirection = enum {
    positive_x,
    positive_y,
    positive_z,
    negative_z,
};

pub const AssetOrigin = enum {
    centered_between_feet_on_ground_in_a_pose,
};

pub const BindPose = enum {
    a_pose,
};

pub const AngleUnit = enum {
    radian,
};

pub const CoordinateContract = struct {
    unit: DistanceUnit,
    numeric_precision: NumericPrecision,
    authoring_step_m: f32,
    handedness: Handedness,
    world_viewer_right: AxisDirection,
    up: AxisDirection,
    toward_camera: AxisDirection,
    away_from_camera: AxisDirection,
    canonical_forward: AxisDirection,
    ground_y_m: f32,
    asset_origin: AssetOrigin,
    canonical_height_m: f32,
    bind_pose: BindPose,
    canonical_angle_unit: AngleUnit,
};

pub const canonical = CoordinateContract{
    .unit = .meter,
    .numeric_precision = .f32,
    .authoring_step_m = 0.001,
    .handedness = .right_handed,
    .world_viewer_right = .positive_x,
    .up = .positive_y,
    .toward_camera = .positive_z,
    .away_from_camera = .negative_z,
    .canonical_forward = .positive_z,
    .ground_y_m = 0,
    .asset_origin = .centered_between_feet_on_ground_in_a_pose,
    .canonical_height_m = 1.8288,
    .bind_pose = .a_pose,
    .canonical_angle_unit = .radian,
};
