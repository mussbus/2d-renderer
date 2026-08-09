const std = @import("std");
const canonical = @import("canonical_model");
const human_test_support = @import("canonical_human_test_support.zig");

const diagnostics = canonical.diagnostics;
const human_attachments = canonical.human_attachments;
const human_structural_semantics = canonical.human_structural_semantics;
const human_structural_validation = canonical.human_structural_validation;
const identity = canonical.identity;
const normalization = canonical.normalization;
const parsing = canonical.parsing;
const serialization = canonical.serialization;
const validation = canonical.validation;

test "Prompt 2D structural semantics validate and round-trip canonically" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    try human_structural_validation.validatePrompt2D(source);
    const canonical_bytes = try serialization.serializeAlloc(std.testing.allocator, loaded.normalized());
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
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    try std.testing.expectEqual(@as(usize, 106), source.anchors.len);
    try std.testing.expectEqual(@as(usize, 22), source.sockets.len);
    try std.testing.expectEqual(@as(usize, 20), source.mount_anchors.len);
    try std.testing.expectEqual(@as(usize, 20), source.attachments.len);
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
    }) |anchor_id| try std.testing.expect(anchorIndex(source, anchor_id) != null);

    const socket_storage = try std.testing.allocator.alloc(human_attachments.SocketReportEntry, source.sockets.len);
    defer std.testing.allocator.free(socket_storage);
    const sockets = try human_attachments.generateSocketReport(source, socket_storage);
    const hair = findSocketReport(sockets, "hair_socket") orelse return error.MissingSocketReport;
    const headwear = findSocketReport(sockets, "headwear_socket") orelse return error.MissingSocketReport;
    try std.testing.expect(hair.attachment_id == null);
    try std.testing.expect(headwear.attachment_id == null);
    const nail = findSocketReport(sockets, "fingernail_thumb_left_socket") orelse return error.MissingSocketReport;
    try std.testing.expectEqualStrings("fingernail_thumb_left_attachment", nail.attachment_id.?);
    try std.testing.expectEqualStrings("fingernail_thumb_left", nail.child_component_id.?);
    try std.testing.expectEqualStrings("fingernail_thumb_left_mount_anchor", nail.child_mount_anchor_id.?);

    const mount_storage = try std.testing.allocator.alloc(human_attachments.MountReportEntry, source.mount_anchors.len);
    defer std.testing.allocator.free(mount_storage);
    const mounts = try human_attachments.generateMountReport(source, mount_storage);
    try expectStableIdOrder(human_attachments.SocketReportEntry, sockets, "socket_id");
    try expectStableIdOrder(human_attachments.MountReportEntry, mounts, "mount_anchor_id");
}

