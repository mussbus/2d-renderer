const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const secondary_motion = @import("attachment_secondary_motion");
const mesh = @import("deformable_mesh");
const equipment = @import("equipment");
const humanoid = @import("humanoid");
const visual_geometry = @import("visual_geometry");

pub const visual_count: usize = 36;
pub const preset_count: usize = 15;
pub const maximum_preset_items: usize = 8;
pub const custom_item_count: usize = 7;
pub const footwear_ankle_offset_metres: f32 = -0.35;
pub const sleeve_shoulder_offset_metres: f32 = 0;

pub const OutfitPresetId = enum(u16) {
    _,

    pub fn index(id: OutfitPresetId) usize {
        return @intFromEnum(id);
    }
};

pub const AnchorKind = enum(u8) {
    head,
    torso,
    pelvis,
    upper_arm,
    hand,
    lower_leg,
    foot,
    waist,
};

pub const VisualSpec = struct {
    stable_id: []const u8,
    semantic: equipment.PresentationSemanticId,
    anchor: AnchorKind,
    authored_size: [2]f32,
    side_authored_size: ?[2]f32 = null,
    front_authored_size: ?[2]f32 = null,
    pivot: [2]f32,
    side_pivot: ?[2]f32 = null,
    front_pivot: ?[2]f32 = null,
    male_front_pivot_y: ?f32 = null,
    female_front_pivot_y: ?f32 = null,
    male_side_pivot_y: ?f32 = null,
    female_side_pivot_y: ?f32 = null,
    fit: visual_geometry.FitContract,
};

fn semantic(raw: u32) equipment.PresentationSemanticId {
    return @enumFromInt(raw);
}

fn fitWithViewCoverage(
    design: visual_geometry.FitDesign,
    front_minimum: f32,
    side_minimum: f32,
) visual_geometry.FitContract {
    var fit = visual_geometry.fitContract(design);
    fit.minimum_front_coverage = front_minimum;
    fit.minimum_side_coverage = side_minimum;
    return fit;
}

fn torsoFit(stable_id: []const u8, design: visual_geometry.FitDesign) visual_geometry.FitContract {
    var fit = visual_geometry.fitContract(design);
    if (std.mem.eql(u8, stable_id, "crimson_halter_top")) {
        fit.minimum_front_coverage = 0.90;
        fit.minimum_side_coverage = 0.82;
        // Profile halter art intentionally covers the anterior bust rather
        // than wrapping the full back-to-bust torso depth.
        fit.minimum_side_span_ratio = 0.58;
        fit.maximum_side_span_ratio = 0.78;
    } else if (std.mem.eql(u8, stable_id, "garnet_wrap_bodice")) {
        fit.minimum_side_span_ratio = 0.75;
        fit.maximum_side_span_ratio = 0.95;
    } else if (std.mem.eql(u8, stable_id, "scarlet_sport_top")) {
        fit.minimum_front_span_ratio = 0.95;
        fit.maximum_front_span_ratio = 1.20;
        fit.minimum_side_span_ratio = 0.95;
        fit.maximum_side_span_ratio = 1.30;
    } else if (std.mem.eql(u8, stable_id, "ivory_blouse_torso")) {
        fit.minimum_side_span_ratio = 0.95;
        fit.maximum_side_span_ratio = 1.25;
    } else if (std.mem.eql(u8, stable_id, "velvet_puff_blouse_torso")) {
        fit.minimum_front_span_ratio = 0.88;
        fit.maximum_front_span_ratio = 1.10;
        fit.minimum_side_span_ratio = 0.95;
        fit.maximum_side_span_ratio = 1.20;
    } else if (std.mem.eql(u8, stable_id, "crimson_one_shoulder_top")) {
        fit.minimum_front_span_ratio = 1.00;
        fit.maximum_front_span_ratio = 1.20;
        fit.minimum_side_span_ratio = 1.00;
        fit.maximum_side_span_ratio = 1.32;
        // The upper-left chest is intentionally bare. Coverage applies to
        // the diagonal garment panel below that neckline.
        fit.coverage_zone = .{
            .minimum_visible_uv = .{ 0.35, 0.50 },
            .maximum_visible_uv = .{ 0.65, 0.88 },
        };
        fit.coverage_mode = .enclosure_bounds;
        fit.maximum_off_target = 0.30;
    } else if (std.mem.eql(u8, stable_id, "ribbon_bodice")) {
        fit.minimum_side_span_ratio = 0.95;
        fit.maximum_side_span_ratio = 1.30;
        fit.coverage_mode = .enclosure_bounds;
        fit.side_coverage_zone = .{
            .minimum_visible_uv = .{ 0.45, 0.45 },
            .maximum_visible_uv = .{ 0.55, 0.82 },
        };
    }
    return fit;
}

fn wideHatFit() visual_geometry.FitContract {
    var fit = visual_geometry.fitContract(.headwear_wide);
    fit.morphology_fit_y_per_scale = 0.3655;
    fit.morphology_fit_y_bias = -0.0177;
    return fit;
}

fn splitSkirtFit() visual_geometry.FitContract {
    var fit = visual_geometry.fitContract(.lower_long);
    // This formal skirt has a deliberately relaxed draped waistband while
    // its hip panel remains fitted. Style/view-specific X response keeps the
    // same authored garment design on the distinct pelvis morphologies.
    fit.male_front_scale_x = 0.665;
    fit.male_side_scale_x = 1.050;
    fit.female_front_scale_x = 0.944;
    fit.female_side_scale_x = 1.160;
    fit.minimum_front_waist_span_ratio = 0.96;
    fit.maximum_front_waist_span_ratio = 1.15;
    fit.minimum_side_waist_span_ratio = 0.96;
    fit.maximum_side_waist_span_ratio = 1.45;
    fit.minimum_side_span_ratio = 0.96;
    fit.maximum_side_span_ratio = 1.45;
    // The split skirt's side silhouette is a curved drape, not a rectangular
    // trouser shell. Its promised target is the fitted waistband/upper-hip
    // panel; the open split and trailing folds are intentional design space.
    fit.side_coverage_zone = .{
        .minimum_visible_uv = .{ 0.10, 0.15 },
        .maximum_visible_uv = .{ 0.90, 0.62 },
    };
    fit.minimum_side_coverage = 0.88;
    return fit;
}

