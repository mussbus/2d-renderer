const std = @import("std");
const definition = @import("definition.zig");
const identity = @import("identity.zig");
const math3d = @import("math3d.zig");
const rig = @import("rig.zig");

pub const control_count: usize = 116;
pub const spine_control_count: usize = 5;
pub const max_targets_per_control: usize = 20;

/// Prompt 2C control-value conventions. These are OPEN/TUNING authoring
/// defaults and do not execute motion.
pub const open_tuning = struct {
    pub const normalized_minimum: f32 = 0;
    pub const normalized_maximum: f32 = 1;
    pub const unipolar_neutral: f32 = 0;
    pub const centered_neutral: f32 = 0.5;
};

pub const Area = enum {
    spine,
    pelvis_root,
    head_jaw,
    arm,
    hand,
    leg_foot,
    eyes_eyelids,
    tongue,
    optional_anatomy,
};

pub const TargetKind = enum {
    bone,
    joint,
};

pub const TargetSpec = struct {
    kind: TargetKind,
    id: []const u8,
};

pub const ControlSpec = struct {
    control_id: []const u8,
    owner_component_id: []const u8,
    area: Area,
    control_type: rig.ControlType,
    space: rig.ControlSpace,
    mirror_control_id: ?[]const u8,
    relevant_joint_id: ?[]const u8,
    normalized_default: ?f32,
    target_count: usize,
    targets: [max_targets_per_control]TargetSpec,
    provenance: []const u8,
};

pub const TraceEntry = struct {
    control_id: []const u8,
    owner_component_id: []const u8,
    area: Area,
    target_kind: TargetKind,
    target_id: []const u8,
    mirror_control_id: ?[]const u8,
    space: rig.ControlSpace,
    relevant_joint_id: ?[]const u8,
    provenance: []const u8,
};

pub const TraceError = error{OutputTooSmall};

const provenance = "owner_approved_m02_prompt_2c_manifest";
const empty_target = TargetSpec{ .kind = .bone, .id = "skeleton_root" };
const control_tags = makeIds(identity.SemanticTagId, &.{ "human", "structural_control" });

pub const control_specs = buildControlSpecs();
pub const target_storage = buildTargetStorage();
pub const controls = buildControls();
pub const trace_count = countTraceEntries();

pub fn generateTraces(output: []TraceEntry) TraceError![]const TraceEntry {
    if (output.len < trace_count) return error.OutputTooSmall;
    var output_index: usize = 0;
    var previous_control_id: ?[]const u8 = null;
    var emitted_controls: usize = 0;
    while (emitted_controls < control_specs.len) : (emitted_controls += 1) {
        var selected_control: ?usize = null;
        for (control_specs, 0..) |spec, index| {
            if (previous_control_id) |previous| {
                if (std.mem.order(u8, spec.control_id, previous) != .gt) continue;
            }
            if (selected_control == null or std.mem.order(u8, spec.control_id, control_specs[selected_control.?].control_id) == .lt) {
                selected_control = index;
            }
        }
        const control_spec = control_specs[selected_control.?];
        var previous_target: ?TargetSpec = null;
        var emitted_targets: usize = 0;
        while (emitted_targets < control_spec.target_count) : (emitted_targets += 1) {
            var selected_target: ?usize = null;
            for (control_spec.targets[0..control_spec.target_count], 0..) |target, target_index| {
                if (previous_target) |previous| {
                    if (!targetLessThan(previous, target)) continue;
                }
                if (selected_target == null or targetLessThan(target, control_spec.targets[selected_target.?])) {
                    selected_target = target_index;
                }
            }
            const target = control_spec.targets[selected_target.?];
            output[output_index] = .{
                .control_id = control_spec.control_id,
                .owner_component_id = control_spec.owner_component_id,
                .area = control_spec.area,
                .target_kind = target.kind,
                .target_id = target.id,
                .mirror_control_id = control_spec.mirror_control_id,
                .space = control_spec.space,
                .relevant_joint_id = control_spec.relevant_joint_id,
                .provenance = control_spec.provenance,
            };
            output_index += 1;
            previous_target = target;
        }
        previous_control_id = control_spec.control_id;
    }
    return output[0..output_index];
}

