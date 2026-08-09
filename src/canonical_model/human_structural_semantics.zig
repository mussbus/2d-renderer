const std = @import("std");
const definition = @import("definition.zig");
const human_attachments = @import("human_attachments.zig");
const identity = @import("identity.zig");
const math3d = @import("math3d.zig");
const semantics = @import("semantics.zig");

pub const landmark_count: usize = 35;
pub const shared_seam_count: usize = 11;
pub const interaction_site_count: usize = 25;
pub const effector_count: usize = 6;

pub const CollisionProxyDecision = enum { defer_from_m02 };
pub const collision_proxy_decision: CollisionProxyDecision = .defer_from_m02;
pub const collision_proxy_count: usize = 0;
pub const collision_proxy_rationale = "owner_approved_prompt_1_defer_until_resolved_geometry_can_validate_fit";

pub const Side = enum { center, left, right };

pub const LandmarkSpec = struct {
    landmark_id: []const u8,
    anchor_id: []const u8,
    mirror_landmark_id: ?[]const u8,
    side: Side,
};

pub const SeamSpec = struct {
    seam_id: []const u8,
    component_a_id: []const u8,
    surface_a_id: []const u8,
    component_b_id: []const u8,
    surface_b_id: []const u8,
};

pub const SiteSpec = struct {
    site_id: []const u8,
    owner_component_id: []const u8,
    region_id: []const u8,
    preferred_anchor_id: []const u8,
    side: Side,
};

pub const EffectorSpec = struct {
    effector_id: []const u8,
    owner_component_id: []const u8,
    region_id: []const u8,
    preferred_anchor_id: []const u8,
    side: Side,
};

pub const LandmarkReportEntry = struct {
    landmark_id: []const u8,
    anchor_id: []const u8,
    mirror_landmark_id: ?[]const u8,
    world_position_m: math3d.Vec3,
};

pub const SeamReportEntry = struct {
    seam_id: []const u8,
    component_a_id: []const u8,
    surface_a_id: []const u8,
    component_b_id: []const u8,
    surface_b_id: []const u8,
};

pub const SiteReportEntry = struct {
    site_id: []const u8,
    owner_component_id: []const u8,
    region_id: []const u8,
    preferred_anchor_id: []const u8,
    capacity: u32,
};

pub const EffectorReportEntry = struct {
    effector_id: []const u8,
    owner_component_id: []const u8,
    region_id: []const u8,
    preferred_anchor_id: []const u8,
    capacity: u32,
};

pub const ReportError = human_attachments.ReportError || error{
    OutputTooSmall,
    MissingLandmarkAnchor,
    InvalidSemanticReport,
};

const landmark_tags = makeIds(identity.SemanticTagId, &.{ "human", "structural_landmark" });
const landmark_left_tags = makeIds(identity.SemanticTagId, &.{ "human", "left", "structural_landmark" });
const landmark_right_tags = makeIds(identity.SemanticTagId, &.{ "human", "right", "structural_landmark" });
const site_tags = makeIds(identity.SemanticTagId, &.{ "human", "interaction_site" });
const site_left_tags = makeIds(identity.SemanticTagId, &.{ "human", "left", "interaction_site" });
const site_right_tags = makeIds(identity.SemanticTagId, &.{ "human", "right", "interaction_site" });
const effector_tags = makeIds(identity.SemanticTagId, &.{ "human", "structural_effector" });
const effector_left_tags = makeIds(identity.SemanticTagId, &.{ "human", "left", "structural_effector" });
const effector_right_tags = makeIds(identity.SemanticTagId, &.{ "human", "right", "structural_effector" });