test "Prompt 2D anchor and landmark reports are deterministic mirrored and grounded" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    const anchor_storage = try std.testing.allocator.alloc(human_attachments.AnchorReportEntry, source.anchors.len);
    defer std.testing.allocator.free(anchor_storage);
    const anchor_storage_repeat = try std.testing.allocator.alloc(human_attachments.AnchorReportEntry, source.anchors.len);
    defer std.testing.allocator.free(anchor_storage_repeat);
    const anchors = try human_attachments.generateAnchorReport(source, anchor_storage);
    const anchors_repeat = try human_attachments.generateAnchorReport(source, anchor_storage_repeat);
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

    const landmark_storage = try std.testing.allocator.alloc(human_structural_semantics.LandmarkReportEntry, source.landmarks.len);
    defer std.testing.allocator.free(landmark_storage);
    const landmarks = try human_structural_semantics.generateLandmarkReport(source, landmark_storage);
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
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const source = loaded.definition();
    const seam_storage = try std.testing.allocator.alloc(human_structural_semantics.SeamReportEntry, source.shared_seams.len);
    defer std.testing.allocator.free(seam_storage);
    const seams = try human_structural_semantics.generateSeamReport(source, seam_storage);
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

    const site_storage = try std.testing.allocator.alloc(human_structural_semantics.SiteReportEntry, source.interaction_sites.len);
    defer std.testing.allocator.free(site_storage);
    const sites = try human_structural_semantics.generateSiteReport(source, site_storage);
    try std.testing.expectEqual(@as(usize, 25), sites.len);
    try expectStableIdOrder(human_structural_semantics.SiteReportEntry, sites, "site_id");
    inline for (.{ "palm_left_site", "foot_ground_right_site", "perineal_center_site", "posterior_anal_site", "vulva_structural_site", "penis_structural_site" }) |site_id| {
        try std.testing.expect(findSiteReport(sites, site_id) != null);
    }

    const effector_storage = try std.testing.allocator.alloc(human_structural_semantics.EffectorReportEntry, source.effectors.len);
    defer std.testing.allocator.free(effector_storage);
    const effectors = try human_structural_semantics.generateEffectorReport(source, effector_storage);
    try std.testing.expectEqual(@as(usize, 6), effectors.len);
    try expectStableIdOrder(human_structural_semantics.EffectorReportEntry, effectors, "effector_id");
    inline for (.{ "hand_left_effector", "hand_right_effector", "foot_left_effector", "foot_right_effector", "mouth_effector", "head_effector" }) |effector_id| {
        try std.testing.expect(findEffectorReport(effectors, effector_id) != null);
    }
    for (source.shared_seams) |seam| try std.testing.expect(seam.coordinate_metadata_id == null);
    for (source.landmarks) |landmark| try std.testing.expect(landmark.coordinate_metadata_id == null);
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
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const base = loaded.definition();
    const anchors = try human_test_support.dupe(canonical.attachment.Anchor, base.anchors);
    defer std.testing.allocator.free(anchors);
    anchors[anchorIndex(base, "shoulder_left_anchor").?].mirror_anchor_id = null;
    try expectAnchorError(base, error.MissingAnchorMirrorPartner, anchors);

    @memcpy(anchors, base.anchors);
    anchors[anchorIndex(base, "eye_socket_left_anchor").?].owner_component_id = try identity.ComponentId.init("torso");
    try expectAnchorError(base, error.AnchorOwnerMismatch, anchors);

    @memcpy(anchors, base.anchors);
    anchors[anchorIndex(base, "eye_socket_left_anchor").?].driver = .{ .bone = try identity.BoneId.init("pelvis") };
    try expectAnchorError(base, error.AnchorDriverMismatch, anchors);

    @memcpy(anchors, base.anchors);
    anchors[anchorIndex(base, "shoulder_left_anchor").?].local_transform.translation_m.x += 0.01;
    try expectAnchorError(base, error.AnchorMirrorMismatch, anchors);

    @memcpy(anchors, base.anchors);
    anchors[anchorIndex(base, "heel_contact_left_anchor").?].local_transform.translation_m.y += 0.01;
    anchors[anchorIndex(base, "heel_contact_right_anchor").?].local_transform.translation_m.y += 0.01;
    try expectAnchorError(base, error.FootContactOffGround, anchors);

    @memcpy(anchors, base.anchors);
    anchors[anchorIndex(base, "head_top_anchor").?].anchor_id = try identity.AnchorId.init("removed_head_top_anchor");
    try expectAnchorError(base, error.MissingRequiredAnchor, anchors);
}

