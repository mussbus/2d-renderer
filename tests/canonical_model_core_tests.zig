const std = @import("std");
const canonical = @import("canonical_model");

const attachment = canonical.attachment;
const component = canonical.component;
const coordinate = canonical.coordinate;
const identity = canonical.identity;
const math3d = canonical.math3d;
const rig = canonical.rig;
const semantics = canonical.semantics;

test "machine IDs remain distinct from display names and version kinds" {
    comptime {
        if (identity.SchemaVersion == identity.AssetVersion or
            identity.SchemaVersion == identity.CompilerVersion or
            identity.AssetVersion == identity.CompilerVersion)
        {
            @compileError("canonical semantic-version identities must remain distinct");
        }
        if (identity.ComponentId == identity.BoneId) {
            @compileError("canonical reference kinds must remain distinct");
        }
    }

    const machine_id = try identity.BoneId.init("spine_01");
    const same_machine_id = try identity.BoneId.init("spine_01");
    const display_name = try identity.DisplayName.init("Spine 01");

    try std.testing.expect(machine_id.eql(same_machine_id));
    try std.testing.expectEqualStrings("spine_01", machine_id.value.bytes);
    try std.testing.expectEqualStrings("Spine 01", display_name.bytes);
    try std.testing.expectError(error.EmptyCanonicalId, identity.BoneId.init(""));
    try std.testing.expectError(error.InvalidCanonicalId, identity.BoneId.init("Spine_01"));
    try std.testing.expectError(error.InvalidCanonicalId, identity.BoneId.init("spine-01"));
    try std.testing.expectError(error.InvalidCanonicalId, identity.BoneId.init("spine_"));

    const schema = identity.SchemaVersion{ .major = 1, .minor = 2, .patch = 3 };
    const asset = identity.AssetVersion{ .major = 4, .minor = 5, .patch = 6 };
    const compiler = identity.CompilerVersion{ .major = 7, .minor = 8, .patch = 9 };
    try std.testing.expectEqual(@as(u32, 1), schema.major);
    try std.testing.expectEqual(@as(u32, 5), asset.minor);
    try std.testing.expectEqual(@as(u32, 9), compiler.patch);
}

test "coordinate and transform contracts are explicit and local only" {
    try std.testing.expectEqual(coordinate.DistanceUnit.meter, coordinate.canonical.unit);
    try std.testing.expectEqual(coordinate.NumericPrecision.f32, coordinate.canonical.numeric_precision);
    try std.testing.expectEqual(@as(f32, 0.001), coordinate.canonical.authoring_step_m);
    try std.testing.expectEqual(coordinate.Handedness.right_handed, coordinate.canonical.handedness);
    try std.testing.expectEqual(coordinate.AxisDirection.positive_x, coordinate.canonical.world_viewer_right);
    try std.testing.expectEqual(coordinate.AxisDirection.positive_y, coordinate.canonical.up);
    try std.testing.expectEqual(coordinate.AxisDirection.positive_z, coordinate.canonical.toward_camera);
    try std.testing.expectEqual(coordinate.AxisDirection.negative_z, coordinate.canonical.away_from_camera);
    try std.testing.expectEqual(coordinate.AxisDirection.positive_z, coordinate.canonical.canonical_forward);
    try std.testing.expectEqual(@as(f32, 0), coordinate.canonical.ground_y_m);
    try std.testing.expectEqual(coordinate.AssetOrigin.centered_between_feet_on_ground_in_a_pose, coordinate.canonical.asset_origin);
    try std.testing.expectEqual(@as(f32, 1.8288), coordinate.canonical.canonical_height_m);
    try std.testing.expectEqual(coordinate.BindPose.a_pose, coordinate.canonical.bind_pose);
    try std.testing.expectEqual(coordinate.AngleUnit.radian, coordinate.canonical.canonical_angle_unit);

    try std.testing.expect(@hasField(math3d.LocalTransform, "translation_m"));
    try std.testing.expect(@hasField(math3d.LocalTransform, "rotation"));
    try std.testing.expect(@hasField(math3d.LocalTransform, "scale"));
    try std.testing.expect(!@hasField(math3d.LocalTransform, "global_transform"));
    try std.testing.expect(!@hasField(math3d.LocalTransform, "world_transform"));
}