fn lowerFit(stable_id: []const u8, design: visual_geometry.FitDesign) visual_geometry.FitContract {
    var fit = visual_geometry.fitContract(design);
    if (std.mem.eql(u8, stable_id, "scarlet_sport_shorts")) {
        // The low-rise sport-short side source tapers more aggressively than
        // the tailored-short source. Preserve that design while giving its
        // male profile enough authored width to enclose the pelvis core
        // during walk compression.
        fit.male_side_scale_x = 1.180;
    } else if (std.mem.eql(u8, stable_id, "velvet_mini_skirt")) {
        // The mini skirt's curved side seam and secondary motion need a small
        // female-profile clearance increase so the promised upper-pelvis
        // enclosure remains intact during rise and landing.
        fit.female_side_scale_x = 1.300;
    } else if (std.mem.eql(u8, stable_id, "ruby_day_dress_lower") or
        std.mem.eql(u8, stable_id, "ruby_fitted_pants"))
    {
        // These profile sources have a deliberately rounded waist/seat edge.
        // Validate the intended enclosed pelvis core, excluding only the
        // alpha-tight antialiased contour at the extreme source columns.
        fit.side_coverage_zone = .{
            .minimum_visible_uv = .{ 0.04, 0.10 },
            .maximum_visible_uv = .{ 0.96, 0.70 },
        };
        fit.minimum_side_coverage = 0.94;
    } else if (std.mem.eql(u8, stable_id, "crimson_highwaist_pants")) {
        fit.side_coverage_zone = .{
            .minimum_visible_uv = .{ 0.025, 0.10 },
            .maximum_visible_uv = .{ 0.975, 0.70 },
        };
        fit.minimum_side_coverage = 0.96;
    }
    return fit;
}