pub const landmark_specs = buildLandmarkSpecs();
pub const landmarks = buildLandmarks();
pub const seam_specs = [_]SeamSpec{
    .{ .seam_id = "torso_pelvis_seam", .component_a_id = "torso", .surface_a_id = "torso_surface", .component_b_id = "pelvis", .surface_b_id = "pelvis_surface" },
    .{ .seam_id = "torso_neck_seam", .component_a_id = "torso", .surface_a_id = "torso_surface", .component_b_id = "neck", .surface_b_id = "neck_surface" },
    .{ .seam_id = "neck_head_seam", .component_a_id = "neck", .surface_a_id = "neck_surface", .component_b_id = "head", .surface_b_id = "head_surface" },
    .{ .seam_id = "torso_arm_left_seam", .component_a_id = "torso", .surface_a_id = "shoulder_left_surface", .component_b_id = "arm_left_01", .surface_b_id = "upper_arm_left_surface" },
    .{ .seam_id = "torso_arm_right_seam", .component_a_id = "torso", .surface_a_id = "shoulder_right_surface", .component_b_id = "arm_right_01", .surface_b_id = "upper_arm_right_surface" },
    .{ .seam_id = "wrist_hand_left_seam", .component_a_id = "arm_left_01", .surface_a_id = "wrist_left_surface", .component_b_id = "hand_left_01", .surface_b_id = "palm_left_surface" },
    .{ .seam_id = "wrist_hand_right_seam", .component_a_id = "arm_right_01", .surface_a_id = "wrist_right_surface", .component_b_id = "hand_right_01", .surface_b_id = "palm_right_surface" },
    .{ .seam_id = "pelvis_thigh_left_seam", .component_a_id = "pelvis", .surface_a_id = "hip_left_surface", .component_b_id = "leg_left_01", .surface_b_id = "thigh_left_surface" },
    .{ .seam_id = "pelvis_thigh_right_seam", .component_a_id = "pelvis", .surface_a_id = "hip_right_surface", .component_b_id = "leg_right_01", .surface_b_id = "thigh_right_surface" },
    .{ .seam_id = "ankle_foot_left_seam", .component_a_id = "leg_left_01", .surface_a_id = "ankle_left_surface", .component_b_id = "foot_left_01", .surface_b_id = "midfoot_left_surface" },
    .{ .seam_id = "ankle_foot_right_seam", .component_a_id = "leg_right_01", .surface_a_id = "ankle_right_surface", .component_b_id = "foot_right_01", .surface_b_id = "midfoot_right_surface" },
};
pub const seam_members = buildSeamMembers();
pub const shared_seams = buildSharedSeams();
pub const site_specs = [_]SiteSpec{
    .{ .site_id = "shoulder_left_site", .owner_component_id = "torso", .region_id = "shoulder_left", .preferred_anchor_id = "shoulder_left_anchor", .side = .left },
    .{ .site_id = "shoulder_right_site", .owner_component_id = "torso", .region_id = "shoulder_right", .preferred_anchor_id = "shoulder_right_anchor", .side = .right },
    .{ .site_id = "hip_left_site", .owner_component_id = "pelvis", .region_id = "hip_left", .preferred_anchor_id = "hip_left_anchor", .side = .left },
    .{ .site_id = "hip_right_site", .owner_component_id = "pelvis", .region_id = "hip_right", .preferred_anchor_id = "hip_right_anchor", .side = .right },
    .{ .site_id = "waist_site", .owner_component_id = "torso", .region_id = "waist", .preferred_anchor_id = "waist_center_anchor", .side = .center },
    .{ .site_id = "upper_back_site", .owner_component_id = "torso", .region_id = "back", .preferred_anchor_id = "upper_back_anchor", .side = .center },
    .{ .site_id = "chest_support_site", .owner_component_id = "torso", .region_id = "chest", .preferred_anchor_id = "sternum_center_anchor", .side = .center },
    .{ .site_id = "palm_left_site", .owner_component_id = "hand_left_01", .region_id = "palm_left", .preferred_anchor_id = "palm_center_left_anchor", .side = .left },
    .{ .site_id = "palm_right_site", .owner_component_id = "hand_right_01", .region_id = "palm_right", .preferred_anchor_id = "palm_center_right_anchor", .side = .right },
    .{ .site_id = "glute_left_site", .owner_component_id = "pelvis", .region_id = "glute_left", .preferred_anchor_id = "glute_left_anchor", .side = .left },
    .{ .site_id = "glute_right_site", .owner_component_id = "pelvis", .region_id = "glute_right", .preferred_anchor_id = "glute_right_anchor", .side = .right },
    .{ .site_id = "head_site", .owner_component_id = "head", .region_id = "head", .preferred_anchor_id = "facial_perception_fallback_anchor", .side = .center },
    .{ .site_id = "face_site", .owner_component_id = "head", .region_id = "face", .preferred_anchor_id = "face_center_anchor", .side = .center },
    .{ .site_id = "foot_ground_left_site", .owner_component_id = "foot_left_01", .region_id = "sole_left", .preferred_anchor_id = "ball_left_anchor", .side = .left },
    .{ .site_id = "foot_ground_right_site", .owner_component_id = "foot_right_01", .region_id = "sole_right", .preferred_anchor_id = "ball_right_anchor", .side = .right },
    .{ .site_id = "perineal_center_site", .owner_component_id = "pelvis", .region_id = "perineal", .preferred_anchor_id = "perineal_center_anchor", .side = .center },
    .{ .site_id = "anterior_genital_site", .owner_component_id = "pelvis", .region_id = "pubic", .preferred_anchor_id = "anterior_genital_anchor", .side = .center },
    .{ .site_id = "posterior_anal_site", .owner_component_id = "anus_module_01", .region_id = "anus_external", .preferred_anchor_id = "posterior_anal_anchor", .side = .center },
    .{ .site_id = "groin_left_site", .owner_component_id = "pelvis", .region_id = "groin_left", .preferred_anchor_id = "groin_left_anchor", .side = .left },
    .{ .site_id = "groin_right_site", .owner_component_id = "pelvis", .region_id = "groin_right", .preferred_anchor_id = "groin_right_anchor", .side = .right },
    .{ .site_id = "pubic_center_site", .owner_component_id = "pelvis", .region_id = "pubic", .preferred_anchor_id = "pubic_center_anchor", .side = .center },
    .{ .site_id = "mouth_site", .owner_component_id = "mouth", .region_id = "mouth_external", .preferred_anchor_id = "mouth_interaction_anchor", .side = .center },
    .{ .site_id = "vulva_structural_site", .owner_component_id = "vulva_vaginal_canal_module_01", .region_id = "vestibule", .preferred_anchor_id = "anterior_genital_anchor", .side = .center },
    .{ .site_id = "penis_structural_site", .owner_component_id = "penis_module_01", .region_id = "penis_base", .preferred_anchor_id = "anterior_genital_anchor", .side = .center },
    .{ .site_id = "scrotum_structural_site", .owner_component_id = "scrotum_testicles_module_01", .region_id = "scrotum", .preferred_anchor_id = "perineal_center_anchor", .side = .center },
};
pub const interaction_sites = buildInteractionSites();
pub const effector_specs = [_]EffectorSpec{
    .{ .effector_id = "hand_left_effector", .owner_component_id = "hand_left_01", .region_id = "palm_left", .preferred_anchor_id = "grip_left_anchor", .side = .left },
    .{ .effector_id = "hand_right_effector", .owner_component_id = "hand_right_01", .region_id = "palm_right", .preferred_anchor_id = "grip_right_anchor", .side = .right },
    .{ .effector_id = "foot_left_effector", .owner_component_id = "foot_left_01", .region_id = "sole_left", .preferred_anchor_id = "ball_left_anchor", .side = .left },
    .{ .effector_id = "foot_right_effector", .owner_component_id = "foot_right_01", .region_id = "sole_right", .preferred_anchor_id = "ball_right_anchor", .side = .right },
    .{ .effector_id = "mouth_effector", .owner_component_id = "mouth", .region_id = "mouth_external", .preferred_anchor_id = "mouth_interaction_anchor", .side = .center },
    .{ .effector_id = "head_effector", .owner_component_id = "head", .region_id = "face", .preferred_anchor_id = "facial_perception_fallback_anchor", .side = .center },
};
pub const effectors = buildEffectors();

