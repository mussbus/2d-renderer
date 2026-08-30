const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const attachment_secondary_motion = @import("attachment_secondary_motion");
const appearance = @import("appearance");
const anatomy = @import("anatomy");
const humanoid = @import("humanoid");
const fault_injection = @import("fault_injection");

pub const OptionalArmRootContract = enum(u8) {
    standard,
    primary_continuous,
    primary_intentional_gap,
};

pub const long_hair_secondary_motion = attachment_secondary_motion.Definition{
    .dynamic_point_count = 3,
    .rest_offsets = .{
        .{ .x = 0, .y = -0.34 },
        .{ .x = 0, .y = -0.70 },
        .{ .x = 0, .y = -1.04 },
        math.Vec2.zero,
    },
    .spring_configuration = .{
        .stiffness = 105,
        .damping = 18,
        .maximum_displacement = 0.28,
        .maximum_velocity = 4.0,
    },
    .gravity_displacement = .{ .x = 0, .y = -0.045 },
    .acceleration_response = .{ .x = 0.006, .y = 0.005 },
    .velocity_response = .{ .x = 0.020, .y = 0.012 },
    .chain_follow = 0.34,
    .landing_impulse_scale = 0.035,
    .output_translation_scale = 0.30,
    .maximum_rotation_radians = 0.42,
};

pub const ponytail_secondary_motion = attachment_secondary_motion.Definition{
    .dynamic_point_count = 3,
    .rest_offsets = .{
        .{ .x = -0.04, .y = -0.34 },
        .{ .x = -0.08, .y = -0.70 },
        .{ .x = -0.12, .y = -1.04 },
        math.Vec2.zero,
    },
    .spring_configuration = .{
        .stiffness = 82,
        .damping = 15,
        .maximum_displacement = 0.34,
        .maximum_velocity = 4.8,
    },
    .gravity_displacement = .{ .x = 0, .y = -0.055 },
    .acceleration_response = .{ .x = 0.008, .y = 0.006 },
    .velocity_response = .{ .x = 0.026, .y = 0.014 },
    .chain_follow = 0.42,
    .landing_impulse_scale = 0.045,
    .output_translation_scale = 0.34,
    .maximum_rotation_radians = 0.52,
};

const profile_names = [_][]const u8{ "simplified", "modest", "adult_detailed" };
const morphology_channel_names = [_][]const u8{
    "shoulder_width",
    "torso_width",
    "chest_depth",
    "waist_width",
    "hip_width",
    "upper_arm_thickness",
    "forearm_thickness",
    "thigh_thickness",
    "calf_thickness",
    "head_scale",
    "hand_scale",
    "foot_scale",
    "breast_scale",
    "tail_thickness",
    "horn_scale",
    "wing_scale",
    "genital_scale",
};
const morphology_preset_names = [_][]const u8{ "slim", "average", "athletic", "broad_heavy", "curvy" };
const morphology_preset_bounds = [_][2]f32{
    .{ 0.72, 0.94 },
    .{ 0.88, 1.12 },
    .{ 0.92, 1.18 },
    .{ 0.98, 1.32 },
    .{ 0.86, 1.22 },
};

const Part = enum(usize) {
    pelvis,
    torso,
    head,
    left_upper_arm,
    left_forearm,
    left_hand,
    right_upper_arm,
    right_forearm,
    right_hand,
    left_thigh,
    left_shin,
    left_foot,
    right_thigh,
    right_shin,
    right_foot,
    left_eye,
    right_eye,
    eyebrows,
    left_eyebrow,
    right_eyebrow,
    nose,
    mouth,
    left_ear,
    right_ear,
    angular_left_eye,
    angular_right_eye,
    angular_eyebrows,
    angular_left_eyebrow,
    angular_right_eyebrow,
    angular_nose,
    angular_mouth,
    angular_left_ear,
    angular_right_ear,
    short_hair,
    long_hair,
    ponytail_hair,
    left_breast,
    right_breast,
    center_breast,
    pectoral,
    penis_a,
    penis_b,
    vulva,
    extra_arm,
    extra_arm_second,
    tail,
    left_horn,
    right_horn,
};
const part_count = std.enums.values(Part).len;
const maximum_visuals_per_variant: usize = 3;

const conventional_core_parts = [_][]const u8{
    "pelvis",
    "torso",
    "head",
    "left_upper_arm",
    "left_forearm",
    "left_hand",
    "right_upper_arm",
    "right_forearm",
    "right_hand",
    "left_thigh",
    "left_shin",
    "left_foot",
    "right_thigh",
    "right_shin",
    "right_foot",
};
const conventional_male_parts = conventional_core_parts ++ [_][]const u8{ "pectoral", "penis_a" };
const conventional_female_parts = conventional_core_parts ++ [_][]const u8{ "left_breast", "right_breast", "vulva" };
const feminine_penis_parts = conventional_core_parts ++ [_][]const u8{ "left_breast", "right_breast", "penis_a" };
const dual_anatomy_parts = conventional_core_parts ++ [_][]const u8{ "left_breast", "right_breast", "penis_a", "vulva" };
const dual_penis_parts = conventional_core_parts ++ [_][]const u8{ "pectoral", "penis_a", "penis_b" };
const triple_breast_parts = conventional_core_parts ++ [_][]const u8{ "left_breast", "right_breast", "center_breast", "vulva" };
const nonstandard_parts = conventional_core_parts ++ [_][]const u8{ "extra_arm", "extra_arm_second", "tail", "left_horn", "right_horn" };
const optional_arm_primary_parts = conventional_male_parts ++
    [_][]const u8{"extra_arm"};
const optional_arm_both_parts = conventional_male_parts ++
    [_][]const u8{ "extra_arm", "extra_arm_second" };

pub fn initDefinition(allocator: std.mem.Allocator) !humanoid.HumanoidDefinition {
    return initDefinitionWithInjector(allocator, null, .standard);
}

pub fn initDefinitionWithOptionalArmRootContract(
    allocator: std.mem.Allocator,
    root_contract: OptionalArmRootContract,
) !humanoid.HumanoidDefinition {
    return initDefinitionWithInjector(allocator, null, root_contract);
}