pub const visual_specs = [_]VisualSpec{
    .{ .stable_id = "crimson_wide_brim_hat", .semantic = semantic(25_000), .anchor = .head, .authored_size = .{ 1.30, 0.72 }, .pivot = .{ 0.50, 0.32 }, .fit = wideHatFit() },
    .{ .stable_id = "moon_ear_headband", .semantic = semantic(25_001), .anchor = .head, .authored_size = .{ 0.84, 1.02 }, .pivot = .{ 0.50, 0.808 }, .fit = visual_geometry.fitContract(.headwear_band) },
    .{ .stable_id = "ember_crescent_headband", .semantic = semantic(25_002), .anchor = .head, .authored_size = .{ 0.82, 0.78 }, .pivot = .{ 0.50, 0.78 }, .fit = visual_geometry.fitContract(.headwear_band) },
    .{ .stable_id = "rose_pillbox_hat", .semantic = semantic(25_003), .anchor = .head, .authored_size = .{ 0.64, 0.30 }, .pivot = .{ 0.50, 0.74 }, .fit = visual_geometry.fitContract(.headwear_fitted) },
    .{ .stable_id = "crimson_halter_top", .semantic = semantic(25_004), .anchor = .torso, .authored_size = .{ 0.905, 1.22 }, .side_authored_size = .{ 0.869, 1.22 }, .pivot = .{ 0.50, 0.50 }, .side_pivot = .{ 0.641, 0.50 }, .fit = torsoFit("crimson_halter_top", .torso_sleeveless) },
    .{ .stable_id = "garnet_wrap_bodice", .semantic = semantic(25_005), .anchor = .torso, .authored_size = .{ 0.928, 1.22 }, .side_authored_size = .{ 0.818, 1.22 }, .pivot = .{ 0.50, 0.50 }, .side_pivot = .{ 0.780, 0.50 }, .fit = torsoFit("garnet_wrap_bodice", .torso_sleeveless) },
    .{ .stable_id = "scarlet_sport_top", .semantic = semantic(25_006), .anchor = .torso, .authored_size = .{ 0.917, 1.10 }, .side_authored_size = .{ 0.831, 1.10 }, .pivot = .{ 0.493, 0.41 }, .side_pivot = .{ 0.578, 0.41 }, .female_front_pivot_y = 0.427, .fit = torsoFit("scarlet_sport_top", .torso_sleeveless) },
    .{ .stable_id = "rose_romper_torso", .semantic = semantic(25_007), .anchor = .torso, .authored_size = .{ 0.877, 1.18 }, .side_authored_size = .{ 0.780, 1.18 }, .pivot = .{ 0.50, 0.470 }, .side_pivot = .{ 0.546, 0.470 }, .fit = torsoFit("rose_romper_torso", .torso_sleeveless) },
    .{ .stable_id = "crimson_cardigan_torso", .semantic = semantic(25_008), .anchor = .torso, .authored_size = .{ 0.928, 1.24 }, .side_authored_size = .{ 0.869, 1.24 }, .pivot = .{ 0.504, 0.50 }, .side_pivot = .{ 0.595, 0.50 }, .fit = visual_geometry.fitContract(.torso_outer) },
    .{ .stable_id = "ivory_blouse_torso", .semantic = semantic(25_009), .anchor = .torso, .authored_size = .{ 0.869, 1.22 }, .side_authored_size = .{ 0.838, 1.22 }, .pivot = .{ 0.504, 0.500 }, .side_pivot = .{ 0.615, 0.479 }, .fit = torsoFit("ivory_blouse_torso", .torso_sleeveless) },
    .{ .stable_id = "ruby_day_dress_torso", .semantic = semantic(25_010), .anchor = .torso, .authored_size = .{ 0.927, 1.20 }, .side_authored_size = .{ 0.765, 1.20 }, .pivot = .{ 0.668, 0.477 }, .side_pivot = .{ 0.472, 0.477 }, .fit = torsoFit("ruby_day_dress_torso", .torso_sleeveless) },
    .{ .stable_id = "crimson_strap_shoe", .semantic = semantic(25_011), .anchor = .foot, .authored_size = .{ 0.364, 0.36 }, .side_authored_size = .{ 0.455, 0.36 }, .pivot = .{ 0.70, 0.62 }, .side_pivot = .{ 0.763, 0.62 }, .fit = visual_geometry.fitContract(.shoe_strap) },

    .{ .stable_id = "velvet_puff_blouse_torso", .semantic = semantic(25_012), .anchor = .torso, .authored_size = .{ 0.804, 1.24 }, .side_authored_size = .{ 0.806, 1.24 }, .pivot = .{ 0.504, 0.50 }, .side_pivot = .{ 0.442, 0.50 }, .fit = torsoFit("velvet_puff_blouse_torso", .torso_sleeveless) },
    .{ .stable_id = "crimson_one_shoulder_top", .semantic = semantic(25_013), .anchor = .torso, .authored_size = .{ 1.067, 1.20 }, .side_authored_size = .{ 0.926, 1.20 }, .pivot = .{ 0.816, 0.478 }, .side_pivot = .{ 0.540, 0.478 }, .fit = torsoFit("crimson_one_shoulder_top", .torso_sleeveless) },
    .{ .stable_id = "ruby_fitted_jacket_torso", .semantic = semantic(25_014), .anchor = .torso, .authored_size = .{ 0.896, 1.24 }, .side_authored_size = .{ 0.702, 1.24 }, .pivot = .{ 0.357, 0.50 }, .side_pivot = .{ 0.311, 0.50 }, .fit = torsoFit("ruby_fitted_jacket_torso", .torso_sleeveless) },
    .{ .stable_id = "ribbon_bodice", .semantic = semantic(25_015), .anchor = .torso, .authored_size = .{ 0.949, 1.20 }, .side_authored_size = .{ 0.967, 1.20 }, .pivot = .{ 0.50, 0.478 }, .side_pivot = .{ 0.30, 0.478 }, .fit = torsoFit("ribbon_bodice", .torso_sleeveless) },
    .{ .stable_id = "crimson_cardigan_sleeve", .semantic = semantic(25_016), .anchor = .upper_arm, .authored_size = .{ 0.30, 0.86 }, .pivot = .{ 0.50, 0.939462 }, .side_pivot = .{ 0.50, 0.939414 }, .fit = visual_geometry.fitContract(.sleeve_fitted) },
    .{ .stable_id = "ivory_blouse_sleeve", .semantic = semantic(25_017), .anchor = .upper_arm, .authored_size = .{ 0.40, 0.88 }, .pivot = .{ 0.50, 0.938537 }, .side_pivot = .{ 0.50, 0.948242 }, .fit = visual_geometry.fitContract(.sleeve_puff) },
    .{ .stable_id = "velvet_puff_sleeve", .semantic = semantic(25_018), .anchor = .upper_arm, .authored_size = .{ 0.42, 0.90 }, .pivot = .{ 0.50, 0.939437 }, .side_pivot = .{ 0.50, 0.939819 }, .fit = visual_geometry.fitContract(.sleeve_puff) },
    .{ .stable_id = "ruby_fitted_sleeve", .semantic = semantic(25_019), .anchor = .upper_arm, .authored_size = .{ 0.28, 0.86 }, .pivot = .{ 0.50, 0.948577 }, .side_pivot = .{ 0.50, 0.948571 }, .fit = visual_geometry.fitContract(.sleeve_fitted) },
    .{ .stable_id = "crimson_long_glove", .semantic = semantic(25_020), .anchor = .hand, .authored_size = .{ 0.38, 0.72 }, .pivot = .{ 0.50, 0.12 }, .fit = visual_geometry.fitContract(.glove_long) },
    .{ .stable_id = "ivory_wrist_cuff", .semantic = semantic(25_021), .anchor = .hand, .authored_size = .{ 0.36, 0.32 }, .pivot = .{ 0.50, 0.20 }, .fit = visual_geometry.fitContract(.wrist_cuff) },
    .{ .stable_id = "ribbon_waist_sash", .semantic = semantic(25_022), .anchor = .waist, .authored_size = .{ 0.836, 0.48 }, .side_authored_size = .{ 0.759, 0.48 }, .pivot = .{ 0.50, 0.45 }, .fit = visual_geometry.fitContract(.waist_sash) },
    .{ .stable_id = "ebony_waist_belt", .semantic = semantic(25_023), .anchor = .waist, .authored_size = .{ 0.827, 0.25 }, .side_authored_size = .{ 0.745, 0.25 }, .pivot = .{ 0.50, 0.50 }, .fit = visual_geometry.fitContract(.waist_belt) },

    .{ .stable_id = "crimson_tailored_shorts", .semantic = semantic(25_024), .anchor = .pelvis, .authored_size = .{ 0.797, 0.68 }, .side_authored_size = .{ 0.727, 0.68 }, .pivot = .{ 0.50, 0.10 }, .male_front_pivot_y = 0.071, .female_front_pivot_y = 0.430, .male_side_pivot_y = 0.287, .female_side_pivot_y = 0.271, .fit = visual_geometry.fitContract(.lower_shorts) },
    .{ .stable_id = "scarlet_sport_shorts", .semantic = semantic(25_025), .anchor = .pelvis, .authored_size = .{ 0.790, 0.64 }, .side_authored_size = .{ 0.713, 0.67 }, .pivot = .{ 0.50, 0.06 }, .male_front_pivot_y = 0.016, .female_front_pivot_y = 0.396, .male_side_pivot_y = 0.246, .female_side_pivot_y = 0.230, .fit = lowerFit("scarlet_sport_shorts", .lower_shorts) },
    .{ .stable_id = "rose_romper_lower", .semantic = semantic(25_026), .anchor = .pelvis, .authored_size = .{ 0.793, 0.68 }, .side_authored_size = .{ 0.712, 0.68 }, .pivot = .{ 0.50, 0.07 }, .male_front_pivot_y = 0.064, .female_front_pivot_y = 0.420, .male_side_pivot_y = 0.289, .female_side_pivot_y = 0.274, .fit = visual_geometry.fitContract(.lower_shorts) },
    .{ .stable_id = "ruby_day_dress_lower", .semantic = semantic(25_027), .anchor = .pelvis, .authored_size = .{ 0.844, 1.42 }, .side_authored_size = .{ 0.770, 1.42 }, .pivot = .{ 0.50, 0.62 }, .male_front_pivot_y = 0.525, .female_front_pivot_y = 0.697, .male_side_pivot_y = 0.629, .female_side_pivot_y = 0.621, .fit = lowerFit("ruby_day_dress_lower", .lower_long) },
    .{ .stable_id = "velvet_mini_skirt", .semantic = semantic(25_028), .anchor = .pelvis, .authored_size = .{ 0.814, 0.72 }, .side_authored_size = .{ 0.733, 0.75 }, .pivot = .{ 0.50, 0.10 }, .male_front_pivot_y = 0.115, .female_front_pivot_y = 0.460, .male_side_pivot_y = 0.323, .female_side_pivot_y = 0.308, .fit = lowerFit("velvet_mini_skirt", .lower_mini) },
    .{ .stable_id = "crimson_highwaist_pants", .semantic = semantic(25_029), .anchor = .pelvis, .authored_size = .{ 0.798, 1.62 }, .side_authored_size = .{ 0.713, 1.62 }, .pivot = .{ 0.50, 0.58 }, .male_front_pivot_y = 0.574, .female_front_pivot_y = 0.736, .male_side_pivot_y = 0.676, .female_side_pivot_y = 0.669, .fit = lowerFit("crimson_highwaist_pants", .lower_pants) },
    .{ .stable_id = "ruby_fitted_pants", .semantic = semantic(25_030), .anchor = .pelvis, .authored_size = .{ 0.810, 1.62 }, .side_authored_size = .{ 0.741, 1.62 }, .pivot = .{ 0.50, 0.58 }, .male_front_pivot_y = 0.577, .female_front_pivot_y = 0.729, .male_side_pivot_y = 0.669, .female_side_pivot_y = 0.662, .fit = lowerFit("ruby_fitted_pants", .lower_pants) },
    .{ .stable_id = "ivory_side_laced_shorts", .semantic = semantic(25_031), .anchor = .pelvis, .authored_size = .{ 0.780, 0.70 }, .side_authored_size = .{ 0.713, 0.70 }, .pivot = .{ 0.50, 0.10 }, .male_front_pivot_y = 0.100, .female_front_pivot_y = 0.437, .male_side_pivot_y = 0.300, .female_side_pivot_y = 0.285, .fit = visual_geometry.fitContract(.lower_shorts) },
    .{ .stable_id = "garnet_split_skirt", .semantic = semantic(25_032), .anchor = .pelvis, .authored_size = .{ 1.30, 1.72 }, .pivot = .{ 0.50, 0.61 }, .male_front_pivot_y = 0.657, .female_front_pivot_y = 0.798, .male_side_pivot_y = 0.743, .female_side_pivot_y = 0.738, .fit = splitSkirtFit() },
    .{ .stable_id = "crimson_thigh_high", .semantic = semantic(25_033), .anchor = .lower_leg, .authored_size = .{ 0.38, 0.957 }, .pivot = .{ 0.50, 0.055 }, .side_pivot = .{ 0.50, 0.055 }, .female_side_pivot_y = 0.057, .fit = visual_geometry.fitContract(.legwear_fitted) },
    .{ .stable_id = "rose_mesh_legwear", .semantic = semantic(25_034), .anchor = .lower_leg, .authored_size = .{ 0.40, 0.957 }, .pivot = .{ 0.50, 0.08 }, .side_pivot = .{ 0.50, 0.09 }, .male_side_pivot_y = 0.062, .female_side_pivot_y = 0.058, .fit = visual_geometry.fitContract(.legwear_fitted) },
    .{ .stable_id = "ember_pattern_legwear", .semantic = semantic(25_035), .anchor = .lower_leg, .authored_size = .{ 0.42, 0.957 }, .pivot = .{ 0.50, 0.08 }, .side_pivot = .{ 0.50, 0.09 }, .male_side_pivot_y = 0.061, .female_side_pivot_y = 0.057, .fit = fitWithViewCoverage(.legwear_fitted, 0.55, 0.15) },
};

