const std = @import("std");
const canonical = @import("canonical_model");

const diagnostics = canonical.diagnostics;
const human_attachments = canonical.human_attachments;
const human_base = canonical.human_base;
const human_structural_semantics = canonical.human_structural_semantics;
const human_structural_validation = canonical.human_structural_validation;
const identity = canonical.identity;
const normalization = canonical.normalization;
const parsing = canonical.parsing;
const serialization = canonical.serialization;
const validation = canonical.validation;

test "Prompt 2D structural semantics validate and round-trip canonically" {
    try human_structural_validation.validatePrompt2D(&human_base.source);
    var diagnostic_storage: [1024]diagnostics.Diagnostic = undefined;
    const normalized = try normalization.normalize(&human_base.source, .{}, &diagnostic_storage);
    try std.testing.expect(normalized.isValid());
    const canonical_bytes = try serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(canonical_bytes);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "\"mirror_anchor_id\":\"shoulder_right_anchor\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "\"mirror_landmark_id\":\"shoulder_right_landmark\"") != null);

    var parsed = try parsing.parse(std.testing.allocator, canonical_bytes);
    defer parsed.deinit();
    try human_structural_validation.validatePrompt2D(&parsed.value);
    var round_trip_diagnostics: [1024]diagnostics.Diagnostic = undefined;
    const round_trip = try normalization.normalize(&parsed.value, .{}, &round_trip_diagnostics);
    try std.testing.expect(round_trip.isValid());
    const round_trip_bytes = try serialization.serializeAlloc(std.testing.allocator, round_trip.normalized.?);
    defer std.testing.allocator.free(round_trip_bytes);
    try std.testing.expectEqualStrings(canonical_bytes, round_trip_bytes);
}

test "Prompt 2D anchor socket mount and attachment inventories are explicit" {
    try std.testing.expectEqual(@as(usize, 106), human_base.source.anchors.len);
    try std.testing.expectEqual(@as(usize, 22), human_base.source.sockets.len);
    try std.testing.expectEqual(@as(usize, 20), human_base.source.mount_anchors.len);
    try std.testing.expectEqual(@as(usize, 20), human_base.source.attachments.len);
    inline for (.{
        "eye_socket_left_anchor",
        "ear_root_right_anchor",
        "clavicle_left_anchor",
        "palm_center_right_anchor",
        "thumb_pad_left_anchor",
        "fingertip_little_right_anchor",
        "posterior_anal_anchor",
        "groin_left_anchor",
        "foot_outer_edge_right_anchor",
        "toe_pad_big_left_anchor",
    }) |anchor_id| try std.testing.expect(anchorIndex(anchor_id) != null);

    var socket_storage: [human_attachments.socket_count]human_attachments.SocketReportEntry = undefined;
    const sockets = try human_attachments.generateSocketReport(&human_base.source, &socket_storage);
    const hair = findSocketReport(sockets, "hair_socket") orelse return error.MissingSocketReport;
    const headwear = findSocketReport(sockets, "headwear_socket") orelse return error.MissingSocketReport;
    try std.testing.expect(hair.attachment_id == null);
    try std.testing.expect(headwear.attachment_id == null);
    const nail = findSocketReport(sockets, "fingernail_thumb_left_socket") orelse return error.MissingSocketReport;
    try std.testing.expectEqualStrings("fingernail_thumb_left_attachment", nail.attachment_id.?);
    try std.testing.expectEqualStrings("fingernail_thumb_left", nail.child_component_id.?);
    try std.testing.expectEqualStrings("fingernail_thumb_left_mount_anchor", nail.child_mount_anchor_id.?);

    var mount_storage: [human_attachments.mount_anchor_count]human_attachments.MountReportEntry = undefined;
    const mounts = try human_attachments.generateMountReport(&human_base.source, &mount_storage);
    try expectStableIdOrder(human_attachments.SocketReportEntry, sockets, "socket_id");
    try expectStableIdOrder(human_attachments.MountReportEntry, mounts, "mount_anchor_id");
}

