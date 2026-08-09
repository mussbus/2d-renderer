const std = @import("std");
const attachment = @import("attachment.zig");
const component = @import("component.zig");
const definition = @import("definition.zig");
const human_rig = @import("human_rig.zig");
const identity = @import("identity.zig");
const math3d = @import("math3d.zig");
const rig = @import("rig.zig");

pub const anchor_count: usize = 106;
pub const socket_count: usize = 22;
pub const mount_anchor_count: usize = 20;
pub const attachment_count: usize = 20;

pub const report_tolerance_m: f32 = 1.0e-5;

pub const open_tuning = struct {
    pub const face_center_rise_m: f32 = 0.020;
    pub const face_reference_forward_m: f32 = 0.090;
    pub const facial_perception_forward_m: f32 = 0.110;
    pub const hair_root_rise_m: f32 = 0.125;
    pub const hair_root_back_m: f32 = 0.020;
    pub const headwear_rise_m: f32 = 0.160;
    pub const sternum_rise_m: f32 = 0.020;
    pub const sternum_forward_m: f32 = 0.060;
    pub const navel_drop_m: f32 = 0.020;
    pub const navel_forward_m: f32 = 0.070;
    pub const waist_forward_m: f32 = 0.060;
    pub const pubic_drop_m: f32 = 0.080;
    pub const pubic_forward_m: f32 = 0.060;
    pub const anterior_genital_drop_m: f32 = 0.100;
    pub const anterior_genital_forward_m: f32 = 0.080;
    pub const perineal_drop_m: f32 = 0.120;
    pub const posterior_anal_drop_m: f32 = 0.100;
    pub const posterior_anal_back_m: f32 = 0.080;
    pub const upper_back_rise_m: f32 = 0.020;
    pub const upper_back_offset_m: f32 = 0.070;
    pub const mouth_forward_m: f32 = 0.060;
    pub const palm_center_offset_m: f32 = 0.015;
    pub const grip_offset_m: f32 = 0.045;
    pub const finger_pad_ratio: f32 = 0.75;
    pub const nail_bed_ratio: f32 = 0.55;
    pub const nail_surface_offset_m: f32 = 0.004;
    pub const groin_half_spacing_m: f32 = 0.055;
    pub const groin_drop_m: f32 = 0.110;
    pub const groin_forward_m: f32 = 0.030;
    pub const glute_half_spacing_m: f32 = 0.070;
    pub const glute_back_m: f32 = 0.070;
    pub const foot_outer_half_width_m: f32 = 0.045;
    pub const foot_inner_half_width_m: f32 = 0.025;
    pub const foot_edge_forward_m: f32 = 0.040;
};

pub const Side = enum { center, left, right };

pub const AnchorKind = enum {
    head,
    torso,
    pelvis,
    upper_limb,
    hand,
    lower_limb,
    foot_contact,
    nail_registration,
};

pub const AnchorSpec = struct {
    anchor_id: []const u8,
    owner_component_id: []const u8,
    driver_bone_id: []const u8,
    mirror_anchor_id: ?[]const u8,
    local_translation_m: math3d.Vec3,
    side: Side,
    kind: AnchorKind,
    ground_contact: bool,
};

pub const SocketSpec = struct {
    socket_id: []const u8,
    anchor_id: []const u8,
    accepted_component_type: []const u8,
    attachment_requirement: component.Requirement,
};

pub const MountSpec = struct {
    mount_anchor_id: []const u8,
    owner_component_id: []const u8,
};

pub const AttachmentSpec = struct {
    attachment_id: []const u8,
    parent_socket_id: []const u8,
    child_component_id: []const u8,
    child_mount_anchor_id: []const u8,
};

pub const AnchorReportEntry = struct {
    anchor_id: []const u8,
    owner_component_id: []const u8,
    driver_bone_id: []const u8,
    mirror_anchor_id: ?[]const u8,
    world_position_m: math3d.Vec3,
};

pub const SocketReportEntry = struct {
    socket_id: []const u8,
    anchor_id: []const u8,
    attachment_id: ?[]const u8,
    child_component_id: ?[]const u8,
    child_mount_anchor_id: ?[]const u8,
};

pub const MountReportEntry = struct {
    mount_anchor_id: []const u8,
    owner_component_id: []const u8,
    attachment_id: ?[]const u8,
};