pub const skirt_secondary_motion = secondary_motion.Definition{
    .dynamic_point_count = 3,
    .rest_offsets = .{
        .{ .x = 0, .y = -0.40 },
        .{ .x = 0, .y = -0.82 },
        .{ .x = 0, .y = -1.24 },
        math.Vec2.zero,
    },
    .spring_configuration = .{
        .stiffness = 84,
        .damping = 16,
        .maximum_displacement = 0.28,
        .maximum_velocity = 4.2,
    },
    .gravity_displacement = .{ .x = 0, .y = -0.06 },
    .acceleration_response = .{ .x = 0.008, .y = 0.006 },
    .velocity_response = .{ .x = 0.022, .y = 0.012 },
    .chain_follow = 0.38,
    .landing_impulse_scale = 0.045,
    .output_translation_scale = 0.30,
    .maximum_rotation_radians = 0.42,
};

const sleeve_secondary_motion = secondary_motion.Definition{
    .dynamic_point_count = 2,
    .rest_offsets = .{
        .{ .x = 0.28, .y = 0 },
        .{ .x = 0.58, .y = 0 },
        math.Vec2.zero,
        math.Vec2.zero,
    },
    .spring_configuration = .{
        .stiffness = 142,
        .damping = 23,
        .maximum_displacement = 0.10,
        .maximum_velocity = 2.4,
    },
    .gravity_displacement = .{ .x = 0, .y = -0.014 },
    .acceleration_response = .{ .x = 0.002, .y = 0.002 },
    .velocity_response = .{ .x = 0.006, .y = 0.004 },
    .chain_follow = 0.24,
    .landing_impulse_scale = 0.010,
    .output_translation_scale = 0.16,
    .maximum_rotation_radians = 0.15,
};

pub const Preset = struct {
    id: OutfitPresetId,
    stable_id: []const u8,
    item_ids: [maximum_preset_items]equipment.EquipmentItemId = undefined,
    item_count: u8 = 0,

    pub fn items(preset: *const Preset) []const equipment.EquipmentItemId {
        return preset.item_ids[0..preset.item_count];
    }
};

const PresetSpec = struct {
    stable_id: []const u8,
    item_names: []const []const u8,
};