pub fn findControlSpec(control_id: []const u8) ?ControlSpec {
    for (control_specs) |spec| if (std.mem.eql(u8, spec.control_id, control_id)) return spec;
    return null;
}

pub fn findControl(
    source: *const definition.CanonicalCreatureDefinition,
    control_id: []const u8,
) ?rig.Control {
    for (source.controls) |control| if (std.mem.eql(u8, control.control_id.value.bytes, control_id)) return control;
    return null;
}

pub fn controlIsActive(
    source: *const definition.CanonicalCreatureDefinition,
    control_id: []const u8,
) bool {
    const spec = findControlSpec(control_id) orelse return false;
    for (source.components) |component| {
        if (std.mem.eql(u8, component.component_id.value.bytes, spec.owner_component_id)) {
            return component.default_state == .enabled;
        }
    }
    return false;
}

pub fn activeControlCount(source: *const definition.CanonicalCreatureDefinition) usize {
    var count: usize = 0;
    for (source.controls) |control| if (controlIsActive(source, control.control_id.value.bytes)) {
        count += 1;
    };
    return count;
}

fn buildControlSpecs() [control_count]ControlSpec {
    @setEvalBranchQuota(1_000_000);
    var result: [control_count]ControlSpec = undefined;
    var index: usize = 0;

    append(&result, &index, "spine_lower_control", "torso", .spine, .whole_region, .local, null, &.{ joint("spine_01_joint"), joint("spine_02_joint") });
    append(&result, &index, "spine_mid_control", "torso", .spine, .whole_region, .local, null, &.{ joint("spine_03_joint"), joint("spine_04_joint") });
    append(&result, &index, "spine_chest_control", "torso", .spine, .whole_region, .local, null, &.{ joint("spine_05_joint"), joint("spine_06_joint") });
    append(&result, &index, "spine_upper_chest_control", "torso", .spine, .whole_region, .local, null, &.{joint("spine_07_joint")});
    append(&result, &index, "spine_curve_control", "torso", .spine, .curve_spline, .local, null, &.{ joint("spine_01_joint"), joint("spine_02_joint"), joint("spine_03_joint"), joint("spine_04_joint"), joint("spine_05_joint"), joint("spine_06_joint"), joint("spine_07_joint") });

    append(&result, &index, "pelvis_translation_control", "pelvis", .pelvis_root, .whole_region, .character, null, &.{bone("pelvis")});
    append(&result, &index, "pelvis_tilt_control", "pelvis", .pelvis_root, .fk_rotation, .local, null, &.{joint("pelvis_joint")});
    append(&result, &index, "pelvis_roll_control", "pelvis", .pelvis_root, .fk_rotation, .local, null, &.{joint("pelvis_joint")});
    append(&result, &index, "pelvis_rotation_control", "pelvis", .pelvis_root, .fk_rotation, .local, null, &.{joint("pelvis_joint")});
    append(&result, &index, "pelvis_thrust_control", "pelvis", .pelvis_root, .normalized_slider, .local, null, &.{bone("pelvis")});
    append(&result, &index, "hip_hike_control", "pelvis", .pelvis_root, .normalized_slider, .local, null, &.{joint("pelvis_joint")});
    append(&result, &index, "pelvis_sway_control", "pelvis", .pelvis_root, .normalized_slider, .character, null, &.{bone("pelvis")});
    append(&result, &index, "pelvis_figure_eight_control", "pelvis", .pelvis_root, .curve_spline, .character, null, &.{bone("pelvis")});

    append(&result, &index, "head_neck_control", "head", .head_jaw, .whole_region, .local, null, &.{ joint("neck_01_joint"), joint("neck_02_joint"), joint("neck_03_joint"), joint("head_joint") });
    append(&result, &index, "jaw_open_close_control", "mouth", .head_jaw, .normalized_slider, .local, null, &.{joint("jaw_joint")});
    append(&result, &index, "jaw_shift_control", "mouth", .head_jaw, .whole_region, .local, null, &.{joint("jaw_joint")});

    inline for (.{ "left", "right" }) |side| {
        const opposite = oppositeSide(side);
        const arm_owner = std.fmt.comptimePrint("arm_{s}_01", .{side});
        const hand_owner = std.fmt.comptimePrint("hand_{s}_01", .{side});
        const leg_owner = std.fmt.comptimePrint("leg_{s}_01", .{side});
        const foot_owner = std.fmt.comptimePrint("foot_{s}_01", .{side});
        const eye_owner = std.fmt.comptimePrint("eye_{s}_01", .{side});

        appendPaired(&result, &index, "clavicle", side, "_override_control", "torso", .arm, .fk_rotation, .local, &.{joint(std.fmt.comptimePrint("clavicle_{s}_joint", .{side}))});
        appendPaired(&result, &index, "scapula", side, "_override_control", "torso", .arm, .fk_rotation, .local, &.{joint(std.fmt.comptimePrint("scapula_{s}_joint", .{side}))});
        appendPaired(&result, &index, "upper_arm", side, "_fk_control", arm_owner, .arm, .fk_rotation, .local, &.{joint(std.fmt.comptimePrint("upper_arm_{s}_joint", .{side}))});
        appendPaired(&result, &index, "elbow", side, "_fk_control", arm_owner, .arm, .fk_rotation, .local, &.{joint(std.fmt.comptimePrint("forearm_{s}_joint", .{side}))});
        appendPaired(&result, &index, "wrist", side, "_fk_control", hand_owner, .arm, .fk_rotation, .local, &.{joint(std.fmt.comptimePrint("hand_{s}_joint", .{side}))});
        appendPaired(&result, &index, "hand", side, "_ik_target", hand_owner, .arm, .ik_target, .character, &.{bone(std.fmt.comptimePrint("hand_{s}", .{side}))});
        appendPaired(&result, &index, "elbow", side, "_pole_control", arm_owner, .arm, .pole_direction, .character, &.{joint(std.fmt.comptimePrint("forearm_{s}_joint", .{side}))});

        const all_hand = handJointTargets(side);
        const fist = fistTargets(side);
        const spread = digitBaseTargets(side);
        const thumb = thumbTargets(side);
        const pinch = pinchTargets(side);
        appendPaired(&result, &index, "hand", side, "_open_close_control", hand_owner, .hand, .normalized_slider, .local, &all_hand);
        appendPaired(&result, &index, "hand", side, "_fist_curl_control", hand_owner, .hand, .normalized_slider, .local, &fist);
        appendPaired(&result, &index, "finger", side, "_spread_control", hand_owner, .hand, .normalized_slider, .local, &spread);
        appendPaired(&result, &index, "palm", side, "_cup_control", hand_owner, .hand, .normalized_slider, .local, &.{joint(std.fmt.comptimePrint("hand_{s}_joint", .{side}))});
        appendPaired(&result, &index, "thumb", side, "_opposition_control", hand_owner, .hand, .normalized_slider, .local, &thumb);
        appendPaired(&result, &index, "hand", side, "_pinch_control", hand_owner, .hand, .normalized_slider, .local, &pinch);
        appendPaired(&result, &index, "hand", side, "_grip_width_control", hand_owner, .hand, .normalized_slider, .local, &spread);

        inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| {
            if (comptime std.mem.eql(u8, digit, "thumb")) {
                inline for (.{ "metacarpal", "proximal", "distal" }) |segment| {
                    append(
                        &result,
                        &index,
                        std.fmt.comptimePrint("{s}_{s}_{s}_fk_control", .{ digit, segment, side }),
                        hand_owner,
                        .hand,
                        .fk_rotation,
                        .local,
                        std.fmt.comptimePrint("{s}_{s}_{s}_fk_control", .{ digit, segment, opposite }),
                        &.{joint(std.fmt.comptimePrint("{s}_{s}_{s}_joint", .{ digit, segment, side }))},
                    );
                }
            } else {
                inline for (.{ "metacarpal", "proximal", "middle", "distal" }) |segment| {
                    append(
                        &result,
                        &index,
                        std.fmt.comptimePrint("{s}_{s}_{s}_fk_control", .{ digit, segment, side }),
                        hand_owner,
                        .hand,
                        .fk_rotation,
                        .local,
                        std.fmt.comptimePrint("{s}_{s}_{s}_fk_control", .{ digit, segment, opposite }),
                        &.{joint(std.fmt.comptimePrint("{s}_{s}_{s}_joint", .{ digit, segment, side }))},
                    );
                }
            }
        }

        appendPaired(&result, &index, "hip", side, "_fk_control", leg_owner, .leg_foot, .fk_rotation, .local, &.{joint(std.fmt.comptimePrint("thigh_{s}_joint", .{side}))});
        appendPaired(&result, &index, "knee", side, "_fk_control", leg_owner, .leg_foot, .fk_rotation, .local, &.{joint(std.fmt.comptimePrint("lower_leg_{s}_joint", .{side}))});
        appendPaired(&result, &index, "ankle", side, "_fk_control", leg_owner, .leg_foot, .fk_rotation, .local, &.{joint(std.fmt.comptimePrint("ankle_{s}_joint", .{side}))});
        appendPaired(&result, &index, "foot", side, "_fk_control", foot_owner, .leg_foot, .fk_rotation, .local, &.{joint(std.fmt.comptimePrint("foot_{s}_joint", .{side}))});
        appendPaired(&result, &index, "foot", side, "_ik_target", foot_owner, .leg_foot, .ik_target, .character, &.{bone(std.fmt.comptimePrint("foot_{s}", .{side}))});
        appendPaired(&result, &index, "knee", side, "_pole_control", leg_owner, .leg_foot, .pole_direction, .character, &.{joint(std.fmt.comptimePrint("lower_leg_{s}_joint", .{side}))});
        appendPaired(&result, &index, "heel", side, "_control", foot_owner, .leg_foot, .normalized_slider, .local, &.{joint(std.fmt.comptimePrint("foot_{s}_joint", .{side}))});
        appendPaired(&result, &index, "ball", side, "_control", foot_owner, .leg_foot, .normalized_slider, .local, &.{joint(std.fmt.comptimePrint("forefoot_{s}_joint", .{side}))});
        const all_toes = allToeTargets(side);
        const big_toe = bigToeTargets(side);
        const lesser_toes = lesserToeTargets(side);
        const toe_bases = toeBaseTargets(side);
        appendPaired(&result, &index, "toe", side, "_control", foot_owner, .leg_foot, .whole_region, .local, &all_toes);
        appendPaired(&result, &index, "big_toe", side, "_curl_control", foot_owner, .leg_foot, .normalized_slider, .local, &big_toe);
        appendPaired(&result, &index, "toe", side, "_curl_control", foot_owner, .leg_foot, .normalized_slider, .local, &lesser_toes);
        appendPaired(&result, &index, "toe", side, "_spread_control", foot_owner, .leg_foot, .normalized_slider, .local, &toe_bases);

        append(
            &result,
            &index,
            std.fmt.comptimePrint("eye_{s}_look_override", .{side}),
            eye_owner,
            .eyes_eyelids,
            .look_target,
            .character,
            std.fmt.comptimePrint("eye_{s}_look_override", .{opposite}),
            &.{bone(std.fmt.comptimePrint("eyeball_{s}_01", .{side}))},
        );
        const side_lids = eyelidTargets(side);
        appendPaired(&result, &index, "eyelid", side, "_control", eye_owner, .eyes_eyelids, .normalized_slider, .local, &side_lids);
    }

    append(&result, &index, "eyes_shared_look_target", "head", .eyes_eyelids, .look_target, .character, null, &.{ bone("eyeball_left_01"), bone("eyeball_right_01") });
    append(&result, &index, "eyes_primary_group_control", "head", .eyes_eyelids, .whole_region, .local, null, &.{ joint("eyeball_left_01_joint"), joint("eyeball_right_01_joint") });
    const all_lids = allEyelidTargets();
    append(&result, &index, "eyelids_blink_control", "head", .eyes_eyelids, .normalized_slider, .local, null, &all_lids);

    append(&result, &index, "tongue_curve_control", "tongue", .tongue, .curve_spline, .local, null, &.{ joint("tongue_01_joint"), joint("tongue_02_joint"), joint("tongue_03_joint"), joint("tongue_04_joint") });
    append(&result, &index, "tongue_tip_control", "tongue", .tongue, .whole_region, .local, null, &.{ joint("tongue_branch_point_joint"), joint("tongue_tip_01_joint") });
    append(&result, &index, "penis_curve_control", "penis_module_01", .optional_anatomy, .curve_spline, .local, null, &.{ joint("penis_shaft_01_joint"), joint("penis_shaft_02_joint"), joint("penis_shaft_03_joint"), joint("penis_shaft_04_joint"), joint("penis_shaft_05_joint"), joint("penis_shaft_06_joint"), joint("penis_shaft_07_joint") });

    if (index != control_count) @compileError(std.fmt.comptimePrint("human control count is {d}, expected {d}", .{ index, control_count }));
    return result;
}