pub fn initDefinitionWithInjector(
    allocator: std.mem.Allocator,
    injector: ?fault_injection.Injector,
    root_contract: OptionalArmRootContract,
) !humanoid.HumanoidDefinition {
    const bones = humanoid.boneInputs();
    const sockets = humanoid.socketInputs();
    const attachment_points = humanoid.attachmentPointInputs();
    const body_regions = humanoid.bodyRegionInputs();
    const visual_groups = humanoid.visualGroupInputs();

    const extra_arm_joints = [_]appearance.ModuleJointInput{
        .{ .debug_name = "shoulder", .parent_joint = null, .rest_local = math.Transform2D.identity() },
        .{ .debug_name = "elbow", .parent_joint = "shoulder", .rest_local = math.Transform2D.init(.{ .x = 0.58, .y = 0 }, 0.28, math.Vec2.one) },
        .{ .debug_name = "wrist", .parent_joint = "elbow", .rest_local = math.Transform2D.init(.{ .x = 0.48, .y = 0 }, -0.42, math.Vec2.one) },
    };
    const extra_arm_sockets = [_]appearance.ModuleSocketInput{
        .{ .debug_name = "hand_tip", .parent_joint = "wrist", .local_to_parent = math.Transform2D.init(.{ .x = 0.24, .y = 0 }, 0, math.Vec2.one) },
    };
    const tail_joints = [_]appearance.ModuleJointInput{
        .{ .debug_name = "tail_root", .parent_joint = null, .rest_local = math.Transform2D.init(.{ .x = 0, .y = -0.08 }, -1.05, math.Vec2.one) },
        .{ .debug_name = "tail_mid", .parent_joint = "tail_root", .rest_local = math.Transform2D.init(.{ .x = 0.52, .y = 0 }, 0.35, math.Vec2.one) },
        .{ .debug_name = "tail_tip", .parent_joint = "tail_mid", .rest_local = math.Transform2D.init(.{ .x = 0.44, .y = 0 }, 0.28, math.Vec2.one) },
    };
    const primary_module_root = if (root_contract ==
        .primary_intentional_gap)
        math.Transform2D.init(
            .{ .x = 0.5682, .y = 0.1382 },
            -0.55,
            math.Vec2.one,
        )
    else
        math.Transform2D.init(
            .{ .x = 0.50, .y = 0.18 },
            -0.55,
            math.Vec2.one,
        );
    const rig_modules = [_]appearance.RigModuleInput{
        .{
            .debug_name = "extra_arm_module",
            .parent_attachment_point = "chest",
            .local_to_attachment_point = primary_module_root,
            .joints = &extra_arm_joints,
            .sockets = &extra_arm_sockets,
        },
        .{
            .debug_name = "extra_arm_module_second",
            .parent_attachment_point = "chest",
            .local_to_attachment_point = math.Transform2D.init(
                .{ .x = -0.5682, .y = 0.1382 },
                3.69,
                math.Vec2.one,
            ),
            .joints = &extra_arm_joints,
            .sockets = &extra_arm_sockets,
        },
        .{
            .debug_name = "tail_module",
            .parent_attachment_point = "waist_pelvis",
            .local_to_attachment_point = math.Transform2D.identity(),
            .joints = &tail_joints,
            .sockets = &.{},
        },
    };

    const canonical_visuals = humanoid.attachmentInputs();
    var visuals: [49]appearance.VisualAttachmentInput = undefined;
    @memcpy(visuals[0..canonical_visuals.len], &canonical_visuals);
    var visual_cursor: usize = canonical_visuals.len;
    visuals[visual_cursor] = extraVisual("torso_modest", .{ .canonical_bone = 2 }, math.Transform2D.init(.{ .x = 0, .y = 0.56 }, 0, math.Vec2.one), .{ .x = 0.90, .y = 1.20 }, .{ 0.5, 0.5 }, .{ 0.25, 0.55, 0.95, 1 }, 31, "torso");
    visual_cursor += 1;
    visuals[visual_cursor] = extraVisual("torso_detailed", .{ .canonical_bone = 2 }, math.Transform2D.init(.{ .x = 0, .y = 0.56 }, 0, math.Vec2.one), .{ .x = 0.88, .y = 1.18 }, .{ 0.5, 0.5 }, .{ 0.85, 0.70, 0.52, 1 }, 31, "torso");
    visual_cursor += 1;
    const face_visuals = [_]struct { []const u8, math.Vec2, math.Vec2, [4]f32, u16 }{
        .{ "left_eye", .{ .x = -0.13, .y = 0.08 }, .{ .x = 0.09, .y = 0.07 }, .{ 0.15, 0.25, 0.55, 1 }, 44 },
        .{ "right_eye", .{ .x = 0.13, .y = 0.08 }, .{ .x = 0.09, .y = 0.07 }, .{ 0.15, 0.25, 0.55, 1 }, 44 },
        .{ "eyebrows", .{ .x = 0, .y = 0.18 }, .{ .x = 0.34, .y = 0.035 }, .{ 0.18, 0.10, 0.06, 1 }, 45 },
        .{ "left_eyebrow", .{ .x = -0.13, .y = 0.18 }, .{ .x = 0.17, .y = 0.035 }, .{ 0.18, 0.10, 0.06, 1 }, 45 },
        .{ "right_eyebrow", .{ .x = 0.13, .y = 0.18 }, .{ .x = 0.17, .y = 0.035 }, .{ 0.18, 0.10, 0.06, 1 }, 45 },
        .{ "nose", .{ .x = 0, .y = -0.01 }, .{ .x = 0.07, .y = 0.13 }, .{ 0.72, 0.42, 0.28, 1 }, 45 },
        .{ "mouth", .{ .x = 0, .y = -0.16 }, .{ .x = 0.20, .y = 0.045 }, .{ 0.65, 0.12, 0.18, 1 }, 46 },
        .{ "left_ear", .{ .x = -0.34, .y = 0 }, .{ .x = 0.07, .y = 0.16 }, .{ 0.82, 0.62, 0.45, 1 }, 42 },
        .{ "right_ear", .{ .x = 0.34, .y = 0 }, .{ .x = 0.07, .y = 0.16 }, .{ 0.82, 0.62, 0.45, 1 }, 42 },
    };
    for (face_visuals) |entry| {
        visuals[visual_cursor] = extraVisual(
            entry[0],
            .{ .attachment_point = "face" },
            math.Transform2D.init(entry[1], 0, math.Vec2.one),
            entry[2],
            .{ 0.5, 0.5 },
            entry[3],
            entry[4],
            "head",
        );
        visual_cursor += 1;
    }
    const angular_face_visuals = [_]struct { []const u8, math.Transform2D, math.Vec2, [4]f32, u16 }{
        .{ "angular_left_eye", math.Transform2D.init(.{ .x = -0.16, .y = 0.10 }, 0.16, math.Vec2.one), .{ .x = 0.13, .y = 0.055 }, .{ 0.10, 0.62, 0.38, 1 }, 44 },
        .{ "angular_right_eye", math.Transform2D.init(.{ .x = 0.16, .y = 0.10 }, -0.16, math.Vec2.one), .{ .x = 0.13, .y = 0.055 }, .{ 0.10, 0.62, 0.38, 1 }, 44 },
        .{ "angular_eyebrows", math.Transform2D.init(.{ .x = 0, .y = 0.22 }, 0, math.Vec2.one), .{ .x = 0.40, .y = 0.025 }, .{ 0.08, 0.05, 0.03, 1 }, 45 },
        .{ "angular_left_eyebrow", math.Transform2D.init(.{ .x = -0.16, .y = 0.22 }, 0.08, math.Vec2.one), .{ .x = 0.20, .y = 0.025 }, .{ 0.08, 0.05, 0.03, 1 }, 45 },
        .{ "angular_right_eyebrow", math.Transform2D.init(.{ .x = 0.16, .y = 0.22 }, -0.08, math.Vec2.one), .{ .x = 0.20, .y = 0.025 }, .{ 0.08, 0.05, 0.03, 1 }, 45 },
        .{ "angular_nose", math.Transform2D.init(.{ .x = 0, .y = -0.02 }, 0, math.Vec2.one), .{ .x = 0.045, .y = 0.18 }, .{ 0.66, 0.48, 0.34, 1 }, 45 },
        .{ "angular_mouth", math.Transform2D.init(.{ .x = 0, .y = -0.19 }, 0, math.Vec2.one), .{ .x = 0.30, .y = 0.025 }, .{ 0.52, 0.10, 0.38, 1 }, 46 },
        .{ "angular_left_ear", math.Transform2D.init(.{ .x = -0.37, .y = 0.02 }, -0.10, math.Vec2.one), .{ .x = 0.10, .y = 0.22 }, .{ 0.78, 0.58, 0.42, 1 }, 42 },
        .{ "angular_right_ear", math.Transform2D.init(.{ .x = 0.37, .y = 0.02 }, 0.10, math.Vec2.one), .{ .x = 0.10, .y = 0.22 }, .{ 0.78, 0.58, 0.42, 1 }, 42 },
    };
    for (angular_face_visuals) |entry| {
        visuals[visual_cursor] = extraVisual(
            entry[0],
            .{ .attachment_point = "face" },
            entry[1],
            entry[2],
            .{ 0.5, 0.5 },
            entry[3],
            entry[4],
            "head",
        );
        visual_cursor += 1;
    }
    const hair_visuals = [_]struct { []const u8, math.Transform2D, math.Vec2, [4]f32, ?attachment_secondary_motion.Definition }{
        .{ "short_hair", math.Transform2D.init(.{ .x = 0, .y = 0.20 }, 0, math.Vec2.one), .{ .x = 0.72, .y = 0.34 }, .{ 0.20, 0.08, 0.03, 1 }, null },
        .{ "long_hair", math.Transform2D.init(.{ .x = 0, .y = -0.08 }, 0, math.Vec2.one), .{ .x = 0.78, .y = 1.10 }, .{ 0.08, 0.05, 0.02, 1 }, long_hair_secondary_motion },
        .{ "ponytail_hair", math.Transform2D.init(.{ .x = -0.30, .y = -0.22 }, -0.18, math.Vec2.one), .{ .x = 0.22, .y = 1.08 }, .{ 0.65, 0.18, 0.06, 1 }, ponytail_secondary_motion },
    };
    for (hair_visuals) |entry| {
        visuals[visual_cursor] = extraVisual(entry[0], .{ .attachment_point = "head_scalp" }, entry[1], entry[2], .{ 0.5, 0.25 }, entry[3], 41, "head");
        visuals[visual_cursor].secondary_motion = entry[4];
        visual_cursor += 1;
    }
    for ([_]struct { []const u8, []const u8, math.Vec2, u16 }{
        .{ "extra_upper_arm", "shoulder", .{ .x = 0.58, .y = 0.14 }, 23 },
        .{ "extra_forearm", "elbow", .{ .x = 0.48, .y = 0.12 }, 24 },
        .{ "extra_hand", "wrist", .{ .x = 0.24, .y = 0.17 }, 25 },
    }) |entry| {
        visuals[visual_cursor] = extraVisual(
            entry[0],
            .{ .module_joint = .{ .module_name = "extra_arm_module", .member_name = entry[1] } },
            math.Transform2D.identity(),
            entry[2],
            .{ 0, 0.5 },
            .{ 0.55, 0.22, 0.75, 1 },
            entry[3],
            "right_arm",
        );
        visual_cursor += 1;
    }
    for ([_]struct { []const u8, []const u8, math.Vec2, u16 }{
        .{ "extra_second_upper_arm", "shoulder", .{ .x = 0.58, .y = 0.14 }, 57 },
        .{ "extra_second_forearm", "elbow", .{ .x = 0.48, .y = 0.12 }, 56 },
        .{ "extra_second_hand", "wrist", .{ .x = 0.24, .y = 0.17 }, 55 },
    }) |entry| {
        visuals[visual_cursor] = extraVisual(
            entry[0],
            .{ .module_joint = .{ .module_name = "extra_arm_module_second", .member_name = entry[1] } },
            math.Transform2D.identity(),
            entry[2],
            .{ 0, 0.5 },
            .{ 0.35, 0.28, 0.82, 1 },
            entry[3],
            "left_arm",
        );
        visual_cursor += 1;
    }
    for ([_]struct { []const u8, []const u8, math.Vec2, u16 }{
        .{ "tail_root_visual", "tail_root", .{ .x = 0.52, .y = 0.18 }, 18 },
        .{ "tail_mid_visual", "tail_mid", .{ .x = 0.44, .y = 0.15 }, 19 },
        .{ "tail_tip_visual", "tail_tip", .{ .x = 0.34, .y = 0.11 }, 20 },
    }) |entry| {
        visuals[visual_cursor] = extraVisual(
            entry[0],
            .{ .module_joint = .{ .module_name = "tail_module", .member_name = entry[1] } },
            math.Transform2D.identity(),
            entry[2],
            .{ 0, 0.5 },
            .{ 0.22, 0.60, 0.38, 1 },
            entry[3],
            "pelvis",
        );
        visual_cursor += 1;
    }
    visuals[visual_cursor] = extraVisual("left_horn_visual", .{ .attachment_point = "head_scalp" }, math.Transform2D.init(.{ .x = -0.20, .y = 0.35 }, 1.20, math.Vec2.one), .{ .x = 0.34, .y = 0.09 }, .{ 0, 0.5 }, .{ 0.92, 0.85, 0.62, 1 }, 43, "head");
    visual_cursor += 1;
    visuals[visual_cursor] = extraVisual("right_horn_visual", .{ .attachment_point = "head_scalp" }, math.Transform2D.init(.{ .x = 0.20, .y = 0.35 }, 1.94, math.Vec2.one), .{ .x = 0.34, .y = 0.09 }, .{ 0, 0.5 }, .{ 0.92, 0.85, 0.62, 1 }, 43, "head");
    visual_cursor += 1;
    if (visual_cursor != visuals.len) return error.ModularVisualCountMismatch;

    var morphology_channels: [morphology_channel_names.len]anatomy.MorphologyChannelInput = undefined;
    for (morphology_channel_names, 0..) |name, index| morphology_channels[index] = .{ .stable_id = name };
    var morphology_ranges: [morphology_preset_names.len][morphology_channel_names.len]anatomy.MorphologyRangeInput = undefined;
    var morphology_presets: [morphology_preset_names.len]anatomy.MorphologyPresetInput = undefined;
    for (morphology_preset_names, 0..) |preset_name, preset_index| {
        for (morphology_channel_names, 0..) |channel_name, channel_index| {
            morphology_ranges[preset_index][channel_index] = .{
                .channel = channel_name,
                .low = morphology_preset_bounds[preset_index][0],
                .high = morphology_preset_bounds[preset_index][1],
            };
        }
        morphology_presets[preset_index] = .{
            .stable_id = preset_name,
            .ranges = &morphology_ranges[preset_index],
        };
    }
    const presentation_profiles = [_]anatomy.PresentationProfileInput{
        .{ .stable_id = "simplified", .detail_tag = "non_explicit" },
        .{ .stable_id = "modest", .detail_tag = "covered" },
        .{ .stable_id = "adult_detailed", .detail_tag = "adult_detail_allowed" },
    };

    const pelvis_sockets = [_]anatomy.ChildSocketInput{
        .{ .stable_id = "genital_a", .local_to_part = math.Transform2D.init(.{ .x = -0.10, .y = -0.10 }, 0, math.Vec2.one), .accepted_child_tag = "adult_anatomy", .role = "pelvis_anatomy" },
        .{ .stable_id = "genital_b", .local_to_part = math.Transform2D.init(.{ .x = 0.10, .y = -0.10 }, 0, math.Vec2.one), .accepted_child_tag = "adult_anatomy", .role = "pelvis_anatomy" },
        .{ .stable_id = "vulva_region", .local_to_part = math.Transform2D.init(.{ .x = 0, .y = -0.08 }, 0, math.Vec2.one), .accepted_child_tag = "adult_anatomy", .role = "pelvis_anatomy" },
        .{ .stable_id = "left_leg", .local_to_part = math.Transform2D.identity(), .accepted_child_tag = "leg", .role = "pelvis_leg" },
        .{ .stable_id = "right_leg", .local_to_part = math.Transform2D.identity(), .accepted_child_tag = "leg", .role = "pelvis_leg" },
        .{ .stable_id = "tail", .local_to_part = math.Transform2D.identity(), .accepted_child_tag = "tail", .role = "pelvis_tail" },
    };
    const torso_sockets = [_]anatomy.ChildSocketInput{
        .{ .stable_id = "chest_left", .local_to_part = math.Transform2D.init(.{ .x = -0.18, .y = 0.20 }, 0, math.Vec2.one), .accepted_child_tag = "chest_anatomy", .role = "torso_anatomy" },
        .{ .stable_id = "chest_right", .local_to_part = math.Transform2D.init(.{ .x = 0.18, .y = 0.20 }, 0, math.Vec2.one), .accepted_child_tag = "chest_anatomy", .role = "torso_anatomy" },
        .{ .stable_id = "chest_center", .local_to_part = math.Transform2D.init(.{ .x = 0, .y = 0.18 }, 0, math.Vec2.one), .accepted_child_tag = "chest_anatomy", .role = "torso_anatomy", .capacity = 2 },
        .{ .stable_id = "left_arm", .local_to_part = math.Transform2D.identity(), .accepted_child_tag = "arm", .role = "torso_arm" },
        .{ .stable_id = "right_arm", .local_to_part = math.Transform2D.identity(), .accepted_child_tag = "arm", .role = "torso_arm" },
        .{
            .stable_id = "extra_arm_right",
            .local_to_part = math.Transform2D.init(
                .{ .x = 0.50, .y = 0.18 },
                -0.55,
                math.Vec2.one,
            ),
            .accepted_child_tag = "arm",
            .role = "torso_arm",
            .supported_connections = .{
                .continuous = true,
                .intentional_gap = true,
            },
        },
        .{
            .stable_id = "extra_arm_left",
            .local_to_part = math.Transform2D.init(
                .{ .x = -0.50, .y = 0.18 },
                3.69,
                math.Vec2.one,
            ),
            .accepted_child_tag = "arm",
            .role = "torso_arm",
            .supported_connections = .{ .continuous = true, .intentional_gap = true },
        },
    };
    const head_sockets = [_]anatomy.ChildSocketInput{
        .{ .stable_id = "face", .local_to_part = math.Transform2D.identity(), .accepted_child_tag = "face_feature", .role = "head_face", .capacity = 10 },
        .{ .stable_id = "left_eye", .local_to_part = math.Transform2D.init(.{ .x = -0.42, .y = 0.02 }, 0, math.Vec2.one), .accepted_child_tag = "eye", .role = "head_eye", .capacity = 2 },
        .{ .stable_id = "right_eye", .local_to_part = math.Transform2D.init(.{ .x = -0.14, .y = 0.02 }, 0, math.Vec2.one), .accepted_child_tag = "eye", .role = "head_eye", .capacity = 2 },
        .{ .stable_id = "scalp", .local_to_part = math.Transform2D.init(.{ .x = -0.28, .y = 0.25 }, 0, math.Vec2.one), .accepted_child_tag = "hair", .role = "head_scalp", .capacity = 3 },
        .{ .stable_id = "horn_left", .local_to_part = math.Transform2D.init(.{ .x = -0.20, .y = 0.30 }, 0, math.Vec2.one), .accepted_child_tag = "horn", .role = "head_horn" },
        .{ .stable_id = "horn_right", .local_to_part = math.Transform2D.init(.{ .x = 0.20, .y = 0.30 }, 0, math.Vec2.one), .accepted_child_tag = "horn", .role = "head_horn" },
    };
    const eye_sockets = [_]anatomy.ChildSocketInput{.{
        .stable_id = "brow",
        .local_to_part = math.Transform2D.init(.{ .x = 0, .y = 0.10 }, 0, math.Vec2.one),
        .accepted_child_tag = "eyebrow",
        .role = "eye_brow",
    }};
    const torso_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "shoulder_width", .scale_per_unit = .{ .x = 1, .y = 0 } },
        .{ .channel = "torso_width", .scale_per_unit = .{ .x = 1, .y = 0 } },
        .{ .channel = "chest_depth", .scale_per_unit = .{ .x = 0.35, .y = 0.10 } },
        .{ .channel = "waist_width", .scale_per_unit = .{ .x = 0.55, .y = 0 } },
    };
    const head_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "head_scale", .scale_per_unit = math.Vec2.one },
    };
    const upper_arm_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "upper_arm_thickness", .scale_per_unit = .{ .x = 0, .y = 1 } },
    };
    const forearm_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "forearm_thickness", .scale_per_unit = .{ .x = 0, .y = 1 } },
    };
    const hand_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "hand_scale", .scale_per_unit = math.Vec2.one },
    };
    const thigh_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "thigh_thickness", .scale_per_unit = .{ .x = 0, .y = 1 } },
    };
    const shin_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "calf_thickness", .scale_per_unit = .{ .x = 0, .y = 1 } },
    };
    const foot_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "foot_scale", .scale_per_unit = math.Vec2.one },
    };
    const breast_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "breast_scale", .scale_per_unit = math.Vec2.one },
    };
    const genital_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "genital_scale", .scale_per_unit = math.Vec2.one },
    };
    const tail_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "tail_thickness", .scale_per_unit = .{ .x = 0, .y = 1 } },
    };
    const horn_morph = [_]anatomy.MorphBindingInput{
        .{ .channel = "horn_scale", .scale_per_unit = math.Vec2.one },
    };
    var part_definitions = [_]anatomy.BodyPartDefinitionInput{
        partDefinition("pelvis_part", "core", "pelvis", &.{ "core_humanoid", "pelvis" }, &pelvis_sockets, &.{}),
        breathingPartDefinition(
            "torso_part",
            "core",
            "torso",
            &.{ "core_humanoid", "torso" },
            &torso_sockets,
            &torso_morph,
            .{
                .translation_at_unit = .{ .x = 0, .y = 0.006 },
                .scale_delta_at_unit = .{ .x = 0.03, .y = 0.012 },
            },
        ),
        partDefinition("head_part", "core", "head", &.{ "core_humanoid", "head" }, &head_sockets, &head_morph),
        breathingPartDefinition(
            "upper_arm_part",
            "limb",
            "upper_arm",
            &.{ "core_humanoid", "arm" },
            &.{},
            &upper_arm_morph,
            .{ .scale_delta_at_unit = .{ .x = 0.003, .y = 0.008 } },
        ),
        partDefinition("forearm_part", "limb", "forearm", &.{ "core_humanoid", "arm" }, &.{}, &forearm_morph),
        partDefinition("hand_part", "limb", "hand", &.{ "core_humanoid", "hand" }, &.{}, &hand_morph),
        partDefinition("thigh_part", "limb", "thigh", &.{ "core_humanoid", "leg" }, &.{}, &thigh_morph),
        partDefinition("shin_part", "limb", "lower_leg", &.{ "core_humanoid", "leg" }, &.{}, &shin_morph),
        partDefinition("foot_part", "limb", "foot", &.{ "core_humanoid", "foot" }, &.{}, &foot_morph),
        partDefinition("eye_part", "face", "eye", &.{ "face_feature", "eye" }, &eye_sockets, &.{}),
        partDefinition("eyebrow_part", "face", "eyebrow", &.{ "face_feature", "eyebrow" }, &.{}, &.{}),
        partDefinition("face_feature_part", "face", "feature", &.{"face_feature"}, &.{}, &.{}),
        partDefinition("hair_part", "appearance", "hair", &.{"hair"}, &.{}, &.{}),
        breathingPartDefinition(
            "breast_part",
            "adult_chest",
            "breast",
            &.{ "adult_anatomy", "chest_anatomy" },
            &.{},
            &breast_morph,
            .{ .scale_delta_at_unit = .{ .x = 0.015, .y = 0.01 } },
        ),
        breathingPartDefinition(
            "pectoral_part",
            "adult_chest",
            "pectoral",
            &.{ "adult_anatomy", "chest_anatomy" },
            &.{},
            &.{},
            .{ .scale_delta_at_unit = .{ .x = 0.015, .y = 0.01 } },
        ),
        partDefinition("penis_part", "adult_genital", "penis", &.{"adult_anatomy"}, &.{}, &genital_morph),
        partDefinition("vulva_part", "adult_genital", "vulva_region", &.{"adult_anatomy"}, &.{}, &genital_morph),
        partDefinition("extra_arm_part", "optional_limb", "upper_arm", &.{ "arm", "articulated_module" }, &.{}, &upper_arm_morph),
        partDefinition("tail_part", "optional_appendage", "tail", &.{ "tail", "articulated_module" }, &.{}, &tail_morph),
        partDefinition("horn_part", "optional_head", "horn", &.{"horn"}, &.{}, &horn_morph),
    };
    part_definitions[0].component.binding_mode = .frame;
    part_definitions[0].component.material_slot = "skin";
    part_definitions[0].component.morphology_response = "declared_bindings";
    part_definitions[1].component.binding_mode = .frame;
    part_definitions[1].component.material_slot = "skin";
    part_definitions[1].component.morphology_response = "declared_bindings";
    part_definitions[2].component.binding_mode = .frame;
    part_definitions[2].component.material_slot = "skin";
    part_definitions[2].component.morphology_response = "declared_bindings";
    for (part_definitions[3..9]) |*definition| {
        definition.component.binding_mode = .segment;
        definition.component.material_slot = "skin";
        definition.component.morphology_response = "declared_bindings";
    }
    part_definitions[9].component.allowed_parent_socket_role = "head_eye";
    part_definitions[9].component.material_slot = "face";
    part_definitions[10].component.allowed_parent_socket_role = "eye_brow";
    part_definitions[10].component.material_slot = "face";
    part_definitions[12].component.allowed_parent_socket_role = "head_scalp";
    part_definitions[12].component.material_slot = "hair";
    part_definitions[17].component.allowed_parent_socket_role = "torso_arm";
    part_definitions[17].component.binding_mode = .segment;
    part_definitions[17].component.supported_connections = .{
        .continuous = true,
        .intentional_gap = true,
    };
    part_definitions[17].component.rig_module_template =
        .shoulder_elbow_wrist_hand;
    part_definitions[18].component.allowed_parent_socket_role = "pelvis_tail";
    part_definitions[18].component.binding_mode = .segment;
    part_definitions[19].component.allowed_parent_socket_role = "head_horn";
    part_definitions[19].component.binding_mode = .segment;

    var variant_visual_storage: [part_count][profile_names.len][maximum_visuals_per_variant][]const u8 = undefined;
    var variants: [part_count][profile_names.len]anatomy.VisualVariantInput = undefined;
    var part_instances: [part_count]anatomy.BodyPartInstanceInput = undefined;
    setInstance(&part_instances, &variants, &variant_visual_storage, .pelvis, "pelvis", "pelvis_part", .{ .attachment_point = "waist_pelvis" }, "pelvis", 30, null, &.{"pelvis"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .torso, "torso", "torso_part", .{ .attachment_point = "chest" }, "torso", 31, null, &.{"torso"});
    setVariantVisual(&variants, &variant_visual_storage, .torso, 1, &.{"torso_modest"});
    setVariantVisual(&variants, &variant_visual_storage, .torso, 2, &.{"torso_detailed"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .head, "head", "head_part", .{ .attachment_point = "face" }, "head", 40, null, &.{"head"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_upper_arm, "left_upper_arm", "upper_arm_part", .{ .attachment_point = "left_shoulder" }, "left_arm", 20, null, &.{"left_upper_arm"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_forearm, "left_forearm", "forearm_part", .{ .attachment_point = "left_wrist" }, "left_arm", 21, null, &.{"left_forearm"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_hand, "left_hand", "hand_part", .{ .attachment_point = "left_hand" }, "left_hand", 22, null, &.{"left_hand"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_upper_arm, "right_upper_arm", "upper_arm_part", .{ .attachment_point = "right_shoulder" }, "right_arm", 60, null, &.{"right_upper_arm"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_forearm, "right_forearm", "forearm_part", .{ .attachment_point = "right_wrist" }, "right_arm", 61, null, &.{"right_forearm"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_hand, "right_hand", "hand_part", .{ .attachment_point = "right_hand" }, "right_hand", 62, null, &.{"right_hand"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_thigh, "left_thigh", "thigh_part", .{ .attachment_point = "left_ankle" }, "left_leg", 10, null, &.{"left_thigh"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_shin, "left_shin", "shin_part", .{ .attachment_point = "left_ankle" }, "left_leg", 11, null, &.{"left_shin"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_foot, "left_foot", "foot_part", .{ .attachment_point = "left_foot" }, "left_foot", 12, null, &.{"left_foot"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_thigh, "right_thigh", "thigh_part", .{ .attachment_point = "right_ankle" }, "right_leg", 50, null, &.{"right_thigh"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_shin, "right_shin", "shin_part", .{ .attachment_point = "right_ankle" }, "right_leg", 51, null, &.{"right_shin"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_foot, "right_foot", "foot_part", .{ .attachment_point = "right_foot" }, "right_foot", 52, null, &.{"right_foot"});
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_eye, "left_eye", "eye_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "left_eye" } }, "head", 44, null, &.{"left_eye"});
    part_instances[@intFromEnum(Part.left_eye)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_eye, "right_eye", "eye_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "right_eye" } }, "head", 44, null, &.{"right_eye"});
    part_instances[@intFromEnum(Part.right_eye)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_eyebrow, "left_eyebrow", "eyebrow_part", .{ .body_part_socket = .{ .part_instance = "left_eye", .socket = "brow" } }, "head", 45, null, &.{"left_eyebrow"});
    part_instances[@intFromEnum(Part.left_eyebrow)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_eyebrow, "right_eyebrow", "eyebrow_part", .{ .body_part_socket = .{ .part_instance = "right_eye", .socket = "brow" } }, "head", 45, null, &.{"right_eyebrow"});
    part_instances[@intFromEnum(Part.right_eyebrow)].topology_status = .direct;
    for ([_]struct { Part, []const u8, []const u8 }{
        .{ .eyebrows, "eyebrows", "eyebrows" },
        .{ .nose, "nose", "nose" },
        .{ .mouth, "mouth", "mouth" },
        .{ .left_ear, "left_ear", "left_ear" },
        .{ .right_ear, "right_ear", "right_ear" },
    }) |entry| setInstance(&part_instances, &variants, &variant_visual_storage, entry[0], entry[1], "face_feature_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "face" } }, "head", 45, null, &.{entry[2]});
    setInstance(&part_instances, &variants, &variant_visual_storage, .angular_left_eye, "angular_left_eye", "eye_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "left_eye" } }, "head", 44, null, &.{"angular_left_eye"});
    part_instances[@intFromEnum(Part.angular_left_eye)].local_to_parent.translation.x = -0.02;
    part_instances[@intFromEnum(Part.angular_left_eye)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .angular_right_eye, "angular_right_eye", "eye_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "right_eye" } }, "head", 44, null, &.{"angular_right_eye"});
    part_instances[@intFromEnum(Part.angular_right_eye)].local_to_parent.translation.x = 0.02;
    part_instances[@intFromEnum(Part.angular_right_eye)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .angular_left_eyebrow, "angular_left_eyebrow", "eyebrow_part", .{ .body_part_socket = .{ .part_instance = "angular_left_eye", .socket = "brow" } }, "head", 45, null, &.{"angular_left_eyebrow"});
    part_instances[@intFromEnum(Part.angular_left_eyebrow)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .angular_right_eyebrow, "angular_right_eyebrow", "eyebrow_part", .{ .body_part_socket = .{ .part_instance = "angular_right_eye", .socket = "brow" } }, "head", 45, null, &.{"angular_right_eyebrow"});
    part_instances[@intFromEnum(Part.angular_right_eyebrow)].topology_status = .direct;
    for ([_]struct { Part, []const u8, []const u8 }{
        .{ .angular_eyebrows, "angular_eyebrows", "angular_eyebrows" },
        .{ .angular_nose, "angular_nose", "angular_nose" },
        .{ .angular_mouth, "angular_mouth", "angular_mouth" },
        .{ .angular_left_ear, "angular_left_ear", "angular_left_ear" },
        .{ .angular_right_ear, "angular_right_ear", "angular_right_ear" },
    }) |entry| setInstance(&part_instances, &variants, &variant_visual_storage, entry[0], entry[1], "face_feature_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "face" } }, "head", 45, null, &.{entry[2]});
    setInstance(&part_instances, &variants, &variant_visual_storage, .short_hair, "short_hair", "hair_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "scalp" } }, "head", 41, null, &.{"short_hair"});
    part_instances[@intFromEnum(Part.short_hair)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .long_hair, "long_hair", "hair_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "scalp" } }, "head", 41, null, &.{"long_hair"});
    part_instances[@intFromEnum(Part.long_hair)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .ponytail_hair, "ponytail_hair", "hair_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "scalp" } }, "head", 41, null, &.{"ponytail_hair"});
    part_instances[@intFromEnum(Part.ponytail_hair)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_breast, "left_breast", "breast_part", .{ .body_part_socket = .{ .part_instance = "torso", .socket = "chest_left" } }, "torso", 32, null, &.{});
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_breast, "right_breast", "breast_part", .{ .body_part_socket = .{ .part_instance = "torso", .socket = "chest_right" } }, "torso", 32, null, &.{});
    setInstance(&part_instances, &variants, &variant_visual_storage, .center_breast, "center_breast", "breast_part", .{ .body_part_socket = .{ .part_instance = "torso", .socket = "chest_center" } }, "torso", 32, null, &.{});
    setInstance(&part_instances, &variants, &variant_visual_storage, .pectoral, "pectoral", "pectoral_part", .{ .body_part_socket = .{ .part_instance = "torso", .socket = "chest_center" } }, "torso", 32, null, &.{});
    setInstance(&part_instances, &variants, &variant_visual_storage, .penis_a, "penis_a", "penis_part", .{ .body_part_socket = .{ .part_instance = "pelvis", .socket = "genital_a" } }, "pelvis", 33, null, &.{});
    setInstance(&part_instances, &variants, &variant_visual_storage, .penis_b, "penis_b", "penis_part", .{ .body_part_socket = .{ .part_instance = "pelvis", .socket = "genital_b" } }, "pelvis", 33, null, &.{});
    setInstance(&part_instances, &variants, &variant_visual_storage, .vulva, "vulva", "vulva_part", .{ .body_part_socket = .{ .part_instance = "pelvis", .socket = "vulva_region" } }, "pelvis", 33, null, &.{});
    setInstance(&part_instances, &variants, &variant_visual_storage, .extra_arm, "extra_arm", "extra_arm_part", .{ .body_part_socket = .{ .part_instance = "torso", .socket = "extra_arm_right" } }, "right_arm", 23, "extra_arm_module", &.{ "extra_upper_arm", "extra_forearm", "extra_hand" });
    if (root_contract == .primary_intentional_gap) {
        part_instances[@intFromEnum(Part.extra_arm)].local_to_parent.translation.x =
            0.08;
        part_instances[@intFromEnum(Part.extra_arm)].connection = .{
            .intentional_gap = .{
                .minimum_gap = 0.07,
                .maximum_gap = 0.09,
            },
        };
    }
    part_instances[@intFromEnum(Part.extra_arm)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .extra_arm_second, "extra_arm_second", "extra_arm_part", .{ .body_part_socket = .{ .part_instance = "torso", .socket = "extra_arm_left" } }, "left_arm", 57, "extra_arm_module_second", &.{ "extra_second_upper_arm", "extra_second_forearm", "extra_second_hand" });
    part_instances[@intFromEnum(Part.extra_arm_second)].local_to_parent.translation.x = 0.08;
    part_instances[@intFromEnum(Part.extra_arm_second)].connection = .{
        .intentional_gap = .{ .minimum_gap = 0.07, .maximum_gap = 0.09 },
    };
    part_instances[@intFromEnum(Part.extra_arm_second)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .tail, "tail", "tail_part", .{ .body_part_socket = .{ .part_instance = "pelvis", .socket = "tail" } }, "pelvis", 18, "tail_module", &.{ "tail_root_visual", "tail_mid_visual", "tail_tip_visual" });
    part_instances[@intFromEnum(Part.tail)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .left_horn, "left_horn", "horn_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "horn_left" } }, "head", 43, null, &.{"left_horn_visual"});
    part_instances[@intFromEnum(Part.left_horn)].topology_status = .direct;
    setInstance(&part_instances, &variants, &variant_visual_storage, .right_horn, "right_horn", "horn_part", .{ .body_part_socket = .{ .part_instance = "head", .socket = "horn_right" } }, "head", 43, null, &.{"right_horn_visual"});
    part_instances[@intFromEnum(Part.right_horn)].topology_status = .direct;

    const face_features = [_][]const u8{ "left_eye", "right_eye", "left_eyebrow", "right_eyebrow", "nose", "mouth", "left_ear", "right_ear" };
    const angular_face_features = [_][]const u8{ "angular_left_eye", "angular_right_eye", "angular_left_eyebrow", "angular_right_eyebrow", "angular_nose", "angular_mouth", "angular_left_ear", "angular_right_ear" };
    const faces = [_]anatomy.FaceDefinitionInput{
        .{ .stable_id = "conventional_face", .head_part = "head", .feature_parts = &face_features },
        .{ .stable_id = "angular_face", .head_part = "head", .feature_parts = &angular_face_features },
    };
    const hair_definitions = [_]anatomy.HairDefinitionInput{
        .{ .stable_id = "short_rigid", .style_tag = "short_rigid", .part_instances = &.{"short_hair"} },
        .{ .stable_id = "long_rigid", .style_tag = "long", .part_instances = &.{"long_hair"} },
        .{ .stable_id = "ponytail", .style_tag = "tied", .part_instances = &.{"ponytail_hair"} },
    };
    const conventional_face = [_][]const u8{"conventional_face"};
    const angular_face = [_][]const u8{"angular_face"};
    const body_presets = [_]anatomy.BodyPresetInput{
        .{ .stable_id = "conventional_male", .active_parts = &conventional_male_parts, .faces = &conventional_face, .hair = "short_rigid", .morphology_preset = "average", .global_build = 50, .presentation_profile = "simplified", .front_shoulder_half_span_metres = 0.36 },
        .{ .stable_id = "conventional_female", .active_parts = &conventional_female_parts, .faces = &angular_face, .hair = "long_rigid", .morphology_preset = "curvy", .global_build = 50, .presentation_profile = "simplified", .front_shoulder_half_span_metres = 0.39 },
        .{ .stable_id = "feminine_with_penis", .active_parts = &feminine_penis_parts, .faces = &angular_face, .hair = "long_rigid", .morphology_preset = "curvy", .global_build = 50, .presentation_profile = "modest", .front_shoulder_half_span_metres = 0.425 },
        .{ .stable_id = "dual_genital_configuration", .active_parts = &dual_anatomy_parts, .faces = &conventional_face, .hair = "short_rigid", .morphology_preset = "average", .global_build = 50, .presentation_profile = "modest", .front_shoulder_half_span_metres = 0.425 },
        .{ .stable_id = "two_penises", .active_parts = &dual_penis_parts, .faces = &conventional_face, .hair = "short_rigid", .morphology_preset = "athletic", .global_build = 50, .presentation_profile = "modest", .front_shoulder_half_span_metres = 0.425 },
        .{ .stable_id = "three_breasts", .active_parts = &triple_breast_parts, .faces = &angular_face, .hair = "long_rigid", .morphology_preset = "curvy", .global_build = 50, .presentation_profile = "modest", .front_shoulder_half_span_metres = 0.425 },
        .{ .stable_id = "nonstandard_humanoid", .active_parts = &nonstandard_parts, .faces = &conventional_face, .hair = "ponytail", .morphology_preset = "athletic", .global_build = 70, .presentation_profile = "simplified", .front_shoulder_half_span_metres = 0.42 },
        .{ .stable_id = "optional_arm_primary_proof", .active_parts = &optional_arm_primary_parts, .faces = &conventional_face, .hair = "short_rigid", .morphology_preset = "average", .global_build = 50, .presentation_profile = "simplified", .front_shoulder_half_span_metres = 0.36 },
        .{ .stable_id = "optional_arm_two_module_proof", .active_parts = &optional_arm_both_parts, .faces = &conventional_face, .hair = "short_rigid", .morphology_preset = "average", .global_build = 50, .presentation_profile = "simplified", .front_shoulder_half_span_metres = 0.36 },
    };

    return humanoid.HumanoidDefinition.initFromVisualDefinitionAndAnatomy(
        allocator,
        &bones,
        &sockets,
        .{
            .attachment_points = &attachment_points,
            .body_regions = &body_regions,
            .visual_groups = &visual_groups,
            .rig_modules = &rig_modules,
            .visuals = &visuals,
        },
        .{
            .morphology_channels = &morphology_channels,
            .morphology_presets = &morphology_presets,
            .presentation_profiles = &presentation_profiles,
            .part_definitions = &part_definitions,
            .part_instances = &part_instances,
            .faces = &faces,
            .hair_definitions = &hair_definitions,
            .body_presets = &body_presets,
            .default_body_preset = "conventional_male",
        },
        injector,
    );
}

fn extraVisual(
    name: []const u8,
    source: appearance.TransformSourceInput,
    local: math.Transform2D,
    size: math.Vec2,
    pivot: [2]f32,
    tint: [4]f32,
    layer: u16,
    region: []const u8,
) appearance.VisualAttachmentInput {
    return .{
        .debug_name = name,
        .canonical_semantic = null,
        .transform_source = source,
        .local_to_source = local,
        .body_region = region,
        .visual_group = "body",
        .sprite_size = size,
        .pivot = pivot,
        .uv_rect = .{ 0, 0, 0.5, 0.5 },
        .tint = tint,
        .texture_page = 0,
        .body_part_layer = layer,
    };
}

fn partDefinition(
    stable_id: []const u8,
    category: []const u8,
    type_tag: []const u8,
    tags: []const []const u8,
    child_sockets: []const anatomy.ChildSocketInput,
    morph_bindings: []const anatomy.MorphBindingInput,
) anatomy.BodyPartDefinitionInput {
    return .{
        .stable_id = stable_id,
        .category_tag = category,
        .type_tag = type_tag,
        .tags = tags,
        .child_sockets = child_sockets,
        .morphology_bindings = morph_bindings,
    };
}

fn breathingPartDefinition(
    stable_id: []const u8,
    category: []const u8,
    type_tag: []const u8,
    tags: []const []const u8,
    child_sockets: []const anatomy.ChildSocketInput,
    morph_bindings: []const anatomy.MorphBindingInput,
    breathing_binding: deformation.BreathingBinding,
) anatomy.BodyPartDefinitionInput {
    var result = partDefinition(stable_id, category, type_tag, tags, child_sockets, morph_bindings);
    result.breathing_binding = breathing_binding;
    return result;
}

fn setInstance(
    instances: *[part_count]anatomy.BodyPartInstanceInput,
    variants: *[part_count][profile_names.len]anatomy.VisualVariantInput,
    visual_storage: *[part_count][profile_names.len][maximum_visuals_per_variant][]const u8,
    part: Part,
    stable_id: []const u8,
    definition: []const u8,
    parent: anatomy.BodyPartParentInput,
    body_region: []const u8,
    layer: u16,
    articulation_module: ?[]const u8,
    visual_names: []const []const u8,
) void {
    const index = @intFromEnum(part);
    for (profile_names, 0..) |profile, profile_index| {
        @memcpy(visual_storage[index][profile_index][0..visual_names.len], visual_names);
        variants[index][profile_index] = .{
            .presentation_profile = profile,
            .visuals = visual_storage[index][profile_index][0..visual_names.len],
        };
    }
    instances[index] = .{
        .stable_id = stable_id,
        .definition = definition,
        .parent = parent,
        .local_to_parent = math.Transform2D.identity(),
        .body_region = body_region,
        .visual_group = "body",
        .base_render_layer = layer,
        .articulation_module = articulation_module,
        .presentation_variants = &variants[index],
    };
}

fn setVariantVisual(
    variants: *[part_count][profile_names.len]anatomy.VisualVariantInput,
    visual_storage: *[part_count][profile_names.len][maximum_visuals_per_variant][]const u8,
    part: Part,
    profile_index: usize,
    visual_names: []const []const u8,
) void {
    const index = @intFromEnum(part);
    @memcpy(visual_storage[index][profile_index][0..visual_names.len], visual_names);
    variants[index][profile_index].visuals = visual_storage[index][profile_index][0..visual_names.len];
}