pub const preset_specs = [_]PresetSpec{
    .{ .stable_id = "wide_brim_crimson", .item_names = &.{ "crimson_wide_brim_hat", "crimson_halter_top", "crimson_tailored_shorts", "crimson_thigh_high", "crimson_strap_shoes" } },
    .{ .stable_id = "garnet_formal", .item_names = &.{ "garnet_wrap_bodice", "garnet_split_skirt", "crimson_long_gloves", "crimson_strap_shoes" } },
    .{ .stable_id = "scarlet_sport", .item_names = &.{ "scarlet_sport_top", "scarlet_sport_shorts", "crimson_strap_shoes" } },
    .{ .stable_id = "ribbon_sash", .item_names = &.{ "ribbon_bodice", "ivory_side_laced_shorts", "ribbon_waist_sash", "crimson_strap_shoes" } },
    .{ .stable_id = "rose_romper", .item_names = &.{ "rose_romper", "rose_pillbox_hat", "crimson_strap_shoes" } },
    .{ .stable_id = "moon_cuffs", .item_names = &.{ "moon_ear_headband", "crimson_halter_top", "crimson_tailored_shorts", "rose_mesh_legwear", "ivory_wrist_cuffs", "crimson_strap_shoes" } },
    .{ .stable_id = "crimson_cardigan", .item_names = &.{ "crimson_cardigan", "crimson_tailored_shorts", "crimson_strap_shoes" } },
    .{ .stable_id = "ivory_blouse_red_shorts", .item_names = &.{ "ivory_blouse", "crimson_tailored_shorts", "crimson_strap_shoes" } },
    .{ .stable_id = "ember_fantasy", .item_names = &.{ "ember_crescent_headband", "garnet_wrap_bodice", "crimson_tailored_shorts", "ember_pattern_legwear", "crimson_strap_shoes" } },
    .{ .stable_id = "base_only", .item_names = &.{} },
    .{ .stable_id = "ruby_day_dress", .item_names = &.{ "ruby_day_dress", "ebony_waist_belt", "crimson_strap_shoes" } },
    .{ .stable_id = "velvet_puff", .item_names = &.{ "velvet_puff_blouse", "velvet_mini_skirt", "ebony_waist_belt", "crimson_strap_shoes" } },
    .{ .stable_id = "one_shoulder_trouser", .item_names = &.{ "crimson_one_shoulder_top", "crimson_highwaist_pants", "ebony_waist_belt", "crimson_long_gloves", "crimson_strap_shoes" } },
    .{ .stable_id = "rose_pillbox", .item_names = &.{ "rose_pillbox_hat", "crimson_halter_top", "rose_mesh_legwear", "crimson_long_gloves", "crimson_strap_shoes" } },
    .{ .stable_id = "ruby_fitted_suit", .item_names = &.{ "ruby_fitted_suit", "crimson_long_gloves", "crimson_strap_shoes" } },
};