fn appendPaired(
    result: *[control_count]ControlSpec,
    index: *usize,
    prefix: []const u8,
    side: []const u8,
    suffix: []const u8,
    owner_component_id: []const u8,
    area: Area,
    control_type: rig.ControlType,
    space: rig.ControlSpace,
    targets: []const TargetSpec,
) void {
    append(
        result,
        index,
        std.fmt.comptimePrint("{s}_{s}{s}", .{ prefix, side, suffix }),
        owner_component_id,
        area,
        control_type,
        space,
        std.fmt.comptimePrint("{s}_{s}{s}", .{ prefix, oppositeSide(side), suffix }),
        targets,
    );
}

fn append(
    result: *[control_count]ControlSpec,
    index: *usize,
    control_id: []const u8,
    owner_component_id: []const u8,
    area: Area,
    control_type: rig.ControlType,
    space: rig.ControlSpace,
    mirror_control_id: ?[]const u8,
    targets: []const TargetSpec,
) void {
    if (targets.len == 0 or targets.len > max_targets_per_control) @compileError("invalid human control target count");
    var copied_targets = [_]TargetSpec{empty_target} ** max_targets_per_control;
    for (targets, 0..) |target, target_index| copied_targets[target_index] = target;
    result[index.*] = .{
        .control_id = control_id,
        .owner_component_id = owner_component_id,
        .area = area,
        .control_type = control_type,
        .space = space,
        .mirror_control_id = mirror_control_id,
        .relevant_joint_id = relevantJointFor(targets[0]),
        .normalized_default = normalizedDefault(control_id, control_type),
        .target_count = targets.len,
        .targets = copied_targets,
        .provenance = provenance,
    };
    index.* += 1;
}