pub const ReportError = error{
    OutputTooSmall,
    MissingAnchor,
    MissingBone,
    BoneHierarchyCycle,
    UnsupportedAnchorDriver,
};

const anchor_tags = makeIds(identity.SemanticTagId, &.{ "human", "structural_anchor" });
const anchor_left_tags = makeIds(identity.SemanticTagId, &.{ "human", "left", "structural_anchor" });
const anchor_right_tags = makeIds(identity.SemanticTagId, &.{ "human", "right", "structural_anchor" });
const contact_left_tags = makeIds(identity.SemanticTagId, &.{ "human", "left", "ground_contact" });
const contact_right_tags = makeIds(identity.SemanticTagId, &.{ "human", "right", "ground_contact" });
const nail_component_types = makeIds(identity.ComponentTypeId, &.{"nail"});
const hair_component_types = makeIds(identity.ComponentTypeId, &.{"hair"});
const headwear_component_types = makeIds(identity.ComponentTypeId, &.{"headwear"});

pub const anchor_specs = buildAnchorSpecs();
pub const anchors = buildAnchors();
pub const socket_specs = buildSocketSpecs();
pub const sockets = buildSockets();
pub const mount_specs = buildMountSpecs();
pub const mount_anchors = buildMountAnchors();
pub const attachment_specs = buildAttachmentSpecs();
pub const attachments = buildAttachments();

pub fn generateAnchorReport(
    source: *const definition.CanonicalCreatureDefinition,
    output: []AnchorReportEntry,
) ReportError![]const AnchorReportEntry {
    if (output.len < source.anchors.len) return error.OutputTooSmall;
    var previous_id: ?[]const u8 = null;
    var emitted: usize = 0;
    while (emitted < source.anchors.len) : (emitted += 1) {
        const selected = selectNext(source.anchors, "anchor_id", previous_id) orelse return error.MissingAnchor;
        const record = source.anchors[selected];
        const driver_bone_id = switch (record.driver) {
            .bone => |id| id.value.bytes,
            else => return error.UnsupportedAnchorDriver,
        };
        output[emitted] = .{
            .anchor_id = record.anchor_id.value.bytes,
            .owner_component_id = record.owner_component_id.value.bytes,
            .driver_bone_id = driver_bone_id,
            .mirror_anchor_id = if (record.mirror_anchor_id) |id| id.value.bytes else null,
            .world_position_m = try anchorWorldPosition(source, record.anchor_id.value.bytes),
        };
        previous_id = record.anchor_id.value.bytes;
    }
    return output[0..source.anchors.len];
}

pub fn generateSocketReport(
    source: *const definition.CanonicalCreatureDefinition,
    output: []SocketReportEntry,
) ReportError![]const SocketReportEntry {
    if (output.len < source.sockets.len) return error.OutputTooSmall;
    var previous_id: ?[]const u8 = null;
    var emitted: usize = 0;
    while (emitted < source.sockets.len) : (emitted += 1) {
        const selected = selectNext(source.sockets, "socket_id", previous_id) orelse return error.MissingAnchor;
        const socket = source.sockets[selected];
        var matched_attachment: ?attachment.Attachment = null;
        for (source.attachments) |record| if (record.parent_socket_id.eql(socket.socket_id)) {
            matched_attachment = record;
            break;
        };
        output[emitted] = .{
            .socket_id = socket.socket_id.value.bytes,
            .anchor_id = socket.anchor_id.value.bytes,
            .attachment_id = if (matched_attachment) |record| record.attachment_id.value.bytes else null,
            .child_component_id = if (matched_attachment) |record| record.child_component_id.value.bytes else null,
            .child_mount_anchor_id = if (matched_attachment) |record| record.child_mount_anchor_id.value.bytes else null,
        };
        previous_id = socket.socket_id.value.bytes;
    }
    return output[0..source.sockets.len];
}