test "quaternion canonical identity normalizes sign unit length and negative zero" {
    const half_sqrt_two: f32 = @sqrt(0.5);
    const positive = try math3d.Quaternion.initCanonical(-0.0, 0.0, half_sqrt_two, half_sqrt_two);
    const negative = try math3d.Quaternion.initCanonical(0.0, -0.0, -half_sqrt_two, -half_sqrt_two);
    try std.testing.expectEqual(positive, negative);
    try std.testing.expectApproxEqAbs(@as(f32, 1), positive.lengthSquared(), 1e-6);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @bitCast(positive.x)));
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @bitCast(positive.y)));

    const tie_break = try math3d.Quaternion.initCanonical(-1.0, -0.0, 0.0, -0.0);
    try std.testing.expectEqual(@as(f32, 1), tie_break.x);
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @bitCast(tie_break.y)));
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @bitCast(tie_break.z)));
    try std.testing.expectEqual(@as(u32, 0), @as(u32, @bitCast(tie_break.w)));

    const within_tolerance = try math3d.Quaternion.initCanonical(0, 0, 0, 1.000002);
    try std.testing.expectEqual(@as(f32, 1), within_tolerance.w);
    try std.testing.expectError(
        error.QuaternionOutsideUnitTolerance,
        math3d.Quaternion.initCanonical(0, 0, 0, 1.00001),
    );
    try std.testing.expectError(
        error.NonFiniteQuaternion,
        math3d.Quaternion.initCanonical(std.math.inf(f32), 0, 0, 1),
    );
}

test "component and bone records express one optional typed parent and mirror" {
    const body_id = try identity.ComponentId.init("body");
    const head_id = try identity.ComponentId.init("head");
    const body_type = try identity.ComponentTypeId.init("body");
    const head_type = try identity.ComponentTypeId.init("head");
    const body = component.Component{
        .component_id = body_id,
        .display_name = try identity.DisplayName.init("Body"),
        .component_type = body_type,
        .parent_component_id = null,
        .semantic_tags = &.{},
        .requirement = .required,
        .default_state = .enabled,
        .multiplicity = .{ .minimum = 1, .maximum = 1 },
        .compatibility = .none,
    };
    const head = component.Component{
        .component_id = head_id,
        .display_name = try identity.DisplayName.init("Head"),
        .component_type = head_type,
        .parent_component_id = body_id,
        .semantic_tags = &.{},
        .requirement = .required,
        .default_state = .enabled,
        .multiplicity = .{ .minimum = 1, .maximum = 1 },
        .compatibility = .none,
    };
    try std.testing.expect(body.parent_component_id == null);
    try std.testing.expect(head.parent_component_id.?.eql(body_id));
    try std.testing.expect(@TypeOf(head.parent_component_id) == ?identity.ComponentId);

    const skeleton_root_id = try identity.BoneId.init("skeleton_root");
    const arm_left_id = try identity.BoneId.init("arm_left_01");
    const arm_right_id = try identity.BoneId.init("arm_right_01");
    const skeleton_root = rig.Bone{
        .bone_id = skeleton_root_id,
        .display_name = try identity.DisplayName.init("Skeleton Root"),
        .parent_bone_id = null,
        .deforms_mesh = false,
        .local_rest_transform = .identity,
        .semantic_tags = &.{},
        .mirror_bone_id = null,
        .display_length_m = null,
    };
    const arm_left = rig.Bone{
        .bone_id = arm_left_id,
        .display_name = try identity.DisplayName.init("Arm Left 01"),
        .parent_bone_id = skeleton_root_id,
        .deforms_mesh = true,
        .local_rest_transform = .identity,
        .semantic_tags = &.{},
        .mirror_bone_id = arm_right_id,
        .display_length_m = 0.4,
    };
    try std.testing.expect(skeleton_root.parent_bone_id == null);
    try std.testing.expect(arm_left.parent_bone_id.?.eql(skeleton_root_id));
    try std.testing.expect(arm_left.mirror_bone_id.?.eql(arm_right_id));
    try std.testing.expect(@TypeOf(arm_left.mirror_bone_id) == ?identity.BoneId);
    try std.testing.expect(@hasField(rig.Bone, "local_rest_transform"));
    try std.testing.expect(!@hasField(rig.Bone, "global_rest_transform"));
}