fn buildTargetStorage() [control_count][max_targets_per_control]rig.DrivenTarget {
    @setEvalBranchQuota(1_000_000);
    var result: [control_count][max_targets_per_control]rig.DrivenTarget = undefined;
    inline for (control_specs, 0..) |spec, control_index| {
        inline for (spec.targets, 0..) |target, target_index| {
            result[control_index][target_index] = switch (target.kind) {
                .bone => .{ .bone = makeId(identity.BoneId, target.id) },
                .joint => .{ .joint = makeId(identity.JointId, target.id) },
            };
        }
    }
    return result;
}

fn buildControls() [control_count]rig.Control {
    @setEvalBranchQuota(1_000_000);
    var result: [control_count]rig.Control = undefined;
    inline for (control_specs, 0..) |spec, index| {
        result[index] = .{
            .control_id = makeId(identity.ControlId, spec.control_id),
            .display_name = null,
            .control_type = spec.control_type,
            .driven_targets = target_storage[index][0..spec.target_count],
            .space = spec.space,
            .mirror_control_id = if (spec.mirror_control_id) |mirror_id| makeId(identity.ControlId, mirror_id) else null,
            .default_value = defaultValue(spec),
            .limits = controlLimits(spec),
            .semantic_tags = &control_tags,
            .region_id = null,
        };
    }
    return result;
}