test "Prompt 2D validator rejects socket mount and attachment relationship defects" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const base = loaded.definition();
    const sockets = try human_test_support.dupe(canonical.attachment.Socket, base.sockets);
    defer std.testing.allocator.free(sockets);
    sockets[socketIndex(base, "hair_socket").?].anchor_id = try identity.AnchorId.init("face_center_anchor");
    var source = base.*;
    source.sockets = sockets;
    try std.testing.expectError(error.SocketAnchorMismatch, human_structural_validation.validatePrompt2D(&source));

    @memcpy(sockets, base.sockets);
    sockets[socketIndex(base, "hair_socket").?].anchor_id = try identity.AnchorId.init("missing_anchor");
    source = base.*;
    source.sockets = sockets;
    try std.testing.expectError(error.SocketAnchorMismatch, human_structural_validation.validatePrompt2D(&source));

    @memcpy(sockets, base.sockets);
    sockets[socketIndex(base, "hair_socket").?].socket_id = try identity.SocketId.init("renamed_hair_socket");
    source = base.*;
    source.sockets = sockets;
    try std.testing.expectError(error.MissingRequiredSocket, human_structural_validation.validatePrompt2D(&source));

    const mounts = try human_test_support.dupe(canonical.attachment.MountAnchor, base.mount_anchors);
    defer std.testing.allocator.free(mounts);
    mounts[0].owner_component_id = try identity.ComponentId.init("head");
    source = base.*;
    source.mount_anchors = mounts;
    try std.testing.expectError(error.MountRelationshipMismatch, human_structural_validation.validatePrompt2D(&source));

    @memcpy(mounts, base.mount_anchors);
    mounts[0].mount_anchor_id = try identity.MountAnchorId.init("renamed_nail_mount");
    source = base.*;
    source.mount_anchors = mounts;
    try std.testing.expectError(error.MissingRequiredMount, human_structural_validation.validatePrompt2D(&source));

    const attachments = try human_test_support.dupe(canonical.attachment.Attachment, base.attachments);
    defer std.testing.allocator.free(attachments);
    attachments[0].child_mount_anchor_id = base.mount_anchors[1].mount_anchor_id;
    source = base.*;
    source.attachments = attachments;
    try std.testing.expectError(error.MountRelationshipMismatch, human_structural_validation.validatePrompt2D(&source));

    @memcpy(attachments, base.attachments);
    attachments[0].attachment_id = try identity.AttachmentId.init("renamed_nail_attachment");
    source = base.*;
    source.attachments = attachments;
    try std.testing.expectError(error.MissingRequiredAttachment, human_structural_validation.validatePrompt2D(&source));
}

test "Prompt 2D validator rejects landmark and seam defects" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const base = loaded.definition();
    const landmarks = try human_test_support.dupe(canonical.semantics.Landmark, base.landmarks);
    defer std.testing.allocator.free(landmarks);
    landmarks[landmarkIndex(base, "head_top_landmark").?].owner = .{ .anchor = try identity.AnchorId.init("face_center_anchor") };
    var source = base.*;
    source.landmarks = landmarks;
    try std.testing.expectError(error.LandmarkOwnerMismatch, human_structural_validation.validatePrompt2D(&source));

    @memcpy(landmarks, base.landmarks);
    landmarks[landmarkIndex(base, "head_top_landmark").?].owner = .{ .anchor = try identity.AnchorId.init("missing_landmark_anchor") };
    source = base.*;
    source.landmarks = landmarks;
    try std.testing.expectError(error.LandmarkOwnerMismatch, human_structural_validation.validatePrompt2D(&source));

    @memcpy(landmarks, base.landmarks);
    landmarks[landmarkIndex(base, "head_top_landmark").?].landmark_id = try identity.LandmarkId.init("renamed_head_top_landmark");
    source = base.*;
    source.landmarks = landmarks;
    try std.testing.expectError(error.MissingRequiredLandmark, human_structural_validation.validatePrompt2D(&source));

    @memcpy(landmarks, base.landmarks);
    landmarks[landmarkIndex(base, "shoulder_left_landmark").?].mirror_landmark_id = null;
    source = base.*;
    source.landmarks = landmarks;
    try std.testing.expectError(error.MissingLandmarkMirrorPartner, human_structural_validation.validatePrompt2D(&source));

    const seams = try human_test_support.dupe(canonical.semantics.SharedSeam, base.shared_seams);
    defer std.testing.allocator.free(seams);
    const seam_members = try human_test_support.dupe(canonical.semantics.SharedSeamMember, base.shared_seams[0].members);
    defer std.testing.allocator.free(seam_members);
    seam_members[0].surface_id = try identity.SurfaceId.init("neck_surface");
    seams[0].members = seam_members;
    source = base.*;
    source.shared_seams = seams;
    try std.testing.expectError(error.SeamContractMismatch, human_structural_validation.validatePrompt2D(&source));

    @memcpy(seams, base.shared_seams);
    seams[0].seam_id = try identity.SeamId.init("renamed_torso_pelvis_seam");
    source = base.*;
    source.shared_seams = seams;
    try std.testing.expectError(error.MissingRequiredSeam, human_structural_validation.validatePrompt2D(&source));

    @memcpy(seams, base.shared_seams);
    @memcpy(seam_members, base.shared_seams[0].members);
    seam_members[0].component_id = try identity.ComponentId.init("missing_seam_owner");
    seams[0].members = seam_members;
    source = base.*;
    source.shared_seams = seams;
    try std.testing.expectError(error.SeamContractMismatch, human_structural_validation.validatePrompt2D(&source));
}