pub fn generateMountReport(
    source: *const definition.CanonicalCreatureDefinition,
    output: []MountReportEntry,
) ReportError![]const MountReportEntry {
    if (output.len < source.mount_anchors.len) return error.OutputTooSmall;
    var previous_id: ?[]const u8 = null;
    var emitted: usize = 0;
    while (emitted < source.mount_anchors.len) : (emitted += 1) {
        const selected = selectNext(source.mount_anchors, "mount_anchor_id", previous_id) orelse return error.MissingAnchor;
        const mount = source.mount_anchors[selected];
        var attachment_id: ?[]const u8 = null;
        for (source.attachments) |record| if (record.child_mount_anchor_id.eql(mount.mount_anchor_id)) {
            attachment_id = record.attachment_id.value.bytes;
            break;
        };
        output[emitted] = .{
            .mount_anchor_id = mount.mount_anchor_id.value.bytes,
            .owner_component_id = mount.owner_component_id.value.bytes,
            .attachment_id = attachment_id,
        };
        previous_id = mount.mount_anchor_id.value.bytes;
    }
    return output[0..source.mount_anchors.len];
}

pub fn anchorWorldPosition(
    source: *const definition.CanonicalCreatureDefinition,
    anchor_id: []const u8,
) ReportError!math3d.Vec3 {
    const record = findAnchor(source.anchors, anchor_id) orelse return error.MissingAnchor;
    const driver_world = switch (record.driver) {
        .bone => |bone_id| try boneWorldTransform(source.bones, bone_id.value.bytes),
        else => return error.UnsupportedAnchorDriver,
    };
    return math3d.AffineTransform.compose(
        driver_world,
        math3d.AffineTransform.fromLocal(record.local_transform),
    ).translation_m;
}

pub fn boneWorldTransform(bones: []const rig.Bone, bone_id: []const u8) ReportError!math3d.AffineTransform {
    var current = findBone(bones, bone_id) orelse return error.MissingBone;
    var world = math3d.AffineTransform.fromLocal(current.local_rest_transform);
    var depth: usize = 0;
    while (current.parent_bone_id) |parent_id| {
        depth += 1;
        if (depth > bones.len) return error.BoneHierarchyCycle;
        current = findBone(bones, parent_id.value.bytes) orelse return error.MissingBone;
        world = math3d.AffineTransform.compose(math3d.AffineTransform.fromLocal(current.local_rest_transform), world);
    }
    return world;
}

