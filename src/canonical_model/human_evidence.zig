const std = @import("std");
const definition = @import("definition.zig");
const human_acceptance = @import("human_acceptance.zig");
const human_attachments = @import("human_attachments.zig");
const human_base = @import("human_base.zig");
const human_controls = @import("human_controls.zig");
const human_joints = @import("human_joints.zig");
const human_measurements = @import("human_measurements.zig");
const human_rig = @import("human_rig.zig");
const human_structural_semantics = @import("human_structural_semantics.zig");
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
        human_rig.shared_bone_count,
        human_rig.optional_penis_bone_count,
        source.joints.len,
        source.controls.len,
        human_controls.spine_control_count,
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
    var trace_storage: [human_controls.trace_count]human_controls.TraceEntry = undefined;
    const traces = try human_controls.generateTraces(&trace_storage);
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

    var anchor_storage: [human_attachments.anchor_count]human_attachments.AnchorReportEntry = undefined;
    const anchors = try human_attachments.generateAnchorReport(source, &anchor_storage);
    try appendSlice(allocator, &output, "ANCHOR_INVENTORY\n");
    for (anchors) |record| try appendFmt(allocator, &output, "anchor id={s} owner={s} driver={s} mirror={s} world={any}\n", .{
        record.anchor_id,
        record.owner_component_id,
        record.driver_bone_id,
        record.mirror_anchor_id orelse "null",
        record.world_position_m,
    });

    var socket_storage: [human_attachments.socket_count]human_attachments.SocketReportEntry = undefined;
    const sockets = try human_attachments.generateSocketReport(source, &socket_storage);
    try appendSlice(allocator, &output, "\nSOCKET_INVENTORY\n");
    for (sockets) |record| try appendFmt(allocator, &output, "socket id={s} anchor={s} attachment={s} child={s} mount={s}\n", .{
        record.socket_id,
        record.anchor_id,
        record.attachment_id orelse "null",
        record.child_component_id orelse "null",
        record.child_mount_anchor_id orelse "null",
    });

    var mount_storage: [human_attachments.mount_anchor_count]human_attachments.MountReportEntry = undefined;
    const mounts = try human_attachments.generateMountReport(source, &mount_storage);
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

    var landmark_storage: [human_structural_semantics.landmark_count]human_structural_semantics.LandmarkReportEntry = undefined;
    const landmarks = try human_structural_semantics.generateLandmarkReport(source, &landmark_storage);
    try appendSlice(allocator, &output, "\nLANDMARK_INVENTORY\n");
    for (landmarks) |record| try appendFmt(allocator, &output, "landmark id={s} anchor={s} mirror={s} world={any}\n", .{
        record.landmark_id,
        record.anchor_id,
        record.mirror_landmark_id orelse "null",
        record.world_position_m,
    });

    var seam_storage: [human_structural_semantics.shared_seam_count]human_structural_semantics.SeamReportEntry = undefined;
    const seams = try human_structural_semantics.generateSeamReport(source, &seam_storage);
    try appendSlice(allocator, &output, "\nSEAM_INVENTORY\n");
    for (seams) |record| try appendFmt(allocator, &output, "seam id={s} a={s}:{s} b={s}:{s}\n", .{
        record.seam_id,
        record.component_a_id,
        record.surface_a_id,
        record.component_b_id,
        record.surface_b_id,
    });

    var site_storage: [human_structural_semantics.interaction_site_count]human_structural_semantics.SiteReportEntry = undefined;
    const sites = try human_structural_semantics.generateSiteReport(source, &site_storage);
    try appendSlice(allocator, &output, "\nINTERACTION_SITE_INVENTORY\n");
    for (sites) |record| try appendFmt(allocator, &output, "site id={s} owner={s} region={s} anchor={s} capacity={d}\n", .{
        record.site_id,
        record.owner_component_id,
        record.region_id,
        record.preferred_anchor_id,
        record.capacity,
    });

    var effector_storage: [human_structural_semantics.effector_count]human_structural_semantics.EffectorReportEntry = undefined;
    const effectors = try human_structural_semantics.generateEffectorReport(source, &effector_storage);
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
    try appendOpenTuningNamespace(allocator, &output, "human_base.open_tuning", human_base.open_tuning);
    try appendOpenTuningNamespace(allocator, &output, "human_rig.open_tuning", human_rig.open_tuning);
    try appendOpenTuningNamespace(allocator, &output, "human_controls.open_tuning", human_controls.open_tuning);
    try appendOpenTuningNamespace(allocator, &output, "human_attachments.open_tuning", human_attachments.open_tuning);
    for (human_joints.mobility_profiles) |profile| try appendFmt(allocator, &output, "human_joints.open_tuning profile={s} type={s} preferred={any} hard={any} bend={any} swing_twist={any} stiffness={d:.9}\n", .{
        profile.profile_id,
        @tagName(profile.joint_type),
        profile.preferred_range,
        profile.hard_range,
        profile.preferred_bend_direction,
        profile.swing_twist,
        profile.stiffness,
    });
    try appendFmt(allocator, &output, "human_rig.measurement_tolerance_m={d:.9}\nhuman_rig.test_only_symmetry_tolerance={d:.9}\nhuman_attachments.report_tolerance_m={d:.9}\n", .{
        human_rig.measurement_tolerance_m,
        human_rig.test_only_symmetry_tolerance,
        human_attachments.report_tolerance_m,
    });
    return output.toOwnedSlice(allocator);
}

fn appendOpenTuningNamespace(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    comptime namespace_name: []const u8,
    comptime namespace: type,
) !void {
    inline for (@typeInfo(namespace).@"struct".decls) |declaration| {
        try appendFmt(allocator, output, "{s}.{s}={any}\n", .{
            namespace_name,
            declaration.name,
            @field(namespace, declaration.name),
        });
    }
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