test "Prompt 2D validator rejects interaction site and effector ownership defects" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    const base = loaded.definition();
    const sites = try human_test_support.dupe(canonical.semantics.InteractionSite, base.interaction_sites);
    defer std.testing.allocator.free(sites);
    sites[siteIndex(base, "palm_left_site").?].owner_component_id = try identity.ComponentId.init("missing_site_owner");
    var source = base.*;
    source.interaction_sites = sites;
    try std.testing.expectError(error.InteractionSiteOwnerMismatch, human_structural_validation.validatePrompt2D(&source));

    const effectors = try human_test_support.dupe(canonical.semantics.Effector, base.effectors);
    defer std.testing.allocator.free(effectors);
    effectors[effectorIndex(base, "foot_left_effector").?].owner_component_id = try identity.ComponentId.init("missing_effector_owner");
    source = base.*;
    source.effectors = effectors;
    try std.testing.expectError(error.EffectorOwnerMismatch, human_structural_validation.validatePrompt2D(&source));
}

test "typed anchor and landmark mirrors require schema 1.1" {
    var loaded = try human_test_support.load();
    defer loaded.deinit();
    var source = loaded.definition().*;
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

fn expectAnchorError(base: *const canonical.definition.CanonicalCreatureDefinition, expected: human_structural_validation.Error, anchors: []const canonical.attachment.Anchor) !void {
    var source = base.*;
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

fn anchorIndex(source: *const canonical.definition.CanonicalCreatureDefinition, id: []const u8) ?usize {
    for (source.anchors, 0..) |record, index| if (std.mem.eql(u8, record.anchor_id.value.bytes, id)) return index;
    return null;
}

fn socketIndex(source: *const canonical.definition.CanonicalCreatureDefinition, id: []const u8) ?usize {
    for (source.sockets, 0..) |record, index| if (std.mem.eql(u8, record.socket_id.value.bytes, id)) return index;
    return null;
}

fn landmarkIndex(source: *const canonical.definition.CanonicalCreatureDefinition, id: []const u8) ?usize {
    for (source.landmarks, 0..) |record, index| if (std.mem.eql(u8, record.landmark_id.value.bytes, id)) return index;
    return null;
}

fn siteIndex(source: *const canonical.definition.CanonicalCreatureDefinition, id: []const u8) ?usize {
    for (source.interaction_sites, 0..) |record, index| if (std.mem.eql(u8, record.site_id.value.bytes, id)) return index;
    return null;
}

fn effectorIndex(source: *const canonical.definition.CanonicalCreatureDefinition, id: []const u8) ?usize {
    for (source.effectors, 0..) |record, index| if (std.mem.eql(u8, record.effector_id.value.bytes, id)) return index;
    return null;
}