pub const Catalog = struct {
    long_skirt_fallback_mesh: mesh.Definition,
    equipment_definition: equipment.Definition,
    presets: [preset_count]Preset,

    pub fn init(
        allocator: std.mem.Allocator,
        humanoid_definition: *const humanoid.HumanoidDefinition,
    ) !Catalog {
        const anatomy_definition = if (humanoid_definition.anatomy_definition) |*value|
            value.view()
        else
            return error.WardrobeRequiresAnatomy;
        const appearance_definition = humanoid_definition.visual_definition.view();

        const mesh_vertices = [_]mesh.VertexInput{
            .{ .local_position = .{ .x = -0.60, .y = 0.0 }, .uv = .{ 0, 0 }, .deformation_weight = 0.15 },
            .{ .local_position = .{ .x = 0.60, .y = 0.0 }, .uv = .{ 1, 0 }, .deformation_weight = 0.15 },
            .{ .local_position = .{ .x = -0.70, .y = -0.82 }, .uv = .{ 0, 0.5 }, .deformation_weight = 0.62 },
            .{ .local_position = .{ .x = 0.70, .y = -0.82 }, .uv = .{ 1, 0.5 }, .deformation_weight = 0.62 },
            .{ .local_position = .{ .x = -0.74, .y = -1.62 }, .uv = .{ 0, 1 }, .deformation_weight = 1.0 },
            .{ .local_position = .{ .x = 0.74, .y = -1.62 }, .uv = .{ 1, 1 }, .deformation_weight = 1.0 },
        };
        const mesh_indices = [_]u16{ 0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4 };
        var long_skirt_fallback_mesh = try mesh.Definition.init(allocator, .{
            .stable_id = "p25_skirt_fallback_mesh",
            .vertices = &mesh_vertices,
            .indices = &mesh_indices,
            .material = .{
                .stable_id = "p25_skirt_fallback_material",
                .texture_page = 0,
                .tint = .{ 1, 1, 1, 1 },
            },
        });
        errdefer long_skirt_fallback_mesh.deinit();

        var components: [visual_count]equipment.VisualComponentInput = undefined;
        for (visual_specs, 0..) |spec, index| {
            const is_skirt = spec.semantic == semantic(25_032);
            const is_loose_sleeve = spec.semantic == semantic(25_016) or
                spec.semantic == semantic(25_017) or
                spec.semantic == semantic(25_018);
            components[index] = .{
                .stable_id = spec.stable_id,
                .presentation_semantic = spec.semantic,
                .sprite_size = .{ .x = spec.authored_size[0], .y = spec.authored_size[1] },
                .pivot = spec.pivot,
                .tint = .{ 1, 1, 1, 1 },
                .deformation_response = responseFor(spec.anchor),
                .secondary_motion = if (is_skirt)
                    skirt_secondary_motion
                else if (is_loose_sleeve)
                    sleeve_secondary_motion
                else
                    null,
                .primitive = if (is_skirt)
                    .{ .deformable_mesh = long_skirt_fallback_mesh.view() }
                else
                    .rigid_sprite,
            };
        }

        const slots = [_]equipment.EquipmentSlotInput{
            .{ .stable_id = "headwear" },
            .{ .stable_id = "torso" },
            .{ .stable_id = "torso_outer" },
            .{ .stable_id = "sleeves" },
            .{ .stable_id = "sleeves_outer" },
            .{ .stable_id = "lower" },
            .{ .stable_id = "legwear" },
            .{ .stable_id = "footwear" },
            .{ .stable_id = "gloves" },
            .{ .stable_id = "wrist" },
            .{ .stable_id = "waist" },
        };
        const roles = [_]equipment.AnatomyRoleInput{
            .{ .stable_id = "head_role", .compatible_part_type = "head" },
            .{ .stable_id = "torso_role", .compatible_part_type = "torso" },
            .{ .stable_id = "pelvis_role", .compatible_part_type = "pelvis" },
            .{ .stable_id = "upper_arm_role", .compatible_part_type = "upper_arm" },
            .{ .stable_id = "hand_role", .compatible_part_type = "hand" },
            .{ .stable_id = "lower_leg_role", .compatible_part_type = "lower_leg" },
            .{ .stable_id = "foot_role", .compatible_part_type = "foot" },
        };
        const layers = [_]equipment.VisualLayerInput{
            .{ .stable_id = "lower", .render_layer = 66 },
            .{ .stable_id = "upper", .render_layer = 68 },
            .{ .stable_id = "sleeves", .render_layer = 69 },
            .{ .stable_id = "long_lower", .render_layer = 70 },
            .{ .stable_id = "legwear", .render_layer = 71 },
            .{ .stable_id = "footwear", .render_layer = 72 },
            .{ .stable_id = "gloves", .render_layer = 73 },
            .{ .stable_id = "upper_outer", .render_layer = 74 },
            .{ .stable_id = "sleeves_outer", .render_layer = 75 },
            .{ .stable_id = "waist", .render_layer = 76 },
            .{ .stable_id = "headwear", .render_layer = 80 },
        };
        const attributes = [_]equipment.AttributeDefinitionInput{
            .{ .stable_id = "movement_speed", .base_value = 4.5, .minimum = 0.1, .maximum = 20 },
            .{ .stable_id = "jump_strength", .base_value = 9, .minimum = 3.51, .maximum = 30 },
        };
        const capabilities = [_]equipment.CapabilityDefinitionInput{
            .{ .stable_id = "double_jump", .granted_by_default = true },
            .{ .stable_id = "dash", .granted_by_default = true },
        };

        const items = comptime wardrobeItems();
        var equipment_definition = try equipment.Definition.init(
            allocator,
            anatomy_definition,
            appearance_definition,
            .{
                .equipment_slots = &slots,
                .anatomy_roles = &roles,
                .visual_layers = &layers,
                .visual_components = &components,
                .attributes = &attributes,
                .capabilities = &capabilities,
                .items = &items,
                .default_loadout = &.{},
            },
        );
        errdefer equipment_definition.deinit();

        var presets: [preset_count]Preset = undefined;
        for (preset_specs, 0..) |spec, index| {
            if (spec.item_names.len > maximum_preset_items) return error.OutfitPresetCapacityExceeded;
            presets[index] = .{
                .id = @enumFromInt(index),
                .stable_id = spec.stable_id,
                .item_count = @intCast(spec.item_names.len),
            };
            for (spec.item_names, 0..) |item_name, item_index| {
                presets[index].item_ids[item_index] = try equipment_definition.itemId(item_name);
            }
        }

        var catalog = Catalog{
            .long_skirt_fallback_mesh = long_skirt_fallback_mesh,
            .equipment_definition = equipment_definition,
            .presets = presets,
        };
        try catalog.validate();
        return catalog;
    }

    pub fn deinit(catalog: *Catalog) void {
        catalog.equipment_definition.deinit();
        catalog.long_skirt_fallback_mesh.deinit();
        catalog.* = undefined;
    }

    pub fn presetId(catalog: *const Catalog, stable_id: []const u8) !OutfitPresetId {
        for (catalog.presets) |candidate| {
            if (std.mem.eql(u8, candidate.stable_id, stable_id)) return candidate.id;
        }
        return error.MissingOutfitPreset;
    }

    pub fn preset(catalog: *const Catalog, id: OutfitPresetId) !*const Preset {
        if (id.index() >= catalog.presets.len) return error.InvalidOutfitPresetId;
        return &catalog.presets[id.index()];
    }

    pub fn nextPreset(catalog: *const Catalog, current: OutfitPresetId) !OutfitPresetId {
        _ = try catalog.preset(current);
        return @enumFromInt((current.index() + 1) % catalog.presets.len);
    }

    pub fn customItems(catalog: *const Catalog) ![custom_item_count]equipment.EquipmentItemId {
        return .{
            try catalog.equipment_definition.itemId("crimson_wide_brim_hat"),
            try catalog.equipment_definition.itemId("ivory_blouse"),
            try catalog.equipment_definition.itemId("crimson_cardigan"),
            try catalog.equipment_definition.itemId("velvet_mini_skirt"),
            try catalog.equipment_definition.itemId("ember_pattern_legwear"),
            try catalog.equipment_definition.itemId("crimson_long_gloves"),
            try catalog.equipment_definition.itemId("crimson_strap_shoes"),
        };
    }

    pub fn validate(catalog: *const Catalog) !void {
        if (catalog.equipment_definition.visual_components.len != visual_count or
            catalog.presets.len != preset_count)
        {
            return error.WardrobeCatalogCountMismatch;
        }
        for (catalog.equipment_definition.visual_components) |component| {
            if (component.presentation_semantic == null) return error.MissingPresentationSemantic;
        }
        for (catalog.equipment_definition.items) |item| {
            if (item.modifier_count != 0 or item.capability_count != 0) {
                return error.CosmeticWardrobeHasGameplayEffect;
            }
        }
        _ = try catalog.presetId("wide_brim_crimson");
        _ = try catalog.presetId("ivory_blouse_red_shorts");
        const custom = try catalog.customItems();
        for (custom, 0..) |candidate, index| {
            for (custom[0..index]) |prior| {
                if (candidate == prior) return error.DuplicateCustomOutfitItem;
            }
        }
    }
};