fn handJointTargets(comptime side: []const u8) [19]TargetSpec {
    var result: [19]TargetSpec = undefined;
    var index: usize = 0;
    inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| {
        if (comptime std.mem.eql(u8, digit, "thumb")) {
            inline for (.{ "metacarpal", "proximal", "distal" }) |segment| {
                result[index] = joint(std.fmt.comptimePrint("{s}_{s}_{s}_joint", .{ digit, segment, side }));
                index += 1;
            }
        } else {
            inline for (.{ "metacarpal", "proximal", "middle", "distal" }) |segment| {
                result[index] = joint(std.fmt.comptimePrint("{s}_{s}_{s}_joint", .{ digit, segment, side }));
                index += 1;
            }
        }
    }
    return result;
}

fn fistTargets(comptime side: []const u8) [14]TargetSpec {
    var result: [14]TargetSpec = undefined;
    var index: usize = 0;
    inline for (.{ "proximal", "distal" }) |segment| {
        result[index] = joint(std.fmt.comptimePrint("thumb_{s}_{s}_joint", .{ segment, side }));
        index += 1;
    }
    inline for (.{ "index", "middle", "ring", "little" }) |digit| inline for (.{ "proximal", "middle", "distal" }) |segment| {
        result[index] = joint(std.fmt.comptimePrint("{s}_{s}_{s}_joint", .{ digit, segment, side }));
        index += 1;
    };
    return result;
}