fn buildAnchorSpecs() [anchor_count]AnchorSpec {
    @setEvalBranchQuota(1_000_000);
    var result: [anchor_count]AnchorSpec = undefined;
    var index: usize = 0;

    appendAnchor(&result, &index, "head_top_anchor", "head", "head", null, vec(0, human_rig.open_tuning.head_top_offset_m, 0), .center, .head, false);
    appendAnchor(&result, &index, "chin_anchor", "head", "jaw", null, vec(0, -human_rig.open_tuning.jaw_bottom_offset_m, 0), .center, .head, false);
    appendAnchor(&result, &index, "face_center_anchor", "head", "head", null, vec(0, open_tuning.face_center_rise_m, open_tuning.face_reference_forward_m), .center, .head, false);
    appendAnchor(&result, &index, "facial_perception_fallback_anchor", "head", "head", null, vec(0, open_tuning.face_center_rise_m, open_tuning.facial_perception_forward_m), .center, .head, false);
    appendAnchor(&result, &index, "hair_root_anchor", "head", "head", null, vec(0, open_tuning.hair_root_rise_m, -open_tuning.hair_root_back_m), .center, .head, false);
    appendAnchor(&result, &index, "headwear_center_anchor", "head", "head", null, vec(0, open_tuning.headwear_rise_m, 0), .center, .head, false);
    appendAnchor(&result, &index, "sternum_center_anchor", "torso", "spine_05", null, vec(0, open_tuning.sternum_rise_m, open_tuning.sternum_forward_m), .center, .torso, false);
    appendAnchor(&result, &index, "navel_anchor", "torso", "spine_02", null, vec(0, -open_tuning.navel_drop_m, open_tuning.navel_forward_m), .center, .torso, false);
    appendAnchor(&result, &index, "waist_center_anchor", "torso", "spine_01", null, vec(0, 0, open_tuning.waist_forward_m), .center, .torso, false);
    appendAnchor(&result, &index, "pelvis_center_anchor", "pelvis", "pelvis", null, math3d.Vec3.zero, .center, .pelvis, false);
    appendAnchor(&result, &index, "pubic_center_anchor", "pelvis", "pelvis", null, vec(0, -open_tuning.pubic_drop_m, open_tuning.pubic_forward_m), .center, .pelvis, false);
    appendAnchor(&result, &index, "anterior_genital_anchor", "pelvis", "pelvis", null, vec(0, -open_tuning.anterior_genital_drop_m, open_tuning.anterior_genital_forward_m), .center, .pelvis, false);
    appendAnchor(&result, &index, "perineal_center_anchor", "pelvis", "pelvis", null, vec(0, -open_tuning.perineal_drop_m, 0), .center, .pelvis, false);
    appendAnchor(&result, &index, "posterior_anal_anchor", "pelvis", "pelvis", null, vec(0, -open_tuning.posterior_anal_drop_m, -open_tuning.posterior_anal_back_m), .center, .pelvis, false);
    appendAnchor(&result, &index, "upper_back_anchor", "torso", "spine_05", null, vec(0, open_tuning.upper_back_rise_m, -open_tuning.upper_back_offset_m), .center, .torso, false);
    appendAnchor(&result, &index, "mouth_interaction_anchor", "mouth", "jaw", null, vec(0, 0, open_tuning.mouth_forward_m), .center, .head, false);

    inline for (.{ "left", "right" }) |side| {
        const is_left = std.mem.eql(u8, side, "left");
        const sign: f32 = if (is_left) -1 else 1;
        const mirror_side = if (is_left) "right" else "left";
        const side_tag: Side = if (is_left) .left else .right;
        const arm_owner = std.fmt.comptimePrint("arm_{s}_01", .{side});
        const hand_owner = std.fmt.comptimePrint("hand_{s}_01", .{side});
        const leg_owner = std.fmt.comptimePrint("leg_{s}_01", .{side});
        const foot_owner = std.fmt.comptimePrint("foot_{s}_01", .{side});

        inline for (.{
            .{ "eye_socket", "head", "head", vec(sign * human_rig.open_tuning.eye_half_spacing_m, human_rig.open_tuning.eye_rise_m, human_rig.open_tuning.eye_forward_m), AnchorKind.head, false },
            .{ "ear_root", std.fmt.comptimePrint("ear_{s}_01", .{side}), std.fmt.comptimePrint("ear_root_{s}_01", .{side}), math3d.Vec3.zero, AnchorKind.head, false },
            .{ "clavicle", "torso", std.fmt.comptimePrint("clavicle_{s}", .{side}), math3d.Vec3.zero, AnchorKind.upper_limb, false },
            .{ "shoulder", "torso", std.fmt.comptimePrint("upper_arm_{s}", .{side}), math3d.Vec3.zero, AnchorKind.upper_limb, false },
            .{ "elbow", arm_owner, std.fmt.comptimePrint("forearm_{s}", .{side}), math3d.Vec3.zero, AnchorKind.upper_limb, false },
            .{ "wrist", arm_owner, std.fmt.comptimePrint("hand_{s}", .{side}), math3d.Vec3.zero, AnchorKind.upper_limb, false },
            .{ "palm_center", hand_owner, std.fmt.comptimePrint("hand_{s}", .{side}), vec(sign * open_tuning.palm_center_offset_m, 0, 0), AnchorKind.hand, false },
            .{ "grip", hand_owner, std.fmt.comptimePrint("hand_{s}", .{side}), vec(sign * open_tuning.grip_offset_m, 0, 0), AnchorKind.hand, false },
            .{ "palm_heel", hand_owner, std.fmt.comptimePrint("hand_{s}", .{side}), math3d.Vec3.zero, AnchorKind.hand, false },
            .{ "thumb_pad", hand_owner, std.fmt.comptimePrint("thumb_distal_{s}", .{side}), vec(sign * human_rig.open_tuning.thumb_distal_length_m * open_tuning.finger_pad_ratio, -0.004, 0), AnchorKind.hand, false },
            .{ "hip", "pelvis", std.fmt.comptimePrint("thigh_{s}", .{side}), math3d.Vec3.zero, AnchorKind.pelvis, false },
            .{ "groin", "pelvis", "pelvis", vec(sign * open_tuning.groin_half_spacing_m, -open_tuning.groin_drop_m, open_tuning.groin_forward_m), AnchorKind.pelvis, false },
            .{ "glute", "pelvis", "pelvis", vec(sign * open_tuning.glute_half_spacing_m, -open_tuning.groin_drop_m, -open_tuning.glute_back_m), AnchorKind.pelvis, false },
            .{ "knee", leg_owner, std.fmt.comptimePrint("lower_leg_{s}", .{side}), math3d.Vec3.zero, AnchorKind.lower_limb, false },
            .{ "ankle", leg_owner, std.fmt.comptimePrint("ankle_{s}", .{side}), math3d.Vec3.zero, AnchorKind.lower_limb, false },
            .{ "heel_contact", foot_owner, std.fmt.comptimePrint("foot_{s}", .{side}), vec(0, -human_rig.open_tuning.heel_ground_drop_m, -human_rig.open_tuning.heel_back_offset_m), AnchorKind.foot_contact, true },
            .{ "foot_outer_edge", foot_owner, std.fmt.comptimePrint("foot_{s}", .{side}), vec(sign * open_tuning.foot_outer_half_width_m, -human_rig.open_tuning.heel_ground_drop_m, open_tuning.foot_edge_forward_m), AnchorKind.foot_contact, true },
            .{ "foot_inner_edge", foot_owner, std.fmt.comptimePrint("foot_{s}", .{side}), vec(-sign * open_tuning.foot_inner_half_width_m, -human_rig.open_tuning.heel_ground_drop_m, open_tuning.foot_edge_forward_m), AnchorKind.foot_contact, true },
            .{ "ball", foot_owner, std.fmt.comptimePrint("forefoot_{s}", .{side}), math3d.Vec3.zero, AnchorKind.foot_contact, true },
            .{ "toe_tip", foot_owner, std.fmt.comptimePrint("toe_big_{s}_02", .{side}), vec(0, 0, human_rig.open_tuning.big_toe_tip_length_m), AnchorKind.foot_contact, true },
        }) |entry| {
            const prefix = entry[0];
            appendAnchor(
                &result,
                &index,
                std.fmt.comptimePrint("{s}_{s}_anchor", .{ prefix, side }),
                entry[1],
                entry[2],
                std.fmt.comptimePrint("{s}_{s}_anchor", .{ prefix, mirror_side }),
                entry[3],
                side_tag,
                entry[4],
                entry[5],
            );
        }

        inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| {
            const is_thumb = std.mem.eql(u8, digit, "thumb");
            const distal_bone = if (is_thumb)
                std.fmt.comptimePrint("thumb_distal_{s}", .{side})
            else
                std.fmt.comptimePrint("{s}_distal_{s}", .{ digit, side });
            const distal_length = if (is_thumb) human_rig.open_tuning.thumb_distal_length_m else human_rig.open_tuning.finger_distal_length_m;
            inline for (.{
                .{ "fingertip", distal_length, @as(f32, 0), AnchorKind.hand },
                .{ "finger_pad", distal_length * open_tuning.finger_pad_ratio, @as(f32, -0.004), AnchorKind.hand },
                .{ "fingernail_bed", distal_length * open_tuning.nail_bed_ratio, open_tuning.nail_surface_offset_m, AnchorKind.nail_registration },
            }) |entry| {
                appendAnchor(
                    &result,
                    &index,
                    std.fmt.comptimePrint("{s}_{s}_{s}_anchor", .{ entry[0], digit, side }),
                    hand_owner,
                    distal_bone,
                    std.fmt.comptimePrint("{s}_{s}_{s}_anchor", .{ entry[0], digit, mirror_side }),
                    vec(sign * entry[1], entry[2], 0),
                    side_tag,
                    entry[3],
                    false,
                );
            }

            const toe_name = if (is_thumb) "big" else digit;
            const toe_driver = if (is_thumb)
                std.fmt.comptimePrint("toe_big_{s}_02", .{side})
            else
                std.fmt.comptimePrint("toe_{s}_{s}_03", .{ digit, side });
            const toe_tip_length = if (is_thumb) human_rig.open_tuning.big_toe_tip_length_m else human_rig.open_tuning.lesser_toe_tip_length_m;
            appendAnchor(
                &result,
                &index,
                std.fmt.comptimePrint("toe_pad_{s}_{s}_anchor", .{ toe_name, side }),
                foot_owner,
                toe_driver,
                std.fmt.comptimePrint("toe_pad_{s}_{s}_anchor", .{ toe_name, mirror_side }),
                vec(0, 0, toe_tip_length * open_tuning.finger_pad_ratio),
                side_tag,
                .foot_contact,
                true,
            );
            appendAnchor(
                &result,
                &index,
                std.fmt.comptimePrint("toenail_bed_{s}_{s}_anchor", .{ digit, side }),
                foot_owner,
                toe_driver,
                std.fmt.comptimePrint("toenail_bed_{s}_{s}_anchor", .{ digit, mirror_side }),
                vec(0, open_tuning.nail_surface_offset_m, toe_tip_length * open_tuning.nail_bed_ratio),
                side_tag,
                .nail_registration,
                false,
            );
        }
    }

    if (index != anchor_count) @compileError(std.fmt.comptimePrint("human anchor count is {d}, expected {d}", .{ index, anchor_count }));
    return result;
}