test "Prompt 2D anchor and landmark reports are deterministic mirrored and grounded" {
    var anchor_storage: [human_attachments.anchor_count]human_attachments.AnchorReportEntry = undefined;
    var anchor_storage_repeat: [human_attachments.anchor_count]human_attachments.AnchorReportEntry = undefined;
    const anchors = try human_attachments.generateAnchorReport(&human_base.source, &anchor_storage);
    const anchors_repeat = try human_attachments.generateAnchorReport(&human_base.source, &anchor_storage_repeat);
    try std.testing.expectEqual(anchors.len, anchors_repeat.len);
    try expectStableIdOrder(human_attachments.AnchorReportEntry, anchors, "anchor_id");
    for (anchors, anchors_repeat) |a, b| {
        try std.testing.expectEqualStrings(a.anchor_id, b.anchor_id);
        try std.testing.expectEqual(a.world_position_m, b.world_position_m);
    }
    const left_shoulder = findAnchorReport(anchors, "shoulder_left_anchor") orelse return error.MissingAnchorReport;
    const right_shoulder = findAnchorReport(anchors, "shoulder_right_anchor") orelse return error.MissingAnchorReport;
    try expectMirrored(left_shoulder.world_position_m, right_shoulder.world_position_m);
    inline for (.{ "heel_contact_left_anchor", "heel_contact_right_anchor", "ball_left_anchor", "ball_right_anchor", "toe_tip_left_anchor", "toe_tip_right_anchor" }) |anchor_id| {
        const entry = findAnchorReport(anchors, anchor_id) orelse return error.MissingAnchorReport;
        try std.testing.expectApproxEqAbs(@as(f32, 0), entry.world_position_m.y, human_attachments.report_tolerance_m);
    }

    var landmark_storage: [human_structural_semantics.landmark_count]human_structural_semantics.LandmarkReportEntry = undefined;
    const landmarks = try human_structural_semantics.generateLandmarkReport(&human_base.source, &landmark_storage);
    try std.testing.expectEqual(@as(usize, 35), landmarks.len);
    try expectStableIdOrder(human_structural_semantics.LandmarkReportEntry, landmarks, "landmark_id");
    const head_top = findLandmarkReport(landmarks, "head_top_landmark") orelse return error.MissingLandmarkReport;
    try std.testing.expectApproxEqAbs(@as(f32, 0), head_top.world_position_m.x, human_attachments.report_tolerance_m);
    const left_palm = findLandmarkReport(landmarks, "palm_center_left_landmark") orelse return error.MissingLandmarkReport;
    const right_palm = findLandmarkReport(landmarks, "palm_center_right_landmark") orelse return error.MissingLandmarkReport;
    try expectMirrored(left_palm.world_position_m, right_palm.world_position_m);
    std.debug.print(
        "PROMPT2D_LANDMARK head_top=({d:.5},{d:.5},{d:.5}) shoulder_left=({d:.5},{d:.5},{d:.5}) heel_left_y={d:.5}\n",
        .{ head_top.world_position_m.x, head_top.world_position_m.y, head_top.world_position_m.z, left_shoulder.world_position_m.x, left_shoulder.world_position_m.y, left_shoulder.world_position_m.z, (findAnchorReport(anchors, "heel_contact_left_anchor") orelse return error.MissingAnchorReport).world_position_m.y },
    );
}

test "Prompt 2D seams sites and effectors have stable structural reports" {
    var seam_storage: [human_structural_semantics.shared_seam_count]human_structural_semantics.SeamReportEntry = undefined;
    const seams = try human_structural_semantics.generateSeamReport(&human_base.source, &seam_storage);
    try std.testing.expectEqual(@as(usize, 11), seams.len);
    try expectStableIdOrder(human_structural_semantics.SeamReportEntry, seams, "seam_id");
    inline for (.{
        "torso_pelvis_seam",
        "torso_neck_seam",
        "neck_head_seam",
        "torso_arm_left_seam",
        "torso_arm_right_seam",
        "wrist_hand_left_seam",
        "wrist_hand_right_seam",
        "pelvis_thigh_left_seam",
        "pelvis_thigh_right_seam",
        "ankle_foot_left_seam",
        "ankle_foot_right_seam",
    }) |seam_id| try std.testing.expect(findSeamReport(seams, seam_id) != null);

    var site_storage: [human_structural_semantics.interaction_site_count]human_structural_semantics.SiteReportEntry = undefined;
    const sites = try human_structural_semantics.generateSiteReport(&human_base.source, &site_storage);
    try std.testing.expectEqual(@as(usize, 25), sites.len);
    try expectStableIdOrder(human_structural_semantics.SiteReportEntry, sites, "site_id");
    inline for (.{ "palm_left_site", "foot_ground_right_site", "perineal_center_site", "posterior_anal_site", "vulva_structural_site", "penis_structural_site" }) |site_id| {
        try std.testing.expect(findSiteReport(sites, site_id) != null);
    }

    var effector_storage: [human_structural_semantics.effector_count]human_structural_semantics.EffectorReportEntry = undefined;
    const effectors = try human_structural_semantics.generateEffectorReport(&human_base.source, &effector_storage);
    try std.testing.expectEqual(@as(usize, 6), effectors.len);
    try expectStableIdOrder(human_structural_semantics.EffectorReportEntry, effectors, "effector_id");
    inline for (.{ "hand_left_effector", "hand_right_effector", "foot_left_effector", "foot_right_effector", "mouth_effector", "head_effector" }) |effector_id| {
        try std.testing.expect(findEffectorReport(effectors, effector_id) != null);
    }
    for (human_base.source.shared_seams) |seam| try std.testing.expect(seam.coordinate_metadata_id == null);
    for (human_base.source.landmarks) |landmark| try std.testing.expect(landmark.coordinate_metadata_id == null);
}