pub fn generateLandmarkReport(
    source: *const definition.CanonicalCreatureDefinition,
    output: []LandmarkReportEntry,
) ReportError![]const LandmarkReportEntry {
    if (output.len < source.landmarks.len) return error.OutputTooSmall;
    var previous_id: ?[]const u8 = null;
    var emitted: usize = 0;
    while (emitted < source.landmarks.len) : (emitted += 1) {
        const selected = selectNext(source.landmarks, "landmark_id", previous_id) orelse return error.InvalidSemanticReport;
        const record = source.landmarks[selected];
        const anchor_id = switch (record.owner) {
            .anchor => |id| id.value.bytes,
            else => return error.MissingLandmarkAnchor,
        };
        output[emitted] = .{
            .landmark_id = record.landmark_id.value.bytes,
            .anchor_id = anchor_id,
            .mirror_landmark_id = if (record.mirror_landmark_id) |id| id.value.bytes else null,
            .world_position_m = try human_attachments.anchorWorldPosition(source, anchor_id),
        };
        previous_id = record.landmark_id.value.bytes;
    }
    return output[0..source.landmarks.len];
}

pub fn generateSeamReport(source: *const definition.CanonicalCreatureDefinition, output: []SeamReportEntry) ReportError![]const SeamReportEntry {
    if (output.len < source.shared_seams.len) return error.OutputTooSmall;
    var previous_id: ?[]const u8 = null;
    var emitted: usize = 0;
    while (emitted < source.shared_seams.len) : (emitted += 1) {
        const selected = selectNext(source.shared_seams, "seam_id", previous_id) orelse return error.InvalidSemanticReport;
        const seam = source.shared_seams[selected];
        if (seam.members.len != 2) return error.InvalidSemanticReport;
        output[emitted] = .{
            .seam_id = seam.seam_id.value.bytes,
            .component_a_id = seam.members[0].component_id.value.bytes,
            .surface_a_id = seam.members[0].surface_id.value.bytes,
            .component_b_id = seam.members[1].component_id.value.bytes,
            .surface_b_id = seam.members[1].surface_id.value.bytes,
        };
        previous_id = seam.seam_id.value.bytes;
    }
    return output[0..source.shared_seams.len];
}

