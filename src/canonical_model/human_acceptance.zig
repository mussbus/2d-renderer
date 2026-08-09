const std = @import("std");
const definition = @import("definition.zig");
const human_structural_validation = @import("human_structural_validation.zig");
const human_validation = @import("human_validation.zig");

pub const derived_profile_decision = "deferred_until_configuration_records_can_prove_shared_human_base_without_duplicate_rigs";

pub const ValidationStage = enum {
    prompt_2a,
    prompt_2b,
    prompt_2d,
};

pub const DiagnosticCode = enum {
    missing_skeleton_root,
    multiple_skeleton_roots,
    wrong_pelvis_parent,
    wrong_spine_count,
    wrong_neck_count,
    wrong_arm_twist_count,
    wrong_leg_twist_count,
    malformed_finger_chain,
    malformed_toe_chain,
    bilateral_mirror_mismatch,
    foot_contact_off_ground,
    canonical_height_mismatch,
    missing_required_landmark,
    missing_required_seam,
    socket_anchor_mismatch,
    missing_interaction_site_owner,
    invalid_optional_module_multiplicity,
};

pub const Diagnostic = struct {
    code: DiagnosticCode,
    object_type: []const u8,
    object_id: ?[]const u8,
    property: ?[]const u8,
    message: []const u8,
};

pub const FixtureKind = enum {
    missing_skeleton_root,
    second_skeleton_root,
    wrong_pelvis_parent,
    wrong_spine_count,
    wrong_neck_count,
    wrong_arm_twist_count,
    wrong_leg_twist_count,
    malformed_finger_chain,
    malformed_toe_chain,
    bilateral_mirror_mismatch,
    foot_contact_off_ground,
    canonical_height_mismatch,
    missing_required_landmark,
    missing_required_seam,
    socket_missing_anchor,
    interaction_site_missing_owner,
    invalid_optional_module_multiplicity,
};

pub const FixtureSpec = struct {
    fixture_id: []const u8,
    file_name: []const u8,
    kind: FixtureKind,
    stage: ValidationStage,
    expected: Diagnostic,
};

pub const invalid_fixture_specs = [_]FixtureSpec{
    fixture("01_missing_skeleton_root", "01_missing_skeleton_root.json", .missing_skeleton_root, .prompt_2b, .missing_skeleton_root, "bone", "skeleton_root", "bone_id", "required skeleton_root is absent"),
    fixture("02_second_skeleton_root", "02_second_skeleton_root.json", .second_skeleton_root, .prompt_2b, .multiple_skeleton_roots, "skeleton", null, "parent_bone_id", "canonical human skeleton has more than one root"),
    fixture("03_wrong_pelvis_parent", "03_wrong_pelvis_parent.json", .wrong_pelvis_parent, .prompt_2b, .wrong_pelvis_parent, "bone", "pelvis", "parent_bone_id", "pelvis parent must be skeleton_root"),
    fixture("04_wrong_spine_count", "04_wrong_spine_count.json", .wrong_spine_count, .prompt_2b, .wrong_spine_count, "skeleton", null, "spine_bone_count", "canonical human skeleton requires exactly seven spine bones"),
    fixture("05_wrong_neck_count", "05_wrong_neck_count.json", .wrong_neck_count, .prompt_2b, .wrong_neck_count, "skeleton", null, "neck_bone_count", "canonical human skeleton requires exactly three neck bones"),
    fixture("06_wrong_arm_twist_count", "06_wrong_arm_twist_count.json", .wrong_arm_twist_count, .prompt_2b, .wrong_arm_twist_count, "skeleton", null, "arm_twist_bone_count", "each canonical upper-arm and forearm chain requires two twist bones"),
    fixture("07_wrong_leg_twist_count", "07_wrong_leg_twist_count.json", .wrong_leg_twist_count, .prompt_2b, .wrong_leg_twist_count, "skeleton", null, "leg_twist_bone_count", "each canonical thigh and lower-leg chain requires two twist bones"),
    fixture("08_malformed_finger_chain", "08_malformed_finger_chain.json", .malformed_finger_chain, .prompt_2b, .malformed_finger_chain, "bone", "index_middle_left", "parent_bone_id", "finger chain parent sequence is malformed"),
    fixture("09_malformed_toe_chain", "09_malformed_toe_chain.json", .malformed_toe_chain, .prompt_2b, .malformed_toe_chain, "bone", "toe_index_left_02", "parent_bone_id", "toe chain parent sequence is malformed"),
    fixture("10_bilateral_mirror_mismatch", "10_bilateral_mirror_mismatch.json", .bilateral_mirror_mismatch, .prompt_2b, .bilateral_mirror_mismatch, "bone", "upper_arm_left", "local_rest_transform", "bilateral neutral transforms exceed the accepted structural symmetry tolerance"),
    fixture("11_foot_contact_off_ground", "11_foot_contact_off_ground.json", .foot_contact_off_ground, .prompt_2d, .foot_contact_off_ground, "anchor", "heel_contact_left_anchor", "local_transform.translation_m.y", "foot-contact reference does not derive to canonical ground Y = 0"),
    fixture("12_canonical_height_mismatch", "12_canonical_height_mismatch.json", .canonical_height_mismatch, .prompt_2b, .canonical_height_mismatch, "measurement", "total_height_m", "value", "derived canonical height does not equal 1.8288 m"),
    fixture("13_missing_required_landmark", "13_missing_required_landmark.json", .missing_required_landmark, .prompt_2d, .missing_required_landmark, "landmark", "head_top_landmark", "landmark_id", "required structural landmark is absent"),
    fixture("14_missing_required_seam", "14_missing_required_seam.json", .missing_required_seam, .prompt_2d, .missing_required_seam, "shared_seam", "torso_pelvis_seam", "seam_id", "required shared structural seam is absent"),
    fixture("15_socket_missing_anchor", "15_socket_missing_anchor.json", .socket_missing_anchor, .prompt_2d, .socket_anchor_mismatch, "socket", "hair_socket", "anchor_id", "socket references the wrong or a missing structural anchor"),
    fixture("16_interaction_site_missing_owner", "16_interaction_site_missing_owner.json", .interaction_site_missing_owner, .prompt_2d, .missing_interaction_site_owner, "interaction_site", "palm_left_site", "owner_component_id", "interaction site owner is missing or does not match the accepted manifest"),
    fixture("17_invalid_optional_module_multiplicity", "17_invalid_optional_module_multiplicity.json", .invalid_optional_module_multiplicity, .prompt_2a, .invalid_optional_module_multiplicity, "component", "penis_module_01", "multiplicity", "optional anatomy module multiplicity must remain zero-or-one"),
};