test "Prompt 2D preserves collision hooks while deferring geometry-derived proxies" {
    try std.testing.expectEqual(human_structural_semantics.CollisionProxyDecision.defer_from_m02, human_structural_semantics.collision_proxy_decision);
    try std.testing.expectEqual(@as(usize, 0), human_structural_semantics.collision_proxy_count);
    try std.testing.expectEqualStrings(
        "owner_approved_prompt_1_defer_until_resolved_geometry_can_validate_fit",
        human_structural_semantics.collision_proxy_rationale,
    );
    const hook = try identity.CollisionGeometryId.init("future_resolved_geometry_hook");
    try std.testing.expectEqualStrings("future_resolved_geometry_hook", hook.value.bytes);
}

test "Prompt 2D validator rejects anchor mirror ownership and ground defects" {
    var anchors = human_base.anchors;
    anchors[anchorIndex("shoulder_left_anchor").?].mirror_anchor_id = null;
    try expectAnchorError(error.MissingAnchorMirrorPartner, &anchors);

    anchors = human_base.anchors;
    anchors[anchorIndex("eye_socket_left_anchor").?].owner_component_id = try identity.ComponentId.init("torso");
    try expectAnchorError(error.AnchorOwnerMismatch, &anchors);

    anchors = human_base.anchors;
    anchors[anchorIndex("eye_socket_left_anchor").?].driver = .{ .bone = try identity.BoneId.init("pelvis") };
    try expectAnchorError(error.AnchorDriverMismatch, &anchors);

    anchors = human_base.anchors;
    anchors[anchorIndex("shoulder_left_anchor").?].local_transform.translation_m.x += 0.01;
    try expectAnchorError(error.AnchorMirrorMismatch, &anchors);

    anchors = human_base.anchors;
    anchors[anchorIndex("heel_contact_left_anchor").?].local_transform.translation_m.y += 0.01;
    anchors[anchorIndex("heel_contact_right_anchor").?].local_transform.translation_m.y += 0.01;
    try expectAnchorError(error.FootContactOffGround, &anchors);

    anchors = human_base.anchors;
    anchors[anchorIndex("head_top_anchor").?].anchor_id = try identity.AnchorId.init("removed_head_top_anchor");
    try expectAnchorError(error.MissingRequiredAnchor, &anchors);
}

test "Prompt 2D validator rejects socket mount and attachment relationship defects" {
    var sockets = human_base.sockets;
    sockets[socketIndex("hair_socket").?].anchor_id = try identity.AnchorId.init("face_center_anchor");
    var source = human_base.source;
    source.sockets = &sockets;
    try std.testing.expectError(error.SocketAnchorMismatch, human_structural_validation.validatePrompt2D(&source));

    sockets = human_base.sockets;
    sockets[socketIndex("hair_socket").?].anchor_id = try identity.AnchorId.init("missing_anchor");
    source = human_base.source;
    source.sockets = &sockets;
    try std.testing.expectError(error.SocketAnchorMismatch, human_structural_validation.validatePrompt2D(&source));

    sockets = human_base.sockets;
    sockets[socketIndex("hair_socket").?].socket_id = try identity.SocketId.init("renamed_hair_socket");
    source = human_base.source;
    source.sockets = &sockets;
    try std.testing.expectError(error.MissingRequiredSocket, human_structural_validation.validatePrompt2D(&source));

    var mounts = human_base.mount_anchors;
    mounts[0].owner_component_id = try identity.ComponentId.init("head");
    source = human_base.source;
    source.mount_anchors = &mounts;
    try std.testing.expectError(error.MountRelationshipMismatch, human_structural_validation.validatePrompt2D(&source));

    mounts = human_base.mount_anchors;
    mounts[0].mount_anchor_id = try identity.MountAnchorId.init("renamed_nail_mount");
    source = human_base.source;
    source.mount_anchors = &mounts;
    try std.testing.expectError(error.MissingRequiredMount, human_structural_validation.validatePrompt2D(&source));

    var attachments = human_base.attachments;
    attachments[0].child_mount_anchor_id = human_base.mount_anchors[1].mount_anchor_id;
    source = human_base.source;
    source.attachments = &attachments;
    try std.testing.expectError(error.MountRelationshipMismatch, human_structural_validation.validatePrompt2D(&source));

    attachments = human_base.attachments;
    attachments[0].attachment_id = try identity.AttachmentId.init("renamed_nail_attachment");
    source = human_base.source;
    source.attachments = &attachments;
    try std.testing.expectError(error.MissingRequiredAttachment, human_structural_validation.validatePrompt2D(&source));
}