test "representative core records preserve typed cross references" {
    const body_id = try identity.ComponentId.init("body");
    const head_id = try identity.ComponentId.init("head");
    const skeleton_root_id = try identity.BoneId.init("skeleton_root");
    const head_bone_id = try identity.BoneId.init("head");
    const neck_joint_id = try identity.JointId.init("neck_joint");
    const head_control_id = try identity.ControlId.init("head_fk");
    const socket_anchor_id = try identity.AnchorId.init("head_socket_anchor");
    const socket_id = try identity.SocketId.init("head_socket");
    const mount_id = try identity.MountAnchorId.init("head_mount");
    const attachment_id = try identity.AttachmentId.init("head_attachment");
    const region_id = try identity.RegionId.init("head_region");
    const body_surface_id = try identity.SurfaceId.init("body_surface");
    const head_surface_id = try identity.SurfaceId.init("head_surface");

    const joint = rig.Joint{
        .joint_id = neck_joint_id,
        .display_name = try identity.DisplayName.init("Neck Joint"),
        .parent_bone_id = skeleton_root_id,
        .child_bone_id = head_bone_id,
        .joint_type = .ball_and_socket,
        .preferred_range = .{
            .x = .{ .minimum_radians = -0.25, .maximum_radians = 0.25 },
            .y = null,
            .z = null,
        },
        .hard_range = .{
            .x = .{ .minimum_radians = -0.5, .maximum_radians = 0.5 },
            .y = null,
            .z = null,
        },
        .preferred_bend_direction = try math3d.Vec3.init(0, 0, 1),
        .swing_twist = null,
        .limit_behavior = .{ .stiffness = null },
        .mobility_profile_override = null,
    };
    const targets = [_]rig.DrivenTarget{.{ .joint = neck_joint_id }};
    const control = rig.Control{
        .control_id = head_control_id,
        .display_name = try identity.DisplayName.init("Head FK"),
        .control_type = .fk_rotation,
        .driven_targets = &targets,
        .space = .local,
        .mirror_control_id = null,
        .default_value = .{ .quaternion = .identity },
        .limits = null,
        .semantic_tags = &.{},
        .region_id = region_id,
    };
    const anchor = attachment.Anchor{
        .anchor_id = socket_anchor_id,
        .display_name = try identity.DisplayName.init("Head Socket Anchor"),
        .owner_component_id = body_id,
        .driver = .{ .bone = skeleton_root_id },
        .local_transform = .identity,
        .semantic_tags = &.{},
    };
    const accepted_types = [_]identity.ComponentTypeId{try identity.ComponentTypeId.init("head")};
    const socket = attachment.Socket{
        .socket_id = socket_id,
        .anchor_id = socket_anchor_id,
        .accepted_component_types = &accepted_types,
        .accepted_tags = &.{},
        .capacity = 1,
        .attachment_requirement = .required,
        .compatibility = .none,
    };
    const mount = attachment.MountAnchor{
        .mount_anchor_id = mount_id,
        .display_name = try identity.DisplayName.init("Head Mount"),
        .owner_component_id = head_id,
        .driver = .{ .component = head_id },
        .local_transform = .identity,
        .semantic_tags = &.{},
    };
    const attachment_record = attachment.Attachment{
        .attachment_id = attachment_id,
        .parent_socket_id = socket_id,
        .child_component_id = head_id,
        .child_mount_anchor_id = mount_id,
        .compatibility_profiles = &.{},
    };

    const region = semantics.Region{
        .region_id = region_id,
        .display_name = try identity.DisplayName.init("Head Region"),
        .owner_component_id = head_id,
        .semantic_tags = &.{},
    };
    const material_id = try identity.MaterialInstanceId.init("neutral_skin");
    const body_surface = semantics.Surface{
        .surface_id = body_surface_id,
        .display_name = try identity.DisplayName.init("Body Surface"),
        .owner_component_id = body_id,
        .region_id = region_id,
        .material_instance_id = material_id,
        .coordinate_metadata_id = null,
        .visibility_metadata_id = null,
    };
    const head_surface = semantics.Surface{
        .surface_id = head_surface_id,
        .display_name = try identity.DisplayName.init("Head Surface"),
        .owner_component_id = head_id,
        .region_id = region_id,
        .material_instance_id = material_id,
        .coordinate_metadata_id = null,
        .visibility_metadata_id = null,
    };
    const landmark = semantics.Landmark{
        .landmark_id = try identity.LandmarkId.init("head_center"),
        .display_name = try identity.DisplayName.init("Head Center"),
        .owner = .{ .surface = head_surface_id },
        .coordinate_metadata_id = null,
        .semantic_tags = &.{},
    };
    const seam_members = [_]semantics.SharedSeamMember{
        .{ .component_id = body_id, .surface_id = body_surface_id },
        .{ .component_id = head_id, .surface_id = head_surface_id },
    };
    const seam = semantics.SharedSeam{
        .seam_id = try identity.SeamId.init("neck_shared_ring"),
        .display_name = try identity.DisplayName.init("Neck Shared Ring"),
        .members = &seam_members,
        .coordinate_metadata_id = null,
    };
    const site = semantics.InteractionSite{
        .site_id = try identity.InteractionSiteId.init("head_contact_site"),
        .display_name = try identity.DisplayName.init("Head Contact Site"),
        .owner_component_id = head_id,
        .region_id = region_id,
        .preferred_anchor_id = socket_anchor_id,
        .semantic_tags = &.{},
        .approach_metadata_id = null,
        .orientation_metadata_id = null,
        .capacity = 1,
        .occupancy_policy_id = null,
    };
    const effector = semantics.Effector{
        .effector_id = try identity.EffectorId.init("head_effector"),
        .display_name = try identity.DisplayName.init("Head Effector"),
        .owner_component_id = head_id,
        .region_id = region_id,
        .preferred_anchor_id = socket_anchor_id,
        .semantic_tags = &.{},
        .approach_metadata_id = null,
        .orientation_metadata_id = null,
        .capacity = 1,
        .occupancy_policy_id = null,
    };

    try std.testing.expect(joint.child_bone_id.eql(head_bone_id));
    try std.testing.expectEqual(rig.ControlSpace.local, control.space);
    try std.testing.expect(socket.anchor_id.eql(anchor.anchor_id));
    try std.testing.expect(attachment_record.parent_socket_id.eql(socket.socket_id));
    try std.testing.expect(attachment_record.child_mount_anchor_id.eql(mount.mount_anchor_id));
    try std.testing.expect(region.owner_component_id.eql(head_id));
    try std.testing.expect(body_surface.owner_component_id.eql(body_id));
    try std.testing.expect(head_surface.region_id.eql(region.region_id));
    try std.testing.expectEqual(@as(usize, 2), seam.members.len);
    try std.testing.expectEqualStrings("head_center", landmark.landmark_id.value.bytes);
    try std.testing.expect(site.owner_component_id.eql(effector.owner_component_id));
}

test "anchors sockets and mount anchors remain structurally distinct" {
    try std.testing.expect(@hasField(attachment.Anchor, "local_transform"));
    try std.testing.expect(@hasField(attachment.MountAnchor, "local_transform"));
    try std.testing.expect(!@hasField(attachment.Socket, "local_transform"));
    try std.testing.expect(@hasField(attachment.Socket, "anchor_id"));
    try std.testing.expect(@hasField(attachment.Attachment, "parent_socket_id"));
    try std.testing.expect(@hasField(attachment.Attachment, "child_mount_anchor_id"));
    try std.testing.expect(attachment.Anchor != attachment.MountAnchor);
    try std.testing.expect(attachment.Anchor != attachment.Socket);
}

test "all locked animator control categories are representable without solvers" {
    const control_types = [_]rig.ControlType{
        .fk_rotation,
        .ik_target,
        .pole_direction,
        .curve_spline,
        .whole_region,
        .normalized_slider,
        .look_target,
        .procedural_grasp,
    };
    try std.testing.expectEqual(@as(usize, 8), control_types.len);
}