pub fn generateSiteReport(source: *const definition.CanonicalCreatureDefinition, output: []SiteReportEntry) ReportError![]const SiteReportEntry {
    if (output.len < source.interaction_sites.len) return error.OutputTooSmall;
    var previous_id: ?[]const u8 = null;
    var emitted: usize = 0;
    while (emitted < source.interaction_sites.len) : (emitted += 1) {
        const selected = selectNext(source.interaction_sites, "site_id", previous_id) orelse return error.InvalidSemanticReport;
        const site = source.interaction_sites[selected];
        output[emitted] = .{
            .site_id = site.site_id.value.bytes,
            .owner_component_id = site.owner_component_id.value.bytes,
            .region_id = (site.region_id orelse return error.InvalidSemanticReport).value.bytes,
            .preferred_anchor_id = (site.preferred_anchor_id orelse return error.InvalidSemanticReport).value.bytes,
            .capacity = site.capacity,
        };
        previous_id = site.site_id.value.bytes;
    }
    return output[0..source.interaction_sites.len];
}

pub fn generateEffectorReport(source: *const definition.CanonicalCreatureDefinition, output: []EffectorReportEntry) ReportError![]const EffectorReportEntry {
    if (output.len < source.effectors.len) return error.OutputTooSmall;
    var previous_id: ?[]const u8 = null;
    var emitted: usize = 0;
    while (emitted < source.effectors.len) : (emitted += 1) {
        const selected = selectNext(source.effectors, "effector_id", previous_id) orelse return error.InvalidSemanticReport;
        const effector = source.effectors[selected];
        output[emitted] = .{
            .effector_id = effector.effector_id.value.bytes,
            .owner_component_id = effector.owner_component_id.value.bytes,
            .region_id = (effector.region_id orelse return error.InvalidSemanticReport).value.bytes,
            .preferred_anchor_id = (effector.preferred_anchor_id orelse return error.InvalidSemanticReport).value.bytes,
            .capacity = effector.capacity,
        };
        previous_id = effector.effector_id.value.bytes;
    }
    return output[0..source.effectors.len];
}