fn buildSocketSpecs() [socket_count]SocketSpec {
    @setEvalBranchQuota(1_000_000);
    var result: [socket_count]SocketSpec = undefined;
    var index: usize = 0;
    result[index] = .{ .socket_id = "hair_socket", .anchor_id = "hair_root_anchor", .accepted_component_type = "hair", .attachment_requirement = .optional };
    index += 1;
    result[index] = .{ .socket_id = "headwear_socket", .anchor_id = "headwear_center_anchor", .accepted_component_type = "headwear", .attachment_requirement = .optional };
    index += 1;
    inline for (.{ "left", "right" }) |side| {
        inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| {
            inline for (.{ "fingernail", "toenail" }) |kind| {
                result[index] = .{
                    .socket_id = std.fmt.comptimePrint("{s}_{s}_{s}_socket", .{ kind, digit, side }),
                    .anchor_id = std.fmt.comptimePrint("{s}_bed_{s}_{s}_anchor", .{ kind, digit, side }),
                    .accepted_component_type = "nail",
                    .attachment_requirement = .required,
                };
                index += 1;
            }
        }
    }
    if (index != socket_count) @compileError("human socket count mismatch");
    return result;
}

fn buildMountSpecs() [mount_anchor_count]MountSpec {
    @setEvalBranchQuota(1_000_000);
    var result: [mount_anchor_count]MountSpec = undefined;
    var index: usize = 0;
    inline for (.{ "left", "right" }) |side| {
        inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| {
            inline for (.{ "fingernail", "toenail" }) |kind| {
                const component_id = std.fmt.comptimePrint("{s}_{s}_{s}", .{ kind, digit, side });
                result[index] = .{
                    .mount_anchor_id = std.fmt.comptimePrint("{s}_mount_anchor", .{component_id}),
                    .owner_component_id = component_id,
                };
                index += 1;
            }
        }
    }
    if (index != mount_anchor_count) @compileError("human mount-anchor count mismatch");
    return result;
}