fn responseFor(anchor: AnchorKind) deformation.Response {
    return switch (anchor) {
        .torso => .{ .morphology = 1.0, .breathing = 0.92 },
        // Fitted equipment follows the same authoritative morphology as its
        // bound anatomy. Reduced response factors visibly detached headwear,
        // footwear, sleeves, legwear, and lower garments at supported build
        // extremes. Breathing response remains design-specific.
        .pelvis => .{ .morphology = 1.0, .breathing = 0.12 },
        .upper_arm => .{ .morphology = 1.0, .breathing = 0.72 },
        .hand, .lower_leg, .foot => .{ .morphology = 1.0, .breathing = 0 },
        .head, .waist => .{ .morphology = 1.0, .breathing = 0 },
    };
}

fn torsoLocal() math.Transform2D {
    // Anatomy binds the torso at the chest point (+0.65 from the torso bone);
    // the canonical torso visual center is +0.56, so -0.09 aligns the layers.
    return math.Transform2D.init(.{ .x = 0, .y = -0.065 }, 0, math.Vec2.one);
}

fn firstRecipe(
    component: []const u8,
    role: []const u8,
    region: []const u8,
    layer: []const u8,
    local: math.Transform2D,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component,
        .binding = .{ .anatomy = .{
            .role = role,
            .selection = .first_compatible,
            .maximum_matches = 1,
        } },
        .local_to_binding = local,
        .body_region = region,
        .visual_layer = layer,
    };
}

fn everyRecipe(
    component: []const u8,
    role: []const u8,
    maximum_matches: u16,
    region: []const u8,
    layer: []const u8,
) equipment.ItemVisualRecipeInput {
    return everyRecipeAt(
        component,
        role,
        maximum_matches,
        region,
        layer,
        math.Transform2D.identity(),
    );
}

fn everyRecipeAt(
    component: []const u8,
    role: []const u8,
    maximum_matches: u16,
    region: []const u8,
    layer: []const u8,
    local: math.Transform2D,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component,
        .binding = .{ .anatomy = .{
            .role = role,
            .selection = .every_compatible,
            .maximum_matches = maximum_matches,
        } },
        .local_to_binding = local,
        .body_region = region,
        .visual_layer = layer,
    };
}

fn attachmentRecipe(
    component: []const u8,
    attachment_point: []const u8,
    region: []const u8,
    layer: []const u8,
    local: math.Transform2D,
) equipment.ItemVisualRecipeInput {
    return .{
        .component = component,
        .binding = .{ .attachment_point = attachment_point },
        .local_to_binding = local,
        .body_region = region,
        .visual_layer = layer,
    };
}

fn cosmeticItem(
    stable_id: []const u8,
    slots: []const []const u8,
    recipes: []const equipment.ItemVisualRecipeInput,
    coverage: []const []const u8,
) equipment.EquipmentItemInput {
    return .{
        .stable_id = stable_id,
        .occupied_slots = slots,
        .visual_recipes = recipes,
        .covered_body_regions = coverage,
        .attribute_modifiers = &.{},
        .capability_grants = &.{},
    };
}