fn buildLandmarkSpecs() [landmark_count]LandmarkSpec {
    @setEvalBranchQuota(500_000);
    var result: [landmark_count]LandmarkSpec = undefined;
    var index: usize = 0;
    inline for (.{
        .{ "head_top_landmark", "head_top_anchor" },
        .{ "chin_landmark", "chin_anchor" },
        .{ "face_center_landmark", "face_center_anchor" },
        .{ "sternum_center_landmark", "sternum_center_anchor" },
        .{ "navel_landmark", "navel_anchor" },
        .{ "waist_center_landmark", "waist_center_anchor" },
        .{ "pelvis_center_landmark", "pelvis_center_anchor" },
    }) |entry| {
        result[index] = .{ .landmark_id = entry[0], .anchor_id = entry[1], .mirror_landmark_id = null, .side = .center };
        index += 1;
    }
    inline for (.{ "left", "right" }) |side| {
        const mirror_side = if (std.mem.eql(u8, side, "left")) "right" else "left";
        const side_tag: Side = if (std.mem.eql(u8, side, "left")) .left else .right;
        inline for (.{ "shoulder", "hip", "elbow", "wrist", "palm_center", "knee", "ankle", "heel_contact", "toe_tip" }) |prefix| {
            const landmark_prefix = if (std.mem.eql(u8, prefix, "heel_contact")) "heel" else prefix;
            result[index] = .{
                .landmark_id = std.fmt.comptimePrint("{s}_{s}_landmark", .{ landmark_prefix, side }),
                .anchor_id = std.fmt.comptimePrint("{s}_{s}_anchor", .{ prefix, side }),
                .mirror_landmark_id = std.fmt.comptimePrint("{s}_{s}_landmark", .{ landmark_prefix, mirror_side }),
                .side = side_tag,
            };
            index += 1;
        }
        inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| {
            result[index] = .{
                .landmark_id = std.fmt.comptimePrint("fingertip_{s}_{s}_landmark", .{ digit, side }),
                .anchor_id = std.fmt.comptimePrint("fingertip_{s}_{s}_anchor", .{ digit, side }),
                .mirror_landmark_id = std.fmt.comptimePrint("fingertip_{s}_{s}_landmark", .{ digit, mirror_side }),
                .side = side_tag,
            };
            index += 1;
        }
    }
    if (index != landmark_count) @compileError("human landmark count mismatch");
    return result;
}

fn buildLandmarks() [landmark_count]semantics.Landmark {
    @setEvalBranchQuota(500_000);
    var result: [landmark_count]semantics.Landmark = undefined;
    inline for (landmark_specs, 0..) |spec, index| {
        result[index] = .{
            .landmark_id = makeId(identity.LandmarkId, spec.landmark_id),
            .display_name = null,
            .owner = .{ .anchor = makeId(identity.AnchorId, spec.anchor_id) },
            .mirror_landmark_id = if (spec.mirror_landmark_id) |id| makeId(identity.LandmarkId, id) else null,
            .coordinate_metadata_id = null,
            .semantic_tags = landmarkTags(spec.side),
        };
    }
    return result;
}

fn buildSeamMembers() [shared_seam_count][2]semantics.SharedSeamMember {
    @setEvalBranchQuota(100_000);
    var result: [shared_seam_count][2]semantics.SharedSeamMember = undefined;
    inline for (seam_specs, 0..) |spec, index| {
        result[index] = .{
            .{ .component_id = makeId(identity.ComponentId, spec.component_a_id), .surface_id = makeId(identity.SurfaceId, spec.surface_a_id) },
            .{ .component_id = makeId(identity.ComponentId, spec.component_b_id), .surface_id = makeId(identity.SurfaceId, spec.surface_b_id) },
        };
    }
    return result;
}