pub fn diagnose(spec: FixtureSpec, source: *const definition.CanonicalCreatureDefinition) ?Diagnostic {
    const validation_error = validationError(spec.stage, source) orelse return null;
    const actual_code = codeForError(validation_error) orelse return .{
        .code = spec.expected.code,
        .object_type = "unexpected_validation_error",
        .object_id = @errorName(validation_error),
        .property = null,
        .message = "fixture produced an unmapped validation error",
    };
    const expected = spec.expected;
    if (actual_code != expected.code) return .{
        .code = actual_code,
        .object_type = "unexpected_validation_error",
        .object_id = @errorName(validation_error),
        .property = null,
        .message = "fixture produced a different mapped validation error",
    };
    return expected;
}

fn validationError(stage: ValidationStage, source: *const definition.CanonicalCreatureDefinition) ?anyerror {
    switch (stage) {
        .prompt_2a => human_validation.validatePrompt2A(source) catch |err| return err,
        .prompt_2b => human_validation.validatePrompt2B(source) catch |err| return err,
        .prompt_2d => human_structural_validation.validatePrompt2D(source) catch |err| return err,
    }
    return null;
}

fn codeForError(validation_error: anyerror) ?DiagnosticCode {
    const name = @errorName(validation_error);
    inline for (.{
        .{ "MissingSkeletonRoot", DiagnosticCode.missing_skeleton_root },
        .{ "MultipleSkeletonRoots", DiagnosticCode.multiple_skeleton_roots },
        .{ "WrongPelvisParent", DiagnosticCode.wrong_pelvis_parent },
        .{ "WrongSpineCount", DiagnosticCode.wrong_spine_count },
        .{ "WrongNeckCount", DiagnosticCode.wrong_neck_count },
        .{ "WrongUpperArmTwistCount", DiagnosticCode.wrong_arm_twist_count },
        .{ "WrongForearmTwistCount", DiagnosticCode.wrong_arm_twist_count },
        .{ "WrongThighTwistCount", DiagnosticCode.wrong_leg_twist_count },
        .{ "WrongLowerLegTwistCount", DiagnosticCode.wrong_leg_twist_count },
        .{ "MalformedFingerChain", DiagnosticCode.malformed_finger_chain },
        .{ "MalformedToeChain", DiagnosticCode.malformed_toe_chain },
        .{ "BilateralMirrorMismatch", DiagnosticCode.bilateral_mirror_mismatch },
        .{ "FootContactOffGround", DiagnosticCode.foot_contact_off_ground },
        .{ "CanonicalHeightMismatch", DiagnosticCode.canonical_height_mismatch },
        .{ "MissingRequiredLandmark", DiagnosticCode.missing_required_landmark },
        .{ "MissingRequiredSeam", DiagnosticCode.missing_required_seam },
        .{ "SocketAnchorMismatch", DiagnosticCode.socket_anchor_mismatch },
        .{ "InteractionSiteOwnerMismatch", DiagnosticCode.missing_interaction_site_owner },
        .{ "InvalidOptionalModuleMultiplicity", DiagnosticCode.invalid_optional_module_multiplicity },
    }) |mapping| if (std.mem.eql(u8, name, mapping[0])) return mapping[1];
    return null;
}

fn fixture(
    fixture_id: []const u8,
    file_name: []const u8,
    kind: FixtureKind,
    stage: ValidationStage,
    code: DiagnosticCode,
    object_type: []const u8,
    object_id: ?[]const u8,
    property: ?[]const u8,
    message: []const u8,
) FixtureSpec {
    return .{
        .fixture_id = fixture_id,
        .file_name = file_name,
        .kind = kind,
        .stage = stage,
        .expected = .{
            .code = code,
            .object_type = object_type,
            .object_id = object_id,
            .property = property,
            .message = message,
        },
    };
}