test "Prompt 2D validator rejects landmark and seam defects" {
    var landmarks = human_base.landmarks;
    landmarks[landmarkIndex("head_top_landmark").?].owner = .{ .anchor = try identity.AnchorId.init("face_center_anchor") };
    var source = human_base.source;
    source.landmarks = &landmarks;
    try std.testing.expectError(error.LandmarkOwnerMismatch, human_structural_validation.validatePrompt2D(&source));

    landmarks = human_base.landmarks;
    landmarks[landmarkIndex("head_top_landmark").?].owner = .{ .anchor = try identity.AnchorId.init("missing_landmark_anchor") };
    source = human_base.source;
    source.landmarks = &landmarks;
    try std.testing.expectError(error.LandmarkOwnerMismatch, human_structural_validation.validatePrompt2D(&source));

    landmarks = human_base.landmarks;
    landmarks[landmarkIndex("head_top_landmark").?].landmark_id = try identity.LandmarkId.init("renamed_head_top_landmark");
    source = human_base.source;
    source.landmarks = &landmarks;
    try std.testing.expectError(error.MissingRequiredLandmark, human_structural_validation.validatePrompt2D(&source));

    landmarks = human_base.landmarks;
    landmarks[landmarkIndex("shoulder_left_landmark").?].mirror_landmark_id = null;
    source = human_base.source;
    source.landmarks = &landmarks;
    try std.testing.expectError(error.MissingLandmarkMirrorPartner, human_structural_validation.validatePrompt2D(&source));

    var seams = human_base.shared_seams;
    var seam_members = human_structural_semantics.seam_members;
    seam_members[0][0].surface_id = try identity.SurfaceId.init("neck_surface");
    for (&seams, 0..) |*seam, index| seam.members = &seam_members[index];
    source = human_base.source;
    source.shared_seams = &seams;
    try std.testing.expectError(error.SeamContractMismatch, human_structural_validation.validatePrompt2D(&source));

    seams = human_base.shared_seams;
    seams[0].seam_id = try identity.SeamId.init("renamed_torso_pelvis_seam");
    source = human_base.source;
    source.shared_seams = &seams;
    try std.testing.expectError(error.MissingRequiredSeam, human_structural_validation.validatePrompt2D(&source));

    seams = human_base.shared_seams;
    seam_members = human_structural_semantics.seam_members;
    seam_members[0][0].component_id = try identity.ComponentId.init("missing_seam_owner");
    for (&seams, 0..) |*seam, index| seam.members = &seam_members[index];
    source = human_base.source;
    source.shared_seams = &seams;
    try std.testing.expectError(error.SeamContractMismatch, human_structural_validation.validatePrompt2D(&source));
}

test "Prompt 2D validator rejects interaction site and effector ownership defects" {
    var sites = human_base.interaction_sites;
    sites[siteIndex("palm_left_site").?].owner_component_id = try identity.ComponentId.init("missing_site_owner");
    var source = human_base.source;
    source.interaction_sites = &sites;
    try std.testing.expectError(error.InteractionSiteOwnerMismatch, human_structural_validation.validatePrompt2D(&source));

    var effectors = human_base.effectors;
    effectors[effectorIndex("foot_left_effector").?].owner_component_id = try identity.ComponentId.init("missing_effector_owner");
    source = human_base.source;
    source.effectors = &effectors;
    try std.testing.expectError(error.EffectorOwnerMismatch, human_structural_validation.validatePrompt2D(&source));
}

