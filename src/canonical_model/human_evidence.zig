const std = @import("std");
const definition = @import("definition.zig");
const human_acceptance = @import("human_acceptance.zig");
const human_attachments = @import("human_attachment_reports.zig");
const human_controls = @import("human_control_api.zig");
const human_measurements = @import("human_measurements.zig");
const human_rig = @import("human_rig.zig");
const human_structural_semantics = @import("human_semantic_reports.zig");
const rig = @import("rig.zig");

pub fn generateAlloc(
    allocator: std.mem.Allocator,
    source: *const definition.CanonicalCreatureDefinition,
) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try appendFmt(allocator, &output,
        \\HUMAN_BASE_STRUCTURAL_EVIDENCE_V1
        \\asset_id={s} schema_version={d}.{d}.{d} asset_version={d}.{d}.{d}
        \\coordinate=right_handed,+X_right,+Y_up,+Z_forward origin=centered_between_feet_on_ground_in_a_pose unit=meter precision=f32
        \\LOCKED_COUNTS components={d} bones={d} shared_bones={d} optional_penis_bones={d} joints={d} controls={d} spine_controls={d} regions={d} surfaces={d} materials={d} anchors={d} sockets={d} mounts={d} attachments={d} landmarks={d} seams={d} sites={d} effectors={d} collision_proxies={d}
        \\COLLISION_PROXY decision={s} count={d} rationale={s}
        \\DERIVED_PROFILES decision={s}
        \\
    , .{
        source.asset_identity.asset_id.value.bytes,
        source.schema_identity.version.major,
        source.schema_identity.version.minor,
        source.schema_identity.version.patch,
        source.asset_identity.version.major,
        source.asset_identity.version.minor,
        source.asset_identity.version.patch,
        source.components.len,
        source.bones.len,
        activeBoneCount(source),
        componentOwnedBoneCount(source, "penis_module_01"),
        source.joints.len,
        source.controls.len,
        controlAreaCount(source, .spine),
        source.regions.len,
        source.surfaces.len,
        source.material_instances.len,
        source.anchors.len,
        source.sockets.len,
        source.mount_anchors.len,
        source.attachments.len,
        source.landmarks.len,
        source.shared_seams.len,
        source.interaction_sites.len,
        source.effectors.len,
        human_structural_semantics.collision_proxy_count,
        @tagName(human_structural_semantics.collision_proxy_decision),
        human_structural_semantics.collision_proxy_count,
        human_structural_semantics.collision_proxy_rationale,
        human_acceptance.derived_profile_decision,
    });

    try appendSlice(allocator, &output, "COMPONENT_TREE\n");
    try appendComponentChildren(allocator, &output, source, null, 0);

    const pose = try human_measurements.deriveGlobalPose(source);
    try appendSlice(allocator, &output, "\nSKELETON_TREE\n");
    try appendBoneChildren(allocator, &output, source, &pose, null, 0);

    try appendSlice(allocator, &output, "\nJOINT_INVENTORY\n");
    var previous_joint: ?[]const u8 = null;
    for (0..source.joints.len) |_| {
        const record = selectNext(source.joints, "joint_id", previous_joint).?;
        try appendFmt(allocator, &output, "joint id={s} parent={s} child={s} type={s} mirror={s} profile={s}\n", .{
            record.joint_id.value.bytes,
            record.parent_bone_id.value.bytes,
            record.child_bone_id.value.bytes,
            @tagName(record.joint_type),
            if (record.mirror_joint_id) |id| id.value.bytes else "null",
            if (record.mobility_profile_override) |id| id.value.bytes else "null",
        });
        previous_joint = record.joint_id.value.bytes;
    }

    try appendSlice(allocator, &output, "\nCONTROL_TARGET_TRACES\n");
    const trace_storage = try allocator.alloc(human_controls.TraceEntry, human_controls.traceCount(source));
    defer allocator.free(trace_storage);
    const traces = try human_controls.generateTraces(source, trace_storage);
    for (traces) |trace| try appendFmt(allocator, &output, "control={s} owner={s} area={s} target={s}:{s} mirror={s} space={s} relevant_joint={s} provenance={s}\n", .{
        trace.control_id,
        trace.owner_component_id,
        @tagName(trace.area),
        @tagName(trace.target_kind),
        trace.target_id,
        trace.mirror_control_id orelse "null",
        @tagName(trace.space),
        trace.relevant_joint_id orelse "null",
        trace.provenance,
    });

    try appendSlice(allocator, &output, "\nSELECTED_TRANSFORMS_AND_PARENT_CHAINS\n");
    inline for (.{
        "skeleton_root",
        "pelvis",
        "spine_07",
        "head",
        "upper_arm_left",
        "hand_left",
        "thigh_left",
        "foot_left",
        "toe_big_left_02",
    }) |bone_id| try appendSelectedTransform(allocator, &output, source, &pose, bone_id);

    const measurements = try human_measurements.generate(source);
    try appendFmt(allocator, &output,
        \\
        \\MEASUREMENTS_METERS
        \\total_height={d:.6} shoulder_breadth={d:.6} hip_breadth={d:.6} arm_span={d:.6} torso_length={d:.6} leg_length={d:.6} upper_arm_length={d:.6} forearm_length={d:.6} thigh_length={d:.6} lower_leg_length={d:.6} hand_length={d:.6} foot_length={d:.6} head_height={d:.6}
    , .{
        measurements.total_height_m,
        measurements.shoulder_breadth_m,
        measurements.hip_breadth_m,
        measurements.arm_span_m,
        measurements.torso_length_m,
        measurements.leg_length_m,
        measurements.upper_arm_length_m,
        measurements.forearm_length_m,
        measurements.thigh_length_m,
        measurements.lower_leg_length_m,
        measurements.hand_length_m,
        measurements.foot_length_m,
        measurements.head_height_m,
    });
    try appendSlice(allocator, &output, "\n");
    try appendFmt(allocator, &output,
        \\KEY_COORDINATES
        \\shoulders left={any} right={any}
        \\elbows left={any} right={any}
        \\wrists left={any} right={any}
        \\hips left={any} right={any}
        \\knees left={any} right={any}
        \\ankles left={any} right={any}
        \\eyes left={any} right={any}
        \\ears left={any} right={any}
        \\heel_contacts left={any} right={any}
        \\big_toe_tips left={any} right={any}
        \\jaw={any} head_top={any}
        \\
    , .{
        measurements.key_joints.shoulders.left,
        measurements.key_joints.shoulders.right,
        measurements.key_joints.elbows.left,
        measurements.key_joints.elbows.right,
        measurements.key_joints.wrists.left,
        measurements.key_joints.wrists.right,
        measurements.key_joints.hips.left,
        measurements.key_joints.hips.right,
        measurements.key_joints.knees.left,
        measurements.key_joints.knees.right,
        measurements.key_joints.ankles.left,
        measurements.key_joints.ankles.right,
        measurements.key_joints.eyes.left,
        measurements.key_joints.eyes.right,
        measurements.key_joints.ears.left,
        measurements.key_joints.ears.right,
        measurements.key_joints.heel_contacts.left,
        measurements.key_joints.heel_contacts.right,
        measurements.key_joints.big_toe_tips.left,
        measurements.key_joints.big_toe_tips.right,
        measurements.key_joints.jaw,
        measurements.key_joints.head_top,
    });

    const anchor_storage = try allocator.alloc(human_attachments.AnchorReportEntry, source.anchors.len);
    defer allocator.free(anchor_storage);
    const anchors = try human_attachments.generateAnchorReport(source, anchor_storage);
    try appendSlice(allocator, &output, "ANCHOR_INVENTORY\n");
    for (anchors) |record| try appendFmt(allocator, &output, "anchor id={s} owner={s} driver={s} mirror={s} world={any}\n", .{
        record.anchor_id,
        record.owner_component_id,
        record.driver_bone_id,
        record.mirror_anchor_id orelse "null",
        record.world_position_m,
    });

    const socket_storage = try allocator.alloc(human_attachments.SocketReportEntry, source.sockets.len);
    defer allocator.free(socket_storage);
    const sockets = try human_attachments.generateSocketReport(source, socket_storage);
    try appendSlice(allocator, &output, "\nSOCKET_INVENTORY\n");
    for (sockets) |record| try appendFmt(allocator, &output, "socket id={s} anchor={s} attachment={s} child={s} mount={s}\n", .{
        record.socket_id,
        record.anchor_id,
        record.attachment_id orelse "null",
        record.child_component_id orelse "null",
        record.child_mount_anchor_id orelse "null",
    });

    const mount_storage = try allocator.alloc(human_attachments.MountReportEntry, source.mount_anchors.len);
    defer allocator.free(mount_storage);
    const mounts = try human_attachments.generateMountReport(source, mount_storage);
    try appendSlice(allocator, &output, "\nMOUNT_INVENTORY\n");
    for (mounts) |record| try appendFmt(allocator, &output, "mount id={s} owner={s} attachment={s}\n", .{
        record.mount_anchor_id,
        record.owner_component_id,
        record.attachment_id orelse "null",
    });

    try appendSlice(allocator, &output, "\nATTACHMENT_INVENTORY\n");
    var previous_attachment: ?[]const u8 = null;
    for (0..source.attachments.len) |_| {
        const record = selectNext(source.attachments, "attachment_id", previous_attachment).?;
        try appendFmt(allocator, &output, "attachment id={s} socket={s} child={s} mount={s}\n", .{
            record.attachment_id.value.bytes,
            record.parent_socket_id.value.bytes,
            record.child_component_id.value.bytes,
            record.child_mount_anchor_id.value.bytes,
        });
        previous_attachment = record.attachment_id.value.bytes;
    }

    const landmark_storage = try allocator.alloc(human_structural_semantics.LandmarkReportEntry, source.landmarks.len);
    defer allocator.free(landmark_storage);
    const landmarks = try human_structural_semantics.generateLandmarkReport(source, landmark_storage);
    try appendSlice(allocator, &output, "\nLANDMARK_INVENTORY\n");
    for (landmarks) |record| try appendFmt(allocator, &output, "landmark id={s} anchor={s} mirror={s} world={any}\n", .{
        record.landmark_id,
        record.anchor_id,
        record.mirror_landmark_id orelse "null",
        record.world_position_m,
    });

    const seam_storage = try allocator.alloc(human_structural_semantics.SeamReportEntry, source.shared_seams.len);
    defer allocator.free(seam_storage);
    const seams = try human_structural_semantics.generateSeamReport(source, seam_storage);
    try appendSlice(allocator, &output, "\nSEAM_INVENTORY\n");
    for (seams) |record| try appendFmt(allocator, &output, "seam id={s} a={s}:{s} b={s}:{s}\n", .{
        record.seam_id,
        record.component_a_id,
        record.surface_a_id,
        record.component_b_id,
        record.surface_b_id,
    });

    const site_storage = try allocator.alloc(human_structural_semantics.SiteReportEntry, source.interaction_sites.len);
    defer allocator.free(site_storage);
    const sites = try human_structural_semantics.generateSiteReport(source, site_storage);
    try appendSlice(allocator, &output, "\nINTERACTION_SITE_INVENTORY\n");
    for (sites) |record| try appendFmt(allocator, &output, "site id={s} owner={s} region={s} anchor={s} capacity={d}\n", .{
        record.site_id,
        record.owner_component_id,
        record.region_id,
        record.preferred_anchor_id,
        record.capacity,
    });

    const effector_storage = try allocator.alloc(human_structural_semantics.EffectorReportEntry, source.effectors.len);
    defer allocator.free(effector_storage);
    const effectors = try human_structural_semantics.generateEffectorReport(source, effector_storage);
    try appendSlice(allocator, &output, "\nEFFECTOR_INVENTORY\n");
    for (effectors) |record| try appendFmt(allocator, &output, "effector id={s} owner={s} region={s} anchor={s} capacity={d}\n", .{
        record.effector_id,
        record.owner_component_id,
        record.region_id,
        record.preferred_anchor_id,
        record.capacity,
    });

    try appendSlice(allocator, &output, "\nOPTIONAL_MODULE_STATE\n");
    inline for (.{
        "anus_module_01",
        "vulva_vaginal_canal_module_01",
        "penis_module_01",
        "scrotum_testicles_module_01",
    }) |component_id| {
        const record = findComponent(source, component_id) orelse return error.MissingComponent;
        try appendFmt(allocator, &output, "component={s} requirement={s} default_state={s} multiplicity={d}..{d}\n", .{
            component_id,
            @tagName(record.requirement),
            @tagName(record.default_state),
            record.multiplicity.minimum,
            record.multiplicity.maximum.?,
        });
    }

    try appendSlice(allocator, &output, "\nADULT_ANATOMY_REQUIRED_IDENTITIES\n");
    inline for (.{
        "anterior_genital_anchor",
        "perineal_center_anchor",
        "posterior_anal_anchor",
        "groin_left_anchor",
        "groin_right_anchor",
        "pubic_center_anchor",
        "glute_left_anchor",
        "glute_right_anchor",
    }) |anchor_id| try appendFmt(allocator, &output, "anchor={s} present={s}\n", .{ anchor_id, if (hasAnchor(source, anchor_id)) "yes" else "no" });
    inline for (.{
        "anterior_genital_site",
        "perineal_center_site",
        "posterior_anal_site",
        "groin_left_site",
        "groin_right_site",
        "pubic_center_site",
        "glute_left_site",
        "glute_right_site",
        "vulva_structural_site",
        "penis_structural_site",
        "scrotum_structural_site",
    }) |site_id| try appendFmt(allocator, &output, "site={s} present={s}\n", .{ site_id, if (hasSite(source, site_id)) "yes" else "no" });

    try appendSlice(allocator, &output, "\nINVALID_FIXTURE_DIAGNOSTICS\n");
    for (human_acceptance.invalid_fixture_specs) |spec| try appendFmt(allocator, &output, "fixture={s} file={s} stage={s} code={s} object={s} id={s} property={s} message={s}\n", .{
        spec.fixture_id,
        spec.file_name,
        @tagName(spec.stage),
        @tagName(spec.expected.code),
        spec.expected.object_type,
        spec.expected.object_id orelse "null",
        spec.expected.property orelse "null",
        spec.expected.message,
    });

    try appendSlice(allocator, &output,
        \\
        \\OPEN_TUNING_CLASSIFICATION
        \\human_base.open_tuning=neutral_material_colors
        \\human_rig.open_tuning=rest_pose_lengths_offsets_and_a_pose_angles
        \\human_joints.open_tuning=provisional_preferred_and_hard_ROM_stiffness_and_swing_twist
        \\human_controls.open_tuning=normalized_control_domains_and_neutral_defaults
        \\human_attachments.open_tuning=structural_registration_offsets
        \\human_rig.measurement_tolerance_m=0.00001 numerical_validation_only
        \\human_rig.test_only_symmetry_tolerance=0.00001 test_validation_only
        \\human_attachments.report_tolerance_m=0.00001 numerical_validation_only
        \\collision_proxy_dimensions=none deferred_from_M02
    );
    try appendSlice(allocator, &output, "\nOPEN_TUNING_VALUES\n");
    try appendMaterialOpenTuning(allocator, &output, source);
    try appendRigOpenTuning(allocator, &output, source);
    try appendControlOpenTuning(allocator, &output, source);
    try appendAttachmentOpenTuning(allocator, &output, source);
    try appendMobilityOpenTuning(allocator, &output, source);
    try appendFmt(allocator, &output, "human_rig.measurement_tolerance_m={d:.9}\nhuman_rig.test_only_symmetry_tolerance={d:.9}\nhuman_attachments.report_tolerance_m={d:.9}\n", .{
        human_rig.measurement_tolerance_m,
        human_rig.test_only_symmetry_tolerance,
        human_attachments.report_tolerance_m,
    });
    return output.toOwnedSlice(allocator);
}