fn wardrobeItems() [30]equipment.EquipmentItemInput {
    return .{
        cosmeticItem("crimson_wide_brim_hat", &.{"headwear"}, &.{firstRecipe("crimson_wide_brim_hat", "head_role", "head", "headwear", math.Transform2D.init(.{ .x = -0.28, .y = 0.304 }, 0, math.Vec2.one))}, &.{"head"}),
        cosmeticItem("moon_ear_headband", &.{"headwear"}, &.{firstRecipe("moon_ear_headband", "head_role", "head", "headwear", math.Transform2D.init(.{ .x = -0.28, .y = 0.43 }, 0, math.Vec2.one))}, &.{"head"}),
        cosmeticItem("ember_crescent_headband", &.{"headwear"}, &.{firstRecipe("ember_crescent_headband", "head_role", "head", "headwear", math.Transform2D.init(.{ .x = -0.28, .y = 0.40 }, 0, math.Vec2.one))}, &.{"head"}),
        cosmeticItem("rose_pillbox_hat", &.{"headwear"}, &.{firstRecipe("rose_pillbox_hat", "head_role", "head", "headwear", math.Transform2D.init(.{ .x = -0.28, .y = 0.45 }, 0, math.Vec2.one))}, &.{"head"}),
        cosmeticItem("crimson_halter_top", &.{"torso"}, &.{firstRecipe("crimson_halter_top", "torso_role", "torso", "upper", torsoLocal())}, &.{"torso"}),
        cosmeticItem("garnet_wrap_bodice", &.{"torso"}, &.{firstRecipe("garnet_wrap_bodice", "torso_role", "torso", "upper", torsoLocal())}, &.{"torso"}),
        cosmeticItem("scarlet_sport_top", &.{"torso"}, &.{firstRecipe("scarlet_sport_top", "torso_role", "torso", "upper", torsoLocal())}, &.{"torso"}),
        cosmeticItem("rose_romper", &.{ "torso", "lower" }, &.{
            firstRecipe("rose_romper_torso", "torso_role", "torso", "upper", torsoLocal()),
            firstRecipe("rose_romper_lower", "pelvis_role", "pelvis", "lower", math.Transform2D.identity()),
        }, &.{ "torso", "pelvis" }),
        cosmeticItem("crimson_cardigan", &.{ "torso_outer", "sleeves_outer" }, &.{
            firstRecipe("crimson_cardigan_torso", "torso_role", "torso", "upper_outer", torsoLocal()),
            everyRecipeAt(
                "crimson_cardigan_sleeve",
                "upper_arm_role",
                4,
                "left_arm",
                "sleeves_outer",
                math.Transform2D.init(
                    .{ .x = sleeve_shoulder_offset_metres, .y = 0 },
                    0,
                    math.Vec2.one,
                ),
            ),
        }, &.{ "torso", "left_arm", "right_arm" }),
        cosmeticItem("ivory_blouse", &.{ "torso", "sleeves" }, &.{
            firstRecipe("ivory_blouse_torso", "torso_role", "torso", "upper", torsoLocal()),
            everyRecipeAt(
                "ivory_blouse_sleeve",
                "upper_arm_role",
                4,
                "left_arm",
                "sleeves",
                math.Transform2D.init(
                    .{ .x = sleeve_shoulder_offset_metres, .y = 0 },
                    0,
                    math.Vec2.one,
                ),
            ),
        }, &.{ "torso", "left_arm", "right_arm" }),
        cosmeticItem("ruby_day_dress", &.{ "torso", "lower" }, &.{
            firstRecipe("ruby_day_dress_torso", "torso_role", "torso", "upper", torsoLocal()),
            firstRecipe("ruby_day_dress_lower", "pelvis_role", "pelvis", "long_lower", math.Transform2D.identity()),
        }, &.{ "torso", "pelvis", "left_leg", "right_leg" }),
        cosmeticItem("crimson_strap_shoes", &.{"footwear"}, &.{everyRecipeAt(
            "crimson_strap_shoe",
            "foot_role",
            2,
            "left_foot",
            "footwear",
            // The presentation projection already resolves the semantic foot
            // binding at the authored shoe pivot. An additional heel-length
            // translation displaced the visible shoe away from the foot.
            math.Transform2D.init(
                .{ .x = footwear_ankle_offset_metres, .y = 0 },
                0,
                math.Vec2.one,
            ),
        )}, &.{ "left_foot", "right_foot" }),
        cosmeticItem("velvet_puff_blouse", &.{ "torso", "sleeves" }, &.{
            firstRecipe("velvet_puff_blouse_torso", "torso_role", "torso", "upper", torsoLocal()),
            everyRecipeAt(
                "velvet_puff_sleeve",
                "upper_arm_role",
                4,
                "left_arm",
                "sleeves",
                math.Transform2D.init(
                    .{ .x = sleeve_shoulder_offset_metres, .y = 0 },
                    0,
                    math.Vec2.one,
                ),
            ),
        }, &.{ "torso", "left_arm", "right_arm" }),
        cosmeticItem("crimson_one_shoulder_top", &.{"torso"}, &.{firstRecipe("crimson_one_shoulder_top", "torso_role", "torso", "upper", torsoLocal())}, &.{"torso"}),
        cosmeticItem("ruby_fitted_suit", &.{ "torso", "sleeves", "lower" }, &.{
            firstRecipe("ruby_fitted_jacket_torso", "torso_role", "torso", "upper", torsoLocal()),
            everyRecipeAt(
                "ruby_fitted_sleeve",
                "upper_arm_role",
                4,
                "left_arm",
                "sleeves",
                math.Transform2D.init(
                    .{ .x = sleeve_shoulder_offset_metres, .y = 0 },
                    0,
                    math.Vec2.one,
                ),
            ),
            firstRecipe("ruby_fitted_pants", "pelvis_role", "pelvis", "lower", math.Transform2D.identity()),
        }, &.{ "torso", "left_arm", "right_arm", "pelvis", "left_leg", "right_leg" }),
        cosmeticItem("ribbon_bodice", &.{"torso"}, &.{firstRecipe("ribbon_bodice", "torso_role", "torso", "upper", torsoLocal())}, &.{"torso"}),
        cosmeticItem("crimson_long_gloves", &.{"gloves"}, &.{everyRecipe("crimson_long_glove", "hand_role", 2, "left_hand", "gloves")}, &.{ "left_hand", "right_hand" }),
        cosmeticItem("ivory_wrist_cuffs", &.{"wrist"}, &.{everyRecipe("ivory_wrist_cuff", "hand_role", 2, "left_hand", "gloves")}, &.{ "left_hand", "right_hand" }),
        cosmeticItem("ribbon_waist_sash", &.{"waist"}, &.{attachmentRecipe("ribbon_waist_sash", "waist_pelvis", "pelvis", "waist", .identity())}, &.{}),
        cosmeticItem("ebony_waist_belt", &.{"waist"}, &.{attachmentRecipe("ebony_waist_belt", "waist_pelvis", "pelvis", "waist", math.Transform2D.init(.{ .x = 0, .y = 0.05 }, 0, math.Vec2.one))}, &.{}),
        cosmeticItem("crimson_tailored_shorts", &.{"lower"}, &.{firstRecipe("crimson_tailored_shorts", "pelvis_role", "pelvis", "lower", math.Transform2D.identity())}, &.{"pelvis"}),
        cosmeticItem("scarlet_sport_shorts", &.{"lower"}, &.{firstRecipe("scarlet_sport_shorts", "pelvis_role", "pelvis", "lower", math.Transform2D.identity())}, &.{"pelvis"}),
        cosmeticItem("velvet_mini_skirt", &.{"lower"}, &.{firstRecipe("velvet_mini_skirt", "pelvis_role", "pelvis", "lower", math.Transform2D.identity())}, &.{"pelvis"}),
        cosmeticItem("crimson_highwaist_pants", &.{"lower"}, &.{firstRecipe("crimson_highwaist_pants", "pelvis_role", "pelvis", "lower", math.Transform2D.identity())}, &.{ "pelvis", "left_leg", "right_leg" }),
        cosmeticItem("ruby_fitted_pants", &.{"lower"}, &.{firstRecipe("ruby_fitted_pants", "pelvis_role", "pelvis", "lower", math.Transform2D.identity())}, &.{ "pelvis", "left_leg", "right_leg" }),
        cosmeticItem("ivory_side_laced_shorts", &.{"lower"}, &.{firstRecipe("ivory_side_laced_shorts", "pelvis_role", "pelvis", "lower", math.Transform2D.identity())}, &.{"pelvis"}),
        cosmeticItem("garnet_split_skirt", &.{"lower"}, &.{firstRecipe("garnet_split_skirt", "pelvis_role", "pelvis", "long_lower", math.Transform2D.identity())}, &.{ "pelvis", "left_leg", "right_leg" }),
        cosmeticItem("crimson_thigh_high", &.{"legwear"}, &.{everyRecipe("crimson_thigh_high", "lower_leg_role", 2, "left_leg", "legwear")}, &.{ "left_leg", "right_leg" }),
        cosmeticItem("rose_mesh_legwear", &.{"legwear"}, &.{everyRecipe("rose_mesh_legwear", "lower_leg_role", 2, "left_leg", "legwear")}, &.{ "left_leg", "right_leg" }),
        cosmeticItem("ember_pattern_legwear", &.{"legwear"}, &.{everyRecipe("ember_pattern_legwear", "lower_leg_role", 2, "left_leg", "legwear")}, &.{ "left_leg", "right_leg" }),
    };
}