fn digitBaseTargets(comptime side: []const u8) [5]TargetSpec {
    var result: [5]TargetSpec = undefined;
    inline for (.{ "thumb", "index", "middle", "ring", "little" }, 0..) |digit, index| {
        result[index] = joint(std.fmt.comptimePrint("{s}_metacarpal_{s}_joint", .{ digit, side }));
    }
    return result;
}

fn thumbTargets(comptime side: []const u8) [3]TargetSpec {
    return .{
        joint(std.fmt.comptimePrint("thumb_metacarpal_{s}_joint", .{side})),
        joint(std.fmt.comptimePrint("thumb_proximal_{s}_joint", .{side})),
        joint(std.fmt.comptimePrint("thumb_distal_{s}_joint", .{side})),
    };
}

fn pinchTargets(comptime side: []const u8) [7]TargetSpec {
    return .{
        joint(std.fmt.comptimePrint("thumb_metacarpal_{s}_joint", .{side})),
        joint(std.fmt.comptimePrint("thumb_proximal_{s}_joint", .{side})),
        joint(std.fmt.comptimePrint("thumb_distal_{s}_joint", .{side})),
        joint(std.fmt.comptimePrint("index_metacarpal_{s}_joint", .{side})),
        joint(std.fmt.comptimePrint("index_proximal_{s}_joint", .{side})),
        joint(std.fmt.comptimePrint("index_middle_{s}_joint", .{side})),
        joint(std.fmt.comptimePrint("index_distal_{s}_joint", .{side})),
    };
}

fn bigToeTargets(comptime side: []const u8) [2]TargetSpec {
    return .{
        joint(std.fmt.comptimePrint("toe_big_{s}_01_joint", .{side})),
        joint(std.fmt.comptimePrint("toe_big_{s}_02_joint", .{side})),
    };
}

fn lesserToeTargets(comptime side: []const u8) [12]TargetSpec {
    var result: [12]TargetSpec = undefined;
    var index: usize = 0;
    inline for (.{ "index", "middle", "ring", "little" }) |digit| inline for (1..4) |segment| {
        result[index] = joint(std.fmt.comptimePrint("toe_{s}_{s}_{d:0>2}_joint", .{ digit, side, segment }));
        index += 1;
    };
    return result;
}

fn allToeTargets(comptime side: []const u8) [14]TargetSpec {
    var result: [14]TargetSpec = undefined;
    const big = bigToeTargets(side);
    const lesser = lesserToeTargets(side);
    for (big, 0..) |target, index| result[index] = target;
    for (lesser, 0..) |target, index| result[index + big.len] = target;
    return result;
}