const Axis = enum { x, y, z };

fn appendMaterialOpenTuning(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: *const definition.CanonicalCreatureDefinition,
) !void {
    const descriptors = [_]struct { name: []const u8, instance_id: []const u8 }{
        .{ .name = "skin_linear_srgb_rgba", .instance_id = "human_base_skin" },
        .{ .name = "lips_linear_srgb_rgba", .instance_id = "human_base_lips" },
        .{ .name = "nails_linear_srgb_rgba", .instance_id = "human_base_nails" },
        .{ .name = "tooth_enamel_linear_srgb_rgba", .instance_id = "human_base_tooth_enamel" },
        .{ .name = "gums_linear_srgb_rgba", .instance_id = "human_base_gums" },
        .{ .name = "oral_mucosa_linear_srgb_rgba", .instance_id = "human_base_oral_mucosa" },
        .{ .name = "tongue_linear_srgb_rgba", .instance_id = "human_base_tongue" },
        .{ .name = "sclera_linear_srgb_rgba", .instance_id = "human_base_sclera" },
        .{ .name = "iris_linear_srgb_rgba", .instance_id = "human_base_iris" },
        .{ .name = "pupil_linear_srgb_rgba", .instance_id = "human_base_pupil" },
        .{ .name = "cornea_linear_srgb_rgba", .instance_id = "human_base_cornea" },
    };
    for (descriptors) |descriptor| {
        try appendFmt(allocator, output, "human_base.open_tuning.{s}={any}\n", .{
            descriptor.name,
            try materialBaseColor(source, descriptor.instance_id),
        });
    }
}