fn buildSharedSeams() [shared_seam_count]semantics.SharedSeam {
    @setEvalBranchQuota(100_000);
    var result: [shared_seam_count]semantics.SharedSeam = undefined;
    inline for (seam_specs, 0..) |spec, index| {
        result[index] = .{
            .seam_id = makeId(identity.SeamId, spec.seam_id),
            .display_name = null,
            .members = &seam_members[index],
            .coordinate_metadata_id = null,
        };
    }
    return result;
}

fn buildInteractionSites() [interaction_site_count]semantics.InteractionSite {
    @setEvalBranchQuota(500_000);
    var result: [interaction_site_count]semantics.InteractionSite = undefined;
    inline for (site_specs, 0..) |spec, index| {
        result[index] = .{
            .site_id = makeId(identity.InteractionSiteId, spec.site_id),
            .display_name = null,
            .owner_component_id = makeId(identity.ComponentId, spec.owner_component_id),
            .region_id = makeId(identity.RegionId, spec.region_id),
            .preferred_anchor_id = makeId(identity.AnchorId, spec.preferred_anchor_id),
            .semantic_tags = siteTags(spec.side),
            .approach_metadata_id = null,
            .orientation_metadata_id = null,
            .capacity = 1,
            .occupancy_policy_id = null,
        };
    }
    return result;
}

fn buildEffectors() [effector_count]semantics.Effector {
    @setEvalBranchQuota(100_000);
    var result: [effector_count]semantics.Effector = undefined;
    inline for (effector_specs, 0..) |spec, index| {
        result[index] = .{
            .effector_id = makeId(identity.EffectorId, spec.effector_id),
            .display_name = null,
            .owner_component_id = makeId(identity.ComponentId, spec.owner_component_id),
            .region_id = makeId(identity.RegionId, spec.region_id),
            .preferred_anchor_id = makeId(identity.AnchorId, spec.preferred_anchor_id),
            .semantic_tags = effectorTags(spec.side),
            .approach_metadata_id = null,
            .orientation_metadata_id = null,
            .capacity = 1,
            .occupancy_policy_id = null,
        };
    }
    return result;
}

fn landmarkTags(comptime side: Side) []const identity.SemanticTagId {
    return switch (side) {
        .center => &landmark_tags,
        .left => &landmark_left_tags,
        .right => &landmark_right_tags,
    };
}

fn siteTags(comptime side: Side) []const identity.SemanticTagId {
    return switch (side) {
        .center => &site_tags,
        .left => &site_left_tags,
        .right => &site_right_tags,
    };
}

fn effectorTags(comptime side: Side) []const identity.SemanticTagId {
    return switch (side) {
        .center => &effector_tags,
        .left => &effector_left_tags,
        .right => &effector_right_tags,
    };
}

fn selectNext(items: anytype, comptime id_field: []const u8, previous_id: ?[]const u8) ?usize {
    var selected: ?usize = null;
    for (items, 0..) |item, index| {
        const id = @field(item, id_field).value.bytes;
        if (previous_id) |previous| if (std.mem.order(u8, id, previous) != .gt) continue;
        if (selected == null or std.mem.order(u8, id, @field(items[selected.?], id_field).value.bytes) == .lt) selected = index;
    }
    return selected;
}

fn makeId(comptime T: type, comptime bytes: []const u8) T {
    return T.init(bytes) catch |id_error| @compileError(@errorName(id_error) ++ ": " ++ bytes);
}

fn makeIds(comptime T: type, comptime values: []const []const u8) [values.len]T {
    var result: [values.len]T = undefined;
    inline for (values, 0..) |value, index| result[index] = makeId(T, value);
    return result;
}