fn toeBaseTargets(comptime side: []const u8) [5]TargetSpec {
    return .{
        joint(std.fmt.comptimePrint("toe_big_{s}_01_joint", .{side})),
        joint(std.fmt.comptimePrint("toe_index_{s}_01_joint", .{side})),
        joint(std.fmt.comptimePrint("toe_middle_{s}_01_joint", .{side})),
        joint(std.fmt.comptimePrint("toe_ring_{s}_01_joint", .{side})),
        joint(std.fmt.comptimePrint("toe_little_{s}_01_joint", .{side})),
    };
}

fn eyelidTargets(comptime side: []const u8) [6]TargetSpec {
    var result: [6]TargetSpec = undefined;
    var index: usize = 0;
    inline for (.{ "upper", "lower" }) |lid| inline for (.{ "inner", "center", "outer" }) |section| {
        result[index] = joint(std.fmt.comptimePrint("eyelid_{s}_{s}_{s}_joint", .{ lid, side, section }));
        index += 1;
    };
    return result;
}

fn allEyelidTargets() [12]TargetSpec {
    var result: [12]TargetSpec = undefined;
    const left = eyelidTargets("left");
    const right = eyelidTargets("right");
    for (left, 0..) |target, index| result[index] = target;
    for (right, 0..) |target, index| result[index + left.len] = target;
    return result;
}

fn relevantJointFor(comptime target: TargetSpec) ?[]const u8 {
    return switch (target.kind) {
        .joint => target.id,
        .bone => if (std.mem.eql(u8, target.id, "skeleton_root")) null else std.fmt.comptimePrint("{s}_joint", .{target.id}),
    };
}

fn defaultValue(comptime spec: ControlSpec) ?rig.ControlValue {
    return switch (spec.control_type) {
        .fk_rotation => .{ .quaternion = math3d.Quaternion.identity },
        .normalized_slider => .{ .scalar = spec.normalized_default.? },
        else => null,
    };
}

fn controlLimits(comptime spec: ControlSpec) ?rig.ControlLimits {
    return if (spec.control_type == .normalized_slider) .{
        .minimum = .{ .scalar = open_tuning.normalized_minimum },
        .maximum = .{ .scalar = open_tuning.normalized_maximum },
    } else null;
}

fn normalizedDefault(comptime control_id: []const u8, comptime control_type: rig.ControlType) ?f32 {
    if (control_type != .normalized_slider) return null;
    inline for (.{
        "pelvis_thrust_control",
        "hip_hike_control",
        "pelvis_sway_control",
    }) |centered_id| if (std.mem.eql(u8, control_id, centered_id)) return open_tuning.centered_neutral;
    if (std.mem.indexOf(u8, control_id, "_spread_control") != null or
        std.mem.indexOf(u8, control_id, "_grip_width_control") != null)
    {
        return open_tuning.centered_neutral;
    }
    return open_tuning.unipolar_neutral;
}

fn bone(comptime id: []const u8) TargetSpec {
    return .{ .kind = .bone, .id = id };
}

fn joint(comptime id: []const u8) TargetSpec {
    return .{ .kind = .joint, .id = id };
}

fn oppositeSide(comptime side: []const u8) []const u8 {
    return if (std.mem.eql(u8, side, "left")) "right" else "left";
}

fn targetLessThan(a: TargetSpec, b: TargetSpec) bool {
    const kind_order = std.math.order(@intFromEnum(a.kind), @intFromEnum(b.kind));
    if (kind_order != .eq) return kind_order == .lt;
    return std.mem.order(u8, a.id, b.id) == .lt;
}

fn countTraceEntries() usize {
    var count: usize = 0;
    for (control_specs) |spec| count += spec.target_count;
    return count;
}

fn makeId(comptime T: type, comptime bytes: []const u8) T {
    return T.init(bytes) catch |id_error| @compileError(@errorName(id_error) ++ ": " ++ bytes);
}

fn makeIds(comptime T: type, comptime values: []const []const u8) [values.len]T {
    var result: [values.len]T = undefined;
    inline for (values, 0..) |value, index| result[index] = makeId(T, value);
    return result;
}