fn appendRigOpenTuning(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: *const definition.CanonicalCreatureDefinition,
) !void {
    try appendSourceValue(allocator, output, "human_rig.open_tuning.pelvis_height_m", try boneTranslation(source, "pelvis", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.hip_half_breadth_m", try boneTranslationAbs(source, "thigh_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.spine_01_rise_m", try boneTranslation(source, "spine_01", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.spine_segment_rise_m", try boneTranslation(source, "spine_02", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.neck_01_rise_m", try boneTranslation(source, "neck_01", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.neck_segment_rise_m", try boneTranslation(source, "neck_02", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.head_rise_m", try boneTranslation(source, "head", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.head_top_offset_m", try anchorTranslation(source, "head_top_anchor", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.jaw_drop_m", try boneTranslationAbs(source, "jaw", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.jaw_forward_m", try boneTranslation(source, "jaw", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.jaw_bottom_offset_m", try anchorTranslationAbs(source, "chin_anchor", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.clavicle_outset_m", try boneTranslationAbs(source, "clavicle_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.clavicle_rise_m", try boneTranslation(source, "clavicle_left", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.scapula_outset_m", try boneTranslationAbs(source, "scapula_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.scapula_drop_m", try boneTranslationAbs(source, "scapula_left", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.scapula_back_m", try boneTranslationAbs(source, "scapula_left", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.shoulder_outset_m", try boneTranslationAbs(source, "upper_arm_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.upper_arm_length_m", try boneDisplayLength(source, "upper_arm_left"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.forearm_length_m", try boneDisplayLength(source, "forearm_left"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.upper_arm_a_pose_degrees", try boneZRotationDegrees(source, "upper_arm_left"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.elbow_a_pose_degrees", try boneZRotationDegrees(source, "forearm_left"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.hand_root_length_m", try boneDisplayLength(source, "hand_left"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.finger_metacarpal_length_m", try boneTranslationAbs(source, "index_proximal_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.finger_proximal_length_m", try boneTranslationAbs(source, "index_middle_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.finger_middle_length_m", try boneTranslationAbs(source, "index_distal_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.finger_distal_length_m", try boneDisplayLength(source, "index_distal_left"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.thumb_metacarpal_length_m", try boneTranslationAbs(source, "thumb_proximal_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.thumb_proximal_length_m", try boneTranslationAbs(source, "thumb_distal_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.thumb_distal_length_m", try boneDisplayLength(source, "thumb_distal_left"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.thumb_base_outset_m", try boneTranslationAbs(source, "thumb_metacarpal_left", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.thumb_base_drop_m", try boneTranslationAbs(source, "thumb_metacarpal_left", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.thumb_base_forward_m", try boneTranslation(source, "thumb_metacarpal_left", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.finger_spacing_m", try boneTranslationAbs(source, "index_metacarpal_left", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.thigh_length_m", try boneDisplayLength(source, "thigh_left"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.lower_leg_length_m", try boneDisplayLength(source, "lower_leg_left"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.ankle_to_foot_drop_m", try boneTranslationAbs(source, "foot_left", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.foot_to_midfoot_forward_m", try boneTranslation(source, "midfoot_left", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.foot_to_midfoot_drop_m", try boneTranslationAbs(source, "midfoot_left", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.midfoot_to_forefoot_forward_m", try boneTranslation(source, "forefoot_left", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.midfoot_to_forefoot_drop_m", try boneTranslationAbs(source, "forefoot_left", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.heel_back_offset_m", try anchorTranslationAbs(source, "heel_contact_left_anchor", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.heel_ground_drop_m", try anchorTranslationAbs(source, "heel_contact_left_anchor", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.big_toe_01_length_m", try boneTranslation(source, "toe_big_left_01", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.big_toe_02_length_m", try boneTranslation(source, "toe_big_left_02", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.big_toe_tip_length_m", try boneDisplayLength(source, "toe_big_left_02"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.lesser_toe_01_length_m", try boneTranslation(source, "toe_index_left_01", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.lesser_toe_02_length_m", try boneTranslation(source, "toe_index_left_02", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.lesser_toe_03_length_m", try boneTranslation(source, "toe_index_left_03", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.lesser_toe_tip_length_m", try boneDisplayLength(source, "toe_index_left_03"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.toe_spacing_m", try boneTranslationAbs(source, "toe_index_left_01", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.eye_half_spacing_m", try boneTranslationAbs(source, "eyeball_left_01", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.eye_rise_m", try boneTranslation(source, "eyeball_left_01", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.eye_forward_m", try boneTranslation(source, "eyeball_left_01", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.eyelid_horizontal_offset_m", @abs(try boneTranslation(source, "eyelid_upper_left_inner", .x) - try boneTranslation(source, "eyeball_left_01", .x)));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.eyelid_vertical_offset_m", @abs(try boneTranslation(source, "eyelid_upper_left_center", .y) - try boneTranslation(source, "eyeball_left_01", .y)));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.eyelid_forward_offset_m", @abs(try boneTranslation(source, "eyelid_upper_left_center", .z) - try boneTranslation(source, "eyeball_left_01", .z)));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.eyeball_display_length_m", try boneDisplayLength(source, "eyeball_left_01"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.eyelid_display_length_m", try boneDisplayLength(source, "eyelid_upper_left_center"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.ear_half_spacing_m", try boneTranslationAbs(source, "ear_root_left_01", .x));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.ear_rise_m", try boneTranslation(source, "ear_root_left_01", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.ear_display_length_m", try boneDisplayLength(source, "ear_root_left_01"));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.tongue_root_drop_m", try boneTranslationAbs(source, "tongue_01", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.tongue_root_forward_m", try boneTranslation(source, "tongue_01", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.tongue_segment_length_m", try boneTranslation(source, "tongue_02", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.tongue_tip_length_m", try boneTranslation(source, "tongue_tip_01", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.penis_root_drop_m", try boneTranslationAbs(source, "penis_root_01", .y));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.penis_root_forward_m", try boneTranslation(source, "penis_root_01", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.penis_shaft_segment_m", try boneTranslation(source, "penis_shaft_01", .z));
    try appendSourceValue(allocator, output, "human_rig.open_tuning.penis_tip_reference_m", try boneTranslation(source, "penis_tip_01", .z));
}

fn appendControlOpenTuning(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: *const definition.CanonicalCreatureDefinition,
) !void {
    try appendSourceValue(allocator, output, "human_controls.open_tuning.normalized_minimum", try controlLimitScalar(source, "eyelids_blink_control", .minimum));
    try appendSourceValue(allocator, output, "human_controls.open_tuning.normalized_maximum", try controlLimitScalar(source, "eyelids_blink_control", .maximum));
    try appendSourceValue(allocator, output, "human_controls.open_tuning.unipolar_neutral", try controlDefaultScalar(source, "eyelids_blink_control"));
    try appendSourceValue(allocator, output, "human_controls.open_tuning.centered_neutral", try controlDefaultScalar(source, "finger_left_spread_control"));
}

fn appendAttachmentOpenTuning(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: *const definition.CanonicalCreatureDefinition,
) !void {
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.face_center_rise_m", try anchorTranslation(source, "face_center_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.face_reference_forward_m", try anchorTranslation(source, "face_center_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.facial_perception_forward_m", try anchorTranslation(source, "facial_perception_fallback_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.hair_root_rise_m", try anchorTranslation(source, "hair_root_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.hair_root_back_m", try anchorTranslationAbs(source, "hair_root_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.headwear_rise_m", try anchorTranslation(source, "headwear_center_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.sternum_rise_m", try anchorTranslation(source, "sternum_center_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.sternum_forward_m", try anchorTranslation(source, "sternum_center_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.navel_drop_m", try anchorTranslationAbs(source, "navel_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.navel_forward_m", try anchorTranslation(source, "navel_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.waist_forward_m", try anchorTranslation(source, "waist_center_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.pubic_drop_m", try anchorTranslationAbs(source, "pubic_center_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.pubic_forward_m", try anchorTranslation(source, "pubic_center_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.anterior_genital_drop_m", try anchorTranslationAbs(source, "anterior_genital_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.anterior_genital_forward_m", try anchorTranslation(source, "anterior_genital_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.perineal_drop_m", try anchorTranslationAbs(source, "perineal_center_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.posterior_anal_drop_m", try anchorTranslationAbs(source, "posterior_anal_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.posterior_anal_back_m", try anchorTranslationAbs(source, "posterior_anal_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.upper_back_rise_m", try anchorTranslation(source, "upper_back_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.upper_back_offset_m", try anchorTranslationAbs(source, "upper_back_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.mouth_forward_m", try anchorTranslation(source, "mouth_interaction_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.palm_center_offset_m", try anchorTranslationAbs(source, "palm_center_left_anchor", .x));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.grip_offset_m", try anchorTranslationAbs(source, "grip_left_anchor", .x));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.finger_pad_ratio", try anchorTranslationAbs(source, "finger_pad_index_left_anchor", .x) / try boneDisplayLength(source, "index_distal_left"));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.nail_bed_ratio", try anchorTranslationAbs(source, "fingernail_bed_index_left_anchor", .x) / try boneDisplayLength(source, "index_distal_left"));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.nail_surface_offset_m", try anchorTranslationAbs(source, "fingernail_bed_index_left_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.groin_half_spacing_m", try anchorTranslationAbs(source, "groin_left_anchor", .x));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.groin_drop_m", try anchorTranslationAbs(source, "groin_left_anchor", .y));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.groin_forward_m", try anchorTranslation(source, "groin_left_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.glute_half_spacing_m", try anchorTranslationAbs(source, "glute_left_anchor", .x));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.glute_back_m", try anchorTranslationAbs(source, "glute_left_anchor", .z));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.foot_outer_half_width_m", try anchorTranslationAbs(source, "foot_outer_edge_left_anchor", .x));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.foot_inner_half_width_m", try anchorTranslationAbs(source, "foot_inner_edge_left_anchor", .x));
    try appendSourceValue(allocator, output, "human_attachments.open_tuning.foot_edge_forward_m", try anchorTranslation(source, "foot_outer_edge_left_anchor", .z));
}

fn appendMobilityOpenTuning(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: *const definition.CanonicalCreatureDefinition,
) !void {
    const descriptors = [_]struct { profile_id: []const u8, joint_id: []const u8 }{
        .{ .profile_id = "human_pelvis_mobility", .joint_id = "pelvis_joint" },
        .{ .profile_id = "human_spine_mobility", .joint_id = "spine_01_joint" },
        .{ .profile_id = "human_neck_head_mobility", .joint_id = "head_joint" },
        .{ .profile_id = "human_jaw_mobility", .joint_id = "jaw_joint" },
        .{ .profile_id = "human_shoulder_girdle_mobility", .joint_id = "clavicle_left_joint" },
        .{ .profile_id = "human_shoulder_mobility", .joint_id = "upper_arm_left_joint" },
        .{ .profile_id = "human_twist_distribution_mobility", .joint_id = "forearm_twist_left_01_joint" },
        .{ .profile_id = "human_elbow_mobility", .joint_id = "forearm_left_joint" },
        .{ .profile_id = "human_wrist_mobility", .joint_id = "hand_left_joint" },
        .{ .profile_id = "human_thumb_base_mobility", .joint_id = "thumb_metacarpal_left_joint" },
        .{ .profile_id = "human_finger_base_mobility", .joint_id = "index_metacarpal_left_joint" },
        .{ .profile_id = "human_finger_hinge_mobility", .joint_id = "index_distal_left_joint" },
        .{ .profile_id = "human_hip_mobility", .joint_id = "thigh_left_joint" },
        .{ .profile_id = "human_knee_mobility", .joint_id = "lower_leg_left_joint" },
        .{ .profile_id = "human_ankle_foot_mobility", .joint_id = "ankle_left_joint" },
        .{ .profile_id = "human_toe_mobility", .joint_id = "toe_big_left_01_joint" },
        .{ .profile_id = "human_eye_mobility", .joint_id = "eyeball_left_01_joint" },
        .{ .profile_id = "human_eyelid_mobility", .joint_id = "eyelid_lower_left_center_joint" },
        .{ .profile_id = "human_tongue_mobility", .joint_id = "tongue_01_joint" },
        .{ .profile_id = "human_ear_mobility", .joint_id = "ear_root_left_01_joint" },
        .{ .profile_id = "human_optional_soft_chain_mobility", .joint_id = "penis_root_01_joint" },
    };
    for (descriptors) |descriptor| {
        const joint_record = findJoint(source, descriptor.joint_id) orelse return error.MissingJoint;
        const profile_id = if (joint_record.mobility_profile_override) |id| id.value.bytes else return error.MissingMobilityProfile;
        if (!std.mem.eql(u8, profile_id, descriptor.profile_id)) return error.UnexpectedMobilityProfile;
        try appendFmt(allocator, output, "human_joints.open_tuning profile={s} type={s} preferred={any} hard={any} bend={any} swing_twist={any} stiffness={d:.9}\n", .{
            profile_id,
            @tagName(joint_record.joint_type),
            joint_record.preferred_range,
            joint_record.hard_range,
            joint_record.preferred_bend_direction,
            joint_record.swing_twist,
            joint_record.limit_behavior.stiffness orelse return error.MissingJointStiffness,
        });
    }
}

fn appendSourceValue(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    label: []const u8,
    value: f32,
) !void {
    const source_precision_value = @round(value * 1_000_000.0) / 1_000_000.0;
    try appendFmt(allocator, output, "{s}={any}\n", .{ label, source_precision_value });
}

fn boneTranslation(source: *const definition.CanonicalCreatureDefinition, id: []const u8, axis: Axis) !f32 {
    const bone = findBone(source, id) orelse return error.MissingBone;
    return vectorAxis(bone.local_rest_transform.translation_m, axis);
}

fn boneTranslationAbs(source: *const definition.CanonicalCreatureDefinition, id: []const u8, axis: Axis) !f32 {
    return @abs(try boneTranslation(source, id, axis));
}

fn boneDisplayLength(source: *const definition.CanonicalCreatureDefinition, id: []const u8) !f32 {
    const bone = findBone(source, id) orelse return error.MissingBone;
    return bone.display_length_m orelse error.MissingBoneDisplayLength;
}

fn boneZRotationDegrees(source: *const definition.CanonicalCreatureDefinition, id: []const u8) !f32 {
    const bone = findBone(source, id) orelse return error.MissingBone;
    const rotation = bone.local_rest_transform.rotation;
    const radians = 2.0 * std.math.atan2(@abs(rotation.z), rotation.w);
    return @round(radians * (180.0 / std.math.pi));
}

fn anchorTranslation(source: *const definition.CanonicalCreatureDefinition, id: []const u8, axis: Axis) !f32 {
    const anchor = findAnchor(source, id) orelse return error.MissingAnchor;
    return vectorAxis(anchor.local_transform.translation_m, axis);
}

fn anchorTranslationAbs(source: *const definition.CanonicalCreatureDefinition, id: []const u8, axis: Axis) !f32 {
    return @abs(try anchorTranslation(source, id, axis));
}

fn controlLimitScalar(
    source: *const definition.CanonicalCreatureDefinition,
    id: []const u8,
    comptime field: enum { minimum, maximum },
) !f32 {
    const control = findControl(source, id) orelse return error.MissingControl;
    const limits = control.limits orelse return error.MissingControlLimits;
    const value = @field(limits, @tagName(field)) orelse return error.MissingControlLimit;
    return switch (value) {
        .scalar => |scalar| scalar,
        else => error.UnexpectedControlValue,
    };
}

fn controlDefaultScalar(source: *const definition.CanonicalCreatureDefinition, id: []const u8) !f32 {
    const control = findControl(source, id) orelse return error.MissingControl;
    const value = control.default_value orelse return error.MissingControlDefault;
    return switch (value) {
        .scalar => |scalar| scalar,
        else => error.UnexpectedControlValue,
    };
}

fn materialBaseColor(source: *const definition.CanonicalCreatureDefinition, id: []const u8) ![4]f32 {
    for (source.material_instances) |instance| {
        if (!std.mem.eql(u8, instance.material_instance_id.value.bytes, id)) continue;
        for (instance.properties) |property| {
            if (!std.mem.eql(u8, property.property_id.value.bytes, "base_color")) continue;
            return switch (property.value) {
                .linear_srgb_rgba => |color| color.channels,
                else => error.UnexpectedMaterialValue,
            };
        }
        return error.MissingMaterialBaseColor;
    }
    return error.MissingMaterialInstance;
}

fn vectorAxis(vector: @import("math3d.zig").Vec3, axis: Axis) f32 {
    return switch (axis) {
        .x => vector.x,
        .y => vector.y,
        .z => vector.z,
    };
}

fn findAnchor(source: *const definition.CanonicalCreatureDefinition, id: []const u8) ?@import("attachment.zig").Anchor {
    for (source.anchors) |anchor| if (std.mem.eql(u8, anchor.anchor_id.value.bytes, id)) return anchor;
    return null;
}

fn findControl(source: *const definition.CanonicalCreatureDefinition, id: []const u8) ?rig.Control {
    for (source.controls) |control| if (std.mem.eql(u8, control.control_id.value.bytes, id)) return control;
    return null;
}

fn findJoint(source: *const definition.CanonicalCreatureDefinition, id: []const u8) ?rig.Joint {
    for (source.joints) |joint_record| if (std.mem.eql(u8, joint_record.joint_id.value.bytes, id)) return joint_record;
    return null;
}

fn activeBoneCount(source: *const definition.CanonicalCreatureDefinition) usize {
    var count: usize = 0;
    for (source.bones) |bone| {
        const owner = bone.owner_component_id orelse continue;
        for (source.components) |component| {
            if (component.component_id.eql(owner) and component.default_state == .enabled) {
                count += 1;
                break;
            }
        }
    }
    return count;
}

fn componentOwnedBoneCount(source: *const definition.CanonicalCreatureDefinition, component_id: []const u8) usize {
    var count: usize = 0;
    for (source.bones) |bone| if (bone.owner_component_id) |owner| {
        if (std.mem.eql(u8, owner.value.bytes, component_id)) count += 1;
    };
    return count;
}

fn controlAreaCount(source: *const definition.CanonicalCreatureDefinition, area: human_controls.Area) usize {
    var count: usize = 0;
    for (source.controls) |control| {
        if (human_controls.areaForControl(control.control_id.value.bytes) == area) count += 1;
    }
    return count;
}

fn appendComponentChildren(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: *const definition.CanonicalCreatureDefinition,
    parent_id: ?[]const u8,
    depth: usize,
) !void {
    var previous: ?[]const u8 = null;
    while (selectNextComponentChild(source, parent_id, previous)) |record| {
        try appendIndent(allocator, output, depth);
        try appendFmt(allocator, output, "- {s} type={s} requirement={s} state={s} multiplicity={d}..{d}\n", .{
            record.component_id.value.bytes,
            record.component_type.value.bytes,
            @tagName(record.requirement),
            @tagName(record.default_state),
            record.multiplicity.minimum,
            record.multiplicity.maximum.?,
        });
        try appendComponentChildren(allocator, output, source, record.component_id.value.bytes, depth + 1);
        previous = record.component_id.value.bytes;
    }
}

fn appendBoneChildren(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: *const definition.CanonicalCreatureDefinition,
    pose: *const human_measurements.GlobalPose,
    parent_id: ?[]const u8,
    depth: usize,
) !void {
    var previous: ?[]const u8 = null;
    while (selectNextBoneChild(source, parent_id, previous)) |record| {
        const world = try pose.transformFor(source, record.bone_id.value.bytes);
        try appendIndent(allocator, output, depth);
        try appendFmt(allocator, output, "- {s} owner={s} mirror={s} deforms={s} local_t={any} local_q={any} local_s={any} world_t={any}\n", .{
            record.bone_id.value.bytes,
            if (record.owner_component_id) |id| id.value.bytes else "null",
            if (record.mirror_bone_id) |id| id.value.bytes else "null",
            if (record.deforms_mesh) "yes" else "no",
            record.local_rest_transform.translation_m,
            record.local_rest_transform.rotation,
            record.local_rest_transform.scale,
            world.translation_m,
        });
        try appendBoneChildren(allocator, output, source, pose, record.bone_id.value.bytes, depth + 1);
        previous = record.bone_id.value.bytes;
    }
}

fn appendSelectedTransform(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: *const definition.CanonicalCreatureDefinition,
    pose: *const human_measurements.GlobalPose,
    bone_id: []const u8,
) !void {
    const bone = findBone(source, bone_id) orelse return error.MissingBone;
    const world = try pose.transformFor(source, bone_id);
    try appendFmt(allocator, output, "bone={s} parent_chain=", .{bone_id});
    try appendParentChain(allocator, output, source, bone);
    try appendFmt(allocator, output, " mirror={s} local_t={any} local_q={any} local_s={any} world_x={any} world_y={any} world_z={any} world_t={any}\n", .{
        if (bone.mirror_bone_id) |id| id.value.bytes else "null",
        bone.local_rest_transform.translation_m,
        bone.local_rest_transform.rotation,
        bone.local_rest_transform.scale,
        world.x_axis,
        world.y_axis,
        world.z_axis,
        world.translation_m,
    });
}

fn appendParentChain(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    source: *const definition.CanonicalCreatureDefinition,
    bone: rig.Bone,
) !void {
    if (bone.parent_bone_id) |parent_id| {
        const parent = findBone(source, parent_id.value.bytes) orelse return error.MissingBone;
        try appendParentChain(allocator, output, source, parent);
        try appendSlice(allocator, output, "/");
    }
    try appendSlice(allocator, output, bone.bone_id.value.bytes);
}

fn selectNextComponentChild(source: *const definition.CanonicalCreatureDefinition, parent_id: ?[]const u8, previous: ?[]const u8) ?@import("component.zig").Component {
    var selected: ?@import("component.zig").Component = null;
    for (source.components) |record| {
        if (!optionalIdMatches(record.parent_component_id, parent_id)) continue;
        const id = record.component_id.value.bytes;
        if (previous) |value| if (std.mem.order(u8, id, value) != .gt) continue;
        if (selected == null or std.mem.order(u8, id, selected.?.component_id.value.bytes) == .lt) selected = record;
    }
    return selected;
}

fn selectNextBoneChild(source: *const definition.CanonicalCreatureDefinition, parent_id: ?[]const u8, previous: ?[]const u8) ?rig.Bone {
    var selected: ?rig.Bone = null;
    for (source.bones) |record| {
        if (!optionalIdMatches(record.parent_bone_id, parent_id)) continue;
        const id = record.bone_id.value.bytes;
        if (previous) |value| if (std.mem.order(u8, id, value) != .gt) continue;
        if (selected == null or std.mem.order(u8, id, selected.?.bone_id.value.bytes) == .lt) selected = record;
    }
    return selected;
}

fn optionalIdMatches(actual: anytype, expected: ?[]const u8) bool {
    if (actual == null or expected == null) return actual == null and expected == null;
    return std.mem.eql(u8, actual.?.value.bytes, expected.?);
}

fn selectNext(records: anytype, comptime id_field: []const u8, previous: ?[]const u8) ?@TypeOf(records[0]) {
    var selected: ?@TypeOf(records[0]) = null;
    for (records) |record| {
        const id = @field(record, id_field).value.bytes;
        if (previous) |value| if (std.mem.order(u8, id, value) != .gt) continue;
        if (selected == null or std.mem.order(u8, id, @field(selected.?, id_field).value.bytes) == .lt) selected = record;
    }
    return selected;
}

fn findBone(source: *const definition.CanonicalCreatureDefinition, id: []const u8) ?rig.Bone {
    for (source.bones) |record| if (std.mem.eql(u8, record.bone_id.value.bytes, id)) return record;
    return null;
}

fn findComponent(source: *const definition.CanonicalCreatureDefinition, id: []const u8) ?@import("component.zig").Component {
    for (source.components) |record| if (std.mem.eql(u8, record.component_id.value.bytes, id)) return record;
    return null;
}

fn hasAnchor(source: *const definition.CanonicalCreatureDefinition, id: []const u8) bool {
    for (source.anchors) |record| if (std.mem.eql(u8, record.anchor_id.value.bytes, id)) return true;
    return false;
}

fn hasSite(source: *const definition.CanonicalCreatureDefinition, id: []const u8) bool {
    for (source.interaction_sites) |record| if (std.mem.eql(u8, record.site_id.value.bytes, id)) return true;
    return false;
}

fn appendIndent(allocator: std.mem.Allocator, output: *std.ArrayList(u8), depth: usize) !void {
    for (0..depth * 2) |_| try output.append(allocator, ' ');
}

fn appendSlice(allocator: std.mem.Allocator, output: *std.ArrayList(u8), bytes: []const u8) !void {
    try output.appendSlice(allocator, bytes);
}

fn appendFmt(allocator: std.mem.Allocator, output: *std.ArrayList(u8), comptime format: []const u8, args: anytype) !void {
    const rendered = try std.fmt.allocPrint(allocator, format, args);
    defer allocator.free(rendered);
    try output.appendSlice(allocator, rendered);
}