fn buildAttachmentSpecs() [attachment_count]AttachmentSpec {
    @setEvalBranchQuota(1_000_000);
    var result: [attachment_count]AttachmentSpec = undefined;
    var index: usize = 0;
    inline for (.{ "left", "right" }) |side| {
        inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| {
            inline for (.{ "fingernail", "toenail" }) |kind| {
                const component_id = std.fmt.comptimePrint("{s}_{s}_{s}", .{ kind, digit, side });
                result[index] = .{
                    .attachment_id = std.fmt.comptimePrint("{s}_attachment", .{component_id}),
                    .parent_socket_id = std.fmt.comptimePrint("{s}_socket", .{component_id}),
                    .child_component_id = component_id,
                    .child_mount_anchor_id = std.fmt.comptimePrint("{s}_mount_anchor", .{component_id}),
                };
                index += 1;
            }
        }
    }
    if (index != attachment_count) @compileError("human attachment count mismatch");
    return result;
}

fn buildAnchors() [anchor_count]attachment.Anchor {
    @setEvalBranchQuota(1_000_000);
    var result: [anchor_count]attachment.Anchor = undefined;
    inline for (anchor_specs, 0..) |spec, index| {
        result[index] = .{
            .anchor_id = makeId(identity.AnchorId, spec.anchor_id),
            .display_name = null,
            .owner_component_id = makeId(identity.ComponentId, spec.owner_component_id),
            .mirror_anchor_id = if (spec.mirror_anchor_id) |id| makeId(identity.AnchorId, id) else null,
            .driver = .{ .bone = makeId(identity.BoneId, spec.driver_bone_id) },
            .local_transform = transform(spec.local_translation_m),
            .semantic_tags = tagsFor(spec),
        };
    }
    return result;
}