test "typed anchor and landmark mirrors require schema 1.1" {
    var source = human_base.source;
    source.schema_identity.version = .{ .major = 1, .minor = 0, .patch = 0 };
    var diagnostic_storage: [1024]diagnostics.Diagnostic = undefined;
    const report = try validation.validate(&source, .{}, &diagnostic_storage);
    try std.testing.expect(!report.isValid());
    var found_anchor = false;
    var found_landmark = false;
    for (report.diagnostics) |diagnostic| {
        if (diagnostic.code != .schema_feature_version_mismatch or diagnostic.property == null) continue;
        if (std.mem.eql(u8, diagnostic.object_type, "anchor") and std.mem.eql(u8, diagnostic.property.?, "mirror_anchor_id")) found_anchor = true;
        if (std.mem.eql(u8, diagnostic.object_type, "landmark") and std.mem.eql(u8, diagnostic.property.?, "mirror_landmark_id")) found_landmark = true;
    }
    try std.testing.expect(found_anchor);
    try std.testing.expect(found_landmark);
}

fn expectAnchorError(expected: human_structural_validation.Error, anchors: []const canonical.attachment.Anchor) !void {
    var source = human_base.source;
    source.anchors = anchors;
    try std.testing.expectError(expected, human_structural_validation.validatePrompt2D(&source));
}

fn expectMirrored(left: canonical.math3d.Vec3, right: canonical.math3d.Vec3) !void {
    try std.testing.expectApproxEqAbs(left.x, -right.x, human_attachments.report_tolerance_m);
    try std.testing.expectApproxEqAbs(left.y, right.y, human_attachments.report_tolerance_m);
    try std.testing.expectApproxEqAbs(left.z, right.z, human_attachments.report_tolerance_m);
}

fn expectStableIdOrder(comptime T: type, records: []const T, comptime field_name: []const u8) !void {
    for (records[1..], 1..) |record, index| {
        try std.testing.expect(std.mem.order(u8, @field(records[index - 1], field_name), @field(record, field_name)) == .lt);
    }
}

fn findSocketReport(records: []const human_attachments.SocketReportEntry, id: []const u8) ?human_attachments.SocketReportEntry {
    for (records) |record| if (std.mem.eql(u8, record.socket_id, id)) return record;
    return null;
}

fn findAnchorReport(records: []const human_attachments.AnchorReportEntry, id: []const u8) ?human_attachments.AnchorReportEntry {
    for (records) |record| if (std.mem.eql(u8, record.anchor_id, id)) return record;
    return null;
}

fn findLandmarkReport(records: []const human_structural_semantics.LandmarkReportEntry, id: []const u8) ?human_structural_semantics.LandmarkReportEntry {
    for (records) |record| if (std.mem.eql(u8, record.landmark_id, id)) return record;
    return null;
}

fn findSeamReport(records: []const human_structural_semantics.SeamReportEntry, id: []const u8) ?human_structural_semantics.SeamReportEntry {
    for (records) |record| if (std.mem.eql(u8, record.seam_id, id)) return record;
    return null;
}

fn findSiteReport(records: []const human_structural_semantics.SiteReportEntry, id: []const u8) ?human_structural_semantics.SiteReportEntry {
    for (records) |record| if (std.mem.eql(u8, record.site_id, id)) return record;
    return null;
}

fn findEffectorReport(records: []const human_structural_semantics.EffectorReportEntry, id: []const u8) ?human_structural_semantics.EffectorReportEntry {
    for (records) |record| if (std.mem.eql(u8, record.effector_id, id)) return record;
    return null;
}

fn anchorIndex(id: []const u8) ?usize {
    for (human_base.source.anchors, 0..) |record, index| if (std.mem.eql(u8, record.anchor_id.value.bytes, id)) return index;
    return null;
}

fn socketIndex(id: []const u8) ?usize {
    for (human_base.source.sockets, 0..) |record, index| if (std.mem.eql(u8, record.socket_id.value.bytes, id)) return index;
    return null;
}

fn landmarkIndex(id: []const u8) ?usize {
    for (human_base.source.landmarks, 0..) |record, index| if (std.mem.eql(u8, record.landmark_id.value.bytes, id)) return index;
    return null;
}

fn siteIndex(id: []const u8) ?usize {
    for (human_base.source.interaction_sites, 0..) |record, index| if (std.mem.eql(u8, record.site_id.value.bytes, id)) return index;
    return null;
}

fn effectorIndex(id: []const u8) ?usize {
    for (human_base.source.effectors, 0..) |record, index| if (std.mem.eql(u8, record.effector_id.value.bytes, id)) return index;
    return null;
}
