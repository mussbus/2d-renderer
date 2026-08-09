const std = @import("std");
const definition = @import("definition.zig");
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

pub const TraceError = error{ OutputTooSmall, UnsupportedTarget };

const provenance = "owner_approved_m02_prompt_2c_manifest";
const empty_target = TargetSpec{ .kind = .bone, .id = "skeleton_root" };
pub const control_specs = buildControlSpecs();

pub fn traceCount(source: *const definition.CanonicalCreatureDefinition) usize {
    var count: usize = 0;
    for (source.controls) |control| count += control.driven_targets.len;
    return count;
}

pub fn generateTraces(
    source: *const definition.CanonicalCreatureDefinition,
    output: []TraceEntry,
) TraceError![]const TraceEntry {
    if (output.len < traceCount(source)) return error.OutputTooSmall;
    var output_index: usize = 0;
    var previous_control_id: ?[]const u8 = null;
    var emitted_controls: usize = 0;
    while (emitted_controls < source.controls.len) : (emitted_controls += 1) {
        var selected_control: ?usize = null;
        for (source.controls, 0..) |control, index| {
            if (previous_control_id) |previous| {
                if (std.mem.order(u8, control.control_id.value.bytes, previous) != .gt) continue;
            }
            if (selected_control == null or std.mem.order(u8, control.control_id.value.bytes, source.controls[selected_control.?].control_id.value.bytes) == .lt) {
                selected_control = index;
            }
        }
        const control = source.controls[selected_control.?];
        var previous_target: ?rig.DrivenTarget = null;
        var emitted_targets: usize = 0;
        while (emitted_targets < control.driven_targets.len) : (emitted_targets += 1) {
            var selected_target: ?usize = null;
            for (control.driven_targets, 0..) |target, target_index| {
                if (previous_target) |previous| {
                    if (!drivenTargetLessThan(previous, target)) continue;
                }
                if (selected_target == null or drivenTargetLessThan(target, control.driven_targets[selected_target.?])) {
                    selected_target = target_index;
                }
            }
            const target = control.driven_targets[selected_target.?];
            output[output_index] = .{
                .control_id = control.control_id.value.bytes,
                .owner_component_id = ownerComponentId(source, control),
                .area = areaForControl(control.control_id.value.bytes),
                .target_kind = drivenTargetKind(target) orelse return error.UnsupportedTarget,
                .target_id = drivenTargetId(target),
                .mirror_control_id = if (control.mirror_control_id) |id| id.value.bytes else null,
                .space = control.space,
                .relevant_joint_id = relevantJointFromControl(source, control),
                .provenance = provenance,
            };
            output_index += 1;
            previous_target = target;
        }
        previous_control_id = control.control_id.value.bytes;
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
    const control = findControl(source, control_id) orelse return false;
    const owner_component_id = ownerComponentId(source, control);
    for (source.components) |component| {
        if (std.mem.eql(u8, component.component_id.value.bytes, owner_component_id)) {
            return component.default_state == .enabled;
        }
    }
    return false;
}

pub fn areaForControl(control_id: []const u8) Area {
    if (std.mem.startsWith(u8, control_id, "spine_")) return .spine;
    if (std.mem.startsWith(u8, control_id, "pelvis_") or std.mem.startsWith(u8, control_id, "hip_hike")) return .pelvis_root;
    if (std.mem.startsWith(u8, control_id, "head_") or std.mem.startsWith(u8, control_id, "jaw_")) return .head_jaw;
    if (std.mem.startsWith(u8, control_id, "eye") or std.mem.startsWith(u8, control_id, "eyelid")) return .eyes_eyelids;
    if (std.mem.startsWith(u8, control_id, "tongue_")) return .tongue;
    if (std.mem.startsWith(u8, control_id, "penis_")) return .optional_anatomy;
    if (std.mem.eql(u8, control_id, "hand_left_ik_target") or
        std.mem.eql(u8, control_id, "hand_right_ik_target")) return .arm;
    if (std.mem.startsWith(u8, control_id, "hand_") or
        std.mem.startsWith(u8, control_id, "finger_") or
        std.mem.startsWith(u8, control_id, "thumb_") or
        std.mem.startsWith(u8, control_id, "index_") or
        std.mem.startsWith(u8, control_id, "middle_") or
        std.mem.startsWith(u8, control_id, "ring_") or
        std.mem.startsWith(u8, control_id, "little_") or
        std.mem.startsWith(u8, control_id, "palm_")) return .hand;
    if (std.mem.indexOf(u8, control_id, "foot_") != null or
        std.mem.indexOf(u8, control_id, "toe_") != null or
        std.mem.indexOf(u8, control_id, "heel_") != null or
        std.mem.indexOf(u8, control_id, "ball_") != null or
        std.mem.indexOf(u8, control_id, "ankle_") != null or
        std.mem.indexOf(u8, control_id, "knee_") != null or
        std.mem.indexOf(u8, control_id, "leg_") != null or
        std.mem.startsWith(u8, control_id, "hip_")) return .leg_foot;
    return .arm;
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

fn drivenTargetLessThan(a: rig.DrivenTarget, b: rig.DrivenTarget) bool {
    const a_tag = std.meta.activeTag(a);
    const b_tag = std.meta.activeTag(b);
    const kind_order = std.math.order(@intFromEnum(a_tag), @intFromEnum(b_tag));
    if (kind_order != .eq) return kind_order == .lt;
    return std.mem.order(u8, drivenTargetId(a), drivenTargetId(b)) == .lt;
}

fn drivenTargetKind(target: rig.DrivenTarget) ?TargetKind {
    return switch (target) {
        .bone => .bone,
        .joint => .joint,
        .anchor, .morphology_parameter, .constraint => null,
    };
}

fn drivenTargetId(target: rig.DrivenTarget) []const u8 {
    return switch (target) {
        inline else => |id| id.value.bytes,
    };
}

fn relevantJointFromControl(
    source: *const definition.CanonicalCreatureDefinition,
    control: rig.Control,
) ?[]const u8 {
    if (control.driven_targets.len == 0) return null;
    return switch (control.driven_targets[0]) {
        .joint => |id| id.value.bytes,
        .bone => |bone_id| blk: {
            if (std.mem.eql(u8, bone_id.value.bytes, "skeleton_root")) break :blk null;
            for (source.joints) |joint_record| {
                if (joint_record.child_bone_id.eql(bone_id)) break :blk joint_record.joint_id.value.bytes;
            }
            break :blk null;
        },
        .anchor, .morphology_parameter, .constraint => null,
    };
}

fn ownerComponentId(
    source: *const definition.CanonicalCreatureDefinition,
    control: rig.Control,
) []const u8 {
    if (control.driven_targets.len == 0) return "unknown";
    // This whole-region animator concept intentionally owns the head/neck
    // span from the head component even though its canonical targets cross
    // the sibling head and neck component branches.
    if (std.mem.eql(u8, control.control_id.value.bytes, "head_neck_control")) return "head";
    var common_owner = targetOwnerComponentId(source, control.driven_targets[0]);
    for (control.driven_targets[1..]) |target| {
        const target_owner = targetOwnerComponentId(source, target);
        while (!componentIsAncestorOrSelf(source, common_owner, target_owner)) {
            common_owner = componentParentId(source, common_owner) orelse return "unknown";
        }
    }
    return common_owner;
}

fn targetOwnerComponentId(source: *const definition.CanonicalCreatureDefinition, target: rig.DrivenTarget) []const u8 {
    const owner_bone_id = switch (target) {
        .bone => |bone_id| bone_id.value.bytes,
        .joint => |joint_id| blk: {
            for (source.joints) |joint_record| {
                if (joint_record.joint_id.eql(joint_id)) break :blk joint_record.child_bone_id.value.bytes;
            }
            return "unknown";
        },
        else => return "unknown",
    };
    for (source.bones) |bone_record| {
        if (!std.mem.eql(u8, bone_record.bone_id.value.bytes, owner_bone_id)) continue;
        return if (bone_record.owner_component_id) |owner| owner.value.bytes else "unknown";
    }
    return "unknown";
}

fn componentIsAncestorOrSelf(
    source: *const definition.CanonicalCreatureDefinition,
    candidate_id: []const u8,
    descendant_id: []const u8,
) bool {
    var current_id = descendant_id;
    while (true) {
        if (std.mem.eql(u8, candidate_id, current_id)) return true;
        current_id = componentParentId(source, current_id) orelse return false;
    }
}

fn componentParentId(source: *const definition.CanonicalCreatureDefinition, component_id: []const u8) ?[]const u8 {
    for (source.components) |component| {
        if (!std.mem.eql(u8, component.component_id.value.bytes, component_id)) continue;
        return if (component.parent_component_id) |parent| parent.value.bytes else null;
    }
    return null;
}