fn buildSockets() [socket_count]attachment.Socket {
    @setEvalBranchQuota(100_000);
    var result: [socket_count]attachment.Socket = undefined;
    inline for (socket_specs, 0..) |spec, index| {
        const accepted_types = if (std.mem.eql(u8, spec.accepted_component_type, "nail"))
            &nail_component_types
        else if (std.mem.eql(u8, spec.accepted_component_type, "hair"))
            &hair_component_types
        else
            &headwear_component_types;
        result[index] = .{
            .socket_id = makeId(identity.SocketId, spec.socket_id),
            .anchor_id = makeId(identity.AnchorId, spec.anchor_id),
            .accepted_component_types = accepted_types,
            .accepted_tags = &.{},
            .capacity = 1,
            .attachment_requirement = spec.attachment_requirement,
            .compatibility = .none,
        };
    }
    return result;
}

fn buildMountAnchors() [mount_anchor_count]attachment.MountAnchor {
    @setEvalBranchQuota(100_000);
    var result: [mount_anchor_count]attachment.MountAnchor = undefined;
    inline for (mount_specs, 0..) |spec, index| {
        result[index] = .{
            .mount_anchor_id = makeId(identity.MountAnchorId, spec.mount_anchor_id),
            .display_name = null,
            .owner_component_id = makeId(identity.ComponentId, spec.owner_component_id),
            .driver = .{ .component = makeId(identity.ComponentId, spec.owner_component_id) },
            .local_transform = math3d.LocalTransform.identity,
            .semantic_tags = &anchor_tags,
        };
    }
    return result;
}

fn buildAttachments() [attachment_count]attachment.Attachment {
    @setEvalBranchQuota(100_000);
    var result: [attachment_count]attachment.Attachment = undefined;
    inline for (attachment_specs, 0..) |spec, index| {
        result[index] = .{
            .attachment_id = makeId(identity.AttachmentId, spec.attachment_id),
            .parent_socket_id = makeId(identity.SocketId, spec.parent_socket_id),
            .child_component_id = makeId(identity.ComponentId, spec.child_component_id),
            .child_mount_anchor_id = makeId(identity.MountAnchorId, spec.child_mount_anchor_id),
            .compatibility_profiles = &.{},
        };
    }
    return result;
}

fn appendAnchor(
    result: *[anchor_count]AnchorSpec,
    index: *usize,
    anchor_id: []const u8,
    owner_component_id: []const u8,
    driver_bone_id: []const u8,
    mirror_anchor_id: ?[]const u8,
    local_translation_m: math3d.Vec3,
    side: Side,
    kind: AnchorKind,
    ground_contact: bool,
) void {
    result[index.*] = .{
        .anchor_id = anchor_id,
        .owner_component_id = owner_component_id,
        .driver_bone_id = driver_bone_id,
        .mirror_anchor_id = mirror_anchor_id,
        .local_translation_m = local_translation_m,
        .side = side,
        .kind = kind,
        .ground_contact = ground_contact,
    };
    index.* += 1;
}

fn tagsFor(comptime spec: AnchorSpec) []const identity.SemanticTagId {
    if (spec.kind == .foot_contact) return if (spec.side == .left) &contact_left_tags else &contact_right_tags;
    return switch (spec.side) {
        .center => &anchor_tags,
        .left => &anchor_left_tags,
        .right => &anchor_right_tags,
    };
}

fn findAnchor(records: []const attachment.Anchor, id: []const u8) ?attachment.Anchor {
    for (records) |record| if (std.mem.eql(u8, record.anchor_id.value.bytes, id)) return record;
    return null;
}

fn findBone(records: []const rig.Bone, id: []const u8) ?rig.Bone {
    for (records) |record| if (std.mem.eql(u8, record.bone_id.value.bytes, id)) return record;
    return null;
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

fn transform(translation_m: math3d.Vec3) math3d.LocalTransform {
    return .{ .translation_m = translation_m, .rotation = math3d.Quaternion.identity, .scale = math3d.Vec3.one };
}

fn vec(x: f32, y: f32, z: f32) math3d.Vec3 {
    return .{ .x = x, .y = y, .z = z };
}

fn makeId(comptime T: type, comptime bytes: []const u8) T {
    return T.init(bytes) catch |id_error| @compileError(@errorName(id_error) ++ ": " ++ bytes);
}

fn makeIds(comptime T: type, comptime values: []const []const u8) [values.len]T {
    var result: [values.len]T = undefined;
    inline for (values, 0..) |value, index| result[index] = makeId(T, value);
    return result;
}
